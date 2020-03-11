-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.
attackSubtaskId = -1

-- Task Parameters Available in Script
--  taskParameters.TargetLocation Type: Location3D - The center location of the Biological attack
--  taskParameters.AreaType Type: Entity Type - Entity type of the biological contamination area
--  taskParameters.AgentType Type: String - Biological agent of the attack


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   if this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("Biological Attack: Cannot attack while embarked."))
      vrf:endTask(false)
   end
end

-- Called each tick while this task is active.
function tick()

   if(attackSubtaskId == -1) then
      
      -- Start indirect fire subtask
      attackSubtaskId = vrf:startSubtask("NBC_Attack", 
         {NbcType="Biological", 
          TargetLocation=taskParameters.TargetLocation,
          AgentType=taskParameters.AgentType,
          AreaType=taskParameters.AreaType})
      
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
