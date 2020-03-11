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

-- TASK PARAMETERS (VRF TEAM DO NOT ERASE)
-- REACTIVE TASK FUNCTIONS START (VRF TEAM DO NOT MODIFY OR ERASE)
-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()

   -- Check if entity AI is enabled. If not, a reactive task should generally not
   -- run, as this means the entity is making a decision for itself about how to
   -- behave as the result of events within the scenario.
   local aiEnabled = this:getStateProperty(AIEnabledStateProperty)   
   if (aiEnabled ~= nil and not aiEnabled) then
      return false
   end

   -- Returning true will cause the reactive task to become active and will call init()
   -- and tick() until the task completes.
   return false
end
-- REACTIVE TASK FUNCTIONS END (VRF TEAM DO NOT MODIFY OR ERASE)
-- Called when the task first starts. Never called again.
function init()
-- REMOVE IF NOT SET BEGIN (VRF TEAM DO NOT ERASE)
   -- Since this is a set, it should tick while the simulation is paused
   vrf:setTickWhilePaused(true)
-- REMOVE IF NOT SET END (VRF TEAM DO NOT ERASE)

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
-- REMOVE IF NOT SET BEGIN (VRF TEAM DO NOT ERASE)
   -- endSet() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the set.
   vrf:endSet()
-- REMOVE IF NOT SET END (VRF TEAM DO NOT ERASE)
-- REMOVE IF NOT TASK BEGIN (VRF TEAM DO NOT ERASE)
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   vrf:endTask(true)
-- REMOVE IF NOT TASK END (VRF TEAM DO NOT ERASE)
end

-- REMOVE IF NOT TASK BEGIN (VRF TEAM DO NOT ERASE)
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
-- REMOVE IF NOT TASK END (VRF TEAM DO NOT ERASE)
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

-- REMOVE IF NOT TASK BEGIN (VRF TEAM DO NOT ERASE)
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
-- REMOVE IF NOT TASK END (VRF TEAM DO NOT ERASE)

-- REACTIVE TASK FUNCTIONS START (VRF TEAM DO NOT MODIFY OR ERASE)
-- Called when a reactive task is disabled (check will no longer called)
-- It is typically not necessary to add code to this function.
function disable()
end
-- REACTIVE TASK FUNCTIONS END (VRF TEAM DO NOT MODIFY OR ERASE)
