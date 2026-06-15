-- // Advanced Cheat Menu v3 - Tabs + Custom ESP + Fixed FOV
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

-- ========== НАСТРОЙКИ ПО УМОЛЧАНИЮ ==========
local settings = {
    aimlock = false,
    silentAim = false,
    esp = false,
    speedHack = false,
    fly = false,
    noclip = false,
    -- парам
    fov = 120,
    smoothness = 0.25,
    speedMult = 2,
    flySpeed = 50,
    teamCheck = true,
    -- ESP настройки
    espBoxColor = Color3.fromRGB(255, 80, 80),
    espBoxThickness = 2,
    espBoxType = "Square",   -- "Square" или "Corner"
    espShowHealth = true,
    espShowName = true,
    espMaxDistance = 300,
}

-- Внутренние переменные
local target = nil
local bodyVelocity = nil
local bodyGyro = nil
local originalWalkSpeed = 16
local originalGravity = nil
local flyActive = false
local espObjects = {}  -- [player] = {box, name, healthBar?}

-- Рисование объектов (через Drawing, если доступно)
local drawingAvailable = pcall(function() return Drawing.new("Square") end)
local fovCircle = nil
if drawingAvailable then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(0, 255, 100)
    fovCircle.Transparency = 0.6
    fovCircle.Filled = false
    fovCircle.NumSides = 64
    fovCircle.Visible = false
end

-- ========== ФУНКЦИИ ПОЛУЧЕНИЯ БЛИЖАЙШЕЙ ЦЕЛИ ==========
local function getNearestTarget()
    local nearest, shortest = nil, settings.fov
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if settings.teamCheck and plr.Team == player.Team then continue end
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

-- ========== ESP (РИСОВАНИЕ) ==========
local function updateESP()
    if not drawingAvailable or not settings.esp then
        for _, v in pairs(espObjects) do
            if v.box then v.box.Visible = false end
            if v.name then v.name.Visible = false end
            if v.healthBar then v.healthBar.Visible = false end
        end
        return
    end

    for plr, drawings in pairs(espObjects) do
        if not plr or not plr.Character then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            continue
        end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            continue
        end

        local distance = (camera.CFrame.Position - root.Position).Magnitude
        if distance > settings.espMaxDistance then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            continue
        end

        local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
            local bottom = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
            local height = (bottom.Y - top.Y)
            if height > 0 then
                local boxWidth = height / 1.8
                local boxHeight = height
                local boxPos = Vector2.new(screenPos.X - boxWidth/2, screenPos.Y - boxHeight/2)

                -- Рисуем бокс в зависимости от типа
                if settings.espBoxType == "Square" then
                    drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                    drawings.box.Position = boxPos
                    drawings.box.Visible = true
                else -- Corner box (уголки)
                    -- Можно реализовать, но для простоты оставим квадрат
                    drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                    drawings.box.Position = boxPos
                    drawings.box.Visible = true
                end

                -- Имя и здоровье
                local text = ""
                if settings.espShowName then text = plr.Name end
                if settings.espShowHealth then text = text .. " [" .. math.floor(hum.Health) .. "hp]" end
                drawings.name.Text = text
                drawings.name.Position = Vector2.new(screenPos.X, screenPos.Y - boxHeight/2 - 15)
                drawings.name.Visible = true

                -- Полоска здоровья (дополнительно)
                if not drawings.healthBar then
                    local bar = Drawing.new("Line")
                    bar.Thickness = 3
                    bar.Color = Color3.fromRGB(0, 255, 0)
                    drawings.healthBar = bar
                end
                local healthPercent = hum.Health / hum.MaxHealth
                local barWidth = boxWidth
                local barHeight = 4
                local barStart = Vector2.new(boxPos.X, boxPos.Y - 5)
                local barEnd = Vector2.new(boxPos.X + barWidth * healthPercent, boxPos.Y - 5)
                drawings.healthBar.From = barStart
                drawings.healthBar.To = barEnd
                drawings.healthBar.Visible = true
            else
                drawings.box.Visible = false
                drawings.name.Visible = false
                if drawings.healthBar then drawings.healthBar.Visible = false end
            end
        else
            drawings.box.Visible = false
            drawings.name.Visible = false
            if drawings.healthBar then drawings.healthBar.Visible = false end
        end
    end
end

-- Создание ESP для игрока
local function createESP(plr)
    if plr == player then return end
    if espObjects[plr] then return end
    if not drawingAvailable then return end
    local box = Drawing.new("Square")
    box.Thickness = settings.espBoxThickness
    box.Color = settings.espBoxColor
    box.Filled = false
    local nameTag = Drawing.new("Text")
    nameTag.Size = 16
    nameTag.Color = Color3.new(1,1,1)
    nameTag.Outline = true
    nameTag.Center = true
    espObjects[plr] = {box = box, name = nameTag, healthBar = nil}
