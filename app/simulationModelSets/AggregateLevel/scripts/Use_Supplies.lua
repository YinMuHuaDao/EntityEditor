-- This script models the use and resupply of supplies and ammunition.

-- Set to true to turn on detailed debugging info to the 
-- entity debug console
DEBUG_DETAIL = true

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.


-- List of active supply units for this unit
activeSuppliers = {}

-- parameter-data storage. This data is static, so it can be stored at init time.
local baseHealth = this:getParameterProperty("Base-Health")
local healthResupplyRate = this:getParameterProperty("Health-Auto-Resupply-Rate")
      
local baseAmmunition = this:getParameterProperty("Base-Ammunition")
local ammunitionUsage = this:getParameterProperty("Ammunition-Usage")
local ammoResupplyRates = this:getParameterProperty("Ammunition-Auto-Resupply")

local baseFood = this:getParameterProperty("Base-Food")
local foodUsagePerSec = this:getParameterProperty("Food-Usage-Per-Second")
local baseWater = this:getParameterProperty("Base-Water")
local waterUsagePerSec = this:getParameterProperty("Water-Usage-Per-Second")
local baseGas = this:getParameterProperty("Base-Motor-Gas")
local gasUsagePerSec = this:getParameterProperty("Motor-Gas-Usage-Per-Second")
local gasUsagePerM = this:getParameterProperty("Motor-Gas-Usage-Per-Meter")
local baseAviationFuel = this:getParameterProperty("Base-Aviation-Fuel")
local aviationFuelUsagePerSec = this:getParameterProperty("Aviation-Fuel-Usage-Per-Second")
local aviationFuelUsagePerM = this:getParameterProperty("Aviation-Fuel-Usage-Per-Meter")
local baseDiesel = this:getParameterProperty("Base-Diesel-Fuel")
local dieselUsagePerSec = this:getParameterProperty("Diesel-Fuel-Usage-Per-Second")
local dieselUsagePerM = this:getParameterProperty("Diesel-Fuel-Usage-Per-Meter")
local baseOil = this:getParameterProperty("Base-Oil")
local oilUsagePerSec = this:getParameterProperty("Oil-Usage-Per-Second")
local baseLubricant = this:getParameterProperty("Base-Lubricant")
local lubricantUsagePerSec = this:getParameterProperty("Lubricant-Usage-Per-Second")

local baseResources = this:getParameterProperty("Base-Resources")

-- Get posture combat power modifiers to modulate the ammo expenditure
-- based on posture. Ditto for speed modifiers and POL usage rate.
local postureModifiers = this:getParameterProperty("Combat-Posture-Modifier")
local postureSpeedModifiers = this:getParameterProperty(
   "MaximumSpeed-Posture-Modifier")

-- Comparison values stored from previous tick
previousPeriodicResupplyTime = 0
previousHealth = baseHealth
previousResources = {}
   
previousUpdateTime = vrf:getSimulationTime()

-- There are several types of expendables that can be used and resupplied:
-- the fixed categories of Food, Water, ...; 
-- ammunition in fixed categories of Anti-Tank, ...;
-- large-munitions (i.e., the single munitions launched in IF, missile
--      attacks, etc.; all put in this one category);
-- and resources, which each have their own name.
-- The table myAmmoCategories below 
-- records the names of the fixed ammo categories
-- that this unit is configured with. Supplies that
-- don't match entries in this tables, or "Large-Munition" or the fixed
-- categories "Food", ... , or the names in baseResources, are ignored.

-- Use the combat power table to get names of the fixed ammo categories--
-- just in case categories are ever added or subtracted from VRF.
local fixedCategoryNames = {}
local basePower = this:getParameterProperty("Base-Combat-Power")
if basePower ~= nil then
   local name, val
   for name, val in pairs(basePower) do
      fixedCategoryNames[name]= true
   end
end

-- Add callbacks for when state properties are set, and when
-- set restore happens. This will allow the script to respond
-- to these changes, and keep the resources updated, while 
-- the scenario is paused.
vrf:addPostSetDataCallback("set-state-properties", "updateResources");
vrf:addPostSetDataCallback("set-restore", "updateResources");

local ammoCategoriesToIgnore = {}

-- Call tick when set restore or set state properties
-- is done to allow the script to immediately respond to these
-- changes.
function updateResources(parameters)

   -- If any ammo was set, we don't want to destroy or use it this
   -- tick, thus overriding the change the user made.
   local stateProps = parameters["state-properties"]
   if stateProps ~= nil then
      local ammmoCats = stateProps["Ammunition-Categories"]
      if ammmoCats ~= nil then
         for ammoType, ammoCat in pairs(ammunitionCategories) do
            ammoCategoriesToIgnore[ammoType] = true
         end
      end
   end
   
   tick();

   ammoCategoriesToIgnore = {}
end

-- Now determine which of these categories this unit is configured with.
local myAmmoCategories = {}

if baseAmmunition ~= nil then
   local name, val
   for name, val in pairs(baseAmmunition) do
      if fixedCategoryNames[val.Type] then -- Otherwise, it's a large munition
         myAmmoCategories[val.Type] = true
      end
   end
end

-- A table for convenience to look up base amounts by name--since the properties
-- list them separately rather than in a map like resources. 
-- Note that these names must match the parameter property names for food, water, 
-- etc. supplies, which must in turn match the names given by the resupplyController
-- to the entries in Supplies-Offered list.
local baseInfo = {["Food"] = baseFood, 
   ["Water"] = baseWater,
   ["Motor-Gas"] = baseGas,
   ["Aviation-Fuel"] = baseAviationFuel,
   ["Diesel-Fuel"] = baseDiesel,
   ["Oil"] = baseOil,
   ["Lubricant"] = baseLubricant}

-- Remember if there are is-airborne properties, and if not,
-- don't keep trying to get them every tick.
local isGround = true
if this:hasParameterProperty("Can-Receive-Fuel-Airborne") and
   this:hasStateProperty("Is-Airborne") then
   
   isGround = false
end

