local ADDON_NAME, addon = ...
local CF = addon.CF
local T = {rows={}, holders={}, buttons={}, recipients={}}
CF.ClickCasting = T

-- The protected tree is independent of the normal tracker. It is positioned
-- against UIParent, NEVER anchored to an ordinary tracker/native aura frame.
-- Only secure state drivers move/show its two role holders during combat.
-- Ordinary presentation rows are siblings of the secure buttons. Their native
-- aura bindings remain the literal aliases focus/target for their lifetime.
-- A changed enemy behind an alias needs an explicit native aura rebuild.
local function readable(v)
    if type(issecretvalue)=="function" then
        local ok,s=pcall(issecretvalue,v); if not ok or s then return false end
    end
    if type(canaccessvalue)=="function" then
        local ok,a=pcall(canaccessvalue,v); if not ok or not a then return false end
    end
    return true
end
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...); if ok and readable(v) then return v end
end
local function locked()
    return call(InCombatLockdown)~=false
end
local function guid(unit)
    local g=call(UnitGUID,unit)
    return type(g)=="string" and g~="" and g or nil
end
local function db() return CursiveForeverDB or {} end
local function say(key)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd8b15aCursive:|r "..CF.T(key)) end
end
local words={
 en={CLICK_CASTING="Click to cast",CLICK_CASTING_TIP="Left-click main effects on the marked Focus row or your current target. Uses fixed positions in all four views. Other enemies remain display-only. Focus and target are shown separately even when they are the same enemy. Change the layout outside combat.",
     CLICK_LOCKED="Change the layout or move the window after combat while click casting is active.",
     CLICK_FOCUS="Focus",CLICK_TARGET="Current target",CLICK_SPELL="Left-click: %s (%s)",
     CLICK_FAILED="Click casting could not be prepared. The ordinary tracker remains available. /cfclick report shows details.",
     CLICK_COMMANDS="/cfclick on | off | report. Change this outside combat.",
     CLICK_NOTE="Marked Focus row first, current target next. With fixed positions, click an icon, timer cell or DoT bar to cast. Other enemies stay below.",},
 de={CLICK_CASTING="Zaubern per Klick",CLICK_CASTING_TIP="Linksklick auf Haupteffekte in der gekennzeichneten Fokuszeile oder beim aktuellen Ziel. Funktioniert mit festen Plätzen in allen vier Ansichten. Weitere Gegner dienen der Anzeige. Fokus und Ziel bleiben zwei Zeilen, auch wenn es derselbe Gegner ist. Anordnung außerhalb des Kampfes ändern.",
     CLICK_LOCKED="Anordnung und Fensterposition bei aktivem Klickzaubern nach dem Kampf ändern.",
     CLICK_FOCUS="Fokus",CLICK_TARGET="Aktuelles Ziel",CLICK_SPELL="Linksklick: %s (%s)",
     CLICK_FAILED="Klickzaubern konnte nicht vorbereitet werden. Die gewohnte Anzeige bleibt verfügbar. Details: /cfclick report.",
     CLICK_COMMANDS="/cfclick on | off | report. Außerhalb des Kampfes ändern.",
     CLICK_NOTE="Markierter Fokus zuerst, aktuelles Ziel darunter. Bei festen Plätzen auf Symbol, Zeitzelle oder DoT-Balken klicken, um zu zaubern. Weitere Gegner stehen darunter.",}
}
for k,v in pairs(words.en) do CF.L_EN[k]=v end
for k,v in pairs(words.de) do CF.L_DE[k]=v end
function CF.ClickLayoutLocked()
    return T.active==true and locked()
end
function CF.ClickCastingEnabled() return db().clickCasting~=false end
function CF.SetClickCastingEnabled(enabled)
    if CF.ClickLayoutLocked() then say("CLICK_LOCKED"); return false end
    db().clickCasting=enabled==true
    T.Refresh()
    return true
end
local function known(id)
    if call(C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell or IsSpellKnown,id)~=true then return false end
    local api=C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell
    return not api or call(api,id)==false
