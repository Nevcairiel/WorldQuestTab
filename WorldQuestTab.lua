﻿--
-- Deprecated and deleted come 8.1
--
--	id, mapX, mapY, mapF, timeString, timeStringShort, color, minutes, zoneId, continentId, rewardId, rewardQuality, rewardTexture, numItems, rewardType, ringcolor, subRewardType
--
-- New info structure
--
-- factionId			[number, nullable] factionId, null if no faction
-- expantionLevel	[number] expansion is belongs to
-- isCriteria			[boolean] is part of currently selected amissary
-- passedFilter		[boolean] passed current filters
-- type					[number] type of quest
-- questId				[number] questId
-- rarity					[number] quest rarity; normal, rare, epic
-- numObjetives		[number] number of objectives
-- title					[string] quest title
-- faction				[string] faction name
-- isElite				[boolean] is elite quest
-- time					[table] time related values
-- 	short				[string] short time string (6H)
-- 	full				[string] long time string (6 Hours)
--		minutes			[number] minutes remaining
--		color				[color] color of time string
-- zoneInfo			[table] zone related values
--		mapType		[Enum.UIMapType] map type
--		mapID			[number] mapID, uses capital 'ID' because Blizzard
-- 	name			[string] zone name
--		mapX			[number] x pin position
--		mapY			[number] y pin position
--		parentMapID	[number] parentmapID, uses capital 'ID' because Blizzard
-- reward				[number] reward related values
--		type				[number] reward type, check 'WQT_REWARDTYPE_...' values below
--		texture			[number/string] texture of the reward. can be string for things like gold or unknown reward
--		amount			[amount] amount of items, gold, rep, or item level
--		id					[number, nullable] itemId for reward. null if not an item
--		quality			[number] item quality; common, rare, epic, etc
--		upgradable	[boolean, nullable] true if item has a chance to upgrade (e.g. ilvl 285+)

local addonName, addon = ...

local WQT = LibStub("AceAddon-3.0"):NewAddon("WorldQuestTab");
local ADD = LibStub("AddonDropDown-1.0");

local _L = addon.L

local _debug = false;

local _TomTomLoaded = IsAddOnLoaded("TomTom");
local _CIMILoaded = IsAddOnLoaded("CanIMogIt");

WQT_TAB_NORMAL = _L["QUESTLOG"];
WQT_TAB_WORLD = _L["WORLDQUEST"];
WQT_GROUP_INFO = _L["GROUP_SEARCH_INFO"];

local WQT_REWARDTYPE_MISSING = 100;
local WQT_REWARDTYPE_ARMOR = 1;
local WQT_REWARDTYPE_RELIC = 2;
local WQT_REWARDTYPE_ARTIFACT = 3;
local WQT_REWARDTYPE_ITEM = 4;
local WQT_REWARDTYPE_GOLD = 5;
local WQT_REWARDTYPE_CURRENCY = 6;
local WQT_REWARDTYPE_HONOR = 7;
local WQT_REWARDTYPE_REP = 8;
local WQT_REWARDTYPE_XP = 9;
local WQT_REWARDTYPE_NONE = 10;

local WQT_EXPANSION_BFA = 7;
local WQT_EXPANSION_LEGION = 6;
local WQT_EXPANSION_WOD = 5;

local WQT_TYPE_BONUSOBJECTIVE = 99;

local WQT_WHITE_FONT_COLOR = CreateColor(0.8, 0.8, 0.8);
local WQT_ORANGE_FONT_COLOR = CreateColor(1, 0.6, 0);
local WQT_GREEN_FONT_COLOR = CreateColor(0, 0.75, 0);
local WQT_BLUE_FONT_COLOR = CreateColor(0.1, 0.68, 1);
local WQT_COLOR_ARTIFACT = CreateColor(0, 0.75, 0);
local WQT_COLOR_GOLD = CreateColor(0.85, 0.7, 0) ;
local WQT_COLOR_CURRENCY = CreateColor(0.6, 0.4, 0.1) ;
local WQT_COLOR_ITEM = CreateColor(0.85, 0.85, 0.85) ;
local WQT_COLOR_ARMOR =  CreateColor(0.85, 0.5, 0.95) ; -- CreateColor(0.7, 0.3, 0.9) ;
local WQT_COLOR_RELIC = CreateColor(0.3, 0.7, 1);
local WQT_COLOR_MISSING = CreateColor(0.7, 0.1, 0.1);
local WQT_COLOR_HONOR = CreateColor(0.8, 0.26, 0);
local WQT_COLOR_AREA_NAME = CreateColor(1.0, 0.9294, 0.7607);
local WQT_ARTIFACT_R, WQT_ARTIFACT_G, WQT_ARTIFACT_B = GetItemQualityColor(6);

local WQT_BOUNDYBOARD_OVERLAYID = 3;

local WQT_LISTITTEM_HEIGHT = 32;
local WQT_REFRESH_DEFAULT = 60;

local WQT_QUESTIONMARK = "Interface/ICONS/INV_Misc_QuestionMark";
local WQT_EXPERIENCE = "Interface/ICONS/XP_ICON";
local WQT_HONOR = "Interface/ICONS/Achievement_LegionPVPTier4";
local WQT_FACTIONUNKNOWN = "Interface/addons/WorldQuestTab/Images/FactionUnknown";

local WQT_ARGUS_COSMIC_BUTTONS = {KrokuunButton, MacAreeButton, AntoranWastesButton, BrokenIslesArgusButton}

local WQT_TYPEFLAG_LABELS = {
		[2] = {["Default"] = _L["TYPE_DEFAULT"], ["Elite"] = _L["TYPE_ELITE"], ["PvP"] = _L["TYPE_PVP"], ["Petbattle"] = _L["TYPE_PETBATTLE"], ["Dungeon"] = _L["TYPE_DUNGEON"]
			, ["Raid"] = _L["TYPE_RAID"], ["Profession"] = _L["TYPE_PROFESSION"], ["Invasion"] = _L["TYPE_INVASION"]}
		,[3] = {["Item"] = _L["REWARD_ITEM"], ["Armor"] = WORLD_QUEST_REWARD_FILTERS_EQUIPMENT, ["Gold"] = WORLD_QUEST_REWARD_FILTERS_GOLD, ["Currency"] = WORLD_QUEST_REWARD_FILTERS_RESOURCES, ["Artifact"] = ITEM_QUALITY6_DESC
			, ["Relic"] = _L["REWARD_RELIC"], ["None"] = _L["REWARD_NONE"], ["Experience"] = _L["REWARD_EXPERIENCE"], ["Honor"] = _L["REWARD_HONOR"], ["Reputation"] = REPUTATION}
	};

local WQT_FILTER_FUNCTIONS = {
		[2] = { -- Types
			function(quest, flags) return (flags["PvP"] and quest.type == LE_QUEST_TAG_TYPE_PVP); end 
			,function(quest, flags) return (flags["Petbattle"] and quest.type == LE_QUEST_TAG_TYPE_PET_BATTLE); end 
			,function(quest, flags) return (flags["Dungeon"] and quest.type == LE_QUEST_TAG_TYPE_DUNGEON); end 
			,function(quest, flags) return (flags["Raid"] and quest.type == LE_QUEST_TAG_TYPE_RAID); end 
			,function(quest, flags) return (flags["Profession"] and quest.type == LE_QUEST_TAG_TYPE_PROFESSION); end 
			,function(quest, flags) return (flags["Invasion"] and quest.type == LE_QUEST_TAG_TYPE_INVASION); end 
			,function(quest, flags) return (flags["Elite"] and (quest.type ~= LE_QUEST_TAG_TYPE_DUNGEON and quest.type ~= LE_QUEST_TAG_TYPE_RAID and quest.isElite)); end 
			,function(quest, flags) return (flags["Default"] and (quest.type ~= LE_QUEST_TAG_TYPE_PVP and quest.type ~= LE_QUEST_TAG_TYPE_PET_BATTLE and quest.type ~= LE_QUEST_TAG_TYPE_DUNGEON and quest.type ~= WQT_TYPE_BONUSOBJECTIVE  and quest.type ~= LE_QUEST_TAG_TYPE_PROFESSION and quest.type ~= LE_QUEST_TAG_TYPE_RAID and quest.type ~= LE_QUEST_TAG_TYPE_INVASION and not quest.isElite)); end 
			}
		,[3] = { -- Reward filters
			function(quest, flags) return (flags["Armor"] and quest.reward.type == WQT_REWARDTYPE_ARMOR); end 
			,function(quest, flags) return (flags["Relic"] and quest.reward.type == WQT_REWARDTYPE_RELIC); end 
			,function(quest, flags) return (flags["Item"] and quest.reward.type == WQT_REWARDTYPE_ITEM); end 
			,function(quest, flags) return (flags["Artifact"] and quest.reward.type == WQT_REWARDTYPE_ARTIFACT); end 
			,function(quest, flags) return (flags["Honor"] and (quest.reward.type == WQT_REWARDTYPE_HONOR or quest.reward.subType == WQT_REWARDTYPE_HONOR)); end 
			,function(quest, flags) return (flags["Gold"] and (quest.reward.type == WQT_REWARDTYPE_GOLD or quest.reward.subType == WQT_REWARDTYPE_GOLD) ); end 
			,function(quest, flags) return (flags["Currency"] and (quest.reward.type == WQT_REWARDTYPE_CURRENCY or quest.reward.subType == WQT_REWARDTYPE_CURRENCY)); end 
			,function(quest, flags) return (flags["Experience"] and quest.reward.type == WQT_REWARDTYPE_XP); end 
			,function(quest, flags) return (flags["Reputation"] and quest.reward.type == WQT_REWARDTYPE_REP or quest.reward.subType == WQT_REWARDTYPE_REP); end
			,function(quest, flags) return (flags["None"] and quest.reward.type == WQT_REWARDTYPE_NONE); end
			}
	};

local WQT_ZONE_EXPANSIONS = {
	[875] = WQT_EXPANSION_BFA -- Zandalar
	,[864] = WQT_EXPANSION_BFA -- Vol'dun
	,[863] = WQT_EXPANSION_BFA -- Nazmir
	,[862] = WQT_EXPANSION_BFA -- Zuldazar
	,[1165] = WQT_EXPANSION_BFA -- Dazar'alor
	,[876] = WQT_EXPANSION_BFA -- Kul Tiras
	,[942] = WQT_EXPANSION_BFA -- Stromsong Valley
	,[896] = WQT_EXPANSION_BFA -- Drustvar
	,[895] = WQT_EXPANSION_BFA -- Tiragarde Sound
	,[1161] = WQT_EXPANSION_BFA -- Boralus

	,[619] = WQT_EXPANSION_LEGION -- Broken Isles
	,[630] = WQT_EXPANSION_LEGION -- Azsuna
	,[680] = WQT_EXPANSION_LEGION -- Suramar
	,[634] = WQT_EXPANSION_LEGION -- Stormheim
	,[650] = WQT_EXPANSION_LEGION -- Highmountain
	,[641] = WQT_EXPANSION_LEGION -- Val'sharah
	,[790] = WQT_EXPANSION_LEGION -- Eye of Azshara
	,[646] = WQT_EXPANSION_LEGION -- Broken Shore
	,[627] = WQT_EXPANSION_LEGION -- Dalaran
	,[830] = WQT_EXPANSION_LEGION -- Krokuun
	,[885] = WQT_EXPANSION_LEGION -- Antoran Wastes
	,[882] = WQT_EXPANSION_LEGION -- Mac'Aree
	,[905] = WQT_EXPANSION_LEGION -- Argus
}
	
local WQT_ZANDALAR = {
	[864] =  {["x"] = 0.39, ["y"] = 0.32} -- Vol'dun
	,[863] = {["x"] = 0.57, ["y"] = 0.28} -- Nazmir
	,[862] = {["x"] = 0.55, ["y"] = 0.61} -- Zuldazar
	,[1165] = {["x"] = 0.55, ["y"] = 0.61} -- Dazar'alor
}
local WQT_KULTIRAS = {
	[942] =  {["x"] = 0.55, ["y"] = 0.25} -- Stromsong Valley
	,[896] = {["x"] = 0.36, ["y"] = 0.67} -- Drustvar
	,[895] = {["x"] = 0.56, ["y"] = 0.54} -- Tiragarde Sound
	,[1161] = {["x"] = 0.56, ["y"] = 0.54} -- Boralus
}
local WQT_LEGION = {
	[630] =  {["x"] = 0.33, ["y"] = 0.58} -- Azsuna
	,[680] = {["x"] = 0.46, ["y"] = 0.45} -- Suramar
	,[634] = {["x"] = 0.60, ["y"] = 0.33} -- Stormheim
	,[650] = {["x"] = 0.46, ["y"] = 0.23} -- Highmountain
	,[641] = {["x"] = 0.34, ["y"] = 0.33} -- Val'sharah
	,[790] = {["x"] = 0.46, ["y"] = 0.84} -- Eye of Azshara
	,[646] = {["x"] = 0.54, ["y"] = 0.68} -- Broken Shore
	,[627] = {["x"] = 0.45, ["y"] = 0.64} -- Dalaran
	
	,[830]	= {["x"] = 0.86, ["y"] = 0.15} -- Krokuun
	,[885]	= {["x"] = 0.86, ["y"] = 0.15} -- Antoran Wastes
	,[882]	= {["x"] = 0.86, ["y"] = 0.15} -- Mac'Aree
}
	
