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

enum struct DetourData
{
	DynamicDetour detour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

// Detours and virtual hooks IDs
static ArrayList g_DynamicDetours;
static ArrayList g_DynamicHookIds;

// Dynamic hook handles
static DynamicHook g_DHookMyTouch;
static DynamicHook g_DHookComeToRest;
static DynamicHook g_DHookValidTouch;
static DynamicHook g_DHookSetWinningTeam;
static DynamicHook g_DHookShouldRespawnQuickly;
static DynamicHook g_DHookRoundRespawn;
static DynamicHook g_DHookCheckRespawnWaves;

// Detour state
static RoundState g_PreHookRoundState;
static TFTeam g_PreHookTeam;	// For clients, use the MvMPlayer methodmap

void DHooks_Initialize(GameData gamedata)
{
	g_DynamicDetours = new ArrayList(sizeof(DetourData));
	g_DynamicHookIds = new ArrayList();
	
	// Create detours
	DHooks_AddDynamicDetour(gamedata, "CUpgrades::ApplyUpgradeToItem", DHookCallback_ApplyUpgradeToItem_Pre, DHookCallback_ApplyUpgradeToItem_Post);
	DHooks_AddDynamicDetour(gamedata, "CPopulationManager::Update", DHookCallback_PopulationManagerUpdate_Pre, _);
	DHooks_AddDynamicDetour(gamedata, "CPopulationManager::ResetMap", DHookCallback_PopulationManagerResetMap_Pre, DHookCallback_PopulationManagerResetMap_Post);
	DHooks_AddDynamicDetour(gamedata, "CPopulationManager::RemovePlayerAndItemUpgradesFromHistory", DHookCallback_RemovePlayerAndItemUpgradesFromHistory_Pre, DHookCallback_RemovePlayerAndItemUpgradesFromHistory_Post);
	DHooks_AddDynamicDetour(gamedata, "CCaptureFlag::Capture", DHookCallback_Capture_Pre, DHookCallback_Capture_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFGameRules::IsQuickBuildTime", DHookCallback_IsQuickBuildTime_Pre, DHookCallback_IsQuickBuildTime_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFGameRules::GameModeUsesUpgrades", _, DHookCallback_GameModeUsesUpgrades_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFGameRules::CanPlayerUseRespec", DHookCallback_CanPlayerUseRespec_Pre, DHookCallback_CanPlayerUseRespec_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFGameRules::DistributeCurrencyAmount", DHookCallback_DistributeCurrencyAmount_Pre, DHookCallback_DistributeCurrencyAmount_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::ConditionGameRulesThink", DHookCallback_ConditionGameRulesThink_Pre, DHookCallback_ConditionGameRulesThink_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::CanRecieveMedigunChargeEffect", DHookCallback_CanRecieveMedigunChargeEffect_Pre, DHookCallback_CanRecieveMedigunChargeEffect_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::RadiusSpyScan", DHookCallback_RadiusSpyScan_Pre, DHookCallback_RadiusSpyScan_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::RemoveAllOwnedEntitiesFromWorld", DHookCallback_RemoveAllOwnedEntitiesFromWorld_Pre, DHookCallback_RemoveAllOwnedEntitiesFromWorld_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::CanBuild", DHookCallback_CanBuild_Pre, DHookCallback_CanBuild_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::ManageRegularWeapons", DHookCallback_ManageRegularWeapons_Pre, DHookCallback_ManageRegularWeapons_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::RegenThink", DHookCallback_RegenThink_Pre, DHookCallback_RegenThink_Post);
	DHooks_AddDynamicDetour(gamedata, "CBaseObject::FindSnapToBuildPos", DHookCallback_FindSnapToBuildPos_Pre, DHookCallback_FindSnapToBuildPos_Post);
	DHooks_AddDynamicDetour(gamedata, "CBaseObject::ShouldQuickBuild", DHookCallback_ShouldQuickBuild_Pre, DHookCallback_ShouldQuickBuild_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFWeaponBase::ApplyOnHitAttributes", DHookCallback_ApplyOnHitAttributes_Pre, DHookCallback_ApplyOnHitAttributes_Post);
	DHooks_AddDynamicDetour(gamedata, "CObjectSapper::ApplyRoboSapperEffects", DHookCallback_ApplyRoboSapperEffects_Pre, DHookCallback_ApplyRoboSapperEffects_Post);
	DHooks_AddDynamicDetour(gamedata, "CRegenerateZone::Regenerate", DHookCallback_Regenerate_Pre, _);
	
	// Create virtual hooks
	g_DHookMyTouch = DHooks_AddDynamicHook(gamedata, "CCurrencyPack::MyTouch");
	g_DHookComeToRest = DHooks_AddDynamicHook(gamedata, "CCurrencyPack::ComeToRest");
	g_DHookValidTouch = DHooks_AddDynamicHook(gamedata, "CTFPowerup::ValidTouch");
	g_DHookSetWinningTeam = DHooks_AddDynamicHook(gamedata, "CTFGameRules::SetWinningTeam");
	g_DHookShouldRespawnQuickly = DHooks_AddDynamicHook(gamedata, "CTFGameRules::ShouldRespawnQuickly");
	g_DHookRoundRespawn = DHooks_AddDynamicHook(gamedata, "CTFGameRules::RoundRespawn");
	g_DHookCheckRespawnWaves = DHooks_AddDynamicHook(gamedata, "CTFGameRules::CheckRespawnWaves");
}

void DHooks_Toggle(bool enable)
{
	for (int i = 0; i < g_DynamicDetours.Length; i++)
	{
		DetourData data;
		if (g_DynamicDetours.GetArray(i, data))
		{
			if (data.callbackPre != INVALID_FUNCTION)
			{
				if (enable)
				{
					data.detour.Enable(Hook_Pre, data.callbackPre);
				}
				else
				{
					data.detour.Disable(Hook_Pre, data.callbackPre);
				}
			}
			
			if (data.callbackPost != INVALID_FUNCTION)
			{
				if (enable)
				{
					data.detour.Enable(Hook_Post, data.callbackPost);
				}
				else
				{
					data.detour.Disable(Hook_Post, data.callbackPost);
				}
			}
		}
	}
	
	if (!enable)
	{
		// Remove virtual hooks
		for (int i = g_DynamicHookIds.Length - 1; i >= 0; i--)
		{
			int hookid = g_DynamicHookIds.Get(i);
			DynamicHook.RemoveHook(hookid);
		}
	}
}

void DHooks_HookAllGameRules()
{
	if (g_DHookSetWinningTeam)
	{
		DHooks_HookGameRules(g_DHookSetWinningTeam, Hook_Post, DHookCallback_SetWinningTeam_Post);
	}
	
	if (g_DHookShouldRespawnQuickly)
	{
		DHooks_HookGameRules(g_DHookShouldRespawnQuickly, Hook_Pre, DHookCallback_ShouldRespawnQuickly_Pre);
		DHooks_HookGameRules(g_DHookShouldRespawnQuickly, Hook_Post, DHookCallback_ShouldRespawnQuickly_Post);
	}
	
	if (g_DHookRoundRespawn)
	{
		DHooks_HookGameRules(g_DHookRoundRespawn, Hook_Pre, DHookCallback_RoundRespawn_Pre);
		DHooks_HookGameRules(g_DHookRoundRespawn, Hook_Post, DHookCallback_RoundRespawn_Post);
	}
	
	if (g_DHookCheckRespawnWaves)
	{
		DHooks_HookGameRules(g_DHookCheckRespawnWaves, Hook_Pre, DHookCallback_CheckRespawnWaves_Pre);
		DHooks_HookGameRules(g_DHookCheckRespawnWaves, Hook_Post, DHookCallback_CheckRespawnWaves_Post);
	}
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (!strncmp(classname, "item_currencypack_", 18))
	{
		if (g_DHookMyTouch)
		{
			DHooks_HookEntity(g_DHookMyTouch, Hook_Pre, entity, DHookCallback_MyTouch_Pre);
			DHooks_HookEntity(g_DHookMyTouch, Hook_Post, entity, DHookCallback_MyTouch_Post);
		}
		
		if (g_DHookComeToRest)
		{
			DHooks_HookEntity(g_DHookComeToRest, Hook_Pre, entity, DHookCallback_ComeToRest_Pre);
			DHooks_HookEntity(g_DHookComeToRest, Hook_Post, entity, DHookCallback_ComeToRest_Post);
		}
		
		if (g_DHookValidTouch)
		{
			DHooks_HookEntity(g_DHookValidTouch, Hook_Pre, entity, DHookCallback_ValidTouch_Pre);
			DHooks_HookEntity(g_DHookValidTouch, Hook_Post, entity, DHookCallback_ValidTouch_Post);
		}
	}
}

static void DHooks_AddDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		DetourData data;
		data.detour = detour;
		data.callbackPre = callbackPre;
		data.callbackPost = callbackPost;
		
		g_DynamicDetours.PushArray(data);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}

static DynamicHook DHooks_AddDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
	{
		LogError("Failed to create hook setup handle for %s", name);
	}
	
	return hook;
}

static void DHooks_HookGameRules(DynamicHook hook, HookMode mode, DHookCallback callback)
{
	if (hook)
	{
		int hookid = hook.HookGamerules(mode, callback, DHookRemovalCB_OnHookRemoved);
		if (hookid != INVALID_HOOK_ID)
		{
			g_DynamicHookIds.Push(hookid);
		}
	}
}

static void DHooks_HookEntity(DynamicHook hook, HookMode mode, int entity, DHookCallback callback)
{
	if (hook)
	{
		int hookid = hook.HookEntity(mode, entity, callback, DHookRemovalCB_OnHookRemoved);
		if (hookid != INVALID_HOOK_ID)
		{
			g_DynamicHookIds.Push(hookid);
		}
	}
}

public void DHookRemovalCB_OnHookRemoved(int hookid)
{
	int index = g_DynamicHookIds.FindValue(hookid);
	if (index != -1)
	{
		g_DynamicHookIds.Erase(index);
	}
}

public MRESReturn DHookCallback_ApplyUpgradeToItem_Pre(int upgradestation, DHookReturn ret, DHookParam params)
{
	// This function has some special logic for MvM that we want
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ApplyUpgradeToItem_Post(int upgradestation, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_PopulationManagerUpdate_Pre(int populator)
{
	// Prevents the populator from messing with the GC and allocating bots
	return MRES_Supercede;
}

public MRESReturn DHookCallback_PopulationManagerResetMap_Pre(int populator)
{
	// MvM defenders get their upgrades and stats reset on map reset, move all players to the defender team
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).SetTeam(TFTeam_Red);
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_PopulationManagerResetMap_Post(int populator)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).ResetTeam();
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RemovePlayerAndItemUpgradesFromHistory_Pre(int populator, DHookParam params)
{
	// This function handles refunding currency and resetting upgrade history during a respec.
	// We block this because we already handle this ourselves in the respec menu handler.
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RemovePlayerAndItemUpgradesFromHistory_Post(int populator, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_Capture_Pre(int flag, DHookReturn ret, DHookParam params)
{
	// Grants the capturing team credits
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_Capture_Post(int flag, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_IsQuickBuildTime_Pre(DHookReturn ret)
{
	// Allows Engineers to quickbuild during setup
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_IsQuickBuildTime_Post(DHookReturn ret)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_GameModeUsesUpgrades_Post(DHookReturn ret)
{
	// Fixes various upgrades and enables a few MvM-related features
	ret.Value = true;
	
	return MRES_Supercede;
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Pre(DHookReturn ret, DHookParam params)
{
	// Enables respecs regardless of round state
	g_PreHookRoundState = GameRules_GetRoundState();
	GameRules_SetProp("m_iRoundState", RoundState_BetweenRounds);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Post(DHookReturn ret, DHookParam params)
{
	GameRules_SetProp("m_iRoundState", g_PreHookRoundState);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Pre(DHookReturn ret, DHookParam params)
{
	int amount = params.Get(1);
	bool shared = params.Get(3);
	
	if (shared)
	{
		// If the player is NULL, take the value of g_CurrencyPackTeam because our code has likely set it to something
		TFTeam team = params.IsNull(2) ? g_CurrencyPackTeam : TF2_GetClientTeam(params.Get(2));
		
		MvMTeam(team).AcquiredCredits += amount;
		
		// This function only collects defenders when MvM is enabled
		if (IsMannVsMachineMode())
		{
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
	}
	else if (!params.IsNull(2))
	{
		int player = params.Get(2);
		
		MvMPlayer(player).AcquiredCredits += amount;
		
		EmitSoundToClient(player, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Post(DHookReturn ret, DHookParam params)
{
	bool shared = params.Get(3);
	
	if (shared)
	{
		if (IsMannVsMachineMode())
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
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Pre(Address playerShared)
{
	// Enables radius currency collection, radius spy scan and increased rage gain during setup
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ConditionGameRulesThink_Post(Address playerShared)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanRecieveMedigunChargeEffect_Pre(Address playerShared, DHookReturn ret, DHookParam params)
{
	// MvM allows flag carriers to be ubered (enabled from CTFPlayerShared::ConditionGameRulesThink), but we don't want this for balance reasons
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanRecieveMedigunChargeEffect_Post(Address playerShared, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RadiusSpyScan_Pre(Address playerShared)
{
	int outer = GetPlayerSharedOuter(playerShared);
	
	TFTeam team = TF2_GetClientTeam(outer);
	
	// RadiusSpyScan only allows defenders to see invaders, move all teammates to the defender team and enemies to the invader team
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
	
	return MRES_Ignored;
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
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RemoveAllOwnedEntitiesFromWorld_Pre(int player, DHookParam params)
{
	// MvM invaders are allowed to keep their buildings and we don't want that, move the player to the defender team
	if (IsMannVsMachineMode())
	{
		MvMPlayer(player).SetTeam(TFTeam_Red);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RemoveAllOwnedEntitiesFromWorld_Post(int player, DHookParam params)
{
	if (IsMannVsMachineMode())
	{
		MvMPlayer(player).ResetTeam();
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanBuild_Pre(int player, DHookReturn ret, DHookParam params)
{
	// Limits the amount of sappers that can be placed on players
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanBuild_Post(int player, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ManageRegularWeapons_Pre(int player, DHookParam params)
{
	// Allows the call to CTFPlayer::ReapplyPlayerUpgrades to happen
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ManageRegularWeapons_Post(int player, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RegenThink_Pre(int player)
{
	// Health regeneration has no scaling in MvM
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RegenThink_Post(int player)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_FindSnapToBuildPos_Pre(int obj, DHookReturn ret, DHookParam params)
{
	// Allows placing sappers on other players
	SetMannVsMachineMode(true);
	
	int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
	
	// The robot sapper only works on bots, give every player the fake client flag
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && client != builder)
		{
			MvMPlayer(client).AddFlags(FL_FAKECLIENT);
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_FindSnapToBuildPos_Post(int obj, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && client != builder)
		{
			MvMPlayer(client).ResetFlags();
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ShouldQuickBuild_Pre(int obj, DHookReturn ret)
{
	SetMannVsMachineMode(true);
	
	// Sentries owned by MvM defenders can be re-deployed quickly, move the sentry to the defender team
	g_PreHookTeam = TF2_GetTeam(obj);
	TF2_SetTeam(obj, TFTeam_Red);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ShouldQuickBuild_Post(int obj, DHookReturn ret)
{
	ResetMannVsMachineMode();
	
	TF2_SetTeam(obj, g_PreHookTeam);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ApplyOnHitAttributes_Pre(int weapon, DHookParam params)
{
	// Allows the "mvm_scout_marked_for_death" event to fire
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ApplyOnHitAttributes_Post(int weapon, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ApplyRoboSapperEffects_Pre(int sapper, DHookReturn ret, DHookParam params)
{
	int target = params.Get(1);
	
	// Minibosses in MvM get slowed down instead of fully stunned
	MvMPlayer(target).SetIsMiniBoss(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ApplyRoboSapperEffects_Post(int sapper, DHookReturn ret, DHookParam params)
{
	int target = params.Get(1);
	
	MvMPlayer(target).ResetIsMiniBoss();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_Regenerate_Pre(int regenerate, DHookParam params)
{
	int player = params.Get(1);
	
	SetEntProp(player, Prop_Send, "m_bInUpgradeZone", true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_MyTouch_Pre(int currencypack, DHookReturn ret, DHookParam params)
{
	// This virtual hook cannot be substituted with an SDKHook because the Touch function for CItem is actually CItem::ItemTouch, not CItem::MyTouch.
	// CItem::ItemTouch simply calls CItem::MyTouch and deletes the entity if it returns true, which causes a TouchPost SDKHook to never get called.
	
	int player = params.Get(1);
	
	// Allows Scouts to gain health from currency packs and distributes the currency
	SetMannVsMachineMode(true);
	
	// Enables money pickup voice lines
	SetVariantString("IsMvMDefender:1");
	AcceptEntityInput(player, "AddContext");
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_MyTouch_Post(int currencypack, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	ResetMannVsMachineMode();
	
	SetVariantString("IsMvMDefender");
	AcceptEntityInput(player, "RemoveContext");
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ComeToRest_Pre(int currencypack)
{
	// Enable MvM for currency distribution
	SetMannVsMachineMode(true);
	
	// Set the currency pack team for distribution
	g_CurrencyPackTeam = TF2_GetTeam(currencypack);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ComeToRest_Post(int currencypack)
{
	ResetMannVsMachineMode();
	
	g_CurrencyPackTeam = TFTeam_Invalid;
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ValidTouch_Pre(int currencypack, DHookReturn ret, DHookParam params)
{
	// MvM invaders are not allowed to collect money.
	// We are disabling MvM instead of swapping teams because ValidTouch also checks the player's team against the currency pack's team.
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ValidTouch_Post(int currencypack, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_SetWinningTeam_Post(DHookParam params)
{
	// This logic can not be moved to a teamplay_round_win event hook.
	// Team scramble logic runs AFTER it fires, meaning CTFGameRules::ShouldScrambleTeams would always return false.
	
	bool forceMapReset = params.Get(3);
	bool switchTeams = params.Get(4);
	
	// Determine whether our CTFGameRules::RoundRespawn hook will reset the map
	int mode = mvm_upgrades_reset_mode.IntValue;
	g_ForceMapReset = forceMapReset && (mode == RESET_MODE_ALWAYS || (mode == RESET_MODE_TEAM_SWITCH && (switchTeams || SDKCall_ShouldScrambleTeams())));
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Pre(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	// Enables quick respawn for Scouts
	SetMannVsMachineMode(true);
	
	// MvM defenders are allowed to respawn quickly, move the player to the defender team
	MvMPlayer(player).SetTeam(TFTeam_Red);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Post(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	ResetMannVsMachineMode();
	
	MvMPlayer(player).ResetTeam();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RoundRespawn_Pre()
{
	// This logic cannot be moved to a teamplay_round_start event hook.
	// CPopulationManager::ResetMap needs to be called right before CTFGameRules::RoundRespawn for the upgrade reset to work properly.
	
	// Switch team credits if the teams are being switched
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
			
			// Reset accumulated team credits on a full reset
			MvMTeam(TFTeam_Red).AcquiredCredits = 0;
			MvMTeam(TFTeam_Blue).AcquiredCredits = 0;
			
			// Reset currency for all clients
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, client);
					SDKCall_AddPlayerCurrencySpent(populator, client, -spentCurrency);
					MvMPlayer(client).Currency = mvm_currency_starting.IntValue;
					MvMPlayer(client).AcquiredCredits = 0;
				}
			}
			
			// Reset player and item upgrades
			SDKCall_ResetMap(populator);
		}
		else
		{
			// Retain player upgrades (forces a call to CTFPlayer::ReapplyPlayerUpgrades)
			SetEntData(populator, g_OffsetRestoringCheckpoint, true);
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_RoundRespawn_Post()
{
	int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
	if (populator != -1)
	{
		SetEntData(populator, g_OffsetRestoringCheckpoint, false);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CheckRespawnWaves_Pre()
{
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CheckRespawnWaves_Post()
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}
