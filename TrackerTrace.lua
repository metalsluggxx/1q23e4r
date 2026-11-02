local _, addon = ...
local CF = addon.CF
local LIMIT, ALIAS_LIMIT, HISTORY_LIMIT = 256, 64, 5
local trace = {entries={}, aliases={}, serial=0, first=1, count=0, omitted=0, running=false}
CF.TrackerTrace = trace
local casts = {entries={}, aliases={}, serial=0, first=1, count=0, omitted=0}
CF.TrackerCastTrace = casts
local frame
CF.L_DE.TRACE_TITLE="Cursive · Ereignisaufzeichnung"
CF.L_EN.TRACE_TITLE="Cursive · Tracker trace"
CF.L_DE.TRACE_HINT="Kopieren: Strg+A, Strg+C. /cftrace 1 bis 5: gespeicherte Kämpfe (1 = neuester). /cftrace off: ausschalten."
CF.L_EN.TRACE_HINT="Copy: Ctrl+A, Ctrl+C. /cftrace 1 through 5: saved fights (1 = newest). /cftrace off: disable recording."
CF.L_DE.TRACE_ON="Cursive: Ereignisaufzeichnung eingeschaltet. /cftrace zeigt den letzten Kampf."
CF.L_EN.TRACE_ON="Cursive: tracker recording enabled. /cftrace shows the latest fight."
CF.L_DE.TRACE_OFF="Cursive: Ereignisaufzeichnung ausgeschaltet."
CF.L_EN.TRACE_OFF="Cursive: tracker recording disabled."
CF.L_DE.TRACE_CLEAR="Cursive: Ereignisaufzeichnung geleert."
CF.L_EN.TRACE_CLEAR="Cursive: tracker recording cleared."
CF.L_DE.TRACE_MISSING="Cursive: Kein gespeicherter Bericht an dieser Stelle. /cftrace 1 bis 5, neuester zuerst."
CF.L_EN.TRACE_MISSING="Cursive: No saved report at that position. /cftrace 1 through 5, newest first."

-- Diagnostic transitions and cast decisions only. No aura queries, widget
-- readback, health samples, combat-log access or changes to either model.
local function readable(value)
    if issecretvalue then
        local ok,result=pcall(issecretvalue,value)
        if not ok or result~=false then return false end
    end
    if canaccessvalue then
        local ok,result=pcall(canaccessvalue,value)
        if not ok or result~=true then return false end
    end
    return true
end
local function safeString(value)
    return readable(value) and type(value)=="string" and value or nil
end
local function clock()
    local ok, value = pcall(GetTime)
    return ok and readable(value) and type(value)=="number" and value==value
        and math.abs(value)<1e12 and value or 0
end
local function settings()
    if type(CursiveForeverDB)~="table" then return nil end
    return CursiveForeverDB
end
local function enabled()
    local db=settings()
    return not db or db.trackerTraceEnabled~=false
end
local function alias(key)
    key=safeString(key)
    if not key or key=="" then return "?" end
    if trace.aliases[key] then return trace.aliases[key] end
    if trace.serial>=ALIAS_LIMIT then return "D+" end
    trace.serial=trace.serial+1
    local result="D"..trace.serial
    trace.aliases[key]=result
    return result
end
local function unitLabel(unit)
    unit=safeString(unit)
    if not unit then return "?" end
    if unit=="none" or unit=="target" or unit=="focus" or unit=="mouseover"
        or unit=="pettarget" or unit=="targettarget"
        or unit=="player" or unit=="pet" or unit:match("^nameplate%d+$") then return unit end
    if unit:match("^sticky:") then return "remembered" end
    return "other"
end
local function castAlias(key)
    key=safeString(key)
    if not key or key=="" then return "?" end
    if casts.aliases[key] then return casts.aliases[key] end
    if casts.serial>=128 then return "C+" end
    casts.serial=casts.serial+1
    local result="C"..casts.serial
    casts.aliases[key]=result
    return result
end
local function append(line,buffer)
    buffer=buffer or trace
    local at=(buffer.first+buffer.count-1)%LIMIT+1
    if buffer.count==LIMIT then
        at=buffer.first; buffer.first=buffer.first%LIMIT+1; buffer.omitted=buffer.omitted+1
    else buffer.count=buffer.count+1 end
    buffer.entries[at]=string.format("%.3fs %s",math.max(0,clock()-(trace.started or clock())),line)
end
local function reset()
    trace.entries={}; trace.aliases={}; trace.serial=0
    trace.first=1; trace.count=0; trace.omitted=0; trace.started=clock()
    casts.entries={}; casts.aliases={}; casts.serial=0
    casts.first=1; casts.count=0; casts.omitted=0
    trace.running=false; trace.ended=nil; trace.id=nil; trace.localTime=nil
