-- // Matcha Cheat Menu v15 - Stable, No Crashes, All Features Fixed
if getgenv().MatchaMenuLoaded then return end
getgenv().MatchaMenuLoaded = true

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local players = game:GetService("Players")

-- ===== SETTINGS =====
local settings = {
    aimlock = false,
    silentAim = false,
    esp = false,
    speedHack = false,
    fly = false,
    noclip = false,
    fov = 120,
    smoothness = 0.3,
    aimPart = "Head",
    teamCheck = true,
    wallCheck = true,
    speedMult = 2,
    flySpeed = 50,
    espBoxColor = Color3.fromRGB(80,200,120),
    espNameColor = Color3.new(1,1,1),
    espHealthColor = Color3.fromRGB(80,200,120),
    espMaxDist = 400,
}

-- Internal
local silentActive = false
local bodyVel, bodyGyro = nil, nil
local originalSpeed = 16
local originalGravity = nil
local flyActive = false
local espObjects = {}
local drawing = pcall(function() return Drawing.new("Square") end)

-- FOV circle
local fovCircle = drawing and Drawing.new("Circle") or nil
if fovCircle then
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(80,200,120)
    fovCircle.Transparency = 0.5
    fovCircle.Filled = false
    fovCircle.NumSides = 64
end

local function getMousePos()
    local p = uis:GetMouseLocation()
    return Vector2.new(p.X, p.Y)
end

-- ===== AIM HELPERS =====
local function getAimPos(char)
    if not char then return end
    if settings.aimPart == "Head" then
        local h = char:FindFirstChild("Head")
        if h then return h.Position + Vector3.new(0,0.2,0) end
    elseif settings.aimPart == "Torso" then
        local t = char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
        if t then return t.Position end
    else -- Random
        local parts = {"Head","UpperTorso","LowerTorso","HumanoidRootPart"}
        local valid = {}
        for _,p in ipairs(parts) do
            local part = char:FindFirstChild(p)
            if part then table.insert(valid, part) end
        end
        if #valid > 0 then
            local chosen = valid[math.random(#valid)]
            return chosen.Position + (chosen.Name=="Head" and Vector3.new(0,0.2,0) or Vector3.new(0,0,0))
        end
    end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    return root and root.Position
end

local function isVisible(part)
    if not part then return false end
    local origin = camera.CFrame.Position
    local dir = (part.Position - origin).Unit
    local ray = Ray.new(origin, dir * (part.Position - origin).Magnitude)
    local hit = workspace:FindPartOnRay(ray, player.Character)
    return hit and hit:IsDescendantOf(part.Parent)
end

local function getNearest()
    local nearest, bestDist = nil, settings.fov
    local cursor = getMousePos()
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if settings.teamCheck and plr.Team == player.Team then continue end
                local aimPos = getAimPos(plr.Character)
                if not aimPos then continue end
                local screenPos, on = camera:WorldToViewportPoint(aimPos)
                if on then
                    local dist = (Vector2.new(screenPos.X,screenPos.Y) - cursor).Magnitude
                    if dist < bestDist then
                        if settings.wallCheck then
                            local checkPart = plr.Character:FindFirstChild(settings.aimPart=="Head" and "Head" or "HumanoidRootPart")
                            if not isVisible(checkPart) then continue end
                        end
                        bestDist = dist
                        nearest = {plr=plr, pos=aimPos}
                    end
                end
            end
        end
    end
    return nearest
end

local function moveToTarget(t)
    if not t or not t.pos then return end
    local sp, on = camera:WorldToViewportPoint(t.pos)
    if on then
        local delta = Vector2.new(sp.X,sp.Y) - getMousePos()
        if delta.Magnitude > 1 then
            if mousemoverel then mousemoverel(delta.X, delta.Y)
            else
                local dir = (t.pos - camera.CFrame.Position).Unit
                local targetCF = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + dir)
                camera.CFrame = camera.CFrame:Lerp(targetCF, settings.smoothness)
            end
        end
    end
end

runService.RenderStepped:Connect(function()
    if fovCircle then
        fovCircle.Visible = (settings.aimlock or settings.silentAim) and camera.ViewportSize.X > 0
        if fovCircle.Visible then
            fovCircle.Radius = settings.fov * 2.5
            fovCircle.Position = getMousePos()
        end
    end
    if settings.aimlock and uis:IsKeyDown(Enum.KeyCode.F) then
        local target = getNearest()
        if target then moveToTarget(target) end
    end
end)

-- ===== SILENT AIM =====
local oldNamecall, mt
local function enableSilent()
    if silentActive or not getrawmetatable then return end
    mt = getrawmetatable(game)
    if not mt then return end
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "FireServer" and settings.silentAim then
            local target = getNearest()
            if target and target.pos then
                if type(args[1]) == "Vector3" then args[1] = target.pos
                elseif type(args[2]) == "Vector3" then args[2] = target.pos end
                if type(args[1]) == "CFrame" then args[1] = CFrame.new(args[1].Position, target.pos)
                elseif type(args[2]) == "CFrame" then args[2] = CFrame.new(args[2].Position, target.pos) end
            end
        end
        return oldNamecall(self, unpack(args))
    end)
    setreadonly(mt, true)
    silentActive = true
