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

void Commands_Init()
{
	RegAdminCmd("sm_currency_give", ConCmd_GiveCurrency, ADMFLAG_CHEATS, "Have some in-game money.");
}

static Action ConCmd_GiveCurrency(int client, int args)
{
	if (!PSM_IsEnabled())
		return Plugin_Continue;
	
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_currency_give <#userid|name> <amount>");
		return Plugin_Handled;
	}
	
	char arg1[MAX_TARGET_LENGTH], arg2[16];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	int amount = 0;
	if (StringToIntEx(arg2, amount) == 0 || amount == 0)
	{
		ReplyToCommand(client, "[SM] %t", "Invalid Amount");
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(arg1, client, target_list, sizeof(target_list), 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		int target = target_list[i];
		MvMPlayer(target).Currency += amount;
	}
	
	char formattedAmount[16];
	FormatCurrencyAmount(amount, formattedAmount, sizeof(formattedAmount));
	
	if (tn_is_ml)
	{
		ShowActivity2(client, "[SM] ", "%t", "MvM_CurrencyAdded", formattedAmount, target_name);
	}
	else
	{
		ShowActivity2(client, "[SM] ", "%t", "MvM_CurrencyAdded", formattedAmount, "_s", target_name);
	}
	
	return Plugin_Handled;
}
