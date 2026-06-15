-- // Advanced Cheat Menu - AIM+ESP+SILENT+SPEED+FLY+NOCLIP (Улучшенная версия)
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

-- Настройки (изменяемые)
local aimlockEnabled = false
local silentAimEnabled = false
local espEnabled = false
local speedHackEnabled = false
local flyEnabled = false
local noclipEnabled = false

local speedMultiplier = 2
local flySpeed = 50
local fovRadius = 120          -- градусов для поиска цели
local smoothness = 0.25
local teamCheck = true          -- не атаковать своих

-- Внутренние переменные
local target = nil
local bodyVelocity = nil
local bodyGyro = nil
local originalWalkSpeed = 16    -- сохраним стандартную скорость
local originalGravity = nil
local flyActive = false
local espObjects = {}            -- { [player] = {box, name} }

-- ==================== СОЗДАНИЕ GUI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CheatMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 600)
frame.Position = UDim2.new(0.5, -160, 0.5, -300)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 45)
title.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
title.Text = "⚡ Cheat Menu ⚡"
title.TextColor3 = Color3.fromRGB(0, 255, 100)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

-- Функция создания кнопки-переключателя
local function createToggle(name, posY, default)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 36)
    btn.Position = UDim2.new(0.05, 0, 0, posY)
    btn.BackgroundColor3 = default and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
    btn.Text = name .. ": " .. (default and "ON" or "OFF")
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = frame
    return btn
end

-- Создаём кнопки
local aimBtn     = createToggle("Aimlock", 55, false)
local silentBtn  = createToggle("Silent Aim", 100, false)
local espBtn     = createToggle("ESP", 145, false)
local speedBtn   = createToggle("Speed Hack", 190, false)
local flyBtn     = createToggle("Fly Hack", 235, false)
local noclipBtn  = createToggle("Noclip", 280, false)

-- Ползунки для настроек
local function createSlider(name, posY, minVal, maxVal, defaultVal, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(0.9, 0, 0, 50)
    sliderFrame.Position = UDim2.new(0.05, 0, 0, posY)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(defaultVal)
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = sliderFrame

    local slider = Instance.new("TextBox")
    slider.Size = UDim2.new(1, 0, 0, 25)
    slider.Position = UDim2.new(0, 0, 0, 22)
    slider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    slider.Text = tostring(defaultVal)
    slider.TextColor3 = Color3.new(1,1,1)
    slider.TextScaled = true
    slider.Font = Enum.Font.Gotham
    slider.Parent = sliderFrame

    local function update(value)
        local num = tonumber(value)
        if num then
            num = math.clamp(num, minVal, maxVal)
            label.Text = name .. ": " .. tostring(num)
            callback(num)
        end
    end

    slider.FocusLost:Connect(function()
        update(slider.Text)
        slider.Text = tostring(callback()) -- показать текущее значение
    end)
    update(defaultVal)
    return callback
end

local fovValue = fovRadius
local smoothValue = smoothness
local speedMultValue = speedMultiplier
local flySpeedValue = flySpeed

createSlider("FOV (градусы)", 335, 20, 360, fovRadius, function(val) fovValue = val end)
createSlider("Smoothness (0-1)", 390, 0.05, 1, smoothness, function(val) smoothValue = val end)
createSlider("Speed множитель", 445, 1, 10, speedMultiplier, function(val) speedMultValue = val; if speedHackEnabled then player.Character.Humanoid.WalkSpeed = originalWalkSpeed * speedMultValue end end)
createSlider("Fly скорость", 500, 10, 200, flySpeed, function(val) flySpeedValue = val; if flyEnabled and bodyVelocity then bodyVelocity.Velocity = bodyVelocity.Velocity.Unit * flySpeedValue end end)

-- Подсказка по клавишам
local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.new(0.9, 0, 0, 60)
keyLabel.Position = UDim2.new(0.05, 0, 0, 555)
keyLabel.BackgroundTransparency = 1
keyLabel.Text = "🔑 Keybinds:\nInsert - Menu | F - Aim | V - Silent | B - ESP | X - Speed | C - Fly | N - Noclip"
keyLabel.TextColor3 = Color3.new(1,1,1)
keyLabel.TextScaled = true
keyLabel.TextYAlignment = Enum.TextYAlignment.Top
keyLabel.Parent = frame

-- ==================== FOV КРУГ (Drawing) ====================
local fovCircle = nil
if pcall(function() return Drawing.new("Circle") end) then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(0, 255, 100)
    fovCircle.Transparency = 0.6
    fovCircle.Filled = false
    fovCircle.NumSides = 64
    fovCircle.Visible = false
    fovCircle.Radius = fovValue * 3.2
else
    warn("⚠️ Drawing API недоступна, FOV круг не будет работать")
end

-- ==================== ESP (Drawing) ====================
local function createESP(plr)
    if plr == player then return end
    if espObjects[plr] then return end
    local box, nameTag
    if pcall(function() return Drawing.new("Square") end) then
        box = Drawing.new("Square")
        box.Thickness = 2
        box.Color = Color3.fromRGB(255, 50, 50)
        box.Filled = false
        nameTag = Drawing.new("Text")
        nameTag.Size = 16
        nameTag.Color = Color3.new(1,1,1)
        nameTag.Outline = true
        nameTag.Center = true
        espObjects[plr] = {box = box, name = nameTag}
    end
end

for _, plr in ipairs(players:GetPlayers()) do createESP(plr) end

players.PlayerAdded:Connect(createESP)
players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        if espObjects[plr].box then espObjects[plr].box:Remove() end
        if espObjects[plr].name then espObjects[plr].name:Remove() end
        espObjects[plr] = nil
    end
end)

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================
local function getNearestTarget()
    local nearest, shortest = nil, fovValue
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if teamCheck and plr.Team == player.Team then continue end
                local root = plr.Character.HumanoidRootPart
                local vector = (root.Position - camera.CFrame.Position)
                local angle = math.acos(camera.CFrame.LookVector:Dot(vector.Unit)) * (180 / math.pi)
                if angle < shortest then
                    shortest = angle
                    nearest = root
                end
            end
        end
    end
    return nearest