end

local function disableSilent()
    if not silentActive or not mt then return end
    setreadonly(mt, false)
    mt.__namecall = oldNamecall
    setreadonly(mt, true)
    silentActive = false
end

-- ===== ESP (LIGHTWEIGHT, NO LINGERING) =====
players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        for _, obj in pairs(espObjects[plr]) do if obj and obj.Remove then obj:Remove() end end
        espObjects[plr] = nil
    end
end)

local function updateESP()
    if not drawing or not settings.esp then
        for _, d in pairs(espObjects) do
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.health then d.health.Visible = false end
            if d.healthBG then d.healthBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
        end
        return
    end
    
    for plr, d in pairs(espObjects) do
        if not plr or not plr.Character then
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.health then d.health.Visible = false end
            if d.healthBG then d.healthBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
            goto cont
        end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.health then d.health.Visible = false end
            if d.healthBG then d.healthBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
            goto cont
        end
        local dist = (camera.CFrame.Position - root.Position).Magnitude
        if dist > settings.espMaxDist then
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.health then d.health.Visible = false end
            if d.healthBG then d.healthBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
            goto cont
        end
        local head = plr.Character:FindFirstChild("Head")
        local ref = head or root
        local sp, on = camera:WorldToViewportPoint(ref.Position)
        if on then
            local top = camera:WorldToViewportPoint((head or root).Position + Vector3.new(0,1.5,0))
            local bottom = camera:WorldToViewportPoint(root.Position - Vector3.new(0,3,0))
            local height = (bottom.Y - top.Y)
            if height < 5 then height = 50 end
            local w = height / 1.8
            local h = height
            local pos = Vector2.new(sp.X - w/2, top.Y)
            
            -- Box
            if not d.box then d.box = Drawing.new("Square") end
            d.box.Visible = true
            d.box.Filled = false
            d.box.Size = Vector2.new(w, h)
            d.box.Position = pos
            d.box.Color = settings.espBoxColor
            d.box.Thickness = 2
            
            -- Name
            if not d.name then
                d.name = Drawing.new("Text")
                d.name.Size = 14
                d.name.Outline = true
                d.name.Center = true
            end
            local txt = plr.Name
            if settings.espHealth then txt = txt .. " [" .. math.floor(hum.Health) .. " HP]" end
            d.name.Text = txt
            d.name.Position = Vector2.new(sp.X, pos.Y - 15)
            d.name.Color = settings.espNameColor
            d.name.Visible = true
            
            -- Health bar (green, filled)
            local healthPercent = hum.Health / hum.MaxHealth
            if not d.health then
                d.health = Drawing.new("Line")
                d.healthBG = Drawing.new("Line")
            end
            local barWidth = w
            local barHeight = 4
            local barStart = Vector2.new(pos.X, pos.Y - 6)
            local barEnd = Vector2.new(pos.X + barWidth * healthPercent, pos.Y - 6)
            d.healthBG.From = barStart
            d.healthBG.To = Vector2.new(pos.X + barWidth, pos.Y - 6)
            d.healthBG.Thickness = barHeight
            d.healthBG.Color = Color3.fromRGB(50,50,50)
            d.health.From = barStart
            d.health.To = barEnd
            d.health.Thickness = barHeight
            d.health.Color = settings.espHealthColor
            d.health.Visible = true
            d.healthBG.Visible = true
            
            -- Head dot (hollow)
            if head then
                local hp, hon = camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.2,0))
                if hon then
                    if not d.headDot then
                        d.headDot = Drawing.new("Circle")
                        d.headDot.NumSides = 16
                        d.headDot.Filled = false
                        d.headDot.Thickness = 2
                    end
                    d.headDot.Radius = 5
                    d.headDot.Position = Vector2.new(hp.X, hp.Y)
                    d.headDot.Color = Color3.fromRGB(255,80,80)
                    d.headDot.Visible = true
                elseif d.headDot then d.headDot.Visible = false end
            elseif d.headDot then d.headDot.Visible = false end
        else
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.health then d.health.Visible = false end
            if d.healthBG then d.healthBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
        end
        ::cont::
    end
