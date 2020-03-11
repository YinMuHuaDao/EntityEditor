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

checkpointState.lookAtObject = nil

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(3)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()

   -- Looking around while prone looks a bit odd
   if (this:getLifeformPosture() == LifeformPosture.StringToEnum("prone") or
      this:getLifeformPosture() == LifeformPosture.StringToEnum("crawling")) then
      return false
   end

   -- Random check each check whether or not to look at something:
   if (math.random(100) < 50) then
      return false
   end
   
   local lookObj = findLookAtObject()
   if (lookObj ~= nil) then
      printVerbose("Look at ", lookObj)
      checkpointState.lookAtObject = lookObj
      return true
   end
   return false
end

-- Called when the task first starts. Never called again.
function init()

   vrf:executeSetData("set-look-at-point", {target_object=checkpointState.lookAtObject, look_at_type=1})
   -- Set the tick period for this script.
   vrf:setTickPeriod(1)
   checkpointState.lookStartTime = vrf:getSimulationTime()
end

-- Called each tick while this task is active.
function tick()
   if (checkpointState.lookAtObject == nil or not checkpointState.lookAtObject:isValid()) then
      vrf:endTask(false)
      return
   end
   
   --printWarn("Looking at ", checkpointState.lookAtObject:getLocation3D())
   --vrf:updateTaskVisualization("lookAtPoint", "point", {color={255, 0, 255, 128}, size=10, location=checkpointState.lookAtObject:getLocation3D()})
   
   if (vrf:getSimulationTime() > checkpointState.lookStartTime + 3) then   
      vrf:endTask(true)  
   elseif (not isInLookArea(checkpointState.lookAtObject)) then
      vrf:endTask(true)
   end

end

-- Find an object to look at and returns it.
-- Returns  nil if none found
function findLookAtObject()
   local nearbyObjects = vrf:getSimObjectsNearWithFilter(
      this:getLocation3D(), 10, {ignore={this}, types={EntityType.Lifeform(),  EntityType.Platform()}})
   local goodTargets = {}
   for i, nearObj in ipairs(nearbyObjects) do      
      if (isInLookArea(nearObj) and not nearObj:isDestroyed()) then
         table.insert(goodTargets, nearObj)
      end
   end
   
   if (#goodTargets > 0) then
      return goodTargets[math.random(#goodTargets)]
   end
   return nil
end

-- Returns true if this object is within a valid area to look at
function isInLookArea(simObject)
   local vecTo = this:getLocation3D():vectorToLoc3D(simObject:getLocation3D())
   local headingDiff = vecTo:headingDiff(this:getDirection3D())
   if (math.abs(headingDiff) < math.rad(45)) then
      return true
   end
   return false
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
   -- Stop Looking
   vrf:executeSetData("set-look-at-point", {look_at_type=3})
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
