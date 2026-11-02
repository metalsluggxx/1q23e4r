local _,addon=...
local C=addon.Client
if C.isForever then return end

-- Client-specific seeds, not a damage model. Unknown personal debuffs remain
-- visible in Extras. Localized names and learned ranks come from the client.
-- Reference facts cross-checked with WeakAuras' per-client collected spell
-- templates; application IDs are intentionally separate from cast IDs.
local function s(key,ids,name,casts)
    return {key=key,ids=type(ids)=="table" and ids or {ids},fallback=name,
        castIDs=type(casts)=="table" and casts or nil,castable=casts~=false}
end
local era={
 WARLOCK={
  s("corruption",{172,6222,6223,7648,11671,11672,25311},"Corruption"),
  s("agony",{980,1014,6217,11711,11712,11713},"Curse of Agony"),
  s("immolate",{348,707,1094,2941,11665,11667,11668,25309},"Immolate"),
  s("siphon_life",{18265,18879,18880,18881},"Siphon Life"),
  s("doom",603,"Curse of Doom"),
  s("curse_weakness",{702,1108,6205,7646,11707,11708},"Curse of Weakness"),
  s("curse_tongues",{1714,11719},"Curse of Tongues"),
  s("curse_recklessness",{704,7658,7659,11717},"Curse of Recklessness"),
  s("curse_exhaustion",18223,"Curse of Exhaustion"),
  s("curse_elements",{1490,11721,11722},"Curse of the Elements"),
  s("curse_shadow",{17862,17937},"Curse of Shadow"),
  s("fear",{5782,6213,6215},"Fear"),s("banish",{710,18647},"Banish"),
  s("howl_of_terror",{5484,17928},"Howl of Terror"),s("death_coil",{6789,17925,17926},"Death Coil"),
  s("drain_life",689,"Drain Life"),s("drain_soul",1120,"Drain Soul"),
 },
 DRUID={s("moonfire",8921,"Moonfire"),s("insect_swarm",5570,"Insect Swarm"),s("rake",1822,"Rake"),s("rip",1079,"Rip"),
  s("faerie_fire",{770,16857},"Faerie Fire"),s("entangling_roots",339,"Entangling Roots"),s("hibernate",2637,"Hibernate"),s("bash",5211,"Bash")},
 PRIEST={s("shadow_word_pain",589,"Shadow Word: Pain"),s("devouring_plague",2944,"Devouring Plague"),s("holy_fire",14914,"Holy Fire"),
  s("mind_flay",15407,"Mind Flay"),s("vampiric_embrace",15286,"Vampiric Embrace"),s("psychic_scream",8122,"Psychic Scream"),s("shackle_undead",9484,"Shackle Undead")},
 HUNTER={s("serpent_sting",1978,"Serpent Sting"),s("hunters_mark",1130,"Hunter's Mark"),s("viper_sting",3034,"Viper Sting"),
  s("scorpid_sting",3043,"Scorpid Sting"),s("concussive_shot",5116,"Concussive Shot"),s("wing_clip",2974,"Wing Clip"),
  s("immolation_trap",{13797,14298,14299,14300,14301},"Immolation Trap",false),s("explosive_trap",{13812,14314,14315},"Explosive Trap",false),
  s("freezing_trap",{3355,14308,14309},"Freezing Trap",false)},
 ROGUE={s("rupture",1943,"Rupture"),s("garrote",703,"Garrote"),s("deadly_poison",{2818,2819,11353,11354,25349},"Deadly Poison",false),
  s("crippling_poison",{3409,11201},"Crippling Poison",false),s("wound_poison",{13218,13222,13223,13224},"Wound Poison",false),
  s("expose_armor",8647,"Expose Armor"),s("cheap_shot",1833,"Cheap Shot"),s("kidney_shot",408,"Kidney Shot"),
  s("sap",6770,"Sap"),s("blind",2094,"Blind"),s("gouge",1776,"Gouge"),s("hemorrhage",16511,"Hemorrhage")},
 MAGE={s("ignite",12654,"Ignite",false),s("fireball_burn",133,"Fireball"),s("pyroblast_burn",11366,"Pyroblast"),
  s("polymorph",118,"Polymorph"),s("frost_nova",122,"Frost Nova"),s("frostbolt",116,"Frostbolt"),s("cone_of_cold",120,"Cone of Cold")},
 WARRIOR={s("rend",772,"Rend"),s("deep_wounds",12721,"Deep Wounds",false),s("demoralizing_shout",1160,"Demoralizing Shout"),
  s("thunder_clap",6343,"Thunder Clap"),s("sunder_armor",7386,"Sunder Armor"),s("hamstring",1715,"Hamstring"),
  s("mortal_strike",12294,"Mortal Strike"),s("disarm",676,"Disarm")},
 SHAMAN={s("flame_shock",8050,"Flame Shock"),s("frost_shock",8056,"Frost Shock"),s("earth_shock",8042,"Earth Shock"),
  s("earthbind",3600,"Earthbind",false),s("frostbrand",8034,"Frostbrand Attack",false),s("stormstrike",17364,"Stormstrike")},
 PALADIN={s("judgement_crusader",{21183,20188,20300,20301,20302,20303},"Judgement of the Crusader",false),
  s("judgement_wisdom",{20186,20354,20355},"Judgement of Wisdom",false),s("judgement_light",{20185,20344,20345,20346},"Judgement of Light",false),
  s("hammer_of_justice",853,"Hammer of Justice"),s("repentance",20066,"Repentance"),s("turn_undead",2878,"Turn Undead")},
}
C.catalog=era
C.defaultSlots={
 WARLOCK={"corruption","agony","immolate","siphon_life"},DRUID={"moonfire","insect_swarm","rake","rip"},
 PRIEST={"shadow_word_pain","devouring_plague","holy_fire"},HUNTER={"serpent_sting","hunters_mark"},
 ROGUE={"rupture","garrote","deadly_poison"},MAGE={"ignite","fireball_burn","pyroblast_burn"},
 WARRIOR={"rend","deep_wounds","sunder_armor"},SHAMAN={"flame_shock","frost_shock"},
 PALADIN={"judgement_crusader","judgement_wisdom","judgement_light"},
}
-- Fixed 35%/20% hints remain available in every edition. Automatic execution
-- rules are enabled only where this foundation has a validated baseline;
-- modern specialization/talent overrides need a separate client profile.
C.executeProfiles={}
if C.edition=="Era" then
 C.executeProfiles={WARRIOR={threshold=20,inclusive=true,spells={5308,20658,20660,20661,20662},name="Execute"},
  PALADIN={threshold=20,inclusive=true,spells={24275,24274,24239},name="Hammer of Wrath"}}
