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


local currentlyJammingList = {}
theJamStartTime = 0
-- Seconds of no new trackers before the jammer is turned off.
local THE_JAM_RECYCLYE_PERIOD = 600

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(1.0)
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

   local trackingEmitters = this:getStateProperty("tracking-emitters")
   if (trackingEmitters ~= nil and #trackingEmitters > 0) then
      return true;
   end
   -- Returning true will cause the reactive task to become active and will call init()
   -- and tick() until the task completes.
   return false
end

-- Called when the task first starts. Never called again.
function init()

   -- turn on the jammer
   vrf:executeSetData("Jammer_Enabled", {enabled=1}) 
   theJamStartTime = vrf:getExerciseTime()
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(1.0)
end

-- Called each tick while this task is active.
function tick()

   local trackingEmitters = this:getStateProperty("tracking-emitters")
   if (trackingEmitters ~= nil and #trackingEmitters > 0) then
      for i, uuid in ipairs(trackingEmitters) do
         local obj = vrf:getSimObjectByUUID(uuid)
	 if (obj ~= nil) then
	    if (not onJammingList(obj)) then
	       startJamming(obj)
	    end
	 end
      end
   end
   
   if (vrf:getExerciseTime() > theJamStartTime + THE_JAM_RECYCLYE_PERIOD) then
      stopAllJamming()
      vrf:endTask(true)
   end
end

function onJammingList(object)
   for i, o in ipairs(currentlyJammingList) do
      if (o == object) then
         return true
      end
   end
   return false
end

function stopAllJamming()
   for i, o in ipairs(currentlyJammingList) do
      vrf:executeSetData("Remove_Jamming_Target", {target=o})
   end
   currentlyJammingList={}
   vrf:executeSetData("Jammer_Enabled", {enabled=2})
end

function startJamming(obj)
   table.insert(currentlyJammingList, obj)
   vrf:executeSetData("Add_Jamming_Target", {target=obj})
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



-- Called when a reactive task is disabled (check will no longer called)
-- It is typically not necessary to add code to this function.
function disable()
end
