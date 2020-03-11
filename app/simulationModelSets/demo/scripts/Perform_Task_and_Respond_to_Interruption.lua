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

checkpointState.currentTask = -1
checkpointState.doResume = false

-- Task Parameters Available in Script
--  taskParameters.idleTask Type: String - Initial idle task to perform prior to being interrupted
--  taskParameters.resumeTask Type: String - Task to perform when resuming after interruption from a reactive task


-- Called when the task first starts. Never called again.
function init()

   checkpointState.currentTask = -1
   checkpointState.doResume = false

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   if checkpointState.currentTask == -1 then
      if checkpointState.doResume then
         checkpointState.currentTask = vrf:startSubtask(taskParameters.resumeTask, {})
      else
         checkpointState.currentTask = vrf:startSubtask(taskParameters.idleTask, {})
      end
   end
   
   if vrf:isSubtaskComplete(checkpointState.currentTask) then
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

   checkpointState.currentTask = -1
   checkpointState.doResume = true
   
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