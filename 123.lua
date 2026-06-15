-- // Matcha Cheat Menu v7 - Right Shift menu, all bugs fixed
if getgenv().MatchaMenuLoaded then return end
getgenv().MatchaMenuLoaded = true

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
    fov = 120,
    smoothness = 0.3,
    aimlockKey = "F",
    aimPart = "Head",
    wallCheck = true,
    teamCheck = true,
    speedMult = 2,
    flySpeed = 50,
    espBoxColor = Color3.fromRGB(80, 200, 120),
    espBoxThickness = 2,
    espBoxType = "Square",
    espShowName = true,
    espShowHealth = true,
    espShowDistance = false,
    espMaxDistance = 350,
    espHealthBarPosition = "Side",
    espHealthBarWidth = 4,
    espHealthBarColor = Color3.fromRGB(80, 200, 120),
    espNameColor = Color3.fromRGB(255, 255, 255),
}

-- Внутренние переменные
local silentActive = false
local bodyVelocity, bodyGyro = nil, nil
local originalWalkSpeed = 16
local originalGravity = nil
local flyActive = false
local espObjects = {}
local drawingAvailable = pcall(function() return Drawing.new("Square") end)

-- FOV круг (вокруг мыши)
local fovCircle = drawingAvailable and Drawing.new("Circle") or nil
if fovCircle then
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(80, 200, 120)
    fovCircle.Transparency = 0.5
    fovCircle.Filled = false
    fovCircle.NumSides = 64
    fovCircle.Visible = false
end

-- ========== УТИЛИТЫ ==========
local function tableFind(t, value)
    for i, v in ipairs(t) do if v == value then return i end end
    return nil
end

-- ========== ПОЛУЧЕНИЕ ПОЗИЦИИ ЦЕЛИ ==========
local function getAimPosition(character)
    if not character then return nil end
    local part = nil
    if settings.aimPart == "Head" then
        part = character:FindFirstChild("Head")
    elseif settings.aimPart == "Torso" then
        part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
    elseif settings.aimPart == "Random" then
        local parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
        local valid = {}
        for _, p in ipairs(parts) do
            local found = character:FindFirstChild(p)
            if found then table.insert(valid, found) end
        end
        if #valid > 0 then part = valid[math.random(#valid)] end
    end
    if not part then
        part = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    end
    return part and part.Position
end

local function isVisible(part)
    if not part then return false end
    local origin = camera.CFrame.Position
    local direction = (part.Position - origin).Unit
    local ray = Ray.new(origin, direction * (part.Position - origin).Magnitude)
    local hit = workspace:FindPartOnRay(ray, player.Character)
    return hit and hit:IsDescendantOf(part.Parent)
end

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
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - cursorPos).Magnitude
                    if dist < shortest then
                        if settings.wallCheck then
                            local checkPart = plr.Character:FindFirstChild(settings.aimPart == "Head" and "Head" or "HumanoidRootPart")
                            if not isVisible(checkPart) then continue end
                        end
                        shortest = dist
                        nearest = {plr = plr, position = aimPos, part = plr.Character:FindFirstChild(settings.aimPart == "Head" and "Head" or "HumanoidRootPart")}
                    end
                end
            end
        end
    end
    return nearest
end

-- ========== AIMLOCK (С ПОДДЕРЖКОЙ mouse + fallback) ==========
local function moveMouseToTarget(targetInfo)
    if not targetInfo or not targetInfo.position then return end
    local screenPos, onScreen = camera:WorldToViewportPoint(targetInfo.position)
    if onScreen then
        local delta = Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mouse.X, mouse.Y)
        if delta.Magnitude > 1 then
            if mousemoverel then
                mousemoverel(delta.X, delta.Y)
            else
                -- fallback: плавное перемещение камеры (менее точно, но работает)
                local direction = (targetInfo.position - camera.CFrame.Position).Unit
                local targetCFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + direction)
                camera.CFrame = camera.CFrame:Lerp(targetCFrame, settings.smoothness)
            end
        end
    end
end

