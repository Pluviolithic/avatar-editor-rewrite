local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Common.lib.Janitor)
local Slider = require(ReplicatedStorage.Common.lib.slidermodule)

local outfits = nil
local currentPage = 0
local currentResults = nil
local accessoryLimit = 15
local currentCategory = ""
local currentSearchString = ""
local currentDescription = nil
local starterDescription = nil
local scrollingRefreshDebounce = false

local player = Players.LocalPlayer
local scaleObliterator = Janitor.new()
local slotsObliterator = Janitor.new()
local wearingObliterator = Janitor.new()
local outfitsObliterator = Janitor.new()
local mainDisplayFrameObliterator = Janitor.new()
local editor = player.PlayerGui:WaitForChild("EditAvatar")

local slotTemplate = editor.Main.Slots.Template:Clone()
local itemTemplate = editor.Main.MainFrame.Items.Template:Clone()
local outfitTemplate = editor.Main.OutfitsFrame.Items.Template:Clone()

local addOutfit = ReplicatedStorage.Remotes.AddOutfit
local getOutfits = ReplicatedStorage.Remotes.GetOutfits
local deleteOutfit = ReplicatedStorage.Remotes.DeleteOutfit
local updateOutfit = ReplicatedStorage.Remotes.UpdateOutfit
local saveDescription = ReplicatedStorage.Remotes.SaveDescription
local resetDescription = ReplicatedStorage.Remotes.ResetDescription
local applyDescription = ReplicatedStorage.Remotes.ApplyDescription

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

local accessoryTypeRemaps = {
	["3DDress"] = Enum.AccessoryType.DressSkirt,
	["3DLeftShoe"] = Enum.AccessoryType.LeftShoe,
	["3DPants"] = Enum.AccessoryType.Pants,
	["3DRightShoe"] = Enum.AccessoryType.RightShoe,
	["3DShorts"] = Enum.AccessoryType.Shorts,

	["3DJacket"] = Enum.AccessoryType.Jacket,
	["3DShirt"] = Enum.AccessoryType.Shirt,
	["3DSweater"] = Enum.AccessoryType.Sweater,
	["3DTShirt"] = Enum.AccessoryType.TShirt,

	["BackAccessory"] = Enum.AccessoryType.Back,
	["FaceAccessory"] = Enum.AccessoryType.Face,
	["FrontAccessory"] = Enum.AccessoryType.Front,
	["HairAccessory"] = Enum.AccessoryType.Hair,
	["HatAccessory"] = Enum.AccessoryType.Hat,
	["NeckAccessory"] = Enum.AccessoryType.Neck,
	["ShouldersAccessory"] = Enum.AccessoryType.Shoulder,
	["WaistAccessory"] = Enum.AccessoryType.Waist,
}

local avatarAssetTypeRemaps = {
	["3DDress"] = Enum.AvatarAssetType.DressSkirtAccessory,
	["3DLeftShoe"] = Enum.AvatarAssetType.LeftShoeAccessory,
	["3DPants"] = Enum.AvatarAssetType.PantsAccessory,
	["3DRightShoe"] = Enum.AvatarAssetType.RightShoeAccessory,
	["3DShorts"] = Enum.AvatarAssetType.ShortsAccessory,

	["3DJacket"] = Enum.AvatarAssetType.JacketAccessory,
	["3DShirt"] = Enum.AvatarAssetType.ShirtAccessory,
	["3DSweater"] = Enum.AvatarAssetType.SweaterAccessory,
	["3DTShirt"] = Enum.AvatarAssetType.TShirtAccessory,
}

function map(x, inMin, inMax, outMin, outMax)
	return outMin + (x - inMin) * (outMax - outMin) / (inMax - inMin)
end

local function getAdjustedCameraAngle(angle: Vector2)
	return CFrame.Angles(0, math.rad(angle.X), 0)
		* CFrame.Angles(0, math.rad(angle.Y), 0)
		* CFrame.Angles(0, math.pi, 0)
		* CFrame.new(Vector3.new(0, 0, 6))
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

local function deserializeFromDataStore(serializedHumanoidDescription)
	local deserialized = deepCopy(serializedHumanoidDescription)
	for _, accessory in deserialized.Accessories do
		accessory.AccessoryType = enumLookupTable[accessory.AccessoryType]
	end
	return deserialized
end

