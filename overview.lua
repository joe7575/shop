-- Offer overview
-- | Goods | Price | Position | Player | Location |

local S = minetest.get_translator("shop")
local storage = minetest.get_mod_storage()
local overview = {}
local GoodsTbl = {} -- structured list with: [key] = {name, price, spos, owner, location}
local FormspecTbl = {} -- comma separated list
local MAX_STR_LEN = 22 -- max length of strings in formspec

local function get_name(lang_code, item_name)
	if item_name == nil or item_name == "" then
		return ""
	end
	local name, count = item_name:match("([^ ]+) ([0-9]+)")
	local ndef = minetest.registered_nodes[name] or minetest.registered_items[name]
	if count and ndef and ndef.description then
		local s = core.get_translated_string(lang_code, ndef.description) or "Oops"
		return minetest.formspec_escape(s:sub(1, MAX_STR_LEN)) .. " (" .. count .. ")"
	else
		return minetest.formspec_escape(item_name) 
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
	local items = {}
	for key,item in pairs(GoodsTbl) do
		items[key] = {
			name = get_name(lang_code, item.name or "oops"),
			price = get_name(lang_code, item.price or "oops"),
			spos = item.spos or "oops",
			owner = item.owner or "oops",
			location = item.location or "oops"
		}
	end
	-- sort by goods
	table.sort(keys, function(a,b) return items[a]["name"] < items[b]["name"] end)
	-- Formspec string
	local tbl = {S("Goods"), S("Price"), S("Position"), S("Owner"), S("Location")}
	for _, key in ipairs(keys) do
		local item = items[key]
		table.insert(tbl, item.name)
		table.insert(tbl, item.price)
		table.insert(tbl, item.spos)
		table.insert(tbl, item.owner)
		table.insert(tbl, item.location)
	end
	return table.concat(tbl, ",")
end

core.register_on_mods_loaded(function()
	if storage:get_string("overview") == "" then
		storage:set_string("overview", core.serialize({}))
	end
	GoodsTbl = core.deserialize(storage:get_string("overview"))
	for key,item in pairs(GoodsTbl) do
		if item.name == nil or item.name == "" or item.name == " 0" then
			GoodsTbl[key] = nil
		elseif item.price == nil or item.price == "" or item.price == " 0" then
			GoodsTbl[key] = nil
		end
	end
end)

function overview.register_goods(key, name, price, pos, owner, location)
	if name == nil or name == "" or name == " 0" then
		return
	end
	if price == nil or price == "" or price == " 0" then
		return
	end
	if GoodsTbl[key] == nil then
		GoodsTbl[key] = {
			name = name,
			price = price,
			spos = minetest.formspec_escape(core.pos_to_string(pos)),
			owner = minetest.formspec_escape(owner),
			location = minetest.formspec_escape(location:sub(1, MAX_STR_LEN))
		}
	else
		GoodsTbl[key].name = name
		GoodsTbl[key].price = price
		GoodsTbl[key].spos = minetest.formspec_escape(core.pos_to_string(pos))
		GoodsTbl[key].owner = minetest.formspec_escape(owner)
		GoodsTbl[key].location = minetest.formspec_escape(location:sub(1, MAX_STR_LEN))
	end
	storage:set_string("overview", core.serialize(GoodsTbl))
end

function overview.remove_goods(key)
	if GoodsTbl[key] ~= nil then
		GoodsTbl[key] = nil
		storage:set_string("overview", core.serialize(GoodsTbl))
	end
end

minetest.register_node("shop:overview", {
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
		local meta = minetest.get_meta(pos)
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

minetest.register_craft({
	output = "shop:overview",
	recipe = {
		{"default:paper", "default:paper", "default:paper"},
		{"default:mese_crystal_fragment", "default:book", "default:mese_crystal_fragment"},
		{"default:paper", "default:paper", "default:paper"},
	}
})

return overview