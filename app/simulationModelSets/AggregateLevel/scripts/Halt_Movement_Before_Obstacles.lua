----------------------------------------------
-- Halt Movement Before Obstacles
----------------------------------------------
-- PURPOSE
-- The purpose of this reactive task is to cause an aggregate to halt before coming into
-- contact with an obstacle or engineering object that might have adverse effects. When
-- an obstacle is encoutered, the unit will stop and report to the user. The user then has
-- a choice for how to proceed:
-- 1) Continue moving through the obstacle, suffering any effects that may result.
-- 2) Stop movement before the obstacle, awaiting new instructions.
-- 3) Continue moving through this obstacle and any future obstacles without halting.
--
-- DETAILS
-- For performance reasons, this reactive task does not determine itself when an obstacle
-- has been encountered. Instead, this is done by the aggregated-movement-actuator. By
-- default, the movement actuator will NOT halt for obstacles. However, if the Halt
-- Movement Before Obstacles reactive task is enabled, it will set the actuator's
-- "halt-movement-for-obstacles" attribute to instruct the actuator that it should halt
-- before obstacles. If the reactive task is later disabled, the "halt-movement-for-obstacles"
-- attribute will one again be disabled.
--
-- When the actuator discovers that any movement forward will result in coming into
-- contact with an obstacle, it sets its "is-halted" attribute to true and its "blocking-obstacle"
-- attribute to the name of the obstacle blocking movement. This causes this reactive
-- task to run. It then sends a user question to the GUI, so that the user may be prompted
-- for further guidance. The user is presented with the three choices outlined above.
-- 
-- If the user chooses to continue, the task executes a "set-obstacle-to-ignore" for the 
-- obstructing object. This tells the actuator that this obstacle should be ignored for now.
-- The reactive task then completes, and the actuator will continue moving through the
-- obstacle. Note that once the aggregate moves beyond the obstacle, the obstacle is
-- removed from the list of objects to ignore. This means that the next contact with the
-- obstacle will once again cause the unit to halt.
--
-- If the user chooses to halt, the reactive task remains active and the unit remains
-- halted.  The user can then retask the unit as desired. If the user again tasks the unit
-- to move through the obstacle, the reactive task will reactivate and the unit will once
-- again halt and ask for further guidance.
--
-- If the user chooses to continue moving through all obstacles, the reactive task is
-- completely disabled. As a result,  the movement actuator's 
-- "halt-movement-for-obstacles" attribute is set to false. The actuator will then no
-- longer halt when encountering obstacles until the reactive task is re-enabled.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script

-- The user question ID. Needed to check response.
questionId = -1

-- The obstacle currently blocking movement.
blockingObstacle = ""

-- The time at which the unit initially halted.
timeHalted = -1

-- In some cases it is important to let the movement actuator a chance to decide
-- anew if it should halt. In such cases, what for the time halted to update before
-- triggering this task.
waitForNewHaltTime = false

-- The distance to the object. If this changes, then either the unit or the obstacle
-- has been moved, and we need to reevaluate our need to halt.
distanceToObstacle = -1

-- Indicates the user chose to remaing halted before obstacle.
userChoseToHalt = false

local TICK_PERIOD = 2

-- Test to determine if the system is an aggregated movement system.
-- This is assumed to be the case if the system has "aggregated movement" in
-- the name. The case of the letters is ignored.
function isAggregatedMovementSystem(systemName)
   local lowerName = string.lower(systemName)
   local index = string.find(lowerName, "aggregated movement")
   return index ~= nil
end

-- The name of the movement system
local systemName = ""
local systemNames = this:getSystemNames()
for i, currentSysName in pairs(systemNames) do
   if isAggregatedMovementSystem(currentSysName) then 
      -- Store system name if valid
      local system = this:getSystem(currentSysName)
      if (system ~= nil) then
          systemName = currentSysName
	  break
      end
   end
end

local questionTitle = vrf:trUtf8("Obstacle In Path")
local questionChoices = {vrf:trUtf8("Yes"), vrf:trUtf8("No"), vrf:trUtf8("Do not halt for any obstacles")}

-- Initializes the aggregated movement system
function initializeAggregatedMovementSystem()
   if (not this:isDisaggregatedUnit()) then
      if(systemName ~= "") then   
         local system = this:getSystem(systemName)
         if (system ~= nil) then
            err = system:setAttribute("halt-movement-for-obstacles", true)
            if err then
               printWarn(vrf:trUtf8("Aggregated movement system %1: can't set halt-movement-for-obstacles."):arg(currentSysName))
            end
         else
            printWarn(vrf:trUtf8("Aggregated movement system %1: can't find system."):arg(systemName))
         end
      else
         printWarn(vrf:trUtf8("No aggregated movement system."))
      end   
   end
end

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()

   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(TICK_PERIOD)
   initializeAggregatedMovementSystem()
   
end

