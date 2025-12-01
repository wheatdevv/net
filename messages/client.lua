--!optimize 2
local holy = require('../holy')
local link = require('./link')
local bridges = require('../bridges')
local internal = require('../internal')
local datatypes = require('../datatypes')
local msg_queue = require('../messages/client_queue')
local callbacks = msg_queue.callbacks

local metadata = holy._datatype_metadata
local read_msg_queue = msg_queue.read
local des_one = metadata.des[internal.one]
local des_many = metadata.des[internal.many]

local open_threads = {}
local spawner

do
	local function runner(func, ...)
		local thread = table.remove(open_threads)
		func(...)
		table.insert(open_threads, thread)
	end

	local function spawner(func, ...)
		func(...)

		while true do
			runner(coroutine.yield())
		end
	end

	for i = 1, 8 do
		open_threads[i] = coroutine.create(spawner)
	end
end

local awaiting = {}
local function msg_constructor(n:string, datatype)
	local cached = datatypes.cached(datatype)
	
	local msg_id = link.ids[n]
	
	if msg_id ~= nil then
		link.link_serdes(n, cached)
		return msg_id
	end
	
	do
		local waiting_thread = awaiting[n]
		
		if waiting_thread ~= nil then
			error('msg is being awaited')
		end
		
		local running = coroutine.running()
		
		awaiting[n] = running
		
		msg_id = coroutine.yield()
	end
	
	link.link_serdes(n, cached)
	
	return msg_id
end

local function sync_connection(msg_id, callback)
	local existing = callbacks[msg_id]
	
	if existing then
		error("msg already has a connection")
	end
	
	callbacks[msg_id] = callback
	
	for _, queue_data in read_msg_queue(msg_id) do
		task.spawn(table.remove(open_threads), callback, queue_data)
		callback = callbacks[msg_id]
		if not callback then break end
	end
end

local function sync_from_remote(arr)
	local msg_name = arr["1"]
	local msg_id = arr["2"]
	
	link.link_name(msg_name, msg_id)
	
	local waiting_thread = awaiting[msg_name]
	
	if waiting_thread then
		task.spawn(waiting_thread, msg_id)
		awaiting[msg_name] = nil
	end
end

bridges.client.sync_one.client_event(function(buff)
	local _, arr = des_one(buff, 0)
	sync_from_remote(arr)
end)

bridges.client.sync_many.client_event(function(buff)
	local _, list = des_many(buff, 0)
	
	for _, arr in list do
		sync_from_remote(arr)
	end
end)

return {
	new = msg_constructor,
	
	sync_connection = sync_connection,
}