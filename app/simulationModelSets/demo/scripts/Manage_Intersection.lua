-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

local DEBUG_DETAIL = false

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

cycleOneCrosswalks = {}
cycleOneTrafficLights = {}
cycleTwoCrosswalks = {}
cycleTwoTrafficLights = {}
nextCycleTime = 0
nextDoNotWalkTime = -1
nextYellowLightTime = -1
currentCycle = 1
flashDoNotWalk = false
flashOn = false

-- Length of time at the end of the cycle when pedestrians are told not to walk before we change to next cycle.
doNotWalkDuration = -1

-- Length of time at the end of the cycle when cars are shown a yellow light.
yellowLightDuration = -1

local crosswalkEntityTypes = {"17:0:0:02:0:0:3", "17:0:0:02:0:0:4"}
local trafficLightEntityType = "5:1:0:6:4:0:1"

-- Task Parameters Available in Script
--  taskParameters.cycleOneObjects Type: SimObjects - The selected objects will all run on the same cycle, being enabled or disabled together
--  taskParameters.cycleTwoObjects Type: SimObjects - The selected objects will all run on the same cycle, being enabled or disabled together
--  taskParameters.cycleDuration Type: Integer Unit: seconds - The length of time each cycle is enabled

-- Returns true if the entity type is for a crosswalk
function isCrosswalk(entityType)
   local i
   for i, crosswalkType in pairs(crosswalkEntityTypes) do
      if vrf:entityTypeMatches(entityType, crosswalkType) then
         return true
      end
   end
   
   return false
end

-- Returns true if the entity type is for a traffic light
function isTrafficLight(entityType)
   return vrf:entityTypeMatches(entityType, trafficLightEntityType)
end

-- Called when the task first starts. Never called again.
function init()

   local i
   local obj
   
   for i, obj in pairs(taskParameters.cycleOneObjects) do
      local entType = obj:getEntityType()
      if isCrosswalk(entType) then
         table.insert(cycleOneCrosswalks, obj)
      elseif isTrafficLight(entType) then
         table.insert(cycleOneTrafficLights, obj)
      else
         printWarn(vrf:trUtf8("Specified object, %1, is not a crosswalk or traffic light."):arg(obj:getName()))
      end
   end
   
   for i, obj in pairs(taskParameters.cycleTwoObjects) do
      local entType = obj:getEntityType()
      if isCrosswalk(entType) then
         table.insert(cycleTwoCrosswalks, obj)
      elseif isTrafficLight(entType) then
         table.insert(cycleTwoTrafficLights, obj)
      else
         printWarn(vrf:trUtf8("Specified object, %1, is not a crosswalk or traffic light."):arg(obj:getName()))
      end
   end
   
   nextCycleTime = 0
   currentCycle = 1
   flashDoNotWalk = false
   
   doNotWalkDuration = math.min(math.max(10, 0.25 * taskParameters.cycleDuration), 0.5 * taskParameters.cycleDuration)
   yellowLightDuration = math.min(math.max(4, 0.10 * taskParameters.cycleDuration), 0.2 * taskParameters.cycleDuration)

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
end

-- Gets the appearances for the list of objects and stores it in a table.
function getAppearances(objects, appearances)

   for i, obj in pairs(objects) do
      appearances[obj] = obj:getAppearance()
   end

end

-- Given a table of objects and their desired appearances, sets these appearances for each object.
function setAppearances(appearances)

   for obj, appearance in pairs(appearances) do
      vrf:sendSetData(obj, "set-appearance", {appearance=appearance})
   end

end

-- Sets the traffic light states in the given table of appearances
function setTrafficLights(appearances, state)

   local redOn = false
   local greenOn = false
   local yellowOn = false
   
   if state == "red" then
      redOn = true
   elseif state == "green" then
      greenOn = true
   elseif state == "yellow" then
      yellowOn = true
   end
   
   for o, appearance in pairs(appearances) do

      appearance = Appearance.SetSmokeEmanating(appearance, greenOn)
      appearance = Appearance.SetPowerPlantStatus(appearance, redOn)
      appearance = Appearance.SetFlaming(appearance, yellowOn)
      appearances[o] = appearance
      
   end

end

-- Sets the walk signal states in the given table of appearances
function setWalkSignals(appearances, state)

   local redOn = false
   local greenOn = false
   
   if state == "red" then
      redOn = true
   elseif state == "green" then
      greenOn = true
   end
   
   for o, appearance in pairs(appearances) do

      appearance = Appearance.SetSpotLights(appearance, greenOn)
      appearance = Appearance.SetInteriorLights(appearance, redOn)
      appearances[o] = appearance
      
   end
   