end
local function spellFor(family,class)
    local ids={}
    for _,id in ipairs(family.ids or {}) do ids[id]=true end
    for id in pairs(CF.filterSpellRanks and CF.filterSpellRanks[class] and CF.filterSpellRanks[class][family.key] or {}) do ids[id]=true end
    for _,id in ipairs(CF.FILTER_RANK_CANDIDATES and CF.FILTER_RANK_CANDIDATES[class] and CF.FILTER_RANK_CANDIDATES[class][family.key] or {}) do ids[id]=true end
    if CF.Client and CF.Client.ResolveCastSpell then
        local handled,name=CF.Client.ResolveCastSpell(family,class,ids)
        if handled then return name,ids end
    end
    if family.castable==false then return nil,ids end
    local candidates=ids
    if family.castIDs then
        candidates={};for _,id in ipairs(family.castIDs) do candidates[id]=true;ids[id]=true end
    end
    local sorted={};for id in pairs(candidates) do if type(id)=="number" then sorted[#sorted+1]=id end end
    table.sort(sorted)
    for _,id in ipairs(sorted) do
        if known(id) then
            local name=CF.SafeSpellName(id)
            if readable(name) and type(name)=="string" and name~="" and not name:find("[\r\n]") then return name,ids end
        end
    end
    return nil,ids
end
local preparedSpells
local function config(reuseSpells)
    local c={slots={},view=CF.GetTrackerView()}
    c.fixed=c.view=="matrix" or c.view=="bars" or CF.GetAuraOrderMode()=="fixed"
    c.enabled=CF.ClickCastingEnabled() and c.fixed
    local class=CF.GetPerformanceClassFile()
    -- All four editions reuse successful spell preparation on idle polls. Explicit
    -- refreshes (settings, login, SPELLS_CHANGED, combat end) start fresh.
    -- A delayed spellbook scan replaces the ranks table; changed catalogue
    -- families have different keys. Unavailable names are retried each poll.
    local cache
    if CF.Client and (CF.Client.edition=="Forever" or CF.Client.edition=="Retail" or CF.Client.edition=="MoP" or CF.Client.edition=="Era")
        and not CF.classRanksDirty then
        local ranks=CF.filterSpellRanks and CF.filterSpellRanks[class]
        if not reuseSpells or not preparedSpells or preparedSpells.class~=class or preparedSpells.ranks~=ranks then
            preparedSpells={class=class,ranks=ranks,spells={}}
        end
        cache=preparedSpells.spells
    else preparedSpells=nil end
    local filter=CF.GetClassFilterStorage(class)
    local context=CF.GetAuraContext()
    local catalog={};for _,f in ipairs(CF.GetAuraLayoutCatalog()) do catalog[f.key]=f end
    local learned=false
    for _,key in ipairs(CF.GetAuraSlotKeys()) do
        local f=catalog[key]
        if f then
            local name,ids
            local prepared=cache and cache[f]
            if prepared then name,ids=prepared.name,prepared.ids
            else
                name,ids=spellFor(f,class)
                if cache and name then cache[f]={name=name,ids=ids} end
            end
            if filter[key] and filter[key][context]==false then name=nil end
            c.slots[#c.slots+1]={key=key,name=name,ids=ids}
            learned=learned or name~=nil
        end
    end
    c.enabled=c.enabled and learned
    c.width,c.height,c.left,c.top=CF.GetClickRoleGeometry()
    -- Header height is frozen during active combat, including nameplate warnings.
    c.header=db().showHeader==false and not CursiveForeverFrame.cfNameplateWarningActive and 0 or 20
    c.top=c.header+CF.GetMatrixHeaderHeight()+(CF.IsTrackerFrameHidden() and 0 or 4)
    local keys={tostring(c.enabled),c.view,c.width,c.height,c.left,c.top,tostring(db().frameScale),
        tostring(db().hidden),tostring(db().hideWindowOutOfCombat),tostring(db().showTargetOutOfCombat),
        tostring(db().portraitCurses),tostring(db().trackerExtraIcons),tostring(db().hideTrackerFrame),
        tostring(CF.GetHealthDisplayMode()),tostring(CF.GetBarsShowSpellNames()),
        tostring(CF.ExperimentalEnabled()),context,CF.T("CLICK_FOCUS")}
    for _,s in ipairs(c.slots) do
        local ids={};for id in pairs(s.ids) do ids[#ids+1]=id end;table.sort(ids)
        keys[#keys+1]=s.key..":"..(s.name or "-")..":"..table.concat(ids,",")
    end
    c.signature=table.concat(keys,"|")
    return c
end

-- This is intentionally identity-free: state drivers decide only whether each
-- fixed role exists, not which enemy it denotes. The duplicate role display
-- when focus == target is intentional, matching the game's unit frames.
T.stateSnippet=[[
    local f=self:GetFrameRef("focus")
    local t=self:GetFrameRef("target")
    local focus=self:GetAttribute("state-focus")=="show"
    local target=self:GetAttribute("state-target")=="show"
    if focus then f:Show() else f:Hide() end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT",self,"TOPLEFT",self:GetAttribute("left"),
        -self:GetAttribute("top")-(focus and self:GetAttribute("row-height") or 0))
    if target then t:Show() else t:Hide() end
    self:CallMethod("RefreshPresentation")
]]
local function tooltip(button)
    if not GameTooltip or not button.cfName then return end
    GameTooltip:SetOwner(CursiveForeverFrame,"ANCHOR_RIGHT")
    GameTooltip:SetText(CF.TF("CLICK_SPELL",button.cfName,CF.T(button.cfUnit=="focus" and "CLICK_FOCUS" or "CLICK_TARGET")),1,.9,.65)
    GameTooltip:Show()
end
local function capture(button,mouse,down)
    T.dispatch=nil
    if mouse~="LeftButton" or down or not button.cfName then return end
    -- This record is usable only while this hardware click is being dispatched.
    -- Never let a failed click misattribute a later keyboard cast.
    local unit=button.cfUnit
    local key=guid(unit)
    if key and call(UnitCanAttack,"player",unit)==true and call(UnitIsDeadOrGhost,unit)==false then
        T.dispatch={unit=unit,guid=key,ids=button.cfIDs,name=call(UnitName,unit)}
    end
end
local function layoutFocusBadge(row)
    local badge=row.cfFocusBadge
    badge:ClearAllPoints()
    local view=CF.GetTrackerView()
    if view=="matrix" or view=="bars" then
        -- Matrix has no room below the portrait; DoT bars use it for health.
        -- Keep a large F opposite the raid marker, inside the existing row.
        badge:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",16,"OUTLINE")
        badge:SetSize(12,18)
        badge:SetPoint("BOTTOMRIGHT",row.portraitRing,"BOTTOMRIGHT",2,-1)
        badge:SetText("F")
    else
        -- Fits the existing band below the portrait, including minimum row
        -- height in Health bars. Neither row nor window dimensions change.
        badge:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
        badge:SetSize(36,10)
        badge:SetPoint("TOP",row.portraitRing,"BOTTOM",0,-1)
        badge:SetText(CF.T("CLICK_FOCUS"))
    end
    badge:SetTextColor(.9,.78,1,1)
    badge:SetJustifyH("CENTER")
    badge:SetWordWrap(false)
    badge:SetShown(row.cfClickRole=="focus")
end
local function create()
    local root=CreateFrame("Frame","CursiveForeverClickRoot",UIParent,"SecureHandlerStateTemplate")
    T.root=root
    root:Hide();root:SetMovable(true);root:SetClampedToScreen(true)
    root:SetFrameStrata("MEDIUM");root:SetFrameLevel(CursiveForeverFrame:GetFrameLevel()+5)
    root.RefreshPresentation=function() if not T.preparing then CF.RelayoutTrackerFrame() end end
    for _,unit in ipairs({"focus","target"}) do
        local holder=CreateFrame("Frame",nil,root,"SecureFrameTemplate")
        T.holders[unit]=holder;holder:Hide();holder:SetFrameLevel(root:GetFrameLevel()+1)
        root:SetFrameRef(unit,holder)
        local row=CF.CreateClickRoleRow(holder,unit)
        T.rows[#T.rows+1]=row
        row.unit,row.cfAuraUnit=unit,unit
        row:SetPoint("TOPLEFT",holder,"TOPLEFT",0,0)
        row:SetFrameLevel(holder:GetFrameLevel()+1)
        row.cfFocusBadge=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        layoutFocusBadge(row)
        T.buttons[unit]={}
        for i=1,8 do
            local b=CreateFrame("Button",nil,holder,"SecureActionButtonTemplate")
            b:SetFrameLevel(holder:GetFrameLevel()+30)
            b:RegisterForClicks("AnyDown","AnyUp")
            b:SetAttribute("useOnKeyDown",false)
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
            b.cfUnit=unit
            b:SetScript("PreClick",capture)
            b:SetScript("PostClick",function() T.dispatch=nil end)
            b:SetScript("OnEnter",tooltip)
            b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            T.buttons[unit][i]=b
        end
    end
    root:SetAttribute("_onstate-focus",T.stateSnippet)
    root:SetAttribute("_onstate-target",T.stateSnippet)
end
local function coordinates(frame)
    local left,top=frame:GetLeft(),frame:GetTop()
    if type(left)~="number" or type(top)~="number" then return nil end
    return left,top
end
function T.SavePosition()
    if not T.active then return false end
    if locked() then return true end
    local x,y=coordinates(T.root)
    if x then db().point,db().relativePoint,db().x,db().y="TOPLEFT","BOTTOMLEFT",x,y end
    return true
end
function T.RestorePosition()
    if not T.active then return false end
    if locked() then return true end
    T.root:ClearAllPoints()
    if db().point then T.root:SetPoint(db().point,UIParent,db().relativePoint or db().point,db().x or 0,db().y or 0)
    else T.root:SetPoint("CENTER",UIParent,"CENTER",360,40) end
    return true
end
function T.StartMoving()
    if not T.active then return false end
    if locked() then say("CLICK_LOCKED") else
        local x,y=GetCursorPosition()
        local left,top=coordinates(T.root)
        if left then T.moving={x=x,y=y,left=left,top=top,scale=T.root:GetEffectiveScale()} end
    end
    return true
end
function T.StopMoving()
    if T.active and T.moving then T.moving=nil;if not locked() then T.SavePosition() end end
end
local function deactivate()
    if not T.root then return end
    if T.active then
        local x,y=coordinates(T.root)
        CursiveForeverFrame:ClearAllPoints()
        if x then CursiveForeverFrame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
        else CursiveForeverFrame:SetPoint("CENTER",UIParent,"CENTER",360,40) end
    end
    T.active=false
    for _,state in ipairs({"focus","target","visibility"}) do UnregisterStateDriver(T.root,state) end
    T.root:Hide();CursiveForeverFrame:SetClampedToScreen(true)
    for _,row in ipairs(T.rows) do row:Hide() end
    for _,list in pairs(T.buttons) do for _,b in ipairs(list) do
        b:SetAttribute("type1",nil);b:SetAttribute("macrotext1",nil);b:Hide()
    end end
end
local function apply(c)
    if not c.enabled then deactivate();return end
    if not T.root then create() end
    local root=T.root
    root:SetScale(db().frameScale or 1)
    if not T.active then
        local x,y=coordinates(CursiveForeverFrame)
        assert(x,"tracker position not ready")
        root:ClearAllPoints();root:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
    end
    root:SetSize(c.width,c.top+2*c.height)
    -- Main can still resize and reflow off-screen tracker rows in combat.
    CursiveForeverFrame:SetClampedToScreen(false)
    CursiveForeverFrame:ClearAllPoints();CursiveForeverFrame:SetPoint("TOPLEFT",root,"TOPLEFT",0,0)
    T.active=true;T.headerHeight=c.header
    root:SetAttribute("left",c.left);root:SetAttribute("top",c.top);root:SetAttribute("row-height",c.height)
    for _,row in ipairs(T.rows) do
        local unit=row.cfClickRole
        local holder=T.holders[unit]
        holder:SetSize(c.width-12,c.height-2)
        holder:ClearAllPoints();holder:SetPoint("TOPLEFT",root,"TOPLEFT",c.left,-c.top-(unit=="target" and c.height or 0))
        CF.LayoutClickRoleRow(row)
        layoutFocusBadge(row)
        row.auraContainer:SetUnit(unit);CF.UpdateAuraLayoutUnit(row,unit)
        row.cfClickAuraInitialized=nil
        local state=row.cfAuraLayout
        local cache=state and state.fixedActive and state.fixedCaches[state.fixedStyle]
        assert(cache and cache.anchors,"fixed effect slots unavailable")
        for i,b in ipairs(T.buttons[unit]) do
            local slot,anchor=c.slots[i],cache.anchors[i]
            local name=slot and slot.name
            b.cfName=name;b.cfIDs=slot and slot.ids
            b:SetAttribute("type1",name and "macro" or nil)
            b:SetAttribute("macrotext1",name and ("/cast [@"..unit..",exists,harm,nodead] "..name) or nil)
            b:ClearAllPoints()
            if slot and anchor then
                -- Ordinary addon-owned anchors, prepared OOC. No native aura
                -- frame, aura contents or secret geometry is inspected here.
                local _,_,_,x,y=anchor:GetPoint(1)
                b:SetPoint("TOPLEFT",holder,"TOPLEFT",x,y)
                b:SetSize(anchor:GetWidth(),c.view=="matrix" and 28 or c.view=="bars" and 16 or 48)
            end
            b:SetShown(name~=nil and anchor~=nil)
        end
        row:Show()
    end
    local combat=db().showTargetOutOfCombat==false and ",combat" or ""
    RegisterStateDriver(root,"focus","[@focus,exists,harm,nodead"..combat.."] show; hide")
    RegisterStateDriver(root,"target","[@target,exists,harm,nodead"..combat.."] show; hide")
    RegisterStateDriver(root,"visibility",db().hidden and "hide" or db().hideWindowOutOfCombat and "[combat] show; hide" or "show")
    -- Driver values need not change when only geometry changes.
    root:Execute(T.stateSnippet)
end
function T.VisibleCount()
    if not T.active then return 0 end
    local count=0
    for _,unit in ipairs({"focus","target"}) do if T.holders[unit]:IsShown() then count=count+1 end end
    return count
end
function T.Represents(row)
    if not T.active then return false end
    for _,unit in ipairs({"focus","target"}) do
        if T.holders[unit]:IsShown() then
            local key=guid(unit)
            if key and readable(row.guid) and row.guid==key then return true end
        end
    end
    return false
end
local function refreshRoleAuras(row)
    -- UpdateAllAuras is the native container's public, display-only full
    -- refresh API. SetUnit with the same literal token is deliberately a no-op.
    -- Never read aura contents, native buttons, or timer values back into Lua.
    local function update(container)
        if container and type(container.UpdateAllAuras)=="function" then
            local ok,err=pcall(container.UpdateAllAuras,container)
            if not ok then T.lastAuraError=readable(err) and tostring(err) or "unreadable error" end
        end
    end
    update(row.auraContainer)
    local state=row.cfAuraLayout
    if state then
        update(state.fixed)
        update(state.others)
        update(state.support)
    end
    row.cfClickAuraGUID=guid(row.cfClickRole)
    row.cfClickAuraInitialized=true
end
function T.RefreshAuras(changedUnit)
    if not T.active or T.preparing then return end
    -- A role event can arrive under just one alias when target == focus.
    -- Refresh both role displays on either alias, also for unreadable GUIDs.
    local all=not readable(changedUnit) or changedUnit==nil
        or changedUnit=="target" or changedUnit=="focus"
    local key=not all and type(changedUnit)=="string" and guid(changedUnit) or nil
    for _,row in ipairs(T.rows) do
        local role=row.cfClickRole
        if all or call(UnitIsUnit,changedUnit,role)==true
            or (key and key==guid(role)) then refreshRoleAuras(row) end
    end
end
function T.RefreshVisuals()
    if not T.active or T.preparing then return end
    local alpha=1-CF.GetWindowTransparency()/100
    for _,row in ipairs(T.rows) do
        -- Catch identity changes even when another layout handler runs first.
        -- Stable health ticks never poll or rebuild native aura data.
        if not row.cfClickAuraInitialized or row.cfClickAuraGUID~=guid(row.cfClickRole) then
            refreshRoleAuras(row)
        end
        CF.RefreshClickRoleRow(row)
        row:SetAlpha(alpha)
    end
end
function T.Refresh(reuseSpells)
    if not T.initialized or not CursiveForeverFrame or locked() or T.preparing then return end
    T.preparing=true
    local ok,err=pcall(function()
        local c=config(reuseSpells)
        if not T.applied or T.applied.signature~=c.signature then apply(c);T.applied=c end
    end)
    if not ok then
        deactivate();T.applied=nil;preparedSpells=nil
        T.lastError=readable(err) and tostring(err) or "unreadable error"
        if not T.warned then T.warned=true;say("CLICK_FAILED") end
    else T.lastError=nil end
    T.preparing=nil
    CF.RelayoutTrackerFrame()
end

-- Resolve a cast recipient from a click dispatched right now, or from a unique
-- public name/GUID match. Cache by cast ID so the planner and performance paths
-- agree regardless of event-handler order. Ambiguous names stay unconfirmed.
function CF.ResolveCastRecipient(targetName,castID,spellID)
    if not T.active and not T.dispatch then return nil end
    if not readable(castID) or type(castID)~="string" or not readable(spellID) or type(spellID)~="number" then return nil end
    if T.recipients[castID] then return T.recipients[castID] end
    local r={at=GetTime()}
    T.recipients[castID]=r
    if not readable(targetName) or type(targetName)~="string" or targetName=="" then return r end
    local d=T.dispatch
    if d and d.ids[spellID] and d.name==targetName and guid(d.unit)==d.guid then
        r.unit,r.guid,r.clicked=d.unit,d.guid,true
        return r
    end
    local seen,count={},0
    local function consider(unit)
        if call(UnitCanAttack,"player",unit)~=true or call(UnitIsDeadOrGhost,unit)~=false
            or call(UnitName,unit)~=targetName then return end
        local key=guid(unit)
        if not key then count=count+1;return end
        if not seen[key] then seen[key]=true;count=count+1;r.unit,r.guid=unit,key end
    end
    consider("target");consider("focus");consider("mouseover");consider("pettarget")
    for i=1,8 do consider("boss"..i) end
    for _,row in ipairs(CF.GetExperimentalRows()) do
        if row.unit and not row.offscreen then consider(row.unit) end
    end
    if count~=1 then r.unit,r.guid=nil,nil end
    return r
end
function CF.GetCastRecipient(castID)
    return readable(castID) and type(castID)=="string" and T.recipients[castID] or nil
end
function CF.GetSuggestionRows()
    if not T.active then return CF.GetExperimentalRows() end
    local result={}
    for _,row in ipairs(T.rows) do
        if T.holders[row.cfClickRole]:IsShown() then result[#result+1]=row end
    end
    for _,row in ipairs(CF.GetExperimentalRows()) do
        if not T.Represents(row) then result[#result+1]=row end
    end
    return result
end
function T.Report()
    return "Cursive click casting "..(CF.TrackerTraceVersion or "1.9.1").."\nactive="..tostring(T.active==true).." roles="..T.VisibleCount()
        .." locked="..tostring(locked()).." view="..CF.GetTrackerView()
        .."\n"..(T.lastError or "No preparation error recorded.")
        .."\n"..(T.lastAuraError or "No aura refresh error recorded.")
end
SLASH_CURSIVECLICK1="/cfclick"
SlashCmdList.CURSIVECLICK=function(input)
    local cmd=(input or ""):lower():match("^%s*(%S*)")
    if cmd=="report" then
        for line in T.Report():gmatch("[^\n]+") do if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) end end
    elseif cmd=="on" or cmd=="off" then CF.SetClickCastingEnabled(cmd=="on")
    else say("CLICK_COMMANDS") end
end
local events=CreateFrame("Frame")
T.events=events
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","SPELLS_CHANGED","UNIT_AURA","UNIT_HEALTH","UNIT_MAXHEALTH","RAID_TARGET_UPDATE"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_LOGIN" then T.initialized=true;T.Refresh()
    elseif event=="PLAYER_REGEN_DISABLED" then
        -- Stop dragging before lockdown can leave a click surface in motion.
        T.moving=nil
    elseif event=="PLAYER_REGEN_ENABLED" then T.StopMoving();T.Refresh()
    elseif event=="PLAYER_ENTERING_WORLD" or event=="SPELLS_CHANGED" then
        T.Refresh();T.RefreshAuras()
    elseif T.active then
        if event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_FOCUS_CHANGED" then
            T.RefreshAuras();CF.RelayoutTrackerFrame()
        elseif event=="UNIT_AURA" then T.RefreshAuras(unit);T.RefreshVisuals()
        else T.RefreshVisuals() end
    end
end)
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    if T.moving then
        if locked() then T.moving=nil else
            local m=T.moving
            local x,y=GetCursorPosition()
            T.root:ClearAllPoints()
            T.root:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",m.left+(x-m.x)/m.scale,m.top+(y-m.y)/m.scale)
        end
    end
    elapsed=elapsed+dt;if elapsed<.2 then return end;elapsed=0
    local now=GetTime()
    for id,r in pairs(T.recipients) do if now-r.at>25 then T.recipients[id]=nil end end
    if T.active then T.RefreshVisuals() end
    if T.initialized and not locked() then T.Refresh(true) end
end)
