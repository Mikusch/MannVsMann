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
static DynamicHook g_DHookValidTouch;
static DynamicHook g_DHookEventKilled;

static RoundState g_OldRoundState;

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CTFGameRules::GameModeUsesUpgrades", _, DHookCallback_GameModeUsesUpgrades_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::CanPlayerUseRespec", DHookCallback_CanPlayerUseRespec_Pre, DHookCallback_CanPlayerUseRespec_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::IsQuickBuildTime", DHookCallback_IsQuickBuildTime_Pre, DHookCallback_IsQuickBuildTime_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::ConditionGameRulesThink", DHookCallback_ConditionGameRulesThink_Pre, DHookCallback_ConditionGameRulesThink_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::RadiusCurrencyCollectionCheck", DHookCallback_RadiusCurrencyCollectionCheck_Pre, DHookCallback_RadiusCurrencyCollectionCheck_Post);
	
	g_DHookComeToRest = CreateDynamicHook(gamedata, "CItem::ComeToRest");
	g_DHookValidTouch = CreateDynamicHook(gamedata, "CTFPowerup::ValidTouch");
	g_DHookEventKilled = CreateDynamicHook(gamedata, "CTFPlayer::Event_Killed");
}

void DHooks_HookClient(int client)
{
	g_DHookEventKilled.HookEntity(Hook_Pre, client, DHookCallback_EventKilled_Pre);
	g_DHookEventKilled.HookEntity(Hook_Post, client, DHookCallback_EventKilled_Post);
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "item_currencypack") != -1)
	{
		g_DHookComeToRest.HookEntity(Hook_Pre, entity, DHookCallback_ComeToRestPre);
		
		g_DHookValidTouch.HookEntity(Hook_Pre, entity, DHookCallback_ValidTouch_Pre);
		g_DHookValidTouch.HookEntity(Hook_Post, entity, DHookCallback_ValidTouch_Post);
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

public MRESReturn DHookCallback_GameModeUsesUpgrades_Post(DHookReturn ret)
{
	//Fixes multiple upgrades not working outside of MvM
	ret.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Pre()
{
	//Allows respecs by making the game think it is MvM pre-round
	g_OldRoundState = GameRules_GetRoundState();
	GameRules_SetProp("m_iRoundState", RoundState_BetweenRounds);
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Post()
{
	GameRules_SetProp("m_iRoundState", g_OldRoundState);
}

public MRESReturn DHookCallback_ComeToRestPre(int item)
{
	//Currency packs will get removed if they land in areas with no nav mesh
	return MRES_Supercede;
}

public MRESReturn DHookCallback_ValidTouch_Pre(int powerup, DHookReturn ret, DHookParam params)
{
	if (g_InRadiusCurrencyCollectionCheck)
	{
		//Allow both teams to collect money using RadiusCurrencyCollectionCheck
		int client = params.Get(1);
		SetEntProp(client, Prop_Data, "m_iTeamNum", g_OldTeamNum);
	}
	
	//CTFPowerup::ValidTouch doesn't allow TF_TEAM_PVE_INVADERS to collect money
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_ValidTouch_Post(int powerup, DHookReturn ret, DHookParam params)
{
	if (g_InRadiusCurrencyCollectionCheck)
	{
		int client = params.Get(1);
		SetEntProp(client, Prop_Data, "m_iTeamNum", TF_TEAM_PVE_DEFENDERS);
	}
	
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_EventKilled_Pre(int client)
{
	//Creates revive markers on player death
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_EventKilled_Post(int client)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_IsQuickBuildTime_Pre()
{
	//Allows quickbuilding during setup
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_IsQuickBuildTime_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Pre()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_RadiusCurrencyCollectionCheck_Pre(Address playerShared)
{
	g_InRadiusCurrencyCollectionCheck = true;
	
	Address outer = view_as<Address>(LoadFromAddress(playerShared + view_as<Address>(g_OffsetOuter), NumberType_Int32));
	int client = SDKCall_GetBaseEntity(outer);
	
	//Radius currency collection is hardcoded to only work for the RED team
	g_OldTeamNum = GetClientTeam(client);
	SetEntProp(client, Prop_Data, "m_iTeamNum", TF_TEAM_PVE_DEFENDERS);
}

public MRESReturn DHookCallback_RadiusCurrencyCollectionCheck_Post(Address playerShared)
{
	g_InRadiusCurrencyCollectionCheck = false;
	
	Address outer = view_as<Address>(LoadFromAddress(playerShared + view_as<Address>(g_OffsetOuter), NumberType_Int32));
	int client = SDKCall_GetBaseEntity(outer);
	
	SetEntProp(client, Prop_Data, "m_iTeamNum", g_OldTeamNum);
}
