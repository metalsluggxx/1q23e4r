local _, addon = ...
local CF = addon and addon.CF
if not CF then return end

-- Matrix geometry is derived exclusively from saved choices and layout
-- constants. The existing native aura slots still own presence and timers.
local CELL_STEP, CELL_SIZE = 28, 28
-- Four secondary effects in two rows. Each cell keeps its icon and native
-- countdown together; reserve a complete 44+4 flow pitch for each column.
local EXTRA_WIDTH, EXTRA_HEIGHT = 96, 30
local HEADER_HEIGHT = 22
local GOLD_R, GOLD_G, GOLD_B = .72, .54, .20
local blankIcon = "Interface\\Icons\\INV_Misc_QuestionMark"

local function previewEnabled()
    return CF.ExperimentalEnabled and CF.ExperimentalEnabled() or false
end

local function slotKeys()
    return CF.GetAuraSlotKeys and CF.GetAuraSlotKeys() or {}
end

function CF.IsMatrixView()
    return CursiveForeverDB and CursiveForeverDB.trackerView == "matrix"
        and #slotKeys() > 0 and not CF.auraSlotsUnavailable
        and (not CF.matrixViewUnavailable or CF.matrixFallbackDeferred) or false
end

function CF.CanSwitchTrackerView(view)
    local current = CF.GetTrackerView and CF.GetTrackerView() or "standard"
    if view == current then return true end
    for _, row in ipairs(CF.GetExperimentalRows and CF.GetExperimentalRows() or {}) do
        if row.unit and row.offscreen and row.cfRetainedAuras then
            -- Each presentation owns different native buttons. Retained aura
            -- data cannot be copied to the other presentation's container.
            return false
        end
    end
    return true
end

-- The selected-row border occupies two units at each edge. The 30-unit
-- curse/extra footprint needs one clear unit inside that border: 36 actual
-- row units plus the established two-unit gap between rows.
local function baseRowHeight() return previewEnabled() and 70 or 38 end
function CF.GetMatrixRowHeight()
    local base = baseRowHeight()
    return CF.ResolveTrackerHeight and CF.ResolveTrackerHeight(base,base,"matrix") or base
end

function CF.GetMatrixIconCenter()
    return (previewEnabled() and 31 or 18)+(CF.GetMatrixRowHeight()-baseRowHeight())/2
end

function CF.GetMatrixHeaderHeight()
    return CF.IsMatrixView() and HEADER_HEIGHT or 0
end

local function baseRowWidth()
    local support = CF.ShouldShowUtilityCurse()
    local extra = CF.ExperimentalWidth and CF.ExperimentalWidth() or 0
    return (support and 64 or 32)+70+10+#slotKeys()*CELL_STEP+(CF.AreTrackerExtrasEnabled() and 8+EXTRA_WIDTH or 0)+16+extra
end
function CF.GetMatrixHealthWidth()
    return 70+CF.GetMatrixRowWidth()-baseRowWidth()
end
local function matrixColumns()
    local support = CF.ShouldShowUtilityCurse()
    -- The curse's native countdown can extend five units beyond either
    -- edge of its icon. Keep four clear units around that full footprint.
    local healthX = support and 64 or 32
    return healthX, healthX + CF.GetMatrixHealthWidth() + 4, support
end

function CF.GetMatrixAuraX()
    local _, dividerX = matrixColumns()
    return dividerX + 6
end

function CF.GetMatrixRowWidth()
    local base = baseRowWidth()
    return CF.ResolveTrackerWidth and CF.ResolveTrackerWidth(base,base-20,"matrix") or base
end

function CF.GetMatrixSlotPosition(index)
    return (index-1)*CELL_STEP, 0
end

function CF.GetMatrixSlotsWidth(count)
    return math.max(CELL_SIZE,count*CELL_STEP)
end

function CF.GetMatrixExtraSize()
    return EXTRA_WIDTH, EXTRA_HEIGHT
end

