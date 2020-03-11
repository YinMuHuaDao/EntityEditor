-- This script is a reactive behavior for aggregates. It is intended to be enabled
-- by inclusion in a weapon system that uses torpedo munitions (munitions must
-- have "Torpedo" in their system name).
-- When activated, it will look for threats within the given range
-- and engage them with an anti-ship torpedo weapon that can be used in the 
-- current postures, and has the range. Since the weapon is a torpedo, it is assumed
-- that all weapons found can engage a submarine at any depth.
--
-- The script looks for targets and ready weapons in the check function; this info
-- is passed to the tick function in global variables. In the tick function, one
-- target and one weapon are selected. The script engages once in each
-- activation, returning to the check function for subsequent attacks against the same 
-- or additional targets.

local DEBUG_DETAIL = true
-- Debug information in the check function:
local DEBUG_DETAIL_CHECK = true

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Global Variables. Global variables get saved when a scenario gets checkpointed. 
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.defenseRadius Type: Real Unit: meters - Distance from entity center at which threats will be engaged. If 0, uses the max range of anti-air weapon systems.
--  taskParameters.reactivetask_priority Type: Integer - 
--  taskParameters.reactivetask_enabled Type: Bool (on/off) - 

-- This entire script can be copied and made into a new script for a different weapon
-- category. These two constants must be changed. 
local WEAPON_CATEGORY = "Anti-Ship"
local TARGET_TYPES = {EntityType.AggregateSurface(), EntityType.AggregateSubsurface()}
-- Note also in this script, the weapon name must have "Torpedo" in it.
function matchesTargetTypes(entityType)
   local i, t
   for i, t in pairs(TARGET_TYPES) do
      if vrf:entityTypeMatches(entityType, t) then
         return true
      end
   end
   return false
end

-- List of eligible weapon systems. Keyed on name, 
-- with {range, strength} in each entry.
-- Initialized in the check() function rather than the checkInit() function to
-- make sure that the IF Power list has been populated, and to allow updates
-- if the SMS has been changed after a scenario save.
local validWeaponList = nil 

-- Weapons that can be used in the current posture, and that have ammo.
-- This list is updated in the check function, and when a target is found
-- it is used by the tick function to select a weapon.
-- A subset of validWeaponList.
-- A global because if the scenario is saved during a tick, the check 
-- function will not be run again on scenario load.
readyWeapons = {}
-- A list of valid targets (entities) generated in the check function, then used in the 
-- tick function.
-- Keyed on target entity name; each item contains {range, strength} where range is 2D.
targets = {}

attackSubtaskId = -1
-- Indicates previous state of weapons being ready; used to print a message (once)
-- when this state changes.
local weaponsReady = true

function hasAmmo(weaponName)
   local result = false
   -- refresh count
   local ammoStatus = this:getStatePropertyMapItem("Ammunition-Categories", weaponName)

   if ammoStatus ~= nil then
      -- the Ammunition Categories count is kept as a float and reduced with
      -- decreasing health; it could be a number < 1, but > 0. The Ammunition
      -- state in that case is kept at 1 (see Use_Supplies.lua) until it is 
      -- used or health falls all of the way to 0. So allow firing here if
      -- ammo is > 0.
      if ammoStatus.Count > 0 then
         result = true
      end
      
   end
   return result
end


-- This function goes through the IF power table and finds the munitions
-- of the indicated type (WEAPON_CATEGORY).
-- It returns a table of these munitions/weapons.
-- Weapons that can't be used in the current posture, or that don't have ammo,
-- are included because this is an ongoing reaction and that status may change.
function getValidWeapons()
   local validWeapons = {}
   
   local allIFWeapons = this:getStateProperty("Indirect-Fire-Power")
   local ammoByCategory = this:getStateProperty("Ammunition-Categories")
   if allIFWeapons == nil or
      ammoByCategory == nil then
      
      printWarn(vrf:trUtf8("Error: React to Naval with Torpedo: Parameter property(s) nil"))
      return validWeapons
   end
   
