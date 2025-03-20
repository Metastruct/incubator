-- eat your friends.. for fun!
-- made by looking at various aowl examples to figure out how to make commands.

if CLIENT then
	CreateClientConVar("eating_disallow_command", 0, true, true)
	CreateClientConVar("eating_friends_only_command", 0, true, true)
	return
end

if SERVER then
	if aowl then
		local maxRange = 196 ^ 2
		local function CanEatPlayer(caller, targetPlayer)
			if not IsValid(targetPlayer) or not targetPlayer:IsPlayer() then
				return false, "That is not a player."
			end

			if not caller.Unrestricted then
				if caller:GetPos():DistToSqr(targetPlayer:GetPos()) > maxRange then
					return false, "You're too far away to eat this player."
				end

				if targetPlayer:GetInfoNum("eating_disallow_command", 0) == 1 then
					return false, "The player has disabled being eaten."
				end

				local friendOnly = targetPlayer:GetInfoNum("eating_friends_only_command", 0) == 1
				if friendOnly and friendsh.GetFriendStatus(caller:UserID(), targetPlayer:UserID()) ~= "friends" then
					return false, "The player only allows friends to eat them."
				end
			end

			return true
		end

		aowl.AddCommand("eat", "Eat your friends!", function(caller, line, target)
			local targetPlayer = aowl.FindPlayer(target)
			if not IsValid(targetPlayer) then
				return false, "Player not found."
			end

			local canEat, reason = CanEatPlayer(caller, targetPlayer)
			if not canEat then
				return false, reason
			end

			targetPlayer:KillSilent()

			if IsValid(caller) and caller.AddFatness then
				caller:AddFatness(1)
			end

			return true, "You have successfully eaten " .. targetPlayer:Nick() .. "."
		end, "players")
	end
end
