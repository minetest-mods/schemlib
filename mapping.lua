-- debug-print
--local dprint = print
local dprint = function() return end

local mapping = {}

-- visual for cost_item free for payment
mapping.c_free_item = "default:cloud"

-----------------------------------------------
-- door compatibility. Seems the old doors was facedir and now the wallmounted values should be used
-----------------------------------------------
local function __param2_wallmounted_to_facedir(nodeinfo, pos, wpos)
	if nodeinfo.param2 == 0 then     -- +y?
		nodeinfo.param2 = 0
	elseif nodeinfo.param2 == 1 then -- -y?
		nodeinfo.param2 = 1
	elseif nodeinfo.param2 == 2 then --unsure
		nodeinfo.param2 = 3
	elseif nodeinfo.param2 == 3 then --unsure
		nodeinfo.param2 = 1
	elseif nodeinfo.param2 == 4 then --unsure
		nodeinfo.param2 = 2
	elseif nodeinfo.param2 == 5 then --unsure
		nodeinfo.param2 = 0
	end
end


local function __torches_compat(nodeinfo, pos, wpos)

-- from default:3dtorch-lbm
	if nodeinfo.param2 == 0 then
		nodeinfo.name = "default:torch_ceiling"
	elseif nodeinfo.param2 == 1 then
		nodeinfo.name = "default:torch"
	else
		nodeinfo.name = "default:torch_wall"
	end
end

local u = {}
local unknown_nodes_data = u
-- Fallback nodes replacement of unknown nodes
-- Maybe it is beter to use aliases for unknown notes. But anyway
u["xpanes:pane_glass_10"] = { name = "xpanes:pane_10" }
u["xpanes:pane_glass_5"]  = { name = "xpanes:pane_5" }
u["beds:bed_top_blue"]    = { name = "beds:bed_top" }
u["beds:bed_bottom_blue"] = { name = "beds:bed_bottom" }

u["homedecor:table_lamp_max"] = { name = "homedecor:table_lamp_white_max" }
u["homedecor:refrigerator"]   = { name = "homedecor:refrigerator_steel" }

u["ethereal:green_dirt"] = { name = "default:dirt_with_grass" }

u["doors:door_wood_b_c"] = {name = "doors:door_wood_a", {["meta"] = {["fields"] = {["state"] = "1"}}}, custom_function = __param2_wallmounted_to_facedir } --closed
u["doors:door_wood_b_o"] = {name = "doors:door_wood_b", {["meta"] = {["fields"] = {["state"] = "3"}}}, custom_function = __param2_wallmounted_to_facedir } --open
u["doors:door_wood_b_1"] = {name = "doors:door_wood_a", {["meta"] = {["fields"] = {["state"] = "0"}}}} --Left door closed
u["doors:door_wood_b_2"] = {name = "doors:door_wood_b", {["meta"] = {["fields"] = {["state"] = "2"}}}} --right door closed
u["doors:door_wood_a_c"] = {name = "doors:hidden" }
u["doors:door_wood_a_o"] = {name = "doors:hidden" }
u["doors:door_wood_t_1"] = {name = "doors:hidden" }
u["doors:door_wood_t_2"] = {name = "doors:hidden" }

u["doors:door_glass_b_c"] = {name = "doors:door_glass_a", {["meta"] = {["fields"] = {["state"] = "1"}}}, custom_function = __param2_wallmounted_to_facedir } --closed
u["doors:door_glass_b_o"] = {name = "doors:door_glass_b", {["meta"] = {["fields"] = {["state"] = "3"}}}, custom_function = __param2_wallmounted_to_facedir } --open
u["doors:door_glass_b_1"] = {name = "doors:door_glass_a", {["meta"] = {["fields"] = {["state"] = "0"}}}} --Left door closed
u["doors:door_glass_b_2"] = {name = "doors:door_glass_b", {["meta"] = {["fields"] = {["state"] = "2"}}}} --right door closed
u["doors:door_glass_a_c"] = {name = "doors:hidden" }
u["doors:door_glass_a_o"] = {name = "doors:hidden" }
u["doors:door_glass_t_1"] = {name = "doors:hidden" }
u["doors:door_glass_t_2"] = {name = "doors:hidden" }

