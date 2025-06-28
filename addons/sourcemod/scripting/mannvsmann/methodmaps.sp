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

// MvMPlayer
static int g_PlayerTeamCount[MAXPLAYERS + 1];
static TFTeam g_PlayerTeam[MAXPLAYERS + 1][8];
static int g_PlayerIsMiniBossCount[MAXPLAYERS + 1];
static int g_PlayerIsMiniBoss[MAXPLAYERS + 1][8];
static int g_PlayerFlagsCount[MAXPLAYERS + 1];
static int g_PlayerFlags[MAXPLAYERS + 1][8];
static bool g_PlayerHasPurchasedUpgrades[MAXPLAYERS + 1];
static bool g_PlayerIsClosingUpgradeMenu[MAXPLAYERS + 1];
static int g_PlayerAcquiredCredits[MAXPLAYERS + 1];

// MvMTeam
static int g_TeamAcquiredCredits[view_as<int>(TFTeam_Blue) + 1];
static int g_TeamWorldMoney[view_as<int>(TFTeam_Blue) + 1];

methodmap MvMPlayer
{
	public MvMPlayer(int client)
	{
		return view_as<MvMPlayer>(client);
	}
	
	property int entindex
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
			return g_PlayerHasPurchasedUpgrades[this.entindex];
		}
		public set(bool value)
		{
			g_PlayerHasPurchasedUpgrades[this.entindex] = value;
		}
	}
	
	property bool IsClosingUpgradeMenu
	{
		public get()
		{
			return g_PlayerIsClosingUpgradeMenu[this.entindex];
		}
		public set(bool value)
		{
			g_PlayerIsClosingUpgradeMenu[this.entindex] = value;
		}
	}
	
	property int AcquiredCredits
	{
		public get()
		{
			return g_PlayerAcquiredCredits[this.entindex];
		}
		public set(int value)
		{
			g_PlayerAcquiredCredits[this.entindex] = value;
		}
	}
	
	property int Currency
	{
		public get()
		{
			return GetEntProp(this.entindex, Prop_Send, "m_nCurrency");
		}
		public set(int value)
		{
			SetEntProp(this.entindex, Prop_Send, "m_nCurrency", Clamp(value, 0, 30000));
		}
	}
	
	public void SetTeam(TFTeam team)
	{
		int index = g_PlayerTeamCount[this.entindex]++;
		g_PlayerTeam[this.entindex][index] = TF2_GetClientTeam(this.entindex);
		TF2_SetEntityTeam(this.entindex, team);
	}
	
	public void ResetTeam()
	{
		int index = --g_PlayerTeamCount[this.entindex];
		TF2_SetEntityTeam(this.entindex, g_PlayerTeam[this.entindex][index]);
	}
	
	public void SetIsMiniBoss(bool isMiniBoss)
	{
		int index = g_PlayerIsMiniBossCount[this.entindex]++;
		g_PlayerIsMiniBoss[this.entindex][index] = GetEntProp(this.entindex, Prop_Send, "m_bIsMiniBoss");
		SetEntProp(this.entindex, Prop_Send, "m_bIsMiniBoss", isMiniBoss);
	}
	
	public bool IsDefender()
	{
		return (GetDefenderTeam() == TFTeam_Any || TF2_GetClientTeam(this.entindex) == GetDefenderTeam());
	}
	
	public void SetMaxPowerupCharges(int maxNumCharges)
	{
		int powerupBottle = TF2Util_GetPlayerLoadoutEntity(this.entindex, LOADOUT_POSITION_ACTION);
		if (powerupBottle != -1)
		{
			if (maxNumCharges != -1)
			{
				if (TF2Attrib_HookValueInt(0, "powerup_max_charges", powerupBottle) != maxNumCharges)
				{
					TF2Attrib_SetByName(powerupBottle, "powerup max charges", float(maxNumCharges));
				}
			}
			else
			{
				TF2Attrib_RemoveByName(powerupBottle, "powerup max charges");
			}
		}
	}
	
	public void ResetIsMiniBoss()
	{
		int index = --g_PlayerIsMiniBossCount[this.entindex];
		SetEntProp(this.entindex, Prop_Send, "m_bIsMiniBoss", g_PlayerIsMiniBoss[this.entindex][index]);
	}
	
	public void AddFlags(int flags)
	{
		int index = g_PlayerFlagsCount[this.entindex]++;
		g_PlayerFlags[this.entindex][index] = GetEntityFlags(this.entindex);
		SetEntityFlags(this.entindex, g_PlayerFlags[this.entindex][index] | flags);
	}
	
	public void ResetFlags()
	{
		int index = --g_PlayerFlagsCount[this.entindex];
		SetEntityFlags(this.entindex, g_PlayerFlags[this.entindex][index]);
	}
	
	public void Reset()
	{
		this.HasPurchasedUpgrades = false;
		this.IsClosingUpgradeMenu = false;
		this.AcquiredCredits = 0;
		this.Currency = sm_mvm_currency_starting.IntValue;
	}
};

methodmap MvMTeam
{
	public MvMTeam(TFTeam team)
	{
		return view_as<MvMTeam>(team);
	}
	
	property int TeamNum
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
			return g_TeamAcquiredCredits[this.TeamNum];
		}
		public set(int value)
		{
			g_TeamAcquiredCredits[this.TeamNum] = value;
		}
	}
	
	property int WorldMoney
	{
		public get()
		{
			return g_TeamWorldMoney[this.TeamNum];
		}
		public set(int value)
		{
			g_TeamWorldMoney[this.TeamNum] = value;
		}
	}
	
	public void Reset()
	{
		this.AcquiredCredits = 0;
		this.WorldMoney = 0;
	}
};
