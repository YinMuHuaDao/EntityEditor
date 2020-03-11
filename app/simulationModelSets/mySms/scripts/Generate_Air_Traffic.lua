-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Configuration Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"
require "airportDataUtils"

-- Global Variables. Global variables get saved when a scenario gets checkpointed.
-- They get re-initialized when a checkpointed scenario is loaded.

-- Master list of all flight plans 
myFlightPlanList = {}
myLastDepartureTime = -1
myProcessingDeparture = false
myDepartureFlightPlan = nil
myAirportFeatures = nil
myRunwayFeatures = nil
myLastDepartureTimePerAirport = {}
-- This is all the aircraft that the script has created.
myAircraftList = {}
-- Overall min period between aircraft creation
local theDepartureInterval = 60
-- Minimum time between departures at any given airport.
local theDepartureIntervalPerAirport = 60 * 5
local theAircraftTypes = {
   {type="1:2:71:57:1:1:4", max_range=6500, min_range=400}, --A320
   {type="1:2:71:57:1:1:1", max_range=6500, min_range=400},  --A320
   {type="1:2:71:57:1:1:2", max_range=6500, min_range=400},  --A320
   {type="1:2:71:57:1:1:3", max_range=6500, min_range=400},  --A320
   {type="1:2:225:57:1:1:1", max_range=9800, min_range=5000}, -- 747
   {type="1:2:225:57:1:11:0", max_range=5700, min_range=200}, -- Boeing 707
   {type="1:2:39:57:1:6:0", max_range=2650, min_range=200},  --CRJ
   {type="1:2:225:40:1:0:0", max_range=500, min_range=0} --Skyhawk
}
local theFlightPlanDirectory = "../data/flightPlans/"

-- Task Parameters Available in Script


