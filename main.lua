local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Shared.Registry)

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Char = Player.Character or Player.CharacterAdded:Wait()
local Map = workspace:WaitForChild("Map")
local NPCFolder = Map.Zones.Field.NPC
local Backpack = Player:WaitForChild("Backpack")
local StarterGear = Player:WaitForChild("StarterGear")
local DropNPC = ReplicatedStorage.Remotes.Field.DropNPC

task.spawn(function()
	Player.CharacterAdded:Connect(function(character)
		Char = character
	end)
end)

local NPCList = Registry.NPCOrdered
local Remote = ReplicatedStorage.Remotes.Plot.SellNPC

local old = Char:GetPivot()

local Queue = {}
local WakeUp = Instance.new("BindableEvent")

local KeepRarity = {
	Secret = true,
	Mythic = true,
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

task.spawn(function()
	while true do
		task.spawn(function()
			pcall(ClearTools)
		end)

		if not next(Queue) then
			WakeUp.Event:Wait()
		end

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
			until not npc.Parent or Count > Max
		end

		if npc.Parent then
			Char:PivotTo(TPos)
			task.wait(.1)
			DropNPC:FireServer()
		end

		RemoveFromQueue(npc)

		task.spawn(function()
			pcall(ClearTools)
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
		pcall(SellNpc, tool)
	end)

	task.spawn(function()
		pcall(ClearTools)
	end)
end)

task.spawn(function()
	while task.wait(2) do
		for _, npc in ipairs(NPCFolder:GetChildren()) do
			if npc:IsA("Model") and GetPrompt(npc) and not Queue[npc] then
				AddToQueue(npc)
			end
		end
	end
end)
