-- The Limited_Munition_Attack script executes limited duration attacks,
-- which include finite-time artillery fire missions and single-munition
-- attacks (such as bomb releases and missile launches).
-- It is not invoked by a user from the GUI directly, but is called by
-- other tasks that set the parameters based on the type of attack.
-- This script sends the actual interaction to the target entities.
--

-- Set to true to dump details to the entity debug console.
local DEBUG_DETAIL = true

-- The fraction of attack strenght to apply to collateral targets in
-- the blast radius when attacking a particular target entity
local COLLATERAL_FRACTION = 0.3

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded

-- The name of the Influence interaction used for combat
local indirectFireInfluenceName = "Engagement.IndirectFire"
timeRemaining = -1
selectedPower = nil
damagePerSecond = 0 -- This is used for "attack damage" for instantaneous attacks
ammunitionPerSecond = 0
requiredAmmunition = 0
hitFactor = AG_NOT_APPLICABLE
maxRange = 0
blastRadius = 0
effectRadius = 0 -- Max of blast radius and sheaf radius
prevEntitiesAffected = {}
previousUpdateTime = -1
prevNumAffected = 0
ammunitionCategoryName = ""
usingTargetArea = false
usingTargetEntity = false

-- Task Parameters Available in Script
-- NOTE: Only one of TargetArea or TargetLocation should be used. TargetArea used if both are set.
--  taskParameters.TargetArea Type: SimObject - The area to target for the indirect fire attack
--  taskParameters.TargetLocation Type: Location3D - The location to target for the indirect fire attack
--  taskParameters.NumberOfAttacks Type: integer - The number of attacks to perform
--  taskParameters.Weapon Type: string - The name of the indirect fire weapon to use
--  taskParameters.CheckRange Type: boolean - Do not perform attack if target is not in range
--  taskParameters.Instantaneous Type: boolean - Start the attack and immediately quit task
--  taskParameters.IsIndirect Type: boolean - Influence type is Indirect Fire; the attack will not be 
--                                      affected by what sector the target is being attacked from.
--  taskParameters.TargetEntity Type: SimObject - the entity to target. Has priority over Location and Area if 
--                                      multiple parameters are valid.
--  taskParameters.SheafRadius Type: real - The radius of the burst pattern that the fire mission uses.
--                                Not used with TargetArea.
--  taskParameters.LosRequired Type: boolean - Indicates an attack requires line of site to the target.


local targetName = nil
if taskParameters.TargetEntity:isValid() then
   targetName = taskParameters.TargetEntity:getUUID()
end

-- Compute the modifier to the munition hit factor based on how much
-- this (firing) entity is being jammed.
-- The ratio (in [0, inf]) of attack to defense is passed through log & sigmoid
-- functions to produce a result in [0.0, 1.0]. If attack = defense,
-- the result is 0.5. If attack >> defense, the value returned is near 0.
-- If defense < 1, it is set to 1.
function computeEwEffect(attack, defense)
   if defense == nil then
      return 1.0
   end
   defense = math.max(defense, 1.0)
   attack = math.max(attack, 0.0)
   
   local ratio = attack/defense
   -- Square the ratio. This happens to be an exponent that
   -- will result in about a 1% change in modifier for a 1%
   -- change in ratio, when the ratio is near 1.0; 
   -- e.g. a ratio of 1.01 results in a modifier
   -- of about 0.495. 
   ratio = ratio * ratio

   return 1.0/(1.0 + ratio)
end  

