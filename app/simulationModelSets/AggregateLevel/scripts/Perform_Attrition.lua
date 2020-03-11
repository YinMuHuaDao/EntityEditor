-- Perform_Attrition.lua
-- Copyright 11/2013 by VT-MAK
--
-- This file contains the script used to compute attrition due to attacks.
-- It is a "background" script that runs all of the time on a unit.
-- The script receives influences and processes Engagement (and 
-- Engagement.IndirectFire) types.

-- Set this to true to dump more info to the entity debug console.
local DEBUG_DETAIL = true

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- *********** Constants used in the calculations
-- Evaluation inverval, in seconds
local TICK_PERIOD = 5

-- The maximum modifier due to EW attack.
-- This number scales vulnerability, so if a unit is
-- completely dependent on comms for operation, and comms
-- are 100% degraded by an EW attack, then vulnerability
-- to attacks will be MAX_EW_MODIFIER x normal.
local MAX_EW_MODIFIER = 2.0

-- Speed at which an entity has to be moving before it will take
-- damage from engineering objects
local ENG_OBJ_THRESHOLD_SPEED = 0.75

-- Standard deviation for attrition random variation.
-- The attrition random variation modifier, which is multiplied by the 
-- computed attrition rate, is drawn from a log-normal distribuition.
-- About 68% of the modifier values will be between +- one standard
-- deviation. The desired range for 68% of values, i.e. the level of 
-- variability, can be used to compute the desired SD, e.g:
-- 68% range		SD (= ln(rangeMax))
-- [0.91, 1.1]		0.095
-- [0.8,  1.25]		0.223
-- [0.67, 1.5]		0.405
-- [0.5,  2.0]		0.693
local ATTRITION_SD = 0.223

-- Random variation in attrition for each attack changes only at
-- a specified time interval, regardless of what the script tick
-- interval is. In seconds.
-- A more frequent random draw will produce results closer to average.
local RAND_DRAW_INTERVAL = 30

-- *********** Global Variables. 
-- Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- parameter-data storage. 
-- This data is static, so it can be stored at init time.
local baseHealth = this:getParameterProperty("Base-Health")
local baseVulnerability = this:getParameterProperty("Base-Vulnerability")
local baseNbcVulnerability = this:getParameterProperty("Base-NBC-Vulnerability")
local baseEWVulnerability = this:getParameterProperty("Base-Comms-Dependence")
local vulnerabilitySectorMod = this:getParameterProperty("Vulnerability-Sector-Modifier")
local vulnerabilityPostureMod = this:getParameterProperty("Vulnerability-Posture-Modifier")
local vulnerabilityMoppMod = this:getParameterProperty("Vulnerability-MOPP-Level-Modifier")
local baseEquipment = this:getParameterProperty("Base-Equipment")
local baseWeapons = this:getParameterProperty("Base-Weapons")
local baseOfficers = this:getParameterProperty("Base-Personnel-Officers")
local baseWOs = this:getParameterProperty("Base-Personnel-WOs")
local baseNCOs = this:getParameterProperty("Base-Personnel-NCOs")
local baseEnlisted = this:getParameterProperty("Base-Personnel-Enlisted")
local healthForRout = this:getParameterProperty("Health-Percent-For-Rout") * 0.01 * baseHealth

-- Comparison values stored from previous tick
previousUpdateTime = -1
previousMOPP = -1
previousHealth = 0
previousOfficers = 0
previousNCOs = 0
previousWOs = 0
previousEnlisted = 0
previousEngineeringAreaVulnerabilityMod = false
previousParentName = ""
previousParentHealth = 0
previousParentKilled = 0
previousParentCaptured = 0
previousParentWounded = 0
previousParentName = ""
updateDestroyedStateBasedOnHealth = true

-- Periodically updated random numbers used in probability calculations
--local hitProbabilityRandom = 0.5
local attritionAmountRandom = 0.5
local randomUpdateTime = -1

-- Used to determine what type of casualty has taken place and who caused it
local attritionRate = 0
local killRate = 0
local captureRate = 0
local woundRate = 0
local killerRates = {}
local capturerRates = {}
local wounderRates = {}
local missingRates = {}
local engagedEnemies = {}

-- Set to true when suffering attrition from contamination
local attritionFromContamination = false
local contaminationType = "None"

-- Add callbacks for when state properties are set.
-- This will allow the script to respond quickly to changes in health 
-- and be able to do so while the scenario is paused.
vrf:addPostSetDataCallback("set-state-properties", "updateAttrition");

-- Call tick when  set state properties is done to allow the script to
-- immediately respond to changes in health.
function updateAttrition(parameters)

   local stateProps = parameters["state-properties"]
   if stateProps ~= nil then
      local health = stateProps["Health"]
      if health ~= nil then
         tick();
      end
   end
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(TICK_PERIOD)
   
   -- Initialize the previous health value
   previousHealth = baseHealth
   previousOfficers = baseOfficers
   previousNCOs = baseNCOs
   previousWOs = baseWOs
   previousEnlisted = baseEnlisted
   
   -- Get exercise time
   previousUpdateTime = vrf:getSimulationTime()
end

-- Called on scenario load. Make sure our derived properties are updated
-- based on restored health.
function loadState()

   local health = this:getStateProperty("Health")
   local savedBaseHealth = this:getStateProperty("Saved-Base-Health")
   
   local healthPercent = health / baseHealth
   if savedBaseHealth ~= nil and savedBaseHealth > 0 and savedBaseHealth ~= baseHealth then
      -- Keep the same health percent from previous save. Adjust our health
      -- value according to the new base health.
      healthPercent = health / savedBaseHealth
      health = healthPercent * baseHealth
      this:setStateProperty("Health", health)
   end
   
   this:setStateProperty("Saved-Base-Health", baseHealth)
   
   -- Equipment
   local restoredEquipment = this:getStateProperty("Equipment")
   local currentEquipment = {}
   for equipType, equip in pairs(baseEquipment) do
      local numLeft = roundEquipmentAndPersonnel(equip.Count * healthPercent)
      local category = equip.Category
      local pacingTracking = equip["Pacing-Tracking"]
      
      local currentEquip = currentEquipment[equipType]
      if(currentEquip ~= nil) then
         pacingTracking = currentEquip["Pacing-Tracking"]
      end
      
      currentEquipment[equipType] = { 
         ["Count"] = numLeft,
         ["Pacing-Tracking"] = pacingTracking,
         ["Category"] = category }
   end
   local restoredWeapons = this:setStateProperty("Equipment", currentEquipment)

   -- Weapons
   local restoredWeapons = this:getStateProperty("Weapons")
   local currentWeapons = {}
   for weaponType, weapon in pairs(baseWeapons) do
      local numLeft = roundEquipmentAndPersonnel(weapon.Count * healthPercent)
      local category = weapon.Category
      local pacingTracking = weapon["Pacing-Tracking"]
      
      local currentWeapon = currentWeapons[weaponType]
      if(currentWeapon ~= nil) then
         pacingTracking = currentWeapon["Pacing-Tracking"]
      end
      
      currentWeapons[weaponType] = { 
         ["Count"] = numLeft,
         ["Pacing-Tracking"] = pacingTracking,
         ["Category"] = category }
   end
   local restoredWeapons = this:setStateProperty("Weapons", currentWeapons)
   
   -- Personnel
   this:setStateProperty("Personnel-Officers", roundEquipmentAndPersonnel(baseOfficers * healthPercent))
   this:setStateProperty("Personnel-WOs",  roundEquipmentAndPersonnel(baseWOs * healthPercent))
   this:setStateProperty("Personnel-NCOs", roundEquipmentAndPersonnel(baseNCOs * healthPercent))
   this:setStateProperty("Personnel-Enlisted", roundEquipmentAndPersonnel(baseEnlisted * healthPercent))
