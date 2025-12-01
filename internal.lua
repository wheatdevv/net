local internal = {}
local datatypes = require("./datatypes")
local id = require('./messages/id')
local start, high = id.LOW_MESSAGES_START, id.HIGH_MESSAGES_END
do
	local any = datatypes.range(start, high) :: number
	
	local one = datatypes.struct({
		["1"] = datatypes.str(datatypes.u8), 
		["2"] = any
	})
	
	local many = datatypes.arr(one, datatypes.vlq(3))
	
	internal.one = one
	internal.many = many
end

return internal