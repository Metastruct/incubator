-- luacheck: globals _M SERVER, new globals dbg_clear _M verbose on_chunk_update net_send_chunkmsg panic Tick net_acknowledge_msg queue_chunk net_BytesLeft send get_db get_queue NewChunk want_aid net_proc_chunkmsg want_player msg_add msg_ack recalculate_chunk SERVER dbg_msg_getter msg_get_next broadcast_chunk
local ___CLEAN_UP_STATE = true
local TEST = false
local TEST_LOSS = false -- test packet loss 
local Tag = 'draw3d'
module(Tag, package.seeall)

local _RAW = setmetatable({}, {
	__index = function(_, k) return rawget(_M, k) end,
	__newindex = _M
})

verbose = _RAW.verbose or false

if TEST then
	verbose = true
end

local function dbg(a, ...)
	if not verbose then return end
	Msg('[' .. Tag .. '] ')
	a = tostring(a)
	local hue = tonumber(util.CRC(tostring(a)))
	local saturation, value = hue % 3 == 0, hue % 127 == 0
	local col = HSVToColor(hue % 180 * 2, saturation and 0.3 or 0.6, value and 0.6 or 1)
	MsgC(col, ("%24s\t"):format(a))
	print(...)
end

local _ = (___CLEAN_UP_STATE) and _RAW.dbg_clear and dbg_clear()
local _ = SERVER and util.AddNetworkString(Tag)
local MSG_bits = 4
local MSGN_bits = 24
local CHUNK_bits = 7
local COLOR_bits = 8
local MAX_CHUNKS = 2 ^ CHUNK_bits - 1
local MSG_CHUNK = 1
local MSG_CHUNK_UPDATE = 2
local MSG_ACK_MSG = 3
local MSG_FULLUPDATE = 4
local MAX_VERTS = 128
local VERTS_bits = math.ceil(math.log(MAX_VERTS, 2)) + 1 -- TODO: fixme

local function NET_MSG(msg_type, unreliable)
	assert(msg_type <= MSG_FULLUPDATE)
	net.Start(Tag, unreliable)
	net.WriteUInt(msg_type, MSG_bits)
end

local function WriteVertex(color, pos)
	if not pos then
		if color == false then
			net.WriteUInt(0, COLOR_bits)

			return
		end

		if not istable(color) then
			error("WriteVertex #1 not a table: " .. tostring(color), 2)
		end

		pos = color[2]
		color = color[1]
	end

	if not isnumber(color) then
		error("WriteVertex() invalid param 1: " .. tostring(color))
	end

	if color <= 0 then
		error("color cannot be below 1", 2)
	end

	assert(isvector(pos), "pos is not vector")
	net.WriteUInt(color + 1, COLOR_bits) -- color
	net.WriteVector(pos) -- pos
end

local net_BytesLeft_startnum
local net_BytesLeft_msglen

local function net_BitsLeft()
	local r = net.BytesLeft()

	return r
end

local function net_BytesLeft()
	local _, hmmm = net.BytesLeft()
	if CLIENT then return _, hmmm end
	local bits = net_BytesLeft_msglen - (net_BytesLeft_startnum - hmmm)

	return bits / 8
end

function want_player(accountid)
	if isnumber(accountid) then
		assert(accountid <= 2 ^ 31)

		return player.GetByAccountID(accountid)
	end

	return accountid
end

function want_aid(accountid)
	if isnumber(accountid) then
		assert(accountid <= 2 ^ 31)

		return accountid
	end

	return accountid:AccountID()
end

do
	function NewChunk()
		local chunk = {Vector(0, 0, 0), Vector(0, 0, 0), Vector(0, 0, 0), 0}

		chunk._verts = {}

		return chunk
	end

	function recalculate_chunk(chunk)
		assert(chunk, 'recalculate_chunk() no chunk')
		chunk[1] = 'obbmin'
		chunk[2] = 'obbmax'
		chunk[3] = 'center'
		chunk[4] = 'centersize'
	end
end

local message_queue = SERVER and (_RAW.get_queue and _RAW.get_queue() or {})

