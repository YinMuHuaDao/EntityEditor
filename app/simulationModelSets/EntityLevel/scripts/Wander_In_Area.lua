-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
job = nil
points = {}
pedestrians = {}

-- Task Parameters Available in Script
--  taskParameters.area Type: SimObject - The area in which the crowd should wander


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
      
   pedestrians = this:getSubordinates(true)
end

-- Called each tick while this task is active.
function tick()
   
   if next(pedestrians) == nil then
      printWarn(vrf:trUtf8("No pedestrians in crowd"))
      vrf:endTask(false)
      return
   end

   if next(points) == nil then

      if job == nil then
   
         -- start a new job to generate random points
         pointIdx = 1
      
         job = vrf:generateRandomPoints({
            number_of_points=#pedestrians,
            boundary=taskParameters.area, 
            min_distance_between_points=1.5,
            placement_restriction="prefer-pedestrian-paths",
            is_strict=true})
         
         if (not job) then
            printWarn(vrf:trUtf8("Could not start async job to generate points"))
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
            elseif numPoints < #pedestrians then
               printInfo(vrf:trUtf8("Could not generate valid positions for requested number of pedestrians: %1 / %2"):
                  arg(numPoints):arg(#pedestrians))
                  
               -- just have them move into the area
               while numPoints < #pedestrians do
                  table.insert(randomPoints, taskParameters.area:getLocation3D())
                  numPoints = numPoints + 1
               end
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
      
      -- move our pedestrians into the area using the generated points and then have them wander
      for i, ped in pairs(pedestrians) do
         if ped:isValid() then
         
            local destPoint = points[math.random(#pedestrians)]
            vrf:sendTask(ped, "Move_Then_Wander",
               {initialDestination=destPoint,
                isIndefinite=0,
                movementMode=1,
                area=taskParameters.area,
                destinationRestriction=3}, false)
         end
      end
      
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
