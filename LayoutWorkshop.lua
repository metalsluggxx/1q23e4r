local _,addon=...
local CF=addon.CF
local P=CF.LayoutTemplates
local W={count=3}
CF.LayoutWorkshop=W
local localized={}
local function tr(de,en) local t=CF.GetEffectiveLanguage()=='de' and de or en;localized[t]={de,en};return t end
local function remember(f,t) if localized[t] then f.cfWorkshopText=localized[t] end end
local function label(parent,text,x,y,width)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');f:SetPoint('TOPLEFT',x,-y);f:SetWidth(width or 280);f:SetJustifyH('LEFT');f:SetText(text);remember(f,text);parent.cfLabels=parent.cfLabels or {};parent.cfLabels[#parent.cfLabels+1]=f;return f
end
local function button(parent,text,x,y,width,fn)
 local f=CreateFrame('Button',nil,parent,'BackdropTemplate');f:SetPoint('TOPLEFT',x,-y);f:SetSize(width,24)
 f.cfLabel=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');f.cfLabel:SetText(text)
 f.cfWorkshopButton=true;remember(f.cfLabel,text);parent.cfButtons=parent.cfButtons or {};parent.cfButtons[#parent.cfButtons+1]=f
 f:SetScript('OnClick',fn)
 if CF.MinimalOptions then CF.MinimalOptions.Button(f) end
 return f
end
local function panel(width,height)
 local f=CreateFrame('Frame',nil,UIParent,'BackdropTemplate');f:SetSize(width,height);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG')
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});f:SetBackdropColor(.035,.03,.025,.98);f:SetBackdropBorderColor(.65,.5,.2,1)
 f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton');f:SetScript('OnDragStart',f.StartMoving);f:SetScript('OnDragStop',f.StopMovingOrSizing)
 local close=button(f,'X',width-34,6,26,function() f:Hide() end);close:ClearAllPoints();close:SetPoint('TOPRIGHT',-8,-6);f.close=close;return f
end
-- Keep complete ordinary UI trees in non-overlapping level bands. A root
-- Raise() alone can leave another window's higher-level controls in front.
local function topLevel(frame)
 local top=frame:GetFrameLevel()
 for _,child in ipairs({frame:GetChildren()}) do top=math.max(top,topLevel(child)) end
 return top
end
local function layerTree(frame,level,strata)
 -- SetFrameLevel also shifts descendants in the client. Never derive new
 -- levels from those already-shifted values: reopening must not accumulate.
 frame:SetFrameStrata(strata or 'FULLSCREEN_DIALOG');frame:SetFrameLevel(level)
 local top=level
 for _,child in ipairs({frame:GetChildren()}) do
  top=math.max(top,layerTree(child,level+1,strata))
 end
 return top
end
function W.SyncLayers()
 local level=CF.optionsPagesFrame and topLevel(CF.optionsPagesFrame)+10 or 100
 if W.frame and not W.frame.cfEmbedded then level=layerTree(W.frame,level)+10 end
 if W.preview then layerTree(W.preview,level) end
end
function W.PrepareOptions()
 -- An explicit options request must not disappear behind a floating preview.
 if W.preview then W.preview:Hide() end
 if W.frame and not W.frame.cfEmbedded then W.frame:Hide() end
end
local function errorText(code)
 local messages={retained={'Gegnerdaten werden noch außerhalb der Sicht aufbewahrt. Bitte nach Freigabe dieser Zeilen erneut laden.','Offscreen enemy data is still retained. Try again once these rows are released.'},apply={'Layout konnte nicht angewendet werden. Die bisherigen Einstellungen wurden wiederhergestellt.','Could not apply layout. Previous settings were restored.'},missing={'Bitte zuerst eine gespeicherte Vorlage auswählen.','Select a saved template first.'},backup={'Noch kein vorheriges Layout vorhanden.','No previous layout available yet.'},combat={'Nur außerhalb des Kampfes.','Available out of combat only.'},exists={'Name bereits vergeben. Bitte neuen Namen wählen.','Name already exists. Choose a new name.'},edition={'Vorlage gehört zu einer anderen Spielversion.','Template belongs to another game edition.'},spells={'Einige Hauptzauber sind hier nicht verfügbar.','Some main spells are unavailable here.'},limit={'Maximal 32 Vorlagen.','Maximum 32 templates.'},name={'Bitte einen Namen mit 1–60 Zeichen eingeben.','Enter a name of 1–60 characters.'}}
 local m=messages[code];return m and tr(m[1],m[2]) or tr('Ungültiger Vorlagencode.','Invalid template code.')
