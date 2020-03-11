-- This script finds all possible targets for EW attack and
-- generates the interactions to attack them. It runs automatically 
-- in the background.

-- To dump detailed information to the entity debug console
DEBUG_DETAIL = true

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- For debugging to the sim console
function dumpJammers()
   printWarn("Jammer list:")
   for k, v in pairs(jammerSystems) do
      printWarn(string.format("%s: type \"%s\", strength %f, range %f",
         k, v.jamtype, v.strength, v.range))
      printWarn(".   Allowed postures:")
      for k, v in pairs(v.postures) do
         printWarn(string.format(".   .   %s", k))
      end
   end
end

-- Test to determine if the system is a jammer.
-- This is assumed to be the case if the system has "jammer" in
-- the name. The case of the letters is ignored.
function isJammer(systemName)
   local lowerName = string.lower(systemName)
   local index = string.find(lowerName, "jammer")
   return index ~= nil
end

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- A table of the emitter sytems by name, with type, strength, range and
-- [allowed] postures stored for each system. "Postures" is a list (table)
-- of strings of postures.
-- Created at init time.
local jammerSystems = {}
local maxRange = 0 -- The maximum range of all jammers--to set a limit on 
            --how big a radius to look for targets
            
function initJammers()
   -- Get a list of all jammer systems on the entity
   local systemNames = this:getSystemNames()
   local systemName
   local i
   local system
   local err
   local strength
   local range
   local jammerType
   local jammerPostures
   
   for i, systemName in ipairs(systemNames) do
      if isJammer(systemName) then
         system = this:getSystem(systemName)
         if (system ~= nil) then
            strength, err = system:getAttribute("jamming-strength")
            if not err and strength > 0.0 then
               range, err = system:getAttribute("jamming-range")
               if not err then
                  jammerType, err = system:getAttribute("jammer-type")
                  if not err then
                     jammerPostures, err = system:getAttribute("allowed-postures")
                     if not err then
                        local postureTable = getPostureTableFromString(jammerPostures)
                        local jammerAttributes = {strength = strength,
                           range = range, jamtype = jammerType,
                           postures = postureTable}
                        jammerSystems[systemName] = jammerAttributes
                        maxRange = math.max(range, maxRange)
                     else
                        printWarn("Jammer ", systemName, ": can't get allowed postures.")
                     end
                  else
                     printWarn("Jammer ", systemName, ": can't get type.")
                  end
               else
                  printWarn("Jammer ", systemName, ": can't get range.")
               end
            else
               printWarn("Jammer ", systemName, " has no strength.")
            end
         else
            printWarn("Jammer ", systemName, ": can't find system.")
         end
      end
   end
   -- if DEBUG_DETAIL then
      -- dumpJammers()
   -- end
end

-- Do this outside of init() in case the entity configuration is changed and a saved
-- scenario is run; this will cause the new configuration to be used in the scenario.
initJammers()

local myForce  = this:getForceType()
local jammerStrengthOn=0 -- Shared between functions during tick

-- Compute the modifier based on range.
-- Square-law dropoff. Returns 1.0 out to 1km,
-- then 1/r^2, where r is in km.
-- Max is used only to cut off the effect at that range.
function rangeModifier(max, range)
   if range > max then
      return 0.0
   else
      range = math.max(range, 1000.0)
      return 1e6/(range * range)
   end
end

-- Called when the task first starts. Never called again.
function init()
   vrf:setTickPeriod(5)   
end

function sendEW(target, attackType, strength, stop)
   local influenceParams = { 
      InfluenceType = attackType,
      Strength = strength,
      StopInfluence = stop}
   vrf:sendInfluence(target, "Jamming", influenceParams)	
         
end

-- Stop all existing attacks
function stopAllAttacks()

   local clearProperty = false
   local currentAttacks = this:getStateProperty("EW-Attacks")
   
   -- Loop through our current attacks. Stop them.
   for attackIndex,attack in pairs(currentAttacks) do
   
      clearProperty = true
      local target = vrf:getSimObjectByUUID(attack.Target)
      
      if(target ~= nil) then
         --  Valid attack, stop it.
         sendEW(target, attack.Type, attack.Strength, 
            true)
      end      
            
   end   
   
   -- Some attacks were stopped
   if(clearProperty) then
      this:setStateProperty("EW-Attacks", {})
   end
   
end

-- Returns a table of targets and jamming types with a strength for each.
-- If multiple jammers are on with the same jamming type, it only uses the
-- strongest strength.
-- Uses jammerSystems and maxRange
function findTargets(activeJammers)

   local targetList = {}
   
   -- If this entity is embarked it can't attack
   if(this:getEmbarkedOn():isValid()) then
      return targetList
   end
   
   local currentLoc = this:getLocation3D()
   -- Get all hostile contacts. 
   -- TMP -- bug, that getSimObjectsNear isn't working?
   local entities = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), maxRange,
      {types={EntityType.Aggregate()}})
