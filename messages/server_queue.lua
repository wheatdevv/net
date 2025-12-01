local server_queue = {}

local msg_queue = {}
server_queue.callbacks = {}
function server_queue.read(msg_id)
	local queue = msg_queue[msg_id]
	
	if not queue then
		return function()
			
		end
	end
	
	return function()
		local length = queue[1]
		
		local clients = queue[2]
		local data = queue[3]
		
		local client = table.remove(clients, 1)
		local removed_data = table.remove(data, 1)
		
		length -= 1
		queue[1] = length
		
		return client, removed_data
	end
end

function server_queue.insert_many(msg_id, client:Player, insert_start, insert_end, data_tbl)
	local queue = msg_queue[msg_id]
	
	local range = insert_end - insert_start + 1

	local client_table = table.create(range, client)
	
	if not queue then
		local queued_data = table.create(range)
		table.move(data_tbl, insert_start, insert_end, 1, queued_data)

		msg_queue[msg_id] = {
			range,
			client_table,
			queued_data,
		}
		
		return
	end
	
	local length = queue[1]
	length += 1
	
	table.move(data_tbl, insert_start, insert_end, length, queue[3])
	table.move(client_table, 1, range, length, queue[2])
	
	length += range
	queue[1] = length
	
	return
end

return server_queue