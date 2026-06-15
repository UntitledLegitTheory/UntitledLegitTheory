-- // SAFE Matcha Menu (только GUI + Drag) — без крашей
local player = game.Players.LocalPlayer
local uis = game:GetService("UserInputService")

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

-- Drag (только за заголовок)
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
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Content
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -130, 1, 0)
content.Position = UDim2.new(0, 130, 0, 0)
content.BackgroundTransparency = 1
content.Parent = main

local function addButton(text, y)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 55)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.Text = text .. " : OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    
    btn.MouseButton1Click:Connect(function()
        if btn.Text:find("OFF") then
            btn.Text = text .. " : ON"
            btn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
        else
            btn.Text = text .. " : OFF"
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        end
    end)
end

addButton("Aimlock", 30)
addButton("Silent Aim", 95)
addButton("ESP", 160)
addButton("Speed Hack", 225)
addButton("Fly Hack", 290)
addButton("Noclip", 355)
addButton("No Recoil", 420)

print("✅ Safe Matcha Menu загружен! (Если не крашится — пиши)")

-- Открытие/закрытие по Insert
uis.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        main.Visible = not main.Visible
    end
end)