-- Resets the ammunition category counts (from ammo counts) 
--if they are uninitialized. Returns Ammunition-Categories
function resetAmmoCategoriesIfNeeded()
   local ammunitionCategories = this:getStateProperty("Ammunition-Categories")
   if ammunitionCategories["UNINITIALIZED"] ~= nil then
      ammunitionCategories = {}
      for ammoName, baseAmmo in pairs(baseAmmunition) do
	  
	     local baseAmmoType = baseAmmo.Type
	     if baseAmmoType == "For Weapon System" then
		   -- Ammo used by weapons systems is special and not consumed by type, but by name
		   baseAmmoType = ammoName
	     end
		 
         local ammo = ammunitionCategories[baseAmmoType]
         if(ammo == nil) then
            ammunitionCategories[baseAmmoType] = { Count = 0; BaseCount = 0 }
            ammo = ammunitionCategories[baseAmmoType]
         end      
         ammo.Count = ammo.Count + baseAmmo.Count
         ammo.BaseCount = ammo.BaseCount + baseAmmo.Count 
      end
      this:setStateProperty("Ammunition-Categories", ammunitionCategories)
   end
   return ammunitionCategories
end

-- Resets the resources if they are uninitialized
function resetResourcesIfNeeded()

   if (this:getStatePropertyMapItem("Resources", "UNINITIALIZED") ~= nil) then
      local resources = {}
      previousResources = {}
      for resourceName, baseResource in pairs(baseResources) do
         resources[resourceName] = {
            ["Amount"] = baseResource["Amount"];
            ["Pacing-Tracking"] = baseResource["Pacing-Tracking"] }
         previousResources[resourceName] = baseResource.Amount
      end
      this:setStateProperty("Resources", resources)
   end

end

-- Used to update a supply to keep the same percentage of the base value as we had
-- when the scenario was saved, even if the base value has changed.
function updateSupplyForLoad(supplyName, baseAmount)

   -- Get the saved base amount
   local savedBaseAmount = this:getStateProperty("Saved-Base-" .. supplyName)
   local savedAmount = this:getStateProperty(supplyName)

   if savedBaseAmount ~= nil and savedAmount ~= nil then
      
      if savedBaseAmount ~= baseAmount then
         
         local percentage = 1
         if savedBaseAmount > 0 then
            percentage = savedAmount.Amount / savedBaseAmount
         end
         local newAmount = {
            Amount = percentage * baseAmount;
            ["Pacing-Tracking"] = savedAmount["Pacing-Tracking"] }
            
         this:setStateProperty(supplyName, newAmount)
      end

      this:setStateProperty("Saved-Base-" .. supplyName, baseAmount)
   end

end

-- Need to see if our Base values have changed since the last time we ran. If they have,
-- we will keep the same percentage of supplies, but the actual values may change.
function loadState()

   -- Ammunition-Categories includes both the current and base values for each
   -- category. We need to compare these against our new base values.
   local ammunitionCategories = this:getStateProperty("Ammunition-Categories")

   local baseAmmoCategoryAmounts = {}
   
   -- Calculate the base amount in each ammo category
   for ammoName, baseAmmo in pairs(baseAmmunition) do
	  
	   local baseAmmoType = baseAmmo.Type
	   if baseAmmoType == "For Weapon System" then
		   -- Ammo used by weapons systems is special and not consumed by type, but by name
		   baseAmmoType = ammoName
	   end
      
      if(baseAmmoCategoryAmounts[baseAmmoType] == nil) then
         baseAmmoCategoryAmounts[baseAmmoType] = baseAmmo.Count
      else
         baseAmmoCategoryAmounts[baseAmmoType] = baseAmmoCategoryAmounts[baseAmmoType] + baseAmmo.Count
      end
   end

   -- Update Ammunition-Categories
   for categoryName, baseAmount in pairs(baseAmmoCategoryAmounts) do
	  		 
      local ammoCat = ammunitionCategories[baseAmmoType]
      if(ammoCat == nil) then
         -- A new ammo category was added. Give us the full amount.
         ammoCat = { Count = baseAmount; BaseCount = baseAmount }
      elseif ammoCat.BaseCount ~= baseAmount then
         -- The base ammo amount for this category changed. Keep the same
         -- percentage, but change the values.
         local percentage = ammoCat.Count / ammoCat.BaseCount
         ammoCat.Count = percentage * baseAmount
         ammoCat.BaseCount = baseAmount 
      end
   end
   
   this:setStateProperty("Ammunition-Categories", ammunitionCategories)
   
   -- Set Ammunition amounts from categories
   this:setStateProperty("Ammunition", {})
   updateAmmunition(ammunitionCategories)

   -- Update each supply based on saved percentage "full"
   updateSupplyForLoad("Food", baseFood.Amount)
   updateSupplyForLoad("Water", baseWater.Amount)
   updateSupplyForLoad("Motor-Gas", baseGas.Amount)
   updateSupplyForLoad("Aviation-Fuel", baseAviationFuel.Amount)
   updateSupplyForLoad("Diesel-Fuel", baseDiesel.Amount)
   updateSupplyForLoad("Oil", baseOil.Amount)
   updateSupplyForLoad("Lubricant", baseLubricant.Amount)
   
   -- Update Resources in the same manner
   local savedBaseResources = this:getStateProperty("Saved-Base-Resources")
   local resources = this:getStateProperty("Resources")
   if savedBaseResources ~= nil and resources ~= nil then
   
      for resourceName, baseResource in pairs(baseResources) do
      
         local savedBaseResource = savedBaseResources[resourceName]
         local resource = resources[resourceName]
         if savedBaseResource ~= nil and 
            resource ~= nil and
            savedBaseResource ~= baseResource.Amount then
            
            local percentage = 1
            if savedBaseResource > 0 then
               percentage = resource.Amount/savedBaseResource
            end
            resources[resourceName].Amount = percentage * baseResource.Amount
         end
         
         savedBaseResources[resourceName] = baseResource.Amount
      end
      
      this:setStateProperty("Resources", resources)
      this:setStateProperty("Saved-Base-Resources", savedBaseResources)
   end
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(5)
   
   ammunitionCategories = resetAmmoCategoriesIfNeeded()
      
   -- Initialize Ammunition amounts
   this:setStateProperty("Ammunition", {})
   updateAmmunition(ammunitionCategories)
   
   -- Initialize resources list
   resetResourcesIfNeeded()
   
   -- Initialize the previous health value
   previousHealth = baseHealth
      
   -- Get exercise time
   previousUpdateTime = vrf:getSimulationTime()
   