runService.RenderStepped:Connect(function()
    if fovCircle then
        fovCircle.Visible = (settings.aimlock or settings.silentAim) and camera.ViewportSize.X > 0
        if fovCircle.Visible then
            fovCircle.Radius = settings.fov * 2.5
            fovCircle.Position = Vector2.new(mouse.X, mouse.Y)
        end
    end
    if settings.aimlock and userInputService:IsKeyDown(Enum.KeyCode[settings.aimlockKey]) then
        local targetInfo = getNearestTargetFromCursor()
        if targetInfo then moveMouseToTarget(targetInfo) end
    end
end)

-- ========== SILENT AIM (MAGIC BULLET) ==========
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
                if type(args[1]) == "Vector3" then args[1] = targetPos
                elseif type(args[2]) == "Vector3" then args[2] = targetPos end
                if type(args[1]) == "CFrame" then args[1] = CFrame.new(args[1].Position, targetPos)
                elseif type(args[2]) == "CFrame" then args[2] = CFrame.new(args[2].Position, targetPos) end
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

-- ========== ESP (ПЕРЕИСПОЛЬЗОВАНИЕ ОБЪЕКТОВ) ==========
local function updateESP()
    if not drawingAvailable or not settings.esp then
        for _, d in pairs(espObjects) do
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.healthBar then d.healthBar.Visible = false end
            if d.healthBarBG then d.healthBarBG.Visible = false end
        end
        return
    end
    for plr, drawings in pairs(espObjects) do
        if not plr or not plr.Character then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            continue
        end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            continue
        end
        local distance = (camera.CFrame.Position - root.Position).Magnitude
        if distance > settings.espMaxDistance then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
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
                drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                drawings.box.Position = boxPos
                drawings.box.Visible = true
                drawings.box.Color = settings.espBoxColor
                drawings.box.Thickness = settings.espBoxThickness
                local text = ""
                if settings.espShowName then text = plr.Name end
                if settings.espShowDistance then text = text .. " [" .. math.floor(distance) .. "m]" end
                if settings.espShowHealth then text = text .. " ❤" .. math.floor(hum.Health) end
                drawings.name.Text = text
                drawings.name.Position = Vector2.new(screenPos.X, screenPos.Y - boxHeight/2 - 15)
                drawings.name.Visible = true
                drawings.name.Color = settings.espNameColor
                if settings.espHealthBarPosition == "Side" then
                    local barWidth = settings.espHealthBarWidth
                    local healthPercent = hum.Health / hum.MaxHealth
                    local barHeight = boxHeight * healthPercent
                    local barPos = Vector2.new(boxPos.X - barWidth - 2, boxPos.Y + (boxHeight - barHeight))
                    if not drawings.healthBar then
                        drawings.healthBar = Drawing.new("Line")
                        drawings.healthBar.Thickness = barWidth
                        drawings.healthBarBG = Drawing.new("Line")
                        drawings.healthBarBG.Thickness = barWidth
                        drawings.healthBarBG.Color = Color3.fromRGB(50,50,50)
                    end
                    drawings.healthBarBG.From = Vector2.new(barPos.X, boxPos.Y)
                    drawings.healthBarBG.To = Vector2.new(barPos.X, boxPos.Y + boxHeight)
                    drawings.healthBar.From = barPos
                    drawings.healthBar.To = Vector2.new(barPos.X, barPos.Y + barHeight)
                    drawings.healthBar.Color = settings.espHealthBarColor
                    drawings.healthBar.Visible = true
                    drawings.healthBarBG.Visible = true
                else
                    local barWidth = boxWidth
                    local barHeight = 4
                    local healthPercent = hum.Health / hum.MaxHealth
                    local barStart = Vector2.new(boxPos.X, boxPos.Y - 6)
                    local barEnd = Vector2.new(boxPos.X + barWidth * healthPercent, boxPos.Y - 6)
                    if not drawings.healthBar then
                        drawings.healthBar = Drawing.new("Line")
                        drawings.healthBar.Thickness = barHeight
                        drawings.healthBarBG = Drawing.new("Line")
                        drawings.healthBarBG.Thickness = barHeight
                        drawings.healthBarBG.Color = Color3.fromRGB(50,50,50)
                    end
                    drawings.healthBarBG.From = Vector2.new(boxPos.X, boxPos.Y - 6)
                    drawings.healthBarBG.To = Vector2.new(boxPos.X + barWidth, boxPos.Y - 6)
                    drawings.healthBar.From = barStart
                    drawings.healthBar.To = barEnd
                    drawings.healthBar.Color = settings.espHealthBarColor
                    drawings.healthBar.Visible = true
                    drawings.healthBarBG.Visible = true
                end
            else
                drawings.box.Visible = false
                drawings.name.Visible = false
                if drawings.healthBar then drawings.healthBar.Visible = false end
                if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            end
        else
            drawings.box.Visible = false
            drawings.name.Visible = false
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
        end
    end
