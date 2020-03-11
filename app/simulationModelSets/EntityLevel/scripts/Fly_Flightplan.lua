-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
myTaskPhase = -1 --0=takeoff, 1=cruise, 2=approach/land
mySubtaskId = -1
-- Task Parameters Available in Script
--  taskParameters.takeoffRunway Type: SimObject
--  taskParameters.flightRoute Type: SimObject
--  taskParameters.destAirportLocation Type: Location3D

-- Lowers the landing gear
function landingGearDown()
	-- Move the articulated part if this entity has a langergear actuator on it.
	if (_G["landinggear"] ~= nil) then
		landinggear:open()
	end
	-- Set the landing lights appearance bit to on (some models key their landing gear off this bit)
	local a = Appearance.SetLandingLights(this:getAppearance(), true)
	a = Appearance.SetLandingGearExtended(a, true)
	vrf:executeSetData("set-appearance", {appearance = a})
end

function setToDefaultSpeed()
   local defaultSpeed = this:getParameter("ordered-speed")
   vrf:executeSetData("set-speed", {speed=defaultSpeed})
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   if (taskParameters.startInAir == true) then
      mySubtaskId = vrf:startSubtask("fly-along", {route=taskParameters.flightRoute, use_fixed_pitch=true, start_at_closest_point=true})
      myTaskPhase=1
      setToDefaultSpeed()
   else
      landingGearDown()
      mySubtaskId = vrf:startSubtask("Fixed_Wing_Takeoff", {runway=taskParameters.takeoffRunway})
      myTaskPhase = 0
   end
end

-- Called each tick while this task is active.
function tick()
   if (myTaskPhase == 0) then
      if (vrf:isSubtaskComplete(mySubtaskId)) then
         mySubtaskId = vrf:startSubtask("fly-along", {route=taskParameters.flightRoute, use_fixed_pitch=true})
         myTaskPhase=1
         setToDefaultSpeed()
      elseif (not vrf:isSubtaskRunning(mySubtaskId)) then
         vrf:endTask(false)
      end
   elseif (myTaskPhase == 1) then
      if (vrf:isSubtaskComplete(mySubtaskId)) then
         mySubtaskId = vrf:startSubtask("Land_At_Airport_Near_Location", {airportLocation=taskParameters.destAirportLocation})
         myTaskPhase=2
      elseif (not vrf:isSubtaskRunning(mySubtaskId)) then
         vrf:endTask(false)
      end
   elseif (myTaskPhase == 2) then
      if (vrf:isSubtaskComplete(mySubtaskId)) then
         vrf:endTask(true)
      elseif (not vrf:isSubtaskRunning(mySubtaskId)) then
         vrf:endTask(false)
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
   vrf:deleteObject(this)
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
