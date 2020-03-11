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

checkpointState.numSubordinates = 0
checkpointState.numNeedCover = 0
checkpointState.numInCover = 0
checkpointState.subordinateStatus = {}
checkpointState.subordinateNames = {}
checkpointState.coverPoints = {}
checkpointState.startingPoint = Location3D(0,0,0)
checkpointState.job = nil
checkpointState.spacing = 0
checkpointState.pointToEntityMap = {}
checkpointState.prevRequestSize = 0



-- Task Parameters Available in Script
--  taskParameters.Threat Type: SimObject - Threat to find cover from
--  taskParameters.ThreatRadius Type: Real Unit: meters - The threat radius defines an area around the threat from which line-of-sight calculations are made
--  taskParameters.Range Type: Real Unit: meters - Distance at which to look for cover locations
--  taskParameters.DistanceFromThreat Type: Real Unit: meters - Minimum distance to keep from threat
--  taskParameters.ChooseFiringPosition Type: Bool (on/off) - Entities should choose firing positions (near edges or in low cover)
--  taskParameters.FaceThreat Type: Bool (on/off) - Whether entities should turn to face the threat once they are in cover
--  taskParameters.StartingLocation Type: Location3D - The starting location to perform the query from. Default is from the entity's location.

-- Constants indicating direction in which an entity can fire from the cover position. Only used when 
-- taskParameters.ChooseFiringPosition is true.
local NotFiringPosition = 0
local FireHigh = 1
local FireToRight = 2
local FireToLeft = 3

-- Called when the task first starts. Never called again.
function init()

   -- Initialize starting point to  be the unit location. We will then try to find the closest subordinate to
   -- this location and use that instead, just to be sure this is a point that can be reached.
   checkpointState.startingPoint = this:getLocation3D()
   
   local closestSubLoc = Location3D(0,0,0)
   local closestSubDist = 9999999

   -- Populate subordinate status table
   local subordinates = this:getAllSubordinates()
   for i, obj in pairs(subordinates) do
      if (obj:isValid() and vrf:entityTypeMatches(obj:getEntityType(), EntityType.Lifeform())) then
      
         checkpointState.numSubordinates = checkpointState.numSubordinates + 1
         checkpointState.numNeedCover  = checkpointState.numNeedCover + 1
         checkpointState.numInCover = 0
         
         -- See if this entity is closer to the center location than the current closest
         local distToCenter = obj:getLocation3D():distanceToLocation3D(checkpointState.startingPoint)
         if (distToCenter < closestSubDist) then
         
            closestSubDist = distToCenter
            closestSubLoc = obj:getLocation3D()
            
         end
         
         -- Set spacing based on first valid entity
         if (checkpointState.spacing == 0) then
         
            local bv = obj:getBoundingVolume()
            checkpointState.spacing = math.max(bv:getForward(), bv:getRight())
            
         end 
         
         table.insert(checkpointState.subordinateStatus, 
            {entity = obj,
             coverPoint = {},
             moveToTaskId = -1,
             facingThreat = false})
             
         checkpointState.subordinateNames[obj:getName()] = true    
             
      end
   end
   
   if (taskParameters.StartingLocation ~= nil and
      taskParameters.StartingLocation ~= Location3D(0,0,0)) then
      
      checkpointState.startingPoint = taskParameters.StartingLocation   
   
   elseif (closestSubLoc ~= nil and closestSubLoc ~= Location3D(0,0,0)) then
   
      checkpointState.startingPoint = closestSubLoc   
   
   end
   
   vrf:updateTaskVisualization("threat point", "point", 
      {color={200,0,0,100},
       location=taskParameters.Threat:getLocation3D(),
       size=taskParameters.ThreatRadius})

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.25)
   
end

function selectBestPointForEntity(entity, points)

   local entityLoc = entity:getLocation3D()
   local closestPtIdx = 0
   local dist = 999999   
   
   for i, pt in pairs(points) do
      
      if (not taskParameters.ChooseFiringPosition or
          pt.firingPosition ~= NotFiringPosition) then
      
         local distToPt = entityLoc:distanceToLocation3D(pt.point)
         if (distToPt < dist) then
            closestPtIdx = i
            dist = distToPt
         end
      end
   end
   
   if (closestPtIdx == 0) then
      return nil, false
   end
   
   return table.remove(points, closestPtIdx), true

