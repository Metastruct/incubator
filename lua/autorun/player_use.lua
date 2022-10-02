local Tag = 'playerusehook'
if SERVER then
	util.AddNetworkString(Tag)
	hook.Add("FindUseEntity", Tag, function(initator, target) end)

	local ratelimit = setmetatable({}, {
		__mode = 'k'
	})

	hook.Add("PlayerUse", Tag, function(initator, target)
		if not initator:KeyPressed(IN_USE) then return end
		if not target:IsValid() or not target:IsPlayer() then return end
		local nextt = ratelimit[target] or 0
		local now = RealTime()
		if now < nextt then return end
		ratelimit[target] = now + .05
		if hook.Run("PlayerUsedByPlayer", target, initator) then return end
		net.Start(Tag)
		net.WriteEntity(initator)
		net.Send(target)
	end)

	return
end

-- helper

local function getStartledBy(target,me)
	--TODO: Serverside
	local startt=RealTime()
	hook.Add("StartCommand",Tag,function(pl,mv)
		local now = RealTime()
		local me=me or pl -- TODO
		local cmd=mv
		if now-startt>0.2 then 
			hook.Remove("StartCommand",Tag)
			return
		end
	
		if --(SERVER and not me:IsBot()) or
			 not me:Alive()
			or me:GetMoveType() ~= MOVETYPE_WALK
			or not me:IsOnGround()
			then return end
	
		local mypos = me:GetPos()
	
		
		local norm = target:GetPos()-mypos
		norm.z = 0
		norm:Normalize()
	
	
		local va = cmd:GetViewAngles()
		va.r = 0
		va.p = 0
		va.y = va.y
	
	
		norm:Rotate(-va)
		norm:Mul(250)
		local fw, sd = cmd:GetForwardMove(), cmd:GetSideMove()
	
		fw = fw - norm.x
		sd = sd + norm.y
		--print(norm)
		cmd:SetForwardMove(fw)
		cmd:SetSideMove(sd)


	end)
	LookAtSmooth(target,1)
end


local WHITE= Color(255, 255, 255)
local help = [[0 = disabled
 - 1 = look at user
 - 2 = look at user and play a sound from rp_react_to_use_saysound
 - 3 = only play deny sound or sound set on rp_react_to_use_saysound cvar

 - HINT: hook.Add("PlayerUsedByPlayer","a",function(me,initator) print("USE TEST",me,initator) return true end)
]]
local rp_react_to_use_mode_friends_only = CreateClientConVar("rp_react_to_use_mode_friends_only", "0", true, false, "Should react action be triggered by friends only", 0, 4)
local rp_react_to_use_friends_only = CreateClientConVar("rp_react_to_use_friends_only", "0", true, false, "Should only friends be able to do anything with use", 0, 4)
local rp_react_to_use_mode = CreateClientConVar("rp_react_to_use_mode", "0", true, false, help, 0, 4)
local rp_react_to_use_saysound = CreateClientConVar("rp_react_to_use_saysound", "none", true, false, "Plays saysound command with the following sound. Empty string or \"none\" to disable.")
local rp_react_to_use_notification = CreateClientConVar("rp_react_to_use_notification", "2", true, false, "1=print message of user, 2=also play a sound")
local rp_react_to_use_notification_sound = CreateClientConVar("rp_react_to_use_notification_sound", "physics/wood/wood_furniture_impact_soft1.wav", true, false, "Notification sound to play to you. Empty to disable.")
local rp_react_to_use_only_afk = CreateClientConVar("rp_react_to_use_only_afk", "0", true, false, "1=Only react if AFK", 0, 1)
local rp_react_to_use_notification_every = CreateClientConVar("rp_react_to_use_notification_every", "3", true, false, "Only allow pressing every N seconds per player", 0, 1)
local rp_react_to_use_notification_in_chat = CreateClientConVar("rp_react_to_use_notification_in_chat", "0", true, false, "0=notification 1=chat message", 0, 1)
local rp_react_to_use_do_not_move = CreateClientConVar("rp_react_to_use_do_not_move", "0", true, false, "Only look towards player instead of moving away", 0, 1)

