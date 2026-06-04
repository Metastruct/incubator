local Tag = "capsadmin"
local bot_capsadmin = CreateConVar("bot_capsadmin", "0", FCVAR_ARCHIVE, "1 = all bots are capsadmin, 2=specified bots are capsadmin (TODO)")

--  Follow: use a bot to make it follow you (5s duration, faces you)
--  Chat trigger: mention a bot's name in chat within 100 units to activate it
--  Attack response: bots counter-attack when hurt (crowbar, 5s chase, 10s cooldown) (overrides godmode)
--  Auto-revive: dead bots respawn after 10s via Revive or KillSilent+Spawn
--  Random events: bots randomly switch weapons, jump, or attack (every 10-40s)
--  Delayed reactions: use/chat responses are delayed 0.1-1s, with 10% ignore chance; attack has 20% ignore chance
--  Sentences: bots say weighted random lines (gordon, h, uh, etc.) on activation
--  Allow rotating players with physgun (qbox only)

require 'hookgroup'

_G.capsadmin = _G.capsadmin or {}
local capsadmin = _G.capsadmin
local DBG = false

local state = setmetatable({}, {
	__index = function(t, k)
		if IsValid(k) and k:IsPlayer() then
			local s = {
				death_count = 0,
				eye_angles = Angle(math.random(-45, 45), math.random(0, 360), 0)
			}

			t[k] = s

			return s
		end
	end
})

function capsadmin.new(name)
	error"TODO"
end

function capsadmin.GetTable()
	return state
end

local now = CurTime()

local function enabled()
	return bot_capsadmin:GetBool()
end

local function dbg(...)
	if not DBG then return end
	MsgC(Color(255, 180, 0), "[" .. Tag .. "] ", Color(255, 255, 255), ...)
end

local WEAPONS = {"weapon_crowbar", "none", "weapon_physcannon", "gmod_camera"}

local ATTACK_WEAPONS = {
	weapon_crowbar = true,
	gmod_camera = true
}

local SENTENCES = {
	{
		text = "gordon",
		weight = 80
	},
	{
		text = "h",
		weight = 50
	},
	{
		text = "uh",
		weight = 30
	},
	{
		text = "huh",
		weight = 30
	},
	{
		text = "a",
		weight = 30
	},
	{
		text = "now what",
		weight = 30
	},
	{
		text = "not again",
		weight = 30
	},
	{
		text = "but why",
		weight = 30
	},
	{
		text = "hm",
		weight = 20
	}
}

