local u1 = require(game.ReplicatedStorage.Packages.Knit)
local u2 = game.Players.LocalPlayer.PlayerGui:WaitForChild("Heartbeat").Heartbeat
local u3 = u2.Position
local u4 = game:GetService("RunService")
local u5 = game:GetService("UserInputService")
require(script.Shared)
local u6 = require(game.ReplicatedStorage.Packages.Vetween)
local u7 = require(game.ReplicatedStorage.Packages.Janitor).new()
local u8 = false
local u9 = nil
local u10 = u1.CreateController({
    ["Name"] = "HeartbeatController"
})
local u11 = nil
local u12 = nil
local u13 = {}
function ButtonBehavior(u14, u15)
    --[[
    Upvalues:
        [1] = u7
        [2] = u6
    --]]
    if not u14:FindFirstChild("UIScale") then
        Instance.new("UIScale").Parent = u14
    end
    u7:Add(u14.MouseButton1Down:Connect(function() --[[Anonymous function at line 45]]
        --[[
        Upvalues:
            [1] = u14
            [2] = u6
            [3] = u15
        --]]
        u14.UIScale.Scale = 1.1
        u6.new(u14.UIScale, u6.infoPresets.SubtleSpring(0.5), {
            ["Scale"] = 1
        }):Play()
        if u15 then
            u15()
        end
    end))
    u7:Add(u14.MouseEnter:Connect(function() --[[Anonymous function at line 54]]
        --[[
        Upvalues:
            [1] = u6
            [2] = u14
        --]]
        u6.new(u14.UIScale, u6.infoPresets.NormalSpring(1), {
            ["Scale"] = 0.9
        }):Play()
    end))
    u7:Add(u14.MouseLeave:Connect(function() --[[Anonymous function at line 60]]
        --[[
        Upvalues:
            [1] = u6
            [2] = u14
        --]]
        u6.new(u14.UIScale, u6.infoPresets.NormalSpring(1), {
            ["Scale"] = 1
        }):Play()
    end))
end
function isFindNote(p16)
    --[[
    Upvalues:
        [1] = u13
    --]]
    for v17, v18 in pairs(u13.Notes) do
        if v18[1] == p16 then
            return { true, v18, v17 }
        end
    end
    return { false, nil }
