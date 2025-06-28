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

static DynamicHook g_DHook_CItem_MyTouch;
static DynamicHook g_DHook_CItem_ComeToRest;
static DynamicHook g_DHook_CTFPowerup_ValidTouch;
static DynamicHook g_DHook_CTFWeaponBaseMelee_GetMeleeDamage;
static DynamicHook g_DHook_CTFStunBall_ApplyBallImpactEffectOnVictim;
static DynamicHook g_DHook_CTeamplayRules_SetWinningTeam;
static DynamicHook g_DHook_CTeamplayRoundBasedRules_GetRespawnWaveMaxLength;
static DynamicHook g_DHook_CTFGameRules_ShouldRespawnQuickly;
static DynamicHook g_DHook_CTeamplayRoundBasedRules_RoundRespawn;
static DynamicHook g_DHook_CTeamplayRoundBasedRules_CheckRespawnWaves;

static TFTeam g_PreHookTeam;

void DHooks_Init()
{
	PSM_AddDynamicDetourFromConf("CPopulationManager::Update", DHookCallback_CPopulationManager_Update_Pre);
	PSM_AddDynamicDetourFromConf("CPopulationManager::ResetMap", DHookCallback_CPopulationManager_ResetMap_Pre, DHookCallback_CPopulationManager_ResetMap_Post);
	PSM_AddDynamicDetourFromConf("CCaptureFlag::Capture", DHookCallback_CCaptureFlag_Capture_Pre, DHookCallback_CCaptureFlag_Capture_Post);
	PSM_AddDynamicDetourFromConf("CTFGameRules::IsQuickBuildTime", DHookCallback_CTFGameRules_IsQuickBuildTime_Pre, DHookCallback_CTFGameRules_IsQuickBuildTime_Post);
	PSM_AddDynamicDetourFromConf("CTFGameRules::DistributeCurrencyAmount", DHookCallback_CTFGameRules_DistributeCurrencyAmount_Pre, DHookCallback_CTFGameRules_DistributeCurrencyAmount_Post);
	PSM_AddDynamicDetourFromConf("CTFGameRules::CalculateCurrencyAmount_ByType", DHookCallback_CTFGameRules_CalculateCurrencyAmount_ByType_Pre);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::ConditionGameRulesThink", DHookCallback_CTFPlayerShared_ConditionGameRulesThink_Pre, DHookCallback_CTFPlayerShared_ConditionGameRulesThink_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::CanRecieveMedigunChargeEffect", DHookCallback_CTFPlayerShared_CanRecieveMedigunChargeEffect_Pre, DHookCallback_CTFPlayerShared_CanRecieveMedigunChargeEffect_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::RadiusSpyScan", DHookCallback_CTFPlayerShared_RadiusSpyScan_Pre, DHookCallback_CTFPlayerShared_RadiusSpyScan_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::ApplyRocketPackStun", DHookCallback_CTFPlayerShared_ApplyRocketPackStun_Pre, DHookCallback_CTFPlayerShared_ApplyRocketPackStun_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::CanBuild", DHookCallback_CTFPlayer_CanBuild_Pre, DHookCallback_CTFPlayer_CanBuild_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::RegenThink", DHookCallback_CTFPlayer_RegenThink_Pre, DHookCallback_CTFPlayer_RegenThink_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::RemoveAllOwnedEntitiesFromWorld", DHookCallback_CTFPlayer_RemoveAllOwnedEntitiesFromWorld_Pre, DHookCallback_CTFPlayer_RemoveAllOwnedEntitiesFromWorld_Post);
	PSM_AddDynamicDetourFromConf("CBaseObject::FindSnapToBuildPos", DHookCallback_CBaseObject_FindSnapToBuildPos_Pre, DHookCallback_CBaseObject_FindSnapToBuildPos_Post);
	PSM_AddDynamicDetourFromConf("CBaseObject::ShouldQuickBuild", DHookCallback_CBaseObject_ShouldQuickBuild_Pre, DHookCallback_CBaseObject_ShouldQuickBuild_Post);
	PSM_AddDynamicDetourFromConf("CObjectSapper::ApplyRoboSapper", DHookCallback_CObjectSapper_ApplyRoboSapper_Pre, DHookCallback_CObjectSapper_ApplyRoboSapper_Post);
	PSM_AddDynamicDetourFromConf("CRegenerateZone::Regenerate", DHookCallback_CRegenerateZone_Regenerate_Pre);
	PSM_AddDynamicDetourFromConf("CTFKnife::CanPerformBackstabAgainstTarget", DHookCallback_CTFKnife_CanPerformBackstabAgainstTarget_Pre, DHookCallback_CTFKnife_CanPerformBackstabAgainstTarget_Post);
	PSM_AddDynamicDetourFromConf("CTFBaseRocket::CheckForStunOnImpact", DHookCallback_CTFBaseRocket_CheckForStunOnImpact_Pre, DHookCallback_CTFBaseRocket_CheckForStunOnImpact_Post);
	PSM_AddDynamicDetourFromConf("CTFSniperRifle::ExplosiveHeadShot", DHookCallback_CTFSniperRifle_ExplosiveHeadShot_Pre, DHookCallback_CTFSniperRifle_ExplosiveHeadShot_Post);
	
	g_DHook_CItem_MyTouch = PSM_AddDynamicHookFromConf("CItem::MyTouch");
	g_DHook_CItem_ComeToRest = PSM_AddDynamicHookFromConf("CItem::ComeToRest");
	g_DHook_CTFPowerup_ValidTouch = PSM_AddDynamicHookFromConf("CTFPowerup::ValidTouch");
	g_DHook_CTFWeaponBaseMelee_GetMeleeDamage = PSM_AddDynamicHookFromConf("CTFWeaponBaseMelee::GetMeleeDamage");
	g_DHook_CTFStunBall_ApplyBallImpactEffectOnVictim = PSM_AddDynamicHookFromConf("CTFStunBall::ApplyBallImpactEffectOnVictim");
	g_DHook_CTeamplayRules_SetWinningTeam = PSM_AddDynamicHookFromConf("CTeamplayRules::SetWinningTeam");
	g_DHook_CTeamplayRoundBasedRules_GetRespawnWaveMaxLength = PSM_AddDynamicHookFromConf("CTeamplayRoundBasedRules::GetRespawnWaveMaxLength");
	g_DHook_CTeamplayRoundBasedRules_RoundRespawn = PSM_AddDynamicHookFromConf("CTeamplayRoundBasedRules::RoundRespawn");
	g_DHook_CTeamplayRoundBasedRules_CheckRespawnWaves = PSM_AddDynamicHookFromConf("CTeamplayRoundBasedRules::CheckRespawnWaves");
	g_DHook_CTFGameRules_ShouldRespawnQuickly = PSM_AddDynamicHookFromConf("CTFGameRules::ShouldRespawnQuickly");
}

