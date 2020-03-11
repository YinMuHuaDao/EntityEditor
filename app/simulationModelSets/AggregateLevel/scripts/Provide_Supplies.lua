-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Set to true to dump detailed debugging info to the console.
DEBUG_DETAIL = true



-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- "ground-ground", "air-ground" or "air-air"
supplyingMode = ""
  

-----------------------------------------------------------------
-- Local State:
-- The list of units within range that this unit has sent supply
-- influences to. A map with key = unit name and value = true.
unitsSupplying = {}

isProvidingSupplies = true

local supplySystem = nil
local resupplyRange = 100

function isSupply(systemName)
   local lowerName = string.lower(systemName)
   local index = string.find(lowerName, "supply")
   return index ~= nil
end

function initSystem()
   local supplySystemName = nil
   local sysNames = this:getSystemNames()
   local i, name
   local err = true
   for i, name in ipairs(sysNames) do
      if isSupply(name) then
         supplySystemName = name
         break
      end
   end
   if supplySystemName ~= nil then
      supplySystem, err = this:getSystem(supplySystemName)
   end
   if err then
      printWarn(vrf:trUtf8("Error: no supply system found for resupply task."))
   else 
      supplyingMode, err = supplySystem:getAttribute("supplying-mode")
      if err then
         printWarn(vrf:trUtf8("Error: no supplying-mode attribute found for supply system."))
      else
         supplyingMode = string.lower(supplyingMode)
         resupplyRange, err = supplySystem:getAttribute("resupply-range")
         if err then
            printWarn(vrf:trUtf8("Error: no resupply-range attribute found for supply system."))
         end
      end
   end
   return err
end

-- Get the supply system in the global part of the script so it can be updated if the
-- SMS is changed after the scenario is saved. The new system will be used when the 
-- scenario is run again.
local initError = initSystem()   

-------------------------
local isGroundUnit = true
if this:hasStateProperty("Is-Airborne") then
   isGroundUnit = false
end

local myForce = this:getForceType()

-- End of script load initialization

--------------------------------------------------------------------
-- Called when the task first starts. Never called again.
function init()
   if initError then
      vrf:endTask(false)
   end
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(5.0)
end
--------------------------------------------------------------------
function sendSupplying(targetName, stop)
   local influenceParams = { 
       StopInfluence = stop}
   local target = vrf:getSimObjectByUUID(targetName)
   vrf:sendInfluence(target, "ProvidingSupplies", influenceParams)	         
end

-- Stop all existing attacks
function stopAllSupplying()   
   -- Loop through our current attacks. Stop them.
   for receiver in pairs(unitsSupplying) do
      sendSupplying(receiver, true)
   end
   unitsSupplying = {}
end

-- Finds all friendly units in range. This means:
-- Aggregates only
-- Same force only
-- Airbone only if I am airborne
function getUnitsInRange()
   local inRangeUnits = {}
   
   -- If this entity is embarked it can't resupply
   if(this:getEmbarkedOn():isValid()) then
      return inRangeUnits
   end
   
   local unitRadius = this:getStateProperty("Physical-Footprint")
   if unitRadius == nil then
      unitRadius = 0
   end
   
   local rangedAggregates = vrf:getSimObjectsNearWithFilter(
      this:getLocation3D(),
      resupplyRange + unitRadius + 1000., --Expand radius by 1km
      {types = {EntityType.Aggregate()}})
   local entity, entityForce, amAirborne, entityAirborne
   local i
   if isGroundUnit then
      amAirborne = false
   else   
      amAirborne = this:getStateProperty("Is-Airborne")
   end
   for i, entity in ipairs(rangedAggregates) do
      if entity ~= this then
         -- Check the range explicitly; the get-near fn may return extras
         local range = this:getLocation3D():distanceToLocation3D(
            entity:getLocation3D())
         
         -- Find the radius of the other unit from its physical footprint. Don't even
         -- try for disaggregated units - they don't have physical footprints and we can't
         -- resupply them anyway.
         local entityRadius = nil
         if not entity:isDisaggregatedUnit() then
            entityRadius = entity:getStateProperty("Physical-Footprint")
         end
         
         -- Guard against units without radii (such as disaggregated units) which can't be resupplied
         if entityRadius ~= nil then
         
            if DEBUG_DETAIL then
               printDebug(string.format(".  Range to %s: %.0f; " ..
                  "Limit = resupply rg %.0f + css unit rad %.0f + entity rad %.0f",
                  entity:getName(), range, resupplyRange, 
                  unitRadius, entityRadius))
            end
            if range <= resupplyRange + unitRadius + entityRadius then
            
               entityForce = entity:getForceType()
               if myForce == entityForce then
                  entityAirborne = false
                  if entity:hasStateProperty("Is-Airborne") then               
                     if entity:getStateProperty("Is-Airborne") then
                     
                        entityAirborne = true
                     end
                  end
                  
                  if ((amAirborne and entityAirborne and 
                     supplyingMode == "air-air") or
                     
                     (amAirborne and not entityAirborne and
                     supplyingMode == "air-ground") or
                     
                     (not amAirborne and not entityAirborne and
                     supplyingMode == "ground-ground")) and
                     not entity:isDestroyed() then
                        
                     table.insert(inRangeUnits, entity:getUUID())
                     if DEBUG_DETAIL then
                        printDebug("Friendly unit in range: ", entity:getName())
                     end
                  end
               end
            end
         end
      end
   end
   return inRangeUnits
