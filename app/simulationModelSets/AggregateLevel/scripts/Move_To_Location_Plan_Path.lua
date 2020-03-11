-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- navigation subtask
subTask = nil

-- Called when the task first starts. Never called again.
function init()
   vrf:setTickPeriod(0.5)
   
   local obstacleType, pathType
   local errorCode
   
   obstacleType, errorCode = vrf:getScriptAttribute("Obstacle-Feature-Query")
   if (errorCode) then
      obstacleType="MAK_OBSTACLE"
   end

   printDebug("Path plan obstacle query: " .. obstacleType)
   
   pathType, errorCode = vrf:getScriptAttribute("Path-Feature-Query")
   if (errorCode) then
      pathType="MAK_ROAD"   
   end
   
   printDebug("Path plan road query: " .. pathType)
   
   if (subTask ~= nil) then
      vrf:stopSubtask(subTask)
      subTask = nil
   end
   
   local params = {
      obstacleQuery=obstacleType,
      pathQuery=pathType,
      destination = taskParameters.destination,
      displayRoute = taskParameters.displayRoute }
      
   subTask = vrf:startSubtask("navigate-to-location", params)
end

-- Called each tick while this task is active.
function tick()
   if (not vrf:isSubtaskRunning(subTask)) then
      vrf:endTask(vrf:subtaskResult(subTask))
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
