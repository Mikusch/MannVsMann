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

#pragma semicolon 1
#pragma newdecls required

void SDKHooks_HookClient(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, SDKHookCB_Client_OnTakeDamagePost);
	SDKHook(client, SDKHook_OnTakeDamageAlive, SDKHookCB_Client_OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, SDKHookCB_Client_OnTakeDamageAlivePost);
}

void SDKHooks_UnhookClient(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, SDKHookCB_Client_OnTakeDamagePost);
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, SDKHookCB_Client_OnTakeDamageAlive);
	SDKUnhook(client, SDKHook_OnTakeDamageAlivePost, SDKHookCB_Client_OnTakeDamageAlivePost);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (!strcmp(classname, "func_regenerate"))
	{
		SDKHook(entity, SDKHook_EndTouch, SDKHookCB_Regenerate_EndTouch);
	}
	else if (!strcmp(classname, "entity_revive_marker"))
	{
		SDKHook(entity, SDKHook_SetTransmit, SDKHookCB_ReviveMarker_SetTransmit);
	}
	else if (!strncmp(classname, "item_currencypack_", 18))
	{
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_CurrencyPack_SpawnPost);
	}
	else if (!strcmp(classname, "obj_attachment_sapper"))
	{
		SDKHook(entity, SDKHook_Spawn, SDKHookCB_Sapper_Spawn);
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_Sapper_SpawnPost);
	}
	else if (!strcmp(classname, "func_respawnroom"))
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_RespawnRoom_Touch);
	}
}

void SDKHooks_UnhookEntity(int entity, const char[] classname)
{
	if (!strcmp(classname, "func_regenerate"))
	{
		SDKUnhook(entity, SDKHook_EndTouch, SDKHookCB_Regenerate_EndTouch);
	}
	else if (!strcmp(classname, "func_respawnroom"))
	{
		SDKUnhook(entity, SDKHook_Touch, SDKHookCB_RespawnRoom_Touch);
	}
}

public Action SDKHookCB_Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// OnTakeDamage may get called while CTFPlayerShared::ConditionGameRulesThink has MvM enabled.
	// This causes unwanted things like defender death sounds and additional revive markers to appear, so we suppress it.
	SetMannVsMachineMode(false);
	
	return Plugin_Continue;
}

public void SDKHookCB_Client_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	ResetMannVsMachineMode();
}

public Action SDKHookCB_Client_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// Blast resistance also applies to self-inflicted damage in MvM
	SetMannVsMachineMode(true);
	
	if (weapon != -1)
	{
		// Modify the damage of the Gas Passer's 'Explode On Ignite' upgrade
		char classname[32];
		if (GetEntityClassname(weapon, classname, sizeof(classname)) && !strcmp(classname, "tf_weapon_jar_gas"))
		{
			if (damagetype & DMG_SLASH)
			{
				damage *= mvm_gas_explode_damage_modifier.FloatValue;
				return Plugin_Changed;
			}
		}
	}
	
	if (inflictor != -1)
	{
		// Modify the damage of the Medi Gun's 'Projectile Shield' upgrade
		char classname[32];
		if (GetEntityClassname(inflictor, classname, sizeof(classname)) && !strcmp(classname, "entity_medigun_shield"))
		{
			damage *= mvm_medigun_shield_damage_modifier.FloatValue;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void SDKHookCB_Client_OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	ResetMannVsMachineMode();
}

public Action SDKHookCB_Regenerate_EndTouch(int regenerate, int other)
{
	if (IsValidClient(other))
	{
		SetEntProp(other, Prop_Send, "m_bInUpgradeZone", true);
	}
	
	return Plugin_Continue;
}

public Action SDKHookCB_ReviveMarker_SetTransmit(int marker, int client)
{
	// Only transmit revive markers to our own team and spectators
	if (!IsEntVisibleToClient(marker, client))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void SDKHookCB_CurrencyPack_SpawnPost(int currencypack)
{
	// Add the currency value to the world money
	if (!GetEntProp(currencypack, Prop_Send, "m_bDistributed"))
	{
		int amount = GetEntData(currencypack, g_OffsetCurrencyPackAmount);
		AddWorldMoney(TF2_GetTeam(currencypack), amount);
	}
	
	SetEdictFlags(currencypack, (GetEdictFlags(currencypack) & ~FL_EDICT_ALWAYS));
	SDKHook(currencypack, SDKHook_SetTransmit, CurrencyPack_SetTransmit);
}

public Action CurrencyPack_SetTransmit(int currencypack, int client)
{
	// Only transmit currency packs to our own team and spectators
	if (!IsEntVisibleToClient(currencypack, client))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void SDKHookCB_Sapper_Spawn(int sapper)
{
	// Prevents repeat placement of sappers on players
	SetMannVsMachineMode(true);
}

public void SDKHookCB_Sapper_SpawnPost(int sapper)
{
	ResetMannVsMachineMode();
}

public Action SDKHookCB_RespawnRoom_Touch(int respawnroom, int other)
{
	if (!IsInArenaMode() && mvm_spawn_protection.BoolValue && GameRules_GetRoundState() != RoundState_TeamWin)
	{
		// Players get uber while they leave their spawn so they don't drop their cash where enemies can't pick it up
		if (!GetEntProp(respawnroom, Prop_Data, "m_bDisabled") && IsValidClient(other) && TF2_GetTeam(respawnroom) == TF2_GetClientTeam(other))
		{
			TF2_AddCondition(other, TFCond_Ubercharged, 0.5);
			TF2_AddCondition(other, TFCond_UberchargedHidden, 0.5);
			TF2_AddCondition(other, TFCond_UberchargeFading, 0.5);
		}
	}
	
	return Plugin_Continue;
}
