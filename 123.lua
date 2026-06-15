-- // Matcha Cheat Menu v12 - Fixed: FOV circle follows cursor exactly, aimlock works
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
    aimlock = false,
    silentAim = false,
    teamCheck = true,
    wallCheck = true,
    aimPart = "Head",
    fov = 120,
    smoothness = 0.3,
    speedHack = false,
    speedMult = 2,
    fly = false,
    flySpeed = 50,
    noclip = false,
    esp = false,
    espBox = true,
    espBoxType = "Square",
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

-- FOV circle (follows mouse cursor exactly using GetMouseLocation)
local fovCircle = drawingAvailable and Drawing.new("Circle") or nil
if fovCircle then
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(80, 200, 120)
    fovCircle.Transparency = 0.5
    fovCircle.Filled = false
    fovCircle.NumSides = 64
    fovCircle.Visible = false
end

-- FIXED: get absolute mouse position
local function getMousePos()
    local pos = userInputService:GetMouseLocation()
    return Vector2.new(pos.X, pos.Y)
end

-- ========== AIM HELPERS ==========
local function getAimPosition(character)
    if not character then return nil end
    if settings.aimPart == "Head" then
        local head = character:FindFirstChild("Head")
        if head then return head.Position + Vector3.new(0, 0.2, 0) end
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
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    return root and root.Position
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
    local cursorPos = getMousePos()
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
                        nearest = {plr = plr, position = aimPos}
                    end
                end
            end
        end
    end
    return nearest
end

local function moveMouseToTarget(targetInfo)
    if not targetInfo or not targetInfo.position then return end
    local screenPos, onScreen = camera:WorldToViewportPoint(targetInfo.position)
    if onScreen then
        local delta = Vector2.new(screenPos.X, screenPos.Y) - getMousePos()
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
            fovCircle.Position = getMousePos()  -- теперь точно по курсору
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

-- ========== ESP (сокращённо, но полностью рабочая) ==========
-- (ESP код остаётся таким же, как в v11, без изменений)
local function getBonePosition(character, boneName)
    if not character then return nil end
    local part = character:FindFirstChild(boneName)
    return part and part.Position
end

