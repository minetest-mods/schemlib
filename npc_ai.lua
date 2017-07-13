--local dprint = print
local dprint = function() return end

local mapping = schemlib.mapping

local npc_ai = {}

local npc_ai_class = {}
npc_ai_class.__index = npc_ai_class

--------------------------------------
--	Create NPC-AI object
--------------------------------------
function npc_ai.new(plan, build_distance)
	local self = setmetatable({}, npc_ai_class)
	self.__index = npc_ai_class
	self.plan = plan
	self.build_distance = build_distance or 3
	return self
end

--------------------------------------
--	Load a region to ve able to see things
--------------------------------------
function npc_ai_class:load_region(min_world_pos, max_world_pos)
	self.vm = minetest.get_voxel_manip()
	self.vm_minp, self.vm_maxp = self.vm:read_from_map(min_world_pos, max_world_pos)
	self.vm_area = VoxelArea:new({MinEdge = self.vm_minp, MaxEdge = self.vm_maxp})
	self.vm_data = self.vm:get_data()
	self.vm_param2_data = self.vm:get_param2_data()
end


--------------------------------------
--	Check if the node from plan already built in the world
--------------------------------------
function npc_ai_class:get_if_buildable(node)
	if not node then
		return
	end

	-- check if already built
	local mapped = node:get_mapped()
	if not mapped then
		-- not buildable
		node:remove_from_plan()
		return nil
	end

	-- get the original node from loaded area. Load a chunk if not given
	local world_pos = node:get_world_pos()
	local node_index

	if self.vm_area then
		node_index = self.vm_area:indexp(world_pos)
	end
	if not node_index then
		self:load_region(world_pos, world_pos)
		node_index = self.vm_area:indexp(world_pos)
	end

	if self.vm_data[node_index] == mapped.content_id then
		-- right node is at the place. there are no costs to touch them. Check if a touch needed
		if mapped.param2 ~= self.vm_param2_data[node_index] then
			--param2 adjustment
			return node
		elseif not mapped.meta then
			--same item without metadata. nothing to do
			node:remove_from_plan()
			return nil
		elseif mapping.is_equal_meta(minetest.get_meta(world_pos):to_table(), mapped.meta) then
			--metadata adjustment
			node:remove_from_plan()
			return nil
		else
			return node
		end
	else
		-- no right node at place
		return node
	end
end

--------------------------------------
--	Get rating for node which one should be built at next
--------------------------------------
function npc_ai_class:get_node_rating(node, npcpos)

	local world_pos = node:get_world_pos()
	local mapped = node:get_mapped()
	local distance_pos = table.copy(world_pos)
	local prefer = 0

	--prefer same items in building order
	if self.lasttarget_name then
		if self.lasttarget_name == mapped.name then
			prefer = prefer + 1
		end

		if world_pos.x == self.lasttarget_pos.x and
				world_pos.y == self.lasttarget_pos.y and
				world_pos.z == self.lasttarget_pos.z then
			prefer = prefer + self.build_distance
		end
	end

	-- prefer air in general, adjust prefered high for non-air,
	if mapped.name == "air" then
		prefer = prefer + self.build_distance + 1
	else
		if node:get_under() then
			prefer = prefer - (2 * self.build_distance)
		end
		distance_pos.y = distance_pos.y + self.build_distance
	end

	-- penalty for air under the walking line and for non air above
	local walking_high = npcpos.y-1 + math.abs(npcpos.x-world_pos.x) + math.abs(npcpos.z-world_pos.z)
	if ( mapped.name ~= "air" and world_pos.y > walking_high) or
			( mapped.name == "air" and world_pos.y < walking_high) then
		prefer = prefer - self.build_distance
	end

	-- avoid build directly under or in the npc
	if mapped.name ~= "air" and
			math.abs(npcpos.x - world_pos.x) < 0.5 and
			math.abs(npcpos.y - world_pos.y) <= self.build_distance and
			math.abs(npcpos.z - world_pos.z) < 0.5 then
		prefer = prefer - self.build_distance
	end

	-- compare
	return prefer - vector.distance(npcpos, distance_pos)
end

--------------------------------------
--	Select the best rated node from list
--------------------------------------
function npc_ai_class:prefer_target(npcpos, nodeslist)
	local selected_node
	local selected_node_rating
	for _, node in ipairs(nodeslist) do
		if self:get_if_buildable(node) then
			local current_rating = self:get_node_rating(node, npcpos)
			if not selected_node or current_rating > selected_node_rating then
				selected_node = node
				selected_node_rating = current_rating
			end
		end
	end
	return selected_node

