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
--  setParameters.FeatureType Type: Integer (0 - choice limit)
--  setParameters.FeatureQuery Type: String
--  setParameters.MaxObjects Type: Integer
--  setParameters.MaxPrimitives Type: Integer
--  setParameters.ForcePaging Type: Bool (on/off)


-- Called when the task first starts. Never called again.
function init()
   this:setStateProperty("DrawFeatures", true)

   -- Since this is a set, it should tick while the simulation is paused
   vrf:setTickWhilePaused(true)


   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   this:setStateProperty("DrawingEnabled", false)
   this:setStateProperty("DrawTerrainSkin", false)
   this:setStateProperty("DrawBounds", false)
   
   this:setStateProperty("MaxPrimitives", setParameters.MaxPrimitives)
   this:setStateProperty("MaxObjects", setParameters.MaxObjects)
   this:setStateProperty("ForcePaging", setParameters.ForcePaging)
   this:setStateProperty("FeatureQuery", "")
   this:setStateProperty("FeatureType", "Feature")

   local ftype
   if setParameters.FeatureType == 0 then
      ftype = "Feature"
   elseif setParameters.FeatureType == 1 then
      ftype = "Area"
   elseif setParameters.FeatureType == 2 then
      ftype = "Path"
   else
      printWarn(string.format("Unknown feature type %d", setParameters.FeatureType))
      vrf:endSet()
      return
   end
   
   printInfo(string.format("Drawing %s set: %s", ftype, setParameters.FeatureQuery))
   
   this:setStateProperty("FeatureType", ftype)
   this:setStateProperty("FeatureQuery", setParameters.FeatureQuery)
   
   this:setStateProperty("DrawingEnabled", true)

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
