-- debug-print
--local dprint = print
local dprint = function() return end

local save_restore = schemlib.save_restore
local modpath = schemlib.modpath
local node = schemlib.node

--------------------------------------
--	Plan class
--------------------------------------
local plan_class = {}
plan_class.__index = plan_class

--------------------------------------
--	Plan class-methods and attributes
--------------------------------------
local plan = {}

--------------------------------------
--	Create new plan object
--------------------------------------
function plan.new(plan_id , anchor_pos)
	local self = setmetatable({}, plan_class)
	self.__index = plan_class
	self.plan_id = plan_id
	self.anchor_pos = anchor_pos
	self.data = {}
	self.data.min_pos = {}
	self.data.max_pos = {}
	self.data.groundnode_count = 0
	self.data.ground_y = -1 --if nothing defined, it is under the building
	self.data.scm_data_cache = {}
	self.data.nodeinfos = {}
	self.data.nodecount = 0
	self.status = "new"
	return self -- the plan object
end

--------------------------------------
--Add node to plan
--------------------------------------
function plan_class:add_node(plan_pos, node)
	-- build 3d cache tree
	if self.data.scm_data_cache[plan_pos.y] == nil then
		self.data.scm_data_cache[plan_pos.y] = {}
	end
	if self.data.scm_data_cache[plan_pos.y][plan_pos.x] == nil then
		self.data.scm_data_cache[plan_pos.y][plan_pos.x] = {}
	end
	if self.data.scm_data_cache[plan_pos.y][plan_pos.x][plan_pos.z] == nil then
		self.data.nodecount = self.data.nodecount + 1
	else
		local replaced_node = self.data.scm_data_cache[plan_pos.y][plan_pos.x][plan_pos.z]
		self.data.nodeinfos[replaced_node.name].count = self.data.nodeinfos[replaced_node.name].count-1
	end

	-- insert to nodeinfos
	local nodeinfo = self.data.nodeinfos[node.name]
	if not nodeinfo then
		nodeinfo = {name_orig = node.name, count = 1}
		self.data.nodeinfos[node.name] = nodeinfo

		-- Merge allways air
		if node.name == 'air' then
			node.plan = self
			node.nodeinfo = nodeinfo
			nodeinfo.deduplicated_node = node
		end
		-- Other nodes could be merged if no param2 support and no metadata exists
		if not node.meta then
			if minetest.registered_nodes[node.name] and not minetest.registered_nodes[node.name].paramtype2 then
				node.plan = self
				node.nodeinfo = nodeinfo
				nodeinfo.deduplicated_node = node
			end
		end
	else
		nodeinfo.count = nodeinfo.count + 1
	end

	if nodeinfo.deduplicated_node and not node.meta then
		self.data.scm_data_cache[plan_pos.y][plan_pos.x][plan_pos.z] = nodeinfo.deduplicated_node 
	else
		node.plan = self
		node.nodeinfo = nodeinfo
		self.data.scm_data_cache[plan_pos.y][plan_pos.x][plan_pos.z] = node
	end


end

--------------------------------------
--Adjust building size and ground info
--------------------------------------
function plan_class:adjust_building_info(plan_pos, node)
	-- adjust min/max position information
	if not self.data.max_pos.y or plan_pos.y > self.data.max_pos.y then
		self.data.max_pos.y = plan_pos.y
	end
	if not self.data.min_pos.y or plan_pos.y < self.data.min_pos.y then
		self.data.min_pos.y = plan_pos.y
	end
	if not self.data.max_pos.x or plan_pos.x > self.data.max_pos.x then
		self.data.max_pos.x = plan_pos.x
	end
	if not self.data.min_pos.x or plan_pos.x < self.data.min_pos.x then
		self.data.min_pos.x = plan_pos.x
	end
	if not self.data.max_pos.z or plan_pos.z > self.data.max_pos.z then
		self.data.max_pos.z = plan_pos.z
	end
	if not self.data.min_pos.z or plan_pos.z < self.data.min_pos.z then
		self.data.min_pos.z = plan_pos.z
	end

	if string.sub(node.name, 1, 18) == "default:dirt_with_" or
			node.name == "farming:soil_wet" then
		self.data.groundnode_count = self.data.groundnode_count + 1
		if self.data.groundnode_count == 1 then
			self.data.ground_y = plan_pos.y
		else
			self.data.ground_y = self.data.ground_y + (plan_pos.y - self.data.ground_y) / self.data.groundnode_count
		end
	end
