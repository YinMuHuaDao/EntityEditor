-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.TargetLocation Type: Location3D - The center location of the NBC attack
--  taskParameters.AreaType Type: Entity Type - Entity type of the contamination area
--  taskParameters.AgentType Type: String - NBC agent of the attack
--  taskParameters.NbcType Type: String - General type of NBC contamination


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   if this:getEmbarkedOn():isValid() then
      printWarn(vrf:trUtf8("NBC Attack: Cannot attack while embarked."))
      vrf:endTask(false)
   end
end

-- Called each tick while this task is active.
function tick()
   
   local systemName = taskParameters.NbcType .. " Weapon"
   local system = this:getSystem(systemName)
   if(system == nil) then
      printWarn(vrf:trUtf8("NBC attack failed: No %1 system found."):arg(systemName))
   else
      local notFound = false
      local weaponRange, notFound = system:getAttribute("weapon-range")
      
      if(notFound) then
         printWarn(vrf:trUtf8("NBC attack failed: %1 system did not have a weapon-range attribute."):arg(systemName))
      else
         local contamRadius, notFound = system:getAttribute("contamination-radius")
         if(notFound) then
            printWarn(vrf:trUtf8("NBC attack failed: %1 system did not have a contamination-radius attribute."):arg(systemName))
         else
            local ammoUsage, notFound = system:getAttribute("ammunition-per-attack")
            if(notFound) then
               printWarn(vrf:trUtf8("NBC attack failed: %1 system did not have an ammunition-per-attack attribute."):arg(systemName))
            else
               
               -- Found all necessary system attributes. Check if we have the ammo.
               local ammo = this:getStateProperty("Ammunition-Categories")
               local ammoCat = ammo[taskParameters.NbcType]
               if(ammoCat == nil or ammoCat.Count <  ammoUsage) then
                  printWarn(vrf:trUtf8("NBC attack failed: Not enough %1 ammunition for attack."):arg(taskParameters.NbcType))
               else
               
                  -- Check the range.
                  local range = this:getStateProperty("Physical-Footprint") + weaponRange
                  if(taskParameters.TargetLocation:distanceToLocation3D(this:getLocation3D()) > range) then
                     printWarn(vrf:trUtf8("NBC attack failed: Target is out of range."))
                  else
                  
                     -- Ok, now we can create the contamination area.
                     
                     -- Create some vertices for the area based off our vector to it. We are
                     -- making a square facing our entity, with each side contamRadius*2
                     local vec = taskParameters.TargetLocation:vectorToLoc3D(this:getLocation3D())
                     vec = vec:getUnit()
                     vec:setBearingInclRange(vec:getBearing() + (math.pi * 0.25), vec:getInclination(),
                        vec:getRange())
                     local contamSq = contamRadius*contamRadius
                     vec = vec:getScaled(math.sqrt(contamSq*2))
                         
                     local vertices = {}
                     
                     -- Point one
                     vertices[1] = taskParameters.TargetLocation:addVector3D(vec)
                        
                     -- Point two
                     vec:setBearingInclRange(vec:getBearing() + (math.pi * 0.5), vec:getInclination(),
                        vec:getRange())
                     vertices[2] = taskParameters.TargetLocation:addVector3D(vec)
                     
                     -- Point three
                     vec:setBearingInclRange(vec:getBearing() + (math.pi * 0.5), vec:getInclination(),
                        vec:getRange())
                     vertices[3] = taskParameters.TargetLocation:addVector3D(vec)
                     
                     -- Point four
                     vec:setBearingInclRange(vec:getBearing() + (math.pi * 0.5), vec:getInclination(),
                        vec:getRange())
                     vertices[4] = taskParameters.TargetLocation:addVector3D(vec)
                     
                     vrf:createArea({entity_type=taskParameters.AreaType,
                        locations=vertices,
			object_name=taskParameters.NbcType .. " Contamination Area",
                        extended_data={
                           DtRwContaminationAreaType={
                           agenttype=taskParameters.AgentType,
                           terraintype="OTHER",
                           topographytype="OTHER",
                           vegetationtype="OTHER"}}})
                           
                     ammo[taskParameters.NbcType].Count = 
                        ammo[taskParameters.NbcType].Count - ammoUsage
                     this:setStateProperty("Ammunition-Categories", ammo)
                  end
               end
            end
         end
      end
   end
      
   vrf:endTask(true)
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
