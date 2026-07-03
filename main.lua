local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local Registry = require(ReplicatedStorage.Shared.Registry)

local Player = Players.LocalPlayer
local Char = Player.Character or Player.CharacterAdded:Wait()
local Map = workspace:WaitForChild("Map")
local NPCFolder = Map.Zones.Field.NPC
local Backpack = Player:WaitForChild("Backpack")
local StarterGear = Player:WaitForChild("StarterGear")
local DropNPC = ReplicatedStorage.Remotes.Field.DropNPC
local Remote = ReplicatedStorage.Remotes.Plot.SellNPC

task.spawn(function()
    Player.CharacterAdded:Connect(function(character)
        Char = character
    end)
end)

local NPCList = Registry.NPCOrdered
local old = Char:GetPivot()
local Queue = {}
local WakeUp = Instance.new("BindableEvent")

local AutoFarmEnabled = false
local AutoSellEnabled = false
local DisableTradeEnabled = false
local ScriptDestroyed = false
local selectedRarity = "Common"
local tradeConnection = nil

local KeepRarity = {
    Common = false,
    Rare = false,
    Epic = false,
    Legendary = false,
    Mythic = true,
    Secret = true,
    ["Ultra Beast"] = true,
}

local Priority = {
    Common = 0,
    Rare = 1,
    Epic = 2,
    Legendary = 3,
    Mythic = 4,
    Secret = 5,
    ["Ultra Beast"] = 6,
}

local NPCInfo = {}

for _, v in ipairs(NPCList) do
    NPCInfo[v.Id] = v.Rarity
    NPCInfo[v.DisplayName] = v.Rarity
end

local function MakeDraggable(object, handle)
    local dragging = false
    local dragInput, dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = object.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function AddToQueue(npc)
    if Queue[npc] then return end
    Queue[npc] = Priority[NPCInfo[npc:GetAttribute("NPCId") or ""]] or 0
    WakeUp:Fire()
end

local function RemoveFromQueue(npc)
    Queue[npc] = nil
end

local function GetPrompt(npc)
    local p = npc:FindFirstChild("Prompts")
    p = p and p:FindFirstChild("Pickup")
    return p and p:IsA("ProximityPrompt") and p or nil
end

local Clearing = false

local function ClearTools()
    if Clearing then return end
    Clearing = true
    
    for _, container in {Backpack, Char} do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and not StarterGear:FindFirstChild(tool.Name) then
                pcall(tool.Destroy, tool)
            end
        end
    end

    Clearing = false
end

local function GetPriorityNpc()
    local best
    local value = -1

    for npc, prio in pairs(Queue) do
        if prio > value then
            value = prio
            best = npc
        end
    end

    return best, value
end

local function SellNpc(tool)
    local guid = tool:GetAttribute("NPCGuid")
    if not guid then return end

    local rarity = NPCInfo[string.split(tool.Name, " ")[1]]

    if KeepRarity[rarity] then
        return
    end

    Remote:FireServer(guid)
end

local function SellAllByRarity()
    for _, container in {Backpack, Char} do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local guid = tool:GetAttribute("NPCGuid")
                if guid then
                    local toolRarity = NPCInfo[string.split(tool.Name, " ")[1]]
                    if toolRarity == selectedRarity then
                        pcall(function() Remote:FireServer(guid) end)
                    end
                end
            end
        end
    end
end

local function FirePrompt(prompt)
    if not prompt.Parent then
        return false
    end
    
    for i = 1, 15 do
        local ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait()
            prompt:InputHoldEnd()
        end)

        if ok and not prompt.Parent then
            return true
        end

        task.wait(0.05)
    end

    return false
end

local function TpRandom()
    if not Char.Parent then return end
    local NewPos = old * CFrame.new(math.random(-30, 30), 0, math.random(-30, 5))
    Char:PivotTo(NewPos)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = Player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 380)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
