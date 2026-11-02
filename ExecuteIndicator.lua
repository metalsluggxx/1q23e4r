local _, addon = ...
local CF = addon.CF
local E = { curves = {}, registrations = {} }
CF.ExecuteIndicator = E

-- Display only. No health result, color or native-widget state is fed into
-- target retention, death detection, the planner or performance recording.
-- Forever 70374: C_SpellBook.IsSpellKnown includes known passive spells;
-- IsSpellInSpellBook is deliberately NOT used (it can include unknown spells).
local profiles = {
    WARLOCK = { threshold=35, spells={440870,440923}, name="Decimation" },
    ROGUE = { threshold=35, spells={1310728}, name="Quietus" },
    WARRIOR = { threshold=20, inclusive=true, spells={5308,20658,20660,20661,20662}, name="Execute" },
    PALADIN = { threshold=20, inclusive=true, spells={24275,24274,24239}, name="Hammer of Wrath" },
    PRIEST = { threshold=20, inclusive=true, spells={1310076},
        requires={1309595,1309633,1309635,1309636}, name="Early Demise" },
}
profiles = (CF.Client and CF.Client.executeProfiles) or profiles
local modes = { "auto", "35", "20", "off" }
local keys = { auto="EXECUTE_AUTO", ["35"]="EXECUTE_35", ["20"]="EXECUTE_20", off="EXECUTE_OFF" }
local translations = {
    de = {
        EXECUTE_TITLE="Execute-Hinweis", EXECUTE_FMT="Execute: %s",
        EXECUTE_AUTO="Automatisch", EXECUTE_35="Unter 35 %", EXECUTE_20="Unter 20 %", EXECUTE_OFF="Aus",
        EXECUTE_TIP="Klicken: Automatisch → Unter 35 % → Unter 20 % → Aus. Automatisch berücksichtigt tatsächlich erlernte Fähigkeiten und Talente. Die festen Schwellen gelten für jede Klasse, etwa für Raidansagen. Der Hinweis zeigt den Gesundheitsbereich; er bestätigt keinen aktiven Proc und keine sofortige Zauberbereitschaft. Abgeblendet: zuletzt bekannter Stand ohne aktuelle Gesundheitsabfrage.",
        SHOW_HEADER="Fensterkopf anzeigen",
        SHOW_HEADER_TIP="Blendet die Titelzeile der Gegnerübersicht ein oder aus und passt die Fensterhöhe an. Ohne Kopf lässt sich das entsperrte Fenster am freien Hintergrund ziehen. Ein wichtiger Hinweis zu ausgeschalteten Gegnernamensplaketten bleibt sichtbar.",
        CONTACT_OPEN="Rückmeldung auf CurseForge",
        CONTACT_TITLE="Kontakt & Rückmeldung",
        CONTACT_NOTE="Erstellt von Leandarh Valinor · Try Again Forever\n\nFragen, Fehler und Vorschläge bitte in den Kommentaren auf CurseForge. Link zum Kopieren:",
        CONTACT_COPY="Strg+C kopiert den markierten Link. Esc schließt dieses Fenster.",
        RAID_MANY_SHORT="Bis zu 40 Gegner; ab Gegner 21 erscheint eine zweite Spalte. Gegnernamensplaketten müssen eingeschaltet sein.",
    },
    en = {
        EXECUTE_TITLE="Execute hint", EXECUTE_FMT="Execute: %s",
        EXECUTE_AUTO="Automatic", EXECUTE_35="Below 35%", EXECUTE_20="Below 20%", EXECUTE_OFF="Off",
        EXECUTE_TIP="Click: Automatic → Below 35% → Below 20% → Off. Automatic checks actually learned abilities and talents. Fixed thresholds work for any class, for example for raid calls. The hint indicates the health range; it does not confirm an active proc or immediate spell readiness. Dimmed: last known state without a current health observation.",
        SHOW_HEADER="Show window header",
        SHOW_HEADER_TIP="Shows or hides the enemy tracker's title bar and adjusts its height. With the header hidden, drag an unlocked window by its empty background. An important warning about disabled enemy nameplates remains visible.",
        CONTACT_OPEN="Feedback on CurseForge",
        CONTACT_TITLE="Contact & feedback",
        CONTACT_NOTE="Created by Leandarh Valinor · Try Again Forever\n\nPlease post questions, bugs and suggestions in the CurseForge comments. Copy this link:",
        CONTACT_COPY="Ctrl+C copies the selected link. Esc closes this window.",
        RAID_MANY_SHORT="Up to 40 enemies; a second column opens at enemy 21. Enemy nameplates must be enabled.",
    },
}
for key, value in pairs(translations.de) do CF.L_DE[key] = value end
for key, value in pairs(translations.en) do CF.L_EN[key] = value end

