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
----------------------------------------------------
-- AUTO HEART BEAT
----------------------------------------------------
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    while not HeartbeatController and controllerFetchAttempts < 50 do -- Coba maksimal 5 detik
        HeartbeatController = Knit.GetController("HeartbeatController")
        if not HeartbeatController then
            controllerFetchAttempts = controllerFetchAttempts + 1
            task.wait(0.1)
        end
    end
     if not HeartbeatController then
        warn("AutoHeartbeat: HeartbeatController tidak ditemukan setelah beberapa kali percobaan.")
        return false
    end

    SoundController = Knit.GetController("SoundController")
    if not SoundController then
        warn("AutoHeartbeat: SoundController tidak ditemukan.")
    end

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    HeartbeatGui = playerGui:WaitForChild("Heartbeat", 5)
    if HeartbeatGui then
        HeartbeatGui = HeartbeatGui:WaitForChild("Heartbeat", 5)
    end

    if not HeartbeatGui then
        warn("AutoHeartbeat: Heartbeat GUI tidak ditemukan.")
        return false
    end
    
    if not (HeartbeatController and HeartbeatController.Trigger) then
        warn("AutoHeartbeat: HeartbeatController.Trigger tidak ditemukan atau tidak valid.")
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
    if not (heartbeatAutoClickerActive and Knit and Vetween and HeartbeatGui and HeartbeatController) then
        return
    end

    local currentLocalState, isGameActive = getCurrentHeartbeatGameStateAndStatus()

    if not isGameActive or not currentLocalState or not currentLocalState.InitTick or not currentLocalState.Beats or not currentLocalState.Notes then
        return
    end

    if #currentLocalState.Notes == 0 then
        return
    end

    local gameTime = tick() - currentLocalState.InitTick
    local bestNoteToHit = nil
    local smallestTimeDifferenceToHitPoint = math.huge

    for i, noteInfo in ipairs(currentLocalState.Notes) do
        local beatIndex = noteInfo[1]
        local noteObject = noteInfo[2]

        if not currentLocalState.Beats[beatIndex] then
            continue
        end

        local targetTime = currentLocalState.Beats[beatIndex]
        local timeUntilHit = targetTime - gameTime
        local diffFromIdealClick = timeUntilHit - HIT_OFFSET_SECONDS

        if diffFromIdealClick >= -PERFECT_WINDOW_SECONDS and diffFromIdealClick <= PERFECT_WINDOW_SECONDS then
            if math.abs(diffFromIdealClick) < smallestTimeDifferenceToHitPoint then
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

        if table.find(currentLocalState.Passed, beatIndex) then
            return
        end

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
                Rayfield:Notify({
                    Title = "Auto Heartbeat",
                    Content = "Gagal menginisialisasi modul. Fitur mungkin tidak bekerja.",
                    Duration = 5,
                    Image = 4483362458
                })
                heartbeatAutoClickerActive = false 
                return false 
            end
        end
        if heartbeatConnection then heartbeatConnection:Disconnect() end 
        heartbeatConnection = RunService:BindToRenderStep("HeartbeatAutoClicker", Enum.RenderPriority.Character.Value + 1, onHeartbeatRenderStep)
        Rayfield:Notify({
            Title = "Auto Heartbeat",
            Content = "Auto Heartbeat Diaktifkan!",
            Duration = 5,
            Image = 4483362458
        })
    else
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end
        Rayfield:Notify({
            Title = "Auto Heartbeat",
            Content = "Auto Heartbeat Dinonaktifkan!",
            Duration = 5,
            Image = 4483362458
        })
    end
    return true 
end

----------------------------------------------------
-- ESP SYSTEM
----------------------------------------------------
local espEnabled = false
local computerESPEnabled = false 
local LocalPlayer = Players.LocalPlayer