end

--------------------------------------
-- Get node from plan
--------------------------------------
function plan_class:get_node(plan_pos)
	local pos = plan_pos
	if self.data.scm_data_cache[pos.y] == nil then
		return nil
	end
	if self.data.scm_data_cache[pos.y][pos.x] == nil then
		return nil
	end
	if self.data.scm_data_cache[pos.y][pos.x][pos.z] == nil then
		return nil
	end
	local cached_node = self.data.scm_data_cache[pos.y][pos.x][pos.z]
	local  dedup_node
	-- break deduplication for node deduplication
	if cached_node.nodeinfo.deduplicated_node then
		dedup_node = {}
		for k, v in pairs(cached_node) do
			dedup_node[k] = v
		end
		dedup_node = setmetatable(dedup_node, node.node_class)
	else
		dedup_node = cached_node
	end
	if not dedup_node._plan_pos then
		dedup_node._plan_pos = pos
	end
	return dedup_node
end

--------------------------------------
--Delete node from plan
--------------------------------------
function plan_class:del_node(pos)
	if self.data.scm_data_cache[pos.y] ~= nil then
		if self.data.scm_data_cache[pos.y][pos.x] ~= nil then
			if self.data.scm_data_cache[pos.y][pos.x][pos.z] ~= nil then
				local oldnode = self.data.scm_data_cache[pos.y][pos.x][pos.z]
				self.data.nodeinfos[oldnode.name].count = self.data.nodeinfos[oldnode.name].count - 1
				self.data.nodecount = self.data.nodecount - 1
				self.data.scm_data_cache[pos.y][pos.x][pos.z] = nil
			end
			if next(self.data.scm_data_cache[pos.y][pos.x]) == nil then
				self.data.scm_data_cache[pos.y][pos.x] = nil
			end
		end
		if next(self.data.scm_data_cache[pos.y]) == nil then
			self.data.scm_data_cache[pos.y] = nil
		end
	end
end

--------------------------------------
--Flood ta buildingplan with air
--------------------------------------
function plan_class:apply_flood_with_air(add_max, add_min, add_top)
	self.data.ground_y =  math.floor(self.data.ground_y)
	add_max = add_max or 3
	add_min = add_min or 0
	add_top = add_top or 5

	-- cache air_id
	local air_id

	dprint("create flatting plan")
	for y = self.data.min_pos.y, self.data.max_pos.y + add_top do
		--calculate additional grounding
		if y > self.data.ground_y then --only over ground
			local high = y-self.data.ground_y
			add_min = high + 1
			if add_min > add_max then --set to max
				add_min = add_max
			end
		end

		dprint("flat level:", y)
		local air_node = {name = "air"}
		for x = self.data.min_pos.x - add_min, self.data.max_pos.x + add_min do
			for z = self.data.min_pos.z - add_min, self.data.max_pos.z + add_min do
				local pos = {x=x, y=y, z=z}
				if not self:get_node(pos) then
					self:add_node(pos, node.new(air_node))
				end
			end
		end
	end
	dprint("flatting plan done")
end

--------------------------------------
--Get world position relative to plan position
--------------------------------------
function plan_class:get_world_pos(pos, anchor_pos)
	local apos = anchor_pos or self.anchor_pos
	return {	x=pos.x+apos.x,
					y=pos.y+apos.y - self.data.ground_y - 1,
					z=pos.z+apos.z
				}
end