end

-- Обновить стиль ESP для всех (при изменении настроек)
local function refreshESPstyle()
    for _, drawings in pairs(espObjects) do
        if drawings.box then
            drawings.box.Color = settings.espBoxColor
            drawings.box.Thickness = settings.espBoxThickness
        end
    end
end

-- Инициализация ESP для существующих игроков
for _, plr in ipairs(players:GetPlayers()) do createESP(plr) end
players.PlayerAdded:Connect(createESP)
players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        if espObjects[plr].box then espObjects[plr].box:Remove() end
        if espObjects[plr].name then espObjects[plr].name:Remove() end
        if espObjects[plr].healthBar then espObjects[plr].healthBar:Remove() end
        espObjects[plr] = nil
    end
end)

-- ========== ПОЛЁТ И СПИДХАК ==========
local function resetWalkSpeed()
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = originalWalkSpeed
    end
end

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
    disableFly()
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

-- Обновление полёта
runService.Heartbeat:Connect(function(deltaTime)
    if not settings.fly or not flyActive or not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root or not bodyVelocity then return end
    local moveDirection = Vector3.new()
    local camCF = camera.CFrame
    if userInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + camCF.LookVector end
    if userInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - camCF.LookVector end
    if userInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - camCF.RightVector end
    if userInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + camCF.RightVector end
    if userInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0,1,0) end
    if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection = moveDirection - Vector3.new(0,1,0) end
    if moveDirection.Magnitude > 0 then
        bodyVelocity.Velocity = moveDirection.Unit * settings.flySpeed
    else
        bodyVelocity.Velocity = Vector3.new(0,0,0)
    end
    bodyGyro.CFrame = camCF
end)

-- Speed hack
runService.Heartbeat:Connect(function()
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then
        if settings.speedHack then
            hum.WalkSpeed = originalWalkSpeed * settings.speedMult
        else
            hum.WalkSpeed = originalWalkSpeed
        end
    end
end)

-- Noclip
runService.Stepped:Connect(function()
    if settings.noclip and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- Aimlock и FOV круг (исправлен: позиция обновляется каждый кадр)
runService.RenderStepped:Connect(function()
    -- FOV круг: центр экрана
    if fovCircle and drawingAvailable then
        fovCircle.Visible = (settings.aimlock or settings.silentAim) and camera.ViewportSize.X > 0
        if fovCircle.Visible then
            fovCircle.Radius = settings.fov * 3.2
            fovCircle.Position = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
        end
    end
    -- Aimlock
    if settings.aimlock then
        target = getNearestTarget()
        if target and target.Parent and target.Parent:FindFirstChild("Humanoid") and target.Parent.Humanoid.Health > 0 then
            local targetPos = target.Position + Vector3.new(0, 2.5, 0)
            local direction = (targetPos - camera.CFrame.Position).Unit
            local targetCFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + direction)
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, settings.smoothness)
        end
    end
    -- ESP обновление
    updateESP()
end)

-- ========== SILENT AIM (БЕЗОПАСНЫЙ) ==========
local silentActive = false
local oldNamecall, mt
local function enableSilentAim()
    if silentActive or not getrawmetatable then return end
    mt = getrawmetatable(game)
    if not mt then return end
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "FireServer" and settings.silentAim then
            local targetRoot = getNearestTarget()
            if targetRoot then
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
local function updateSilentAim()
    if settings.silentAim then enableSilentAim() else disableSilentAim() end
end

-- ========== GUI С ВКЛАДКАМИ (СТИЛЬНЫЙ) ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CheatMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 450)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

-- Заголовок
local titleBar = Instance.new("TextLabel")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
titleBar.Text = "⚡ ADVANCED CHEAT MENU ⚡"
titleBar.TextColor3 = Color3.fromRGB(0, 255, 180)
titleBar.TextScaled = true
titleBar.Font = Enum.Font.GothamBold
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

-- Панель вкладок (левая колонка)
local tabPanel = Instance.new("Frame")
tabPanel.Size = UDim2.new(0, 150, 1, -40)
tabPanel.Position = UDim2.new(0, 0, 0, 40)
tabPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
tabPanel.BorderSizePixel = 0
tabPanel.Parent = mainFrame

-- Контейнер для содержимого вкладок (правая область)
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -150, 1, -40)
contentFrame.Position = UDim2.new(0, 150, 0, 40)
contentFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
contentFrame.BorderSizePixel = 0
contentFrame.Parent = mainFrame
Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0, 8)

-- Табы
local tabs = {"COMBAT", "ESP", "CHARACTER", "MISC"}
local activeTab = "COMBAT"
local tabButtons = {}