-- Get the WEAPON_TYPE systems
   local weapon = ""
   local weaponInfo = nil
   local foundWeapon = false
   local myPosture = this:getStateProperty("Posture")
   
   for weapon, weaponInfo in pairs(allIFWeapons) do
      if DEBUG_DETAIL then
         printDebug("Considering weapon ", weapon)
      end
      if weaponInfo["Damage-Type"] == WEAPON_CATEGORY 
         and string.find(weapon, "Torpedo") ~= nil 
         then
         
         local weapRange = weaponInfo["Range"]
         local weapStrength = weaponInfo["Strength-Per-Attack"]
         if weapRange ~= nil then
                  
            validWeapons[weapon] = 
               {range = weapRange, strength = weapStrength}
            if DEBUG_DETAIL then
               printDebug(".  Adding ", weapon, ", range ", 
                  weapRange, ", strength ", weapStrength)
            end
         end
      end
   end
   return validWeapons
end

--Looks through all the weapons in the list to make sure they have ammo
--and can be used in the given posture.
--Returns a list of weapons that are ready.
function findReadyWeapons(weaponList, myPosture)
   local ready = {}
   local name, info
   for name, info in pairs(weaponList) do
      local weapProperty = this:getStatePropertyMapItem("Indirect-Fire-Power", name)
      if hasAmmo(name) and
         postureAllowsWeaponUse(weapProperty, myPosture)
         then
         
         ready[name] = info
      end
      
   end
   return ready
end

-- Determines if the bandit is within range of some ready weapon.
-- Returns a boolean indicating this, and the bandit's range.
function canEngageBandit(bandit, readyWeapons)
   local weapon, weaponInfo
   local canEngage = false
   local banditLoc = bandit:getLocation3D()
   
   -- Compute the 2D range to the contact
   banditLoc = Location3D(banditLoc:getLat(), banditLoc:getLon(), 0)
   local myLatLon = this:getLocation3D()
   myLatLon = Location3D(myLatLon:getLat(), myLatLon:getLon(), 0)
   local banditRange = myLatLon:distanceToLocation3D(banditLoc)
   
   for weapon, weaponInfo in pairs(readyWeapons) do
      if DEBUG_DETAIL_CHECK then
         printDebug(".   Weapon ", weapon, ", range ", weaponInfo.range)
      end
      -- Check range 
      if banditRange <= weaponInfo.range then
         
         canEngage = true
         break
      elseif DEBUG_DETAIL then
         if banditRange > weaponInfo.range then
            printDebug(".  .  Target range ", banditRange,
               " is too far.")
         end
      end
   end
   return canEngage, banditRange
end
--================================================================================
-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(5.0)
   vrf:setRespondToNewSensorContacts(true)
   if DEBUG_DETAIL then
      printDebug("React to Naval with Torpedo: checkInit")
   end
