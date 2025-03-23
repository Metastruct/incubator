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

hook.Add("PlayerEnteredVehicle", "%s_%s" % {Tag, id}, function(pl, veh)
	if not (IsValid(pl) and IsValid(veh)) then return end
	if not pl.IsPlayerSittingOn then return end
	if veh:GetClass() ~= "prop_vehicle_prisoner_pod" then return end
	-- veh.IsSitVehicle: aowl/commands/easy_sit_on_player.lua:81
	-- veh.playerdynseat: sitanywhere/server/sit.lua:76
	if not (veh.IsSitVehicle or veh.playerdynseat) then return end

	-- Idk if bots have badges, exclude them just in case
	for _, pl_iter in ipairs(player.GetHumans()) do
		-- Skip anyone who's not part of the tower
		-- sitanywhere/helpers.lua:153
		if not pl:IsPlayerSittingOn(pl_iter) then continue end

		-- sitanywhere/helpers.lua:116
		local sitters = pl_iter:GetSitters()
		local sits_count = table.Count(sitters)
		local cur_level = MetaBadges.GetBadgeLevel(pl_iter, id) or 0

		if cur_level >= sits_count then continue end
		MetaBadges.UpgradeBadge(pl_iter, id, sits_count)
	end
end)