end

-- This function determines whether an attack with the given hit factor and combat type
-- will hit this unit.
function hitByAttack(hitFactor, defenseFactor)

   if hitFactor == nil or hitFactor == AG_NOT_APPLICABLE or
      hitFactor < 0.0 then
      -- Not guided, always hits something.
      return true
   elseif(defenseFactor == nil or defenseFactor == AG_NOT_APPLICABLE or
      defenseFactor < 1.0) then 
      -- No defense factor (ignore small values), always hits
      if DEBUG_DETAIL then
         printDebug(string.format(".    No defense factor (%.2f); munition hits.",
            defenseFactor))
      end
      return true
   else
      -- Calculate hit probability
      local factorRatio = hitFactor/defenseFactor
      -- Raise ratio to 4th power. This happens to be an exponent that
      -- will result in about a 1% increase in probability for a 1%
      -- increase in ratio; e.g. a ratio of 1.01 results in a probability
      -- of about 51%. (The relative incremental change decreases
      -- for ratios much different from 1.0.)
      factorRatio = factorRatio * factorRatio
      factorRatio = factorRatio * factorRatio
      
      hitProb = factorRatio/(1.0 + factorRatio)
      local draw = math.random()
      if DEBUG_DETAIL then
         printDebug(string.format(".    Hit fact. %d, def. fact. %d, P(hit) %.3f, draw %.3f",
            hitFactor, defenseFactor, hitProb, draw))
      end
      if(draw < hitProb) then
         return true
      else
         if DEBUG_DETAIL then
            printDebug(".    Miss")
         end
         return false
      end
   end
end

-- Varies the amount of attrition within a range centered on the given value. 
-- Random number is any real in (-inf, inf); assumed to be from a standard
-- normal distribution.
function varyAttrition(attrition, randomNumber)
   local modifier = math.exp(randomNumber * ATTRITION_SD)
   if DEBUG_DETAIL then
      printDebug(string.format(".   Attr. %.3f, draw %.3f, modifier %.3f, net attr. rate %.3f", 
      attrition, randomNumber, modifier, attrition*modifier))
   end
   return attrition * modifier
end

-- Calculate the EW effect modifier based on the base comms EW 
-- dependence and the current Comms degradation percent.
-- The modifier ranges between 1.0 and MAX_EW_MODIFIER.
function calculateEWModifier ()
   local modifier = 1.0
   local degradationPercent = this:getStateProperty("EW-Comms-Degradation-Percent")
   if degradationPercent ~= nil and
      baseEWVulnerability ~= nil then
      
      modifier = 1.0 + (MAX_EW_MODIFIER - 1.0) * 
         degradationPercent/ 100.0 * baseEWVulnerability
   end 
   return modifier
end

-- Returns true if the unit with the given center location and footprint overlaps
-- the specified area.
function overlapsArea(loc, footprint, area)   local overlaps = false
   if(area:isPointInside(loc) or 
      loc:distanceToLocation3D(area:getLocation3D()) <= footprint) then
      overlaps = true
   else
      local vecToArea = loc:vectorToLoc3D(area:getLocation3D())
      
      local scaledVector = vecToArea:getUnit():getScaled(footprint)
      local closestPoint = loc:addVector3D(scaledVector) 
      if(area:isPointInside(closestPoint)) then
         overlaps = true
      end
   end
   
   return overlaps
end

-- Calculates the current attrition for an embarked unit based on the attrition of the parent
function calculateAttritionEmbarked(parent, currentHealth)

   -- This unit is embarked, and therfor cannot directly defend against
   -- any attacks.
   this:setStateProperty("Attacks-Defending", {})
   
   local currentTime = vrf:getSimulationTime()
   
   local timeDiff = currentTime - previousUpdateTime
   
   if DEBUG_DETAIL then
      printDebug(string.format("Attrition due to attacks, for past %.2f seconds",
         timeDiff))
   end
   
   local attritionAmount = 0
   attritionRate = 0
   
   local parentHealth = parent:getStateProperty("Health")
   
   if(previousParentName ~= parent:getUUID()) then
   
      -- We are newly embarked, save our parent info so we can use it
      -- to determine how to attrit ourselves next tick
      previousParentName = parent:getUUID()
      previousParentHealth = parentHealth
      
      killRate = 0
      captureRate = 0
      woundRate = 0
      killerRates = {}
      capturerRates = {}
      wounderRates = {}
      missingRates = {}
      engagedEnemies = {}
      
   elseif(parentHealth < previousParentHealth) then
   
      -- Let's attrit. Base our attrition on our parent's attrition.
      local parentAttritionPercent = (previousParentHealth - parentHealth) /
         previousParentHealth
         
      previousParentHealth = parentHealth
         
      attritionAmount = currentHealth * parentAttritionPercent
      attritionRate = attritionAmount / timeDiff
      
      local parentCasualtiesPerAttacker = parent:getStateProperty("Casualties-Per-Attacker")
      
      -- Figure out kill, capture, wounded, and missing rates,
      -- per attacker and overall, based on parent's numbers.
      if next(parentCasualtiesPerAttacker) == nil then
         -- Parent's attackers have been cleared. They have probably ended
         -- and we are now taking the final round of damage. Use previous values.
      else
      
         killRate = 0
         captureRate = 0
         woundRate = 0
         killerRates = {}
         capturerRates = {}
         wounderRates = {}
         missingRates = {}
         engagedEnemies = {}
      
         local parentKilled = 0
         local parentCaptured = 0
         local parentWounded = 0
         local parentMissing = 0
         local parentKilledByAttacker = {}
         local parentCapturedByAttacker = {}
         local parentWoundedByAttacker = {}
         local parentMissingByAttacker = {}
         for attacker,casualties in pairs(parentCasualtiesPerAttacker) do
            parentKilled = parentKilled + casualties["Number-Killed"]
            parentKilledByAttacker[attacker] = casualties["Number-Killed"]
            parentCaptured = parentCaptured + casualties["Number-Captured"]
            parentCapturedByAttacker[attacker] = casualties["Number-Captured"]
            parentWounded = parentWounded + casualties["Number-Wounded"]
            parentWoundedByAttacker[attacker] = casualties["Number-Wounded"]
            parentMissing = parentMissing + casualties["Number-Missing"]
            parentMissingByAttacker[attacker] = casualties["Number-Missing"]
         end
         
         local totalParentCasualties = parentKilled + parentCaptured +
            parentWounded + parentMissing
         killRate = attritionRate * parentKilled / totalParentCasualties
         captureRate = attritionRate * parentCaptured / totalParentCasualties
         woundRate = attritionRate * parentWounded / totalParentCasualties
      
         for attacker,killed in pairs(parentKilledByAttacker) do
            killerRates[attacker] = attritionRate * killed / totalParentCasualties
         end
         for attacker,captured in pairs(parentCapturedByAttacker) do
            capturerRates[attacker] = attritionRate * captured / totalParentCasualties
         end
         for attacker,wounded in pairs(parentWoundedByAttacker) do
            wounderRates[attacker] = attritionRate * wounded / totalParentCasualties
         end
         for attacker,missing in pairs(parentMissingByAttacker) do
            missingRates[attacker] = attritionRate * missing / totalParentCasualties
         end
      end
   end
   
   this:setStateProperty("Attrition-Rate", attritionRate)
   
   -- Update our "previous" values for the next tick
   previousUpdateTime = currentTime
      
   if DEBUG_DETAIL then
      printDebug(string.format("  Net attrition rate %.2f, attrition for interval %.2f",
         attritionRate, attritionAmount))
   end
   return attritionAmount
