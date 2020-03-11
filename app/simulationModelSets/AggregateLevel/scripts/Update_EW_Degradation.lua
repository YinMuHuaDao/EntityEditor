-- Perform_Attrition.lua
-- Copyright 11/2013 by VT-MAK
--
-- This file contains the script used to compute attrition due to attacks.
-- It is a "background" script that runs all of the time on a unit.
-- The script receives influences and processes Engagement (and 
-- Engagement.IndirectFire) types.

-- Set this to true to dump more info to the entity debug console.
DEBUG_DETAIL = true

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- *********** Constants used in the calculations
-- Evaluation inverval, in seconds
TICK_PERIOD = 5

-- Choice of two algorithms:
-- SUM_ATTACKS means that the strengths of all the attacks of a given type
-- are summed before comparing against the defense.
-- MAX_OF_ATTACKS means that the maximum strength attack is used alone.
COMBINE_ATTACKS = "SUM_ATTACKS"

-- Standard deviation for attack strength random variation.
-- The EW strength random variation modifier, which is multiplied by the 
-- EW attack strength, is drawn from a log-normal distribuition.
-- About 68% of the modifier values will be between +- one standard
-- deviation. The desired range for 68% of values, i.e. the level of 
-- variability, can be used to compute the desired SD, e.g:
-- 68% range		SD (= ln(rangeMax))
-- [0.91, 1.1]		0.095
-- [0.8,  1.25]	0.223
-- [0.67, 1.5]		0.405
-- [0.5,  2.0]		0.693
VARIATION_SD = 0.1

-- Random variation in strength for each attack changes only at
-- a specified time interval, regardless of what the script tick
-- interval is. In seconds.
-- A more frequent random draw will produce results closer to average.
RAND_DRAW_INTERVAL = 30

-- *********** Global Variables. 

-- Periodically updated random numbers used in probability calculations
local randomUpdateTime = -1

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(TICK_PERIOD)
end

-- Calculates derived properties that are required to update the dynamic
-- properties controlled by this script. Returns the current values of these
-- properties.
-- Pre-tick derived properties:
--
function calculatePreTickDerivedProperties()
end

-- Compute the degree to which the EW attack is successful.
-- The ratio (in [0, inf]) of attack to defense is passed through log & sigmoid
-- functions to produce a result in [0.0, 1.0]. If attack = defense,
-- the result is 0.5.
-- If defense < 1, it is set to 1.
function computeEffect(attack, defense)
   if defense == nil then
      return 1.0
   end
   defense = math.max(defense, 1.0)
   attack = math.max(attack, 0.0)
   
   local ratio = attack/defense
   -- Raise ratio to 4th power. This happens to be an exponent that
   -- will result in about a 1% increase in probability for a 1%
   -- increase in ratio; e.g. a ratio of 1.01 results in a probability
   -- of about 51%. (The relative incremental change decreases
   -- for ratios much different from 1.0.)
   ratio = ratio * ratio
   ratio = ratio * ratio

   return ratio/(1.0 + ratio)
end  
   
-- Updates any dynamic properties controlled by this task. 
-- Returns the value of intermediate calculations that are not
-- stored as part of state: a table with a "Comms" entry
-- giving the comms jamming effect fraction, and a "Radar"
-- entry giving the net Radar attack strength being received.
function updateDynamicProperties()
   local netAttackStrength = {comms = 0, radar = 0}
   local effects = {Comms = 0, Radar = 0}
   local currentAttacksDefending = this:getStateProperty("EW-Attacks-Defending")
   if currentAttacksDefending == nil then
      currentAttacksDefending = {}
   end
   local updateRandomDraw = false
   local currentTime = vrf:getSimulationTime()
   if currentTime > randomUpdateTime then
      randomUpdateTime = currentTime + RAND_DRAW_INTERVAL
      updateRandomDraw = true
   end

   for attackIndex, attack in pairs(currentAttacksDefending) do
      if updateRandomDraw then
         local randomNumber = vrf:gaussian() 
         -- Create and store the log normal-distributed number
         attack["CurrentRandomDraw"] = math.exp(randomNumber * VARIATION_SD)
      end
      local strength = attack["Strength"] *
         attack["CurrentRandomDraw"]
      
      if DEBUG_DETAIL then
         printDebug(string.format(".  Attacker %s, type %s, nominal strength %.1f",
            attack.Attacker, attack.Type, attack.Strength))
         printDebug(string.format(".   Random draw %f, net strength %f",
            attack["CurrentRandomDraw"], strength))
      end
      -- Two possible algorithms: sum attacks, or take
      -- the strongest attack.
      
      if netAttackStrength[attack["Type"]] == nil then
         netAttackStrength[attack["Type"]] = 0
      end
      if COMBINE_ATTACKS == "SUM_ATTACKS" then
         netAttackStrength[attack["Type"]] = 
            netAttackStrength[attack["Type"]]+
            strength
      elseif COMBINE_ATTACKS == "MAX_OF_ATTACKS" then
         if netAttackStrength[attack["Type"]] < strength then
            netAttackStrength[attack["Type"]] = strength
         end
      else
         printWarn("Update EW Degradation: no attack combination rule defined")
      end
      
   end   
   local defense = this:getParameterProperty("Base-EW-Defense-Strength")
   
   -- Radar jamming effects are computed by each sensor (in C++) or weapon individually,
   -- based on their individual defense factors. Therefore we leave just the net
   -- jamming attack strength in the Radar effects.
   effects["Comms"] = computeEffect(netAttackStrength["comms"], defense)
   effects["Radar"] = netAttackStrength["radar"]
   return effects
