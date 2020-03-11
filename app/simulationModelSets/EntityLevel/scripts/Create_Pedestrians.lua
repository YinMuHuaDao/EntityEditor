-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

local DEBUG_DETAIL = false

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

job = nil
pointIdx = 1
points = {}
pedestriansCreated = {}
allPedestrians = {}
selectionGroupCreated = false

local entityName = "Pedest"
local crowdUnitType = "11:1:0:0:34:0:4"
local westernMaleCivType = "3:1:225:3:0:1:0"
local westernFemaleCivType = "3:1:225:3:1:1:0"
local mideastMaleCivType = "3:1:1:3:1:0:3"
local mideastFemaleCivType = "3:1:1:3:1:0:2"

local categoriesOfTypesToCreate = {
   ["western"] = { westernMaleCivType, westernFemaleCivType },
   ["mideast"] = { mideastMaleCivType, mideastFemaleCivType } }

local speedTable = {
   [westernMaleCivType] = {minSpeed=0.66, maxSpeed=1.5},
   [westernFemaleCivType] = {minSpeed=0.66, maxSpeed=1.10},
   [mideastMaleCivType] = {minSpeed=0.66, maxSpeed=1.5},
   [mideastFemaleCivType] = {minSpeed=0.66, maxSpeed=1.10} }
local defaultSpeeds = {minSpeed=0.66, maxSpeed=1.10}

local entitiesPerTick = 10

local areaNotDrawn = true

-- Task Parameters Available in Script
--  taskParameters.number Type: Integer - The number of pedestrians to create
--  taskParameters.placement Type: Integer (0 - choice limit) - Valid placement locations
--  taskParameters.isStrict Type:Bool - Placement restriction is strictly enforced
--  taskParameters.restrictToArea Type: Bool (on/off) - Restrict default movement within area


vrf:setTickWhilePaused(true)

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   pedestriansCreated = {}
   allPedestrians = {}
   selectionGroupCreated = false
   vrf:setTickPeriod(0.5)
   areaNotDrawn = true
end

function typesToCreate()
   
   -- Use the configured category of types.
   local category, errorCode = vrf:getScriptAttribute("Entity-Type-Category")
   if (errorCode) then
      category = "western"
   end
   
   return categoriesOfTypesToCreate[category]
   
end

-- Converts taskParameters.placement to a generateRandomPoints friendly value.
function placementRestriction()
   
   if taskParameters.placement == 0 then
      return "free"
   elseif taskParameters.placement == 1 then
      return "prefer-roads"
   elseif taskParameters.placement == 2 then
      return "avoid-roads"
   elseif taskParameters.placement == 3 then
      return "prefer-pedestrian-paths"
   end
   
   return "free"
end

-- The radius in which to create pedestrians and have them wander. Only used if
-- this is not an areal object. For areal object, pedestrians will be created
-- within the area itself.
function radius()

   local points = this:getLocations3D()
   
   if #points > 2 then
      -- This is an area, radius is unused
      return 0
   end
   
   -- Use the configured radius.
   local radius, errorCode = vrf:getScriptAttribute("Creation-Radius")
   if (errorCode) then
      return 0
   end
   
   return radius

end

-- The center point of the radius return by radius().
function accessPoint()

   local points = this:getLocations3D()
   
   if #points > 2 then
      -- This is an area, access point is unused
      return Location3D(0,0,0)
   end
   
   return this:getLocation3D()

end

-- The area in which to create pedestrians and have them wander. Only used if
-- this is an areal object. For non-areal objects, pedestrians will be created
-- within the value returned by radius().
function boundingArea()

   local points = this:getLocations3D()
   
   if #points > 2 then
      -- This is an area, radius is unused
      return this
   end
   
   return nil

end

