local msg_queue = {}
local queue_data = {}

local client_queue = {
	callbacks = {}
}

-- TODO: change this to SoA

function client_queue.read(msg_id:number)
	local queue = msg_queue[msg_id]
	
	if not queue then
		return function()
			return nil, nil
		end
	end
	
	return function()
		local length = queue[1]
		
		if length <= 0 then
			msg_queue[msg_id] = nil
			return nil, nil
		end
		
		local data_index = queue[2]
		local data = queue_data[data_index]
		
		local removed = table.remove(data)
		queue[1] -= 1
		
		return true, removed
	end
end

function client_queue.insert(msg_id, data)
	local queue = msg_queue[msg_id]
	
	if not queue then
		queue = { 1, #queue_data+1 }
		msg_queue[msg_id] = queue
		return
	end
	
	local len = queue[1]
	local data_idx = queue[2]
	
	len += 1
	queue[1] += 1
	queue_data[data_idx] = data
end

function client_queue.insert_many(msg_id, insert_start, insert_end, data)
	local queue = msg_queue[msg_id]
	
	if not queue then
		local idx = #queue_data+1
		queue = { 0, idx }
		queue_data[idx] = {}
		msg_queue[msg_id] = queue
	end
	
	local length = queue[1]
	local data_idx = queue[2]
	local queue_data = queue_data[data_idx]
	
	table.move(data, insert_start, insert_end, length + 1, queue_data)
	
	length += insert_end - insert_start + 1
	queue[1] = length
end

return client_queue