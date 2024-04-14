local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local resetDescription = ReplicatedStorage.Remotes.ResetDescription
local applyDescription = ReplicatedStorage.Remotes.ApplyDescription

local function serializeHumanoidDescription(description: HumanoidDescription)
	return {
		Accessories = description:GetAccessories(false),
		Animations = {
			ClimbAnimation = description.ClimbAnimation,
			FallAnimation = description.FallAnimation,
			IdleAnimation = description.IdleAnimation,
			JumpAnimation = description.JumpAnimation,
			MoodAnimation = description.MoodAnimation,
			RunAnimation = description.RunAnimation,
			SwimAnimation = description.SwimAnimation,
			WalkAnimation = description.WalkAnimation,
		},
		Scales = {
			HeightScale = description.HeightScale,
			WidthScale = description.WidthScale,
			HeadScale = description.HeadScale,
			BodyTypeScale = description.BodyTypeScale,
			ProportionScale = description.ProportionScale,
		},
		Colors = {
			HeadColor = { description.HeadColor.R, description.HeadColor.G, description.HeadColor.B },
			LeftArmColor = { description.LeftArmColor.R, description.LeftArmColor.G, description.LeftArmColor.B },
			LeftLegColor = { description.LeftLegColor.R, description.LeftLegColor.G, description.LeftLegColor.B },
			RightArmColor = { description.RightArmColor.R, description.RightArmColor.G, description.RightArmColor.B },
			RightLegColor = { description.RightLegColor.R, description.RightLegColor.G, description.RightLegColor.B },
			TorsoColor = { description.TorsoColor.R, description.TorsoColor.G, description.TorsoColor.B },
		},
		BodyParts = {
			Face = description.Face,
			Head = description.Head,
			LeftArm = description.LeftArm,
			LeftLeg = description.LeftLeg,
			RightArm = description.RightArm,
			RightLeg = description.RightLeg,
			Torso = description.Torso,
		},
		GraphicTShirt = description.GraphicTShirt,
		Shirt = description.Shirt,
		Pants = description.Pants,
	}
end

local function deserializeHumanoidDescription(serializedHumanoidDescription: { [string]: any })
	local description = Instance.new("HumanoidDescription")

	for i = #serializedHumanoidDescription.Accessories, 16, -1 do
		table.remove(serializedHumanoidDescription.Accessories)
	end

	description:SetAccessories(serializedHumanoidDescription.Accessories, false)

	for animationCategory, animationId in pairs(serializedHumanoidDescription.Animations) do
		description[animationCategory] = animationId
	end

	for scaleCategory, scale in pairs(serializedHumanoidDescription.Scales) do
		description[scaleCategory] = scale
	end

	for colorCategory, color in pairs(serializedHumanoidDescription.Colors) do
		description[colorCategory] = Color3.new(table.unpack(color))
	end

	for bodyPartCategory, bodyPartId in pairs(serializedHumanoidDescription.BodyParts) do
		description[bodyPartCategory] = bodyPartId
	end

	description.GraphicTShirt = serializedHumanoidDescription.GraphicTShirt
	description.Shirt = serializedHumanoidDescription.Shirt
	description.Pants = serializedHumanoidDescription.Pants

	return description
end

applyDescription.OnServerEvent:Connect(function(player, serializedHumanoidDescription)
	local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")

	if not humanoid then
		return
	end

	humanoid:ApplyDescription(deserializeHumanoidDescription(serializedHumanoidDescription))
end)

resetDescription.OnServerEvent:Connect(function(player)
	player.Character.Humanoid:ApplyDescription(Players:GetHumanoidDescriptionFromUserId(player.UserId))
end)
