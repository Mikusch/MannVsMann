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
static DynamicHook g_DHookShouldRespawnQuickly;
static DynamicHook g_DHookRoundRespawn;

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CPopulationManager::ResetMap", DHookCallback_PopulationManagerResetMap_Pre, DHookCallback_PopulationManagerResetMap_Post);
	CreateDynamicDetour(gamedata, "CPopulationManager::Update", DHookCallback_PopulationManagerUpdate_Pre, _);
	CreateDynamicDetour(gamedata, "CTFGameRules::GameModeUsesUpgrades", _, DHookCallback_GameModeUsesUpgrades_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::CanPlayerUseRespec", DHookCallback_CanPlayerUseRespec_Pre, _);
	CreateDynamicDetour(gamedata, "CTFGameRules::IsQuickBuildTime", DHookCallback_IsQuickBuildTime_Pre, DHookCallback_IsQuickBuildTime_Post);
	CreateDynamicDetour(gamedata, "CTFPlayerShared::ConditionGameRulesThink", DHookCallback_ConditionGameRulesThink_Pre, DHookCallback_ConditionGameRulesThink_Post);
	CreateDynamicDetour(gamedata, "CTFGameRules::DistributeCurrencyAmount", DHookCallback_DistributeCurrencyAmount_Pre, DHookCallback_DistributeCurrencyAmount_Post);
	
	g_DHookComeToRest = CreateDynamicHook(gamedata, "CItem::ComeToRest");
	g_DHookValidTouch = CreateDynamicHook(gamedata, "CTFPowerup::ValidTouch");
	g_DHookEventKilled = CreateDynamicHook(gamedata, "CTFPlayer::Event_Killed");
	g_DHookShouldRespawnQuickly = CreateDynamicHook(gamedata, "CTFGameRules::ShouldRespawnQuickly");
	g_DHookRoundRespawn = CreateDynamicHook(gamedata, "CTFGameRules::RoundRespawn");
}

void DHooks_HookClient(int client)
{
	g_DHookEventKilled.HookEntity(Hook_Pre, client, DHookCallback_EventKilled_Pre);
	g_DHookEventKilled.HookEntity(Hook_Post, client, DHookCallback_EventKilled_Post);
}

