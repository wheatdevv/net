local bridges = require('../../bridges')
local msg_queue = require('../../messages/server_queue')
local import = require('../../stream/import')
local callbacks = msg_queue.callbacks
local insert_many = callbacks.insert_many

local function incoming(client, first:buffer | {unknown}, second:buffer)
	local iterator
	
	if second then
		iterator = import(second, first)
	else
		iterator = import(first)
	end
	
	for msg_id, call_count, queue_data in iterator do
		for i = 1, call_count do
			local callback = callbacks[msg_id]
			if not callback then
				insert_many(callback, client, i, call_count, queue_data)
				
				break
			end
			
			local data = queue_data[i]
			callback(client, data)
		end
	end
end

return function()
	bridges.server.reliable.server_event(incoming)
end