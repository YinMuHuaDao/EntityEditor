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

-- movement subtask
subTask = nil

-- drop points table
cargoDropPoints = {}
cargoObject = nil

-- machine states
logicState = "init"
--           "choose-cargo"
--           "drop-point"
--           "unload"

-- Task Parameters Available in Script
--  taskParameters.cargo Type: SimObjects - Items to carry.

-- Called when the task first starts. Never called again.
function init()

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   if (subTask ~= nil) then
      vrf:stopSubtask(subTask)
      subTask = nil
   end        

   local rowPoint = this:getLocation3D():makeCopy()
   local embarkees = this:getEmbarkedObjects()
   local bvolCargo = nil
   local sign = -1.0
   local fwd = 0.0

   if (embarkees ==  nil or #embarkees < 1) then
      printInfo(vrf:trUtf8("Unload Cargo: No more cargo objects to process.  Task Complete."))
      vrf:endTask(true)
   end

   for idx,sub in ipairs(embarkees) do
      bvolCargo = sub:getBoundingVolume()

      cargoDropPoints[idx] = rowPoint:addVector3D(Vector3D(0.0,(bvolCargo:getRight()+0.5)*sign, 0.0))

      local terrainAltitude, valid, surfaceType = vrf:getTerrainAltitude(cargoDropPoints[idx]:getLat(), cargoDropPoints[idx]:getLon())

      if (valid) then
         cargoDropPoints[idx]:setAlt(terrainAltitude)
      end

      -- keep track of longest cargo in row
      if (bvolCargo:getForward() * 2.0 > fwd) then
         fwd = bvolCargo:getForward() * 2.0
      end

      -- next row?
      if (sign > 0.0) then
         rowPoint = rowPoint:addVector3D(Vector3D((fwd+0.5)*-1.0,0.0, 0.0))
      end

      -- flip sign left or right
      sign = sign * -1.0
   end

   logicState = "choose-cargo"     
end

-- Called each tick while this task is active.
function tick()

   local embarkees = this:getEmbarkedObjects()

   if (not embarkees or #embarkees < 1) then
      printInfo(vrf:trUtf8("Unload Cargo: no embarkees, task complete."))
      vrf:endTask(true)
   end

   if (logicState == "choose-cargo") then
      advanceToMoveState()
   end

   if (logicState == "unload") then
      doUnloadStep()
      return
   end

   -- subTask nil?
   if (subTask == nil) then
      printInfo(vrf:trUtf8("Unload Cargo subtask missing, skipping task."))
      vrf:endTask(false)
   return   end
  
   if (vrf:isTaskComplete(subTask)) then
      if (logicState == "drop-point") then
         vrf:stopSubtask(subTask)
         subTask = nil
         logicState = "unload"
      end
   end
   
   return
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

-- advanceToMoveState()
-- Calculate movement toward cargo dropoff point
-- Issue movement subtask
-- Change state to logicState = "drop-point"
function advanceToMoveState()
   if (subTask) then
      vrf:stopSubtask(subTask)
   end
   
   subTask = nil

   -- this is validated prior to calling advanceToMoveState()
   local embarkee = this:getEmbarkedObjects()[1]
   local dest = cargoDropPoints[1]:makeCopy()
   local bvolRw = this:getBoundingVolume()
   local bvolSub = embarkee:getBoundingVolume()
   local altOffset = bvolSub:getUp() * 2.0 + bvolRw:getUp()
   
   local terrainAltitude, valid, surfaceType = vrf:getTerrainAltitude(cargoDropPoints[1]:getLat(), cargoDropPoints[1]:getLon())
 
   if (not valid) then
      terrainAltitude = cargoDropPoints[1]:getAlt()
      printDebug("no terrain.  cargoDropPoint[1].getAlt(): " .. terrainAltitude)
   end
   
   altOffset = altOffset
   
   printDebug("drop altitude: " .. altOffset + terrainAltitude)

   dest:setAlt(terrainAltitude + (altOffset > 2 and altOffset or 2))

   subTask = vrf:startSubtask("move-to-location-task", {aiming_point = dest})

   logicState = "drop-point"
end

-- doUnloadStep 
-- Unload first embarkee at first drop point
function doUnloadStep()

   if (cargoObject == nil) then
      cargoObject = this:getEmbarkedObjects()[1]

      if (cargoObject == nil) then
         return
      end

      if (not cargoObject:isValid()) then
         cargoObject = nil
         return
      end
   end

   if (cargoObject:isEmbarked()) then
      vrf:sendSetData(cargoObject, "set-unload-entity",{})
      return
   end

   if (cargoDropPoints[1]) then
      vrf:sendSetData(cargoObject, "set-unload-entity",cargoDropPoints[1]:makeCopy())
      table.remove(cargoDropPoints, 1)

      cargoObject = nil
   end

   logicState = "choose-cargo"
end