end

-- Calculates the current attrition based on the current attacks, NBC areas, and engineering objects
function calculateAttrition(currentAttacks, currentAttacksDefending, 
   engineeringObjects, nbcAreas)

   -- Not embarked
   previousParentName = ""
      
   -- First get attrition from combat
   local currentVulnerability = this:getStateProperty("Vulnerability")
   local physFootprint = this:getStateProperty("Physical-Footprint")
   local sectorSizes = this:getStateProperty("Sector-Sizes")
   local unitLocation = this:getLocation3D()
   
   local currentTime = vrf:getSimulationTime()
   local doUpdateRandom = false
   
   -- Update our random values if necessary
   if(currentTime > randomUpdateTime) then
      doUpdateRandom = true --flag for attrition variation
      -- Update again in a minute
      randomUpdateTime = currentTime + RAND_DRAW_INTERVAL
   end
   
   local timeDiff = currentTime - previousUpdateTime
   
   if DEBUG_DETAIL then
      printDebug(string.format("Attrition due to attacks, for past %.2f seconds",
         timeDiff))
   end

   attritionRate = 0
   killRate = 0
   captureRate = 0
   woundRate = 0
   killerRates = {}
   capturerRates = {}
   wounderRates = {}
   missingRates = {}
   engagedEnemies = {}
      
   -- Update list of engaged enemies.
   for attackIndex, attack in pairs(currentAttacks) do
      engagedEnemies[attack.Target] = true
   end
   for attackIndex, attack in pairs(currentAttacksDefending) do    
      if doUpdateRandom then
         attack.CurrentRandomDraw = vrf:gaussian()
      end
      -- While we're at it, clear out expired attacks.
      if(attack.TimeComplete ~= AG_NOT_APPLICABLE and
         attack.TimeComplete < previousUpdateTime) then
		 
         if DEBUG_DETAIL then
            printDebug("Attack from ", vrf:getSimObjectByUUID(attack.Attacker):getName(), 
               " expired.")
         end
         currentAttacksDefending[attackIndex] = nil
      else
         engagedEnemies[attack.Attacker] = true
      end
   end
   this:setStateProperty("Attacks-Defending", currentAttacksDefending)
   
   -- Stores linear engineering object vulnerability modifiers so that we do not
   -- have to query them again every loop
   local engLineVulnMods = {}
   -- Calculate this separately here, rather than rolling into pre-tick 
   -- vulnerability calculations, so that it can be used or not on a 
   -- per-attack basis. (See usage below.)
   local EwModifier = calculateEWModifier()
      
   for attackIndex, attack in pairs(currentAttacksDefending) do
   
      if DEBUG_DETAIL then
         printDebug(string.format("  Attacker %s, type %s, nominal strength %.1f",
            vrf:getSimObjectByUUID(attack.Attacker):getName(), attack.Type, attack.Strength))
      end

      local prevAttackUpdateTime = math.max(attack.TimeStarted, previousUpdateTime)
      local currAttackUpdateTime = currentTime
            
      -- For limited duration attacks, see if the attack is over.
      if(attack.TimeComplete ~= AG_NOT_APPLICABLE and
         attack.TimeComplete < currentTime) then
         currAttackUpdateTime = attack.TimeComplete
      end
      
      local attackTime = currAttackUpdateTime - prevAttackUpdateTime
      
      -- Can't take full damage if full tick time was not experienced, so scale it back
      local attackStrength = attack.Strength * attackTime/timeDiff
      
      -- Assume that if the attack duration is short, this is a single munition
      -- attack, and comms jamming has no effect on vulnerability 
      --(because comms jamming would only affect coordination of entities over time).
      -- Note that if this is an instantaneous attack, the attack duration set
      -- in processAttack below is 1.0 seconds.
      local perAttackEwModifier = EwModifier
      if attackTime <= 1.0 then
         perAttackEwModifier = 1.0
      end
         
      if DEBUG_DETAIL and attackTime ~= timeDiff then
         printDebug(string.format(
            ".    Limited duration attack, %.3f this tick",
            attackTime))
      end
      
      -- Calculate our vulnerability
      local vulnForAttack = 0
      
      local vulnInfoForAttack = currentVulnerability[attack.Type]
      if(vulnInfoForAttack == nil) then
         printWarn("Ignoring attack received with unknown combat type: ", attack.Type)
      else
         vulnForAttack = vulnInfoForAttack.Vulnerability
      end
      
      if DEBUG_DETAIL then
         printDebug(".    Current vulnerability is ", vulnForAttack)
         printDebug(".       Type ", attack.Type)
      end
      -- Sector does not come in to play for indirect fire
      if(not attack.IsIndirect) then
      
         -- Find our attacker's location and determine any vulnerability modifiers based on
         -- that location relative to ours
         local attacker = vrf:getSimObjectByUUID(attack.Attacker)
         if (attacker:isValid()) then
         
            local attackerLocation = attacker:getLocation3D()
            local sector = getSector(this, attackerLocation, sectorSizes)
          
            -- Adjust vulnerability based on where attack is originating
            local sectorVuln = vulnerabilitySectorMod[sector]
            if (sectorVuln ~= nil) then
               vulnForAttack = vulnForAttack * sectorVuln
               if DEBUG_DETAIL then
                  printDebug(".    Sector mod for vuln. is ", sectorVuln)
               end
            end
            
            -- Adjust vulnerability for any linear objects with defensive values
            for objNum,engLine in pairs(engineeringObjects["lines"]) do
       
               local vulnMods = engLineVulnMods[objNum]
               if(vulnMods == nil) then
                  engLineVulnMods[objNum] = 
                     engLine:getParameterProperty("Vulnerability-Modifiers")
                  vulnMods = engLineVulnMods[objNum]
               end
            
               if(vulnMods ~= nil) then
                  local vulnForType = vulnMods[attack.Type]
                  if(vulnForType ~= nil) then
                     
                     -- It has a vulnerability modifier, modify it based on
                     -- the current effectiveness of the object.
                     local vulnMod = engineeringObjectEffectiveModifier(engLine, vulnForType)
                     
                     if(vulnMod ~= 1) then
                        -- This object does affect vulnerability for this attack type. Now see
                        -- if its affecting us. Must be between us and the attacker and be closer
                        -- to us than to the attacker.
                        local hasEffect = false
                        local location, hasEffect = engLine:getIntersectionPointWithLine2D(
                           unitLocation, attackerLocation)
                        if(hasEffect and 
                           unitLocation:distanceToLocation3D(location) < 
                           attackerLocation:distanceToLocation3D(location)) then
                           if DEBUG_DETAIL then
                              printDebug(".  Eng. obj. mod for vuln. is ", vulnMod)
                           end
                           vulnForAttack = vulnForAttack * vulnMod
                        end
                     end
                  end
               end
            end
         end            
      end
                
      vulnForAttack = vulnForAttack * perAttackEwModifier
      if DEBUG_DETAIL and EwModifier > 1.0 then
         printDebug(".   EW mod for vuln. is ", perAttackEwModifier)
      end
             
      -- Multiply vulnerability by attack strength to get attrition
      local attritionRateThisAttack = vulnForAttack * attackStrength
      attritionRateThisAttack = varyAttrition(attritionRateThisAttack,
         attack.CurrentRandomDraw)
         
      attritionRate = attritionRate + attritionRateThisAttack
      
      -- Calculate casualty type rates
      local killRateThisAttack = attritionRateThisAttack * attack.ProbabilityKill
      local captureRateThisAttack = attritionRateThisAttack * attack.ProbabilityCapture
      local woundRateThisAttack = attritionRateThisAttack * attack.ProbabilityWound
      local missingRateThisAttack = attritionRateThisAttack - killRateThisAttack -
         captureRateThisAttack - woundRateThisAttack
      
      -- Update total casualty rates
      killRate = killRate + killRateThisAttack
      captureRate = captureRate + captureRateThisAttack
      woundRate = woundRate + woundRateThisAttack
      
      -- Update casuatly rates for this attacker
      if(killerRates[attack.Attacker] == nil) then
         killerRates[attack.Attacker] = 0
      end
      if(capturerRates[attack.Attacker] == nil) then
         capturerRates[attack.Attacker] = 0
      end
      if(wounderRates[attack.Attacker] == nil) then
         wounderRates[attack.Attacker] = 0
      end
      if(missingRates[attack.Attacker] == nil) then
         missingRates[attack.Attacker] = 0
      end
      killerRates[attack.Attacker] = killerRates[attack.Attacker] + killRateThisAttack
      capturerRates[attack.Attacker] = capturerRates[attack.Attacker] + captureRateThisAttack
      wounderRates[attack.Attacker] = wounderRates[attack.Attacker] + woundRateThisAttack
      missingRates[attack.Attacker] = missingRates[attack.Attacker] + missingRateThisAttack  

   end   
   
   local footprint = this:getStateProperty("Physical-Footprint")
   
   -- Create a list of the environmental objects (NBC areas, engineering objects)
   -- that are causing attrition to this unit.
   local envAttrition = {}
   
   -- Calculate attrition from NBC
   attritionFromContamination = false
   for objNum,nbcArea in pairs(nbcAreas) do
         
      -- Get NBC damage information
      local nbcType = ""
      local damagePerSec = 0
      local minimumMopp = 0         
      nbcType, damagePerSec, minimumMopp = nbcArea:getNbcDamage()         
      
      -- If MOPP 0 is enough to counteract effects, this area isn't actually contaminated
      if(minimumMopp > 0) then
      
         -- Valid NBC area. See if we fall within it.          
         if(overlapsArea(unitLocation, footprint, nbcArea)) then
            -- Contamination!!
            if(not attritionFromContamination) then
               attritionFromContamination = true
               contaminationType = nbcArea:getNbcAgent()
            end  
            
            local moppLevel = this:getStateProperty("MOPP-Level")
            if(moppLevel < minimumMopp) then
               -- MOPP is not providing enough protection. Alter attrition.
               local objName = nbcArea:getUUID()
               local attritionRateThisArea = damagePerSec * baseNbcVulnerability[nbcType]
               
               if DEBUG_DETAIL then
                  printDebug(string.format("  Attrit. rate %.1f in area %s, vuln %.3f, net rate %.1f",
                     damagePerSec, nbcArea:getName(), baseNbcVulnerability[nbcType], 
                     attritionRateThisArea))
               end
               attritionRate = attritionRate + attritionRateThisArea
               killRate = killRate + attritionRateThisArea
               killerRates[objName] = attritionRateThisArea
               
               envAttrition[objName] = attritionRateThisArea
            elseif DEBUG_DETAIL then
               printDebug(string.format("  No attrit. from area %s; req'd MOPP %d",
                  nbcArea:getName(), minimumMopp))
            end
         end
      end
   end
   
   
   -- Calculate attrition from engineering objects, but only if we are moving faster than .75 m/s
   if(this:getSpeed() > ENG_OBJ_THRESHOLD_SPEED) then
   
      -- Calculate attrition from engineering areas
      for objNum,engArea in pairs(engineeringObjects["areas"]) do
         
         local takeAttrition = false
         
         if(engArea:getForceEnumeration() == this:getForceEnumeration()) then        
            -- Areas of our own force types affect us if our center is within them
            if(engArea:isPointInside(unitLocation)) then
               takeAttrition = true
            end
         else      
            -- Areas of other force types affect us if we overlap with them
            if(overlapsArea(unitLocation, footprint, engArea)) then
               takeAttrition = true
            end
         end
         
         if(takeAttrition) then
            local attritionRateThisObj = 0
            local attritionAmts = engArea:getParameterProperty("Attrition-Per-Second")
            for attrType,attrAmt in pairs(attritionAmts) do
               
               -- Adjust attrition amount based on effectiveness
               local effectiveAttrAmt = engineeringObjectEffectiveValue(engArea, attrAmt)
               
               -- Calculation attrition based on vulnerability
               local vulnForType = currentVulnerability[attrType].Vulnerability
               attritionRateThisObj = attritionRateThisObj + (vulnForType * effectiveAttrAmt)
               
            end
            
            -- Alter attrition and kill rates
            if(attritionRateThisObj > 0) then
               local objName = engArea:getUUID()
               attritionRate = attritionRate + attritionRateThisObj
               killRate = killRate + attritionRateThisObj
               killerRates[objName] = attritionRateThisObj
               
               envAttrition[objName] = attritionRateThisObj
            end
         end
      end
                  
      -- Calculate attrition from engineering lines
      for objNum,engLine in pairs(engineeringObjects["lines"]) do
      
         local takeAttrition = false
         
         local distance = -1
         local closestPoint, distance = engLine:getClosestPointToLocation2D(unitLocation)
         local lineWidth = engLine:getParameterProperty("Fixed-Width")
         
         takeAttrition = (lineWidth ~= nil and distance >= 0 and distance < lineWidth/2)
         
         if(takeAttrition) then
            local attritionRateThisObj = 0
            local attritionAmts = engLine:getParameterProperty("Attrition-Per-Second")
            for attrType,attrAmt in pairs(attritionAmts) do
            
               -- Adjust attrition amount based on effectiveness
               local effectiveAttrAmt = engineeringObjectEffectiveValue(engLine, attrAmt)
               
               -- Calculation attrition based on vulnerability
               local vulnForType = currentVulnerability[attrType].Vulnerability
               attritionRateThisObj = attritionRateThisObj + (vulnForType * effectiveAttrAmt)
            
            end
            
            -- Alter attrition and kill rates
            if(attritionRateThisObj > 0) then
               local objName = engLine:getUUID()
               attritionRate = attritionRate + attritionRateThisObj
               killRate = killRate + attritionRateThisObj
               killerRates[objName] = attritionRateThisObj
               
               envAttrition[objName] = attritionRateThisObj
            end
         end
      end
                  
      -- Calculate attrition from engineering points
      for objNum,engPoint in pairs(engineeringObjects["points"]) do
      
         local takeAttrition = false
         
         local distance = -1
         local distance = unitLocation:distanceToLocation3D(engPoint:getLocation3D())
         
         -- Only take attrition from objects which were not created by our force that we are
         -- in range of
         takeAttrition = (engPoint:getForceEnumeration() ~= this:getForceEnumeration() and
            distance >= 0 and distance < footprint)
         
         if(takeAttrition) then
            local attritionRateThisObj = 0
            local attritionAmts = engPoint:getParameterProperty("Immediate-Attrition")
            for attrType,attrAmt in pairs(attritionAmts) do
            
               -- Adjust attrition amount based on effectiveness
               local effectiveAttrAmt = engineeringObjectEffectiveValue(engPoint, attrAmt)
               
               -- Calculation attrition based on vulnerability
               local vulnForType = currentVulnerability[attrType].Vulnerability
               attritionRateThisObj = attritionRateThisObj + (vulnForType * effectiveAttrAmt)
            
            end
            
            -- Alter attrition and kill rates
            if(attritionRateThisObj > 0) then
               local objName = engPoint:getUUID()
               attritionRate = attritionRate + attritionRateThisObj
               killRate = killRate + attritionRateThisObj
               killerRates[objName] = attritionRateThisObj
               
               envAttrition[objName] = attritionRateThisObj
            end
            
            -- Determine if this object should now be destroyed
            local destroy = engPoint:getParameterProperty("Destroy-On-Contact")
            if(destroy) then
               vrf:deleteObject(engPoint)
            end
            
         end
      end

      this:setStateProperty("Environmental-Attrition", envAttrition)
   end
      
   -- Publish for display in GUI
   this:setStateProperty("Attrition-Rate", attritionRate)
   
   -- Update our "previous" values for the next tick
   previousUpdateTime = currentTime
      
   if DEBUG_DETAIL then
      printDebug(string.format("  Net attrition rate %.2f, attrition for interval %.2f",
         attritionRate, attritionRate*timeDiff))
   end
         
   return attritionRate * timeDiff
