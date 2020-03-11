-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.route Type: SimObject
--  taskParameters.reverseDirection Type: Boolean
--  taskParameters.startAtClosestVertex Type: Boolean
--  taskParameters.retrograde Type: Boolean

-- Globals
mySubordinateTasks = {}
initialHeading = 0

local MoveAlong = 1
local MoveIntoFinalPosition = 2

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   initialHeading = this:getDirection3D():getBearing()

   local currentSubordinates = this:getAllSubordinates(true)
   
   for subIndex, subordinate in pairs(currentSubordinates) do
      local taskId = -1
      
      local direction = 0
      if taskParameters.reverseDirection then direction = 1 end
      
      if (taskParameters.retrograde) then
         taskId = vrf:sendTask(subordinate, "move-along-retrograde", 
            {route = taskParameters.route, 
             start_at_closest_point = taskParameters.startAtClosestVertex,
             traversal_direction = direction})
      else
         taskId = vrf:sendTask(subordinate, "move-along",  
            {route = taskParameters.route, 
             start_at_closest_point = taskParameters.startAtClosestVertex,
             traversal_direction = direction})
      end
      
      -- Keep track of the offset such that when the subordinate gets to the end of the route they can move back to their original offset location as an offset
      -- from the end of the route
      mySubordinateTasks[subordinate:getUUID()] = {MoveAlong, taskId, this:getLocation3D(), subordinate:getLocation3D()}
   end
end

-- Checks the status of the subordinates to see if the still exist and are executing a task at a particular step.  If they are done with the MoveIntoFinalPosition
-- step then they are complete and removed from the taskable subordinates list
function allSubordinatesComplete()
   local currentSubordinates = this:getAllSubordinates(true)
   local currentTable = mySubordinateTasks
   local complete = true
   
   mySubordinateTasks = {}

   for subIndex, subordinate in pairs(currentSubordinates) do
      local taskStatus = currentTable[subordinate:getUUID()]
      if (taskStatus ~= nil) then
         if (not vrf:isTaskComplete(taskStatus[2])) then
            mySubordinateTasks[subordinate:getUUID()] = taskStatus
            complete = false
         elseif (taskStatus[1] == MoveAlong) then
            taskStatus[1] = MoveIntoFinalPosition
               -- Given the direction of the last segment of this route, and the initial positions of the entity, calculate
               -- rotated offset positions and move the entity to those offset positions retrograde to keep their current headings
	      
            local locations = taskParameters.route:getLocations3D()
            local endPoint = locations[table.getn(locations)];
            local originalAggregateLocation = taskStatus[3]
            local originalSubordinateLocation = taskStatus[4]
            local offsetFromMe = originalAggregateLocation:vectorToLoc3D(originalSubordinateLocation)
            if not taskParameters.retrograde then
               local routeEndBearing = locations[table.getn(locations) -1]:vectorToLoc3D(endPoint):
                  getBearing()
               offsetFromMe:setBearingInclRange(offsetFromMe:getBearing() + routeEndBearing - initialHeading,
                  0.0, offsetFromMe:getRange())
            end
            local targetLocation = endPoint:addVector3D(offsetFromMe)	 
      
            taskStatus[2] = vrf:sendTask(subordinate, "move-to-location-retrograde-task", {aiming_point = targetLocation})
	    
            mySubordinateTasks[subordinate:getUUID()] = taskStatus
            complete = false	 
         end
      end      
   end
   
   return complete
end

-- Called each tick while this task is active.
function tick()
   if (allSubordinatesComplete()) then
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
