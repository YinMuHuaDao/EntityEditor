-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

local DEBUG_DETAIL = false

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
crowdRadius = 0
points = {}  -- the destination points, sorted by distance from center
peds = {}    -- pedestrians, sorted by time to destination center
numPeds = 0
tasked = false
needToMoveList = {}
numberLeftToMove = 0
movementTaskIds = {}
turnTaskIds = {}
job = nil
idleTask = "Civilian_Idle"
leftOfLinePoints = {}
ignoredSubordinates = {}

local resumeTask = "wander"

local westernMaleCivType = "3:1:225:3:0:1:0"
local westernFemaleCivType = "3:1:225:3:1:1:0"
local mideastMaleCivType = "3:1:1:3:1:0:3"
local mideastFemaleCivType = "3:1:1:3:1:0:2"

local speedTable = {
   [westernMaleCivType] = {minSpeed=1.0, maxSpeed=1.5},
   [westernFemaleCivType] = {minSpeed=1.0, maxSpeed=1.10},
   [mideastMaleCivType] = {minSpeed=0.66, maxSpeed=1.5},
   [mideastFemaleCivType] = {minSpeed=0.66, maxSpeed=1.10} }
local defaultSpeed = {minSpeed=1.0, maxSpeed=1.10}

local minCrowdRadius = 5
local minDistanceBetweenPeople = 1.3
local maxNumberToMovePerTick = 10

-- Task Parameters Available in Script
--  taskParameters.locationOfInterest Type: Location3D - The location to crowd around
--  taskParameters.minDistance Type: Distance - The minimum distance from the location of interest
--  taskParameters.idleTask Type: String - The task which will be given to each pedestrian when they arrive
--  taskParameters.speedMultiplier Type: Real - Chosen speed for each entity is multiplied by this value. Used to slow down or speed up entities.
--  taskParameters.keepLeftOfLine Type: Boolean - Whether entities should crowd only to the left of specified line
--  taskParameters.leftOfLineStart Type: Location3D - Start of the line from which entities will stay to the left
--  taskParameters.leftOfLineEnd Type: Location3D - End of the line from which entities will stay to the left
--  taskParameters.leftOfLine Type: SimObject - Object which defines the line from which entities will stay to the left. If set, leftOfLineStart and leftOfLineEnd are ignored.
--  taskParameters.reverseLeftOfLine Type: Boolean - The leftOfLine object's vertices will be considered in reverse order when determining if a point is to the left of the line
--  taskParameters.faceLeftOfLine Type: Boolean - Whether entities should face the leftOfLine instead of the locationOfInterest
--  taskParameters.subordinatesToIgnore Type:SimObjects - These subordinates will be ignored and will not be tasked to crowd around.

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   if taskParameters.idleTask ~= nil and taskParameters.idleTask ~= "" then
      idleTask = taskParameters.idleTask
   end
   
   if taskParameters.keepLeftOfLine then
      if taskParameters.leftOfLine:isValid() then
      
         -- reverse the points if necessary
         if taskParameters.reverseLeftOfLine then
            local reversePoints = taskParameters.leftOfLine:getLocations3D()
            local numPoints = #reversePoints
            for i, pt in pairs(reversePoints) do
               leftOfLinePoints[numPoints-i+1] = pt
            end
         else
            leftOfLinePoints = taskParameters.leftOfLine:getLocations3D()
         end
         
      else
         leftOfLinePoints = { taskParameters.leftOfLineStart, taskParameters.leftOfLineEnd }
      end
   end
   
   -- Create a set of subordinates to be ignored (for easy lookup)
   ignoredSubordinates = {}
   for i, sub in pairs(taskParameters.subordinatesToIgnore) do
      ignoredSubordinates[sub:getUUID()] = true
   end
   
end

