local _, addon = ...
local CF = addon and addon.CF
if not CF then return end

-- This presentation changes geometry only. Aura assignment, duration bars and
-- countdowns remain native-owned; no timer or aura state is read back here.
local BAR_HEIGHT, BAR_STEP, BAR_TOP, AURA_X = 16, 18, 4, 148
local HEALTH_X, HEALTH_Y, HEALTH_WIDTH, HEALTH_HEIGHT = 5, 60, 104, 16
local curves = {}

local function slotKeys()
    return CF.GetAuraSlotKeys and CF.GetAuraSlotKeys() or {}
end

function CF.IsBarsView()
    return CursiveForeverDB and CursiveForeverDB.trackerView == "bars"
        and #slotKeys() > 0 and not CF.auraSlotsUnavailable
        and (not CF.barsViewUnavailable or CF.barsFallbackDeferred) or false
end

function CF.GetBarsShowSpellNames()
    return not CursiveForeverDB or CursiveForeverDB.barsShowSpellNames ~= false
end

function CF.SetBarsShowSpellNames(value)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not CursiveForeverDB then return end
    CursiveForeverDB.barsShowSpellNames = value ~= false
    if CF.ApplyAuraLayoutToAllRows then CF.ApplyAuraLayoutToAllRows() end
    if CF.RefreshTrackerViewControl then CF.RefreshTrackerViewControl() end
end

local function auraX() return CF.AreTrackerExtrasEnabled() and AURA_X or 118 end
local function baseSlotsWidth() return CF.GetBarsShowSpellNames() and 210 or 110 end
local function baseRowWidth()
    local preview = CF.ExperimentalWidth and CF.ExperimentalWidth() or 0
    return auraX()+baseSlotsWidth()+16+preview
