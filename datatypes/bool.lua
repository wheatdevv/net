--!optimize 2
--!native
local holy = require('../holy')

local bool_type = holy.new_datatype()
local outgoing = require('../stream/outgoing')
local incoming = require('../stream/incoming')

local metadata = holy._datatype_metadata

local bitpack = require('../misc/bitpack')

local bitpack_read = bitpack.read
local push_true = bitpack.push_true
local push_false = bitpack.push_false

function bool_ser_io(buff, cursor, bool)
	do 
		local len = buffer.len(buff)
		local target = cursor+1
		
		if target > len then
			local old_buff = buff
			len*=2
			buff = buffer.create(len)
			buffer.copy(buff, 0, old_buff, 0, cursor)
		end
	end
	
	buffer.writeu8(buff, cursor, bool and 1 or 0)
	return cursor+1, buff
end

function bool_des_io(buff, cursor)
	return cursor+1, buffer.readu8(buff, cursor)
end

function bool_ser(buff, cursor, bool)
	if outgoing.io then return bool_ser_io() end
	
	if bool then
		push_true(outgoing.bitpacker)
	else
		push_false(outgoing.bitpacker)
	end
	
	return cursor, buff
end

function bool_des(buff, cursor)
	if incoming.io then return bool_des_io() end
	
	return cursor, bitpack_read(incoming.bitpacker)
end

metadata.ser[bool_type] = bool_ser
metadata.des[bool_type] = bool_des

return bool_type