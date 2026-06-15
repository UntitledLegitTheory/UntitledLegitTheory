-- // Hoholware Menu - Горизонтальный Redline Style
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

-- GUI
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 780, 0, 380)
main.Position = UDim2.new(0.5, -390, 0.5, -190)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,45)
title.BackgroundTransparency = 1
title.Text = "HOHOLWARE"          -- ← Изменено
title.TextColor3 = Color3.fromRGB(0, 255, 200)
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

-- Создание панелей
local function createPanel(name, posX)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 240, 0, 300)
    panel.Position = UDim2.new(0, posX, 0, 55)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    panel.Parent = main
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1,0,0,32)
    header.BackgroundColor3 = Color3.fromRGB(25,25,32)
    header.Text = name
    header.TextColor3 = Color3.fromRGB(0, 255, 200)
    header.TextScaled = true
    header.Font = Enum.Font.GothamBold
    header.Parent = panel
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

    return panel
end

local combatPanel = createPanel("COMBAT", 20)
local movementPanel = createPanel("MOVEMENT", 270)
local miscPanel = createPanel("MISC", 520)

-- Toggle функция
local function createToggle(panel, name, y)
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0.9,0,0,45)
    toggle.Position = UDim2.new(0.05,0,0,y)
    toggle.BackgroundColor3 = Color3.fromRGB(30,30,35)
    toggle.Text = name .. " : OFF"
    toggle.TextColor3 = Color3.new(1,1,1)
    toggle.TextScaled = true
    toggle.Font = Enum.Font.GothamSemibold
    toggle.Parent = panel
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,8)

    toggle.MouseButton1Click:Connect(function()
        if name == "Speed Hack" then speedEnabled = not speedEnabled
        elseif name == "Fly Hack" then flyEnabled = not flyEnabled
        elseif name == "Noclip" then noclipEnabled = not noclipEnabled
        elseif name == "Godmode" then godEnabled = not godEnabled
        end
        toggle.Text = name .. " : " .. (toggle.Text:find("OFF") and "ON" or "OFF")
        toggle.BackgroundColor3 = toggle.Text:find("ON") and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(30,30,35)
    end)
end

createToggle(movementPanel, "Speed Hack", 45)
createToggle(movementPanel, "Fly Hack", 105)
createToggle(movementPanel, "Noclip", 165)
createToggle(movementPanel, "Godmode", 225)

-- Ползунки
local function createSlider(panel, name, minv, maxv, default, y, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9,0,0,50)
    frame.Position = UDim2.new(0.05,0,0,y)
    frame.BackgroundTransparency = 1
    frame.Parent = panel

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
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
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

createSlider(movementPanel, "Speed", 1, 6, speedMult, 100, function(v) speedMult = v end)
createSlider(movementPanel, "Fly", 30, 150, flySpeed, 160, function(v) flySpeed = v end)

-- Insert
uis.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        main.Visible = not main.Visible
    end
end)

print("✅ Hoholware Menu загружено!")