end

-- Randomly assigns a single casualty to an attacker based on the given probabilities.
function assignCasualty(attackerRates)

   local attacker = ""
   
   -- Get the total rate
   local totalRate = 0
   for currAttacker, rate in pairs(attackerRates) do
      totalRate = totalRate + rate
   end
   
   -- Randomly assign the attacker
   local checkRate = 0
   local r = math.random() * totalRate
   for currAttacker, rate in pairs(attackerRates) do
      checkRate = checkRate + rate 
      if(r < checkRate) then
         attacker = currAttacker
         break
      end
   end

   return attacker
end     

-- Randomly assigns each casualty to a type and attacker based on the probabilities
-- calculated in calculateAttrition().
function assignCasualties(numCasulaties, casualtiesPerAttacker)      

   local casualtiesLeft = numCasulaties
   local numKilled = 0
   local numCaptured = 0
   local numWounded = 0
   local numMissing = 0
   
   while(casualtiesLeft > 0) do
   
      local typeToIncrement = ""
      local attacker = ""
      
      local r = math.random() * attritionRate
      if (r < killRate) then
         numKilled = numKilled + 1
         attacker = assignCasualty(killerRates)
         typeToIncrement = "Number-Killed"

      elseif (r < killRate + captureRate ) then
         numCaptured = numCaptured + 1
         attacker = assignCasualty(capturerRates)
         typeToIncrement = "Number-Captured"
            
      elseif (r < killRate + captureRate + woundRate) then
         numWounded = numWounded + 1
         attacker = assignCasualty(wounderRates)
         typeToIncrement = "Number-Wounded"
            
      else
         numMissing = numMissing + 1      
         attacker = assignCasualty(missingRates)
         typeToIncrement = "Number-Missing"
         
      end
      
      if(casualtiesPerAttacker == nil) then
         casualtiesPerAttacker = {}
      end
      if(casualtiesPerAttacker[attacker] == nil) then
         casualtiesPerAttacker[attacker] = {
            ["Number-Killed"] = 0,
            ["Number-Captured"] = 0,
            ["Number-Wounded"] = 0,
            ["Number-Missing"] = 0
         }
      end
      casualtiesPerAttacker[attacker][typeToIncrement] =
         casualtiesPerAttacker[attacker][typeToIncrement] + 1
      
      casualtiesLeft = casualtiesLeft - 1
   end
   
   return numKilled, numCaptured, numWounded, numMissing
