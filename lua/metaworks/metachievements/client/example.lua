do return end -- don't add this in your code

local Tag = "MetAchievements"
local id = "spawnmenu"

local triggered = false

local function trigger()
    if triggered then return end -- don't send netmessage if it already happened
    net.Start(Tag..""..id)
    net.SendToServer()
    hook.Remove("OnSpawnMenuOpen", Tag.."_"..id)
    triggered = true
end

hook.Add("OnSpawnMenuOpen", Tag.."_"..id, trigger)