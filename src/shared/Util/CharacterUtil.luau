--!strict

local CharacterUtil = {}

function CharacterUtil.getHumanoid(character: Model): Humanoid?
	return character:FindFirstChildOfClass("Humanoid")
end

function CharacterUtil.getRoot(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RootPart then
		return humanoid.RootPart
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- R15: LowerTorso.Root, R6: HumanoidRootPart.RootJoint.
function CharacterUtil.getRootJoint(character: Model): Motor6D?
	local lowerTorso = character:FindFirstChild("LowerTorso")
	if lowerTorso then
		local joint = lowerTorso:FindFirstChild("Root")
		if joint and joint:IsA("Motor6D") then
			return joint
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local joint = root:FindFirstChild("RootJoint")
		if joint and joint:IsA("Motor6D") then
			return joint
		end
	end
	return nil
end

-- Distance from the root part's centre down to the soles of the feet.
function CharacterUtil.rootToFeet(humanoid: Humanoid, root: BasePart): number
	return humanoid.HipHeight + root.Size.Y / 2
end

function CharacterUtil.isAlive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

return CharacterUtil
