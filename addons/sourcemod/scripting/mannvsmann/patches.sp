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

static ArrayList g_MemoryPatches;

void Patches_Init(GameData gamedata)
{
	g_MemoryPatches = new ArrayList();
	
	Patches_AddMemoryPatch(gamedata, "CTFPlayerShared::RadiusCurrencyCollectionCheck::AllowAllTeams");
}

void Patches_Toggle(bool enable)
{
	for (int i = 0; i < g_MemoryPatches.Length; i++)
	{
		MemoryPatch patch = g_MemoryPatches.Get(i);
		if (patch)
		{
			if (enable)
			{
				patch.Enable();
			}
			else
			{
				patch.Disable();
			}
		}
	}
}

static void Patches_AddMemoryPatch(GameData gamedata, const char[] name)
{
	MemoryPatch patch = MemoryPatch.CreateFromConf(gamedata, name);
	if (patch.Validate())
	{
		g_MemoryPatches.Push(patch);
	}
	else
	{
		LogError("Failed to validate memory patch %s", name);
	}
}
