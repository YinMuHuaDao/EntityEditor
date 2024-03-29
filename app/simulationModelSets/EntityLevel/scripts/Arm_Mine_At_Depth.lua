-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.mine_depth Type: Real Unit: meters
--  taskParameters.explode_within_radius Type: Real Unit: meters
--  taskParameters.arm_time Type: Integer Unit: seconds

myState = 0
myArmAtTime = 0

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   vrf:executeSetData("set-ordered-altitude", {altitude = -taskParameters.mine_depth})
   proximitysensor:setDetectionProximity(taskParameters.explode_within_radius)
   proximitysensor:setObjectTypesToDetect(taskParameters.targets, taskParameters.hostile_only)
end

function almost(x, y, e)
   return (((x)<=((y)+(e))) and ((x)>=((y)-(e))))
end

-- Called each tick while this task is active.
function tick()
   -- If the mine is at the appropriate depth then check to see if there is an arm delay.  If there isn't, arm.  If there is then wait and then arm
   if (myState == 0) then
      if (almost(this:getLocation3D():getAlt(), -taskParameters.mine_depth, 1.0 * vrf:getTimeMultiplier())) then
         myState = 1
	      myArmAtTime = vrf:getExerciseTime() + taskParameters.arm_time
      end
   end
   
   if ((myState == 1) and (vrf:getExerciseTime() >= myArmAtTime)) then
      vrf:executeSetData("set-detonate", {fuse_type=3000, detonation_proximity=taskParameters.explode_within_radius})
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
