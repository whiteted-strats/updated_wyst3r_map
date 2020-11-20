QuadTree = {}
QuadTree.__index = QuadTree

function QuadTree.create(_x, _z, _width, _height, _level)
   local quadtree = {}
   
   setmetatable(quadtree, QuadTree)
   
   quadtree.x = _x
   quadtree.z = _z
   quadtree.width = _width
   quadtree.height = _height
   quadtree.level = _level
   quadtree.children = nil
   quadtree.objects = {}
   
   return quadtree
end

function QuadTree:split()
	local subwidth = math.floor(self.width / 2)
	local subheight = math.floor(self.height / 2)
	
	self.children = 
	{
		QuadTree.create(self.x, 			self.z, 			subwidth, subheight, (self.level + 1)),
		QuadTree.create(self.x + subwidth, 	self.z, 			subwidth, subheight, (self.level + 1)),
		QuadTree.create(self.x, 			self.z + subheight, subwidth, subheight, (self.level + 1)),
		QuadTree.create(self.x + subwidth, 	self.z + subheight, subwidth, subheight, (self.level + 1))
	}
end

function QuadTree:get_quadrants(_object)
	local quadrants = nil
	
	local center_x = (self.x + math.floor(self.width / 2))
	local center_z = (self.z + math.floor(self.height / 2))
	
	local isLeft = ((_object.x1 < center_x) and (_object.x2 < center_x))
	local isTop = ((_object.z1 < center_z) and (_object.z2 < center_z))
	local isRight = ((_object.x1 > center_x) and (_object.x2 > center_x))
	local isBottom = ((_object.z1 > center_z) and (_object.z2 > center_z))
	
	if isLeft then
		if isTop then
			quadrants = {1}
		elseif isBottom then
			quadrants = {3}
		else
			quadrants = {1, 3}
		end
	elseif isRight then
		if isTop then
			quadrants = {2}
		elseif isBottom then
			quadrants = {4}
		else
			quadrants = {2, 4}
		end
	else
		if isTop then
			quadrants = {1, 2}
		elseif isBottom then
			quadrants = {3, 4}
		else
			quadrants = {1, 2, 3, 4}
		end
	end
	
	return quadrants
end

function QuadTree:insert(_object)
	if self.children then
		local quadrants = self:get_quadrants(_object)
		
		for index, quadrant in ipairs(quadrants) do
			self.children[quadrant]:insert(_object)	
		end		
		
		return
	end
	
	table.insert(self.objects, _object)
	
	if ((#self.objects > 10) and (self.level <= 10)) then
		if not self.children then
			self:split()
		end
		
		index = 1	
		
		while index <= #self.objects do
			local object = self.objects[index]
			local quadrants = self:get_quadrants(object)
			
			for index, quadrant in ipairs(quadrants) do
				self.children[quadrant]:insert(object)	
			end	
				
			table.remove(self.objects, index)
		end		
	end
end

function QuadTree:getobjects(_objects)
	for index, object in ipairs(self.objects) do
		_objects[object] = object
	end
end

function QuadTree:find_collisions(_object, _collisions)
	if self.children then
		local quadrants = self:get_quadrants(_object)
		
		for index, quadrant in ipairs(quadrants) do
			self.children[quadrant]:find_collisions(_object, _collisions)
		end	
	end
	
	self:getobjects(_collisions)
end