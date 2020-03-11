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

-- list of objects to pick up
cargoList = taskParameters.cargoList
cargoListIdx = 0

-- current object to pick up
cargoObjectToPickUp = nil

cruiseAltitude = taskParameters.cruiseAltitude

if (cruiseAltitude == nil) then 
   cruiseAltitude = 0.0
end

planRoute = taskParameters.planRoute

if (planRoute == nil) then
  planRoute = false
end

-- distance destination object has to move before subtask is reissued
checkDistance = 0.5

-- location destination was at when move task was started
lastLocation = nil

-- movement subtask
subTask = nil

-- pick up point is computed, above cargo
cargoPickupPoint = nil

-- machine states
logicState = "init"
--           "choose-cargo"
--           "ingress-route"
--           "ingress-point"
--           "embark"

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
   
   if (cargoList == nil or #cargoList < 1) then
      printWarn(vrf:trUtf8("Invalid cargo list"))
      vrf:endTask(false)
      return
   end         
   
   logicState = "choose-cargo"  
end

-- Called each tick while this task is active.
function tick()

   if (logicState == "choose-cargo") then
      cargoObjectToPickUp = pickNextCargo()

      if (cargoObjectToPickUp == nil) then
         printInfo(vrf:trUtf8("Retrieve Cargo: No more cargo objects to process.  Task Complete."))
         vrf:endTask(true)
         return
      end

      printDebug("Cargo Object: " .. cargoObjectToPickUp:getName())

      advanceToIngressState()
   end

   -- subTask nil?
   if (subTask == nil) then
      printInfo(vrf:trUtf8("Retrieve Cargo subtask missing, skipping task."))
      vrf:endTask(false)
   return   end
   
   -- check to make sure destination object is still valid
   if (not cargoObjectToPickUp:isValid()) then
      printInfo(vrf:trUtf8("Retrieve Cargo: cargo object has become invalid, skipping task."))
      vrf:endTask(false)
      return
   end
  
   if (vrf:isTaskComplete(subTask)) then
      if (logicState == "ingress-route") then
         vrf:stopSubtask(subTask)
         subTask = nil
         sendMoveToIngressPoint()
         logicState = "ingress-point"
      else
         if (logicState == "ingress-point") then         
            if (doEmbarkStep()) then
               vrf:stopSubtask(subTask)
               subTask = nil
               logicState = "choose-cargo"
            end
         end
      end
   else
      -- still performing movement step
      -- check to see if destination object has moved enough to reissue subtask
      local newLocation = cargoObjectToPickUp:getLocation3D()
      if (not lastLocation:isNearLocation3D(newLocation, checkDistance)) then
         printInfo("Retrieve Cargo: cargo object moved, restarting task. old: [ " .. lastLocation:getLat() .. ", " .. lastLocation:getLon() .. ", "  .. lastLocation:getAlt() .. " ] new: [ " .. newLocation:getLat() .. ", "  .. newLocation:getLon() .. ", "  .. newLocation:getAlt() .. " ]")
         
         -- redo
         advanceToIngressState()
         return
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

-- Move to ingress point
function sendMoveToIngressPoint()
   subTask = vrf:startSubtask("move-to-location-task", {aiming_point = cargoPickupPoint})
end

-- advanceToIngressState()
-- Calculate movement toward cargo object
-- Issue movement subtask
-- Change state to logicState = "ingress-route"
function advanceToIngressState()
   if (subTask) then
      vrf:stopSubtask(subTask)
   end
   
   subTask = nil

   lastLocation = cargoObjectToPickUp:getLocation3D():makeCopy()
   
   cargoPickupPoint = lastLocation:makeCopy()

   local clamping = terrainClamp
   local bvolRw = this:getBoundingVolume()
   local bvolCargo = cargoObjectToPickUp:getBoundingVolume()
   local ingressPoint = cargoObjectToPickUp:getLocation3D():makeCopy()
   local  boundingThreshold = bvolRw:getUp() + math.sqrt((bvolCargo:getForward()*2)*(bvolCargo:getForward()*2)+(bvolCargo:getRight()*2)*(bvolCargo:getRight()*2)+(bvolCargo:getUp()*2)*(bvolCargo:getUp()*2)) / 2  
   local terrainAltitude, valid, surfaceType = vrf:getTerrainAltitude(lastLocation:getLat(), lastLocation:getLon())
   local ingressAltitude = lastLocation:getAlt()
   
   if (not valid) then
      terrainAltitude = 0.0
   end
   
   cargoPickupPoint:setAlt(lastLocation:getAlt() + boundingThreshold)
   
   if (terrainAltitude > cargoPickupPoint:getAlt()) then
      cargoPickupPoint:setAlt(terrainAltitude + boundingThreshold)
   end

   -- calculate a flight path endpoint that is above the cargo object
   ingressAltitude = cargoPickupPoint:getAlt()    
   
   -- make last point at cruise altitude...
   ingressPoint:setAlt(cruiseAltitude)
   
   -- or route high enough to cover cargo and rw bvols
   if (ingressAltitude > cruiseAltitude) then
      ingressPoint:setAlt(ingressAltitude)
   end   
      
   local contourHeight = cruiseAltitude
   
   if (contourHeight == 0.0) then
      contourHeight = ingressAltitude
   end
   
   -- avoid terrain contours more than 10m above cruising altitude
   contourHeight = contourHeight + 30
   
   -- hat
   local rwHAT = cruiseAltitude - terrainAltitude
   
   if (rwHAT < 0.0) then
      rwHAT = 100.0
   end
   
   local bAvoidBuildings = true
   
   if (rwHAT > 1000) then
      bAvoidBuildings = false
   end
   
   if (not planRoute) then
	printDebug("Retrieve Cargo: planRoute is false.")
   end
   
   if (planRoute) then
	printDebug("Retrieve Cargo: planRoute is true.")
   end
   
   -- close enough already?
   -- If within 2x bounding diameter or 10m, whichever is larger, just go to pickup point
   if (not planRoute or this:getLocation3D():isNearLocation3D(cargoPickupPoint,boundingThreshold * 4 > 10 and boundingThreshold * 4 or 10)) then
      sendMoveToIngressPoint()
      logicState = "ingress-point"
   else
      -- still some distance, try plan route
      local params = {
         destination = ingressPoint,
         avoidElevationContours = true,
         altitudeLimit = contourHeight,
         avoidBuildings = bAvoidBuildings,
         buildingLimit = rwHAT - boundingThreshold,
         buffer = boundingThreshold,
         terrainClamp = true,
         heightAboveTerrain = rwHAT,
         displayRoute = true }  
      
      subTask = vrf:startSubtask("rotary-navigate-to-location", params)   

      logicState = "ingress-route"
   end
end

-- doEmbarkStep 
-- If cargo is embarked, return true
-- Else, facilitate embark operation
function doEmbarkStep()

   -- basic logic
   -- Is cargo already embarked on aircraft?  done.
   -- Is cargo embarked? Send "set-unload-entity" to cargo.
   -- Wait for cargo to be disembarked.
   -- Send "set-load-entity".
   -- Wait for cargo to be embarked on aircraft.
   -- Done.
   local cargoIsEmbarked = cargoObjectToPickUp:isEmbarked()
   local cargoParent = cargoObjectToPickUp:getEmbarkedOn()
   local ret = false

   if (not cargoIsEmbarked) then
      vrf:sendSetData(cargoObjectToPickUp, "set-load-entity", 
               {parent  = this,
               load_override = false})
   else
      if (cargoParent == this) then
         -- done
         ret = true
      else
         vrf:sendSetData(cargoObjectToPickUp, "set-unload-entity")    
      end
   end

   return ret
end

-- function pickNextCargo
-- Advances to next item in cargoList
-- Returns cargo object or nil
function pickNextCargo()
   local nextCargo = nil

   -- cargoListIdx starts at zero
   while (cargoListIdx < #cargoList) do
      cargoListIdx = cargoListIdx +1
      nextCargo = cargoList[cargoListIdx]
      
      printDebug("Next Cargo: " .. nextCargo:getName())

      if (nextCargo and nextCargo:isValid()) then
         -- found it        
         break
      end     

      nextCargo = nil
      cargoListIdx = cargoListIdx +1
   end

   return nextCargo
end
 