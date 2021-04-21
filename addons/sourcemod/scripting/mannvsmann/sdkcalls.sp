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

static Handle g_SDKCallGetBaseEntity;
static Handle g_SDKCallGetNextRespawnWave;
static Handle g_SDKCallDropCurrencyPack;

void SDKCalls_Initialize(GameData gamedata)
{
	g_SDKCallGetBaseEntity = PrepSDKCall_GetBaseEntity(gamedata);
	g_SDKCallGetNextRespawnWave = PrepSDKCall_GetNextRespawnWave(gamedata);
	g_SDKCallDropCurrencyPack = PrepSDKCall_DropCurrencyPack(gamedata);
}

Handle PrepSDKCall_GetBaseEntity(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::GetBaseEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (call == null)
		LogMessage("Failed to create SDKCall: CBaseEntity::GetBaseEntity");
	
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

int SDKCall_GetBaseEntity(Address address)
{
	if (g_SDKCallGetBaseEntity)
		return SDKCall(g_SDKCallGetBaseEntity, address);
	
	return -1;
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
