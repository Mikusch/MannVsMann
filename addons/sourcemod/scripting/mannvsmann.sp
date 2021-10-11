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

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <tf2attributes>
#include <memorypatch>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.3.0"

#define SOUND_CREDITS_UPDATED	"ui/credits_updated.wav"

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
}

// ConVars
ConVar mvm_currency_starting;
ConVar mvm_currency_rewards_player_killed;
ConVar mvm_currency_rewards_player_count_bonus;
ConVar mvm_currency_rewards_player_catchup_max;
ConVar mvm_currency_hud_position_x;
ConVar mvm_currency_hud_position_y;
ConVar mvm_upgrades_reset_mode;
ConVar mvm_showhealth;
ConVar mvm_spawn_protection;
ConVar mvm_enable_music;
ConVar mvm_nerf_upgrades;
ConVar mvm_custom_upgrades_file;

// DHooks
TFTeam g_CurrencyPackTeam = TFTeam_Invalid;

// Offsets
int g_OffsetPlayerSharedOuter;
int g_OffsetPlayerReviveMarker;
int g_OffsetCurrencyPackAmount;
int g_OffsetRestoringCheckpoint;

// Other globals
Handle g_HudSync;
Menu g_RespecMenu;
bool g_IsMapRunning;
bool g_ForceMapReset;