end

-- Sets the crosswalk states
function setAllowCrossing(crosswalks, on)
   
   for i, crosswalk in pairs(crosswalks) do
      vrf:sendSetData(crosswalk, "Allow_Crossing", {allow=on})
   end

end

-- Called each tick while this task is active.
function tick()

   if next(cycleOneCrosswalks) == nil and
      next(cycleOneTrafficLights) == nil and
      next(cycleTwoCrosswalks) == nil and
      next(cycleTwoTrafficLights) == nil then
      
      printWarn(vrf:trUtf8("No valid objects to manage were specified.")) 
   end
   
   local currentTime = vrf:getSimulationTime()
   
   if DEBUG_DETAIL then
      printWarn("------------" .. currentTime)
      printWarn("   Next Do Not Walk Time " .. nextDoNotWalkTime)
      printWarn("   Next Yellow Light Time" .. nextYellowLightTime)
      printWarn("   Next Cycle Time" .. nextCycleTime)
   end
   
   local crosswalks = {}
   local lights = {}
   local otherCrosswalks = {}
   local otherLights = {}
   local currName = ""
   local otherName = ""
   
   if currentCycle == 1 then
      crosswalks = cycleOneCrosswalks
      lights = cycleOneTrafficLights
      otherCrosswalks = cycleTwoCrosswalks
      otherLights = cycleTwoTrafficLights
      
      currName = "curr (1)"
      otherName = "other (2)"
   else
      crosswalks = cycleTwoCrosswalks
      lights = cycleTwoTrafficLights
      otherCrosswalks = cycleOneCrosswalks
      otherLights = cycleOneTrafficLights
      
      currName = "curr (2)"
      otherName = "other (1)"
   end
   
   -- Get current appearances of lights
   local lightAppearances = {}
   local otherLightAppearances = {}
   getAppearances(lights, lightAppearances)
   getAppearances(otherLights, otherLightAppearances)
   
   if nextDoNotWalkTime > 0 and currentTime >= nextDoNotWalkTime then
      -- Disallow crosswalk crossing
      setAllowCrossing(crosswalks, false)
      
      -- Begin flashing red "do not walk" lights
      flashDoNotWalk = true
      flashOn = true
      
      nextDoNotWalkTime = -1
      
      if DEBUG_DETAIL then
         printWarn(otherName .. " -> flash do not walk")
      end
   end
   
   if flashDoNotWalk then
      -- Toggle "do not walk" light
      flashOn = not flashOn
      if flashOn then
         setWalkSignals(otherLightAppearances, "red")
      else
         setWalkSignals(otherLightAppearances, "off")
      end
   end
   
   if nextYellowLightTime > 0 and currentTime >= nextYellowLightTime then      
      -- Turn lights yellow
      setTrafficLights(lightAppearances, "yellow")
      
      nextYellowLightTime = -1
      
      if DEBUG_DETAIL then
         printWarn(currName .. " -> yellow")
      end
   end

   if currentTime >= nextCycleTime then
      
      -- Disallow crosswalk crossing
      setAllowCrossing(crosswalks, false)
         
      -- Turn lights red
      setTrafficLights(lightAppearances, "red")
      
      -- Turn walk signal green
      setWalkSignals(lightAppearances, "green")
      
      if DEBUG_DETAIL then
         printWarn(currName .. " -> red")
         printWarn(currName .. " -> walk")
      end
      
      -- Allow crosswalk crossing for next cycle
      setAllowCrossing(otherCrosswalks, true)
      
      -- Turn lights green for next cycle
      setTrafficLights(otherLightAppearances, "green")
      
      -- Turn walk signal for next cycle red
      setWalkSignals(otherLightAppearances, "red")
      
      if DEBUG_DETAIL then
         printWarn(otherName .. " -> green")      
         printWarn(otherName .. " -> do not walk")
      end
      
      if currentCycle == 1 then
         currentCycle = 2
      else
         currentCycle = 1
      end
      
      -- Reset timers      
      nextCycleTime = currentTime + taskParameters.cycleDuration
      nextDoNotWalkTime = currentTime + taskParameters.cycleDuration - doNotWalkDuration
      nextYellowLightTime = currentTime + taskParameters.cycleDuration - yellowLightDuration
      flashDoNotWalk = false
   end
   
   -- Update appearances of lights
   setAppearances(lightAppearances)
   setAppearances(otherLightAppearances)

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
