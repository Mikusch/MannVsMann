/**
 * Copyright (C) 2022  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <tf2attributes>
#include <tf2utils>
#include <sourcescramble>
#include <pluginstatemanager>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.19.1"

#define DEFAULT_UPGRADES_FILE	"scripts/items/mvm_upgrades.txt"

#define MARKER_MODEL_TEAMCOLOR	"models/props_mvm/mvm_revive_tombstone_teamcolor.mdl"
#define SOUND_CREDITS_UPDATED	"ui/credits_updated.wav"

#define MVM_BUYBACK_COST_PER_SEC	5

const TFTeam TFTeam_Invalid = view_as<TFTeam>(-1);
const TFTeam TFTeam_Any = view_as<TFTeam>(-2);

enum CurrencyRewards
{
	TF_CURRENCY_KILLED_PLAYER,
	TF_CURRENCY_KILLED_OBJECT,
	TF_CURRENCY_ASSISTED_PLAYER,
	TF_CURRENCY_BONUS_POINTS,
	TF_CURRENCY_CAPTURED_OBJECTIVE,
	TF_CURRENCY_ESCORT_REWARD,
	TF_CURRENCY_PACK_SMALL,
	TF_CURRENCY_PACK_MEDIUM,
	TF_CURRENCY_PACK_LARGE,
	TF_CURRENCY_PACK_CUSTOM,
	TF_CURRENCY_TIME_REWARD,
	TF_CURRENCY_WAVE_COLLECTION_BONUS,
};

enum TFGameType
{
	TF_GAMETYPE_UNDEFINED = 0,
	TF_GAMETYPE_CTF,
	TF_GAMETYPE_CP,
	TF_GAMETYPE_ESCORT,
	TF_GAMETYPE_ARENA,
	TF_GAMETYPE_MVM,
	TF_GAMETYPE_RD,
	TF_GAMETYPE_PASSTIME,
	TF_GAMETYPE_PD,
	
	TF_GAMETYPE_COUNT,
};

enum MedigunChargeType
{
	MEDIGUN_CHARGE_INVALID = -1,
	MEDIGUN_CHARGE_INVULN = 0,
	MEDIGUN_CHARGE_CRITICALBOOST,
	MEDIGUN_CHARGE_MEGAHEAL,
	MEDIGUN_CHARGE_BULLET_RESIST,
	MEDIGUN_CHARGE_BLAST_RESIST,
	MEDIGUN_CHARGE_FIRE_RESIST,
	
	MEDIGUN_NUM_CHARGE_TYPES,
};

enum
{
	LOADOUT_POSITION_INVALID = -1,
	
	// Weapons & Equipment
	LOADOUT_POSITION_PRIMARY = 0,
	LOADOUT_POSITION_SECONDARY,
	LOADOUT_POSITION_MELEE,
	LOADOUT_POSITION_UTILITY,
	LOADOUT_POSITION_BUILDING,
	LOADOUT_POSITION_PDA,
	LOADOUT_POSITION_PDA2,
	
	// Wearables
	LOADOUT_POSITION_HEAD,
	LOADOUT_POSITION_MISC,
	
	// Other
	LOADOUT_POSITION_ACTION,
	
	// More wearables, yay!
	LOADOUT_POSITION_MISC2,
	
	// Taunts
	LOADOUT_POSITION_TAUNT,
	LOADOUT_POSITION_TAUNT2,
	LOADOUT_POSITION_TAUNT3,
	LOADOUT_POSITION_TAUNT4,
	LOADOUT_POSITION_TAUNT5,
	LOADOUT_POSITION_TAUNT6,
	LOADOUT_POSITION_TAUNT7,
	LOADOUT_POSITION_TAUNT8,
	
	CLASS_LOADOUT_POSITION_COUNT,
};

enum
{
	LIFE_ALIVE = 0,		// alive
	LIFE_DYING,			// playing death animation or still falling off of a ledge waiting to hit ground
	LIFE_DEAD,			// dead. lying still.
	LIFE_RESPAWNABLE,
	LIFE_DISCARDBODY,
};

enum 
{
	TF_STATE_ACTIVE = 0,	// Happily running around in the game.
	TF_STATE_WELCOME,		// First entering the server (shows level intro screen).
	TF_STATE_OBSERVER,		// Game observer mode.
	TF_STATE_DYING,			// Player is dying.
	TF_STATE_COUNT
};

enum
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_POI,		// PASSTIME point of interest - game objective, big fight, anything interesting; added in the middle of the enum due to tons of hard-coded "<ROAMING" enum compares
	OBS_MODE_ROAMING,	// free roaming
	
	NUM_OBSERVER_MODES,
};

enum
{
	RESET_MODE_TEAM_SWITCH = 0,
	RESET_MODE_ALWAYS,
	RESET_MODE_NEVER,
};

char g_PlayerClassNames[][] =
{
	"Undefined",
	"Scout",
	"Sniper",
	"Soldier",
	"Demoman",
	"Medic",
	"Heavy",
	"Pyro",
	"Spy",
	"Engineer",
	"Civilian",
	"",
	"Random"
};

// ConVars
ConVar sm_mvm_currency_starting;
ConVar sm_mvm_currency_rewards_player_killed;
ConVar sm_mvm_currency_rewards_objective_captured;
ConVar sm_mvm_currency_rewards_escort;
ConVar sm_mvm_currency_rewards_player_count_base;
ConVar sm_mvm_currency_rewards_player_count_bonus_min;
ConVar sm_mvm_currency_rewards_player_count_bonus_max;
ConVar sm_mvm_currency_rewards_player_catchup_min;
ConVar sm_mvm_currency_rewards_player_catchup_max;
ConVar sm_mvm_currency_rewards_player_modifier_arena;
ConVar sm_mvm_currency_rewards_player_modifier_medieval;
ConVar sm_mvm_upgrades_reset_mode;
ConVar sm_mvm_showhealth;
ConVar sm_mvm_spawn_protection;
ConVar sm_mvm_music_enabled;
ConVar sm_mvm_players_are_minibosses;
ConVar sm_mvm_gas_explode_damage_modifier;
ConVar sm_mvm_explosive_sniper_shot_damage_modifier;
ConVar sm_mvm_medigun_shield_damage_modifier;
ConVar sm_mvm_medigun_shield_damage_drain_rate;
ConVar sm_mvm_radius_spy_scan;
ConVar sm_mvm_revive_markers;
ConVar sm_mvm_broadcast_events;
ConVar sm_mvm_custom_upgrades_file;
ConVar sm_mvm_death_responses;
ConVar sm_mvm_defender_team;
ConVar sm_mvm_powerup_max_charges;
ConVar sm_mvm_backstab_armor_piercing;
ConVar sm_mvm_quickbuild;
ConVar sm_mvm_setup_quickbuild;
ConVar sm_mvm_player_sapper;
ConVar sm_mvm_respec_enabled;
ConVar sm_mvm_resupply_upgrades;

ConVar tf_avoidteammates_pushaway;

// DHooks
TFTeam g_CurrencyPackTeam = TFTeam_Invalid;

// Global entities
int g_PopulationManager = INVALID_ENT_REFERENCE;
int g_ObjectiveResource = INVALID_ENT_REFERENCE;

// Other globals
Handle g_BuybackHudSync;
bool g_ForceMapReset;

#include "mannvsmann/methodmaps.sp"

#include "mannvsmann/commands.sp"
#include "mannvsmann/convars.sp"
#include "mannvsmann/dhooks.sp"
#include "mannvsmann/events.sp"
#include "mannvsmann/offsets.sp"
#include "mannvsmann/sdkhooks.sp"
#include "mannvsmann/sdkcalls.sp"
#include "mannvsmann/util.sp"

public Plugin myinfo = 
{
	name = "Mann vs. Mann",
	author = "Mikusch",
	description = "Regular Team Fortress 2 with Mann vs. Machine upgrades",
	version = PLUGIN_VERSION,
	url = "https://github.com/Mikusch/MannVsMann"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mannvsmann.phrases");
	
	g_BuybackHudSync = CreateHudSynchronizer();
	
	GameData gameconf = new GameData("mannvsmann");
	if (!gameconf)
		SetFailState("Failed to find mannvsmann gamedata");

	PSM_Init("sm_mvm_enabled", gameconf);
	PSM_AddPluginStateChangedHook(OnPluginStateChanged);
	PSM_AddShouldEnableCallback(ShouldEnable);

	PSM_AddMemoryPatchFromConf("CTFPlayerShared::RadiusCurrencyCollectionCheck::AllowAllTeams");

	DHooks_Init();
	Commands_Init();
	ConVars_Init();
	Events_Init();

	Offsets_Init(gameconf);
	SDKCalls_Init(gameconf);

	delete gameconf;
}

public void OnPluginEnd()
{
	if (!PSM_IsEnabled())
		return;
	
	PSM_SetPluginState(false);
}

public void OnConfigsExecuted()
{
	PSM_TogglePluginState();
}

public void OnMapStart()
{
	PrecacheSound(SOUND_CREDITS_UPDATED);
	
	SuperPrecacheModel(MARKER_MODEL_TEAMCOLOR);
	AddFileToDownloadsTable("materials/models/props_mvm/mvm_revive_heavy_blue.vmt");
	AddFileToDownloadsTable("materials/models/props_mvm/mvm_revive_heavy_darker_blue.vmt");
	AddFileToDownloadsTable("materials/models/props_mvm/mvm_revive_heavy_rim_blue.vmt");
	AddFileToDownloadsTable("materials/models/props_mvm/mvm_revive_hologram_blue.vtf");
	AddFileToDownloadsTable("materials/models/props_mvm/mvm_revive_tombstone_base_blue.vmt");
	AddFileToDownloadsTable("materials/models/props_mvm/mvm_revive_tombstone_base_blue.vtf");
	
	if (PSM_IsEnabled())
	{
		DHooks_OnMapStart();

		// Set custom upgrades file and add it to downloads
		char path[PLATFORM_MAX_PATH];
		sm_mvm_custom_upgrades_file.GetString(path, sizeof(path));
		if (path[0])
		{
			SetCustomUpgradesFile(path);
		}
		
		// Enable upgrades
		RunScriptCode(0, -1, -1, "ForceEnableUpgrades(2)");
		
		// Reset all teams
		for (TFTeam team = TFTeam_Unassigned; team <= TFTeam_Blue; team++)
		{
			MvMTeam(team).Reset();
		}
		
		// Create a populator and an upgrade station, which enable some MvM features
		CreateEntityByName("info_populator");
		DispatchSpawn(CreateEntityByName("func_upgradestation"));
	}
}

public void OnClientPutInServer(int client)
{
	if (!PSM_IsEnabled())
		return;
	
	MvMPlayer(client).Reset();
}

public void TF2_OnWaitingForPlayersEnd()
{
	if (!PSM_IsEnabled())
		return;
	
	g_ForceMapReset = true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!PSM_IsEnabled())
		return;
	
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);
	
	if (StrEqual(classname, "info_populator"))
	{
		g_PopulationManager = EntIndexToEntRef(entity);
	}
	else if (StrEqual(classname, "tf_objective_resource"))
	{
		g_ObjectiveResource = EntIndexToEntRef(entity);
	}
	else if (!strncmp(classname, "item_currencypack_", 18))
	{
		// CTFPlayer::DropCurrencyPack does not assign a team to the currency pack but CTFGameRules::DistributeCurrencyAmount needs to know it
		if (g_CurrencyPackTeam != TFTeam_Invalid)
		{
			TF2_SetEntityTeam(entity, g_CurrencyPackTeam);
		}
	}
	else if (StrEqual(classname, "tf_dropped_weapon"))
	{
		// Do not allow dropped weapons, as you can sell their upgrades for free currency
		RemoveEntity(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!PSM_IsEnabled())
		return;
	
	PSM_SDKUnhook(entity);
	
	char classname[32];
	if (GetEntityClassname(entity, classname, sizeof(classname)))
	{
		if (!strncmp(classname, "item_currencypack_", 18))
		{
			// Remove the currency value from the world money
			if (!GetEntProp(entity, Prop_Send, "m_bDistributed"))
			{
				int amount = GetEntData(entity, GetOffset("CCurrencyPack", "m_nAmount"));
				AddWorldMoney(TF2_GetEntityTeam(entity), -amount);
			}
		}
		else if (StrEqual(classname, "func_regenerate"))
		{
			// DisableAndEndTouch doesn't work here because m_hTouchingEntities is empty at this point
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					AcceptEntityInput(entity, "EndTouch", _, client);
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!PSM_IsEnabled())
		return Plugin_Continue;
	
	if (buttons & IN_ATTACK2)
	{
		char name[32];
		GetClientWeapon(client, name, sizeof(name));
		
		// Resist mediguns can instantly revive in MvM (CWeaponMedigun::SecondaryAttack)
		if (StrEqual(name, "tf_weapon_medigun"))
		{
			SetMannVsMachineMode(true);
		}
	}
	
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!PSM_IsEnabled())
		return;
	
	if (IsMannVsMachineMode())
	{
		ResetMannVsMachineMode();
	}
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	if (!PSM_IsEnabled())
		return Plugin_Continue;
	
	char section[32];
	if (kv.GetSectionName(section, sizeof(section)))
	{
		if (!strncmp(section, "MvM_", 4, false))
		{
			if (StrEqual(section, "MVM_Upgrade"))
			{
				// Required for tracking of spent currency
				SetMannVsMachineMode(true);
				
				if (kv.JumpToKey("Upgrade"))
				{
					// Stop showing hints once the player has purchased an upgrade
					MvMPlayer(client).HasPurchasedUpgrades = true;
				}
			}
			else if (StrEqual(section, "MvM_UpgradesBegin"))
			{
				if (sm_mvm_respec_enabled.BoolValue)
				{
					// Create a menu to substitute client-side "Refund Upgrades" button
					Menu menu = new Menu(MenuHandler_UpgradeRespec, MenuAction_Select | MenuAction_DisplayItem | MenuAction_End);
					menu.SetTitle("%T", "MvM_UpgradeStation", client);
					menu.AddItem("respec", "MvM_UpgradeRespec");
					menu.Display(client, MENU_TIME_FOREVER);
				}
			}
			else if (StrEqual(section, "MvM_UpgradesDone"))
			{
				// Do upgrade voice lines
				if (kv.GetNum("num_upgrades", 0) > 0)
				{
					SetVariantString("IsMvMDefender:1");
					AcceptEntityInput(client, "AddContext");
					
					SetVariantString("TLK_MVM_UPGRADE_COMPLETE");
					AcceptEntityInput(client, "SpeakResponseConcept");
					
					AcceptEntityInput(client, "ClearContext");
				}
				
				CancelClientMenu(client);
				
				if (IsInArenaMode())
				{
					/**
					 * The upgrade menu takes a while to fully close client-side.
					 * Attempting to reopen it while it is still closing will keep it open with the old layout.
					 * MvM_UpgradesDone gets fired when the menu has fully closed client-side.
					 */
					
					// We were waiting for this player's menu to close, reopen it right now
					if (MvMPlayer(client).IsClosingUpgradeMenu)
					{
						MvMPlayer(client).IsClosingUpgradeMenu = false;
						
						// Prevent menu staying open by switching classes right before round start
						if (GameRules_GetRoundState() == RoundState_Preround)
						{
							SetEntProp(client, Prop_Send, "m_bInUpgradeZone", true);
						}
					}
					else
					{
						SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
					}
				}
			}
		}
		else if (StrEqual(section, "+use_action_slot_item_server"))
		{
			SetMannVsMachineMode(true);
			
			if (MvMPlayer(client).IsDefender())
			{
				if (IsClientObserver(client))
				{
					float nextRespawn = SDKCall_GetNextRespawnWave(TF2_GetClientTeam(client), client);
					if (nextRespawn)
					{
						float respawnWait = (nextRespawn - GetGameTime());
						if (respawnWait > 1.0)
						{
							// Player buys back into the game
							FakeClientCommand(client, "td_buyback");
						}
					}
				}
				else if (!SDKCall_CanRecieveMedigunChargeEffect(GetPlayerShared(client), MEDIGUN_CHARGE_INVULN))
				{
					// Do not allow players to use ubercharge canteens if they are also unable to receive medigun charge effects
					int powerupBottle = TF2Util_GetPlayerLoadoutEntity(client, LOADOUT_POSITION_ACTION);
					if (powerupBottle != -1 && TF2Attrib_HookValueInt(0, "ubercharge", powerupBottle))
					{
						return Plugin_Handled;
					}
				}
			}
			else
			{
				int powerupBottle = TF2Util_GetPlayerLoadoutEntity(client, LOADOUT_POSITION_ACTION);
				if (powerupBottle != -1 && TF2Attrib_HookValueInt(0, "powerup_charges", powerupBottle))
				{
					PrintCenterText(client, "%t", "MvM_Hint_CannotUseCanteens");
					return Plugin_Handled;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnClientCommandKeyValues_Post(int client, KeyValues kv)
{
	if (!PSM_IsEnabled())
		return;
	
	if (IsMannVsMachineMode())
	{
		ResetMannVsMachineMode();
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (!PSM_IsEnabled())
		return;
	
	if (condition == TFCond_UberchargedCanteen)
	{
		// Prevent players from receiving uber canteens if they are unable to be ubered by mediguns
		if (!SDKCall_CanRecieveMedigunChargeEffect(GetPlayerShared(client), MEDIGUN_CHARGE_INVULN))
		{
			TF2_RemoveCondition(client, condition);
		}
	}
}

static void OnPluginStateChanged(bool enable)
{
	if (enable)
	{
		OnMapStart();
		
		PSM_AddEntityOutputHook("team_round_timer", "On10SecRemain", EntityOutput_OnTimer10SecRemain);
		PSM_AddNormalSoundHook(NormalSoundHook);
		
		CreateTimer(0.1, Timer_UpdateHudText, _, TIMER_REPEAT);
	}
	else
	{
		// Disable upgrades
		SetVariantString("ForceEnableUpgrades(0)");
		AcceptEntityInput(0, "RunScriptCode");
		
		if (!IsMannVsMachineMode())
		{
			// Remove our populator to avoid the server filling up with bots.
			// Using RemoveImmediate is required because RemoveEntity deletes the populator a few frames later.
			// This may cause the global populator pointer to be set to NULL even if a new populator was created.
			SDKCall_RemoveImmediate(g_PopulationManager);
			
			// Remove other entities likely created by the plugin
			RemoveEntitiesByClassname("func_upgradestation");
			RemoveEntitiesByClassname("item_currencypack_*");
			RemoveEntitiesByClassname("entity_revive_marker");
		}
		
		// Clear custom upgrades file
		ClearCustomUpgradesFile();
	}
	
	// Iterate all in-game clients
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (enable)
			{
				OnClientPutInServer(client);
			}
			else
			{
				CancelClientMenu(client);
				
				// Close any open upgrade menu
				SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
				
				// Remove all player upgrades
				TF2Attrib_RemoveAll(client);
				
				// Remove all weapon upgrades
				for (int loadoutSlot = LOADOUT_POSITION_PRIMARY; loadoutSlot < CLASS_LOADOUT_POSITION_COUNT; loadoutSlot++)
				{
					int weapon = TF2Util_GetPlayerLoadoutEntity(client, loadoutSlot);
					if (weapon != -1)
					{
						TF2Attrib_RemoveAll(weapon);
					}
				}
			}
		}
	}
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1)
	{
		if (enable)
		{
			char classname[64];
			if (!GetEntityClassname(entity, classname, sizeof(classname)))
				continue;
			
			OnEntityCreated(entity, classname);
		}
	}
	
	// Restart the game to apply our changes
	if (GameRules_GetRoundState() >= RoundState_Preround && !GameRules_GetProp("m_bInWaitingForPlayers"))
	{
		ServerCommand("mp_restartgame_immediate 1");
	}
}

static bool ShouldEnable()
{
	return !IsMannVsMachineMode();
}

static Action EntityOutput_OnTimer10SecRemain(const char[] output, int caller, int activator, float delay)
{
	if (sm_mvm_music_enabled.BoolValue)
	{
		if (GameRules_GetProp("m_bInSetup"))
		{
			EmitGameSoundToAll("music.mvm_start_mid_wave");
		}
		
		if (IsInArenaMode() && GameRules_GetRoundState() == RoundState_Preround)
		{
			EmitGameSoundToAll("music.mvm_start_wave");
		}
	}
	
	return Plugin_Continue;
}

static Action NormalSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	Action action = Plugin_Continue;
	
	if (IsValidEntity(entity))
	{
		char classname[32];
		if (GetEntityClassname(entity, classname, sizeof(classname)))
		{
			// Make revive markers and money pickups silent for the other team
			if (StrEqual(classname, "entity_revive_marker") || !strncmp(classname, "item_currencypack_", 18))
			{
				for (int i = 0; i < numClients; i++)
				{
					int client = clients[i];
					if (!IsEntityVisibleToPlayer(entity, client))
					{
						for (int j = i; j < numClients - 1; j++)
						{
							clients[j] = clients[j + 1];
						}
						
						numClients--;
						i--;
						action = Plugin_Changed;
					}
				}
			}
		}
	}
	
	return action;
}

