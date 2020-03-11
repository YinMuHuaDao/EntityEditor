
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

checkpointState.subordinateTasks = {}
checkpointState.destinations = {}

-- Task Parameters Available in Script
--  taskParameters.Location Type: Location3D - Location around which the unit should circle
--  taskParameters.FacingDirection Type: Integer (0 - choice limit) - Direction in which to face once in position
--  taskParameters.Radius Type: Real Unit: meters - Distance at which entities should stand from the location

local FaceIn = 0
local FaceOut = 1

-- Called when the task first starts. Never called again.
function init()

   local subordinates = this:getSubordinates(true)
   
   -- Initialize list of current subordinate task ids to -1
   for i, obj in pairs(subordinates) do
      if (obj:isValid() and vrf:entityTypeMatches(obj:getEntityType(), EntityType.Lifeform())) then
      
         table.insert(checkpointState.subordinateTasks,
            { entity=obj, taskId = -1 })
      
      end
   end
   
   local numSubordinates = #checkpointState.subordinateTasks
   if numSubordinates > 0 then
      -- Determine the points at which the entities will stand
      local TwoPi = 2 * math.pi
      local headingDiff = TwoPi / numSubordinates
      local nextHeading = math.random() * headingDiff
      
      while #checkpointState.destinations < numSubordinates do
      
         local vec = Vector3D(0,0,0)
         vec:setBearingInclRange(nextHeading, 0, taskParameters.Radius)
         table.insert(checkpointState.destinations, taskParameters.Location:addVector3D(vec))
         
         nextHeading = nextHeading + headingDiff
         if nextHeading > TwoPi then
            nextHeading = nextHeading - TwoPi
         end
         
      end
      
   end

   -- Set the tick period for this script.
   vrf:setTickPeriod(1.0)
   
end

-- Called each tick while this task is active.
function tick()
            
   vrf:updateTaskVisualization("Center", "point", 
      {color={0,0,255,150},
       location=taskParameters.Location,
       size=1})

   local numComplete = 0
   local removedSubs = {}
   for i, subordinateTask in pairs(checkpointState.subordinateTasks) do
   
      if (not subordinateTask.entity:isValid()) then
      
         -- Entity is gone
         table.insert(removedSubs, i)
         
      elseif (subordinateTask.entity:isDestroyed()) then
      
         -- No more moving for this one
         numComplete = numComplete + 1
      
      elseif subordinateTask.taskId < 0 then
      
         if #checkpointState.destinations == 0 then
            printWarn(vrf:trUtf8("Error: No destinations remaining."))
            vrf:endTask(false)
            return
         end
         
         -- Move entity into location
         local loc = table.remove(checkpointState.destinations)
         subordinateTask.taskId = vrf:sendTask(subordinateTask.entity, "move-to-location", 
            {aiming_point = loc})
            
         vrf:updateTaskVisualization("Destination" .. i, "point", 
            {color={0,255,0,150},
             location=loc,
             size=1})
            
      elseif vrf:isTaskComplete(subordinateTask.taskId) then
      
         -- Done moving. Face the right way.         
         local vecToFace = subordinateTask.entity:getLocation3D():vectorToLoc3D(taskParameters.Location)
         if taskParameters.FacingDirection == FaceOut then
            vecToFace = vecToFace:getScaled(-1)
         end         
         vrf:sendTask(subordinateTask.entity, "turn-to-heading", {heading=vecToFace:getBearing()}, false)
         
         numComplete = numComplete + 1
         
      end
      
   end
   
   -- Get rid of any subordinates which have been removed
   local remIdx = #removedSubs
   while (remIdx > 0) do      
      table.remove(checkpointState.subordinateTasks, removedSubs[remIdx])
      remIdx = remIdx - 1   
   end

   -- If everyone's in place, end the task.
   if numComplete >= #checkpointState.subordinateTasks then
   
      if #checkpointState.subordinateTasks == 0 then
         printWarn(vrf:trUtf8("No human subordinates to perform task."))
      end
   
      vrf:endTask(true)
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
