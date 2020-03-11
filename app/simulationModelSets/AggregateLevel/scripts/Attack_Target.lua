-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.target Type: SimObject
--  taskParameters.changePosture Type: Bool (on/off) - Change posture before moving to attack
--  taskParameters.newPosture Type: Integer (0 - choice limit)


local footprintSize = this:getParameterProperty("Base-Physical-Footprint")
local subtaskId = -1
local state = "init"
local targetFootprintSize = 10

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   state = "init"
   
   if (not taskParameters.target:isValid()) then
      printInfo("Target not found.")
      vrf:endTask(false)
      return
   end
   
   targetFootprintSize = taskParameters.target:getParameterProperty("Base-Physical-Footprint")
   
   vrf:executeSetData("set-state-properties", {state_properties={ Preferred_Targets=taskParameters.target } })
end

-- Returns true if the unit is currently engaging the desired target.
function engagedWithTarget()
   local currentAttacks = this:getStateProperty("Attacks")
   for attackIndex, attack in pairs(currentAttacks) do
      if (attack.Target == taskParameters.target:getUUID()) then
         return true
      end
   end
   return false
end

function startTurnToTarget()
   local currentLoc = this:getLocation3D()
   local bearingToTarget = currentLoc:vectorToLoc3D(taskParameters.target:getLocation3D()):getBearing()
   subtaskId = vrf:startSubtask("turn-to-heading", {heading = bearingToTarget})
end

function startChangePosture()
   -- Change Posture has hasty-attack as 2, deleberate attack as 3.  This task has hasty as 0 and deliberate as 1.
   subtaskId = vrf:startSubtask("Change_Posture", { Posture=taskParameters.newPosture + 2})
end

function startMoving()
   subtaskId = vrf:startSubtask("move-to", {destination = taskParameters.target})
end

function withinMinTargetDistance()
   if (this:getLocation3D():distanceToLocation3D(taskParameters.target:getLocation3D()) <= footprintSize + targetFootprintSize) then
      return true
   else
      return false
   end
end

-- Called each tick while this task is active.
function tick()

   if (not taskParameters.target:isValid()) then
      printInfo("Target not found.")
      vrf:endTask(false)
   end
   
   -- Check to see if the target has been destroyed or is in Rout.  If so, task is complete.
   if (taskParameters.target:isDestroyed() or taskParameters.target:getStateProperty("Posture") == "Rout") then
      vrf:endTask(true)
   end
   
   
   if (state == "init") then
      -- First turn toward the target
      startTurnToTarget()
      state = "turning"
   end
   
   if (subtaskId >= 0) then
      if (vrf:isSubtaskComplete(subtaskId)) then
         if (state == "turning") then
            if (taskParameters.changePosture) then
               startChangePosture()
               state = "posture-transition"
            else
               startMoving()
               state = "moving"
            end
         elseif (state == "posture-transition") then
            startMoving()
            state = "moving"
         end
      end
   end
   
   -- If moving, and 
   if (state == "moving") then
      if (withinMinTargetDistance() or engagedWithTarget()) then
         vrf:stopSubtask(subtaskId)
         subtaskId = -1
         state = "engaging"
      end
   elseif (state == "engaging") then
      if (not withinMinTargetDistance() and not engagedWithTarget()) then
         startMoving()
         state = "moving"
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
