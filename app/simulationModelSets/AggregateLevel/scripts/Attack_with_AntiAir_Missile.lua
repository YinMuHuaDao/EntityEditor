-- Attack with AntiAir Missiles
--
-- This script finds the first weapon system on the
-- entity that fires anti-air munitions and attacks the 
-- target. The target must be an air aggregate
-- The weapon system selected must have the range and ceiling
-- to attack the target, and the entity must be in a tactical posture
-- that allows use of the weapon system.
--
-- This script will start a limited-munition-attack task
-- for each missile that is to be launched. Each one
-- is an instantaneous attack, and each is started
-- as soon as the previous one is complete. Multiple-missile
-- attacks are implemented as multiple limited-munition-attacks
-- so that they each resolve independently for P(hit).

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Set to true to print more detail to debug console
DEBUG_DETAIL = false

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
attackingWeapon = ""
attackSubtaskId = -1
attacksRemaining = taskParameters.numMissiles

local allIFWeapons = this:getStateProperty("Indirect-Fire-Power")
local ammoByCategory = this:getStateProperty("Ammunition-Categories")

-- Task Parameters Available in Script
--  taskParameters.targetEntity Type: SimObject
--  taskParameters.numMissiles Type: Integer

function hasAmmo(weaponName)
   local result = false
   -- For weapon system ammo, weapon name and category are the same
   local ammoStatus = ammoByCategory[weaponName]
   if ammoStatus ~= nil then
      if ammoStatus.Count >= 1 then
         result = true
      end
   end
   return result
end

function inRange(weaponInfo, targetRange, targetAlt)
   local result = false
   if weaponInfo ~= nil then
      local maxRange = weaponInfo["Range"]
      local maxAltitude = weaponInfo["Max-Altitude"]
      if maxRange ~= nil and 
         maxAltitude ~= nil then
         
         if targetRange <= maxRange 
            and targetAlt <= maxAltitude then
            
            result = true
         end
      else
         printWarn(vrf:trUtf8("Attack with anti-air: can't get range/altitude for weapon %1"):
            arg(weaponName))
      end
   end
   return result
end

-- Called when the task first starts. Never called again.
function init()
   if DEBUG_DETAIL then
      printDebug("Starting attack-with-AntiAir missile init function")
   end
   if allIFWeapons == nil or
      ammoByCategory == nil then
      
      printWarn(vrf:trUtf8("Error: Attack with Anti-Air: Parameter table(s) nil"))
      vrf:endTask(false)
      
   elseif taskParameters.targetEntity == this then
      printWarn(vrf:trUtf8("Error: Attack with Anti-Air: cannot target self"))
      vrf:endTask(false)
   elseif not taskParameters.targetEntity:isValid() then
      printWarn(vrf:trUtf8("Error: Attack with Anti-Air: no target selected"))
      vrf:endTask(false)   
    -- Make sure the target is an air aggregate
   elseif not vrf:entityTypeMatches(taskParameters.targetEntity:getEntityType(),
      EntityType.AggregateAir()) then
      
      printWarn(vrf:trUtf8("Error: Attack with Anti-Air: Target is not aggregate air"))
      vrf:endTask(false)
   elseif this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Attack with Anti-Air: Cannot attack while embarked."))
      vrf:endTask(false)
   else
      vrf:setTickPeriod(2.0)
      local targetLoc = taskParameters.targetEntity:getLocation3D()
      local rangeToTarget = this:getLocation3D():distanceToLocation3D(targetLoc)
      local targetAlt = targetLoc:getAlt()
      
      local weapon = ""
      local weaponInfo = nil
      local foundWeapon = false
      local wrongPosture = nil
      local rangeTooShort = nil
      local noAmmo = nil
      local myPosture = this:getStateProperty("Posture")
      
      -- Look through all the weapons in the IF-Power table.
      -- Consider the anti-air weapons. Check that the target is within
      -- range and ceiling of the weapon.
      -- Check that the unit is in an allowed posture to use the weapon.
      for weapon, weaponInfo in pairs(allIFWeapons) do
         if DEBUG_DETAIL then
            printDebug("Considering weapon ", weapon)
         end
         
         if string.find(string.lower(weapon), "missile") and
            weaponInfo["Damage-Type"] == "Anti-Air" then
            if DEBUG_DETAIL then printDebug("...Anti-Air type, missile") end
            if hasAmmo(weapon) then
               if inRange(weaponInfo, rangeToTarget, targetAlt) then               
                  if postureAllowsWeaponUse(weaponInfo, myPosture) then
                    attackingWeapon = weapon
                    foundWeapon = true
                    if DEBUG_DETAIL then
                      printDebug(string.format("Weapon %s found for attack, ammo %d",
                        attackingWeapon, ammoLeft))
                    end
                    break
                  else
                    -- If a weapon can't be used because of posture, warn the user
                    wrongPosture = weapon
                  end
               else
                  rangeTooShort = weapon
               end
            else
               noAmmo = weapon
            end
         end
      end
      if not foundWeapon then
         printWarn(vrf:trUtf8("Cannot fire. Possible reasons include: no appropriate weapon system, out of ammunition, target out of range."))
         if noAmmo ~= nil then
            printWarn(vrf:trUtf8("  (Weapon %1 has no ammo.)"):arg(noAmmo))
         end
         if rangeTooShort ~= nil then
            printWarn(vrf:trUtf8("  (Weapon %1 does not have the range and ceiling to reach the target.)"):
               arg(rangeTooShort))
         end
         if wrongPosture then
            printWarn(vrf:trUtf8("  (Weapon %1 cannot be used in the current posture.)"):arg(wrongPosture))
         end
         vrf:endTask(false)
      end
   end
end

-- Called each tick while this task is active.
function tick()
   if attackSubtaskId == -1 then
      
     -- Start indirect fire subtask
      attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
         {NumberOfAttacks=1, 
          TargetEntity=taskParameters.targetEntity,
          Weapon=attackingWeapon,
          CheckRange=true,
          Instantaneous=true,
          IsIndirect = false})
      attacksRemaining = attacksRemaining - 1
      if DEBUG_DETAIL then
         printDebug("Attack-with-AntiAir is launching a missile")
      end
      
   elseif vrf:isSubtaskComplete(attackSubtaskId) then
      if attacksRemaining > 0 and
         vrf:subtaskResult(attackSubtaskId) then
         
        -- Start indirect fire subtask
         attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
            {NumberOfAttacks=1, 
             TargetEntity=taskParameters.targetEntity,
             Weapon=attackingWeapon,
             CheckRange=true,
             Instantaneous=true,
             IsIndirect = false})
         attacksRemaining = attacksRemaining - 1
         if DEBUG_DETAIL then
            printDebug("Attack-with-AntiAir is launching a missile")
         end
      else
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