end
if C.edition=="MoP" then
 C.catalog.WARLOCK={s("corruption",{146739,172},"Corruption",{172}),s("agony",980,"Agony"),s("immolate",348,"Immolate"),
  s("unstable_affliction",30108,"Unstable Affliction"),s("doom",603,"Doom"),s("seed",27243,"Seed of Corruption"),s("haunt",48181,"Haunt"),
  s("curse_enfeeblement",109466,"Curse of Enfeeblement"),s("curse_elements",1490,"Curse of the Elements"),s("curse_exhaustion",18223,"Curse of Exhaustion"),
  s("fear",{118699,5782},"Fear",{5782}),s("banish",710,"Banish"),s("howl_of_terror",5484,"Howl of Terror"),s("mortal_coil",6789,"Mortal Coil"),
  s("shadowfury",30283,"Shadowfury"),s("drain_life",689,"Drain Life"),s("drain_soul",1120,"Drain Soul"),s("malefic_grasp",103103,"Malefic Grasp")}
 C.catalog.DRUID={s("moonfire",8921,"Moonfire"),s("sunfire",93402,"Sunfire"),s("rake",1822,"Rake"),s("rip",1079,"Rip"),s("lacerate",33745,"Lacerate"),
  s("thrash",{77758,106830},"Thrash"),s("faerie_fire",770,"Faerie Fire"),s("entangling_roots",339,"Entangling Roots"),s("hibernate",2637,"Hibernate")}
 C.catalog.PRIEST={s("shadow_word_pain",589,"Shadow Word: Pain"),s("vampiric_touch",34914,"Vampiric Touch"),s("devouring_plague",2944,"Devouring Plague"),
  s("holy_fire",14914,"Holy Fire"),s("mind_flay",{15407,129197},"Mind Flay"),s("psychic_scream",8122,"Psychic Scream"),s("silence",15487,"Silence")}
 C.catalog.HUNTER={s("serpent_sting",118253,"Serpent Sting",{1978}),s("black_arrow",3674,"Black Arrow"),s("explosive_shot",53301,"Explosive Shot"),
  s("murder_of_crows",131894,"A Murder of Crows"),s("hunters_mark",1130,"Hunter's Mark"),s("concussive_shot",5116,"Concussive Shot"),s("wyvern_sting",19386,"Wyvern Sting")}
 C.catalog.ROGUE={s("rupture",1943,"Rupture"),s("garrote",703,"Garrote"),s("deadly_poison",2818,"Deadly Poison",false),
  s("hemorrhage",89775,"Hemorrhage",{16511}),s("crimson_tempest",122233,"Crimson Tempest",{121411}),s("vendetta",79140,"Vendetta"),
  s("revealing_strike",84617,"Revealing Strike"),s("kidney_shot",408,"Kidney Shot"),s("blind",2094,"Blind")}
 C.catalog.MAGE={s("ignite",{413841,12654},"Ignite",false),s("living_bomb",44457,"Living Bomb"),s("nether_tempest",114923,"Nether Tempest"),
  s("frost_bomb",112948,"Frost Bomb"),s("pyroblast_burn",11366,"Pyroblast"),s("combustion",83853,"Combustion",{11129}),
  s("polymorph",118,"Polymorph"),s("frost_nova",122,"Frost Nova"),s("slow",31589,"Slow")}
 C.catalog.WARRIOR={s("deep_wounds",115767,"Deep Wounds",false),s("bloodbath",113344,"Bloodbath",false),s("colossus_smash",86346,"Colossus Smash"),
  s("demoralizing_shout",1160,"Demoralizing Shout"),s("hamstring",1715,"Hamstring"),s("weakened_armor",113746,"Weakened Armor",false)}
 C.catalog.PALADIN={s("censure",31803,"Censure",false),s("execution_sentence",114916,"Execution Sentence",{114157}),
  s("hammer_of_justice",853,"Hammer of Justice"),s("fist_of_justice",105593,"Fist of Justice"),s("blinding_light",105421,"Blinding Light")}
 C.catalog.DEATHKNIGHT={s("blood_plague",55078,"Blood Plague",false),s("frost_fever",55095,"Frost Fever",false),
  s("soul_reaper",{114866,130735,130736},"Soul Reaper"),s("chains_of_ice",45524,"Chains of Ice"),s("necrotic_strike",73975,"Necrotic Strike")}
 C.catalog.MONK={s("breath_of_fire",123725,"Breath of Fire",{115181}),s("dizzying_haze",116330,"Dizzying Haze",false),
  s("disable",116095,"Disable"),s("paralysis",115078,"Paralysis"),s("leg_sweep",119381,"Leg Sweep"),s("touch_of_karma",122470,"Touch of Karma")}
 C.defaultSlots.WARLOCK={"corruption","agony","immolate","unstable_affliction"}
 C.defaultSlots.DRUID={"moonfire","sunfire","rake","rip"}
 C.defaultSlots.PRIEST={"shadow_word_pain","vampiric_touch","devouring_plague"}
 C.defaultSlots.HUNTER={"serpent_sting","black_arrow","explosive_shot"}
 C.defaultSlots.MAGE={"ignite","living_bomb","nether_tempest","frost_bomb"}
 C.defaultSlots.WARRIOR={"deep_wounds","colossus_smash","bloodbath"}
 C.defaultSlots.PALADIN={"censure","execution_sentence"}
 C.defaultSlots.DEATHKNIGHT={"blood_plague","frost_fever","soul_reaper"}
 C.defaultSlots.MONK={"breath_of_fire","disable"}
