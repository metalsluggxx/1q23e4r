local _, addon = ...
local CF = addon.CF
local D = {registrations={}}
CF.DeathEvents = D

-- Public standalone events on Forever 70374, independently tested with the
-- Death Probe. No combat-log subscription, aura access or widget readback.
-- Only a GUID already owned by a tracked row can cause a removal.
local recent, count = {}, 0
local SETTLE_SECONDS, RECENT_LIMIT = 2, 128
local receiver = CreateFrame("Frame")
D.frame = receiver

local function readable(value)
    if type(issecretvalue)=="function" then
        local ok, result=pcall(issecretvalue,value)
        if not ok or result~=false then return false end
    elseif type(canaccessvalue)~="function" then return false end
    if type(canaccessvalue)=="function" then
        local ok, result=pcall(canaccessvalue,value)
        if not ok or result~=true then return false end
    end
    return true
end

function D.ReadGUID(value)
    if not readable(value) or type(value)~="string" or value=="" or #value>256 then return nil end
    return value
end

function D.ReadUnitGUID(unit)
    if not readable(unit) or type(unit)~="string" then return nil end
    local ok, value=pcall(UnitGUID,unit)
    return ok and D.ReadGUID(value) or nil
end

local function clock()
    local ok, value=pcall(GetTime)
    if ok and readable(value) and type(value)=="number" and value==value
        and math.abs(value)<1e12 then return value end
end

local function prune(now)
    for key, expires in pairs(recent) do
        if expires<=now then recent[key]=nil; count=count-1 end
    end
end

function D.Reset()
    recent={}; count=0
end

function D.IsUnitDead(unit)
    if count==0 then return false end
    if not readable(unit) or type(unit)~="string" then return false end
    local now=clock()
    if not now then return false end
    prune(now)
    if count==0 then return false end
    local key=D.ReadUnitGUID(unit)
    return key and recent[key]~=nil or false
end

local function remember(key, now)
    if not now then return end
    prune(now)
    if not recent[key] and count>=RECENT_LIMIT then
        local oldest, expiry
        for candidate, at in pairs(recent) do
            if not expiry or at<expiry then oldest,expiry=candidate,at end
        end
        if oldest then recent[oldest]=nil; count=count-1 end
    end
    if not recent[key] then count=count+1 end
    recent[key]=now+SETTLE_SECONDS
end

function D.Handle(event, first, second)
    if event=="PLAYER_ENTERING_WORLD" then D.Reset(); return end
    local victim
    if event=="UNIT_DIED" then victim=first
    elseif event=="PARTY_KILL" then victim=second
    else return end
    -- PARTY_KILL's attacker is irrelevant, including when it is protected.
    local key=D.ReadGUID(victim)
    if not key then
        if CF.TraceTracker then CF.TraceTracker("DEATH_EVENT_IGNORED",nil,event.."_unreadable") end
        return
    end
    local now=clock()
    if now then prune(now) end
    if recent[key] then return end
    if CF.RemoveDeadTrackedGUID and CF.RemoveDeadTrackedGUID(key,event) then
        -- The death event may precede readable death flags. Briefly prevent
        -- that exact dead identity from being recreated during this ordering
        -- gap. No lifetime prediction, persistent blacklist or visibility rule.
        remember(key,now)
    end
end

for _, event in ipairs({"UNIT_DIED","PARTY_KILL","PLAYER_ENTERING_WORLD"}) do
    local ok=pcall(receiver.RegisterEvent,receiver,event)
    D.registrations[event]=ok and "REGISTERED" or "UNAVAILABLE"
end
receiver:SetScript("OnEvent",function(_,event,first,second)
    D.Handle(event,first,second)
end)