local function fullDeserialize(serializedHumanoidDescription)
	return deserializeHumanoidDescription(deserializeFromDataStore(serializedHumanoidDescription))
end

local function clearDisplayFrame(frame: ScrollingFrame)
	for _, itemDisplay in ipairs(frame:GetChildren()) do
		if itemDisplay:IsA("ImageLabel") then
			itemDisplay:Destroy()
		end
	end
end

local function closeAllFrames()
	for _, element in ipairs(editor.Main:GetChildren()) do
		if element.Name:match("Frame") then
			element.Visible = false
		end
	end
end

local function resetUI()
	slotsObliterator:Cleanup()
	scaleObliterator:Cleanup()
	wearingObliterator:Cleanup()
	outfitsObliterator:Cleanup()
	mainDisplayFrameObliterator:Cleanup()

	closeAllFrames()

	currentPage = 0
	currentResults = nil

	editor.Main.AccessoryFrame.Visible = true
	editor.Main.MainFrame.Visible = true
	editor.Main.MainFrame.Search.Text = ""
end

local function getItemIndex(list: { { [string]: any } }, itemId: number): number?
	for index, equippedItem in ipairs(list) do
		if equippedItem.AssetId == itemId then
			return index
		end
	end
	return nil
end

local function hasItemEquipped(description: HumanoidDescription, itemId: number): boolean
	if getItemIndex(description:GetAccessories(true), itemId) then
		return true
	end

	return tonumber(description.Pants) == itemId
		or tonumber(description.Shirt) == itemId
		or tonumber(description.GraphicTShirt) == itemId
end

local function fixOrderFromIndex(list: { { [string]: any } }, index: number)
	for i = index, #list do
		if list[i].Order then
			list[i].Order -= 1
		end
	end
end

-- local function countAccessoriesOfType(list: { { [string]: any } }, accessoryType: Enum.AvatarAssetType)
-- 	local count = 0
-- 	for _, accessory in ipairs(list) do
-- 		if accessory.AccessoryType == accessoryType then
-- 			count += 1
-- 		end
-- 	end
-- 	return count
-- end
--

local function unequipItem(description: HumanoidDescription, itemId: number)
	local accessories = description:GetAccessories(true)
	local slotDisplay = editor.Main.Slots:FindFirstChild(itemId)
	local itemDisplay = editor.Main.MainFrame.Items:FindFirstChild(itemId)
	local itemIndex = getItemIndex(accessories, itemId)

	if itemIndex then
		table.remove(accessories, itemIndex)
		fixOrderFromIndex(accessories, itemIndex)
		description:SetAccessories(accessories, true)
	else
		if description.Pants == itemId then
			description.Pants = 868697782
		elseif description.Shirt == itemId then
			description.Shirt = 868697637
		elseif description.GraphicTShirt == itemId then
			description.GraphicTShirt = 0
		elseif description.Face == itemId then
			description.Face = 144075659
		end
	end

	if slotDisplay then
		slotDisplay:Destroy()
	end

	if itemDisplay then
		itemDisplay.Equipped.Visible = false
	end

	applyDescription:FireServer(serializeHumanoidDescription(description))
end

local function createSlotForItem(itemId: number)
	if editor.Main.Slots:FindFirstChild(itemId) then
		return
	end

	local slotDisplay = slotTemplate:Clone()

	slotDisplay.Item.Image = `http://www.roblox.com/Thumbs/Asset.ashx?width=110&height=110&assetId={itemId}`
	slotDisplay.Name = itemId
	slotDisplay.Parent = editor.Main.Slots
	slotsObliterator:Add(slotDisplay)

	slotDisplay.Item.Activated:Connect(function()
		unequipItem(currentDescription, itemId)
	end)
end

local function getMapOfEquippedItemsFromCategory(category: string, description: HumanoidDescription)
	if category == "Pants" or category == "Shirt" or category == "GraphicTShirt" then
		return { [description[category]] = true }
	end

	local equippedMap = {}
	if category:match("Accessory") then
		if description[category] == "" then
			return equippedMap
		end

		for _, stringId in ipairs((description[category] :: string):split(",")) do
			equippedMap[tonumber(stringId)] = true
		end

		return equippedMap
	end

	for _, item in ipairs(description:GetAccessories(false)) do
		if item.AccessoryType == accessoryTypeRemaps[category] then
			equippedMap[item.AssetId] = true
		end
	end

	return equippedMap
