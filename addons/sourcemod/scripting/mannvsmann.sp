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

#define TF_MAX_PLAYERS	33
#define TF_TEAM_COUNT	view_as<int>(TFTeam_Blue) + 1

#define TF_TEAM_PVE_INVADERS	TFTeam_Blue
#define TF_TEAM_PVE_DEFENDERS	TFTeam_Red

#define SOLID_BBOX	2
#define EF_NODRAW	0x020

#define UPGRADE_STATION_MODEL	"models/error.mdl"
#define SOUND_CREDITS_UPDATED	"ui/credits_updated.wav"

enum CurrencyRewards
{
	TF_CURRENCY_PACK_SMALL = 6,
	TF_CURRENCY_PACK_MEDIUM,
	TF_CURRENCY_PACK_LARGE,
	TF_CURRENCY_PACK_CUSTOM
}

//ConVars
ConVar mvm_start_credits;
ConVar mvm_max_credits;
ConVar mvm_credits_elimination;

//DHooks
TFTeam g_CurrencyPackTeam;

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
	version = "1.0.0", 
	url = "https://github.com/Mikusch/MannVsMann"
};

public void OnPluginStart()
{
	Events_Initialize();
	
	mvm_start_credits = CreateConVar("mvm_start_credits", "600", "Amount of credits that each player spawns with", _, true, 0.0);
	mvm_max_credits = CreateConVar("mvm_max_credits", "30000", "Maximum amount of credits that can be held by a player");
	mvm_credits_elimination = CreateConVar("mvm_credits_elimination", "15", "Amount of credits dropped when a player is killed through combat");
	
	AddNormalSoundHook(NormalSoundHook);
	
	GameData gamedata = new GameData("mannvsmann");
	if (gamedata != null)
	{
		DHooks_Initialize(gamedata);
		Patches_Initialize(gamedata);
		SDKCalls_Initialize(gamedata);
		
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
	
	//Prevents server crashes on plugin reload
	//Otherwise TF2 will try to dereference a NULL ptr since the destructor for info_populator calls too late
	//
	//This will cause two populators to be created but that's better than server crashes
	CreateTimer(0.1, Timer_CreatePopulator);
}

public void OnPluginEnd()
{
	Patches_Destroy();
	
	//Remove all populators on plugin end
	int populator = MaxClients + 1;
	while ((populator = FindEntityByClassname(populator, "info_populator")) != -1)
	{
		RemoveEntity(populator);
	}
}

public void OnMapStart()
{
	PrecacheModel(UPGRADE_STATION_MODEL);
	PrecacheSound(SOUND_CREDITS_UPDATED);
	
	DHooks_HookGameRules();
	
	//An info_populator entity is required for a lot of MvM-related stuff
	//This entity is preserved across round restarts
	CreateEntityByName("info_populator");
	
	HookEntityOutput("team_round_timer", "On10SecRemain", EntityOutput_OnTimer10SecRemain);
}

public void OnClientPutInServer(int client)
{
	DHooks_HookClient(client);
	SDKHooks_HookClient(client);
}

public void TF2_OnWaitingForPlayersEnd()
{
	for (TFTeam team = TFTeam_Unassigned; team <= TFTeam_Blue; team++)
	{
		MvMTeam(team).AcquiredCredits = 0;
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).Currency = mvm_start_credits.IntValue;
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);
	
	if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		//This is required because CTFPlayer::DropCurrencyPack does not assign a team to currency packs normally,
		//but CTFGameRules::DistributeCurrencyAmount needs to know the team to distribute the money to teammates
		if (g_CurrencyPackTeam != TFTeam_Unassigned)
		{
			TF2_SetTeam(entity, g_CurrencyPackTeam);
		}
	}
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char name[64];
	if (kv.GetSectionName(name, sizeof(name)))
	{
		if (strncmp(name, "MvM_", 4, false) == 0)
		{
			//Enable MvM for client commands to be processed in CTFGameRules::ClientCommandKeyValues 
			GameRules_SetProp("m_bPlayingMannVsMachine", true);
		}
		else if (StrEqual(name, "+use_action_slot_item_server"))
		{
			float nextRespawn = SDKCall_GetNextRespawnWave(GetClientTeam(client), client);
			if (nextRespawn)
			{
				float respawnWait = (nextRespawn - GetGameTime());
				if (respawnWait > 1.0)
				{
					//Allow players to buy back
					GameRules_SetProp("m_bPlayingMannVsMachine", true);
					FakeClientCommand(client, "td_buyback");
				}
			}
		}
	}
}

public void OnClientCommandKeyValues_Post(int client, KeyValues kv)
{
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		GameRules_SetProp("m_bPlayingMannVsMachine", false);
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
		if (GetEntityClassname(entity, classname, sizeof(classname)) && strncmp(classname, "item_currencypack_", 18) == 0)
		{
			//Make money pickups silent for the other team
			for (int i = 0; i < numClients; i++)
			{
				int client = clients[i];
				if (IsClientInGame(client) && TF2_GetClientTeam(client) != TF2_GetTeam(entity))
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
	
	return action;
}

public Action Timer_CreatePopulator(Handle timer)
{
	CreateEntityByName("info_populator");
}
