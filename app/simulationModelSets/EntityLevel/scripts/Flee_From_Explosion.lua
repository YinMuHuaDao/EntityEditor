-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
vrf:require("vrfutil")

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
checkpointState.runSubtaskId = -1
checkpointState.recentDetonations = {} -- List of { location, time }
vrf:setCheckpointMode(CheckpointStateOnly)

local fleeSpeed = 6.7 -- 15 mph
local theDetonationTimeout = 60 -- seconds
local theMunitionTypesToFleeFrom = 
{
   "2:9:225:2:6:-1:-1",
   "2:9:225:2:7:-1:-1",
   "2:9:225:2:8:-1:-1",
   "2:9:225:2:14:2:-1",
   "2:9:225:1:15:6:-1",
   "2:9:225:2:85:1:-1" -- Grenade
}
local isRegistered = false

-- Task Parameters Available in Script
--  taskParameters.DetonationRange Type: Real Unit: meters - Detonations within this range cause the entity to flee


-- Called to register interest in detonations
function registerDetonationInterest()
   for i, munition in ipairs(theMunitionTypesToFleeFrom) do
      this:registerDetonationInterest(taskParameters.DetonationRange, munition)
   end
   
   isRegistered = true
end

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(0.5)
   
   -- Register our interest in knowing about detonations within our range
   if not isRegistered then
      registerDetonationInterest()
   end
   
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   
   -- Register our interest in knowing about detonations within our range
   if not isRegistered then
      registerDetonationInterest()
   end
   
   -- Check if entity AI is enabled. If not, a reactive task should generally not
   -- run, as this means the entity is making a decision for itself how to behave
   -- as the result of events within the scenario.
   local aiEnabled = this:getStateProperty(AIEnabledStateProperty)   
   if (aiEnabled ~= nil and not aiEnabled) then
      return false
   end
   
   -- Check for detonations
   if (updateDetonationList()) then         
      if (#checkpointState.recentDetonations > 0) then
         return true
      end
   end
      
   return false
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Checks for any new detonations and puts them on the list.
function updateDetonationList()
   local listChanged = false
   -- prune any old detonations from the list
   for i, detEntry in ipairs(checkpointState.recentDetonations) do
      if (detEntry.time + theDetonationTimeout < vrf:getSimulationTime()) then
         printInfo("Timing out detonation at ", detEntry.location)
         table.remove(checkpointState.recentDetonations, i)
         listChanged = true
      end
   end
   -- Add any new ones
   local detOccured = false
   local munitionType = nil
   local detLocation = nil
   detOccured, munitionType, detLocation = this:getLastDetonation()
   if (detOccured) then
      local detEntry = {}
      detEntry.location = detLocation
      detEntry.time = vrf:getSimulationTime()
      table.insert(checkpointState.recentDetonations, detEntry)
      printInfo("New detonation at ", detEntry.location)
      listChanged = true
   end
   return listChanged
end

function getDetonationObject(detLocation)
   -- If we are not the first to react to the explosion, an object for it may exist.
      local nearbyObjects = vrf:getSimObjectsNear(detLocation, 1)
      
      if( nearbyObjects ) then
         for entityNum,entity in pairs(nearbyObjects) do
            if(entity:getEntityType() == "16:1:0:0:0:0:0") then
               -- Found the detonation object
               return entity
            end
         end
      end
      
      if(not detonationObj) then
         -- We are the first to react. Create an object to run from.
         return vrf:createWaypoint(
            {entity_type="16:1:0:0:0:0:0", location=detLocation, publish=false})
      end
      return nil
end

-- Called each tick while this task is active.
function tick()

   -- Check to see if something has changed about the detonations (new or expired)
   if (updateDetonationList()) then
      if (checkpointState.runSubtaskId >= 0) then
         -- Stop the running flee task.  A new one will get started if needed.
         vrf:stopSubtask(checkpointState.runSubtaskId)
         checkpointState.runSubtaskId = -1
      end
      
      if (#checkpointState.recentDetonations == 0) then
         vrf:endTask(true)
         return
      end
   end
   
   if(checkpointState.runSubtaskId == -1) then
   
      -- Flee least 25% farther than our detonation detection range
      local fleeRange = taskParameters.DetonationRange + taskParameters.DetonationRange * 0.25
      
      local fleeFromTable = {}
      for i, detEntry in ipairs(checkpointState.recentDetonations) do
         local detonationObj = getDetonationObject(detEntry.location)      
         table.insert(fleeFromTable, detonationObj)
      end
      
      -- Run!
      vrf:executeSetData("set-navigation-preference", {road_preference="ignore-roads"})
      checkpointState.runSubtaskId  = vrf:startSubtask("flee", 
         {fleeFrom=fleeFromTable, radius=fleeRange})
      vrf:executeSetData("set-speed", {speed=fleeSpeed})
         
   elseif(vrf:isSubtaskComplete(checkpointState.runSubtaskId)) then      
      -- Ok, I think we're safe, stop running.
      checkpointState.runSubtaskId = -1
      
      -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
      -- Wrap it in an appropriate test for completion of the task.
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
   -- Return to default ordered speed for the entity.
   vrf:executeSetData("set-navigation-preference", {road_preference="avoid-roads"})
   local defaultSpeed = this:getParameter("ordered-speed")
   vrf:executeSetData("set-speed", {speed=defaultSpeed})
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
