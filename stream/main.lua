--!native

type MessageId = number

export type Stream = {
	read buffs: { [MessageId]: buffer },
	read bitpacks: { [MessageId]: any },

	read batched_cursor_and_send_count: { [MessageId]: vector },
	read batch_unknown: { unknown },
	batch_unknown_len: number,
}

local id = require('../messages/id')
local holy = require('../holy')
local bitpack = require('../misc/bitpack')
local clients = require('../misc/clients')

local low_msg_end = id.LOW_MESSAGES_END

local send_buff, send_cursor

local vlq_size = holy.vlq_size
local metadata = holy._datatype_metadata
local has_data = bitpack.contains_data
local evaluate_packer = bitpack.evaluate_packer

local datatypes = holy.datatypes
local vlq2 = datatypes.vlq(2)
local vlq2_ser = metadata.ser[vlq2]
local boundary_array_datatype = datatypes.arr(datatypes.u8, vlq2)
local boundary_array_ser = metadata.ser[boundary_array_datatype]
local low_messages_ser = metadata.ser_no_realloc[datatypes.u8]
local high_messages_ser = metadata.ser_no_realloc[datatypes.u16]
local export_bitpack = bitpack.export

local function constructor() : Stream
	return {
		buffs = {},
		bitpacks = {},

		batched_cursor_and_send_count = {},
		batch_unknown = {},
		batch_unknown_len = 0
	}
end

local allocated = 0

local function get_id_maps(batched_cursor_and_send_count : {[number] : vector})
	local empty = next(batched_cursor_and_send_count) == nil
	if empty then return end

	local low = {}
	local low_len = 0
	local high = {}
	local high_len = 0

	for msg_id, cursor_and_send_count in batched_cursor_and_send_count do
		if msg_id <= low_msg_end then
			low_len += 1
			low[low_len] = msg_id
			allocated += 1 -- u8
		else
			high_len += 1
			high[high_len] = msg_id
			allocated += 2 -- u16
		end

		local cursor = cursor_and_send_count.x
		local send = cursor_and_send_count.y

		allocated += vlq_size(send)
		allocated += cursor
	end

	local low_exists = low_len > 0
	local high_exists = high_len > 0

	if low_exists then allocated += vlq_size(low_len) end
	if high_exists then allocated += vlq_size(high_len) end

	return low_exists and low or nil, high_exists and high or nil
end

local function get_boundaries(msg_bitpacks, low, high)
	local boundary_array = {}
	local boundary_array_len = 0

	local contains_bitpack = false
	local len = 0

	if low ~= nil then
		local low_len = #low
		for i = 1, low_len do
			local id = low[i]
			local bitpacker = msg_bitpacks[id]
			local contains = bitpacker and has_data(bitpacker) or false
			if contains then
				allocated += evaluate_packer(bitpacker)
			end
			if contains then
				len += 1
			else
				contains_bitpack = contains
				boundary_array_len += 1
				boundary_array[boundary_array_len] = len
				len = 0
			end
		end
	end

	if high ~= nil then
		local high_len = #high
		for i = 1, high_len do
			local id = high[i]
			local bitpacker = msg_bitpacks[id]
			local contains = bitpacker and has_data(bitpacker) or false
			if contains then
				allocated += evaluate_packer(bitpacker)
			end
			if contains then
				len += 1
			else
				contains_bitpack = contains
				boundary_array_len += 1
				boundary_array[boundary_array_len] = len
				len = 0
			end
		end
	end

	if boundary_array_len == 0 then return end

	return boundary_array
end

local function opts(
	first: boolean?,
	second: boolean?,
	third: boolean?,
	fourth: boolean?,
	fifth: boolean?,
	sixth: boolean?,
	seventh: boolean?,
	eighth: boolean?
): ()
	local output = 0
	if first then
		output += 0b1
	end
	if second then
		output += 0b10
	end
	if third then
		output += 0b100
	end
	if fourth then
		output += 0b1000
	end
	if fifth then
		output += 0b10000
	end
	if sixth then
		output += 0b100000
	end
	if seventh then
		output += 0b1000000
	end
	if eighth then
		output += 0b10000000
	end
	buffer.writeu8(send_buff :: buffer, send_cursor :: number, output)
	send_cursor += 1
