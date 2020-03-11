-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

local DEBUG_DETAIL = false

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

subtaskId = -1
surroundedLocation = Location3D(0,0,0)
idleTask = "Civilian_Idle"

-- If object of interest moves more than the retaskDistance, then we will restart
-- our crowd_around_location subtask. This should NOT be used for moving objects,
-- but rather objects that can be occasionally re-placed.
local retaskDistance = 2

-- Task Parameters Available in Script
--  taskParameters.objectOfInterest Type: SimObject - The object to crowd around
--  taskParameters.minDistance Type: Distance - The minimum distance from the location of interest
--  taskParameters.idleTask Type: String - The task which will be given to each pedestrian when they arrive
--  taskParameters.speedMultiplier Type: Real - Chosen speed for each entity is multiplied by this value. Used to slow down or speed up entities.


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   if taskParameters.objectOfInterest:isValid() then
      local currentObjectLocation = taskParameters.objectOfInterest:getLocation3D()
      local currentDirection = taskParameters.objectOfInterest:getDirection3D()
      local boundingVolume, offset = taskParameters.objectOfInterest:getBoundingVolume()
      offset:setUp(0) -- ignore up offset
   
      if DEBUG_DETAIL then
         vrf:updateTaskVisualization("obj loc", "point", 
            {color={0,255,0,175}, size=1, location=currentObjectLocation})
      end
   
      local offsetVec = offset:makeVectorRefToDirection(currentDirection)
      currentObjectLocation = currentObjectLocation:addVector3D(offsetVec)
   
      if DEBUG_DETAIL then
         vrf:updateTaskVisualization("offset loc", "point", 
            {color={0,0,255,175}, size=1, location=currentObjectLocation})
      end
   
      -- If not already doing so, surround the object
      if subtaskId < 0 then
   
         local halfLength = boundingVolume:getForward()/2
         local halfWidth = boundingVolume:getRight()/2
         local radius = math.sqrt((halfLength * halfLength) + (halfWidth * halfWidth))
         local minDist = taskParameters.minDistance + radius
   
         surroundedLocation = currentObjectLocation
         subtaskId = vrf:startSubtask("Crowd_Around_Location",
            { locationOfInterest = surroundedLocation,
              minDistance = minDist,
              idleTask = taskParameters.idleTask,
              speedMultiplier = taskParameters.speedMultiplier,
              subordinatesToIgnore = {taskParameters.objectOfInterest} })
      end
   
      if subtaskId > 0 and 
         currentObjectLocation:distanceToLocation3D(surroundedLocation) > retaskDistance then
      
         vrf:stopSubtask(subtaskId)
         subtaskId = -1
      end
   
      -- See if we are done
      if subtaskId > 0 and vrf:isSubtaskComplete(subtaskId) then
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
