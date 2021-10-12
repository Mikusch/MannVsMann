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
	HookEvent("teamplay_setup_finished", Event_TeamplaySetupFinished);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("teamplay_restart_round", Event_TeamplayRestartRound);
	HookEvent("teamplay_flag_event", Event_TeamplayFlagEvent);
	HookEvent("teamplay_point_captured", Event_TeamplayPointCaptured);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_changeclass", Event_PlayerChangeClass);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_buyback", Event_PlayerBuyback, EventHookMode_Pre);
	HookEvent("player_bonuspoints", Event_PlayerBonusPoints);
	HookEvent("player_escort_score", Event_PlayerEscortScore);
	HookEvent("player_used_powerup_bottle", Event_PlayerUsedPowerupBottle, EventHookMode_Pre);
	HookEvent("mvm_pickup_currency", Event_PlayerPickupCurrency, EventHookMode_Pre);
}

public Action Event_TeamplayBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	if (mvm_enable_music.BoolValue)
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
			event.SetString("sound", IsInArenaMode() ? "music.mvm_end_wave" : "music.mvm_end_mid_wave");
			return Plugin_Changed;
		}
		else if (strcmp(sound, "Game.YourTeamLost") == 0 || strcmp(sound, "Game.Stalemate") == 0)
		{
			event.SetString("sound", "music.mvm_lost_wave");
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}


public void Event_TeamplayRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	// NOTE: teamplay_round_start fires too late for us to reset player upgrades.
	// Instead we set a bool to reset everything in a CTFGameRules::RoundRespawn virtual hook.
	g_ForceMapReset = event.GetBool("full_round") && (mvm_upgrades_reset_mode.IntValue == 0 && SDKCall_ShouldSwitchTeams() || mvm_upgrades_reset_mode.IntValue == 1);
}

public void Event_TeamplaySetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	int resource = FindEntityByClassname(MaxClients + 1, "tf_objective_resource");
	if (resource != -1)
	{
		// Disallow selling individual upgrades
		SetEntProp(resource, Prop_Send, "m_nMannVsMachineWaveCount", 2);
		
		// Disable faster rage gain on heal
		SetEntProp(resource, Prop_Send, "m_bMannVsMachineBetweenWaves", false);
	}
}

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// Allow players to sell individual upgrades during setup
	int resource = FindEntityByClassname(MaxClients + 1, "tf_objective_resource");
	if (resource != -1)
	{
		if (GameRules_GetProp("m_bInSetup"))
		{
			// Allow selling individual upgrades
			SetEntProp(resource, Prop_Send, "m_nMannVsMachineWaveCount", 1);
			
			// Enable faster rage gain on heal
			SetEntProp(resource, Prop_Send, "m_bMannVsMachineBetweenWaves", true);
		}
		else
		{
			SetEntProp(resource, Prop_Send, "m_nMannVsMachineWaveCount", 2);
			SetEntProp(resource, Prop_Send, "m_bMannVsMachineBetweenWaves", false);
		}
	}
}

public void Event_TeamplayRestartRound(Event event, const char[] name, bool dontBroadcast)
{
	g_ForceMapReset = true;
}

public void Event_TeamplayFlagEvent(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	int eventtype = event.GetInt("eventtype");
	
	if (eventtype == TF_FLAGEVENT_CAPTURED)
	{
		int amount = CalculateCurrencyAmount_ByType(TF_CURRENCY_CAPTURED_OBJECTIVE);
		MvMPlayer(player).AddExperiencePoints(amount);
	}
}

public void Event_TeamplayPointCaptured(Event event, const char[] name, bool dontBroadcast)
{
	char[] cappers = new char[MaxClients];
	event.GetString("cappers", cappers, MaxClients);
	
	for (int i = 0; i < strlen(cappers); i++)
	{
		int player = cappers[i];
		
		int amount = CalculateCurrencyAmount_ByType(TF_CURRENCY_CAPTURED_OBJECTIVE);
		MvMPlayer(player).AddExperiencePoints(amount);
	}
}

public void Event_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			// Forcibly close the upgrade menu when the round starts
			SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
		}
	}
}

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		// Allow medics to revive
		TF2Attrib_SetByName(client, "revive", 1.0);
	}
	
	if (mvm_showhealth.IntValue)
	{
		// Allow players to see enemy health
		TF2Attrib_SetByName(client, "mod see enemy health", 1.0);
	}
	
	if (IsInArenaMode() && GameRules_GetRoundState() == RoundState_Preround && !MvMPlayer(client).IsClosingUpgradeMenu)
	{
		// Automatically open the upgrade menu on spawn
		SetEntProp(client, Prop_Send, "m_bInUpgradeZone", true);
	}
}

