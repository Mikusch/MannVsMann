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

static DynamicHook g_DHookComeToRest;

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CTFGameRules::GameModeUsesUpgrades", _, DHookCallback_GameModeUsesUpgrades_Post);
	
	g_DHookComeToRest = CreateDynamicHook(gamedata, "CItem::ComeToRest");
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "item_currencypack") != -1)
	{
		g_DHookComeToRest.HookEntity(Hook_Pre, entity, DHookCallback_ComeToRestPre);
	}
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour != null)
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);
		
		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}

static DynamicHook CreateDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (hook == null)
		LogError("Failed to create hook setup handle for %s", name);
	
	return hook;
}

public MRESReturn DHookCallback_GameModeUsesUpgrades_Post(Address gamerules, DHookReturn ret)
{
	//Fixes multiple upgrades not working outside of MvM
	ret.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHookCallback_ComeToRestPre(int item)
{
	//Currency packs will get removed if they land in areas with no nav mesh
	return MRES_Supercede;
}