function CF.InitMatrixAuraButton(button, formatter)
    -- This function is called only inside initializeFrame. After that
    -- callback returns, neither this button nor its regions are accessed.
    button:SetSize(CELL_SIZE,CELL_SIZE)
    local icon = button:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(button)
    icon:SetAlpha(0)
    button:SetIcon(icon)

    local duration = button:CreateFontString(nil,"OVERLAY","GameFontNormal")
    duration:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"OUTLINE")
    duration:SetPoint("CENTER",button,"CENTER",0,0)
    duration:SetSize(CELL_SIZE,14)
    duration:SetJustifyH("CENTER")
    duration:SetWordWrap(false)
    duration:SetTextColor(1,.90,.36,1)
    if formatter then button:SetDurationText(duration,(CF.Client and CF.Client.DurationTextOptions
        and CF.Client.DurationTextOptions(formatter)) or {textFormatter=formatter})
    else button:SetDurationText(duration) end

    -- A permanent applied effect has no seconds to render. This small mark
    -- inherits the native button's presence without inspecting that state.
    local presence = button:CreateTexture(nil,"OVERLAY")
    presence:SetSize(6,1)
    presence:SetPoint("BOTTOM",button,"BOTTOM",0,2)
    presence:SetColorTexture(GOLD_R,GOLD_G,GOLD_B,.9)
end

function CF.InitMatrixExtraAuraButton(button, formatter)
    -- Called only inside initializeFrame. The 44-unit cell is native-owned;
    -- its visible icon and duration veil occupy only the first fourteen.
    button:SetSize(44,14)
    local icon = button:CreateTexture(nil,"ARTWORK")
    icon:SetPoint("TOPLEFT",button,"TOPLEFT",0,0)
    icon:SetSize(14,14)
    icon:SetTexCoord(.08,.92,.08,.92)
    icon:SetVertexColor(1,1,1,1)
    button:SetIcon(icon)

    local veil = CreateFrame("StatusBar",nil,button)
    veil:SetPoint("TOPLEFT",button,"TOPLEFT",0,0)
    veil:SetSize(14,14)
    veil:SetOrientation("VERTICAL")
    if veil.SetReverseFill then veil:SetReverseFill(true) end
    veil:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    local texture = veil:GetStatusBarTexture()
    if texture then
        texture:SetColorTexture(.25,.25,.28,CF.GetAppliedAuraVeilOpacity and CF.GetAppliedAuraVeilOpacity() or .58)
        if texture.SetBlendMode then texture:SetBlendMode("BLEND") end
    end
    local options = {}
    if Enum and Enum.StatusBarTimerDirection then
        options.direction = Enum.StatusBarTimerDirection.ElapsedTime or Enum.StatusBarTimerDirection.RemainingTime
    end
    if Enum and Enum.StatusBarInterpolation then options.interpolation = Enum.StatusBarInterpolation.Immediate end
    local ok = pcall(button.SetDurationBar,button,veil,options)
    if not ok then veil:Hide() end

    local shade = button:CreateTexture(nil,"OVERLAY")
    shade:SetPoint("TOPLEFT",button,"TOPLEFT",16,0)
    shade:SetSize(28,14)
    shade:SetColorTexture(0,0,0,.70)
    local duration = button:CreateFontString(nil,"OVERLAY","GameFontNormal")
    duration:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",8,"OUTLINE")
    duration:SetPoint("TOPLEFT",button,"TOPLEFT",16,0)
    duration:SetSize(28,14)
    duration:SetJustifyH("LEFT")
    duration:SetWordWrap(false)
    duration:SetTextColor(1,.90,.36,1)
    if formatter then button:SetDurationText(duration,(CF.Client and CF.Client.DurationTextOptions
        and CF.Client.DurationTextOptions(formatter)) or {textFormatter=formatter})
    else button:SetDurationText(duration) end
end

