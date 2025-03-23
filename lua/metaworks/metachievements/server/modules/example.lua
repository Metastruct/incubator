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

-- clientside example, see lua/metaworks/metachievements/client/example.lua

local id = "spawnmenu"

MetAchievements.RegisterAchievement(id, {
	title = "Opened the Spawn Menu!",
	description = "WOW you pressed Q!"
})

util.AddNetworkString(Tag.."_"..id) -- don't forget to add the networkstring serverside!

net.Receive(Tag.."_"..id, function(len, ply)
	MetAchievements.UnlockAchievement(ply, id)
end)