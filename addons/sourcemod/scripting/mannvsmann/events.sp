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

#pragma semicolon 1
#pragma newdecls required

#define MAX_EVENT_NAME_LENGTH	32

void Events_Init()
{
	PSM_AddEventHook("teamplay_broadcast_audio", EventHook_TeamplayBroadcastAudio, EventHookMode_Pre);
	PSM_AddEventHook("teamplay_setup_finished", EventHook_TeamplaySetupFinished);
	PSM_AddEventHook("teamplay_round_start", EventHook_TeamplayRoundStart);
	PSM_AddEventHook("teamplay_restart_round", EventHook_TeamplayRestartRound);
	PSM_AddEventHook("arena_round_start", EventHook_ArenaRoundStart);
	PSM_AddEventHook("player_death", EventHook_PlayerDeath);
	PSM_AddEventHook("player_spawn", EventHook_PlayerSpawn);
	PSM_AddEventHook("post_inventory_application", EventHook_PostInventoryApplication);
	PSM_AddEventHook("player_changeclass", EventHook_PlayerChangeClass);
	PSM_AddEventHook("player_team", EventHook_PlayerTeam);
	PSM_AddEventHook("player_buyback", EventHook_PlayerBuyback, EventHookMode_Pre);
	PSM_AddEventHook("player_used_powerup_bottle", EventHook_PlayerUsedPowerupBottle, EventHookMode_Pre);
	PSM_AddEventHook("mvm_pickup_currency", EventHook_PlayerPickupCurrency, EventHookMode_Pre);
}

static Action EventHook_TeamplayBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	
	if (GetDefenderTeam() == TFTeam_Any || GetDefenderTeam() == team)
	{
		if (!strncmp(sound, "Game.TeamRoundStart", 19))
		{
			event.SetString("sound", "Announcer.MVM_Get_To_Upgrade");
			return Plugin_Changed;
		}
	}
	
	if (sm_mvm_music_enabled.BoolValue)
	{
		if (StrEqual(sound, "Game.YourTeamWon"))
		{
			event.SetString("sound", IsInArenaMode() ? "music.mvm_end_wave" : "music.mvm_end_mid_wave");
			return Plugin_Changed;
		}
		else if (StrEqual(sound, "Game.YourTeamLost") || StrEqual(sound, "Game.Stalemate"))
		{
			event.SetString("sound", "music.mvm_lost_wave");
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

static void EventHook_TeamplaySetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	int resource = FindEntityByClassname(-1, "tf_objective_resource");
	if (resource != -1)
	{
		// Disallow selling individual upgrades
		SetEntProp(resource, Prop_Send, "m_nMannVsMachineWaveCount", 2);
		
		// Disable faster rage gain on heal
		SetEntProp(resource, Prop_Send, "m_bMannVsMachineBetweenWaves", false);
	}
}

static void EventHook_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// Allow players to sell individual upgrades during setup
	int resource = FindEntityByClassname(-1, "tf_objective_resource");
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

static void EventHook_TeamplayRestartRound(Event event, const char[] name, bool dontBroadcast)
{
	g_ForceMapReset = true;
}

static void EventHook_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && MvMPlayer(client).IsDefender())
		{
			// Forcibly close the upgrade menu when the round starts
			SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
		}
	}
}

static void EventHook_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (team > TFTeam_Spectator)
	{
		SetVariantString("!self.GrantOrRemoveAllUpgrades(true, true)");
		AcceptEntityInput(client, "RunScriptCode");
		
		int populator = FindEntityByClassname(-1, "info_populator");
		if (populator != -1)
		{
			// This should put us at the right currency, given that we've removed item and player upgrade tracking by this point
			int totalAcquiredCurrency = MvMTeam(team).AcquiredCredits + MvMPlayer(client).AcquiredCredits + sm_mvm_currency_starting.IntValue;
			int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, client);
			MvMPlayer(client).Currency = totalAcquiredCurrency - spentCurrency;
		}
	}
}

static void EventHook_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int weaponid = event.GetInt("weaponid");
	int customkill = event.GetInt("customkill");
	int death_flags = event.GetInt("death_flags");
	bool silent_kill = event.GetBool("silent_kill");
	
	if (GetDefenderTeam() == TFTeam_Any || TF2_GetClientTeam(victim) != GetDefenderTeam())
	{
		int dropAmount = CalculateCurrencyAmount(attacker);
		if (dropAmount)
		{
			// Enable MvM for CTFGameRules::DistributeCurrencyAmount to properly distribute the currency
			SetMannVsMachineMode(true);
			
			if (victim != attacker && IsValidClient(attacker))
			{
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
	}
	
	if (MvMPlayer(victim).IsDefender())
	{
		if (!(death_flags & TF_DEATHFLAG_DEADRINGER))
		{
			// Play death sound only to the victim, otherwise it gets very annoying after a while
			EmitGameSoundToClient(victim, "MVM.PlayerDied");
		}
		
		if (!IsInArenaMode() && sm_mvm_revive_markers.BoolValue)
		{
			if (!(death_flags & TF_DEATHFLAG_DEADRINGER) && !silent_kill)
			{
				if (GetEntDataEnt2(victim, GetOffset("CTFPlayer", "m_hReviveMarker")) == -1)
				{
					// Create revive marker
					int marker = SDKCall_ReviveMarkerCreate(victim);
					SetEntDataEnt2(victim, GetOffset("CTFPlayer", "m_hReviveMarker"), marker);
					
					SetEntProp(marker, Prop_Send, "m_nModelIndex", PrecacheModel(MARKER_MODEL_TEAMCOLOR));
					
					int skin = GetEntProp(marker, Prop_Send, "m_iTeamNum") - 2;
					DispatchKeyValueInt(marker, "skin", skin);
				}
			}
		}
		
		if (sm_mvm_death_responses.BoolValue)
		{
			// The victim is still considered alive here, so we do voice line stuff one frame later
			RequestFrame(RequestFrameCallback_SpeakDeathResponses, GetClientUserId(victim));
		}
	}
}

static void EventHook_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	MvMPlayer(client).SetMaxPowerupCharges(sm_mvm_powerup_max_charges.IntValue);
}