end

-- Compute the jamming level as a percentage,
-- corresponding to a given jamming effect fraction.
function percent(effects, jamType)
   local effect = math.max(effects[jamType], 0)
   effect = math.min(effect, 1.0)
   return effect * 100
end

-- Calculates remaining derived properties which are maintained by this script.
-- Input: table of jamming types and effect values.
-- Derived properties:
--    EW-Comms-Degradation-Percent
--    Radar-Jamming-Strength-Receiving
function calculateDerivedProperties(effects)
   local commsResult = percent(effects, "Comms")
   local radarResult = effects["Radar"]
   this:setStateProperty("EW-Comms-Degradation-Percent", 
      commsResult)
   this:setStateProperty("Radar-Jamming-Strength-Receiving",
      radarResult)      
   if DEBUG_DETAIL then
      printDebug(string.format(".   Comms degradation: %d%%; radar jamming strength received: %f",
         commsResult, radarResult))
   end
end

-- Called each tick while this task is active.
function tick()
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Update EW Degradation",
         vrf:getSimulationTime()))
   end
   calculatePreTickDerivedProperties() -- Does nothing
   local effects = updateDynamicProperties()
   calculateDerivedProperties(effects)  
   
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

-- Adds or updates a attack being applied against this unit.
function processAttack(attacker, combatType, strength)
   
   printDebug(string.format("\n%.3f Processing EW attack from %s.",
      vrf:getSimulationTime(),
      attacker:getName()))
   
   currentAttacksDefending = this:getStateProperty("EW-Attacks-Defending")
   local found = false

   -- See if the attack is already ongoing
   for attackIndex,attack in pairs(currentAttacksDefending) do
      if(attacker:getUUID() == attack.Attacker and 
         combatType == attack.Type) then
         -- Update the strength
         attack.Strength = strength
         found = true
         if DEBUG_DETAIL then
            printDebug("Updating attack from ", attack.Attacker,
               ", type ", attack.Type, ", strength ", strength)
         end
         break
      end
   end
   
   if(not found) then
   
      local randomNumber = vrf:gaussian() 
      -- Create and store the log normal-distributed number
      randomNumber = math.exp(randomNumber * VARIATION_SD)
                              
      table.insert(currentAttacksDefending, 
         { Type = combatType, 
           Strength = strength,
           Attacker = attacker,
           CurrentRandomDraw = randomNumber} )
           
      if DEBUG_DETAIL then
         local currentTime = vrf:getSimulationTime() 
         printDebug(string.format(".   Adding attack from %s, type %s, strength %.1f", 
            attacker:getName(), combatType, strength))
      else
         printInfo("Defending new EW attack from ", attacker)      
      end
   end
   
   -- Set the updated list
   this:setStateProperty("EW-Attacks-Defending", currentAttacksDefending)
end

-- Removes an existing attack being applied against this unit.
function processStopAttack(attacker, combatType, strength)
   printDebug(string.format("\n%.3f Processing stop EW attack",
      vrf:getSimulationTime()))
      
   -- See if we can find the attack
   currentAttacksDefending = this:getStateProperty("EW-Attacks-Defending")
   for attackIndex,attack in pairs(currentAttacksDefending) do
      if attacker:getUUID() == attack.Attacker and
         combatType == attack.Type then
         -- Found it. Remove it.
         currentAttacksDefending[attackIndex] = nil
         this:setStateProperty("EW-Attacks-Defending", currentAttacksDefending)
         if DEBUG_DETAIL then
            printDebug("Stopping EW attack from ", attacker:getName(), 
               ", type ", combatType)
         end
         break
      end
   end
   
end

-- Called whenever the entity receives an Influence interaction while
-- this task is active.
--   influencer is the SimObject sending the Influence.
--   influenceName is a string identifying the kind of Influence.
--   influenceParams is a table of optional Influence parameters.
function receiveInfluence(influencer, influenceName, influenceParams)

   if(influenceName == "Jamming") then
      if(influenceParams.StopInfluence) then
         processStopAttack(influencer, influenceParams.InfluenceType, influenceParams.Strength)
      else
         processAttack(influencer, influenceParams.InfluenceType, influenceParams.Strength)
      end
   end
end
