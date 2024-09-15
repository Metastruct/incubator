
if SERVER then
	resource.AddSingleFile( 'resource/fonts/MinecraftRegular.ttf' )
	return
end

local FONT_NAME = 'ChatsoundMinecraftSubtitles'
local MIN_FONT_SIZE = 1
local MAX_FONT_SIZE = 8

local enabledCV = CreateClientConVar( 'chatsounds_minecraft_subtitles_enable', 0, true, false, 'Toggle Minecraft-like subtitles for chatsounds', 0, 1 )
local sizeCV = CreateClientConVar( 'chatsounds_minecraft_subtitles_size', 2, true, false, 'Sets Minecraft subtitles size', MIN_FONT_SIZE, MAX_FONT_SIZE )

__MINECRAFT_SUBTITLES_FONTS_CACHE = __MINECRAFT_SUBTITLES_FONTS_CACHE or {}

ChatsoundMinecraftSubtitles = {
	subtitles = {},

	fontName = 'DermaDefault',
	fontScale = 12,
	fontHeight = -1, -- calculated

	backgroundColor = Color( 0, 0, 0, 230 ),
	textColor = Color( 255, 255, 255 ),
	shadowColor = Color( 64, 64, 64 ),

	leftArrow = '<',
	rightArrow = '>',
	leftArrowWidth = -1, -- calculated
	rightArrowWidth = -1, -- calculated
	minStaticWidth = -1, -- calculated

	gap = 16,
	padding = 8,
	shadowOffset = -1, -- calculated
	shadowOffsetScale = 1,
	screenPaddingInt = 4,
	screenPaddingPercent = 0.12,
	minAngle = 30,
	minDistance = 10,
	minDistance2 = -1, -- calculated
	fadeOutDuration = 2,

	hookName = 'ChatsoundMinecraftSubtitles',
	hooks = {
		ChatsoundsSoundInit = function( self, ply, snd, sound_data, meta )
			local playerName = ply:Name()
			local soundName = meta["Key"]
			local id = "%s:%s" % { ply:UserID(), meta["Key"] }

			local subtitle = self.subtitles[id]

			if !subtitle then
				subtitle = {}
				self.subtitles[id] = subtitle
			end

			subtitle.deadline = CurTime() + math.min( sound_data['Duration'], 60 )
			subtitle.position = ply:GetShootPos()
			subtitle.alpha = 255
			subtitle.count = ( subtitle.count or 0 ) + 1
			subtitle.name = subtitle.count > 1
				and '%s (x%i)' % { id, subtitle.count }
				 or id
		end,
		HUDPaint = function( self )
			local now = CurTime()
			local x, y = ScrW() - self.screenPaddingInt, math.Round( ScrH() * ( 1 - self.screenPaddingPercent ) ) - self.screenPaddingInt
			local widestName = 0

			self:setMinecraftFont()

			for k, subtitle in pairs( self.subtitles ) do
				if subtitle.deadline < now then
					if subtitle.deadline + self.fadeOutDuration < now then
						self.subtitles[k] = nil
						continue
					end

					subtitle.alpha = ( 1 - ( now - subtitle.deadline ) / self.fadeOutDuration ) * 255
				end

				subtitle.width = surface.GetTextSize( subtitle.name )
				widestName = math.max( widestName, subtitle.width )
			end

			local w = self.minStaticWidth + widestName
			local h = table.Count( self.subtitles ) * self.fontHeight
			x = x - w
			y = y - h

			surface.SetDrawColor( self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b, self.backgroundColor.a )
			surface.DrawRect( x, y, w, h )

			local i = 0
			local myPos = LocalPlayer():GetShootPos()
			local yaw = LocalPlayer():EyeAngles().yaw

			for k, subtitle in pairs( self.subtitles ) do
				local direction = subtitle.position - LocalPlayer():GetShootPos()
				local angle = 180

				if direction:Length2DSqr() > self.minDistance2 then
					angle = math.Round( yaw - direction:Angle().yaw ) % 360

					if angle >= 180 then
						angle = angle - 360
					end
				end

				-- if angle < -self.minAngle or angle > ( 180 - self.minAngle ) then
				if angle == 180 or angle < -self.minAngle then
					self:drawMinecraftText( self.leftArrow, x + self.padding, y + i * self.fontHeight, subtitle.alpha )
				end

				-- if angle > self.minAngle or angle < -( 180 - self.minAngle ) then
				if angle == 180 or angle > self.minAngle then
					self:drawMinecraftText( self.rightArrow, x + w - self.padding - self.rightArrowWidth, y + i * self.fontHeight, subtitle.alpha )
				end

				local center = ( widestName - subtitle.width ) / 2
				self:drawMinecraftText( subtitle.name, x + self.padding + self.leftArrowWidth + self.gap + center, y + i * self.fontHeight, subtitle.alpha )

				i = i + 1
			end
		end,
	}
}

