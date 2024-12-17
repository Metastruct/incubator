do return end -- remove this line

if not MetAchievements then return end

local Tag = "MetAchievements"
local id = "chat"

MetAchievements.RegisterAchievement(id, {
	title = "Chat Person",
	description = "Say something."
})

hook.Add("PlayerSay", Tag.."_"..id, function(ply)
	MetAchievements.UnlockAchievement(ply, id)
end)
