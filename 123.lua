-- // Hoholware Menu - Исправленная версия
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

local velocity, gyro = nil, nil

-- ==================== GUI ====================
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 720, 0, 380)
main.Position = UDim2.new(0.5, -360, 0.5, -190)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,50)
title.BackgroundTransparency = 1
title.Text = "HOHOLWARE"
title.TextColor3 = Color3.fromRGB(0, 255, 180)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = main

-- Drag
title.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        local startPos = main.Position
        local startMouse = inp.Position
        local conn = uis.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - startMouse
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then conn:Disconnect() end
        end)
    end
end)

-- Панели
local movementPanel = Instance.new("Frame")
movementPanel.Size = UDim2.new(0, 240, 0, 280)
movementPanel.Position = UDim2.new(0, 240, 0, 70)
movementPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
movementPanel.Parent = main
Instance.new("UICorner", movementPanel).CornerRadius = UDim.new(0, 10)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1,0,0,40)
header.BackgroundColor3 = Color3.fromRGB(30,30,35)
header.Text = "MOVEMENT"
header.TextColor3 = Color3.fromRGB(0, 255, 180)
header.TextScaled = true
header.Font = Enum.Font.GothamBold
header.Parent = movementPanel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

-- Функции
local function createToggle(name, y)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9,0,0,45)
    btn.Position = UDim2.new(0.05,0,0,y)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,35)
    btn.Text = name .. " : OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = movementPanel
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    btn.MouseButton1Click:Connect(function()
        if name == "Speed Hack" then 
            speedEnabled = not speedEnabled
        elseif name == "Fly Hack" then 
            flyEnabled = not flyEnabled
        elseif name == "Noclip" then 
            noclipEnabled = not noclipEnabled
        elseif name == "Godmode" then 
            godEnabled = not godEnabled
        end
        
        btn.Text = name .. " : " .. (btn.Text:find("OFF") and "ON" or "OFF")
        btn.BackgroundColor3 = btn.Text:find("ON") and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(30,30,35)
    end)
end

createToggle("Speed Hack", 50)
createToggle("Fly Hack", 105)
createToggle("Noclip", 160)
createToggle("Godmode", 215)

-- Ползунки
local function createSlider(name, minv, maxv, default, y, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9,0,0,50)
    frame.Position = UDim2.new(0.05,0,0,y)
    frame.BackgroundTransparency = 1
    frame.Parent = movementPanel

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,0,20)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. default
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,6)
    bar.Position = UDim2.new(0,0,0,30)
    bar.BackgroundColor3 = Color3.fromRGB(40,40,45)
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5,0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 180)
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            local conn = uis.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    local percent = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                    local value = minv + (maxv - minv) * percent
                    fill.Size = UDim2.new(percent, 0, 1, 0)
                    label.Text = name .. ": " .. string.format("%.1f", value)
                    callback(value)
                end
            end)
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then conn:Disconnect() end
            end)
        end
    end)
end

createSlider("Speed", 1, 6, speedMult, 100, function(v) speedMult = v end)
createSlider("Fly", 30, 150, flySpeed, 170, function(v) flySpeed = v end)

-- Логика (основные функции)
rs.Heartbeat:Connect(function()
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = speedEnabled and 16 * speedMult or 16
    end
end)

rs.RenderStepped:Connect(function()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if flyEnabled and root then
        if not velocity then
            velocity = Instance.new("BodyVelocity")
            gyro = Instance.new("BodyGyro")
            velocity.MaxForce = Vector3.new(9e9,9e9,9e9)
            gyro.MaxTorque = Vector3.new(9e9,9e9,9e9)
            velocity.Parent = root
            gyro.Parent = root
        end
        
        local move = Vector3.new()
        if uis:IsKeyDown(Enum.KeyCode.W) then move += camera.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.S) then move -= camera.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.A) then move -= camera.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.D) then move += camera.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
        if uis:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end

        velocity.Velocity = move.Unit * flySpeed
        gyro.CFrame = camera.CFrame
    elseif velocity then
        velocity:Destroy()
        gyro:Destroy()
        velocity, gyro = nil, nil
    end
end)

rs.Stepped:Connect(function()
    if noclipEnabled and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- Insert
uis.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        main.Visible = not main.Visible
    end
end)

print("✅ Hoholware Menu загружен!")