end

local function getAllEquippedItems(description: HumanoidDescription)
	local list = description:GetAccessories(true)

	if description.Pants > 0 then
		table.insert(list, { AssetId = description.Pants })
	end

	if description.Shirt > 0 then
		table.insert(list, { AssetId = description.Shirt })
	end

	if description.GraphicTShirt > 0 then
		table.insert(list, { AssetId = description.GraphicTShirt })
	end

	if description.Face > 0 then
		table.insert(list, { AssetId = description.Face })
	end

	return list
end

local function displayCurrentlyWearing()
	for _, item in ipairs(getAllEquippedItems(currentDescription)) do
		local itemDisplay = itemTemplate:Clone()

		itemDisplay.Name = item.AssetId
		itemDisplay.Item.Image = `http://www.roblox.com/Thumbs/Asset.ashx?width=110&height=110&assetId={item.AssetId}`

		itemDisplay.Item.Activated:Connect(function()
			unequipItem(currentDescription, item.AssetId)
			itemDisplay:Destroy()
		end)

		itemDisplay.Parent = editor.Main.WearingFrame.Items
		wearingObliterator:Add(itemDisplay)
	end
end

local function displayOutfits()
	for i, outfit in ipairs(outfits) do
		local outfitDisplay = outfitTemplate:Clone()
		outfitsObliterator:Add(outfitDisplay)
		outfitDisplay.Parent = editor.Main.OutfitsFrame.Items

		if typeof(outfit) ~= "table" then
			local camera = Instance.new("Camera")
			local characterDisplay = Players:CreateHumanoidModelFromDescription(outfit, Enum.HumanoidRigType.R15)

			camera.CFrame = characterDisplay.Humanoid.RootPart.CFrame * getAdjustedCameraAngle(Vector2.new())
			camera.Parent = outfitDisplay.Character

			outfitDisplay.Character.CurrentCamera = camera
			characterDisplay.Parent = outfitDisplay.Character.WorldModel
			characterDisplay.Humanoid:ApplyDescription(outfit)

			task.spawn(function()
				local angle = Vector2.new()
				while outfitDisplay.Parent do
					angle = angle + Vector2.new(0.5, 0)
					outfitDisplay.Character.CurrentCamera.CFrame = outfitDisplay.Character.WorldModel:FindFirstChildWhichIsA(
						"Model"
					).Humanoid.RootPart.CFrame * getAdjustedCameraAngle(angle)
					task.wait()
				end
			end)
		end

		outfitDisplay.Delete.Activated:Connect(function()
			table.remove(outfits, i)
			deleteOutfit:FireServer(i)
			outfitDisplay:Destroy()
		end)

		outfitDisplay.Update.Activated:Connect(function()
			updateOutfit:FireServer(i, serializeHumanoidDescription(currentDescription))
			outfits[i] = currentDescription:Clone()
			local characterClone = outfitDisplay.Character.WorldModel:FindFirstChildWhichIsA("Model")
				or player.Character:Clone()
			characterClone.Parent = outfitDisplay.Character.WorldModel
			characterClone.Humanoid:ApplyDescription(currentDescription)
		end)
	end
end

