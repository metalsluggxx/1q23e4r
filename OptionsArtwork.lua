local _,addon=...
local CF=addon.CF
-- Ordinary options presentation only; never touches tracker or secure buttons.
local A={};CF.OptionsArtwork=A
local MEDIA='Interface\\AddOns\\CursiveCharacterPack\\Media\\Jaina\\'
local BACK={bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1}
local FRAMES,FPS,SCALE=235,24,1360/1664
local function tr(de,en) return CF.GetEffectiveLanguage()=='de' and de or en end
local function at(o,x,y,w,h) o:ClearAllPoints();o:SetPoint('TOPLEFT',x,-y);o:SetSize(w,h) end
local function hook(o,key,fn)
 local old=o:GetScript(key);o:SetScript(key,function(self,...) if old then old(self,...) end;fn(self,...) end)
end
local function label(parent,size)
 local t=parent:CreateFontString(nil,'OVERLAY',size or 'GameFontHighlightSmall')
 t:SetJustifyH('LEFT');t:SetJustifyV('MIDDLE');return t
end
local function light(t)
 if t and t.SetTextColor then t:SetTextColor(.91,.94,.97,1);t:SetShadowOffset(1,-1) end
end
local function button(parent,fn)
 local b=CreateFrame('Button',nil,parent,'BackdropTemplate');b.cfLabel=label(b)
 b:SetScript('OnClick',fn);CF.MinimalOptions.Button(b);return b
