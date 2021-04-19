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
#include <dhooks>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

#define SOLID_BBOX	2
#define EF_NODRAW	0x020

#define UPGRADE_STATION_MODEL	"models/error.mdl"

#include "mannvsmann/dhooks.sp"
#include "mannvsmann/events.sp"

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
	Events_Initialize();
	
	GameData gamedata = new GameData("mannvsmann");
	if (gamedata != null)
	{
		DHooks_Initialize(gamedata);
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find mannvsmann gamedata");
	}
}

public void OnMapStart()
{
	PrecacheModel(UPGRADE_STATION_MODEL);
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

public int IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}
