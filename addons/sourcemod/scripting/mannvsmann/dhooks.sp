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
static TFTeam g_PreHookTeam;	//NOTE: For clients, use the MvMPlayer methodmap

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CUpgrades::ApplyUpgradeToItem", DHookCallback_ApplyUpgradeToItem_Pre, DHookCallback_ApplyUpgradeToItem_Post);
	CreateDynamicDetour(gamedata, "CPopulationManager::Update", DHookCallback_PopulationManagerUpdate_Pre, _);
	CreateDynamicDetour(gamedata, "CPopulationManager::ResetMap", DHookCallback_PopulationManagerResetMap_Pre, DHookCallback_PopulationManagerResetMap_Post);
	CreateDynamicDetour(gamedata, "CPopulationManager::RemovePlayerAndItemUpgradesFromHistory", DHookCallback_RemovePlayerAndItemUpgradesFromHistory_Pre, DHookCallback_RemovePlayerAndItemUpgradesFromHistory_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::IsQuickBuildTime", DHookCallback_IsQuickBuildTime_Pre, DHookCallback_IsQuickBuildTime_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::GameModeUsesUpgrades", _, DHookCallback_GameModeUsesUpgrades_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::CanPlayerUseRespec", DHookCallback_CanPlayerUseRespec_Pre, DHookCallback_CanPlayerUseRespec_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::DistributeCurrencyAmount", DHookCallback_DistributeCurrencyAmount_Pre, DHookCallback_DistributeCurrencyAmount_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::ConditionGameRulesThink", DHookCallback_ConditionGameRulesThink_Pre, DHookCallback_ConditionGameRulesThink_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::CanRecieveMedigunChargeEffect", DHookCallback_CanRecieveMedigunChargeEffect_Pre, DHookCallback_CanRecieveMedigunChargeEffect_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::RadiusSpyScan", DHookCallback_RadiusSpyScan_Pre, DHookCallback_RadiusSpyScan_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::RemoveAllOwnedEntitiesFromWorld", DHookCallback_RemoveAllOwnedEntitiesFromWorld_Pre, DHookCallback_RemoveAllOwnedEntitiesFromWorld_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::CanBuild", DHookCallback_CanBuild_Pre, DHookCallback_CanBuild_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::ManageRegularWeapons", DHookCallback_ManageRegularWeapons_Pre, DHookCallback_ManageRegularWeapons_Post);
	CreateDynamicDetour(gamedata, "CTFPlayer::RegenThink", DHookCallback_RegenThink_Pre, DHookCallback_RegenThink_Post);
	CreateDynamicDetour(gamedata, "CBaseObject::FindSnapToBuildPos", DHookCallback_FindSnapToBuildPos_Pre, DHookCallback_FindSnapToBuildPos_Post);
	CreateDynamicDetour(gamedata, "CBaseObject::ShouldQuickBuild", DHookCallback_ShouldQuickBuild_Pre, DHookCallback_ShouldQuickBuild_Post);
	CreateDynamicDetour(gamedata, "CObjectSapper::ApplyRoboSapperEffects", DHookCallback_ApplyRoboSapperEffects_Pre, DHookCallback_ApplyRoboSapperEffects_Post);
	
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
		g_DHookRoundRespawn.HookGamerules(Hook_Post, DHookCallback_RoundRespawn_Post);
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
	//This function has some special logic for MvM that we want
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_ApplyUpgradeToItem_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_PopulationManagerUpdate_Pre()
{
	//Prevents the populator from messing with the GC and allocating bots
	return MRES_Supercede;
}

public MRESReturn DHookCallback_PopulationManagerResetMap_Pre()
{
	//MvM defenders get their upgrades and stats reset on map reset, move all players to the defender team
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).SetTeam(TFTeam_Red);
		}
	}
}

public MRESReturn DHookCallback_PopulationManagerResetMap_Post()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).ResetTeam();
		}
	}
}

public MRESReturn DHookCallback_RemovePlayerAndItemUpgradesFromHistory_Pre(int populator, DHookParam params)
{
	//This function handles refunding currency and resetting upgrade history during a respec
	//Block this, as we already handle it ourselves in the respec menu handler
	SetMannVsMachineMode(false);
}

