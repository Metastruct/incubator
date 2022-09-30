local Tag = 'playerusehook'

if SERVER then
	util.AddNetworkString(Tag)
	hook.Add("FindUseEntity", Tag, function(initator, target) end)

	local ratelimit = setmetatable({}, {
		__mode = 'k'
	})

	hook.Add("PlayerUse", Tag, function(initator, target)
		if initator:KeyPressed(IN_USE) then return end
		if not target:IsValid() or not target:IsPlayer() then return end
		local nextt = ratelimit[target] or 0
		local now = RealTime()
		if now < nextt then return end
		ratelimit[target] = now + .05
		if hook.Run("PlayerUsedByPlayer", target, initator) then
			return
		end
		net.Start(Tag)
		net.WriteEntity(initator)
		net.Send(target)
	end)

	return
end

local help = [[ 
0=disabled
 - 1=look at user
 - 2=look at user and play a sound from rp_react_to_use_saysound
 - 3=only play deny sound or sound set on rp_react_to_use_saysound cvar

 - HINT: hook.Add("PlayerUsedByPlayer","a",function(me,initator) print("USE TEST",me,initator) return true end)
]]
local rp_react_to_use_mode = CreateClientConVar("rp_react_to_use_mode", "0", true, false, help, 0, 4)
local rp_react_to_use_saysound = CreateClientConVar("rp_react_to_use_saysound", "none", true, false, "Plays saysound command with the following sound. Empty string or \"none\" to disable.")
local rp_react_to_use_notification = CreateClientConVar("rp_react_to_use_notification", "1", true, false, "1=print message of user, 2=also play a sound")
local rp_react_to_use_only_afk = CreateClientConVar("rp_react_to_use_only_afk", "0", true, false, "1=Only react if AFK", 0, 1)
local ratelimit = 0
local ratelimit_msg = 0
local last_user
local first_msg = true

local function PlayerUsedByPlayer(initator)
	local mode = rp_react_to_use_mode:GetInt()
	local mode_msg = rp_react_to_use_notification:GetInt()
	local soundstr = rp_react_to_use_saysound:GetString()
	local only_afk = rp_react_to_use_only_afk:GetBool()

	if soundstr:Trim() == "" or soundstr:Trim() == "none" then
		soundstr = false
	end

	local now = RealTime()
	local first = first_msg
	first_msg = false

	if first or mode == 1 or mode == 2 then
		if now < ratelimit then return end
		ratelimit = now + math.Rand(2, 5)
		local stop_afk = only_afk and LocalPlayer():IsAFK()

		if not stop_afk then
			if mode == 2 or first then
				RunConsoleCommand("saysound", soundstr or "suit denydevice")
			end

			LookAtSmooth(initator, 1)
		end
	elseif mode == 3 then
		if now < ratelimit then return end
		ratelimit = now + math.Rand(2, 5)
		RunConsoleCommand("saysound", soundstr or "suit denydevice")
	end

	if first or mode_msg > 0 then
		if (now - ratelimit_msg) < (last_user == initator and .5 or .5) then return end
		ratelimit_msg = now

		if first then
			surface.PlaySound("friends/friend_join.wav")
			chat.AddText(Color(255, 222, 222), "[Notice] ", Color(255, 255, 255), "Disable the use messages by running in console: rp_react_to_use_notification 0")
		elseif mode_msg >= 2 then
			surface.PlaySound("friends/friend_join.wav")
		end

		chat.AddText(initator, Color(255, 255, 255), " pressed ", Color(255, 100, 50), "+use", Color(255, 255, 255), " on you", Color(255, 255, 255), "!")
	end
end

net.Receive(Tag, function(len)
	local initator = net.ReadEntity()
	if not initator:IsValid() then return end
	if hook.Run("PlayerUsedByPlayer", LocalPlayer(), initator) then return end
	PlayerUsedByPlayer(initator)
end)
