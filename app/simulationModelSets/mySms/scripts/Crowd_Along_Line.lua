-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

subtaskId = -1
surroundedLocation = Location3D(0,0,0)

-- If object of interest moves more than the retaskDistance, then we will restart
-- our crowd_around_location subtask. This should NOT be used for moving objects,
-- but rather objects that can be occasionally re-placed.
local retaskDistance = 2

-- Task Parameters Available in Script
--  taskParameters.line Type: Location3D - Line along which entities should crowd
--  taskParameters.leftOrRight Type: Integer (0 - choice limit) - Should the crowd gather to the left or right of the line
--  taskParameters.idleTask Type: String - The task which will be given to each pedestrian when they arrive
--  taskParameters.speedMultiplier Type: Real - Chosen speed for each entity is multiplied by this value. Used to slow down or speed up entities.


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

function findLineCenter(vertices)
   -- Don't assume we can just use # to find number of vertices, count them
   local numVertices = 0
   local vertex = nil
   local index = nil
   for index, vertex in pairs(vertices) do
      numVertices = numVertices + 1
   end
   
   if numVertices < 2 then
      -- This is not a line
      printWarn("not a line")
      return Location3D(0,0,0)
   elseif numVertices % 2 == 1 then
      -- Odd number, choose the central vertex
      local vertexNum = math.ceil(numVertices/2)
      local currentVertexNum = 0
      vertex = nil
      index = nil
      repeat
         index, vertex = next(vertices, index)
         currentVertexNum = currentVertexNum + 1
      until currentVertexNum == vertexNum
      return vertex
   else
      -- Odd number, find central segment
      local vertexNum = numVertices/2
      local currentVertexNum = 0
      local firstVertex = nil
      local secondVertex = nil
      local tempIndex = nil
      index = nil
      repeat
         index, firstVertex = next(vertices, index)
         tempIndex, secondVertex = next(vertices, index)
         currentVertexNum = currentVertexNum + 1
      until currentVertexNum == vertexNum
      
      -- Find mid-point of central segment
      local segmentVec = firstVertex:vectorToLoc3D(secondVertex)
      local midpointVec = segmentVec:getScaled(0.5)
      return firstVertex:addVector3D(midpointVec)
   end
end

-- Called each tick while this task is active.
function tick()

   if (taskParameters.line:isValid()) then
      local centerOfLine = findLineCenter(taskParameters.line:getLocations3D())
   
      -- If not already doing so, surround the object
      if subtaskId < 0 then
   
         surroundedLocation = centerOfLine
         local reverseLeftOfLine = false
         if taskParameters.leftOrRight == 1 then
            reverseLeftOfLine = true
         end
   
         subtaskId = vrf:startSubtask("Crowd_Around_Location",
            { locationOfInterest = surroundedLocation,
              idleTask = taskParameters.idleTask,
              speedMultiplier = taskParameters.speedMultiplier,
              keepLeftOfLine = true,
              leftOfLine = taskParameters.line,
              reverseLeftOfLine = reverseLeftOfLine,
              faceLeftOfLine = true })
      end
   
      if subtaskId > 0 and 
         centerOfLine:distanceToLocation3D(surroundedLocation) > retaskDistance then
      
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
