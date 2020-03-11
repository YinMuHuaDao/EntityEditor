-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.Rope Type: SimObject

myTaskId = -1
myState = "start"

local theRopeStartOffset = VectorOffset3D(0.0, -0.2, -1.8)

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.08)
   --Get first vertex of rope and have the DI start at that point
   myStartPoint = getStartPoint(taskParameters.Rope:getLocation3D())
end

function getStartPoint(ropeLocation)
   --Take ropeLocation and set back about .2/.3
   --Create vector3d to rope location
   --This offset is due to some screwiness in rope creation and we want
   --the guy to not have the rope thru his head. Looks dumb.
   --local vec = Vector3D(-0.2,0.0,1.8)
   local vec = theRopeStartOffset:makeVectorRefToDirection(this:getEmbarkedOn():getDirection3D())
   local loc = ropeLocation:addVector3D(vec)
   return loc
end

-- Called each tick while this task is active.
function tick()
   if ( myTaskId == -1) then
      --set his posture to parachuting
      vrf:executeSetData("set-lifeform-posture",{lifeform_posture = "parachuting" })
      --Wait 2 secs to let the entity change posture animation so he's not standing up in mid air
      myTaskId = vrf:startSubtask("wait-duration", {seconds_to_wait = 1.5})
      myState="Prepare"
   elseif myState == "Prepare" then
      if (vrf:isSubtaskComplete(myTaskId) ) then
         -- So scriptedmovement task  uses entities current location so we need to get him outside helo to start
         --vrf:executeSetData("set-location",{location=myStartPoint})
         local height = vrf:getTerrainAltitudeBelow(myStartPoint)
         height = myStartPoint:getAlt() - height
         fastRope(height)
         myState = "fastRope"
         vrf:setTickPeriod(0.001)
      end
   elseif (myState == "fastRope") then
       if (vrf:isSubtaskComplete(myTaskId) ) then
            myState="finish"
	    end
	    --During the fast roping we check if we're at the ground--Helo might be lower than the rope length so clear animation task when hit gnd
--       local height = this:getHeightAboveTerrain() 
--       if (height< 0.5) then
          --we're close enough, we're done
--	      vrf:stopSubtask(myTaskId)
--         myLoc = this:getLocation3D()
--         myHeading = this:getHeading()
--         vrf:executeSetData("set-lifeform-posture",{lifeform_posture = "standing" })
         --Set weapon state
--	      vrf:executeSetData("set-lifeform-weapon-state",{lifeform_weapon_state = "weapon-in-fire-position" })
--         myState =  "finish"
--      end
   else    
      --disembark him
	   this:changeAttachment("")
      vrf:executeSetData("set-lifeform-posture",{lifeform_posture = "standing" })
      --Set weapon state
      vrf:executeSetData("set-lifeform-weapon-state",{lifeform_weapon_state = "weapon-in-fire-position" })
      -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
      -- Wrap it in an appropriate test for completion of the task.
      vrf:endTask(true)
   end
end

function fastRope(height)
    --Now task him to move down the rope
    local animation = buildFastRopeAnimation(height)
    --this:changeAttachment("")
    vrf:executeSetData("invisible", {invisible=2})
    myTaskId = vrf:startSubtask("animated-movement-task", { animation_model = animation, reference_heading = 0.0})
    --myTaskId = vrf:startSubtask("scripted-movement",{move_out_heading =0.0,scripted_movement_file="FastRope",
--               target_point = this:getName(),clamp_type = 0,completion_rule = 0})
end

function buildFastRopeAnimation(dropHeight)
   local maxDescentSpeed = 5.0 -- m/s
   local acceleration = 2.0 -- m/s^2
   --local numFrames = math.floor(takeoffTime * 5);
	local velocity = 0
	local position = 0
   local animation = ScriptAnimationModel(this)
   
   local offset = this:getOffsetFromParent();
   offset = offset:getNegated()
   offset = offset:addOffset(taskParameters.Rope:getOffsetFromParent())
   offset = offset:addOffset(theRopeStartOffset)
   -- Turning to get on rope
--   animation:addAnimationRow(1 / 5, 0, 0, 0, math.rad(0), 0, 0)
--   animation:addAnimationRow(1 / 5, 0, 0, 0, math.rad(30), 0, 0)
--   animation:addAnimationRow(1 / 5, 0, 0, 0, math.rad(60), 0, 0)
--   animation:addAnimationRow(1 / 5, 0, 0, 0, math.rad(90), 0, 0)
   
   local frameTime = 1/5
   while (position < dropHeight) do
      if (velocity < maxDescentSpeed) then
         velocity = velocity + acceleration * frameTime
      end      
      animation:addAnimationRow(frameTime, offset:getRight(), offset:getForward(), -position + offset:getUp(), 0, 0, 0)
      position = position + velocity * frameTime
   end
   -- Add a last row that is the same as the previous one.
   position = position - velocity * frameTime
   animation:addAnimationRow(frameTime, offset:getRight(), offset:getForward(), -position + offset:getUp(), 0, 0, 0)
   
   animation:setClampType(4)
   animation:setCompletionRule(4)
   
   return animation
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
