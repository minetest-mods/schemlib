local dprint = print
--local dprint = function() return end

local npc_ai = {}

local BUILD_DISTANCE = 3
local mapping = schemlib.mapping

npc_ai.get_if_buildable = function(plan, realpos, node_prep)
	local pos = plan:get_plan_pos(realpos)
	local node
	if node_prep then
		node = node_prep
	else
		node = plan:get_buildable_node(pos, realpos)
	end

	if not node then
		plan:del_node(pos)
		return nil
	end

	-- get info about placed node to compare
	local orig_node = minetest.get_node(realpos)
	if orig_node.name == "ignore" then
		minetest.get_voxel_manip():read_from_map(realpos, realpos)
		orig_node = minetest.get_node(realpos)
	end

	if not orig_node or orig_node.name == "ignore" then --not loaded chunk. can be forced by forceload_block before check if buildable
		dprint("ignore node at", minetest.pos_to_string(realpos))
		return nil
	end

	-- check if already built
	if orig_node.name == node.name or orig_node.name == minetest.registered_nodes[node.name].name then 
		-- right node is at the place. there are no costs to touch them. Check if a touch needed
		if (node.param2 ~= orig_node.param2 and not (node.param2 == nil and orig_node.param2  == 0)) then
			--param2 adjustment
--			node.matname = mapping.c_free_item -- adjust params for free
			return node
		elseif not node.meta then
			--same item without metadata. nothing to do
			plan:del_node(pos)
			return nil
		elseif mapping.is_equal_meta(minetest.get_meta(realpos):to_table(), node.meta) then
			--metadata adjustment
			plan:del_node(pos)
			return nil
		elseif node.matname == mapping.c_free_item then
			-- TODO: check if nearly nodes are already built
			return node
		else
			return node
		end
	else
		-- no right node at place
		return node
	end
end


function npc_ai.prefer_target(npcpos, t1, t2, savedata)
	if not t1 then
		return t2
	end

	-- variables for preference manipulation
	local t1_c = table.copy(t1.world_pos)
	local t2_c = table.copy(t2.world_pos)
	local prefer = 0
	local lasttarget = savedata.last_selection

	--prefer same items in building order
	if lasttarget then
		if lasttarget.name == t1.name then
			prefer = prefer + 1
		end
		if lasttarget.name == t2.name then
			prefer = prefer - 1
		end

		if t1.world_pos.x == lasttarget.world_pos.x and
				t1.world_pos.y == lasttarget.world_pos.y and
				t1.world_pos.z == lasttarget.world_pos.z then
			prefer = prefer + BUILD_DISTANCE
		end
		if t2.world_pos.x == lasttarget.world_pos.x and
				t2.world_pos.y == lasttarget.world_pos.y and
				t2.world_pos.z == lasttarget.world_pos.z then
			prefer = prefer - BUILD_DISTANCE
		end
	end

	-- prefer air in general, adjust prefered high for non-air
	if t1.name == "air" then
		prefer = prefer + 3
	else
		t1_c.y = t1_c.y + 3
	end
	if t2.name == "air" then
		prefer = prefer - 3
	else
		t2_c.y = t2_c.y + 3
	end

	-- penalty for air under the walking line and for non air above
	local walking_high_t1 = npcpos.y-1 + math.abs(npcpos.x-t1.world_pos.x) + math.abs(npcpos.z-t1.world_pos.z)
	local walking_high_t2 = npcpos.y-1 + math.abs(npcpos.x-t2.world_pos.x) + math.abs(npcpos.z-t2.world_pos.z)
	if ( t1.name ~= "air" and t1.world_pos.y > walking_high_t1) or
			( t1.name == "air" and t1.world_pos.y < walking_high_t1) then
		prefer = prefer - BUILD_DISTANCE
	end
	if ( t2.name ~= "air" and t2.world_pos.y > walking_high_t2) or
			( t2.name == "air" and t2.world_pos.y < walking_high_t2) then
		prefer = prefer + BUILD_DISTANCE
	end

	-- avoid build directly under or in the npc
	if t1.name ~= "air" and
			math.abs(npcpos.x - t1.world_pos.x) < 0.5 and
			math.abs(npcpos.y - t1.world_pos.y) <= BUILD_DISTANCE and
			math.abs(npcpos.z - t1.world_pos.z) < 0.5 then
		prefer = prefer-BUILD_DISTANCE
	end
	if t2.name ~= "air" and
			math.abs(npcpos.x - t2.world_pos.x) < 0.5 and
			math.abs(npcpos.y - t2.world_pos.y) <= BUILD_DISTANCE and
			math.abs(npcpos.z - t2.world_pos.z) < 0.5 then
		prefer = prefer+BUILD_DISTANCE
	end

	-- compare
	if vector.distance(npcpos, t1_c) - prefer > vector.distance(npcpos, t2_c) then
		return t2
	else
		return t1
	end

