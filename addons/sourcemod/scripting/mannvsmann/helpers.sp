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

bool WeaponID_IsSniperRifle(int weaponID)
{
	if (weaponID == TF_WEAPON_SNIPERRIFLE || 
		weaponID == TF_WEAPON_SNIPERRIFLE_DECAP || 
		weaponID == TF_WEAPON_SNIPERRIFLE_CLASSIC)
	return true;
	else
		return false;
}

bool WeaponID_IsSniperRifleOrBow(int weaponID)
{
	if (weaponID == TF_WEAPON_COMPOUND_BOW)
		return true;
	else
		return WeaponID_IsSniperRifle(weaponID);
}

any Max(any a, any b)
{
	return a > b ? a : b;
}

void RandomVector(float min, float max, float buffer[3])
{
	for (int i = 0; i < sizeof(buffer); i++)
	{
		buffer[i] = GetRandomFloat(min, max);
	}
}

void WorldSpaceCenter(int entity, float[3] buffer)
{
	float origin[3], mins[3], maxs[3], offset[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);
	
	AddVectors(mins, maxs, offset);
	ScaleVector(offset, 0.5);
	
	AddVectors(origin, offset, buffer);
}

bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}

stock TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Data, "m_iTeamNum"));
}
