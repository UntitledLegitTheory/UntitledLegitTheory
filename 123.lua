-- // Matcha Cheat Menu v9 - Fixed aimlock (head), new ESP features (head dot, skeleton, 3D corners, fill), RGB picker, checkbox UI
if getgenv().MatchaMenuLoaded then return end
getgenv().MatchaMenuLoaded = true

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")

-- ========== SETTINGS ==========
local settings = {
    -- Combat
    aimlock = false,
    silentAim = false,
    teamCheck = true,
    wallCheck = true,
    aimPart = "Head",
    fov = 120,
    smoothness = 0.3,
    -- Speed/Fly/Noclip
    speedHack = false,
    speedMult = 2,
    fly = false,
    flySpeed = 50,
    noclip = false,
    -- ESP master
    esp = false,
    -- ESP components
    espBox = true,
    espBoxType = "Square",   -- Square, Corner3D, Filled
    espBoxColor = Color3.fromRGB(80, 200, 120),
    espBoxThickness = 2,
    espBoxFillTransparency = 0.5,
    espName = true,
    espNameColor = Color3.fromRGB(255, 255, 255),
    espHealth = true,
    espHealthBarPos = "Side",
    espHealthBarColor = Color3.fromRGB(80, 200, 120),
    espDistance = false,
    espHeadDot = true,
    espHeadDotColor = Color3.fromRGB(255, 80, 80),
    espHeadDotSize = 4,
    espSkeleton = true,
    espSkeletonColor = Color3.fromRGB(255, 255, 255),
    espMaxDistance = 400,
}

-- Internal vars
local silentActive = false
local bodyVelocity, bodyGyro = nil, nil
local originalWalkSpeed = 16
local originalGravity = nil
local flyActive = false
local espObjects = {}
local drawingAvailable = pcall(function() return Drawing.new("Square") end)

-- FOV circle (follows mouse exactly)
local fovCircle = drawingAvailable and Drawing.new("Circle") or nil
if fovCircle then
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(80, 200, 120)
    fovCircle.Transparency = 0.5
    fovCircle.Filled = false
    fovCircle.NumSides = 64
    fovCircle.Visible = false
end

-- Helper functions
local function tableFind(t, val)
    for i, v in ipairs(t) do if v == val then return i end end
    return nil
end

-- ========== AIM POSITION (FIXED) ==========
local function getAimPosition(character)
    if not character then return nil end
    if settings.aimPart == "Head" then
        local head = character:FindFirstChild("Head")
        if head then return head.Position + Vector3.new(0, 0.2, 0) end  -- slight offset for center
    elseif settings.aimPart == "Torso" then
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
        if torso then return torso.Position end
    elseif settings.aimPart == "Random" then
        local parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
        local valid = {}
        for _, p in ipairs(parts) do
            local found = character:FindFirstChild(p)
            if found then table.insert(valid, found) end
        end
        if #valid > 0 then
            local chosen = valid[math.random(#valid)]
            return chosen.Position + (chosen.Name == "Head" and Vector3.new(0, 0.2, 0) or Vector3.new(0,0,0))
        end
    end
    -- fallback
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    return root and root.Position
end

-- Visibility check
local function isVisible(part)
    if not part then return false end
    local origin = camera.CFrame.Position
    local direction = (part.Position - origin).Unit
    local ray = Ray.new(origin, direction * (part.Position - origin).Magnitude)
    local hit = workspace:FindPartOnRay(ray, player.Character)
    return hit and hit:IsDescendantOf(part.Parent)
end

-- Nearest target (based on FOV around cursor)
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

-- Aimlock (mouse movement)
local function moveMouseToTarget(targetInfo)
    if not targetInfo or not targetInfo.position then return end
    local screenPos, onScreen = camera:WorldToViewportPoint(targetInfo.position)
    if onScreen then
        local delta = Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mouse.X, mouse.Y)
        if delta.Magnitude > 1 then
            if mousemoverel then
                mousemoverel(delta.X, delta.Y)
            else
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
            fovCircle.Position = Vector2.new(mouse.X, mouse.Y)  -- exactly at cursor
        end
    end
    if settings.aimlock and userInputService:IsKeyDown(Enum.KeyCode.F) then
        local targetInfo = getNearestTargetFromCursor()
        if targetInfo then moveMouseToTarget(targetInfo) end
    end
end)

