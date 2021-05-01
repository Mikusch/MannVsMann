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

//Dynamic hook handles
static DynamicHook g_DHookMyTouch;
static DynamicHook g_DHookComeToRest;
static DynamicHook g_DHookValidTouch;
static DynamicHook g_DHookShouldRespawnQuickly;
static DynamicHook g_DHookRoundRespawn;

//Detour state
static RoundState g_PreHookRoundState;
static TFTeam g_PreHookTeam;	//Note: For clients, use the MvMPlayer methodmap

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CUpgrades::ApplyUpgradeToItem", DHookCallback_ApplyUpgradeToItem_Pre, DHookCallback_ApplyUpgradeToItem_Post);
	CreateDynamicDetour(gamedata, "CPopulationManager::Update", DHookCallback_PopulationManagerUpdate_Pre, _);
	CreateDynamicDetour(gamedata, "CPopulationManager::ResetMap", DHookCallback_PopulationManagerResetMap_Pre, DHookCallback_PopulationManagerResetMap_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::IsQuickBuildTime", DHookCallback_IsQuickBuildTime_Pre, DHookCallback_IsQuickBuildTime_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::GameModeUsesUpgrades", _, DHookCallback_GameModeUsesUpgrades_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::CanPlayerUseRespec", DHookCallback_CanPlayerUseRespec_Pre, DHookCallback_CanPlayerUseRespec_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::DistributeCurrencyAmount", DHookCallback_DistributeCurrencyAmount_Pre, DHookCallback_DistributeCurrencyAmount_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::ConditionGameRulesThink", DHookCallback_ConditionGameRulesThink_Pre, DHookCallback_ConditionGameRulesThink_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::RadiusSpyScan", DHookCallback_RadiusSpyScan_Pre, DHookCallback_RadiusSpyScan_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::RemoveAllOwnedEntitiesFromWorld", DHookCallback_RemoveAllOwnedEntitiesFromWorld_Pre, DHookCallback_RemoveAllOwnedEntitiesFromWorld_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::CanBuild", DHookCallback_CanBuild_Pre, DHookCallback_CanBuild_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::ManageRegularWeapons", DHookCallback_ManageRegularWeapons_Pre, DHookCallback_ManageRegularWeapons_Post);
	CreateDynamicDetour(gamedata, "CBaseObject::FindSnapToBuildPos", DHookCallback_FindSnapToBuildPos_Pre, DHookCallback_FindSnapToBuildPos_Post);
	CreateDynamicDetour(gamedata, "CBaseObject::ShouldQuickBuild", DHookCallback_ShouldQuickBuild_Pre, DHookCallback_ShouldQuickBuild_Post);
	CreateDynamicDetour(gamedata, "CTFKnife::CanPerformBackstabAgainstTarget", DHookCallback_CanPerformBackstabAgainstTarget_Pre, DHookCallback_CanPerformBackstabAgainstTarget_Post);
	
	g_DHookMyTouch = CreateDynamicHook(gamedata, "CCurrencyPack::MyTouch");
	g_DHookComeToRest = CreateDynamicHook(gamedata, "CCurrencyPack::ComeToRest");
	g_DHookValidTouch = CreateDynamicHook(gamedata, "CTFPowerup::ValidTouch");
	g_DHookShouldRespawnQuickly = CreateDynamicHook(gamedata, "CTFGameRules::ShouldRespawnQuickly");
	g_DHookRoundRespawn = CreateDynamicHook(gamedata, "CTFGameRules::RoundRespawn");
}

void DHooks_HookGameRules()
{
	if (g_DHookShouldRespawnQuickly)
	{
		g_DHookShouldRespawnQuickly.HookGamerules(Hook_Pre, DHookCallback_ShouldRespawnQuickly_Pre);
		g_DHookShouldRespawnQuickly.HookGamerules(Hook_Post, DHookCallback_ShouldRespawnQuickly_Post);
	}
	
	if (g_DHookRoundRespawn)
	{
		g_DHookRoundRespawn.HookGamerules(Hook_Pre, DHookCallback_RoundRespawn_Pre);
	}
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		if (g_DHookMyTouch)
		{
			g_DHookMyTouch.HookEntity(Hook_Pre, entity, DHookCallback_MyTouch_Pre);
			g_DHookMyTouch.HookEntity(Hook_Post, entity, DHookCallback_MyTouch_Post);
		}
		
		if (g_DHookComeToRest)
		{
			g_DHookComeToRest.HookEntity(Hook_Pre, entity, DHookCallback_ComeToRest_Pre);
			g_DHookComeToRest.HookEntity(Hook_Post, entity, DHookCallback_ComeToRest_Post);
		}
		
		if (g_DHookValidTouch)
		{
			g_DHookValidTouch.HookEntity(Hook_Pre, entity, DHookCallback_ValidTouch_Pre);
			g_DHookValidTouch.HookEntity(Hook_Post, entity, DHookCallback_ValidTouch_Post);
		}
	}
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
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
	if (!hook)
		LogError("Failed to create hook setup handle for %s", name);
	
	return hook;
}

