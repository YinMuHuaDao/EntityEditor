-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables
--
-- Global variables get saved when a scenario gets checkpointed in one of the folowing way:
-- 1) If the checkpoint mode is AllGlobals all global variables defined will be saved as part of the save stat
-- 2) The current default behavior of CheckpointStateOnly will *only* save variables that are part of the checkpointState table
--
-- If you wish to change the mode, call setCheckpointMode(AllGlobals) to save all globals or setCheckpointMode(CheckpointStateOnly)
-- to save only those variables in the checkpointState table
-- They get re-initialized when a checkpointed scenario is loaded.
vrf:setCheckpointMode(CheckpointStateOnly)

subOffsets = {}
subGoals = {}

-- Table of currently moving subordinates and the taskIds of their tasks.
movingSubs = {}

-- States are:
--  starting:  First initialization of task
--  moving:  Subordinates are moving to destination
myState = "starting"

-- Task Parameters Available in Script
--  taskParameters.destination Type: Location3D - Move to location destination.
destination = taskParameters.destination


-- Called when the task first starts. Never called again.
function init()

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)

   -- Record the subordinate distances from the aggregate center, to record the current formation.
   local subordinates = this:getSubordinates(true)
   
   if (#subordinates < 1) then
      vrf:endTask(false)
      return
   end

   if (destination == nil) then
      printWarn("Unit_UAS_Move_To_Location(): no destination?\n")
      vrf:endTask(false)
      return
   end

   local nHAT = 0
   local dAlt, bAvailable = vrf:getTerrainAltitude(destination:getLat(), destination:getLon())

   if (bAvailable) then
      nHAT = destination:getAlt() - dAlt
   end
   
   -- Record the initial offsets of the subordinates
   for idx,sub in ipairs(subordinates) do
      local subLocation = sub:getLocation3D()
      local offset = this:getLocation3D():vectorToLoc3D(subLocation)

      if (sub:isDestroyed() == false) then
         subOffsets[sub:getUUID()] = offset;
         subGoals[sub:getUUID()] = destination:addVector3D(subOffsets[sub:getUUID()]):makeCopy()

         local goalAlt, bFound = vrf:getTerrainAltitude(subGoals[sub:getUUID()]:getLat(), subGoals[sub:getUUID()]:getLon())

         if (bAvailable and bFound) then
            goalAlt = goalAlt + nHAT
         else
            goalAlt = destination:getAlt()
         end
         
         subGoals[sub:getUUID()]:setAlt(goalAlt)
      end   
   end

end

-- Checks the status of moving subordinates, and returns the count of subordinates that are still moving.
-- Additionally, this call will check to see if a subordinate has been killed, and removes it from the group if so.
function checkSubordinateTasks()
   local activeSubsCount = 0;
   for sub, taskId in pairs(movingSubs) do
      if (sub:isDestroyed()) then
         movingSubs[sub] = nil;
      end
      
      if (vrf:isTaskComplete(taskId)) then 
         -- remove the subordinate from the table it has completed its task
         movingSubs[sub] = nil
      else
         activeSubsCount = activeSubsCount + 1
      end
   end
   return activeSubsCount
end

function taskSubordinateMovement()
   local subordinates = this:getSubordinates(true);
   
   if (#subordinates < 1) then
      vrf:endTask(false)
      return
   end

   -- Record the initial offsets of the subordinates
   for idx,sub in ipairs(subordinates) do
      local subDest = subGoals[sub:getUUID()]
      
      if (sub:isDestroyed() == false) and (subDest ~= nil) then
         local taskId = vrf:sendTask(sub, "move-to-location-task", {aiming_point = subDest})

         movingSubs[sub] = taskId;
      end   
   end
end

-- Called each tick while this task is active.
function tick()

   -- Check subordinate movement
   if (myState == "moving") then
      if (checkSubordinateTasks() < 1) then
         vrf:endTask(true)
      end
   else
      if (myState == "starting") then
         taskSubordinateMovement()
         myState = "moving"
      end
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
