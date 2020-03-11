-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables
--
-- Global variables get saved when a scenario gets checkpointed in one of the folowing way:
-- 1) If the checkpoint mode is AllGlobals all global variables defined will be saved as part of the save stat
-- 2) In setting CheckpointStateOnly, this means that the script will *only* save variables that are part of the checkpointState table.  If you remove this value, it will then
--    default to the behavior of sabing all globals
--
-- If you wish to change the mode, call setCheckpointMode(AllGlobals) to save all globals or setCheckpointMode(CheckpointStateOnly)
-- to save only those variables in the checkpointState table
-- They get re-initialized when a checkpointed scenario is loaded.
vrf:setCheckpointMode(CheckpointStateOnly)


local SPACING = 1
local AUTO_RELEASE = false
local RELEASE_PERIOD = 10.0

-- List of all the slots on the queue.  Entries are tables that contain location, entity
checkpointState.slots = {}
-- List of objects that are on their way to the queue, but have not yet reached the entry point.
checkpointState.pendingObjects = {}
-- List of objects that want to be in the queue, but there is not enough room for them.
checkpointState.waitingObjects = {}

-- Called when the task first starts. Never called again.
function init()

   printInfo("Starting Queue Manager")
   setupSlots()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   
   -- check for changes in the queue geometry
   if (checkGeometryChanged()) then
      adjustSlots()
   end
   
   purgeBadEntities()
      
   moveObjectsUpInQueue()
   
   -- If there are waiters and free slots, add one to the queue
   if (#checkpointState.waitingObjects > 0 and 
      numFreeSlots() > 0 and
      checkpointState.slots[#checkpointState.slots].entity == nil) then
      o = checkpointState.waitingObjects[1]
      table.remove(checkpointState.waitingObjects, 1)
      addToQueue(o)
   end
end


-- If any entity in the queue is dead or invalid, remove it from the queue manager
function purgeBadEntities()
   for slotNum, slot in ipairs(checkpointState.slots) do
      if (slot.entity ~= nil) then
         if (not slot.entity:isValid() or slot.entity:isDestroyed()) then
	    slot.entity = nil
	end
      end
   end
end


-- Returns true if the geometry of this route has changed.
function checkGeometryChanged()
   if (checkpointState.previousPoints == nil) then
      -- First time called.  Set up the geometry.
      checkpointState.previousPoints = this:getLocations3D()
   else
      local currentPoints = this:getLocations3D()
      for i, p in ipairs(checkpointState.previousPoints) do
         if (p:distanceToLocation3D(currentPoints[i]) > 0.5) then
	    return true
	end
      end
   end
   return false
end

-- Recalculates slots based on new geometry and gets all the objects in line to move to the new slot locations
function adjustSlots()
   local oldSlots = checkpointState.slots
   setupSlots()
   
   -- Task all the waiting entities to move to new slot locations.
   local nextNewSlotNum = 1
   for slotNum, slot in ipairs(oldSlots) do
      if (slot.entity ~= nil) then
         if (nextNewSlotNum <= #checkpointState.slots) then
            local newSlot = checkpointState.slots[nextNewSlotNum]
	    newSlot.entity = slot.entity
	    newSlot.inPosition = false
	    vrf:sendMessage(newSlot.entity, "MoveTo:"..encodeLocation(newSlot.location))
	    nextNewSlotNum = nextNewSlotNum + 1
	else
	   -- There is not a new slot for this entity, so put it on the wiating list.  (the queue must have been modified to make it smaller)
	   table.insert(checkpointState.waitingObjects, slot.entity)
	end
      end
   end
end

-- Releases the next object on the queue if there is one
-- Does not require them to be in position to release.
-- Return true if one was released.
function releaseNextObject()
   for slotNum, slot in ipairs(checkpointState.slots) do
      if (slot.entity ~= nil) then
         printInfo("Release: ", slot.entity)
         vrf:sendMessage(slot.entity, "QueueRelease")
         slot.entity = nil
         return true
      end
   end
   return false
end

function encodeLocation(loc3D)
   return loc3D:getLat()..":"..loc3D:getLon()..":"..loc3D:getAlt()
end

-- Creates the slots table based on the current geometry of the queue.
-- All slot locations are cleared.
function setupSlots()
   checkpointState.slots = {}
   local points = this:getLocations3D()
   checkpointState.previousPoints = this:getLocations3D()
   if (#points >= 2) then
      local p1 = nil
      for ptNum = #points, 1, -1 do
         local p2 = points[ptNum]
         if (p1 ~= nil) then         
            local dist = p2:distanceToLocation3D(p1)
            local numSlots = math.ceil(dist / SPACING)
            if (numSlots >= 2) then
               local vec = p1:vectorToLoc3D(p2)
               vec = vec:getScaled(1 / (numSlots - 1))
               printInfo("Queue Length: ", dist, " NumSlots: ", numSlots)
               for slot=1,numSlots-1 do
                  local newSlot = {}
                  local slotLoc = p1:addVector3D(vec:getScaled(slot - 1))
                  newSlot["location"]=slotLoc
                  newSlot["entity"]=nil
                  table.insert(checkpointState.slots, newSlot)
                  vrf:updateTaskVisualization("slot" .. #checkpointState.slots, "point", {color={255, 255, 0, 128}, location=slotLoc, size=SPACING})
               end
            end
         end
         p1 = p2
      end
   end   
end

function moveToLastAvailableSlot(object)
   local bestFreeSlot = nil
   for slotNum = #checkpointState.slots, 1, -1 do
      local slot = checkpointState.slots[slotNum]
      if (slot["entity"] == nil) then
         bestFreeSlot = slot
      else
         if (bestFreeSlot ~= nil) then
            bestFreeSlot["entity"] = object
            bestFreeSlot["inPosition"] = false
            vrf:sendMessage(object, "MoveTo:"..encodeLocation(bestFreeSlot.location))
         else
            vrf:sendMessage(object, "QueueFull")
            table.insert(checkpointState.waitingObjects, 1, object) -- put to start of waiting list, since entity is already at the start of the line.
         end
         return
      end
   end
   -- We get here if all slots are free.  First is the best.
   bestFreeSlot = checkpointState.slots[1]
   bestFreeSlot["entity"] = object
   bestFreeSlot["inPosition"] = false
   vrf:sendMessage(object, "MoveTo:"..encodeLocation(bestFreeSlot.location))
end

function numFreeSlots()
   local freeSlots = 0
   for slotNum, slot in ipairs(checkpointState.slots) do
      if (slot["entity"] == nil) then
         freeSlots = freeSlots + 1         
      end
   end
   return freeSlots  - #checkpointState.pendingObjects
end

function addToQueue(object)
   
   local emptySpace = numFreeSlots()
   if (emptySpace > 0 and 
      checkpointState.slots[#checkpointState.slots].entity == nil) then
      -- start out going to the end of the line.  A slot will get reserved once they are there.
      vrf:sendMessage(object, "MoveTo:"..encodeLocation(this:getLocations3D()[1]))
      table.insert(checkpointState.pendingObjects, object)
      return
   else
      -- No Slot Available
      --printInfo("No space on queue")
      vrf:sendMessage(object, "QueueFull")
      table.insert(checkpointState.waitingObjects, object)
   end
   
end

function processJoinQueue(object)
   printInfo("Process joiner: ", object)
   if (#checkpointState.waitingObjects > 0) then
      table.insert(checkpointState.waitingObjects, object)
   else
      addToQueue(object)
   end
end

-- This is any time an object sends an InPosition message to the queue
-- This means on of 2 things:
--   1)  It is on the pending list, and has arrived at the start of the queue, and now needs a slot
--   2)  It has reached its designated slot
function processInPosition(object)
   -- check for this obejct on the pending list
   for i, o in ipairs(checkpointState.pendingObjects) do
      if (o == object) then
         table.remove(checkpointState.pendingObjects, i)
         moveToLastAvailableSlot(object)
         return
      end
   end
   
   --check for this object already in the queue, moving to a slot
   for slotNum, slot in ipairs(checkpointState.slots) do
      if (slot.entity == object) then
         slot.inPosition = true
         return
      end
   end
end

-- Removes this object from slot and other lists.
-- It has informed us that it is no longer participating in the queue
function processLeavingQueue(object)
   for i, o in ipairs(checkpointState.pendingObjects) do
      if (o == object) then
         table.remove(checkpointState.pendingObjects, i)
         return
      end
   end
   
   for slotNum, slot in ipairs(checkpointState.slots) do
      if (slot.entity == object) then
         slot.entity = nil
         return
      end
   end
   
   for i, o in ipairs(checkpointState.waitingObjects) do
      if (o == object) then
         table.remove(checkpointState.waitingObjects, i)
         return
      end
   end
end

-- Goes through all the slots and objects in the queue and 
-- tells them to move up in line if appropriate
function moveObjectsUpInQueue()
   local availSlot = nil
   for slotNum, slot in ipairs(checkpointState.slots) do
      if (availSlot == nil) then
         -- Just try to find an available slot
         if (slot.entity == nil) then
            availSlot = slot
         end
      else
         if (slot.entity ~= nil) then
            availSlot.entity = slot.entity
            availSlot.inPosition = false
            slot.entity = nil
            vrf:sendMessage(availSlot.entity, "MoveTo:"..encodeLocation(availSlot.location))
            availSlot = nil
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
   vrf:setTickPeriod(0.5) -- Workaround for apparent issue where this is incorrect after a load.
end


-- Called when this task is ending, for any reason.
-- It is typically not necessary to add code to this function.
function shutdown()
   -- Release all objects from queue
   for i, o in ipairs(checkpointState.pendingObjects) do
      vrf:sendMessage(o, "QueueRelease")
   end
   
   for slotNum, slot in ipairs(checkpointState.slots) do
      if (slot.entity ~= nil) then
         vrf:sendMessage(slot.entity, "QueueRelease")
      end
   end
   
   for i, o in ipairs(checkpointState.waitingObjects) do
      vrf:sendMessage(o, "QueueRelease")
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
   if (message == "JoinQueue") then
      processJoinQueue(sender)
   elseif (message == "InPosition") then
      processInPosition(sender)
   elseif (message == "LeaveQueue") then
      processLeavingQueue(sender)
   elseif (message == "QueueReleaseNext") then
      releaseNextObject()
   end
end
