-- // Safe Matcha Menu + Working Cheats (Speed, Fly, Noclip, Godmode)
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")

local speedEnabled = false
local flyEnabled = false
local noclipEnabled = false
local godEnabled = false

local speedMult = 2.8
local flySpeed = 65
local bodyVel = nil

-- ==================== GUI ====================
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 380, 0, 520)
main.Position = UDim2.new(0.5, -190, 0.5, -260)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.BorderSizePixel = 0
main.Parent = sg

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 120, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 70)
title.BackgroundTransparency = 1
title.Text = "MATCHA"
title.TextColor3 = Color3.fromRGB(0, 255, 170)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = sidebar

-- Drag
local dragging = false
local dragStart, startPos

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

uis.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Content
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -130, 1, 0)
content.Position = UDim2.new(0, 130, 0, 0)
content.BackgroundTransparency = 1
content.Parent = main

local function addToggle(name, y)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 55)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.Text = name .. " : OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    btn.MouseButton1Click:Connect(function()
        if name == "Speed Hack" then 
            speedEnabled = not speedEnabled 
        elseif name == "Fly Hack" then 
            flyEnabled = not flyEnabled 
            if flyEnabled then
                bodyVel = Instance.new("BodyVelocity")
                bodyVel.MaxForce = Vector3.new(0,0,0)
                bodyVel.Parent = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            else
                if bodyVel then bodyVel:Destroy() end
            end
        elseif name == "Noclip" then 
            noclipEnabled = not noclipEnabled 
        elseif name == "Godmode" then 
            godEnabled = not godEnabled 
        end

        btn.Text = name .. (btn.Text:find("OFF") and " : ON" or " : OFF")
        btn.BackgroundColor3 = btn.Text:find("ON") and Color3.fromRGB(0, 170, 80) or Color3.fromRGB(30, 30, 35)
    end)
end

addToggle("Speed Hack", 30)
addToggle("Fly Hack", 95)
addToggle("Noclip", 160)
addToggle("Godmode", 225)

-- ==================== Функции ====================

-- Speed Hack
rs.Heartbeat:Connect(function()
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = speedEnabled and 16 * speedMult or 16
    end
end)

-- Fly Hack
rs.RenderStepped:Connect(function()
    if flyEnabled and bodyVel and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local root = player.Character.HumanoidRootPart
        local move = Vector3.new()
        if uis:IsKeyDown(Enum.KeyCode.W) then move += camera.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.S) then move -= camera.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.A) then move -= camera.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.D) then move += camera.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
        if uis:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end

        bodyVel.Velocity = move.Unit * flySpeed
        bodyVel.MaxForce = Vector3.new(400000, 400000, 400000)
    end
end)

-- Noclip
rs.Stepped:Connect(function()
    if noclipEnabled and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Godmode
rs.Heartbeat:Connect(function()
    if godEnabled and player.Character and player.Character:FindFirstChild("Humanoid") then
        local hum = player.Character.Humanoid
        hum.MaxHealth = 9e9
        hum.Health = 9e9
    end
end)

-- Insert toggle
uis.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        main.Visible = not main.Visible
    end
end)

print("✅ Safe Menu + Speed + Fly + Noclip + Godmode загружен!")
