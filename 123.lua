-- // Advanced Cheat Menu v5 - Mouse Aimlock + Body Part Select + FOV on Cursor
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

-- ========== НАСТРОЙКИ ==========
local settings = {
    aimlock = false,
    silentAim = false,
    esp = false,
    speedHack = false,
    fly = false,
    noclip = false,
    -- параметры
    fov = 120,
    smoothness = 0.3,
    aimlockKey = "F",
    aimPart = "Head",        -- "Head", "Torso", "Random"
    wallCheck = true,
    teamCheck = true,
    speedMult = 2,
    flySpeed = 50,
    -- ESP
    espBoxColor = Color3.fromRGB(255, 80, 80),
    espBoxThickness = 2,
    espBoxType = "Square",
    espShowName = true,
    espShowHealth = true,
    espShowDistance = false,
    espMaxDistance = 350,
    espHealthBarPosition = "Side",
    espHealthBarWidth = 4,
    espHealthBarColor = Color3.fromRGB(0, 255, 0),
    espOutline = true,
    espNameColor = Color3.fromRGB(255, 255, 255),
}

-- Внутренние переменные
local silentActive = false
local aimlockTarget = nil
local bodyVelocity, bodyGyro = nil, nil
local originalWalkSpeed = 16
local originalGravity = nil
local flyActive = false
local espObjects = {}  -- [player] = {box, name, healthBar, healthBarBG, distanceText, mainBox}
local drawingAvailable = pcall(function() return Drawing.new("Square") end)

-- FOV круг (рисуется вокруг курсора)
local fovCircle = drawingAvailable and Drawing.new("Circle") or nil
if fovCircle then
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(0, 255, 100)
    fovCircle.Transparency = 0.5
    fovCircle.Filled = false
    fovCircle.NumSides = 64
    fovCircle.Visible = false
end