-- Called when the task first starts. Never called again.
-- Sets global variables.
function init()

   if this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Limited Munition Attack: Cannot attack while embarked."))
      vrf:endTask(false)
   else
      local defaultTickTime = 3
      if(taskParameters.Instantaneous) then
         -- Tick as soon as we can for instantaneous attacks
         defaultTickTime = 0
      end
      
      -- Set the tick period for this script.
      vrf:setTickPeriod(defaultTickTime)
      
      -- Initialize variables
      if taskParameters.IsIndirect then
         indirectFireInfluenceName = "Engagement.IndirectFire"
      else
         indirectFireInfluenceName = "Engagement"
      end
      
      previousUpdateTime = -1
      selectedPower = this:getStatePropertyMapItem("Indirect-Fire-Power",
         taskParameters.Weapon)
         
      if(selectedPower ~= nil) then
      
         maxRange = selectedPower["Range"]
         
         -- Get target location and set flags for target parameter usage
         --
         local targetLoc = taskParameters.TargetLocation
         if taskParameters.TargetEntity:isValid() then
            usingTargetEntity = true
            targetLoc = taskParameters.TargetEntity:getLocation3D()
         elseif taskParameters.TargetArea:isValid() then
            usingTargetArea = true
            targetLoc = taskParameters.TargetArea:getLocation3D()
         end
         
         -- If the target is out of range, end task and return
         --
         if taskParameters.CheckRange then
            if this:getLocation3D():distanceToLocation3D(targetLoc) > maxRange then
            
               printWarn(vrf:trUtf8(
                  "Selected target location is not within range of weapon %1"):
                  arg(taskParameters.Weapon))
               selectedPower = nil
               vrf:endTask(false)
               return
                  
            elseif usingTargetArea then
               -- Check the boundary vertices as well
               local verts, i, loc
               verts = taskParameters.TargetArea:getLocations3D()
               for i, loc in pairs(verts) do
                  if this:getLocation3D():distanceToLocation3D(loc) > maxRange then
                     printWarn(vrf:trUtf8(
                        "Part of target area is not within range of weapon %1"):
                        arg(taskParameters.Weapon))
                     selectedPower = nil
                     vrf:endTask(false)
                     return
                  end
               end
            end
         end
         
         -- If there is no LOS to target, end task and return
         --
         if taskParameters.LosRequired then
            local hasLos
            local validTerrainData
            hasLos, validTerrainData = this:hasLosToLocation(targetLoc)
            
            if not validTerrainData then
               -- Try again next tick. Don't give up yet!
               return
            elseif not hasLos then
               printWarn(vrf:trUtf8(
                  "Cannot fire %1 at target location, blocked by terrain"):arg(taskParameters.Weapon))
               selectedPower = nil
               vrf:endTask(false)
               return
            end
         end
			
         requiredAmmunition = selectedPower["Ammunition-Per-Attack"] * 
            taskParameters.NumberOfAttacks
            
         -- An instantaneous attack means all attacks occur simultaneously and the
         -- unit immediately finishes the task
         if(taskParameters.Instantaneous) then
            timeRemaining = 0.0
            damagePerSecond = selectedPower["Strength-Per-Attack"] * 
               taskParameters.NumberOfAttacks
            taskParameters.NumberOfAttacks = 1
         else
            local attackDuration = selectedPower["Seconds-Per-Attack"]
            damagePerSecond = selectedPower["Strength-Per-Attack"] /
               attackDuration     
            timeRemaining = attackDuration * taskParameters.NumberOfAttacks            
            ammunitionPerSecond = selectedPower["Ammunition-Per-Attack"] /
               attackDuration
         end
         
         hitFactor = selectedPower["Hit-Factor"]
         
         -- Check for radar jamming
         local jamRcv = this:getStateProperty("Radar-Jamming-Strength-Receiving")
         if jamRcv ~= nil and 
            jamRcv > 0 and
            selectedPower["Can-Be-Radar-Jammed"] then
            
            local ewModifier = computeEwEffect(jamRcv, 
               selectedPower["Jamming-Defense-Factor"])
            
            hitFactor = hitFactor * ewModifier
            if DEBUG_DETAIL then
               printDebug(string.format(".   Jam strength %f, defense %f, modifier %f;",
                  jamRcv, selectedPower["Jamming-Defense-Factor"], ewModifier))
               printDebug(".   Net hit factor ", hitFactor)
            end
         end
            
         blastRadius = selectedPower["Radius"]
         local maxRadius = selectedPower["Max-Sheaf-Radius"]
         effectRadius = taskParameters.SheafRadius;
         if  effectRadius > maxRadius then
            printInfo(vrf:trUtf8("Given sheaf radius is greater than max allowed for weapon. Setting to %1."):
               arg(maxRadius))
            effectRadius = maxRadius
         end
         if blastRadius > effectRadius then
            printInfo(vrf:trUtf8("Given sheaf radius is less than blast radius for weapon. Setting to %1."):
               arg(blastRadius))
            effectRadius = blastRadius
         end
         
          -- Adjust tick time
         local tickRate = selectedPower["Seconds-Per-Attack"]/2
         if(defaultTickTime > tickRate) then
            vrf:setTickPeriod(tickRate)
         end            
         
         -- Make sure we have enough ammunition. Get current amounts from Ammunition-Categories.
         -- For weapon system ammo, weapon name and category are the same.
         local ammunitionLeft = 0
            
         ammunitionCategoryName = taskParameters.Weapon
   
         local ammoCatInfo = this:getStatePropertyMapItem("Ammunition-Categories",
            ammunitionCategoryName)
         if(ammoCatInfo ~= nil) then       
            -- This conversion to int, with the special test for <1, mimics
            -- the computation of ammo quantities in Use_Supplies.lua.
            -- Important for large munitions where <1 may be a common case.
            if (ammoCatInfo.Count < 1) then
               ammunitionLeft = math.ceil(ammoCatInfo.Count)
            else
               -- Report only whole integer values
               ammunitionLeft = roundToInt(ammoCatInfo.Count)
            end
         end
         
         if DEBUG_DETAIL then
            printDebug(string.format(
               "Doing %.0f attacks, %.0f rounds per attack. %s has %.0f ammo available.",
               taskParameters.NumberOfAttacks, selectedPower["Ammunition-Per-Attack"], 
               ammunitionCategoryName, ammunitionLeft))
         end
         if(ammunitionLeft < requiredAmmunition) then
            printWarn(vrf:trUtf8("Not enough ammunition for selected weapon %1"):arg(taskParameters.Weapon))
            selectedPower = nil
         end
      else
         printWarn("Unable to find data for weapon system: ", 
            taskParameters.weapon)
         vrf:endTask(false)
      end
   end
