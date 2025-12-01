local LOW_MESSAGES_START = 30 -- starts after serdes
local LOW_MESSAGES_END = 255 -- max of u8
local HIGH_MESSAGES_START = LOW_MESSAGES_END + 1
local HIGH_MESSAGES_END = 65_535 -- max of u16

local cur_id = LOW_MESSAGES_START
local function new()
	local new_id = cur_id
	
	if new_id > HIGH_MESSAGES_END then
		error('max events reached, why exactly do you need', HIGH_MESSAGES_END)
	end
	
	cur_id += 1
	return new_id
end

return {
	new = new,
	
	LOW_MESSAGES_START = LOW_MESSAGES_START,
	LOW_MESSAGES_END = LOW_MESSAGES_END,
	
	HIGH_MESSAGES_END = HIGH_MESSAGES_END,
	HIGH_MESSAGES_START = HIGH_MESSAGES_START
}