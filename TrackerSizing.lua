local _, addon = ...
local CF = addon and addon.CF
if not CF then return end

-- These preferences describe public, addon-owned layout geometry only.
-- They never alter scale on individual icons, fonts or native aura widgets.
local function viewKey(view)
    view = view or (CF.GetTrackerView and CF.GetTrackerView())
        or (CursiveForeverDB and CursiveForeverDB.trackerView)
    return (view == "matrix" or view == "bars" or view == "healthbar") and view or "standard"
end
local function factor(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    return math.floor(math.max(.5,math.min(1.5,value))*100+.5)/100
end
function CF.GetTrackerSizing(view)
    local saved = CursiveForeverDB and CursiveForeverDB.trackerSizing
    local entry = type(saved) == "table" and saved[viewKey(view)]
    if type(entry) ~= "table" then return 1,1 end
    return factor(entry.width),factor(entry.height)
end
local function refresh()
    if CF.ApplyAuraLayoutToAllRows then CF.ApplyAuraLayoutToAllRows() end
    if CF.RefreshTrackerSizingControls then CF.RefreshTrackerSizingControls() end
end
function CF.SetTrackerSizing(axis,value,view)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if not CursiveForeverDB or (axis ~= "width" and axis ~= "height") then return false end
    if type(CursiveForeverDB.trackerSizing) ~= "table" then CursiveForeverDB.trackerSizing={} end
    local key = viewKey(view)
    local width,height = CF.GetTrackerSizing(key)
    CursiveForeverDB.trackerSizing[key]={width=width,height=height}
    CursiveForeverDB.trackerSizing[key][axis]=factor(value)
    refresh()
    return true
end
function CF.ResetTrackerSizing(view)
    if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false end
    if CursiveForeverDB and type(CursiveForeverDB.trackerSizing) == "table" then
        CursiveForeverDB.trackerSizing[viewKey(view)]=nil
    end
    refresh()
end
function CF.ResolveTrackerWidth(baseWidth,minWidth,view)
    local width = CF.GetTrackerSizing(view)
    return math.max(minWidth,math.floor(baseWidth*width+.5))
end
function CF.ResolveTrackerHeight(baseHeight,minHeight,view)
    local _,height = CF.GetTrackerSizing(view)
    return math.max(minHeight,math.floor(baseHeight*height+.5))
end
