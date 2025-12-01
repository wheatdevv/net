--!native
local clients = {}

local luausignal = require('./luausignal')

export type Identity = Player

export type ApiIdentity = {
	local_client: Identity,

	all: () -> { Identity },
	is_connected: { [Identity]: true? },

	client_added: luausignal.Identity<Identity>,
	client_removed: luausignal.Identity<Identity>,
}


local is_connected = {}
clients.is_connected = setmetatable(is_connected, {
	__index = function(_, plr:Player)
		return plr:IsDescendantOf(game.Players)
	end,
})
clients.client_removed = luausignal() :: luausignal.Identity<Identity>
clients.client_added = luausignal() :: luausignal.Identity<Identity>

local Players = game.Players
local get_players = Players.GetPlayers

Players.ChildAdded:Connect(function(plr)
	if not plr:IsA("Player") then
		return
	end
	is_connected[plr] = true
	clients.client_added:fire(plr)
end)

Players.ChildRemoved:Connect(function(plr)
	if not plr:IsA("Player") then return end
	is_connected[plr] = nil
	clients.client_removed:fire(plr)
end)

function clients.all() : { Identity }
	return get_players(Players)
end

return clients :: ApiIdentity