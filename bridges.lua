--!optimize 2
local isclient = game:GetService("RunService"):IsClient()

local function constructor(name, unreliable:boolean?)
	local event:RemoteEvent
	
	if isclient then
		event = game.ReplicatedStorage:WaitForChild(name)
		assert(event:IsA("BaseRemoteEvent"))
	else
		local found =  game.ReplicatedStorage:FindFirstChild(name) 
		if found then
			event = found
		else
			if unreliable then
				event = Instance.new("UnreliableRemoteEvent") :: RemoteEvent
			else
				event = Instance.new("RemoteEvent") :: RemoteEvent
			end
			event.Name = name
			event.Parent = game.ReplicatedStorage
		end
	end
	
	if not event:IsA("BaseRemoteEvent") then
		error('how?')
	end
	
	local impl = {}
	
	function impl.server_event(callback)
		event.OnServerEvent:Connect(callback)
	end
	
	function impl.client_event(callback)
		event.OnClientEvent:Connect(callback)
	end
	
	function impl.fire_server(...)
		event:FireServer(...)
	end
	
	function impl.fire_all(...)
		event:FireAllClients(...)
	end
	
	function impl.fire(client, ...)
		event:FireClient(client, ...)
	end
	
	return impl
end

return {
	client = {
		reliable = constructor("reliable"),
		sync_one = constructor("sync_one"),
		sync_many = constructor("sync_many")
	},
	
	server = {
		reliable = constructor("reliable"),
	}
}