public MRESReturn DHookCallback_RemovePlayerAndItemUpgradesFromHistory_Post(int populator, DHookParam params)
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_IsQuickBuildTime_Pre()
{
	//Allows Engineers to quickbuild during setup
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_IsQuickBuildTime_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_GameModeUsesUpgrades_Post(DHookReturn ret)
{
	//Fixes various upgrades and enables a few MvM-related features
	ret.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Pre()
{
	//Enables respecs regardless of round state
	g_PreHookRoundState = GameRules_GetRoundState();
	GameRules_SetProp("m_iRoundState", RoundState_BetweenRounds);
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Post()
{
	GameRules_SetProp("m_iRoundState", g_PreHookRoundState);
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Pre(DHookReturn ret, DHookParam params)
{
	if (IsMannVsMachineMode())
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
						MvMPlayer(client).SetTeam(TFTeam_Red);
					}
					else
					{
						MvMPlayer(client).SetTeam(TFTeam_Blue);
					}
					
					EmitSoundToClient(client, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
				}
			}
		}
		else if (!params.IsNull(2))
		{
			int player = params.Get(2);
			
			EmitSoundToClient(player, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
		}
	}
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Post(DHookReturn ret, DHookParam params)
{
	if (IsMannVsMachineMode())
	{
		bool shared = params.Get(3);
		
		if (shared)
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					MvMPlayer(client).ResetTeam();
				}
			}
		}
	}
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Pre()
{
	//Enables radius currency collection, radius spy scan and increased rage gain during setup
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_CanRecieveMedigunChargeEffect_Pre()
{
	//MvM allows flag carriers to be ubered, we don't want this (enabled from CTFPlayerShared::ConditionGameRulesThink)
	SetMannVsMachineMode(false);
}

public MRESReturn DHookCallback_CanRecieveMedigunChargeEffect_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_RadiusSpyScan_Pre(Address playerShared)
{
	int outer = GetPlayerSharedOuter(playerShared);
	
	TFTeam team = TF2_GetClientTeam(outer);
	
	//RadiusSpyScan only allows defenders to see invaders, move all teammates to the defender team and enemies to the invader team
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (client == outer)
			{
				MvMPlayer(client).SetTeam(TFTeam_Red);
			}
			else
			{
				if (TF2_GetClientTeam(client) == team)
				{
					MvMPlayer(client).SetTeam(TFTeam_Red);
				}
				else
				{
					MvMPlayer(client).SetTeam(TFTeam_Blue);
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
			MvMPlayer(client).ResetTeam();
		}
	}
}

public MRESReturn DHookCallback_RemoveAllOwnedEntitiesFromWorld_Pre(int client)
{
	//MvM invaders are allowed to keep their buildings and we don't want that, move the player to the defender team
	if (IsMannVsMachineMode())
	{
		MvMPlayer(client).SetTeam(TFTeam_Red);
	}
}

public MRESReturn DHookCallback_RemoveAllOwnedEntitiesFromWorld_Post(int client)
{
	if (IsMannVsMachineMode())
	{
		MvMPlayer(client).ResetTeam();
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

public MRESReturn DHookCallback_RegenThink_Pre()
{
	//Health regeneration has no scaling in MvM
	SetMannVsMachineMode(true);
}

public MRESReturn DHookCallback_RegenThink_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_FindSnapToBuildPos_Pre(int obj)
{
	//Allows placing sappers on other players
	SetMannVsMachineMode(true);
	
	int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
	
	//The robot sapper only works on bots, give every player the fake client flag
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
	
	//Sentries owned by MvM defenders can be re-deployed quickly, move the sentry to the defender team
	g_PreHookTeam = TF2_GetTeam(obj);
	TF2_SetTeam(obj, TFTeam_Red);
}

public MRESReturn DHookCallback_ShouldQuickBuild_Post(int obj, DHookReturn ret)
{
	ResetMannVsMachineMode();
	
	TF2_SetTeam(obj, g_PreHookTeam);
}

public MRESReturn DHookCallback_ApplyRoboSapperEffects_Pre(int sapper, DHookReturn ret, DHookParam params)
{
	int target = params.Get(1);
	
	//Minibosses in MvM get slowed down instead of fully stunned
	SetEntProp(target, Prop_Send, "m_bIsMiniBoss", true);
}

public MRESReturn DHookCallback_ApplyRoboSapperEffects_Post(int sapper, DHookReturn ret, DHookParam params)
{
	int target = params.Get(1);
	
	SetEntProp(target, Prop_Send, "m_bIsMiniBoss", false);
}

public MRESReturn DHookCallback_MyTouch_Pre(int currencypack, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	//NOTE: You cannot substitute this virtual hook with SDKHooks because the Touch function for CItem is actually CItem::ItemTouch, and NOT CItem::MyTouch.
	//CItem::ItemTouch simply calls CItem::MyTouch and deletes the entity if it returns true, which causes a TouchPost SDKHook to never get called!
	
	//Allows Scouts to gain health from currency packs and distributes the currency
	SetMannVsMachineMode(true);
	
	//Enables money pickup voice lines
	SetVariantString("IsMvMDefender:1");
	AcceptEntityInput(player, "AddContext");
}

public MRESReturn DHookCallback_MyTouch_Post(int currencypack, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	ResetMannVsMachineMode();
	
	SetVariantString("IsMvMDefender");
	AcceptEntityInput(player, "RemoveContext");
}

public MRESReturn DHookCallback_ComeToRest_Pre(int currencypack)
{
	//Enable MvM for currency distribution
	SetMannVsMachineMode(true);
	
	//Set the currency pack team for distribution
	g_CurrencyPackTeam = TF2_GetTeam(currencypack);
}

public MRESReturn DHookCallback_ComeToRest_Post()
{
	ResetMannVsMachineMode();
	
	g_CurrencyPackTeam = TFTeam_Invalid;
}

public MRESReturn DHookCallback_ValidTouch_Pre()
{
	//MvM invaders are not allowed to collect money
	//We are disabling MvM instead of swapping teams because ValidTouch also checks the player's team against the currency pack's team
	SetMannVsMachineMode(false);
}

public MRESReturn DHookCallback_ValidTouch_Post()
{
	ResetMannVsMachineMode();
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Pre(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	//Enables quick respawn for Scouts
	SetMannVsMachineMode(true);
	
	//MvM defenders are allowed to respawn quickly, move the player to the defender team
	MvMPlayer(player).SetTeam(TFTeam_Red);
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Post(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	ResetMannVsMachineMode();
	
	MvMPlayer(player).ResetTeam();
}

public MRESReturn DHookCallback_RoundRespawn_Pre()
{
	//NOTE: It is too late to run this logic in a teamplay_round_start event hook
	//since it depends on the state of the round before the call to RoundRespawn.
	
	//Switch team credits if the teams are being switched
	if (SDKCall_ShouldSwitchTeams())
	{
		int redCredits = MvMTeam(TFTeam_Red).AcquiredCredits;
		int blueCredits = MvMTeam(TFTeam_Blue).AcquiredCredits;
		
		MvMTeam(TFTeam_Red).AcquiredCredits = blueCredits;
		MvMTeam(TFTeam_Blue).AcquiredCredits = redCredits;
	}
	
	int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
	if (populator != -1)
	{
		if (g_ForceMapReset)
		{
			g_ForceMapReset = false;
			
			//Reset accumulated team credits on a full reset
			MvMTeam(TFTeam_Red).AcquiredCredits = 0;
			MvMTeam(TFTeam_Blue).AcquiredCredits = 0;
			
			//Reset currency for all clients
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, client);
					SDKCall_AddPlayerCurrencySpent(populator, client, -spentCurrency);
					MvMPlayer(client).Currency = mvm_currency_starting.IntValue;
				}
			}
			
			//Reset player and item upgrades
			SDKCall_ResetMap(populator);
		}
		else
		{
			//Retain player upgrades (forces a call to CTFPlayer::ReapplyPlayerUpgrades)
			SetEntData(populator, g_OffsetRestoringCheckpoint, true);
		}
	}
}

public MRESReturn DHookCallback_RoundRespawn_Post()
{
	int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
	if (populator != -1)
	{
		SetEntData(populator, g_OffsetRestoringCheckpoint, false);
	}
}
