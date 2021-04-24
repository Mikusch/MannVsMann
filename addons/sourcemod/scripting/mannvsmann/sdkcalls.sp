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

static Handle g_SDKCallResetMap;
static Handle g_SDKCallShouldSwitchTeams;
static Handle g_SDKCallGetNextRespawnWave;
static Handle g_SDKCallDropCurrencyPack;

void SDKCalls_Initialize(GameData gamedata)
{
	g_SDKCallResetMap = PrepSDKCall_ResetMap(gamedata);
	g_SDKCallShouldSwitchTeams = PrepSDKCall_ShouldSwitchTeams(gamedata);
	g_SDKCallGetNextRespawnWave = PrepSDKCall_GetNextRespawnWave(gamedata);
	g_SDKCallDropCurrencyPack = PrepSDKCall_DropCurrencyPack(gamedata);
}

Handle PrepSDKCall_ResetMap(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CPopulationManager::ResetMap");
	
	Handle call = EndPrepSDKCall();
	if (call == null)
		LogMessage("Failed to create SDKCall: CPopulationManager::ResetMap");
	
	return call;
}

Handle PrepSDKCall_ShouldSwitchTeams(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFGameRules::ShouldSwitchTeams");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (call == null)
		LogMessage("Failed to create SDKCall: CTFGameRules::ShouldSwitchTeams");
	
	return call;
}

Handle PrepSDKCall_GetNextRespawnWave(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFGameRules::GetNextRespawnWave");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (call == null)
		LogMessage("Failed to create SDKCall: CTFGameRules::GetNextRespawnWave");
	
	return call;
}

Handle PrepSDKCall_DropCurrencyPack(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::DropCurrencyPack");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	
	Handle call = EndPrepSDKCall();
	if (call == null)
		LogMessage("Failed to create SDKCall: CTFPlayer::DropCurrencyPack");
	
	return call;
}

void SDKCall_ResetMap(int populator)
{
	if (g_SDKCallResetMap)
		SDKCall(g_SDKCallResetMap, populator);
}

bool SDKCall_ShouldSwitchTeams()
{
	if (g_SDKCallShouldSwitchTeams)
		return SDKCall(g_SDKCallShouldSwitchTeams);
	
	return false;
}

float SDKCall_GetNextRespawnWave(int team, int player)
{
	if (g_SDKCallGetNextRespawnWave)
		return SDKCall(g_SDKCallGetNextRespawnWave, team, player);
	
	return 0.0;
}

void SDKCall_DropCurrencyPack(int client, CurrencyRewards size = TF_CURRENCY_PACK_SMALL, int amount = 0, bool forceDistribute = false, int moneyMaker = -1)
{
	if (g_SDKCallDropCurrencyPack)
		SDKCall(g_SDKCallDropCurrencyPack, client, size, amount, forceDistribute, moneyMaker);
}
