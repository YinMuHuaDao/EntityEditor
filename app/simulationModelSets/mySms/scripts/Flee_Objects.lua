-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
subtaskId = -1
objectsToFlee = {}

-- Task Parameters Available in Script
--  taskParameters.typesToFlee Type: String List of Entity Types - Will attempt to flee any entities with matching entity types
--  taskParameters.fleeRadius Type: Real Unit: meters - Will attempt to flee when objects are within this radius the entity


-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()

   local aiEnabled = this:getStateProperty(AIEnabledStateProperty)   
   if (aiEnabled == nil or aiEnabled) then
   
      if next(taskParameters.typesToFlee) ~= nil then
         objectsToFlee = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), taskParameters.fleeRadius, 
            {types=taskParameters.typesToFlee})
         
         if next(objectsToFlee) ~= nil then
            return true
         end
      end
   end
   
   return false
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   if subtaskId < 0 then
      subtaskId = vrf:startSubtask("flee",
         { fleeFrom = objectsToFlee, radius = taskParameters.fleeRadius })
   end

   if vrf:isSubtaskComplete(subtaskId) then
      subtaskId = -1
      objectsToFlee = {}
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



-- Called when a reactive task is disabled (check will no longer called)
-- It is typically not necessary to add code to this function.
function disable()
end
