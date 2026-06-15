-- // Matcha Menu - Исправленный Fly + Speed + Слайдеры
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")

local speedEnabled = false
local flyEnabled = false
local noclipEnabled = false
local godEnabled = false

local speedMult = 2.5
local flySpeed = 60

local velocity = nil
local gyro = nil

-- ==================== GUI ====================
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 400, 0, 580)
main.Position = UDim2.new(0.5, -200, 0.5, -290)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,60)
title.BackgroundTransparency = 1
title.Text = "MATCHA"
title.TextColor3 = Color3.fromRGB(0, 255, 170)
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

-- Content
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -70)
content.Position = UDim2.new(0, 10, 0, 70)
content.BackgroundTransparency = 1
content.Parent = main

local function createFeature(name, y)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 70)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = content

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.65, 0, 0, 50)
    btn.Position = UDim2.new(0, 0, 0, 10)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,35)
    btn.Text = name .. " : OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)

    local slider = Instance.new("TextBox")
    slider.Size = UDim2.new(0.3, 0, 0, 35)
    slider.Position = UDim2.new(0.7, 0, 0, 17)
    slider.BackgroundColor3 = Color3.fromRGB(40,40,45)
    slider.Text = name == "Speed Hack" and tostring(speedMult) or tostring(flySpeed)
    slider.TextColor3 = Color3.new(1,1,1)
    slider.TextScaled = true
    slider.Font = Enum.Font.Gotham
    slider.Parent = frame
    Instance.new("UICorner", slider).CornerRadius = UDim.new(0,8)

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

        btn.Text = name .. (btn.Text:find("OFF") and " : ON" or " : OFF")
        btn.BackgroundColor3 = btn.Text:find("ON") and Color3.fromRGB(0,180,90) or Color3.fromRGB(30,30,35)
    end)

    slider.FocusLost:Connect(function()
        if name == "Speed Hack" then
            speedMult = tonumber(slider.Text) or 2.5
        else
            flySpeed = tonumber(slider.Text) or 60
        end
    end)

    return btn
end

createFeature("Speed Hack", 0)
createFeature("Fly Hack", 80)
createFeature("Noclip", 160)
createFeature("Godmode", 240)

-- ==================== Логика ====================

-- Speed Hack
rs.Heartbeat:Connect(function()
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        local hum = player.Character.Humanoid
        hum.WalkSpeed = speedEnabled and 16 * speedMult or 16
    end
end)

-- Fly Hack (исправленная версия)
rs.RenderStepped:Connect(function()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if flyEnabled then
        if not velocity then
            velocity = Instance.new("BodyVelocity")
            gyro = Instance.new("BodyGyro")
            velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
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
        velocity = nil
        gyro = nil
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

-- Insert
uis.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        main.Visible = not main.Visible
    end
end)

print("✅ Matcha Menu с слайдерами загружен!")