-- ========== ФУНКЦИЯ ПОЛУЧЕНИЯ ПОЗИЦИИ ЧАСТИ ТЕЛА ==========
local function getAimPosition(character)
    if not character then return nil end
    local part = nil
    if settings.aimPart == "Head" then
        part = character:FindFirstChild("Head")
    elseif settings.aimPart == "Torso" then
        part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
    elseif settings.aimPart == "Random" then
        local parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftArm", "RightArm"}
        local validParts = {}
        for _, p in ipairs(parts) do
            local found = character:FindFirstChild(p)
            if found then table.insert(validParts, found) end
        end
        if #validParts > 0 then
            part = validParts[math.random(1, #validParts)]
        end
    end
    if not part then
        part = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    end
    return part and part.Position
end

-- ========== ПРОВЕРКА ВИДИМОСТИ ==========
local function isVisible(part)
    if not part then return false end
    local origin = camera.CFrame.Position
    local direction = (part.Position - origin).Unit
    local ray = Ray.new(origin, direction * (part.Position - origin).Magnitude)
    local hit = workspace:FindPartOnRay(ray, player.Character)
    if hit then
        local hitPart = hit
        if hitPart:IsDescendantOf(part.Parent) then return true end
        return false
    end
    return true
end

-- ========== ПОЛУЧЕНИЕ БЛИЖАЙШЕЙ ЦЕЛИ (УЧЁТ FOV ОТ КУРСОРА) ==========
local function getNearestTargetFromCursor()
    local nearest, shortest = nil, settings.fov
    local cursorPos = Vector2.new(mouse.X, mouse.Y)
    
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if settings.teamCheck and plr.Team == player.Team then continue end
                local aimPos = getAimPosition(plr.Character)
                if not aimPos then continue end
                local screenPos, onScreen = camera:WorldToViewportPoint(aimPos)
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - cursorPos).Magnitude
                    if distance < shortest then
                        if settings.wallCheck then
                            local part = plr.Character:FindFirstChild(settings.aimPart == "Head" and "Head" or "HumanoidRootPart")
                            if not isVisible(part) then continue end
                        end
                        shortest = distance
                        nearest = {plr = plr, position = aimPos, part = plr.Character:FindFirstChild(settings.aimPart == "Head" and "Head" or "HumanoidRootPart")}
                    end
                end
            end
        end
    end
    return nearest
end

-- ========== AIMLOCK ЧЕРЕЗ МЫШЬ (С ПОДДЕРЖКОЙ mousemoverel) ==========
local function moveMouseToTarget(targetInfo)
    if not targetInfo or not targetInfo.position then return end
    local screenPos, onScreen = camera:WorldToViewportPoint(targetInfo.position)
    if onScreen then
        local currentPos = Vector2.new(mouse.X, mouse.Y)
        local targetPos2D = Vector2.new(screenPos.X, screenPos.Y)
        local delta = targetPos2D - currentPos
        if delta.Magnitude > 1 and mousemoverel then
            mousemoverel(delta.X, delta.Y)
        end
    end
end

-- Основной цикл аимлока (с FOV вокруг мыши)
runService.RenderStepped:Connect(function()
    -- Обновляем FOV круг (позиция = курсор)
    if fovCircle then
        fovCircle.Visible = (settings.aimlock or settings.silentAim) and camera.ViewportSize.X > 0
        if fovCircle.Visible then
            fovCircle.Radius = settings.fov * 2.5  -- примерный коэф. для удобства
            fovCircle.Position = Vector2.new(mouse.X, mouse.Y)
        end
    end
    
    -- Аимлок по зажатой клавише
    if settings.aimlock and userInputService:IsKeyDown(Enum.KeyCode[settings.aimlockKey]) then
        local targetInfo = getNearestTargetFromCursor()
        if targetInfo then
            moveMouseToTarget(targetInfo)
            aimlockTarget = targetInfo
        end
    else
        aimlockTarget = nil
    end
end)

-- ========== SILENT AIM / MAGIC BULLET (С УЧЁТОМ ЧАСТИ ТЕЛА) ==========
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
            local targetInfo = getNearestTargetFromCursor()
            if targetInfo and targetInfo.position then
                local targetPos = targetInfo.position
                -- Подмена позиции
                if type(args[1]) == "Vector3" then
                    args[1] = targetPos
                elseif type(args[2]) == "Vector3" then
                    args[2] = targetPos
                end
                -- Подмена CFrame (для орудий с направлением)
                if type(args[1]) == "CFrame" then
                    args[1] = CFrame.new(args[1].Position, targetPos)
                elseif type(args[2]) == "CFrame" then
                    args[2] = CFrame.new(args[2].Position, targetPos)
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

-- ========== ESP С БОКОВОЙ ПОЛОСКОЙ ЗДОРОВЬЯ (ИСПРАВЛЕННЫЙ) ==========
local function updateESP()
    if not drawingAvailable or not settings.esp then
        for _, v in pairs(espObjects) do
            if v.box then v.box.Visible = false end
            if v.name then v.name.Visible = false end
            if v.healthBar then v.healthBar.Visible = false end
            if v.healthBarBG then v.healthBarBG.Visible = false end
            if v.distanceText then v.distanceText.Visible = false end
            if v.mainBox then v.mainBox.Visible = false end
        end
        return
    end

    for plr, drawings in pairs(espObjects) do
        if not plr or not plr.Character then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            if drawings.mainBox then drawings.mainBox.Visible = false end
            continue
        end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            if drawings.mainBox then drawings.mainBox.Visible = false end
            continue
        end

        local distance = (camera.CFrame.Position - root.Position).Magnitude
        if distance > settings.espMaxDistance then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            if drawings.mainBox then drawings.mainBox.Visible = false end
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
                
                -- Отрисовка бокса
                if settings.espBoxType == "Square" then
                    drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                    drawings.box.Position = boxPos
                    drawings.box.Visible = true
                    if drawings.mainBox then drawings.mainBox.Visible = false end
                elseif settings.espBoxType == "Glow" then
                    if not drawings.mainBox then
                        local mainBox = Drawing.new("Square")
                        mainBox.Thickness = settings.espBoxThickness
                        mainBox.Color = settings.espBoxColor
                        mainBox.Filled = false
                        drawings.mainBox = mainBox
                    end
                    drawings.box.Size = Vector2.new(boxWidth+4, boxHeight+4)
                    drawings.box.Position = Vector2.new(boxPos.X-2, boxPos.Y-2)
                    drawings.box.Thickness = settings.espBoxThickness + 2
                    drawings.box.Color = Color3.fromRGB(255,255,255)
                    drawings.box.Visible = true
                    drawings.mainBox.Size = Vector2.new(boxWidth, boxHeight)
                    drawings.mainBox.Position = boxPos
                    drawings.mainBox.Visible = true
                else -- Corner (используем обычный квадрат, но можно доработать)
                    drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                    drawings.box.Position = boxPos
                    drawings.box.Visible = true
                    if drawings.mainBox then drawings.mainBox.Visible = false end
                end

                -- Имя, здоровье, дистанция
                local text = ""
                if settings.espShowName then text = plr.Name end
                if settings.espShowDistance then text = text .. " [" .. math.floor(distance) .. "m]" end
                if settings.espShowHealth then text = text .. " ❤" .. math.floor(hum.Health) end
                drawings.name.Text = text
                drawings.name.Position = Vector2.new(screenPos.X, screenPos.Y - boxHeight/2 - 15)
                drawings.name.Visible = true
                drawings.name.Color = settings.espNameColor
                drawings.name.Size = 14
                drawings.name.Outline = settings.espOutline

                -- Полоска здоровья (сбоку или сверху)
                if settings.espHealthBarPosition == "Side" then
                    local barWidth = settings.espHealthBarWidth
                    local healthPercent = hum.Health / hum.MaxHealth
                    local barHeight = boxHeight * healthPercent
                    local barPos = Vector2.new(boxPos.X - barWidth - 2, boxPos.Y + (boxHeight - barHeight))
                    if not drawings.healthBar then
                        drawings.healthBar = Drawing.new("Line")
                        drawings.healthBar.Thickness = barWidth
                        drawings.healthBar.Color = settings.espHealthBarColor
                        drawings.healthBarBG = Drawing.new("Line")
                        drawings.healthBarBG.Thickness = barWidth
                        drawings.healthBarBG.Color = Color3.fromRGB(50, 50, 50)
                    end
                    drawings.healthBarBG.From = Vector2.new(barPos.X, boxPos.Y)
                    drawings.healthBarBG.To = Vector2.new(barPos.X, boxPos.Y + boxHeight)
                    drawings.healthBar.From = barPos
                    drawings.healthBar.To = Vector2.new(barPos.X, barPos.Y + barHeight)
                    drawings.healthBar.Visible = true
                    drawings.healthBarBG.Visible = true
                else -- Top
                    local barWidth = boxWidth
                    local barHeight = 4
                    local healthPercent = hum.Health / hum.MaxHealth
                    local barStart = Vector2.new(boxPos.X, boxPos.Y - 6)
                    local barEnd = Vector2.new(boxPos.X + barWidth * healthPercent, boxPos.Y - 6)
                    if not drawings.healthBar then
                        drawings.healthBar = Drawing.new("Line")
                        drawings.healthBar.Thickness = barHeight
                        drawings.healthBar.Color = settings.espHealthBarColor
                        drawings.healthBarBG = Drawing.new("Line")
                        drawings.healthBarBG.Thickness = barHeight
                        drawings.healthBarBG.Color = Color3.fromRGB(50, 50, 50)
                    end
                    drawings.healthBarBG.From = Vector2.new(boxPos.X, boxPos.Y - 6)
                    drawings.healthBarBG.To = Vector2.new(boxPos.X + barWidth, boxPos.Y - 6)
                    drawings.healthBar.From = barStart
                    drawings.healthBar.To = barEnd
                    drawings.healthBar.Visible = true
                    drawings.healthBarBG.Visible = true
                end

                if settings.espBoxType ~= "Glow" then
                    drawings.box.Thickness = settings.espBoxThickness
                    drawings.box.Color = settings.espBoxColor
                elseif drawings.mainBox then
                    drawings.mainBox.Thickness = settings.espBoxThickness
                    drawings.mainBox.Color = settings.espBoxColor
                end
            else
                drawings.box.Visible = false
                drawings.name.Visible = false
                if drawings.healthBar then drawings.healthBar.Visible = false end
                if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
                if drawings.mainBox then drawings.mainBox.Visible = false end
            end
        else
            drawings.box.Visible = false
            drawings.name.Visible = false
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            if drawings.mainBox then drawings.mainBox.Visible = false end
        end
    end
end

-- Создание ESP объекта
local function createESP(plr)
    if plr == player or espObjects[plr] then return end
    if not drawingAvailable then return end
    local box = Drawing.new("Square")
    box.Thickness = settings.espBoxThickness
    box.Color = settings.espBoxColor
    box.Filled = false
    local nameTag = Drawing.new("Text")
    nameTag.Size = 14
    nameTag.Color = settings.espNameColor
    nameTag.Outline = settings.espOutline
    nameTag.Center = true
    espObjects[plr] = {box = box, name = nameTag, healthBar = nil, healthBarBG = nil, mainBox = nil}
end

-- Удаление при выходе
players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        if espObjects[plr].box then espObjects[plr].box:Remove() end
        if espObjects[plr].name then espObjects[plr].name:Remove() end
        if espObjects[plr].healthBar then espObjects[plr].healthBar:Remove() end
        if espObjects[plr].healthBarBG then espObjects[plr].healthBarBG:Remove() end
        if espObjects[plr].mainBox then espObjects[plr].mainBox:Remove() end
        espObjects[plr] = nil
    end
end)