--------------------------------------
--Get plan position relative to world position
--------------------------------------
function plan_class:get_plan_pos(pos, anchor_pos)
	local apos = anchor_pos or self.anchor_pos
	return {	x=pos.x-apos.x,
					y=pos.y-apos.y + self.data.ground_y + 1,
					z=pos.z-apos.z
				}
end

	--------------------------------------
	--Get a random position of an existing node in plan
	--------------------------------------
-- get nodes for selection which one should be build
-- skip parameter is randomized
function plan_class:get_random_plan_pos()
	dprint("get something from list")

	-- get random existing y
	local keyset = {}
	for k in pairs(self.data.scm_data_cache) do table.insert(keyset, k) end
	if #keyset == 0 then --finished
		return nil
	end
	local y = keyset[math.random(#keyset)]

	-- get random existing x
	keyset = {}
	for k in pairs(self.data.scm_data_cache[y]) do table.insert(keyset, k) end
	local x = keyset[math.random(#keyset)]

	-- get random existing z
	keyset = {}
	for k in pairs(self.data.scm_data_cache[y][x]) do table.insert(keyset, k) end
	local z = keyset[math.random(#keyset)]

	if z ~= nil then
		return {x=x,y=y,z=z}
	end
end

--------------------------------------
--Get a nodes list for a world chunk
--------------------------------------
function plan_class:get_chunk_nodes(plan_pos)
-- calculate the begin of the chunk
	--local BLOCKSIZE = core.MAP_BLOCKSIZE
	local BLOCKSIZE = 16
	local wpos = self:get_world_pos(plan_pos)
	local minp = {}
	minp.x = (math.floor(wpos.x/BLOCKSIZE))*BLOCKSIZE
	minp.y = (math.floor(wpos.y/BLOCKSIZE))*BLOCKSIZE
	minp.z = (math.floor(wpos.z/BLOCKSIZE))*BLOCKSIZE
	local maxp = vector.add(minp, 16)

	dprint("nodes for chunk (real-pos)", minetest.pos_to_string(minp), minetest.pos_to_string(maxp))

	local minv = self:get_plan_pos(minp)
	local maxv = self:get_plan_pos(maxp)
	dprint("nodes for chunk (plan-pos)", minetest.pos_to_string(minv), minetest.pos_to_string(maxv))

	local ret = {}
	for y = minv.y, maxv.y do
		if self.data.scm_data_cache[y] ~= nil then
			for x = minv.x, maxv.x do
				if self.data.scm_data_cache[y][x] ~= nil then
					for z = minv.z, maxv.z do
						if self.data.scm_data_cache[y][x][z] ~= nil then
							table.insert(ret, self:get_node({x=x, y=y,z=z}))
						end
					end
				end
			end
		end
	end
	dprint("nodes in chunk to build", #ret)
	return ret, minp, maxp -- minp/maxp are worldpos
end

--------------------------------------
-- Generate a plan from schematics file
--------------------------------------
function plan_class:read_from_schem_file(filename)
	-- Minetest Schematics
	if string.find(filename, '.mts',  -4) then
		local str = minetest.serialize_schematic(filename, "lua", {})
		if not str then
			dprint("error: could not open file \"" .. filename .. "\"")
			return
		end
		local schematic = loadstring(str.." return(schematic)")()
			--[[	schematic.yslice_prob = {{ypos = 0,prob = 254},..}
					schematic.size = { y = 18,x = 10, z = 18},
					schematic.data = {{param2 = 2,name = "default:tree",prob = 254},..}
				]]

		-- analyze the file
		for i, ent in ipairs( schematic.data ) do
			if ent.name ~= "air" then
				local pos = {
						z = math.floor((i-1)/schematic.size.y/schematic.size.x),
						y = math.floor((i-1)/schematic.size.x) % schematic.size.y,
						x = (i-1) % schematic.size.x
					}
				local new_node = node.new(ent)
				self:add_node(pos, new_node)
				self:adjust_building_info(pos, new_node)
			end
		end
	-- WorldEdit files
	elseif string.find(filename, '.we',   -3) or string.find(filename, '.wem',  -4) then
		local file = io.open( filename, 'r' )
		if not file then
			dprint("error: could not open file \"" .. filename .. "\"")
			return
		end
		local nodes = schemlib.worldedit_file.load_schematic(file:read("*a"))
		-- analyze the file
		for i, ent in ipairs( nodes ) do
			local pos = {x=ent.x, y=ent.y, z=ent.z}
			local new_node = node.new(ent)
			self:add_node(pos, new_node)
			self:adjust_building_info(pos, new_node)
		end
	end
end

--------------------------------------
--Propose anchor position for the plan
--------------------------------------
function plan_class:propose_anchor(world_pos, do_check, add_y, add_xz)
	add_xz = add_xz or 4
	add_y = add_y or 8
	local minp = self:get_world_pos(self.data.min_pos, world_pos)
	local maxp = self:get_world_pos(self.data.max_pos, world_pos)

	-- to get some randomization for error-node
	local minx, maxx, stx, miny, maxy, minz, maxz, stz
	if math.random(2) == 1 then
		minx = minp.x-add_xz
		maxx = maxp.x+add_xz
	else
		maxx = minp.x-add_xz
		minx = maxp.x+add_xz
	end
	if math.random(2) == 1 then
		minz = minp.z-add_xz
		maxz = maxp.z+add_xz
	else
		maxz = minp.z-add_xz
		minz = maxp.z+add_xz
	end
	-- handle rotation
	if minx < maxx then
		stx = 1
	else
		stx = -1
	end
	if minz < maxz then
		stz = 1
	else
		stz = -1
	end
	miny = minp.y-add_y
	maxy = maxp.y+add_y
	-- only "y" needs to be proposed as usable ground
	local ground_y
	local groundnode_count = 0
	self:load_region({x=minx, y=miny, z=minz}) --first region

	for x = minx, maxx, stx do
		for z = minz, maxz, stz do
			local is_ground = true
			for y = miny, maxy, 1 do
				local pos = {x=x, y=y, z=z}
				if not self.vm_area:contains(x, y, z) then
					self:load_region(pos, pos)
				end
				local node_index = self.vm_area:indexp(pos)
				local content_id = self.vm_data[node_index]
				--print(x,y,z,minetest.get_name_from_content_id(content_id))
				if do_check and plan._protected_content_ids[content_id] then
					dprint("build denied because of not overridable", minetest.get_name_from_content_id(content_id), "at", x,y,z)
					return false, pos
				end

				if plan._over_surface_content_ids[content_id] then
					if y == miny then
						dprint("build denied because hanging in",minetest.get_name_from_content_id(content_id), "at", x,y,z)
						return false, pos
					end
					if is_ground == true then --only if ground above
						groundnode_count = groundnode_count + 1
						if groundnode_count == 1 then
							ground_y = pos.y
						else
							ground_y = ground_y + (pos.y - ground_y) / groundnode_count
						end
						if not do_check == true then
							break -- leave y loop, not necessary to check above
						end
					end
					is_ground = false
				end
			end
			if is_ground ~= false then --nil is air only (no ground), true is ground only (no air)
				-- air only or non-air only. Not buildable
				dprint("build denied because ground only at", x,y,z)
				return false, {x=x, y=world_pos.y, z=z}
			end
		end
	end

	if ground_y then
		dprint("proposed anchor high", ground_y)
		return {x=world_pos.x, y=math.floor(ground_y+0.5), z=world_pos.z}
	end
end

--------------------------------------
--add/build a chunk
--------------------------------------
function plan_class:do_add_chunk(plan_pos)
	dprint("---build chunk", minetest.pos_to_string(plan_pos))
	local chunk_nodes = self:get_chunk_nodes(plan_pos)
	dprint("Instant build of chunk: nodes:", #chunk_nodes)
	for idx, node in ipairs(chunk_nodes) do
		node:place()
	end
end

--------------------------------------
--	Load a region to the voxel
--------------------------------------
function plan_class:load_region(min_world_pos, max_world_pos)
	if not max_world_pos then
		max_world_pos = min_world_pos
	end
	self._vm = minetest.get_voxel_manip()
	self._vm_minp, self._vm_maxp = self._vm:read_from_map(min_world_pos, max_world_pos)
	self.vm_area = VoxelArea:new({MinEdge = self._vm_minp, MaxEdge = self._vm_maxp})
	self.vm_data = self._vm:get_data()
	self.vm_param2_data = self._vm:get_param2_data()
end

--------------------------------------
---add/build a chunk using VoxelArea
--------------------------------------
function plan_class:do_add_chunk_voxel(plan_pos)
	local chunk_pos = self:get_world_pos(plan_pos)
	dprint("---build chunk using voxel", minetest.pos_to_string(plan_pos))

	self:load_region(chunk_pos, chunk_pos)

	local meta_fix = {}
	local on_construct_fix = {}

	for idx, origdata in pairs(self.vm_data) do
		local wpos = self.vm_area:position(idx)
		local pos = self:get_plan_pos(wpos)
		local node = self:get_node(pos)
		if node then
			local mapped = node:get_mapped()
			if mapped and mapped.content_id then
				-- write to voxel
				self.vm_data[idx] = mapped.content_id
				self.vm_param2_data[idx] = mapped.param2

				-- Call the constructor
				if mapped.node_def.on_construct then
					on_construct_fix[wpos] = mapped.node_def.on_construct
				end

				-- Set again by node for meta
				if mapped.meta then
					meta_fix[wpos] = mapped
				end
			end
			self:del_node(pos)
		end
	end

	-- store the changed map data
	self._vm:set_data(self.vm_data)
	self._vm:set_param2_data(self.vm_param2_data)
	self._vm:calc_lighting()
	self._vm:update_liquids()
	self._vm:write_to_map()

	-- fix the nodes
	if  #meta_fix then
		minetest.after(0, function(meta_fix, on_construct_fix)

			dprint("on construct calls", #on_construct_fix)
			for world_pos, func in pairs(on_construct_fix) do
				func(world_pos)
			end

			dprint("fix nodes", #meta_fix)
			for world_pos, mapped in pairs(meta_fix) do
				minetest.get_meta(world_pos):from_table(mapped.meta)
			end
		end, meta_fix, on_construct_fix)
	end
end

function plan_class:get_status()
	if self.status == "build" then
		if self.data.nodecount == 0 then
			dprint("finished by nodecount 0 in get_status")
			self.status = "finished"
		end
	end
	if self.on_status then -- trigger updates trough this hook
		self:on_status(self.status)
	end
	return self.status
end

function plan_class:set_status(status)
	self.status = status
	if self.on_status then -- trigger updates trough this hook
		self:on_status(self.status)
	end
end
------------------------------------------
-- Cache some node content ID
plan._protected_content_ids = {}
plan._over_surface_content_ids = {}
minetest.after(0, function()

	for name, def in pairs(minetest.registered_nodes) do
		-- protected nodes
		if def.is_ground_content == false and not
				(def.groups.leaves or def.groups.leafdecay or def.groups.tree) then
			plan._protected_content_ids[minetest.get_content_id(name)] = name
		end

		-- usual first node over surface
		if def.walkable == false or def.drawtype == "airlike" or
				def.groups.flora or def.groups.flower or
				def.groups.leaves or def.groups.leafdecay
				or def.groups.tree then
			plan._over_surface_content_ids[minetest.get_content_id(name)] = name
		end
	end

	plan._over_surface_content_ids[minetest.get_content_id("air")] = "air"
	plan._over_surface_content_ids[minetest.get_content_id("default:snow")] = "default:snow"
	plan._over_surface_content_ids[minetest.get_content_id("default:snowblock")] = "default:snowblock"
end)
------------------------------------------
return plan
