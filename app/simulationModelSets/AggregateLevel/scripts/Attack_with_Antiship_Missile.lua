-- Attack with Antiship Missiles
--
-- This script will start a limited-munition-attack task
-- for each missile that is to be launched. Each one
-- is an instantaneous attack, and each is started
-- as soon as the previous one is complete. Multiple-missile
-- attacks are implemented as multiple limited-munition-attacks
-- so that they each resolve independently for P(hit).
-- Anti-ship missile attacks are not "indirect" attacks,
-- so it is possible to configure a ship such that the
-- missile combat effect is different for different sectors.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Set to true to print more detail to debug console
DEBUG_DETAIL = true

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
local allIFWeapons = this:getStateProperty("Indirect-Fire-Power")
local ammoByCategory = this:getStateProperty("Ammunition-Categories")
attackingWeapon = ""
attackSubtaskId = -1
attacksRemaining = taskParameters.numMissiles

-- Task Parameters Available in Script
--  taskParameters.targetShip Type: SimObject
--  taskParameters.numMissiles Type: Integer

function hasAmmo(weaponName)
   local result = false
   -- For weapon system ammo, weapon name and category are the same
   local ammoStatus = ammoByCategory[weaponName]
   if ammoStatus ~= nil then
      if ammoStatus.Count >= 1 then
         result = true
      end
   else
      printDebug("No ammo with category %s", weaponName)
      for ammoCatName, ammoCatInfo in pairs(ammoByCategory) do
         printDebug("__ %s", ammoCatName)
      end
   end
   return result
end

function inRange(weaponInfo, targetRange)
   local result = false
   if weaponInfo ~= nil then
      local maxRange = weaponInfo["Range"]
      if maxRange ~= nil then
         if targetRange <= maxRange then
            
            result = true
         end
      else
         printWarn(vrf:trUtf8("Attack with anti-ship: can't get range for weapon %1."):
            arg(weaponName))
      end
   end
   return result
end


-- Called when the task first starts. Never called again.
function init()
   if DEBUG_DETAIL then
      printDebug("Starting attack-with-antiship missile init function")
   end
   if allIFWeapons == nil or
      ammoByCategory == nil then
      
      printWarn(vrf:trUtf8("Error: Attack with Anti-ship: Parameter table(s) nil."))
      vrf:endTask(false)
   elseif taskParameters.targetShip == this then
      printWarn(vrf:trUtf8("Error: Attack with Anti-Surface: cannot target self."))
      vrf:endTask(false)
   elseif not taskParameters.targetShip:isValid() then
      printWarn(vrf:trUtf8("Error: Attack with Anti-Surface: no target selected."))
      vrf:endTask(false)   
   elseif not (vrf:entityTypeMatches(taskParameters.targetShip:getEntityType(), EntityType.AggregateSurface())
               or vrf:entityTypeMatches(taskParameters.targetShip:getEntityType(), EntityType.AggregateSubsurface())) then
      
      printWarn(vrf:trUtf8("Error: Attack with Anti-Surface: Target is not aggregate surface."))
      vrf:endTask(false)
   elseif this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Attack with Anti-Surface: Cannot attack while embarked."))
      vrf:endTask(false)
   else
      vrf:setTickPeriod(2.0)
      local targetLoc = taskParameters.targetShip:getLocation3D()
      local terrainAlt = vrf:getTerrainAltitude(targetLoc:getLat(), targetLoc:getLon())
      if targetLoc:getAlt() - terrainAlt < -0.5 then
         printWarn(vrf:trUtf8("Cannot attack submerged vessel with missile"))
         vrf:endTask(false)
      else      
         local rangeToTarget = this:getLocation3D():distanceToLocation3D(targetLoc)
         local weapon = ""
         local weaponInfo = nil
         local foundWeapon = false
         local wrongPosture = false
         local myPosture = this:getStateProperty("Posture")
         
         for weapon, weaponInfo in pairs(allIFWeapons) do
            if DEBUG_DETAIL then
               printDebug("Considering weapon ", weapon)
            end
            if string.find(string.lower(weapon), "missile") and
               weaponInfo["Damage-Type"] == "Anti-Ship" then
               if DEBUG_DETAIL then printDebug("...anti-ship type, missile") end

               if hasAmmo(weapon) and
                  inRange(weaponInfo, rangeToTarget) then
                  
                  if postureAllowsWeaponUse(weaponInfo, myPosture) then
                     attackingWeapon = weapon
                     foundWeapon = true
                     if DEBUG_DETAIL then
                        printDebug(string.format("Weapon %s found for attack",
                           attackingWeapon))
                     end
                     break
                  else
                     -- If a weapon can't be used just because of posture, warn the user
                     wrongPosture = true
                  end
               else
                  if DEBUG_DETAIL then
                     if not hasAmmo(weapon) then
                        printDebug("...No ammo")
                     end
                     if not inRange(weaponInfo, rangeToTarget) then
                        printDebug("...Out of range (range ", rangeToTarget, ")")
                     end
                  end
               end
            end
         end
         if not foundWeapon then
            printWarn(vrf:trUtf8("Cannot fire. Possible reasons include: no appropriate weapon system, out of ammunition, target out of range."))
            if wrongPosture then
               printWarn(vrf:trUtf8("At least one anti-ship missile cannot be used in the current posture."))
            end
            vrf:endTask(false)
         end
      end
   end
end

-- Called each tick while this task is active.
function tick()
   if attackSubtaskId == -1 then
      
     -- Start indirect fire subtask
      attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
         {NumberOfAttacks=1, 
          TargetEntity=taskParameters.targetShip,
          Weapon=attackingWeapon,
          CheckRange=true,
          Instantaneous=true,
          IsIndirect = false})
      attacksRemaining = attacksRemaining - 1
      if DEBUG_DETAIL then
         printDebug("Attack-with-antiship is launching a missile")
      end
      
   elseif vrf:isSubtaskComplete(attackSubtaskId) then
      if attacksRemaining > 0 and
         vrf:subtaskResult(attackSubtaskId) then
         
        -- Start indirect fire subtask
         attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
            {NumberOfAttacks=1, 
             TargetEntity=taskParameters.targetShip,
             Weapon=attackingWeapon,
             CheckRange=true,
             Instantaneous=true,
             IsIndirect = false})
         attacksRemaining = attacksRemaining - 1
         if DEBUG_DETAIL then
            printDebug("Attack-with-antiship is launching a missile")
         end
      else
         vrf:endTask(true)
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
