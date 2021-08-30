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

static int g_IsMannVsMachineModeCount;
static bool g_IsMannVsMachineModeState[8];

bool WeaponID_IsSniperRifle(int weaponID)
{
	if (weaponID == TF_WEAPON_SNIPERRIFLE || 
		weaponID == TF_WEAPON_SNIPERRIFLE_DECAP || 
		weaponID == TF_WEAPON_SNIPERRIFLE_CLASSIC)
		return true;
	else
		return false;
}

bool WeaponID_IsSniperRifleOrBow(int weaponID)
{
	if (weaponID == TF_WEAPON_COMPOUND_BOW)
		return true;
	else
		return WeaponID_IsSniperRifle(weaponID);
}

any Min(any a, any b)
{
	return a <= b ? a : b;
}

any Max(any a, any b)
{
	return a >= b ? a : b;
}

any Clamp(any val, any min, any max)
{
	return Min(Max(val, min), max);
}

bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}

TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
}

void TF2_SetTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
}

Address GetPlayerShared(int client)
{
	Address offset = view_as<Address>(GetEntSendPropOffs(client, "m_Shared", true));
	return GetEntityAddress(client) + offset;
}

int GetPlayerSharedOuter(Address playerShared)
{
	Address outer = view_as<Address>(LoadFromAddress(playerShared + view_as<Address>(g_OffsetPlayerSharedOuter), NumberType_Int32));
	return SDKCall_GetBaseEntity(outer);
}

bool IsMultiStageMap()
{
	return FindEntityByClassname(MaxClients + 1, "team_control_point_round") != -1;
}

bool IsMannVsMachineMode()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
}

void SetMannVsMachineMode(bool value)
{
	int count = ++g_IsMannVsMachineModeCount;
	g_IsMannVsMachineModeState[count - 1] = IsMannVsMachineMode();
	GameRules_SetProp("m_bPlayingMannVsMachine", value);
}

void ResetMannVsMachineMode()
{
	int count = g_IsMannVsMachineModeCount--;
	GameRules_SetProp("m_bPlayingMannVsMachine", g_IsMannVsMachineModeState[count - 1]);
}

void CreateUpgradeStation(int regenerate)
{
	int upgradestation = CreateEntityByName("func_upgradestation");
	
	//This saves us from copying various values (origin, mins, maxs, etc.)
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(regenerate, Prop_Data, "m_ModelName", model, sizeof(model));
	SetEntityModel(upgradestation, model);
	
	SetVariantString("!activator");
	AcceptEntityInput(upgradestation, "SetParent", regenerate);
	
	DispatchSpawn(upgradestation);
}

int GetPlayingClientCount()
{
	int count;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) > TFTeam_Spectator)
		{
			count++;
		}
	}
	
	return count;
}

int CalculateCurrencyAmount(int attacker)
{
	//Base currency amount
	float amount = mvm_currency_rewards_player_killed.FloatValue;
	
	//Award bonus credits to losing teams
	float redMultiplier = MvMTeam(TFTeam_Red).AcquiredCredits > 0 ? float(MvMTeam(TFTeam_Blue).AcquiredCredits) / float(MvMTeam(TFTeam_Red).AcquiredCredits) : 1.0;
	float blueMultiplier = MvMTeam(TFTeam_Blue).AcquiredCredits > 0 ? float(MvMTeam(TFTeam_Red).AcquiredCredits) / float(MvMTeam(TFTeam_Blue).AcquiredCredits) : 1.0;
	
	//Clamp it so it doesn't reach into insanity
	redMultiplier = Clamp(redMultiplier, 1.0, mvm_currency_rewards_player_catchup_max.FloatValue);
	blueMultiplier = Clamp(blueMultiplier, 1.0, mvm_currency_rewards_player_catchup_max.FloatValue);
	
	if (TF2_GetClientTeam(attacker) == TFTeam_Red)
	{
		amount *= redMultiplier;
	}
	else if (TF2_GetClientTeam(attacker) == TFTeam_Blue)
	{
		amount *= blueMultiplier;
	}
	
	//Add low player count bonus
	float multiplier = (mvm_currency_rewards_player_count_bonus.FloatValue - 1.0) / MaxClients * (MaxClients - GetPlayingClientCount());
	amount += amount * multiplier;
	
	return RoundToCeil(amount);
}