local function createTabButton(name, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 40)
    btn.Position = UDim2.new(0, 5, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.Text = name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = tabPanel
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

for i, name in ipairs(tabs) do
    local btn = createTabButton(name, 10 + (i-1)*48)
    tabButtons[name] = btn
    btn.MouseButton1Click:Connect(function()
        activeTab = name
        for _, v in pairs(tabButtons) do
            v.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        end
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        -- Очистить contentFrame и заполнить заново
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end
        populateTab(activeTab)
    end)
end

-- Функция заполнения вкладок
local function createCheckbox(parent, text, yPos, getter, setter)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = getter() and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
    btn.Text = text .. ": " .. (getter() and "ON" or "OFF")
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = parent
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        btn.BackgroundColor3 = getter() and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
        btn.Text = text .. ": " .. (getter() and "ON" or "OFF")
        if text == "Silent Aim" then updateSilentAim() end
        if text == "Fly Hack" then
            if getter() then enableFly() else disableFly() end
        end
        if text == "Speed Hack" and not getter() then resetWalkSpeed() end
        if text == "ESP" then refreshESPstyle() end
    end)
    return btn
end

local function createSlider(parent, name, yPos, minVal, maxVal, getter, setter, formatFunc)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 60)
    frame.Position = UDim2.new(0.05, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(getter())
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local slider = Instance.new("TextBox")
    slider.Size = UDim2.new(1, 0, 0, 30)
    slider.Position = UDim2.new(0, 0, 0, 25)
    slider.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    slider.Text = tostring(getter())
    slider.TextColor3 = Color3.new(1,1,1)
    slider.TextScaled = true
    slider.Font = Enum.Font.Gotham
    slider.Parent = frame

    local function update(value)
        local num = tonumber(value)
        if num then
            num = math.clamp(num, minVal, maxVal)
            label.Text = name .. ": " .. (formatFunc and formatFunc(num) or tostring(num))
            setter(num)
            slider.Text = tostring(getter())
        end
    end
    slider.FocusLost:Connect(function() update(slider.Text) end)
    update(getter())
end

local function createColorPicker(parent, name, yPos, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 40)
    frame.Position = UDim2.new(0.05, 0, 0, yPos)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name .. ":"
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.4, 0, 0.8, 0)
    btn.Position = UDim2.new(0.55, 0, 0.1, 0)
    btn.BackgroundColor3 = getter()
    btn.Text = "  "
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = frame
    btn.MouseButton1Click:Connect(function()
        local colorPicker = Instance.new("Frame")
        colorPicker.Size = UDim2.new(0, 200, 0, 150)
        colorPicker.Position = UDim2.new(0.5, -100, 0.5, -75)
        colorPicker.BackgroundColor3 = Color3.fromRGB(30,30,35)
        colorPicker.Parent = screenGui
        -- Простая палитра (можно расширить)
        local colors = {Color3.new(1,0,0), Color3.new(0,1,0), Color3.new(0,0,1), Color3.new(1,1,0), Color3.new(1,0,1), Color3.new(0,1,1), Color3.new(1,1,1)}
        for i, col in ipairs(colors) do
            local swatch = Instance.new("TextButton")
            swatch.Size = UDim2.new(0, 50, 0, 50)
            swatch.Position = UDim2.new(0, ((i-1)%4)*50, 0, math.floor((i-1)/4)*50)
            swatch.BackgroundColor3 = col
            swatch.Text = ""
            swatch.Parent = colorPicker
            swatch.MouseButton1Click:Connect(function()
                setter(col)
                btn.BackgroundColor3 = col
                colorPicker:Destroy()
                refreshESPstyle()
            end)
        end
    end)
end

