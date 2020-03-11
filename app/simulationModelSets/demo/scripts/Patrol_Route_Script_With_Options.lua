-- This script re-implements the Patrol Route task but includes the parameters found
-- with move-along-route tasks.
-- (c) MAK, 2016
-- Author: D. Reece

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
state = "reverse"
moveSystem = nil
lastPointIndex = -1
taskId = -1
routePoints = nil
-- This flag will be the same as the task parameter for the initial route follow
-- task, but then reset to false for all subsequent route follow tasks in the patrol.
startAtClosest = false

-- Task Parameters Available in Script
--  taskParameters.Route Type: SimObject - Route to Patrol
--  taskParameters.treatRouteAsRoad Type: Bool (on/off)
--  taskParameters.reverseDirection Type: Bool (on/off)
--  taskParameters.startAtClosestVertex Type: Bool (on/off)

-- Called when the task first starts. Never called again.
function init()
   if not taskParameters.Route:isValid() then
      printWarn("No valid route for patrol task.")
      vrf:endTask(false)
      return
   end
   moveSystem = this:getSystem("movement")
   if moveSystem == nil then 
      printWarn("Couldn't find movement system for entity")
      vrf:endTask(false)
      return
   end
   routePoints = taskParameters.Route:getLocations3D()
   lastPointIndex = # routePoints
   
   if taskParameters.reverseDirection then
      state = "forward"
   end 
   
   startAtClosest = taskParameters.startAtClosestVertex
end

-- Called each tick while this task is active.
function tick()
   if state == "reverse" then
      if (taskId == -1 or
         not vrf:isTaskRunning(taskId)) then
         
         -- Start the route in forward direction
         if taskParameters.treatRouteAsRoad then
            taskId = vrf:startSubtask("rail-route",
               {route = taskParameters.Route,
                start_at_closest_point = startAtClosest})
         else
            taskId = vrf:startSubtask("move-along",
               {route = taskParameters.Route,
                start_at_closest_point = startAtClosest})
         end
         startAtClosest = false
         state = "forward"
      end
   elseif state == "forward" then
      if (taskId == -1 or
         not vrf:isTaskRunning(taskId)) then
         
         -- Start the route in forward direction
         if taskParameters.treatRouteAsRoad then
            taskId = vrf:startSubtask("rail-route",
               {route = taskParameters.Route,
                start_at_closest_point = startAtClosest,
                traversal_direction = 1})
         else
            taskId = vrf:startSubtask("move-along",
               {route = taskParameters.Route,
               start_at_closest_point = startAtClosest,
               traversal_direction = 1})
         end
         startAtClosest = false
         state = "reverse"
      end
   else 
      printWarn("Illegal patrol route state")
      vrf:endTask()
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