public MRESReturn DHookCallback_ApplyUpgradeToItem_Pre()
{
	//Fixes various things related to applying upgrades
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_ApplyUpgradeToItem_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_PopulationManagerUpdate_Pre()
{
	//Prevent the populator doing unwanted stuff, like a call to CPopulationManager::AllocateBots
	return MRES_Supercede;
}

public MRESReturn DHookCallback_PopulationManagerResetMap_Pre()
{
	//CPopulationManager::ResetMap resets upgrades for RED team only
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).MoveToDefenderTeam();
		}
	}
}

public MRESReturn DHookCallback_PopulationManagerResetMap_Post()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).MoveToPreHookTeam();
		}
	}
}

public MRESReturn DHookCallback_IsQuickBuildTime_Pre()
{
	//Engineers in MvM are allowed to quick-build during setup
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_IsQuickBuildTime_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_GameModeUsesUpgrades_Post(DHookReturn ret)
{
	//Fixes various upgrades and enables MvM-related features
	ret.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Pre()
{
	//Allow respecs regardless of round state
	g_PreHookRoundState = GameRules_GetRoundState();
	GameRules_SetProp("m_iRoundState", RoundState_BetweenRounds);
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Post()
{
	GameRules_SetProp("m_iRoundState", g_PreHookRoundState);
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Pre(DHookReturn ret, DHookParam params)
{
	SetMannVsMachineMode(true);
	int amount = params.Get(1);
	bool shared = params.Get(3);
	
	if (shared)
	{
		//If the player is NULL, take the value of g_CurrencyPackTeam because our code has likely set it to something
		TFTeam team = params.IsNull(2) ? g_CurrencyPackTeam : TF2_GetClientTeam(params.Get(2));
		
		MvMTeam(team).AcquiredCredits += amount;
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				if (TF2_GetClientTeam(client) == team)
				{
					MvMPlayer(client).MoveToDefenderTeam();
				}
				else
				{
					MvMPlayer(client).MoveToInvaderTeam();
				}
				
				EmitSoundToClient(client, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
			}
		}
	}
	else if (!params.IsNull(2))
	{
		//FIXME: The TF2 function doesn't call our hook for some reason and thus awards "temporary" currency
		LogError("NOT IMPLEMENTED: Non-shared currency was distributed to %N", params.Get(2));
		
		EmitSoundToClient(params.Get(2), SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
	}
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Post(DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).MoveToPreHookTeam();
		}
	}
	
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Pre()
{
	//Allows the call to CTFPlayerShared::RadiusCurrencyCollectionCheck to happen
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_RadiusSpyScan_Pre(Address playerShared)
{
	int outer = TF2_GetPlayerSharedOuter(playerShared);
	
	TFTeam team = TF2_GetClientTeam(outer);
	
	//RadiusSpyScan only allows defenders to see invaders, so move all teammates to defenders and enemies to invaders
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (client == outer)
			{
				MvMPlayer(client).MoveToDefenderTeam();
			}
			else
			{
				if (TF2_GetClientTeam(client) == team)
				{
					MvMPlayer(client).MoveToDefenderTeam();
				}
				else
				{
					MvMPlayer(client).MoveToInvaderTeam();
				}
			}
		}
	}
}

public MRESReturn DHookCallback_RadiusSpyScan_Post(Address playerShared)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).MoveToPreHookTeam();
		}
	}
}

public MRESReturn DHookCallback_RemoveAllOwnedEntitiesFromWorld_Pre(int client)
{
	//Invaders in MvM are allowed to keep their buildings, we don't want that
	if (IsMannVsMachineMode())
	{
		MvMPlayer(client).MoveToDefenderTeam();
	}
}

