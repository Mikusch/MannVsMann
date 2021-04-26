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

static MemoryPatch g_MemoryPatchRadiusCurrencyCollectionCheck;
static MemoryPatch g_MemoryPatchEventKilled;

void Patches_Initialize(GameData gamedata)
{
	MemoryPatch.SetGameData(gamedata);
	
	//Allows players not on RED to collect credits in a radius
	CreateMemoryPatch(g_MemoryPatchRadiusCurrencyCollectionCheck, "MemoryPatch_RadiusCurrencyCollectionCheck");
	
	//Prevents defender voice lines when another defender dies
	CreateMemoryPatch(g_MemoryPatchEventKilled, "MemoryPatch_EventKilled");
}

void Patches_Destroy()
{
	if (g_MemoryPatchRadiusCurrencyCollectionCheck)
		g_MemoryPatchRadiusCurrencyCollectionCheck.Disable();
	
	if (g_MemoryPatchEventKilled)
		g_MemoryPatchEventKilled.Disable();
}

static void CreateMemoryPatch(MemoryPatch &patch, const char[] name)
{
	patch = new MemoryPatch(name);
	if (patch)
		patch.Enable();
	else
		LogError("Failed to create memory patch %s", name);
}
