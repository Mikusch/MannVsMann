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

// MvMPlayer properties
static int g_PlayerTeamCount[MAXPLAYERS + 1];
static TFTeam g_PlayerTeam[MAXPLAYERS + 1][8];
static int g_PlayerIsMiniBossCount[MAXPLAYERS + 1];
static int g_PlayerIsMiniBoss[MAXPLAYERS + 1][8];
static int g_PlayerFlagsCount[MAXPLAYERS + 1];
static int g_PlayerFlags[MAXPLAYERS + 1][8];
static bool g_PlayerHasPurchasedUpgrades[MAXPLAYERS + 1];
static bool g_PlayerIsClosingUpgradeMenu[MAXPLAYERS + 1];
static int g_PlayerAcquiredCredits[MAXPLAYERS + 1];

// MvMTeam properties
static int g_TeamAcquiredCredits[view_as<int>(TFTeam_Blue) + 1];
static int g_TeamWorldMoney[view_as<int>(TFTeam_Blue) + 1];

methodmap MvMPlayer
{
	public MvMPlayer(int client)
	{
		return view_as<MvMPlayer>(client);
	}
	
	property int _client
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property bool HasPurchasedUpgrades
	{
		public get()
		{
			return g_PlayerHasPurchasedUpgrades[this._client];
		}
		public set(bool value)
		{
			g_PlayerHasPurchasedUpgrades[this._client] = value;
		}
	}
	
	property bool IsClosingUpgradeMenu
	{
		public get()
		{
			return g_PlayerIsClosingUpgradeMenu[this._client];
		}
		public set(bool value)
		{
			g_PlayerIsClosingUpgradeMenu[this._client] = value;
		}
	}
	
	property int AcquiredCredits
	{
		public get()
		{
			return g_PlayerAcquiredCredits[this._client];
		}
		public set(int value)
		{
			g_PlayerAcquiredCredits[this._client] = value;
		}
	}
	
	property int Currency
	{
		public get()
		{
			return GetEntProp(this._client, Prop_Send, "m_nCurrency");
		}
		public set(int value)
		{
			SetEntProp(this._client, Prop_Send, "m_nCurrency", value);
		}
	}
	
	public void SetTeam(TFTeam team)
	{
		int index = g_PlayerTeamCount[this._client]++;
		g_PlayerTeam[this._client][index] = TF2_GetClientTeam(this._client);
		TF2_SetTeam(this._client, team);
	}
	
	public void ResetTeam()
	{
		int index = --g_PlayerTeamCount[this._client];
		TF2_SetTeam(this._client, g_PlayerTeam[this._client][index]);
	}
	
	public void SetIsMiniBoss(bool isMiniBoss)
	{
		int index = g_PlayerIsMiniBossCount[this._client]++;
		g_PlayerIsMiniBoss[this._client][index] = GetEntProp(this._client, Prop_Send, "m_bIsMiniBoss");
		SetEntProp(this._client, Prop_Send, "m_bIsMiniBoss", isMiniBoss);
	}
	
	public void ResetIsMiniBoss()
	{
		int index = --g_PlayerIsMiniBossCount[this._client];
		SetEntProp(this._client, Prop_Send, "m_bIsMiniBoss", g_PlayerIsMiniBoss[this._client][index]);
	}
	
	public void AddFlags(int flags)
	{
		int index = g_PlayerFlagsCount[this._client]++;
		g_PlayerFlags[this._client][index] = GetEntityFlags(this._client);
		SetEntityFlags(this._client, g_PlayerFlags[this._client][index] | flags);
	}
	
	public void ResetFlags()
	{
		int index = --g_PlayerFlagsCount[this._client];
		SetEntityFlags(this._client, g_PlayerFlags[this._client][index]);
	}
	
	public void RespecUpgrades()
	{
		// This clears the upgrade history and removes upgrade attributes from the player and their items
		KeyValues respec = new KeyValues("MVM_Respec");
		FakeClientCommandKeyValues(this._client, respec);
		delete respec;
	}
	
	public void Reset()
	{
		this.HasPurchasedUpgrades = false;
		this.IsClosingUpgradeMenu = false;
		this.AcquiredCredits = 0;
		this.Currency = mvm_currency_starting.IntValue;
	}
}

methodmap MvMTeam
{
	public MvMTeam(TFTeam team)
	{
		return view_as<MvMTeam>(team);
	}
	
	property int _teamNum
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int AcquiredCredits
	{
		public get()
		{
			return g_TeamAcquiredCredits[this._teamNum];
		}
		public set(int value)
		{
			g_TeamAcquiredCredits[this._teamNum] = value;
		}
	}
	
	property int WorldMoney
	{
		public get()
		{
			return g_TeamWorldMoney[this._teamNum];
		}
		public set(int value)
		{
			g_TeamWorldMoney[this._teamNum] = value;
		}
	}
}
