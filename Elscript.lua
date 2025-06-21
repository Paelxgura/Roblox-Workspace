--[[
	SCRIPT OPTIMIZED & FIXED BY GEMINI
	---------------------------------
	Perubahan (Fix):
	- Memperbaiki logika ESP Player yang tidak berfungsi.
	- Sistem pelacakan ESP sekarang berpusat pada objek Player (yang persisten)
	  bukan pada model Character (yang bisa hilang/muncul lagi saat respawn).
	  Ini membuat ESP lebih stabil dan andal.
	- Mempertahankan semua optimalisasi performa sebelumnya (loop interval, noclip efisien, dll).
]]

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Welcome in ElHub!",
	LoadingTitle = "Patience is a key..",
	LoadingSubtitle = "Elproject",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = nil,
		FileName = "FIVE NIGHT: HUNTED"
	},
	Discord = {
		Enabled = false
	},
	KeySystem = false
})

--==================================================--
--[[               SERVICE & LOCALS               ]]--
--==================================================--
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--==================================================--
--[[              AUTO HEART BEAT                 ]]--
--==================================================--
-- Bagian ini tidak diubah dan seharusnya berfungsi seperti sebelumnya.
local HIT_OFFSET_SECONDS = 0.01
local PERFECT_WINDOW_SECONDS = 0.14
local Knit, Vetween, HeartbeatController, SoundController, HeartbeatGui
local heartbeatAutoClickerActive = false
local heartbeatConnection = nil

local function initializeHeartbeatReferences()
	if Knit and HeartbeatController and SoundController and HeartbeatGui and Vetween then return true end
	local successKnit, knitModule = pcall(require, ReplicatedStorage.Packages.Knit)
	if not successKnit then warn("AutoHeartbeat: Gagal memuat Knit:", knitModule) return false end
	Knit = knitModule
	local successVetween, vetweenModule = pcall(require, ReplicatedStorage.Packages.Vetween)
	if not successVetween then warn("AutoHeartbeat: Gagal memuat Vetween:", vetweenModule) return false end
	Vetween = vetweenModule
	local controllerFetchAttempts = 0
	while not HeartbeatController and controllerFetchAttempts < 50 do
		HeartbeatController = Knit.GetController("HeartbeatController")
		if not HeartbeatController then controllerFetchAttempts = controllerFetchAttempts + 1; task.wait(0.1) end
	end
	if not HeartbeatController then warn("AutoHeartbeat: HeartbeatController tidak ditemukan.") return false end
	SoundController = Knit.GetController("SoundController")
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	HeartbeatGui = playerGui:WaitForChild("Heartbeat", 5)
	if HeartbeatGui then HeartbeatGui = HeartbeatGui:WaitForChild("Heartbeat", 5) end
	if not HeartbeatGui then warn("AutoHeartbeat: Heartbeat GUI tidak ditemukan.") return false end
	if not (HeartbeatController and HeartbeatController.Trigger) then warn("AutoHeartbeat: HeartbeatController.Trigger tidak valid.") return false end
	return true
end
local function getCurrentHeartbeatGameStateAndStatus()
	if not HeartbeatController or not HeartbeatController.Trigger then return nil, false end
	local _, currentIsActive = pcall(debug.getupvalue, HeartbeatController.Trigger, 1)
	local _, currentGameState = pcall(debug.getupvalue, HeartbeatController.Trigger, 6)
	return currentGameState, currentIsActive
