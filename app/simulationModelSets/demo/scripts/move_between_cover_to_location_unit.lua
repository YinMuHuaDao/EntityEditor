
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
checkpointState.lessPreferableDestinations = {}
checkpointState.findDestsJob = nil
checkpointState.nextTaskTime = 0
checkpointState.spacing = 0
checkpointState.needDestinations = true
checkpointState.numCandidateDestinations = 4
checkpointState.usedPoints = {}

local DRAW_DEBUG_VIS = false

-- Task Parameters Available in Script
--  taskParameters.Destination Type: Location3D - Location to move to
--  taskParameters.Threat Type: SimObject - The threat to find cover from
--  taskParameters.ThreatRadius Type: Real Unit: meters - The threat radius defines an area around the threat from which line-of-sight calculations are made
--  taskParameters.DistanceFromThreat Type: Real Unit: meters - Minimum distance to keep from the threat

local TaskInterval = 5

-- Called when the task first starts. Never called again.
function init()

   local subordinates = this:getSubordinates(true)
   
   -- Initialize list of current subordinate task ids to -1
   for i, obj in pairs(subordinates) do
      if (obj:isValid() and vrf:entityTypeMatches(obj:getEntityType(), EntityType.Lifeform())) then
      
         table.insert(checkpointState.subordinateTasks,
            { entity=obj, taskId = -1 })
         
         -- Set spacing based on first valid entity
         if (checkpointState.spacing == 0) then
         
            local bv = obj:getBoundingVolume()
            checkpointState.spacing = math.max(bv:getForward(), bv:getRight())
            
         end 
      
      end
   end
   
   checkpointState.needDestinations = true
   checkpointState.numCandidateDestinations = #checkpointState.subordinateTasks * 4
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.25)
   
end

function prunePoints(points, lessPreferablePoints)

   local OffsetForCheck = 1
   local CheckDist = 2

   local checkRadius = math.max(checkpointState.spacing, 5)
   local types={EntityType.Platform(), EntityType.Lifeform(), EntityType.CulturalFeature()}
   local toRemove = {}
   
   local i = #points
   while (i > 0) do
   
      local prunePt = false
      
      -- Prune points that are already occupied by other objects
      local nearbyObjs = vrf:getSimObjectsNearWithFilter(points[i].point, checkRadius, types)
      for objNum, obj in pairs(nearbyObjs) do
              
         local bv = obj:getBoundingVolume()
         local objSize = math.max(bv:getForward(), bv:getRight())
         if (points[i].point:distanceToLocation3D(obj:getLocation3D()) < objSize + checkpointState.spacing) then
         
            prunePt = true
            break
            
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
      
      if not prunePt then
         -- Prune points that are too close to previously used points
         for usedPtNum, usedPt in pairs(checkpointState.usedPoints) do
            
            if (points[i].point:distanceToLocation3D(usedPt) < checkpointState.spacing) then
            
               prunePt = true
               break
               
            end
         end
      end
      
      -- Non-firing positions are less preferable.
      if not prunePt and points[i].isHigh then
               
         local vecToThreat = points[i].point:vectorToLoc3D(taskParameters.Threat:getLocation3D()):getUnit()
         local vecToRight = Vector3D(vecToThreat:getEast(), -vecToThreat:getNorth(), 0):getScaled(OffsetForCheck)
         local vecToLeft = vecToRight:getNegated()
         
         local rightPt = points[i].point:addVector3D(vecToRight)
         local leftPt = points[i].point:addVector3D(vecToLeft)
         
         vecToThreat = vecToThreat:getScaled(CheckDist)
         local rightCheckPt = rightPt:addVector3D(vecToThreat)
         local leftCheckPt = leftPt:addVector3D(vecToThreat)
      
         local dataAvailRight = false
         local dataAvailLeft = false
         local losSide = false
         local isFiringPos = false
         
         while ((not dataAvailRight or not dataAvailLeft) and not isFiringPos) do
         
            local losBlocked = true
            losBlocked, dataAvailRight = vrf:doesChordHitTerrain(rightPt, rightCheckPt)
            if (dataAvailRight and not losBlocked) then
               isFiringPos = true
            end
            
            if (not isFiringPos) then
               losBlocked, dataAvailLeft = vrf:doesChordHitTerrain(leftPt, leftCheckPt)
               if (dataAvailLeft and not losBlocked) then
                  isFiringPos = true
               end
            end
         
         end
         
         if not isFiringPos then
            
            -- Prune it from the main list and add to the less preferable one
            prunePt = true
            table.insert(lessPreferablePoints, points[i])
            
         end
         
      end
         
      
      if prunePt then
         
         if DRAW_DEBUG_VIS then
            vrf:updateTaskVisualization("Pruned" .. i, "point", 
               {color={255,0,0,255},
                location=points[i].point,
                size=2})
         end
                
         table.remove(points, i)
      
      else
         
         if DRAW_DEBUG_VIS then
            vrf:updateTaskVisualization("Not-Pruned" .. i, "point", 
               {color={0,255,255,255},
                location=points[i].point,
                size=2})    
         end  
      
      end
      
      i = i - 1
      
   end

end

function selectBestPointForEntity(entity, points)

   local entityLoc = entity:getLocation3D()
   local closestPtIdx = 0
   local dist = 999999   
   
   for i, pt in pairs(points) do

      local distToPt = entityLoc:distanceToLocation3D(pt.point)
      if (distToPt < dist) then
         closestPtIdx = i
         dist = distToPt
      end
      
   end
   
   if (closestPtIdx == 0) then
      return nil, false
   end
   
   table.insert(checkpointState.usedPoints, points[closestPtIdx].point)
   
   return table.remove(points, closestPtIdx), true