end

function prunePoints(points)

   local checkRadius = math.max(checkpointState.spacing, 5)
   local types={EntityType.Platform(), EntityType.Lifeform(), EntityType.CulturalFeature()}
   local toRemove = {}
   
   local i = #points
   while (i > 0) do
   
      local prunePt = false
      
      -- Prune points that are already occupied by other objects
      local nearbyObjs = vrf:getSimObjectsNearWithFilter(points[i].point, checkRadius, types)
      for objNum, obj in pairs(nearbyObjs) do
     
         if (not checkpointState.subordinateNames[obj:getName()]) then
         
            local bv = obj:getBoundingVolume()
            local objSize = math.max(bv:getForward(), bv:getRight())
            if (points[i].point:distanceToLocation3D(obj:getLocation3D()) < objSize + checkpointState.spacing) then
            
               prunePt = true
               break
               
            end
         end
      end
      
      if not prunePt then
         -- Prune points that are already reserved for other objects in this unit
         for statusNum, status in pairs(checkpointState.subordinateStatus) do
        
               if (status.coverPoint ~=nil and next(status.coverPoint) and
                  points[i].point:distanceToLocation3D(status.coverPoint.point) < checkpointState.spacing) then
               
                  prunePt = true
                  break
                  
            end
         end
      end
   
      if not prunePt then
         -- Prune points that are too close to one another
         local j = i - 1
         while (j > 0) do
            
            if (points[i].point:distanceToLocation3D(points[j].point) < checkpointState.spacing) then
            
               prunePt = true
               break
            
            end
            j = j - 1
            
         end
      end
      
      if prunePt then
      
         vrf:updateTaskVisualization("pruned-" .. i, "point", 
            {color={200,0,200,200}, location=points[i].point, size=1})
         table.remove(points, i)
         
      end
      
      i = i - 1
      
   end

end

function markFiringPositions(points)

   if (not taskParameters.ChooseFiringPosition) then
      return
   end
   
   local OffsetForCheck = 1
   local CheckDist = 2

   for i, pt in pairs(points) do
      
      if not pt.isHigh then
      
         pt.firingPosition = FireHigh
         
      else
      
         local vecToThreat = pt.point:vectorToLoc3D(taskParameters.Threat:getLocation3D()):getUnit()
         local vecToRight = Vector3D(vecToThreat:getEast(), -vecToThreat:getNorth(), 0):getScaled(OffsetForCheck)
         local vecToLeft = vecToRight:getNegated()
         
         local rightPt = pt.point:addVector3D(vecToRight)
         local leftPt = pt.point:addVector3D(vecToLeft)
         
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
         
         pt.firingPosition = firingPos
         
      end   
      
   end

end

