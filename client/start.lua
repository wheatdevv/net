local working = false
local RunService = game:GetService('RunService')

local bridges = require('../bridges')
local stream = require('../stream/main')
local global = require('../stream/global')

local reliable = bridges.client.reliable

local export = stream.export

local function start()
	if working then return end
	
	working = true
	RunService.PostSimulation:Connect(function(dt)
		local buff = stream.export(global)
		
		if not buff then return end
		
		local unknown = global.batch_unknown
		
		if next(unknown) then
			reliable.fire_server(unknown, buff)
		else
			reliable.fire_server(buff)
		end
		
		stream.reset(global)
	end)
end

return start