MainFrame.Parent = ScreenGui

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)
local TopFix = Instance.new("Frame")
TopFix.Size = UDim2.new(1, 0, 0, 10)
TopFix.Position = UDim2.new(0, 0, 1, -10)
TopFix.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TopFix.BorderSizePixel = 0
TopFix.Parent = TopBar
TopBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = TopBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -60, 0, 0)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
MinimizeBtn.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TopBar

MakeDraggable(MainFrame, TopBar)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -40)
Content.Position = UDim2.new(0, 10, 0, 35)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local afLabel = Instance.new("TextLabel")
afLabel.Size = UDim2.new(1, -60, 0, 25)
afLabel.Position = UDim2.new(0, 0, 0, 0)
afLabel.BackgroundTransparency = 1
afLabel.Text = "Auto Farm"
afLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
afLabel.TextXAlignment = Enum.TextXAlignment.Left
afLabel.Font = Enum.Font.Gotham
afLabel.TextSize = 13
afLabel.Parent = Content

local afToggle = Instance.new("Frame")
afToggle.Size = UDim2.new(0, 50, 0, 25)
afToggle.Position = UDim2.new(1, -50, 0, 0)
afToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
afToggle.BorderSizePixel = 0
Instance.new("UICorner", afToggle).CornerRadius = UDim.new(1, 0)
afToggle.Parent = Content

local afCircle = Instance.new("Frame")
afCircle.Size = UDim2.new(0, 21, 0, 21)
afCircle.Position = UDim2.new(0, 2, 0.5, -10.5)
afCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
afCircle.BorderSizePixel = 0
Instance.new("UICorner", afCircle).CornerRadius = UDim.new(1, 0)
afCircle.Parent = afToggle

afToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        AutoFarmEnabled = not AutoFarmEnabled
        afToggle.BackgroundColor3 = AutoFarmEnabled and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
        afCircle.Position = AutoFarmEnabled and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
        if AutoFarmEnabled then WakeUp:Fire() end
    end
end)

local asLabel = Instance.new("TextLabel")
asLabel.Size = UDim2.new(1, -60, 0, 25)
asLabel.Position = UDim2.new(0, 0, 0, 30)
asLabel.BackgroundTransparency = 1
asLabel.Text = "Auto Sell"
asLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
asLabel.TextXAlignment = Enum.TextXAlignment.Left
asLabel.Font = Enum.Font.Gotham
asLabel.TextSize = 13
asLabel.Parent = Content

local asToggle = Instance.new("Frame")
asToggle.Size = UDim2.new(0, 50, 0, 25)
asToggle.Position = UDim2.new(1, -50, 0, 30)
asToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
asToggle.BorderSizePixel = 0
Instance.new("UICorner", asToggle).CornerRadius = UDim.new(1, 0)
asToggle.Parent = Content

local asCircle = Instance.new("Frame")
asCircle.Size = UDim2.new(0, 21, 0, 21)
asCircle.Position = UDim2.new(0, 2, 0.5, -10.5)
asCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
asCircle.BorderSizePixel = 0
Instance.new("UICorner", asCircle).CornerRadius = UDim.new(1, 0)
asCircle.Parent = asToggle

asToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        AutoSellEnabled = not AutoSellEnabled
        asToggle.BackgroundColor3 = AutoSellEnabled and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
        asCircle.Position = AutoSellEnabled and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
    end
end)

local dtLabel = Instance.new("TextLabel")
dtLabel.Size = UDim2.new(1, -60, 0, 25)
dtLabel.Position = UDim2.new(0, 0, 0, 60)
dtLabel.BackgroundTransparency = 1
dtLabel.Text = "Disable Trade & Gift"
dtLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
dtLabel.TextXAlignment = Enum.TextXAlignment.Left
dtLabel.Font = Enum.Font.Gotham
dtLabel.TextSize = 13
dtLabel.Parent = Content

local dtToggle = Instance.new("Frame")
dtToggle.Size = UDim2.new(0, 50, 0, 25)
dtToggle.Position = UDim2.new(1, -50, 0, 60)
dtToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
dtToggle.BorderSizePixel = 0
Instance.new("UICorner", dtToggle).CornerRadius = UDim.new(1, 0)
dtToggle.Parent = Content