end

-- Безопасное восстановление скорости
local function resetWalkSpeed()
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = originalWalkSpeed
    end
end

-- Управление полётом
local function disableFly()
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.PlatformStand = false
        if originalGravity and workspace.Gravity ~= originalGravity then
            workspace.Gravity = originalGravity
        end
    end
    flyActive = false
end

local function enableFly()
    if not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChild("Humanoid")
    if not root or not hum then return end

    disableFly() -- чистим старые объекты
    
    -- Сохраняем гравитацию
    if not originalGravity then originalGravity = workspace.Gravity end
    workspace.Gravity = 0
    hum.PlatformStand = true
    
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVelocity.Parent = root
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root
    
    flyActive = true
end

-- Обновление полёта в Heartbeat (для плавности)
runService.Heartbeat:Connect(function(deltaTime)
    if not flyEnabled or not flyActive or not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root or not bodyVelocity then return end
    
    local moveDirection = Vector3.new()
    local cameraCFrame = camera.CFrame
    
    if userInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + cameraCFrame.LookVector end
    if userInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - cameraCFrame.LookVector end
    if userInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - cameraCFrame.RightVector end
    if userInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + cameraCFrame.RightVector end
    if userInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
    if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end
    
    if moveDirection.Magnitude > 0 then
        bodyVelocity.Velocity = moveDirection.Unit * flySpeedValue
    else
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end
    bodyGyro.CFrame = cameraCFrame
end)

-- ==================== ОСНОВНЫЕ ЛУПЫ ====================
-- 1. Aimlock + FOV круг
runService.RenderStepped:Connect(function()
    if fovCircle then
        fovCircle.Visible = (aimlockEnabled or silentAimEnabled) and camera.ViewportSize.X > 0
        if fovCircle.Visible then
            fovCircle.Radius = fovValue * 3.2
            fovCircle.Position = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
        end
    end
    
    if aimlockEnabled then
        target = getNearestTarget()
        if target and target.Parent and target.Parent:FindFirstChild("Humanoid") and target.Parent.Humanoid.Health > 0 then
            local targetPos = target.Position + Vector3.new(0, 2.5, 0)
            local direction = (targetPos - camera.CFrame.Position).Unit
            local targetCFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + direction)
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothValue)
        end
    end
end)

-- 2. Speed Hack (Heartbeat - стабильнее)
runService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    if speedHackEnabled then
        if hum.WalkSpeed ~= originalWalkSpeed * speedMultValue then
            hum.WalkSpeed = originalWalkSpeed * speedMultValue
        end
    else
        if hum.WalkSpeed ~= originalWalkSpeed then
            hum.WalkSpeed = originalWalkSpeed
        end
    end
end)