if SERVER then
	local function NewMsgQueue()
		local ack_pos, msg_counter = 0, 0
		local msgs = {}

		local q = {msgs, ack_pos, msg_counter}

		return q
	end

	function get_queue()
		return message_queue
	end

	function msg_add(aid, msg)
		local q = message_queue[aid]

		if not q then
			q = NewMsgQueue()
			message_queue[aid] = q
		end

		local msgs = q[1]
		local ack_pos = q[2]
		local msg_counter = q[3] + 1
		q[3] = msg_counter

		table.insert(msgs, {msg_counter, msg})
	end

	function msg_ack(aid, msg_num)
		local q = message_queue[aid]

		if not q then
			dbg("msg_ack()", "NO QUEUE!!!!", aid, want_player(aid))

			return
		end

		local msgs = q[1]
		local old_ack_pos = q[2]
		local ack_pos = msg_num
		local msg_counter = q[3]

		for i = 1, #msgs do
			local msg_n = msgs[i][1]
			ack_pos = math.min(ack_pos, msg_n)

			if msg_n == msg_num then
				table.remove(msgs, i)
				break
			end
		end

		dbg('msg_ack()', want_player(aid), 'msg_num=', msg_num, 'ack_pos=', ack_pos, '<- old_ack_pos=', old_ack_pos, 'msg_counter=', msg_counter)
		q[2] = ack_pos
	end

	function msg_get_next(aid, no_dithering)
		local q = message_queue[aid]
		if not q then return end
		local msgs = q[1]
		local ack_pos = q[2]
		local i = no_dithering and 1 or math.random(math.min(#q, 5))
		--TODO: allow slow resubmit if it's the same message every time?
		local wrapped = msgs[i]
		if not wrapped then return end -- no messages
		local msg_n = wrapped[1]
		local msg = wrapped[2]

		if msg_n <= ack_pos then
			local msg = '[draw3d] msg not removed, was acknowledged??: ' .. ' ack_pos=%s msg_n=%s pl=%s'
			msg = msg:format(ack_pos, msg_n, want_player(aid))
			dbg(msg)
			--ErrorNoHalt(msg)
		end

		return msg, msg_n
	end
end

local db = {
	pl1 = {
		{
			"TODO obbmin",
			"TODO obbmax",
			"TODO obbcenter",
			"TODO size",
			{Vector(1, 2, 3), 0, Vector(1, 2, 3), 0, Vector(1, 2, 3), 0}
		},
'...'
	}
}

local db = _RAW.get_db and get_db() or setmetatable({}, {
	__index = function(self, k)
		local chunks = {}
		self[k] = chunks

		return chunks
	end
})

function get_db()
	return db
end

local CHUNK_VERTS_POS = 5
api = _RAW.api or {}

if CLIENT then
	function send(chunk_pos, verts, chunk_update, pl, reliable)
		assert(pl == nil, "cannot send pl from client")
		assert(not chunk_update or istable(chunk_update), "Provide table in chunk_update")
		dbg('send()', 'chunk_pos=', chunk_pos, '#verts=', verts and table.Count(verts), "#chunk_update=", chunk_update and table.Count(chunk_update))
		reliable = false
		NET_MSG(chunk_update and MSG_CHUNK_UPDATE or MSG_CHUNK, reliable ~= true)
		net.WriteUInt(chunk_pos, CHUNK_bits)

		if chunk_update then
			assert(not verts)

			for vertex_id, vertex in pairs(chunk_update) do
				net.WriteUInt(vertex_id + 1, VERTS_bits)
				WriteVertex(vertex)
			end

			net.WriteUInt(0, VERTS_bits)
		else
			--PrintTable(verts)
			for i = 1, #verts, 2 do
				WriteVertex(verts[i], verts[i + 1])
			end

			WriteVertex(false)
		end

		net.SendToServer()
	end

	api.send = send
else
	function send(chunk_pos, verts, chunk_update, pl)
		-- API to do it from the server?
		error"unimplemented"
	end

	function net_send_chunkmsg(targets, msg, msg_n)
		local chunk_update = msg.chunk_update
		NET_MSG(chunk_update and MSG_CHUNK_UPDATE or MSG_CHUNK, true)
		net.WriteUInt(msg_n, MSGN_bits)
		local aid = msg[1]
		local chunk_pos = msg[2]
		net.WriteUInt(aid, 32)
		net.WriteUInt(chunk_pos, CHUNK_bits)
		local chunk = msg[3]
		dbg('net_send_chunkmsg()', 'targets=', targets, 'chunk_pos=', chunk_pos, 'chunk_update=', chunk_update and table.Count(chunk_update) or 'no')

		if chunk_update then
			if chunk_update and chunk then
				error'chunk found, but updating'
			end

			local verts = chunk_update

			-- TODO: main vector and float offsets?
			for k, v in pairs(verts) do
				local color, pos, i = v[1], v[2], v[3]
				-- search for 'net.ReadUInt(VERTS_bits)'
				assert(isnumber(i))
				net.WriteUInt(i, VERTS_bits)
				WriteVertex(color, pos)
			end

			net.WriteUInt(0, VERTS_bits)
		else
			local verts = chunk._verts
			-- TODO: main vector and float offsets?
			local alerted

			for i = 1, #verts, 2 do
				if not alerted and not verts[i] then
					alerted = true
					local msg = "[draw3d] Chunk transmit missing chunks, impossible: " .. "pl=%s chunk_pos=%s chunk._verts=%s\n"
					msg = msg:format(want_player(aid), chunk_pos, table.ToString(chunk._verts))
					--ErrorNoHalt(msg)
				end

				WriteVertex(verts[i] or 3, verts[i + 1] or Vector(-1, 1, 2))
			end

			WriteVertex(false)
		end

		net.Send(targets)
	end

	local function merge_msg(target_aid, msg)
		-- TODO
	end

	function queue_chunk(target_aid, aid, chunk_pos, chunk, chunk_update)
		dbg('queue_chunk()', 'target_aid=', target_aid, 'aid=', aid, 'chunk_pos=', chunk_pos, chunk_update and '(chunk_update)' or '')

		if chunk_update then
			assert(not chunk, 'chunk found, but am updating')

			local msg = {
				aid,
				chunk_pos,
				nil,
				chunk_update = chunk_update
			}

			msg_add(target_aid, msg)
		else
			local msg = {aid, chunk_pos, chunk}

			if merge_msg(target_aid, msg) then return end
			msg_add(target_aid, msg)
		end
	end

	function broadcast_chunk(...)
		dbg('broadcast_chunk()', want_player((...)))

		if TEST then
			local ply = assert(me)
			local target_aid = ply:AccountID()
			queue_chunk(target_aid, ...)

			return
		end

		for _, ply in player.Iterator() do
			local target_aid = ply:AccountID()

			if ply:NetSendOK() then
				queue_chunk(target_aid, ...)
			end
		end
	end
end

local function ReadToVertsTable(i, verts, verts_updates)
	local color = net.ReadUInt(COLOR_bits)
	dbg('\t', '-', i, 'RAW color=', color)

	if color == 0 then
		if net_BytesLeft() > 0 then
			dbg('ReadToVertsTable()', '<ASSUMPTION FAIL>', 'net_BytesLeft()>0', '==', net_BytesLeft())
		end

		return false
	end

	local pos = net.ReadVector()

	-- strange syntax to catch nan
	if (math.abs(pos.x) < 1) or (math.abs(pos.y) < 1) or (math.abs(pos.z) < 1) then
		panic("INVALID POS RECEIVED")

		return false
	end

	if not (math.abs(pos.x) < 2 ^ 14) or not (math.abs(pos.y) < 2 ^ 14) or not (math.abs(pos.z) < 2 ^ 14) then
		panic("INFINITE POS RECEIVED")

		return false
	end

	dbg('\t', '-', i, 'pos=', pos)
	verts[i * 2 - 1] = color - 1
	verts[i * 2] = pos

	if verts_updates then
		table.insert(verts_updates, {color - 1, pos, i})
	end

	return verts, verts_updates
end

function net_proc_chunkmsg(aid, is_chunk_update)
	local chunk_pos = net.ReadUInt(CHUNK_bits)
	dbg('net_proc_chunkmsg()', 'pl=', want_player(aid), 'aid=', aid, 'chunk_pos=', chunk_pos, 'is_chunk_update=', is_chunk_update)

	if is_chunk_update then
		local chunk = db[aid][chunk_pos]

		if not chunk then
			dbg('NO CHUNK', want_player(aid), aid, chunk_pos)
			--TODO: make chunk?

			return
		end

		local verts = chunk._verts
		local verts_updates = {}

		for _ = 1, MAX_VERTS do
			local i = net.ReadUInt(VERTS_bits)

			if i == 0 then
				if net_BytesLeft() > 0 then
					dbg('WTF', 'net_BytesLeft()>0  == ' .. net_BytesLeft())
				end

				break
			end

			if ReadToVertsTable(i, verts, verts_updates) == false then
				error'should not be possible'
			end
		end

		chunk._verts = verts
		db[aid][chunk_pos] = chunk
		recalculate_chunk(chunk)

		if SERVER then
			broadcast_chunk(aid, chunk_pos, nil, verts_updates)
		end
	else
		local chunk = NewChunk()
		Msg"[draw3d] "
		print("NewChunk() n=", chunk_pos, want_player(aid))
		local verts = chunk._verts

		for i = 1, MAX_VERTS do
			if ReadToVertsTable(i, verts) == false then break end
		end

		db[aid][chunk_pos] = chunk
		recalculate_chunk(chunk)

		if SERVER then
			broadcast_chunk(aid, chunk_pos, chunk, false)
		end
	end

	local chunk = db[aid][chunk_pos]
	local ok, err = xpcall(on_chunk_update, debug.traceback, aid, chunk_pos, chunk)

	if not ok then
		ErrorNoHalt(("[draw3d] ERROR in on_chunk_update() for %s (chunk= draw3d.get_db()[%s][%s] ): %s\n"):format(want_player(aid), aid, chunk_pos, err))
	end
	--TODO: Should only be enabled on server when server chunk sending optimization has been coded
end

local function on_chunk_update(aid, chunk_pos, chunk)
	-- TODO populate
	dbg("CHUNK UPDATE", want_player(aid), chunk_pos)
end

_M.on_chunk_update = _RAW.on_chunk_update or on_chunk_update

if SERVER then
	local function net_send_fullupdate()
		panic"unimplemented"
	end
	function process_queue(aid,q,sent)
		local pl = want_player(aid)
		--print(pl or aid)
		if not pl then return end
		table.Empty(sent)

		for i = 1, 6 do
			local msg, msg_n = msg_get_next(aid, false)
			--if pl==me then Msg"." end

			if msg then
				if not sent[msg] then
					sent[msg] = true

					if msg[1] == 'fullupdate' then
						net_send_fullupdate(pl, msg_n)
					else
						net_send_chunkmsg(pl, msg, msg_n)
					end
				end
			else
				break
			end
		end
	end

	function Tick()
	--	Msg"_"
		local sent = {}
		for aid, q in pairs(message_queue) do
			process_queue(aid,q,sent)
		end
	end

	function dbg_msg_getter()
		for aid, q in pairs(message_queue) do
			local pl = want_player(aid)
			print(aid, pl)
			if not pl then return end
			local msg, msg_n = msg_get_next(aid, false)
			print('    - MSG=', msg_n, msg)
		end
	end

	hook.Add('Tick', Tag, function()
		Tick()
	end)
end

local msgn_acknowledged = 0
local ack_dedupe = {}

function net_acknowledge_msg(msg_n, aid)
	if CLIENT then
		--dbg('net_acknowledge_msg()', 'msg_n=', msg_n)
		NET_MSG(MSG_ACK_MSG, true)
		net.WriteUInt(msg_n, MSGN_bits)
		net.SendToServer()

		if msg_n <= msgn_acknowledged then
			dbg('net_acknowledge_msg()', 'WARN', '<<<<already ack 1>>>>', 'msg_n=', msg_n, 'msgn_acknowledged=', msgn_acknowledged)

			return true
		elseif msg_n > msgn_acknowledged + 1 then
			if not ack_dedupe[msg_n] then
				ack_dedupe[msg_n] = true
				dbg('net_acknowledge_msg()', 'WARN', 'missing acks!', 'msg_n=', msg_n, 'msgn_acknowledged=', msgn_acknowledged)
			else
				dbg('net_acknowledge_msg()', 'WARN', '<<<<already ack 2>>>>, missing acks!', 'msg_n=', msg_n, 'msgn_acknowledged=', msgn_acknowledged)

				return true
			end
		else
			msgn_acknowledged = msg_n

			for msg_n_acked, _ in pairs(ack_dedupe) do
				if msg_n == msg_n_acked then
					ack_dedupe[msg_n_acked] = nil
					dbg('net_acknowledge_msg()', 'acked!', 'msg_n=', msg_n, 'msgn_acknowledged=', msgn_acknowledged, "missing=", table.Count(ack_dedupe))
				end
			end
		end
	end

	if SERVER then
		msg_ack(aid, msg_n)
		local pl = want_player(aid)
		dbg('net_acknowledge_msg()', 'pl=', pl, 'aid=', aid, 'msg_n=', msg_n)
	end
end

-- full state update
function net_fullupdate(aid)
	local pl = want_player(aid)
	dbg('net_fullupdate()', 'pl=', pl, 'aid=', aid)

	if SERVER then
		table.Empty(message_queue[aid])

		message_queue[aid][1] = {'fullupdate'}

		return
	end

	send_fullupdate_noclear(aid)
end

function send_fullupdate_noclear(target_aid)
	target_aid = want_aid(target_aid)
	dbg('send_fullupdate_noclear()', 'pl=', want_player(target_aid), 'target_aid=', target_aid)

	for aid, chunks in pairs(db) do
		for chunk_pos, chunk in pairs(chunks) do
			queue_chunk(target_aid, aid, chunk_pos, chunk)
		end
	end
end

hook.Add("PlayerFullyConnectedNet", Tag, function(pl)
	--TODO
	--send_fullupdate_noclear(pl)
end)

local function MSGN()
	local r = net.ReadUInt(MSGN_bits)

	if r > 64000 then
		--ErrorNoHaltWithStack
		panic("MSGN too large: " .. r)

		return
	end

	return r
end

function on_net_receive(len, pl)
	local aid = SERVER and pl:AccountID()
	local msg_type = net.ReadUInt(MSG_bits)

	if msg_type == MSG_ACK_MSG then
		assert(SERVER, "got MSG_ACK_MSG on CLIENT??")
		local msgn = MSGN()
		dbg('MSG_ACK_MSG', 'pl=', pl, 'aid=', aid, 'msgn=', msgn)
		net_acknowledge_msg(msgn, aid)
	elseif msg_type == MSG_CHUNK or msg_type == MSG_CHUNK_UPDATE then
		--if msg_type == MSG_CHUNK_UPDATE then panic("UNIMPLEMENTED") end
		local msgn = CLIENT and MSGN() or false

		if CLIENT then
			if net_acknowledge_msg(msgn) then return end -- already processed
			aid = net.ReadUInt(32)
		end

		dbg(msg_type == MSG_CHUNK and 'MSG_CHUNK' or 'MSG_CHUNK_UPDATE', 'pl=', pl, 'aid=', aid, 'msgn=', msgn)
		net_proc_chunkmsg(aid, msg_type == MSG_CHUNK_UPDATE)
	elseif msg_type == MSG_FULLUPDATE then
		do
			return panic("Unimplemented")
		end

		local msgn = CLIENT and MSGN()
		dbg('MSG_FULLUPDATE', 'pl=', pl, 'aid=', aid, 'msgn=', msgn)
		net_fullupdate(aid, msgn)
	else
		print(pl)
		panic("invalid msg: " .. tostring(msg_type))
	end

	if net_BytesLeft() ~= 0 then end --dbg("RECEIVE","bytes still left: ",net_BytesLeft(),"msg=",msg_type)
end

net.Receive(Tag, function(len, pl)
	if TEST_LOSS and math.random() > 0.9 then return end
	net_BytesLeft_startnum = net_BitsLeft()
	net_BytesLeft_msglen = len
	on_net_receive(len, pl)
end)

function dbg_clear()
	table.Empty(get_db())

	if SERVER then
		table.Empty(get_queue())
	end
end

function status()
	PrintTable(get_db())

	if SERVER then
		PrintTable(get_queue())
	end
end

function panic(msg)
	--dbg_clear()
	_M.Tick = function() end
	_M.on_net_receive = function() end

	if msg then
		error(msg, 2)
	end
end

kill = panic
destroy = panic

local _ = CLIENT and false and TEST and timer.Simple(2, function()
	draw3d.send(1, {33, Vector(11, 22, 33), 44, Vector(44, 55, 66)})

	timer.Simple(3, function()
		epoe.api.print("\n=====\n\n")
		print("\n=====\n\n")

		draw3d.send(1, nil, {
			[3] = {222, Vector(111, 222, 333)}
		})
	end)
end)