-- Called each tick period for this script while enabled but not in the active state.
function check()

   if(systemName ~= nil and systemName ~= "") then
      local system = this:getSystem(systemName)
      if (system ~= nil) then
         local systemHalted = false
         local err = false
         systemHalted, err = system:getAttribute("is-halted")
         if not err then 
            if systemHalted then
               latestTimeHalted, err = system:getAttribute("time-halted")
               if not err then
                  if not waitForNewHaltTime or latestTimeHalted ~= timeHalted then
                     timeHalted = latestTimeHalted
                     waitForNewHaltTime = false
                     return true
                  end
               else
                  printWarn(vrf:trUtf8("Aggregated movement system %1: can't get time-halted."):arg(systemName))
               end
            end
         else
            printWarn(vrf:trUtf8("Aggregated movement system %1: can't get is-halted."):arg(systemName))
         end
      else
         printWarn(vrf:trUtf8("Cannot find system with name %1"):arg(systemName))
      end
   end
   
   return false
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(TICK_PERIOD)
   userChoseToHalt = false
   printWarn(vrf:trUtf8("Halted movement. Obstacle in the way."))
end

-- Tells the unit to resume movement, regardless of current obstacle
function resumeMovement()   
   vrf:executeSetData("set-obstacle-to-ignore", {obstacle_to_ignore = blockingObstacle})
end

-- Tells the unit to resume movement, regardless of any obstacles
function resumeMovementThroughAllObstacles(skipTaskDisable)
   if (systemName ~= nil and systemName ~= "") then
      local system = this:getSystem(systemName)
      if (system ~= nil) then
         local err = false
         err = system:setAttribute("halt-movement-for-obstacles", false)
         if err then
            printWarn(vrf:trUtf8("Aggregated movement system %1: can't set halt-movement-for-obstacles."):arg(systemName))
         else
            printInfo(vrf:trUtf8("Resuming movement."))
         end
         
         if not skipTaskDisable then
            -- Disable reactive task
            vrf:executeSetData("set-reactive-task-disabled", {script_id ="Halt_Movement_Before_Obstacles", cancel_now=true})
         end
      end
   end
end

-- Called each tick while this task is active.
function tick()

   -- Check if the obstruction has been removed. 
   if not check() then
      -- Obstruction is gone
      if questionId >= 0 then
         vrf:cancelUserQuestion(questionId)
         questionId = -1
      end
      vrf:endTask(true)
   else
   
      -- See if we are already being blocked
      if not userChoseToHalt then
      
         -- Have we asked a question yet?
         if questionId < 0 then      
         
            local system = nil
            if (systemName ~= nil and systemName ~= "") then
               system = this:getSystem(systemName)
            end
            
            if (system == nil) then
               printWarn(vrf:trUtf8("Cannot find system with name "):arg(systemName))
               vrf:endTask(true)
               return
            end
            
            -- Ask user what they want to do. Until they respond, assume they want
            -- us to halt where we are.
            local err = false
            blockingObstacle, err = system:getAttribute("blocking-obstacle")
            
            if err then
               printWarn(vrf:trUtf8("Aggregated movement system: can't get blocking-obstacle."))
               vrf:endTask(true)
               return
            end
            
            local obstacleObj = vrf:getSimObjectByName(blockingObstacle)
            
            if not obstacleObj:isValid() then
               printWarn(vrf:trUtf8("Aggregated movement system: can't get blocking-obstacle object: %1."):arg(blockingObstacle))
               vrf:endTask(true)
               return
            end
            
            distanceToObstacle = this:getLocation3D():distanceToLocation3D(obstacleObj:getLocation3D())
            
            questionId = vrf:askUserQuestion(questionTitle,
               vrf:trUtf8("%1 is obstructing the path. Continue anyway?"):arg(obstacleObj:getName()),
               questionChoices, 1)
               
         else
            
            -- Check for question response
            local option = vrf:statusOfUserQuestion(questionId)
            
            if option == 0 then
               -- User chose to keep moving
               resumeMovement()
               questionId = -1
               vrf:endTask(true)
            elseif option == 1 then
               -- User chose to remain halted
               questionId = -1
               userChoseToHalt = true
               vrf:setTickPeriod(30) -- Don't need to tick so much
            elseif option == 2 then
               -- User chose to always continue through obstacles
               questionId = -1
               resumeMovementThroughAllObstacles(false)
            elseif option == -1 then
               -- User has not yet responded
               -- Has the obstacle been removed?               
               local obstacleObj = vrf:getSimObjectByName(blockingObstacle)               
               if not obstacleObj:isValid() then
                  -- Before triggering again, let the movement actuator determine if we should halt.
                  waitForNewHaltTime = true
                  printWarn(vrf:trUtf8("Aggregated movement system: obstacle %1 has ben removed."):arg(blockingObstacle))
                  vrf:endTask(true)
               else
                  local newDistanceToObstacle = this:getLocation3D():distanceToLocation3D(obstacleObj:getLocation3D())
                  if newDistanceToObstacle > distanceToObstacle + 2 then
                     -- Before triggering again, let the movement actuator determine if we should halt.
                     waitForNewHaltTime = true
                     printWarn(vrf:trUtf8("Aggregated movement system: proximity to obstacle %1 has changed."):arg(blockingObstacle))
                     vrf:endTask(true)
                  end
               end
            end
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
function loadState()
   initializeAggregatedMovementSystem()
end


-- Called when this task is ending, for any reason.
function shutdown()
   -- Cancel any current questions.
   if questionId >= 0 then
      vrf:cancelUserQuestion(questionId)
      questionId = -1
      distanceToObstacle = -1
      blockingObstacle = ""
   end
end

-- Called when a reactive task is disabled (check will no longer called)
function disable()
   shutdown()
   
   -- If task is disabled, user is explicitly indicating they want to move over obstacles. 
   resumeMovementThroughAllObstacles(true)
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