local function drawSkeleton(plr, drawings)
    if not drawings.skeletonLines then drawings.skeletonLines = {} end
    local char = plr.Character
    if not char then return end
    local head = getBonePosition(char, "Head")
    local upperTorso = getBonePosition(char, "UpperTorso") or getBonePosition(char, "HumanoidRootPart")
    local leftArm = getBonePosition(char, "LeftUpperArm") or getBonePosition(char, "LeftArm")
    local rightArm = getBonePosition(char, "RightUpperArm") or getBonePosition(char, "RightArm")
    local leftLeg = getBonePosition(char, "LeftUpperLeg") or getBonePosition(char, "LeftLeg")
    local rightLeg = getBonePosition(char, "RightUpperLeg") or getBonePosition(char, "RightLeg")
    local leftFore = getBonePosition(char, "LeftLowerArm")
    local rightFore = getBonePosition(char, "RightLowerArm")
    local leftFoot = getBonePosition(char, "LeftLowerLeg")
    local rightFoot = getBonePosition(char, "RightLowerLeg")
    local connections = {
        {head, upperTorso},
        {upperTorso, leftArm}, {upperTorso, rightArm},
        {upperTorso, leftLeg}, {upperTorso, rightLeg},
        {leftArm, leftFore}, {rightArm, rightFore},
        {leftLeg, leftFoot}, {rightLeg, rightFoot}
    }
    for i, conn in ipairs(connections) do
        local a, b = conn[1], conn[2]
        if a and b then
            local sa = camera:WorldToViewportPoint(a)
            local sb = camera:WorldToViewportPoint(b)
            if sa.Z > 0 and sb.Z > 0 then
                if not drawings.skeletonLines[i] then
                    drawings.skeletonLines[i] = Drawing.new("Line")
                    drawings.skeletonLines[i].Thickness = 2
                end
                drawings.skeletonLines[i].From = Vector2.new(sa.X, sa.Y)
                drawings.skeletonLines[i].To = Vector2.new(sb.X, sb.Y)
                drawings.skeletonLines[i].Color = settings.espSkeletonColor
                drawings.skeletonLines[i].Visible = true
            elseif drawings.skeletonLines[i] then
                drawings.skeletonLines[i].Visible = false
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
            if d.skeletonLines then for _, l in pairs(d.skeletonLines) do if l then l.Visible = false end end end
            if d.cornerLines then for _, l in pairs(d.cornerLines) do if l then l.Visible = false end end end
        end
        return
    end
    for plr, d in pairs(espObjects) do
        if not plr or not plr.Character then
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.healthBar then d.healthBar.Visible = false end
            if d.healthBarBG then d.healthBarBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
            if d.skeletonLines then for _, l in pairs(d.skeletonLines) do if l then l.Visible = false end end end
            if d.cornerLines then for _, l in pairs(d.cornerLines) do if l then l.Visible = false end end end
            continue
        end
        local root = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChild("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.healthBar then d.healthBar.Visible = false end
            if d.healthBarBG then d.healthBarBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
            continue
        end
        local dist = (camera.CFrame.Position - root.Position).Magnitude
        if dist > settings.espMaxDistance then
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.healthBar then d.healthBar.Visible = false end
            if d.healthBarBG then d.healthBarBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
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
                -- Box
                if settings.espBox then
                    if not d.box then d.box = Drawing.new("Square") end
                    d.box.Visible = true
                    if settings.espBoxType == "Square" then
                        d.box.Filled = false
                        d.box.Size = Vector2.new(boxWidth, boxHeight)
                        d.box.Position = boxPos
                        d.box.Color = settings.espBoxColor
                        d.box.Thickness = settings.espBoxThickness
                        if d.cornerLines then for _, l in pairs(d.cornerLines) do if l then l.Visible = false end end end
                    elseif settings.espBoxType == "Filled" then
                        d.box.Filled = true
                        d.box.Transparency = settings.espBoxFillTransparency
                        d.box.Size = Vector2.new(boxWidth, boxHeight)
                        d.box.Position = boxPos
                        d.box.Color = settings.espBoxColor
                        d.box.Thickness = settings.espBoxThickness
                        if d.cornerLines then for _, l in pairs(d.cornerLines) do if l then l.Visible = false end end end
                    else -- Corner3D
                        d.box.Visible = false
                        if not d.cornerLines then d.cornerLines = {} end
                        local len = math.min(15, boxWidth/4)
                        local tl = boxPos
                        local tr = Vector2.new(boxPos.X + boxWidth, boxPos.Y)
                        local bl = Vector2.new(boxPos.X, boxPos.Y + boxHeight)
                        local br = Vector2.new(boxPos.X + boxWidth, boxPos.Y + boxHeight)
                        local lines = {
                            {tl, Vector2.new(tl.X + len, tl.Y)},
                            {tl, Vector2.new(tl.X, tl.Y + len)},
                            {tr, Vector2.new(tr.X - len, tr.Y)},
                            {tr, Vector2.new(tr.X, tr.Y + len)},
                            {bl, Vector2.new(bl.X + len, bl.Y)},
                            {bl, Vector2.new(bl.X, bl.Y - len)},
                            {br, Vector2.new(br.X - len, br.Y)},
                            {br, Vector2.new(br.X, br.Y - len)},
                        }
                        for i, seg in ipairs(lines) do
                            if not d.cornerLines[i] then d.cornerLines[i] = Drawing.new("Line") end
                            d.cornerLines[i].From = seg[1]
                            d.cornerLines[i].To = seg[2]
                            d.cornerLines[i].Color = settings.espBoxColor
                            d.cornerLines[i].Thickness = settings.espBoxThickness
                            d.cornerLines[i].Visible = true
                        end
                        for i = #lines+1, #d.cornerLines do if d.cornerLines[i] then d.cornerLines[i].Visible = false end end
                    end
                else
                    if d.box then d.box.Visible = false end
                    if d.cornerLines then for _, l in pairs(d.cornerLines) do if l then l.Visible = false end end end
                end
                -- Name
                if settings.espName then
                    if not d.name then d.name = Drawing.new("Text") end
                    d.name.Size = 14
                    d.name.Outline = true
                    d.name.Center = true
                    local text = plr.Name
                    if settings.espDistance then text = text .. " [" .. math.floor(dist) .. "m]" end
                    if settings.espHealth then text = text .. " [" .. math.floor(hum.Health) .. " HP]" end
                    d.name.Text = text
                    d.name.Position = Vector2.new(screenPos.X, screenPos.Y - boxHeight/2 - 15)
                    d.name.Color = settings.espNameColor
                    d.name.Visible = true
                elseif d.name then d.name.Visible = false end
                -- Health bar
                if settings.espHealth then
                    if not d.healthBar then d.healthBar = Drawing.new("Line"); d.healthBarBG = Drawing.new("Line") end
                    local healthPercent = hum.Health / hum.MaxHealth
                    if settings.espHealthBarPos == "Side" then
                        local barWidth = 4
                        local barHeight = boxHeight * healthPercent
                        local barPos = Vector2.new(boxPos.X - barWidth - 2, boxPos.Y + (boxHeight - barHeight))
                        d.healthBarBG.From = Vector2.new(barPos.X, boxPos.Y)
                        d.healthBarBG.To = Vector2.new(barPos.X, boxPos.Y + boxHeight)
                        d.healthBarBG.Thickness = barWidth
                        d.healthBarBG.Color = Color3.fromRGB(50,50,50)
                        d.healthBar.From = barPos
                        d.healthBar.To = Vector2.new(barPos.X, barPos.Y + barHeight)
                        d.healthBar.Thickness = barWidth
                        d.healthBar.Color = settings.espHealthBarColor
                        d.healthBar.Visible = true
                        d.healthBarBG.Visible = true
                    else
                        local barWidth = boxWidth
                        local barHeight = 4
                        local barStart = Vector2.new(boxPos.X, boxPos.Y - 6)
                        local barEnd = Vector2.new(boxPos.X + barWidth * healthPercent, boxPos.Y - 6)
                        d.healthBarBG.From = Vector2.new(boxPos.X, boxPos.Y - 6)
                        d.healthBarBG.To = Vector2.new(boxPos.X + barWidth, boxPos.Y - 6)
                        d.healthBarBG.Thickness = barHeight
                        d.healthBarBG.Color = Color3.fromRGB(50,50,50)
                        d.healthBar.From = barStart
                        d.healthBar.To = barEnd
                        d.healthBar.Thickness = barHeight
                        d.healthBar.Color = settings.espHealthBarColor
                        d.healthBar.Visible = true
                        d.healthBarBG.Visible = true
                    end
                else
                    if d.healthBar then d.healthBar.Visible = false; d.healthBarBG.Visible = false end
                end
                -- Head dot
                if settings.espHeadDot then
                    local head = plr.Character:FindFirstChild("Head")
                    if head then
                        local hpos, hon = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.2, 0))
                        if hon then
                            if not d.headDot then d.headDot = Drawing.new("Circle") end
                            d.headDot.Radius = settings.espHeadDotSize
                            d.headDot.Position = Vector2.new(hpos.X, hpos.Y)
                            d.headDot.Color = settings.espHeadDotColor
                            d.headDot.Filled = true
                            d.headDot.Visible = true
                        elseif d.headDot then d.headDot.Visible = false end
                    end
                elseif d.headDot then d.headDot.Visible = false end
                -- Skeleton
                if settings.espSkeleton then
                    drawSkeleton(plr, d)
                elseif d.skeletonLines then
                    for _, l in pairs(d.skeletonLines) do if l then l.Visible = false end end
                end
            else
                if d.box then d.box.Visible = false end
                if d.name then d.name.Visible = false end
                if d.healthBar then d.healthBar.Visible = false; d.healthBarBG.Visible = false end
                if d.headDot then d.headDot.Visible = false end
                if d.skeletonLines then for _, l in pairs(d.skeletonLines) do if l then l.Visible = false end end end
                if d.cornerLines then for _, l in pairs(d.cornerLines) do if l then l.Visible = false end end end
            end
        else
            if d.box then d.box.Visible = false end
            if d.name then d.name.Visible = false end
            if d.healthBar then d.healthBar.Visible = false; d.healthBarBG.Visible = false end
            if d.headDot then d.headDot.Visible = false end
            if d.skeletonLines then for _, l in pairs(d.skeletonLines) do if l then l.Visible = false end end end
            if d.cornerLines then for _, l in pairs(d.cornerLines) do if l then l.Visible = false end end end
        end
    end
