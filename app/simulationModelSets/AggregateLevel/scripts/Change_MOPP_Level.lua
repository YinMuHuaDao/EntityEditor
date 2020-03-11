-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
currentMoppLevel = 0
timeStarted = 0
local transitionTimes = this:getParameterProperty("MOPP-Level-Transition-Times")

-- Task Parameters Available in Script
--  taskParameters.MoppLevel Type: Integer


-- Called when the task first starts. Never called again.
function init()
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(2)
      
   if this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Change MOPP Level: Cannot change MOPP level while embarked."))
      vrf:endTask(false)
   else
      local moppTransition = this:getStateProperty("MOPP-Transition")
      if(moppTransition.IsTransitioning and 
         moppTransition.NewLevel == taskParameters.MoppLevel) then
      
         currentMoppLevel = this:getStateProperty("MOPP-Level")
         
         -- Keep current transition info if transitioning to same level we were already
         -- transitioning to. Just update the time started to record the fact that this
         -- is a new task, even if its doing the same thing.
         timeStarted = vrf:getSimulationTime()
         moppTransition.TimeStarted = timeStarted
         
         this:setStateProperty("MOPP-Transition", moppTransition)
         
      else
         
         -- Start a new transition
         
         -- Determine transition time
         currentMoppLevel = this:getStateProperty("MOPP-Level")
         local transTime = math.abs(transitionTimes["Level-"..currentMoppLevel] - 
            transitionTimes["Level-"..taskParameters.MoppLevel])
            
         timeStarted = vrf:getSimulationTime()
         
         moppTransition.IsTransitioning = true
         moppTransition.NewLevel = taskParameters.MoppLevel
         moppTransition.TimeStarted = timeStarted
         moppTransition.TimeFinished = moppTransition.TimeStarted + transTime
         
         this:setStateProperty("MOPP-Transition", moppTransition)
      end
   end
   
end

-- Called each tick while this task is active.
function tick()

   local moppTransition = this:getStateProperty("MOPP-Transition")
   local updatedMoppLevel = this:getStateProperty("MOPP-Level")
   
   if(currentMoppLevel ~= updatedMoppLevel) then
   
      -- Someone has manually set the MOPP to a new value. Cancel our transition.
      moppTransition.IsTransitioning = false
      moppTransition.NewLevel = 0
      moppTransition.TimeStarted = 0
      moppTransition.TimeFinished = 0
      this:setStateProperty("MOPP-Transition", moppTransition)
      
      vrf:endTask(true)
   else      

      local currentTime = vrf:getSimulationTime()      
      if(moppTransition.TimeFinished <= currentTime) then
         
         -- Transition finished
         this:setStateProperty("MOPP-Level", moppTransition.NewLevel)
         
         moppTransition.IsTransitioning = false
         moppTransition.NewLevel = 0
         moppTransition.TimeStarted = 0
         moppTransition.TimeFinished = 0
         this:setStateProperty("MOPP-Transition", moppTransition)
         
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

   local moppTransition = this:getStateProperty("MOPP-Transition")
   
   -- Only clear out the transition info if a new transition isn't already
   -- in place. This can happen when one transition task is replaced by another.
   if(moppTransition.TimeStarted == timeStarted) then
      moppTransition.IsTransitioning = false
      moppTransition.NewLevel = 0
      moppTransition.TimeStarted = 0
      moppTransition.TimeFinished = 0
      this:setStateProperty("MOPP-Transition", moppTransition)
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