for _, plr in ipairs(players:GetPlayers()) do createESP(plr) end
players.PlayerAdded:Connect(createESP)

-- Запуск обновления ESP
runService.RenderStepped:Connect(updateESP)

-- ========== SPEED HACK, FLY, NOCLIP (без изменений, стабильно) ==========
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

runService.Heartbeat:Connect(function()
    if settings.fly and flyActive and player.Character then
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if root and bodyVelocity then
            local moveDir = Vector3.new()
            local camCF = camera.CFrame
            if userInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
            if userInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
            if userInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
            if userInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
            if userInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
            if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
            bodyVelocity.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * settings.flySpeed or Vector3.new()
            bodyGyro.CFrame = camCF
        end
    end
    if settings.speedHack and player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = originalWalkSpeed * settings.speedMult
    elseif player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.WalkSpeed ~= originalWalkSpeed then
        player.Character.Humanoid.WalkSpeed = originalWalkSpeed
    end
end)

runService.Stepped:Connect(function()
    if settings.noclip and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end
end)

player.CharacterAdded:Connect(function()
    resetWalkSpeed()
    if settings.fly then task.wait(0.5); enableFly() end
end)

-- ========== НОВОЕ МЕНЮ С ВЫБОРОМ ЧАСТИ ТЕЛА ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CheatMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 540, 0, 480)
mainFrame.Position = UDim2.new(0.5, -270, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 12)
pcall(function() mainFrame.BackgroundTransparency = 0.3 end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "✦ C H E A T   M E N U ✦"
title.TextColor3 = Color3.fromRGB(220, 220, 240)
title.TextScaled = true
title.Font = Enum.Font.Gotham
title.Parent = mainFrame

-- Табы
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 36)
tabBar.Position = UDim2.new(0, 0, 0, 40)
tabBar.BackgroundTransparency = 1
tabBar.Parent = mainFrame

