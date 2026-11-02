local _,addon=...
local CF,C=addon.CF,addon.Client
local releaseLabel=(C.build.releaseChannel or "release"):upper()
local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd8b15a"..C.title..":|r "..text) end
end
function CF.ClientFeatureNotice()
    say(CF.GetEffectiveLanguage()=="de"
        and "Diese Ausgabe enthält den Tracker mit vier Ansichten. Auswertung, Handlungsvorschläge und Fluchwächter stehen derzeit nur in Forever zur Verfügung."
        or "This edition includes the tracker with four views. Analysis, action suggestions and Curse Watcher are currently available only in Forever.")
end
function CF.GetClientReport()
    local lines={C.title.." "..C.build.version,"build="..C.build.buildID,
        "reference="..C.build.client.."/"..C.build.build.." interface="..C.build.interface,
        "aura_backend="..(C.classicAuras and "public_classic" or "native_container")}
    if type(GetBuildInfo)=="function" then
        local ok,v,b,_,toc=pcall(GetBuildInfo)
        if ok and C.Readable(v) and C.Readable(b) and C.Readable(toc) then
            lines[#lines+1]="running="..tostring(v).."/"..tostring(b).." interface="..tostring(toc)
            if tonumber(toc)~=C.build.interface then lines[#lines+1]="Client differs from package reference." end
        end
    end
    lines[#lines+1]="aura_index="..type(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex)
    lines[#lines+1]="secret_guard="..type(issecretvalue).." access_guard="..type(canaccessvalue)
    if addon.ClassicAuraBackend then
        lines[#lines+1]="last_read="..addon.ClassicAuraBackend.status.." rejected="..addon.ClassicAuraBackend.rejected
    end
    lines[#lines+1]="Automatic Execute: "..(C.isForever and "Forever profiles" or C.edition=="Era" and "Warrior / Paladin" or "pending; use manual 20% / 35%")
    lines[#lines+1]="Live validation: "..(C.isForever and "port regression package; existing client baseline" or "pending")
    return table.concat(lines,"\n")
end
SLASH_CURSIVECLIENT1="/cfclient"
SlashCmdList.CURSIVECLIENT=function()
    for line in CF.GetClientReport():gmatch("[^\n]+") do say(line) end
end
if C.isForever then
    if C.build.changelogEN and C.build.changelogDE then
        -- The release package and in-game history share the maintained texts.
        CF.CHANGELOG_EN=C.build.changelogEN
        CF.CHANGELOG_DE=C.build.changelogDE
        return
    end
    CF.CHANGELOG_EN=C.title.." "..C.build.version.." — "..releaseLabel.."\nClient reference: "..C.build.client.." ("..C.build.build..")\n"
        .."Maintenance: no changes to Forever features, target/focus arrangement or saved preferences.\n\n1.9.2 — RELEASE\n"
        .."Standard keeps up to eight main icons on one line and grows wider after the fourth. An already displayed, still-selected target stays visible as combat begins while combat and threat data catch up.\n\n"
        .."1.9.2-beta2: Standard keeps up to eight main icons on one line and grows wider after the fourth. The Main tooltip explains the width. Companion build for the saved-settings fix in the new editions.\n\n"..CF.CHANGELOG_EN
    CF.CHANGELOG_DE=C.title.." "..C.build.version.." — "..releaseLabel.."\nClientstand: "..C.build.client.." ("..C.build.build..")\n"
        .."Wartung: keine Änderungen an Forever-Funktionen, Ziel-/Fokus-Anordnung oder gespeicherten Einstellungen.\n\n1.9.2 — RELEASE\n"
        .."Standard zeigt bis zu acht Hauptsymbole in einer Reihe und wird ab dem fünften breiter. Ein bereits angezeigtes, weiterhin angewähltes Ziel bleibt beim Kampfbeginn sichtbar, während die Kampf- und Bedrohungsdaten noch eintreffen.\n\n"
        .."1.9.2-beta2: Standard zeigt bis zu acht Hauptsymbole in einer Reihe und wird ab dem fünften breiter. Der Haupt-Hinweis erklärt die Breite. Begleitender Stand zur Speicherkorrektur in den neuen Ausgaben.\n\n"..CF.CHANGELOG_DE
    return
end

local previousVersion=C.edition=="MoP" and "5.0.0" or C.edition=="Era" and "1.0.0" or "12.0.0"
CF.CHANGELOG_EN=C.title.." "..previousVersion.." — RELEASE\nClient reference: "..C.build.client.." ("..C.build.build..")\n\n"
    .."First release: personal DoT and debuff tracking, four views, class spell selections and click casting on target or focus in fixed layouts.\n"
    .."An already displayed, still-selected target stays visible as combat begins while combat and threat data catch up.\n"
    ..(C.edition=="Era" and "Minimap distance: 70–115 px. Saved distances within this range are preserved.\n" or "")
    .."Settings and main-effect selections persist through UI reloads and game restarts. Standard keeps up to eight main icons on one line, growing wider after the fourth.\n\n"
    .."Analysis, action suggestions and Curse Watcher are currently available only in Forever."
CF.CHANGELOG_DE=C.title.." "..previousVersion.." — RELEASE\nClientstand: "..C.build.client.." ("..C.build.build..")\n\n"
    .."Erstveröffentlichung: eigene DoTs und Debuffs verfolgen, vier Ansichten, klassenspezifische Zauberauswahl und Klickzaubern auf Ziel oder Fokus bei festen Plätzen.\n"
    .."Ein bereits angezeigtes, weiterhin angewähltes Ziel bleibt beim Kampfbeginn sichtbar, während die Kampf- und Bedrohungsdaten noch eintreffen.\n"
    ..(C.edition=="Era" and "Minimap-Abstand: 70–115 px. Gespeicherte Abstände innerhalb dieses Bereichs bleiben erhalten.\n" or "")
    .."Einstellungen und Hauptauswahl bleiben nach UI-Neuladen und Spielneustart erhalten. Standard zeigt bis zu acht Hauptsymbole in einer Reihe und wird ab dem fünften breiter.\n\n"
    .."Auswertung, Handlungsvorschläge und Fluchwächter stehen derzeit nur in Forever zur Verfügung."
CF.CHANGELOG_EN=C.title.." "..C.build.version.." — "..releaseLabel.."\nClient reference: "..C.build.client.." ("..C.build.build..")\n\n"
    ..(C.edition=="MoP" and "Minimap distance: 70–115 px; valid saved distances are preserved. Grimoire slider labels no longer overlap the decorative ends. The click-casting option explains Focus/Target placement and how to keep enemy rows in place when switching targets. Your click-casting setting is preserved.\n\n"
        or "Maintenance: no changes to this edition's display, click casting or saved preferences.\n\n")
    ..CF.CHANGELOG_EN
CF.CHANGELOG_DE=C.title.." "..C.build.version.." — "..releaseLabel.."\nClientstand: "..C.build.client.." ("..C.build.build..")\n\n"
    ..(C.edition=="MoP" and "Minimap-Abstand: 70–115 px; gültige gespeicherte Abstände bleiben erhalten. Reglerziffern überlappen im Grimoire nicht mehr mit den Verzierungen. Die Klickzauber-Option erklärt die Fokus-/Zielanordnung und wie Gegnerzeilen beim Zielwechsel an ihrem Platz bleiben. Deine Klickzauber-Einstellung bleibt erhalten.\n\n"
        or "Wartung: keine Änderungen an Anzeige, Klickzaubern oder gespeicherten Einstellungen dieser Ausgabe.\n\n")
    ..CF.CHANGELOG_DE
if C.build.changelogEN and C.build.changelogDE then
    -- Use the same maintained history in game and in the release attachment.
    CF.CHANGELOG_EN=C.build.changelogEN
    CF.CHANGELOG_DE=C.build.changelogDE
end
CF.L_DE.PERFORMANCE_SUMMARY="Die Auswertung steht derzeit nur in der Forever-Ausgabe zur Verfügung."
CF.L_EN.PERFORMANCE_SUMMARY="Performance analysis is currently available only in the Forever edition."
CF.L_DE.FILTER_NOTE="Häkchen = in diesem Spielmodus anzeigen. Neue, noch nicht katalogisierte Effekte bleiben automatisch sichtbar."
CF.L_EN.FILTER_NOTE="Checked = show in this play mode. New, not-yet-catalogued effects remain visible automatically."
CF.L_DE.NO_DESCRIPTION="Keine Beschreibung vom Spielclient geliefert."
CF.L_EN.NO_DESCRIPTION="No description supplied by the game client."
CF.ShowCardSelection=CF.ClientFeatureNotice
CF.ShowExperimentalOptions=CF.ClientFeatureNotice
CF.L_DE.STATUS_HEADER="Status · "..C.title.." %s"
CF.L_EN.STATUS_HEADER="Status · "..C.title.." %s"
CF.L_DE.PRIORITY_MARKER_TIP="Gegner mit dieser Schlachtzugsmarkierung stehen bevorzugt oben, soweit die Markierung verfügbar ist."
CF.L_EN.PRIORITY_MARKER_TIP="Enemies with this raid marker are prioritized whenever their marker is available."
CF.L_DE.CURSE_SUMMARY="Der Fluchwächter folgt in einer späteren Version. Eigene Flüche werden bereits im Tracker angezeigt."
CF.L_EN.CURSE_SUMMARY="Curse Watcher follows in a later version. Your curses already appear in the tracker."
CF.L_DE.AURA_LAYOUT_PORTRAIT_NOTE="Eigene unterstützende Flüche neben dem Porträt bzw. Lebensbalken. Welche Flüche verfügbar sind, richtet sich nach deiner Spielversion."
CF.L_EN.AURA_LAYOUT_PORTRAIT_NOTE="Your utility curses beside the portrait or health bar. Available curses depend on your game edition."
CF.L_DE.OP_LIST_HELP="Anzeigen: im gewählten Spielmodus aktiv. Haupt: großer Platz in der Anzeige. Die Pfeile ändern die feste Reihenfolge."
CF.L_EN.OP_LIST_HELP="Show: enabled in the selected context. Main: a main display slot. The arrows change your fixed order."
CF.L_DE.OP_MAIN_TIP="Bis zu acht Haupteffekte wählen und mit den Pfeilen anordnen. Weitere aktivierte Effekte erscheinen als Zusatzsymbole. In Standard bleiben alle Hauptsymbole in einer Reihe; ab dem fünften wird das Fenster breiter statt höher."
CF.L_EN.OP_MAIN_TIP="Choose up to eight main effects and reorder them with the arrows. Other enabled effects appear as extra icons. Standard keeps all main icons on one line; adding a fifth or more makes the window wider instead of taller."
CF.L_DE.AURA_LAYOUT_SAVED="Diese Reihenfolge gilt für feste Plätze und wird je Charakter gespeichert. Leere Plätze sind kein Trefferbeweis."
CF.L_EN.AURA_LAYOUT_SAVED="Fixed slot order is saved per character. Empty slots do not confirm a hit."
if C.edition=="MoP" then
    CF.L_DE.CLICK_CASTING="Klickzaubern (Fokus/Ziel oben)"
    CF.L_EN.CLICK_CASTING="Click to cast (Focus/Target first)"
    CF.L_DE.CLICK_NOTE="An: Fokus zuerst, aktuelles Ziel darunter. Zielwechsel ersetzt den Gegner in der Zielzeile. Aus: Zielwechsel verschiebt keine Gegnerzeilen. Feste Plätze betrifft die Zauber."
    CF.L_EN.CLICK_NOTE="On: Focus first, current target next. Changing target replaces the enemy in the Target row. Off: target changes do not move enemy rows. Fixed order refers to spells."
    CF.L_DE.CLICK_CASTING_TIP="Bei festen Zauberplätzen auf Hauptsymbole, Zeitzellen oder DoT-Balken klicken: Fokus zuerst, aktuelles Ziel darunter. Bei Zielwechsel wechselt der Gegner in der Zielzeile. Für ruhige Gegnerzeilen Klickzaubern ausschalten. Fokus und Ziel bleiben getrennte Zeilen, auch beim selben Gegner. Außerhalb des Kampfes ändern."
    CF.L_EN.CLICK_CASTING_TIP="With fixed spell positions, click main icons, timer cells or DoT bars: Focus first, current target next. Changing target replaces the enemy in the Target row. Turn click casting off to keep enemy rows in place when switching targets. Focus and Target remain separate rows, even for the same enemy. Change this outside combat."
end
CF.L_DE.OPTIONS_COMMANDS="/cf — Gegnerübersicht\n/cf options — Einstellungen\n/cf dots — Zauber & Priorität\n/cfclient — Clientstatus\n/cf trace — Trackerdiagnose"
CF.L_EN.OPTIONS_COMMANDS="/cf — enemy tracker\n/cf options — settings\n/cf dots — spells & priority\n/cfclient — client status\n/cf trace — tracker diagnostics"
local autoDE=C.edition=="Era" and "Automatisch: Krieger und Paladine. Andere Klassen verwenden bei Bedarf 20% oder 35%." or "Automatische Klassenregeln folgen in einer späteren Version. Bis dahin 20% oder 35% manuell wählen."
local autoEN=C.edition=="Era" and "Automatic: Warriors and Paladins. Other classes can choose 20% or 35%." or "Automatic class rules follow in a later version. Select 20% or 35% manually for now."
CF.L_DE.OP_EXECUTE_TIP=autoDE;CF.L_EN.OP_EXECUTE_TIP=autoEN
CF.L_DE.EXECUTE_TIP=autoDE;CF.L_EN.EXECUTE_TIP=autoEN
local refresh=CF.RefreshOptionsPages
function CF.RefreshOptionsPages(...)
    if refresh then refresh(...) end
    local f=CF.optionsPagesFrame
    if not f or not f.controls then return end
    for _,key in ipairs({"experimental","curse","monitor","cards","recording","minimum","layout"}) do
        local control=f.controls[key]
        if control then control:SetEnabled(false);control:SetAlpha(.45) end
    end
    local control=f.controls.experimental
    if control and control.cfLabel then control.cfLabel:SetText(CF.GetEffectiveLanguage()=="de" and "Vorschläge: folgen später" or "Suggestions: coming later") end
end