-- ========== SILENT AIM ==========
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

-- ========== ESP with HEAD DOT, SKELETON, 3D CORNERS, FILL ==========
local function getBonePosition(character, boneName)
    if not character then return nil end
    -- try direct part
    local part = character:FindFirstChild(boneName)
    if part then return part.Position end
    -- try via HumanoidRootPart for relative positioning? too complex, just skip
    return nil
end

local function drawSkeleton(plr, drawings)
    if not drawings.skeletonLines then
        drawings.skeletonLines = {}
    end
    local character = plr.Character
    if not character then return end
    local head = getBonePosition(character, "Head")
    local upperTorso = getBonePosition(character, "UpperTorso") or getBonePosition(character, "HumanoidRootPart")
    local leftArm = getBonePosition(character, "LeftUpperArm") or getBonePosition(character, "LeftArm")
    local rightArm = getBonePosition(character, "RightUpperArm") or getBonePosition(character, "RightArm")
    local leftLeg = getBonePosition(character, "LeftUpperLeg") or getBonePosition(character, "LeftLeg")
    local rightLeg = getBonePosition(character, "RightUpperLeg") or getBonePosition(character, "RightLeg")
    
    local connections = {
        {head, upperTorso},
        {upperTorso, leftArm}, {upperTorso, rightArm},
        {upperTorso, leftLeg}, {upperTorso, rightLeg},
        {leftArm, getBonePosition(character, "LeftLowerArm")}, {rightArm, getBonePosition(character, "RightLowerArm")},
        {leftLeg, getBonePosition(character, "LeftLowerLeg")}, {rightLeg, getBonePosition(character, "RightLowerLeg")}
    }
    for i, conn in ipairs(connections) do
        local a, b = conn[1], conn[2]
        if a and b then
            local screenA = camera:WorldToViewportPoint(a)
            local screenB = camera:WorldToViewportPoint(b)
            if screenA.Z > 0 and screenB.Z > 0 then
                if not drawings.skeletonLines[i] then
                    drawings.skeletonLines[i] = Drawing.new("Line")
                    drawings.skeletonLines[i].Thickness = 2
                    drawings.skeletonLines[i].Color = settings.espSkeletonColor
                end
                drawings.skeletonLines[i].From = Vector2.new(screenA.X, screenA.Y)
                drawings.skeletonLines[i].To = Vector2.new(screenB.X, screenB.Y)
                drawings.skeletonLines[i].Visible = true
            else
                if drawings.skeletonLines[i] then drawings.skeletonLines[i].Visible = false end
            end
        end
    end
end