end


function npc_ai.plan_target_get(z)
	local plan = z.plan
	local npcpos = table.copy(z.npcpos)
	local savedata = z.savedata

	local npcpos_round = vector.round(npcpos)
	local selectednode

	-- first try: look for nearly buildable nodes
	dprint("search for nearly node")
	for x=npcpos_round.x-5, npcpos_round.x+5 do
		for y=npcpos_round.y-5, npcpos_round.y+5 do
			for z=npcpos_round.z-5, npcpos_round.z+5 do
				local node = npc_ai.get_if_buildable(plan,{x=x,y=y,z=z})
				if node then
					selectednode = npc_ai.prefer_target(npcpos, selectednode, node, savedata)
				end
			end
		end
	end
	if selectednode then
		dprint("nearly found: NPC: "..minetest.pos_to_string(npcpos).." Block "..minetest.pos_to_string(selectednode.world_pos))
	end

	if not selectednode then
		dprint("nearly nothing found")
		-- get the old target to compare
		if savedata.last_selection and savedata.last_selection.world_pos and
				(savedata.last_selection.name_id or savedata.last_selection.name) then
			selectednode = npc_ai.get_if_buildable(plan, savedata.last_selection.world_pos, savedata.last_selection)
		end
	end

	-- second try. Check the current chunk
	dprint("search for node in current chunk")

	local chunk_nodes = plan:get_chunk_nodes(plan:get_plan_pos(npcpos_round))
	dprint("Chunk loaeded: nodes:", #chunk_nodes)

	for idx, nodeplan in ipairs(chunk_nodes) do
		local node = npc_ai.get_if_buildable(plan, nodeplan.world_pos, nodeplan)
		if node then
			selectednode = npc_ai.prefer_target(npcpos, selectednode, node, savedata)
		end
	end

	if selectednode then
		dprint("found in current chunk: NPC: "..minetest.pos_to_string(npcpos).." Block "..minetest.pos_to_string(selectednode.world_pos))
	end

	if not selectednode then
		dprint("get random node")

		local random_pos = plan:get_node_random()
		if random_pos then
			dprint("---check chunk", minetest.pos_to_string(random_pos))
			local wpos = plan:get_world_pos(random_pos)
			local node = npc_ai.get_if_buildable(plan, wpos)
			if node then
				selectednode = npc_ai.prefer_target(npcpos, selectednode, node, savedata)
			end

			if selectednode then
				dprint("random node: Block "..minetest.pos_to_string(random_pos))
			else
				dprint("random node not buildable, check the whole chunk", minetest.pos_to_string(random_pos))
				local chunk_nodes = plan:get_chunk_nodes(random_pos)
				dprint("Chunk loaeded: nodes:", #chunk_nodes)

				for idx, nodeplan in ipairs(chunk_nodes) do
					local node = npc_ai.get_if_buildable(plan, nodeplan.world_pos, nodeplan)
					if node then
						selectednode = npc_ai.prefer_target(npcpos, selectednode, node, savedata)
					end
				end
				if selectednode then
					dprint("found in current chunk: Block "..minetest.pos_to_string(selectednode.world_pos))
				end
			end
		else
			dprint("something wrong with random_pos")
		end
	end

	if selectednode then
		assert(selectednode.world_pos, "BUG: a position should exists")
		savedata.last_selection = selectednode
		return selectednode
	else
		dprint("no next node found", plan.data.nodecount)
	end
end

function npc_ai.place_node(targetnode)
	dprint("target reached - build", targetnode.name, minetest.pos_to_string(targetnode.world_pos))
	local soundspec
	if minetest.registered_items[targetnode.name].sounds then
		soundspec = minetest.registered_items[targetnode.name].sounds.place
	elseif targetnode.name == "air" then --TODO: should be determinated on old node, if the material handling is implemented
		soundspec = default.node_sound_leaves_defaults({place = {name = "default_place_node", gain = 0.25}})
	end
	if soundspec then
		soundspec.pos = targetnode.world_pos
		minetest.sound_play(soundspec.name, soundspec)
	end
	minetest.env:add_node(targetnode.world_pos, targetnode)
	if targetnode.meta then
		minetest.env:get_meta(targetnode.world_pos):from_table(targetnode.meta)
	end
end


return npc_ai
