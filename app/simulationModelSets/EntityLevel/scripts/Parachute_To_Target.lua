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
--  taskParameters.targetObject Type: SimObject
--  taskParameters.musterPoint Type: SimObject - If specified, after landing, the object will move to this point.
--  taskParameters.deployParachuteAltitude Type: Real Unit: meters
--  taskParameters.deployAltIsAgl Type: Bool (on/off) - When checked, the deploy altitude is AGL. When unchecked, it is above Sea Level.

checkpointState.startEmbarked = false
checkpointState.disembarkSubtaskId = -1
checkpointState.parachuteSubtaskId = -1
checkpointState.moveToSubtaskId = -1
checkpointState.targetObject = -1
checkpointState.musterPoint = -1
checkpointState.deleteTarget = false
checkpointState.deleteMuster = false
checkpointState.previousRulesOfEngagement = "fire-at-will"

function setupPoints()

   if taskParameters.targetObject:isValid() then
      checkpointState.targetObject = taskParameters.targetObject
   else
      checkpointState.targetObject = vrf:createWaypoint({
         location = taskParameters.targetLocation, publish = false})
      checkpointState.deleteTarget = true
   end
   
   if taskParameters.useMusterLocation == true then
      if taskParameters.musterPoint:isValid() then
         checkpointState.musterPoint = taskParameters.musterPoint
      elseif taskParameters.musterLocation ~= this:getLocation3D() then
         checkpointState.musterPoint = vrf:createWaypoint({
            location = taskParameters.musterLocation, publish = false})
         checkpointState.deleteMuster = true
      else
         checkpointState.musterPoint = checkpointState.targetObject
      end
   end

end

-- Called when the task first starts. Never called again.
function init()
   
   --Send this first so the task doesn't deploy the parachute too early.
   vrf:executeSetData("Deploy_Parachute_Altitude", {
      deployAltitude = taskParameters.deployParachuteAltitude,
      deployAltitudeIsAgl = taskParameters.deployAltIsAgl})

   local parent = this:getEmbarkedOn()
   checkpointState.startEmbarked = parent:isValid()
   
   setupPoints()
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)

end

-- Called each tick while this task is active.
function tick()
   
   --Disembark if necessary
   if checkpointState.startEmbarked and checkpointState.disembarkSubtaskId == -1 then
      local parent = this:getEmbarkedOn()
      if vrf:entityTypeMatches(parent:getEntityType(), EntityType.PlatformAir()) then
         checkpointState.disembarkSubtaskId = vrf:startSubtask("disembark-entity", {});
      else  
         doneWithWaypoint = true
         vrf:endTask(true)
      end  
   
   --If we started not embarked, or finished embarking, start parachuting to the target.
   elseif (not checkpointState.startEmbarked or vrf:isSubtaskComplete(checkpointState.disembarkSubtaskId)) and checkpointState.parachuteSubtaskId == -1 then
      checkpointState.previousRulesOfEngagement = this:getRulesOfEngagement()
      vrf:executeSetData("set-engagement-rules", {engagement_rules = "hold-fire"})
      checkpointState.parachuteSubtaskId = vrf:startSubtask("Control_Parachute", {
         destination = checkpointState.targetObject, 
         deployParachuteAltitude=taskParameters.deployParachuteAltitude,
         deployAltIsAgl = taskParameters.deployAltIsAgl})

   --Once the parachute task is done, move to the target.
   elseif (checkpointState.parachuteSubtaskId ~= -1 and vrf:isSubtaskComplete(checkpointState.parachuteSubtaskId)) and checkpointState.moveToSubtaskId == -1 then
      vrf:executeSetData("set-engagement-rules", {engagement_rules = checkpointState.previousRulesOfEngagement})
      if checkpointState.musterPoint ~= -1 then
         checkpointState.moveToSubtaskId = vrf:startSubtask("move-to", {control_point = checkpointState.musterPoint})
      else
         checkpointState.moveToSubtaskId = vrf:startSubtask("move-to", {control_point = checkpointState.targetObject})
      end
      
   --End the task once we've reached the target on the ground.
   elseif checkpointState.moveToSubtaskId ~= -1 and vrf:isSubtaskComplete(checkpointState.moveToSubtaskId) then
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
   setupPoints()
end


-- Called when this task is ending, for any reason.
-- It is typically not necessary to add code to this function.
function shutdown()
   if checkpointState.deleteTarget then
      vrf:deleteObject(checkpointState.targetObject)
   end
   if checkpointState.deleteMuster then
      vrf:deleteObject(checkpointState.musterPoint)
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