local function updateESP()
    if not drawingAvailable or not settings.esp then
        for _, d in pairs(espObjects) do
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.healthBar then d.healthBar.Visible = false end
            if d.healthBarBG then d.healthBarBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
            if d.skeletonLines then
                for _, line in ipairs(d.skeletonLines) do line.Visible = false end
            end
        end
        return
    end
    
    for plr, drawings in pairs(espObjects) do
        if not plr or not plr.Character then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            if drawings.headDot then drawings.headDot.Visible = false end
            if drawings.skeletonLines then
                for _, line in ipairs(drawings.skeletonLines) do line.Visible = false end
            end
            continue
        end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            if drawings.headDot then drawings.headDot.Visible = false end
            if drawings.skeletonLines then
                for _, line in ipairs(drawings.skeletonLines) do line.Visible = false end
            end
            continue
        end
        
        local distance = (camera.CFrame.Position - root.Position).Magnitude
        if distance > settings.espMaxDistance then
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            if drawings.headDot then drawings.headDot.Visible = false end
            if drawings.skeletonLines then
                for _, line in ipairs(drawings.skeletonLines) do line.Visible = false end
            end
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
                
                -- BOX
                if settings.espBox then
                    if not drawings.box then
                        drawings.box = Drawing.new("Square")
                        drawings.box.Filled = false
                    end
                    drawings.box.Visible = true
                    if settings.espBoxType == "Square" then
                        drawings.box.Filled = false
                        drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                        drawings.box.Position = boxPos
                        drawings.box.Color = settings.espBoxColor
                        drawings.box.Thickness = settings.espBoxThickness
                    elseif settings.espBoxType == "Filled" then
                        drawings.box.Filled = true
                        drawings.box.Transparency = settings.espBoxFillTransparency
                        drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                        drawings.box.Position = boxPos
                        drawings.box.Color = settings.espBoxColor
                        drawings.box.Thickness = settings.espBoxThickness
                    elseif settings.espBoxType == "Corner3D" then
                        -- Draw 4 corner brackets (simulated by 2 lines per corner)
                        drawings.box.Visible = false  -- hide main box, we will draw lines manually
                        -- We'll implement using 8 line objects
                        if not drawings.cornerLines then
                            drawings.cornerLines = {}
                            for i = 1, 8 do drawings.cornerLines[i] = Drawing.new("Line") end
                        end
                        local cornerLen = math.min(15, boxWidth/4)
                        -- top-left
                        drawings.cornerLines[1].From = boxPos
                        drawings.cornerLines[1].To = Vector2.new(boxPos.X + cornerLen, boxPos.Y)
                        drawings.cornerLines[2].From = boxPos
                        drawings.cornerLines[2].To = Vector2.new(boxPos.X, boxPos.Y + cornerLen)
                        -- top-right
                        local tr = Vector2.new(boxPos.X + boxWidth, boxPos.Y)
                        drawings.cornerLines[3].From = tr
                        drawings.cornerLines[3].To = Vector2.new(tr.X - cornerLen, tr.Y)
                        drawings.cornerLines[4].From = tr
                        drawings.cornerLines[4].To = Vector2.new(tr.X, tr.Y + cornerLen)
                        -- bottom-left
                        local bl = Vector2.new(boxPos.X, boxPos.Y + boxHeight)
                        drawings.cornerLines[5].From = bl
                        drawings.cornerLines[5].To = Vector2.new(bl.X + cornerLen, bl.Y)
                        drawings.cornerLines[6].From = bl
                        drawings.cornerLines[6].To = Vector2.new(bl.X, bl.Y - cornerLen)
                        -- bottom-right
                        local br = Vector2.new(boxPos.X + boxWidth, boxPos.Y + boxHeight)
                        drawings.cornerLines[7].From = br
                        drawings.cornerLines[7].To = Vector2.new(br.X - cornerLen, br.Y)
                        drawings.cornerLines[8].From = br
                        drawings.cornerLines[8].To = Vector2.new(br.X, br.Y - cornerLen)
                        for _, line in ipairs(drawings.cornerLines) do
                            line.Color = settings.espBoxColor
                            line.Thickness = settings.espBoxThickness
                            line.Visible = true
                        end
                    end
                else
                    if drawings.box then drawings.box.Visible = false end
                    if drawings.cornerLines then
                        for _, line in ipairs(drawings.cornerLines) do line.Visible = false end
                    end
                end
                
                -- NAME
                if settings.espName then
                    if not drawings.name then
                        drawings.name = Drawing.new("Text")
                        drawings.name.Size = 14
                        drawings.name.Outline = true
                        drawings.name.Center = true
                    end
                    local text = plr.Name
                    if settings.espDistance then text = text .. " [" .. math.floor(distance) .. "m]" end
                    if settings.espHealth then text = text .. " [" .. math.floor(hum.Health) .. " HP]" end
                    drawings.name.Text = text
                    drawings.name.Position = Vector2.new(screenPos.X, screenPos.Y - boxHeight/2 - 15)
                    drawings.name.Visible = true
                    drawings.name.Color = settings.espNameColor
                elseif drawings.name then
                    drawings.name.Visible = false
                end
                
                -- HEALTH BAR (Side or Top)
                if settings.espHealth then
                    if settings.espHealthBarPos == "Side" then
                        if not drawings.healthBar then
                            drawings.healthBar = Drawing.new("Line")
                            drawings.healthBarBG = Drawing.new("Line")
                        end
                        local barWidth = 4
                        local healthPercent = hum.Health / hum.MaxHealth
                        local barHeight = boxHeight * healthPercent
                        local barPos = Vector2.new(boxPos.X - barWidth - 2, boxPos.Y + (boxHeight - barHeight))
                        drawings.healthBarBG.From = Vector2.new(barPos.X, boxPos.Y)
                        drawings.healthBarBG.To = Vector2.new(barPos.X, boxPos.Y + boxHeight)
                        drawings.healthBarBG.Thickness = barWidth
                        drawings.healthBarBG.Color = Color3.fromRGB(50,50,50)
                        drawings.healthBar.From = barPos
                        drawings.healthBar.To = Vector2.new(barPos.X, barPos.Y + barHeight)
                        drawings.healthBar.Thickness = barWidth
                        drawings.healthBar.Color = settings.espHealthBarColor
                        drawings.healthBar.Visible = true
                        drawings.healthBarBG.Visible = true
                    else -- Top
                        if not drawings.healthBar then
                            drawings.healthBar = Drawing.new("Line")
                            drawings.healthBarBG = Drawing.new("Line")
                        end
                        local barWidth = boxWidth
                        local barHeight = 4
                        local healthPercent = hum.Health / hum.MaxHealth
                        local barStart = Vector2.new(boxPos.X, boxPos.Y - 6)
                        local barEnd = Vector2.new(boxPos.X + barWidth * healthPercent, boxPos.Y - 6)
                        drawings.healthBarBG.From = Vector2.new(boxPos.X, boxPos.Y - 6)
                        drawings.healthBarBG.To = Vector2.new(boxPos.X + barWidth, boxPos.Y - 6)
                        drawings.healthBarBG.Thickness = barHeight
                        drawings.healthBarBG.Color = Color3.fromRGB(50,50,50)
                        drawings.healthBar.From = barStart
                        drawings.healthBar.To = barEnd
                        drawings.healthBar.Thickness = barHeight
                        drawings.healthBar.Color = settings.espHealthBarColor
                        drawings.healthBar.Visible = true
                        drawings.healthBarBG.Visible = true
                    end
                else
                    if drawings.healthBar then drawings.healthBar.Visible = false end
                    if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
                end
                
                -- HEAD DOT
                if settings.espHeadDot then
                    local head = plr.Character:FindFirstChild("Head")
                    if head then
                        local headPos, headOn = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.2, 0))
                        if headOn then
                            if not drawings.headDot then
                                drawings.headDot = Drawing.new("Circle")
                                drawings.headDot.NumSides = 16
                                drawings.headDot.Filled = true
                            end
                            drawings.headDot.Radius = settings.espHeadDotSize
                            drawings.headDot.Position = Vector2.new(headPos.X, headPos.Y)
                            drawings.headDot.Color = settings.espHeadDotColor
                            drawings.headDot.Visible = true
                        else
                            if drawings.headDot then drawings.headDot.Visible = false end
                        end
                    end
                elseif drawings.headDot then
                    drawings.headDot.Visible = false
                end
                
                -- SKELETON
                if settings.espSkeleton then
                    drawSkeleton(plr, drawings)
                elseif drawings.skeletonLines then
                    for _, line in ipairs(drawings.skeletonLines) do line.Visible = false end
                end
                
            else
                if drawings.box then drawings.box.Visible = false end
                if drawings.name then drawings.name.Visible = false end
                if drawings.healthBar then drawings.healthBar.Visible = false end
                if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
                if drawings.headDot then drawings.headDot.Visible = false end
                if drawings.skeletonLines then
                    for _, line in ipairs(drawings.skeletonLines) do line.Visible = false end
                end
                if drawings.cornerLines then
                    for _, line in ipairs(drawings.cornerLines) do line.Visible = false end
                end
            end
        else
            if drawings.box then drawings.box.Visible = false end
            if drawings.name then drawings.name.Visible = false end
            if drawings.healthBar then drawings.healthBar.Visible = false end
            if drawings.healthBarBG then drawings.healthBarBG.Visible = false end
            if drawings.headDot then drawings.headDot.Visible = false end
            if drawings.skeletonLines then
                for _, line in ipairs(drawings.skeletonLines) do line.Visible = false end
            end
            if drawings.cornerLines then
                for _, line in ipairs(drawings.cornerLines) do line.Visible = false end
            end
        end
    end
