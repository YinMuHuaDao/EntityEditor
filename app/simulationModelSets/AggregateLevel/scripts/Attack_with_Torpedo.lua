-- Attack with Torpedoes
-- This script is almost identical to attack with anti-ship missile,
-- but it uses weapons with "torpedo" in their name, and can
-- attack submarines.
--
-- This script will start a limited-munition-attack task
-- for each torpedo that is to be launched. Each one
-- is an instantaneous attack, and each is started
-- as soon as the previous one is complete. Multiple-torpedo
-- attacks are implemented as multiple limited-munition-attacks
-- so that they each resolve independently for P(hit).
-- Torpedo attacks are not "indirect" attacks, so it is
-- possible to configure a ship such that the torpedo combat 
-- effect is different for different sectors.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Set to true to print more detail to debug console
DEBUG_DETAIL = true

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
attackingWeapon = ""
attackSubtaskId = -1
attacksRemaining = taskParameters.numTorpedoes

-- Task Parameters Available in Script
--  taskParameters.targetShip Type: SimObject
--  taskParameters.numTorpedoes Type: Integer

local allIFWeapons = this:getStateProperty("Indirect-Fire-Power")
local ammoByCategory = this:getStateProperty("Ammunition-Categories")

function hasAmmo(weaponName)
   local result = false
   -- For weapon system ammo, weapon name and category are the same
   local ammoStatus = ammoByCategory[weaponName]
   if ammoStatus ~= nil then
      if ammoStatus.Count >= 1 then
         result = true
      end
   else
      printDebug("No ammo with category %s", weaponName)
      for ammoCatName, ammoCatInfo in pairs(ammoByCategory) do
         printDebug("__ %s", ammoCatName)
      end
   end
   return result
end

function inRange(weaponInfo, targetRange)
   local result = false
   if weaponInfo ~= nil then
      local maxRange = weaponInfo["Range"]
      if maxRange ~= nil then
         if targetRange <= maxRange then

            result = true
          end
      else
         printWarn("Attack with Torpedo: can't get range for weapon ",
            weaponName)
      end
   end
   return result
end

-- Called when the task first starts. Never called again.
function init()
   if DEBUG_DETAIL then
      printDebug("Starting attack-with-torpedo init function")
   end
   if allIFWeapons == nil or
      ammoByCategory == nil then
      
      printWarn(vrf:trUtf8("Error: Attack with Torpedo: Parameter table(s) nil"))
      vrf:endTask(false)
   elseif taskParameters.targetShip == this then
      printWarn("Error: Attack with Torpedo: cannot target self")
      vrf:endTask(false)
   elseif not taskParameters.targetShip:isValid() then
      printWarn("Error: Attack with Torpedo: no target selected")
      vrf:endTask(false)   
   elseif not (vrf:entityTypeMatches(taskParameters.targetShip:getEntityType(), EntityType.AggregateSurface())
               or vrf:entityTypeMatches(taskParameters.targetShip:getEntityType(), EntityType.AggregateSubsurface())) then

      printWarn("Error: Attack with Torpedo: Target is not aggregate surface")
      vrf:endTask(false)
   elseif this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Attack with Torpedo: Cannot attack while embarked."))
      vrf:endTask(false)
   else
      vrf:setTickPeriod(2.0)
      local targetLoc = taskParameters.targetShip:getLocation3D()
      local rangeToTarget = this:getLocation3D():distanceToLocation3D(targetLoc)
      local weapon = ""
      local weaponInfo = nil
      local foundWeapon = false
      local wrongPosture = false
      local myPosture = this:getStateProperty("Posture")

      for weapon, weaponInfo in pairs(allIFWeapons) do
         if DEBUG_DETAIL then
            printDebug("Considering weapon ", weapon)
         end
         if string.find(string.lower(weapon), "torpedo") and
            weaponInfo["Damage-Type"] == "Anti-Ship" then
            if DEBUG_DETAIL then printDebug("...anti-ship type, torpedo") end

            if hasAmmo(weapon) and
               inRange(weaponInfo, rangeToTarget) then

               if postureAllowsWeaponUse(weaponInfo, myPosture) then
                  attackingWeapon = weapon
                  foundWeapon = true
                  if DEBUG_DETAIL then
                     printDebug(string.format("Weapon %s found for attack.", attackingWeapon))
                  end
                  break
               else
                  -- If a weapon can't be used just because of posture, warn the user
                  wrongPosture = true
               end
            end
         end
      end
      if not foundWeapon then
         printWarn("No anti-surface weapons available that can engage target.")
         if wrongPosture then
            printWarn("At least one anti-ship torpedo cannot be used in the current posture.")
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
          TargetEntity=taskParameters.targetShip,
          Weapon=attackingWeapon,
          CheckRange=true,
          Instantaneous=true,
          IsIndirect = false,
	  LosRequired = true})
      attacksRemaining = attacksRemaining - 1
      if DEBUG_DETAIL then
         printDebug("Attack-with-torpedo is launching a torpedo")
      end

   elseif vrf:isSubtaskComplete(attackSubtaskId) then
      if attacksRemaining > 0 and
         vrf:subtaskResult(attackSubtaskId) then

        -- Start indirect fire subtask
         attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
            {NumberOfAttacks=1, 
             TargetEntity=taskParameters.targetShip,
             Weapon=attackingWeapon,
             CheckRange=true,
             Instantaneous=true,
             IsIndirect = false,
	     LosRequired = true})
         attacksRemaining = attacksRemaining - 1
         if DEBUG_DETAIL then
            printDebug("Attack-with-torpedo is launching a torpedo")
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