end

local function createESP(plr)
    if plr == player or espObjects[plr] or not drawing then return end
    espObjects[plr] = {}
end

for _, plr in ipairs(players:GetPlayers()) do createESP(plr) end
players.PlayerAdded:Connect(createESP)
runService.RenderStepped:Connect(updateESP)

-- ===== SPEED, FLY, NOCLIP =====
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
    bodyVel.MaxForce = Vector3.new(1e9,1e9,1e9)
    bodyVel.Parent = root
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e9,1e9,1e9)
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root
    flyActive = true
end

runService.Heartbeat:Connect(function()
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
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum then
        if settings.speedHack then hum.WalkSpeed = originalSpeed * settings.speedMult
        elseif hum.WalkSpeed ~= originalSpeed then hum.WalkSpeed = originalSpeed end
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
    resetSpeed()
    if settings.fly then task.wait(0.5); enableFly() end
end)

-- ===== DISABLE ALL CHEATS (for close button) =====
local function disableAll()
    settings.aimlock = false
    settings.silentAim = false
    settings.esp = false
    settings.speedHack = false
    settings.fly = false
    settings.noclip = false
    if silentActive then disableSilent() end
    if flyActive then disableFly() end
    resetSpeed()
    if fovCircle then fovCircle.Visible = false end
end

-- ===== SIMPLE GUI (No Scrolling, No Crashes) =====
local gui = Instance.new("ScreenGui")
gui.Name = "MatchaMenu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 350, 0, 520)
main.Position = UDim2.new(0.5, -175, 0.5, -260)
main.BackgroundColor3 = Color3.fromRGB(20,22,25)
main.BackgroundTransparency = 0.05
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
local mCorner = Instance.new("UICorner", main)
mCorner.CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundTransparency = 1
titleBar.Parent = main

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -35, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "MATCHA CHEAT"
titleLbl.TextColor3 = Color3.fromRGB(80,200,120)
titleLbl.TextScaled = true
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 25, 0, 25)
close.Position = UDim2.new(1, -30, 0, 5)
close.BackgroundColor3 = Color3.fromRGB(60,60,70)
close.Text = "X"
close.TextColor3 = Color3.new(1,1,1)
close.TextScaled = true
close.Font = Enum.Font.GothamBold
close.Parent = titleBar
close.MouseButton1Click:Connect(function()
    disableAll()
    main.Visible = false
end)

local function addToggle(text, y, getter, setter)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 32)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = getter() and Color3.fromRGB(80,200,120) or Color3.fromRGB(50,52,55)
    btn.Text = text .. (getter() and "  ON" or "  OFF")
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        btn.BackgroundColor3 = getter() and Color3.fromRGB(80,200,120) or Color3.fromRGB(50,52,55)
        btn.Text = text .. (getter() and "  ON" or "  OFF")
        if text == "Silent Aim" then
            if settings.silentAim then enableSilent() else disableSilent() end
        elseif text == "Fly" then
            if getter() then enableFly() else disableFly() end
        elseif text == "Speed" and not getter() then resetSpeed() end
    end)
    return btn
end

