-- ✅ Load Rayfield UI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ✅ Buat Window utama
local Window = Rayfield:CreateWindow({
    Name = "Advanced ESP",
    LoadingTitle = "Advanced ESP",
    LoadingSubtitle = "with Killer Detection",
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

-- ✅ Buat Tab untuk ESP
local MainTab = Window:CreateTab("ESP", 4483362458)
local espEnabled = false

-- ✅ Fungsi deteksi killer berdasarkan atribut "Role"
local function isKillerCharacter(player)
    return player:GetAttribute("Role") == "Monster"
end

-- ✅ Fungsi buat ESP
local function createESP(player)
    if player == game.Players.LocalPlayer then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    if char:FindFirstChild("ESPTag") then return end

    local isKiller = isKillerCharacter(player)

    -- BillboardGui
    local tag = Instance.new("BillboardGui")
    tag.Name = "ESPTag"
    tag.Adornee = char.HumanoidRootPart
    tag.Size = UDim2.new(0, 100, 0, 40)
    tag.StudsOffset = Vector3.new(0, 3, 0)
    tag.AlwaysOnTop = true

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = isKiller and "[KILLER] " .. player.Name or player.Name
    text.TextColor3 = isKiller and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
    text.TextStrokeTransparency = 0.5
    text.TextScaled = true
    text.Font = Enum.Font.GothamBold
    text.Parent = tag
    tag.Parent = char

    -- Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"
    highlight.FillColor = isKiller and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.4
    highlight.OutlineTransparency = 0
    highlight.Adornee = char
    highlight.Parent = char
end

-- ✅ Hapus ESP dari karakter
local function removeESP(player)
    local char = player.Character
    if char then
        if char:FindFirstChild("ESPTag") then
            char.ESPTag:Destroy()
        end
        if char:FindFirstChild("ESPHighlight") then
            char.ESPHighlight:Destroy()
        end
    end
end

-- ✅ Toggle ESP
MainTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Callback = function(state)
        espEnabled = state
        for _, player in ipairs(game.Players:GetPlayers()) do
            if espEnabled then
                task.spawn(function()
                    task.wait(2) -- tunggu agar Role sudah muncul
                    createESP(player)
                end)
            else
                removeESP(player)
            end
        end
    end
})

-- ✅ Auto ESP saat pemain baru masuk
game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if espEnabled then
            task.wait(2)
            createESP(player)
        end
    end)
end)

-- ✅ Untuk semua pemain yang sudah ada
for _, player in ipairs(game.Players:GetPlayers()) do
    player.CharacterAdded:Connect(function()
        if espEnabled then
            task.wait(2)
            createESP(player)
        end
    end)
end
