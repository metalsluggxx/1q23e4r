local _,addon=...
local CF=addon.CF
-- Optional artwork discovery only. No loading, enabling, timers or gameplay hooks.
local P={name='CursiveCharacterPack'};CF.CharacterPack=P
local function public(value)
 if issecretvalue and issecretvalue(value) then return false end
 if canaccessvalue and not canaccessvalue(value) then return false end
 return true
end
local function query(fn,...)
 if type(fn)~='function' then return nil end
 local ok,value=pcall(fn,...)
 if ok and public(value) then return value end
end
function P.Status()
 local pack=_G.CursiveCharacterPack
 if type(pack)=='table' and public(pack) then
  if type(pack.apiVersion)~='number' then return 'invalid' end
  if pack.apiVersion<1 then return 'outdated' end
  if pack.apiVersion>1 then return 'newer' end
  local theme=type(pack.themes)=='table' and pack.themes.jaina
  if type(theme)~='table' or theme.layout~='jaina-v7' or theme.frameCount~=235 or theme.fps~=24
   or theme.path~='Interface\\AddOns\\CursiveCharacterPack\\Media\\Jaina\\' then return 'invalid' end
  return 'available',theme
 end
 local api=C_AddOns
 local version=query(api and api.GetAddOnMetadata or GetAddOnMetadata,P.name,'Version')
 local title=query(api and api.GetAddOnMetadata or GetAddOnMetadata,P.name,'Title')
 if not version and not title then return 'missing' end
 local character=query(UnitName,'player')
 local enabled
 if api and type(api.GetAddOnEnableState)=='function' then
  enabled=query(api.GetAddOnEnableState,P.name,character)
 else
  -- Legacy globals have the opposite argument order.
  enabled=query(GetAddOnEnableState,character,P.name)
 end
 if enabled==0 then return 'disabled' end
 local format=query(api and api.GetAddOnMetadata or GetAddOnMetadata,P.name,'X-Cursive-Pack-API')
 local number=type(format)=='string' and tonumber(format)
 if number and number<1 then return 'outdated' end
 if number and number>1 then return 'newer' end
 local loaded=query(api and api.IsAddOnLoaded or IsAddOnLoaded,P.name)
 return loaded and 'invalid' or 'not_loaded'
end
function P.Message()
 local de=CF.GetEffectiveLanguage()=='de'
 local status=P.Status()
 if status=='available' then
  return de and 'Cursive Character Pack: Jaina verfügbar.' or 'Cursive Character Pack: Jaina available.'
 elseif status=='disabled' then
  return de and 'Cursive Character Pack ist deaktiviert. In der Addon-Liste aktivieren und die Oberfläche neu laden.' or 'Cursive Character Pack is disabled. Enable it in the AddOns list and reload the interface.'
 elseif status=='outdated' then
  return de and 'Bitte Cursive Character Pack aktualisieren und WoW neu starten.' or 'Please update Cursive Character Pack and restart WoW.'
 elseif status=='newer' then
  return de and 'Dieses Charakterpaket benötigt eine neuere Cursive-Version. Bitte Cursive aktualisieren.' or 'This character pack needs a newer Cursive version. Please update Cursive.'
 elseif status=='invalid' then
  return de and 'Jaina ist nicht verfügbar. Bitte Cursive Character Pack vollständig neu installieren und WoW neu starten.' or 'Jaina is unavailable. Please reinstall the complete Cursive Character Pack and restart WoW.'
 elseif status=='not_loaded' then
  return de and 'Cursive Character Pack ist nicht geladen. Addon-Liste prüfen und WoW neu starten.' or 'Cursive Character Pack is not loaded. Check the AddOns list and restart WoW.'
 end
 return de and 'Nicht verfügbar: Cursive Character Pack von CurseForge herunterladen, neben Cursive installieren und WoW neu starten.' or 'Not available: download Cursive Character Pack from CurseForge, install it alongside Cursive and restart WoW.'
end