end

-- Calculates derived properties that are required to update the dynamic
-- properties controlled by this script. Returns the current values of these
-- properties.
-- Pre-tick derived properties:
--     Vulnerability
function calculatePreTickDerivedProperties(engineeringObjects)
   -- Get current posture
   local posture = this:getStateProperty("Posture")
   local postureMod = vulnerabilityPostureMod[posture]
   local moppLevel = this:getStateProperty("MOPP-Level")
   local moppMod = vulnerabilityMoppMod[moppLevel]
   
   -- Calculate vulnerability modification from engineering areas
   local loc = this:getLocation3D()
   local footprint = this:getStateProperty("Physical-Footprint")
   
   local engineeringVulMods = {}
   for objNum,engArea in pairs(engineeringObjects["areas"]) do
   
      local maxSizeFactor = engArea:getParameterProperty("Maximum-Relative-Size-Of-Effected")
      if(maxSizeFactor ~= nil) then
      
         local unitArea = footprint*footprint*math.pi
         local areaBoundingVol = engArea:getBoundingVolume()
         local objArea = areaBoundingVol:getForward() * areaBoundingVol:getRight()
         
         -- Area affects us if our center point is inside and we are smaller than the maximum
         -- relative size of the area (i.e. we are not too big to receive the effects)
         if(unitArea <= objArea*maxSizeFactor and
            engArea:isPointInside(loc)) then
            
            local vulnMods = engArea:getParameterProperty("Vulnerability-Modifiers")
            
            if(vulnMods ~= nil) then
            
               for combatType,vulnMod in pairs(vulnMods) do
                  
                  if(engineeringVulMods[combatType] == nil) then
                     engineeringVulMods[combatType] = 
                        engineeringObjectEffectiveModifier(engArea, vulnMod)
                  else
                     engineeringVulMods[combatType] = 
                        engineeringVulMods[combatType] * 
                        engineeringObjectEffectiveModifier(engArea, vulnMod)
                  end
               end                  
            end               
         end            
      end
   end

   -- Calculate vulnerability if posture has changed
   currentVulnerability = this:getStateProperty("Vulnerability")
   if (posture ~= previousPosture or
       moppLevel ~= previousMOPP or
       next(engineeringVulMods) ~= nil or
       (next(engineeringVulMods) == nil and previousEngineeringAreaVulnerabilityMod)) then 
      if DEBUG_DETAIL then
         printDebug("New posture ", posture)
         printDebug("New MOPP ", moppLevel)
      end
      for combatType, vuln in pairs(baseVulnerability) do
      
         local engVulnMod = engineeringVulMods[combatType]
         if (engVulnMod == nil) then engVulnMod = 1 end
         
         currentVulnerability[combatType].Vulnerability =
            postureMod * moppMod * engVulnMod * vuln.Vulnerability
            
         
         if DEBUG_DETAIL then
            printDebug("New vuln. modifier for combat type ", 
               combatType, ": \n  Posture mod: ", postureMod,
               "\n  MOPP mod: ", moppMod,
               "\n  Eng. obj. mod: ", engVulnMod,
               "\n  Final value: ", 
               currentVulnerability[combatType].Vulnerability)
         end
         currentVulnerability[combatType]["Defense-Factor"] =
            vuln["Defense-Factor"]
      end
      this:setStateProperty("Vulnerability", currentVulnerability)
   end
   
   -- Update our "previous" values for the next tick
   previousPosture = posture
   previousMOPP = moppLevel
   previousEngineeringAreaVulnerabilityMod = (next(engineeringVulMods) ~= nil)
   
   return currentVulnerability
