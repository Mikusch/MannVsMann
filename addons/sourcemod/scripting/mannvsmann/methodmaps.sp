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

static int g_PlayerTeamCount[MAXPLAYERS + 1];
static TFTeam g_PlayerTeam[MAXPLAYERS + 1][8];
static bool g_PlayerHasPurchasedUpgrades[MAXPLAYERS + 1];
static bool g_PlayerIsClosingUpgradeMenu[MAXPLAYERS + 1];

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
	
	property bool HasPurchasedUpgrades
	{
		public get()
		{
			return g_PlayerHasPurchasedUpgrades[this];
		}
		public set(bool val)
		{
			g_PlayerHasPurchasedUpgrades[this] = val;
		}
	}
	
	property bool IsClosingUpgradeMenu
	{
		public get()
		{
			return g_PlayerIsClosingUpgradeMenu[this];
		}
		public set(bool val)
		{
			g_PlayerIsClosingUpgradeMenu[this] = val;
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
	
	public void SetTeam(TFTeam team)
	{
		int index = g_PlayerTeamCount[this]++;
		g_PlayerTeam[this][index] = TF2_GetClientTeam(this.Client);
		TF2_SetTeam(this.Client, team);
	}
	
	public void ResetTeam()
	{
		int index = --g_PlayerTeamCount[this];
		TF2_SetTeam(this.Client, g_PlayerTeam[this][index]);
	}
	
	public void RemoveAllUpgrades()
	{
		//This clears the upgrade history and removes upgrade attributes from the player and their items
		KeyValues respec = new KeyValues("MVM_Respec");
		FakeClientCommandKeyValues(this.Client, respec);
		delete respec;
	}
	
	public void Reset()
	{
		this.HasPurchasedUpgrades = false;
		this.IsClosingUpgradeMenu = false;
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
