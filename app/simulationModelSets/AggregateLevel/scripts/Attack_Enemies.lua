-- This script finds all possible targets for direct fire attack and
-- generates the interactions to attack them. It runs automatically 
-- in the background.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

--Dump detailed information about what is going on.
DEBUG_DETAIL = true

-- To dump indirect powers table. (This table isn't used in Attack Enemies.)
DEBUG_IF_POWERS = false

-- Evaluation inverval, in seconds
TICK_PERIOD = 30

-- The maximum number of targets a unit can engage at once,
-- if none are preferred (in state properties)
MAX_TARGETS = 3

-- The name of the Influence interaction used for combat
local combatInfluenceName = "Engagement"

-- parameter-data storage. This data is static, so it can be stored at init time.
local baseHealth = this:getParameterProperty("Base-Health")
local baseCombatPower = this:getParameterProperty("Base-Combat-Power")
local ifMoraleLessThan = this:getParameterProperty("If-Morale-Less-Than")
local moraleModifyCombatPower = this:getParameterProperty("Attack-Strength-Morale-Modifier")
local combatSectorMod = this:getParameterProperty("Combat-Sector-Modifier")
local combatPostureMod = this:getParameterProperty("Combat-Posture-Modifier")
local combatDetLevelMod = this:getParameterProperty("Combat-Detection-Level-Modifier")
local combatMoppMod = this:getParameterProperty("Combat-MOPP-Level-Modifier")
local rangePostureMod = this:getParameterProperty("Range-Posture-Modifier")
local postureSectorSize = this:getParameterProperty("Posture-Sector-Size")
local casualtyTypeProbs = this:getParameterProperty("Casualty-Type-Probabilities")
local illuminationIntensityModifier = this:getParameterProperty("Combat-Power-Illumination-Intensity-Modifier")
local precipitationIntensityModifier = this:getParameterProperty("Combat-Power-Precipitation-Intensity-Modifier")
local baseEWDependence = this:getParameterProperty("Base-Comms-Dependence")

-- Can be set to force all attacks to be resent during the next tick.
-- Primarily used after scenario load to force all attacks to immediately resume.
local resendAllAttacks = false

-- Comparison values stored from previous tick
previousPosture = "-"
previousHealth = -1
previousMopp = -1
previousEnv = -1
previousMorale = -1
previousEW = -1

-- For printing init info--gives the user a chance to set
-- notify level to debug, which they don't get when
-- init() is run
firstTick = true

-- Called to retrieve the value specified. If error is true then the value will not be set
function setValueIfPresent(valueToSet, attributeName)
   local val, errorCode = vrf:getScriptAttribute(attributeName)
   
   if (not errorCode) then
      return val
   end
   
   return valueToSet
end

--Used to force a state property update when Set Restore is called.
forceUpdate = false;

function postSetRestore()

   forceUpdate = true;
   calculatePreTickDerivedProperties();
   forceUpdate = false;

end

-- Called when the task first starts. Never called again.
function init()

   -- Set the tick period for this script.
   vrf:setTickPeriod(setValueIfPresent(TICK_PERIOD, "Tick-Period"))
   
   -- Register interest in new sensor information. This will cause
   -- the next tick time to be called in response to new sensor
   -- contacts, or contacts with new information.
   vrf:setRespondToNewSensorContacts(true);

   --Set combat power when entity is first created.
   calculatePreTickDerivedProperties();
   
   --Need to respond to set posture and set restore by updating combat power.
   vrf:addPostSetDataCallback("set-state-properties", "calculatePreTickDerivedProperties");
   --calculatePreTickDerivedProperties won't update unless health or posture has changed,
   --so force an update when doing restore.
   vrf:addPostSetDataCallback("set-restore", "postSetRestore");
   
end

-- Called when the a saved scenario is loaded.
function loadState()

   -- Set the initial tick period for this script. Start it low so we resend the
   -- current attacks quickly.
   vrf:setTickPeriod(0.1)
   resendAllAttacks = true
   
   -- Register interest in new sensor information. This will cause
   -- the next tick time to be called in response to new sensor
   -- contacts, or contacts with new information.
   vrf:setRespondToNewSensorContacts(true);
end

function sendEngagement(target, combatType, strength, hitFactor, stop)

   if DEBUG_DETAIL then
      printDebug(string.format("Sending influence: target %s, type %s, str %.1f, stop = %s", 
         target:getName(), combatType, strength, tostring(stop)))
   end
   
   local influenceParams = { 
      InfluenceType = combatType,
      Strength = strength,
      Duration = AG_NOT_APPLICABLE,
      HitFactor = hitFactor,
      Location = target:getLocation3D(),
      StopInfluence = stop,
      ProbabilityKilled = casualtyTypeProbs.Killed,
      ProbabilityCaptured = casualtyTypeProbs.Captured,
      ProbabilityWounded = casualtyTypeProbs.Wounded }
   vrf:sendInfluence(target, combatInfluenceName, influenceParams)	
         
end

-- Stop all existing attacks
function stopAllAttacks()

   local clearProperty = false
   local currentAttacks = this:getStateProperty("Attacks")
   
   -- Loop through our current attacks. Stop them.
   for attackIndex,attack in pairs(currentAttacks) do
   
      clearProperty = true
      local target = vrf:getSimObjectByUUID(attack.Target)
      
      if(target:isValid()) then
         --  Valid attack, stop it.
         sendEngagement(target, attack.Type, attack.Strength, 
            AG_NOT_APPLICABLE, true)
      end      
            
   end   
   
   -- Some attacks were stopped
   if(clearProperty) then
      this:setStateProperty("Attacks", {})
   end
   
end

--Determines a modifier based on the illumination at the entity (target)
function illuminationEffect(entity)
   local modifier = 1
   
   -- The closer to 0 the illumination the more the modifier will take effect
   if (illuminationIntensityModifier > 0) then
      illumination = vrf:getIllumination(entity)
      modifier = 1.0 - (1.0 - illuminationIntensityModifier) * (1.0 - illumination)
   end
   return modifier
end


-- Returns a table of targets and combat types with a base combat strength for each.
-- Targets are chosen based on the amount of damage we can cause to them, with
-- preference always given to preferred targets specified by the user.
function findTargets(currentLoc, combatPowerList, whenFiredUpon)

   local targetList = {}

   -- If this entity is embarked it can't attack
   if(this:getEmbarkedOn():isValid()) then
      return targetList
   end
   
   -- Get all hostile contacts. Would like to do a range based lookup, but we need to
   -- factor in each entity's physical footprint.
   local entities = this:getAllHostileContacts()
   
   ---------- QUIT IF THERE ARE NO CONTACTS
   if next(entities) == nil then 
      return targetList
   end
   ----------
   
   local attackingEnemies = {}
   
   if(whenFiredUpon) then
      -- Make a list of entities who are attacking us.
      local currentAttacksDefending = this:getStateProperty("Attacks-Defending")
      for attackIndex,attack in pairs(currentAttacksDefending) do
         attackingEnemies[attack.Attacker] = true
      end
   end

   -- Find remaining ammo
   local ammunition = this:getStateProperty("Ammunition-Categories")
   
   -- Loop through each combat power and weed out the ineffective ones
   local effectiveCombatPowers = {}
   for combatType,combatPower in pairs(combatPowerList) do
   
      if combatPower.Strength > 0 then
         local ammoLeft = 0
         local ammoAmt = ammunition[combatType]
         if ammoAmt ~= nil then ammoLeft = ammoAmt.Count end
         
         if ammoLeft > 0 then
            -- This combat power can actually do some damage
            effectiveCombatPowers[combatType] = combatPower
         else
            if DEBUG_DETAIL then    
               printDebug("  No ammo for ", combatType)
            end
         end
      end
   end
   
   -- Get sector sizes
   local sectors = this:getStateProperty("Sector-Sizes")
   
   -- Get list of preferred targets. Convert to be indexed by target name.
   local preferredTargets = {}
   local preferredTargetList = this:getStateProperty("Preferred-Targets")
   if preferredTargetList ~= nil then
      for indexNum,prefTargetName in pairs(preferredTargetList) do
         preferredTargets[prefTargetName] = true
      end
   end
   
   -- List of "effective" strength against current chosen targets. Used in target selection.
   -- We will prefer enemies we are more effective against unless others are specified
   -- as preferred targets.
   local effectiveCombatStrengths = {}
   
   local hasPreferredTarget = false
   local targetCount = 0
   local myAlt = currentLoc:getAlt()
   
   -- Loop through entities and determine which ones should be targeted
   for entityNum,entity in pairs(entities) do
      
      local entityID = entity:getUUID()
      
      -- If we have a preferred target, this
      -- entity must also be a preferred target to even receive consideration
      local isCurrentPreferred = (preferredTargets[entityID] ~= nil)
      if( isCurrentPreferred or not hasPreferredTarget ) then
          
         -- Make sure this is a valid target
         if( entity:isAggregate() and (not entity:getEmbarkedOn():isValid()) and
             ((not whenFiredUpon) or attackingEnemies[entityID]) and
             entity:getForceType() ~= this:getForceType() and
             entity:getStateProperty("Health") > 0) then
            
            local entityFp = entity:getStateProperty("Physical-Footprint")
            
            if(entityFp ~= nil) then
               local entityLoc = entity:getLocation3D()
               local distance = 
                  math.max(0, currentLoc:distanceToLocation3D(entityLoc) - entityFp)
               local heightAbove = math.max(entityLoc:getAlt() - myAlt, 0)   
                     
               local currentTargetEffectiveCombatStrength = 0
               local currentTargetInfo = {}
                  
               -- This will become true if any combat power has the range and strength
               -- to attack the target.
               local effectiveTarget = false
               
               -- Loop through each combat power and see if this is a viable target for that power
               for combatType,combatPower in pairs(effectiveCombatPowers) do
                  
                  -- Make sure it's in range
                  if combatPower.Range > distance and
                     -- If shooting up, make sure that target is below weapon ceiling
                     heightAbove < combatPower.Range/2 then
                   
                     -- Only bother attacking if we think we can do damage
                     local vulnToAttack = entity:getStatePropertyMapItem("Vulnerability",
                        combatType)
                     if(vulnToAttack ~= nil and vulnToAttack.Vulnerability > 0) then
                
                        -- Determine which sector they are in
                        local sector = getSector(this, entityLoc, sectors)
                        
                        -- Determine detection level
                        local detectionLevel = 0
                        local contactInfo = this:getContactInfo(entity)
                        if(contactInfo ~= nil) then
                           detectionLevel = contactInfo.detectionLevel
                        end
                        
                        -- Attenuate combat power as distance approaches max range,
                        -- or height difference approaches max ceiling
                        local rangeRatio = distance/combatPower.Range
                        local altRatio = heightAbove * 2/combatPower.Range
                        local rangeModifier = 1.0
                        -- Use a power of ratio to make combat power fall off slowly
                        -- at first, then more quickly as ratio approaches 1.
                        if rangeRatio > altRatio then
                           rangeModifier = 1/(1 + rangeRatio * rangeRatio)
                        else
                           rangeModifier = 1/(1 + altRatio * altRatio)
                        end
					 
                        local illumModifier = illuminationEffect(entity)
                        
                        local currentCombatStrength = combatPower.Strength * 
                           combatSectorMod[sector] * combatDetLevelMod[detectionLevel] *
                           rangeModifier * illumModifier
                        local currentEffectiveCombatStrength = currentCombatStrength *
                           vulnToAttack.Vulnerability
                        if DEBUG_DETAIL then
                           printDebug(string.format("Target %s, atk type %s: base power %.1f, "..
                              "sector mod %.2f, CID mod %.2f, range mod %.2f, illum mod %.2f, net power %.1f",
                              entity:getName(), combatType, 
                              combatPower.Strength, combatSectorMod[sector], combatDetLevelMod[detectionLevel],
                              rangeModifier, illumModifier, currentCombatStrength))
                        end
                        
                        if(currentEffectiveCombatStrength > 0) then
                           -- This attack could damage the target. Save the info. After all attacks are
                           -- considered, we will then determine if this target makes the cut.
                           currentTargetInfo[combatType] = currentCombatStrength
                           effectiveTarget = true
                           currentTargetEffectiveCombatStrength = 
                              currentTargetEffectiveCombatStrength + currentEffectiveCombatStrength
                        end
         
                     end
                  end
               end
               
               -- Determine if this target makes the cut over the already added targets
               local addIt = false
               if effectiveTarget then
                  if isCurrentPreferred and not hasPreferredTarget then
                  
                     -- Drop all existing (non-preferred) targets. We now have a preferred target.
                     targetList = {}
                     effectiveCombatStrengths = {}
                     targetCount = 0
                     addIt = true
                     
                  elseif targetCount < MAX_TARGETS then
                  
                     -- Still room for more targets
                     addIt = true
                     
                  else
                  
                     -- Loop through the current list of chosen targets, and find the least preferred target
                     -- Preference is determined by:
                     --    - Targets against which we have a greater "effective" combat strength
                     --       (i.e., considering target vulnerabilty)
                     local lowestEffectiveCombatStrength = 0
                     local lowestTarget = ""
                     for chosenTargetName,chosenEffectiveCombatStrength in pairs(effectiveCombatStrengths) do
                     
                        if lowestEffectiveCombatStrength == 0 or
                           chosenEffectiveCombatStrength < lowestEffectiveCombatStrength then
                           
                           lowestEffectiveCombatStrength = chosenEffectiveCombatStrength
                           lowestTarget = chosenTargetName
                        end
                        
                     end
                     
                     if lowestEffectiveCombatStrength < currentTargetEffectiveCombatStrength then
                        
                        -- Remove the least preferred target
                        addIt = true
                        targetList[lowestTarget] = nil
                        effectiveCombatStrengths[lowestTarget] = nil
                        targetCount = targetCount - 1   
                        if DEBUG_DETAIL then
                           printDebug(".  More than ", MAX_TARGETS, " targets; removing entity ", 
                              lowestTarget, 
                              " from target list.")
                        end
                        
                     end
                     
                  end
               end
               if addIt then
                  
                  -- Add this target
                  targetList[entityID] = currentTargetInfo
                  effectiveCombatStrengths[entityID] = 
                     currentTargetEffectiveCombatStrength
                  targetCount = targetCount + 1
                  if DEBUG_DETAIL then
                     local name = vrf:getSimObjectByUUID(entityID):getName()
                     printDebug(".  Adding entity ", name, 
                        " to target list.")
                  end
                  
                  hasPreferredTarget = isCurrentPreferred
                  
               end
               
            end
         end         
      end   
   end
   
   return targetList
end


function updateAttacks(targetList, combatPowerList, currentAttacks)
   
   local updated = false
   local stoppedAttacks = {}
   local numTargets = 0
   
   for tIndex,target in pairs(targetList) do numTargets = numTargets + 1 end   
   if DEBUG_DETAIL and numTargets > 1 then
      printDebug("Dividing power among ", numTargets,
         " targets.")
   end
   
   -- Loop through our current attacks. Stop them if not in target list.
   for attackIndex,attack in pairs(currentAttacks) do
      
      local target = vrf:getSimObjectByUUID(attack.Target)      
      
      if (not target:isValid()) then
      
         -- Seems to be an invalid attack
         stoppedAttacks[#stoppedAttacks+1] = attackIndex
	 
         -- Make sure we remove this from the target list
         targetList[attack.Target] = nil
	  
         updated = true
	 
      else
      
         local newCombatPower = nil
         if (targetList[attack.Target] ~= nil ) then
            newCombatPower = targetList[attack.Target][attack.Type]
         end
      
         if (newCombatPower == nil) then
	 
            -- Can no longer continue attack on this target
            sendEngagement(target, attack.Type, 0, AG_NOT_APPLICABLE, true)
            stoppedAttacks[#stoppedAttacks+1] = attackIndex
	    
            updated = true
	 
         else
            
            newCombatPower = newCombatPower / numTargets
	         
            if (attack.Strength ~= newCombatPower) then
         
               -- Attack needs to be updated
               attack.Strength = newCombatPower
               sendEngagement(target, attack.Type, newCombatPower,
                  combatPowerList[attack.Type]["Hit-Factor"], false)
	       
               updated = true
	       
            end	    
	 
            -- Make sure we remove this from the target list. What remains will be new targets.
            targetList[attack.Target][attack.Type] = nil
         end	    
      end     
	 
   end
   
   -- Some attacks may have been stopped stopped. Remove them from the list.
   for i, attackIndex in pairs(stoppedAttacks) do
      currentAttacks[attackIndex] = nil
   end
   
   -- Some targets may be new. Add them to the list.
   for targetID, combatPowers in pairs(targetList) do

      local target = vrf:getSimObjectByUUID(targetID) 
      
      if (target:isValid()) then
         for combatType, combatPower in pairs(combatPowers) do
            if DEBUG_DETAIL then
               printDebug("    New target; engaging with combat power ", combatType)
            end
            currentAttacks[#currentAttacks + 1] =  
               { ["Target"] = targetID, ["Type"] = combatType, ["Strength"] = combatPower }
            
            sendEngagement(target, combatType, combatPower/numTargets,
               combatPowerList[combatType]["Hit-Factor"], false)
            updated = true
         end
      else
         if DEBUG_DETAIL then
            printDebug("  New target on target list not valid.")
         end
      end
      
   end
   
   return updated
end
-------------------------- MODIFIERS -------------------------------------
--
-- These modifiers are independent of target characteristics.
--------------------------------------------------------------------------

-- Calculate the EW effect modifier based on the base comms EW 
-- dependence and the current Comms degradation percent.
-- The modifier ranges between 0.0 and 1.0.
function calculateEWModifier ()
   local modifier = 1.0
   local degradationPercent = this:getStateProperty("EW-Comms-Degradation-Percent")
   
   if degradationPercent ~= nil and
      baseEWDependence ~= nil then
      
      modifier = 1.0 - degradationPercent/ 100.0 * baseEWDependence
      if DEBUG_DETAIL and modifier ~= 1.0 then
         printDebug(string.format(".  Comms jamming %d percent; strength modifier %f",
            degradationPercent, modifier))
      end
   end 
   return modifier
end

-- Calculates effects based on morale
function moraleEffects()
   local morale = this:getStateProperty("Morale")
   
   if (morale < ifMoraleLessThan) then
      return moraleModifyCombatPower
   end

   return 1.0
end

-- Calculates effects on the environment based on precipitation
-- at attacker position.  Based on values supplied in the script-enable-controller
function effectsFromEnvironment()
   local effectModifier = 1.0

   -- The closer to 100% the precipitation intensity the more the modifier will take effect
   if (precipitationIntensityModifier > 0) then
      local precipType, precipIntens = vrf:getPrecipitationInformation(this)

      if ((precipType == 1) or (precipType == 2)) then
         local precipModifier = 1.0 - (1.0 - precipitationIntensityModifier) * precipIntens
         effectModifier = effectModifier * precipModifier
         if DEBUG_DETAIL and precipModifier ~= 1.0 then
            printDebug(".  Precipitation modifier " .. precipModifier)
         end
      end
   end

   return effectModifier
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Calculates derived properties that are required to update the dynamic
-- properties controlled by this script. Returns the current values of these
-- properties.
-- Pre-tick derived properties:
--     Combat-Power
function calculatePreTickDerivedProperties()
   
   local posture = this:getStateProperty("Posture")
   local health = this:getStateProperty("Health")
   local mopp = this:getStateProperty("MOPP-Level")
   local healthPercent = health / baseHealth
   local environmentalEffects = effectsFromEnvironment()
   local moraleModifier = moraleEffects()
   local ewDegradationModifier = calculateEWModifier()
      
   -- Calculate combat power, but only if posture or health has changed
   currentCombatPower = this:getStateProperty("Combat-Power")
   if (posture ~= previousPosture or
       health ~= previousHealth or
       mopp ~= previousMopp or
       environmentalEffects ~= previousEnv or
       moraleModifier ~= previousMorale or
       ewDegradationModifier ~= previousEW or
       forceUpdate == true) then
   
      if DEBUG_DETAIL then
         printDebug(string.format("New posture, health, MOPP, morale, environment or EW; recalculating power."))
      end
      
      for combatType, basePower in pairs(baseCombatPower) do
         local newStrength = combatPostureMod[posture] * healthPercent *
            combatMoppMod[mopp] * basePower.Strength * environmentalEffects * moraleModifier *
            ewDegradationModifier
         local newRange = rangePostureMod[posture] * basePower.Range
         currentCombatPower[combatType].Range = newRange
         currentCombatPower[combatType].Strength = newStrength
         currentCombatPower[combatType]["Hit-Factor"] = basePower["Hit-Factor"]
         if DEBUG_DETAIL and newStrength > 0 then
            printDebug(string.format(".  %s: strength %f, range %f",
               combatType, newStrength, newRange))
         end
      end      
      this:setStateProperty("Combat-Power", currentCombatPower)
   end
   
   previousPosture = posture
   previousHealth = health
   previousMopp = mopp
   previousEnv = environmentalEffects
   previousMorale = moraleModifier
   previousEW = ewDegradationModifier
   
   return currentCombatPower
end
   
-- Updates any dynamic properties controlled by this task. Returns the
-- current values of these properties.
-- Dynamic properties:
--     Attacks
function updateDynamicProperties(combatPowerList)
   local currentLoc = this:getLocation3D()
   local currentAttacks = this:getStateProperty("Attacks")
   local rulesOfEngagement = this:getRulesOfEngagement()
   
   -- Find the targets we can possibly attack
   local targetList = {}
   
   if(rulesOfEngagement == "hold-fire") then
      if DEBUG_DETAIL and true then
         printDebug("  Hold fire, stopping attacks")
      end
      stopAllAttacks()
      currentAttacks = {}
   else
   
      local whenFiredUpon = false
      if(rulesOfEngagement == "fire-when-fired-upon") then
         whenFiredUpon = true
      end
      targetList = findTargets(currentLoc, combatPowerList, whenFiredUpon)

      -- Update our attacks
      if (updateAttacks(targetList, combatPowerList, currentAttacks)) then
      
         -- Something changed, update the property
         this:setStateProperty("Attacks", currentAttacks)
      end
   end
   
   return currentAttacks
end

-- Calculates remaining derived properties which are maintained by this script.
-- Derived properties:
--     None
function calculateDerivedProperties()
end

-- Called each tick while this task is active.
function tick()   
   if DEBUG_IF_POWERS and firstTick then
      local allIFWeapons = this:getStateProperty("Indirect-Fire-Power")
      if allIFWeapons then
         printDebug("IF/Large Munition weapons:")
         for weapon, weaponInfo in pairs(allIFWeapons) do
            printDebug("Weapon ", weapon)
            printDebug(string.format("  Dmg %s, Rg %f, Rad %f, Hit %f, Sec/attk %f, Str/attk %d, Ammo/Attk %d",
               weaponInfo["Damage-Type"], weaponInfo["Range"], 
               weaponInfo["Radius"], weaponInfo["Hit-Factor"],
               weaponInfo["Seconds-Per-Attack"],
               weaponInfo["Strength-Per-Attack"], 
               weaponInfo["Ammunition-Per-Attack"]))
         end
      end
   end   
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Attack Enemies:",
         vrf:getSimulationTime()))
   end
   
   firstTick = false
   
   -- Check to see if we need to resend current attacks before processing
   if resendAllAttacks then
      local currentAttacks = this:getStateProperty("Attacks")
      for attackIndex,attack in pairs(currentAttacks) do
         local target = vrf:getSimObjectByUUID(attack.Target)
         
         if(target:isValid()) then
            --  Valid attack, resend it.
            sendEngagement(target, attack.Type, attack.Strength, 
               AG_NOT_APPLICABLE, false)
         end      
      end
      
      resendAllAttacks = false
      
      -- Reset the tick period. Usually when we need to resend attacks the
      -- tick period is decreased to force the resend more quickly.
      vrf:setTickPeriod(setValueIfPresent(TICK_PERIOD, "Tick-Period"))
   end
   
   local combatPower = calculatePreTickDerivedProperties()
   local currentAttacks = updateDynamicProperties(combatPower)
   calculateDerivedProperties()  
      
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

-- Called when this entity is destroyed
function entityDestroyed()
   stopAllAttacks()
end

-- Called when this entity is completely removed
function shutdown()
   stopAllAttacks()
end