end
--=======================================================================
-- Calculates derived properties that are required to update the dynamic
-- properties controlled by this script. Returns the current values of these
-- properties.
-- Pre-tick derived properties:
--     If either the resources or ammo categories states have an "UNINITIALIZED"
--     entry, that means the entity has been reset (restored), and those 
--     state properties have to be filled out again.
--     Returns the ammunition categories state property.
function calculatePreTickDerivedProperties()
   resetResourcesIfNeeded()
   return resetAmmoCategoriesIfNeeded()   
end
--=======================================================================
--                                               This section contains 
--                                               functions for 
--                                               updateDynamicProperties.

-- Calculates the new amount of the given supply given the current amount,
-- the amount used per second, the amount used per meter, how long it has
-- been, how far we have travelled, what percentage of our health was lost
-- since the last update. currentSupply is the current stae property value.
-- Takes emptiedSupplies as an argument; this is a list of supplies that
-- go to 0 this tick.
-- *** Updates emptiedSupplies.
-- Returns the update supply
function useSupply(supplyType, perSec, perMeter, dT, 
   distance, healthPercent, healthDiffPercent, emptiedSupplies, currentSupply)

   if currentSupply ~= nil then
      local amount = currentSupply.Amount
      local amountUsed = healthPercent *
         ((perSec * dT) + (perMeter * distance))
      local amountDestroyed = healthDiffPercent * amount
      local amountLost = math.max(amountUsed, amountDestroyed)
      currentSupply.Amount = math.max(0, amount - amountLost)
      if amount > 0 and currentSupply.Amount == 0 then
         emptiedSupplies[supplyType] = true
      end

      if DEBUG_DETAIL then
         if amountUsed > 0 or amountDestroyed > 0 then
            printDebug(string.format("Using supply %s: used %.3f, destroyed %.3f, remaining %.3f",
               supplyType, amountUsed, amountDestroyed, currentSupply.Amount))
         end
      end
   end
   
   return currentSupply
end
   

 
-- Calculates the new amount of each Resaource given the percentage of our health was
-- lost since the last update.
function destroyResources(healthDiffPercent)
   
   local resources = this:getStateProperty("Resources")
   local changed = false
   if resources ~= nil then
      for resourceName, resource in pairs(resources) do
      
         -- Destroy resources based on change in health
         local amountDestroyed = healthDiffPercent * resource.Amount
         
         -- Find amount used since last time
         local previousResource = previousResources[resourceName]
         if previousResource == nil then
            previousResource = 0
         end
         local amountUsed = previousResource - resource.Amount
         if amountUsed < 0 then
            amountUsed = 0
         end
         
         -- We want only want to both destroy and use resources, so we choose whichever
         -- mechanism causes the biggest loss.
         if amountDestroyed > amountUsed then
            
            -- Destroy the remaining items that were not used
            amountDestroyed = amountDestroyed - amountUsed
            resources[resourceName].Amount = resource.Amount - amountDestroyed
            changed = true

            if DEBUG_DETAIL then
               printDebug("Using supply "..resourceName..": used ",
                  amountUsed, ", destroyed ", amountDestroyed, ", remaining ",
                  resources[resourceName].Amount)
            end
         end
         
         previousResources[resourceName] = resources[resourceName].Amount
         
      end
      
      if changed then
         this:setStateProperty("Resources", resources)
      end      
   end
end

