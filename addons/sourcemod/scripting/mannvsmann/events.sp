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

void Events_Initialize()
{
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("teamplay_broadcast_audio", Event_TeamplayBroadcastAudio, EventHookMode_Pre);
	HookEvent("teamplay_game_over", Event_TeamplayGameOver);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_buyback", Event_PlayerBuyback, EventHookMode_Pre);
	HookEvent("player_used_powerup_bottle", Event_PlayerUsedPowerupBottle, EventHookMode_Pre);
}

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//Create an upgrade station
	int resupply = MaxClients + 1;
	while ((resupply = FindEntityByClassname(resupply, "func_regenerate")) != -1)
	{
		int upgrades = CreateEntityByName("func_upgradestation");
		if (IsValidEntity(upgrades) && DispatchSpawn(upgrades))
		{
			float origin[3], mins[3], maxs[3];
			GetEntPropVector(resupply, Prop_Data, "m_vecAbsOrigin", origin);
			GetEntPropVector(resupply, Prop_Data, "m_vecMins", mins);
			GetEntPropVector(resupply, Prop_Data, "m_vecMaxs", maxs);
			
			TeleportEntity(upgrades, origin, NULL_VECTOR, NULL_VECTOR);
			SetEntityModel(upgrades, UPGRADE_STATION_MODEL);
			SetEntPropVector(upgrades, Prop_Send, "m_vecMins", mins);
			SetEntPropVector(upgrades, Prop_Send, "m_vecMaxs", maxs);
			
			SetEntProp(upgrades, Prop_Send, "m_nSolidType", SOLID_BBOX);
			SetEntProp(upgrades, Prop_Send, "m_fEffects", (GetEntProp(upgrades, Prop_Send, "m_fEffects") | EF_NODRAW));
			
			ActivateEntity(upgrades);
		}
	}
	
	bool full_reset = event.GetBool("full_reset");
	if (full_reset && mvm_reset_on_round_start.BoolValue)
	{
		for (TFTeam team = TFTeam_Unassigned; team <= TFTeam_Blue; team++)
		{
			MvMTeam(team).AcquiredCredits = 0;
		}
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientConnected(client))
			{
				if (!IsFakeClient(client))
					MvMPlayer(client).RefundAllUpgrades();
				
				MvMPlayer(client).Currency = MvMTeam(TF2_GetClientTeam(client)).AcquiredCredits + mvm_start_credits.IntValue;
			}
		}
	}
}

public Action Event_TeamplayBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	
	if (strncmp(sound, "Game.TeamRoundStart", 19) == 0)
	{
		event.SetString("sound", "Announcer.MVM_Get_To_Upgrade");
		return Plugin_Changed;
	}
	if (StrEqual(sound, "Game.YourTeamWon"))
	{
		event.SetString("sound", "music.mvm_end_mid_wave");
		return Plugin_Changed;
	}
	else if (StrEqual(sound, "Game.YourTeamLost") || StrEqual(sound, "Game.Stalemate"))
	{
		event.SetString("sound", "music.mvm_lost_wave");
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action Event_TeamplayGameOver(Event event, const char[] name, bool dontBroadcast)
{
	//info_populator causes weird things to happen if it keeps existing past this event
	int populator = MaxClients + 1;
	while ((populator = FindEntityByClassname(populator, "info_populator")) != -1)
	{
		RemoveEntity(populator);
	}
}

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		//Allow medics to revive
		TF2Attrib_SetByName(client, "revive", 1.0);
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers") || GameRules_GetRoundState() == RoundState_Pregame)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (team > TFTeam_Spectator)
	{
		if (IsClientConnected(client))
		{
			if (!IsFakeClient(client))
				MvMPlayer(client).RefundAllUpgrades();
			
			MvMPlayer(client).Currency = MvMTeam(team).AcquiredCredits + mvm_start_credits.IntValue;
		}
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	//MvMPlayer.RefundAllUpgrades may have set this to allow refunding
	SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (GameRules_GetProp("m_bInWaitingForPlayers"))
		return;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int weaponid = event.GetInt("weaponid");
	
	if (attacker == 0)
		return;
	
	if (victim == attacker)
		return;
	
	bool forceDistribute = IsValidClient(attacker) && TF2_GetPlayerClass(attacker) == TFClass_Sniper && WeaponID_IsSniperRifleOrBow(weaponid);
	
	//CCurrencyPack::DistributedBy does not pass the money maker to DistributeCurrencyAmount for some stupid reason
	g_CurrencyPackTeam = TF2_GetClientTeam(attacker);
	
	SDKCall_DropCurrencyPack(victim, TF_CURRENCY_PACK_CUSTOM, mvm_credits_elimination.IntValue, forceDistribute, forceDistribute ? attacker : -1);
	
	//This is probably not needed considering our DistributeCurrencyAmount hook resets this, but better safe than sorry...
	g_CurrencyPackTeam = TFTeam_Unassigned;
}

public Action Event_PlayerBuyback(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	
	//Only broadcast buybacks to the player's own team
	event.BroadcastDisabled = true;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TF2_GetClientTeam(player))
			event.FireToClient(client);
	}
	
	return Plugin_Changed;
}

public Action Event_PlayerUsedPowerupBottle(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	
	//Only broadcast buybacks to the player's own team
	event.BroadcastDisabled = true;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TF2_GetClientTeam(player))
			event.FireToClient(client);
	}
	
	return Plugin_Changed;
}
