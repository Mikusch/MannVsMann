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

#define TF_MAXPLAYERS	33

#define SOLID_BBOX	2

#define UPGRADE_STATION_MODEL	"models/error.mdl"
#define SOUND_CREDITS_UPDATED	"ui/credits_updated.wav"

const TFTeam TFTeam_Invalid = view_as<TFTeam>(-1);

enum CurrencyRewards
{
	TF_CURRENCY_PACK_SMALL = 6,
	TF_CURRENCY_PACK_MEDIUM,
	TF_CURRENCY_PACK_LARGE,
	TF_CURRENCY_PACK_CUSTOM
}

//ConVars
ConVar mvm_starting_currency;
ConVar mvm_currency_rewards_method;
ConVar mvm_currency_rewards_player_killed;
ConVar mvm_reset_on_round_end;

//DHooks
TFTeam g_CurrencyPackTeam;

//Offsets
int g_OffsetPlayerSharedOuter;
int g_OffsetPlayerReviveMarker;
int g_OffsetCurrencyPackAmount;
int g_OffsetRestoringCheckpoint;

//Other globals
Handle g_HudSync;
bool g_ForceMapReset;

#include "mannvsmann/methodmaps.sp"

#include "mannvsmann/commands.sp"
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
	version = "1.0.0", 
	url = "https://github.com/Mikusch/MannVsMann"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mannvsmann.phrases");
	
	mvm_starting_currency = CreateConVar("mvm_starting_currency", "600", "Number of credits that players get at the start of a match.", _, true, 0.0);
	mvm_currency_rewards_method = CreateConVar("mvm_currency_rewards_method", "1", "When set to 0, drop a fixed currency amount. When set to 1, drop a calculated currency amount.");
	mvm_currency_rewards_player_killed = CreateConVar("mvm_currency_rewards_player_killed", "15", "The fixed number of credits dropped by players on death.");
	mvm_reset_on_round_end = CreateConVar("mvm_reset_on_round_end", "1", "When set to 1, player upgrades and cash will reset when a full round has been played.");
	
	HookEntityOutput("team_round_timer", "On10SecRemain", EntityOutput_OnTimer10SecRemain);
	
	AddNormalSoundHook(NormalSoundHook);
	
	g_HudSync = CreateHudSynchronizer();
	
	Commands_Initialize();
	Events_Initialize();
	
	GameData gamedata = new GameData("mannvsmann");
	if (gamedata != null)
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
	
	//Remove the populator on plugin end
	int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
	if (populator != -1)
	{
		//NOTE: We use RemoveImmediate here because RemoveEntity deletes it a few frames later.
		//This causes the global populator pointer to be set to NULL despite us having created a new populator already.
		SDKCall_RemoveImmediate(populator);
	}
	
	//Remove all upgrade stations in the map
	int upgradestation = MaxClients + 1;
	while ((upgradestation = FindEntityByClassname(upgradestation, "func_upgradestation")) != -1)
	{
		RemoveEntity(upgradestation);
	}
	
	//Remove all currency packs still in the map
	int currencypack = MaxClients + 1;
	while ((currencypack = FindEntityByClassname(currencypack, "item_currencypack*")) != -1)
	{
		RemoveEntity(currencypack);
	}
	
	//Remove all revive markers still in the map
	int marker = MaxClients + 1;
	while ((marker = FindEntityByClassname(marker, "entity_revive_marker")) != -1)
	{
		RemoveEntity(marker);
	}
}

