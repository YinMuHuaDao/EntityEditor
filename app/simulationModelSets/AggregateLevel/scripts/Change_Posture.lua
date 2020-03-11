-- Change_Posture-- Implements the change posture task.

-- The maximum modifier due to EW attack.
-- This number scales posture change time, so if a unit is
-- completely dependent on comms for operations, and comms
-- are 100% degraded by an EW attack, then posture change
-- times will be MAX_EW_MODIFIER x normal.
MAX_EW_MODIFIER = 2.0

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

mySubordinateTasks = {}

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
currentPosture = ""
timeStarted = 0
local transitionTimes = this:getParameterProperty("Posture-Transition-Times")
local baseEWVulnerability = this:getParameterProperty("Base-Comms-Dependence")

-- Maps the enumeration passed in via taskParameters.Posture to the posture name
local postureTable = { [0] = "Travel", [1] = "Reconnaissance",
   [2] = "Hasty-Attack", [3] = "Deliberate-Attack", 
   [4] = "Hasty-Defense", [5] = "Deliberate-Defense" }

-- Task Parameters Available in Script
--  taskParameters.Posture Type: Integer (0 - choice limit) - The index of the new posture for the unit
--  taskParameters.PostureName Type: String - The name of the new posture for the unit
-- NOTE: Only one of Posture or PostureName should be used. PostureName will be used if available.

-- Calculate the EW effect modifier based on the base comms EW 
-- dependence and the current Comms degradation percent.
-- The modifier ranges between 1.0 and MAX_EW_MODIFIER.
function calculateEWModifier ()
   local modifier = 1.0
   local degradationPercent = this:getStateProperty("EW-Comms-Degradation-Percent")
   if degradationPercent ~= nil and
      baseEWVulnerability ~= nil then
      
      modifier = 1.0 + (MAX_EW_MODIFIER - 1.0) * 
         degradationPercent/ 100.0 * baseEWVulnerability
   end 
   return modifier
end

-- Returns true if the posture name is valid
function validPostureName(postureName)
   
   if postureName == nil then
      return false
   end
   
   for index, validName in pairs(postureTable) do
      if postureName == validName then
         return true
      end
   end
   
   return false
end


-- Called when the task first starts. Never called again.
function init()
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(2)
   
   local newPostureName = taskParameters.PostureName
   if not validPostureName(newPostureName) then
      newPostureName = postureTable[taskParameters.Posture]
   end
   
   if (this:isDisaggregatedUnit()) then
      local currentSubordinates = this:getSubordinates(true)
   
      for subIndex, subordinate in pairs(currentSubordinates) do      
         mySubordinateTasks[subordinate:getUUID()] = vrf:sendTask(subordinate, "Change_Posture", {PostureName = newPostureName})
      end
   else
	   -- Keep current transition info if transitioning to same posture we were already
	   -- transitioning to.
	   currentPosture = this:getStateProperty("Posture")	   
	   local postureTransition = this:getStateProperty("Posture-Transition")
	   
	   if(currentPosture == "Rout") then
         vrf:endTask(true)
         printWarn("Cannot change postures. Unit is in a rout.")
       elseif(postureTransition.IsTransitioning and 
	      postureTransition.NewPosture == newPostureName) then
	   
	      
	      -- Keep current transition info if transitioning to same posture we were already
	      -- transitioning to. Just update the time started to record the fact that this
	      -- is a new task, even if its doing the same thing.
	      timeStarted = vrf:getSimulationTime()
	      postureTransition.TimeStarted = timeStarted
	      
	      this:setStateProperty("Posture-Transition", postureTransition)
	      
	   else
	      
	      -- Start a new transition
	   
	      local currentTime = vrf:getSimulationTime()
	      
	      -- If a transition is already in progress, we can retain some of the time spent
	      -- transitioning. The rest is lost.
	      local timeCredit = 0
	      if(postureTransition.IsTransitioning) then            
             -- Transitioning to a new posture. Keep half of our current transition time.
             timeCredit = (currentTime - postureTransition.TimeStarted) / 2
	      end
	      
	      -- Determine transition time
	      local requiredTime = transitionTimes[currentPosture][newPostureName] *
             calculateEWModifier ()
	      local transTime = math.max(0, requiredTime - timeCredit)
	      
	      timeStarted = currentTime

	      postureTransition.IsTransitioning = true
	      postureTransition.NewPosture = newPostureName
	      postureTransition.TimeStarted = timeStarted
	      postureTransition.TimeFinished = postureTransition.TimeStarted + transTime
	      
	      this:setStateProperty("Posture-Transition", postureTransition)
	   end
   end   
end

-- Checks the status of the subordinates to see if the still exist and are still in task mode.  If not then the subordinates are removed from
-- the mySubordinatesList.  Once the list is empty the the task is complete
function allSubordinatesComplete()
   local currentSubordinates = this:getSubordinates(true)
   local currentTable = mySubordinateTasks
   local complete = true
   
   mySubordinateTasks = {}
   for subIndex, subordinate in pairs(currentSubordinates) do
      local taskId = currentTable[subordinate:getUUID()]
      if (taskId ~= nil) then
        if (not vrf:isTaskComplete(taskId)) then
           mySubordinateTasks[subordinate:getUUID()] = taskId
           complete = false
        end
      end      
   end
   
   return complete
end

-- Called each tick while this task is active.
function tick()
   if (this:isDisaggregatedUnit()) then
      if (allSubordinatesComplete()) then
         vrf:endTask(true)
      end
   else
      local postureTransition = this:getStateProperty("Posture-Transition")
      local updatedPosture = this:getStateProperty("Posture")
   
      if(currentPosture ~= updatedPosture) then
   
      -- Someone has manually set the posture to a new value. Cancel our posture transition.
         postureTransition.IsTransitioning = false
         postureTransition.NewPosture = ""
         postureTransition.TimeStarted = 0
         postureTransition.TimeFinished = 0
         this:setStateProperty("Posture-Transition", postureTransition)
      
         vrf:endTask(true)
      else      

         local currentTime = vrf:getSimulationTime()
         if(postureTransition.TimeFinished <= currentTime) then
      
         -- Transition finished
            this:setStateProperty("Posture", postureTransition.NewPosture)
         
            postureTransition.IsTransitioning = false
            postureTransition.NewPosture = ""
            postureTransition.TimeStarted = 0
            postureTransition.TimeFinished = 0
            this:setStateProperty("Posture-Transition", postureTransition)
         
            vrf:endTask(true)
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

   local postureTransition = this:getStateProperty("Posture-Transition")
   
   -- Only clear out the transition info if a new transition isn't already
   -- in place. This can happen when one transition task is replaced by another.
   if((postureTransition ~= nil) and (postureTransition.TimeStarted == timeStarted)) then
      postureTransition.IsTransitioning = false
      postureTransition.NewPosture = ""
      postureTransition.TimeStarted = 0
      postureTransition.TimeFinished = 0
      this:setStateProperty("Posture-Transition", postureTransition)
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
