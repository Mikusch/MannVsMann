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

static TFTeam g_PlayerPreHookTeam[TF_MAXPLAYERS + 1];

static int g_TeamAcquiredCredits[view_as<int>(TFTeam_Blue) + 1];
static int g_TeamWorldCredits[view_as<int>(TFTeam_Blue) + 1];

methodmap MvMPlayer
{
	public MvMPlayer(int client)
	{
		return view_as<MvMPlayer>(client);
	}
	
	property int Client
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int Currency
	{
		public get()
		{
			return GetEntProp(this.Client, Prop_Send, "m_nCurrency");
		}
		public set(int val)
		{
			SetEntProp(this.Client, Prop_Send, "m_nCurrency", val);
		}
	}
	
	property TFTeam PreHookTeam
	{
		public get()
		{
			return g_PlayerPreHookTeam[this];
		}
		public set(TFTeam team)
		{
			g_PlayerPreHookTeam[this] = team;
		}
	}
	
	public void MoveToDefenderTeam()
	{
		this.PreHookTeam = TF2_GetClientTeam(this.Client);
		TF2_SetTeam(this.Client, TF_TEAM_PVE_DEFENDERS);
	}
	
	public void MoveToInvaderTeam()
	{
		this.PreHookTeam = TF2_GetClientTeam(this.Client);
		TF2_SetTeam(this.Client, TF_TEAM_PVE_INVADERS);
	}
	
	public void MoveToPreHookTeam()
	{
		if (this.PreHookTeam != TFTeam_Invalid)
		{
			TF2_SetTeam(this.Client, this.PreHookTeam);
			this.PreHookTeam = TFTeam_Invalid;
		}
	}
	
	public void AddCurrency(int amount)
	{
		this.Currency = Clamp(this.Currency + amount, 0, mvm_max_credits.IntValue);
	}
	
	public void RefundAllUpgrades()
	{
		//This function sends a LOT of data and may cause buffer overflows if used too frequently
		//Prefer an SDKCall to CPopulationManager::ResetMap for mass-refunds
		
		int populator = FindEntityByClassname(MaxClients + 1, "info_populator");
		if (populator != -1)
		{
			GameRules_SetProp("m_bPlayingMannVsMachine", true);
			
			//Required for respec to work
			SetEntProp(this.Client, Prop_Send, "m_bInUpgradeZone", true);
			
			//Required for player upgrades to be removed properly
			SetEntData(populator, g_OffsetRestoringCheckpoint, true);
			
			KeyValues respec = new KeyValues("MVM_Respec");
			FakeClientCommandKeyValues(this.Client, respec);
			delete respec;
			
			SetEntData(populator, g_OffsetRestoringCheckpoint, false);
			
			GameRules_SetProp("m_bPlayingMannVsMachine", false);
		}
	}
}

methodmap MvMTeam
{
	public MvMTeam(TFTeam team)
	{
		return view_as<MvMTeam>(team);
	}
	
	property int AcquiredCredits
	{
		public get()
		{
			return g_TeamAcquiredCredits[this];
		}
		public set(int val)
		{
			g_TeamAcquiredCredits[this] = val;
		}
	}
	
	property int WorldCredits
	{
		public get()
		{
			return g_TeamWorldCredits[this];
		}
		public set(int val)
		{
			g_TeamWorldCredits[this] = val;
		}
	}
}
