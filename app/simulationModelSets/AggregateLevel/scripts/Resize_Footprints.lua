-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- parameter-data storage. This data is static, so it can be stored at init time.
local basePhysicalFootprint = this:getParameterProperty("Base-Physical-Footprint")
local footprintPostureMod = this:getParameterProperty("Footprint-Posture-Modifier")
local postureSectorSize = this:getParameterProperty("Posture-Sector-Size")

-- Comparison values stored from previous tick
previousPosture = "-"

-- Add callbacks for when state properties are se.
-- This will allow the script to respond quickly to changes in posture 
-- and be able to do so while  the scenario is paused.
vrf:addPostSetDataCallback("set-state-properties", "updateFootprints");

-- Call tick when  set state properties is done to allow the script to
-- immediately respond to changes in posture.
function updateFootprints(parameters)

   tick();

end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(2)

   
end

-- Calculates derived properties that are required to update the dynamic
-- properties controlled by this script. Returns the current values of these
-- properties.
-- Pre-tick derived properties:
--     None
function calculatePreTickDerivedProperties()
end
   
-- Updates any dynamic properties controlled by this task. Returns the
-- current values of these properties.
-- Dynamic properties:
--     None
function updateDynamicProperties()
end

-- Calculates remaining derived properties which are maintained by this script.
-- Derived properties:
--     Physical-Footprint
--     Sector-Sizes
function calculateDerivedProperties(ammunitionCategories)
      
   -- Get current posture
   local posture = this:getStateProperty("Posture")
         
   -- Only update if posture has changed
   if (posture ~= previousPosture) then
   
      -- Calculate physical footprint
      local fp = basePhysicalFootprint * footprintPostureMod[posture]
      this:setStateProperty("Physical-Footprint", fp)
      
      -- Set sector sizes
      local postureSectors = postureSectorSize[posture]
      this:setStateProperty("Sector-Sizes", postureSectors)
   end

   previousPosture = posture
end

-- Called each tick while this task is active.
function tick()
      
   calculatePreTickDerivedProperties()
   updateDynamicProperties()
   calculateDerivedProperties()
   
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
