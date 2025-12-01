local write = require('../messages/write')
local global = require('../stream/global')

return function(msg_id, data)
	write(msg_id, global, data)
end