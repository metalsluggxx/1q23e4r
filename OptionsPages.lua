local _,addon=...
local CF=addon.CF

-- Settings presentation only. Existing setters own saved values and tracker updates.
local translations={
 de={OPTIONS_GENERAL="Anzeige",OPTIONS_COMBAT="Zauber & Hinweise",OPTIONS_HELP="Allgemeines & Hilfe",
  OPTIONS_DESIGN_HELP="Voll zeigt das gewählte Menümotiv. Minimal zeigt das schlichte Optionsfenster. Die Auswahl wird gespeichert.",
  OPTIONS_DESIGN_TIP="Voll: gewähltes Menümotiv. Minimal: schlichtes Fenster mit denselben Einstellungen.",
  OP_SIZE="Größe & Abstände",OP_FRAME="Fenster & Symbole",OP_FADE="Transparenz & Ablauf",
  OP_VISIBILITY="Sichtbarkeit",OP_SPELLS="Zauber & Priorität",OP_HINTS="Hinweise",
  OP_ENABLED="Anzeigen",OP_ENABLED_SHORT="An",OP_MAIN="Haupt",OP_ORDER="Priorität",
  OP_LIST_HELP="Anzeigen: im gewählten Spielmodus aktiv. Haupt: großer Platz in der Anzeige. Die Pfeile ändern zugleich die Vorschlagspriorität.",
  OP_MAIN_TIP="Als Haupteffekt verwenden. Bis zu acht Plätze; die Reihenfolge gilt auch für Handlungsvorschläge. Unterstützende Flüche sind ebenfalls wählbar und erscheinen dann nur am Hauptplatz. Andere aktivierte Effekte erscheinen als Zusatzsymbole. In Standard bleiben alle Hauptsymbole in einer Reihe; ab dem fünften wird das Fenster breiter statt höher.",
  OP_FIXED_NOTE="Matrix und DoT-Balken verwenden deine feste Zauberreihenfolge. Die Sortierwahl für Standard und Lebensbalken bleibt gespeichert.",
  OP_OOC_NOTE="Bei ausgeblendetem Fenster wird außerhalb des Kampfes auch das gewählte Ziel nicht angezeigt. Deine Ziel-Einstellung bleibt gespeichert.",
  OP_CURSE_NOTE="Die separate Fluchanzeige gehört zu den Zusatzsymbolen und ist für Hexenmeister verfügbar.",
  OP_FILTER_CLASS="Zauber: %s",OP_OWN_CLASS="Eigene Klasse",OP_ALL_ON="Alle anzeigen",OP_ALL_OFF="Alle ausblenden",
  OP_CONTEXT_NOTE="Die Auswahl gilt nur für den oben gewählten Spielmodus.",
  OP_OTHER_CLASS="Filter für diese Klasse. Hauptplätze und Priorität werden für die eigene Klasse eingestellt.",
  OP_SAVED="Einstellungen werden gespeichert. Eine neue Ablaufabdunklung wird nach dem UI-Neuladen aktiv.",
  OP_EXECUTE_TIP="Automatisch berücksichtigt erlernte Fähigkeiten und Talente. Feste Schwellen sind für jede Klasse verfügbar; Aus deaktiviert den Hinweis.",
  OPTIONS_COMMANDS="Direktbefehle:\n/cf — Gegnerübersicht\n/cf options — Einstellungen\n/cf dots oder /cf filters — Zauber & Priorität\n/cf performance — Monitor und Archiv\n/cf karten — Kartenauswahl",
 },
 en={OPTIONS_GENERAL="Display",OPTIONS_COMBAT="Spells & alerts",OPTIONS_HELP="General & help",
  OPTIONS_DESIGN_HELP="Full shows the selected menu artwork. Minimal shows the plain options window. Your choice is saved.",
  OPTIONS_DESIGN_TIP="Full: selected menu artwork. Minimal: plain window with the same settings.",
  OP_SIZE="Size & spacing",OP_FRAME="Window & icons",OP_FADE="Transparency & duration",
  OP_VISIBILITY="Visibility",OP_SPELLS="Spells & priority",OP_HINTS="Alerts",
  OP_ENABLED="Show",OP_ENABLED_SHORT="Show",OP_MAIN="Main",OP_ORDER="Priority",
  OP_LIST_HELP="Show: enabled in the selected context. Main: a main display slot. The arrows also set action-suggestion priority.",
  OP_MAIN_TIP="Use as a main effect. Select up to eight slots; their order also sets suggestion priority. Utility curses can also be selected and then appear only in their main slot. Other enabled effects appear as extra icons. Standard keeps all main icons on one line; adding a fifth or more makes the window wider instead of taller.",
  OP_FIXED_NOTE="Matrix and DoT bars use your fixed spell order. Your sorting choice for Standard and Health bars stays saved.",
  OP_OOC_NOTE="While the window is hidden out of combat, the selected target is also hidden. Your target setting is preserved.",
  OP_CURSE_NOTE="The separate curse display is part of extra icons and is available to Warlocks.",
  OP_FILTER_CLASS="Spells: %s",OP_OWN_CLASS="Own class",OP_ALL_ON="Show all",OP_ALL_OFF="Hide all",
  OP_CONTEXT_NOTE="Changes apply only to the selected context above.",
  OP_OTHER_CLASS="Filters for this class. Main slots and priority are configured for your own class.",
  OP_SAVED="Settings are saved. A changed duration-sweep opacity takes effect after reloading the UI.",
  OP_EXECUTE_TIP="Automatic considers learned abilities and talents. Fixed thresholds work for any class; Off disables the indicator.",
  OPTIONS_COMMANDS="Shortcuts:\n/cf — enemy tracker\n/cf options — settings\n/cf dots or /cf filters — spells & priority\n/cf performance — monitor and archive\n/cf cards — card selection",
 }
}
for key,value in pairs(translations.de) do CF.L_DE[key]=value end
for key,value in pairs(translations.en) do CF.L_EN[key]=value end