end

local function export(stream:Stream)
	allocated = 1
	local batched_cursor_and_send_count = stream.batched_cursor_and_send_count

	local low, high = get_id_maps(batched_cursor_and_send_count)

	if not low and not high then return end
	local bitpacks = stream.bitpacks
	
	local boundaries = get_boundaries(bitpacks, low, high)
	local boundaries_exist = boundaries ~= nil

	if boundaries_exist then
		local boundaries_len = #boundaries

		allocated += vlq_size(boundaries_len)

		for i = 1, boundaries_len do
			local bound = boundaries[i]

			allocated += vlq_size(bound)
		end
	end

	send_buff = buffer.create(allocated)
	send_cursor = 0

	local low_messages_exist = low ~= nil
	local high_messages_exist = high ~= nil
	
	opts(boundaries_exist, low_messages_exist, high_messages_exist)
	
	if boundaries_exist then
		local new_send_cursor, new_send_buff = boundary_array_ser(send_buff, send_cursor, boundaries)
		
		if new_send_buff ~= send_buff then
			holy.stfu_check()
			error('boundaries reallocated buffer')
		end
		
		send_cursor = new_send_cursor
	end
	
	local msg_buffs = stream.buffs
	
	local new_buff
	
	if low_messages_exist then
		local msg_ids = low
		local ids_len = #msg_ids
		send_cursor, new_buff = vlq2_ser(send_buff, send_cursor, ids_len)
		
		if new_buff ~= send_buff then
			holy.stfu_check()
			error('low_ser reallocated')
		end
		
		for i = 1, ids_len do
			local id = msg_ids[i]
			send_cursor = low_messages_ser(send_buff, send_cursor, id)
			
			local message_buff = msg_buffs[id]
			
			local cursor_and_send_count = batched_cursor_and_send_count[id]
			
			local cursor = cursor_and_send_count.x
			local send_count = cursor_and_send_count.y
			
			send_cursor, new_buff = vlq2_ser(send_buff, send_cursor, send_count)
			
			local bitpack = bitpacks[id]
			
			if has_data(bitpack) then
				send_buff, new_buff = export_bitpack(send_buff, send_cursor, bitpack)
			end
			
			if new_buff ~= send_buff then
				holy.stfu_check()
				error('reallocated while writing msg_id', id)
			end
			
			buffer.copy(send_buff, send_cursor, message_buff, 0, cursor)
			send_cursor += cursor
		end
	end
	if high_messages_exist then
		local msg_ids = high
		local ids_len = #msg_ids

		send_cursor, new_buff = vlq2_ser(send_buff, send_cursor, ids_len)

		if new_buff ~= send_buff then
			holy.stfu_check()
			error('high_ser reallocated')
		end

		for i = 1, ids_len do
			local id = msg_ids[i]
			send_cursor = high_messages_ser(send_buff, send_cursor, id)

			local message_buff = msg_buffs[id]

			local cursor_and_send_count = batched_cursor_and_send_count[id]

			local cursor = cursor_and_send_count.x
			local send_count = cursor_and_send_count.y

			send_cursor, new_buff = vlq2_ser(send_buff, send_cursor, send_count)

			local bitpack = bitpacks[id]

			if has_data(bitpack) then
				send_buff, new_buff = export_bitpack(send_buff, send_cursor, bitpack)
			end

			if new_buff ~= send_buff then
				holy.stfu_check()
				error('reallocated while writing msg_id', id)
			end

			buffer.copy(send_buff, send_cursor, message_buff, 0, cursor)
			send_cursor += cursor
		end
	end
	return send_buff
end

local function reset(stream:Stream)
	table.clear(stream.batch_unknown)
	stream.batch_unknown_len = 0
	
	table.clear(stream.batched_cursor_and_send_count)
end


return {
	new = constructor,
	export = export,
	reset = reset,

	per_client = per_client,
}