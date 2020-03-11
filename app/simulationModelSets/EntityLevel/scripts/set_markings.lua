-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables
--
-- Global variables get saved when a scenario gets checkpointed in one of the folowing way:
-- 1) If the checkpoint mode is AllGlobals all global variables defined will be saved as part of the save stat
-- 2) In setting CheckpointStateOnly, this means that the script will *only* save variables that are part of the checkpointState table.  If you remove this value, it will then
--    default to the behavior of sabing all globals
--
-- If you wish to change the mode, call setCheckpointMode(AllGlobals) to save all globals or setCheckpointMode(CheckpointStateOnly)
-- to save only those variables in the checkpointState table
-- They get re-initialized when a checkpointed scenario is loaded.
vrf:setCheckpointMode(CheckpointStateOnly)

-- Set Parameters Available in Script
--  setParameters.country Type: Integer (0 - choice limit)


-- Called when the task first starts. Never called again.
function init()

   -- Since this is a set, it should tick while the simulation is paused
   vrf:setTickWhilePaused(true)
   
    -- For units, pass the set down to subordiantes.
    if (this:isDisaggregatedUnit()) then
      local subordinates = this:getSubordinates(true);
      for i,sub in ipairs(subordinates) do
         vrf:sendSetData(sub, "set_markings", setParameters )
      end
   end
   
   -- For now, just hardcode list of countries.  Later this will be enhanced to be set from the meta file directly:
   local countryString = "Other"
   if setParameters.country == 0 then countryString = "German" 
   elseif setParameters.country == 1 then countryString = "Dutch"
   elseif setParameters.country == 2 then countryString = "Czech"
   elseif setParameters.country == 3 then countryString = "Canadian"
   elseif setParameters.country == 4 then countryString = "Swiss"
   elseif setParameters.country == 5 then countryString = "French"   
   end
   
   if setParameters.platoon == 0 then platoonString = "None"
   elseif setParameters.platoon == 1 then platoonString = "Scout"
   elseif setParameters.platoon == 2 then platoonString = "Mortar"
   elseif setParameters.platoon == 3 then platoonString = "Antitank"
   elseif setParameters.platoon == 4 then platoonString = "4th"
   elseif setParameters.platoon == 5 then platoonString = "5th"
   elseif setParameters.platoon == 6 then platoonString = "6th"
   end
   
   if setParameters.plate == 0 then plateString = "03 20 01"
   elseif setParameters.plate == 1 then plateString = "21 12 02"
   elseif setParameters.plate == 2 then plateString = "65 22 03"
   elseif setParameters.plate == 3 then plateString = "88 00 04"
   elseif setParameters.plate == 4 then plateString = "31 20 05"
   elseif setParameters.plate == 5 then plateString = "29 22 06"
   elseif setParameters.plate == 6 then plateString = "80 80 07"
   elseif setParameters.plate == 7 then plateString = "99 20 08"
   end

   this:setStatePropertyMapItem("Markings", "marking_platoon", platoonString)
   this:setStatePropertyMapItem("Markings", "marking_country", countryString)
   this:setStatePropertyMapItem("Markings", "marking_id", plateString)
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   -- endSet() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the set.
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
