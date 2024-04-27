
local FONT = 'Trebuchet24'
local FONT_HEIGHT = draw.GetFontHeight( FONT )

local function getMediaPlayers()
	return ents.FindByClass( "mediaplayer_tv" )
end

local function togglePlayerSubscribtion( player )
	MediaPlayer.RequestListen( player )
end

local function watch( params )
	local getValue = params.value
	local deepCheck = params.deepCheck or false
	local onChange = params.onChange
	local callOnInit = params.callOnInit or false
	local watchIf = params.watchIf or nil
	local watchInterval = params.watchInterval or 0.25

	if callOnInit then
		onChange( getValue() )
	end

	local prev = getValue()

	local function copyValue( value )
		prev = {}

		for k, v in pairs( value ) do
			prev[k] = v
		end
	end

	local check = deepCheck and function()
		local value = getValue()

		if #prev != #value then
			copyValue( value )
			onChange( value )
			return
		end

		for k, _ in pairs( value ) do
			if prev[k] != value[k] then
				copyValue( value )
				onChange( value )
				break
			end
		end
	end or function()
		local value = getValue()

		if prev != value then
			prev = value
			onChange( value )
		end
	end

	if watchIf != nil then
		local function runCheck()
			if watchIf() then
				check()
				timer.Simple( watchInterval, runCheck )
			end
		end

		runCheck()
	end
end

local function titleGetter( player )
	return function()
		if player._mp == nil then
			return 'Not subscribed'
		end

		local media = player._mp:CurrentMedia()
		return media and media:Title() or 'No media'
	end
end

local function createCloseButton( parent, onClose )
	local close = vgui.Create( 'DButton', parent )
	close:SetText( '' )
	close:SetSize( 25, 25 )
	close:SetMouseInputEnabled( true )

	local padding = 5
	function close:Paint( w, h )
		surface.SetDrawColor( 255, 255, 255 )
		surface.DrawLine( padding, padding, w - padding, h - padding )
		surface.DrawLine( w - padding - 1, padding, padding - 1, h - padding )
	end

	function close:DoClick()
		onClose()
	end

	return close
end

function togglePopup( player )
	if !player then return end

	if IsValid( player.popup ) then
		player.popup:Remove()
		player.popup = nil
		return
	end

	local popup = vgui.Create( 'DFrame' )
	player.popup = popup
	player.popup_meta = player.popup_meta or {}

	local meta = player.popup_meta
	local x = meta.x or 50
	local y = meta.y or 50
	local w = meta.w or 160
	local h = meta.h or 90

	popup:DockPadding( 5, 25, 5, 5 )
	popup:SetPos( x, y )
	popup:SetSize( w, h )
	popup:SetTitle( '' )
	popup:SetSizable( true )
	popup:ShowCloseButton( false )

	local popup_Think = popup.Think

	function popup:Think()
		if !IsValid( player ) then
			popup:Remove()
			return
		end

		popup_Think( self )

		local x, y = popup:GetPos()
		local w, h = popup:GetSize()

		if x < 0 then
			x = 0
			popup.x = 0
		elseif x + w > ScrW() then
			x = ScrW() - w
			popup.x = x
		end

		if y < 0 then
			y = 0
			popup.y = 0
		elseif y + h > ScrH() then
			y = ScrH() - h
			popup.y = y
		end

		meta.x = popup.x
		meta.y = popup.y
		meta.w = w
		meta.h = h
	end

	function popup:Paint( w, h )
		surface.SetDrawColor( 0, 0, 0, 210 )
		surface.DrawRect( 0, 0, w, h )

		surface.SetDrawColor( 255, 255, 255 )
		surface.DrawRect( 0, 0, w, 1 )
	end

	do // Title label
		local label = vgui.Create( 'DLabel', popup )
		label:SetPos( 5, 0 )
		label:SetContentAlignment( 4 )
		label:SetColor( color_white )
		label:SetMouseInputEnabled( false )

		label.Think = popup_Think

		watch({
			value = titleGetter( player ),
			onChange = function( title )
				label:SetText( title )
			end,
			callOnInit = true,
			watchIf = function()
				return IsValid( label )
			end,
		})

		watch({
			value = function()
				return popup:GetWide()
			end,
			onChange = function( wide )
				label:SetSize( wide - 25 - 5, 25 )
			end,
			watchIf = function()
				return IsValid( popup )
			end,
			watchInterval = 0.1,
			callOnInit = true,
		})
	end

	do // Close button
		local close = createCloseButton( popup, function()
			popup:Remove()

			if player then
				player.popup = nil
			end
		end )

		watch({
			value = function()
				return popup:GetWide()
			end,
			onChange = function( wide )
				close:SetPos( popup:GetWide() - close:GetWide(), 1 )
			end,
			watchIf = function()
				return IsValid( popup )
			end,
			watchInterval = 0.1,
			callOnInit = true,
		})
	end

	do // Screen panel
		local screen = vgui.Create( 'DPanel', popup )
		screen:Dock( FILL )

		local function canDraw()
			if !IsValid( player ) then
				return 'Player does not exist'
			end

			if !IsValid( player._mp ) then
				return 'Not subscribed'
			end

			local media = player._mp:CurrentMedia()

			if !media or !media.Draw then
				return 'No media'
			end
		end

		function screen:Paint( w, h )
			local reason = canDraw()

			if reason then
				draw.DrawText( reason, FONT, w / 2, ( h - FONT_HEIGHT ) / 2, color_white, TEXT_ALIGN_CENTER )
			else
				local media = player._mp:CurrentMedia()

				media:Draw( w, h )
			end
		end
	end