end

local function createESP(plr)
    if plr == player or espObjects[plr] or not drawingAvailable then return end
    espObjects[plr] = {}
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
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end
end)

player.CharacterAdded:Connect(function()
    resetWalkSpeed()
    if settings.fly then task.wait(0.5); enableFly() end
end)

-- ========== GUI (полностью из v11, без изменений) ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchaMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 900, 0, 580)
mainFrame.Position = UDim2.new(0.5, -450, 0.5, -290)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 22)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = true
mainFrame.Parent = screenGui
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundTransparency = 1
titleBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "MATCHA CHEAT MENU"
title.TextColor3 = Color3.fromRGB(80, 200, 120)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar
local closeCorner = Instance.new("UICorner", closeBtn)
closeCorner.CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 160, 1, -40)
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.BackgroundColor3 = Color3.fromRGB(24, 26, 28)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
local sidebarCorner = Instance.new("UICorner", sidebar)
sidebarCorner.CornerRadius = UDim.new(0, 8)

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

local function createRGBPicker(parent, name, y, getter, setter)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 40)
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
    
    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 40, 0, 32)
    preview.Position = UDim2.new(0.5, 0, 0.5, -16)
    preview.BackgroundColor3 = getter()
    preview.BorderSizePixel = 1
    preview.BorderColor3 = Color3.fromRGB(80,80,80)
    preview.Parent = frame
    Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 6)
    
    local pickerBtn = Instance.new("TextButton")
    pickerBtn.Size = UDim2.new(0.2, 0, 0.8, 0)
    pickerBtn.Position = UDim2.new(0.7, 0, 0.1, 0)
    pickerBtn.BackgroundColor3 = Color3.fromRGB(50,52,55)
    pickerBtn.Text = "Pick"
    pickerBtn.TextColor3 = Color3.new(1,1,1)
    pickerBtn.TextScaled = true
    pickerBtn.Font = Enum.Font.Gotham
    pickerBtn.Parent = frame
    Instance.new("UICorner", pickerBtn).CornerRadius = UDim.new(0, 6)
    
    pickerBtn.MouseButton1Click:Connect(function()
        local palette = Instance.new("Frame")
        palette.Size = UDim2.new(0, 220, 0, 150)
        palette.Position = UDim2.new(0.5, -110, 0.5, -75)
        palette.BackgroundColor3 = Color3.fromRGB(30,32,35)
        palette.Parent = screenGui
        Instance.new("UICorner", palette).CornerRadius = UDim.new(0, 8)
        
        local colors = {
            Color3.new(1,0.2,0.2), Color3.new(0.2,1,0.2), Color3.new(0.2,0.5,1), 
            Color3.new(1,1,0.2), Color3.new(1,0.5,0), Color3.new(1,0,1), 
            Color3.new(0,1,1), Color3.new(1,1,1), Color3.new(0.5,0.5,0.5),
            Color3.new(0.8,0.4,0.2), Color3.new(0.2,0.8,0.6), Color3.new(0.6,0.2,0.8)
        }
        local size = 50
        for i, col in ipairs(colors) do
            local swatch = Instance.new("TextButton")
            swatch.Size = UDim2.new(0, size, 0, size)
            swatch.Position = UDim2.new(0, ((i-1)%4)*size, 0, math.floor((i-1)/4)*size)
            swatch.BackgroundColor3 = col
            swatch.Text = ""
            swatch.Parent = palette
            Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 4)
            swatch.MouseButton1Click:Connect(function()
                setter(col)
                preview.BackgroundColor3 = col
                palette:Destroy()
            end)
        end
        local function closePalette(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if not palette:IsAncestorOf(input.Origin) and palette.Parent then
                    palette:Destroy()
                    userInputService.InputBegan:Disconnect(closeConn)
                end
            end
        end
        local closeConn = userInputService.InputBegan:Connect(closePalette)
    end)
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

