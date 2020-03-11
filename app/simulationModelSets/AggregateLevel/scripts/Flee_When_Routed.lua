-- Flee When Routed

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- The heading to flee must be at least MIN_HEADING_FROM_ATTACKER
-- radians from the direction of any attacker.
local MIN_HEADING_FROM_ATTACKER = math.pi / 16
local MAX_HEADING_ATTEMPTS = 3

-- The minimum flee distance is the size of our base footprint. We we
-- re-evaluate our need to flee at that point.
local minFleeDistance = this:getParameterProperty("Base-Physical-Footprint")

-- The subtask ID of the move-to-location task
local subtaskId = -1

-- Called when reactive task is enabled or changes to the enabled state.
function checkInit()
   -- Set the tick period for this script while checking.
   vrf:setTickPeriod(3)
end

-- Called each tick period for this script while enabled but not in the active state.
function check()
   
   local needToFlee = false
   
   -- Flee if we are in rout posture and under attack
   if this:getStateProperty("Posture") == "Rout" then
      local attacksDefending = this:getStateProperty("Attacks-Defending")
      
      if next(attacksDefending) ~= nil then
         needToFlee = true
      end
   end
   
   return needToFlee
end

-- Called when the task first starts. Never called again.
function init()
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(5)
end

-- Called each tick while this task is active.
function tick()
   
   if subtaskId < 0 or
      vrf:isSubtaskComplete(subtaskId) then
      
      subtaskId = -1
      
      if this:getStateProperty("Posture") ~= "Rout" then
         -- We are no longer in rout posture. Stop fleeing.
         vrf:endTask(true)
         return
      end
      
      local attacksDefending = this:getStateProperty("Attacks-Defending")
      if next(attacksDefending) == nil then
         -- We are no longer being attacked. Stop fleeing.
         vrf:endTask(true)
         return
      end
      
      -- Determine direction to flee. 
      local currentLoc = this:getLocation3D()
      local vectorsToAttackers = {}
      for index, attack in pairs(attacksDefending) do
         -- Calculate vector to the attacker (if we haven't already)
         if vectorsToAttackers[attack.Attacker] == nil then
            local attacker = vrf:getSimObjectByUUID(attack.Attacker)
            if attacker:isValid() then
               vectorsToAttackers[attack.Attacker] = 
                  currentLoc:vectorToLoc3D(attacker:getLocation3D()):getUnit()
            end
         end
      end
      
      -- Find the vector which is the average of the vectors to the attackers. Then negate
      -- it to head in the opposite direction.
      local sumNorth = 0
      local sumEast = 0
      local sumDown = 0
      local attackerCount = 0
      for attacker, attackerVector in pairs(vectorsToAttackers) do
         sumNorth = sumNorth + attackerVector:getNorth()
         sumEast = sumEast + attackerVector:getEast()
         sumDown = sumDown + attackerVector:getDown()
         attackerCount = attackerCount + 1
      end
      
      local shouldFlee = false
      local vectorToFlee = Vector3D(0,0,0)
      if attackerCount > 0 then
         vectorToFlee:setNorthEastDown(sumNorth/attackerCount,
            sumEast/attackerCount, sumDown/attackerCount)
         vectorToFlee = vectorToFlee:getNegated():getUnit()
      
         -- If surrounded, this could mean moving directly towards one of our
         -- attackers. In this case, stay put and hope for a miracle.
         local keepChecking = true
         local numAttempts = 0
         while keepChecking do
            
            shouldFlee = true
            
            for attacker, attackerVector in pairs(vectorsToAttackers) do
               local headingDiff = vectorToFlee:headingDiff(attackerVector)
               if math.abs(headingDiff) < MIN_HEADING_FROM_ATTACKER then
                  -- This vector is not safe to flee
                  shouldFlee = false
                  break
               end
            end
            
            if not shouldFlee and numAttempts < MAX_HEADING_ATTEMPTS then
               local randomOffset = math.pi / math.random(6, 8)
               if math.random(0, 1) > 0 then randomOffset = randomOffset * -1 end
               vectorToFlee:setBearingInclRange(
                  vectorToFlee:getBearing() + randomOffset,
                  vectorToFlee:getInclination(), vectorToFlee:getRange())
               numAttempts = numAttempts + 1
            else
               keepChecking = false
            end
         end
      end
      
      if shouldFlee then
         -- Flee to minFleeDistance (and then check again)
         vectorToFlee = vectorToFlee:getScaled(minFleeDistance)
         local locToFlee = currentLoc:addVector3D(vectorToFlee)
         
         subtaskId = vrf:startSubtask("move-to-location-retrograde-task", 
            {aiming_point = locToFlee})
      else
         -- No fleeing. Either no one is attacking us, or we are completely surrounded. Just exit.
         vrf:endTask(true)
      end
   
   else
      -- Movement subtask is still running
      if this:getStateProperty("Posture") ~= "Rout" then
         -- We are no longer in rout posture. Stop fleeing.
         vrf:stopSubtask(subtaskId)
         vrf:endTask(true)
         return
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