public void OnMapStart()
{
	PrecacheModel(UPGRADE_STATION_MODEL);
	PrecacheSound(SOUND_CREDITS_UPDATED);
	
	DHooks_HookGameRules();
	
	//An info_populator entity is required for a lot of MvM-related stuff (preserved entity)
	CreateEntityByName("info_populator");
	
	//Create upgrade stations (preserved entity)
	int regenerate = MaxClients + 1;
	while ((regenerate = FindEntityByClassname(regenerate, "func_regenerate")) != -1)
	{
		int upgradestation = CreateEntityByName("func_upgradestation");
		if (IsValidEntity(upgradestation) && DispatchSpawn(upgradestation))
		{
			float origin[3], mins[3], maxs[3];
			GetEntPropVector(regenerate, Prop_Send, "m_vecOrigin", origin);
			GetEntPropVector(regenerate, Prop_Send, "m_vecMins", mins);
			GetEntPropVector(regenerate, Prop_Send, "m_vecMaxs", maxs);
			
			SetEntityModel(upgradestation, UPGRADE_STATION_MODEL);
			SetEntPropVector(upgradestation, Prop_Send, "m_vecMins", mins);
			SetEntPropVector(upgradestation, Prop_Send, "m_vecMaxs", maxs);
			SetEntProp(upgradestation, Prop_Send, "m_nSolidType", SOLID_BBOX);
			
			TeleportEntity(upgradestation, origin, NULL_VECTOR, NULL_VECTOR);
			
			ActivateEntity(upgradestation);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHooks_HookClient(client);
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
		//CTFPlayer::DropCurrencyPack does not assign a team to the currency pack but CTFGameRules::DistributeCurrencyAmount needs to know it
		if (g_CurrencyPackTeam != TFTeam_Invalid)
		{
			TF2_SetTeam(entity, g_CurrencyPackTeam);
		}
	}
	else if (strcmp(classname, "tf_dropped_weapon") == 0)
	{
		//Do not allow dropped weapons, as you can sell their upgrades for free currency
		RemoveEntity(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntity(entity))
		return;
	
	char classname[32];
	if (GetEntityClassname(entity, classname, sizeof(classname)) && strncmp(classname, "item_currencypack", 17) == 0)
	{
		//Remove the currency value from the world money
		if (!GetEntProp(entity, Prop_Send, "m_bDistributed"))
		{
			TFTeam team = TF2_GetTeam(entity);
			MvMTeam(team).WorldCredits -= GetEntData(entity, g_OffsetCurrencyPackAmount);
		}
	}
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char section[32];
	if (kv.GetSectionName(section, sizeof(section)))
	{
		if (strncmp(section, "MvM_", 4, false) == 0)
		{
			//Enable MvM for client commands to be processed in CTFGameRules::ClientCommandKeyValues 
			SetMannVsMachineMode(true);
			
			if (strcmp(section, "MVM_Upgrade") == 0)
			{
				if (kv.JumpToKey("Upgrade"))
				{
					int upgrade = kv.GetNum("Upgrade");
					int count = kv.GetNum("count");
					
					//Disposable Sentry
					if (upgrade == 23 && count == 1)
					{
						PrintHintText(client, "%t", "MvM_Upgrade_DisposableSentry");
					}
				}
			}
			else if (strcmp(section, "MvM_UpgradesDone") == 0)
			{
				//Enable upgrade voice lines
				SetVariantString("IsMvMDefender:1");
				AcceptEntityInput(client, "AddContext");
			}
		}
		else if (strcmp(section, "+use_action_slot_item_server") == 0)
		{
			//Required for td_buyback and CTFPowerupBottle::Use to work properly
			SetMannVsMachineMode(true);
			
			if (IsClientObserver(client))
			{
				float nextRespawn = SDKCall_GetNextRespawnWave(GetClientTeam(client), client);
				if (nextRespawn)
				{
					float respawnWait = (nextRespawn - GetGameTime());
					if (respawnWait > 1.0)
					{
						//Player buys back into the game
						FakeClientCommand(client, "td_buyback");
					}
				}
			}
		}
	}
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

public Action EntityOutput_OnTimer10SecRemain(const char[] output, int caller, int activator, float delay)
{
	if (GameRules_GetProp("m_bInSetup"))
	{
		EmitGameSoundToAll("music.mvm_start_mid_wave");
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
			//Make revive markers and money pickups silent for the other team
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
