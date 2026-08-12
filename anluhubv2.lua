-- [[ 0. Pure Bypass & Super Anti-Kick ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Super Anti-Kick
local oldKick
oldKick = hookfunction(LocalPlayer.Kick, function(self, ...)
    if not checkcaller() then 
        warn("[Anlu Bypass] 킥 시도를 감지하고 차단했어! 🛡️")
        return nil 
    end
    return oldKick(self, ...)
end)

-- Remote & Silent Aim Protection (Theory-Perfect)
local rawMetatable = getrawmetatable(game)
local oldNamecall = rawMetatable.__namecall
local oldIndex = rawMetatable.__index
setreadonly(rawMetatable, false)

_G.CurrentTargetPart = nil
_G.RageActive = false
_G.GhostPos = nil

rawMetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if not checkcaller() then
        if method == "Raycast" and self == workspace and _G.RageActive and _G.CurrentTargetPart then
            args[2] = (_G.CurrentTargetPart.Position - args[1]).Unit * 10000
            return oldNamecall(self, unpack(args))
        end
        local name = tostring(self)
        if name:find("AntiCheat") or name:find("Check") or name:find("Kick") or name:find("Ban") then return nil end
    end
    return oldNamecall(self, ...)
end)

rawMetatable.__index = newcclosure(function(self, index)
    if not checkcaller() and _G.RageActive and _G.CurrentTargetPart then
        if self == Mouse then
            if index == "Hit" then return _G.CurrentTargetPart.CFrame
            elseif index == "Target" then return _G.CurrentTargetPart end
        end
    end
    return oldIndex(self, index)
end)
setreadonly(rawMetatable, true)

-- [[ 1. 라이브러리 및 서비스 로딩 ]]
local function SafeHttpGet(url)
    local success, result = pcall(function() return game:HttpGet(url, true) end)
    return success and result or nil
end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local libRaw = SafeHttpGet(repo .. 'Library.lua') or SafeHttpGet('https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua')
if not libRaw then return warn("[Eclipse Core] 라이브러리 로드 실패.") end
local Library = loadstring(libRaw)()
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

-- [[ 2. UI 구성 (원래 코드 100% 복구) ]]
local Window = Library:CreateWindow({ Title = 'Anlu Hub | Masterpiece Edition', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
local Tabs = { Main = Window:AddTab('Main'), Visuals = Window:AddTab('Visuals'), ESP = Window:AddTab('ESP'), Character = Window:AddTab('Character'), Misc = Window:AddTab('Misc'), Settings = Window:AddTab('Settings') }

-- [Main 탭] Rage Bot & Target Settings
local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
local TargetGroup = Tabs.Main:AddRightGroupbox('Rage Target Settings')

RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})
RageGroup:AddToggle('DesyncEnabled', {Text = 'Enable TRUE Desync (Soul Out)', Default = true}) -- 신규 추가
RageGroup:AddToggle('Disable3rdPerson', {Text = '3인칭일 때 자동발사 끄기', Default = true})
RageGroup:AddToggle('DisableUnlockedCursor', {Text = '커서 풀렸을 때 자동발사 끄기', Default = true})

local TargetStatusLabel = TargetGroup:AddLabel('Target Status: None')
TargetGroup:AddToggle('TeamCheck', {Text = 'Team Check (팀전 게임에서만 ON)', Default = false})
TargetGroup:AddDropdown('TargetPart', { Values = {'Head', 'HumanoidRootPart', 'Torso'}, Default = 1, Multi = false, Text = 'Target Part' })
TargetGroup:AddSlider('TPHeight', {Text = 'TP Height Above Enemy', Default = 3, Min = 1, Max = 15, Rounding = 1})
TargetGroup:AddSlider('HideTime', {Text = 'Void Hide Time (Sec)', Default = 0.05, Min = 0.01, Max = 1, Rounding = 2})
TargetGroup:AddSlider('AttackTime', {Text = 'Attack Time (Sec)', Default = 0.1, Min = 0.01, Max = 1, Rounding = 2})

-- [Character 탭] Movement & Anti Aim (100% 복구)
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
local AAGroup = Tabs.Character:AddRightGroupbox('Anti Aim')

CharGroup:AddToggle('Fly', {Text = 'Fly (Space: 상승 / Shift: 하강)'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200, Rounding = 0})
CharGroup:AddToggle('SpeedEnabled', {Text = 'Speed Hack'})
CharGroup:AddSlider('WalkSpeed', {Text = 'Speed Multiplier', Default = 2, Min = 1, Max = 10, Rounding = 1})
CharGroup:AddToggle('JumpEnabled', {Text = 'Infinite Jump'})
CharGroup:AddToggle('SlideBoost', {Text = 'Slide Boost'})
CharGroup:AddSlider('BoostForce', {Text = 'Boost Power', Default = 3, Min = 1, Max = 10, Rounding = 1})

AAGroup:AddToggle('AAEnabled', {Text = 'Enable Anti Aim'})
AAGroup:AddDropdown('YawMode', { Values = {'Static', 'Jitter', 'Random', 'Spin'}, Default = 1, Multi = false, Text = 'Torso Yaw Mode' })
AAGroup:AddSlider('YawAngle', {Text = 'Torso Yaw Limit', Default = 90, Min = 0, Max = 180, Rounding = 0})
AAGroup:AddSlider('YawSpeed', {Text = 'Yaw Speed', Default = 15, Min = 1, Max = 50, Rounding = 0})
AAGroup:AddDropdown('PitchMode', { Values = {'Static', 'Up', 'Down', 'Random'}, Default = 1, Multi = false, Text = 'Pitch Mode' })
AAGroup:AddSlider('PitchAngle', {Text = 'Pitch Angle', Default = 0, Min = -180, Max = 180, Rounding = 0})

-- [[ 3. 핵심 로직 함수들 ]]
local function CanAutoShoot()
    if Library.Toggled or (Library.ScreenGui and Library.ScreenGui.Enabled) then return false end
    if UserInputService:GetFocusedTextBox() ~= nil then return false end
    if Toggles.DisableUnlockedCursor.Value and UserInputService.MouseBehavior == Enum.MouseBehavior.Default then return false end
    if Toggles.Disable3rdPerson.Value then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Head") then
            if (Camera.CFrame.Position - char.Head.Position).Magnitude > 2.2 then return false end
        end
        if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then return false end
    end
    return true
end

local Cache = { waist = nil, rootJoint = nil, neck = nil }
local function UpdateCache(character)
    if not character then Cache.waist = nil; Cache.rootJoint = nil; Cache.neck = nil; return end
    local upperTorso = character:WaitForChild("UpperTorso", 3) or character:FindFirstChild("UpperTorso")
    local hrp = character:WaitForChild("HumanoidRootPart", 3) or character:FindFirstChild("HumanoidRootPart")
    local torso = character:FindFirstChild("Torso")
    Cache.waist = upperTorso and upperTorso:FindFirstChild("Waist")
    Cache.rootJoint = hrp and hrp:FindFirstChild("RootJoint")
    Cache.neck = (torso and torso:FindFirstChild("Neck")) or (character:FindFirstChild("Head") and character.Head:FindFirstChild("Neck")) or (upperTorso and upperTorso:FindFirstChild("Neck"))
end
if LocalPlayer.Character then UpdateCache(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(UpdateCache)

local function GetValidTarget()
    if not Toggles.RageEnabled.Value then return nil, nil end
    local maxDistance = math.huge
    local closestPart, closestPlayer = nil, nil
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not (Toggles.TeamCheck.Value and player.Team == LocalPlayer.Team) then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not char:FindFirstChildOfClass("ForceField") then
                local part = char:FindFirstChild(Options.TargetPart.Value) or char:FindFirstChild("HumanoidRootPart")
                if part then
                    local dist = (part.Position - myHRP.Position).Magnitude
                    if dist <= maxDistance then maxDistance = dist; closestPart = part; closestPlayer = player end
                end
            end
        end
    end
    return closestPart, closestPlayer
end

local clientItemModule = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
local oldInput; oldInput = hookfunction(clientItemModule.Input, function(...)
    local args = {...}
    if Toggles.RageEnabled.Value and type(args[1]) == "table" and args[1].Info then
        local info = args[1].Info
        info.ShootRecoil = 0; info.ShootSpread = 0; info.ShootCooldown = 0; info.QuickShotCooldown = 0
        info.ProjectileSpeed = 999999; info.BulletVelocity = 999999; info.ReloadTime = 0.01
    end
    return oldInput(...)
end)

local function BuffedAutoShoot()
    if not CanAutoShoot() then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool and hum then
        local backpackTool = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
        if backpackTool then hum:EquipTool(backpackTool); tool = backpackTool end
    end
    if tool then tool:Activate() end
    pcall(function() if mouse1press then mouse1press() mouse1release() end end)
    pcall(function() VirtualUser:CaptureController(); VirtualUser:Button1Down(Vector2.zero); VirtualUser:Button1Up(Vector2.zero) end)
    pcall(function() local vp = Camera.ViewportSize; VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0); VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0) end)
