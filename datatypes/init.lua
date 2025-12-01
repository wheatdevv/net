--!optimize 2
local holy = require('./holy')
local bool = require('@self/bool')

local function cached<inp>(inp) : any
	local input_type = type(inp)
	if input_type ~= 'table' then
		if holy.check_datatype_exists(inp) then return inp end
	end
	
	local first_index, first_value = next(inp)
	
	if first_index == 1 then return holy.datatypes.arr(cached(first_value)) end
	
	if type(first_index) == 'string' then
		local out = table.clone(inp)
		
		for key, value in inp do
			out[key] = cached(value)
		end
		
		return holy.datatypes.struct(out)
	end
	
	local cached_first_index = cached(first_index)
	
	local type_first_index = type(cached_first_index)
	
	if type_first_index == "number" or type_first_index == "vector" then
		return holy_datatypes.map(cached_first_index, cached(first_value))
	end
end

return {
	cached = cached,
	bool = bool,
	
	vlq = holy.datatypes.vlq,
	
	u8 = holy.datatypes.u8,
	u16 = holy.datatypes.u16,
	u32 = holy.datatypes.u32,
	f32 = holy.datatypes.f32,
	f64 = holy.datatypes.f64,
	range = holy.datatypes.range,
	
	str = holy.datatypes.str,
	
	vect3 = holy.datatypes.vect3,
	
	arr = holy.datatypes.arr,
	struct = holy.datatypes.struct,
}