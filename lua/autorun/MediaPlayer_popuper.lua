
if !CLIENT then return end

local EASE = 0.2
local FONT = 'Trebuchet24'
local FONT_HEIGHT = draw.GetFontHeight( FONT )
local MUTE_UNFOCUSED_CONVAR = "mediaplayer_mute_unfocused"
local MUTE_UNFOCUSED_DESCRIPTION = string.format( "Mute distant media players (%s)", MUTE_UNFOCUSED_CONVAR )

local function getMediaPlayers()
	local tvs = ents.FindByClass( "mediaplayer_tv" )
	local projectors = ents.FindByClass( "mediaplayer_projector" )

	return table.Add( tvs, projectors )
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

local function togglePopup( player )
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
	local x = meta.x or ScrH() / 50
	local y = meta.y or ScrH() / 50
	local w = meta.w or ScrW() * 0.25
	local h = meta.h or ScrH() * 0.25

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

		if meta.x != x then
			if x < 0 then
				x = 0
			elseif x + w > ScrW() then
				x = ScrW() - w
			end

			popup.x = x
			meta.x = x
		end

		if meta.y != y then
			if y < 0 then
				y = 0
			elseif y + h > ScrH() then
				y = ScrH() - h
			end

			popup.y = y
			meta.y = y
		end

		if meta.w != w or meta.h != h then
			local left, top, right, bottom = popup:GetDockPadding()
			local x_padding, y_padding = left + right, top + bottom

			w = math.min( x + w, ScrW() ) - x
			h = math.min( y + h, ScrH() ) - y

			local screen_w, screen_h = w - x_padding, h - y_padding
			local screen_w_ratio, screen_h_ratio = screen_w / 16, screen_h / 9

			local screen_min_ratio = math.min( screen_w_ratio, screen_h_ratio )

			screen_w = screen_w / screen_w_ratio * screen_min_ratio
			screen_h = screen_h / screen_h_ratio * screen_min_ratio

			w = math.round( screen_w + x_padding )
			h = math.round( screen_h + y_padding )

			popup:SetSize( w, h )
			meta.w = w
			meta.h = h

			if IsValid( popup.close ) then
				popup.close:Refresh()
			end
		end
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
		popup.close = createCloseButton( popup, function()
			popup:Remove()

			if IsValid( player ) then
				player.popup = nil
			end
		end )

		function popup.close:Refresh()
			popup.close:SetPos( popup:GetWide() - popup.close:GetWide(), 1 )
		end

		popup.close:Refresh()
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

				-- local w_ratio = w / 16
				-- local h_ratio = h / 9
				-- local min_ratio = math.min( w_ratio, h_ratio )

				-- local screen_w = w / w_ratio * min_ratio
				-- local screen_h = h / h_ratio * min_ratio

				-- local matrix = Matrix()
				-- matrix:Translate( Vector( ( w - screen_w ) / 2, ( h - screen_h ) / 2, 0 ) )

				-- cam.PushModelMatrix( matrix )
				-- 	media:Draw( screen_w, screen_h )
				-- cam.PopModelMatrix()
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
				if !player._mp then return end

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
					return player._mp
				end,
				onChange = function( mp )
					panel.sidebarButton:SetDisabled( !mp )
				end,
				callOnInit = true,
				watchIf = function()
					return IsValid( panel.sidebarButton )
				end,
			})

			watch({
				value = function()
					return list.showSideBarFor and list.showSideBarFor == player._mp
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
						panel.subscribeButton:SetText( 'Unsub.' )
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
				if mp_popuper.frame == frame then
					mp_popuper.frame = nil
				end

				MediaPlayer.HideSidebar()

				frame:SetMouseInputEnabled( false )
				frame:SetKeyboardInputEnabled( false )

				frame:MoveTo( ScrW(), 0, 0.25, 0, EASE, function()
					frame:Remove()
				end )
			end

			function frame:Paint( w, h )
				surface.SetDrawColor( 0, 0, 0, 230 )
				surface.DrawRect( 0, 0, w, h )

				surface.SetDrawColor( 255, 255, 255 )
				surface.DrawRect( 0, 0, 1, h )
			end

			local visible = gui.IsGameUIVisible()

			function frame:Think()
				if visible != gui.IsGameUIVisible() then
					visible = gui.IsGameUIVisible()

					if visible then
						gui.HideGameUI()
						mp_popuper.close()
						frame.Think = nil
					end
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
			frame.list.notFoundLabel = nil

			function frame.list:Refresh()
				local mediaPlayers = getMediaPlayers()

				if #mediaPlayers == 0 then
					if !IsValid( frame.list.notFoundLabel ) then
						local label = vgui.Create( 'DLabel', frame.list )
						frame.list.notFoundLabel = label
						label:SetText( 'No media players found' )
						label:SetContentAlignment( 5 )
						label:SetColor( color_white )
						label:Dock( TOP )
						label:SetTall( 25 )
					end
				else
					if IsValid( frame.list.notFoundLabel ) then
						frame.list.notFoundLabel:Remove()
						frame.list.notFoundLabel = nil
					end
				end

				for _, player in ipairs( mediaPlayers ) do
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

		do // Footer
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

			do // Mute Unfocused Toggle
				local muteUnfocused = {}
				frame.muteUnfocused = muteUnfocused

				muteUnfocused.frame = vgui.Create( 'DPanel', frame.footerFrame )
				muteUnfocused.frame:DockPadding( 0, 5, 0, 5 )
				muteUnfocused.frame.Paint = nil

				do // Mute Unfocused Checkbox
					muteUnfocused.checkbox = vgui.Create( 'DCheckBox', muteUnfocused.frame )
					muteUnfocused.checkbox:SetValue( GetConVar( MUTE_UNFOCUSED_CONVAR ):GetBool() )
					muteUnfocused.checkbox:Dock( RIGHT )

					function muteUnfocused.checkbox:OnChange( value )
						GetConVar( MUTE_UNFOCUSED_CONVAR ):SetBool( value )
					end
				end

				do // Mute Unfocused Label
					muteUnfocused.label = vgui.Create( 'DLabel', muteUnfocused.frame )
					muteUnfocused.label:SetText( MUTE_UNFOCUSED_DESCRIPTION )
					muteUnfocused.label:DockMargin( 0, 0, 5, 0 )
					muteUnfocused.label:Dock( FILL )
				end
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
