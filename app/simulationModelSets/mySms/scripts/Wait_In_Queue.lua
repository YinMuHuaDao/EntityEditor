-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables
--
-- Global variables get saved when a scenario gets checkpointed in one of the folowing way:
-- 1) If the checkpoint mode is AllGlobals all global variables defined will be saved as part of the save stat
-- 2) In setting CheckpointStateOnly, this means that the script will *only* save variables that are part of the checkpointState table.  If you remove this value, it will then
--    default to the behavior of sabing all globals
--
-- If you wish to change the mode, call setCheckpointMode(AllGlobals) to save all globals or setCheckpointMode(CheckpointStateOnly)
-- to save only those variables in the checkpointState table
-- They get re-initialized when a checkpointed scenario is loaded.
vrf:setCheckpointMode(CheckpointStateOnly)

-- Task Parameters Available in Script
--  taskParameters.queue Type: SimObject

-- Called when the task first starts. Never called again.
function init()
   if (not taskParameters.queue:isValid()) then
      vrf:endTask(false)
      return
   end
   checkpointState.state = "start"
   vrf:sendMessage(taskParameters.queue, "JoinQueue")
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   if (checkpointState.state == "moving") then
      if (vrf:isSubtaskComplete(checkpointState.subtaskId)) then
         checkpointState.state = "idle"
         vrf:sendMessage(taskParameters.queue, "InPosition")
         vrf:startSubtask("Civilian_Idle", {allowTalking = false})
      end
   end
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   -- vrf:endTask(true)

end

function moveToPosition(loc3D)
   vrf:stopAllSubtasks()
   checkpointState.state = "moving"
   checkpointState.subtaskId = vrf:startSubtask("move-to-location", {aiming_point=loc3D})
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
   vrf:sendMessage(taskParameters.queue, "LeaveQueue")
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)   
   local parsedMessage = {}
   for t in string.gmatch(message, "([^:]+)") do
      table.insert(parsedMessage, t)
   end
   
   if (parsedMessage[1] == "MoveTo") then
      local dest = Location3D(tonumber(parsedMessage[2]), tonumber(parsedMessage[3]), tonumber(parsedMessage[4]))
      moveToPosition(dest)
   elseif (parsedMessage[1] == "QueueRelease") then
      vrf:stopAllSubtasks()
      vrf:endTask(true)
   elseif (parsedMessage[1] == "QueueFull") then
      --printWarn("Queue is full")
      --vrf:endTask(false)
   end
end