-- Each type (ammo, food, etc.) is reduced based on usage 
-- and on the reduction in unit health since last tick.
-- Ammo usage is computed from the unit's list of attacks and the
-- ammunition usage table.
-- Note that ammo for limited-munition attacks (i.e., indirect fire,
-- missile attacks) is updated in the Limited_Munition_Attack script.
-- The usage rate for other supplies is computed from the individual 
-- usage rates per time and/or distance in the parameter properties.
-- *** ammunitionCategories is changed as a side effect; also, the 
-- State properties will not be updated. Instead the 
-- ammunitionCategories and updatedSupplies tables will be updated with
-- the latest values.
-- Returns a list of newly-emptied supplies (names).
function useAndDestroySupplies(timeDiff, ammunitionCategories, updatedSupplies)
   -- Keep a list of supplies that have reached 0, by name.
   -- (Actually a map, with supply names as keys, true as the values.)
   -- A return value.
   local emptiedSupplies = {}
   
   -- Calculate the current health, the difference in health since the last
   -- tick, and the percentage change in health since the last tick.
   local health = this:getStateProperty("Health")
   local healthPercent = health / baseHealth
   local healthDiff = math.max(0, previousHealth - health)
   local healthDiffPercent = 0
   if(previousHealth > 0) then
      healthDiffPercent = healthDiff / previousHealth
   end
   
   -- Calculate the change in position since the last tick.
   local location = this:getLocation3D()
   -- Derive distance travelled from current speed. Not as accurate as 
   -- recording the last position and checking the distance between that
   -- and the current position, but that approach gives a false
   -- indication if the user teleported the entity.
   local metersTraveled = this:getSpeed() * timeDiff
   
   local usageAmounts = {}

   -- See what kind of attacks we have going on and decrement the ammo amounts
   local currentAttacks = this:getStateProperty("Attacks")
   
   local postureNow = this:getStateProperty("Posture")
   for attackIndex, attack in pairs(currentAttacks) do
   
      -- Only need to evaluate once for each ammo type. It is assumed that we can
      -- only fire so many rounds no matter how many enemies we are attacking. So we
      -- don't use more just because we are firing at two different enemies.
      if (usageAmounts[attack.Type] == nil) then
      
         -- Calculate our ammunition usage for each attack type, based on our health and base usage.
         -- We use less ammo when we're at lower health (there are less of us to shoot our guns).
         local amountUsed = 0
         local usageRate = ammunitionUsage[attack.Type]
         if(usageRate ~= nil) then
            local postureMod = postureModifiers[postureNow]
            if postureMod == nil then postureMod = 1.0 end
            amountUsed = usageRate * healthPercent * postureMod * timeDiff
         end
         
         -- Save how much we are using
         usageAmounts[attack.Type] = amountUsed
      end
   end
   
   -- Decrement ammo categories
   for ammoType, ammoCat in pairs(ammunitionCategories) do
      if not ammoCategoriesToIgnore[ammoType] then
         -- Ammo is destroyed as we take damage
         local amountDestroyed = healthDiffPercent * ammoCat.Count
         
         -- Usage amounts for large munitions will be nil.
         local amountUsed = 0
         if usageAmounts[ammoType] ~= nil then 
            amountUsed = usageAmounts[ammoType] 
         end
         -- Decrement our remaining ammo amounts by the maximum of the amount
         -- destroyed and the amount used.
         local decrementAmount = math.max(amountDestroyed, amountUsed)
         
         if DEBUG_DETAIL and decrementAmount > 0 then
            if amountDestroyed > amountUsed then
               printDebug("Ammo ", ammoType, ": ", amountDestroyed, " destroyed.")
            else
               printDebug("Ammo ", ammoType, ": ", amountUsed, " used.")
            end
         end
         
         local new = math.max(ammoCat.Count - decrementAmount, 0)
         if ammoCat.Count > 0 and new == 0 then
            emptiedSupplies[ammoType] = true
         end
         ammoCat.Count = new
      end
   end
   
   -- Use other supplies
   
   -- Posture is used to modify the POL usage/sec, per SWGS reqmnt.
   -- TODO: review this.
   local postureSpeedMod
   if postureSpeedModifiers ~= nil then
      postureSpeedMod = postureSpeedModifiers[postureNow]
   else
      postureSpeedMod = 1.0
   end
   
   updatedSupplies["Food"] = useSupply("Food", foodUsagePerSec,
      0, timeDiff, metersTraveled,
      healthPercent, healthDiffPercent, emptiedSupplies,
      updatedSupplies["Food"])
   
   updatedSupplies["Water"] = useSupply("Water", waterUsagePerSec,
      0, timeDiff, metersTraveled, 
      healthPercent, healthDiffPercent, emptiedSupplies,
      updatedSupplies["Water"])
      
   updatedSupplies["Motor-Gas"] = useSupply("Motor-Gas", gasUsagePerSec * postureSpeedMod, 
      gasUsagePerM, timeDiff, metersTraveled, 
      healthPercent, healthDiffPercent, emptiedSupplies,
      updatedSupplies["Motor-Gas"])
      
   updatedSupplies["Aviation-Fuel"] = useSupply("Aviation-Fuel", aviationFuelUsagePerSec * postureSpeedMod,
      aviationFuelUsagePerM, timeDiff, metersTraveled, 
      healthPercent, healthDiffPercent, emptiedSupplies,
      updatedSupplies["Aviation-Fuel"])

   updatedSupplies["Diesel-Fuel"] = useSupply("Diesel-Fuel", dieselUsagePerSec * postureSpeedMod,
      dieselUsagePerM, timeDiff, metersTraveled, 
      healthPercent, healthDiffPercent, emptiedSupplies,
      updatedSupplies["Diesel-Fuel"])

   updatedSupplies["Oil"] = useSupply("Oil", oilUsagePerSec * postureSpeedMod,
      0, timeDiff, metersTraveled, 
      healthPercent, healthDiffPercent, emptiedSupplies,
      updatedSupplies["Oil"])

   updatedSupplies["Lubricant"] = useSupply("Lubricant", lubricantUsagePerSec * postureSpeedMod,
      0, timeDiff, metersTraveled, 
      healthPercent, healthDiffPercent, emptiedSupplies,
      updatedSupplies["Lubricant"])

      
   destroyResources(healthDiffPercent)
      
   -- Update our "previous" values for the next tick
   previousHealth = health
   
   return emptiedSupplies
end
--....................................................................
-- Determines if the unit is allowed to take supplies, based on its
-- combat activity, etc.
function canTakeSupplies()
   local can = true
   
   if(this:getEmbarkedOn():isValid()) then
      if DEBUG_DETAIL then
         printDebug("Can't receive supplies while embarked.")
      end
      return false
   end
   local supplyMove = this:getParameterProperty("Can-Receive-Supplies-Moving")
   if supplyMove == nil or not supplyMove then
      local speed = this:getSpeed()
      if speed > 0 then
         if DEBUG_DETAIL then
            printDebug("Can't receive supplies while moving.")
         end
         return false
      end
   end
   local supplyAttack = this:getParameterProperty(
      "Can-Receive-Supplies-Attacking")
   if supplyAttack == nil or not supplyAttack then

      local attacks = this:getStateProperty("Attacks")
      if attacks ~= nil and next(attacks) ~= nil then
         if DEBUG_DETAIL then
            printDebug("Can't receive supplies while attacking.")
         end
         return false
      end
   end
   local supplyDefend = this:getParameterProperty(
      "Can-Receive-Supplies-Defending")
   if supplyDefend == nil or not supplyDefend then
      local defenses = this:getStateProperty("Attacks-Defending")
      if defenses ~= nil and next(defenses) ~= nil then
         if DEBUG_DETAIL then
            printDebug("Can't receive supplies while defending.")
         end
         return false
      end
   end
   -- There is a built-in prohibition, later in the code, against
   -- receiving anything but aviation fuel while airborne. So this test
   -- effectively will only allow aviation fuel.
   if not isGround then
   
      local fuelAirborne = this:getParameterProperty(
         "Can-Receive-Fuel-Airborne")
      if fuelAirborne == nil or not fuelAirborne then
         local airborne = this:getStateProperty("Is-Airborne")
         if airborne ~= nil and airborne then
            if DEBUG_DETAIL then
               printDebug("Can't receive supplies while airborne.")
            end
            return false
         end
      end
   end

   if this:isDestroyed() then
      if DEBUG_DETAIL then
         printDebug("Can't receive supplies while destroyed.")
      end
      return false
   end

   return true
