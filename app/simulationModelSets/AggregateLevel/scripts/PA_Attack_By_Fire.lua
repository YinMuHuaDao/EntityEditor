-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

local MECH_TYPE = "11:1:-1:-1:4:-1:-1"
local ARMOR_TYPE = "11:1:-1:-1:2:-1:-1"
local ARTILLERY_TYPE = "11:1:-1:-1:7:-1:-1"
local SP_ARTILLERY_TYPE = "11:1:-1:-1:8:-1:-1"

local INITIAL_STATE = "initial"
local APPROACH_STATE = "approach"
local MOVE_TO_POS_STATE = "move-to-pos"
local ACQUIRE_TARGETS_STATE = "acquire-targets"
local ATTACK_STATE = "attacking"
local ATTACK_COMPLETE_STATE = "attack-complete"

local TARGET_AREA_RADIUS = 3000

state = INITIAL_STATE
approachSubtask = -1
moveToTasks = {}
attackTasks = {}

frontLineUnits = {}
artilleryUnits = {}
otherUnits = {}

ineffectiveUnits = {}

frontLineUnitRadius = 0
artilleryUnitRadius = 0
otherUnitRadius = 0

local AS_FAST_AS_POSSIBLE = 999999
maxSpeed = AS_FAST_AS_POSSIBLE

-- Task Parameters Available in Script
--  taskParameters.TargetLocation Type: Location3D - Location of targets
--  taskParameters.AttackByFireLocation Type: Location3D - Location from which attack should be launched

function resetUnitLists()

   frontLineUnits = {}
   artilleryUnits = {}
   otherUnits = {}
   frontLineUnitRadius = 0
   artilleryUnitRadius = 0
   otherUnitRadius = 0

   -- Organize units according to type
   local subordinates = this:getSubordinates(true)
   for subIndex, subordinate in pairs( subordinates ) do
      local subordinateType = subordinate:getEntityType()
      local fp = subordinate:getStateProperty("Physical-Footprint")
   
      if vrf:entityTypeMatches(MECH_TYPE, subordinateType) or
         vrf:entityTypeMatches(ARMOR_TYPE, subordinateType) then
         table.insert(frontLineUnits, subordinate)
         
         if fp ~= nil and fp > frontLineUnitRadius then
            frontLineUnitRadius = fp
         end
         
      elseif vrf:entityTypeMatches(ARTILLERY_TYPE, subordinateType) or
         vrf:entityTypeMatches(SP_ARTILLERY_TYPE, subordinateType) then
         table.insert(artilleryUnits, subordinate)
         
         if fp ~= nil and fp > artilleryUnitRadius then
            artilleryUnitRadius = fp
         end
         
      else
         table.insert(otherUnits, subordinate)
         
         if fp ~= nil and fp > otherUnitRadius then
            otherUnitRadius = fp
         end
         
      end
      
   end
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(2)

   resetUnitLists()
end

function approachAttackByFireLocation()

   -- We want the units to move at the same speed.
   local subordinates = this:getSubordinates(true)
   local newMaxSpeed = AS_FAST_AS_POSSIBLE
   for subIndex, subordinate in pairs( subordinates ) do
      local speed = subordinate:getParameter("max-speed")      
      local mod = subordinate:getStateProperty("MaximumSpeedModifier")
      local adj = subordinate:getStateProperty("MaximumSpeedAdjustment")
      if mod ~= nil then
         speed = speed * mod
      end
      if adj ~= nil then
         speed = speed - adj
      end
      
      if speed < newMaxSpeed then
         newMaxSpeed = speed
      end
   end
      
   if newMaxSpeed ~= maxSpeed then
      maxSpeed = newMaxSpeed
      
      for subIndex, subordinate in pairs( subordinates ) do
         vrf:sendSetData(subordinate, "set-speed", {speed = maxSpeed})
      end
   end
   
   if approachSubtask == -1 then
      -- Start a new task to move the units closer to the attack position
      
      -- First find location to move to.  Choosing a point just on the edge of the final
      -- attack formation.
      local distance = frontLineUnitRadius * 3 + artilleryUnitRadius * 2 + otherUnitRadius * 2
      
      if this:getLocation3D():distanceToLocation3D(taskParameters.AttackByFireLocation) < distance then
         -- We are already close enough to get into position.
         return MOVE_TO_POS_STATE
         
      else
         -- Need to move to a closer location.
         local vectorFromAttackLoc = 
            taskParameters.AttackByFireLocation:vectorToLoc3D(this:getLocation3D())
         vectorFromAttackLoc = vectorFromAttackLoc:getUnit()
         vectorFromAttackLoc = vectorFromAttackLoc:getScaled(distance)
         local approachPoint = 
            taskParameters.AttackByFireLocation:addVector3D(vectorFromAttackLoc)
         approachSubtask = vrf:startSubtask("PA_Move_To_Location_Direct",
            {location = approachPoint})
            
      end
      
   elseif vrf:isSubtaskComplete(approachSubtask) then
      -- Approach is complete, move units into position
      approachSubtask = -1
      return MOVE_TO_POS_STATE
      
   end
   
   return APPROACH_STATE
   
