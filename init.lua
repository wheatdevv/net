local lib = {}

local msgs_shared = require('@self/messages/shared')
local container = require('@self/messages/container')
local bridghes = require('@self/bridges')

lib.shared = {
	new = msgs_shared.new,
}

lib.client = {
	send = require('@self/client/send'),
	start = require('@self/client/start'),
	sync = msgs_shared.sync_connection,
}
lib.server = {
	send = require('@self/server/send'),
	start = require('@self/server/start'),
	broadcast_to_all = require('@self/server/broadcast_to_all'),
	sync = msgs_shared.sync_connection,
}

lib.datatypes = require('@self/datatypes')
lib.container = container

local isServer = game:GetService("RunService"):IsServer()

local client_reliable = require('@self/incoming/client/reliable')
local server_reliable = require('@self/incoming/server/reliable')

if isServer then
	server_reliable()
else
	client_reliable()
end
return lib