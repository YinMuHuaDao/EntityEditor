-- Maximum_Speed_Modifier.lua
-- Copyright 11/2014 by VT-MAK
--
-- This file contains the script used to compute a maximum speed
-- modifier based on the following conditions:
-- 1) Rain/Snow
-- 2) Visibility
-- 3) Wind
--
-- The resultant modifier calculation will be placed into a state variable that
-- will be used by the aggregate movement actuator to apply to the maximum
-- potential speed

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- *********** Constants used in the calculations
-- Evaluation interval, in seconds
local TICK_PERIOD = 5

-- The altitude within which airborne units must be in order to trigger
-- the overlap speed modifier. In meters.
local AIR_ALTITUDE_OVERLAP = 153 --500 feet

-- The lowest possible movement modifier value
local LOWEST_POSSIBLE_VALUE = 0.00 -- fully stopped

-- Default modifier that will apply to rain percentage.  The percentage intensity of the rain
-- multiplied by this factor will reduce maximum speed by that amount
local MODIFIER_FOR_MAX_RAIN_INTENSITY = 0

-- Default modifier that will apply to snow percentage.  The percentage intensity of the snow
-- multiplied by this factor will reduce maximum speed by that amount
local MODIFIER_FOR_MAX_SNOW_INTENSITY = 0

-- If visibility is below this particular number, a percentage value of the actual visibility
-- is taken and applied to the modifier.  The closer to 0 visibility is the higher the modifier
-- value
local VISIBILITY_DEGRADES_WHEN_BELOW = 0
local MODIFIER_FOR_ZERO_VISIBILITY = 0

-- When the wind is above a certain kilometer per hour then degrades by a percentage amount until the max
-- degrade speed, at which point the maximum penalty is taken
local WIND_DEGRADES_WHEN_ABOVE = 0
local WIND_DEGRADES_UNTIL = 0
local WIND_DEGRADES_TO = 0

-- How susceptible the unit is to the affects of tail or head winds.
local WIND_DIRECTION_SUSCEPTIBILITY = 0 

local MAXIMUM_SPEED_POSTURE_MODIFIER = this:getParameterProperty("MaximumSpeed-Posture-Modifier")
local MAXIMUM_FOOTPRINT_OVERLAP_MODIFIER = this:getParameterProperty("MaximumSpeed-Footprint-Overlap-Modifier")
local MAXIMUM_SPEED_MOPP_LEVEL_MODIFIER = this:getParameterProperty("MaximumSpeed-MOPP-Level-Modifier")

local am_ground = true
if this:hasStateProperty("Is-Airborne") then

   am_ground = false
end

-- Called to retrieve the value specified. If error is true then the value will not be set
function setValueIfPresent(valueToSet, attributeName)
   local val, errorCode = vrf:getScriptAttribute(attributeName)
   
   if (not errorCode) then
      return val
   end
   
   return valueToSet
end

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(TICK_PERIOD)
end

-- Called to initialize local variables. 
MODIFIER_FOR_MAX_RAIN_INTENSITY = setValueIfPresent(MODIFIER_FOR_MAX_RAIN_INTENSITY, "Rain-Modifier-By-Intensity")
MODIFIER_FOR_MAX_SNOW_INTENSITY = setValueIfPresent(MODIFIER_FOR_MAX_SNOW_INTENSITY, "Snow-Modifier-By-Intensity")
LOWEST_POSSIBLE_VALUE = setValueIfPresent(LOWEST_POSSIBLE_VALUE, "Lowest-Possible-Movement-Modifier-Value")
VISIBILITY_DEGRADES_WHEN_BELOW = setValueIfPresent(VISIBILITY_DEGRADES_WHEN_BELOW, "Visibility-Degrades-When-Below")
MODIFIER_FOR_ZERO_VISIBILITY = setValueIfPresent(MODIFIER_FOR_ZERO_VISIBILITY, "Visibility-Can-Degrade-Speed-Up-To")
WIND_DEGRADES_WHEN_ABOVE = setValueIfPresent(WIND_DEGRADES_WHEN_ABOVE, "Wind-Degrades-When-Above")
WIND_DEGRADES_UNTIL = setValueIfPresent(WIND_DEGRADES_UNTIL, "Wind-Degrades-Until")
WIND_DEGRADES_TO = setValueIfPresent(WIND_DEGRADES_TO, "Wind-Degrades-To")
WIND_DIRECTION_SUSCEPTIBILITY = setValueIfPresent(WIND_DIRECTION_SUSCEPTIBILITY, "Wind-Direction-Susceptibility")