end

-- Resets all supplies except health to base levels, modified
-- by health percent.
-- Changes the counts in the ammo map and supplies map, and returns both.
function resetAllSupplies(ammoMap, suppliesMap, healthPercent)
   local supply
   local info
   local stateInfo
   for supply, info in pairs(baseInfo) do
      if suppliesMap[supply] ~= nil then
         suppliesMap[supply].Amount = info.Amount * healthPercent
      end
   end
   
   if suppliesMap["Resources"] ~= nil then
      for supply, info in pairs(baseResources) do
         suppliesMap["Resources"][supply].Amount = info.Amount * healthPercent
      end
   end
   
   for supply, info in pairs(ammoMap) do
      info.Count = info.BaseCount * healthPercent
   end
   return ammoMap, suppliesMap
end

-- Updates the given supply state using the given rate, where a supply
-- is one of "Food", "Water", "Motor-Gas", "Aviation-Fuel", 
-- "Diesel-Fuel", "Oil", or "Lubricant".
-- Checks first
-- to make sure that the base amount, adjusted for health, isn't exceeded.
-- Takes emptiedSupplies as an argument; this is the list of supplies that
-- were zeroed this tick. If this function leaves the supply with > 0 amount,
-- this supply is removed from the list.
-- Returns the updated supply.
function takeSupply(supplyName, rate, healthPercent, dT, emptiedSupplies, supply)
   if supply ~= nil and rate ~= nil and rate > 0 then
      local old = supply.Amount
      local baseStruct = baseInfo[supplyName]
      if baseStruct ~= nil then
         supply.Amount = math.min(baseStruct.Amount * healthPercent, 
            old + dT* rate)
         if supply.Amount > old then
            if DEBUG_DETAIL then
               printDebug("Taking supply ", supplyName, " at rate ", rate)
            end
         end
      end
      if supply.Amount > 0 then
         emptiedSupplies[supplyName] = nil
      end
   elseif DEBUG_DETAIL then
      printDebug("Supply ", supplyName,
         ", supply state or rate is nil")         
   end
   
   return supply
end

-- Updates the given resource amount and returns the new property.
-- Does not do anything with emptiedSupplies, since Use_Supplies does 
-- not expend resources and thus detect that they are empty.
function takeResource(resourceName, rate, healthPercent, dT, currentResource)
   if currentResource ~= nil and rate ~= nil and rate > 0 then
      local old = currentResource.Amount
      local baseStruct = baseResources[resourceName]
      if baseStruct ~= nil then
         currentResource.Amount = math.min(baseStruct.Amount * healthPercent,
            old + dT * rate)
         if currentResource.Amount > old then
            if DEBUG_DETAIL then
               printDebug("Taking resource ", resourceName,
                  " at rate ", rate)
            end
         end
      end
   elseif DEBUG_DETAIL then
      printDebug("Supply ", resourceName,
         ", supply state or rate is nil")
   end
   
   return currentResource
end
   
-- Updates the given ammo using the given rate, where the
-- ammo name must be one of the fixed category names.
-- Checks to make
-- sure the base amount, adjusted for health, hasn't been exceeded.
-- The ammoMap is the table of ammunition categories, possibly
-- uninitialized. 
-- *** Updates the ammoMap.
function takeAmmo(ammoName, rate, ammoMap, healthPercent, dT)
   local ammoInfo = ammoMap[ammoName]
   if ammoInfo ~= nil and rate ~= nil and rate > 0 then
      old = ammoInfo.Count
      ammoInfo.Count = math.min(ammoInfo.BaseCount * healthPercent, 
         old + dT * rate)
      if ammoInfo.Count > old then
         if DEBUG_DETAIL then
            printDebug("Taking ammo type ", ammoName, " at rate ", rate)
         end
      end
   end
end

-- Updates all ammo in ammo categories table (ammoMap) that isn't of a type that
-- is aggregated into categories, i.e. anti-tank, HE, AP, AA, or anti-ship.
-- Returns: nothing, but *** updates ammoMap.
function takeLargeAmmo(rate, ammoMap, healthPercent, dT)
   if rate ~= nil and rate > 0 then
      local ammoInfo
      local ammoType
      for ammoType, ammoInfo in pairs(ammoMap) do
         -- Ignore the fixed categories; this is for large munitions:
         if fixedCategoryNames[ammoType] == nil then
            local old = ammoInfo.Count
            local new = math.min(ammoInfo.BaseCount * healthPercent,
               old + rate * dT)
            if new > old then 
               ammoInfo.Count = new
               if DEBUG_DETAIL then
                  printDebug("Taking large munition ", ammoType,
                     " at rate ", rate)
               end
            end
         end
      end
   end
end
  

