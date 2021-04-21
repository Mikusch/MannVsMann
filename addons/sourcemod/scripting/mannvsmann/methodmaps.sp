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

static int g_TeamAcquiredCredits[view_as<int>(TFTeam_Blue) + 1];

methodmap MvMPlayer
{
	public MvMPlayer(int client)
	{
		return view_as<MvMPlayer>(client);
	}
	
	property int Currency
	{
		public get()
		{
			return GetEntProp(view_as<int>(this), Prop_Send, "m_nCurrency");
		}
		public set(int val)
		{
			SetEntProp(view_as<int>(this), Prop_Send, "m_nCurrency", val);
		}
	}
	
	public void AddCurrency(int amount)
	{
		this.Currency = Clamp(this.Currency + amount, 0, mvm_max_currency.IntValue);
	}
	
	public void DropCurrencyPack(int amount = 0, bool forceDistribute = false, int moneyMaker = 0)
	{
		float origin[3], angles[3];
		WorldSpaceCenter(view_as<int>(this), origin);
		GetClientAbsAngles(view_as<int>(this), angles);
		
		float velocity[3];
		RandomVector(-1.0, 1.0, velocity);
		velocity[2] = 1.0;
		NormalizeVector(velocity, velocity);
		ScaleVector(velocity, 250.0);
		
		CreateCurrencyPack(origin, angles, velocity, amount, moneyMaker, forceDistribute);
	}
	
	public void RefundAllUpgrades()
	{
		KeyValues respec = new KeyValues("MVM_Respec");
		FakeClientCommandKeyValues(view_as<int>(this), respec);
		delete respec;
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
}
