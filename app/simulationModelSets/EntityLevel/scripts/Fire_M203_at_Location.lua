-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables
--
myState = "start"
myHeading = 0.0
myTaskId = -1
myDiguyTaskId = -1
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
--  taskParameters.TargetLocation Type: Location3D - Location to fire at
--  taskParameters.MunitionType Type: String (weapon name) - Kind of grenade to fire


-- Called when the task first starts. Never called again.
function init()


   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   --Turn towards target,throw grenade, store weapon,diguy animation, return weapon
   if ( myState == "start") then
      -- get the heading
      local loc = this:getLocation3D()
      local tgtVector = loc:vectorToLoc3D(taskParameters.TargetLocation)
      myLocation = taskParameters.TargetLocation
      myHeading =  tgtVector:getBearing();	
      -- turn to heading]
      myTaskId = vrf:startSubtask("turn-to-heading",{heading = myHeading})
      myState = "turning"
   elseif ( myState == "turning"  ) then
      --Task the entity to throw the grenade and do diguy animation
      if (vrf:isSubtaskComplete(myTaskId) ) then
         myTaskId = vrf:startSubtask("Fire_For_Effect_on_Location",{location=myLocation,munition=taskParameters.MunitionType,numRnds =1,heightAboveTerrain = 0.0})
         myDiguyTaskId = vrf:startSubtask("di-guy-animation",{di_guy_animation_task_kind = "stand_fire_m203",di_guy_animation_duration = 0})
         myState = "throwing"
      end
   elseif ( myState == "throwing" ) then
      if ( vrf:isSubtaskComplete(myTaskId) and vrf:isSubtaskComplete(myDiguyTaskId) ) then
         myState = "complete"
      end
   elseif ( myState == "complete") then
      -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
      vrf:endTask(true)
   else
      -- We have some unknown state just end the task
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
