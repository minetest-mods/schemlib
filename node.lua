local mapping = schemlib.mapping

--------------------------------------
--	Node class
--------------------------------------
local node_class = {}
node_class.__index = node_class
local node = {}
node.node_class = node_class
-------------------------------------
--	Create new node
--------------------------------------
function node.new(data)
	local self = setmetatable({}, node_class)
	self.__index = node_class

	self.name = data.name
	assert(self.name, "No name given for node object")

	self.data = {}
	-- compat: param2
	self.data.param2 = data.param2 or 0
	self.data.prob = data.prob

		-- metadata is only of intrest if it is not empty
	if data.meta then
		if (data.meta.fields and next(data.meta.fields)) or
				(data.meta.inventory and next(data.meta.inventory)) then
			self.data.meta = data.meta
		end
	end

	return self
end

-------------------------------------
--	Get node position in the world
--------------------------------------
function node_class:get_world_pos()
	if not self._world_pos then
		self._world_pos = self.plan:get_world_pos(self._plan_pos)
	end
	return self._world_pos
end

-------------------------------------
--	Get all information to build the node
--------------------------------------
function node_class:get_mapped()
	if self.mapped == 'unknown' then
		return
	end

	local mappedinfo = self.nodeinfo.mapped
	if not mappedinfo then
		mappedinfo = mapping.map(self.name)
		self.nodeinfo.mapped = mappedinfo
		self.mapped = nil
	end

	if not mappedinfo or mappedinfo == 'unknown' then
		self.nodeinfo.mapped = 'unknown'
		self.mapped = 'unknown'
		return
	end

	if self.mapped and self.mapped.name == mappedinfo.name_orig then
		return self.mapped
	end

	local mapped = table.copy(mappedinfo)
	mapped.name = mapped.name or self.data.name
	mapped.param2 = mapped.param2 or self.data.param2
	mapped.meta = mapped.meta or self.data.meta
	mapped.prob = mapped.prob or self.data.prob

	if mapped.custom_function ~= nil then
		mapped.custom_function(mapped, self._plan_pos, self:get_world_pos())
		mapped.custom_function = nil
	end

	mapped.content_id = minetest.get_content_id(mapped.name)
	self.mapped = mapped
	self.cost_item = mapped.cost_item -- workaround / backwards compatibility to npcf_builder
	return mapped
end


--------------------------------------
-- get node under this one if exists
--------------------------------------
function node_class:get_under()
	return self.plan:get_node({x=self._plan_pos.x, y=self._plan_pos.y-1, z=self._plan_pos.z})
end

--------------------------------------
-- get node above this one if exists
--------------------------------------
function node_class:get_above()
	return self.plan:get_node({x=self._plan_pos.x, y=self._plan_pos.y+1, z=self._plan_pos.z})
end


--------------------------------------
-- add/build a node
--------------------------------------
function node_class:place()
	local mapped = self:get_mapped()
	local world_pos = self:get_world_pos()
	if mapped then
		minetest.add_node(world_pos, mapped)
		if mapped.meta then
			minetest.get_meta(world_pos):from_table(mapped.meta)
		end
	end
	if not self.final_node_name then
		self:remove_from_plan()
	end
end

--------------------------------------
-- Delete node from plan
--------------------------------------
function node_class:remove_from_plan()
	self.plan:del_node(self._plan_pos)
end

-------------------
return node
