local _, addon = ...
local build = assert(addon.Build, "Cursive build information missing")
local client = { build=build, edition=build.edition }
addon.Client = client
client.isForever = build.edition == "Forever"
client.classicAuras = build.edition == "Era" or build.edition == "MoP"
client.supportsAnalysis = client.isForever
client.supportsSuggestions = client.isForever
client.minimapRadiusMin = client.classicAuras and 70 or 80
client.minimapRadiusMax = client.classicAuras and 115 or 125
client.title = "Cursive "..(build.edition == "Era" and "Classic Era" or build.edition == "MoP" and "MoP Classic" or build.edition)
if not client.isForever then
    client.dbName="Cursive"..build.edition.."DB"
    client.experimentalDBName="Cursive"..build.edition.."ExperimentalDB"
end
function client.LoadSavedVariables()
    -- SavedVariables arrive after the TOC files, immediately before our
    -- ADDON_LOADED. Import both roots before defaults can publish any aliases.
    if client.savedVariablesLoaded then return end
    client.savedVariablesLoaded = true
    if not client.isForever then
        CursiveForeverDB=_G[client.dbName]
        CursiveForeverExperimentalDB=_G[client.experimentalDBName]
    end
end
function client.BindSavedVariables()
    if not client.isForever and client.savedVariablesLoaded then
        _G[client.dbName]=CursiveForeverDB
        _G[client.experimentalDBName]=CursiveForeverExperimentalDB
    end
end

-- These checks never coerce or compare a protected value. The fallback is
-- for public APIs on older clients without secret-value support.
function client.Readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        local ok, access = pcall(canaccessvalue, value)
        if not ok or not access then return false end
    end
    return true
end
function client.ReadableTable(value)
    if not client.Readable(value) or type(value) ~= "table" then return false end
    if type(canaccesstable) == "function" then
        local ok, access = pcall(canaccesstable, value)
        if not ok or not access then return false end
    end
    return true
end
client.sortMethod = AuraContainerSortMethod or (Enum and Enum.AuraContainerSortMethod)
client.sortDirection = AuraContainerSortDirection or (Enum and Enum.AuraContainerSortDirection)
if client.classicAuras then
    -- Private constants for our own container, not replacement Blizzard globals.
    client.sortMethod = { ExpirationOnly=1 }
    client.sortDirection = { Normal=1 }
end
function client.CreateAuraContainer(parent)
    if client.classicAuras then return addon.ClassicAuraBackend.Create(parent) end
    return CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
end
