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
static DynamicHook g_DHookGetMeleeDamage;
static DynamicHook g_DHookApplyBallImpactEffectOnVictim;
static DynamicHook g_DHookSetWinningTeam;
static DynamicHook g_DHookShouldRespawnQuickly;
static DynamicHook g_DHookRoundRespawn;
static DynamicHook g_DHookCheckRespawnWaves;

// Detour state
static TFTeam g_PreHookTeam;	// For clients, use the MvMPlayer methodmap
static RoundState g_PreHookRoundState;

void DHooks_Init(GameData gamedata)
{
	g_DynamicDetours = new ArrayList(sizeof(DetourData));
	g_DynamicHookIds = new ArrayList();
	
	// Create detours
	DHooks_AddDynamicDetour(gamedata, "CPopulationManager::Update", DHookCallback_PopulationManagerUpdate_Pre, _);
	DHooks_AddDynamicDetour(gamedata, "CPopulationManager::ResetMap", DHookCallback_PopulationManagerResetMap_Pre, DHookCallback_PopulationManagerResetMap_Post);
	DHooks_AddDynamicDetour(gamedata, "CCaptureFlag::Capture", DHookCallback_Capture_Pre, DHookCallback_Capture_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFGameRules::IsQuickBuildTime", DHookCallback_IsQuickBuildTime_Pre, DHookCallback_IsQuickBuildTime_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFGameRules::DistributeCurrencyAmount", DHookCallback_DistributeCurrencyAmount_Pre, DHookCallback_DistributeCurrencyAmount_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::ConditionGameRulesThink", DHookCallback_ConditionGameRulesThink_Pre, DHookCallback_ConditionGameRulesThink_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::CanRecieveMedigunChargeEffect", DHookCallback_CanRecieveMedigunChargeEffect_Pre, DHookCallback_CanRecieveMedigunChargeEffect_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::RadiusSpyScan", DHookCallback_RadiusSpyScan_Pre, DHookCallback_RadiusSpyScan_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayerShared::ApplyRocketPackStun", DHookCallback_ApplyRocketPackStun_Pre, DHookCallback_ApplyRocketPackStun_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::CanBuild", DHookCallback_CanBuild_Pre, DHookCallback_CanBuild_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFPlayer::RegenThink", DHookCallback_RegenThink_Pre, DHookCallback_RegenThink_Post);
	DHooks_AddDynamicDetour(gamedata, "CBaseObject::FindSnapToBuildPos", DHookCallback_FindSnapToBuildPos_Pre, DHookCallback_FindSnapToBuildPos_Post);
	DHooks_AddDynamicDetour(gamedata, "CBaseObject::ShouldQuickBuild", DHookCallback_ShouldQuickBuild_Pre, DHookCallback_ShouldQuickBuild_Post);
	DHooks_AddDynamicDetour(gamedata, "CObjectSapper::ApplyRoboSapperEffects", DHookCallback_ApplyRoboSapperEffects_Pre, DHookCallback_ApplyRoboSapperEffects_Post);
	DHooks_AddDynamicDetour(gamedata, "CRegenerateZone::Regenerate", DHookCallback_Regenerate_Pre, _);
	DHooks_AddDynamicDetour(gamedata, "CTFPowerupBottle::AllowedToUse", DHookCallback_AllowedToUse_Pre, DHookCallback_AllowedToUse_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFKnife::CanPerformBackstabAgainstTarget", DHookCallback_CanPerformBackstabAgainstTarget_Pre, DHookCallback_CanPerformBackstabAgainstTarget_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFBaseRocket::CheckForStunOnImpact", DHookCallback_CheckForStunOnImpact_Pre, DHookCallback_CheckForStunOnImpact_Post);
	DHooks_AddDynamicDetour(gamedata, "CTFSniperRifle::ExplosiveHeadShot", DHookCallback_ExplosiveHeadShot_Pre, DHookCallback_ExplosiveHeadShot_Post);
	
	// Create virtual hooks
	g_DHookMyTouch = DHooks_AddDynamicHook(gamedata, "CCurrencyPack::MyTouch");
	g_DHookComeToRest = DHooks_AddDynamicHook(gamedata, "CCurrencyPack::ComeToRest");
	g_DHookValidTouch = DHooks_AddDynamicHook(gamedata, "CTFPowerup::ValidTouch");
	g_DHookGetMeleeDamage = DHooks_AddDynamicHook(gamedata, "CTFWeaponBaseMelee::GetMeleeDamage");
	g_DHookApplyBallImpactEffectOnVictim = DHooks_AddDynamicHook(gamedata, "CTFStunBall::ApplyBallImpactEffectOnVictim");
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
	
	if (IsWeaponBaseMelee(entity))
	{
		if (g_DHookGetMeleeDamage)
		{
			DHooks_HookEntity(g_DHookGetMeleeDamage, Hook_Pre, entity, DHookCallback_GetMeleeDamage_Pre);
			DHooks_HookEntity(g_DHookGetMeleeDamage, Hook_Post, entity, DHookCallback_GetMeleeDamage_Post);
		}
	}
	
	if (!strcmp(classname, "tf_projectile_stun_ball") || !strcmp(classname, "tf_projectile_ball_ornament"))
	{
		if (g_DHookApplyBallImpactEffectOnVictim)
		{
			DHooks_HookEntity(g_DHookApplyBallImpactEffectOnVictim, Hook_Pre, entity, DHookCallback_ApplyBallImpactEffectOnVictim_Pre);
			DHooks_HookEntity(g_DHookApplyBallImpactEffectOnVictim, Hook_Post, entity, DHookCallback_ApplyBallImpactEffectOnVictim_Post);
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

static MRESReturn DHookCallback_PopulationManagerUpdate_Pre(int populator)
{
	// Prevents the populator from messing with the GC and allocating bots
	return MRES_Supercede;
}

static MRESReturn DHookCallback_PopulationManagerResetMap_Pre(int populator)
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

static MRESReturn DHookCallback_PopulationManagerResetMap_Post(int populator)
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

static MRESReturn DHookCallback_Capture_Pre(int flag, DHookReturn ret, DHookParam params)
{
	// Grants the capturing team credits
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_Capture_Post(int flag, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_IsQuickBuildTime_Pre(DHookReturn ret)
{
	// Allows Engineers to quickbuild during setup
	SetMannVsMachineMode(sm_mvm_setup_quickbuild.BoolValue);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_IsQuickBuildTime_Post(DHookReturn ret)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_DistributeCurrencyAmount_Pre(DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_DistributeCurrencyAmount_Post(DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_ConditionGameRulesThink_Pre(Address pShared)
{
	// Enables radius currency collection, radius spy scan and increased rage gain during setup
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ConditionGameRulesThink_Post(Address pShared)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CanRecieveMedigunChargeEffect_Pre(Address pShared, DHookReturn ret, DHookParam params)
{
	// MvM allows flag carriers to be ubered (enabled from CTFPlayerShared::ConditionGameRulesThink), but we don't want this for balance reasons
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CanRecieveMedigunChargeEffect_Post(Address pShared, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_RadiusSpyScan_Pre(Address pShared)
{
	int player = TF2Util_GetPlayerFromSharedAddress(pShared);
	TFTeam team = TF2_GetClientTeam(player);
	
	// This MvM feature may confuse players, so we allow servers to toggle it
	if (!sm_mvm_radius_spy_scan.BoolValue)
	{
		MvMPlayer(player).SetTeam(TFTeam_Spectator);
		return MRES_Ignored;
	}
	
	// RadiusSpyScan only allows defenders to see invaders, move all teammates to the defender team and enemies to the invader team
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (client == player)
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

static MRESReturn DHookCallback_RadiusSpyScan_Post(Address pShared)
{
	if (!sm_mvm_radius_spy_scan.BoolValue)
	{
		int player = TF2Util_GetPlayerFromSharedAddress(pShared);
		
		MvMPlayer(player).ResetTeam();
		return MRES_Ignored;
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			MvMPlayer(client).ResetTeam();
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ApplyRocketPackStun_Pre(Address pShared, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int player = TF2Util_GetPlayerFromSharedAddress(pShared);
		
		// Minibosses get slowed down instead of fully stunned
		for (int client = 1; client <= MaxClients; client++)
		{
			if (client != player && IsClientInGame(client))
			{
				MvMPlayer(client).SetIsMiniBoss(true);
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ApplyRocketPackStun_Post(Address pShared, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int player = TF2Util_GetPlayerFromSharedAddress(pShared);
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (client != player && IsClientInGame(client))
			{
				MvMPlayer(client).ResetIsMiniBoss();
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CanBuild_Pre(int player, DHookReturn ret, DHookParam params)
{
	// Limits the amount of sappers that can be placed on players
	SetMannVsMachineMode(sm_mvm_player_sapper.BoolValue);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CanBuild_Post(int player, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_RegenThink_Pre(int player)
{
	// Health regeneration has no scaling in MvM
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_RegenThink_Post(int player)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_FindSnapToBuildPos_Pre(int obj, DHookReturn ret, DHookParam params)
{
	if (sm_mvm_player_sapper.BoolValue)
	{
		// Allows placing sappers on other players
		SetMannVsMachineMode(true);
		
		int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
		
		// The robot sapper only works on bots, give every player the fake client flag
		for (int client = 1; client <= MaxClients; client++)
		{
			if (client != builder && IsClientInGame(client))
			{
				MvMPlayer(client).AddFlags(FL_FAKECLIENT);
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_FindSnapToBuildPos_Post(int obj, DHookReturn ret, DHookParam params)
{
	if (sm_mvm_player_sapper.BoolValue)
	{
		ResetMannVsMachineMode();
		
		int builder = GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (client != builder && IsClientInGame(client))
			{
				MvMPlayer(client).ResetFlags();
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ShouldQuickBuild_Pre(int obj, DHookReturn ret)
{
	SetMannVsMachineMode(true);
	
	// Sentries owned by MvM defenders can be re-deployed quickly, move the sentry to the defender team
	g_PreHookTeam = TF2_GetTeam(obj);
	TF2_SetTeam(obj, TFTeam_Red);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ShouldQuickBuild_Post(int obj, DHookReturn ret)
{
	ResetMannVsMachineMode();
	
	TF2_SetTeam(obj, g_PreHookTeam);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ApplyRoboSapperEffects_Pre(int sapper, DHookReturn ret, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int target = params.Get(1);
		
		// Minibosses get slowed down instead of fully stunned
		MvMPlayer(target).SetIsMiniBoss(true);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ApplyRoboSapperEffects_Post(int sapper, DHookReturn ret, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int target = params.Get(1);
		
		MvMPlayer(target).ResetIsMiniBoss();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_Regenerate_Pre(int regenerate, DHookParam params)
{
	int player = params.Get(1);
	
	if (IsPlayerDefender(player))
	{
		SetEntProp(player, Prop_Send, "m_bInUpgradeZone", true);
	}
	else
	{
		PrintCenterText(player, "%t", "MvM_Hint_CannotUpgrade");
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_AllowedToUse_Pre(int bottle, DHookReturn ret)
{
	if (IsInArenaMode() && sm_mvm_arena_canteens.BoolValue && GameRules_GetRoundState() == RoundState_Stalemate)
	{
		g_PreHookRoundState = GameRules_GetRoundState();
		
		GameRules_SetProp("m_iRoundState", RoundState_RoundRunning);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_AllowedToUse_Post(int bottle, DHookReturn ret)
{
	if (IsInArenaMode() && sm_mvm_arena_canteens.BoolValue && GameRules_GetRoundState() == RoundState_RoundRunning)
	{
		GameRules_SetProp("m_iRoundState", g_PreHookRoundState);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CanPerformBackstabAgainstTarget_Pre(int knife, DHookReturn ret, DHookParam params)
{
	SetMannVsMachineMode(true);
	
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int target = params.Get(1);
		
		// Minibosses cannot be backstabbed from all sides while sapped
		MvMPlayer(target).SetTeam(TFTeam_Blue);
		MvMPlayer(target).SetIsMiniBoss(true);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CanPerformBackstabAgainstTarget_Post(int knife, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int target = params.Get(1);
		
		MvMPlayer(target).ResetTeam();
		MvMPlayer(target).ResetIsMiniBoss();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CheckForStunOnImpact_Pre(int rocket, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int target = params.Get(1);
		
		// Minibosses receive a weaker rocket specialist stun
		MvMPlayer(target).SetIsMiniBoss(true);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CheckForStunOnImpact_Post(int rocket, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int target = params.Get(1);
		
		MvMPlayer(target).ResetIsMiniBoss();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ExplosiveHeadShot_Pre(int sniperrifle, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int attacker = params.Get(1);
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (client != attacker && IsClientInGame(client))
			{
				// Minibosses receive a weaker explosive headshot stun
				MvMPlayer(client).SetIsMiniBoss(true);
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ExplosiveHeadShot_Post(int sniperrifle, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int attacker = params.Get(1);
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (client != attacker && IsClientInGame(client))
			{
				MvMPlayer(client).ResetIsMiniBoss();
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_MyTouch_Pre(int currencypack, DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_MyTouch_Post(int currencypack, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	ResetMannVsMachineMode();
	
	SetVariantString("IsMvMDefender");
	AcceptEntityInput(player, "RemoveContext");
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ComeToRest_Pre(int currencypack)
{
	// Enable MvM for currency distribution
	SetMannVsMachineMode(true);
	
	// Set the currency pack team for distribution
	g_CurrencyPackTeam = TF2_GetTeam(currencypack);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ComeToRest_Post(int currencypack)
{
	ResetMannVsMachineMode();
	
	g_CurrencyPackTeam = TFTeam_Invalid;
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ValidTouch_Pre(int currencypack, DHookReturn ret, DHookParam params)
{
	// MvM invaders are not allowed to collect money.
	// We are disabling MvM instead of swapping teams because ValidTouch also checks the player's team against the currency pack's team.
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ValidTouch_Post(int currencypack, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_GetMeleeDamage_Pre(int melee, DHookReturn ret, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue && sm_mvm_backstab_armor_piercing.BoolValue)
	{
		int entity = params.Get(1);
		if (IsValidClient(entity))
		{
			// Minibosses cannot get killed instantly by backstabs
			MvMPlayer(entity).SetIsMiniBoss(true);
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_GetMeleeDamage_Post(int melee, DHookReturn ret, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue && sm_mvm_backstab_armor_piercing.BoolValue)
	{
		int entity = params.Get(1);
		if (IsValidClient(entity))
		{
			MvMPlayer(entity).ResetIsMiniBoss();
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ApplyBallImpactEffectOnVictim_Pre(int ball, DHookParam params)
{
	SetMannVsMachineMode(true);
	
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int player = params.Get(1);
		
		// Minibosses cannot get fully stunned by sandman balls
		MvMPlayer(player).SetIsMiniBoss(true);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ApplyBallImpactEffectOnVictim_Post(int ball, DHookParam params)
{
	ResetMannVsMachineMode();
	
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int player = params.Get(1);
		
		MvMPlayer(player).ResetIsMiniBoss();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_SetWinningTeam_Post(DHookParam params)
{
	// This logic can not be moved to a teamplay_round_win event hook.
	// Team scramble logic runs AFTER it fires, meaning CTFGameRules::ShouldScrambleTeams would always return false.
	
	bool forceMapReset = params.Get(3);
	bool switchTeams = params.Get(4);
	
	// Determine whether our CTFGameRules::RoundRespawn hook will reset the map
	int mode = sm_mvm_upgrades_reset_mode.IntValue;
	g_ForceMapReset = forceMapReset && (mode == RESET_MODE_ALWAYS || (mode == RESET_MODE_TEAM_SWITCH && (switchTeams || SDKCall_ShouldScrambleTeams())));
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ShouldRespawnQuickly_Pre(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	// Enables quick respawn for Scouts
	SetMannVsMachineMode(true);
	
	// MvM defenders are allowed to respawn quickly, move the player to the defender team
	MvMPlayer(player).SetTeam(TFTeam_Red);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_ShouldRespawnQuickly_Post(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	ResetMannVsMachineMode();
	
	MvMPlayer(player).ResetTeam();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_RoundRespawn_Pre()
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
	
	int populator = FindEntityByClassname(-1, "info_populator");
	if (populator != -1)
	{
		if (g_ForceMapReset)
		{
			g_ForceMapReset = false;
			
			// Reset accumulated team credits on a full reset
			for (TFTeam team = TFTeam_Unassigned; team <= TFTeam_Blue; team++)
			{
				MvMTeam(team).AcquiredCredits = 0;
			}
			
			// Reset currency for all clients
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					int spentCurrency = SDKCall_GetPlayerCurrencySpent(populator, client);
					SDKCall_AddPlayerCurrencySpent(populator, client, -spentCurrency);
					MvMPlayer(client).Currency = sm_mvm_currency_starting.IntValue;
					MvMPlayer(client).AcquiredCredits = 0;
				}
			}
			
			// Reset player and item upgrades
			SDKCall_ResetMap(populator);
		}
		else
		{
			// Retain player upgrades (forces a call to CTFPlayer::ReapplyPlayerUpgrades)
			SetEntData(populator, GetOffset("CPopulationManager", "m_isRestoringCheckpoint"), true, 1);
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_RoundRespawn_Post()
{
	int populator = FindEntityByClassname(-1, "info_populator");
	if (populator != -1)
	{
		SetEntData(populator, GetOffset("CPopulationManager", "m_isRestoringCheckpoint"), false, 1);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CheckRespawnWaves_Pre()
{
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CheckRespawnWaves_Post()
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}
