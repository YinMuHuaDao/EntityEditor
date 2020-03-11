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

-- Task Parameters Available in Script


-- Called when the task first starts. Never called again.
function init()

   checkpointState.startTime = vrf:getSimulationTime()

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   local elapsedTime = vrf:getSimulationTime() - checkpointState.startTime
   local brightnessState = 0
   if (elapsedTime > 90) then
      brightnessState = 3
   elseif (elapsedTime > 60) then
      brightnessState = 2
   elseif (elapsedTime > 30) then
      brightnessState = 1
   end

   
   local app = vrf:bitwiseLeftShift(brightnessState, 9)
   app = Appearance.SetSmokeEmanating(app, true)
   if (this:getAppearance() ~= app) then
      vrf:executeSetData("set-appearance", {appearance=app})
   end
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
