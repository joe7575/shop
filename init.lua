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

local output = function(name, message)
	minetest.chat_send_player(name, message)
end

local function get_shop_formspec(pos, p)
	local spos = pos.x.. "," ..pos.y .. "," .. pos.z
	local formspec =
		"size[8,7]" ..
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
		"list[nodemeta:" .. spos .. ";sell" .. p .. ";1,1;1,1;]" ..
		"list[nodemeta:" .. spos .. ";buy" .. p .. ";4,1;1,1;]" ..
		"list[current_player;main;0,3.25;8,4;]"
	return formspec
end

local formspec_register =
	"size[8,9]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"label[0,0;" .. S("Cash register") .. "]" ..
	"list[current_name;register;0,0.75;8,4;]" ..
	"list[current_player;main;0,5.25;8,4;]" ..
	"listring[]"

local formspec_stock =
	"size[8,9]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"label[0,0;" .. S("Stock") .. "]" ..
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
		meta:set_string("formspec", get_shop_formspec(pos, 1))
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
		local s = inv:get_list("sell" .. pg_current)
		local b = inv:get_list("buy" .. pg_current)
		local player = sender:get_player_name()
		local pinv = sender:get_inventory()
		local admin_shop = meta:get_string("admin_shop")
		
		if fields.next then
			if pg_total < 32 and
					pg_current == pg_total and
					player == owner and
					not (inv:is_empty("sell" .. pg_current) or inv:is_empty("buy" .. pg_current)) then
				inv:set_size("buy" .. pg_current + 1, 1)
				inv:set_size("sell" .. pg_current + 1, 1)
				meta:set_string("formspec", get_shop_formspec(node_pos, pg_current + 1))
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
				meta:set_string("formspec", get_shop_formspec(node_pos, meta:get_int("pages_current")))
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
				meta:set_string("formspec", get_shop_formspec(node_pos, meta:get_int("pages_current")))
			end
		elseif fields.register then
			if player ~= owner and (not minetest.check_player_privs(player, "shop_admin")) then
				output(player, S("Only the shop owner can open the register."))
				return
			else
				minetest.show_formspec(player, "shop:shop", formspec_register)
			end
		elseif fields.stock then
			if player ~= owner and (not minetest.check_player_privs(player, "shop_admin")) then
				output(player, S("Only the shop owner can open the stock."))
				return
			else
				minetest.show_formspec(player, "shop:shop", formspec_stock)
			end
		elseif fields.ok then
			-- Shop's closed if not set up, or the till is full.
			if inv:is_empty("sell" .. pg_current) or
				inv:is_empty("buy" .. pg_current) or
				(not inv:room_for_item("register", b[1])) then
				output(player, S("Shop closed."))
				return
			end

			-- Player has funds.
			if pinv:contains_item("main", b[1]) then
				-- Player has space for the goods.
				if pinv:room_for_item("main", s[1]) then
					-- There's inventory in stock.
					if inv:contains_item("stock", s[1]) then
						-- Pay with debit card (move item from stock to player register).
						local item = b[1]:get_name()
						local price = minetest.get_item_group(item, "amout") * b[1]:get_count()
						if price and price > 0 then
							if debit.has_debit(sender, price) then
								local owner = meta:get_string("owner")
								local amount = debit.take_debit(sender, price)
								debit.credit(owner, price)
								local sold = inv:remove_item("stock", s[1]) -- Take one from the stock.
								pinv:add_item("main", sold) -- Give it to the player.
								minetest.chat_send_player(player, S("Paid by debit card. Your balance is @1 €.", amount))
								return
							end
						end

						-- Load the debit card (move item from player register to stock).
						item = s[1]:get_name()
						price = minetest.get_item_group(item, "amout") * s[1]:get_count()
						if price and price > 0 then
							if debit.has_debit(sender, 0) and pinv:contains_item("main", b[1]) then
								if inv:contains_item("stock", "shop:goldcard") then
									local amount = debit.add_debit(sender, price)
									pinv:remove_item("main", b[1]) -- Take one from the player.
									inv:add_item("register", b[1]) -- Fill the register
									minetest.chat_send_player(player, S("Refunded by debit card. Your balance is @1 €.", amount))
									return
								end
							end
						end

						-- Pay with banknotes
						pinv:remove_item("main", b[1]) -- Take the funds.
						inv:add_item("register", b[1]) -- Fill the till.
						local sold = inv:remove_item("stock", s[1]) -- Take one from the stock.
						pinv:add_item("main", sold) -- Give it to the player.
					elseif admin_shop == "true" then
						pinv:remove_item("main", b[1])
						inv:add_item("register", b[1])
						pinv:add_item("main", s[1])
					else
						output(player, S("Goods no longer in stock!"))
					end
				else
					output(player, S("You're all filled up!"))
				end
			else
				output(player, S("Not enough credits!")) -- 32X.
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
	can_dig = function(pos, player) 
				local meta = minetest.get_meta(pos) 
				local owner = meta:get_string("owner") 
				local inv = meta:get_inventory() 
				return player:get_player_name() == owner and
			inv:is_empty("register") and
			inv:is_empty("stock") and
			-- FIXME Make all contents in the buy/sell lists drop as items.
			inv:is_empty("buy1") and
			inv:is_empty("sell1")
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