static void EventHook_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (MvMPlayer(client).IsDefender())
	{
		if (IsInArenaMode())
		{
			if (GameRules_GetRoundState() == RoundState_Preround && !MvMPlayer(client).IsClosingUpgradeMenu)
			{
				// Automatically open the upgrade menu on spawn
				SetEntProp(client, Prop_Send, "m_bInUpgradeZone", true);
			}
		}
		else if (sm_mvm_resupply_upgrades.BoolValue)
		{
			// Tell players how to upgrade if they have not purchased anything yet
			if (!MvMPlayer(client).HasPurchasedUpgrades)
			{
				PrintCenterText(client, "%t", "MvM_Hint_HowToUpgrade");
			}
		}
	}
	
	if (sm_mvm_showhealth.BoolValue)
	{
		// Allow players to see enemy health
		TF2Attrib_SetByName(client, "mod see enemy health", 1.0);
	}
}

static void EventHook_PlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	EmitGameSoundToClient(client, "music.mvm_class_select");
	
	if (IsInArenaMode() && MvMPlayer(client).IsDefender())
	{
		if (GetEntProp(client, Prop_Send, "m_bInUpgradeZone"))
		{
			MvMPlayer(client).IsClosingUpgradeMenu = true;
		}
		
		SetEntProp(client, Prop_Send, "m_bInUpgradeZone", false);
	}
}

static Action EventHook_PlayerBuyback(Event event, const char[] name, bool dontBroadcast)
{
	if (sm_mvm_broadcast_events.BoolValue)
	{
		return Plugin_Continue;
	}
	
	int player = event.GetInt("player");
	
	// Only broadcast to spectators and our own team
	event.BroadcastDisabled = true;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && (TF2_GetClientTeam(client) <= TFTeam_Spectator || TF2_GetClientTeam(client) == TF2_GetClientTeam(player)))
		{
			event.FireToClient(client);
		}
	}
	
	return Plugin_Changed;
}

static Action EventHook_PlayerUsedPowerupBottle(Event event, const char[] name, bool dontBroadcast)
{
	if (sm_mvm_broadcast_events.BoolValue)
	{
		return Plugin_Continue;
	}
	
	int player = event.GetInt("player");
	
	// Only broadcast to spectators and our own team
	event.BroadcastDisabled = true;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && (TF2_GetClientTeam(client) <= TFTeam_Spectator || TF2_GetClientTeam(client) == TF2_GetClientTeam(player)))
		{
			event.FireToClient(client);
		}
	}
	
	return Plugin_Changed;
}

static Action EventHook_PlayerPickupCurrency(Event event, const char[] name, bool dontBroadcast)
{
	int player = event.GetInt("player");
	int currency = event.GetInt("currency");
	
	// This attribute is not implemented in TF2, let's do it ourselves
	int newCurrency = RoundToCeil(currency * TF2Attrib_HookValueFloat(1.0, "currency_bonus", player));
	int bonusCurrency = newCurrency - currency;
	
	// Give the player the bonus currency
	MvMPlayer(player).Currency += bonusCurrency;
	MvMPlayer(player).AcquiredCredits += bonusCurrency;
	
	event.SetInt("currency", newCurrency);
	return Plugin_Changed;
}

static void RequestFrameCallback_SpeakDeathResponses(int userid)
{
	int victim = GetClientOfUserId(userid);
	if (victim != 0)
	{
		ArrayList players = new ArrayList();
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && GetClientTeam(client) == GetClientTeam(victim) && IsPlayerAlive(client))
			{
				players.Push(client);
			}
		}
		
		if (players.Length == 1)
		{
			SetVariantString("TLK_MVM_LAST_MAN_STANDING");
			AcceptEntityInput(players.Get(0), "SpeakResponseConcept");
		}
		else
		{
			char modifier[32];
			Format(modifier, sizeof(modifier), "victimclass:%s", g_PlayerClassNames[TF2_GetPlayerClass(victim)]);
			
			for (int i = 0; i < players.Length; i++)
			{
				int client = players.Get(i);
				
				SetVariantString(modifier);
				AcceptEntityInput(client, "AddContext");
				
				SetVariantString("IsMvMDefender:1");
				AcceptEntityInput(client, "AddContext");
				
				SetVariantString("TLK_MVM_DEFENDER_DIED");
				AcceptEntityInput(client, "SpeakResponseConcept");
				
				AcceptEntityInput(client, "ClearContext");
			}
		}
		
		delete players;
	}
}
