-- // Matcha Menu v2 - Широкое и Компактное
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")

-- Настройки
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
main.Size = UDim2.new(0, 560, 0, 420)  -- ← Шире и ниже
main.Position = UDim2.new(0.5, -280, 0.5, -210)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

-- Sidebar (вкладки)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 150, 1, 0)  -- чуть шире
sidebar.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,60)
title.BackgroundTransparency = 1
title.Text = "HOHOLWARE 1.0"
title.TextColor3 = Color3.fromRGB(0, 255, 170)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = sidebar

-- Tab Buttons
local tabs = {}
local currentTab = "Character"

local function switchTab(tabName)
    currentTab = tabName
    for name, frame in pairs(tabs) do
        frame.Visible = (name == tabName)
    end
end

local function createTabButton(text, y, tabName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 50)
    btn.Position = UDim2.new(0, 10, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    btn.Text = text
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    btn.MouseButton1Click:Connect(function()
        switchTab(tabName)
    end)
end

createTabButton("Combat", 80, "Combat")
createTabButton("ESP", 140, "ESP")
createTabButton("Character", 200, "Character")

-- Content Area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -160, 1, 0)
contentArea.Position = UDim2.new(0, 160, 0, 0)
contentArea.BackgroundTransparency = 1
contentArea.Parent = main

-- ==================== Character Tab ====================
local charTab = Instance.new("Frame")
charTab.Size = UDim2.new(1,0,1,0)
charTab.BackgroundTransparency = 1
charTab.Parent = contentArea
tabs.Character = charTab

local function createToggle(parent, name, y)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.95,0,0,55)
    frame.Position = UDim2.new(0.025,0,0,y)
    frame.BackgroundColor3 = Color3.fromRGB(28,28,35)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueBox = Instance.new("TextBox")
    valueBox.Size = UDim2.new(0.22,0,0,38)
    valueBox.Position = UDim2.new(0.48,0,0.15,0)
    valueBox.BackgroundColor3 = Color3.fromRGB(40,40,48)
    valueBox.Text = name == "Speed Hack" and "2.8" or "65"
    valueBox.TextColor3 = Color3.new(1,1,1)
    valueBox.TextScaled = true
    valueBox.Parent = frame
    Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0,8)

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0.25,0,0,38)
    toggle.Position = UDim2.new(0.72,0,0.15,0)
    toggle.BackgroundColor3 = Color3.fromRGB(200,50,50)
    toggle.Text = "OFF"
    toggle.TextColor3 = Color3.new(1,1,1)
    toggle.TextScaled = true
    toggle.Parent = frame
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,8)

    toggle.MouseButton1Click:Connect(function()
        if name == "Speed Hack" then speedEnabled = not speedEnabled
        elseif name == "Fly Hack" then flyEnabled = not flyEnabled
        elseif name == "Noclip" then noclipEnabled = not noclipEnabled
        elseif name == "Godmode" then godEnabled = not godEnabled
        end

        toggle.Text = toggle.Text == "OFF" and "ON" or "OFF"
        toggle.BackgroundColor3 = toggle.Text == "ON" and Color3.fromRGB(0,180,90) or Color3.fromRGB(200,50,50)
    end)

    valueBox.FocusLost:Connect(function()
        if name == "Speed Hack" then 
            speedMult = tonumber(valueBox.Text) or 2.8
        elseif name == "Fly Hack" then 
            flySpeed = tonumber(valueBox.Text) or 65
        end
    end)
end

createToggle(charTab, "Speed Hack", 30)
createToggle(charTab, "Fly Hack", 100)
createToggle(charTab, "Noclip", 170)
createToggle(charTab, "Godmode", 240)

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

-- Insert
uis.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        main.Visible = not main.Visible
    end
end)

switchTab("Character")

print("✅ Широкое компактное меню загружено!")
