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
static DynamicHook g_DHookComeToRest;
static DynamicHook g_DHookValidTouch;
static DynamicHook g_DHookShouldRespawnQuickly;
static DynamicHook g_DHookRoundRespawn;

//Detour state
static bool g_PreHookIsMannVsMachineMode;
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
	//This function is very frequently called and we do not want to mess something up
	//Remember the state and set it back after this hook is done
	g_PreHookIsMannVsMachineMode = view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
	
	//Fixes various things related to applying upgrades
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_ApplyUpgradeToItem_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", g_PreHookIsMannVsMachineMode);
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
	//CBaseObject::ShouldQuickBuild might have called this and already handles enabling/disabling MvM
	g_PreHookIsMannVsMachineMode = view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
	
	//Engineers in MvM are allowed to quick-build during setup
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_IsQuickBuildTime_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", g_PreHookIsMannVsMachineMode);
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
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
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
				}
			}
		}
		else if (!params.IsNull(2))
		{
			//FIXME: The TF2 function doesn't call our hook for some reason and thus awards "temporary" currency
			LogError("NOT IMPLEMENTED: Non-shared currency was distributed to %N", params.Get(2));
		}
	}
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Post(DHookReturn ret, DHookParam params)
{
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				MvMPlayer(client).MoveToPreHookTeam();
			}
		}
	}
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Pre()
{
	//Allows the call to CTFPlayerShared::RadiusCurrencyCollectionCheck to happen
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
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
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		MvMPlayer(client).MoveToDefenderTeam();
	}
}

public MRESReturn DHookCallback_RemoveAllOwnedEntitiesFromWorld_Post(int client)
{
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		MvMPlayer(client).MoveToPreHookTeam();
	}
}

public MRESReturn DHookCallback_CanBuild_Pre()
{
	//Limits the amount of sappers that can be placed on players
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_CanBuild_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_ManageRegularWeapons_Pre()
{
	//Allows the call to CTFPlayer::ReapplyPlayerUpgrades to happen
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_ManageRegularWeapons_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_FindSnapToBuildPos_Pre(int obj)
{
	//Allows placing sappers on other players
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
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
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
	
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
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
	g_PreHookTeam = TF2_GetTeam(obj);
	TF2_SetTeam(obj, TF_TEAM_PVE_DEFENDERS);
}

public MRESReturn DHookCallback_ShouldQuickBuild_Post(int obj, DHookReturn ret)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
	
	TF2_SetTeam(obj, g_PreHookTeam);
}

public MRESReturn DHookCallback_CanPerformBackstabAgainstTarget_Pre(int knife, DHookReturn ret, DHookParam params)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
	//Players can backstab sapped players from any side
	int target = params.Get(1);
	MvMPlayer(target).MoveToInvaderTeam();
}

public MRESReturn DHookCallback_CanPerformBackstabAgainstTarget_Post(int knife, DHookReturn ret, DHookParam params)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
	
	int target = params.Get(1);
	MvMPlayer(target).MoveToPreHookTeam();
}

public MRESReturn DHookCallback_ComeToRest_Pre(int currencypack)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
	//CCurrencyPack::ComeToRest will call CTFGameRules::DistributeCurrencyAmount
	g_CurrencyPackTeam = TF2_GetTeam(currencypack);
}

public MRESReturn DHookCallback_ComeToRest_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
	
	g_CurrencyPackTeam = TFTeam_Invalid;
}

public MRESReturn DHookCallback_ValidTouch_Pre()
{
	//CTFPowerup::ValidTouch doesn't allow BLU team to collect money
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_ValidTouch_Post()
{
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Pre(DHookReturn ret, DHookParam params)
{
	int client = params.Get(1);
	
	//Buybacks call CTeamplayRoundBasedRules::GetNextRespawnWave which in turn calls this hook
	//Remember the state and set it back after this hook is done
	g_PreHookIsMannVsMachineMode = view_as<bool>(GameRules_GetProp("m_bPlayingMannVsMachine"));
	
	//Allow Scouts to respawn quickly
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
	//Circumvent hardcoded RED team check
	MvMPlayer(client).MoveToDefenderTeam();
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Post(DHookReturn ret, DHookParam params)
{
	int client = params.Get(1);
	
	GameRules_SetProp("m_bPlayingMannVsMachine", g_PreHookIsMannVsMachineMode);
	
	MvMPlayer(client).MoveToPreHookTeam();
}

public MRESReturn DHookCallback_RoundRespawn_Pre()
{
	//Combines the functionality of several event hooks
	//Required because teamplay_round_start fires right after the call to RoundRespawn, which is too late to reset player upgrades
	
	if (g_ForceMapReset)
	{
		g_ForceMapReset = !g_ForceMapReset;
		
		//Reset accumulated team credits
		for (TFTeam team = TFTeam_Unassigned; team <= TFTeam_Blue; team++)
		{
			MvMTeam(team).AcquiredCredits = 0;
		}
		
		int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
		if (populator != -1)
		{
			SDKCall_ResetMap(populator);
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					//Reset the currency spent statistic
					int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, client);
					SDKCall_AddPlayerCurrencySpent(populator, client, -spentCurrency);
					
					MvMPlayer(client).Currency = mvm_starting_currency.IntValue;
				}
			}
		}
	}
}
