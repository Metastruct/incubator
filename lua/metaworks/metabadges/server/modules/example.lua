do return end -- remove this line

if not MetaBadges then return end

local Tag = "MetaBadges"    								-- used as a tag for hooks so we can identify them
local id = "spawn"          								-- id used by MetaBadges, it's also the filepath for the material so don't use spaces

MetaBadges.RegisterBadge (id, {
	basetitle = "You Spawned!",
	levels = {
		{ title = "First Spawn" },
		{ title = "Second Spawn" }
	}
})

hook.Add ("PlayerInitialSpawn", Tag.."_"..id, function (ply)
	if IsValid(ply) then
		MetaBadges.UpgradeBadge(ply, id, 1)					-- hardcoded example to give the first level only. Setting this to 3 will be invalid.
	end
end)

--[[
	to add an icon just add one under /materials/metabadges/{yourid}/{s1}/{x}.vmt/vtf

	{s1} being the icon_set you specified (by default 1)

	{x} being your level name if you just have a single one it would be default.vmt/vtf
		otherwise you can have an icon for each level: 1.vmt/vft and 2.vmt/vtf and so on
]]--

-----------------------------------------------------------------------------------------

local id = "full"

MetaBadges.RegisterBadge (id, {
	basetitle = "Fully Defined",                            -- Badge Title
	levels = {                                              -- Levels, accepts an array of levels and a default array.
		default = {											-- most badges just set a default level and then just increment that, no need to add them all yourself!
			title = "AFK",
			description = "This tracks the longest AFK session."
		},
	},

	--[[

	You can Specify Levels directly by giving them an index.
	if you don't add a default level, upgrading to a level that isn't specified will do nothing.
	for example:

	levels = {
		[1] = {
			title = "Something happened!",
		},
		[5] = {
			title = "Something happened 5 times!!"
		}
	}

	You can specify a default level and that will be used for all levels that aren't specified

	levels = {
		default = {
			title = "Join Streak",
			description = "You joined the server!"
		},
															-- level 1 - 6 will just print the above in this example
		[7] = {
			title = "Join Streak",
			description = "You've joined the server for a week!!1."
			xp = 20                                         -- you can also specify xp per level
		}
															-- all levels after 7 will also print the default
	}

	]]--

	level_interpolation = MetaBadges.INTERPOLATION_NONE,    -- how to handle level number interpolation there is _CEIL and _FLOOR, default is _NONE
	xp = function (level) return level end,                 -- amount of xp to give, can be function or number. Default is 10
	icon_set = 2                                            -- which iconset to use, 1 by default
})

--[[
	You can also modify the way the Badges unlock by specifiying a fourth parameter to the UpgradeBadge function.
		MetaBadges.UpgradeBadge(ply, id, level, >>variant<<)
	valid variants are:
		MetaBadges.VARIANT_NORMAL   -- normal unlock, just don't specify the parameter as it's the default
		MetaBadges.VARIANT_MINIMAL  -- if you've ever seen badges upgrade in quick succession? this prevents that and only upgrades once to the new level
		MetaBadges.VARIANT_SILENT   -- does not broadcast the badge upgrade to other players at all (for example the FPS badge)
]]--

-- todo: document observables for tracking stats (see daily_join_streak I guess) and getting MetAchievement stats