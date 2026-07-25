
local PANEL = {}

AccessorFunc( PANEL, "m_strModel", "Model" )

function PANEL:Init()

	self:SetSize( 762, 502 )
	self:SetTitle( "Model Viewer" )

	self:SetSizable( true )
	self:SetMinWidth( 650 )
	self:SetMinHeight( 270 )

	self:MakePopup()
	self:SetKeyboardInputEnabled( false )

	local left = self:Add( "Panel" )
	left:Dock( FILL )
	self.LeftPanel = left

		local previewCont = left:Add( "Panel" )
		previewCont:Dock( FILL )
		previewCont:DockMargin( 0, 0, 0, 4 )

		self.ModelPanel = previewCont:Add( "DAdjustableModelPanel" )
		self.ModelPanel.FarZ = 32768
		self.ModelPanel:Dock( FILL )

	local controls = left:Add( "Panel" )
	controls:SetTall( 64 )
	controls:Dock( BOTTOM )

		local controls_anim = controls:Add( "Panel" )
		controls_anim:SetTall( 20 )
		controls_anim:Dock( TOP )
		controls_anim:DockMargin( 0, 0, 0, 4 )
		controls_anim:MoveToBack()

			self.AnimTrack = controls_anim:Add( "DSlider" )
			self.AnimTrack:Dock( FILL )
			self.AnimTrack:SetNotches( 100 )
			self.AnimTrack:SetTrapInside( true )
			self.AnimTrack:SetLockY( 0.5 )

			self.AnimPause = controls_anim:Add( "DImageButton" )
			self.AnimPause:SetImage( "icon16/control_pause_blue.png" )
			self.AnimPause:SetStretchToFit( false )
			self.AnimPause:SetPaintBackground( true )
			self.AnimPause:SetIsToggle( true )
			self.AnimPause:SetToggle( false )
			self.AnimPause:Dock( LEFT )
			self.AnimPause:SetWide( 32 )

		local BestGuess = controls:Add( "DImageButton" )
		BestGuess:SetImage( "icon32/wand.png" )
		BestGuess:SetStretchToFit( false )
		BestGuess:SetPaintBackground( true )
		BestGuess.DoClick = function() self:BestGuessLayout() end
		BestGuess:Dock( LEFT )
		BestGuess:DockMargin( 0, 0, 0, 0 )
		BestGuess:SetWide( 50 )
		BestGuess:SetTooltip( "Best Guess" )

		local FullFrontal = controls:Add( "DImageButton" )
		FullFrontal:SetImage( "icon32/hand_point_090.png" )
		FullFrontal:SetStretchToFit( false )
		FullFrontal:SetPaintBackground( true )
		FullFrontal.DoClick = function() self:FullFrontalLayout() end
		FullFrontal:Dock( LEFT )
		FullFrontal:DockMargin( 2, 0, 0, 0 )
		FullFrontal:SetWide( 50 )
		FullFrontal:SetTooltip( "Front" )

		local Above = controls:Add( "DImageButton" )
		Above:SetImage( "icon32/hand_property.png" )
		Above:SetStretchToFit( false )
		Above:SetPaintBackground( true )
		Above.DoClick = function() self:AboveLayout() end
		Above:Dock( LEFT )
		Above:DockMargin( 2, 0, 0, 0 )
		Above:SetWide( 50 )
		Above:SetTooltip( "Above" )

		local Right = controls:Add( "DImageButton" )
		Right:SetImage( "icon32/hand_point_180.png" )
		Right:SetStretchToFit( false )
		Right:SetPaintBackground( true )
		Right.DoClick = function() self:RightLayout() end
		Right:Dock( LEFT )
		Right:DockMargin( 2, 0, 0, 0 )
		Right:SetWide( 50 )
		Right:SetTooltip( "Right" )

		local Origin = controls:Add( "DImageButton" )
		Origin:SetImage( "icon32/hand_point_090.png" )
		Origin:SetStretchToFit( false )
		Origin:SetPaintBackground( true )
		Origin.DoClick = function() self:OriginLayout() end
		Origin:Dock( LEFT )
		Origin:DockMargin( 2, 0, 0, 0 )
		Origin:SetWide( 50 )
		Origin:SetTooltip( "Center" )

	local right = self:Add( "DPropertySheet" )
	right:Dock( RIGHT )
	right:SetPadding( 0 )
	right:DockMargin( 4, 0, 0, 0 )
	right:SetWide( 268 )
	self.PropertySheet = right

	-- Animations

	local anims = right:Add( "Panel" )
	anims:Dock( FILL )
	anims:DockPadding( 2, 0, 2, 2 )
	right:AddSheet( "Animations", anims, "icon16/monkey.png" )

		self.AnimList = anims:Add( "DListView" )
		self.AnimList:AddColumn( "name" )
		self.AnimList:Dock( FILL )
		self.AnimList:SetMultiSelect( false )
		self.AnimList:SetHideHeaders( true )

		self.AnimList.OnRowSelected = function( _, _, line )
			local ent = self.ModelPanel:GetEntity()
			if ( !IsValid( ent ) ) then return end

			local speed = ent:GetPlaybackRate()
			ent:ResetSequence( line:GetColumnText( 1 ) )
			ent:SetCycle( 0 )
			ent:SetPlaybackRate( speed )
			if ( speed < 0 ) then ent:SetCycle( 1 ) end
		end

		self.AnimList.OnRowRightClick = function( _, _, line )
			local menu = DermaMenu( false, line )

			menu:AddOption( "Copy", function()
				SetClipboardText( line:GetColumnText( 1 ) )
			end ):SetIcon("icon16/page_copy.png")

			menu:Open()
		end

		self.AnimSearch = anims:Add( "DTextEntry" )
		self.AnimSearch:Dock( TOP )
		self.AnimSearch:DockMargin( 0, 0, 0, 2 )
		self.AnimSearch:SetPlaceholderText( "Filter..." )
		self.AnimSearch.OnChange = function( p )
			local ent = self.ModelPanel:GetEntity()
			if ( !IsValid( ent ) ) then return end

			self:FillAnimations( ent, p:GetText() )
		end

	-- Bodygroups

	local pnl = right:Add( "Panel" )
	pnl:Dock( FILL )
	pnl:DockPadding( 7, 0, 7, 7 )

	self.BodygroupTab = right:AddSheet( "Bodygroups", pnl, "icon16/brick.png" )

		self.BodyList = pnl:Add( "DScrollPanel" )
		self.BodyList:Dock( FILL )

	-- Settings

	local settings = right:Add( "Panel" )
	settings:Dock( FILL )
	settings:DockPadding( 7, 0, 7, 7 )
	right:AddSheet( "Settings", settings, "icon16/cog.png" )

		local bbox = settings:Add( "DCheckBoxLabel" )
		bbox:SetText( "Show Bounding Box" )
		bbox:Dock( TOP )
		bbox:DockMargin( 0, 0, 0, 3 )
		bbox:SetDark( true )
		bbox:SetCookieName( "model_viewer_bbox" )
		self.ShowBBoxPnl = bbox

		local origin = settings:Add( "DCheckBoxLabel" )
		origin:SetText( "Show Origin" )
		origin:Dock( TOP )
		origin:SetDark( true )
		origin:SetCookieName( "model_viewer_origin" )
		self.ShowOriginPnl = origin

		local playSpeed = settings:Add( "DNumSlider" )
		playSpeed:SetText( "Playback Speed" )
		playSpeed:Dock( TOP )
		playSpeed:SetValue( 1 )
		playSpeed:SetMinMax( -1, 2 )
		playSpeed:SetDark( true )
		playSpeed.OnValueChanged = function( s, value )
			self.ModelPanel:GetEntity():SetPlaybackRate( value )
		end

		local moveSpeed = settings:Add( "DNumSlider" )
		moveSpeed:SetText( "Move Speed" )
		moveSpeed:Dock( TOP )
		moveSpeed:SetMinMax( 0.5, 8 )
		moveSpeed:SetValue( 1 )
		moveSpeed:SetDark( true )
		moveSpeed.OnValueChanged = function( p )
			self.ModelPanel:SetMovementScale( p:GetValue() )
		end
		moveSpeed:SetCookieName( "modelviewer_movespeed" )

		local angle = settings:Add( "DTextEntry" )
		angle:SetTooltip( "Entity Angles" )
		angle:Dock( TOP )
		angle:DockMargin( 0, 0, 0, 3 )
		angle:SetZPos( 100 )
		angle.OnChange = function( p )
			self.ModelPanel:GetEntity():SetAngles( Angle( p:GetText() ) )
		end
		self.TargetAnglePanel = angle

		local cam_angle = settings:Add( "DTextEntry" )
		cam_angle:SetTooltip( "Camera Angles" )
		cam_angle:Dock( TOP )
		cam_angle:DockMargin( 0, 0, 0, 3 )
		cam_angle:SetZPos( 101 )
		cam_angle.OnChange = function( p )
			self.ModelPanel:SetLookAng( Angle( p:GetText() ) )
		end
		self.TargetCamAnglePanel = cam_angle

		local cam_pos = settings:Add( "DTextEntry" )
		cam_pos:SetTooltip( "Camera Position" )
		cam_pos:Dock( TOP )
		cam_pos:DockMargin( 0, 0, 0, 3 )
		cam_pos:SetZPos( 102 )
		cam_pos.OnChange = function( p )
			self.ModelPanel:SetCamPos( Vector( p:GetText() ) )
		end
		self.TargetCamPosPanel = cam_pos

		local cam_fov = settings:Add( "DNumSlider" )
		cam_fov:SetText( "Camera FOV" )
		cam_fov:Dock( TOP )
		cam_fov:DockMargin( 0, 0, 0, 3 )
		cam_fov:SetZPos( 103 )
		cam_fov:SetMinMax( 0.001, 179 )
		cam_fov:SetDark( true )
		cam_fov.OnValueChanged = function( p )
			self.ModelPanel:SetFOV( p:GetValue() )
		end
		self.TargetCamFOVPanel = cam_fov

		local labels = { "Pitch", "Yaw", "Roll" }
		for i = 1, 3 do
			local rotate45 = settings:Add( "DButton" )
			rotate45:SetText( "Rotate Entity +/-45 " .. labels[ i ] )
			rotate45:Dock( TOP )
			rotate45:DockMargin( 0, 0, 0, 3 )
			rotate45:SetZPos( 110 + i )
			rotate45.DoClick = function( p )
				local aang = self.ModelPanel:GetEntity():GetAngles()
				aang[ i ] = aang[ i ] + 45
				self.ModelPanel:GetEntity():SetAngles( aang )
			end
			rotate45.DoRightClick = function( p )
				local aang = self.ModelPanel:GetEntity():GetAngles()
				aang[ i ] = aang[ i ] - 45
				self.ModelPanel:GetEntity():SetAngles( aang )
			end
		end