local function readable(value)
    local guarded = false
    if type(issecretvalue) == "function" then
        guarded = true
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        guarded = true
        local ok, access = pcall(canaccessvalue, value)
        if not ok or not access then return false end
    end
    return guarded
end

local function known(ids)
    local api = C_SpellBook and C_SpellBook.IsSpellKnown
    if type(api) ~= "function" then api = IsPlayerSpell or IsSpellKnown end
    if type(api) ~= "function" then return false end
    for _, id in ipairs(ids) do
        local ok, value = pcall(api, id)
        if ok and readable(value) and value == true then return true end
    end
    return false
end

function CF.GetExecuteMode()
    local mode = CursiveForeverDB and CursiveForeverDB.executeMode
    return keys[mode] and mode or "auto"
end

function CF.GetExecuteModeLabel()
    return CF.T(keys[CF.GetExecuteMode()])
end

function E.Resolve()
    local mode = CF.GetExecuteMode()
    if mode == "off" then return nil end
    if mode == "35" or mode == "20" then return tonumber(mode), false end
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or not readable(class) or type(class) ~= "string" then return nil end
    local profile = profiles[class]
    if not profile or not known(profile.spells) then return nil end
    if profile.requires and not known(profile.requires) then return nil end
    return profile.threshold, profile.inclusive == true
end

local function ensure(row)
    if row.cfExecute then return row.cfExecute end
    local frame = CreateFrame("Frame", nil, row)
    frame:SetSize(70,14); frame:EnableMouse(false)
    local ink = CreateFrame("Frame", nil, frame)
    ink:SetAllPoints(frame); ink:EnableMouse(false)
    local icon = ink:CreateTexture(nil,"OVERLAY")
    icon:SetTexture("Interface\\AddOns\\CursiveForever\\Media\\ExecuteSwords.tga")
    icon:SetSize(13,13); icon:SetPoint("CENTER",frame,"CENTER",-25,0)
    icon:SetVertexColor(1,0.72,0.18,1)
    local text = ink:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    text:SetPoint("LEFT",frame,"CENTER",-16,0); text:SetSize(49,14)
    text:SetJustifyH("LEFT"); text:SetWordWrap(false)
    text:SetText("Execute!"); text:SetTextColor(1,0.72,0.18,1)
    frame.ink, frame.icon, frame.label = ink, icon, text
    ink:SetAlpha(0); frame:Hide()
    row.cfExecute = frame
    return frame
end

function CF.LayoutExecuteIndicator(row, healthX, healthWidth)
    -- Anchors use only addon-owned constants, never native health geometry.
    local ok = pcall(function()
        local frame = ensure(row)
        frame:ClearAllPoints()
        local iconCenter = CF.GetAuraLayoutIconCenter and CF.GetAuraLayoutIconCenter() or 35
        local portraitOffset = CF.GetAuraLayoutPortraitOffset and CF.GetAuraLayoutPortraitOffset() or 0
        frame:SetPoint("TOPLEFT",row,"TOPLEFT",healthX+portraitOffset,-iconCenter-18)
        frame:SetSize(healthWidth,14)
    end)
    if not ok then E.lastError = "layout" end
end

function CF.ClearExecuteIndicator(row)
    if row and row.cfExecute then
        row.cfExecute:Hide()
        pcall(row.cfExecute.ink.SetAlpha,row.cfExecute.ink,0)
        row.cfExecute:SetAlpha(1)
    end
end

function CF.ApplyExecuteAvailability(row)
    if row and row.cfExecute then
        row.cfExecute:SetAlpha(row.cfUnavailable and 0.30 or 1)
    end
end

local function curveFor(threshold, inclusive)
    local key = tostring(threshold)..(inclusive and ":inclusive" or ":strict")
    if E.curves[key] then return E.curves[key] end
    if not C_CurveUtil or type(C_CurveUtil.CreateColorCurve) ~= "function"
        or not Enum or not Enum.LuaCurveType or Enum.LuaCurveType.Step == nil
        or type(CreateColor) ~= "function" then return nil end
    local ok, curve = pcall(function()
        local value = C_CurveUtil.CreateColorCurve()
        value:SetType(Enum.LuaCurveType.Step)
        value:AddPoint(0,CreateColor(1,1,1,1))
        -- The next native float after 0.2 preserves the inclusive 20% boundary
        -- of Execute / Hammer of Wrath / Early Demise in the display curve.
        local stop = inclusive and threshold == 20 and 0.20000001788139343 or threshold/100
        value:AddPoint(stop,CreateColor(1,1,1,0))
        return value
    end)
    if ok then E.curves[key] = curve; return curve end
