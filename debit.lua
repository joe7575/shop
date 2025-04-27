--[[
    Shop mod for Minetest to buy/sell items
    Copyright 2017 James Stevenson, 2019 - 2025 Joachim Stolberg

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]--

local S = core.get_translator("shop")
local storage = core.get_mod_storage()

local function transfer(player)
	local meta = player:get_meta()
	local debit = meta:get_int("shop_debit")
	local key = "shop_debit_" .. player:get_player_name()
	local amount = storage:get_int(key)
	meta:set_int("shop_debit", debit + amount)
	storage:set_int(key, 0)
end

function shop.has_debit(player, amount)
	if player and player:is_player() then
		local inv = player:get_inventory()
		if inv:contains_item("main", "shop:debitcard") then
			local meta = player:get_meta()
			local debit = meta:get_int("shop_debit")
			if debit >= amount then
				return true
			end
		end
	end
	return false
end

function shop.take_debit(player, amount)
	if player and player:is_player() then
		local inv = player:get_inventory()
		if inv:contains_item("main", "shop:debitcard") then
			local meta = player:get_meta()
			local debit = meta:get_int("shop_debit")
			if debit >= amount then
				meta:set_int("shop_debit", debit - amount)
				return meta:get_int("shop_debit")
			end
		end
	end
	return 0
end

function shop.add_debit(player, amount)
	if player and player:is_player() then
		local inv = player:get_inventory()
		if inv:contains_item("main", "shop:debitcard") then
			local meta = player:get_meta()
			local debit = meta:get_int("shop_debit")
			meta:set_int("shop_debit", debit + amount)
			return meta:get_int("shop_debit")
		end
	end
	return 0
end

function shop.credit(owner, amount)
	local player = core.get_player_by_name(owner)
	if player and player:is_player() then
		local meta = player:get_meta()
		local debit = meta:get_int("shop_debit")
		meta:set_int("shop_debit", debit + amount)
	else
		local key = "shop_debit_" .. owner
		local debit = storage:get_int(key)
		storage:set_int(key, debit + amount)
	end
end

core.register_chatcommand("balance", {
	privs = {interact = true},
	description = "Check account balance",
	params = "",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if player then
			local meta = player:get_meta()
			local debit = meta:get_int("shop_debit")
			core.chat_send_player(name, S("Your balance is @1 €", debit))
		end
	end,
})

core.register_chatcommand("set_balance", {
	privs = {server = true},
	params = "<name> <value>",
	description = "Set account balance",
	func = function(name, param)
		local destname, value = param:match("^(%S+)%s(.+)$")
		local player = core.get_player_by_name(destname)
		value = tonumber(value or "0") or 0
		if player then
			local meta = player:get_meta()
			meta:set_int("shop_debit", value)
			core.chat_send_player(name, S("The balance of @1 is @2 €", destname, value))
		end
	end,
})

core.register_on_joinplayer(function(player)
	transfer(player)
end)
