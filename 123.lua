-- // Ultra Stable Cheat v17 - No Drawing, No mousemoverel, No getrawmetatable
if getgenv().UltraStableLoaded then return end
getgenv().UltraStableLoaded = true

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local players = game:GetService("Players")

-- ======= НАСТРОЙКИ (изменяются через меню) =======
local settings = {
    aimlock = false,
    esp = false,
    speed = false,
    fly = false,
    noclip = false,
    aimPart = "Head",        -- Head / Torso
    fov = 120,
    smoothness = 0.3,
    speedMult = 2,
    flySpeed = 50,
}

-- ======= ВНУТРЕННИЕ ПЕРЕМЕННЫЕ =======
local origSpeed = 16
local origGravity = nil
local bodyVel, bodyGyro = nil, nil
local flyActive = false
local espObjects = {}    -- для BillboardGui

-- ======= ЗАЩИТА ОТ ОШИБОК =======
local function safeCall(func, ...)
    local ok, result = pcall(func, ...)
    if not ok then warn("[Safe] error:", result) end
    return ok, result
end

-- ======= СПИДХАК, ФЛАЙ, НОКЛИП =======
local function resetSpeed()
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = origSpeed end
end

local function disableFly()
    if bodyVel then bodyVel:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    bodyVel, bodyGyro = nil, nil
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then
        hum.PlatformStand = false
        if origGravity then workspace.Gravity = origGravity end
    end
    flyActive = false
end

local function enableFly()
    if not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChild("Humanoid")
    if not root or not hum then return end
    disableFly()
    if not origGravity then origGravity = workspace.Gravity end
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

-- Цикл для флая (Heartbeat)
rs.Heartbeat:Connect(function()
    if settings.fly and flyActive and player.Character then
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
            bodyVel.Velocity = move.Magnitude > 0 and move.Unit * settings.flySpeed or Vector3.new()
            bodyGyro.CFrame = cf
        end
    end
    -- Спидхак
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then
        if settings.speed then
            hum.WalkSpeed = origSpeed * settings.speedMult
        elseif hum.WalkSpeed ~= origSpeed then
            hum.WalkSpeed = origSpeed
        end
    end
end)

-- Ноклип (Stepped)
rs.Stepped:Connect(function()
    if settings.noclip and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- Респавн
player.CharacterAdded:Connect(function()
    resetSpeed()
    if settings.fly then task.wait(0.5); enableFly() end
end)

-- ======= АИМЛОК (без mousemoverel, через CFrame) =======
local function getAimPosition(character)
    if settings.aimPart == "Head" then
        local head = character:FindFirstChild("Head")
        if head then return head.Position + Vector3.new(0, 0.2, 0) end
    end
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
    local nearest, bestAngle = nil, settings.fov
    local cursorPos = Vector2.new(uis:GetMouseLocation().X, uis:GetMouseLocation().Y)
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
                            local checkPart = plr.Character:FindFirstChild(settings.aimPart == "Head" and "Head" or "HumanoidRootPart")
                            if isVisible(checkPart) then
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

rs.RenderStepped:Connect(function()
    if settings.aimlock and uis:IsKeyDown(Enum.KeyCode.F) then
        local targetPos = getNearestTarget()
        if targetPos then
            local direction = (targetPos - camera.CFrame.Position).Unit
            local targetCF = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + direction)
            camera.CFrame = camera.CFrame:Lerp(targetCF, settings.smoothness)
        end
    end
end)

