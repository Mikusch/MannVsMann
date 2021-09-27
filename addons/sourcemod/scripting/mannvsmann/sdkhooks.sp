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
	SDKHook(client, SDKHook_OnTakeDamage, Client_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, Client_OnTakeDamagePost);
	SDKHook(client, SDKHook_OnTakeDamageAlive, Client_OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, Client_OnTakeDamageAlivePost);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "func_regenerate") == 0)
	{
		SDKHook(entity, SDKHook_Spawn, Regenerate_Spawn);
	}
	else if (strcmp(classname, "entity_revive_marker") == 0)
	{
		SDKHook(entity, SDKHook_SetTransmit, ReviveMarker_SetTransmit);
	}
	else if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, CurrencyPack_SpawnPost);
	}
	else if (strcmp(classname, "obj_attachment_sapper") == 0)
	{
		SDKHook(entity, SDKHook_Spawn, Sapper_Spawn);
		SDKHook(entity, SDKHook_SpawnPost, Sapper_SpawnPost);
	}
	else if (strcmp(classname, "func_respawnroom") == 0)
	{
		SDKHook(entity, SDKHook_Touch, RespawnRoom_Touch);
	}
}

public Action Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	//OnTakeDamage may get called while CTFPlayerShared::ConditionGameRulesThink has MvM enabled
	//It does some unwanted stuff like defender death sounds and creating additional revive markers, suppress it
	SetMannVsMachineMode(false);
}

public void Client_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	ResetMannVsMachineMode();
}

public Action Client_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	//Blast resistance also applies to self-inflicted damage in MvM
	SetMannVsMachineMode(true);
	
	if (mvm_nerf_upgrades.BoolValue)
	{
		char classname[32];
		if (weapon != -1 && GetEntityClassname(weapon, classname, sizeof(classname)))
		{
			//Allow blast resistance to reduce the damage of the Gas Passer 'Explode On Ignite' upgrade
			if (strcmp(classname, "tf_weapon_jar_gas") == 0 && damagetype & DMG_SLASH)
			{
				damage = 250.0;
				damagetype |= DMG_BLAST;
				return Plugin_Changed;
			}
		}
		
		if (inflictor != -1 && GetEntityClassname(inflictor, classname, sizeof(classname)))
		{
			//Do not allow the Medigun's 'Projectile Shield' upgrade to deal damage
			if (strcmp(classname, "entity_medigun_shield") == 0)
			{
				damage = 0.0;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public void Client_OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	ResetMannVsMachineMode();
}

public void Regenerate_Spawn(int regenerate)
{
	if (g_IsMapRunning)
	{
		CreateUpgradeStation(regenerate);
	}
}

public Action ReviveMarker_SetTransmit(int marker, int client)
{
	//Only transmit revive markers to our own team and spectators
	if (TF2_GetClientTeam(client) != TFTeam_Spectator && TF2_GetTeam(marker) != TF2_GetClientTeam(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void CurrencyPack_SpawnPost(int currencypack)
{
	//Add the currency value to the world money
	if (!GetEntProp(currencypack, Prop_Send, "m_bDistributed"))
	{
		TFTeam team = TF2_GetTeam(currencypack);
		MvMTeam(team).WorldCredits += GetEntData(currencypack, g_OffsetCurrencyPackAmount);
	}
	
	SetEdictFlags(currencypack, (GetEdictFlags(currencypack) & ~FL_EDICT_ALWAYS));
	SDKHook(currencypack, SDKHook_SetTransmit, CurrencyPack_SetTransmit);
}

public Action CurrencyPack_SetTransmit(int currencypack, int client)
{
	//Only transmit currency packs to our own team and spectators
	if (TF2_GetClientTeam(client) != TFTeam_Spectator && TF2_GetTeam(currencypack) != TF2_GetClientTeam(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public void Sapper_Spawn(int sapper)
{
	//Prevents repeat placement of sappers on players
	SetMannVsMachineMode(true);
}

public void Sapper_SpawnPost(int sapper)
{
	ResetMannVsMachineMode();
}

public Action RespawnRoom_Touch(int respawnroom, int other)
{
	if (!IsInArenaMode() && mvm_spawn_protection.BoolValue && GameRules_GetRoundState() != RoundState_TeamWin)
	{
		//Players get uber while they leave their spawn so they don't drop their cash where enemies can't pick it up
		if (!GetEntProp(respawnroom, Prop_Data, "m_bDisabled") && IsValidClient(other) && TF2_GetTeam(respawnroom) == TF2_GetClientTeam(other))
		{
			TF2_AddCondition(other, TFCond_Ubercharged, 0.5);
			TF2_AddCondition(other, TFCond_UberchargedHidden, 0.5);
			TF2_AddCondition(other, TFCond_UberchargeFading, 0.5);
		}
	}
}
