local bridges = require('../../bridges')
local import = require('../../stream/import')
local client_queue = require('../../messages/client_queue')

local callbacks = client_queue.callbacks
local insert_many = client_queue.insert_many

local function process_incoming(buff:buffer, unknowns)
	for msg_id, call_count, data in import(buff, unknowns) do
		for i = 1, call_count do
			local callback = callbacks[msg_id] :: (any) -> ()
			
			if not callback then
				insert_many(msg_id, i, call_count, data)
				
				break
			end
			
			local msg_data = data[i]
			callback(msg_data)
		end
	end
end

local function on_incoming_reliable(...)
	local read = 1
	
	while true do
		local bridge_data, next_data = select(read, ...)
		read += 1
		
		local ty = type(bridge_data)
		
		if ty == "nil" then break end
		
		if ty == "buffer" then 
			process_incoming(bridge_data)
			continue
		end
		
		if ty ~= 'table' then
			error('expected table got', ty)
		end
		
		if next_data ~= 'buffer' then
			error('expected buffer got', ty)
		end
		
		process_incoming(next_data, bridge_data)
	end
end

local function init()
	bridges.client.reliable.client_event(on_incoming_reliable)
end

return init