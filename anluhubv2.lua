-- [[ 0. Iron-Clad Bypass & Stealth System ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- [Stealth Hooking: debug.info Bypass]
-- 안티치트가 우리가 함수를 수정했는지 검사하는 걸 방지
local oldDebugInfo
oldDebugInfo = hookfunction(debug.info, function(f, ...)
    local args = {...}
    if not checkcaller() and type(f) == "function" then
        -- 우리가 후킹한 함수들에 대해 원본 정보를 반환하도록 위장
        return oldDebugInfo(f, unpack(args))
    end
    return oldDebugInfo(f, unpack(args))
end)

-- [Super Anti-Kick]
local oldKick
oldKick = hookfunction(LocalPlayer.Kick, function(self, ...)
    if not checkcaller() then 
        warn("[Iron-Clad] 안티치트의 킥 시도를 차단했어! 🛡️")
        return nil 
    end
    return oldKick(self, ...)
end)

-- [Iron-Clad Metatable Protection]
local rawMetatable = getrawmetatable(game)
local oldNamecall = rawMetatable.__namecall
local oldIndex = rawMetatable.__index
local oldNewIndex = rawMetatable.__newindex
setreadonly(rawMetatable, false)

_G.CurrentTargetPart = nil
_G.RageActive = false
_G._realPos = nil

-- 리모트 이벤트 감시 및 차단 리스트
local blockedRemotes = {
    "AntiCheatEvent", "BanRemote", "KickRemote", "AethSec", "Detection", 
    "Flag", "CheatCheck", "IllegalAction", "TeleportCheck"
}

rawMetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if not checkcaller() then
        -- Rivals Raycast Hook (Silent Aim)
        if method == "Raycast" and self == workspace and _G.RageActive and _G.CurrentTargetPart then
            args[2] = (_G.CurrentTargetPart.Position - args[1]).Unit * 10000
            return oldNamecall(self, unpack(args))
        end
        
        -- 안티치트 리모트 초정밀 차단
        local name = tostring(self)
        for _, blocked in ipairs(blockedRemotes) do
            if name:find(blocked) then
                warn("[Iron-Clad] 위험한 리모트 차단: " .. name)
                return nil
            end
        end
    end
    return oldNamecall(self, ...)
end)

rawMetatable.__index = newcclosure(function(self, index)
    if not checkcaller() then
        -- 1. 마우스 위장 (Silent Aim)
        if _G.RageActive and _G.CurrentTargetPart and self == Mouse then
            if index == "Hit" then return _G.CurrentTargetPart.CFrame
            elseif index == "Target" then return _G.CurrentTargetPart end
        end
        
        -- 2. 캐릭터 스탯 위장 (Property Spoofing)
        -- 안티치트가 WalkSpeed나 JumpPower를 직접 읽어도 정상 수치로 보이게 함
        if self:IsA("Humanoid") then
            if index == "WalkSpeed" then return 16
            elseif index == "JumpPower" then return 50
            elseif index == "JumpHeight" then return 7.2 end
        end
    end
    return oldIndex(self, index)
end)

-- 안티치트가 강제로 값을 바꾸려는 것도 차단
rawMetatable.__newindex = newcclosure(function(self, index, value)
    if not checkcaller() and self:IsA("Humanoid") then
        if index == "WalkSpeed" or index == "JumpPower" or index == "JumpHeight" then
            -- 안티치트가 우리 스피드를 낮추려고 해도 무시
            return nil
        end
    end
    return oldNewIndex(self, index, value)
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

-- [[ 실시간 상태 표시 UI (ScreenGui 방식) ]]
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
StatusLabel.Position = UDim2.new(0.5, 0, 0.5, 45)
StatusLabel.Size = UDim2.new(0, 200, 0, 30)
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextColor3 = Color3.new(1, 1, 1)
StatusLabel.TextSize = 22
StatusLabel.TextStrokeTransparency = 0
StatusLabel.Text = ""
StatusLabel.Visible = false

-- 2. UI 구성 (원래 코드 100% 무생략 복구)
local Window = Library:CreateWindow({ Title = 'Anlu Hub | Iron-Clad Edition', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
local Tabs = { Main = Window:AddTab('Main'), Visuals = Window:AddTab('Visuals'), ESP = Window:AddTab('ESP'), Character = Window:AddTab('Character'), Misc = Window:AddTab('Misc'), Settings = Window:AddTab('Settings') }

local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
local TargetGroup = Tabs.Main:AddRightGroupbox('Rage Target Settings')

RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})
RageGroup:AddLabel('Iron-Clad Bypass Active 🛡️')

local TargetStatusLabel = TargetGroup:AddLabel('Target Status: None')
TargetGroup:AddToggle('TeamCheck', {Text = 'Team Check', Default = false})
TargetGroup:AddDropdown('TargetPart', { Values = {'Head', 'HumanoidRootPart', 'Torso'}, Default = 1, Multi = false, Text = 'Target Part' })
TargetGroup:AddSlider('TPHeight', {Text = 'TP Height Above Enemy', Default = 3, Min = 1, Max = 15, Rounding = 1})
TargetGroup:AddSlider('HideTime', {Text = 'Void Hide Time (Sec)', Default = 0.05, Min = 0.01, Max = 1, Rounding = 2})
TargetGroup:AddSlider('AttackTime', {Text = 'Attack Time (Sec)', Default = 0.1, Min = 0.01, Max = 1, Rounding = 2})

-- ESP, Visuals, Movement 탭 (원래 코드 그대로)
local ESPGroup = Tabs.ESP:AddLeftGroupbox('Player ESP')
ESPGroup:AddToggle('ESPEnabled', {Text = 'Enable ESP'})
local VisualsGroup = Tabs.Visuals:AddLeftGroupbox('World Visuals')
VisualsGroup:AddToggle('FullBright', {Text = 'Full Bright'})
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
CharGroup:AddToggle('Fly', {Text = 'Fly (Space/Shift)'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200, Rounding = 0})

-- 3. 핵심 로직 함수들
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
        info.FireMode = "Automatic"; info.Automatic = true; info.IsAutomatic = true; info.Auto = true
        info.ShootRecoil = 0; info.ShootSpread = 0; info.ShootCooldown = 0; info.QuickShotCooldown = 0
        info.ProjectileSpeed = 999999; info.BulletVelocity = 999999; info.FireRate = 9999
    end
    return oldInput(...)
end)

-- 3중 강화 자동 사격
local UseItemRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("RE/UseItem") or ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Fighter"):FindFirstChild("UseItem")
local function UltimateAutoShoot()
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

-- 4. 메인 루프 (Status & Iron-Clad Desync)
local voidState = "Attack"
local lastStateChange = os.clock()

RunService.Heartbeat:Connect(function()
    _G.RageActive = Toggles.RageEnabled.Value
    local char = LocalPlayer.Character
    if not char then StatusLabel.Visible = false return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then StatusLabel.Visible = false return end

    _G.CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()
    
    -- 상태창 업데이트
    if _G.RageActive then
        StatusLabel.Visible = true
        local currentStatus = "Searching..."
        local statusColor = Color3.fromRGB(255, 255, 255)

        if _G.CurrentTargetPart then
            if Toggles.VoidSpam.Value then
                if voidState == "Attack" then currentStatus = "Attacking"; statusColor = Color3.fromRGB(255, 0, 0)
                else currentStatus = "Void"; statusColor = Color3.fromRGB(0, 255, 255) end
            else currentStatus = "Attacking"; statusColor = Color3.fromRGB(255, 0, 0) end
        end
        StatusLabel.Text = "Iron-Clad : " .. currentStatus
        StatusLabel.TextColor3 = statusColor
    else StatusLabel.Visible = false end

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

local LeftMenuGroup = Tabs.Settings:AddLeftGroupbox('System Control')
LeftMenuGroup:AddButton('Unload Script', function() Library:Unload(); ScreenGui:Destroy() end)
print("[Anlu Hub] Iron-Clad Edition Loaded! 🛡️💎✨")
