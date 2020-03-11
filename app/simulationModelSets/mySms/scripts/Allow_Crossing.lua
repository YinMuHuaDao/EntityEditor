-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Set Parameters Available in Script
--  setParameters.allow Type: Bool (on/off)


-- Called when the task first starts. Never called again.
function init()

   -- Since this is a set, it should tick while the simulation is paused
   vrf:setTickWhilePaused(true)


   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   local allow = "0"
   if setParameters.allow then allow = "1" end
   this:setExtendedData("CrosswalkCrossingAllowed", allow)
   vrf:endSet()

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
