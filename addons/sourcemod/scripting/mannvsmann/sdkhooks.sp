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
	SDKHook(client, SDKHook_OnTakeDamageAlive, SDKHookCB_Client_OnTakeDamageAlive);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "entity_revive_marker") == 0)
	{
		SDKHook(entity, SDKHook_SetTransmit, SDKHookCB_ReviveMarker_SetTransmit);
	}
	else if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_CurrencyPack_SpawnPost);
		SDKHook(entity, SDKHook_Touch, SDKHookCB_CurrencyPack_Touch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_CurrencyPack_TouchPost);
	}
}

public Action SDKHookCB_Client_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, 
	float damageForce[3], float damagePosition[3], int damagecustom)
{
	char classname[32];
	if (weapon != -1 && GetEntityClassname(weapon, classname, sizeof(classname)))
	{
		//Nerf the Gas Passer "Explode On Ignite" upgrade
		if (strcmp(classname, "tf_weapon_jar_gas") == 0 && damagetype & DMG_SLASH)
		{
			damagetype |= DMG_BLAST; //Makes Blast Resistance useful
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void SDKHookCB_CurrencyPack_SpawnPost(int currencypack)
{
	SetEdictFlags(currencypack, (GetEdictFlags(currencypack) & ~FL_EDICT_ALWAYS));
	SDKHook(currencypack, SDKHook_SetTransmit, SDKHookCB_CurrencyPack_SetTransmit);
}

public Action SDKHookCB_CurrencyPack_SetTransmit(int entity, int client)
{
	//Only transmit currency packs to our own team and spectators
	if (TF2_GetClientTeam(client) != TFTeam_Spectator && TF2_GetTeam(entity) != TF2_GetClientTeam(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action SDKHookCB_CurrencyPack_Touch(int entity, int touchPlayer)
{
	//Enable Mann vs. Machine for CCurrencyPack::MyTouch
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public Action SDKHookCB_CurrencyPack_TouchPost(int entity, int touchPlayer)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public Action SDKHookCB_ReviveMarker_SetTransmit(int entity, int client)
{
	//Only transmit revive markers to our own team and spectators
	if (TF2_GetClientTeam(client) != TFTeam_Spectator && TF2_GetTeam(entity) != TF2_GetClientTeam(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}
