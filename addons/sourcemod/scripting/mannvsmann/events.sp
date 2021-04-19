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

void Events_Initialize()
{
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
}

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//Create an upgrade station
	int regenerate = MaxClients + 1;
	while ((regenerate = FindEntityByClassname(regenerate, "func_regenerate")) != -1)
	{
		int upgrades = CreateEntityByName("func_upgradestation");
		if (IsValidEntity(upgrades))
		{
			float origin[3], mins[3], maxs[3];
			GetEntPropVector(regenerate, Prop_Data, "m_vecAbsOrigin", origin);
			GetEntPropVector(regenerate, Prop_Data, "m_vecMins", mins);
			GetEntPropVector(regenerate, Prop_Data, "m_vecMaxs", maxs);
			
			SetEntPropVector(upgrades, Prop_Send, "m_vecMins", mins);
			SetEntPropVector(upgrades, Prop_Send, "m_vecMaxs", maxs);
			TeleportEntity(upgrades, origin, NULL_VECTOR, NULL_VECTOR);
			
			SetEntityModel(upgrades, UPGRADE_STATION_MODEL);
			
			SetEntProp(upgrades, Prop_Send, "m_nSolidType", SOLID_BBOX);
			SetEntProp(upgrades, Prop_Send, "m_fEffects", (GetEntProp(upgrades, Prop_Send, "m_fEffects") | EF_NODRAW));
			
			if (DispatchSpawn(upgrades))
			{
				ActivateEntity(upgrades);
			}
		}
	}
	
	//Required for some upgrades to work
	CreateEntityByName("info_populator");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			SetEntProp(client, Prop_Send, "m_nCurrency", 10000);
		}
	}
}

public void Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	TF2Attrib_SetByName(1, "revive", 1.0);
}