end

function footprintTouchesRadius(entity, location)
   if(entity:isAggregate()) then
   
      local entityLoc = entity:getLocation3D()
      local entRadius = entity:getStateProperty("Physical-Footprint")
      if entRadius == nil and DEBUG_DETAIL then
         printDebug(".   Checking for proximity of entity ", entity:getName())
         return false
      end
      local entLocAtAlt = Location3D(entityLoc:getLat(), entityLoc:getLon(),
         location:getAlt())
      local horizDist = location:distanceToLocation3D(entLocAtAlt) - entRadius
      horizDist = math.max(horizDist, 0)
      local vertDist = math.abs(entityLoc:getAlt() - location:getAlt())
      local distance = horizDist + vertDist
      if DEBUG_DETAIL then      
         printDebug(string.format("checking %s; distance to detonation %.1f (altitude diff %.1f), effect radius %.1f",
            entity:getName(), 
            distance, vertDist, effectRadius))
      end   
      -- Make sure we are within the blast radius.
      return (distance <= effectRadius)
   end

   return false
end

function isInArea(entity, area)

   if(entity:isAggregate()) then
      local entityLoc = entity:getLocation3D()
      local footprint = entity:getStateProperty("Physical-Footprint")
      
      -- Make sure we are within the blast radius, altitude-wise.
      -- Assume the area is on the ground.
      -- If no blast radius set, don't factor in.
      local isInBlastRadius = true
      local entityAGL = 0
      if blastRadius > 0 then
         entityAGL = entity:getHeightAboveTerrain()
         isInBlastRadius = entityAGL <= blastRadius
      end
      if not isInBlastRadius then
         if DEBUG_DETAIL then
            printDebug(string.format("  Ent. %s not in altitude range of blast; ent. alt %.1f; rad. %.1f",
               entity:getName(), entityAGL, blastRadius))
         end
         return false
      end
      
      if (footprint == nil) then
      
         -- Object has no footprint. Just do a point check
         local isInRange = (not taskParameters.CheckRange) or 
            (this:getLocation3D():distanceToLocation3D(entityLoc) < maxRange)
         if (area:isPointInside(entityLoc) and isInRange) then
            if DEBUG_DETAIL then
               printDebug(string.format("   Ent. %s point location is in tgt area",
                  entity:getName()))
            end
            return true
         elseif DEBUG_DETAIL then
            printDebug(string.format("   Ent. %s point location is not in tgt area",
                  entity:getName()))
         end
      else
         -- Object has a footprint. Need to check if any point in its footprint
         -- is within range and in the area.
         if ((not taskParameters.CheckRange) or 
            (this:getLocation3D():distanceToLocation3D(entityLoc) < (maxRange + footprint))) then
            
            if(area:isPointInside(entityLoc)) then
               if DEBUG_DETAIL then
                  printDebug(string.format("  Ent. %s center is in range and in area",
                     entity:getName()))
               end
               return true
            elseif(entityLoc:distanceToLocation3D(area:getLocation3D()) <= footprint) then
               if DEBUG_DETAIL then
                  printDebug(string.format("  Ent. %s center is in range and footprint contains area",
                     entity:getName()))
               end
               return true
            else
               local vecToArea = entityLoc:vectorToLoc3D(area:getLocation3D())
               
               local scaledVector = vecToArea:getUnit():getScaled(footprint)
               local closestPoint = entityLoc:addVector3D(scaledVector) 
               if(area:isPointInside(closestPoint)) then
                  if DEBUG_DETAIL then
                     printDebug(string.format(
                        "  Ent. %s center is in range and footprint is in area",
                        entity:getName()))
                  end
                  return true
               end
               
            end
         end
      end
   end
   if DEBUG_DETAIL then
      printDebug(string.format("  Ent. %s does not overlap tgt area",
         entity:getName()))
   end
   return false