public MRESReturn DHookCallback_RemoveAllOwnedEntitiesFromWorld_Post(int client)
{
	if (IsMannVsMachineMode())
	{
		MvMPlayer(client).MoveToPreHookTeam();
	}
}

public MRESReturn DHookCallback_CanBuild_Pre()
{
	//Limits the amount of sappers that can be placed on players
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_CanBuild_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_ManageRegularWeapons_Pre()
{
	//Allows the call to CTFPlayer::ReapplyPlayerUpgrades to happen
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_ManageRegularWeapons_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_FindSnapToBuildPos_Pre(int obj)
{
	//Allows placing sappers on other players
	SetMannVsMachineMode(true);
	
	int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
	
	//Robot Sapper only works on bots so give everyone the fake client flag
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && client != builder)
		{
			SetEntityFlags(client, GetEntityFlags(client) | FL_FAKECLIENT);
		}
	}
}

public MRESReturn DHookCallback_FindSnapToBuildPos_Post(int obj)
{
	ResetMannVsMachineMode();
	
	int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && client != builder)
		{
			SetEntityFlags(client, GetEntityFlags(client) & ~FL_FAKECLIENT);
		}
	}
}

public MRESReturn DHookCallback_ShouldQuickBuild_Pre(int obj)
{
	SetMannVsMachineMode(true);
	
	g_PreHookTeam = TF2_GetTeam(obj);
	TF2_SetTeam(obj, TF_TEAM_PVE_DEFENDERS);
}

public MRESReturn DHookCallback_ShouldQuickBuild_Post(int obj, DHookReturn ret)
{
	ResetMannVsMachineMode();
	
	TF2_SetTeam(obj, g_PreHookTeam);
}

public MRESReturn DHookCallback_CanPerformBackstabAgainstTarget_Pre(int knife, DHookReturn ret, DHookParam params)
{
	SetMannVsMachineMode(true);
	
	//Players can backstab sapped players from any side
	int target = params.Get(1);
	MvMPlayer(target).MoveToInvaderTeam();
}

public MRESReturn DHookCallback_CanPerformBackstabAgainstTarget_Post(int knife, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	int target = params.Get(1);
	MvMPlayer(target).MoveToPreHookTeam();
}

public MRESReturn DHookCallback_MyTouch_Pre(int currencypack)
{
	//You may be wondering why I didn't just use SDKHook_Touch and SDKHook_TouchPost for this.
	//
	//Well, the Touch function for CItem is actually CItem::ItemTouch, and NOT CItem::MyTouch.
	//ItemTouch merely calls MyTouch and deletes the entity if MyTouch returns true, which means that a TouchPost hook callback will never get called.
	//We are hooking the virtual function MyTouch directly to be able to properly disable MvM. Thanks Valve.
	
	//Allows Scouts to gain health and calls CTFGameRules::DistributeCurrencyAmount
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_MyTouch_Post(int currencypack)
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_ComeToRest_Pre(int currencypack)
{
	//CCurrencyPack::ComeToRest will call CTFGameRules::DistributeCurrencyAmount
	g_CurrencyPackTeam = TF2_GetTeam(currencypack);
}

public MRESReturn DHookCallback_ComeToRest_Post()
{
	g_CurrencyPackTeam = TFTeam_Invalid;
}

public MRESReturn DHookCallback_ValidTouch_Pre()
{
	//CTFPowerup::ValidTouch doesn't allow BLU team to collect money
	SetMannVsMachineMode(false);
}

public MRESReturn DHookCallback_ValidTouch_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Pre(DHookReturn ret, DHookParam params)
{
	int client = params.Get(1);
	
	//Allow Scouts to respawn quickly
	SetMannVsMachineMode(true);
	
	//Circumvent hardcoded RED team check
	MvMPlayer(client).MoveToDefenderTeam();
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Post(DHookReturn ret, DHookParam params)
{
	int client = params.Get(1);
	
	ResetMannVsMachineMode();
	
	MvMPlayer(client).MoveToPreHookTeam();
}

public MRESReturn DHookCallback_RoundRespawn_Pre()
{
	//Too late to do this in teamplay_round_start since that event fires after RoundRespawn
	
	if (g_ForceMapReset)
	{
		g_ForceMapReset = !g_ForceMapReset;
		
		int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
		if (populator != -1)
		{
			SDKCall_ResetMap(populator);
		}
	}
}
