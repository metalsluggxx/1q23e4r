local _, addon = ...
local CF = addon.CF

-- Only the main tracker window is faded. Options, history, performance and
-- diagnostic windows keep their own opacity. Native aura children inherit the
-- tracker opacity without reading or changing their contents or local alpha.
local mainWindow, mainBaseAlpha
local trackerHeader
local MAX_TRANSPARENCY = 80

local function normalize(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    return math.floor(math.max(0, math.min(MAX_TRANSPARENCY, value)) + 0.5)
end

function CF.GetWindowTransparency()
    return normalize(type(CursiveForeverDB) == "table" and CursiveForeverDB.windowTransparency)
end

function CF.RegisterTrackerHeader(frame)
    if not frame or type(frame.SetIgnoreParentAlpha) ~= "function" then return false end
    frame:SetIgnoreParentAlpha(true)
    frame:SetAlpha(1)
    trackerHeader=frame
    return true
end

function CF.ApplyWindowTransparency()
    if mainWindow then
        mainWindow:SetAlpha(mainBaseAlpha * (1 - CF.GetWindowTransparency() / 100))
    end
    if trackerHeader then trackerHeader:SetAlpha(1) end
end

function CF.RegisterMainWindow(frame)
    -- Reject auxiliary windows even if a future caller registers one by mistake.
    if not frame or type(frame.SetAlpha) ~= "function"
        or type(frame.GetName) ~= "function" or frame:GetName() ~= "CursiveForeverFrame" then return end
    if mainWindow ~= frame then
        mainWindow = frame
        local alpha = frame.GetAlpha and frame:GetAlpha() or 1
        mainBaseAlpha = type(alpha) == "number" and alpha or 1
    end
    CF.ApplyWindowTransparency()
    return frame
end

function CF.SetWindowTransparency(percent)
    if type(CursiveForeverDB) ~= "table" then CursiveForeverDB = {} end
    CursiveForeverDB.windowTransparency = normalize(percent)
    CF.ApplyWindowTransparency()
    return CursiveForeverDB.windowTransparency
end