end
   
-- Updates any dynamic properties controlled by this task. Returns the
-- current values of these properties.
-- Dynamic properties:
--     Health
--     Contamination
function updateDynamicProperties(vulnerability, attacks, attacksDefending,  
   engineeringObjects, nbcAreas)
   
   local health = this:getStateProperty("Health")
   
   -- Perform attrition
   local attritionAmount = 0
   local parent = this:getEmbarkedOn()
   if(parent:isValid()) then
      attritionAmount = calculateAttritionEmbarked(parent, health)
   else
      attritionAmount = calculateAttrition(attacks, attacksDefending,
         engineeringObjects, nbcAreas)
   end

   health = math.max(0, roundToInt(health - attritionAmount))
   this:setStateProperty("Health", health)
   
   local currentPosture = this:getStateProperty("Posture")
   if health > 0 and health <= healthForRout then
      if currentPosture ~= "Rout" then
         this:setStateProperty("Posture", "Rout")
         printWarn(vrf:trUtf8("Unit is in a rout."))
      end
   elseif currentPosture == "Rout" and health > 0 then
      this:setStateProperty("Posture", "Travel")
      printWarn(vrf:trUtf8("Unit is no longer in a rout."))
   end
   
   local contamination = this:getStateProperty("Contamination")
   if(attritionFromContamination == true) then
      this:setStateProperty("Contamination", contaminationType)
   end      
   
   if updateDestroyedStateBasedOnHealth then
      if(health == 0) then
         this:setDestroyed(true)
      elseif (this:isDestroyed()) then
         this:setDestroyed(false)
      end
   end
         
   return health
end

-- Rounds equipment and personnel numbers to the correct whole number.
function roundEquipmentAndPersonnel(numLeft)
   if (numLeft < 1) then
      -- Do not destroy the last one left until we are completely destroyed
      return math.ceil(numLeft)
   else
      -- Report only whole integer values
      return roundToInt(numLeft)
   end
end

