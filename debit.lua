-- `Shop' mod for Minetest
-- Copyright 2017 James Stevenson, 2025 Joachim Stolberg
-- Licensed GNU General Public License 3
-- (Or higher, as you please.)

local S = minetest.get_translator("shop")
local storage = minetest.get_mod_storage()
local debit = {}

local function transfer(player)
	local meta = player:get_meta()
	local debit = meta:get_int("shop_debit")
	local key = "shop_debit_" .. player:get_player_name()
	local amount = storage:get_int(key)
	meta:set_int("shop_debit", debit + amount)
	storage:set_int(key, 0)
end

function debit.has_debit(player, amount)
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

function debit.take_debit(player, amount)
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

function debit.add_debit(player, amount)
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

function debit.credit(owner, amount)
	local player = minetest.get_player_by_name(owner)
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

minetest.register_chatcommand("balance", {
	privs = {interact = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			local meta = player:get_meta()
			local debit = meta:get_int("shop_debit")
			minetest.chat_send_player(name, S("Your balance is @1 €", debit))
		end
	end,
})

minetest.register_on_joinplayer(function(player)
	transfer(player)
end)

return debit

