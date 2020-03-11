-- This script periodically checks the level of supplies and updates
-- aggregated state variables: Combat-Effectiveness, Has-OL  (oil & lubricant),
-- has-Fuel and Has-Food-Water. It determines what POL supplies are relevant
-- by checking their usage rates in the parameter properties.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"


local usesMotorGas
local usesDieselFuel
local usesAviationFuel
local usesOil
local usesLubricant
local usesSomePOL

local ammoTypesInUse

local baseHealth
local baseMotorGas
local baseAviationFuel
local baseDieselFuel
local baseOil
local baseLubricant
local baseTotalWeapons
local baseTotalPersonnel
local resetTickTimeAfterFirstTick = false

prevHadOil = true
prevHadLubricant = true
prevHadFuel = true
prevHadFood = true
prevHadWater = true
local prevHadAmmo = {}

-- Add callbacks for when state properties are set.
-- This will allow the script to respond quickly to changes in health 
-- and be able to do so while the scenario is paused.
vrf:addPostSetDataCallback("set-state-properties", "updateCombatEffectiveness");

-- Add callbacks for when unit is restored.
-- This allows us to make sure that status which is NA for the unit (for instance,
-- if it does not use POL) are not incorrectly set to Fully Operational.
vrf:addPostSetDataCallback("set-restore", "restoreUnit");

-- Call tick when  set state properties is done to allow the script to
-- immediately respond to changes in health.
function updateCombatEffectiveness(parameters)

   local stateProps = parameters["state-properties"]
   if stateProps ~= nil then
      if stateProps["Health"] ~= nil or
         stateProps["Motor-Gas"] ~= nil or
         stateProps["Aviation-Fuel"] ~= nil or
         stateProps["Diesel-Fuel"] ~= nil or
         stateProps["Oil"] ~= nil or
         stateProps["Lubricant"] ~= nil or
         stateProps["Ammunition-Categories"] ~= nil or
         stateProps["Food"] ~= nil or
         stateProps["Water"] ~= nil
         then
         tick();
      end
   end
end

function restoreUnit(parameters)
   if (not this:isDisaggregatedUnit()) then
      getParamVariables()
   end
end

function getParamVariables()
   -- parameter-data storage. This data is static, so it can be stored at init time.
   baseHealth = this:getParameterProperty("Base-Health")
   baseMotorGas = this:getParameterProperty("Base-Motor-Gas")
   baseAviationFuel = this:getParameterProperty("Base-Aviation-Fuel")
   baseDieselFuel = this:getParameterProperty("Base-Diesel-Fuel")
   baseOil = this:getParameterProperty("Base-Oil")
   baseLubricant = this:getParameterProperty("Base-Lubricant")
   local baseAmmo = this:getParameterProperty("Base-Ammunition")
   local motorGasUsagePerSec = this:getParameterProperty("Motor-Gas-Usage-Per-Second")
   local motorGasUsagePerM = this:getParameterProperty("Motor-Gas-Usage-Per-Meter")
   local aviationFuelUsagePerSec = this:getParameterProperty("Aviation-Fuel-Usage-Per-Second")
   local aviationFuelUsagePerM = this:getParameterProperty("Aviation-Fuel-Usage-Per-Meter")
   local dieselFuelUsagePerSec = this:getParameterProperty("Diesel-Fuel-Usage-Per-Second")
   local dieselFuelUsagePerM = this:getParameterProperty("Diesel-Fuel-Usage-Per-Meter")
   local oilUsagePerSec = this:getParameterProperty("Oil-Usage-Per-Second")
   local lubricantUsagePerSec = this:getParameterProperty("Lubricant-Usage-Per-Second")
   local baseOfficers = this:getParameterProperty("Base-Personnel-Officers")
   local baseWOs = this:getParameterProperty("Base-Personnel-WOs")
   local baseNCOs = this:getParameterProperty("Base-Personnel-NCOs")
   local baseEnlisted = this:getParameterProperty("Base-Personnel-Enlisted")
   local baseWeapons = this:getParameterProperty("Base-Weapons")
   
   baseTotalPersonnel = baseOfficers + baseWOs + baseNCOs + baseEnlisted
   
   if baseTotalPersonnel == 0 then
      this:setStateProperty("Personnel-Status", "NA")
   end
   
   baseTotalWeapons = 0
   for weaponName, weapon in pairs(baseWeapons) do
      baseTotalWeapons = baseTotalWeapons + weapon.Count
   end
   
   if baseTotalWeapons == 0 then
      this:setStateProperty("Weapons-Status", "NA")
   end

   -- Figure out what type of fuel this unit uses.
   usesMotorGas = false
   usesDieselFuel = false
   usesAviationFuel = false
   usesOil = false
   usesLubricant = false
   
   if (motorGasUsagePerSec ~= nil and motorGasUsagePerM ~= nil) then
      if(motorGasUsagePerSec > 0 or motorGasUsagePerM > 0) then
         usesMotorGas = true
      end
   end
      
   if (dieselFuelUsagePerSec ~= nil and dieselFuelUsagePerM ~= nil) then
      if(dieselFuelUsagePerSec > 0 or dieselFuelUsagePerM > 0) then
         usesDieselFuel = true
      end
   end
      
   if (aviationFuelUsagePerSec ~= nil and aviationFuelUsagePerM ~= nil) then
      if(aviationFuelUsagePerSec > 0 or aviationFuelUsagePerM > 0) then
         usesAviationFuel = true
      end
   end
      
   if (oilUsagePerSec ~= nil and oilUsagePerSec > 0) then
      usesOil = true
   end
      
   if(lubricantUsagePerSec ~= nil and lubricantUsagePerSec > 0) then
      usesLubricant = true
   end
   
   usesSomePOL = usesOil or usesLubricant or usesAviationFuel or usesDieselFuel or usesMotorGas
   if not usesSomePOL then
      this:setStateProperty("POL-Status", "NA")
   end
   
   -- Figure out what ammo types the unit uses.
   ammoTypesInUse = {}
   prevHadAmmo = {}
   
   -- Find ammo types that we use in direct fire attacks
   local ammoUsages = this:getParameterProperty("Ammunition-Usage")
   if ammoUsages ~= nil then
      for ammoType, ammoUsage in pairs(ammoUsages) do
         if(ammoUsage > 0) then
            ammoTypesInUse[ammoType] = true
            prevHadAmmo[ammoType] = true
         end
      end
   end
   
   -- Now find indirect fire ammo as well
   if baseAmmo ~= nil then
      for ammoName, ammoInfo in pairs(baseAmmo) do
         if(ammoInfo.Type == "For Weapon System") then
            ammoTypesInUse[ammoName] = true
            prevHadAmmo[ammoName] = true
         end         
      end
   end
   
   if next(ammoTypesInUse) == nil then
      this:setStateProperty("Ammunition-Status", "NA")
   end
   
