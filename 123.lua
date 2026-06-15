-- // Matcha Menu - Современный Fly + Noclip (Luau)
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")

local flyEnabled = false
local noclipEnabled = false
local speedEnabled = false

local flySpeed = 70
local speedMult = 3

-- GUI (оставил минимальную)
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = player.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 360, 0, 480)
main.Position = UDim2.new(0.5, -180, 0.5, -240)
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

-- Кнопки
local function createBtn(text, pos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.85,0,0,50)
    btn.Position = UDim2.new(0.075,0,0,pos)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,35)
    btn.Text = text .. " : OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)

    btn.MouseButton1Click:Connect(function()
        if text == "Fly" then flyEnabled = not flyEnabled
        elseif text == "Noclip" then noclipEnabled = not noclipEnabled
        elseif text == "Speed" then speedEnabled = not speedEnabled
        end
        btn.Text = text .. (btn.Text:find("OFF") and " : ON" or " : OFF")
        btn.BackgroundColor3 = btn.Text:find("ON") and Color3.fromRGB(0,180,90) or Color3.fromRGB(30,30,35)
    end)
end

createBtn("Speed", 80)
createBtn("Fly", 150)
createBtn("Noclip", 220)

-- ==================== Логика ====================

-- Speed
rs.Heartbeat:Connect(function()
    if speedEnabled and player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = 16 * speedMult
    end
end)

-- Fly (самый стабильный метод)
local velocity, gyro

rs.RenderStepped:Connect(function()
    if flyEnabled then
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if not velocity then
                velocity = Instance.new("BodyVelocity")
                gyro = Instance.new("BodyGyro")
                velocity.MaxForce = Vector3.new(9e9,9e9,9e9)
                gyro.MaxTorque = Vector3.new(9e9,9e9,9e9)
                velocity.Parent = root
                gyro.Parent = root
            end

            local moveDir = Vector3.new()
            if uis:IsKeyDown(Enum.KeyCode.W) then moveDir += camera.CFrame.LookVector end
            if uis:IsKeyDown(Enum.KeyCode.S) then moveDir -= camera.CFrame.LookVector end
            if uis:IsKeyDown(Enum.KeyCode.A) then moveDir -= camera.CFrame.RightVector end
            if uis:IsKeyDown(Enum.KeyCode.D) then moveDir += camera.CFrame.RightVector end
            if uis:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
            if uis:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0,1,0) end

            velocity.Velocity = moveDir.Unit * flySpeed
            gyro.CFrame = camera.CFrame
        end
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
        for _, part in pairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

print("✅ Matcha Menu загружен (улучшенный Fly)")
