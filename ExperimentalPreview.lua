local _, addon = ...
local CF, X = addon.CF, {}
CF.Experimental = X
local P = CF.ExperimentalPlanner
local KEYS = {"agony","corruption","immolate"}
local SEEDS = {agony=980,corruption=172,immolate=348}
local DEFAULT_DURATION = {agony=24,corruption=18,immolate=15}
local DEFAULT_CAST = {agony=0,corruption=0,immolate=2}
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local model = {targets={},sent={},seen={},serial=0,busyUntil=0}
X.model=model
local catalog, cfg, frame, lastScan, scanIndex = {}, nil, nil, 0, 0
local lastSpellIDs = {}

local de = {
 TITLE="Handlungsvorschläge · EXPERIMENTAL", TOGGLE="Vorschläge: %s", ON="Ein", OFF="Aus",
 TIP="EXPERIMENTAL: Vorschläge aus geschätzten DoT-Zeiten. Linksklick schaltet um; Rechtsklick öffnet Prioritäten und Laufzeiten. Nur Omen der Pein, Verderbnis und Feuerbrand (Hexenmeister).",
 NOTE="Schätzung aus eigenen Zauberabschlüssen. Verfehlt, Widerstanden, Entfernen und Überschreiben werden nicht zuverlässig erkannt. Normales Zaubern auf das ausgewählte Ziel wird vorausgesetzt; keine Mauszeiger-/Fokusmakros.",
 LEGEND="Grün 1: jetzt fällig · Gold 1: später · Blau 2: danach · Setzen: Erstanwendung · Zaubert: Versuch läuft · ~: geschätzt · ?: unbekannt. Zaubername mit ? oben: Rechtsklick setzt erneut fällig.",
 PRIORITY="Vorschlagspriorität / DoT", DURATION="Laufzeit (s)", CAST="Zauberzeit (s)", AUTO="0 = automatisch / Grundwert; bei Bedarf eigene Werte eintragen.",
 GCD="Globale Abklingzeit (s)", RESET="Zeitmodell zurücksetzen", CLOSE="Schließen", NOW="Jetzt",
 ROW="EXPERIMENTAL", UNKNOWN="Ziel nicht lesbar", UNSUPPORTED="Die erste Experimental-Fassung unterstützt Hexenmeister mit Omen der Pein, Verderbnis und Feuerbrand.",
 UNOBSERVED="Laufzeit und bisheriger Verlauf unbekannt: kein automatischer Zaubervorschlag. Das sichtbare Raster prüfen; unbekannt bedeutet nicht fehlend.",
 INITIAL="Geschätzte Erstanwendung: Kampf ab Beginn erfasst, für diesen Gegner bisher keine eigene Anwendung erfasst. Kein Nachweis einer fehlenden Aura.",
 ESTIMATED="Geschätzte Anwendung aus einem Zauberabschluss; Treffer nicht bestätigt. Ziel beim Senden des Zaubers angenommen.",
 OBSERVED="Zuletzt aus frei lesbaren eigenen Aura-Daten übernommen; spätere Änderungen können verborgen bleiben.",
 MANUAL="Vom Spieler wieder als fällig eingeplant; keine Treffer- oder Aura-Bestätigung.",
 ACTION="Voraussichtlicher Zauberbeginn: in %.1f s", CORRECT="Alt + Rechtsklick: diesen DoT wieder als fällig einplanen.",
 APPLY="Setzen", CAST_ACTIVE="Zaubert", PLAN_PRIORITY="Gemeinsame DoT-Priorität: %d", SHARED_ORDER="Gemeinsame Reihenfolge einstellen",
 HELP="/cfexp öffnet die Einstellungen. /cfexp on | off | reset. /cfexp miss immolate (oder agony / corruption): beim aktuellen Ziel wieder fällig setzen.",
 CHANGED="Experimental-Vorschläge: %s. /cfexp für Einstellungen.", SAVED="Gespeichert je Charakter. Zeitmodell nur für diese Sitzung; Raven-Auswertung und Fluchwächter bleiben eigenständig.",
 CORRECTED="DoT für das ausgewählte Ziel wieder als fällig eingeplant.",
 NO_TARGET="Kein lesbares Ziel oder kein passender DoT für die Korrektur.",
 FUTURE="in %ss", CASTING="Versuch: %s", ATTEMPT="%s ?", PARTIAL="EXPERIMENTAL ?",
 PENDING="Zauberversuch noch offen. Die Vorschau rechnet für spätere Aktionen mit einer möglichen Anwendung; ein Treffer ist noch nicht bestätigt.",
 REVIEW="Letzter unbestätigter Zauberversuch auf diesem Gegner. Bei Verfehlen/Widerstehen: Rechtsklick auf diese Zeile setzt genau diesen DoT erneut fällig. Die Korrektur funktioniert auch, wenn der DoT nicht unter den nächsten zwei Vorschlägen steht.",
 OFFSCREEN="Außer Sicht: Die Planung führt bekannte Schätzungen weiter. Fortbestand der Effekte und ein unbeobachteter Tod sind nicht bestätigt.",
}
local en = {
 TITLE="Action suggestions · EXPERIMENTAL", TOGGLE="Suggestions: %s", ON="On", OFF="Off",
 TIP="EXPERIMENTAL: suggestions from estimated DoT timers. Left-click toggles; right-click opens priorities and durations. Bane of Agony, Corruption and Immolate only (Warlock).",
 NOTE="Estimated from your completed casts. Misses, resists, removals and replacements cannot be detected reliably. Assumes normal casting on the selected target; no mouseover/focus macros.",
 LEGEND="Green 1: due now · Gold 1: later · Blue 2: afterwards · Apply: first application · Casting: attempt pending · ~: estimated · ?: unknown. Right-click the spell name with ? above to mark it due again.",
 PRIORITY="Suggestion priority / DoT", DURATION="Duration (s)", CAST="Cast time (s)", AUTO="0 = automatic / base value; enter your own values if needed.",
 GCD="Global cooldown (s)", RESET="Reset timer model", CLOSE="Close", NOW="Now",
 ROW="EXPERIMENTAL", UNKNOWN="Target unreadable", UNSUPPORTED="The first Experimental build supports Warlocks with Bane of Agony, Corruption and Immolate.",
 UNOBSERVED="Unknown timer and prior history: no automatic cast suggestion. Check the visible grid; unknown does not mean missing.",
 INITIAL="Estimated first application: combat tracked from its start, with no own application recorded on this enemy. This does not prove aura absence.",
 ESTIMATED="Estimated application from a completed cast; hit unconfirmed. Assumes the target selected when the cast was sent.",
 OBSERVED="Last observed through readable own-aura data; later changes may be hidden.",
 MANUAL="Manually scheduled as due again; no hit or aura confirmation.",
 ACTION="Expected cast start: in %.1f s", CORRECT="Alt + right-click: schedule this DoT as due again.",
 APPLY="Apply", CAST_ACTIVE="Casting", PLAN_PRIORITY="Shared DoT priority: %d", SHARED_ORDER="Configure shared order",
 HELP="/cfexp opens settings. /cfexp on | off | reset. /cfexp miss immolate (or agony / corruption): schedule it as due on the current target.",
 CHANGED="Experimental suggestions: %s. /cfexp for settings.", SAVED="Saved per character. Timers are session-only; Raven analysis and the Curse Watcher remain independent.",
 CORRECTED="Scheduled the DoT as due again on the selected target.",
 NO_TARGET="No readable target or matching DoT for correction.",
 FUTURE="in %ss", CASTING="Attempt: %s", ATTEMPT="%s ?", PARTIAL="EXPERIMENTAL ?",
 PENDING="Cast attempt pending. The preview assumes a possible application to plan later actions; a hit has not been confirmed.",
 REVIEW="Last unconfirmed cast attempt on this enemy. On a miss/resist, right-click this label to schedule that exact effect as due again, even when it is no longer among the next two suggestions.",
 OFFSCREEN="Out of view: planning retains known estimates. Continued aura presence and an unobserved death are not confirmed.",
}
for k,v in pairs(de) do CF.L_DE["EXP_"..k]=v end
for k,v in pairs(en) do CF.L_EN["EXP_"..k]=v end
local function T(k) return CF.T("EXP_"..k) end
local function Print(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd8b15aCursive Experimental:|r "..s) end end

local function readable(v)
    if issecretvalue then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return false end
    end
    if canaccessvalue then
        local ok,access=pcall(canaccessvalue,v)
        if not ok or not access then return false end
    end
    return true
end
local function field(t,k)
    if not readable(t) or type(t)~="table" then return nil end
    if canaccesstable then
        local ok,access=pcall(canaccesstable,t)
        if not ok or not access then return nil end
    end
    local ok,v=pcall(function() return t[k] end)
    if ok and readable(v) then return v end
end
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok and readable(v) then return v end
end
local function number(v)
    if readable(v) and type(v)=="number" and v==v and math.abs(v)<1e12 then return v end
end
local function guid(unit)
    if type(unit)~="string" then return nil end
    local v=call(UnitGUID,unit)
    if type(v)=="string" and v~="" then return v end
end
local function name(unit)
    local v=call(UnitName,unit)
    return type(v)=="string" and v or nil
end
local function spellInfo(id)
    X.spellInfoCache=X.spellInfoCache or {}
    local now=GetTime()
    local cached=X.spellInfoCache[id]
    if cached and now-cached.at<.2 then return cached.info end
    local info=C_Spell and call(C_Spell.GetSpellInfo,id) or nil
    X.spellInfoCache[id]={at=now,info=info}
    return info
end
local function spellName(id)
    local v=C_Spell and call(C_Spell.GetSpellName,id)
    return type(v)=="string" and v or nil
end
local function warlock() return CF.GetPerformanceClassFile()=="WARLOCK" end
local function traceCast(stage,castGUID,spellID,r,reason)
    if CF.TraceExperimentalCast then
        pcall(CF.TraceExperimentalCast,stage,castGUID,spellID,r and r.effectKey,
            r and r.key,r and r.selectedKey,reason)
    end
end

function X.Init()
    if cfg then return cfg end
    CursiveForeverExperimentalDB=CursiveForeverExperimentalDB or {characters={}}
    if CF.Client then CF.Client.BindSavedVariables() end
    local db=CursiveForeverExperimentalDB
    db.characters=db.characters or {}
    local key=guid("player") or ((name("player") or "player").."-"..(call(GetRealmName) or "realm"))
    db.characters[key]=db.characters[key] or {}
    cfg=db.characters[key]
    cfg.enabled=cfg.enabled==true and (not CF.Client or CF.Client.supportsSuggestions)
    cfg.gcd=math.max(.5,math.min(3,tonumber(cfg.gcd) or 1.5))
    cfg.effects=cfg.effects or {}
    local order,seen={},{}
    for _,k in ipairs(type(cfg.order)=="table" and cfg.order or KEYS) do
        if SEEDS[k] and not seen[k] then order[#order+1]=k; seen[k]=true end
    end
    for _,k in ipairs(KEYS) do
        if not seen[k] then order[#order+1]=k end
        cfg.effects[k]=cfg.effects[k] or {}
        local e=cfg.effects[k]
        e.enabled=e.enabled~=false
        e.duration=math.max(0,math.min(120,tonumber(e.duration) or 0))
        e.castTime=math.max(0,math.min(10,tonumber(e.castTime) or 0))
    end
    cfg.order=order
    X.cfg=cfg
    return cfg
end

-- Fixed-slot order is the single source of priority. The legacy order field
-- remains a derived compatibility value, never a second editable preference.
function X.SyncOrder()
    X.Init()
    if not CF.GetAuraSlotKeys then return cfg.order end
    local order,seen={},{}
    for _,key in ipairs(CF.GetAuraSlotKeys()) do
        if SEEDS[key] and not seen[key] then order[#order+1]=key; seen[key]=true end
    end
    -- Enabled effects without a fixed slot follow the selected slots in the
    -- same catalogue order used by the layout editor.
    for _,entry in ipairs(CF.GetAuraLayoutCatalog()) do
        local key=entry.key
        if SEEDS[key] and not seen[key] then order[#order+1]=key; seen[key]=true end
    end
    for _,key in ipairs(KEYS) do
        if not seen[key] then order[#order+1]=key; seen[key]=true end
    end
    cfg.order=order
    return order
end

function X.RefreshCatalog()
    X.Init()
    X.SyncOrder()
    local rankCache=CF.filterSpellRanks and CF.filterSpellRanks.WARLOCK or {}
    catalog={}
    for _,s in ipairs(CF.GetAuraLayoutCatalog()) do
        if SEEDS[s.key] then
            local e={key=s.key,ids={},spellID=lastSpellIDs[s.key] or SEEDS[s.key]}
            for _,id in ipairs(s.ids) do e.ids[id]=true end
            -- The filter cache also holds unlearned rank candidates. Use it
            -- only for recognition, never as evidence of the player's rank.
            for id in pairs(rankCache[s.key] or {}) do e.ids[id]=true end
            e.name=spellName(e.spellID) or spellName(SEEDS[s.key]) or s.key
            catalog[s.key]=e
        end
    end
    X.catalog=catalog
end

local function effectForSpell(id)
    if not number(id) then return nil end
    local n=spellName(id)
    for _,k in ipairs(KEYS) do
        local e=catalog[k]
        if e and (e.ids[id] or (n and n==e.name)) then return k end
    end
end
local function effectSpec(k,priority,record)
    local c,options=catalog[k],cfg.effects[k]
    if not c or not options.enabled then return nil end
    local settings=CF.GetClassFilterStorage("WARLOCK")[k]
    local context=CF.GetAuraContext()
    if settings and settings[context]==false then return nil end
    local id=(record and record.spellID) or c.spellID
    local duration=options.duration>0 and options.duration or nil
    if not duration and record then duration=record.observedDuration end
    -- Rank 2 Corruption's 15 seconds was observed on the user's 70338 client.
    if not duration and k=="corruption" then
        if id==6222 then duration=15 elseif id==172 then duration=12 end
    end
    duration=duration or DEFAULT_DURATION[k]
    local info=spellInfo(id)
    local castMS=number(field(info,"castTime"))
    local cast=options.castTime>0 and options.castTime or (castMS and castMS/1000) or DEFAULT_CAST[k]
    return {key=k,priority=priority,name=c.name,spellID=id,duration=duration,castTime=cast,
        expiresAt=record and record.expiresAt,confidence=record and record.confidence or "unobserved"}
end

local function target(key,now)
    local t=model.targets[key]
    if not t then
        model.serial=model.serial+1
        t={key=key,order=model.serial,effects={},
            initialEligible=model.initialCoverage==true or model.initialReady==true}
        model.targets[key]=t
    end
    t.lastSeen=now
    return t
end

-- This is an explicit planning assumption for a fully tracked new fight,
-- never an aura observation. Keep the original nil-timer rule in the planner.
local function planEffect(k,priority,t,now)
    local e=effectSpec(k,priority,t.effects[k])
    if e and not e.expiresAt and model.initialCoverage and t.initialEligible
        and not (t.initialBlocked and t.initialBlocked[k]) then
        e.expiresAt=now
        e.confidence="initial"
    end
    return e
end

function X.InvalidateInitial()
    model.initialCoverage=false; model.initialReady=false
    for _,t in pairs(model.targets) do t.initialEligible=false end
end

function X.CombatChanged(active)
    if active then
        if model.fightActive then return end
        model.fightActive=true
        model.initialCoverage=model.initialReady==true
        model.initialReady=false
    else
        model.fightActive=false; model.initialCoverage=false
        -- A subsequent new fight can be followed from its start. Existing
        -- incomplete target histories remain ineligible until forgotten.
        model.initialReady=true
    end
end

function CF.ExperimentalEnabled() return X.Init().enabled and warlock() end
function CF.ExperimentalWidth() return CF.ExperimentalEnabled() and 128 or 0 end
function X.Reset()
    traceCast("RESET",nil,nil,nil,"world_entry_or_manual_reset")
    model.targets={}; model.sent={}; model.seen={}; model.activeCast=nil; model.busyUntil=0
    model.initialCoverage=false; model.fightActive=false
    model.initialReady=call(UnitAffectingCombat,"player")==false and call(InCombatLockdown)==false
    X.lastPlan={}; lastScan=0; scanIndex=0
end
function X.ForgetTarget(key)
    if not key then return end
    model.targets[key]=nil
    for id,r in pairs(model.sent) do
        if r.key==key then
            traceCast("DISCARD",id,r.spellID,r,"target_removed")
            model.sent[id]=nil
        end
    end
    if model.activeCast and model.activeCast.key==key then
        model.activeCast=nil
    end
    X.lastPlan={}
end
function CF.ToggleExperimental()
    if CF.Client and not CF.Client.supportsSuggestions then CF.ClientFeatureNotice(); return false end
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    X.Init()
    if not warlock() then Print(T("UNSUPPORTED")); return end
    cfg.enabled=not cfg.enabled
    -- Display toggles must not discard casts already observed this session.
    X.RefreshCatalog()
    if CF.ApplyAuraLayoutToAllRows then CF.ApplyAuraLayoutToAllRows() end
    if X.RefreshSettings then X.RefreshSettings() end
    if X.RefreshToggle then X.RefreshToggle() end
    Print(string.format(T("CHANGED"),T(cfg.enabled and "ON" or "OFF")))
end

local function allowedAuraRead()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        return call(C_Secrets.ShouldAurasBeSecret)==false
    end
    return call(InCombatLockdown)==false
end

function X.Observe(unit,key,now)
    if not allowedAuraRead() or not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellName then return end
    if guid(unit)~=key then return end
    local t=target(key,now)
    for _,k in ipairs(KEYS) do
        local c=catalog[k]
        if c then
            local aura=call(C_UnitAuras.GetAuraDataBySpellName,unit,c.name,"HARMFUL|PLAYER")
            local expiry=number(field(aura,"expirationTime"))
            local duration=number(field(aura,"duration"))
            local id=number(field(aura,"spellId"))
            local source=field(aura,"sourceUnit")
            if expiry and expiry>now and duration and duration>0 and duration<=120
                and effectForSpell(id)==k and type(source)=="string"
                and (source=="player" or call(UnitIsUnit,source,"player")==true) then
                t.effects[k]={expiresAt=expiry,observedDuration=duration,spellID=id,confidence="observed"}
            end
            -- nil/redacted is unknown; never remove a timer or infer absence.
        end
    end
end

function X.Sent(targetName,castGUID,spellID,now)
    if not warlock() then return end
    if not readable(castGUID) or type(castGUID)~="string" then
        X.InvalidateInitial()
        traceCast("SENT_REJECT",castGUID,spellID,nil,"cast_id_unusable"); return
    end
    if not number(spellID) then
        X.InvalidateInitial()
        traceCast("SENT_REJECT",castGUID,spellID,nil,"spell_id_unusable"); return
    end
    X.Init()
    if not next(catalog) then X.RefreshCatalog() end
    local k=effectForSpell(spellID)
    if k then lastSpellIDs[k]=spellID; catalog[k].spellID=spellID end
    local selectedKey=guid("target")
    local recipient=CF.ResolveCastRecipient and CF.ResolveCastRecipient(targetName,castGUID,spellID)
    local recipientUnit=recipient and recipient.unit or (not recipient and "target" or nil)
    local key=recipient and recipient.guid or (not recipient and selectedKey or nil)
    -- Preserve the existing association requirements and short-circuit API
    -- reads; retain only their diagnostic outcome, never the target's name.
    local targetReadable=readable(targetName)
    local targetUsable=targetReadable and type(targetName)=="string" and targetName~=""
    local selectedName=targetUsable and recipientUnit and name(recipientUnit) or nil
    local namesMatch=targetUsable and targetName==selectedName
    local attackable=namesMatch and recipientUnit and call(UnitCanAttack,"player",recipientUnit)
    local targetMatches=namesMatch and attackable==true
    if k and (not targetMatches or not key) then X.InvalidateInitial() end
    local reason=not targetReadable and "sent_target_unreadable"
        or (not targetUsable and "sent_target_empty_or_invalid")
        or (not selectedName and "selected_name_unavailable")
        or (not namesMatch and "target_name_mismatch")
        or (attackable~=true and "target_not_attackable")
        or (not key and "selected_guid_unavailable") or "matched"
    local spec=k and effectSpec(k,1,{spellID=spellID})
    local ms=number(field(spellInfo(spellID),"castTime"))
    local cast=spec and spec.castTime or (ms and ms/1000) or 0
    local r={effectKey=k,key=targetMatches and key or nil,selectedKey=selectedKey,spellID=spellID,at=now,
        previousBusy=model.busyUntil,previousActive=model.activeCast,
        endsAt=now+cast,actionEnd=now+math.max(cfg.gcd,cast)}
    if model.sent[castGUID] then traceCast("DISCARD",castGUID,spellID,model.sent[castGUID],"sent_id_replaced") end
    model.sent[castGUID]=r
    -- Freeze the selected target at SENT. Never use a post-cast target snapshot.
    model.activeCast=r; r.castGUID=castGUID
    model.busyUntil=r.actionEnd
    traceCast("SENT",castGUID,spellID,r,reason)
end

function X.Succeeded(castGUID,spellID,now)
    if not warlock() then return end
    if not readable(castGUID) or type(castGUID)~="string" then
        X.InvalidateInitial()
        traceCast("SUCCEEDED_REJECT",castGUID,spellID,nil,"cast_id_unusable"); return
    end
    if not number(spellID) then
        X.InvalidateInitial()
        traceCast("SUCCEEDED_REJECT",castGUID,spellID,nil,"spell_id_unusable"); return
    end
    if model.seen[castGUID] then
        traceCast("SUCCEEDED_REJECT",castGUID,spellID,nil,"duplicate_success"); return
    end
    local r=model.sent[castGUID]
    model.sent[castGUID]=nil
    model.seen[castGUID]=now
    if not r or r.spellID~=spellID or now-r.at>20 then
        if effectForSpell(spellID) or (r and r.effectKey) then X.InvalidateInitial() end
        traceCast("SUCCEEDED_REJECT",castGUID,spellID,r,not r and "missing_sent"
            or (r.spellID~=spellID and "spell_id_mismatch") or "sent_expired")
        return
    end
    if model.activeCast==r then model.activeCast=nil end
    model.busyUntil=math.max(now,r.at+cfg.gcd,model.activeCast and model.activeCast.actionEnd or 0)
    if not r.key or not r.effectKey then
        traceCast("SUCCEEDED_SKIP",castGUID,spellID,r,not r.key and "unassigned_target" or "untracked_spell"); return
    end
    local t=target(r.key,now)
    local old=t.effects[r.effectKey]
    local spec=effectSpec(r.effectKey,1,{spellID=spellID,observedDuration=old and old.observedDuration})
    if not spec then
        t.initialBlocked=t.initialBlocked or {}; t.initialBlocked[r.effectKey]=true
        traceCast("SUCCEEDED_SKIP",castGUID,spellID,r,"effect_disabled"); return
    end
    t.effects[r.effectKey]={expiresAt=now+spec.duration,spellID=spellID,
        observedDuration=old and old.observedDuration,confidence="estimated",attemptAt=now}
    t.lastEffect=r.effectKey
    traceCast("ESTIMATE",castGUID,spellID,r,"cast_completed_hit_unconfirmed")
end

function X.Failed(castGUID,eventName,spellID)
    if not readable(castGUID) or type(castGUID)~="string" then
        traceCast(eventName or "FAILED",castGUID,spellID,nil,"cast_id_unusable"); return
    end
    local r=model.sent[castGUID]; model.sent[castGUID]=nil
    local reportedSpell=spellID
    if readable(reportedSpell) and reportedSpell==nil and r then reportedSpell=r.spellID end
    traceCast(eventName or "FAILED",castGUID,reportedSpell,r,r and "pending_discarded" or "no_pending_cast")
    if r and model.activeCast==r then
        local previous=r.previousActive
        model.activeCast=previous and model.sent[previous.castGUID]==previous and previous or nil
        model.busyUntil=r.previousBusy or 0
    end
    -- Failed/interrupted casts never overwrite an already-running effect.
end

function X.MarkDue(key,k)
    if not key or not SEEDS[k] then return false end
    local t=target(key,GetTime())
    local old=t.effects[k]
    t.effects[k]={expiresAt=GetTime(),confidence="manual",spellID=old and old.spellID,
        observedDuration=old and old.observedDuration}
    -- A manual miss correction must also cancel the same virtual pending
    -- application; a late SUCCEEDED must not overwrite the correction.
    for id,r in pairs(model.sent) do
        if r.key==key and r.effectKey==k then
            traceCast("DISCARD",id,r.spellID,r,"manual_correction")
            if model.activeCast==r then model.activeCast=nil end
            model.sent[id]=nil
        end
    end
    traceCast("MANUAL_DUE",nil,old and old.spellID,{key=key,effectKey=k},"player_correction")
    return true
end

local function border(f,r,g,b,a)
    f:SetBackdropBorderColor(r,g,b,a or 1)
end
local function makePanel(row)
    local iconCenter = CF.GetAuraLayoutIconCenter and CF.GetAuraLayoutIconCenter() or 35
    local p=CreateFrame("Frame",nil,row)
    p:SetWidth(124); p:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,0); p:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,0)
    local line=p:CreateTexture(nil,"ARTWORK"); line:SetColorTexture(.38,.28,.12,.6)
    line:SetWidth(1); line:SetPoint("TOPLEFT",0,-3); line:SetPoint("BOTTOMLEFT",0,3)
    p.review=CreateFrame("Button",nil,p)
    p.review:SetSize(96,12); p.review:SetPoint("TOP",p,"TOP",0,-2)
    p.review:RegisterForClicks("RightButtonUp")
    p.label=p.review:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    p.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",8,"OUTLINE")
    p.label:SetPoint("CENTER"); p.label:SetSize(96,10); p.label:SetWordWrap(false)
    p.label:SetText("EXPERIMENTAL"); p.label:SetTextColor(.78,.65,.4)
    p.review:SetScript("OnClick",function(self,mouse)
        if mouse=="RightButton" and self.key and self.effectKey then
            X.MarkDue(self.key,self.effectKey); X.Tick(GetTime())
        end
    end)
    p.review:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(T("TITLE"),1,.78,.3)
        GameTooltip:AddLine(T(self.pending and "PENDING" or (self.effectKey and "REVIEW" or "UNOBSERVED")),1,.78,.35,true)
        if row.offscreen then GameTooltip:AddLine(T("OFFSCREEN"),1,.78,.35,true) end
        GameTooltip:Show()
    end)
    p.review:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    p.icons={}
    for i=1,2 do
        local b=CreateFrame("Button",nil,p,"BackdropTemplate")
        b:SetSize(34,34); b:SetPoint("CENTER",p,"TOP",i==1 and -28 or 28,-iconCenter)
        b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
        b:SetBackdropColor(.03,.02,.01,.9); border(b,.38,.28,.12)
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",2,-2); b.icon:SetPoint("BOTTOMRIGHT",-2,2)
        b.icon:SetTexCoord(.08,.92,.08,.92)
        b.clock=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        b.clock:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
        b.clock:SetPoint("TOP",b,"BOTTOM",0,-2); b.clock:SetWidth(52); b.clock:SetJustifyH("CENTER")
        b.number=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        b.number:SetPoint(i==1 and "BOTTOMLEFT" or "BOTTOMRIGHT",b,i==1 and "TOPLEFT" or "TOPRIGHT",i==1 and -12 or 12,2)
        b.estimate=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); b.estimate:SetPoint("TOPRIGHT",-3,-2)
        b.estimate:SetTextColor(1,.76,.3)
        b:RegisterForClicks("RightButtonUp")
        b:SetScript("OnClick",function(self,button)
            if button=="RightButton" and IsAltKeyDown() and self.action and not self.pendingCast then
                X.MarkDue(self.action.targetKey,self.action.effectKey); X.Tick(GetTime())
            end
        end)
        b:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(T("TITLE"),1,.78,.3)
            local a=self.action
            if a then
                GameTooltip:AddLine(a.name or a.effectKey,1,1,1)
                if self.pendingCast then
                    GameTooltip:AddLine(T("PENDING"),1,.78,.35,true)
                else
                    GameTooltip:AddLine(string.format(T("ACTION"),math.max(0,a.startAt-GetTime())),1,1,1)
                    GameTooltip:AddLine(string.format(T("PLAN_PRIORITY"),a.priority),.8,.8,.8,true)
                    local confidence=a.confidence=="observed" and "OBSERVED" or (a.confidence=="manual" and "MANUAL"
                        or (a.confidence=="initial" and "INITIAL" or (a.confidence=="unobserved" and "UNOBSERVED" or "ESTIMATED")))
                    GameTooltip:AddLine(T(confidence),1,.78,.35,true)
                    GameTooltip:AddLine(T("CORRECT"),.8,.8,.8,true)
                end
                if row.offscreen then GameTooltip:AddLine(T("OFFSCREEN"),1,.78,.35,true) end
            else GameTooltip:AddLine(T(self.unknownEffect and "UNOBSERVED" or "UNKNOWN"),1,.78,.35,true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        p.icons[i]=b
    end
    row.cfExperimentalPanel=p
    return p
end

function CF.ExperimentalLayoutRow(row)
    if not CF.ExperimentalEnabled() or not row.unit or (row.cfUnavailable and not row.offscreen) then
        if row.cfExperimentalPanel then row.cfExperimentalPanel:Hide() end
        return
    end
    local p=row.cfExperimentalPanel or makePanel(row)
    -- Reuse this addon-owned panel while following the current row geometry.
    -- Native aura widgets and the recommendation model are not changed here.
    local center=CF.GetAuraLayoutIconCenter and CF.GetAuraLayoutIconCenter() or 35
    for index,button in ipairs(p.icons) do
        button:ClearAllPoints()
        button:SetPoint("CENTER",p,"TOP",index==1 and -28 or 28,-center)
    end
    p:Show()
end

local function draw(row,actions,now,unknown,t,active)
    local p=row.cfExperimentalPanel or makePanel(row)
    p:Show()
    p.review.key=nil; p.review.effectKey=nil; p.review.pending=nil
    p.label:SetText(unknown and T("PARTIAL") or "EXPERIMENTAL")
    local k=t and t.lastEffect
    local e=k and t.effects[k]
    if active and t and active.key==t.key and active.effectKey then
        p.review.pending=true
        p.label:SetText(string.format(T("CASTING"),catalog[active.effectKey].name))
    elseif e and e.confidence=="estimated" then
        p.review.key=t.key; p.review.effectKey=k
        p.label:SetText(string.format(T("ATTEMPT"),catalog[k].name))
    end
    for i,b in ipairs(p.icons) do
        local a=actions[i]; b.action=a; b.unknownEffect=t and unknown
        b.pendingCast=a and active and active.key==a.targetKey and active.effectKey==a.effectKey or false
        if a then
            b:Show(); b.icon:SetTexture(CF.SafeSpellTexture(a.spellID) or UNKNOWN_ICON)
            local dt=math.max(0,a.startAt-now)
            -- Keep scheduling untouched. Separate a first application or open
            -- cast from an already-running effect's future renewal countdown.
            b.clock:SetText(b.pendingCast and T("CAST_ACTIVE") or (a.confidence=="initial" and T("APPLY")
                or (dt<.05 and T("NOW") or string.format(T("FUTURE"),string.format(dt<10 and "%.1f" or "%.0f",dt)))))
            b.estimate:SetText((row.offscreen or a.confidence=="estimated" or a.confidence=="initial" or a.confidence=="simulated") and "~" or "")
            b.number:SetText(not b.pendingCast and a.globalIndex and tostring(a.globalIndex) or "")
            if b.pendingCast then border(b,.38,.28,.12)
            elseif a.globalIndex==1 and dt<.05 then border(b,.18,1,.28); b.number:SetTextColor(.18,1,.28)
            elseif a.globalIndex==1 then border(b,.72,.54,.20); b.number:SetTextColor(.88,.69,.30)
            elseif a.globalIndex==2 then border(b,.2,.65,1); b.number:SetTextColor(.2,.65,1)
            else border(b,.38,.28,.12) end
        elseif unknown and i==1 then
            b:Show(); b.icon:SetTexture(UNKNOWN_ICON); b.clock:SetText("?"); b.number:SetText(""); b.estimate:SetText(""); border(b,.38,.28,.12)
        else b:Hide() end
    end
end

function X.Prune(now)
    if model.activeCast and now-model.activeCast.at>20 then model.activeCast=nil end
    for id,r in pairs(model.sent) do
        if now-r.at>20 then
            traceCast("DISCARD",id,r.spellID,r,"pending_timeout")
            model.sent[id]=nil
        end
    end
    for id,at in pairs(model.seen) do if now-at>20 then model.seen[id]=nil end end
    for key,t in pairs(model.targets) do if now-t.lastSeen>180 then model.targets[key]=nil end end
end

function X.Tick(now)
    X.Prune(now)
    if not CF.ExperimentalEnabled() then return end
    X.SyncOrder()
    local rows=CF.GetSuggestionRows and CF.GetSuggestionRows() or CF.GetExperimentalRows()
    local combat=call(UnitAffectingCombat,"player")==true or call(InCombatLockdown)==true
    local planRows,byKey={},{}
    for _,row in ipairs(rows) do
        local panel=row.cfExperimentalPanel
        local unit=row.cfAuraUnit or row.unit
        local key,liveUnit
        if combat and row.unit and row.offscreen and readable(row.guid) and type(row.guid)=="string" and row.guid~="" then
            -- Identity and cast estimates survive camera loss. Native aura
            -- widgets are not read back or treated as current measurements.
            key=row.guid
            local candidate=row.cfLiveUnit
            if candidate and guid(candidate)==key and call(UnitExists,candidate)==true then
                local dead=call(UnitIsDeadOrGhost,candidate)
                if dead==true then key=nil
                elseif dead==false then liveUnit=candidate end
            end
        elseif combat and row.unit and not row.cfUnavailable and call(UnitExists,unit)==true
            and call(UnitIsDeadOrGhost,unit)==false then
            key=guid(unit); liveUnit=unit
        end
        if key then
            if key and (not row.guid or row.guid==key) then
                local t=target(key,now)
                local r={key=key,order=t.order,effects={},unit=liveUnit,row=row}
                for priority,k in ipairs(cfg.order) do
                    local e=planEffect(k,priority,t,now)
                    if e then
                        r.effects[#r.effects+1]=e
                        if not e.expiresAt then r.unknown=true end
                    end
                end
                if not byKey[key] then planRows[#planRows+1]=r; byKey[key]=r
                else
                    local first=byKey[key]
                    first.duplicates=first.duplicates or {}
                    first.duplicates[#first.duplicates+1]=row
                end
            else draw(row,{},now,true) end
        elseif combat and row.unit and not row.offscreen and not row.cfUnavailable
            and call(UnitExists,unit)==true and call(UnitIsDeadOrGhost,unit)==false then
            draw(row,{},now,true)
        elseif panel then panel:Hide() end
    end
    if now-lastScan>=.5 and #planRows>0 then
        scanIndex=scanIndex%#planRows+1
        local r=planRows[scanIndex]
        if r.unit then X.Observe(r.unit,r.key,now) end
        lastScan=now
        -- Incorporate this observation before selecting this frame's actions.
        local t=model.targets[r.key]
        r.effects={}; r.unknown=nil
        for priority,k in ipairs(cfg.order) do
            local e=planEffect(k,priority,t,now)
            if e then
                r.effects[#r.effects+1]=e
                if not e.expiresAt then r.unknown=true end
            end
        end
    end
    local active=model.activeCast
    if active and active.key and active.effectKey then
        local r=byKey[active.key]
        if r then
            for _,e in ipairs(r.effects) do
                if e.key==active.effectKey then
                    e.expiresAt=math.max(now,active.endsAt)+e.duration; e.confidence="simulated"
                end
            end
        end
    end
    local start=math.max(now,model.busyUntil or 0)
    -- Delayed/pushed-back casts remain pending until a terminal event arrives.
    if active then start=math.max(start,now+.2) end
    local global=P.Plan(planRows,start,2,cfg.gcd)
    X.lastPlan=global
    for _,r in ipairs(planRows) do
        local actions=P.RowPlan(r,global,start,cfg.gcd)
        draw(r.row,actions,now,r.unknown,model.targets[r.key],active)
        for _,duplicate in ipairs(r.duplicates or {}) do
            draw(duplicate,actions,now,r.unknown,model.targets[r.key],active)
        end
    end
end

local function text(parent,s,x,y,w,h)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",x,-y); f:SetSize(w,h); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP")
    f:SetWordWrap(true); f:SetText(s); return f
end
local function button(parent,s,x,y,w,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",x,-y); b:SetSize(w,24); b:SetText(s); b:SetScript("OnClick",fn); return b
end
local function input(parent,x,y,w,limit,fn)
    local b=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    b:SetPoint("TOPLEFT",x,-y); b:SetSize(w,24); b:SetAutoFocus(false); b:SetMaxLetters(8)
    local function commit(self)
        local n=tonumber((self:GetText() or ""):gsub(",","."))
        if n and n>=0 and n<=limit then fn(n) end
        self:ClearFocus(); X.RefreshSettings()
    end
    b:SetScript("OnEnterPressed",commit)
    b:SetScript("OnEscapePressed",function(self) self:ClearFocus(); X.RefreshSettings() end)
    b:SetScript("OnEditFocusLost",function(self)
        local n=tonumber((self:GetText() or ""):gsub(",","."))
        if n and n>=0 and n<=limit then fn(n) end
    end)
    return b
end

function X.RefreshSettings()
    if not frame then return end
    X.SyncOrder()
    frame.title:SetText(T("TITLE")); frame.note:SetText(T("NOTE")); frame.legend:SetText(T("LEGEND"))
    frame.toggle:SetText(string.format(T("TOGGLE"),T(cfg.enabled and "ON" or "OFF")))
    frame.head:SetText(T("PRIORITY")); frame.duration:SetText(T("DURATION")); frame.cast:SetText(T("CAST"))
    frame.auto:SetText(T("AUTO")); frame.gcdLabel:SetText(T("GCD")); frame.gcd:SetText(tostring(cfg.gcd))
    frame.reset:SetText(T("RESET")); frame.close:SetText(T("CLOSE")); frame.saved:SetText(T("SAVED"))
    frame.sharedOrder:SetText(T("SHARED_ORDER"))
    for i,r in ipairs(frame.rows) do
        local k=cfg.order[i]; r.key=k
        r.label:SetText(tostring(i)..". "..(catalog[k] and catalog[k].name or k))
        r.enabled:SetChecked(cfg.effects[k].enabled)
        r.duration:SetText(tostring(cfg.effects[k].duration)); r.cast:SetText(tostring(cfg.effects[k].castTime))
    end
end

function CF.ShowExperimentalOptions()
    X.Init(); X.RefreshCatalog()
    if not frame then
        frame=CreateFrame("Frame","CursiveForeverExperimentalOptions",UIParent,"BackdropTemplate")
        frame:SetSize(720,460); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true); frame:SetClampedToScreen(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        CF.AuraLayoutUI.backdrop(frame,1)
        frame.title=text(frame,T("TITLE"),20,16,660,24)
        frame.title:SetFontObject("GameFontNormalLarge")
        frame.note=text(frame,T("NOTE"),20,48,680,58)
        frame.legend=text(frame,T("LEGEND"),20,110,680,38)
        frame.toggle=button(frame,"",20,158,210,CF.ToggleExperimental)
        frame.sharedOrder=button(frame,"",245,158,452,function() CF.ShowAuraLayoutOptions() end)
        frame.head=text(frame,"",50,200,290,20)
        frame.duration=text(frame,"",440,200,112,20); frame.cast=text(frame,"",568,200,130,20)
        frame.rows={}
        for i=1,3 do
            local y=224+(i-1)*36
            local r={}; frame.rows[i]=r
            r.enabled=CreateFrame("CheckButton",nil,frame,"UICheckButtonTemplate")
            r.enabled:SetSize(24,24); r.enabled:SetPoint("TOPLEFT",20,-y)
            r.enabled:SetScript("OnClick",function(self) cfg.effects[r.key].enabled=self:GetChecked() and true or false end)
            r.label=text(frame,"",50,y+4,370,24)
            r.duration=input(frame,450,y,80,120,function(n) cfg.effects[r.key].duration=n end)
            r.cast=input(frame,580,y,80,10,function(n) cfg.effects[r.key].castTime=n end)
        end
        frame.auto=text(frame,"",20,338,680,20)
        frame.gcdLabel=text(frame,"",20,372,205,24)
        frame.gcd=input(frame,237,366,58,3,function(n) if n>=.5 then cfg.gcd=n end end)
        frame.reset=button(frame,"",320,366,200,X.Reset)
        frame.close=button(frame,"",550,366,150,function() frame:Hide() end)
        frame.saved=text(frame,"",20,410,680,32)
        frame:SetScript("OnShow",function(self)
            self:SetScale(math.max(.1,math.min(1,(UIParent:GetWidth()-40)/720,(UIParent:GetHeight()-40)/460)))
        end)
        table.insert(UISpecialFrames,"CursiveForeverExperimentalOptions")
        CF.RegisterLocaleUpdater(X.RefreshSettings)
    end
    X.RefreshSettings(); frame:Show(); frame:Raise()
end

function CF.ConfigureExperimentalToggle(b)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    b:SetScript("OnClick",function(_,mouse)
        if mouse=="RightButton" then CF.ShowExperimentalOptions() else CF.ToggleExperimental() end
    end)
    b.CFLocaleRefresh=function() b.cfLabel:SetText(string.format(T("TOGGLE"),T(CF.ExperimentalEnabled() and "ON" or "OFF"))) end
    X.RefreshToggle=b.CFLocaleRefresh
    CF.RegisterLocaleUpdater(b.CFLocaleRefresh); b.CFLocaleRefresh()
end

SLASH_CURSIVEEXPERIMENTAL1="/cfexp"
SlashCmdList.CURSIVEEXPERIMENTAL=function(msg)
    X.Init(); X.RefreshCatalog()
    local cmd,arg=(msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd=="on" or cmd=="off" then
        if cfg.enabled~=(cmd=="on") then CF.ToggleExperimental() end
    elseif cmd=="reset" then X.Reset()
    elseif cmd=="miss" then
        local key=guid("target")
        local aliases={feuerbrand="immolate",verderbnis="corruption",omen="agony"}
        local k=aliases[arg] or arg
        if k=="" then k=key and model.targets[key] and model.targets[key].lastEffect end
        Print(T(X.MarkDue(key,k) and "CORRECTED" or "NO_TARGET"))
    elseif cmd=="help" then Print(T("HELP"))
    else CF.ShowExperimentalOptions() end
end

local event=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","SPELLS_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_FAILED_QUIET","UNIT_SPELLCAST_INTERRUPTED"}) do event:RegisterEvent(e) end
event:SetScript("OnEvent",function(_,e,unit,castOrTarget,spellOrCast,spellID)
    if e=="PLAYER_LOGIN" then X.Init(); X.RefreshCatalog(); return end
    if e=="PLAYER_ENTERING_WORLD" then X.Reset(); return end
    if e=="SPELLS_CHANGED" then X.RefreshCatalog(); return end
    if e=="PLAYER_REGEN_DISABLED" then X.CombatChanged(true); return end
    if e=="PLAYER_REGEN_ENABLED" then X.CombatChanged(false); return end
    if not readable(unit) or unit~="player" then return end
    local now=GetTime()
    if e=="UNIT_SPELLCAST_SENT" then X.Sent(castOrTarget,spellOrCast,spellID,now)
    elseif e=="UNIT_SPELLCAST_SUCCEEDED" then X.Succeeded(castOrTarget,spellOrCast,now)
    else X.Failed(castOrTarget,e,spellOrCast) end
end)
local elapsed=0
event:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed>=.2 then elapsed=0; X.Tick(GetTime()) end
end)
