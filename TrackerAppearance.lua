local _,addon=...
local CF=addon and addon.CF
if not CF then return end

-- Freeze native icon cosmetics for this UI session. Saved changes never
-- touch native descendants or rebuild retained offscreen containers.
local appliedVeilOpacity
function CF.GetAuraVeilOpacity()
    local value=CursiveForeverDB and CursiveForeverDB.auraVeilOpacity
    if type(value) ~= "number" or value ~= value then return 58 end
    return math.floor(math.max(0,math.min(100,value))+.5)
end
function CF.GetAppliedAuraVeilOpacity()
    if appliedVeilOpacity == nil then appliedVeilOpacity=CF.GetAuraVeilOpacity() end
    return appliedVeilOpacity/100
end
function CF.SetAuraVeilOpacity(value)
    if not CursiveForeverDB then return end
    CF.GetAppliedAuraVeilOpacity()
    CursiveForeverDB.auraVeilOpacity=value
    CursiveForeverDB.auraVeilOpacity=CF.GetAuraVeilOpacity()
    if CF.RefreshAuraAppearanceControls then CF.RefreshAuraAppearanceControls() end
end
function CF.HasPendingAuraAppearance()
    return CF.GetAuraVeilOpacity() ~= math.floor(CF.GetAppliedAuraVeilOpacity()*100+.5)
end

-- Public presentation preferences only; aura and combat state stay native.
function CF.AreTrackerExtrasEnabled()
    return not CursiveForeverDB or CursiveForeverDB.trackerExtraIcons ~= false
end
function CF.IsTrackerFrameHidden()
    return CursiveForeverDB and CursiveForeverDB.hideTrackerFrame == true or false
end
function CF.ShouldShowUtilityCurse(mode)
    return CF.AreTrackerExtrasEnabled() and CF.WantsPortraitCurses and CF.WantsPortraitCurses(mode) or false
end
local function hasRetainedLegacyRow()
    for _,row in ipairs(CF.GetExperimentalRows and CF.GetExperimentalRows() or {}) do
        local state=row.cfAuraLayout
        if row.unit and row.offscreen and row.cfRetainedAuras and not (state and state.fixedActive) then return true end
    end
    return false
end
function CF.GetRequestedTrackerExtras()
    if CF.pendingTrackerExtraIcons ~= nil then return CF.pendingTrackerExtraIcons end
    return CF.AreTrackerExtrasEnabled()
end
local function refreshControls()
    if CF.RefreshTrackerAppearanceControls then CF.RefreshTrackerAppearanceControls() end
end
function CF.SetTrackerExtrasEnabled(enabled)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not CursiveForeverDB then return false end
    enabled=enabled ~= false
    if enabled ~= CF.AreTrackerExtrasEnabled() and hasRetainedLegacyRow() then
        -- Standard's sorted legacy strip contains main and extra effects in
        -- one group. Its filters cannot be rebuilt from an unavailable unit.
        CF.pendingTrackerExtraIcons=enabled
        refreshControls()
        return false
    end
    CF.pendingTrackerExtraIcons=nil
    CursiveForeverDB.trackerExtraIcons=enabled
    if CF.ApplyAuraLayoutToAllRows then CF.ApplyAuraLayoutToAllRows() end
    refreshControls()
    return true
end
function CF.ApplyPendingTrackerExtras()
    if CF.pendingTrackerExtraIcons == nil or hasRetainedLegacyRow() then return false end
    CursiveForeverDB.trackerExtraIcons=CF.pendingTrackerExtraIcons
    CF.pendingTrackerExtraIcons=nil
    refreshControls()
    return true
end
function CF.SetTrackerFrameHidden(hidden)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not CursiveForeverDB then return end
    CursiveForeverDB.hideTrackerFrame=hidden == true
    if CF.RelayoutTrackerFrame then CF.RelayoutTrackerFrame() end
    refreshControls()
end
function CF.ApplyTrackerExtrasToRow(row)
    local s=row and row.cfAuraLayout
    if not s then return end
    local show=CF.AreTrackerExtrasEnabled()
    if s.others then s.others:SetShown(show and s.fixedActive or false) end
    if s.support then s.support:SetShown(show and s.supportActive or false) end
end
local function targetBracket(row)
    if row.cfTargetBracket then return row.cfTargetBracket end
    -- Addon-owned decoration, within the existing left margin. Anchors follow
    -- the row's height; no aura widget or protected content is inspected.
    local bracket={}
    for layer=0,1 do
        local inset=layer
        local thickness=layer==0 and 4 or 2
        local arm=layer==0 and 8 or 6
        local function stroke()
            -- Below portrait and raid-marker artwork, so the selection mark
            -- never paints over their existing compact overlay positions.
            local texture=row:CreateTexture(nil,"BACKGROUND",nil,layer+1)
            if layer==0 then texture:SetColorTexture(.02,.03,.02,1)
            else texture:SetColorTexture(.36,.88,.42,1) end
            bracket[#bracket+1]=texture
            return texture
        end
        local side=stroke()
        side:SetPoint("TOPLEFT",row,"TOPLEFT",inset,-inset)
        side:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",inset,inset)
        side:SetWidth(thickness)
        local top=stroke()
        top:SetPoint("TOPLEFT",row,"TOPLEFT",inset,-inset)
        top:SetSize(arm,thickness)
        local bottom=stroke()
        bottom:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",inset,inset)
        bottom:SetSize(arm,thickness)
    end
    row.cfTargetBracket=bracket
    return bracket
end
function CF.ApplyTrackerRowAppearance(row)
    if not row then return end
    local hidden=CF.IsTrackerFrameHidden()
    if row.bg then row.bg:SetShown(not hidden) end
    if row.healthDivider then row.healthDivider:SetShown(not hidden) end
    if hidden and row.targetBorder then row.targetBorder:Hide() end
    local selected=hidden and row.unit ~= nil and row.cfTargetSelected == true
    local bracket=selected and targetBracket(row) or row.cfTargetBracket
    for _,texture in ipairs(bracket or {}) do texture:SetShown(selected) end
end
