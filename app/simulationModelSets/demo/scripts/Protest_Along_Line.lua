-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

subtaskId = -1
idleTask = "Civilian_Protest"

local speedMultiplier = 1.25 -- make them move faster than normal Crowd Around behavior

-- Task Parameters Available in Script
--  taskParameters.line Type: SimObject - Line along which entities should protest
--  taskParameters.leftOrRight Type: Integer (0 - choice limit) - Should the crowd protest to the left or right of the line


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   
   -- If not already doing so, surround the location
   if subtaskId < 0 then
      surroundedLocation = currentObjectLocation
      subtaskId = vrf:startSubtask("Crowd_Along_Line",
         { line = taskParameters.line,
           leftOrRight = taskParameters.leftOrRight,
           idleTask = idleTask,
           speedMultiplier = speedMultiplier })
   end
   
   -- See if we are done
   if subtaskId > 0 and vrf:isSubtaskComplete(subtaskId) then
      vrf:endTask(true)
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