end
-----------------------------------------------
-- Called each tick period for this script while enabled but not in the active state.
function check()
   if DEBUG_DETAIL_CHECK then
      printDebug(string.format("\n%.3f React to Naval with Torpedo; checking for threats.",
         vrf:getSimulationTime()))
   end
   if this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("React to Naval with Torpedo: Cannot attack while embarked."))
      return false
   end
   
   local whenFiredUpon = false
   local attackingEnemies = {}
   local rulesOfEngagement = this:getRulesOfEngagement()
   if rulesOfEngagement == "hold-fire" then
      return false
   elseif rulesOfEngagement == "fire-when-fired-upon" then
      -- Make a list of entities who are attacking us.
      whenFiredUpon = true
      local currentAttacksDefending = this:getStateProperty("Attacks-Defending")
      for attackIndex,attack in pairs(currentAttacksDefending) do
         attackingEnemies[attack.Attacker] = true
      end
   end
   
   -- Initialize validWeaponList if necessary
   if validWeaponList == nil then
      validWeaponList = getValidWeapons()
      if next(validWeaponList) == nil then
         printWarn(vrf:trUtf8("React to Naval with Torpedo: No valid anti-surface weapons."))
         disableReaction(vrf:getScriptId())
         validWeaponList = nil
         return false
      end
   end
   
   -- Update ready weapons
   readyWeapons = findReadyWeapons(validWeaponList, this:getStateProperty("Posture"))
   -- Print out a warning message once, until the state changes.
   if next(readyWeapons) == nil then
      if weaponsReady then
         printWarn(vrf:trUtf8("React to Naval with Torpedo: No torpedoes ready."))
         weaponsReady = false
      end
      return false
   else
      if not weaponsReady then
         printWarn(vrf:trUtf8("React to Naval with Torpedo: Torpedoes ready."))
         weaponsReady = true
      end
   end
      
   -- See if there are threats
   targets = {}
   local contacts = this:getAllHostileContacts()
   if next(contacts) == nil then
      if DEBUG_DETAIL_CHECK then
         printDebug(".  No contacts.")
      end
      return false
   else
      local targetFound = false
      local i, contact
      for i, contact in ipairs(contacts) do
         if not contact:isDestroyed() then
            local contactType = contact:getEntityType()
            if matchesTargetTypes(contactType) then
               if DEBUG_DETAIL_CHECK then
                  printDebug(".  Considering contact ", contact:getName())
               end
               
               local canEngage = true
               if whenFiredUpon then
                  canEngage = attackingEnemies[contact:getUUID()]
               end	
	       
               if canEngage then
                  local canEngage, range 
                  canEngage, range = canEngageBandit(contact, readyWeapons)
                  if DEBUG_DETAIL_CHECK then
                     printDebug(".   Range ", range, 
                        " Can engage? ", canEngage)
                  end
                  if canEngage and
                     range < taskParameters.defenseRadius then
                     
                     targetFound = true
                     targets[contact:getUUID()] = {range = range}
                     if DEBUG_DETAIL_CHECK then 
                        printDebug(".   Found valid target ", contact:getName())
                     end
                  end
               end
            end
         end
      end
      return targetFound
   end
   return false
end
--==================================================================================
-- Picks a target and a weapon to engage it with.
-- Returns target, weapon.
-- 
-- For now, pick the closest target, and the highest-strength weapon.
function selectTargetAndWeapon(targets, readyWeapons)
   local target, targetInfo, weapon, weaponInfo
   local minDistance = 1e10
   local bestTarget = next(targets)
   for target, targetInfo in pairs(targets) do
      if targetInfo.range < minDistance then
         bestTarget = target
         minDistance = targetInfo.range
      end
   end
   
   targetInfo = targets[bestTarget]
   local bestWeapon = next(readyWeapons)
   local highestStrength = 0
   for weapon, weaponInfo in pairs(readyWeapons) do
      if targetInfo.range <= weaponInfo.range then
         
         if weaponInfo.strength > highestStrength then
            bestWeapon = weapon
            highestStrength = weaponInfo.strength
         end
      end
   end
   return bestTarget, bestWeapon
end
--==================================================================================
-- Called when the task first starts. Never called again.
function init()
   if DEBUG_DETAIL then
      printDebug("React to Naval with Torpedo: init reaction")
   end
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   if DEBUG_DETAIL then
      printDebug(string.format("%.3f React to Naval with Torpedo: tick",
         vrf:getSimulationTime()))
   end
   
   if attackSubtaskId == -1 then
      local target
      local weapon
      target, weapon = selectTargetAndWeapon(targets, readyWeapons)
      if DEBUG_DETAIL then
         printDebug(string.format("\n%.3f React to Naval with Torpedo: attacking threat %s with %s",
            vrf:getSimulationTime(), target, weapon))
      end
      attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
         {NumberOfAttacks=1, 
          TargetEntity = target,
          Weapon = weapon,
          CheckRange=true,
          Instantaneous=true,
          IsIndirect = false})
          
   else
      if vrf:isSubtaskComplete(attackSubtaskId) then
         attackSubtaskId = -1
         vrf:endTask(true)
      end
   end

end

--====================================================================================
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



-- Called when a reactive task is disabled (check will no longer called)
-- It is typically not necessary to add code to this function.
function disable()
end
