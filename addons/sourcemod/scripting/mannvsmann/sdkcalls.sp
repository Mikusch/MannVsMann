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

static Handle g_SDKCallDropSingleInstance;

void SDKCalls_Initialize(GameData gamedata)
{
	g_SDKCallDropSingleInstance = PrepSDKCall_DropSingleInstance(gamedata);
}

Handle PrepSDKCall_DropSingleInstance(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPowerup::DropSingleInstance");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (call == null)
		LogMessage("Failed to create SDKCall: CTFPowerup::DropSingleInstance");
	
	return call;
}

void SDKCall_DropSingleInstance(int powerup, const float[3] launchVel, int thrower, float throwerTouchDelay, float resetTime = 0.1)
{
	if (g_SDKCallDropSingleInstance)
		SDKCall(g_SDKCallDropSingleInstance, powerup, launchVel, thrower, throwerTouchDelay, resetTime);
}
