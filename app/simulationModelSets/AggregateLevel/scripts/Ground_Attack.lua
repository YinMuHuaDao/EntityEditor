-- AGGREGATE bomb run:
-- Moves an aggregate air unit to a target location, releases bombs and 
-- flies away.
-- 
-- This task uses Indirect Fire HE weapons, i.e. weapons from the 
-- "Indirect-Fire-Power" state property that have Damage-Type "High-Explosive."
-- It uses the Limited_Munition_Attack task to carry out the engagement 
-- portion of the task, with the Instantaneous parameter set true if 
-- seconds-per-attack is below a threshold, and the IsIndirect parameter
-- always set to true.

-- Set to true to print more detail to debug console
DEBUG_DETAIL = true

-- Time between attacks with different ammo categories,
-- in seconds
REATTACK_TIME =	30  

-- The threshold time for Seconds-Per-Attack, below which the
-- attack is considered to be instantaneous.
INSTANTANEOUS_ATTACK_TIME = 1.0

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"
FSM = require "fsm2"

taskFSM = FSM.new()
taskId = -1
attackingWeapon = nil
timeOfNextAttack = -1
fsmState = nil -- This will save/restore FSM state when a scenario is saved and loaded.
local allIFWeapons = this:getStateProperty("Indirect-Fire-Power")
local ammoByCategory = this:getStateProperty("Ammunition-Categories")

-- Task Parameters Available in Script
--  taskParameters.targetPoint Type: SimObject - Target point for bombs
--  taskParameters.ingressRoute Type: SimObject - Route to fly to target area
--  taskParameters.egressRoute Type: SimObject - Route to fly away from target (before RTB)


-------------- Utility functions --------------------------------------------

-- Wrapper for testing for task complete. If there is an error,
-- the main task will be ended.
function isActionComplete(task)
   return task == -1 or taskDone(task, true)
end
-- Wrapper for a the constant True.
-- Note the fsm predicate functions take one argument.
function trueFn (dummy)
	return true
end
-- See if the user specified an ingress route
function isIngressRouteValid(dummy)
	return taskParameters.ingressRoute ~= nil and
		taskParameters.ingressRoute:isValid()
end
-- See if the user specified an egress route
function isEgressRouteValid(dummy)
	return taskParameters.egressRoute ~= nil and
		taskParameters.egressRoute:isValid()
end

