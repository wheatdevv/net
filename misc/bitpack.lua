--!native
--!optimize 2

local holy = require('../holy')

local metadata = holy._datatype_metadata
local uint_size = holy.uint_size
local vlq_size = holy.vlq_size
local lookup_uint_ser_static = holy.const_lookups.uint.ser_static

local vlq = holy.datatypes.vlq(2)
local ser_vlq = metadata.ser[vlq]
local des_vlq = metadata.des[vlq]

local function new()
	return {
		pages = {},
		increment = 1,
		current = 0,
	}
end

local function push_true(packer: any): ()
	local increment = packer.increment

	packer.current += increment

	if increment < 2 ^ 32 then
		packer.increment = increment * 0b10
	else
		table.insert(packer.pages, packer.current)

		packer.increment = 1
		packer.current = 0
	end
end

local function push_false(packer: any): ()
	local increment = packer.increment

	if increment < 2 ^ 32 then
		packer.increment = increment * 0b10
	else
		table.insert(packer.pages, packer.current)

		packer.increment = 1
		packer.current = 0
	end
end

local function push(packer: any, bool: boolean): ()
	(bool and push_true or push_false)(packer)
end

local function evaluate_pages(packer: any): number
	return #packer.pages * 4
end

local function evaluate_remainder(packer: any): number
	local next_increment = packer.increment

	if next_increment == 0b1 then return 0 end

	local current_increment = next_increment / 0b10

	return uint_size(current_increment)
end

function evaluate_packer(packer:any): number
	local pages = #packer.pages * 4
	local remainder = evaluate_remainder(packer)
	
	return pages + remainder
end

local function contains_anything(packer:any)
	return packer.increment ~= 1 or #packer.pages > 0
end

local function export(buff: buffer, cursor: number, packer: any): (number, buffer)
	local pages_bytes = evaluate_pages(packer)
	local remainder_bytes = evaluate_remainder(packer)

	local data_bytes = pages_bytes + remainder_bytes

	cursor, buff = ser_vlq2(buff, cursor, data_bytes)

	local u32_pages = packer.pages

	local u32_pages_len = #u32_pages

	for i = 1, u32_pages_len do
		buffer.writeu32(buff, cursor, u32_pages[i])
		cursor += 4
	end

	if remainder_bytes > 0 then
		lookup_uint_ser_static[remainder_bytes](buff, cursor, packer.current)
		cursor += remainder_bytes
	end

	return cursor, buff
end

local import
local import_byte
do
	local bitfield_const_lookup = table.create((2 ^ 8 - 1)) :: { [number]: { [number]: boolean } }
	do
		local outer_index = 0
		for encoded = 0, 2 ^ 8 - 1 do
			local inner_tbl = table.create(8) :: { boolean }
			local inner_index = 1

			for test_exp = 0, 7 do
				inner_tbl[inner_index] = bit32.btest(encoded, 2 ^ test_exp)
				inner_index += 1
			end

			bitfield_const_lookup[outer_index] = inner_tbl

			outer_index += 1
		end
	end

	function import(buff: buffer, cursor: number): (number, any)
		local byte_count
		cursor, byte_count = des_vlq2(buff, cursor)

		local bits_output = table.create(byte_count * 8) :: { true | false }
		local output_index = 1

		local encoded: number
		for byte = 0, byte_count - 1 do
			encoded = buffer.readu8(buff, cursor)
			cursor += 1

			table.move(bitfield_const_lookup[encoded], 1, 8, output_index, bits_output)

			output_index += 8
		end

		return cursor, {
			pages = bits_output,
			read_index = 1,
		}
	end

	function import_byte(
		buff: buffer,
		cursor: number
	): (
		number,
		boolean,
		boolean,
		boolean,
		boolean,
		boolean,
		boolean,
		boolean,
		boolean
		)
		local decoded = buffer.readu8(buff, cursor)
		cursor += 1

		local decoded_tbl = bitfield_const_lookup[decoded]
		
		return cursor,
		decoded_tbl[1],
		decoded_tbl[2],
		decoded_tbl[3],
		decoded_tbl[4],
		decoded_tbl[5],
		decoded_tbl[6],
		decoded_tbl[7],
		decoded_tbl[8]
	end
end

local function read(unpacker: UnpackerIdentity): boolean
	local read = unpacker.read_index

	unpacker.read_index = read + 1

	local output = unpacker.pages[read]

	return output
end

return {
	new = new,
	reset = reset,
	push_false = push_false,
	push_true = push_true,
	push = push,
	evaluate_array = evaluate_array,
	evaluate_remainder = evaluate_remainder,
	evaluate_packer = evaluate_packer,
	contains_data = contains_anything,
	export = export,
	import = import,
	import_byte = import_byte,
	read = read,
}