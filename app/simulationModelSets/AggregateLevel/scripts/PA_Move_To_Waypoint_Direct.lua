-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.waypoint Type: SimObject

mySubtaskId = -1
myWaypointLocation = Location3D(0, 0, 0)

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   if (mySubtaskId == -1) then
      myWaypointLocation = taskParameters.waypoint:getLocation3D()
      mySubtaskId = vrf:startSubtask("PA_Move_To_Location_Direct", {location = myWaypointLocation, retrograde = taskParameters.retrograde})
   elseif (vrf:isSubtaskComplete(mySubtaskId)) then
      -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
      vrf:endTask(true)
    -- If the waypoint has been removed stop the task
   elseif (taskParameters.waypoint:isDeleted()) then
       printWarn(vrf:trUtf8("Waypoint has been deleted.  Stopping movement task"))
       vrf:endTask(true)
    -- If the waypoint has moved reissue subtask
   elseif (myWaypointLocation ~= taskParameters.waypoint:getLocation3D()) then
      vrf:stopAllSubtasks()
      mySubtaskId = -1
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
