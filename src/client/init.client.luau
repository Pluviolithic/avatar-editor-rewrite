local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Common.lib.Janitor)

local accessoryLimit = 15
local currentCategory = ""
local currentDescription = nil

local player = Players.LocalPlayer
local editor = player.PlayerGui:WaitForChild("EditAvatar")
local itemTemplate = editor.Main.MainFrame.Items.Template:Clone()

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
	clearDisplayFrame(editor.Main.MainFrame.Items)
	clearDisplayFrame(editor.Main.BundleFrame.Items)
	clearDisplayFrame(editor.Main.WearingFrame.Items)
	clearDisplayFrame(editor.Main.OutfitsFrame.Items)

	closeAllFrames()

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

local function fixOrderFromIndex(list: { { [string]: any } }, index: number)
	for i = index, #list do
		list[i].Order = i
	end
end

local function countAccessoriesOfType(list: { { [string]: any } }, accessoryType: Enum.AvatarAssetType)
	local count = 0
	for _, accessory in ipairs(list) do
		if accessory.AccessoryType == accessoryType then
			count += 1
		end
	end
	return count
end

local function displayResultsInFrame(results: CatalogPages, frame: ScrollingFrame)
	local page = results:GetCurrentPage()

	for _, item in ipairs(page) do
		local itemDisplay = itemTemplate:Clone()

		itemDisplay.Item.Image = `http://www.roblox.com/Thumbs/Asset.ashx?width=110&height=110&assetId={item.Id}`

		itemDisplay.Item.Activated:Connect(function()
			local accessories = table.clone(currentDescription:GetAccessories(false))
			local itemIndex = getItemIndex(accessories, item.Id)

			if itemIndex then
				table.remove(accessories, itemIndex)
				fixOrderFromIndex(accessories, itemIndex)
			elseif #accessories < accessoryLimit then
				table.insert(accessories, {
					AssetId = item.Id,
					IsLayered = true,
					AccessoryType = Enum.AccessoryType[currentCategory:gsub("Accessory", "")],
					Order = #accessories + 1,
				})
			end

			currentDescription:SetAccessories(accessories, false)
			applyDescription:FireServer(serializeHumanoidDescription(currentDescription))
		end)

		itemDisplay.Parent = frame
	end
end

local function search(text: string?): CatalogPages
	local searchParameters = CatalogSearchParams.new()

	searchParameters.AssetTypes = { Enum.AvatarAssetType[currentCategory] }
	if text then
		searchParameters.SearchKeyword = text
	end

	if currentCategory == "LeftShoeAccessory" or currentCategory == "RightShoeAccessory" then
		searchParameters.BundleTypes = { Enum.BundleType.Shoes }
	end

	return AvatarEditorService:SearchCatalog(searchParameters)
end

local function openCategory(categoryName: string)
	if currentCategory == categoryName then
		return
	end
	currentCategory = categoryName

	clearDisplayFrame(editor.Main.MainFrame.Items)
	displayResultsInFrame(search(), editor.Main.MainFrame.Items)
end

local function handleCategoryButton(button: GuiBase, obliterator: typeof(Janitor.new()))
	if not button:IsA("GuiButton") then
		return
	end
	obliterator:Add(button.Activated:Connect(function()
		openCategory(button.Name)
	end))
end

local function openEditor(obliterator: typeof(Janitor.new()))
	editor.Enabled = true

	currentDescription = player.Character.Humanoid:GetAppliedDescription()

	resetUI()

	for _, button in ipairs(editor.Main.AccessoryFrame:GetChildren()) do
		handleCategoryButton(button, obliterator)
	end

	for _, button in ipairs(editor.Main.ShirtFrame:GetChildren()) do
		handleCategoryButton(button, obliterator)
	end

	obliterator:Add(editor.Main.Reset.Activated:Connect(function()
		resetDescription:FireServer()
	end))

	for _, button in ipairs(editor.Main:GetChildren()) do
		if not button:IsA("GuiButton") then
			continue
		end

		local frame = editor.Main:FindFirstChild(`{button.Name}Frame`)

		obliterator:Add(button.Activated:Connect(function()
			if frame then
				closeAllFrames()
				frame.Visible = true

				if button.Name == "Accessory" or button.Name == "Shirt" or button.Name == "Pants" then
					editor.Main.MainFrame.Visible = true
				end
				return
			end
		end))
	end
end

local function closeEditor(obliterator: typeof(Janitor.new()))
	obliterator:Cleanup()
	-- player.Character.Archivable = false
	editor.Enabled = false
end

local function main()
	local obliterator = Janitor.new()

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
