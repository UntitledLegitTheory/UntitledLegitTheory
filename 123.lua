-- // SimpleCheat v16 - Стабильная лёгкая версия (только базовые функции)
if getgenv().SimpleCheatLoaded then return end
getgenv().SimpleCheatLoaded = true

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local players = game:GetService("Players")

-- Настройки (включено/выключено)
local aimlock = false
local esp = false
local speedHack = false
local fly = false
local noclip = false

-- Параметры
local fovRadius = 150          -- градусов
local smoothness = 0.3
local speedMult = 2
local flySpeed = 50

-- Внутренние переменные
local originalSpeed = 16
local originalGravity = nil
local bodyVel, bodyGyro = nil, nil
local flyActive = false
local espObjects = {}          -- [player] = {box, name}

-- Рисование (если поддерживается)
local drawingAvailable = pcall(function() return Drawing.new("Square") end)

-- ---------- Аимлок через мышь ----------
local function getAimPosition(character)
    local head = character:FindFirstChild("Head")
    if head then return head.Position + Vector3.new(0, 0.2, 0) end
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
    return torso and torso.Position
end

local function isVisible(part)
    if not part then return true end
    local origin = camera.CFrame.Position
    local dir = (part.Position - origin).Unit
    local ray = Ray.new(origin, dir * (part.Position - origin).Magnitude)
    local hit = workspace:FindPartOnRay(ray, player.Character)
    return not hit or hit:IsDescendantOf(part.Parent)
end

local function getNearestTarget()
    local nearest, bestAngle = nil, fovRadius
    local cursorPos = Vector2.new(mouse.X, mouse.Y)
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local aimPos = getAimPosition(plr.Character)
                if aimPos then
                    local screenPos, onScreen = camera:WorldToViewportPoint(aimPos)
                    if onScreen then
                        local angle = (Vector2.new(screenPos.X, screenPos.Y) - cursorPos).Magnitude
                        if angle < bestAngle then
                            if isVisible(plr.Character:FindFirstChild("Head") or plr.Character.HumanoidRootPart) then
                                bestAngle = angle
                                nearest = aimPos
                            end
                        end
                    end
                end
            end
        end
    end
    return nearest
end

runService.RenderStepped:Connect(function()
    if aimlock and uis:IsKeyDown(Enum.KeyCode.F) then
        local targetPos = getNearestTarget()
        if targetPos then
            local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
            if onScreen then
                local delta = Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mouse.X, mouse.Y)
                if delta.Magnitude > 1 then
                    mousemoverel(delta.X, delta.Y)
                end
            end
        end
    end
end)

-- ---------- ESP (только квадрат и имя) ----------
local function updateESP()
    if not drawingAvailable or not esp then
        for _, d in pairs(espObjects) do
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
        end
        return
    end

    for plr, drawings in pairs(espObjects) do
        if not plr or not plr.Character then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            goto continue
        end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            goto continue
        end
        local dist = (camera.CFrame.Position - root.Position).Magnitude
        if dist > 400 then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            goto continue
        end
        local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
            local bottom = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
            local height = bottom.Y - top.Y
            if height < 5 then height = 50 end
            local width = height / 1.8
            local boxPos = Vector2.new(screenPos.X - width/2, top.Y)
            if not drawings.box then
                drawings.box = Drawing.new("Square")
                drawings.box.Thickness = 2
                drawings.box.Filled = false
                drawings.box.Color = Color3.fromRGB(80, 200, 120)
            end
            drawings.box.Size = Vector2.new(width, height)
            drawings.box.Position = boxPos
            drawings.box.Visible = true
            
            if not drawings.name then
                drawings.name = Drawing.new("Text")
                drawings.name.Size = 14
                drawings.name.Center = true
                drawings.name.Outline = true
                drawings.name.Color = Color3.new(1,1,1)
            end
            drawings.name.Text = plr.Name .. " [" .. math.floor(hum.Health) .. " HP]"
            drawings.name.Position = Vector2.new(screenPos.X, top.Y - 15)
            drawings.name.Visible = true
        else
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
        end
        ::continue::
    end