local dtCircle = Instance.new("Frame")
dtCircle.Size = UDim2.new(0, 21, 0, 21)
dtCircle.Position = UDim2.new(0, 2, 0.5, -10.5)
dtCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dtCircle.BorderSizePixel = 0
Instance.new("UICorner", dtCircle).CornerRadius = UDim.new(1, 0)
dtCircle.Parent = dtToggle

dtToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        DisableTradeEnabled = not DisableTradeEnabled
        dtToggle.BackgroundColor3 = DisableTradeEnabled and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
        dtCircle.Position = DisableTradeEnabled and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
        
        if DisableTradeEnabled then
            task.spawn(function()
                local Frame = Player.PlayerGui:WaitForChild("MainGui"):WaitForChild("Menus"):WaitForChild("GiftFrame")
                tradeConnection = Frame:GetPropertyChangedSignal("Visible"):Connect(function()
                    if DisableTradeEnabled and Frame.Visible then
                        local TradeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Trade"):WaitForChild("TradeResponse")
						local GiftRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Gift")
                        for _, plr in Players:GetPlayers() do
                            TradeRemote:FireServer(plr, false)
                        end
                    end
                end)
                if Frame.Visible then
                    local TradeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Trade"):WaitForChild("TradeResponse")
					local GiftRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Gift")
                    for _, plr in Players:GetPlayers() do
                        TradeRemote:FireServer(plr, false)
						local char = plr.Character
						if not char then return end

						for _, v in Char:GetChildren() do
							if v:IsA("Tool") then
								local GUID = v:GetAttribute("NPCGuid") or nil
								if not GUID then continue end
								GiftRemote:FireServer("Decline", GUID)
							end
						end
                    end

                end
            end)
        else
            if tradeConnection then
                tradeConnection:Disconnect()
                tradeConnection = nil
            end
        end
    end
end)

local krLabel = Instance.new("TextLabel")
krLabel.Size = UDim2.new(1, 0, 0, 20)
krLabel.Position = UDim2.new(0, 0, 0, 90)
krLabel.BackgroundTransparency = 1
krLabel.Text = "Keep Rarity"
krLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
krLabel.TextXAlignment = Enum.TextXAlignment.Left
krLabel.Font = Enum.Font.GothamBold
krLabel.TextSize = 13
krLabel.Parent = Content

local krContainer = Instance.new("Frame")
krContainer.Size = UDim2.new(1, 0, 0, 154)
krContainer.Position = UDim2.new(0, 0, 0, 110)
krContainer.BackgroundTransparency = 1
krContainer.Parent = Content

local rarityKeys = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Ultra Beast"}

for i, rarity in ipairs(rarityKeys) do
    local checkBox = Instance.new("TextButton")
    checkBox.Size = UDim2.new(0, 18, 0, 18)
    checkBox.Position = UDim2.new(0, 0, 0, (i-1) * 22)
    checkBox.BackgroundColor3 = KeepRarity[rarity] and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(60, 60, 60)
    checkBox.BorderSizePixel = 0
    checkBox.Text = KeepRarity[rarity] and "✓" or ""
    checkBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkBox.Font = Enum.Font.GothamBold
    checkBox.TextSize = 12
    Instance.new("UICorner", checkBox).CornerRadius = UDim.new(0, 4)
    checkBox.Parent = krContainer

    local rName = Instance.new("TextLabel")
    rName.Size = UDim2.new(0, 100, 0, 18)
    rName.Position = UDim2.new(0, 24, 0, (i-1) * 22)
    rName.BackgroundTransparency = 1
    rName.Text = rarity
    rName.TextColor3 = Color3.fromRGB(200, 200, 200)
    rName.TextXAlignment = Enum.TextXAlignment.Left
    rName.Font = Enum.Font.Gotham
    rName.TextSize = 12
    rName.Parent = krContainer

    checkBox.MouseButton1Click:Connect(function()
        KeepRarity[rarity] = not KeepRarity[rarity]
        checkBox.BackgroundColor3 = KeepRarity[rarity] and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(60, 60, 60)
        checkBox.Text = KeepRarity[rarity] and "✓" or ""
    end)