end

local function createESP(plr)
    if plr == player or espObjects[plr] or not drawingAvailable then return end
    local box = Drawing.new("Square")
    box.Thickness = settings.espBoxThickness
    box.Color = settings.espBoxColor
    box.Filled = false
    local name = Drawing.new("Text")
    name.Size = 14
    name.Color = settings.espNameColor
    name.Outline = true
    name.Center = true
    espObjects[plr] = {box = box, name = name, healthBar = nil, healthBarBG = nil}
end

players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        if espObjects[plr].box then espObjects[plr].box:Remove() end
        if espObjects[plr].name then espObjects[plr].name:Remove() end
        if espObjects[plr].healthBar then espObjects[plr].healthBar:Remove() end
        if espObjects[plr].healthBarBG then espObjects[plr].healthBarBG:Remove() end
        espObjects[plr] = nil
    end
end)

for _, plr in ipairs(players:GetPlayers()) do createESP(plr) end
players.PlayerAdded:Connect(createESP)
runService.RenderStepped:Connect(updateESP)

-- ========== SPEED, FLY, NOCLIP ==========
local function resetWalkSpeed()
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = originalWalkSpeed end
end

local function disableFly()
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then
        hum.PlatformStand = false
        if originalGravity then workspace.Gravity = originalGravity end
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
            local cf = camera.CFrame
            if userInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cf.LookVector end
            if userInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cf.LookVector end
            if userInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cf.RightVector end
            if userInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cf.RightVector end
            if userInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
            if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
            bodyVelocity.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * settings.flySpeed or Vector3.new()
            bodyGyro.CFrame = cf
        end
    end
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then
        if settings.speedHack then
            hum.WalkSpeed = originalWalkSpeed * settings.speedMult
        elseif hum.WalkSpeed ~= originalWalkSpeed then
            hum.WalkSpeed = originalWalkSpeed
        end
    end
end)

runService.Stepped:Connect(function()
    if settings.noclip and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

player.CharacterAdded:Connect(function()
    resetWalkSpeed()
    if settings.fly then task.wait(0.5); enableFly() end
end)

-- ========== ШИРОКОЕ МЕНЮ (750x350) Right Shift ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchaMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 750, 0, 350)
mainFrame.Position = UDim2.new(0.5, -375, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 25)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 12)
pcall(function() mainFrame.BackgroundTransparency = 0.25 end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "✦  MATCHA CHEAT MENU  ✦"
title.TextColor3 = Color3.fromRGB(80, 200, 120)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 36)
tabBar.Position = UDim2.new(0, 0, 0, 40)
tabBar.BackgroundTransparency = 1
tabBar.Parent = mainFrame

local tabs = {"⚔️ Combat", "👁️ ESP", "🧬 Character", "⚙️ Misc"}
local activeTab = "⚔️ Combat"
local tabButtons = {}
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -86)
contentFrame.Position = UDim2.new(0, 10, 0, 76)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local leftCol = Instance.new("Frame")
leftCol.Size = UDim2.new(0.48, 0, 1, 0)
leftCol.Position = UDim2.new(0, 0, 0, 0)
leftCol.BackgroundTransparency = 1
leftCol.Parent = contentFrame

local rightCol = Instance.new("Frame")
rightCol.Size = UDim2.new(0.48, 0, 1, 0)
rightCol.Position = UDim2.new(0.52, 0, 0, 0)
rightCol.BackgroundTransparency = 1
rightCol.Parent = contentFrame

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 1, 0)
    btn.Position = UDim2.new(0, (i-1)*125, 0, 0)
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
        btn.TextColor3 = Color3.fromRGB(80, 200, 120)
        for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end
        leftCol.Parent = contentFrame
        rightCol.Parent = contentFrame
        populateTab(activeTab)
    end)
