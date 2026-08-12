-- 1. 안전한 HttpGet
local function SafeHttpGet(url)
    local success, result = pcall(function()
        return game:HttpGet(url, true)
    end)
    if success and result then return result end
    return nil
end

local repo = 'https://raw.githubusercontent.com/Anlu-Dev/Library/refs/heads/main/'
local libRaw = SafeHttpGet(repo .. 'Library.lua')
local themeRaw = SafeHttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua')
local saveRaw = SafeHttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua')

if not libRaw or not themeRaw or not saveRaw then
    return warn("[Eclipse Core] 라이브러리 불러오기 실패.")
end

local Library = loadstring(libRaw)()
local ThemeManager = loadstring(themeRaw)()
local SaveManager = loadstring(saveRaw)()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- 2. UI 구성
local Window = Library:CreateWindow({
    Title = 'Eclipse | Core System',
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

-- [Main 탭] Rage Bot 구성
local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
local TargetGroup = Tabs.Main:AddRightGroupbox('Rage Target Settings')

RageGroup:AddToggle('RageEnabled', {
    Text = 'Enable Rage Bot',
    Default = false,
    Callback = function(Value)
        if Toggles.TargetTP then Toggles.TargetTP:SetValue(Value) end
        if Toggles.SilentAim then Toggles.SilentAim:SetValue(Value) end
        if Toggles.AutoShoot then Toggles.AutoShoot:SetValue(Value) end
    end
})

RageGroup:AddToggle('TargetTP', {Text = 'TP Above Target (조건 만족 시)', Default = true})
RageGroup:AddToggle('SilentAim', {Text = '360° Silent Aim', Default = true})
RageGroup:AddToggle('AutoShoot', {Text = 'Auto Fire', Default = true})

TargetGroup:AddDropdown('TargetPart', {
    Values = {'Head', 'HumanoidRootPart', 'Torso'},
    Default = 1,
    Multi = false,
    Text = 'Target Part'
})

TargetGroup:AddSlider('TPHeight', {Text = 'TP Height Above Enemy', Default = 3, Min = 1, Max = 15, Rounding = 1})
TargetGroup:AddSlider('RageRange', {Text = 'Max Detection Range', Default = 10000, Min = 100, Max = 99999, Rounding = 0})

-- [Character 탭]
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
local AAGroup = Tabs.Character:AddRightGroupbox('Anti Aim')

CharGroup:AddToggle('Fly', {Text = 'Fly (Space: 상승 / Shift: 하강)'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200, Rounding = 0})

CharGroup:AddToggle('SpeedEnabled', {Text = 'Speed Hack'})
CharGroup:AddSlider('WalkSpeed', {Text = 'Speed Multiplier', Default = 2, Min = 1, Max = 10, Rounding = 1})

CharGroup:AddToggle('JumpEnabled', {Text = 'Infinite Jump'})

CharGroup:AddToggle('SlideBoost', {Text = 'Slide Boost'})
CharGroup:AddSlider('BoostForce', {Text = 'Boost Power', Default = 3, Min = 1, Max = 10, Rounding = 1})

-- Anti Aim UI
AAGroup:AddToggle('AAEnabled', {Text = 'Enable Anti Aim'})

AAGroup:AddDropdown('YawMode', {
    Values = {'Static', 'Jitter', 'Random', 'Spin'},
    Default = 1,
    Multi = false,
    Text = 'Torso Yaw Mode'
})
AAGroup:AddSlider('YawAngle', {Text = 'Torso Yaw Limit', Default = 90, Min = 0, Max = 180, Rounding = 0})
AAGroup:AddSlider('YawSpeed', {Text = 'Yaw Speed', Default = 15, Min = 1, Max = 50, Rounding = 0})

AAGroup:AddDropdown('PitchMode', {
    Values = {'Static', 'Up', 'Down', 'Random'},
    Default = 1,
    Multi = false,
    Text = 'Pitch Mode'
})
AAGroup:AddSlider('PitchAngle', {Text = 'Pitch Angle', Default = 0, Min = -180, Max = 180, Rounding = 0})

-- 3. 관절 캐싱
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

-- 4. 필터링 유틸리티 함수들

local function IsSelfFirstPerson()
    local char = LocalPlayer.Character
    if not char then return false end
    local head = char:FindFirstChild("Head")
    if not head then return false end
    return (Camera.CFrame.Position - head.Position).Magnitude < 2.5
end

local function IsTargetFirstPerson(player)
    local char = player.Character
    if not char then return false end
    local head = char:FindFirstChild("Head")
    if not head then return false end
    return head.LocalTransparencyModifier >= 0.9 or head.Transparency >= 0.9
end

local function IsInvincibleOrImmune(character)
    if not character then return true end
    if character:FindFirstChildOfClass("ForceField") then return true end
    if character:FindFirstChild("SpawnProtection") or character:FindFirstChild("Shield") or character:FindFirstChild("Invincible") or character:FindFirstChild("GodMode") then return true end
    
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return true end
    
    return false
end

local function IsTeammate(player)
    if player == LocalPlayer then return true end
    if LocalPlayer.Team ~= nil and player.Team ~= nil then
        return player.Team == LocalPlayer.Team
    end
    if LocalPlayer.TeamColor == player.TeamColor then
        return true
    end
    return false
end

-- 5. 조건 만족 전용 타깃 탐색 함수
local CurrentTargetPart = nil
local CurrentTargetPlayer = nil

local function GetValidTarget()
    if not Toggles.RageEnabled.Value then return nil, nil end
    local maxDistance = Options.RageRange.Value
    local closestPart = nil
    local closestPlayer = nil
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if not IsTeammate(player) and player.Character then
            local char = player.Character
            if not IsInvincibleOrImmune(char) then
                local partName = Options.TargetPart.Value
                local targetPart = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
                
                if targetPart then
                    local dist = (targetPart.Position - myHRP.Position).Magnitude
                    if dist <= maxDistance then
                        maxDistance = dist
                        closestPart = targetPart
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPart, closestPlayer
end

-- 6. 하이엔드 360° Silent Aim
local rawMetatable = getrawmetatable(game)
local oldNamecall = rawMetatable.__namecall
local oldIndex = rawMetatable.__index
setreadonly(rawMetatable, false)

rawMetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if not checkcaller() and Toggles.RageEnabled and Toggles.RageEnabled.Value and Toggles.SilentAim and Toggles.SilentAim.Value and CurrentTargetPart then
        if method == "Raycast" and self == workspace then
            local origin = args[1]
            if origin then
                local targetPos = CurrentTargetPart.Position
                args[2] = (targetPos - origin).Unit * 10000
                return oldNamecall(self, unpack(args))
            end
        elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
            local ray = args[1]
            if ray then
                local origin = ray.Origin
                local targetPos = CurrentTargetPart.Position
                args[1] = Ray.new(origin, (targetPos - origin).Unit * 10000)
                return oldNamecall(self, unpack(args))
            end
        end
    end

    return oldNamecall(self, ...)
end)

rawMetatable.__index = newcclosure(function(self, index)
    if not checkcaller() and Toggles.RageEnabled and Toggles.RageEnabled.Value and Toggles.SilentAim and Toggles.SilentAim.Value and CurrentTargetPart then
        if self == Mouse then
            if index == "Hit" then
                return CurrentTargetPart.CFrame
            elseif index == "Target" then
                return CurrentTargetPart
            end
        end
    end
    return oldIndex(self, index)
end)

setreadonly(rawMetatable, true)

-- 7. 10스터드 이내 클릭 리모트(RemoteEvent) 직접 발동 사격 함수
local function TriggerAutoShoot(targetPart)
    local char = LocalPlayer.Character
    if not char or not targetPart then return end
    local tool = char:FindFirstChildOfClass("Tool")
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    if not tool or not myHRP then return end

    local distance = (myHRP.Position - targetPart.Position).Magnitude

    -- [핵심] 적과의 거리가 10스터드 이내일 때: Tool 내 리모트 이벤트 직접 실행
    if distance <= 10 then
        for _, v in ipairs(tool:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                pcall(function()
                    v:FireServer(targetPart.Position, targetPart)
                    v:FireServer(targetPart)
                    v:FireServer()
                end)
            elseif v:IsA("RemoteFunction") then
                pcall(function()
                    v:InvokeServer(targetPart.Position, targetPart)
                end)
            end
        end
    end

    -- 기본 도구 활성화 및 마우스 입력 주입 (2중 보장)
    tool:Activate()
    pcall(function()
        if mouse1press then
            mouse1press()
            task.delay(0.01, function() pcall(mouse1release) end)
        else
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.delay(0.01, function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
        end
    end)
end

-- 8. 메인 프레임 루프
RunService.Stepped:Connect(function(_, delta)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    -- 유효한 적 타깃 찾기
    CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()

    -- [Rage Bot 실행 조건]
    if Toggles.RageEnabled.Value and CurrentTargetPart and CurrentTargetPlayer then
        local canTP = Toggles.TargetTP.Value 
            and IsSelfFirstPerson() 
            and IsTargetFirstPerson(CurrentTargetPlayer)

        if canTP then
            local targetPos = CurrentTargetPart.Position
            local height = Options.TPHeight.Value
            local abovePos = targetPos + Vector3.new(0, height, 0)

            hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

        -- 자동 발사 (목표 타깃 부위 전달)
        if Toggles.AutoShoot.Value then
            TriggerAutoShoot(CurrentTargetPart)
        end
    end

    -- [Movement]
    local isTPActive = Toggles.RageEnabled.Value and CurrentTargetPart and Toggles.TargetTP.Value and IsSelfFirstPerson() and CurrentTargetPlayer and IsTargetFirstPerson(CurrentTargetPlayer)
    
    if Toggles.Fly.Value and not isTPActive then
        hrp.AssemblyLinearVelocity = Vector3.zero
        local moveDir = Vector3.zero
        local speed = Options.FlySpeed.Value

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end

        if moveDir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (moveDir.Unit * (speed * delta))
        end
    end

    if Toggles.SpeedEnabled.Value and not Toggles.Fly.Value and hum.MoveDirection.Magnitude > 0 then
        local extraSpeed = (Options.WalkSpeed.Value - 1) * 16
        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (extraSpeed * delta))
    end

    if Toggles.SlideBoost.Value and not Toggles.Fly.Value and hum.MoveDirection.Magnitude > 0 then
        local boost = Options.BoostForce.Value * 5
        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (boost * delta))
    end

    -- [Anti Aim]
    if Toggles.AAEnabled.Value and not isTPActive then
        local yaw = 0
        local pitch = 0
        local speed = Options.YawSpeed.Value
        local yawLimit = Options.YawAngle.Value

        local yMode = Options.YawMode.Value
        if yMode == 'Static' then yaw = math.rad(yawLimit)
        elseif yMode == 'Jitter' then yaw = math.rad(math.sin(tick() * speed) * yawLimit)
        elseif yMode == 'Random' then yaw = math.rad(math.random(-yawLimit, yawLimit))
        elseif yMode == 'Spin' then yaw = math.rad((tick() * speed * 50) % 360) end

        local pMode = Options.PitchMode.Value
        if pMode == 'Up' then pitch = math.rad(-180)
        elseif pMode == 'Down' then pitch = math.rad(180)
        elseif pMode == 'Random' then pitch = math.rad(math.random(-180, 180))
        elseif pMode == 'Static' then pitch = math.rad(Options.PitchAngle.Value) end

        if Cache.waist then
            Cache.waist.Transform = CFrame.Angles(pitch, yaw, 0)
        elseif Cache.rootJoint then
            Cache.rootJoint.Transform = CFrame.Angles(pitch, 0, yaw)
        end

        if Cache.neck then
            Cache.neck.Transform = CFrame.Angles(pitch, 0, 0)
        end
    end
end)

-- 무한 점프
UserInputService.JumpRequest:Connect(function()
    if Toggles.JumpEnabled.Value and LocalPlayer.Character me then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Settings
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder('EclipseCore')
SaveManager:SetFolder('EclipseCore/configs')

local LeftMenuGroup = Tabs.Settings:AddLeftGroupbox('System Control')
LeftMenuGroup:AddButton('Unload Script', function() Library:Unload() end)
LeftMenuGroup:AddLabel('Menu Toggle'):AddKeyPicker('MenuKeybind', { Default = 'Right', Text = 'Menu keybind', NoUI = true })
Library.ToggleKeybind = Options.MenuKeybind

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:AddThemeSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
