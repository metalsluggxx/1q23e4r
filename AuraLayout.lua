local _, addon = ...
local CF = addon and addon.CF
if not CF then return end

-- Declarative displays only: no aura reads, visibility inspection or timer
-- arithmetic. Blizzard owns aura assignment, presence, icons and countdowns.
local MAX_SLOTS, SLOT_SIZE, SLOT_STEP = 8, 34, 38
local ROW_STEP = 50
local ROW_BOTTOM, ROW_GAP = 4, 2
local PORTRAIT_CURSE_WIDTH, PORTRAIT_CURSE_OFFSET = 26, 24
-- Existing room after the aura anchor, keeping four units before the border.
local MAIN_STRIP_WIDTHS = { standard=174, compact=172, minimal=177 }
local OTHER_GAP, OTHER_WIDTH, OTHER_HEIGHT = 8, 40, 50
local OTHER_TIME = {gap=1,height=9,fontSize=8}
-- Each small row uses 14 icon + 1 gap + 9 time units. A two-unit
-- separator makes 24 + 2 + 24 = the main icon's 50-unit time band.
local function baseIconTop()
    -- Reserve the existing review label/number band only for enabled suggestions.
    return CF.ExperimentalEnabled and CF.ExperimentalEnabled() and 14 or 4
end
local function iconTop()
    return baseIconTop()+(CF.GetStandardRowPadding and CF.GetStandardRowPadding() or 0)
end
local supportKeys = {
    curse_weakness=true, curse_tongues=true,
    curse_recklessness=true, curse_exhaustion=true,
    curse_elements=true,
}
supportKeys = (CF.Client and CF.Client.supportKeys) or supportKeys
local defaultKeys = { "corruption", "agony", "immolate" }
local blankIcon = "Interface\\Icons\\INV_Misc_QuestionMark"

local de = {
    AURA_VEIL_OPACITY="Deckkraft der Ablaufanimation: %d%%",
    AURA_APPEARANCE_NOTE="Abdunklung laufender Symbole: 0% ohne Schleier, 100% deckend. Matrix-Zahlen und DoT-Balken bleiben unverändert.",
    AURA_APPEARANCE_PENDING="Neue Deckkraft nach UI-Neuladen aktiv. Übernehmen ist außerhalb des Kampfes möglich.",
    AURA_APPEARANCE_APPLY="Übernehmen und UI neu laden",
    AURA_LAYOUT_OPEN="DoT-Anordnung einstellen",
    AURA_LAYOUT_TITLE="DoT-Anordnung",
    AURA_LAYOUT_MODE="Sortierung:",
    AURA_LAYOUT_EXPIRATION="Nach Ablauf",
    AURA_LAYOUT_FIXED="Feste Reihenfolge",
    AURA_LAYOUT_FIXED_TIP="Verwendet deine festgelegte Zauberreihenfolge.",
    AURA_LAYOUT_EXPIRATION_TIP="Zeigt die Effekte mit der kürzesten Restlaufzeit zuerst.",
    AURA_LAYOUT_MODE_TIP="Diese Auswahl gilt für Standard und Lebensbalken. Matrix und DoT-Balken verwenden feste Positionen.",
    AURA_LAYOUT_ORDER_PENDING="Die Änderung wartet, bis erhaltene Gegnerdaten sicher umgestellt werden können.",
    AURA_LAYOUT_HEALTHBAR_EXPIRATION_UNAVAILABLE="Die Ablaufsortierung konnte für einen Gegner nicht eingerichtet werden. Seine Lebensbalkenanzeige verwendet vorerst feste Positionen.",
    AURA_LAYOUT_STANDARD_EXPIRATION_UNAVAILABLE="Die kompakte Ablaufsortierung konnte nicht aktiviert werden. Standard verwendet vorerst die bisherige Effektleiste.",
    AURA_LAYOUT_NOTE="Bis zu acht Hauptplätze wählen; Pfeile ändern ihre Reihenfolge. Standard zeigt alle Hauptplätze nebeneinander und wird ab dem fünften breiter statt höher; Matrix zeigt Spalten, DoT-Balken die Liste von oben nach unten, Lebensbalken Symbole rechts neben dem Balken. Vier weitere Effekte erscheinen kleiner in zwei Reihen, bei DoT-Balken am Porträt. Die Zauberfilter gelten weiterhin.",
    AURA_LAYOUT_PORTRAIT="Unterstützende Flüche am Porträt",
    AURA_LAYOUT_PORTRAIT_NOTE="Eigene Schwäche, Sprachen, Tollkühnheit, Erschöpfung und Elemente rechts am Porträt, in der Lebensbalkenansicht rechts am Balken, mit getrennten Zeiten. Der Fluchwächter bleibt unabhängig davon einstellbar.",
    AURA_LAYOUT_COUNT="%d / 8 feste Plätze",
    AURA_LAYOUT_LIMIT="Höchstens acht feste Plätze auswählen.",
    AURA_LAYOUT_RESET="Reihenfolge zurücksetzen",
    AURA_LAYOUT_SAVED="Die Reihenfolge bestimmt auch die DoT-Vorschlagspriorität. Nicht fest platzierte DoTs folgen danach. Gespeichert je Charakter; freie Plätze sind kein Aura-Nachweis.",
    AURA_LAYOUT_UNAVAILABLE="Feste Plätze konnten nicht aktiviert werden. Die Anzeige bleibt nach Ablauf sortiert.",
    AURA_LAYOUT_SUPPORT_UNAVAILABLE="Flüche bleiben in der Effektleiste; die Porträtanzeige konnte nicht aktiviert werden.",
    AURA_LAYOUT_MATRIX_UNAVAILABLE="Matrix konnte nicht aktiviert werden. Standard bleibt verfügbar.",
    AURA_LAYOUT_MATRIX_DEFERRED="Matrix konnte nicht vollständig eingerichtet werden. Standard wird aktiviert, sobald erhaltene Gegnerdaten sicher umgestellt werden können.",
    AURA_LAYOUT_BARS_UNAVAILABLE="Balken konnten nicht aktiviert werden. Standard bleibt verfügbar.",
    AURA_LAYOUT_BARS_DEFERRED="Balken konnten nicht vollständig eingerichtet werden. Standard wird aktiviert, sobald erhaltene Gegnerdaten sicher umgestellt werden können.",
}
local en = {
    AURA_VEIL_OPACITY="Duration sweep opacity: %d%%",
    AURA_APPEARANCE_NOTE="Darkens active icons: 0% removes the veil, 100% is opaque. Matrix numbers and DoT bars are unchanged.",
    AURA_APPEARANCE_PENDING="New opacity takes effect after reloading the UI. Apply while out of combat.",
    AURA_APPEARANCE_APPLY="Apply and reload UI",
    AURA_LAYOUT_OPEN="Configure DoT layout",
    AURA_LAYOUT_TITLE="DoT layout",
    AURA_LAYOUT_MODE="Order:",
    AURA_LAYOUT_EXPIRATION="Expiring first",
    AURA_LAYOUT_FIXED="Fixed order",
    AURA_LAYOUT_FIXED_TIP="Uses your configured spell order.",
    AURA_LAYOUT_EXPIRATION_TIP="Shows effects with the shortest remaining time first.",
    AURA_LAYOUT_MODE_TIP="This choice applies to Standard and Health bars. Matrix and DoT bars use fixed positions.",
    AURA_LAYOUT_ORDER_PENDING="The change waits until retained enemy data can be switched safely.",
    AURA_LAYOUT_HEALTHBAR_EXPIRATION_UNAVAILABLE="Expiration sorting could not be initialized for an enemy. Its Health bars display temporarily uses fixed positions.",
    AURA_LAYOUT_STANDARD_EXPIRATION_UNAVAILABLE="Compact expiration sorting could not be initialized. Standard temporarily uses its previous effect strip.",
    AURA_LAYOUT_NOTE="Select up to eight main slots; use the arrows to change their order. Standard keeps all main slots on one line and grows wider after the fourth instead of taller; Matrix uses columns, DoT bars follows priority downward, and Health bars places icons to the right. Four other enabled effects appear in two smaller rows, beside the portrait in DoT bars. Spell filters still apply.",
    AURA_LAYOUT_PORTRAIT="Utility curses by the portrait",
    AURA_LAYOUT_PORTRAIT_NOTE="Your Weakness, Tongues, Recklessness, Exhaustion and Elements beside the portrait, or beside the bar in Health bars view, with separate timers. Configure the Curse Watcher independently.",
    AURA_LAYOUT_COUNT="%d / 8 fixed slots",
    AURA_LAYOUT_LIMIT="Select no more than eight fixed slots.",
    AURA_LAYOUT_RESET="Reset slot order",
    AURA_LAYOUT_SAVED="This order also sets DoT suggestion priority. DoTs without a fixed slot follow afterwards. Saved per character; empty slots do not prove aura absence.",
    AURA_LAYOUT_UNAVAILABLE="Fixed slots could not be enabled. Effects remain sorted by expiration.",
    AURA_LAYOUT_SUPPORT_UNAVAILABLE="Curses remain in the effect strip; the portrait display could not be enabled.",
    AURA_LAYOUT_MATRIX_UNAVAILABLE="Matrix could not be enabled. Standard remains available.",
    AURA_LAYOUT_MATRIX_DEFERRED="Matrix could not be fully initialized. Standard will be activated as soon as retained enemy data can be switched safely.",
    AURA_LAYOUT_BARS_UNAVAILABLE="Bars could not be enabled. Standard remains available.",
    AURA_LAYOUT_BARS_DEFERRED="Bars could not be fully initialized. Standard will be activated as soon as retained enemy data can be switched safely.",
}
for key, value in pairs(de) do CF.L_DE[key] = value end
for key, value in pairs(en) do CF.L_EN[key] = value end