u["doors:door_steel_b_c"] = {name = "doors:door_steel_a", {["meta"] = {["fields"] = {["state"] = "1"}}}, custom_function = __param2_wallmounted_to_facedir } --closed
u["doors:door_steel_b_o"] = {name = "doors:door_steel_b", {["meta"] = {["fields"] = {["state"] = "3"}}}, custom_function = __param2_wallmounted_to_facedir } --open
u["doors:door_steel_b_1"] = {name = "doors:door_steel_a", {["meta"] = {["fields"] = {["state"] = "0"}}}} --Left door closed
u["doors:door_steel_b_2"] = {name = "doors:door_steel_b", {["meta"] = {["fields"] = {["state"] = "2"}}}} --right door closed
u["doors:door_steel_a_c"] = {name = "doors:hidden" }
u["doors:door_steel_a_o"] = {name = "doors:hidden" }
u["doors:door_steel_t_1"] = {name = "doors:hidden" }
u["doors:door_steel_t_2"] = {name = "doors:hidden" }

u["fallback"] = {name = "air" }

local c = {}
local default_replacements = c
-- "name" and "cost_item" are optional.
-- if name is missed it will not be changed
-- if cost_item is missed it will be determinated as usual (from changed name)
-- a crazy sample is: instead of cobble place goldblock, use wood as payment
-- c["default:cobble"] = { name = "default:goldblock", cost_item = "default:wood" }

c["beds:bed_top"] = { cost_item = mapping.c_free_item }  -- the bottom of the bed is payed, so buld the top for free

-- it is hard to get a source in survival, so we use buckets. Note, the bucket is lost after usage by NPC
c["default:lava_source"]        = { cost_item = "bucket:bucket_lava" }
c["default:river_water_source"] = { cost_item = "bucket:bucket_river_water" }
c["default:water_source"]       = { cost_item = "bucket:bucket_water" }

-- does not sense to set flowing water because it flow away without the source (and will be generated trough source)
c["default:water_flowing"]       = { name = "" }
c["default:lava_flowing"]        = { name = "" }
c["default:river_water_flowing"] = { name = "" }

-- pay different dirt types by the sane dirt
c["default:dirt_with_dry_grass"] = { cost_item = "default:dirt" }
c["default:dirt_with_grass"]     = { cost_item = "default:dirt" }
c["default:dirt_with_snow"]      = { cost_item = "default:dirt" }

-- Changed with MTG-0.4.16
c["xpanes:pane_5"]               = { name = "xpanes:pane_flat", param2 = 0 } --unsure
c["xpanes:pane_10"]              = { name = "xpanes:pane_flat", param2 = 1 } --unsure

c["default:torch"]               = { custom_function = __torches_compat }
c["torches:wall"]                = { name = "default:torch_wall" }

-----------------------------------------------
-- copy table of mapping entry
-----------------------------------------------
local function merge_map_entry(entry1, entry2)
	if entry2 then
		local ret_entry = table.copy(entry2)
		for k,v in pairs(entry1) do
			ret_entry[k] = v
		end
		return ret_entry
	else
		return table.copy(entry1)
	end
end

	-----------------------------------------------
	-- is_equal_meta - compare meta information of 2 nodes
	-- name - Node name to check and map
	-- return - item name used as payment
	-----------------------------------------------
function mapping.is_equal_meta(a,b)
	local typa = type(a)
	local typb = type(b)
	if typa ~= typb then
		return false
	end

	if typa == "table" then
		if #a ~= #b then
			return false
		else
			for i,v in ipairs(a) do
				if not mapping.is_equal_meta(a[i],b[i]) then
					return false
				end
			end
			return true
		end
	else
		if a == b then
			return true
		end
	end
