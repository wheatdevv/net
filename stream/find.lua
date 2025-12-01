--!native
local clients = require('../misc/clients')
local stream = require('../stream/main')

local subbed = {}
local streams = {}
local new_stream = stream.new
local is_connected = clients.is_connected

clients.client_removed:connect(function(plr)
	for count, stream_sets in subbed do
		local mapped = streams[count]
		
		for i = #stream_sets, 1, -1 do
			local client_set = stream_sets[i]
			client_set[plr] = nil
			
			local isnt_empty = next(client_set)
			
			if isnt_empty then continue end
			
			table.remove(client_set, i)
			table.remove(mapped, i)
		end
	end
end)

local function new_stream(clients:{Player})
	local len = #clients
	
	if len == 0 then return end
	
	local set = {}
	
	for i = 1, len do
		local client = clients[i]
		
		if is_connected[client] then
			set[client] = true
		end
	end
	
	local client_sets = subbed[len]
	
	if not client_sets then
		client_sets = {}
		subbed[len] = client_sets
	end
	
	local mapped = streams[len]
	
	if not mapped then
		mapped = {}
		streams[len] = mapped
	end
	
	local new = #client_sets+1
	
	local _stream = stream.new()
	
	client_sets[new] = set
	mapped[new] = _stream
	
	return _stream
end

local function find(clients: {Player}) : stream.Stream?
	local len = #clients
	if len == 0 then return end
	
	local client_sets = subbed[len]
	
	if not client_sets then
		client_sets = {}
		subbed[len] = client_sets
		-- nothing to query
		return new_stream(clients)
	end
	
	local client_sets_len = #client_sets
	
	for i = 1, client_sets_len do
		local set = client_sets[i]
		
		local matches_all = true
		
		for j = len, 1, -1 do
			local client = clients[j]
			
			if not is_connected[client] then continue end
			
			if set[client] ~= true then
				matches_all = false
				break
			end
		end
		
		if not matches_all then continue end
		
		local mapped = streams[len]
		
		return mapped[i]
	end
	
	return new_stream(clients)
end

local per_client = setmetatable({}, {
	__index = function(t, plr)
		if is_connected[plr] then
			local new = new_stream({ plr })
			t[plr] = new
			return new
		end
	end,
})

clients.client_removed:connect(function(plr)
	per_client[plr] = nil
end)

return {
	per_client = per_client,
	find = find,
	
	subbed = subbed,
	streams = streams,
}