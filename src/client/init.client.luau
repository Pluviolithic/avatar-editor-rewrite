local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Common.lib.Janitor)

local currentPage = 0
local currentResults = nil
local accessoryLimit = 15
local currentCategory = ""
local currentDescription = nil
local starterDescription = nil
local scrollingRefreshDebounce = false

local player = Players.LocalPlayer
local slotsObliterator = Janitor.new()
local wearingObliterator = Janitor.new()
local mainDisplayFrameObliterator = Janitor.new()
local editor = player.PlayerGui:WaitForChild("EditAvatar")

local slotTemplate = editor.Main.Slots.Template:Clone()
local itemTemplate = editor.Main.MainFrame.Items.Template:Clone()

local saveDescription = ReplicatedStorage.Remotes.SaveDescription
local resetDescription = ReplicatedStorage.Remotes.ResetDescription
local applyDescription = ReplicatedStorage.Remotes.ApplyDescription

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
	mainDisplayFrameObliterator:Cleanup()

	clearDisplayFrame(editor.Main.BundleFrame.Items)
	clearDisplayFrame(editor.Main.WearingFrame.Items)
	clearDisplayFrame(editor.Main.OutfitsFrame.Items)

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
			description.Pants = 0
		elseif description.Shirt == itemId then
			description.Shirt = 0
		elseif description.GraphicTShirt == itemId then
			description.GraphicTShirt = 0
		elseif description.Face == itemId then
			description.Face = 0
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

	local map = {}
	if category:match("Accessory") then
		if description[category] == "" then
			return map
		end

		for _, stringId in ipairs((description[category] :: string):split(",")) do
			map[tonumber(stringId)] = true
		end

		return map
	end

	for _, item in ipairs(description:GetAccessories(false)) do
		if item.AccessoryType == accessoryTypeRemaps[category] then
			map[item.AssetId] = true
		end
	end

	return map
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

	-- if currentCategory == "LeftShoeAccessory" or currentCategory == "RightShoeAccessory" then
	-- 	searchParameters.BundleTypes = { Enum.BundleType.Shoes }
	-- end
	--
	return AvatarEditorService:SearchCatalog(searchParameters)
end

local function openCategory(categoryName: string)
	if currentCategory == categoryName then
		return
	end
	currentCategory = categoryName

	local scrollingFrame = editor.Main.MainFrame.Items

	slotsObliterator:Cleanup()
	mainDisplayFrameObliterator:Cleanup()
	currentResults = search()
	displayResultsInFrame(scrollingFrame)

	mainDisplayFrameObliterator:Add(function()
		currentPage = 0
		currentResults = nil
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

local function handleCategoryButton(button: GuiBase, obliterator: typeof(Janitor.new()))
	if not button:IsA("GuiButton") then
		return
	end
	obliterator:Add(button.Activated:Connect(function()
		openCategory(button.Name)
	end))
end

local function closeEditor(obliterator: typeof(Janitor.new()))
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	obliterator:Cleanup()
	-- player.Character.Archivable = false
	editor.Enabled = false
end

local function openEditor(obliterator: typeof(Janitor.new()))
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	editor.Enabled = true

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

	obliterator:Add(editor.Main.Apply.Activated:Connect(function()
		editor.Enabled = false
		resetUI()
		saveDescription:FireServer(serializeHumanoidDescription(currentDescription))
	end))

	obliterator:Add(editor.Main.WearingFrame.RemoveAll.Activated:Connect(function()
		currentDescription.Shirt = 0
		currentDescription.Pants = 0
		currentDescription.GraphicTShirt = 0
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
					editor.Main.WearingFrame.Visible = true
					displayCurrentlyWearing()
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