local WQT_ZONE_MAPCOORDS = {
		[875]	= WQT_ZANDALAR -- Zandalar
		,[1011]	= WQT_ZANDALAR -- Zandalar flightmap
		,[876]	= WQT_KULTIRAS -- Kul Tiras
		,[1014]	= WQT_KULTIRAS -- Kul Tiras flightmap

		,[619] 	= WQT_LEGION -- Legion
		,[993] 	= WQT_LEGION -- Legion flightmap	
		,[905] 	= WQT_LEGION -- Legion Argus
		
		,[12] 	= { --Kalimdor
			[81] 	= {["x"] = 0.42, ["y"] = 0.82} -- Silithus
			,[64]	= {["x"] = 0.5, ["y"] = 0.72} -- Thousand Needles
			,[249]	= {["x"] = 0.47, ["y"] = 0.91} -- Uldum
			,[71]	= {["x"] = 0.55, ["y"] = 0.84} -- Tanaris
			,[78]	= {["x"] = 0.5, ["y"] = 0.81} -- Ungoro
			,[69]	= {["x"] = 0.43, ["y"] = 0.7} -- Feralas
			,[70]	= {["x"] = 0.55, ["y"] = 0.67} -- Dustwallow
			,[199]	= {["x"] = 0.51, ["y"] = 0.67} -- S Barrens
			,[7]	= {["x"] = 0.47, ["y"] = 0.6} -- Mulgore
			,[66]	= {["x"] = 0.41, ["y"] = 0.57} -- Desolace
			,[65]	= {["x"] = 0.43, ["y"] = 0.46} -- Stonetalon
			,[10]	= {["x"] = 0.52, ["y"] = 0.5} -- N Barrens
			,[1]	= {["x"] = 0.58, ["y"] = 0.5} -- Durotar
			,[63]	= {["x"] = 0.49, ["y"] = 0.41} -- Ashenvale
			,[62]	= {["x"] = 0.46, ["y"] = 0.23} -- Dakshore
			,[76]	= {["x"] = 0.59, ["y"] = 0.37} -- Azshara
			,[198]	= {["x"] = 0.54, ["y"] = 0.32} -- Hyjal
			,[77]	= {["x"] = 0.49, ["y"] = 0.25} -- Felwood
			,[80]	= {["x"] = 0.53, ["y"] = 0.19} -- Moonglade
			,[83]	= {["x"] = 0.58, ["y"] = 0.23} -- Winterspring
			,[57]	= {["x"] = 0.42, ["y"] = 0.1} -- Teldrassil
			,[97]	= {["x"] = 0.33, ["y"] = 0.27} -- Azuremyst
			,[106]	= {["x"] = 0.3, ["y"] = 0.18} -- Bloodmyst
		}
		
		,[13]	= { -- Eastern Kingdoms
			[210]	= {["x"] = 0.47, ["y"] = 0.87} -- Cape of STV
			,[50]	= {["x"] = 0.47, ["y"] = 0.87} -- N STV
			,[17]	= {["x"] = 0.54, ["y"] = 0.89} -- Blasted Lands
			,[51]	= {["x"] = 0.54, ["y"] = 0.78} -- Swamp of Sorrow
			,[42]	= {["x"] = 0.49, ["y"] = 0.79} -- Deadwind
			,[47]	= {["x"] = 0.45, ["y"] = 0.8} -- Duskwood
			,[52]	= {["x"] = 0.4, ["y"] = 0.79} -- Westfall
			,[37]	= {["x"] = 0.47, ["y"] = 0.75} -- Elwynn
			,[49]	= {["x"] = 0.51, ["y"] = 0.75} -- Redridge
			,[36]	= {["x"] = 0.49, ["y"] = 0.7} -- Burning Steppes
			,[32]	= {["x"] = 0.47, ["y"] = 0.65} -- Searing Gorge
			,[15]	= {["x"] = 0.52, ["y"] = 0.65} -- Badlands
			,[27]	= {["x"] = 0.44, ["y"] = 0.61} -- Dun Morogh
			,[48]	= {["x"] = 0.52, ["y"] = 0.6} -- Loch Modan
			,[241]	= {["x"] = 0.56, ["y"] = 0.55} -- Twilight Highlands
			,[56]	= {["x"] = 0.5, ["y"] = 0.53} -- Wetlands
			,[14]	= {["x"] = 0.51, ["y"] = 0.46} -- Arathi Highlands
			,[26]	= {["x"] = 0.57, ["y"] = 0.4} -- Hinterlands
			,[25]	= {["x"] = 0.46, ["y"] = 0.4} -- Hillsbrad
			,[217]	= {["x"] = 0.4, ["y"] = 0.48} -- Ruins of Gilneas
			,[21]	= {["x"] = 0.41, ["y"] = 0.39} -- Silverpine
			,[18]	= {["x"] = 0.39, ["y"] = 0.32} -- Tirisfall
			,[22]	= {["x"] = 0.49, ["y"] = 0.31} -- W Plaugelands
			,[23]	= {["x"] = 0.54, ["y"] = 0.32} -- E Plaguelands
			,[95]	= {["x"] = 0.56, ["y"] = 0.23} -- Ghostlands
			,[94]	= {["x"] = 0.54, ["y"] = 0.18} -- Eversong
			,[122]	= {["x"] = 0.55, ["y"] = 0.05} -- Quel'Danas
		}
		
		,[101]	= { -- Outland
			[104]	= {["x"] = 0.74, ["y"] = 0.8} -- Shadowmoon Valley
			,[108]	= {["x"] = 0.45, ["y"] = 0.77} -- Terrokar
			,[107]	= {["x"] = 0.3, ["y"] = 0.65} -- Nagrand
			,[100]	= {["x"] = 0.52, ["y"] = 0.51} -- Hellfire
			,[102]	= {["x"] = 0.33, ["y"] = 0.47} -- Zangarmarsh
			,[105]	= {["x"] = 0.36, ["y"] = 0.23} -- Blade's Edge
			,[109]	= {["x"] = 0.57, ["y"] = 0.2} -- Netherstorm
		}
		
		,[113]	= { -- Northrend
			[114]	= {["x"] = 0.22, ["y"] = 0.59} -- Borean Tundra
			,[119]	= {["x"] = 0.25, ["y"] = 0.41} -- Sholazar Basin
			,[118]	= {["x"] = 0.41, ["y"] = 0.26} -- Icecrown
			,[127]	= {["x"] = 0.47, ["y"] = 0.55} -- Crystalsong
			,[120]	= {["x"] = 0.61, ["y"] = 0.21} -- Stormpeaks
			,[121]	= {["x"] = 0.77, ["y"] = 0.32} -- Zul'Drak
			,[116]	= {["x"] = 0.71, ["y"] = 0.53} -- Grizzly Hillsbrad
			,[113]	= {["x"] = 0.78, ["y"] = 0.74} -- Howling Fjord
		}
		
		,[424]	= { -- Pandaria
			[554]	= {["x"] = 0.9, ["y"] = 0.68} -- Timeless Isles
			,[371]	= {["x"] = 0.67, ["y"] = 0.52} -- Jade Forest
			,[418]	= {["x"] = 0.53, ["y"] = 0.75} -- Karasang
			,[376]	= {["x"] = 0.51, ["y"] = 0.65} -- Four Winds
			,[422]	= {["x"] = 0.35, ["y"] = 0.62} -- Dread Waste
			,[390]	= {["x"] = 0.5, ["y"] = 0.52} -- Eternal Blossom
			,[379]	= {["x"] = 0.45, ["y"] = 0.35} -- Kun-lai Summit
			,[507]	= {["x"] = 0.48, ["y"] = 0.05} -- Isle of Giants
			,[388]	= {["x"] = 0.32, ["y"] = 0.45} -- Townlong Steppes
			,[504]	= {["x"] = 0.2, ["y"] = 0.11} -- Isle of Thunder
		}
		
		,[572]	= { -- Draenor
			[550]	= {["x"] = 0.24, ["y"] = 0.49} -- Nagrand
			,[525]	= {["x"] = 0.34, ["y"] = 0.29} -- Frostridge
			,[543]	= {["x"] = 0.49, ["y"] = 0.21} -- Gorgrond
			,[535]	= {["x"] = 0.43, ["y"] = 0.56} -- Talador
			,[542]	= {["x"] = 0.46, ["y"] = 0.73} -- Spired of Arak
			,[539]	= {["x"] = 0.58, ["y"] = 0.67} -- Shadowmoon
			,[534]	= {["x"] = 0.58, ["y"] = 0.47} -- Tanaan Jungle
			,[558]	= {["x"] = 0.73, ["y"] = 0.43} -- Ashran
		}
		
		,[947]		= {
			[619]	= {["x"] = 0.6, ["y"] = 0.41}
			,[12]	= {["x"] = 0.19, ["y"] = 0.5}
			,[13]	= {["x"] = 0.88, ["y"] = 0.56}
			,[113]	= {["x"] = 0.49, ["y"] = 0.13}
			,[424]	= {["x"] = 0.46, ["y"] = 0.92}
			,[875]	= {["x"] = 0.46, ["y"] = 0.92}
			,[876]	= {["x"] = 0.46, ["y"] = 0.92}
		} -- All of Azeroth
	}

local WQT_SORT_OPTIONS = {[1] = _L["TIME"], [2] = _L["FACTION"], [3] = _L["TYPE"], [4] = _L["ZONE"], [5] = _L["NAME"], [6] = _L["REWARD"]}


local WQT_NO_FACTION_DATA = { ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/FactionNone", ["name"]=_L["NO_FACTION"] } -- No faction
local WQT_FACTION_DATA = {
	[1894] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_Warden" }
	,[1859] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_NightFallen" }
	,[1900] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_CourtofFarnodis" }
	,[1948] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_Valarjar" }
	,[1828] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_HightmountainTribes" }
	,[1883] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_DreamWeavers" }
	,[1090] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_KirinTor" }
	,[2045] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_Legionfall" } -- This isn't in until 7.3
	,[2165] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_ArmyoftheLight" }
	,[2170] = 	{ ["expansion"] = WQT_EXPANSION_LEGION ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_LegionCircle_Faction_ArgussianReach" }
	,[609] = 	{ ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction609" } -- Cenarion Circle - Call of the Scarab
	,[910] = 	{ ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction910" } -- Brood of Nozdormu - Call of the Scarab
	,[1515] = 	{ ["expansion"] = WQT_EXPANSION_WOD ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1515" } -- Dreanor Arakkoa Outcasts
	,[1681] = 	{ ["expansion"] = WQT_EXPANSION_WOD ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1681" } -- Dreanor Vol'jin's Spear
	,[1682] = 	{ ["expansion"] = WQT_EXPANSION_WOD ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1682" } -- Dreanor Wrynn's Vanguard
	,[1731] = 	{ ["expansion"] = WQT_EXPANSION_WOD ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1731" } -- Dreanor Council of Exarchs
	,[1445] = 	{ ["expansion"] = WQT_EXPANSION_WOD ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction1445" } -- Draenor Frostwolf Orcs
	,[67] = 		{ ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction67" } -- Horde
	,[469] = 	{ ["expansion"] = 0 ,["faction"] = nil ,["icon"] = "Interface/Addons/WorldQuestTab/Images/Faction469" } -- Alliance
	-- BfA                                                         
	,[2164] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = nil ,["icon"] = "Interface/ICONS/INV_Faction_Championsofazeroth_Round" } -- Champions of Azeroth
	,[2156] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = "Horde" ,["icon"] = 2058211 } -- Talanji's Expedition
	,[2103] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = "Horde" ,["icon"] = 2058217 } -- Zandalari Empire
	,[2158] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = "Horde" ,["icon"] = "Interface/ICONS/INV_Faction_Voldunai_Round" } -- Voldunai
	,[2157] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = "Horde" ,["icon"] = "Interface/ICONS/INV_Faction_HordeWarEffort_Round" } -- The Honorbound
	,[2163] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = nil ,["icon"] = 2058212 } -- Tortollan Seekers
	,[2162] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = "Alliance" ,["icon"] = "Interface/ICONS/INV_Faction_Stormswake_Round" } -- Storm's Wake
	,[2160] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = "Alliance" ,["icon"] = "Interface/ICONS/INV_Faction_ProudmooreAdmiralty_Round" } -- Proudmoore Admirality
	,[2161] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = "Alliance" ,["icon"] = "Interface/ICONS/INV_Faction_OrderofEmbers_Round" } -- Order of Embers
	,[2159] = 	{ ["expansion"] = WQT_EXPANSION_BFA ,["faction"] = "Alliance" ,["icon"] = "Interface/ICONS/INV_Faction_AllianceWarEffort_Round" } -- 7th Legion
}

for k, v in pairs(WQT_FACTION_DATA) do
	v.name = GetFactionInfoByID(k);
end
	
local WQT_DEFAULTS = {
	global = {	
		version = "";
		sortBy = 1;
		defaultTab = false;
		showTypeIcon = true;
		showFactionIcon = true;
		saveFilters = true;
		filterPoI = false;
		bigPoI = false;
		disablePoI = false;
		showPinReward = true;
		showPinRing = true;
		showPinTime = true;
		funQuests = true;
		emissaryOnly = false;
		useTomTom = true;
		preciseFilter = true;
		rewardAmountColors = true;
		filters = {
				[1] = {["name"] = _L["FACTION"]
				, ["flags"] = {[_L["OTHER_FACTION"]] = false, [_L["NO_FACTION"]] = false}}
				,[2] = {["name"] = _L["TYPE"]
						, ["flags"] = {["Default"] = false, ["Elite"] = false, ["PvP"] = false, ["Petbattle"] = false, ["Dungeon"] = false, ["Raid"] = false, ["Profession"] = false, ["Invasion"] = false}}--, ["Emissary"] = false}}
				,[3] = {["name"] = _L["REWARD"]
						, ["flags"] = {["Item"] = false, ["Armor"] = false, ["Gold"] = false, ["Currency"] = false, ["Artifact"] = false, ["Relic"] = false, ["None"] = false, ["Experience"] = false, ["Honor"] = false, ["Reputation"] = false}}
			}
	}
}

for k, v in pairs(WQT_FACTION_DATA) do
	if v.expansion >= WQT_EXPANSION_LEGION then
		WQT_DEFAULTS.global.filters[1].flags[k] = false;
	end
end
	
------------------------------------------------------------

local _filterOrders = {}

------------------------------------------------------------

local function QuestIsWatched(questID)
	for i=1, GetNumWorldQuestWatches() do 
		if (GetWorldQuestWatchInfo(i) == questID) then
			return true;
		end
	end
	return false;
end

local function GetMapWQProvider()
	if WQT.mapWQProvider then return WQT.mapWQProvider; end
	
	for k, v in pairs(WorldMapFrame.dataProviders) do 
		for k1, v2 in pairs(k) do
			if k1=="IsMatchingWorldMapFilters" then 
				WQT.mapWQProvider = k; 
				break;
			end 
		end 
	end
	-- We hook it here because we can't hook it during addonloaded for some reason
	hooksecurefunc(WQT.mapWQProvider, "RefreshAllData", function(self) 
			WQT_WorldQuestFrame.pinHandler:UpdateMapPoI(); 
			
			-- If the pins updated and make sure the highlight is still on the correct pin
			local parentPin = WQT_PoISelectIndicator:GetParent();
			local questId = parentPin and parentPin.questID;
			if (WQT_PoISelectIndicator:IsShown() and questId and questId ~= WQT_PoISelectIndicator.questId) then
				local pin = WQT:GetMapPinForWorldQuest(WQT_PoISelectIndicator.questId);
				if pin then
					WQT_WorldQuestFrame:ShowHighlightOnPin(pin)
				end
			end
			
			-- Keep highlighted pin in foreground
			if (WQT_PoISelectIndicator.questId) then
				local provider = GetMapWQProvider();
				local pin = provider.activePins[WQT_PoISelectIndicator.questId];
				if (pin) then
					pin:SetFrameLevel(3000);
				end
			end
			
			
			-- Hook a script to every pin's OnClick
			for qId, pin in pairs(WQT.mapWQProvider.activePins ) do
				if (not pin.WQTHooked) then
					pin.WQTHooked = true;
					hooksecurefunc(pin, "OnClick", function(self, button) 
						if (button == "RightButton") then
							-- If the quest wasn't tracked before we clicked, untrack it again
							if (self.notTracked and QuestIsWatched(self.questID)) then
								RemoveWorldQuestWatch(self.questID);
							end
							-- Show the tracker dropdown
							if WQT_TrackDropDown:GetParent() ~= self then
								-- If the dropdown is linked to another button, we must move and close it first
								WQT_TrackDropDown:SetParent(self);
								ADD:HideDropDownMenu(1);
							end
							ADD:ToggleDropDownMenu(1, nil, WQT_TrackDropDown, self, -10, 0);
						end
							
					end)
				end
			end

		end);

	return WQT.mapWQProvider;
end

function WQT:GetMapPinForWorldQuest(questID)
	local provider = GetMapWQProvider();
	if (provider == nil) then
		return nil
	end
	
	return provider.activePins[questID];
end

function WQT:GetMapPinForBonusObjective(questID)
	if not WorldMapFrame.pinPools["BonusObjectivePinTemplate"] then 
		return nil; 
	end
	
	for pin, v in pairs(WorldMapFrame.pinPools["BonusObjectivePinTemplate"].activeObjects) do 
		if (questID == pin.questID) then
			return pin;
		end
	end
	return nil;
end

local function GetFactionData(id)
	if (not id) then  
		-- No faction
		return WQT_NO_FACTION_DATA;
	end;

	if (not WQT_FACTION_DATA[id]) then
		-- Add new faction
		WQT_FACTION_DATA[id] = { ["expansion"] = 0 ,["faction"] = nil ,["icon"] = WQT_FACTIONUNKNOWN }
		WQT_FACTION_DATA[id].name = GetFactionInfoByID(id) or "Unknown Faction";
	end
	
	return WQT_FACTION_DATA[id];
end

local function GetAbreviatedNumberChinese(number)
	if type(number) ~= "number" then return "NaN" end;
	if (number >= 10000 and number < 100000) then
		local rest = number - floor(number/10000)*10000
		if rest < 100 then
			return _L["NUMBERS_FIRST"]:format(floor(number / 10000));
		else
			return _L["NUMBERS_FIRST"]:format(floor(number / 1000)/10);
		end
	elseif (number >= 100000 and number < 100000000) then
		return _L["NUMBERS_FIRST"]:format(floor(number / 10000));
	elseif (number >= 100000000 and number < 1000000000) then
		local rest = number - floor(number/100000000)*100000000
		if rest < 100 then
			return _L["NUMBERS_SECOND"]:format(floor(number / 100000000));
		else
			return _L["NUMBERS_SECOND"]:format(floor(number / 10000000)/10);
		end
	elseif (number >= 1000000000) then
		return _L["NUMBERS_SECOND"]:format(floor(number / 100000000));
	end
	return number 
end

