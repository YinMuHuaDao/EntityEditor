-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
availableLaunchers = {}
invalidLaunchers = {}
assignedTargets = {}
awaitingText = {}
onHold = false
taskId = -1
totalNumLaunchers = 0
assignedLaunchers = 0
-- Task Parameters Available in Script
--  taskParameters.TargetTypes Type: String List of Entity Types - Entity type of desired targets
--  taskParameters.DefenseArea Type: SimObject - Area within which the launchers will fire on targets
--  taskParameters.AvailableLaunchers Type: SimObjects - Launchers that can be given targets to shoot down
--  taskParameters.Powerunit Type:SimObject--Unit that provided power to the battery 

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   setupAvailableLaunchers()
end

function setupAvailableLaunchers()
   for i, launcher in ipairs(taskParameters.AvailableLaunchers) do
	availableLaunchers[launcher:getUUID()] = launcher
	totalNumLaunchers = totalNumLaunchers + 1
   end
   if next(availableLaunchers) == nil then
        printWarn(vrf:trUtf8("Patriot Air Defense: No available Patriot launchers"))
	vrf:endTask(false)
   end
end

-- Called each tick while this task is active.
function tick()
   --Check our rules of engagment, if not fire at will go on hold
    if not (this:getRulesOfEngagement () == "fire-at-will" ) then
        if ( onHold ==false ) then
	   --Broadcast clear engagements
	   taskId = vrf:startSubtask("send-text", {destination_name ="DtBroadcast",text = "hold-fire"})
	   onHold = true
	end
        return
    end
    
    --if our power grid is down we're done too--go on hold
    -- if there is now power unit, then just operate as normal.
   if ( onHold == false and taskParameters.Powerunit:isValid() and taskParameters.Powerunit:isDestroyed() ) then
      --Broadcast clear engagements
      taskId = vrf:startSubtask("send-text", {destination_name ="DtBroadcast",text = "hold-fire"})
      onHold = true
      return
   end
    
   --if we were on hold, set to false since passed above checks
   if ( onHold ==true ) then
      --reset
      onHold =  false
   end
    
   --todo get all hostiles in ascending range from us--Shoot closest first
   --These will be spot reports since we dont have a sensor
   local targets = {}
   findTargets(targets)
    if ((assignedLaunchers == 0) and (next(targets) == nil ) )then
         return
    end
    --So seems it takes a couple ticks to send out a text message
    --so don't go assigning anyone till you're done with the current
    --one
   if ( (assignedLaunchers< totalNumLaunchers) and (#awaitingText ==0)) then
       --Go thru the targets and assign them.
       assignTargets(targets)
    end

    if (taskId ==-1 ) and #awaitingText >0 then
       local index = next(awaitingText)
       local tar = awaitingText[index]
       sendAssignments(tar)
       printDebug("text sent")
    end
    if vrf:isTaskComplete(taskId) then
      --We're ready to send the next text or start assigning more
      taskId =-1
    end

   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   --Currently this is a continuous task
   --vrf:endTask(true)

end

function findTargets(validTargets)
   local contactList=this:getAllHostileContacts()
   local target
   local dead = false
   local assignedIndex = nil

   for i, target in pairs(contactList) do
      local targetType = target:getEntityType()
      if target:isDestroyed() then
         dead = true
      else
          dead = false
      end
         --If the target is destroyed, remove it from our assigned targets
      assignedIndex = findAssignedTarget(assignedTargets,target:getUUID())
      if  assignedIndex ~= "" then
         if dead then
	    -- Might need to send a clear although reactive launcher task should
	    -- clear automatically if target is dead
	    assignedTargets[assignedIndex] = nil
	  end
	 --Regardless this target is spoken for so don&apos;t add to the target list
      else
         if  targetMatch(targetType)  and not dead and
            taskParameters.DefenseArea:isPointInside(
            target:getLocation3D())then
	    --We have a valid target insert into our target list
	    printDebug("valid target", target:getName())
	    validTargets[target:getUUID()] = target
         end
       end      
   end
end

function targetMatch(targetType)
   local match = false
   local j = 1
   for j,type in ipairs(taskParameters.TargetTypes) do
      if vrf:entityTypeMatches(targetType,type) then
         match=true
	 break
      end
   end
   return match
end

function assignTargets(targets)
   local launcher = nil
   local tgt =nil
   --go thru targets and find an available launcher for them
   for p,tgt in pairs(targets) do
      launcher = findClosestLauncher(tgt)
      if launcher ~= nil then
         assignedTargets[launcher:getUUID()] = tgt
	 assignedLaunchers = assignedLaunchers + 1
         table.insert(awaitingText,tgt)
	 printDebug("assign ",launcher:getName())
	 printDebug("target ",tgt:getName())
	 --Be sure to remove this target from our list
      else
          --No point in going thru more targets we're out of launchers
          break      
      end
   end
end

function findClosestLauncher(tgt)
   local launcher = nil
   local bestLauncher = nil
   for id,launcher in pairs(availableLaunchers) do
      --is this launcher free?
      if ( validLauncher(launcher) ) then
         if ( assignedTargets[launcher:getUUID()] == nil) then
            local closestTgt = nil
            local closestRange =1e10
	    local targetLoc = tgt:getLocation3D()
            local targetRange = launcher:getLocation3D():distanceToLocation3D(
                  targetLoc)
	    if ( targetRange < closestRange ) then
	       closestRange = targetRange
	       bestLauncher = launcher
	    end
         end
      end
    end
    return bestLauncher
end

function validLauncher(launcher)
   --Is it destroyed?
   local bret  = true
   if ( launcher:isDestroyed() or not launcher:isValid() ) then
      bret = false
   end
   --Next check if incapicated--i.e. out of ammo,comms down,etc
   if ( invalidLaunchers[launcher:getUUID()] ~=nil ) then
      --launcher is no good
      bret = false
   end
   return bret
end

function sendAssignments(tar)
    --now we send the launcher a text with the target
      local mess = "Fire"..tar:getName()
      printInfo(mess)
      --look up launcher
      local uuid =findAssignedTarget(assignedTargets,tar:getUUID())
      if uuid ~=""  then
         local launcher = nil
         launcher = vrf:getSimObjectByUUID(uuid)
	taskId = vrf:startSubtask("send-text", {destination_name = launcher,text = mess})
         table.remove(awaitingText,1)
      end
end

function findAssignedTarget(assignedTargets,id)
   local launcherUuid = ""
   for uuid, tgt in pairs(assignedTargets) do
        if (tgt:getUUID() == id) then
	   launcherUuid  = uuid
	   break
	end
   end
   return launcherUuid
end

function clearAssignment(launcher)
   printDebug("clear assign")
   assignedTargets[launcher:getUUID()] = nil
   assignedLaunchers = assignedLaunchers - 1
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
   --A launcher has become available
   if ( message =="free" ) then
      if ( invalidLaunchers[sender:getUUID()] ~=nil ) then
         --This launcher is available again
	 invalidLaunchers[sender:getUUID()] = nil
      else
         clearAssignment(sender)
      end
   end
   --Launcher is out of commission
   if ( message == "no ammo" ) then
      --We unassign the launcher
      clearAssignment(sender)
      --and place on invalid list
      invalidLaunchers[sender:getUUID()] = sender
   end
end