end

local function createESP(plr)
    if plr == player or espObjects[plr] or not drawingAvailable then return end
    espObjects[plr] = {}
end

players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        if espObjects[plr].box then espObjects[plr].box:Remove() end
        if espObjects[plr].name then espObjects[plr].name:Remove() end
        espObjects[plr] = nil
    end
end)

for _, plr in ipairs(players:GetPlayers()) do createESP(plr) end
players.PlayerAdded:Connect(createESP)
runService.RenderStepped:Connect(updateESP)

-- ---------- Speed, Fly, Noclip ----------
local function resetSpeed()
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = originalSpeed end
end

local function disableFly()
    if bodyVel then bodyVel:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then
        hum.PlatformStand = false
        if originalGravity then workspace.Gravity = originalGravity end
    end
    flyActive = false
    bodyVel, bodyGyro = nil, nil
end

local function enableFly()
    if not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChild("Humanoid")
    if not root or not hum then return end
    disableFly()
    if not originalGravity then originalGravity = workspace.Gravity end
    workspace.Gravity = 0
    hum.PlatformStand = true
    bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVel.Parent = root
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root
    flyActive = true
end

runService.Heartbeat:Connect(function()
    if fly and flyActive and player.Character then
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if root and bodyVel then
            local move = Vector3.new()
            local cf = camera.CFrame
            if uis:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
            if uis:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
            if uis:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
            if uis:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
            if uis:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if uis:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
            bodyVel.Velocity = move.Magnitude > 0 and move.Unit * flySpeed or Vector3.new()
            bodyGyro.CFrame = cf
        end
    end
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then
        if speedHack then
            hum.WalkSpeed = originalSpeed * speedMult
        elseif hum.WalkSpeed ~= originalSpeed then
            hum.WalkSpeed = originalSpeed
        end
    end
end)

runService.Stepped:Connect(function()
    if noclip and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

player.CharacterAdded:Connect(function()
    resetSpeed()
    if fly then task.wait(0.5); enableFly() end
end)

-- ---------- ГУИ (просто кнопки) ----------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SimpleCheat"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0, 320)
mainFrame.Position = UDim2.new(0.5, -125, 0.5, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundTransparency = 1
title.Text = "Simple Cheat"
title.TextColor3 = Color3.fromRGB(80, 200, 120)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -30, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = mainFrame
closeBtn.MouseButton1Click:Connect(function()
    aimlock = false
    esp = false
    speedHack = false
    fly = false
    noclip = false
    if flyActive then disableFly() end
    resetSpeed()
    mainFrame.Visible = false
end)

local function addButton(text, y, getter, setter)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.8, 0, 0, 32)
    btn.Position = UDim2.new(0.1, 0, 0, y)
    btn.BackgroundColor3 = getter() and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 55, 60)
    btn.Text = text .. (getter() and " ON" or " OFF")
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = mainFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        btn.BackgroundColor3 = getter() and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 55, 60)
        btn.Text = text .. (getter() and " ON" or " OFF")
        if text == "Fly" and getter() then enableFly() elseif text == "Fly" and not getter() then disableFly() end
        if text == "Speed" and not getter() then resetSpeed() end
    end)
end

addButton("Aimlock (Hold F)", 50, function() return aimlock end, function(v) aimlock = v end)
addButton("ESP", 95, function() return esp end, function(v) esp = v end)
addButton("Speed Hack", 140, function() return speedHack end, function(v) speedHack = v end)
addButton("Fly Hack", 185, function() return fly end, function(v) fly = v end)
addButton("Noclip", 230, function() return noclip end, function(v) noclip = v end)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0.9, 0, 0, 40)
hint.Position = UDim2.new(0.05, 0, 0, 275)
hint.BackgroundTransparency = 1
hint.Text = "Right Shift - Menu\nF (Hold) - Aimlock"
hint.TextColor3 = Color3.fromRGB(180, 180, 200)
hint.TextScaled = true
hint.Font = Enum.Font.Gotham
hint.Parent = mainFrame

uis.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

print("SimpleCheat v16 загружен. Right Shift - меню.")
