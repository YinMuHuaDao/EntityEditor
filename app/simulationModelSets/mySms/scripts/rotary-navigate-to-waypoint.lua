-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- feature query type to use
ftype = "MAK_ELEVATION_CONTOUR_AREA"
structureFeatureType = "MAK_STRUCTURES"

-- name of maximum elevation attribute, avoid features >= to this elevation
maximumElevationAttr = "MAK_ELEVATION"
attributeStructureHeight = "MAK_STRUCTURE_HEIGHT"

-- These two factors generate a minimum buffer width that
-- must be between the ship centerline and the shallow
-- depth obstacle in the final path.

-- Multiplied by ship length (reflects maneuverability)
local LENGTH_FACTOR = 1.0
-- Minimum value-- needed because the surface on which the movement
-- actuator runs aground may be more extensive than the obstacle
-- in the feature data used to plan.
local MIN_BUFFER = 5.0

-- navigation subtask
subTask = nil

-- minumum depth value calculation
avoidElevationContours = taskParameters.avoidElevationContours
altitudeLimit = taskParameters.altitudeLimit
avoidBuildings = taskParameters.avoidBuildings
buildingLimit = taskParameters.buildingLimit
terrainClamp = taskParameters.terrainClamp
heightAboveTerrain = taskParameters.heightAboveTerrain

if (avoidElevationContours == nil) then
   avoidElevationContours = false
end

if (altitudeLimit == nil) then
   altitudeLimit = 100000
end

if (avoidBuildings == nil) then
   avoidBuildings = false
end

if (buildingLimit == nil) then
   buildingLimit = 100000
end

if (terrainClamp == nil) then
   terrainClamp = true
end

if (heightAboveTerrain == nil) then
   heightAboveTerrain = 100
end

-- Called when the task first starts. Never called again.
function init()
   vrf:setTickPeriod(0.5)
   
   if (subTask ~= nil) then
      vrf:stopSubtask(subTask)
      subTask = nil
   end
   
   if (altitudeLimit < 0) then
      printWarn(vrf:trUtf8("Invalid altitude (%1)"):arg(altitudeLimit))
      vrf:endTask(false)
      return
   end

   if (buildingLimit == nil) then
      buildingLimit = -1
   end

   if (buildingLimit < 0) then
      printWarn(vrf:trUtf8("Invalid building height (%1)"):arg(buildingLimit))
      vrf:endTask(false)
      return
   end
      
   local bvol = this:getBoundingVolume()
   local length = bvol:getForward()
   local width = bvol:getRight()
   local bufferWidth = width/2 + 
      math.max(LENGTH_FACTOR * length,
      MIN_BUFFER)
   printVerbose("Buffer width ", bufferWidth)

   local queryString = ""
  
   if (avoidElevationContours == true) then
       queryString = "( " .. ftype .. " AND " .. maximumElevationAttr .. " >= " .. altitudeLimit .. " )"
   end

   if (avoidElevationContours == true and avoidBuildings == true) then
      queryString = queryString ..  " OR "
   end

   if (avoidBuildings == true) then
       queryString = queryString .. "( " .. structureFeatureType .. " AND " .. attributeStructureHeight .. " >= " .. buildingLimit .. " )"
   end

   printDebug("Query:\n\t" .. queryString)

   local clamping = terrainClamp
   local hat = heightAboveTerrain
   
   if (taskParameters.buffer ~= nil) then
      bufferWidth = taskParameters.buffer
   end   

   local params = {
      obstacleQuery = queryString,
      pathQuery = "NONE",
      buffer = bufferWidth,
      destinationObject = taskParameters.destination,
      displayRoute = taskParameters.displayRoute,
      terrainClamp = clamping,
      heightAboveTerrain = hat }
      
   subTask = vrf:startSubtask("air-navigate-to-waypoint", params)
end

-- Called each tick while this task is active.
function tick()
   if (not vrf:isSubtaskRunning(subTask)) then
      vrf:endTask(vrf:subtaskResult(subTask))
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