-- Called to modify the movement modifier by rain intensity.  If the weather is raining 
-- then the rain modifier will be multiplied by the given intensity to achieve the movement
-- penalty
function modifyByPrecipitation(maximumSpeedModifier)
   -- Rain is precipitation type 1 and 2 is snow.  See documentation for luaSetPrecipitationType
   if ((MODIFIER_FOR_MAX_RAIN_INTENSITY >= 0) or (MODIFIER_FOR_MAX_SNOW_INTENSITY >= 0)) then
      local precipType, precipIntens = vrf:getPrecipitationInformation(this)
   
      if ((precipType == 1) and (MODIFIER_FOR_MAX_RAIN_INTENSITY >= 0)) then
         maximumSpeedModifier = maximumSpeedModifier * (1.0 - (precipIntens * (1.0 - MODIFIER_FOR_MAX_RAIN_INTENSITY)))
      elseif ((precipType == 2) and (MODIFIER_FOR_MAX_SNOW_INTENSITY >= 0)) then
         maximumSpeedModifier = maximumSpeedModifier * (1.0 - (precipIntens * (1.0 - MODIFIER_FOR_MAX_SNOW_INTENSITY)))
      end
   end
   
   return maximumSpeedModifier
end

-- If visibility is below VISIBILITY_DEGRADES_WHEN_BELOW, a percentage value of the actual visibility
-- is taken and applied to the MODIFIER_FOR_ZERO_VISIBILITY modifier.  The closer to 0 visibility is the higher the modifier
-- value
function modifyByVisibility(maximumSpeedModifier)

   if (MODIFIER_FOR_ZERO_VISIBILITY >= 0) then
      local visibility = vrf:getVisibilityDistance(this)
   
      if (visibility < VISIBILITY_DEGRADES_WHEN_BELOW) then
         maximumSpeedModifier = maximumSpeedModifier *
          (1.0 - (1.0 - visibility / VISIBILITY_DEGRADES_WHEN_BELOW) * (1.0 - MODIFIER_FOR_ZERO_VISIBILITY))
      end
   end
 
   return maximumSpeedModifier 
end

-- If the wind speed is above a certain value, degrade the speed modifier for each N kilometers/hour
-- above that wind speed (each whole amount, so if the base wind speed to be above is 40 km/h and the
-- delta is 10 km/5, when the wind speed is 50 km/h the movement will be degraded by 1 * WIND_DEGRADES_TO_KM_PER_DELTA, when
-- it is 60 km/h it will be degraded by 2 * WIND_DEGRADES_TO_KM_PER_DELTA, etc).
function modifyByWindSpeed(maximumSpeedModifier)
   if (WIND_DEGRADES_TO > 0) then
      local windSpeed = vrf:getWindSpeed(this)
	  
	  -- Wind speed is in meters/second so need to translate to kilometers/hour
	  windSpeed = windSpeed * 3.6
     if (windSpeed >= WIND_DEGRADES_UNTIL) then
        maximumSpeedModifier = maximumSpeedModifier * WIND_DEGRADES_TO
	  elseif ((windSpeed >= WIND_DEGRADES_WHEN_ABOVE) and ((WIND_DEGRADES_UNTIL - WIND_DEGRADES_WHEN_ABOVE) > 0)) then
        local percent = (windSpeed - WIND_DEGRADES_WHEN_ABOVE) / (WIND_DEGRADES_UNTIL - WIND_DEGRADES_WHEN_ABOVE)
	     local delta = percent * (1.0 - WIND_DEGRADES_TO)

		 maximumSpeedModifier = maximumSpeedModifier * (1.0 - delta)
	  end
   end
   
   return maximumSpeedModifier
end

-- The direction of the wind can also affect speed. A unit moving into the wind
-- will be slowed down, while a unit moving with the wind will be sped up. Some
-- units are affected more than others.
function adjustByWindDirection(maximumSpeedAdjustment)
   if (WIND_DIRECTION_SUSCEPTIBILITY > 0) then
      local orthoProjSpeed = 0
      local directionSpeedAdjustment = 0
      local windSpeed = vrf:getWindSpeed(this)
      
      -- Wind direction is the direction it is blowing FROM. We want
      -- the vector in which it is blowing, so adjust by pi radians.
      local windDirection = vrf:getWindDirection(this) + math.pi
      local windVector = Vector3D(0,0,0)
      windVector:setBearingInclRange(windDirection, 0, windSpeed)
      
      -- Calculate the orthogonal projection of the wind vector onto the unit's
      -- velocity vector.
      local velocityVector = this:getVelocity3D()
      velocityVector:setNorthEastDown(velocityVector:getNorth(), velocityVector:getEast(), 0)
      local top = velocityVector:dotVector3D(windVector)
      local bottom = velocityVector:dotVector3D(velocityVector)
      local orthoProj = velocityVector:getScaled(top/bottom)
         
      -- Now get the wind speed of the orthogonal projection to see how much of
      -- the wind's effect coincides with the unit's direction of movement.
      orthoProjSpeed = orthoProj:getRange()
      
      local directionSpeedAdjustment = WIND_DIRECTION_SUSCEPTIBILITY * orthoProjSpeed
      if top < 0 then
         directionSpeedAdjustment = directionSpeedAdjustment * -1
      end
      
      maximumSpeedAdjustment = maximumSpeedAdjustment + directionSpeedAdjustment
   end
   
   return maximumSpeedAdjustment