#include "mannvsmann/methodmaps.sp"

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
	
	CreateConVar("mvm_version", PLUGIN_VERSION, "Mann vs. Mann plugin version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	mvm_currency_starting = CreateConVar("mvm_currency_starting", "1000", "Number of credits that players get at the start of a match.", _, true, 0.0);
	mvm_currency_rewards_player_killed = CreateConVar("mvm_currency_rewards_player_killed", "15", "The fixed number of credits dropped by players on death.");
	mvm_currency_rewards_player_count_bonus = CreateConVar("mvm_currency_rewards_player_count_bonus", "2.0", "Multiplier to dropped currency that gradually increases up to this value until all player slots have been filled.", _, true, 1.0);
	mvm_currency_rewards_player_catchup_max = CreateConVar("mvm_currency_rewards_player_catchup_max", "1.5", "Maximum currency bonus multiplier for losing teams.", _, true, 1.0);
	mvm_currency_hud_position_x = CreateConVar("mvm_currency_hud_position_x", "-1", "x coordinate of the currency HUD message, from 0 to 1. -1.0 is the center.", _, true, -1.0, true, 1.0);
	mvm_currency_hud_position_y = CreateConVar("mvm_currency_hud_position_y", "0.75", "y coordinate of the currency HUD message, from 0 to 1. -1.0 is the center.", _, true, -1.0, true, 1.0);
	mvm_upgrades_reset_mode = CreateConVar("mvm_upgrades_reset_mode", "0", "How player upgrades and credits are reset after a full round has been played. 0 = Reset upgrades and credits when teams are being switched. 1 = Always reset upgrades and credits. 2 = Never reset upgrades and credits.");
	mvm_showhealth = CreateConVar("mvm_showhealth", "0", "When set to 1, shows a floating health icon over enemy players.");
	mvm_showhealth.AddChangeHook(ConVarChanged_ShowHealth);
	mvm_spawn_protection = CreateConVar("mvm_spawn_protection", "1", "When set to 1, players are granted ubercharge while they leave their spawn.");
	mvm_enable_music = CreateConVar("mvm_enable_music", "1", "When set to 1, Mann vs. Machine music will play at the start and end of a round.");
	mvm_nerf_upgrades = CreateConVar("mvm_nerf_upgrades", "1", "When set to 1, some upgrades will be modified to be fairer in player versus player modes.");
	mvm_custom_upgrades_file = CreateConVar("mvm_custom_upgrades_file", "", "Custom upgrade menu file to use, set to an empty string to use the default.");
	mvm_custom_upgrades_file.AddChangeHook(ConVarChanged_CustomUpgradesFile);
	
	HookEntityOutput("team_round_timer", "On10SecRemain", EntityOutput_OnTimer10SecRemain);
	
	AddNormalSoundHook(NormalSoundHook);
	
	g_HudSync = CreateHudSynchronizer();
	
	CreateTimer(0.1, Timer_UpdateHudText, _, TIMER_REPEAT);
	
	// Create a menu to substitute client-side "Refund Upgrades" button
	g_RespecMenu = new Menu(MenuHandler_UpgradeRespec, MenuAction_Select | MenuAction_DisplayItem);
	g_RespecMenu.SetTitle("%t", "MvM_UpgradeStation");
	g_RespecMenu.AddItem("respec", "MvM_UpgradeRespec");
	
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
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void OnPluginEnd()
{
	Patches_Destroy();
	
	// Remove the populator on plugin end
	int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
	if (populator != -1)
	{
		// NOTE: We use RemoveImmediate here because RemoveEntity deletes it a few frames later.
		// This causes the global populator pointer to be set to NULL despite us having created a new populator already.
		SDKCall_RemoveImmediate(populator);
	}
	
	// Remove all upgrade stations in the map
	int upgradestation = MaxClients + 1;
	while ((upgradestation = FindEntityByClassname(upgradestation, "func_upgradestation")) != -1)
	{
		RemoveEntity(upgradestation);
	}
	
	// Remove all currency packs still in the map
	int currencypack = MaxClients + 1;
	while ((currencypack = FindEntityByClassname(currencypack, "item_currencypack*")) != -1)
	{
		RemoveEntity(currencypack);
	}
	
	// Remove all revive markers still in the map
	int marker = MaxClients + 1;
	while ((marker = FindEntityByClassname(marker, "entity_revive_marker")) != -1)
	{
		RemoveEntity(marker);
	}
}

public void OnMapStart()
{
	g_IsMapRunning = true;
	
	PrecacheSound(SOUND_CREDITS_UPDATED);
	
	DHooks_HookGameRules();
	
	// An info_populator entity is required for a lot of MvM-related stuff (preserved entity)
	CreateEntityByName("info_populator");
	
	// Set custom upgrades file on level init
	char path[PLATFORM_MAX_PATH];
	mvm_custom_upgrades_file.GetString(path, sizeof(path));
	if (path[0] != '\0')
	{
		SetCustomUpgradesFile(path);
	}
	
	if (IsInArenaMode())
	{
		// Arena maps usually don't have resupply lockers, create a dummy upgrade station to initialize the upgrade system
		DispatchSpawn(CreateEntityByName("func_upgradestation"));
	}
	else
	{
		// Create upgrade stations (preserved entity)
		int regenerate = MaxClients + 1;
		while ((regenerate = FindEntityByClassname(regenerate, "func_regenerate")) != -1)
		{
			CreateUpgradeStation(regenerate);
		}
	}
}

public void OnMapEnd()
{
	g_IsMapRunning = false;
}

public void OnClientPutInServer(int client)
{
	SDKHooks_HookClient(client);
	
	MvMPlayer(client).Reset();
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_ForceMapReset = true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);
	
	if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		// CTFPlayer::DropCurrencyPack does not assign a team to the currency pack but CTFGameRules::DistributeCurrencyAmount needs to know it
		if (g_CurrencyPackTeam != TFTeam_Invalid)
		{
			TF2_SetTeam(entity, g_CurrencyPackTeam);
		}
	}
	else if (strcmp(classname, "tf_dropped_weapon") == 0)
	{
		// Do not allow dropped weapons, as you can sell their upgrades for free currency
		RemoveEntity(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntity(entity))
		return;
	
	char classname[32];
	if (GetEntityClassname(entity, classname, sizeof(classname)))
	{
		if (strncmp(classname, "item_currencypack", 17) == 0)
		{
			// Remove the currency value from the world money
			if (!GetEntProp(entity, Prop_Send, "m_bDistributed"))
			{
				TFTeam team = TF2_GetTeam(entity);
				MvMTeam(team).WorldMoney -= GetEntData(entity, g_OffsetCurrencyPackAmount);
			}
		}
		else if (strncmp(classname, "func_upgradestation", 17) == 0)
		{
			// Clears m_bInUpgradeZone on touching clients
			AcceptEntityInput(entity, "DisableAndEndTouch");
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (buttons & IN_ATTACK2)
	{
		char name[32];
		GetClientWeapon(client, name, sizeof(name));
		
		// Resist mediguns can instantly revive in MvM (CWeaponMedigun::SecondaryAttack)
		if (strcmp(name, "tf_weapon_medigun") == 0)
		{
			SetMannVsMachineMode(true);
		}
	}
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (IsMannVsMachineMode())
	{
		ResetMannVsMachineMode();
	}
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char section[32];
	if (kv.GetSectionName(section, sizeof(section)))
	{
		if (strncmp(section, "MvM_", 4, false) == 0)
		{
			// Enable MvM for client commands to be processed in CTFGameRules::ClientCommandKeyValues 
			SetMannVsMachineMode(true);
			
			if (strcmp(section, "MVM_Upgrade") == 0)
			{
				if (kv.JumpToKey("Upgrade"))
				{
					// Stop showing hints once the player has purchased an upgrade
					MvMPlayer(client).HasPurchasedUpgrades = true;
					
					int upgrade = kv.GetNum("Upgrade");
					int count = kv.GetNum("count");
					
					// Tell players how to build the Disposable Sentry
					if (upgrade == 23 && count == 1)
					{
						PrintHintText(client, "%t", "MvM_Upgrade_DisposableSentry");
					}
				}
			}
			else if (strcmp(section, "MvM_UpgradesBegin") == 0)
			{
				g_RespecMenu.Display(client, MENU_TIME_FOREVER);
			}
			else if (strcmp(section, "MvM_UpgradesDone") == 0)
			{
				// Enable upgrade voice lines
				SetVariantString("IsMvMDefender:1");
				AcceptEntityInput(client, "AddContext");
				
				CancelClientMenu(client);
				
				if (IsInArenaMode())
				{
					// NOTE: This is here because the upgrade menu takes a while to fully close clientside.
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
		else if (strcmp(section, "+use_action_slot_item_server") == 0)
		{
			// Required for td_buyback and CTFPowerupBottle::Use to work properly
			SetMannVsMachineMode(true);
			
			if (IsClientObserver(client))
			{
				float nextRespawn = SDKCall_GetNextRespawnWave(GetClientTeam(client), client);
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
				if (powerupBottle != -1 && TF2Attrib_GetByName(powerupBottle, "ubercharge") != Address_Null)
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
	if (IsMannVsMachineMode())
	{
		ResetMannVsMachineMode();
		
		char section[32];
		if (kv.GetSectionName(section, sizeof(section)))
		{
			if (strcmp(section, "MvM_UpgradesDone") == 0)
			{
				SetVariantString("IsMvMDefender");
				AcceptEntityInput(client, "RemoveContext");
			}
		}
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (condition == TFCond_UberchargedCanteen)
	{
		// Prevent players from receiving uber canteens if they are unable to be ubered by mediguns
		if (!SDKCall_CanRecieveMedigunChargeEffect(GetPlayerShared(client), MEDIGUN_CHARGE_INVULN))
		{
			TF2_RemoveCondition(client, condition);
		}
	}
}

public void ConVarChanged_ShowHealth(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (convar.BoolValue)
			{
				TF2Attrib_SetByName(client, "mod see enemy health", 1.0);
			}
			else
			{
				TF2Attrib_RemoveByName(client, "mod see enemy health");
			}
		}
	}
}

public void ConVarChanged_CustomUpgradesFile(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (newValue[0] != '\0')
	{
		SetCustomUpgradesFile(newValue);
	}
	else
	{
		int gamerules = FindEntityByClassname(MaxClients + 1, "tf_gamerules");
		if (gamerules != -1)
		{
			// Reset to the default upgrades file
			SetVariantString("scripts/items/mvm_upgrades.txt");
			AcceptEntityInput(gamerules, "SetCustomUpgradesFile");
		}
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
			if (strcmp(classname, "entity_revive_marker") == 0 || strncmp(classname, "item_currencypack", 17) == 0)
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
	SetHudTextParams(mvm_currency_hud_position_x.FloatValue, mvm_currency_hud_position_y.FloatValue, 0.3, 122, 196, 55, 255, _, 0.0, 0.0, 0.0);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			TFTeam team = TF2_GetClientTeam(client);
			if (team > TFTeam_Spectator)
			{
				// Show players how much currency they have outside of upgrade stations
				if (!GetEntProp(client, Prop_Send, "m_bInUpgradeZone"))
				{
					ShowSyncHudText(client, g_HudSync, "$%d ($%d)", MvMPlayer(client).Currency, MvMTeam(team).WorldMoney);
				}
			}
			else if (team == TFTeam_Spectator)
			{
				// Spectators can see currency stats for each team
				ShowSyncHudText(client, g_HudSync, "BLU: $%d ($%d)\nRED: $%d ($%d)", MvMTeam(TFTeam_Blue).AcquiredCredits, MvMTeam(TFTeam_Blue).WorldMoney, MvMTeam(TFTeam_Red).AcquiredCredits, MvMTeam(TFTeam_Red).WorldMoney);
			}
		}
	}
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
				if (strcmp(info, "respec") == 0)
				{
					MvMPlayer(param1).RemoveAllUpgrades();
					
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
				SetGlobalTransTarget(param1);
				Format(display, sizeof(display), "%t", display);
				return RedrawMenuItem(display);
			}
		}
	}
	
	return 0;
}
