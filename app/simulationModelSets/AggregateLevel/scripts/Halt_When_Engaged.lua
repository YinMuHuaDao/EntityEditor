-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script


-- This flag is true when the task is temporarily disabled.  This happens
-- when, after the task activates, but is then overridden (by another movement task).
-- The task then remains temporarily disabled until there are no attacks.  It then 
-- reenabled itsef.
tempDisable = false


-- Checks for any ongoing attacks, and returns true if there are any.
function ongoingAttacks()
   local currentAttacks = this:getStateProperty("Attacks")
   for attackIndex, attack in pairs(currentAttacks) do
      return true
   end
   return false
end

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(5.0)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   if tempDisable then 
      tempDisable = ongoingAttacks()
      return false
   elseif ongoingAttacks() then
      return true
   end
   return false
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(5.0)
   printInfo(vrf:trUtf8("Halting for attack"))
   tempDisable = true
   
end

-- Called each tick while this task is active.
function tick()
   -- End task as soon as the attackers list is empty again.
   if not ongoingAttacks() then
      vrf:endTask(true)
      tempDisable = false
   end

end


-- Called when this task is being suspended, likely by a reaction activating.
function suspend()
end

-- Called when this task is being resumed after being suspended.
function resume()
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