-- Updates health, ammo and other supplies based on resupply activities.
-- Takes the state property Ammunition Categories as an argument.
-- Takes the state properties for updatedSupplies as an argument.
-- Also takes emptiedSupplies as an argument, which is a list of supplies that
-- have just reached 0 (through use or destruction) this tick. This function
-- will remove entries if the are resupplied to a non-zero level. Note that
-- health is ignored (notification is handled elsewhere in VRF); fixed supplies
-- like food update this list individually in takeSupply, but the ammo in the list is
-- updated at the end of resupply(), for all ammo types at once.
-- *** ammo map is changed as a side effect.
-- *** updatedSupplies is changed as a side effect.
-- *** emptiedSupplies is changed as a side effect.
function resupply(dT, ammoMap, emptiedSupplies, updatedSupplies)
   local health = this:getStateProperty("Health")
   local healthPercent = health / baseHealth
   local old
   local rate
   local mode = this:getStateProperty("Resupply-Mode")
   
   -- If the unit is airborne, then canTakeSupplies() will be false unless
   -- can-refuel-airborne is true. In that case, the unit can only take
   -- aviation fuel.
   local airborne
   if isGround then 
      airborne = false
   else   
      airborne = this:getStateProperty("Is-Airborne")
   end
   local fuelOnly = false
   if airborne ~= nil and airborne then
      fuelOnly = true
   end

   -------------------
   if mode == "None" or
      not canTakeSupplies() then 
      
      if DEBUG_DETAIL then
         printDebug(".  Cannot resupply.")
      end
      return
   --------------------   
   elseif mode == "Auto-Continuous" then
      if DEBUG_DETAIL then
         printDebug(".  Auto resupplying")
      end
      if fuelOnly then
         updatedSupplies["Aviation-Fuel"] = takeSupply("Aviation-Fuel", this:getParameterProperty(
            "Aviation-Fuel-Auto-Resupply-Rate"), 
            healthPercent, dT, emptiedSupplies, updatedSupplies["Aviation-Fuel"])
         return
      end
      old = this:getStateProperty("Health")
      rate = this:getParameterProperty("Health-Auto-Resupply-Rate")
      if old ~= nil and rate ~= nil and rate > 0 then
         -- Round the fractional increase. Note Health is an Int property.
         local new = math.min(this:getParameterProperty("Base-Health"),
            math.floor(old + dT * rate + 0.5))
         if new > old then
            this:setStateProperty("Health", new)
            if DEBUG_DETAIL then
               printDebug("Taking Health at rate ", rate)
            end
         end
      end
      
      -- Update all the regular, categorized ammo
      local ammoType
      for ammoType, rate in pairs(ammoResupplyRates) do
         takeAmmo(ammoType, rate, ammoMap, healthPercent, dT)
      end
      
      -- Update all the large-munition ammo (bombs, missiles, etc.).
      -- (No need to update the emptied list; the emptied warning is generated
      -- in another script.)
      local largeAmmoRate = this:getParameterProperty("Large-Munition-Auto-Resupply-Rate")
      takeLargeAmmo(largeAmmoRate, ammoMap, healthPercent, dT)
      
      updatedSupplies["Food"] = takeSupply("Food",
         this:getParameterProperty("Food-Auto-Resupply-Rate"), 
         healthPercent, dT, emptiedSupplies, updatedSupplies["Food"])
      updatedSupplies["Water"] = takeSupply("Water", 
         this:getParameterProperty("Water-Auto-Resupply-Rate"), 
         healthPercent, dT, emptiedSupplies, updatedSupplies["Water"])
      updatedSupplies["Motor-Gas"] = takeSupply("Motor-Gas",
         this:getParameterProperty("Motor-Gas-Auto-Resupply-Rate"), 
         healthPercent, dT, emptiedSupplies, updatedSupplies["Motor-Gas"])
      updatedSupplies["Aviation-Fuel"] = takeSupply("Aviation-Fuel",
         this:getParameterProperty("Aviation-Fuel-Auto-Resupply-Rate"), 
         healthPercent, dT, emptiedSupplies, updatedSupplies["Aviation-Fuel"])
      updatedSupplies["Diesel-Fuel"] = takeSupply("Diesel-Fuel",
         this:getParameterProperty("Diesel-Fuel-Auto-Resupply-Rate"), 
         healthPercent, dT, emptiedSupplies, updatedSupplies["Diesel-Fuel"])
      updatedSupplies["Oil"] = takeSupply("Oil",
         this:getParameterProperty("Oil-Auto-Resupply-Rate"), 
         healthPercent, dT, emptiedSupplies, updatedSupplies["Oil"])
      updatedSupplies["Lubricant"] = takeSupply("Lubricant",
         this:getParameterProperty("Lubricant-Auto-Resupply-Rate"), 
         healthPercent, dT, emptiedSupplies, updatedSupplies["Lubricant"])
      
      if updatedSupplies["Resources"] ~= nil then
         local resource, info
         for resource, info in pairs(baseResources) do
            updatedSupplies["Resources"][resource] = takeResource(resource, 
               info["Auto-Resupply-Rate"], healthPercent, dT, updatedSupplies["Resources"][resource])
         end
      end
   --------------------      
   elseif mode == "Auto-Periodic" then
   
      local time = vrf:getSimulationTime()
      local period = this:getStateProperty("Auto-Resupply-Period")
      if DEBUG_DETAIL then
         printDebug(string.format(".   Periodic resupply"))
      end
      if period ~= nil and
         time - previousPeriodicResupplyTime >= period then
         
         if fuelOnly then
            if updatedSupplies["Aviation-Fuel"] ~= nil and baseAviationFuel ~= nil then
               updatedSupplies["Aviation-Fuel"].Amount = baseAviationFuel.Amount * healthPercent
            end
            emptiedSupplies["Aviation-Fuel"] = nil
            previousPeriodicResupplyTime = time
            if DEBUG_DETAIL then
               printDebug("Resupplying aviation fuel (only).")
            end
            return
         end
            
         ammoMap, updatedSupplies = resetAllSupplies(ammoMap, updatedSupplies, healthPercent)
         emptiedSupplies = {}
         if DEBUG_DETAIL then
            printDebug("Resetting all supplies except health.")
         end
         previousPeriodicResupplyTime = time
      elseif DEBUG_DETAIL and
         period ~= nil then
         
         printDebug(string.format(".   %.0f seconds until resupply",
            period - (time - previousPeriodicResupplyTime)))
      end
   --------------------         
   elseif mode == "From-Supply" then
   
      local supplierName
      local supplier
      local supplyList
      local _v
      local changedAmmo = false
      if DEBUG_DETAIL and next(activeSuppliers) == nil then
         printDebug(".  No nearby supply units.")
      end
      for supplierName, _v in pairs(activeSuppliers) do
         supplier = vrf:getSimObjectByUUID(supplierName)
         if supplier:isValid() then
            supplyList = supplier:getStateProperty("Supplies-Offered")
            if supplyList ~= nil then
            
               if fuelOnly then
                  if supplyList["Aviation-Fuel"] ~= nil then
                     updatedSupplies["Aviation-Fuel"] = takeSupply("Aviation-Fuel", 
                        supplyList["Aviation-Fuel"], 
                        healthPercent, dT, emptiedSupplies, updatedSupplies["Aviation-Fuel"])
                  end
               else
                  for supplyType, rate in pairs(supplyList) do
                     --Note: these type names are set in resupplyController.cxx
                     
                     if supplyType == "Health" then
                        old = this:getStateProperty("Health")
                        if old ~= nil then
                           -- Round the fractional increase. Note Health is an Int property.
                           new = math.min(this:getParameterProperty("Base-Health"),
                              math.floor(old + dT * rate + 0.5))
                           if new > old then
                              this:setStateProperty("Health", new)
                              if DEBUG_DETAIL then
                                 printDebug("Taking Health at rate ", rate)
                              end
                           end
                        end
                     -- See if this is an ammo category we use   
                     elseif myAmmoCategories[supplyType] == true then -- 
                        takeAmmo(supplyType, rate, ammoMap,
                           healthPercent, dT)
                        changedAmmo = true
                     
                     elseif supplyType == "Large-Munition" then
                        takeLargeAmmo(rate, ammoMap, healthPercent, dT)
                        changedAmmo = true
                        
                     -- See if this is a basic supply type   
                     elseif baseInfo[supplyType] ~= nil then 
                        updatedSupplies[supplyType] = takeSupply(supplyType, rate,
                           healthPercent, dT, emptiedSupplies, updatedSupplies[supplyType])
                        
                     -- See if this is a resource we use   
                     elseif baseResources[supplyType] ~= nil and updatedSupplies["Resources"] ~= nil then 
                        updatedSupplies["Resources"][supplyType] = takeResource(supplyType,
                           rate, healthPercent, dT, updatedSupplies["Resources"][supplyType])
                     end
                  end
               end
            end
         end
      end
   end
   -- If ammo is non-zero, make sure it isn't on the list
   -- of just-emptied supplies.
   local ammoType, ammoInfo
   for ammoType, ammoInfo in pairs(ammoMap) do
      if ammoInfo ~= nil and ammoInfo.Count > 0 then
         emptiedSupplies[ammoType] = nil
      end
   end
   
   return
