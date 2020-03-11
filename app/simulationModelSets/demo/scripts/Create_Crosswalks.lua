-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

crosswalkFeatures = nil
crosswalksToCreate = {}

-- Task Parameters Available in Script
--  taskParameters.range Type: Real Unit: meters - Create crosswalks within this range of the specified locaiton


-- Called when the task first starts. Never called again.
function init()

   -- Since this is a set, it should tick while the simulation is paused
   vrf:setTickWhilePaused(true)

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Called each tick while this task is active.
function tick()

   if crosswalkFeatures == nil then
      crosswalkFeatures = vrf:getFeaturesWithinRange(this:getLocation3D(), taskParameters.range, {query="MAK_CROSSWALK"})
   elseif crosswalkFeatures:isLoaded() then
   
      if next(crosswalksToCreate) == nil then
         local numFeatures = crosswalkFeatures:getFeatureCount()
         for i=1, numFeatures, 1 do
            local vertices = crosswalkFeatures:getLocations3D(i)
            local width = tonumber(crosswalkFeatures:getFeatureAttributeValue(i, "width"))
            crosswalksToCreate[i] = {
               vertices = vertices,
               width = width/2 }
         end
      end
      
      local createdCrosswalks = {}
      for i, crosswalk in pairs(crosswalksToCreate) do
         local canCreate = true
         for v, vertex in pairs(crosswalk.vertices) do
            local alt, isValid = vrf:getTerrainAltitude(vertex:getLat(), vertex:getLon())
            if isValid then
               crosswalk.vertices[v]:setAlt(alt)
            else
               canCreate = false
            end
         end
         
         if canCreate then
            local crosswalkObj = vrf:createTacticalGraphic({
               entity_type="17:0:0:2:0:0:4",
               object_name_prefix="Crosswalk",
               locations=crosswalk.vertices})
            table.insert(createdCrosswalks, i)
            --vrf:sendSetData(crosswalkObj, "set-width", {width=crosswalk.width})
         end
      end
      
      for i, crosswalkIndex in pairs(createdCrosswalks) do
         crosswalksToCreate[crosswalkIndex] = nil
      end
      
      if next(crosswalksToCreate) == nil then
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
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
