local _, addon = ...
local CF = addon and addon.CF
if not CF then return end

-- A fourth presentation of the existing tracked rows. AuraLayout supplies
-- native fixed slots or an expiration-sorted group in the same icon band;
-- only ordinary addon-owned anchors and the health StatusBar are laid out here.
local ICON_SIZE, ICON_STEP = 34, 38
local HEALTH_X, HEALTH_WIDTH, HEALTH_HEIGHT = 44, 244, 34
local MAIN_X, SUPPORT_SPACE = 300, 32
local EXTRA_GAP, EXTRA_WIDTH = 8, 40

local function slotKeys()
    return CF.GetAuraSlotKeys and CF.GetAuraSlotKeys() or {}
end

local function previewEnabled()
    return CF.ExperimentalEnabled and CF.ExperimentalEnabled() or false
end

local function hasSupport()
    return CF.ShouldShowUtilityCurse()
end

function CF.IsHealthbarView()
    return CursiveForeverDB and CursiveForeverDB.trackerView == "healthbar"
        and #slotKeys() > 0 and not CF.auraSlotsUnavailable or false
end

local function baseRowHeight() return previewEnabled() and 70 or 58 end
local function rowPadding() return (CF.GetHealthbarRowHeight()-baseRowHeight())/2 end
local function baseRowWidth()
    local preview = CF.ExperimentalWidth and CF.ExperimentalWidth() or 0
    return MAIN_X+(hasSupport() and SUPPORT_SPACE or 0)+CF.GetHealthbarSlotsWidth()+(CF.AreTrackerExtrasEnabled() and EXTRA_GAP+EXTRA_WIDTH or 0)+16+preview
end
function CF.GetHealthbarHealthWidth()
    return HEALTH_WIDTH+CF.GetHealthbarRowWidth()-baseRowWidth()
end
function CF.GetHealthbarHealthHeight()
    local _,height=1,1
    if CF.GetTrackerSizing then _,height=CF.GetTrackerSizing("healthbar") end
    -- Two lines of health text need 28 units plus a clear edge. Row height
    -- separately reserves enough room for the unchanged icons and countdowns.
    return math.max(30,math.floor(HEALTH_HEIGHT*height+.5))
end
function CF.GetHealthbarTop() return (previewEnabled() and 14 or 4)+rowPadding() end
function CF.GetHealthbarIconCenter() return CF.GetHealthbarTop()+ICON_SIZE/2 end
function CF.GetHealthbarRowHeight()
    local base = baseRowHeight()
    return CF.ResolveTrackerHeight and CF.ResolveTrackerHeight(base,base,"healthbar") or base
end
function CF.GetHealthbarAuraX()
    return MAIN_X+(hasSupport() and SUPPORT_SPACE or 0)+CF.GetHealthbarHealthWidth()-HEALTH_WIDTH