end

function PANEL:OnKeyCodePressed( code )
	if ( code != KEY_UP && code != KEY_DOWN ) then return end

	local line = self.AnimList:GetSelectedLine()
	if ( !line ) then return end
	local direction = code == KEY_UP && -1 or 1

	line = self.AnimList:GetLine( line + direction )
	if ( !IsValid( line ) ) then return end

	self.AnimList:ClearSelection()
	self.AnimList:SelectItem( line )
end

function PANEL:SetDefaultLighting()

	self.ModelPanel:SetAmbientLight( Color( 255 * 0.3, 255 * 0.3, 255 * 0.3 ) )

	self.ModelPanel:SetDirectionalLight( BOX_FRONT, Color( 255 * 1.3, 255 * 1.3, 255 * 1.3 ) )
	self.ModelPanel:SetDirectionalLight( BOX_BACK, Color( 255 * 0.2, 255 * 0.2, 255 * 0.2 ) )
	self.ModelPanel:SetDirectionalLight( BOX_RIGHT, Color( 255 * 0.2, 255 * 0.2, 255 * 0.2 ) )
	self.ModelPanel:SetDirectionalLight( BOX_LEFT, Color( 255 * 0.2, 255 * 0.2, 255 * 0.2 ) )
	self.ModelPanel:SetDirectionalLight( BOX_TOP, Color( 255 * 2.3, 255 * 2.3, 255 * 2.3 ) )
	self.ModelPanel:SetDirectionalLight( BOX_BOTTOM, Color( 255 * 0.1, 255 * 0.1, 255 * 0.1 ) )

