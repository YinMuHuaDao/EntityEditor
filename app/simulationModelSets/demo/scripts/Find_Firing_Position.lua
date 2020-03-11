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

checkpointState.subtaskId = -1
checkpointState.done = false

-- Task Parameters Available in Script
--  taskParameters.Threat Type: SimObject - Threat to find cover from
--  taskParameters.ThreatRadius Type: Real Unit: meters - The threat radius defines an area around the threat from which line-of-sight calculations are made
--  taskParameters.Range Type: Real Unit: meters - Distance at which to look for cover locations
--  taskParameters.DistanceFromThreat Type: Real Unit: meters - Minimum distance to keep from threat

-- Called when the task first starts. Never called again.
function init()

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
end

-- Called each tick while this task is active.
function tick()

   if checkpointState.done then   
      
      -- Need animations for looking around cover. This is a placeholder.
      --vrf:sendTask(this, "Periodic_Look_Around", {TimeBetweenLooks=10, Variability=3}, false)
      
      vrf:endTask(true)
      
   elseif checkpointState.subtaskId < 0 then
   
      checkpointState.subtaskId = vrf:startSubtask("Find_Cover", 
          {Threat=taskParameters.Threat,
           ThreatRadius=taskParameters.ThreatRadius,
           Range=taskParameters.Range,
           DistanceFromThreat=taskParameters.DistanceFromThreat,
           ChooseFiringPosition=true,
           StartFrom=0, -- entity location
           FaceThreat=true})
         
   elseif (vrf:isSubtaskComplete(checkpointState.subtaskId)) then
   
      checkpointState.done = true
      vrf:setTickPeriod(2)
      
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
