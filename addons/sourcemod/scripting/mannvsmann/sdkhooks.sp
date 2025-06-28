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

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (0 < entity <= MaxClients)
	{
		PSM_SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
		PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_Client_OnTakeDamagePost);
		PSM_SDKHook(entity, SDKHook_OnTakeDamageAlive, SDKHookCB_Client_OnTakeDamageAlive);
		PSM_SDKHook(entity, SDKHook_OnTakeDamageAlivePost, SDKHookCB_Client_OnTakeDamageAlivePost);
	}
	else if (StrEqual(classname, "func_regenerate"))
	{
		PSM_SDKHook(entity, SDKHook_StartTouchPost, SDKHookCB_Regenerate_StartTouchPost);
		PSM_SDKHook(entity, SDKHook_EndTouchPost, SDKHookCB_Regenerate_EndTouchPost);
	}
	else if (StrEqual(classname, "entity_medigun_shield"))
	{
		PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_MedigunShield_OnTakeDamagePost);
	}
	else if (StrEqual(classname, "entity_revive_marker"))
	{
		PSM_SDKHook(entity, SDKHook_SetTransmit, SDKHookCB_ReviveMarker_SetTransmit);
	}
	else if (!strncmp(classname, "item_currencypack_", 18))
	{
		PSM_SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_CurrencyPack_SpawnPost);
	}
	else if (StrEqual(classname, "obj_attachment_sapper"))
	{
		PSM_SDKHook(entity, SDKHook_Spawn, SDKHookCB_Sapper_Spawn);
		PSM_SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_Sapper_SpawnPost);
	}
	else if (StrEqual(classname, "func_respawnroom"))
	{
		PSM_SDKHook(entity, SDKHook_TouchPost, SDKHookCB_RespawnRoom_TouchPost);
	}
}

static Action SDKHookCB_Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// OnTakeDamage may get called while CTFPlayerShared::ConditionGameRulesThink has MvM enabled.
	// This causes unwanted things like defender death sounds and additional revive markers to appear, so we suppress it.
	SetMannVsMachineMode(false);
	
	return Plugin_Continue;
}

static void SDKHookCB_Client_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	ResetMannVsMachineMode();
}

static Action SDKHookCB_Client_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// Blast resistance also applies to self-inflicted damage in MvM
	SetMannVsMachineMode(true);
	
	if (weapon != -1)
	{
		char classname[32];
		if (GetEntityClassname(weapon, classname, sizeof(classname)))
		{
			// Modify the damage of the Gas Passer's 'Explode On Ignite' upgrade
			if (StrEqual(classname, "tf_weapon_jar_gas") && (damagetype & DMG_SLASH))
			{
				damage *= sm_mvm_gas_explode_damage_modifier.FloatValue;
				return Plugin_Changed;
			}
			// Modify the damage of the Sniper Rifle's 'Explosive Headshot' upgrade
			else if (!strncmp(classname, "tf_weapon_sniperrifle", 21) && (damagetype & DMG_SLASH) && damagecustom == TF_CUSTOM_BLEEDING)
			{
				damage *= sm_mvm_explosive_sniper_shot_damage_modifier.FloatValue;
				return Plugin_Changed;
			}
		}
	}
	
	if (inflictor != -1)
	{
		// Modify the damage of the Medi Gun's 'Projectile Shield' upgrade
		char classname[32];
		if (GetEntityClassname(inflictor, classname, sizeof(classname)) && StrEqual(classname, "entity_medigun_shield"))
		{
			damage *= sm_mvm_medigun_shield_damage_modifier.FloatValue;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

static void SDKHookCB_Client_OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	ResetMannVsMachineMode();
}

static void SDKHookCB_Regenerate_StartTouchPost(int regenerate, int other)
{
	if (IsValidClient(other))
	{
		// Avoid players pushing eachother
		if (IsFakeClient(other))
		{
			SetFakeClientConVar(other, "tf_avoidteammates_pushaway", "0");
		}
		else
		{
			tf_avoidteammates_pushaway.ReplicateToClient(other, "0");
		}
	}
}

static void SDKHookCB_Regenerate_EndTouchPost(int regenerate, int other)
{
	if (IsValidClient(other))
	{
		SetEntProp(other, Prop_Send, "m_bInUpgradeZone", false);
		
		char value[64];
		tf_avoidteammates_pushaway.GetString(value, sizeof(value));
		
		if (IsFakeClient(other))
		{
			SetFakeClientConVar(other, "tf_avoidteammates_pushaway", value);
		}
		else
		{
			tf_avoidteammates_pushaway.ReplicateToClient(other, value);
		}
	}
}

static void SDKHookCB_MedigunShield_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	int owner = GetEntPropEnt(victim, Prop_Send, "m_hOwnerEntity");
	if (!IsValidEntity(owner))
		return;
	
	// Allow players to drain shield energy by dealing damage
	SetEntPropFloat(owner, Prop_Send, "m_flRageMeter", GetEntPropFloat(owner, Prop_Send, "m_flRageMeter") - (damage * sm_mvm_medigun_shield_damage_drain_rate.FloatValue));
}

static Action SDKHookCB_ReviveMarker_SetTransmit(int marker, int client)
{
	// Only transmit revive markers to our own team and spectators
	return IsEntityVisibleToPlayer(marker, client) ? Plugin_Continue : Plugin_Handled;
}

static void SDKHookCB_CurrencyPack_SpawnPost(int currencypack)
{
	// Add the currency value to the world money
	if (!GetEntProp(currencypack, Prop_Send, "m_bDistributed"))
	{
		int amount = GetEntData(currencypack, GetOffset("CCurrencyPack", "m_nAmount"));
		AddWorldMoney(TF2_GetEntityTeam(currencypack), amount);
	}
	
	SetEdictFlags(currencypack, (GetEdictFlags(currencypack) & ~FL_EDICT_ALWAYS));
	SDKHook(currencypack, SDKHook_SetTransmit, SDKHookCB_CurrencyPack_SetTransmit);
}

static Action SDKHookCB_CurrencyPack_SetTransmit(int currencypack, int client)
{
	// Only transmit currency packs to our own team and spectators
	return IsEntityVisibleToPlayer(currencypack, client) ? Plugin_Continue : Plugin_Handled;
}

static Action SDKHookCB_Sapper_Spawn(int sapper)
{
	// Prevents repeat placement of sappers on players
	SetMannVsMachineMode(sm_mvm_player_sapper.BoolValue);
	
	return Plugin_Continue;
}

static void SDKHookCB_Sapper_SpawnPost(int sapper)
{
	ResetMannVsMachineMode();
}

static void SDKHookCB_RespawnRoom_TouchPost(int respawnroom, int other)
{
	if (!IsInArenaMode() && sm_mvm_spawn_protection.BoolValue && GameRules_GetRoundState() != RoundState_TeamWin)
	{
		// Players get uber while they leave their spawn so they don't drop their cash where enemies can't pick it up
		if (!GetEntProp(respawnroom, Prop_Data, "m_bDisabled") && IsValidClient(other) && TF2_GetEntityTeam(respawnroom) == TF2_GetClientTeam(other))
		{
			TF2_AddCondition(other, TFCond_Ubercharged, 0.5);
			TF2_AddCondition(other, TFCond_UberchargedHidden, 0.5);
			TF2_AddCondition(other, TFCond_UberchargeFading, 0.5);
			TF2_AddCondition(other, TFCond_ImmuneToPushback, 1.0);
		}
	}
}