end

local dropdownDisplay = Instance.new("TextButton")
dropdownDisplay.Size = UDim2.new(0, 100, 0, 30)
dropdownDisplay.Position = UDim2.new(0, 0, 0, 270)
dropdownDisplay.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
dropdownDisplay.BorderSizePixel = 0
dropdownDisplay.Text = selectedRarity
dropdownDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
dropdownDisplay.Font = Enum.Font.Gotham
dropdownDisplay.TextSize = 12
Instance.new("UICorner", dropdownDisplay).CornerRadius = UDim.new(0, 6)
dropdownDisplay.Parent = Content

local dropdownList = Instance.new("Frame")
dropdownList.Size = UDim2.new(0, 100, 0, #rarityKeys * 22)
dropdownList.Position = UDim2.new(0, 0, 0, 240)
dropdownList.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
dropdownList.BorderSizePixel = 0
dropdownList.Visible = false
dropdownList.ZIndex = 10
Instance.new("UICorner", dropdownList).CornerRadius = UDim.new(0, 6)
dropdownList.Parent = Content

for i, rarity in ipairs(rarityKeys) do
    local opt = Instance.new("TextButton")
    opt.Size = UDim2.new(1, 0, 0, 22)
    opt.Position = UDim2.new(0, 0, 0, (i-1) * 22)
    opt.BackgroundTransparency = 1
    opt.Text = rarity
    opt.TextColor3 = Color3.fromRGB(200, 200, 200)
    opt.Font = Enum.Font.Gotham
    opt.TextSize = 12
    opt.ZIndex = 11
    opt.Parent = dropdownList

    opt.MouseButton1Click:Connect(function()
        selectedRarity = rarity
        dropdownDisplay.Text = rarity
        dropdownList.Visible = false
    end)
end

dropdownDisplay.MouseButton1Click:Connect(function()
    dropdownList.Visible = not dropdownList.Visible
end)

local sellAllBtn = Instance.new("TextButton")
sellAllBtn.Size = UDim2.new(0, 115, 0, 30)
sellAllBtn.Position = UDim2.new(0, 110, 0, 270)
sellAllBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
sellAllBtn.BorderSizePixel = 0
sellAllBtn.Text = "Sell All by Rarity"
sellAllBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
sellAllBtn.Font = Enum.Font.GothamBold
sellAllBtn.TextSize = 11
Instance.new("UICorner", sellAllBtn).CornerRadius = UDim.new(0, 6)
sellAllBtn.MouseButton1Click:Connect(SellAllByRarity)
sellAllBtn.Parent = Content

local halfW = math.floor(230 / 2) - 5

local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Size = UDim2.new(0, halfW, 0, 30)
rejoinBtn.Position = UDim2.new(0, 0, 0, 305)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
rejoinBtn.BorderSizePixel = 0
rejoinBtn.Text = "Rejoin"
rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rejoinBtn.Font = Enum.Font.GothamBold
rejoinBtn.TextSize = 12
Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 6)
rejoinBtn.MouseButton1Click:Connect(function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
end)
rejoinBtn.Parent = Content