end

-- Identify units newly in range, and units newly out of range.
-- Takes table of all in-range units (names) as an argument, and uses
-- the global unitsSupplying list. Does NOT change the global list.
-- Returns these two sets in two tables:
-- The first table is a list of units indexed as 1, 2, 3, etc.
-- The second table (defunct units) is like the unitsSupplying table,
-- so has key-value pairs (name1, true), (name2, true), etc.
function getNewAndDefunct(inRangeUnits)
   local defunctUnits = table.copy(unitsSupplying)
   local newUnits = {}
   local i
   local inRangeUnit
   for i, inRangeUnit in ipairs(inRangeUnits) do
      local target = vrf:getSimObjectByUUID(inRangeUnit)
      if target == nil or defunctUnits[inRangeUnit] == nil or target:isDestroyed() then
         table.insert(newUnits, inRangeUnit)
      elseif target ~= nil and not target:isDestroyed() then
         defunctUnits[inRangeUnit] = nil
      end
   end
   return newUnits, defunctUnits
end

-- Finds current units in range, determines which
-- ones are new, determines which existing units are
-- now defunct; sends start or stop influences
-- and updates unitsSupplying appropriately.
function updateSuppliedUnits()
   local unitsInRange = getUnitsInRange()
   local newList
   local defunctList
   local i
   local unit
   newList, defunctList = getNewAndDefunct(unitsInRange)
   for i, unit in ipairs(newList) do
      unitsSupplying[unit] = true
      sendSupplying(unit, false)
      printInfo(vrf:trUtf8("Now supplying unit %1"):arg(unit))
   end
   for unit, i in pairs(defunctList) do
      unitsSupplying[unit] = nil
      sendSupplying(unit, true)
      printInfo(vrf:trUtf8("No longer supplying unit %1"):arg(unit))
   end
end

function canProvideSupplies()
   local can = true
   local attacks = this:getStateProperty("Attacks")
   if next(attacks) ~= nil then
      if DEBUG_DETAIL then
         printDebug(".  .  Can't provide supplies while attacking.")
      end
      return false
   end
   local defenses = this:getStateProperty("Attacks-Defending")
   if next(defenses) ~= nil then
      if DEBUG_DETAIL then
         printDebug(".  .  Can't provide supplies while defending.")
      end
      return false
   end
   
   local amAirborne = false
   if not isGroundUnit then
      if this:getStateProperty("Is-Airborne") then
         amAirborne = true
      end
   end   
   if amAirborne and supplyingMode == "ground-ground" then
      if DEBUG_DETAIL then
         printDebug(".  .  Can't provide supplies while airborne.")
      end
      return false
   elseif not amAirborne and supplyingMode ~= "ground-ground" then
      if DEBUG_DETAIL then
         printDebug(".  .  Can't provide supplies while not airborne.")
      end
      return false
   end

   if (this:isDestroyed()) then
      if DEBUG_DETAIL then
         printDebug(".  .  Can't provide supplies while destroyed.")
      end
      return false
   end

   return true
end

-- Called each tick while this task is active.
function tick()
   if initError then
      vrf:endTask(false)
      return
   end
   
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Resupplier",
         vrf:getSimulationTime()))
   end
   local stopOrdered = this:getStateProperty("Supplies-Stop-Ordered")
   local capable = canProvideSupplies()
   if not stopOrdered and capable then
      if not isProvidingSupplies then
         if DEBUG_DETAIL then
            printDebug(".  Able to provide supplies again.")
         end
         isProvidingSupplies = true
      end
      updateSuppliedUnits()
      
   elseif isProvidingSupplies then
      stopAllSupplying()
      isProvidingSupplies = false
      if DEBUG_DETAIL then
         printDebug("Stopping supply function")
      end
   end
end


-- Called immediately before a scenario checkpoint is saved when
-- this task is active.
-- It is typically not necessary to add code to this function.
function saveState()
end

-- Called immediately after a scenario checkpoint is loaded in which
-- this task is active.
-- It is typically not necessary to add code to this function.
-- Resend influence interactions to update for loaded scenario
function loadState()
   local i
   local unit

   for unit, i in pairs(unitsSupplying) do
      sendSupplying(unit, false)
   end
end
