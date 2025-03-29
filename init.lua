-- `Shop' mod for Minetest
-- Copyright 2017 James Stevenson
-- Licensed GNU General Public License 3
-- (Or higher, as you please.)
-- minetest.net
--
-- Sep-2019: modified by JoSto 

local S = minetest.get_translator("shop")
local MP = minetest.get_modpath("shop")
local debit = dofile(MP .. "/debit.lua")
local overview = dofile(MP .. "/overview.lua")

local output = function(name, message)
	minetest.chat_send_player(name, message)
end

local function get_price(item)
	local name = item:get_name()
	local price = minetest.get_item_group(name, "amout") * item:get_count()
	if price and price > 0 then
		return price
	end
	return 0
end

local function player_has_debitcard(pinv)
	if pinv:contains_item("main", "shop:debitcard") then
		return true
	end
	return false
end

-- For banks only.
local function shop_has_goldcard(inv)
	if inv:contains_item("stock", "shop:goldcard") then
		return true
	end
	return false
end

local function shop_has_debitcard(inv)
	if inv:contains_item("register", "shop:debitcard") then
		return true
	end
	return false
end

local function player_has_funds(player, pinv, funds)
	local price = get_price(funds)
	if price > 0 and player_has_debitcard(pinv) then
		if debit.has_debit(player, price) then
			return true
		end
	end
	if pinv:contains_item("main", funds) then
		return true
	end
	return false
end

local function player_has_space_for_goods(player, pinv, goods)
	local price = get_price(goods)
	if price > 0 and player_has_debitcard(pinv) then
		return true
	end
	if pinv:room_for_item("main", goods) then
		return true
	end
	return false
end

local function goods_in_stock(inv, goods)
	local price = get_price(goods)
	if price > 0 and shop_has_goldcard(inv) then
		return true
	end
	if inv:contains_item("stock", goods) then
		return true
	end
	return false
end

-- Move goods from shop to player.
-- This can be:
--  - Real goods from the shop's stock moved to the player's inventory.
--  - Bank with gold card: Money from the shop's gold card, credited to the player, if the player has a debit card.
--  - Bank with gold card:: Money from the shop's gold card, moved to the player's inventory, if the player has no debit card.
local function move_goods_from_shop_to_player(sender, owner, inv, pinv, goods)
	local price = get_price(goods)
	if price > 0 then -- is money
		if shop_has_goldcard(inv) then
			if player_has_debitcard(pinv) then
				local amount = debit.add_debit(sender, price)
				output(sender:get_player_name(), S("Refunded by debit card. Your balance is @1 €.", amount))
			else
				pinv:add_item("main", goods)
			end
		end
	else -- real goods
		pinv:add_item("main", inv:remove_item("stock", goods))
	end
end

-- Move funds from player to shop.
-- This can be:
--  - Real goods from the player's inventory moved to the shop's register.
--  - Money from the player's debit card, moved to the shop's register.
--  - Money from the player's debit card, moved to the owner's account, if the register has a debit card.
--  - Money from the player's inventory, moved to the shop's register.
--  - Money from the player's inventory, moved to the owner's account, if the register has a debit card.
local function move_funds_from_player_to_shop(sender, owner, inv, pinv, funds)
	local price = get_price(funds)
	if price > 0 then -- is money
		if player_has_debitcard(pinv) then
			local amount = debit.take_debit(sender, price)
			output(sender:get_player_name(), S("Paid by debit card. Your balance is @1 €.", amount))
			if shop_has_debitcard(inv) then
				debit.credit(owner, price)
			else
				inv:add_item("register", funds)
			end
		else -- No debit card.
			if shop_has_debitcard(inv) then
				debit.credit(owner, price)
				pinv:remove_item("main", funds)
			else
				inv:add_item("register", pinv:remove_item("main", funds))
			end
		end
	else -- real goods
		inv:add_item("register", pinv:remove_item("main", funds))
	end
end

local function register_goods(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local owner = meta:get_string("owner")
	local location = meta:get_string("location")
	for idx = 1,meta:get_int("pages_total") do
		local key = (minetest.hash_node_position(pos) * 64) + idx
		local item = inv:get_list("sell" .. idx)[1]
		if inv:contains_item("stock", item) then
			local name = item:get_name() .. " " ..  item:get_count()
			local item = inv:get_list("buy" .. idx)[1]
			local price = item:get_name() .. " " ..  item:get_count()
			overview.register_goods(key, name, price, pos, owner, location)
		end
	end
end

local function drop_last_items(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local owner = meta:get_string("owner")
	local location = meta:get_string("location")
	for idx = 1,meta:get_int("pages_total") do
		local item = inv:get_list("sell" .. idx)[1]
		if not item:is_empty() then
			minetest.add_item(pos, item)
		end
		item = inv:get_list("buy" .. idx)[1]
		if not item:is_empty() then
			minetest.add_item(pos, item)
		end
	end
end

local function get_shop_formspec(pos, meta, p)
	local spos = pos.x.. "," ..pos.y .. "," .. pos.z
	local formspec =
		"size[8,7.2]" ..
		default.gui_bg ..
		default.gui_bg_img ..
		default.gui_slots ..
		"label[0,1;" .. S("Goods") .. "]" ..
		"label[3,1;" .. S("Price") .. "]" ..
		"button[0,0;2,1;ok;" .. S("Buy") .. "]" ..
		"button_exit[3,0;2,1;exit;" .. S("Exit") .. "]" ..
		"button[6,0;2,1;stock;" .. S("Stock") .. "]" ..
		"button[6,1;2,1;register;" .. S("Cash register") .. "]" ..
		"button[0,2;1,1;prev;<]" ..
		"button[1,2;1,1;next;>]" ..
		"field[3.3,2.8;5,0.6;location;" .. S("Shop location:") .. ";" .. meta:get_string("location") .. "]" ..
		"list[nodemeta:" .. spos .. ";sell" .. p .. ";1,1;1,1;]" ..
		"list[nodemeta:" .. spos .. ";buy" .. p .. ";4,1;1,1;]" ..
		"list[current_player;main;0,3.45;8,4;]"
	return formspec
end

local formspec_register =
	"size[8,9]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"label[0,0;" .. S("Cash register") .. "  " .. S("(For a transfer instead of cash, deposit debit card)") .. "]" ..
	"list[current_name;register;0,0.75;8,4;]" ..
	"list[current_player;main;0,5.25;8,4;]" ..
	"listring[]"

local formspec_stock =
	"size[8,9]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"label[0,0;" .. S("Stock for goods") .. "]" ..
	"list[current_name;stock;0,0.75;8,4;]" ..
	"list[current_player;main;0,5.25;8,4;]" ..
	"listring[]"

minetest.register_privilege("shop_admin", {
	description = S("Shop administration and maintenance"),
	give_to_singleplayer = false,
	give_to_admin = true,
})

minetest.register_node("shop:shop", {
	description = S("Shop"),
	tiles = {
		"shop_shop_topbottom.png",
		"shop_shop_topbottom.png",
		"shop_shop_side.png",
		"shop_shop_side.png",
		"shop_shop_side.png",
		"shop_shop_front.png",
	},
	groups = {choppy = 3, oddly_breakable_by_hand = 1},
	paramtype2 = "facedir",
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		meta:set_string("pos", pos.x .. "," .. pos.y .. "," .. pos.z)
		local owner = placer:get_player_name()

		meta:set_string("owner", owner)
		meta:set_string("infotext", S("Shop (Owned by @1)", owner))
		meta:set_string("formspec", get_shop_formspec(pos, meta, 1))
		meta:set_string("admin_shop", "false")
		meta:set_int("pages_current", 1)
		meta:set_int("pages_total", 1)

		local inv = meta:get_inventory()
		inv:set_size("buy1", 1)
		inv:set_size("sell1", 1)
		inv:set_size("stock", 8*4)
		inv:set_size("register", 8*4)
	end,
	on_skeleton_key_use = function(pos, player)
		if not minetest.check_player_privs(player, "shop_admin") then
			return
		end
		local meta = minetest.get_meta(pos)
		if meta:get_string("admin_shop") == "false" then
			output(player:get_player_name(), S("Enabling infinite stocks in shop."))
			meta:set_string("admin_shop", "true")
		elseif meta:get_string("admin_shop") == "true" then
			output(player:get_player_name(), S("Disabling infinite stocks in shop."))
			meta:set_string("admin_shop", "false")
		end
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		local node_pos = minetest.string_to_pos(meta:get_string("pos"))
		local owner = meta:get_string("owner")
		local inv = meta:get_inventory()
		local pg_current = meta:get_int("pages_current")
		local pg_total = meta:get_int("pages_total")
		local shop2player = inv:get_list("sell" .. pg_current)
		local player2shop = inv:get_list("buy" .. pg_current)
		local playername = sender:get_player_name()
		local pinv = sender:get_inventory()
		local admin_shop = meta:get_string("admin_shop")
		
		if fields.location then
			if playername == owner then
				meta:set_string("location", fields.location)
			end
		end
		if fields.next then
			if pg_total < 32 and
					pg_current == pg_total and
					playername == owner and
					not (inv:is_empty("sell" .. pg_current) or inv:is_empty("buy" .. pg_current)) then
				inv:set_size("buy" .. pg_current + 1, 1)
				inv:set_size("sell" .. pg_current + 1, 1)
				meta:set_string("formspec", get_shop_formspec(node_pos, meta, pg_current + 1))
				meta:set_int("pages_current", pg_current + 1) 
				meta:set_int("pages_total", pg_current + 1)
			elseif pg_total > 1 then
				if inv:is_empty("sell" .. pg_current) and inv:is_empty("buy" .. pg_current) then
					if pg_current == pg_total then
						meta:set_int("pages_total", pg_total - 1)
					else
						for i = pg_current, pg_total do
							inv:set_list("buy" .. i, inv:get_list("buy" .. i + 1))
							inv:set_list("sell" .. i, inv:get_list("sell" .. i + 1))
							inv:set_list("buy" .. i + 1, nil)
							inv:set_list("sell" .. i + 1, nil)
						end
						meta:set_int("pages_total", pg_total - 1)
						pg_current = pg_current - 1
					end
				end
				if pg_current < pg_total then
					meta:set_int("pages_current", pg_current + 1)
				else
					meta:set_int("pages_current", 1)
				end
				meta:set_string("formspec", get_shop_formspec(node_pos, meta, meta:get_int("pages_current")))
			end
		elseif fields.prev then
			if pg_total > 1 then
				if inv:is_empty("sell" .. pg_current) and inv:is_empty("buy" .. pg_current) then
					if pg_current == pg_total then
						meta:set_int("pages_total", pg_total - 1)
					else
						for i  = pg_current, pg_total do
							inv:set_list("buy" .. i, inv:get_list("buy" .. i + 1))
							inv:set_list("sell" .. i, inv:get_list("sell" .. i + 1))
							inv:set_list("buy" .. i + 1, nil)
							inv:set_list("sell" .. i + 1, nil)
						end
						meta:set_int("pages_total", pg_total - 1)
						pg_current = pg_current + 1
					end
				end
				if pg_current == 1 and pg_total > 1 then
					meta:set_int("pages_current", pg_total)
				elseif pg_current > 1 then
					meta:set_int("pages_current", pg_current - 1)
				end
				meta:set_string("formspec", get_shop_formspec(node_pos, meta, meta:get_int("pages_current")))
			end
		elseif fields.register then
			if playername ~= owner and (not minetest.check_player_privs(playername, "shop_admin")) then
				output(playername, S("Only the shop owner can open the register."))
				return
			else
				minetest.show_formspec(playername, "shop:shop", formspec_register)
			end
		elseif fields.stock then
			if playername ~= owner and (not minetest.check_player_privs(playername, "shop_admin")) then
				output(playername, S("Only the shop owner can open the stock."))
				return
			else
				minetest.show_formspec(playername, "shop:shop", formspec_stock)
			end
		elseif fields.ok then
			-- Shop's closed if not set up, or the till is full.
			if inv:is_empty("sell" .. pg_current) or
				inv:is_empty("buy" .. pg_current) or
				(not inv:room_for_item("register", player2shop[1])) then
				output(playername, S("Shop closed."))
				return
			end

			if player_has_funds(sender, pinv, player2shop[1]) then
				if player_has_space_for_goods(sender, pinv, shop2player[1]) then
					if goods_in_stock(inv, shop2player[1]) then
						move_goods_from_shop_to_player(sender, owner, inv, pinv, shop2player[1])
						move_funds_from_player_to_shop(sender, owner, inv, pinv, player2shop[1])
					else
						output(playername, S("Goods no longer in stock!"))
						local key = (minetest.hash_node_position(pos) * 64) + pg_current
						overview.remove_goods(key)
					end
				else
					output(playername, S("You're all filled up!"))
				end
			else
				output(playername, S("Not enough credits!")) -- 32X.
			end
		end
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local inv = meta:get_inventory()
		local playername = player:get_player_name()
		if playername ~= owner and
			(not minetest.check_player_privs(playername, "shop_admin")) then
			return 0
		else
			return stack:get_count()
		end
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local playername = player:get_player_name()
		if playername ~= owner and
			(not minetest.check_player_privs(playername, "shop_admin"))then
			return 0
		else
			return stack:get_count()
		end
	end,
	allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		local playername = player:get_player_name()
		if playername ~= owner and
			(not minetest.check_player_privs(playername, "shop_admin")) then
			return 0
		else
			return count
		end
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		register_goods(pos)
	end,
	on_metadata_inventory_take = function(pos, listname, index, stack, player)
		register_goods(pos)
	end,
	can_dig = function(pos, player) 
		local meta = minetest.get_meta(pos) 
		local owner = meta:get_string("owner") 
		local inv = meta:get_inventory() 
		if player:get_player_name() == owner and inv:is_empty("register") and inv:is_empty("stock") then
			for idx = 1,meta:get_int("pages_total") do 
				local key = (minetest.hash_node_position(pos) * 64) + idx 
				overview.remove_goods(key) 
			end
			drop_last_items(pos)
			return true
		else
			return false
		end
	end,
})

minetest.register_craftitem("shop:geld1E", {
	description = S("Banknote 1€"),
	inventory_image = "shop_1E.png",
	groups = {money=1, amout=1},
	stack_max = 999,
})

minetest.register_craftitem("shop:geld10E", {
	description = S("Banknote 10€"),
	inventory_image = "shop_10E.png",
	groups = {money=1, amout=10},
	stack_max = 999,
})

minetest.register_craftitem("shop:geld100E", {
	description = S("Banknote 100€"),
	inventory_image = "shop_100E.png",
	groups = {money=1, amout=100},
	stack_max = 999,
})

minetest.register_craftitem("shop:geld1000E", {
	description = S("Banknote 1000€"),
	inventory_image = "shop_1000E.png",
	groups = {money=1, amout=1000},
	stack_max = 999,
})

minetest.register_craftitem("shop:debitcard", {
	description = S("Debit Card"),
	inventory_image = "shop_debit.png",
	groups = {money=1},
	stack_max = 1,
})

minetest.register_craftitem("shop:goldcard", {
	description = S("Gold Card"),
	inventory_image = "shop_gold.png",
	groups = {money=1, not_in_creative_inventory = 1},
	stack_max = 1,
})

minetest.register_craft({
	output = "shop:shop",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:wood", "default:gold_ingot", "group:wood"},
		{"group:wood", "group:wood", "group:wood"}
	}
})

minetest.register_lbm({
	name = "shop:register",
	nodenames = {"shop:shop"},
	run_at_every_load = true,
	action = function(pos)
		register_goods(pos)
	end
})
