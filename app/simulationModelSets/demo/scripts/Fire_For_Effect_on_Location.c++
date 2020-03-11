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

myTaskId = -1
-- If you wish to change the mode, call setCheckpointMode(AllGlobals) to save all globals or setCheckpointMode(CheckpointStateOnly)
-- to save only those variables in the checkpointState table
-- They get re-initialized when a checkpointed scenario is loaded.
vrf:setCheckpointMode(CheckpointStateOnly)

-- Task Parameters Available in Script
--  taskParameters.location Type: Location3D - Location to fire upon
--  taskParameters.Munition Type: String (weapon name) - Selection weapon and muntion to fire
--  taskParameters.numRnds Type: Integer - Number of Rounds To Fire
--  taskParameters.heigthAboveTerrain Type: Real Unit: meters - Set height above terrain if air burst desired


-- Called when the task first starts. Never called again.
function init()


   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   if ( myTaskId < 0 ) then
   end
   
   if ( vrf:isSubtaskComplete(myTaskId) ) then
      -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
      -- Wrap it in an appropriate test for completion of the task.
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
