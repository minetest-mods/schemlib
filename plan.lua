--[[ API

data types (and usual names):
- plan_pos  - a relative position vector used in plan. Note: the relative 0,0,0 in plan will be the placed to the defined world_pos position
- world_pos - a absolute ("real") position vector in the world

- plan_node - a abstract node description used in plan till build
- buildable_node - a enhanced plan node ready for build

- status
  "new"    - created
  "ready"  - ready for processing
  ??? - custom status possible

- plan_type - a type of plan to handle different types
  - house
  - lumber

public class-methods
- new(plan_id [,anchor_pos])    - Constructor - create a new plan object with unique plan_id (WIP)
- get(plan_id)    - get a existing plan object with unique plan_id
- get_all()       - get a plan list
- save_all()      - write plan definitions to files in world
- load_all()      - read all plan definitions from files in world

public object methods
- add_node(plan_pos, plan_node)  - add a node to plan   (OK)
- get_node(plan_pos)             - get a node from plan (OK)
- del_node(plan_pos)             - delete a node from plan (OK)
- get_node_next_to_pos(plan_pos) - get the nearest node to pos (low-prio)
- get_node_random()              - get a random existing plan_pos from plan (OK)
- get_chunk_nodes(plan_pos)      - get a list of all nodes from chunk of a pos (OK)

- read_from_schem_file(file)     - read from WorldEdit or mts file (OK)
- get_world_pos(plan_pos)        - get a world position for a plan position (OK)
- get_plan_pos(world_pos)        - get a plan position for a world position (OK)
- get_buildable_node(plan_pos)   - get a plan node ready to build (OK)
- load_plan()                    - load a plan state from file in world-directory (low-prio) (:scm_data_cache)
- save_plan()                    - store the current plan to a file in world directory and set them valid (low-prio) (:scm_data_cache)
- delete_plan()                  - remove the plan from plan_list
- change_plan_id(new_plan_id)    - change the plan id
- apply_flood_with_air
     (add_max, add_min, add_top) - Fill a building with air (OK)
- do_add_node(buildable_node)    - Place node to world using "add_node" and remove them from plan (OK)
- do_add_chunk(plan_pos)         - Place a node (OK)
- do_add_chunk_voxel(plan_pos)   - Place a node (OK)

Internals
private class attributes
 - plan_list - a simple list with all known plans

private object atributes
-- allways loaded in list
- plan_id    - a id of the plan (=filename)
- status     - plan status
- anchor_pos - position vector in world
- data.nodeinfos      - a list of node information for name_id with counter ({name_orig="abc:dcg",count=1})
- data.ground_y       - explicit ground adjustment for anchor_pos
- data.min_pos        - minimal {x,y,z} vector
- data.max_pos        - maximal {x,y,z} vector

-- save the cache data using save_cache()
- data.nodecount      - count of nodes in scm_data_cache
- data.scm_data_cache - all plan nodes

-- will be rebuild on demand
- data.prepared_cache - cache of prepared buildable nodes
]]

-- debug-print
local dprint = print
--local dprint = function() return end


local mapping = schemlib.mapping
local save_restore = schemlib.save_restore
local modpath = schemlib.modpath
local schematics = schemlib.schematics

local plan = {}
plan.plan_list = {}

function plan.get(plan_id)
	if plan.plan_list ~= nil then
		return plan.plan_list[plan_id]
	end
end

function plan.get_all()
--TODO: list files + merge with plan_list
-- Output table entries:
-- entry[plan_id] = { plan_id=, status=, anchor_pos=, ground_y=, min_pos=, max_pos=, node_count= }
	return plan.plan_list
end


plan.new = function( plan_id , anchor_pos)
	local self = {}
	self.plan_id = plan_id
	self.anchor_pos = anchor_pos
	self.data = {}
	self.status = "new"
