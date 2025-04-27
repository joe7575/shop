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

-- Offer overview
-- | Goods | Price | Position | Player | Location |

local S = core.get_translator("shop")
local storage = core.get_mod_storage()

local ShopList = {}	-- Array with shop positions
local GoodsTbl = {} -- structured list with: [key] = {name, price, spos, owner, location}
local FormspecTbl = {} -- comma separated list
local MAX_STR_LEN = 22 -- max length of strings in formspec
local CYCLE_TIME = 60*60 -- every hour

local function get_name(lang_code, item_name)
	if item_name == nil or item_name == "" then
		return ""
	end
	local name, count = item_name:match("([^ ]+) ([0-9]+)")
	local ndef = core.registered_nodes[name] or core.registered_items[name]
	if count and ndef and ndef.description then
		local s = core.get_translated_string(lang_code, ndef.description) or "Oops"
		return core.formspec_escape(s:sub(1, MAX_STR_LEN)) .. " (" .. count .. ")"
	else
		return core.formspec_escape(item_name) 
	end
end

local function formspec(data)
	return "size[12,10]" ..
	"label[5,-0.2;" .. S("Offer Overview") .. "]" ..
	"tablecolumns[text;text;text;text;text]" ..
	"style_type[table;font_size=-2]" ..
	"table[0,0.4;11.8,9.0;button;" .. data .. "]" ..
	"button_exit[5.0,9.5;2,1;exit;Exit]"
end

local function get_formspec_string(lang_code)
	-- generate key list
	local keys = {}
	for key in pairs(GoodsTbl) do
		table.insert(keys, key)
	end
	-- translate goods and price
	local offers = {}
	for key,offer in pairs(GoodsTbl) do
		offers[key] = {
			goods = get_name(lang_code, offer.goods or "oops"),
			price = get_name(lang_code, offer.price or "oops"),
			spos = offer.spos or "oops",
			owner = offer.owner or "oops",
			location = offer.location or "oops"
		}
	end
	-- sort by goods
	table.sort(keys, function(a,b) return offers[a]["goods"] < offers[b]["goods"] end)
	-- Formspec string
	local tbl = {S("Goods (pieces)"), S("Price (pieces)"), S("Position"), S("Owner"), S("Location")}
	for _, key in ipairs(keys) do
		local offer = offers[key]
		table.insert(tbl, offer.goods)
		table.insert(tbl, offer.price)
		table.insert(tbl, offer.spos)
		table.insert(tbl, offer.owner)
		table.insert(tbl, offer.location)
	end
	return table.concat(tbl, ",")
end

core.register_node("shop:overview", {
	description = S("Offer Overview"),
	tiles = {
		-- up, down, right, left, back, front
		"shop_overview.png",
	},

	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -8/16, -8/16, 7.5/16,  8/16,  8/16, 8/16},
		},
	},

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local meta = core.get_meta(pos)
		local lang_code = core.get_player_information(clicker:get_player_name()).lang_code or "en"
		meta:set_string("formspec", formspec(get_formspec_string(lang_code)))
		meta:set_string("infotext", S("Offer Overview"))
	end,

	paramtype = 'light',
	light_source = 4,
	paramtype2 = "facedir",
	groups = {cracky=2},
	is_ground_content = false,
})

core.register_craft({
	output = "shop:overview",
	recipe = {
		{"default:paper", "default:paper", "default:paper"},
		{"default:mese_crystal_fragment", "default:book", "default:mese_crystal_fragment"},
		{"default:paper", "default:paper", "default:paper"},
	}
})

local function maintain_shop_list()
	GoodsTbl = {}
	ShopList = core.deserialize(storage:get_string("ShopList"))
	for _,pos in pairs(ShopList) do
		for _, offer in shop.get_offer(pos) do
			GoodsTbl[offer.key] = {
				goods = offer.goods,
				price = offer.price,
				spos = core.formspec_escape(core.pos_to_string(pos)),
				owner = core.formspec_escape(offer.owner),
				location = core.formspec_escape(offer.location:sub(1, MAX_STR_LEN))
			}
		end
	end
	core.after(CYCLE_TIME, maintain_shop_list)
end

core.register_on_mods_loaded(function()
	if storage:get_string("ShopList") == "" then
		storage:set_string("ShopList", core.serialize({}))
	end
	core.after(10, maintain_shop_list)
end)

core.register_chatcommand("update_offer", {
	privs = {server = true},
	params = "",
	description = S("Update the Offer Overview boards"),
	func = function(name, param)
		core.after(0.1, maintain_shop_list)
		core.chat_send_player(name, S("Offer Overview boards updated"))
	end,
})

function shop.register_shop(pos)
	local key = core.hash_node_position(pos)
	ShopList[key] = pos
	storage:set_string("ShopList", core.serialize(ShopList))
end

function shop.delete_shop(pos)
	local key = core.hash_node_position(pos)
	ShopList[key] = nil
	storage:set_string("ShopList", core.serialize(ShopList))
end

