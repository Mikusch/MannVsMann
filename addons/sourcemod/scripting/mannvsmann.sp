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

#pragma semicolon 1
#pragma newdecls required

#define SOLID_BBOX	2
#define EF_NODRAW	0x020

#define UPGRADE_STATION_MODEL	"models/error.mdl"
#define SOUND_CREDITS_UPDATED	"ui/credits_updated.wav"

int g_OffsetCurrencyPackAmount;

ConVar mvm_cash_elimination;

#include "mannvsmann/convars.sp"
#include "mannvsmann/dhooks.sp"
#include "mannvsmann/events.sp"
#include "mannvsmann/helpers.sp"
#include "mannvsmann/sdkhooks.sp"
#include "mannvsmann/sdkcalls.sp"

public Plugin myinfo = 
{
	name = "Mann vs. Mann", 
	author = "Mikusch", 
	description = "Mann vs. Machine but it's PvP", 
	version = "1.0.0", 
	url = "https://github.com/Mikusch/MannVsMann"
};

public void OnPluginStart()
{
	ConVars_Initialize();
	Events_Initialize();
	
	GameData gamedata = new GameData("mannvsmann");
	if (gamedata != null)
	{
		DHooks_Initialize(gamedata);
		SDKCalls_Initialize(gamedata);
		
		g_OffsetCurrencyPackAmount = gamedata.GetOffset("CCurrencyPack::m_nAmount");
		
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

public void OnMapStart()
{
	PrecacheModel(UPGRADE_STATION_MODEL);
	PrecacheSound(SOUND_CREDITS_UPDATED);
	
	HookEntityOutput("team_round_timer", "On10SecRemain", EntityOutput_OnTimer10SecRemain);
}

public void OnClientPutInServer(int client)
{
	DHooks_HookClient(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	DHooks_OnEntityCreated(entity, classname);
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	char name[64];
	if (kv.GetSectionName(name, sizeof(name)) && strncmp(name, "MVM_", 4) == 0)
	{
		//Set m_bPlayingMannVsMachine on true, and let the server run CTFGameRules::ClientCommandKeyValues 
		GameRules_SetProp("m_bPlayingMannVsMachine", true);
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
	EmitGameSoundToAll("music.mvm_start_wave");
}

void DropCurrencyPack(int client, int amount, bool forceDistribute, int moneyMaker)
{
	float origin[3], angles[3];
	WorldSpaceCenter(client, origin);
	GetClientAbsAngles(client, angles);
	
	float velocity[3];
	RandomVector(-1.0, 1.0, velocity);
	velocity[2] = 1.0;
	NormalizeVector(velocity, velocity);
	ScaleVector(velocity, 250.0);
	
	CreateCurrencyPack(origin, angles, velocity, amount, moneyMaker, forceDistribute);
}

void CreateCurrencyPacks(const float origin[3], int remainingMoney = 0, int moneyMaker = -1, bool forceDistribute = false)
{
	while (remainingMoney > 0)
	{
		int amount = 0;
		
		if (remainingMoney >= 100)
			amount = 25;
		else if (remainingMoney >= 40)
			amount = 10;
		else if (remainingMoney >= 5)
			amount = 5;
		else
			amount = remainingMoney;
		
		remainingMoney -= amount;
		
		float angles[3];
		angles[1] = GetRandomFloat(-180.0, 180.0);
		
		float velocity[3];
		RandomVector(-1.0, 1.0, velocity);
		velocity[2] = GetRandomFloat(5.0, 20.0);
		NormalizeVector(velocity, velocity);
		ScaleVector(velocity, 250.0 * GetRandomFloat(1.0, 4.0));
		
		CreateCurrencyPack(origin, angles, velocity, amount, moneyMaker, forceDistribute);
	}
}

void CreateCurrencyPack(const float origin[3], const float angles[3], const float velocity[3], int amount, int moneyMaker, bool forceDistribute)
{
	int currencyPack = CreateEntityByName("item_currencypack_custom");
	if (IsValidEntity(currencyPack))
	{
		DispatchKeyValueVector(currencyPack, "origin", origin);
		DispatchKeyValueVector(currencyPack, "angles", angles);
		
		SetEntData(currencyPack, g_OffsetCurrencyPackAmount, amount);
		
		SetEntProp(currencyPack, Prop_Data, "m_iTeamNum", TF2_GetClientTeam(moneyMaker));
		
		if (forceDistribute)
		{
			DistributedBy(currencyPack, moneyMaker);
		}
		
		if (DispatchSpawn(currencyPack))
		{
			SetEdictFlags(currencyPack, (GetEdictFlags(currencyPack) & ~FL_EDICT_ALWAYS));
			
			SDKCall_DropSingleInstance(currencyPack, velocity, moneyMaker, 0.0, 0.0);
			
			SDKHooks_HookCurrencyPack(currencyPack);
		}
	}
}

void DistributedBy(int currencyPack, int moneyMaker)
{
	DistributeCurrencyAmount(GetEntData(currencyPack, g_OffsetCurrencyPackAmount), moneyMaker);
	SetEntProp(currencyPack, Prop_Send, "m_bDistributed", true);
}

void DistributeCurrencyAmount(int amount, int touchPlayer)
{
	if (IsValidClient(touchPlayer))
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == TF2_GetClientTeam(touchPlayer))
			{
				SetEntProp(client, Prop_Send, "m_nCurrency", GetEntProp(client, Prop_Send, "m_nCurrency") + amount);
				EmitSoundToClient(client, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
			}
		}
	}
}