function CF.RestoreMatrixRowStyle(row)
    if not row or not row.cfMatrixOwnStyle or CF.IsMatrixView() then return end
    -- Only our ordinary row widgets are restored. Native aura buttons and
    -- their children remain owned exclusively by their initialization cache.
    row.healthAbs:SetParent(row)
    row.healthPct:SetParent(row)
    row.healthAbs:SetHeight(0)
    row.healthPct:SetHeight(0)
    if row.healthBar then row.healthBar:SetHeight(10) end
    if row.cfMatrixHealthOverlay then row.cfMatrixHealthOverlay:Hide() end
    row.raidMarker:SetSize(20,20)
    row.healthDivider:SetSize(1,28)
    if row.cfExecute then
        row.cfExecute.icon:ClearAllPoints()
        row.cfExecute.icon:SetPoint("CENTER",row.cfExecute,"CENTER",-25,0)
        row.cfExecute.label:Show()
    end
    row.cfMatrixOwnStyle = nil
    row.cfMatrixBarShown = nil
end

function CF.LayoutMatrixHealth(row, barShown)
    if not row or not CF.IsMatrixView() then return end
    local center = CF.GetMatrixIconCenter()
    local healthX = matrixColumns()
    local width = CF.GetMatrixHealthWidth()
    local overlay = row.cfMatrixHealthOverlay
    if not overlay then
        -- Health text must be above the child StatusBar. This parent is
        -- independent of the bar's native fill, visibility and geometry.
        overlay = CreateFrame("Frame",nil,row)
        overlay:SetAllPoints(row)
        overlay:SetFrameLevel(row:GetFrameLevel()+4)
        overlay:EnableMouse(false)
        overlay.shade = overlay:CreateTexture(nil,"BACKGROUND")
        overlay.shade:SetColorTexture(0,0,0,.4)
        row.cfMatrixHealthOverlay = overlay
    end
    row.cfMatrixOwnStyle = true
    overlay:Show()
    row.healthAbs:SetParent(overlay)
    row.healthPct:SetParent(overlay)
    row.healthAbs:ClearAllPoints()
    row.healthPct:ClearAllPoints()
    row.healthAbs:SetSize(width,14)
    row.healthPct:SetSize(width,14)
    if barShown ~= nil then row.cfMatrixBarShown = barShown
    elseif row.cfMatrixBarShown ~= nil then barShown = row.cfMatrixBarShown
    else barShown = CF.GetHealthDisplayMode() == "bar" and row.healthBarValueAvailable end
    if barShown then
        row.healthAbs:SetPoint("CENTER",row,"TOPLEFT",healthX+width/2,-center)
        row.healthPct:SetPoint("CENTER",row,"TOPLEFT",healthX+width/2,-center-7)
        overlay.shade:ClearAllPoints()
        overlay.shade:SetPoint("TOPLEFT",row,"TOPLEFT",healthX+1,-center+9)
        overlay.shade:SetSize(width-2,18)
        overlay.shade:Show()
    else
        -- Percentage mode and unreadable-health fallbacks retain both the
        -- absolute value and the second line, without inspecting their text.
        row.healthAbs:SetPoint("CENTER",row,"TOPLEFT",healthX+width/2,-center+7)
        row.healthPct:SetPoint("CENTER",row,"TOPLEFT",healthX+width/2,-center-7)
        overlay.shade:Hide()
    end
    if row.healthBar then
        row.healthBar:ClearAllPoints()
        row.healthBar:SetPoint("TOPLEFT",row,"TOPLEFT",healthX+1,-center+9)
        row.healthBar:SetSize(width-2,18)
    end
end