-- Buat ESP
local function createESP(model, labelText, fillColor, progressText) -- Tambahkan argumen progressText
    local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("RootPart") or model:FindFirstChild("Torso")
    
    -- Untuk komputer, root mungkin adalah model itu sendiri jika tidak ada part spesifik
    if model.Name:lower():match("computer") and not root then
        -- Coba cari part acak di dalam model komputer sebagai adornee, atau gunakan pivot model jika bisa
        -- Untuk kesederhanaan, kita bisa skip jika tidak ada root part yang jelas untuk komputer
        -- Atau, kita bisa letakkan BillboardGui langsung di model, tapi adornee lebih baik.
        -- Jika model komputer memiliki PrimaryPart, gunakan itu.
        if model.PrimaryPart then
            root = model.PrimaryPart
        else
            -- Fallback jika tidak ada PrimaryPart, coba part pertama yang ditemukan
            local firstPart = model:FindFirstChildWhichIsA("BasePart")
            if firstPart then
                root = firstPart
            else
                 -- warn("[ESP] Tidak dapat menemukan Root Part atau PrimaryPart untuk komputer:", model.Name)
                -- return -- Jangan buat ESP jika tidak ada adornee yang valid
            end
        end
    end

    if not root and not model.Name:lower():match("computer") then -- Jika bukan komputer dan tidak ada root
        return
    end

    local espTag = model:FindFirstChild("ESPTag")
    local espHighlight = model:FindFirstChild("ESPHighlight")

    local displayText = "[" .. labelText .. "] " .. model.Name
    if progressText then
        displayText = displayText .. "\n" .. progressText -- Tambahkan progress text jika ada
    end

    if not espTag then
        local gui = Instance.new("BillboardGui")
        gui.Name = "ESPTag"
        gui.Adornee = root or model -- Jika root masih nil (misal komputer tanpa part), adornee ke model
        gui.Size = UDim2.new(0, 150, 0, 60) -- Perbesar sedikit untuk dua baris teks
        gui.StudsOffset = Vector3.new(0, 3.5, 0)
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0 -- Agar tidak terpengaruh pencahayaan
        gui.ResetOnSpawn = false -- Agar tidak hilang saat karakter respawn (jika adornee karakter)


        local text = Instance.new("TextLabel")
        text.Name = "ESPText"
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.Text = displayText
        text.TextColor3 = fillColor
        text.TextStrokeTransparency = 0.3
        text.TextScaled = false -- Matikan TextScaled agar ukuran font konsisten
        text.RichText = true
        text.Font = Enum.Font.GothamSemibold
        text.TextSize = 14 -- Atur ukuran font
        text.TextWrapped = true -- Aktifkan text wrapping
        text.Parent = gui
        gui.Parent = model
        espTag = gui
    else
        -- Update teks jika ESP tag sudah ada
        local textLabel = espTag:FindFirstChild("ESPText")
        if textLabel then
            textLabel.Text = displayText
            textLabel.TextColor3 = fillColor -- Update warna juga jika berubah (misal status completed)
        end
    end

    if not espHighlight then
        local hl = Instance.new("Highlight")
        hl.Name = "ESPHighlight"
        hl.Adornee = model
        hl.FillColor = fillColor
        hl.OutlineColor = Color3.fromRGB(fillColor.r * 255 * 0.7, fillColor.g * 255 * 0.7, fillColor.b * 255 * 0.7) -- Outline lebih gelap
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0.2
        hl.DepthMode = Enum.HighlightDepthMode.Occluded -- Terlihat meski terhalang
        hl.Parent = model
        espHighlight = hl
    else
        espHighlight.FillColor = fillColor
        espHighlight.OutlineColor = Color3.fromRGB(fillColor.r * 255 * 0.7, fillColor.g * 255 * 0.7, fillColor.b * 255 * 0.7)
    end
end

-- Hapus ESP
local function clearESP(model)
    for _, child in ipairs(model:GetChildren()) do
        if child.Name == "ESPTag" or child.Name == "ESPHighlight" then
            child:Destroy()
        end
    end
end

