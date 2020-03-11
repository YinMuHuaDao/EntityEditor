-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Rope types and their lengths
local theRopeTypes = 
{
   {length=10, type="5:1:0:27:6:1:0"},
   {length=15, type="5:1:0:27:6:2:0"},
   {length=20, type="5:1:0:27:6:3:0"}
}

-- Task Parameters Available in Script
--  taskParameters.numberRopes Type: Integer - Number of Ropes to deploy

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()
   -- Create desired number of ropes from desired location and length.
   local i = 0
   local numRopes = taskParameters.numberRopes
   --Create number of ropes
   for  i=1,numRopes do
      local ropeLocation, errorCode = vrf:getScriptAttribute("Rope-Location")
      createRope(ropeLocation)
   end
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   vrf:endTask(true)

end

function createRope(ropeOffset)
   local ends = {}
   local height=this:getHeightAboveTerrain()
   if (height >36.0) then
      --36 m is longest rope military uses for fast roping,
      height = 36.0
   end
   local off = ropeOffset:makeVectorRefToDirection(this:getDirection3D())
   local top = this:getLocation3D():addVector3D(off)
   local gnd = Location3D(top:getLat(),top:getLon(),top:getAlt()-height)
   ends[1] = top
   ends[2] = gnd
   --mySimObject = vrf:createTacticalGraphic ({entity_type = "17:0:0:2:1:0:0",locations = ends})
   local ropeType = findRopeType(height)
   mySimObject = vrf:createEntity({entity_type = ropeType,location = top})
   mySimObject:changeAttachment(this:getUUID())
end

-- Returns the rope entity type that is the best fit for the specified height
function findRopeType(height)
   local bestRope = nil
   for i, ropeEntry in ipairs(theRopeTypes) do
      if (bestRope == nil) then
         bestRope = ropeEntry
      elseif (bestRope.length < height and ropeEntry.length > bestRope.length) then
         bestRope = ropeEntry
      elseif (bestRope.length > height and
         ropeEntry.length >= height and
         ropeEntry.length < bestRope.length) then
         bestRope = ropeEntry
      end
   end
   return bestRope.type
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