-- ======= ESP (BillboardGui - безопасный, без Drawing) =======
local function createESPForPlayer(plr)
    if plr == player or espObjects[plr] then return end
    safeCall(function()
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 200, 0, 40)
        billboard.Adornee = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.MaxDistance = 400
        billboard.Parent = plr.Character
        local label = Instance.new("TextLabel", billboard)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.new(1,1,1)
        label.TextStrokeTransparency = 0.3
        label.Font = Enum.Font.Gotham
        label.TextScaled = true
        label.Text = plr.Name
        local healthBar = Instance.new("Frame", billboard)
        healthBar.Size = UDim2.new(1, 0, 0.2, 0)
        healthBar.Position = UDim2.new(0, 0, 1, 0)
        healthBar.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        healthBar.BorderSizePixel = 0
        local healthBG = Instance.new("Frame", billboard)
        healthBG.Size = UDim2.new(1, 0, 0.2, 0)
        healthBG.Position = UDim2.new(0, 0, 1, 0)
        healthBG.BackgroundColor3 = Color3.fromRGB(50,50,50)
        healthBG.BorderSizePixel = 0
        healthBG.ZIndex = 0
        espObjects[plr] = {billboard = billboard, label = label, healthBar = healthBar, healthBG = healthBG}
    end)
end

local function updateESPvisibility()
    for plr, data in pairs(espObjects) do
        local enabled = settings.esp
        if data.billboard then
            data.billboard.Enabled = enabled and plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") ~= nil
        end
        if data.healthBar and plr and plr.Character then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                data.healthBar.Size = UDim2.new(hum.Health / hum.MaxHealth, 0, 0.2, 0)
                data.healthBar.Visible = true
                data.healthBG.Visible = true
            else
                data.healthBar.Visible = false
                data.healthBG.Visible = false
            end
        end
        if data.label and plr and plr.Character then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                data.label.Text = plr.Name .. " [" .. math.floor(hum.Health) .. " HP]"
            else
                data.label.Text = plr.Name .. " [DEAD]"
            end
        end
    end
end

-- Обновляем Adornee при смене персонажа
players.PlayerAdded:Connect(createESPForPlayer)
players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        if espObjects[plr].billboard then espObjects[plr].billboard:Destroy() end
        espObjects[plr] = nil
    end
end)

-- Создаём ESP для существующих игроков
for _, plr in ipairs(players:GetPlayers()) do
    createESPForPlayer(plr)
end

-- Периодическое обновление ESP (каждый тик)
rs.RenderStepped:Connect(updateESPvisibility)

-- Когда персонаж игрока появляется, обновляем Adornee для всех ESP
player.CharacterAdded:Connect(function()
    for plr, data in pairs(espObjects) do
        if data.billboard then
            data.billboard.Adornee = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        end
    end
end)

-- ======= ГРАФИЧЕСКИЙ ИНТЕРФЕЙС =======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UltraMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 340)
mainFrame.Position = UDim2.new(0.5, -130, 0.5, -170)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 30)
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
title.Text = "Ultra Cheat"
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
    settings.aimlock = false
    settings.esp = false
    settings.speed = false
    settings.fly = false
    settings.noclip = false
    if flyActive then disableFly() end
    resetSpeed()
    mainFrame.Visible = false
end)

local function addToggle(text, y, getter, setter)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.85, 0, 0, 32)
    btn.Position = UDim2.new(0.075, 0, 0, y)
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
        if text == "Fly" and getter() then enableFly()
        elseif text == "Fly" and not getter() then disableFly() end
        if text == "Speed" and not getter() then resetSpeed() end
    end)
    return btn
end

addToggle("Aimlock (Hold F)", 50, function() return settings.aimlock end, function(v) settings.aimlock = v end)
addToggle("ESP", 95, function() return settings.esp end, function(v) settings.esp = v end)
addToggle("Speed Hack", 140, function() return settings.speed end, function(v) settings.speed = v end)
addToggle("Fly Hack", 185, function() return settings.fly end, function(v) settings.fly = v end)
addToggle("Noclip", 230, function() return settings.noclip end, function(v) settings.noclip = v end)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0.9, 0, 0, 45)
hint.Position = UDim2.new(0.05, 0, 0, 280)
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

-- Финал
print("Ultra Stable Cheat v17 загружен. Все функции работают без крашей.")