local tabs = {"⚔️ Combat", "👁️ ESP", "🧬 Char", "⚙️ Misc"}
local activeTab = "⚔️ Combat"
local tabButtons = {}
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -86)
contentFrame.Position = UDim2.new(0, 10, 0, 76)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 1, 0)
    btn.Position = UDim2.new(0, (i-1)*115, 0, 0)
    btn.BackgroundTransparency = 1
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 220)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = tabBar
    tabButtons[name] = btn
    btn.MouseButton1Click:Connect(function()
        activeTab = name
        for _, b in pairs(tabButtons) do b.TextColor3 = Color3.fromRGB(200,200,220) end
        btn.TextColor3 = Color3.fromRGB(0, 255, 180)
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end
        populateTab(activeTab)
    end)
end
tabButtons["⚔️ Combat"].TextColor3 = Color3.fromRGB(0, 255, 180)

-- Вспомогательные функции UI
local function createToggle(parent, text, y, getter, setter)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.45, 0, 0, 32)
    btn.Position = UDim2.new(0, 0, 0, y)
    btn.BackgroundColor3 = getter() and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 70)
    btn.Text = text .. (getter() and " ✓" : "")
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        btn.BackgroundColor3 = getter() and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 70)
        btn.Text = text .. (getter() and " ✓" : "")
        if text:find("Silent") then updateSilentAim() end
        if text:find("Fly") then if getter() then enableFly() else disableFly() end end
        if text:find("Speed") and not getter() then resetWalkSpeed() end
    end)
    return btn
end

local function createSlider(parent, name, y, minVal, maxVal, getter, setter, format)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 50)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(getter())
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.3, 0, 0, 28)
    box.Position = UDim2.new(0.65, 0, 0, 0)
    box.BackgroundColor3 = Color3.fromRGB(40,40,45)
    box.Text = tostring(getter())
    box.TextColor3 = Color3.new(1,1,1)
    box.Font = Enum.Font.Gotham
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local function update(val)
        local num = tonumber(val)
        if num then
            num = math.clamp(num, minVal, maxVal)
            label.Text = name .. ": " .. (format and format(num) or tostring(num))
            setter(num)
            box.Text = tostring(getter())
        end
    end
    box.FocusLost:Connect(function() update(box.Text) end)
    update(getter())