local function place(object,x,y,w,h)
 object:ClearAllPoints();object:SetPoint("TOPLEFT",x,-y)
 if w and h then object:SetSize(w,h) end
end
local function enabled(object,value)
 object:SetEnabled(value);object:SetAlpha(value and 1 or .45)
end
local function scrollTo(page,value)
 local range=math.max(0,(page.cfContentHeight or 1)-(page.cfViewportHeight or 1))
 value=math.max(0,math.min(range,value or 0))
 page.cfScroll:SetVerticalScroll(value);page.cfScrollOffset=value
 if page.cfScroll.ScrollBar then
  page.cfScroll.ScrollBar:SetMinMaxValues(0,range)
  page.cfScroll.ScrollBar:SetValue(value)
 end
end

function CF.BuildOptionsPages(f,ui)
 CF.L_DE.LAYOUT_WORKSHOP='Vorschau & Layoutvorlagen'
 CF.L_EN.LAYOUT_WORKSHOP='Preview & layout templates'
 -- Options wording only: Classic Era has no native focus role.
 if CF.Client and CF.Client.edition=="Era" then
  CF.L_DE.CLICK_NOTE="Bei aktiviertem Klickzaubern steht dein aktuelles Ziel oben. Mit festen Plätzen klickst du auf Symbol, Zeitzelle oder DoT-Balken, um darauf zu zaubern. Weitere Gegner dienen der Anzeige."
  CF.L_EN.CLICK_NOTE="With click casting enabled, your current target appears first. With fixed positions, click an icon, timer cell or DoT bar to cast on it. Other enemy rows are display-only."
  CF.L_DE.CLICK_CASTING_TIP="Linksklick auf Hauptzauber beim aktuellen Ziel. Funktioniert mit festen Plätzen in allen vier Ansichten. Zielwechsel ersetzt den Gegner in der obersten Zeile. Für ruhige Gegnerzeilen Klickzaubern ausschalten. Classic Era hat kein natives Fokusziel. Anordnung außerhalb des Kampfes ändern."
  CF.L_EN.CLICK_CASTING_TIP="Left-click main spells on your current target. Uses fixed positions in all four views. Changing target replaces the enemy in the top row. Turn click casting off to keep enemy rows in place. Classic Era has no native focus. Change the layout outside combat."
 end
 CF.L_DE.OPTIONS_PRIORITY_HELP="Markierte Gegner stehen in der Gegnerliste zuerst. Beim Klickzaubern bleiben Fokus und aktuelles Ziel davor."
 CF.L_EN.OPTIONS_PRIORITY_HELP="Marked enemies lead the enemy list. With click casting, focus and current-target rows remain ahead of them."
 if CF.Client and CF.Client.edition=="Era" then
  CF.L_DE.OPTIONS_PRIORITY_HELP="Markierte Gegner stehen in der Gegnerliste zuerst. Beim Klickzaubern bleibt dein aktuelles Ziel davor."
  CF.L_EN.OPTIONS_PRIORITY_HELP="Marked enemies lead the enemy list. With click casting, your current-target row remains ahead of them."
 end
 CF.optionsPagesFrame=f;f.cfUnifiedOptions=true;f.cfOptionsUI=ui
 f.cfSpellContext="solo";f.cfSpellClass=CF.GetPerformanceClassFile();f.cfSpellRows={}
 local function text(id,key,parent,height,heading)
  local label=ui.text(parent,key,0,0,300,height or 24,heading~=false)
  f.cfLabels=f.cfLabels or {};f.cfLabels[id]=label;return label
 end
 local function radios(id,parent,choices,setter)
  local group=CreateFrame("Frame",nil,parent);group.cfRadios={};f.controls[id]=group
  group.cfOptionsLayout={x=0,y=0,width=300,height=52,kind="group"}
  f.optionNodes[#f.optionNodes+1]=group
  for _,choice in ipairs(choices) do
   local value,key=choice[1],choice[2]
   local rb=CreateFrame("CheckButton",nil,group,"UIRadioButtonTemplate")
   rb:SetSize(20,20);if rb.Text then rb.Text:Hide() end
   rb.cfLabel=group:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
   rb.cfLabel:SetPoint("LEFT",rb,"RIGHT",3,0);rb.cfLabel:SetJustifyH("LEFT")
   rb.cfRadioLabelWidth=118;rb.cfLabel:SetWidth(118)
   rb.cfLabelKey=key;rb:SetScript("OnClick",function() setter(value);CF.RefreshOptionsPages() end)
   rb.cfOptionsLayout={x=0,y=0,width=20,height=20,kind="radio"}
   f.optionNodes[#f.optionNodes+1]=rb;f.controls[id.."_"..value]=rb
   group.cfRadios[#group.cfRadios+1]={button=rb,value=value,key=key}
  end
  return group
 end
 for id,page in pairs(f.pages) do
  local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
  local body=CreateFrame("Frame",nil,scroll);body:SetSize(690,1);scroll:SetScrollChild(body)
  page.cfScroll,page.cfBody=scroll,body
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel",function(_,delta)
   scrollTo(page,(scroll:GetVerticalScroll() or 0)-delta*42)
  end)
 end
 local display,spells=f.pages.general,f.pages.combat
 for _,spec in ipairs({{"size","OP_SIZE",display},{"frame","OP_FRAME",display},{"fade","OP_FADE",display},
  {"visibility","OP_VISIBILITY",display},{"spells","OP_SPELLS",spells},{"hints","OP_HINTS",spells}}) do
  text(spec[1],spec[2],spec[3])
 end
 text("sortTitle","AURA_LAYOUT_MODE",display)
 text("sortNote",nil,display,54,false);text("visibilityNote","OP_OOC_NOTE",display,50,false)
 text("curseNote","OP_CURSE_NOTE",display,40,false)
 text("veilNote",nil,display,62,false)
 text("spellHelp","OP_LIST_HELP",spells,68,false)
 text("spellCount",nil,spells,24,false);text("contextNote","OP_CONTEXT_NOTE",spells,40,false)
 text("spellHeader",nil,spells)
 text("filterShow","OP_ENABLED_SHORT",spells);text("filterMain","OP_MAIN",spells);text("filterOrder","OP_ORDER",spells)
 text("executeTitle","EXECUTE_TITLE",spells)
 f.controls.order=radios("order",display,{{"fixed","AURA_LAYOUT_FIXED"},{"expiration","AURA_LAYOUT_EXPIRATION"}},CF.SetAuraOrderMode)
 for _,r in ipairs(f.controls.order.cfRadios) do ui.tooltip(r.button,r.key,r.key.."_TIP") end
 radios("spellContext",spells,{{"solo","SOLO"},{"dungeon","DUNGEON"},{"raid","RAID"}},function(value) f.cfSpellContext=value end)
 radios("executeModes",spells,{{"auto","EXECUTE_AUTO"},{"35","EXECUTE_35"},{"20","EXECUTE_20"},{"off","EXECUTE_OFF"}},CF.SetExecuteMode)
 for _,r in ipairs(f.controls.executeModes.cfRadios) do ui.tooltip(r.button,"EXECUTE_TITLE","OP_EXECUTE_TIP") end
 ui.checkbox(display,"portraitCurses","AURA_LAYOUT_PORTRAIT","OP_CURSE_NOTE",0,0,300,
  function() return CursiveForeverDB.portraitCurses~=false end,CF.SetPortraitCurses)
 ui.checkbox(spells,"clickCasting","CLICK_CASTING","CLICK_CASTING_TIP",0,0,300,
  CF.ClickCastingEnabled,CF.SetClickCastingEnabled)
 text("clickNote","CLICK_NOTE",spells,100,false)
 local veil=ui.slider(display,"veilOpacity",0,0,0,100,1,CF.GetAuraVeilOpacity,
  function(value) if not f.cfOptionsRefreshing then CF.SetAuraVeilOpacity(value) end end,"AURA_VEIL_OPACITY",function(v) return math.floor(v+.5) end)
 ui.tooltip(veil,"AURA_VEIL_OPACITY","AURA_APPEARANCE_NOTE")
 ui.action(display,"applyAppearance","AURA_APPEARANCE_APPLY",0,0,CF.ReloadForAuraAppearance)
 ui.action(display,"layoutWorkshop","LAYOUT_WORKSHOP",0,0,function() if CF.LayoutWorkshop then CF.LayoutWorkshop.Show() end end)
 ui.action(spells,"resetOrder","AURA_LAYOUT_RESET",0,0,CF.ResetAuraSlotOrder)
 ui.action(spells,"ownClass","OP_OWN_CLASS",0,0,function() f.cfSpellClass=CF.GetPerformanceClassFile();CF.RefreshOptionsPages() end)
 for _,spec in ipairs({{"showAll","OP_ALL_ON",true},{"hideAll","OP_ALL_OFF",false}}) do
  local value=spec[3]
  ui.action(spells,spec[1],spec[2],0,0,function()
   local storage=CF.GetClassFilterStorage(f.cfSpellClass)
   for _,spell in ipairs(CF.GetClassFilterCatalog(f.cfSpellClass)) do
    storage[spell.key]=storage[spell.key] or {};storage[spell.key][f.cfSpellContext]=value
   end
   ui.applyFilters();CF.RefreshOptionsPages()
  end)
 end
 -- Reparent only ordinary options objects. Native tracker widgets never enter this tree.
 f.cfManagedNodes={}
 for _,object in ipairs(f.optionNodes) do
  for _,page in pairs(f.pages) do if object:GetParent()==page then
   object:SetParent(page.cfBody);f.cfManagedNodes[#f.cfManagedNodes+1]=object;break
  end end
 end
 -- Keep layout inputs inactive during a protected combat layout. Navigation,
 -- review and help remain usable; the shield explains the restriction.
 for _,id in ipairs({"general","combat"}) do
  local page=f.pages[id]
  local shield=CreateFrame("Frame",nil,page)
  shield:SetAllPoints(page);shield:SetFrameLevel(page:GetFrameLevel()+90);shield:EnableMouse(true)
  local bg=shield:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.025,.02,.015,.94)
  local label=shield:CreateFontString(nil,"OVERLAY","GameFontNormal")
  label:SetPoint("CENTER");label:SetSize(280,100);label:SetWordWrap(true)
  shield.label=label;page.cfClickCombatShield=shield;shield:Hide()
 end
 local oldSelect=f.CFSelectPage
 f.CFSelectPage=function(id) oldSelect(id);CF.RefreshOptionsPages() end
 f:RegisterEvent("PLAYER_REGEN_DISABLED");f:RegisterEvent("PLAYER_REGEN_ENABLED")
 local oldEvent=f:GetScript("OnEvent")
 f:SetScript("OnEvent",function(self,...)
  if oldEvent then oldEvent(self,...) end
  CF.RefreshOptionsPages()
 end)
end

local function spellRows(f)
 local ui=f.cfOptionsUI
 local own=f.cfSpellClass==CF.GetPerformanceClassFile()
 local keys=own and CF.GetAuraSlotKeys() or {}
 local selected,byKey,ordered,valid={},{},{},{}
 for _,spell in ipairs(CF.GetClassFilterCatalog(f.cfSpellClass)) do byKey[spell.key]=spell end
 for _,spell in ipairs(CF.GetAuraLayoutCatalog()) do valid[spell.key]=true end
 for i,key in ipairs(keys) do selected[key]=i;ordered[#ordered+1]=byKey[key] end
 for _,spell in ipairs(CF.GetClassFilterCatalog(f.cfSpellClass)) do if not selected[spell.key] then ordered[#ordered+1]=spell end end
 local storage=CF.GetClassFilterStorage(f.cfSpellClass)
 for _,row in ipairs(f.cfSpellRows) do row:Hide() end
 for i,spell in ipairs(ordered) do
  local row=f.cfSpellRows[i]
  if not row then
   row=CreateFrame("Frame",nil,f.pages.combat.cfBody,"BackdropTemplate")
   row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
   row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(22,22);row.icon:SetPoint("LEFT",2,0);row.icon:SetTexCoord(.08,.92,.08,.92)
   row.label=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");row.label:SetPoint("LEFT",28,0)
   row.label:SetWidth(118);row.label:SetJustifyH("LEFT");row.label:SetWordWrap(false)
   row.hover=CreateFrame("Button",nil,row);row.hover:SetPoint("TOPLEFT",0,0);row.hover:SetSize(150,38)
   row.hover:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(row.displayName,1,.82,.35)
    GameTooltip:AddLine(row.description or CF.T("NO_DESCRIPTION"),1,1,1,true);GameTooltip:Show()
   end)
   row.hover:SetScript("OnLeave",function() GameTooltip:Hide() end)
   for _,kind in ipairs({"show","main"}) do
    local mode=kind;local cb=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
    cb:SetSize(24,24);if cb.Text then cb.Text:Hide() end
    cb:SetScript("OnClick",function(self)
     if mode=="show" then
      local s=CF.GetClassFilterStorage(f.cfSpellClass);s[row.key]=s[row.key] or {}
      s[row.key][f.cfSpellContext]=self:GetChecked() and true or false;ui.applyFilters()
     elseif f.cfSpellClass==CF.GetPerformanceClassFile() then
      if not CF.SetAuraSlotEnabled(row.key,self:GetChecked() and true or false) then f.cfSlotLimit=true end
     end
     CF.RefreshOptionsPages()
    end)
    ui.tooltip(cb,mode=="show" and "OP_ENABLED" or "OP_MAIN",mode=="show" and "OP_CONTEXT_NOTE" or "OP_MAIN_TIP")
    row[kind]=cb;f.controls["spell_"..i.."_"..kind]=cb
   end
   for _,direction in ipairs({-1,1}) do
    local step=direction
    local b=CF.AuraLayoutUI.action(row,step==-1 and "CARDS_MOVE_UP" or "CARDS_MOVE_DOWN",true)
    b:SetSize(24,26);b.cfLabel:SetWidth(22);b.cfDecorIcon:Hide()
    b:SetScript("OnClick",function() CF.MoveAuraSlot(row.key,step);CF.RefreshOptionsPages() end)
    row[step==-1 and "up" or "down"]=b;f.controls["spell_"..i.."_"..step]=b
   end
   f.cfSpellRows[i]=row
  end
  row.key=spell.key
  local name,icon,description=CF.AuraLayoutUI.spellInfo(spell)
  row.displayName=name or spell.fallback;row.description=description
  row.label:SetText((selected[spell.key] and selected[spell.key]..". " or "")..row.displayName)
  row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  row.show:SetChecked(not storage[spell.key] or storage[spell.key][f.cfSpellContext]~=false)
  row.main:SetChecked(selected[spell.key]~=nil);enabled(row.main,own and valid[spell.key] or false)
  local position=selected[spell.key]
  enabled(row.up,own and position~=nil and position>1);enabled(row.down,own and position~=nil and position<#keys)
  row:Show()
 end
 f.cfSpellCount=#ordered
 f.cfLabels.spellHeader:SetText(CF.TF("OP_FILTER_CLASS",CF.GetClassDisplayName(f.cfSpellClass)))
 f.cfLabels.spellCount:SetText(f.cfSlotLimit and CF.T("AURA_LAYOUT_LIMIT") or CF.TF("AURA_LAYOUT_COUNT",#keys))
 f.cfSlotLimit=nil
 f.cfLabels.spellHelp:SetText(CF.T(own and "OP_LIST_HELP" or "OP_OTHER_CLASS"))
 enabled(f.controls.resetOrder,own)
end

function CF.RefreshOptionsPages(frame)
 local f=frame or CF.optionsPagesFrame
 if not f or not f.cfUnifiedOptions or f.cfOptionsRefreshing then return end
 f.cfOptionsRefreshing=true
 -- Reflect loaded/imported layouts in every existing control. CFRefresh is
 -- read-only: slider synchronization must not invoke its setting writer.
 for _,control in pairs(f.controls) do
  if control.CFRefresh then control:CFRefresh() end
 end
 local view=CF.pendingTrackerView or CF.GetTrackerView()
 local ordered=view=="standard" or view=="healthbar"
 local function refreshRadio(id,current,available)
  for _,r in ipairs(f.controls[id].cfRadios) do
   r.button:SetChecked(current==r.value);r.button.cfLabel:SetText(CF.T(r.key))
   enabled(r.button,available~=false)
  end
 end
 refreshRadio("order",ordered and (CF.pendingAuraOrderMode or CF.GetAuraOrderMode()) or "fixed",ordered)
 refreshRadio("spellContext",f.cfSpellContext)
 refreshRadio("executeModes",CF.GetExecuteMode())
 f.cfLabels.sortNote:SetText(CF.T(not ordered and "OP_FIXED_NOTE" or CF.pendingAuraOrderMode and "AURA_LAYOUT_ORDER_PENDING" or "AURA_LAYOUT_MODE_TIP"))
 enabled(f.controls.outOfCombat,not CursiveForeverDB.hideWindowOutOfCombat)
 enabled(f.controls.portraitCurses,CF.GetPerformanceClassFile()=="WARLOCK" and CF.GetRequestedTrackerExtras())
 f.controls.portraitCurses:SetChecked(CursiveForeverDB.portraitCurses~=false)
 f.cfLabels.visibilityNote:SetShown(CursiveForeverDB.hideWindowOutOfCombat==true)
 f.cfLabels.veilNote:SetText(CF.T(CF.HasPendingAuraAppearance() and "AURA_APPEARANCE_PENDING" or "AURA_APPEARANCE_NOTE"))
 enabled(f.controls.applyAppearance,CF.CanReloadAuraAppearance())
 spellRows(f)
 if f.cfOptionsPlaced then CF.LayoutOptionsPages(f,f.cfOptionsBindings,true) end
 -- A page refresh at the midpoint of the book animation must not make
 -- controls clickable through the turning leaf. The final select refreshes
 -- their normal enabled states after the existing animation restores input.
 if f.pageTurnLayer and f.pageTurnLayer.state then
  for _,control in pairs(f.controls) do if control.SetEnabled then control:SetEnabled(false) end end
 end
 for _,id in ipairs({"general","combat"}) do
  local shield=f.pages[id].cfClickCombatShield
  if shield then
   shield.label:SetText(CF.T("CLICK_LOCKED"))
   shield:SetShown(CF.ClickLayoutLocked and CF.ClickLayoutLocked() or false)
  end
 end
 f.cfOptionsRefreshing=nil
end

function CF.LayoutOptionsPages(f,bindings,refreshOnly)
 if not f.cfUnifiedOptions then return end
 f.cfOptionsBindings=bindings
 local full=f.cfGrimoire
 -- Jaina has one continuous panel, rather than two separated book leaves.
 -- Keep each control's width; remove only the unused central gap.
 local column,right=full and 296 or 326,f.cfJaina and 324 or full and 394 or 352
 local contentWidth=right+column
 local function node(object,pageID,x,y,w,h)
  object:SetParent(f.pages[pageID].cfBody);place(object,x,y,w,h);object:Show()
 end
 local function textHeight(object,width,fallback)
  object:SetWidth(width)
  object:SetHeight(0)
  local measured=object.GetStringHeight and object:GetStringHeight()
  local height=measured and measured>0 and math.ceil(measured)+2 or fallback
  object:SetHeight(height)
  return height
 end
 local function label(key,pageID,col,y,h)
  local object=f.cfLabels[key] or f.optionLabels[key]
  h=textHeight(object,column,h or 22)
  node(object,pageID,col==1 and right or 0,y,column,h)
  if full then object:SetTextColor(.09,.05,.025,1) else
   local heading=object.cfOptionsLayout and object.cfOptionsLayout.kind=="heading"
   object:SetTextColor(heading and .87 or .76,heading and .72 or .73,heading and .40 or .67,1)
  end
  return h
 end
 local function control(key,pageID,col,y,h,w)
  local object=f.controls[key];local width=w or column;local x=col==1 and right or 0
  local kind=object.cfOptionsLayout and object.cfOptionsLayout.kind
  node(object,pageID,x,y,kind=="checkbox" and 26 or width,h or 28)
  if kind=="checkbox" then object.Text:SetWidth(width-34);object:SetHitRectInsets(0,-(width-26),0,0)
  elseif object.cfLabel then object.cfLabel:SetWidth(width-32) end
 end
 local function slider(key,pageID,col,y)
  local object=f.controls[key];local x=col==1 and right or 0
  local inset=full and not f.cfJaina and 32 or 0
  local captionWidth=f.cfJaina and column-70 or column
  local captionHeight=textHeight(object.cfCaption,captionWidth,24)
  node(object.cfCaption,pageID,x,y,captionWidth,captionHeight)
  node(object,pageID,x+inset,y+captionHeight+4,column-inset*2,18)
  -- Leave room below the rail for the native limit labels (also in MoP).
  local labelRoom=full and 24 or 18
  return captionHeight+4+18+(full and labelRoom or 2)
 end
 local function stack(pageID,col)
  local y=0
  local flow={}
  function flow.text(key,fallback,gap)
   y=y+label(key,pageID,col,y,fallback)+(gap or 4)
  end
  function flow.section(key)
   if y>0 then y=y+(full and 12 or 8) end
   flow.text(key,22)
   if not full or f.cfJaina then
    f.cfMinimalLines=f.cfMinimalLines or {}
    local id=pageID..col..key;local t=f.cfMinimalLines[id]
    if not t then t=f.pages[pageID].cfBody:CreateTexture(nil,"ARTWORK");f.cfMinimalLines[id]=t end
    place(t,col==1 and right or 0,y-3,column,1)
    if f.cfJaina then t:SetColorTexture(.38,.68,.85,.65) else t:SetColorTexture(.55,.41,.19,.65) end
    t:Show();y=y+3
   end
  end
  function flow.control(key,height,gap)
   height=height or 28
   if not full and height>=28 and height<=40 then height=26 end
   control(key,pageID,col,y,height)
   y=y+height+(gap or (full and 4 or 3))
  end
  function flow.slider(key) y=y+slider(key,pageID,col,y) end
  function flow.position() return y end
  function flow.advance(amount) y=y+amount end
  return flow
 end
 if not refreshOnly then
  for _,object in ipairs(f.cfManagedNodes) do object:Hide() end
  for _,line in ipairs(f.optionDividers) do line:Hide() end
 end
 if f.cfMinimalLines then for _,t in pairs(f.cfMinimalLines) do t:Hide() end end
 for id,page in pairs(f.pages) do
  place(page,f.cfJaina and 252 or full and 325 or 20,f.cfJaina and 466 or full and 418 or 100,f.cfJaina and 644 or full and 710 or 720,f.cfJaina and 320 or full and 234 or 460)
  page.cfViewportHeight=f.cfJaina and 320 or full and 234 or 460
  place(page.cfScroll,0,0,contentWidth,page.cfViewportHeight)
  page.cfBody:SetWidth(contentWidth)
 end
 -- Content follows its measured text, so hidden options leave no blank rows.
 -- Only ordinary options objects are moved; tracker and secure frames are untouched.
 local view=CF.pendingTrackerView or CF.GetTrackerView()
 local left,rightSide=stack("general",0),stack("general",1)
 left.section("TARGET_DISPLAY");left.control("view",56)
 if view=="bars" then left.control("barsSpellNames",30) end
 left.control("health")
 left.section("sortTitle");left.control("order")
 if full then left.text("sortNote",56) end
 left.section("frame")
 for _,key in ipairs({"header","hideFrame","extraIcons","portraitCurses"}) do left.control(key,28) end
 if full then left.control("lock",28) end
 if full then left.text("curseNote",42) end
 if full then left.control("resetPosition") end
 left.section("visibility");left.control("hideOutOfCombat",30);left.control("outOfCombat",30)
 if CursiveForeverDB.hideWindowOutOfCombat then left.text("visibilityNote",54) end
 rightSide.section("size")
 for _,key in ipairs({"scale","trackerWidth","trackerHeight"}) do rightSide.slider(key) end
 rightSide.control("resetScale")
 if not full then rightSide.control("lock");rightSide.control("resetPosition") end
 rightSide.section("fade");rightSide.slider("transparency");rightSide.slider("veilOpacity")
 if full then rightSide.text("veilNote",70);rightSide.control("applyAppearance",40);rightSide.control("layoutWorkshop",40)
 else rightSide.control("applyAppearance",32) end
 local heights={general=math.max(left.position(),rightSide.position())}

 left,rightSide=stack("combat",0),stack("combat",1)
 left.section("spells");left.text("spellHeader",22)
 left.control("spellContext",26);left.text("spellCount",22)
 local headers={{"filterShow",144,40},{"filterMain",187,44},{"filterOrder",236,58}}
 local headerHeight=20
 for _,p in ipairs(headers) do
  local heading=f.cfLabels[p[1]]
  heading:SetFontObject("GameFontNormalSmall")
  local h=textHeight(heading,p[3],20)
  headerHeight=math.max(headerHeight,h)
  node(heading,"combat",p[2],left.position(),p[3],h)
  f.cfLabels[p[1]]:SetJustifyH("CENTER")
  if full then f.cfLabels[p[1]]:SetTextColor(.09,.05,.025,1) else f.cfLabels[p[1]]:SetTextColor(.87,.78,.55,1) end
 end
 left.advance(headerHeight+2)
 for i,row in ipairs(f.cfSpellRows) do if i<=f.cfSpellCount then
  place(row,0,left.position(),column,32);row:Show()
  row.hover:SetHeight(32)
  row:SetBackdropColor(full and .26 or .06,full and .16 or .04,full and .06 or .025,full and .10 or .85)
  row.label:SetTextColor(full and .10 or .95,full and .06 or .82,full and .025 or .55,1)
  place(row.show,155,4,24,24);place(row.main,197,4,24,24)
  place(row.up,238,3,24,26);place(row.down,269,3,24,26)
  left.advance(34)
 end end
 left.advance(4)
 local bottom=left.position()
 control("showAll","combat",0,bottom,30,column/2-4)
 node(f.controls.hideAll,"combat",column/2+4,bottom,column/2-4,30);f.controls.hideAll.cfLabel:SetWidth(column/2-26)
 left.advance(36);left.text("contextNote",44);left.text("spellHelp",90)
 rightSide.section("hints");rightSide.control("experimental",30)
 rightSide.section("executeTitle");rightSide.control("executeModes",52)
 rightSide.section("PRIORITY_MARKER");rightSide.text("OPTIONS_PRIORITY_HELP",44);rightSide.control("priority")
 rightSide.section("CURSE_WATCHER");rightSide.text("CURSE_SUMMARY",74);rightSide.control("curse")
 rightSide.advance(8);rightSide.control("resetOrder",40)
 if f.cfSpellClass~=CF.GetPerformanceClassFile() then rightSide.control("ownClass") end
 rightSide.advance(8);rightSide.control("clickCasting",32)
 if full then rightSide.text("clickNote",110) else
  f.cfLabels.clickNote:Hide();f.cfMinimalCombatY=rightSide.position()+10;rightSide.advance(90)
 end
 heights.combat=math.max(left.position(),rightSide.position())

 left,rightSide=stack("performance",0),stack("performance",1)
 left.section("OPTIONS_MONITOR");left.text("PERFORMANCE_SUMMARY",78);left.control("monitor")
 left.section("OPTIONS_RECORDING");left.control("recording");left.slider("minimum")
 left.text("OPTIONS_ARCHIVE_HELP",94)
 rightSide.section("CARDS_TITLE");rightSide.text("CARDS_SUMMARY",78);rightSide.control("cards")
 rightSide.section("PERFORMANCE_LAYOUT");rightSide.text("OPTIONS_LAYOUT_HELP",70);rightSide.control("layout")
 heights.performance=math.max(left.position(),rightSide.position())

 left,rightSide=stack("help",0),stack("help",1)
 left.section("OPTIONS_ACCESS");left.control("language");left.control("minimap")
 left.slider("radius");left.text("OPTIONS_MINIMAP_HELP",64)
 if f.designGroup then
  if full then
   -- Full artwork: the selector hangs below the right-hand bookmarks.
   f.designGroup:SetParent(f);place(f.designGroup,1095,617,190,190);f.designGroup:Show()
   f.designGroup:SetFrameLevel(f:GetFrameLevel()+60)
  else
   node(f.designGroup,"help",0,left.position(),column,128);left.advance(136)
   f.designGroup:SetFrameLevel(f.pages.help.cfBody:GetFrameLevel()+1)
  end
  for name,button in pairs(f.designChoices) do
   button:SetFrameLevel(f.designGroup:GetFrameLevel()+1)
   f.controls["optionsDesign_"..name]=button
  end
  if not full then
   for i,name in ipairs({"FULL","minimal"}) do place(f.designChoices[name],(i-1)*155,34,20,20) end
   if f.cfDesignHelp then f.cfDesignHelp:SetWidth(column) end
   if f.cfDesignTitle then f.cfDesignTitle:SetWidth(column) end
  end
 end
 f.cfArtworkEntryY=left.position();f.cfMinimalHelpY=left.position()
 left.advance(CF.OptionsArtwork and 38 or 30)
 left.text("OPTIONS_COMMANDS",148);left.text("OPTIONS_CREDITS",64)
 rightSide.section("OPTIONS_INFORMATION")
 local buildHeight=textHeight(bindings.build,column,94)
 node(bindings.build,"help",right,rightSide.position(),column,buildHeight)
 rightSide.advance(buildHeight+6)
 rightSide.control("history");rightSide.control("status");rightSide.control("contact",40)
 rightSide.section("CONTROLS");rightSide.text("HELP_TEXT",176)
 rightSide.section("RAID_MANY");rightSide.text("RAID_MANY_TEXT",100)
 heights.help=math.max(left.position(),rightSide.position())
 for id,page in pairs(f.pages) do
  local height=math.max(page.cfViewportHeight,heights[id]+8)
  page.cfContentHeight=height;page.cfBody:SetHeight(height)
  scrollTo(page,page.cfScroll:GetVerticalScroll() or 0)
 end
 for _,id in ipairs({"view","order","spellContext","executeModes"}) do
  local group=f.controls[id];local list=group.cfRadios
  if not list then list={};for _,mode in ipairs({"standard","matrix","bars","healthbar"}) do list[#list+1]={button=group.radios[mode]} end end
  for i,r in ipairs(list) do
   local cols=id=="spellContext" and 3 or 2;local pitch=column/cols
   place(r.button,((i-1)%cols)*pitch,math.floor((i-1)/cols)*(id=="view" and 22 or 26),20,20)
   r.button.cfLabel:SetWidth(pitch-25);r.button:SetHitRectInsets(0,-(pitch-25),0,0)
  end
 end
 place(f.controls.view.cfPending,0,44,column,12)
 f.controls.view.CFRefresh()
 f.controls.barsSpellNames:SetShown(view=="bars")
 -- Removed launchers are never displayed or keyboard-reachable in this organization.
 for _,key in ipairs({"auraLayout","filters","execute"}) do f.controls[key]:Hide() end
 for _,key in ipairs({"DISPLAY_HINT","CLASS_FILTER","CLASS_FILTER_SUMMARY"}) do f.optionLabels[key]:Hide() end
 f.controls.ownClass:SetShown(f.cfSpellClass~=CF.GetPerformanceClassFile())
 f.cfLabels.visibilityNote:SetShown(CursiveForeverDB.hideWindowOutOfCombat==true)
 for _,tab in pairs(f.tabs) do tab.cfLabel:SetWordWrap(true);tab.cfLabel:SetHeight(full and 36 or 28) end
 f.optionLabels.OPTIONS_SAVED:SetText(CF.T("OP_SAVED"))
 f.cfOptionsPlaced=true
 if not full then
  f.cfLabels.sortNote:Hide();f.cfLabels.curseNote:Hide();f.cfLabels.veilNote:Hide()
 end
 if CF.MinimalOptions then CF.MinimalOptions.Apply(f,bindings) end
end

function CF.OpenOptionsPage(page,classFile)
 CF.ShowOptionsWindow()
 local f=CF.optionsPagesFrame
 if not f then return end
 if page=="combat" then
  f.cfSpellClass=type(classFile)=="string" and CF.CLASS_FILTERS[classFile] and classFile or CF.GetPerformanceClassFile()
  CF.RefreshClassSpellRanks()
 end
 f.CFCancelPageTurn(false);f.CFSelectPage(page);scrollTo(f.pages[page],0)
 CF.RefreshOptionsPages();f:Show();f:Raise()
end
