--!optimize 2
local holy = require('../holy')
local datatypes = require('../datatypes')

local metadata = holy._datatype_metadata
local message_names = {}
local message_ids = {}
local message_ser = {}
local message_des = {}

local function link_name(id, name)
	message_names[name] = id
	message_ids[id] = name
end

local function link_serdes(msg_name, inp)
	local cached = datatypes.cached(inp)
	
	if holy.check_datatype_exists(cached) == false then
		error('u didnt define the msg!!')
	end
	
	local msg_id = message_ids[msg_name]
	if not msg_id then
		error('no msg id with name')
	elseif message_ser[msg_id] then
		error('already linked ser')
	elseif message_des[msg_id] then
		error('already linked des')
	end
	
	holy.copy_datatype(cached, msg_id)
	
	message_ser[msg_id] = metadata.ser[msg_id]
	message_des[msg_id] = metadata.des[msg_id]
end

return {
	link_name = link_name,
	link_serdes = link_serdes,
	
	names = message_names,
	ids = message_ids,
	ser = message_ser,
	des = message_des
}