end

local function createESP(plr)
    if plr == player or espObjects[plr] or not drawingAvailable then return end
    espObjects[plr] = {}  -- empty, will be filled on demand
end

players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        for k, v in pairs(espObjects[plr]) do
            if type(v) == "table" then
                for _, obj in pairs(v) do if obj and obj.Remove then obj:Remove() end end
            elseif v and v.Remove then v:Remove() end
        end
        espObjects[plr] = nil
    end
end)

for _, plr in ipairs(players:GetPlayers()) do createESP(plr) end
players.PlayerAdded:Connect(createESP)
runService.RenderStepped:Connect(updateESP)

-- ========== SPEED, FLY, NOCLIP ==========
-- (same as before, stable)
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

-- ========== NEW GUI WITH CHECKBOX SQUARES AND RGB PICKER ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchaMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 900, 0, 560)
mainFrame.Position = UDim2.new(0.5, -450, 0.5, -280)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 22)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = true
mainFrame.Parent = screenGui
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "MATCHA CHEAT MENU"
title.TextColor3 = Color3.fromRGB(80, 200, 120)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Sidebar (vertical tabs)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 160, 1, -40)
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.BackgroundColor3 = Color3.fromRGB(24, 26, 28)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
local sidebarCorner = Instance.new("UICorner", sidebar)
sidebarCorner.CornerRadius = UDim.new(0, 8)