end

function moveIntoPosition()

   if next(moveToTasks) == nil then
      -- Task each subordinate into position
      
      -- Book it!
      local subordinates = this:getSubordinates(true)
      for subIndex, subordinate in pairs( subordinates ) do
         vrf:sendSetData(subordinate, "set-speed", {speed = AS_FAST_AS_POSSIBLE})
      end
      
      -- Make sure our list of units hasn't changed.
      resetUnitLists()
      
      -- Widths of each level in formation. We will have three levels:
      -- front line (tanks, mechs)
      -- middle (other)
      -- rear (artillery)
      local frontLineWidth = #frontLineUnits * frontLineUnitRadius * 2
      local midLineWidth = #otherUnits * otherUnitRadius * 2
      local rearLineWidth = #artilleryUnits * artilleryUnitRadius * 2
      
      -- Get unit vector from attack point to target.
      local attackVector = 
         taskParameters.AttackByFireLocation:vectorToLoc3D(taskParameters.TargetLocation)
      attackVector = attackVector:getUnit()
      
      -------------- FRONT LINE
      -- Get mid-point for first line. Backup attack loc by radius.
      local frontLineMidPoint = taskParameters.AttackByFireLocation:addVector3D(
         attackVector:getScaled(-1 * frontLineUnitRadius))
         
      -- Get left-most front line loc.
      local leftSideVec = attackVector:getScaled(frontLineWidth/2 - frontLineUnitRadius)
      leftSideVec:setBearingInclRange(leftSideVec:getBearing() - (math.pi * 0.5),
         leftSideVec:getInclination(), leftSideVec:getRange())
      local leftmostLoc = frontLineMidPoint:addVector3D(leftSideVec)
      local vecToNextLoc =
         leftmostLoc:vectorToLoc3D(frontLineMidPoint):getUnit():getScaled(frontLineUnitRadius * 2)
      
      -- Order each front line unit into pos.
      local posIter = 0
      for unitIndex, unit in pairs(frontLineUnits) do
         local pos = leftmostLoc:addVector3D(vecToNextLoc:getScaled(posIter))
         vrf:sendSetData(unit, "set-speed", {speed = AS_FAST_AS_POSSIBLE})
         moveToTasks[unit:getUUID()] = vrf:sendTask(unit, "move-to-location", {aiming_point = pos})         
         posIter = posIter + 1         
      end
      
      -------------- SECOND LINE
      -- Get mid-point for second line. Backup front line loc by radius of units.
      local midLineMidPoint = frontLineMidPoint:addVector3D(
         attackVector:getScaled(-1 * (frontLineUnitRadius + otherUnitRadius)))
         
      -- Get left-most second line loc.      
      leftSideVec = attackVector:getScaled(midLineWidth/2 - otherUnitRadius)
      leftSideVec:setBearingInclRange(leftSideVec:getBearing() - (math.pi * 0.5),
         leftSideVec:getInclination(), leftSideVec:getRange())
      leftmostLoc = midLineMidPoint:addVector3D(leftSideVec)
      vecToNextLoc =
         leftmostLoc:vectorToLoc3D(midLineMidPoint):getUnit():getScaled(otherUnitRadius * 2)
      
      -- Order each second line unit into pos.
      posIter = 0
      for unitIndex, unit in pairs(otherUnits) do
         local pos = leftmostLoc:addVector3D(vecToNextLoc:getScaled(posIter))
         vrf:sendSetData(unit, "set-speed", {speed = AS_FAST_AS_POSSIBLE})      
         moveToTasks[unit:getUUID()] = vrf:sendTask(unit, "move-to-location", {aiming_point = pos})         
         posIter = posIter + 1         
      end
      
      -------------- REAR LINE
      -- Get mid-point for rear line. Backup second line loc by radius of units.
      local rearLineMidPoint = midLineMidPoint:addVector3D(
         attackVector:getScaled(-1 * (otherUnitRadius + artilleryUnitRadius)))
         
      -- Get left-most second line loc.
      leftSideVec = attackVector:getScaled(rearLineWidth/2 - artilleryUnitRadius)
      leftSideVec:setBearingInclRange(leftSideVec:getBearing() - (math.pi * 0.5),
         leftSideVec:getInclination(), leftSideVec:getRange())
      leftmostLoc = rearLineMidPoint:addVector3D(leftSideVec)
      vecToNextLoc =
         leftmostLoc:vectorToLoc3D(rearLineMidPoint):getUnit():getScaled(artilleryUnitRadius * 2)
      
      -- Order each second line unit into pos.
      posIter = 0
      for unitIndex, unit in pairs(artilleryUnits) do
         local pos = leftmostLoc:addVector3D(vecToNextLoc:getScaled(posIter))
         vrf:sendSetData(unit, "set-speed", {speed = AS_FAST_AS_POSSIBLE})
         moveToTasks[unit:getUUID()] = vrf:sendTask(unit, "move-to-location", {aiming_point = pos})         
         posIter = posIter + 1
      end
      
   else
      -- Check if all units are in position
      local tasksComplete = true
      
      for unitName, task in pairs( moveToTasks ) do
         local unit = vrf:getSimObjectByUUID(unitName)
         if unit ~= nil and unit:isValid() then
            
            if not vrf:isTaskComplete(task) and
               unit:getDamageState() ~= "destroyed" then
               tasksComplete = false
            end
         end
      end
      
      if tasksComplete then
         -- Units in position, look for targets
         moveToTasks = {}
         return ACQUIRE_TARGETS_STATE
      end
      
   end
   
   return MOVE_TO_POS_STATE
   
