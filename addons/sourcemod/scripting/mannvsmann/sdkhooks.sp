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

void SDKHooks_HookClient(int client)
{
	SDKHook(client, SDKHook_PostThink, Client_PostThink);
	SDKHook(client, SDKHook_OnTakeDamageAlive, Client_OnTakeDamageAlive);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "entity_revive_marker") == 0)
	{
		SDKHook(entity, SDKHook_SetTransmit, ReviveMarker_SetTransmit);
	}
	else if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, CurrencyPack_SpawnPost);
		SDKHook(entity, SDKHook_Touch, CurrencyPack_Touch);
		SDKHook(entity, SDKHook_TouchPost, CurrencyPack_TouchPost);
	}
}

public void Client_PostThink(int client)
{
	TFTeam team = TF2_GetClientTeam(client);
	if (team > TFTeam_Spectator)
	{
		SetHudTextParams(0.85, 0.85, 0.1, 122, 196, 55, 255, _, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_HudSync, "$%d ($%d)", MvMPlayer(client).Currency, MvMTeam(team).WorldCredits);
	}
}

public Action Client_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, 
	float damageForce[3], float damagePosition[3], int damagecustom)
{
	char classname[32];
	
	if (inflictor != -1 && GetEntityClassname(inflictor, classname, sizeof(classname)))
	{
		//Change the damage of the Medi Gun projectile shield
		if (strcmp(classname, "entity_medigun_shield") == 0)
		{
			damage *= mvm_medigun_shield_damage_modifier.FloatValue;
			return Plugin_Changed;
		}
	}
	
	if (weapon != -1 && GetEntityClassname(weapon, classname, sizeof(classname)))
	{
		//Change the damage of the Gas Passer "Explode On Ignite" upgrade
		if (strcmp(classname, "tf_weapon_jar_gas") == 0 && damagetype & DMG_SLASH)
		{
			damage *= mvm_gas_explosion_damage_modifier.FloatValue;
			damagetype |= DMG_BLAST; //Makes Blast Resistance useful
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void CurrencyPack_SpawnPost(int currencypack)
{
	SetEdictFlags(currencypack, (GetEdictFlags(currencypack) & ~FL_EDICT_ALWAYS));
	SDKHook(currencypack, SDKHook_SetTransmit, CurrencyPack_SetTransmit);
}

public Action CurrencyPack_SetTransmit(int entity, int client)
{
	//Only transmit currency packs to our own team and spectators
	if (TF2_GetClientTeam(client) != TFTeam_Spectator && TF2_GetTeam(entity) != TF2_GetClientTeam(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action CurrencyPack_Touch(int entity, int touchPlayer)
{
	//Enable Mann vs. Machine for CCurrencyPack::MyTouch so the currency is distributed
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public Action CurrencyPack_TouchPost(int entity, int touchPlayer)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public Action ReviveMarker_SetTransmit(int entity, int client)
{
	//Only transmit revive markers to our own team and spectators
	if (TF2_GetClientTeam(client) != TFTeam_Spectator && TF2_GetTeam(entity) != TF2_GetClientTeam(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}