local function GetAbreviatedNumberRoman(number)
	if type(number) ~= "number" then return "NaN" end;
	if (number >= 1000 and number < 10000) then
		local rest = number - floor(number/1000)*1000
		if rest < 100 then
			return _L["NUMBERS_FIRST"]:format(floor(number / 1000));
		else
			return _L["NUMBERS_FIRST"]:format(floor(number / 100)/10);
		end
	elseif (number >= 10000 and number < 1000000) then
		return _L["NUMBERS_FIRST"]:format(floor(number / 1000));
	elseif (number >= 1000000 and number < 10000000) then
		local rest = number - floor(number/1000000)*1000000
		if rest < 100000 then
			return _L["NUMBERS_SECOND"]:format(floor(number / 1000000));
		else
			return _L["NUMBERS_SECOND"]:format(floor(number / 100000)/10);
		end
	elseif (number >= 10000000 and number < 1000000000) then
		return _L["NUMBERS_SECOND"]:format(floor(number / 1000000));
	elseif (number >= 1000000000 and number < 10000000000) then
		local rest = number - floor(number/1000000000)*1000000000
		if rest < 100000000 then
			return _L["NUMBERS_THIRD"]:format(floor(number / 1000000000));
		else
			return _L["NUMBERS_THIRD"]:format(floor(number / 100000000)/10);
		end
	elseif (number >= 10000000) then
		return _L["NUMBERS_THIRD"]:format(floor(number / 1000000000));
	end
	return number 
end

local function GetLocalizedAbreviatedNumber(number)
	if (_L["IS_AZIAN_CLIENT"]) then
		return GetAbreviatedNumberChinese(number);
	end
	return GetAbreviatedNumberRoman(number);
end

local function slashcmd(msg, editbox)
	if msg == "options" then
		print(_L["OPTIONS_INFO"]);
	else
		if _debug then
		-- This is to get the zone coords for highlights so I don't have to retype it every time
		
		-- local x, y = GetCursorPosition();
		
		-- local WorldMapButton = WorldMapFrame.ScrollContainer.Child;
		-- x = x / WorldMapButton:GetEffectiveScale();
		-- y = y / WorldMapButton:GetEffectiveScale();
	
		-- local centerX, centerY = WorldMapButton:GetCenter();
		-- local width = WorldMapButton:GetWidth();
		-- local height = WorldMapButton:GetHeight();
		-- local adjustedY = (centerY + (height/2) - y ) / height;
		-- local adjustedX = (x - (centerX - (width/2))) / width;
		-- print(WorldMapFrame.mapID)
		-- print("{\[\"x\"\] = " .. floor(adjustedX*100)/100 .. ", \[\"y\"\] = " .. floor(adjustedY*100)/100 .. "} ")
		local debugfr = WQT.debug;
		debugfr.mem = GetAddOnMemoryUsage(addonName);
		local frames = {WQT_WorldQuestFrame, WQT_QuestScrollFrame, WQT_WorldQuestFrame.pinHandler, WQT_WorldQuestFrame.dataprovider, WQT};
		for key, frame in pairs(frames) do
			for k, v in pairs(frame) do
				if type(v) == "function" then
					local name = frame.GetName and  frame:GetName() .. ":" or ""
					debugfr.callCounters[name .. k] = {};
					hooksecurefunc(frame, k, function(self) 
							local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
							tinsert(debugfr.callCounters[name .. k], time().."|"..mem);
						end)
				end
			end
		end
	
		debugfr.callCounters["OnMapChanged"] = {};
		hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
			local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
			tinsert(debugfr.callCounters["OnMapChanged"], time().."|"..mem);
		end)
			
		debugfr.callCounters["QuestMapFrame_ShowQuestDetails"] = {};
		hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["QuestMapFrame_ShowQuestDetails"], time().."|"..mem);
			end)
		
		debugfr.callCounters["QuestMapFrame_ReturnFromQuestDetails"] = {};
		hooksecurefunc("QuestMapFrame_ReturnFromQuestDetails", function()
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["QuestMapFrame_ReturnFromQuestDetails"], time().."|"..mem);
			end)
			
			debugfr.callCounters["ToggleDropDownMenu"] = {};
		hooksecurefunc("ToggleDropDownMenu", function()
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["ToggleDropDownMenu"], time().."|"..mem);
			end);
			
			debugfr.callCounters["QuestMapFrame_ShowQuestDetails"] = {};
		hooksecurefunc("QuestMapFrame_ShowQuestDetails", function(self)
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["QuestMapFrame_ShowQuestDetails"], time().."|"..mem);
			end)
			
			debugfr.callCounters["LFGListSearchPanel_UpdateResults"] = {};
		hooksecurefunc("LFGListSearchPanel_UpdateResults", function(self)
				local mem = GetAddOnMemoryUsage(addonName) - debugfr.mem;
				tinsert(debugfr.callCounters["LFGListSearchPanel_UpdateResults"], time().."|"..mem);
			end)
		end
	end
end

local function IsRelevantFilter(filterID, key)
	-- Check any filter outside of factions if disabled by worldmap filter
	if (filterID > 1) then return not WQT:FilterIsWorldMapDisabled(key) end
	-- Faction filters that are a string get a pass
	if (not key or type(key) == "string") then return true; end
	-- Factions with an ID of which the player faction is matching or neutral pass
	local data = GetFactionData(key);
	local playerFaction = GetPlayerFactionGroup();
	if (data and not data.faction or data.faction == playerFaction) then return true; end
	
	return false;
end

local function GetSortedFilterOrder(filterId)
	local filter = WQT.settings.filters[filterId];
	local tbl = {};
	for k, v in pairs(filter.flags) do
		table.insert(tbl, k);
	end
	table.sort(tbl, function(a, b) 
				if(a == _L["REWARD_NONE"] or b == _L["REWARD_NONE"])then
					return a == _L["REWARD_NONE"] and b == _L["REWARD_NONE"];
				end
				if(a == _L["NO_FACTION"] or b == _L["NO_FACTION"])then
					return a ~= _L["NO_FACTION"] and b == _L["NO_FACTION"];
				end
				if(a == _L["OTHER_FACTION"] or b == _L["OTHER_FACTION"])then
					return a ~= _L["OTHER_FACTION"] and b == _L["OTHER_FACTION"];
				end
				if(type(a) == "number" and type(b) == "number")then
					local nameA = GetFactionInfoByID(tonumber(a));
					local nameB = GetFactionInfoByID(tonumber(b));
					if nameA and nameB then
						return nameA < nameB;
					end
					return a and not b;
				end
				return a < b; 
			end)
	return tbl;
end

function UnlockArgusHighlights()
	for k, button in ipairs(WQT_ARGUS_COSMIC_BUTTONS) do
		button:UnlockHighlight(); 
	end
end

local function SortQuestList(list)
	table.sort(list, function(a, b) 
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2) or a.time.minutes == b.time.minutes then
				if a.expantionLevel ==  b.expantionLevel then
					return a.title < b.title;
				end
				return a.expantionLevel > b.expantionLevel;
			end	
			return a.time.minutes < b.time.minutes;
	end);
end

local function SortQuestListByZone(list)
	table.sort(list, function(a, b) 
		if a.zoneInfo.mapID == b.zoneInfo.mapID then
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2) or a.time.minutes == b.time.minutes then
				return a.title < b.title;
			end	
			return a.time.minutes < b.time.minutes;
		end
		return (a.zoneInfo.name or "zz") < (b.zoneInfo.name or "zz");
	end);
end

local function SortQuestListByFaction(list)
	table.sort(list, function(a, b) 
	if a.expantionLevel ==  b.expantionLevel then
		if a.faction == b.faction then
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2) or a.time.minutes == b.time.minutes then
				return a.title < b.title;
			end	
			return a.time.minutes < b.time.minutes;
		end
		return a.faction > b.faction;
	end
	return a.expantionLevel > b.expantionLevel;
	end);
end

local function SortQuestListByType(list)
	table.sort(list, function(a, b) 
		local aIsCriteria = WorldMapFrame.overlayFrames[WQT_BOUNDYBOARD_OVERLAYID]:IsWorldQuestCriteriaForSelectedBounty(a.questId);
		local bIsCriteria = WorldMapFrame.overlayFrames[WQT_BOUNDYBOARD_OVERLAYID]:IsWorldQuestCriteriaForSelectedBounty(b.questId);
		if aIsCriteria == bIsCriteria then
			if a.type == b.type then
				if a.rarity == b.rarity then
					if (a.isElite and b.isElite) or (not a.isElite and not b.isElite) then
						-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
						if (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2) or a.time.minutes == b.time.minutes then
							return a.title < b.title;
						end	
						return a.time.minutes < b.time.minutes;
					end
					return b.isElite;
				end
				return a.rarity < b.rarity;
			end
			return a.type < b.type;
		end
		return aIsCriteria and not bIsCriteria;
	end);
end

local function SortQuestListByName(list)
	table.sort(list, function(a, b) 
		return a.title < b.title;
	end);
end

local function SortQuestListByReward(list)
	table.sort(list, function(a, b) 
		if a.reward.type == b.reward.type then
			if not a.reward.quality or not b.reward.quality or a.reward.quality == b.reward.quality then
				if not a.reward.amount or not b.reward.amount or a.reward.amount == b.reward.amount then
					-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
					if (a.time.minutes > 60 and b.time.minutes > 60 and math.abs(a.time.minutes - b.time.minutes) < 2) or a.time.minutes == b.time.minutes then
						return a.title < b.title;
					end	
					return a.time.minutes < b.time.minutes;
				
				end
				return a.reward.amount > b.reward.amount;
			end
			return a.reward.quality > b.reward.quality;
		elseif a.reward.type == 0 or b.reward.type == 0 then
			return a.reward.type > b.reward.type;
		end
		return a.reward.type < b.reward.type;
	end);
end

local function GetQuestTimeString(questId)
	local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questId);
	local timeString = "";
	local timeStringShort = "";
	local color = WQT_WHITE_FONT_COLOR;
	if ( timeLeftMinutes ) then
		if ( timeLeftMinutes <= WORLD_QUESTS_TIME_CRITICAL_MINUTES ) then
			color = RED_FONT_COLOR;
			timeString = SecondsToTime(timeLeftMinutes * 60);
		elseif timeLeftMinutes < 60  then
			timeString = SecondsToTime(timeLeftMinutes * 60);
			color = WQT_ORANGE_FONT_COLOR;
		elseif timeLeftMinutes < 24 * 60  then
			timeString = D_HOURS:format(timeLeftMinutes / 60);
			color = WQT_GREEN_FONT_COLOR
		else
			timeString = D_DAYS:format(timeLeftMinutes  / 1440);
			color = WQT_BLUE_FONT_COLOR;
		end
	end
	-- start with default, for CN and KR
	timeStringShort = timeString;
	local t, str = string.match(timeString:gsub(" |4", ""), '(%d+)(%a)');
	if t and str then
		timeStringShort = t..str;
	end

	return timeLeftMinutes, timeString, color, timeStringShort;
end

local function ConvertOldSettings()
	WQT.settings.filters[3].flags.Resources = nil;
	WQT.settings.versionCheck = "1";
end

local function ConvertToBfASettings()
	-- In 8.0.01 factions use ids rather than name
	local repFlags = WQT.settings.filters[1].flags;
	for name, value in pairs(repFlags) do
		if (type(name) == "string" and name ~=_L["OTHER_FACTION"] and name ~= _L["NO_FACTION"]) then
			repFlags[name] = nil;
		end
	end
end

local deprecated = {
		["id"] = true, ["mapX"] = true, ["mapY"] = true, ["mapF"] = true, ["timeString"] = true, ["timeStringShort"] = true, 
		["color"] = true, ["minutes"] = true, ["zoneId"] = true, ["continentId"] = true, ["rewardId"] = true, ["rewardQuality"] = true, 
		["rewardTexture"] = true, ["numItems"] = true, ["rewardType"] = true, ["ringColor"] = true, ["subRewardType"] = true;
	}

local function AddDebugToTooltip(tooltip, questInfo)
	-- First all non table values;
	for key, value in pairs(questInfo) do
		if (not deprecated[key]) then
			if (type(value) ~= "table") then
				tooltip:AddDoubleLine(key, tostring(value));
			elseif (type(value) == "table" and value.GetRGBA) then
				tooltip:AddDoubleLine(key, value.r .. "/" .. value.g .. "/" .. value.b );
			end
		end
	end

	-- Actual tables
	for key, value in pairs(questInfo) do
		if (type(value) == "table" and not value.GetRGBA) then
			tooltip:AddDoubleLine(key, "");
			for key2, value2 in pairs(value) do
				if (type(value2) == "table" and value2.GetRGBA) then-- colors
					tooltip:AddDoubleLine("    " .. key2, value2.r .. "/" .. value2.g .. "/" .. value2.b );
				else
					tooltip:AddDoubleLine("    " .. key2, tostring(value2));
				end
			end
		end
	end
	
	-- Deprecated values
	for key, value in pairs(questInfo) do
		if (deprecated[key]) then
			if (type(value) ~= "table") then
				tooltip:AddDoubleLine(key, tostring(value) , 0.5, 0.5, 0.5, 0.5, 0.5, 0.5);
			elseif (type(value) == "table" and value.GetRGBA) then
				tooltip:AddDoubleLine(key, value.r .. "/" .. value.g .. "/" .. value.b , 0.5, 0.5, 0.5, 0.5, 0.5, 0.5);
			end
		end
	end

end

function WQT:UpdateFilterIndicator() 
	if (InCombatLockdown()) then return; end
	if (GetCVarBool("showTamers") and GetCVarBool("worldQuestFilterArtifactPower") and GetCVarBool("worldQuestFilterResources") and GetCVarBool("worldQuestFilterGold") and GetCVarBool("worldQuestFilterEquipment")) then
		WQT_WorldQuestFrame.filterButton.indicator:Hide();
	else
		WQT_WorldQuestFrame.filterButton.indicator:Show();
	end
end

function WQT:SetAllFilterTo(id, value)
	local options = WQT.settings.filters[id].flags;
	for k, v in pairs(options) do
		options[k] = value;
	end
end

function WQT:FilterIsWorldMapDisabled(filter)
	if (filter == "Petbattle" and not GetCVarBool("showTamers")) or (filter == "Artifact" and not GetCVarBool("worldQuestFilterArtifactPower")) or (filter == "Currency" and not GetCVarBool("worldQuestFilterResources"))
		or (filter == "Gold" and not GetCVarBool("worldQuestFilterGold")) or (filter == "Armor" and not GetCVarBool("worldQuestFilterEquipment")) then
		
		return true;
	end

	return false;
end

