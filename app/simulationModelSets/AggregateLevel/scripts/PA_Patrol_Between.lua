-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.point1 Type: SimObject
--  taskParameters.point2 Type: SimObject

-- Globals
mySubordinateTasks = {}


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)

   local currentSubordinates = this:getAllSubordinates(true)
   
   for subIndex, subordinate in pairs(currentSubordinates) do
      local taskId = -1

	  taskId = vrf:sendTask(subordinate, "patrol-two-points",  {first_control_point = taskParameters.point1,
	     second_control_point = taskParameters.point2})
      
      -- Keep track of the offset such that when the subordinate gets to the end of the route they can move back to their original offset location as an offset
      -- from the end of the route
      mySubordinateTasks[subordinate:getUUID()] = taskId
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
      local taskId = currentTable[subordinate:getUUID()]
      if (taskId ~= nil) then
         if (not vrf:isTaskComplete(taskId)) then
	        mySubordinateTasks[subordinate:getUUID()] = taskId
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