end

function acquireTargets()
   -- Check to see if any units have discovered enemies in the target area
   
   -- Pseudo-aggs can't tell what sensor contacts their subordinates have, so just go to attack
   return ATTACK_STATE
end

function attackTargets()

   local targetEnemies = {}
   
   local entitiesInArea = 
      vrf:getSimObjectsNear(taskParameters.TargetLocation, TARGET_AREA_RADIUS)
      
   for entityIndex, entity in pairs(entitiesInArea) do
      if entity:getForceType() ~= this:getForceType() and
         vrf:entityTypeMatches(EntityType.AggregateGround(), entity:getEntityType()) and
         entity:getDamageState() ~= "destroyed" then
         
         table.insert(targetEnemies, entity)
      end
   end
   
   if next(targetEnemies) == nil then
      -- No enemies in target area
      return ATTACK_COMPLETE_STATE
   else
   
      -- Make sure our list of units hasn't changed.
      resetUnitLists()
      
      -- Find the untasked artillery
      local untaskedArtillery = {}
      for unitIndex, unit in pairs(artilleryUnits) do
      
         local ce = unit:getStateProperty("Combat-Effectiveness")
         if ce ~= nil and 
            ce ~= "Not Operational" and 
            unit:getDamageState() ~= "destroyed" and
            not ineffectiveUnits[unit:getUUID()] then
      
            if attackTasks[unit:getUUID()] == nil or
               vrf:isTaskComplete(attackTasks[unit:getUUID()]) then
               
               untaskedArtillery[unit:getUUID()] = unit
            end
            
         end
      end
      
      for unitName, unit in pairs(untaskedArtillery) do
      
         -- Clear out completed tasks.
         attackTasks[unitName] = nil
         
         -- Task units to fire at new enemy. Pick an enemy at random.
         local firstTargetOption = math.random(#targetEnemies)
         local targetOption = firstTargetOption
         local ifWeapons = unit:getStateProperty("Indirect-Fire-Power")
         local chosenWeapon = nil
         local chosenWeaponName = ""
         local chosenTarget = nil
         
         repeat
            
            local distToTarget = 
               unit:getLocation3D():distanceToLocation3D(targetEnemies[targetOption]:getLocation3D())
            for weaponName, weapon in pairs(ifWeapons) do
               if weapon["Damage-Type"] == "High-Explosive" and
                  distToTarget < weapon["Range"] then
                  
                  chosenWeapon = weapon
                  chosenWeaponName = weaponName
                  break
               end
            end
            
            if chosenWeapon ~= nil then
               chosenTarget = targetEnemies[targetOption]
               break
            end
         
            targetOption = targetOption + 1
            if targetOption > #targetEnemies then targetOption = 0 end
         until targetOption == firstTargetOption
         
         if chosenTarget == nil or chosenWeapon == nil then
            ineffectiveUnits[unitName] = true
         else
            attackTasks[unitName] = vrf:sendTask(unit, "Indirect_Fire", 
               {TargetPoint = chosenTarget,
                 SheafRadius = chosenWeapon["Radius"],
                 NumberOfAttacks = 3,
                 Weapon = chosenWeaponName})
         end
      end
      
      
   end
   
   return ATTACK_STATE
end

-- Called each tick while this task is active.
function tick()
   
   if state == INITIAL_STATE then
      state = APPROACH_STATE
      
   elseif state == APPROACH_STATE then
      state = approachAttackByFireLocation()
      
   elseif state == MOVE_TO_POS_STATE then
      state = moveIntoPosition()
      
   elseif state == ACQUIRE_TARGETS_STATE then
      state = acquireTargets()
      
   elseif state == ATTACK_STATE then      
      state = attackTargets()
      
   elseif state == ATTACK_COMPLETE_STATE then
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
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