function findVectorToFace(location, vertices)

   local vecToFace = location:vectorToLoc3D(taskParameters.locationOfInterest)
   
   if taskParameters.faceLeftOfLine then
                  
      local vertex = nil
      local nextVertex = nil
      local index = 0
      local nextIndex = 0
      
      local closestDist = 99999999
      local closestPoint = nil
      local negateVec = false
      
      -- Find closest point on the closest segment
      for index, vertex in pairs(vertices) do
         nextIndex, nextVertex = next(vertices, index)
         if nextIndex ~= nil then
         
            local vectorOfSegment = vertex:vectorToLoc3D(nextVertex)
            local vectorToSegment = Vector3D(0,0,0)
            
            local isLeftOfLine = location:isLeftOfLine(vertex, nextVertex)
            if isLeftOfLine then
               vectorToSegment:setBearingInclRange(vectorOfSegment:getBearing() + (math.pi/2), 0, 1)
            else
               vectorToSegment:setBearingInclRange(vectorOfSegment:getBearing() - (math.pi/2), 0, 1)
            end
            
            local dist = math.max(vertex:distanceToLocation3D(location), nextVertex:distanceToLocation3D(location))
            vectorToSegment = vectorToSegment:getScaled(dist)
            
            -- Get the end point of a perpendicular line from the location
            local perpLineEnd = location:addVector3D(vectorToSegment)
            
            local intersectPoint = Location3D(0,0,0)
            local doesIntersect, intersectPoint = vrf:intersectSegments2D(location, perpLineEnd, vertex, nextVertex)
            if doesIntersect then
               dist = intersectPoint:distanceToLocation3D(location)
               
               if dist < closestDist then
                  closestDist = dist
                  closestPoint = intersectPoint
                  
                  if isLeftOfLine then
                     negateVec = false
                  else
                     negateVec = true
                  end
               end
            end
         end
         
         if closestPoint ~= nil then
            vecToFace = location:vectorToLoc3D(closestPoint)
            
            if negateVec then
               vecToFace = vecToFace:getNegated()
            end
         end
         
      end
   end
   
   return vecToFace