end

-----------------------------------------------
-- Fallback nodes replacement of unknown nodes
-----------------------------------------------
function mapping.map_unknown(name)
	local map = unknown_nodes_data[name]
	if not map or map.name == name then -- no fallback mapping. don't use the node
		dprint("mapping failed:", name, dump(map))
		print("unknown nodes in building", name)
		return unknown_nodes_data["fallback"]
	end

	dprint("mapped", name, "to", map.name)
	return merge_map_entry(map)
end

-----------------------------------------------
-- Take filters and actions on nodes before building
-----------------------------------------------
function mapping.map(name)
-- get mapped registred node name for further mappings
	local node_chk = minetest.registered_nodes[name]

	--do fallback mapping if not registred node
	if not node_chk then
		local fallback = mapping.map_unknown(name)
		if fallback then
			dprint("map fallback:", dump(fallback))
			local fbmapped = mapping.map(fallback.name)
			if fbmapped then
				return merge_map_entry(fbmapped, fallback) --merge fallback values into the mapped node
			end
		end
		dprint("unmapped node", name)
		return
	end

	-- get default replacement
	local map = default_replacements[name]
	local mr -- mapped return table
	if not map then
		mr = {}
		mr.name = name
	else
		mr = merge_map_entry(map)
		if mr.name == nil then
			mr.name = name
		end
	end

	--disabled by mapping
	if mr.name == "" then
		return nil
	end

	local node_def = minetest.registered_nodes[mr.name]
	mr.node_def = node_def
	-- determine cost_item
	if not mr.cost_item then
		--Check for price or if it is free
		local recipe = minetest.get_craft_recipe(mr.name)
		if (node_def.groups.not_in_creative_inventory and --not in creative
				not (node_def.groups.not_in_creative_inventory == 0) and
				(not recipe or not recipe.items)) --and not craftable
				or (not node_def.description or node_def.description == "") then -- no description
			-- node cannot be used as payment. Check for drops
			local dropstack = minetest.get_node_drops(mr.name)
			if dropstack then
				mr.cost_item = dropstack[1] -- use the first one
			else --something not supported, but known
				mr.cost_item = mapping.c_free_item -- will be build for free. they are something like doors:hidden or second part of coffee lrfurn:coffeetable_back
			end
		else -- build for payment the 1:1
			mr.cost_item = mr.name
		end
	end

	if mr.cost_item == "" or mr.cost_item == nil then
		mr.cost_item = mapping.c_free_item
	end

	dprint("map", name, "to", mr.name, mr.param2, mr.cost_item)
	return mr
end


------------------------------------------
-- Cache some node content ID
mapping._protected_content_ids = {}
mapping._over_surface_content_ids = {}
mapping._non_removal_nodes = {}

minetest.after(0, function()

	for name, def in pairs(minetest.registered_nodes) do
		-- protected nodes
		if def.is_ground_content == false and not
				(def.groups.leaves or def.groups.leafdecay or def.groups.tree) then
			mapping._protected_content_ids[minetest.get_content_id(name)] = name
		end

		-- usual first node over surface
		if def.walkable == false or def.drawtype == "airlike" or
				def.groups.flora or def.groups.flower or
				def.groups.leaves or def.groups.leafdecay
				or def.groups.tree then
			mapping._over_surface_content_ids[minetest.get_content_id(name)] = name
		end

		-- this nodes needs not to be removed
		if def.groups.liquid then
			mapping._non_removal_nodes[minetest.get_content_id(name)] = name
		end
	end

	mapping._over_surface_content_ids[minetest.get_content_id("air")] = "air"
	mapping._over_surface_content_ids[minetest.get_content_id("default:snow")] = "default:snow"
	mapping._over_surface_content_ids[minetest.get_content_id("default:snowblock")] = "default:snowblock"

	mapping._non_removal_nodes[minetest.get_content_id("air")] = "air"
end)
------------------------------------------

return mapping