end
-- Restyle the existing scroll control only. Its range, dragging and click
-- scripts remain owned by the client's UIPanelScrollFrameTemplate.
local function styleScroll(scroll,on)
 local bar=scroll and scroll.ScrollBar
 local thumb=bar and bar.GetThumbTexture and bar:GetThumbTexture()
 if not thumb then return end
 local s=bar.cfJainaScroll
 if not s and not on then return end
 if not s then
  s={native={},arrows={},thumb={texture=thumb:GetTexture(),coords={thumb:GetTexCoord()},
   atlas=thumb.GetAtlas and thumb:GetAtlas(),color=thumb.GetVertexColor and {thumb:GetVertexColor()} or {1,1,1,1},w=thumb:GetWidth(),h=thumb:GetHeight()}}
  bar.cfJainaScroll=s
  for _,r in ipairs({bar:GetRegions()}) do if r~=thumb then s.native[#s.native+1]={r,r:GetAlpha()} end end
  s.rail=bar:CreateTexture(nil,'BACKGROUND');s.rail:SetPoint('TOP');s.rail:SetPoint('BOTTOM');s.rail:SetWidth(3);s.rail:SetColorTexture(.20,.40,.53,.8)
  for _,spec in ipairs({{'ScrollUpButton','up'},{'ScrollDownButton','down'}}) do
   local b=bar[spec[1]] or scroll[spec[1]]
   if b then
    local plate=button(b,function() end);plate:SetAllPoints(b);plate:EnableMouse(false)
    local item={button=b,plate=plate,native={},kind=spec[2]};s.arrows[#s.arrows+1]=item
    for _,r in ipairs({b:GetRegions()}) do item.native[#item.native+1]={r,r:GetAlpha()} end
    local function refresh()
     plate:SetEnabled(b:IsEnabled());CF.MinimalOptions.Button(plate);CF.MinimalOptions.Symbol(plate,item.kind,true)
    end
    hook(b,'OnEnable',refresh);hook(b,'OnDisable',refresh)
    hook(b,'OnEnter',function() if s.active then plate:GetScript('OnEnter')(plate) end end)
    hook(b,'OnLeave',function() if s.active then refresh() end end)
   end
  end
 end
 if not on and not s.active then return end
 s.active=on;s.rail:SetShown(on)
 for _,v in ipairs(s.native) do v[1]:SetAlpha(on and 0 or v[2]) end
 for _,item in ipairs(s.arrows) do
  for _,v in ipairs(item.native) do v[1]:SetAlpha(on and 0 or v[2]) end
  item.plate:SetShown(on);item.plate:SetEnabled(item.button:IsEnabled())
  if on then CF.MinimalOptions.Button(item.plate);CF.MinimalOptions.Symbol(item.plate,item.kind,true) end
 end
 if on then
  thumb:SetTexture('Interface\\Buttons\\WHITE8X8');thumb:SetTexCoord(0,1,0,1);thumb:SetVertexColor(.50,.81,.98,1);thumb:SetSize(8,20)
 else
  if s.thumb.atlas and thumb.SetAtlas then thumb:SetAtlas(s.thumb.atlas) else thumb:SetTexture(s.thumb.texture or '') end
  thumb:SetTexCoord(unpack(s.thumb.coords));thumb:SetVertexColor(unpack(s.thumb.color));thumb:SetSize(s.thumb.w,s.thumb.h)
 end
end
function A.IsMage() return CF.GetPerformanceClassFile()=='MAGE' end
function A.GetChoices(db)
 return db.optionsArtworkClass or 'auto',db.optionsArtworkGender or db.optionsMageArtwork or 'auto'
end
function A.Requested(db)
 local class,gender=A.GetChoices(db)
 if class=='auto' then class=CF.GetPerformanceClassFile() end
 if class~='MAGE' then return nil end
 if gender=='female' then return 'jaina' end
 if gender~='auto' then return nil end
 local sex=UnitSex and UnitSex('player')
 if issecretvalue and issecretvalue(sex) then return nil end
 if canaccessvalue and not canaccessvalue(sex) then return nil end
 return sex==3 and 'jaina' or nil
end
function A.Resolve(db)
 if A.Requested(db)=='jaina' and CF.CharacterPack.Status()=='available' then return 'jaina' end
end
local classes={'auto','WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','DEATHKNIGHT','SHAMAN','MAGE','WARLOCK','MONK','DRUID','DEMONHUNTER','EVOKER'}
local de={WARRIOR='Krieger',PALADIN='Paladin',HUNTER='Jäger',ROGUE='Schurke',PRIEST='Priester',DEATHKNIGHT='Todesritter',SHAMAN='Schamane',MAGE='Magier',WARLOCK='Hexenmeister',MONK='Mönch',DRUID='Druide',DEMONHUNTER='Dämonenjäger',EVOKER='Rufer'}
local en={WARRIOR='Warrior',PALADIN='Paladin',HUNTER='Hunter',ROGUE='Rogue',PRIEST='Priest',DEATHKNIGHT='Death knight',SHAMAN='Shaman',MAGE='Mage',WARLOCK='Warlock',MONK='Monk',DRUID='Druid',DEMONHUNTER='Demon hunter',EVOKER='Evoker'}
local function available(key) return key=='auto' or key=='WARLOCK' or key=='MAGE' and CF.CharacterPack.Status()=='available' end
function A.RefreshChooser(f)
 local a=f.cfArtwork;local d=a and a.chooser;if not d then return end
 local db=CursiveForeverDB;local class,gender=A.GetChoices(db)
 d.title:SetText(tr('Menümotiv wählen','Choose menu artwork'))
 d.help:SetText(tr('Automatisch richtet sich nach deinem Charakter. Die Auswahl verändert nur das Optionsmenü.','Automatic follows your character. This choice changes only the options menu.'))
 d.classTitle:SetText(tr('Klasse','Class'));d.genderTitle:SetText(tr('Darstellung','Appearance'))
 for key,b in pairs(d.classes) do
  b.cfLabel:SetText(key=='auto' and tr('Automatisch','Automatic') or (CF.GetEffectiveLanguage()=='de' and de[key] or en[key]))
  CF.MinimalOptions.Button(b)
  b.cfLabel:SetTextColor(available(key) and .91 or .43,available(key) and .85 or .43,available(key) and .70 or .43,1)
  b:SetBackdropBorderColor(class==key and .95 or .40,class==key and .80 or .32,class==key and .40 or .18,1)
 end
 for key,b in pairs(d.genders) do
  b.cfLabel:SetText(key=='auto' and tr('Automatisch','Automatic') or key=='female' and tr('Weiblich','Female') or tr('Männlich','Male'))
  CF.MinimalOptions.Button(b)
  b:SetBackdropBorderColor(gender==key and .95 or .40,gender==key and .80 or .32,gender==key and .40 or .18,1)
 end
 d.animation.caption:SetText(tr('Menümotiv animieren','Animate menu artwork'))
 d.animation:SetChecked(db.optionsArtworkAnimation~=false)
 d.status:SetText(A.Resolve(db)=='jaina' and tr('Aktives Motiv: Jaina · Eis und Wasser','Active artwork: Jaina · ice and water') or tr('Aktives Motiv: Gul’dans Grimoire','Active artwork: Gul’dan’s grimoire'))
 d.future:SetText(CF.CharacterPack.Message()..'\n'..tr('Medivh und weitere Motive folgen später. Grimoire und Minimal bleiben immer verfügbar.','Medivh and more artwork will follow later. Grimoire and Minimal are always available.'))
end
function A.OpenChooser(f)
 local a=A.Initialize(f)
 if not a.chooser then
  local d=CreateFrame('Frame','CursiveArtworkChooser',UIParent,'BackdropTemplate');a.chooser=d
  d:SetSize(600,556);d:SetPoint('CENTER',UIParent,'CENTER');d:SetFrameStrata('FULLSCREEN_DIALOG')
  d:SetFrameLevel(f:GetFrameLevel()+100);d:SetClampedToScreen(true);d:EnableMouse(true)
  d:SetBackdrop(BACK);d:SetBackdropColor(.025,.024,.03,1);d:SetBackdropBorderColor(.76,.60,.30,1)
  d:SetMovable(true);d:RegisterForDrag('LeftButton')
  d:SetScript('OnDragStart',function(self) self:StartMoving() end);d:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
  d.title=label(d,'GameFontNormalLarge');at(d.title,20,18,520,26)
  d.help=label(d);at(d.help,20,54,560,40);d.help:SetWordWrap(true)
  d.close=button(d,function() d:Hide() end);at(d.close,552,12,32,32);CF.MinimalOptions.Symbol(d.close,'close',true)
  d.classTitle=label(d,'GameFontNormal');at(d.classTitle,20,102,560,22)
  d.classes={}
  for i,key in ipairs(classes) do
   local b=button(d,function()
    if not available(key) then return end
    CursiveForeverDB.optionsArtworkClass=key;f.CFRefreshPresentation();A.RefreshChooser(f)
   end)
   at(b,20+((i-1)%3)*190,130+math.floor((i-1)/3)*36,180,29);d.classes[key]=b
   hook(b,'OnEnter',function(self)
    GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(self.cfLabel:GetText())
    GameTooltip:AddLine(key=='MAGE' and CF.CharacterPack.Status()~='available' and CF.CharacterPack.Message() or
     not available(key) and tr('Wird in einer zukünftigen Version ergänzt.','Will be added in a future version.') or
     key=='MAGE' and tr('Weiblich: Jaina. Medivh folgt später.','Female: Jaina. Medivh will follow later.') or
     key=='WARLOCK' and tr('Gul’dans Grimoire.','Gul’dan’s grimoire.') or
     tr('Verwendet die Klasse deines Charakters.','Uses your character’s class.'),1,1,1,true);GameTooltip:Show()
   end)
   hook(b,'OnLeave',function() GameTooltip:Hide();A.RefreshChooser(f) end)
  end
  d.genderTitle=label(d,'GameFontNormal');at(d.genderTitle,20,316,560,22);d.genders={}
  for i,key in ipairs({'auto','female','male'}) do
   local b=button(d,function() CursiveForeverDB.optionsArtworkGender=key;f.CFRefreshPresentation();A.RefreshChooser(f) end)
   at(b,20+(i-1)*190,344,180,29);d.genders[key]=b
   hook(b,'OnLeave',function() A.RefreshChooser(f) end)
  end
  d.animation=CreateFrame('CheckButton',nil,d,'UICheckButtonTemplate');at(d.animation,18,390,24,24)
  if d.animation.Text then d.animation.Text:Hide() end
  d.animation.caption=label(d.animation);d.animation.caption:SetPoint('LEFT',d.animation,'RIGHT',4,0);d.animation.caption:SetSize(480,24)
  d.animation:SetHitRectInsets(0,-480,0,0)
  d.animation:SetScript('OnClick',function(self) CursiveForeverDB.optionsArtworkAnimation=self:GetChecked() and true or false;A.Apply(f,f.cfOptionsBindings) end)
  d.status=label(d,'GameFontNormal');at(d.status,20,428,560,24)
  d.future=label(d);at(d.future,20,466,560,65);d.future:SetWordWrap(true)
  d:SetScript('OnHide',function() GameTooltip:Hide();CF.MinimalOptions.HideTip() end)
  UISpecialFrames[#UISpecialFrames+1]='CursiveArtworkChooser'
 end
 A.RefreshChooser(f);a.chooser:Show();a.chooser:Raise()
end
local function paintTab(f,b)
 if not f.cfJaina then return end
 local selected=f.activePage==b.cfJainaPage
 b:SetBackdrop(nil);b.cfSelectedLine:Hide()
 b.cfLabel:SetTextColor(selected and .65 or .89,selected and .92 or .94,1,1)
 b.cfLabel:SetShadowOffset(1,-1)
 for _,t in ipairs(b.cfJainaGlows) do
  t:SetAlpha(t==b.cfJainaGlow and (b.cfJainaHover and .40 or selected and .14 or 0) or 0)
 end
end
function A.Initialize(f)
 if f.cfArtwork then return f.cfArtwork end
 local a={lastFrame=nil,paths={},glows={},buffers={},tick=0,clock=0};f.cfArtwork=a
 for i=1,FRAMES do a.paths[i]={MEDIA..string.format('Top%03d.blp',i),MEDIA..string.format('Bottom%03d.blp',i)} end
 a.layer=CreateFrame('Frame',nil,f);a.layer:SetAllPoints();a.layer:EnableMouse(false);a.layer:SetFrameLevel(f:GetFrameLevel())
 -- Keep the imagery on the options frame's background draw layer, exactly as
 -- the book artwork. A separate child frame could cover the title/version
 -- despite sharing the parent's frame level. The child only owns the timer.
 -- Never change the file on a visible texture. Keep one complete frame on
 -- screen while two other buffers load. Alpha zero keeps queued textures
 -- attached to the visible menu without drawing them over the current frame.
 for i=1,3 do
  local b={index=i,glows={}};a.buffers[i]=b
  b.top=f:CreateTexture(nil,'BACKGROUND',nil,-8);at(b.top,0,0,1360,1024*SCALE);b.top:SetTexCoord(0,1664/2048,0,1)
  b.bottom=f:CreateTexture(nil,'BACKGROUND',nil,-8);at(b.bottom,0,1024*SCALE,1360,224*SCALE);b.bottom:SetTexCoord(0,1664/2048,0,224/256)
  b.regions={b.top,b.bottom};b.top:SetAlpha(0);b.bottom:SetAlpha(0)
 end
 a.top=a.buffers[1].top;a.bottom=a.buffers[1].bottom
 a.canWait=type(a.top.IsObjectLoaded)=='function'
 a.layer:Hide()
 a.title=label(f,'GameFontNormalLarge');at(a.title,445,404,360,28);a.title:SetJustifyH('CENTER');a.title:SetText('Cursive');a.title:Hide()
 a.close=button(f,function() f:Hide() end);at(a.close,1274,409,28,28);a.close:SetFrameLevel(f:GetFrameLevel()+70);CF.MinimalOptions.Symbol(a.close,'close',true);a.close:Hide()
 a.entry=button(f.pages.help.cfBody,function() A.OpenChooser(f) end)
 a.design=CreateFrame('Frame',nil,f);at(a.design,992,773,272,60);a.design:SetFrameLevel(f:GetFrameLevel()+60);a.design:Hide()
 a.designTitle=label(a.design);at(a.designTitle,0,0,272,17);a.designTitle:SetJustifyH('CENTER')
 a.designButtons={}
 for i,key in ipairs({'FULL','minimal'}) do
  local b=button(a.design,function() f.CFSetDesign(key) end);at(b,18+(i-1)*124,22,112,27);a.designButtons[key]=b
 end
 for i,p in ipairs(f.optionPages) do
  local b=f.tabs[p.id];b.cfJainaPage=p.id
  b.cfJainaGlows={}
  for _,buffer in ipairs(a.buffers) do
   local t=b:CreateTexture(nil,'ARTWORK');t:SetAllPoints();t:SetBlendMode('ADD');t:SetAlpha(0);t:Hide()
   local y=540+(i-1)*97
   t:SetTexCoord(1205/2048,1555/2048,y/1024,(y+82)/1024)
   b.cfJainaGlows[#b.cfJainaGlows+1]=t
   buffer.glows[i]=t;buffer.regions[#buffer.regions+1]=t;a.glows[#a.glows+1]=t
  end
  hook(b,'OnEnter',function(self) self.cfJainaHover=true;paintTab(f,self) end)
  hook(b,'OnLeave',function(self) self.cfJainaHover=false;paintTab(f,self) end)
  hook(b,'OnHide',function(self) self.cfJainaHover=false end)
 end
 local function clearBuffer(buffer)
  for _,t in ipairs(buffer.regions) do t:SetAlpha(0);t:SetTexture(nil) end
  buffer.frame=nil
 end
 local function queue(buffer,frame)
  if buffer.frame==frame then return end
  local paths=a.paths[frame]
  buffer.top:SetTexture(paths[1]);buffer.bottom:SetTexture(paths[2])
  for _,t in ipairs(buffer.glows) do t:SetTexture(paths[1]) end
  buffer.frame=frame;buffer.queuedAt=a.tick
 end
 local function ready(buffer)
  -- Allow at least one render update after SetTexture, then ask about every
  -- region. A ready top half alone must never expose an unloaded bottom/glow.
  if a.tick<=buffer.queuedAt then return false end
  for _,t in ipairs(buffer.regions) do if not t:IsObjectLoaded() then return false end end
  return true
 end
 local function present(buffer)
  if a.front then for _,t in ipairs(a.front.regions) do t:SetAlpha(0) end end
  a.front=buffer;a.lastFrame=buffer.frame;a.top=buffer.top;a.bottom=buffer.bottom
  buffer.top:SetAlpha(1);buffer.bottom:SetAlpha(1)
  for i,p in ipairs(f.optionPages) do
   local b=f.tabs[p.id];b.cfJainaGlow=buffer.glows[i];paintTab(f,b)
  end
 end
 local function prefetch()
  local index=a.front and a.front.index or 1
  local frame=a.lastFrame or 1
  if not a.front then queue(a.buffers[1],1) end
  for offset=1,2 do queue(a.buffers[(index+offset-1)%3+1],(frame+offset-1)%FRAMES+1) end
 end
 a.Update=function(_,elapsed)
  a.tick=a.tick+1
  if not a.front then
   if not ready(a.buffers[1]) then return end
   present(a.buffers[1]);a.clock=0
   if not a.animating then a.layer:SetScript('OnUpdate',nil) end
   return
  end
  -- Bound catch-up after a long render stall. Disk/GPU delays hold the last
  -- complete frame instead of clearing it or endlessly replacing a request.
  a.clock=math.min(a.clock+elapsed,2/FPS)
  for _=1,2 do
   if a.clock+1e-7<1/FPS then break end
   local nextBuffer=a.buffers[a.front.index%3+1]
   if not ready(nextBuffer) then a.clock=math.min(a.clock,1/FPS);break end
   present(nextBuffer);a.clock=math.max(0,a.clock-1/FPS);prefetch()
  end
 end
 function a.Start(animate)
  a.animating=animate and a.canWait
  a.layer:Show()
  if not a.canWait then
   -- Older/custom clients without a readiness query get a stable still;
   -- guessing a loading delay would reintroduce the same flicker.
   if not a.front then queue(a.buffers[1],1);present(a.buffers[1]) end
   a.layer:SetScript('OnUpdate',nil);return
  end
  if a.animating then
   prefetch();a.layer:SetScript('OnUpdate',a.Update)
  else
   for _,buffer in ipairs(a.buffers) do if buffer~=a.front then clearBuffer(buffer) end end
   a.clock=0
   if a.front then a.layer:SetScript('OnUpdate',nil)
   else queue(a.buffers[1],1);a.layer:SetScript('OnUpdate',a.Update) end
  end
 end
 function a.Stop(release)
  a.layer:SetScript('OnUpdate',nil)
  if release then
   a.layer:Hide()
   for _,buffer in ipairs(a.buffers) do clearBuffer(buffer) end
   for _,p in ipairs(f.optionPages) do f.tabs[p.id].cfJainaGlow=nil end
   a.front=nil;a.lastFrame=nil;a.clock=0;a.animating=false
  end
 end
 hook(f,'OnHide',function()
  a.Stop(true);if a.chooser then a.chooser:Hide() end
  for _,b in pairs(f.tabs) do b.cfJainaHover=false end
  GameTooltip:Hide();CF.MinimalOptions.HideTip()
 end)
 hook(f,'OnShow',function() A.Apply(f,f.cfOptionsBindings) end)
 local tabs=f.CFRefreshTabs
 f.CFRefreshTabs=function() tabs();if f.cfJaina then A.Style(f) end end
 return a
end
function A.Style(f)
 local a=f.cfArtwork;if not a then return end
 local M=CF.MinimalOptions
 if f.grimoireSignature then f.grimoireSignature:GetParent():Hide() end
 f.grimoireArt:Hide();f.designGroup:Hide();f.closeButton:Hide()
 a.title:Show();a.close:Show();a.design:Show()
 M.Button(a.close);M.Symbol(a.close,'close',true)
 light(a.title);light(a.designTitle)
 a.designTitle:SetText(tr('Options-Design','Options design'))
 for key,b in pairs(a.designButtons) do
  b.cfLabel:SetText(key=='FULL' and tr('Voll','Full') or 'Minimal');M.Button(b)
 end
 for _,t in pairs(f.optionLabels) do light(t) end
 for _,t in pairs(f.cfLabels or {}) do light(t) end
 light(f.cfOptionsBindings and f.cfOptionsBindings.build)
 for _,c in pairs(f.controls) do
  light(c.Text);light(c.cfLabel);light(c.cfCaption);light(c.Low);light(c.High)
  local kind=c.cfOptionsLayout and c.cfOptionsLayout.kind
  if kind=='slider' then M.StyleSlider(c,true)
  elseif kind=='checkbox' or kind=='radio' then M.StyleCheckbox(c,true)
  elseif c.cfLabel and c.SetBackdrop and kind=='action' then M.Button(c) end
 end
 for _,r in ipairs(f.cfSpellRows or {}) do
  r:SetBackdropColor(.055,.14,.22,.62);M.StyleCheckbox(r.show,true);M.StyleCheckbox(r.main,true)
  light(r.label);M.Button(r.up);M.Button(r.down);M.Symbol(r.up,'up',true);M.Symbol(r.down,'down',true)
  for _,t in ipairs({r:GetRegions()}) do if t.GetText then light(t) end end
 end
 for i,p in ipairs(f.optionPages) do
  local b=f.tabs[p.id];at(b,1205*SCALE,(540+(i-1)*97)*SCALE,350*SCALE,82*SCALE)
  b.cfLabel:ClearAllPoints();b.cfLabel:SetPoint('CENTER');b.cfLabel:SetSize(246,40);b.cfLabel:SetJustifyH('CENTER');b.cfLabel:SetFontObject('GameFontNormal')
  for _,t in ipairs(b.cfJainaGlows) do t:Show() end;paintTab(f,b)
 end
end
function A.Apply(f,bindings)
 if not f.cfUnifiedOptions or not bindings then return end
 local a=A.Initialize(f);local db=CursiveForeverDB
 local active=f.cfGrimoire and A.Resolve(db)=='jaina'
 f.cfJaina=active and true or false
 for _,page in pairs(f.pages) do styleScroll(page.cfScroll,active) end
 a.title:SetShown(active);a.close:SetShown(active);a.design:SetShown(active)
 for _,t in ipairs(a.glows) do t:SetShown(active) end
 a.entry:SetParent(f.pages.help.cfBody);at(a.entry,0,f.cfArtworkEntryY or 0,f.cfGrimoire and 296 or 326,30)
 a.entry.cfLabel:SetText(tr('Menümotiv wählen …','Choose menu artwork …'));CF.MinimalOptions.Button(a.entry);a.entry:Show()
 if f.cfMinimal and f.cfMinimal.future.art then f.cfMinimal.future.art:Hide() end
 if active then
  A.Style(f);at(bindings.version,992,860,272,20);light(bindings.version)
  if f:IsShown() then
   a.Start(db.optionsArtworkAnimation~=false)
  else a.Stop(true) end
 else
  a.Stop(true)
  f.grimoireArt:SetTexture('Interface\\AddOns\\CursiveForever\\Media\\OptionsGrimoire.tga')
  f.grimoireArt:SetTexCoord(0,.75,0,.5625);f.grimoireArt:SetShown(f.cfGrimoire)
 end
 A.RefreshChooser(f)
end
