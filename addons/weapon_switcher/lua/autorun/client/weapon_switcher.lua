-- hl2 weapon switcher in lua (an attempt)
-- not a faithful reproduction
-- problems:
--   - does not scale the same as original
--   - overrides hooks
--   -

local HOOK_INPUT        = "WeaponSwitcher_Input"
local HOOK_PAINT        = "WeaponSwitcher_Paint"
local HOOK_SILENCE      = "WeaponSwitcher_SilenceEngine"
local CALLBACK_TOGGLE   = "WeaponSwitcher_Toggle"

local NUM_SLOTS         = 6
local SELECTION_TIMEOUT = 3
local SOUND_VOLUME      = 0.35

local SOUND_MOVE        = "Player.WeaponSelectionMoveSlot"
local SOUND_SELECT      = "Player.WeaponSelected"
local SOUND_CLOSE       = "Player.WeaponSelectionClose"
local SOUND_DENY        = "Player.DenyWeaponSelection"

local YPOS              = 20
local SMALL             = 80
local LARGE_W           = 200
local LARGE_H           = 200
local ITEM_H            = 42
local GAP               = 8
local CORNER            = 6
local NUM_X             = 8
local NUM_Y             = 6
local NAME_BOT          = 8
local ICON_PAD          = 6

local COL_BG            = Color(0, 0, 0, 90)
local COL_BG_EMPTY      = Color(0, 0, 0, 70)
local COL_BG_SEL        = Color(0, 0, 0, 150)
local COL_NUMBER        = Color(255, 220, 0, 255)
local COL_TEXT          = Color(255, 220, 0, 220)

local ICON_COLOR        = {}

-- garry is a monkey who hid wherever the fuck the physgun icon is, so we use this.
local ICON_CHAR         = {
	weapon_physgun = "h",
}

local ICON_SCALE        = {
	weapon_physgun = 0.85,
}

-- Force the gravgun to sort before the physgun within slot 0. (thanks rubat)
local SLOT_OVERRIDE     = {
	weapon_physcannon = { slot = 0, pos = 1 },
	weapon_physgun    = { slot = 0, pos = 50 },
}

local function GetSlotOf(w)
	local o = SLOT_OVERRIDE[w:GetClass()]
	return o and o.slot or w:GetSlot()
end

local function GetSlotPosOf(w)
	local o = SLOT_OVERRIDE[w:GetClass()]
	return o and o.pos or w:GetSlotPos()
end

local cvFastSwitch = GetConVar("hud_fastswitch")
local cvCustom = CreateClientConVar("weapon_switcher_custom", "0", true, false,
	"1 = use this custom switcher, 0 = use stock engine CHudWeaponSelection")
local cvScale = CreateClientConVar("weapon_switcher_scale", "1", true, false,
	"HUD scale multiplier (clamped 0.25 - 4)")

local scale = 1
local function S(n) return math.Round(n * scale) end

local fontsCreated = false
local function ApplyScale()
	fontsCreated = true
	scale = math.Clamp(cvScale:GetFloat(), 0.25, 4)

	surface.CreateFont("WeaponSwitcher_Number", {
		font = "Verdana",
		size = math.Round(18 * scale),
		weight = 700,
		antialias = true,
		additive = true,
	})

	surface.CreateFont("WeaponSwitcher_Text", {
		font = "Verdana",
		size = math.Round(14 * scale),
		weight = 700,
		antialias = true,
	})

	surface.CreateFont("WeaponSwitcher_Icon", {
		font = "HalfLife2",
		size = math.Round(140 * scale),
		weight = 0,
		antialias = true,
		additive = true,
	})

	surface.CreateFont("WeaponSwitcher_IconGlow", {
		font = "HalfLife2",
		size = math.Round(140 * scale),
		weight = 0,
		antialias = true,
		additive = true,
		blursize = math.max(1, math.Round(6 * scale)),
	})
end

cvars.AddChangeCallback("weapon_switcher_scale", function() ApplyScale() end, "WeaponSwitcher_Scale")

local visible = false
local lastInputTime = 0
local selectedClass = nil
local _ourSound = false

concommand.Add("weapon_switcher_toggle", function()
	RunConsoleCommand("weapon_switcher_custom", cvCustom:GetBool() and "0" or "1")
end)

