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
	char customUpgradesFile[PLATFORM_MAX_PATH];
	GameRules_GetPropString("m_pszCustomUpgradesFile", customUpgradesFile, sizeof(customUpgradesFile));
	
	// Reset to the default upgrades file
	if (!StrEqual(customUpgradesFile, DEFAULT_UPGRADES_FILE))
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
	// Base currency amount
	float amount = float(SDKCall_CalculateCurrencyAmount_ByType(TF_CURRENCY_KILLED_PLAYER));
	
	if (!amount)
	{
		return 0;
	}
	
	// If we have an attacker, use their team to determine whether to award a catchup bonus
	if (IsValidClient(attacker))
	{
		// Award bonus credits to losing teams
		float redMult = MvMTeam(TFTeam_Red).AcquiredCredits ? float(MvMTeam(TFTeam_Blue).AcquiredCredits) / float(MvMTeam(TFTeam_Red).AcquiredCredits) : 1.0;
		float blueMult = MvMTeam(TFTeam_Blue).AcquiredCredits ? float(MvMTeam(TFTeam_Red).AcquiredCredits) / float(MvMTeam(TFTeam_Blue).AcquiredCredits) : 1.0;
		
		float penaltyMult = sm_mvm_currency_rewards_player_catchup_min.FloatValue;
		float bonusMult = sm_mvm_currency_rewards_player_catchup_max.FloatValue;
		
		// Clamp it so it doesn't reach into insanity
		redMult = Clamp(redMult, penaltyMult, bonusMult);
		blueMult = Clamp(blueMult, penaltyMult, bonusMult);
		
		if (TF2_GetClientTeam(attacker) == TFTeam_Red)
		{
			amount *= redMult;
		}
		else if (TF2_GetClientTeam(attacker) == TFTeam_Blue)
		{
			amount *= blueMult;
		}
	}
	
	// Modify currency amount in arena mode
	if (IsInArenaMode())
	{
		amount *= sm_mvm_currency_rewards_player_modifier_arena.FloatValue;
	}
	
	// Modify currency amount in medieval mode
	if (GameRules_GetProp("m_bPlayingMedieval"))
	{
		amount *= sm_mvm_currency_rewards_player_modifier_medieval.FloatValue;
	}
	
	// Add low player count bonus
	float playerMult = (sm_mvm_currency_rewards_player_count_bonus.FloatValue - 1.0) / MaxClients * (MaxClients - GetPlayingClientCount());
	amount += amount * playerMult;
	
	return RoundToCeil(amount);
}

int FormatCurrencyAmount(int amount, char[] buffer, int maxlength)
{
	if (amount < 0)
	{
		return Format(buffer, maxlength, "-$%d", -amount);
	}
	else
	{
		return Format(buffer, maxlength, "$%d", amount);
	}
}

TFTeam GetDefenderTeam()
{
	char teamName[16];
	sm_mvm_defender_team.GetString(teamName, sizeof(teamName));
	
	if (StrEqual("blue", teamName, false))
	{
		return TFTeam_Blue;
	}
	else if (StrEqual("red", teamName, false))
	{
		return TFTeam_Red;
	}
	else if (StrEqual(teamName, "spectator", false))
	{
		return TFTeam_Spectator;
	}
	else
	{
		return TFTeam_Any;
	}
}

bool IsWeaponBaseMelee(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack");
}

void SuperPrecacheModel(const char[] szModel)
{
	char szBase[PLATFORM_MAX_PATH], szPath[PLATFORM_MAX_PATH];
	strcopy(szBase, sizeof(szBase), szModel);
	SplitString(szBase, ".mdl", szBase, sizeof(szBase));
	
	AddFileToDownloadsTable(szModel);
	PrecacheModel(szModel);
	
	Format(szPath, sizeof(szPath), "%s.phy", szBase);
	if (FileExists(szPath))
		AddFileToDownloadsTable(szPath);
	
	Format(szPath, sizeof(szPath), "%s.vvd", szBase);
	if (FileExists(szPath))
		AddFileToDownloadsTable(szPath);
	
	Format(szPath, sizeof(szPath), "%s.dx80.vtx", szBase);
	if (FileExists(szPath))
		AddFileToDownloadsTable(szPath);
	
	Format(szPath, sizeof(szPath), "%s.dx90.vtx", szBase);
	if (FileExists(szPath))
		AddFileToDownloadsTable(szPath);
	
	Format(szPath, sizeof(szPath), "%s.sw.vtx", szBase);
	if (FileExists(szPath))
		AddFileToDownloadsTable(szPath);
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
