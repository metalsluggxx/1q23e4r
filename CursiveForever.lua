local ADDON_NAME, addon = ...
addon = addon or {}

-- Cursive Forever 1.9.1
--
-- Display policy:
--
-- OUT OF COMBAT:
--   Show only the currently selected hostile target.
--   If there is no hostile target, show nothing.
--
-- IN COMBAT + RAID:
--   Show ALL currently visible hostile nameplate units.
--
-- IN COMBAT + NOT RAID:
--   Show only visible hostile nameplate units for which player or pet
--   is on the threat table.
--
-- Existing:
--   * player-applied harmful auras only
--   * current-target highlighting
--   * no click-to-target

local CF = CreateFrame("Frame")
addon.CF = CF
CF.Client = addon.Client

local MAX_ROWS = 40
local ROWS_PER_COLUMN = 20
local ROW_W_STANDARD = 535
local ROW_W_COMPACT = 430
local ROW_W_MINIMAL = 337
local ROW_H = 44
local TITLE_H = 20
local MIN_BODY_H = 12
local REFRESH_INTERVAL = 0.20

local VERSION = addon.Build and addon.Build.version or "1.9.1"
CF.TrackerTraceVersion = VERSION
local VERSION_LABEL = VERSION .. " - by Leandarh Valinor"
local RELEASE_DATE = addon.Build and addon.Build.releaseDate or "22.10.2026"

-- Client reference reported on 2026-10-17; version and build date confirmed by screenshot.
-- User reports observed gameplay working on 70450; earlier checks retain their original client references.
-- Legacy TESTED_* identifiers are display metadata, not a compatibility assertion.
local TESTED_CLIENT_VERSION = addon.Build and addon.Build.client or "1.60.1"
local TESTED_CLIENT_BUILD = addon.Build and addon.Build.build or "70450"
local TESTED_CLIENT_FLAVOR = "Release x64"
local TESTED_CLIENT_DATE = (addon.Build and addon.Build.referenceOnly) and "Reference; live test pending" or "Oct 15 2026"

-- Pals-for-Life-inspired UI palette:
-- warm near-black/brown base, restrained gold framing,
-- status green/yellow/red reserved for actual state information.
local THEME_BG_R, THEME_BG_G, THEME_BG_B = 0.020, 0.016, 0.011
local THEME_BG_ALT1_R, THEME_BG_ALT1_G, THEME_BG_ALT1_B = 0.050, 0.042, 0.030
local THEME_BG_ALT2_R, THEME_BG_ALT2_G, THEME_BG_ALT2_B = 0.032, 0.027, 0.020
local THEME_HEADER_R, THEME_HEADER_G, THEME_HEADER_B = 0.072, 0.052, 0.029
local THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B = 0.72, 0.54, 0.20
local THEME_GOLD_HI_R, THEME_GOLD_HI_G, THEME_GOLD_HI_B = 0.88, 0.69, 0.30
local THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B = 0.38, 0.28, 0.12
local THEME_ACTIVE_R, THEME_ACTIVE_G, THEME_ACTIVE_B = 0.36, 0.88, 0.42

local MEDIA_PATH = "Interface\\AddOns\\CursiveForever\\Media\\"
local DECOR_RAVEN = MEDIA_PATH .. "RavenMark.tga"
local DECOR_PERFORMANCE_MAIN = MEDIA_PATH .. "PerformanceRavenMain.tga"
local DECOR_PERFORMANCE_ARCHIVE = MEDIA_PATH .. "PerformanceRavenArchive.tga"
local DECOR_PERFORMANCE_COMPACT = MEDIA_PATH .. "PerformanceRavenCompact.tga"
local DECOR_CORNER = MEDIA_PATH .. "CornerRune.tga"
local DECOR_RUNE_GREEN = MEDIA_PATH .. "RuneGreen.tga"
local DECOR_RUNE_RED = MEDIA_PATH .. "RuneRed.tga"
local DECOR_RUNE_PURPLE = MEDIA_PATH .. "RunePurpleSkull.tga"
local DECOR_RUNE_VIOLET = MEDIA_PATH .. "RuneViolet.tga"
local DECOR_RUNE_GOLD = MEDIA_PATH .. "RuneGold.tga"
local DECOR_RUNE_BLUE = MEDIA_PATH .. "RuneBlue.tga"

-- Forever / WoW 12.1 exposes the AuraContainer sorting enums as globals.
-- Keep Enum.* as a compatibility fallback for later client changes.
local CF_AuraSortMethod =
    AuraContainerSortMethod
    or (Enum and Enum.AuraContainerSortMethod)
    or (CF.Client and CF.Client.sortMethod)

local CF_AuraSortDirection =
    AuraContainerSortDirection
    or (Enum and Enum.AuraContainerSortDirection)
    or (CF.Client and CF.Client.sortDirection)

local db
local main
local optionsFrame
local historyFrame
local filterFrame
local curseWatcherOptionsFrame
local curseAlertFrame
local minimapButton
local rows = {}
function CF.GetExperimentalRows() return rows end
local visibleUnits = {}
local unitToRow = {}
local guidToRow = {}

-- Engagement memory must never rely on reusable nameplateN tokens.
-- Normal enemies are tracked by stable GUID. The unit-token fallback exists
-- only for protected/secret-GUID cases and is cleared as soon as that
-- nameplate token disappears.
CF.playerEngagedGUIDs = {}
CF.raidMarkerGUIDCache = CF.raidMarkerGUIDCache or {}
CF.raidMarkerCacheSeen = CF.raidMarkerCacheSeen or {}
CF.raidCurseCastState = CF.raidCurseCastState or {}
local playerEngagedUnits = {}

local refreshElapsed = 0
local UpdateMinimapButtonPosition
local DURATION_FORMATTER = nil
local HEALTH_COLOR_CURVE = nil
local lastAuraContext = nil
local curseTestMode = false

local nameplateWarningBlinkElapsed = 0
local NAMEPLATE_WARNING_PERIOD = 2.20

local function CreateHealthColorCurve()
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then
        return nil
    end

    local curve = C_CurveUtil.CreateColorCurve()

    if curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
        curve:SetType(Enum.LuaCurveType.Step)
    end

    -- Step curve:
    -- 0–24.99%  = red
    -- 25–49.99% = yellow
    -- 50–100%   = green
    curve:AddPoint(0.00, CreateColor(1.00, 0.28, 0.22, 1.00))
    curve:AddPoint(0.25, CreateColor(1.00, 0.82, 0.18, 1.00))
    curve:AddPoint(0.50, CreateColor(0.38, 1.00, 0.46, 1.00))

    return curve
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd8b15a"..(CF.Client and CF.Client.title or "Cursive Forever")..":|r " .. tostring(msg))
end

local function GetTestedClientBuildString()
    return TESTED_CLIENT_VERSION
        .. " (" .. TESTED_CLIENT_BUILD .. ")"
        .. " · " .. TESTED_CLIENT_FLAVOR
        .. (TESTED_CLIENT_DATE ~= "" and (" · " .. TESTED_CLIENT_DATE) or "")
end

-- Known Warlock debuff families. A family may contain more than one spell ID
-- because Blizzard occasionally replaces a spell with a new ID while keeping
-- the same player-facing effect.
--
-- The filter is deliberately EXCLUSION based: unknown/new Forever beta debuffs
-- remain visible until they are added here.
local WARLOCK_DEBUFFS = {
    { key="corruption",            ids={172},             fallback="Verderbnis / Corruption" },
    { key="immolate",              ids={348},             fallback="Feuerbrand / Immolate" },
    { key="agony",                 ids={980},             fallback="Agonie / Agony" },
    { key="doom",                  ids={603},             fallback="Verdammnis / Doom" },
    { key="unstable_affliction",   ids={1219045, 30108},  fallback="Instabiles Gebrechen / Unstable Affliction" },
    { key="siphon_life",           ids={63106},           fallback="Lebensentzug / Siphon Life" },
    { key="wrack",                 ids={1316697},         fallback="Zermürben / Wrack" },
    { key="seed_of_corruption",    ids={27243},           fallback="Saat der Verderbnis / Seed of Corruption" },
    { key="haunt",                 ids={48181},           fallback="Heimsuchung / Haunt" },
    { key="phantom_singularity",   ids={205179},          fallback="Phantomsingularität / Phantom Singularity" },
    { key="vile_taint",            ids={278350},          fallback="Übler Makel / Vile Taint" },
    { key="soul_rot",              ids={386997, 325640},  fallback="Seelenfäule / Soul Rot" },
    { key="wither",                ids={445468},          fallback="Wither" },
    { key="curse_weakness",        ids={702,1108,6205,7646,11707,11708,27224,30909}, fallback="Fluch der Schwäche" },
    { key="curse_tongues",         ids={1714,11719},      fallback="Fluch der Sprachen" },
    { key="curse_recklessness",    ids={704},             fallback="Fluch der Tollkühnheit / Curse of Recklessness" },
    { key="curse_exhaustion",      ids={334275,18223,104223,29539}, fallback="Fluch der Erschöpfung" },
    { key="curse_elements",        ids={440892,1311676,1311677,1311680}, fallback="Fluch der Elemente / Curse of the Elements" },
    -- Target debuffs, not the passive talents or the damage they trigger.
    { key="demonic_brand",         ids={1293696},         fallback="Dämonisches Brandmal / Demonic Brand" },
    { key="shadow_vulnerability",  ids={17794},           fallback="Schattenverwundbarkeit / Shadow Vulnerability" },
    { key="fear",                  ids={5782},            fallback="Furcht / Fear" },
    { key="banish",                ids={710},             fallback="Verbannen / Banish" },
    { key="howl_of_terror",        ids={5484},            fallback="Schreckensgeheul / Howl of Terror" },
    { key="mortal_coil",           ids={6789},            fallback="Todesmantel / Mortal Coil" },
    { key="shadowfury",            ids={30283},           fallback="Schattenfuror / Shadowfury" },
    { key="havoc",                 ids={80240},           fallback="Verwüstung / Havoc" },
    { key="shadow_embrace",        ids={32390},           fallback="Schattenumschlingung / Shadow Embrace" },
    { key="eradication",           ids={196414},          fallback="Auslöschung / Eradication" },
}

-- Banthers Owl-Corner: Balance-Druid debuffs.
-- Multiple classic rank IDs are grouped so the filter keeps working while
-- leveling through the Forever beta.
local DRUID_DEBUFFS = {
    {
        key="moonfire",
        ids={
            8921, 8924, 8925, 8926, 8927, 8928, 8929,
            9833, 9834, 9835, 26987, 26988, 48462, 48463,
            164812
        },
        fallback="Mondfeuer / Moonfire"
    },
    {
        key="insect_swarm",
        ids={5570, 24974, 24975, 24976, 24977, 27013, 48468},
        fallback="Insektenschwarm / Insect Swarm"
    },
    {
        key="rake",
        ids={1822, 1823, 1824, 9904, 27003, 48573, 48574},
        fallback="Krallenhieb / Rake"
    },
    {
        key="rip",
        ids={1079, 9492, 9493, 9752, 9894, 9896, 27008, 49799, 49800},
        fallback="Zerfetzen / Rip"
    },
}

-- Filter families remain separate from the smaller damage/coverage catalogue.
-- Rank IDs learned from the client's spellbook supplement these base IDs.
CF.CLASS_FILTERS = {
    WARLOCK = WARLOCK_DEBUFFS,
    DRUID = DRUID_DEBUFFS,
    PRIEST = {
        {key="shadow_word_pain",ids={589},fallback="Schattenwort: Schmerz / Shadow Word: Pain"},
        {key="devouring_plague",ids={2944},fallback="Verschlingende Seuche / Devouring Plague"},
        {key="holy_fire",ids={14914},fallback="Heiliges Feuer / Holy Fire"},
        {key="mind_flay",ids={15407},fallback="Gedankenschinden / Mind Flay"},
        {key="vampiric_embrace",ids={15286},fallback="Vampirumarmung / Vampiric Embrace"},
        {key="psychic_scream",ids={8122},fallback="Psychischer Schrei / Psychic Scream"},
        {key="shadow_weaving",ids={15258},fallback="Schattenwirken / Shadow Weaving"},
    },
    HUNTER = {
        {key="serpent_sting",ids={1978},fallback="Schlangenbiss / Serpent Sting"},
        {key="black_arrow",ids={3674},fallback="Schwarzer Pfeil / Black Arrow"},
        {key="lacerate_hunter",ids={24118,24119,24120,1299332},fallback="Lacerate"},
        {key="immolation_trap",ids={13795,13797},fallback="Feuerbrandfalle / Immolation Trap"},
        {key="explosive_trap",ids={13813,13812},fallback="Sprengfalle / Explosive Trap"},
        {key="hunters_mark",ids={1130},fallback="Mal des Jägers / Hunter's Mark"},
        {key="viper_sting",ids={3034},fallback="Vipernbiss / Viper Sting"},
        {key="scorpid_sting",ids={3043},fallback="Skorpidstich / Scorpid Sting"},
        {key="concussive_shot",ids={5116},fallback="Erschütternder Schuss / Concussive Shot"},
        {key="wing_clip",ids={2974},fallback="Zurechtstutzen / Wing Clip"},
        {key="freezing_trap",ids={1499,3355},fallback="Eiskältefalle / Freezing Trap"},
        {key="frost_trap",ids={13809,13810},fallback="Frostfalle / Frost Trap"},
        {key="scatter_shot",ids={19503},fallback="Streuschuss / Scatter Shot"},
        {key="wyvern_sting",ids={19386},fallback="Wyverngift / Wyvern Sting"},
    },
    ROGUE = {
        {key="rupture",ids={1943},fallback="Blutung / Rupture"},
        {key="garrote",ids={703},fallback="Erdrosseln / Garrote"},
        {key="deadly_poison",ids={2818},fallback="Tödliches Gift / Deadly Poison"},
        {key="crippling_poison",ids={3409},fallback="Verkrüppelndes Gift / Crippling Poison"},
        {key="mind_numbing_poison",ids={5760},fallback="Gedankenbetäubendes Gift / Mind-numbing Poison"},
        {key="wound_poison",ids={13218},fallback="Wundgift / Wound Poison"},
        {key="expose_armor",ids={8647},fallback="Rüstung schwächen / Expose Armor"},
        {key="cheap_shot",ids={1833},fallback="Fieser Trick / Cheap Shot"},
        {key="kidney_shot",ids={408},fallback="Nierenhieb / Kidney Shot"},
        {key="sap",ids={6770},fallback="Kopfnuss / Sap"},
        {key="blind",ids={2094},fallback="Blenden / Blind"},
        {key="gouge",ids={1776},fallback="Solarplexus / Gouge"},
        {key="hemorrhage",ids={16511},fallback="Blutsturz / Hemorrhage"},
    },
    MAGE = {
        {key="ignite",ids={12654},fallback="Entzünden / Ignite"},
        {key="fireball_burn",ids={133},fallback="Feuerball / Fireball"},
        {key="pyroblast_burn",ids={11366},fallback="Pyroschlag / Pyroblast"},
        {key="polymorph",ids={118},fallback="Verwandlung / Polymorph"},
        {key="frost_nova",ids={122},fallback="Frostnova / Frost Nova"},
        {key="frostbolt",ids={116},fallback="Frostblitz / Frostbolt"},
        {key="cone_of_cold",ids={120},fallback="Kältekegel / Cone of Cold"},
        {key="counterspell",ids={2139,18469},fallback="Gegenzauber / Counterspell"},
    },
    WARRIOR = {
        {key="rend",ids={772},fallback="Verwunden / Rend"},
        {key="deep_wounds",ids={12721,12834},fallback="Tiefe Wunden / Deep Wounds"},
        {key="demoralizing_shout",ids={1160},fallback="Demoralisierender Ruf / Demoralizing Shout"},
        {key="thunder_clap",ids={634},fallback="Donnerknall / Thunder Clap"},
        {key="sunder_armor",ids={7386},fallback="Rüstung zerreißen / Sunder Armor"},
        {key="hamstring",ids={1715},fallback="Kniesehne / Hamstring"},
        {key="mortal_strike",ids={12294},fallback="Tödlicher Stoß / Mortal Strike"},
        {key="disarm",ids={676},fallback="Entwaffnen / Disarm"},
        {key="piercing_howl",ids={12323},fallback="Durchdringendes Heulen / Piercing Howl"},
        {key="intimidating_shout",ids={5246},fallback="Drohruf / Intimidating Shout"},
    },
    SHAMAN = {
        {key="flame_shock",ids={8050},fallback="Flammenschock / Flame Shock"},
        {key="frost_shock",ids={8056},fallback="Frostschock / Frost Shock"},
        {key="earth_shock",ids={8042},fallback="Erdschock / Earth Shock"},
        {key="earthbind",ids={2484,3600},fallback="Erdbindung / Earthbind"},
        {key="frostbrand",ids={8034},fallback="Frostbrand / Frostbrand Attack"},
        {key="stormstrike",ids={17364},fallback="Sturmschlag / Stormstrike"},
    },
    PALADIN = {
        {key="consecration",ids={26573},fallback="Weihe / Consecration"},
        {key="judgement_crusader",ids={21183},fallback="Richturteil des Kreuzfahrers / Judgement of the Crusader"},
        {key="judgement_wisdom",ids={20186},fallback="Richturteil der Weisheit / Judgement of Wisdom"},
        {key="judgement_light",ids={20185},fallback="Richturteil des Lichts / Judgement of Light"},
        {key="judgement_justice",ids={20184},fallback="Richturteil der Gerechtigkeit / Judgement of Justice"},
        {key="hammer_of_justice",ids={853},fallback="Hammer der Gerechtigkeit / Hammer of Justice"},
        {key="turn_undead",ids={2878},fallback="Untote vertreiben / Turn Undead"},
        {key="repentance",ids={20066},fallback="Buße / Repentance"},
    },
}

-- Triggered debuffs are not necessarily listed in the player's spellbook.
-- These Classic rank candidates are admitted only after their localized names
-- match a seed of this family in the running client; unrelated IDs are ignored.
CF.FILTER_RANK_CANDIDATES = {
    WARLOCK = {
        curse_recklessness={7658,7659,11717,27226},
        shadow_vulnerability={17797,17798,17799,17800},
    },
    HUNTER = {
        immolation_trap={14298,14299,14300,14301,14302,14303,14304,14305},
        explosive_trap={14314,14315,14316,14317},
        freezing_trap={14308,14309,14310,14311},
    },
    ROGUE = {
        deadly_poison={2819,11353,11354,25349},
        crippling_poison={11201}, mind_numbing_poison={8692,11398},
        wound_poison={13222,13223,13224},
    },
    PALADIN = {
        judgement_crusader={20188,20300,20301,20302,20303},
        judgement_light={20344,20345,20346}, judgement_wisdom={20354,20355},
        consecration={20116,20922,20923,20924},
    },
}

-- Preserve the existing families and their saved keys; extend Druid coverage.
for _, entry in ipairs({
    {key="lacerate",ids={414644,1235826,1235827},fallback="Lacerate"},
    {key="faerie_fire",ids={770,16857},fallback="Feenfeuer / Faerie Fire"},
    {key="entangling_roots",ids={339},fallback="Wucherwurzeln / Entangling Roots"},
    {key="hibernate",ids={2637},fallback="Winterschlaf / Hibernate"},
    {key="demoralizing_roar",ids={99},fallback="Demoralisierendes Gebrüll / Demoralizing Roar"},
    {key="bash",ids={5211},fallback="Hieb / Bash"},
}) do
    DRUID_DEBUFFS[#DRUID_DEBUFFS+1] = entry
end
-- The active Classic/Forever Siphon Life family coexists with its old seed.
for _, entry in ipairs(WARLOCK_DEBUFFS) do
    if entry.key == "siphon_life" then table.insert(entry.ids,1,18265) end
end

-- Profiles replace seeds before defaults, rank learning or filter caches exist.
if CF.Client and CF.Client.catalog then
    CF.CLASS_FILTERS = CF.Client.catalog
    WARLOCK_DEBUFFS = CF.CLASS_FILTERS.WARLOCK or {}
    DRUID_DEBUFFS = CF.CLASS_FILTERS.DRUID or {}
    CF.FILTER_RANK_CANDIDATES = CF.Client.rankCandidates or {}
end

function CF.GetClassFilterCatalog(classFile)
    if not classFile then local _, current = UnitClass("player"); classFile = current end
    return CF.CLASS_FILTERS[classFile] or {}
end

function CF.GetClassFilterStorage(classFile)
    if not db then return {} end
    if classFile == "WARLOCK" then return db.spellFilters end
    if classFile == "DRUID" then return db.owlFilters end
    db.classSpellFilters = db.classSpellFilters or {}
    db.classSpellFilters[classFile] = db.classSpellFilters[classFile] or {}
    return db.classSpellFilters[classFile]
end

function CF.GetClassDisplayName(classFile)
    local names = CF.GetEffectiveLanguage() == "de" and {
        WARLOCK="Hexenmeister", DRUID="Druide", PRIEST="Priester", HUNTER="Jäger",
        ROGUE="Schurke", MAGE="Magier", WARRIOR="Krieger", SHAMAN="Schamane", PALADIN="Paladin",
    } or {
        WARLOCK="Warlock", DRUID="Druid", PRIEST="Priest", HUNTER="Hunter",
        ROGUE="Rogue", MAGE="Mage", WARRIOR="Warrior", SHAMAN="Shaman", PALADIN="Paladin",
    }
    local extra = CF.GetEffectiveLanguage() == "de" and {DEATHKNIGHT="Todesritter",MONK="Mönch",DEMONHUNTER="Dämonenjäger",EVOKER="Rufer"}
        or {DEATHKNIGHT="Death Knight",MONK="Monk",DEMONHUNTER="Demon Hunter",EVOKER="Evoker"}
    return names[classFile] or extra[classFile] or classFile or "?"
end

local RAID_CURSES = {
    {
        key = "curse_weakness",
        ids = {702,1108,6205,7646,11707,11708,27224,30909},
        fallback = "Fluch der Schwäche",
        english = "Curse of Weakness",
        durationSeconds = 120,
    },
    {
        key = "curse_tongues",
        ids = {1714,11719},
        fallback = "Fluch der Sprachen",
        english = "Curse of Tongues",
        durationSeconds = 30,
    },
    {
        key = "curse_exhaustion",
        ids = {334275,18223,104223,29539},
        fallback = "Fluch der Erschöpfung",
        english = "Curse of Exhaustion",
        durationSeconds = 12,
    },
    {
        key = "curse_elements",
        ids = {440892,1311676,1311677,1311680},
        fallback = "Fluch der Elemente",
        english = "Curse of the Elements",
        durationSeconds = 300,
    },
}

if CF.Client and CF.Client.raidCurses then RAID_CURSES = CF.Client.raidCurses end

local function GetRaidCurseDef(key)
    for _, curse in ipairs(RAID_CURSES) do
        if curse.key == key then
            return curse
        end
    end
    return nil
end

local FILTER_CONTEXTS = { "solo", "dungeon", "raid" }

local TRACKED_DEBUFF_SPELL_IDS = {}

local function AddTrackedSpellIDs(catalog)
    for _, spell in ipairs(catalog) do
        for _, spellID in ipairs(spell.ids) do
            TRACKED_DEBUFF_SPELL_IDS[spellID] = true
        end
    end
end

for _, catalog in pairs(CF.CLASS_FILTERS) do AddTrackedSpellIDs(catalog) end

local DEFAULTS = {
    hidden = false,
    showMinimap = true,
    showTargetOutOfCombat = true,
    hideWindowOutOfCombat = false,
    auraVeilOpacity = 58,
    minimapAngle = 220,
    minimapRadius = 105,
    lockFrame = false,
    frameScale = 1.00,
    -- Standard uses the proven portrait-only geometry, historically "minimal".
    -- Keep that internal key stable; a future smaller layout needs its own key.
    targetDisplayMode = "minimal",
    trackerView = "standard",
    barsShowSpellNames = true,
    windowTransparency = 0,
    trackerExtraIcons = true,
    hideTrackerFrame = false,
    healthDisplayMode = "bar",
    executeMode = "auto",
    showHeader = true,
    optionsDecorStyle = 2,
    optionsDesign = "FULL",
    uiLanguage = "auto",
    raidCurseWatcherEnabled = false,
    raidCurseKey = "none",
    raidCurseWarnSeconds = 5,
    performanceEnabled = true,
    performanceMinSeconds = 45,
    priorityRaidMarker = 8,
}

-- ------------------------------------------------------------
-- DISPLAY LANGUAGE / LOCALIZATION
-- ------------------------------------------------------------
-- uiLanguage:
--   "auto" = follow the WoW client language (deDE -> German, everything else English)
--   "de"   = force German UI
--   "en"   = force English UI
--
-- Spell/aura detection remains client/API based and is deliberately independent
-- from the Cursive display language.

CF.localeUpdaters = CF.localeUpdaters or {}

CF.L_DE = {
    DETAIL_OBSERVATION_GAP = "Beobachtung lückenhaft: Zielzeiten gelten nur für beobachtete Abschnitte. Vollständige Abdeckung, Erneuerungen und Tickverluste bleiben unbekannt.",
    PERFORMANCE_TARGET_UNCONFIRMED = "Ziel unbestätigt",
    PERFORMANCE_PARTIAL_NOTE = "Teilaufzeichnung: ≥ zeigt einen Schadens-Teilstand; Beobachtungslücken bleiben unbekannt.",
    CURSE_UNCONFIRMED = "FLUCH UNBESTÄTIGT",
    CURSE_EXPIRED = "ERINNERUNG ABGELAUFEN",

    OPTIONS_GENERAL = "Allgemein",
    OPTIONS_COMBAT = "Kampfanzeige",
    OPTIONS_REVIEW = "Auswertung",
    OPTIONS_HELP = "Hilfe & Info",
    OPTIONS_ACCESS = "Sprache & Minikarte",
    OPTIONS_MAIN_WINDOW = "Hauptfenster",
    OPTIONS_MINIMAP_HELP = "Linksklick öffnet die Optionen. Rechtsklick schaltet die Gegnerübersicht um. Ziehen verschiebt das Minikartensymbol.",
    OPTIONS_RESET_SCALE = "Größe auf 100 % zurücksetzen",
    OPTIONS_DESIGN_HELP = "FULL öffnet Gul’dans Grimoire; minimal zeigt das schlichte Optionsfenster. Die Auswahl wird gespeichert.",
    OPTIONS_DESIGN_TIP = "FULL: Grimoire mit Umblättern. minimal: schlichtes Fenster mit denselben Einstellungen.",
    OPTIONS_PRIORITY_HELP = "Gegner mit dieser Raidmarkierung stehen bevorzugt oben in der Übersicht.",
    OPTIONS_MONITOR = "Performance-Monitor",
    OPTIONS_RECORDING = "Kampfaufzeichnung",
    OPTIONS_LAYOUT_HELP = "Größe und Position des Rabenfensters getrennt von der Gegnerübersicht einstellen.",
    OPTIONS_ARCHIVE_HELP = "Bis zu 30 geeignete Kämpfe je Charakter. Die Kartenauswahl beeinflusst die Anzeige; ausgeblendete Effekte werden weiter aufgezeichnet.",
    OPTIONS_INFORMATION = "Version & Status",
    OPTIONS_STATUS = "Status anzeigen",
    OPTIONS_COMMANDS = "Direktbefehle:\n/cf — Gegnerübersicht\n/cf performance — Monitor und Archiv\n/cf filters — Klassenfilter\n/cf karten — Kartenauswahl",
    OPTIONS_CREDITS = "Erstellt von Leandarh Valinor · Try Again Forever",
    OPTIONS_SAVED = "Änderungen werden sofort übernommen und gespeichert.",
    OPTIONS_SAVED_SHORT = "Änderungen werden sofort gespeichert.",
    OPTIONS_VERSION = "Version:",
    CLASS_FILTER = "Klassen-Zauberfilter",
    CLASS_FILTER_TITLE = "%s · Zauberfilter",
    CLASS_FILTER_SUMMARY = "Eigene Klasseneffekte getrennt nach Solo, Gruppe und Raid anzeigen oder ausblenden.",
    CLASS_FILTER_OPEN = "Zauberfilter öffnen",
    CARDS_TITLE = "Raben-Karten",
    CARDS_SUMMARY = "Bis zu fünf Effektkarten auswählen, anordnen und unbenutzte Karten ausblenden. Je Charakter gespeichert.",
    CARDS_OPEN = "Karten auswählen",
    CARDS_NOTE = "Häkchen = anzeigen. Die Reihenfolge gilt von links nach rechts; Platz 3 ist die große mittlere Karte. Änderungen wirken sofort auf die Anzeige.",
    CARDS_COUNT = "%d / 5 Karten ausgewählt",
    CARDS_LIMIT = "Höchstens fünf Karten; zuerst eine abwählen.",
    CARDS_HIDE_UNUSED = "Karten ohne Schaden und Zauberversuch ausblenden",
    CARDS_RECORDING_NOTE = "Ausgeblendete Effekte werden weiter aufgezeichnet. In älteren Kämpfen können neu ergänzte Effekte fehlen.",
    CARDS_RESET = "Standard wiederherstellen",
    CARDS_MOVE_UP = "Auf",
    CARDS_MOVE_DOWN = "Ab",
    CARDS_NOT_RECORDED = "Nicht aufgezeichnet",
    PERFORMANCE_DAMAGE_ONLY = "Nur Schadenssumme",
    DETAIL_DAMAGE_ONLY = "Flächeneffekt: Die Schadenssumme stammt aus dem DamageMeter. Zielzuordnung, Zauberzahl, Abdeckung und Erneuerungen werden für diesen Effekt nicht aus einzelnen Zielauren abgeleitet.",
    TRAP_DAMAGE = "Fallen",

    PERFORMANCE_CLIENT_RESTRICTED = "Client-Sperre",
    DETAIL_CLIENT_RESTRICTED_NOTICE = "Aura-Daten vom Client gesperrt: Abdeckung, Erneuerungen und Tickverluste nicht belegbar.",
    DETAIL_CLIENT_RESTRICTED_TIP = "Bei diesem Zauberversuch hat der Client den Zugriff auf die Aura-Liste gesperrt. Die Anwendung bleibt unbestätigt. Schaden und erfasste Zauber bleiben sichtbar.",
    PERFORMANCE_UNCONFIRMED = "nicht bestätigt",
    DETAIL_ACTION_UNCONFIRMED = "Unbestätigt",
    DETAIL_ACTION_NOT_APPLIED = "Nicht angewendet",
    DETAIL_UNCONFIRMED_SUMMARY = "Abdeckung/Ticks nicht bestätigt · Zauber %d · nicht angewendet %d · unbestätigt %d",
    DETAIL_UNRECORDED_SUMMARY = "Schaden vorhanden, aber keine bestätigte Anwendung aufgezeichnet · Abdeckung und Ticks offen.",
    DETAIL_NOT_APPLIED_COUNT = " · nicht angewendet %d",
    DETAIL_UNCONFIRMED_NOTICE = "Keine sicheren Anwendungsdaten: Uptime, Erneuerungen und Tickverluste bleiben offen. Schaden stammt weiter aus dem DamageMeter.",
    DETAIL_TARGET_UNCONFIRMED_SUMMARY = "Zauberziele nicht eindeutig zugeordnet · Zielabdeckung und Tickverluste bleiben offen.",
    DETAIL_TARGET_UNCONFIRMED_NOTICE = "Unbestätigte Zauberziele können diese Gegner betreffen. Deshalb werden auch bei den benannten Zielen keine 0-%-Abdeckung oder vollständigen Lücken ausgewiesen.",
    STATUS_DAMAGE = "Schadenszuordnung: %s · native Sitzung: %s",
    STATUS_DAMAGE_LIST = "Grundlage: %s · Sitzungen vorher / zuletzt / neu: %s / %s / %s",
    STATUS_DAMAGE_DURATION = "Dauervergleich: Aufzeichnung %s s · native Sitzung %s s",
    STATUS_DAMAGE_TRACE = "Verlauf der Zuordnungsprüfung:",
    STATUS_DAMAGE_API = "API vorhanden (Liste / Sitzung / Quelle): %s / %s / %s",
    STATUS_DAMAGE_LIST_STATE = "Listenstatus (vorher / zuletzt): %s / %s",
    DETAIL_APPLICATION_TIP = "Zauberabschluss ist kein Trefferbeleg. Nicht angewendet: Die vorherige eigene Aura blieb während der Prüfung wiederholt lesbar und unverändert. Unbestätigt: Rückgabe leer/geschützt, Ziel oder Zeitpunkt unklar oder Prüfung zu kurz. Eine leere Rückgabe beweist keinen Fehlschlag. Daraus wird kein Tickverlust berechnet.",
    STATUS_HEADER = "Status · Cursive Forever %s",
    STATUS_FIGHT = "%s · %s · Aufzeichnung: %s",
    STATUS_ACTIVE = "Laufender Kampf",
    STATUS_LAST = "Zuletzt beendeter Kampf",
    STATUS_ARCHIVED = "Neuester archivierter Kampf",
    STATUS_UNKNOWN_VERSION = "ältere Version",
    STATUS_COUNTS = "%s · bestätigt %d · nicht angewendet %d · unbestätigt %d",
    STATUS_EMPTY = "Noch keine Aufzeichnung mit Anwendungsstatus vorhanden.",
    STATUS_COPY = "Text auswählen",
    STATUS_COPY_HINT = "Text auswählen und Strg+C drücken, um den Status zu kopieren. ESC schließt das Fenster.",
    STATUS_REFRESH = "Aktualisieren",
    STATUS_CLIENT = "Aktueller Client: %s · Build %s · Datum %s",
    STATUS_PENDING = "Noch in Prüfung: %d Zauber.",
    STATUS_NOTE = "Unbestätigte Anwendungen liefern keine belastbare Uptime oder Tickwerte.",
    STATUS_RESTRICTED = "Client-Sperre in dieser Aufzeichnung: Betroffene Anwendungswerte sind nicht belegbar.",
    DETAIL_TITLE = "DoT-Details",
    DETAIL_OPEN = "Klicken: DoT-Details öffnen",
    DETAIL_BACK = "Zurück zu den DoT-Karten",
    DETAIL_ALL_TARGETS = "Alle Ziele",
    DETAIL_NO_TICK = "Ohne Tick überschrieben (berechnet)",
    DETAIL_DISCARDED = "Verworfene Tickzeit",
    DETAIL_LOST = "Verlorene Ticks (berechnet)",
    DETAIL_TIME = "Zeit",
    DETAIL_TARGET = "Ziel",
    DETAIL_ACTION = "Vorgang",
    DETAIL_REMAINING = "Restzeit",
    DETAIL_PROGRESS = "Tickzeit verworfen",
    DETAIL_EVENTS = "Zauber & Erneuerungen",
    DETAIL_EVENTS_FMT = "Zauber & Erneuerungen · %d Einträge · neueste zuerst",
    DETAIL_EVENTS_LIMIT_FMT = "Letzte %d von %d Zaubern · %d im Filter",
    DETAIL_LEGACY = "Für diesen Kampf wurden noch keine DoT-Details gespeichert. Die Aufzeichnung beginnt mit neuen Kämpfen ab 1.2.8.",
    DETAIL_LEGACY_SHORT = "Älterer Kampf · vorhandene Übersichtswerte bleiben erhalten.",
    DETAIL_NO_EVENTS = "Keine aufgezeichneten Anwendungen für diese Auswahl.",
    DETAIL_SUMMARY_FMT = "Abdeckung %s  ·  %.1f / %.1f Zielsekunden  ·  Lücken %.1f s  ·  Zauber %d  ·  Erneuerungen %d",
    DETAIL_COVERAGE_FMT = "%.1f / %.1f s · Lücke %.1f s",
    DETAIL_TICKS_FMT = "Modell: %d Ticks · bei lückenloser Erneuerung: %d",
    DETAIL_PARTIAL = "Teilaufzeichnung: Nicht alle Zielzeiten ließen sich eindeutig zuordnen.",
    DETAIL_NO_CASTS = "Keine aufgezeichnete Anwendung · Tickauswertung nicht verfügbar.",
    DETAIL_PASSIVE = "Passiver Effekt · keine aus Zaubern ableitbare Abdeckung.",
    DETAIL_NO_MODEL = "Kein durchgängig bestätigtes Tickmodell oder keine eindeutige Zielzuordnung.",
    DETAIL_MODEL_NOTICE = "Berechnung aus Zaubern und Grundintervallen · keine gemessenen Schadensticks.",
    DETAIL_FOOTER = "Lücken beziehen sich auf erfasste, relevante Zielzeiten. Tickverluste vergleichen Deinen Verlauf mit lückenloser Erneuerung nach Ablauf – ab der ersten aufgezeichneten Anwendung je Ziel.",
    DETAIL_METHOD = "Wie wird gerechnet?",
    DETAIL_METHOD_TIP = "Bestätigter Timer-Neustart beim Erneuern: Omen der Pein (2 s), Feuerbrand und Verderbnis (3 s). Ohne Tick überschrieben: vor dem ersten rechnerischen Tick erneut angewendet. Verworfene Tickzeit: Fortschritt seit dem letzten Tick bei einer vorzeitigen Erneuerung. Verlorene Ticks: Differenz zur lückenlosen Referenz je Ziel am Kampfende; ausgelassene Erneuerungen zählen ebenfalls. Diese Werte sind nicht addierbar. Tote oder nicht verfügbare Ziele werden nicht weiter belastet. Grundintervalle ohne Tempo-Modell. Ab 1.2.9 werden Anwendungen anhand lesbarer eigener Auren bestätigt; geschützte Anwendungsdaten unterdrücken Uptime und Tickwerte. Zauber zählen auch nicht angewendete Versuche. Vorzeitiges Entfernen eines bereits bestätigten DoTs wird nicht lückenlos erfasst. Schaden und Direkttreffer stammen weiterhin nur aus dem DamageMeter. Daraus wird kein verlorener Schadenswert geschätzt.",
    DETAIL_TARGET_TIP = "Klicken: Werte und Zauber auf dieses Ziel filtern. Die Nummer unterscheidet gleichnamige Ziele innerhalb dieses Kampfes.",
    DETAIL_EVENT_TIP = "DoT-Laufzeit: %.1f s · Restlaufzeit beim Erneuern: %.1f s",
    DETAIL_INTERVAL_FMT = "Berechnetes Grundintervall: %.1f s",
    DETAIL_NO_TICK_TIP = "Die vorherige Anwendung wurde vor ihrem ersten berechneten Tick überschrieben.",
    DETAIL_GAP_FMT = "Erneut angewendet nach %.1f s ohne diesen DoT.",
    DETAIL_ACTION_APPLY = "Angewendet",
    DETAIL_ACTION_REFRESH = "Früh erneuert",
    DETAIL_ACTION_REAPPLY = "Neu angewendet",
    DETAIL_ACTION_REPLACE = "Effekt gewechselt",

    UNKNOWN = "unbekannt",
    ENEMY = "Gegner",
    TARGET = "ZIEL",
    PROTECTED_TARGET = "geschütztes Ziel",
    BOSS = "Boss",

    OPTIONS = "Optionen",
    DISPLAY_CONTROL = "Anzeige & Bedienung",
    LANGUAGE = "Sprache",
    LANGUAGE_BUTTON_FMT = "Sprache: %s",
    LANGUAGE_TOOLTIP = "Klicken zum Wechseln: Auto → Deutsch → English. Auto folgt der Sprache des WoW-Clients.",

    SHOW_MINIMAP = "Minimap-Button anzeigen",
    SHOW_MINIMAP_TIP = "Blendet den verschiebbaren Cursive-Button an der Minimap ein oder aus.",
    LOCK_MAIN = "Hauptfenster sperren",
    LOCK_MAIN_TIP = "Verhindert, dass Cursive im Kampf versehentlich verschoben wird.",
    MINIMAP_DISTANCE_FMT = "Minimap-Abstand: |cffd8b15a%d px|r",
    SCALE_FMT = "Gesamtgröße: |cffd8b15a%d%%|r",
    TRACKER_WIDTH = "Breite der aktuellen Ansicht",
    TRACKER_HEIGHT = "Zeilenhöhe der aktuellen Ansicht",
    TRACKER_WIDTH_FMT = "Breite (%s): |cffd8b15a%d%%|r",
    TRACKER_HEIGHT_FMT = "Zeilenhöhe (%s): |cffd8b15a%d%%|r",
    TRACKER_SIZING_TIP = "Wird für die aktuelle Ansicht gespeichert. Verändert die Aufteilung, ohne Symbole und Schrift zu verzerren. Der Platzbedarf des Inhalts begrenzt die Verkleinerung. Für insgesamt kleinere Inhalte verwende Gesamtgröße.",
    TRACKER_HEIGHT_TIP = "Verändert die Zeilenhöhe der aktuellen Ansicht. In der Lebensbalkenansicht wird auch der Lebensbalken höher oder flacher. Symbole und Schrift behalten ihre Größe und begrenzen die Verkleinerung. Für insgesamt kleinere Inhalte verwende Gesamtgröße.",
    TRACKER_RESET_TIP = "Setzt die Gesamtgröße sowie Breite und Zeilenhöhe der aktuellen Ansicht auf 100%. Die Maße anderer Ansichten bleiben gespeichert.",
    TRACKER_EXTRAS_PENDING = "Zusatzsymbole: Änderung vorgemerkt.",
    TRACKER_EXTRA_ICONS = "Zusatzsymbole aktivieren",
    TRACKER_EXTRA_ICONS_TIP = "Zeigt zusätzliche Effekte und das separate Fluchsymbol in allen vier Ansichten. Ohne Zusatzsymbole wird die Anzeige schmaler. Haupt-DoTs, Raidmarker und Execute bleiben sichtbar. Bei gespeicherten Gegnerdaten außerhalb des Sichtfelds kann die Änderung bis zur nächsten Aktualisierung oder bis Kampfende warten.",
    TRACKER_HIDE_FRAME = "Rahmen ausblenden",
    TRACKER_HIDE_FRAME_TIP = "Blendet Hintergrund, Außenrahmen und Zeilenumrandungen in allen vier Ansichten aus. Portraits, Lebensbalken, Effekte und Zeiten bleiben sichtbar. Der Header wird weiterhin separat ein- oder ausgeblendet.",
    WINDOW_TRANSPARENCY = "Transparenz des Hauptfensters",
    WINDOW_TRANSPARENCY_FMT = "Hauptfenster-Transparenz: |cffd8b15a%d%%|r",
    WINDOW_TRANSPARENCY_TIP = "Ändert nur die Transparenz der Cursive-Gegnerübersicht. Der eingeblendete Header, Einstellungen und andere Fenster bleiben deckend. 0% ist vollständig sichtbar.",
    SHOW_OOC = "Feindliches Ziel außerhalb des Kampfes anzeigen",
    SHOW_OOC_TIP = "Wenn deaktiviert, bleibt Cursive außerhalb des Kampfes leer.",
    HIDE_WINDOW_OOC = "Fenster ausblenden, wenn nicht im Kampf",
    HIDE_WINDOW_OOC_TIP = "Blendet das gesamte Cursive-Hauptfenster außerhalb des eigenen Kampfes aus. Beim Kampfbeginn erscheint es wieder, sofern es nicht manuell ausgeblendet wurde. Einstellungen und andere Fenster bleiben erreichbar.",

    OPTIONS_DESIGN = "Options-Design",
    DECOR_SUBTLE = "Dezent",
    DECOR_RAVEN = "Rabe",
    DECOR_FULL = "Voll",
    DECOR_SUBTLE_TIP = "Paket 1: kleines Rabenemblem, schlichte Ornamentlinien und ein sehr schwaches Wasserzeichen.",
    DECOR_RAVEN_TIP = "Paket 2 (Standard): Rabenemblem, Abschnittssymbole, Runentrenner und kleine Eckornamente.",
    DECOR_FULL_TIP = "Paket 3: Vollausbau mit großem Wasserzeichen, Doppel-Runenlinien, starken Zentralrunen und dekorierten Buttons.",

    TARGET_DISPLAY = "Zieldarstellung",
    HEALTH_DISPLAY = "Lebensanzeige",
    HEALTH_PERCENT = "Prozent",
    HEALTH_BAR = "Balken",
    HEALTH_BAR_PERCENT = "Balken + Prozent",
    HEALTH_DISPLAY_FMT = "Lebensanzeige: %s",
    HEALTH_DISPLAY_TIP = "Für Standard und Matrix: Klicken wechselt zwischen Lebensbalken und Prozentwert. Die Auswahl wird gespeichert. DoT-Balken und Lebensbalken zeigen immer einen Lebensbalken mit HP-Prozenten. Die Lebensbalkenansicht ergänzt Gegnername und aktuelle/maximale Lebenspunkte.",
    STANDARD = "Standard",
    STANDARD_TIP = "Porträt, Lebensanzeige und Effekte ohne Gegnernamen. Das aktuelle Ziel bleibt über Zeilenrahmen und Porträtring erkennbar.",
    DISPLAY_HINT = "Porträt, Lebensanzeige und Effekte. Zielmarkierung: Rahmen oder grüne Klammer.",
    MATRIX = "Matrix",
    BARS = "DoT-Balken",
    HEALTHBARS = "Lebensbalken",
    HEALTHBARS_HINT = "Name und HP im Balken, Effekte rechts. Zielmarkierung: Rahmen oder grüne Klammer.",
    BARS_SHOW_SPELL_NAMES = "Zaubernamen anzeigen",
    BARS_SHOW_SPELL_NAMES_TIP = "Zeigt die Zaubernamen in den Effektbalken. Ohne Namen wird die DoT-Balkenansicht schmaler.",
    TRACKER_VIEW = "Gegneransicht",
    TRACKER_VIEW_FMT = "Ansicht: %s",
    TRACKER_VIEW_PENDING_FMT = "Ansicht: %s (vorgemerkt)",
    TRACKER_VIEW_TIP = "Standard zeigt Effektsymbole, Matrix gemeinsame Symbolüberschriften und DoT-Balken die Effekte je Gegner untereinander in Deiner Prioritätsreihenfolge. Lebensbalken zeigt je Gegner ein Porträt links, einen großen Lebensbalken mit Name, aktuellen/maximalen HP und Prozentwert in der Mitte sowie Effektsymbole rechts. Alle Ansichten behalten Zusatzeffekte und Fluchanzeige. Ein Wechsel kann vorgemerkt werden, bis Gegner außerhalb der Sicht sicher neu dargestellt werden können oder der Kampf endet. Die bisher aktive Ansicht erneut wählen hebt die Vormerkung auf.",

    RAID_MANY = "Raid & viele Gegner",
    RAID_MANY_TEXT = "Bis zu 40 Gegner werden verfolgt. Ab Gegner 21 öffnet Cursive automatisch eine zweite Spalte. Im Raid werden weiterhin alle sichtbaren feindlichen Namensplaketten gezeigt.",

    CURSE_WATCHER = "Raid-Fluchwächter",
    CURSE_SUMMARY = "An den eigenen Boss-Fluch erinnern. Der Timer folgt abgeschlossenen Zaubern und bestätigt keinen Treffer.",
    CURSE_OPEN = "Fluchwächter öffnen",



    CONTROLS = "Bedienung",
    HELP_TEXT = "|cffdfbd62Minimap:|r Linksklick Optionen · Rechtsklick Cursive ein/aus · Ziehen verschiebt den Button.\n|cffdfbd62Hauptfenster:|r Am Kopf ziehen; ohne Kopf am freien Hintergrund. Bei Sperre ist Verschieben deaktiviert.",
    TESTED_ON = "Clientstand:",

    VERSION_HISTORY = "Versionshistorie",
    RESET_POSITION = "Fensterposition zurücksetzen",

    FILTER_NOTE = "Häkchen = in diesem Spielmodus anzeigen. Neue, noch nicht katalogisierte Beta-Debuffs bleiben automatisch sichtbar.",
    DEBUFF = "Debuff",
    SOLO = "Solo",
    DUNGEON = "Dungeon",
    RAID = "Raid",
    NO_DESCRIPTION = "Keine Beschreibung vom Beta-Client geliefert.",
    DESCRIPTION_HINT = "Beschreibung: Maus über Icon oder Zaubernamen",
    SHOW_ALL = "Alle anzeigen",
    HIDE_ALL = "Alle ausblenden",

    CURSE_NOTE = "Persönliche Raid-Zuweisung: Forever schützt feindliche Aura-Daten im Kampf. Cursive führt deshalb ab deinem erfolgreichen Fluch-Cast einen eigenen Timer. Vor dem ersten Cast erscheint ein roter Hinweis; kurz vor Ablauf ein orangefarbener Hinweis.",
    CURSE_ENABLED = "Raid-Fluchwächter aktiv",
    CURSE_ENABLED_TIP = "Im Schlachtzug wird der zugewiesene Fluch auf aktiven Encounter-Bossen überwacht.",
    MY_CURSE = "Meine Fluch-Zuweisung",
    NONE = "Keine Zuweisung",
    WARN_BEFORE_FMT = "Vorwarnung vor Ablauf: |cffd8b15a%d Sekunden|r",
    TEST_CURRENT = "Test auf aktuellem Ziel",
    TEST_END = "Test beenden",
    RAID_TEST_HINT = "Im Raid: boss1–boss8 · Test: aktuelles Ziel",

    CURSE_MISSING = "FLUCH FEHLT!",
    CURSE_RENEW = "FLUCH ERNEUERN!",
    ON_TARGET = " auf ",
    SOON = "bald",

    NAMEPLATES_ENABLE = "Namensplaketten einschalten: ",
    KEY_UNKNOWN = "Taste unbekannt",
    NO_KEY_BOUND = "keine Taste belegt",
    WINDOW_LOCKED = "Fenster ist gesperrt.",

    MINIMAP_LEFT = "Linksklick: Optionen",
    MINIMAP_RIGHT = "Rechtsklick: Fenster ein/aus",
    MINIMAP_DRAG = "Ziehen: Position verändern",

    LOADED_FMT = "%s geladen.",
    TEST_ENDED = "Fluchwächter-Test beendet.",
    TEST_SELECT_HOSTILE = "Für den Test zuerst ein feindliches Ziel anwählen.",
    TEST_ASSIGN_CURSE = "Für den Test zuerst einen Fluch zuweisen.",
    TEST_ACTIVE = "Fluchwächter-Test auf aktuellem Ziel aktiv.",
    POSITION_RESET = "Fensterposition zurückgesetzt.",
    NAMEPLATE_API_MISSING = "C_NamePlate.GetNamePlates ist nicht verfügbar.",
    ON = "AN",
    OFF = "AUS",

    PERFORMANCE = "Performance",
    PERFORMANCE_SECTION = "Performance & Priorität",
    PERFORMANCE_SUMMARY = "Gespeicherte Kämpfe mit Schadenswerten und verfügbaren DoT-Details im Rabenfenster ansehen.",
    PERFORMANCE_ENABLED = "Performance-Historie aktiv",
    PERFORMANCE_ENABLED_TIP = "Wenn aktiv, speichert Cursive passende Kämpfe still im Hintergrund. Das Performance-Fenster öffnet sich niemals automatisch.",
    PERFORMANCE_OPEN = "Performance öffnen",
    PERFORMANCE_MIN_FMT = "Kampf speichern ab: |cffd8b15a%d Sekunden|r",
    PERFORMANCE_MIN_TIP = "Mindestkampfdauer für einen Historieneintrag. Bereich 15 bis 60 Sekunden, Standard 45.",
    PERFORMANCE_LAYOUT = "Größe & Position",
    PERFORMANCE_LAYOUT_TITLE = "Performance: Größe & Position",
    PERFORMANCE_SCALE_FMT = "Performancefenster: |cffd8b15a%d %%|r",
    PERFORMANCE_LAYOUT_HINT = "Ziehe das Performancefenster mit der linken Maustaste an die gewünschte Stelle.",
    PERFORMANCE_LAYOUT_SAVED = "Größe und Position werden für diesen Charakter gespeichert. Die Größe gilt für beide Ansichten.",
    PERFORMANCE_CENTER = "Position zentrieren",
    PERFORMANCE_HISTORY = "Kampf-Historie",
    PERFORMANCE_HISTORY_SHORT = "Historie",
    PERFORMANCE_CLEAR = "Historie löschen",
    PERFORMANCE_EMPTY = "Noch keine gespeicherten Kämpfe.",
    PERFORMANCE_MAX = "Letzte 30 Kämpfe",
    PERFORMANCE_SELECTED = "Ausgewählter Kampf",
    PERFORMANCE_FIGHT_DURATION = "Kampfdauer",
    PERFORMANCE_TOTAL_DAMAGE = "Gesamtschaden",
    PERFORMANCE_ALIVE_TIME = "Lebenszeit",
    PERFORMANCE_DEATHS = "Tode",
    PERFORMANCE_UPTIME = "Uptime",
    PERFORMANCE_DAMAGE = "Schaden",
    PERFORMANCE_DAMAGE_SHARE = "Anteil",
    PERFORMANCE_CASTS = "Zauber",
    PERFORMANCE_REFRESHES = "Erneuerungen",
    PERFORMANCE_UNUSED = "nicht verwendet",
    PERFORMANCE_TRASH = "Trash",
    PERFORMANCE_KILL = "Kill",
    PERFORMANCE_WIPE = "Wipe",
    PERFORMANCE_DISABLED = "Performance-Historie ist deaktiviert.",
    PERFORMANCE_DELETE_TIP = "Diesen Kampf aus der Historie löschen.",
    PERFORMANCE_CLEAR_TIP = "Alle gespeicherten Performance-Kämpfe dieses Charakters löschen.",
    PERFORMANCE_HISTORY_COUNT_FMT = "%d / 30 Kämpfe",
    PERFORMANCE_CREATED_BY = "created by Leandarh Valinor",
    PERFORMANCE_COVERAGE_NOTE = "Uptime über relevante Zielsekunden · Tote Zeit des Spielers zählt zur Kampfdauer.",
    PERFORMANCE_DATA_NOTE = "Schaden: Blizzard/Forever DamageMeter · Uptime: bestätigte Anwendungen · Unbestätigte Werte: —",
    PERFORMANCE_NOT_AVAILABLE = "Keine Performance-Daten verfügbar.",
    PERFORMANCE_UNKNOWN_FIGHT = "Unbekannter Kampf",
    PERFORMANCE_BOSS_TARGETS_FMT = "Ziele: %d",
    PERFORMANCE_NO_DOTS = "Keine passenden periodischen Effekte erkannt.",
    PERFORMANCE_SLASH_HINT = "/cf performance öffnet dieses Fenster.",
    PERFORMANCE_ARCHIVE_TIP = "Raven Archive ein-/ausblenden. Der Zustand wird pro Charakter gespeichert.",
    PERFORMANCE_ARCHIVE_OPEN = "Raven Archive öffnen",
    PERFORMANCE_ARCHIVE_CLOSE = "Raven Archive schließen",
    PERFORMANCE_COLLAPSE = "Performance einklappen",
    PERFORMANCE_EXPAND = "Performance ausklappen",
    PERFORMANCE_CARD_DAMAGE_FMT = "%s",
    PERFORMANCE_CARD_SHARE_FMT = "%.1f %%",
    PERFORMANCE_CARD_UPTIME_FMT = "%.1f %%",
    PERFORMANCE_CARD_CASTS_FMT = "%d",
    PERFORMANCE_CARD_REFRESH_FMT = "%d",
    PERFORMANCE_FIGHT_META_FMT = "%s · %s · %s",
    PERFORMANCE_SUMMARY_FMT = "%s: %s   ·   %s: %s   ·   %s: %d",
    PERFORMANCE_DAMAGE_UNAVAILABLE = "Schadensdaten nicht verfügbar",
    PERFORMANCE_PASSIVE = "passiv",
    PERFORMANCE_RESULT_FIGHT = "Kampf",
    PERFORMANCE_CLOSE_HINT = "ESC oder × zum Schließen",
    PRIORITY_MARKER = "Prioritätsmarker",
    PRIORITY_MARKER_FMT = "Prioritätsmarker: %s",
    PRIORITY_MARKER_TIP = "Klicken zum Wechseln. Gegner mit diesem Raidmarker werden, soweit die Forever-API den Marker lesbar liefert, ganz oben einsortiert.",
    MARKER_STAR = "Stern",
    MARKER_CIRCLE = "Kreis",
    MARKER_DIAMOND = "Diamant",
    MARKER_TRIANGLE = "Dreieck",
    MARKER_MOON = "Mond",
    MARKER_SQUARE = "Quadrat",
    MARKER_CROSS = "Kreuz",
    MARKER_SKULL = "Totenkopf",
    RAID_MARKER_SECRET = "Raidmarker ist im aktuellen Kampf von der API geschützt; Anzeige/Sortierung kann dann eingeschränkt sein.",
    RETIRED_COMMAND = "Dieser Entwicklungsbefehl wurde entfernt. /cf diagnose öffnet den Status.",
}

CF.L_EN = {
    DETAIL_OBSERVATION_GAP = "Observation gaps: target times cover observed spans only. Full coverage, refreshes and lost ticks remain unknown.",
    PERFORMANCE_TARGET_UNCONFIRMED = "Target unconfirmed",
    PERFORMANCE_PARTIAL_NOTE = "Partial recording: ≥ marks a damage sample; observation gaps remain unknown.",
    CURSE_UNCONFIRMED = "CURSE UNCONFIRMED",
    CURSE_EXPIRED = "REMINDER EXPIRED",

    OPTIONS_GENERAL = "General",
    OPTIONS_COMBAT = "Combat display",
    OPTIONS_REVIEW = "Review",
    OPTIONS_HELP = "Help & info",
    OPTIONS_ACCESS = "Language & minimap",
    OPTIONS_MAIN_WINDOW = "Main window",
    OPTIONS_MINIMAP_HELP = "Left-click opens options. Right-click toggles the enemy tracker. Drag to move the minimap icon.",
    OPTIONS_RESET_SCALE = "Reset size to 100%",
    OPTIONS_DESIGN_HELP = "FULL opens Gul’dan’s grimoire; minimal shows the simple options window. Your choice is saved.",
    OPTIONS_DESIGN_TIP = "FULL: grimoire with page turns. minimal: simple window with the same settings.",
    OPTIONS_PRIORITY_HELP = "Enemies carrying this raid marker appear first in the tracker.",
    OPTIONS_MONITOR = "Performance Monitor",
    OPTIONS_RECORDING = "Fight recording",
    OPTIONS_LAYOUT_HELP = "Adjust the Raven window size and position independently of the enemy tracker.",
    OPTIONS_ARCHIVE_HELP = "Up to 30 eligible fights per character. Card choices affect the display; hidden effects continue to be recorded.",
    OPTIONS_INFORMATION = "Version & status",
    OPTIONS_STATUS = "Show status",
    OPTIONS_COMMANDS = "Shortcuts:\n/cf — enemy tracker\n/cf performance — monitor and archive\n/cf filters — class filters\n/cf cards — card selection",
    OPTIONS_CREDITS = "Created by Leandarh Valinor · Try Again Forever",
    OPTIONS_SAVED = "Changes apply immediately and are saved.",
    OPTIONS_SAVED_SHORT = "Changes are saved immediately.",
    OPTIONS_VERSION = "Version:",
    CLASS_FILTER = "Class spell filters",
    CLASS_FILTER_TITLE = "%s · Spell filters",
    CLASS_FILTER_SUMMARY = "Show or hide your class effects separately for solo, group and raid play.",
    CLASS_FILTER_OPEN = "Open spell filters",
    CARDS_TITLE = "Raven cards",
    CARDS_SUMMARY = "Choose and order up to five effect cards and hide unused cards. Saved per character.",
    CARDS_OPEN = "Choose cards",
    CARDS_NOTE = "Checked cards are shown from left to right; slot 3 is the large middle card. Changes apply to the display immediately.",
    CARDS_COUNT = "%d / 5 cards selected",
    CARDS_LIMIT = "Five cards maximum; deselect one first.",
    CARDS_HIDE_UNUSED = "Hide cards without damage or cast attempts",
    CARDS_RECORDING_NOTE = "Hidden effects are still recorded. Newly added effects may be absent from older fights.",
    CARDS_RESET = "Restore defaults",
    CARDS_MOVE_UP = "Up",
    CARDS_MOVE_DOWN = "Down",
    CARDS_NOT_RECORDED = "Not recorded",
    PERFORMANCE_DAMAGE_ONLY = "Damage total only",
    DETAIL_DAMAGE_ONLY = "Area effect: damage totals come from DamageMeter. Targets, cast counts, coverage and refreshes are not inferred from individual target auras for this effect.",
    TRAP_DAMAGE = "Traps",

    PERFORMANCE_CLIENT_RESTRICTED = "Client restriction",
    DETAIL_CLIENT_RESTRICTED_NOTICE = "Aura data restricted by the client: coverage, refreshes and lost ticks cannot be verified.",
    DETAIL_CLIENT_RESTRICTED_TIP = "During this cast attempt, the client denied access to the aura list. The application remains unconfirmed. Damage and recorded casts remain visible.",
    PERFORMANCE_UNCONFIRMED = "unconfirmed",
    DETAIL_ACTION_UNCONFIRMED = "Unconfirmed",
    DETAIL_ACTION_NOT_APPLIED = "Not applied",
    DETAIL_UNCONFIRMED_SUMMARY = "Coverage/ticks unconfirmed · Casts %d · not applied %d · unconfirmed %d",
    DETAIL_UNRECORDED_SUMMARY = "Damage recorded without a confirmed application · Coverage and ticks remain unknown.",
    DETAIL_NOT_APPLIED_COUNT = " · not applied %d",
    DETAIL_UNCONFIRMED_NOTICE = "Application data is uncertain: uptime, refreshes and lost ticks remain unavailable. Damage still comes from DamageMeter.",
    DETAIL_TARGET_UNCONFIRMED_SUMMARY = "Cast targets could not be assigned uniquely · Target coverage and lost ticks remain unknown.",
    DETAIL_TARGET_UNCONFIRMED_NOTICE = "Unassigned casts may belong to these enemies. Named targets therefore show neither zero coverage nor a full coverage gap.",
    STATUS_DAMAGE = "Damage assignment: %s · native session: %s",
    STATUS_DAMAGE_LIST = "Baseline: %s · sessions before / latest / new: %s / %s / %s",
    STATUS_DAMAGE_DURATION = "Duration check: recording %s s · native session %s s",
    STATUS_DAMAGE_TRACE = "Assignment check history:",
    STATUS_DAMAGE_API = "API present (list / session / source): %s / %s / %s",
    STATUS_DAMAGE_LIST_STATE = "List state (before / latest): %s / %s",
    DETAIL_APPLICATION_TIP = "A completed cast does not prove a hit. Not applied: the previous player aura remained repeatedly readable and unchanged during verification. Unconfirmed: empty/protected data, uncertain target/timing or an incomplete check. An empty return does not prove failure. No lost ticks are inferred from this.",
    STATUS_HEADER = "Status · Cursive Forever %s",
    STATUS_FIGHT = "%s · %s · Recorded with: %s",
    STATUS_ACTIVE = "Current fight",
    STATUS_LAST = "Last completed fight",
    STATUS_ARCHIVED = "Newest archived fight",
    STATUS_UNKNOWN_VERSION = "older version",
    STATUS_COUNTS = "%s · confirmed %d · not applied %d · unconfirmed %d",
    STATUS_EMPTY = "No recording with application status available yet.",
    STATUS_COPY = "Select text",
    STATUS_COPY_HINT = "Select text and press Ctrl+C to copy this status. ESC closes the window.",
    STATUS_REFRESH = "Refresh",
    STATUS_CLIENT = "Current client: %s · Build %s · Date %s",
    STATUS_PENDING = "Still being verified: %d casts.",
    STATUS_NOTE = "Unconfirmed applications cannot provide reliable uptime or tick figures.",
    STATUS_RESTRICTED = "Client restriction in this recording: affected application metrics cannot be verified.",
    DETAIL_TITLE = "DoT details",
    DETAIL_OPEN = "Click: open DoT details",
    DETAIL_BACK = "Back to the DoT cards",
    DETAIL_ALL_TARGETS = "All targets",
    DETAIL_NO_TICK = "Overwritten before first tick (calculated)",
    DETAIL_DISCARDED = "Discarded tick progress",
    DETAIL_LOST = "Lost ticks (calculated)",
    DETAIL_TIME = "Time",
    DETAIL_TARGET = "Target",
    DETAIL_ACTION = "Action",
    DETAIL_REMAINING = "Remaining",
    DETAIL_PROGRESS = "Tick progress lost",
    DETAIL_EVENTS = "Casts & refreshes",
    DETAIL_EVENTS_FMT = "Casts & refreshes · %d entries · newest first",
    DETAIL_EVENTS_LIMIT_FMT = "Last %d of %d casts · %d in filter",
    DETAIL_LEGACY = "No DoT details were stored for this fight. Recording starts with new fights from 1.2.8 onwards.",
    DETAIL_LEGACY_SHORT = "Older fight · existing overview values are preserved.",
    DETAIL_NO_EVENTS = "No recorded applications for this selection.",
    DETAIL_SUMMARY_FMT = "Coverage %s  ·  %.1f / %.1f target-seconds  ·  Gaps %.1f s  ·  Casts %d  ·  Refreshes %d",
    DETAIL_COVERAGE_FMT = "%.1f / %.1f s · gap %.1f s",
    DETAIL_TICKS_FMT = "Model: %d ticks · with continuous renewal: %d",
    DETAIL_PARTIAL = "Partial recording: some target times could not be assigned reliably.",
    DETAIL_NO_CASTS = "No recorded application · tick analysis unavailable.",
    DETAIL_PASSIVE = "Passive effect · no cast-derived coverage available.",
    DETAIL_NO_MODEL = "No consistently confirmed tick model or no reliable target identity.",
    DETAIL_MODEL_NOTICE = "Calculated from casts and base intervals · not observed damage ticks.",
    DETAIL_FOOTER = "Gaps use recorded, relevant target times. Lost ticks compare your timeline with continuous renewal after expiry, starting at the first recorded application on each target.",
    DETAIL_METHOD = "How is this calculated?",
    DETAIL_METHOD_TIP = "Confirmed timer reset on renewal: Bane of Agony (2 s), Immolate and Corruption (3 s). Overwritten before first tick: refreshed before the first modeled tick. Discarded tick progress: time since the last tick at an early refresh. Lost ticks: shortfall against continuous renewal on each target at fight end; gaps also contribute. These metrics are not additive. Dead or unavailable targets accrue no further loss. Base intervals without a haste model. Readable player auras confirm applications from 1.2.9; protected application data suppresses uptime and tick results. Casts also include unsuccessful attempts. Early removal of a confirmed aura is not continuously observed. Damage and direct hits still come only from DamageMeter. No lost-damage amount is estimated.",
    DETAIL_TARGET_TIP = "Click to filter totals and casts to this target. The number distinguishes enemies with identical names within this fight.",
    DETAIL_EVENT_TIP = "DoT duration: %.1f s · remaining at refresh: %.1f s",
    DETAIL_INTERVAL_FMT = "Modeled base interval: %.1f s",
    DETAIL_NO_TICK_TIP = "The previous application was overwritten before its first modeled tick.",
    DETAIL_GAP_FMT = "Reapplied after %.1f s without this DoT.",
    DETAIL_ACTION_APPLY = "Applied",
    DETAIL_ACTION_REFRESH = "Early refresh",
    DETAIL_ACTION_REAPPLY = "Reapplied",
    DETAIL_ACTION_REPLACE = "Effect changed",

    UNKNOWN = "unknown",
    ENEMY = "Enemy",
    TARGET = "TARGET",
    PROTECTED_TARGET = "protected target",
    BOSS = "Boss",

    OPTIONS = "Options",
    DISPLAY_CONTROL = "Display & Controls",
    LANGUAGE = "Language",
    LANGUAGE_BUTTON_FMT = "Language: %s",
    LANGUAGE_TOOLTIP = "Click to cycle: Auto → Deutsch → English. Auto follows the WoW client language.",

    SHOW_MINIMAP = "Show minimap button",
    SHOW_MINIMAP_TIP = "Shows or hides the movable Cursive button around the minimap.",
    LOCK_MAIN = "Lock main window",
    LOCK_MAIN_TIP = "Prevents Cursive from being moved accidentally during combat.",
    MINIMAP_DISTANCE_FMT = "Minimap distance: |cffd8b15a%d px|r",
    SCALE_FMT = "Overall size: |cffd8b15a%d%%|r",
    TRACKER_WIDTH = "Current view width",
    TRACKER_HEIGHT = "Current view row height",
    TRACKER_WIDTH_FMT = "Width (%s): |cffd8b15a%d%%|r",
    TRACKER_HEIGHT_FMT = "Row height (%s): |cffd8b15a%d%%|r",
    TRACKER_SIZING_TIP = "Saved for the current view. Adjusts the layout without stretching icons or text. Content size limits how far the layout can shrink. Use Overall size to make all contents smaller.",
    TRACKER_HEIGHT_TIP = "Adjusts row height for the current view. In Health bars, the visible health bar also becomes taller or flatter. Icons and text keep their size and limit how far rows can shrink. Use Overall size to make all contents smaller.",
    TRACKER_RESET_TIP = "Resets overall size and the current view's width and row height to 100%. Dimensions saved for other views are kept.",
    TRACKER_EXTRAS_PENDING = "Extra icons: change queued.",
    TRACKER_EXTRA_ICONS = "Enable extra icons",
    TRACKER_EXTRA_ICONS_TIP = "Shows additional effects and the separate curse icon in all four views. Disabling them makes the tracker narrower. Main DoTs, raid markers and Execute stay visible. The change may wait until an enemy outside your view can be refreshed or combat ends.",
    TRACKER_HIDE_FRAME = "Hide frame",
    TRACKER_HIDE_FRAME_TIP = "Hides the background, outer frame and row borders in all four views. Portraits, health bars, effects and timers stay visible. The header can still be shown or hidden separately.",
    WINDOW_TRANSPARENCY = "Tracker transparency",
    WINDOW_TRANSPARENCY_FMT = "Tracker transparency: |cffd8b15a%d%%|r",
    WINDOW_TRANSPARENCY_TIP = "Changes only the Cursive enemy tracker's transparency. The visible header, settings and other windows stay opaque. 0% is fully visible.",
    SHOW_OOC = "Show hostile target out of combat",
    SHOW_OOC_TIP = "When disabled, Cursive remains empty while out of combat.",
    HIDE_WINDOW_OOC = "Hide window out of combat",
    HIDE_WINDOW_OOC_TIP = "Hides the entire Cursive tracker while you are out of combat. It returns when combat starts, unless manually hidden. Options and other windows remain accessible.",

    OPTIONS_DESIGN = "Options design",
    DECOR_SUBTLE = "Subtle",
    DECOR_RAVEN = "Raven",
    DECOR_FULL = "Full",
    DECOR_SUBTLE_TIP = "Theme 1: small raven emblem, simple ornament lines and a very faint watermark.",
    DECOR_RAVEN_TIP = "Theme 2 (default): raven emblem, section icons, rune dividers and small corner ornaments.",
    DECOR_FULL_TIP = "Theme 3: full decoration with a large watermark, double rune lines, strong center runes and decorated buttons.",

    TARGET_DISPLAY = "Target display",
    HEALTH_DISPLAY = "Health display",
    HEALTH_PERCENT = "Percent",
    HEALTH_BAR = "Bar",
    HEALTH_BAR_PERCENT = "Bar + percent",
    HEALTH_DISPLAY_FMT = "Health display: %s",
    HEALTH_DISPLAY_TIP = "For Standard and Matrix: click to switch between a health bar and a percentage. Your choice is saved. DoT bars and Health bars always display a health bar with HP percentage inside it. Health bars also includes the enemy name and current/maximum health.",
    STANDARD = "Standard",
    STANDARD_TIP = "Portrait, health display and effects without enemy names. The current target stays visible through the row border and portrait ring.",
    DISPLAY_HINT = "Portrait, health and effects. Target marking: border or green bracket.",
    MATRIX = "Matrix",
    BARS = "DoT bars",
    HEALTHBARS = "Health bars",
    HEALTHBARS_HINT = "Name and HP in the bar, effects on the right. Target: border or green bracket.",
    BARS_SHOW_SPELL_NAMES = "Show spell names",
    BARS_SHOW_SPELL_NAMES_TIP = "Shows spell names in the effect bars. Hiding names makes the DoT bars view narrower.",
    TRACKER_VIEW = "Tracker view",
    TRACKER_VIEW_FMT = "View: %s",
    TRACKER_VIEW_PENDING_FMT = "View: %s (queued)",
    TRACKER_VIEW_TIP = "Standard shows effect icons, Matrix shared icon headings, and DoT bars stacks effects per enemy in your priority order. Health bars shows each enemy's portrait on the left, a large health bar with name, current/maximum HP and percentage in the middle, and effect icons on the right. All views retain additional effects and the curse display. A switch may be queued until offscreen enemies can be rebuilt safely or combat ends. Select the currently active view again to cancel the queued switch.",

    RAID_MANY = "Raid & many enemies",
    RAID_MANY_TEXT = "Up to 40 enemies are tracked. From enemy 21 onward Cursive automatically opens a second column. In raids all relevant visible hostile nameplates continue to be shown.",

    CURSE_WATCHER = "Raid Curse Watcher",
    CURSE_SUMMARY = "Reminder for your own boss curse. Its timer follows completed casts and does not confirm a hit.",
    CURSE_OPEN = "Open Curse Watcher",



    CONTROLS = "Controls",
    HELP_TEXT = "|cffdfbd62Minimap:|r Left click options · Right click Cursive on/off · Drag to move the button.\n|cffdfbd62Main window:|r Drag the header, or the empty background when the header is hidden. A locked window cannot be moved.",
    TESTED_ON = "Client reference:",

    VERSION_HISTORY = "Version history",
    RESET_POSITION = "Reset window position",

    FILTER_NOTE = "Checked = show in this play mode. New, not-yet-catalogued beta debuffs remain visible automatically.",
    DEBUFF = "Debuff",
    SOLO = "Solo",
    DUNGEON = "Dungeon",
    RAID = "Raid",
    NO_DESCRIPTION = "No description supplied by the beta client.",
    DESCRIPTION_HINT = "Description: mouse over an icon or spell name",
    SHOW_ALL = "Show all",
    HIDE_ALL = "Hide all",

    CURSE_NOTE = "Personal raid assignment: Forever protects hostile aura data during combat. Cursive therefore starts its own timer from your successful curse cast. Before the first cast a red warning is shown; shortly before expiration the warning turns orange.",
    CURSE_ENABLED = "Enable Raid Curse Watcher",
    CURSE_ENABLED_TIP = "In raids, the assigned curse is tracked on active encounter bosses.",
    MY_CURSE = "My curse assignment",
    NONE = "No assignment",
    WARN_BEFORE_FMT = "Expiration warning: |cffd8b15a%d seconds|r",
    TEST_CURRENT = "Test on current target",
    TEST_END = "End test",
    RAID_TEST_HINT = "Raid: boss1–boss8 · Test: current target",

    CURSE_MISSING = "CURSE MISSING!",
    CURSE_RENEW = "RENEW CURSE!",
    ON_TARGET = " on ",
    SOON = "soon",

    NAMEPLATES_ENABLE = "Enable nameplates: ",
    KEY_UNKNOWN = "key unknown",
    NO_KEY_BOUND = "no key bound",
    WINDOW_LOCKED = "Window is locked.",

    MINIMAP_LEFT = "Left click: Options",
    MINIMAP_RIGHT = "Right click: Show/hide window",
    MINIMAP_DRAG = "Drag: Move position",

    LOADED_FMT = "%s loaded.",
    TEST_ENDED = "Curse Watcher test ended.",
    TEST_SELECT_HOSTILE = "Select a hostile target before starting the test.",
    TEST_ASSIGN_CURSE = "Assign a curse before starting the test.",
    TEST_ACTIVE = "Curse Watcher test active on current target.",
    POSITION_RESET = "Window position reset.",
    NAMEPLATE_API_MISSING = "C_NamePlate.GetNamePlates is unavailable.",
    ON = "ON",
    OFF = "OFF",

    PERFORMANCE = "Performance",
    PERFORMANCE_SECTION = "Performance & Priority",
    PERFORMANCE_SUMMARY = "Review recorded fights with damage values and available DoT details in the Raven window.",
    PERFORMANCE_ENABLED = "Enable performance history",
    PERFORMANCE_ENABLED_TIP = "When enabled, Cursive stores eligible fights silently in the background. The performance window never opens automatically.",
    PERFORMANCE_OPEN = "Open Performance",
    PERFORMANCE_MIN_FMT = "Store fights from: |cffd8b15a%d seconds|r",
    PERFORMANCE_MIN_TIP = "Minimum fight duration for a history entry. Range 15 to 60 seconds, default 45.",
    PERFORMANCE_LAYOUT = "Size & position",
    PERFORMANCE_LAYOUT_TITLE = "Performance: size & position",
    PERFORMANCE_SCALE_FMT = "Performance window: |cffd8b15a%d %%|r",
    PERFORMANCE_LAYOUT_HINT = "Drag the Performance window with the left mouse button to your preferred position.",
    PERFORMANCE_LAYOUT_SAVED = "Size and position are saved for this character. Both views share the same scale.",
    PERFORMANCE_CENTER = "Center position",
    PERFORMANCE_HISTORY = "Fight History",
    PERFORMANCE_HISTORY_SHORT = "History",
    PERFORMANCE_CLEAR = "Clear history",
    PERFORMANCE_EMPTY = "No saved fights yet.",
    PERFORMANCE_MAX = "Last 30 fights",
    PERFORMANCE_SELECTED = "Selected fight",
    PERFORMANCE_FIGHT_DURATION = "Fight duration",
    PERFORMANCE_TOTAL_DAMAGE = "Total damage",
    PERFORMANCE_ALIVE_TIME = "Alive time",
    PERFORMANCE_DEATHS = "Deaths",
    PERFORMANCE_UPTIME = "Uptime",
    PERFORMANCE_DAMAGE = "Damage",
    PERFORMANCE_DAMAGE_SHARE = "Share",
    PERFORMANCE_CASTS = "Casts",
    PERFORMANCE_REFRESHES = "Refreshes",
    PERFORMANCE_UNUSED = "not used",
    PERFORMANCE_TRASH = "Trash",
    PERFORMANCE_KILL = "Kill",
    PERFORMANCE_WIPE = "Wipe",
    PERFORMANCE_DISABLED = "Performance history is disabled.",
    PERFORMANCE_DELETE_TIP = "Delete this fight from history.",
    PERFORMANCE_CLEAR_TIP = "Delete all saved performance fights for this character.",
    PERFORMANCE_HISTORY_COUNT_FMT = "%d / 30 fights",
    PERFORMANCE_CREATED_BY = "created by Leandarh Valinor",
    PERFORMANCE_COVERAGE_NOTE = "Uptime uses relevant target-seconds · Time spent dead still counts toward fight duration.",
    PERFORMANCE_DATA_NOTE = "Damage: Blizzard/Forever DamageMeter · Uptime: confirmed applications · Unconfirmed values: —",
    PERFORMANCE_NOT_AVAILABLE = "No performance data available.",
    PERFORMANCE_UNKNOWN_FIGHT = "Unknown fight",
    PERFORMANCE_BOSS_TARGETS_FMT = "Targets: %d",
    PERFORMANCE_NO_DOTS = "No matching periodic effects detected.",
    PERFORMANCE_SLASH_HINT = "/cf performance opens this window.",
    PERFORMANCE_ARCHIVE_TIP = "Show/hide the Raven Archive. Its state is saved per character.",
    PERFORMANCE_ARCHIVE_OPEN = "Open Raven Archive",
    PERFORMANCE_ARCHIVE_CLOSE = "Close Raven Archive",
    PERFORMANCE_COLLAPSE = "Collapse Performance",
    PERFORMANCE_EXPAND = "Expand Performance",
    PERFORMANCE_CARD_DAMAGE_FMT = "%s",
    PERFORMANCE_CARD_SHARE_FMT = "%.1f %%",
    PERFORMANCE_CARD_UPTIME_FMT = "%.1f %%",
    PERFORMANCE_CARD_CASTS_FMT = "%d",
    PERFORMANCE_CARD_REFRESH_FMT = "%d",
    PERFORMANCE_FIGHT_META_FMT = "%s · %s · %s",
    PERFORMANCE_SUMMARY_FMT = "%s: %s   ·   %s: %s   ·   %s: %d",
    PERFORMANCE_DAMAGE_UNAVAILABLE = "Damage data unavailable",
    PERFORMANCE_PASSIVE = "passive",
    PERFORMANCE_RESULT_FIGHT = "Fight",
    PERFORMANCE_CLOSE_HINT = "ESC or × to close",
    PRIORITY_MARKER = "Priority marker",
    PRIORITY_MARKER_FMT = "Priority marker: %s",
    PRIORITY_MARKER_TIP = "Click to cycle. Enemies with this raid marker are sorted to the top whenever the Forever API exposes the marker as readable.",
    MARKER_STAR = "Star",
    MARKER_CIRCLE = "Circle",
    MARKER_DIAMOND = "Diamond",
    MARKER_TRIANGLE = "Triangle",
    MARKER_MOON = "Moon",
    MARKER_SQUARE = "Square",
    MARKER_CROSS = "Cross",
    MARKER_SKULL = "Skull",
    RAID_MARKER_SECRET = "The raid marker is protected by the API in this combat state; display/sorting can then be limited.",
    RETIRED_COMMAND = "This development command was removed. Use /cf diagnose to open status.",
}

function CF.GetLanguageMode()
    local mode = db and db.uiLanguage or "auto"
    if mode ~= "auto" and mode ~= "de" and mode ~= "en" then
        mode = "auto"
    end
    return mode
end

function CF.GetEffectiveLanguage()
    local mode = CF.GetLanguageMode()
    if mode == "de" or mode == "en" then
        return mode
    end

    if GetLocale and GetLocale() == "deDE" then
        return "de"
    end
    return "en"
end

function CF.T(key)
    local source = CF.GetEffectiveLanguage() == "de" and CF.L_DE or CF.L_EN
    return source[key] or CF.L_EN[key] or CF.L_DE[key] or tostring(key)
end

function CF.TF(key, ...)
    return string.format(CF.T(key), ...)
end

function CF.GetLanguageModeLabel()
    local mode = CF.GetLanguageMode()
    if mode == "de" then
        return "Deutsch"
    elseif mode == "en" then
        return "English"
    end
    return "Auto"
end

function CF.CycleLanguageMode()
    local mode = CF.GetLanguageMode()
    if mode == "auto" then
        db.uiLanguage = "de"
    elseif mode == "de" then
        db.uiLanguage = "en"
    else
        db.uiLanguage = "auto"
    end
end

function CF.RegisterLocaleUpdater(fn)
    if type(fn) == "function" then
        CF.localeUpdaters[#CF.localeUpdaters + 1] = fn
    end
end

function CF.RefreshLocale()
    for _, fn in ipairs(CF.localeUpdaters) do
        pcall(fn)
    end
end

function CF.GetCurseFallback(curse)
    if not curse then
        return CF.T("CURSE_WATCHER")
    end
    if CF.GetEffectiveLanguage() == "en" and curse.english then
        return curse.english
    end
    return curse.fallback
end

local function GetTargetDisplayMode()
    local mode = db and db.targetDisplayMode or DEFAULTS.targetDisplayMode

    if mode ~= "standard"
        and mode ~= "compact"
        and mode ~= "minimal"
    then
        mode = DEFAULTS.targetDisplayMode
    end

    return mode
end

function CF.GetHealthDisplayMode()
    return db and db.healthDisplayMode == "percent" and "percent" or "bar"
end

local function GetCurrentRowWidth()
    if CF.IsHealthbarView and CF.IsHealthbarView() then return CF.GetHealthbarRowWidth() end
    if CF.IsBarsView and CF.IsBarsView() then return CF.GetBarsRowWidth() end
    if CF.IsMatrixView and CF.IsMatrixView() then return CF.GetMatrixRowWidth() end
    local mode = GetTargetDisplayMode()
    if CF.GetStandardRowWidth then return CF.GetStandardRowWidth(mode) end

    local extra = CF.ExperimentalWidth and CF.ExperimentalWidth() or 0
    extra = extra + (CF.GetAuraLayoutExtraWidth and CF.GetAuraLayoutExtraWidth(mode) or 0)
    if mode == "compact" then
        return ROW_W_COMPACT + extra
    elseif mode == "minimal" then
        return ROW_W_MINIMAL + extra
    end

    return ROW_W_STANDARD + extra
end

local function IsSecretValue(value)
    if not issecretvalue then return false end
    -- Test readability before any comparison, conversion or branch on value.
    -- A failed checker cannot establish that the value is safe to inspect.
    local ok, secret = pcall(issecretvalue, value)
    return not ok or secret ~= false
end

local function ReadClientBoolean(fn, ...)
    if not fn then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or IsSecretValue(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function UnitExistsReadable(unit)
    if IsSecretValue(unit) or type(unit) ~= "string" then return false end
    return ReadClientBoolean(UnitExists, unit) == true
end

local function ShortDisplayName(name, maxChars)
    if IsSecretValue(name) then
        return name
    end

    if name == nil then
        name = CF.T("ENEMY")
    else
        name = tostring(name)
    end

    if #name <= maxChars then
        return name
    end

    return string.sub(name, 1, maxChars) .. "…"
end

CF.CHANGELOG_DE = [[
Zuletzt im Spiel bestätigter Clientstand: WoW Forever 1.60.1 (70450), Release x64 — Client-Build vom 15.10.2026.
Ältere Einträge beschreiben den jeweiligen damaligen Stand.

|cffdfbd621.9.1 – Unterstützende Flüche als Haupteffekte|r  |cffaaaaaa22.10.2026|r
• Fluch der Schwäche, Sprachen, Tollkühnheit, Erschöpfung und Elemente sind unter Zauber & Hinweise nun in allen vier Ansichten als Haupt auswählbar. Danke an thermanshs für den Vorschlag.
• Gewählte Flüche folgen der normalen Haupteffektreihenfolge und zählen zu den acht Hauptplätzen. Sie erscheinen nicht zusätzlich am kleinen Fluchplatz oder im Zusatzraster.
• Mit festen Plätzen und aktiviertem Klickzaubern lassen sich erlernte Hauptflüche wie andere Hauptzauber auf Fokus oder Ziel wirken. Bei ausgeschalteten Zusatzsymbolen bleiben sie sichtbar.
• Bestehende Auswahlen bleiben erhalten. Der Raid-Fluchwächter wird weiterhin unabhängig eingestellt.

|cffdfbd621.9.0 – Zaubern per Klick auf Fokus und Ziel|r  |cffaaaaaa21.10.2026|r
• Erlernte Hauptzauber per Linksklick auf Fokus oder aktuelles Ziel wirken. Funktioniert mit festen Plätzen in Standard, Matrix, DoT-Balken und Lebensbalken, auch in leeren Feldern. Danke an Myia für den Vorschlag.
• Der Fokus steht ganz oben: Standard und Lebensbalken zeigen Fokus unter dem Porträt; Matrix und DoT-Balken verwenden ein größeres F am Porträt. Darunter folgt das aktuelle Ziel mit der vertrauten Zielmarkierung. Weitere Gegner dienen der Anzeige.
• Beim Ziel- oder Fokuswechsel werden die zugehörigen Effekte einschließlich Zusatzeffekten und unterstützendem Fluch aktualisiert. Zeigen Fokus und Ziel denselben Gegner, aktualisieren sich beide Zeilen gemeinsam.
• Gemerkte Gegner außerhalb der Sicht übernehmen nicht mehr das Schlachtzugsymbol oder die daraus folgende Sortierpriorität eines anderen Gegners.
• Sind Fokus und Ziel derselbe Gegner, bleiben beide Bedienzeilen sichtbar – wie bei den normalen Ziel- und Fokusfenstern. Die Vorschläge zählen diesen Gegner nur einmal.
• Klickzaubern ist für feste Anordnungen voreingeschaltet und unter Zauber & Hinweise abschaltbar. Nach Ablauf behält die gewohnte Anzeige.
• Bei aktivem Klickzaubern Anordnung, Größe, Position und Fenstersichtbarkeit außerhalb des Kampfes ändern. Das Fenster folgt weiterhin seiner gespeicherten Sichtbarkeitseinstellung für außerhalb des Kampfes.
• Fokuszauber berücksichtigen den erkannten Empfänger in Vorschlägen und Kampfauswertung. Mehrdeutige Zuordnungen bleiben unbestätigt; ein abgeschlossener Zauber ist weiterhin kein Trefferbeweis.

|cffdfbd621.8.0 – Übersichtlichere Optionen und gemeinsame Zauberliste|r  |cffaaaaaa20.10.2026|r
• Die Optionen haben vier klar benannte Seiten: Anzeige, Zauber & Hinweise, Auswertung sowie Allgemeines & Hilfe. Grimoire und schlichtes Optionsfenster verwenden dieselbe Ordnung.
• Anzeige bündelt Ansicht, Sortierung, Größe, Transparenz, Fensterkopf, Rahmen, Zusatzsymbole und Sichtbarkeit außerhalb des Kampfes.
• Zauber & Hinweise vereint Zauberfilter, Hauptplätze und Priorität in einer Liste. Filter für Solo, Dungeon und Raid bleiben getrennt. /cf dots und /cf filters öffnen diese Seite direkt.
• Execute bietet vier direkte Auswahlknöpfe: Automatisch, Unter 35 %, Unter 20 % und Aus. Vorschläge, Raidmarker-Priorität und Fluchwächter stehen daneben.
• Vorhandene Einstellungen bleiben erhalten. Nicht verfügbare Optionen sind mit Erklärung ausgegraut; längere Seiten lassen sich scrollen.
• Fluch der Elemente ist jetzt in der Zauberliste anwählbar, nutzt den gemeinsamen Platz für unterstützende Flüche und lässt sich im Fluchwächter zuweisen.
• Dämonisches Brandmal und Schattenverwundbarkeit (Verbesserter Schattenblitz) sind als Haupt- oder Zusatzeffekte wählbar. Danke an thermanshs für diese Zauberwünsche.

|cffdfbd621.7.8 – Kompakte Standardzeilen und Anzeigeoptionen|r  |cffaaaaaa20.10.2026|r
• Standard mit Nach Ablauf reserviert beim Einschalten der Zusatzsymbole keine leere zweite große Symbolreihe mehr. Bis zu vier gewählte Haupteffekte passen in eine Reihe; fünf bis acht behalten ihre zweite Reihe.
• Haupteffekte bleiben nach Restlaufzeit sortiert. Bis zu vier Zusatzeffekte nutzen den kompakten Bereich aus zwei Zweierreihen, wie bei fester Reihenfolge.
• Der Wechsel zwischen fester Reihenfolge und Ablaufsortierung wartet bei Bedarf, damit laufende Timer bei Gegnern außerhalb der Sicht erhalten bleiben.
• Die Deckkraft der Ablaufanimation lässt sich unter DoT-Anordnung von 0–100% einstellen (Vorgabe: 58%). Änderungen außerhalb des Kampfes mit Übernehmen und UI neu laden aktivieren. Danke an Myia für den Vorschlag.
• Neue Checkbox Fenster ausblenden, wenn nicht im Kampf unter Kampfanzeige, standardmäßig aus. Die Übersicht erscheint beim Kampfbeginn wieder, sofern sie nicht manuell ausgeblendet wurde; Optionen bleiben erreichbar.

|cffdfbd621.7.7-beta1 – Deckkraft der Ablaufanimation und Sichtbarkeit im Kampf|r  |cffaaaaaa20.10.2026|r
• Die Deckkraft der Ablaufanimation lässt sich unter DoT-Anordnung von 0–100% einstellen. Die bisherigen 58% bleiben voreingestellt. Danke an Myia für den Vorschlag.
• Eine geänderte Deckkraft außerhalb des Kampfes mit Übernehmen und UI neu laden aktivieren. Sie betrifft den dunklen Schleier auf Symbolen; Matrix-Zahlen und DoT-Balken behalten ihre Darstellung.
• Neue Checkbox Fenster ausblenden, wenn nicht im Kampf unter Kampfanzeige, standardmäßig aus. Die gesamte Gegnerübersicht erscheint beim eigenen Kampfbeginn wieder; manuelles Ausblenden hat weiterhin Vorrang. Optionen und andere Fenster bleiben erreichbar.
• Das gewünschte Leuchten bei Ablauf ist in dieser Beta noch nicht enthalten.

|cffdfbd621.7.6 – Rahmenlose Anzeige und deutlichere Zielmarkierung|r  |cffaaaaaa20.10.2026|r
• Der eingeblendete Fensterkopf bleibt vollständig deckend, wenn die Transparenz der Gegnerübersicht erhöht wird.
• Zusatzsymbole aktivieren und Rahmen ausblenden stehen in allen vier Ansichten zur Verfügung. Ohne Zusatzeffekte und den separaten unterstützenden Fluch wird die Anzeige schmaler; Haupt-DoTs, Raidmarker und Execute-Hinweise bleiben sichtbar.
• Rahmen ausblenden entfernt Hintergrund, Außenrahmen und Zeilenumrandungen bei kleineren Außenabständen. Eine grüne Klammer links kennzeichnet in jeder rahmenlosen Ansicht dein ausgewähltes Ziel.
• In der Lebensbalkenansicht verändert der Zeilenhöhenregler jetzt neben dem Abstand auch die sichtbare Balkenhöhe. Schrift und Symbole behalten ihre Größe; Mindestmaße sichern die Lesbarkeit. Bei 100% bleibt die vertraute Anordnung erhalten.
• Zusatzsymbole sind anfangs eingeschaltet und Rahmen sichtbar. Der Fensterkopf bleibt separat schaltbar.

|cffdfbd621.7.6-beta1 – Rahmen und Zusatzsymbole schaltbar|r  |cffaaaaaa20.10.2026|r
• Der eingeblendete Fensterkopf bleibt vollständig deckend, wenn die Transparenz der Gegnerübersicht erhöht wird.
• Neue gemeinsame Optionen für Standard, Matrix, DoT-Balken und Lebensbalken: Zusatzsymbole aktivieren (standardmäßig an) und Rahmen ausblenden (standardmäßig aus).
• Ohne Zusatzsymbole entfallen zusätzliche Effekte und der separate unterstützende Fluch samt Platzbedarf. Haupt-DoTs, Raidmarker und Execute-Hinweise bleiben sichtbar.
• Rahmen ausblenden entfernt Fensterhintergrund, Außenrahmen und Zeilenumrandungen bei kleineren Außenabständen. Der Fensterkopf bleibt separat schaltbar.
• Bei Standard mit Nach Ablauf kann das Umschalten der Zusatzsymbole warten, bis ein Gegner außerhalb des Sichtfelds wieder aktualisierbar ist oder der Kampf endet. Seine laufenden Timer bleiben erhalten.

|cffdfbd621.7.5 – Größe der Gegnerübersicht flexibler einstellen|r  |cffaaaaaa19.10.2026|r
• Die Gegnerübersicht lässt sich jetzt bis auf 40% verkleinern. Die Gesamtskalierung reicht von 40–130% in 5%-Schritten.
• Breite und Zeilenhöhe lassen sich für Standard, Matrix, DoT-Balken und Lebensbalken unabhängig einstellen. Symbole und Schrift behalten ihre Proportionen; der Platzbedarf des Inhalts begrenzt die Verkleinerung.
• Jede Ansicht merkt sich ihre Maße und kann auf 100% zurückgesetzt werden. Die gespeicherte Gesamtskalierung bleibt erhalten; neue Einstellungen beginnen bei 100%.

|cffdfbd621.7.4 – Sortierung leichter auswählen|r  |cffaaaaaa18.10.2026|r
• Die DoT-Anordnung zeigt unter Sortierung jetzt zwei direkte Auswahlen: Feste Reihenfolge / Nach Ablauf. Die aktive Auswahl bleibt sichtbar; Kurzinfos erklären beide Möglichkeiten.
• Lebensbalken berücksichtigt jetzt dieselbe Sortierwahl wie Standard: Effekte an festen Plätzen oder zuerst die Effekte mit der kürzesten Restlaufzeit anzeigen.
• Matrix und DoT-Balken behalten deine festgelegte Effektreihenfolge. Deine gespeicherte Sortierwahl bleibt erhalten.

|cffdfbd621.7.3 – Lebensbalkenansicht|r  |cffaaaaaa18.10.2026|r
• Neue vierte Ansicht auf Vorschlag von thermanshs: Porträt und Raidmarker links, großer Lebensbalken mit Gegnername, aktuellen/maximalen HP und Prozenten in der Mitte sowie Effektsymbole mit Restzeiten rechts.
• Vier direkte Auswahlen: Standard / Matrix / DoT-Balken / Lebensbalken. Die bisherige Balkenansicht heißt jetzt DoT-Balken.
• Längere Gegnernamen erhalten mehr Platz im Lebensbalken, ohne Fensterbreite oder Zeilenhöhe zu vergrößern.
• Haupteffekte folgen der gewählten Priorität. Vier Zusatzeffekte, eigener unterstützender Fluch und Execute-Schwerter bleiben verfügbar. Mindestens einen Hauptplatz in der DoT-Anordnung wählen.

|cffdfbd621.7.3-beta1 – Neue Lebensbalkenansicht (Beta)|r  |cffaaaaaa18.10.2026|r
• Vierte Ansicht auf Vorschlag von thermanshs: Porträt und Raidmarker links, großer Lebensbalken mit Name, aktuellen/maximalen HP und Prozenten in der Mitte, Effektsymbole mit Restzeiten rechts.
• Vier direkte Auswahlen: Standard / Matrix / DoT-Balken / Lebensbalken. Die bisherige Balkenansicht heißt zur Unterscheidung DoT-Balken.
• Haupteffekte folgen der gewählten Priorität; vier Zusatzeffekte, eigener unterstützender Fluch und Execute-Schwerter bleiben sichtbar. Mindestens einen Hauptplatz in der DoT-Anordnung auswählen.

|cffdfbd621.7.2 – Balkenansicht und Hauptfenster-Transparenz|r  |cffaaaaaa18.10.2026|r
• Neue Balkenansicht auf Vorschlag von BenTheMan: DoT-Balken je Gegner in der gewählten Prioritätsreihenfolge, mit Restzeiten. Standard / Matrix / Balken direkt auswählen; ausgeblendete Zaubernamen sparen Breite.
• HP-Prozente stehen in der Balkenansicht im Lebensbalken: ab 70% links, darunter rechts. Standard und Matrix behalten ihre gespeicherte Lebensanzeige. Vier Zusatzsymbole am Porträt, unterstützender Fluch und Raidmarker bleiben sichtbar.
• Neuer Transparenzregler von 0–80% ausschließlich für das Hauptfenster. Kürzerer Fensterkopf mit Autorenname bei unveränderten Fenstermaßen. Handlungsvorschläge bleiben optional, experimentell und bei Neuinstallation ausgeschaltet. Sie rechnen mit unbegrenzter Gegnerlebensdauer; ein Zauberabschluss bestätigt keinen Treffer.

|cffdfbd621.7.2-beta3 – Kürzerer Fensterkopf|r  |cffaaaaaa18.10.2026|r
• „created“ aus dem Fensterkopf entfernt, damit bei ausgeblendeten Zaubernamen mehr Platz bleibt. Version, Autorenname und Fenstermaße bleiben erhalten.

|cffdfbd621.7.2-beta2 – Lebensbalken und gezielte Transparenz|r  |cffaaaaaa18.10.2026|r
• Fehlende Lebensbalken in der Balkenansicht bei zuvor gespeicherter Prozentanzeige korrigiert. Balken zeigt nun stets Lebensbalken mit HP-Prozenten; Standard und Matrix behalten ihre eigene Auswahl.
• Transparenz auf das Hauptfenster begrenzt. Einstellungen, Auswertung, Archiv und Diagnose bleiben deckend.

|cffdfbd621.7.2-beta1 – Balken und Transparenz (Beta)|r  |cffaaaaaa18.10.2026|r
• Neue Balkenansicht auf Vorschlag von BenTheMan: bis zu acht gewählte Haupteffekte je Gegner in Prioritätsreihenfolge, mit Restlaufbalken und Zeiten. Drei direkte Ansichtsschalter; optionale Zaubernamen sparen Breite.
• Vier Zusatzeffekte am Porträt, eigener unterstützender Fluch und Raidmarker. HP-Prozente im Lebensbalken stehen ab 70% links, darunter rechts.
• Gemeinsamer Transparenzregler von 0–80% für Cursive-Fenster; die Auswahl wird gespeichert. Erste Beta der neuen Ansicht.

|cffdfbd621.7.1 – Wartungsrelease für Client 70450|r  |cffaaaaaa17.10.2026|r
• Clientangaben auf WoW Forever 1.60.1 (70450), Release x64, Build vom 15.10.2026 aktualisiert. Die im Spiel beobachteten Funktionen liefen auf dem neuen Client; keine Funktionsänderung.

|cffdfbd621.7.0 – Standard und Matrix, kompakte Zusatzanzeigen|r  |cffaaaaaa16.10.2026|r
• Neue Matrixansicht mit gemeinsamen Zauberspalten, Restzeiten je Gegner, kompakten Porträts, Lebensbalken und Execute-Schwertern. Bis zu acht Hauptfamilien aller neun Klassen, einschließlich Zermürben. Standard bleibt voreingestellt und wird durch kleinere Abstände schmaler.
• Beide Ansichten zeigen vier Zusatzsymbole in zwei Zweierreihen. Fluchsymbol und Zeiten bleiben innerhalb des Zielrahmens; Ansichtswechsel bewahren gemerkte Gegner außerhalb der Sicht.
• Fluchwächter korrigiert: Ein anderer unterstützender Fluch, auch Tollkühnheit, lässt die Erinnerung an den zugewiesenen Fluch wieder erscheinen. Handlungsvorschläge bleiben optional und experimentell; ein Zauberabschluss bestätigt keinen Treffer.

|cffdfbd621.7.0-beta6 – Fluchwechsel im Fluchwächter (BETA)|r  |cffaaaaaa16.10.2026|r
• Fluchwächter korrigiert: Nach Schwäche → Tollkühnheit erscheint die Erinnerung an Schwäche wieder. Die drei zuweisbaren Flüche bleiben unverändert; Omen der Pein und Verdammnis werden getrennt behandelt.
• Fluchwechsel bleiben beim ursprünglich zugeordneten Gegner, auch nach einem Zielwechsel. Fehlgeschlagene oder nicht eindeutig zuordenbare Versuche ändern keine fremde Erinnerung; ein Zauberabschluss ist kein Trefferbeweis.

|cffdfbd621.7.0-beta5 – Freier Matrix-Zielrahmen (BETA)|r  |cffaaaaaa16.10.2026|r
• Überdeckung des goldenen Matrix-Zielrahmens durch Fluchsymbol und Zeitfläche behoben. Ohne Vorschläge etwas mehr Innenabstand; Standard und Matrix mit Vorschlägen behalten ihre Maße.

|cffdfbd621.7.0-beta4 – Vier Zusatzplätze und stabile Matrix (BETA)|r  |cffaaaaaa16.10.2026|r
• Zusatzbereich beider Ansichten auf vier Symbole in zwei Zweierreihen verkleinert. Zeiten stehen in Standard darunter, in Matrix daneben; der Porträtfluch bleibt getrennt.
• Vorübergehend falsche Porträtgrößen, Trennlinien und Fluchpositionen nach Aura-Aktualisierungen in Matrix korrigiert.
• Fluch und Zusatzsymbole erhalten oben und unten Innenabstand. Bei verzögertem Ansichtswechsel bleiben vorhandene Anzeigen außer Sicht erhalten.

|cffdfbd621.7.0-beta3 – Kompaktere Matrix (BETA)|r  |cffaaaaaa16.10.2026|r
• Matrix ohne Vorschläge deutlich flacher: kleinere Überschrift und Porträts, engere Zeitspalten. Vorschläge behalten ihren bisherigen Platz.
• Lebenspunkte im Balken und Execute-Schwerter am Porträt. Die Prozentanzeige behält beide Lebenswerte; Standard wird beim Rückwechsel vollständig wiederhergestellt.

|cffdfbd621.7.0-beta2 – Sichere Einrichtung von Standard und Matrix (BETA)|r  |cffaaaaaa16.10.2026|r
• Beta1-Rückschritt mit überhohen Zeilen, großen Fluchsymbolen und wirkungsloser Matrixauswahl korrigiert.
• Ansichtswechsel warten bei erhaltenen Auren außerhalb der Sicht; die Auswahl zeigt die aktive oder vorgemerkte Ansicht. Darstellungsfehler vermischen Standard und Matrix nicht mehr.

|cffdfbd621.7.0-beta1 – Matrixansicht und schmalerer Standard (BETA)|r  |cffaaaaaa16.10.2026|r
• Standard und Matrix unter Kampfanzeige auswählbar. Matrix zeigt bis zu acht feste Hauptspalten mit gemeinsamen Symbolköpfen und Restzeiten je Gegner; acht Zusatzeffekte stehen daneben.
• Standard wird durch geringere, gleichmäßige Abstände zwischen Porträt, Fluch und Trennlinie schmaler. Zermürben als Auswahl ergänzt, sodass alle fünf Hexer-DoTs gemeinsam wählbar sind; Klassenkataloge aller neun Klassen bleiben verfügbar.
• Nicht sofort mögliche Ansichtswechsel werden bei Gegnern außer Sicht vorgemerkt; erneuter Klick storniert den Wunsch. Erste Beta der Matrixansicht.

|cffdfbd621.6.2 – Überarbeitete kompakte Gegneranzeige|r  |cffaaaaaa16.10.2026|r
• Kompakte Standardansicht mit Porträts, gleichmäßigen Zeilen, ausgerichteten Haupt-DoTs, Zeiten und Execute-Hinweis. Ein Fluchplatz am Porträt; acht Zusatzsymbole in zwei Viererreihen. Überflüssiger Seitenstreifen entfällt.
• Bei nur einer Gegneransicht entfällt der Standard-Auswahlschalter. Kontakt & Rückmeldung liegt im Vordergrund. Fensterkopf bleibt ausblendbar; Handlungsvorschläge bleiben optional und experimentell.
• Clientangabe auf WoW Forever 1.60.1 (70425), Release x64, Build vom 14.10.2026 aktualisiert. Bisherige Spielprüfungen erfolgten auf 70374.

|cffdfbd621.6.2-beta5 – Zusatzsymbole bündig ausgerichtet (BETA)|r  |cffaaaaaa16.10.2026|r
• Acht Zusatzsymbole in zwei Viererreihen bündig zu den Haupt-DoTs angeordnet; ein Fluchplatz bündig zum Porträt ersetzt die unnötige Reserve für zwei Flüche.
• Ohne Vorschläge zehn Pixel weniger Höhe je Gegnerzeile bei gleicher Breite. Vorschläge behalten ihren Beschriftungsplatz.

|cffdfbd621.6.2-beta4 – Neue Standardansicht (BETA)|r  |cffaaaaaa16.10.2026|r
• Die aktuelle Porträtansicht heißt Standard; Kompakt und die bisherige Minimal-Auswahl entfallen. Gespeicherte Zielansichten wechseln auf Standard. FULL/minimal bleibt die unabhängige Auswahl für das Optionsfenster.
• Überflüssigen grün/goldenen Seitenstreifen entfernt; Zielrahmen, Porträtring und Raidmarker bleiben erhalten.

|cffdfbd621.6.2-beta3 – Rückmeldungsfenster im Vordergrund (BETA)|r  |cffaaaaaa16.10.2026|r
• Kontakt & Rückmeldung liegt über dem Optionsbuch. Verdeckte Schaltflächen reagieren nicht mehr auf Klicks durch den Dialog; Kopieren, Escape und Schließen bleiben nutzbar.

|cffdfbd621.6.2-beta2 – Flüche rechts am Porträt (BETA)|r  |cffaaaaaa16.10.2026|r
• Unterstützende Flüche mit eigenen Zeiten rechts oben am Porträt angeordnet. Kompakt/Minimal wird mit dieser Option geringfügig breiter.
• Jede Gegnerzeile unten zehn Pixel kürzer; Execute! rückt zur Unterkante der DoT-Zeiten hoch. Symbol• und Schriftgrößen bleiben erhalten.

|cffdfbd621.6.2-beta1 – Weniger senkrechter Platzbedarf (BETA)|r  |cffaaaaaa16.10.2026|r
• Obere und untere Zeilenränder verkleinert; Gegnerzeilen bleiben gleichmäßig angeordnet. Hauptsymbole, Schrift, Zeitbänder und Breite bleiben erhalten.
• Bei einer Symbolreihe mit Porträtflüchen nur das Porträt verkleinert, damit beide Fluchzeiten in den Rahmen passen. Vorschläge und Execute folgen der gemeinsamen Ausrichtung.

|cffdfbd621.6.1 – Execute-Hinweis und ausblendbarer Fensterkopf|r  |cffaaaaaa15.10.2026|r
• Execute-Hinweis mit Schwertern unter der Lebensanzeige: Automatisch, unter 35%, unter 20% oder Aus. Automatisch berücksichtigt passende gelernte Fähigkeiten/Talente; die manuellen Schwellen wurden im Spiel bestätigt, die automatische Erkennung noch nicht.
• Fensterkopf einschließlich Autorenzeile ausblendbar; danke an AbelBeja für den Vorschlag! Ohne Kopf bleibt das entsperrte Fenster am Hintergrund verschiebbar. Kontakt unter Hilfe & Info.
• Gemeinsame DoT-Priorität, kompakte Zeilen und Todesmeldungen der Beta-Reihe übernommen. Vorschläge bleiben optional und experimentell; sie rechnen weiterhin mit unbegrenzter Gegnerlebensdauer.

|cffdfbd621.6.1-beta5 – Execute-Hinweis und Fensterkopf (BETA)|r  |cffaaaaaa15.10.2026|r
• Execute-Hinweis ergänzt: Automatisch (Vorgabe), unter 35%, unter 20% oder Aus. Automatisch berücksichtigt Dezimierung, Exitus, Hinrichten, Hammer des Zorns sowie Early Demise mit erlerntem Schattenwort: Tod. Feste Schwellen sind klassenunabhängig; der Hinweis zeigt keine unmittelbare Zauberbereitschaft.
• Schwerter und Execute! nutzen den Platz unter der Lebensanzeige. Ohne aktuelle Gegnerdaten bleibt ein vorhandener Hinweis abgeblendet.
• Fensterkopf unter Allgemein ausblendbar, auch im leeren Fenster. Verschieben bleibt am Hintergrund möglich; Urheber und kopierbarer CurseForge-Kontakt stehen unter Hilfe & Info.

|cffdfbd621.6.1-beta4 – Todesmeldungen für gemerkte Gegner (BETA)|r  |cffaaaaaa15.10.2026|r
• Passende Todesmeldungen entfernen gemerkte Gegner samt Effekten und Vorschlägen auch ohne aktuell erreichbares Ziel. Doppelte oder unbekannte Meldungen entfernen keine fremden Zeilen.
• Lebende Gegner bleiben beim Wegdrehen erhalten. Eine lückenlose Erkennung jedes Todes außerhalb der Sicht ist weiterhin nicht zugesichert.
• /cftrace zeigt die neue Todesbereinigung; eine separate Probe ist nicht mehr erforderlich.

|cffdfbd621.6.1-beta3 – Kompakte, gleichmäßige Zeilen (BETA)|r  |cffaaaaaa15.10.2026|r
• Gleichmäßige Ränder ober• und unterhalb der Haupt-DoTs verkürzen Gegnerzeilen. Zusatzsymbole wandern in zwei kleine Reihen rechts; freie Breite wird zuerst genutzt.
• Porträtflüche und eigene Zeitanzeigen bleiben erhalten. Auftauchende oder ablaufende Effekte verändern die Fenstergröße nicht.

|cffdfbd621.6.1-beta2 – Gemeinsame Reihenfolge und Anordnung (BETA)|r  |cffaaaaaa15.10.2026|r
• Die DoT-Anordnung bestimmt nun zugleich die Vorschlagspriorität; beide verwenden eine gemeinsame gespeicherte Reihenfolge.
• Porträt, Hauptsymbole und Vorschläge ausgerichtet; Zeiten darunter, Status und Aktionsnummern darüber.
• Erstanwendungen heißen „Setzen“, laufende Versuche „Zaubert“. Während des Zaubers wird nicht schon seine spätere Erneuerung als „in 14s“ angezeigt.

|cffdfbd621.6.1-beta1 – Erstanwendungen (BETA)|r  |cffaaaaaa15.10.2026|r
• Geschätzte Erstanwendungen in vollständig von Beginn an erfassten Kämpfen ergänzt. So kann fehlender Feuerbrand vor späteren Erneuerungen stehen; fällige höher priorisierte DoTs behalten Vorrang.
• „~“ kennzeichnet die Annahme, keinen Nachweis einer fehlenden Aura. Bei unvollständigem Verlauf, etwa nach Neuladen im Kampf, bleibt die Anwendung unbekannt.
• Laufende Zauber belegen ihre Zeit; Abbruch gibt den Vorschlag wieder frei. Automatische Treffer-/Fehlschlagerkennung fehlt weiterhin, manuelle Korrektur bleibt möglich.

|cffdfbd621.6.0 – Anzeige-Release|r  |cffaaaaaa15.10.2026|r
• Lebensbalken oder Prozent, bis zu acht feste Effektplätze, Porträtflüche und FULL/minimal-Optionen gemeinsam veröffentlicht. Lebensbalken sind auf Anregung von thermanshs voreingestellt; gespeicherte Einstellungen und Archiv bleiben erhalten.
• Wegdrehen erhält Gegnerzeile und letzte HP-Anzeige. Passende verfügbare Ziele können Auren weiter aktualisieren; bestätigter Tod entfernt Zeile und Vorschläge. Ohne passende Zuordnung kann das Aura-Raster dennoch leer werden; unbeobachtete Tode sind nicht sofort erkennbar.
• Optionale experimentelle Hexer-Vorschau mit zwei globalen Aktionen und bis zu zwei je Zeile, nach Priorität, Ablaufzeit und Zauberdauer. Gegnerleben wird unbegrenzt angenommen; keine gemessene Schadensoptimierung oder automatische Trefferbestätigung. Beobachtete Fehlschläge per Rechtsklick korrigierbar; unbekannte Erstanwendungen bleiben offen.
• Die letzten fünf anonymisierten Kampfberichte über /cftrace 1 bis 5 abrufbar; laufende Aufzeichnungen bleiben beim erneuten Einschalten erhalten.

|cffdfbd621.6.0-experimental9 – Aufzeichnungen erhalten (EXPERIMENTAL)|r  |cffaaaaaa15.10.2026|r
• Die fünf letzten Berichte mit Nummer, Startzeit und Dauer speichern; Auswahl über /cftrace 1 bis 5. /cftrace ohne Zahl zeigt den laufenden oder letzten Bericht.
• Erneutes Einschalten setzt laufende Aufzeichnungen nicht zurück; Mitschnitte ab Kampfmitte werden gekennzeichnet. Die bekannte kurze Aura-Rasterlücke bleibt offen.

|cffdfbd621.6.0-experimental8 – Todesprüfung und Ersatzzuordnung (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Letzte lesbare Todeshinweise beim Verlust eines Gegners berücksichtigen; nur eindeutig passende Gegner werden entfernt.
• Vor dem Leeren der Aura-Anzeige nach einem passenden Ersatzziel suchen, nun auch beim Begleiter und Ziel des Ziels. Keine Daten fremder Gegner übernehmen.
• Ohne passende Zuordnung kann das Raster weiterhin leer werden. Zeile und letzte HP bleiben erhalten und beweisen weder Leben noch fortbestehende Auren.

|cffdfbd621.6.0-experimental7 – Bewährte Anzeige wiederherstellen (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Bewährte Anzeige beim Wegdrehen wiederhergestellt: letzte HP, Lebensbalken und vorhandene DoT-Zähler bleiben stehen; der zusätzliche Hinweis „Außer Sicht“ entfällt. Gemerkte HP sind keine frischen Messwerte.
• Aura-Aktualisierung über das weiterhin angewählte passende Ziel wiederhergestellt; Zielwechsel übertragen keine fremden Daten.

|cffdfbd621.6.0-experimental6 – Zauberdiagnose (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• /cftrace um anonymisierte Zauberentscheidungen ergänzt, um unpassende Empfehlungen trotz frisch sichtbarer DoTs einzugrenzen. Der Bericht bestätigt keine Treffer.
• Reine Diagnoseergänzung; die beobachtete Verderbnis-Abweichung wird damit noch nicht behoben.

|cffdfbd621.6.0-experimental5 – Frühe Aura-Aktualisierung (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Vorhandene DoT-Zähler bleiben auch erhalten, wenn eine Aura-Aktualisierung kurz vor dem Entfernen der Namensplakette eintrifft.
• Automatische begrenzte Ereignisaufzeichnung ergänzt: /cftrace zeigt den letzten Kampf zum Kopieren; on/off/clear steuern die Aufzeichnung. Namen, HP und Aura-Inhalte werden nicht aufgezeichnet.

|cffdfbd621.6.0-experimental4 – Wegdrehen wieder abgesichert (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Vorhandene DoT-Anzeigen beim Wegdrehen wieder erhalten, auch bei ausgeschalteten Vorschlägen. Gemerkte Schätzungen bleiben mit „~“ in der globalen Prioritätsfolge.
• Rückkehr, Tod und wiederverwendete Namensplaketten sicherer unterscheiden. Ein fremder Gegner ersetzt keine gemerkte Zuordnung; unbeobachtete Zeit erzeugt keine zusätzlichen Auswertungsticks.

|cffdfbd621.6.0-experimental3 – Lua-Fehler beim Statushinweis (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Lua-Fehler beim Anzeigen des unbekannten Gegnerzustands behoben; Statushinweis in allen drei Ansichten korrekt ausgerichtet.

|cffdfbd621.6.0-experimental2 – Gegnerzustände und Vorschau (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Bei nicht erreichbaren Gegnern veraltete HP und Aura-Zähler durch einen unbekannten Zustand ersetzen; fehlende Sichtbarkeit allein zählt nicht als Tod. Bestätigte Tode entfernen Zeile und Vorschläge.
• Ein-/Ausschalten der Vorschau erhält den Zauberverlauf. Unbekannte DoT-Zeiten erzeugen keine sofortige Erstanwendung. Grün 1 bedeutet jetzt, Gold 1 später, Blau 2 danach.
• „Zauber ?“ bleibt nach unbestätigtem Abschluss für eine manuelle Fehlschlagkorrektur per Rechtsklick erreichbar. Keine automatische Treffererkennung.

|cffdfbd621.6.0-experimental1 – Geschätzte Vorschläge (EXPERIMENTAL)|r  |cffaaaaaa13.10.2026|r
• Optionale experimentelle Hexer-Vorschau für Omen, Verderbnis und Feuerbrand: zwei Vorschläge je Gegner, global nächste und folgende Aktion. Fällige Prioritäten gelten über alle Gegner; Zauberzeit und globale Abklingzeit werden berücksichtigt.
• „?“ bedeutet unbekannte Anwendung, „~“ eine Schätzung. Zauberabschlüsse bestätigen keine Treffer; Mauszeiger-/Fokusmakros werden nicht unterstützt. Keine Restlebenszeit• oder Schadensoptimierung.
• /cfexp öffnet Einstellungen für Priorität, Effekte und Zeiten; on/off/reset sowie miss immolate|agony|corruption steuern die Vorschau. Alt-Rechtsklick korrigiert einen beobachteten Fehlschlag.

|cffdfbd621.6.0-beta2 – Platz im Grimoire|r  |cffaaaaaa13.10.2026|r
• Rechte Kampfanzeige-Seite im Grimoire aufgeräumt: DoT-Anordnung und Autoreninschrift überlagern sich nicht mehr.

|cffdfbd621.6.0-beta1 – Flexible DoT-Anordnung|r  |cffaaaaaa13.10.2026|r
• Ablaufsortierung oder bis zu acht feste DoT-Plätze wählen, speichern und über /cf dots anordnen. Vier Plätze je Reihe; weitere eingeschaltete Effekte bleiben kleiner sichtbar.
• Eigene unterstützende Flüche in Kompakt/Minimal optional unten am Porträt, für Hexer voreingeschaltet. Freie Hauptplätze sind keine Erneuerungsempfehlung.
• Lebensbalken bleiben auf Anregung von thermanshs voreingestellt. Gespeicherte Auswahl und Klassen-/Gruppenfilter bleiben erhalten.

|cffdfbd621.5.0-beta3 – Lebensbalken als Voreinstellung|r  |cffaaaaaa13.10.2026|r
• Der von thermanshs angeregte Lebensbalken wird zur Voreinstellung für neue Installationen und bislang nicht gesetzte Lebensanzeigen. Gespeicherte Prozentanzeige bleibt erhalten; jederzeit umschaltbar.

|cffdfbd621.5.0-beta2 – Korrekturen aus dem Spieltest|r  |cffaaaaaa13.10.2026|r
• Lua-Fehler beim Wechsel zwischen Lebensbalken und Prozent im Kampf korrigiert.
• Weiße Schaltflächen nach FULL → minimal behoben; Farben werden sofort wiederhergestellt. Der Lebensbalken auf Wunsch von thermanshs bleibt enthalten.

|cffdfbd621.5.0-beta1 – Community-Wunsch|r  |cffaaaaaa13.10.2026|r
• Auf Wunsch von thermanshs Lebensbalken als Alternative zur HP-Prozentanzeige ergänzt. Unter Kampfanzeige umschaltbar, sofort wirksam und gespeichert; Prozent bleibt zunächst voreingestellt.
• In allen drei Gegneransichten und beiden Optionsdesigns verfügbar, mit Grün/Gelb/Rot. Fehlende Lebensdaten zeigen einen unbekannten Zustand.

|cffdfbd621.4.7-beta1 – Testfassung|r  |cffaaaaaa12.10.2026|r
• Verarbeitung geschützter oder unlesbarer Gegner• und Kampfdaten abgesichert. Unbekannte Überlebenszeit wird nicht als gemessener Prozentwert ausgegeben.
• Veraltete Marker• und persönliche Flucherinnerungen regelmäßig bereinigt; aktuelle Ziele und gespeicherte Kämpfe bleiben erhalten. Zielwechsel verwerfen mehrdeutige Erinnerungen.

|cffdfbd621.4.6 – Wartungsrelease|r  |cffaaaaaa12.10.2026|r
• Falsche 0-%-Abdeckung bei unbestätigten Zauberzielen behoben; Schadenszuordnung früh angelegter Kampfsitzungen verbessert.
• Die Wartungskorrekturen aus 1.4.5 übernommen. Gesperrte Aura-Zeiten, mehrdeutige Ziele und Beobachtungslücken bleiben als unbekannte Werte erkennbar; vorhandene Archive bleiben erhalten.

|cffdfbd621.4.5 – Wartungsrelease|r  |cffaaaaaa12.10.2026|r
• Schaden zuverlässiger dem eigenen Kampf zuordnen. Unbekannter Schaden bleibt „—“, ein Teilstand trägt „≥“; mehrdeutige Zauberziele werden nicht dem angewählten Gegner zugeschrieben.
• Abdeckung und Tickmodell pausieren bei unbeobachtbaren Gegnern; Folgebosse erhalten getrennte Aufzeichnungen. Bildpausen zählen zur Kampfdauer, aber nicht als beobachtete Abdeckung.
• Flucherinnerung unterscheidet „FLUCH UNBESTÄTIGT“ und „ERINNERUNG ABGELAUFEN“. Gesperrte Abfragen behaupten keinen fehlenden Fluch. Korrekturen gelten für neue Aufzeichnungen; alte Werte bleiben erhalten.

|cffdfbd621.4.4 – Release|r  |cffaaaaaa11.10.2026|r
• Optionen in Allgemein, Kampfanzeige, Auswertung und Hilfe & Info gegliedert, mit einheitlichen Bedienelementen und Anpassung an die Bildschirmgröße.
• FULL als voreingestelltes Optionsdesign: Gul’dans düsteres Grimoire mit Vorwärts-/Rückwärtsblättern. minimal bietet dieselben Einstellungen schlicht; die Auswahl bleibt gespeichert.
• Klassenfilter für alle neun Klassen, bis zu fünf auswählbare und sortierbare Raben-Karten sowie Charakterarchiv. Gesperrte Aura-Werte bleiben als „Client-Sperre / Unbestätigt“ sichtbar.

|cffdfbd621.4.4-beta|r  |cffaaaaaa11.10.2026|r
• Gespiegelte Titel und Signaturen beim Umblättern korrigiert; beide Blattseiten bleiben deckend. Signatur erscheint nur auf der bedruckten rechten Seite.
• Gul’dans Gesicht, Hände und Rüstung dunkler gestaltet; Fel-Glut bleibt sichtbar.

|cffdfbd621.4.3-beta|r  |cffaaaaaa11.10.2026|r
• Autorensignatur bewegt sich beim Vorwärtsblättern mit dem Blatt und wird beim Rückwärtsblättern korrekt verdeckt.

|cffdfbd621.4.2-beta|r  |cffaaaaaa11.10.2026|r
• Abgeschnittene FULL-Grafik durch vollständige Außenkontur ersetzt, Pergament nachgedunkelt und Cursive/Forever in die Buchüberschriften eingebunden.
• Verzierte Buchschließe für FULL/minimal und besser platzierte Signatur ergänzt; Umblättern an die neue Grafik angepasst.

|cffdfbd621.4.1-beta|r  |cffaaaaaa11.10.2026|r
• Lua-Fehler beim Aufbau der Buchsignatur und den daraus entstehenden Folgefehler beim erneuten Öffnen der Optionen behoben.

|cffdfbd621.4.0-beta|r  |cffaaaaaa11.10.2026|r
• Erste spielbare FULL-Optionsansicht mit Gul’dans Grimoire, vier Kapiteln, Reglern auf den Buchseiten und animiertem Vorwärts-/Rückwärtsblättern. minimal bleibt wählbar.
• Feste Autorensignatur ergänzt; Designwahl wird unabhängig von der Gegneransicht gespeichert. Direktaufruf über /cf grimoire, /cf full und /cf minimal.

|cffdfbd621.3.3-beta|r  |cffaaaaaa11.10.2026|r
• Häkchenbeschriftungen direkt am Schalter ausgerichtet und Speicherhinweis aus der Eckverzierung verschoben. Reiterränder verlieren ihre Hervorhebung wieder korrekt.

|cffdfbd621.3.2-beta|r  |cffaaaaaa11.10.2026|r
• Vier Optionsreiter mit einheitlichen Knöpfen, Spalten und Reglern eingeführt. Niedrigeres Fenster passt sich Bildschirm und UI-Skalierung an.
• Schließknöpfe im Braun-/Goldthema; Sprachwechsel aktualisiert auch verdeckte Seiten. Gegnerübersicht und Performancefenster behalten ihre Größe.

|cffdfbd621.3.1-beta|r  |cffaaaaaa11.10.2026|r
• Fehlende Pfeilzeichen der Kartensortierung durch lesbare „Auf“/„Ab“-Schalter ersetzt; kleine Schalter bleiben frei von Ziersymbolen.

|cffdfbd621.3.0-beta|r  |cffaaaaaa11.10.2026|r
• Zauberfilter für alle neun Klassen mit getrennten Einstellungen für Solo, Gruppe und Raid. Bekannte Ränge aus dem Zauberbuch ergänzen; unbekannte Effekte bleiben sichtbar.
• Bis zu fünf Raben-Karten je Charakter über /cf karten auswählen und sortieren; unbenutzte Karten optional ausblenden. Ausgeblendete Effekte werden weiter aufgezeichnet; alte Kämpfe bleiben erhalten.
• Weihe ergänzt, Jägerfallen und Tiefe Wunden besser zugeordnet. Flächeneffektkarten zeigen Schadenssummen und Anteile, keine abgeleiteten Ziel• oder Tickwerte.

|cffdfbd621.2.12-beta|r
• Wiederholte Fehler bei gesperrten Aura-Daten vermieden. Betroffene Karten, Zielfilter und Details zeigen „Client-Sperre“; Schaden und Zauberzahlen bleiben sichtbar.
• Lesbare Anwendungen können weiterhin bestätigt werden. Leere oder gesperrte Antworten sind kein Fehlschlagnachweis; fehlende Aura-Zeiten werden nicht ersetzt.

|cffdfbd621.2.11-beta / 1.2.10-beta|r
• Unbestätigte Aura-Werte zeigen „—“ statt falscher Nullwerte; Ursache der Client-Sperre genauer eingegrenzt.
• DoT-Detailhintergrund deckend und Informationstafel verbessert.

|cffdfbd621.2.8 / 1.2.9-beta|r
• Performance-Monitor mit DoT-Details und geschätztem Tickmodell ergänzt.
• Eröffnungszauber besser erfassen; unsichere Anwendungen als unbestätigt kennzeichnen.

Die vollständige Versionsgeschichte steht in VERSIONSHISTORIE.txt.
English release notes: CHANGELOG.txt.
]]

CF.CHANGELOG_EN = [[
Latest client reference from previous in-game checks: WoW Forever 1.60.1 (70450), Release x64 — client build 15 October 2026.

|cffdfbd621.9.1 – Utility curses as main effects|r  |cffaaaaaa22.10.2026|r
• Curse of Weakness, Tongues, Recklessness, Exhaustion and the Elements can now be selected as Main under Spells & alerts in all four views. Thanks to thermanshs for the suggestion.
• Selected curses use the normal main-effect order and count toward the eight main slots. They no longer also appear in the small curse or extra-effect display.
• With fixed positions and Click to cast enabled, learned main curses can be cast on focus or target like other main spells. They stay visible when extra icons are disabled.
• Existing selections are preserved. The Raid Curse Watcher remains independently configured.

|cffdfbd621.9.0 – Click casting on focus and target|r  |cffaaaaaa21.10.2026|r
• Left-click a learned main spell to cast it on your focus or current target. Works with fixed positions in Standard, Matrix, DoT bars and Health bars, including empty slots. Thanks to Myia for the suggestion.
• Focus stays at the top: Standard and Health bars show Focus below the portrait; Matrix and DoT bars use a larger F beside it. The current target follows with the familiar target highlight. Other tracked enemies remain display-only.
• Switching focus or target refreshes that row’s effects, including extra effects and utility curses. When focus and target are the same enemy, both rows update together.
• Enemies remembered outside your view no longer inherit another enemy's raid marker or marker-based sorting priority.
• When focus and target are the same enemy, both role rows stay visible, just like the normal target and focus frames. Suggestions count that enemy once.
• Click casting is enabled by default for fixed layouts and can be disabled under Spells & alerts. Expiring first retains the ordinary display.
• While click casting is active, change layout, size, position and window visibility outside combat. The window still follows its saved out-of-combat visibility setting.
• Focus casts use the identified recipient in suggestions and fight records. Ambiguous recipients remain unconfirmed; a completed cast is still not proof of a hit.

|cffdfbd621.8.0 – Clearer settings and one shared spell list|r  |cffaaaaaa20.10.2026|r
• Options now has four clearly named pages: Display, Spells & alerts, Review, and General & help. Both the grimoire and minimal design use this organization.
• Display brings together view selection, sorting, size, transparency, header, frames, extra icons and out-of-combat visibility.
• Spells & alerts combines spell filters, main slots and priority in one list. Solo, dungeon and raid filters stay separate. /cf dots and /cf filters open this page directly.
• Execute has four direct choices: Automatic, Below 35%, Below 20% and Off. Suggestions, raid-marker priority and the Curse Watcher are grouped alongside it.
• Existing settings are retained. Unavailable choices are dimmed with explanations, and longer pages can be scrolled.
• Curse of the Elements can now be enabled in the spell list, uses the shared utility-curse place and can be assigned in the Curse Watcher.
• Demonic Brand and Shadow Vulnerability (Improved Shadow Bolt) can now be chosen as main effects or extra icons. Thanks to thermanshs for these spell requests.

|cffdfbd621.7.8 – Compact Standard rows and display options|r  |cffaaaaaa20.10.2026|r
• Standard with Expiring first no longer reserves an empty second large icon row when extra icons are enabled. Up to four selected main effects fit in one row; five to eight retain their second row.
• Main effects keep their expiration order. Up to four additional effects use the compact two-by-two area, matching the fixed-order view.
• Switching between fixed and expiration order waits when necessary to preserve running timers on enemies outside your view.
• Adjust Duration sweep opacity from 0–100% in DoT layout (default: 58%). Apply the change outside combat with Apply and reload UI. Thanks to Myia for the suggestion.
• Add Hide window out of combat under Combat display, off by default. The tracker returns when combat starts unless manually hidden; Options remain accessible.

|cffdfbd621.7.7-beta1 – Duration sweep opacity and combat visibility|r  |cffaaaaaa20.10.2026|r
• Adjust Duration sweep opacity from 0–100% in DoT layout. The current 58% remains the default. Thanks to Myia for the suggestion.
• Apply a changed sweep opacity with Apply and reload UI while out of combat. It affects the dark veil on icons; Matrix numbers and DoT bars keep their appearance.
• Add Hide window out of combat under Combat display, off by default. The entire tracker returns when you enter combat; manually hiding it still takes precedence. Options and other windows remain accessible.
• The requested expiration glow is not included in this beta.

|cffdfbd621.7.6 – Frameless tracking and clearer target selection|r  |cffaaaaaa20.10.2026|r
• The visible window header stays fully opaque when tracker transparency is increased.
• Enable extra icons and Hide frame are available in all four views. Hiding extra effects and the separate utility curse makes the tracker narrower; main DoTs, raid markers and Execute indicators remain visible.
• Hide frame removes the background, outer frame and row borders with less outer padding. A green bracket on the left marks your selected enemy in every frameless view.
• In Health bars, the row-height slider now changes the visible health bar height as well as row spacing. Text and icons keep their size; minimum dimensions preserve readability. At 100%, the familiar layout is retained.
• Extra icons start enabled and frames remain visible by default. The header can still be switched independently.

|cffdfbd621.7.6-beta1 – Optional frames and extra icons|r  |cffaaaaaa20.10.2026|r
• The visible window header stays fully opaque when tracker transparency is increased.
• New shared options for Standard, Matrix, DoT bars and Health bars: Enable extra icons (on by default) and Hide frame (off by default).
• Disabling extra icons hides additional effects and the separate utility curse, reclaiming their space. Main DoTs, raid markers and Execute indicators remain visible.
• Hide frame removes the window background, outer frame and row borders, with less outer padding. The header remains independently switchable.
• In Standard with Expiring first, changing extra icons may wait until an enemy outside your view can be refreshed or combat ends, preserving its running timers.

|cffdfbd621.7.5 – More flexible tracker sizing|r  |cffaaaaaa19.10.2026|r
• The main tracker can now be scaled down to 40%, with a range of 40–130% in 5% steps.
• Adjust width and row height independently for Standard, Matrix, DoT bars and Health bars. Icons and text keep their proportions; space needed for the contents limits how far each dimension can shrink.
• Each view remembers its dimensions and can reset them to 100%. Your saved overall scale is retained; new settings start at 100%.

|cffdfbd621.7.4 – Clearer sorting controls|r  |cffaaaaaa18.10.2026|r
• DoT layout now shows two direct choices under Order: Fixed order / Expiring first. The active choice stays visible; tooltips explain both options.
• Health bars now follows the same sorting choice as Standard: keep effects in fixed positions or show the effects with the shortest remaining time first.
• Matrix and DoT bars keep your configured fixed effect order. Your saved sorting preference is retained.

|cffdfbd621.7.3 – Health bars view|r  |cffaaaaaa18.10.2026|r
• New fourth view, requested by thermanshs: portrait and raid marker on the left, a large health bar with enemy name, current/maximum HP and percentage in the middle, and effect icons with countdowns on the right.
• Four direct choices: Standard / Matrix / DoT bars / Health bars. The previous Bars view is now called DoT bars.
• Longer enemy names have more room inside the health bar without increasing window width or row height.
• Main effects follow your priority. Four additional effects, your utility curse and Execute swords remain available. Select at least one main slot in DoT layout.

|cffdfbd621.7.3-beta1 – New Health bars view (Beta)|r  |cffaaaaaa18.10.2026|r
• Fourth view requested by thermanshs: portrait and raid marker on the left, a large health bar with name, current/maximum HP and percentage in the middle, effect icons and countdowns on the right.
• Four direct choices: Standard / Matrix / DoT bars / Health bars. The existing Bars view is renamed DoT bars for clarity.
• Main effects follow your priority; four extras, your utility curse and Execute swords remain visible. Select at least one main slot in DoT layout.

|cffdfbd621.7.2 – Bars view and tracker transparency|r  |cffaaaaaa18.10.2026|r
• New Bars view requested by BenTheMan: DoT bars grouped by enemy in priority order, with countdowns.
• Choose Standard / Matrix / Bars directly. Hide spell names in Bars to save width.
• Bars always shows HP percentages inside health bars: left at 70% or above, right below. Standard and Matrix retain their saved health display.
• Transparency affects only the tracker. A shorter title retains the author without enlarging the window.
• Suggestions remain experimental and off by default, assume unlimited enemy life and do not confirm hits.

|cffdfbd621.7.2-beta3 – Shorter window title|r  |cffaaaaaa18.10.2026|r
• Remove “created” from the tracker title to fit narrow windows; retain version and author.

|cffdfbd621.7.2-beta2 – Health bars and tracker transparency|r  |cffaaaaaa18.10.2026|r
• Fix missing Bars health bars after selecting percentage display. Standard and Matrix retain their preference.
• Limit transparency to the main tracker; other windows remain opaque.

|cffdfbd621.7.2-beta1 – Bars and transparency (Beta)|r  |cffaaaaaa18.10.2026|r
• New Bars view requested by BenTheMan, grouped by enemy in priority order; select all three views directly.
• Optional spell names save width; extras sit near the portrait and in-bar HP percentages change sides at 70%.
• Add a saved transparency slider for Cursive windows.

|cffdfbd621.7.1 – Maintenance release for client 70450|r  |cffaaaaaa17.10.2026|r
• Update the client reference to WoW Forever 1.60.1 (70450), Release x64, built 15 October 2026. User-observed functions continued working; no feature changes.

|cffdfbd621.7.0 – Standard and Matrix, compact extra effects|r  |cffaaaaaa16.10.2026|r
• Release Matrix with shared spell columns and compact enemy rows alongside Standard; add Wrack selection.
• Both views show four additional effects in two rows of two; curses and countdowns stay inside the border.
• Fix the Curse Watcher after replacing an assigned curse with Recklessness or another utility curse.

|cffdfbd621.7.0-beta6 – Curse changes in the Curse Watcher (BETA)|r  |cffaaaaaa16.10.2026|r
• Restore the assigned-curse reminder after a competing utility curse, including Recklessness, is cast on that enemy.
• Target changes do not redirect the update; failed or unclear attempts do not replace other enemies' reminders.

|cffdfbd621.7.0-beta5 – Clear Matrix target border (BETA)|r  |cffaaaaaa16.10.2026|r
• Keep curse countdowns and both additional-effect rows clear of the Matrix target border; slightly increase row height without suggestions.

|cffdfbd621.7.0-beta4 – Four extra slots and stable Matrix (BETA)|r  |cffaaaaaa16.10.2026|r
• Use four additional-effect slots in two rows of two in both views, reducing empty space.
• Keep Matrix portraits, dividers and curses aligned after aura updates and improve border clearance.

|cffdfbd621.7.0-beta3 – More compact Matrix (BETA)|r  |cffaaaaaa16.10.2026|r
• Smaller Matrix rows and heading without suggestions, with smaller portraits and closer time columns.
• Move health numbers inside bars and Execute swords to the portrait; restore Standard fully when switching back.

|cffdfbd621.7.0-beta2 – Safe Standard and Matrix initialization (BETA)|r  |cffaaaaaa16.10.2026|r
• Fix oversized rows and utility curses, and Matrix selection failing to change the view.
• Delay switches while retaining offscreen effects; Matrix display errors no longer disrupt Standard.

|cffdfbd621.7.0-beta1 – Matrix view and narrower Standard (BETA)|r  |cffaaaaaa16.10.2026|r
• Add Matrix with shared spell headings and up to eight effect columns; Standard remains the default.
• Narrow Standard portrait/divider spacing and add Wrack to effect selection.
• Delay incompatible view switches while retaining offscreen effects. Client reference: 1.60.1 (70425).

|cffdfbd621.6.2 – Redesigned compact combat display|r  |cffaaaaaa16.10.2026|r
• Release compact, aligned Standard rows, eight additional effects in two rows of four and one portrait curse.
• Remove the redundant side stripe and single-view selector; fix the feedback dialog appearing behind Options.
• Client reference updated to 1.60.1 (70425), Release x64, built 14 October 2026; preceding gameplay checks used 70374.

|cffdfbd621.6.2-beta5 – Aligned extra effects (BETA)|r  |cffaaaaaa16.10.2026|r
• Align eight additional effects in two rows of four with the main DoTs; use one curse beside the portrait.
• Reduce row height with suggestions hidden while keeping the window width.

|cffdfbd621.6.2-beta4 – New Standard view (BETA)|r  |cffaaaaaa16.10.2026|r
• Make the portrait view Standard and migrate previous choices to it; remove Compact and the old Minimal tracker layout.
• Remove the redundant side stripe; keep target highlighting and raid markers.

|cffdfbd621.6.2-beta3 – Feedback dialog in front (BETA)|r  |cffaaaaaa16.10.2026|r
• Keep Contact & feedback above the options book. Its background blocks clicks to controls underneath; copying and closing still work.

|cffdfbd621.6.2-beta2 – Curses beside the portrait (BETA)|r  |cffaaaaaa16.10.2026|r
• Move utility curses beside the portrait, with separate countdowns.
• Reduce space below enemy rows and raise Execute! toward the countdown baseline.

|cffdfbd621.6.2-beta1 – Less vertical space (BETA)|r  |cffaaaaaa16.10.2026|r
• Reduce upper/lower row margins while keeping icons, fonts and width unchanged.
• Align suggestions and Execute; shrink portraits only where needed to keep curse timers inside the row.

|cffdfbd621.6.1 – Execute hint and optional window header|r  |cffaaaaaa15.10.2026|r
• Release Execute modes: Automatic, Below 35%, Below 20%, Off, with swords and Execute! beneath health.
• Hide the window header to save height, following AbelBeja's suggestion; keep the author credit when shown.
• Include shared DoT priority, compact rows and death notifications. Suggestions remain experimental and off by default. Manual Execute thresholds checked on 70374.

|cffdfbd621.6.1-beta5 – Execute hint and window header (BETA)|r  |cffaaaaaa15.10.2026|r
• Add automatic or manual Execute hints beneath health. Automatic checks relevant learned abilities/talents; manual thresholds work on any class.
• Add an optional header and background dragging. Put author details and CurseForge feedback under Help & info.
• Execute marks a health range, not a ready proc or cast.

|cffdfbd621.6.1-beta4 – Death events for remembered enemies (BETA)|r  |cffaaaaaa15.10.2026|r
• Matching death notifications remove remembered enemies and suggestions, including without a visible nameplate.
• Keep living enemies when turning away; missing death notifications cannot guarantee immediate offscreen removal.

|cffdfbd621.6.1-beta3 – Compact, evenly spaced rows (BETA)|r  |cffaaaaaa15.10.2026|r
• Reduce row height using equal upper/lower margins. Move additional effects into two small rows on the right, reusing spare width.

|cffdfbd621.6.1-beta2 – Shared order and aligned rows (BETA)|r  |cffaaaaaa15.10.2026|r
• Use the saved DoT order as the shared suggestion priority.
• Align portraits and icons with times below; show Apply for first applications and Casting during an attempt.

|cffdfbd621.6.1-beta1 – Initial applications (BETA)|r  |cffaaaaaa15.10.2026|r
• Suggest estimated first applications when combat is tracked from its start; Immolate can fit before later renewals.
• ~ marks assumptions. Incomplete histories stay unknown and cast completion does not prove a hit.

|cffdfbd621.6.0 – Display release|r  |cffaaaaaa15.10.2026|r
• Release health bars/percentages, fixed DoT positions, portrait curses and the grimoire. Health bars default follows thermanshs's suggestion.
• Suggestions remain experimental, off by default, with unlimited enemy life and no automatic hit detection.
• Without a reachable matching enemy, aura icons may temporarily disappear and unseen deaths require confirmation. Client reference: 1.60.1 (70374).

|cffdfbd621.6.0-experimental9 – Preserve recording history (EXPERIMENTAL)|r  |cffaaaaaa15.10.2026|r
• Keep five tracker reports with session number, start time and duration: /cftrace 1 through 5.
• /cftrace on preserves an active recording; reports started mid-fight are marked incomplete.

|cffdfbd621.6.0-experimental8 – Death check and fallback binding (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Improve matching death checks after nameplate loss; use matching alternatives such as pet target for aura updates.
• Aura icons may still disappear without a reachable matching enemy, while the row and last health remain.

|cffdfbd621.6.0-experimental7 – Restore established display (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Restore retained health without an Out of view overlay when turning away.
• Restore aura updates through the selected matching enemy. Retained HP is the last seen value.

|cffdfbd621.6.0-experimental6 – Cast diagnosis (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Add anonymized cast-association decisions to /cftrace for investigating incorrect suggestions.
• The fresh-Corruption/due-now discrepancy remains unresolved; this adds diagnosis, not hit detection.

|cffdfbd621.6.0-experimental5 – Early aura refresh (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Preserve countdowns when an aura refresh precedes nameplate removal.
• Add automatic tracker reports via /cftrace, with on/off/clear controls and no names, health or aura contents.

|cffdfbd621.6.0-experimental4 – Camera-loss regression (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Restore retained DoT displays when turning away; estimated suggestions stay in global priority order with ~.
• Improve return/death handling without confusing reused nameplates. Unseen deaths still require confirmation.

|cffdfbd621.6.0-experimental3 – Unknown-state label Lua error (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Fix the Lua error when displaying the unknown-state label in the tracker layouts.

|cffdfbd621.6.0-experimental2 – Target states and preview (EXPERIMENTAL)|r  |cffaaaaaa14.10.2026|r
• Remove confirmed dead enemies and their suggestions; show an unknown state for unavailable enemies.
• Keep cast history when toggling suggestions. Green 1 means now, gold 1 later, blue 2 the following action.
• Right-click Spell ? to correct an observed miss. No automatic hit recognition; client reference 70374.

|cffdfbd621.6.0-experimental1 – Estimated suggestions (EXPERIMENTAL)|r  |cffaaaaaa13.10.2026|r
• Add optional Agony/Corruption/Immolate suggestions per enemy and globally, with configurable priority and cast/GCD timing.
• Use /cfexp for settings and miss corrections. ~ marks estimates, ? unknown applications; normal selected-target casts are required.

|cffdfbd621.6.0-beta2 – Grimoire spacing|r  |cffaaaaaa13.10.2026|r
• Rearrange the grimoire Combat display page so DoT layout controls leave the signature clear.

|cffdfbd621.6.0-beta1 – Flexible DoT layout|r  |cffaaaaaa13.10.2026|r
• Choose expiration order or up to eight fixed slots via /cf dots; save selection and order per character.
• Keep other enabled effects in a smaller strip. Optional utility curses appear by Compact/Minimal portraits.
• Empty slots are reserved positions, not refresh instructions; the Curse Watcher stays independent.

|cffdfbd621.5.0-beta3 – Health bars by default|r  |cffaaaaaa13.10.2026|r
• Make health bars the default for new or unset displays, following thermanshs's suggestion. Preserve saved percentage preferences.

|cffdfbd621.5.0-beta2 – In-game test fixes|r  |cffaaaaaa13.10.2026|r
• Fix the Lua error when switching health bars/percentages in combat on client 70338.
• Restore button colors immediately after switching FULL to minimal.

|cffdfbd621.5.0-beta1 – Community request|r  |cffaaaaaa13.10.2026|r
• Add thermanshs's requested health-bar alternative, selectable under Combat display in all tracker layouts.
• Save the choice and apply it immediately. Percent remains the initial default in this beta.

|cffdfbd621.4.7-beta1 – Test version|r  |cffaaaaaa12.10.2026|r
• Handle unreadable client values safely and keep unknown alive-time unknown.
• Clean stale marker and curse reminders during extended play, preserving active targets and saved fights.

|cffdfbd621.4.6 – Maintenance release|r  |cffaaaaaa12.10.2026|r
• Fix false zero coverage beside unassigned casts and improve early damage-session matching.
• Include separate fight damage, encounter separation and clearer curse reminders. Blocked aura timing remains unavailable.

|cffdfbd621.4.5 – Maintenance release|r  |cffaaaaaa12.10.2026|r
• Keep damage with its own fight and distinguish unknown, partial and zero values.
• Pause coverage for unobserved enemies; separate consecutive bosses and count frame pauses in fight duration.
• Curse reminders distinguish unconfirmed applications from expired reminders.

|cffdfbd621.4.4 – Release|r  |cffaaaaaa11.10.2026|r
• Release four Options pages and FULL's animated grimoire, with minimal as a saved alternative.
• Include all-class filters, up to five selectable Raven cards and per-character archives. Client reference: 1.60.1 (70338).

|cffdfbd621.4.4-beta|r  |cffaaaaaa11.10.2026|r
• Fix mirrored titles and inscriptions during page turns; keep pages opaque.
• Darken Gul’dan while retaining the fel glow.

|cffdfbd621.4.3-beta|r  |cffaaaaaa11.10.2026|r
• Make the creator inscription turn with the right page and disappear beneath the returning left page.

|cffdfbd621.4.2-beta|r  |cffaaaaaa11.10.2026|r
• Restore the full grimoire silhouette and darken the parchment; integrate Cursive / Forever into the headings.
• Add an illuminated FULL/minimal clasp and reposition the creator inscription clear of controls.

|cffdfbd621.4.1-beta|r  |cffaaaaaa11.10.2026|r
• Fix Lua errors when creating the book signature and reopening Options afterwards.

|cffdfbd621.4.0-beta|r  |cffaaaaaa11.10.2026|r
• Add FULL as the default: Gul’dan's grimoire, four chapters, sliders and forward/backward page turns.
• Keep minimal, save the design choice and add /cf grimoire, /cf full and /cf minimal.

|cffdfbd621.3.3-beta|r  |cffaaaaaa11.10.2026|r
• Align checkbox captions, move the settings note clear of ornaments and correct lingering tab hover highlights.

|cffdfbd621.3.2-beta|r  |cffaaaaaa11.10.2026|r
• Organize Options into four aligned tabs with consistent controls; shorten the window and fit it to the screen.

|cffdfbd621.3.1-beta|r  |cffaaaaaa11.10.2026|r
• Replace missing card-order arrows with readable Up / Down labels, without overlapping decoration.

|cffdfbd621.3.0-beta|r  |cffaaaaaa11.10.2026|r
• Add Solo/Group/Raid filters for all nine classes and /cf cards for selecting/reordering five Raven cards.
• Hidden effects remain recorded. Add Consecration, trap and Deep Wounds damage support; area effects show damage totals only.

|cffdfbd621.2.12-beta|r
• Pause blocked aura-list checks per enemy until combat ends. Show Client restriction on affected cards and details; unavailable timing stays unknown.

|cffdfbd621.2.11-beta / 1.2.10-beta|r
• Show unconfirmed metrics as — instead of false zeroes; add clearer aura reports.
• Make the detail background opaque and improve the raven information plaque.

|cffdfbd621.2.8 / 1.2.9-beta|r
• Add enemy-filtered DoT details and calculated tick estimates to Performance.
• Improve opening-cast recording and handling of uncertain applications.

Complete release history: CHANGELOG.txt.
Deutsche Versionsgeschichte: VERSIONSHISTORIE.txt.
]]

function CF.GetChangelog()
    return CF.GetEffectiveLanguage() == "de" and CF.CHANGELOG_DE or CF.CHANGELOG_EN
end

local function ApplyDefaults()
    CursiveForeverDB = CursiveForeverDB or {}
    if CF.Client then CF.Client.BindSavedVariables() end
    db = CursiveForeverDB
    db.debug = nil -- retired development setting
    if CF.Client and not CF.Client.isForever then
        db.performanceEnabled = false
        db.raidCurseWatcherEnabled = false
        db.raidCurseKey = "none"
    end

    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end

    if CF.Client and (CF.Client.edition == "Era" or CF.Client.edition == "MoP") then
        -- Preserve the chosen distance where it fits the Classic range, including
        -- the new inner positions. Migrate only values outside that range.
        db.minimapRadius = math.min(CF.Client.minimapRadiusMax,
            math.max(CF.Client.minimapRadiusMin, tonumber(db.minimapRadius) or 105))
    end
    -- Retire the old three-way selector on load, including existing installs.
    -- Only the target layout changes; other preferences and archives stay put.
    db.targetDisplayMode = DEFAULTS.targetDisplayMode
    db.trackerView = (db.trackerView == "matrix" or db.trackerView == "bars" or db.trackerView == "healthbar") and db.trackerView or "standard"
    if type(db.barsShowSpellNames) ~= "boolean" then db.barsShowSpellNames = true end
    if CF.GetWindowTransparency then db.windowTransparency = CF.GetWindowTransparency() end
    if CF.ApplyWindowTransparency then CF.ApplyWindowTransparency() end
    db.healthDisplayMode = CF.GetHealthDisplayMode()
    db.executeMode = CF.GetExecuteMode and CF.GetExecuteMode() or "auto"
    if type(db.showHeader) ~= "boolean" then db.showHeader = true end

    db.spellFilters = db.spellFilters or {}
    db.owlFilters = db.owlFilters or {}
    db.raidCurseLearnedIDs = db.raidCurseLearnedIDs or {}
    db.performanceHistoryByCharacter = db.performanceHistoryByCharacter or {}
    db.performanceSlotMemoryByCharacter = db.performanceSlotMemoryByCharacter or {}

    local function InitFilterTable(catalog, storage)
        for _, spell in ipairs(catalog) do
            local settings = storage[spell.key]
            if type(settings) ~= "table" then
                settings = {}
                storage[spell.key] = settings
            end

            for _, context in ipairs(FILTER_CONTEXTS) do
                if settings[context] == nil then
                    settings[context] = true
                end
            end
        end
    end

    for classFile, catalog in pairs(CF.CLASS_FILTERS) do
        InitFilterTable(catalog, CF.GetClassFilterStorage(classFile))
    end
    if CF.InitializeAuraLayout then CF.InitializeAuraLayout() end
end

local function ApplyDarkBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(THEME_BG_R, THEME_BG_G, THEME_BG_B, alpha or 0.96)
    frame:SetBackdropBorderColor(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 1)
end

local function AddWitchCorners(frame)
    local corners = {
        {"TOPLEFT", 5, -5}, {"TOPRIGHT", -5, -5},
        {"BOTTOMLEFT", 5, 5}, {"BOTTOMRIGHT", -5, 5},
    }
    local textures={}
    for _, info in ipairs(corners) do
        local t = frame:CreateTexture(nil, "OVERLAY")
        t:SetSize(6, 6)
        t:SetPoint(info[1], frame, info[1], info[2], info[3])
        t:SetColorTexture(THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 0.72)
        textures[#textures+1]=t
    end
    return textures
end

local function AddInnerGlow(frame)
    local a = frame:CreateTexture(nil, "BORDER")
    a:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    a:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    a:SetHeight(2)
    a:SetColorTexture(THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 0.72)
    local b = frame:CreateTexture(nil, "BORDER")
    b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 3)
    b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    b:SetHeight(1)
    b:SetColorTexture(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 0.55)
    return a,b
end

local function IsHostile(unit)
    if not unit or not UnitExistsReadable(unit) then
        return false
    end

    return ReadClientBoolean(UnitCanAttack, "player", unit) == true
end

local function ThreatValue(sourceUnit, enemyUnit)
    local ok, value = pcall(UnitThreatSituation, sourceUnit, enemyUnit)
    if ok and not IsSecretValue(value) and type(value) == "number" then
        return value
    end
    return nil
end

local function UnitIsActuallyInCombat(unit)
    if not unit or not UnitExistsReadable(unit) then
        return false
    end

    return ReadClientBoolean(UnitAffectingCombat, unit) == true
end

local function UnitIsActuallyDead(unit)
    if not unit then return nil end
    if CF.DeathEvents and CF.DeathEvents.IsUnitDead(unit) then return true end
    -- On nameplate removal the token may cease to exist before its readable
    -- death flags and GUID disappear. Do not suppress that last death check.
    -- RemoveDeadTrackedUnit still requires the row's matching public identity.
    local exists = UnitExistsReadable(unit)
    local knownAlive = false
    if UnitIsDeadOrGhost then
        local dead = ReadClientBoolean(UnitIsDeadOrGhost, unit)
        if dead == true then return true end
        if dead == false then knownAlive = true end
    end
    if UnitIsDead then
        local dead = ReadClientBoolean(UnitIsDead, unit)
        if dead == true then return true end
        if dead == false then knownAlive = true end
    end
    -- Default false flags for an unavailable token are not evidence of life.
    if exists and knownAlive then return false end
    return nil
end

local function IsOurCombat(unit)
    if not IsHostile(unit) then
        return false
    end

    -- A successful tracked debuff cast by us is explicit proof that we
    -- intentionally engaged this unit, even if the threat API lags behind.
    if CF.IsUnitRememberedAsEngaged(unit) then
        return true
    end

    -- Forever can report threat status 0 for a merely attackable neutral mob.
    -- That must not be enough to put a yellow, unpulled unit into Cursive.
    if not UnitIsActuallyInCombat(unit) then
        return false
    end

    if ThreatValue("player", unit) ~= nil then
        return true
    end

    if UnitExistsReadable("pet") and ThreatValue("pet", unit) ~= nil then
        return true
    end

    return false
end

local function PlayerInCombat()
    return ReadClientBoolean(UnitAffectingCombat, "player") ~= false
end

function CF.RefreshMainWindowVisibility(inCombat)
    if not main or not db then return end
    if inCombat == nil then inCombat=PlayerInCombat() end
    main:SetShown(not db.hidden and (db.hideWindowOutOfCombat ~= true or inCombat))
end

function CF.SetHideWindowOutOfCombat(enabled)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not db then return end
    db.hideWindowOutOfCombat=enabled == true
    CF.RefreshMainWindowVisibility()
    if CF.ClickCasting then CF.ClickCasting.Refresh() end
end

function CF.SetMainWindowManuallyHidden(hidden)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not db then return end
    db.hidden=hidden == true
    CF.RefreshMainWindowVisibility()
    if CF.ClickCasting then CF.ClickCasting.Refresh() end
end

function CF.CanReloadAuraAppearance()
    return CF.HasPendingAuraAppearance and CF.HasPendingAuraAppearance() and not PlayerInCombat() or false
end

function CF.ReloadForAuraAppearance()
    if not CF.CanReloadAuraAppearance() then return false end
    ReloadUI()
    return true
end

local function InRaid()
    return ReadClientBoolean(IsInRaid) == true
end

local function IsCurrentTarget(unit)
    if not unit or not UnitExistsReadable("target") then
        return false
    end

    return ReadClientBoolean(UnitIsUnit, "target", unit) == true
end

local function SafeUnitGUID(unit)
    if not unit or not UnitExistsReadable(unit) then
        return nil
    end

    local ok, guid = pcall(UnitGUID, unit)
    if not ok or IsSecretValue(guid) or type(guid) ~= "string" or guid == "" then
        return nil
    end

    -- WoW 12.x may return secret GUID strings for protected/PvP-related units.
    -- Secret values must never be used as Lua table keys (guidToRow[guid]).
    if IsSecretValue(guid) then
        return nil
    end

    return guid
end

local function IsSafeGUIDKey(guid)
    return not IsSecretValue(guid) and type(guid) == "string" and guid ~= ""
end

local function StickyKeyForGUID(guid)
    if not IsSafeGUIDKey(guid) then
        return nil
    end

    return "sticky:" .. guid
end

function CF.MarkUnitEngaged(unit)
    if not unit or not UnitExistsReadable(unit) then
        return
    end

    local guid = SafeUnitGUID(unit)

    if IsSafeGUIDKey(guid) then
        CF.playerEngagedGUIDs[guid] = true
        -- Never retain a token flag when a stable GUID is available.
        playerEngagedUnits[unit] = nil
    else
        -- Protected/secret GUID fallback. This is deliberately ephemeral.
        playerEngagedUnits[unit] = true
    end
end

function CF.IsUnitRememberedAsEngaged(unit)
    if not unit or not UnitExistsReadable(unit) then
        return false
    end

    local guid = SafeUnitGUID(unit)

    if IsSafeGUIDKey(guid) then
        return CF.playerEngagedGUIDs[guid] == true
    end

    return playerEngagedUnits[unit] == true
end

function CF.ForgetUnitEngagement(unit)
    if not unit then
        return
    end

    local guid = SafeUnitGUID(unit)

    if IsSafeGUIDKey(guid) then
        CF.playerEngagedGUIDs[guid] = nil
    end

    -- Always clear the ephemeral token fallback.
    playerEngagedUnits[unit] = nil
end

local function FindRowByUnitOrGUID(unit)
    if unitToRow[unit] then
        return unitToRow[unit]
    end

    local guid = SafeUnitGUID(unit)
    if IsSafeGUIDKey(guid) then
        return guidToRow[guid]
    end

    return nil
end

local function GetAuraContext()
    if ReadClientBoolean(IsInRaid) == true then
        return "raid"
    end

    if ReadClientBoolean(IsInGroup) == true then
        return "dungeon"
    end

    return "solo"
end

local function BuildSpellCandidateFilters(context)
    context = context or GetAuraContext()
    local _, classFile = UnitClass("player")
    local excluded = {}
    local storage = CF.GetClassFilterStorage(classFile or "UNKNOWN")
    local learned = CF.filterSpellRanks and CF.filterSpellRanks[classFile] or {}
    for _, spell in ipairs(CF.GetClassFilterCatalog(classFile)) do
        local settings = storage[spell.key]
        if settings and settings[context] == false then
            for _, id in ipairs(spell.ids) do excluded[id] = true end
            for id in pairs(learned[spell.key] or {}) do excluded[id] = true end
        end
    end
    -- Unknown/new effects stay visible; filtering is performed by the client.
    return {excludeSpellIDs=excluded}
end
CF.BuildSpellCandidateFilters = BuildSpellCandidateFilters
CF.GetAuraContext = GetAuraContext

local function GetSpellDisplayInfo(spell)
    for _, spellID in ipairs(spell.ids) do
        local name = CF.SafeSpellName(spellID)
        if name then
            local description
            if C_Spell and C_Spell.GetSpellDescription then
                local ok, value = pcall(C_Spell.GetSpellDescription, spellID)
                if ok and not IsSecretValue(value) and type(value)=="string" then description=value end
            end
            if CF.Client and CF.Client.SpellReplacementNote then
                local note=CF.Client.SpellReplacementNote(spell)
                if note then description=(description and description.."\n\n" or "")..note end
            end
            return name, CF.SafeSpellTexture(spellID), description, spellID
        end
    end
    return spell.fallback, nil, nil, spell.ids[1]
end

function CF.LearnRaidCurseSpellIDFromCast(spellID)
    if not db or IsSecretValue(spellID) or type(spellID) ~= "number" then
        return nil
    end

    local castName = nil
    if C_Spell and C_Spell.GetSpellName then
        local ok, value = pcall(C_Spell.GetSpellName, spellID)
        if ok and not IsSecretValue(value) and type(value) == "string" then
            castName = value
        end
    end

    if not castName then
        return nil
    end

    for _, curse in ipairs(RAID_CURSES) do
        local matched = (castName == curse.fallback)
            or (curse.english and castName == curse.english)

        if not matched and C_Spell and C_Spell.GetSpellName then
            for _, knownID in ipairs(curse.ids) do
                local ok, knownName = pcall(C_Spell.GetSpellName, knownID)
                if ok
                    and not IsSecretValue(knownName)
                    and type(knownName) == "string"
                    and castName == knownName
                then
                    matched = true
                    break
                end
            end
        end

        if matched then
            db.raidCurseLearnedIDs[curse.key] = spellID

            return curse.key
        end
    end

    return nil
end

local function RaidCurseReadable(value)
    if IsSecretValue(value) then return false end
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue,value)
        if not ok or accessible ~= true then return false end
    end
    return true
end

function CF.GetRaidCurseCastFamily(spellID)
    if not RaidCurseReadable(spellID) or type(spellID) ~= "number" then return nil end
    local castName = CF.SafeSpellName(spellID)
    if not RaidCurseReadable(castName) then castName = nil end
    local learned = CF.filterSpellRanks and CF.filterSpellRanks.WARLOCK or {}
    for _, family in ipairs(WARLOCK_DEBUFFS) do
        -- Banes such as Agony and Doom do not replace utility curses.
        if string.sub(family.key,1,6) == "curse_" then
            if learned[family.key] and learned[family.key][spellID] then return family.key end
            for _, knownID in ipairs(family.ids) do
                if spellID == knownID then return family.key end
                local knownName = castName and CF.SafeSpellName(knownID)
                if RaidCurseReadable(knownName) and knownName and castName == knownName then return family.key end
            end
            local assignable = GetRaidCurseDef(family.key)
            if castName and assignable and (castName == assignable.fallback or castName == assignable.english) then
                return family.key
            end
        end
    end
    return nil
end

CF.raidCursePendingCasts = {}

function CF.RaidCurseCastSent(targetName, castGUID, spellID)
    if not RaidCurseReadable(castGUID) or type(castGUID) ~= "string" or castGUID == "" then return false end
    local pending, now = CF.raidCursePendingCasts, GetTime()
    pending[castGUID] = nil
    local count, oldestKey, oldestAt = 0,nil,nil
    for key, record in pairs(pending) do
        if now-record.sentAt > 15 then pending[key] = nil
        else
            count = count+1
            if not oldestAt or record.sentAt < oldestAt then oldestKey,oldestAt = key,record.sentAt end
        end
    end
    local family = CF.GetRaidCurseCastFamily(spellID)
    if not family or not RaidCurseReadable(targetName) or type(targetName) ~= "string" or targetName == "" then return false end
    local seen, selectedKey, ambiguous = {},nil,false
    local function Consider(unit)
        if not UnitExistsReadable(unit) or not IsHostile(unit) or UnitIsActuallyDead(unit) then return end
        local guid = SafeUnitGUID(unit)
        if RaidCurseReadable(guid) and IsSafeGUIDKey(guid) and seen[guid] then return end
        local ok, name = pcall(UnitName,unit)
        if not ok or not RaidCurseReadable(name) or type(name) ~= "string" then ambiguous = true; return end
        if name ~= targetName then return end
        if not RaidCurseReadable(guid) or not IsSafeGUIDKey(guid) then ambiguous = true; return end
        if not seen[guid] then
            seen[guid] = true
            if selectedKey then ambiguous = true end
            selectedKey = "guid:"..guid
        end
    end
    Consider("target"); Consider("focus"); Consider("mouseover"); Consider("pettarget")
    for index=1,8 do Consider("boss"..index) end
    local plates = 0
    for unit in pairs(visibleUnits) do
        plates = plates+1
        if plates > 40 then ambiguous = true; break end
        Consider(unit)
    end
    if ambiguous or not selectedKey then return false end
    if count >= 32 and oldestKey then pending[oldestKey] = nil end
    pending[castGUID] = {unitKey=selectedKey,curseKey=family,spellID=spellID,sentAt=now}
    return true
end

function CF.RaidCurseCastFailed(castGUID)
    if RaidCurseReadable(castGUID) and type(castGUID) == "string" then CF.raidCursePendingCasts[castGUID] = nil end
end

function CF.GetRaidCurseUnitKey(unit)
    if not unit or not UnitExistsReadable(unit) then
        return nil
    end

    local guid = SafeUnitGUID(unit)
    if IsSafeGUIDKey(guid) then
        return "guid:" .. guid
    end

    -- Test mode and restricted encounter units can still use their stable
    -- boss/target token for the current session.
    return "unit:" .. tostring(unit)
end

function CF.RecordRaidCurseCast(curseKey, spellID, unitKey)
    if not curseKey or not RaidCurseReadable(spellID) or type(spellID) ~= "number" then
        return false
    end
    if unitKey == nil then
        -- Preserve the standalone helper; event callers supply their SENT
        -- association rather than using whichever target is selected later.
        if not UnitExistsReadable("target") or not IsHostile("target") or UnitIsActuallyDead("target") then return false end
        unitKey = CF.GetRaidCurseUnitKey("target")
    elseif not RaidCurseReadable(unitKey) or type(unitKey) ~= "string"
        or string.sub(unitKey,1,5) ~= "guid:" or #unitKey <= 5 then
        return false
    end

    local curse = GetRaidCurseDef(curseKey)
    if not curse then
        return false
    end

    if not unitKey then
        return false
    end

    local duration = tonumber(curse.durationSeconds) or 0
    if duration <= 0 then
        return false
    end

    local now = GetTime()

    -- A completed cast starts an estimate, not a hit confirmation.
    CF.raidCurseCastState[unitKey] = {
        curseKey = curseKey,
        spellID = spellID,
        castAt = now,
        expiresAt = now + duration,
        duration = duration,
    }

    return true
end

function CF.RaidCurseCastFinished(castGUID, spellID)
    if not RaidCurseReadable(castGUID) or type(castGUID) ~= "string" then return false end
    local record = CF.raidCursePendingCasts[castGUID]
    CF.raidCursePendingCasts[castGUID] = nil
    if not record or not RaidCurseReadable(spellID) or type(spellID) ~= "number"
        or record.spellID ~= spellID or GetTime()-record.sentAt > 15 then return false end
    -- A competing completed curse invalidates the previous assumption only
    -- for this SENT identity. A miss is still possible; readable aura evidence
    -- remains free to confirm that the assigned curse is actually present.
    CF.raidCurseCastState[record.unitKey] = nil
    if GetRaidCurseDef(record.curseKey) then
        CF.RecordRaidCurseCast(record.curseKey,spellID,record.unitKey)
    end
    return true
end

function CF.GetRaidCurseCastRemaining(unit, curseKey)
    local unitKey = CF.GetRaidCurseUnitKey(unit)
    if not unitKey then
        return nil, "no-unit"
    end

    local state = CF.raidCurseCastState[unitKey]
    if not state then
        return nil, "not-cast"
    end

    if state.curseKey ~= curseKey then
        return nil, "other-curse"
    end

    local remaining = (tonumber(state.expiresAt) or 0) - GetTime()

    if remaining <= 0 then
        return nil, "expired"
    end

    return remaining, "present-cast"
end

-- These caches support live display only. They do not own recordings or archives.
CF.TRANSIENT_CACHE_INTERVAL = 15
CF.TRANSIENT_MARKER_MAX_AGE = 300
CF.TRANSIENT_CACHE_MAX = 256

function CF.ClearTransientTargetCaches()
    wipe(CF.raidMarkerGUIDCache)
    wipe(CF.raidMarkerCacheSeen)
    wipe(CF.raidCurseCastState)
    wipe(CF.raidCursePendingCasts)
    CF.transientCacheNextAt = nil
end

function CF.PruneTransientTargetCaches(force)
    local now = GetTime()
    if not force and CF.transientCacheNextAt and now < CF.transientCacheNextAt then return end
    CF.transientCacheNextAt = now + CF.TRANSIENT_CACHE_INTERVAL
    local neededMarkers, neededCurses = {}, {}
    local function KeepGUID(guid)
        if IsSafeGUIDKey(guid) then
            neededMarkers[guid] = true
            neededCurses["guid:" .. guid] = true
        end
    end
    local function KeepUnit(unit)
        if UnitExistsReadable(unit) and not UnitIsActuallyDead(unit) then
            KeepGUID(SafeUnitGUID(unit))
            neededCurses["unit:" .. unit] = true
        end
    end
    for _, row in ipairs(rows) do
        if row.unit then
            KeepGUID(row.guid) -- includes offscreen rows retained for this fight
            KeepUnit(row.unit)
        end
    end
    KeepUnit("target"); KeepUnit("focus"); KeepUnit("mouseover")
    for i = 1, 8 do KeepUnit("boss" .. i) end

    local function Prune(cache, needed, stamp, expired, remove)
        local count, candidates = 0, {}
        for key, value in pairs(cache) do
            local at = stamp(key, value)
            if not needed[key] and expired(at) then
                remove(key)
            else
                count = count + 1
                if not needed[key] then candidates[#candidates + 1] = {key=key, at=at} end
            end
        end
        if count > CF.TRANSIENT_CACHE_MAX then
            table.sort(candidates, function(a,b)
                if a.at == b.at then return a.key < b.key end
                return a.at < b.at
            end)
            for _, item in ipairs(candidates) do
                if count <= CF.TRANSIENT_CACHE_MAX then break end
                remove(item.key); count = count - 1
            end
        end
    end
    Prune(CF.raidMarkerGUIDCache, neededMarkers,
        function(key) return CF.raidMarkerCacheSeen[key] or 0 end,
        function(at) return now-at >= CF.TRANSIENT_MARKER_MAX_AGE end,
        function(key) CF.raidMarkerGUIDCache[key]=nil; CF.raidMarkerCacheSeen[key]=nil end)
    Prune(CF.raidCurseCastState, neededCurses,
        function(_,value) return value.expiresAt or 0 end,
        function(at) return at <= now end,
        function(key) CF.raidCurseCastState[key]=nil end)
end

local function SafeUnitName(unit, fallback)
    if unit and UnitExistsReadable(unit) then
        local ok, name = pcall(UnitName, unit)

        if ok then
            if IsSecretValue(name) then
                return fallback or CF.T("PROTECTED_TARGET")
            end

            if type(name) == "string" and name ~= "" then
                return name
            end
        end
    end

    return fallback or CF.T("BOSS")
end

-- ------------------------------------------------------------
-- PERFORMANCE HISTORY / DoT COVERAGE
-- ------------------------------------------------------------
-- Player-owned cast events preserve attempts; readable own aura data confirms
-- applications. Protected aura data stays unknown. The native DamageMeter
-- remains the only source of measured damage. Confirmed application timings
-- and durations drive the model. For multi-boss encounters, seconds are summed
-- across relevant boss target-seconds rather than using "active somewhere".
--
-- The large headline Uptime therefore means:
--   active target-seconds / relevant target-seconds
-- and player death time remains part of the fight, by design.

CF.PERFORMANCE_HISTORY_MAX = 30
CF.PERFORMANCE_MIN_MIN = 15
CF.PERFORMANCE_MIN_MAX = 60
CF.performanceActive = nil
CF.performanceFrame = nil
CF.performanceSelectedIndex = 1
CF.performanceMarkerWasSecret = false

CF.PERFORMANCE_PROFILES = {
    WARLOCK = {
        {
            key = "bane",
            fallback = "Bane of Agony / Doom",
            variants = {
                { seedIDs = {980}, duration = 24, fallbackNames = {"Bane of Agony", "Agony"} },
                { seedIDs = {603}, duration = 60, fallbackNames = {"Bane of Doom", "Doom"} },
            },
        },
        {
            key = "immolate",
            fallback = "Immolate",
            variants = {
                { seedIDs = {348}, duration = 15, fallbackNames = {"Immolate", "Feuerbrand"} },
            },
        },
        {
            key = "corruption",
            fallback = "Corruption",
            variants = {
                { seedIDs = {172}, duration = 18, fallbackNames = {"Corruption", "Verderbnis"} },
            },
        },
        {
            key = "siphon_life",
            fallback = "Siphon Life",
            variants = {
                { seedIDs = {18265}, duration = 30, fallbackNames = {"Siphon Life", "Lebensentzug"} },
            },
        },
        {
            key = "wrack",
            fallback = "Wrack",
            variants = {
                { seedIDs = {1316697}, duration = 6, fallbackNames = {"Wrack"} },
            },
        },
    },

    DRUID = {
        { key="moonfire", fallback="Moonfire", variants={{seedIDs={8921}, duration=12, fallbackNames={"Moonfire","Mondfeuer"}}} },
        { key="insect_swarm", fallback="Insect Swarm", variants={{seedIDs={5570}, duration=12, fallbackNames={"Insect Swarm","Insektenschwarm"}}} },
        { key="rake", fallback="Rake", variants={{seedIDs={1822}, duration=9, fallbackNames={"Rake","Krallenhieb"}}} },
        { key="rip", fallback="Rip", variants={{seedIDs={1079}, duration=12, fallbackNames={"Rip","Zerfetzen"}}} },
        { key="lacerate", fallback="Lacerate", variants={{seedIDs={414644,1235826,1235827}, duration=15, fallbackNames={"Lacerate"}}} },
    },

    PRIEST = {
        { key="shadow_word_pain", fallback="Shadow Word: Pain", variants={{seedIDs={589}, duration=18, fallbackNames={"Shadow Word: Pain"}}} },
        { key="devouring_plague", fallback="Devouring Plague", variants={{seedIDs={2944}, duration=24, fallbackNames={"Devouring Plague"}}} },
        { key="holy_fire", fallback="Holy Fire", variants={{seedIDs={14914}, duration=10, fallbackNames={"Holy Fire"}}} },
    },

    HUNTER = {
        { key="serpent_sting", fallback="Serpent Sting", variants={{seedIDs={1978}, duration=15, fallbackNames={"Serpent Sting"}}} },
        { key="black_arrow", fallback="Black Arrow", variants={{seedIDs={3674}, duration=15, fallbackNames={"Black Arrow"}}} },
        { key="lacerate_hunter", fallback="Lacerate", variants={{seedIDs={24118,24119,24120,1299332}, duration=21, fallbackNames={"Lacerate"}}} },
        { key="trap_periodic", fallback="Trap DoT", labelKey="TRAP_DAMAGE", passive=true, damageOnly=true, variants={{seedIDs={13797,13812,13795,13813}, duration=0, fallbackNames={"Immolation Trap","Explosive Trap","Feuerbrandfalle","Sprengfalle"}}} },
    },

    ROGUE = {
        { key="rupture", fallback="Rupture", variants={{seedIDs={1943}, duration=16, fallbackNames={"Rupture"}}} },
        { key="garrote", fallback="Garrote", variants={{seedIDs={703}, duration=18, fallbackNames={"Garrote"}}} },
        { key="deadly_poison", fallback="Deadly Poison", passive=true, variants={{seedIDs={2818}, duration=12, fallbackNames={"Deadly Poison"}}} },
    },

    MAGE = {
        { key="ignite", fallback="Ignite", passive=true, variants={{seedIDs={12654}, duration=4, fallbackNames={"Ignite"}}} },
        { key="fireball_burn", fallback="Fireball", variants={{seedIDs={133}, duration=8, fallbackNames={"Fireball"}}} },
        { key="pyroblast_burn", fallback="Pyroblast", variants={{seedIDs={11366}, duration=12, fallbackNames={"Pyroblast"}}} },
    },

    WARRIOR = {
        { key="rend", fallback="Rend", variants={{seedIDs={772}, duration=15, fallbackNames={"Rend"}}} },
        { key="deep_wounds", fallback="Deep Wounds", passive=true, variants={{seedIDs={12721,12834}, duration=12, fallbackNames={"Deep Wounds"}}} },
    },

    SHAMAN = {
        { key="flame_shock", fallback="Flame Shock", variants={{seedIDs={8050}, duration=12, fallbackNames={"Flame Shock"}}} },
    },

    PALADIN = {
        {key="consecration",fallback="Consecration",passive=true,damageOnly=true,
            variants={{seedIDs={26573},duration=0,fallbackNames={"Consecration","Weihe"}}}},
    },
}

function CF.GetPlayerCharacterKey()
    local name, realm = UnitFullName("player")
    name = name or UnitName("player") or "Player"
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "Realm"
    return tostring(name) .. "-" .. tostring(realm)
end

function CF.GetPerformanceHistory()
    if not db then
        return {}
    end

    db.performanceHistoryByCharacter = db.performanceHistoryByCharacter or {}
    local key = CF.GetPlayerCharacterKey()

    if type(db.performanceHistoryByCharacter[key]) ~= "table" then
        db.performanceHistoryByCharacter[key] = {}
    end

    return db.performanceHistoryByCharacter[key]
end

function CF.GetPerformanceCharacterSettings()
    if not db then
        return { archiveOpen = true, collapsed = false, scale = 1 }
    end

    db.performanceSettingsByCharacter = db.performanceSettingsByCharacter or {}
    local key = CF.GetPlayerCharacterKey()

    if type(db.performanceSettingsByCharacter[key]) ~= "table" then
        db.performanceSettingsByCharacter[key] = {
            archiveOpen = true,
            collapsed = false,
            scale = 1,
        }
    else
        if db.performanceSettingsByCharacter[key].archiveOpen == nil then
            db.performanceSettingsByCharacter[key].archiveOpen = true
        end
        if db.performanceSettingsByCharacter[key].collapsed == nil then
            db.performanceSettingsByCharacter[key].collapsed = false
        end
        if db.performanceSettingsByCharacter[key].scale == nil then
            db.performanceSettingsByCharacter[key].scale = 1
        end
    end

    return db.performanceSettingsByCharacter[key]
end

function CF.IsPerformanceArchiveOpen()
    return CF.GetPerformanceCharacterSettings().archiveOpen ~= false
end

function CF.SetPerformanceArchiveOpen(open)
    CF.GetPerformanceCharacterSettings().archiveOpen = open and true or false
    if CF.performanceFrame then
        CF.PerformanceApplyArchiveState()
    end
end

function CF.TogglePerformanceArchive()
    CF.SetPerformanceArchiveOpen(not CF.IsPerformanceArchiveOpen())
end

function CF.IsPerformanceCollapsed()
    return CF.GetPerformanceCharacterSettings().collapsed == true
end

function CF.SetPerformanceCollapsed(collapsed)
    CF.GetPerformanceCharacterSettings().collapsed = collapsed and true or false
    if CF.performanceFrame then
        CF.PerformanceApplyCollapsedState()
        CF.PerformanceApplyArchiveState()
        CF.PerformanceRefreshFrame()
    end
end

function CF.TogglePerformanceCollapsed()
    CF.SetPerformanceCollapsed(not CF.IsPerformanceCollapsed())
end

function CF.NormalizePerformanceScale(value)
    value = tonumber(value)
    if not value or value ~= value then value = 1 end
    value = math.max(0.50, math.min(1.20, value))
    return math.floor(value * 20 + 0.5) / 20
end

function CF.GetPerformanceScale()
    return CF.NormalizePerformanceScale(CF.GetPerformanceCharacterSettings().scale)
end

function CF.IsPerformanceAnchorPoint(point)
    return point == "CENTER" or point == "TOP" or point == "BOTTOM"
        or point == "LEFT" or point == "RIGHT" or point == "TOPLEFT"
        or point == "TOPRIGHT" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT"
end

function CF.SavePerformancePosition()
    local f = CF.performanceFrame
    if not db or not f then return end
    local point, _, relativePoint, x, y = f:GetPoint(1)
    if not CF.IsPerformanceAnchorPoint(point) then return end
    CF.GetPerformanceCharacterSettings().position = {
        point = point,
        relativePoint = CF.IsPerformanceAnchorPoint(relativePoint) and relativePoint or point,
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
    }
end

function CF.PerformanceApplyWindowPlacement()
    local f = CF.performanceFrame
    if not f then return end
    local settings = CF.GetPerformanceCharacterSettings()
    local position = settings.position
    f:SetScale(CF.GetPerformanceScale())
    f:ClearAllPoints()
    if type(position) == "table"
        and CF.IsPerformanceAnchorPoint(position.point)
        and CF.IsPerformanceAnchorPoint(position.relativePoint)
        and type(position.x) == "number" and math.abs(position.x) < 100000
        and type(position.y) == "number" and math.abs(position.y) < 100000
    then
        f:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function CF.SetPerformanceScale(value)
    CF.GetPerformanceCharacterSettings().scale = CF.NormalizePerformanceScale(value)
    CF.PerformanceApplyWindowPlacement()
end

function CF.ResetPerformancePosition()
    CF.GetPerformanceCharacterSettings().position = nil
    CF.PerformanceApplyWindowPlacement()
end

function CF.GetPerformanceProfile()
    local _, classFile = UnitClass("player")
    return (CF.PERFORMANCE_PROFILES and CF.PERFORMANCE_PROFILES[classFile]) or {}
end

function CF.GetPerformanceClassFile()
    local _, classFile = UnitClass("player")
    return classFile or "UNKNOWN"
end

-- Display choices never limit the underlying recording catalogue.
function CF.NormalizePerformanceCardKeys(keys, classFile)
    local valid, seen, result = {}, {}, {}
    for _, effect in ipairs(CF.PERFORMANCE_PROFILES[classFile] or {}) do valid[effect.key] = true end
    if type(keys) ~= "table" then return result end
    for _, key in ipairs(keys) do
        if type(key) == "string" and valid[key] and not seen[key] then
            result[#result+1] = key; seen[key] = true
            if #result == 5 then break end
        end
    end
    return result
end

function CF.GetPerformanceCardKeys()
    local settings = CF.GetPerformanceCharacterSettings()
    if settings.cardKeys ~= nil then
        return CF.NormalizePerformanceCardKeys(settings.cardKeys, CF.GetPerformanceClassFile())
    end
    local result = {}
    for i, effect in ipairs(CF.GetPerformanceProfile()) do
        if i > 5 then break end
        result[#result+1] = effect.key
    end
    return result
end

function CF.PerformanceCardSettingsChanged()
    if CF.performanceDetailsFrame then CF.performanceDetailsFrame:Hide() end
    if CF.performanceFrame and CF.performanceFrame:IsShown() then CF.PerformanceRefreshFrame() end
    if CF.cardSelectionFrame and CF.cardSelectionFrame:IsShown() then CF.RefreshCardSelection() end
end

function CF.SetPerformanceCardEnabled(key, enabled)
    local keys = CF.GetPerformanceCardKeys()
    local found
    for i, current in ipairs(keys) do if current == key then found = i; break end end
    if enabled and not found then
        if #keys >= 5 then return false end
        keys[#keys+1] = key
    elseif not enabled and found then table.remove(keys, found) end
    CF.GetPerformanceCharacterSettings().cardKeys = CF.NormalizePerformanceCardKeys(keys, CF.GetPerformanceClassFile())
    CF.PerformanceCardSettingsChanged()
    return true
end

function CF.MovePerformanceCard(key, direction)
    if direction ~= -1 and direction ~= 1 then return end
    local keys = CF.GetPerformanceCardKeys()
    for i, current in ipairs(keys) do
        local other = i + direction
        if current == key and other >= 1 and other <= #keys then
            keys[i], keys[other] = keys[other], keys[i]
            CF.GetPerformanceCharacterSettings().cardKeys = keys
            CF.PerformanceCardSettingsChanged()
            return
        end
    end
end

function CF.GetPerformanceDisplaySlots(snapshot)
    local settings = CF.GetPerformanceCharacterSettings()
    local result, byKey = {}, {}
    for _, slot in ipairs(snapshot.slots or {}) do
        if slot.key then byKey[slot.key] = slot end
    end
    if settings.cardKeys == nil then
        -- Legacy recordings retain their recorded order until the user chooses.
        for i = 1, math.min(5, #(snapshot.slots or {})) do result[i] = snapshot.slots[i] end
    else
        local definitions = {}
        for _, effect in ipairs(CF.PERFORMANCE_PROFILES[snapshot.classFile or CF.GetPerformanceClassFile()] or {}) do
            definitions[effect.key] = effect
        end
        for i, key in ipairs(CF.GetPerformanceCardKeys()) do
            result[i] = byKey[key]
            if not result[i] and definitions[key] then
                local name, spellID, icon = CF.GetPerformanceEffectDisplay(definitions[key])
                result[i] = { key=key, name=name, spellID=spellID, icon=icon, notRecorded=true }
            end
        end
    end
    if settings.hideUnusedCards and snapshot.damageMeterAvailable then
        for i = 1, 5 do
            local slot = result[i]
            if slot and not slot.notRecorded and slot.used == false then result[i] = nil end
        end
    end
    return result
end


function CF.SafeSpellName(spellID)
    if IsSecretValue(spellID) or type(spellID) ~= "number" then
        return nil
    end

    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and not IsSecretValue(name) and type(name) == "string" then
            return name
        end
    end

    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and not IsSecretValue(name) and type(name) == "string" then
            return name
        end
    end

    return nil
end

-- Only ordinary spellbook data is inspected, outside combat. Names come from
-- the client, independently of the addon's display language. No aura scan.
function CF.RefreshClassSpellRanks()
    if InCombatLockdown and InCombatLockdown() then CF.classRanksDirty=true; return false end
    if CF.Client and CF.Client.RefreshSpellCatalog then CF.Client.RefreshSpellCatalog() end
    local api = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if not api or not api.GetNumSpellBookSkillLines or not api.GetSpellBookSkillLineInfo
        or not api.GetSpellBookItemInfo or bank == nil then return false end
    local classFile = CF.GetPerformanceClassFile()
    local catalog = CF.GetClassFilterCatalog(classFile)
    local names, ids, learned = {}, {}, {}
    for _, spell in ipairs(catalog) do
        learned[spell.key] = {}
        for _, id in ipairs(spell.ids) do
            ids[id] = spell.key
            local name = CF.SafeSpellName(id)
            if type(name) == "string" then names[name] = spell.key end
        end
    end
    for key, candidates in pairs(CF.FILTER_RANK_CANDIDATES[classFile] or {}) do
        for _, id in ipairs(candidates) do
            local name = CF.SafeSpellName(id)
            if name and names[name] == key then learned[key][id] = true end
        end
    end
    local ok = pcall(function()
        local count = api.GetNumSpellBookSkillLines()
        if IsSecretValue(count) or type(count) ~= "number" or count <= 0 then error("unreadable spellbook") end
        for line = 1, math.min(100, count) do
            local info = api.GetSpellBookSkillLineInfo(line)
            if info and not IsSecretValue(info) then
                local offset, size = info.itemIndexOffset, info.numSpellBookItems
                if not IsSecretValue(offset) and not IsSecretValue(size)
                    and type(offset) == "number" and type(size) == "number" then
                    for index = offset+1, offset+math.min(500,size) do
                        local item = api.GetSpellBookItemInfo(index, bank)
                        if item and not IsSecretValue(item) then
                            local id, base, name = item.spellID, item.actionID, item.name
                            if not IsSecretValue(id) and type(id) == "number"
                                and not IsSecretValue(name) and type(name) == "string" then
                                local key = ids[id] or names[name]
                                if key then
                                    learned[key][id] = true
                                    if not IsSecretValue(base) and type(base) == "number" then learned[key][base] = true end
                                end
                            end
                        end
                    end
                else error("unreadable skill line") end
            else error("missing skill line") end
        end
    end)
    if not ok then return false end
    CF.filterSpellRanks = CF.filterSpellRanks or {}
    CF.filterSpellRanks[classFile] = learned
    for _, ranks in pairs(learned) do for id in pairs(ranks) do TRACKED_DEBUFF_SPELL_IDS[id] = true end end
    CF.classRanksDirty = nil
    return true
end

function CF.SafeSpellTexture(spellID)
    if spellID and C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon then
            return icon
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function CF.StringEqualsIgnoreCase(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then
        return false
    end

    return string.lower(a) == string.lower(b)
end

function CF.PerformanceVariantMatchesSpell(variant, spellID, spellName)
    if not variant then
        return false
    end

    for _, seedID in ipairs(variant.seedIDs or {}) do
        if spellID == seedID then
            return true
        end

        local seedName = CF.SafeSpellName(seedID)
        if seedName and spellName and CF.StringEqualsIgnoreCase(seedName, spellName) then
            return true
        end
    end

    if spellName then
        for _, fallbackName in ipairs(variant.fallbackNames or {}) do
            if CF.StringEqualsIgnoreCase(spellName, fallbackName) then
                return true
            end
        end
    end

    return false
end

function CF.ResolvePerformanceEffect(spellID)
    if IsSecretValue(spellID) or type(spellID) ~= "number" then
        return nil
    end

    local spellName = CF.SafeSpellName(spellID)
    local profile = CF.GetPerformanceProfile()

    for slotIndex, effect in ipairs(profile) do
        for variantIndex, variant in ipairs(effect.variants or {}) do
            if CF.PerformanceVariantMatchesSpell(variant, spellID, spellName) then
                return effect, variant, slotIndex, variantIndex, spellName
            end
        end
    end

    return nil
end

function CF.GetPerformanceEffectDisplay(effect, usedSpellID, usedName)
    local spellID = usedSpellID
    local name = usedName

    if not spellID and effect and effect.variants then
        for _, variant in ipairs(effect.variants) do
            if variant.seedIDs and variant.seedIDs[1] then
                spellID = variant.seedIDs[1]
                break
            end
        end
    end

    if not name and spellID then
        name = CF.SafeSpellName(spellID)
    end

    if not name and effect then
        name = effect.fallback
    end

    if effect and effect.labelKey then name = CF.T(effect.labelKey) end
    return name or "DoT", spellID, CF.SafeSpellTexture(spellID)
end

function CF.GetPerformanceTargetKey(unit)
    if not unit or not UnitExistsReadable(unit) then
        return nil
    end

    -- Prefer encounter boss tokens. They stay useful even when hostile GUIDs are
    -- protected by Forever's instance secrecy rules.
    for i = 1, 8 do
        local bossUnit = "boss" .. i

        if UnitExistsReadable(bossUnit) then
            if ReadClientBoolean(UnitIsUnit, unit, bossUnit) == true then
                return bossUnit
            end
        end
    end

    local guid = SafeUnitGUID(unit)
    if IsSafeGUIDKey(guid) then
        return "guid:" .. guid
    end

    local name = SafeUnitName(unit, nil)
    if name and name ~= CF.T("PROTECTED_TARGET") then
        return "name:" .. tostring(name)
    end

    return "unit:" .. tostring(unit)
end

function CF.PerformanceEnsureEffectData(effectKey)
    local active = CF.performanceActive
    if not active or not effectKey then
        return nil
    end

    active.effects = active.effects or {}
    local data = active.effects[effectKey]

    if not data then
        data = {
            activeSeconds = 0,
            casts = 0,
            refreshes = 0,
            targets = {},
            usedSpellID = nil,
            usedName = nil,
        }
        active.effects[effectKey] = data
    end

    return data
end

function CF.PerformanceStart(encounterID, encounterName)
    if IsSecretValue(encounterID) then return end
    if IsSecretValue(encounterName) or type(encounterName) ~= "string" then encounterName = nil end
    if not db or not db.performanceEnabled then
        return
    end

    if CF.performanceActive then
        if encounterID then
            CF.performanceActive.encounterID = encounterID
        end
        if encounterName and not IsSecretValue(encounterName) then
            CF.performanceActive.encounterName = encounterName
            CF.performanceActive.isEncounter = true
        end
        return
    end

    CF.performanceRecordingSerial = (CF.performanceRecordingSerial or 0) + 1
    CF.performanceActive = {
        recordingID = CF.performanceRecordingSerial,
        state = "active",
        lastObservedAt = GetTime(),
        addonVersion = VERSION,
        startedAt = GetTime(),
        startedEpoch = time and time() or 0,
        elapsed = 0,
        aliveSeconds = 0,
        deathCount = 0,
        encounterID = encounterID,
        encounterName = (encounterName and not IsSecretValue(encounterName)) and encounterName or nil,
        isEncounter = encounterName ~= nil,
        encounterSuccess = nil,
        effects = {},
        targetRelevant = {},
        seenTargets = {},
        primaryTargetName = nil,
        bossFallbackName = nil,
        totalDamage = 0,
        damageMeterAvailable = false,
        damageCaptureAt = 0,
        damageCache = nil,
        damageSessionID = nil,
    }
    CF.PerformanceBeginDamageWindow(CF.performanceActive)
    CF.PerformanceAdoptOpeningCasts(CF.performanceActive)
end

function CF.PerformanceMarkEncounterStart(encounterID, encounterName)
    if IsSecretValue(encounterID) then return end
    if IsSecretValue(encounterName) or type(encounterName) ~= "string" then encounterName = nil end
    if not db or not db.performanceEnabled then
        return
    end

    local openingWindow
    if CF.performanceActive and CF.performanceActive.isEncounter then
        -- Duplicate starts for the same running encounter are harmless.
        if CF.performanceActive.encounterID == encounterID then return end
        CF.PerformanceFinalize()
    end

    if CF.performanceActive and not CF.performanceActive.isEncounter then
        if GetTime()-CF.performanceActive.startedAt<=0.5 then
            openingWindow=CF.performanceActive
        end
        -- PLAYER_REGEN_DISABLED may precede ENCOUNTER_START. Carry only very
        -- recent casts explicitly belonging to a boss into the new sample.
        -- Unrelated trash casts must never move into a boss encounter.
        local opening={}
        for _,record in ipairs(CF.performanceActive.recentCasts or {}) do
            if GetTime()-record.at<=CF.PERFORMANCE_CAST_GRACE then
                for i=1,8 do
                    local unit="boss"..i
                    if UnitExistsReadable(unit) and (record.targetKey==unit
                        or (record.guid and SafeUnitGUID(unit)==record.guid)) then
                        opening[#opening+1]={spellID=record.spellID,spellName=record.spellName,
                            effect=record.effect,variant=record.variant,targetKey=unit,
                            guid=record.guid,unit=unit,targetName=record.targetName,
                            at=record.at,sentAt=record.sentAt,deadline=record.deadline,baseline=record.baseline,
                            earlyObservation=record.confirmedAura}
                        break
                    end
                end
            end
        end
        -- A boss can be engaged without dropping combat after trash. The boss
        -- performance sample must start at the encounter boundary, not at the
        -- earlier trash pull.
        CF.PerformanceFinalize()
        CF.performanceOpeningCasts=opening
    end

    CF.PerformanceStart(encounterID, encounterName)

    if CF.performanceActive then
        if openingWindow then
            -- REGEN_DISABLED and ENCOUNTER_START can describe the same pull.
            -- Retain its native-session boundary, not a false overlapping fight.
            local active=CF.performanceActive
            active.damageStartSessions=openingWindow.damageStartSessions
            active.damageBoundaryUncertain=openingWindow.damageBoundaryUncertain
            active.damageSessionID=openingWindow.damageSessionID
            active.damageSessionMatched=openingWindow.damageSessionMatched
            active.damageCandidate=openingWindow.damageCandidate
            active.damageBaselineAt=openingWindow.damageBaselineAt
            active.damageBaselineSource=openingWindow.damageBaselineSource
            local diagnostic=active.damageDiagnostics
            local previous=openingWindow.damageDiagnostics
            if diagnostic and previous then
                diagnostic.baseline=CF.PerformanceCopyDamageDiagnostics(previous.baseline)
                diagnostic.baselineStatus=previous.baselineStatus
                diagnostic.baselineSource=previous.baselineSource
                diagnostic.baselineAge=previous.baselineAge
            end
        end
        CF.performanceActive.encounterID = encounterID
        if encounterName and not IsSecretValue(encounterName) then
            CF.performanceActive.encounterName = encounterName
        end
        CF.performanceActive.isEncounter = true
    end
end

function CF.PerformanceMarkEncounterEnd(encounterID, encounterName, success, encounterUnitStatus)
    if IsSecretValue(encounterID) then return end
    if IsSecretValue(encounterName) or type(encounterName) ~= "string" then encounterName = nil end
    if IsSecretValue(success) or type(success) ~= "number" then success = nil end
    local active = CF.performanceActive
    if not active then
        return
    end

    -- A late end event must never close the following boss.
    if encounterID and active.encounterID and encounterID ~= active.encounterID then return end
    if encounterID then active.encounterID = encounterID end

    if encounterName and not IsSecretValue(encounterName) then
        active.encounterName = encounterName
    end

    active.isEncounter = true
    active.encounterSuccess = success
    CF.PerformanceTick(0)
    active.encounterEnded = true

    if not IsSecretValue(encounterUnitStatus) and type(encounterUnitStatus) == "table" then
        local status = {}
        local ok = pcall(function()
            for _, info in ipairs(encounterUnitStatus) do
                if not IsSecretValue(info) and type(info) == "table" then
                    status[#status + 1] = {
                        creatureID = CF.PerformanceReadableField(info, "creatureID"),
                        creatureName = CF.PerformanceReadableField(info, "creatureName"),
                        remainingHealthPercent = CF.PerformanceReadableField(info, "remainingHealthPercent"),
                    }
                end
            end
        end)
        if ok then active.encounterUnitStatus = status end
    end
    CF.PerformanceFinalize()
end

-- Detail records are independent of DamageMeter amounts. Tick counts are a
-- cast/duration model, not combat-log observations or a damage-loss estimate.
-- Refresh reset confirmed by the author's tests on Forever 1.60.1 (70245).
-- Base periods: wowhead.com/forever/spell=980 (2 s), =348 and =172 (3 s).
CF.PERFORMANCE_DETAIL_VERSION = 1
CF.PERFORMANCE_DETAIL_MAX_TARGETS = 128
CF.PERFORMANCE_DETAIL_MAX_EVENTS = 256

function CF.PerformanceDetailModel(variant)
    local seed = variant and variant.seedIDs and variant.seedIDs[1]
    if seed == 980 then return 2, seed end
    if seed == 348 or seed == 172 then return 3, seed end
    return nil, seed
end

function CF.PerformanceDetailDuration(spellID, variant)
    local fallback = tonumber(variant and variant.duration) or 0
    local interval = CF.PerformanceDetailModel(variant)
    if not interval then return fallback end
    -- Low ranks of Corruption are shorter than the endgame profile. Prefer the
    -- actual spell description (client language, independent of addon language).
    CF.performanceDetailDurationCache = CF.performanceDetailDurationCache or {}
    if CF.performanceDetailDurationCache[spellID] then
        return CF.performanceDetailDurationCache[spellID]
    end
    local seconds, ambiguous
    if C_Spell and C_Spell.GetSpellDescription then
        local ok, description = pcall(C_Spell.GetSpellDescription, spellID)
        if ok and not IsSecretValue(description) and type(description) == "string" then
            for value in string.gmatch(description, "(%d+[%.,]?%d*)%s+[Ss]e[kc]") do
                local n = tonumber((string.gsub(value, ",", ".")))
                if seconds and seconds ~= n then ambiguous = true end
                seconds = n
            end
        end
    end
    if seconds and not ambiguous and seconds >= interval and seconds <= 120 then
        CF.performanceDetailDurationCache[spellID] = seconds
        return seconds
    end
    if spellID == 172 then return 12 end
    if spellID == 6222 then return 15 end
    return fallback
end

function CF.PerformanceDetailObserveTarget(active, key, unit, name)
    if not active or not key then return nil end
    active.detailTargets = active.detailTargets or {}
    local target = active.detailTargets[key]
    if not target then
        active.detailTargetCount = active.detailTargetCount or 0
        if active.detailTargetCount >= CF.PERFORMANCE_DETAIL_MAX_TARGETS then
            active.detailTargetsTruncated = true
            return nil
        end
        active.detailTargetCount = active.detailTargetCount + 1
        target = { key=key, order=active.detailTargetCount,
            reliable=string.sub(key,1,5)=="guid:" or string.match(key,"^boss%d+$")~=nil }
        active.detailTargets[key] = target
    end
    if unit then name = SafeUnitName(unit, name) end
    if not IsSecretValue(name) and type(name)=="string"
        and name ~= CF.T("PROTECTED_TARGET") then target.name = name end
    return target
end

function CF.PerformanceDetailTicksBetween(origin, interval, first, last)
    if not origin or not interval or last <= first then return 0 end
    local a = math.max(0, math.floor((first-origin)/interval + 0.000001))
    local b = math.max(0, math.floor((last-origin)/interval + 0.000001))
    return math.max(0,b-a)
end

function CF.PerformanceDetailAdvance(target, now)
    if not target or not target.lastAt or now <= target.lastAt then return end
    local app = target.application
    if target.relevant and app and app.interval then
        local amount = CF.PerformanceDetailTicksBetween(app.appliedAt,app.interval,
            target.lastAt,math.min(now,app.expiresAt))
        target.actualTicks = target.actualTicks + amount
        app.ticks = app.ticks + amount
        target.referenceTicks = target.referenceTicks + CF.PerformanceDetailTicksBetween(
            target.referenceAt,app.interval,target.lastAt,now)
    end
    target.lastAt = now
end

function CF.PerformanceDetailRecordCast(active, data, targetKey, spellID, spellName, variant, now, duration)
    local info = CF.PerformanceDetailObserveTarget(active,targetKey,nil)
    if not info then return end
    local detail = data.detail
    if not detail then
        detail = { targets={}, events={}, eventTotal=0, eventNext=1 }
        data.detail = detail
    end
    local target = detail.targets[targetKey]
    if not target then
        target = { casts=0, refreshes=0, noTick=0, discarded=0, remaining=0,
            actualTicks=0, referenceTicks=0, knownCasts=0, unknownCasts=0 }
        detail.targets[targetKey] = target
    end
    CF.PerformanceDetailAdvance(target,now)
    local old = target.application
    local interval, model = CF.PerformanceDetailModel(variant)
    if not info.reliable then interval = nil end
    local same = old and old.model==model
    local early = same and old.expiresAt > now + 0.000001
    local remaining = early and (old.expiresAt-now) or 0
    local event = { at=math.max(0,now-active.startedAt), target=targetKey,
        spellID=spellID, kind=early and "refresh" or (old and (same and "reapply" or "replace") or "apply"),
        remaining=remaining, duration=duration, interval=interval }
    if early then
        target.refreshes = target.refreshes + 1
        target.remaining = target.remaining + remaining
        if old.interval then
            local age = math.max(0,now-old.appliedAt)
            local fullTicks = math.floor(age/old.interval + 0.000001)
            local progress = math.max(0,age-fullTicks*old.interval)
            target.discarded = target.discarded + progress
            event.discarded = progress
            event.noTick = fullTicks==0
            if event.noTick then target.noTick = target.noTick + 1 end
        end
    elseif old and same then
        event.gap = math.max(0,now-old.expiresAt)
    end
    if not same or not interval or not old.interval then target.referenceAt = now end
    target.application = { appliedAt=now, expiresAt=now+duration, interval=interval, model=model, ticks=0 }
    target.relevant = true
    target.lastAt = now
    target.casts = target.casts + 1
    if interval then target.knownCasts = target.knownCasts + 1
    else target.unknownCasts = target.unknownCasts + 1 end
    detail.eventTotal = detail.eventTotal + 1
    detail.events[detail.eventNext] = event
    detail.eventNext = (detail.eventNext % CF.PERFORMANCE_DETAIL_MAX_EVENTS) + 1
end

function CF.PerformanceDetailCoverage(data, key, seconds)
    local active = CF.performanceActive
    if not active or not active.detailTargets or not active.detailTargets[key] then return end
    data.detailCovered = data.detailCovered or {}
    data.detailCovered[key] = (data.detailCovered[key] or 0) + seconds
end

function CF.PerformanceDetailTick(active, now, elapsed, relevant)
    if active.detailFinished then return end
    for _, data in pairs(active.effects or {}) do
        for key, target in pairs((data.detail and data.detail.targets) or {}) do
            local pending=data.pendingTargets and data.pendingTargets[key]
            if pending then
                if not relevant[key] then pending.coverageUnknown=true end
            elseif relevant[key] then
                if not target.relevant then
                    target.lastAt = math.max(target.lastAt or now,now-elapsed)
                end
                target.relevant = true
                CF.PerformanceDetailAdvance(target,now)
            else
                -- A newly unavailable target ends at the last observation.
                if target.relevant then
                    active.detailCoverageIncomplete = true
                    active.unobservedTargets=active.unobservedTargets or {}
                    active.unobservedTargets[key]=true
                end
                target.relevant = false
                target.lastAt = now
            end
        end
    end
end

function CF.PerformanceDetailTargetDied(unit)
    local active = CF.performanceActive
    if not active or active.detailFinished then return end
    local key = CF.GetPerformanceTargetKey(unit)
    if not key then return end
    CF.PerformanceResolvePending(true,key)
    local now = GetTime()
    for _, data in pairs(active.effects or {}) do
        local target = data.detail and data.detail.targets[key]
        if target then
            CF.PerformanceDetailAdvance(target,now)
            target.relevant = false
            target.application = nil
            target.referenceAt = nil
        end
    end
end

-- An identity-only death closes the existing model without advancing it
-- through an interval for which no matching unit was available.
function CF.PerformanceDetailTargetGUIDDied(key)
    if not CF.DeathEvents or not CF.DeathEvents.ReadGUID(key) then return end
    local active = CF.performanceActive
    if not active or active.detailFinished then return end
    local targetKey = "guid:" .. key
    CF.PerformanceResolvePending(true,targetKey)
    for _, data in pairs(active.effects or {}) do
        local target = data.detail and data.detail.targets[targetKey]
        if target then
            target.relevant = false
            target.application = nil
            target.referenceAt = nil
        end
    end
end

function CF.PerformanceDetailFinish(active, now)
    if not active or active.detailFinished then return end
    CF.PerformanceResolvePending(true)
    for _, data in pairs(active.effects or {}) do
        for _, target in pairs((data.detail and data.detail.targets) or {}) do
            CF.PerformanceDetailAdvance(target,now)
        end
    end
    active.detailFinished = true
end

function CF.PerformanceDetailBuildSnapshot(active, data)
    local detail = data.detail or {}
    local result = { version=CF.PERFORMANCE_DETAIL_VERSION, targets={}, events={},
        eventTotal=detail.eventTotal or 0, targetsTruncated=active.detailTargetsTruncated or false,
        coverageIncomplete=active.detailCoverageIncomplete or false }
    for key, info in pairs(active.detailTargets or {}) do
        local target = (detail.targets and detail.targets[key]) or {}
        local relevant = tonumber((active.targetRelevant or {})[key]) or 0
        local covered = math.min(relevant,tonumber((data.detailCovered or {})[key]) or 0)
        result.targets[#result.targets+1] = {
            key=key, name=info.name, order=info.order, reliable=info.reliable,
            relevant=relevant, covered=covered, casts=target.casts or 0, refreshes=target.refreshes or 0,
            noTick=target.noTick or 0, discarded=target.discarded or 0, remaining=target.remaining or 0,
            actualTicks=target.actualTicks or 0, referenceTicks=target.referenceTicks or 0,
            lostTicks=math.max(0,(target.referenceTicks or 0)-(target.actualTicks or 0)),
            knownCasts=target.knownCasts or 0, unknownCasts=target.unknownCasts or 0,
            unconfirmed=target.unconfirmed or 0, notApplied=target.notApplied or 0,
            clientRestricted=target.clientRestricted or 0,
        }
    end
    table.sort(result.targets,function(a,b) return a.order < b.order end)
    local count = math.min(result.eventTotal,CF.PERFORMANCE_DETAIL_MAX_EVENTS)
    local first = result.eventTotal > count and detail.eventNext or 1
    for i=0,count-1 do
        local event = detail.events[((first+i-1)%CF.PERFORMANCE_DETAIL_MAX_EVENTS)+1]
        local copy = {}
        for key,value in pairs(event) do copy[key] = value end
        result.events[#result.events+1] = copy
    end
    return result
end

-- A cast completion is an attempt, not proof of an applied aura. Only use
-- readable, player-filtered aura data; protected results stay unknown. Never
-- inspect AuraContainer widgets or register a restricted combat-log event.
CF.PERFORMANCE_CAST_GRACE = 5
CF.PERFORMANCE_AURA_WAIT = 2.5
CF.PERFORMANCE_AURA_SCAN_LIMIT = 80

-- Keep only application totals and the restriction flag needed by the UI.
-- Detailed development error logs are no longer collected or archived.
CF.PERFORMANCE_AURA_BLOCK_TARGETS = 128

function CF.SafeStatusText(value)
    -- Check protection before comparing, formatting or converting the value.
    if issecretvalue then
        local ok,secret=pcall(issecretvalue,value)
        if not ok or secret then return "[protected/unreadable text]" end
    end
    if type(value)~="string" then return "[non-string value]" end
    local ok,text=pcall(function()
        local clean=string.gsub(value,"[%c]"," ")
        clean=string.gsub(clean,"|","/") -- disable chat links, textures and colours
        if #clean>320 then
            clean=string.sub(clean,1,320-3)
            -- Do not finish a shortened UTF-8 message inside a character.
            clean=string.gsub(clean,"[\194-\244][\128-\191]*$","").."..."
        end
        return clean
    end)
    return ok and text or "[unreadable text]"
end

function CF.PerformanceIsAuraAccessError(text)
    text=CF.SafeStatusText(text)
    -- Match only the client's observed access-denial message. Ordinary Lua
    -- errors, empty results and protected fields must not disable a lookup.
    return string.find(text,"GetDebuffDataByIndex(): Auras cannot be accessed when secret",1,true)~=nil
end

function CF.PerformanceAuraWasRestricted(data)
    local d=data and data.auraDiagnostics
    if not d then return false end
    if d.restrictedCasts~=nil then return d.restrictedCasts>0 end
    -- Read-only presentation of the exact denial captured by 1.2.11. Do not
    -- rewrite archived counts or infer a restriction from an empty lookup.
    if (d.unknown or 0)<=0 then return false end
    for i=1,math.min(#(d.errors or {}),4) do
        local sample=d.errors[i]
        if sample.method=="index" and sample.stage=="call"
            and CF.PerformanceIsAuraAccessError(sample.text) then return true end
    end
    return false
end

function CF.PerformanceAuraIndexPaused(record)
    if record.auraIndexBlocked then return true end
    local key=record.guid or record.targetKey
    if IsSecretValue(key) or type(key)~="string" then return false end
    local active=CF.performanceActive
    return active and active.auraIndexBlockedTargets and active.auraIndexBlockedTargets[key]==true or false
end

function CF.PerformancePauseAuraIndex(record)
    record.auraIndexBlocked=true
    record.auraAccessBlocked=true
    local active=CF.performanceActive
    local key=record.guid or record.targetKey
    if not active or IsSecretValue(key) or type(key)~="string" then return end
    active.auraIndexBlockedTargets=active.auraIndexBlockedTargets or {}
    if not active.auraIndexBlockedTargets[key]
        and (active.auraIndexBlockedCount or 0)<CF.PERFORMANCE_AURA_BLOCK_TARGETS then
        active.auraIndexBlockedTargets[key]=true
        active.auraIndexBlockedCount=(active.auraIndexBlockedCount or 0)+1
    end
    -- The cache belongs to this fight; overflow targets remain paused per cast.
end

function CF.PerformanceCastUnit(record)
    if record.targetUnknown then return nil end
    local function Matches(unit)
        if not unit or not UnitExistsReadable(unit) then return false end
        if record.guid then return SafeUnitGUID(unit)==record.guid end
        return record.targetKey and string.match(record.targetKey,"^boss%d+$")
            and unit==record.targetKey
    end
    if Matches("target") then return "target" end
    if Matches(record.unit) then return record.unit end
    if Matches("focus") then return "focus" end
    if Matches("mouseover") then return "mouseover" end
    for i=1,8 do if Matches("boss"..i) then return "boss"..i end end
    for unit in pairs(visibleUnits) do if Matches(unit) then return unit end end
end

function CF.PerformanceInspectOwnAura(aura,record,method)
    if IsSecretValue(aura) then return {state="unknown",reason="protected"} end
    if aura==nil then return {state="unknown",reason="empty"} end
    if type(aura)~="table" then
        return {state="unknown",reason="return_type"}
    end
    -- Some clients protect individual fields rather than the whole result.
    local readable,result=pcall(function()
        local expiry,duration,spellID,source,name=aura.expirationTime,aura.duration,
            aura.spellId,aura.sourceUnit,aura.name
        if IsSecretValue(expiry) or IsSecretValue(duration) or IsSecretValue(spellID)
            or IsSecretValue(source) or IsSecretValue(name) then
            return {state="unknown",reason="protected"}
        end
        if source and source~="player" then return {state="unknown",reason="source"} end
        -- A rank-specific aura ID may differ from the cast ID. The readable
        -- localized spell name is a second exact identity check, not a guess.
        if spellID~=record.spellID and not (type(name)=="string" and record.spellName
            and CF.StringEqualsIgnoreCase(name,record.spellName)) then
            return {state="unknown",reason="identity"}
        end
        if type(expiry)~="number" or type(duration)~="number" or duration<=0
            or duration==math.huge or expiry==math.huge or duration~=duration
            or expiry~=expiry or expiry<=GetTime() or expiry-duration>GetTime()+0.05 then
            return {state="unknown",reason="timing"}
        end
        return {state="present",reason=method,expiresAt=expiry,duration=duration,
            appliedAt=expiry-duration}
    end)
    return readable and result or {state="unknown",reason="field_error"}
end

function CF.PerformanceReadOwnAura(record)
    local unit=CF.PerformanceCastUnit(record)
    if not unit then return {state="unknown",reason="target"} end
    if UnitIsActuallyDead(unit) then return {state="unknown",reason="dead"} end
    if not C_UnitAuras then return {state="unknown",reason="api_missing"} end
    local named={state="unknown",reason="api_missing"}
    if record.spellName and C_UnitAuras.GetAuraDataBySpellName then
        local ok,aura=pcall(C_UnitAuras.GetAuraDataBySpellName,unit,record.spellName,"HARMFUL|PLAYER")
        named=ok and CF.PerformanceInspectOwnAura(aura,record,"name")
            or {state="unknown",reason="name_error"}
        if named.state=="present" then return named end
    end
    -- Empty name results do not prove absence. Only readable, attributable
    -- aura data may confirm an application. A paused list never blocks names.
    if not C_UnitAuras.GetDebuffDataByIndex then return named end
    if CF.PerformanceAuraIndexPaused(record) then
        return {state="unknown",reason="access_blocked"}
    end
    local result={state="unknown",reason="no_match"}
    for index=1,CF.PERFORMANCE_AURA_SCAN_LIMIT do
        local ok,aura=pcall(C_UnitAuras.GetDebuffDataByIndex,unit,index,"HARMFUL|PLAYER")
        if not ok then
            result.reason="index_error"
            if CF.PerformanceIsAuraAccessError(aura) then
                CF.PerformancePauseAuraIndex(record)
                result.reason="access_blocked"
            end
            break
        end
        if IsSecretValue(aura) then result.reason="protected"; break end
        if aura==nil then break end
        local found=CF.PerformanceInspectOwnAura(aura,record,"index")
        if found.state=="present" then return found end
        if found.reason~="identity" and found.reason~="source" then result.reason=found.reason end
        if index==CF.PERFORMANCE_AURA_SCAN_LIMIT then result.reason="limit" end
    end
    return result
end

function CF.PerformancePrepareCast(spellID, targetName, castGUID)
    if not db or not db.performanceEnabled or IsSecretValue(spellID) then return end
    local effect,variant,_,_,name=CF.ResolvePerformanceEffect(spellID)
    if not effect or not variant or effect.passive then return end
    local r={spellID=spellID,spellName=name,effect=effect,variant=variant,
        targetKey="unconfirmed-target",targetUnknown=true,
        targetName=CF.T("PERFORMANCE_TARGET_UNCONFIRMED"),sentAt=GetTime(),
        baseline={state="unknown",reason="target"}}
    if IsSecretValue(targetName) or type(targetName)~="string" or targetName=="" then return r end
    local seen, count, chosen={},0,nil
    local function Consider(unit)
        if not UnitExistsReadable(unit) or not IsHostile(unit) or UnitIsActuallyDead(unit) then return end
        if SafeUnitName(unit,nil)~=targetName then return end
        local key=CF.GetPerformanceTargetKey(unit)
        local reliable=key and (string.sub(key,1,5)=="guid:" or string.match(key,"^boss%d+$"))
        if not reliable then count=count+1; return end
        if not seen[key] then
            seen[key]=true; count=count+1
            chosen={key=key,unit=unit,guid=SafeUnitGUID(unit)}
        end
    end
    local recipient = CF.ResolveCastRecipient and CF.ResolveCastRecipient(targetName,castGUID,spellID)
    if recipient and recipient.unit and SafeUnitGUID(recipient.unit)==recipient.guid then Consider(recipient.unit)
    elseif not recipient then
        Consider("target"); Consider("focus"); Consider("mouseover")
        for i=1,8 do Consider("boss"..i) end
        for unit in pairs(visibleUnits) do Consider(unit) end
    end
    if count~=1 or not chosen then return r end
    r.targetUnknown=false; r.targetKey=chosen.key; r.guid=chosen.guid
    r.unit=chosen.unit; r.targetName=targetName
    local ok,classification=pcall(UnitClassification,chosen.unit)
    r.worldBoss=ok and not IsSecretValue(classification) and classification=="worldboss"
    r.baseline=CF.PerformanceReadOwnAura(r)
    return r
end

function CF.PerformanceCastSent(targetName,castGUID,spellID)
    if IsSecretValue(castGUID) or type(castGUID)~="string" then return end
    CF.performanceSent=CF.performanceSent or {}
    local now=GetTime()
    for key,record in pairs(CF.performanceSent) do
        if now-record.sentAt>15 then CF.performanceSent[key]=nil end
    end
    local r=CF.PerformancePrepareCast(spellID,targetName,castGUID)
    if not r then return end
    CF.performanceSent[castGUID]=r
end

function CF.PerformanceAttachCast(active,r)
    local data=CF.PerformanceEnsureEffectData(r.effect.key)
    if not data then return end
    r.relevantAt=(active.targetRelevant or {})[r.targetKey] or 0
    r.coveredAt=(data.detailCovered or {})[r.targetKey] or 0
    data.pendingTargets=data.pendingTargets or {}
    data.pendingTargets[r.targetKey]=r
    active.pendingCasts=active.pendingCasts or {}
    active.pendingCasts[#active.pendingCasts+1]=r
    active.recentCasts=active.recentCasts or {}
    if #active.recentCasts>=16 then table.remove(active.recentCasts,1) end
    active.recentCasts[#active.recentCasts+1]=r
    active.seenTargets[r.targetKey]=true
    CF.PerformanceDetailObserveTarget(active,r.targetKey,nil,r.targetName)
    if not active.primaryTargetName then
        active.primaryTargetName=r.targetName
        if r.worldBoss then active.bossFallbackName=r.targetName end
    end
end

function CF.PerformanceAdoptOpeningCasts(active)
    local queued=CF.performanceOpeningCasts or {}
    CF.performanceOpeningCasts={}
    local now=GetTime()
    for _,r in ipairs(queued) do
        if now-r.at<=CF.PERFORMANCE_CAST_GRACE then
            r.opening=true
            CF.PerformanceAttachCast(active,r)
        end
    end
    CF.PerformanceResolvePending(false)
end

function CF.PerformanceRecordCast(spellID,castGUID)
    if not db or not db.performanceEnabled or IsSecretValue(spellID) then return end
    local now=GetTime()
    local safeGUID=not IsSecretValue(castGUID) and type(castGUID)=="string" and castGUID or nil
    CF.performanceSeenCasts=CF.performanceSeenCasts or {}
    for key,at in pairs(CF.performanceSeenCasts) do
        if now-at>15 then CF.performanceSeenCasts[key]=nil end
    end
    if safeGUID and CF.performanceSeenCasts[safeGUID] then return end
    local r=safeGUID and CF.performanceSent and CF.performanceSent[safeGUID]
    if safeGUID and CF.performanceSent then CF.performanceSent[safeGUID]=nil end
    if not r or r.spellID~=spellID or now-r.sentAt>15 then
        r=CF.PerformancePrepareCast(spellID)
        -- A post-cast snapshot is not a valid pre-refresh baseline.
        if r then r.baseline={state="unknown"} end
    end
    if not r then return end
    if safeGUID then CF.performanceSeenCasts[safeGUID]=now end
    r.at=now; r.deadline=now+CF.PERFORMANCE_AURA_WAIT
    local active=CF.performanceActive
    if active and not active.encounterEnded then
        -- Resolve older applications before freezing this target's model.
        CF.PerformanceResolvePending(false)
        local data=CF.PerformanceEnsureEffectData(r.effect.key)
        if data and data.pendingTargets and data.pendingTargets[r.targetKey] then
            -- Another cast on the same effect/target supersedes an unresolved
            -- observation. The older cast must remain explicitly unknown.
            data.pendingTargets[r.targetKey].superseded=true
            CF.PerformanceResolvePending(false)
        end
        CF.PerformanceAttachCast(active,r)
        CF.PerformanceResolvePending(false)
    elseif not active then
        local kept={}
        for _,old in ipairs(CF.performanceOpeningCasts or {}) do
            if now-old.at<=CF.PERFORMANCE_CAST_GRACE then kept[#kept+1]=old end
        end
        if #kept>=8 then table.remove(kept,1) end
        kept[#kept+1]=r; CF.performanceOpeningCasts=kept
        -- This observation can be readable before combat secrecy begins.
        r.earlyObservation=CF.PerformanceReadOwnAura(r)
    end
end

function CF.PerformanceApplicationResult(r,observation,force)
    if r.superseded or r.targetUnknown then return "unknown" end
    local old=r.baseline or {state="unknown"}
    if observation.state=="present" then
        local at=observation.appliedAt
        -- Require timing attributable to this attempt, not just an older aura.
        if at>=r.at-0.35 and at<=r.deadline and
            ((old.state=="present" and
                (observation.expiresAt>old.expiresAt+0.05
                    or (old.appliedAt and at>old.appliedAt+0.05))) or
             (old.state=="unknown" and at>=math.max((r.sentAt or r.at)-0.05,r.at-0.35))) then
            return "applied",observation
        end
    end
    if force or GetTime()>=r.deadline then
        -- Only a repeatedly readable, unchanged old timer supports a failed
        -- refresh. Missing/filtered/short observations always remain unknown.
        if GetTime()>=r.deadline and not r.sawUnknown and (r.presentSamples or 0)>=2
            and r.firstPresentAt and r.firstPresentAt<=r.at+0.35 then
            if old.state=="present" and observation.state=="present" and not r.changedAura
                and observation.expiresAt==old.expiresAt and old.expiresAt>GetTime() then
                return "not_applied"
            end
        end
        return "unknown"
    end
end

function CF.PerformanceRecordApplicationStatus(data,r,status)
    -- Preserve the archive field name for compatibility with older recordings.
    local d=data.auraDiagnostics or {version=4,applied=0,not_applied=0,unknown=0,restrictedCasts=0}
    data.auraDiagnostics=d
    d[status]=(d[status] or 0)+1
    r.clientRestricted=status=="unknown" and r.auraAccessBlocked==true
    if r.clientRestricted then d.restrictedCasts=(d.restrictedCasts or 0)+1 end
end

function CF.PerformanceCopyApplicationStatus(data)
    local d=data.auraDiagnostics
    if not d then return nil end
    return {version=d.version,applied=d.applied,not_applied=d.not_applied,
        unknown=d.unknown,restrictedCasts=d.restrictedCasts}
end

function CF.PerformanceRecordUnapplied(active,data,r,status)
    if not active.detailTargets[r.targetKey] then
        data.unconfirmed=(data.unconfirmed or 0)+1
        return
    end
    data.detail=data.detail or {targets={},events={},eventTotal=0,eventNext=1}
    local detail=data.detail
    local target=detail.targets[r.targetKey]
    if not target then
        target={casts=0,refreshes=0,noTick=0,discarded=0,remaining=0,
            actualTicks=0,referenceTicks=0,knownCasts=0,unknownCasts=0}
        detail.targets[r.targetKey]=target
    end
    target.casts=target.casts+1
    if status=="unknown" then
        target.unconfirmed=(target.unconfirmed or 0)+1
        target.unknownCasts=target.unknownCasts+1
        data.unconfirmed=(data.unconfirmed or 0)+1
        if r.clientRestricted then target.clientRestricted=(target.clientRestricted or 0)+1 end
    else
        target.notApplied=(target.notApplied or 0)+1
        data.notApplied=(data.notApplied or 0)+1
    end
    detail.eventTotal=detail.eventTotal+1
    detail.events[detail.eventNext]={at=math.max(0,r.at-active.startedAt),target=r.targetKey,
        spellID=r.spellID,kind=status=="unknown" and "unconfirmed" or "not_applied",
        opening=r.opening,clientRestricted=r.clientRestricted}
    detail.eventNext=(detail.eventNext%CF.PERFORMANCE_DETAIL_MAX_EVENTS)+1
end

function CF.PerformanceCommitApplication(active,data,r,aura)
    data.confirmedApplications=(data.confirmedApplications or 0)+1
    local now=GetTime()
    local appliedAt=math.max(r.at,aura.appliedAt)
    local duration=math.max(0,aura.expiresAt-appliedAt)
    -- While awaiting confirmation, the previous confirmed aura continued to
    -- contribute coverage, but its tick model was frozen. Correct only this
    -- target's short confirmation window; never another target's coverage.
    local relevant=math.max(0,(active.targetRelevant[r.targetKey] or 0)-r.relevantAt)
    local oldCovered=math.max(0,(data.detailCovered or {})[r.targetKey] or 0)-r.coveredAt
    local added=math.min(relevant,math.max(0,now-math.max(appliedAt,active.startedAt)))
    local old=data.targets[r.targetKey]
    -- Retain pre-impact coverage when a previous confirmed aura was still up.
    if old and old.expiresAt>r.at then
        added=math.min(relevant,added+math.max(0,math.min(appliedAt,old.expiresAt)-math.max(r.at,active.startedAt)))
    end
    local correction=added-oldCovered
    data.activeSeconds=math.max(0,(data.activeSeconds or 0)+correction)
    data.detailCovered=data.detailCovered or {}
    data.detailCovered[r.targetKey]=math.max(0,(data.detailCovered[r.targetKey] or 0)+correction)
    CF.PerformanceDetailRecordCast(active,data,r.targetKey,r.spellID,r.spellName,r.variant,appliedAt,duration)
    local target=data.detail and data.detail.targets[r.targetKey]
    if target then
        target.lastAt=math.max(target.lastAt,active.startedAt)
        if r.coverageUnknown then
            target.unconfirmed=(target.unconfirmed or 0)+1
            target.unknownCasts=target.unknownCasts+1
            data.unconfirmed=(data.unconfirmed or 0)+1
        end
    end
    if old and old.expiresAt>appliedAt and (old.spellID==r.spellID
        or (old.name and r.spellName and CF.StringEqualsIgnoreCase(old.name,r.spellName))) then
        data.refreshes=(data.refreshes or 0)+1
    end
    data.targets[r.targetKey]={expiresAt=aura.expiresAt,spellID=r.spellID,name=r.spellName}
end

function CF.PerformanceResolvePending(force,onlyKey)
    local active=CF.performanceActive
    if not active or active.detailFinished then return end
    local pending=active.pendingCasts or {}
    if #pending==0 then return end
    local kept={}
    for _,r in ipairs(pending) do
        local observation=r.earlyObservation or CF.PerformanceReadOwnAura(r)
        r.earlyObservation=nil
        if observation.reason=="access_blocked" then r.auraAccessBlocked=true end
        if observation.state=="unknown" then r.sawUnknown=true end
        if observation.state=="present" then
            r.sawPresent=true
            r.presentSamples=(r.presentSamples or 0)+1
            r.firstPresentAt=r.firstPresentAt or GetTime()
            if r.baseline and r.baseline.state=="present"
                and (observation.expiresAt~=r.baseline.expiresAt
                    or observation.appliedAt~=r.baseline.appliedAt) then r.changedAura=true end
        end
        local status,aura=CF.PerformanceApplicationResult(r,observation,force and (not onlyKey or onlyKey==r.targetKey))
        if status then
            local data=CF.PerformanceEnsureEffectData(r.effect.key)
            if data then
                if data.pendingTargets[r.targetKey]==r then data.pendingTargets[r.targetKey]=nil end
                data.casts=(data.casts or 0)+1
                data.usedSpellID=r.spellID; data.usedName=r.spellName or data.usedName
                CF.PerformanceRecordApplicationStatus(data,r,status)
                if status=="applied" then CF.PerformanceCommitApplication(active,data,r,aura)
                else CF.PerformanceRecordUnapplied(active,data,r,status) end
                r.confirmedAura=aura
            end
        else kept[#kept+1]=r end
    end
    active.pendingCasts=kept
end

function CF.PerformanceMarkPlayerDeath()
    local active = CF.performanceActive
    if active and not active.encounterEnded then
        active.deathCount = (active.deathCount or 0) + 1
    end
end

function CF.PerformanceBossUnitRelevant(unit)
    if not unit or not UnitExistsReadable(unit) then
        return false
    end

    return ReadClientBoolean(UnitIsDeadOrGhost, unit) == false
        and ReadClientBoolean(UnitCanAttack, "player", unit) == true
end

-- A readable number and an absent/protected value have different meanings.
function CF.PerformanceReadableField(object, key)
    if IsSecretValue(object) or type(object)~="table" then return nil end
    local ok,value=pcall(function() return object[key] end)
    if not ok or IsSecretValue(value) then return nil end
    return value
end

function CF.PerformanceReadableNumber(value)
    if IsSecretValue(value) or type(value)~="number" then return nil end
    if value~=value or value==math.huge or value==-math.huge or value<0 then return nil end
    return value
end

function CF.PerformanceEmptyDamage(reason)
    return {spellDamage={},totalDamageKnown=false,spellBreakdownKnown=false,
        available=false,sourceFound=false,spellCount=0,sessionMatched=false,
        partial=false,reason=reason or "unavailable"}
end

function CF.PerformanceReadDamageSource(source, result)
    if IsSecretValue(source) or type(source)~="table" then return result end
    result.sourceFound=true
    local total=CF.PerformanceReadableNumber(CF.PerformanceReadableField(source,"totalAmount"))
    if total~=nil then result.totalDamage=total; result.totalDamageKnown=true end
    local spells=CF.PerformanceReadableField(source,"combatSpells")
    local complete=type(spells)=="table"
    local sum=0
    if complete then
        -- The detailed source replaces a readable header breakdown, if any.
        result.spellDamage={}; result.spellCount=0
        local ok=pcall(function()
            for _,spell in ipairs(spells) do
                local id=CF.PerformanceReadableNumber(CF.PerformanceReadableField(spell,"spellID"))
                local amount=CF.PerformanceReadableNumber(CF.PerformanceReadableField(spell,"totalAmount"))
                if not id or id<=0 or amount==nil then
                    complete=false
                else
                    result.spellCount=result.spellCount+1
                    sum=sum+amount
                    local effect=CF.ResolvePerformanceEffect(id)
                    if effect then result.spellDamage[effect.key]=(result.spellDamage[effect.key] or 0)+amount end
                end
            end
        end)
        if not ok then complete=false end
    end
    -- A truncated/empty breakdown must not make an absent spell a known zero.
    -- Do not invent a total by summing a possibly incomplete spell list.
    result.spellBreakdownKnown=complete and result.totalDamageKnown
        and math.abs(sum-result.totalDamage)<0.001 or false
    return result
end

function CF.PerformanceParseDamageSession(session, sourceGetter, sessionID, reason)
    local result=CF.PerformanceEmptyDamage(reason)
    result.sessionID=sessionID
    if IsSecretValue(session) or type(session)~="table" then return result end
    result.available=true
    result.durationSeconds=CF.PerformanceReadableNumber(CF.PerformanceReadableField(session,"durationSeconds"))
    local sources=CF.PerformanceReadableField(session,"combatSources")
    local localSource
    if type(sources)=="table" then
        pcall(function()
            for _,candidate in ipairs(sources) do
                if CF.PerformanceReadableField(candidate,"isLocalPlayer")==true then
                    localSource=candidate; break
                end
            end
        end)
    end
    if not localSource then result.reason="local-source-not-found"; return result end
    CF.PerformanceReadDamageSource(localSource,result)
    local guid=CF.PerformanceReadableField(localSource,"sourceGUID")
    local creatureID=CF.PerformanceReadableField(localSource,"sourceCreatureID")
    if not IsSafeGUIDKey(guid) then guid=SafeUnitGUID("player") end
    if not IsSafeGUIDKey(guid) then guid=nil end
    if sourceGetter and (guid or creatureID) then
        local ok,source=pcall(sourceGetter,guid,creatureID)
        if ok then CF.PerformanceReadDamageSource(source,result) end
    end
    return result
end

function CF.PerformanceReadDamageSessionByID(sessionID)
    if not CF.PerformanceReadableNumber(sessionID) or sessionID<=0 or not C_DamageMeter
        or not C_DamageMeter.GetCombatSessionFromID then return nil,"session-api-or-id-unavailable" end
    local damageType=(Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
    local ok,session=pcall(C_DamageMeter.GetCombatSessionFromID,sessionID,damageType)
    if not ok then return nil,"session-call-failed" end
    if IsSecretValue(session) then return nil,"session-protected" end
    if type(session)~="table" then return nil,"session-unavailable" end
    local getter
    if C_DamageMeter.GetCombatSessionSourceFromID then
        getter=function(guid,creatureID)
            return C_DamageMeter.GetCombatSessionSourceFromID(sessionID,damageType,guid,creatureID)
        end
    end
    return CF.PerformanceParseDamageSession(session,getter,sessionID,"recording-session-id")
end

function CF.PerformanceListDamageSessions()
    if not C_DamageMeter or not C_DamageMeter.GetAvailableCombatSessions then return nil,"list-api-missing" end
    local ok,list=pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok then return nil,"list-call-failed" end
    if IsSecretValue(list) then return nil,"list-protected" end
    if type(list)~="table" then return nil,"list-unavailable" end
    local sessions={}
    local zeroIDs=0
    local readable=pcall(function()
        for _,info in ipairs(list) do
            local id=CF.PerformanceReadableNumber(CF.PerformanceReadableField(info,"sessionID"))
            if id==nil then error("unreadable session identity") end
            if id>0 then sessions[id]={durationSeconds=CF.PerformanceReadableNumber(
                CF.PerformanceReadableField(info,"durationSeconds"))}
            else zeroIDs=zeroIDs+1 end
        end
    end)
    if not readable then return nil,"list-identity-unreadable" end
    return sessions,"ok",zeroIDs
end

-- Store bounded, readable metadata only. No protected payloads, raw errors,
-- character names or GUIDs are copied into the damage-session diagnostic.
function CF.PerformanceCopyDamageDiagnostics(value)
    if type(value)~="table" then return value end
    local copy={}
    for key,item in pairs(value) do copy[key]=CF.PerformanceCopyDamageDiagnostics(item) end
    return copy
end

function CF.PerformanceDamageSessionSummary(sessions, zeroIDs)
    if not sessions then return nil end
    local ids={}
    for id in pairs(sessions) do ids[#ids+1]=id end
    table.sort(ids)
    local result={count=#ids,zeroIDs=zeroIDs or 0,sessions={},truncated=#ids>20}
    for i=1,math.min(20,#ids) do
        local id=ids[i]
        result.sessions[i]={sessionID=id,durationSeconds=sessions[id].durationSeconds}
    end
    return result
end

function CF.PerformanceDamageTrace(active, reason, data)
    if not active then return end
    local d=active.damageDiagnostics
    if not d then d={version=1,trace={}}; active.damageDiagnostics=d end
    d.reason=reason
    local startedAt=active.startedAt or GetTime()
    d.expectedDuration=math.max(0,(active.endedAt or GetTime())-startedAt)
    if data then
        d.nativeDuration=data.durationSeconds
        d.totalDamageKnown=data.totalDamageKnown and true or false
        d.spellBreakdownKnown=data.spellBreakdownKnown and true or false
        d.sourceFound=data.sourceFound and true or false
    end
    local last=d.trace[#d.trace]
    if not last or last.reason~=reason or last.sessionID~=d.candidateID
        or last.newCount~=d.newCount then
        d.trace[#d.trace+1]={at=math.max(0,GetTime()-startedAt),reason=reason,
            sessionID=d.candidateID,newCount=d.newCount,nativeDuration=d.nativeDuration,
            expectedDuration=d.expectedDuration}
        if #d.trace>16 then table.remove(d.trace,1) end
    end
end

function CF.PerformanceObserveIdleDamageSessions()
    if not db or not db.performanceEnabled or CF.performanceActive or PlayerInCombat() then return end
    local now=GetTime()
    if CF.performanceIdleDamageAt and now-CF.performanceIdleDamageAt<0.5 then return end
    local sessions,status,zeroIDs=CF.PerformanceListDamageSessions()
    CF.performanceIdleDamageAt=now
    CF.performanceIdleDamageSessions=sessions
    CF.performanceIdleDamageStatus=status
    CF.performanceIdleDamageZeroIDs=zeroIDs
end

function CF.PerformanceDamageDurationMatches(active, data)
    local duration=data and data.durationSeconds
    local expected=math.max(0,(active.endedAt or GetTime())-active.startedAt)
    -- Timing is only a rejection check after the native ID passed the window
    -- checks. Similar duration by itself is never used to select a session.
    return duration~=nil and duration>0 and math.abs(duration-expected)<=1
end

function CF.PerformanceBeginDamageWindow(active)
    local previous=CF.performanceDamageWindow
    if previous then
        -- Settle a delayed result before opening another matching window.
        -- After this point the previous recording may only read its bound ID.
        if previous.endedAt and not previous.damageSessionMatched then
            CF.PerformanceFindBestAvailableSession(previous)
        end
        previous.damageWindowClosed=true
        -- An unresolved overlapping finalization blocks fresh late IDs. An
        -- already completed retry window does not disable all future fights.
        active.damageBoundaryUncertain=not previous.damageSessionMatched
            and (previous.state=="waiting" or not previous.endedAt
                or GetTime()-previous.endedAt<3)
    end
    local sessions,status,zeroIDs=CF.PerformanceListDamageSessions()
    local idleAt=CF.performanceIdleDamageAt
    -- The native session may already exist when REGEN_DISABLED is delivered.
    -- A recent out-of-combat baseline keeps that ID from becoming historical
    -- merely because the client's event follows native session creation.
    local idleAge=idleAt and GetTime()-idleAt
    local useIdle=CF.performanceIdleDamageSessions and idleAge and idleAge>=0 and idleAge<=2
    active.damageStartSessions=useIdle and CF.performanceIdleDamageSessions or sessions
    active.damageBaselineAt=useIdle and idleAt or GetTime()
    active.damageBaselineSource=useIdle and "pre-combat" or "combat-start"
    active.damageDiagnostics={version=1,trace={},baselineSource=active.damageBaselineSource,
        baselineAge=useIdle and idleAge or 0,
        baselineStatus=useIdle and CF.performanceIdleDamageStatus or status,
        baseline=CF.PerformanceDamageSessionSummary(active.damageStartSessions,
            useIdle and CF.performanceIdleDamageZeroIDs or zeroIDs),
        latestStatus=status,latest=CF.PerformanceDamageSessionSummary(sessions,zeroIDs),
        apiList=C_DamageMeter and type(C_DamageMeter.GetAvailableCombatSessions)=="function" or false,
        apiSession=C_DamageMeter and type(C_DamageMeter.GetCombatSessionFromID)=="function" or false,
        apiSource=C_DamageMeter and type(C_DamageMeter.GetCombatSessionSourceFromID)=="function" or false}
    CF.performanceIdleDamageSessions=nil
    CF.PerformanceDamageTrace(active,"window-open")
    CF.performanceDamageWindow=active
end

function CF.PerformanceFindBestAvailableSession(active)
    if not active then return nil end
    if active.damageWindowClosed then CF.PerformanceDamageTrace(active,"window-closed"); return nil end
    if not active.damageStartSessions then CF.PerformanceDamageTrace(active,"baseline-unavailable"); return nil end
    local sessions,status,zeroIDs=CF.PerformanceListDamageSessions()
    local diagnostic=active.damageDiagnostics or {version=1,trace={}}
    active.damageDiagnostics=diagnostic
    diagnostic.latestStatus=status
    diagnostic.latest=CF.PerformanceDamageSessionSummary(sessions,zeroIDs)
    diagnostic.candidateID=nil; diagnostic.nativeDuration=nil; diagnostic.newCount=nil
    if not sessions then CF.PerformanceDamageTrace(active,status or "list-unavailable"); return nil end
    local candidate,count=nil,0
    for id in pairs(sessions) do
        if not active.damageStartSessions[id] then candidate=id; count=count+1 end
    end
    diagnostic.newCount=count
    if active.damageBoundaryUncertain and active.endedAt then
        CF.PerformanceDamageTrace(active,"overlapping-finalization"); return nil
    end
    if count~=1 then CF.PerformanceDamageTrace(active,count==0 and "no-new-session" or "multiple-new-sessions"); return nil end
    diagnostic.candidateID=candidate
    local data,readStatus=CF.PerformanceReadDamageSessionByID(candidate)
    if not data then CF.PerformanceDamageTrace(active,readStatus or "session-unavailable"); return nil end
    data.durationSeconds=data.durationSeconds or sessions[candidate].durationSeconds
    if not CF.PerformanceDamageDurationMatches(active,data) then
        CF.PerformanceDamageTrace(active,data.durationSeconds and "duration-mismatch" or "duration-unreadable",data)
        -- A native ID first seen outside this recording's time boundary is
        -- never rehabilitated later merely because the durations become equal.
        if data.durationSeconds and data.durationSeconds>
            (active.endedAt or GetTime())-active.startedAt+1 then
            active.damageRejectedSessions=active.damageRejectedSessions or {}
            active.damageRejectedSessions[candidate]=true
        end
        return nil
    end
    if active.damageRejectedSessions and active.damageRejectedSessions[candidate] then
        CF.PerformanceDamageTrace(active,"historical-timing",data); return nil
    end
    if not active.endedAt then
        -- A frozen old session delivered late must not pass one coincidentally
        -- matching duration. Observe it advancing within this active window.
        local evidence=active.damageCandidate
        if not evidence or evidence.id~=candidate then
            active.damageCandidate={id=candidate,at=GetTime(),duration=data.durationSeconds}
            CF.PerformanceDamageTrace(active,"waiting-progress",data)
            return nil
        end
        local dt=GetTime()-evidence.at
        local advance=data.durationSeconds-evidence.duration
        if dt<0.5 or advance<=0 or math.abs(advance-dt)>0.5 then
            CF.PerformanceDamageTrace(active,"progress-not-confirmed",data); return nil
        end
    end
    active.damageSessionID=candidate
    active.damageSessionMatched=true
    active.damageBoundaryUncertain=false
    data.sessionMatched=true
    data.recordingID=active.recordingID
    data.partial=not active.endedAt
    CF.PerformanceDamageTrace(active,"session-bound",data)
    return data
end

function CF.PerformanceCopyDamageData(data, reason)
    if type(data)~="table" then return nil end
    local copy={}
    for k,v in pairs(data) do if k~="spellDamage" then copy[k]=v end end
    copy.spellDamage={}
    for k,v in pairs(data.spellDamage or {}) do copy.spellDamage[k]=v end
    copy.reason=reason or data.reason
    return copy
end

function CF.PerformanceUseCachedDamage(active, fallbackResult, reason)
    local cache=active and active.damageCache
    if cache and cache.sessionMatched and cache.recordingID==active.recordingID
        and (cache.totalDamageKnown or cache.spellBreakdownKnown) then
        local result=CF.PerformanceCopyDamageData(cache,"recording-cache:"..(reason or "partial"))
        result.partial=true
        return result
    end
    return fallbackResult or CF.PerformanceEmptyDamage(reason)
end

function CF.PerformanceGetDamageMeterData(active)
    local result=CF.PerformanceEmptyDamage("session-unmatched")
    if not active then return result end
    local data
    if active.damageSessionMatched and active.damageSessionID then
        local readStatus
        data,readStatus=CF.PerformanceReadDamageSessionByID(active.damageSessionID)
        if active.damageDiagnostics then active.damageDiagnostics.candidateID=active.damageSessionID end
        if not data then CF.PerformanceDamageTrace(active,readStatus or "bound-session-unavailable") end
        if data and not data.durationSeconds then
            local sessions,status,zeroIDs=CF.PerformanceListDamageSessions()
            if active.damageDiagnostics then
                active.damageDiagnostics.latestStatus=status
                active.damageDiagnostics.latest=CF.PerformanceDamageSessionSummary(sessions,zeroIDs)
            end
            data.durationSeconds=sessions and sessions[active.damageSessionID]
                and sessions[active.damageSessionID].durationSeconds
        end
        if data then
            data.sessionMatched=true; data.recordingID=active.recordingID
            data.partial=not active.endedAt
        end
    else data=CF.PerformanceFindBestAvailableSession(active) end
    if data and CF.PerformanceDamageDurationMatches(active,data) then
        if data.totalDamageKnown or data.spellBreakdownKnown then
            CF.PerformanceDamageTrace(active,"matched-readable",data)
            return data
        end
        CF.PerformanceDamageTrace(active,data.sourceFound and "matched-values-unreadable" or "local-source-not-found",data)
        result=data
    elseif data then
        CF.PerformanceDamageTrace(active,data.durationSeconds and "bound-duration-mismatch" or "bound-duration-unreadable",data)
    end
    if active.damageDiagnostics then result.reason=active.damageDiagnostics.reason end
    return CF.PerformanceUseCachedDamage(active,result,"unavailable-or-extended-session")
end

function CF.PerformanceCaptureCurrentDamage(active, force)
    if not active then return false end
    local now=GetTime()
    if not force and now-(active.damageCaptureAt or 0)<0.5 then return active.damageCache~=nil end
    active.damageCaptureAt=now
    local capture=CF.PerformanceGetDamageMeterData(active)
    if capture.sessionMatched and capture.recordingID==active.recordingID
        and (capture.totalDamageKnown or capture.spellBreakdownKnown) then
        active.damageCache=CF.PerformanceCopyDamageData(capture)
        return true
    end
    return false
end

function CF.PerformanceTick(elapsed)
    local active = CF.performanceActive
    if not active or not db or not db.performanceEnabled then
        return
    end

    if active.encounterEnded then
        return
    end

    local now = GetTime()
    elapsed = math.max(0, now - (active.lastObservedAt or active.startedAt))
    active.elapsed = math.max(0, now - active.startedAt)
    active.lastObservedAt = now
    if elapsed <= 0 then return end
    if elapsed > 2 then
        active.observationGapSeconds = (active.observationGapSeconds or 0) + elapsed
        active.detailCoverageIncomplete = true
        CF.PerformanceDetailTick(active, now, 0, {})
        return
    end

    local playerDead = ReadClientBoolean(UnitIsDeadOrGhost, "player")
    if playerDead == nil then
        active.aliveTimeUnknown = true
    elseif playerDead == false then
        active.aliveSeconds = (active.aliveSeconds or 0) + elapsed
    end

    local detailRelevant = {}

    -- Keep a rolling copy of the player's native DamageMeter source while the
    -- fight is still active. This survives builds where the completed Expired
    -- session is delayed or incomplete immediately after combat.
    CF.PerformanceCaptureCurrentDamage(active, false)

    if active.isEncounter then
        for i = 1, 8 do
            local unit = "boss" .. i
            if CF.PerformanceBossUnitRelevant(unit) then
                local targetKey = unit
                detailRelevant[targetKey] = true
                CF.PerformanceDetailObserveTarget(active, targetKey, unit)
                active.targetRelevant[targetKey] =
                    (active.targetRelevant[targetKey] or 0) + elapsed

                for _, effectData in pairs(active.effects or {}) do
                    local state = effectData.targets and effectData.targets[targetKey]
                    if state and tonumber(state.expiresAt) and state.expiresAt > now then
                        effectData.activeSeconds =
                            (effectData.activeSeconds or 0) + elapsed
                        CF.PerformanceDetailCoverage(effectData, targetKey, elapsed)
                    end
                end
            end
        end
    else
        -- Generic multi-target fallback for Trash/open world:
        -- use the same target-second model as boss encounters, but derive the
        -- relevant targets from Cursive's own engaged rows. This avoids the
        -- misleading "the DoT ticks somewhere, therefore 100% uptime" result
        -- in pulls with two or more enemies.
        local seenKeys = {}

        for _, row in ipairs(rows) do
            if row and row.unit then
                local targetKey = nil

                if IsSafeGUIDKey(row.guid) then
                    targetKey = "guid:" .. tostring(row.guid)
                elseif row.unit and not string.match(tostring(row.unit), "^sticky:") then
                    targetKey = CF.GetPerformanceTargetKey(row.unit)
                elseif row.fullName and not row.fullNameIsSecret then
                    targetKey = "name:" .. tostring(row.fullName)
                end

                local unit = targetKey and CF.PerformanceCastUnit({targetKey=targetKey,guid=row.guid,unit=row.unit})
                local observed = unit and CF.PerformanceBossUnitRelevant(unit)
                if targetKey and not observed and not (unit and UnitIsActuallyDead(unit)) then
                    active.detailCoverageIncomplete = true
                    active.unobservedTargets=active.unobservedTargets or {}
                    active.unobservedTargets[targetKey]=true
                elseif targetKey and observed and active.unobservedTargets and active.unobservedTargets[targetKey] then
                    -- The first returning sample establishes visibility now;
                    -- it cannot retrospectively establish the preceding span.
                    active.unobservedTargets[targetKey]=nil
                    observed=false
                end
                if targetKey and observed and not seenKeys[targetKey] then
                    seenKeys[targetKey] = true
                    detailRelevant[targetKey] = true
                    CF.PerformanceDetailObserveTarget(active, targetKey, nil,
                        not row.fullNameIsSecret and row.fullName or nil)
                    active.targetRelevant[targetKey] =
                        (active.targetRelevant[targetKey] or 0) + elapsed

                    for _, effectData in pairs(active.effects or {}) do
                        local state = effectData.targets and effectData.targets[targetKey]
                        if state and tonumber(state.expiresAt) and state.expiresAt > now then
                            effectData.activeSeconds =
                                (effectData.activeSeconds or 0) + elapsed
                            CF.PerformanceDetailCoverage(effectData, targetKey, elapsed)
                        end
                    end
                end
            end
        end

        -- An absent token contributes no target-seconds, coverage or model
        -- ticks. The remembered tracker row remains a presentation feature.
    end
    CF.PerformanceDetailTick(active, now, elapsed, detailRelevant)
end

function CF.BuildStatusReport()
    local lines={CF.TF("STATUS_HEADER",VERSION)}
    if GetBuildInfo then
        local ok,version,build,date=pcall(GetBuildInfo)
        if ok then
            lines[#lines+1]=CF.TF("STATUS_CLIENT",CF.SafeStatusText(version),
                CF.SafeStatusText(build),CF.SafeStatusText(date))
        end
    end
    local fight=CF.performanceActive or CF.performanceLastAuraFight
    local archived=not fight
    if archived then fight=CF.GetPerformanceHistory()[1] end
    if not fight then
        lines[#lines+1]=CF.T("STATUS_EMPTY")
        return table.concat(lines,"\n")
    end
    lines[#lines+1]=CF.TF("STATUS_FIGHT",CF.T(CF.performanceActive and "STATUS_ACTIVE"
        or (archived and "STATUS_ARCHIVED" or "STATUS_LAST")),
        CF.FormatPerformanceDuration(fight.duration or fight.elapsed),fight.addonVersion or CF.T("STATUS_UNKNOWN_VERSION"))
    local diagnostic=fight.damageDiagnostics
    if diagnostic or fight.damageSource then
        lines[#lines+1]=""
        lines[#lines+1]=CF.TF("STATUS_DAMAGE",diagnostic and diagnostic.reason or fight.damageSource,
            tostring(fight.damageSessionID or (diagnostic and diagnostic.candidateID) or "—"))
        if diagnostic then
            lines[#lines+1]=CF.TF("STATUS_DAMAGE_LIST",diagnostic.baselineSource or "—",
                tostring(diagnostic.baseline and diagnostic.baseline.count or "—"),
                tostring(diagnostic.latest and diagnostic.latest.count or "—"),tostring(diagnostic.newCount or "—"))
            local function seconds(value) return value and string.format("%.3f",value) or "—" end
            lines[#lines+1]=CF.TF("STATUS_DAMAGE_DURATION",seconds(diagnostic.expectedDuration),seconds(diagnostic.nativeDuration))
            lines[#lines+1]=CF.TF("STATUS_DAMAGE_API",tostring(diagnostic.apiList),
                tostring(diagnostic.apiSession),tostring(diagnostic.apiSource))
            lines[#lines+1]=CF.TF("STATUS_DAMAGE_LIST_STATE",diagnostic.baselineStatus or "—",diagnostic.latestStatus or "—")
            lines[#lines+1]=CF.T("STATUS_DAMAGE_TRACE")
            for _,entry in ipairs(diagnostic.trace or {}) do
                lines[#lines+1]=string.format("  +%.2f s: %s · ID %s · native %s s",entry.at,entry.reason,
                    tostring(entry.sessionID or "—"),seconds(entry.nativeDuration))
            end
        end
    end
    local found=false
    local entries=archived and (fight.slots or {}) or CF.GetPerformanceProfile()
    for _,entry in ipairs(entries) do
        local data=archived and entry or ((fight.effects or {})[entry.key] or {})
        local d=data.auraDiagnostics
        if d then
            found=true
            local name=archived and entry.name or CF.GetPerformanceEffectDisplay(entry,data.usedSpellID,data.usedName)
            lines[#lines+1]=""
            lines[#lines+1]=CF.TF("STATUS_COUNTS",name or entry.key,d.applied or 0,
                d.not_applied or 0,d.unknown or 0)
            if CF.PerformanceAuraWasRestricted(data) then lines[#lines+1]=CF.T("STATUS_RESTRICTED") end
        end
    end
    if not found then lines[#lines+1]=CF.T("STATUS_EMPTY") end
    if #(fight.pendingCasts or {})>0 then
        lines[#lines+1]=CF.TF("STATUS_PENDING",#fight.pendingCasts)
    end
    lines[#lines+1]=""
    lines[#lines+1]=CF.T("STATUS_NOTE")
    return table.concat(lines,"\n")
end

function CF.PerformanceCountRelevantBossTargets(active)
    local count = 0
    for key, seconds in pairs((active and active.targetRelevant) or {}) do
        if seconds and seconds > 0 then
            count = count + 1
        end
    end
    return count
end

function CF.PerformanceGetRelevantTargetSeconds(active)
    if not active then
        return 0
    end

    local sum = 0
    for _, seconds in pairs(active.targetRelevant or {}) do
        sum = sum + (tonumber(seconds) or 0)
    end

    return sum
end

function CF.PerformanceBuildSnapshot(active, damageData)
    local duration = math.max(0,(active.endedAt or GetTime())-active.startedAt)
    local totalDamage = damageData.totalDamageKnown and damageData.totalDamage or nil
    local relevantSeconds = CF.PerformanceGetRelevantTargetSeconds(active)
    local profile = CF.GetPerformanceProfile()
    local slots = {}

    for slotIndex, effect in ipairs(profile) do
        local effectData = (active.effects and active.effects[effect.key]) or {}
        local damage = damageData.spellBreakdownKnown and (damageData.spellDamage[effect.key] or 0) or nil
        local used = (tonumber(effectData.casts) or 0)>0 or (damage and damage>0)
        if not used and damage~=nil then used=false end
        local uptime = 0

        if relevantSeconds > 0 and not effect.passive then
            uptime = math.min(
                100,
                math.max(
                    0,
                    ((tonumber(effectData.activeSeconds) or 0) / relevantSeconds) * 100
                )
            )
        end

        local displayName, displaySpellID, displayIcon =
            CF.GetPerformanceEffectDisplay(
                effect,
                effectData.usedSpellID,
                effectData.usedName
            )

        -- Native damage without any confirmed application cannot establish
        -- coverage. Keep it unknown without inventing an extra cast or target.
        local coverageUnknown=not effect.passive and
            (active.detailCoverageIncomplete or (damage and damage>0
                and (tonumber(effectData.confirmedApplications) or 0)==0)) or false
        local details=CF.PerformanceDetailBuildSnapshot(active,effectData)
        details.coverageUnknown=coverageUnknown
        details.observationGap=active.detailCoverageIncomplete and true or false
        slots[#slots + 1] = {
            details = details,
            slotIndex = slotIndex,
            key = effect.key,
            name = displayName,
            spellID = displaySpellID,
            icon = displayIcon,
            uptime = uptime,
            damage = damage,
            damageKnown = damage~=nil,
            damagePartial = damageData.partial and true or false,
            damageShare = (damage~=nil and totalDamage~=nil and not damageData.partial)
                and (totalDamage>0 and (damage/totalDamage*100) or 0) or nil,
            casts = tonumber(effectData.casts) or 0,
            refreshes = tonumber(effectData.refreshes) or 0,
            unconfirmed = tonumber(effectData.unconfirmed) or 0,
            notApplied = tonumber(effectData.notApplied) or 0,
            applicationTracking = 3,
            coverageUnknown = coverageUnknown,
            auraDiagnostics = CF.PerformanceCopyApplicationStatus(effectData),
            passive = effect.passive and true or false,
            damageOnly = effect.damageOnly and true or false,
            used = used,
        }
    end

    local endEpoch = active.endedEpoch or (time and time() or 0)
    local name = active.encounterName or active.bossFallbackName

    if not name or name == "" then
        name = CF.T("PERFORMANCE_TRASH")
    end

    local result = "fight"
    if active.encounterSuccess == 1 then
        result = "kill"
    elseif active.encounterSuccess == 0 then
        result = "wipe"
    end

    return {
        version = 2,
        recordingID = active.recordingID,
        startedAt = active.startedAt,
        endedAt = active.endedAt,
        damageSessionID = damageData.sessionID,
        damageSessionMatched = damageData.sessionMatched and true or false,
        damageSource = damageData.reason,
        damageDiagnostics = CF.PerformanceCopyDamageDiagnostics(active.damageDiagnostics),
        totalDamageKnown = damageData.totalDamageKnown and true or false,
        spellBreakdownKnown = damageData.spellBreakdownKnown and true or false,
        damagePartial = damageData.partial and true or false,
        observationGapSeconds = active.observationGapSeconds or 0,
        coverageIncomplete = active.detailCoverageIncomplete and true or false,
        aliveTimeKnown = not active.observationGapSeconds and not active.aliveTimeUnknown,
        addonVersion = VERSION,
        name = name,
        encounterID = active.encounterID,
        result = result,
        duration = duration,
        endEpoch = endEpoch,
        classFile = CF.GetPerformanceClassFile(),
        totalDamage = totalDamage,
        damageMeterAvailable = damageData.available and true or false,
        aliveSeconds = tonumber(active.aliveSeconds) or 0,
        alivePercent = not active.observationGapSeconds and not active.aliveTimeUnknown and duration > 0
            and math.min(100, math.max(0, (active.aliveSeconds / duration) * 100))
            or nil,
        deaths = tonumber(active.deathCount) or 0,
        relevantTargetSeconds = relevantSeconds,
        relevantTargets = CF.PerformanceCountRelevantBossTargets(active),
        bossTargets = CF.PerformanceCountRelevantBossTargets(active), -- legacy field for 1.1.0 history
        slots = slots,
    }
end

function CF.PerformanceStoreSnapshot(snapshot)
    if not snapshot then
        return
    end

    local history = CF.GetPerformanceHistory()
    local insertAt=1
    if snapshot.endEpoch then
        for i,old in ipairs(history) do
            if not old.endEpoch or old.endEpoch<=snapshot.endEpoch then break end
            insertAt=i+1
        end
    end
    table.insert(history, insertAt, snapshot)

    while #history > CF.PERFORMANCE_HISTORY_MAX do
        table.remove(history)
    end

    CF.performanceSelectedIndex = 1

    if CF.performanceFrame and CF.performanceFrame:IsShown() then
        CF.PerformanceRefreshFrame()
    end
end

function CF.PerformanceFinalizeWithDamage(active, attempt)
    if not active or active._snapshotStored then
        return
    end

    attempt = tonumber(attempt) or 1
    local damageData = CF.PerformanceGetDamageMeterData(active)

    -- Retry the recording's own native ID/window for delayed readable data.
    if (not damageData.totalDamageKnown or not damageData.spellBreakdownKnown or damageData.partial)
        and attempt < 5
    then
        C_Timer.After(0.55, function()
            CF.PerformanceFinalizeWithDamage(active, attempt + 1)
        end)
        return
    end

    active._snapshotStored = true
    active.state = "archived"

    local snapshot = CF.PerformanceBuildSnapshot(active, damageData)
    CF.PerformanceStoreSnapshot(snapshot)

end

function CF.PerformanceFinalize()
    local active = CF.performanceActive
    if not active or active.state~="active" then return end
    -- Finish the final observed interval; a long unsampled interval is a gap.
    if not active.encounterEnded then CF.PerformanceTick(0) end
    active.endedAt=GetTime()
    active.endedEpoch=time and time() or 0
    active.elapsed=math.max(0,active.endedAt-active.startedAt)
    CF.PerformanceDetailFinish(active,active.endedAt)
    CF.PerformanceCaptureCurrentDamage(active,true)
    active.state="waiting"
    CF.performanceActive=nil
    CF.performanceOpeningCasts={}
    CF.performanceLastAuraFight=active
    if not db or not db.performanceEnabled or active.elapsed<(tonumber(db.performanceMinSeconds) or 45) then
        active.state="discarded"
        return
    end
    C_Timer.After(0.65,function() CF.PerformanceFinalizeWithDamage(active,1) end)
end

function CF.FormatPerformanceDuration(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%02d", minutes, secs)
end

function CF.FormatPerformanceNumber(value)
    value = tonumber(value) or 0

    if value >= 1000000000 then
        return string.format("%.2f B", value / 1000000000)
    elseif value >= 1000000 then
        return string.format("%.2f M", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1f K", value / 1000)
    end

    return tostring(math.floor(value + 0.5))
end

function CF.GetPerformanceMonthName(month)
    local de = {"Jan","Feb","Mär","Apr","Mai","Jun","Jul","Aug","Sep","Okt","Nov","Dez"}
    local en = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
    local list = CF.GetEffectiveLanguage() == "de" and de or en
    return list[month] or "?"
end

function CF.GetEnglishOrdinal(day)
    day = tonumber(day) or 0
    local mod100 = day % 100
    if mod100 >= 11 and mod100 <= 13 then
        return tostring(day) .. "th"
    end

    local mod10 = day % 10
    if mod10 == 1 then
        return tostring(day) .. "st"
    elseif mod10 == 2 then
        return tostring(day) .. "nd"
    elseif mod10 == 3 then
        return tostring(day) .. "rd"
    end

    return tostring(day) .. "th"
end

function CF.FormatPerformanceDate(epoch)
    local info = date("*t", tonumber(epoch) or 0)
    if not info then
        return "?"
    end

    if CF.GetEffectiveLanguage() == "de" then
        return tostring(info.day) .. ". " .. CF.GetPerformanceMonthName(info.month)
    end

    return CF.GetEnglishOrdinal(info.day) .. " " .. CF.GetPerformanceMonthName(info.month)
end

function CF.FormatPerformanceEndTime(epoch)
    return date("%H:%M", tonumber(epoch) or 0)
end

function CF.PerformanceDeleteHistoryIndex(index)
    local history = CF.GetPerformanceHistory()
    if type(index) ~= "number" or index < 1 or index > #history then
        return
    end

    table.remove(history, index)

    if index < CF.performanceSelectedIndex then
        CF.performanceSelectedIndex = CF.performanceSelectedIndex - 1
    elseif index == CF.performanceSelectedIndex then
        CF.performanceSelectedIndex = math.min(index, #history)
    end

    if CF.performanceSelectedIndex > #history then
        CF.performanceSelectedIndex = math.max(1, #history)
    elseif CF.performanceSelectedIndex < 1 then
        CF.performanceSelectedIndex = 1
    end

    if CF.performanceFrame and CF.performanceFrame:IsShown() then
        CF.PerformanceRefreshFrame()
    end
end

function CF.PerformanceClearHistory()
    local history = CF.GetPerformanceHistory()
    for i = #history, 1, -1 do
        table.remove(history, i)
    end

    CF.performanceSelectedIndex = 1

    if CF.performanceFrame and CF.performanceFrame:IsShown() then
        CF.PerformanceRefreshFrame()
    end
end

function CF.GetPriorityMarkerName(index)
    local keys = {
        "MARKER_STAR",
        "MARKER_CIRCLE",
        "MARKER_DIAMOND",
        "MARKER_TRIANGLE",
        "MARKER_MOON",
        "MARKER_SQUARE",
        "MARKER_CROSS",
        "MARKER_SKULL",
    }

    index = math.max(1, math.min(8, tonumber(index) or 8))
    return CF.T(keys[index])
end

function CF.CyclePriorityRaidMarker()
    local current = tonumber(db and db.priorityRaidMarker) or 8
    current = current + 1
    if current > 8 then
        current = 1
    end
    db.priorityRaidMarker = current
end

local function FindRaidCurseAura(unit, curse)
    if not unit or not curse or not C_UnitAuras then return nil,nil,"unavailable" end
    local state="unknown"
    local function Read(fn,...)
        if not fn then return nil end
        local ok,aura=pcall(fn,...)
        if not ok then
            if CF.PerformanceIsAuraAccessError(aura) then state="restricted"
            elseif state~="restricted" then state="unavailable" end
            return nil
        end
        if not RaidCurseReadable(aura) then state="restricted"; return nil end
        if aura==nil then return nil end
        if type(aura)~="table" then return nil end
        -- Only return an aura whose identity fields are readable. A protected
        -- table is not evidence of either presence or absence.
        local id=CF.PerformanceReadableField(aura,"spellId")
        local name=CF.PerformanceReadableField(aura,"name")
        if not RaidCurseReadable(id) then id=nil end
        if not RaidCurseReadable(name) then name=nil end
        if type(id)~="number" and type(name)~="string" then state="restricted"; return nil end
        return aura,id,name
    end
    local learnedID=db and db.raidCurseLearnedIDs and db.raidCurseLearnedIDs[curse.key]
    if not RaidCurseReadable(learnedID) or type(learnedID)~="number" then learnedID=nil end
    local ok,wantedName=pcall(function() return GetSpellDisplayInfo(curse) end)
    if not ok or not RaidCurseReadable(wantedName) or type(wantedName)~="string" then wantedName=nil end
    local function Matches(id,name)
        if type(id)=="number" then
            local family=CF.GetRaidCurseCastFamily(id)
            if family then return family==curse.key end
            if id==learnedID then return true end
        end
        return type(name)=="string" and (name==wantedName or name==curse.fallback or name==curse.english)
    end
    if learnedID then
        local aura,id,name=Read(C_UnitAuras.GetUnitAuraBySpellID,unit,learnedID)
        if aura and Matches(id,name) then return aura,id,"present-learned" end
    end
    if wantedName then
        local aura,id,name=Read(C_UnitAuras.GetAuraDataBySpellName,unit,wantedName,"HARMFUL")
        if aura and Matches(id,name) then return aura,id,"present-name" end
    end
    if C_UnitAuras.GetDebuffDataByIndex then
        for i=1,80 do
            local aura,id,name=Read(C_UnitAuras.GetDebuffDataByIndex,unit,i,"HARMFUL")
            if not aura then break end
            if Matches(id,name) then return aura,id,"present-scan" end
        end
    end
    for _,knownID in ipairs(curse.ids) do
        local aura,id,name=Read(C_UnitAuras.GetUnitAuraBySpellID,unit,knownID)
        if aura and Matches(id,name) then return aura,id,"present-id" end
    end
    -- Empty name/ID/index results are not a build-verified absence proof.
    return nil,nil,state
end

local function GetAuraRemainingSeconds(unit, aura)
    if not unit or not aura then
        return nil
    end

    -- Preferred 12.x path: auraInstanceID itself is usable for the native
    -- DurationObject API, so we do not need to inspect secret expirationTime.
    if C_UnitAuras
        and C_UnitAuras.GetAuraDuration
    then
        local auraInstanceID = nil

        pcall(function()
            if not IsSecretValue(aura.auraInstanceID)
                and aura.auraInstanceID ~= nil
            then
                auraInstanceID = aura.auraInstanceID
            end
        end)

        if auraInstanceID then
            local okDuration, duration = pcall(
                C_UnitAuras.GetAuraDuration,
                unit,
                auraInstanceID
            )

            if okDuration and not IsSecretValue(duration) and duration and duration.GetRemainingDuration then
                local okRemaining, remaining = pcall(
                    duration.GetRemainingDuration,
                    duration
                )

                if okRemaining and not IsSecretValue(remaining) and type(remaining) == "number" then
                    return math.max(0, remaining)
                end
            end
        end
    end

    -- Compatibility fallback for unrestricted aura data.
    local ok, remaining = pcall(function()
        if not IsSecretValue(aura.expirationTime) and type(aura.expirationTime)=="number" then
            return aura.expirationTime - GetTime()
        end
    end)

    if ok and type(remaining) == "number" then
        return math.max(0, remaining)
    end

    return nil
end

local function GetActiveCurseWatchUnits()
    local units = {}

    if curseTestMode then
        if UnitExistsReadable("target")
            and IsHostile("target")
            and not UnitIsActuallyDead("target")
        then
            units[#units + 1] = "target"
        end
        return units
    end

    if not db
        or not db.raidCurseWatcherEnabled
        or db.raidCurseKey == "none"
        or not InRaid()
        or not PlayerInCombat()
    then
        return units
    end

    for i = 1, 8 do
        local unit = "boss" .. i
        if UnitExistsReadable(unit)
            and IsHostile(unit)
            and not UnitIsActuallyDead(unit)
        then
            units[#units + 1] = unit
        end
    end

    return units
end

local function HideRaidCurseAlert()
    if curseAlertFrame then
        curseAlertFrame:Hide()
    end
end

local function SetRaidCurseAlert(state, curse, bossName, remaining)
    if not curseAlertFrame then
        return
    end

    local name, icon = GetSpellDisplayInfo(curse)

    curseAlertFrame.icon:SetTexture(
        icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    )

    if state == "missing" or state == "unconfirmed" or state == "expired" then
        curseAlertFrame:SetBackdropColor(0.34, 0.015, 0.025, 0.98)
        curseAlertFrame:SetBackdropBorderColor(1.00, 0.16, 0.16, 1.00)
        curseAlertFrame.title:SetText("|cffff3b3b" .. CF.T(state=="expired" and "CURSE_EXPIRED"
            or (state=="missing" and "CURSE_MISSING" or "CURSE_UNCONFIRMED")) .. "|r")
        curseAlertFrame.detail:SetText(
            (name or CF.GetCurseFallback(curse)) .. CF.T("ON_TARGET") .. tostring(bossName)
        )
    elseif state == "expiring" then
        curseAlertFrame:SetBackdropColor(0.30, 0.13, 0.015, 0.98)
        curseAlertFrame:SetBackdropBorderColor(1.00, 0.64, 0.08, 1.00)
        curseAlertFrame.title:SetText("|cffffb020" .. CF.T("CURSE_RENEW") .. "|r")

        local remainingText
        if remaining and remaining < 5 then
            remainingText = string.format("%.1f s", remaining)
        elseif remaining then
            remainingText = string.format("%.0f s", remaining)
        else
            remainingText = CF.T("SOON")
        end

        curseAlertFrame.detail:SetText(
            (name or CF.GetCurseFallback(curse))
            .. CF.T("ON_TARGET") .. tostring(bossName)
            .. " · " .. remainingText
        )
    end

    curseAlertFrame:Show()
end

local function UpdateRaidCurseWatcher()
    if not db or not main or not curseAlertFrame then
        return
    end

    if not curseTestMode then
        if not db.raidCurseWatcherEnabled
            or db.raidCurseKey == "none"
        then
            curseAlertFrame:Hide()
            return
        end
    end

    local curse = GetRaidCurseDef(db.raidCurseKey)
    if not curse then
        curseAlertFrame:Hide()
        return
    end

    local units = GetActiveCurseWatchUnits()
    if #units == 0 then
        curseAlertFrame:Hide()
        return
    end

    local warnSeconds = tonumber(db.raidCurseWarnSeconds) or 5
    local expiringUnit = nil
    local expiringRemaining = nil

    for _, unit in ipairs(units) do
        local bossName = SafeUnitName(unit, unit)
        local castRemaining, castState =
            CF.GetRaidCurseCastRemaining(unit, curse.key)

        if castState == "present-cast" then
            if castRemaining <= warnSeconds
                and (not expiringRemaining or castRemaining < expiringRemaining)
            then
                expiringUnit = unit
                expiringRemaining = castRemaining
            end
        else
            -- Compatibility fallback: some auras may be explicitly non-secret.
            local aura, spellID, state = FindRaidCurseAura(unit, curse)

            if not aura then
                SetRaidCurseAlert(castState=="expired" and "expired"
                    or (state=="missing" and "missing" or "unconfirmed"),curse,bossName)
                return
            end

            if aura then
                local remaining = GetAuraRemainingSeconds(unit, aura)

                if remaining
                    and remaining <= warnSeconds
                    and (not expiringRemaining or remaining < expiringRemaining)
                then
                    expiringUnit = unit
                    expiringRemaining = remaining
                end
            end
        end
    end

    if expiringUnit then
        SetRaidCurseAlert(
            "expiring",
            curse,
            SafeUnitName(expiringUnit, expiringUnit),
            expiringRemaining
        )
        return
    end

    HideRaidCurseAlert()
end

local function ToggleRaidCurseTest()
    if curseTestMode then
        curseTestMode=false
        Print(CF.T("TEST_ENDED"))
    else
        if not UnitExistsReadable("target") or not IsHostile("target") then
            Print(CF.T("TEST_SELECT_HOSTILE"))
            return
        end
        if db.raidCurseKey=="none" then
            Print(CF.T("TEST_ASSIGN_CURSE"))
            return
        end
        curseTestMode=true
        Print(CF.T("TEST_ACTIVE"))
    end
    if curseWatcherOptionsFrame and curseWatcherOptionsFrame.testButton then
        curseWatcherOptionsFrame.testButton.cfLabel:SetText(CF.T(curseTestMode and "TEST_END" or "TEST_CURRENT"))
    end
    UpdateRaidCurseWatcher()
end

local function CreateRaidCurseAlert()
    if curseAlertFrame or not main then
        return
    end

    curseAlertFrame = CreateFrame(
        "Frame",
        "CursiveForeverRaidCurseAlert",
        main,
        "BackdropTemplate"
    )
    curseAlertFrame:SetHeight(46)
    curseAlertFrame:SetPoint("BOTTOMLEFT", main, "TOPLEFT", 0, 4)
    curseAlertFrame:SetPoint("BOTTOMRIGHT", main, "TOPRIGHT", 0, 4)
    curseAlertFrame:SetFrameLevel(main:GetFrameLevel() + 20)
    curseAlertFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    curseAlertFrame:Hide()

    local icon = curseAlertFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", 5, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    curseAlertFrame.icon = icon

    local title = curseAlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
    title:SetPoint("TOPRIGHT", curseAlertFrame, "TOPRIGHT", -6, -4)
    title:SetJustifyH("LEFT")
    curseAlertFrame.title = title

    local detail = curseAlertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 5)
    detail:SetPoint("BOTTOMRIGHT", curseAlertFrame, "BOTTOMRIGHT", -6, 5)
    detail:SetJustifyH("LEFT")
    curseAlertFrame.detail = detail
end

local function CountActiveRows()
    local n = 0
    for i = 1, MAX_ROWS do
        if rows[i] and rows[i].unit then
            n = n + 1
        end
    end
    return n
end

function CF.CacheRaidMarkerForUnit(unit, index, row)
    if IsSecretValue(index) then
        return
    end

    local numericIndex = tonumber(index)
    if numericIndex and (numericIndex < 1 or numericIndex > 8) then
        numericIndex = nil
    end

    local guid = nil

    if unit and UnitExistsReadable(unit) then
        local unitGUID = SafeUnitGUID(unit)
        if IsSafeGUIDKey(unitGUID) then
            guid = unitGUID
        end
    end

    if not guid and row and IsSafeGUIDKey(row.guid) then
        guid = row.guid
    end

    if not guid then
        return
    end

    if numericIndex then
        CF.raidMarkerGUIDCache[guid] = numericIndex
        CF.raidMarkerCacheSeen[guid] = GetTime()
    else
        CF.raidMarkerGUIDCache[guid] = nil
        CF.raidMarkerCacheSeen[guid] = nil
    end
end

function CF.GetCachedRaidMarkerForRow(row, unit)
    local guid = nil

    if unit and UnitExistsReadable(unit) then
        local unitGUID = SafeUnitGUID(unit)
        if IsSafeGUIDKey(unitGUID) then
            guid = unitGUID
        end
    end

    if not guid and row and IsSafeGUIDKey(row.guid) then
        guid = row.guid
    end

    if guid then
        local cached = tonumber(CF.raidMarkerGUIDCache[guid])
        if cached and cached >= 1 and cached <= 8 then
            return cached
        end
    end

    return nil
end

function CF.UpdateRowRaidMarker(row, unit)
    if not row or not row.raidMarker then
        return
    end

    local queryUnit = unit
    -- A recycled nameplate token cannot provide this remembered enemy's mark.
    -- Keep raid-marker identity checks consistent with aura/health ownership.
    if queryUnit and IsSafeGUIDKey(row.guid) and UnitExistsReadable(queryUnit)
        and SafeUnitGUID(queryUnit) ~= row.guid then
        queryUnit = nil
    end
    if (not queryUnit or not UnitExistsReadable(queryUnit))
        and row.lastNameplateUnit
        and UnitExistsReadable(row.lastNameplateUnit)
        and IsSafeGUIDKey(row.guid)
        and SafeUnitGUID(row.lastNameplateUnit) == row.guid
    then
        queryUnit = row.lastNameplateUnit
    end

    if not queryUnit or not UnitExistsReadable(queryUnit) or not GetRaidTargetIndex then
        row.raidMarkerIndex = nil
        row.isPriorityMarker = false
        row.raidMarker:Hide()
        return
    end

    local ok, index = pcall(GetRaidTargetIndex, queryUnit)
    if not ok or (not IsSecretValue(index) and index == nil) then
        if ok then
            CF.CacheRaidMarkerForUnit(queryUnit, nil, row)
        end
        row.raidMarkerIndex = nil
        row.isPriorityMarker = false
        row.raidMarker:Hide()
        return
    end

    if IsSecretValue(index) then
        CF.performanceMarkerWasSecret = true

        -- Forever may protect the numeric raid-marker index in combat while
        -- still allowing FrameXML to render the icon. Preserve priority
        -- sorting from a previously readable/self-set marker via stable GUID.
        local cachedIndex = CF.GetCachedRaidMarkerForRow(row, queryUnit)
        row.raidMarkerIndex = cachedIndex
        row.isPriorityMarker =
            cachedIndex ~= nil
            and cachedIndex == (tonumber(db and db.priorityRaidMarker) or 8)

        -- FrameXML may still be able to render the protected value without Lua
        -- inspecting it. If not, simply hide the icon rather than erroring.
        local rendered = false
        if SetRaidTargetIconTexture then
            row.raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            local okRender = pcall(SetRaidTargetIconTexture, row.raidMarker, index)
            rendered = okRender and true or false
        end

        if rendered then
            row.raidMarker:Show()
        else
            row.raidMarker:Hide()
        end
        return
    end

    index = tonumber(index)
    if not index or index < 1 or index > 8 then
        row.raidMarkerIndex = nil
        row.isPriorityMarker = false
        row.raidMarker:Hide()
        return
    end

    row.raidMarkerIndex = index
    row.isPriorityMarker = index == (tonumber(db and db.priorityRaidMarker) or 8)
    CF.CacheRaidMarkerForUnit(queryUnit, index, row)

    -- Always use Blizzard's own renderer. Modern FrameXML stores the raid
    -- target icons in a shared texture/atlas; fabricating paths such as
    -- UI-RaidTargetingIcon_4 can yield an empty or clipped texture.
    local rendered = false

    if SetRaidTargetIconTexture then
        row.raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        local okRender = pcall(
            SetRaidTargetIconTexture,
            row.raidMarker,
            index
        )
        rendered = okRender and true or false
    end

    if rendered then
        row.raidMarker:Show()
    else
        row.raidMarker:Hide()
    end
end

local function UpdateTargetHighlight()
    for i = 1, MAX_ROWS do
        local row = rows[i]

        if row and row.unit then
            local selected = false

            if IsSafeGUIDKey(row.guid) and UnitExistsReadable("target") then
                local targetGUID = SafeUnitGUID("target")
                selected = IsSafeGUIDKey(targetGUID) and targetGUID == row.guid
            end

            if not selected and row.unit and not string.match(row.unit, "^sticky:") then
                selected = IsCurrentTarget(row.unit)
            end

            row.cfTargetSelected = selected
            if selected then
                row.targetBorder:Show()

                if GetTargetDisplayMode() == "standard" and not (CF.IsHealthbarView and CF.IsHealthbarView()) then
                    row.targetLabel:Show()
                else
                    row.targetLabel:Hide()
                end

                if row.portraitRing then
                    row.portraitRing:SetColorTexture(THEME_ACTIVE_R, THEME_ACTIVE_G, THEME_ACTIVE_B, 1)
                end

                row.bg:SetColorTexture(0.095, 0.073, 0.040, 0.97)
            else
                row.targetBorder:Hide()
                row.targetLabel:Hide()
                if row.portraitRing then
                    row.portraitRing:SetColorTexture(THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 0.92)
                end

                if i % 2 == 0 then
                    row.bg:SetColorTexture(THEME_BG_ALT1_R, THEME_BG_ALT1_G, THEME_BG_ALT1_B, 0.94)
                else
                    row.bg:SetColorTexture(THEME_BG_ALT2_R, THEME_BG_ALT2_G, THEME_BG_ALT2_B, 0.94)
                end
            end
        elseif row then
            row.cfTargetSelected = nil
            row.targetBorder:Hide()
            row.targetLabel:Hide()
        end
        if CF.ApplyTrackerRowAppearance then CF.ApplyTrackerRowAppearance(row) end
    end
end

function CF.ApplyTrackerFrameAppearance()
    if not main then return end
    local hidden=CF.IsTrackerFrameHidden and CF.IsTrackerFrameHidden()
    if hidden then main:SetBackdrop(nil) else ApplyDarkBackdrop(main,0.97) end
    for _,art in ipairs(main.cfFrameArt or {}) do art:SetShown(not hidden) end
    for _,row in ipairs(rows) do
        if CF.ApplyTrackerRowAppearance then CF.ApplyTrackerRowAppearance(row) end
    end
end

function CF.GetMainHeaderHeight()
    if CF.ClickCasting and CF.ClickCasting.active then return CF.ClickCasting.headerHeight end
    if db and db.showHeader == false and not (main and main.cfNameplateWarningActive) then return 0 end
    return TITLE_H
end

local function LayoutRows()
    if not main then return end
    if CF.matrixFallbackRefreshPending or CF.barsFallbackRefreshPending then
        CF.matrixFallbackRefreshPending = nil
        CF.barsFallbackRefreshPending = nil
        CF.ApplyAuraLayoutToAllRows()
        return
    end
    if CF.ApplyPendingTrackerView and CF.ApplyPendingTrackerView() then
        CF.ApplyAuraLayoutToAllRows()
        return
    end
    if CF.ApplyPendingAuraOrderMode and CF.ApplyPendingAuraOrderMode() then
        CF.ApplyAuraLayoutToAllRows()
        return
    end

    if CF.ApplyPendingTrackerExtras and CF.ApplyPendingTrackerExtras() then
        CF.ApplyAuraLayoutToAllRows()
        return
    end
    local frameless=CF.IsTrackerFrameHidden and CF.IsTrackerFrameHidden()
    local headerHeight = CF.GetMainHeaderHeight()
    if main.titlebar then
        if headerHeight > 0 then main.titlebar:Show() else main.titlebar:Hide() end
    end
    local rowWidth = GetCurrentRowWidth()-(frameless and 12 or 0)
    local rowHeight = CF.GetAuraLayoutRowHeight and CF.GetAuraLayoutRowHeight() or ROW_H
    local matrixHeaderHeight = CF.GetMatrixHeaderHeight and CF.GetMatrixHeaderHeight() or 0
    local activeRows = {}

    for i = 1, MAX_ROWS do
        local row = rows[i]
        if row and row.unit then
            CF.UpdateRowRaidMarker(row, row.unit)
            if CF.ClickCasting and CF.ClickCasting.Represents(row) then row:Hide()
            else activeRows[#activeRows + 1] = row end
        elseif row then
            row:Hide()
        end
    end

    table.sort(activeRows, function(a, b)
        local ap = a.isPriorityMarker and 1 or 0
        local bp = b.isPriorityMarker and 1 or 0

        if ap ~= bp then
            return ap > bp
        end

        return (a._index or 0) < (b._index or 0)
    end)

    local roleCount = CF.ClickCasting and CF.ClickCasting.VisibleCount() or 0
    -- Preserve the two-column display limit without deleting tracked enemies.
    while #activeRows > MAX_ROWS-roleCount do table.remove(activeRows):Hide() end
    for index, row in ipairs(activeRows) do
        local visibleIndex = index + roleCount
        local column = math.floor((visibleIndex - 1) / ROWS_PER_COLUMN)
        local rowInColumn = (visibleIndex - 1) % ROWS_PER_COLUMN

        row:ClearAllPoints()
        row:SetPoint(
            "TOPLEFT",
            main,
            "TOPLEFT",
            (frameless and 0 or 6) + (column * rowWidth),
            -(headerHeight + matrixHeaderHeight + (frameless and 0 or 4) + (rowInColumn * rowHeight))
        )
        row:Show()
    end

    local visibleIndex = #activeRows + roleCount
    local columns = math.max(1, math.ceil(visibleIndex / ROWS_PER_COLUMN))
    local rowsHigh = math.min(visibleIndex, ROWS_PER_COLUMN)

    -- The nameplate warning shares the header with the short Cursive title.
    -- Keep this exceptional hint readable even when the row layout is narrow.
    main:SetWidth(math.max(columns * rowWidth, main.cfNameplateWarningActive and 340 or 0))

    if visibleIndex == 0 then
        main:SetHeight(headerHeight + MIN_BODY_H)
    else
        main:SetHeight(headerHeight + matrixHeaderHeight + (rowsHigh * rowHeight) + (frameless and 0 or 7))
    end

    if CF.LayoutMatrixHeaders then CF.LayoutMatrixHeaders(main,columns,rowWidth,headerHeight,visibleIndex) end

    UpdateTargetHighlight()
    CF.ApplyTrackerFrameAppearance()
    if CF.ClickCasting then CF.ClickCasting.RefreshVisuals() end
end
CF.RelayoutTrackerFrame=LayoutRows

local function CreateCursiveSecondsFormatter()
    if not C_StringUtil or not C_StringUtil.CreateSecondsFormatter then return nil end
    local f = C_StringUtil.CreateSecondsFormatter()
    if f.SetDefaultAbbreviation and Enum and Enum.SecondsFormatterAbbreviation then
        f:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
    end
    if f.SetStripIntervalWhitespace and Enum and Enum.SecondsFormatterIntervalWhitespace then
        f:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.Strip)
    end
    if f.SetMillisecondsThreshold then f:SetMillisecondsThreshold(5) end
    if f.SetDesiredUnitCount then f:SetDesiredUnitCount(1) end
    if f.SetRounding and Enum and Enum.SecondsFormatterRounding then
        f:SetRounding(Enum.SecondsFormatterRounding.RoundUp)
    end
    return f
end

local function InitAuraButton(auraButton, size, timeStyle)
    if timeStyle and timeStyle.bars and CF.InitBarsAuraButton then
        return CF.InitBarsAuraButton(auraButton, DURATION_FORMATTER)
    end
    if timeStyle and timeStyle.matrix and CF.InitMatrixAuraButton then
        return CF.InitMatrixAuraButton(auraButton, DURATION_FORMATTER)
    end
    if timeStyle and timeStyle.matrixExtra and CF.InitMatrixExtraAuraButton then
        return CF.InitMatrixExtraAuraButton(auraButton, DURATION_FORMATTER)
    end
    size = type(size) == "number" and size or 34
    local timeGap = timeStyle and timeStyle.gap or 2
    local timeHeight = timeStyle and timeStyle.height or (size < 30 and 10 or 14)
    auraButton:SetSize(size, size)

    -- Kräftiges Grundicon ohne dauerhaften Grauschleier.
    local icon = auraButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(auraButton)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetVertexColor(1, 1, 1, 1)
    auraButton:SetIcon(icon)

    -- Variante A, korrigiert:
    -- Das Grundicon bleibt klar.
    -- Darüber liegt ein grauer "Ablauf"-Schleier, der mit ablaufender Zeit
    -- VON OBEN NACH UNTEN wächst.
    local veil = CreateFrame("StatusBar", nil, auraButton)
    veil:SetAllPoints(auraButton)
    veil:SetOrientation("VERTICAL")
    if veil.SetReverseFill then
        veil:SetReverseFill(true)
    end
    veil:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")

    local vt = veil:GetStatusBarTexture()
    if vt then
        vt:SetColorTexture(0.25, 0.25, 0.28, CF.GetAppliedAuraVeilOpacity and CF.GetAppliedAuraVeilOpacity() or 0.58)
        if vt.SetBlendMode then
            vt:SetBlendMode("BLEND")
        end
    end

    local barOptions = {}
    if Enum and Enum.StatusBarTimerDirection then
        -- elapsed time = grauer Schleier wächst mit verstrichener Zeit
        if Enum.StatusBarTimerDirection.ElapsedTime then
            barOptions.direction = Enum.StatusBarTimerDirection.ElapsedTime
        else
            -- Fallback if beta enum differs
            barOptions.direction = Enum.StatusBarTimerDirection.RemainingTime
        end
    end
    if Enum and Enum.StatusBarInterpolation then
        barOptions.interpolation = Enum.StatusBarInterpolation.Immediate
    end

    local ok = pcall(function()
        auraButton:SetDurationBar(veil, barOptions)
    end)
    if not ok then
        veil:Hide()
    end

    local shade = auraButton:CreateTexture(nil, "OVERLAY")
    shade:SetPoint("TOPLEFT", auraButton, "BOTTOMLEFT", 0, -timeGap)
    shade:SetPoint("TOPRIGHT", auraButton, "BOTTOMRIGHT", 0, -timeGap)
    shade:SetHeight(timeHeight)
    shade:SetColorTexture(0, 0, 0, 0.70)

    local duration = auraButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if size < 30 then duration:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", timeStyle and timeStyle.fontSize or 9, "OUTLINE") end
    duration:SetPoint("TOP", auraButton, "BOTTOM", 0, -timeGap)
    duration:SetJustifyH("CENTER")
    duration:SetTextColor(1.0, 0.90, 0.36, 1)

    if DURATION_FORMATTER then
        auraButton:SetDurationText(duration, (CF.Client and CF.Client.DurationTextOptions
            and CF.Client.DurationTextOptions(DURATION_FORMATTER)) or { textFormatter = DURATION_FORMATTER })
    else
        auraButton:SetDurationText(duration)
    end
end
CF.InitAuraButton = InitAuraButton

local ApplyTargetDisplayLayoutToRow
local ApplyTargetDisplayMode

local function SetRowHealthColor(row, r, g, b)
    row.healthPct:SetTextColor(r, g, b, 1)
    if row.healthBar then
        pcall(row.healthBar.SetStatusBarColor, row.healthBar, r, g, b, 1)
    end
end

local function ApplyRowHealthDisplay(row)
    if not row.healthPct then return false end
    -- Bars includes its HP percentage inside a health bar. A saved percentage
    -- preference belongs to Standard/Matrix and must not hide that bar.
    local useBar = row.healthBar ~= nil and ((CF.IsBarsView and CF.IsBarsView())
        or (CF.IsHealthbarView and CF.IsHealthbarView())
        or CF.GetHealthDisplayMode() == "bar")
    if row.healthBar then row.healthBar:Hide() end
    row.healthPct:Show()

    -- Secret values go straight to native widgets, without Lua arithmetic.
    -- Native health/max-health keeps bar fill independent of percentage curves.
    if useBar and row.healthBarValueAvailable then
        local okRange = pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, row.healthBarMaximum)
        local okValue = okRange and pcall(row.healthBar.SetValue, row.healthBar, row.healthBarValue)
        if okValue then
            row.healthBar:Show()
            row.healthPct:Hide()
            if CF.LayoutBarsHealth then CF.LayoutBarsHealth(row,true) end
            if CF.LayoutMatrixHealth then CF.LayoutMatrixHealth(row,true) end
            if CF.LayoutHealthbarHealth then CF.LayoutHealthbarHealth(row,true) end
            return true
        end
    elseif not useBar and row.healthValueAvailable
        and pcall(row.healthPct.SetFormattedText, row.healthPct, "%.0f%%", row.healthValue) then
        if CF.LayoutBarsHealth then CF.LayoutBarsHealth(row,false) end
        if CF.LayoutMatrixHealth then CF.LayoutMatrixHealth(row,false) end
        if CF.LayoutHealthbarHealth then CF.LayoutHealthbarHealth(row,false) end
        return true
    end

    -- Never leave a previous enemy's fill visible when data/rendering is unavailable.
    if row.healthBar then pcall(row.healthBar.SetValue, row.healthBar, 0) end
    row.healthPct:SetText(row.healthDisplayEmpty and "" or (useBar and "?" or "?%"))
    SetRowHealthColor(row, 0.85, 0.85, 0.85)
    if CF.LayoutBarsHealth then CF.LayoutBarsHealth(row,false) end
    if CF.LayoutMatrixHealth then CF.LayoutMatrixHealth(row,false) end
    if CF.LayoutHealthbarHealth then CF.LayoutHealthbarHealth(row,false) end
    return false
end

-- Presentation fallbacks reuse the same health renderer as ordinary updates.
CF.RefreshRowHealthDisplay = ApplyRowHealthDisplay

function CF.SetHealthDisplayMode(mode)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not db then return end
    db.healthDisplayMode = mode == "percent" and "percent" or "bar"
    for _, row in ipairs(rows) do
        ApplyRowHealthDisplay(row)
    end
end

local function CreateRow(index, parent, role)
    local row = CreateFrame("Frame", nil, parent or main)
    row.cfClickRole = role
    row:SetSize(GetCurrentRowWidth() - 12, ROW_H - 2)
    row._index = index
    row:Hide()

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    row.bg = bg

    if index % 2 == 0 then
        bg:SetColorTexture(THEME_BG_ALT1_R, THEME_BG_ALT1_G, THEME_BG_ALT1_B, 0.94)
    else
        bg:SetColorTexture(THEME_BG_ALT2_R, THEME_BG_ALT2_G, THEME_BG_ALT2_B, 0.94)
    end

    local raidMarker = row:CreateTexture(nil, "OVERLAY", nil, 7)
    raidMarker:SetSize(20, 20)
    raidMarker:SetPoint("LEFT", row, "LEFT", 12, 0)
    raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raidMarker:SetTexCoord(0, 0.25, 0, 0.25)
    raidMarker:Hide()
    row.raidMarker = raidMarker
    row.raidMarkerIndex = nil
    row.isPriorityMarker = false

    local border = CreateFrame("Frame", nil, row)
    border:SetAllPoints(row)
    border:SetFrameLevel(row:GetFrameLevel() + 3)

    local top = border:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(2)
    top:SetColorTexture(THEME_GOLD_HI_R, THEME_GOLD_HI_G, THEME_GOLD_HI_B, 0.92)

    local bottom = border:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(2)
    bottom:SetColorTexture(THEME_GOLD_HI_R, THEME_GOLD_HI_G, THEME_GOLD_HI_B, 0.92)

    local left = border:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(2)
    left:SetColorTexture(THEME_GOLD_HI_R, THEME_GOLD_HI_G, THEME_GOLD_HI_B, 0.92)

    local right = border:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(2)
    right:SetColorTexture(THEME_GOLD_HI_R, THEME_GOLD_HI_G, THEME_GOLD_HI_B, 0.92)

    border:Hide()
    row.targetBorder = border

    -- Compact/minimal portrait. Hidden in standard mode.
    local portraitRing = row:CreateTexture(nil, "ARTWORK")
    portraitRing:SetSize(38, 38)
    portraitRing:SetPoint("LEFT", row, "LEFT", 13, 0)
    portraitRing:SetColorTexture(THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 0.92)
    row.portraitRing = portraitRing

    local portraitRingMask = row:CreateMaskTexture(nil, "ARTWORK")
    portraitRingMask:SetAllPoints(portraitRing)
    portraitRingMask:SetTexture(
        "Interface/CHARACTERFRAME/TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )
    portraitRing:AddMaskTexture(portraitRingMask)

    local portrait = row:CreateTexture(nil, "OVERLAY")
    portrait:SetSize(34, 34)
    portrait:SetPoint("CENTER", portraitRing, "CENTER", 0, 0)
    portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    row.portrait = portrait

    local portraitMask = row:CreateMaskTexture(nil, "OVERLAY")
    portraitMask:SetAllPoints(portrait)
    portraitMask:SetTexture(
        "Interface/CHARACTERFRAME/TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )
    portrait:AddMaskTexture(portraitMask)

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", row, "LEFT", 17, 0)
    name:SetWidth(172)
    name:SetJustifyH("LEFT")
    if name.SetWordWrap then
        name:SetWordWrap(false)
    end
    if name.SetMaxLines then
        name:SetMaxLines(1)
    end
    if name.SetWordWrap then name:SetWordWrap(false) end
    name:SetText(CF.T("ENEMY"))
    row.name = name

    local targetLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetLabel:SetPoint("LEFT", row, "LEFT", 198, 0)
    targetLabel:SetWidth(42)
    targetLabel:SetJustifyH("LEFT")
    targetLabel:SetText("|cff65ff72" .. CF.T("TARGET") .. "|r")
    targetLabel:Hide()
    row.targetLabel = targetLabel

    -- Dedicated health column:
    -- exact current HP on top, percentage below.
    local healthAbs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthAbs:SetPoint("TOPLEFT", row, "TOPLEFT", 246, -6)
    healthAbs:SetWidth(82)
    healthAbs:SetJustifyH("CENTER")
    healthAbs:SetTextColor(0.92, 0.92, 0.96, 1)
    healthAbs:SetText("")
    row.healthAbs = healthAbs

    local healthPct = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthPct:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 246, 6)
    healthPct:SetWidth(82)
    healthPct:SetJustifyH("CENTER")
    healthPct:SetText("")
    row.healthPct = healthPct

    local healthBar = CreateFrame("StatusBar", nil, row)
    healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    healthBar:SetMinMaxValues(0, 100)
    healthBar:SetValue(0)
    healthBar:SetStatusBarColor(0.38, 1.00, 0.46, 1)
    healthBar:EnableMouse(false)
    local healthBackground = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBackground:SetAllPoints(healthBar)
    healthBackground:SetColorTexture(0.045, 0.035, 0.025, 1)
    -- BackdropTemplate reads its size in Lua when geometry changes. A native
    -- health display can carry secret geometry, so draw the rim with anchors
    -- only, as for the target border above; no size callback or arithmetic.
    local healthBorder = CreateFrame("Frame", nil, healthBar)
    healthBorder:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -1, 1)
    healthBorder:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 1, -1)
    healthBorder:SetFrameLevel(healthBar:GetFrameLevel() + 1)
    local healthTop = healthBorder:CreateTexture(nil, "OVERLAY")
    healthTop:SetPoint("TOPLEFT")
    healthTop:SetPoint("TOPRIGHT")
    healthTop:SetHeight(1)
    healthTop:SetColorTexture(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 0.85)
    local healthBottom = healthBorder:CreateTexture(nil, "OVERLAY")
    healthBottom:SetPoint("BOTTOMLEFT")
    healthBottom:SetPoint("BOTTOMRIGHT")
    healthBottom:SetHeight(1)
    healthBottom:SetColorTexture(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 0.85)
    local healthLeft = healthBorder:CreateTexture(nil, "OVERLAY")
    healthLeft:SetPoint("TOPLEFT", healthBorder, "TOPLEFT", 0, -1)
    healthLeft:SetPoint("BOTTOMLEFT", healthBorder, "BOTTOMLEFT", 0, 1)
    healthLeft:SetWidth(1)
    healthLeft:SetColorTexture(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 0.85)
    local healthRight = healthBorder:CreateTexture(nil, "OVERLAY")
    healthRight:SetPoint("TOPRIGHT", healthBorder, "TOPRIGHT", 0, -1)
    healthRight:SetPoint("BOTTOMRIGHT", healthBorder, "BOTTOMRIGHT", 0, 1)
    healthRight:SetWidth(1)
    healthRight:SetColorTexture(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 0.85)
    healthBorder:EnableMouse(false)
    healthBar:Hide()
    row.healthBar = healthBar
    row.healthDisplayEmpty = true

    local healthDivider = row:CreateTexture(nil, "ARTWORK")
    healthDivider:SetPoint("LEFT", row, "LEFT", 335, 0)
    healthDivider:SetSize(1, 28)
    healthDivider:SetColorTexture(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 0.72)
    row.healthDivider = healthDivider

    local container = (CF.Client and CF.Client.CreateAuraContainer(row)) or CreateFrame("AuraContainer",nil,row,"CustomAuraContainerTemplate")

    container:SetPoint("LEFT", row, "LEFT", 345, 0)
    container:SetSize(178, 34)

    local auraOptions = {
        maxFrameCount = 8,
        initializeFrame = InitAuraButton,
        candidateFilters = BuildSpellCandidateFilters(GetAuraContext()),
        layout = {
            elementWidth = 34,
            elementHeight = 34,
            elementSpacing = 4,
            lineSpacing = 16,
        },
    }

    -- Dynamic priority sorting:
    -- strictly by expiration timestamp, soonest first.
    if CF_AuraSortMethod and CF_AuraSortDirection then
        auraOptions.sortMethod = CF_AuraSortMethod.ExpirationOnly
        auraOptions.sortDirection = CF_AuraSortDirection.Normal
    end

    container:AddAuraGroup("playerDots", "HARMFUL|PLAYER", auraOptions)

    -- Apply the sort explicitly as well. This is intentional because the
    -- Forever beta currently appears to ignore the creation-time option in
    -- some situations.
    if container.SetAuraGroupSortMethod
        and CF_AuraSortMethod
        and CF_AuraSortDirection
    then
        container:SetAuraGroupSortMethod(
            "playerDots",
            CF_AuraSortMethod.ExpirationOnly,
            CF_AuraSortDirection.Normal
        )
    end

    row.auraContainer = container
    if not role then rows[index] = row end
    ApplyTargetDisplayLayoutToRow(row)
    return row
end

-- Presentation-only rows: never enter the GUID tracker or its retention lifecycle.
function CF.CreateClickRoleRow(parent, role)
    return CreateRow(role == "focus" and 1 or 2, parent, role)
end

local function RefreshDotSortForRow(row)
    if not row or not row.auraContainer then
        return
    end
    if CF.PrepareTrackedAuraRefresh then CF.PrepareTrackedAuraRefresh(row) end
    -- Retained native duration objects remain display-only. Asking the client
    -- to rebuild them through an unavailable token would discard the display.
    if row.offscreen and row.cfRetainedAuras then return end

    local container = row.auraContainer

    -- Keep the intended sort rule explicit.
    if container.SetAuraGroupSortMethod
        and CF_AuraSortMethod
        and CF_AuraSortDirection
    then
        pcall(
            container.SetAuraGroupSortMethod,
            container,
            "playerDots",
            CF_AuraSortMethod.ExpirationOnly,
            CF_AuraSortDirection.Normal
        )
    end

    -- Important:
    -- changing/setting the sort rule alone does not necessarily force the
    -- currently assigned AuraButtons to be rebuilt/reordered in Forever beta.
    -- UpdateAllAuras explicitly asks the managed container to reprocess them.
    if container.UpdateAllAuras then
        pcall(container.UpdateAllAuras, container)
    end
    if CF.RefreshAuraLayoutContainers then CF.RefreshAuraLayoutContainers(row) end
end

local function RefreshDotSortForUnit(unit)
    local row = FindRowByUnitOrGUID(unit)
    if row then
        RefreshDotSortForRow(row)
    end
end

local function ApplySpellFilterToRow(row, context)
    if not row or not row.auraContainer then
        return
    end

    local container = row.auraContainer
    if CF.ConfigureRowAuras then
        CF.ConfigureRowAuras(row, context, GetTargetDisplayMode())
        RefreshDotSortForRow(row)
        return
    end
    local filters = BuildSpellCandidateFilters(context)

    if container.SetAuraGroupCandidateFilters then
        pcall(
            container.SetAuraGroupCandidateFilters,
            container,
            "playerDots",
            filters
        )
    end

    -- Force the managed container to re-evaluate current aura assignments.
    if container.UpdateAllAuras then
        pcall(container.UpdateAllAuras, container)
    end

    RefreshDotSortForRow(row)
end

local function ApplySpellFiltersToAllRows()
    local context = GetAuraContext()
    lastAuraContext = context

    for i = 1, MAX_ROWS do
        if rows[i] then
            ApplySpellFilterToRow(rows[i], context)
        end
    end
end

local function UpdateRowDisplayedName(row)
    if not row or not row.name then
        return
    end

    local mode = GetTargetDisplayMode()
    local fullName = row.fullName

    if not IsSecretValue(fullName) and fullName == nil then
        fullName = CF.T("ENEMY")
    end

    if mode == "standard" or (CF.IsHealthbarView and CF.IsHealthbarView()) then
        row.name:SetText(fullName)
    elseif mode == "compact" then
        if row.fullNameIsSecret or IsSecretValue(fullName) then
            -- Secret strings may be displayed, but not shortened in Lua.
            -- The fixed 92px FontString width provides the visual clipping.
            row.name:SetText(fullName)
        else
            row.name:SetText(ShortDisplayName(fullName, 12))
        end
    else
        row.name:SetText("")
    end
end

local function UpdateRowPortrait(row, unit)
    if not row or not row.portrait or not unit or not UnitExistsReadable(unit) then
        return
    end

    local ok = pcall(SetPortraitTexture, row.portrait, unit)
    if not ok then
        row.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
end

ApplyTargetDisplayLayoutToRow = function(row)
    if not row then return end
    if CF.RestoreHealthbarRowStyle then CF.RestoreHealthbarRowStyle(row) end
    if CF.RestoreBarsRowStyle then CF.RestoreBarsRowStyle(row) end
    if CF.RestoreMatrixRowStyle then CF.RestoreMatrixRowStyle(row) end

    local mode = GetTargetDisplayMode()
    local rowWidth = GetCurrentRowWidth()
    local healthX, healthWidth

    local rowHeight = CF.GetAuraLayoutRowHeight and CF.GetAuraLayoutRowHeight() or ROW_H
    row:SetSize(rowWidth - 12, rowHeight - 2)

    row.name:ClearAllPoints()
    row.targetLabel:ClearAllPoints()
    row.healthAbs:ClearAllPoints()
    row.healthPct:ClearAllPoints()
    row.healthDivider:ClearAllPoints()
    row.auraContainer:ClearAllPoints()
    row.raidMarker:ClearAllPoints()

    if mode == "standard" then
        row.portrait:Hide()
        row.portraitRing:Hide()
        row.name:Show()

        row.raidMarker:SetPoint("LEFT", row, "LEFT", 12, 0)
        row.name:SetPoint("LEFT", row, "LEFT", 38, 0)
        row.name:SetWidth(153)

        row.targetLabel:SetPoint("LEFT", row, "LEFT", 198, 0)
        row.targetLabel:SetWidth(42)

        healthX, healthWidth = 246, 82

        row.healthDivider:SetPoint("LEFT", row, "LEFT", 335, 0)

        row.auraContainer:SetPoint("LEFT", row, "LEFT", 345, 0)
        row.auraContainer:SetSize(178, 34)

    elseif mode == "compact" then
        row.portrait:Show()
        row.portraitRing:Show()
        row.name:Show()
        row.targetLabel:Hide()

        row.portraitRing:ClearAllPoints()
        row.portraitRing:SetPoint("LEFT", row, "LEFT", 13, 0)
        row.raidMarker:SetPoint("TOPLEFT", row.portraitRing, "TOPLEFT", -5, 5)

        row.name:SetPoint("LEFT", row, "LEFT", 57, 0)
        row.name:SetWidth(92)

        healthX, healthWidth = 154, 72

        row.healthDivider:SetPoint("LEFT", row, "LEFT", 232, 0)

        row.auraContainer:SetPoint("LEFT", row, "LEFT", 242, 0)
        row.auraContainer:SetSize(176, 34)

    else
        row.portrait:Show()
        row.portraitRing:Show()
        row.name:Hide()
        row.targetLabel:Hide()

        row.portraitRing:ClearAllPoints()
        row.portraitRing:SetPoint("LEFT", row, "LEFT", 13, 0)
        row.raidMarker:SetPoint("TOPLEFT", row.portraitRing, "TOPLEFT", -5, 5)

        healthX, healthWidth = 58, 70

        row.healthDivider:SetPoint("LEFT", row, "LEFT", 134, 0)

        row.auraContainer:SetPoint("LEFT", row, "LEFT", 144, 0)
        row.auraContainer:SetSize(176, 34)
    end

    if CF.GetStandardHealthWidth then healthWidth = CF.GetStandardHealthWidth(mode) end
    row.healthAbs:SetPoint("TOPLEFT", row, "TOPLEFT", healthX, -6)
    row.healthAbs:SetWidth(healthWidth)
    row.healthPct:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", healthX, 6)
    row.healthPct:SetWidth(healthWidth)

    if row.healthBar then
        row.healthBar:ClearAllPoints()
        -- Use fixed layout dimensions and the row itself, never the geometry
        -- of a FontString which may currently contain a secret percentage.
        row.healthBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", healthX + 1, 8)
        row.healthBar:SetSize(healthWidth - 2, 10)
        ApplyRowHealthDisplay(row)
    end
    UpdateRowDisplayedName(row)
    if CF.ConfigureRowAuras then CF.ConfigureRowAuras(row, GetAuraContext(), mode) end
    if CF.GetAuraLayoutColumns then
        healthX = CF.GetAuraLayoutColumns(mode).healthX - CF.GetAuraLayoutPortraitOffset(mode)
    end
    if CF.ExperimentalLayoutRow then CF.ExperimentalLayoutRow(row) end
    if CF.LayoutExecuteIndicator then CF.LayoutExecuteIndicator(row,healthX,healthWidth) end
    if CF.LayoutMatrixRow then CF.LayoutMatrixRow(row) end
    if CF.LayoutBarsRow then CF.LayoutBarsRow(row) end
    if CF.LayoutHealthbarRow then CF.LayoutHealthbarRow(row) end
    if CF.ApplyTrackedRowAvailability then CF.ApplyTrackedRowAvailability(row) end
end

ApplyTargetDisplayMode = function()
    for _, row in ipairs(rows) do
        ApplyTargetDisplayLayoutToRow(row)
    end

    LayoutRows()
    UpdateTargetHighlight()
end

function CF.ApplyAuraLayoutToAllRows()
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    ApplyTargetDisplayMode()
    if CF.ClickCasting then CF.ClickCasting.Refresh() end
end

function CF.LayoutClickRoleRow(row)
    ApplyTargetDisplayLayoutToRow(row)
end

function CF.GetClickRoleGeometry()
    local frameless = CF.IsTrackerFrameHidden and CF.IsTrackerFrameHidden()
    return GetCurrentRowWidth()-(frameless and 12 or 0),
        CF.GetAuraLayoutRowHeight(), frameless and 0 or 6,
        CF.GetMainHeaderHeight() + CF.GetMatrixHeaderHeight() + (frameless and 0 or 4)
end

function CF.GetTrackerView()
    local view = CursiveForeverDB and CursiveForeverDB.trackerView
    return (view == "matrix" or view == "bars" or view == "healthbar") and view or "standard"
end

function CF.RefreshTrackerAppearanceControls()
    if not optionsFrame or not optionsFrame.controls then return end
    for _,key in ipairs({"extraIcons","hideFrame","view"}) do
        local control=optionsFrame.controls[key]
        if control and control.CFRefresh then control.CFRefresh() end
    end
    if CF.RefreshOptionsPages then CF.RefreshOptionsPages() end
end

function CF.RefreshTrackerSizingControls()
    if not optionsFrame or not optionsFrame.controls then return end
    for _,key in ipairs({"trackerWidth","trackerHeight"}) do
        local control=optionsFrame.controls[key]
        if control and control.CFRefresh then control.CFRefresh() end
    end
end

function CF.RefreshTrackerViewControl()
    CF.RefreshTrackerSizingControls()
    if optionsFrame and optionsFrame.controls and optionsFrame.controls.view then
        optionsFrame.controls.view.CFLocaleRefresh()
    end
    if optionsFrame and optionsFrame.controls and optionsFrame.controls.health then
        optionsFrame.controls.health.CFLocaleRefresh()
    end
    if CF.RefreshOptionsPages then CF.RefreshOptionsPages() end
end

function CF.SetTrackerView(view)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not db then return end
    view = (view == "matrix" or view == "bars" or view == "healthbar") and view or "standard"
    if view == "matrix" then
        CF.matrixViewUnavailable = nil
        CF.matrixFallbackDeferred = nil
    end
    if view == "bars" then
        CF.barsViewUnavailable = nil
        CF.barsFallbackDeferred = nil
    end
    if view ~= CF.GetTrackerView() and CF.CanSwitchTrackerView and not CF.CanSwitchTrackerView(view) then
        CF.pendingTrackerView = view
        CF.RefreshTrackerViewControl()
        return false
    end
    CF.pendingTrackerView = nil
    db.trackerView = view
    if view == "standard" then CF.matrixFallbackDeferred = nil end
    if view ~= "bars" then CF.barsFallbackDeferred = nil end
    ApplyTargetDisplayMode()
    if CF.ClickCasting then CF.ClickCasting.Refresh() end
    CF.RefreshTrackerViewControl()
    return CF.GetTrackerView() == view
end

function CF.ApplyPendingTrackerView()
    local view = CF.pendingTrackerView
    if not view or not db or (CF.CanSwitchTrackerView and not CF.CanSwitchTrackerView(view)) then return false end
    CF.pendingTrackerView = nil
    db.trackerView = view
    if view == "standard" then CF.matrixFallbackDeferred = nil end
    if view ~= "bars" then CF.barsFallbackDeferred = nil end
    CF.RefreshTrackerViewControl()
    return true
end

function CF.SetRowAuraUnit(row, unit)
    local changed = row.cfAuraUnit ~= unit
    if unit == "none" or (row.cfAuraUnit and row.cfAuraUnit ~= unit) then row.cfRetainedAuras = nil end
    row.cfAuraUnit = unit
    if changed and CF.TraceTracker then CF.TraceTracker("BIND_REQUEST",row) end
    if CF.UpdateAuraLayoutUnit then CF.UpdateAuraLayoutUnit(row, unit)
    else row.auraContainer:SetUnit(unit) end
end

function CF.ApplyTrackedRowAvailability(row)
    if CF.ApplyTrackerExtrasToRow then CF.ApplyTrackerExtrasToRow(row) end
    if CF.ApplyTrackerRowAppearance then CF.ApplyTrackerRowAppearance(row) end
    if CF.ApplyExecuteAvailability then CF.ApplyExecuteAvailability(row) end
    -- Availability is internal bookkeeping, not a replacement display mode.
    -- Preserve the existing row and its last health display on camera loss.
    if row.cfUnavailableLabel then row.cfUnavailableLabel:Hide() end
    if not row.cfUnavailable or row.cfRetainedAuras then return end
    -- A genuinely invalid binding must still remain hidden if native clearing
    -- fails. This concerns the aura binding, not the remembered enemy's HP.
    local layout = row.cfAuraLayout
    row.auraContainer:Hide()
    if layout then
        for _,key in ipairs({"fixed","others","support"}) do
            if layout[key] then layout[key]:Hide() end
        end
    end
end

function CF.DiscardRetainedAuras(row, reason, currentKey)
    if CF.TraceTracker then CF.TraceTracker("INVALIDATE",row,reason or "explicit",currentKey) end
    row.cfRetainedAuras = nil
    row.cfUnavailable = true
    pcall(CF.SetRowAuraUnit,row,"none")
    CF.ApplyTrackedRowAvailability(row)
end

function CF.ValidateRetainedAuraBindings()
    for _,row in ipairs(rows) do
        if row.offscreen and row.cfRetainedAuras and UnitExistsReadable(row.cfAuraUnit) then
            local key = SafeUnitGUID(row.cfAuraUnit)
            if not IsSafeGUIDKey(key) or key ~= row.guid then
                -- Replace an invalid binding directly when an independent
                -- live token still identifies this enemy. Do not clear the
                -- native display first and only then look for a replacement.
                if not CF.ReconcileStickyRow(row,true) then
                    CF.DiscardRetainedAuras(row,IsSafeGUIDKey(key) and "unit_reused" or "unit_identity_unknown",key)
                end
            end
        end
    end
end

local function SetRowName(row, unit)
    local ok, value = pcall(UnitName, unit)

    if ok and (IsSecretValue(value) or type(value) == "string") then
        row.fullName = value
        row.fullNameIsSecret = IsSecretValue(value)
    elseif not row.fullNameIsSecret and row.fullName == nil then
        row.fullName = CF.T("ENEMY")
        row.fullNameIsSecret = false
    end

    UpdateRowDisplayedName(row)
    UpdateRowPortrait(row, unit)
end

local function UpdateRowHealth(row, unit)
    if not row or not unit or not UnitExistsReadable(unit) then
        if row then
            row.healthAbs:SetText("")
            row.healthValue = nil
            row.healthValueAvailable = false
            row.healthBarValue, row.healthBarMaximum = nil, nil
            row.healthBarValueAvailable = false
            row.healthDisplayEmpty = true
            if CF.ClearBarsHealth then CF.ClearBarsHealth(row) end
            if CF.ClearHealthbarHealth then CF.ClearHealthbarHealth(row) end
            if CF.ClearExecuteIndicator then CF.ClearExecuteIndicator(row) end
            ApplyRowHealthDisplay(row)
        end
        return
    end
    row.healthDisplayEmpty = false
    if CF.UpdateExecuteIndicator then CF.UpdateExecuteIndicator(row,unit) end

    -- Absolute health may be secret during combat, but SetFormattedText can
    -- display it directly without Lua arithmetic.
    local okHealth, health = pcall(UnitHealth, unit)
    local okMaximum, maximum = pcall(UnitHealthMax, unit)
    row.healthBarValueAvailable = okHealth and (IsSecretValue(health) or type(health) == "number")
        and okMaximum and (IsSecretValue(maximum) or (type(maximum) == "number" and maximum > 0))
    if row.healthBarValueAvailable then
        row.healthBarValue, row.healthBarMaximum = health, maximum
    else
        row.healthBarValue, row.healthBarMaximum = nil, nil
    end
    if okHealth and (IsSecretValue(health) or type(health) == "number") then
        local okDisplay = pcall(
            row.healthAbs.SetFormattedText,
            row.healthAbs,
            "%d HP",
            health
        )

        if not okDisplay then
            local okAbbrev, text = pcall(AbbreviateNumbers, health)
            local shown = okAbbrev and pcall(row.healthAbs.SetFormattedText, row.healthAbs, "%s HP", text)
            if not shown then row.healthAbs:SetText("HP ?") end
        end
    else
        row.healthAbs:SetText("HP ?")
    end

    -- Ask WoW for a 0..100 health percentage.
    local okPct, pct
    if CurveConstants and CurveConstants.ScaleTo100 then
        okPct, pct = pcall(
            UnitHealthPercent,
            unit,
            true,
            CurveConstants.ScaleTo100
        )
    else
        okPct, pct = pcall(UnitHealthPercent, unit, true)
    end

    row.healthValueAvailable = okPct and (IsSecretValue(pct) or type(pct) == "number")
    if row.healthValueAvailable then row.healthValue = pct else row.healthValue = nil end
    if CF.UpdateBarsHealth then CF.UpdateBarsHealth(row,unit) end
    if not ApplyRowHealthDisplay(row) then return end

    -- If Forever exposes the scaled percentage as a normal value, use the
    -- exact requested thresholds directly.
    local pctIsSecret = IsSecretValue(pct)

    if not pctIsSecret then
        local okColor = pcall(function()
            if pct < 25 then
                SetRowHealthColor(row, 1.00, 0.28, 0.22)
            elseif pct < 50 then
                SetRowHealthColor(row, 1.00, 0.82, 0.18)
            else
                SetRowHealthColor(row, 0.38, 1.00, 0.46)
            end
        end)

        if okColor then
            return
        end
    end

    -- Secret-value fallback: let the engine evaluate a ColorCurve from the
    -- health fraction, then pass the resulting color straight to the FontString.
    if HEALTH_COLOR_CURVE then
        local okColor, color = pcall(
            UnitHealthPercent,
            unit,
            true,
            HEALTH_COLOR_CURVE
        )

        if okColor then
            local applied = pcall(function()
                SetRowHealthColor(row, color:GetRGB())
            end)

            if applied then
                return
            end
        end
    end

    SetRowHealthColor(row, 0.85, 0.85, 0.85)
end

local function UpdateHealthForUnit(unit)
    local row = FindRowByUnitOrGUID(unit)
    if row then
        if row.offscreen and row.cfUnavailable then return end
        UpdateRowHealth(row, unit)
    end
end

function CF.SuspendTrackedRow(row)
    if not row.cfUnavailable and CF.TraceTracker then CF.TraceTracker("UNAVAILABLE",row) end
    row.cfUnavailable = true
    row.cfLiveUnit = nil
    if not row.cfRetainedAuras then pcall(CF.SetRowAuraUnit,row,"none") end
    -- As before the experimental preview, a missing nameplate leaves the
    -- last health display intact. It is not sampled as fresh combat data.
    row.targetBorder:Hide()
    row.targetLabel:Hide()
    CF.ApplyTrackedRowAvailability(row)
end

local function FindFreeRow()
    for i = 1, MAX_ROWS do
        if not rows[i].unit then
            return rows[i]
        end
    end
    return nil
end

-- Reuse the established health, portrait, raid-marker and target decorations.
-- These visual rows have fixed unit aliases and are not tracker/model records.
function CF.RefreshClickRoleRow(row)
    local unit = row.cfClickRole
    local key=SafeUnitGUID(unit)
    if key~=row.guid then row.fullName,row.fullNameIsSecret=nil,false end
    row.unit, row.guid = unit, key
    SetRowName(row,unit)
    UpdateRowHealth(row,unit)
    CF.UpdateRowRaidMarker(row,unit)
    local selected = IsCurrentTarget(unit)
    row.cfTargetSelected = selected
    row.targetBorder:SetShown(selected)
    row.targetLabel:Hide()
    row.portraitRing:SetColorTexture(selected and THEME_ACTIVE_R or THEME_GOLD_R,
        selected and THEME_ACTIVE_G or THEME_GOLD_G,
        selected and THEME_ACTIVE_B or THEME_GOLD_B,1)
    row.bg:SetColorTexture(selected and .095 or THEME_BG_ALT1_R,
        selected and .073 or THEME_BG_ALT1_G,selected and .040 or THEME_BG_ALT1_B,.97)
    if CF.ApplyTrackerRowAppearance then CF.ApplyTrackerRowAppearance(row) end
end

local function ShowUnit(unit)
    if UnitIsActuallyDead(unit) then return end
    local guid = SafeUnitGUID(unit)

    if unitToRow[unit] then
        local row = unitToRow[unit]
        row.guid = row.guid or guid
        SetRowName(row, unit)
        UpdateRowHealth(row, unit)
        CF.UpdateRowRaidMarker(row, unit)
        UpdateTargetHighlight()
        return
    end

    -- A nameplate token may disappear when the mob leaves the camera view.
    -- If that same GUID comes back, reconnect the already existing row instead
    -- of creating a new one.
    if IsSafeGUIDKey(guid) and guidToRow[guid] then
        local row = guidToRow[guid]
        local stickyKey = StickyKeyForGUID(guid)

        if row.unit and unitToRow[row.unit] == row then
            unitToRow[row.unit] = nil
        end
        if stickyKey and unitToRow[stickyKey] == row then
            unitToRow[stickyKey] = nil
        end

        row.unit = unit
        row.offscreen = nil
        row.cfUnavailable = nil
        row.cfRetainedAuras = nil
        row.cfLiveUnit = nil
        row.lastNameplateUnit = unit
        unitToRow[unit] = row
        if CF.TraceTracker then CF.TraceTracker("RECONNECT",row) end

        SetRowName(row, unit)
        UpdateRowHealth(row, unit)

        pcall(function()
            CF.SetRowAuraUnit(row, unit)
        end)

        ApplySpellFilterToRow(row, GetAuraContext())
        RefreshDotSortForRow(row)
        ApplyTargetDisplayLayoutToRow(row)
        LayoutRows()
        return
    end

    local row = FindFreeRow()
    if not row then
        return
    end

    row.unit = unit
    row.guid = guid
    row.offscreen = nil
    row.cfUnavailable = nil
    row.cfRetainedAuras = nil
    row.cfLiveUnit = nil
    row.lastNameplateUnit = string.match(unit or "", "^nameplate%d+$") and unit or nil

    unitToRow[unit] = row
    if IsSafeGUIDKey(guid) then
        guidToRow[guid] = row
    end

    SetRowName(row, unit)
    UpdateRowHealth(row, unit)

    pcall(function()
        CF.SetRowAuraUnit(row, unit)
    end)

    ApplySpellFilterToRow(row, GetAuraContext())
    RefreshDotSortForRow(row)
    LayoutRows()
end

local function HideUnit(unit)
    local row = unitToRow[unit]

    if not row and string.match(tostring(unit), "^sticky:") then
        row = unitToRow[unit]
    end

    if not row then
        local guid = SafeUnitGUID(unit)
        if IsSafeGUIDKey(guid) then
            row = guidToRow[guid]
        end
    end

    if not row then return end

    if CF.TraceTracker then CF.TraceTracker("CLEAR",row) end

    if row.unit and unitToRow[row.unit] == row then
        unitToRow[row.unit] = nil
    end

    if IsSafeGUIDKey(row.guid) and guidToRow[row.guid] == row then
        guidToRow[row.guid] = nil
    end

    row.unit = nil
    row.guid = nil
    row.offscreen = nil
    row.cfUnavailable = nil
    row.cfRetainedAuras = nil
    row.cfLiveUnit = nil
    row.lastNameplateUnit = nil
    row.fullName = nil
    row.fullNameIsSecret = nil

    pcall(function()
        CF.SetRowAuraUnit(row, "none")
    end)

    row.name:SetText(CF.T("ENEMY"))
    row.healthAbs:SetText("")
    row.healthValue = nil
    row.healthValueAvailable = false
    row.healthBarValue, row.healthBarMaximum = nil, nil
    row.healthBarValueAvailable = false
    row.healthDisplayEmpty = true
    if CF.ClearBarsHealth then CF.ClearBarsHealth(row) end
    if CF.ClearHealthbarHealth then CF.ClearHealthbarHealth(row) end
    if CF.ClearExecuteIndicator then CF.ClearExecuteIndicator(row) end
    ApplyRowHealthDisplay(row)
    row.targetBorder:Hide()
    row.targetLabel:Hide()
    if row.cfUnavailableLabel then row.cfUnavailableLabel:Hide() end
    if row.cfExperimentalPanel then row.cfExperimentalPanel:Hide() end
    row:Hide()

    LayoutRows()
end

-- Additive identity-only entry point: a missing/reused unit token is not
-- queried to determine which row died. The established unit-based path below
-- remains responsible for ordinary readable unit death flags.
function CF.RemoveDeadTrackedGUID(key, source)
    if not CF.DeathEvents or not CF.DeathEvents.ReadGUID(key) then return false end
    local row = guidToRow[key]
    if not row or not row.unit or CF.DeathEvents.ReadGUID(row.guid) ~= key then return false end
    if CF.TraceTracker then CF.TraceTracker("DEATH_EVENT",row,source,key) end

    -- Keep the existing performance closing path when the row's own live
    -- token still matches. A detached row closes by GUID without new ticks.
    if not row.offscreen and UnitExistsReadable(row.unit)
        and CF.DeathEvents.ReadUnitGUID(row.unit) == key then
        CF.PerformanceDetailTargetDied(row.unit)
        CF.ForgetUnitEngagement(row.unit)
    else
        CF.PerformanceDetailTargetGUIDDied(key)
    end
    CF.playerEngagedGUIDs[key] = nil
    if CF.Experimental then CF.Experimental.ForgetTarget(key) end
    HideUnit(row.unit)
    return true
end

function CF.RemoveDeadTrackedUnit(unit)
    local actualKey = SafeUnitGUID(unit)
    if not actualKey then
        -- This path is called only after a readable positive death result.
        -- SafeUnitGUID deliberately excludes unavailable units for all normal
        -- sampling. Here only, accept a still-readable terminal identity.
        local ok, key = pcall(UnitGUID, unit)
        if ok and IsSafeGUIDKey(key) then actualKey = key end
    end
    local row = unitToRow[unit] or (IsSafeGUIDKey(actualKey) and guidToRow[actualKey])
    if row and IsSafeGUIDKey(row.guid) and actualKey ~= row.guid then
        return false -- a reused token's death does not belong to this row
    end
    local key = row and row.guid or SafeUnitGUID(unit)
    if CF.TraceTracker then CF.TraceTracker("DEAD",row,"confirmed",actualKey) end
    CF.PerformanceDetailTargetDied(unit)
    CF.ForgetUnitEngagement(unit)
    if IsSafeGUIDKey(key) then
        CF.playerEngagedGUIDs[key] = nil
        if CF.Experimental then CF.Experimental.ForgetTarget(key) end
    end
    HideUnit(row and row.unit or unit)
    return true
end

function CF.ReconcileStickyRow(row, requireLiveBinding)
    if not row.offscreen then return end
    -- Removed nameplate tokens may already name a different creature. Use
    -- only a currently readable independent token with exactly the same GUID.
    for _,unit in ipairs({"target","focus","mouseover","pettarget","targettarget"}) do
        local key = SafeUnitGUID(unit)
        if IsSafeGUIDKey(key) and key == row.guid then
            local dead = UnitIsActuallyDead(unit)
            if dead == true then CF.RemoveDeadTrackedUnit(unit); return true end
            if dead == false then
                if requireLiveBinding then
                    row.cfRetainedAuras = nil
                    local ok = pcall(CF.SetRowAuraUnit,row,unit)
                    if not ok then return false end
                end
                if row.cfLiveUnit ~= unit and CF.TraceTracker then CF.TraceTracker("LIVE_ALIAS",row,unit) end
                row.cfLiveUnit = unit
                if row.cfUnavailable or (not row.cfRetainedAuras and row.cfAuraUnit ~= unit) then
                    row.cfUnavailable = nil
                    SetRowName(row,unit)
                    -- A matching target can verify life/health without
                    -- replacing the retained native aura display.
                    if not row.cfRetainedAuras then
                        local ok = pcall(CF.SetRowAuraUnit,row,unit)
                        if not ok then
                            CF.DiscardRetainedAuras(row,"binding_failed")
                            row.cfLiveUnit = nil
                            return false
                        end
                    end
                    ApplyTargetDisplayLayoutToRow(row)
                end
                UpdateRowHealth(row,unit)
                return true
            end
        end
    end
    if not requireLiveBinding then CF.SuspendTrackedRow(row) end
    return false
end

local function DetachUnitToSticky(unit, deferLayout)
    local row = unitToRow[unit]
    if not row then
        return false
    end

    -- Outside combat there is no reason to preserve the row.
    if not PlayerInCombat() then
        HideUnit(unit)
        return false
    end

    local guid = row.guid
    if not IsSafeGUIDKey(guid) then
        -- PvP/protected units can expose only secret GUIDs. They cannot
        -- participate in GUID-keyed sticky tracking; keep the addon error-free.
        HideUnit(unit)
        return false
    end

    unitToRow[unit] = nil

    local stickyKey = StickyKeyForGUID(guid)
    row.unit = stickyKey
    row.offscreen = true
    local exists = UnitExistsReadable(unit)
    local currentKey = exists and SafeUnitGUID(unit) or nil
    row.cfRetainedAuras = row.cfAuraUnit == unit and (not exists or currentKey == guid)
    row.lastNameplateUnit = unit

    unitToRow[stickyKey] = row
    guidToRow[guid] = row
    if CF.TraceTracker then
        local reason = row.cfRetainedAuras and "native_retained"
            or (row.cfAuraUnit ~= unit and "binding_changed")
            or (IsSafeGUIDKey(currentKey) and "unit_reused" or "unit_identity_unknown")
        CF.TraceTracker("DETACH",row,reason,currentKey)
    end

    -- Preserve the existing native duration objects as in the established
    -- tracker. Visibility loss is not death. Only a matching independent
    -- token may verify current health/life; confirmed death still removes it.
    CF.ReconcileStickyRow(row)
    if not deferLayout then LayoutRows() end

    return true
end

function CF.PrepareTrackedAuraRefresh(row)
    if row and row.cfClickRole then return end
    if not row or row.offscreen or not row.unit or not IsSafeGUIDKey(row.guid) then return end
    local unit = row.unit
    local exists = UnitExistsReadable(unit)
    local key = exists and SafeUnitGUID(unit) or nil
    if not exists or (IsSafeGUIDKey(key) and key ~= row.guid) then
        -- UNIT_AURA or a layout pass can precede NAME_PLATE_UNIT_REMOVED.
        -- Preserve the old display before an explicit native rebuild loses
        -- it. A token already assigned to somebody else must still be cleared.
        if CF.TraceTracker then CF.TraceTracker("EARLY_DETACH",row,not exists and "unit_unavailable" or "unit_reused") end
        if not exists then visibleUnits[unit] = nil end
        DetachUnitToSticky(unit,true)
    end
end

local function HideAllExcept(keepUnit)
    local toHide = {}

    for unit in pairs(unitToRow) do
        if unit ~= keepUnit then
            toHide[#toHide + 1] = unit
        end
    end

    for _, unit in ipairs(toHide) do
        HideUnit(unit)
    end
end

local function FindVisibleTokenForTarget()
    if not UnitExistsReadable("target") then
        return nil
    end

    for unit in pairs(visibleUnits) do
        if UnitExistsReadable(unit) then
            if ReadClientBoolean(UnitIsUnit, "target", unit) == true then
                return unit
            end
        end
    end

    return nil
end

local function MarkCurrentTargetEngaged()
    if not IsHostile("target") then
        return
    end

    local unit = FindVisibleTokenForTarget()
    if unit then
        CF.MarkUnitEngaged(unit)
        ShowUnit(unit)
    end
end

local function ClearEngagementMemory()
    wipe(CF.playerEngagedGUIDs)
    wipe(playerEngagedUnits)
end

local function RefreshDisplayPolicy()
    CF.ValidateRetainedAuraBindings()
    local currentContext = GetAuraContext()
    if currentContext ~= lastAuraContext then
        ApplySpellFiltersToAllRows()
    end

    local inCombat = PlayerInCombat()

    -- OUT OF COMBAT:
    -- Show only current hostile target. Prefer its nameplate token so the
    -- unit identity remains stable if available; otherwise use "target".
    if not inCombat then
        local wanted = nil

        if db.showTargetOutOfCombat and IsHostile("target") and not UnitIsActuallyDead("target") then
            wanted = FindVisibleTokenForTarget() or "target"
        end

        if wanted then
            HideAllExcept(wanted)
            ShowUnit(wanted)
        else
            HideAllExcept(nil)
        end

        UpdateTargetHighlight()
        return
    end

    -- IN COMBAT:
    -- Never keep the synthetic out-of-combat "target" row.
    if unitToRow["target"] then
        HideUnit("target")
    end

    local raid = InRaid()

    -- Evaluate every visible hostile nameplate.
    for unit in pairs(visibleUnits) do
        local shouldShow = false
        local previous = unitToRow[unit]
        local currentKey = SafeUnitGUID(unit)
        if previous and IsSafeGUIDKey(previous.guid) and IsSafeGUIDKey(currentKey)
            and previous.guid ~= currentKey then
            DetachUnitToSticky(unit)
        end

        if UnitExistsReadable(unit)
            and IsHostile(unit)
            and not UnitIsActuallyDead(unit)
        then
            if raid then
                -- RAID MODE: every visible hostile enemy.
                shouldShow = true
            else
                -- SOLO/PARTY MODE: only enemies tied to our threat.
                shouldShow = IsOurCombat(unit)
                -- Combat can begin at projectile launch before the enemy's
                -- combat/threat data arrives. Keep an already displayed,
                -- still-selected enemy through that handover. This neither
                -- marks engagement nor asserts that a spell hit. A reused or
                -- unreadable token must never inherit the previous row.
                if not shouldShow and previous and not previous.offscreen
                    and previous.unit == unit and IsSafeGUIDKey(previous.guid)
                    and IsSafeGUIDKey(currentKey) and previous.guid == currentKey
                    and IsCurrentTarget(unit) then
                    shouldShow = true
                end
            end
        end

        if shouldShow then
            ShowUnit(unit)
        elseif UnitIsActuallyDead(unit) == true then
            CF.RemoveDeadTrackedUnit(unit)
        elseif unitToRow[unit] and not UnitExistsReadable(unit) then
            -- Some client event sequences lose the token before REMOVED.
            -- A periodic refresh must not delete the row in that interval.
            visibleUnits[unit] = nil
            DetachUnitToSticky(unit)
        else
            HideUnit(unit)
        end
    end

    for _,row in ipairs(rows) do
        if row.unit and row.offscreen then CF.ReconcileStickyRow(row) end
    end
    UpdateTargetHighlight()
end

local function RescanVisibleNameplates()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        Print(CF.T("NAMEPLATE_API_MISSING"))
        return
    end

    local seen = {}
    local plates = C_NamePlate.GetNamePlates() or {}

    for _, plate in ipairs(plates) do
        local unit = plate.unitToken
        if unit then
            seen[unit] = true
            visibleUnits[unit] = true
        end
    end

    local toRemove = {}
    for unit in pairs(visibleUnits) do
        if not seen[unit] then
            toRemove[#toRemove + 1] = unit
        end
    end

    for _, unit in ipairs(toRemove) do
        visibleUnits[unit] = nil

        if UnitIsActuallyDead(unit) and CF.RemoveDeadTrackedUnit(unit) then
            playerEngagedUnits[unit] = nil
        elseif PlayerInCombat() then
            DetachUnitToSticky(unit)
        else
            HideUnit(unit)
        end
    end

    RefreshDisplayPolicy()

end

local function SavePosition()
    if not db or not main then return end

    if CF.ClickCasting and CF.ClickCasting.SavePosition() then return end
    local point, _, relativePoint, x, y = main:GetPoint(1)
    db.point = point
    db.relativePoint = relativePoint
    db.x = x
    db.y = y
end

local function RestorePosition()
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return end
    if CF.ClickCasting and CF.ClickCasting.RestorePosition() then return end
    main:ClearAllPoints()

    if db and db.point then
        main:SetPoint(
            db.point,
            UIParent,
            db.relativePoint or db.point,
            db.x or 0,
            db.y or 0
        )
    else
        main:SetPoint("CENTER", UIParent, "CENTER", 360, 40)
    end
end

local function ApplyMainScale()
    if main then
        main:SetScale(db.frameScale or 1.0)
        if CF.ClickCasting then CF.ClickCasting.Refresh() end
    end
end

local function GetNormalMainTitleText()
    return "|cffdfbd62Cursive v"
        .. VERSION
        .. " - by Leandarh Valinor|r"
end

local function EnemyNameplatesEnabled()
    if GetCVarBool then
        local ok, enabled = pcall(GetCVarBool, "nameplateShowEnemies")
        if ok then
            return enabled == true
        end
    end

    if GetCVar then
        local ok, value = pcall(GetCVar, "nameplateShowEnemies")
        if ok and value ~= nil then
            return tostring(value) == "1"
        end
    end

    -- If the client unexpectedly exposes neither API, do not show a false alarm.
    return true
end

local function GetEnemyNameplateBindingText()
    if not GetBindingKey then
        return CF.T("KEY_UNKNOWN")
    end

    local ok, key1 = pcall(GetBindingKey, "NAMEPLATES")
    if not ok or not key1 or key1 == "" then
        return CF.T("NO_KEY_BOUND")
    end

    if GetBindingText then
        local okText, text = pcall(GetBindingText, key1, "KEY_", true)
        if okText and text and text ~= "" then
            return text
        end
    end

    return tostring(key1)
end

local function UpdateNameplateRequirementWarning()
    if not main or not main.titleMeta or not main.nameplateWarning then
        return
    end

    local warning = not EnemyNameplatesEnabled()
    local changed = main.cfNameplateWarningActive ~= warning
    main.cfNameplateWarningActive = warning
    if changed then LayoutRows() end
    if not warning then
        main.titleMeta:SetText(GetNormalMainTitleText())
        main.nameplateWarning:Hide()
        main.nameplateWarning:SetAlpha(1)
        nameplateWarningBlinkElapsed = 0
        return
    end

    -- Keep the titlebar recognizable, but make enough room for the actual hint.
    main.titleMeta:SetText("|cffdfbd62Cursive|r")
    main.nameplateWarning:SetText(
        "|cffd8b15a" .. CF.T("NAMEPLATES_ENABLE") .. "|r"
        .. "|cffffd878" .. GetEnemyNameplateBindingText() .. "|r"
    )
    main.nameplateWarning:Show()
end

function CF.SetMainHeaderShown(shown)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not db then return end
    db.showHeader = shown ~= false
    if CF.ClickCasting then CF.ClickCasting.Refresh() end
    LayoutRows()
end

local function CreateUI()
    if main then return end

    main = CreateFrame("Frame", "CursiveForeverFrame", UIParent, "BackdropTemplate")
    if CF.RegisterMainWindow then CF.RegisterMainWindow(main) end
    main:SetSize(GetCurrentRowWidth(), CF.GetMainHeaderHeight() + MIN_BODY_H)
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:EnableMouse(true)

    ApplyDarkBackdrop(main, 0.97)
    main.cfFrameArt=AddWitchCorners(main)
    local glowTop,glowBottom=AddInnerGlow(main)
    main.cfFrameArt[#main.cfFrameArt+1]=glowTop
    main.cfFrameArt[#main.cfFrameArt+1]=glowBottom

    -- Very small combat header: it exists primarily as a visible drag handle.
    local titlebar = CreateFrame("Frame", nil, main)
    titlebar:SetPoint("TOPLEFT", 1, -1)
    titlebar:SetPoint("TOPRIGHT", -1, -1)
    titlebar:SetHeight(TITLE_H)
    titlebar:EnableMouse(true)
    titlebar:RegisterForDrag("LeftButton")

    local tb = titlebar:CreateTexture(nil, "BACKGROUND")
    tb:SetAllPoints()
    tb:SetColorTexture(THEME_HEADER_R, THEME_HEADER_G, THEME_HEADER_B, 1)

    local felLine = titlebar:CreateTexture(nil, "ARTWORK")
    felLine:SetPoint("BOTTOMLEFT", titlebar, "BOTTOMLEFT", 0, 0)
    felLine:SetPoint("BOTTOMRIGHT", titlebar, "BOTTOMRIGHT", 0, 0)
    felLine:SetHeight(1)
    felLine:SetColorTexture(THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 0.58)

    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titlebar, "LEFT", 7, 0)
    title:SetPoint("RIGHT", titlebar, "RIGHT", -7, 0)
    title:SetJustifyH("LEFT")
    title:SetText(GetNormalMainTitleText())
    main.titleMeta = title

    local nameplateWarning = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameplateWarning:SetPoint("RIGHT", titlebar, "RIGHT", -7, 0)
    nameplateWarning:SetWidth(265)
    nameplateWarning:SetJustifyH("RIGHT")
    nameplateWarning:Hide()
    main.nameplateWarning = nameplateWarning

    titlebar:SetScript("OnEnter", function(self)
        if db.lockFrame then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Cursive", 0.88, 0.72, 0.34)
            GameTooltip:AddLine(CF.T("WINDOW_LOCKED"), 1, 1, 1)
            GameTooltip:Show()
        end
    end)

    titlebar:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    titlebar:SetScript("OnDragStart", function()
        if db.lockFrame then
            return
        end
        if CF.ClickCasting and CF.ClickCasting.StartMoving() then return end
        main:StartMoving()
    end)

    titlebar:SetScript("OnDragStop", function()
        if not db.lockFrame then
            if CF.ClickCasting then CF.ClickCasting.StopMoving() end
            main:StopMovingOrSizing()
            SavePosition()
        end
    end)

    main.titlebar = titlebar
    if CF.RegisterTrackerHeader then CF.RegisterTrackerHeader(titlebar) end
    -- The free background remains a drag surface when the header is hidden.
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart",function()
        if db.showHeader == false and not db.lockFrame then
            if CF.ClickCasting and CF.ClickCasting.StartMoving() then return end
            main:StartMoving()
        end
    end)
    main:SetScript("OnDragStop",function()
        if CF.ClickCasting then CF.ClickCasting.StopMoving() end
        main:StopMovingOrSizing(); SavePosition()
    end)

    for i = 1, MAX_ROWS do
        CreateRow(i)
    end

    main.CFLocaleRefresh = function()
        for _, row in ipairs(rows) do
            if row and row.targetLabel then
                row.targetLabel:SetText("|cff65ff72" .. CF.T("TARGET") .. "|r")
            end
            if row and row.name and not row.unit then
                row.name:SetText(CF.T("ENEMY"))
            end
        end
        UpdateNameplateRequirementWarning()
    end
    CF.RegisterLocaleUpdater(main.CFLocaleRefresh)

    RestorePosition()
    ApplyMainScale()
    ApplySpellFiltersToAllRows()
    CreateRaidCurseAlert()
    UpdateRaidCurseWatcher()
    UpdateNameplateRequirementWarning()

    CF.RefreshMainWindowVisibility()
end

-- ------------------------------------------------------------
-- OPTIONS / HISTORY / MINIMAP
-- ------------------------------------------------------------

-- Three selectable decorative packages for the options-family windows:
-- 1 = Dezent        : raven mark + simple dividers + faint watermark
-- 2 = Rabenornament : raven mark + section sigils + center-rune dividers
--                     + small corner ornaments (DEFAULT)
-- 3 = Vollausbau    : everything from 2 + stronger watermark, double rune
--                     dividers, edge runes and decorated action buttons.
local decoratedFrames = {}
local decoratedSections = {}
local decoratedDividers = {}
local decoratedButtons = {}
local decorButtonCounter = 0

local DECOR_BUTTON_ICONS = {
    DECOR_RUNE_GREEN,
    DECOR_RUNE_PURPLE,
    DECOR_RUNE_VIOLET,
    DECOR_RUNE_GOLD,
    DECOR_RUNE_BLUE,
    DECOR_RUNE_RED,
}

local function GetOptionsDecorStyle()
    local value = tonumber(db and db.optionsDecorStyle) or 2
    if value ~= 1 and value ~= 2 and value ~= 3 then
        value = 2
    end
    return value
end

local function ApplyDecorFrame(frame)
    if not frame or not frame.cfDecor then return end

    local d = frame.cfDecor
    if frame.cfGrimoire then
        for _, key in ipairs({"raven","watermark","headerLeft","headerRight","headerLeft2","headerRight2","headerRune"}) do d[key]:Hide() end
        for _, tex in ipairs(d.corners) do tex:Hide() end
        for _, tex in ipairs(d.edgeRunes) do tex:Hide() end
        return
    end
    local style = GetOptionsDecorStyle()

    d.raven:Show()
    d.raven:SetAlpha(style == 1 and 0.82 or 0.96)

    if style == 1 then
        d.raven:SetSize(34, 34)
    elseif style == 2 then
        d.raven:SetSize(42, 42)
    else
        d.raven:SetSize(48, 48)
    end

    if d.title and d.titlePoint then
        d.title:ClearAllPoints()
        local shift = style == 1 and 39 or (style == 2 and 48 or 55)
        d.title:SetPoint(
            d.titlePoint.point,
            d.titlePoint.relativeTo,
            d.titlePoint.relativePoint,
            (d.titlePoint.x or 0) + shift,
            d.titlePoint.y or 0
        )
    end

    -- Package 1 deliberately keeps only a ghostly watermark.
    -- Package 2 is the clean default without a watermark.
    -- Package 3 brings the raven back as a larger ritual watermark.
    if style == 1 then
        d.watermark:Show()
        d.watermark:SetSize(205, 205)
        d.watermark:SetAlpha(0.028)
        d.watermark:ClearAllPoints()
        d.watermark:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 28)
    elseif style == 3 then
        d.watermark:Show()
        d.watermark:SetSize(320, 320)
        d.watermark:SetAlpha(0.055)
        d.watermark:ClearAllPoints()
        d.watermark:SetPoint("CENTER", frame, "CENTER", 28, -25)
    else
        d.watermark:Hide()
    end

    local showCorners = style >= 2
    for _, tex in ipairs(d.corners) do
        if showCorners then
            tex:Show()
            local size = style == 2 and 18 or 28
            tex:SetSize(size, size)
            tex:SetAlpha(style == 2 and 0.42 or 0.72)
        else
            tex:Hide()
        end
    end

    -- Header ornament under the title.
    d.headerLeft:Show()
    d.headerRight:Show()
    d.headerRune:Show()
    d.headerLeft:SetAlpha(style == 1 and 0.30 or 0.48)
    d.headerRight:SetAlpha(style == 1 and 0.30 or 0.48)
    d.headerRune:SetSize(style == 1 and 9 or (style == 2 and 13 or 16),
                         style == 1 and 9 or (style == 2 and 13 or 16))
    d.headerRune:SetAlpha(style == 1 and 0.42 or (style == 2 and 0.70 or 0.92))

    if style == 3 then
        d.headerLeft2:Show()
        d.headerRight2:Show()
    else
        d.headerLeft2:Hide()
        d.headerRight2:Hide()
    end

    -- Tiny side runes looked too busy in the full package.
    -- Keep the major corner ornaments and section symbols instead.
    for _, tex in ipairs(d.edgeRunes) do
        tex:Hide()
    end
end

local function ApplyDecorSection(s)
    local style = GetOptionsDecorStyle()

    s.label:ClearAllPoints()
    if style >= 2 then
        s.icon:Show()
        s.icon:SetSize(style == 2 and 16 or 18, style == 2 and 16 or 18)
        s.icon:SetAlpha(style == 2 and 0.82 or 1.0)
        s.label:SetPoint(
            s.point, s.relativeTo, s.relativePoint,
            (s.x or 0) + 22, s.y or 0
        )
    else
        s.icon:Hide()
        s.label:SetPoint(
            s.point, s.relativeTo, s.relativePoint,
            s.x or 0, s.y or 0
        )
    end
end

local function ApplyDecorDivider(d)
    local style = GetOptionsDecorStyle()

    d.left1:Show()
    d.right1:Show()
    d.rune:Show()

    if style == 1 then
        d.left1:SetAlpha(0.18)
        d.right1:SetAlpha(0.18)
        d.rune:SetSize(7, 7)
        d.rune:SetAlpha(0.28)
        d.left2:Hide()
        d.right2:Hide()
        d.endLeft:Hide()
        d.endRight:Hide()
    elseif style == 2 then
        d.left1:SetAlpha(0.32)
        d.right1:SetAlpha(0.32)
        d.rune:SetSize(12, 12)
        d.rune:SetAlpha(0.66)
        d.left2:Hide()
        d.right2:Hide()
        d.endLeft:Hide()
        d.endRight:Hide()
    else
        d.left1:SetAlpha(0.42)
        d.right1:SetAlpha(0.42)
        d.rune:SetSize(16, 16)
        d.rune:SetAlpha(0.95)
        d.left2:Show()
        d.right2:Show()

        -- Full package keeps the strong center rune and double line,
        -- but drops the tiny line-end symbols to avoid visual clutter.
        d.endLeft:Hide()
        d.endRight:Hide()
    end
end

local function ApplyDecorButton(b)
    if not b then return end
    if b.cfGrimoireSkin then b.cfGrimoireSkin(); return end
    local style = GetOptionsDecorStyle()

    if style == 3 and not b.cfNoDecor then
        b.cfDecorIcon:Show()
        b.cfDecorIcon:SetAlpha(0.90)
        b.cfLabel:ClearAllPoints()
        b.cfLabel:SetPoint("CENTER", 7, 0)
        b:SetBackdropBorderColor(
            THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 0.88
        )
    else
        b.cfDecorIcon:Hide()
        b.cfLabel:ClearAllPoints()
        b.cfLabel:SetPoint("CENTER")
        b:SetBackdropBorderColor(
            THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 1
        )
    end
end

local function ApplyOptionsDecorStyleAll()
    for _, frame in ipairs(decoratedFrames) do
        ApplyDecorFrame(frame)
    end

    for _, section in ipairs(decoratedSections) do
        ApplyDecorSection(section)
    end

    for _, divider in ipairs(decoratedDividers) do
        ApplyDecorDivider(divider)
    end

    for _, button in ipairs(decoratedButtons) do
        ApplyDecorButton(button)
    end
end

local function AttachDecorFrame(frame, title)
    if not frame or frame.cfDecor then
        return
    end

    local d = {}
    frame.cfDecor = d
    d.title = title

    if title then
        local point, relativeTo, relativePoint, x, y = title:GetPoint(1)
        d.titlePoint = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end

    local raven = frame:CreateTexture(nil, "ARTWORK")
    raven:SetTexture(DECOR_RAVEN)
    raven:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -3)
    d.raven = raven

    local watermark = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    watermark:SetTexture(DECOR_RAVEN)
    watermark:SetBlendMode("ADD")
    d.watermark = watermark

    d.corners = {}
    local cornerAnchors = {
        {"TOPLEFT", 4, -4},
        {"TOPRIGHT", -4, -4},
        {"BOTTOMLEFT", 4, 4},
        {"BOTTOMRIGHT", -4, 4},
    }

    for i, c in ipairs(cornerAnchors) do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(DECOR_CORNER)
        tex:SetPoint(c[1], frame, c[1], c[2], c[3])
        d.corners[i] = tex
    end

    local function MakeLine(y, left)
        local t = frame:CreateTexture(nil, "ARTWORK")
        t:SetHeight(1)
        t:SetColorTexture(THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 1)
        if left then
            t:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, y)
            t:SetPoint("TOPRIGHT", frame, "TOP", -11, y)
        else
            t:SetPoint("TOPLEFT", frame, "TOP", 11, y)
            t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, y)
        end
        return t
    end

    d.headerLeft = MakeLine(-40, true)
    d.headerRight = MakeLine(-40, false)
    d.headerLeft2 = MakeLine(-43, true)
    d.headerRight2 = MakeLine(-43, false)

    local headerRune = frame:CreateTexture(nil, "OVERLAY")
    headerRune:SetTexture(DECOR_CORNER)
    headerRune:SetPoint("CENTER", frame, "TOP", 0, -40)
    d.headerRune = headerRune

    d.edgeRunes = {}
    local edgeDefs = {
        {"LEFT",  frame, "LEFT",  4,  155, DECOR_RUNE_GREEN},
        {"LEFT",  frame, "LEFT",  4,    0, DECOR_RUNE_VIOLET},
        {"LEFT",  frame, "LEFT",  4, -155, DECOR_RUNE_GOLD},
        {"RIGHT", frame, "RIGHT", -4,  155, DECOR_RUNE_PURPLE},
        {"RIGHT", frame, "RIGHT", -4,    0, DECOR_RUNE_BLUE},
        {"RIGHT", frame, "RIGHT", -4, -155, DECOR_RUNE_RED},
    }
    for i, e in ipairs(edgeDefs) do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(e[6])
        tex:SetSize(13, 13)
        tex:SetPoint(e[1], e[2], e[3], e[4], e[5])
        d.edgeRunes[i] = tex
    end

    decoratedFrames[#decoratedFrames + 1] = frame
    ApplyDecorFrame(frame)
end

local function RegisterDecorSection(frame, label, texturePath)
    if not frame or not label then return end

    local point, relativeTo, relativePoint, x, y = label:GetPoint(1)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(texturePath)
    icon:SetPoint("RIGHT", label, "LEFT", -4, 0)

    local s = {
        frame = frame,
        label = label,
        icon = icon,
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }

    decoratedSections[#decoratedSections + 1] = s
    ApplyDecorSection(s)
end

local function RegisterDecorDivider(frame, y, texturePath)
    local d = {}

    local function MakeHalfLine(yOffset, left)
        local t = frame:CreateTexture(nil, "ARTWORK")
        t:SetHeight(1)
        t:SetColorTexture(THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 1)
        if left then
            t:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y + yOffset)
            t:SetPoint("TOPRIGHT", frame, "TOP", -12, y + yOffset)
        else
            t:SetPoint("TOPLEFT", frame, "TOP", 12, y + yOffset)
            t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, y + yOffset)
        end
        return t
    end

    d.left1 = MakeHalfLine(0, true)
    d.right1 = MakeHalfLine(0, false)
    d.left2 = MakeHalfLine(-3, true)
    d.right2 = MakeHalfLine(-3, false)

    d.rune = frame:CreateTexture(nil, "OVERLAY")
    d.rune:SetTexture(texturePath or DECOR_CORNER)
    d.rune:SetPoint("CENTER", frame, "TOP", 0, y)

    d.endLeft = frame:CreateTexture(nil, "OVERLAY")
    d.endLeft:SetTexture(DECOR_CORNER)
    d.endLeft:SetSize(9, 9)
    d.endLeft:SetPoint("LEFT", frame, "LEFT", 16, y)

    d.endRight = frame:CreateTexture(nil, "OVERLAY")
    d.endRight:SetTexture(DECOR_CORNER)
    d.endRight:SetSize(9, 9)
    d.endRight:SetPoint("RIGHT", frame, "RIGHT", -16, y)

    decoratedDividers[#decoratedDividers + 1] = d
    ApplyDecorDivider(d)
end

local function CreateCloseButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.055, 0.043, 0.027, 1)
    local x = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("|cffd8b15a×|r")
    b:SetScript("OnEnter", function() bg:SetColorTexture(0.16, 0.115, 0.05, 1) end)
    b:SetScript("OnLeave", function() bg:SetColorTexture(0.055, 0.043, 0.027, 1) end)
    b:SetScript("OnClick", function() parent:Hide() end)
    return b
end

local function CreateActionButton(parent, text, noDecor)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b.cfNoDecor = noDecor == true
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    b:SetBackdropColor(0.055, 0.043, 0.027, 0.98)
    b:SetBackdropBorderColor(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 1)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(CF.T(text))
    b.cfLabel = fs
    b.cfTextKey = text
    b.CFLocaleRefresh = function()
        fs:SetText(CF.T(b.cfTextKey))
    end
    CF.RegisterLocaleUpdater(b.CFLocaleRefresh)

    decorButtonCounter = decorButtonCounter + 1
    local decorIcon = b:CreateTexture(nil, "ARTWORK")
    decorIcon:SetSize(14, 14)
    decorIcon:SetPoint("LEFT", b, "LEFT", 7, 0)
    decorIcon:SetTexture(
        DECOR_BUTTON_ICONS[
            ((decorButtonCounter - 1) % #DECOR_BUTTON_ICONS) + 1
        ]
    )
    decorIcon:Hide()
    b.cfDecorIcon = decorIcon
    decoratedButtons[#decoratedButtons + 1] = b
    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.095, 0.073, 0.038, 1)
        self:SetBackdropBorderColor(THEME_GOLD_HI_R, THEME_GOLD_HI_G, THEME_GOLD_HI_B, 1)
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.055, 0.043, 0.027, 0.98)
        self:SetBackdropBorderColor(THEME_GOLD_DIM_R, THEME_GOLD_DIM_G, THEME_GOLD_DIM_B, 1)
    end)
    ApplyDecorButton(b)
    return b
end

local function CreateHistoryFrame()
    if historyFrame then return end
    historyFrame = CreateFrame("Frame", "CursiveForeverHistoryFrame", UIParent, "BackdropTemplate")
    historyFrame:SetSize(520, 520)
    historyFrame:SetPoint("CENTER")
    historyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    historyFrame:SetMovable(true)
    historyFrame:SetClampedToScreen(true)
    historyFrame:EnableMouse(true)
    historyFrame:RegisterForDrag("LeftButton")
    historyFrame:Hide()
    ApplyDarkBackdrop(historyFrame, 1.0)
    historyFrame:SetBackdropColor(0.010, 0.004, 0.016, 1.0)
    AddWitchCorners(historyFrame)
    AddInnerGlow(historyFrame)
    CreateCloseButton(historyFrame)
    historyFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    historyFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local title = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -13)
    title:SetText("|cffdfbd62" .. CF.T("VERSION_HISTORY") .. "|r")
    AttachDecorFrame(historyFrame, title)

    local subtitle = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOPRIGHT", historyFrame, "TOPRIGHT", -42, -17)
    subtitle:SetText(VERSION .. "  •  by Leandarh Valinor")

    local clientInfo = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    clientInfo:SetPoint("TOPLEFT", 20, -45)
    clientInfo:SetSize(480, 16)
    clientInfo:SetJustifyH("LEFT")
    clientInfo:SetText(CF.T("TESTED_ON") .. " "..(CF.Client and CF.Client.build.clientName or "WoW Forever").." " .. GetTestedClientBuildString())

    local readingPanel = CreateFrame("Frame", nil, historyFrame, "BackdropTemplate")
    readingPanel:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 12, -68)
    readingPanel:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -12, 12)
    readingPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    readingPanel:SetBackdropColor(0.006, 0.004, 0.010, 1.0)
    readingPanel:SetBackdropBorderColor(0.30, 0.09, 0.42, 1.0)

    local scroll = CreateFrame("ScrollFrame", nil, historyFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -78)
    scroll:SetPoint("BOTTOMRIGHT", -36, 20)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(450, 900)
    scroll:SetScrollChild(child)
    local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT")
    text:SetPoint("TOPRIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(3)
    text:SetText(CF.GetChangelog())
    C_Timer.After(0, function() child:SetHeight(math.max(900, text:GetStringHeight()+20)) end)
    historyFrame.CFLocaleRefresh = function()
        title:SetText("|cffdfbd62" .. CF.T("VERSION_HISTORY") .. "|r")
        clientInfo:SetText(CF.T("TESTED_ON") .. " "..(CF.Client and CF.Client.build.clientName or "WoW Forever").." " .. GetTestedClientBuildString())
        text:SetText(CF.GetChangelog())
        C_Timer.After(0, function()
            child:SetHeight(math.max(900, text:GetStringHeight() + 20))
        end)
    end
    CF.RegisterLocaleUpdater(historyFrame.CFLocaleRefresh)

    table.insert(UISpecialFrames, "CursiveForeverHistoryFrame")
end

local function ShowHistory()
    CreateHistoryFrame()

    -- Always force history above the options window.
    historyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    if optionsFrame then
        historyFrame:SetFrameLevel(math.max(100, optionsFrame:GetFrameLevel() + 50))
    else
        historyFrame:SetFrameLevel(100)
    end

    historyFrame:Show()
    historyFrame:Raise()
end

function CF.PerformanceResultText(result)
    if result == "kill" then
        return CF.T("PERFORMANCE_KILL")
    elseif result == "wipe" then
        return CF.T("PERFORMANCE_WIPE")
    end
    return CF.T("PERFORMANCE_RESULT_FIGHT")
end

function CF.PerformanceResultRune(result)
    if result == "kill" then
        return DECOR_RUNE_GREEN
    elseif result == "wipe" then
        return DECOR_RUNE_PURPLE
    end
    return DECOR_RUNE_GOLD
end

function CF.PerformanceFormatHistoryLine(snapshot)
    if not snapshot then
        return CF.T("PERFORMANCE_UNKNOWN_FIGHT")
    end

    return tostring(snapshot.name or CF.T("PERFORMANCE_UNKNOWN_FIGHT"))
        .. "\n|cffaaa28f"
        .. CF.FormatPerformanceDuration(snapshot.duration)
        .. " · " .. CF.FormatPerformanceDate(snapshot.endEpoch)
        .. " · " .. CF.FormatPerformanceEndTime(snapshot.endEpoch)
        .. "|r"
end

-- Coordinates describe the writing surfaces inside the approved gold frames.
CF.PERFORMANCE_CARD_LAYOUT = {
    { x=68,  y=-439, width=162, height=238 },
    { x=280, y=-463, width=150, height=246 },
    { x=486, y=-449, width=202, height=290 },
    { x=759, y=-463, width=154, height=246 },
    { x=977, y=-439, width=150, height=238 },
}

function CF.PerformanceCreateCard(parent, slotIndex)
    local isCenter = slotIndex == 3
    local layout = CF.PERFORMANCE_CARD_LAYOUT[slotIndex]
    local card = CreateFrame("Button", nil, parent)
    card:EnableMouse(true)
    card:RegisterForClicks("LeftButtonUp")
    card:SetHitRectInsets(0,0,0,0)
    card:SetScript("OnClick",function(self)
        if self.sourceIndex and not self.notRecorded then CF.ShowPerformanceDetails(self.sourceIndex) end
    end)
    card:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText(CF.T(self.notRecorded and "CARDS_NOT_RECORDED" or "DETAIL_OPEN"),0.95,0.83,0.51); GameTooltip:Show()
    end)
    card:SetScript("OnLeave",function() GameTooltip:Hide() end)
    card:SetScript("OnHide",function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    card.isCenter = isCenter
    card:SetSize(layout.width, layout.height)
    -- Card faces are blank artwork now; live values need no covering rectangle.

    local iconFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
    iconFrame:EnableMouse(false)
    iconFrame:SetSize(isCenter and 76 or 60, isCenter and 76 or 60)
    iconFrame:SetPoint("TOP", 0, -3)
    iconFrame:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",
        edgeSize=2,
    })
    iconFrame:SetBackdropColor(0.008, 0.008, 0.010, 1)
    iconFrame:SetBackdropBorderColor(0.36, 0.92, 0.30, 0.92)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.icon = icon

    local name = card:CreateFontString(nil, "OVERLAY", isCenter and "GameFontNormalLarge" or "GameFontNormal")
    name:SetPoint("TOPLEFT", 5, isCenter and -84 or -68)
    name:SetPoint("TOPRIGHT", -5, isCenter and -84 or -68)
    name:SetHeight(isCenter and 32 or 26)
    name:SetJustifyH("CENTER")
    name:SetJustifyV("TOP")
    name:SetTextColor(0.94, 0.84, 0.56)
    card.name = name

    local function MakePair(labelY, labelTemplate, valueTemplate)
        local label = card:CreateFontString(nil, "OVERLAY", labelTemplate or "GameFontDisableSmall")
        label:SetPoint("TOPLEFT", 9, labelY)
        label:SetWidth(isCenter and 78 or (layout.width - 78))
        label:SetHeight(16)
        label:SetWordWrap(false)
        label:SetJustifyH("LEFT")
        label:SetTextColor(0.72, 0.72, 0.72)
        local value = card:CreateFontString(nil, "OVERLAY", valueTemplate or "GameFontNormal")
        value:SetPoint("TOPRIGHT", -9, labelY + 1)
        value:SetWidth(isCenter and 96 or 56)
        value:SetHeight(isCenter and 24 or 20)
        value:SetWordWrap(false)
        value:SetJustifyH("RIGHT")
        return label, value
    end

    local base = isCenter and -142 or -116
    local step = isCenter and 30 or 24

    card.uptimeLabel, card.uptime = MakePair(base, "GameFontDisableSmall", isCenter and "GameFontNormalLarge" or "GameFontNormal")
    card.uptime:SetTextColor(0.46, 1.00, 0.35)

    card.damageLabel, card.damage = MakePair(base-step, "GameFontDisableSmall", isCenter and "GameFontNormalHuge" or "GameFontNormalLarge")
    card.damage:SetTextColor(0.95, 0.80, 0.40)

    card.castLabel, card.castValue = MakePair(base-(step*2))
    card.castValue:SetTextColor(0.96, 0.96, 0.96)

    card.refreshLabel, card.refreshValue = MakePair(base-(step*3))
    card.refreshValue:SetTextColor(0.96, 0.96, 0.96)

    card.shareLabel, card.share = MakePair(base-(step*4), "GameFontDisableSmall", isCenter and "GameFontNormalLarge" or "GameFontNormal")
    card.share:SetTextColor(0.92, 0.92, 0.92)

    local state = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    state:SetPoint("TOP", 0, isCenter and -118 or -96)
    state:SetHeight(14)
    state:SetWordWrap(false)
    state:SetWidth(card:GetWidth()-12)
    state:SetJustifyH("CENTER")
    card.state = state

    return card
end

function CF.PerformanceUpdateCard(card, slot)
    if not card then return end
    if not slot then card.effectKey=nil; card:Hide(); return end
    card.effectKey=slot.key; card.notRecorded=slot.notRecorded

    card:Show()
    card.icon:SetTexture(slot.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    card.name:SetText(slot.name or "DoT")
    card.uptimeLabel:SetText(CF.T("PERFORMANCE_UPTIME"))
    card.damageLabel:SetText(CF.T("PERFORMANCE_DAMAGE"))
    card.castLabel:SetText(CF.T("PERFORMANCE_CASTS"))
    card.refreshLabel:SetText(CF.T("PERFORMANCE_REFRESHES"))
    card.shareLabel:SetText(CF.T("PERFORMANCE_DAMAGE_SHARE"))

    if slot.notRecorded then
        card.uptime:SetText("—"); card.damage:SetText("—"); card.share:SetText("—")
        card.castValue:SetText("—"); card.refreshValue:SetText("—")
        card.state:SetText(CF.T("CARDS_NOT_RECORDED")); return
    end

    if slot.passive then
        card.uptime:SetText("—")
        card.state:SetText(CF.T(slot.damageOnly and "PERFORMANCE_DAMAGE_ONLY" or "PERFORMANCE_PASSIVE"))
    elseif slot.coverageUnknown or (tonumber(slot.unconfirmed) or 0)>0 then
        card.uptime:SetText("—")
        card.state:SetText(CF.T(CF.PerformanceAuraWasRestricted(slot)
            and "PERFORMANCE_CLIENT_RESTRICTED" or "PERFORMANCE_UNCONFIRMED"))
    elseif slot.used==nil then
        card.uptime:SetText("—")
        card.state:SetText(CF.T("PERFORMANCE_UNCONFIRMED"))
    elseif not slot.used then
        card.uptime:SetText("0.0 %")
        card.state:SetText(CF.T("PERFORMANCE_UNUSED"))
    else
        local uptime = math.max(0, math.min(100, tonumber(slot.uptime) or 0))
        card.uptime:SetText(CF.TF("PERFORMANCE_CARD_UPTIME_FMT", uptime))
        card.state:SetText("")
    end

    card.damage:SetText(slot.damage~=nil and ((slot.damagePartial and "≥ " or "")..CF.FormatPerformanceNumber(slot.damage)) or "—")
    card.share:SetText(slot.damageShare~=nil and CF.TF("PERFORMANCE_CARD_SHARE_FMT",slot.damageShare) or "—")
    card.castValue:SetText(slot.passive and "—" or tostring(tonumber(slot.casts) or 0))
    card.refreshValue:SetText((slot.passive or slot.coverageUnknown or (tonumber(slot.unconfirmed) or 0)>0)
        and "—" or tostring(tonumber(slot.refreshes) or 0))
end

-- One reusable detail overlay; its data always follows the selected archive fight.
function CF.PerformanceDetailLabel(target)
    return (target.name or CF.T("PROTECTED_TARGET")) .. " · #" .. tostring(target.order or 0)
end

function CF.PerformanceDetailSeconds(value)
    return string.format("%.1f s", tonumber(value) or 0)
end

function CF.PerformanceDetailTime(value)
    local seconds = math.max(0,tonumber(value) or 0)
    return string.format("%d:%04.1f",math.floor(seconds/60),seconds%60)
end

function CF.PerformanceDetailTotals(details, selected)
    local total = { relevant=0, covered=0, casts=0, refreshes=0, noTick=0,
        discarded=0, lostTicks=0, actualTicks=0, referenceTicks=0,
        knownCasts=0, unknownCasts=0, unconfirmed=0, notApplied=0, clientRestricted=0 }
    for _, target in ipairs(details.targets or {}) do
        if not selected or selected==target.key then
            for key in pairs(total) do total[key] = total[key] + (tonumber(target[key]) or 0) end
        end
    end
    return total
end

function CF.PerformanceDetailHasUnassignedCasts(details)
    for _,target in ipairs(details.targets or {}) do
        if (target.key=="unconfirmed-target" or target.reliable==false)
            and (tonumber(target.unconfirmed) or 0)>0 then return true end
    end
    return false
end

function CF.ShowStatusReport()
    local f=CF.statusReportFrame
    if not f then
        f=CreateFrame("Frame","CursiveForeverStatusReportFrame",UIParent,"BackdropTemplate")
        CF.statusReportFrame=f
        f:SetSize(820,580)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(250)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",function(self) self:StartMoving() end)
        f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
        f:SetBackdropColor(0.025,0.024,0.019,1)
        f:SetBackdropBorderColor(THEME_GOLD_DIM_R,THEME_GOLD_DIM_G,THEME_GOLD_DIM_B,1)
        CreateCloseButton(f)
        f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT",20,-18)
        f.title:SetSize(755,24); f.title:SetJustifyH("LEFT")
        f.hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.hint:SetPoint("TOPLEFT",20,-50)
        f.hint:SetSize(770,36); f.hint:SetJustifyH("LEFT")
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",20,-100)
        scroll:SetPoint("BOTTOMRIGHT",-40,64)
        local edit=CreateFrame("EditBox",nil,scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(GameFontHighlightSmall)
        edit:SetWidth(750)
        edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed",function() f:Hide() end)
        scroll:SetScrollChild(edit)
        f.scroll=scroll; f.edit=edit
        f.measure=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.measure:SetWidth(750)
        f.measure:Hide()
        local select=CreateActionButton(f,"STATUS_COPY")
        select:SetSize(180,28); select:SetPoint("BOTTOMLEFT",20,18)
        select:SetScript("OnClick",function()
            edit:SetFocus(); edit:HighlightText()
        end)
        local refresh=CreateActionButton(f,"STATUS_REFRESH")
        refresh:SetSize(160,28); refresh:SetPoint("LEFT",select,"RIGHT",16,0)
        refresh:SetScript("OnClick",function() CF.ShowStatusReport() end)
        f.selectButton=select; f.refreshButton=refresh
        f:SetScript("OnHide",function() edit:ClearFocus() end)
        table.insert(UISpecialFrames,"CursiveForeverStatusReportFrame")
        CF.RegisterLocaleUpdater(function()
            if f:IsShown() then CF.ShowStatusReport() end
        end)
    end
    f:SetScale(math.min(1,(UIParent:GetWidth()-40)/820,(UIParent:GetHeight()-40)/580))
    f.title:SetText(CF.TF("STATUS_HEADER",VERSION))
    f.hint:SetText(CF.T("STATUS_COPY_HINT"))
    local report=CF.BuildStatusReport()
    f.measure:SetText(report)
    f.edit:SetText(report)
    f.edit:SetHeight(math.max(420,f.measure:GetStringHeight()+24))
    f.edit:SetCursorPosition(0)
    f.edit:ClearFocus()
    f.scroll:SetVerticalScroll(0)
    f:Show(); f:Raise()
end

function CF.CreatePerformanceDetailsFrame()
    if CF.performanceDetailsFrame then return end
    local parent = CF.performanceFrame
    if not parent then return end
    local f = CreateFrame("Frame","CursiveForeverPerformanceDetailsFrame",parent,"BackdropTemplate")
    CF.performanceDetailsFrame = f
    f:SetSize(970,584)
    f:SetPoint("TOP",parent,"TOP",0,-300)
    f:SetFrameStrata(parent:GetFrameStrata())
    f:SetFrameLevel(parent:GetFrameLevel()+20)
    f:EnableMouse(true)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2,
        insets={left=2,right=2,top=2,bottom=2}})
    f:SetBackdropColor(0.025,0.024,0.019,1)
    f:SetBackdropBorderColor(0.48,0.37,0.17,1)
    f:Hide()
    f:SetScript("OnHide",function() GameTooltip:Hide() end)

    local capLeft=f:CreateTexture(nil,"ARTWORK")
    capLeft:SetTexture(MEDIA_PATH.."PerformanceRavenInfo.tga")
    capLeft:SetPoint("TOPLEFT",0,0); capLeft:SetSize(64,64); capLeft:SetTexCoord(0,0.125,0,1)
    local capRight=f:CreateTexture(nil,"ARTWORK")
    capRight:SetTexture(MEDIA_PATH.."PerformanceRavenInfo.tga")
    capRight:SetPoint("TOPRIGHT",0,0); capRight:SetSize(64,64); capRight:SetTexCoord(0.875,1,0,1)
    local rail=f:CreateTexture(nil,"ARTWORK")
    rail:SetTexture(MEDIA_PATH.."PerformanceRavenInfo.tga")
    rail:SetPoint("TOPLEFT",capLeft,"TOPRIGHT",0,0)
    rail:SetPoint("BOTTOMRIGHT",capRight,"BOTTOMLEFT",0,0); rail:SetTexCoord(0.125,0.875,0,1)
    f.headerArt={capLeft,rail,capRight}

    local function Label(owner,x,y,width,height,template)
        local text=owner:CreateFontString(nil,"OVERLAY",template or "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT",x,y); text:SetSize(width,height)
        text:SetJustifyH("LEFT"); text:SetJustifyV("TOP")
        text:SetTextColor(0.82,0.80,0.73)
        return text
    end
    f.title=Label(f,66,-17,802,22,"GameFontNormalLarge")
    f.title:SetTextColor(0.95,0.83,0.51)
    f.subtitle=Label(f,66,-35,802,16)
    f.subtitle:SetWordWrap(false)
    local close=CreateFrame("Button",nil,f)
    close:SetSize(40,40); close:SetPoint("TOPRIGHT",-18,-12)
    close:SetFrameLevel(f:GetFrameLevel()+3)
    close:RegisterForClicks("LeftButtonUp"); close:SetHitRectInsets(0,0,0,0); close:EnableMouse(true)
    local art=close:CreateTexture(nil,"ARTWORK")
    art:SetTexture(MEDIA_PATH.."PerformanceRavenClose.tga"); art:SetAllPoints(close)
    close:SetScript("OnClick",function() f:Hide() end)
    close:SetScript("OnEnter",function(self)
        art:SetAlpha(0.8); GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(CF.T("DETAIL_BACK")); GameTooltip:Show()
    end)
    close:SetScript("OnLeave",function() art:SetAlpha(1); GameTooltip:Hide() end)
    close:SetScript("OnHide",function() art:SetAlpha(1) end)
    f.closeButton=close
    f.summary=Label(f,24,-78,922,20)
    f.summary:SetWordWrap(false)
    f.metrics={}
    for i,key in ipairs({"DETAIL_NO_TICK","DETAIL_DISCARDED","DETAIL_LOST"}) do
        local x=24+(i-1)*310
        local label=Label(f,x,-109,292,18)
        label:SetTextColor(0.72,0.70,0.62)
        local value=Label(f,x,-133,292,28,"GameFontNormalLarge")
        value:SetTextColor(0.94,0.79,0.42)
        f.metrics[i]={label=label,value=value,key=key}
    end
    f.notice=Label(f,24,-165,922,18)
    f.notice:SetTextColor(0.75,0.72,0.62)
    f.notice:SetWordWrap(false)

    f.allButton=CreateActionButton(f,"DETAIL_ALL_TARGETS")
    f.allButton:SetSize(268,26); f.allButton:SetPoint("TOPLEFT",24,-192)
    f.allButton:SetScript("OnClick",function()
        f.selectedTarget=nil; f.eventScroll:SetVerticalScroll(0); CF.PerformanceRefreshDetails()
    end)
    f.eventTitle=Label(f,326,-190,612,22,"GameFontNormal")
    f.columns={}
    for i,col in ipairs({{0,48,"DETAIL_TIME"},{52,144,"DETAIL_TARGET"},
        {202,108,"DETAIL_ACTION"},{316,68,"DETAIL_REMAINING"},{392,188,"DETAIL_PROGRESS"}}) do
        local label=Label(f,326+col[1],-217,col[2],16)
        label:SetTextColor(0.63,0.61,0.54); label:SetWordWrap(false)
        f.columns[i]={label=label,key=col[3],x=col[1],width=col[2]}
    end
    local function Scroll(x,width)
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",x,-240); scroll:SetSize(width,240)
        local child=CreateFrame("Frame",nil,scroll)
        child:SetSize(width,1); child:EnableMouse(false)
        scroll:SetScrollChild(child)
        return scroll,child
    end
    f.targetScroll,f.targetChild=Scroll(24,268)
    f.eventScroll,f.eventChild=Scroll(326,584)
    f.targetRows={}; f.eventRows={}
    f.empty=Label(f,342,-295,550,100,"GameFontNormal")
    f.empty:SetJustifyH("CENTER"); f.empty:SetTextColor(0.75,0.72,0.63)
    f.footer=Label(f,24,-501,922,38)
    f.footer:SetTextColor(0.66,0.64,0.58)
    f.help=CreateActionButton(f,"DETAIL_METHOD")
    f.help:SetSize(220,24); f.help:SetPoint("BOTTOMLEFT",24,12)
    f.help:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText(CF.T("DETAIL_METHOD"),0.95,0.83,0.51)
        GameTooltip:AddLine(CF.T("DETAIL_METHOD_TIP"),0.86,0.84,0.77,true); GameTooltip:Show()
    end)
    f.help:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f.help:SetScript("OnClick",f.help:GetScript("OnEnter"))
    f.tickSummary=Label(f,262,-548,670,20)
    f.tickSummary:SetJustifyH("RIGHT")
    table.insert(UISpecialFrames,"CursiveForeverPerformanceDetailsFrame")
end

function CF.PerformanceRefreshDetails()
    local f=CF.performanceDetailsFrame
    if not f or not f:IsShown() then return end
    local history=CF.GetPerformanceHistory()
    local snapshot=history[CF.performanceSelectedIndex]
    local slot=snapshot and snapshot.slots and snapshot.slots[f.slotIndex]
    if snapshot and f.effectKey then
        slot=nil
        for _, candidate in ipairs(snapshot.slots or {}) do
            if candidate.key==f.effectKey then slot=candidate; break end
        end
    end
    if not slot or CF.IsPerformanceCollapsed() then f:Hide(); return end
    if f.snapshot~=snapshot then
        f.snapshot=snapshot; f.selectedTarget=nil
        f.targetScroll:SetVerticalScroll(0); f.eventScroll:SetVerticalScroll(0)
    end
    f.title:SetText((slot.name or "DoT").." · "..CF.T("DETAIL_TITLE"))
    f.subtitle:SetText((snapshot.name or CF.T("PERFORMANCE_UNKNOWN_FIGHT")).." · "
        ..CF.FormatPerformanceDuration(snapshot.duration).." · "..CF.FormatPerformanceDate(snapshot.endEpoch))
    for _,metric in ipairs(f.metrics) do metric.label:SetText(CF.T(metric.key)); metric.value:SetText("—") end
    for _,column in ipairs(f.columns) do column.label:SetText(CF.T(column.key)) end
    -- CreateActionButton owns a localised label; the normal locale updater refreshes it.
    f.footer:SetText(CF.T("DETAIL_FOOTER"))
    f.tickSummary:SetText("")
    f.summary:SetText(""); f.notice:SetText("")
    for _,row in ipairs(f.targetRows) do row:Hide() end
    for _,row in ipairs(f.eventRows) do row:Hide() end
    f.empty:Hide()
    if slot.damageOnly then
        f.eventTitle:SetText(CF.T("DETAIL_EVENTS")); f.notice:SetText(CF.T("PERFORMANCE_DAMAGE_ONLY"))
        f.empty:SetText(CF.T("DETAIL_DAMAGE_ONLY")); f.empty:Show()
        f.footer:SetText(""); f.targetChild:SetHeight(1); f.eventChild:SetHeight(1); return
    end
    local detail=slot.details
    if type(detail)~="table" or detail.version~=CF.PERFORMANCE_DETAIL_VERSION then
        f.eventTitle:SetText(CF.T("DETAIL_EVENTS")); f.empty:SetText(CF.T("DETAIL_LEGACY")); f.empty:Show()
        f.notice:SetText(CF.T("DETAIL_LEGACY_SHORT"))
        f.targetChild:SetHeight(1); f.eventChild:SetHeight(1)
        return
    end
    local targets={}
    for _,target in ipairs(detail.targets or {}) do targets[target.key]=target end
    if f.selectedTarget and not targets[f.selectedTarget] then f.selectedTarget=nil end
    local total=CF.PerformanceDetailTotals(detail,f.selectedTarget)
    -- Unknown-target attempts can belong to any of the named rows. Their
    -- absence from a named row is not evidence of zero coverage on that enemy.
    -- Derive this at display time so existing 1.4.5 archives are corrected too.
    local unassigned=CF.PerformanceDetailHasUnassignedCasts(detail)
    local percent=total.relevant>0 and string.format("%.1f %%",100*total.covered/total.relevant) or "—"
    f.summary:SetText(CF.TF("DETAIL_SUMMARY_FMT",percent,total.covered,total.relevant,
        math.max(0,total.relevant-total.covered),total.casts,total.refreshes))
    if detail.observationGap then
        f.summary:SetText(CF.T("DETAIL_OBSERVATION_GAP"))
    elseif unassigned then
        f.summary:SetText(CF.T("DETAIL_TARGET_UNCONFIRMED_SUMMARY"))
    elseif detail.coverageUnknown and total.unconfirmed==0 then
        f.summary:SetText(CF.T("DETAIL_UNRECORDED_SUMMARY"))
    elseif total.unconfirmed>0 then
        f.summary:SetText(CF.TF("DETAIL_UNCONFIRMED_SUMMARY",total.casts,total.notApplied,total.unconfirmed))
    elseif (tonumber(slot.applicationTracking) or 0)>=2 then
        f.summary:SetText(f.summary:GetText()..CF.TF("DETAIL_NOT_APPLIED_COUNT",total.notApplied))
    end
    if slot.passive then f.summary:SetText(CF.T("DETAIL_PASSIVE")) end
    local canModel=total.knownCasts>0 and total.unknownCasts==0 and total.unconfirmed==0
        and not unassigned and not detail.coverageUnknown and not detail.targetsTruncated and not detail.coverageIncomplete
    if canModel then
        f.metrics[1].value:SetText(tostring(total.noTick))
        f.metrics[2].value:SetText(CF.PerformanceDetailSeconds(total.discarded))
        f.metrics[3].value:SetText(tostring(total.lostTicks))
        f.tickSummary:SetText(CF.TF("DETAIL_TICKS_FMT",total.actualTicks,total.referenceTicks))
    end
    if detail.observationGap then
        f.notice:SetText(CF.T("DETAIL_PARTIAL"))
    elseif unassigned then
        f.notice:SetText(CF.T("DETAIL_TARGET_UNCONFIRMED_NOTICE"))
    elseif detail.coverageUnknown or total.unconfirmed>0 then
        local restricted=total.clientRestricted>0 or (not f.selectedTarget and CF.PerformanceAuraWasRestricted(slot))
        f.notice:SetText(CF.T(restricted and "DETAIL_CLIENT_RESTRICTED_NOTICE" or "DETAIL_UNCONFIRMED_NOTICE"))
    elseif detail.targetsTruncated or detail.coverageIncomplete then
        f.notice:SetText(CF.T("DETAIL_PARTIAL"))
    elseif not canModel then
        f.notice:SetText(CF.T(total.casts==0 and "DETAIL_NO_CASTS" or "DETAIL_NO_MODEL"))
    else
        f.notice:SetText(CF.T("DETAIL_MODEL_NOTICE"))
    end
    for i,target in ipairs(detail.targets or {}) do
        local row=f.targetRows[i]
        if not row then
            row=CreateFrame("Button",nil,f.targetChild,"BackdropTemplate")
            row:SetSize(268,43); row:SetPoint("TOPLEFT",0,-(i-1)*47)
            row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
            row:EnableMouse(true); row:RegisterForClicks("LeftButtonUp")
            row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            row.name:SetPoint("TOPLEFT",7,-6); row.name:SetSize(183,15)
            row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
            row.uptime=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            row.uptime:SetPoint("TOPRIGHT",-7,-6); row.uptime:SetSize(63,15); row.uptime:SetJustifyH("RIGHT")
            row.coverage=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
            row.coverage:SetPoint("TOPLEFT",7,-24); row.coverage:SetSize(252,14)
            row.coverage:SetJustifyH("LEFT"); row.coverage:SetWordWrap(false)
            row:SetScript("OnClick",function(self)
                f.selectedTarget=self.target.key; f.eventScroll:SetVerticalScroll(0); CF.PerformanceRefreshDetails()
            end)
            row:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(CF.PerformanceDetailLabel(self.target))
                GameTooltip:AddLine(CF.T("DETAIL_TARGET_TIP"),0.8,0.8,0.7,true); GameTooltip:Show()
            end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end)
            f.targetRows[i]=row
        end
        row.target=target
        row.name:SetText(CF.PerformanceDetailLabel(target))
        row.uptime:SetText(target.relevant>0 and string.format("%.1f %%",100*target.covered/target.relevant) or "—")
        row.coverage:SetText(CF.TF("DETAIL_COVERAGE_FMT",target.covered,target.relevant,
            math.max(0,target.relevant-target.covered)))
        if unassigned or detail.coverageUnknown or (target.unconfirmed or 0)>0 then
            row.uptime:SetText("—")
            row.coverage:SetText(CF.T((target.clientRestricted or 0)>0
                and "PERFORMANCE_CLIENT_RESTRICTED" or "PERFORMANCE_UNCONFIRMED"))
        end
        if slot.passive then
            row.uptime:SetText("—")
            row.coverage:SetText(CF.T("PERFORMANCE_PASSIVE"))
        end
        local selected=f.selectedTarget==target.key
        row:SetBackdropColor(selected and 0.13 or 0.04,selected and 0.11 or 0.038,0.025,1)
        row:SetBackdropBorderColor(selected and 0.68 or 0.22,selected and 0.51 or 0.19,0.10,1)
        row:Show()
    end
    f.targetChild:SetHeight(math.max(1,#(detail.targets or {})*47))
    local count=0
    for i=#(detail.events or {}),1,-1 do
        local event=detail.events[i]
        if not f.selectedTarget or event.target==f.selectedTarget then
            count=count+1
            local row=f.eventRows[count]
            if not row then
                row=CreateFrame("Frame",nil,f.eventChild)
                row:SetSize(584,30); row:SetPoint("TOPLEFT",0,-(count-1)*32)
                row:EnableMouse(true)
                local bg=row:CreateTexture(nil,"BACKGROUND")
                bg:SetColorTexture(0.20,0.17,0.10,count%2==1 and 0.15 or 0.04); bg:SetAllPoints(row)
                row.cells={}
                for j,column in ipairs(f.columns) do
                    local cell=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                    cell:SetPoint("TOPLEFT",column.x,-8); cell:SetSize(column.width,16)
                    cell:SetJustifyH("LEFT"); cell:SetWordWrap(false); row.cells[j]=cell
                end
                row:SetScript("OnEnter",function(self)
                    local e=self.event
                    GameTooltip:SetOwner(self,"ANCHOR_TOP")
                    GameTooltip:SetText(self.targetLabel.." · "..CF.PerformanceDetailTime(e.at),0.95,0.83,0.51)
                    if e.kind=="unconfirmed" or e.kind=="not_applied" then
                        GameTooltip:AddLine(CF.T(e.clientRestricted and "DETAIL_CLIENT_RESTRICTED_TIP"
                            or "DETAIL_APPLICATION_TIP"),0.85,0.83,0.75,true)
                    else
                        GameTooltip:AddLine(CF.TF("DETAIL_EVENT_TIP",e.duration or 0,e.remaining or 0),0.85,0.83,0.75,true)
                    end
                    if e.interval then
                        GameTooltip:AddLine(CF.TF("DETAIL_INTERVAL_FMT",e.interval),0.85,0.83,0.75,true)
                        if e.noTick then GameTooltip:AddLine(CF.T("DETAIL_NO_TICK_TIP"),0.95,0.65,0.40,true) end
                    end
                    if e.gap and e.gap>0 then GameTooltip:AddLine(CF.TF("DETAIL_GAP_FMT",e.gap),0.85,0.83,0.75,true) end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave",function() GameTooltip:Hide() end)
                f.eventRows[count]=row
            end
            row.event=event
            row.targetLabel=targets[event.target] and CF.PerformanceDetailLabel(targets[event.target]) or CF.T("PROTECTED_TARGET")
            row.cells[1]:SetText(CF.PerformanceDetailTime(event.at))
            row.cells[2]:SetText(row.targetLabel)
            row.cells[3]:SetText(CF.T(event.clientRestricted and "PERFORMANCE_CLIENT_RESTRICTED"
                or "DETAIL_ACTION_"..string.upper(event.kind or "apply")))
            row.cells[4]:SetText(event.kind=="refresh" and CF.PerformanceDetailSeconds(event.remaining) or "—")
            row.cells[5]:SetText(event.discarded and CF.PerformanceDetailSeconds(event.discarded) or "—")
            row:Show()
        end
    end
    f.eventTitle:SetText(CF.TF("DETAIL_EVENTS_FMT",count))
    if (detail.eventTotal or 0)>#(detail.events or {}) then
        f.eventTitle:SetText(CF.TF("DETAIL_EVENTS_LIMIT_FMT",#detail.events,detail.eventTotal,count))
    end
    f.eventChild:SetHeight(math.max(1,count*32))
    if count==0 then f.empty:SetText(CF.T("DETAIL_NO_EVENTS")); f.empty:Show() end
end

function CF.ShowPerformanceDetails(slotIndex)
    if not CF.performanceFrame or CF.IsPerformanceCollapsed() then return end
    CF.CreatePerformanceDetailsFrame()
    local f=CF.performanceDetailsFrame
    f.slotIndex=slotIndex; f.selectedTarget=nil; f.snapshot=nil
    local snapshot=CF.GetPerformanceHistory()[CF.performanceSelectedIndex]
    f.effectKey=snapshot and snapshot.slots and snapshot.slots[slotIndex] and snapshot.slots[slotIndex].key
    f:Show(); CF.PerformanceRefreshDetails()
end

function CF.PerformanceApplyArchiveState()
    local f = CF.performanceFrame
    if not f or not f.historyPanel or not f.archiveTab then return end

    local collapsed = CF.IsPerformanceCollapsed()
    local open = CF.IsPerformanceArchiveOpen() and not collapsed
    -- One control owns both the visible arrow and its hit rectangle. Compact
    -- mode hides AND disables it without changing the saved archive preference.
    if collapsed then
        f.archiveTab:EnableMouse(false)
        f.archiveTab:Hide()
    else
        f.archiveTab:Show()
        f.archiveTab:EnableMouse(true)
    end
    if open then
        f.historyPanel:Show()
        f.archiveTab.art:SetTexCoord(0, 1, 0, 1)
    else
        f.historyPanel:Hide()
        f.archiveTab.art:SetTexCoord(1, 0, 0, 1)
    end
end

function CF.PerformanceApplyCollapsedState()
    local f = CF.performanceFrame
    if not f then return end

    local collapsed = CF.IsPerformanceCollapsed()
    if collapsed then
        if CF.performanceDetailsFrame then CF.performanceDetailsFrame:Hide() end
        f:SetSize(680, 344)
        f.performanceArt:Hide()
        f.compactArt:Show()
        f.cardsPanel:Hide()
        f.historyPanel:Hide()
        f.note:Hide()
        f.dataNote:Hide()
        f.notesPanel:Hide()
        f.fightHeader:ClearAllPoints()
        f.fightHeader:SetPoint("TOP", 0, -254)
        f.fightHeader:SetSize(510, 50)
        f.fightHeader:SetBackdropColor(0.010,0.015,0.012,1)
        f.fightHeader:SetBackdropBorderColor(0.46,0.39,0.18,0.85)
        f.summary:ClearAllPoints()
        f.summary:SetPoint("BOTTOM", 0, 9)
        f.summary:SetWidth(650)
        f.summary:SetHeight(28)
        f.collapseButton:ClearAllPoints()
        f.collapseButton:SetPoint("TOPRIGHT", -50, -8)
        f.closeButton:ClearAllPoints()
        f.closeButton:SetPoint("TOPRIGHT", -8, -4)
        f.closeButton:SetSize(34, 34)
        f.collapseButton.text:SetText("+")
        f.infoPanel:ClearAllPoints()
        f.infoPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 8, 0)
        f.infoPanel:SetSize(578, 64)
        f.versionLabel:SetWidth(466)
        f.clientLabel:SetWidth(466)
    else
        f:SetSize(1220, 962)
        f.performanceArt:Show()
        f.compactArt:Hide()
        f.cardsPanel:Show()
        f.note:Show()
        f.dataNote:Show()
        f.notesPanel:Show()
        f.fightHeader:ClearAllPoints()
        f.fightHeader:SetPoint("TOPLEFT", 361, -347)
        f.fightHeader:SetSize(345, 46)
        f.fightHeader:SetBackdropColor(0.010,0.015,0.012,0)
        f.fightHeader:SetBackdropBorderColor(0.46,0.39,0.18,0)
        f.summary:ClearAllPoints()
        f.summary:SetPoint("TOP", f.notesPanel, "TOP", 0, -25)
        f.summary:SetWidth(876)
        f.summary:SetHeight(16)
        f.collapseButton:ClearAllPoints()
        f.collapseButton:SetPoint("TOPRIGHT", -115, -214)
        f.closeButton:ClearAllPoints()
        f.closeButton:SetPoint("TOPLEFT", 1118, -206)
        f.closeButton:SetSize(40, 40)
        f.collapseButton.text:SetText("–")
        -- Keep release/author/client details off the feathers and chains. The
        -- extra footer space leaves the artwork and encounter rows untouched.
        f.infoPanel:ClearAllPoints()
        f.infoPanel:SetPoint("BOTTOM", f, "BOTTOM", 0, 4)
        f.infoPanel:SetSize(760, 64)
        f.versionLabel:SetWidth(648)
        f.clientLabel:SetWidth(648)
    end
    f.versionLabel:SetText(VERSION .. " · " .. CF.T("PERFORMANCE_CREATED_BY"))
    f.clientLabel:SetText(CF.T("TESTED_ON") .. " "..(CF.Client and CF.Client.build.clientName or "WoW Forever").." " .. GetTestedClientBuildString())
end

function CF.CreatePerformanceFrame()
    if CF.performanceFrame then return end

    local f = CreateFrame("Frame", "CursiveForeverPerformanceFrame", UIParent)
    CF.performanceFrame = f
    f:SetSize(1220, 962)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(140)
    if f.SetClipsChildren then f:SetClipsChildren(false) end
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()
    f:SetScript("OnDragStart", function(self)
        self.cfDragging = true
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.cfDragging = nil
        CF.SavePerformancePosition()
    end)
    f:SetScript("OnHide", function(self)
        if self.cfDragging then
            self:StopMovingOrSizing()
            self.cfDragging = nil
            CF.SavePerformancePosition()
        end
        if CF.performanceLayoutOptionsFrame then CF.performanceLayoutOptionsFrame:Hide() end
        if CF.performanceDetailsFrame then CF.performanceDetailsFrame:Hide() end
    end)

    -- Decorative art cannot own a click or obscure the controls' hit regions.
    local artLayer = CreateFrame("Frame", nil, f)
    artLayer:SetAllPoints(f)
    artLayer:SetFrameLevel(f:GetFrameLevel())
    artLayer:EnableMouse(false)
    if artLayer.SetClipsChildren then artLayer:SetClipsChildren(false) end
    f.artLayer = artLayer

    local performanceArt = artLayer:CreateTexture(nil, "BACKGROUND")
    performanceArt:SetTexture(DECOR_PERFORMANCE_MAIN)
    -- Both wings extend beyond the card area. The right margin also preserves
    -- the outer feather tip instead of ending the canvas inside the feather.
    -- This entire artwork belongs to the raven, never to the archive.
    performanceArt:SetPoint("TOPLEFT", artLayer, "TOPLEFT", -420, 0)
    performanceArt:SetSize(1700, 895)
    performanceArt:SetTexCoord(0, 1, 0, 1)
    performanceArt:SetBlendMode("BLEND")
    performanceArt:SetVertexColor(1, 1, 1, 1)
    performanceArt:SetAlpha(1)
    f.performanceArt = performanceArt

    local compactArt = artLayer:CreateTexture(nil, "BACKGROUND")
    compactArt:SetTexture(DECOR_PERFORMANCE_COMPACT)
    -- The compact asset contains the full raven silhouette with transparent
    -- margins. Display its entire canvas; never crop wing tips or claw ends.
    compactArt:SetPoint("TOP", artLayer, "TOP", 0, -66)
    compactArt:SetSize(680, 180)
    compactArt:SetTexCoord(0, 1, 0, 1)
    compactArt:SetBlendMode("BLEND")
    compactArt:SetVertexColor(1, 1, 1, 1)
    compactArt:SetAlpha(1)
    compactArt:Hide()
    f.compactArt = compactArt

    local closeButton = CreateFrame("Button", nil, f)
    closeButton:SetFrameStrata(f:GetFrameStrata())
    closeButton:SetFrameLevel(f:GetFrameLevel() + 10)
    closeButton:RegisterForClicks("LeftButtonUp")
    closeButton:SetHitRectInsets(0, 0, 0, 0)
    closeButton:EnableMouse(true)
    closeButton:SetSize(40, 40)
    closeButton:SetPoint("TOPLEFT", 1118, -206)
    local closeArt=closeButton:CreateTexture(nil,"ARTWORK")
    closeArt:SetTexture(MEDIA_PATH .. "PerformanceRavenClose.tga")
    closeArt:SetAllPoints(closeButton)
    closeArt:SetBlendMode("BLEND")
    closeButton.art=closeArt
    closeButton:SetScript("OnEnter",function() closeArt:SetAlpha(0.8) end)
    closeButton:SetScript("OnLeave",function() closeArt:SetAlpha(1) end)
    closeButton:SetScript("OnHide",function() closeArt:SetAlpha(1) end)
    closeButton:SetScript("OnClick",function() f:Hide() end)
    f.closeButton=closeButton

    local collapseButton = CreateFrame("Button", nil, f, "BackdropTemplate")
    collapseButton:SetFrameStrata(f:GetFrameStrata())
    collapseButton:SetFrameLevel(f:GetFrameLevel() + 10)
    collapseButton:RegisterForClicks("LeftButtonUp")
    collapseButton:SetHitRectInsets(0, 0, 0, 0)
    collapseButton:EnableMouse(true)
    collapseButton:SetSize(25, 25)
    collapseButton:SetPoint("TOPRIGHT", -35, -9)
    collapseButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    collapseButton:SetBackdropColor(0.025,0.020,0.018,0.96)
    collapseButton:SetBackdropBorderColor(0.60,0.43,0.18,0.90)
    local collapseText = collapseButton:CreateFontString(nil,"OVERLAY","GameFontNormal")
    collapseText:SetPoint("CENTER")
    collapseText:SetTextColor(0.94,0.80,0.42)
    collapseButton.text = collapseText
    collapseButton:SetScript("OnClick", function() CF.TogglePerformanceCollapsed() end)
    collapseButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:SetText(CF.T(CF.IsPerformanceCollapsed() and "PERFORMANCE_EXPAND" or "PERFORMANCE_COLLAPSE"),1,0.82,0.35)
        GameTooltip:Show()
    end)
    collapseButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.collapseButton = collapseButton

    -- Raven Archive, separate artwork so it can disappear without shrinking the raven.
    local historyPanel = CreateFrame("Frame", nil, f)
    historyPanel:SetFrameLevel(f:GetFrameLevel() + 1)
    historyPanel:EnableMouse(false)
    historyPanel:SetSize(355, 620)
    historyPanel:SetPoint("TOPRIGHT", f, "TOPLEFT", 13, -118)
    f.historyPanel = historyPanel

    local archiveArt = historyPanel:CreateTexture(nil,"BACKGROUND")
    archiveArt:SetTexture(DECOR_PERFORMANCE_ARCHIVE)
    archiveArt:SetAllPoints()
    archiveArt:SetBlendMode("BLEND")
    archiveArt:SetVertexColor(1, 1, 1, 1)
    archiveArt:SetAlpha(1)

    -- Archive artwork contains only the empty panel and ornamental frame.

    local historyTitle = historyPanel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    historyTitle:SetPoint("TOP", 0, -99)
    historyTitle:SetSize(247,22)
    historyTitle:SetJustifyH("CENTER")
    historyTitle:SetWordWrap(false)
    historyTitle:SetTextColor(0.93,0.80,0.48)
    f.historyTitle = historyTitle

    local historyCount = historyPanel:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    historyCount:SetPoint("TOP", 0, -126)
    historyCount:SetSize(247,14)
    historyCount:SetJustifyH("CENTER")
    historyCount:SetWordWrap(false)
    historyCount:SetTextColor(0.72,0.72,0.66)
    f.historyCount = historyCount

    local scroll = CreateFrame("ScrollFrame", nil, historyPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 29, -154)
    scroll:SetPoint("BOTTOMRIGHT", -42, 143)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(280)
    child:SetHeight(CF.PERFORMANCE_HISTORY_MAX * 42)
    scroll:SetScrollChild(child)
    f.historyRows = {}

    for i=1,CF.PERFORMANCE_HISTORY_MAX do
        local row = CreateFrame("Button", nil, child, "BackdropTemplate")
        row:SetSize(278,38)
        row:SetPoint("TOPLEFT",0,-((i-1)*42))
        row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        row:SetBackdropColor(0.025,0.035,0.033,0.96)
        row:SetBackdropBorderColor(0.17,0.25,0.21,0.85)
        row.index=i
        local resultRune=row:CreateTexture(nil,"ARTWORK")
        resultRune:SetSize(25,25); resultRune:SetPoint("LEFT",6,0); row.resultRune=resultRune
        local rt=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        rt:SetPoint("TOPLEFT",36,-4); rt:SetPoint("BOTTOMRIGHT",-28,3); rt:SetJustifyH("LEFT"); rt:SetJustifyV("MIDDLE"); row.text=rt
        local del=CreateFrame("Button",nil,row); del:SetSize(22,22); del:SetPoint("RIGHT",-2,0)
        local d=del:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); d:SetPoint("CENTER",0,1); d:SetText("|cffd98266×|r")
        del:SetScript("OnClick",function() CF.PerformanceDeleteHistoryIndex(row.index) end)
        del:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(CF.T("PERFORMANCE_DELETE_TIP"),1,0.82,0.35,1,true); GameTooltip:Show() end)
        del:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("OnClick",function(self) CF.performanceSelectedIndex=self.index; CF.PerformanceRefreshFrame() end)
        f.historyRows[i]=row
    end

    local clear = CreateActionButton(historyPanel,"PERFORMANCE_CLEAR")
    clear:SetSize(246,34); clear:SetPoint("TOPLEFT",58,-493)
    clear:SetScript("OnClick",function() CF.PerformanceClearHistory() end)
    f.clearButton=clear

    -- One button owns the original ornamental double-chevron artwork. Mirroring
    -- its texture changes direction without adding a second arrow or hotspot.
    local archiveTab = CreateFrame("Button",nil,f)
    archiveTab:SetFrameStrata(f:GetFrameStrata())
    archiveTab:SetFrameLevel(f:GetFrameLevel() + 10)
    archiveTab:SetSize(47,95)
    archiveTab:SetPoint("TOPLEFT",f,"TOPLEFT",21,-216)
    archiveTab:RegisterForClicks("LeftButtonUp")
    archiveTab:SetHitRectInsets(0,0,0,0)
    archiveTab:EnableMouse(true)
    local archiveTabArt=archiveTab:CreateTexture(nil,"ARTWORK")
    archiveTabArt:SetTexture(MEDIA_PATH .. "PerformanceRavenToggle.tga")
    archiveTabArt:SetAllPoints(archiveTab)
    archiveTabArt:SetBlendMode("BLEND")
    archiveTab.art=archiveTabArt
    archiveTab:SetScript("OnClick",function() CF.TogglePerformanceArchive() end)
    archiveTab:SetScript("OnEnter",function(self)
        self.art:SetAlpha(0.8)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(CF.T(CF.IsPerformanceArchiveOpen() and "PERFORMANCE_ARCHIVE_CLOSE" or "PERFORMANCE_ARCHIVE_OPEN"),1,0.82,0.35)
        GameTooltip:Show()
    end)
    local function ArchiveTabLeave(self)
        self.art:SetAlpha(1)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    archiveTab:SetScript("OnLeave",ArchiveTabLeave)
    archiveTab:SetScript("OnHide",ArchiveTabLeave)
    f.archiveTab=archiveTab

    -- Live encounter text is placed inside the now-blank engraved plaque.
    local fightHeader=CreateFrame("Frame",nil,f,"BackdropTemplate")
    fightHeader:SetFrameLevel(f:GetFrameLevel() + 2)
    fightHeader:EnableMouse(false)
    fightHeader:SetSize(345,46); fightHeader:SetPoint("TOPLEFT",361,-347)
    fightHeader:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    fightHeader:SetBackdropColor(0.010,0.015,0.012,0); fightHeader:SetBackdropBorderColor(0.46,0.39,0.18,0)
    f.fightHeader=fightHeader
    local selectedResult=fightHeader:CreateTexture(nil,"ARTWORK"); selectedResult:SetSize(22,22); selectedResult:SetPoint("LEFT",2,0); f.selectedResult=selectedResult
    local selectedTitle=fightHeader:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); selectedTitle:SetPoint("TOP",9,-4); selectedTitle:SetSize(300,20); selectedTitle:SetWordWrap(false); selectedTitle:SetJustifyH("CENTER"); selectedTitle:SetTextColor(0.96,0.84,0.52); f.selectedTitle=selectedTitle
    local selectedMeta=fightHeader:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); selectedMeta:SetPoint("TOP",selectedTitle,"BOTTOM",0,-2); selectedMeta:SetSize(300,14); selectedMeta:SetWordWrap(false); selectedMeta:SetJustifyH("CENTER"); f.selectedMeta=selectedMeta

    local cardsPanel=CreateFrame("Frame",nil,f)
    cardsPanel:SetFrameLevel(f:GetFrameLevel() + 1)
    cardsPanel:EnableMouse(false)
    cardsPanel:SetPoint("TOPLEFT",0,0); cardsPanel:SetAllPoints(f)
    f.cardsPanel=cardsPanel; f.cards={}
    for i=1,5 do f.cards[i]=CF.PerformanceCreateCard(cardsPanel,i) end

    local textLayer=CreateFrame("Frame",nil,f)
    textLayer:SetAllPoints(f)
    textLayer:SetFrameLevel(f:GetFrameLevel() + 3)
    textLayer:EnableMouse(false)
    f.textLayer=textLayer

    -- A matching ornamental plaque frames the metadata. Fixed end caps retain
    -- their proportions in both views; only the quiet central rails stretch.
    -- All three decorative textures belong to one mouse-transparent frame.
    local infoPanel=CreateFrame("Frame",nil,textLayer)
    infoPanel:SetFrameLevel(f:GetFrameLevel() + 4)
    infoPanel:EnableMouse(false)
    f.infoPanel=infoPanel

    local infoLeft=infoPanel:CreateTexture(nil,"BACKGROUND")
    infoLeft:SetTexture(MEDIA_PATH .. "PerformanceRavenInfo.tga")
    infoLeft:SetPoint("TOPLEFT",0,0)
    infoLeft:SetSize(64,64)
    infoLeft:SetTexCoord(0,0.125,0,1)
    infoLeft:SetBlendMode("BLEND")
    local infoRight=infoPanel:CreateTexture(nil,"BACKGROUND")
    infoRight:SetTexture(MEDIA_PATH .. "PerformanceRavenInfo.tga")
    infoRight:SetPoint("TOPRIGHT",0,0)
    infoRight:SetSize(64,64)
    infoRight:SetTexCoord(0.875,1,0,1)
    infoRight:SetBlendMode("BLEND")
    local infoMiddle=infoPanel:CreateTexture(nil,"BACKGROUND")
    infoMiddle:SetTexture(MEDIA_PATH .. "PerformanceRavenInfo.tga")
    infoMiddle:SetPoint("TOPLEFT",infoLeft,"TOPRIGHT",0,0)
    infoMiddle:SetPoint("BOTTOMRIGHT",infoRight,"BOTTOMLEFT",0,0)
    infoMiddle:SetTexCoord(0.125,0.875,0,1)
    infoMiddle:SetBlendMode("BLEND")
    f.infoArt={infoLeft,infoMiddle,infoRight}

    local versionLabel=infoPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    versionLabel:SetPoint("TOP",0,-20)
    versionLabel:SetHeight(14)
    versionLabel:SetJustifyH("CENTER")
    versionLabel:SetWordWrap(false)
    versionLabel:SetTextColor(0.74,0.72,0.66)
    versionLabel:SetShadowColor(0,0,0,1)
    versionLabel:SetShadowOffset(1,-1)
    f.versionLabel=versionLabel

    local clientLabel=infoPanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    clientLabel:SetPoint("TOP",0,-36)
    clientLabel:SetHeight(14)
    clientLabel:SetJustifyH("CENTER")
    clientLabel:SetWordWrap(false)
    clientLabel:SetTextColor(0.66,0.67,0.62)
    clientLabel:SetShadowColor(0,0,0,1)
    clientLabel:SetShadowOffset(1,-1)
    f.clientLabel=clientLabel

    -- Reuse the existing ornamental plaque. Its opaque inner face carries all
    -- three lines; it accepts no clicks and stays above the metadata plaque.
    local notesPanel=CreateFrame("Frame",nil,f)
    notesPanel:SetFrameLevel(f:GetFrameLevel()+2)
    notesPanel:EnableMouse(false)
    notesPanel:SetPoint("TOP",f,"TOP",0,-804)
    notesPanel:SetSize(1060,88)
    local notesLeft=notesPanel:CreateTexture(nil,"BACKGROUND")
    notesLeft:SetTexture(MEDIA_PATH.."PerformanceRavenInfo.tga")
    notesLeft:SetPoint("TOPLEFT",0,0); notesLeft:SetSize(88,88)
    notesLeft:SetTexCoord(0,0.125,0,1); notesLeft:SetBlendMode("BLEND")
    local notesRight=notesPanel:CreateTexture(nil,"BACKGROUND")
    notesRight:SetTexture(MEDIA_PATH.."PerformanceRavenInfo.tga")
    notesRight:SetPoint("TOPRIGHT",0,0); notesRight:SetSize(88,88)
    notesRight:SetTexCoord(0.875,1,0,1); notesRight:SetBlendMode("BLEND")
    local notesMiddle=notesPanel:CreateTexture(nil,"BACKGROUND")
    notesMiddle:SetTexture(MEDIA_PATH.."PerformanceRavenInfo.tga")
    notesMiddle:SetPoint("TOPLEFT",notesLeft,"TOPRIGHT",0,0)
    notesMiddle:SetPoint("BOTTOMRIGHT",notesRight,"BOTTOMLEFT",0,0)
    notesMiddle:SetTexCoord(0.125,0.875,0,1); notesMiddle:SetBlendMode("BLEND")
    f.notesPanel=notesPanel

    local summary=textLayer:CreateFontString(nil,"OVERLAY","GameFontNormal")
    summary:SetPoint("BOTTOM",0,47); summary:SetWidth(900); summary:SetJustifyH("CENTER"); summary:SetTextColor(0.90,0.90,0.88); f.summary=summary
    local note=textLayer:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    note:SetPoint("TOP",notesPanel,"TOP",0,-43); note:SetSize(876,14)
    note:SetJustifyH("CENTER"); note:SetWordWrap(false)
    note:SetTextColor(0.82,0.82,0.76); note:SetText(CF.T("PERFORMANCE_COVERAGE_NOTE")); f.note=note
    local dataNote=textLayer:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    dataNote:SetPoint("TOP",notesPanel,"TOP",0,-58); dataNote:SetSize(876,14)
    dataNote:SetJustifyH("CENTER"); dataNote:SetWordWrap(false)
    dataNote:SetTextColor(0.82,0.82,0.76); f.dataNote=dataNote
    for _,label in ipairs({summary,note,dataNote}) do
        label:SetShadowColor(0,0,0,1); label:SetShadowOffset(1,-1)
    end
    f.empty=textLayer:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.empty:SetPoint("CENTER",0,-40); f.empty:SetTextColor(0.88,0.76,0.48)

    f.CFLocaleRefresh=function()
        f.note:SetText(CF.T("PERFORMANCE_COVERAGE_NOTE"))
        CF.PerformanceApplyCollapsedState()
        CF.PerformanceRefreshFrame()
    end
    CF.RegisterLocaleUpdater(f.CFLocaleRefresh)
    CF.PerformanceApplyCollapsedState(); CF.PerformanceApplyArchiveState()
    table.insert(UISpecialFrames,"CursiveForeverPerformanceFrame")
end

function CF.PerformanceRefreshFrame()
    local f = CF.performanceFrame
    if not f then
        return
    end

    local history = CF.GetPerformanceHistory()
    local count = #history
    f.historyTitle:SetText(CF.T("PERFORMANCE_MAX"))
    f.historyCount:SetText(CF.TF("PERFORMANCE_HISTORY_COUNT_FMT", count))

    for i, row in ipairs(f.historyRows or {}) do
        local snapshot = history[i]
        row.index = i

        if snapshot then
            row:Show()
            row.text:SetText(CF.PerformanceFormatHistoryLine(snapshot))
            row.resultRune:SetTexture(CF.PerformanceResultRune(snapshot.result))
            row.resultRune:SetAlpha(0.92)

            if i == CF.performanceSelectedIndex then
                row:SetBackdropColor(0.105, 0.045, 0.125, 1)
                row:SetBackdropBorderColor(0.42, 0.92, 0.32, 0.90)
            else
                row:SetBackdropColor(0.030, 0.018, 0.038, 0.96)
                row:SetBackdropBorderColor(0.21, 0.15, 0.25, 0.80)
            end
        else
            row:Hide()
        end
    end

    if count == 0 then
        if CF.performanceDetailsFrame then CF.performanceDetailsFrame:Hide() end
        f.empty:Show()
        f.empty:SetText(CF.T("PERFORMANCE_EMPTY"))
        f.selectedTitle:SetText("")
        f.selectedMeta:SetText("")
        f.selectedResult:Hide()
        f.summary:SetText("")
        f.dataNote:SetText(CF.T("PERFORMANCE_SLASH_HINT"))
        for _, card in ipairs(f.cards or {}) do
            card:Hide()
        end
        return
    end

    if CF.performanceSelectedIndex < 1 then
        CF.performanceSelectedIndex = 1
    elseif CF.performanceSelectedIndex > count then
        CF.performanceSelectedIndex = count
    end

    local snapshot = history[CF.performanceSelectedIndex]
    if not snapshot then
        return
    end

    f.empty:Hide()
    f.selectedTitle:SetText(snapshot.name or CF.T("PERFORMANCE_UNKNOWN_FIGHT"))
    f.selectedMeta:SetText(
        CF.FormatPerformanceDuration(snapshot.duration)
        .. " · " .. CF.FormatPerformanceDate(snapshot.endEpoch)
        .. " · " .. CF.FormatPerformanceEndTime(snapshot.endEpoch)
        .. " · " .. CF.PerformanceResultText(snapshot.result)
    )
    f.selectedResult:SetTexture(CF.PerformanceResultRune(snapshot.result))
    f.selectedResult:Show()

    local slots = CF.GetPerformanceDisplaySlots(snapshot)
    for i=1,5 do
        local card=f.cards[i]
        local pos=CF.PERFORMANCE_CARD_LAYOUT[i]
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT",f.cardsPanel,"TOPLEFT",pos.x,pos.y)
        CF.PerformanceUpdateCard(card,slots[i])
        card.sourceIndex=nil
        for index, recorded in ipairs(snapshot.slots or {}) do
            if recorded==slots[i] then card.sourceIndex=index; break end
        end
    end

    f.summary:SetText(
        CF.TF(
            "PERFORMANCE_SUMMARY_FMT",
            CF.T("PERFORMANCE_TOTAL_DAMAGE"),
            snapshot.totalDamage~=nil and ((snapshot.damagePartial and "≥ " or "")..CF.FormatPerformanceNumber(snapshot.totalDamage)) or "—",
            CF.T("PERFORMANCE_ALIVE_TIME"),
            snapshot.alivePercent~=nil and string.format("%.1f %%",snapshot.alivePercent) or "—",
            CF.T("PERFORMANCE_DEATHS"),
            tonumber(snapshot.deaths) or 0
        )
    )

    if snapshot.damagePartial or snapshot.coverageIncomplete then
        f.dataNote:SetText(CF.T("PERFORMANCE_PARTIAL_NOTE"))
    elseif snapshot.damageMeterAvailable then
        f.dataNote:SetText(
            CF.TF("PERFORMANCE_BOSS_TARGETS_FMT", tonumber(snapshot.relevantTargets or snapshot.bossTargets) or 0)
            .. "  ·  " .. CF.T("PERFORMANCE_DATA_NOTE")
        )
    else
        f.dataNote:SetText(
            CF.T("PERFORMANCE_DAMAGE_UNAVAILABLE")
            .. "  ·  " .. CF.T("PERFORMANCE_DATA_NOTE")
        )
    end
    CF.PerformanceRefreshDetails()
end

function CF.ShowPerformance()
    if CF.Client and not CF.Client.supportsAnalysis then CF.ClientFeatureNotice(); return end
    if optionsFrame then optionsFrame:Hide() end
    CF.CreatePerformanceFrame()
    CF.PerformanceApplyCollapsedState()
    CF.PerformanceRefreshFrame()
    CF.PerformanceApplyArchiveState()
    CF.PerformanceApplyWindowPlacement()
    CF.performanceFrame:Show()
    CF.performanceFrame:Raise()
end

function CF.ShowPerformanceLayoutOptions()
    if CF.Client and not CF.Client.supportsAnalysis then CF.ClientFeatureNotice(); return end
    CF.ShowPerformance()
    local f = CF.performanceLayoutOptionsFrame
    if not f then
        f = CreateFrame("Frame", "CursiveForeverPerformanceLayoutOptions", UIParent, "BackdropTemplate")
        CF.performanceLayoutOptionsFrame = f
        f:SetSize(370, 220)
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -32, -80)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(200)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        ApplyDarkBackdrop(f, 1)
        CreateCloseButton(f)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetSize(320, 20)
        title:SetJustifyH("LEFT")
        title:SetTextColor(0.88, 0.76, 0.48)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 18, -44)
        hint:SetSize(332, 36)
        hint:SetJustifyH("LEFT")
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 20, -91)
        local slider = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 22, -113)
        slider:SetWidth(322)
        slider:SetMinMaxValues(0.50, 1.20)
        slider:SetValueStep(0.05)
        if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
        if slider.Low then slider.Low:SetText("50%") end
        if slider.High then slider.High:SetText("120%") end
        if slider.Text then slider.Text:SetText("") end
        slider:SetScript("OnValueChanged", function(self, value)
            if self.cfRefreshing then return end
            CF.SetPerformanceScale(value)
            label:SetText(CF.TF("PERFORMANCE_SCALE_FMT", math.floor(CF.GetPerformanceScale() * 100 + 0.5)))
        end)
        local saved = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        saved:SetPoint("TOPLEFT", 18, -146)
        saved:SetSize(332, 30)
        saved:SetJustifyH("LEFT")
        local center = CreateActionButton(f, "PERFORMANCE_CENTER")
        center:SetSize(230, 28)
        center:SetPoint("BOTTOMLEFT", 18, 12)
        center:SetScript("OnClick", CF.ResetPerformancePosition)
        local resetScale = CreateActionButton(f, "100 %")
        resetScale:SetSize(90, 28)
        resetScale:SetPoint("LEFT", center, "RIGHT", 10, 0)
        resetScale:SetScript("OnClick", function()
            CF.SetPerformanceScale(1)
            f:CFRefresh()
        end)
        f.scaleSlider = slider
        f.CFRefresh = function()
            title:SetText(CF.T("PERFORMANCE_LAYOUT_TITLE"))
            hint:SetText(CF.T("PERFORMANCE_LAYOUT_HINT"))
            saved:SetText(CF.T("PERFORMANCE_LAYOUT_SAVED"))
            local value = CF.GetPerformanceScale()
            slider.cfRefreshing = true
            slider:SetValue(value)
            slider.cfRefreshing = nil
            label:SetText(CF.TF("PERFORMANCE_SCALE_FMT", math.floor(value * 100 + 0.5)))
        end
        CF.RegisterLocaleUpdater(f.CFRefresh)
        table.insert(UISpecialFrames, "CursiveForeverPerformanceLayoutOptions")
    end
    f:CFRefresh()
    f:Show()
    f:Raise()
end

local function CreateMatrixCheckbox(parent, x, y, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    cb.CFRefresh = function()
        cb:SetChecked(getter())
    end
    return cb
end

-- One reusable filter matrix for all classes; old commands remain aliases.
function CF.RefreshClassFilterFrame()
    local f = filterFrame
    if not f then return end
    local catalog = CF.GetClassFilterCatalog(f.classFile)
    local storage = CF.GetClassFilterStorage(f.classFile)
    f.title:SetText("|cffdfbd62" .. CF.TF("CLASS_FILTER_TITLE",CF.GetClassDisplayName(f.classFile)) .. "|r")
    f.note:SetText(CF.T("FILTER_NOTE"))
    f.hSpell:SetText(CF.T("DEBUFF")); f.hSolo:SetText(CF.T("SOLO"))
    f.hDungeon:SetText(CF.T("DUNGEON")); f.hRaid:SetText(CF.T("RAID"))
    f.hint:SetText(CF.T("DESCRIPTION_HINT"))
    for _, row in ipairs(f.rows) do row:Hide() end
    for i, spell in ipairs(catalog) do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Frame",nil,f.child,"BackdropTemplate")
            row:SetSize(650,36); row:SetPoint("TOPLEFT",0,-((i-1)*38))
            row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
            row:SetBackdropColor(i%2==0 and 0.060 or 0.040,0.034,0.025,1)
            row.icon = row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(28,28); row.icon:SetPoint("LEFT",7,0)
            row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
            row.label = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            row.label:SetPoint("LEFT",43,0); row.label:SetWidth(385); row.label:SetJustifyH("LEFT")
            row.hover = CreateFrame("Button",nil,row)
            row.hover:SetPoint("TOPLEFT",4,-2); row.hover:SetPoint("BOTTOMRIGHT",-205,2)
            row.hover:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(row.displayName,0.95,0.83,0.51)
                GameTooltip:AddLine(row.description or CF.T("NO_DESCRIPTION"),1,1,1,true); GameTooltip:Show()
            end)
            row.hover:SetScript("OnLeave",function() GameTooltip:Hide() end)
            row.controls = {}
            for c, context in ipairs(FILTER_CONTEXTS) do
                local contextKey = context
                local cb = CreateMatrixCheckbox(row,488+(c-1)*75,-6,
                    function() return CF.GetClassFilterStorage(f.classFile)[row.spellKey][contextKey] ~= false end,
                    function(value)
                        CF.GetClassFilterStorage(f.classFile)[row.spellKey][contextKey] = value
                        ApplySpellFiltersToAllRows()
                    end)
                row.controls[#row.controls+1] = cb
            end
            f.rows[i] = row
        end
        local name, icon, description = GetSpellDisplayInfo(spell)
        row.spellKey = spell.key; row.displayName = name or spell.fallback
        row.description = description and description ~= "" and description or nil
        row.label:SetText(row.displayName); row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        storage[spell.key] = storage[spell.key] or {}
        for _, cb in ipairs(row.controls) do cb:CFRefresh() end
        row:Show()
    end
    f.child:SetHeight(math.max(1,#catalog*38))
end

local function CreateSpellFilterFrame()
    if filterFrame then return end
    local f = CreateFrame("Frame","CursiveForeverSpellFilterFrame",UIParent,"BackdropTemplate")
    filterFrame = f; f.rows = {}; f.classFile = CF.GetPerformanceClassFile()
    f:SetSize(720,640); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(130)
    f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:Hide()
    ApplyDarkBackdrop(f,1); AddWitchCorners(f); AddInnerGlow(f); CreateCloseButton(f)
    f:SetScript("OnDragStart",function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    f.title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.title:SetPoint("TOPLEFT",16,-13)
    AttachDecorFrame(f,f.title)
    f.note = f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f.note:SetPoint("TOPLEFT",18,-43); f.note:SetSize(675,40); f.note:SetJustifyH("LEFT"); f.note:SetJustifyV("TOP")
    local header = CreateFrame("Frame",nil,f,"BackdropTemplate")
    header:SetPoint("TOPLEFT",14,-87); header:SetPoint("TOPRIGHT",-14,-87); header:SetHeight(30)
    header:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); header:SetBackdropColor(0.080,0.060,0.032,1)
    f.hSpell = header:CreateFontString(nil,"OVERLAY","GameFontNormal"); f.hSpell:SetPoint("LEFT",10,0)
    for i, key in ipairs({"hSolo","hDungeon","hRaid"}) do
        f[key] = header:CreateFontString(nil,"OVERLAY","GameFontNormal")
        f[key]:SetPoint("CENTER",header,"LEFT",500+(i-1)*75,0)
    end
    f.scroll = CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT",14,-120); f.scroll:SetPoint("BOTTOMRIGHT",-34,62)
    f.child = CreateFrame("Frame",nil,f.scroll); f.child:SetSize(655,1); f.scroll:SetScrollChild(f.child)
    local allOn = CreateActionButton(f,"SHOW_ALL"); allOn:SetSize(140,30); allOn:SetPoint("BOTTOMLEFT",16,18)
    local allOff = CreateActionButton(f,"HIDE_ALL"); allOff:SetSize(150,30); allOff:SetPoint("LEFT",allOn,"RIGHT",10,0)
    local function SetAll(value)
        local storage = CF.GetClassFilterStorage(f.classFile)
        for _, spell in ipairs(CF.GetClassFilterCatalog(f.classFile)) do
            storage[spell.key] = storage[spell.key] or {}
            for _, context in ipairs(FILTER_CONTEXTS) do storage[spell.key][context] = value end
        end
        CF.RefreshClassFilterFrame(); ApplySpellFiltersToAllRows()
    end
    allOn:SetScript("OnClick",function() SetAll(true) end); allOff:SetScript("OnClick",function() SetAll(false) end)
    f.hint = f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMRIGHT",-18,23); f.hint:SetSize(280,25); f.hint:SetJustifyH("RIGHT")
    CF.RegisterLocaleUpdater(CF.RefreshClassFilterFrame)
    table.insert(UISpecialFrames,"CursiveForeverSpellFilterFrame")
end

local function ShowSpellFilter(classFile)
    if CF.OpenOptionsPage then return CF.OpenOptionsPage("combat",classFile) end
    CreateSpellFilterFrame()
    -- Button OnClick passes a frame; only explicit class tokens are accepted.
    filterFrame.classFile = type(classFile)=="string" and CF.CLASS_FILTERS[classFile] and classFile or CF.GetPerformanceClassFile()
    filterFrame.scroll:SetVerticalScroll(0)
    CF.RefreshClassSpellRanks(); CF.RefreshClassFilterFrame()
    filterFrame:Show(); filterFrame:Raise()
end

local function ShowOwlFilter()
    ShowSpellFilter("DRUID")
end

function CF.RefreshCardSelection()
    local f = CF.cardSelectionFrame
    if not f then return end
    local keys, selected, ordered = CF.GetPerformanceCardKeys(), {}, {}
    local effects = {}
    for _, effect in ipairs(CF.GetPerformanceProfile()) do effects[effect.key] = effect end
    for i, key in ipairs(keys) do selected[key]=i; ordered[#ordered+1]=effects[key] end
    for _, effect in ipairs(CF.GetPerformanceProfile()) do
        if not selected[effect.key] then ordered[#ordered+1]=effect end
    end
    f.title:SetText("|cffdfbd62"..CF.T("CARDS_TITLE").." · "..CF.GetClassDisplayName(CF.GetPerformanceClassFile()).."|r")
    f.note:SetText(CF.T("CARDS_NOTE")); f.count:SetText(CF.TF("CARDS_COUNT",#keys))
    f.hideUnused.Text:SetText(CF.T("CARDS_HIDE_UNUSED"))
    f.hideUnused:SetChecked(CF.GetPerformanceCharacterSettings().hideUnusedCards == true)
    f.hint:SetText(CF.T("CARDS_RECORDING_NOTE"))
    for _, row in ipairs(f.rows) do row:Hide() end
    for i, effect in ipairs(ordered) do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Frame",nil,f.child,"BackdropTemplate"); row:SetSize(655,42)
            row:SetPoint("TOPLEFT",0,-((i-1)*44)); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
            row:SetBackdropColor(i%2==0 and 0.06 or 0.04,0.034,0.025,1)
            row.check = CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.check:SetPoint("LEFT",2,0); row.check:SetSize(28,28); row.check.Text:SetText("")
            row.check:SetScript("OnClick",function(self)
                if not CF.SetPerformanceCardEnabled(row.effectKey,self:GetChecked() and true or false) then
                    self:SetChecked(false); f.count:SetText(CF.T("CARDS_LIMIT"))
                end
            end)
            row.icon = row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(30,30); row.icon:SetPoint("LEFT",38,0)
            row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
            row.label = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            row.label:SetPoint("LEFT",79,0); row.label:SetWidth(355); row.label:SetJustifyH("LEFT")
            row.position = row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            row.position:SetPoint("LEFT",454,0); row.position:SetWidth(68)
            row.up = CreateActionButton(row,"CARDS_MOVE_UP",true); row.up:SetSize(42,28); row.up:SetPoint("LEFT",546,0)
            row.down = CreateActionButton(row,"CARDS_MOVE_DOWN",true); row.down:SetSize(42,28); row.down:SetPoint("LEFT",594,0)
            row.up:SetScript("OnClick",function() CF.MovePerformanceCard(row.effectKey,-1) end)
            row.down:SetScript("OnClick",function() CF.MovePerformanceCard(row.effectKey,1) end)
            f.rows[i] = row
        end
        local name, _, icon = CF.GetPerformanceEffectDisplay(effect)
        local position = selected[effect.key]
        row.effectKey = effect.key; row.label:SetText(name); row.icon:SetTexture(icon)
        row.check:SetChecked(position ~= nil)
        row.position:SetText(position and tostring(position) or "—")
        row.up:SetEnabled(position ~= nil and position > 1)
        row.down:SetEnabled(position ~= nil and position < #keys)
        row.up:SetAlpha(position ~= nil and position > 1 and 1 or 0.35)
        row.down:SetAlpha(position ~= nil and position < #keys and 1 or 0.35)
        row:Show()
    end
    f.child:SetHeight(math.max(1,#ordered*44))
end

function CF.ShowCardSelection()
    local f = CF.cardSelectionFrame
    if not f then
        f = CreateFrame("Frame","CursiveForeverCardSelectionFrame",UIParent,"BackdropTemplate")
        CF.cardSelectionFrame = f; f.rows = {}
        f:SetSize(720,490); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(140)
        f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:Hide(); ApplyDarkBackdrop(f,1); AddWitchCorners(f); AddInnerGlow(f); CreateCloseButton(f)
        f:SetScript("OnDragStart",function(self) self:StartMoving() end)
        f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        f.title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT",16,-14); AttachDecorFrame(f,f.title)
        f.note = f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.note:SetPoint("TOPLEFT",18,-45); f.note:SetSize(675,40); f.note:SetJustifyH("LEFT"); f.note:SetJustifyV("TOP")
        f.scroll = CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT",16,-92); f.scroll:SetPoint("BOTTOMRIGHT",-36,116)
        f.child = CreateFrame("Frame",nil,f.scroll); f.child:SetSize(655,1); f.scroll:SetScrollChild(f.child)
        f.hideUnused = CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
        f.hideUnused:SetPoint("BOTTOMLEFT",16,73); f.hideUnused:SetSize(26,26)
        f.hideUnused:SetScript("OnClick",function(self)
            CF.GetPerformanceCharacterSettings().hideUnusedCards = self:GetChecked() and true or false
            CF.PerformanceCardSettingsChanged()
        end)
        f.hint = f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.hint:SetPoint("BOTTOMLEFT",20,42); f.hint:SetSize(670,29); f.hint:SetJustifyH("LEFT")
        f.reset = CreateActionButton(f,"CARDS_RESET"); f.reset:SetSize(190,26); f.reset:SetPoint("BOTTOMLEFT",18,12)
        f.reset:SetScript("OnClick",function()
            local settings = CF.GetPerformanceCharacterSettings(); settings.cardKeys=nil; settings.hideUnusedCards=false
            CF.PerformanceCardSettingsChanged()
        end)
        f.count = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
        f.count:SetPoint("BOTTOMRIGHT",-22,20); f.count:SetWidth(470); f.count:SetJustifyH("RIGHT")
        CF.RegisterLocaleUpdater(CF.RefreshCardSelection)
        table.insert(UISpecialFrames,"CursiveForeverCardSelectionFrame")
    end
    CF.RefreshCardSelection(); f:Show(); f:Raise()
end

local function CreateCheckbox(parent, x, y, label, tooltip, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(CF.T(label))
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(CF.T(label), 1, 0.82, 0.35)
        if tooltip then GameTooltip:AddLine(CF.T(tooltip), 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    cb.CFRefresh = function() cb:SetChecked(getter()) end
    cb.CFLocaleRefresh = function() cb.Text:SetText(CF.T(label)) end
    CF.RegisterLocaleUpdater(cb.CFLocaleRefresh)
    return cb
end

local function CreateCurseWatcherOptionsFrame()
    if curseWatcherOptionsFrame then return end

    curseWatcherOptionsFrame = CreateFrame(
        "Frame",
        "CursiveForeverCurseWatcherOptionsFrame",
        UIParent,
        "BackdropTemplate"
    )
    curseWatcherOptionsFrame:SetSize(620, 430)
    curseWatcherOptionsFrame:SetPoint("CENTER")
    curseWatcherOptionsFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    curseWatcherOptionsFrame:SetFrameLevel(140)
    curseWatcherOptionsFrame:SetMovable(true)
    curseWatcherOptionsFrame:SetClampedToScreen(true)
    curseWatcherOptionsFrame:EnableMouse(true)
    curseWatcherOptionsFrame:RegisterForDrag("LeftButton")
    curseWatcherOptionsFrame:Hide()

    ApplyDarkBackdrop(curseWatcherOptionsFrame, 1.0)
    curseWatcherOptionsFrame:SetBackdropColor(THEME_BG_R, THEME_BG_G, THEME_BG_B, 1.0)
    AddWitchCorners(curseWatcherOptionsFrame)
    AddInnerGlow(curseWatcherOptionsFrame)
    CreateCloseButton(curseWatcherOptionsFrame)

    curseWatcherOptionsFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    curseWatcherOptionsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = curseWatcherOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("|cffdfbd62" .. CF.T("CURSE_WATCHER") .. "|r")
    AttachDecorFrame(curseWatcherOptionsFrame, title)

    local note = curseWatcherOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 18, -47)
    note:SetWidth(575)
    note:SetJustifyH("LEFT")
    note:SetSpacing(2)
    note:SetText(CF.T("CURSE_NOTE"))

    local enabled = CreateCheckbox(
        curseWatcherOptionsFrame,
        18, -94,
        "CURSE_ENABLED",
        "CURSE_ENABLED_TIP",
        function() return db.raidCurseWatcherEnabled end,
        function(v)
            db.raidCurseWatcherEnabled = v and (not CF.Client or CF.Client.isForever)
            UpdateRaidCurseWatcher()
        end
    )
    curseWatcherOptionsFrame.enabledControl = enabled

    local assignLabel = curseWatcherOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    assignLabel:SetPoint("TOPLEFT", 20, -137)
    assignLabel:SetText("|cffd8b15a" .. CF.T("MY_CURSE") .. "|r")

    curseWatcherOptionsFrame.curseRadios = {}

    local function RefreshCurseAssignmentRadios()
        for _, rb in ipairs(curseWatcherOptionsFrame.curseRadios) do
            if rb.CFRefresh then
                rb:CFRefresh()
            end
        end

        if curseWatcherOptionsFrame.noneRadio
            and curseWatcherOptionsFrame.noneRadio.CFRefresh
        then
            curseWatcherOptionsFrame.noneRadio:CFRefresh()
        end
    end

    local function MakeCurseRadio(curse, x, y)
        local rb = CreateFrame("CheckButton", nil, curseWatcherOptionsFrame, "UIRadioButtonTemplate")
        rb:SetPoint("TOPLEFT", x, y)

        local name, icon, description = GetSpellDisplayInfo(curse)

        local tex = curseWatcherOptionsFrame:CreateTexture(nil, "ARTWORK")
        tex:SetSize(26, 26)
        tex:SetPoint("LEFT", rb, "RIGHT", 4, 0)
        tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local fs = curseWatcherOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", tex, "RIGHT", 7, 0)
        fs:SetWidth(155)
        fs:SetJustifyH("LEFT")
        fs:SetText(name or CF.GetCurseFallback(curse))

        rb:SetScript("OnClick", function()
            db.raidCurseKey = curse.key
            db.raidCurseWatcherEnabled = true

            RefreshCurseAssignmentRadios()
            curseWatcherOptionsFrame.enabledControl:CFRefresh()
            UpdateRaidCurseWatcher()
        end)

        rb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name or CF.GetCurseFallback(curse), 0.82, 0.52, 1)
            if description and description ~= "" then
                GameTooltip:AddLine(description, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        rb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        rb.CFRefresh = function()
            rb:SetChecked(db.raidCurseKey == curse.key)
        end

        curseWatcherOptionsFrame.curseRadios[#curseWatcherOptionsFrame.curseRadios + 1] = rb
        return rb
    end

    for i, curse in ipairs(RAID_CURSES) do
        MakeCurseRadio(curse, 22 + ((i - 1) % 2) * 296, -166 - math.floor((i - 1) / 2) * 41)
    end

    local noneRadio = CreateFrame("CheckButton", nil, curseWatcherOptionsFrame, "UIRadioButtonTemplate")
    noneRadio:SetPoint("TOPLEFT", 22, -248)
    local noneText = curseWatcherOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noneText:SetPoint("LEFT", noneRadio, "RIGHT", 4, 0)
    noneText:SetText(CF.T("NONE"))
    noneRadio:SetScript("OnClick", function()
        db.raidCurseKey = "none"
        RefreshCurseAssignmentRadios()
        UpdateRaidCurseWatcher()
    end)
    noneRadio.CFRefresh = function()
        noneRadio:SetChecked(db.raidCurseKey == "none")
    end
    curseWatcherOptionsFrame.noneRadio = noneRadio

    local warnLabel = curseWatcherOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warnLabel:SetPoint("TOPLEFT", 24, -288)

    local warnSlider = CreateFrame("Slider", nil, curseWatcherOptionsFrame, "OptionsSliderTemplate")
    warnSlider:SetPoint("TOPLEFT", 24, -310)
    warnSlider:SetWidth(310)
    warnSlider:SetMinMaxValues(3, 10)
    warnSlider:SetValueStep(1)
    if warnSlider.SetObeyStepOnDrag then
        warnSlider:SetObeyStepOnDrag(true)
    end
    if warnSlider.Low then warnSlider.Low:SetText("3 s") end
    if warnSlider.High then warnSlider.High:SetText("10 s") end
    if warnSlider.Text then warnSlider.Text:SetText("") end

    warnSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value or 5) + 0.5)
        db.raidCurseWarnSeconds = value
        warnLabel:SetText(CF.TF("WARN_BEFORE_FMT", value))
        UpdateRaidCurseWatcher()
    end)

    warnSlider.CFRefresh = function()
        local value = db.raidCurseWarnSeconds or 5
        warnSlider:SetValue(value)
        warnLabel:SetText(CF.TF("WARN_BEFORE_FMT", value))
    end
    curseWatcherOptionsFrame.warnSlider = warnSlider

    local test = CreateActionButton(curseWatcherOptionsFrame, "TEST_CURRENT")
    test:SetSize(205, 31)
    test:SetPoint("BOTTOMLEFT", 20, 22)
    test:SetScript("OnClick", ToggleRaidCurseTest)
    curseWatcherOptionsFrame.testButton = test

    local hint = curseWatcherOptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMRIGHT", -20, 28)
    hint:SetWidth(230)
    hint:SetJustifyH("RIGHT")
    hint:SetText(CF.T("RAID_TEST_HINT"))

    curseWatcherOptionsFrame.CFRefresh = function()
        enabled:CFRefresh()
        RefreshCurseAssignmentRadios()
        warnSlider:CFRefresh()

        if curseTestMode then
            test.cfLabel:SetText(CF.T("TEST_END"))
        else
            test.cfLabel:SetText(CF.T("TEST_CURRENT"))
        end
    end

    curseWatcherOptionsFrame.CFLocaleRefresh = function()
        title:SetText("|cffdfbd62" .. CF.T("CURSE_WATCHER") .. "|r")
        note:SetText(CF.T("CURSE_NOTE"))
        assignLabel:SetText("|cffd8b15a" .. CF.T("MY_CURSE") .. "|r")
        noneText:SetText(CF.T("NONE"))
        hint:SetText(CF.T("RAID_TEST_HINT"))
        warnSlider:CFRefresh()
        curseWatcherOptionsFrame:CFRefresh()
    end
    CF.RegisterLocaleUpdater(curseWatcherOptionsFrame.CFLocaleRefresh)

    table.insert(UISpecialFrames, "CursiveForeverCurseWatcherOptionsFrame")
end

local function ShowCurseWatcherOptions()
    if CF.Client and not CF.Client.isForever then CF.ClientFeatureNotice(); return end
    CreateCurseWatcherOptionsFrame()
    curseWatcherOptionsFrame:CFRefresh()
    curseWatcherOptionsFrame:Show()
    curseWatcherOptionsFrame:Raise()
end

local optionControls = {}
local function RefreshOptions()
    for _, c in ipairs(optionControls) do if c.CFRefresh then c:CFRefresh() end end
    if CF.RefreshOptionsPages then CF.RefreshOptionsPages() end
end

local function AttachRadioLabel(parent, rb, label, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", rb, "RIGHT", 3, 0)
    fs:SetWidth(width or 90)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    rb.cfLabel = fs

    -- Make the text area clickable as part of the radio button.
    if rb.SetHitRectInsets then
        rb:SetHitRectInsets(0, -(width or 90), 0, 0)
    end

    -- Some clients expose a template label, others do not.
    -- Hide it if it exists so there can never be duplicate text.
    if rb.Text then
        rb.Text:SetText("")
        rb.Text:Hide()
    end

    return fs
end

local function CreateOptionsDecorRadio(parent, x, y, label, style, tooltip)
    local rb = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    rb:SetPoint("TOPLEFT", x, y)

    AttachRadioLabel(parent, rb, CF.T(label), 58)

    rb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(CF.T(label), 1, 0.82, 0.35)
        if tooltip then
            GameTooltip:AddLine(CF.T(tooltip), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)

    rb:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rb:SetScript("OnClick", function()
        db.optionsDecorStyle = style
        ApplyOptionsDecorStyleAll()
        RefreshOptions()
    end)

    rb.CFRefresh = function()
        rb:SetChecked(GetOptionsDecorStyle() == style)
    end
    rb.CFLocaleRefresh = function()
        rb.cfLabel:SetText(CF.T(label))
    end
    CF.RegisterLocaleUpdater(rb.CFLocaleRefresh)

    return rb
end

local function CreateDisplayModeRadio(parent, x, y, label, mode, tooltip)
    local rb = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    rb:SetPoint("TOPLEFT", x, y)

    AttachRadioLabel(parent, rb, CF.T(label), 100)

    rb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(CF.T(label), 1, 0.82, 0.35)
        if tooltip then
            GameTooltip:AddLine(CF.T(tooltip), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)

    rb:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rb:SetScript("OnClick", function()
        db.targetDisplayMode = mode
        ApplyTargetDisplayMode()
        RefreshOptions()
    end)

    rb.CFRefresh = function()
        rb:SetChecked(GetTargetDisplayMode() == mode)
    end
    rb.CFLocaleRefresh = function()
        rb.cfLabel:SetText(CF.T(label))
    end
    CF.RegisterLocaleUpdater(rb.CFLocaleRefresh)

    return rb
end

local function CreateOptionsFrame()
    if optionsFrame then return end

    -- One grid for every page. Coordinates are logical WoW UI units.
    local grid = {width=760, height=620, margin=20, contentWidth=720,
        contentHeight=440, column=344, right=376, buttonHeight=32}
    local f = CreateFrame("Frame", "CursiveForeverOptionsFrame", UIParent, "BackdropTemplate")
    optionsFrame = f
    f.pages, f.tabs, f.controls = {}, {}, {}
    f.optionNodes, f.optionLabels, f.optionDividers = {}, {}, {}
    local function remember(object, x, y, width, height, kind)
        object.cfOptionsLayout={x=x,y=y,width=width,height=height,kind=kind}
        f.optionNodes[#f.optionNodes+1]=object
        return object
    end
    f:SetSize(grid.width, grid.height); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:Hide()
    f.classicBackdrop=CreateFrame("Frame",nil,f,"BackdropTemplate")
    f.classicBackdrop:SetAllPoints(); f.classicBackdrop:SetFrameLevel(f:GetFrameLevel())
    ApplyDarkBackdrop(f.classicBackdrop,1); AddWitchCorners(f.classicBackdrop); AddInnerGlow(f.classicBackdrop)
    f.closeButton=CreateCloseButton(f)
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetScript("OnHide", function()
        if f.CFCancelPageTurn then f.CFCancelPageTurn(true) end
        if historyFrame then historyFrame:Hide() end
        if filterFrame then filterFrame:Hide() end
        if CF.cardSelectionFrame then CF.cardSelectionFrame:Hide() end
        if CF.auraLayoutOptionsFrame then CF.auraLayoutOptionsFrame:Hide() end
        if curseWatcherOptionsFrame then curseWatcherOptionsFrame:Hide() end
        if CF.contactFrame then CF.contactFrame:Hide() end
    end)
    f.CFFitToScreen = function()
        f:SetScale(math.max(0.1, math.min(1,
            (UIParent:GetWidth()-40)/f:GetWidth(), (UIParent:GetHeight()-40)/f:GetHeight())))
    end
    f:SetScript("OnShow", f.CFFitToScreen)
    f:RegisterEvent("DISPLAY_SIZE_CHANGED"); f:RegisterEvent("UI_SCALE_CHANGED")
    f:SetScript("OnEvent", function() if f:IsShown() then f.CFFitToScreen() end end)

    local function text(parent, key, x, y, width, height, heading)
        local fs = parent:CreateFontString(nil, "OVERLAY", heading and "GameFontNormal" or "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", x, -y); fs:SetSize(width, height)
        fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetWordWrap(true)
        fs:SetTextColor(heading and 0.87 or 0.78, heading and 0.74 or 0.76, heading and 0.38 or 0.70)
        remember(fs,x,y,width,height,heading and "heading" or "text")
        fs.cfOptionsKey=key
        if key then f.optionLabels[key]=fs end
        if key then
            local refresh = function() fs:SetText(CF.T(key)) end
            CF.RegisterLocaleUpdater(refresh); refresh()
        end
        return fs
    end
    local function action(parent, id, key, x, y, callback)
        local b = CreateActionButton(parent, key)
        b:SetSize(grid.column, grid.buttonHeight); b:SetPoint("TOPLEFT", x, -y)
        b.cfLabel:SetWidth(grid.column-48); b.cfLabel:SetWordWrap(false)
        b:SetScript("OnClick", callback); f.controls[id] = b
        remember(b,x,y,grid.column,grid.buttonHeight,"action")
        return b
    end
    local function checkbox(parent, id, key, tip, x, y, width, getter, setter)
        local cb = CreateCheckbox(parent, x, -y, key, tip, getter, setter)
        cb.cfTipTitle=key;cb.cfTipBody=tip
        local onClick=cb:GetScript("OnClick")
        cb:SetScript("OnClick",function(self,...)
            onClick(self,...)
            if CF.RefreshOptionsPages then CF.RefreshOptionsPages() end
        end)
        cb:SetSize(26,26); cb.Text:ClearAllPoints(); cb.Text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.Text:SetWidth(width-34); cb.Text:SetWordWrap(true); cb.Text:SetJustifyH("LEFT")
        cb:SetHitRectInsets(0, -(width-26), 0, 0)
        optionControls[#optionControls+1] = cb; f.controls[id] = cb
        remember(cb,x,y,width,26,"checkbox")
        return cb
    end
    local function slider(parent, id, x, y, low, high, step, getter, setter, labelKey, displayValue)
        local label = text(parent, nil, x, y, grid.column, 20)
        local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        local sideLimits=id=="scale" or id=="trackerWidth" or id=="trackerHeight"
        local inset=sideLimits and 32 or 8
        s:SetPoint("TOPLEFT", x+inset, -y-26); s:SetSize(grid.column-inset*2, 18)
        s:SetMinMaxValues(low,high); s:SetValueStep(step)
        if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
        if s.Low then s.Low:SetText(tostring(displayValue(low))) end
        if s.High then s.High:SetText(tostring(displayValue(high))) end
        if sideLimits then
            -- End labels sit beside these closely stacked sizing sliders.
            if s.Low then s.Low:ClearAllPoints(); s.Low:SetPoint("RIGHT",s,"LEFT",-5,0) end
            if s.High then s.High:ClearAllPoints(); s.High:SetPoint("LEFT",s,"RIGHT",5,0) end
        end
        if s.Text then s.Text:SetText("") end
        local refreshing = false
        s:SetScript("OnValueChanged", function(self, value)
            if refreshing then return end
            value = math.max(low, math.min(high, math.floor((tonumber(value) or getter())/step+0.5)*step))
            setter(value); label:SetText(CF.TF(labelKey,displayValue(value)))
        end)
        s.CFRefresh = function()
            local value = getter()
            refreshing = true; s:SetValue(value); refreshing = false
            label:SetText(CF.TF(labelKey,displayValue(value)))
        end
        optionControls[#optionControls+1] = s; f.controls[id] = s
        s.cfCaption=label
        remember(s,x+inset,y+26,grid.column-inset*2,18,"slider")
        return s
    end
    local function divider(parent, y)
        local line = parent:CreateTexture(nil,"ARTWORK")
        line:SetPoint("TOPLEFT",0,-y); line:SetSize(grid.contentWidth,1)
        line:SetColorTexture(THEME_GOLD_R,THEME_GOLD_G,THEME_GOLD_B,0.28)
        f.optionDividers[#f.optionDividers+1]=line
    end
    local function tooltip(button, titleKey, bodyKey, marker)
        button.cfTipTitle=titleKey;button.cfTipBody=bodyKey
        local enter, leave = button:GetScript("OnEnter"), button:GetScript("OnLeave")
        button:SetScript("OnEnter", function(self)
            if enter then enter(self) end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(CF.T(titleKey),1,0.82,0.35)
            GameTooltip:AddLine(CF.T(bodyKey),1,1,1,true)
            if marker and CF.performanceMarkerWasSecret then
                GameTooltip:AddLine(CF.T("RAID_MARKER_SECRET"),1,0.45,0.35,true)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self) if leave then leave(self) end; GameTooltip:Hide() end)
    end

    local title = text(f,nil,16,14,430,24,true)
    title:SetFontObject("GameFontNormalLarge")
    local version = text(f,nil,580,13,134,30)
    version:SetJustifyH("RIGHT"); version:SetText(VERSION)
    AttachDecorFrame(f,title)

    local pageList = {
        {id="general", key="OPTIONS_GENERAL"}, {id="combat", key="OPTIONS_COMBAT"},
        {id="performance", key="OPTIONS_REVIEW"}, {id="help", key="OPTIONS_HELP"},
    }
    f.optionPages=pageList
    f.CFRefreshTabs = function()
        local id=f.activePage
        for _,pageInfo in ipairs(pageList) do
            local selected=pageInfo.id==id
            local tab=f.tabs[pageInfo.id]
            if selected then tab.cfSelectedLine:Show() else tab.cfSelectedLine:Hide() end
            tab:SetBackdropColor(selected and 0.14 or 0.055,selected and 0.105 or 0.043,selected and 0.045 or 0.027,1)
            tab:SetBackdropBorderColor(THEME_GOLD_DIM_R,THEME_GOLD_DIM_G,THEME_GOLD_DIM_B,1)
            tab.cfLabel:SetTextColor(selected and 1 or 0.76,selected and 0.84 or 0.70,selected and 0.46 or 0.52)
        end
    end
    f.CFSelectPage = function(id)
        if not f.pages[id] then id="general" end
        f.activePage=id
        for pageID,page in pairs(f.pages) do
            page:SetAlpha(1)
            if pageID==id then page:Show() else page:Hide() end
        end
        f.CFRefreshTabs()
    end
    for index, info in ipairs(pageList) do
        local page = CreateFrame("Frame",nil,f)
        page:SetPoint("TOPLEFT",grid.margin,-114); page:SetSize(grid.contentWidth,grid.contentHeight)
        f.pages[info.id]=page
        local tab = CreateActionButton(f,info.key,true)
        tab:SetPoint("TOPLEFT",grid.margin+(index-1)*182,-62); tab:SetSize(174,32)
        tab.cfLabel:SetWidth(158); tab.cfLabel:SetWordWrap(false)
        tab.cfSelectedLine=tab:CreateTexture(nil,"ARTWORK")
        tab.cfSelectedLine:SetPoint("BOTTOMLEFT",1,1); tab.cfSelectedLine:SetSize(172,2)
        tab.cfSelectedLine:SetColorTexture(THEME_GOLD_HI_R,THEME_GOLD_HI_G,THEME_GOLD_HI_B,1)
        tab:SetScript("OnClick",function()
            if f.CFRequestPage then f.CFRequestPage(info.id) else f.CFSelectPage(info.id) end
        end)
        tab:SetScript("OnLeave",function() f.CFRefreshTabs() end)
        f.tabs[info.id]=tab
    end

    local general, combat, performance, help = f.pages.general, f.pages.combat, f.pages.performance, f.pages.help
    text(general,"OPTIONS_ACCESS",0,0,grid.column,24,true)
    text(general,"OPTIONS_MAIN_WINDOW",grid.right,0,grid.column,24,true)
    local language = action(general,"language","LANGUAGE",0,36,function()
        CF.CycleLanguageMode(); CF.RefreshLocale(); RefreshOptions()
        UpdateNameplateRequirementWarning(); UpdateRaidCurseWatcher()
        if curseWatcherOptionsFrame and curseWatcherOptionsFrame.CFRefresh then curseWatcherOptionsFrame:CFRefresh() end
    end)
    language.CFLocaleRefresh=function() language.cfLabel:SetText(CF.TF("LANGUAGE_BUTTON_FMT",CF.GetLanguageModeLabel())) end
    CF.RegisterLocaleUpdater(language.CFLocaleRefresh); tooltip(language,"LANGUAGE","LANGUAGE_TOOLTIP")
    checkbox(general,"minimap","SHOW_MINIMAP","SHOW_MINIMAP_TIP",0,90,grid.column,
        function() return db.showMinimap end,function(v)
            db.showMinimap=v
            if minimapButton then if v then minimapButton:Show() else minimapButton:Hide() end end
        end)
    slider(general,"radius",0,142,
        CF.Client and CF.Client.minimapRadiusMin or 80,
        CF.Client and CF.Client.minimapRadiusMax or 125,
        1,function() return db.minimapRadius or 105 end,
        function(v) db.minimapRadius=v; if minimapButton and UpdateMinimapButtonPosition then UpdateMinimapButtonPosition() end end,
        "MINIMAP_DISTANCE_FMT",function(v) return math.floor(v+0.5) end)
    text(general,"OPTIONS_MINIMAP_HELP",0,280,grid.column,32)
    local transparency=slider(general,"transparency",0,216,0,80,5,CF.GetWindowTransparency,
        CF.SetWindowTransparency,"WINDOW_TRANSPARENCY_FMT",function(v) return math.floor(v+0.5) end)
    tooltip(transparency,"WINDOW_TRANSPARENCY","WINDOW_TRANSPARENCY_TIP")
    checkbox(general,"lock","LOCK_MAIN","LOCK_MAIN_TIP",grid.right,36,grid.column/2,
        function() return db.lockFrame end,function(v) db.lockFrame=v end)
    checkbox(general,"header","SHOW_HEADER","SHOW_HEADER_TIP",grid.right+grid.column/2,36,grid.column/2,
        function() return db.showHeader ~= false end,CF.SetMainHeaderShown)
    slider(general,"scale",grid.right,82,0.40,1.30,0.05,function() return db.frameScale or 1 end,
        function(v) if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return end; db.frameScale=v; ApplyMainScale() end,"SCALE_FMT",function(v) return math.floor(v*100+0.5) end)
    local function sizingSlider(id,axis,y,titleKey,formatKey)
        local function getter()
            local width,height=CF.GetTrackerSizing()
            return axis == "width" and width or height
        end
        local control=slider(general,id,grid.right,y,.5,1.5,.01,getter,function() end,
            "SCALE_FMT",function(v) return math.floor(v*100+.5) end)
        local syncing=false
        local function caption(value)
            local keys={standard="STANDARD",matrix="MATRIX",bars="BARS",healthbar="HEALTHBARS"}
            control.cfCaption:SetText(CF.TF(formatKey,CF.T(keys[CF.GetTrackerView()]),math.floor(value*100+.5)))
        end
        control:SetScript("OnValueChanged",function(_,value)
            if syncing then return end
            CF.SetTrackerSizing(axis,value)
        end)
        control.CFRefresh=function()
            syncing=true
            local value=getter(); control:SetValue(value); caption(value)
            syncing=false
        end
        CF.RegisterLocaleUpdater(control.CFRefresh)
        tooltip(control,titleKey,axis=="height" and "TRACKER_HEIGHT_TIP" or "TRACKER_SIZING_TIP")
        return control
    end
    sizingSlider("trackerWidth","width",150,"TRACKER_WIDTH","TRACKER_WIDTH_FMT")
    sizingSlider("trackerHeight","height",218,"TRACKER_HEIGHT","TRACKER_HEIGHT_FMT")
    local resetSize=action(general,"resetScale","OPTIONS_RESET_SCALE",grid.right,286,function()
        if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return end
        db.frameScale=1; ApplyMainScale(); CF.ResetTrackerSizing(); RefreshOptions()
    end)
    tooltip(resetSize,"OPTIONS_RESET_SCALE","TRACKER_RESET_TIP")
    action(general,"resetPosition","RESET_POSITION",0,286,function()
        if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return end
        db.point=nil; db.relativePoint=nil; db.x=nil; db.y=nil
        RestorePosition(); Print(CF.T("POSITION_RESET"))
    end)
    f.optionLabels.OPTIONS_MINIMAP_HELP:Hide()
    divider(general,326)


    text(combat,"TARGET_DISPLAY",0,0,grid.column,24,true)
    local health=action(combat,"health","HEALTH_DISPLAY",grid.right,0,function()
        if (CF.IsBarsView and CF.IsBarsView()) or (CF.IsHealthbarView and CF.IsHealthbarView()) then return end
        CF.SetHealthDisplayMode(CF.GetHealthDisplayMode() == "percent" and "bar" or "percent")
        f.controls.health.CFLocaleRefresh()
    end)
    health.CFLocaleRefresh=function()
        local bars = (CF.IsBarsView and CF.IsBarsView()) or (CF.IsHealthbarView and CF.IsHealthbarView())
        health.cfLabel:SetText(CF.TF("HEALTH_DISPLAY_FMT",CF.T(bars and "HEALTH_BAR_PERCENT"
            or CF.GetHealthDisplayMode() == "bar" and "HEALTH_BAR" or "HEALTH_PERCENT")))
        health:SetEnabled(not bars)
        health:SetAlpha(bars and .65 or 1)
    end
    health.CFRefresh=health.CFLocaleRefresh
    optionControls[#optionControls+1]=health
    CF.RegisterLocaleUpdater(health.CFLocaleRefresh)
    tooltip(health,"HEALTH_DISPLAY","HEALTH_DISPLAY_TIP")
    local view=CreateFrame("Frame",nil,combat)
    view:SetPoint("TOPLEFT",0,-36); view:SetSize(grid.column,56)
    f.controls.view=view
    remember(view,0,36,grid.column,56,"view")
    view.radios={}
    for index,choice in ipairs({{mode="standard",key="STANDARD"},{mode="matrix",key="MATRIX"},
        {mode="bars",key="BARS"},{mode="healthbar",key="HEALTHBARS"}}) do
        local rb=CreateFrame("CheckButton",nil,view,"UIRadioButtonTemplate")
        local x,y=((index-1)%2)*155,math.floor((index-1)/2)*22
        rb:SetPoint("TOPLEFT",x,-y); rb:SetSize(20,20)
        AttachRadioLabel(view,rb,CF.T(choice.key),118)
        rb.cfRadioLabelWidth=118
        rb:SetScript("OnClick",function()
            CF.SetTrackerView(choice.mode)
            RefreshOptions()
        end)
        tooltip(rb,choice.key,"TRACKER_VIEW_TIP")
        rb.CFLocaleRefresh=function() rb.cfLabel:SetText(CF.T(choice.key)) end
        CF.RegisterLocaleUpdater(rb.CFLocaleRefresh)
        view.radios[choice.mode]=rb
        f.controls["view_"..choice.mode]=rb
        remember(rb,x,y,20,20,"radio")
    end
    local viewPending=text(view,nil,0,44,grid.column,12)
    view.cfPending=viewPending
    viewPending:SetFontObject("GameFontDisableSmall")
    view.CFLocaleRefresh=function()
        local current = CF.pendingTrackerView or CF.GetTrackerView()
        for mode,rb in pairs(view.radios) do rb:SetChecked(current==mode) end
        if CF.pendingTrackerView then
            local key=current=="healthbar" and "HEALTHBARS" or (current=="bars" and "BARS" or (current=="matrix" and "MATRIX" or "STANDARD"))
            viewPending:SetText(CF.TF("TRACKER_VIEW_PENDING_FMT",CF.T(key))); viewPending:Show()
        elseif CF.pendingTrackerExtraIcons ~= nil then
            viewPending:SetText(CF.T("TRACKER_EXTRAS_PENDING")); viewPending:Show()
        else viewPending:Hide() end
        if f.controls.barsSpellNames then
            if current=="bars" then f.controls.barsSpellNames:Show() else f.controls.barsSpellNames:Hide() end
        end
        if f.optionLabels.DISPLAY_HINT then
            f.optionLabels.DISPLAY_HINT:SetText(CF.T(current=="healthbar" and "HEALTHBARS_HINT" or "DISPLAY_HINT"))
            if current=="bars" then f.optionLabels.DISPLAY_HINT:Hide() else f.optionLabels.DISPLAY_HINT:Show() end
        end
    end
    view.CFRefresh=view.CFLocaleRefresh
    optionControls[#optionControls+1]=view
    CF.RegisterLocaleUpdater(view.CFLocaleRefresh)
    text(combat,"DISPLAY_HINT",0,96,grid.column,30)
    checkbox(combat,"barsSpellNames","BARS_SHOW_SPELL_NAMES","BARS_SHOW_SPELL_NAMES_TIP",0,96,grid.column,
        CF.GetBarsShowSpellNames,function(value) CF.SetBarsShowSpellNames(value); RefreshOptions() end)
    checkbox(combat,"extraIcons","TRACKER_EXTRA_ICONS","TRACKER_EXTRA_ICONS_TIP",grid.right,36,168,
        CF.GetRequestedTrackerExtras,function(value) CF.SetTrackerExtrasEnabled(value); RefreshOptions() end)
    checkbox(combat,"hideFrame","TRACKER_HIDE_FRAME","TRACKER_HIDE_FRAME_TIP",grid.right+176,36,168,
        CF.IsTrackerFrameHidden,function(value) CF.SetTrackerFrameHidden(value); RefreshOptions() end)
    local dotLayout=action(combat,"auraLayout","AURA_LAYOUT_TITLE",grid.right,76,CF.ShowAuraLayoutOptions)
    local suggestions=action(combat,"experimental","EXP_TITLE",grid.right+176,76,CF.ToggleExperimental)
    dotLayout.cfOptionsLayout.width=168; dotLayout:SetWidth(168)
    suggestions.cfOptionsLayout.width=168; suggestions:SetWidth(168)
    CF.ConfigureExperimentalToggle(suggestions)
    tooltip(suggestions,"EXP_TITLE","EXP_TIP")
    local execute=action(combat,"execute","EXECUTE_TITLE",grid.right,112,function()
        CF.CycleExecuteMode(); f.controls.execute.CFLocaleRefresh()
    end)
    execute.CFLocaleRefresh=function() execute.cfLabel:SetText(CF.TF("EXECUTE_FMT",CF.GetExecuteModeLabel())) end
    execute.CFRefresh=execute.CFLocaleRefresh
    optionControls[#optionControls+1]=execute
    CF.RegisterLocaleUpdater(execute.CFLocaleRefresh); tooltip(execute,"EXECUTE_TITLE","EXECUTE_TIP")
    checkbox(combat,"outOfCombat","SHOW_OOC","SHOW_OOC_TIP",0,128,grid.column,
        function() return db.showTargetOutOfCombat end,function(v) db.showTargetOutOfCombat=v; RefreshDisplayPolicy() end)
    checkbox(combat,"hideOutOfCombat","HIDE_WINDOW_OOC","HIDE_WINDOW_OOC_TIP",0,160,grid.column,
        function() return db.hideWindowOutOfCombat == true end,CF.SetHideWindowOutOfCombat)
    divider(combat,196)
    text(combat,"CLASS_FILTER",0,208,grid.column,22,true)
    text(combat,"CLASS_FILTER_SUMMARY",0,236,grid.column,32)
    action(combat,"filters","CLASS_FILTER_OPEN",grid.right,226,ShowSpellFilter)
    text(combat,"PRIORITY_MARKER",0,282,grid.column,22,true)
    text(combat,"OPTIONS_PRIORITY_HELP",0,310,grid.column,32)
    local priority=action(combat,"priority","PRIORITY_MARKER",grid.right,300,function()
        CF.CyclePriorityRaidMarker(); f.controls.priority.CFLocaleRefresh(); LayoutRows()
    end)
    priority.CFLocaleRefresh=function()
        priority.cfLabel:SetText(CF.TF("PRIORITY_MARKER_FMT",CF.GetPriorityMarkerName(db.priorityRaidMarker)))
    end
    CF.RegisterLocaleUpdater(priority.CFLocaleRefresh); tooltip(priority,"PRIORITY_MARKER","PRIORITY_MARKER_TIP",true)
    text(combat,"CURSE_WATCHER",0,356,grid.column,22,true)
    text(combat,"CURSE_SUMMARY",0,384,grid.column,48)
    action(combat,"curse","CURSE_OPEN",grid.right,374,ShowCurseWatcherOptions)

    text(performance,"OPTIONS_MONITOR",0,0,grid.column,24,true)
    text(performance,"CARDS_TITLE",grid.right,0,grid.column,24,true)
    text(performance,"PERFORMANCE_SUMMARY",0,34,grid.column,60)
    text(performance,"CARDS_SUMMARY",grid.right,34,grid.column,60)
    action(performance,"monitor","PERFORMANCE_OPEN",0,108,function() CF.ShowPerformance() end)
    action(performance,"cards","CARDS_OPEN",grid.right,108,function() CF.ShowCardSelection() end)
    divider(performance,164)
    text(performance,"OPTIONS_RECORDING",0,186,grid.column,24,true)
    text(performance,"PERFORMANCE_LAYOUT",grid.right,186,grid.column,24,true)
    checkbox(performance,"recording","PERFORMANCE_ENABLED","PERFORMANCE_ENABLED_TIP",0,224,grid.column,
        function() return db.performanceEnabled end,function(v)
            db.performanceEnabled=v and (not CF.Client or CF.Client.supportsAnalysis); if not db.performanceEnabled then CF.performanceActive=nil end
        end)
    slider(performance,"minimum",0,282,15,60,5,function() return tonumber(db.performanceMinSeconds) or 45 end,
        function(v) db.performanceMinSeconds=v end,"PERFORMANCE_MIN_FMT",function(v) return math.floor(v+0.5) end)
    text(performance,"OPTIONS_LAYOUT_HELP",grid.right,224,grid.column,52)
    action(performance,"layout","PERFORMANCE_LAYOUT",grid.right,300,function() CF.ShowPerformanceLayoutOptions() end)
    text(performance,"OPTIONS_ARCHIVE_HELP",0,374,grid.contentWidth,56)

    text(help,"CONTROLS",0,0,grid.column,24,true)
    text(help,"OPTIONS_INFORMATION",grid.right,0,grid.column,24,true)
    text(help,"HELP_TEXT",0,34,grid.column,140)
    local build=text(help,nil,grid.right,34,grid.column,88)
    action(help,"history","VERSION_HISTORY",grid.right,140,ShowHistory)
    action(help,"status","OPTIONS_STATUS",grid.right,184,function() CF.ShowStatusReport() end)
    text(help,"RAID_MANY",0,220,grid.column,24,true)
    text(help,"RAID_MANY_TEXT",0,254,grid.column,88)
    action(help,"contact","CONTACT_OPEN",0,350,CF.ShowContactInfo)
    text(help,"OPTIONS_COMMANDS",grid.right,254,grid.column,112)
    divider(help,388)
    text(help,"OPTIONS_CREDITS",0,410,grid.contentWidth,24)

    local footerLine=f:CreateTexture(nil,"ARTWORK")
    footerLine:SetPoint("TOPLEFT",20,-572); footerLine:SetSize(grid.contentWidth,1)
    footerLine:SetColorTexture(THEME_GOLD_R,THEME_GOLD_G,THEME_GOLD_B,0.28)
    -- Keep this line clear of the 28-unit corner ornaments in the Full style.
    text(f,"OPTIONS_SAVED",40,588,grid.width-80,20)
    CF.BuildOptionsPages(f,{text=text,action=action,checkbox=checkbox,slider=slider,
        tooltip=tooltip,applyFilters=ApplySpellFiltersToAllRows})
    CF.AttachGrimoire(f,{db=db,title=title,version=version,build=build,
        footerLine=footerLine,applyDecoration=ApplyOptionsDecorStyleAll})
    f.CFLocaleRefresh=function()
        title:SetText("|cffdfbd62"..(CF.Client and CF.Client.title or "Cursive Forever").."|r  |cffd8d1c2"..CF.T("OPTIONS").."|r")
        build:SetText(CF.T("OPTIONS_VERSION").." "..VERSION.."\n\n"..CF.T("TESTED_ON")
            .." "..(CF.Client and CF.Client.build.clientName or "WoW Forever").." "..TESTED_CLIENT_VERSION.." ("..TESTED_CLIENT_BUILD..")\n"
            ..TESTED_CLIENT_FLAVOR.." · "..TESTED_CLIENT_DATE)
        RefreshOptions(); language.CFLocaleRefresh(); priority.CFLocaleRefresh()
        f.CFSelectPage(f.cfMinimalPage or f.activePage or "general")
        if f.CFRefreshPresentation then f.CFRefreshPresentation() end
    end
    CF.RegisterLocaleUpdater(f.CFLocaleRefresh)
    f.CFLocaleRefresh(); f.CFFitToScreen()
    table.insert(UISpecialFrames,"CursiveForeverOptionsFrame")
end

local function ShowOptions()
    if CF.LayoutWorkshop then CF.LayoutWorkshop.PrepareOptions() end
    if CF.performanceFrame then CF.performanceFrame:Hide() end
    CreateOptionsFrame()
    RefreshOptions()
    ApplyOptionsDecorStyleAll()
    optionsFrame.CFRefreshPresentation()
    optionsFrame:Show()
    optionsFrame:Raise()
end
CF.ShowOptionsWindow = ShowOptions

local function Atan2(y,x)
    if math.atan2 then return math.atan2(y,x) end
    if x>0 then return math.atan(y/x) end
    if x<0 and y>=0 then return math.atan(y/x)+math.pi end
    if x<0 and y<0 then return math.atan(y/x)-math.pi end
    if x==0 and y>0 then return math.pi/2 end
    if x==0 and y<0 then return -math.pi/2 end
    return 0
end

UpdateMinimapButtonPosition = function()
    if not minimapButton then return end
    local a = math.rad(db.minimapAngle or 220)
    local radius = db.minimapRadius or 105
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(a) * radius,
        math.sin(a) * radius
    )
end

local function UpdateMinimapAngleFromCursor()
    local mx,my = Minimap:GetCenter()
    local scale = UIParent:GetEffectiveScale()
    local cx,cy = GetCursorPosition()
    cx,cy = cx/scale, cy/scale
    local a = math.deg(Atan2(cy-my,cx-mx))
    if a<0 then a=a+360 end
    db.minimapAngle=a
    UpdateMinimapButtonPosition()
end

local function ResolveWarlockMinimapIcon()
    -- Ask the current client for a real FileDataID instead of relying on a
    -- hard-coded path. Especially useful while Forever is still beta.
    if C_Spell and C_Spell.GetSpellTexture then
        local candidates = {
            686, -- Shadow Bolt
            172, -- Corruption
            348, -- Immolate / Feuerbrand
        }

        for _, spellID in ipairs(candidates) do
            local ok, iconID = pcall(C_Spell.GetSpellTexture, spellID)
            if ok and iconID then
                return iconID
            end
        end
    end

    -- Last-resort texture path. Double backslashes are intentional Lua escapes.
    return "Interface\\Icons\\Spell_Shadow_ShadowBolt"
end

local function CreateMinimapButton()
    if minimapButton then return end

    minimapButton = CreateFrame("Button", "CursiveForeverMinimapButton", Minimap)
    minimapButton:SetSize(34, 34)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    -- Keep mask objects referenced on the button.
    minimapButton.CFMasks = {}

    local function ApplyCircleMask(texture)
        local mask = minimapButton:CreateMaskTexture(nil, "ARTWORK")
        mask:SetAllPoints(texture)
        mask:SetTexture(
            "Interface/CHARACTERFRAME/TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE",
            "CLAMPTOBLACKADDITIVE"
        )
        texture:AddMaskTexture(mask)
        minimapButton.CFMasks[#minimapButton.CFMasks + 1] = mask
        return mask
    end

    -- Soft circular hover glow, hidden normally.
    local glow = minimapButton:CreateTexture(nil, "BACKGROUND", nil, -2)
    glow:SetSize(34, 34)
    glow:SetPoint("CENTER")
    glow:SetColorTexture(THEME_GOLD_HI_R, THEME_GOLD_HI_G, THEME_GOLD_HI_B, 0.34)
    ApplyCircleMask(glow)
    glow:Hide()
    minimapButton.CFGlow = glow

    -- Purple outer ring.
    local outer = minimapButton:CreateTexture(nil, "BACKGROUND", nil, -1)
    outer:SetSize(32, 32)
    outer:SetPoint("CENTER")
    outer:SetColorTexture(THEME_GOLD_R, THEME_GOLD_G, THEME_GOLD_B, 1.0)
    ApplyCircleMask(outer)

    -- Dark inner disc. Difference in diameter creates the visible ring.
    local inner = minimapButton:CreateTexture(nil, "BORDER")
    inner:SetSize(28, 28)
    inner:SetPoint("CENTER")
    inner:SetColorTexture(0.032, 0.025, 0.016, 1.0)
    ApplyCircleMask(inner)

    -- Round warlock icon.
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER")
    icon:SetTexture(ResolveWarlockMinimapIcon())
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ApplyCircleMask(icon)

    local fallbackText = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fallbackText:SetPoint("CENTER", 0, 0)
    fallbackText:SetText("|cffdfbd62C|r")
    fallbackText:Hide()

    C_Timer.After(0, function()
        if not icon:GetTexture() then
            fallbackText:Show()
        end
    end)

    -- Tiny circular fel accent.
    local fel = minimapButton:CreateTexture(nil, "OVERLAY")
    fel:SetSize(6, 6)
    fel:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 4, -4)
    fel:SetColorTexture(0.30, 1.00, 0.38, 0.95)
    ApplyCircleMask(fel)

    minimapButton:SetScript("OnEnter", function(self)
        self.CFGlow:Show()

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(CF.Client and CF.Client.title or "Cursive Forever", 0.88, 0.72, 0.34)
        GameTooltip:AddLine(CF.T("MINIMAP_LEFT"), 1, 1, 1)
        GameTooltip:AddLine(CF.T("MINIMAP_RIGHT"), 1, 1, 1)
        GameTooltip:AddLine(CF.T("MINIMAP_DRAG"), 0.45, 1, 0.55)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function(self)
        self.CFGlow:Hide()
        GameTooltip:Hide()
    end)

    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ShowOptions()
        elseif button == "RightButton" then
            CF.SetMainWindowManuallyHidden(not db.hidden)
            if not db.hidden then RescanVisibleNameplates() end
        end
    end)

    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            UpdateMinimapAngleFromCursor()
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateMinimapAngleFromCursor()
    end)

    UpdateMinimapButtonPosition()

    if not db.showMinimap then
        minimapButton:Hide()
    end
end

local function Toggle()
    CF.SetMainWindowManuallyHidden(not db.hidden)
    if not db.hidden then RescanVisibleNameplates() end
end

CF:RegisterEvent("ADDON_LOADED")
CF:RegisterEvent("SPELLS_CHANGED")
CF:RegisterEvent("PLAYER_LOGIN")
CF:RegisterEvent("PLAYER_ENTERING_WORLD")
CF:RegisterEvent("PLAYER_TARGET_CHANGED")
CF:RegisterEvent("PLAYER_FOCUS_CHANGED")
CF:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
CF:RegisterEvent("UNIT_TARGET")
CF:RegisterEvent("NAME_PLATE_UNIT_ADDED")
CF:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
CF:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
CF:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
CF:RegisterEvent("PLAYER_REGEN_DISABLED")
CF:RegisterEvent("PLAYER_REGEN_ENABLED")
CF:RegisterEvent("GROUP_ROSTER_UPDATE")
CF:RegisterEvent("UNIT_PET")
CF:RegisterEvent("UNIT_AURA")
CF:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
CF:RegisterEvent("UNIT_SPELLCAST_SENT")
CF:RegisterEvent("UNIT_SPELLCAST_FAILED")
CF:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
CF:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
CF:RegisterEvent("PLAYER_DEAD")
CF:RegisterEvent("RAID_TARGET_UPDATE")

-- If this client sets a raid marker itself, remember the marker before combat
-- protection can hide its numeric index. This does not attempt to extract
-- protected information; it only remembers arguments already known locally.
if hooksecurefunc and not CF.raidMarkerSetHookInstalled then
    pcall(function()
        hooksecurefunc("SetRaidTarget", function(unit, index)
            if not IsSecretValue(index) then
                CF.CacheRaidMarkerForUnit(unit, index)
            end

            C_Timer.After(0, function()
                LayoutRows()
            end)
        end)
        CF.raidMarkerSetHookInstalled = true
    end)
end
CF:RegisterEvent("UNIT_HEALTH")
CF:RegisterEvent("UNIT_MAXHEALTH")
CF:RegisterEvent("UNIT_FLAGS")
CF:RegisterEvent("CVAR_UPDATE")
CF:RegisterEvent("UPDATE_BINDINGS")
CF:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
CF:RegisterEvent("ENCOUNTER_START")
CF:RegisterEvent("ENCOUNTER_END")
CF:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")

CF.AuraLayoutUI = {
    backdrop=ApplyDarkBackdrop, close=CreateCloseButton,
    action=CreateActionButton, spellInfo=GetSpellDisplayInfo,
}

CF:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, ...)
    if (string.match(event, "^UNIT_") or event == "NAME_PLATE_UNIT_ADDED"
        or event == "NAME_PLATE_UNIT_REMOVED")
        and (IsSecretValue(arg1) or type(arg1) ~= "string") then return end
    if CF.TraceTrackerEvent then CF.TraceTrackerEvent(event,arg1) end
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if CF.Client then CF.Client.LoadSavedVariables() end
        ApplyDefaults()
        CF.RefreshClassSpellRanks()
        DURATION_FORMATTER = CreateCursiveSecondsFormatter()
        HEALTH_COLOR_CURVE = CreateHealthColorCurve()

    elseif event == "PLAYER_LOGIN" then
        CF.RefreshClassSpellRanks()
        CreateUI()
        CreateMinimapButton()
        ApplySpellFiltersToAllRows()
        Print(CF.TF("LOADED_FMT", VERSION_LABEL))

        C_Timer.After(0.5, function()
            RescanVisibleNameplates()
            UpdateNameplateRequirementWarning()
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        CF.RefreshMainWindowVisibility()
        CF.ClearTransientTargetCaches()
        CF.performanceOpeningCasts={}
        CF.performanceSent={}
        CF.performanceSeenCasts={}
        C_Timer.After(0.8, function()
            ApplySpellFiltersToAllRows()
            RescanVisibleNameplates()
            UpdateNameplateRequirementWarning()
        end)

    elseif event == "SPELLS_CHANGED" then
        CF.classRanksDirty=true
        if not CF.classRankRefreshQueued then
            CF.classRankRefreshQueued=true
            C_Timer.After(0.2,function()
                CF.classRankRefreshQueued=nil
                if CF.RefreshClassSpellRanks() then
                    ApplySpellFiltersToAllRows()
                    if filterFrame and filterFrame:IsShown() then CF.RefreshClassFilterFrame() end
                    if CF.cardSelectionFrame and CF.cardSelectionFrame:IsShown() then CF.RefreshCardSelection() end
                end
            end)
        end

    elseif event == "CVAR_UPDATE" then
        if arg1 == "nameplateShowEnemies" then
            UpdateNameplateRequirementWarning()
        end

    elseif event == "UPDATE_BINDINGS" then
        UpdateNameplateRequirementWarning()

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- The fallback token has no stable identity across target changes.
        CF.raidCurseCastState["unit:target"] = nil
        -- RefreshDisplayPolicy reconciles sticky rows against the new target.
        -- Never restore a removed/reusable nameplate token here.
        RefreshDisplayPolicy()
        UpdateHealthForUnit("target")

    elseif event == "PLAYER_FOCUS_CHANGED"
        or event == "UPDATE_MOUSEOVER_UNIT"
        or (event == "UNIT_TARGET" and (arg1 == "pet" or arg1 == "target"))
    then
        -- A live fallback alias is reusable too. Reconcile on its change
        -- event instead of leaving a foreign binding until the next tick.
        RefreshDisplayPolicy()

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        visibleUnits[arg1] = true
        RefreshDisplayPolicy()

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        visibleUnits[arg1] = nil

        -- nameplateN tokens are reusable. Never let the ephemeral token
        -- engagement flag survive removal, or a later neutral mob could inherit it.
        playerEngagedUnits[arg1] = nil

        if UnitIsActuallyDead(arg1) and CF.RemoveDeadTrackedUnit(arg1) then
        elseif PlayerInCombat() then
            -- Keep the established native display and known estimates;
            -- current life/health still require an independent matching token.
            DetachUnitToSticky(arg1)
        else
            CF.ForgetUnitEngagement(arg1)
            HideUnit(arg1)
        end

        RefreshDisplayPolicy()

    elseif event == "UNIT_SPELLCAST_SENT" then
        if not IsSecretValue(arg1) and arg1=="player" then
            if CF.ResolveCastRecipient then CF.ResolveCastRecipient(arg2,arg3,select(1,...)) end
            CF.PerformanceCastSent(arg2,arg3,select(1,...))
            CF.RaidCurseCastSent(arg2,arg3,select(1,...))
        end

    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not IsSecretValue(arg1) and arg1=="player" then CF.RaidCurseCastFailed(arg2) end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget = arg1
        local spellID = arg3

        if not IsSecretValue(unitTarget) and unitTarget == "player" and not IsSecretValue(spellID) and type(spellID) == "number" then
            CF.PerformanceRecordCast(spellID,arg2)
            local learnedCurseKey = CF.LearnRaidCurseSpellIDFromCast(spellID)

            if TRACKED_DEBUFF_SPELL_IDS[spellID] or learnedCurseKey then
                local recipient = CF.GetCastRecipient and CF.GetCastRecipient(arg2)
                if recipient then
                    if IsSafeGUIDKey(recipient.guid) then
                        CF.playerEngagedGUIDs[recipient.guid]=true
                        -- Only nameplates enter the tracker. Reusable focus/target
                        -- aliases belong exclusively to the fixed presentation.
                        for token in pairs(visibleUnits) do
                            if SafeUnitGUID(token)==recipient.guid then
                                CF.MarkUnitEngaged(token);ShowUnit(token);break
                            end
                        end
                    end
                else MarkCurrentTargetEngaged() end
                RefreshDisplayPolicy()
            end

            if CF.RaidCurseCastFinished(arg2,spellID) or learnedCurseKey then
                UpdateRaidCurseWatcher()
            end
        end

    elseif event == "UNIT_HEALTH"
        or event == "UNIT_MAXHEALTH"
        or event == "UNIT_FLAGS"
    then
        if UnitIsActuallyDead(arg1) then
            if not CF.RemoveDeadTrackedUnit(arg1) then RefreshDisplayPolicy() end
        else
            local row = FindRowByUnitOrGUID(arg1)
            if row and row.offscreen then CF.ReconcileStickyRow(row) end
            UpdateHealthForUnit(arg1)
        end

    elseif event == "UNIT_AURA" then
        CF.PerformanceResolvePending(false)
        UpdateRaidCurseWatcher()

        -- No polling and no timer-based resorting:
        -- only aura changes can alter the expiration ordering.
        RefreshDotSortForUnit(arg1)

        -- Preserve the established selected-target update path and use the
        -- same identity checks for other independently available aliases.
        if arg1 == "target" or arg1 == "focus" or arg1 == "mouseover"
            or arg1 == "pettarget" or arg1 == "targettarget" then
            local targetGUID = SafeUnitGUID(arg1)
            local stickyRow = IsSafeGUIDKey(targetGUID)
                and guidToRow[targetGUID]
                or nil

            if stickyRow and stickyRow.offscreen then
                CF.ReconcileStickyRow(stickyRow)
                if stickyRow.unit and not stickyRow.cfUnavailable then
                    -- A retained missing nameplate must not block an aura
                    -- refresh for the same, independently readable enemy.
                    local liveUnit = stickyRow.cfLiveUnit
                    if liveUnit and SafeUnitGUID(liveUnit) == stickyRow.guid
                        and UnitIsActuallyDead(liveUnit) == false then
                        stickyRow.cfRetainedAuras = nil
                        if stickyRow.cfAuraUnit ~= liveUnit then
                            local ok = pcall(CF.SetRowAuraUnit,stickyRow,liveUnit)
                            if not ok then
                                CF.DiscardRetainedAuras(stickyRow,"binding_failed")
                                stickyRow.cfLiveUnit = nil
                                return
                            end
                        end
                    end
                    ApplySpellFilterToRow(stickyRow, GetAuraContext())
                    RefreshDotSortForRow(stickyRow)
                end
            end
        end

    elseif event == "ENCOUNTER_START" then
        CF.PerformanceMarkEncounterStart(arg1, arg2)
        UpdateRaidCurseWatcher()

    elseif event == "ENCOUNTER_END" then
        local arg4, arg5, arg6 = ...
        -- Handler parameters already consumed arg1..arg3, so ENCOUNTER_END's
        -- success flag is the second value in varargs (arg5 overall).
        CF.PerformanceMarkEncounterEnd(arg1, arg2, arg5, arg6)
        UpdateRaidCurseWatcher()

    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        UpdateRaidCurseWatcher()

    elseif event == "PLAYER_DEAD" then
        CF.PerformanceMarkPlayerDeath()

    elseif event == "RAID_TARGET_UPDATE" then
        LayoutRows()

    elseif event == "GROUP_ROSTER_UPDATE" then
        ApplySpellFiltersToAllRows()
        RefreshDisplayPolicy()
        UpdateRaidCurseWatcher()

    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        -- The event alone cannot identify our fight. Refresh only through the
        -- recording's checked native-session window; never copy the last ID.
        local damageType=(Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
        if not IsSecretValue(arg1) and arg1==damageType and CF.performanceActive then
            CF.PerformanceCaptureCurrentDamage(CF.performanceActive,false)
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        CF.RefreshMainWindowVisibility(false)
        if CF.classRanksDirty and CF.RefreshClassSpellRanks() then ApplySpellFiltersToAllRows() end
        CF.PerformanceFinalize()
        ClearEngagementMemory()
        RefreshDisplayPolicy()
        CF.PruneTransientTargetCaches(true)

        -- Anything still left in the GUID map after the out-of-combat policy
        -- is stale bookkeeping and can be dropped.
        for guid, row in pairs(guidToRow) do
            if not row.unit then
                guidToRow[guid] = nil
            end
        end

        UpdateRaidCurseWatcher()

        if CF.FinishTrackerTrace then CF.FinishTrackerTrace() end

    elseif event == "PLAYER_REGEN_DISABLED" then
        CF.RefreshMainWindowVisibility(true)
        CF.PerformanceStart()
        RefreshDisplayPolicy()
        UpdateRaidCurseWatcher()

    elseif event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_THREAT_SITUATION_UPDATE"
        or event == "UNIT_PET"
    then
        RefreshDisplayPolicy()
        UpdateRaidCurseWatcher()
    end
end)

CF:SetScript("OnUpdate", function(self, elapsed)
    CF.PruneTransientTargetCaches()
    CF.PerformanceObserveIdleDamageSessions()
    CF.performanceAuraPoll=(CF.performanceAuraPoll or 0)+elapsed
    if CF.performanceAuraPoll>=0.10 then
        CF.performanceAuraPoll=0
        CF.PerformanceResolvePending(false)
    end
    CF.PerformanceTick(elapsed)
    refreshElapsed = refreshElapsed + elapsed

    if main
        and main.nameplateWarning
        and main.nameplateWarning:IsShown()
    then
        nameplateWarningBlinkElapsed =
            (nameplateWarningBlinkElapsed + elapsed) % NAMEPLATE_WARNING_PERIOD

        local phase =
            (nameplateWarningBlinkElapsed / NAMEPLATE_WARNING_PERIOD)
            * (math.pi * 2)

        -- Deliberately gentle: never disappears completely, just breathes.
        local alpha = 0.48 + (0.30 * ((math.sin(phase) + 1) * 0.5))
        main.nameplateWarning:SetAlpha(alpha)
    end

    if refreshElapsed >= REFRESH_INTERVAL then
        refreshElapsed = 0
        RefreshDisplayPolicy()
        UpdateRaidCurseWatcher()

        -- Defensive refresh in case a beta build changes without firing CVAR_UPDATE.
        UpdateNameplateRequirementWarning()
    end
end)

SLASH_CURSIVEFOREVER1 = "/cf"
SLASH_CURSIVEFOREVER2 = "/cursiveforever"

SlashCmdList.CURSIVEFOREVER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "diagnose" or msg == "diagnostics"
        or msg == "diag" or msg == "auradiag" or msg == "aura diag"
        or msg == "perfdiag" or msg == "performance diag"
        or msg == "markerdiag" or msg == "marker diag"
        or msg == "cursediag" or msg == "curse diag" then
        CF.ShowStatusReport()

    elseif msg == "cursetest" or msg == "curse test" then
        ToggleRaidCurseTest()

    elseif msg == "curse" or msg == "fluch" then
        ShowCurseWatcherOptions()

    elseif msg == "dots" or msg == "anordnung" then
        CF.ShowAuraLayoutOptions()

    elseif msg == "scan" or msg == "debug" then
        Print(CF.T("RETIRED_COMMAND"))

    elseif msg == "grimoire" or msg == "full" or msg == "minimal" then
        db.optionsDesign=msg=="minimal" and "minimal" or "FULL"
        ShowOptions()

    elseif msg == "options" or msg == "option" or msg == "opt" then
        ShowOptions()

    elseif msg == "performance" or msg == "perf" then
        CF.ShowPerformance()

    elseif msg == "history" or msg == "changelog" then
        ShowHistory()

    elseif msg == "filters" or msg == "filter" or msg == "spells" then
        ShowSpellFilter()

    elseif msg == "cards" or msg == "karten" then
        CF.ShowCardSelection()

    elseif msg == "owl" or msg == "owlcorner" or msg == "banther" then
        ShowOwlFilter()

    elseif msg == "show" then
        CF.SetMainWindowManuallyHidden(false)
        RescanVisibleNameplates()

    elseif msg == "hide" then
        CF.SetMainWindowManuallyHidden(true)

    elseif msg == "reset" then
        if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return end
        db.point = nil
        db.relativePoint = nil
        db.x = nil
        db.y = nil
        RestorePosition()
        Print(CF.T("POSITION_RESET"))

    else
        Toggle()
    end
end