function WQT:InitFilter(self, level)

	local info = ADD:CreateInfo();
	info.keepShownOnClick = true;	
	info.tooltipWhileDisabled = true;
	info.tooltipOnButton = true;
	info.hoverFuncWhileDisabled = true;
	
	if level == 1 then
		info.checked = 	nil;
		info.isNotRadio = nil;
		info.func =  nil;
		info.hasArrow = false;
		info.notCheckable = false;
		
		info.text = _L["TYPE_EMISSARY"];
		info.func = function(_, _, _, value)
				WQT.settings.emissaryOnly = value;
				WQT_QuestScrollFrame:DisplayQuestList();
				if (WQT.settings.filterPoI) then
					WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
				end
			end
		info.checked = function() return WQT.settings.emissaryOnly end;
		ADD:AddButton(info, level);			
		
		info.hasArrow = true;
		info.notCheckable = true;
		
		for k, v in pairs(WQT.settings.filters) do
			info.text = v.name;
			info.value = k;
			ADD:AddButton(info, level)
		end
		
		info.text = _L["SETTINGS"];
		info.value = 0;
		ADD:AddButton(info, level)
	elseif level == 2 then
		info.hasArrow = false;
		info.isNotRadio = true;
		if ADD.MENU_VALUE then
			if ADD.MENU_VALUE == 1 then
			
				info.notCheckable = true;
					
				info.text = CHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(1, true);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:DisplayQuestList();
							end
				ADD:AddButton(info, level)
				
				info.text = UNCHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(1, false);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:DisplayQuestList();
							end
				ADD:AddButton(info, level)
			
				info.notCheckable = false;
				local options = WQT.settings.filters[ADD.MENU_VALUE].flags;
				local order = _filterOrders[ADD.MENU_VALUE] 
				local haveLabels = (WQT_TYPEFLAG_LABELS[ADD.MENU_VALUE] ~= nil);
				local currExp = WQT_EXPANSION_BFA;
				local playerFaction = GetPlayerFactionGroup();
				for k, flagKey in pairs(order) do
					local factionInfo = type(flagKey) == "number" and GetFactionData(flagKey) or nil;
					-- factions that aren't a faction (other and no faction), are of current expansion, and are neutral of player faction
					if (not factionInfo or (factionInfo.expansion == currExp and (not factionInfo.faction or factionInfo.faction == playerFaction))) then
						info.text = type(flagKey) == "number" and GetFactionInfoByID(flagKey) or flagKey;
						info.func = function(_, _, _, value)
											options[flagKey] = value;
											if (value) then
												WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
											end
											WQT_QuestScrollFrame:DisplayQuestList();
										end
						info.checked = function() return options[flagKey] end;
						ADD:AddButton(info, level);			
					end
				end
				
				info.hasArrow = true;
				info.notCheckable = true;
				info.text = EXPANSION_NAME6;
				info.value = 100;
				info.func = nil;
				ADD:AddButton(info, level)
				
			
			elseif WQT.settings.filters[ADD.MENU_VALUE] then
				
				info.notCheckable = true;
					
				info.text = CHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(ADD.MENU_VALUE, true);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:DisplayQuestList();
							end
				ADD:AddButton(info, level)
				
				info.text = UNCHECK_ALL
				info.func = function()
								WQT:SetAllFilterTo(ADD.MENU_VALUE, false);
								ADD:Refresh(self, 1, 2);
								WQT_QuestScrollFrame:DisplayQuestList();
							end
				ADD:AddButton(info, level)
			
				info.notCheckable = false;
				local options = WQT.settings.filters[ADD.MENU_VALUE].flags;
				local order = _filterOrders[ADD.MENU_VALUE] 
				local haveLabels = (WQT_TYPEFLAG_LABELS[ADD.MENU_VALUE] ~= nil);
				for k, flagKey in pairs(order) do
					info.disabled = false;
					info.tooltipTitle = nil;
					info.text = haveLabels and WQT_TYPEFLAG_LABELS[ADD.MENU_VALUE][flagKey] or flagKey;
					info.func = function(_, _, _, value)
										options[flagKey] = value;
										if (value) then
											WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
										end
										WQT_QuestScrollFrame:DisplayQuestList();
									end
					info.checked = function() return options[flagKey] end;
					info.funcEnter = nil;
					info.funcLeave = nil;
					
					if WQT:FilterIsWorldMapDisabled(flagKey) then
						info.disabled = true;
						info.tooltipTitle = _L["MAP_FILTER_DISABLED"];
						info.tooltipText = _L["MAP_FILTER_DISABLED_INFO"];
						info.funcEnter = function() WQT_WorldQuestFrame:ShowHighlightOnMapFilters(); end;
						info.funcLeave = function() WQT_PoISelectIndicator:Hide(); end;	
					end
					
					ADD:AddButton(info, level);			
				end
				
			elseif ADD.MENU_VALUE == 0 then
				info.notCheckable = false;
				info.tooltipWhileDisabled = true;
				info.tooltipOnButton = true;
				
				info.text = _L["DEFAULT_TAB"];
				info.tooltipTitle = _L["DEFAULT_TAB_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.defaultTab = value;

					end
				info.checked = function() return WQT.settings.defaultTab end;
				ADD:AddButton(info, level);			

				info.text = _L["SAVE_SETTINGS"];
				info.tooltipTitle = _L["SAVE_SETTINGS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.saveFilters = value;
					end
				info.checked = function() return WQT.settings.saveFilters end;
				ADD:AddButton(info, level);	
				
				info.text = _L["PRECISE_FILTER"];
				info.tooltipTitle = _L["PRECISE_FILTER_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.preciseFilter = value;
						WQT_QuestScrollFrame:DisplayQuestList();
						if (WQT.settings.filterPoI) then
							WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
						end
					end
				info.checked = function() return WQT.settings.preciseFilter end;
				ADD:AddButton(info, level);	
				
				info.text = _L["PIN_DISABLE"];
				info.tooltipTitle = _L["PIN_DISABLE_TT"];
				info.func = function(_, _, _, value)
						-- Update these numbers when adding new options !
						local start, stop = 5, 8
						WQT.settings.disablePoI = value;
						if (value) then
							-- Reset alpha on official pins
							local WQProvider = GetMapWQProvider();
							local WQProvider = GetMapWQProvider();
							for qID, PoI in pairs(WQProvider.activePins) do
								PoI.BountyRing:SetAlpha(1);
								PoI.TimeLowFrame:SetAlpha(1);
								PoI.TrackedCheck:SetAlpha(1);
							end
							WQT_WorldQuestFrame.pinHandler.pinPool:ReleaseAll();
							for i = start, stop do
								ADD:DisableButton(2, i);
							end
						else
							for i = start, stop do
								ADD:EnableButton(2, i);
							end
						end
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI(true)
					end
				info.checked = function() return WQT.settings.disablePoI end;
				ADD:AddButton(info, level);
				
				info.text = _L["FILTER_PINS"];
				info.disabled = WQT.settings.disablePoI;
				info.tooltipTitle = _L["FILTER_PINS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.filterPoI = value;
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					end
				info.checked = function() return WQT.settings.filterPoI end;
				ADD:AddButton(info, level);
				
				info.text = _L["PIN_REWARDS"];
				info.disabled = WQT.settings.disablePoI;
				info.tooltipTitle = _L["PIN_REWARDS_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showPinReward = value;
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					end
				info.checked = function() return WQT.settings.showPinReward end;
				ADD:AddButton(info, level);
				
				info.text = _L["PIN_COLOR"];
				info.disabled = WQT.settings.disablePoI;
				info.tooltipTitle = _L["PIN_COLOR_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showPinRing = value;
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					end
				info.checked = function() return WQT.settings.showPinRing end;
				ADD:AddButton(info, level);
				
				info.text = _L["PIN_TIME"];
				info.disabled = WQT.settings.disablePoI;
				info.tooltipTitle = _L["PIN_TIME_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showPinTime = value;
						WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
					end
				info.checked = function() return WQT.settings.showPinTime end;
				ADD:AddButton(info, level);
				
				info.disabled = false;
				
				info.text = _L["SHOW_TYPE"];
				info.tooltipTitle = _L["SHOW_TYPE_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showTypeIcon = value;
						WQT_QuestScrollFrame:UpdateQuestList();
					end
				info.checked = function() return WQT.settings.showTypeIcon end;
				ADD:AddButton(info, level);		
				
				info.text = _L["SHOW_FACTION"];
				info.tooltipTitle = _L["SHOW_FACTION_TT"];
				info.func = function(_, _, _, value)
						WQT.settings.showFactionIcon = value;
						WQT_QuestScrollFrame:UpdateQuestList();
					end
				info.checked = function() return WQT.settings.showFactionIcon end;
				ADD:AddButton(info, level);		
				
				-- TomTom compatibility
				if _TomTomLoaded then
					info.text = "Use TomTom";
					info.tooltipTitle = "";
					info.func = function(_, _, _, value)
							WQT.settings.useTomTom = value;
							WQT_QuestScrollFrame:UpdateQuestList();
						end
					info.checked = function() return WQT.settings.useTomTom end;
					ADD:AddButton(info, level);	
				end
			end
		end
	elseif level == 3 then
		info.isNotRadio = true;
		info.notCheckable = false;
		local options = WQT.settings.filters[1].flags;
		local order = _filterOrders[1] 
		local haveLabels = (WQT_TYPEFLAG_LABELS[1] ~= nil);
		local currExp = WQT_EXPANSION_LEGION;
		for k, flagKey in pairs(order) do
			local data = type(flagKey) == "number" and GetFactionData(flagKey) or nil;
			if (data and data.expansion == currExp ) then
				info.text = type(flagKey) == "number" and data.name or flagKey;
				info.func = function(_, _, _, value)
									options[flagKey] = value;
									if (value) then
										WQT_WorldQuestFrame.pinHandler:UpdateMapPoI()
									end
									WQT_QuestScrollFrame:DisplayQuestList();
								end
				info.checked = function() return options[flagKey] end;
				ADD:AddButton(info, level);			
			end
		end
	end

end

function WQT:InitSort(self, level)

	local selectedValue = ADD:GetSelectedValue(self);
	local info = ADD:CreateInfo();
	local buttonsAdded = 0;
	info.func = function(self, category) WQT:Sort_OnClick(self, category) end
	
	for k, option in ipairs(WQT_SORT_OPTIONS) do
		info.text = option;
		info.arg1 = k;
		info.value = k;
		if k == selectedValue then
			info.checked = 1;
		else
			info.checked = nil;
		end
		ADD:AddButton(info, level);
		buttonsAdded = buttonsAdded + 1;
	end
	
	return buttonsAdded;
end

function WQT:Sort_OnClick(self, category)

	local dropdown = WQT_WorldQuestFrameSortButton;
	if ( category and dropdown.active ~= category ) then
		ADD:CloseDropDownMenus();
		dropdown.active = category
		ADD:SetSelectedValue(dropdown, category);
		ADD:SetText(dropdown, WQT_SORT_OPTIONS[category]);
		WQT.settings.sortBy = category;
		WQT_QuestScrollFrame:UpdateQuestList();
	end
end

function WQT:InitTrackDropDown(self, level)

	if not self:GetParent() or not self:GetParent().info then return; end
	local questId = self:GetParent().info.questId;
	local questInfo = self:GetParent().info;
	local info = ADD:CreateInfo();
	info.notCheckable = true;	
	
	-- TomTom functionality
	if (_TomTomLoaded and WQT.settings.useTomTom) then
	
		if (TomTom.WaypointExists and TomTom.AddWaypoint and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints) then
			-- All required functions are found
			if (not TomTom:WaypointExists(questInfo.zoneInfo.mapID, questInfo.zoneInfo.mapX, questInfo.zoneInfo.mapY, questInfo.title)) then
				info.text = _L["TRACKDD_TOMTOM"];
				info.func = function()
					TomTom:AddWaypoint(questInfo.zoneInfo.mapID, questInfo.zoneInfo.mapX, questInfo.zoneInfo.mapY, {["title"] = questInfo.title})
					TomTom:AddWaypoint(questInfo.zoneInfo.mapID, questInfo.zoneInfo.mapX, questInfo.zoneInfo.mapY, {["title"] = questInfo.title})
				end
			else
				info.text = _L["TRACKDD_TOMTOM_REMOVE"];
				info.func = function()
					local key = TomTom:GetKeyArgs(questInfo.zoneInfo.mapID, questInfo.zoneInfo.mapX, questInfo.zoneInfo.mapY, questInfo.title);
					local wp = TomTom.waypoints[questInfo.zoneInfo.mapID] and TomTom.waypoints[questInfo.zoneInfo.mapID][key];
					TomTom:RemoveWaypoint(wp);
				end
			end
		else
			-- Something wrong with TomTom
			info.text = "TomTom Unavailable";
			info.func = function()
				print("Something is wrong with TomTom. Either it failed to load correctly, or an update changed its functionality.");
			end
		end
		
		ADD:AddButton(info, level);
	end
	
	-- Don't allow tracking and LFG for bonus objective, Blizzard UI can't handle it
	if (questInfo.type ~= WQT_TYPE_BONUSOBJECTIVE) then
		-- Tracking
		if (QuestIsWatched(questId)) then
			info.text = UNTRACK_QUEST;
			info.func = function(_, _, _, value)
						RemoveWorldQuestWatch(questId);
						WQT_QuestScrollFrame:DisplayQuestList();
					end
		else
			info.text = TRACK_QUEST;
			info.func = function(_, _, _, value)
						AddWorldQuestWatch(questId);
						WQT_QuestScrollFrame:DisplayQuestList();
					end
		end	
		ADD:AddButton(info, level)
		
		
		-- LFG if possible
		if (questInfo.type ~= LE_QUEST_TAG_TYPE_PET_BATTLE and questInfo.type ~= LE_QUEST_TAG_TYPE_DUNGEON  and questInfo.type ~= LE_QUEST_TAG_TYPE_PROFESSION and questInfo.type ~= LE_QUEST_TAG_TYPE_RAID) then
			info.text = OBJECTIVES_FIND_GROUP;
			info.func = function()
				WQT_GroupSearch:Hide();
				LFGListUtil_FindQuestGroup(questId);
				if (not C_LFGList.CanCreateQuestGroup(questId)) then
					WQT_GroupSearch:SetParent(LFGListFrame.SearchPanel.SearchBox);
					WQT_GroupSearch:SetFrameLevel(LFGListFrame.SearchPanel.SearchBox:GetFrameLevel()+5);
					WQT_GroupSearch:ClearAllPoints();
					WQT_GroupSearch:SetPoint("TOPLEFT", LFGListFrame.SearchPanel.SearchBox, "BOTTOMLEFT", -2, -3);
					WQT_GroupSearch:SetPoint("RIGHT", LFGListFrame.SearchPanel, "RIGHT", -30, 0);
				
					WQT_GroupSearch.Text:SetText(_L["FORMAT_GROUP_SEARCH"]:format(questInfo.questId, questInfo.title));
					WQT_GroupSearch.downArrow = false;
					WQT_GroupSearch:Show();
					
					WQT_GroupSearch.questId = questId;
					WQT_GroupSearch.title = questInfo.title;
				end
			end
			ADD:AddButton(info, level);
		end
	end
	
	info.text = CANCEL;
	info.func = nil;
	ADD:AddButton(info, level)
end

function WQT:IsFiltering()
	local playerFaction = GetPlayerFactionGroup()
	if WQT.settings.emissaryOnly then return true; end
	for k, category in pairs(WQT.settings.filters)do
		for k2, flag in pairs(category.flags) do
			if flag and IsRelevantFilter(k, k2) then 
				return true;
			end
		end
	end
	return false;
end

function WQT:isUsingFilterNr(id)
	-- TODO see if we can change this to only check once every time we go through all quests
	if not WQT.settings.filters[id] then return false end
	local flags = WQT.settings.filters[id].flags;
	for k, flag in pairs(flags) do
		if flag then return true; end
	end
	return false;
end

function WQT:PassesAllFilters(questInfo)
	if questInfo.questId < 0 then return true; end
	
	if not WQT:IsFiltering() then return true; end

	if WQT.settings.emissaryOnly then 
		return WorldMapFrame.overlayFrames[WQT_BOUNDYBOARD_OVERLAYID]:IsWorldQuestCriteriaForSelectedBounty(questInfo.questId);
	end
	
	local precise = WQT.settings.preciseFilter;
	local passed = true;
	
	if precise then
		if WQT:isUsingFilterNr(1) then 
			passed = WQT:PassesFactionFilter(questInfo) and true or false; 
		end
		if (WQT:isUsingFilterNr(2) and passed) then
			passed = WQT:PassesFlagId(2, questInfo) and true or false;
		end
		if (WQT:isUsingFilterNr(3) and passed) then
			passed = WQT:PassesFlagId(3, questInfo) and true or false;
		end
	else
		if WQT:isUsingFilterNr(1) and WQT:PassesFactionFilter(questInfo) then return true; end
		if WQT:isUsingFilterNr(2) and WQT:PassesFlagId(2, questInfo) then return true; end
		if WQT:isUsingFilterNr(3) and WQT:PassesFlagId(3, questInfo) then return true; end
	end
	
	return precise and passed or false;
end

function WQT:PassesFactionFilter(questInfo)
	-- Factions (1)
	local flags = WQT.settings.filters[1].flags
	-- no faction
	if not questInfo.factionId then return flags[_L["NO_FACTION"]]; end
	
	if flags[questInfo.factionId] ~= nil then 
		-- specific faction
		return flags[questInfo.factionId];
	else
		-- other faction
		return flags[_L["OTHER_FACTION"]];
	end

	return false;
end

function WQT:PassesFlagId(flagId ,questInfo)
	local flags = WQT.settings.filters[flagId].flags

	for k, func in ipairs(WQT_FILTER_FUNCTIONS[flagId]) do
		if(func(questInfo, flags)) then return true; end
	end
	return false;
end



function WQT:OnInitialize()

	self.db = LibStub("AceDB-3.0"):New("BWQDB", WQT_DEFAULTS, true);
	self.settings = self.db.global;
	
	if (not WQT.settings.versionCheck) then
		ConvertOldSettings()
	end
	if (WQT.settings.versionCheck < "8.0.1") then
		ConvertToBfASettings();
	end
	WQT.settings.versionCheck  = GetAddOnMetadata(addonName, "version");
	
end

function WQT:OnEnable()

	WQT_TabNormal.Highlight:Show();
	WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
	WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	
	if not self.settings.saveFilters then
		for k, filter in pairs(self.settings.filters) do
			WQT:SetAllFilterTo(k, false);
		end
	end

	if self.settings.saveFilters and WQT_SORT_OPTIONS[self.settings.sortBy] then
		ADD:SetSelectedValue(WQT_WorldQuestFrameSortButton, self.settings.sortBy);
		ADD:SetText(WQT_WorldQuestFrameSortButton, WQT_SORT_OPTIONS[self.settings.sortBy]);
	else
		ADD:SetSelectedValue(WQT_WorldQuestFrameSortButton, 1);
		ADD:SetText(WQT_WorldQuestFrameSortButton, WQT_SORT_OPTIONS[1]);
	end

	for k, v in pairs(WQT.settings.filters) do
		_filterOrders[k] = GetSortedFilterOrder(k);
	end
	
	WQT_WorldQuestFrame:SelectTab((UnitLevel("player") >= 110 and self.settings.defaultTab) and WQT_TabWorld or WQT_TabNormal);
end


WQT_ListButtonMixin = {}

function WQT_ListButtonMixin:OnClick(button)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	if not self.questId or self.questId== -1 then return end

	if IsModifiedClick("QUESTWATCHTOGGLE") then
		-- Don't track bonus objectives. The object tracker doesn't like it;
		if (self.info.type ~= WQT_TYPE_BONUSOBJECTIVE) then
			-- Only do tracking if we aren't adding the link tot he chat
			if (not ChatEdit_TryInsertQuestLinkForQuestID(self.questId)) then 
				if (QuestIsWatched(self.questId)) then
					RemoveWorldQuestWatch(self.questId);
				else
					AddWorldQuestWatch(self.questId, true);
				end
			end
		end
	elseif IsModifiedClick("DRESSUP") and self.info.reward.type == WQT_REWARDTYPE_ARMOR then
		local _, link = GetItemInfo(self.info.reward.id);
		DressUpItemLink(link)
		
	elseif button == "LeftButton" then
		-- Don't track bonus objectives. The object tracker doesn't like it;
		if (self.info.type ~= WQT_TYPE_BONUSOBJECTIVE) then
			AddWorldQuestWatch(self.questId);
		end
		WorldMapFrame:SetMapID(self.zoneId);
		WQT_QuestScrollFrame:DisplayQuestList();
		
	elseif button == "RightButton" then

		if WQT_TrackDropDown:GetParent() ~= self then
			 -- If the dropdown is linked to another button, we must move and close it first
			WQT_TrackDropDown:SetParent(self);
			ADD:HideDropDownMenu(1);
		end
		ADD:ToggleDropDownMenu(1, nil, WQT_TrackDropDown, "cursor", -10, -10);
	end
	
	
end

function WQT_ListButtonMixin:SetEnabled(value)
	value = value==nil and true or value;
	
	if value then
		self:Enable();
	else
		self:Disable();
	end
	
	
	self:EnableMouse(value);
	self.faction:EnableMouse(value);
end

function WQT_ListButtonMixin:OnLeave()
	UnlockArgusHighlights();
	HideUIPanel(self.highlight);
	WQT_Tooltip:Hide();
	WQT_Tooltip.ItemTooltip:Hide();
	WQT_PoISelectIndicator:Hide();
	WQT_MapZoneHightlight:Hide();
	
	-- Reset highlighted pin to original frame level
	if (WQT_PoISelectIndicator.pin) then
		WQT_PoISelectIndicator.pin:SetFrameLevel(WQT_PoISelectIndicator.pinLevel);
	end
	WQT_PoISelectIndicator.questId = nil;
	
	if (self.resetLabel) then
		WorldMapFrame.ScrollContainer:GetMap():TriggerEvent("ClearAreaLabel", MAP_AREA_LABEL_TYPE.POI);
		self.resetLabel = false;
	end
end

function WQT_ListButtonMixin:OnEnter()
	ShowUIPanel(self.highlight);
	
	local questInfo = self.info;
	
	-- Put the ping on the relevant map pin
	local scale = 1;
	local pin = WQT:GetMapPinForWorldQuest(questInfo.questId)
	if not pin then
		 pin = WQT:GetMapPinForBonusObjective(questInfo.questId);
		 scale = 0.5;
	end
	if pin then
		WQT_WorldQuestFrame:ShowHighlightOnPin(pin, scale)
		WQT_PoISelectIndicator.questId = questInfo.questId;
	end
	
	WQT_QuestScrollFrame:ShowQuestTooltip(self, questInfo);
	
	-- If we are on a continent, we want to highlight the relevant zone
	self:ShowWorldmapHighlight(questInfo.zoneInfo.mapID);
end

function WQT_ListButtonMixin:UpdateQuestType(questInfo)
	local frame = self.type;
	local inProgress = false;
	local isCriteria = WorldMapFrame.overlayFrames[WQT_BOUNDYBOARD_OVERLAYID]:IsWorldQuestCriteriaForSelectedBounty(questInfo.questId);
	local questType, rarity, isElite, tradeskillLineIndex = questInfo.type, questInfo.rarity, questInfo.isElite, questInfo.tradeskill;
	
	frame:Show();
	frame:SetWidth(frame:GetHeight());
	frame.texture:Show();
	frame.texture:Show();
	
	if isElite then
		frame.elite:Show();
	else
		frame.elite:Hide();
	end
	
	if not rarity or rarity == LE_WORLD_QUEST_QUALITY_COMMON then
		frame.bg:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		frame.bg:SetTexCoord(0.875, 1, 0.375, 0.5);
		frame.bg:SetSize(28, 28);
	elseif rarity == LE_WORLD_QUEST_QUALITY_RARE then
		frame.bg:SetAtlas("worldquest-questmarker-rare");
		frame.bg:SetTexCoord(0, 1, 0, 1);
		frame.bg:SetSize(18, 18);
	elseif rarity == LE_WORLD_QUEST_QUALITY_EPIC then
		frame.bg:SetAtlas("worldquest-questmarker-epic");
		frame.bg:SetTexCoord(0, 1, 0, 1);
		frame.bg:SetSize(18, 18);
	end
	
	local tradeskillLineID = tradeskillLineIndex and select(7, GetProfessionInfo(tradeskillLineIndex));
	if ( questType == LE_QUEST_TAG_TYPE_PVP ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-pvp-ffa", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_PET_BATTLE ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-petbattle", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_PROFESSION and WORLD_QUEST_ICONS_BY_PROFESSION[tradeskillLineID] ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas(WORLD_QUEST_ICONS_BY_PROFESSION[tradeskillLineID], true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_DUNGEON ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-dungeon", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_RAID ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-raid", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_INVASION ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-burninglegion", true);
		end
	else
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-questmarker-questbang");
			frame.texture:SetSize(6, 15);
		end
	end
	
	if ( isCriteria ) then
		if ( isElite ) then
			frame.criteriaGlow:SetAtlas("worldquest-questmarker-dragon-glow", false);
			frame.criteriaGlow:SetPoint("CENTER", 0, -1);
		else
			frame.criteriaGlow:SetAtlas("worldquest-questmarker-glow", false);
			frame.criteriaGlow:SetPoint("CENTER", 0, 0);
		end
		frame.criteriaGlow:Show();
	else
		frame.criteriaGlow:Hide();
	end
	
	-- Bonus objectives
	if (questType == WQT_TYPE_BONUSOBJECTIVE) then
		frame.texture:SetAtlas("QuestBonusObjective", true);
		frame.texture:SetSize(22, 22);
	end
end

function WQT_ListButtonMixin:Update(questInfo, shouldShowZone)
	
	self:Show();
	self.title:SetText(questInfo.title);
	self.time:SetTextColor(questInfo.time.color.r, questInfo.time.color.g, questInfo.time.color.b, 1);
	self.time:SetText(questInfo.time.full);
	self.extra:SetText(shouldShowZone and questInfo.zoneInfo.name or "");
			
	if (WQT_QuestScrollFrame.PoIHoverId == questInfo.questId) then
		self.highlight:Show();
	end
			
	self.title:ClearAllPoints()
	self.title:SetPoint("RIGHT", self.reward, "LEFT", -5, 0);
	
	self.info = questInfo;
	self.zoneId = questInfo.zoneInfo.mapID;
	self.questId = questInfo.questId;
	self.numObjectives = questInfo.numObjectives;
	
	if WQT.settings.showFactionIcon then
		self.title:SetPoint("BOTTOMLEFT", self.faction, "RIGHT", 5, 1);
	elseif WQT.settings.showTypeIcon then
		self.title:SetPoint("BOTTOMLEFT", self.type, "RIGHT", 5, 1);
	else
		self.title:SetPoint("BOTTOMLEFT", self, "LEFT", 10, 0);
	end
	
	if WQT.settings.showFactionIcon then
		self.faction:Show();
		local factionData = GetFactionData(questInfo.factionId);
		
		self.faction.icon:SetTexture(factionData.icon);--, nil, nil, "TRILINEAR");
		self.faction:SetWidth(self.faction:GetHeight());
	else
		self.faction:Hide();
		self.faction:SetWidth(0.1);
	end
	
	if WQT.settings.showTypeIcon then
		self:UpdateQuestType(questInfo)
	else
		self.type:Hide()
		self.type:SetWidth(0.1);
	end
	
	-- display reward
	self.reward:Show();
	self.reward.icon:Show();

	if questInfo.reward.type == WQT_REWARDTYPE_MISSING then
		self.reward.iconBorder:SetVertexColor(1, 0, 0);
		self.reward:SetAlpha(1);
		self.reward.icon:SetTexture(WQT_QUESTIONMARK);
	else
		local r, g, b = GetItemQualityColor(questInfo.reward.quality);
		self.reward.iconBorder:SetVertexColor(r, g, b);
		self.reward:SetAlpha(1);
		if questInfo.reward.texture == "" then
			self.reward:SetAlpha(0);
		end
		self.reward.icon:SetTexture(questInfo.reward.texture);
	
		if questInfo.reward.amount and questInfo.reward.amount > 1  then
			self.reward.amount:SetText(GetLocalizedAbreviatedNumber(questInfo.reward.amount));
			r, g, b = 1, 1, 1;
			if questInfo.reward.type == WQT_REWARDTYPE_RELIC then
				self.reward.amount:SetText("+" .. questInfo.reward.amount);
			elseif questInfo.reward.type == WQT_REWARDTYPE_ARTIFACT then
				r, g, b = GetItemQualityColor(2);
			elseif questInfo.reward.type == WQT_REWARDTYPE_ARMOR then
				if questInfo.reward.upgradable then
					self.reward.amount:SetText(questInfo.reward.amount.."+");
				end
				r, g, b = WQT_COLOR_ARMOR:GetRGB();
			end
	
			self.reward.amount:SetVertexColor(r, g, b);
			self.reward.amount:Show();
		end
	end
	
	if GetSuperTrackedQuestID() == questInfo.questId or IsWorldQuestWatched(questInfo.questId) then
		self.trackedBorder:Show();
	end

end

function WQT_ListButtonMixin:ShowWorldmapHighlight(zoneId)
	local areaId = WorldMapFrame.mapID;
	local coords = WQT_ZONE_MAPCOORDS[areaId] and WQT_ZONE_MAPCOORDS[areaId][zoneId];
	if not coords then return; end;

	local mapInfo = C_Map.GetMapInfo(zoneId);
	WorldMapFrame.ScrollContainer:GetMap():TriggerEvent("SetAreaLabel", MAP_AREA_LABEL_TYPE.POI, mapInfo.name);

	-- Now we cheat by acting like we moved our mouse over the relevant zone
	WQT_MapZoneHightlight:SetParent(WorldMapFrame.ScrollContainer.Child);
	WQT_MapZoneHightlight:SetFrameLevel(5);
	local fileDataID, atlasID, texPercentageX, texPercentageY, textureX, textureY, scrollChildX, scrollChildY = C_Map.GetMapHighlightInfoAtPosition(WorldMapFrame.mapID, coords.x, coords.y);
	if (fileDataID and fileDataID > 0) or (atlasID) then
		WQT_MapZoneHightlight.texture:SetTexCoord(0, texPercentageX, 0, texPercentageY);
		local width = WorldMapFrame.ScrollContainer.Child:GetWidth();
		local height = WorldMapFrame.ScrollContainer.Child:GetHeight();
		WQT_MapZoneHightlight.texture:ClearAllPoints();
		if (atlasID) then
			WQT_MapZoneHightlight.texture:SetAtlas(atlasID, true, "TRILINEAR");
			scrollChildX = ((scrollChildX + 0.5*textureX) - 0.5) * width;
			scrollChildY = -((scrollChildY + 0.5*textureY) - 0.5) * height;
			WQT_MapZoneHightlight:SetPoint("CENTER", scrollChildX, scrollChildY);
			WQT_MapZoneHightlight:Show();
		else
			WQT_MapZoneHightlight.texture:SetTexture(fileDataID, nil, nil, "LINEAR");
			textureX = textureX * width;
			textureY = textureY * height;
			scrollChildX = scrollChildX * width;
			scrollChildY = -scrollChildY * height;
			if textureX > 0 and textureY > 0 then
				WQT_MapZoneHightlight.texture:SetWidth(textureX);
				WQT_MapZoneHightlight.texture:SetHeight(textureY);
				WQT_MapZoneHightlight.texture:SetPoint("TOPLEFT", WQT_MapZoneHightlight:GetParent(), "TOPLEFT", scrollChildX, scrollChildY);
				WQT_MapZoneHightlight:Show();
			end
		end
	end
	
	self.resetLabel = true;
end


WQT_QuestDataProvider = {};

local function QuestCreationFunc(pool)
	local questInfo = {["time"] = {}, ["reward"] = {}};
	return questInfo;
end

local function QuestResetFunc(pool, questInfo)
	-- Clean out everthing that isn't a color
	for k, v in pairs(questInfo) do
		if type(v) == "table" and not v.GetRGB then
			QuestResetFunc(pool, v)
		else
			questInfo[k] = nil;
		end
	end
end

function WQT_QuestDataProvider:OnLoad()
	self.pool = CreateObjectPool(QuestCreationFunc, QuestResetFunc);
	self.iterativeList = {};
	self.keyList = {};
end



function WQT_QuestDataProvider:ScanTooltipRewardForPattern(questID, pattern)
	local result;
	
	GameTooltip_AddQuestRewardsToTooltip(WQT_Tooltip, questID);
	for i=2, 6 do
		local lineText = _G["WQT_TooltipTooltipTextLeft"..i]:GetText() or "";
		result = lineText:match(pattern);
		if result then break; end
	end
	
	-- Force hide compare tooltips as they's show up for people with alwaysCompareItems set to 1
	for k, tooltip in ipairs(WQT_Tooltip.shoppingTooltips) do
		tooltip:Hide();
	end
	
	return result;
end

function WQT_QuestDataProvider:GetAPrewardFromText(text)
	local numItems = tonumber(string.match(text:gsub("[%p| ]", ""), '%d+'));
	local int, dec=text:match("(%d+)%.?%,?(%d*)");
	numItems = numItems/(10^dec:len())
	if (_L["IS_AZIAN_CLIENT"]) then
		if (text:find(THIRD_NUMBER)) then
			numItems = numItems * 100000000;
		elseif (text:find(SECOND_NUMBER)) then
			numItems = numItems * 10000;
		end
	else --roman numerals
		if (text:find(THIRD_NUMBER)) then -- Billion just in case
			numItems = numItems * 1000000000;
		elseif (text:find(SECOND_NUMBER)) then -- Million
			numItems = numItems * 1000000;
		end
	end
	
	return numItems;
end

function WQT_QuestDataProvider:SetQuestReward(questInfo)
	local reward = questInfo.reward;
	local _, texture, numItems, quality, rewardType, color, rewardId, itemId, upgradable = nil, nil, 0, 1, 0, WQT_COLOR_MISSING, nil, nil, nil;
	
	if GetNumQuestLogRewards(questInfo.questId) > 0 then
		_, texture, numItems, quality, _, itemId = GetQuestLogRewardInfo(1, questInfo.questId);
		if itemId and (select(6, GetItemInfo(itemId)) == ARMOR )then -- Gear
			local result = self:ScanTooltipRewardForPattern(questInfo.questId, "(%d+%+?)$");
			if result then
				numItems = tonumber(result:match("(%d+)"));
				upgradable = result:match("(%+)") and true;
			end
			rewardType = WQT_REWARDTYPE_ARMOR;
			color = WQT_COLOR_ARMOR;
		elseif itemId and IsArtifactRelicItem(itemId) then
			-- Because getting a link of the itemID only shows the base item
			numItems = tonumber(self:ScanTooltipRewardForPattern(questInfo.questId, "^%+(%d+)"));
			rewardType = WQT_REWARDTYPE_RELIC;	
			color = WQT_COLOR_RELIC;
		else	-- Normal items
			rewardType = WQT_REWARDTYPE_ITEM;
			color = WQT_COLOR_ITEM;
		end
	elseif GetQuestLogRewardHonor(questInfo.questId) > 0 then
		numItems = GetQuestLogRewardHonor(questInfo.questId);
		texture = WQT_HONOR;
		color = WQT_COLOR_HONOR;
		rewardType = WQT_REWARDTYPE_HONOR;
	elseif GetQuestLogRewardMoney(questInfo.questId) > 0 then
		numItems = floor(abs(GetQuestLogRewardMoney(questInfo.questId) / 10000))
		texture = "Interface/ICONS/INV_Misc_Coin_01";
		rewardType = WQT_REWARDTYPE_GOLD;
		color = WQT_COLOR_GOLD;
	elseif GetNumQuestLogRewardCurrencies(questInfo.questId) > 0 then
		_, texture, numItems, rewardId = GetQuestLogRewardCurrencyInfo(GetNumQuestLogRewardCurrencies(questInfo.questId), questInfo.questId)
		-- Because azerite is currency but is treated as an item
		local azuriteID = C_CurrencyInfo.GetAzeriteCurrencyID();
		if rewardId ~= azuriteID then
			local name, _, apTex, _, _, _, _, apQuality = GetCurrencyInfo(rewardId);
			name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(rewardId, numItems, name, texture, apQuality); 
			
			if	C_CurrencyInfo.GetFactionGrantedByCurrency(rewardId) then
				rewardType = WQT_REWARDTYPE_REP;
				quality = 0;
			else
				rewardType = WQT_REWARDTYPE_CURRENCY;
			end
			
			color = WQT_COLOR_CURRENCY;
		else
			-- We want azerite to act like AP
			local name, _, apTex, _, _, _, _, apQuality = GetCurrencyInfo(azuriteID);
			name, texture, _, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(azuriteID, numItems, name, texture, apQuality); 
			
			rewardType = WQT_REWARDTYPE_ARTIFACT;
			color = WQT_COLOR_ARTIFACT;
		end
	elseif haveData and GetQuestLogRewardXP(questInfo.questId) > 0 then
		numItems = GetQuestLogRewardXP(questInfo.questId);
		texture = WQT_EXPERIENCE;
		color = WQT_COLOR_ITEM;
		rewardType = WQT_REWARDTYPE_XP;
	elseif GetNumQuestLogRewards(questInfo.questId) == 0 then
		texture = "";
		color = WQT_COLOR_ITEM;
		rewardType = WQT_REWARDTYPE_NONE;
	end
	
	questInfo.rewardId = itemId; -- deprecated
	questInfo.rewardQuality = quality or 1; -- deprecated
	questInfo.rewardTexture = texture or WQT_QUESTIONMARK; -- deprecated
	questInfo.numItems = numItems or 0; -- deprecated
	questInfo.rewardType = rewardType or 0; -- deprecated
	questInfo.ringColor = color; -- deprecated
	
	questInfo.reward.id = itemId;
	questInfo.reward.quality = quality or 1;
	questInfo.reward.texture = texture or WQT_QUESTIONMARK;
	questInfo.reward.amount = numItems or 0;
	questInfo.reward.type = rewardType or 0;
	questInfo.reward.color = color;
	questInfo.reward.upgradable = upgradable;
end

function WQT_QuestDataProvider:SetSubReward(questInfo) 
	local subType = nil;
	if questInfo.reward.type ~= WQT_REWARDTYPE_CURRENCY and questInfo.reward.type ~= WQT_REWARDTYPE_ARTIFACT and questInfo.reward.type ~= WQT_REWARDTYPE_REP and GetNumQuestLogRewardCurrencies(questInfo.questId) > 0 then
		subType = WQT_REWARDTYPE_CURRENCY;
	elseif questInfo.reward.type ~= WQT_REWARDTYPE_HONOR and GetQuestLogRewardHonor(questInfo.questId) > 0 then
		subType = WQT_REWARDTYPE_HONOR;
	elseif questInfo.reward.type ~= WQT_REWARDTYPE_GOLD and GetQuestLogRewardMoney(questInfo.questId) > 0 then
		subType = WQT_REWARDTYPE_GOLD;
	end
	questInfo.subRewardType = subType; -- deprecated
	
	questInfo.reward.subType = subType;
end

function WQT_QuestDataProvider:FindDuplicate(questId)
	for questInfo, v in self.pool:EnumerateActive() do
		if (questInfo.questId == questId) then
			return questInfo;
		end
	end
	
	return nil;
end

function WQT_QuestDataProvider:AddQuest(qInfo, zoneId, continentId)
	local duplicate = self:FindDuplicate(qInfo.questId);
	-- If there is a duplicate, we don't want to go through all the info again
	if (duplicate) then
		-- Check if the new zone is the 'official' zone, if so, use that one instead
		if (zoneId == C_TaskQuest.GetQuestZoneID(qInfo.questId) ) then
			local zoneInfo = C_Map.GetMapInfo(zoneId);
			duplicate.zoneInfo = zoneInfo;
			duplicate.zoneInfo.mapX = qInfo.x;
			duplicate.zoneInfo.mapY = qInfo.y;
		end
		
		if _debug then
			print("|cFFFFFF00 duplicate: " .. duplicate.title  .. " (" .. duplicate.zoneInfo.name .. ")" .."|r")
		end
		
		return duplicate;
	end

	local haveData = HaveQuestRewardData(qInfo.questId);
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(qInfo.questId);
	
	worldQuestType = not QuestUtils_IsQuestWorldQuest(qInfo.questId) and WQT_TYPE_BONUSOBJECTIVE or worldQuestType;
	local minutes, timeString, color, timeStringShort = GetQuestTimeString(qInfo.questId);
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(qInfo.questId);
	
	local faction = factionId and GetFactionInfoByID(factionId) or _L["NO_FACTION"];
	local questInfo = self.pool:Acquire();
	local expLevel = WQT_ZONE_EXPANSIONS[zoneId] or 0;

	questInfo.id = qInfo.questId; -- deprecated
	questInfo.mapX = questInfo.x; -- deprecated
	questInfo.mapY = questInfo.y; -- deprecated
	questInfo.timeString = timeString; -- deprecated
	questInfo.timeStringShort = timeStringShort; -- deprecated
	questInfo.color = color; -- deprecated
	questInfo.minutes = minutes; -- deprecated
	questInfo.zoneId = zoneId; -- deprecated
	
	questInfo.time.minutes = minutes;
	questInfo.time.full = timeString;
	questInfo.time.short = timeStringShort;
	questInfo.time.color = color;
	
	questInfo.questId = qInfo.questId;
	questInfo.title = title;
	
	questInfo.faction = faction;
	questInfo.factionId = factionId;
	questInfo.type = worldQuestType or -1;
	questInfo.rarity = rarity;
	questInfo.isElite = isElite;
	questInfo.zoneInfo = C_Map.GetMapInfo(zoneId);
	questInfo.zoneInfo.mapX = qInfo.x;
	questInfo.zoneInfo.mapY = qInfo.y;
	questInfo.expantionLevel = expLevel;
	questInfo.tradeskill = tradeskillLineIndex;
	questInfo.numObjectives = qInfo.numObjectives;
	questInfo.passedFilter = true;
	questInfo.isCriteria = WorldMapFrame.overlayFrames[WQT_BOUNDYBOARD_OVERLAYID]:IsWorldQuestCriteriaForSelectedBounty(qInfo.questId);
	
	self:SetQuestReward(questInfo);
	-- If the quest as a second reward e.g. Mark of Honor + Honor points
	self:SetSubReward(questInfo);
	
	-- Filter out invalid quests like "Tracking Quest" in nazmir, to prevent them from triggering the missing data refresh
	local isInvalid = not WorldMap_DoesWorldQuestInfoPassFilters(questInfo) and questInfo.time.minutes == 0 and questInfo.reward.type == WQT_REWARDTYPE_NONE and not questInfo.factionId;
	
	if _debug and isInvalid then
		print("|cFFFF0000 Invalid: " .. questInfo.title  .. " (" .. questInfo.zoneInfo.name .. ")" .."|r")
	end
	
	if not haveData and not isInvalid then
		questInfo.reward.type = WQT_REWARDTYPE_MISSING;
		C_TaskQuest.RequestPreloadRewardData(qInfo.questId);
		return nil;
	end;

	return questInfo;
end

function WQT_QuestDataProvider:AddQuestsInZone(zoneID, continentId)
	local questsById = C_TaskQuest.GetQuestsForPlayerByMapID(zoneID, continentId);
	if not questsById then return false; end
	local missingData = false;
	local quest;
	
	for k, info in ipairs(questsById) do
		if info.mapID == zoneID then
			quest = self:AddQuest(info, zoneID, continentId);
			if not quest then 
				missingData = true;
			end;
		end
	end
	
	return missingData;
end

function WQT_QuestDataProvider:LoadQuestsInZone(zoneId)
	self.pool:ReleaseAll();
	local continentZones = WQT_ZONE_MAPCOORDS[zoneId];
	if not (WorldMapFrame:IsShown() or FlightMapFrame:IsShown()) then return; end
	
	local currentMapInfo = C_Map.GetMapInfo(zoneId);
	local continentId = currentMapInfo.parentMapID; --select(2, GetCurrentMapContinent());
	local missingRewardData = false;
	local questsById, quest;

	if currentMapInfo.mapType == Enum.UIMapType.Continent  and continentZones then
		-- All zones in a continent
		for ID, data in pairs(continentZones) do	
			 local missing = self:AddQuestsInZone(ID, ID);
			 missingRewardData = missing or missingRewardData;
		end
	elseif (currentMapInfo.mapType == Enum.UIMapType.World) then
		for contID, contData in pairs(continentZones) do
			-- every ID is a continent, get every zone on every continent;
			local ContExpLevel = WQT_ZONE_EXPANSIONS[contID];
			if ContExpLevel == GetExpansionLevel() or ContExpLevel == 0 then
				continentZones = WQT_ZONE_MAPCOORDS[contID];
				for zoneID, zoneData  in pairs(continentZones) do
					local missing = self:AddQuestsInZone(zoneID, contID);
					missingRewardData = missing or missingRewardData;
				end
			end
		end
	else
		-- Dalaran being a special snowflake
		missingRewardData = self:AddQuestsInZone(zoneId, continentId);
	end
	
	return missingRewardData;
end

function WQT_QuestDataProvider:GetIterativeList()
	wipe(self.iterativeList);
	
	for questInfo, v in self.pool:EnumerateActive() do
		table.insert(self.iterativeList, questInfo);
	end
	
	return self.iterativeList;
end

function WQT_QuestDataProvider:GetKeyList()
	for id, questInfo in pairs(self.keyList) do
		self.keyList[id] = nil;
	end
	
	for questInfo, v in self.pool:EnumerateActive() do
		self.keyList[questInfo.questId] = questInfo;
	end
	
	return self.keyList;
end

function WQT_QuestDataProvider:GetQuestById(id)
	for questInfo, v in self.pool:EnumerateActive() do
		if questInfo.questId == id then return questInfo; end
	end
	return nil;
end

local _questDataProvider = CreateFromMixins(WQT_QuestDataProvider);


WQT_PinHandlerMixin = {};

local function OnPinRelease(pool, pin)
	pin.questID = nil;
	pin:Hide();
	pin:ClearAllPoints();
end

function WQT_PinHandlerMixin:OnLoad()
	self.pinPool = CreateFramePool("FRAME", WorldMapPOIFrame, "WQT_PinTemplate", OnPinRelease);
end

function WQT_PinHandlerMixin:UpdateFlightMapPins()
	if not FlightMapFrame:IsShown() or WQT.settings.disablePoI then return; end
	local missingRewardData = false;
	local continentId = GetTaxiMapID();
	local missingRewardData = false;
	
	if self.UpdateFlightMap then
		missingRewardData = _questDataProvider:LoadQuestsInZone(continentId);
	end
	WQT.FlightMapList = _questDataProvider:GetKeyList()
	-- If nothing is missing, we can stop updating until we open the map the next time
	if not missingRewardData then
		self.UpdateFlightMap = false
	end
	
	WQT_WorldQuestFrame.pinHandler.pinPool:ReleaseAll();
	local quest = nil;
	for qID, PoI in pairs(WQT.FlightmapPins.activePins) do
		quest =  _questDataProvider:GetQuestById(qID);
		
		if (quest) then
			local pin = self.pinPool:Acquire();
			pin:Update(PoI, quest, qID);
		end
	end
end

function WQT_PinHandlerMixin:UpdateMapPoI()
	WQT_WorldQuestFrame.pinHandler.pinPool:ReleaseAll();
	
	if (WQT.settings.disablePoI) then return; end
	local buttons = WQT_WorldQuestFrame.scrollFrame.buttons;
	local WQProvider = GetMapWQProvider();

	local quest;
	for qID, PoI in pairs(WQProvider.activePins) do
		quest = _questDataProvider:GetQuestById(qID);
		if (quest) then
			local pin = WQT_WorldQuestFrame.pinHandler.pinPool:Acquire();
			pin.questID = qID;
			pin:Update(PoI, quest);
			PoI:SetShown(true);
			if (WQT.settings.filterPoI) then
				PoI:SetShown(quest.passedFilter);
			end
		end
		
	end
end


WQT_PinMixin = {};

function WQT_PinMixin:Update(PoI, quest, flightPinNr)
	local bw = PoI:GetWidth();
	local bh = PoI:GetHeight();
	self:SetParent(PoI);
	self:SetAllPoints();
	self:Show();
	
	if not flightPinNr then
		PoI.info = quest;
	end
	
	PoI.BountyRing:SetAlpha(0);
	PoI.TimeLowFrame:SetAlpha(0);
	PoI.TrackedCheck:SetAlpha(0);

	self.trackedCheck:SetAlpha(IsWorldQuestWatched(quest.questId) and 1 or 0);

	-- Ring stuff
	if (WQT.settings.showPinRing) then
		self.ring:SetVertexColor(quest.reward.color:GetRGB());
	else
		self.ring:SetVertexColor(WQT_COLOR_CURRENCY:GetRGB());
	end
	self.ring:SetAlpha((WQT.settings.showPinReward or WQT.settings.showPinRing) and 1 or 0);
	
	-- Icon stuff
	local showIcon =WQT.settings.showPinReward and (quest.reward.type == WQT_REWARDTYPE_MISSING or quest.reward.texture ~= "")
	self.icon:SetAlpha(showIcon and 1 or 0);
	if quest.reward.type == WQT_REWARDTYPE_MISSING then
		SetPortraitToTexture(self.icon, WQT_QUESTIONMARK);
	else
		SetPortraitToTexture(self.icon, quest.reward.texture);
	end
	
	-- Time
	self.time:SetAlpha((WQT.settings.showPinTime and quest.time.short ~= "")and 1 or 0);
	self.timeBG:SetAlpha((WQT.settings.showPinTime and quest.time.short ~= "") and 0.65 or 0);
	self.time:SetFontObject(flightPinNr and "WQT_NumberFontOutlineBig" or "WQT_NumberFontOutline");
	self.time:SetScale(flightPinNr and 1 or 2.5);
	self.time:SetHeight(flightPinNr and 32 or 16);
	if(WQT.settings.showPinTime) then
		self.time:SetText(quest.time.short)
		self.time:SetVertexColor(quest.time.color.r, quest.time.color.g, quest.time.color.b) 
	end
	
end


WQT_ScrollListMixin = {};

function WQT_ScrollListMixin:OnLoad()
	_questDataProvider:OnLoad();
	self.questList = {};
	self.questListDisplay = {};
	self.scrollBar.trackBG:Hide();
	
	self.scrollBar.doNotHide = true;
	HybridScrollFrame_CreateButtons(self, "WQT_QuestTemplate", 1, 0);
	HybridScrollFrame_Update(self, 200, self:GetHeight());
		
	self.update = function() self:DisplayQuestList(true) end;
end

function WQT_ScrollListMixin:ShowQuestTooltip(button, questInfo)
	WQT_Tooltip:SetOwner(button, "ANCHOR_RIGHT");

	-- In case we somehow don't have data on this quest, even through that makes no sense at this point
	if ( not HaveQuestData(questInfo.questId) ) then
		WQT_Tooltip:SetText(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		WQT_Tooltip.recalculatePadding = true;
		WQT_Tooltip:Show();
		return;
	end
	
	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questInfo.questId);
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(questInfo.questId);
	local color = WORLD_QUEST_QUALITY_COLORS[rarity or 1];
	
	WQT_Tooltip:SetText(title, color.r, color.g, color.b);
	
	if ( factionID ) then
		local factionName = GetFactionInfoByID(factionID);
		if ( factionName ) then
			if (capped) then
				WQT_Tooltip:AddLine(factionName, GRAY_FONT_COLOR:GetRGB());
			else
				WQT_Tooltip:AddLine(factionName);
			end
		end
	end

	-- Add time
	WQT_Tooltip:AddLine(BONUS_OBJECTIVE_TIME_LEFT:format(SecondsToTime(questInfo.time.minutes*60, true, true)), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	

	for objectiveIndex = 1, questInfo.numObjectives do
		local objectiveText, objectiveType, finished = GetQuestObjectiveInfo(questInfo.questId, objectiveIndex, false);
		if ( objectiveText and #objectiveText > 0 ) then
			local color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			WQT_Tooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
		end
	end

	local percent = C_TaskQuest.GetQuestProgressBarInfo(questInfo.questId);
	if ( percent ) then
		GameTooltip_ShowProgressBar(WQT_Tooltip, 0, 100, percent, PERCENTAGE_STRING:format(percent));
	end

	if questInfo.reward.texture ~= "" then
		if questInfo.reward.texture == WQT_QUESTIONMARK then
			WQT_Tooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		else
			GameTooltip_AddQuestRewardsToTooltip(WQT_Tooltip, questInfo.questId);
			
			-- reposition compare frame
			if((questInfo.reward.type == WQT_REWARDTYPE_ARMOR) and WQT_Tooltip.ItemTooltip:IsShown()) then
				if IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems") then
					-- Setup and check total size of both tooltips
					WQT_CompareTooltip1:SetCompareItem(WQT_CompareTooltip2, WQT_Tooltip.ItemTooltip.Tooltip);
					local totalWidth = 0;
					if ( WQT_CompareTooltip1:IsShown()  ) then
							totalWidth = totalWidth + WQT_CompareTooltip1:GetWidth();
					end
					if ( WQT_CompareTooltip2:IsShown()  ) then
							totalWidth = totalWidth + WQT_CompareTooltip2:GetWidth();
					end
					
					-- If there is room to the right, give priority to show compare tooltips to the right of the tooltip
					local priorityRight = WQT_Tooltip.ItemTooltip.Tooltip:GetRight() + totalWidth < GetScreenWidth();
					WQT_Tooltip.ItemTooltip.Tooltip.overrideComparisonAnchorSide  = priorityRight and "right" or "left";
					GameTooltip_ShowCompareItem(WQT_Tooltip.ItemTooltip.Tooltip, WQT_Tooltip.ItemTooltip);

					-- Set higher frame level in case things overlap
					local level = WQT_Tooltip:GetFrameLevel();
					WQT_CompareTooltip1:SetFrameLevel(level +2);
					WQT_CompareTooltip2:SetFrameLevel(level +1);
				end
			end
		end
	end

	-- CanIMogIt functionality
	-- Partial copy of addToTooltip in tooltips.lua
	if (_CIMILoaded and questInfo.reward.id) then
		local _, itemLink = GetItemInfo(questInfo.reward.id);
		local tooltip = WQT_Tooltip.ItemTooltip.Tooltip;
		if (itemLink and CanIMogIt:IsReadyForCalculations(itemLink)) then
			local text;
			text = CanIMogIt:GetTooltipText(itemLink);
			if (text and text ~= "") then
				tooltip:AddDoubleLine(" ", text);
				tooltip:Show();
				tooltip.CIMI_tooltipWritten = true
			end
			
			if CanIMogItOptions["showSourceLocationTooltip"] then
				local sourceTypesText = CanIMogIt:GetSourceLocationText(itemLink);
				if (sourceTypesText and sourceTypesText ~= "") then
					tooltip:AddDoubleLine(" ", sourceTypesText);
					tooltip:Show();
					tooltip.CIMI_tooltipWritten = true
				end
			end
		end
	end
	
	-- Add debug lines
	if _debug then
		AddDebugToTooltip(WQT_Tooltip, questInfo);
	end

	WQT_Tooltip:Show();
	WQT_Tooltip.recalculatePadding = true;
end

function WQT_ScrollListMixin:SetButtonsEnabled(value)
	value = value==nil and true or value;
	local buttons = self.buttons;
	if not buttons then return end;
	
	for k, button in ipairs(buttons) do
		button:SetEnabled(value);
		button:EnableMouse(value);
		button:EnableMouseWheel(value);
	end
	
end

function WQT_ScrollListMixin:ApplySort()
	local list = self.questList;
	local sortOption = ADD:GetSelectedValue(WQT_WorldQuestFrame.sortButton);
	if sortOption == 2 then -- faction
		SortQuestListByFaction(list);
	elseif sortOption == 3 then -- type
		SortQuestListByType(list);
	elseif sortOption == 4 then -- zone
		SortQuestListByZone(list);
	elseif sortOption == 5 then -- name
		SortQuestListByName(list);
	elseif sortOption == 6 then -- reward
		SortQuestListByReward(list)
	else -- time or anything else
		SortQuestList(list)
	end
end

function WQT_ScrollListMixin:UpdateFilterDisplay()
	local isFiltering = WQT:IsFiltering();
	WQT_WorldQuestFrame.filterBar.clearButton:SetShown(isFiltering);
	-- If we're not filtering, we 'hide' everything
	if not isFiltering then
		WQT_WorldQuestFrame.filterBar.text:SetText(""); 
		WQT_WorldQuestFrame.filterBar:SetHeight(0.1);
		return;
	end

	local filterList = "";
	local haveLabels = false;
	-- If we are filtering, 'show' things
	WQT_WorldQuestFrame.filterBar:SetHeight(20);
	-- Emissary has priority
	if (WQT.settings.emissaryOnly) then
		filterList = _L["TYPE_EMISSARY"];	
	else
		for kO, option in pairs(WQT.settings.filters) do
			haveLabels = (WQT_TYPEFLAG_LABELS[kO] ~= nil);
			for kF, flag in pairs(option.flags) do
				if (flag and IsRelevantFilter(kO, kF)) then
					local label = haveLabels and WQT_TYPEFLAG_LABELS[kO][kF] or kF;
					label = type(kF) == "number" and GetFactionInfoByID(kF) or label;
					filterList = filterList == "" and label or string.format("%s, %s", filterList, label);
				end
			end
		end
	end

	WQT_WorldQuestFrame.filterBar.text:SetText(_L["FILTER"]:format(filterList)); 
end

function WQT_ScrollListMixin:UpdateQuestFilters()
	wipe(self.questListDisplay);
	
	for k, questInfo in ipairs(self.questList) do
		if (WorldMap_DoesWorldQuestInfoPassFilters(questInfo)) then
			questInfo.passedFilter = WQT:PassesAllFilters(questInfo)
			if questInfo.passedFilter then
				table.insert(self.questListDisplay, questInfo);
			end
		end
	end
end

function WQT_ScrollListMixin:UpdateQuestList()
	if (not WorldMapFrame:IsShown() or InCombatLockdown()) then return end

	local mapAreaID = WorldMapFrame.mapID;
	
	local missingRewardData = _questDataProvider:LoadQuestsInZone(mapAreaID);
	
	self.questList = _questDataProvider:GetIterativeList();
	
	-- If we were missing reward data, redo this function
	if missingRewardData and not addon.errorTimer then
		addon.errorTimer = C_Timer.NewTimer(0.5, function() addon.errorTimer = nil; self:UpdateQuestList() end);
	end

	self:UpdateQuestFilters();

	self:ApplySort();
	if not InCombatLockdown() then
		self:DisplayQuestList();
	else
		WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
	end
end

function WQT_ScrollListMixin:DisplayQuestList(skipPins)

	if InCombatLockdown() or not WorldMapFrame:IsShown() or not WQT_WorldQuestFrame:IsShown() then return end
	
	local offset = HybridScrollFrame_GetOffset(self);
	local buttons = self.buttons;
	if buttons == nil then return; end
	
	local mapInfo = C_Map.GetMapInfo(WorldMapFrame.mapID);
	local shouldShowZone = mapInfo and (mapInfo.mapType == Enum.UIMapType.Continent or mapInfo.mapType == Enum.UIMapType.World); 

	self:ApplySort();
	self:UpdateQuestFilters();
	local list = self.questListDisplay;
	local r, g, b = 1, 1, 1;
	local mapInfo = C_Map.GetMapInfo(WorldMapFrame.mapID);
	self:GetParent():HideOverlayMessage();
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;
		button:Hide();
		button.reward.amount:Hide();
		button.trackedBorder:Hide();
		button.info = nil;
		button.highlight:Hide();
		
		if ( displayIndex <= #list) then
			button:Update(list[displayIndex], shouldShowZone);
		end
	end
	
	HybridScrollFrame_Update(self, #list * WQT_LISTITTEM_HEIGHT, self:GetHeight());

	if (not skipPins and mapInfo.mapType ~= Enum.UIMapType.Continent) then	
		WQT_WorldQuestFrame.pinHandler:UpdateMapPoI();
	end
	
	self:UpdateFilterDisplay();
	
	if (IsAddOnLoaded("Aurora")) then
		WQT_WorldQuestFrame.Background:SetAlpha(0);
	elseif (#list == 0) then
		WQT_WorldQuestFrame.Background:SetAtlas("NoQuestsBackground", true);
	else
		WQT_WorldQuestFrame.Background:SetAtlas("QuestLogBackground", true);
	end
end

function WQT_ScrollListMixin:ScrollFrameSetEnabled(enabled)
	self:EnableMouse(enabled)
	self:EnableMouse(enabled);
	self:EnableMouseWheel(enabled);
	local buttons = self.buttons;
	for k, button in ipairs(buttons) do
		button:EnableMouse(enabled);
	end
end


WQT_CoreMixin = {}

function WQT_CoreMixin:OnLoad()
	self.pinHandler = CreateFromMixins(WQT_PinHandlerMixin);
	self.pinHandler:OnLoad();

	self.dataprovider = _questDataProvider
	
	self:SetFrameLevel(self:GetParent():GetFrameLevel()+4);
	self.blocker:SetFrameLevel(self:GetFrameLevel()+4);
	
	
	self.filterDropDown = ADD:CreateMenuTemplate("WQT_WorldQuestFrameFilterDropDown", self);
	self.filterDropDown.noResize = true;
	ADD:Initialize(self.filterDropDown, function(self, level) WQT:InitFilter(self, level) end, "MENU");
	self.filterButton.indicator.tooltipTitle = _L["MAP_FILTER_DISABLED_TITLE"];
	self.filterButton.indicator.tooltipSub = _L["MAP_FILTER_DISABLED_INFO"];
	
	self.sortButton = ADD:CreateMenuTemplate("WQT_WorldQuestFrameSortButton", self, nil, "BUTTON");
	self.sortButton:SetSize(93, 22);
	self.sortButton:SetPoint("RIGHT", "WQT_WorldQuestFrameFilterButton", "LEFT", 10, -1);
	self.sortButton:EnableMouse(false);
	self.sortButton:SetScript("OnClick", function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); end);

	ADD:Initialize(self.sortButton, function(self) WQT:InitSort(self, level) end);
	ADD:SetWidth(self.sortButton, 90);
	
	
	
	local frame = ADD:CreateMenuTemplate("WQT_TrackDropDown", self);
	frame:EnableMouse(true);
	ADD:Initialize(frame, function(self, level) WQT:InitTrackDropDown(self, level) end, "MENU");
	

	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");
	self:RegisterEvent("QUEST_TURNED_IN");
	self:RegisterEvent("WORLD_QUEST_COMPLETED_BY_SPELL"); -- Class hall items
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED");
	self:SetScript("OnEvent", function(self, event, ...) if self[event] then self[event](self, ...) else print("WQT missing function for: " .. event) end end)
	
	self.updatePeriod = WQT_REFRESH_DEFAULT;
	self.ticker = C_Timer.NewTicker(WQT_REFRESH_DEFAULT, function() self.scrollFrame:UpdateQuestList(true); end)
	
	SLASH_WQTSLASH1 = '/wqt';
	SLASH_WQTSLASH2 = '/worldquesttab';
	SlashCmdList["WQTSLASH"] = slashcmd
	
	-- Show quest tab when leaving quest details
	hooksecurefunc("QuestMapFrame_ReturnFromQuestDetails", function()
			self:SelectTab(WQT_TabNormal);
		end)
	
	WorldMapFrame:HookScript("OnShow", function() 
			self.scrollFrame:UpdateQuestList();
			self:SelectTab(self.selectedTab); 
		end)
	WorldMapFrame:HookScript("OnHide", function() 
			self.dataprovider.pool:ReleaseAll();
		end)

	QuestScrollFrame:SetScript("OnShow", function() 
			if(self.selectedTab and self.selectedTab:GetID() == 2) then
				self:SelectTab(WQT_TabWorld); 
			else
				self:SelectTab(WQT_TabNormal); 
			end
		end)
		
	hooksecurefunc(WorldMapFrame, "OnMapChanged", function() 
		local mapAreaID = WorldMapFrame.mapID;
	
		if (self.currentMapId ~= mapAreaID) then
			ADD:HideDropDownMenu(1);
			self.scrollFrame:UpdateQuestList();
			self.pinHandler:UpdateMapPoI();
			self.currentMapId = mapAreaID;
		end
	end)
	
	local worldMapFilter;
	
	for k, frame in ipairs(WorldMapFrame.overlayFrames) do
		for name, value in pairs(frame) do
			if (name == "OnSelection") then
				worldMapFilter = frame;
				break;
			end
		end
	end
	if (worldMapFilter) then
		hooksecurefunc(worldMapFilter, "OnSelection", function() 
				self.scrollFrame:UpdateQuestList();
				WQT:UpdateFilterIndicator();
			end);
		self.worldMapFilter = worldMapFilter;
	end
	
	-- Close all our custom dropdowns when opening an Blizzard dropdown
	hooksecurefunc("ToggleDropDownMenu", function()
			ADD:CloseDropDownMenus();
		end);
	
	-- Fix for Blizzard issue with quest details not showing the first time a quest is clicked
	-- And (un)tracking quests on the details frame closes the frame
	local lastQuest = nil;
	QuestMapFrame.DetailsFrame.TrackButton:HookScript("OnClick", function(self) 
			QuestMapFrame_ShowQuestDetails(lastQuest);
		end)
	
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", function(questId)
			self:SelectTab(WQT_TabDetails);
			if QuestMapFrame.DetailsFrame.questID == nil then
				QuestMapFrame.DetailsFrame.questID = questId;
			end
			lastQuest = QuestMapFrame.DetailsFrame.questID;
		end)
	
	-- Auto emisarry when clicking on one of the buttons
	local bountyBoard = WorldMapFrame.overlayFrames[WQT_BOUNDYBOARD_OVERLAYID];
	
	hooksecurefunc(bountyBoard, "OnTabClick", function(tab) 
		WQT.settings.emissaryOnly = true;
		WQT_QuestScrollFrame:DisplayQuestList();
	end)
	
	-- Show hightlight in list when hovering over PoI
	hooksecurefunc("TaskPOI_OnEnter", function(self)
			if (self.questID ~= WQT_QuestScrollFrame.PoIHoverId) then
				WQT_QuestScrollFrame.PoIHoverId = self.questID;
				WQT_QuestScrollFrame:DisplayQuestList(true);
			end
			self.notTracked = not QuestIsWatched(self.questID);
		end)
		
	hooksecurefunc("TaskPOI_OnLeave", function(self)
			WQT_QuestScrollFrame.PoIHoverId = nil;
			WQT_QuestScrollFrame:DisplayQuestList(true);
			self.notTracked = nil;
		end)
		
	-- PVEFrame quest grouping
	LFGListFrame:HookScript("OnHide", function() 
			WQT_GroupSearch:Hide(); 
			WQT_GroupSearch.questId = nil;
			WQT_GroupSearch.title = nil;
		end)

	hooksecurefunc("LFGListSearchPanel_UpdateResults", function(self)
			if (self.searching and not InCombatLockdown()) then
				local searchString = LFGListFrame.SearchPanel.SearchBox:GetText();
				searchString = searchString:lower();
			
				if (WQT_GroupSearch.questId and WQT_GroupSearch.title and not (searchString:find(WQT_GroupSearch.questId) or WQT_GroupSearch.title:lower():find(searchString))) then
					WQT_GroupSearch.Text:SetText(_L["FORMAT_GROUP_TYPO"]:format(WQT_GroupSearch.questId, WQT_GroupSearch.title));
					WQT_GroupSearch:Show();
				else
					WQT_GroupSearch:Hide();
				end
			
				
			end
		end);
		
	LFGListFrame.EntryCreation:HookScript("OnHide", function() 
			if (not InCombatLockdown()) then
				WQT_GroupSearch:Hide();
			end
		end);
		
	LFGListSearchPanelScrollFrame.StartGroupButton:HookScript("OnClick", function() 
			-- If we are creating a group because we couldn't find one, show the info on the create frame
			if InCombatLockdown() then return; end
			local searchString = LFGListFrame.SearchPanel.SearchBox:GetText();
			searchString = searchString:lower();
			if (WQT_GroupSearch.questId and WQT_GroupSearch.title and (searchString:find(WQT_GroupSearch.questId) or WQT_GroupSearch.title:lower():find(searchString))) then
				WQT_GroupSearch.Text:SetText(_L["FORMAT_GROUP_CREATE"]:format(WQT_GroupSearch.questId, WQT_GroupSearch.title));
				WQT_GroupSearch:SetParent(LFGListFrame.EntryCreation.Name);
				WQT_GroupSearch:SetFrameLevel(LFGListFrame.EntryCreation.Name:GetFrameLevel()+5);
				WQT_GroupSearch:ClearAllPoints();
				WQT_GroupSearch:SetPoint("BOTTOMLEFT", LFGListFrame.EntryCreation.Name, "TOPLEFT", -2, 3);
				WQT_GroupSearch:SetPoint("BOTTOMRIGHT", LFGListFrame.EntryCreation.Name, "TOPRIGHT", -2, 3);
				WQT_GroupSearch.downArrow = true;
				WQT_GroupSearch.questId = nil;
				WQT_GroupSearch.title = nil;
				WQT_GroupSearch:Show();
			end
		end)

	
	
	

	-- Shift questlog around to make room for the tabs
	local a,b,c,d =QuestMapFrame:GetPoint(1);
	QuestMapFrame:SetPoint(a,b,c,d,-60);
	QuestScrollFrame:SetPoint("BOTTOMRIGHT",QuestMapFrame, "BOTTOMRIGHT", 0, -5);
	QuestScrollFrame.Background:SetPoint("BOTTOMRIGHT",QuestMapFrame, "BOTTOMRIGHT", 0, -5);
	QuestMapFrame.DetailsFrame:SetPoint("TOPRIGHT", QuestMapFrame, "TOPRIGHT", -26, -8)
	QuestMapFrame.VerticalSeparator:SetHeight(470);
end

function WQT_CoreMixin:ShowHighlightOnMapFilters()
	if (not self.worldMapFilter) then return; end
	WQT_PoISelectIndicator:SetParent(self.worldMapFilter);
	WQT_PoISelectIndicator:ClearAllPoints();
	WQT_PoISelectIndicator:SetPoint("CENTER", self.worldMapFilter, 0, 1);
	WQT_PoISelectIndicator:SetFrameLevel(self.worldMapFilter:GetFrameLevel()+1);
	WQT_PoISelectIndicator:Show();
	WQT_PoISelectIndicator:SetScale(0.40);
end

function WQT_CoreMixin:ShowHighlightOnPin(pin, scale)
	WQT_PoISelectIndicator:SetParent(pin);
	WQT_PoISelectIndicator:ClearAllPoints();
	WQT_PoISelectIndicator:SetPoint("CENTER", pin, 0, -1);
	WQT_PoISelectIndicator:SetFrameLevel(pin:GetFrameLevel()+1);
	WQT_PoISelectIndicator.pinLevel = pin:GetFrameLevel();
	WQT_PoISelectIndicator.pin = pin;
	pin:SetFrameLevel(3000);
	WQT_PoISelectIndicator:Show();
	WQT_PoISelectIndicator:SetScale(scale or 1);
end

function WQT_CoreMixin:FilterClearButtonOnClick()
	ADD:CloseDropDownMenus();
	WQT.settings.emissaryOnly = false;
	for k, v in pairs(WQT.settings.filters) do
		WQT:SetAllFilterTo(k, false);
	end
	self.scrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:ADDON_LOADED(loaded)
	WQT:UpdateFilterIndicator();
	if (loaded == "Blizzard_FlightMap") then
		for k, v in pairs(FlightMapFrame.dataProviders) do 
			if (type(k) == "table") then 
				for k2, v2 in pairs(k) do 
					if (k2 == "activePins") then 
						WQT.FlightmapPins = k;
						break;
					end 
				end 
			end 
		end
		WQT.FlightMapList = {};
		self.pinHandler.UpdateFlightMap = true;
		hooksecurefunc(WQT.FlightmapPins, "OnShow", function() self.pinHandler:UpdateFlightMapPins() end);
		hooksecurefunc(WQT.FlightmapPins, "RefreshAllData", function() self.pinHandler:UpdateFlightMapPins() end);
		
		hooksecurefunc(WQT.FlightmapPins, "OnHide", function() 
				for id in pairs(WQT.FlightMapList) do
					WQT.FlightMapList[id].id = -1;
					WQT.FlightMapList[id] = nil;
				end 
				self.pinHandler.UpdateFlightMap = true;
			end)

		-- find worldmap's world quest data provider
		self:UnregisterEvent("ADDON_LOADED");
	elseif (loaded == "TomTom") then
		_TomTomLoaded = true;
	elseif (loaded == "CanIMogIt") then
		_CIMILoaded = true;
	end
end

function WQT_CoreMixin:PLAYER_REGEN_DISABLED()
	self.scrollFrame:ScrollFrameSetEnabled(false)
	self:ShowOverlayMessage(_L["COMBATLOCK"]);
	ADD:HideDropDownMenu(1);
end

function WQT_CoreMixin:PLAYER_REGEN_ENABLED()
	if self:GetAlpha() == 1 then
		self.scrollFrame:ScrollFrameSetEnabled(true)
	end
	self.scrollFrame:UpdateQuestList();
	self:SelectTab(self.selectedTab);
	WQT:UpdateFilterIndicator();
end

function WQT_CoreMixin:QUEST_TURNED_IN(questId)
	if (QuestUtils_IsQuestWorldQuest(questId)) then
		-- Remove TomTom arrow if tracked
		if (_TomTomLoaded and WQT.settings.useTomTom and TomTom.GetKeyArgs and TomTom.RemoveWaypoint and TomTom.waypoints) then
			-- We need to re-obtain these details, because by this point, the questlist has already updated and our quest no longer exists
			local title = C_TaskQuest.GetQuestInfoByQuestID(questId);
			local mapId = C_TaskQuest.GetQuestZoneID(questId);
			local x, y = C_TaskQuest.GetQuestLocation(questId, mapId)
			local key = TomTom:GetKeyArgs(mapId, x, y, title);
			local wp = TomTom.waypoints[mapId] and TomTom.waypoints[mapId][key];
			if wp then
				TomTom:RemoveWaypoint(wp);
			end
		end

		self.scrollFrame:UpdateQuestList();
	end
end

function WQT_CoreMixin:WORLD_QUEST_COMPLETED_BY_SPELL(...)
	self.scrollFrame:UpdateQuestList();
end

function WQT_CoreMixin:QUEST_WATCH_LIST_CHANGED()
	self.scrollFrame:DisplayQuestList();
end

function WQT_CoreMixin:ShowOverlayMessage(message)
	message = message or "";
	self:SetCombatEnabled(false);
	ShowUIPanel(self.blocker);
	self.blocker.text:SetText(message);
end

function WQT_CoreMixin:HideOverlayMessage()
	self:SetCombatEnabled(true);
	HideUIPanel(self.blocker);
end

function WQT_CoreMixin:SetCombatEnabled(value)
	value = value==nil and true or value;
	
	self:EnableMouse(value);
	self:EnableMouseWheel(value);
	WQT_QuestScrollFrame:EnableMouseWheel(value);
	WQT_QuestScrollFrame:EnableMouse(value);
	WQT_QuestScrollFrameScrollChild:EnableMouseWheel(value);
	WQT_QuestScrollFrameScrollChild:EnableMouse(value);
	WQT_WorldQuestFrameSortButtonButton:EnableMouse(value);
	self.filterButton:EnableMouse(value);
	if value then
		self.filterButton:Enable();
		self.sortButton:Enable();
	else
		self.filterButton:Disable();
		self.sortButton:Disable();
	end
	
	self.scrollFrame:SetButtonsEnabled(value);
		
	self.scrollFrame:EnableMouseWheel(value);
end

function WQT_CoreMixin:SelectTab(tab)
	-- There's a lot of shenanigans going on here with enabling/disabling the mouse due to
	-- Addon restructions of hiding/showing frames during combat
	local id = tab and tab:GetID() or nil;
	if self.selectedTab ~= tab then
		ADD:HideDropDownMenu(1);
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	end
	
	self.selectedTab = tab;
	
	WQT_TabNormal:SetAlpha(1);
	WQT_TabNormal:SetAlpha(1);
	WQT_TabWorld:SetAlpha(1);
	-- because hiding stuff in combat doesn't work
	if not InCombatLockdown() then
		WQT_TabNormal:SetFrameLevel(WQT_TabNormal:GetParent():GetFrameLevel()+(tab == WQT_TabNormal and 2 or 1));
		WQT_TabWorld:SetFrameLevel(WQT_TabWorld:GetParent():GetFrameLevel()+(tab == WQT_TabWorld and 2 or 1));
	 
		self.filterButton:SetFrameLevel(self:GetFrameLevel());
		self.sortButton:SetFrameLevel(self:GetFrameLevel());
		
		self.filterButton:EnableMouse(true);
	end
	
	
	WQT_TabWorld:EnableMouse(true);
	WQT_TabNormal:EnableMouse(true);
	

	if (not QuestScrollFrame.Contents:IsShown() and not QuestMapFrame.DetailsFrame:IsShown()) or id == 1 then
		-- Default questlog
		self:SetAlpha(0);
		WQT_TabNormal.Highlight:Show();
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		ShowUIPanel(QuestScrollFrame);
		
		if not InCombatLockdown() then
			self.blocker:EnableMouse(false);
			HideUIPanel(self.blocker)
			self:SetCombatEnabled(false);
		end
	elseif id == 2 then
		-- WQT
		WQT_TabWorld.Highlight:Show();
		self:SetAlpha(1);
		WQT_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		WQT_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		HideUIPanel(QuestScrollFrame);
		if not InCombatLockdown() then
			self:SetFrameLevel(self:GetParent():GetFrameLevel()+3);
			self:SetCombatEnabled(true);
		end
	elseif id == 3 then
		-- Quest details
		self:SetAlpha(0);
		WQT_TabNormal:SetAlpha(0);
		WQT_TabWorld:SetAlpha(0);
		HideUIPanel(QuestScrollFrame);
		ShowUIPanel(QuestMapFrame.DetailsFrame);
		WQT_TabWorld:EnableMouse(false);
		WQT_TabNormal:EnableMouse(false);
		if not InCombatLockdown() then
			self.blocker:EnableMouse(false);
			WQT_TabWorld:EnableMouse(false);
			WQT_TabNormal:EnableMouse(false);
			self.filterButton:EnableMouse(false);
			self:SetCombatEnabled(false);
		end
	end
end


--------
-- Debug stuff to monitor mem usage
-- Remember to uncomment line template in xml
--------

if _debug then

local l_debug = CreateFrame("frame", addonName .. "Debug", UIParent);
WQT.debug = l_debug;

l_debug.linePool = CreateFramePool("FRAME", l_debug, "WQT_DebugLine");

local function ShowDebugHistory()
	local mem = floor(l_debug.history[#l_debug.history]*100)/100;
	local scale = l_debug:GetScale();
	local current = 0;
	local line = nil;
	l_debug.linePool:ReleaseAll();
	for i=1, #l_debug.history-1, 1 do
		line = l_debug.linePool:Acquire();
		current = l_debug.history[i];
		line:Show();
		line.Fill:SetStartPoint("BOTTOMLEFT", l_debug, (i-1)*2*scale, current/10*scale);
		line.Fill:SetEndPoint("BOTTOMLEFT", l_debug, i*2*scale, l_debug.history[i+1]/10*scale);
		local fade = (current/ 500)-1;
		line.Fill:SetVertexColor(fade, 1-fade, 0);
		line.Fill:Show();
	end
	l_debug.text:SetText(mem)
end

l_debug:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = nil,
	  tileSize = 0, edgeSize = 16,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
	  })
l_debug:SetFrameLevel(5)
l_debug:SetMovable(true)
l_debug:SetPoint("Center", 250, 0)
l_debug:RegisterForDrag("LeftButton")
l_debug:EnableMouse(true);
l_debug:SetScript("OnDragStart", l_debug.StartMoving)
l_debug:SetScript("OnDragStop", l_debug.StopMovingOrSizing)
l_debug:SetWidth(100)
l_debug:SetHeight(100)
l_debug:SetClampedToScreen(true)
l_debug.text = l_debug:CreateFontString(nil, nil, "GameFontWhiteSmall")
l_debug.text:SetPoint("BOTTOMLEFT", 2, 2)
l_debug.text:SetText("0000")
l_debug.text:SetJustifyH("left")
l_debug.time = 0;
l_debug.interval = 0.2;
l_debug.history = {}
l_debug.callCounters = {}

l_debug:SetScript("OnUpdate", function(self,elapsed) 
		self.time = self.time + elapsed;
		if(self.time >= self.interval) then
			self.time = self.time - self.interval;
			UpdateAddOnMemoryUsage();
			table.insert(self.history, GetAddOnMemoryUsage(addonName));
			if(#self.history > 50) then
				table.remove(self.history, 1)
			end
			ShowDebugHistory()

			if(l_debug.showTT) then
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT");
				GameTooltip:SetText("Function calls", nil, nil, nil, nil, true);
				for k, v in pairs(l_debug.callCounters) do
					local t = time();
					local ts = 0;
					local mem = 0;
					local memtot = 0;
					local latest = 0;
					
					for i = #v, 1, -1 do
						ts, mem = v[i]:match("(%d+)|(%d+)");
						ts = tonumber(ts);
						mem = tonumber(mem);
						if (t - ts> 20) then
							table.remove(v, i);
						elseif (ts > latest) then
							latest = ts;
						end
						memtot = memtot + mem;
					end
						
					if #v > 0 then
						local color = (t - latest <=1) and NORMAL_FONT_COLOR or DISABLED_FONT_COLOR;
						GameTooltip:AddDoubleLine(k, #v .. " (" .. floor(memtot/10)/10 .. ")", color.r, color.g, color.b, color.r, color.g, color.b);		
					end
				end
				GameTooltip:Show();
			end
		end
	end)

l_debug:SetScript("OnEnter", function(self,elapsed) 
		l_debug.showTT = true;
		
	end)
	
l_debug:SetScript("OnLeave", function(self,elapsed) 
		l_debug.showTT = false;
		GameTooltip:Hide();
	end)
l_debug:Show()

end