function buildCombat(container)
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

function buildESP(container)
    local y = 10
    createCheckbox(container, "Enable ESP", y, function() return settings.esp end, function(v) settings.esp = v end); y = y + 45
    createCheckbox(container, "Show Box", y, function() return settings.espBox end, function(v) settings.espBox = v end); y = y + 45
    createDropdown(container, "Box Type", y, {"Square", "Corner3D", "Filled"}, function() return settings.espBoxType end, function(v) settings.espBoxType = v end); y = y + 65
    createSlider(container, "Box Thickness", y, 1, 5, function() return settings.espBoxThickness end, function(v) settings.espBoxThickness = v end); y = y + 65
    createRGBPicker(container, "Box Color", y, function() return settings.espBoxColor end, function(v) settings.espBoxColor = v end); y = y + 50
    createCheckbox(container, "Show Name", y, function() return settings.espName end, function(v) settings.espName = v end); y = y + 45
    createRGBPicker(container, "Name Color", y, function() return settings.espNameColor end, function(v) settings.espNameColor = v end); y = y + 50
    createCheckbox(container, "Show Health", y, function() return settings.espHealth end, function(v) settings.espHealth = v end); y = y + 45
    createRGBPicker(container, "Health Bar Color", y, function() return settings.espHealthBarColor end, function(v) settings.espHealthBarColor = v end); y = y + 50
    createCheckbox(container, "Show Distance", y, function() return settings.espDistance end, function(v) settings.espDistance = v end); y = y + 45
    createCheckbox(container, "Head Dot", y, function() return settings.espHeadDot end, function(v) settings.espHeadDot = v end); y = y + 45
    createRGBPicker(container, "Head Dot Color", y, function() return settings.espHeadDotColor end, function(v) settings.espHeadDotColor = v end); y = y + 50
    createSlider(container, "Head Dot Size", y, 2, 10, function() return settings.espHeadDotSize end, function(v) settings.espHeadDotSize = v end); y = y + 65
    createCheckbox(container, "Skeleton", y, function() return settings.espSkeleton end, function(v) settings.espSkeleton = v end); y = y + 45
    createRGBPicker(container, "Skeleton Color", y, function() return settings.espSkeletonColor end, function(v) settings.espSkeletonColor = v end); y = y + 50
    createSlider(container, "Max Distance", y, 50, 800, function() return settings.espMaxDistance end, function(v) settings.espMaxDistance = v end); y = y + 65
    container.CanvasSize = UDim2.new(0, 0, 0, y + 20)
end

function buildCharacter(container)
    local y = 10
    createCheckbox(container, "Speed Hack", y, function() return settings.speedHack end, function(v) settings.speedHack = v end); y = y + 45
    createSlider(container, "Speed Multiplier", y, 1, 10, function() return settings.speedMult end, function(v) settings.speedMult = v end); y = y + 65
    createCheckbox(container, "Fly Hack", y, function() return settings.fly end, function(v) settings.fly = v; if v then enableFly() else disableFly() end end); y = y + 45
    createSlider(container, "Fly Speed", y, 10, 200, function() return settings.flySpeed end, function(v) settings.flySpeed = v end); y = y + 65
    createCheckbox(container, "Noclip", y, function() return settings.noclip end, function(v) settings.noclip = v end); y = y + 45
    container.CanvasSize = UDim2.new(0, 0, 0, y + 20)
end

function buildMisc(container)
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
        for _, b in pairs(tabButtons) do b.BackgroundColor3 = Color3.fromRGB(30, 32, 35) end
        btn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        for tab, panel in pairs(contentPanels) do panel.Visible = (tab == activeTab) end
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
print("Matcha Cheat Menu v12 loaded. Right Shift - menu. FOV circle and aimlock now follow mouse exactly.")
