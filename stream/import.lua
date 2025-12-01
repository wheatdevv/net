local holy = require('../holy')
local bitpack = require('../misc/bitpack')
local incoming = require('../stream/incoming')

local datatypes = holy.datatypes
local metadata = holy._datatype_metadata
local des = metadata.des
local vlq2 = datatypes.vlq(2)
local vlq2_des = des[vlq2]
local boundary_array_datatype = datatypes.arr(datatypes.u8, vlq2)
local boundary_array_des = des[boundary_array_datatype]
local low_messages_des = des[datatypes.u8]
local high_messages_des = des[datatypes.u16]
local import_byte = bitpack.import_byte
local import = bitpack.import

local function iterator(buff:buffer, unknowns:{unknown})	
	coroutine.yield()
	incoming.unknowns = unknowns
	if unknowns then incoming.unknowns_cursor = 1 end
	
	local cursor,has_boundaries, has_low, has_high = import_byte(buff, 0)
	
	local boundaries = {}
	local boundaries_index = 1
	
	if has_boundaries then
		cursor, boundaries = boundary_array_des(buff, cursor)
	end
	local unpacking:boolean = true
	if has_low then
		local map_length:number
		cursor, map_length = vlq2_des(buff, cursor)
		
		for i = 1, map_length do
			local bound = boundaries[boundaries_index]
			
			if bound then
				if bound > 0 then
					bound -= 1
					boundaries[boundaries_index] = bound
				else
					boundaries_index += 1
					unpacking = not unpacking
				end
			end

			local msg_id:number
			cursor, msg_id = low_messages_des(buff, cursor)

			local send_count:number
			cursor, send_count = vlq2_des(buff, cursor)

			local bitpacker
			if unpacking then
				cursor, bitpacker = import(buff, cursor)
			end
			incoming.bitpack = bitpacker
			
			local msg_deserializer = des[msg_id]
			local data = table.create(send_count)
			
			local msg_data
			for i = 1, send_count do
				cursor, msg_data = msg_deserializer(buff, cursor)
				data[i] = msg_data
			end

			coroutine.yield(msg_id, send_count, data)
		end
	end
	
	if has_high then
		local map_length:number
		cursor, map_length = vlq2_des(buff, cursor)

		for i = 1, map_length do
			local bound = boundaries[boundaries_index]

			if bound then
				if bound > 0 then
					bound -= 1
					boundaries[boundaries_index] = bound
				else
					boundaries_index += 1
					unpacking = not unpacking
				end
			end

			local msg_id:number
			cursor, msg_id = high_messages_des(buff, cursor)

			local send_count:number
			cursor, send_count = vlq2_des(buff, cursor)

			local bitpacker
			if unpacking then
				cursor, bitpacker = import(buff, cursor)
			end
			incoming.bitpack = bitpacker

			local msg_deserializer = des[msg_id]
			local data = table.create(send_count)

			local msg_data
			for i = 1, send_count do
				cursor, msg_data = msg_deserializer(buff, cursor)
				data[i] = msg_data
			end

			coroutine.yield(msg_id, send_count, data)
		end
	end
	
	coroutine.yield()
	error('iterator complete')
end

local function wrap(buff:buffer, unknown:{unknown}?)
	local wrapped = coroutine.wrap(iterator)
	wrapped(buff, unknown)
	
	return wrapped
end

return wrap