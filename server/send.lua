local write = require('../messages/write')
local find = require('../stream/find')

local per_client = find.per_client
return function(msg_id, to:Player, data)
	local stream = per_client[to]
	if stream then
		write(msg_id, stream, data)
	end
end