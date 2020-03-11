-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

subtaskId = -1


local maxNumberOfPedestrians = 300

-- Task Parameters Available in Script


-- Should run immediately, paused or not
vrf:setTickWhilePaused(true)

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()

   -- Can be configured not to do initial creation
   local doCreation, errorCode = vrf:getScriptAttribute("Perform-Initial-Creation")
   if (errorCode) then
      doCreation = true
   end

   -- If this unit already has subordinates (as will happen with an Aggregate-As),
   -- don't create anymore
   local subordinates = this:getSubordinates(true)
   
   if next(subordinates) == nil and doCreation then
      -- Immediately start creating entities
      return true
   end
   
   -- Don't even try to react
   vrf:executeSetData("set-reactive-task-disabled", 
      {script_id="Create_Initial_Pedestrians"})
   return false
   
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickWhilePaused(true)
   vrf:setTickPeriod(0.5)
end

-- Calculates the area (size) of this area (object).
function getArea()

   -- If this is an object with multiple points, we will create the pedestrians within
   -- the area defined by those points. Otherwise, we will create them within the
   -- configured radius of this object.
   local points = this:getLocations3D()
   
   if #points < 2 then
      -- Use the configured radius.
      local radius, errorCode = vrf:getScriptAttribute("Creation-Radius")
      
      if (errorCode) then
         radius = 0
      end
      
      return math.pi * radius * radius
   end
   
   -- First of all, we're going to assume a convex polygon here. If we're working
   -- with a concave polygon, well, our calculation will be wrong and we may not
   -- produce the correct number of people, but I think that's ok.
   -- To calculate the area, we will divide our polygon into triangles and use
   -- Heron's formula to calculate the size of each one.
   
   -- First, we're only going to worry about 2D space here, so drop the altitude.
   for idx, point in pairs(points) do
      points[idx]:setAlt(0)
   end
   
   local pt1 = points[1]
   local i = 2
   local totalArea = 0
   while i+1 <= #points do
      local pt2 = points[i]
      local pt3 = points[i+1]
      local sideA = pt1:distanceToLocation3D(pt2)
      local sideB = pt2:distanceToLocation3D(pt3)
      local sideC = pt3:distanceToLocation3D(pt1)
      local halfPerim = (sideA+sideB+sideC)/2
      local areaSq = halfPerim *
         (halfPerim - sideA) *
         (halfPerim - sideB) *
         (halfPerim - sideC)
      totalArea = totalArea + math.sqrt(areaSq)
      i = i+1
   end
   
   return totalArea
end

function getDesiredNumber(area)

   -- Get the configured density factor, if present
   local densityFactor, errorCode = vrf:getScriptAttribute("Density-Factor")
   
   if (errorCode) then
      densityFactor = 1
   end
   
   return math.min(math.floor((math.sqrt(area)+0.5) * densityFactor), maxNumberOfPedestrians)
end

-- Called each tick while this task is active.
function tick()

   -- Just want to run this task one time
   vrf:executeSetData("set-reactive-task-disabled", 
      {script_id="Create_Initial_Pedestrians"})
      
   local area = getArea()
   local numPeds = getDesiredNumber(area)
   
   if numPeds == maxNumberOfPedestrians then
      printVerbose(vrf:trUtf8("Creating maximum number of pedestrians: %1"):arg(maxNumberOfPedestrians))
   end

   if subtaskId < 0 then   
      subtaskId = vrf:startSubtask("Create_Pedestrians",
         {number=numPeds,
          placement=3, -- prefer-pedestrian-paths
          isStrict=true,
          restrictToArea=true})
          
      if subtaskId < 0 then
         printWarn(vrf:trUtf8("Failed to create pedestrians"))
         vrf:endTask(true)
      end
   elseif vrf:isSubtaskComplete(subtaskId) then
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



-- Called when a reactive task is disabled (check will no longer called)
-- It is typically not necessary to add code to this function.
function disable()
end
