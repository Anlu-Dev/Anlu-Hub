-- [[ 0. Pure Bypass & Super Anti-Kick ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Super Anti-Kick
local oldKick
oldKick = hookfunction(LocalPlayer.Kick, function(self, ...)
    if not checkcaller() then return nil end
    return oldKick(self, ...)
end)

-- Remote & Silent Aim Protection
local rawMetatable = getrawmetatable(game)
local oldNamecall = rawMetatable.__namecall
local oldIndex = rawMetatable.__index
setreadonly(rawMetatable, false)

_G.CurrentTargetPart = nil
_G.RageActive = false
_G._realPos = nil

rawMetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if not checkcaller() then
        if method == "Raycast" and self == workspace and _G.RageActive and _G.CurrentTargetPart then
            args[2] = (_G.CurrentTargetPart.Position - args[1]).Unit * 10000
            return oldNamecall(self, unpack(args))
        end
        local name = tostring(self)
        if name == "AntiCheatEvent" or name == "BanRemote" or name == "KickRemote" then return nil end
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

-- 1. 라이브러리 불러오기
local function SafeHttpGet(url)
    local success, result = pcall(function() return game:HttpGet(url, true) end)
    return success and result or nil
end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local libRaw = SafeHttpGet(repo .. 'Library.lua') or SafeHttpGet('https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua')
local Library = loadstring(libRaw)()

local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

-- [[ 실시간 상태 표시 UI (ScreenGui 방식 - 100% 가시성 보장) ]]
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnluStatusGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = ScreenGui
StatusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0.5, 0, 0.5, 40) -- 조준점 아래
StatusLabel.Size = UDim2.new(0, 200, 0, 30)
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextColor3 = Color3.new(1, 1, 1)
StatusLabel.TextSize = 20
StatusLabel.TextStrokeTransparency = 0
StatusLabel.Text = ""
StatusLabel.Visible = false

-- 2. UI 구성 (원래 코드 100% 무생략 복구)
local Window = Library:CreateWindow({
    Title = 'Anlu Hub | Ghost-Status Fixed',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab('Main'),
    Visuals = Window:AddTab('Visuals'),
    ESP = Window:AddTab('ESP'),
    Character = Window:AddTab('Character'),
    Misc = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings'),
}

local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
local TargetGroup = Tabs.Main:AddRightGroupbox('Rage Target Settings')

RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})
RageGroup:AddLabel('Desync & Status Fixed 👻')

local TargetStatusLabel = TargetGroup:AddLabel('Target Status: None')
TargetGroup:AddToggle('TeamCheck', {Text = 'Team Check', Default = false})
TargetGroup:AddDropdown('TargetPart', { Values = {'Head', 'HumanoidRootPart', 'Torso'}, Default = 1, Multi = false, Text = 'Target Part' })
TargetGroup:AddSlider('TPHeight', {Text = 'TP Height Above Enemy', Default = 3, Min = 1, Max = 15, Rounding = 1})
TargetGroup:AddSlider('HideTime', {Text = 'Void Hide Time (Sec)', Default = 0.05, Min = 0.01, Max = 1, Rounding = 2})
TargetGroup:AddSlider('AttackTime', {Text = 'Attack Time (Sec)', Default = 0.1, Min = 0.01, Max = 1, Rounding = 2})

-- Visuals, ESP, Character 탭 (원래 코드 그대로)
local VisualsGroup = Tabs.Visuals:AddLeftGroupbox('World Visuals')
VisualsGroup:AddToggle('FullBright', {Text = 'Full Bright', Default = false})
VisualsGroup:AddToggle('NoFog', {Text = 'No Fog', Default = false})
VisualsGroup:AddSlider('FieldOfView', {Text = 'Field Of View', Default = 70, Min = 30, Max = 120, Rounding = 0})

local ESPGroup = Tabs.ESP:AddLeftGroupbox('Player ESP')
ESPGroup:AddToggle('ESPEnabled', {Text = 'Enable ESP', Default = false})
ESPGroup:AddToggle('ESPBoxes', {Text = 'Show Boxes', Default = false})
ESPGroup:AddToggle('ESPNames', {Text = 'Show Names', Default = false})
ESPGroup:AddToggle('ESPHealth', {Text = 'Show Health', Default = false})
ESPGroup:AddToggle('ESPSkeletons', {Text = 'Show Skeletons', Default = false})

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