end

-- The parameter variables are declared local (above) and then initialized in
-- global code rather than in init(). This way, if a scenario is saved, but then
-- this entity's configuration is changed, the new configuration will be used
-- when the scenario is loaded.
-- This isn't necessary for disaggregated units, since they get their params
-- every tick
if (not this:isDisaggregatedUnit()) then
   getParamVariables()
else
   -- Need to update to get parameter properties updated correctly
   this:updateStateAndParameterProperties()
end

-- Called when the task first starts. Never called again.
function init()

   resetTickTimeAfterFirstTick = true
   
   -- Precalculate summation of all subordinates
   if (this:isDisaggregatedUnit()) then
      calculatePreTickDerivedProperties()
   end

   calculateDerivedProperties()
end

-- Called init() as there is some state that still need to be initialized
function loadState()
   init()
end

-- Calculates derived properties that are required to update the dynamic
-- properties controlled by this script. Returns the current values of these
-- properties.
-- Pre-tick derived properties:
--     For a disaggregated units, the component units may have changed since
--     last tick, and thus the parameter properties; so get them.
function calculatePreTickDerivedProperties()
   if (this:isDisaggregatedUnit()) then
     this:updateStateAndParameterProperties()
     getParamVariables()
   end
end
   
-- Updates any dynamic properties controlled by this task. Returns the
-- current values of these properties.
-- Dynamic properties:
--     None
function updateDynamicProperties()
end


-- Returns the minimum of the two combat effectiveness levels
function minimumCombatEffectiveness(ce1, ce2)   
   if(ce1 == "Not Operational" or ce2 == "Not Operational") then
      return "Not Operational"
   elseif(ce1 == "Marginally Operational" or ce2 == "Marginally Operational") then
      return "Marginally Operational"
   elseif(ce1 == "Substantially Operational" or ce2 == "Substantially Operational") then
      return "Substantially Operational"
   elseif(ce1 == "Fully Operational" or ce2 == "Fully Operational") then
      return "Fully Operational"
   end
   
   return "NA"
end