end
-- Deterministic fictional timers: exactly three seconds absent after expiry.
function W.Timer(elapsed,row,index)
 local duration=12+index*3;local phase=(elapsed+(row-1)*2+(index-1)*1.7)%(duration+3)
 return phase<duration and duration-phase or nil,duration
end
function W.Included(row,index) return row==1 or index<=((row-2)%3==0 and 1 or 3) end
function W.BuildSpells()
 local byKey,all={},CF.GetAuraLayoutCatalog();for _,s in ipairs(all) do byKey[s.key]=s end
 local main,extra,used={},{},{}
 for _,k in ipairs(CF.GetAuraSlotKeys()) do if byKey[k] then main[#main+1]=byKey[k];used[k]=true end end
 -- An empty main selection stays empty: the preview must not alter it.
 local curse=false
 for _,s in ipairs(all) do
  local isCurse=s.key:match('^curse_')
  if not used[s.key] and #extra<4 and (not isCurse or not curse) then extra[#extra+1]=s;if isCurse then curse=true end end
 end
 local function enrich(list) local out={} for _,s in ipairs(list) do local id=s.ids and s.ids[1];out[#out+1]={key=s.key,name=CF.SafeSpellName(id) or s.fallback or s.key,icon=CF.SafeSpellTexture(id)} end return out end
 return enrich(main),enrich(extra)
end
local function cell(parent)
 local f=CreateFrame('Frame',nil,parent);f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetAllPoints()
 f.shade=f:CreateTexture(nil,'OVERLAY');f.shade:SetAllPoints();f.shade:SetColorTexture(0,0,0,.7)
 f.time=label(f,'',0,0,34);f.time:SetJustifyH('CENTER');f.time:SetTextColor(1,1,1,1)
 f.bar=CreateFrame('StatusBar',nil,f);f.bar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar');f.bar:SetMinMaxValues(0,1);f.bar:SetStatusBarColor(.5,.22,.72)
 f.name=label(f.bar,'',3,2,120);return f
end
local function rowFrame(parent)
 local r=CreateFrame('Frame',nil,parent,'BackdropTemplate');r.cells={};r.extras={}
 r:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
 r.portrait=r:CreateTexture(nil,'ARTWORK');r.portrait:SetTexture('Interface\\Icons\\Ability_Hunter_Pet_Cat');r.portrait:SetPoint('TOPLEFT',4,-4);r.portrait:SetSize(32,32)
 r.hp=CreateFrame('StatusBar',nil,r);r.hp:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar');r.hp:SetMinMaxValues(0,100);r.hp:SetStatusBarColor(.15,.6,.25)
 r.hpText=label(r.hp,'',2,1,60);r.name=label(r,'',44,4,110)
 for i=1,8 do r.cells[i]=cell(r) end
 for i=1,4 do r.extras[i]=cell(r) end
 return r
end
local function geometry()
 local view=CF.GetTrackerView();local x=CF.GetAuraLayoutColumns().auraX;local w=CF.GetStandardRowWidth()
 if view=='matrix' then x=CF.GetMatrixAuraX();w=CF.GetMatrixRowWidth()
 elseif view=='bars' then x=CF.GetBarsAuraX();w=CF.GetBarsRowWidth()
 elseif view=='healthbar' then x=CF.GetHealthbarAuraX();w=CF.GetHealthbarRowWidth() end
 return view,w,CF.GetAuraLayoutRowHeight(),x
end
function W.Draw(elapsed)
 local f=W.preview;if not f or not f:IsShown() then return end
 if P.InCombat() then f:Hide();return end
 local db=CursiveForeverDB;local view,width,height,x=geometry();local matrix=view=='matrix';local bars=view=='bars'
 local top=matrix and 28 or 4;local main=W.main or {};local extra=W.extra or {}
 local requested=db.frameScale or 1
 -- Keep ten tall Bars rows reachable in a scrollable viewport.
 local headerHeight=db.showHeader~=false and 26 or 0
 local bodyHeight=W.count*height+top+headerHeight
 local visibleHeight=math.max(80,math.min(bodyHeight,(UIParent:GetHeight()-130)/requested))
 local scale=math.min(requested,(UIParent:GetWidth()-60)/(width+46))
 f:SetScale(scale);f:SetSize(math.max(360,width+46),visibleHeight+74);f.scroll:SetSize(width+16,visibleHeight);f.body:SetSize(width,bodyHeight)
 f.caption:SetText(tr('ANSICHTSVORSCHAU · fiktive Daten','DISPLAY PREVIEW · fictional data'))
 f.header:SetText(db.showHeader~=false and 'Cursive · '..tr('Vorschau','Preview') or '')
 for i=1,8 do
  local h=f.headers[i];h:Hide()
  if matrix and main[i] then h:SetTexture(main[i].icon);h:ClearAllPoints();h:SetPoint('TOPLEFT',f.body,'TOPLEFT',x+(i-1)*28,-headerHeight);h:Show() end
 end
 for n=1,10 do
  local row=f.rows[n];row:Hide()
  if n<=W.count then
   row:Show();row:SetSize(width,height-2);row:ClearAllPoints();row:SetPoint('TOPLEFT',f.body,'TOPLEFT',0,-(headerHeight+top+(n-1)*height))
   row:SetAlpha(1-CF.GetWindowTransparency()/100)
   local frame=not db.hideTrackerFrame
   row:SetBackdropColor(.04,.035,.03,frame and .85 or 0);row:SetBackdropBorderColor(.8,.65,.2,frame and 1 or 0)
   local columns=CF.GetAuraLayoutColumns()
   local hp=math.max(8,100-n*8)
   local px,ps,hy,hx,hw=columns.portraitLeft,columns.portraitSize,20,columns.healthX,columns.healthWidth
   local py=math.max(4,(height-ps)/2-4)
   if matrix then px,ps,py=4,24,CF.GetMatrixIconCenter()-12;hw=CF.GetMatrixHealthWidth();hx=x-hw-10;hy=CF.GetMatrixIconCenter()-6
   elseif bars then px,ps,py=5,38,4;hx,hy,hw=5,60,104
   elseif view=='healthbar' then px,ps,py=4,34,CF.GetHealthbarTop();hx,hy,hw=44,CF.GetHealthbarTop(),CF.GetHealthbarHealthWidth() end
   row.portrait:ClearAllPoints();row.portrait:SetPoint('TOPLEFT',px,-py);row.portrait:SetSize(ps,ps)
   row.name:SetParent(row);row.name:ClearAllPoints();row.name:SetPoint('TOPLEFT',hx,-math.max(2,hy-12));row.name:SetWidth(hw);row.name:SetText(tr('Gegner ','Enemy ')..n)
   row.hp:ClearAllPoints();row.hp:SetPoint('TOPLEFT',hx,-hy);row.hp:SetSize(hw,view=='healthbar' and CF.GetHealthbarHealthHeight() or 12);row.hp:SetValue(hp);row.hpText:SetText(hp..'%');row.hp:SetAlpha(db.healthDisplayMode=='percent' and 0 or 1)
   if view=='healthbar' then
    row.hp:SetAlpha(1);row.name:SetParent(row.hp);row.name:ClearAllPoints();row.name:SetPoint('TOPLEFT',2,-2);row.hpText:ClearAllPoints();row.hpText:SetPoint('BOTTOMLEFT',2,2)
   else row.hpText:ClearAllPoints();row.hpText:SetPoint('TOPLEFT',2,-1) end
   if db.healthDisplayMode=='percent' and view~='healthbar' then row.name:SetText(tr('Gegner ','Enemy ')..n..' · '..hp..'%') end
   local order={};for i,s in ipairs(main) do local rem,d=W.Timer(elapsed,n,i);if not W.Included(n,i) then rem=nil end;order[#order+1]={s=s,remaining=rem,duration=d,index=i} end
   if not matrix and not bars and CF.GetAuraOrderMode()=='expiration' then table.sort(order,function(a,b) local av,bv=a.remaining or 1e9,b.remaining or 1e9;if av==bv then return a.index<b.index end return av<bv end) end
   for i=1,8 do local c=row.cells[i];c:Hide();local e=order[i]
    if e then
     c:Show();local size=matrix and 26 or bars and 16 or 34
     local dx,dy=(i-1)*38,4
     if matrix then dx,dy=(i-1)*28,CF.GetMatrixIconCenter()-13 elseif view=='healthbar' then dy=CF.GetHealthbarTop() elseif bars then dx,dy=CF.GetBarsSlotPosition(i);dy=dy+CF.GetBarsTop() end
     c:SetSize(size,size);c:ClearAllPoints();c:SetPoint('TOPLEFT',row,'TOPLEFT',x+dx,-dy);c.icon:SetTexture(e.s.icon);c.icon:SetAlpha(matrix and 0 or 1)
     c.shade:SetShown(not e.remaining and not matrix);c.time:ClearAllPoints();c.time:SetPoint('TOPLEFT',0,matrix and -5 or -size);c.time:SetWidth(size)
     c.time:SetText(e.remaining and tostring(math.ceil(e.remaining)) or '—');c.bar:Hide()
     if bars then c.bar:Show();c.bar:ClearAllPoints();c.bar:SetPoint('TOPLEFT',c,'TOPRIGHT',2,0);c.bar:SetSize(CF.GetBarsSlotsWidth()-18,16);c.bar:SetValue(e.remaining and e.remaining/e.duration or 0);c.name:SetWidth(CF.GetBarsSlotsWidth()-58);c.name:SetText(db.barsShowSpellNames~=false and e.s.name or '');c.time:ClearAllPoints();c.time:SetPoint('TOPRIGHT',c.bar,'TOPRIGHT',0,0);c.time:SetWidth(32) end
    end
   end
   for i=1,4 do local c=row.extras[i];c:Hide()
    if db.trackerExtraIcons~=false and extra[i] and (n==1 or i<=n%3) then
     local rem=W.Timer(elapsed,n,i+8);c:Show();c:SetSize(14,14);c:ClearAllPoints()
     local ex,ey=width-60,4;if bars then ex,ey=CF.GetBarsExtraPosition() end
     if matrix then ex=x+#main*28+8;ey=CF.GetMatrixIconCenter()-14 end
     c:SetPoint('TOPLEFT',row,'TOPLEFT',ex+((i-1)%2)*(matrix and 48 or 22),-ey-math.floor((i-1)/2)*(matrix and 16 or 24));c.icon:SetTexture(extra[i].icon);c.shade:SetShown(not rem);c.bar:Hide();c.time:SetWidth(20);c.time:ClearAllPoints();c.time:SetPoint('TOPLEFT',matrix and 15 or -3,matrix and 0 or -14);c.time:SetText(rem and math.ceil(rem) or '—')
    end
   end
  end
 end
end
function W.ShowPreview()
 if P.InCombat() then return false end
 W.main,W.extra=W.BuildSpells()
 if not W.preview then
  local f=panel(500,360);W.preview=f;f.caption=label(f,'',12,10,420);f.header=label(f,'',0,0,400)
  f.scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate');f.scroll:SetPoint('TOPLEFT',10,-64)
  f.body=CreateFrame('Frame',nil,f.scroll);f.scroll:SetScrollChild(f.body);f.header:SetParent(f.body);f.header:ClearAllPoints();f.header:SetPoint('TOPLEFT',0,0)
  f.headers={};for i=1,8 do f.headers[i]=f.body:CreateTexture(nil,'ARTWORK');f.headers[i]:SetSize(20,20) end
  f.rows={};for i=1,10 do f.rows[i]=rowFrame(f.body) end
  local slider=CreateFrame('Slider',nil,f,'OptionsSliderTemplate');f.countSlider=slider;slider:SetPoint('TOPLEFT',125,-38);slider:SetSize(180,16);slider:SetMinMaxValues(1,10);slider:SetValueStep(1)
  f.countText=label(f,tr('Gegner: ','Enemies: ')..W.count,12,34,110)
  slider:SetScript('OnValueChanged',function(_,v) W.count=math.max(1,math.min(10,math.floor(v+.5)));f.countText:SetText(tr('Gegner: ','Enemies: ')..W.count) end);slider:SetValue(W.count)
  f:RegisterEvent('PLAYER_REGEN_DISABLED');f:SetScript('OnEvent',function() f:Hide() end)
  local since=0;f:SetScript('OnUpdate',function(_,dt) since=since+dt;if since>=.1 then since=0;W.Draw(GetTime()-W.started) end end)
 end
 if CF.MinimalOptions then CF.MinimalOptions.StylePreview(W.preview) end
 W.SyncLayers();W.started=GetTime();W.preview:Show();W.Draw(0);return true
end
function W.Show(host)
 -- SlashCmdList passes a string (including an empty string), not a UI host.
 if type(host)=='string' then host=nil end
 if P.InCombat() then return end
 local options=CF.optionsPagesFrame
 if not host and CF.MinimalOptions and options and not options.cfGrimoire then
  options:Show();options.CFSelectPage('templates');return
 end
 if not W.frame then
  local f=panel(630,510);W.frame=f
  f.heading=label(f,tr('Ansichtsvorschau & Layoutvorlagen','Display preview & layout templates'),16,12,550)
  label(f,tr('Vorschau mit fiktiven Zeiten; endet beim Kampfbeginn.','Fictional preview timers; stops when combat starts.'),16,40,590)
  button(f,tr('Vorschau starten','Start preview'),16,64,180,W.ShowPreview)
  button(f,tr('Vorschau beenden','Stop preview'),208,64,180,function() if W.preview then W.preview:Hide() end end)
  label(f,tr('Name der neuen Vorlage:','New template name:'),16,102,350)
  f.name=CreateFrame('EditBox',nil,f,'InputBoxTemplate');f.name:SetAutoFocus(false);f.name:SetMaxLetters(60);f.name:SetPoint('TOPLEFT',22,-124);f.name:SetSize(370,24)
  f.status=label(f,'',16,432,595);f.status:SetHeight(50)
  button(f,tr('Ausgewählte löschen','Delete selected'),408,64,200,function() if f.selected then local ok,err=P.Delete(f.selected);f.status:SetText(ok and tr('Vorlage gelöscht. Aktuelle Ansicht bleibt erhalten.','Template deleted. Current display is retained.') or errorText(err));W.RefreshList() end end)
  button(f,tr('Aktuelles speichern','Save current'),408,124,200,function() local ok,err=P.Save(f.name:GetText());f.status:SetText(ok and tr('Gespeichert.','Saved.') or errorText(err));W.RefreshList() end)
  f.selection=label(f,'',60,166,480);f.index=1
  button(f,'<',16,160,30,function() f.index=f.index-1;W.RefreshList() end)
  button(f,'>',578,160,30,function() f.index=f.index+1;W.RefreshList() end)
  local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',22,-234);scroll:SetSize(560,150)
  f.code=CreateFrame('EditBox',nil,scroll);f.code:SetMultiLine(true);f.code:SetHeight(150);f.code:SetAutoFocus(false);f.code:SetFontObject('GameFontHighlightSmall');f.code:SetWidth(552);f.code:SetMaxLetters(P.MAX_BYTES);scroll:SetScrollChild(f.code)
  button(f,tr('Code exportieren','Export code'),16,196,180,function() local data=f.selected and P.Get(f.selected) or P.Capture();local code,err=P.Encode(data);if code then f.code:SetText(code);f.code:HighlightText();f.code:SetFocus() else f.status:SetText(errorText(err)) end end)
  f.load=button(f,tr('Layout laden','Load layout'),208,196,180,function() W.Load(f.selected and P.Get(f.selected), 'missing') end)
  f.import=button(f,tr('Importieren & laden','Import & load'),16,396,180,function() local d,err=P.Decode(f.code:GetText());W.Load(d,err) end)
  f.reload=button(f,tr('Symboloptik neu laden','Reload icon shading'),208,396,180,function() if not P.InCombat() and CF.HasPendingAuraAppearance() then ReloadUI() end end)
  f.reload:SetShown(CF.HasPendingAuraAppearance())
  button(f,tr('Import speichern','Save import'),408,396,200,function() local d,err=P.Decode(f.code:GetText());if d then local ok,e=P.Save(f.name:GetText(),d);f.status:SetText(ok and tr('Gespeichert.','Saved.') or errorText(e));W.RefreshList() else f.status:SetText(errorText(err)) end end)
  f.restore=button(f,tr('Vorheriges wiederherstellen','Restore previous'),408,196,200,function() W.Load(CursiveForeverDB.layoutTemplateBackup,'backup') end)
  f:RegisterEvent('PLAYER_REGEN_DISABLED');f:SetScript('OnEvent',function() f:Hide() end)
 end
 local f=W.frame
 if host then
  f.cfEmbedded=true;f:SetParent(host);f:ClearAllPoints();f:SetPoint('TOPLEFT',0,0);f:SetMovable(false);f.close:Hide();f:SetBackdrop(nil)
  layerTree(f,host:GetFrameLevel()+1,host:GetFrameStrata())
  if CF.MinimalOptions then CF.MinimalOptions.StyleWorkshop(f) end
 else W.Detach();f.close:Show() end
 W.RefreshLocale()
 W.RefreshList();W.frame.reload:SetShown(CF.HasPendingAuraAppearance());W.SyncLayers();W.frame:Show()
end
function W.Detach()
 local f=W.frame;if not f or not f.cfEmbedded then return end
 if CF.MinimalOptions then CF.MinimalOptions.RestoreWorkshop(f) end
 f:Hide();f.cfEmbedded=nil;f:SetParent(UIParent);f:ClearAllPoints();f:SetPoint('CENTER');f:SetMovable(true);f.close:Show()
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});f:SetBackdropColor(.035,.03,.025,.98);f:SetBackdropBorderColor(.65,.5,.2,1)
end
function W.RefreshLocale()
 local f=W.frame;if not f then return end
 for _,o in ipairs(f.cfLabels or {}) do if o.cfWorkshopText then o:SetText(tr(unpack(o.cfWorkshopText))) end end
 for _,b in ipairs(f.cfButtons or {}) do if b.cfLabel.cfWorkshopText then b.cfLabel:SetText(tr(unpack(b.cfLabel.cfWorkshopText))) end end
end
function W.RefreshList()
 local f=W.frame;local names=P.List();f.index=math.max(1,math.min(#names,f.index));f.selected=names[f.index]
 f.selection:SetText(f.selected or tr('Noch keine gespeicherten Vorlagen','No saved templates yet'))
end
function W.Load(data,missingReason)
 local f=W.frame
 if not data then f.status:SetText(errorText(missingReason));return false end
 local ok,reason=P.Apply(data)
 if not ok then f.status:SetText(errorText(reason));return false end
 f.reload:SetShown(CF.HasPendingAuraAppearance())
 local message=tr('Layout geladen.','Layout loaded.')
 if data.class~=CF.GetPerformanceClassFile() then message=message..tr(' Darstellung übernommen; eigene Hauptzauber beibehalten.',' Appearance applied; own main spells retained.') end
 if reason=='appearance' then message=message..tr(' Nur die geänderte Symbolabdunklung benötigt noch ein Neuladen.',' Only changed icon shading still needs a reload.') end
 f.status:SetText(message)
 W.main,W.extra=W.BuildSpells()
 if W.preview and W.preview:IsShown() then W.Draw(GetTime()-(W.started or GetTime())) end
 return true
end
SLASH_CURSIVELAYOUT1='/cflayout'
SlashCmdList.CURSIVELAYOUT=W.Show