-- Content area
local contentArea = Instance.new("ScrollingFrame")
contentArea.Size = UDim2.new(1, -170, 1, -50)
contentArea.Position = UDim2.new(0, 170, 0, 45)
contentArea.BackgroundTransparency = 1
contentArea.BorderSizePixel = 0
contentArea.ScrollBarThickness = 6
contentArea.CanvasSize = UDim2.new(0, 0, 0, 0)
contentArea.Parent = mainFrame

local tabNames = {"Combat", "ESP", "Character", "Misc"}
local activeTab = "Combat"
local tabButtons = {}
local contentPanels = {}

-- Helper: create checkbox with square indicator
local function createCheckbox(parent, text, y, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 34)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local square = Instance.new("Frame")
    square.Size = UDim2.new(0, 22, 0, 22)
    square.Position = UDim2.new(0, 5, 0.5, -11)
    square.BackgroundColor3 = getter() and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 52, 55)
    square.BorderSizePixel = 1
    square.BorderColor3 = Color3.fromRGB(100,100,100)
    square.Parent = frame
    local sqCorner = Instance.new("UICorner", square)
    sqCorner.CornerRadius = UDim.new(0, 4)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -35, 1, 0)
    label.Position = UDim2.new(0, 35, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.Parent = frame
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        square.BackgroundColor3 = getter() and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(50, 52, 55)
        if text:find("Silent") then
            if settings.silentAim then enableSilentAim() else disableSilentAim() end
        end
        if text:find("Fly") then
            if getter() then enableFly() else disableFly() end
        end
        if text:find("Speed") and not getter() then resetWalkSpeed() end
    end)
    return frame
end

local function createSlider(parent, name, y, minVal, maxVal, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 52)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 0, 20)
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
            num = math.clamp(num, minVal, maxVal)
            label.Text = name .. ": " .. tostring(num)
            setter(num)
            box.Text = tostring(getter())
        end
    end
    box.FocusLost:Connect(function() update(box.Text) end)
    update(getter())
