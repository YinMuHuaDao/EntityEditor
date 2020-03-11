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

checkpointState.moveSubtaskId = -1
checkpointState.turnSubtaskId = -1
checkpointState.coverPoint = Location3D(0,0,0)
checkpointState.startingPoint = Location3D(0,0,0)
checkpointState.coverIsHigh = false
checkpointState.job = nil
checkpointState.space = 0
checkpointState.pointsToFind = 4
checkpointState.placeholderObj = nil

-- Task Parameters Available in Script
--  taskParameters.Threat Type: SimObject - Threat to find cover from
--  taskParameters.ThreatRadius Type: Real Unit: meters - The threat radius defines an area around the threat from which line-of-sight calculations are made
--  taskParameters.Range Type: Real Unit: meters - Distance at which to look for cover locations
--  taskParameters.DistanceFromThreat Type: Real Unit: meters - Minimum distance to keep from threat
--  taskParameters.ChooseFiringPosition Type: Bool (on/off) - Entities should choose firing positions (near edges or in low cover)
--  taskParameters.FaceThreat Type: Bool (on/off) - Whether entities should turn to face the threat once they are in cover
--  taskParameters.StartingLocation Type: Location3D - The starting location to perform the query from. Default is from the entity's location.
--  taskParameters.StartFrom Type: Integer (0 - choice limit) - Location from which the entity should begin looking for cover points
--  taskParameters.OnlyForward Type: Bool (on/off) - Indicates that cover points behind the entity should be avoided
--  taskParameters.ForwardDirection Type: Real Unit: radian - Direction of forward movement. Only used when Only Forward is true


-- Constants indicating direction in which an entity can fire from the cover position. Only used when 
-- taskParameters.ChooseFiringPosition is true.
local NotFiringPosition = 0
local FireHigh = 1
local FireToRight = 2
local FireToLeft = 3

local StartFromEntityLocation = 0
local StartFromSpecifiedLocation = 1

local PlaceholderType = "16:0:0:1:0:0:104"

-- Called when the task first starts. Never called again.
function init()
   
   vrf:updateTaskVisualization("threat point", "point", 
      {color={200,0,0,100},
       location=taskParameters.Threat:getLocation3D(),
       size=taskParameters.ThreatRadius})
       
   local bv = this:getBoundingVolume()
   checkpointState.space = math.max(bv:getForward(), bv:getRight())
   
   if (taskParameters.StartFrom == StartFromEntityLocation or
      taskParameters.StartingLocation == nil or
      taskParameters.StartingLocation == Location3D(0,0,0)) then
      
      checkpointState.startingPoint = this:getLocation3D()
   
   else
      
      checkpointState.startingPoint = taskParameters.StartingLocation   
   
   end

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.25)
   
end

function isFiringPosition(point)
   
   local OffsetForCheck = 1
   local CheckDist = 2
   
   point.firingPosition = NotFiringPosition
      
   if not point.isHigh then
   
      point.firingPosition = FireHigh
      
   else
   
      local vecToThreat = point.point:vectorToLoc3D(taskParameters.Threat:getLocation3D()):getUnit()
      local vecToRight = Vector3D(vecToThreat:getEast(), -vecToThreat:getNorth(), 0):getScaled(OffsetForCheck)
      local vecToLeft = vecToRight:getNegated()
      
      local rightPt = point.point:addVector3D(vecToRight)
      local leftPt = point.point:addVector3D(vecToLeft)
      
      vecToThreat = vecToThreat:getScaled(CheckDist)
      local rightCheckPt = rightPt:addVector3D(vecToThreat)
      local leftCheckPt = leftPt:addVector3D(vecToThreat)
   
      local dataAvailRight = false
      local dataAvailLeft = false
      local losSide = false
      local firingPos = NotFiringPosition
      
      while ((not dataAvailRight or not dataAvailLeft) and firingPos == NotFiringPosition) do
      
         local losBlocked = true
         losBlocked, dataAvailRight = vrf:doesChordHitTerrain(rightPt, rightCheckPt)
         if (dataAvailRight and not losBlocked) then
            firingPos = FireToRight
         end
         
         if (firingPos == NotFiringPosition) then
            losBlocked, dataAvailLeft = vrf:doesChordHitTerrain(leftPt, leftCheckPt)
            if (dataAvailLeft and not losBlocked) then
               firingPos = FireToLeft
            end
         end
      
      end
      
      point.firingPosition = firingPos
      
   end
   
   return (point.firingPosition ~= NotFiringPosition)

end

