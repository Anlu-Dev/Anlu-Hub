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

-- Rage Bot 마스터 토글 (켜면 하위 항목 자동 전체 활성화)
RageGroup:AddToggle('RageEnabled', {
    Text = 'Enable Rage Bot',
    Default = false,
    Callback = function(Value)
        if Toggles.TargetTP then Toggles.TargetTP:SetValue(Value) end
        if Toggles.SilentAim then Toggles.SilentAim:SetValue(Value) end
        if Toggles.AutoShoot then Toggles.AutoShoot:SetValue(Value) end
    end
})

RageGroup:AddToggle('TargetTP', {Text = 'TP Above Target (1인칭 전용)', Default = true})
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

-- 4. 유틸리티 함수 (1인칭 여부 / 무적 체크)
local function IsFirstPerson()
    local char = LocalPlayer.Character
    if not char then return false end
    local head = char:FindFirstChild("Head")
    if not head then return false end
    -- 카메라와 Head 사이 거리로 1인칭 판별 (2.5 Studs 미만일 경우 1인칭)
    return (Camera.CFrame.Position - head.Position).Magnitude < 2.5
end

local function IsInvincible(character)
    if not character then return true end
    -- ForceField 및 스폰 무적 태그 검사
    if character:FindFirstChildOfClass("ForceField") then return true end
    if character:FindFirstChild("SpawnProtection") or character:FindFirstChild("Shield") or character:FindFirstChild("Invincible") then return true end
    return false
end

-- 5. 360도 전방위 타깃 탐색 (거리 무제한 가능 + 무적 제외)
local CurrentTargetPart = nil

local function Get360Target()
    if not Toggles.RageEnabled.Value then return nil end
    local maxDistance = Options.RageRange.Value
    local closestTarget = nil
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            -- 무적이 아니고 체력이 남아있는 적만 필터링
            if hum and hum.Health > 0 and not IsInvincible(char) then
                local partName = Options.TargetPart.Value
                local targetPart = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
                
                if targetPart then
                    local dist = (targetPart.Position - myHRP.Position).Magnitude
                    if dist <= maxDistance then
                        maxDistance = dist
                        closestTarget = targetPart
                    end
                end
            end
        end
    end
    return closestTarget
end

-- 6. 하이엔드 360° Silent Aim (Raycast + Mouse Hooking)
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

-- 7. 강력한 Auto Fire 함수
local function TriggerAutoShoot()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
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
end

-- 8. 메인 프레임 루프
RunService.Stepped:Connect(function(_, delta)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    -- 타깃 탐색
    CurrentTargetPart = Get360Target()

    -- [Rage Bot 동작 조건]
    if Toggles.RageEnabled.Value and CurrentTargetPart then
        -- 1인칭 상태일 때만 적 위 상공 밀착 텔레포트 적용
        if Toggles.TargetTP.Value and IsFirstPerson() then
            local targetPos = CurrentTargetPart.Position
            local height = Options.TPHeight.Value
            local abovePos = targetPos + Vector3.new(0, height, 0)

            hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

        -- 자동 사격 실행
        if Toggles.AutoShoot.Value then
            TriggerAutoShoot()
        end
    end

    -- [Movement]
    if Toggles.Fly.Value and not (Toggles.RageEnabled.Value and CurrentTargetPart and Toggles.TargetTP.Value and IsFirstPerson()) then
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
    if Toggles.AAEnabled.Value and not (Toggles.RageEnabled.Value and CurrentTargetPart and Toggles.TargetTP.Value and IsFirstPerson()) then
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
    if Toggles.JumpEnabled.Value and LocalPlayer.Character then
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