-- Called each tick while this task is active.
function tick()

   if (checkpointState.numSubordinates == 0) then
      printWarn(vrf:trUtf8("Unit contains no subordinates which are capable of taking cover."))
      vrf:endTask(false)
      return
   end

   -- Do people need cover? Do we have enough cover points already?
   if (checkpointState.numNeedCover > 0 and 
      #checkpointState.coverPoints < checkpointState.numNeedCover) then
   
      -- Are we already looking for some?
      if (checkpointState.job == nil) then
      
         -- Find a cover points. Find more than we need, just in case some are occupied.
         local numToRequest = math.max(checkpointState.numNeedCover * 4,
            checkpointState.prevRequestSize * 1.5)
            checkpointState.job = vrf:findCoverPoint(
            checkpointState.startingPoint,
            taskParameters.Threat:getLocation3D(), 
            taskParameters.ThreatRadius, 
            taskParameters.DistanceFromThreat,
            taskParameters.Range,
            numToRequest)
         checkpointState.prevRequestSize = numToRequest
            
         if checkpointState.job == nil then
            printWarn(vrf:trUtf8("Failed to start job"))
         end
            
      else
      
         -- See if the search is done
         local index = 0
         local message = ""
         checkpointState.coverPoints,index,message = checkpointState.job:getObject()            
         if (index == 1 and #checkpointState.coverPoints > 0) then
         
            prunePoints(checkpointState.coverPoints)
            markFiringPositions(checkpointState.coverPoints)
            checkpointState.job = nil
            
         
         elseif (index == 1) then

            if (message ~= nil and string.len(message) > 0) then
               printWarn(vrf:trUtf8("Failed to find any cover points: %1"):arg(message))
            else
               printWarn(vrf:trUtf8("Failed to find any cover points"))
            end
            vrf:endTask(false)
            return

         end            
      end
   end
   
   local removedSubs = {}
   checkpointState.numNeedCover = 0
   checkpointState.numInCover = 0
   for i, status in pairs(checkpointState.subordinateStatus) do
   
      if (not status.entity:isValid()) then
      
         -- Entity is gone
         table.insert(removedSubs, i)
         
      elseif (status.entity:isDestroyed()) then
      
         -- Clearly a little late for cover
         status.coverPoint = {}
         
      elseif (status.coverPoint ~= nil and next(status.coverPoint)) then
      
         -- Done moving?
         if (status.entity:getSpeed() == 0) then

             -- Should he crouch?
            if (not status.coverPoint.isHigh and
                status.entity:getLifeformPosture() ~= LifeformPosture.StringToEnum("crouching")) then
         
               vrf:sendSetData(status.entity, "set-lifeform-posture", {lifeform_posture = "crouching"})
            end
            
             -- Should he face the threat?
            if (taskParameters.FaceThreat and not status.facingThreat) then
            
               local vecToThreat = status.entity:getLocation3D():vectorToLoc3D(taskParameters.Threat:getLocation3D())
               vrf:sendTask(status.entity, "turn-to-heading", {heading=vecToThreat:getBearing()}, false)
               status.facingThreat = true
               
            end
            
         end
         
         if (status.moveToTaskId >= 0 and vrf:isTaskComplete(status.moveToTaskId)) then
            checkpointState.numInCover = checkpointState.numInCover + 1
         end
         
      else
      
         -- He needs cover.
         if (#checkpointState.coverPoints > 0) then
            
            -- Tell him where to go
            local validPointsLeft = true
            status.coverPoint, validPointsLeft = selectBestPointForEntity(status.entity, checkpointState.coverPoints)
            
            if (status.coverPoint ~= nil and next(status.coverPoint)) then
            
               -- Good, we got a valid point               
               vrf:sendSetData(status.entity, "set-lifeform-posture", {lifeform_posture = "standing"})
               vrf:sendSetData(status.entity, "set-speed", {speed = 9999})
               vrf:sendSetData(status.entity, "set-navigation-preference", {road_preference = "ignore-roads"})
               status.moveToTaskId = vrf:sendTask(status.entity, "move-to-location", {aiming_point = status.coverPoint.point})
               
               vrf:updateTaskVisualization(status.entity:getName() .. "-cp", "point", 
                  {color={0,200,0,200}, location=status.coverPoint.point, size=1})
            
            else
            
               -- Still needs cover
               checkpointState.numNeedCover = checkpointState.numNeedCover + 1
               
               if (not validPointsLeft) then
               
                  checkpointState.coverPoints = {}
                  
               end               
            end            
         else
         
            -- Still needs cover
            checkpointState.numNeedCover = checkpointState.numNeedCover + 1
            
         end      
      end      
   end
   
   local remIdx = #removedSubs
   while (remIdx > 0) do
      
      table.remove(checkpointState.subordinateStatus, removedSubs[remIdx])
      checkpointState.numSubordinates = checkpointState.numSubordinates - 1
      remIdx = remIdx - 1
   
   end
   
   for i, pt in pairs(checkpointState.coverPoints) do
   
      vrf:updateTaskVisualization("unused cp " .. i, "point", 
         {color={0,0,200,200}, location=pt.point, size=1})
         
   end
   
   if (checkpointState.numInCover == checkpointState.numSubordinates) then
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

   for statusNum, status in pairs(checkpointState.subordinateStatus) do
   
      local defaultSpeed = status.entity:getParameter("ordered-speed")
      vrf:sendSetData(status.entity, "set-speed", {speed = defaultSpeed})
      vrf:sendSetData(status.entity, "set-navigation-preference", {road_preference = "avoid-roads"})
      
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
