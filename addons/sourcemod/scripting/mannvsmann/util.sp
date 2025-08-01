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

static int g_IsMannVsMachineModeCount;
static bool g_IsMannVsMachineModeState[8];

bool WeaponID_IsSniperRifle(int weaponID)
{
	return (weaponID == TF_WEAPON_SNIPERRIFLE || weaponID == TF_WEAPON_SNIPERRIFLE_DECAP || weaponID == TF_WEAPON_SNIPERRIFLE_CLASSIC);
}

bool WeaponID_IsSniperRifleOrBow(int weaponID)
{
	return (weaponID == TF_WEAPON_COMPOUND_BOW) ? true : WeaponID_IsSniperRifle(weaponID);
}

bool IsHeadshot(int type)
{
	return (type == TF_CUSTOM_HEADSHOT || type == TF_CUSTOM_HEADSHOT_DECAPITATION);
}

any Min(any a, any b)
{
	return (a <= b) ? a : b;
}

any Max(any a, any b)
{
	return (a >= b) ? a : b;
}

any Clamp(any val, any min, any max)
{
	return Min(Max(val, min), max);
}

any Abs(any val)
{
	return (val < 0) ? -val : val;
}

bool IsValidClient(int client)
{
	return (0 < client <= MaxClients) && IsClientInGame(client);
}

void RemoveEntitiesByClassname(const char[] classname)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, classname)) != -1)
	{
		RemoveEntity(entity);
	}
}

TFTeam TF2_GetEntityTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
}

void TF2_SetEntityTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
}

TFTeam GetEnemyTeam(TFTeam team)
{
	switch (team)
	{
		case TFTeam_Red: { return TFTeam_Blue; }
		case TFTeam_Blue: { return TFTeam_Red; }
		default: { return team; }
	}
}

Address GetPlayerShared(int client)
{
	Address offset = view_as<Address>(GetEntSendPropOffs(client, "m_Shared", true));
	return GetEntityAddress(client) + offset;
}

void SetCustomUpgradesFile(const char[] path)
{
	if (FileExists(path, true, "GAME"))
	{
		AddFileToDownloadsTable(path);
		
		int gamerules = FindEntityByClassname(-1, "tf_gamerules");
		if (gamerules != -1)
		{
			SetVariantString(path);
			AcceptEntityInput(gamerules, "SetCustomUpgradesFile");
		}
	}
	else
	{
		LogError("Custom upgrades file '%s' does not exist", path);
	}
}

void ClearCustomUpgradesFile()
{
	char file[PLATFORM_MAX_PATH];
	GameRules_GetPropString("m_pszCustomUpgradesFile", file, sizeof(file));
	
	// Reset to the default upgrades file
	if (!StrEqual(file, DEFAULT_UPGRADES_FILE))
	{
		int gamerules = FindEntityByClassname(-1, "tf_gamerules");
		if (gamerules != -1)
		{
			SetVariantString(DEFAULT_UPGRADES_FILE);
			AcceptEntityInput(gamerules, "SetCustomUpgradesFile");
		}
	}
}

bool IsMannVsMachineMode()
{
	return GameRules_GetProp("m_bPlayingMannVsMachine") != 0;
}

void SetMannVsMachineMode(bool value)
{
	int index = g_IsMannVsMachineModeCount++;
	g_IsMannVsMachineModeState[index] = IsMannVsMachineMode();
	GameRules_SetProp("m_bPlayingMannVsMachine", value);
}

void ResetMannVsMachineMode()
{
	int index = --g_IsMannVsMachineModeCount;
	GameRules_SetProp("m_bPlayingMannVsMachine", g_IsMannVsMachineModeState[index]);
}

bool IsEntityVisibleToPlayer(int entity, int client)
{
	// Always show neutral entities and allow spectators to see everything 
	if (TF2_GetEntityTeam(entity) == TFTeam_Unassigned || TF2_GetClientTeam(client) <= TFTeam_Spectator)
	{
		return true;
	}
	
	// Only visible when on the same team
	return TF2_GetEntityTeam(entity) == TF2_GetClientTeam(client);
}

void AddWorldMoney(TFTeam team, int amount)
{
	if (team == TFTeam_Unassigned)
	{
		// If no team owns the currency pack, add it to world money for everyone
		for (TFTeam other = TFTeam_Unassigned; other <= TFTeam_Blue; other++)
		{
			MvMTeam(other).WorldMoney += amount;
		}
	}
	else
	{
		MvMTeam(team).WorldMoney += amount;
	}
}