end

-- RGB Color Picker (3 sliders)
local function createRGBPicker(parent, name, y, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 100)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.new(1,1,1)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame
    
    local r, g, b = getter().R, getter().G, getter().B
    local rSlider, gSlider, bSlider
    
    local function updateColor()
        setter(Color3.new(rSlider.Value, gSlider.Value, bSlider.Value))
        preview.BackgroundColor3 = getter()
    end
    
    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 40, 0, 40)
    preview.Position = UDim2.new(0.8, 0, 0.2, 0)
    preview.BackgroundColor3 = getter()
    preview.BorderSizePixel = 1
    preview.BorderColor3 = Color3.fromRGB(80,80,80)
    preview.Parent = frame
    Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 6)
    
    local function makeSlider(min, max, val, color)
        local s = Instance.new("TextBox")
        s.Size = UDim2.new(0.7, 0, 0, 24)
        s.Position = UDim2.new(0, 0, 0, 25)
        s.BackgroundColor3 = Color3.fromRGB(40,42,45)
        s.Text = tostring(val)
        s.TextColor3 = Color3.new(1,1,1)
        s.Font = Enum.Font.Gotham
        s.Parent = frame
        Instance.new("UICorner", s).CornerRadius = UDim.new(0, 6)
        local function update(val)
            local num = math.clamp(tonumber(val) or 0, min, max)
            s.Text = tostring(num)
            return num
        end
        s.FocusLost:Connect(function() 
            local num = update(s.Text)
            if color == "r" then rSlider = num
            elseif color == "g" then gSlider = num
            else bSlider = num end
            updateColor()
        end)
        return update(s.Text)
    end
    
    rSlider = makeSlider(0,1, r, "r")
    local rLabel = Instance.new("TextLabel")
    rLabel.Size = UDim2.new(0.1, 0, 0, 20)
    rLabel.Position = UDim2.new(0.72, 0, 0.25, 0)
    rLabel.BackgroundTransparency = 1
    rLabel.Text = "R"
    rLabel.TextColor3 = Color3.fromRGB(255,100,100)
    rLabel.TextScaled = true
    rLabel.Font = Enum.Font.GothamBold
    rLabel.Parent = frame
    
    gSlider = makeSlider(0,1, g, "g")
    local gLabel = Instance.new("TextLabel")
    gLabel.Size = UDim2.new(0.1, 0, 0, 20)
    gLabel.Position = UDim2.new(0.72, 0, 0.45, 0)
    gLabel.BackgroundTransparency = 1
    gLabel.Text = "G"
    gLabel.TextColor3 = Color3.fromRGB(100,255,100)
    gLabel.TextScaled = true
    gLabel.Font = Enum.Font.GothamBold
    gLabel.Parent = frame
    
    bSlider = makeSlider(0,1, b, "b")
    local bLabel = Instance.new("TextLabel")
    bLabel.Size = UDim2.new(0.1, 0, 0, 20)
    bLabel.Position = UDim2.new(0.72, 0, 0.65, 0)
    bLabel.BackgroundTransparency = 1
    bLabel.Text = "B"
    bLabel.TextColor3 = Color3.fromRGB(100,100,255)
    bLabel.TextScaled = true
    bLabel.Font = Enum.Font.GothamBold
    bLabel.Parent = frame
    
    updateColor()
    return frame
end

local function createDropdown(parent, name, y, options, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 52)
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
    btn.BackgroundColor3 = Color3.fromRGB(50,52,55)
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
        dropdownFrame.BackgroundColor3 = Color3.fromRGB(40,42,45)
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