function CF.LayoutMatrixRow(row)
    if not row then return end
    if not CF.IsMatrixView() then CF.RestoreMatrixRowStyle(row); return end
    local center = CF.GetMatrixIconCenter()
    local healthX, dividerX = matrixColumns()
    row:SetHeight(CF.GetMatrixRowHeight()-2)
    row.name:Hide()
    row.targetLabel:Hide()
    row.cfMatrixOwnStyle = true
    row.portraitRing:SetSize(24,24)
    row.portraitRing:ClearAllPoints()
    row.portraitRing:SetPoint("LEFT", row, "TOPLEFT", 4, -center)
    row.portraitRing:Show()
    row.portrait:SetSize(20,20)
    row.portrait:Show()
    row.raidMarker:ClearAllPoints()
    row.raidMarker:SetSize(14,14)
    row.raidMarker:SetPoint("TOPLEFT", row.portraitRing, "TOPLEFT", -2, 2)

    CF.LayoutMatrixHealth(row)
    row.healthDivider:ClearAllPoints()
    row.healthDivider:SetPoint("LEFT", row, "TOPLEFT", dividerX, -center)
    row.healthDivider:SetSize(1,26)

    local state = row.cfAuraLayout
    if state and state.support then
        state.support:ClearAllPoints()
        state.support:SetPoint("TOPLEFT", row, "TOPLEFT", 37, -center+15)
    end
    if row.cfExecute then
        row.cfExecute:ClearAllPoints()
        row.cfExecute:SetPoint("TOPLEFT", row, "TOPLEFT", 15, -center+1)
        row.cfExecute:SetSize(13,13)
        row.cfExecute.icon:ClearAllPoints()
        row.cfExecute.icon:SetPoint("CENTER",row.cfExecute,"CENTER",0,0)
        row.cfExecute.label:Hide()
    end
end

local function makeHeader(main)
    local header = CreateFrame("Frame", nil, main)
    header:SetHeight(HEADER_HEIGHT)
    header.icons = {}
    for index=1,8 do
        local button = CreateFrame("Button", nil, header)
        button:SetSize(18,18)
        local icon = button:CreateTexture(nil,"ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(.08,.92,.08,.92)
        button.icon = icon
        button:SetScript("OnEnter",function(self)
            if GameTooltip and self.cfSpellLabel then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(self.cfSpellLabel,1,.84,.46)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        header.icons[index] = button
    end
    return header
end

function CF.LayoutMatrixHeaders(main, columns, rowWidth, titleHeight, activeCount)
    if not main then return end
    local show = CF.IsMatrixView() and activeCount > 0
    local headers = main.cfMatrixHeaders or {}
    main.cfMatrixHeaders = headers
    if not show then
        for _, header in ipairs(headers) do header:Hide() end
        return
    end
    local keys, byKey = slotKeys(), {}
    for _, spell in ipairs(CF.GetAuraLayoutCatalog()) do byKey[spell.key] = spell end
    local auraX = CF.GetMatrixAuraX()
    for column=1,math.max(2,columns) do
        local header = headers[column]
        if column <= columns then
            if not header then header=makeHeader(main); headers[column]=header end
            header:ClearAllPoints()
            local frameless = CF.IsTrackerFrameHidden and CF.IsTrackerFrameHidden()
            header:SetPoint("TOPLEFT", main, "TOPLEFT", (frameless and 0 or 6)+(column-1)*rowWidth, -titleHeight-2)
            header:SetSize(rowWidth-(frameless and 0 or 12),HEADER_HEIGHT)
            for index, button in ipairs(header.icons) do
                local spell = byKey[keys[index]]
                if spell then
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", header, "TOPLEFT", auraX+(index-1)*CELL_STEP+CELL_SIZE/2, -HEADER_HEIGHT/2)
                    button.icon:SetTexture(CF.SafeSpellTexture(spell.ids[1]) or blankIcon)
                    local label = spell.fallback
                    if CF.AuraLayoutUI and CF.AuraLayoutUI.spellInfo then
                        local name = CF.AuraLayoutUI.spellInfo(spell)
                        label = name or label
                    end
                    button.cfSpellLabel = label
                    button:Show()
                else
                    button.cfSpellLabel = nil
                    button:Hide()
                end
            end
            header:Show()
        elseif header then header:Hide() end
    end
end