-- Calculates remaining derived properties which are maintained by this script.
-- Derived properties:
--     Equipment
--     Weapons
--     Personnel-Officers
--     Personnel-WOs
--     Personnel-NCOs
--     Personnel-Enlisted
-- Dynamic properties (set here due to a dependency on some derived properties):
--     Number-Killed
--     Number-Captured
--     Number-Wounded
--     Number-Missing
--     Casualties-Per-Attacker
function calculateDerivedProperties(health, probabilityKill, probabilityCapture, probabilityWound)

   local healthPercent = health / baseHealth
   
   local casualtiesPerAttacker = this:getStateProperty("Casualties-Per-Attacker")
      
   -- Calculate attrition if health has changed
   if (health ~= previousHealth) then
   
      local previousHealthPercent = previousHealth / baseHealth
      
      -- Equipment
      for equipType, equip in pairs(baseEquipment) do
         local prevNumLeft = roundEquipmentAndPersonnel(equip.Count * previousHealthPercent)
         local numLeft = roundEquipmentAndPersonnel(equip.Count * healthPercent)
         
         if (numLeft ~= prevNumLeft) then
            -- Set the new value
            this:setStatePropertyMapItem("Equipment", equipType,
               { Count = numLeft })
         end
      end
   
      -- Weapons
      for weaponType, weapon in pairs(baseWeapons) do
         local prevNumLeft = roundEquipmentAndPersonnel(weapon.Count * previousHealthPercent)
         local numLeft = roundEquipmentAndPersonnel(weapon.Count * healthPercent)
         
         if (numLeft ~= prevNumLeft) then
            -- Set the new value
            this:setStatePropertyMapItem("Weapons", weaponType,
               { Count = numLeft })
         end
      end
      
      -- Personnel
      local prevOfficers = roundEquipmentAndPersonnel(baseOfficers * previousHealthPercent)
      local newOfficers = roundEquipmentAndPersonnel(baseOfficers * healthPercent)
      local prevWOs = roundEquipmentAndPersonnel(baseWOs * previousHealthPercent)
      local newWOs = roundEquipmentAndPersonnel(baseWOs * healthPercent)
      local prevNCOs = roundEquipmentAndPersonnel(baseNCOs * previousHealthPercent)
      local newNCOs = roundEquipmentAndPersonnel(baseNCOs * healthPercent)
      local prevEnlisted = roundEquipmentAndPersonnel(baseEnlisted * previousHealthPercent)
      local newEnlisted = roundEquipmentAndPersonnel(baseEnlisted * healthPercent)
      
      if( prevOfficers ~= newOfficers) then
         this:setStateProperty("Personnel-Officers", newOfficers)
      end
      if( prevWOs ~= newWOs) then
         this:setStateProperty("Personnel-WOs",  newWOs)
      end
      if( prevNCOs ~= newNCOs) then
         this:setStateProperty("Personnel-NCOs", newNCOs)
      end
      if( prevEnlisted ~= newEnlisted) then
         this:setStateProperty("Personnel-Enlisted", newEnlisted)
      end
      
      -- Casualties
      local numCasualties = math.max(0, previousOfficers - newOfficers) +
         math.max(0, previousWOs - newWOs) +
         math.max(0, previousNCOs - newNCOs) +
         math.max(0, previousEnlisted - newEnlisted)
      local numberKilled = this:getStateProperty("Number-Killed")
      local numberCaptured = this:getStateProperty("Number-Captured")
      local numberWounded = this:getStateProperty("Number-Wounded")
      local numberMissing = this:getStateProperty("Number-Missing")
      
      local newKilled, newCaptured, newWounded, newMissing =
         assignCasualties(numCasualties, casualtiesPerAttacker)
               
      this:setStateProperty("Number-Killed", numberKilled + newKilled)
      this:setStateProperty("Number-Captured", numberCaptured + newCaptured)
      this:setStateProperty("Number-Wounded", numberWounded + newWounded)
      this:setStateProperty("Number-Missing", numberMissing + newMissing)
      
      -- Update "previous" casualty counts
      previousOfficers = newOfficers
      previousWOs = newWOs
      previousNCOs = newNCOs
      previousEnlisted = newEnlisted
   end
   
   for attacker, attackerCasualties in pairs(casualtiesPerAttacker) do
      if(not engagedEnemies[attacker]) then
         casualtiesPerAttacker[attacker] = nil
      end
   end
   this:setStateProperty("Casualties-Per-Attacker", casualtiesPerAttacker)
   
   -- Update our "previous" values for the next tick
   previousHealth = health
end

-- Called each tick while this task is active.
function tick()
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Perform Attrition:",
         vrf:getSimulationTime()))
   end
   
   -- Get list of attacks and attacks defending
   local attacks = this:getStateProperty("Attacks")
   local attacksDefending = this:getStateProperty("Attacks-Defending")
   
   -- Calculate the maximum range attack against us to find
   -- the maximum distance an attacker is from us.
   local maxAttackerRange = 0
   for attackIndex, attack in pairs(attacksDefending) do
      local attacker = vrf:getSimObjectByUUID(attack.Attacker)
      if (attacker:isValid()) then
      
         local combatPower = attacker:getStatePropertyMapItem("Combat-Power", attack.Type)
         if(combatPower ~= nil and 
            maxAttackerRange < combatPower.Range and
            not attack.IsIndirect) then
            maxAttackerRange = combatPower.Range
         end
      end
   end      
   
   -- Get lists of all the engineering objects and NBC areas
   local footprint = this:getStateProperty("Physical-Footprint")
   local engineeringObjects = { ["areas"] = {},  ["lines"] = {},  ["points"] = {} }
   
   local nbcAreas = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), footprint,
      {types={EntityType.NbcArealObject()}})
   engineeringObjects["areas"] = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), footprint,
      {types={EntityType.EngineeringArealObject(), EntityType.EngineeringFixedSizeArealObject()}})
   -- For lines we also need to know about ones that are between us and our attackers
   engineeringObjects["lines"] = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), 
      footprint + maxAttackerRange,
      {types={EntityType.EngineeringLinearObject()}})
   engineeringObjects["points"] = vrf:getSimObjectsNearWithFilter(this:getLocation3D(), footprint,
      {types={EntityType.EngineeringPointObject()}})
      
   local vulnerability = calculatePreTickDerivedProperties(engineeringObjects)
   local health, probabilityKill, probabilityCapture, probabilityWound = 
      updateDynamicProperties(vulnerability, attacks, attacksDefending, 
      engineeringObjects, nbcAreas)
   calculateDerivedProperties(health, probabilityKill, probabilityCapture, probabilityWound)  

	-- Reset given the state of this flag being true, then reset flag to false
   if (this:getStateProperty("Reset-Killed-Captured-Wounded-Missing") == true) then
	  this:setStateProperty("Number-Killed", 0)
	  this:setStateProperty("Number-Captured", 0)
	  this:setStateProperty("Number-Wounded", 0)
	  this:setStateProperty("Number-Missing", 0)
	  this:setStateProperty("Reset-Killed-Captured-Wounded-Missing", false)
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

