require "Data\\GE\\GameData"
require "Data\\GE\\PlayerData"
require "Data\\GE\\PresetData"
require "Utilities\\QuadTree"
require "Utilities\\GE\\IntroDataReader"
require "Utilities\\GE\\GuardDataReader"
require "Utilities\\GE\\ObjectDataReader"
require "Utilities\\GE\\ProjectileDataReader"
require "Utilities\\GE\\ExplosionDataReader"
--require "guard_LOS"

-- [Draw circles around doors showing where guards can open them from]
--	 * nil to disable
--   * 210 for aztec glass
guardHeightForDoors = nil	

local screen = {}

-- This doesn't work for window sizes that are larger than the monitor size, because
-- BizHawk silently rejects such cases. So window size may be set to e.g. 4x, while 
-- the actual size remains 2x.
screen.width = (client.bufferwidth() / client.getwindowsize())
screen.height = (client.bufferheight() / client.getwindowsize())

local map = {}

map.center_x = (screen.width / 2)
map.center_y = (screen.height / 2)
map.width = screen.width
map.height = (screen.height - (screen.height / 12) - 1) -- Account for black borders
map.min_x = (map.center_x - (map.width / 2))
map.min_y = (map.center_y - (map.height / 2))
map.max_x = (map.min_x + map.width)
map.max_y = (map.min_y + map.height)
map.units_per_pixel = (9600.0 / screen.height)

local text = {}

text.width = 7.5
text.height = 15

local output = {}

output.x = map.min_x
output.y = map.max_y
output.border_width = 10
output.border_height = 3
output.horizontal_spacing = 15
output.vertical_spacing = 2

local camera = {}

camera.modes = {"Manual", "Follow"}
camera.mode = 2
camera.position = {["x"] = 0.0, ["z"] = 0.0}
camera.floor = 1
camera.zoom = 7.5
camera.zoom_min = 1.0
camera.zoom_max = 100.0
camera.zoom_step = 0.5
camera.switch_mode_key = "M"
camera.switch_floor_key = "F"
camera.zoom_in_key = "Equals" --"NumberPadPlus"
camera.zoom_out_key = "Minus" --"NumberPadMinus"

local mission = {}

mission.index = 0xFF
mission.name = nil

local target = {}

target.type = "Player" -- "Guard" -- 
target.name = "Bond"
target.id = 0x20 -- nil
target.position = nil
target.height = nil

local constants = {}

constants.default_alpha = 0.7
constants.inactive_alpha_factor = 0.15
constants.view_cone_scale = 4.0
constants.view_cone_angle = 90.0
constants.target_circle_scale = 3.0
constants.max_picking_distance = 5.0
constants.max_picking_frames = 10
constants.min_guard_displacement = 0.1
constants.max_guard_displacement = 20.0
constants.projectile_radius = 8.0
constants.shockwave_to_damage_interval_ratio = 0.25
constants.shockwave_intensity = 0.3
constants.max_fadeout_intensity = 0.8

function make_color(_r, _g, _b, _a)
	local a_hex = bit.band(math.floor((_a * 255) + 0.5), 0xFF)
	local r_hex = bit.band(math.floor((_r * 255) + 0.5), 0xFF)
	local g_hex = bit.band(math.floor((_g * 255) + 0.5), 0xFF)
	local b_hex = bit.band(math.floor((_b * 255) + 0.5), 0xFF)
	
	a_hex = bit.lshift(a_hex, (8 * 3))
	r_hex = bit.lshift(r_hex, (8 * 2))
	g_hex = bit.lshift(g_hex, (8 * 1))
	b_hex = bit.lshift(b_hex, (8 * 0))
	
	return (a_hex + r_hex + g_hex + b_hex)
end

function make_rgb(_r, _g, _b)
	return make_color(_r, _g, _b, 0.0)
end

function make_alpha(_a)
	return make_color(0.0, 0.0, 0.0, _a)
end

function make_inactive_alpha(_a)
	return make_alpha(constants.inactive_alpha_factor * _a)
end

function make_alpha_pair(_a)
	return {["active"] = make_alpha(_a), ["inactive"] = make_inactive_alpha(_a)}
end

local colors = {}

colors.default_alpha = make_alpha_pair(constants.default_alpha)

colors.level_color = make_rgb(1.0, 1.0, 1.0)
colors.object_color = make_rgb(1.0, 1.0, 1.0)

colors.entity_edge_color = make_rgb(0.0, 0.0, 0.0)
colors.target_circle_color = make_rgb(1.0, 0.0, 0.0)
colors.view_cone_color = make_rgb(1.0, 1.0, 1.0)
colors.view_cone_alpha = make_alpha_pair(0.1)
colors.velocity_line_color = make_rgb(0.2, 0.8, 0.4)

colors.bond_stealth_suit_color = make_rgb(0.085, 0.1, 0.14)
colors.bond_fatigues_color = make_rgb(0.27, 0.27, 0.1)
colors.bond_parka_color = make_rgb(0.68, 0.70, 0.75)
colors.bond_dress_suit_color = make_rgb(0.2, 0.2, 0.32)
colors.bond_tuxedo_color = make_rgb(0.09, 0.09, 0.09)
colors.natalya_skirt_color = make_rgb(0.40, 0.85, 0.90)
colors.natalya_fatigues_color = make_rgb(0.55, 0.65, 0.65)
colors.trevelyan_dress_shirt_color = make_rgb(1, 0.2, 0.2) -- make_rgb(0.15, 0.15, 0.15)
colors.trevelyan_stealth_suit_color = make_rgb(0.1, 0.1, 0.15)
colors.boris_color = make_rgb(0.65, 0.35, 0.15)
colors.ouromov_color = make_rgb(0.375, 0.325, 0.2)
colors.valentin_color = make_rgb(0.15, 0.2, 0.235)
colors.xenia_color = make_rgb(0.2, 0.25, 0.25)
colors.baron_samedi_color = make_rgb(0.95, 0.9, 0.85)
colors.jaws_color = make_rgb(1.0, 1.0, 1.0)

colors.jungle_commando_color = make_rgb(0.34, 0.41, 0.1)
colors.russian_soldier_color = make_rgb(0.25, 0.36, 0.14)
colors.russian_infantry_color = make_rgb(0.55, 0.51, 0.33)
colors.janus_special_forces_color = make_rgb(0.1, 0.11, 0.08)
colors.janus_marine_color = make_rgb(0.38, 0.38, 0.38)
colors.russian_commandant_color = make_rgb(0.6, 0.49, 0.25)
colors.siberian_guard_a_color = make_rgb(0.09, 0.09, 0.09)
colors.siberian_guard_b_color = make_rgb(0.28, 0.25, 0.22)	
colors.naval_officer_color = make_rgb(0.125, 0.25, 0.1)
colors.siberian_special_forces_color = make_rgb(0.57, 0.60, 0.64)
colors.civilian_color = make_rgb(0.36, 0.19, 0.20)
colors.scientist_color = make_rgb(1.0, 1.0, 1.0)	
colors.arctic_commando_color = make_rgb(0.38, 0.48, 0.59)
colors.moonraker_elite_color = make_rgb(0.80, 0.78, 0.24)

