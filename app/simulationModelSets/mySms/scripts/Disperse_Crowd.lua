-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

local DEBUG_DETAIL = true

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
      
   local peds = this:getSubordinates(true)
   
   if next(peds) == nil then
      printWarn(vrf:trUtf8("No pedestrians in crowd"))
      vrf:endTask(false)
      return
   end
   
   for i, ped in pairs(peds) do
      if ped:isValid() then
         vrf:sendTask(ped, "wander",
            {isIndefinite=0,
             movementMode=0,
             destinationRestriction=3},
            false)
      end
   end
      
   vrf:endTask(true)
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