end
if C.edition=="Retail" then
 C.catalog={
 WARLOCK={s("corruption",{146739,172},"Corruption",{172}),s("agony",980,"Agony"),s("immolate",{157736,348},"Immolate",{348}),
  s("unstable_affliction",{316099,30108},"Unstable Affliction",{30108}),s("wither",445474,"Wither",{445468}),
  s("seed",27243,"Seed of Corruption"),s("haunt",48181,"Haunt"),s("soul_rot",386997,"Soul Rot"),
  s("vile_taint",386931,"Vile Taint",false),s("phantom_singularity",205179,"Phantom Singularity"),
  s("curse_weakness",702,"Curse of Weakness"),s("curse_tongues",1714,"Curse of Tongues"),s("curse_exhaustion",334275,"Curse of Exhaustion"),
  s("fear",118699,"Fear",{5782}),s("banish",710,"Banish"),s("mortal_coil",6789,"Mortal Coil"),s("havoc",80240,"Havoc")},
 DRUID={s("moonfire",{164812,155625},"Moonfire",{8921}),s("sunfire",164815,"Sunfire",{93402}),s("rake",155722,"Rake",{1822}),s("rip",1079,"Rip"),
  s("stellar_flare",202347,"Stellar Flare"),s("thrash",{192090,405233},"Thrash",{77758,106830}),s("entangling_roots",339,"Entangling Roots")},
 PRIEST={s("shadow_word_pain",589,"Shadow Word: Pain"),s("vampiric_touch",34914,"Vampiric Touch"),s("devouring_plague",335467,"Devouring Plague"),
  s("holy_fire",14914,"Holy Fire"),s("mind_flay",{15407,391403},"Mind Flay"),s("psychic_scream",8122,"Psychic Scream")},
 HUNTER={s("serpent_sting",{271788,259491},"Serpent Sting",false),s("barbed_shot",217200,"Barbed Shot"),s("black_arrow",430703,"Black Arrow"),
  s("hunters_mark",257284,"Hunter's Mark"),s("wildfire_bomb",269747,"Wildfire Bomb",false),s("freezing_trap",3355,"Freezing Trap",false)},
 ROGUE={s("rupture",1943,"Rupture"),s("garrote",703,"Garrote"),s("deadly_poison",2818,"Deadly Poison",false),
  s("crimson_tempest",121411,"Crimson Tempest"),s("deathmark",360194,"Deathmark"),s("kingsbane",385627,"Kingsbane"),s("kidney_shot",408,"Kidney Shot"),s("blind",2094,"Blind")},
 MAGE={s("ignite",12654,"Ignite",false),s("living_bomb",{217694,438671},"Living Bomb",false),s("touch_of_magi",210824,"Touch of the Magi",{321507}),
  s("winters_chill",228358,"Winter's Chill",false),s("polymorph",118,"Polymorph"),s("frost_nova",122,"Frost Nova"),s("slow",31589,"Slow")},
 WARRIOR={s("rend",388539,"Rend",{772}),s("deep_wounds",{262115,115767},"Deep Wounds",false),s("colossus_smash",208086,"Colossus Smash",{167105}),
  s("thunderous_roar",397364,"Thunderous Roar",{384318}),s("demoralizing_shout",1160,"Demoralizing Shout"),s("hamstring",1715,"Hamstring")},
 SHAMAN={s("flame_shock",188389,"Flame Shock"),s("frost_shock",196840,"Frost Shock"),s("lashing_flames",334168,"Lashing Flames",false),
  s("earthbind",116947,"Earthbind",false),s("lightning_rod",197209,"Lightning Rod",false)},
 PALADIN={s("expurgation",383346,"Expurgation",false),s("execution_sentence",343527,"Execution Sentence"),s("judgment",197277,"Judgment",{20271}),
  s("hammer_of_justice",853,"Hammer of Justice"),s("blinding_light",105421,"Blinding Light")},
 DEATHKNIGHT={s("blood_plague",55078,"Blood Plague",false),s("frost_fever",55095,"Frost Fever",false),s("virulent_plague",191587,"Virulent Plague",false),
  s("festering_wound",194310,"Festering Wound",false),s("soul_reaper",343294,"Soul Reaper"),s("chains_of_ice",45524,"Chains of Ice")},
 MONK={s("breath_of_fire",123725,"Breath of Fire",{115181}),s("mystic_touch",113746,"Mystic Touch",false),s("keg_smash",121253,"Keg Smash"),
  s("paralysis",115078,"Paralysis"),s("leg_sweep",119381,"Leg Sweep"),s("touch_of_karma",122470,"Touch of Karma")},
 DEMONHUNTER={s("sigil_of_flame",204598,"Sigil of Flame",false),s("fiery_brand",207771,"Fiery Brand",{204021}),s("chaos_brand",1490,"Chaos Brand",false),
  s("burning_wound",391191,"Burning Wound",false),s("frailty",247456,"Frailty",false),s("sigil_of_misery",207685,"Sigil of Misery",false)},
 EVOKER={s("fire_breath",357209,"Fire Breath",false),s("disintegrate",356995,"Disintegrate"),s("shattering_star",370452,"Shattering Star"),
  s("sleep_walk",360806,"Sleep Walk"),s("landslide",355689,"Landslide",false)},
 }
 C.defaultSlots={WARLOCK={"corruption","agony","unstable_affliction","immolate"},DRUID={"moonfire","sunfire","rake","rip"},
  PRIEST={"shadow_word_pain","vampiric_touch","devouring_plague"},HUNTER={"serpent_sting","barbed_shot","black_arrow"},
  ROGUE={"rupture","garrote","deadly_poison"},MAGE={"ignite","touch_of_magi","winters_chill"},WARRIOR={"rend","deep_wounds","colossus_smash"},
  SHAMAN={"flame_shock","frost_shock"},PALADIN={"expurgation","execution_sentence","judgment"},
  DEATHKNIGHT={"blood_plague","frost_fever","virulent_plague","festering_wound"},MONK={"breath_of_fire","mystic_touch"},
  DEMONHUNTER={"sigil_of_flame","fiery_brand","chaos_brand"},EVOKER={"fire_breath","disintegrate","shattering_star"}}
end
C.supportKeys={curse_weakness=true,curse_tongues=true,curse_recklessness=true,curse_exhaustion=true,curse_elements=true,curse_shadow=true,curse_enfeeblement=true}
C.raidCurses={} -- watcher model awaits separate validation for each client
C.rankCandidates={}