-- 3. Noclip (Stepped - обновляем коллизию)
runService.Stepped:Connect(function()
    if noclipEnabled and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- 4. ESP (RenderStepped + защита от ошибок)
runService.RenderStepped:Connect(function()
    if not espEnabled then
        for _, v in pairs(espObjects) do
            if v.box then v.box.Visible = false end
            if v.name then v.name.Visible = false end
        end
        return
    end
    
    for plr, drawings in pairs(espObjects) do
        if not plr or not plr.Character then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            continue
        end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            continue
        end
        
        local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
            local bottom = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
            local height = (bottom.Y - top.Y)
            if height > 0 then
                drawings.box.Size = Vector2.new(height / 1.8, height)
                drawings.box.Position = Vector2.new(screenPos.X - drawings.box.Size.X/2, screenPos.Y - drawings.box.Size.Y/2)
                drawings.box.Visible = true
                drawings.name.Text = plr.Name .. " [" .. math.floor(hum.Health) .. "hp]"
                drawings.name.Position = Vector2.new(screenPos.X, screenPos.Y - drawings.box.Size.Y/2 - 15)
                drawings.name.Visible = true
            end
        else
            drawings.box.Visible = false
            drawings.name.Visible = false
        end
    end
end)

-- ==================== SILENT AIM (безопасный перехват) ====================
local silentActive = false
local oldNamecall = nil
local mt = nil

local function enableSilentAim()
    if silentActive then return end
    if not getrawmetatable then 
        warn("getrawmetatable не поддерживается, Silent Aim отключён")
        return 
    end
    mt = getrawmetatable(game)
    if not mt then return end
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "FireServer" and silentAimEnabled then
            local targetRoot = getNearestTarget()
            if targetRoot then
                -- Пытаемся подменить позицию (первый аргумент обычно Vector3)
                if type(args[1]) == "Vector3" then
                    args[1] = targetRoot.Position + Vector3.new(0, 2.5, 0)
                elseif type(args[2]) == "Vector3" then
                    args[2] = targetRoot.Position + Vector3.new(0, 2.5, 0)
                end
            end
        end
        return oldNamecall(self, unpack(args))
    end)
    setreadonly(mt, true)
    silentActive = true
end

local function disableSilentAim()
    if not silentActive or not mt then return end
    setreadonly(mt, false)
    mt.__namecall = oldNamecall
    setreadonly(mt, true)
    silentActive = false
end

-- Включаем/выключаем silent aim при изменении настройки
local function updateSilentAim()
    if silentAimEnabled then
        enableSilentAim()
    else
        disableSilentAim()
    end
end

-- ==================== ОБРАБОТЧИКИ КНОПОК И KEYBINDS ====================
local function toggleAim() aimlockEnabled = not aimlockEnabled; aimBtn.Text = "Aimlock: " .. (aimlockEnabled and "ON" or "OFF"); aimBtn.BackgroundColor3 = aimlockEnabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50) end
local function toggleSilent() silentAimEnabled = not silentAimEnabled; silentBtn.Text = "Silent Aim: " .. (silentAimEnabled and "ON" or "OFF"); silentBtn.BackgroundColor3 = silentAimEnabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50); updateSilentAim() end
local function toggleEsp() espEnabled = not espEnabled; espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF"); espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50) end
local function toggleSpeed() speedHackEnabled = not speedHackEnabled; speedBtn.Text = "Speed Hack: " .. (speedHackEnabled and "ON" or "OFF"); speedBtn.BackgroundColor3 = speedHackEnabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50); if not speedHackEnabled then resetWalkSpeed() end end
local function toggleFly() flyEnabled = not flyEnabled; flyBtn.Text = "Fly Hack: " .. (flyEnabled and "ON" or "OFF"); flyBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50); if flyEnabled then enableFly() else disableFly() end end
local function toggleNoclip() noclipEnabled = not noclipEnabled; noclipBtn.Text = "Noclip: " .. (noclipEnabled and "ON" or "OFF"); noclipBtn.BackgroundColor3 = noclipEnabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50) end

aimBtn.MouseButton1Click:Connect(toggleAim)
silentBtn.MouseButton1Click:Connect(toggleSilent)
espBtn.MouseButton1Click:Connect(toggleEsp)
speedBtn.MouseButton1Click:Connect(toggleSpeed)
flyBtn.MouseButton1Click:Connect(toggleFly)
noclipBtn.MouseButton1Click:Connect(toggleNoclip)

userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        frame.Visible = not frame.Visible
    elseif input.KeyCode == Enum.KeyCode.F then
        toggleAim()
    elseif input.KeyCode == Enum.KeyCode.V then
        toggleSilent()
    elseif input.KeyCode == Enum.KeyCode.B then
        toggleEsp()
    elseif input.KeyCode == Enum.KeyCode.X then
        toggleSpeed()
    elseif input.KeyCode == Enum.KeyCode.C then
        toggleFly()
    elseif input.KeyCode == Enum.KeyCode.N then
        toggleNoclip()
    end
end)

-- ==================== ОЧИСТКА ПРИ ВЫХОДЕ ====================
player.CharacterAdded:Connect(function()
    resetWalkSpeed()
    if flyEnabled then
        task.wait(0.5)
        enableFly()
    end
end)

-- Обработка смены камеры (например, зритель)
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    if fovCircle then
        fovCircle.Visible = false
    end
end)

-- Инициализация silent aim (отключён по умолчанию)
updateSilentAim()

print("✅ Улучшенный Cheat Menu загружен! (Insert - меню)")
