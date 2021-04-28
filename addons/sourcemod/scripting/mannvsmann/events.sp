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
	HookEvent("teamplay_broadcast_audio", Event_TeamplayBroadcastAudio, EventHookMode_Pre);
	HookEvent("teamplay_round_win", Event_TeamplayRoundWin);
	HookEvent("teamplay_restart_round", Event_TeamplayRestartRound);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_buyback", Event_PlayerBuyback, EventHookMode_Pre);
	HookEvent("player_used_powerup_bottle", Event_PlayerUsedPowerupBottle, EventHookMode_Pre);
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
	if (strcmp(sound, "Game.YourTeamWon") == 0)
	{
		event.SetString("sound", "music.mvm_end_mid_wave");
		return Plugin_Changed;
	}
	else if (strcmp(sound, "Game.YourTeamLost") == 0 || strcmp(sound, "Game.Stalemate") == 0)
	{
		event.SetString("sound", "music.mvm_lost_wave");
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}


public void Event_TeamplayRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	//teamplay_round_start fires too late for us to reset player upgrades so we hook this event instead
	g_ForceMapReset = event.GetBool("full_round");
}

public void Event_TeamplayRestartRound(Event event, const char[] name, bool dontBroadcast)
{
	g_ForceMapReset = true;
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
	//Never do this when gamerules is about to switch EVERY player
	//Refunds are already handled by whatever caused this team switch
	if (SDKCall_ShouldSwitchTeams())
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (team > TFTeam_Spectator)
	{
		MvMPlayer(client).RefundAllUpgrades();
		MvMPlayer(client).Currency = MvMTeam(team).AcquiredCredits + mvm_start_credits.IntValue;
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
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int weaponid = event.GetInt("weaponid");
	int death_flags = event.GetInt("death_flags");
	
	if (IsValidClient(attacker))
	{
		//Create currency pack
		if (victim != attacker && GameRules_GetRoundState() != RoundState_TeamWin)
		{
			//CTFPlayer::DropCurrencyPack does not assign a team to the currency pack but CTFGameRules::DistributeCurrencyAmount needs to know it
			g_CurrencyPackTeam = TF2_GetClientTeam(attacker);
			
			bool forceDistribute = TF2_GetPlayerClass(attacker) == TFClass_Sniper && WeaponID_IsSniperRifleOrBow(weaponid);
			SDKCall_DropCurrencyPack(victim, TF_CURRENCY_PACK_CUSTOM, mvm_credits_player_killed.IntValue, forceDistribute, forceDistribute ? attacker : -1);
		}
		
		if (!(death_flags & TF_DEATHFLAG_DEADRINGER))
		{
			//Create revive marker
			SetEntDataEnt2(victim, g_OffsetPlayerReviveMarker, SDKCall_ReviveMarkerCreate(victim));
		}
	}
}

public Action Event_PlayerBuyback(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	
	//Only broadcast to spectators and our own team
	event.BroadcastDisabled = true;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && (TF2_GetClientTeam(client) == TF2_GetClientTeam(player) || TF2_GetClientTeam(client) == TFTeam_Spectator))
		{
			event.FireToClient(client);
		}
	}
	
	return Plugin_Changed;
}

public Action Event_PlayerUsedPowerupBottle(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	
	//Only broadcast to spectators and our own team
	event.BroadcastDisabled = true;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && (TF2_GetClientTeam(client) == TF2_GetClientTeam(player) || TF2_GetClientTeam(client) == TFTeam_Spectator))
		{
			event.FireToClient(client);
		}
	}
	
	return Plugin_Changed;
}
