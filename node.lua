--------------------------------------
--	Node class
--------------------------------------
local node_class = {}
node_class.__index = node_class
local node = {}
-------------------------------------
--	Create new node
--------------------------------------
node.new = function( data )
	local self = setmetatable(data, node_class)
	self.__index = node_class

	-- compat: param2
	self.param2 = self.param2 or 0

		-- metadata is only of intrest if it is not empty
	if self.meta then
		if (not self.meta.fields or not next(self.meta.fields)) and
				not (self.meta.inventory or not next(self.meta.inventory)) then
			self.meta = nil
		end
	end

	return self
end

-------------------
return node
