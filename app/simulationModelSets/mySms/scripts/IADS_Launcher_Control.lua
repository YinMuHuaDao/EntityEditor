-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
targetName=""
taskId = -1
isActive = false
state = "free"
myController = ""
myLauncherSystem = nil

-- These are the resource names that will be checked for when determining 
-- if there are any missiles left.
-- Note:  Dashes need to be escaped with %
local theMissileNames = {
	"PAC%-3%-missile",
	"SA%-21%-missile"
	}

function findResourceName()
   for i, rName in ipairs(this:getResourceNames()) do
      for j, mName in ipairs(theMissileNames) do
	 local res = rName:find(mName)
         if res ~= nil then
            return rName
         end
      end
   end
   return nil
end
	
-- Run this at startup to cache the resource name to use.
local theResourceName = findResourceName()


-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   -- Returning true will cause the reactive task to become active and will call init()
   -- and tick() until the task completes.
   --if we are in a state of no ammo, check for resupply
  if ( not haveAmmo() ) then
      state = "no ammo"
      isActive = true
    return true;
   else 
      if (targetName:len() >0) then
         state = "awaitingTarget"
         isActive = true
         return true
      end
  end
  isActive = false
   return false
end

-- Called when the task first starts. Never called again.
function init()
   myLauncherSystem = this:getSystem("weapon")
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   taskId = -1
end

-- Called each tick while this task is active.
function tick()
   if ( state == "no ammo" ) then
      if ( haveAmmo() ) then
         clear("free")
	 state = "clearing"
      end
   end
   
   if ( state == "clearing" ) then
      if ( vrf:isTaskComplete(taskId) )then
         -- we've sent the  text message to our controller
	 state = "free"
	 targetName=""
	 taskId = -1
	 printDebug("task complete")
	 vrf:endTask(true)
      end
   end
   
   if (state == "awaitingTarget" ) then
      if ( taskId == -1 ) and validTgt() then
         -- do we have ammo left to shoot?
         if ( haveAmmo() ) then
            taskId = vrf:startSubtask("fire-at-target", {
               target = targetName,
	       auto_select_weapon = true})
            state="firing"	 
         else
            clear("no ammo")
         end
      end
   end
   
   if (state =="firing") then
      if ( vrf:isTaskComplete(taskId) ) then
         -- we need to wait until the missile either hits or
	 if ( myLauncherSystem ) then
	    local isPassed = myLauncherSystem:getAttribute(
                "passed-target")
	    if ( isPassed ) then
               clear("free")   
	       state = "clearing"
	    else
	       --check if target is destroyed
	       local target = vrf:getSimObjectByName (targetName)
	       if (target and target:isDestroyed() ) then
                  clear("free")   
	          state = "clearing"
	       end
	    end
	 end
	 
      end
   end
end

function haveAmmo()
   if (theResourceName == nil) then
      theResourceName = findResourceName()
      
   end
   if (theResourceName == nil) then
      return false
   end
   local current,full = this:getResourceAmounts(theResourceName)
   if ( current <= 0 ) then
      --We have no missiles
      state = "no ammo"
      return false
   end
   return true
end

function validTgt()
   --look up target
      local tgt = vrf:getSimObjectByName(targetName)
      if (tgt:isValid()) and (not tgt:isDestroyed()) then
         return true
      else
         --invalid target send clear
	 clear("free")
	 state = "clearing"
	 return false
      end
end

function clear(msg)
   --Send text back to parent so we know this launcher is free again
   taskId = vrf:startSubtask( "send-text", {destination_name = myController,text =msg})
   printDebug("send text")
   isActive = false
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
   if string.find(message,"Fire") ~= nil then
          local i,j =string.find(message,"Fire")
          --Now get the target
          targetName = string.sub(message,j+1)
          printInfo("firing at",targetName)
	  myController = sender:getName()
	  taskId = -1
	  state = "awaitingTarget"
   end
   if (( message == "hold-fire") and isActive) then
      clear("free")
   end
end



-- Called when a reactive task is disabled (check will no longer called)
-- It is typically not necessary to add code to this function.
function disable()
end