end

-- Prints warning messages for supplies that have reached 0.
function showWarnings(emptyList)
   local name, _v
   for name, _v in pairs(emptyList) do
      printWarn(vrf:trUtf8("Supply of %1 is now exhausted."):arg(name))
   end
end

--....................................................................
-- Updates any dynamic properties controlled by this task. Returns the
-- current values of these properties.
-- Dynamic properties:
--     Health
--     Ammunition-Categories
--     Food
--     Water
--     Motor-Gas
--     Aviation-Fuel
--     Diesel-Fuel
--     Oil
--     Lubricant
--     Other-supplies
--
-- These properties are update in two steps. 
-- First, reductions are taken based on consumption and on
-- destruction due to reduced health.
-- Second, if the unit is being resupplied, health, ammo, and other
-- supplies are increased.
function updateDynamicProperties(ammunitionCategories)
   local currentTime = vrf:getSimulationTime()
   local dT = currentTime - previousUpdateTime
   local emptiedSupplies 
   
   -- Holds all updated supply amounts
   local updatedSupplies = { 
      ["Food"] = this:getStateProperty("Food"),
      ["Water"] = this:getStateProperty("Water"),
      ["Motor-Gas"] = this:getStateProperty("Motor-Gas"),
      ["Aviation-Fuel"] = this:getStateProperty("Aviation-Fuel"),
      ["Diesel-Fuel"] = this:getStateProperty("Diesel-Fuel"),
      ["Oil"] = this:getStateProperty("Oil"),
      ["Lubricant"] = this:getStateProperty("Lubricant"),
      ["Resources"] = this:getStateProperty("Resources")}      
   
   emptiedSupplies = 
      useAndDestroySupplies(dT, ammunitionCategories, updatedSupplies)
   resupply(dT, ammunitionCategories, emptiedSupplies, updatedSupplies)
   
   -- Set the new ammo amounts
   this:setStateProperty("Ammunition-Categories", ammunitionCategories)
   
   -- Set other supplies
   for supplyName, supplyProp in pairs(updatedSupplies) do
      this:setStateProperty(supplyName, supplyProp)
   end
   
   showWarnings(emptiedSupplies)

   previousUpdateTime = currentTime
   return ammunitionCategories
end

--=========================================================================