static Action Timer_UpdateHudText(Handle timer)
{
	if (!PSM_IsEnabled())
		return Plugin_Stop;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			TFTeam team = TF2_GetClientTeam(client);
			if (team > TFTeam_Spectator)
			{
				// Show respawning players how to buy back into the game
				if (GameRules_GetRoundState() != RoundState_Stalemate && GameRules_GetRoundState() != RoundState_TeamWin && MvMPlayer(client).IsDefender())
				{
					int playerState = GetEntProp(client, Prop_Send, "m_nPlayerState");
					int observerMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
					
					// Observing, but not in freeze cam or death cam
					if ((playerState == TF_STATE_OBSERVER || playerState == TF_STATE_DYING) &&
						(observerMode != OBS_MODE_FREEZECAM && observerMode != OBS_MODE_DEATHCAM))
					{
						float nextRespawn = 0.0;
						
						int resource = GetPlayerResourceEntity();
						if (resource != -1)
						{
							nextRespawn = GetEntPropFloat(resource, Prop_Send, "m_flNextRespawnTime", client);
						}
						else if (TF2_GetPlayerClass(client) != TFClass_Scout)
						{
							nextRespawn = SDKCall_GetNextRespawnWave(team, client);
						}
						
						if (nextRespawn)
						{
							float respawnWait = (nextRespawn - GetGameTime());
							if (respawnWait > 1.0)
							{
								int cost = RoundToFloor(respawnWait) * MVM_BUYBACK_COST_PER_SEC;
								
								SetHudTextParams(-1.0, (1.0 / 3.0), 0.1, 255, 255, 255, 255);
								ShowSyncHudText(client, g_BuybackHudSync, "%t", "MvM_Buyback", cost);
							}
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

static int MenuHandler_UpgradeRespec(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[64];
			if (menu.GetItem(param2, info, sizeof(info)))
			{
				if (StrEqual(info, "respec") && sm_mvm_respec_enabled.BoolValue)
				{
					RunScriptCode(param1, -1, -1, "!self.GrantOrRemoveAllUpgrades(true, true)");
					TF2_RespawnPlayer(param1);
					
					// This should put us at the right currency, given that we've removed item and player upgrade tracking by this point
					int totalAcquiredCurrency = MvMTeam(TF2_GetClientTeam(param1)).AcquiredCredits + MvMPlayer(param1).AcquiredCredits + sm_mvm_currency_starting.IntValue;
					int spentCurrency = SDKCall_GetPlayerCurrencySpent(g_PopulationManager, param1);
					MvMPlayer(param1).Currency = totalAcquiredCurrency - spentCurrency;
					
					if (IsInArenaMode())
					{
						if (GetEntProp(param1, Prop_Send, "m_bInUpgradeZone"))
						{
							MvMPlayer(param1).IsClosingUpgradeMenu = true;
						}
						
						SetEntProp(param1, Prop_Send, "m_bInUpgradeZone", false);
					}
				}
			}
		}
		case MenuAction_DisplayItem:
		{
			char info[64], display[128];
			if (menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display)))
			{
				Format(display, sizeof(display), "%T", display, param1);
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}