end

-- Modifies the maximum speed modifier by posture.  If modifier is 0 for a particular posture will not be
-- taken into account
function modifyByPosture(maximumSpeedModifier)
   local posture = this:getStateProperty("Posture")
   local postureModifier = MAXIMUM_SPEED_POSTURE_MODIFIER[posture]

   if (postureModifier ~= 0) then
      maximumSpeedModifier = maximumSpeedModifier * postureModifier
   end

   return maximumSpeedModifier
end

-- Called to see if footprints overlap.  If they do then will modify the maximum speed by the lowest possible
-- non-zero modifier
function modifyByFootprintOverlap(maximumSpeedModifier)
   local ent_is_ground
   local am_airborne = false
   if not am_ground then
      local airborne = this:getStateProperty("Is-Airborne")
      if airborne ~= nil and airborne then 
         am_airborne = true
      end
   end
   
   if (MAXIMUM_FOOTPRINT_OVERLAP_MODIFIER ~= 0) then
      local entityFp = this:getStateProperty("Physical-Footprint")

      if(entityFp ~= nil) then
         local resultOverlapModifier = MAXIMUM_FOOTPRINT_OVERLAP_MODIFIER
         local overlaps = false
         local currentLoc = this:getLocation3D()
         local nearby = vrf:getSimObjectsNearWithFilter(currentLoc,
              entityFp, {types={"11:-1:-1:-1:-1:-1:-1"}, ignore={this}})

         for entityNum,entity in pairs(nearby) do
         if (not entity:isDisaggregatedUnit()) then
               local overlapModifier = entity:getParameterProperty("MaximumSpeed-Footprint-Overlap-Modifier")
               if (overlapModifier ~= nil and overlapModifier > 0) then
                  local entityLoc = entity:getLocation3D()
                  local targetFp = entity:getStateProperty("Physical-Footprint")

                  if (targetFp ~= nil) then
                     local distance = 
                        math.max(0, math.abs(currentLoc:distanceToLocation3D(entityLoc) - targetFp))

                     if (entityFp > distance) then
                        ent_is_airborne = false
                        if entity:hasStateProperty("Is-Airborne") then
                           local airborne = entity:getStateProperty("Is-Airborne")
                           if airborne ~= nil and airborne then
                              ent_is_airborne = true
                           end
                        end
                        if am_airborne and ent_is_airborne then
                           if math.abs(currentLoc:getAlt() - entityLoc:getAlt()) < AIR_ALTITUDE_OVERLAP then
                              resultOverlapModifier = math.min(resultOverlapModifier, overlapModifier)
                              overlaps = true
                           end
                        elseif not am_airborne and not ent_is_airborne then
                           resultOverlapModifier = math.min(resultOverlapModifier, overlapModifier)
                           overlaps = true
                        end
                     end
                  end
               end
            end
         end

         if (overlaps) then
            maximumSpeedModifier = maximumSpeedModifier * resultOverlapModifier
         end
      end
   end

   return maximumSpeedModifier
end

-- Modifies the maximum speed modifier by MOPP level.  If modifier is 0 for a particular MOPP level,
-- will not be taken into account
function modifyByMoppLevel(maximumSpeedModifier)
   local moppLevel = this:getStateProperty("MOPP-Level")
   local moppLevelModifier = MAXIMUM_SPEED_MOPP_LEVEL_MODIFIER[moppLevel]
   
   if (moppLevelModifier ~= 0) then
      maximumSpeedModifier = maximumSpeedModifier * moppLevelModifier
   end

   return maximumSpeedModifier
end

-- Called each tick while this task is active.
function tick()
   
   -- Really only need to check this if the entities speed > 0
   if (this:getSpeed() > 0) then
      local maximumSpeedModifier = 1.0
   
      maximumSpeedModifier = modifyByPrecipitation(maximumSpeedModifier)
      maximumSpeedModifier = modifyByVisibility(maximumSpeedModifier)
      maximumSpeedModifier = modifyByWindSpeed(maximumSpeedModifier)
      maximumSpeedModifier = modifyByPosture(maximumSpeedModifier)
      maximumSpeedModifier = modifyByFootprintOverlap(maximumSpeedModifier)
      maximumSpeedModifier = modifyByMoppLevel(maximumSpeedModifier)

      -- Do not let value be zero, so set to minimum possible value
      if (maximumSpeedModifier <= LOWEST_POSSIBLE_VALUE) then
         maximumSpeedModifier = LOWEST_POSSIBLE_VALUE
      end
      
      local maximumSpeedAdjustment = 0.0
      maximumSpeedAdjustment = adjustByWindDirection(maximumSpeedAdjustment)

      -- Now set into state properties to effect movement

      this:setStateProperty("MaximumSpeedModifier", maximumSpeedModifier)
      this:setStateProperty("MaximumSpeedAdjustment", maximumSpeedAdjustment)
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
