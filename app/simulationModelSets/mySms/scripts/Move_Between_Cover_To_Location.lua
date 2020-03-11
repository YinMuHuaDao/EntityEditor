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

local CoverPointRange = 20
local DistanceToMovePerStep = 20
local PauseBetweenSteps = 1
local MaxPauseVariance = 1
local OccupiedCheckRadius = 5
local TimeToWaitForDestinationToClear = 8

local PlaceholderType = "16:0:0:1:0:0:104"

-- If you wish to change the mode, call setCheckpointMode(AllGlobals) to save all globals or setCheckpointMode(CheckpointStateOnly)
-- to save only those variables in the checkpointState table
-- They get re-initialized when a checkpointed scenario is loaded.
vrf:setCheckpointMode(CheckpointStateOnly)

checkpointState.job = nil
checkpointState.path = {}
checkpointState.moveSubtaskId = -1
checkpointState.currDistOnPath = 0
checkpointState.atEnd = false
checkpointState.nextMoveTime = 0
checkpointState.finalPoint = Location3D(0,0,0)
checkpointState.space = 0
checkpointState.placeholderObj = nil
checkpointState.destinationWaitTime = 0

-- Task Parameters Available in Script
--  taskParameters.Location Type: Location3D - Location to move to
--  taskParameters.Threat Type: SimObject - The threat to find cover from
--  taskParameters.ThreatRadius Type: Real Unit: meters - The threat radius defines an area around the threat from which line-of-sight calculations are made
--  taskParameters.DistanceFromThreat Type: Real Unit: meters - Distance to keep from the threat


-- Called when the task first starts. Never called again.
function init()

   local bv = this:getBoundingVolume()
   checkpointState.space = math.max(bv:getForward(), bv:getRight())

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.25)

end