local randomBtn = Instance.new("TextButton")
randomBtn.Size = UDim2.new(0, halfW, 0, 30)
randomBtn.Position = UDim2.new(0, halfW + 10, 0, 305)
randomBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
randomBtn.BorderSizePixel = 0
randomBtn.Text = "Join Random"
randomBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
randomBtn.Font = Enum.Font.GothamBold
randomBtn.TextSize = 12
Instance.new("UICorner", randomBtn).CornerRadius = UDim.new(0, 6)
randomBtn.MouseButton1Click:Connect(function()
    local success, result = pcall(function()
        return TeleportService:TeleportAsync(game.PlaceId, {Player})
    end)
    if not success or (result and type(result) == "table" and #result > 0 and result[1].Joined and result[1].JobId == game.JobId) then
        return
    end
end)
randomBtn.Parent = Content

local MinimizedBtn = Instance.new("TextButton")
MinimizedBtn.Size = UDim2.new(0, 40, 0, 40)
MinimizedBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MinimizedBtn.BorderSizePixel = 0
MinimizedBtn.Text = "+"
MinimizedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizedBtn.Font = Enum.Font.GothamBold
MinimizedBtn.TextSize = 20
MinimizedBtn.Visible = false
Instance.new("UICorner", MinimizedBtn).CornerRadius = UDim.new(0, 8)
MinimizedBtn.Parent = ScreenGui

MakeDraggable(MinimizedBtn, MinimizedBtn)

MinimizeBtn.MouseButton1Click:Connect(function()
    MinimizedBtn.Position = MainFrame.Position
    MainFrame.Visible = false
    MinimizedBtn.Visible = true
end)

MinimizedBtn.MouseButton1Click:Connect(function()
    MainFrame.Position = MinimizedBtn.Position
    MainFrame.Visible = true
    MinimizedBtn.Visible = false
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScriptDestroyed = true
    WakeUp:Fire()
    ScreenGui:Destroy()
end)

task.spawn(function()
    while true do
        if ScriptDestroyed then break end
        
        task.spawn(function()
            if AutoSellEnabled then
                pcall(ClearTools)
            end
        end)

        if not AutoFarmEnabled or not next(Queue) then
            WakeUp.Event:Wait()
        end
        
        if ScriptDestroyed then break end
        if not AutoFarmEnabled then continue end

        local npc, priority = GetPriorityNpc()

        if not npc then
            continue
        end

        if not npc.Parent then
            RemoveFromQueue(npc)
            continue
        end

        local prompt = GetPrompt(npc)

        if not prompt then
            RemoveFromQueue(npc)
            continue
        end

        prompt.HoldDuration = 0
        local TPos = npc:GetPivot() * CFrame.new(0, 3, 0)

        Char:PivotTo(TPos)
        task.wait(.3)

        FirePrompt(prompt)

        task.wait(.1)

        if Char.Parent then
            Char:PivotTo(old)
        end

        task.wait(.1)
        
        if npc.Parent then
            local Count = 0
            local Max = 10
            
            if priority >= 4 then
                Max = 300
            end

            repeat
                TpRandom()
                Count += 1
                task.wait(.1)
            until not npc.Parent or Count > Max or ScriptDestroyed
        end

        if npc.Parent then
            Char:PivotTo(TPos)
            task.wait(.1)
            DropNPC:FireServer()
        end

        RemoveFromQueue(npc)

        task.spawn(function()
            if AutoSellEnabled then
                pcall(ClearTools)
            end
        end)
    end
end)

for _, npc in ipairs(NPCFolder:GetChildren()) do
    if npc:IsA("Model") then
        AddToQueue(npc)
    end
end

NPCFolder.ChildAdded:Connect(function(npc)
    if npc:IsA("Model") then
        AddToQueue(npc)
    end
end)

NPCFolder.ChildRemoved:Connect(function(npc)
    RemoveFromQueue(npc)
end)

Backpack.ChildAdded:Connect(function(tool)
    if not tool:IsA("Tool") then
        return
    end

    task.defer(function()
        task.wait(0.1)
        if AutoSellEnabled then
            pcall(SellNpc, tool)
        end
    end)

    task.spawn(function()
        if AutoSellEnabled then
            pcall(ClearTools)
        end
    end)
end)

task.spawn(function()
    while task.wait(2) do
        if ScriptDestroyed then break end
        for _, npc in ipairs(NPCFolder:GetChildren()) do
            if npc:IsA("Model") and GetPrompt(npc) and not Queue[npc] then
                AddToQueue(npc)
            end
        end
    end
end)