end
local function onHeartbeatRenderStep()
	if not (heartbeatAutoClickerActive and Knit and Vetween and HeartbeatGui and HeartbeatController) then return end
	local currentLocalState, isGameActive = getCurrentHeartbeatGameStateAndStatus()
	if not (isGameActive and currentLocalState and currentLocalState.InitTick and currentLocalState.Beats and currentLocalState.Notes and #currentLocalState.Notes > 0) then return end
	local gameTime = tick() - currentLocalState.InitTick
	local bestNoteToHit, smallestTimeDifferenceToHitPoint = nil, math.huge
	for i, noteInfo in ipairs(currentLocalState.Notes) do
		local beatIndex = noteInfo[1]
		if currentLocalState.Beats[beatIndex] then
			local targetTime, timeUntilHit = currentLocalState.Beats[beatIndex], currentLocalState.Beats[beatIndex] - gameTime
			local diffFromIdealClick = timeUntilHit - HIT_OFFSET_SECONDS
			if math.abs(diffFromIdealClick) <= PERFECT_WINDOW_SECONDS and math.abs(diffFromIdealClick) < smallestTimeDifferenceToHitPoint then
				smallestTimeDifferenceToHitPoint = math.abs(diffFromIdealClick)
				bestNoteToHit = { noteData = noteInfo, arrayIndex = i, timeError = gameTime - targetTime }
			end
		end
	end
	if bestNoteToHit then
		local noteData, beatIndex, noteObject, arrayIndex, timeError = bestNoteToHit.noteData, bestNoteToHit.noteData[1], bestNoteToHit.noteData[2], bestNoteToHit.arrayIndex, bestNoteToHit.timeError
		if table.find(currentLocalState.Passed, beatIndex) then return end
		if math.abs(timeError) < PERFECT_WINDOW_SECONDS then
			if SoundController then pcall(SoundController.PlaySound, SoundController, "SingleHeartbeat") end
			HeartbeatGui.Playfield.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			HeartbeatGui.Playfield.BackgroundTransparency = 0
			currentLocalState.Stats.Perfect = currentLocalState.Stats.Perfect + 1
			Vetween.new(HeartbeatGui.Playfield, Vetween.newInfo(0.5, Vetween.Style.Linear), { ["BackgroundColor3"] = Color3.fromRGB(0, 0, 0), ["BackgroundTransparency"] = 1 }):Play()
			if noteObject and noteObject.Parent then noteObject:Destroy() end
			table.insert(currentLocalState.Passed, beatIndex)
			table.remove(currentLocalState.Notes, arrayIndex)
			if HeartbeatGui.UIScale then
				HeartbeatGui.UIScale.Scale = 1.1
				Vetween.new(HeartbeatGui.UIScale, Vetween.newInfo(2, Vetween.Style.Quint), { ["Scale"] = 1 }):Play()
			end
		end
	end
end
local function enableAutoHeartbeat(enable)
	heartbeatAutoClickerActive = enable
	if enable then
		if not (Knit and Vetween and HeartbeatGui and HeartbeatController) then
			if not initializeHeartbeatReferences() then
				Rayfield:Notify({Title = "Auto Heartbeat", Content = "Gagal menginisialisasi modul.", Duration = 5, Image = 4483362458})
				heartbeatAutoClickerActive = false; return false 
			end
		end
		if heartbeatConnection then heartbeatConnection:Disconnect() end 
		heartbeatConnection = RunService:BindToRenderStep("HeartbeatAutoClicker", Enum.RenderPriority.Character.Value + 1, onHeartbeatRenderStep)
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Auto Heartbeat Diaktifkan!", Duration = 5, Image = 4483362458})
	else
		if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Auto Heartbeat Dinonaktifkan!", Duration = 5, Image = 4483362458})
	end
	return true 
end

--==================================================--
--[[         ESP SYSTEM (OPTIMIZED & FIXED)       ]]--
--==================================================--
local espEnabled = false
local computerESPEnabled = false
local trackedObjects = {} -- Melacak Player atau Model (Komputer)
local ESP_UPDATE_INTERVAL = 0.25

-- Fungsi untuk membersihkan semua elemen ESP dari sebuah objek
local function clearESP(object)
	if not object or not trackedObjects[object] then return end
	local espInfo = trackedObjects[object]
	if espInfo.Tag and espInfo.Tag.Parent then espInfo.Tag:Destroy() end
	if espInfo.Highlight and espInfo.Highlight.Parent then espInfo.Highlight:Destroy() end
	trackedObjects[object] = nil
end

-- Fungsi utama untuk membuat/memperbarui ESP.
-- Sekarang lebih pintar dalam menangani Player vs Model.
-- Fungsi utama untuk membuat/memperbarui ESP.
-- Versi ini dengan pengaturan opacity yang bisa diubah.
local function createOrUpdateESP(object, labelText, fillColor, progressText)
	local model, root
	
	if object:IsA("Player") then
		model = object.Character
		if not model then
			clearESP(object)
			return
		end
		root = model:FindFirstChild("HumanoidRootPart")
	elseif object:IsA("Model") then
		model = object
		root = model.PrimaryPart or model:FindFirstChild("RootPart") or model:FindFirstChildWhichIsA("BasePart")
	end

	if not model or not root then return end
	
	local espInfo = trackedObjects[object] or {}
	
	if espInfo.Character and espInfo.Character ~= model then
		clearESP(object)
		espInfo = {}
	end

	local displayText = labelText
	if progressText then
		displayText = displayText .. "\n" .. progressText
	end
	
	-- Buat atau Update BillboardGui (Teks)
	if not espInfo.Tag or not espInfo.Tag.Parent then
		local gui = Instance.new("BillboardGui", model)
		gui.Name = "ESPTag"
		gui.Adornee = root
		gui.Size = UDim2.new(0, 150, 0, 60)
		gui.StudsOffset = Vector3.new(0, 5, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		
		local text = Instance.new("TextLabel", gui)
		text.Name = "ESPText"
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.TextColor3 = fillColor
		text.Font = Enum.Font.GothamSemibold
		text.TextSize = 14
		text.TextWrapped = true
		text.RichText = true
		
		-- [[ PENGATURAN OPACITY TEKS ]]
		text.TextTransparency = 0.2 -- # <--- UBAH DI SINI (0.0 = solid, 1.0 = hilang)
		text.TextStrokeTransparency = 0.5 -- # <--- UBAH DI SINI (garis pinggir teks)
		
		espInfo.Tag = gui
	end
	
	espInfo.Tag.ESPText.Text = displayText
	espInfo.Tag.ESPText.TextColor3 = fillColor
	espInfo.Tag.Adornee = root
	
	-- Buat atau Update Highlight (Siluet)
	if not espInfo.Highlight or not espInfo.Highlight.Parent then
		local hl = Instance.new("Highlight", model)
		hl.Name = "ESPHighlight"
		hl.Adornee = model
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		espInfo.Highlight = hl
	end
	
	espInfo.Highlight.FillColor = fillColor
	espInfo.Highlight.OutlineColor = Color3.new(fillColor.r * 0.7, fillColor.g * 0.7, fillColor.b * 0.7)

	-- [[ PENGATURAN OPACITY HIGHLIGHT ]]
	espInfo.Highlight.FillTransparency = 0.9 -- # <--- UBAH DI SINI (isian warna siluet)
	espInfo.Highlight.OutlineTransparency = 0.7 -- # <--- UBAH DI SINI (garis pinggir siluet)
	
	trackedObjects[object] = espInfo
	if object:IsA("Player") then
		espInfo.Character = model
	end
end

-- Fungsi scan untuk komputer tidak perlu banyak berubah
local function scanComputersESP()
	if not computerESPEnabled then return end
	local tasksFolder = Workspace:FindFirstChild("Tasks", true)
	if not tasksFolder then return end
	
	for _, item in ipairs(tasksFolder:GetChildren()) do 
		if item:IsA("Model") and item.Name:lower() == "computer" then
			local progress = item:GetAttribute("Progress")
			local completed = item:GetAttribute("Completed")
			local progressText, espColor
			
			if completed then
				progressText = "Completed"; espColor = Color3.fromRGB(100, 150, 255)
			elseif type(progress) == "number" then
				progressText = string.format("Progress: %.1f", progress); espColor = Color3.fromRGB(50, 255, 50)
			else
				progressText = "Progress: N/A"; espColor = Color3.fromRGB(50, 255, 50)
			end
			createOrUpdateESP(item, "COMPUTER", espColor, progressText)
		end
	end
end

-- Fungsi update untuk player, sekarang hanya sebagai pembungkus
local function updatePlayerESP(player)
	if not espEnabled or player == LocalPlayer then return end
	
	local role = player:GetAttribute("Role")
	local color, nameText
	
	-- Teks utama ESP sekarang SELALU nama pemain
	nameText = player.Name
	
	-- Default warna jika role tidak terdeteksi
	color = Color3.fromRGB(220, 220, 220)

	-- [[ PERBAIKAN DI SINI ]]
	-- Kita ubah nilai role menjadi huruf kecil semua sebelum dicek, agar lebih andal.
	if type(role) == "string" and role ~= "" then
		local roleLower = string.lower(role)
		
		if string.find(roleLower, "monster") then
			-- Jika kata "monster" ditemukan, beri warna merah
			color = Color3.fromRGB(255, 50, 50)
		elseif string.find(roleLower, "survivor") then
			-- Jika kata "survivor" ditemukan, beri warna kuning
			color = Color3.fromRGB(255, 236, 161)
		end
	end
	
	-- Panggil fungsi utama hanya dengan nama pemain dan warna.
	createOrUpdateESP(player, nameText, color)
end

-- Main ESP Loop
task.spawn(function()
	while true do
		-- Hapus objek yang sudah tidak valid dari daftar pelacakan
		for object, _ in pairs(trackedObjects) do
			if not object or not object.Parent then
				clearESP(object)
			end
		end

		if espEnabled then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					pcall(updatePlayerESP, player)
				end
			end
		end
		
		if computerESPEnabled then
			pcall(scanComputersESP)
		end
		
		task.wait(ESP_UPDATE_INTERVAL)
	end
end)

-- Event untuk membersihkan ESP saat player keluar
Players.PlayerRemoving:Connect(clearESP)

--==================================================--
--[[            MOVEMENT (OPTIMIZED)              ]]--
--==================================================--
local targetSpeed = 16
local persistentSpeedEnabled = false
local speedConnection = nil
local noclipActive = false

local function setNoclip(character, enabled)
	if not character then return end
	pcall(function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = not enabled end
		end
	end)
end

--==================================================--
--[[                 UI TOGGLES                   ]]--
--==================================================--
local MainTab = Window:CreateTab("Main", 4483362458)
local MovementTab = Window:CreateTab("Movement", 4483362458)

MainTab:CreateToggle({ Name = "Auto Heartbeat", CurrentValue = heartbeatAutoClickerActive, Flag = "AutoHeartbeatEnabled", Callback = function(Value) if not enableAutoHeartbeat(Value) and Value then heartbeatAutoClickerActive = false; Rayfield:SetFlag("AutoHeartbeatEnabled", false) end end })
MainTab:CreateToggle({ Name = "ESP Player", CurrentValue = espEnabled, Flag = "ESPEnabled", Callback = function(Value) espEnabled = Value; if not Value then for object in pairs(trackedObjects) do if object:IsA("Player") then clearESP(object) end end end end })
MainTab:CreateToggle({ Name = "ESP Computer", CurrentValue = computerESPEnabled, Flag = "ComputerESPEnabled", Callback = function(Value) computerESPEnabled = Value; if not Value then for object in pairs(trackedObjects) do if object:IsA("Model") then clearESP(object) end end end end })
MovementTab:CreateSlider({ Name = "Speed Hack (WalkSpeed)", Range = {16, 100}, Increment = 1, Suffix = "Speed", CurrentValue = 16, Flag = "SpeedHackSlider", Callback = function(Value) targetSpeed = Value; local char = LocalPlayer.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = Value end end })

MovementTab:CreateToggle({
	Name = "Persistent Speed (Anti-Reset)",
	CurrentValue = false,
	Flag = "PersistentSpeedToggle",
	Callback = function(Value)
		persistentSpeedEnabled = Value
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
		if Value and hum then
			hum.WalkSpeed = targetSpeed
			speedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
				if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
			end)
		end
	end,
})

MovementTab:CreateToggle({
	Name = "Noclip",
	CurrentValue = false,
	Flag = "NoclipToggle",
	Callback = function(Value)
		noclipActive = Value
		setNoclip(LocalPlayer.Character, noclipActive)
	end,
})
-- Handle Noclip saat respawn
LocalPlayer.CharacterAdded:Connect(function(character)
	if noclipActive then
		task.wait(0.1) -- Beri sedikit jeda agar semua part termuat
		setNoclip(character, true)
	end
end)

Rayfield:Notify({ Title = "ElHub Loaded!", Content = "Selamat datang di ElHub. (Optimized & Fixed)", Duration = 7, Image = 4483362458 })