void DHooks_OnMapStart()
{
	PSM_DHookGameRules(g_DHook_CTeamplayRules_SetWinningTeam, Hook_Post, DHookCallback_CTFGameRules_SetWinningTeam_Post);
	PSM_DHookGameRules(g_DHook_CTeamplayRoundBasedRules_GetRespawnWaveMaxLength, Hook_Pre, DHookCallback_CTFGameRules_GetRespawnWaveMaxLength_Pre);
	PSM_DHookGameRules(g_DHook_CTeamplayRoundBasedRules_GetRespawnWaveMaxLength, Hook_Post, DHookCallback_CTFGameRules_GetRespawnWaveMaxLength_Post);
	PSM_DHookGameRules(g_DHook_CTeamplayRoundBasedRules_RoundRespawn, Hook_Pre, DHookCallback_CTFGameRules_RoundRespawn_Pre);
	PSM_DHookGameRules(g_DHook_CTeamplayRoundBasedRules_RoundRespawn, Hook_Post, DHookCallback_CTFGameRules_RoundRespawn_Post);
	PSM_DHookGameRules(g_DHook_CTeamplayRoundBasedRules_CheckRespawnWaves, Hook_Pre, DHookCallback_CTFGameRules_CheckRespawnWaves_Pre);
	PSM_DHookGameRules(g_DHook_CTeamplayRoundBasedRules_CheckRespawnWaves, Hook_Post, DHookCallback_CTFGameRules_CheckRespawnWaves_Post);
	PSM_DHookGameRules(g_DHook_CTFGameRules_ShouldRespawnQuickly, Hook_Pre, DHookCallback_CTFGameRules_ShouldRespawnQuickly_Pre);
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (!strncmp(classname, "item_currencypack_", 18))
	{
		PSM_DHookEntity(g_DHook_CItem_MyTouch, Hook_Pre, entity, DHookCallback_CCurrencyPack_MyTouch_Pre);
		PSM_DHookEntity(g_DHook_CItem_MyTouch, Hook_Post, entity, DHookCallback_CCurrencyPack_MyTouch_Post);

		PSM_DHookEntity(g_DHook_CItem_ComeToRest, Hook_Pre, entity, DHookCallback_CCurrencyPack_ComeToRest_Pre);
		PSM_DHookEntity(g_DHook_CItem_ComeToRest, Hook_Post, entity, DHookCallback_CCurrencyPack_ComeToRest_Post);
		
		PSM_DHookEntity(g_DHook_CTFPowerup_ValidTouch, Hook_Pre, entity, DHookCallback_CCurrencyPack_ValidTouch_Pre);
		PSM_DHookEntity(g_DHook_CTFPowerup_ValidTouch, Hook_Post, entity, DHookCallback_CCurrencyPack_ValidTouch_Post);
	}
	
	if (HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack"))
	{
		PSM_DHookEntity(g_DHook_CTFWeaponBaseMelee_GetMeleeDamage, Hook_Pre, entity, DHookCallback_CTFWeaponBaseMelee_GetMeleeDamage_Pre);
		PSM_DHookEntity(g_DHook_CTFWeaponBaseMelee_GetMeleeDamage, Hook_Post, entity, DHookCallback_CTFWeaponBaseMelee_GetMeleeDamage_Post);
	}
	
	if (StrEqual(classname, "tf_projectile_stun_ball") || StrEqual(classname, "tf_projectile_ball_ornament"))
	{
		PSM_DHookEntity(g_DHook_CTFStunBall_ApplyBallImpactEffectOnVictim, Hook_Pre, entity, DHookCallback_CTFStunBall_ApplyBallImpactEffectOnVictim_Pre);
		PSM_DHookEntity(g_DHook_CTFStunBall_ApplyBallImpactEffectOnVictim, Hook_Post, entity, DHookCallback_CTFStunBall_ApplyBallImpactEffectOnVictim_Post);
	}
}

static MRESReturn DHookCallback_CPopulationManager_Update_Pre(int populator)
{
	// Prevents the populator from messing with the GC and allocating bots
	return MRES_Supercede;
}

static MRESReturn DHookCallback_CPopulationManager_ResetMap_Pre(int populator)
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

static MRESReturn DHookCallback_CPopulationManager_ResetMap_Post(int populator)
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

static MRESReturn DHookCallback_CCaptureFlag_Capture_Pre(int flag, DHookReturn ret, DHookParam params)
{
	// Grants the capturing team credits
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CCaptureFlag_Capture_Post(int flag, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_IsQuickBuildTime_Pre(DHookReturn ret)
{
	// Allows Engineers to quickbuild during setup
	SetMannVsMachineMode(sm_mvm_setup_quickbuild.BoolValue);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_IsQuickBuildTime_Post(DHookReturn ret)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_DistributeCurrencyAmount_Pre(DHookReturn ret, DHookParam params)
{
	int amount = params.Get(1);
	bool shared = params.Get(3);
	
	// Group distribution (default)
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
					// Allow the player to have currency distributed to them
					MvMPlayer(client).SetTeam(TF2_GetClientTeam(client) == team ? TFTeam_Red : TFTeam_Blue);

					EmitSoundToClient(client, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
				}
			}
		}
	}
	// Individual distribution
	else if (!params.IsNull(2))
	{
		int player = params.Get(2);
		
		MvMPlayer(player).AcquiredCredits += amount;
		
		EmitSoundToClient(player, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_DistributeCurrencyAmount_Post(DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_CTFGameRules_CalculateCurrencyAmount_ByType_Pre(DHookReturn ret, DHookParam params)
{
	CurrencyRewards type = params.Get(1);
	
	int amount = 0;
	
	switch (type)
	{
		case TF_CURRENCY_KILLED_PLAYER:
		{
			amount = sm_mvm_currency_rewards_player_killed.IntValue;
		}
		case TF_CURRENCY_ASSISTED_PLAYER:
		{
			amount = sm_mvm_currency_rewards_player_killed.IntValue / 2;
		}
		case TF_CURRENCY_CAPTURED_OBJECTIVE:
		{
			amount = sm_mvm_currency_rewards_objective_captured.IntValue;
		}
		case TF_CURRENCY_ESCORT_REWARD:
		{
			amount = sm_mvm_currency_rewards_escort.IntValue;
		}
	}
	
	if (amount == 0)
	{
		return MRES_Ignored;
	}
	else
	{
		ret.Value = amount;
		return MRES_Supercede;
	}
}

static MRESReturn DHookCallback_CTFPlayerShared_ConditionGameRulesThink_Pre(Address pShared)
{
	// Enables radius currency collection, radius spy scan and increased rage gain during setup
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayerShared_ConditionGameRulesThink_Post(Address pShared)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayerShared_CanRecieveMedigunChargeEffect_Pre(Address pShared, DHookReturn ret, DHookParam params)
{
	// MvM allows flag carriers to be ubered (enabled from CTFPlayerShared::ConditionGameRulesThink), but we don't want this for balance reasons
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayerShared_CanRecieveMedigunChargeEffect_Post(Address pShared, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayerShared_RadiusSpyScan_Pre(Address pShared)
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

static MRESReturn DHookCallback_CTFPlayerShared_RadiusSpyScan_Post(Address pShared)
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

static MRESReturn DHookCallback_CTFPlayerShared_ApplyRocketPackStun_Pre(Address pShared, DHookParam params)
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

static MRESReturn DHookCallback_CTFPlayerShared_ApplyRocketPackStun_Post(Address pShared, DHookParam params)
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

static MRESReturn DHookCallback_CTFPlayer_CanBuild_Pre(int player, DHookReturn ret, DHookParam params)
{
	// Limits the amount of sappers that can be placed on players
	SetMannVsMachineMode(sm_mvm_player_sapper.BoolValue);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_CanBuild_Post(int player, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_RegenThink_Pre(int player)
{
	// Health regeneration has no scaling in MvM
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_RegenThink_Post(int player)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_RemoveAllOwnedEntitiesFromWorld_Pre(int player, DHookParam params)
{
	// Do not retain buildings on class change
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_RemoveAllOwnedEntitiesFromWorld_Post(int player, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseObject_FindSnapToBuildPos_Pre(int obj, DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_CBaseObject_FindSnapToBuildPos_Post(int obj, DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_CBaseObject_ShouldQuickBuild_Pre(int obj, DHookReturn ret)
{
	if (sm_mvm_quickbuild.BoolValue)
	{
		SetMannVsMachineMode(true);
		
		// Sentries owned by MvM defenders can be re-deployed quickly, move the sentry to the defender team
		g_PreHookTeam = TF2_GetEntityTeam(obj);
		TF2_SetEntityTeam(obj, TFTeam_Red);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseObject_ShouldQuickBuild_Post(int obj, DHookReturn ret)
{
	if (sm_mvm_quickbuild.BoolValue)
	{
		ResetMannVsMachineMode();
		
		TF2_SetEntityTeam(obj, g_PreHookTeam);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CObjectSapper_ApplyRoboSapper_Pre(int sapper, DHookReturn ret, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		// Minibosses get slowed down instead of fully stunned
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				MvMPlayer(client).SetIsMiniBoss(true);
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CObjectSapper_ApplyRoboSapper_Post(int sapper, DHookReturn ret, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				MvMPlayer(client).ResetIsMiniBoss();
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CRegenerateZone_Regenerate_Pre(int regenerate, DHookParam params)
{
	if (sm_mvm_resupply_upgrades.BoolValue)
	{
		int player = params.Get(1);
		
		if (MvMPlayer(player).IsDefender())
		{
			SetEntProp(player, Prop_Send, "m_bInUpgradeZone", true);
		}
		else
		{
			PrintCenterText(player, "%t", "MvM_Hint_CannotUpgrade");
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFKnife_CanPerformBackstabAgainstTarget_Pre(int knife, DHookReturn ret, DHookParam params)
{
	int target = params.Get(1);
	
	SetMannVsMachineMode(true);
	
	MvMPlayer(target).SetTeam(TFTeam_Blue);
	
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		// Minibosses cannot be backstabbed from all sides while sapped
		MvMPlayer(target).SetIsMiniBoss(true);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFKnife_CanPerformBackstabAgainstTarget_Post(int knife, DHookReturn ret, DHookParam params)
{
	int target = params.Get(1);
	
	ResetMannVsMachineMode();
	
	MvMPlayer(target).ResetTeam();
	
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		MvMPlayer(target).ResetIsMiniBoss();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFBaseRocket_CheckForStunOnImpact_Pre(int rocket, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int target = params.Get(1);
		
		// Minibosses receive a weaker rocket specialist stun
		MvMPlayer(target).SetIsMiniBoss(true);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFBaseRocket_CheckForStunOnImpact_Post(int rocket, DHookParam params)
{
	if (sm_mvm_players_are_minibosses.BoolValue)
	{
		int target = params.Get(1);
		
		MvMPlayer(target).ResetIsMiniBoss();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFSniperRifle_ExplosiveHeadShot_Pre(int sniperrifle, DHookParam params)
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

static MRESReturn DHookCallback_CTFSniperRifle_ExplosiveHeadShot_Post(int sniperrifle, DHookParam params)
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

// This virtual hook cannot be substituted with an SDKHook because the Touch function for CItem is actually CItem::ItemTouch, not CItem::MyTouch.
// CItem::ItemTouch simply calls CItem::MyTouch and deletes the entity if it returns true, which causes a TouchPost SDKHook to never get called.
static MRESReturn DHookCallback_CCurrencyPack_MyTouch_Pre(int currencypack, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	// Allows Scouts to gain health from currency packs and distributes the currency
	SetMannVsMachineMode(true);
	
	// Enables money pickup voice lines
	SetVariantString("IsMvMDefender:1");
	AcceptEntityInput(player, "AddContext");
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CCurrencyPack_MyTouch_Post(int currencypack, DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	ResetMannVsMachineMode();
	
	SetVariantString("IsMvMDefender");
	AcceptEntityInput(player, "RemoveContext");
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CCurrencyPack_ComeToRest_Pre(int currencypack)
{
	// Enable MvM for currency distribution
	SetMannVsMachineMode(true);
	
	// Set the currency pack team for distribution
	g_CurrencyPackTeam = TF2_GetEntityTeam(currencypack);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CCurrencyPack_ComeToRest_Post(int currencypack)
{
	ResetMannVsMachineMode();
	
	g_CurrencyPackTeam = TFTeam_Invalid;
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CCurrencyPack_ValidTouch_Pre(int currencypack, DHookReturn ret, DHookParam params)
{
	// MvM invaders are not allowed to collect money.
	// We are disabling MvM instead of swapping teams because ValidTouch also checks the player's team against the currency pack's team.
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CCurrencyPack_ValidTouch_Post(int currencypack, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBaseMelee_GetMeleeDamage_Pre(int melee, DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_CTFWeaponBaseMelee_GetMeleeDamage_Post(int melee, DHookReturn ret, DHookParam params)
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

static MRESReturn DHookCallback_CTFStunBall_ApplyBallImpactEffectOnVictim_Pre(int ball, DHookParam params)
{
	SetMannVsMachineMode(true);
	
	int player = params.Get(1);
	
	if (IsValidClient(player) && sm_mvm_players_are_minibosses.BoolValue)
	{
		// Minibosses cannot get fully stunned by sandman balls
		MvMPlayer(player).SetIsMiniBoss(true);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFStunBall_ApplyBallImpactEffectOnVictim_Post(int ball, DHookParam params)
{
	ResetMannVsMachineMode();
	
	int player = params.Get(1);
	
	if (IsValidClient(player) && sm_mvm_players_are_minibosses.BoolValue)
	{
		MvMPlayer(player).ResetIsMiniBoss();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_SetWinningTeam_Post(DHookParam params)
{
	// This logic can not be moved to a teamplay_round_win event hook.
	// Team scramble logic runs AFTER it fires, meaning CTFGameRules::ShouldScrambleTeams would always return false.
	
	bool forceMapReset = params.Get(3);
	bool switchTeams = params.Get(4);
	
	// Determine whether our CTeamplayRoundBasedRules::RoundRespawn hook will reset the map
	int mode = sm_mvm_upgrades_reset_mode.IntValue;
	g_ForceMapReset = forceMapReset && (mode == RESET_MODE_ALWAYS || (mode == RESET_MODE_TEAM_SWITCH && (switchTeams || SDKCall_ShouldScrambleTeams())));
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_GetRespawnWaveMaxLength_Pre(DHookReturn ret, DHookParam params)
{
	SetMannVsMachineMode(false);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_GetRespawnWaveMaxLength_Post(DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

// This logic cannot be moved to a teamplay_round_start event hook.
// CPopulationManager::ResetMap needs to be called right before CTeamplayRoundBasedRules::RoundRespawn for the upgrade reset to work properly.
static MRESReturn DHookCallback_CTFGameRules_RoundRespawn_Pre()
{
	// Switch team credits if the teams are being switched
	if (SDKCall_ShouldSwitchTeams())
	{
		int redCredits = MvMTeam(TFTeam_Red).AcquiredCredits;
		int blueCredits = MvMTeam(TFTeam_Blue).AcquiredCredits;
		
		MvMTeam(TFTeam_Red).AcquiredCredits = blueCredits;
		MvMTeam(TFTeam_Blue).AcquiredCredits = redCredits;
	}
	
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
				int spentCurrency = SDKCall_GetPlayerCurrencySpent(g_PopulationManager, client);
				SDKCall_AddPlayerCurrencySpent(g_PopulationManager, client, -spentCurrency);
				MvMPlayer(client).Currency = sm_mvm_currency_starting.IntValue;
				MvMPlayer(client).AcquiredCredits = 0;
			}
		}
		
		// Reset player and item upgrades
		SDKCall_ResetMap(g_PopulationManager);
	}
	else
	{
		// Retain player upgrades (forces a call to CTFPlayer::ReapplyPlayerUpgrades)
		SetEntData(g_PopulationManager, GetOffset("CPopulationManager", "m_isRestoringCheckpoint"), true, 1);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_RoundRespawn_Post()
{
	SetEntData(g_PopulationManager, GetOffset("CPopulationManager", "m_isRestoringCheckpoint"), false, 1);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_CheckRespawnWaves_Pre()
{
	// Enable fast respawn for Scouts
	SetMannVsMachineMode(true);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_CheckRespawnWaves_Post()
{
	ResetMannVsMachineMode();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_ShouldRespawnQuickly_Pre(DHookReturn ret, DHookParam params)
{
	int player = params.Get(1);
	
	if (TF2_GetClientTeam(player) > TFTeam_Spectator && TF2_GetPlayerClass(player) == TFClass_Scout)
	{
		ret.Value = true;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}