-- Called each tick while this task is active.
function tick()

   local crowdUnit = nil
   if not this:isAggregate() then
      -- Find/create the Civilian Crowd unit which all pedestrians will be placed in
      local crowdUnitUUID = this:getStateProperty("Owned-Crowd")
      if crowdUnitUUID == nil or crowdUnitUUID == {} then
         crowdUnit = vrf:createEntity({
            entity_type=crowdUnitType,
            location=this:getLocation3D(),
            object_name_prefix="Crowd",
            force=this:getForceType()})
      
         this:setStateProperty("Owned-Crowd", crowdUnit:getUUID(), true) 
      else
         crowdUnit = vrf:getSimObjectByUUID(crowdUnitUUID)
      end
   end
   
   -- Create task visualization for the area where pedestrians are created
   if areaNotDrawn then
      local taskVisArea = boundingArea()
      local taskVisPoints = {}
      if taskVisArea == nil then
         -- We're using a radius from the center point, but this actually describes
         -- a square to the point generation algorithm, with the radius being the
         -- half width.
         local centerPoint = accessPoint()
         local taskVisHalfWidth = radius()
         local northVec = Vector3D(0,0,0)
         northVec:setBearingInclRange(0, 0, taskVisHalfWidth)
         local eastVec = Vector3D(0,0,0)
         eastVec:setBearingInclRange(math.pi * 0.5, 0, taskVisHalfWidth)
         local southVec = Vector3D(0,0,0)
         southVec:setBearingInclRange(math.pi, 0, taskVisHalfWidth)
         local westVec = Vector3D(0,0,0)
         westVec:setBearingInclRange(math.pi * 1.5, 0, taskVisHalfWidth)
            
         table.insert(taskVisPoints, centerPoint:addVector3D(northVec):addVector3D(eastVec))
         table.insert(taskVisPoints, centerPoint:addVector3D(southVec):addVector3D(eastVec))
         table.insert(taskVisPoints, centerPoint:addVector3D(southVec):addVector3D(westVec))
         table.insert(taskVisPoints, centerPoint:addVector3D(northVec):addVector3D(westVec))
         table.insert(taskVisPoints, taskVisPoints[1])
      else
         -- Use the geometry of the boudning area
         taskVisPoints = taskVisArea:getLocations3D()
         table.insert(taskVisPoints, taskVisPoints[1])
      end
      
      if next(taskVisPoints) then
         vrf:updateTaskVisualization("CreationArea", "line", 
            {color={0,0,255,200}, locations=taskVisPoints, offset=Vector3D(0, 0, -0.5)})
      end
      areaNotDrawn = false
   end

   if next(points) == nil then

      if job == nil then
   
         -- start a new job to generate random points
         pointIdx = 1
      
         job = vrf:generateRandomPoints({
            number_of_points=taskParameters.number,
            boundary=boundingArea(), 
            access_point=accessPoint(),
            max_distance_from_access_point=radius(),
            min_distance_between_points=1.5,
            placement_restriction=placementRestriction(),
            is_strict=taskParameters.isStrict,
            ground_clamp=true})
         
         if (not job) then
            printWarn(vrf:trUtf8("Could not start async job to generate points"))
            vrf:endTask(false)
            return
         end
      
      else
      
         if DEBUG_DETAIL then
            local dbgPts = job:getDebugObject()
            for i, pt in pairs (dbgPts) do
               vrf:updateTaskVisualization("dbgPt" .. i, "point",
                  {color={255,0,0,200}, size=1, location=pt, offset=Vector3D(0,0,-1)})
            end
         end
      
         -- see if random points have been generated
         local randomPoints,index,message = job:getObject()
         if (index == 1) then
         
            local numPoints = #randomPoints
               
            if (numPoints == 0) then 
               printWarn(vrf:trUtf8("Failed to generate any valid pedestrian positions."))
               vrf:endTask(false)
               return
            elseif numPoints < taskParameters.number then
               printInfo(vrf:trUtf8("Could not generate valid positions for requested number of pedestrians: %1 / %2"):
                  arg(numPoints):arg(taskParameters.number))
            end
         
            points = randomPoints
            return
         end

         -- print out any messages from the algorithm
         if (message and message ~= "" and message ~= lastMessage) then
            printDebug(vrf:trUtf8("Failed to generate valid pedestrian positions: %1"):arg(message))
         end

         lastMessage = message
      end
   else
   
      -- All points have been generated. Now just need to create and task our pedestrians.         
      local numPoints = #points
            
      local bounds = ""
      local movement = 0
      if (taskParameters.restrictToArea) then
         bounds = boundingArea()
         movement = 1
      end
         
      local numCreatedThisTick = 0
      while pointIdx <= numPoints and numCreatedThisTick < entitiesPerTick do 
      
         local point = points[pointIdx]
      
         local types = typesToCreate()
         if types == nil or #types == 0 then
            printWarn(vrf:trUtf8("No configured entity types to create"))
            vrf:endTask(false)
            return            
         end
         
         local typeIdx = (pointIdx % #types) + 1
         local entityType = types[typeIdx]
         
         local entityHeading = math.rad(math.random(360))
         
         local superior = this
         
         if not this:isAggregate() and crowdUnit ~= nil and crowdUnit:isValid() then
            superior = crowdUnit
         end
         
         -- Create the new pedestrian
         local pedestrian = vrf:createEntity({
            entity_type=entityType,
            location=point,
            object_name_prefix=entityName,
            force=this:getForceType(),
            heading=entityHeading,
            superior=superior})
            
         -- Task the pedestrian to walk around at some speed
         if pedestrian:isValid() then
         
            -- Randomize the speed based on entity type
            local orderedSpeed = 0
            for matchingType, speeds in pairs(speedTable) do
               if vrf:entityTypeMatches(matchingType, entityType) then
                  orderedSpeed = (math.random() * (speeds.maxSpeed - speeds.minSpeed)) +
                     speeds.minSpeed
               end
            end
            
            -- No matching entity type, use default speed range
            if orderedSpeed <= 0 then
               orderedSpeed = (math.random() * (defaultSpeeds.maxSpeed - defaultSpeeds.minSpeed)) +
                  defaultSpeeds.minSpeed
            end
            
            vrf:sendSetData(pedestrian, "set-speed",
               {speed=orderedSpeed})
                      
            -- When many entities begin wandering at once, it can take a while
            -- to both find valid wander points and plan paths. Instead, since
            -- we already have a list of valid wander points (our entity locations)
            -- we have them move to one of these points and then wander.
            local destPoint = points[math.random(numPoints)]
            vrf:sendTask(pedestrian, "Move_Then_Wander",
               {initialDestination=destPoint,
                isIndefinite=0,
                movementMode=movement,
                area=bounds,
                destinationRestriction=taskParameters.placement},
               false)
               
            table.insert(pedestriansCreated, pedestrian:getUUID())
            table.insert(allPedestrians, pedestrian)
         end           
      
         pointIdx = pointIdx + 1
         numCreatedThisTick = numCreatedThisTick + 1
      end
      
      -- save a record of all pedestrians created by this task
      if next(pedestriansCreated) ~= nil then
         local ownedPeds = this:getStateProperty("Owned-Pedestrians")
         if ownedPeds == nil then ownedPeds = {} end
         
         for i, ped in pairs(ownedPeds) do
            table.insert(pedestriansCreated, ped)
         end
         
         this:setStateProperty("Owned-Pedestrians", pedestriansCreated, true)
         pedestriansCreated = {}
      end

      if pointIdx >= numPoints then
      
         if not selectionGroupCreated then
            vrf:createSelectionGroup(this:getName() .. " Group", allPedestrians)
            selectionGroupCreated = true
         end
	 
         vrf:endTask(true)
      end
      return
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
   if (job ~= nil) then
      job:cancel()
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