-- Scan dan update ESP Player
local function scanPlayersESP()
    if not espEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local role = player:GetAttribute("Role")
            local char = player.Character
            if char and char:IsA("Model") then
                if role == "Monster" then
                    createESP(char, "MONSTER", Color3.fromRGB(255, 50, 50))
                elseif role == "Survivor" then
                    createESP(char, "SURVIVOR", Color3.fromRGB(50, 180, 255))
                else 
                    createESP(char, "PLAYER", Color3.fromRGB(220, 220, 220))
                end
            end
        end
    end
end

-- Scan dan update ESP Computer
local function scanComputersESP()
    if not computerESPEnabled then return end
    
    local tasksFolder = workspace:FindFirstChild("Tasks")
    if not tasksFolder then return end

    for _, item in ipairs(tasksFolder:GetChildren()) do -- Hanya cari di dalam folder Tasks
        if item:IsA("Model") and item.Name:lower() == "computer" then
            local progress = item:GetAttribute("Progress")
            local completed = item:GetAttribute("Completed")
            local progressText = ""
            local espColor = Color3.fromRGB(50, 255, 50) -- Warna default untuk komputer (hijau)

            if completed == true then
                progressText = "Completed"
                espColor = Color3.fromRGB(100, 150, 255) -- Warna biru jika sudah selesai
            elseif type(progress) == "number" then
                progressText = string.format("Progress: %.1f", progress) -- Format progress menjadi satu angka desimal
                if progress >= 100 then -- Asumsi progress 100 adalah selesai, bisa disesuaikan
                     -- progressText = "Progress: MAX" -- Atau biarkan angka jika bisa lebih dari 100
                end
            else
                progressText = "Progress: N/A" -- Jika attribute tidak ada atau bukan angka
            end
            createESP(item, "COMPUTER", espColor, progressText)
        end
    end
end


task.spawn(function()
    while RunService.Stepped:Wait() do -- Ganti task.wait dengan loop yang lebih responsif
        if espEnabled then
            pcall(scanPlayersESP)
        end
        if computerESPEnabled then
            pcall(scanComputersESP)
        end
    end
end)

----------------------------------------------------
-- UI TOGGLES
----------------------------------------------------
local MainTab = Window:CreateTab("Main", 4483362458)

local AutoHeartbeatToggle = MainTab:CreateToggle({
    Name = "Auto Heartbeat",
    CurrentValue = heartbeatAutoClickerActive, 
    Flag = "AutoHeartbeatEnabled", 
    Callback = function(Value)
        local success = enableAutoHeartbeat(Value)
        if not success and Value then 
            heartbeatAutoClickerActive = false
            -- Jika Rayfield mendukung, update UI togglenya di sini
            -- AutoHeartbeatToggle:SetValue(false) -- Contoh jika ada API nya
            Rayfield:SetFlag("AutoHeartbeatEnabled", false) -- Coba set flag Rayfield
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
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    if char then clearESP(char) end
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
            local tasksFolder = workspace:FindFirstChild("Tasks")
            if tasksFolder then
                for _, item in ipairs(tasksFolder:GetChildren()) do
                     if item:IsA("Model") and item.Name:lower() == "computer" then
                        clearESP(item)
                    end
                end
            end
            -- Hapus juga ESP komputer di luar folder Tasks jika ada, untuk kebersihan
            for _, item in ipairs(workspace:GetDescendants()) do
                if item:IsA("Model") and item.Name:lower() == "computer" and item:FindFirstChild("ESPTag") then
                    clearESP(item)
                end
            end
        end
    end
})

Rayfield:Notify({
    Title = "ElHub Loaded!",
    Content = "Selamat datang di ElHub untuk FIVE NIGHT: HUNTED.",
    Duration = 7,
    Image = 4483362458,
    Actions = {
        Ignore = {
            Name = "Okay!",
            Callback = function()
                -- print("User dismissed welcome notification.")
            end
        },
    },
})