-- Finds the location on the path that is the specified distance from the start.
-- Returns this location as well as a bool indicating whether we have reached the 
-- end of the path.
function findLocationAlongPath(distance)

   if (not next(checkpointState.path)) then
      -- No path!
      return nil, true
   end
   
   if (#checkpointState.path == 1) then
      -- Only a single point!
      return checkpointState.path[1], true
   end
   
   local currVertexDist = 0
   local nextVertexDist = 0
   local v = 1
   
   while (v < #checkpointState.path and nextVertexDist < distance) do
   
      currVertexDist = nextVertexDist
      nextVertexDist = nextVertexDist + 
         checkpointState.path[v]:distanceToLocation3D(checkpointState.path[v+1])
      v = v + 1      
   
   end
   
   if (nextVertexDist <= distance) then
      
      -- End of the path. Return the final point and indicate our arrival.
      return checkpointState.path[v], (v == #checkpointState.path)
      
   end
   
   -- Location is somewhere between v-1 and v.
   local vec = checkpointState.path[v-1]:vectorToLoc3D(checkpointState.path[v])
   vec = vec:getUnit():getScaled(distance - currVertexDist)
   local location = checkpointState.path[v-1]:addVector3D(vec)
   
   return location, false
   
end

-- Called each tick while this task is active.
function tick()

   local distFromThreat = taskParameters.Location:distanceToLocation3D(taskParameters.Threat:getLocation3D())
   if (distFromThreat < taskParameters.DistanceFromThreat) then
      printWarn(vrf:trUtf8("Destination is closer to threat (%1 m) than the minimum required distance (%2 m)."):
         arg(distFromThreat):arg(taskParameters.DistanceFromThreat))
      vrf:endTask(false)
      return
   end

   if (not checkpointState.job and #checkpointState.path == 0) then
   
      -- Start job to find a general path to location.
      checkpointState.job = vrf:findPathToLocation(
         this:getLocation3D(), taskParameters.Location, false,
         taskParameters.Threat:getLocation3D(), 
         taskParameters.DistanceFromThreat)
      
   elseif (#checkpointState.path == 0) then
   
      -- Do we have a path yet?
      checkpointState.path,index,message = checkpointState.job:getObject()
      if (index == 1 and #checkpointState.path > 0) then
         
         if (#checkpointState.path < 2) then
         
            -- Not sure why this would happen, but just in case, add our start and end locations
            table.insert(checkpointState.path, 1, this:getLocation3D())
            table.insert(checkpointState.path, taskParameters.Location)
         
         end
         
         vrf:updateTaskVisualization("path ", "line", 
            {color={144,238,144,200}, locations=checkpointState.path, offset=Vector3D(0, 0, -0.5)})
      
      elseif (index == 1) then
         if (message ~= nil and string.len(message) > 0) then
            printWarn(vrf:trUtf8("Failed to find path to destination: %1"):arg(message))
         else
            printWarn(vrf:trUtf8("Failed to find path to destination."))
         end
         vrf:endTask(false)

      end

   elseif (checkpointState.moveSubtaskId < 0) then
   
      -- Need to start movement?
      if (vrf:getSimulationTime() > checkpointState.nextMoveTime) then
   
         local nextPt = nil
            
         if (not checkpointState.atEnd) then
            -- Find a point at the next step distance along the path.
            nextPt, checkpointState.atEnd = findLocationAlongPath(checkpointState.currDistOnPath)
            checkpointState.currDistOnPath = checkpointState.currDistOnPath + DistanceToMovePerStep
            if (checkpointState.atEnd) then 
               checkpointState.finalPoint = nextPt 
               checkpointState.destinationWaitTime = vrf:getSimulationTime() + TimeToWaitForDestinationToClear
            end
         end
         
         if (checkpointState.atEnd) then
            
            -- Make sure the destination is clear. If not, wait a bit longer.
            local checkRadius = math.max(checkpointState.space, OccupiedCheckRadius)
            local typesToFind={EntityType.Platform(), EntityType.Lifeform(), EntityType.CulturalFeature(), PlaceholderType}
            local nearbyObjs = vrf:getSimObjectsNearWithFilter(checkpointState.finalPoint,
               OccupiedCheckRadius, {types=typesToFind})
            local occupied = false
            for objNum, obj in pairs(nearbyObjs) do
               
               if obj ~= this then
                  local bv = obj:getBoundingVolume()
                  local objSize = math.max(bv:getForward(), bv:getRight())
                  if (checkpointState.finalPoint:distanceToLocation3D(obj:getLocation3D()) < objSize + checkpointState.space) then
                  
                     occupied = true
                     
                  end
               end
            end
            
            if occupied then
            
               -- Check if we have waited long enough. Could be whoever is occupying our destination location is just not going to move.
               -- If it's still occupied, just give it up and stay here.
               if checkpointState.destinationWaitTime <  vrf:getSimulationTime() then
                  vrf:endTask(true)
                  return                  
               end
               
            else
            
               -- We're at the end of our path and the point is not occupied. Just go to the destination.
               checkpointState.placeholderObj = vrf:createTacticalGraphic(
                  {location=checkpointState.finalPoint,
                   entity_type=PlaceholderType,
                   publish=false})
               vrf:executeSetData("set-lifeform-posture", {lifeform_posture = "standing"})
               checkpointState.moveSubtaskId = vrf:startSubtask("move-to-location", 
                  {aiming_point=checkpointState.finalPoint, speed=99999})
                  
            end
            
         else
         
            -- Find the next point on the path we will probably use. This is necessary to know the general direction we want to find cover in.
            local futurePt = findLocationAlongPath(checkpointState.currDistOnPath)
            local forwardDirection = nextPt:vectorToLoc3D(futurePt)
         
            -- We need to move to a cover point near this next point
            vrf:executeSetData("set-lifeform-posture", {lifeform_posture = "standing"})
            checkpointState.moveSubtaskId = vrf:startSubtask("Find_Cover",
               {Threat=taskParameters.Threat, 
                ThreatRadius=taskParameters.ThreatRadius, 
                DistanceFromThreat=taskParameters.DistanceFromThreat,
                StartFrom=1, -- specified starting location
                StartingLocation=nextPt, 
                Range=CoverPointRange,
                OnlyForward=true, 
                ForwardDirection=forwardDirection:getBearing()})
               
         end 
      
      end
      
   elseif (vrf:isSubtaskComplete(checkpointState.moveSubtaskId)) then
   
      if (checkpointState.atEnd) then
         
         -- This was the completion of the final movement task.
         vrf:endTask(true)
         return
         
      end
      
      checkpointState.moveSubtaskId = -1
      
      -- Pause for a few seconds
      checkpointState.nextMoveTime = vrf:getSimulationTime() + PauseBetweenSteps + (MaxPauseVariance * math.random())      
      
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
   if checkpointState.placeholderObj ~= nil then
      vrf:deleteObject(checkpointState.placeholderObj)
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