--	self.plan_type = nil

	if self.plan_id ~= nil then
		plan.plan_list[self.plan_id] = self
	end

	function self.add_node(self, node)
		-- insert new
		if self.data.scm_data_cache[node.y] == nil then
			self.data.scm_data_cache[node.y] = {}
		end
		if self.data.scm_data_cache[node.y][node.x] == nil then
			self.data.scm_data_cache[node.y][node.x] = {}
		end
		if self.data.scm_data_cache[node.y][node.x][node.z] == nil then
			self.data.nodecount = self.data.nodecount + 1
		else
			local replaced_node = self.data.scm_data_cache[node.y][node.x][node.z]
			data.nodeinfos[replaced_node.name_id].count = self.data.nodeinfos[replaced_node.name_id].count-1
		end

		if not node.name_id then
			local chk_name_id
			for name_id, nodeinfo in pairs(self.data.nodeinfos) do
				if nodeinfo.orig_name == node.name then
					chk_name_id = name_id
					nodeinfo.count = nodeinfo.count + 1
					break
				end
			end
			if not chk_name_id then
				chk_name_id = #self.data.nodeinfos + 1
				self.data.nodeinfos[chk_name_id] = { name_orig = node.name, count = 1 }
			end
			node.name_id = chk_name_id
		else
			self.data.nodeinfos[node.name_id].count = self.data.nodeinfos[node.name_id].count + 1
		end
		node.name = nil --standardize, in case it was given for id determination
		self.data.scm_data_cache[node.y][node.x][node.z] = node
	end


	function self.get_node(self, plan_pos)
		local pos = plan_pos
		assert(pos.x, "pos without xyz")
		if self.data.scm_data_cache[pos.y] == nil then
			return nil
		end
		if self.data.scm_data_cache[pos.y][pos.x] == nil then
			return nil
		end
		if self.data.scm_data_cache[pos.y][pos.x][pos.z] == nil then
			return nil
		end
		return self.data.scm_data_cache[pos.y][pos.x][pos.z]
	end

	function self.del_node(self, pos)
		if self.data.scm_data_cache[pos.y] ~= nil then
			if self.data.scm_data_cache[pos.y][pos.x] ~= nil then
				if self.data.scm_data_cache[pos.y][pos.x][pos.z] ~= nil then
					local oldnode = self.data.scm_data_cache[pos.y][pos.x][pos.z]
					self.data.nodeinfos[oldnode.name_id].count = self.data.nodeinfos[oldnode.name_id].count - 1
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

		if self.data.prepared_cache and self.data.prepared_cache[pos.y] ~= nil then
			if self.data.prepared_cache[pos.y][pos.x]then
				if self.data.prepared_cache[pos.y][pos.x][pos.z] ~= nil then
					self.data.prepared_cache[pos.y][pos.x][pos.z] = nil
				end
				if next(self.data.prepared_cache[pos.y][pos.x]) == nil then
					self.data.prepared_cache[pos.y][pos.x] = nil
				end
			end
			if next(self.data.prepared_cache[pos.y]) == nil then
				self.data.prepared_cache[pos.y] = nil
			end
		end
	end

	function self.apply_flood_with_air(self, add_max, add_min, add_top)
		self.data.ground_y =  math.floor(self.data.ground_y)
		if add_max == nil then
			add_max = 3
		end
		if add_max == nil then
			add_max = 0
		end
		if add_top == nil then
			add_top = 5
		end

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
			for x = self.data.min_pos.x - add_min, self.data.max_pos.x + add_min do
				for z = self.data.min_pos.z - add_min, self.data.max_pos.z + add_min do
					local airnode = {x=x, y=y, z=z, name = "air", name_id=air_id}
					if self:get_node(airnode) == nil then
						self:add_node(airnode)
						air_id = airnode.name_id
					end
				end
			end
		end
		dprint("flatting plan done")
	end

	function self.get_world_pos(self,pos)
		return {	x=pos.x+self.anchor_pos.x,
						y=pos.y+self.anchor_pos.y - self.data.ground_y - 1,
						z=pos.z+self.anchor_pos.z
					}
	end

	function self.get_plan_pos(self,pos)
		return {	x=pos.x-self.anchor_pos.x,
						y=pos.y-self.anchor_pos.y + self.data.ground_y + 1,
						z=pos.z-self.anchor_pos.z
					}
	end


-- get nodes for selection which one should be build
-- skip parameter is randomized
	function self.get_node_random(self)
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

