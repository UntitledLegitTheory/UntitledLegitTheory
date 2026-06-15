-- // Matcha Admin Style Cheat Menu + Drag
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")

local aimlockEnabled = false
local silentEnabled = false
local espEnabled = false
local speedEnabled = false
local flyEnabled = false
local noclipEnabled = false
local noRecoilEnabled = false
local godEnabled = false

local speedMult = 2.5
local flySpeed = 60
local fov = 120
local smoothness = 0.25

local target = nil
local bodyVel = nil

-- ==================== GUI ====================
local sg = Instance.new("ScreenGui")
sg.Name = "MatchaAdmin"
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 380, 0, 550)
main.Position = UDim2.new(0.5, -190, 0.5, -275)
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
title.Size = UDim2.new(1, 0, 0, 60)
title.BackgroundTransparency = 1
title.Text = "MATCHA"
title.TextColor3 = Color3.fromRGB(0, 255, 170)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = sidebar

-- Drag Functionality
local dragging = false
local dragInput
local dragStart
local startPos

local function updateInput(input)
    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

uis.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateInput(input)
    end
end)

-- Main Content
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -130, 1, 0)
content.Position = UDim2.new(0, 130, 0, 0)
content.BackgroundTransparency = 1
content.Parent = main

local function createToggle(name, yPos)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 48)
    frame.Position = UDim2.new(0.05, 0, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    frame.Parent = content
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.32, 0, 0.75, 0)
    toggleBtn.Position = UDim2.new(0.63, 0, 0.12, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    toggleBtn.Text = "OFF"
    toggleBtn.TextColor3 = Color3.new(1,1,1)
    toggleBtn.TextScaled = true
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = frame
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

    toggleBtn.MouseButton1Click:Connect(function()
        if name == "Aimlock" then aimlockEnabled = not aimlockEnabled
        elseif name == "Silent Aim" then silentEnabled = not silentEnabled
        elseif name == "ESP" then espEnabled = not espEnabled
        elseif name == "Speed Hack" then speedEnabled = not speedEnabled
        elseif name == "Fly Hack" then flyEnabled = not flyEnabled
        elseif name == "Noclip" then noclipEnabled = not noclipEnabled
        elseif name == "No Recoil" then noRecoilEnabled = not noRecoilEnabled
        elseif name == "Godmode" then godEnabled = not godEnabled
        end

        local isOn = false
        if name == "Aimlock" then isOn = aimlockEnabled
        elseif name == "Silent Aim" then isOn = silentEnabled
        elseif name == "ESP" then isOn = espEnabled
        elseif name == "Speed Hack" then isOn = speedEnabled
        elseif name == "Fly Hack" then isOn = flyEnabled
        elseif name == "Noclip" then isOn = noclipEnabled
        elseif name == "No Recoil" then isOn = noRecoilEnabled
        elseif name == "Godmode" then isOn = godEnabled
        end

        toggleBtn.Text = isOn and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = isOn and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
    end)
end

createToggle("Aimlock", 20)
createToggle("Silent Aim", 75)
createToggle("ESP", 130)
createToggle("Speed Hack", 185)
createToggle("Fly Hack", 240)
createToggle("Noclip", 295)
createToggle("No Recoil", 350)
createToggle("Godmode", 405)

-- Keybinds
local keys = Instance.new("TextLabel")
keys.Size = UDim2.new(0.9, 0, 0, 50)
keys.Position = UDim2.new(0.05, 0, 0, 470)
keys.BackgroundTransparency = 1
keys.Text = "INSERT - Toggle Menu\nDrag by title"
keys.TextColor3 = Color3.fromRGB(170, 170, 170)
keys.TextScaled = true
keys.Font = Enum.Font.Gotham
keys.Parent = content

print("✅ Matcha Menu с Drag загружен! (Перетаскивай за заголовок MATCHA)")
