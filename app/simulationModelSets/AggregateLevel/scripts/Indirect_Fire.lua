-- This script implements an indirect fire task, i.e. for artillery.
-- The attack may be directed at a point, with a desired sheaf (burst pattern)
-- radius, or at an area. When directed at an area, the intent is that this
-- is an engagement area within which specific targets are attacked, 
-- and that a notional forward observer would direct different attacks
-- on the targets--thus splitting the effects of the artillery. 
-- (See implementation in Limited Munition Attack.)
--
-- This IF task can only take place if 
-- - The unit has ammunition of the specified type
-- - The unit is not embarked
-- - The unit is not moving
-- - The unit is in a posture that allows use of the weapon
-- - The ammo is HE ammunition
-- - The target is in range.


-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded
attackSubtaskId = -1

-- Task Parameters Available in Script
--  taskParameters.TargetPoint Type: SimObject - The aim point for the fire mission
--  taskParameters.SheafRadius Type: number (real) - The radius of the burst pattern of the mission
--  taskParameters.NumberOfAttacks Type: integer - The number of attacks to perform
--  taskParameters.Weapon Type: string - The name of the indirect fire ammo to use
--  taskParameters.TargetArea Type: SimObject - The area to target for the indirect fire attack

-- Note-- TargetArea is no longer used in the task dialog; it is retained here to support
-- legacy tasks that might start Indirect_Fire as a subtask and use TargetArea.

usingTargetArea = false -- True if target area parameter is valid (priority over point)

-- Called when the task first starts. Never called again.
function init()

   -- Set the tick period for this script.
   vrf:setTickPeriod(3)
   
   if this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Indirect Fire: Cannot attack while embarked."))
      vrf:endTask(false)
   elseif this:getSpeed() > 0.1 and
      this:getEntityType() == EntityType.AggregateGround() then
      printWarn(vrf:trUtf8("Indirect Fire: Cannot attack while moving."))
	  vrf:endTask(false)
   else
      local weaponInfo = this:getStatePropertyMapItem("Indirect-Fire-Power",
         taskParameters.Weapon)
		local currentPosture = this:getStateProperty("Posture")
      if weaponInfo == nil then
         printWarn(vrf:trUtf8("Indirect fire: Unit has no indirect fire weapon named %1."):arg(taskParameters.Weapon))
         vrf:endTask(false)
      elseif weaponInfo["Damage-Type"] ~= "High-Explosive" then
         printWarn(vrf:trUtf8("Indirect fire: Bad ammo; must fire High Explosive munition."))
         vrf:endTask(false)
		elseif not postureAllowsWeaponUse(weaponInfo, currentPosture) then
			-- Not in a valid posture
			printWarn(vrf:trUtf8("Indirect fire for weapon %1 not allowed in posture %2."):
				arg(taskParameters.Weapon):arg(currentPosture))
			vrf:endTask(false)
		elseif this:getSpeed() > 0 then
			printWarn(vrf:trUtf8("Indirect fire not allowed while entity is moving."))
			vrf:endTask(false)	
		else
			usingTargetArea = taskParameters.TargetArea ~= nil and
									taskParameters.TargetArea:isValid()
			if not usingTargetArea and
				not taskParameters.TargetPoint:isValid() then
				
					printWarn(vrf:trUtf8("Indirect fire: no valid target point."))
					vrf:endTask(false)
			else
					
				-- Check range
				
				local maxRange = weaponInfo["Range"]
				local targetLoc
				if usingTargetArea then
					targetLoc = taskParameters.TargetArea:getLocation3D()
				else
					targetLoc = taskParameters.TargetPoint:getLocation3D()
				end
				if this:getLocation3D():distanceToLocation3D(targetLoc) > maxRange then
				
					printWarn(vrf:trUtf8(
						"Selected target location is not within range of weapon %1; aborting IF task."):
						arg(taskParameters.Weapon))
					vrf:endTask(false)
				elseif usingTargetArea then
					-- Check the boundary vertices as well
					local verts, i, loc
					verts = taskParameters.TargetArea:getLocations3D()
					for i, loc in pairs(verts) do
						if this:getLocation3D():distanceToLocation3D(loc) > maxRange then
							printWarn(vrf:trUtf8(
								"Part of target area is not within range of weapon %1; aborting IF task."):
								arg(taskParameters.Weapon))
							vrf:endTask(false)
							break
						end
					end
				end
			end	
		end
   end
   
end

-- Called each tick while this task is active.
function tick()
   
   if(attackSubtaskId == -1) then
	
		local targetLocation
		if taskParameters.TargetArea ~= nil and
			taskParameters.TargetArea:isValid() then
			
			-- Start indirect fire subtask-- into area
			attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
				{NumberOfAttacks=taskParameters.NumberOfAttacks, 
				 TargetArea=taskParameters.TargetArea,
				 Weapon=taskParameters.Weapon,
				 CheckRange = true,
				 IsIndirect = true})
      
		elseif taskParameters.TargetPoint ~= nil and
			taskParameters.TargetPoint:isValid() then
			
			-- Start indirect fire, onto TRP, with sheaf radius
			targetLocation = taskParameters.TargetPoint:getLocation3D()
			
			attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
				{NumberOfAttacks=taskParameters.NumberOfAttacks, 
				 TargetLocation=targetLocation,
				 Weapon=taskParameters.Weapon,
				 SheafRadius = taskParameters.SheafRadius,
				 CheckRange = true,
				 IsIndirect = true})
      
		else
			vrf:endTask(false)
			return
		end
      
      
   elseif(vrf:isSubtaskComplete(attackSubtaskId)) then
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