function prunePoints(points)

   local checkRadius = math.max(checkpointState.space, 5)
   local typesToFind={EntityType.Platform(), EntityType.Lifeform(), EntityType.CulturalFeature(), PlaceholderType}
   local toRemove = {}
   
   local forwardDirection = Vector3D(0,0,0)
   forwardDirection:setBearingInclRange(taskParameters.ForwardDirection, 0, 1)
      
   local i = #points
   while (i > 0) do
   
      if (taskParameters.ChooseFiringPosition and         
         not isFiringPosition(points[i])) then
      
         -- Prune points that are not firing positions
         vrf:updateTaskVisualization("pruned-" .. i, "point", 
            {color={200,0,200,200}, location=points[i].point, size=1})
         table.remove(points, i)
      
      else
      
         local pruned = false
         
         if (taskParameters.OnlyForward) then
         
            -- Prune points that are behind the entity 
            local currentLocation = this:getLocation3D()
            local vecToPoint = currentLocation:vectorToLoc3D(points[i].point)
            if (forwardDirection:headingDiff(vecToPoint) > (math.pi/2)) then
         
               vrf:updateTaskVisualization("pruned-" .. i, "point", 
                  {color={200,0,200,200}, location=points[i].point, size=1})
               table.remove(points, i)
               pruned = true
            end
         end
      
         if not pruned then
	 
            -- Prune points that are already occupied by other objects            
            local nearbyObjs = vrf:getSimObjectsNearWithFilter(points[i].point, checkRadius, {types=typesToFind})
            for objNum, obj in pairs(nearbyObjs) do
               
               if obj ~= this then
                  local bv = obj:getBoundingVolume()
                  local objSize = math.max(bv:getForward(), bv:getRight())
                  if (points[i].point:distanceToLocation3D(obj:getLocation3D()) < objSize + checkpointState.space) then
                  
                     vrf:updateTaskVisualization("pruned-" .. i, "point", 
                        {color={200,0,200,200}, location=points[i].point, size=1})
                     table.remove(points, i)
                     break
                              
                  end
               end
            end
         end
      end
      
      i = i - 1
      
   end
end


-- Called each tick while this task is active.
function tick()

   if (not checkpointState.job and
      checkpointState.moveSubtaskId == -1 and
      checkpointState.turnSubtaskId == -1) then
   
      -- Not doing anything yet, find a cover point.
      checkpointState.job = vrf:findCoverPoint(
         checkpointState.startingPoint,
         taskParameters.Threat:getLocation3D(), 
         taskParameters.ThreatRadius, 
         taskParameters.DistanceFromThreat,
         taskParameters.Range,
         checkpointState.pointsToFind)
      
   elseif (checkpointState.moveSubtaskId == -1 and
      checkpointState.turnSubtaskId == -1) then
      
      -- Do we have a cover point yet?
      local result,index,message = checkpointState.job:getObject()
      if (index == 1 and #result > 0) then
      
         -- Prune points that are occupied or not firing positions (if that is required)
         prunePoints(result)
      
         if (#result > 0) then
         
            -- Found cover, get moving.
            vrf:executeSetData("set-speed", {speed = 9999})
            vrf:executeSetData("set-navigation-preference", {road_preference = "ignore-roads"})
            checkpointState.coverPoint = result[1].point
            checkpointState.coverIsHigh = result[1].isHigh
            checkpointState.placeholderObj = vrf:createTacticalGraphic(
               {location=checkpointState.coverPoint,
                entity_type=PlaceholderType,
                publish=false})
            checkpointState.moveSubtaskId = vrf:startSubtask("move-to-location", {aiming_point = checkpointState.coverPoint})
            checkpointState.job = nil
   
            for i, pt in pairs(result) do
            
               if i ~= 1 then
                  vrf:updateTaskVisualization("unused cp " .. i, "point", 
                     {color={0,0,200,200}, location=pt.point, size=1})
               end
                  
            end
            
         else
            -- No points left after pruning. Find some more.
            checkpointState.job = nil
            checkpointState.pointsToFind = checkpointState.pointsToFind + 4
         end
      
      elseif (index == 1) then

         if (message ~= nil and string.len(message) > 0) then
            printWarn(vrf:trUtf8("Failed to find cover point: %1"):arg(message))
         else
            printWarn(vrf:trUtf8("Failed to find cover point"))
         end
         vrf:endTask(false)

      end
   
   elseif (checkpointState.moveSubtaskId >= 0) then
         
      -- See if we are done moving.
      if (vrf:isSubtaskComplete(checkpointState.moveSubtaskId)) then
      
         checkpointState.moveSubtaskId = -1
      
         if (not checkpointState.coverIsHigh) then
            vrf:executeSetData("set-lifeform-posture", {lifeform_posture = "crouching"})
         end
            
         if (taskParameters.FaceThreat) then
         
            local vecToThreat = this:getLocation3D():vectorToLoc3D(taskParameters.Threat:getLocation3D())         
            checkpointState.turnSubtaskId = vrf:startSubtask("turn-to-heading", {heading=vecToThreat:getBearing()})
            
         else
      
            vrf:endTask(true)
            
         end    
      end   
   elseif (checkpointState.turnSubtaskId >= 0) then  
   
      -- See if we are done turning.
      if (vrf:isSubtaskComplete(checkpointState.turnSubtaskId)) then
      
         vrf:endTask(true)
      
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
   local defaultSpeed = this:getParameter("ordered-speed")
   vrf:executeSetData("set-speed", {speed = defaultSpeed})
   vrf:executeSetData("set-navigation-preference", {road_preference = "avoid-roads"})
   
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