end

function PANEL:BestGuessLayout()

	local ent = self.ModelPanel:GetEntity()
	if ( !IsValid( ent ) ) then return end

	local pos = ent:GetPos()
	local ang = ent:GetAngles()

	local tab = PositionSpawnIcon( ent, pos, true )

	ent:SetAngles( ang )
	if ( tab ) then
		self.ModelPanel:SetCamPos( tab.origin )
		self.ModelPanel:SetFOV( tab.fov )
		self.ModelPanel:SetLookAng( tab.angles )
	end

end

function PANEL:FullFrontalLayout()

	local ent = self.ModelPanel:GetEntity()
	if ( !IsValid( ent ) ) then return end

	local pos = ent:GetPos()
	local campos = pos + Vector( -200, 0, 0 )

	self.ModelPanel:SetCamPos( campos )
	self.ModelPanel:SetFOV( 45 )
	self.ModelPanel:SetLookAng( ( campos * -1 ):Angle() )

end

function PANEL:AboveLayout()

	local ent = self.ModelPanel:GetEntity()
	if ( !IsValid( ent ) ) then return end

	local pos = ent:GetPos()
	local campos = pos + Vector( 0, 0, 200 )

	self.ModelPanel:SetCamPos( campos )
	self.ModelPanel:SetFOV( 45 )
	self.ModelPanel:SetLookAng( ( campos * -1 ):Angle() )

