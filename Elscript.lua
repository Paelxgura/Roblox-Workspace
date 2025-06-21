--[[
	SCRIPT OPTIMIZED BY GEMINI
	---------------------------
	Perubahan Utama:
	1. ESP System: Diubah dari loop per-frame menjadi loop berbasis interval (0.25 detik) dan event-driven. Jauh lebih ringan.
	2. Noclip: Loop per-frame dihapus total. Properti CanCollide kini hanya diubah sekali saat toggle diaktifkan/dinonaktifkan.
	3. Persistent Speed: Diubah dari loop per-frame menjadi event-based (GetPropertyChangedSignal). Hanya berjalan saat WalkSpeed diubah oleh game.
	4. Manajemen ESP: Lebih pintar dalam melacak dan membersihkan ESP untuk menghindari kebocoran memori (memory leak).
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
-- Catatan: Bagian ini sebagian besar tidak diubah karena logikanya sangat spesifik
-- untuk gameplay rhythm. Mengubahnya secara drastis bisa merusak fungsinya.
-- Optimalisasi di bagian lain akan memberikan dampak performa yang jauh lebih besar.
local HIT_OFFSET_SECONDS = 0.01
local PERFECT_WINDOW_SECONDS = 0.14

local Knit = nil
local Vetween = nil
local HeartbeatController = nil
local SoundController = nil
local HeartbeatGui = nil

local heartbeatAutoClickerActive = false
local heartbeatConnection = nil

local function initializeHeartbeatReferences()
	if Knit and HeartbeatController and SoundController and HeartbeatGui and Vetween then
		return true
	end

	local successKnit, knitModule = pcall(require, ReplicatedStorage.Packages.Knit)
	if not successKnit then
		warn("AutoHeartbeat: Gagal memuat Knit:", knitModule)
		return false
	end
	Knit = knitModule

	local successVetween, vetweenModule = pcall(require, ReplicatedStorage.Packages.Vetween)
	if not successVetween then
		warn("AutoHeartbeat: Gagal memuat Vetween:", vetweenModule)
		return false
	end
	Vetween = vetweenModule

	local controllerFetchAttempts = 0
	while not HeartbeatController and controllerFetchAttempts < 50 do
		HeartbeatController = Knit.GetController("HeartbeatController")
		if not HeartbeatController then
			controllerFetchAttempts = controllerFetchAttempts + 1
			task.wait(0.1)
		end
	end
	if not HeartbeatController then
		warn("AutoHeartbeat: HeartbeatController tidak ditemukan.")
		return false
	end

	SoundController = Knit.GetController("SoundController")
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	HeartbeatGui = playerGui:WaitForChild("Heartbeat", 5)
	if HeartbeatGui then
		HeartbeatGui = HeartbeatGui:WaitForChild("Heartbeat", 5)
	end

	if not HeartbeatGui then
		warn("AutoHeartbeat: Heartbeat GUI tidak ditemukan.")
		return false
	end
	
	if not (HeartbeatController and HeartbeatController.Trigger) then
		warn("AutoHeartbeat: HeartbeatController.Trigger tidak valid.")
		return false
	end
	
	return true
end

local function getCurrentHeartbeatGameStateAndStatus()
	if not HeartbeatController or not HeartbeatController.Trigger then
		return nil, false
	end
	local _, currentIsActive = pcall(debug.getupvalue, HeartbeatController.Trigger, 1)
	local _, currentGameState = pcall(debug.getupvalue, HeartbeatController.Trigger, 6)
	return currentGameState, currentIsActive
end

local function onHeartbeatRenderStep()
	if not (heartbeatAutoClickerActive and Knit and Vetween and HeartbeatGui and HeartbeatController) then return end

	local currentLocalState, isGameActive = getCurrentHeartbeatGameStateAndStatus()
	if not (isGameActive and currentLocalState and currentLocalState.InitTick and currentLocalState.Beats and currentLocalState.Notes and #currentLocalState.Notes > 0) then return end

	local gameTime = tick() - currentLocalState.InitTick
	local bestNoteToHit = nil
	local smallestTimeDifferenceToHitPoint = math.huge

	for i, noteInfo in ipairs(currentLocalState.Notes) do
		local beatIndex = noteInfo[1]
		if currentLocalState.Beats[beatIndex] then
			local targetTime = currentLocalState.Beats[beatIndex]
			local timeUntilHit = targetTime - gameTime
			local diffFromIdealClick = timeUntilHit - HIT_OFFSET_SECONDS

			if math.abs(diffFromIdealClick) <= PERFECT_WINDOW_SECONDS and math.abs(diffFromIdealClick) < smallestTimeDifferenceToHitPoint then
				smallestTimeDifferenceToHitPoint = math.abs(diffFromIdealClick)
				bestNoteToHit = {
					noteData = noteInfo,
					arrayIndex = i,
					timeError = gameTime - targetTime
				}
			end
		end
	end

	if bestNoteToHit then
		local noteData = bestNoteToHit.noteData
		local beatIndex = noteData[1]
		local noteObject = noteData[2]
		local arrayIndex = bestNoteToHit.arrayIndex
		local timeError = bestNoteToHit.timeError

		if table.find(currentLocalState.Passed, beatIndex) then return end

		if math.abs(timeError) < PERFECT_WINDOW_SECONDS then
			if SoundController then
				pcall(SoundController.PlaySound, SoundController, "SingleHeartbeat")
			end
			
			HeartbeatGui.Playfield.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			HeartbeatGui.Playfield.BackgroundTransparency = 0
			currentLocalState.Stats.Perfect = currentLocalState.Stats.Perfect + 1

			Vetween.new(HeartbeatGui.Playfield, Vetween.newInfo(0.5, Vetween.Style.Linear), {
				["BackgroundColor3"] = Color3.fromRGB(0, 0, 0),
				["BackgroundTransparency"] = 1
			}):Play()
			
			if noteObject and noteObject.Parent then
				noteObject:Destroy()
			end

			table.insert(currentLocalState.Passed, beatIndex)
			table.remove(currentLocalState.Notes, arrayIndex)

			if HeartbeatGui.UIScale then
				HeartbeatGui.UIScale.Scale = 1.1
				Vetween.new(HeartbeatGui.UIScale, Vetween.newInfo(2, Vetween.Style.Quint), {
					["Scale"] = 1
				}):Play()
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
				heartbeatAutoClickerActive = false 
				return false 
			end
		end
		if heartbeatConnection then heartbeatConnection:Disconnect() end 
		heartbeatConnection = RunService:BindToRenderStep("HeartbeatAutoClicker", Enum.RenderPriority.Character.Value + 1, onHeartbeatRenderStep)
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Auto Heartbeat Diaktifkan!", Duration = 5, Image = 4483362458})
	else
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Auto Heartbeat Dinonaktifkan!", Duration = 5, Image = 4483362458})
	end
	return true 
end

--==================================================--
--[[            ESP SYSTEM (OPTIMIZED)            ]]--
--==================================================--
local espEnabled = false
local computerESPEnabled = false
local trackedESP = {} -- Tabel untuk melacak semua objek dengan ESP aktif
local ESP_UPDATE_INTERVAL = 0.25 -- Detik. Mengupdate ESP 4x per detik sudah lebih dari cukup.

local function clearESP(model)
	if not model or not trackedESP[model] then return end
	
	local espElements = trackedESP[model]
	if espElements.Tag and espElements.Tag.Parent then espElements.Tag:Destroy() end
	if espElements.Highlight and espElements.Highlight.Parent then espElements.Highlight:Destroy() end
	
	trackedESP[model] = nil
end

local function createOrUpdateESP(model, labelText, fillColor, progressText)
	local root
	if model:IsA("Player") and model.Character then
		model = model.Character
	end
	
	root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("RootPart") or model.PrimaryPart
	if not root then
		-- Fallback untuk model tanpa root part standar (seperti komputer)
		root = model:FindFirstChildWhichIsA("BasePart")
		if not root then return end -- Tidak bisa membuat ESP tanpa part
	end
	
	local espInfo = trackedESP[model] or {}
	local displayText = labelText
	if progressText then
		displayText = displayText .. "\n" .. progressText
	end
	
	-- Buat atau Update BillboardGui
	if not espInfo.Tag or not espInfo.Tag.Parent then
		local gui = Instance.new("BillboardGui")
		gui.Name = "ESPTag"
		gui.Adornee = root
		gui.Size = UDim2.new(0, 150, 0, 60)
		gui.StudsOffset = Vector3.new(0, 5, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		
		local text = Instance.new("TextLabel")
		text.Name = "ESPText"
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.TextColor3 = fillColor
		text.TextStrokeTransparency = 0.3
		text.TextScaled = false
		text.RichText = true
		text.Font = Enum.Font.GothamSemibold
		text.TextSize = 14
		text.TextWrapped = true
		text.Parent = gui
		gui.Parent = model -- Simpan di model agar mudah dibersihkan
		espInfo.Tag = gui
	end
	
	-- Update Teks dan Warna
	local textLabel = espInfo.Tag.ESPText
	textLabel.Text = displayText
	textLabel.TextColor3 = fillColor
	
	-- Buat atau Update Highlight
	if not espInfo.Highlight or not espInfo.Highlight.Parent then
		local hl = Instance.new("Highlight")
		hl.Name = "ESPHighlight"
		hl.Adornee = model
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = model
		espInfo.Highlight = hl
	end
	
	-- Update Warna Highlight
	espInfo.Highlight.FillColor = fillColor
	espInfo.Highlight.OutlineColor = Color3.new(fillColor.r * 0.7, fillColor.g * 0.7, fillColor.b * 0.7)
	espInfo.Highlight.FillTransparency = 0.5
	espInfo.Highlight.OutlineTransparency = 0.2
	
	trackedESP[model] = espInfo
end

local function scanComputersESP()
	if not computerESPEnabled then return end
	
	local tasksFolder = Workspace:FindFirstChild("Tasks", true) 
	if not tasksFolder then return end
	
	for _, item in ipairs(tasksFolder:GetChildren()) do 
		if item:IsA("Model") and item.Name:lower() == "computer" then
			local progress = item:GetAttribute("Progress")
			local completed = item:GetAttribute("Completed")
			
			local progressText
			local espColor
			
			if completed then
				progressText = "Completed"
				espColor = Color3.fromRGB(100, 150, 255) 
			elseif type(progress) == "number" then
				progressText = string.format("Progress: %.1f", progress) 
				espColor = Color3.fromRGB(50, 255, 50)
			else
				progressText = "Progress: N/A" 
				espColor = Color3.fromRGB(50, 255, 50)
			end
			
			createOrUpdateESP(item, "COMPUTER", espColor, progressText)
		end
	end
end

local function updatePlayerESP(player)
	if not espEnabled or player == LocalPlayer then return end
	
	local char = player.Character
	if not char then
		clearESP(char) -- Bersihkan ESP jika karakter tidak ada
		return
	end
	
	local role = player:GetAttribute("Role")
	local color
	local roleText
	
	if role == "Monster" then
		color = Color3.fromRGB(255, 50, 50)
		roleText = "MONSTER"
	elseif role == "Survivor" then
		color = Color3.fromRGB(255, 236, 161)
		roleText = "SURVIVOR"
	else 
		color = Color3.fromRGB(220, 220, 220)
		roleText = player.Name
	end
	
	createOrUpdateESP(char, roleText, color)
end

-- Main ESP Loop (JAUH LEBIH EFISIEN)
task.spawn(function()
	while true do
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
		
		-- Bersihkan ESP untuk objek yang sudah tidak ada
		for model, _ in pairs(trackedESP) do
			if not model or not model.Parent then
				clearESP(model)
			end
		end
		
		task.wait(ESP_UPDATE_INTERVAL)
	end
end)


--==================================================--
--[[            MOVEMENT (OPTIMIZED)              ]]--
--==================================================--
local targetSpeed = 16
local persistentSpeedEnabled = false
local speedConnection = nil
local noclipActive = false

-- Fungsi Noclip yang jauh lebih efisien
local function setNoclip(character, enabled)
	if not character then return end
	pcall(function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = not enabled
			end
		end
	end)
end

--==================================================--
--[[                 UI TOGGLES                   ]]--
--==================================================--
local MainTab = Window:CreateTab("Main", 4483362458)
local MovementTab = Window:CreateTab("Movement", 4483362458)

MainTab:CreateToggle({
	Name = "Auto Heartbeat",
	CurrentValue = heartbeatAutoClickerActive, 
	Flag = "AutoHeartbeatEnabled", 
	Callback = function(Value)
		local success = enableAutoHeartbeat(Value)
		if not success and Value then 
			heartbeatAutoClickerActive = false
			Rayfield:SetFlag("AutoHeartbeatEnabled", false) 
		end
	end
})

MainTab:CreateToggle({
	Name = "ESP Player",
	CurrentValue = espEnabled,
	Flag = "ESPEnabled",
	Callback = function(Value)
		espEnabled = Value
		if not Value then
			-- Hapus semua ESP player yang aktif
			for model, espElements in pairs(trackedESP) do
				if model and model:FindFirstChild("Humanoid") then
					clearESP(model)
				end
			end
		end
	end
})

MainTab:CreateToggle({
	Name = "ESP Computer",
	CurrentValue = computerESPEnabled,
	Flag = "ComputerESPEnabled", 
	Callback = function(Value)
		computerESPEnabled = Value
		if not Value then
			-- Hapus semua ESP komputer yang aktif
			for model, espElements in pairs(trackedESP) do
				if model and model.Name:lower() == "computer" then
					clearESP(model)
				end
			end
		end
	end
})


MovementTab:CreateSlider({
	Name = "Speed Hack (WalkSpeed)",
	Range = {16, 100},
	Increment = 1,
	Suffix = "Speed",
	CurrentValue = 16,
	Flag = "SpeedHackSlider",
	Callback = function(Value)
		targetSpeed = Value
		local char = LocalPlayer.Character
		if char and char:FindFirstChild("Humanoid") then
			char.Humanoid.WalkSpeed = Value
		end
	end,
})

-- Persistent Speed yang dioptimalkan
MovementTab:CreateToggle({
	Name = "Persistent Speed (Anti-Reset)",
	CurrentValue = false,
	Flag = "PersistentSpeedToggle",
	Callback = function(Value)
		persistentSpeedEnabled = Value
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		
		if speedConnection then
			speedConnection:Disconnect()
			speedConnection = nil
		end
		
		if Value and hum then
			hum.WalkSpeed = targetSpeed -- Atur sekali saat diaktifkan
			-- Hanya berjalan KETIKA WalkSpeed diubah oleh script lain / game
			speedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
				if hum.WalkSpeed ~= targetSpeed then
					hum.WalkSpeed = targetSpeed
				end
			end)
		elseif hum then
			-- Kembalikan ke speed default jika mau, atau biarkan saja
			-- hum.WalkSpeed = 16 
		end
	end,
})

-- Noclip yang dioptimalkan
MovementTab:CreateToggle({
	Name = "Noclip",
	CurrentValue = false,
	Flag = "NoclipToggle",
	Callback = function(Value)
		noclipActive = Value
		setNoclip(LocalPlayer.Character, noclipActive)
		
		-- Pastikan noclip tetap aktif setelah respawn
		LocalPlayer.CharacterAdded:Connect(function(character)
			if noclipActive then
				task.wait(0.1) -- Beri waktu sedikit untuk karakter memuat
				setNoclip(character, true)
			end
		end)
	end,
})

Rayfield:Notify({
	Title = "ElHub Loaded!",
	Content = "Selamat datang di ElHub untuk FIVE NIGHT: HUNTED. (Optimized)",
	Duration = 7,
	Image = 4483362458
})