local function PickSentence()
	local total = 0

	for _, s in ipairs(SENTENCES) do
		total = total + s.weight
	end

	local r = math.random() * total

	for _, s in ipairs(SENTENCES) do
		r = r - s.weight
		if r <= 0 then return s.text end
	end

	return SENTENCES[#SENTENCES].text
end

local function HandleBotRandomEvent(bot)
	local s = state[bot]
	if not bot:Alive() then return end
	if s.next_event and now < s.next_event then return end
	s.next_event = now + math.random(10, 40)

	if math.random(2) == 1 then
		local wep = WEAPONS[math.random(#WEAPONS)]
		bot:SelectWeapon(wep)

		--dbg(bot, " random event: selected ", wep, "\n")
		if ATTACK_WEAPONS[wep] then
			s.attack_until = now + math.Rand(0.2, 1.5)
		end
	else
		s.jump = now + math.Rand(0.1, 1.5)
	end
end

function capsadmin.say_delayed(bot, text, delay)
	local s = state[bot]

	s.say = {
		text = text,
		time = now + (delay or math.Rand(0.1, 0.5))
	}
end

function capsadmin.OnPostPlayerDeath(bot, inflictor, attacker)
	if not enabled() then return end
	if not bot:IsBot() then return end
	local s = state[bot]
	s.died = now
	s.death_count = s.death_count + 1

	--dbg(bot, " died\n")
	timer.Create(Tag .. '_revive_' .. bot:UserID(), 10, 1, function()
		capsadmin.revive_bot(bot)
	end)
end

function capsadmin.revive_bot(bot)
	if not IsValid(bot) then return end
	local s = state[bot]

	if bot:Alive() then
		s.died = nil
		dbg(bot, " already alive, skipping revive\n")

		return
	end

	bot:Revive()

	if bot:UnStuck() == false then
		dbg(bot, " UnStuck failed, KillSilent+Spawn\n")
		bot:KillSilent()
		bot:Spawn()
	else
		dbg(bot, " revived and unstuck\n")
	end

	s.died = nil
end

function capsadmin.BotThink(bot)
	local s = state[bot]
	local owner = bot.IsBeingPhysgunned and bot:IsBeingPhysgunned()

	if owner and owner:IsValid() then
		s.eye_angles = bot:EyeAngles()
	end

	if s.use_state and now >= s.use_state.time then
		local user = s.use_state.user
		s.used = now
		s.user = user

		if s.use_state.fromChat and math.random(2) == 1 then
			capsadmin.say_delayed(bot, user:Nick())
		else
			capsadmin.say_delayed(bot, PickSentence())
		end

		local wep = WEAPONS[math.random(#WEAPONS)]

		if wep ~= "none" then
			bot:SelectWeapon(wep)
			dbg(bot, " used by ", user, ", selected ", wep, "\n")
		else
			dbg(bot, " used by ", user, ", no weapon\n")
		end

		s.use_state = nil
	end

	if s.say and now >= s.say.time then
		bot:Say(s.say.text)
		s.say = nil
	end

	HandleBotRandomEvent(bot)
end

function capsadmin.OnThink()
	now = CurTime()
	if not enabled() then return end

	for _, bot in player.Iterator() do
		if bot:IsBot() then
			capsadmin.BotThink(bot)
		end
	end
end

function capsadmin.OnPlayerUsedByPlayer(used, user, fromChat)
	if not enabled() then return end

	if used:IsBot() then
		local s = state[used]

		if math.random() < 0.1 then
			dbg(used, " ignored use by ", user, "\n")

			return
		end

		s.use_state = {
			user = user,
			fromChat = fromChat,
			time = CurTime() + math.Rand(0.1, 1)
		}

		dbg(used, " will react to ", user, " in ", s.use_state.time - CurTime(), "s\n")
	end
end

function capsadmin.OnPlayerSay(ply, text)
	local bots = player.GetBots()
	if not next(bots) then return end
	if not enabled() then return end
	local lower = text:lower()

	for _, bot in ipairs(bots) do
		if lower:find(bot:Nick():lower(), 1, true) and ply:GetPos():Distance(bot:GetPos()) <= 100 then
			capsadmin.OnPlayerUsedByPlayer(bot, ply, true)
		end
	end
end

function capsadmin.Attacked(bot, attacker)
	if not attacker:IsPlayer() then return end
	if not bot:IsBot() then return end

	if math.random() < 0.2 then
		dbg(bot, " ignored attack by ", attacker, "\n")

		return
	end

	local s = state[bot]
	bot:SelectWeapon("weapon_crowbar")
	s.target = attacker
	s.attack_start = now
	dbg(bot, " attacked by ", attacker, ", counter-attacking\n")
end

function capsadmin.OnPlayerHurt(bot, attacker)
	if not enabled() then return end
	if not bot:IsBot() then return end
	if not IsValid(attacker) then return end
	local s = state[bot]
	if s.attack_cooldown and now < s.attack_cooldown then return end
	s.attack_cooldown = now + 10
	capsadmin.Attacked(bot, attacker)
end

function capsadmin.OnPlayerShouldTakeDamage(bot, attacker)
	if not attacker:IsPlayer() or not attacker:IsBot() then return end
	local s = state[attacker]
	if s.target == bot then return true end
end

function capsadmin.OnStartCommand(bot, cmd)
	if not enabled() then return end
	if not bot:IsBot() then return end
	local s = state[bot]

	if s.attack_until then
		if now < s.attack_until then
			cmd:SetButtons(bit.bor(cmd:GetButtons() or 0, IN_ATTACK))
		else
			s.attack_until = nil
		end
	end

	if s.jump then
		cmd:SetButtons(bit.bor(cmd:GetButtons() or 0, IN_JUMP))
		s.jump = nil
	end

	local ang

	if s.target then
		if not IsValid(s.target) or now - s.attack_start > 5 then
			s.target = nil
			s.attack_start = nil
		else
			ang = (s.target:EyePos() - bot:EyePos()):Angle()
			local buttons = bit.bor(IN_ATTACK, IN_SPEED)

			if math.abs(ang.p) > 45 then
				buttons = bit.bor(buttons, IN_DUCK)
			end

			cmd:SetButtons(bit.bor(cmd:GetButtons() or 0, buttons))
			local dist = bot:GetPos():Distance(s.target:GetPos())

			if dist >= 16 then
				cmd:SetForwardMove(400)
				cmd:SetSideMove(0)
			else
				cmd:SetForwardMove(0)
				cmd:SetSideMove(0)
			end

			cmd:SetViewAngles(ang)

			return
		end
	end

	if s.used then
		if not IsValid(s.user) then
			s.used = nil
			s.user = nil

			return
		end

		ang = (s.user:GetPos() - bot:GetPos()):Angle()
		ang.p = 0

		if now - s.used > 5 then
			dbg(bot, " move timer expired\n")
			s.eye_angles = ang
			s.used = nil
			s.user = nil
			ang = nil
		end
	end

	if not ang then
		ang = cmd:GetViewAngles()

		if ang:IsZero() then
			ang = bot:EyeAngles()

			if ang:IsZero() then
				ang = s.eye_angles
			else
				s.eye_angles = ang
				ang = nil
			end
		else
			s.eye_angles = ang
			ang = nil
		end
	end

	if ang then
		cmd:SetViewAngles(ang)
	end

	if s.used then
		if now - s.used > 5 then return end
		local dist = bot:GetPos():Distance(s.user:GetPos())

		if dist < 100 then
			cmd:SetForwardMove(0)
			cmd:SetSideMove(0)
		else
			if dist > 200 then
				cmd:SetButtons(bit.bor(cmd:GetButtons() or 0, IN_SPEED))
			end

			cmd:SetForwardMove(400)
			cmd:SetSideMove(0)
		end
	end
end

local hooks = hookgroup.NewObj(Tag)
capsadmin.hooks = hooks
hooks:Add("PostPlayerDeath", capsadmin.OnPostPlayerDeath)
hooks:Add("Think", capsadmin.OnThink)
hooks:Add("PlayerUsedByPlayer", capsadmin.OnPlayerUsedByPlayer)
hooks:Add("PlayerHurt", capsadmin.OnPlayerHurt)
hooks:Add("PlayerShouldTakeDamage", capsadmin.OnPlayerShouldTakeDamage)
hooks:Add("PlayerSay", capsadmin.OnPlayerSay)
hooks:Add("StartCommand", capsadmin.OnStartCommand)
hooks:Activate()

capsadmin.panic = function()
	hooks:Deactivate()
	print("killed " .. Tag)
end
