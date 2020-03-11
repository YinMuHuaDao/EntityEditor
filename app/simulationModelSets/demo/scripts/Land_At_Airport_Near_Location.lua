-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "airportDataUtils"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
myAirportFeatures = nil
myRunwayFeatures = nil
mySubtaskId = -1

-- Task Parameters Available in Script
--  taskParameters.airportLocation Type: Location3D - Location to search for suitable airport


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   myRunwayFeatures = vrf:getFeaturesWithinRange(taskParameters.airportLocation, 50000, {query="MAK_RUNWAYS"})
   myAirportFeatures = vrf:getFeaturesWithinRange(taskParameters.airportLocation, 50000, {query="MAK_AIRPORTS"})  
end

-- Called each tick while this task is active.
function tick()
   if (mySubtaskId == -1) then
      if (myRunwayFeatures:isLoaded() and myAirportFeatures:isLoaded()) then
         local runwayObj = findSuitableRunway(taskParameters.airportLocation, myRunwayFeatures, myAirportFeatures, vrf:getWindDirection(), 1500, false)
         if (runwayObj == nil) then
            printWarn("No runway found")
            vrf:endTask(false)
         else
            mySubtaskId = vrf:startSubtask("Fixed_Wing_Land", {runway=runwayObj})
         end
      end
   else
      if (vrf:isSubtaskComplete(mySubtaskId)) then
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