--   local entities = vrf:getVrfObjects()   
   
   for entityNum,entity in pairs(entities) do
   
      -- Ignore entity if not an aggregate, if the same force, or if health is 0.
      local entHealth = entity:getStateProperty("Health")
      if( entity:isAggregate() and entity ~= this and
         entity:getForceType() ~= myForce  and
         entHealth and entHealth > 0 ) then 
            
         if DEBUG_DETAIL then
            printDebug("Checking entity ", entity:getName())
         end
         -- check center-to-center range
         local entityLoc = entity:getLocation3D()
         local distance =  currentLoc:distanceToLocation3D(entityLoc)
          
         for jammerName, attributes in pairs(activeJammers) do
            
            -- Ignore this jammer if it doesn't have the range.
            if attributes["range"] > distance then
             
               -- Found a target. If there is already an entry in the target list
               -- for this jamming type, take the max of the strength there 
               -- and the strength of this jammer.
               local entityName = entity:getUUID()
               local jammingType = attributes["jamtype"]
               local jammingStrength = math.floor(attributes["strength"] * 
                  rangeModifier(attributes["range"], distance))
               if (targetList[entityName] == nil) then targetList[entityName] = {} end
               if targetList[entityName][jammingType] == nil then
                  targetList[entityName][jammingType] = jammingStrength
               else
                  targetList[entityName][jammingType] = math.max(jammingStrength,
                     targetList[entityName][jammingType])
               end
               if DEBUG_DETAIL then
                  printDebug(string.format(".   Attacking %s with strength %f, type %s",
                     entity:getName(), jammingStrength, jammingType))
               end
            else
               if DEBUG_DETAIL then
                  printDebug(string.format(".   Out of range (%.f)",
                     distance))
               end
            end
         end
      end
   end

   return targetList
end

function updateAttacks(targetList, currentAttacks)
   
   local updated = false
   local stoppedAttacks = {}
   local numTargets = 0
   
   for tIndex,target in pairs(targetList) do numTargets = numTargets + 1 end   
   
   -- Loop through our current attacks. Stop them if:
   --  - the target isn't a valid entity
   --  - the target isn't on the target list this tick
   --  - the attack type isn't on the target list this tick
   -- Also, if the attack strength has changed, then send
   -- a new influence with the updated strength, and
   -- remove that attack from the [new] targets list.
   for attackIndex,attack in pairs(currentAttacks) do
      
      local target = vrf:getSimObjectByUUID(attack.Target)      
      if (target == nil) then
         -- Seems to be an invalid attack
         table.insert(stoppedAttacks, attackIndex)
	 
         -- Make sure we remove this from the target list
         targetList[attack.Target] = nil	  
         updated = true	 
      else
         local newCombatPower = nil
         if (targetList[attack.Target] ~= nil ) then
            newCombatPower = targetList[attack.Target][attack.Type]
         end
         if (newCombatPower == nil) then
            -- No attack on the target with this type this tick
            sendEW(target, attack.Type, 0, true)
            table.insert(stoppedAttacks, attackIndex)
            updated = true
         else
            if (attack.Strength ~= newCombatPower) then
               -- Attack needs to be updated
               attack.Strength = newCombatPower
               sendEW(target, attack.Type, newCombatPower, false)
               updated = true
            end	    
            -- Make sure we remove this from the target list. 
            --What remains will be new targets.
            targetList[attack.Target][attack.Type] = nil
         end	    
      end     
   end
   
   -- Some attacks may have been stopped stopped. Remove them from the list.
   for i, attackIndex in pairs(stoppedAttacks) do
      currentAttacks[attackIndex] = nil
   end
   
   -- Some targets may be new. Add them to the list.
   for targetName, attributes in pairs(targetList) do

      local target = vrf:getSimObjectByUUID(targetName) 
      if (target ~= nil) then
         for jammingType, jammingStrength in pairs(attributes) do
            table.insert(currentAttacks, 
               { ["Target"] = targetName, ["Type"] = jammingType, 
               ["Strength"] = jammingStrength })
            sendEW(target, jammingType, jammingStrength, false)
            updated = true
         end
      end
      
   end
   return updated 
end

-- Finds out which jammers are currently on, and can be used in 
-- the current posture.
--
-- Uses global variable jammerSystems.
--
-- Pre-tick derived properties:
--
function calculatePreTickDerivedProperties()
   local activeJammers = {}
   local posture = this:getStateProperty("Posture")
   jammerStrengthOn = 0
   
   -- Find out which jammers are on 
   for jammerName, status in pairs(jammerSystems) do
      local system = this:getSystem(jammerName)
      if system ~= nil then
         local isOn, err = system:getAttribute("is-jammer-on")
         if not err and isOn then
            jammerStrengthOn = jammerStrengthOn + status.strength
            if status.postures[posture] then
               activeJammers[jammerName] = status
            else
               printWarn(string.format("Jammer \"%s\" is on, but "..
                  "cannot be used in posture \"%s\"",
                  jammerName, posture))
            end
         end
      end
   end
   local empty = true;
   for k, v in pairs(activeJammers) do
      empty = false
      break
   end
   return activeJammers, empty
end
   
-- Updates any dynamic properties controlled by this task. 
-- Dynamic properties:
--     Attacks
function updateDynamicProperties(activeJammers, empty)
   local currentAttacks = this:getStateProperty("EW-Attacks")
   local targetList = {}
   
   if not empty then
      -- Find the targets we can possibly attack
      targetList = findTargets(activeJammers) 
   end
   -- Update our attacks
   if (updateAttacks(targetList, currentAttacks)) then
         
      -- Something changed, update the property
      this:setStateProperty("EW-Attacks", currentAttacks)
   end
end

-- Calculates remaining derived properties which are maintained by this script.
-- Derived properties:
--     None
function calculateDerivedProperties()
   this:setStateProperty("Jamming-Strength-On", jammerStrengthOn)
end

-- Called each tick while this task is active.
function tick()
   local activeJammers = {}
   local empty = true
   
   activeJammers, empty = calculatePreTickDerivedProperties()
   
   if DEBUG_DETAIL and jammerStrengthOn > 0.0 then
      printDebug(string.format("\n%.3f Make EW attacks",
         vrf:getSimulationTime()))
      printDebug(".  Total jammer strength now ", jammerStrengthOn)
   end
   updateDynamicProperties(activeJammers, empty)
   calculateDerivedProperties()  
      
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

-- Called when this entity is destroyed
function entityDestroyed()
   stopAllAttacks()
end
