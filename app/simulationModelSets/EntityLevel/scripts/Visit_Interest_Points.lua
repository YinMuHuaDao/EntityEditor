-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.visitTime Type: Real
--  taskParameters.maxVisitDistance Type: Real Unit: meters - Maximum distance from which to deviate from normal movement to visit an interst point.
--  taskParameters.visitLiklihood Type: Integer - Percent liklihood that an entity will choose to visit a point that it passes near.

local thePointOfInterestType="16:0:0:1:1:0:0"

-- Points on this list have already been processed and are not elegable for visiting.
myPointsToIgnore={}
myPointToVisit=nil
mySubtaskId = -1
myVisitEndTime =  0
myVisitStage = nil

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(2)
end

-- Remove points from the ignore list if they are sufficently far away, so the entity can consider visiting them again later.
function expireIgnorePoints()
   for i, point in ipairs(myPointsToIgnore) do
      if (not point:isValid() or 
         this:getLocation3D():distanceToLocation3D(point:getLocation3D()) > taskParameters.maxVisitDistance * 1.5) then
         table.remove(myPointsToIgnore, i)
      end
   end
end

-- Return a nearby elegible point of interest or nil.
function findVisitPoint()
   local nearPoi = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), taskParameters.maxVisitDistance, 
      {types={thePointOfInterestType}, ignore=myPointsToIgnore})
   if (#nearPoi > 0) then
      local visitPoint = nearPoi[math.random(#nearPoi)]
      return visitPoint
   end
   return nil
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   local visitPoint = findVisitPoint()
   if (visitPoint ~= nil) then
      table.insert(myPointsToIgnore, visitPoint)
      if (math.random(100) <= taskParameters.visitLiklihood) then
         myPointToVisit = visitPoint
         return true
      end
   end
   expireIgnorePoints()
   return false
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   mySubtaskId = vrf:startSubtask("move-to", {control_point=myPointToVisit, at_distance=(math.random(20)/10 + 1)})
   myVisitStage = "move-to"
end

-- Called each tick while this task is active.
function tick()
   if (myVisitStage == "move-to") then
      if (mySubtaskId >= 0) then
         if (vrf:isSubtaskRunning(mySubtaskId) == false) then
            mySubtaskId = vrf:startSubtask("Civilian_Idle", {})
            -- Visit teh point for the specified visit time +/- 50%
            myVisitEndTime = vrf:getSimulationTime() + taskParameters.visitTime / 2 + math.random(taskParameters.visitTime) 
            myVisitStage = "visiting"
         end
      end
   elseif (myVisitStage == "visiting") then
      if (vrf:getSimulationTime() >= myVisitEndTime) then
         mySubtaskId = -1
         myVisitPoint = nil
         vrf:setTickPeriod(2)
         vrf:endTask(true)
      end
   end
   

   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   

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



-- Called when a reactive task is disabled (check will no longer called)
-- It is typically not necessary to add code to this function.
function disable()
end
