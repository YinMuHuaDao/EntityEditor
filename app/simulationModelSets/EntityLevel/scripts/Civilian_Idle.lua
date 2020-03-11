-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

function isTalkCompanionNear()
   if (taskParameters.allowTalking) then
      local nearHumans = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), 3, {types={EntityType.Lifeform()}, ignore={this}})
      -- See if there is a stationary person nearby.
      for i, entity in ipairs(nearHumans) do
         if (entity:getSpeed() < 0.2) then
	    return true
         end
      end
   end
   return false
end

local westernMaleCivType = "3:1:225:3:0:1:0"
local westernFemaleCivType = "3:1:225:3:1:1:0"
local mideastMaleCivType = "3:1:1:3:1:0:3"
local mideastFemaleCivType = "3:1:1:3:1:0:2"

function isWesternMale()   
   local entityType = this:getEntityType()
   if vrf:entityTypeMatches(westernMaleCivType, entityType) then
      return true
   end
   return false
end

function isWesternFemale()   
   local entityType = this:getEntityType()
   if vrf:entityTypeMatches(westernFemaleCivType, entityType) then
      return true
   end
   return false
end

function isMideastMale()   
   local entityType = this:getEntityType()
   if vrf:entityTypeMatches(mideastMaleCivType, entityType) then
      return true
   end
   return false
end

function isMideastFemale()   
   local entityType = this:getEntityType()
   if vrf:entityTypeMatches(mideastFemaleCivType, entityType) then
      return true
   end
   return false
end

function isMale()
   return isWesternMale() or isMideastMale()
end

function isFemale()
   return isWesternFemale() or isMideastFemale()
end

local theIdleAnimations = { 
   {animation = "stand_text", hand_item="cell", condition=isWesternMale},
   {animation = "stand_ambient_1"},
   {animation = "stand_ambient_2"},
   {animation = "stand_ambient_3"},
   {animation = "hands_on_hips1", condition=isWesternFemale},
   {animation = "stand_arms_folded", condition=isFemale},
   {animation = "talk1", condition=isTalkCompanionNear},
   {animation = "talk2", condition=isTalkCompanionNear},
   {animation = "talk3", condition=isTalkCompanionNear},
   {animation = "talk5", condition=isTalkCompanionNear}
}

mySubtaskId = -1



-- Task Parameters Available in Script
function startIdleAnimation()
   local numTries = 0
   while (numTries < #theIdleAnimations * 2) do
      local entry = theIdleAnimations[math.random(#theIdleAnimations)]
      if (this:isAnimationAvailable(entry["animation"])) then
         if (entry["condition"] == nil or entry["condition"]()) then
            vrf:executeSetData("set-di-guy-hand-item", {hand_item=entry["hand_item"]})   
            mySubtaskId = vrf:startSubtask("di-guy-animation", {di_guy_animation_task_kind=entry["animation"]})
            return
         end
      end
      numTries = numTries + 1
   end   
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   math.randomseed( os.time() )
   startIdleAnimation()
end

-- Called each tick while this task is active.
function tick()
   if (mySubtaskId >= 0) then
      if (vrf:isSubtaskRunning(mySubtaskId) == false) then
         startIdleAnimation()
      end
   end
end


-- Called when this task is being suspended, likely by a reaction activating.
function suspend()
   -- By default, halt all subtasks and other entity tasks started by this task when suspending.
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
   mySubtaskId = -1
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