local function displayResultsInFrame(frame: ScrollingFrame)
	local page = currentResults:GetCurrentPage()
	local missingSlots = getMapOfEquippedItemsFromCategory(currentCategory, currentDescription)

	currentPage += 1

	for _, item in ipairs(page) do
		local itemDisplay = itemTemplate:Clone()

		itemDisplay.Name = item.Id
		itemDisplay.Item.Image = `http://www.roblox.com/Thumbs/Asset.ashx?width=110&height=110&assetId={item.Id}`

		if hasItemEquipped(currentDescription, item.Id) then
			itemDisplay.Equipped.Visible = true
			createSlotForItem(item.Id)
			missingSlots[item.Id] = nil
		end

		itemDisplay.Item.Activated:Connect(function()
			if currentCategory == "Shirt" or currentCategory == "Pants" or currentCategory == "GraphicTShirt" then
				slotsObliterator:Cleanup()
				if hasItemEquipped(currentDescription, item.Id) then
					currentDescription[currentCategory] = 0
					itemDisplay.Equipped.Visible = false
					return
				end
				createSlotForItem(item.Id)
				itemDisplay.Equipped.Visible = true
				currentDescription[currentCategory] = item.Id
				applyDescription:FireServer(serializeHumanoidDescription(currentDescription))
				return
			end

			local accessories = currentDescription:GetAccessories(true)
			local itemIndex = getItemIndex(accessories, item.Id)

			if itemIndex then
				unequipItem(currentDescription, item.Id)
				return
			elseif #accessories < accessoryLimit then
				table.insert(accessories, {
					AssetId = item.Id,
					IsLayered = if accessoryTypeRemaps[currentCategory] then true else false,
					AccessoryType = accessoryTypeRemaps[currentCategory] or Enum.AccessoryType[currentCategory],
					Order = if accessoryTypeRemaps[currentCategory]
						then #currentDescription:GetAccessories(false) + 1
						else nil,
				})
				itemDisplay.Equipped.Visible = true
				createSlotForItem(item.Id)
			end

			currentDescription:SetAccessories(accessories, true)
			applyDescription:FireServer(serializeHumanoidDescription(currentDescription))
		end)

		mainDisplayFrameObliterator:Add(itemDisplay)
		itemDisplay.Parent = frame
	end

	if currentPage == 1 then
		for itemId in pairs(missingSlots) do
			createSlotForItem(itemId)
		end
	end
end

local function search(text: string?): CatalogPages
	local searchParameters = CatalogSearchParams.new()

	searchParameters.Limit = 60
	searchParameters.AssetTypes = { avatarAssetTypeRemaps[currentCategory] or Enum.AvatarAssetType[currentCategory] }
	if text then
		searchParameters.SearchKeyword = text
	end

	return AvatarEditorService:SearchCatalog(searchParameters)
end

local function openCategory(categoryName: string, searchString: string)
	if currentCategory == categoryName and searchString ~= currentSearchString then
		return
	end
	currentCategory = categoryName

	local scrollingFrame = editor.Main.MainFrame.Items

	slotsObliterator:Cleanup()
	wearingObliterator:Cleanup()
	outfitsObliterator:Cleanup()
	mainDisplayFrameObliterator:Cleanup()

	currentSearchString = searchString

	currentResults = search(searchString)
	displayResultsInFrame(scrollingFrame)

	mainDisplayFrameObliterator:Add(function()
		currentPage = 0
		currentResults = nil
		currentSearchString = ""
		scrollingFrame.CanvasPosition = Vector2.new(0, 0)
	end, true)

	mainDisplayFrameObliterator:Add(
		editor.Main.MainFrame.Items:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if
				scrollingFrame.AbsoluteWindowSize.Y * scrollingFrame.CanvasSize.Y.Scale
						+ scrollingFrame.CanvasPosition.Y
					>= scrollingFrame.AbsoluteCanvasSize.Y - 0.1
				and not scrollingRefreshDebounce
			then
				scrollingRefreshDebounce = true

				currentResults:AdvanceToNextPageAsync()
				displayResultsInFrame(scrollingFrame)

				task.wait(2)
				scrollingRefreshDebounce = false
			end
		end)
	)
end

-- local sliderStartX, sliderEndX = -0.015, 0.905

local function handleScaleSlider(slider)
	local sliderConfig = {
		snapFactor = 0.1,
	}
	if slider.Parent.Name == "Height" or slider.Parent.Name == "HeadSize" then
		sliderConfig.min = 75
		sliderConfig.max = 125
	elseif slider.Parent.Name == "Width" then
		sliderConfig.min = 70
		sliderConfig.max = 100
	else
		sliderConfig.min = 0
		sliderConfig.max = 100
	end
	local newSlider = Slider.new(slider.Parent, slider, slider.Button, sliderConfig)
	scaleObliterator:Add(newSlider.ValueChanged:Connect(function(sliderValue)
		slider.Parent.Percentage.Text = `{math.round(sliderValue)}%`
	end))
end

local function handleCategoryButton(button: GuiBase, obliterator: typeof(Janitor.new()))
	if not button:IsA("GuiButton") then
		return
	end
	obliterator:Add(button.Activated:Connect(function()
		editor.Main.MainFrame.Search.Text = ""
		openCategory(button.Name, "")
	end))
end

local function closeEditor(obliterator: typeof(Janitor.new()))
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	obliterator:Cleanup()
	player.Character.Archivable = false
	editor.Enabled = false