end

--------------------------------------
--	Select the best rated node from list
--------------------------------------
function npc_ai_class:plan_target_get(npcpos)
	local npcpos_round = vector.round(npcpos)
	local npcpos_plan = self.plan:get_plan_pos(npcpos_round)
	local selectednode
	local first_distance = 5

	local prefer_list = {}

	-- first try: look for nearly buildable nodes
	dprint("search for nearly node")
	for x=npcpos_plan.x-first_distance, npcpos_plan.x+first_distance do
		for y=npcpos_plan.y-first_distance, npcpos_plan.y+first_distance do
			for z=npcpos_plan.z-first_distance, npcpos_plan.z+first_distance do
				local node = self.plan:get_node({x=x,y=y,z=z})
				if node then
					table.insert(prefer_list, node)
				end
			end
		end
	end
	self:load_region(vector.subtract(npcpos_round, first_distance), vector.add(npcpos_round, first_distance))
	selectednode = self:prefer_target(npcpos, prefer_list)
	if selectednode then
		dprint("nearly found: NPC: "..minetest.pos_to_string(npcpos).." Block "..minetest.pos_to_string(selectednode:get_world_pos()))
		self.lasttarget_name = selectednode:get_mapped().name
		self.lasttarget_pos = selectednode:get_world_pos()
		return selectednode
	else
		dprint("nearly nothing found")
	end

	-- second try. Check the current chunk
	dprint("search for node in current chunk")
	local chunk_nodes, min_world_pos, max_world_pos = self.plan:get_chunk_nodes(npcpos_plan)
	-- add last selection to the current chunk to compare
	if self.lasttarget_pos then
		table.insert(chunk_nodes, self.plan:get_node(self.lasttarget_pos))
	end
	dprint("Chunk loaeded: nodes:", #chunk_nodes)
	self:load_region(min_world_pos, max_world_pos)
	selectednode = self:prefer_target(npcpos, chunk_nodes)
	if selectednode then
		dprint("found in current chunk: NPC: "..minetest.pos_to_string(npcpos).." Block "..minetest.pos_to_string(selectednode:get_world_pos()))
		self.lasttarget_name = selectednode:get_mapped().name
		self.lasttarget_pos = selectednode:get_world_pos()
		return selectednode
	else
		dprint("current chunk nothing found")
	end

	dprint("get random node")
	local random_node = self.plan:get_node_random()
	if random_node then
		dprint("---check chunk", minetest.pos_to_string(random_node.plan_pos))
		selectednode = self:get_if_buildable(random_node)
		if selectednode then
			dprint("random node: Block "..minetest.pos_to_string(random_node.plan_pos))
		else
			dprint("random node not buildable, check the whole chunk", minetest.pos_to_string(random_node.plan_pos))
			local chunk_nodes, min_world_pos, max_world_pos = self.plan:get_chunk_nodes(random_node.plan_pos)
			dprint("Chunk loaeded: nodes:", #chunk_nodes)
			selectednode = self:prefer_target(npcpos, chunk_nodes)
			if selectednode then
				dprint("found in current chunk: Block "..minetest.pos_to_string(selectednode:get_world_pos()))
			end
		end
	else
		dprint("something wrong with random node")
	end
	if selectednode then
		self.lasttarget_name = selectednode:get_mapped().name
		self.lasttarget_pos = selectednode:get_world_pos()
		return selectednode
	else
		dprint("no next node found", self.plan.data.nodecount)
	end
end


function npc_ai_class:place_node(targetnode)
	dprint("target reached - build", targetnode.name, minetest.pos_to_string(targetnode:get_world_pos()))
	local mapped = targetnode:get_mapped()
	local soundspec
	if minetest.registered_items[mapped.name].sounds then
		soundspec = minetest.registered_items[mapped.name].sounds.place
	elseif mapped.name == "air" then --TODO: should be determinated on old node, if the material handling is implemented
		soundspec = default.node_sound_leaves_defaults({place = {name = "default_place_node", gain = 0.25}})
	end
	if soundspec then
		soundspec.pos = targetnode:get_world_pos()
		minetest.sound_play(soundspec.name, soundspec)
	end
	targetnode:place()
end

return npc_ai
