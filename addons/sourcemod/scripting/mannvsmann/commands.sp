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

void Commands_Initialize()
{
	RegConsoleCmd("sm_respec", ConCmd_Respec, "Refunds all player and item upgrades");
	RegConsoleCmd("sm_refund", ConCmd_Respec, "Refunds all player and item upgrades");
}


public Action ConCmd_Respec(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "%t", "MvM_Command_PlayerNotAlive");
		return Plugin_Handled;
	}
	
	float origin[3];
	GetClientAbsOrigin(client, origin);
	
	bool inRespawnRoom;
	
	int respawnroom = MaxClients + 1;
	while ((respawnroom = FindEntityByClassname(respawnroom, "func_respawnroom")) != -1)
	{
		TR_ClipRayToEntity(origin, origin, MASK_ALL, RayType_EndPoint, respawnroom);
		if (TR_StartSolid())
		{
			inRespawnRoom = true;
			break;
		}
	}
	
	if (!inRespawnRoom)
	{
		ReplyToCommand(client, "%t", "MvM_Command_PlayerNotInRespawnRoom");
		return Plugin_Handled;
	}
	
	MvMPlayer(client).RefundAllUpgrades();
	MvMPlayer(client).Currency = MvMTeam(TF2_GetClientTeam(client)).AcquiredCredits + mvm_start_credits.IntValue;
	
	return Plugin_Handled;
}
