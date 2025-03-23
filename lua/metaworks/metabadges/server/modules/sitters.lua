if not MetaBadges then return end

local Tag = "MetaBadges"
local id = "sitters"

local levels = {
	default = {
		title = "Player Collector",
		description = "Total number of players who have sat on your head."
	}
}

MetaBadges.RegisterBadge(id, {
	basetitle = "Player Collector",
	levels = levels,
	level_interpolation = MetaBadges.INTERPOLATION_FLOOR
})

local function IsCustomSeat(seat)
	-- seat.IsSitVehicle: aowl/commands/easy_sit_on_player.lua:81
	-- seat.playerdynseat: sitanywhere/server/sit.lua:76
	return seat:GetClass() == "prop_vehicle_prisoner_pod" and (seat.IsSitVehicle or seat.playerdynseat)
end

local function FindRootPlayer(seat, depth)
	depth = (depth or 0) + 1

	local parent = seat:GetParent()
	if IsValid(seat) and IsCustomSeat(seat) and depth <= 64 and IsValid(parent) then
		return FindRootPlayer(parent, depth)
	end
	if IsValid(seat) and seat:IsPlayer() and not IsValid(parent) then
		return seat
	end
end

hook.Add("PlayerEnteredVehicle", Tag .. "_" .. id, function(_, veh)
	if not IsValid(veh) then return end
	if not IsCustomSeat(veh) then return end

	local root_player = FindRootPlayer(veh)
	-- Player sit on world or prop
	if not IsValid(root_player) then return end
	-- sitanywhere/helpers.lua:116
	local sitters = root_player:GetSitters()
	local sits_count = table.Count(sitters)
	local cur_level = MetaBadges.GetBadgeLevel(root_player, id) or 0

	if cur_level >= sits_count then return end
	MetaBadges.UpgradeBadge(root_player, id, sits_count, MetaBadges.VARIANT_SILENT)
end)