end

-- Called each tick while this task is active.
function tick()

   if not taskParameters.Threat:isValid() then
      -- We have threat to find cover from
      printWarn(vrf:trUtf8("Cannot perform task: no valid threat selected."))
      vrf:endTask(false)
      return
   end      

   if #checkpointState.subordinateTasks == 0 then
      -- We have no taskable human subordinates
      printWarn(vrf:trUtf8("Cannot perform task: no human subordinate entities."))
      vrf:endTask(false)
      return
   end      

   if #checkpointState.destinations == 0 and
      checkpointState.needDestinations and
      checkpointState.findDestsJob == nil then
      
      -- We need to figure out where these guys are heading to. They obviously can't all stand in the same spot,
      -- and they really should all finish in cover. Let's find some firing positions near the destination.      
      
      -- Make a visualization for the specified destination point
      vrf:updateTaskVisualization("Destination", "point", 
         {color={0,255,0,255},
          location=taskParameters.Destination,
          size=2})
      
      -- Start a new job to find our destination firing positions.
      checkpointState.findDestsJob = vrf:findCoverPoint(
         taskParameters.Destination,
         taskParameters.Threat:getLocation3D(), 
         taskParameters.ThreatRadius, 
         taskParameters.DistanceFromThreat,
         100, -- should be within 100m of desired destination
         checkpointState.numCandidateDestinations)
         
      -- In case we need to find additional points because the found points are rejected, increase the number
      -- that will be requested next time
      checkpointState.numCandidateDestinations = 
         checkpointState.numCandidateDestinations + #checkpointState.subordinateTasks
      
   elseif #checkpointState.destinations == 0 and checkpointState.needDestinations then
      -- We have a job going to find destination firing positions. Is it done?
      
      local index = 0
      local message = ""
      checkpointState.destinations,index,message = checkpointState.findDestsJob:getObject()            
      if (index == 1 and #checkpointState.destinations > 0) then
         -- Great, we have some destination firing positions.
         
         -- Prune the list down to the best ones and the less preferable but usable ones.
         checkpointState.lessPreferableDestinations = {}
         prunePoints(checkpointState.destinations, checkpointState.lessPreferableDestinations)
         checkpointState.job = nil
         
         local totalPossibleDests = #checkpointState.destinations + #checkpointState.lessPreferableDestinations
         if index == 1 and totalPossibleDests < #checkpointState.subordinateTasks then

            printWarn(vrf:trUtf8("Failed to find enough cover points near destination. %1/%2"):
               arg(totalPossibleDests):arg(#checkpointState.subordinateTasks))
            vrf:endTask(false)
            return
            
         end
      
         checkpointState.findDestsJob = nil   
      
      elseif (index == 1) then

         printWarn(vrf:trUtf8("Failed to find any cover points near destination."))
         vrf:endTask(false)
         return

      end 
   
   end
   
   local currTime = vrf:getSimulationTime()
   local removedSubs = {}
   local numDone = 0
   local numNeedDests = #checkpointState.subordinateTasks
   
   -- Check on task status
   for i, subordTask in pairs(checkpointState.subordinateTasks) do
   
      if not subordTask.entity:isValid() then
      
         -- Entity is gone
         table.insert(removedSubs, i)
         numNeedDests = numNeedDests - 1
         
      elseif subordTask.entity:isDestroyed() then
      
         -- This one is dead, so it's definitely done moving.
         numDone = numDone + 1
         numNeedDests = numNeedDests - 1
         
      elseif subordTask.taskId < 0 and currTime > checkpointState.nextTaskTime and 
         (#checkpointState.destinations > 0 or #checkpointState.lessPreferableDestinations > 0) then
         -- Time to task another subordinate
         
         checkpointState.nextTaskTime = currTime + TaskInterval
      
         local dest = {}
         if #checkpointState.destinations > 0 then
            dest = selectBestPointForEntity(subordTask.entity, checkpointState.destinations)
         else
            dest = selectBestPointForEntity(subordTask.entity, checkpointState.lessPreferableDestinations)
         end
         
         subordTask.taskId = vrf:sendTask(subordTask.entity, "Move_Between_Cover_To_Location",
            {Location = dest.point,
             Threat = taskParameters.Threat,
             ThreatRadius = taskParameters.ThreatRadius,
             DistanceFromThreat = taskParameters.DistanceFromThreat})
         subordTask.destination = dest
         
         vrf:updateTaskVisualization("Destination" .. subordTask.entity:getName(), "point", 
            {color={0,255,125,255},
             location=dest.point,
             size=2})
             
         numNeedDests = numNeedDests - 1
      
      elseif subordTask.taskId >= 0 then
         
         if vrf:isTaskComplete(subordTask.taskId) then
            
            if vrf:taskResult(subordTask.taskId) then
               -- This one is done         
               numDone = numDone + 1
               numNeedDests = numNeedDests - 1
            else
               -- This one failed, needs a new destination
               subordTask.taskId = -1
               subordTask.destination = {}
            end
            
         else
         
            -- Still moving, doesn't need a new destination
            numNeedDests = numNeedDests - 1
            
         end
         
      end
      
   end
   
   if numNeedDests == 0 then
      checkpointState.needDestinations = false
   else
      checkpointState.needDestinations = true
   end
   
   local remIdx = #removedSubs
   while remIdx > 0 do
      
      table.remove(checkpointState.subordinateTasks, removedSubs[remIdx])
      remIdx = remIdx - 1
   
   end
   
   if numDone >= #checkpointState.subordinateTasks then
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
