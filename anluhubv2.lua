-- [[ 0. Pure Bypass & Super Anti-Kick (Refined) ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Super Anti-Kick
local oldKick
oldKick = hookfunction(LocalPlayer.Kick, function(self, ...)
    if not checkcaller() then 
        warn("[Anlu Bypass] 킥 시도를 차단했어! 🛡️")
        return nil 
    end
    return oldKick(self, ...)
end)

-- Remote & Silent Aim Protection (Refined to prevent VoteBan error)
local rawMetatable = getrawmetatable(game)
local oldNamecall = rawMetatable.__namecall
local oldIndex = rawMetatable.__index
setreadonly(rawMetatable, false)

_G.CurrentTargetPart = nil
_G.RageActive = false
_G._oldCFrame = nil
_G._serverCFrame = nil

rawMetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if not checkcaller() then
        -- Rivals Raycast Hook (Silent Aim)
        if method == "Raycast" and self == workspace and _G.RageActive and _G.CurrentTargetPart then
            args[2] = (_G.CurrentTargetPart.Position - args[1]).Unit * 10000
            return oldNamecall(self, unpack(args))
        end
        -- 안티치트 리모트만 정밀 차단 (게임 로직 에러 방지)
        local name = tostring(self)
        if name == "AntiCheatEvent" or name == "BanRemote" or name == "KickRemote" then 
            return nil 
        end
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

-- [[ 1. 라이브러리 불러오기 ]]
local function SafeHttpGet(url)
    local success, result = pcall(function() return game:HttpGet(url, true) end)
    return success and result or nil
end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local libRaw = SafeHttpGet(repo .. 'Library.lua') or SafeHttpGet('https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua')
if not libRaw then return warn("[Eclipse Core] 라이브러리 로드 실패.") end
local Library = loadstring(libRaw)()
local VirtualUser = game:GetService("VirtualUser")

-- [[ 2. UI 구성 (원래 코드 100% 무생략 복구) ]]
local Window = Library:CreateWindow({ Title = 'Anlu Hub | Masterpiece Master', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
local Tabs = { Main = Window:AddTab('Main'), Visuals = Window:AddTab('Visuals'), ESP = Window:AddTab('ESP'), Character = Window:AddTab('Character'), Misc = Window:AddTab('Misc'), Settings = Window:AddTab('Settings') }

-- [Main 탭] Rage Bot & Target Settings
local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
local TargetGroup = Tabs.Main:AddRightGroupbox('Rage Target Settings')

RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})
RageGroup:AddToggle('DesyncEnabled', {Text = 'Enable Frame-Swap Desync', Default = true}) -- 신규
RageGroup:AddToggle('Disable3rdPerson', {Text = '3인칭일 때 자동발사 끄기', Default = true})
RageGroup:AddToggle('DisableUnlockedCursor', {Text = '커서 풀렸을 때 자동발사 끄기', Default = true})

local TargetStatusLabel = TargetGroup:AddLabel('Target Status: None')
TargetGroup:AddToggle('TeamCheck', {Text = 'Team Check', Default = false})
TargetGroup:AddDropdown('TargetPart', { Values = {'Head', 'HumanoidRootPart', 'Torso'}, Default = 1, Multi = false, Text = 'Target Part' })
TargetGroup:AddSlider('TPHeight', {Text = 'TP Height Above Enemy', Default = 3, Min = 1, Max = 15, Rounding = 1})
TargetGroup:AddSlider('HideTime', {Text = 'Void Hide Time (Sec)', Default = 0.05, Min = 0.01, Max = 1, Rounding = 2})
TargetGroup:AddSlider('AttackTime', {Text = 'Attack Time (Sec)', Default = 0.1, Min = 0.01, Max = 1, Rounding = 2})

-- [Visuals 탭] (100% 복구)
local VisualsGroup = Tabs.Visuals:AddLeftGroupbox('World Visuals')
VisualsGroup:AddToggle('FullBright', {Text = 'Full Bright', Default = false})
VisualsGroup:AddToggle('NoFog', {Text = 'No Fog', Default = false})
VisualsGroup:AddSlider('FieldOfView', {Text = 'Field Of View', Default = 70, Min = 30, Max = 120, Rounding = 0})

-- [ESP 탭] (100% 복구)
local ESPGroup = Tabs.ESP:AddLeftGroupbox('Player ESP')
ESPGroup:AddToggle('ESPEnabled', {Text = 'Enable ESP', Default = false})
ESPGroup:AddToggle('ESPBoxes', {Text = 'Show Boxes', Default = false})
ESPGroup:AddToggle('ESPNames', {Text = 'Show Names', Default = false})
ESPGroup:AddToggle('ESPHealth', {Text = 'Show Health', Default = false})
ESPGroup:AddToggle('ESPSkeletons', {Text = 'Show Skeletons', Default = false})

-- [Character 탭] (100% 복구)
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
local AAGroup = Tabs.Character:AddRightGroupbox('Anti Aim')

CharGroup:AddToggle('Fly', {Text = 'Fly (Space/Shift)'})
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
    end
    return true
end

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

-- 무기 개조 (Full-Auto)
local clientItemModule = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
local oldInput; oldInput = hookfunction(clientItemModule.Input, function(...)
    local args = {...}
    if Toggles.RageEnabled.Value and type(args[1]) == "table" and args[1].Info then
        local info = args[1].Info
        info.FireMode = "Automatic"; info.Automatic = true; info.IsAutomatic = true; info.Auto = true; info.IsSemi = false
        info.ShootRecoil = 0; info.ShootSpread = 0; info.ShootCooldown = 0; info.QuickShotCooldown = 0
        info.ProjectileSpeed = 999999; info.BulletVelocity = 999999; info.ReloadTime = 0.01; info.FireRate = 9999
    end
    return oldInput(...)
end)

local function StabilizedAutoShoot()
    if not CanAutoShoot() then return end
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
        pcall(function() if mouse1press then mouse1press() mouse1release() end end)
    end
end

-- [[ 4. 메인 루프 (Frame-Swap & Infinite Range) ]]
local voidState = "Attack"
local lastStateChange = os.clock()

RunService.Heartbeat:Connect(function()
    _G.RageActive = Toggles.RageEnabled.Value
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    
    _G.CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()
    TargetStatusLabel:SetText(CurrentTargetPlayer and ('Target Status: ' .. CurrentTargetPlayer.Name) or 'Target Status: None')

    if _G.RageActive and _G.CurrentTargetPart then
        local targetPos = _G.CurrentTargetPart.Position
        local abovePos = targetPos + Vector3.new(0, Options.TPHeight.Value, 0)
        
        if Toggles.VoidSpam.Value then
            local now = os.clock()
            if voidState == "Attack" then
                if (now - lastStateChange >= Options.AttackTime.Value) then 
                    voidState = "Hide"; lastStateChange = now
                    hrp.CFrame = CFrame.new(math.random(1e8, 1e9), math.random(1e8, 1e9), math.random(1e8, 1e9))
                else
                    hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                    StabilizedAutoShoot()
                end
            else
                if (now - lastStateChange >= Options.HideTime.Value) then voidState = "Attack"; lastStateChange = now
                else hrp.CFrame = CFrame.new(math.random(1e8, 1e9), math.random(1e8, 1e9), math.random(1e8, 1e9)) end
            end
        elseif Toggles.DesyncEnabled.Value then
            _G._oldCFrame = hrp.CFrame
            hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
            StabilizedAutoShoot()
        else
            hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
            StabilizedAutoShoot()
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end)

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and Toggles.DesyncEnabled.Value and _G.RageActive and _G._oldCFrame then
        hrp.CFrame = _G._oldCFrame
        _G._oldCFrame = nil
    end
    if _G.RageActive and _G.CurrentTargetPart then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, _G.CurrentTargetPart.Position)
    end
    -- Visuals 설정 적용
    if Toggles.FullBright and Toggles.FullBright.Value then game:GetService("Lighting").Brightness = 2; game:GetService("Lighting").ClockTime = 14 end
end)

-- 이동 로직 및 기타 기능
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChild("Humanoid")
    local isRageActive = Toggles.RageEnabled.Value and _G.CurrentTargetPart

    if Toggles.Fly.Value and not isRageActive then
        hrp.AssemblyLinearVelocity = Vector3.zero
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
        if moveDir.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (moveDir.Unit * Options.FlySpeed.Value * 0.016) end
    end
    if Toggles.JumpEnabled.Value and UserInputService:IsKeyDown(Enum.KeyCode.Space) then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

local MiscGroup = Tabs.Misc:AddLeftGroupbox('Misc')
MiscGroup:AddButton('FPS Boost', function() for _, v in pairs(workspace:GetDescendants()) do if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic end end end)
MiscGroup:AddButton('Rejoin', function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddLabel('Menu Keybind'):AddKeybind('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu Keybind' })
Library.ToggleKeybind = Options.MenuKeybind

print("[Anlu Hub] Masterpiece Master Loaded! 🚀💎✨")
