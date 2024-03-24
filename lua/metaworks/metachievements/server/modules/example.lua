-- taken from: https://gitlab.com/metastruct/internal/MetaWorks-metastruct/-/blob/master/lua/metaworks/metachievements/server/modules/bunnyhop.lua?ref_type=heads
do return end -- remove this line

if not MetAchievements then return end

local Tag = "MetAchievements"
local id = "bunnyhop"

MetAchievements.RegisterAchievement(id, {
	title = "Breakneck Pace",
	description = "Break the sound barrier by bunnyhopping."
})

util.AddNetworkString(Tag.."_"..id)

net.Receive(Tag.."_"..id, function(len, ply)
	local speed = ply:GetVelocity():Length()
	if speed >= 5000 and not ply:InVehicle() then
		MetAchievements.UnlockAchievement(ply, id) -- we're done here.
	else -- re-arm clientside
		net.Start(Tag.."_"..id)
		net.Send(ply)
	end
end)