end
local function baseRowHeight()
    return math.max(96,BAR_TOP+math.max(BAR_HEIGHT,#slotKeys()*BAR_STEP-2)+6)
end
local function heightDelta() return CF.GetBarsRowHeight()-baseRowHeight() end
local function paneOffset() return math.max(0,heightDelta()/2) end
local function barStep()
    local count = #slotKeys()
    if count <= 1 then return BAR_STEP end
    local delta = heightDelta()
    return BAR_STEP+delta/(count-1)*(delta > 0 and .5 or 1)
end
function CF.GetBarsTop() return BAR_TOP+math.max(0,heightDelta()/4) end
function CF.GetBarsIconCenter()
    return (CF.ExperimentalEnabled and CF.ExperimentalEnabled() and 31 or 23)+paneOffset()
end
function CF.GetBarsAuraX() return auraX() end
function CF.GetBarsSlotPosition(index) return 0, (index-1)*barStep() end
function CF.GetBarsSlotsWidth()
    return baseSlotsWidth()+CF.GetBarsRowWidth()-baseRowWidth()
end
function CF.GetBarsSlotsHeight(count)
    return math.max(BAR_HEIGHT,((count or #slotKeys())-1)*barStep()+BAR_HEIGHT)
end
function CF.GetBarsRowHeight()
    -- Six units keep the final bar clear of the row border. The left pane
    -- remains tall enough for its portrait, health, curse, extras and Execute.
    local base = baseRowHeight()
    local minimum = math.max(96,BAR_TOP+math.max(BAR_HEIGHT,(#slotKeys()-1)*17+BAR_HEIGHT)+6)
    return CF.ResolveTrackerHeight and CF.ResolveTrackerHeight(base,minimum,"bars") or base
end
function CF.GetBarsRowWidth()
    local base = baseRowWidth()
    local minimumBar = CF.GetBarsShowSpellNames() and 140 or 70
    return CF.ResolveTrackerWidth and CF.ResolveTrackerWidth(base,base-baseSlotsWidth()+minimumBar,"bars") or base
end
-- Leave room for a full native "1 min" countdown below each small icon,
-- including the formatter fallback, rather than measuring protected text.
function CF.GetBarsExtraSize() return 64,50 end
function CF.GetBarsExtraPosition() return 83,6+paneOffset() end

function CF.InitBarsAuraButton(button, formatter)
    -- Called only by initializeFrame. Neither the button nor its descendants
    -- may be accessed after initialization. The caller anchors this button to
    -- an ordinary addon-owned slot, so resizing that slot remains safe.
    if type(button.SetDurationBar) ~= "function" or not Enum
        or not Enum.StatusBarTimerDirection
        or Enum.StatusBarTimerDirection.RemainingTime == nil then
        error("Native remaining-duration bars unavailable")
    end
    button:SetSize(CF.GetBarsSlotsWidth(),BAR_HEIGHT)
    local icon = button:CreateTexture(nil,"ARTWORK")
    icon:SetPoint("TOPLEFT",button,"TOPLEFT",0,0)
    icon:SetSize(BAR_HEIGHT,BAR_HEIGHT)
    icon:SetTexCoord(.08,.92,.08,.92)
    icon:SetVertexColor(1,1,1,1)
    button:SetIcon(icon)

    local background = button:CreateTexture(nil,"BACKGROUND")
    background:SetPoint("TOPLEFT",button,"TOPLEFT",18,0)
    background:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",0,0)
    background:SetColorTexture(.035,.045,.04,.92)

    local bar = CreateFrame("StatusBar",nil,button)
    bar:SetPoint("TOPLEFT",button,"TOPLEFT",18,0)
    bar:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",0,0)
    bar:SetOrientation("HORIZONTAL")
    if bar.SetReverseFill then bar:SetReverseFill(false) end
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(.26,.52,.39,.86)
    local options = { direction=Enum.StatusBarTimerDirection.RemainingTime }
    if Enum.StatusBarInterpolation then options.interpolation=Enum.StatusBarInterpolation.Immediate end
    -- Let a missing/rejected native capability abort the new cache atomically.
    -- A silent substitute would look like a supported bar without a timer.
    button:SetDurationBar(bar,options)

    local ink = CreateFrame("Frame",nil,button)
    ink:SetAllPoints(button)
    ink:SetFrameLevel(bar:GetFrameLevel()+1)
    ink:EnableMouse(false)
    local duration = ink:CreateFontString(nil,"OVERLAY","GameFontNormal")
    duration:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    duration:SetPoint("RIGHT",button,"RIGHT",-4,0)
    duration:SetSize(36,BAR_HEIGHT)
    duration:SetJustifyH("RIGHT")
    duration:SetWordWrap(false)
    duration:SetTextColor(1,.93,.58,1)
    if formatter then button:SetDurationText(duration,(CF.Client and CF.Client.DurationTextOptions
        and CF.Client.DurationTextOptions(formatter)) or {textFormatter=formatter})
    else button:SetDurationText(duration) end
end

local function readable(value)
    local guarded = false
    if type(issecretvalue) == "function" then
        guarded = true
        local ok, secret = pcall(issecretvalue,value)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        guarded = true
        local ok, access = pcall(canaccessvalue,value)
        if not ok or not access then return false end
    end
    return guarded
end

local function healthOverlay(row)
    if row.cfBarsHealthOverlay then return row.cfBarsHealthOverlay end
    local overlay = CreateFrame("Frame",nil,row)
    overlay:SetAllPoints(row)
    overlay:SetFrameLevel(row:GetFrameLevel()+5)
    overlay:EnableMouse(false)
    for _,side in ipairs({"left","right"}) do
        local ink = CreateFrame("Frame",nil,overlay)
        ink:SetPoint("TOPLEFT",row,"TOPLEFT",HEALTH_X,-HEALTH_Y-paneOffset())
        ink:SetSize(HEALTH_WIDTH,HEALTH_HEIGHT)
        ink:EnableMouse(false)
        local text = ink:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
        text:SetPoint("TOPLEFT",ink,"TOPLEFT",3,0)
        text:SetPoint("BOTTOMRIGHT",ink,"BOTTOMRIGHT",-3,0)
        text:SetJustifyH(side == "left" and "LEFT" or "RIGHT")
        text:SetWordWrap(false)
        text:SetTextColor(1,1,1,1)
        ink.text = text
        ink:SetAlpha(0)
        ink:Hide()
        overlay[side] = ink
    end
    row.cfBarsHealthOverlay = overlay
    return overlay
end

local function curveFor(side)
    if curves[side] then return curves[side] end
    if not C_CurveUtil or type(C_CurveUtil.CreateColorCurve) ~= "function"
        or not Enum or not Enum.LuaCurveType or Enum.LuaCurveType.Step == nil
        or type(CreateColor) ~= "function" then return nil end
    local ok, curve = pcall(function()
        local result = C_CurveUtil.CreateColorCurve()
        result:SetType(Enum.LuaCurveType.Step)
        result:AddPoint(0,CreateColor(1,1,1,side == "right" and 1 or 0))
        -- Exactly 70% belongs on the filled left side; below 70% uses the
        -- empty right side. Both complementary masks are evaluated natively.
        result:AddPoint(.70,CreateColor(1,1,1,side == "left" and 1 or 0))
        return result
    end)
    if ok then curves[side]=curve; return curve end
end

function CF.ClearBarsHealth(row)
    if not row then return end
    row.cfBarsHealthMasksReady = nil
    local overlay = row.cfBarsHealthOverlay
    if not overlay then return end
    for _,side in ipairs({"left","right"}) do
        overlay[side]:SetAlpha(0)
        overlay[side].text:SetText("")
        overlay[side]:Hide()
    end
end

function CF.UpdateBarsHealth(row,unit)
    if not row or not CF.IsBarsView() then return end
    if row.healthDisplayEmpty or not row.healthValueAvailable then CF.ClearBarsHealth(row); return end
    local overlay = healthOverlay(row)
    row.cfBarsHealthMasksReady = nil
    local leftCurve, rightCurve = curveFor("left"), curveFor("right")
    if unit and leftCurve and rightCurve and type(UnitHealthPercent) == "function" then
        local ok = pcall(function()
            -- Match the percentage source used by UpdateRowHealth.
            local left = UnitHealthPercent(unit,true,leftCurve)
            local right = UnitHealthPercent(unit,true,rightCurve)
            -- Secret alpha channels go straight to native frame rendering.
            -- Do not compare, retain, stringify or read back these channels.
            overlay.left:SetAlpha(select(4,left:GetRGBA()))
            overlay.right:SetAlpha(select(4,right:GetRGBA()))
        end)
        if ok then row.cfBarsHealthMasksReady=true; return end
    end
    -- A public percentage can drive the same layout without curves. Secret
    -- values remain display-only and use the centered fallback instead.
    local value = row.healthValue
    if readable(value) and type(value) == "number" and value == value and value >= 0 and value <= 100 then
        overlay.left:SetAlpha(value >= 70 and 1 or 0)
        overlay.right:SetAlpha(value < 70 and 1 or 0)
        row.cfBarsHealthMasksReady = true
        return
    end
    overlay.left:SetAlpha(0)
    overlay.right:SetAlpha(0)
end

function CF.LayoutBarsHealth(row,barShown)
    if not row or not CF.IsBarsView() then return end
    local overlay = healthOverlay(row)
    row.cfBarsOwnStyle = true
    overlay:Show()
    for _,side in ipairs({"left","right"}) do
        overlay[side]:ClearAllPoints()
        overlay[side]:SetPoint("TOPLEFT",row,"TOPLEFT",HEALTH_X,-HEALTH_Y-paneOffset())
    end
    row.healthAbs:SetParent(overlay)
    row.healthPct:SetParent(overlay)
    row.healthAbs:ClearAllPoints()
    row.healthAbs:SetPoint("TOPLEFT",row,"TOPLEFT",5,-42-paneOffset())
    row.healthAbs:SetSize(70,14)
    row.healthAbs:SetJustifyH("CENTER")
    row.healthPct:ClearAllPoints()
    row.healthPct:SetPoint("TOPLEFT",row,"TOPLEFT",HEALTH_X,-HEALTH_Y-paneOffset())
    row.healthPct:SetSize(HEALTH_WIDTH,HEALTH_HEIGHT)
    row.healthPct:SetJustifyH("CENTER")
    if row.healthBar then
        row.healthBar:ClearAllPoints()
        row.healthBar:SetPoint("TOPLEFT",row,"TOPLEFT",HEALTH_X,-HEALTH_Y-paneOffset())
        row.healthBar:SetSize(HEALTH_WIDTH,HEALTH_HEIGHT)
    end
    if barShown ~= nil then row.cfBarsBarShown=barShown
    elseif row.cfBarsBarShown ~= nil then barShown=row.cfBarsBarShown
    else barShown=row.healthBarValueAvailable end

    local formatted = row.healthValueAvailable and pcall(function()
        overlay.left.text:SetFormattedText("%.0f%%",row.healthValue)
        overlay.right.text:SetFormattedText("%.0f%%",row.healthValue)
    end)
    if barShown and formatted then
        row.healthPct:Hide()
        if row.cfBarsHealthMasksReady then
            overlay.left.text:SetJustifyH("LEFT")
        else
            -- Neutral alignment still needs contrast over the health fill.
            -- Use white overlay text rather than the stock health-colored text.
            overlay.left.text:SetJustifyH("CENTER")
            overlay.left:SetAlpha(1)
            overlay.right:SetAlpha(0)
        end
        overlay.left:Show()
        overlay.right:Show()
    else
        overlay.left:Hide()
        overlay.right:Hide()
        row.healthPct:Show()
        if row.healthValueAvailable then
            local ok = pcall(row.healthPct.SetFormattedText,row.healthPct,"%.0f%%",row.healthValue)
            if not ok then row.healthPct:SetText(row.healthDisplayEmpty and "" or "?%") end
        elseif barShown then row.healthPct:SetText(row.healthDisplayEmpty and "" or "?") end
    end
end

function CF.RestoreBarsRowStyle(row)
    if not row or not row.cfBarsOwnStyle or CF.IsBarsView() then return end
    CF.ClearBarsHealth(row)
    local mode = CursiveForeverDB and CursiveForeverDB.targetDisplayMode
    local width = mode == "standard" and 82 or mode == "compact" and 72 or 70
    row.healthAbs:SetParent(row)
    row.healthPct:SetParent(row)
    row.healthAbs:SetWidth(width)
    row.healthPct:SetWidth(width)
    row.healthAbs:SetHeight(0)
    row.healthPct:SetHeight(0)
    row.healthPct:SetJustifyH("CENTER")
    if row.healthBar then row.healthBar:SetSize(width-2,10) end
    if row.cfBarsHealthOverlay then row.cfBarsHealthOverlay:Hide() end
    row.raidMarker:SetSize(20,20)
    row.healthDivider:SetSize(1,28)
    if row.cfExecute then
        row.cfExecute.icon:ClearAllPoints()
        row.cfExecute.icon:SetPoint("CENTER",row.cfExecute,"CENTER",-25,0)
        row.cfExecute.label:Show()
    end
    row.cfBarsOwnStyle = nil
    row.cfBarsBarShown = nil
end

function CF.LayoutBarsRow(row)
    if not row then return end
    if not CF.IsBarsView() then CF.RestoreBarsRowStyle(row); return end
    if CF.RestoreMatrixRowStyle then CF.RestoreMatrixRowStyle(row) end
    row.cfBarsOwnStyle = true
    row:SetHeight(CF.GetBarsRowHeight()-2)
    row.name:Hide()
    row.targetLabel:Hide()
    row.portraitRing:ClearAllPoints()
    row.portraitRing:SetPoint("TOPLEFT",row,"TOPLEFT",5,-6-paneOffset())
    row.portraitRing:SetSize(34,34)
    row.portraitRing:Show()
    row.portrait:SetSize(30,30)
    row.portrait:Show()
    row.raidMarker:ClearAllPoints()
    row.raidMarker:SetPoint("TOPLEFT",row.portraitRing,"TOPLEFT",-2,2)
    row.raidMarker:SetSize(14,14)
    row.healthDivider:ClearAllPoints()
    row.healthDivider:SetPoint("TOPLEFT",row,"TOPLEFT",auraX()-5,-4)
    row.healthDivider:SetSize(1,CF.GetBarsRowHeight()-10)
    local state = row.cfAuraLayout
    if state and state.support then
        state.support:ClearAllPoints()
        state.support:SetPoint("TOPLEFT",row,"TOPLEFT",48,-6-paneOffset())
    end
    if state and state.others then
        state.others:ClearAllPoints()
        local x, y = CF.GetBarsExtraPosition()
        state.others:SetPoint("TOPLEFT",row,"TOPLEFT",x,-y)
    end
    CF.LayoutBarsHealth(row)
    if row.cfExecute then
        row.cfExecute:ClearAllPoints()
        row.cfExecute:SetPoint("TOPLEFT",row,"TOPLEFT",5,-78-paneOffset())
        row.cfExecute:SetSize(HEALTH_WIDTH,14)
        row.cfExecute.icon:ClearAllPoints()
        row.cfExecute.icon:SetPoint("CENTER",row.cfExecute,"CENTER",-25,0)
        row.cfExecute.label:Show()
    end
end