cvars.AddChangeCallback("weapon_switcher_custom", function(_, _, new)
	if not tobool(new) then
		visible = false
		selectedClass = nil
	end
end, CALLBACK_TOGGLE)

local function PlaySound(name)
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	_ourSound = true
	lp:EmitSound(name, 60, 100, SOUND_VOLUME)
	_ourSound = false
end

local function FastSwitchActive()
	return cvFastSwitch and cvFastSwitch:GetInt() == 1
end

local function GetBuckets()
	local lp = LocalPlayer()
	if not IsValid(lp) then return nil end

	local buckets = {}
	for slot = 0, NUM_SLOTS - 1 do buckets[slot] = {} end

	for _, w in ipairs(lp:GetWeapons()) do
		if IsValid(w) then
			local s = GetSlotOf(w)
			if s >= 0 and s < NUM_SLOTS then
				table.insert(buckets[s], w)
			end
		end
	end

	for slot = 0, NUM_SLOTS - 1 do
		table.sort(buckets[slot], function(a, b) return GetSlotPosOf(a) < GetSlotPosOf(b) end)
	end

	return buckets
end

local function FlatList(buckets)
	local flat = {}
	for slot = 0, NUM_SLOTS - 1 do
		for _, w in ipairs(buckets[slot]) do
			table.insert(flat, w)
		end
	end
	return flat
end

local function GetSelectedSlot(buckets)
	if not selectedClass then return nil end

	for slot = 0, NUM_SLOTS - 1 do
		for _, w in ipairs(buckets[slot]) do
			if w:GetClass() == selectedClass then return slot end
		end
	end
end

local function CurrentIndex(flat)
	if selectedClass then
		for i, w in ipairs(flat) do
			if w:GetClass() == selectedClass then return i end
		end
	end

	local active = LocalPlayer():GetActiveWeapon()
	if IsValid(active) then
		for i, w in ipairs(flat) do
			if w == active then return i end
		end
	end

	return 0
end

local function SwitchTo(class)
	local lp = LocalPlayer()
	if not IsValid(lp) then return false end

	for _, w in ipairs(lp:GetWeapons()) do
		if IsValid(w) and w:GetClass() == class then
			input.SelectWeapon(w)
			return true
		end
	end
	return false
end

local function ResetSelection(withCloseSound)
	if visible and withCloseSound then PlaySound(SOUND_CLOSE) end
	visible = false
	selectedClass = nil
end

