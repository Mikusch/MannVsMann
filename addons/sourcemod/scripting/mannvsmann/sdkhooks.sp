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

void SDKHooks_HookCurrencyPack(int currencyPack)
{
	SDKHook(currencyPack, SDKHook_Touch, SDKHookCB_CurrencyPack_Touch);
	SDKHook(currencyPack, SDKHook_SetTransmit, SDKHookCB_CurrencyPack_SetTransmit);
}

public Action SDKHookCB_CurrencyPack_Touch(int entity, int other)
{
	if (!IsValidClient(other) || IsFakeClient(other))
		return;
	
	if (TF2_GetClientTeam(other) != TF2_GetTeam(entity))
		return;
	
	if (!GetEntProp(entity, Prop_Send, "m_bDistributed"))
	{
		DistributeCurrencyAmount(GetEntData(entity, g_OffsetCurrencyPackAmount), other);
	}
}

public Action SDKHookCB_CurrencyPack_SetTransmit(int entity, int client)
{
	if (TF2_GetTeam(entity) != TF2_GetClientTeam(client))
		return Plugin_Handled;
	
	return Plugin_Continue;
}