-- to be able working with forceload chunks
	function self.get_chunk_nodes(self, node)
	-- calculate the begin of the chunk
		--local BLOCKSIZE = core.MAP_BLOCKSIZE
		local BLOCKSIZE = 16
		local wpos = self:get_world_pos(node)
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
								local pos = {x=x,y=y,z=z}
								local wpos = self:get_world_pos(pos)
								table.insert(ret, self:get_buildable_node(pos, wpos))
							end
						end
					end
				end
			end
		end
		dprint("nodes in chunk to build", #ret)
		return ret
	end


	function self.read_from_schem_file(self, filename)
		local file = save_restore.file_access(filename, "r")
		if file == nil then
			dprint("error: could not open file \"" .. filename .. "\"")
			self.data = nil
		else
			-- different file types
			if string.find( filename, '.mts',  -4 ) then
				self.data = schematics.analyze_mts_file(file)
			end
			if string.find( filename, '.we',   -3 ) or string.find( filename, '.wem',  -4 ) then
				self.data = schematics.analyze_we_file(file)
			end
		end
	end


	-- prepare node for build
	function self.get_buildable_node(self, plan_pos, world_pos)
		-- first run, generate mapping data
		if self.data.mappedinfo == nil then
			mapping.do_mapping(self.data)
		end

		-- get from cache
		if self.data.prepared_cache ~= nil and
				self.data.prepared_cache[plan_pos.y] ~= nil and
				self.data.prepared_cache[plan_pos.y][plan_pos.x] ~= nil and
				self.data.prepared_cache[plan_pos.y][plan_pos.x][plan_pos.z] ~= nil then
			return self.data.prepared_cache[plan_pos.y][plan_pos.x][plan_pos.z]
		end

		-- get scm data
		local scm_node = self:get_node(plan_pos)
		if scm_node == nil then
			return nil
		end

		--get mapping data
		local map = self.data.mappedinfo[scm_node.name_id]
		if map == nil then
			return nil
		end

		local node = mapping.merge_map_entry(map, scm_node)

		if node.custom_function ~= nil then
			node.custom_function(node, plan_pos, world_pos)
		end

		-- maybe node name is changed in custom function. Update the content_id in this case
		node.content_id = minetest.get_content_id(node.name)
		node.node_def = minetest.registered_nodes[node.name]
		node.plan_pos = plan_pos
		node.world_pos = world_pos

		-- store the mapped node info in cache
		if self.data.prepared_cache == nil then
			self.data.prepared_cache = {}
		end
		if self.data.prepared_cache[plan_pos.y] == nil then
			self.data.prepared_cache[plan_pos.y] = {}
		end
		if self.data.prepared_cache[plan_pos.y][plan_pos.x] == nil then
			self.data.prepared_cache[plan_pos.y][plan_pos.x] = {}
		end
		self.data.prepared_cache[plan_pos.y][plan_pos.x][plan_pos.z] = node

		return node
	end


	function self.change_plan_id(self, new_plan_id)
		if self.plan_id then
			plan.plan_list[self.plan_id ] = nil
		end
		self.plan_id = new_plan_id
		if self.plan_id then
			plan.plan_list[self.plan_id ] = self
		end
	end

	function self.delete_plan(self)
		if self.plan_id then
			plan.plan_list[self.plan_id ] = nil
		end
	end

	function self.do_add_node(self, buildable_node)
		if buildable_node.node then
			minetest.env:add_node(buildable_node.world_pos, buildable_node.node)
			if buildable_node.node.meta then
				minetest.env:get_meta(buildable_node.world_pos):from_table(buildable_node.node.meta)
			end
		end
		self:del_node(buildable_node.plan_pos)
	end

	function self.do_add_chunk(self, plan_pos)
		local chunk_pos = self.plan:get_world_pos(plan_pos)
		dprint("---build chunk", minetest.pos_to_string(plan_pos))

		local chunk_nodes = self:get_chunk_nodes(self:get_plan_pos(chunk_pos))
		dprint("Instant build of chunk: nodes:", #chunk_nodes)
		for idx, nodeplan in ipairs(chunk_nodes) do
			--TODO: call "add_node"
			self:do_add_node(nodeplan)
		end
	end


	function self.do_add_chunk_voxel(self, plan_pos)
		local chunk_pos = self.plan:get_world_pos(plan_pos)
		dprint("---build chunk uning voxel", minetest.pos_to_string(plan_pos))

		-- work on VoxelArea
		local vm = minetest.get_voxel_manip()
		local minp, maxp = vm:read_from_map(chunk_pos, chunk_pos)
		local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
		local data = vm:get_data()
		local param2_data = vm:get_param2_data()
		local light_fix = {}
		local meta_fix = {}
--		for idx in a:iterp(vector.add(minp, 8), vector.subtract(maxp, 8)) do -- do not touch for beter light update
		for idx, origdata in pairs(data) do -- do not touch for beter light update
			local wpos = a:position(idx)
			local pos = self:get_plan_pos(wpos)
			local node = self:get_buildable_node(pos, wpos)
			if node and node.content_id then
				-- write to voxel
				data[idx] = node.content_id
				param2_data[idx] = node.param2

				-- mark for light update
				assert(node.node_def, dump(node))
				if node.node_def.light_source and node.node_def.light_source > 0 then
					table.insert(light_fix, node)
				end
				if node.meta then
					table.insert(meta_fix, node)
				end
				self.plan:remove_node(node)
			end
			self.plan:remove_node(pos) --if exists
		end

		-- store the changed map data
		vm:set_data(data)
		vm:set_param2_data(param2_data)
		vm:calc_lighting()
		vm:update_liquids()
		vm:write_to_map()
		vm:update_map()

		-- fix the lights
		dprint("fix lights", #light_fix)
		for _, fix in ipairs(light_fix) do
			minetest.env:add_node(fix.world_pos, fix)
		end

		dprint("process meta", #meta_fix)
		for _, fix in ipairs(meta_fix) do
			minetest.env:get_meta(fix.world_pos):from_table(fix.meta)
		end
	end


	--------------------------------------

--------------------
--	TODO: save the reference to a global accessable table
--------------------
	return self -- the plan object
end

return plan
