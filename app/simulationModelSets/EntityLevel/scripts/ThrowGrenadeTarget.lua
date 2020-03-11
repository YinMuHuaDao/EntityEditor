-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables
--
checkpointState.myState = "start"
checkpointState.myHeading = 0.0
checkpointState.myTaskId = -1
checkpointState.myDiguyTaskId = -1
checkpointState.myDiguyHandItem = ""

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
--  taskParameters.target Type: SimObject - Target object to throw grenade at
--  taskParameters.munitionType Type: String (weapon name)


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.1)
end

-- Called each tick while this task is active.
function tick()
   --Turn towards target,throw grenade, store weapon,diguy animation, return weapon
   if ( checkpointState.myState == "start") then
      --Stow weapon before throwing
      vrf:executeSetData("set-lifeform-weapon-state",{lifeform_weapon_state = "weapon-stowed"})
      checkpointState.myDiguyHandItem = this:getDiGuyHandItem()
      vrf:executeSetData("set-di-guy-hand-item",{hand_item = "grenade" })
      checkpointState.myTaskId = vrf:startSubtask("wait-duration",{seconds_to_wait = 1.5})
      checkpointState.myState = "stowweapon"
   elseif ( checkpointState.myState == "stowweapon" ) then
      if (vrf:isSubtaskComplete(checkpointState.myTaskId) ) then
         -- get the heading
         local loc = this:getLocation3D()
         local tgtVector = loc:vectorToLoc3D(taskParameters.target:getLocation3D())
         checkpointState.myLocation = taskParameters.target:getLocation3D()
         checkpointState.myHeading =  tgtVector:getBearing();
         -- turn to heading
         checkpointState.myDiguyTaskId = vrf:startSubtask("di-guy-animation",{di_guy_animation_task_kind = "stand_ready_ambient_1",di_guy_animation_duration = 1})
         checkpointState.myTaskId = vrf:startSubtask("turn-to-heading",{heading = checkpointState.myHeading})
         checkpointState.myState = "turning"
      end
   elseif ( checkpointState.myState == "turning"  ) then
      --Task the entity to throw the grenade and do diguy animation
      if (vrf:isSubtaskComplete(checkpointState.myTaskId) ) then
         --vrf:executeSetData("set-di-guy-hand-item",{hand_item = })
         checkpointState.myTaskId = vrf:startSubtask("Fire_For_Effect_on_Target",{target=taskParameters.target,munition=taskParameters.munitionType,numRnds =1,heightAboveTerrain = 0.0})
         checkpointState.myDiguyTaskId = vrf:startSubtask("di-guy-animation",{di_guy_animation_task_kind = "throw_grenade",di_guy_animation_duration = 0})
         checkpointState.myState = "throwing"
      end
   elseif ( checkpointState.myState == "throwing" ) then
      if ( vrf:isSubtaskComplete(checkpointState.myTaskId) and vrf:isSubtaskComplete(checkpointState.myDiguyTaskId) ) then
         vrf:executeSetData("set-di-guy-hand-item",{hand_item = checkpointState.myDiguyHandItem})
         vrf:executeSetData("set-lifeform-weapon-state",{lifeform_weapon_state = "weapon-deployed"})
         -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
         vrf:endTask(true)
      end
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