end
         
         
-- Called each tick while this task is active.
function tick()

   if DEBUG_DETAIL then
      -- debug task visualizations
      vrf:updateTaskVisualization("locationOfInterest", "point", 
         {color={0,255,0,200}, size=1, location=taskParameters.locationOfInterest})
         
      if next(leftOfLinePoints) ~= nil then
         vrf:updateTaskVisualization("leftOfLine", "line", 
            {color={0,255,255,200}, locations=leftOfLinePoints})
      end
   end
   
   -- Get the list of pedestrians
   if next(peds) == nil then
      
      local pedsUnsorted = this:getSubordinates(true)
      
      if next(pedsUnsorted) == nil then
         printWarn(vrf:trUtf8("No pedestrians in crowd"))
         vrf:endTask(false)
         return
      end
      
      -- sort the pedestrians by travel time to the location
      for i, ped in pairs(pedsUnsorted) do
      
         if not ignoredSubordinates[ped:getUUID()] then      
            local dist = ped:getLocation3D():distanceToLocation3D(taskParameters.locationOfInterest)
                     
            -- pick a speed based on entity type
            local orderedSpeed = 0
            local entityType = ped:getEntityType()
            for matchingType, speeds in pairs(speedTable) do
               if vrf:entityTypeMatches(matchingType, entityType) then
                  orderedSpeed = (math.random() * (speeds.maxSpeed - speeds.minSpeed)) +
                     speeds.minSpeed
               end
            end
               
            -- No matching entity type, use default speed range
            if orderedSpeed <= 0 then
               orderedSpeed = (math.random() * (defaultSpeed.maxSpeed - defaultSpeed.minSpeed)) +
                  defaultSpeed.minSpeed
            end
            
            orderedSpeed = orderedSpeed * taskParameters.speedMultiplier
            
            local pedEntry = {entity=ped, timeToWalk=dist/orderedSpeed, speed=orderedSpeed}
            table.insert(peds, pedEntry)
            numPeds = numPeds + 1
         end
      end
      table.sort(peds, function(a,b) return a.timeToWalk < b.timeToWalk end)      
   end

   -- Calculate the radius of the crowd around the destination point based on the
   -- number of people
   if crowdRadius <= 0 then
      local radiusSq = (numPeds * numPeds)/math.pi
      crowdRadius = math.max(math.sqrt(radiusSq), minCrowdRadius)
   end
   
   -- Generate random points around the destination location
   if next(points) == nil then
      if job == nil then
         job = vrf:generateRandomPoints({
            number_of_points=numPeds,
            access_point=taskParameters.locationOfInterest,
            min_distance_from_access_point=taskParameters.minDistance,
            max_distance_from_access_point=crowdRadius,
            min_distance_between_points=minDistanceBetweenPeople,
            placement_restriction="free",
            tightly_pack=true,
            need_line_of_sight=true,
            left_of_line=leftOfLinePoints})
         
         if (not job) then
            printWarn(vrf:trUtf8("Could not start async job to generate destination points"))
            vrf:endTask(false)
            return
         end
      else
         
         -- see if random points have been generated
         local randomPoints,index,message = job:getObject()
         if (index == 1) then
         
            local numPoints = #randomPoints
               
            if (numPoints == 0) then 
               printWarn(vrf:trUtf8("Failed to generate any valid pedestrian positions."))
               vrf:endTask(false)
               return
            elseif numPoints < numPeds then
               printInfo(vrf:trUtf8("Could not generate valid positions for requested number of pedestrians: %1 / %2"):
                  arg(numPoints):arg(numPeds))
                  
               -- Just make up some spots around the edge and hope for the best
               local randomVect = Vector3D(0,0,0)
               while numPoints < numPeds do
                  local entityHeading = 
                  randomVect:setBearingInclRange(math.rad(math.random(360)), 0, crowdRadius)
                  local randomPoint = taskParameters.locationOfInterest:addVector3D(randomVect)
                  table.insert(randomPoints, randomPoint)
                  numPoints = numPoints + 1
               end
            end
         
            -- sort the points by distance from center
            local startLoc = this:getLocation3D()
            for i, pt in pairs(randomPoints) do
               local distFromDest = pt:distanceToLocation3D(taskParameters.locationOfInterest)
               local distFromStart = pt:distanceToLocation3D(startLoc)
               local ptEntry = {point = pt, distFromDest = distFromDest, distFromStart = distFromStart}
               table.insert(points, ptEntry)
            end
            table.sort(points,
               function(a,b) return (a.distFromDest < b.distFromDest) or
                  (a.distFromDest == b.distFromDest and a.distFromStart > b.distFromStart) end)
            
            return
         end

         -- print out any messages from the algorithm
         if (message and message ~= "" and message ~= lastMessage) then
            printDebug(vrf:trUtf8("Failed to generate valid pedestrian positions: %1"):arg(message))
         end

         lastMessage = message
         return
      end
   end 
   
   -- we've got our pedestrians and our destination points. match them up.
   if not tasked and next(points) ~= nil and next(peds) ~= nil then
      numberLeftToMove = 0
      for i, pedEntry in pairs(peds) do
         needToMoveList[pedEntry.entity] = {aiming_point = points[i].point, speed=pedEntry.speed}
         numberLeftToMove = numberLeftToMove + 1
      end
      
      tasked = true
   end
   
   -- see if any (or all) tasks have finished
   if tasked then
      if next(needToMoveList) == nil and next(movementTaskIds) == nil and next(turnTaskIds) == nil then
         vrf:endTask(true)
      else
      
         if next(needToMoveList) ~= nil then
         
            local numToMoveThisTick = math.min(maxNumberToMovePerTick, numberLeftToMove)
            
            while numToMoveThisTick > 0 do
            
               local r = math.random(numberLeftToMove)            
               local params = {}
               local pedEntity = nil
               pedEntity, params = next(needToMoveList)
               while r > 1 and pedEntity ~= nil do
                  r = r - 1
                  pedEntity, params = next(needToMoveList, pedEntity)
               end
               
               if pedEntity ~= nil then
                  movementTaskIds[pedEntity:getUUID()] = vrf:sendTask(pedEntity, "move-to-location", params)
                  numberLeftToMove = numberLeftToMove - 1
                  needToMoveList[pedEntity] = nil
               end
               
               numToMoveThisTick = numToMoveThisTick - 1
            end
         end
      
         local completed = {}
         
         -- check movement tasks
         for pedUUID, taskId in pairs(movementTaskIds) do
            if vrf:isTaskComplete(taskId) then
               table.insert(completed, pedUUID)
               
               -- turn towards the location
               local ped = vrf:getSimObjectByUUID(pedUUID)
               if ped ~= nil and ped:isValid() then
               
                  local vecToFace = findVectorToFace(ped:getLocation3D(), leftOfLinePoints)
                  turnTaskIds[pedUUID] = vrf:sendTask(ped,
                     "turn-to-heading", {heading=vecToFace:getBearing()})
               end
            end
         end
         
         for i, pedUUID in pairs(completed) do
            movementTaskIds[pedUUID] = nil
         end
         
         completed = {}
         
         -- check turn tasks
         for pedUUID, taskId in pairs(turnTaskIds) do
            if vrf:isTaskComplete(taskId) then
               table.insert(completed, pedUUID)
               
               -- give pedestrian an idle task
               local ped = vrf:getSimObjectByUUID(pedUUID)
               if ped ~= nil and ped:isValid() then
                  vrf:sendTask(ped, "Perform_Task_and_Respond_to_Interruption", 
                     {idleTask=idleTask, resumeTask=resumeTask}, false)
               end
            end
         end
         
         for i, pedUUID in pairs(completed) do
            turnTaskIds[pedUUID] = nil
         end
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