end

local function openEditor(obliterator: typeof(Janitor.new()))
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	editor.Enabled = true

	player.Character.Archivable = true
	currentDescription = player.Character.Humanoid:GetAppliedDescription()
	starterDescription = currentDescription:Clone()

	resetUI()

	for _, button in ipairs(editor.Main.AccessoryFrame:GetChildren()) do
		handleCategoryButton(button, obliterator)
	end

	for _, button in ipairs(editor.Main.ShirtFrame:GetChildren()) do
		handleCategoryButton(button, obliterator)
	end

	for _, button in ipairs(editor.Main.PantsFrame:GetChildren()) do
		handleCategoryButton(button, obliterator)
	end

	for _, sliderFrame in ipairs(editor.Main.ScaleFrame.Frame:GetChildren()) do
		local slider = sliderFrame:FindFirstChild("Slider")
		if not slider then
			continue
		end

		-- handleScaleSlider(slider)
	end

	obliterator:Add(editor.Main.BodyFrame.Scale.Activated:Connect(function()
		closeAllFrames()
		editor.Main.BodyFrame.Visible = true
		editor.Main.ScaleFrame.Visible = true
	end))

	handleCategoryButton(editor.Main.BodyFrame.Face, obliterator)

	obliterator:Add(editor.Main.OutfitsFrame.CreateOutfit.Activated:Connect(function()
		if outfits and #outfits < 10 then
			table.insert(outfits, {
				_empty = true,
			})
			addOutfit:FireServer()

			local outfitDisplay = outfitTemplate:Clone()
			outfitsObliterator:Add(outfitDisplay)
			outfitDisplay.Parent = editor.Main.OutfitsFrame.Items
		end
	end))

	obliterator:Add(editor.Main.Apply.Activated:Connect(function()
		editor.Enabled = false
		resetUI()
		saveDescription:FireServer(serializeHumanoidDescription(currentDescription))
	end))

	obliterator:Add(editor.Main.WearingFrame.RemoveAll.Activated:Connect(function()
		currentDescription.Shirt = 868697637
		currentDescription.Pants = 868697782
		currentDescription.GraphicTShirt = 0
		currentDescription.Face = 144075659
		currentDescription:SetAccessories({}, true)
		applyDescription:FireServer(serializeHumanoidDescription(currentDescription))
	end))

	obliterator:Add(editor.Main.Cancel.Activated:Connect(function()
		applyDescription:FireServer(serializeHumanoidDescription(starterDescription))
		closeEditor(obliterator)
	end))

	obliterator:Add(editor.Main.Reset.Activated:Connect(function()
		resetUI()
		resetDescription:FireServer()
		currentDescription = Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end))

	obliterator:Add(editor.Main.MainFrame.Search.FocusLost:Connect(function(entered)
		if not entered or not currentCategory then
			return
		end
		openCategory(currentCategory, editor.Main.MainFrame.Search.Text)
	end))

	for _, button in ipairs(editor.Main:GetChildren()) do
		if not button:IsA("GuiButton") then
			continue
		end

		local frame = editor.Main:FindFirstChild(`{button.Name}Frame`)

		obliterator:Add(button.Activated:Connect(function()
			if frame and not frame.Visible then
				slotsObliterator:Cleanup()
				mainDisplayFrameObliterator:Cleanup()

				closeAllFrames()

				frame.Visible = true

				if button.Name == "Wearing" then
					displayCurrentlyWearing()
				elseif button.Name == "Outfits" then
					if not outfits then
						outfits = getOutfits:InvokeServer()
						while not outfits do
							outfits = getOutfits:InvokeServer()
							task.wait(5)
						end

						for i, outfit in ipairs(outfits) do
							if not outfit._empty then
								outfits[i] = fullDeserialize(outfit)
							end
						end
					end
					displayOutfits()
				else
					editor.Main.MainFrame.Visible = true
				end
			end
		end))
	end
end

local function main()
	local obliterator = Janitor.new()

	editor.Main.Slots.Template:Destroy()
	editor.Main.MainFrame.Items.Template:Destroy()
	editor.Main.OutfitsFrame.Items.Template:Destroy()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.P then
			return
		end

		if editor.Enabled then
			closeEditor(obliterator)
		else
			openEditor(obliterator)
		end
	end)
end

main()
