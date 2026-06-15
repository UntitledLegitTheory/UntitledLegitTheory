-- Matcha Latte Style Cheat Menu
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")

local aimlock = false
local silent = false
local esp = false
local speed = false
local fly = false
local noclip = false
local norecoil = false
local nospread = false
local god = false

local speedVal = 2.5
local flySpeed = 60
local fov = 120
local smoothness = 0.22

local target = nil
local bv = nil

-- GUI
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local f = Instance.new("Frame")
f.Size = UDim2.new(0, 340, 0, 620)
f.Position = UDim2.new(0.5, -170, 0.5, -310)
f.BackgroundColor3 = Color3.fromRGB(15,15,18)
f.Parent = sg

Instance.new("UICorner", f).CornerRadius = UDim.new(0,14)
local s = Instance.new("UIStroke", f)
s.Color = Color3.fromRGB(0,255,180)
s.Thickness = 1.8

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,70)
title.BackgroundTransparency = 1
title.Text = "MATCHA"
title.TextColor3 = Color3.fromRGB(0,255,180)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = f

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1,0,0,20)
sub.Position = UDim2.new(0,0,0,48)
sub.BackgroundTransparency = 1
sub.Text = "Latte • External"
sub.TextColor3 = Color3.fromRGB(120,255,200)
sub.TextScaled = true
sub.Font = Enum.Font.Gotham
sub.Parent = f

local function btn(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.92,0,0,50)
    b.Position = UDim2.new(0.04,0,0,y)
    b.BackgroundColor3 = Color3.fromRGB(25,25,32)
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.TextScaled = true
    b.Font = Enum.Font.GothamSemibold
    b.Parent = f
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", b).Color = Color3.fromRGB(0,255,180)
    return b
end

local aimB = btn("AIMLOCK", 90)
local silB = btn("SILENT AIM", 150)
local espB = btn("ESP BOXES", 210)
local spdB = btn("SPEED HACK", 270)
local flyB = btn("FLY HACK", 330)
local nclB = btn("NOCLIP", 390)
local recB = btn("NO RECOIL", 450)
local sprB = btn("NO SPREAD", 510)
local godB = btn("GODMODE", 570)

-- Keybinds info
local kb = Instance.new("TextLabel")
kb.Size = UDim2.new(0.92,0,0,70)
kb.Position = UDim2.new(0.04,0,0,635)
kb.BackgroundTransparency = 1
kb.Text = "INSERT - Menu\nF/V/B/X/C/N/R/G/H - Toggle"
kb.TextColor3 = Color3.fromRGB(160,160,170)
kb.TextScaled = true
kb.Font = Enum.Font.Gotham
kb.Parent = f

-- (Остальную логику скрипта я могу добавить, если нужно. Сейчас для теста вставь этот код)

print("Matcha Menu loaded")