-- Build panels (each panel is a frame inside contentArea)
local function buildCombat(container)
    local y = 10
    createCheckbox(container, "Aimlock (Hold F)", y, function() return settings.aimlock end, function(v) settings.aimlock = v end); y = y + 45
    createCheckbox(container, "Silent Aim", y, function() return settings.silentAim end, function(v) settings.silentAim = v; if v then enableSilentAim() else disableSilentAim() end end); y = y + 45
    createCheckbox(container, "Team Check", y, function() return settings.teamCheck end, function(v) settings.teamCheck = v end); y = y + 45
    createCheckbox(container, "Wall Check", y, function() return settings.wallCheck end, function(v) settings.wallCheck = v end); y = y + 45
    createDropdown(container, "Aim Part", y, {"Head", "Torso", "Random"}, function() return settings.aimPart end, function(v) settings.aimPart = v end); y = y + 65
    createSlider(container, "FOV (pixels)", y, 30, 400, function() return settings.fov end, function(v) settings.fov = v end); y = y + 65
    createSlider(container, "Smoothness", y, 0.1, 1, function() return settings.smoothness end, function(v) settings.smoothness = v end); y = y + 65
    container.CanvasSize = UDim2.new(0, 0, 0, y + 20)
end

local function buildESP(container)
    local y = 10
    createCheckbox(container, "Enable ESP", y, function() return settings.esp end, function(v) settings.esp = v end); y = y + 45
    createCheckbox(container, "Show Box", y, function() return settings.espBox end, function(v) settings.espBox = v end); y = y + 45
    createDropdown(container, "Box Type", y, {"Square", "Corner3D", "Filled"}, function() return settings.espBoxType end, function(v) settings.espBoxType = v end); y = y + 65
    if settings.espBoxType == "Filled" then
        createSlider(container, "Fill Transparency", y, 0.1, 0.9, function() return settings.espBoxFillTransparency end, function(v) settings.espBoxFillTransparency = v end); y = y + 65
    end
    createSlider(container, "Box Thickness", y, 1, 5, function() return settings.espBoxThickness end, function(v) settings.espBoxThickness = v end); y = y + 65
    createRGBPicker(container, "Box Color", y, function() return settings.espBoxColor end, function(v) settings.espBoxColor = v end); y = y + 110
    createCheckbox(container, "Show Name", y, function() return settings.espName end, function(v) settings.espName = v end); y = y + 45
    createRGBPicker(container, "Name Color", y, function() return settings.espNameColor end, function(v) settings.espNameColor = v end); y = y + 110
    createCheckbox(container, "Show Health", y, function() return settings.espHealth end, function(v) settings.espHealth = v end); y = y + 45
    createRGBPicker(container, "Health Bar Color", y, function() return settings.espHealthBarColor end, function(v) settings.espHealthBarColor = v end); y = y + 110
    createCheckbox(container, "Show Distance", y, function() return settings.espDistance end, function(v) settings.espDistance = v end); y = y + 45
    createCheckbox(container, "Head Dot", y, function() return settings.espHeadDot end, function(v) settings.espHeadDot = v end); y = y + 45
    createRGBPicker(container, "Head Dot Color", y, function() return settings.espHeadDotColor end, function(v) settings.espHeadDotColor = v end); y = y + 110
    createSlider(container, "Head Dot Size", y, 2, 10, function() return settings.espHeadDotSize end, function(v) settings.espHeadDotSize = v end); y = y + 65
    createCheckbox(container, "Skeleton", y, function() return settings.espSkeleton end, function(v) settings.espSkeleton = v end); y = y + 45
    createRGBPicker(container, "Skeleton Color", y, function() return settings.espSkeletonColor end, function(v) settings.espSkeletonColor = v end); y = y + 110
    createSlider(container, "Max Distance", y, 50, 800, function() return settings.espMaxDistance end, function(v) settings.espMaxDistance = v end); y = y + 65
    container.CanvasSize = UDim2.new(0, 0, 0, y + 20)
end