colors.guard_dying_color = make_rgb(0.5, 0.0, 0.0)
colors.guard_bleeding_color = make_rgb(1.0, 0.3, 0.3)
colors.guard_shooting_color = make_rgb(1.0, 1.0, 0.0)
colors.guard_throwing_grenade_color = make_rgb(0.0, 0.3, 0.0)
colors.guard_unloaded_alpha = make_alpha_pair(0.3)

colors.projectile_default_color = make_rgb(0.6, 0.6, 0.6)
colors.projectile_grenade_color = make_rgb(0.0, 0.6, 0.0)
colors.projectile_remote_mine_color = make_rgb(0.8, 0.4, 0.4)
colors.projectile_proximity_mine_color = make_rgb(0.4, 1.0, 0.4)
colors.projectile_timed_mine_color = make_rgb(1.0, 1.0, 0.4)


function parse_scale()	
	return io.read("*n", "*l")
end

function parse_bounds(_scale)	
	local min_x, min_z, max_x, max_z = io.read("*n", "*n", "*n", "*n", "*l")	
	
	local bounds = {}
	
	bounds.min_x = (min_x / _scale)
	bounds.min_z = (min_z / _scale)
	bounds.max_x = (max_x / _scale)
	bounds.max_z = (max_z / _scale)
	
	return bounds
end

function parse_floors(_scale)
	local floors = {}
	local start_index = io.read("*n")
	
	for height in string.gmatch(io.read("*l"), "%S+") do	
		-- Offset the floors by 1 unit to ensure characters end up above the floor
		table.insert(floors, {["height"] = ((tonumber(height) / _scale) - 1.0)})
	end
	
	table.sort(floors, (function(a, b) return (a.height < b.height) end))

	for index, floor in ipairs(floors) do
		floor.index = (start_index + index - 1)
	end
	
	return floors
end

function parse_edges(_scale)
	local edges = {}

	while true do	
		local x1, y1, z1, x2, y2, z2 = io.read("*n", "*n", "*n", "*n", "*n", "*n", "*l")
		
		if not x1 then
			break
		end
		
		local edge = {}
		
		edge.x1 = (x1 / _scale)
		edge.y1 = (y1 / _scale)
		edge.z1 = (z1 / _scale)
		edge.x2 = (x2 / _scale)
		edge.y2 = (y2 / _scale)
		edge.z2 = (z2 / _scale)
		
		table.insert(edges, edge)
	end
	
	return edges
end

function parse_map_file(_filename)
	local file = io.open(_filename, "r")
	
	if not file then
		error("Failed to open file: " .. _filename)
	end
	
	io.input(file)
	
	local map = {}
	
	while true do
		local group = io.read("*l")
		
		if not group then
			break
		end
			
		if (group == "[Scale]") then
			map.scale = parse_scale()
		elseif (group == "[Bounds]") then
			map.bounds = parse_bounds(map.scale)
		elseif (group == "[Floors]") then
			map.floors = parse_floors(map.scale)
		elseif (group == "[Edges]") then
			map.edges = parse_edges(map.scale)
		else
			error("Invalid group type: " .. group)
		end
	end

	io.close(file)
	
	return map
end

function init_quadtree(_bounds, _edges)
	local quadtree = QuadTree.create(_bounds.min_x, _bounds.min_z, _bounds.width, _bounds.height, 1)
	
	if _edges then
		append_quadtree(quadtree, _edges, nil)
	end
	
	return quadtree
end

function append_quadtree(_quadtree, _edges, _object)
	for index, edge in ipairs(_edges) do
		edge["object"] = _object
		_quadtree:insert(edge)
	end
end

local level_data = {}

function init_level_data()
	for mission_index, mission_name in pairs(GameData.mission_index_to_name) do
		local data = parse_map_file("Maps/GE/" .. mission_name .. ".map")
		
		for index, edge in ipairs(data.edges) do
			edge.color = colors.level_color
		end
	
		level_data[mission_name] = data
	end
end

local level = {}

function load_level(_name)
	level = level_data[_name]
	
	level.bounds.width = (level.bounds.max_x - level.bounds.min_x)
	level.bounds.height = (level.bounds.max_z - level.bounds.min_z)
	
	level.quadtree = init_quadtree(level.bounds, level.edges)
end

function get_distance_2d(_x1, _y1, _x2, _y2)
	local diff_x = (_x1 - _x2)
	local diff_y = (_y1 - _y2)
	
	return math.sqrt((diff_x * diff_x) + (diff_y * diff_y))
end

function get_distance_3d(_p1, _p2)
	local diff_x = (_p1.x - _p2.x)
	local diff_y = (_p1.y - _p2.y)
	local diff_z = (_p1.z - _p2.z)
	
	return math.sqrt((diff_x * diff_x) + (diff_y * diff_y) + (diff_z * diff_z))
end

local objects = {}