end

function PANEL:RightLayout()

	local ent = self.ModelPanel:GetEntity()
	if ( !IsValid( ent ) ) then return end

	local pos = ent:GetPos()
	local campos = pos + Vector( 0, 200, 0 )

	self.ModelPanel:SetCamPos( campos )
	self.ModelPanel:SetFOV( 45 )
	self.ModelPanel:SetLookAng( ( campos * -1 ):Angle() )

end

function PANEL:OriginLayout()

	local ent = self.ModelPanel:GetEntity()
	if ( !IsValid( ent ) ) then return end

	local pos = ent:GetPos()
	local campos = pos + vector_origin

	self.ModelPanel:SetCamPos( campos )
	self.ModelPanel:SetFOV( 45 )
	self.ModelPanel:SetLookAng( Angle( 0, -180, 0 ) )

end

function PANEL:UpdateEntity( ent )

	ent:SetEyeTarget( self.ModelPanel:GetCamPos() )

	if ( IsValid( self.TargetAnglePanel ) && !self.TargetAnglePanel:IsEditing() && !self.TargetAnglePanel:IsHovered() ) then
		self.TargetAnglePanel:SetText( tostring( ent:GetAngles() ) )
	end
	if ( IsValid( self.TargetCamAnglePanel ) && !self.TargetCamAnglePanel:IsEditing() && !self.TargetCamAnglePanel:IsHovered() ) then
		self.TargetCamAnglePanel:SetText( tostring( self.ModelPanel:GetLookAng() ) )
	end
	if ( IsValid( self.TargetCamPosPanel ) && !self.TargetCamPosPanel:IsEditing() && !self.TargetCamPosPanel:IsHovered() ) then
		self.TargetCamPosPanel:SetText( tostring( self.ModelPanel:GetCamPos() ) )
	end
	if ( IsValid( self.TargetCamFOVPanel ) && !self.TargetCamFOVPanel:IsEditing() && !self.TargetCamFOVPanel:IsHovered() ) then
		self.TargetCamFOVPanel:SetValue( self.ModelPanel:GetFOV() )
	end

	if ( self.AnimTrack:GetDragging() ) then

		ent:SetCycle( self.AnimTrack:GetSlideX() )
		self.AnimPause:SetToggle( true )

	elseif ( ent:GetCycle() != self.AnimTrack:GetSlideX() ) then

		local cyc = ent:GetCycle()
		if ( cyc < 0 ) then cyc = cyc + 1 end
		self.AnimTrack:SetSlideX( cyc )

	end

	if ( !self.AnimPause:GetToggle() ) then
		ent:FrameAdvance( FrameTime() )
	end