local function addSlider(name, y, minV, maxV, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 50)
    frame.Position = UDim2.new(0.05, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = main
    
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
    box.BackgroundColor3 = Color3.fromRGB(40,42,45)
    box.Text = tostring(getter())
    box.TextColor3 = Color3.new(1,1,1)
    box.Font = Enum.Font.Gotham
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    
    local function update(val)
        local num = tonumber(val)
        if num then
            num = math.clamp(num, minV, maxV)
            label.Text = name .. ": " .. tostring(num)
            setter(num)
            box.Text = tostring(getter())
        end
    end
    box.FocusLost:Connect(function() update(box.Text) end)
    update(getter())
end

local function addDropdown(name, y, options, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 50)
    frame.Position = UDim2.new(0.05, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = main
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.45, 0, 0, 30)
    btn.Position = UDim2.new(0.5, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(50,52,55)
    btn.Text = getter()
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    btn.MouseButton1Click:Connect(function()
        local drop = Instance.new("Frame")
        drop.Size = UDim2.new(0, 120, 0, #options*30)
        drop.BackgroundColor3 = Color3.fromRGB(40,42,45)
        drop.Parent = frame
        Instance.new("UICorner", drop).CornerRadius = UDim.new(0, 6)
        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 30)
            optBtn.Position = UDim2.new(0, 0, 0, (i-1)*30)
            optBtn.BackgroundTransparency = 1
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.new(1,1,1)
            optBtn.TextScaled = true
            optBtn.Font = Enum.Font.Gotham
            optBtn.Parent = drop
            optBtn.MouseButton1Click:Connect(function()
                setter(opt)
                btn.Text = opt
                drop:Destroy()
            end)
        end
        local function closeDrop(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if not drop:IsAncestorOf(input.Origin) then
                    drop:Destroy()
                    uis.InputBegan:Disconnect(conn)
                end
            end
        end
        local conn = uis.InputBegan:Connect(closeDrop)
    end)
end

-- Build UI
local y = 50
addToggle("Aimlock (Hold F)", y, function() return settings.aimlock end, function(v) settings.aimlock = v end); y = y + 42
addToggle("Silent Aim", y, function() return settings.silentAim end, function(v) settings.silentAim = v; if v then enableSilent() else disableSilent() end end); y = y + 42
addToggle("ESP", y, function() return settings.esp end, function(v) settings.esp = v end); y = y + 42
addToggle("Speed Hack", y, function() return settings.speedHack end, function(v) settings.speedHack = v end); y = y + 42
addToggle("Fly Hack", y, function() return settings.fly end, function(v) settings.fly = v; if v then enableFly() else disableFly() end end); y = y + 42
addToggle("Noclip", y, function() return settings.noclip end, function(v) settings.noclip = v end); y = y + 50
addDropdown("Aim Part", y, {"Head","Torso","Random"}, function() return settings.aimPart end, function(v) settings.aimPart = v end); y = y + 60
addSlider("FOV (pixels)", y, 30, 400, function() return settings.fov end, function(v) settings.fov = v end); y = y + 60
addSlider("Smoothness", y, 0.1, 1, function() return settings.smoothness end, function(v) settings.smoothness = v end); y = y + 60

local keyHint = Instance.new("TextLabel")
keyHint.Size = UDim2.new(0.9, 0, 0, 80)
keyHint.Position = UDim2.new(0.05, 0, 0, y+10)
keyHint.BackgroundTransparency = 1
keyHint.Text = "Right Shift  -  Show/Hide Menu\nF (Hold)     -  Aimlock\nV / B / X / C / N  -  Toggles"
keyHint.TextColor3 = Color3.fromRGB(180,180,200)
keyHint.TextScaled = true
keyHint.TextXAlignment = Enum.TextXAlignment.Left
keyHint.Font = Enum.Font.Gotham
keyHint.Parent = main

-- Keybinds
uis.InputBegan:Connect(function(inp, gp)
    if gp then return end
    local k = inp.KeyCode
    if k == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    elseif k == Enum.KeyCode.V then
        settings.silentAim = not settings.silentAim
        if settings.silentAim then enableSilent() else disableSilent() end
        for _, btn in ipairs(main:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Text:find("Silent") then
                btn.BackgroundColor3 = settings.silentAim and Color3.fromRGB(80,200,120) or Color3.fromRGB(50,52,55)
                btn.Text = "Silent Aim" .. (settings.silentAim and "  ON" or "  OFF")
            end
        end
    elseif k == Enum.KeyCode.B then
        settings.esp = not settings.esp
        for _, btn in ipairs(main:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Text:find("ESP") then
                btn.BackgroundColor3 = settings.esp and Color3.fromRGB(80,200,120) or Color3.fromRGB(50,52,55)
                btn.Text = "ESP" .. (settings.esp and "  ON" or "  OFF")
            end
        end
    elseif k == Enum.KeyCode.X then
        settings.speedHack = not settings.speedHack
        if not settings.speedHack then resetSpeed() end
        for _, btn in ipairs(main:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Text:find("Speed") then
                btn.BackgroundColor3 = settings.speedHack and Color3.fromRGB(80,200,120) or Color3.fromRGB(50,52,55)
                btn.Text = "Speed Hack" .. (settings.speedHack and "  ON" or "  OFF")
            end
        end
    elseif k == Enum.KeyCode.C then
        settings.fly = not settings.fly
        if settings.fly then enableFly() else disableFly() end
        for _, btn in ipairs(main:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Text:find("Fly") then
                btn.BackgroundColor3 = settings.fly and Color3.fromRGB(80,200,120) or Color3.fromRGB(50,52,55)
                btn.Text = "Fly Hack" .. (settings.fly and "  ON" or "  OFF")
            end
        end
    elseif k == Enum.KeyCode.N then
        settings.noclip = not settings.noclip
        for _, btn in ipairs(main:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Text:find("Noclip") then
                btn.BackgroundColor3 = settings.noclip and Color3.fromRGB(80,200,120) or Color3.fromRGB(50,52,55)
                btn.Text = "Noclip" .. (settings.noclip and "  ON" or "  OFF")
            end
        end
    end
end)

enableSilent()
print("Matcha Menu v15 loaded (stable). Right Shift toggles menu.")