function get_object_edges(_object_data_reader)
	local edges = {}	
	local points, min_y, max_y = _object_data_reader:get_collision_data()
	
	for i = 1, #points, 1 do
		local j = ((i % #points) + 1)
		
		local edge = {}
		
		edge.x1 = points[i].x
		edge.y1 = min_y
		edge.z1 = points[i].y			
		edge.x2 = points[j].x
		edge.y2 = max_y
		edge.z2 = points[j].y	
		
		edge.color = colors.object_color
		
		table.insert(edges, edge)
	end
	
	return edges
end

function load_static_object(_object_data_reader)	
	local static_object = {}
	
	static_object.edges = get_object_edges(_object_data_reader)
	static_object.data_reader = _object_data_reader:clone()
	
	append_quadtree(objects.quadtree, static_object.edges, static_object)

	table.insert(objects.static, static_object)
end

function load_dynamic_object(_object_data_reader)
	local dynamic_object = {}
	
	local position = _object_data_reader:get_value("position")	
	local edges = get_object_edges(_object_data_reader)
	
	local max_distance = 0.0
	
	for index, edge in ipairs(edges) do
		local distance = get_distance_2d(edge.x1, edge.z1, position.x, position.z)
		
		max_distance = math.max(max_distance, distance)
	end
	
	dynamic_object.bounding_radius = max_distance
	dynamic_object.data_reader = _object_data_reader:clone()

	table.insert(objects.dynamic, dynamic_object)
end

function load_object(_object_data_reader)
	local is_door = (_object_data_reader.current_data.type == 0x01)
	local is_vehicle = (_object_data_reader.current_data.type == 0x27)
	local is_tank = (_object_data_reader.current_data.type == 0x2D)
	
	if is_door then
		local state = _object_data_reader:get_value("state")
	
		-- Is the door opening or closing?
		if ((state == 0x01) or (state == 0x02)) then
			load_dynamic_object(_object_data_reader)
		else
			load_static_object(_object_data_reader)
		end	
	elseif is_vehicle or is_tank then
		load_dynamic_object(_object_data_reader)	
	else
		load_static_object(_object_data_reader)
	end
end

function load_objects()	
	objects.static = {}
	objects.dynamic = {}	
	objects.quadtree = init_quadtree(level.bounds)
	
	ObjectDataReader.for_each(function(_object_data_reader)
		if _object_data_reader:is_collidable() then
			load_object(_object_data_reader)
		end
	end)
end

function units_to_pixels(_units)
	return ((_units * camera.zoom) / map.units_per_pixel)
end

function pixels_to_units(_pixels)
	return ((_pixels * map.units_per_pixel) / camera.zoom)
end

function level_to_screen(_x, _z)
	local diff_x = units_to_pixels(_x - camera.position.x)
	local diff_z = units_to_pixels(_z - camera.position.z)
	
	local screen_x = (map.center_x + diff_x)
	local screen_y = (map.center_y + diff_z)
	
	return screen_x, screen_y
end

function screen_to_level(_x, _y)	
	local diff_x = (_x - map.center_x)
	local diff_y = (_y - map.center_y)
	
	local level_x = (pixels_to_units(diff_x) + camera.position.x)
	local level_z = (pixels_to_units(diff_y) + camera.position.z)
	
	return level_x, level_z
end

function get_floor(_height)
	for i = 2, #level.floors, 1 do
		if (_height < (level.floors[i].height)) then
			return (i - 1)
		end
	end
	
	return #level.floors
end

local default_camera = {}

default_camera.mode = camera.mode
default_camera.position = {["x"] = camera.position.x, ["z"] = camera.position.z}
default_camera.floor = camera.floor
default_camera.zoom = camera.zoom

function reset_camera()
	camera.mode = default_camera.mode
	camera.position = default_camera.position
	camera.floor = default_camera.floor
	camera.zoom = default_camera.zoom
end

local default_target = {}

default_target.type = target.type
default_target.id = target.id

function reset_target()
	target.type = default_target.type
	target.id = default_target.id
end

function reset_guards()
	guard_states = {}
end

function update_mission()
	local current_mission = GameData.get_current_mission()
	
	if (current_mission ~= mission.index) then
		mission.index = current_mission
		mission.name = GameData.get_mission_name(mission.index)
	
		load_level(mission.name)
		load_objects()
		
		reset_camera()
		reset_target()
		reset_guards()
	end
end

function pick_target(_x, _y)
	local target_to_position_map = {}	

	target_to_position_map[{["type"] = "Player"}] = PlayerData.get_value("position")
	
	GuardDataReader.for_each(function(_guard_data_reader)
		local id = _guard_data_reader:get_value("id")
		local position = _guard_data_reader:get_position()
		
		target_to_position_map[{["type"] = "Guard", ["id"] = id}] = position
	end)
	
	local targets_and_distances = {}
	
	for target, position in pairs(target_to_position_map) do
		local distance = get_distance_2d(_x, _y, level_to_screen(position.x, position.z))
		
		table.insert(targets_and_distances, {["target"] = target, ["distance"] = distance})	
	end

	table.sort(targets_and_distances, (function(a, b) return (a.distance < b.distance) end))
	
	local closest_target_and_distance = targets_and_distances[1]
	
	if (closest_target_and_distance.distance > (constants.max_picking_distance * camera.zoom)) then
		return {}
	end
	
	return closest_target_and_distance.target
end

local mouse_start_frame = nil

function on_mouse_button_down(_x, _y)
	mouse_start_frame = emu.framecount()
end

function on_mouse_button_up(_x, _y)
	if ((emu.framecount() - mouse_start_frame) <= constants.max_picking_frames) then
		target = pick_target(_x, _y)
	end
end

function on_mouse_drag(_diff_x, _diff_y)
	if (camera.mode == 2) then
		target = {}
	end
	
	camera.position.x = (camera.position.x - pixels_to_units(_diff_x))
	camera.position.z = (camera.position.z - pixels_to_units(_diff_y))
	 
	camera.position.x = math.max(camera.position.x, level.bounds.min_x)
	camera.position.x = math.min(camera.position.x, level.bounds.max_x)
	camera.position.z = math.max(camera.position.z, level.bounds.min_z)
	camera.position.z = math.min(camera.position.z, level.bounds.max_z)	
end

local previous_mouse =  nil

function update_mouse()
	current_mouse = input.getmouse()
	
	if previous_mouse and previous_mouse.Left then	
		if current_mouse.Left then
			local diff_x = (current_mouse.X - previous_mouse.X)
			local diff_y = (current_mouse.Y - previous_mouse.Y)
		
			if ((diff_x ~= 0) or (diff_y ~= 0)) then
				on_mouse_drag(diff_x, diff_y)
			end
		else	
			on_mouse_button_up(current_mouse.X, current_mouse.Y)						
		end
	elseif current_mouse.Left then
		if ((current_mouse.X >= 0) and
			(current_mouse.Y >= 0) and
			(current_mouse.X < screen.width) and
			(current_mouse.Y < screen.height)) then			
			on_mouse_button_down(current_mouse.X, current_mouse.Y)
		else
			current_mouse.Left = false
		end
	end
	
	previous_mouse = current_mouse
end

function on_switch_mode()
	camera.mode = (math.mod(camera.mode, #camera.modes) + 1)
end

function on_switch_floor()
	if ((camera.mode == 2) and (#level.floors > 1)) then
		target = {}
	end
		
	camera.floor = (math.mod(camera.floor, #level.floors) + 1)
end

function on_zoom_in()
	camera.zoom = math.min((camera.zoom + camera.zoom_step), camera.zoom_max)
end

function on_zoom_out()
	camera.zoom = math.max((camera.zoom - camera.zoom_step), camera.zoom_min)
end

function on_keyboard_button_down(key)
	if (key == camera.switch_mode_key) then
		on_switch_mode()
	elseif (key == camera.switch_floor_key) then
		on_switch_floor()
	elseif (key == camera.zoom_in_key) then
		on_zoom_in()
	elseif (key == camera.zoom_out_key) then
		on_zoom_out()
	end
end

function on_keyboard_button_up(key)
end

local previous_keyboard = nil

function update_keyboard()
	local current_keyboard = input.get()
	
	if previous_keyboard then
		for key, state in pairs(previous_keyboard) do
			if not current_keyboard[key] then
				on_keyboard_button_up(key)
			end
		end
		
		for key, state in pairs(current_keyboard) do
			if not previous_keyboard[key] then
				on_keyboard_button_down(key)
			end
		end
	end	
	
	previous_keyboard = current_keyboard
end

function update_target()
	local body_to_name = 
	{
		[0x06] = "Boris",
		[0x07] = "Ouromov",
		[0x08] = "Trevelyan",
		[0x09] = "Trevelyan",
		[0x0A] = "Valentin",
		[0x0B] = "Xenia",
		[0x0C] = "Baron Samedi",
		[0x0D] = "Jaws",
		[0x10] = "Natalya",
		[0x14] = "Hostage",
		[0x20] = "Civilian",
		[0x23] = "Scientist",
		[0x4F] = "Natalya"
	}
	
	if (target.type == "Player") then
		target.name = "Bond"
		target.position = PlayerData.get_value("position")
		target.height = PlayerData.get_value("clipping_height")
	elseif (target.type == "Guard") then
		GuardDataReader.for_each(function(_guard_data_reader)
			if (_guard_data_reader:get_value("id") == target.id) then
				target.name = (body_to_name[_guard_data_reader:get_value("body_model")] or (_guard_data_reader:is_clone() and "Clone" or "Guard"))			
				target.position = _guard_data_reader:get_position()
				target.height = _guard_data_reader:get_value("clipping_height")
			end
		end)
	else
		target.name = "None"
		target.position = nil
		target.height = nil
	end
end

function update_camera()
	if (camera.mode == 2) then
		if target.position and target.height then
			camera.position = target.position	
			camera.floor = get_floor(target.height)
		end
	end
end

function update_static_objects()
	local count = #objects.static

	for i = count, 1, -1 do
		local static_object = objects.static[i]
		
		-- Is this a door?
		if (static_object.data_reader.current_data.type == 0x01) then
			local state = static_object.data_reader:get_value("state")
			
			-- Is the door opening or closing?
			if ((state == 0x01) or (state == 0x02)) then
				load_dynamic_object(static_object.data_reader)

				table.remove(objects.static, i)
			end
		elseif not static_object.data_reader:is_collidable() then
			table.remove(objects.static, i)
		end
	end
	
	-- Rebuild quadtree (if needed)
	if (#objects.static ~= count) then 
		objects.quadtree = init_quadtree(level.bounds)
	
		for index, object in ipairs(objects.static) do
			append_quadtree(objects.quadtree, object.edges, object)
		end
	end
end

function update_dynamic_objects()
	for i = #objects.dynamic, 1, -1 do
		local dynamic_object = objects.dynamic[i]
		
		-- Is this a door?
		if (dynamic_object.data_reader.current_data.type == 0x01) then
			local state = dynamic_object.data_reader:get_value("state")
			
			-- Is the door not opening or closing?
			if ((state ~= 0x01) and (state ~= 0x02)) then			
				load_static_object(dynamic_object.data_reader)
				
				table.remove(objects.dynamic, i)
			end
		end	
	end
end

function update_objects()
	update_static_objects()
	update_dynamic_objects()
end

local guard_states = {}

function update_guard(_guard_data_reader)
	local current_state = {}
		
	current_state.action = _guard_data_reader:get_value("current_action")	
	current_state.position = _guard_data_reader:get_position()
	current_state.local_target_position = nil

	if (current_state.action == 0x0E) then
		current_state.target_position = _guard_data_reader:get_value("path_target_position")
		current_state.segment_coverage = _guard_data_reader:get_value("path_segment_coverage")
		current_state.segment_length = _guard_data_reader:get_value("path_segment_length")
		current_state.local_target_position = _guard_data_reader:get_value("local_target_position")
	elseif (current_state.action == 0x0F) then
		current_state.target_position = _guard_data_reader:get_value("target_position")
		current_state.segment_coverage = _guard_data_reader:get_value("segment_coverage")
		current_state.segment_length = _guard_data_reader:get_value("segment_length")
		current_state.local_target_position = _guard_data_reader:get_value("local_target_position")
	end

	if _guard_data_reader:get_value("local_target_set") == 0 then
		current_state.local_target_position = nil
	end
	
	current_state.is_moving = ((current_state.action == 0x0E) or (current_state.action == 0x0F))
	current_state.is_fading = (current_state.action == 0x05)
	current_state.is_loaded = true
	
	local id = _guard_data_reader:get_value("id")
	
	if current_state.is_moving then
		local previous_state = guard_states[id]
		
		if previous_state and previous_state.is_moving then	
			local displacement = 0.0
			
			if previous_state.is_loaded then
				if ((current_state.segment_coverage ~= previous_state.segment_coverage) or
					(current_state.segment_length ~= previous_state.segment_length)) then
					if ((current_state.segment_coverage >= 0.0) and
						(current_state.segment_coverage <= current_state.segment_length)) then
						displacement = (current_state.segment_coverage - previous_state.segment_coverage)
					end
				end
			else
				if ((current_state.position.x ~= previous_state.position.x) or
					(current_state.position.y ~= previous_state.position.y) or
					(current_state.position.z ~= previous_state.position.z)) then
					displacement = get_distance_3d(current_state.position, previous_state.position)
				end
			end	
				
			if ((displacement < constants.min_guard_displacement) or
				(displacement > constants.max_guard_displacement)) then
				current_state.is_loaded = previous_state.is_loaded
			else
				current_state.is_loaded = not previous_state.is_loaded
			end
		end
	end
	
	guard_states[id] = current_state 
end

function update_guards()
	GuardDataReader.for_each(update_guard)
end

-- Liang-Barsky algorithm.. to a rectangle
function clip_line(_line, _bounds)
	local diff_x = (_line.x2 - _line.x1)
	local diff_y = (_line.y2 - _line.y1)
	
	local p = {-diff_x, diff_x, -diff_y, diff_y}
	local q = {(_line.x1 - _bounds.min_x), -(_line.x1 - _bounds.max_x), (_line.y1 - _bounds.min_y), -(_line.y1 - _bounds.max_y)}
	
	local t0 = 0.0
	local t1 = 1.0
	
	for i = 1, 4, 1 do
		if ((p[i] == 0.0) and (q[i] < 0.0)) then
			return nil
		end
		
		local r = (q[i] / p[i])
		
		if (p[i] < 0.0) then
			if (r > t1) then
				return nil
			elseif (r > t0) then
				t0 = r
			end
		elseif (p[i] > 0.0) then
			if (r < t0) then
				return nil
			elseif (r < t1) then
				t1 = r
			end
		end
	end
	
	local clipped_line = {}
	
	clipped_line.x1 = (_line.x1 + (t0 * diff_x))
	clipped_line.y1 = (_line.y1 + (t0 * diff_y))
	clipped_line.x2 = (_line.x1 + (t1 * diff_x))
	clipped_line.y2 = (_line.y1 + (t1 * diff_y))
	
	return clipped_line
end

function get_current_alpha(_alpha, _is_active)
	local alpha = (_alpha or colors.default_alpha)
	
	return (_is_active and alpha.active or alpha.inactive)
end

function draw_line(_line)
	local line = {}

	line.x1, line.y1 = level_to_screen(_line.x1, _line.z1)
	line.x2, line.y2 = level_to_screen(_line.x2, _line.z2)
	
	if (((line.x1 < map.min_x) or (line.x1 > map.max_x)) or
		((line.y1 < map.min_y) or (line.y1 > map.max_y)) or
		((line.x2 < map.min_x) or (line.x2 > map.max_x)) or
		((line.y2 < map.min_y) or (line.y2 > map.max_y))) then
		line = clip_line(line, map)
		
		if not line then
			return
		end
	end	
	
	local min_height, max_height = _line.y1, _line.y2
	
	if (max_height < min_height) then
		min_height, max_height = max_height, min_height
	end
	
	local is_active = ((get_floor(min_height) <= camera.floor) and 
					   (get_floor(max_height) >= camera.floor))						   
	local color = (_line.color + get_current_alpha(_line.alpha, is_active))

	gui.drawLine(line.x1, line.y1, line.x2, line.y2, color)	
end

function draw_circle(_circle)
	local screen_x, screen_y = level_to_screen(_circle.x, _circle.z)
	local screen_radius = units_to_pixels(_circle.radius)
	local screen_diameter = (screen_radius * 2)
	
	local ellipse = {}
	
	ellipse.x = (screen_x - screen_radius)
	ellipse.y = (screen_y - screen_radius)
	ellipse.width = screen_diameter
	ellipse.height = screen_diameter
	
	if (not _circle.force) and ((ellipse.x < map.min_x) or
		(ellipse.y < map.min_y) or
		((ellipse.x + ellipse.width) > map.max_x) or
		((ellipse.y + ellipse.height) > map.max_y)) then
		return
	end
			
	local is_active = (get_floor(_circle.y) == camera.floor)
	local alpha = get_current_alpha(_circle.alpha, is_active)
	
	local inner_color = (_circle.inner_color and (_circle.inner_color + alpha) or nil)
	local outer_color = (_circle.outer_color and (_circle.outer_color + alpha) or nil)
	
	gui.drawEllipse(ellipse.x, ellipse.y, ellipse.width, ellipse.height, outer_color, inner_color)			
end

-- A sector
function draw_cone(_cone)
	local screen_x, screen_y = level_to_screen(_cone.x, _cone.z)
	local screen_radius = units_to_pixels(_cone.radius)
	local screen_diameter = (screen_radius * 2)

	local pie = {}
	
	pie.x = (screen_x - screen_radius)
	pie.y = (screen_y - screen_radius)
	pie.width = screen_diameter
	pie.height = screen_diameter
	pie.start_angle = _cone.start_angle
	pie.sweep_angle = _cone.sweep_angle
	
	if ((pie.x < map.min_x) or
		(pie.y < map.min_y) or
		((pie.x + pie.width) > map.max_x) or
		((pie.y + pie.height) > map.max_y)) then	
		return
	end
	
	local is_active = (get_floor(_cone.y) == camera.floor)
	local color = (_cone.color + get_current_alpha(_cone.alpha, is_active))

	gui.drawPie(pie.x, pie.y, pie.width, pie.height, pie.start_angle, pie.sweep_angle, color, color)		
end

function draw_rectangle(_rectangle)
	local box = {}
	
	box.x1, box.y1 = level_to_screen(_rectangle.x1, _rectangle.z1)
	box.x2, box.y2 = level_to_screen(_rectangle.x2, _rectangle.z2)
	
	if ((box.x1 > map.max_x) or
		(box.y1 > map.max_y) or
		(box.x2 < map.min_x) or
		(box.y2 < map.min_y)) then
		return
	end
	
	box.x1 = math.max(box.x1, map.min_x)
	box.y1 = math.max(box.y1, map.min_y)
	box.x2 = math.min(box.x2, map.max_x)
	box.y2 = math.min(box.y2, map.max_y)
	
	local min_height, max_height = _rectangle.y1, _rectangle.y2
	
	if (max_height < min_height) then
		min_height, max_height = max_height, min_height
	end
	
	local is_active = ((get_floor(min_height) <= camera.floor) and
					   (get_floor(max_height) >= camera.floor))					   
	local color = (_rectangle.color + get_current_alpha(_rectangle.alpha, is_active))
	
	gui.drawBox(box.x1, box.y1, box.x2, box.y2, color, color)
end

function draw_text(_text)	
	local lines = {}
	
	local offset_x = _text.border_width
	local offset_y = _text.border_height
	
	for index, fragment in ipairs(_text.fragments) do
		local width = math.ceil(text.width * string.len(fragment))
		
		if (#lines == 0) then
			table.insert(lines, {["y"] = offset_y, ["fragments"] = {}})
		elseif ((offset_x + width) > (_text.width - _text.border_width)) then
			offset_x = _text.border_width
			offset_y = (offset_y + text.height + _text.vertical_spacing)
		
			table.insert(lines, {["y"] = offset_y, ["fragments"] = {}})
		end
		
		table.insert(lines[#lines].fragments, {["text"] = fragment, ["width"] = width})
		
		offset_x = (offset_x + width + _text.horizontal_spacing)		
	end
	
	local text_height = (#lines * text.height)
	local text_spacing = ((#lines - 1) * _text.vertical_spacing)
	local text_border = (_text.border_height * 2)	
	local text_padding = ((text_height + text_spacing + text_border) - (screen.height - _text.y))
	
	client.SetGameExtraPadding(0, 0, 0, math.max(text_padding, 0))
	
	for index, line in ipairs(lines) do	
		for index, fragment in ipairs(line.fragments) do
			line.width = ((line.width or 0) + fragment.width)
		end	
	
		line.spacing = (((_text.width - (_text.border_width * 2)) - line.width) / #line.fragments)
		
		offset_x = _text.border_width
		
		for index, fragment in ipairs(line.fragments) do
			gui.drawText((_text.x + offset_x), (_text.y + line.y), fragment.text)
			
			offset_x = (offset_x + fragment.width + line.spacing)
		end
	end
end

function draw_level()
	local bounds = {}
	local collisions = {}
	
	bounds.x1, bounds.z1 = screen_to_level(map.min_x, map.min_y)
	bounds.x2, bounds.z2 = screen_to_level(map.max_x, map.max_y)
	
	level.quadtree:find_collisions(bounds, collisions)
	
	for key, edge in pairs(collisions) do
		draw_line(edge)
	end
end

function drawGuardCirclesForDoor(object, position)
	-- Guards' test is 2m but 3D, whereas ours is 2D
	if guardHeightForDoors == nil then
		return
	end

	if (object.data_reader.current_data.type == 0x01) then

		-- Sphere is radius 200, so we need to slice the sphere
		local yDiff = (position.y - guardHeightForDoors)
		yDiff = math.abs(yDiff)
		if yDiff >= 199.999 then	-- leaves radius ~5
			yDiff = 199.999
		end
		local radius = (40000 - (yDiff*yDiff))^(1/2)
		
		draw_circle({
			x=position.x,
			y=position.y,
			z=position.z,
			radius = radius,
			outer_color = 0xFF00DD66,
		})
	end
end

function drawDoorReachability(object)
	if (object.data_reader.current_data.type ~= 0x01) then
		return
	end

	doorReachabilityColour = make_rgb(0.0, 1, 0.0)

	-- 0-based, not 0x2710-based
	local preset = object.data_reader:get_value("preset")
	local presetAddr = PresetData.get_start_address() + 0x44 * preset

	-- We may need to use the y's to draw them or not
	-- Compare to camera.floor, though for now we'll just use the built in alpha-ing
	local low_y = PresetData:get_value(presetAddr, "low_y")
	local high_y = PresetData:get_value(presetAddr, "high_y")

	-- Get norm_z from the cross product, as the ASM does.
	-- We ASSUME normal_y is essentially upright, i.e. the door is
	local norm_x = PresetData:get_value(presetAddr, "normal_x")
	local norm_y = PresetData:get_value(presetAddr, "normal_y")
	local norm_z = {
		["z"] = (norm_x.x * norm_y.y - norm_y.x * norm_x.y),
		["x"] = (norm_x.y * norm_y.z - norm_y.y * norm_x.z),
		["y"] = (norm_x.z * norm_y.x - norm_y.z * norm_x.x),
	}

	-- Local x/z limits.
	local x_limits = {
		PresetData:get_value(presetAddr, "low_x"),
		PresetData:get_value(presetAddr, "high_x"),
	}
	local z_limits = {
		PresetData:get_value(presetAddr, "low_z"),
		PresetData:get_value(presetAddr, "high_z"),
	}

	-- Produce the final points, lifted from python
	local preset_pos = PresetData:get_value(presetAddr, "position")
	local expansion = 150

	local js = {2,2,1,1}
	local ks = {2,1,1,2}
	local change = {-expansion, expansion}
	local pnts = {}
	local i,j,k,doorX,doorZ

	for i = 1,4,1 do
		j = js[i]
		k = ks[i]

		doorX = x_limits[j] + change[j]
		doorZ = z_limits[k] + change[k]
		table.insert(pnts, {
			x = preset_pos.x + norm_x.x*doorX + norm_z.x*doorZ, 
			z = preset_pos.z + norm_x.z*doorX + norm_z.z*doorZ,
		})
	end

	-- Draw each of the edges to form this expanded rectangle
	for i = 1,4,1 do
		j = (i % 4) + 1
		local line = {
			x1 = pnts[i].x, z1 = pnts[i].z,
			y1 = preset_pos.y,	-- place at the door's height atm
			x2 = pnts[j].x, z2 = pnts[j].z,
			y2 = preset_pos.y,
			color=doorReachabilityColour,
			-- If specifying alpha, needs to have 'active' and 'inactive' values
		}
		draw_line(line)
	end

	-- And then draw the circle also, but around the object's position
	local door_pos = object.data_reader:get_value("position")
	draw_circle({
		x=door_pos.x,
		y=door_pos.y,
		z=door_pos.z,
		radius = 200,
		outer_color = doorReachabilityColour,
		force=true,
	})

end

function drawActivatableRange(object)
	-- Radius 2m, or 4m for an aircraft.
	-- Our angle must also be within 22.5 degrees, or 120 for the aircraft
	local radius = 200
	if object.data_reader.current_data.type == 0x28 then
		radius = 400
	end

	local pos = object.data_reader:get_value("position")

	draw_circle({
		x = pos.x,
		y = pos.y,
		z = pos.z,
		radius = radius,
		outer_color = make_rgb(0,1,0),
		force=true,
	})
end

-- ! Activatable objects are only obtained once, otherwise we'll have to repeatedly reparse scripts
local activatableObjects = ScriptData.getActivatableObjects()

function draw_static_objects(_bounds)
	local count = 0
	local collisions = {}

	objects.quadtree:find_collisions(_bounds, collisions)

	-- Draw the lines and collect together the objects which are on screen
	onscreenObjs = {}
	for key, edge in pairs(collisions) do
		onscreenObjs[edge.object.data_reader.current_address] = edge.object
		draw_line(edge)
	end

	-- Iterate over just the activatable objects
	-- TODO check they are on-screen, though our 2 on frigate don't have collision
	for _, objAddr in ipairs(activatableObjects) do
		-- Create a mock obj
		local actObj = {}
		actObj.data_reader = ObjectDataReader.create()
		actObj.data_reader.current_address = objAddr
		actObj.data_reader.current_data = ObjectData.get_data(objAddr)
		drawActivatableRange(actObj)
	end

	-- Iterate over all on screen objects
	for _, object in pairs(onscreenObjs) do
		local position = object.data_reader:get_value("position")
		drawGuardCirclesForDoor(object, position)
		drawDoorReachability(object)
	end
end

function draw_dynamic_objects(_bounds)
	for index, object in ipairs(objects.dynamic) do
		local position = object.data_reader:get_value("position")
		
		if (((position.x + object.bounding_radius) > _bounds.x1) and
			((position.z + object.bounding_radius) > _bounds.z1) and
			((position.x - object.bounding_radius) < _bounds.x2) and
			((position.z - object.bounding_radius) < _bounds.z2)) then

			drawGuardCirclesForDoor(object, position)

			local edges = get_object_edges(object.data_reader)
			
			for index, edge in ipairs(edges) do
				draw_line(edge)
			end
		end
	end
end

function draw_objects()
	local bounds = {}
	
	bounds.x1, bounds.z1 = screen_to_level(map.min_x, map.min_y)
	bounds.x2, bounds.z2 = screen_to_level(map.max_x, map.max_y)

	draw_static_objects(bounds)
	draw_dynamic_objects(bounds)
end

function draw_entity(_entity)
	local entity_circle = {}
	
	entity_circle.x = _entity.x
	entity_circle.y = _entity.y
	entity_circle.z = _entity.z
	entity_circle.radius = _entity.radius
	entity_circle.inner_color = _entity.color
	entity_circle.outer_color = colors.entity_edge_color
	entity_circle.alpha = _entity.alpha

	draw_circle(entity_circle)
	
	if _entity.is_target then
		local target_circle = {}
		
		target_circle.x = _entity.x
		target_circle.y = _entity.y
		target_circle.z = _entity.z
		target_circle.radius = (_entity.radius * constants.target_circle_scale)
		target_circle.outer_color = colors.target_circle_color
		
		draw_circle(target_circle)
	end
end

function draw_guard(_guard_data_reader)
	-- Work even if guards are off screen

	-- Constants should probably be globals
	local action_to_color = 
	{
		[0x04] = colors.guard_dying_color,
		[0x05] = colors.guard_dying_color,
		[0x06] = colors.guard_bleeding_color,
		[0x08] = colors.guard_shooting_color,
		[0x09] = colors.guard_shooting_color,
		[0x0A] = colors.guard_shooting_color,
		[0x14] = colors.guard_throwing_grenade_color
	}
	
	local body_to_color = 
	{
		[0x00] = colors.jungle_commando_color,
		[0x01] = colors.st_petersburg_guard_color,
		[0x02] = colors.russian_soldier_color,
		[0x03] = colors.russian_infantry_color,
		[0x04] = colors.janus_special_forces_color,
		[0x06] = colors.boris_color,
		[0x07] = colors.ouromov_color,
		[0x08] = colors.trevelyan_dress_shirt_color,
		[0x09] = colors.trevelyan_stealth_suit_color,
		[0x0A] = colors.valentin_color,
		[0x0B] = colors.xenia_color,
		[0x0C] = colors.baron_samedi_color,
		[0x0D] = colors.jaws_color,
		[0x10] = colors.natalya_skirt_color,
		[0x11] = colors.janus_marine_color,
		[0x12] = colors.russian_commandant_color,
		[0x13] = colors.siberian_guard_a_color,
		[0x14] = colors.naval_officer_color,
		[0x15] = colors.siberian_special_forces_color,
		[0x20] = colors.civilian_color,
		[0x23] = colors.scientist_color,
		[0x25] = colors.siberian_guard_b_color,
		[0x26] = colors.arctic_commando_color,
		[0x27] = colors.moonraker_elite_color,
		[0x4F] = colors.natalya_fatigues_color			
	}
	
	local id = _guard_data_reader:get_value("id")	
	local body_model = _guard_data_reader:get_value("body_model")
	local collision_radius = _guard_data_reader:get_value("collision_radius")
	local clipping_height = _guard_data_reader:get_value("clipping_height")		
	
	local state = guard_states[id]
	local color = (action_to_color[state.action] or body_to_color[body_model])
	local alpha = colors.default_alpha	
	
	if state.is_fading then
		alpha = make_alpha_pair(constants.default_alpha * (_guard_data_reader:get_value("alpha") / 255.0))
	elseif state.is_moving then
		local segment_line = {}
		
		-- Draw the guard's segment
		segment_line.x1 = state.position.x
		segment_line.y1 = clipping_height
		segment_line.z1 = state.position.z		
		segment_line.x2 = state.target_position.x
		segment_line.y2 = clipping_height
		segment_line.z2 = state.target_position.z				
		segment_line.color = make_rgb(1, 0.0, 0.0) -- color
		segment_line.alpha = (not state.is_loaded and colors.guard_unloaded_alpha)
		
		draw_line(segment_line)

		if not state.is_loaded then
			local dir_x = ((state.target_position.x - state.position.x) / state.segment_length)
			local dir_z = ((state.target_position.z - state.position.z) / state.segment_length)
			
			local unloaded_entity = {}
			
			unloaded_entity.x = (state.position.x + (dir_x * state.segment_coverage))
			unloaded_entity.y = clipping_height
			unloaded_entity.z = (state.position.z + (dir_z * state.segment_coverage))
			unloaded_entity.radius = collision_radius
			unloaded_entity.color = color
			unloaded_entity.alpha = colors.guard_unloaded_alpha
			
			draw_entity(unloaded_entity)
		end		
	end


	-- Rough Trev's line of sight on caverns.
	--if drawTrevLOS and GameData.get_current_mission() == 0x17 and _guard_data_reader:get_value("health") == 6000.0 then
	--	trevLOS = get_LOS_sectors(_guard_data_reader.current_address)
	--	for _, sector in ipairs(trevLOS) do
	--		draw_line(sector.cws)
	--		draw_line(sector.acws)
	--	end
	--end
	
	
	local loaded_entity = {}
	
	loaded_entity.x = state.position.x
	loaded_entity.y = clipping_height
	loaded_entity.z = state.position.z
	loaded_entity.radius = collision_radius
	loaded_entity.is_target = ((target.type == "Guard") and (target.id == id))
	loaded_entity.color = color
	loaded_entity.alpha = alpha	
	
	draw_entity(loaded_entity)

	
	-- =================== Drawing Facing dirc =================
	-- We add a thin triangle pointing the way that the guard is facing

	local addr = _guard_data_reader.current_address
	local az_ang = GuardData.azimuth_angle(addr)
	local cosAz = math.cos(az_ang)
	local sinAz = math.sin(az_ang)

	local cr = collision_radius
	local point = {x=state.position.x + cr*1.5*sinAz, z=state.position.z + cr*1.25*cosAz}
	local baseV = {x=cr*0.2*cosAz, z=-cr*0.2*sinAz}
	
	-- Lines for base, and each base vertex to the outer point
	-- Chosen colour is approximately adding 128 to each colour component, modulo 256
	-- (Actually may get carries from b -> g or g -> r, but they are at most 1)
	local compColour = 0xFF000000 + ((0x00808080 + color) % 0x01000000)
	local baseLine = {	x1 = state.position.x + baseV.x, z1 = state.position.z + baseV.z, y1 = clipping_height,
						x2 = state.position.x - baseV.x, z2 = state.position.z - baseV.z, y2 = clipping_height,
					color=compColour, alpha=alpha}
	local edge1 = {		x1 = state.position.x + baseV.x, z1 = state.position.z + baseV.z, y1 = clipping_height,
						x2 = point.x, z2 = point.z, y2 = clipping_height,
						color=compColour, alpha=alpha}
	local edge2 = {	x1 = state.position.x - baseV.x, z1 = state.position.z - baseV.z, y1 = clipping_height,
						x2 = point.x, z2 = point.z, y2 = clipping_height,
						color=compColour, alpha=alpha}
	-- decided we don't like the baseline
	draw_line(edge1)
	draw_line(edge2)


	
	-- Draw the local target if it's set (we're chasing / walking and it's valid)
	if state.local_target_position ~= nil then
		local edge = {
			x1 = state.position.x, z1 = state.position.z, y1 = clipping_height,
			x2 = state.local_target_position.x, z2 = state.local_target_position.z, y2 = clipping_height,
			color=0xFFFF00FF, alpha=alpha,
		}
		draw_line(edge)
	end


	-- Drawing whiskers on Boris
	--if drawBorisWhiskers and body_model == 0x06 then
	--	local lbv = {x=400*cosAz, z=-400*sinAz}
	--	local whiskers = {
	--		x1 = state.position.x - lbv.x, z1 = state.position.z - lbv.z, y1 = clipping_height,
	--		x2 = state.position.x + lbv.x, z2 = state.position.z + lbv.z, y2 = clipping_height,
	--		color=compColour, alpha=alpha
	--	}
	--	draw_line(whiskers)
	--end

end

function draw_guards()
	GuardDataReader.for_each(draw_guard)
end

function draw_bond()
	local outfit_to_color =
	{
		[0x00] = colors.bond_dress_suit_color,
		[0x02] = colors.bond_fatigues_color,
		[0x03] = colors.bond_stealth_suit_color,
		[0x04] = colors.bond_parka_color,
		[0x08] = colors.bond_tuxedo_color
	}
	
	local position = PlayerData.get_value("position")
	local collision_radius = PlayerData.get_value("collision_radius")
	local clipping_height = PlayerData.get_value("clipping_height")
	local view_angle = (PlayerData.get_value("azimuth_angle") + 90)
	local velocity = PlayerData.get_value("velocity")
	
	local color = nil
	
	-- Literally every frame
	IntroDataReader.for_each(function(_intro_data_reader) 
		if (_intro_data_reader.current_data.type == 0x05) then
			local outfit = _intro_data_reader:get_value("outfit")
		
			color = outfit_to_color[outfit]
		end
	end)
	
	-- Cone code example
	local view_cone = {}
	
	view_cone.x = position.x
	view_cone.y = clipping_height
	view_cone.z = position.z
	view_cone.radius = (collision_radius * constants.view_cone_scale)
	view_cone.start_angle = (view_angle - (constants.view_cone_angle / 2))
	view_cone.sweep_angle = constants.view_cone_angle
	view_cone.color = colors.view_cone_color
	view_cone.alpha = colors.view_cone_alpha
	
	draw_cone(view_cone)
	
	local view_angle_radians = math.rad(view_angle)
	local view_angle_cosine = math.cos(view_angle_radians)
	local view_angle_sine = math.sin(view_angle_radians)
	
	local velocity_x = ((view_angle_cosine * velocity.z) - (view_angle_sine * velocity.x))
	local velocity_z = ((view_angle_cosine * velocity.x) + (view_angle_sine * velocity.z))
	
	local velocity_line = {}
	
	velocity_line.x1 = position.x
	velocity_line.y1 = clipping_height
	velocity_line.z1 = position.z	
	velocity_line.x2 = (position.x + velocity_x)
	velocity_line.y2 = clipping_height
	velocity_line.z2 = (position.z + velocity_z)	
	velocity_line.color = colors.velocity_line_color
	
	draw_line(velocity_line)
	
	local entity = {}
	
	entity.x = position.x
	entity.y = clipping_height
	entity.z = position.z
	entity.radius = collision_radius
	entity.is_target = (target.type == "Player")	
	entity.color = color	
	
	draw_entity(entity)
end

-- TODO: Draw all weapons, not just projectiles?
function draw_projectile(_projectile_data_reader)
	local image_to_color = 
	{
		[0x0BA] = colors.projectile_default_color, 			-- Knife
		[0x0C4] = colors.projectile_grenade_color, 			-- Hand grenade
		[0x0C7] = colors.projectile_remote_mine_color, 		-- Remote mine
		[0x0C8] = colors.projectile_proximity_mine_color, 	-- Proximity mine
		[0x0C9] = colors.projectile_timed_mine_color, 		-- Timed mine
		[0x0CA] = colors.projectile_default_color, 			-- Rocket
		[0x0CB] = colors.projectile_default_color, 			-- Grenade
		[0x0F5] = colors.projectile_default_color, 			-- Covert modem/Tracker bug
		[0x111] = colors.projectile_default_color 			-- Plastique
	}

	local position = _projectile_data_reader:get_value("position")
	local image = _projectile_data_reader:get_value("image")
	
	local color = image_to_color[image]
	
	if not color then
		return
	end
	
	local entity = {}
	
	entity.x = position.x
	entity.y = position.y
	entity.z = position.z
	entity.radius = constants.projectile_radius
	entity.color = color
	entity.is_target = true
	
	draw_entity(entity)
end

function draw_projectiles()
	ProjectileDataReader.for_each(draw_projectile)
end

function draw_explosion(_explosion_data_reader)	
	local position = _explosion_data_reader:get_position()
	
	local animation_frame = _explosion_data_reader:get_value("animation_frame")
	local animation_length = _explosion_data_reader:get_type_value("animation_length")
	
	local min_damage_radius = _explosion_data_reader:get_type_value("min_damage_radius")
	local max_damage_radius = _explosion_data_reader:get_type_value("max_damage_radius")
	
	local damage_interval = (animation_length / 4)
	local damage_speed = ((max_damage_radius - min_damage_radius) / animation_length)	
	local damage_radius = (min_damage_radius + (animation_frame * damage_speed))
	
	local next_damage_frame = _explosion_data_reader:get_value("next_damage_frame")
	local prev_damage_frame = (next_damage_frame - damage_interval)
	
	local shockwave_length = (constants.shockwave_to_damage_interval_ratio * damage_interval)
	local fadeout_length = (damage_interval - shockwave_length)
	
	local intensity = constants.shockwave_intensity
	
	if (animation_frame <= ExplosionData.no_damage_frame_count) then
		damage_radius = (animation_frame * (damage_radius / ExplosionData.no_damage_frame_count))
	else
		local damage_frame = (animation_frame - prev_damage_frame)

		if (next_damage_frame < animation_length) then
			if (damage_frame > fadeout_length) then
				local shockwave_frame = (damage_frame - fadeout_length)
				local shockwave_speed = (damage_radius / shockwave_length)
		
				damage_radius = (shockwave_frame * shockwave_speed)
			else			
				intensity = (constants.max_fadeout_intensity * math.max((1.0 - (damage_frame / fadeout_length)), 0.0))
			end
		else				
			intensity = (constants.max_fadeout_intensity * math.max((1.0 - (damage_frame / damage_interval)), 0.0))
		end		
	end

	local rectangle = {}
	
	rectangle.x1 = (position.x - damage_radius)
	rectangle.y1 = (position.y - damage_radius)
	rectangle.z1 = (position.z - damage_radius)	
	rectangle.x2 = (position.x + damage_radius)
	rectangle.y2 = (position.y + damage_radius)
	rectangle.z2 = (position.z + damage_radius)
	
	rectangle.color = make_rgb(1.0, intensity, 0.0)
	rectangle.alpha = make_alpha_pair(intensity)
	
	draw_rectangle(rectangle)
end

function draw_explosions()
	ExplosionDataReader.for_each(draw_explosion)
end

function draw_output()
	local fragments = {}
	
	table.insert(fragments, string.format("Mode: %s", camera.modes[camera.mode]))
	
	if target.id then
		table.insert(fragments, string.format("Target: %s (0x%X)", target.name, target.id))
	else
		table.insert(fragments, string.format("Target: %s", target.name))
	end	
	
	local floor_suffixes = {"st", "nd", "rd", "th"}		
	local floor_index = level.floors[camera.floor].index	
	local floor_number = ((floor_index < 0) and math.abs(floor_index) or (floor_index + 1))
	local floor_type = ((floor_index < 0) and "basement" or "floor")	
	local floor_suffix = floor_suffixes[math.min(math.mod(floor_number, 10), 4)]
	
	table.insert(fragments, string.format("%d%s %s", floor_number, floor_suffix, floor_type))
	table.insert(fragments, string.format("X: %d Z: %d", camera.position.x, camera.position.z))
	table.insert(fragments, string.format("Zoom: %.1fx", camera.zoom))
	
	local text = {}
	
	text.x = map.min_x
	text.y = map.max_y
	text.width = map.width
	text.border_width = output.border_width
	text.border_height = output.border_height
	text.horizontal_spacing = output.horizontal_spacing
	text.vertical_spacing = output.vertical_spacing
	text.fragments = fragments
	
	draw_text(text)
end

function is_mission_running()
	return ((GameData.get_mission_state() ~= 0) and 
			(GameData.get_global_timer() ~= 0))
end

function on_load_state()
	if not is_mission_running() then
		return
	end	
		
	load_objects()
	reset_guards()
end

function on_update()
	if not is_mission_running() then
		return
	end

	update_mission()
	update_mouse()
	update_keyboard()
	update_target()
	update_camera()	
	update_objects()
	update_guards()
	
	draw_level()
	draw_objects()
	draw_guards()
	draw_bond()
	draw_projectiles()
	draw_explosions()
	draw_output()
end

init_level_data()

-- Named events now
while event.unregisterbyname("WM_load") do
	--
end
while event.unregisterbyname("WM_update") do
	--
end
event.onloadstate(on_load_state, "WM_load")
event.onframeend(on_update, "WM_update")