end

function PANEL:Refresh()

	CloseDermaMenus()

	if ( !self:GetModel() ) then return end

	self.ModelPanel:SetModel( self:GetModel() )
	self.ModelPanel.LayoutEntity = function() self:UpdateEntity( self.ModelPanel:GetEntity() )  end

	local ent = self.ModelPanel:GetEntity()
	if ( !IsValid( ent ) ) then return end

	ent:SetLOD( 0 )

	self:BestGuessLayout()
	self:FillAnimations( ent, self.AnimSearch:GetText() )
	self:SetDefaultLighting()

end

function PANEL:FillAnimations( ent, filter )

	self.AnimList:Clear()

	local sequences = {}
	for i = 0, ent:GetSequenceCount() - 1 do
		local seq = ent:GetSequenceName( i )
		if ( !seq ) then continue end

		seq = string.lower( seq )

		if ( filter && !string.find( seq:lower(), filter:lower(), 1, true ) ) then continue end

		table.insert( sequences, seq )
	end

	for k, v in SortedPairsByValue( sequences ) do

		self.AnimList:AddLine( v )

	end

	self.BodyList:Clear()
	local newItems = 0

	if ( ent:SkinCount() > 1 ) then

		local skinSlider = self.BodyList:Add( "DNumSlider" )
		skinSlider:Dock( TOP )
		skinSlider:DockMargin( 0, 0, 0, 3 )
		skinSlider:SetText( "Skin" )
		skinSlider:SetDark( true )
		skinSlider:SetDecimals( 0 )
		skinSlider:SetMinMax( 0, ent:SkinCount() - 1 )
		skinSlider:SetValue( ent:GetSkin() )
		skinSlider.OnValueChanged = function( s, newVal )
			newVal = math.Round( newVal )
			ent:SetSkin( newVal )
		end
		newItems = newItems + 1

	end

	for k = 0, ent:GetNumBodyGroups() - 1 do

		if ( ent:GetBodygroupCount( k ) <= 1 ) then continue end

		local bgSlider = self.BodyList:Add( "DNumSlider" )
		bgSlider:Dock( TOP )
		bgSlider:DockMargin( 0, 0, 0, 3 )
		bgSlider:SetDark( true )
		bgSlider:SetDecimals( 0 )
		bgSlider:SetText( ent:GetBodygroupName( k ) )
		bgSlider:SetMinMax( 0, ent:GetBodygroupCount( k ) - 1 )
		bgSlider:SetValue( ent:GetBodygroup( k ) )
		bgSlider.BodyGroupID = k
		bgSlider.OnValueChanged = function( s, newVal )
			newVal = math.Round( newVal )
			ent:SetBodygroup( s.BodyGroupID, newVal )
		end
		newItems = newItems + 1

	end

	if ( newItems > 0 ) then
		self.BodygroupTab.Tab:SetVisible( true )
	else
		self.BodygroupTab.Tab:SetVisible( false )
	end
	local propertySheet = self.PropertySheet
	propertySheet.tabScroller:InvalidateLayout()

end

function PANEL:SetModelPath( path )

	self:SetModel( path )
	self:Refresh()

end

vgui.Register( "LoadedModelBrowserViewer", PANEL, "DFrame" )