local function buildCharacter(container)
    local y = 10
    createCheckbox(container, "Speed Hack", y, function() return settings.speedHack end, function(v) settings.speedHack = v end); y = y + 45
    createSlider(container, "Speed Multiplier", y, 1, 10, function() return settings.speedMult end, function(v) settings.speedMult = v end); y = y + 65
    createCheckbox(container, "Fly Hack", y, function() return settings.fly end, function(v) settings.fly = v; if v then enableFly() else disableFly() end end); y = y + 45
    createSlider(container, "Fly Speed", y, 10, 200, function() return settings.flySpeed end, function(v) settings.flySpeed = v end); y = y + 65
    createCheckbox(container, "Noclip", y, function() return settings.noclip end, function(v) settings.noclip = v end); y = y + 45
    container.CanvasSize = UDim2.new(0, 0, 0, y + 20)
end

local function buildMisc(container)
    local y = 10
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.9, 0, 0, 200)
    label.Position = UDim2.new(0, 0, 0, y)
    label.BackgroundTransparency = 1
    label.Text = "KEYBINDS\n\nRight Shift  -  Show/Hide Menu\nF (Hold)     -  Aimlock\nV            -  Silent Aim toggle\nB            -  ESP toggle\nX            -  Speed Hack toggle\nC            -  Fly toggle\nN            -  Noclip toggle\n\nFOV circle follows your mouse cursor."
    label.TextColor3 = Color3.fromRGB(200,200,220)
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Font = Enum.Font.Gotham
    label.Parent = container
    container.CanvasSize = UDim2.new(0, 0, 0, 250)
end

-- Create panels
for _, name in ipairs(tabNames) do
    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ScrollBarThickness = 6
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.Visible = (name == activeTab)
    panel.Parent = contentArea
    contentPanels[name] = panel
    if name == "Combat" then buildCombat(panel)
    elseif name == "ESP" then buildESP(panel)
    elseif name == "Character" then buildCharacter(panel)
    elseif name == "Misc" then buildMisc(panel) end
end

-- Create tab buttons
for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 40)
    btn.Position = UDim2.new(0, 5, 0, 10 + (i-1)*48)
    btn.BackgroundColor3 = (name == activeTab) and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(30, 32, 35)
    btn.Text = name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.Gotham
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        activeTab = name
        for _, b in pairs(tabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(30, 32, 35)
        end
        btn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        for tab, panel in pairs(contentPanels) do
            panel.Visible = (tab == activeTab)
        end
    end)
    tabButtons[name] = btn
end

-- Keybinds
userInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
    elseif k == Enum.KeyCode.V then
        settings.silentAim = not settings.silentAim
        if settings.silentAim then enableSilentAim() else disableSilentAim() end
        -- refresh combat panel checkboxes? just simple rebuild of combat panel
        if activeTab == "Combat" then
            for _, child in ipairs(contentPanels["Combat"]:GetChildren()) do child:Destroy() end
            buildCombat(contentPanels["Combat"])
        end
    elseif k == Enum.KeyCode.B then
        settings.esp = not settings.esp
        if activeTab == "ESP" then
            for _, child in ipairs(contentPanels["ESP"]:GetChildren()) do child:Destroy() end
            buildESP(contentPanels["ESP"])
        end
    elseif k == Enum.KeyCode.X then
        settings.speedHack = not settings.speedHack
        if not settings.speedHack then resetWalkSpeed() end
        if activeTab == "Character" then
            for _, child in ipairs(contentPanels["Character"]:GetChildren()) do child:Destroy() end
            buildCharacter(contentPanels["Character"])
        end
    elseif k == Enum.KeyCode.C then
        settings.fly = not settings.fly
        if settings.fly then enableFly() else disableFly() end
        if activeTab == "Character" then
            for _, child in ipairs(contentPanels["Character"]:GetChildren()) do child:Destroy() end
            buildCharacter(contentPanels["Character"])
        end
    elseif k == Enum.KeyCode.N then
        settings.noclip = not settings.noclip
        if activeTab == "Character" then
            for _, child in ipairs(contentPanels["Character"]:GetChildren()) do child:Destroy() end
            buildCharacter(contentPanels["Character"])
        end
    end
end)

enableSilentAim()
print("Matcha Cheat Menu v9 loaded. Right Shift - menu. All features active.")
