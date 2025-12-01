local holy = require('../holy')
local datatypes = require('../datatypes')
local bridges = require('../bridges')
local internal = require('../internal')
local id = require('./id')
local link = require('./link')
local clients = require('../misc/clients')
local msg_queue = require('../messages/server_queue')
local callbacks = msg_queue.callbacks

local metadata = holy._datatype_metadata
local ser_one = metadata.ser[internal.one]
local ser_many = metadata.ser[internal.many]

local bridge_one = bridges.client.sync_one
local bridge_many = bridges.client.sync_many
local read_msg_queue = msg_queue.read

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

local function constructor(msg_name:string, datatype)
	local cached = datatypes.cached(datatype)
	
	local msg_id = id.new()
	link.link_name(msg_name, msg_id)
	link.link_serdes(msg_name, cached)
	
	local cursor, raw_buff = ser_one(buffer.create(8), 0, {
		["1"] = msg_name,
		["2"] = msg_id
	})
	
	local buff = buffer.create(cursor)
	
	buffer.copy(buff, 0, raw_buff, 0, cursor)
	
	bridge_one.fire_all(buff)
	
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

clients.client_added:connect(function(plr)
	local batch = {}
	
	for name, id in link.ids do
		batch[#batch+1] = {
			["1"] = name,
			["2"] = id
		}
	end
	
	local cursor, raw_buff = ser_many(buffer.create(48), 0, batch)
	
	local buff = buffer.create(cursor)

	buffer.copy(buff, 0, raw_buff, 0, cursor)
	
	bridge_many.fire(plr, buff)
end)
return {
	new = constructor,
	
	sync_connection = sync_connection
}