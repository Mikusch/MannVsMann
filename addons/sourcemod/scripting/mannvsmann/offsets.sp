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

static StringMap g_Offsets;

void Offsets_Init(GameData gamedata)
{
	g_Offsets = new StringMap();
	
	SetOffset(gamedata, "CTFPlayer", "m_hReviveMarker");
	SetOffset(gamedata, "CCurrencyPack", "m_nAmount");
	SetOffset(gamedata, "CPopulationManager", "m_isRestoringCheckpoint");
}

any GetOffset(const char[] cls, const char[] prop)
{
	char key[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	
	int offset;
	if (!g_Offsets.GetValue(key, offset))
	{
		ThrowError("Offset '%s' not present in map", key);
	}
	
	return offset;
}

static void SetOffset(GameData gamedata, const char[] cls, const char[] prop)
{
	char key[64], base_key[64], base_prop[64];
	Format(key, sizeof(key), "%s::%s", cls, prop);
	Format(base_key, sizeof(base_key), "%s_BaseOffset", cls);
	
	// Get the actual offset, calculated using a base offset if present
	if (gamedata.GetKeyValue(base_key, base_prop, sizeof(base_prop)))
	{
		int base_offset = FindSendPropInfo(cls, base_prop);
		if (base_offset == -1)
		{
			// If we found nothing, search on CBaseEntity instead
			base_offset = FindSendPropInfo("CBaseEntity", base_prop);
			if (base_offset == -1)
			{
				ThrowError("Base offset '%s::%s' could not be found", cls, base_prop);
			}
		}
		
		int offset = base_offset + gamedata.GetOffset(key);
		g_Offsets.SetValue(key, offset);
	}
	else
	{
		int offset = gamedata.GetOffset(key);
		if (offset == -1)
		{
			ThrowError("Offset '%s' could not be found", key);
		}
		
		g_Offsets.SetValue(key, offset);
	}
}
