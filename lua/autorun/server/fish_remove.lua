-- serverside: remove map fish entities (classes "fish" and "func_fish_pool")
-- so the clientside aquarium simulation is the only fish in the scene.
-- Gate on the "arcade" landmark: without it, do nothing at all.

pcall(require, "landmark")

if not LMVector or not landmark or type(landmark.get) ~= "function" or not landmark.get("arcade") then
	print("[fish_remove] landmark module / 'arcade' landmark unavailable; disabled")

	return
end

local FISH_CLASSES = {
	["fish"] = true,
	["func_fish_pool"] = true
}

local function RemoveFishEntities()
	local removed = 0

	for _, e in ipairs(ents.GetAll()) do
		if FISH_CLASSES[e:GetClass()] then
			e:Remove()
			removed = removed + 1
		end
	end

	if removed > 0 then
		print("[fish_remove] removed " .. removed .. " fish entities")
	end
end

hook.Add("InitPostEntity", "scratch_remove_fish", RemoveFishEntities)

-- catch any that spawn after the map has loaded (respawn/reset, late spawners)
hook.Add("OnEntityCreated", "scratch_remove_fish", function(e)
	if FISH_CLASSES[e:GetClass()] then
		e:Remove()
	end
end)