end
tabButtons["⚔️ Combat"].TextColor3 = Color3.fromRGB(80, 200, 120)

-- Хранилище для динамических элементов UI, чтобы обновлять их без пересоздания всей вкладки
local uiElements = {}

local function createToggle(parent, text, y, getter, setter, id)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 32)
    btn.Position = UDim2.new(0, 0, 0, y)
    btn.BackgroundColor3 = getter() and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 50, 55)
    btn.Text = text .. (getter() and " ✓" or "")
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        btn.BackgroundColor3 = getter() and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 50, 55)
        btn.Text = text .. (getter() and " ✓" or "")
        if text:find("Silent") then
            if settings.silentAim then enableSilentAim() else disableSilentAim() end
        end
        if text:find("Fly") then
            if getter() then enableFly() else disableFly() end
        end
        if text:find("Speed") and not getter() then resetWalkSpeed() end
    end)
    if id then uiElements[id] = btn end
    return btn
end

local function updateToggle(id, getter)
    local btn = uiElements[id]
    if btn then
        local text = btn.Text:gsub(" ✓", ""):gsub(" ON", ""):gsub(" OFF", "")
        local isOn = getter()
        btn.BackgroundColor3 = isOn and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 50, 55)
        btn.Text = text .. (isOn and " ✓" or "")
    end
end

