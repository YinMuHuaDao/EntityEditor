-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "aggregateUtils"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
attackSubtaskId = -1

-- Task Parameters Available in Script
--  taskParameters.NumberOfBombs Type: Integer
--  taskParameters.TargetLocation Type: Location3D
--  taskParameters.Weapon Type: String


-- Called when the task first starts. Never called again.
function init()

   -- Set the tick period for this script.
   vrf:setTickPeriod(0.001)
   
   if this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Bomb Location: Cannot attack while embarked."))
      vrf:endTask(false)
   else
   
      local allPowers = this:getStateProperty("Indirect-Fire-Power")
      local selectedPower = allPowers[taskParameters.Weapon]
      
      if(selectedPower ~= nil) then
      
         local myPosture = this:getStateProperty("Posture")
         if postureAllowsWeaponUse(selectedPower, myPosture) then
         
            -- Make sure point is in range
            local maxRange = selectedPower["Range"]
            local groundLoc = this:getLocation3D()
            groundLoc:setAlt(taskParameters.TargetLocation:getAlt())
            if(groundLoc:distanceToLocation3D(taskParameters.TargetLocation) > maxRange) then      
               printWarn(vrf:trUtf8("Selected location is not within range of weapon %1"):arg(taskParameters.Weapon))
               vrf:endTask(false)
            
            end
         else
            printWarn(vrf:trUtf8("Bomb Location: weapon cannot be used in the current posture"))
            vrf:endTask(false)
         end
      end
   end
end

-- Called each tick while this task is active.
function tick()
   
   if(attackSubtaskId == -1) then
      
      -- Start indirect fire subtask
      attackSubtaskId = vrf:startSubtask("Limited_Munition_Attack", 
         {NumberOfAttacks=taskParameters.NumberOfBombs, 
          TargetLocation=taskParameters.TargetLocation,
          Weapon=taskParameters.Weapon,
          CheckRange=false,
          Instantaneous=true,
          IsIndirect = true})
      
   elseif(vrf:isSubtaskComplete(attackSubtaskId)) then
      vrf:endTask(true)
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