local ratelimit = 0
local ratelimit_msg = 0
local msg_next_ok_ply = 0
local last_user
local first_msg = true

local function PlayerUsedByPlayer(initator)
	local mode = rp_react_to_use_mode:GetInt()
	local mode_msg = rp_react_to_use_notification:GetInt()
	local soundstr = rp_react_to_use_saysound:GetString()
	local rp_react_to_use_notification_sound = rp_react_to_use_notification_sound:GetString()
	local only_afk = rp_react_to_use_only_afk:GetBool()
	local use_chat = rp_react_to_use_notification_in_chat:GetBool()
	local rp_react_to_use_notification_every = rp_react_to_use_notification_every:GetFloat()
	local rp_react_to_use_friends_only = rp_react_to_use_friends_only:GetBool()
	local rp_react_to_use_mode_friends_only = rp_react_to_use_mode_friends_only:GetBool()

	if soundstr:Trim() == "" or soundstr:Trim() == "none" then
		soundstr = false
	end

	local arefriends

	if rp_react_to_use_mode_friends_only or rp_react_to_use_friends_only then
		arefriends = LocalPlayer():IsFriend(initator)
		if rp_react_to_use_friends_only and not arefriends then return end
	end

	local now = RealTime()
	local first = first_msg
	first_msg = false

	if not rp_react_to_use_mode_friends_only or arefriends then
		if first or mode == 1 or mode == 2 then
			if now < ratelimit then return end
			ratelimit = now + math.Rand(2, 5)
			local stop_afk = only_afk and LocalPlayer():IsAFK()

			if not stop_afk then
				if mode == 2 or first then
					RunConsoleCommand("saysound", soundstr or "suit denydevice")
				end

				if first or rp_react_to_use_do_not_move:GetBool() then
					LookAtSmooth(initator, 1)
				else
					getStartledBy(initator)
				end
					
					
			end
		elseif mode == 3 then
			if now < ratelimit then return end
			ratelimit = now + math.Rand(2, 5)
			RunConsoleCommand("saysound", soundstr or "suit denydevice")
		end
	end

	if first or mode_msg > 0 then
		if (now - ratelimit_msg) < .5 then return end
		ratelimit_msg = now

		if last_user ~= initator then
			last_user = initator
		elseif now < msg_next_ok_ply then
			print("rate limit",initator)
			return
		end

		msg_next_ok_ply = now + math.Clamp(rp_react_to_use_notification_every, 0, 60 * 5)

		if first then
			if rp_react_to_use_notification_sound:Trim()~="" then
				surface.PlaySound(rp_react_to_use_notification_sound)
			end
			chat.AddText(Color(255, 222, 222), "[Notice] ", WHITE, "Disable the use messages by running in console: rp_react_to_use_notification 0")
		elseif mode_msg >= 2 then
			if rp_react_to_use_notification_sound:Trim()~="" then
				surface.PlaySound(rp_react_to_use_notification_sound)
			end
		end

		--
		if not use_chat then
			MsgC(initator, WHITE, " pressed +use on you!\n")
		end

		if LocalPlayer():CanSee(initator) then
			if use_chat then
				chat.AddText(initator, WHITE, " wants your attention!")
			else
				notification.AddLegacy(initator:GetName() .. " wants your attention!", NOTIFY_GENERIC, 5)
			end
		else
			if use_chat then
				chat.AddText(initator, WHITE, " tapped on your shoulder!")
			else
				notification.AddLegacy(initator:GetName() .. " tapped on your shoulder!", NOTIFY_GENERIC, 5)
			end
		end
	end
end

net.Receive(Tag, function(len)
	local initator = net.ReadEntity()
	if not initator:IsValid() then return end
	if hook.Run("PlayerUsedByPlayer", LocalPlayer(), initator) then return end
	PlayerUsedByPlayer(initator)
end)
