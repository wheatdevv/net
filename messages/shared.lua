local runService = game:GetService("RunService")
local isServer = runService:IsServer()

if isServer then
	local server = require('./server')
	return server
else
	local client = require('./client')
	return client
end