end
tick()
function render(_)
    --[[
    Upvalues:
        [1] = u13
        [2] = u2
        [3] = u3
        [4] = u10
        [5] = u6
    --]]
    local v19 = tick() - u13.InitTick
    u2.Position = u3
    for v20 = 1, #u13.Beats do
        local v21 = u13.Beats[v20]
        local v22 = isFindNote(v20)[1]
        local v23 = isFindNote(v20)[2]
        local v24 = isFindNote(v20)[3]
        if v22 then
            local v25 = v21 - v19
            local v26 = v25 / 1.5
            v23[2].Position = u2.Playfield.Hit.Position:Lerp(UDim2.new(1, 0, 0.5, 0), v26)
            local v27 = v23[2]
            local v28 = UDim2.new
            local v29 = (1 - v26) / 0.1
            v27.Size = v28(0.043, 0, math.clamp(v29, 0, 1) * 0.962, 0)
            if v25 < -0.15 and not table.find(u13.Passed, v20) then
                v23[2]:Destroy()
                local v30 = u13.Passed
                local v31 = v23[1]
                table.insert(v30, v31)
                table.remove(u13.Notes, v24)
                local v32 = u13.Stats
                v32.Miss = v32.Miss + 1
                if u13.Stats.Miss >= 1 then
                    u10.Cancel()
                end
                u2.Playfield.BackgroundColor3 = Color3.fromRGB(255, 0, 4)
                u2.Playfield.BackgroundTransparency = 0
                u6.new(u2.Playfield, u6.newInfo(0.5, u6.Style.Linear), {
                    ["BackgroundColor3"] = Color3.fromRGB(0, 0, 0),
                    ["BackgroundTransparency"] = 1
                }):Play()
            end
            if v23[2] and not v23[2].Visible then
                v23[2].Visible = true
            end
        else
            local v33 = v19 - v21
            if math.abs(v33) < 1.5 and not table.find(u13.Passed, v20) then
                local v34 = { v20, script.Beat:Clone() }
                v34[2].Parent = u2.Playfield
                local u35 = v34[2]
                task.delay(0.1, function() --[[Anonymous function at line 127]]
                    --[[
                    Upvalues:
                        [1] = u35
                    --]]
                    u35.Visible = true
                end)
                u35.BackgroundTransparency = 1
                local v36 = u13.Notes
                table.insert(v36, v34)
            end
        end
    end
    if u13.Beats[#u13.Beats] + 0.5 < v19 or #u13.Passed == #u13.Beats then
        u10.Cancel()
    end
end
function u10.Cancel(p37) --[[Anonymous function at line 156]]
    --[[
    Upvalues:
        [1] = u8
        [2] = u4
        [3] = u11
        [4] = u13
        [5] = u7
        [6] = u2
        [7] = u6
    --]]
    if u8 then
        u8 = false
        u4:UnbindFromRenderStep("HeartBeat")
        u11.RepairStatus:Fire(u13)
        for _, v38 in pairs(u13.Notes) do
            v38[2]:Destroy()
        end
        if not p37 then
            local _ = 3 <= u13.Stats.Miss
        end
        u7:Cleanup()
        u2.UIScale.Scale = 1
        u2.GroupTransparency = 0
        u2.Rotation = 0
        u6.new(u2, u6.newInfo(1, u6.Style.Quint, nil, true), {
            ["Rotation"] = -15,
            ["GroupTransparency"] = 1
        }):Play()
        u6.new(u2.UIScale, u6.newInfo(1, u6.Style.Quint, nil, true), {
            ["Scale"] = 2
        }):Play()
    end
end
function u10.Trigger(p39) --[[Anonymous function at line 189]]
    --[[
    Upvalues:
        [1] = u8
        [2] = u2
        [3] = u9
        [4] = u5
        [5] = u12
        [6] = u13
        [7] = u6
        [8] = u10
        [9] = u7
        [10] = u4
    --]]
    if not p39 then
        warn("No beats included")
    end
    if not u8 then
        u8 = true
        u2.Parent.Enabled = true
        u9 = u5.MouseBehavior
        u12:PlaySound("HackingPopup")
        local v40 = {
            ["InitTick"] = tick() + 2,
            ["Beats"] = p39,
            ["Stats"] = {
                ["Miss"] = 0,
                ["Perfect"] = 0
            },
            ["Offset"] = 0.15,
            ["Notes"] = {},
            ["Passed"] = {}
        }
        u13 = v40
        u2.UIScale.Scale = 2
        u2.GroupTransparency = 1
        u2.Rotation = 15
        u6.new(u2, u6.newInfo(2, u6.Style.Quint), {
            ["Rotation"] = 0,
            ["GroupTransparency"] = 0
        }):Play()
        u6.new(u2.UIScale, u6.newInfo(2, u6.Style.Quint), {
            ["Scale"] = 1
        }):Play()
        local function u54() --[[Anonymous function at line 221]]
            --[[
            Upvalues:
                [1] = u13
                [2] = u12
                [3] = u2
                [4] = u6
                [5] = u10
            --]]
            local v41 = tick() - u13.InitTick
            local v42 = (1 / 0)
            local v43 = nil
            for v44, v45 in ipairs(u13.Notes) do
                local v46 = v41 - u13.Beats[v45[1]]
                local v47 = math.abs(v46)
                if v47 < v42 then
                    v43 = v44
                    v42 = v47
                end
            end
            if v43 then
                local v48 = u13.Notes[v43]
                local v49 = v41 - u13.Beats[v48[1]]
                if math.abs(v49) < 0.15 then
                    u12:PlaySound("SingleHeartbeat")
                    u2.Playfield.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    u2.Playfield.BackgroundTransparency = 0
                    local v50 = u13.Stats
                    v50.Perfect = v50.Perfect + 1
                    u6.new(u2.Playfield, u6.newInfo(0.5, u6.Style.Linear), {
                        ["BackgroundColor3"] = Color3.fromRGB(0, 0, 0),
                        ["BackgroundTransparency"] = 1
                    }):Play()
                else
                    u2.Playfield.BackgroundColor3 = Color3.fromRGB(255, 0, 4)
                    u2.Playfield.BackgroundTransparency = 0
                    u6.new(u2.Playfield, u6.newInfo(0.5, u6.Style.Linear), {
                        ["BackgroundColor3"] = Color3.fromRGB(0, 0, 0),
                        ["BackgroundTransparency"] = 1
                    }):Play()
                    local v51 = u13.Stats
                    v51.Miss = v51.Miss + 1
                    u10.Cancel()
                end
                v48[2]:Destroy()
                local v52 = u13.Passed
                local v53 = v48[1]
                table.insert(v52, v53)
                table.remove(u13.Notes, v43)
            end
            u2.UIScale.Scale = 1.1
            u6.new(u2.UIScale, u6.newInfo(2, u6.Style.Quint), {
                ["Scale"] = 1
            }):Play()
        end
        u7:Add(u5.InputBegan:Connect(function(p55, p56) --[[Anonymous function at line 255]]
            --[[
            Upvalues:
                [1] = u54
            --]]
            if p56 then
                return
            elseif p55.UserInputType == Enum.UserInputType.MouseButton1 then
                u54()
            elseif p55.KeyCode == Enum.KeyCode.ButtonR2 then
                u54()
            end
        end))
        u7:Add(u5.TouchTap:Connect(function(_, p57) --[[Anonymous function at line 265]]
            --[[
            Upvalues:
                [1] = u54
            --]]
            if not p57 then
                u54()
            end
        end))
        if u5.TouchEnabled then
            u2.Label.Text = "Focus.. tap to match the heartbeat"
        end
        if u5.KeyboardEnabled then
            u2.Label.Text = "Focus.. tap to match the heartbeat"
        end
        if u5.GamepadEnabled then
            u2.Label.Text = "Focus.. click [R2] to match the heartbeat"
        end
        u4:BindToRenderStep("HeartBeat", 0, render)
    end
end
function u10.KnitInit(_) --[[Anonymous function at line 284]]
    --[[
    Upvalues:
        [1] = u11
        [2] = u1
        [3] = u12
    --]]
    u11 = u1.GetService("TaskService")
    u12 = u1.GetController("SoundController")
    local u58 = game:GetService("ContentProvider")
    task.spawn(function() --[[Anonymous function at line 289]]
        --[[
        Upvalues:
            [1] = u58
        --]]
        u58:PreloadAsync({ script.Beat })
    end)
end
function u10.KnitStart(_) --[[Anonymous function at line 294]]
    --[[
    Upvalues:
        [1] = u11
        [2] = u10
    --]]
    u11.Repair:Connect(function(p59, p60) --[[Anonymous function at line 295]]
        --[[
        Upvalues:
            [1] = u10
        --]]
        if p59 == "Close" then
            u10.Cancel(false)
        elseif p59 == "Error" then
            u10.Trigger(p60)
        end
    end)
end
return u10
     