public void Event_ObjectDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	int amount = CalculateCurrencyAmount_ByType(TF_CURRENCY_KILLED_OBJECT);
	MvMPlayer(attacker).AddExperiencePoints(amount, false, client);
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	// Never do this for mass-switches as it may lead to buffer overflows
	if (SDKCall_ShouldSwitchTeams() || SDKCall_ShouldScrambleTeams())
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (team > TFTeam_Spectator)
	{
		MvMPlayer(client).RefundExperiencePoints();
		
		SetEntProp(client, Prop_Send, "m_bInUpgradeZone", true);
		MvMPlayer(client).RemoveAllUpgrades();
		SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
		
		int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
		if (populator != -1)
		{
			// This should put us at the right currency, given that we've removed item and player upgrade tracking by this point
			int totalAcquiredCurrency = MvMTeam(team).AcquiredCredits + MvMPlayer(client).AcquiredCredits + mvm_currency_starting.IntValue;
			int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, client);
			MvMPlayer(client).Currency = totalAcquiredCurrency - spentCurrency;
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int inflictor = event.GetInt("inflictor_entindex");
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int weaponid = event.GetInt("weaponid");
	int customkill = event.GetInt("customkill");
	int assister = GetClientOfUserId(event.GetInt("assister"));
	int death_flags = event.GetInt("death_flags");
	bool silent_kill = event.GetBool("silent_kill");
	
	int dropAmount = CalculateCurrencyAmount_ByType(TF_CURRENCY_KILLED_PLAYER);
	if (dropAmount > 0)
	{
		// Enable MvM for CTFGameRules::DistributeCurrencyAmount to properly distribute the currency
		SetMannVsMachineMode(true);
		
		// Give money directly to the enemy team if a trigger killed the player
		char classname[16];
		if (inflictor != -1 && GetEntityClassname(inflictor, classname, sizeof(classname)) && strncmp(classname, "trigger_", 8) == 0)
		{
			g_CurrencyPackTeam = TF2_GetEnemyTeam(TF2_GetClientTeam(victim));
			SDKCall_DistributeCurrencyAmount(dropAmount, -1, true, true);
			g_CurrencyPackTeam = TFTeam_Invalid;
		}
		else if (victim != attacker && IsValidClient(attacker))
		{
			MvMPlayer(attacker).AddExperiencePoints(dropAmount, false, victim);
			
			int moneyMaker = -1;
			if (TF2_GetPlayerClass(attacker) == TFClass_Sniper)
			{
				if (customkill == TF_CUSTOM_BLEEDING || WeaponID_IsSniperRifleOrBow(weaponid))
				{
					moneyMaker = attacker;
					
					if (IsHeadshot(customkill))
					{
						Event headshotEvent = CreateEvent("mvm_sniper_headshot_currency");
						if (headshotEvent)
						{
							headshotEvent.SetInt("userid", GetClientUserId(attacker));
							headshotEvent.SetInt("currency", dropAmount);
							headshotEvent.Fire();
						}
					}
				}
			}
			
			g_CurrencyPackTeam = TF2_GetClientTeam(attacker);
			SDKCall_DropCurrencyPack(victim, TF_CURRENCY_PACK_CUSTOM, dropAmount, _, moneyMaker);
			g_CurrencyPackTeam = TFTeam_Invalid;
		}
		
		ResetMannVsMachineMode();
	}
	
	if (IsValidClient(assister))
	{
		int amount = CalculateCurrencyAmount_ByType(TF_CURRENCY_ASSISTED_PLAYER);
		MvMPlayer(assister).AddExperiencePoints(amount, false, victim);
	}
	
	if (!IsInArenaMode())
	{
		if (!(death_flags & TF_DEATHFLAG_DEADRINGER) && !silent_kill)
		{
			if (GetEntDataEnt2(victim, g_OffsetPlayerReviveMarker) == -1)
			{
				// Create revive marker
				SetEntDataEnt2(victim, g_OffsetPlayerReviveMarker, SDKCall_ReviveMarkerCreate(victim));
			}
		}
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInArenaMode())
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		
		// Tell players how to upgrade if they have not purchased anything yet
		if (!MvMPlayer(client).HasPurchasedUpgrades)
		{
			PrintCenterText(client, "%t", "MvM_Hint_HowToUpgrade");
		}
	}
}

public void Event_PlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	EmitGameSoundToClient(client, "music.mvm_class_select");
	
	MvMPlayer(client).RefundExperiencePoints();
	
	if (IsInArenaMode())
	{
		if (GetEntProp(client, Prop_Send, "m_bInUpgradeZone"))
		{
			MvMPlayer(client).IsClosingUpgradeMenu = true;
		}
		
		SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
	}
}

public Action Event_PlayerBuyback(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	
	// Only broadcast to spectators and our own team
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

public void Event_PlayerBonusPoints(Event event, const char[] name, bool dontBroadcast)
{
	int points = event.GetInt("points");
	int player = event.GetInt("player_entindex");
	int source = event.GetInt("source_entindex");
	
	int amount = CalculateCurrencyAmount_ByType(TF_CURRENCY_BONUS_POINTS);
	MvMPlayer(player).AddExperiencePoints(amount * points, false, source);
}

public void Event_PlayerEscortScore(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	int points = event.GetInt("points");
	
	int amount = CalculateCurrencyAmount_ByType(TF_CURRENCY_ESCORT_REWARD);
	MvMPlayer(player).AddExperiencePoints(amount * points);
}

public Action Event_PlayerUsedPowerupBottle(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	
	// Only broadcast to spectators and our own team
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

public Action Event_PlayerPickupCurrency(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	int currency = event.GetInt("currency");
	
	// This attribute is not implemented in TF2, let's do it ourselves
	Address currency_bonus = TF2Attrib_GetByName(player, "currency bonus");
	if (currency_bonus)
	{
		int newCurrency = RoundToCeil(currency * TF2Attrib_GetValue(currency_bonus));
		int bonusCurrency = newCurrency - currency;
		
		// Give the player the bonus currency
		MvMPlayer(player).Currency += bonusCurrency;
		MvMPlayer(player).AcquiredCredits += bonusCurrency;
		
		event.SetInt("currency", newCurrency);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