-- Calculates remaining derived properties which are maintained by this script.
-- Derived properties:
--     Combat-Effectiveness
--     Personnel-Status
--     POL-Status
--     Ammunition-Status
--     Weapons-Status
--     Has-Fuel
--     Has-OL
--     Has-Food-Water
function calculateDerivedProperties()
      
   -- Check health
   local health = this:getStateProperty("Health")
   local healthFraction = 1
   if health ~= nil and baseHealth ~= nil then
      healthFraction = health/baseHealth
   end

   -- Initialize combat effectiveness based on health
   local combatEffectiveness = CombatEffectiveness.getCombatEffectivenessForHealth(healthFraction)
   printDebug(string.format("Update status: health %d, base %d, fraction %f; effectiveness %s\n",
      health, baseHealth, healthFraction, combatEffectiveness))
   
   local polEffectiveness = "NA"
   local ammmoEffectiveness = "NA"
   local personnelEffectiveness = "NA"
   local weaponsEffectiveness = "NA"
   
   -- Check resources. Keep in mind that that if we are already ineffective,
   -- having lots of fuel won't change that.
      
   local hasOil = true
   local hasLubricant = true
   local hasFuel = true
   
   -- Check our fuel, oil, and lubricant.
   if usesSomePOL then
      if usesMotorGas then
         local amount = this:getStateProperty("Motor-Gas")
         
         hasFuel = hasFuel and (amount.Amount > 0)
         if polEffectiveness ~= "Not Operational" then
            local fraction = 0
            if( baseMotorGas.Amount > 0 ) then
               fraction = amount.Amount/baseMotorGas.Amount
            end
            
            local effectiveness = CombatEffectiveness.getCombatEffectivenessForFuel(fraction)
            
            polEffectiveness = minimumCombatEffectiveness(polEffectiveness, 
               effectiveness)
         end
      end
      
      if usesAviationFuel then
         local amount = this:getStateProperty("Aviation-Fuel")
         
         hasFuel = hasFuel and (amount.Amount > 0)
         if polEffectiveness ~= "Not Operational" then
            local fraction = 0
            if( baseAviationFuel.Amount > 0 ) then
               fraction = amount.Amount/baseAviationFuel.Amount
            end
            
            local effectiveness = CombatEffectiveness.getCombatEffectivenessForFuel(fraction)
            
            polEffectiveness = minimumCombatEffectiveness(polEffectiveness, 
               effectiveness)
         end
      end
      
      if usesDieselFuel then
         local amount = this:getStateProperty("Diesel-Fuel")
         
         hasFuel = hasFuel and (amount.Amount > 0)
         if polEffectiveness ~= "Not Operational" then
            local fraction = 0
            if( baseDieselFuel.Amount > 0 ) then
               fraction = amount.Amount/baseDieselFuel.Amount
            end
            
            local effectiveness = CombatEffectiveness.getCombatEffectivenessForFuel(fraction)
            
            polEffectiveness = minimumCombatEffectiveness(polEffectiveness, 
               effectiveness)
         end
      end
      
      if prevHadFuel ~= hasFuel then      
         this:setStateProperty("Has-Fuel", hasFuel)
         prevHadFuel = hasFuel
         if not hasFuel then
            printWarn(vrf:trUtf8("Out of fuel."))
         end
      end
      
      if usesOil then
         local amount = this:getStateProperty("Oil")
         hasOil = (amount.Amount > 0)
         
         if polEffectiveness ~= "Not Operational" then
            local fraction = 0
            if( baseOil.Amount > 0 ) then
               fraction = amount.Amount/baseOil.Amount
            end
            
            local effectiveness = CombatEffectiveness.getCombatEffectivenessForOil(fraction)
            
            polEffectiveness = minimumCombatEffectiveness(polEffectiveness, 
               effectiveness)
         end
      end
      
      if prevHadOil and not hasOil then
         printWarn(vrf:trUtf8("Out of oil."))
      end
      
      if usesLubricant then
         local amount = this:getStateProperty("Lubricant")
         hasLubricant = (amount.Amount > 0)
         
         if polEffectiveness ~= "Not Operational" then
            local fraction = 0
            if( baseLubricant.Amount > 0 ) then
               fraction = amount.Amount/baseLubricant.Amount
            end
            
            local effectiveness = CombatEffectiveness.getCombatEffectivenessForLubricant(fraction)
            
            polEffectiveness = minimumCombatEffectiveness(polEffectiveness, 
               effectiveness)
         end
      end
      
      if prevHadLubricant and not hasLubricant then
         printWarn(vrf:trUtf8("Out of lubricant."))
      end
      
      local prevHadOL = (prevHadOil and prevHadLubricant)
      local hasOL = (hasOil and hasLubricant)
      if prevHadOL ~= hasOL then      
         this:setStateProperty("Has-OL", hasOL)
      end
      prevHadOil = hasOil
      prevHadLubricant = hasLubricant
         
      this:setStateProperty("POL-Status", polEffectiveness)
   end
   
   -- Update combat effectiveness based on POL levels
   combatEffectiveness = minimumCombatEffectiveness(combatEffectiveness, 
      polEffectiveness)
   
   -- Check food and water   
   local foodSupply = this:getStateProperty("Food")
   local hasFood = false
   if foodSupply ~= nil then
      hasFood = foodSupply.Amount > 0
   end
   
   local waterSupply = this:getStateProperty("Water")
   local hasWater = false
   if waterSupply ~= nil then
      hasWater = waterSupply.Amount > 0
   end
   
   if prevHadFood and not hasFood then
      printWarn(vrf:trUtf8("Out of food."))
   end
   
   if prevHadWater and not hasWater then
      printWarn(vrf:trUtf8("Out of water."))
   end
   
   local prevHadFW = (prevHadFood and prevHadWater)
   local hasFW = (hasFood and hasWater)
   if prevHadFW ~= hasFW then      
      this:setStateProperty("Has-Food-Water", hasFW)
   end
   prevHadFood = hasFood
   prevHadWater = hasWater
   
   -- Check our ammo.
   if ammoTypesInUse ~= nil and next(ammoTypesInUse) ~= nil then
      local ammo = this:getStateProperty("Ammunition-Categories")
      
      if ammo ~= nil then 
         for ammoType, ammoAmount in pairs(ammo) do
            if(ammoTypesInUse[ammoType]) then         
               local fraction = 0
               if( ammoAmount.BaseCount > 0 ) then
                  fraction = ammoAmount.Count/ammoAmount.BaseCount
                  
                  local hasAmmo = (ammoAmount.Count >= 1)
                  if(hasAmmo ~= prevHadAmmo[ammoType]) then
                     if(not hasAmmo) then
                        printWarn(vrf:trUtf8("Out of ammunition: %1"):arg(ammoType))
                     end
                     prevHadAmmo[ammoType] = (ammoAmount.Count >= 1)
                  end
               end
               
               ammmoEffectiveness = minimumCombatEffectiveness(ammmoEffectiveness, 
                  CombatEffectiveness.getCombatEffectivenessForAmmunition(fraction))
            end
         end
      end
      
      this:setStateProperty("Ammunition-Status", ammmoEffectiveness)
   end
   
   -- Update combat effectiveness based on ammo levels
   combatEffectiveness = minimumCombatEffectiveness(combatEffectiveness, 
      ammmoEffectiveness)
   
   -- Set overall combat effectiveness
   this:setStateProperty("Combat-Effectiveness", combatEffectiveness)
      
   -- Check personnel. Do not update overall combat effectiveness based on personnel.
   -- Health takes care of this.
   if baseTotalPersonnel > 0 then
      local officers = this:getStateProperty("Personnel-Officers")
      local WOs = this:getStateProperty("Personnel-WOs")
      local NCOs = this:getStateProperty("Personnel-NCOs")
      local enlisted = this:getStateProperty("Personnel-Enlisted")
   
      local totalPersonnel = officers + WOs + NCOs + enlisted
      local fraction = totalPersonnel/baseTotalPersonnel
      
      local effectiveness = CombatEffectiveness.getCombatEffectivenessForHealth(fraction)
         
      this:setStateProperty("Personnel-Status", effectiveness)
   end
   
   -- Check weapons. Do not update overall combat effectiveness based on weapons.
   -- Health takes care of this.
   if baseTotalWeapons > 0 then
      local weapons = this:getStateProperty("Weapons")
      local totalWeapons = 0
      for weaponName, weapon in pairs(weapons) do
         totalWeapons = totalWeapons + weapon.Count
      end      
      local fraction = totalWeapons/baseTotalWeapons
      
      local effectiveness = CombatEffectiveness.getCombatEffectivenessForHealth(fraction)
         
      this:setStateProperty("Weapons-Status", effectiveness)
   end
   
   return combatEffectiveness
   
end

-- Called each tick while this task is active.
function tick()
      
   calculatePreTickDerivedProperties()
   updateDynamicProperties()
   calculateDerivedProperties()
   
   if (resetTickTimeAfterFirstTick) then
      -- Set the tick period for this script.
      if (this:isDisaggregatedUnit()) then
         vrf:setTickPeriod(60)
      else
         vrf:setTickPeriod(10)
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

-- Called when this entity is destroyed
function entityDestroyed()   
   this:setStateProperty("Combat-Effectiveness",
      CombatEffectiveness.getCombatEffectivenessForHealth(0))
      
   if baseTotalPersonnel > 0 then
      this:setStateProperty("Personnel-Status", "Not Operational")
   end
      
   if baseTotalWeapons > 0 then
      this:setStateProperty("Weapons-Status", "Not Operational")
   end
      
   if next(ammoTypesInUse) ~= nil then
      this:setStateProperty("Ammunition-Status", "Not Operational")
   end
      
   if usesSomePOL then
      this:setStateProperty("POL-Status", "Not Operational")
   end
   
end
