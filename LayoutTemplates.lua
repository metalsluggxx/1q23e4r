local _,addon=...
local CF=addon.CF
local P={VERSION=1,MAX_BYTES=8192,MAX_TEMPLATES=32}
CF.LayoutTemplates=P
local bools={showHeader=true,hideTrackerFrame=true,trackerExtraIcons=true,barsShowSpellNames=true,portraitCurses=true,showTargetOutOfCombat=true,hideWindowOutOfCombat=true}
local ranges={frameScale={.4,1.3},windowTransparency={0,80},auraVeilOpacity={0,100}}
local choices={trackerView={standard=true,matrix=true,bars=true,healthbar=true},auraOrderMode={fixed=true,expiration=true},healthDisplayMode={bar=true,percent=true},executeMode={auto=true,off=true,['20']=true,['35']=true}}
local views={'standard','matrix','bars','healthbar'}
for _,view in ipairs(views) do for _,axis in ipairs({'width','height'}) do ranges[view..'_'..axis]={.5,1.5} end end
local function combat() return InCombatLockdown and InCombatLockdown() end
P.InCombat=combat
local function clone(t) local r={} for k,v in pairs(t) do r[k]=type(v)=='table' and clone(v) or v end return r end
local function edition() return CF.Client and CF.Client.edition or 'Forever' end
local function validToken(s) return type(s)=='string' and #s>0 and #s<=48 and s:match('^[%w_]+$') end
function P.Validate(data)
 if type(data)~='table' or data.version~=1 or not validToken(data.class) or not validToken(data.edition) or type(data.values)~='table' or type(data.slots)~='table' then return nil,'format' end
 local out={version=1,class=data.class,edition=data.edition,values={},slots={}}
 for key,value in pairs(data.values) do
  if bools[key] then if type(value)~='boolean' then return nil,'value' end
  elseif ranges[key] then local r=ranges[key];if type(value)~='number' or value~=value or value<r[1] or value>r[2] then return nil,'range' end
  elseif choices[key] then if type(value)~='string' or not choices[key][value] then return nil,'choice' end
  else return nil,'field' end
  out.values[key]=value
 end
 local seen,count={},0
 for index,key in pairs(data.slots) do
  if type(index)~='number' or index%1~=0 or index<1 or index>8 or not validToken(key) or seen[key] then return nil,'slots' end
  seen[key]=true;count=count+1;out.slots[index]=key
 end
 if #out.slots~=count then return nil,'slots' end
 return out
end
function P.Capture()
 local db=CursiveForeverDB
 local data={version=1,class=CF.GetPerformanceClassFile(),edition=edition(),values={},slots=CF.GetAuraSlotKeys()}
 for key in pairs(bools) do if type(db[key])=='boolean' then data.values[key]=db[key] end end
 for key in pairs(choices) do if db[key]~=nil then data.values[key]=db[key] end end
 for key in pairs(ranges) do if db[key]~=nil then data.values[key]=db[key] end end
 for _,view in ipairs(views) do local w,h=CF.GetTrackerSizing(view);data.values[view..'_width']=w;data.values[view..'_height']=h end
 return P.Validate(data)
