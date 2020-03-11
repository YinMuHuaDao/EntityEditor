-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Task Parameters Available in Script
--  taskParameters.InsertionPoint Type: SimObject - Point helicopter should fly to and hover at to insert troops
--  taskParameters.MusterPoint Type: SimObject - Point troops move after they detach from rope
--  taskParameters.NumberTroops Type: Integer - Number of troops to insert
--  taskParameters.NumberRopes Type: Integer - Number of Ropes to use for insertion

myState= "Start"
myTaskId = -1
myRopes = {}
--guys on the rope
myOnRope = {}
myTroopsToInsert = {}
myTroopOffsets = {}
myGroundTroops = {}
myLastRopeIndex=1
myNumberOfTroopsInserting = -1

local theAircraftBottomDist = 0 - this:getParameter("right-support"):getUp()

-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.2)
end

-- Called each tick while this task is active.
function tick()
   local changeState =false
   if ( vrf:isSubtaskComplete(myTaskId) )then
      --check if done
      changeState = true
   else
      changeState = false
   end
   if ( myState == "Start" ) then
      --We start by tasking our helicopter to go to the insertion point.
      myTaskId = vrf:startSubtask("move-to-location",{aiming_point = hoverPoint(), at_distance=1.0})
      vrf:updateTaskVisualization("hover-point", "point", {location = hoverPoint(), size = 2, color={0, 255, 0, 128}})
      myState = "movingToInsertion"
   elseif (myState == "movingToInsertion"  and changeState) then
      --at location so grab list of embarked and start dropping      
      if (vrf:isTaskAvailable("Open_Sliding_Door")) then
         myTaskId = vrf:startSubtask("Open_Sliding_Door", {})
      else
         myTaskId = -1
      end
      myState = "Prepare"
   elseif (myState =="Prepare" and not vrf:isSubtaskRunning(myTaskId)) then
      myTaskId = vrf:startSubtask("Deploy_Ropes",{numberRopes = taskParameters.NumberRopes})
      myState = "deployRopes"
   elseif (myState == "deployRopes" and changeState ) then
      setUpInsertionTroops()
      getRopes()
      myState = "insertion"
   elseif ( myState == "insertion") then
      if ( #myTroopsToInsert > 0 ) then
         --Still have troops to drop in so check if it's time for another
	      if (timeForNextTroop() )then
	         insertTroop()
	      end
      end
      -- Still have guys on the rope?
      if ( next(myOnRope) ~= nil ) then
         --update guys on rope, check if anyone done
	      updateRope()
      elseif (next(myGroundTroops) ~= nil) then
         updateGnd()
      else
        for ind,rope in pairs(myRopes) do
	        --Remove the ropes
           vrf:deleteObject(rope)
	     end
	     -- Close the door if there is one
        if (vrf:isTaskAvailable("Close_Sliding_Door")) then
            myTaskId = vrf:startSubtask("Close_Sliding_Door", {})
        else
            myTaskId = -1
        end
        myState = "finish"
      end
   elseif (myState == "finish" and not vrf:isSubtaskRunning(myTaskId)) then
      vrf:endTask(true)
   end
end

-- Returns the location the helicopter should hover durring insertion
function hoverPoint()
   if (taskParameters.InsertionPoint:isValid()) then
      local hPoint = taskParameters.InsertionPoint:getLocation3D();
      hPoint:setAlt(hPoint:getAlt() + taskParameters.InsertionAltitude + theAircraftBottomDist)
      return hPoint
   else
      return nil
   end
end

function setUpInsertionTroops()
   local embarkedObjects = this:getEmbarkedObjects ()
   local i =1
   for index, embarkedObject in pairs( embarkedObjects ) do
      local entType =  embarkedObject:getEntityType()
      if ( vrf:entityTypeMatches(entType, EntityType.Lifeform()) )then
          -- add embarked troops to our list till we have number of guys we want to insert
          if ( i <= taskParameters.NumberTroops) then
             table.insert(myTroopsToInsert,embarkedObject)
	          
	          i = i+1
          end
      end
   end
   -- Since the actual number may not be the number specified in the task (if there are fewer on the aircraft that specified)
   -- record the actual number here for calculating destination offsets.
   myNumberOfTroopsInserting = #myTroopsToInsert
   for index, troop in ipairs(myTroopsToInsert) do
      setupDestination(troop, index)
   end
end

function getRopes()
   --Collect the ropes on this unit
   local ropeType = "5:1:0:27:6:-1:-1"
   local objs = vrf:getSimObjectsNear(this:getLocation3D(),20.0)
   for index, obj in pairs(objs) do
      if ( vrf:entityTypeMatches(obj:getEntityType(), ropeType) )then
         table.insert(myRopes,obj)
      end
   end
end

function setupDestination(embarkedObject,i)
   --Take the muster point and add offset
   local musterSpacing = 3.0
   local xOffset = (i-1) *musterSpacing - 0.5*(myNumberOfTroopsInserting - 1) * musterSpacing
   local loc = taskParameters.InsertionPoint:getLocation3D()
   local muster = nil
   if (taskParameters.MusterPoint:isValid()) then
      muster = taskParameters.MusterPoint:getLocation3D()
   else
      muster = taskParameters.InsertionPoint:getLocation3D()
   end
   --Make offset from our insertion point and musterpoint, minus the alitutde of course
   loc:setAlt(muster:getAlt())
   local bearingVector = loc:vectorToLoc3D(muster);
   --now offset if by our xoffset
   local bearing =  bearingVector:getBearing() + math.rad(90.0);
   if (xOffset < 0) then 
      bearing = bearing + math.rad(180)
   end
   local offset = Vector3D(0.0,0.0,0.0)
   offset:setBearingInclRange(bearing,0.0,xOffset)
   local dest = muster:addVector3D(offset)
   myTroopOffsets[embarkedObject:getUUID()] = dest
   offset:setBearingInclRange(bearing,0.0,30.0)
   dest =muster:addVector3D(offset)
end

function timeForNextTroop()
    -- if any guy on the rope is within 3 meters we can' go yet
    local startAlt = this:getLocation3D():getAlt()
    local ready = true
    --Don't bother if we don't have anyone on yet
    if ( next(myOnRope) ~= nil ) then
       for index, ent in pairs(myOnRope) do
       -- Add 1.8 for approx height of a human
       -- Checks for head of previous guy to be more than 3 meters below bottom of the aircraft.
       local onRopeAlt = ent:getLocation3D():getAlt() + 1.8
       local testAlt = startAlt - theAircraftBottomDist
       if (onRopeAlt + 1 > testAlt) then
	      --someone's too close
	      ready = false
	   end
	end
    end
    return ready
end

function insertTroop()
    local index = next(myTroopsToInsert)
    local troop = myTroopsToInsert[index]
    local taskId  = -1

    --Task him to Fast Rope
    taskId = vrf:sendTask(troop,"FastRoping",{Rope =myRopes[myLastRopeIndex]})
    if (taskParameters.NumberRopes > 1) then
        if (myLastRopeIndex == taskParameters.NumberRopes ) then
	        myLastRopeIndex = 1
	     else
	        myLastRopeIndex = myLastRopeIndex + 1
	     end
    end
    --remove from insertion table and add to onRope table
    table.remove(myTroopsToInsert,index)
    myOnRope[taskId] = troop
    myCheck = taskId
end

function updateRope()
   --Go thru on rope and see if anyone's done
   for index, ent in pairs(myOnRope) do
      if ( vrf:isTaskComplete(index) ) then
	      vrf:sendSetData(ent,"set-speed",{speed=3.0})
	      local taskId = vrf:sendTask(ent,"move-to-location",{aiming_point = myTroopOffsets[ent:getUUID()]})
	      myGroundTroops[taskId] = ent
	      myOnRope[index] = nil
      end
   end
end

function updateGnd()
   for gndIndex, gndEnt  in pairs( myGroundTroops) do
      --check if task complete
      if ( vrf:isTaskComplete(gndIndex) ) then
         --Set posture to crouch
	 vrf:sendSetData(gndEnt,"set-lifeform-posture",{lifeform_posture = "crouching" })
	 vrf:sendSetData(gndEnt,"set-lifeform-weapon-state",{lifeform_weapon_state = "weapon-in-fire-position" })
         myGroundTroops[gndIndex] = nil
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