end
function CF.GetHealthbarSlotPosition(index) return (index-1)*ICON_STEP,0 end
function CF.GetHealthbarSlotsWidth(count)
    return math.max(ICON_SIZE,((count or #slotKeys())-1)*ICON_STEP+ICON_SIZE)
end
function CF.GetHealthbarRowWidth()
    local base = baseRowWidth()
    return CF.ResolveTrackerWidth and CF.ResolveTrackerWidth(base,base-HEALTH_WIDTH+180,"healthbar") or base
end

local function healthCenter()
    return CF.GetHealthbarIconCenter()+6
end

local function overlayFor(row)
    if row.cfHealthbarHealthOverlay then return row.cfHealthbarHealthOverlay end
    -- Text is above the native StatusBar's fill and border. Its frame never
    -- derives geometry from a secret health value or an aura-owned widget.
    local overlay = CreateFrame("Frame",nil,row)
    overlay:SetAllPoints(row)
    overlay:SetFrameLevel(row:GetFrameLevel()+5)
    overlay:EnableMouse(false)
    overlay.shade = overlay:CreateTexture(nil,"BACKGROUND")
    overlay.shade:SetColorTexture(0,0,0,.48)
    for _,key in ipairs({"amount","percent"}) do
        local text = overlay:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
        text:SetJustifyH("RIGHT")
        text:SetWordWrap(false)
        text:SetTextColor(1,1,1,1)
        text:SetText("")
        overlay[key] = text
    end
    row.cfHealthbarHealthOverlay = overlay
    return overlay
end

function CF.ClearHealthbarHealth(row)
    if not row then return end
    row.cfHealthbarBarShown = nil
    local overlay = row.cfHealthbarHealthOverlay
    if not overlay then return end
    overlay.amount:SetText("")
    overlay.percent:SetText("")
end

local function renderAmount(row,text)
    if not row.healthBarValueAvailable then return false end
    -- AbbreviateNumbers and the FontString setters accept display-only secret
    -- values. Never concatenate, compare or perform arithmetic on the result.
    if type(AbbreviateNumbers) == "function" then
        local currentOK,current = pcall(AbbreviateNumbers,row.healthBarValue)
        local maximumOK,maximum = pcall(AbbreviateNumbers,row.healthBarMaximum)
        if currentOK and maximumOK
            and pcall(text.SetFormattedText,text,"%s / %s",current,maximum) then
            return true
        end
    end
    return pcall(text.SetFormattedText,text,"%d / %d",row.healthBarValue,row.healthBarMaximum)
end

function CF.LayoutHealthbarHealth(row,barShown)
    if not row or not CF.IsHealthbarView() then return end
    local overlay = overlayFor(row)
    local center = healthCenter()
    local height = CF.GetHealthbarHealthHeight()
    local top = center-height/2
    local textTop = center-14
    local width = CF.GetHealthbarHealthWidth()
    row.cfHealthbarOwnStyle = true
    if barShown ~= nil then row.cfHealthbarBarShown=barShown end
    overlay:Show()

    overlay.shade:ClearAllPoints()
    overlay.shade:SetPoint("TOPLEFT",row,"TOPLEFT",HEALTH_X,-top)
    overlay.shade:SetSize(width,height)
    overlay.amount:ClearAllPoints()
    overlay.amount:SetPoint("TOPLEFT",row,"TOPLEFT",HEALTH_X+width-96,-textTop)
    overlay.amount:SetSize(90,14)
    overlay.percent:ClearAllPoints()
    overlay.percent:SetPoint("TOPLEFT",row,"TOPLEFT",HEALTH_X+width-96,-textTop-15)
    overlay.percent:SetSize(90,13)

    if row.healthBar then
        row.healthBar:ClearAllPoints()
        row.healthBar:SetPoint("TOPLEFT",row,"TOPLEFT",HEALTH_X,-top)
        row.healthBar:SetSize(width,height)
    end
    -- The ordinary health updater still maintains these existing fields for
    -- all other presentations. This view uses dedicated text above the bar.
    row.healthAbs:Hide()
    row.healthPct:Hide()
    if row.healthDisplayEmpty then
        overlay.amount:SetText("")
        overlay.percent:SetText("")
        return
    end
    if not renderAmount(row,overlay.amount) then overlay.amount:SetText("? / ?") end
    if not row.healthValueAvailable
        or not pcall(overlay.percent.SetFormattedText,overlay.percent,"%.0f%%",row.healthValue) then
        overlay.percent:SetText("?%")
    end
end

function CF.RestoreHealthbarRowStyle(row)
    if not row or not row.cfHealthbarOwnStyle or CF.IsHealthbarView() then return end
    CF.ClearHealthbarHealth(row)
    if row.cfHealthbarHealthOverlay then row.cfHealthbarHealthOverlay:Hide() end
    row.name:SetParent(row)
    row.name:SetHeight(0)
    row.name:SetJustifyH("LEFT")
    if row.cfHealthbarNameColor then
        local color = row.cfHealthbarNameColor
        row.name:SetTextColor(color[1],color[2],color[3],color[4])
    end
    row.cfHealthbarNameColor = nil
    -- Main layout restores each mode's exact positions and visibility next.
    row.healthAbs:SetParent(row)
    row.healthPct:SetParent(row)
    row.healthAbs:SetHeight(0)
    row.healthPct:SetHeight(0)
    row.healthAbs:Show()
    row.healthPct:Show()
    local mode = CursiveForeverDB and CursiveForeverDB.targetDisplayMode
    local width = mode == "standard" and 82 or mode == "compact" and 72 or 70
    row.name:SetWidth(mode == "standard" and 153 or 92)
    local hideName = mode ~= "standard" and mode ~= "compact"
        or (CF.IsMatrixView and CF.IsMatrixView()) or (CF.IsBarsView and CF.IsBarsView())
    if hideName then row.name:Hide() else row.name:Show() end
    row.healthAbs:SetWidth(width)
    row.healthPct:SetWidth(width)
    if row.healthBar then row.healthBar:SetSize(width-2,10) end
    row.raidMarker:SetSize(20,20)
    row.healthDivider:SetSize(1,28)
    if row.cfExecute then
        row.cfExecute.icon:ClearAllPoints()
        row.cfExecute.icon:SetPoint("CENTER",row.cfExecute,"CENTER",-25,0)
        row.cfExecute.label:Show()
    end
    row.cfHealthbarOwnStyle = nil
    if CF.RefreshRowHealthDisplay then CF.RefreshRowHealthDisplay(row) end
end

function CF.LayoutHealthbarRow(row)
    if not row then return end
    if not CF.IsHealthbarView() then CF.RestoreHealthbarRowStyle(row); return end
    if CF.RestoreMatrixRowStyle then CF.RestoreMatrixRowStyle(row) end
    if CF.RestoreBarsRowStyle then CF.RestoreBarsRowStyle(row) end
    local center = healthCenter()
    local overlay = overlayFor(row)
    row.cfHealthbarOwnStyle = true
    row:SetHeight(CF.GetHealthbarRowHeight()-2)
    row.targetLabel:Hide()

    if not row.cfHealthbarNameColor then
        -- This is the ordinary name widget's explicitly assigned color, not
        -- health or aura data; no native text width or contents are read back.
        if type(row.name.GetTextColor) == "function" then
            local ok,r,g,b,a = pcall(row.name.GetTextColor,row.name)
            if ok then row.cfHealthbarNameColor={r,g,b,a} end
        end
        if not row.cfHealthbarNameColor then row.cfHealthbarNameColor={1,.82,0,1} end
    end
    row.name:SetParent(overlay)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT",row,"TOPLEFT",HEALTH_X+5,-center)
    row.name:SetSize(CF.GetHealthbarHealthWidth()-104,CF.GetHealthbarHealthHeight()-4)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetTextColor(1,1,1,1)
    row.name:Show()

    row.portraitRing:ClearAllPoints()
    row.portraitRing:SetPoint("LEFT",row,"TOPLEFT",5,-center)
    row.portraitRing:SetSize(34,34)
    row.portraitRing:Show()
    row.portrait:SetSize(30,30)
    row.portrait:Show()
    row.raidMarker:ClearAllPoints()
    row.raidMarker:SetPoint("TOPLEFT",row.portraitRing,"TOPLEFT",-2,2)
    row.raidMarker:SetSize(14,14)

    local auraX = CF.GetHealthbarAuraX()
    row.healthDivider:ClearAllPoints()
    row.healthDivider:SetPoint("TOPLEFT",row,"TOPLEFT",auraX-5,-CF.GetHealthbarTop())
    row.healthDivider:SetSize(1,50)
    local state = row.cfAuraLayout
    if state and state.support then
        -- An 18-unit icon with a native countdown up to 28 units wide. Both
        -- edges stay clear of the health bar and the main-effect divider.
        state.support:ClearAllPoints()
        state.support:SetPoint("TOPLEFT",row,"TOPLEFT",298+CF.GetHealthbarHealthWidth()-HEALTH_WIDTH,-center+15)
    end
    if state and state.others then
        state.others:ClearAllPoints()
        state.others:SetPoint("TOPLEFT",row,"TOPLEFT",auraX+CF.GetHealthbarSlotsWidth()+EXTRA_GAP,-CF.GetHealthbarTop())
    end
    CF.LayoutHealthbarHealth(row)
    if row.cfExecute then
        row.cfExecute:ClearAllPoints()
        row.cfExecute:SetPoint("TOPLEFT",row,"TOPLEFT",27,-center-5)
        row.cfExecute:SetSize(13,13)
        row.cfExecute.icon:ClearAllPoints()
        row.cfExecute.icon:SetPoint("CENTER",row.cfExecute,"CENTER",0,0)
        row.cfExecute.label:Hide()
    end
end
