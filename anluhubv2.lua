-- [[ 0. Iron-Clad Stealth Bypass System ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- [Stealth Hooking: debug.info Bypass]
local oldDebugInfo
oldDebugInfo = hookfunction(debug.info, function(f, ...)
    if not checkcaller() and type(f) == "function" then
        return oldDebugInfo(f, ...)
    end
    return oldDebugInfo(f, ...)
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
_G._realCFrame = nil -- 진짜 위치 저장용

local blockedRemotes = {"AntiCheatEvent", "BanRemote", "KickRemote", "AethSec", "Detection", "Flag", "CheatCheck", "IllegalAction", "TeleportCheck"}

rawMetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if not checkcaller() then
        if method == "Raycast" and self == workspace and _G.RageActive and _G.CurrentTargetPart then
            args[2] = (_G.CurrentTargetPart.Position - args[1]).Unit * 10000
            return oldNamecall(self, unpack(args))
        end
        local name = tostring(self)
        for _, blocked in ipairs(blockedRemotes) do
            if name:find(blocked) then return nil end
        end
    end
    return oldNamecall(self, ...)
end)

rawMetatable.__index = newcclosure(function(self, index)
    if not checkcaller() then
        if _G.RageActive and _G.CurrentTargetPart and self == Mouse then
            if index == "Hit" then return _G.CurrentTargetPart.CFrame
            elseif index == "Target" then return _G.CurrentTargetPart end
        end
        if self:IsA("Humanoid") then
            if index == "WalkSpeed" then return 16
            elseif index == "JumpPower" then return 50
            elseif index == "JumpHeight" then return 7.2 end
        end
    end
    return oldIndex(self, index)
end)

rawMetatable.__newindex = newcclosure(function(self, index, value)
    if not checkcaller() and self:IsA("Humanoid") then
        if index == "WalkSpeed" or index == "JumpPower" or index == "JumpHeight" then return nil end
    end
    return oldNewIndex(self, index, value)
end)
setreadonly(rawMetatable, true)

-- [[ 1. 라이브러리 및 UI 로드 (원래 코드 100% 무생략) ]]
local function SafeHttpGet(url)
    local success, result = pcall(function() return game:HttpGet(url, true) end)
    return success and result or nil
end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local libRaw = SafeHttpGet(repo .. 'Library.lua') or SafeHttpGet('https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua')
local Library = loadstring(libRaw)()

local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

-- [[ 실시간 상태 표시 UI ]]
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
StatusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
StatusLabel.Position = UDim2.new(0.5, 0, 0.5, 35)
StatusLabel.Size = UDim2.new(0, 300, 0, 20)
StatusLabel.Font = Enum.Font.RobotoMono
StatusLabel.TextColor3 = Color3.new(1, 1, 1)
StatusLabel.TextSize = 14
StatusLabel.TextStrokeTransparency = 0.5
StatusLabel.Text = ""
StatusLabel.Visible = false

-- UI 구성 (원래 코드 100% 무생략 복구)
local Window = Library:CreateWindow({ Title = 'Anlu Hub | Theory Master Edition', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
local Tabs = { Main = Window:AddTab('Main'), Visuals = Window:AddTab('Visuals'), ESP = Window:AddTab('ESP'), Character = Window:AddTab('Character'), Misc = Window:AddTab('Misc'), Settings = Window:AddTab('Settings') }

-- [Main 탭]
local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
local TargetGroup = Tabs.Main:AddRightGroupbox('Rage Target Settings')
RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})
RageGroup:AddLabel('Theory-Master Desync Active 🌌')

local TargetStatusLabel = TargetGroup:AddLabel('Target Status: None')
TargetGroup:AddToggle('TeamCheck', {Text = 'Team Check (팀전 게임에서만 ON)', Default = false})
TargetGroup:AddDropdown('TargetPart', { Values = {'Head', 'HumanoidRootPart', 'Torso'}, Default = 1, Multi = false, Text = 'Target Part' })
TargetGroup:AddSlider('TPHeight', {Text = 'TP Height Above Enemy', Default = 3, Min = 1, Max = 15, Rounding = 1})
TargetGroup:AddSlider('HideTime', {Text = 'Void Hide Time (Sec)', Default = 0.05, Min = 0.01, Max = 1, Rounding = 2})
TargetGroup:AddSlider('AttackTime', {Text = 'Attack Time (Sec)', Default = 0.1, Min = 0.01, Max = 1, Rounding = 2})

-- [Visuals, ESP, Character 탭] (원래 코드 100% 복구)
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

-- [[ 3. 핵심 로직 함수들 ]]
local function CanAutoShoot()
    if Library.Toggled then return false end
    if UserInputService:GetFocusedTextBox() ~= nil then return false end
    if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then return false end
    return true
end

-- 관절 캐싱 (원래 코드 그대로)
local Cache = { waist = nil, rootJoint = nil, neck = nil }
local function UpdateCache(character)
    if not character then Cache.waist = nil Cache.rootJoint = nil Cache.neck = nil return end
    local upperTorso = character:WaitForChild("UpperTorso", 3) or character:FindFirstChild("UpperTorso")
    local hrp = character:WaitForChild("HumanoidRootPart", 3) or character:FindFirstChild("HumanoidRootPart")
    local torso = character:FindFirstChild("Torso")
    Cache.waist = upperTorso and upperTorso:FindFirstChild("Waist")
    Cache.rootJoint = hrp and hrp:FindFirstChild("RootJoint")
    Cache.neck = (torso and torso:FindFirstChild("Neck")) or (character:FindFirstChild("Head") and character.Head:FindFirstChild("Neck")) or (upperTorso and upperTorso:FindFirstChild("Neck"))
end
if LocalPlayer.Character then UpdateCache(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(UpdateCache)

local function IsInvincibleOrImmune(character)
    if not character then return true end
    if character:FindFirstChildOfClass("ForceField") then return true end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return true end
    return false
end

local function IsTeammate(player)
    if player == LocalPlayer then return true end
    if Toggles.TeamCheck and Toggles.TeamCheck.Value then
        if LocalPlayer.Team ~= nil and player.Team ~= nil then return player.Team == LocalPlayer.Team end
    end
    return false
end

local function GetValidTarget()
    if not (Toggles.RageEnabled and Toggles.RageEnabled.Value) then return nil, nil end
    local maxDistance = math.huge
    local closestPart, closestPlayer = nil, nil
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if not IsTeammate(player) and player.Character then
            local char = player.Character
            if not IsInvincibleOrImmune(char) then
                local partName = Options.TargetPart and Options.TargetPart.Value or 'Head'
                local targetPart = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                if targetPart then
                    local dist = (targetPart.Position - myHRP.Position).Magnitude
                    if dist <= maxDistance then maxDistance = dist; closestPart = targetPart; closestPlayer = player end
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
        info.FireMode = "Automatic"; info.Automatic = true; info.IsAutomatic = true; info.Auto = true
        info.ShootRecoil = 0; info.ShootSpread = 0; info.ShootCooldown = 0; info.QuickShotCooldown = 0
        info.ProjectileSpeed = 999999; info.BulletVelocity = 999999; info.ReloadTime = 0.01; info.FireRate = 9999
    end
    return oldInput(...)
end)

-- [[ 4. 고도화된 사격 로직 (Theory Sync Shoot) ]]
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local fighter = remotes and remotes:FindFirstChild("Fighter")
local UseItemRemote = remotes and remotes:FindFirstChild("RE/UseItem") or (fighter and fighter:FindFirstChild("UseItem"))

local function TheorySyncShoot()
    if not CanAutoShoot() then return end
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        -- 리모트 사격 신호 (서버용 몸이 적 근처에 있는 순간 호출됨)
        if UseItemRemote then pcall(function() UseItemRemote:FireServer("StartShooting", tool.Name) end) end
        tool:Activate()
        pcall(function()
            local vp = Camera.ViewportSize
            VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
        end)
    end
end

-- [[ 5. 메인 루프 (Theory Master Desync) ]]
local voidState = "Attack"
local lastStateChange = os.clock()

-- [Heartbeat: 네트워크 전송용 조작]
RunService.Heartbeat:Connect(function()
    _G.RageActive = Toggles.RageEnabled.Value
    local char = LocalPlayer.Character
    if not char then StatusLabel.Visible = false return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then StatusLabel.Visible = false return end

    -- 1. 진짜 위치 저장
    _G._realCFrame = hrp.CFrame

    _G.CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()
    TargetStatusLabel:SetText(CurrentTargetPlayer and ('Target Status: ' .. CurrentTargetPlayer.Name) or 'Target Status: None')
    
    -- 상태창 업데이트
    if _G.RageActive then
        StatusLabel.Visible = true
        local currentStatus = "Searching..."
        local statusColor = Color3.fromRGB(255, 255, 255)
        if _G.CurrentTargetPart then
            if Toggles.VoidSpam.Value then
                if voidState == "Attack" then currentStatus = "Attacking"; statusColor = Color3.fromRGB(255, 100, 100)
                else currentStatus = "Voiding"; statusColor = Color3.fromRGB(100, 255, 255) end
            else currentStatus = "Attacking"; statusColor = Color3.fromRGB(255, 100, 100) end
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("Ammo") and tool.Ammo.Value == 0 then
                currentStatus = "Reloading"; statusColor = Color3.fromRGB(255, 255, 100)
            end
        end
        StatusLabel.Text = "Rage Bot : " .. currentStatus
        StatusLabel.TextColor3 = statusColor
    else StatusLabel.Visible = false end

    -- 2. 서버 전송용 위치 조작 (Desync)
    if _G.RageActive then
        if _G.CurrentTargetPart then
            local targetPos = _G.CurrentTargetPart.Position
            local height = Options.TPHeight.Value
            local abovePos = targetPos + Vector3.new(0, height, 0)

            if Toggles.VoidSpam.Value then
                local now = os.clock()
                if voidState == "Attack" then
                    if (now - lastStateChange >= Options.AttackTime.Value) then
                        voidState = "Hide"; lastStateChange = now
                        hrp.CFrame = CFrame.new(math.random(1e8, 1e9), math.random(1e8, 1e9), math.random(1e8, 1e9))
                    else
                        -- 공격 순간: 적 근처로 몸 이동 후 발사
                        hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                        TheorySyncShoot()
                    end
                else
                    if (now - lastStateChange >= Options.HideTime.Value) then voidState = "Attack"; lastStateChange = now
                    else hrp.CFrame = CFrame.new(math.random(1e8, 1e9), math.random(1e8, 1e9), math.random(1e8, 1e9)) end
                end
            else
                -- 일반 Desync 공격
                hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                TheorySyncShoot()
            end
        else
            -- 적이 없을 때도 Void에 위치시켜서 숨김
            hrp.CFrame = CFrame.new(math.random(1e8, 1e9), math.random(1e8, 1e9), math.random(1e8, 1e9))
        end
        -- 네트워크 전송 빈도 유도를 위해 물리 속도 조작
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
    end

    -- Movement (100% 복구)
    if not _G.RageActive then
        if Toggles.Fly.Value then
            hrp.AssemblyLinearVelocity = Vector3.zero
            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end
            if moveDir.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (moveDir.Unit * (Options.FlySpeed.Value * 0.016)) end
        end
        if Toggles.SpeedEnabled.Value and not Toggles.Fly.Value and hum and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * ((Options.WalkSpeed.Value - 1) * 16 * 0.016))
        end
        if Toggles.SlideBoost.Value and not Toggles.Fly.Value and hum and hum.MoveDirection.Magnitude > 0 and UserInputService:IsKeyDown(Enum.KeyCode.C) then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (Options.BoostForce.Value * 5 * 0.016))
        end
    end
end)

-- [RenderStepped: 화면 렌더링용 복구]
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and _G.RageActive and _G._realCFrame then
        -- 렌더링 직전 진짜 위치로 복구 (본인 화면 정상화)
        hrp.CFrame = _G._realCFrame
        _G._realCFrame = nil
    end
    if Toggles.FullBright and Toggles.FullBright.Value then game:GetService("Lighting").Brightness = 2; game:GetService("Lighting").ClockTime = 14 end
end)

-- 무한 점프 & 기타 (원래 코드 그대로)
UserInputService.JumpRequest:Connect(function()
    if Toggles.JumpEnabled.Value and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local LeftMenuGroup = Tabs.Settings:AddLeftGroupbox('System Control')
LeftMenuGroup:AddButton('Unload Script', function() Library:Unload(); ScreenGui:Destroy() end)
LeftMenuGroup:AddLabel('Menu Toggle'):AddKeyPicker('MenuKeybind', { Default = 'RightControl', Text = 'Menu keybind', NoUI = true })
Library.ToggleKeybind = Options.MenuKeybind

print("[Anlu Hub] Theory Master Loaded! 🌌💎✨")