end

-- [[ 4. 메인 루프 (Theory-Perfect + All Features Integrated) ]]
local ghostPart = Instance.new("Part")
ghostPart.Transparency = 1; ghostPart.CanCollide = false; ghostPart.Anchored = true; ghostPart.Parent = workspace
local voidState = "Attack"
local lastStateChange = os.clock()

RunService.Heartbeat:Connect(function()
    _G.RageActive = Toggles.RageEnabled.Value
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then TargetStatusLabel:SetText('Target Status: None') return end
    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChild("Humanoid")

    _G.CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()
    TargetStatusLabel:SetText(CurrentTargetPlayer and ('Target Status: ' .. CurrentTargetPlayer.Name) or 'Target Status: None')

    if _G.RageActive and _G.CurrentTargetPart then
        local targetPos = _G.CurrentTargetPart.Position
        local abovePos = targetPos + Vector3.new(0, Options.TPHeight.Value, 0)
        
        -- TRUE Desync (Theory Optimized)
        if Toggles.DesyncEnabled.Value then
            if not _G.GhostPos then _G.GhostPos = hrp.CFrame end
            Camera.CameraSubject = ghostPart; ghostPart.CFrame = _G.GhostPos
            hum.PlatformStand = true; hum.AutoRotate = false
            for _, v in pairs(char:GetDescendants()) do if v:IsA("Motor6D") and (v.Part0 == hrp or v.Part1 == hrp) then v.Enabled = false end end
            for _, v in pairs(char:GetChildren()) do
                if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                    v.CanCollide = false
                    v.CFrame = _G.GhostPos * (hrp.CFrame:ToObjectSpace(v.CFrame))
                end
            end
            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Camera.CFrame.RightVector end
            _G.GhostPos = _G.GhostPos + (moveDir * 0.5)
        else
            hum.PlatformStand = false; hum.AutoRotate = true; _G.GhostPos = nil; Camera.CameraSubject = hum
            for _, v in pairs(char:GetDescendants()) do if v:IsA("Motor6D") then v.Enabled = true end end
        end

        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)

        -- Extreme Void Spam
        if Toggles.VoidSpam.Value then
            local now = os.clock()
            if voidState == "Attack" then
                if (now - lastStateChange >= Options.AttackTime.Value) then 
                    voidState = "Hide"; lastStateChange = now
                    local randX = math.random(100000000, 1000000000) * (math.random(0,1) == 0 and 1 or -1)
                    local randY = math.random(100000000, 1000000000) * (math.random(0,1) == 0 and 1 or -1)
                    local randZ = math.random(100000000, 1000000000) * (math.random(0,1) == 0 and 1 or -1)
                    hrp.CFrame = CFrame.new(randX, randY, randZ)
                else
                    hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                    BuffedAutoShoot()
                end
            else
                if (now - lastStateChange >= Options.HideTime.Value) then voidState = "Attack"; lastStateChange = now
                else
                    local randX = math.random(100000000, 1000000000) * (math.random(0,1) == 0 and 1 or -1)
                    local randY = math.random(100000000, 1000000000) * (math.random(0,1) == 0 and 1 or -1)
                    local randZ = math.random(100000000, 1000000000) * (math.random(0,1) == 0 and 1 or -1)
                    hrp.CFrame = CFrame.new(randX, randY, randZ)
                end
            end
        else
            hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
            BuffedAutoShoot()
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    else
        hum.PlatformStand = false; hum.AutoRotate = true; Camera.CameraSubject = hum; _G.GhostPos = nil
        for _, v in pairs(char:GetDescendants()) do if v:IsA("Motor6D") then v.Enabled = true end end
    end

    -- 원래 이동 로직 (100% 복구)
    local isRageActive = Toggles.RageEnabled.Value and _G.CurrentTargetPart
    if Toggles.Fly.Value and not isRageActive then
        hrp.AssemblyLinearVelocity = Vector3.zero
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end
        if moveDir.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (moveDir.Unit * Options.FlySpeed.Value * 0.016) end
    end
    if Toggles.SpeedEnabled.Value and not Toggles.Fly.Value and hum.MoveDirection.Magnitude > 0 then
        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (Options.WalkSpeed.Value - 1) * 16 * 0.016)
    end
    if Toggles.JumpEnabled.Value and UserInputService:IsKeyDown(Enum.KeyCode.Space) then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    if Toggles.SlideBoost.Value and hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0 and UserInputService:IsKeyDown(Enum.KeyCode.C) then
        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + (hum.MoveDirection * Options.BoostForce.Value)
    end
    if Toggles.AAEnabled.Value and not isRageActive then
        local finalYaw = (Options.YawMode.Value == 'Spin' and math.rad((tick() * Options.YawSpeed.Value * 100) % 360)) or math.rad(Options.YawAngle.Value)
        local finalPitch = math.rad(Options.PitchAngle.Value)
        if Cache.waist then Cache.waist.C0 = CFrame.new(0, 0.85, 0) * CFrame.Angles(finalPitch, finalYaw, 0) end
        if Cache.rootJoint then Cache.rootJoint.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(-180) + finalYaw) end
    end
end)

-- [Misc & Settings 탭 100% 복구]
local MiscGroup = Tabs.Misc:AddLeftGroupbox('Misc')
MiscGroup:AddButton('FPS Boost', function() for _, v in pairs(workspace:GetDescendants()) do if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic end end end)
MiscGroup:AddButton('Rejoin', function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)

local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddLabel('Menu Keybind'):AddKeybind('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu Keybind' })
Library.ToggleKeybind = Options.MenuKeybind

print("[Anlu Hub] Masterpiece Edition Final Loaded! 🚀👻💎")