-- Returns 0 (for forward) or 1 (for reverse) based on which end of the route is closer to the
-- startLocation specified.  It is assumed that the entity will start at the closer end of the route.
function routeTraverseDirection(route, startLocation)
	if (not route:isValid()) then
		return 0
	end
	
	local routePoints = route:getLocations3D()
	local startDist = startLocation:distanceToLocation3D(routePoints[1])
	local endDist = startLocation:distanceToLocation3D(routePoints[#routePoints])
	if (startDist < endDist) then
		return 0
	else
		return 1
	end
end

-- Common function that starts a fly-to-target subtask.
-- Sets taskId as a side effect.
function startFlyToTarget(dummy)
   taskId = vrf:startSubtask("move-to-location", 
      {aiming_point = taskParameters.targetPoint:getLocation3D()})
end
-- Function determines if there are additional weapons
-- with which to attack. 
-- These are indirect-fire-power items of category HE.
-- Returns a boolean value that is true if a weapon is found;
-- sets attackingWeapon as a side effect.
-- Also returns a second boolean value that is true if
-- at least one HE weapon is unavailable because of posture.
function hasMoreIFHEWeapons(dummy)
   -- Refresh ammoByCategory to get latest ammo count
   ammoByCategory = this:getStateProperty("Ammunition-Categories")
	local weapon
	local weaponInfo
	local foundWeapon = false
   local wrongPosture = false
   attackingWeapon = nil
   if allIFWeapons ~= nil and 
      ammoByCategory ~= nil then
      
      local myPosture = this:getStateProperty("Posture")
      for weapon, weaponInfo in pairs(allIFWeapons) do
         if DEBUG_DETAIL then
            printDebug("Checking ammo for weapon ", weapon)
         end
         if weaponInfo["Damage-Type"] == "High-Explosive" then
            if DEBUG_DETAIL then printDebug("...HE type") end
            
            -- For weapon system ammo, weapon name and category are the same
            local ammoStatus = ammoByCategory[weapon]
            if ammoStatus ~= nil then
               local ammoLeft = ammoStatus.Count
               if ammoLeft >= weaponInfo["Ammunition-Per-Attack"] then
                  if postureAllowsWeaponUse(weaponInfo, myPosture) then
                  
                     attackingWeapon = weapon
                     foundWeapon = true
                     if DEBUG_DETAIL then
                        printDebug(string.format("Found %d ammo; using weapon %s",
                           ammoLeft, attackingWeapon))
                     end
                     break
                  else
                     wrongPosture = true
                     printInfo(vrf:trUtf8(
                        "Posture does not allow use of a ground attack weapon %1"):
                        arg(weapon))
                  end
               end
            end
         end
      end
   end
	return foundWeapon, wrongPosture
end

-- Start a ground attack-- a "limited munition attack".
-- Uses attackingWeapon. Launches as many attacks as the 
-- available ammo will allow.
-- Sets taskId as a side effect.
function startNextAttack(dummy)
	local attacksAvail = 0
   local ammoLeft = 0
	if allIFWeapons ~= nil and ammoByCategory ~= nil 
      and attackingWeapon ~= nil then
      
      -- For weapon system ammo, weapon name and category are the same
		local weaponAmmo = ammoByCategory[attackingWeapon]
		if weaponAmmo ~= nil then
			ammoLeft = weaponAmmo.Count
         local weaponInfo = allIFWeapons[attackingWeapon]
         if weaponInfo ~= nil then
            local ammoPerAttack = weaponInfo["Ammunition-Per-Attack"]
            if ammoPerAttack > 0 then
               if ammoLeft >= ammoPerAttack then
                  attacksAvail = math.modf(ammoLeft/ ammoPerAttack)
               end	
            end
         end
		end
	end
	if attacksAvail > 0 then	
      if DEBUG_DETAIL then
         printDebug(string.format("Starting %d attack(s) with weapon %s",
            attacksAvail, attackingWeapon))
         printDebug(string.format(".  Duration per attack %.1f seconds",
            allIFWeapons[attackingWeapon]["Seconds-Per-Attack"]))
      end
      local groundLoc = taskParameters.targetPoint:getLocation3D()
      local terrainAltitude = vrf:getTerrainAltitude(groundLoc:getLat(),
         groundLoc:getLon())
      groundLoc:setAlt(terrainAltitude)
		taskId = vrf:startSubtask("Limited_Munition_Attack",
			{NumberOfAttacks = attacksAvail,
			 TargetLocation = groundLoc,
			 Weapon = attackingWeapon,
			 CheckRange = false, -- Attacker should be at target location
			 Instantaneous = allIFWeapons[attackingWeapon]["Seconds-Per-Attack"] <= 
            INSTANTANEOUS_ATTACK_TIME,
          IsIndirect = true})
   else
      printWarn(vrf:trUtf8("Error: not enough ammo for attack?"))
      printWarn(vrf:trUtf8("(Ammo %1 , amount left: %2)"):
         arg(attackingWeapon):arg(ammoLeft))
      taskId = -1
	end
end
			 
--*********************************************************************
--  FSM definition
--
-- In this FSM, we will use the ID of the running subtask as the 
-- argument to the tick and predicate functions.
--*********************************************************************
-- Define the states. All have null tick functions.
taskFSM:addTickFunctions({
   {"start", nil},
   {"flyingIngress", nil}, --Fly along ingress route, if it exists
   {"flyingToTarget", nil}, -- Fly to target location
   {"attacking", nil},     --Attack target with available HE munition
   {"reattacking", nil},   --Waiting to attack with additional HE munition
   {"flyingEgress", nil},  -- Fly away along egress route
   {"done", nil}
   }
)
-------------- Start state --------------------------------------------

taskFSM:addTransition("start", 
	isIngressRouteValid, 
	"flyingIngress", 
	function (dummy)
		local direction = routeTraverseDirection(taskParameters.ingressRoute, this:getLocation3D())
		taskId = vrf:startSubtask("move-along", 
			{route = taskParameters.ingressRoute,
			 start_at_closest_point = true,
			 traversal_direction = direction})
	end
)
taskFSM:addTransition("start",
   function (dummy)
      return taskParameters.targetPoint:isValid()
   end,
	"flyingToTarget",
	startFlyToTarget
)   
taskFSM:addTransition("start", 
	trueFn, 
   "done",
	function (dummy) 
		if DEBUG_DETAIL then
			printDebug("No target point; ending task.")
		end
		vrf:endTask(true)
	end
)
-------------- Flying Ingress state -----------------------------------
taskFSM:addTransition("flyingIngress", 
   function (dummy)
      return isActionComplete(taskId) and
         taskParameters.targetPoint:isValid()
   end,
	"flyingToTarget",
	startFlyToTarget
)
-------------- Flying to Target state ---------------------------------
taskFSM:addTransition("flyingToTarget", 
	function(task) 
		return isActionComplete(task) and
		       hasMoreIFHEWeapons(nil)
	end,
	"attacking",
	startNextAttack
)
taskFSM:addTransition("flyingToTarget",
	function (task)
		return isActionComplete(task) and
			isEgressRouteValid(nil)
	end,
	"flyingEgress",
	function (dummy)
		if DEBUG_DETAIL then
			printDebug("No HE weapons; starting egress.")
		end
		-- If ingress and egress are the same route, then reverse direction when egressing.
		local direction = routeTraverseDirection(taskParameters.egressRoute, this:getLocation3D())
		taskId = vrf:startSubtask("move-along", 
			{route = taskParameters.egressRoute,
			 start_at_closest_point = true,
			 traversal_direction = direction})
	end
)
taskFSM:addTransition("flyingToTarget",
	isActionComplete,
	"done",
	function (dummy) 
		if DEBUG_DETAIL then
			printDebug("No HE weapons; no route; ending task.")
		end
		vrf:endTask(true)
	end
)
-------------- Attacking state ----------------------------------------
taskFSM:addTransition("attacking", 
	function (task)
		return isActionComplete(task) and
			   hasMoreIFHEWeapons(nil)
	end,
	"reattacking",
	function (dummy)
		timeOfNextAttack = vrf:getSimulationTime() + REATTACK_TIME
		if DEBUG_DETAIL then
			printDebug("Time of next attack: ", timeOfNextAttack)
		end
	end
)
taskFSM:addTransition("attacking",
	function (task)
		return isActionComplete(task) and
			isEgressRouteValid(nil)
	end,
	"flyingEgress",
	function (dummy)
		if DEBUG_DETAIL then
			printDebug("No more HE weapons; starting egress.")
		end
		-- If ingress and egress are the same route, then reverse direction when egressing.
		local direction = routeTraverseDirection(taskParameters.egressRoute, this:getLocation3D())
		taskId = vrf:startSubtask("move-along", 
			{route = taskParameters.egressRoute,
			 start_at_closest_point = true,
			 traversal_direction = direction})
	end
)
taskFSM:addTransition("attacking",
	isActionComplete,
	"done",
	function (dummy) 
		if DEBUG_DETAIL then
			printDebug("No more HE weapons; no route; ending task.")
		end
		vrf:endTask(true)
	end
)
------------- Preparing to reattack state ---------------------------
taskFSM:addTransition("reattacking",
	function (dummy)
		return vrf:getSimulationTime() > timeOfNextAttack
	end,
	"attacking",
	startNextAttack
)
------------- Flying egress route ----------------------------------
taskFSM:addTransition("flyingEgress",
	isActionComplete,
	"done",
	function (dummy) 
		if DEBUG_DETAIL then
			printDebug("At end of egress route; ending task.")
		end
		vrf:endTask(true)
	end
)
--****************************************************************************

-- Called when the task first starts. Never called again.
function init()
	if DEBUG_DETAIL then
      printDebug("Initializing Ground Attack task")
   end
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(1.0)
   local hasWeapon
   local wrongPosture
   hasWeapon, wrongPosture = hasMoreIFHEWeapons(nil)
   if not hasWeapon then
      printWarn(vrf:trUtf8("Ground Attack: No weapons available."))
      if wrongPosture then
         printWarn(vrf:trUtf8(".  Weapon unavailable because unit is not in the correct posture."))
      end
      vrf:endTask(false)
   end
   
   if this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Ground Attack: Cannot attack while embarked."))
      vrf:endTask(false)
   end
end

-- Called each tick while this task is active.
function tick()
	if DEBUG_DETAIL then
		printDebug(string.format("\n%.3f: Ticking; state %s",
			vrf:getSimulationTime(), taskFSM:get()))
	end
	taskFSM:tick(taskId)
	if DEBUG_DETAIL then
		printDebug("Finished tick in state ", taskFSM:get())
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
function saveState()
	fsmState = taskFSM:get()
end

-- Called immediately after a scenario checkpoint is loaded in which
-- this task is active.
function loadState()
	taskFSM:set(fsmState)
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
