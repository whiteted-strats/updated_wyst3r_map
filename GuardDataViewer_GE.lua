require "Data\\GE\\GuardData"

local guard_data_mnemonics = 
{
	["current_action"] = 
	{
		[0x1] = "standing",
		[0x2] = "ducking",
		[0x3] = "wasting time",
		[0x4] = "dying",
		[0x5] = "fading",
		[0x6] = "hurting",
		[0x8] = "shooting/aiming",
		[0x9] = "shooting + walking",
		[0xA] = "shooting + running/rolling",
		[0xB] = "sidestepping",
		[0xC] = "sidehopping",
		[0xD] = "running away",
		[0xE] = "walking along path",
		[0xF] = "moving",
		[0x10] = "surrendering",
		[0x12] = "looking around",
		[0x13] = "triggering alarm",
		[0x14] = "throwing grenade"		
	}
}

function format_value(value, metadata)
	if not value then
		return string.format("%s: N/A", metadata.name)
	end
	
	local value_string = nil

	if metadata.type == "hex" then
		value_string = string.format("0x%X", value)
	elseif metadata.type == "unsigned" then
		value_string = string.format("%d", value)
	elseif metadata.type == "float" then
		value_string = string.format("%.4f", value)
	elseif metadata.type == "vector" then
		if (metadata.size == 0x0C) then	
			value_string = string.format("{%.4f, %.4f, %.4f}", value.x, value.y, value.z)
		elseif (metadata.size == 0x08) then
			value_string = string.format("{%.4f, %.4f}", value.x, value.y)
		else
			error("Invalid size")		
		end		
	elseif metadata.type == "enum" then
		value_string = (guard_data_mnemonics[metadata.name][value] or string.format("unknown (0x%X)", value))
	else
		error("Invalid type")
	end
	
	return string.format("%s: %s", metadata.name, value_string)
end

function on_update_text(_slot)
	local slot_address = (GuardData.get_start_address() + ((_slot - 1) * GuardData.size))
	local slot_address_metadata = {["name"] = "slot_address", ["type"] = "hex"}
	local slot_address_string = format_value(slot_address, slot_address_metadata)
	
	local is_empty = not slot_address or GuardData.is_empty(slot_address)
	
	local guard_data_string = slot_address_string .. "\n\n"
	

	for index, metadata in ipairs(GuardData.metadata) do
		local value = nil
		
		if not is_empty then
			value = GuardData:get_value(slot_address, metadata.name)
		end
		
		local value_address = (slot_address + metadata.offset)
		local value_string = string.format("[0x%X] %s", value_address, format_value(value, metadata))
		
		-- Trim
		if (string.len(value_string) > guard_data_output_text_max_length) then
			value_string = string.format("%s...", string.sub(value_string, 0, (guard_data_output_text_max_length - 4)))
		end
		
		guard_data_string = (guard_data_string .. value_string .. "\n")
	end
	
	if is_empty then
		guard_data_string = (guard_data_string .. "\n(empty)")
	end

	forms.settext(guard_data_output_text, guard_data_string)
end

local current_slot = 1

function on_update_slot()
	local capacity = GuardData.get_capacity()
	
	current_slot = math.max(current_slot, 1)
	current_slot = math.min(current_slot, capacity)
	
	local slot_string = string.format("Slot %d / %d", current_slot, capacity)
	
	forms.settext(guard_data_slot_text, slot_string)
end

function on_update()
	on_update_slot()	
	on_update_text(current_slot)
end

function on_prev_slot()
	current_slot = math.max((current_slot - 1), 1)
	
	on_update()
end

function on_next_slot()
	current_slot = math.min((current_slot + 1), GuardData.get_capacity())
	
	on_update()
end

guard_data_button_size_x = 75
guard_data_button_size_y = 25

guard_data_dialog_size_x = 540
guard_data_dialog_size_y = 920

guard_data_prev_slot_button_pos_x = (guard_data_dialog_size_x / 2) - 5 - guard_data_button_size_x - 10
guard_data_prev_slot_button_pos_y = guard_data_dialog_size_y - 70

guard_data_next_slot_button_pos_x = (guard_data_dialog_size_x / 2) + 5 - 10
guard_data_next_slot_button_pos_y = guard_data_prev_slot_button_pos_y

guard_data_output_text_pos_x = 0
guard_data_output_text_pos_y = 0
guard_data_output_text_size_x = guard_data_dialog_size_x
guard_data_output_text_size_y = guard_data_dialog_size_y - 100
guard_data_output_text_width = 7
guard_data_output_text_border = 30
guard_data_output_text_max_length = ((guard_data_output_text_size_x - guard_data_output_text_border) / guard_data_output_text_width)

guard_data_slot_text_pos_x = 10
guard_data_slot_text_pos_y = guard_data_prev_slot_button_pos_y + 5

guard_data_dialog = forms.newform(guard_data_dialog_size_x, guard_data_dialog_size_y, "Guard Data Viewer")
guard_data_prev_slot_button = forms.button(guard_data_dialog, "Prev slot", on_prev_slot, guard_data_prev_slot_button_pos_x, guard_data_prev_slot_button_pos_y, guard_data_button_size_x, guard_data_button_size_y)
guard_data_next_slot_button = forms.button(guard_data_dialog, "Next slot", on_next_slot, guard_data_next_slot_button_pos_x, guard_data_next_slot_button_pos_y, guard_data_button_size_x, guard_data_button_size_y)
guard_data_output_text = forms.label(guard_data_dialog, "", guard_data_output_text_pos_x, guard_data_output_text_pos_y, guard_data_output_text_size_x, guard_data_output_text_size_y, true)
guard_data_slot_text = forms.label(guard_data_dialog, "", guard_data_slot_text_pos_x, guard_data_slot_text_pos_y)

on_update()

event.onframeend(on_update)