end

local function createColorPicker(parent, name, y, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 30)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.3, 0, 0.8, 0)
    btn.Position = UDim2.new(0.65, 0, 0.1, 0)
    btn.BackgroundColor3 = getter()
    btn.Text = ""
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(function()
        local picker = Instance.new("Frame")
        picker.Size = UDim2.new(0, 180, 0, 120)
        picker.Position = UDim2.new(0.5, -90, 0.5, -60)
        picker.BackgroundColor3 = Color3.fromRGB(30,30,35)
        picker.Parent = screenGui
        local colors = {Color3.new(1,0.2,0.2), Color3.new(0.2,1,0.2), Color3.new(0.2,0.5,1), Color3.new(1,1,0.2), Color3.new(1,0.5,0), Color3.new(1,0,1), Color3.new(0,1,1)}
        for i, col in ipairs(colors) do
            local sw = Instance.new("TextButton")
            sw.Size = UDim2.new(0, 40, 0, 40)
            sw.Position = UDim2.new(0, ((i-1)%4)*45, 0, math.floor((i-1)/4)*45)
            sw.BackgroundColor3 = col
            sw.Text = ""
            sw.Parent = picker
            sw.MouseButton1Click:Connect(function()
                setter(col)
                btn.BackgroundColor3 = col
                picker:Destroy()
            end)
        end
    end)
end

