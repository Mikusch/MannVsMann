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

void ConVars_Init()
{
	CreateConVar("sm_mvm_version", PLUGIN_VERSION, "Mann vs. Mann plugin version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	CreateConVar("sm_mvm_enabled", "1", "When set, the plugin will be enabled.");
	sm_mvm_currency_starting = CreateConVar("sm_mvm_currency_starting", "1000", "Number of credits that players get at the start of a match.", _, true, 0.0);
	sm_mvm_currency_rewards_player_killed = CreateConVar("sm_mvm_currency_rewards_player_killed", "15", "Number of credits dropped by players on death.", _, true, 0.0);
	sm_mvm_currency_rewards_objective_captured = CreateConVar("sm_mvm_currency_rewards_objective_captured", "100", "Number of credits awarded for capturing an objective.", _, true, 0.0);
	sm_mvm_currency_rewards_escort = CreateConVar("sm_mvm_currency_rewards_escort", "10", "Number of credits awarded for escorting an objective.", _, true, 0.0);
	sm_mvm_currency_rewards_player_count_base = CreateConVar("sm_mvm_currency_rewards_player_count_base", "32", "The base amount of players to use for currency scaling.", _, _, _, true, float(MAXPLAYERS - 1));
	sm_mvm_currency_rewards_player_count_bonus_min = CreateConVar("sm_mvm_currency_rewards_player_count_bonus_min", "0.33", "Minimum multiplier to currency when player count exceeds base amount.", _, true, 0.0, true, 1.0);
	sm_mvm_currency_rewards_player_count_bonus_max = CreateConVar("sm_mvm_currency_rewards_player_count_bonus_max", "2.0", "Maximum multiplier to currency when player count drops below base amount.", _, true, 1.0);
	sm_mvm_currency_rewards_player_catchup_min = CreateConVar("sm_mvm_currency_rewards_player_catchup_min", "0.66", "Maximum currency penalty multiplier for winning teams", _, true, 0.0, true, 1.0);
	sm_mvm_currency_rewards_player_catchup_max = CreateConVar("sm_mvm_currency_rewards_player_catchup_max", "1.5", "Maximum currency bonus multiplier for losing teams.", _, true, 1.0);
	sm_mvm_currency_rewards_player_modifier_arena = CreateConVar("sm_mvm_currency_rewards_player_modifier_arena", "1.5", "Multiplier to dropped currency in arena mode.");
	sm_mvm_currency_rewards_player_modifier_medieval = CreateConVar("sm_mvm_currency_rewards_player_modifier_medieval", "0.33", "Multiplier to dropped currency in medieval mode.");
	sm_mvm_upgrades_reset_mode = CreateConVar("sm_mvm_upgrades_reset_mode", "0", "How player upgrades and credits are reset after a full round has been played. 0 = Reset if teams are being switched or scrambled. 1 = Always reset. 2 = Never reset.");
	sm_mvm_showhealth = CreateConVar("sm_mvm_showhealth", "0", "When set to 1, shows a floating health icon over enemy players.");
	sm_mvm_spawn_protection = CreateConVar("sm_mvm_spawn_protection", "1", "When set to 1, players are granted ubercharge while they leave their spawn.");
	sm_mvm_music_enabled = CreateConVar("sm_mvm_music_enabled", "1", "When set to 1, Mann vs. Machine music will play at the start and end of a round.");
	sm_mvm_players_are_minibosses = CreateConVar("sm_mvm_players_are_minibosses", "1", "When set to 1, all upgrades will function as if players are MvM giants.");
	sm_mvm_gas_explode_damage_modifier = CreateConVar("sm_mvm_gas_explode_damage_modifier", "0.5", "Multiplier to damage of the explosion created by the 'Explode On Ignite' upgrade.");
	sm_mvm_explosive_sniper_shot_damage_modifier = CreateConVar("sm_mvm_explosive_sniper_shot_damage_modifier", "1.0", "Multiplier to damage of the explosion created by the 'Explosive Headshot' upgrade.");
	sm_mvm_medigun_shield_damage_modifier = CreateConVar("sm_mvm_medigun_shield_damage_modifier", "0", "Multiplier to damage of the shield created by the Medi Gun's 'Projectile Shield' upgrade.");
	sm_mvm_medigun_shield_damage_drain_rate = CreateConVar("sm_mvm_medigun_shield_damage_drain_rate", "0.05", "How much energy to drain for each point of damage to the shield.");
	sm_mvm_radius_spy_scan = CreateConVar("sm_mvm_radius_spy_scan", "0", "When set to 1, Spy will reveal cloaked enemy Spies in a radius.");
	sm_mvm_revive_markers = CreateConVar("sm_mvm_revive_markers", "1", "When set to 1, players will create revive markers on death.");
	sm_mvm_broadcast_events = CreateConVar("sm_mvm_broadcast_events", "0", "When set to 1, the 'player_buyback' and 'player_used_powerup_bottle' events will be broadcast to all players.");
	sm_mvm_custom_upgrades_file = CreateConVar("sm_mvm_custom_upgrades_file", "", "Custom upgrades file to use, set to an empty string to use the default.");
	sm_mvm_death_responses = CreateConVar("sm_mvm_death_responses", "0", "When set to 1, players will announce their teammate's deaths.");
	sm_mvm_defender_team = CreateConVar("sm_mvm_defender_team", "any", "Determines which team is allowed to use Mann vs. Machine Defender mechanics. {any, blue, red, spectator}");
	sm_mvm_powerup_max_charges = CreateConVar("sm_mvm_powerup_max_charges", "-1", "Maximum amount of powerup bottle charges that a player can carry. Set to -1 to use the default.", _, true, -1.0, true, 6.0);
	sm_mvm_backstab_armor_piercing = CreateConVar("sm_mvm_backstab_armor_piercing", "1", "When set to 1, backstabs use armor piercing upgrades to determine the damage.");
	sm_mvm_quickbuild = CreateConVar("sm_mvm_quickbuild", "1", "When set to 1, Engineers can quickly redeploy their buildings.");
	sm_mvm_setup_quickbuild = CreateConVar("sm_mvm_setup_quickbuild", "1", "When set to 1, Engineer can quickbuild during setup.");
	sm_mvm_player_sapper = CreateConVar("sm_mvm_player_sapper", "1", "When set to 1, Spy can place sappers on players.");
	sm_mvm_respec_enabled = CreateConVar("sm_mvm_respec_enabled", "1", "When set to 1, players can refund their upgrades.");
	sm_mvm_resupply_upgrades = CreateConVar("sm_mvm_resupply_upgrades", "1", "When set to 1, the resupply locker will act as an upgrade station.");
	
	PSM_AddConVarChangeHook(sm_mvm_showhealth, ConVarChanged_ShowHealth);
	PSM_AddConVarChangeHook(sm_mvm_custom_upgrades_file, ConVarChanged_CustomUpgradesFile);
	PSM_AddConVarChangeHook(sm_mvm_currency_starting, ConVarChanged_StartingCurrency);
	PSM_AddConVarChangeHook(sm_mvm_powerup_max_charges, ConVarChanged_PowerupMaxCharges);

	tf_avoidteammates_pushaway = FindConVar("tf_avoidteammates_pushaway");
}

static void ConVarChanged_ShowHealth(ConVar convar, const char[] oldValue, const char[] newValue)
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

static void ConVarChanged_CustomUpgradesFile(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (newValue[0])
	{
		SetCustomUpgradesFile(newValue);
	}
	else
	{
		ClearCustomUpgradesFile();
	}
}

static void ConVarChanged_StartingCurrency(ConVar convar, const char[] oldValue, const char[] newValue)
{
	// Add or remove currency from players.
	// This might leave the player at negative currency to compensate for purchased upgrades.
	int oldCurrency = StringToInt(oldValue);
	int newCurrency = StringToInt(newValue);
	int difference = oldCurrency - newCurrency;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).Currency -= difference;
		}
	}
}

static void ConVarChanged_PowerupMaxCharges(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).SetMaxPowerupCharges(convar.IntValue);
		}
	}
}
