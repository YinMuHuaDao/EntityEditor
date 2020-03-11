-- This script implements an auto-defense behavior for aggregate air defense
-- entities with one or more anti-airs weapon systems (i.e., Indirect-Fire-Power
-- entries with Anti-Air damage type).
-- It checks the contact list each tick and for each air aggregate, it looks to 
-- see if it has an anti-air weapon systems (from the IF Power table) that has the
-- range and ceiling to reach it. It finds the closest such target.
-- Then it starts a Attack_with_AntiAir_Missile task to attack it. Note that this
-- subtask selects the weapon, so that is not done in this task.

-- Set to true to dump details
DEBUG_DETAIL = true

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
antiAirWeaponList = {} -- List of eligible weapon systems. Keyed on name, 
                        -- with range and max-altitude in each entry.
attackSubtaskId = -1
state = "acquiring"
local weaponsReady = true

local allIFWeapons = this:getStateProperty("Indirect-Fire-Power")
local ammoByCategory = this:getStateProperty("Ammunition-Categories")


-- Task Parameters Available in Script
--  taskParameters.engagementArea Type: SimObject - Target AC must be in this area to be engaged.


function hasAmmo(weaponName)
   local result = false
   -- refresh count
   ammoByCategory = this:getStateProperty("Ammunition-Categories")
   -- For weapon system ammo, weapon name and category are the same
   local ammoStatus = ammoByCategory[weaponName]
   if ammoStatus ~= nil then
      if ammoStatus.Count >= 1 then
         result = true
      end
   end
   return result
end

function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(5.0)
   
   -- Get the anti-air systems
   if allIFWeapons == nil or
      ammoByCategory == nil then
      
      printWarn("Error: Auto SAM Defense: Parameter table(s) nil")
      vrf:endTask(false)
   elseif this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Auto SAM Defense: Cannot attack while embarked."))
      vrf:endTask(false)
   else
      local weapon = ""
      local weaponInfo = nil
      local foundWeapon = false
      local myPosture = this:getStateProperty("Posture")
      local postureOK = nil
      
      for weapon, weaponInfo in pairs(allIFWeapons) do
         if DEBUG_DETAIL then
            printDebug("Considering weapon ", weapon)
         end
         if weaponInfo["Damage-Type"] == "Anti-Air" then
            
            local weapRange = weaponInfo["Range"]
            local weapAlt = weaponInfo["Max-Altitude"]
            if weapRange ~= nil and weapAlt ~= nil then
               antiAirWeaponList[weapon] = 
                  {range = weapRange,
                  altitude = weapAlt}
               if DEBUG_DETAIL then
                  printDebug(".  Anti-air type, range ", 
                     weapRange,
                     ", ceiling ", weapAlt)
               end
               if not postureAllowsWeaponUse(weaponInfo, myPosture) then
                  postureOK = weapon
               end
            end
         end
      end
      if next(antiAirWeaponList) == nil then
         printWarn(vrf:trUtf8("Auto Air Defense: No available anti-air weapon systems"))
         if postureOK ~= nil then
            printWarn(vrf:trUtf8("  (Current posture does not allow use of weapon %1.)"):
               arg(postureOK))
         end
         vrf:endTask(false)
      end
   end    
end
  
--Looks through all the weapons in the list to make sure they have ammo
--and can be used in the current posture.
--Returns a list of weapons that are ready.
function checkWeapons(weaponList)
   local ready = {}
   local name
   local info
   local myPosture = this:getStateProperty("Posture")
   for name, info in pairs(weaponList) do
      if hasAmmo(name) then
         weapInfo = allIFWeapons[name]
         
         if postureAllowsWeaponUse(weapInfo, myPosture) then
            ready[name] = info
         else
            printVerbose(vrf:trUtf8(".  Weapon %1 can't be used in posture %2."):arg(name):arg(myPosture))
         end
      else
         printVerbose(vrf:trUtf8(".  Weapon %1 has no ammo."):arg(name))
      end
   end
   return ready
end

