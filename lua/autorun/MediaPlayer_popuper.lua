
if !CLIENT then return end

local EASE = 0.2
local FONT = 'Trebuchet24'
local FONT_HEIGHT = draw.GetFontHeight( FONT )

function getMediaPlayers()
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
		if !IsValid( player ) then
			return 'Removed'
		end

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
		surface.SetDrawColor( 0, 0, 0, 230 )
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

local function createMediaPlayerController( player, panel, list )
	do // Label
		panel.title = vgui.Create( 'DLabel', panel )
		panel.title:Dock( TOP )
		panel.title:SetContentAlignment( 5 )
		panel.title:SetColor( color_white )

		watch({
			value = titleGetter( player ),
			onChange = function( title )
				panel.title:SetText( title )
			end,
			callOnInit = true,
			watchIf = function()
				return IsValid( panel.title )
			end,
		})
	end

	do // Owner
		panel.owner = vgui.Create( 'DLabel', panel )
		panel.owner:Dock( TOP )
		panel.owner:SetContentAlignment( 5 )
		panel.owner:SetColor( color_white )

		watch({
			value = function()
				panel.owner.player = player.CPPIGetOwner and player:CPPIGetOwner() or panel.owner.player

				return panel.owner.player and panel.owner.player:Name()
			end,
			onChange = function( name )
				panel.owner:SetText( name and 'Owner: ' .. name or 'Unknown owner' )
			end,
			callOnInit = true,
			watchIf = function()
				return IsValid( panel.owner )
			end,
		})
	end

	do // Controls
		panel.controls = vgui.Create( 'DPanel', panel )
		panel.controls:Dock( BOTTOM )
		panel.controls:DockMargin( 0, 5, 0, 0 )
		panel.controls:SetTall( 25 )

		panel.controls.Paint = nil

		do // Sidebar toggle
			panel.sidebarButton = vgui.Create( 'DButton', panel.controls )
			table.insert( panel.buttons, panel.sidebarButton )
			panel.sidebarButton:Dock( LEFT )

			function panel.sidebarButton:DoClick()
				MediaPlayer.HideSidebar()

				if list.showSideBarFor == player._mp then
					list.showSideBarFor = nil
				else
					timer.Simple( 0.1, function()
						if !IsValid( player ) or !IsValid( player._mp ) or !IsValid( list ) then return end

						MediaPlayer.ShowSidebar( player._mp )
						list.showSideBarFor = player._mp
					end )
				end
			end

			watch({
				value = function()
					return list.showSideBarFor == player._mp
				end,
				onChange = function( isShowing )
					if isShowing then
						panel.sidebarButton:SetText( 'Hide sidebar' )
						panel.sidebarButton:SetWide( 80 )
					else
						panel.sidebarButton:SetText( 'Show sidebar' )
						panel.sidebarButton:SetWide( 85 )
					end
				end,
				callOnInit = true,
				watchIf = function()
					return IsValid( panel.sidebarButton )
				end,
			})
		end

		do // Subscribtion toggle
			panel.subscribeButton = vgui.Create( 'DButton', panel.controls )
			table.insert( panel.buttons, panel.subscribeButton )
			panel.subscribeButton:Dock( RIGHT )

			watch({
				value = function()
					return player._mp != nil
				end,
				onChange = function( value )
					if value then
						panel.subscribeButton:SetText( 'Ubsub.' )
						panel.subscribeButton:SetWide( 50 )
					else
						panel.subscribeButton:SetText( 'Watch' )
						panel.subscribeButton:SetWide( 45 )
					end
				end,
				callOnInit = true,
				watchIf = function()
					return IsValid( panel.subscribeButton )
				end,
				callOnInit = true,
			})

			function panel.subscribeButton:DoClick()
				togglePlayerSubscribtion( player )
			end
		end

		do // Popup toggle
			panel.popupButton = vgui.Create( 'DButton', panel.controls )
			table.insert( panel.buttons, panel.popupButton )
			panel.popupButton:Dock( RIGHT )
			panel.popupButton:DockMargin( 0, 0, 5, 0 )

			watch({
				value = function()
					return player._mp == nil and !IsValid( player.popup )
				end,
				onChange = function( disabled )
					panel.popupButton:SetDisabled( disabled )
				end,
				callOnInit = true,
				watchIf = function()
					return IsValid( panel.popupButton )
				end,
			})

			watch({
				value = function()
					return IsValid( player.popup )
				end,
				onChange = function( value )
					if value then
						panel.popupButton:SetText( 'Pop down' )
						panel.popupButton:SetWide( 69 )
					else
						panel.popupButton:SetText( 'Pop up' )
						panel.popupButton:SetWide( 55 )
					end
				end,
				callOnInit = true,
				watchIf = function()
					return IsValid( panel.popupButton )
				end,
			})

			function panel.popupButton:DoClick()
				togglePopup( player )
			end
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

		local frame do // Main frame
			frame = vgui.Create( 'DFrame' )
			mp_popuper.frame = frame
			frame:DockPadding( 1, 29, 0, 0 )
			frame:SetSize( 350, ScrH() )
			frame:SetTitle( '' )
			frame:MakePopup()
			frame:SetSizable( true )
			frame:SetDraggable( false )
			frame:ShowCloseButton( false )
			frame:SetKeyboardInputEnabled( false )

			frame:SetPos( ScrW(), 0 )
			frame:MoveTo( ScrW() - frame:GetWide(), 0, 0.25, 0, EASE )

			function frame:Close()
				frame:SetMouseInputEnabled( false )
				frame:SetKeyboardInputEnabled( false )

				MediaPlayer.HideSidebar()

				frame:MoveTo( ScrW(), 0, 0.25, 0, EASE, function()
					frame:Remove()
					mp_popuper.close()
				end )
			end

			function frame:Paint( w, h )
				surface.SetDrawColor( 0, 0, 0, 230 )
				surface.DrawRect( 0, 0, w, h )

				surface.SetDrawColor( 255, 255, 255 )
				surface.DrawRect( 0, 0, 1, h )
			end

			function frame:Think()
				if gui.IsGameUIVisible() then
					gui.HideGameUI()
					mp_popuper.close()
					frame.Think = nil
				end
			end

		end

		do // Close button
			frame.close = createCloseButton( frame, function()
				mp_popuper.close()
			end )

			frame.close:SetPos( 2, 2 )
		end

		do // TV list
			frame.list = vgui.Create( 'DScrollPanel', frame )
			frame.list:Dock( FILL )
			frame.list:DockMargin( 5, 0, 0, 0 )
			frame.list.mediaPlayers = {}

			function frame.list:Refresh()
				for _, player in ipairs( getMediaPlayers() ) do
					local panel = frame.list.mediaPlayers[player]
					if IsValid( panel ) then continue end

					panel = vgui.Create( 'DPanel', frame.list )
					frame.list.mediaPlayers[player] = panel
					panel:SetTall( 75 )
					panel:Dock( TOP )
					panel:DockMargin( 0, 0, 5, 5 )
					panel:DockPadding( 5, 5, 5, 5 )
					panel.buttons = {}

					function panel:Think()
						if !IsValid( player ) then
							for _, button in ipairs( panel.buttons ) do
								button:SetDisabled( true )
							end

							timer.Simple( 5, function()
								if IsValid( panel ) then
									panel:Remove()
									frame.list.mediaPlayers[player] = nil
								end
							end )
						end
					end

					function panel:Paint( w, h )
						if IsValid( player ) then
							surface.SetDrawColor( 150, 150, 150 )
							surface.DrawOutlinedRect( 0, 0, w, h )
						else
							surface.SetDrawColor( 255, 0, 0, 230 )
							surface.DrawRect( 0, 0, w, h )
						end


						if self:IsHovered() then
							surface.SetDrawColor( 255, 255, 255 )
							surface.DrawOutlinedRect( 0, 0, w, h )
						end
					end

					createMediaPlayerController( player, panel, frame.list )
				end
			end

			function frame.list:Adapt()
			end

			watch({
				value = function()
					return getMediaPlayers()
				end,
				deepCheck = true,
				onChange = function()
					frame.list:Refresh()
				end,
				watchIf = function()
					return IsValid( frame )
				end,
				callOnInit = true,
			})
		end

		do // Volume slider
			frame.footerFrame = vgui.Create( 'DPanel', frame )
			frame.footerFrame:Dock( BOTTOM )
			local inlinePadding = 10
			local blockPadding = 5

			function frame.footerFrame:Adapt()
				local height = 0

				for _, child in ipairs( self:GetChildren() ) do
					child:SetPos( inlinePadding, height + blockPadding )
					child:SetWide( frame:GetWide() - inlinePadding * 2 )
					height = height + child:GetTall()
				end

				self:SetTall( height + blockPadding * 2 )
			end

			function frame.footerFrame:Paint( w, h )
				surface.SetDrawColor( 255, 255, 255 )
				surface.DrawRect( 0, 0, w, 1 )
			end

			do // Volume slider
				frame.volume = vgui.Create( 'DNumSlider', frame.footerFrame )
				frame.volume:SetText( 'Volume' )
				frame.volume:SetMin( 0 )
				frame.volume:SetMax( 100 )
				frame.volume:SetDecimals( 0 )
				frame.volume:SetValue( MediaPlayer.Volume() * 100 )

				function frame.volume:OnValueChanged( value )
					MediaPlayer.Volume( value / 100 )
				end

				local interval = 8
				function frame.volume.Slider:Paint( w, h )
					local ticks = math.round( ( w - 8 ) / interval )
					local step = ( w - 8 ) / ticks

					surface.SetDrawColor( 210, 210, 210 )
					surface.DrawRect( 7, h / 2, w - 14, 1 )

					for i = 1, ticks do
						surface.DrawRect( math.floor( i * step ), h / 2 + 4, 1, 5 )
					end
				end
			end

			frame.footerFrame:Adapt()
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

list.Set( "ChatCommands", "popup", function( ... )
	mp_popuper.toggle()
end )
