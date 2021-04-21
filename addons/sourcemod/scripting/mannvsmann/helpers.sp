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

bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}

TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Data, "m_iTeamNum"));
}

void TF2_SetTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Data, "m_iTeamNum", team);
}

any Min(any a, any b)
{
	return a < b ? a : b;
}

any Max(any a, any b)
{
	return a > b ? a : b;
}

any Clamp(any val, any min, any max)
{
	return Max(min, Min(max, val));
}

TFTeam MvM_GetClientTeam(int client)
{
	//Our CTFPlayerShared::RadiusCurrencyCollectionCheck detour might have moved the client's team
	return g_InRadiusCurrencyCollectionCheck ? g_PreRadiusCurrencyCollectionCheckTeam : TF2_GetClientTeam(client);
}