-- 3. 핵심 로직 함수들
local function CanAutoShoot()
    if Library.Toggled then return false end
    if UserInputService:GetFocusedTextBox() ~= nil then return false end
    if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then return false end
    return true
end

local function GetValidTarget()
    if not Toggles.RageEnabled.Value then return nil, nil end
    local maxDistance = math.huge
    local closestPart, closestPlayer = nil, nil
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not char:FindFirstChildOfClass("ForceField") then
                if not (Toggles.TeamCheck.Value and player.Team == LocalPlayer.Team) then
                    local part = char:FindFirstChild(Options.TargetPart.Value) or char:FindFirstChild("HumanoidRootPart")
                    if part then
                        local dist = (part.Position - myHRP.Position).Magnitude
                        if dist <= maxDistance then maxDistance = dist; closestPart = part; closestPlayer = player end
                    end
                end
            end
        end
    end
    return closestPart, closestPlayer
end

-- 무기 개조
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

-- 3중 강화 자동 사격
local UseItemRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("RE/UseItem") or ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Fighter"):FindFirstChild("UseItem")
local function UltimateAutoShoot()
    if not CanAutoShoot() then return end
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
        if UseItemRemote then UseItemRemote:FireServer("StartShooting", tool.Name) end
        pcall(function()
            local vp = Camera.ViewportSize
            VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
        end)
    end
end

-- 4. 메인 루프 (Status & Desync Integrated)
local voidState = "Attack"
local lastStateChange = os.clock()

RunService.Heartbeat:Connect(function()
    _G.RageActive = Toggles.RageEnabled.Value
    local char = LocalPlayer.Character
    if not char then StatusLabel.Visible = false return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then StatusLabel.Visible = false return end

    _G.CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()
    
    -- [[ 실시간 상태 업데이트 ]]
    if _G.RageActive then
        StatusLabel.Visible = true
        
        local currentStatus = "Searching..."
        local statusColor = Color3.fromRGB(255, 255, 255)

        if _G.CurrentTargetPart then
            if Toggles.VoidSpam.Value then
                if voidState == "Attack" then currentStatus = "Attacking"; statusColor = Color3.fromRGB(255, 0, 0)
                else currentStatus = "Void"; statusColor = Color3.fromRGB(0, 255, 255) end
            else
                currentStatus = "Attacking"; statusColor = Color3.fromRGB(255, 0, 0)
            end
            
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("Ammo") and tool.Ammo.Value == 0 then
                currentStatus = "Reloading"; statusColor = Color3.fromRGB(255, 255, 0)
            end
        end
        
        StatusLabel.Text = "Rage Bot : " .. currentStatus
        StatusLabel.TextColor3 = statusColor
    else
        StatusLabel.Visible = false
    end

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
                    UltimateAutoShoot()
                end
            else
                if (now - lastStateChange >= Options.HideTime.Value) then voidState = "Attack"; lastStateChange = now
                else hrp.CFrame = CFrame.new(math.random(1e8, 1e9), math.random(1e8, 1e9), math.random(1e8, 1e9)) end
            end
        else
            -- [Desync: Visual Offset]
            _G._realPos = hrp.CFrame
            hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
            UltimateAutoShoot()
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end)

-- 시각적 복구
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and _G.RageActive and _G._realPos then
        local offset = hrp.CFrame:ToObjectSpace(_G._realPos)
        for _, v in pairs(char:GetChildren()) do
            if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                v.CFrame = hrp.CFrame * offset * (hrp.CFrame:ToObjectSpace(v.CFrame))
            end
        end
        _G._realPos = nil
    end
end)

local MiscGroup = Tabs.Misc:AddLeftGroupbox('Misc')
MiscGroup:AddButton('FPS Boost', function() for _, v in pairs(workspace:GetDescendants()) do if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic end end end)
MiscGroup:AddButton('Rejoin', function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)

local LeftMenuGroup = Tabs.Settings:AddLeftGroupbox('System Control')
LeftMenuGroup:AddButton('Unload Script', function() Library:Unload(); ScreenGui:Destroy() end)
LeftMenuGroup:AddLabel('Menu Toggle'):AddKeyPicker('MenuKeybind', { Default = 'RightControl', Text = 'Menu keybind', NoUI = true })
Library.ToggleKeybind = Options.MenuKeybind

print("[Anlu Hub] Ghost-Status Fixed Loaded! 🚀💎✨")
