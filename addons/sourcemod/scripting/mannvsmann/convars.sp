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

void ConVars_Initialize()
{
	mvm_start_currency = CreateConVar("mvm_start_currency", "Amount of cash each player spawns with", "400");
	mvm_currency_elimination = CreateConVar("mvm_currency_elimination", "Amount of cash dropped when a player is killed", "10");
	mvm_currency_capture = CreateConVar("mvm_currency_capture", "Amount of cash dropped when a point is captured", "100");
}