function ChatsoundMinecraftSubtitles:init()
	self.minDistance2 = self.minDistance * self.minDistance

	self:calcScales()
	self:toggle()

	cvars.AddChangeCallback( 'chatsounds_minecraft_subtitles_enable', function( _, oldValue, value )
		self:toggle()
	end, 'chatsounds_minecraft_subtitles_enable' )

	cvars.AddChangeCallback( 'chatsounds_minecraft_subtitles_size', function( _, oldValue, value )
		self:calcScales()
	end, 'chatsounds_minecraft_subtitles_size' )
end

function ChatsoundMinecraftSubtitles:calcScales()
	local size = sizeCV:GetInt()
	local fontSize = self.fontScale * size
	self.fontName = FONT_NAME .. fontSize
	self.shadowOffset = self.shadowOffsetScale * size

	if !__MINECRAFT_SUBTITLES_FONTS_CACHE[self.fontName] then
		__MINECRAFT_SUBTITLES_FONTS_CACHE[self.fontName] = true

		surface.CreateFont( self.fontName, {
			-- On Windows/macOS, use the font-name which is shown to you by your operating system Font Viewer. On Linux, use the file name
			font = system.IsLinux() and "MinecraftRegular.ttf" or "Minecraft",
			extended = true,
			size = fontSize,
			weight = 100,
			blursize = 0,
			scanlines = 0,
			antialias = false,
			underline = false,
			italic = false,
			strikeout = false,
			symbol = false,
			rotary = false,
			shadow = false,
			additive = false,
			outline = false,
		})
	end

	timer.Simple( 0, function()
		surface.SetFont( self.fontName )

		local _, fontHeight = surface.GetTextSize( 'test' )
		-- draw.GetFontHeight doesn't update height

		self.fontHeight = fontHeight
		self.leftArrowWidth = surface.GetTextSize( self.leftArrow )
		self.rightArrowWidth = surface.GetTextSize( self.rightArrow )
		self.minStaticWidth = self.padding * 2 + self.gap * 2 + self.leftArrowWidth + self.rightArrowWidth
	end )
end

function ChatsoundMinecraftSubtitles:toggle()
	local isEnabled = enabledCV:GetBool()

	for eventName, callback in pairs( self.hooks ) do
		if isEnabled then
			hook.Add( eventName, self.hookName, function( ... )
				callback( self, ... )
			end )
		else
			hook.Remove( eventName, self.hookName )
		end
	end
end

function ChatsoundMinecraftSubtitles:setMinecraftFont()
	surface.SetFont( self.fontName )
end

function ChatsoundMinecraftSubtitles:drawMinecraftText( text, x, y, alpha )
	surface.SetTextColor( self.shadowColor.r, self.shadowColor.g, self.shadowColor.b, alpha )
	surface.SetTextPos( x + self.shadowOffset, y )
	surface.DrawText( text )

	surface.SetTextColor( self.textColor.r, self.textColor.g, self.textColor.b, alpha )
	surface.SetTextPos( x, y - self.shadowOffset )
	surface.DrawText( text )
end

ChatsoundMinecraftSubtitles:init()