local function createSlider(parent, name, y, minVal, maxVal, getter, setter, id)
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
    box.Size = UDim2.new(0.35, 0, 0, 28)
    box.Position = UDim2.new(0.6, 0, 0, 0)
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
            label.Text = name .. ": " .. tostring(num)
            setter(num)
            box.Text = tostring(getter())
        end
    end
    box.FocusLost:Connect(function() update(box.Text) end)
    update(getter())
    if id then uiElements[id] = {label = label, box = box, update = update} end
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
    btn.BackgroundColor3 = Color3.fromRGB(50,50,55)
    btn.Text = getter()
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        local dropdownFrame = Instance.new("Frame")
        dropdownFrame.Size = UDim2.new(0, 140, 0, #options * 32)
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
        createToggle(leftCol, "Aimlock (Hold F)", 10, function() return settings.aimlock end, function(v) settings.aimlock = v end, "aimlock")
        createToggle(leftCol, "Silent Aim", 55, function() return settings.silentAim end, function(v) settings.silentAim = v; if v then enableSilentAim() else disableSilentAim() end end, "silent")
        createToggle(leftCol, "Team Check", 100, function() return settings.teamCheck end, function(v) settings.teamCheck = v end, "team")
        createToggle(leftCol, "Wall Check", 145, function() return settings.wallCheck end, function(v) settings.wallCheck = v end, "wall")
        createDropdown(leftCol, "Aim Part", 200, {"Head", "Torso", "Random"}, function() return settings.aimPart end, function(v) settings.aimPart = v end)
        createSlider(rightCol, "FOV (pixels)", 10, 30, 400, function() return settings.fov end, function(v) settings.fov = v end)
        createSlider(rightCol, "Smoothness", 70, 0.1, 1, function() return settings.smoothness end, function(v) settings.smoothness = v end)
    elseif tab == "👁️ ESP" then
        createToggle(leftCol, "Enable ESP", 10, function() return settings.esp end, function(v) settings.esp = v end, "esp")
        createToggle(leftCol, "Show Name", 55, function() return settings.espShowName end, function(v) settings.espShowName = v end, "espname")
        createToggle(leftCol, "Show Health", 100, function() return settings.espShowHealth end, function(v) settings.espShowHealth = v end, "esphealth")
        createToggle(leftCol, "Show Distance", 145, function() return settings.espShowDistance end, function(v) settings.espShowDistance = v end, "espdist")
        createSlider(rightCol, "Max Distance", 10, 50, 800, function() return settings.espMaxDistance end, function(v) settings.espMaxDistance = v end)
        createSlider(rightCol, "Box Thickness", 70, 1, 5, function() return settings.espBoxThickness end, function(v) settings.espBoxThickness = v end)
        createColorPicker(rightCol, "Box Color", 130, function() return settings.espBoxColor end, function(v) settings.espBoxColor = v end)
        createColorPicker(rightCol, "Name Color", 180, function() return settings.espNameColor end, function(v) settings.espNameColor = v end)
        local boxTypeBtn = Instance.new("TextButton")
        boxTypeBtn.Size = UDim2.new(0.9, 0, 0, 32)
        boxTypeBtn.Position = UDim2.new(0, 0, 0, 230)
        boxTypeBtn.BackgroundColor3 = Color3.fromRGB(50,50,55)
        boxTypeBtn.Text = "Box Type: " .. settings.espBoxType
        boxTypeBtn.TextColor3 = Color3.new(1,1,1)
        boxTypeBtn.Font = Enum.Font.Gotham
        boxTypeBtn.Parent = rightCol
        boxTypeBtn.MouseButton1Click:Connect(function()
            local types = {"Square", "Corner", "Glow"}
            local idx = tableFind(types, settings.espBoxType) or 1
            idx = idx % 3 + 1
            settings.espBoxType = types[idx]
            boxTypeBtn.Text = "Box Type: " .. settings.espBoxType
        end)
    elseif tab == "🧬 Character" then
        createToggle(leftCol, "Speed Hack", 10, function() return settings.speedHack end, function(v) settings.speedHack = v end, "speed")
        createSlider(leftCol, "Speed Multiplier", 65, 1, 10, function() return settings.speedMult end, function(v) settings.speedMult = v end)
        createToggle(rightCol, "Fly Hack", 10, function() return settings.fly end, function(v) settings.fly = v; if v then enableFly() else disableFly() end end, "fly")
        createSlider(rightCol, "Fly Speed", 65, 10, 200, function() return settings.flySpeed end, function(v) settings.flySpeed = v end)
        createToggle(rightCol, "Noclip", 130, function() return settings.noclip end, function(v) settings.noclip = v end, "noclip")
    elseif tab == "⚙️ Misc" then
        local keyLabel = Instance.new("TextLabel")
        keyLabel.Size = UDim2.new(0.9, 0, 0, 180)
        keyLabel.Position = UDim2.new(0, 0, 0, 10)
        keyLabel.BackgroundTransparency = 1
        keyLabel.Text = "⌨️  KEYBINDS\n\nRight Shift → Show/Hide Menu\nF (Hold) → Aimlock\nV → Silent Aim toggle\nB → ESP toggle\nX → Speed Hack toggle\nC → Fly toggle\nN → Noclip toggle\n\nFOV circle follows your mouse."
        keyLabel.TextColor3 = Color3.new(200,200,220)
        keyLabel.TextScaled = true
        keyLabel.TextXAlignment = Enum.TextXAlignment.Left
        keyLabel.TextYAlignment = Enum.TextYAlignment.Top
        keyLabel.Font = Enum.Font.Gotham
        keyLabel.Parent = leftCol
    end
end

populateTab("⚔️ Combat")

-- ========== KEYBINDS ==========
userInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
    elseif k == Enum.KeyCode.V then
        settings.silentAim = not settings.silentAim
        if settings.silentAim then enableSilentAim() else disableSilentAim() end
        updateToggle("silent", function() return settings.silentAim end)
    elseif k == Enum.KeyCode.B then
        settings.esp = not settings.esp
        updateToggle("esp", function() return settings.esp end)
    elseif k == Enum.KeyCode.X then
        settings.speedHack = not settings.speedHack
        if not settings.speedHack then resetWalkSpeed() end
        updateToggle("speed", function() return settings.speedHack end)
    elseif k == Enum.KeyCode.C then
        settings.fly = not settings.fly
        if settings.fly then enableFly() else disableFly() end
        updateToggle("fly", function() return settings.fly end)
    elseif k == Enum.KeyCode.N then
        settings.noclip = not settings.noclip
        updateToggle("noclip", function() return settings.noclip end)
    end
end)

-- Очистка при выгрузке скрипта
game.Players.LocalPlayer.CharacterAdded:Connect(function()
    resetWalkSpeed()
end)

enableSilentAim()  -- silent aim по умолчанию выключен, но функция готова
print("✅ Matcha Cheat Menu v7 (Right Shift menu, all bugs fixed) loaded.")
