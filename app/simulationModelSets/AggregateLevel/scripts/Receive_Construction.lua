-- Receive_Construction.lua
-- Copyright 2014 by VT MAK
--
-- This file contains the script used to compute the percentage of
-- construction complete on an engineering object.
-- It is a "background" script that runs all of the time on a unit.
-- The script receives influences and processes ImproveEngineeringObject
-- types.

-- Set this to true to dump more info to the entity debug console.
DEBUG_DETAIL = true

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- *********** Constants used in the calculations
-- Evaluation inverval, in seconds
TICK_PERIOD = 5

-- *********** Global Variables. 
-- Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Previous tick time for comparison to current tick
previousUpdateTime = -1

-- List of units performing construction on this object
constructingUnits = {}

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(TICK_PERIOD)
   
   -- Get exercise time
   previousUpdateTime = vrf:getSimulationTime()
end

-- Called each tick while this task is active.
function tick()
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Receive Construction:",
         vrf:getSimulationTime()))
   end
   
   -- Determine amount of time since last tick
   local currentTime = vrf:getSimulationTime()
   local elapsedTime = currentTime - previousUpdateTime
   
   -- Add up all the construction that has occurred
   local totalConstruction = this:getStateProperty("Percent-Complete")
   for constructingUnit, constructionPerSec in pairs(constructingUnits) do
      totalConstruction = totalConstruction + (elapsedTime * constructionPerSec)
   end
   
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Total Construction: %.3f",
         currentTime, totalConstruction))
   end
   
   -- Cannot have total construction > 100 or < 0
   totalConstruction = math.min(100, totalConstruction)
   totalConstruction = math.max(0, totalConstruction)
      
   this:setStateProperty("Percent-Complete", totalConstruction) 
   
   -- Set previousUpdateTime for next tick
   previousUpdateTime = currentTime
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

-- Immediately adds construction.
function processImmediateConstruction(constructingUnit, strength)
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Processing immediate construction from %s.",
         vrf:getSimulationTime(), constructingUnit))
   end
      
   -- Convert strength (an integer value that comes from the Influence
   -- interaction) into a real value indicating construction % per second.
   -- The strength value is simply the percent constructed in an hour.
   -- For immediate construction we will realize the full value of this
   -- strength right now.
   local construction = strength/3600
   
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Immediate Construction: %.3f",
         vrf:getSimulationTime(), construction))
   end
   
   -- Add up all the construction that has occurred
   local totalConstruction = this:getStateProperty("Percent-Complete")
   totalConstruction = totalConstruction + construction
   
   -- Cannot have total construction > 100 or < 0
   totalConstruction = math.min(100, totalConstruction)
   totalConstruction = math.max(0, totalConstruction)
      
   this:setStateProperty("Percent-Complete", totalConstruction) 
end

-- Adds or updates information regarding construction being performed on this
-- object by another unit.
function processConstruction(constructingUnit, strength)
   
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Processing construction from %s.",
         vrf:getSimulationTime(), constructingUnit))
   end
      
   -- Convert strength (an integer value that comes from the Influence
   -- interaction) into a real value indicating construction % per second.
   -- The strength value is simply the percent constructed in an hour.
   local constructionPerSec = strength/3600
 
   -- See if construction is already ongoing
   local construction = constructingUnits[constructingUnit]
   if(construction ~= nil) then
      construction = constructionPerSec
      
      if DEBUG_DETAIL then
         printDebug("Updating construction from ", constructingUnit)
      end
   else
      constructingUnits[constructingUnit] = constructionPerSec
      
      if DEBUG_DETAIL then
         printDebug("New construction from ", constructingUnit)
      end
   end
end

-- Stops construction by the specified unit
function processStopConstruction(constructingUnit)
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Processing stop construction",
         vrf:getSimulationTime()))
   end
      
   -- Clear out construction from the specified unit
   if DEBUG_DETAIL then
      if(constructingUnits[constructingUnit] ~= nil) then
         printDebug("Stopping construction from ", constructingUnit)
      end
   end
   
   constructingUnits[constructingUnit] = nil   
end

-- Called whenever the entity receives an Influence interaction while
-- this task is active.
--   influencer is the SimObject sending the Influence.
--   influenceName is a string identifying the kind of Influence.
--   influenceParams is a table of optional Influence parameters.
function receiveInfluence(influencer, influenceName, influenceParams)

   if(influenceName == "ImproveEngineeringObject") then
      if(influenceParams.StopInfluence) then
         processStopConstruction(influencer:getUUID())
      elseif(influenceParams.Duration == 0) then
         processImmediateConstruction(influencer:getUUID(), influenceParams.Strength)
      else
         processConstruction(influencer:getUUID(), influenceParams.Strength)
      end
   elseif (influenceName == "DestroyEngineeringObject") then
   
      -- Destruction and Improvement are really the same, just inverse. Multiply destruction strength
      -- by -1 to get the negative construction strength.
      if(influenceParams.StopInfluence) then
         processStopConstruction(influencer:getUUID())
      else
         processConstruction(influencer:getUUID(), -1*influenceParams.Strength)
      end
   end

end
