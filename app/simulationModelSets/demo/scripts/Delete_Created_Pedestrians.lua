-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(10)
end

-- Called each tick while this task is active.
function tick()

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

-- Called when this entity is completely removed
function shutdown()
   local ownedPeds = this:getStateProperty("Owned-Pedestrians")
   if ownedPeds ~= nil then
      for i, ped in pairs(ownedPeds) do
         vrf:deleteObject(ped)
      end
   end
   
   local crowdUnitUUID = this:getStateProperty("Owned-Crowd")
   if crowdUnitUUID ~= nil then
      vrf:deleteObject(crowdUnitUUID)
   end
end
