local _,addon=...
local CF=addon.CF
-- Presentation only: the existing controls retain their setters and callbacks.
local M={};CF.MinimalOptions=M
local GOLD={.76,.60,.30,1};local INK={.055,.045,.035,1}
local ICE={edge={.48,.74,.89,1},back={.025,.065,.105,.94},text={.87,.94,.99,1},
 hover={.76,.92,1,1},hoverBack={.06,.16,.24,1},accent={.50,.81,.98,1},rail={.12,.23,.31,1}}
local PLAIN={edge=GOLD,back=INK,text={.91,.85,.70,1},hover={1,.81,.42,1},
 hoverBack={.13,.10,.055,1},accent={.87,.70,.36,1},rail={.19,.18,.16,1}}
-- Resolve by ancestry, not by the open motif alone: unrelated dialogs and
-- tracker controls retain their own appearance even while Jaina is visible.
function M.IsIce(owner)
 local f=CF.optionsPagesFrame
 if not f or not f.cfJaina then return false end
 while owner do
  if owner==f then return true end
  owner=owner.GetParent and owner:GetParent()
 end
 return false
end
local function palette(owner) return M.IsIce(owner) and ICE or PLAIN end
local BACK={bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1}
local function tr(de,en) return CF.GetEffectiveLanguage()=='de' and de or en end
local function at(o,x,y,w,h) o:ClearAllPoints();o:SetPoint('TOPLEFT',x,-y);if w then o:SetSize(w,h) end end
local function strip(s) return (s or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','') end
local function text(parent,value,x,y,w)
 local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');t:SetJustifyH('LEFT');t:SetJustifyV('TOP');t:SetWordWrap(true);at(t,x,y,w,18);t:SetText(value);return t
end
local function line(parent,x,y,w)
 local t=parent:CreateTexture(nil,'ARTWORK');at(t,x,y,w,1);t:SetColorTexture(.55,.41,.19,.65);return t
end
local function hook(o,event,fn)
 local old=o:GetScript(event);o:SetScript(event,function(self,...) if old then old(self,...) end;fn(self,...) end)
end
local function minimal() return CF.optionsPagesFrame and (not CF.optionsPagesFrame.cfGrimoire or CF.optionsPagesFrame.cfJaina) end
function M.HideTip() if M.tip then M.tip:Hide() end end
function M.Tip(owner,title,body)
 if not minimal() then return end
 if not M.tip then
  local f=CreateFrame('Frame',nil,UIParent,'BackdropTemplate');M.tip=f
  f:SetFrameStrata('TOOLTIP');f:SetClampedToScreen(true);f:EnableMouse(false)
  f:SetBackdrop(BACK);f:SetBackdropColor(.035,.028,.022,1);f:SetBackdropBorderColor(unpack(GOLD))
  f.title=text(f,'',12,10,252);f.title:SetTextColor(unpack(GOLD))
  f.body=text(f,'',12,32,252);f.body:SetTextColor(.90,.87,.80,1)
  -- Half of a rotated square forms the pointer; the window covers its inner half.
  f.pointer=f:CreateTexture(nil,'BACKGROUND');f.pointer:SetSize(12,12);f.pointer:SetColorTexture(unpack(GOLD));f.pointer:SetRotation(math.pi/4)
  f.pointerInside=f:CreateTexture(nil,'BORDER');f.pointerInside:SetSize(10,10);f.pointerInside:SetColorTexture(.035,.028,.022,1);f.pointerInside:SetRotation(math.pi/4)
 end
 local f=M.tip;local p=palette(owner)
 f:SetBackdropBorderColor(unpack(p.edge));f.title:SetTextColor(unpack(p.edge));f.pointer:SetColorTexture(unpack(p.edge))
 local back=M.IsIce(owner) and {.025,.05,.08,1} or {.035,.028,.022,1}
 f:SetBackdropColor(unpack(back));f.pointerInside:SetColorTexture(unpack(back))
 f.body:SetTextColor(unpack(M.IsIce(owner) and ICE.text or {.90,.87,.80,1}))
 f.title:SetText(strip(title));f.body:SetText(strip(body));f.body:SetHeight(0)
 local h=math.max(20,f.body:GetStringHeight());f.body:SetHeight(h);f:SetSize(276,h+44)
 f:ClearAllPoints();f.pointer:ClearAllPoints();f.pointerInside:ClearAllPoints()
 local right=owner.GetRight and owner:GetRight();local screen=UIParent:GetWidth()
 local flip=right and right+294>screen
 if flip then f:SetPoint('TOPRIGHT',owner,'TOPLEFT',-12,8);f.pointer:SetPoint('RIGHT',6,-0);f.pointerInside:SetPoint('RIGHT',5,0)
 else f:SetPoint('TOPLEFT',owner,'TOPRIGHT',12,8);f.pointer:SetPoint('LEFT',-6,0);f.pointerInside:SetPoint('LEFT',-5,0) end
 -- Pointer stays near the first text line even for long explanations.
 f.pointer:ClearAllPoints();f.pointer:SetPoint(flip and 'TOPRIGHT' or 'TOPLEFT',flip and 6 or -6,-14)
 f.pointerInside:ClearAllPoints();f.pointerInside:SetPoint(flip and 'TOPRIGHT' or 'TOPLEFT',flip and 5 or -5,-15)
 f.owner=owner;f:Show();GameTooltip:Hide()
end
function M.Tooltip(o,title,body)
 o.cfMinimalTipTitle=title;o.cfMinimalTipBody=body
 if o.cfMinimalTipHook then return end;o.cfMinimalTipHook=true
 hook(o,'OnEnter',function(self)
  if not minimal() then return end
  local a=type(self.cfMinimalTipTitle)=='function' and self.cfMinimalTipTitle() or self.cfMinimalTipTitle
  local b=type(self.cfMinimalTipBody)=='function' and self.cfMinimalTipBody() or self.cfMinimalTipBody
  if not a and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
   local l=_G.GameTooltipTextLeft1;a=l and l:GetText();local parts={}
   for i=2,20 do local t=_G['GameTooltipTextLeft'..i];if t and t:GetText() then parts[#parts+1]=t:GetText() end end
   b=table.concat(parts,'\n')
  end
  if a and b and b~='' then M.Tip(self,a,b) end
 end)
 hook(o,'OnLeave',M.HideTip);hook(o,'OnHide',M.HideTip)
end
function M.Button(b)
 if not b or not b.cfLabel then return end
 if not b.cfMinimalButton then
  b.cfMinimalButton=true
  hook(b,'OnEnter',function(self) if (minimal() or self.cfWorkshopButton) and self:IsEnabled() then local p=palette(self);self:SetBackdropBorderColor(unpack(p.hover));self:SetBackdropColor(unpack(p.hoverBack)) end end)
  hook(b,'OnLeave',function(self) if minimal() or self.cfWorkshopButton then M.Button(self) end end)
 end
 if b.cfWorkshopButton and not b.cfWorkshopNative then
  b.cfWorkshopNative={}
  for _,key in ipairs({'Normal','Pushed','Highlight','Disabled'}) do b.cfWorkshopNative[key]=b['Get'..key..'Texture'](b) end
 end
 if b.cfWorkshopButton then b:SetNormalTexture('');b:SetPushedTexture('');b:SetHighlightTexture('');b:SetDisabledTexture('') end
 if b.cfDecorIcon then b.cfDecorIcon:Hide() end
 if b.cfBookArt then b.cfBookArt:Hide() end
 local p=palette(b)
 b:SetBackdrop(BACK);b:SetBackdropColor(unpack(p.back));b:SetBackdropBorderColor(unpack(p.edge))
 b.cfLabel:ClearAllPoints();b.cfLabel:SetPoint('CENTER');b.cfLabel:SetSize(math.max(12,b:GetWidth()-12),math.max(12,b:GetHeight()-4));b.cfLabel:SetJustifyH('CENTER');b.cfLabel:SetJustifyV('MIDDLE');b.cfLabel:SetTextColor(unpack(p.text))
 if b.cfMinimalSymbol then M.Symbol(b,b.cfMinimalSymbol.kind,b.cfMinimalSymbol.active) end
 M.Tooltip(b,b.cfMinimalTipTitle,b.cfMinimalTipBody)
end
-- Draw icons from two strokes rather than font glyphs that some clients lack.
function M.Symbol(b,kind,on)
 local s=b.cfMinimalSymbol
 if not s then
  s={};b.cfMinimalSymbol=s
  for i=1,2 do s[i]=b:CreateTexture(nil,'OVERLAY');s[i]:SetColorTexture(.94,.78,.43,1) end
  local function refresh(self) local a=self.cfMinimalSymbol;M.Symbol(self,a.kind,a.active) end
  hook(b,'OnEnable',refresh);hook(b,'OnDisable',refresh)
 end
 s.kind=kind;s.active=on;b.cfLabel:SetShown(not on)
 for i=1,2 do
  local t=s[i];t:SetShown(on);t:ClearAllPoints();t:SetSize(kind=='close' and 15 or 9,2)
  t:SetColorTexture(unpack(M.IsIce(b) and ICE.accent or {.94,.78,.43,1}))
  local angle=(i==1 and 1 or -1)*math.pi/4
  if kind=='down' then angle=-angle end
  t:SetRotation(angle);t:SetPoint('CENTER',kind=='close' and 0 or (i==1 and -3 or 3),0)
  t:SetAlpha(b:IsEnabled() and 1 or .3)
 end
end
local function button(parent,title,fn)
 local b=CreateFrame('Button',nil,parent,'BackdropTemplate');b.cfLabel=text(b,title,0,0,100);b:SetScript('OnClick',fn);M.Button(b);return b
end
local function checkbox(c,on)
 local radio=c.cfOptionsLayout and c.cfOptionsLayout.kind=="radio"
 if radio and not (on and M.IsIce(c)) then
  local s=c.cfMinimalCheck
  if s then
   s.box:Hide();s.inner:Hide();s.mark:Hide()
   for _,key in ipairs({'Normal','Pushed','Highlight','Checked','DisabledChecked'}) do if c['Set'..key..'Texture'] then c['Set'..key..'Texture'](c,s[key] or '') end end
  end
  if on and c.cfLabel then c.cfLabel:SetTextColor(.90,.87,.80,1) end
  return
 end
 if not c.cfMinimalCheck then
  local s={};c.cfMinimalCheck=s
  for _,key in ipairs({'Normal','Pushed','Highlight','Checked','DisabledChecked'}) do
   local getter=c['Get'..key..'Texture'];if getter then s[key]=getter(c) end
  end
  s.box=c:CreateTexture(nil,'BACKGROUND');s.box:SetSize(15,15);s.box:SetPoint('CENTER');s.box:SetColorTexture(unpack(GOLD))
  s.inner=c:CreateTexture(nil,'BORDER');s.inner:SetSize(13,13);s.inner:SetPoint('CENTER');s.inner:SetColorTexture(unpack(INK))
  s.mark=c:CreateTexture(nil,'OVERLAY');s.mark:SetColorTexture(.87,.70,.36,1);s.mark:SetSize(7,7);s.mark:SetPoint('CENTER')
 end
 local s=c.cfMinimalCheck;local p=palette(c)
 s.box:SetColorTexture(unpack(p.edge));s.inner:SetColorTexture(unpack(p.back));s.mark:SetColorTexture(unpack(p.accent))
 s.box:SetShown(on and not radio);s.inner:SetShown(on and not radio)
 if on then
  c:SetNormalTexture(radio and s.Normal or '');c:SetPushedTexture('');c:SetHighlightTexture('');c:SetCheckedTexture(s.mark)
  s.mark:SetSize(radio and 5 or 7,radio and 5 or 7);s.mark:SetRotation(radio and math.pi/4 or 0)
  if c.SetDisabledCheckedTexture then c:SetDisabledCheckedTexture(s.mark) end
  c:SetChecked(c:GetChecked())
  local label=c.cfLabel or c.Text;if label then label:SetTextColor(unpack(M.IsIce(c) and ICE.text or {.90,.87,.80,1})) end
 else
  for _,key in ipairs({'Normal','Pushed','Highlight','Checked','DisabledChecked'}) do if c['Set'..key..'Texture'] then c['Set'..key..'Texture'](c,s[key] or '') end end
  s.mark:Hide()
 end
end
M.StyleCheckbox=checkbox
local function slider(s,on)
 if not s.cfMinimalSlider then
  local thumb=s:GetThumbTexture()
  local a={thumb={texture=thumb:GetTexture(),coords={thumb:GetTexCoord()},w=thumb:GetWidth(),h=thumb:GetHeight()}};s.cfMinimalSlider=a
  a.rail=s:CreateTexture(nil,'ARTWORK');a.rail:SetPoint('LEFT');a.rail:SetPoint('RIGHT');a.rail:SetHeight(5);a.rail:SetColorTexture(.19,.18,.16,1)
  a.fill=s:CreateTexture(nil,'ARTWORK',nil,1);a.fill:SetPoint('LEFT');a.fill:SetHeight(5);a.fill:SetColorTexture(unpack(GOLD))
  a.value=text(s,'',0,0,64);a.value:ClearAllPoints();a.value:SetPoint('BOTTOMRIGHT',s,'TOPRIGHT',0,5);a.value:SetJustifyH('RIGHT');a.value:SetTextColor(.91,.77,.48,1)
  a.native={};if s.GetRegions then for _,r in ipairs({s:GetRegions()}) do if r~=a.rail and r~=a.fill and r~=a.value and r~=s.Low and r~=s.High and r~=s.Text and r~=s:GetThumbTexture() then a.native[#a.native+1]={r,r:GetAlpha()} end end end
  hook(s,'OnValueChanged',function() if minimal() then M.UpdateSlider(s) end end)
 end
 local a=s.cfMinimalSlider
 if not on and s.CFRefresh then s.CFRefresh() end
 a.rail:SetShown(on);a.fill:SetShown(on);a.value:SetShown(on)
 if on then
  local p=palette(s)
  a.rail:SetColorTexture(unpack(p.rail));a.fill:SetColorTexture(unpack(p.edge))
  a.value:SetTextColor(unpack(M.IsIce(s) and ICE.accent or {.91,.77,.48,1}))
  if s.cfBookRail then s.cfBookRail:Hide();s.cfBookFill:Hide() end
  if s.SetBackdrop then s:SetBackdrop(nil) end
  for _,v in ipairs(a.native) do v[1]:SetAlpha(0) end
  local thumb=s:GetThumbTexture();thumb:SetTexture('Interface\\Buttons\\WHITE8X8');thumb:SetTexCoord(0,1,0,1);thumb:SetVertexColor(unpack(M.IsIce(s) and ICE.accent or {.87,.71,.40,1}));thumb:SetSize(9,15)
  if s.Low then s.Low:Hide() end;if s.High then s.High:Hide() end
  M.UpdateSlider(s)
 else
  -- Grimoire already restored its native regions and rail before this hook.
  if s.Low then s.Low:Show() end;if s.High then s.High:Show() end
  local thumb=s:GetThumbTexture();thumb:SetVertexColor(1,1,1,1)
  if not s.cfBookRail then
   thumb:SetTexture(a.thumb.texture);thumb:SetTexCoord(unpack(a.thumb.coords));thumb:SetSize(a.thumb.w,a.thumb.h)
   for _,v in ipairs(a.native) do v[1]:SetAlpha(v[2]) end
  end
 end
end
function M.UpdateSlider(s)
 local a=s.cfMinimalSlider;if not a then return end
 local lo,hi=s:GetMinMaxValues();a.fill:SetWidth(math.max(.1,s:GetWidth()*math.max(0,math.min(1,(s:GetValue()-lo)/(hi-lo)))))
 if s.cfCaption then
  local caption=strip(s.cfCaption:GetText());local title,value=caption:match('^(.-):%s*(.-)%s*$')
  if title and value then s.cfCaption:SetText(title);a.value:SetText(value) end
  s.cfCaption:SetTextColor(unpack(M.IsIce(s) and ICE.text or {.90,.87,.80,1}));s.cfCaption:SetWidth(s:GetWidth()-70)
 else a.value:SetText(tostring(math.floor(s:GetValue()+.5))) end
end
M.StyleSlider=slider
local future={
 {'control','combat','Kontrollwächter','Control watcher','Warnt bei schadensempfindlicher Kontrolle, z. B. Verwandlung.','Warns about damage-sensitive crowd control, such as Polymorph.'},
 {'cooldown','combat','Zauberbereitschaft','Spell readiness','Zeigt Abklingzeiten beim Klickzaubern an.','Shows cooldowns when casting by click.'},
 {'curses','combat','Flüche anderer Spieler','Other players’ curses','Berücksichtigt fremde Flüche beim Fluchwächter.','Accounts for other players’ curses in the Curse Watcher.'},
 {'chat','templates','Im Chat teilen','Share in chat','Teile eine anklickbare Layoutvorlage.','Share a clickable layout template.'},
 {'auto','templates','Automatische Vorlagenwahl','Automatic layout selection','Ordnet Vorlagen Charakteren und Spezialisierungen zu.','Assigns layouts to characters and specializations.'},
 {'art','help','Klassenmotive','Class artwork','Weitere Menügestaltungen mit bekannten Warcraft-Charakteren.','Additional menu artwork featuring Warcraft characters.'},
}
function M.Initialize(f)
 if f.cfMinimal then return end
 local m={tabs={},future={},lines={}};f.cfMinimal=m
 m.chrome=CreateFrame('Frame',nil,f,'BackdropTemplate');m.chrome:SetAllPoints();m.chrome:SetFrameLevel(f:GetFrameLevel());m.chrome:EnableMouse(false)
 m.chrome:SetBackdrop(BACK);m.chrome:SetBackdropColor(.035,.029,.024,.99);m.chrome:SetBackdropBorderColor(unpack(GOLD))
 for _,corner in ipairs({'TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT'}) do
  local sx=corner:find('LEFT') and 1 or -1;local sy=corner:find('TOP') and -1 or 1
  local a=m.chrome:CreateTexture(nil,'BORDER');a:SetColorTexture(.88,.71,.39,1);a:SetSize(12,1);a:SetPoint(corner,sx*3,sy*3)
  local b=m.chrome:CreateTexture(nil,'BORDER');b:SetColorTexture(.88,.71,.39,1);b:SetSize(1,12);b:SetPoint(corner,sx*3,sy*3)
 end
 m.close=button(f,'',function() f:Hide() end);at(m.close,720,10,28,28);M.Symbol(m.close,'close',true);m.close:SetFrameLevel(f:GetFrameLevel()+65)
 m.templates=CreateFrame('Frame',nil,f);at(m.templates,20,106,720,450)
 m.templates.cfScroll=CreateFrame('ScrollFrame',nil,m.templates,'UIPanelScrollFrameTemplate');at(m.templates.cfScroll,0,0,696,450)
 m.templates.cfBody=CreateFrame('Frame',nil,m.templates.cfScroll);m.templates.cfBody:SetSize(678,590);m.templates.cfScroll:SetScrollChild(m.templates.cfBody)
 m.templates:Hide();m.templates.cfScroll:EnableMouseWheel(true)
 m.combatOverlay=CreateFrame('Frame',nil,f);m.combatOverlay:SetAllPoints(m.templates);m.combatOverlay:SetFrameLevel(f:GetFrameLevel()+66);m.combatOverlay:EnableMouse(false);m.combatOverlay:Hide()
 m.combatHint=text(m.combatOverlay,'',0,0,600);m.combatHint:ClearAllPoints();m.combatHint:SetPoint('CENTER',m.templates,'CENTER',0,0);m.combatHint:SetSize(600,80);m.combatHint:SetJustifyH('CENTER');m.combatHint:SetJustifyV('MIDDLE');m.combatHint:Hide()
 m.templates.cfScroll:SetScript('OnMouseWheel',function(self,delta) self:SetVerticalScroll(math.max(0,math.min(140,(self:GetVerticalScroll() or 0)-delta*36))) end)
 local pages={{'general','Anzeige','Display'},{'combat','Zauber & Hinweise','Spells & alerts'},{'templates','Vorlagen','Layouts'},{'performance','Auswertung','Review'},{'help','Allgemeines & Hilfe','General & help'}}
 for i,p in ipairs(pages) do
  local id=p[1];local b=button(f,'',function() f.CFSelectPage(id) end);b.cfNames=p;at(b,20+(i-1)*144,60,138,30);b:SetFrameLevel(f:GetFrameLevel()+65);m.tabs[id]=b
 end
 for _,spec in ipairs(future) do
  local parent=spec[2]=='templates' and m.templates.cfBody or f.pages[spec[2]].cfBody
  local b=CreateFrame('Button',nil,parent);b:SetSize(326,24);b.cfLabel=text(b,'',0,4,326);b.cfLabel:SetTextColor(.48,.46,.42,1);b.spec=spec;m.future[spec[1]]=b
  -- Hoverable but no click handler and no stored option.
  M.Tooltip(b,function() return tr(spec[3],spec[4]) end,function() return tr(spec[5],spec[6])..'\n\n'..tr('Wird in einer zukünftigen Version ergänzt.','Will be added in a future version.') end)
 end
 local select=f.CFSelectPage
 f.CFSelectPage=function(id)
  M.HideTip()
  if id=='templates' and not f.cfGrimoire then
   f.cfMinimalPage=id;select('general');for _,page in pairs(f.pages) do page:Hide() end;m.templates:Show()
   if CF.LayoutWorkshop then CF.LayoutWorkshop.Show(m.templates.cfBody) end
  else f.cfMinimalPage=nil;m.templates:Hide();select(id) end
  M.RefreshTemplateState(f)
  M.RefreshTabs(f)
 end
 hook(f,'OnHide',M.HideTip)
end
function M.RefreshTemplateState(f)
 local m=f.cfMinimal;if not m then return end
 local active=not f.cfGrimoire and f.cfMinimalPage=='templates'
 if active then for _,page in pairs(f.pages) do page:Hide() end;m.templates:Show() end
 local locked=CF.LayoutTemplates and CF.LayoutTemplates.InCombat() or false
 m.combatHint:SetText(tr('Vorschau und Layoutvorlagen sind im Kampf pausiert.\nNach dem Kampf kannst du hier weiterarbeiten.','Preview and layout templates are paused during combat.\nYou can continue here after combat.'))
 m.combatOverlay:SetShown(active and locked);m.combatHint:SetShown(active and locked);m.templates.cfScroll:SetShown(not locked)
 if not active or not CF.LayoutWorkshop then return end
 local w=CF.LayoutWorkshop
 if locked then if w.frame and w.frame.cfEmbedded then w.frame:Hide() end
 elseif not w.frame or not w.frame.cfEmbedded or not w.frame:IsShown() then w.Show(m.templates.cfBody) end
end
function M.RefreshTabs(f)
 local m=f.cfMinimal;if not m then return end
 for id,b in pairs(m.tabs) do
  b.cfLabel:SetText(tr(b.cfNames[2],b.cfNames[3]));M.Button(b)
  if (f.cfMinimalPage or f.activePage)==id then b:SetBackdropColor(.14,.105,.052,1);b:SetBackdropBorderColor(.94,.75,.38,1);b.cfLabel:SetTextColor(1,.84,.49,1) end
 end
end
function M.StylePreview(f)
 if not f then return end
 M.StyleWorkshop(f)
 if f.countSlider then
  slider(f.countSlider,minimal());f.countSlider.cfMinimalSlider.value:Hide()
  if f.countSlider.Low then f.countSlider.Low:Hide() end
  if f.countSlider.High then f.countSlider.High:Hide() end
 end
end
function M.RestoreWorkshop(f)
 -- Workshop dialogs share the same flat controls in both menu designs.
 M.StyleWorkshop(f)
end
function M.StyleWorkshop(f)
 if not f then return end
 for _,b in ipairs(f.cfButtons or {}) do M.Button(b) end
 if f.close then M.Symbol(f.close,'close',true) end
 for _,e in ipairs({f.name,f.code}) do
  if e then
   if not e.cfMinimalBackground then
    local bg=e:CreateTexture(nil,'BACKGROUND');bg:SetPoint('TOPLEFT',-4,4);bg:SetPoint('BOTTOMRIGHT',4,-4);bg:SetColorTexture(.025,.023,.02,1);e.cfMinimalBackground=bg
   end
   e.cfMinimalBackground:Show()
  end
 end
end
function M.Apply(f,bindings)
 if not f.cfUnifiedOptions then return end
 M.Initialize(f);local m=f.cfMinimal;local on=not f.cfGrimoire
 m.chrome:SetShown(on);m.close:SetShown(on);f.closeButton:SetShown(not on);m.templates:SetShown(on and f.cfMinimalPage=='templates')
 if on then
  M.Button(m.close)
  f.classicBackdrop:Hide()
  if f.cfDecor then
   for _,key in ipairs({'raven','watermark','headerLeft','headerRight','headerLeft2','headerRight2','headerRune'}) do if f.cfDecor[key] then f.cfDecor[key]:Hide() end end
   for _,key in ipairs({'corners','edgeRunes'}) do for _,t in ipairs(f.cfDecor[key] or {}) do t:Hide() end end
  end
  at(bindings.title,20,18,500,24)
 end
 for _,b in pairs(m.tabs) do b:SetShown(on) end
 for _,b in pairs(f.tabs) do b:SetShown(not on) end
 for _,b in pairs(m.future) do b:SetShown(on) end
 if not on then
  if f.cfMinimalPage then f.cfMinimalPage=nil;f.CFSelectPage('general') end
  if CF.LayoutWorkshop and CF.LayoutWorkshop.Detach then CF.LayoutWorkshop.Detach() end
 end
 for _,c in pairs(f.controls) do
  local kind=c.cfOptionsLayout and c.cfOptionsLayout.kind
  if kind=='slider' then
   slider(c,on)
   if not on and c.cfCaption then c.cfCaption:SetText(strip(c.cfCaption:GetText()));c.cfCaption:SetTextColor(.10,.06,.025,1);c.cfCaption:SetShadowOffset(0,0) end
  elseif kind=='checkbox' or kind=='radio' or c.cfMinimalCheck then if on or c.cfMinimalCheck then checkbox(c,on) end
  elseif on and c.cfLabel and c.SetBackdrop then M.Button(c) end
  if on then M.Tooltip(c,c.cfTipTitle and function() return CF.T(c.cfTipTitle) end,c.cfTipBody and function() return CF.T(c.cfTipBody) end) end
 end
 for _,row in ipairs(f.cfSpellRows) do
  if on then
   checkbox(row.show,true);checkbox(row.main,true);M.Button(row.up);M.Button(row.down)
   M.Symbol(row.up,'up',true);M.Symbol(row.down,'down',true)
   M.Tooltip(row.up,function() return CF.T('CARDS_MOVE_UP') end,function() return tr('Priorität erhöhen.','Increase priority.') end)
   M.Tooltip(row.down,function() return CF.T('CARDS_MOVE_DOWN') end,function() return tr('Priorität verringern.','Decrease priority.') end)
   M.Tooltip(row.hover,function() return row.displayName end,function() return row.description or CF.T('NO_DESCRIPTION') end)
  else
   M.Symbol(row.up,'up',true);M.Symbol(row.down,'down',true)
   if row.show.cfMinimalCheck then checkbox(row.show,false);checkbox(row.main,false) end
   row.up.cfLabel:SetText(CF.T('CARDS_MOVE_UP'));row.down.cfLabel:SetText(CF.T('CARDS_MOVE_DOWN'))
  end
 end
 for _,spec in ipairs(future) do local b=m.future[spec[1]];b.cfLabel:SetText(tr(spec[3],spec[4])..' · '..tr('Geplant','Planned')) end
 if on then
  at(m.future.control,352,f.cfMinimalCombatY or 0,326,24);at(m.future.cooldown,352,(f.cfMinimalCombatY or 0)+26,326,24)
  at(m.future.curses,352,(f.cfMinimalCombatY or 0)+52,326,24);m.future.curses:SetShown(CF.Client and CF.Client.edition=='Forever' and CF.GetPerformanceClassFile()=='WARLOCK')
  at(m.future.chat,16,520,630,24);at(m.future.auto,16,546,630,24)
  at(m.future.art,0,f.cfMinimalHelpY or 0,326,24)
  f.controls.layoutWorkshop:Hide()
  if CF.LayoutWorkshop and CF.LayoutWorkshop.frame and CF.LayoutWorkshop.frame.cfEmbedded then M.StyleWorkshop(CF.LayoutWorkshop.frame) end
  M.RefreshTabs(f)
 end
 if CF.LayoutWorkshop then M.StylePreview(CF.LayoutWorkshop.preview) end
 M.RefreshTemplateState(f)
 if CF.OptionsArtwork then CF.OptionsArtwork.Apply(f,bindings) end
 M.HideTip()
end
