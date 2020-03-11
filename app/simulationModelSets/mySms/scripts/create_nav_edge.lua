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

-- Task Parameters Available in Script
--  taskParameters.NavTag Type: Integer (0 - choice limit)
--  taskParameters.Profile Type: Integer (0 - choice limit)

vrf:setTickWhilePaused(true)

-- Called when the task first starts. Never called again.
function init()


   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   local navTag = ""
   if taskParameters.NavTag == 0 then
      navTag = "road"
   elseif taskParameters.NavTag == 1 then
      navTag = "pedestrian-path"
   elseif taskParameters.NavTag == 2 then
      navTag = "crosswalk"
   elseif taskParameters.NavTag == 3 then
      navTag = "door"
   else
      printWarn("Invalid nav tag: " .. taskParameters.NavTag)
      vrf:endTask(false)
      return
   end

   local profile = ""
   if taskParameters.Profile == 0 then
      profile = "lifeform"
   elseif taskParameters.Profile == 1 then
      profile = "ground-platform"
   else
      printWarn("Invalid profile: " .. taskParameters.Profile)
      vrf:endTask(false)
      return
   end
   
   local locs = this:getLocations3D()
   if #locs < 2 then      
      printWarn("Invalid route, not enough points")
      vrf:endTask(false)
      return
   end
   
   local fn = profile .. ".navEdgeInput"
   local f, err = io.open(fn, "a")
      
   local prevX = 0
   local prevY = 0
   local prevZ = 0
   for i, loc in pairs(locs) do
   
      if prevX ~= 0 and prevY ~= 0 and prevZ ~= 0 then
         f:write("{", prevX, ", ", prevY, ", ",prevZ, "} ")
      end
      
      local x = 0
      local y = 0
      local z = 0
      
      x, y, z = loc:getGeocentric()
      
      if prevX ~= 0 and prevY ~= 0 and prevZ ~= 0 then
         f:write("{", x, ", ", y, ", ", z, "} \"", navTag, "\"\n")
      end
      
      prevX = x
      prevY = y
      prevZ = z
      
   end
   
   f:close()

   vrf:endTask(true)

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
