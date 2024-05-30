local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local addOutfit = ReplicatedStorage.Remotes.AddOutfit
local getOutfits = ReplicatedStorage.Remotes.GetOutfits
local deleteOutfit = ReplicatedStorage.Remotes.DeleteOutfit
local updateOutfit = ReplicatedStorage.Remotes.UpdateOutfit
local saveDescription = ReplicatedStorage.Remotes.SaveDescription
local resetDescription = ReplicatedStorage.Remotes.ResetDescription
local applyDescription = ReplicatedStorage.Remotes.ApplyDescription

local allOutfitData = {}
local outfitDataStore = DataStoreService:GetDataStore("Outfits2")

local enumLookupTable = {
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

local function deepCopy(original)
	local copy = {}

	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end

		copy[k] = v
	end

	return copy
end

local function serializeForDataStore(serializedHumanoidDescription)
	local serialized = deepCopy(serializedHumanoidDescription)
	for _, accessory in serialized.Accessories do
		accessory.AccessoryType = accessory.AccessoryType.Value
	end
	return serialized
end

local function deserializeFromDataStore(serializedHumanoidDescription)
	local deserialized = deepCopy(serializedHumanoidDescription)
	for _, accessory in deserialized.Accessories do
		accessory.AccessoryType = enumLookupTable[accessory.AccessoryType]
	end
	return deserialized
end

-- local function countIdsInString(IdString: string): number
-- 	return #IdString:split(",")
-- end
--

local function deserializeHumanoidDescription(serializedHumanoidDescription: { [string]: any }): HumanoidDescription
	local serialized = table.clone(serializedHumanoidDescription)
	local description = Instance.new("HumanoidDescription")

	for i = #serialized.Accessories, 16, -1 do
		table.remove(serialized.Accessories)
	end

	description:SetAccessories(serialized.Accessories, true)

	for animationCategory, animationId in pairs(serialized.Animations) do
		description[animationCategory] = animationId
	end

	for scaleCategory, scale in pairs(serialized.Scales) do
		description[scaleCategory] = scale
	end

	for colorCategory, color in pairs(serialized.Colors) do
		description[colorCategory] = Color3.new(table.unpack(color))
	end

	for bodyPartCategory, bodyPartId in pairs(serialized.BodyParts) do
		description[bodyPartCategory] = bodyPartId
	end

	description.GraphicTShirt = serialized.GraphicTShirt
	description.Shirt = serialized.Shirt
	description.Pants = serialized.Pants

	return description
end

-- local function fullSerialize(description: HumanoidDescription)
-- 	return serializeForDataStore(serializeHumanoidDescription(description))
-- end

local function fullDeserialize(serializedHumanoidDescription)
	return deserializeHumanoidDescription(deserializeFromDataStore(serializedHumanoidDescription))
end

local function onPlayerAdded(player: Player)
	local outfitData = outfitDataStore:GetAsync(`Key_{player.UserId}`)

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	if outfitData then
		if outfitData.CurrentOutfit then
			humanoid:ApplyDescription(fullDeserialize(outfitData.CurrentOutfit))
		end
		allOutfitData[player.UserId] = outfitData
	else
		allOutfitData[player.UserId] = {
			Outfits = {},
		}
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
	outfitDataStore:SetAsync(`Key_{player.UserId}`, allOutfitData[player.UserId])
end)

addOutfit.OnServerEvent:Connect(function(player, serializedHumanoidDescription)
	if allOutfitData[player.UserId] and #allOutfitData[player.UserId].Outfits < 10 then
		table.insert(allOutfitData[player.UserId].Outfits, serializeForDataStore(serializedHumanoidDescription))
	end
end)

deleteOutfit.OnServerEvent:Connect(function(player, outfitIndex)
	if allOutfitData[player.UserId] and #allOutfitData[player.UserId].Outfits >= outfitIndex then
		table.remove(allOutfitData[player.UserId].Outfits, outfitIndex)
	end
end)

updateOutfit.OnServerEvent:Connect(function(player, outfitIndex, serializedHumanoidDescription)
	if allOutfitData[player.UserId] and #allOutfitData[player.UserId].Outfits >= outfitIndex then
		allOutfitData[player.UserId].Outfits[outfitIndex] = serializeForDataStore(serializedHumanoidDescription)
	end
end)

getOutfits.OnServerInvoke = function(player)
	return allOutfitData[player.UserId] and allOutfitData[player.UserId].Outfits
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	outfitDataStore:SetAsync(`Key_{player.UserId}`, allOutfitData[player.UserId])
	allOutfitData[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
