-- Public-aura renderer for Era and MoP. Retail/Forever never execute this
-- backend. No combat-log access, guessed cast timers or native-widget reads.
local _, addon = ...
local client = addon.Client
if not client.classicAuras then return end
local B = { containers={}, scans={}, serial=0, status="idle", rejected=0 }
addon.ClassicAuraBackend = B
local readable, readableTable = client.Readable, client.ReadableTable
local function number(value)
    return readable(value) and type(value)=="number" and value==value
        and value~=math.huge and value~=-math.huge
end
local function guidFor(unit)
    local ok, value = pcall(UnitGUID,unit)
    if ok and readable(value) and type(value)=="string" and value~="" then return value end
end
local function exists(unit)
    local ok, value = pcall(UnitExists,unit)
    return ok and readable(value) and value==true
end
local function snapshot(unit,guid)
    local prior = B.scans[unit]
    if prior and prior.serial==B.serial and prior.guid==guid then return prior.auras,prior.status end
    local api = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    local result, status = {}, "public"
    if type(api)~="function" then status="api_unavailable" else
        local ok = pcall(function()
            for index=1,255 do
                local aura = api(unit,index,"HARMFUL|PLAYER")
                if not readable(aura) then error("protected aura") end
                if aura==nil then return end
                if not readableTable(aura) then error("inaccessible aura") end
                local id,icon,duration,expiration,instance = aura.spellId,aura.icon,aura.duration,aura.expirationTime,aura.auraInstanceID
                if not number(id) or not number(duration) or not number(expiration)
                    or duration<0 or expiration<0 or not readable(icon) or not readable(instance)
                    or (type(icon)~="number" and type(icon)~="string") then error("unreadable aura fields") end
                -- Copy only public values needed for this display. Never save
                -- raw AuraData or infer application from SENT/SUCCEEDED.
                result[#result+1] = { spellId=id, icon=icon, duration=duration,
                    expirationTime=expiration, instance=type(instance)=="number" and instance or index }
            end
            error("aura scan limit") -- a truncated scan is not complete
        end)
        if not ok then result=nil; status="unavailable"; B.rejected=B.rejected+1
        elseif guidFor(unit)~=guid then result=nil; status="identity_changed" end
    end
    if status~="public" then result=nil end
    B.status=status
    B.scans[unit]={serial=B.serial,guid=guid,auras=result,status=status}
    return result,status
end
local function matches(aura,filters)
    filters=filters or {}
    return (not filters.includeSpellIDs or filters.includeSpellIDs[aura.spellId]==true)
        and not (filters.excludeSpellIDs and filters.excludeSpellIDs[aura.spellId])
end
local function secondsText(remaining)
    if remaining>=60 then return string.format("%dm",math.ceil(remaining/60)) end
    if remaining<5 then return string.format("%.1f",math.max(0,remaining)) end
    return tostring(math.ceil(remaining))
end
local function renderButton(button,aura,now)
    if not aura then button.cfAura=nil; button:Hide(); return end
    local permanent=aura.expirationTime==0 or aura.duration==0
    local remaining=permanent and 0 or math.max(0,aura.expirationTime-now)
    if not permanent and remaining<=0 then button.cfAura=nil; button:Hide(); return end
    button.cfAura=aura
    if button.cfIcon then button.cfIcon:SetTexture(aura.icon) end
    if button.cfDurationText then button.cfDurationText:SetText(permanent and "" or secondsText(remaining)) end
    if button.cfDurationBar then
        local bar=button.cfDurationBar
        bar:SetMinMaxValues(0,permanent and 1 or aura.duration)
        local elapsed=Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime
        local reverse=elapsed~=nil and button.cfBarDirection==elapsed
        bar:SetValue(permanent and (reverse and 0 or 1) or (reverse and math.max(0,aura.duration-remaining) or remaining))
    end
    button:Show()
end
local function makeButton(container,initialize)
    local button=CreateFrame("Frame",nil,container)
    button:EnableMouse(false)
    function button:SetIcon(icon) self.cfIcon=icon end
    function button:SetDurationText(text) self.cfDurationText=text end
    function button:SetDurationBar(bar,options)
        self.cfDurationBar=bar;self.cfBarDirection=options and options.direction
    end
    if initialize then initialize(button) end
    button:Hide()
    return button
