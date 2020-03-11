-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
subtaskId = -1

-- Task Parameters Available in Script
--  taskParameters.DistanceFromContamination Type: Real


-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(3)
end

-- Called to check if we need to put on MOPP gear due to proximity to the given
-- NBC area.
function inNbcDangerZone(nbcArea)
   local loc = this:getLocation3D()
   local distance = this:getStateProperty("Physical-Footprint") +
      taskParameters.DistanceFromContamination
   if(nbcArea:isPointInside(loc) or 
      loc:distanceToLocation3D(nbcArea:getLocation3D()) <= distance) then
      return true
   else
      local vecToArea = loc:vectorToLoc3D(nbcArea:getLocation3D())
      
      local scaledVector = vecToArea:getUnit():getScaled(distance)
      local closestPoint = loc:addVector3D(scaledVector) 
      if(nbcArea:isPointInside(closestPoint)) then
         return true
      end
   end
   
   return false
end

-- Called each tick period for this script while enabled but not in the active state.
function check()

   -- Can't change MOPP level while embarked
   if not this:getEmbarkedOn():isValid() then
      -- See if we are already protected
      local currentMoppLevel = this:getStateProperty("MOPP-Level")
      if(currentMoppLevel < 4) then
      
         -- Check if we are already changing MOPP level
         local moppTransition = this:getStateProperty("MOPP-Transition")
         if(not moppTransition.IsTransitioning) then
         
            -- Check if we are in a hazardous area
            
            -- First check sensed areas
            local nbcContacts = this:getContactsWithFilter({EntityType.NbcArealObject()}, false)
            for objNum,nbcArea in pairs(nbcContacts) do                       
               -- Found an NBC area. See if we fall within it.
               if inNbcDangerZone(nbcArea) then
                  return true
               end
            end
            
            -- Then check friendly areas
            local nbcAreas = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), 
               this:getStateProperty("Physical-Footprint") + taskParameters.DistanceFromContamination,
               {types={EntityType.NbcArealObject()}})
            for objNum,nbcArea in pairs(nbcAreas) do
               -- We already checked NBC areas of other forces that we know about. We are
               -- now only interested in areas of our own force type.
               if nbcArea:getForceType() == this:getForceType() then
                  -- Found an NBC area. See if we fall within it.
                  if inNbcDangerZone(nbcArea) then
                     return true
                  end
               end
            end
         end      
      end
   end
   
   return false
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(2)
end

-- Called each tick while this task is active.
function tick()

   if(subtaskId == -1) then
      -- Change MOPP level
      subtaskId = vrf:startSubtask("Change_MOPP_Level", 
         {MoppLevel=4})      
   elseif(vrf:isSubtaskComplete(subtaskId)) then
      -- Done
      subtaskId = -1

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

-- Reset subtask id to -1 such that if the task start again the
-- tasks will get reissued
function shutdown()
   subtaskId = -1
end
