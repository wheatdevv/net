local stream = require('../stream/main')
local clients = require('../misc/clients')
local global = require('../stream/global')
local find = require('../stream/find')
local bridges = require('../bridges')

local reset = {}

local reset_stream = stream.reset
local export = stream.export
local subbed = find.subbed
local streams = find.streams

local reliable = bridges.client.reliable

local function global_replication()
	local buff = export(global)
	
	if not buff then return nil end
	
	local per_client = {}
	
	local batch_unknown_len = global.batch_unknown_len
	local should_insert_unknown = batch_unknown_len > 0
	local batch_unknown = global.batch_unknown
	
	local all_clients = clients.all()
	local num_clients = #clients
	
	if should_insert_unknown then
		for i = 1, num_clients do
			local client = all_clients[i]
			
			per_client[client] = { batch_unknown, buff }
		end
	else
		for i = 1, num_clients do
			local client = all_clients[i]
			
			per_client[client] = { buff }
		end
	end
	
	table.insert(reset, global)
	
	return per_client
end

local RunService = game:GetService("RunService")
local function start()
	RunService.PreSimulation:Connect(function()
		local per_client = global_replication() or {}
		
		for count, client_sets in subbed do
			local mapped = streams[count]
			
			for i = 1, #client_sets do
				local outgoing_stream = mapped[i]
				local buff = export(outgoing_stream)
				if not buff then continue end
				table.insert(reset, outgoing_stream)
				
				local batch_unknown_len = outgoing_stream.batch_unknown_len
				local should_insert_unknown = batch_unknown_len > 0
				local batch_unknown = outgoing_stream.batch_unknown

				local stream_client_set = client_sets[i]

				for client in stream_client_set do
					local send_list = per_client[client]
					if send_list == nil then
						send_list = {}
						per_client[client] = send_list
					end

					if should_insert_unknown then table.insert(send_list, batch_unknown) end

					table.insert(send_list, buff)
				end
			end
		end
		
		for client, tbl in per_client do
			print('doing sm')
			reliable.fire(client, unpack(tbl))
		end
		
		local _, first = next(reset)
		if not first then return end
		
		reset_stream(first)
		reset[1] = nil
		
		for i = 2, #reset do
			reset_stream(reset[i])
			reset[i] = nil
		end
	end)
end

return start