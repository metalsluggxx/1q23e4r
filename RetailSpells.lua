local _, addon = ...
local C = addon.Client
if not C or C.edition ~= "Retail" then return end

-- Retail spellbook adaptation only. Never reads an aura or changes a secure
-- button, unit binding, row identity, or any other edition's spell catalogue.
local seeds, order = {}, {}
for _, family in ipairs(C.catalog.WARLOCK) do
    seeds[family.key] = family
    order[#order+1] = family.key
end
local handled = {corruption=true, immolate=true, wither=true, unstable_affliction=true}
local resolved = {}
local witherBase = "corruption"
local witherIDs = {[445468]=true, [445474]=true}

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and C.Readable(value) then return value end
end
local function number(v)
    return C.Readable(v) and type(v)=="number" and v>0 and v<math.huge
end
local function text(v)
    return C.Readable(v) and type(v)=="string" and v~="" and not v:find("[\r\n]")
end
local function name(id)
    return call(C_Spell and C_Spell.GetSpellName, id)
end
local function bank()
    return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
end
local function learned(id)
    if not number(id) then return false end
    if bank() ~= nil and call(C_SpellBook and C_SpellBook.IsSpellInSpellBook,id,bank(),true)==true then return true end
    return call(C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell or IsSpellKnown,id)==true
end
local function active(id)
    return learned(id) and call(C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell,id)==false
end
local function override(id)
    local value = call(C_Spell and C_Spell.GetOverrideSpell,id,0,true)
    return number(value) and value or id
end
local function bookSpell(identifier)
    local api = C_SpellBook
    if not api or type(api.FindSpellBookSlotForSpell)~="function" or bank()==nil then return end
    -- Exclude future and off-spec spells; name lookup finds changed cast IDs.
    local ok, slot, spellBank = pcall(api.FindSpellBookSlotForSpell,identifier,false,true,false,false)
    if not ok or not number(slot) or not C.Readable(spellBank) or spellBank~=bank() then return end
    local info = call(api.GetSpellBookItemInfo,slot,spellBank)
    if not C.ReadableTable(info) or type(info)~="table" then return end
    local id, passive, offSpec, itemType = info.spellID, info.isPassive, info.isOffSpec, info.itemType
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    if not number(id) or not C.Readable(passive) or passive~=false
        or not C.Readable(offSpec) or offSpec~=false or not C.Readable(itemType)
        or spellType==nil or itemType~=spellType then return end
    -- The selected, learned spellbook entry is evidence even when IsSpellKnown
    -- returns false for a talent replacement. No guessed or future cast.
    return id
end
local function resolve(family)
    if not family or family.castable==false then return end
    local candidates = family.castIDs or family.ids
    for _, id in ipairs(candidates) do
        local actual = bookSpell(id)
        if not actual then
            local localized = name(id)
            if text(localized) then actual=bookSpell(localized) end
        end
        if actual then
            local replacement=override(actual)
            if replacement~=actual and active(replacement) then actual=replacement end
            if text(name(actual)) then return actual end
        end
    end
    for _, id in ipairs(candidates) do
        local actual=override(id)
        if active(actual) and text(name(actual)) then return actual end
        if actual~=id and active(id) and text(name(id)) then return id end
    end
    -- Learned same-family variants from the existing spellbook scan are a
    -- final fallback, never restricted to an obsolete castIDs seed.
    local cf=addon.CF
    local ranks=cf and cf.filterSpellRanks and cf.filterSpellRanks.WARLOCK
    local ids={}
    for id in pairs(ranks and ranks[family.key] or {}) do if number(id) then ids[#ids+1]=id end end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local actual=override(id)
        if active(actual) and text(name(actual)) then return actual end
    end
end
local function isWither(id)
    if not number(id) then return false end
    if witherIDs[id] then return true end
    local a,b=name(id),name(445468)
    return text(a) and text(b) and a==b
end
local function copyFamily(original, displayID, extra)
    local family, seen = {}, {}
    for k,v in pairs(original) do family[k]=v end
    family.ids={}
    local function add(id)
        if number(id) and not seen[id] then seen[id]=true;family.ids[#family.ids+1]=id end
    end
    add(displayID)
    for _,id in ipairs(original.ids) do add(id) end
    for _,id in ipairs(extra and extra.ids or {}) do add(id) end
    for _,id in ipairs(extra and extra.castIDs or {}) do add(id) end
    return family
end

function C.MapAuraSlotKeys(keys)
    if type(keys)~="table" then return keys end
    local explicit=false
    for _,key in ipairs(keys) do if key=="wither" then explicit=true end end
    local mapped={}
    for _,key in ipairs(keys) do
        -- An explicitly chosen Wither keeps its saved priority over an older
        -- Corruption/Immolate default. The ordinary normalizer deduplicates.
        if key=="wither" then mapped[#mapped+1]=witherBase
        elseif not (explicit and key==witherBase) then mapped[#mapped+1]=key end
    end
    return mapped
end

function C.RefreshSpellCatalog()
    if call(InCombatLockdown)~=false then return end
    local cf=addon.CF
    if not cf or cf.GetPerformanceClassFile()~="WARLOCK" then return end
    local nextResolved={}
    for key in pairs(handled) do nextResolved[key]=resolve(seeds[key]) end
    local spec=call(GetSpecialization)
    local specID=number(spec) and call(GetSpecializationInfo,spec) or nil
    local baseConfirmed=isWither(nextResolved.immolate) or isWither(nextResolved.corruption)
        or specID==265 or specID==266 or specID==267
    -- Hellcaller replaces Immolate in Destruction, Corruption in Affliction.
    if isWither(nextResolved.immolate) or specID==267 then witherBase="immolate"
    elseif isWither(nextResolved.corruption) or specID==265 then witherBase="corruption" end
    local replacement=nextResolved.wither
    if not isWither(nextResolved[witherBase]) and replacement and isWither(replacement) then
        nextResolved[witherBase]=replacement
    end
    resolved=nextResolved
    local catalog=C.catalog.WARLOCK
    for i=#catalog,1,-1 do catalog[i]=nil end
    for _,key in ipairs(order) do
        if key~="wither" then
            local extra=key==witherBase and seeds.wither or nil
            local family=copyFamily(seeds[key],resolved[key],extra)
            if extra then family.replacementBaseID=seeds[key].castIDs[1] end
            catalog[#catalog+1]=family
        end
    end
    local db=CursiveForeverDB
    if not db then return end
    local settings=cf.GetPerformanceCharacterSettings()
    local old=settings.auraSlotKeys
    local explicit=false
    for _,key in ipairs(old or {}) do if key=="wither" then explicit=true end end
    -- At ADDON_LOADED the specialization/spellbook can still be unavailable.
    -- Keep legacy storage intact until PLAYER_LOGIN can identify the base.
    if explicit and baseConfirmed then settings.auraSlotKeys=cf.NormalizeAuraSlotKeys(old) end
    -- Migrate the old Wither filter once per base spell. Afterwards the shared
    -- slot's own saved checkbox always wins, including across talent changes.
    db.retailWitherFiltersMigrated=db.retailWitherFiltersMigrated or {}
    if baseConfirmed and not db.retailWitherFiltersMigrated[witherBase]
        and (explicit or isWither(resolved[witherBase])) then
        local filters=db.spellFilters
        if filters and type(filters.wither)=="table" then
            local copy={};for k,v in pairs(filters.wither) do copy[k]=v end
            filters[witherBase]=copy
        end
        db.retailWitherFiltersMigrated[witherBase]=true
    end
end

function C.ResolveCastSpell(family,class,ids)
    if class~="WARLOCK" or not handled[family.key] then return false end
    if family.castable==false then return true end
    local id=resolved[family.key]
    if not id and call(InCombatLockdown)==false then id=resolve(seeds[family.key]) end
    if id then
        local localized=name(id)
        if text(localized) then ids[id]=true;return true,localized end
    end
    return true
end

function C.SpellReplacementNote(family)
    if not family.replacementBaseID then return end
    local cf=addon.CF
    local base=name(family.replacementBaseID)
    if not text(base) then base=family.key=="immolate" and "Immolate" or "Corruption" end
    if cf.GetEffectiveLanguage()=="de" then
        return "Gemeinsamer Platz für "..base.." und Welken. Name und Symbol folgen deiner Talentwahl; Auswahl und Reihenfolge bleiben erhalten."
    end
    return "Shared slot for "..base.." and Wither. Name and icon follow your talents; selection and order are preserved."
end

function C.DurationTextOptions(formatter)
    -- Give Blizzard's existing aura duration binding its permanent-duration
    -- text. The native button owns assignment/visibility and distinguishes an
    -- expired finite timer from a zero-length duration. No Lua aura inspection,
    -- guessed lifetime, or replacement of the countdown with a cast estimate.
    if not formatter or not C_DurationUtil or type(C_DurationUtil.CreateDurationTextBinding)~="function" then return end
    local ok, options=pcall(function()
        local binding=C_DurationUtil.CreateDurationTextBinding()
        binding:SetFormatter(formatter)
        binding:SetZeroDurationText("∞")
        return {binding=binding}
    end)
    if ok then return options end
end
