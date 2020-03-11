-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables
--
-- Global variables get saved when a scenario gets checkpointed in one of the folowing way:
-- 1) If the checkpoint mode is AllGlobals all global variables defined will be saved as part of the save stat
-- 2) The current default behavior of CheckpointStateOnly will *only* save variables that are part of the checkpointState table
--
-- If you wish to change the mode, call setCheckpointMode(AllGlobals) to save all globals or setCheckpointMode(CheckpointStateOnly)
-- to save only those variables in the checkpointState table
-- They get re-initialized when a checkpointed scenario is loaded.
vrf:setCheckpointMode(CheckpointStateOnly)

checkpointState.state = "move"
checkpointState.subtaskId = -1

-- Task Parameters Available in Script
--  taskParameters.initialDestination Type: Location3D - The initial destination that the entity should reach before wandering.
--  taskParameters.isIndefinite Type: Integer (0 - choice limit) - Choose whether the entity will wander indefinitely or for a fixed amount of time.
--  taskParameters.wanderTime Type: Integer Unit: seconds
--  taskParameters.movementMode Type: Integer (0 - choice limit)
--  taskParameters.area Type: SimObject
--  taskParameters.destinationRestriction Type: Integer (0 - choice limit) - Wander will choose destinations fitting this restriction

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   checkpointState.state = "move"
   checkpointState.subtaskId = -1
end

-- Called each tick while this task is active.
function tick()

   if checkpointState.state == "move" then
      
      if checkpointState.subtaskId < 0 then
         checkpointState.subtaskId = vrf:startSubtask("move-to-location", {aiming_point = taskParameters.initialDestination})
      end
      
      if vrf:isSubtaskComplete(checkpointState.subtaskId) then
         checkpointState.state = "wander"
         checkpointState.subtaskId = -1
      end
      
   end

   if checkpointState.state == "wander" then
      
      if checkpointState.subtaskId < 0 then
         checkpointState.subtaskId = vrf:startSubtask("wander",
               {isIndefinite=taskParameters.isIndefinite,
                wanderTime=taskParameters.wanderTime,
                movementMode=taskParameters.movementMode,
                area=taskParameters.area,
                destinationRestriction=taskParameters.destinationRestriction})
      end
      
      if vrf:isSubtaskComplete(checkpointState.subtaskId) then
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
