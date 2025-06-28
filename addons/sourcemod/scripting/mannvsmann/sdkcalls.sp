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

static Handle g_SDKCallResetMap;
static Handle g_SDKCallGetPlayerCurrencySpent;
static Handle g_SDKCallAddPlayerCurrencySpent;
static Handle g_SDKCallDropCurrencyPack;
static Handle g_SDKCallCanRecieveMedigunChargeEffect;
static Handle g_SDKCallReviveMarkerCreate;
static Handle g_SDKCallRemoveImmediate;
static Handle g_SDKCallCalculateCurrencyAmount_ByType;
static Handle g_SDKCallShouldSwitchTeams;
static Handle g_SDKCallShouldScrambleTeams;
static Handle g_SDKCallGetNextRespawnWave;

void SDKCalls_Init(GameData gameconf)
{
	g_SDKCallResetMap = PrepSDKCall_ResetMap(gameconf);
	g_SDKCallGetPlayerCurrencySpent = PrepSDKCall_GetPlayerCurrencySpent(gameconf);
	g_SDKCallAddPlayerCurrencySpent = PrepSDKCall_AddPlayerCurrencySpent(gameconf);
	g_SDKCallDropCurrencyPack = PrepSDKCall_DropCurrencyPack(gameconf);
	g_SDKCallCanRecieveMedigunChargeEffect = PrepSDKCall_CanRecieveMedigunChargeEffect(gameconf);
	g_SDKCallReviveMarkerCreate = PrepSDKCall_ReviveMarkerCreate(gameconf);
	g_SDKCallRemoveImmediate = PrepSDKCall_RemoveImmediate(gameconf);
	g_SDKCallCalculateCurrencyAmount_ByType = PrepSDKCall_CalCalculateCurrencyAmount_ByType(gameconf);
	g_SDKCallShouldSwitchTeams = PrepSDKCall_ShouldSwitchTeams(gameconf);
	g_SDKCallShouldScrambleTeams = PrepSDKCall_ShouldScrambleTeams(gameconf);
	g_SDKCallGetNextRespawnWave = PrepSDKCall_GetNextRespawnWave(gameconf);
}

static Handle PrepSDKCall_ResetMap(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CPopulationManager::ResetMap");
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CPopulationManager::ResetMap");
	
	return call;
}

static Handle PrepSDKCall_GetPlayerCurrencySpent(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CPopulationManager::GetPlayerCurrencySpent");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CPopulationManager::GetPlayerCurrencySpent");
	
	return call;
}

static Handle PrepSDKCall_AddPlayerCurrencySpent(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CPopulationManager::AddPlayerCurrencySpent");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CPopulationManager::AddPlayerCurrencySpent");
	
	return call;
}

static Handle PrepSDKCall_DropCurrencyPack(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CTFPlayer::DropCurrencyPack");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFPlayer::DropCurrencyPack");
	
	return call;
}

static Handle PrepSDKCall_CanRecieveMedigunChargeEffect(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CTFPlayerShared::CanRecieveMedigunChargeEffect");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFPlayerShared::CanRecieveMedigunChargeEffect");
	
	return call;
}

static Handle PrepSDKCall_ReviveMarkerCreate(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CTFReviveMarker::Create");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFReviveMarker::Create");
	
	return call;
}

static Handle PrepSDKCall_RemoveImmediate(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "UTIL_RemoveImmediate");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: UTIL_RemoveImmediate");
	
	return call;
}

static Handle PrepSDKCall_CalCalculateCurrencyAmount_ByType(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CTFGameRules::CalculateCurrencyAmount_ByType");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFGameRules::CalculateCurrencyAmount_ByType");
	
	return call;
}

static Handle PrepSDKCall_ShouldSwitchTeams(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Virtual, "CTFGameRules::ShouldSwitchTeams");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFGameRules::ShouldSwitchTeams");
	
	return call;
}

static Handle PrepSDKCall_ShouldScrambleTeams(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Virtual, "CTFGameRules::ShouldScrambleTeams");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFGameRules::ShouldScrambleTeams");
	
	return call;
}

static Handle PrepSDKCall_GetNextRespawnWave(GameData gameconf)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Virtual, "CTeamplayRoundBasedRules::GetNextRespawnWave");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTeamplayRoundBasedRules::GetNextRespawnWave");
	
	return call;
}

void SDKCall_ResetMap(int populator)
{
	SDKCall(g_SDKCallResetMap, populator);
}

int SDKCall_GetPlayerCurrencySpent(int populator, int player)
{
	return SDKCall(g_SDKCallGetPlayerCurrencySpent, populator, player);
}

void SDKCall_AddPlayerCurrencySpent(int populator, int player, int cost)
{
	SDKCall(g_SDKCallAddPlayerCurrencySpent, populator, player, cost);
}

void SDKCall_DropCurrencyPack(int player, CurrencyRewards size = TF_CURRENCY_PACK_SMALL, int amount = 0, bool forceDistribute = false, int moneyMaker = -1)
{
	SDKCall(g_SDKCallDropCurrencyPack, player, size, amount, forceDistribute, moneyMaker);
}

bool SDKCall_CanRecieveMedigunChargeEffect(Address pShared, MedigunChargeType type)
{
	return SDKCall(g_SDKCallCanRecieveMedigunChargeEffect, pShared, type);
}

int SDKCall_ReviveMarkerCreate(int owner)
{
	return SDKCall(g_SDKCallReviveMarkerCreate, owner);
}

void SDKCall_RemoveImmediate(int entity)
{
	SDKCall(g_SDKCallRemoveImmediate, entity);
}

int SDKCall_CalculateCurrencyAmount_ByType(CurrencyRewards type)
{
	return SDKCall(g_SDKCallCalculateCurrencyAmount_ByType, type);
}

bool SDKCall_ShouldSwitchTeams()
{
	return SDKCall(g_SDKCallShouldSwitchTeams);
}

bool SDKCall_ShouldScrambleTeams()
{
	return SDKCall(g_SDKCallShouldScrambleTeams);
}

float SDKCall_GetNextRespawnWave(TFTeam team, int player)
{
	return SDKCall(g_SDKCallGetNextRespawnWave, team, player);
}