end
local function start(kind)
    reset()
    local db=settings()
    local sequence=db and db.trackerTraceSequence
    if not readable(sequence) or type(sequence)~="number" or sequence~=sequence
        or sequence<0 or sequence>=1e9 or sequence~=math.floor(sequence) then sequence=0 end
    trace.id=sequence+1
    if db then db.trackerTraceSequence=trace.id end
    trace.localTime="?"
    if type(date)=="function" then
        local ok,value=pcall(date,"%Y-%m-%d %H:%M:%S")
        if ok and safeString(value) then trace.localTime=value end
    end
    trace.running=true; append(kind)
end
local function record(action,row,reason,otherKey)
    if not trace.running or not enabled() then return end
    action=safeString(action) or "?"
    local parts={action}
    if row then
        parts[#parts+1]=alias(row.guid)
        parts[#parts+1]="unit="..unitLabel(row.unit)
        parts[#parts+1]="aura="..unitLabel(row.cfAuraUnit)
        parts[#parts+1]="retained="..tostring(row.cfRetainedAuras==true)
        parts[#parts+1]="unavailable="..tostring(row.cfUnavailable==true)
    end
    if safeString(reason) then parts[#parts+1]="reason="..reason end
    if readable(otherKey) and otherKey~=nil then parts[#parts+1]="current="..alias(otherKey) end
    append(table.concat(parts," "))
end
function CF.TraceTracker(...)
    -- A diagnostic failure must not interrupt the tracker.
    pcall(record,...)
end
local function recordCast(stage,castGUID,spellID,effectKey,key,selectedKey,reason)
    if not trace.running or not enabled() then return end
    local spell="?"
    if readable(spellID) and type(spellID)=="number" and spellID==spellID
        and spellID>=0 and spellID<1e9 and spellID==math.floor(spellID) then
        spell=tostring(spellID)
    end
    local effect=safeString(effectKey)
    if effect~="agony" and effect~="corruption" and effect~="immolate" then effect="other" end
    local parts={"CAST",safeString(stage) or "?","cast="..castAlias(castGUID),
        "spell="..spell,"effect="..effect,"assigned="..alias(key),"selected="..alias(selectedKey)}
    if safeString(reason) then parts[#parts+1]="reason="..reason end
    append(table.concat(parts," "),casts)
end
function CF.TraceExperimentalCast(...)
    -- A separate ring keeps repeated casts from evicting tracker transitions.
    pcall(recordCast,...)
end
local function eventRecord(event,unit)
    if event=="PLAYER_REGEN_DISABLED" and enabled() then
        if trace.running then CF.FinishTrackerTrace("RECORDING_REPLACED_BY_COMBAT_START") end
        start("COMBAT_START")
        return
    end
    if not trace.running or not enabled() then return end
    if event~="NAME_PLATE_UNIT_ADDED" and event~="NAME_PLATE_UNIT_REMOVED"
        and event~="PLAYER_TARGET_CHANGED" then return end
    if event=="PLAYER_TARGET_CHANGED" then unit="target" end
    local ok,key=pcall(UnitGUID,unit)
    append(event.." unit="..unitLabel(unit).." current="..(ok and alias(key) or "?"))
end
function CF.TraceTrackerEvent(...)
    pcall(eventRecord,...)
end
function CF.BuildTrackerTraceReport()
    local client="?"
    if GetBuildInfo then
        local ok,version,build=pcall(GetBuildInfo)
        if ok and safeString(version) and safeString(build) then client=version.."/"..build end
    end
    local lines={"Cursive tracker trace "..(CF.TrackerTraceVersion or "?"),
        "client="..client,
        string.format("session=%s local_time=%s duration=%.3fs",tostring(trace.id or "?"),
            trace.localTime or "?",math.max(0,(trace.ended or clock())-(trace.started or clock()))),
        string.format("entries=%d omitted=%d running=%s",trace.count,trace.omitted,tostring(trace.running)),
        "D1/D2: anonymized identities; no aura contents or hit confirmation."}
    if CF.DeathEvents then
        local registrations=CF.DeathEvents.registrations
        lines[#lines+1]="death events: UNIT_DIED="..(registrations.UNIT_DIED or "?")
            .." PARTY_KILL="..(registrations.PARTY_KILL or "?")
        lines[#lines+1]="DEATH_EVENT: readable victim GUID matched a tracked row; no hit confirmation or promise of complete delivery."
    end
    for i=0,trace.count-1 do lines[#lines+1]=trace.entries[(trace.first+i-1)%LIMIT+1] end
    lines[#lines+1]=string.format("CAST DECISIONS: entries=%d omitted=%d",casts.count,casts.omitted)
    lines[#lines+1]="C1/C2: anonymized attempts; selected is the SENT snapshot, assigned is the model association. ESTIMATE is not a hit confirmation."
    for i=0,casts.count-1 do lines[#lines+1]=casts.entries[(casts.first+i-1)%LIMIT+1] end
    return table.concat(lines,"\n")
end
function CF.FinishTrackerTrace(reason)
    pcall(function()
        if not trace.running then return end
        append(safeString(reason) or "COMBAT_END"); trace.ended=clock(); trace.running=false
        local db=settings()
        if db then
            local report=CF.BuildTrackerTraceReport()
            local history={report}
            if type(db.trackerTraceHistory)=="table" then
                for i=1,HISTORY_LIMIT-1 do
                    local old=safeString(db.trackerTraceHistory[i])
                    if old then history[#history+1]=old end
                end
            elseif safeString(db.trackerTraceLast) then
                -- Preserve the previous version's single report on upgrade.
                history[#history+1]=db.trackerTraceLast
            end
            db.trackerTraceHistory=history; db.trackerTraceLast=report
        end
    end)
end
function CF.GetTrackerTraceReport(index)
    local db=settings()
    if index==nil and trace.running then return CF.BuildTrackerTraceReport() end
    if index~=nil and (type(index)~="number" or index~=math.floor(index)
        or index<1 or index>HISTORY_LIMIT) then return nil end
    local requested=index or 1
    local history=db and db.trackerTraceHistory
    local report=type(history)=="table" and safeString(history[requested]) or nil
    if not report and requested==1 and db then report=safeString(db.trackerTraceLast) end
    if report then return report end
    if index==nil then return CF.BuildTrackerTraceReport() end
end
local function showReport(index)
    local report=CF.GetTrackerTraceReport(index)
    if not report then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(CF.T("TRACE_MISSING")) end
        return
    end
    if not frame then
        frame=CreateFrame("Frame","CursiveForeverTrackerTraceFrame",UIParent,"BackdropTemplate")
        frame:SetSize(760,480); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        CF.AuraLayoutUI.backdrop(frame)
        frame:EnableMouse(true); frame:SetMovable(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
        frame:SetClampedToScreen(true)
        local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        title:SetPoint("TOPLEFT",16,-16)
        frame.title=title
        local hint=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT",16,-45); hint:SetWidth(700); hint:SetJustifyH("LEFT")
        frame.hint=hint
        local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
        close:SetPoint("TOPRIGHT",-3,-3); close:SetScript("OnClick",function() frame:Hide() end)
        local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-72); scroll:SetPoint("BOTTOMRIGHT",-36,16)
        local edit=CreateFrame("EditBox",nil,scroll)
        edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(GameFontHighlightSmall)
        edit:SetWidth(700); edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed",function(self) self:ClearFocus(); frame:Hide() end)
        scroll:SetScrollChild(edit); frame.edit=edit; frame.scroll=scroll
        frame:SetScript("OnHide",function() edit:ClearFocus() end)
        local measure=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        measure:SetWidth(700); measure:Hide(); frame.measure=measure
    end
    frame.title:SetText(CF.T("TRACE_TITLE")); frame.hint:SetText(CF.T("TRACE_HINT"))
    frame.measure:SetText(report); frame.edit:SetHeight(math.max(360,frame.measure:GetStringHeight()+24))
    frame.edit:SetText(report); frame.scroll:SetVerticalScroll(0)
    frame:SetScale(math.min(1,(UIParent:GetWidth()-40)/760,(UIParent:GetHeight()-40)/480))
    frame:Show(); frame.edit:SetFocus(); frame.edit:HighlightText()
end
SLASH_CURSIVETRACKERTRACE1="/cftrace"
SlashCmdList.CURSIVETRACKERTRACE=function(message)
    local cmd=(message or ""):lower():match("^%s*(%S*)")
    local db=settings()
    if not db then return end
    if cmd=="off" then
        CF.FinishTrackerTrace("RECORDING_STOPPED"); db.trackerTraceEnabled=false
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(CF.T("TRACE_OFF")) end
    elseif cmd=="on" then
        db.trackerTraceEnabled=true
        if not trace.running then
            local ok,combat=pcall(UnitAffectingCombat,"player")
            if ok and readable(combat) and combat==true then pcall(start,"RECORDING_START_MID_COMBAT") end
        end
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(CF.T("TRACE_ON")) end
    elseif cmd=="clear" then
        local wasRunning=trace.running and enabled()
        db.trackerTraceLast=nil; db.trackerTraceHistory=nil; reset()
        if wasRunning then pcall(start,"RECORDING_RESTARTED_AFTER_CLEAR") end
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(CF.T("TRACE_CLEAR")) end
    else showReport(tonumber(cmd)) end
end