-- Given that the ammunition in the Ammunition-Categories table has
-- been reduced by expenditure and health loss, 
-- and/or replenished by resupply activities, 
-- update the individual ammo types proportionally. I.e. if ammo
-- category Anti-tank has been reduced to 60%, then each type of ammo
-- in that category will be reduced to 60%.
function updateAmmunition(ammunitionCategories)
   -- Update named ammunition lists based on levels of each ammo category
   local ammunition = this:getStateProperty("Ammunition")
   local isInitialization = (next(ammunition) == nil) -- Don't print error messages for
         -- missing ammo entries if this is the first initialization of the table.
         
   local ammunitionUpdated = false
   
   for ammoName, baseAmmo in pairs(baseAmmunition) do
   
      local baseAmmoType = baseAmmo.Type
      if baseAmmoType == nil then
         printWarn(vrf:trUtf8("Error: no category known for ammo %1"):arg(ammoName))
      else
      
         if baseAmmoType == "For Weapon System" then
            -- Ammo used by weapons systems is special and not consumed by type, but by name
            baseAmmoType = ammoName
         end
        
         local ammoCat = ammunitionCategories[baseAmmoType]
         
         -- Two checks to prevent script failure if the unit's ammunition
         -- parameters changed since the scenario (and state data) 
         -- was saved. This recovery should only  have to run once for a unit,
         -- the first time this script is ticked.
         -- 1
         if ammoCat == nil then
            printInfo(vrf:trUtf8("Info: Ammunition Category entry for %1 is nil; creating entry"):arg(baseAmmoType))
            printInfo(vrf:trUtf8("...Ammo parameters probably changed after scenario was created."))
            ammoCat = {}
            ammoCat.BaseCount = 0
            ammoCat.Count = 0
            -- Roll up all the weapons of this category
            local _ammoName
            local _ammoInfo
            for _ammoName, _ammoInfo in pairs(baseAmmunition) do
               if _ammoInfo.Type == baseAmmoType or
                  (_ammoInfo.Type == "For Weapon System" and _ammoName == baseAmmoType) then
                  ammoCat.BaseCount = ammoCat.BaseCount + _ammoInfo.Count
               end
            end
            ammoCat.Count = ammoCat.BaseCount * 
               this:getStateProperty("Health")/this:getParameterProperty("Base-Health")
            ammunitionCategories[baseAmmoType] = ammoCat
            this:setStateProperty("Ammunition-Categories", ammunitionCategories)
         end
         -- 2
         if ammunition[ammoName] == nil then
            if not isInitialization then
               printInfo(vrf:trUtf8("Info: Ammunition entry for %1 is nil; creating entry"):arg(ammoName))
               printInfo(vrf:trUtf8("...Ammo parameters probably changed after scenario was created."))
            end
            ammunition[ammoName] = { ["Count"] = 0, ["Pacing-Tracking"] = baseAmmo["Pacing-Tracking"], ["Type"] = baseAmmoType }
         end
         
         local oldCount = ammunition[ammoName].Count      
         local newCount = baseAmmo.Count * (ammoCat.Count/ammoCat.BaseCount)
         
         if (newCount < 1) then
            -- Do not destroy the last one left until we are completely destroyed
            newCount = math.ceil(newCount)
         else
            -- Report only whole integer values
            newCount = roundToInt(newCount)
         end
         
         if oldCount ~= newCount then
            ammunition[ammoName].Count = newCount
            ammunitionUpdated = true
         end
         
         -- The way ammunition types are treated has slightly changed. If the type does not
         -- match what is expected, just update it.
         if ammunition[ammoName].Type ~= baseAmmoType then
            ammunition[ammoName].Type = baseAmmoType
            ammunitionUpdated = true
         end

   --~       if DEBUG_DETAIL and ammunition[ammoName].Count ~= oldCount then
   --~          printDebug(string.format("Updating ammo %s, type %s; new %.2f%% of %d = %d",
   --~             ammoName, baseAmmoType,
   --~             ammoCat.Count/ammoCat.BaseCount * 100, baseAmmo.Count, 
   --~             ammunition[ammoName].Count))
   --~       end
         
      end
   end
      
   if ammunitionUpdated then
      this:setStateProperty("Ammunition", ammunition)
   end
end

-- Calculates remaining derived properties which are maintained by this script.
-- ammunitionCategories is the state property with ammunition levels by fixed
-- category, as well as large munitions.
-- Derived properties:
--    Ammunition levels (individual ammos, based on ammo category amounts)
--    Warning notification for supplies that have run out this tick.
function calculateDerivedProperties(ammunitionCategories)
   updateAmmunition(ammunitionCategories)
end
--=========================================================================      
-- Called each tick while this task is active.
function tick()
   if DEBUG_DETAIL then
      printDebug(string.format("\n%.3f Use Supplies:",
         vrf:getSimulationTime()))
   end
   local ammunitionCategories = calculatePreTickDerivedProperties()
   ammunitionCategories = updateDynamicProperties(ammunitionCategories)
   calculateDerivedProperties(ammunitionCategories)  
   
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

   local food = this:getStateProperty("Food")
   food.Amount = 0
   this:setStateProperty("Food", food)
   
   local water = this:getStateProperty("Water")
   water.Amount = 0
   this:setStateProperty("Water", water)
   
   local gas = this:getStateProperty("Motor-Gas")
   gas.Amount = 0
   this:setStateProperty("Motor-Gas", gas)
   
   local avFuel = this:getStateProperty("Aviation-Fuel")
   avFuel.Amount = 0
   this:setStateProperty("Aviation-Fuel", avFuel)
   
   local diesel = this:getStateProperty("Diesel-Fuel")
   diesel.Amount = 0
   this:setStateProperty("Diesel-Fuel", diesel)
   
   local oil = this:getStateProperty("Oil")
   oil.Amount = 0
   this:setStateProperty("Oil", oil)
   
   local lubricant = this:getStateProperty("Lubricant")
   lubricant.Amount = 0
   this:setStateProperty("Lubricant", lubricant)
   
   local ammoCats = this:getStateProperty("Ammunition-Categories")
   for cat, info in pairs(ammoCats) do
      info.Count = 0
   end
   this:setStateProperty("Ammunition-Categories", ammoCats)
   
   local ammo = this:getStateProperty("Ammunition")
   for name, info in pairs(ammo) do
      info.Count = 0
   end
   this:setStateProperty("Ammunition", ammo)
   
   local resources = this:getStateProperty("Resources")
   for name, info in pairs(resources) do
      info.Amount = 0
      
      previousResources[name] = info.Amount
   end
   this:setStateProperty("Resources", resources)
   
end

-- Called whenever the entity receives an Influence interaction while
-- this task is active.
--   influencer is the SimObject sending the Influence.
--   influenceName is a string identifying the kind of Influence.
--   influenceParams is a table of optional Influence parameters.
function receiveInfluence(influencer, influenceName, influenceParams)

   if influenceName == "ProvidingSupplies" then
      if DEBUG_DETAIL then
         printDebug(string.format("\n%.3f Use Supplies: ProvidingSupplies interaction received",
            vrf:getSimulationTime()))
      end
      local influencerName = influencer:getUUID()
      if influenceParams.StopInfluence then
         if activeSuppliers[influencerName] ~= nil then
            activeSuppliers[influencerName] = nil
            printInfo(vrf:trUtf8("%1 is no longer providing supplies."):
               arg(influencerName))
         end
      else
         activeSuppliers[influencerName] = true
         printInfo(vrf:trUtf8("%1 is providing supplies."):
            arg(influencerName))
      end
   end

end