end

function CF.UpdateExecuteIndicator(row, unit)
    if not row or not E.threshold then CF.ClearExecuteIndicator(row); return end
    local ok = pcall(function()
        local frame = ensure(row)
        local curve = curveFor(E.threshold,E.inclusive)
        if curve then
            local color = UnitHealthPercent(unit,false,curve)
            -- The result may contain secret channels. Pass its alpha straight
            -- to the native renderer; never inspect, compare or save it.
            frame.ink:SetAlpha(select(4,color:GetRGBA()))
        else
            -- Fail closed unless the unscaled health fraction is public.
            local fraction = UnitHealthPercent(unit,false)
            if not readable(fraction) or type(fraction) ~= "number"
                or fraction ~= fraction or fraction < 0 or fraction > 1 then error("unavailable") end
            local active = fraction > 0 and (fraction < E.threshold/100
                or (E.inclusive and fraction == E.threshold/100))
            frame.ink:SetAlpha(active and 1 or 0)
        end
        CF.ApplyExecuteAvailability(row)
        frame:Show()
    end)
    if not ok then E.lastError = "health_display"; CF.ClearExecuteIndicator(row) end
end

local function matches(row,unit)
    local ok, exists = pcall(UnitExists,unit)
    if not ok or not readable(exists) or exists ~= true then return false end
    if row.guid then
        local good, guid = pcall(UnitGUID,unit)
        return good and readable(guid) and readable(row.guid) and guid == row.guid
    end
    return not row.offscreen and unit == row.unit
end

function E.Refresh()
    E.threshold, E.inclusive = E.Resolve()
    for _,row in ipairs(CF.GetExperimentalRows()) do
        CF.ClearExecuteIndicator(row)
        local unit = row.cfLiveUnit or (not row.offscreen and row.unit)
        if unit and not row.cfUnavailable and matches(row,unit) then CF.UpdateExecuteIndicator(row,unit) end
    end
end

function CF.SetExecuteMode(mode)
    if not CursiveForeverDB then return end
    CursiveForeverDB.executeMode = keys[mode] and mode or "auto"
    E.Refresh()
end

function CF.CycleExecuteMode()
    local mode = CF.GetExecuteMode()
    for i,value in ipairs(modes) do
        if value == mode then CF.SetExecuteMode(modes[i % #modes + 1]); return end
    end
end

local frame = CreateFrame("Frame")
E.frame = frame
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","SPELLS_CHANGED",
    "PLAYER_TALENT_UPDATE","TRAIT_CONFIG_UPDATED","ACTIVE_TALENT_GROUP_CHANGED"}) do
    E.registrations[event] = pcall(frame.RegisterEvent,frame,event)
end
frame:SetScript("OnEvent",function() E.Refresh() end)

function CF.ShowContactInfo()
    local f = CF.contactFrame
    if not f then
        f = CreateFrame("Frame","CursiveForeverContactFrame",UIParent,"BackdropTemplate")
        CF.contactFrame = f
        f:SetSize(520,196); f:SetPoint("CENTER"); f:EnableMouse(true)
        f:SetClampedToScreen(true); CF.AuraLayoutUI.backdrop(f,0.98)
        CF.AuraLayoutUI.close(f)
        f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT",16,-14)
        f.note=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.note:SetPoint("TOPLEFT",16,-44); f.note:SetSize(488,70); f.note:SetJustifyH("LEFT"); f.note:SetJustifyV("TOP")
        f.link=CreateFrame("EditBox",nil,f,"InputBoxTemplate")
        f.link:SetSize(476,24); f.link:SetPoint("TOPLEFT",22,-123); f.link:SetAutoFocus(false)
        f.link:SetScript("OnEscapePressed",function() f:Hide() end)
        f:SetScript("OnHide",function() f.link:ClearFocus() end)
        f.hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.hint:SetPoint("TOPLEFT",16,-163); f.hint:SetWidth(488)
        table.insert(UISpecialFrames,"CursiveForeverContactFrame")
    end
    f.title:SetText(CF.T("CONTACT_TITLE")); f.note:SetText(CF.T("CONTACT_NOTE")); f.hint:SetText(CF.T("CONTACT_COPY"))
    f.link:SetText("https://www.curseforge.com/wow/addons/cursive-forever/comments")
    -- Grimoire controls use higher levels within DIALOG. Keep the complete
    -- contact dialog above that stratum, including on subsequent opens.
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:Show(); f:Raise(); f.link:SetFocus(); f.link:HighlightText()
end
