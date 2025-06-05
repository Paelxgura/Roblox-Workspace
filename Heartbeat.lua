-- Auto Repair Heartbeat - Executor Friendly (Auto Trigger)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local function waitForHeartbeatGui()
    repeat task.wait()
    until LocalPlayer:FindFirstChild("PlayerGui") 
        and LocalPlayer.PlayerGui:FindFirstChild("Heartbeat") 
        and LocalPlayer.PlayerGui.Heartbeat:FindFirstChild("Heartbeat")
    return LocalPlayer.PlayerGui.Heartbeat.Heartbeat
end

local function getTriggerFunc()
    local controllerModule = require(game.ReplicatedStorage.Packages.Knit).GetController("HeartbeatController")
    local triggerFunc = controllerModule.Trigger
    if not triggerFunc then
        warn("Trigger function not found.")
        return nil
    end
    return triggerFunc
end

local function getGameState()
    local controller = require(game.ReplicatedStorage.Packages.Knit).GetController("HeartbeatController")
    return debug.getupvalue(controller.Trigger, 6) -- u13 table (game state)
end

local function autoTap()
    local state = getGameState()
    if not state or not state.Beats then return end

    local lastTap = 0
    RunService:BindToRenderStep("HeartbeatAutoTap", 301, function()
        local now = tick()
        local beatIndex, closestDiff = nil, math.huge
        for i, beatTime in ipairs(state.Beats) do
            if not table.find(state.Passed, i) then
                local diff = math.abs(now - state.InitTick - beatTime)
                if diff < closestDiff and diff <= 0.15 then
                    beatIndex, closestDiff = i, diff
                end
            end
        end

        if beatIndex and now - lastTap > 0.15 then
            -- Simulate tap
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 0)
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 0)
            lastTap = now
        end

        if #state.Passed == #state.Beats then
            RunService:UnbindFromRenderStep("HeartbeatAutoTap")
        end
    end)
end

-- Main Execution Flow
task.spawn(function()
    local gui = waitForHeartbeatGui()
    local triggerFunc = getTriggerFunc()
    while true do
        task.wait(1)
        if gui.Visible then
            autoTap()
        end
    end
end)