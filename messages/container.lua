local _shared = require('./shared')

local new = _shared.new

local n_id = 0
local function container<T>(map:{[T] : any}) : { [T] : number}
	n_id += 1
	
	local _container = {}
	
	for name, idk in map do
		_container[name] = new(`{n_id}{name}`, idk)
	end
	
	return _container
end

return container