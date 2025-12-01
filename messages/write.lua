--!optimize 2
--!native

local cached_stream, message_bitpacks, message_buffs, batched_cursor_and_send_count
local cached_msg_id, message_bitpack, message_buff, message_serializer

local holy = require('../holy')
local outgoing = require('../stream/outgoing')
local bitpack =  require('../misc/bitpack')

local def_size = 32
local metadata = holy._datatype_metadata
local ser = metadata.ser
local new_bitpack = bitpack.new

local function write(msg_id, stream, data)
	if stream ~= cached_stream then
		cached_stream = stream
		message_bitpacks = stream.bitpacks
		message_buffs = stream.buffs
		batched_cursor_and_send_count = stream.batched_cursor_and_send_count
		outgoing.current = stream
	end	
	if msg_id ~= cached_msg_id then
		cached_msg_id = msg_id
		message_serializer = ser[msg_id]

		message_bitpack = message_bitpacks[msg_id]

		if not message_bitpack then
			message_bitpack = new_bitpack()
			message_bitpacks[msg_id] = message_bitpack
		end
		outgoing.bitpack = message_bitpack

		message_buff = message_buffs[msg_id]

		if not message_buff then
			message_buff = buffer.create(def_size)
			message_buffs[msg_id] = message_buff
		end
	end
	
	local cursor_send_count = batched_cursor_and_send_count[msg_id]
	
	if not cursor_send_count then
		cursor_send_count = vector.create(0,0)
	end
	
	local cursor = cursor_send_count.x
	local send_count = cursor_send_count.y
	
	local new_buff
	cursor, new_buff = message_serializer(message_buff, cursor, data)
	
	send_count += 1
	
	if new_buff ~= message_buff then
		message_buffs[msg_id] = new_buff
		message_buff = new_buff
	end
	
	batched_cursor_and_send_count[msg_id] = vector.create(cursor, send_count)
end

return write