end

-- Sends an engagement Influence interaction
function sendEngagement(target, combatType, strength, duration, hitFactor, loc, stop)

   local influenceParams = { 
      InfluenceType = combatType,
      Strength = strength,
      Duration = duration,
      HitFactor = hitFactor,
      Location = loc,
      StopInfluence = stop,
      ProbabilityKilled = 1,
      ProbabilityCaptured = 0,
      ProbabilityWounded = 0 }
   vrf:sendInfluence(target, indirectFireInfluenceName, influenceParams)   
   if DEBUG_DETAIL then
      printDebug("Sending IF influence to target ", target:getName(),
         " with type ", combatType, 
         ", duration ", duration, 
         " and strength ", strength)
   end

end

-- Called each tick while this task is active.
function tick()
   
   if(selectedPower == nil) then
      vrf:endTask(true)
      return
   end
   
   if(not taskParameters.Instantaneous and
      timeRemaining <= 0) then      
      -- All over
      vrf:endTask(true)
      
   else    
      local timeDiff = 0
      local currentTime = vrf:getSimulationTime()
      if not taskParameters.Instantaneous then
      
         -- Calculate time remaining
         if(previousUpdateTime < 0) then
            previousUpdateTime = currentTime
         end
         timeDiff = currentTime - previousUpdateTime
         if(timeDiff > timeRemaining) then
            timeDiff = timeRemaining
         end
         timeRemaining = timeRemaining - timeDiff
      end  -- else timeRemaining is 0.0, set in init
      if DEBUG_DETAIL then 
         printDebug(string.format(
            "\n%.3f Lim. Mun. attack, %.1f seconds (remaining)",
            vrf:getSimulationTime(), timeRemaining))
      end
      
      -- Use ammunition
      local haveEnoughAmmo = false
      local ammunitionLeft = 0
      local ammoCatInfo = this:getStatePropertyMapItem("Ammunition-Categories",
         ammunitionCategoryName)
      if(ammoCatInfo ~= nil) then
         ammunitionLeft = ammoCatInfo.Count
         
         -- For instantaneous attacks, use all ammo right now
         if(taskParameters.Instantaneous) then
            ammunitionLeft = ammoCatInfo.Count - requiredAmmunition
            haveEnoughAmmo = true
         else
            ammunitionLeft = ammoCatInfo.Count - (ammunitionPerSecond * timeDiff)
            haveEnoughAmmo = ammunitionLeft >= 0
         end
      end

      local entitiesAffected = {}
      local numAffected = 0
         
      -- If we have no ammo left, no entities are affected.
      if(haveEnoughAmmo) then
      
         -- The attack will go through; update ammo left
         ammunitionLeft = math.max(0, ammunitionLeft)
         
         ammoCatInfo.Count = ammunitionLeft
            
         this:setStatePropertyMapItem("Ammunition-Categories", 
            ammunitionCategoryName, ammoCatInfo)  
         if ammunitionLeft == 0 then
            printWarn(vrf:trUtf8("This attack depletes ammo %1"):arg(ammunitionCategoryName))
         end
         
         -- Check if attacks need to be updated              
         local targetLoc =  taskParameters.TargetLocation
         if usingTargetEntity then
         
            if taskParameters.TargetEntity:isValid() then
            
               targetLoc = taskParameters.TargetEntity:getLocation3D()
            else
               -- Entity is no longer present. Stop attack.
               vrf:endTask(true)
            end
         
         else
         
            if usingTargetArea then
               if taskParameters.TargetArea:isValid() then
                  targetLoc = taskParameters.TargetArea:getLocation3D()
               else
                  -- Area is no longer present. Stop attack.
                  vrf:endTask(true)
                  -- Continue below, in order to send stop-engagement influences
                  -- to any entities that had been undergoing attack.
               end
            end
         end
         -- Get entities within range...but since this function looks
         -- at center location and we want to impact entities whose
         -- footprint is touched, add 1km as a conservative unit footprint.
         local entities = vrf:getSimObjectsNear(
            this:getLocation3D(), selectedPower["Range"] + 1000)
            --targetLoc, this:getLocation3D():distanceToLocation3D(targetLoc))

         -- Look for other entities affected
         for entityNum, entity in pairs(entities) do
            local isAffected = false
            
            -- Ignore this, and the target entity
            if entity ~= this and
               not entity:isDisaggregatedUnit() and
               not (taskParameters.TargetEntity:isValid() and
                    taskParameters.TargetEntity == entity) then
                    
               if(taskParameters.TargetArea:isValid()) then
                  isAffected = isInArea(entity, taskParameters.TargetArea)
               else
                  isAffected = footprintTouchesRadius(entity, targetLoc)
               end
               
               if(isAffected) then               
                  -- Add to list
                  entitiesAffected[entity:getUUID()] = entity
                  numAffected = numAffected + 1
                  if DEBUG_DETAIL then
                     printDebug("Unit ", entity:getName(),
                        " in range and blast radius.")
                  end
               end
            end
         end
         
         if taskParameters.TargetEntity:isValid() then
            -- If this attack is targeted at an entity, attack it
            -- with full strength, and collateral targets at a fraction
            
            if prevEntitiesAffected[targetName] == nil then
               sendEngagement(taskParameters.TargetEntity, selectedPower["Damage-Type"],
                  damagePerSecond, timeRemaining, hitFactor, 
                  targetLoc, false)
               if DEBUG_DETAIL then
                  printDebug("Sending new engagement to ", taskParameters.TargetEntity:getName())
               end
               
               this:setStatePropertyListItem("Limited-Munition-Attacks", 
                  { Target = taskParameters.TargetEntity,
                    Weapon = taskParameters.Weapon }, 
                  { Target = taskParameters.TargetEntity,
                    Weapon = taskParameters.Weapon,
                    Strength = damagePerSecond})
            end
            local damagePerEntity = damagePerSecond * COLLATERAL_FRACTION
            for entityName,entity in pairs(entitiesAffected) do   
               if prevEntitiesAffected[entityName] == nil then
               
                  sendEngagement(entity, selectedPower["Damage-Type"],
                     damagePerEntity, timeRemaining, hitFactor, 
                     targetLoc, false)
                  if DEBUG_DETAIL then
                     printDebug("Sending new engagement to ", entityName)
                  end
               
                  this:setStatePropertyListItem("Limited-Munition-Attacks", 
                     { Target = entity,
                       Weapon = taskParameters.Weapon }, 
                     { Target = entity,
                       Weapon = taskParameters.Weapon,
                       Strength = damagePerEntity})
               end
                  
               -- Reduce the prevEntitiesAffected list to just the obsolete ones
               prevEntitiesAffected[entityName] = nil         
            end
            -- Add the target in the list so we know next time it has already
            -- received an influence.
            entitiesAffected[targetName] = taskParameters.TargetEntity
            
         else
            local damagePerEntity =  damagePerSecond
            
            if usingTargetArea then
               -- If this is an attack on an area, split strength between targets, 
               -- assuming that a forward observer is directing fire to 
               -- multiple places.
            
               if(numAffected > 1) then
                  damagePerEntity = damagePerSecond / numAffected
                  if DEBUG_DETAIL then
                     printDebug("Fire strength modified by factor of ", 
                        1/numAffected, " because of multiple targets.")
                  end
               end
            else
               -- If this is an attack on a target point, reduce the strength by
               -- the fraction of the sheaf area that one blast covers. Effect
               -- is the same on all targets.
               
               local coverageFraction = 1
               if taskParameters.SheafRadius > blastRadius  and
                  taskParameters.SheafRadius > 0.0 then
                  
                  coverageFraction = blastRadius / taskParameters.SheafRadius
                     -- That's the radius ratio, now get the area ratio:
                  coverageFraction = coverageFraction * coverageFraction
               end
               
               damagePerEntity = damagePerSecond * coverageFraction
               if DEBUG_DETAIL and coverageFraction < 1.0 then
                  printDebug("Fire strength modified by factor of ",
                     coverageFraction, " because sheaf area > blast radius")
               end                        
            end
         
            for entityName,entity in pairs(entitiesAffected) do   
               if(prevEntitiesAffected[entityName] == nil or 
                  numAffected ~= prevNumAffected) then
               
                  -- This entity needs to know it's being affected
                  sendEngagement(entity, selectedPower["Damage-Type"],
                     damagePerEntity, timeRemaining, hitFactor, 
                     targetLoc, false)
                  if DEBUG_DETAIL then
                     printDebug("Sending new/update engagement to ", entityName)
                  end
                  
                  this:setStatePropertyListItem("Limited-Munition-Attacks", 
                     { Target = entity,
                       Weapon = taskParameters.Weapon }, 
                     { Target = entity,
                       Weapon = taskParameters.Weapon,
                       Strength = damagePerEntity})
               end
                  
               -- Reduce the prevEntitiesAffected list to just the obsolete ones
               prevEntitiesAffected[entityName] = nil         
            end
         end
      else
         if DEBUG_DETAIL then 
            printDebug("...Not enough ammo to continue attack.")
         end
      end
      
      -- For non-instantaneous attacks, we need to look at entities which were
      -- affected before but no longer are as well as setting up the list of
      -- affected entities for next tick.
      if(not taskParameters.Instantaneous) then
         for entityName,entity in pairs(prevEntitiesAffected) do   
         
            -- This entity is no longer being affected
            sendEngagement(entity, selectedPower["Damage-Type"],
               0, 0, 0, targetLoc, true)
               
            this:setStatePropertyListItem("Limited-Munition-Attacks", 
               { Target = entity,
                 Weapon = taskParameters.Weapon }, 
               nil)
         end
         
         prevNumAffected = 0
         prevEntitiesAffected = {}
         for entityName,entity in pairs(entitiesAffected) do 
            prevNumAffected = prevNumAffected + 1
            prevEntitiesAffected[entityName] = entity
         end
         previousUpdateTime = currentTime
      end
   end

   -- Task was instantaneous. Just exit.
   if(taskParameters.Instantaneous) then
      vrf:endTask(true)
   end
end

-- Clears the "Limited-Munition-Attacks" state property of any attacks
-- that use this weapon.
function clearLimitedMunitionAttacks()

   local indicesToClear = {}
   local ltdMunAttacks = this:getStateProperty("Limited-Munition-Attacks")
   local isUpdated = false
   if ltdMunAttacks ~= nil then
      for attackIndex, attack in ipairs(ltdMunAttacks) do
         if attack.Weapon == taskParameters.Weapon then
            table.insert(indicesToClear, attackIndex)
         end
      end
   end
   
   for i, attackIndex in ipairs(indicesToClear) do
      ltdMunAttacks[attackIndex] = nil
      isUpdated = true
   end
   
   if isUpdated then
      this:setStateProperty("Limited-Munition-Attacks", ltdMunAttacks)
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
   clearLimitedMunitionAttacks()
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
