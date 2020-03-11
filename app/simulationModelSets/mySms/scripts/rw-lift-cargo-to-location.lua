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

-- Altitude at which to fly
cruiseAltitude = taskParameters.cruiseAltitude

-- Destination point
destination = taskParameters.destination

if (cruiseAltitude == nil) then 
   cruiseAltitude = 0.0
end

-- movement subtask
subTask = nil

-- machine states
logicState = "init"
--           "pickup"
--           "fly"
--           "dropoff"

-- Task Parameters Available in Script
-- taskParameters.cargoList
-- taskParameters.cruiseAltitude
-- taskParameters.destination

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
   
   if (destination == nil) then
      printWarn(vrf:trUtf8("Invalid destination."))
      vrf:endTask(false)
      return
   end           
   
   logicState = "init"  
end

-- Called each tick while this task is active.
function tick()

   if (logicState == "init") then
      if (not subTask == nil )  then
         vrf:stopSubtask(subTask)
         subTask = nil
      end
      local params = {
         cargoList = taskParameters.cargoList,
         cruiseAltitude = taskParameters.cruiseAltitude,
         planRoute = true
         }

      subTask = vrf:startSubtask("rw-retrieve-cargo", params)

      logicState = "pickup"
   end

   -- subTask nil?
   if (subTask == nil) then
      printInfo(vrf:trUtf8("RW Lift Cargo To Location: missing subTask, skipping task."))
      vrf:endTask(false)
      return
   end

   if (vrf:isTaskComplete(subTask)) then
      if (logicState == "pickup") then
         local destinationAltitude, valid, surfaceType = vrf:getTerrainAltitude(destination:getLat(), destination:getLon())

         if (not valid) then
            -- wait for terrain to page
            return
         end

         local rwHAT = cruiseAltitude - destinationAltitude

         if (rwHAT < 10) then
            rwHAT = 10
         end

         vrf:stopSubtask(subTask)
         subTask = nil

         -- assign movement
         local ingressPoint = destination:makeCopy()

         ingressPoint:setAlt(cruiseAltitude)

         local params = {
            destination = ingressPoint,
            avoidElevationContours = true,
            altitudeLimit = cruiseAltitude + 20,
            avoidBuildings = true,
            buildingLimit = cruiseAltitude - 10 > 0 and cruiseAltitude - 10 or 10,
            buffer = 15,
            terrainClamp = true,
            heightAboveTerrain = rwHAT,
            displayRoute = true }  
      
         subTask = vrf:startSubtask("rotary-navigate-to-location", params)
         logicState = "fly"
      else
         if (logicState == "fly") then         
            vrf:stopSubtask(subTask)
            subTask = nil
            subTask = vrf:startSubtask("rw-unload-cargo", {})
            logicState = "dropoff"
         else
            printInfo(vrf:trUtf8("RW Lift Cargo To Location: Done unloading.  Task Complete."))
            vrf:endTask(true)
            return
         end
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
 