--Finds the closest target on the given target list that is an air aggregate,
--in the engagement area and within the maximum range and 
--altitude of one of the anti-air weapons.
function findClosestTarget(targetList, readyWeaponList)
   local closestTarget = nil
   local rangeToClosest = allWeaponsMaxRange
   local altOfClosest = 0
   local i
   local target
   
   for i, target in ipairs(targetList) do
      local targetType = target:getEntityType()
      
      if not target:isDestroyed() and
         vrf:entityTypeMatches(targetType, EntityType.AggregateAir())  and
         taskParameters.engagementArea:isPointInside(
         target:getLocation3D())then
         
         if DEBUG_DETAIL then
            printDebug(".  Considering ", target:getName())
         end
         -- Remember the closest one (that we can shoot at)
         local targetLoc = target:getLocation3D()
         local targetAlt = targetLoc:getAlt()
         local targetRange = this:getLocation3D():distanceToLocation3D(
            targetLoc)
         local haveWeapon = false
         local weapon
         local weapInfo
         for weapon, weapInfo in pairs(readyWeaponList) do
            if targetAlt <= weapInfo.altitude and 
               targetRange <= weapInfo.range then
               
               haveWeapon = true
               break
            elseif DEBUG_DETAIL then
               if targetRange > weapInfo.range then
                  printDebug(".  .  Target range ", targetRange,
                     " is too far.")
               end
               if targetAlt > weapInfo.altitude then
                  printDebug(".  .  Target altitude ", targetAlt,
                     " is too high.")
               end
            end
         end
         if haveWeapon then
            rangeToClosest = targetRange
            closestTarget = target
            altOfClosest = targetAlt
         end
      end
   end
   return closestTarget, rangeToClosest, altOfClosest
end

-- Called each tick while this task is active.
function tick()
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Automatic Air Defense, state %s",
         vrf:getSimulationTime(), state))
   end
   
   if not taskParameters.engagementArea:isValid() then
      printWarn(vrf:trUtf8("Automatic Air Defense: Engagement area is invalid."))
      vrf:endTask(false)
   elseif state == "acquiring" then   
      -- Update ready weapons
      local allWeaponsMaxAltitude
      local allWeaponsMaxRange
      local readyWeapons = checkWeapons(antiAirWeaponList)
      if next(readyWeapons) == nil then
         if weaponsReady then
            printWarn(vrf:trUtf8("Auto air defense: No anti-air weapons ready."))
            weaponsReady = false
         end
         return
      else
         if not weaponsReady then
            printWarn(vrf:trUtf8("Auto air defense: Anti-air weapons ready."))
            weaponsReady = true
         end
      end
      
      local bandits = this:getAllHostileContacts()
      if next(bandits) == nil then
         if DEBUG_DETAIL then
            printDebug(".  No contacts.")
         end
         return
      end
      -- Find the closest one that is within range and ceiling of a ready weapon
      closestTarget, rangeToClosest, altOfClosest = 
         findClosestTarget(bandits, readyWeapons)
         
      if closestTarget ~= nil then
         if DEBUG_DETAIL then
            printDebug(".  Found target ", closestTarget:getName())
         end
         -- Got a target; engage
         attackSubtaskId = vrf:startSubtask("Attack_with_AntiAir_Missile",
            {targetEntity = closestTarget, 
            numMissiles = 1})
         state = "shooting"
      elseif DEBUG_DETAIL then
         printDebug(".   No targets.")
      end
   elseif state == "shooting" then
      if not vrf:isSubtaskRunning(attackSubtaskId) then
         state = "acquiring"
      end   
   end
end


-- Called when this task is being suspended, likely by a reaction activating.
function suspend()
   -- By default, halt all subtasks and other entity tasks started by this task when suspending.
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
end

-- Called when this task is being resumed after being suspended.
function resume()
   -- By default, simply call init() to start the task over.
   init()
end

-- Called immediately before a scenario checkpoint is saved when
-- this task is active.
-- It is typically not necessary to add code to this function.
function saveState()
end

-- Called immediately after a scenario checkpoint is loaded in which
-- this task is active.
-- It is typically not necessary to add code to this function.
function loadState()
end


-- Called when this task is ending, for any reason.
-- It is typically not necessary to add code to this function.
function shutdown()
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
