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

void ConVars_Initialize()
{
	CreateConVar("mvm_version", PLUGIN_VERSION, "Mann vs. Mann plugin version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	mvm_enable = CreateConVar("mvm_enable", "1", "When set, the plugin will be enabled.");
	mvm_currency_starting = CreateConVar("mvm_currency_starting", "1000", "Number of credits that players get at the start of a match.", _, true, 0.0);
	mvm_currency_rewards_player_killed = CreateConVar("mvm_currency_rewards_player_killed", "15", "The fixed number of credits dropped by players on death.");
	mvm_currency_rewards_player_count_bonus = CreateConVar("mvm_currency_rewards_player_count_bonus", "2.0", "Multiplier to dropped currency that gradually increases up to this value until all player slots have been filled.", _, true, 1.0);
	mvm_currency_rewards_player_catchup_max = CreateConVar("mvm_currency_rewards_player_catchup_max", "1.5", "Maximum currency bonus multiplier for losing teams.", _, true, 1.0);
	mvm_currency_rewards_player_modifier_arena = CreateConVar("mvm_currency_rewards_player_modifier_arena", "2.0", "Multiplier to dropped currency in arena mode.");
	mvm_currency_rewards_player_modifier_medieval = CreateConVar("mvm_currency_rewards_player_modifier_medieval", "0.33", "Multiplier to dropped currency in medieval mode.");
	mvm_currency_hud_position_x = CreateConVar("mvm_currency_hud_position_x", "-1", "x coordinate of the currency HUD message, from 0 to 1. -1.0 is the center.", _, true, -1.0, true, 1.0);
	mvm_currency_hud_position_y = CreateConVar("mvm_currency_hud_position_y", "0.75", "y coordinate of the currency HUD message, from 0 to 1. -1.0 is the center.", _, true, -1.0, true, 1.0);
	mvm_upgrades_reset_mode = CreateConVar("mvm_upgrades_reset_mode", "0", "How player upgrades and credits are reset after a full round has been played. 0 = Reset if teams are being switched or scrambled. 1 = Always reset. 2 = Never reset.");
	mvm_showhealth = CreateConVar("mvm_showhealth", "0", "When set to 1, shows a floating health icon over enemy players.");
	mvm_spawn_protection = CreateConVar("mvm_spawn_protection", "1", "When set to 1, players are granted ubercharge while they leave their spawn.");
	mvm_enable_music = CreateConVar("mvm_enable_music", "1", "When set to 1, Mann vs. Machine music will play at the start and end of a round.");
	mvm_nerf_upgrades = CreateConVar("mvm_nerf_upgrades", "1", "When set to 1, some upgrades will be modified to be fairer in player versus player modes.");
	mvm_custom_upgrades_file = CreateConVar("mvm_custom_upgrades_file", "", "Custom upgrade menu file to use, set to an empty string to use the default.");
	
	// Always keep this hook active
	mvm_enable.AddChangeHook(ConVarChanged_Enable);
}

void ConVars_Toggle(bool enable)
{
	if (enable)
	{
		mvm_showhealth.AddChangeHook(ConVarChanged_ShowHealth);
		mvm_custom_upgrades_file.AddChangeHook(ConVarChanged_CustomUpgradesFile);
		mvm_currency_starting.AddChangeHook(ConVarChanged_StartingCurrency);
	}
	else
	{
		mvm_showhealth.RemoveChangeHook(ConVarChanged_ShowHealth);
		mvm_custom_upgrades_file.RemoveChangeHook(ConVarChanged_CustomUpgradesFile);
		mvm_currency_starting.RemoveChangeHook(ConVarChanged_StartingCurrency);
	}
}

public void ConVarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_IsEnabled != convar.BoolValue)
	{
		TogglePlugin(convar.BoolValue);
	}
}

public void ConVarChanged_ShowHealth(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_IsEnabled)
	{
		return;
	}
	
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
	if (!g_IsEnabled)
	{
		return;
	}
	
	if (newValue[0] != '\0')
	{
		SetCustomUpgradesFile(newValue);
	}
	else
	{
		ClearCustomUpgradesFile();
	}
}

public void ConVarChanged_StartingCurrency(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_IsEnabled)
	{
		return;
	}
	
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