-- Called when this entity is destroyed
function entityDestroyed()
   -- Perform one last tick to try to properly assign damage and casualties,
   -- but don't change our destroyed state!
   updateDestroyedStateBasedOnHealth = false
   tick()
   updateDestroyedStateBasedOnHealth = true
   
   -- If still not completely destroyed, rectify that.
   local health = this:getStateProperty("Health")
   if health > 0 then
   
      -- Health
      this:setStateProperty("Health", 0)
      
      -- Personnel
      this:setStateProperty("Personnel-Officers", 0)
      this:setStateProperty("Personnel-WOs", 0)
      this:setStateProperty("Personnel-NCOs", 0)
      this:setStateProperty("Personnel-Enlisted", 0)
      
      -- Set killed based on the sum of the total number of base personnel minus those that are currently
      -- captured or missing.  The set wounded to 0

      local totalPersonnel = baseOfficers + baseWOs + baseNCOs + baseEnlisted
      local totalIgnored = this:getStateProperty("Number-Missing") + this:getStateProperty("Number-Captured") + this:getStateProperty("Number-Wounded")
      local totalKilled = totalPersonnel - totalIgnored

      this:setStateProperty("Number-Killed", totalKilled)

      -- Equipment
      for equipType, equip in pairs(baseEquipment) do
         this:setStatePropertyMapItem("Equipment", equipType,
            { Count = 0 })
      end
   
      -- Weapons
      for weaponType, weapon in pairs(baseWeapons) do
         this:setStatePropertyMapItem("Weapons", weaponType,
            { Count = 0 })
      end
   end
   
   -- Set altitude to 0 above terrain. Mainly for aircraft so that they aren't still
   -- flying when destroyed.
   local loc = this:getLocation3D()
   local terrainAlt = 0
   local terrainPagedIn = false
   terrainAlt, terrainPagedIn = vrf:getTerrainAltitude(loc:getLat(), loc:getLon())
   if terrainPagedIn then
      loc:setAlt(terrainAlt)
      this:setLocation3D(loc)
   end
   
end

-- Adds or updates a attack being applied against this unit.
function processAttack(attacker, combatType, strength, duration, 
	hitFactor, probKill, probCapture, probWound, isIndirectFire)
   
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Processing attack from %s.",
         vrf:getSimulationTime(),
         attacker:getName()))
   end

   local found = false

   if (hitFactor ~= AG_NOT_APPLICABLE) then 
      -- If there is a hit factor involved with this attack, determine
      -- if the attack hits.
      local currentVulnerability = baseVulnerability[combatType]["Defense-Factor"]
      if currentVulnerability ~= nil and
         not hitByAttack(hitFactor, currentVulnerability)  then

         printWarn(vrf:trUtf8("Attack from %1 misses."):arg(attacker:getName()))
         return -- ******* MISS, return without adding the attack ******
      end
   end   
   
   -- Check to see if this attack is already in the list, and should just
   -- be updated. Dont' check if duration is 0, since that is an instantaneous
   -- attack.
   if duration > 0 or duration < 0 then
      local currentAttack = this:getStatePropertyListItem("Attacks-Defending",
         { Attacker = attacker, 
           Type = combatType,
           IsIndirect = isIndirectFire })
      
      if(currentAttack ~= nil) then
         -- Update the strength
         local newAttack = {
            Strength = strength,
   --           HitFactor = hitFactor, -- Not used
            ProbabilityKill = probKill,
            ProbabilityCapture = probCapture,
            ProbabilityWound = probWound, }
         
         this:setStatePropertyListItem("Attacks-Defending",
            { Attacker = attacker, 
              Type = combatType,
              IsIndirect = isIndirectFire },
            newAttack)
         
         found = true
         if DEBUG_DETAIL then
            printDebug("Updating attack from ", attacker:getName(),
               ", type ", combatType)
         end
      end
   end
      
   if(not found) then
      if duration == 0 then
         -- Instantaneous attack; make it a 1-second attack.
         duration = 1.0
         -- Put something in the console so that the user knows an attack happened
         printWarn(vrf:trUtf8("Attack from %1 hits."):
            arg(attacker:getName()))
      end
      local currentTime = vrf:getSimulationTime()
      
      -- Compute completion time of this attack. Note that if timeComplete
      -- is Not Applicable, the attack does not complete until a 
      -- stop-attack is received.
      local timeComplete
      if duration == AG_NOT_APPLICABLE then
         timeComplete = AG_NOT_APPLICABLE -- indefinite duration
      else
         timeComplete = duration + currentTime
      end
      -- The index into the list doesn't matter. It will be lost with setStateProperty()
      local randomNumber = vrf:gaussian() --For some reason, it doesn't work to put this fn call in
                              -- the table constructor below
                              
      local newAttack = 
         { Type = combatType, 
           Strength = strength,
           Attacker = attacker,
           TimeStarted = currentTime,
           TimeComplete = timeComplete,
--           HitFactor = hitFactor, -- Not used
           ProbabilityKill = probKill,
           ProbabilityCapture = probCapture,
           ProbabilityWound = probWound,
           IsIndirect = isIndirectFire,
           CurrentRandomDraw = randomNumber}
           
      -- Add this new item to the list.
      -- Note: sometimes multiple instantaneous attacks will arrive between
      -- ticks, and so the list will have multiple entries from the same
      -- attacker.
      this:setStatePropertyListItem("Attacks-Defending",
         {}, newAttack)

      printInfo(vrf:trUtf8("%1   Defending new attack from %2"):
         arg(currentTime):arg(attacker:getName()))
      if DEBUG_DETAIL then
         printDebug(string.format("%.3f: Adding attack from %s, type %s, strength %.1f", 
            currentTime,
            attacker:getName(), combatType, strength))
         printDebug(string.format(".  Attack until time %.3f",
            timeComplete))
      end
   end
end

-- Removes an existing attack being applied against this unit.
function processStopAttack(attacker, combatType, strength, isIndirectFire)
   
   -- Set an end time for the attack the attack
   local currentTime = vrf:getSimulationTime()
   local endingAttack = { TimeComplete = currentTime }
   if(this:setStatePropertyListItem("Attacks-Defending",
      { Attacker = attacker, 
        Type = combatType,
        IsIndirect = isIndirectFire },
      endingAttack)) then
      
      if attacker:isValid() then
         printInfo(vrf:trUtf8("%1 Stopping attack from %2"):
            arg(vrf:getSimulationTime()):arg(attacker:getName()))
      else
         printInfo(vrf:trUtf8("%1 Stopping attack from unknown attacker"):
            arg(vrf:getSimulationTime()))
      end
   end
        
end

-- Called whenever the entity receives an Influence interaction while
-- this task is active.
--   influencer is the SimObject sending the Influence.
--   influenceName is a string identifying the kind of Influence.
--   influenceParams is a table of optional Influence parameters.
function receiveInfluence(influencer, influenceName, influenceParams)

   local isIndirectFire = (influenceName == "Engagement.IndirectFire")
   if(isIndirectFire or influenceName == "Engagement") then
      if(influenceParams.StopInfluence) then
         processStopAttack(influencer, influenceParams.InfluenceType, influenceParams.Strength, isIndirectFire)
      else
         processAttack(influencer, influenceParams.InfluenceType, influenceParams.Strength,
            influenceParams.Duration, influenceParams.HitFactor,
            influenceParams.ProbabilityKilled, influenceParams.ProbabilityCaptured,
            influenceParams.ProbabilityWounded, isIndirectFire)
      end
   end

end