void DHooks_HookGameRules()
{
	g_DHookShouldRespawnQuickly.HookGamerules(Hook_Pre, DHookCallback_ShouldRespawnQuickly_Pre);
	g_DHookShouldRespawnQuickly.HookGamerules(Hook_Post, DHookCallback_ShouldRespawnQuickly_Post);
	
	g_DHookRoundRespawn.HookGamerules(Hook_Pre, DHookCallback_RoundRespawn_Pre);
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "item_currencypack", 17) == 0)
	{
		g_DHookComeToRest.HookEntity(Hook_Pre, entity, DHookCallback_ComeToRest_Pre);
		g_DHookComeToRest.HookEntity(Hook_Post, entity, DHookCallback_ComeToRest_Post);
		
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

public MRESReturn DHookCallback_PopulationManagerResetMap_Pre()
{
	//CPopulationManager::ResetMap resets upgrades for defenders
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

public MRESReturn DHookCallback_PopulationManagerUpdate_Pre()
{
	//Prevent the populator doing unwanted stuff, like a call to CPopulationManager::AllocateBots
	return MRES_Supercede;
}

public MRESReturn DHookCallback_GameModeUsesUpgrades_Post(DHookReturn ret)
{
	//Fixes various upgrades and enables MvM-related features
	ret.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHookCallback_CanPlayerUseRespec_Pre(DHookReturn ret)
{
	//Always allow respecs
	ret.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHookCallback_ComeToRest_Pre(int item)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
	//This is required because CTFPlayer::DropCurrencyPack does not assign a team to currency packs normally,
	//but CTFGameRules::DistributeCurrencyAmount needs to know the team to distribute the money to teammates
	g_CurrencyPackTeam = TF2_GetTeam(item);
}

public MRESReturn DHookCallback_ComeToRest_Post(int item)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
	
	g_CurrencyPackTeam = TFTeam_Unassigned;
}

public MRESReturn DHookCallback_ValidTouch_Pre(int powerup, DHookReturn ret, DHookParam params)
{
	//CTFPowerup::ValidTouch doesn't allow TF_TEAM_PVE_INVADERS to collect money
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_ValidTouch_Post(int powerup, DHookReturn ret, DHookParam params)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_EventKilled_Pre(int client)
{
	//Players in MvM create revive markers on death
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
}

public MRESReturn DHookCallback_EventKilled_Post(int client)
{
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
}

public MRESReturn DHookCallback_IsQuickBuildTime_Pre()
{
	//Engineers in MvM are allowed to quickbuild during Setup
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

public MRESReturn DHookCallback_DistributeCurrencyAmount_Pre(DHookReturn ret, DHookParam params)
{
	//Instead of changing every player's teams to allow money distribution,
	//let's keep things simple and replace the logic with our own
	
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		int amount = params.Get(1);
		bool shared = params.Get(3);
		
		if (shared)
		{
			//If the player is NULL, take the value of g_CurrencyPackTeam as a different hook has likely set it to something
			TFTeam team = params.IsNull(2) ? g_CurrencyPackTeam : TF2_GetClientTeam(params.Get(2));
			
			for (int client = 1; client <= MaxClients; client++)
			{
				//Always let people in the correct team through
				if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
				{
					MvMPlayer(client).AddCurrency(amount);
					EmitSoundToClient(client, SOUND_CREDITS_UPDATED, _, SNDCHAN_STATIC, SNDLEVEL_NONE, _, 0.1);
				}
			}
			
			MvMTeam(team).AcquiredCredits += amount;
		}
		else if (!params.IsNull(2))
		{
			MvMPlayer(params.Get(2)).AddCurrency(amount);
		}
		
		//Do not let TF2 call this function, it would lead to RED getting money twice
		ret.Value = params.Get(1);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_DistributeCurrencyAmount_Post(DHookReturn ret, DHookParam params)
{
	//We don't need this anymore after the call to DistributeCurrencyAmount
	g_CurrencyPackTeam = TFTeam_Unassigned;
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Pre(DHookReturn ret, DHookParam params)
{
	int client = params.Get(1);
	
	//Allows Scouts to respawn quickly
	GameRules_SetProp("m_bPlayingMannVsMachine", true);
	
	//Hardcoded TF_TEAM_PVE_DEFENDERS check
	MvMPlayer(client).MoveToDefenderTeam();
}

public MRESReturn DHookCallback_ShouldRespawnQuickly_Post(DHookReturn ret, DHookParam params)
{
	int client = params.Get(1);
	
	GameRules_SetProp("m_bPlayingMannVsMachine", false);
	
	MvMPlayer(client).MoveToPreHookTeam();
}

public MRESReturn DHookCallback_RoundRespawn_Pre()
{
	//Combines the functionality of several event hooks
	//Required because teamplay_round_start fires right after the call to RoundRespawn, which is too late to reset player upgrades
	
	int gamerules = FindEntityByClassname(MaxClients + 1, "tf_gamerules");
	if (gamerules != -1)
	{
		bool forceMapReset = view_as<bool>(GetEntData(gamerules, g_OffsetForceMapReset));
		if (forceMapReset)
		{
			//Reset accumulated team credits
			for (TFTeam team = TFTeam_Unassigned; team <= TFTeam_Blue; team++)
			{
				MvMTeam(team).AcquiredCredits = 0;
			}
			
			//Reset player credits
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					MvMPlayer(client).Currency = mvm_start_credits.IntValue;
				}
			}
			
			//Reset player upgrades and upgrade history
			int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
			if (populator != -1)
			{
				SDKCall_ResetMap(populator);
			}
		}
	}
}