function stringSplit(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

function printTable(t)
   for i, v in pairs(t) do
      printWarn(i, v)
   end
end

-- Returns a table for a flight plan entry with:
-- "name" as the airport/fix name
-- "location" as the location3D of the location
function buildFlightPlanEntry(fileLine)
   local parsedLine = stringSplit(fileLine, " ")
   local entry = {}
   entry["name"] = parsedLine[2]
   local altitude = tonumber(parsedLine[3] * 0.3048)
   -- Some flightplan files don't have altitude, so default them to 30000 feet.
   if (altitude < 10) then altitude = 30000 * 0.3048 end      
   local loc = Location3D(math.rad(tonumber(parsedLine[4])), math.rad(tonumber(parsedLine[5])), altitude)
   entry["location"] = loc
   return entry
end

-- Returns an array of flight plan entries.
function buildFlightPlan(file)   
   local flightPlan = {}
   local lineNum = 1
   for line in file:lines() do
      -- Ignore the first 4 lines, since they are just header.
      if (lineNum > 4) then
         --local lineArgs = stringSplit(line, " ")
         table.insert(flightPlan, buildFlightPlanEntry(line))
      end
      lineNum = lineNum +1
   end
   -- calculate total distance for flightplan
   local totalDistance = 0
   for i, entry in ipairs(flightPlan) do
      if (i > 1) then
         local distance = entry["location"]:vectorToLoc3D(flightPlan[i-1]["location"]):getRange()
         totalDistance = totalDistance + distance
      end
   end
   flightPlan["distance"] = totalDistance / 1000  -- Store in km
   return flightPlan
end

function isPointInBox(point, southWestCorner, northEastCorner)
   if (point:getLat() > southWestCorner:getLat() and
      point:getLat() < northEastCorner:getLat() and
      point:getLon() > southWestCorner:getLon() and
      point:getLon() < northEastCorner:getLon()) then
      return true
   end
   return false
end

function isLineInBox(startPoint, endPoint, southWestCorner, northEastCorner)
   if (isPointInBox(startPoint, southWestCorner, northEastCorner) or
      isPointInBox(endPoint, southWestCorner, northEastCorner)) then
      return true
   end
   local corners = {}
   table.insert(corners, southWestCorner)
   table.insert(corners, Location3D(northEastCorner:getLat(), southWestCorner:getLon(), 0))
   table.insert(corners, northEastCorner)
   table.insert(corners, Location3D(southWestCorner:getLat(), northEastCorner:getLon(), 0))
   if (vrf:intersectSegments2D(corners[1], corners[2], startPoint, endPoint)) then	
      return true
   end
   if (vrf:intersectSegments2D(corners[2], corners[3], startPoint, endPoint)) then	
      return true
   end
   if (vrf:intersectSegments2D(corners[3], corners[4], startPoint, endPoint)) then	
      return true
   end
   if (vrf:intersectSegments2D(corners[4], corners[1], startPoint, endPoint)) then	
      return true
   end
   return false
	
end


function areaOfInterestCorners()
   local ne = taskParameters.areaOfInterest:getLocations3D()[1]:makeCopy()
   local sw = ne:makeCopy()
   for i, point in ipairs(taskParameters.areaOfInterest:getLocations3D()) do
      ne:setLat(math.max(ne:getLat(), point:getLat()))
      ne:setLon(math.max(ne:getLon(), point:getLon()))
      sw:setLat(math.min(sw:getLat(), point:getLat()))
      sw:setLon(math.min(sw:getLon(), point:getLon()))
   end
   return sw, ne
end

-- Returns true if the flight plan overlaps the area of interest, or no area of interest is specified.
function useFlightPlan(flightPlan)
   if (#flightPlan < 3) then
      return false
   end
   if (taskParameters.areaOfInterest:isValid()) then
      if (mySouthWestCorner == nil) then
         mySouthWestCorner, myNorthEastCorner = areaOfInterestCorners()
      end
      for i, entry in ipairs(flightPlan) do
         if (i < #flightPlan) then
            if (isLineInBox(entry["location"], flightPlan[i+1]["location"], mySouthWestCorner, myNorthEastCorner)) then
               return true
            end
         end
      end
   else
      return true
   end
   return false
end


function readFlightPlans()
   local indexFile, message = io.open(theFlightPlanDirectory .. "flightPlanList.txt", "r")
   if (indexFile == nil) then
      printWarn("Error reading flight plan index: ", message)
   else
      for line in indexFile:lines() do
         local fpFile, message = io.open(theFlightPlanDirectory .. line)
         if (fpFile ~= nil) then
             local flightPlan = buildFlightPlan(fpFile)
             if (useFlightPlan(flightPlan)) then
               table.insert(myFlightPlanList, flightPlan)
             end
         else
            printWarn("Could not open flight plan file ", fpFile, ": ", message)
         end
      end
   end
   printInfo("Read ", #myFlightPlanList, " flight plans")
end

-- Creates a route and returns it.
-- The route will not include the first or last points on the flight plan.
function createFlightRoute(flightPlan)
   if (flightPlan["route"] == nil) then
      local pointList = {}
      for i, entry in ipairs(flightPlan) do
         if (i > 1 and i < #flightPlan) then  -- Don't put first or last point in the route
            table.insert(pointList, entry["location"])
            --printWarn(entry["location"])
         end
      end
      local routeName = flightPlan[1]["name"] .. " to " .. flightPlan[#flightPlan]["name"]
      local flightRoute = vrf:createRoute({locations=pointList, object_name=routeName, overlay="Flight Routes"})
      flightPlan["route"] = flightRoute
   end
   return flightPlan["route"]
end

-- Returns a flightplan entry to be used for the next departure
function chooseDepartureFlightplan()
   local attempts = 0
   local flifhtPlan = nil
   while (attempts < 10) do
      flightPlan = myFlightPlanList[math.random(#myFlightPlanList)]
      local depAirport = flightPlan[1]["name"]
      if (myLastDepartureTimePerAirport[depAirport] == nil or
         myLastDepartureTimePerAirport[depAirport] + theDepartureIntervalPerAirport < vrf:getSimulationTime()) then
         return flightPlan
      end
      attempts = attempts + 1
   end
   return nil
end

function aircraftValid(aircraft, flightDistance)
   printInfo(aircraft["max_range"], ", ", flightDistance, ", ", aircraft["min_range"])
   if (aircraft["max_range"] > flightDistance and aircraft["min_range"] < flightDistance) then
      return true
   end
   return false
end

function chooseAircraft(flightDistance)
   local numTries = 0
   local aircraft = nil
   while(numTries < 10) do
      aircraft = theAircraftTypes[math.random(#theAircraftTypes)]
      if (aircraftValid(aircraft, flightDistance)) then
         return aircraft
      end
   end
   -- Random choosing did not find one.  Just walk the list from the beginning to try and find one.
   for i, ac in ipairs(theAircraftTypes) do
      if (aircraftValid(ac, flightDistance)) then
         return ac
      end
   end
   return nil
end

-- Returns a location3D that is the given distance along the flightplan and also the heading to the next point.
function locationAndHeadingAlongFlightPlan(flightPlan, distance)
   local distLeft = distance
   for i, entry in ipairs(flightPlan) do
      if (i > 1) then
         local legVec = flightPlan[i-1]["location"]:vectorToLoc3D(entry["location"])
         if (legVec:getRange() > distLeft) then
            -- The location is along this segment, so now calculate it
            legVec = legVec:getScaled(distLeft / legVec:getRange())
            local midLoc = flightPlan[i-1]["location"]:addVector3D(legVec)
            return midLoc, legVec:getBearing()
         else
            distLeft = distLeft - legVec:getRange()
         end
      end
   end
end

function createAircraftEnroute(flightPlan, aircraftType)
   -- Random point along route that is at least 10km  from either end of the plan route
   local createStartDist = math.random(flightPlan["distance"] * 1000 - 20000) + 10000
   local startPos, startHeading = locationAndHeadingAlongFlightPlan(flightPlan, createStartDist)
   local plane = vrf:createEntity({location = startPos, heading = startHeading, entity_type=aircraftType["type"], force=3, clamp=false})
   table.insert(myAircraftList, plane)
   vrf:sendTask(plane, "Fly_Flightplan", {flightRoute=createFlightRoute(flightPlan), 
               destAirportLocation=flightPlan[#flightPlan]["location"], startInAir=true}, false)
end


-- Called when the task first starts. Never called again.
function init()
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   readFlightPlans()
   -- Create some enroute planes to start
   if (taskParameters.createEnroute == true and #myFlightPlanList > 0) then      
      -- Create 90% of max aircraft enroute at startup.  Remaining 10% will be created as time proceeds
      while (#myAircraftList < taskParameters.maxAircraft - taskParameters.maxAircraft * 0.1) do
         local flightPlan = myFlightPlanList[math.random(#myFlightPlanList)]
         local aircraft = chooseAircraft(flightPlan["distance"])
         createAircraftEnroute(flightPlan, aircraft)
      end
   end
    if (#myFlightPlanList < 1) then
      printWarn("No flight plans found.")
      vrf:endTask(false)
   end
   
end

-- Walks the aircraft list removing any that have been deleted, and also deleting any that have somehow crashed.
function checkActiveAircraft()
   for i, plane in ipairs(myAircraftList) do
      if (not plane:isValid()) then
         table.remove(myAircraftList, i)
      else
         if (plane:getDamageState() == "destroyed") then
            vrf:deleteObject(plane)
         end
      end
   end
end


-- Called each tick while this task is active.
function tick()  
   checkActiveAircraft()
   
   if (myProcessingDeparture) then
      if (myRunwayFeatures:isLoaded() and myAirportFeatures:isLoaded()) then
         local runway = findSuitableRunway(myDepartureFlightPlan[1]["location"], myRunwayFeatures, myAirportFeatures, 
            vrf:getWindDirection(myDepartureFlightPlan[1]["location"]), 1500, true)
         if (runway ~= nil) then
            local startHeading = runway:getLocations3D()[1]:vectorToLoc3D(runway:getLocations3D()[2]):getBearing()
            local startPos = runway:getLocations3D()[1]
            startPos:setAlt(startPos:getAlt() + 1)
            local aircraft = chooseAircraft(myDepartureFlightPlan["distance"])
            local plane = vrf:createEntity({location = startPos, heading = startHeading, entity_type=aircraft["type"], force=3, clamp=true})
            table.insert(myAircraftList, plane)
            vrf:sendTask(plane, "Fly_Flightplan", {takeoffRunway=runway, flightRoute=createFlightRoute(myDepartureFlightPlan), 
               destAirportLocation=myDepartureFlightPlan[#myDepartureFlightPlan]["location"]}, false)
            myLastDepartureTime = vrf:getSimulationTime()
            myLastDepartureTimePerAirport[myDepartureFlightPlan[1]["name"]] = vrf:getSimulationTime()
            myProcessingDeparture = false      
            myDepartureFlightPlan = nil
         else
            printWarn("No departure runway found for flight plan departing ", myDepartureFlightPlan[1]["name"])
            myProcessingDeparture = false      
            myDepartureFlightPlan = nil
         end
      end
   else
      -- check to see if we should start a new departure
      if (myLastDepartureTime < 0 or myLastDepartureTime + theDepartureInterval < vrf:getSimulationTime() and
         #myAircraftList < taskParameters.maxAircraft) then
         -- Start a new departure
         myDepartureFlightPlan = chooseDepartureFlightplan()
         if (myDepartureFlightPlan ~= nil) then
            printInfo("Starting flight from ", myDepartureFlightPlan[1]["name"], " to ", myDepartureFlightPlan[#myDepartureFlightPlan]["name"])
            myRunwayFeatures = vrf:getFeaturesWithinRange(myDepartureFlightPlan[1]["location"], 10000, {query="MAK_RUNWAYS"})
            myAirportFeatures = vrf:getFeaturesWithinRange(myDepartureFlightPlan[1]["location"], 10000, {query="MAK_AIRPORTS"})  
            -- Need to wait for the airports and runways to be loaded.
            myProcessingDeparture = true
         end
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
   for i, plane in ipairs(myAircraftList) do 
      vrf:deleteObject(plane)
   end
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