function CF.InitializeAuraLayout()
    local db = CursiveForeverDB
    db.auraOrderMode = db.auraOrderMode == "fixed" and "fixed" or "expiration"
    if type(db.portraitCurses) ~= "boolean" then db.portraitCurses = true end
end

function CF.GetAuraOrderMode()
    return CursiveForeverDB and CursiveForeverDB.auraOrderMode == "fixed" and "fixed" or "expiration"
end

function CF.GetAuraLayoutCatalog()
    local result = {}
    for _, spell in ipairs(CF.GetClassFilterCatalog()) do
        result[#result+1] = spell
    end
    return result
end

function CF.NormalizeAuraSlotKeys(keys)
    if CF.Client and CF.Client.MapAuraSlotKeys then keys=CF.Client.MapAuraSlotKeys(keys) end
    local valid, seen, result = {}, {}, {}
    for _, spell in ipairs(CF.GetAuraLayoutCatalog()) do valid[spell.key] = true end
    if type(keys) ~= "table" then return result end
    for _, key in ipairs(keys) do
        if type(key) == "string" and valid[key] and not seen[key] then
            seen[key] = true; result[#result+1] = key
            if #result == MAX_SLOTS then break end
        end
    end
    return result
end

function CF.GetAuraSlotKeys()
    local settings = CF.GetPerformanceCharacterSettings()
    if settings.auraSlotKeys ~= nil then return CF.NormalizeAuraSlotKeys(settings.auraSlotKeys) end
    if CF.Client and CF.Client.defaultSlots then return CF.NormalizeAuraSlotKeys(CF.Client.defaultSlots[CF.GetPerformanceClassFile()] or {}) end
    if CF.GetPerformanceClassFile() == "WARLOCK" then return CF.NormalizeAuraSlotKeys(defaultKeys) end
    local keys = {}
    for _, effect in ipairs(CF.GetPerformanceProfile()) do keys[#keys+1] = effect.key end
    local result = CF.NormalizeAuraSlotKeys(keys)
    while #result > 4 do table.remove(result) end
    return result
end

function CF.WantsPortraitCurses(mode)
    mode = mode or (CursiveForeverDB and CursiveForeverDB.targetDisplayMode) or "minimal"
    return CursiveForeverDB and CursiveForeverDB.portraitCurses ~= false
        and CF.GetPerformanceClassFile() == "WARLOCK"
        and (mode == "compact" or mode == "minimal")
        and not CF.portraitCursesUnavailable
end

local function fixedSlotCount()
    if not CF.AreTrackerExtrasEnabled() then return #CF.GetAuraSlotKeys() end
    if (CF.GetAuraOrderMode() == "fixed" or (CF.IsMatrixView and CF.IsMatrixView())
        or (CF.IsBarsView and CF.IsBarsView())
        or (CF.IsHealthbarView and CF.IsHealthbarView())) and not CF.auraSlotsUnavailable then
        return #CF.GetAuraSlotKeys()
    end
    if CF.GetAuraOrderMode() == "expiration" and not CF.standardExpirationUnavailable
        and not CF.auraSlotsUnavailable then
        return #CF.GetAuraSlotKeys()
    end
    return 0
end

local function fixedWidth(count)
    return (math.max(1,math.min(count,MAX_SLOTS))-1)*SLOT_STEP + SLOT_SIZE
end

function CF.GetAuraLayoutIconCenter()
    if CF.IsHealthbarView and CF.IsHealthbarView() then return CF.GetHealthbarIconCenter() end
    if CF.IsBarsView and CF.IsBarsView() then return CF.GetBarsIconCenter() end
    if CF.IsMatrixView and CF.IsMatrixView() then return CF.GetMatrixIconCenter() end
    return iconTop() + SLOT_SIZE/2
end

local function baseColumns(mode)
    mode = mode or (CursiveForeverDB and CursiveForeverDB.targetDisplayMode) or "minimal"
    local support = CF.ShouldShowUtilityCurse(mode)
    local count = fixedSlotCount()
    local size = support and count > 0 and 30 or 38
    if mode == "minimal" then
        -- Equal four-unit clearances, measured from visible element edges.
        -- The one-unit divider has its own width, so both sides stay equal.
        local left, gap = 5, 4
        -- A native "1 min" label can be 28 units wide under an 18-unit
        -- icon. Measure clearances from that full footprint, not the icon.
        local curseX = left + size + gap + 5
        local healthX = support and (curseX + 18 + 5 + gap) or (left + size + gap)
        return {portraitLeft=left,portraitSize=size,supportX=curseX,
            healthX=healthX,auraX=healthX+70+gap+1+gap}
    end
    local offset = CF.GetAuraLayoutPortraitOffset(mode)
    return {portraitLeft=13+(38-size)/2,portraitSize=size,
        supportX=13+(38-size)/2+size+6,
        healthX=(mode=="standard" and 246 or 154)+offset,
        auraX=(mode=="standard" and 345 or 242)+offset}
end

function CF.GetAuraLayoutPortraitOffset(mode)
    return CF.ShouldShowUtilityCurse(mode) and PORTRAIT_CURSE_OFFSET or 0
end

local function baseRowHeight()
    local count = fixedSlotCount()
    -- Main slots share one horizontal band. Only the legacy fallback strip
    -- (no configured main slots) retains its existing two-line capacity.
    local lines = count > 0 and 1 or 2
    return baseIconTop()+lines*ROW_STEP+ROW_BOTTOM+ROW_GAP
end
function CF.GetStandardRowPadding()
    local base = baseRowHeight()
    local height = CF.ResolveTrackerHeight and CF.ResolveTrackerHeight(base,base-2,"standard") or base
    return math.max(0,(height-base)/2)
end
function CF.GetAuraLayoutRowHeight()
    if CF.IsHealthbarView and CF.IsHealthbarView() then return CF.GetHealthbarRowHeight() end
    if CF.IsBarsView and CF.IsBarsView() then return CF.GetBarsRowHeight() end
    if CF.IsMatrixView and CF.IsMatrixView() then return CF.GetMatrixRowHeight() end
    local base = baseRowHeight()
    return CF.ResolveTrackerHeight and CF.ResolveTrackerHeight(base,base-2,"standard") or base
end

local function baseExtraWidth(mode)
    local count = fixedSlotCount()
    mode = mode or (CursiveForeverDB and CursiveForeverDB.targetDisplayMode) or "minimal"
    local portraitOffset = CF.GetAuraLayoutPortraitOffset(mode)
    local shift = mode == "minimal" and (baseColumns(mode).auraX-144-portraitOffset) or 0
    if count == 0 then return portraitOffset+shift end
    local available = MAIN_STRIP_WIDTHS[mode] or MAIN_STRIP_WIDTHS.standard
    -- Reuse the empty part of the existing strip before adding any width.
    return portraitOffset + math.max(0,fixedWidth(count)+OTHER_GAP+OTHER_WIDTH-available) + shift
end

-- The ordinary Standard presentation keeps icon pitch and native flow
-- intact. Width changes belong to its public health/text column; unused
-- trailing strip space may contract before squeezing that column.
local function standardMode(mode)
    mode = mode or (CursiveForeverDB and CursiveForeverDB.targetDisplayMode)
    return (mode == "minimal" or mode == "compact") and mode or "standard"
end
local function baseHealthWidth(mode)
    return mode == "standard" and 82 or mode == "compact" and 72 or 70
end
local function standardBaseWidth(mode)
    local preview = CF.ExperimentalWidth and CF.ExperimentalWidth() or 0
    if not CF.AreTrackerExtrasEnabled() then
        return baseColumns(mode).auraX+fixedWidth(math.max(1,#CF.GetAuraSlotKeys()))+16+preview
    end
    return (mode == "standard" and 535 or mode == "compact" and 430 or 337)+baseExtraWidth(mode)+preview
end
local function standardTrailingSlack(mode)
    if not CF.AreTrackerExtrasEnabled() then return 0 end
    local count = fixedSlotCount()
    if count == 0 then return 0 end
    local available = MAIN_STRIP_WIDTHS[mode] or MAIN_STRIP_WIDTHS.standard
    return math.max(0,available-fixedWidth(count)-OTHER_GAP-OTHER_WIDTH)
end
function CF.GetStandardRowWidth(mode)
    mode = standardMode(mode)
    local base = standardBaseWidth(mode)
    local minimum = base-baseHealthWidth(mode)+70-standardTrailingSlack(mode)
    return CF.ResolveTrackerWidth and CF.ResolveTrackerWidth(base,minimum,"standard") or base
end
function CF.GetStandardHealthWidth(mode)
    mode = standardMode(mode)
    return math.max(70,baseHealthWidth(mode)+CF.GetStandardRowWidth(mode)-standardBaseWidth(mode))
end
function CF.GetAuraLayoutColumns(mode)
    mode = standardMode(mode)
    local columns = baseColumns(mode)
    columns.healthWidth = CF.GetStandardHealthWidth(mode)
    columns.auraX = columns.auraX+columns.healthWidth-baseHealthWidth(mode)
    return columns
end
function CF.GetAuraLayoutExtraWidth(mode)
    mode = standardMode(mode)
    return baseExtraWidth(mode)+CF.GetStandardRowWidth(mode)-standardBaseWidth(mode)
end

local function changed()
    if CF.ApplyAuraLayoutToAllRows then CF.ApplyAuraLayoutToAllRows() end
    if CF.RefreshAuraLayoutOptions then CF.RefreshAuraLayoutOptions() end
    if CF.Experimental and CF.Experimental.RefreshSettings then CF.Experimental.RefreshSettings() end
end

local function hasRetainedRows()
    for _, row in ipairs(CF.GetExperimentalRows and CF.GetExperimentalRows() or {}) do
        if row.unit and row.offscreen and row.cfRetainedAuras then return true end
    end
    return false
end

function CF.SetAuraOrderMode(mode)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    mode = mode == "fixed" and "fixed" or "expiration"
    if mode == CF.GetAuraOrderMode() then
        CF.pendingAuraOrderMode = nil
        if CF.RefreshAuraLayoutOptions then CF.RefreshAuraLayoutOptions() end
        return true
    end
    -- Standard and Health bars use distinct containers for fixed and sorted
    -- groups. Their retained data cannot be copied when a unit is unavailable.
    local orderedView = not ((CF.IsMatrixView and CF.IsMatrixView()) or (CF.IsBarsView and CF.IsBarsView()))
    if orderedView and hasRetainedRows() then
        CF.pendingAuraOrderMode = mode
        if CF.RefreshAuraLayoutOptions then CF.RefreshAuraLayoutOptions() end
        return false
    end
    CF.pendingAuraOrderMode = nil
    CursiveForeverDB.auraOrderMode = mode
    changed()
    return true
end

function CF.ApplyPendingAuraOrderMode()
    local mode = CF.pendingAuraOrderMode
    if not mode or not CursiveForeverDB or hasRetainedRows() then return false end
    CF.pendingAuraOrderMode = nil
    CursiveForeverDB.auraOrderMode = mode
    if CF.RefreshAuraLayoutOptions then CF.RefreshAuraLayoutOptions() end
    if CF.Experimental and CF.Experimental.RefreshSettings then CF.Experimental.RefreshSettings() end
    -- The main row-layout boundary applies the new presentation after this
    -- return. Do not recurse into that boundary from here.
    return true
end

function CF.SetPortraitCurses(enabled)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    CursiveForeverDB.portraitCurses = enabled == true
    changed()
end

function CF.SetAuraSlotEnabled(key, enabled)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    local keys, found = CF.GetAuraSlotKeys()
    for i, current in ipairs(keys) do if current == key then found = i end end
    if enabled and not found then
        if #keys >= MAX_SLOTS or #CF.NormalizeAuraSlotKeys({key}) == 0 then return false end
        keys[#keys+1] = key
    elseif not enabled and found then table.remove(keys, found) end
    CF.GetPerformanceCharacterSettings().auraSlotKeys = keys
    changed()
    return true
end

function CF.MoveAuraSlot(key, direction)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if direction ~= -1 and direction ~= 1 then return end
    local keys = CF.GetAuraSlotKeys()
    for i, current in ipairs(keys) do
        local other = i + direction
        if current == key and other >= 1 and other <= #keys then
            keys[i], keys[other] = keys[other], keys[i]
            CF.GetPerformanceCharacterSettings().auraSlotKeys = keys
            changed(); return
        end
    end
end

local function familyIDs(spell)
    local ids = {}
    for _, id in ipairs(spell.ids) do ids[id] = true end
    local class = CF.GetPerformanceClassFile()
    local learned = CF.filterSpellRanks and CF.filterSpellRanks[class]
    for id in pairs(learned and learned[spell.key] or {}) do ids[id] = true end
    return ids
end

local function enabled(spell, context)
    local settings = CF.GetClassFilterStorage(CF.GetPerformanceClassFile())[spell.key]
    return not settings or settings[context] ~= false
end

local function merge(into, from)
    for id in pairs(from) do into[id] = true end
end

local function newContainer(row, width, height)
    local c = (CF.Client and CF.Client.CreateAuraContainer(row)) or CreateFrame("AuraContainer", nil, row, "CustomAuraContainerTemplate")
    c:SetSize(width, height)
    c:SetFrameLevel(row:GetFrameLevel()+4)
    if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("TOPLEFT") end
    if c.SetFlowLayoutMaximumLineSize then c:SetFlowLayoutMaximumLineSize(width) end
    if c.SetFlowLayoutGrowthDirection then c:SetFlowLayoutGrowthDirection(1, -1) end
    c:SetUnit("none")
    return c
end

local function addGroup(container, key, size, maxCount, layout, timeStyle)
    assert(container.AddAuraGroup and container.SetAuraGroupCandidateFilters)
    container:AddAuraGroup(key, "HARMFUL|PLAYER", {
        maxFrameCount=maxCount,
        initializeFrame=function(button) CF.InitAuraButton(button, size, timeStyle) end,
        candidateFilters={includeSpellIDs={}},
        layout=layout or {elementWidth=size,elementHeight=size,elementSpacing=2,lineSpacing=14},
    })
    local method = (CF.Client and CF.Client.sortMethod) or AuraContainerSortMethod or (Enum and Enum.AuraContainerSortMethod)
    local direction = (CF.Client and CF.Client.sortDirection) or AuraContainerSortDirection or (Enum and Enum.AuraContainerSortDirection)
    if container.SetAuraGroupSortMethod and method and direction then
        container:SetAuraGroupSortMethod(key, method.ExpirationOnly, direction.Normal)
    end
end

local function retireFixedCache(cache)
    if not cache or not cache.container then return end
    pcall(cache.container.Hide,cache.container)
    pcall(cache.container.SetUnit,cache.container,"none")
end

local function sortedStyle(style)
    return style == "healthbar_expiration" or style == "standard_expiration"
end

local function buildFixedCache(row, count, style)
    local cache = {slots={},placeholders={},anchors={},labels={},style=style,capacity=count}
    local stage = style..":container"
    local ok, err = pcall(function()
        if sortedStyle(style) then
            local healthbar = style == "healthbar_expiration"
            local width = healthbar and CF.GetHealthbarSlotsWidth(count) or fixedWidth(count)
            local height = ROW_STEP
            cache.container = newContainer(row,width,height)
            cache.container:Hide()
            local method = (CF.Client and CF.Client.sortMethod) or AuraContainerSortMethod or (Enum and Enum.AuraContainerSortMethod)
            local direction = (CF.Client and CF.Client.sortDirection) or AuraContainerSortDirection or (Enum and Enum.AuraContainerSortDirection)
            assert(cache.container.SetFlowLayoutMaximumLineSize,"native aura flow unavailable")
            assert(cache.container.SetAuraGroupSortMethod and method and method.ExpirationOnly ~= nil
                and direction and direction.Normal ~= nil,"native expiration sorting unavailable")
            stage = style..":mainEffects"
            -- All selection and order are native. No aura values, assigned
            -- buttons or remaining times are read or retained by this code.
            addGroup(cache.container,"mainEffects",SLOT_SIZE,count,
                {elementWidth=SLOT_SIZE,elementHeight=SLOT_SIZE,elementSpacing=SLOT_STEP-SLOT_SIZE,lineSpacing=16})
            return
        end
        local matrix = style == "matrix"
        local bars = style == "bars"
        local size = bars and 16 or matrix and 28 or SLOT_SIZE
        local width = bars and CF.GetBarsSlotsWidth(count) or matrix and CF.GetMatrixSlotsWidth(count) or fixedWidth(count)
        local height = bars and CF.GetBarsSlotsHeight(count) or matrix and 28 or ROW_STEP
        cache.container = newContainer(row,width,height)
        cache.container:Hide()
        assert(cache.container.AddAuraSlot and cache.container.SetAuraSlotCandidateFilters
            and cache.container.SetAuraSlotEnabled,"native aura slots unavailable")
        -- These ordinary frames belong to the addon. Their parent preserves
        -- the active container's visibility, while their anchors use the row
        -- rather than any geometry controlled by the native aura system.
        cache.anchorRoot = CreateFrame("Frame",nil,cache.container)
        cache.anchorRoot:SetAllPoints(row)
        cache.anchorRoot:SetFrameLevel(row:GetFrameLevel()+4)
        for index=1,count do
            stage = style..":slot:"..index
            local anchor = CreateFrame("Frame",nil,cache.anchorRoot)
            anchor:SetSize(bars and width or size,size)
            anchor:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
            cache.anchors[index] = anchor
            local placeholder = CreateFrame("Frame",nil,anchor)
            placeholder:SetAllPoints(anchor)
            placeholder.icon = placeholder:CreateTexture(nil,"BACKGROUND")
            if bars then
                placeholder.icon:SetPoint("TOPLEFT",anchor,"TOPLEFT",0,0)
                placeholder.icon:SetSize(size,size)
            else placeholder.icon:SetAllPoints() end
            placeholder.icon:SetTexCoord(.08,.92,.08,.92)
            placeholder.icon:SetAlpha(.16)
            local rim = placeholder:CreateTexture(nil,"BORDER")
            rim:SetPoint("BOTTOMLEFT"); rim:SetPoint("BOTTOMRIGHT"); rim:SetHeight(1)
            rim:SetColorTexture(.38,.28,.12,.65)
            placeholder:Hide()
            cache.placeholders[index] = placeholder
            local level = placeholder:GetFrameLevel()+1
            if bars then
                -- Labels describe configured slots, not queried aura data.
                -- Their addon-owned overlay can be updated and resized while
                -- the native aura buttons remain inaccessible and untouched.
                local overlay = CreateFrame("Frame",nil,anchor)
                overlay:SetAllPoints(anchor)
                overlay:SetFrameLevel(level+5)
                overlay:EnableMouse(false)
                local label = overlay:CreateFontString(nil,"OVERLAY","GameFontNormal")
                label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
                label:SetPoint("LEFT",anchor,"LEFT",22,0)
                label:SetPoint("RIGHT",anchor,"RIGHT",-42,0)
                label:SetHeight(14)
                label:SetJustifyH("LEFT")
                label:SetWordWrap(false)
                label:SetTextColor(.94,.87,.69,1)
                label:Hide()
                cache.labels[index] = label
            end
            -- Capture this cache's immutable presentation. The engine may
            -- initialize a slot later, after the active view has changed.
            local initializeMatrix = matrix
            local initializeBars = bars
            local slotAnchor = anchor
            cache.container:AddAuraSlot("fixed"..index,"HARMFUL|PLAYER",{
                candidateFilters={includeSpellIDs={}},
                initializeFrame=function(frame)
                    if initializeBars then CF.InitAuraButton(frame,nil,{bars=true})
                    elseif initializeMatrix then CF.InitAuraButton(frame,28,{matrix=true})
                    else CF.InitAuraButton(frame) end
                    if initializeBars then frame:SetAllPoints(slotAnchor)
                    else frame:SetPoint("TOPLEFT",slotAnchor,"TOPLEFT",0,0) end
                    frame:SetFrameLevel(level)
                    -- No frame or child reference escapes this callback.
                end,
            })
            cache.slots[index] = true
        end
    end)
    if not ok then
        retireFixedCache(cache)
        return nil,stage..": "..tostring(err)
    end
    return cache
end

local function buildOtherCache(row,style)
    local container
    local ok, err = pcall(function()
        local matrix = style == "matrix"
        local width,height = OTHER_WIDTH,OTHER_HEIGHT
        if matrix then width,height = CF.GetMatrixExtraSize() end
        if style == "bars" then width,height = CF.GetBarsExtraSize() end
        container = newContainer(row,width,height)
        container:Hide()
        -- Each cache captures its initializer style. Native buttons may be
        -- initialized later, after the active presentation has changed.
        if matrix then
            addGroup(container,"otherEffects",14,4,
                {elementWidth=44,elementHeight=14,elementSpacing=4,lineSpacing=2},{matrixExtra=true})
        elseif style == "bars" then
            addGroup(container,"otherEffects",14,4,
                {elementWidth=14,elementHeight=14,elementSpacing=18,lineSpacing=12},OTHER_TIME)
        else
            addGroup(container,"otherEffects",14,4,
                {elementWidth=14,elementHeight=14,elementSpacing=6,lineSpacing=12},OTHER_TIME)
        end
    end)
    if not ok then
        if container then pcall(container.Hide,container); pcall(container.SetUnit,container,"none") end
        return nil,"otherEffects: "..tostring(err)
    end
    return {container=container,style=style}
end

local function ensureFixed(row,state,count,style)
    style = style or "standard"
    local caches = state.fixedCaches or {}
    -- Existing addon-owned state may already hold the Standard presentation.
    -- No native button is inspected or imported from it.
    if not state.fixedCaches and state.fixed then
        local previousStyle = state.fixedStyle or "standard"
        caches[previousStyle] = {container=state.fixed,slots=state.slots or {},
            placeholders=state.placeholders or {},anchors={},style=previousStyle}
    end
    state.fixedCaches = caches
    local otherCaches = state.otherCaches or {}
    if not state.otherCaches and state.others then
        local previousStyle = state.otherStyle or state.fixedStyle or "standard"
        otherCaches[previousStyle] = {container=state.others,style=previousStyle}
    end
    state.otherCaches = otherCaches
    local cache = caches[style]
    local nextCache
    if not cache or (sortedStyle(style) and cache.capacity ~= count)
        or (not sortedStyle(style) and #cache.slots < count) then
        local err
        nextCache, err = buildFixedCache(row,count,style)
        if not nextCache then error(err) end
    end
    local otherCache = otherCaches[style]
    if not otherCache then
        local err
        otherCache, err = buildOtherCache(row,style)
        if not otherCache then
            retireFixedCache(nextCache)
            error(err)
        end
    end
    -- Commit both native presentations together. A failed extra group must
    -- not retire the currently working main or extra effects container.
    if nextCache then
        if cache then retireFixedCache(cache) end
        cache = nextCache
        caches[style] = cache
    end
    otherCaches[style] = otherCache
    if state.fixed and state.fixed ~= cache.container then
        retireFixedCache({container=state.fixed})
    end
    if state.others and state.others ~= otherCache.container then
        retireFixedCache({container=state.others})
    end
    state.fixed, state.slots, state.placeholders = cache.container,cache.slots,cache.placeholders
    state.others = otherCache.container
    state.fixedStyle, state.otherStyle = style, style
end

local function layoutFixedCache(row,state,mode)
    if not state.fixedActive then return end
    local matrix = state.fixedStyle == "matrix"
    local bars = state.fixedStyle == "bars"
    -- Health bars share the Standard icon style. Fixed slots use ordinary
    -- addon-owned anchors; the sorted group owns its horizontal flow itself.
    local healthbar = CF.IsHealthbarView and CF.IsHealthbarView() or false
    local top = bars and CF.GetBarsTop() or matrix and CF.GetMatrixIconCenter()-14 or iconTop()
    local x = bars and CF.GetBarsAuraX() or matrix and CF.GetMatrixAuraX() or CF.GetAuraLayoutColumns(mode).auraX
    if healthbar then top,x = CF.GetHealthbarTop(),CF.GetHealthbarAuraX() end
    local count = state.renderedSlotCount or #CF.GetAuraSlotKeys()
    state.fixed:ClearAllPoints(); state.fixed:SetPoint("TOPLEFT",row,"TOPLEFT",x,-top)
    state.fixed:SetSize(bars and CF.GetBarsSlotsWidth(count) or matrix and CF.GetMatrixSlotsWidth(count) or fixedWidth(count),
        bars and CF.GetBarsSlotsHeight(count) or matrix and 28 or ROW_STEP)
    if state.fixedStyle == "standard_expiration" then
        local width = fixedWidth(count)
        state.fixed:SetSize(width,ROW_STEP)
        state.fixed:SetFlowLayoutMaximumLineSize(width)
    end
    if healthbar then
        local width = CF.GetHealthbarSlotsWidth(count)
        state.fixed:SetSize(width,ROW_STEP)
        if state.fixedStyle == "healthbar_expiration" then
            state.fixed:SetFlowLayoutMaximumLineSize(width)
        end
    end
    local cache = state.fixedCaches and state.fixedCaches[state.fixedStyle or "standard"]
    for index,anchor in ipairs(cache and cache.anchors or {}) do
        local offsetX = matrix and CF.GetMatrixSlotPosition(index) or (index-1)*SLOT_STEP
        local offsetY = 0
        if bars then
            offsetX,offsetY = CF.GetBarsSlotPosition(index)
            anchor:SetSize(CF.GetBarsSlotsWidth(count),16)
        end
        if healthbar then offsetX,offsetY = CF.GetHealthbarSlotPosition(index) end
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT",row,"TOPLEFT",x+offsetX,-top-offsetY)
        local label = cache and cache.labels and cache.labels[index]
        if label then
            local placeholder = cache.placeholders[index]
            label:SetShown(index <= count and placeholder and placeholder.cfLayoutEnabled
                and (not CF.GetBarsShowSpellNames or CF.GetBarsShowSpellNames()) or false)
        end
    end
    if state.others then
        if bars then
            local extraX,extraY = CF.GetBarsExtraPosition()
            state.others:ClearAllPoints()
            state.others:SetPoint("TOPLEFT",row,"TOPLEFT",extraX,-extraY)
            return
        end
        local width = matrix and CF.GetMatrixSlotsWidth(count) or fixedWidth(count)
        if healthbar then width = CF.GetHealthbarSlotsWidth(count) end
        local extraTop = matrix and CF.GetMatrixIconCenter()-15 or top
        state.others:ClearAllPoints()
        state.others:SetPoint("TOPLEFT",row,"TOPLEFT",x+width+OTHER_GAP,-extraTop)
    end
end

local function ensureSupport(row, state)
    if not state.support then
        -- One personal utility curse with its own native countdown.
        state.support = newContainer(row, PORTRAIT_CURSE_WIDTH, 30)
        addGroup(state.support, "supportCurses", 18, 1)
    end
end

local function warnOnce(key, flag)
    if CF[flag] then return end
    CF[flag] = true
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd8b15aCursive Forever:|r "..CF.T(key)) end
end

local function healthbarExpirationFailed(err,state)
    CF.healthbarExpirationLastError = tostring(err)
    if state then state.healthbarExpirationFailed = true end
    -- A failure in this new presentation must not disable other rows' working
    -- native caches, especially those still displaying retained offscreen data.
    warnOnce("AURA_LAYOUT_HEALTHBAR_EXPIRATION_UNAVAILABLE","healthbarExpirationWarned")
end

function CF.UpdateAuraLayoutUnit(row, unit)
    if row.offscreen and row.cfRetainedAuras then return end
    local s = row.cfAuraLayout
    row.auraContainer:SetUnit(s and (s.fixedActive or s.matrixBlocked or s.barsBlocked) and "none" or unit)
    if not s then return end
    if s.fixed then s.fixed:SetUnit(s.fixedActive and unit or "none") end
    if s.others then s.others:SetUnit(s.fixedActive and unit or "none") end
    if s.support then s.support:SetUnit(s.supportActive and unit or "none") end
end

function CF.RefreshAuraLayoutContainers(row)
    if row.offscreen and row.cfRetainedAuras then return end
    local s = row.cfAuraLayout
    if not s then return end
    for _, key in ipairs({"fixed","others","support"}) do
        local c = s[key]
        if c and c.UpdateAllAuras then pcall(c.UpdateAllAuras,c) end
    end
end

local function rowGeometry(row, mode, support)
    support = support and CF.AreTrackerExtrasEnabled()
    -- Aura/filter refreshes also reach this boundary without the main window
    -- relayout. Keep their geometry in the selected presentation as well.
    local restorePresentation = row.cfMatrixOwnStyle or row.cfBarsOwnStyle or row.cfHealthbarOwnStyle
    if CF.IsHealthbarView and CF.IsHealthbarView() then
        CF.LayoutHealthbarRow(row)
        return
    end
    if CF.RestoreHealthbarRowStyle then CF.RestoreHealthbarRowStyle(row) end
    if CF.IsBarsView and CF.IsBarsView() then
        if CF.RestoreMatrixRowStyle then CF.RestoreMatrixRowStyle(row) end
        CF.LayoutBarsRow(row)
        return
    end
    if CF.RestoreBarsRowStyle then CF.RestoreBarsRowStyle(row) end
    if CF.IsMatrixView and CF.IsMatrixView() then
        CF.LayoutMatrixRow(row)
        return
    end
    if CF.RestoreMatrixRowStyle then CF.RestoreMatrixRowStyle(row) end
    local height = CF.GetAuraLayoutRowHeight()
    local top, center = iconTop(), CF.GetAuraLayoutIconCenter()
    local portraitOffset = CF.GetAuraLayoutPortraitOffset(mode)
    -- All dimensions are addon-owned layout constants, not native geometry.
    local columns = CF.GetAuraLayoutColumns(mode)
    local healthX = columns.healthX
    local healthWidth = columns.healthWidth
    row.healthAbs:SetWidth(healthWidth)
    row.healthPct:SetWidth(healthWidth)
    if row.healthBar then row.healthBar:SetSize(healthWidth-2,10) end
    row.healthAbs:ClearAllPoints(); row.healthAbs:SetPoint("TOPLEFT",row,"TOPLEFT",healthX,-center+15)
    row.healthPct:ClearAllPoints(); row.healthPct:SetPoint("BOTTOMLEFT",row,"TOPLEFT",healthX,-center-15)
    if row.healthBar then
        row.healthBar:ClearAllPoints(); row.healthBar:SetPoint("BOTTOMLEFT",row,"TOPLEFT",healthX+1,-center-13)
    end
    local auraX = columns.auraX
    row.auraContainer:ClearAllPoints(); row.auraContainer:SetPoint("TOPLEFT",row,"TOPLEFT",auraX,-top)
    row.name:ClearAllPoints(); row.name:SetPoint("LEFT",row,"TOPLEFT",(mode=="standard" and 38 or 57)+portraitOffset,-center)
    row.targetLabel:ClearAllPoints(); row.targetLabel:SetPoint("LEFT",row,"TOPLEFT",198,-center)
    row.healthDivider:ClearAllPoints(); row.healthDivider:SetPoint("LEFT",row,"TOPLEFT",auraX-(mode=="minimal" and 5 or 10),-center)
    if mode ~= "standard" then
        -- Preserve portrait sizes; align the single curse with its upper edge.
        local count = fixedSlotCount()
        local portraitSize = support and count > 0 and 30 or 38
        local portraitInset = (38-portraitSize)/2
        row.portraitRing:SetSize(portraitSize,portraitSize)
        row.portrait:SetSize(portraitSize-4,portraitSize-4)
        row.portraitRing:ClearAllPoints()
        row.portraitRing:SetPoint("LEFT",row,"TOPLEFT",columns.portraitLeft,-center)
        local portraitTop = center-portraitSize/2
        -- Keep the existing overlaid raid symbol inside the shorter row.
        row.raidMarker:ClearAllPoints()
        row.raidMarker:SetPoint("TOPLEFT",row.portraitRing,"TOPLEFT",mode=="minimal" and -3 or -5,math.min(5,portraitTop-2))
        local state = row.cfAuraLayout
        if state and state.support then
            state.support:ClearAllPoints()
            state.support:SetPoint("TOPLEFT",row,"TOPLEFT",columns.supportX,-portraitTop)
        end
    else
        row.raidMarker:ClearAllPoints(); row.raidMarker:SetPoint("LEFT",row,"TOPLEFT",12,-center)
    end
    row:SetHeight(height-2)
    if restorePresentation and CF.LayoutExecuteIndicator then
        CF.LayoutExecuteIndicator(row,healthX-portraitOffset,healthWidth)
    end
end

local function displaySignature(context, mode, keys)
    local forced = (CF.IsMatrixView and CF.IsMatrixView()) or (CF.IsBarsView and CF.IsBarsView())
    local order = forced and "fixed" or CF.GetAuraOrderMode()
    local parts={context,order,table.concat(keys,","),tostring(CF.WantsPortraitCurses(mode))}
    for _,spell in ipairs(CF.GetClassFilterCatalog()) do
        parts[#parts+1]=spell.key..(enabled(spell,context) and ":1" or ":0")
    end
    return table.concat(parts,"|")
end

local function matrixFailed(err, failedState)
    CF.matrixViewLastError = tostring(err)
    CF.matrixViewUnavailable = true
    CF.matrixFallbackRefreshPending = true
    if failedState then failedState.matrixFailed,failedState.matrixBlocked = true,true end
    local retainedMatrix = false
    for _, tracked in ipairs(CF.GetExperimentalRows and CF.GetExperimentalRows() or {}) do
        local state = tracked.cfAuraLayout
        if tracked.unit and tracked.offscreen and tracked.cfRetainedAuras and state
            and state.fixedActive and state.fixedStyle == "matrix" then
            retainedMatrix = true; break
        end
    end
    if retainedMatrix then
        -- A different native cache cannot reconstruct retained aura data.
        -- Keep its headers and geometry until the queued fallback is safe.
        CF.matrixFallbackDeferred = true
        CF.pendingTrackerView = "standard"
    else
        CF.matrixFallbackDeferred = nil
        CF.pendingTrackerView = nil
        if CursiveForeverDB then CursiveForeverDB.trackerView = "standard" end
    end
    if CF.RefreshTrackerViewControl then CF.RefreshTrackerViewControl() end
    if retainedMatrix then warnOnce("AURA_LAYOUT_MATRIX_DEFERRED","matrixDeferredWarned")
    else warnOnce("AURA_LAYOUT_MATRIX_UNAVAILABLE","matrixViewWarned") end
end

local function barsFailed(err, failedState)
    CF.barsViewLastError = tostring(err)
    CF.barsViewUnavailable = true
    CF.barsFallbackRefreshPending = true
    if failedState then failedState.barsFailed,failedState.barsBlocked = true,true end
    local retainedBars = false
    for _, tracked in ipairs(CF.GetExperimentalRows and CF.GetExperimentalRows() or {}) do
        local state = tracked.cfAuraLayout
        if tracked.unit and tracked.offscreen and tracked.cfRetainedAuras and state
            and state.fixedActive and state.fixedStyle == "bars" then
            retainedBars = true; break
        end
    end
    if retainedBars then
        CF.barsFallbackDeferred = true
        CF.pendingTrackerView = "standard"
    else
        CF.barsFallbackDeferred = nil
        CF.pendingTrackerView = nil
        if CursiveForeverDB then CursiveForeverDB.trackerView = "standard" end
    end
    if CF.RefreshTrackerViewControl then CF.RefreshTrackerViewControl() end
    if retainedBars then warnOnce("AURA_LAYOUT_BARS_DEFERRED","barsDeferredWarned")
    else warnOnce("AURA_LAYOUT_BARS_UNAVAILABLE","barsViewWarned") end
end

local function standardExpirationFailed(err)
    CF.standardExpirationLastError = tostring(err)
    warnOnce("AURA_LAYOUT_STANDARD_EXPIRATION_UNAVAILABLE","standardExpirationUnavailable")
end

local function configureRow(row, context, mode)
    if CF.PrepareTrackedAuraRefresh then CF.PrepareTrackedAuraRefresh(row) end
    context = context or CF.GetAuraContext()
    mode = mode or CursiveForeverDB.targetDisplayMode
    local s = row.cfAuraLayout or {slots={},placeholders={}}
    row.cfAuraLayout = s
    local keys = CF.GetAuraSlotKeys()
    local signature = displaySignature(context,mode,keys)
    if row.offscreen and row.cfRetainedAuras then
        if s.displaySignature and s.displaySignature ~= signature then
            -- A changed filter/order cannot be rebuilt from unavailable data.
            -- Presentation switches are queued before reaching this path.
            CF.DiscardRetainedAuras(row,"aura_settings_changed")
        else
            rowGeometry(row,mode,CF.WantsPortraitCurses(mode))
            layoutFixedCache(row,s,mode)
            if s.fixedActive then row.auraContainer:Hide() end
            return
        end
    end
    local matrix = CF.IsMatrixView and CF.IsMatrixView() or false
    local bars = CF.IsBarsView and CF.IsBarsView() or false
    local healthbar = CF.IsHealthbarView and CF.IsHealthbarView() or false
    if not healthbar or CF.GetAuraOrderMode() ~= "expiration" then s.healthbarExpirationFailed = nil end
    local standardExpiration = not (matrix or bars or healthbar) and CF.GetAuraOrderMode() == "expiration"
        and not CF.standardExpirationUnavailable
    local fixed = (CF.GetAuraOrderMode() == "fixed" or matrix or bars or healthbar or standardExpiration)
        and #keys > 0 and not CF.auraSlotsUnavailable
    local support = CF.WantsPortraitCurses(mode)
    local byKey = {}
    for _, spell in ipairs(CF.GetClassFilterCatalog()) do byKey[spell.key] = spell end
    s.matrixBlocked = false
    if not CF.matrixViewUnavailable then s.matrixFailed = nil end
    s.barsBlocked = false
    if not CF.barsViewUnavailable then s.barsFailed = nil end
    if fixed then
        local style = bars and "bars" or matrix and "matrix"
            or healthbar and CF.GetAuraOrderMode() == "expiration" and not s.healthbarExpirationFailed
                and "healthbar_expiration" or standardExpiration and "standard_expiration" or "standard"
        local cache = s.fixedCaches and s.fixedCaches[style]
        local otherCache = s.otherCaches and s.otherCaches[style]
        local matrixBlocked = matrix and CF.matrixViewUnavailable and CF.matrixFallbackDeferred
            and (s.matrixFailed or not cache or not otherCache or #cache.slots < #keys)
        local barsBlocked = bars and CF.barsViewUnavailable and CF.barsFallbackDeferred
            and (s.barsFailed or not cache or not otherCache or #cache.slots < #keys)
        if matrixBlocked or barsBlocked then
            -- Another retained Matrix row keeps the global presentation
            -- alive. A failed/new row must not show Standard icons beneath
            -- Matrix headings, or continuously retry the failing builder.
            if barsBlocked then s.barsBlocked,s.barsFailed = true,true
            else s.matrixBlocked,s.matrixFailed = true,true end
            fixed = false
        else
            local ok, err = pcall(ensureFixed,row,s,#keys,style)
            if not ok and style == "standard_expiration" then
                standardExpirationFailed(err)
                fixed,ok = false,true
            elseif not ok and style == "healthbar_expiration" then
                healthbarExpirationFailed(err,s)
                ok,err = pcall(ensureFixed,row,s,#keys,"standard")
            elseif not ok and bars then
                barsFailed(err,s)
                bars = CF.IsBarsView and CF.IsBarsView() or false
                signature = displaySignature(context,mode,keys)
                if CF.barsFallbackDeferred then
                    fixed,ok = false,true
                else
                    s.barsBlocked = false
                    fixed = CF.GetAuraOrderMode() == "fixed" and #keys > 0 and not CF.auraSlotsUnavailable
                    if fixed then ok,err = pcall(ensureFixed,row,s,#keys,"standard") else ok = true end
                end
            elseif not ok and matrix then
                matrixFailed(err,s)
                matrix = CF.IsMatrixView and CF.IsMatrixView() or false
                signature = displaySignature(context,mode,keys)
                if CF.matrixFallbackDeferred then
                    fixed,ok = false,true
                else
                    s.matrixBlocked = false
                    fixed = CF.GetAuraOrderMode() == "fixed" and #keys > 0 and not CF.auraSlotsUnavailable
                    if fixed then ok, err = pcall(ensureFixed,row,s,#keys,"standard") else ok = true end
                end
            end
            if not ok then
                CF.auraLayoutLastError = tostring(err)
                fixed = false
                warnOnce("AURA_LAYOUT_UNAVAILABLE","auraSlotsUnavailable")
            end
        end
    end

    if support then
        local ok, err = pcall(ensureSupport,row,s)
        if not ok then
            CF.portraitCursesLastError = tostring(err)
            support = false
            warnOnce("AURA_LAYOUT_SUPPORT_UNAVAILABLE","portraitCursesUnavailable")
        end
    end
    local filters = CF.BuildSpellCandidateFilters(context)
    local excluded = filters.excludeSpellIDs
    local supportIDs = {}
    if support then
        -- Selected main effects own their place in every view. Only the
        -- remaining utility curses belong to the separate small display.
        local mainKeys = {}
        for _, key in ipairs(keys) do mainKeys[key] = true end
        for key in pairs(supportKeys) do
            local spell = byKey[key]
            if spell and not mainKeys[key] and enabled(spell,context) then merge(supportIDs,familyIDs(spell)) end
        end
        s.support:SetAuraGroupCandidateFilters("supportCurses",{includeSpellIDs=supportIDs})
        merge(excluded,supportIDs)
        if next(supportIDs) then s.support:Show() else s.support:Hide() end
    elseif s.support then s.support:Hide() end
    -- The legacy strip receives only the portrait exclusion. Fixed-slot
    -- exclusions belong to the separate remainder strip, never to both modes.
    if not CF.AreTrackerExtrasEnabled() then
        local mainIDs={}
        for _,key in ipairs(keys) do
            local spell=byKey[key]
            if spell and enabled(spell,context) then merge(mainIDs,familyIDs(spell)) end
        end
        filters.includeSpellIDs=mainIDs
    end
    row.auraContainer:SetAuraGroupCandidateFilters("playerDots",filters)
    s.fixedActive, s.supportActive = fixed, support and next(supportIDs) ~= nil
    if fixed then
        local remainingExcluded = {}
        merge(remainingExcluded,excluded)
        if sortedStyle(s.fixedStyle) then
            local mainIDs = {}
            for _, key in ipairs(keys) do
                local spell = byKey[key]
                if spell and enabled(spell,context) then merge(mainIDs,familyIDs(spell)) end
            end
            s.fixed:SetAuraGroupCandidateFilters("mainEffects",{includeSpellIDs=mainIDs})
            merge(remainingExcluded,mainIDs)
        end
        for i = 1, #s.slots do
            local spell = byKey[keys[i]]
            local active = spell and enabled(spell,context) or false
            local ids = active and familyIDs(spell) or {}
            s.fixed:SetAuraSlotEnabled("fixed"..i,false)
            s.fixed:SetAuraSlotCandidateFilters("fixed"..i,{includeSpellIDs=ids})
            s.fixed:SetAuraSlotEnabled("fixed"..i,active)
            local placeholder = s.placeholders[i]
            if placeholder then
                placeholder.cfLayoutEnabled = active
                if active then placeholder.icon:SetTexture(CF.SafeSpellTexture(spell.ids[1]) or blankIcon) end
                if active and s.fixedStyle ~= "matrix" then placeholder:Show() else placeholder:Hide() end
            end
            local cache = s.fixedCaches and s.fixedCaches[s.fixedStyle]
            local label = cache and cache.labels and cache.labels[i]
            if label then
                local name = spell and spell.fallback or ""
                if spell and CF.AuraLayoutUI and CF.AuraLayoutUI.spellInfo then
                    name = CF.AuraLayoutUI.spellInfo(spell) or name
                end
                label:SetText(name)
                label:SetShown(active and (not CF.GetBarsShowSpellNames or CF.GetBarsShowSpellNames()) or false)
            end
            if active then merge(remainingExcluded,ids) end
        end
        s.others:SetAuraGroupCandidateFilters("otherEffects",{excludeSpellIDs=remainingExcluded})
        s.fixed:Show(); s.others:Show(); row.auraContainer:Hide()
    else
        if s.fixed then s.fixed:Hide() end
        if s.others then s.others:Hide() end
        if s.matrixBlocked or s.barsBlocked then row.auraContainer:Hide() else row.auraContainer:Show() end
    end
    s.displaySignature, s.renderedSlotCount = signature, #keys
    rowGeometry(row,mode,support)
    layoutFixedCache(row,s,mode)
    CF.UpdateAuraLayoutUnit(row,row.cfAuraUnit or "none")
end

function CF.ConfigureRowAuras(row, context, mode)
    local requestedMatrix = CF.IsMatrixView and CF.IsMatrixView() or false
    local requestedBars = CF.IsBarsView and CF.IsBarsView() or false
    local requestedHealthbarExpiration = CF.IsHealthbarView and CF.IsHealthbarView()
        and CF.GetAuraOrderMode() == "expiration"
    local requestedStandardExpiration = not (requestedMatrix or requestedBars
        or (CF.IsHealthbarView and CF.IsHealthbarView())) and CF.GetAuraOrderMode() == "expiration"
    local restorePresentationGeometry = requestedMatrix or requestedBars or row.cfMatrixOwnStyle or row.cfBarsOwnStyle
        or (CF.IsHealthbarView and CF.IsHealthbarView()) or row.cfHealthbarOwnStyle
    local ok, err = pcall(configureRow,row,context,mode)
    local state = row.cfAuraLayout
    if not ok and requestedStandardExpiration and state and state.fixedStyle == "standard_expiration" then
        standardExpirationFailed(err)
        if row.offscreen and row.cfRetainedAuras then
            if CF.ApplyTrackedRowAvailability then CF.ApplyTrackedRowAvailability(row) end
            return false
        end
        ok,err = pcall(configureRow,row,context,mode)
    end
    if not ok and requestedHealthbarExpiration and state and state.fixedStyle == "healthbar_expiration" then
        healthbarExpirationFailed(err,state)
        if row.offscreen and row.cfRetainedAuras then
            if CF.ApplyTrackedRowAvailability then CF.ApplyTrackedRowAvailability(row) end
            return false
        end
        ok,err = pcall(configureRow,row,context,mode)
    end
    if not ok and (requestedMatrix or requestedBars) then
        if requestedBars then barsFailed("configureRow: "..tostring(err),row.cfAuraLayout)
        else matrixFailed("configureRow: "..tostring(err),row.cfAuraLayout) end
        -- An already retained row must keep its native objects and
        -- current presentation. The fallback is queued until it is safe.
        if row.offscreen and row.cfRetainedAuras then
            if CF.ApplyTrackedRowAvailability then CF.ApplyTrackedRowAvailability(row) end
            return false
        end
        ok,err = pcall(configureRow,row,context,mode)
    end
    if ok then
        if CF.ApplyTrackedRowAvailability then CF.ApplyTrackedRowAvailability(row) end
        return true
    end
    -- A beta API mismatch must leave the proven strip available, with its
    -- original user filters and no exclusions for failed auxiliary displays.
    CF.auraLayoutLastError = tostring(err)
    if row.offscreen and row.cfRetainedAuras then CF.DiscardRetainedAuras(row,"layout_api_error") end
    warnOnce("AURA_LAYOUT_UNAVAILABLE","auraSlotsUnavailable")
    CF.portraitCursesUnavailable = true
    local s = row.cfAuraLayout
    if s then
        s.fixedActive, s.supportActive = false, false
        for _, key in ipairs({"fixed","others","support"}) do
            if s[key] then s[key]:Hide(); pcall(s[key].SetUnit,s[key],"none") end
        end
    end
    if row.auraContainer.SetAuraGroupCandidateFilters then
        local fallbackFilters=CF.BuildSpellCandidateFilters(context or CF.GetAuraContext())
        if not CF.AreTrackerExtrasEnabled() then
            local selected={}; for _,key in ipairs(CF.GetAuraSlotKeys()) do selected[key]=true end
            fallbackFilters.includeSpellIDs={}
            for _,spell in ipairs(CF.GetClassFilterCatalog()) do
                if selected[spell.key] and enabled(spell,context or CF.GetAuraContext()) then
                    merge(fallbackFilters.includeSpellIDs,familyIDs(spell))
                end
            end
        end
        pcall(row.auraContainer.SetAuraGroupCandidateFilters,row.auraContainer,"playerDots",fallbackFilters)
    end
    row.auraContainer:Show()
    pcall(row.auraContainer.SetUnit,row.auraContainer,row.cfAuraUnit or "none")
    local laidOut = restorePresentationGeometry
        and pcall(rowGeometry,row,mode or CursiveForeverDB.targetDisplayMode,false)
    if not laidOut then row:SetHeight(CF.GetAuraLayoutRowHeight()-2) end
    if CF.ApplyTrackedRowAvailability then CF.ApplyTrackedRowAvailability(row) end
    return false
end

-- Options are built on demand after the main file has supplied its UI helpers.
function CF.RefreshAuraAppearanceControls()
    if CF.RefreshOptionsPages then CF.RefreshOptionsPages() end
    local f=CF.auraLayoutOptionsFrame
    if not f or not f.veilOpacity then return end
    f.refreshingAppearance=true
    local value=CF.GetAuraVeilOpacity()
    f.veilOpacity:SetValue(value)
    f.veilLabel:SetText(CF.TF("AURA_VEIL_OPACITY",value))
    local pending=CF.HasPendingAuraAppearance()
    f.veilNote:SetText(CF.T(pending and "AURA_APPEARANCE_PENDING" or "AURA_APPEARANCE_NOTE"))
    f.applyAppearance.cfLabel:SetText(CF.T("AURA_APPEARANCE_APPLY"))
    local canApply=CF.CanReloadAuraAppearance()
    f.applyAppearance:SetEnabled(canApply)
    f.applyAppearance:SetAlpha(canApply and 1 or .45)
    f.refreshingAppearance=nil
end

function CF.RefreshAuraLayoutOptions()
    if CF.RefreshOptionsPages then CF.RefreshOptionsPages() end
    local f = CF.auraLayoutOptionsFrame
    if not f then return end
    CF.RefreshAuraAppearanceControls()
    local keys, selected, ordered, byKey = CF.GetAuraSlotKeys(), {}, {}, {}
    for _, spell in ipairs(CF.GetAuraLayoutCatalog()) do byKey[spell.key] = spell end
    for i,key in ipairs(keys) do selected[key]=i; ordered[#ordered+1]=byKey[key] end
    for _,spell in ipairs(CF.GetAuraLayoutCatalog()) do
        if not selected[spell.key] then ordered[#ordered+1]=spell end
    end
    f.title:SetText(CF.T("AURA_LAYOUT_TITLE").." · "..CF.GetClassDisplayName(CF.GetPerformanceClassFile()))
    f.orderLabel:SetText(CF.T("AURA_LAYOUT_MODE"))
    for mode, radio in pairs(f.orderRadios) do
        radio:SetChecked((CF.pendingAuraOrderMode or CF.GetAuraOrderMode())==mode)
        radio.cfLabel:SetText(CF.T(radio.labelKey))
    end
    f.note:SetText(CF.T("AURA_LAYOUT_NOTE")); f.hint:SetText(CF.T("AURA_LAYOUT_SAVED"))
    f.count:SetText(CF.TF("AURA_LAYOUT_COUNT",#keys))
    f.portrait.Text:SetText(CF.T("AURA_LAYOUT_PORTRAIT"))
    f.portrait:SetChecked(CursiveForeverDB.portraitCurses ~= false)
    f.portrait:SetEnabled(CF.GetPerformanceClassFile()=="WARLOCK")
    f.portrait:SetAlpha(CF.GetPerformanceClassFile()=="WARLOCK" and 1 or .4)
    f.portraitNote:SetText(CF.T("AURA_LAYOUT_PORTRAIT_NOTE"))
    for _, row in ipairs(f.rows) do row:Hide() end
    for i, spell in ipairs(ordered) do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Frame",nil,f.child,"BackdropTemplate")
            row:SetSize(650,38); row:SetPoint("TOPLEFT",0,-((i-1)*40))
            row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
            row:SetBackdropColor(i%2==0 and .060 or .040,.034,.025,1)
            row.check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.check:SetSize(26,26); row.check:SetPoint("LEFT",2,0); row.check.Text:SetText("")
            row.check:SetScript("OnClick",function(self)
                if not CF.SetAuraSlotEnabled(row.spellKey,self:GetChecked() and true or false) then
                    self:SetChecked(false); f.count:SetText(CF.T("AURA_LAYOUT_LIMIT"))
                end
            end)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(28,28); row.icon:SetPoint("LEFT",36,0)
            row.icon:SetTexCoord(.08,.92,.08,.92)
            row.label=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            row.label:SetPoint("LEFT",76,0); row.label:SetWidth(366); row.label:SetJustifyH("LEFT")
            row.position=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            row.position:SetPoint("LEFT",462,0); row.position:SetWidth(44)
            row.up=CF.AuraLayoutUI.action(row,"CARDS_MOVE_UP",true)
            row.up:SetSize(42,28); row.up:SetPoint("LEFT",542,0)
            row.down=CF.AuraLayoutUI.action(row,"CARDS_MOVE_DOWN",true)
            row.down:SetSize(42,28); row.down:SetPoint("LEFT",592,0)
            row.up:SetScript("OnClick",function() CF.MoveAuraSlot(row.spellKey,-1) end)
            row.down:SetScript("OnClick",function() CF.MoveAuraSlot(row.spellKey,1) end)
            f.rows[i]=row
        end
        local position=selected[spell.key]
        local name,icon=CF.AuraLayoutUI.spellInfo(spell)
        row.spellKey=spell.key; row.label:SetText(name or spell.fallback)
        row.icon:SetTexture(icon or blankIcon); row.check:SetChecked(position~=nil)
        row.position:SetText(position and tostring(position) or "—")
        row.up:SetEnabled(position~=nil and position>1)
        row.down:SetEnabled(position~=nil and position<#keys)
        row.up:SetAlpha(position~=nil and position>1 and 1 or .35)
        row.down:SetAlpha(position~=nil and position<#keys and 1 or .35)
        row:Show()
    end
    f.child:SetHeight(math.max(1,#ordered*40))
end

function CF.ShowAuraLayoutOptions()
    if CF.OpenOptionsPage then return CF.OpenOptionsPage("combat") end
    local f=CF.auraLayoutOptionsFrame
    if not f then
        f=CreateFrame("Frame","CursiveForeverAuraLayoutOptions",UIParent,"BackdropTemplate")
        CF.auraLayoutOptionsFrame=f; f.rows={}
        f:SetSize(720,600); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(145)
        f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        CF.AuraLayoutUI.backdrop(f,1); CF.AuraLayoutUI.close(f)
        f:SetScript("OnDragStart",function(self) self:StartMoving() end)
        f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        f:SetScript("OnShow",function(self)
            self:SetScale(math.max(.1,math.min(1,(UIParent:GetWidth()-40)/720,(UIParent:GetHeight()-40)/600)))
        end)
        local function text(y,height,font)
            local label=f:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT",18,-y); label:SetSize(676,height)
            label:SetJustifyH("LEFT"); label:SetJustifyV("TOP"); label:SetWordWrap(true)
            return label
        end
        f.title=text(16,24,"GameFontNormalLarge")
        f.orderLabel=text(53,20,"GameFontNormal")
        f.orderLabel:SetWidth(92); f.orderLabel:SetJustifyV("MIDDLE")
        f.orderRadios={}
        for i, choice in ipairs({{mode="fixed",key="AURA_LAYOUT_FIXED"},
            {mode="expiration",key="AURA_LAYOUT_EXPIRATION"}}) do
            local radio=CreateFrame("CheckButton",nil,f,"UIRadioButtonTemplate")
            radio:SetSize(20,20); radio:SetPoint("TOPLEFT",118+(i-1)*182,-53)
            radio.labelKey=choice.key
            radio.cfLabel=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            radio.cfLabel:SetPoint("LEFT",radio,"RIGHT",3,0)
            radio.cfLabel:SetWidth(144); radio.cfLabel:SetJustifyH("LEFT")
            if radio.SetHitRectInsets then radio:SetHitRectInsets(0,-147,0,0) end
            if radio.Text then radio.Text:SetText(""); radio.Text:Hide() end
            radio:SetScript("OnClick",function()
                if CF.GetAuraOrderMode()==choice.mode and not CF.pendingAuraOrderMode then
                    CF.RefreshAuraLayoutOptions()
                else
                    CF.SetAuraOrderMode(choice.mode)
                end
            end)
            radio:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(CF.T(choice.key),1,0.82,0.35)
                GameTooltip:AddLine(CF.T(choice.key.."_TIP"),1,1,1,true)
                GameTooltip:AddLine(CF.T("AURA_LAYOUT_MODE_TIP"),1,1,1,true)
                if CF.pendingAuraOrderMode then
                    GameTooltip:AddLine(CF.T("AURA_LAYOUT_ORDER_PENDING"),1,.82,.35,true)
                end
                GameTooltip:Show()
            end)
            radio:SetScript("OnLeave",function() GameTooltip:Hide() end)
            f.orderRadios[choice.mode]=radio
        end
        f.portrait=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
        f.portrait:SetSize(26,26); f.portrait:SetPoint("TOPLEFT",16,-86)
        f.portrait.Text:SetWidth(640); f.portrait.Text:SetJustifyH("LEFT")
        f.portrait:SetScript("OnClick",function(self) CF.SetPortraitCurses(self:GetChecked() and true or false) end)
        f.portraitNote=text(118,30); f.note=text(156,48)
        f.veilLabel=text(214,20,"GameFontNormalSmall"); f.veilLabel:SetWidth(360)
        f.veilOpacity=CreateFrame("Slider",nil,f,"OptionsSliderTemplate")
        f.veilOpacity:SetPoint("TOPLEFT",26,-240); f.veilOpacity:SetSize(320,18)
        f.veilOpacity:SetMinMaxValues(0,100); f.veilOpacity:SetValueStep(1)
        if f.veilOpacity.SetObeyStepOnDrag then f.veilOpacity:SetObeyStepOnDrag(true) end
        if f.veilOpacity.Low then f.veilOpacity.Low:SetText("0%") end
        if f.veilOpacity.High then f.veilOpacity.High:SetText("100%") end
        if f.veilOpacity.Text then f.veilOpacity.Text:SetText("") end
        f.veilOpacity:SetScript("OnValueChanged",function(_,value)
            if not f.refreshingAppearance then CF.SetAuraVeilOpacity(value) end
        end)
        f.applyAppearance=CF.AuraLayoutUI.action(f,"AURA_APPEARANCE_APPLY")
        f.applyAppearance:SetSize(300,28); f.applyAppearance:SetPoint("TOPLEFT",394,-232)
        f.applyAppearance:SetScript("OnClick",CF.ReloadForAuraAppearance)
        f.veilNote=text(278,30)
        f:RegisterEvent("PLAYER_REGEN_DISABLED"); f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent",CF.RefreshAuraAppearanceControls)
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT",16,-316); f.scroll:SetPoint("BOTTOMRIGHT",-36,80)
        f.child=CreateFrame("Frame",nil,f.scroll); f.child:SetSize(655,1); f.scroll:SetScrollChild(f.child)
        f.hint=text(526,30)
        f.reset=CF.AuraLayoutUI.action(f,"AURA_LAYOUT_RESET")
        f.reset:SetSize(260,28); f.reset:SetPoint("BOTTOMLEFT",18,12)
        f.reset:SetScript("OnClick",function()
            CF.GetPerformanceCharacterSettings().auraSlotKeys=nil; changed()
        end)
        f.count=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
        f.count:SetPoint("BOTTOMRIGHT",-20,20)
        CF.RegisterLocaleUpdater(CF.RefreshAuraLayoutOptions)
        table.insert(UISpecialFrames,"CursiveForeverAuraLayoutOptions")
    end
    CF.RefreshClassSpellRanks()
    if CF.ApplyAuraLayoutToAllRows then CF.ApplyAuraLayoutToAllRows() end
    CF.RefreshAuraLayoutOptions(); f:Show(); f:Raise()
end

function CF.ResetAuraSlotOrder()
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    CF.GetPerformanceCharacterSettings().auraSlotKeys=nil
    changed()
end
