-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
vrf:require("vrfutil")

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
checkpointState.taskId = -1
checkpointState.job = nil

checkpointState.startTime = 0
checkpointState.wanderRadius = 100.0
vrf:setCheckpointMode(CheckpointStateOnly)

local lastTenPoints = {}
local currentPoint = nil
local DRAW_DEBUG = false

-- Task Parameters Available in Script
--  taskParameters.isIndefinite Type: Integer (0 - choice limit) - Choose whether the entity will wander indefinitely or for a fixed amount of time.
--  taskParameters.wanderTime Type: Integer Unit: seconds
--  taskParameters.movementMode Type: Integer (0 - choice limit)
--  taskParameters.area Type: SimObject
--  taskParameters.destinationRestriction Type: Integer (0 - choice limit) - Wander will choose destinations fitting this restriction

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   checkpointState.startTime = vrf:getSimulationTime()
end

-- Converts taskParameters.destinationRestriction to a generateRandomPoints friendly value.
function destinationRestriction()
   
   if taskParameters.destinationRestriction == 0 then
      return "free"
   elseif taskParameters.destinationRestriction == 1 then
      return "prefer-roads"
   elseif taskParameters.destinationRestriction == 2 then
      return "avoid-roads"
   elseif taskParameters.destinationRestriction == 3 then
      return "prefer-pedestrian-paths"
   end
   
   return "free"
end

-- Called each tick while this task is active.
function tick()
   if (taskParameters.isIndefinite == 1) then
      local timeDiff = vrf:getSimulationTime() - checkpointState.startTime
      if (timeDiff > taskParameters.wanderTime) then
         vrf:endTask(true)
      end
   end
   
if DRAW_DEBUG then
   for i, pt in pairs(lastTenPoints) do
      vrf:updateTaskVisualization("Pt" .. i, "point", 
         {color=pt.color, size=3+i, location=pt.point,offset=Vector3D(0,0,-0.5)})
   end
   
   if currentPoint ~= nil then
      vrf:updateTaskVisualization("CPt", "point", 
         {color={255,255,0, 200}, size=3, location=currentPoint,offset=Vector3D(0,0,-0.5)})
   end
end

   if (checkpointState.job) then
      -- check job
      local points,index,message = checkpointState.job:getObject()
      if (index == 1) then
      
         if (#points > 0) then 
	 
            local randIdx = math.random(#points)
	     
            if currentPoint ~= nil then
               if currentPoint:distanceToLocation3D(this:getLocation3D()) > 1 then
                  table.insert(lastTenPoints, {point=currentPoint, color={255,0,0,200}})
               else
                  table.insert(lastTenPoints, {point=currentPoint, color={0,0,255,200}})
               end
               
               if #lastTenPoints > 10 then
                  table.remove(lastTenPoints, 1)
               end
            end
		
            checkpointState.taskId = vrf:startSubtask("move-to-location", {aiming_point=points[randIdx]})
	    
            currentPoint = points[randIdx]
	    
         else
            printWarn("generate points job failed: " .. message)
            vrf:endTask(false)
         end
         
         checkpointState.job = nil
         return
      end

      -- print out any messages from the algorithm
      if (message and message ~= "" and message ~= lastMessage) then
         printDebug("generate points job: " .. message)
      end

      lastMessage = message

      if (index == 0) then    
         return
      end
   end
   
   if (checkpointState.taskId == -1) then
   
      local randomPointGenParams = {
         min_distance_between_points=math.min(10, checkpointState.wanderRadius/2),
         placement_restriction=destinationRestriction(),
	 number_of_points=1,
	 min_distance_from_access_point=2}
         
      if this:isEmbarked() then
         randomPointGenParams.parent_object = this:getEmbarkedOn()
      end
      
      if (taskParameters.movementMode == 1 and taskParameters.area:isValid()) then
         randomPointGenParams.boundary = taskParameters.area
         
         local loc = this:getLocation3D()
         if (taskParameters.area:isPointInside(loc)) then
            -- We're in the area, use our own location as access point
            randomPointGenParams.access_point=loc
            randomPointGenParams.max_distance_from_access_point=checkpointState.wanderRadius
         else      
            -- Make sure our wander radius is big enough to get us to the area
            local areaVertices =  taskParameters.area:getLocations3D()
            local distanceToArea = 99999999999
            for i, vert in pairs(areaVertices) do
               local d = loc:distanceToLocation3D(vert)
               if (d < distanceToArea) then
                  distanceToArea = d
               end
            end
            
            if (distanceToArea < checkpointState.wanderRadius) then
               -- Area is within wander radius, use our own location as access point
               randomPointGenParams.access_point=loc
               randomPointGenParams.max_distance_from_access_point=checkpointState.wanderRadius
            end
         end
      else
         randomPointGenParams.access_point=this:getLocation3D()
         randomPointGenParams.max_distance_from_access_point=checkpointState.wanderRadius
      end
      
      checkpointState.job = vrf:generateRandomPoints(randomPointGenParams)     
         
      if (not checkpointState.job) then
         printWarn(vrf:trUtf8("Could not start async job"))
         vrf:endTask(false)
         return
      end
      
   elseif (vrf:isSubtaskComplete(checkpointState.taskId)) then
      checkpointState.taskId = -1
   end
end


-- Called when this task is being suspended, likely by a reaction activating.
function suspend()
-- By default, halt all subtasks and other entity tasks started by this task when suspending.
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
   
   checkpointState.job = nil
   checkpointState.taskId = -1
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