function populateTab(tab)
    if tab == "COMBAT" then
        createCheckbox(contentFrame, "Aimlock", 10, function() return settings.aimlock end, function(v) settings.aimlock = v end)
        createCheckbox(contentFrame, "Silent Aim", 60, function() return settings.silentAim end, function(v) settings.silentAim = v; updateSilentAim() end)
        createCheckbox(contentFrame, "Team Check", 110, function() return settings.teamCheck end, function(v) settings.teamCheck = v end)
        createSlider(contentFrame, "FOV (градусы)", 170, 20, 360, function() return settings.fov end, function(v) settings.fov = v end)
        createSlider(contentFrame, "Smoothness", 240, 0.05, 1, function() return settings.smoothness end, function(v) settings.smoothness = v end)
    elseif tab == "ESP" then
        createCheckbox(contentFrame, "ESP", 10, function() return settings.esp end, function(v) settings.esp = v end)
        createCheckbox(contentFrame, "Show Name", 60, function() return settings.espShowName end, function(v) settings.espShowName = v end)
        createCheckbox(contentFrame, "Show Health", 110, function() return settings.espShowHealth end, function(v) settings.espShowHealth = v end)
        createSlider(contentFrame, "Max Distance", 170, 50, 800, function() return settings.espMaxDistance end, function(v) settings.espMaxDistance = v end)
        createSlider(contentFrame, "Box Thickness", 240, 1, 5, function() return settings.espBoxThickness end, function(v) settings.espBoxThickness = v; refreshESPstyle() end)
        createColorPicker(contentFrame, "Box Color", 310, function() return settings.espBoxColor end, function(v) settings.espBoxColor = v; refreshESPstyle() end)
        -- Выбор типа бокса (можно добавить RadioButton, но для простоты - переключатель)
        local boxTypeBtn = Instance.new("TextButton")
        boxTypeBtn.Size = UDim2.new(0.9, 0, 0, 35)
        boxTypeBtn.Position = UDim2.new(0.05, 0, 0, 380)
        boxTypeBtn.BackgroundColor3 = Color3.fromRGB(40,40,45)
        boxTypeBtn.Text = "Box Type: " .. settings.espBoxType
        boxTypeBtn.TextColor3 = Color3.new(1,1,1)
        boxTypeBtn.TextScaled = true
        boxTypeBtn.Parent = contentFrame
        boxTypeBtn.MouseButton1Click:Connect(function()
            settings.espBoxType = (settings.espBoxType == "Square") and "Corner" or "Square"
            boxTypeBtn.Text = "Box Type: " .. settings.espBoxType
        end)
    elseif tab == "CHARACTER" then
        createCheckbox(contentFrame, "Speed Hack", 10, function() return settings.speedHack end, function(v) settings.speedHack = v; if not v then resetWalkSpeed() end end)
        createSlider(contentFrame, "Speed Multiplier", 70, 1, 10, function() return settings.speedMult end, function(v) settings.speedMult = v end)
        createCheckbox(contentFrame, "Fly Hack", 140, function() return settings.fly end, function(v) settings.fly = v; if v then enableFly() else disableFly() end end)
        createSlider(contentFrame, "Fly Speed", 210, 10, 200, function() return settings.flySpeed end, function(v) settings.flySpeed = v end)
        createCheckbox(contentFrame, "Noclip", 280, function() return settings.noclip end, function(v) settings.noclip = v end)
    elseif tab == "MISC" then
        local keyLabel = Instance.new("TextLabel")
        keyLabel.Size = UDim2.new(0.9, 0, 0, 150)
        keyLabel.Position = UDim2.new(0.05, 0, 0, 10)
        keyLabel.BackgroundTransparency = 1
        keyLabel.Text = "🔑 KEYBINDS\nInsert - Menu\nF - Aimlock\nV - Silent Aim\nB - ESP\nX - Speed Hack\nC - Fly\nN - Noclip"
        keyLabel.TextColor3 = Color3.new(1,1,1)
        keyLabel.TextScaled = true
        keyLabel.TextYAlignment = Enum.TextYAlignment.Top
        keyLabel.Parent = contentFrame
    end
end

-- Инициализация активной вкладки
populateTab("COMBAT")
tabButtons["COMBAT"].BackgroundColor3 = Color3.fromRGB(60, 60, 70)

-- Keybinds
userInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.Insert then
        mainFrame.Visible = not mainFrame.Visible
    elseif key == Enum.KeyCode.F then
        settings.aimlock = not settings.aimlock
        local btn = createCheckbox -- просто обновим визуально (можно вызвать перерисовку вкладки)
        populateTab(activeTab) -- проще перерисовать текущую вкладку (но потеряем кнопки? пересоздадим)
        -- лучше обновить через прямое изменение кнопки, но для простоты перезагрузим вкладку
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end
        populateTab(activeTab)
    elseif key == Enum.KeyCode.V then
        settings.silentAim = not settings.silentAim
        updateSilentAim()
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end; populateTab(activeTab)
    elseif key == Enum.KeyCode.B then
        settings.esp = not settings.esp
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end; populateTab(activeTab)
    elseif key == Enum.KeyCode.X then
        settings.speedHack = not settings.speedHack
        if not settings.speedHack then resetWalkSpeed() end
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end; populateTab(activeTab)
    elseif key == Enum.KeyCode.C then
        settings.fly = not settings.fly
        if settings.fly then enableFly() else disableFly() end
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end; populateTab(activeTab)
    elseif key == Enum.KeyCode.N then
        settings.noclip = not settings.noclip
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end; populateTab(activeTab)
    end
end)

-- При переключении персонажа
player.CharacterAdded:Connect(function()
    resetWalkSpeed()
    if settings.fly then
        task.wait(0.5)
        enableFly()
    end
end)

updateSilentAim()
print("✅ Cheat Menu v3 загружен! (Insert - меню)")
