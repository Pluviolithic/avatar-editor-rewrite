local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local saveDescription = ReplicatedStorage.Remotes.SaveDescription
local resetDescription = ReplicatedStorage.Remotes.ResetDescription
local applyDescription = ReplicatedStorage.Remotes.ApplyDescription

local allOutfitData = {}
local outfitDataStore = DataStoreService:GetDataStore("Outfits")

local enumLookupTable = {
	Enum.AccessoryType.Unknown,
	Enum.AccessoryType.Hat,
	Enum.AccessoryType.Hair,
	Enum.AccessoryType.Face,
	Enum.AccessoryType.Neck,
	Enum.AccessoryType.Shoulder,
	Enum.AccessoryType.Front,
	Enum.AccessoryType.Back,
	Enum.AccessoryType.Waist,
	Enum.AccessoryType.TShirt,
	Enum.AccessoryType.Shirt,
	Enum.AccessoryType.Pants,
	Enum.AccessoryType.Jacket,
	Enum.AccessoryType.Sweater,
	Enum.AccessoryType.Shorts,
	Enum.AccessoryType.LeftShoe,
	Enum.AccessoryType.RightShoe,
	Enum.AccessoryType.DressSkirt,
}

local function serializeHumanoidDescription(description: HumanoidDescription)
	return {
		Accessories = description:GetAccessories(true),
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

local function serializeForDataStore(serializedHumanoidDescription)
	for _, accessory in serializedHumanoidDescription.Accessories do
		accessory.AccessoryType = accessory.AccessoryType.Value
	end
	return serializedHumanoidDescription
end

local function deserializeFromDataStore(serializedHumanoidDescription)
	for _, accessory in serializedHumanoidDescription.Accessories do
		accessory.AccessoryType = enumLookupTable[accessory.AccessoryType]
	end
	return serializedHumanoidDescription
end

-- local function countIdsInString(IdString: string): number
-- 	return #IdString:split(",")
-- end
--

local function deserializeHumanoidDescription(serializedHumanoidDescription: { [string]: any }): HumanoidDescription
	local description = Instance.new("HumanoidDescription")

	for i = #serializedHumanoidDescription.Accessories, 16, -1 do
		table.remove(serializedHumanoidDescription.Accessories)
	end

	description:SetAccessories(serializedHumanoidDescription.Accessories, true)

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

local function fullSerialize(description: HumanoidDescription)
	return serializeForDataStore(serializeHumanoidDescription(description))
end

local function fullDeserialize(serializedHumanoidDescription)
	return deserializeHumanoidDescription(deserializeFromDataStore(serializedHumanoidDescription))
end

local function onPlayerAdded(player: Player)
	local outfitData = outfitDataStore:GetAsync(`Key_{player.UserId}`)

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	if outfitData then
		print(outfitData)
		if outfitData.CurrentOutfit then
			humanoid:ApplyDescription(fullDeserialize(outfitData.CurrentOutfit))
		end
		allOutfitData[player.UserId] = outfitData
	else
		allOutfitData[player.UserId] = {}
	end
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

saveDescription.OnServerEvent:Connect(function(player, serializedHumanoidDescription)
	local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")

	if not humanoid then
		return
	end

	humanoid:ApplyDescription(deserializeHumanoidDescription(serializedHumanoidDescription))
	allOutfitData[player.UserId].CurrentOutfit = serializeForDataStore(serializedHumanoidDescription)
	print(allOutfitData)
	outfitDataStore:SetAsync(`Key_{player.UserId}`, allOutfitData[player.UserId])
end)

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	outfitDataStore:SetAsync(`Key_{player.UserId}`, allOutfitData[player.UserId])
	allOutfitData[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