end
function P.Encode(data)
 local d,err=P.Validate(data);if not d then return nil,err end
 local lines={'CURSIVE-LAYOUT:1','edition='..d.edition,'class='..d.class,'slots='..table.concat(d.slots,',')}
 local keys={} for k in pairs(d.values) do keys[#keys+1]=k end table.sort(keys)
 for _,k in ipairs(keys) do lines[#lines+1]=k..'='..tostring(d.values[k]) end
 return table.concat(lines,'\n')
end
-- Bounded data-only grammar. Never loadstring, execute, or deserialize Lua.
function P.Decode(text)
 if type(text)~='string' or #text>P.MAX_BYTES then return nil,'size' end
 text=text:gsub('\r',''):gsub('^%s+',''):gsub('%s+$','')
 if text:sub(1,17)~='CURSIVE-LAYOUT:1\n' then return nil,'version' end
 local d={version=1,values={},slots={}};local seen={}
 for line in text:sub(18):gmatch('[^\n]+') do
  local k,v=line:match('^([%w_]+)=(.*)$')
  if not k or seen[k] then return nil,'field' end seen[k]=true
  if k=='class' or k=='edition' then d[k]=v
  elseif k=='slots' then
   if v~='' and (v:sub(1,1)==',' or v:sub(-1)==',' or v:find(',,',1,true)) then return nil,'slots' end
   for slot in v:gmatch('[^,]+') do d.slots[#d.slots+1]=slot end
  elseif bools[k] then if v~='true' and v~='false' then return nil,'value' end d.values[k]=v=='true'
  elseif ranges[k] then d.values[k]=tonumber(v);if not d.values[k] then return nil,'number' end
  elseif choices[k] then d.values[k]=v
  else return nil,'field' end
 end
 if not seen.slots then return nil,'slots' end
 return P.Validate(d)
end
local function storage()
 local db=CursiveForeverDB;db.layoutTemplates=type(db.layoutTemplates)=='table' and db.layoutTemplates or {}
 return db.layoutTemplates
end
function P.List() local names={} for name in pairs(storage()) do names[#names+1]=name end table.sort(names);return names end
function P.Save(name,data)
 if combat() then return false,'combat' end
 if type(name)~='string' then return false,'name' end
 name=name:match('^%s*(.-)%s*$')
 if #name<1 or #name>60 or name:find('[%c|]') then return false,'name' end
 local s=storage();if s[name] then return false,'exists' end
 if #P.List()>=P.MAX_TEMPLATES then return false,'limit' end
 local d,err=P.Validate(data or P.Capture());if not d then return false,err end
 s[name]=clone(d);return true
end
function P.Delete(name)
 if combat() then return false,'combat' end
 storage()[name]=nil;return true
end
function P.Get(name) local d=storage()[name];if d then return P.Validate(d) end end
function P.Apply(data)
 if combat() then return false,'combat' end
 local d,err=P.Validate(data);if not d then return false,err end
 if d.edition~=edition() then return false,'edition' end
 -- Different classes may share appearance, but never their spell selections.
 local slots
 if d.class==CF.GetPerformanceClassFile() then
  slots=CF.NormalizeAuraSlotKeys(d.slots)
  if #slots~=#d.slots then return false,'spells' end
 end
 -- Retained native aura contents cannot be moved into a different presentation.
 -- Reject before writing anything; preserve the established offscreen behavior.
 for _,row in ipairs(CF.GetExperimentalRows and CF.GetExperimentalRows() or {}) do
  if row.unit and row.offscreen and row.cfRetainedAuras then return false,'retained' end
 end
 if CF.ClickLayoutLocked and CF.ClickLayoutLocked() then return false,'combat' end
 local db=CursiveForeverDB
 local backup,backupError=P.Capture();if not backup then return false,backupError end
 local settings=CF.GetPerformanceCharacterSettings()
 local oldValues={};for k in pairs(d.values) do oldValues[k]=db[k] end
 for k in pairs(choices) do oldValues[k]=db[k] end
 local oldFlags={}
 for _,k in ipairs({'matrixViewUnavailable','matrixFallbackDeferred','barsViewUnavailable','barsFallbackDeferred'}) do oldFlags[k]=CF[k] end
 local oldSizing=type(db.trackerSizing)=='table' and clone(db.trackerSizing) or db.trackerSizing
 local oldSlots=settings.auraSlotKeys and clone(settings.auraSlotKeys)
 local pendingView,pendingOrder,pendingExtras=CF.pendingTrackerView,CF.pendingAuraOrderMode,CF.pendingTrackerExtraIcons
 -- This is intentionally session-frozen by the existing native aura renderer.
 CF.GetAppliedAuraVeilOpacity()
 local function refresh()
  if CursiveForeverFrame then CursiveForeverFrame:SetScale(db.frameScale or 1) end
  if CF.SetTrackerView(db.trackerView)==false then error('view unavailable') end
  CF.SetHealthDisplayMode(db.healthDisplayMode)
  CF.ApplyWindowTransparency()
  CF.SetExecuteMode(db.executeMode)
  CF.RefreshMainWindowVisibility(false)
  CF.RefreshAuraLayoutOptions()
  CF.RefreshOptionsPages()
  if CF.Experimental and CF.Experimental.RefreshSettings then CF.Experimental.RefreshSettings() end
 end
 for k,v in pairs(d.values) do
  local view,axis=k:match('^(%w+)_(width)$');if not view then view,axis=k:match('^(%w+)_(height)$') end
  if view then db.trackerSizing=db.trackerSizing or {};db.trackerSizing[view]=db.trackerSizing[view] or {};db.trackerSizing[view][axis]=v
  else db[k]=v end
 end
 if slots then settings.auraSlotKeys=clone(slots) end
 CF.pendingTrackerView=nil;CF.pendingAuraOrderMode=nil;CF.pendingTrackerExtraIcons=nil
 local ok=pcall(refresh)
 if not ok then
  for k in pairs(d.values) do if not k:match('_width$') and not k:match('_height$') then db[k]=oldValues[k] end end
  for k in pairs(choices) do db[k]=oldValues[k] end
  db.trackerSizing=oldSizing;settings.auraSlotKeys=oldSlots
  pcall(refresh)
  for k in pairs(choices) do db[k]=oldValues[k] end
  for _,k in ipairs({'matrixViewUnavailable','matrixFallbackDeferred','barsViewUnavailable','barsFallbackDeferred'}) do CF[k]=oldFlags[k] end
  CF.pendingTrackerView,CF.pendingAuraOrderMode,CF.pendingTrackerExtraIcons=pendingView,pendingOrder,pendingExtras
  return false,'apply'
 end
 db.layoutTemplateBackup=backup
 return true,CF.HasPendingAuraAppearance() and 'appearance' or nil
end
P.Edition=edition