end
local function render(container)
    local now=GetTime()
    for _,entry in ipairs(container.cfEntries) do
        local chosen={}
        if entry.enabled then
            for _,aura in ipairs(container.cfAuras or {}) do
                if (aura.expirationTime==0 or aura.duration==0 or aura.expirationTime>now) and matches(aura,entry.filters) then
                    chosen[#chosen+1]=aura
                end
            end
        end
        table.sort(chosen,function(a,b)
            local ae=a.expirationTime==0 and math.huge or a.expirationTime
            local be=b.expirationTime==0 and math.huge or b.expirationTime
            if ae~=be then return ae<be end
            if a.spellId~=b.spellId then return a.spellId<b.spellId end
            return a.instance<b.instance
        end)
        for i,button in ipairs(entry.buttons) do renderButton(button,chosen[i],now) end
    end
end
local function layout(container)
    for _,entry in ipairs(container.cfEntries) do
        if not entry.slot then
            local spec=entry.layout
            local w,h=spec.elementWidth or 34,spec.elementHeight or 34
            local gap,line=spec.elementSpacing or 0,spec.lineSpacing or 0
            local width=container.cfLineSize or container:GetWidth()
            local columns=math.max(1,math.floor((width+gap)/(w+gap)))
            for i,button in ipairs(entry.buttons) do
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT",container,"TOPLEFT",((i-1)%columns)*(w+gap),-math.floor((i-1)/columns)*(h+line))
            end
        end
    end
end
local function refresh(container)
    local unit=container.cfUnit
    if not unit or unit=="none" then container.cfAuras=nil;render(container);return end
    local row=container:GetParent()
    local guid=exists(unit) and guidFor(unit) or nil
    if not guid then
        -- Camera loss preserves only this row's already observed public
        -- identity. Fixed target/focus roles must never retain another target.
        if row.cfClickRole or not container.cfGUID or row.guid~=container.cfGUID or not row.unit then
            container.cfAuras=nil
        end
    elseif not row.cfClickRole and row.guid and guid~=row.guid then
        container.cfAuras=nil -- reused nameplate belongs to a different enemy
    else
        if container.cfGUID~=guid then container.cfAuras=nil end
        container.cfGUID=guid
        container.cfAuras,container.cfReadStatus=snapshot(unit,guid)
    end
    render(container)
end
function B.Create(parent)
    local container=CreateFrame("Frame",nil,parent)
    container.cfEntries={};container.cfByKey={};container:EnableMouse(false)
    function container:SetUnit(unit)
        if self.cfUnit~=unit then self.cfAuras=nil;self.cfGUID=nil end
        self.cfUnit=unit
        B.serial=B.serial+1
        refresh(self)
    end
    function container:UpdateAllAuras()
        B.serial=B.serial+1;layout(self);refresh(self)
    end
    local function add(self,key,options,slot)
        assert(not self.cfByKey[key],"Duplicate aura key")
        local entry={filters=options.candidateFilters,layout=options.layout or {},slot=slot,enabled=true,buttons={}}
        self.cfByKey[key]=entry;self.cfEntries[#self.cfEntries+1]=entry
        for i=1,(slot and 1 or options.maxFrameCount or 8) do entry.buttons[i]=makeButton(self,options.initializeFrame) end
        layout(self);render(self)
    end
    function container:AddAuraGroup(key,filter,options)
        assert(filter=="HARMFUL|PLAYER","Unsupported aura filter");add(self,key,options,false)
    end
    function container:AddAuraSlot(key,filter,options)
        assert(filter=="HARMFUL|PLAYER","Unsupported aura filter");add(self,key,options,true)
    end
    function container:SetAuraGroupCandidateFilters(key,filters) self.cfByKey[key].filters=filters;render(self) end
    container.SetAuraSlotCandidateFilters=container.SetAuraGroupCandidateFilters
    function container:SetAuraSlotEnabled(key,enabled) self.cfByKey[key].enabled=enabled==true;render(self) end
    function container:SetAuraGroupSortMethod(key,method,direction)
        assert(self.cfByKey[key] and method==client.sortMethod.ExpirationOnly and direction==client.sortDirection.Normal,"Unsupported aura order")
        render(self)
    end
    function container:SetFlowLayoutAnchorPoint(anchor) assert(anchor=="TOPLEFT") end
    function container:SetFlowLayoutGrowthDirection(x,y) assert(x==1 and y==-1) end
    function container:SetFlowLayoutMaximumLineSize(width) self.cfLineSize=width;layout(self) end
    container:HookScript("OnSizeChanged",function(self) layout(self) end)
    container:HookScript("OnShow",function(self) layout(self);refresh(self) end)
    B.containers[#B.containers+1]=container
    return container
end
-- One bounded updater for all layouts. Shared unit snapshots avoid one scan
-- per icon/container. Dead/cleared rows are unbound by the existing tracker.
local driver=CreateFrame("Frame")
B.driver=driver
driver:RegisterEvent("UNIT_AURA")
driver:SetScript("OnEvent",function(_,_,unit)
    if not readable(unit) or type(unit)~="string" then return end
    B.serial=B.serial+1
    for _,container in ipairs(B.containers) do
        if container.cfUnit==unit and container:IsShown() then refresh(container) end
    end
end)
local elapsed=0
driver:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta
    if elapsed<.10 then return end
    elapsed=0;B.serial=B.serial+1
    -- Discard stale per-unit scans; per-row snapshots own camera retention.
    B.scans={}
    for _,container in ipairs(B.containers) do
        if container:IsShown() and container.cfUnit and container.cfUnit~="none" then refresh(container) end
    end
end)