local function createDropdown(parent, name, y, options, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 50)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.45, 0, 0, 32)
    btn.Position = UDim2.new(0.5, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(60,60,70)
    btn.Text = getter()
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        local dropdownFrame = Instance.new("Frame")
        dropdownFrame.Size = UDim2.new(0, 150, 0, #options * 32)
        dropdownFrame.Position = UDim2.new(0, btn.AbsolutePosition.X - frame.AbsolutePosition.X, 0, 32)
        dropdownFrame.BackgroundColor3 = Color3.fromRGB(40,40,45)
        dropdownFrame.Parent = frame
        Instance.new("UICorner", dropdownFrame).CornerRadius = UDim.new(0, 6)
        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 30)
            optBtn.Position = UDim2.new(0, 0, 0, (i-1)*30)
            optBtn.BackgroundTransparency = 1
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.new(1,1,1)
            optBtn.TextScaled = true
            optBtn.Font = Enum.Font.Gotham
            optBtn.Parent = dropdownFrame
            optBtn.MouseButton1Click:Connect(function()
                setter(opt)
                btn.Text = opt
                dropdownFrame:Destroy()
            end)
        end
        -- Закрыть при клике вне
        local function closeOnClick(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if not dropdownFrame:IsAncestorOf(input.Origin) and dropdownFrame.Parent then
                    dropdownFrame:Destroy()
                    userInputService.InputBegan:Disconnect(closeConn)
                end
            end
        end
        local closeConn = userInputService.InputBegan:Connect(closeOnClick)
    end)
end

function populateTab(tab)
    if tab == "⚔️ Combat" then
        createToggle(contentFrame, "Aimlock (Hold F)", 10, function() return settings.aimlock end, function(v) settings.aimlock = v end)
        createToggle(contentFrame, "Silent Aim", 55, function() return settings.silentAim end, function(v) settings.silentAim = v; updateSilentAim() end)
        createToggle(contentFrame, "Team Check", 100, function() return settings.teamCheck end, function(v) settings.teamCheck = v end)
        createToggle(contentFrame, "Wall Check", 145, function() return settings.wallCheck end, function(v) settings.wallCheck = v end)
        createDropdown(contentFrame, "Aim Part", 200, {"Head", "Torso", "Random"}, function() return settings.aimPart end, function(v) settings.aimPart = v end)
        createSlider(contentFrame, "FOV (pixels)", 270, 30, 400, function() return settings.fov end, function(v) settings.fov = v end)
        createSlider(contentFrame, "Smoothness", 330, 0.1, 1, function() return settings.smoothness end, function(v) settings.smoothness = v end)
    elseif tab == "👁️ ESP" then
        createToggle(contentFrame, "Enable ESP", 10, function() return settings.esp end, function(v) settings.esp = v end)
        createToggle(contentFrame, "Show Name", 55, function() return settings.espShowName end, function(v) settings.espShowName = v end)
        createToggle(contentFrame, "Show Health", 100, function() return settings.espShowHealth end, function(v) settings.espShowHealth = v end)
        createToggle(contentFrame, "Show Distance", 145, function() return settings.espShowDistance end, function(v) settings.espShowDistance = v end)
        createSlider(contentFrame, "Max Distance", 200, 50, 800, function() return settings.espMaxDistance end, function(v) settings.espMaxDistance = v end)
        createSlider(contentFrame, "Box Thickness", 260, 1, 5, function() return settings.espBoxThickness end, function(v) settings.espBoxThickness = v end)
        createColorPicker(contentFrame, "Box Color", 320, function() return settings.espBoxColor end, function(v) settings.espBoxColor = v end)
        createColorPicker(contentFrame, "Name Color", 370, function() return settings.espNameColor end, function(v) settings.espNameColor = v end)
        local boxTypeBtn = Instance.new("TextButton")
        boxTypeBtn.Size = UDim2.new(0.45, 0, 0, 32)
        boxTypeBtn.Position = UDim2.new(0, 0, 0, 420)
        boxTypeBtn.BackgroundColor3 = Color3.fromRGB(60,60,70)
        boxTypeBtn.Text = "Box Type: " .. settings.espBoxType
        boxTypeBtn.TextColor3 = Color3.new(1,1,1)
        boxTypeBtn.Font = Enum.Font.Gotham
        boxTypeBtn.Parent = contentFrame
        boxTypeBtn.MouseButton1Click:Connect(function()
            local types = {"Square", "Corner", "Glow"}
            local idx = table.find(types, settings.espBoxType) or 1
            idx = idx % 3 + 1
            settings.espBoxType = types[idx]
            boxTypeBtn.Text = "Box Type: " .. settings.espBoxType
        end)
    elseif tab == "🧬 Char" then
        createToggle(contentFrame, "Speed Hack", 10, function() return settings.speedHack end, function(v) settings.speedHack = v end)
        createSlider(contentFrame, "Speed Multiplier", 65, 1, 10, function() return settings.speedMult end, function(v) settings.speedMult = v end)
        createToggle(contentFrame, "Fly Hack", 130, function() return settings.fly end, function(v) settings.fly = v; if v then enableFly() else disableFly() end end)
        createSlider(contentFrame, "Fly Speed", 190, 10, 200, function() return settings.flySpeed end, function(v) settings.flySpeed = v end)
        createToggle(contentFrame, "Noclip", 260, function() return settings.noclip end, function(v) settings.noclip = v end)
    elseif tab == "⚙️ Misc" then
        local keyLabel = Instance.new("TextLabel")
        keyLabel.Size = UDim2.new(1, 0, 0, 180)
        keyLabel.Position = UDim2.new(0, 0, 0, 10)
        keyLabel.BackgroundTransparency = 1
        keyLabel.Text = "⌨️  KEYBINDS\n\nInsert → Show/Hide Menu\nF (Hold) → Aimlock\nV → Silent Aim toggle\nB → ESP toggle\nX → Speed Hack toggle\nC → Fly toggle\nN → Noclip toggle\n\nFOV circle follows your mouse cursor."
        keyLabel.TextColor3 = Color3.new(200,200,220)
        keyLabel.TextScaled = true
        keyLabel.TextXAlignment = Enum.TextXAlignment.Left
        keyLabel.TextYAlignment = Enum.TextYAlignment.Top
        keyLabel.Font = Enum.Font.Gotham
        keyLabel.Parent = contentFrame
    end
end

populateTab("⚔️ Combat")

-- Keybinds
userInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.Insert then
        mainFrame.Visible = not mainFrame.Visible
    elseif k == Enum.KeyCode.V then
        settings.silentAim = not settings.silentAim
        updateSilentAim()
        populateTab(activeTab)  -- обновить UI
    elseif k == Enum.KeyCode.B then
        settings.esp = not settings.esp
        populateTab(activeTab)
    elseif k == Enum.KeyCode.X then
        settings.speedHack = not settings.speedHack
        if not settings.speedHack then resetWalkSpeed() end
        populateTab(activeTab)
    elseif k == Enum.KeyCode.C then
        settings.fly = not settings.fly
        if settings.fly then enableFly() else disableFly() end
        populateTab(activeTab)
    elseif k == Enum.KeyCode.N then
        settings.noclip = not settings.noclip
        populateTab(activeTab)
    end
end)

-- Инициализация
updateSilentAim()
print("✅ Cheat Menu v5 (FOV on cursor + Body part select) загружен. Insert - меню.")
