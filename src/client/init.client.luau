local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Common.lib.Janitor)

local currentCategory = ""
local currentHumanoid = nil
local currentDescription = nil

local player = Players.LocalPlayer
local editorCamera = Instance.new("Camera")
local editor = player.PlayerGui:WaitForChild("EditAvatar")
local itemTemplate = editor.Main.Background.Items.Template:Clone()

-- if not in limits, it's 3
local customLimits = {
	Head = 1,
	Shirt = 1,
	Pants = 1,
	Face = 1,
	Torso = 1,
	LeftArm = 1,
	LeftLeg = 1,
	RightArm = 1,
	RightLeg = 1,
	GraphicTShirt = 1,
}

local accessoryBlobCategories = {
	ShoulderAccessory = true,
	JacketAccessory = true,
	SweaterAccessory = true,
	ShirtAccessory = true,
	TShirtAccessory = true,
	DressSkirtAccessory = true,
	PantsAccessory = true,
	ShortsAccessory = true,
	LeftShoeAccessory = true,
	RightShoeAccessory = true,
}

local function getAdjustedCameraAngle(angle: Vector2)
	return CFrame.Angles(0, math.rad(angle.X), 0)
		* CFrame.Angles(0, math.rad(angle.Y), 0)
		* CFrame.Angles(0, math.pi, 0)
		* CFrame.new(Vector3.new(0, 0, 6))
end

local function checkIfInputInFrame(input: InputObject, frame: Frame)
	return input.Position.X > frame.AbsolutePosition.X
		and input.Position.X < (frame.AbsolutePosition.X + frame.AbsoluteSize.X)
		and input.Position.Y > frame.AbsolutePosition.Y
		and input.Position.Y < (frame.AbsolutePosition.Y + frame.AbsoluteSize.Y)
end

local function clearDisplay()
	editor.Main.Background.Search.Text = ""
	for _, itemDisplay in ipairs(editor.Main.Background.Items:GetChildren()) do
		if itemDisplay:IsA("ImageLabel") then
			itemDisplay:Destroy()
		end
	end
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
		list[i].Order -= 1
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

local function displayResults(results: CatalogPages)
	local page = results:GetCurrentPage()

	for _, item in ipairs(page) do
		local itemDisplay = itemTemplate:Clone()

		itemDisplay.Item.Image = `http://www.roblox.com/Thumbs/Asset.ashx?width=110&height=110&assetId={item.Id}`

		itemDisplay.Item.Activated:Connect(function()
			if accessoryBlobCategories[currentCategory] then
				local accessories = table.clone(currentDescription:GetAccessories(false))
				local itemIndex = getItemIndex(accessories, item.Id)

				if itemIndex then
					table.remove(accessories, itemIndex)
					fixOrderFromIndex(accessories, itemIndex)
				elseif
					countAccessoriesOfType(accessories, Enum.AvatarAssetType[currentCategory] :: Enum.AvatarAssetType)
					< 4
				then
					table.insert(accessories, {
						AssetId = item.Id,
						IsLayered = true,
						AccessoryType = Enum.AccessoryType[currentCategory:gsub("Accessory", "")],
						Order = #accessories + 1,
					})
				end
				print(accessories)

				currentDescription:SetAccessories(accessories, false)
				currentHumanoid:ApplyDescription(currentDescription)
				return
			end

			if customLimits[currentCategory] == 1 then
				if currentDescription[currentCategory] == item.Id then
					currentDescription[currentCategory] = nil
				elseif not currentDescription[currentCategory] then
					currentDescription[currentCategory] = item.Id
				end
				currentHumanoid:ApplyDescription(currentDescription)
				return
			end

			local descriptionIndex = currentCategory

			if descriptionIndex == "Hat" then
				descriptionIndex = "HatAccessory"
			end

			local _, commaCount = currentDescription[descriptionIndex]:gsub(",", "")
			if currentDescription[descriptionIndex]:match(tostring(item.Id)) then
				currentDescription[descriptionIndex] = currentDescription[descriptionIndex]:gsub(`,?{item.Id}`, "")
			elseif commaCount < 2 then
				currentDescription[descriptionIndex] = `{currentDescription[descriptionIndex]},{item.Id}`
			end
			currentHumanoid:ApplyDescription(currentDescription)
		end)

		itemDisplay.Parent = editor.Main.Background.Items
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
	clearDisplay()

	displayResults(search())
end

local function openEditor(obliterator: typeof(Janitor.new()))
	editor.Enabled = true
	player.Character.Archivable = true

	local angle = Vector2.new()
	local dragging = false
	local displayCharacter = player.Character:Clone()

	obliterator:Add(displayCharacter)

	currentHumanoid = displayCharacter.Humanoid
	currentDescription = displayCharacter.Humanoid:GetAppliedDescription()
	displayCharacter.Parent = editor.Main.Character.WorldModel
	editorCamera.CFrame = displayCharacter.Humanoid.RootPart.CFrame * getAdjustedCameraAngle(Vector2.new())

	openCategory("Hat")

	obliterator:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not checkIfInputInFrame(input, editor.Main.Character) then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true

			local startAngle = angle
			local startPosition = UserInputService:GetMouseLocation()

			while dragging do
				angle = startAngle + (startPosition - UserInputService:GetMouseLocation())
				editorCamera.CFrame = displayCharacter.Humanoid.RootPart.CFrame * getAdjustedCameraAngle(angle)
				task.wait()
			end
		end
	end))

	obliterator:Add(UserInputService.InputEnded:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end))

	obliterator:Add(function()
		dragging = false
		clearDisplay()
	end, true)

	obliterator:Add(editor.Main.Background.Search.FocusLost:Connect(function(enterPressed)
		if not enterPressed then
			return
		end
	end))

	for _, button in ipairs(editor.Main:GetChildren()) do
		if not button:IsA("ImageButton") then
			continue
		end

		obliterator:Add(button.Activated:Connect(function()
			openCategory(button.Name)
		end))
	end
end

local function closeEditor(obliterator: typeof(Janitor.new()))
	obliterator:Cleanup()
	player.Character.Archivable = false
	editor.Enabled = false
end

local function main()
	local obliterator = Janitor.new()

	clearDisplay()
	editor.Main.Character.CurrentCamera = editorCamera

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
