/*
 * Copyright (C) 2021  Mikusch
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

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <tf2attributes>
#include <memorypatch>

#define PLUGIN_VERSION	"1.6.0"

#define DEFAULT_UPGRADES_FILE	"scripts/items/mvm_upgrades.txt"

#define SOUND_CREDITS_UPDATED	"ui/credits_updated.wav"

#define MVM_BUYBACK_COST_PER_SEC	5

const TFTeam TFTeam_Invalid = view_as<TFTeam>(-1);

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
}

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
}

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
}

enum LoadoutPosition
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
}

enum
{
	LIFE_ALIVE = 0,		// alive
	LIFE_DYING,			// playing death animation or still falling off of a ledge waiting to hit ground
	LIFE_DEAD,			// dead. lying still.
	LIFE_RESPAWNABLE,
	LIFE_DISCARDBODY,
}

enum 
{
	TF_STATE_ACTIVE = 0,	// Happily running around in the game.
	TF_STATE_WELCOME,		// First entering the server (shows level intro screen).
	TF_STATE_OBSERVER,		// Game observer mode.
	TF_STATE_DYING,			// Player is dying.
	TF_STATE_COUNT
}

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
}

enum
{
	RESET_MODE_TEAM_SWITCH = 0,
	RESET_MODE_ALWAYS,
	RESET_MODE_NEVER,
}

// ConVars
ConVar mvm_enable;
ConVar mvm_currency_starting;
ConVar mvm_currency_rewards_player_killed;
ConVar mvm_currency_rewards_player_count_bonus;
ConVar mvm_currency_rewards_player_catchup_max;
ConVar mvm_currency_rewards_player_modifier_arena;
ConVar mvm_currency_rewards_player_modifier_medieval;
ConVar mvm_currency_hud_position_x;
ConVar mvm_currency_hud_position_y;
ConVar mvm_upgrades_reset_mode;
ConVar mvm_showhealth;
ConVar mvm_spawn_protection;
ConVar mvm_enable_music;
ConVar mvm_gas_explode_damage_modifier;
ConVar mvm_medigun_shield_damage_modifier;
ConVar mvm_custom_upgrades_file;

// DHooks
TFTeam g_CurrencyPackTeam = TFTeam_Invalid;

// Offsets
int g_OffsetPlayerSharedOuter;
int g_OffsetPlayerReviveMarker;
int g_OffsetCurrencyPackAmount;
int g_OffsetRestoringCheckpoint;

// Other globals
Handle g_CurrencyHudSync;
Handle g_BuybackHudSync;
bool g_IsEnabled;
bool g_IsMapRunning;
bool g_ForceMapReset;

#include "mannvsmann/methodmaps.sp"

#include "mannvsmann/convars.sp"
#include "mannvsmann/dhooks.sp"
#include "mannvsmann/events.sp"
#include "mannvsmann/helpers.sp"
#include "mannvsmann/patches.sp"
#include "mannvsmann/sdkhooks.sp"
#include "mannvsmann/sdkcalls.sp"

public Plugin myinfo = 
{
	name = "Mann vs. Mann", 
	author = "Mikusch", 
	description = "Regular Team Fortress 2 with Mann vs. Machine upgrades", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/Mikusch/MannVsMann"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mannvsmann.phrases");
	
	g_CurrencyHudSync = CreateHudSynchronizer();
	g_BuybackHudSync = CreateHudSynchronizer();
	
	ConVars_Initialize();
	Events_Initialize();
	
	GameData gamedata = new GameData("mannvsmann");
	if (gamedata)
	{
		DHooks_Initialize(gamedata);
		Patches_Initialize(gamedata);
		SDKCalls_Initialize(gamedata);
		
		g_OffsetPlayerSharedOuter = gamedata.GetOffset("CTFPlayerShared::m_pOuter");
		g_OffsetPlayerReviveMarker = gamedata.GetOffset("CTFPlayer::m_hReviveMarker");
		g_OffsetCurrencyPackAmount = gamedata.GetOffset("CCurrencyPack::m_nAmount");
		g_OffsetRestoringCheckpoint = gamedata.GetOffset("CPopulationManager::m_isRestoringCheckpoint");
		
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find mannvsmann gamedata");
	}
}

public void OnPluginEnd()
{
	if (!g_IsEnabled)
	{
		return;
	}
	
	TogglePlugin(false);
}

public void OnMapStart()
{
	g_IsMapRunning = true;
}

public void OnMapEnd()
{
	g_IsMapRunning = false;
}

public void OnConfigsExecuted()
{
	if (g_IsEnabled != mvm_enable.BoolValue)
	{
		TogglePlugin(mvm_enable.BoolValue);
	}
	else if (g_IsEnabled)
	{
		SetupOnMapStart();
	}
}

public void OnClientPutInServer(int client)
{
	if (!g_IsEnabled)
	{
		return;
	}
	
	SDKHooks_HookClient(client);
	MvMPlayer(client).Reset();
}

public void TF2_OnWaitingForPlayersEnd()
{
	if (!g_IsEnabled)
	{
		return;
	}
	
	g_ForceMapReset = true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_IsEnabled)
	{
		return;
	}
	
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);
	
	if (!strncmp(classname, "item_currencypack_", 18))
	{
		// CTFPlayer::DropCurrencyPack does not assign a team to the currency pack but CTFGameRules::DistributeCurrencyAmount needs to know it
		if (g_CurrencyPackTeam != TFTeam_Invalid)
		{
			TF2_SetTeam(entity, g_CurrencyPackTeam);
		}
	}
	else if (!strcmp(classname, "tf_dropped_weapon"))
	{
		// Do not allow dropped weapons, as you can sell their upgrades for free currency
		RemoveEntity(entity);
	}
	
	if (g_IsMapRunning && IsInArenaMode())
	{
		if (!strcmp(classname, "tf_powerup_bottle"))
		{
			// Canteens can't be activated in arena mode, so just remove any powerup bottles
			RemoveEntity(entity);
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!g_IsEnabled)
	{
		return;
	}
	
	if (!IsValidEntity(entity))
	{
		return;
	}
	
	char classname[32];
	if (GetEntityClassname(entity, classname, sizeof(classname)))
	{
		if (!strncmp(classname, "item_currencypack_", 18))
		{
			// Remove the currency value from the world money
			if (!GetEntProp(entity, Prop_Send, "m_bDistributed"))
			{
				TFTeam team = TF2_GetTeam(entity);
				MvMTeam(team).WorldMoney -= GetEntData(entity, g_OffsetCurrencyPackAmount);
			}
		}
		else if (!strcmp(classname, "func_regenerate"))
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
	if (!g_IsEnabled)
	{
		return Plugin_Continue;
	}
	
	if (buttons & IN_ATTACK2)
	{
		char name[32];
		GetClientWeapon(client, name, sizeof(name));
		
		// Resist mediguns can instantly revive in MvM (CWeaponMedigun::SecondaryAttack)
		if (!strcmp(name, "tf_weapon_medigun"))
		{
			SetMannVsMachineMode(true);
		}
	}
	
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!g_IsEnabled)
	{
		return;
	}
	
	if (IsMannVsMachineMode())
	{
		ResetMannVsMachineMode();
	}
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	if (!g_IsEnabled)
	{
		return Plugin_Continue;
	}
	
	char section[32];
	if (kv.GetSectionName(section, sizeof(section)))
	{
		if (!strncmp(section, "MvM_", 4, false))
		{
			// Enable MvM for client commands to be processed in CTFGameRules::ClientCommandKeyValues 
			SetMannVsMachineMode(true);
			
			if (!strcmp(section, "MVM_Upgrade"))
			{
				if (kv.JumpToKey("Upgrade"))
				{
					// Stop showing hints once the player has purchased an upgrade
					MvMPlayer(client).HasPurchasedUpgrades = true;
				}
			}
			else if (!strcmp(section, "MvM_UpgradesBegin"))
			{
				// Create a menu to substitute client-side "Refund Upgrades" button
				Menu menu = new Menu(MenuHandler_UpgradeRespec, MenuAction_Select | MenuAction_DisplayItem | MenuAction_End);
				menu.SetTitle("%T", "MvM_UpgradeStation", client);
				menu.AddItem("respec", "MvM_UpgradeRespec");
				menu.Display(client, MENU_TIME_FOREVER);
			}
			else if (!strcmp(section, "MvM_UpgradesDone"))
			{
				// Enable upgrade voice lines
				SetVariantString("IsMvMDefender:1");
				AcceptEntityInput(client, "AddContext");
				
				CancelClientMenu(client);
				
				// Tell Engineers how to build disposable sentries
				if (TF2_GetPlayerClass(client) == TFClass_Engineer)
				{
					int melee = GetPlayerWeaponSlot(client, 3);
					if (melee != -1 && TF2Attrib_GetByName(melee, "engy disposable sentries"))
					{
						PrintHintText(client, "%t", "MvM_Upgrade_DisposableSentry");
					}
				}
				
				if (IsInArenaMode())
				{
					// This code exists because the upgrade menu takes a while to fully close clientside.
					// Attempting to reopen it while it is still closing will lead to it staying open with the old layout.
					// As a workaround, we check for MvM_UpgradesDone to detect whether the menu has fully closed clientside.
					
					// We were waiting for this player's menu to close, reopen it right away
					if (MvMPlayer(client).IsClosingUpgradeMenu)
					{
						MvMPlayer(client).IsClosingUpgradeMenu = false;
						
						// Prevent edge case where the upgrade menu stays open when switching classes right before round start
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
		else if (!strcmp(section, "+use_action_slot_item_server"))
		{
			// Required for td_buyback and CTFPowerupBottle::Use to work properly
			SetMannVsMachineMode(true);
			
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
				int powerupBottle = SDKCall_GetEquippedWearableForLoadoutSlot(client, view_as<int>(LOADOUT_POSITION_ACTION));
				if (powerupBottle != -1 && TF2Attrib_GetByName(powerupBottle, "ubercharge"))
				{
					ResetMannVsMachineMode();
					return Plugin_Handled;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnClientCommandKeyValues_Post(int client, KeyValues kv)
{
	if (!g_IsEnabled)
	{
		return;
	}
	
	if (IsMannVsMachineMode())
	{
		ResetMannVsMachineMode();
		
		char section[32];
		if (kv.GetSectionName(section, sizeof(section)))
		{
			if (!strcmp(section, "MvM_UpgradesDone"))
			{
				SetVariantString("IsMvMDefender");
				AcceptEntityInput(client, "RemoveContext");
			}
		}
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (!g_IsEnabled)
	{
		return;
	}
	
	if (condition == TFCond_UberchargedCanteen)
	{
		// Prevent players from receiving uber canteens if they are unable to be ubered by mediguns
		if (!SDKCall_CanRecieveMedigunChargeEffect(GetPlayerShared(client), MEDIGUN_CHARGE_INVULN))
		{
			TF2_RemoveCondition(client, condition);
		}
	}
}

void SetupOnMapStart()
{
	PrecacheSound(SOUND_CREDITS_UPDATED);
	
	DHooks_HookAllGameRules();
	
	// Set custom upgrades file and add it to downloads
	char path[PLATFORM_MAX_PATH];
	mvm_custom_upgrades_file.GetString(path, sizeof(path));
	if (path[0] != '\0')
	{
		SetCustomUpgradesFile(path);
	}
	
	// Reset all teams
	for (TFTeam team = TFTeam_Unassigned; team <= TFTeam_Blue; team++)
	{
		MvMTeam(team).Reset();
	}
	
	// Create a populator and an upgrade station, which enable some MvM features
	CreateEntityByName("info_populator");
	DispatchSpawn(CreateEntityByName("func_upgradestation"));
}

void TogglePlugin(bool enable)
{
	g_IsEnabled = enable;
	
	ConVars_Toggle(enable);
	DHooks_Toggle(enable);
	Events_Toggle(enable);
	Patches_Toggle(enable);
	
	if (enable)
	{
		SetupOnMapStart();
		
		AddNormalSoundHook(NormalSoundHook);
		HookEntityOutput("team_round_timer", "On10SecRemain", EntityOutput_OnTimer10SecRemain);
		CreateTimer(0.1, Timer_UpdateHudText, _, TIMER_REPEAT);
	}
	else
	{
		RemoveNormalSoundHook(NormalSoundHook);
		UnhookEntityOutput("team_round_timer", "On10SecRemain", EntityOutput_OnTimer10SecRemain);
		
		// Remove our populator to avoid the server filling up with bots
		int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
		if (populator != -1)
		{
			// Using RemoveImmediate is required because RemoveEntity deletes the populator a few frames later.
			// This may cause the global populator pointer to be set to NULL even if a new populator was created.
			SDKCall_RemoveImmediate(populator);
		}
		
		// Remove other entities likely created by the plugin
		RemoveEntitiesByClassname("func_upgradestation");
		RemoveEntitiesByClassname("item_currencypack_*");
		RemoveEntitiesByClassname("entity_revive_marker");
		
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
				SDKHooks_UnhookClient(client);
				CancelClientMenu(client);
				
				// Close any open upgrade menu
				SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
			}
		}
	}
	
	// Iterate all valid entities
	for (int entity = MaxClients + 1; entity < GetMaxEntities(); entity++)
	{
		if (IsValidEntity(entity))
		{
			char classname[32];
			if (GetEntityClassname(entity, classname, sizeof(classname)))
			{
				if (enable)
				{
					OnEntityCreated(entity, classname);
				}
				else
				{
					SDKHooks_UnhookEntity(entity, classname);
				}
			}
		}
	}
	
	// Restart the game to apply our changes
	if (GameRules_GetRoundState() >= RoundState_Preround && !GameRules_GetProp("m_bInWaitingForPlayers"))
	{
		ServerCommand("mp_restartgame_immediate 1");
	}
}

public Action EntityOutput_OnTimer10SecRemain(const char[] output, int caller, int activator, float delay)
{
	if (mvm_enable_music.BoolValue)
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

public Action NormalSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	Action action = Plugin_Continue;
	
	if (IsValidEntity(entity))
	{
		char classname[32];
		if (GetEntityClassname(entity, classname, sizeof(classname)))
		{
			// Make revive markers and money pickups silent for the other team
			if (!strcmp(classname, "entity_revive_marker") || !strncmp(classname, "item_currencypack_", 18))
			{
				for (int i = 0; i < numClients; i++)
				{
					int client = clients[i];
					if (TF2_GetClientTeam(client) != TF2_GetTeam(entity) && TF2_GetClientTeam(client) != TFTeam_Spectator)
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

public Action Timer_UpdateHudText(Handle timer)
{
	if (!g_IsEnabled)
	{
		return Plugin_Stop;
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			TFTeam team = TF2_GetClientTeam(client);
			if (team > TFTeam_Spectator)
			{
				// Show respawning players how to buy back into the game
				if (GameRules_GetRoundState() != RoundState_Stalemate && GameRules_GetRoundState() != RoundState_TeamWin)
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
				
				// Show players how much currency they have outside of upgrade stations
				if (!GetEntProp(client, Prop_Send, "m_bInUpgradeZone"))
				{
					SetHudTextParams(mvm_currency_hud_position_x.FloatValue, mvm_currency_hud_position_y.FloatValue, 0.1, 122, 196, 55, 255);
					ShowSyncHudText(client, g_CurrencyHudSync, "$%d ($%d)", MvMPlayer(client).Currency, MvMTeam(team).WorldMoney);
				}
			}
			else if (team == TFTeam_Spectator)
			{
				// Spectators can see currency stats for each team
				SetHudTextParams(mvm_currency_hud_position_x.FloatValue, mvm_currency_hud_position_y.FloatValue, 0.1, 122, 196, 55, 255);
				ShowSyncHudText(client, g_CurrencyHudSync, "BLU: $%d ($%d)\nRED: $%d ($%d)", MvMTeam(TFTeam_Blue).AcquiredCredits, MvMTeam(TFTeam_Blue).WorldMoney, MvMTeam(TFTeam_Red).AcquiredCredits, MvMTeam(TFTeam_Red).WorldMoney);
			}
		}
	}
	
	return Plugin_Continue;
}

public int MenuHandler_UpgradeRespec(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[64];
			if (menu.GetItem(param2, info, sizeof(info)))
			{
				if (!strcmp(info, "respec"))
				{
					MvMPlayer(param1).RespecUpgrades();
					
					int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
					if (populator != -1)
					{
						// This should put us at the right currency, given that we've removed item and player upgrade tracking by this point
						int totalAcquiredCurrency = MvMTeam(TF2_GetClientTeam(param1)).AcquiredCredits + MvMPlayer(param1).AcquiredCredits + mvm_currency_starting.IntValue;
						int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, param1);
						MvMPlayer(param1).Currency = totalAcquiredCurrency - spentCurrency;
					}
					
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