local function CycleOffset(offset)
	local buckets = GetBuckets(); if not buckets then return end
	local flat = FlatList(buckets)
	if #flat == 0 then
		PlaySound(SOUND_DENY)
		return
	end

	local cur = CurrentIndex(flat)
	local newIdx = ((cur - 1 + offset) % #flat) + 1
	local newWep = flat[newIdx]

	if FastSwitchActive() then
		SwitchTo(newWep:GetClass())
		PlaySound(SOUND_MOVE)
		return
	end

	selectedClass = newWep:GetClass()
	visible = true
	lastInputTime = CurTime()
	PlaySound(SOUND_MOVE)
end

local function SelectSlot(slot)
	local buckets = GetBuckets(); if not buckets then return end
	if not buckets[slot] then return end
	if #buckets[slot] == 0 then
		PlaySound(SOUND_DENY)
		return
	end

	if FastSwitchActive() then
		local target = buckets[slot][1]
		local active = LocalPlayer():GetActiveWeapon()
		if IsValid(active) then
			for i, w in ipairs(buckets[slot]) do
				if w == active then
					target = buckets[slot][(i % #buckets[slot]) + 1]
					break
				end
			end
		end
		SwitchTo(target:GetClass())
		PlaySound(SOUND_MOVE)
		return
	end

	if selectedClass then
		for i, w in ipairs(buckets[slot]) do
			if w:GetClass() == selectedClass then
				local newIdx = (i % #buckets[slot]) + 1
				selectedClass = buckets[slot][newIdx]:GetClass()
				visible = true
				lastInputTime = CurTime()
				PlaySound(SOUND_MOVE)
				return
			end
		end
	end

	selectedClass = buckets[slot][1]:GetClass()
	visible = true
	lastInputTime = CurTime()
	PlaySound(SOUND_MOVE)
end

local function Confirm()
	if not visible or not selectedClass then return false end

	SwitchTo(selectedClass)
	PlaySound(SOUND_SELECT)
	visible = false
	selectedClass = nil
	return true
end


local function ScrollClaimedByWeapon()
	local lp = LocalPlayer()
	if not lp:IsValid() then return false end

	local wep = lp:GetActiveWeapon()
	if not wep:IsValid() then return false end

	local cls = wep:GetClass()
	if cls == "weapon_physgun" or cls == "weapon_physcannon" then
		return input.IsMouseDown(MOUSE_LEFT)
	end

	return hook.Run("WeaponSwitcher_ScrollClaimed", wep) == true
end

local iconCache = {}

local function GetIconInfo(class)
	if iconCache[class] ~= nil then return iconCache[class] end

	local content = file.Read("scripts/" .. class .. ".txt", "GAME")
	if not content then
		iconCache[class] = false
		return false
	end

	local sec = content:match('"weapon_s"%s*{(.-)}')
		or content:match('"weapon"%s*{(.-)}')
	if not sec then
		iconCache[class] = false
		return false
	end

	local font = sec:match('"font"%s*"([^"]+)"')
	local char = sec:match('"character"%s*"([^"]+)"')
	if not font or not char then
		iconCache[class] = false
		return false
	end

	iconCache[class] = { font = font, char = char }
	return iconCache[class]
end

local function DrawWeaponIcon(w, x, y, boxW, boxH, alpha)
	local cls = w:GetClass()
	local info = GetIconInfo(cls)
	if info then
		local char = ICON_CHAR[cls] or info.char
		local tint = ICON_COLOR[cls] or COL_NUMBER
		local scale = ICON_SCALE[cls] or 1
		surface.SetFont("WeaponSwitcher_Icon")
		surface.SetTextColor(tint.r, tint.g, tint.b, alpha)
		local tw, th = surface.GetTextSize(char)
		local px = x + math.floor((boxW - tw) * 0.5)
		local py = y + math.floor((boxH - S(28) - th) * 0.5)

		local pushed = false
		if scale ~= 1 then
			local cx, cy = px + tw * 0.5, py + th * 0.5
			local m = Matrix()
			m:Translate(Vector(cx, cy, 0))
			m:Scale(Vector(scale, scale, 1))
			m:Translate(Vector(-cx, -cy, 0))
			cam.PushModelMatrix(m)
			pushed = true
		end

		surface.SetFont("WeaponSwitcher_IconGlow")
		surface.SetTextColor(tint.r, tint.g, tint.b, math.floor(alpha * 0.6))
		for _ = 1, 3 do
			surface.SetTextPos(px, py)
			surface.DrawText(char)
		end

		surface.SetFont("WeaponSwitcher_Icon")
		surface.SetTextColor(tint.r, tint.g, tint.b, alpha)
		surface.SetTextPos(px, py)
		surface.DrawText(char)

		if pushed then cam.PopModelMatrix() end
		return
	end

	if type(w.DrawWeaponSelection) == "function" then
		local pad = S(ICON_PAD)
		render.SetScissorRect(x + pad, y + pad, x + boxW - pad, y + boxH - S(22), true)
		pcall(w.DrawWeaponSelection, w, x, y, boxW, boxH, alpha)
		render.SetScissorRect(0, 0, 0, 0, false)
	end
end

local function PrettyName(w)
	local name = w:GetPrintName() or w:GetClass()
	if name:sub(1, 1) ~= "#" then return name end

	local key = name:sub(2)
	local phrase = language.GetPhrase(key)
	if phrase and phrase ~= "" and phrase ~= key then return phrase end

	return w:GetClass():gsub("^weapon_", ""):gsub("_", " "):upper()
end

hook.Add("EntityEmitSound", HOOK_SILENCE, function(data)
	if not cvCustom:GetBool() then return end
	if _ourSound then return end

	local n = data.SoundName
	if n == SOUND_MOVE or n == SOUND_SELECT or n == SOUND_CLOSE or n == SOUND_DENY then
		return false
	end
end)

hook.Add("PlayerBindPress", HOOK_INPUT, function(ply, bind, pressed)
	if not pressed then return end
	if not cvCustom:GetBool() then return end

	if bind == "invnext" or bind == "invprev" then
		if ScrollClaimedByWeapon() then return end
		if bind == "invnext" then CycleOffset(1) else CycleOffset(-1) end
		return true
	end

	if bind == "lastinv" then
		ResetSelection(false)
		return
	end

	local slot = bind:match("^slot(%d)$")
	if slot then
		SelectSlot(tonumber(slot) - 1)
		return true
	end

	if visible then
		if bind == "+attack" then return Confirm() end
		if bind == "+attack2" then
			ResetSelection(true)
			return true
		end
	end
end)

hook.Add("HUDPaint", HOOK_PAINT, function()
	if not cvCustom:GetBool() then return end
	if not fontsCreated then fontsCreated = true ApplyScale() end
	if not visible then return end
	if CurTime() - lastInputTime > SELECTION_TIMEOUT then
		ResetSelection(true)
		return
	end

	local buckets = GetBuckets(); if not buckets then return end
	local selectedSlot = GetSelectedSlot(buckets)

	local sSMALL       = S(SMALL)
	local sLARGE_W     = S(LARGE_W)
	local sLARGE_H     = S(LARGE_H)
	local sITEM_H      = S(ITEM_H)
	local sGAP         = S(GAP)
	local sCORNER      = S(CORNER)
	local sNUM_X       = S(NUM_X)
	local sNUM_Y       = S(NUM_Y)
	local sNAME_BOT    = S(NAME_BOT)
	local sNAME_PAD    = S(12)

	local totalW       = 0
	for slot = 0, NUM_SLOTS - 1 do
		totalW = totalW + ((selectedSlot == slot) and sLARGE_W or sSMALL)
		if slot < NUM_SLOTS - 1 then totalW = totalW + sGAP end
	end

	local startX = math.floor((ScrW() - totalW) * 0.5)
	local rowY = S(YPOS)

	local function DrawNumber(x, y, slot)
		surface.SetFont("WeaponSwitcher_Number")
		surface.SetTextColor(COL_NUMBER.r, COL_NUMBER.g, COL_NUMBER.b, COL_NUMBER.a)
		surface.SetTextPos(x + sNUM_X, y + sNUM_Y)
		surface.DrawText(tostring(slot + 1))
	end

	local function DrawName(x, y, boxW, boxH, w, atBottom)
		local name = PrettyName(w)
		surface.SetFont("WeaponSwitcher_Text")
		surface.SetTextColor(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, COL_TEXT.a)
		local maxW = boxW - sNAME_PAD
		while surface.GetTextSize(name) > maxW and #name > 4 do
			name = name:sub(1, -2)
		end
		local tw, th = surface.GetTextSize(name)
		local ny = atBottom and (y + boxH - th - sNAME_BOT) or (y + math.floor((boxH - th) * 0.5))
		surface.SetTextPos(x + math.floor((boxW - tw) * 0.5), ny)
		surface.DrawText(name)
	end

	local x = startX
	for slot = 0, NUM_SLOTS - 1 do
		local list = buckets[slot]
		local hasWeapons = #list > 0
		local isSelected = (selectedSlot == slot)

		if isSelected and hasWeapons then
			local y = rowY
			for i, w in ipairs(list) do
				local isSelWep = (w:GetClass() == selectedClass)
				local h = isSelWep and sLARGE_H or sITEM_H
				local bg = isSelWep and COL_BG_SEL or COL_BG

				draw.RoundedBox(sCORNER, x, y, sLARGE_W, h, bg)

				if isSelWep then
					DrawWeaponIcon(w, x, y, sLARGE_W, h, 255)
					DrawName(x, y, sLARGE_W, h, w, true)
				else
					DrawName(x, y, sLARGE_W, h, w, false)
				end

				if i == 1 then DrawNumber(x, y, slot) end

				y = y + h + sGAP
			end

			x = x + sLARGE_W + sGAP
		else
			local bg = hasWeapons and COL_BG or COL_BG_EMPTY
			draw.RoundedBox(sCORNER, x, rowY, sSMALL, sSMALL, bg)
			if hasWeapons then DrawNumber(x, rowY, slot) end
			x = x + sSMALL + sGAP
		end
	end
end)
