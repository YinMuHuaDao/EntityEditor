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
--  taskParameters.timeBetweenDrops Type: Integer Unit: seconds
--  taskParameters.deployParachuteAltitude Type: Real Unit: meters
--  taskParameters.entitiesToDrop Type: SimObjects
--  taskParameters.targetObject Type: SimObject
--  taskParameters.musterPoint Type: SimObject
--  taskParameters.targetLocation Type: Location3D
--  taskParameters.deployAltIsAgl Type: Boolean


checkpointState.myState = "";
checkpointState.myTaskId = -1
checkpointState.myEntitiesToDrop = {}
checkpointState.myDisembarkingEntities = {}
checkpointState.myDoorStartsClosed = false
checkpointState.myLastDropTime = -1
checkpointState.myTroopOffsets = {}

function setupDestination(embarkedObject,i)
   --Take the muster point and add offset
   local musterSpacing = 3.0
   local xOffset = (i-1) *musterSpacing - 0.5*(#checkpointState.myEntitiesToDrop - 1) * musterSpacing
   local loc = taskParameters.targetObject:getLocation3D()
   local muster = taskParameters.targetObject:getLocation3D()
   if (taskParameters.musterPoint:isValid()) then
      muster = taskParameters.musterPoint:getLocation3D()
   end
   --Make offset from our insertion point and musterpoint, minus the alitutde of course
   loc:setAlt(muster:getAlt())
   local bearingVector = loc:vectorToLoc3D(muster);
   --now offset if by our xoffset
   local bearing =  bearingVector:getBearing() + math.rad(90.0);
   if (xOffset < 0) then 
      bearing = bearing + math.rad(180)
   end
   local offset = Vector3D(0.0,0.0,0.0)
   offset:setBearingInclRange(bearing,0.0,xOffset)
   local dest = muster:addVector3D(offset)
   checkpointState.myTroopOffsets[embarkedObject:getUUID()] = dest
   offset:setBearingInclRange(bearing,0.0,30.0)
   dest = muster:addVector3D(offset)
end

-- Called when the task first starts. Never called again.
function init()
   
   checkpointState.myState = "Start"
   
   checkpointState.myEntitiesToDrop = taskParameters.entitiesToDrop
   checkpointState.myDoorStartsClosed = cargodoor:isClosed()

   for index, entity in ipairs(checkpointState.myEntitiesToDrop) do
      setupDestination(entity, index)
   end
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

function timeForNextDrop()
   return vrf:getExerciseTime() > checkpointState.myLastDropTime + taskParameters.timeBetweenDrops
end

-- Called each tick while this task is active.
function tick()

   --If I don't have a door, move on to dropping entities.
   if (checkpointState.myState == "Start" and (not cargodoor:isClosed() or not vrf:isTaskAvailable("Open_Cargo_Door"))) then
      checkpointState.myState = "Drop"
   
   --If I have a door and it is closed, start opening.
   elseif (checkpointState.myState == "Start" and vrf:isTaskAvailable("Open_Cargo_Door") and cargodoor:isClosed()) then
      checkpointState.myTaskId = vrf:startSubtask("Open_Cargo_Door", {})
      checkpointState.myDoorStartsClosed = true
      checkpointState.myState = "DoorOpening"
      
   --if the door is open, or does not exist,
   elseif (checkpointState.myState == "DoorOpening" and vrf:isSubtaskComplete(checkpointState.myTaskId)) then
      checkpointState.myState = "Drop"
      checkpointState.myTaskId = -1
   
   --Ready to drop - task the first entity to drop   
   elseif (checkpointState.myState == "Drop") then
      if (#checkpointState.myEntitiesToDrop > 0 and timeForNextDrop() ) then
         checkpointState.myLastDropTime = vrf:getExerciseTime()
	 
	 local musterLoc = checkpointState.myTroopOffsets[checkpointState.myEntitiesToDrop[1]:getUUID()]
	 
	 local target = nil
	 if taskParameters.targetObject:isValid() then
	    target = taskParameters.targetObject
	 end
	 
         if (checkpointState.myEntitiesToDrop[1]:isValid()) then
            vrf:sendTask(checkpointState.myEntitiesToDrop[1], "Parachute_To_Target", {
	       targetObject = target,
	       musterPoint = nil,
	       musterLocation = musterLoc,
	       useMusterLocation = true,
               targetLocation = taskParameters.targetLocation,
               deployParachuteAltitude = taskParameters.deployParachuteAltitude,
               deployAltIsAgl = taskParameters.deployAltIsAgl}, false)
            --Add to list of disembarking entities, so the door doesn't close too early.
            table.insert(checkpointState.myDisembarkingEntities, table.remove(checkpointState.myEntitiesToDrop, 1))
         end
      elseif (#checkpointState.myEntitiesToDrop == 0 and #checkpointState.myDisembarkingEntities == 0) then
         if (checkpointState.myDoorStartsClosed) then
            checkpointState.myState = "DoorClosing"
            checkpointState.myTaskId = vrf:startSubtask("Close_Cargo_Door", {})
         else
            checkpointState.myState = "Finish"
         end
      end

   --Close door if necessary.
   elseif (checkpointState.myState == "DoorClosing" and vrf:isSubtaskComplete(checkpointState.myTaskId)) then
      checkpointState.myState = "Finish"

      --Done dropping entities.   
   elseif (checkpointState.myState == "Finish") then
      vrf:endTask(true)
   end
   
   --update disembarking entities.
   for index, entity in ipairs(checkpointState.myDisembarkingEntities) do
      if entity:isValid() and entity:getEmbarkedOn() ~= this then
         table.remove(checkpointState.myDisembarkingEntities, index)
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