end

local function createMediaPlayerController( player, panel )
	// Label
	local label = vgui.Create( 'DLabel', panel )
	label:Dock( FILL )
	label:SetContentAlignment( 5 )
	label:SetColor( color_white )

	watch({
		value = titleGetter( player ),
		onChange = function( title )
			label:SetText( title )
		end,
		callOnInit = true,
		watchIf = function()
			return IsValid( label )
		end,
	})

	do // Subscribtion toggle
		local subscribeButton = vgui.Create( 'DButton', panel )
		subscribeButton:Dock( RIGHT )
		subscribeButton:SetWide( 50 )

		watch({
			value = function()
				return player._mp != nil
			end,
			onChange = function( value )
				if value then
					subscribeButton:SetText( 'Stop' )
				else
					subscribeButton:SetText( 'Watch' )
				end
			end,
			callOnInit = true,
			watchIf = function()
				return IsValid( subscribeButton )
			end,
			callOnInit = true,
		})

		subscribeButton.DoClick = function()
			togglePlayerSubscribtion( player )
		end
	end

	do // Popup toggle
		local popupButton = vgui.Create( 'DButton', panel )
		popupButton:Dock( RIGHT )
		popupButton:SetWide( 70 )
		popupButton:DockMargin( 0, 0, 5, 0 )

		watch({
			value = function()
				return player._mp == nil and !IsValid( player.popup )
			end,
			onChange = function( disabled )
				popupButton:SetDisabled( disabled )
			end,
			callOnInit = true,
			watchIf = function()
				return IsValid( popupButton )
			end,
		})

		watch({
			value = function()
				return IsValid( player.popup )
			end,
			onChange = function( value )
				if value then
					popupButton:SetText( 'Pop down' )
				else
					popupButton:SetText( 'Pop up' )
				end
			end,
			callOnInit = true,
			watchIf = function()
				return IsValid( popupButton )
			end,
		})

		popupButton.DoClick = function()
			togglePopup( player )
		end
	end
end

if mp_popuper and IsValid( mp_popuper.frame ) then
	mp_popuper.frame:Remove()
end

mp_popuper = {
	frame = nil,
	open = function()
		if IsValid( mp_popuper.frame ) then
			mp_popuper.close()
		end

		local frame = vgui.Create( 'DFrame' )
		mp_popuper.frame = frame
		frame:SetSize( 350, ScrH() )
		frame:SetPos( ScrW() - frame:GetWide(), 0 )
		frame:SetTitle( '' )
		frame:MakePopup()
		frame:SetSizable( true )
		frame:ShowCloseButton( false )

		frame:SetAlpha( 0 )
		frame:AlphaTo( 255, 0.25 )

		function frame:Close()
			frame:SetMouseInputEnabled( false )
			frame:SetKeyboardInputEnabled( false )

			frame:AlphaTo( 0, 0.25, 0, function()
				frame:Remove()
				mp_popuper.close()
			end )
		end

		function frame:Paint( w, h )
			surface.SetDrawColor( 0, 0, 0, 210 )
			surface.DrawRect( 0, 0, w, h )

			surface.SetDrawColor( 255, 255, 255 )
			surface.DrawRect( 0, 0, 1, h )
		end

		do // Close button
			local close = createCloseButton( frame, function()
				mp_popuper.close()
			end )

			close:SetPos( 2, 2 )
		end

		local list = vgui.Create( 'DScrollPanel', frame )
		frame.list = list
		list:Dock( FILL )

		watch({
			value = function()
				return getMediaPlayers()
			end,
			deepCheck = true,
			onChange = function()
				mp_popuper.refresh()
			end,
			watchIf = function()
				return IsValid( frame )
			end,
			callOnInit = true,
		})
	end,
	refresh = function()
		if !IsValid( mp_popuper.frame ) then
			return
		end

		local list = mp_popuper.frame.list
		list:Clear()

		for _, player in ipairs( getMediaPlayers() ) do
			local panel = vgui.Create( 'DPanel', list )
			panel:SetTall( 50 )
			panel:Dock( TOP )
			panel:DockMargin( 0, 0, 0, 5 )
			panel:DockPadding( 5, 5, 5, 5 )

			function panel:Paint( w, h )
				if self:IsHovered() then
					surface.SetDrawColor( 255, 255, 255 )
					surface.DrawRect( 0, 0, 1, h )
					surface.DrawRect( w - 1, 0, 1, h )
				end
			end

			createMediaPlayerController( player, panel )
		end
	end,
	close = function()
		if IsValid( mp_popuper.frame ) then
			mp_popuper.frame:Close()
			mp_popuper.frame = nil
		end
	end,
	toggle = function()
		if IsValid( mp_popuper.frame ) then
			mp_popuper.close()
		else
			mp_popuper.open()
		end
	end
}

local prefixes = {
    '/',
    '!',
    '.',
}

hook.Add( 'OnPlayerChat', 'popuper', function( ply, message )
	if !mp_popuper then return end
	if ply != LocalPlayer() then return end

	local usedPrefix = nil

    for _, prefix in ipairs( prefixes ) do
        if string.StartWith( message, prefix ) then
            usedPrefix = prefix
            break
        end
    end

    if !usedPrefix then return end
    local args = string.Explode( '%s+', string.sub( message, #usedPrefix + 1 ):lower(), true )

    if args[1] == 'popup' then
		mp_popuper.toggle()
	end
end )
