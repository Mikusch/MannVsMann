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

any Abs(any value)
{
	any mask = value >> 31;
	return (value + mask) ^ mask;
}

bool IsValidClient(int client)
{
	return (0 < client <= MaxClients) && IsClientInGame(client);
}

TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
}

void TF2_SetTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
}

TFTeam TF2_GetEnemyTeam(TFTeam team)
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

int GetPlayerSharedOuter(Address playerShared)
{
	Address outer = view_as<Address>(LoadFromAddress(playerShared + view_as<Address>(g_OffsetPlayerSharedOuter), NumberType_Int32));
	return SDKCall_GetBaseEntity(outer);
}

void SetCustomUpgradesFile(const char[] path)
{
	if (FileExists(path, true, "MOD"))
	{
		AddFileToDownloadsTable(path);
		
		int gamerules = FindEntityByClassname(MaxClients + 1, "tf_gamerules");
		if (gamerules != -1)
		{
			// Set the custom upgrades file for the server
			SetVariantString(path);
			AcceptEntityInput(gamerules, "SetCustomUpgradesFile");
			
			// Set the custom upgrades file for the client without the server re-parsing it
			char downloadPath[PLATFORM_MAX_PATH];
			Format(downloadPath, sizeof(downloadPath), "download/%s", path);
			GameRules_SetPropString("m_pszCustomUpgradesFile", downloadPath);
			
			// Tell the client the upgrades file has changed
			Event event = CreateEvent("upgrades_file_changed");
			if (event)
			{
				event.SetString("path", downloadPath);
				event.Fire();
			}
		}
	}
	else
	{
		LogError("Custom upgrades file '%s' does not exist", path);
	}
}

bool IsMannVsMachineMode()
{
	return view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
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

bool IsInArenaMode()
{
	return view_as<TFGameType>(GameRules_GetProp("m_nGameType")) == TF_GAMETYPE_ARENA;
}

void CreateUpgradeStation(int regenerate)
{
	int upgradestation = CreateEntityByName("func_upgradestation");
	
	// This saves us from copying various values (origin, mins, maxs, etc.)
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(regenerate, Prop_Data, "m_ModelName", model, sizeof(model));
	SetEntityModel(upgradestation, model);
	
	SetVariantString("!activator");
	AcceptEntityInput(upgradestation, "SetParent", regenerate);
	
	DispatchSpawn(upgradestation);
}

void DispatchParticleEffect(const char[] name, ParticleAttachment attachType, int entity, const char[] attachmentName, bool resetAllParticlesOnEntity = false)
{
	int tableidx = FindStringTable("ParticleEffectNames");
	int numstrings = GetStringTableNumStrings(tableidx);
	
	for (int stringidx = 0; stringidx < numstrings; stringidx++)
	{
		char str[256];
		ReadStringTable(tableidx, stringidx, str, sizeof(str));
		
		if (strcmp(str, name) == 0)
		{
			TE_Start("TFParticleEffect");
			TE_WriteNum("m_iParticleSystemIndex", stringidx);
			TE_WriteNum("entindex", entity);
			TE_WriteNum("m_iAttachType", view_as<int>(attachType));
			TE_WriteNum("m_iAttachmentPointIndex", SDKCall_LookupAttachment(entity, attachmentName));
			TE_WriteNum("m_bResetParticles", resetAllParticlesOnEntity);
			TE_SendToAll();
			break;
		}
	}
}

int CalculateCurrencyAmount_ByType(CurrencyRewards type)
{
	switch (type)
	{
		case TF_CURRENCY_KILLED_PLAYER: { return 40; }
		case TF_CURRENCY_KILLED_OBJECT: { return 40; }
		case TF_CURRENCY_ASSISTED_PLAYER: { return 20; }
		case TF_CURRENCY_BONUS_POINTS: { return 1; }
		case TF_CURRENCY_CAPTURED_OBJECTIVE: { return 100; }
		case TF_CURRENCY_ESCORT_REWARD: { return 10; }
		case TF_CURRENCY_PACK_SMALL: { return 5; }
		case TF_CURRENCY_PACK_MEDIUM: { return 10; }
		case TF_CURRENCY_PACK_LARGE: { return 25; }
		case TF_CURRENCY_TIME_REWARD: { return 5; }
		case TF_CURRENCY_WAVE_COLLECTION_BONUS: { return 100; }
		default: { return 0; }
	}
}