bool IsInArenaMode()
{
	return view_as<TFGameType>(GameRules_GetProp("m_nGameType")) == TF_GAMETYPE_ARENA;
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
	float amount = float(SDKCall_CalculateCurrencyAmount_ByType(TF_CURRENCY_KILLED_PLAYER));
	
	if (!amount)
		return 0;
	
	if (IsValidClient(attacker))
		amount *= CalculateTeamCatchupMultiplier(TF2_GetClientTeam(attacker));
	
	if (IsInArenaMode())
		amount *= sm_mvm_currency_modifier_arena.FloatValue;
	
	if (GameRules_GetProp("m_bPlayingMedieval"))
		amount *= sm_mvm_currency_modifier_medieval.FloatValue;
	
	amount *= CalculatePlayerCountMultiplier();
	
	return RoundFloat(amount);
}

float CalculateTeamCatchupMultiplier(TFTeam team)
{
	if (team <= TFTeam_Spectator)
		return 1.0;
	
	int myCredits = MvMTeam(team).AcquiredCredits;
	int enemyCredits = MvMTeam(GetEnemyTeam(team)).AcquiredCredits;
	int totalCredits = myCredits + enemyCredits;
	
	int creditDiff = enemyCredits - myCredits;
	float threshold = Max(sm_mvm_currency_team_catchup_base_threshold.FloatValue + (totalCredits * sm_mvm_currency_team_catchup_threshold_scale.FloatValue), 1.0);
	float thresholdDiff = float(creditDiff) / threshold;

	float mult = 1.0 + (thresholdDiff * sm_mvm_currency_team_catchup_multiplier_strength.FloatValue);
	return Clamp(mult, sm_mvm_currency_team_catchup_min.FloatValue, sm_mvm_currency_team_catchup_max.FloatValue);
}

float CalculatePlayerCountMultiplier()
{
	int baseCount = sm_mvm_currency_player_count_base.IntValue;
	
	if (baseCount <= 0)
		return 1.0;
	
	int playerCount = GetPlayingClientCount();
	float minMult = sm_mvm_currency_player_count_bonus_min.FloatValue;
	float maxMult = sm_mvm_currency_player_count_bonus_max.FloatValue;
	
	float mult;
	
	if (playerCount <= baseCount)
	{
		float slope = (1.0 - maxMult) / float(baseCount);
		mult = maxMult + slope * float(playerCount);
	}
	else
	{
		float slope = (minMult - 1.0) / float(baseCount);
		mult = 1.0 + slope * float(playerCount - baseCount);
	}
	
	return Clamp(mult, minMult, maxMult);
}

int FormatCurrencyAmount(int amount, char[] buffer, int maxlength)
{
	char temp[32];
	int len = IntToString(Abs(amount), temp, sizeof(temp));

	int commas = (len - 1) / 3;
	int outIndex = 0;
	int digitIndex = 0;
	
	int totalLen = len + commas;
	if (amount < 0)
		totalLen += 2;
	else
		totalLen += 1;
	
	if (totalLen >= maxlength)
	{
		buffer[0] = '\0';
		return 0;
	}

	if (amount < 0)
	{
		buffer[outIndex++] = '-';
	}
	buffer[outIndex++] = '$';

	for (int i = 0; i < len; i++)
	{
		if (i > 0 && (len - i) % 3 == 0)
		{
			buffer[outIndex++] = ',';
		}
		buffer[outIndex++] = temp[digitIndex++];
	}

	buffer[outIndex] = '\0';
	return outIndex;
}

TFTeam GetDefenderTeam()
{
	char teamName[16];
	sm_mvm_defender_team.GetString(teamName, sizeof(teamName));
	
	if (StrEqual("blue", teamName, false))
		return TFTeam_Blue;
	else if (StrEqual("red", teamName, false))
		return TFTeam_Red;
	else if (StrEqual(teamName, "spectator", false))
		return TFTeam_Spectator;
	else
		return TFTeam_Any;
}

void SuperPrecacheModel(const char[] model)
{
	char base[PLATFORM_MAX_PATH], path[PLATFORM_MAX_PATH];
	strcopy(base, sizeof(base), model);
	SplitString(base, ".mdl", base, sizeof(base));
	
	AddFileToDownloadsTable(model);
	PrecacheModel(model);
	
	Format(path, sizeof(path), "%s.phy", base);
	if (FileExists(path))
		AddFileToDownloadsTable(path);
	
	Format(path, sizeof(path), "%s.vvd", base);
	if (FileExists(path))
		AddFileToDownloadsTable(path);
	
	Format(path, sizeof(path), "%s.dx80.vtx", base);
	if (FileExists(path))
		AddFileToDownloadsTable(path);
	
	Format(path, sizeof(path), "%s.dx90.vtx", base);
	if (FileExists(path))
		AddFileToDownloadsTable(path);
	
	Format(path, sizeof(path), "%s.sw.vtx", base);
	if (FileExists(path))
		AddFileToDownloadsTable(path);
}

void RunScriptCode(int entity, int activator, int caller, const char[] format, any...)
{
	if (!IsValidEntity(entity))
		return;
	
	static char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 5);
	
	SetVariantString(buffer);
	AcceptEntityInput(entity, "RunScriptCode", activator, caller);
}
