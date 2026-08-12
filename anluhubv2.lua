--[[
    Anlu Hub v2 - RIVALS TRUE GHOST FINAL
    Bypass: Clean Super Anti-Kick
    Features: TRUE Desync (Soul-Out-of-Body), Extreme Void Spam, Silent Aim, Rapid Fire
    Made by Anlu-Dev & Manus
]]

-- [0. Core Bypass & Services]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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

-- [[ 1. 라이브러리 및 UI 로딩 ]]
local function SafeHttpGet(url)
    local success, res = pcall(function() return game:HttpGet(url, true) end)
    return success and res or nil
end

local libRaw = SafeHttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua') or SafeHttpGet('https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua')
local Library = loadstring(libRaw)()
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local Window = Library:CreateWindow({ Title = 'Eclipse | True Ghost Edition', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
local Tabs = { Main = Window:AddTab('Main'), Character = Window:AddTab('Character'), Misc = Window:AddTab('Misc'), Settings = Window:AddTab('Settings') }

local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
local TargetGroup = Tabs.Main:AddRightGroupbox('Rage Target Settings')

RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})
RageGroup:AddToggle('DesyncEnabled', {Text = 'Enable TRUE Desync (Soul Out)', Default = true})
RageGroup:AddToggle('Disable3rdPerson', {Text = '3인칭일 때 자동발사 끄기', Default = true})
RageGroup:AddToggle('DisableUnlockedCursor', {Text = '커서 풀렸을 때 자동발사 끄기', Default = true})

local TargetStatusLabel = TargetGroup:AddLabel('Target Status: None')
TargetGroup:AddToggle('TeamCheck', {Text = 'Team Check', Default = false})
TargetGroup:AddDropdown('TargetPart', { Values = {'Head', 'HumanoidRootPart', 'Torso'}, Default = 1, Multi = false, Text = 'Target Part' })
TargetGroup:AddSlider('TPHeight', {Text = 'TP Height Above Enemy', Default = 3, Min = 1, Max = 15, Rounding = 1})
TargetGroup:AddSlider('HideTime', {Text = 'Void Hide Time (Sec)', Default = 0.05, Min = 0.01, Max = 1, Rounding = 2})
TargetGroup:AddSlider('AttackTime', {Text = 'Attack Time (Sec)', Default = 0.1, Min = 0.01, Max = 1, Rounding = 2})

-- [[ 2. 무기 시스템 후킹 ]]
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

-- [[ 3. 진짜 유체이탈(Desync) 로직 ]]
local function GetValidTarget()
    if not Toggles.RageEnabled.Value then return nil, nil end
    local closestPart, closestPlayer = nil, nil
    local maxDist = math.huge
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
                    if dist <= maxDist then maxDist = dist; closestPart = part; closestPlayer = player end
                end
            end
        end
    end
    return closestPart, closestPlayer
end

local function BuffedAutoShoot()
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool then tool:Activate() end
    pcall(function() if mouse1press then mouse1press() mouse1release() end end)
    pcall(function() VirtualUser:CaptureController(); VirtualUser:Button1Down(Vector2.zero); VirtualUser:Button1Up(Vector2.zero) end)
end

local ghostPart = Instance.new("Part")
ghostPart.Transparency = 1; ghostPart.CanCollide = false; ghostPart.Anchored = true; ghostPart.Parent = workspace
local voidState = "Attack"
local lastStateChange = os.clock()

RunService.Heartbeat:Connect(function()
    _G.RageActive = Toggles.RageEnabled.Value
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChild("Humanoid")

    _G.CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()
    TargetStatusLabel:SetText(CurrentTargetPlayer and ('Target Status: ' .. CurrentTargetPlayer.Name) or 'Target Status: None')

    if _G.RageActive and _G.CurrentTargetPart then
        local targetPos = _G.CurrentTargetPart.Position
        local abovePos = targetPos + Vector3.new(0, Options.TPHeight.Value, 0)
        
        -- [[ TRUE DESYNC CORE ]]
        if Toggles.DesyncEnabled.Value then
            if not _G.GhostPos then _G.GhostPos = hrp.CFrame end
            
            -- 1. 시점(Camera)을 유체이탈 위치에 고정
            Camera.CameraSubject = ghostPart; ghostPart.CFrame = _G.GhostPos
            
            -- 2. 모든 신체 부위(HRP 제외)를 유체이탈 위치로 강제 이동
            for _, v in pairs(char:GetChildren()) do
                if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                    v.CanCollide = false
                    v.CFrame = _G.GhostPos * (hrp.CFrame:ToObjectSpace(v.CFrame))
                end
            end
            
            -- 3. WASD 조종
            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Camera.CFrame.RightVector end
            _G.GhostPos = _G.GhostPos + (moveDir * 0.5)
        else
            _G.GhostPos = nil; Camera.CameraSubject = hum
        end

        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)

        -- [[ EXTREME VOID SPAM ]]
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
    else
        Camera.CameraSubject = hum; _G.GhostPos = nil
    end
end)

-- [[ 4. 기타 이동 및 설정 ]]
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
CharGroup:AddToggle('Fly', {Text = 'Fly'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200})

local MiscGroup = Tabs.Misc:AddLeftGroupbox('Misc')
MiscGroup:AddButton('FPS Boost', function() for _, v in pairs(workspace:GetDescendants()) do if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic end end end)
MiscGroup:AddButton('Rejoin', function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)

Library.ToggleKeybind = Options.MenuKeybind
print("[Anlu Hub] True Ghost Edition Loaded! 👻🌌✨")
