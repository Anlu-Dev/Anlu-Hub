local repo = 'https://raw.githubusercontent.com/Anlu-Dev/Library/refs/heads/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua'))()

-- 서비스 참조
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 1. 윈도우 생성
local Window = Library:CreateWindow({
    Title = 'Eclipse | Core System',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- 2. 탭 생성
local Tabs = {
    Main = Window:AddTab('Main'),
    Visuals = Window:AddTab('Visuals'),
    ESP = Window:AddTab('ESP'),
    Character = Window:AddTab('Character'),
    Misc = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings'),
}

-- 3. Character 탭 구성
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
local AAGroup = Tabs.Character:AddRightGroupbox('Anti Aim')

-- [Movement 섹션]
CharGroup:AddToggle('Fly', {Text = 'Fly (Space: 상승 / Shift: 하강)'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200, Rounding = 0})

CharGroup:AddToggle('SpeedEnabled', {Text = 'Speed Hack'})
CharGroup:AddSlider('WalkSpeed', {Text = 'Speed Multiplier', Default = 2, Min = 1, Max = 10, Rounding = 1})

CharGroup:AddToggle('JumpEnabled', {Text = 'Infinite Jump'})

CharGroup:AddToggle('SlideBoost', {Text = 'Slide Boost'})
CharGroup:AddSlider('BoostForce', {Text = 'Boost Power', Default = 3, Min = 1, Max = 10, Rounding = 1})

-- [Anti Aim 섹션]
AAGroup:AddToggle('AAEnabled', {Text = 'Enable Anti Aim'})

-- Yaw 설정 (0 ~ 180도)
AAGroup:AddDropdown('YawMode', {
    Values = {'Static', 'Jitter', 'Random', 'Extended Random'},
    Default = 1,
    Multi = false,
    Text = 'Yaw Mode'
})
AAGroup:AddSlider('YawAngle', {Text = 'Torso Yaw Limit', Default = 90, Min = 0, Max = 180, Rounding = 0})
AAGroup:AddSlider('YawSpeed', {Text = 'Yaw Speed / Jitter Speed', Default = 10, Min = 1, Max = 50, Rounding = 0})

-- Pitch 설정 (-180 ~ 180도 확장)
AAGroup:AddDropdown('PitchMode', {
    Values = {'Static', 'Up', 'Down', 'Random', 'Extended Random'},
    Default = 1,
    Multi = false,
    Text = 'Pitch Mode'
})
AAGroup:AddSlider('PitchAngle', {Text = 'Pitch Angle (Static)', Default = 0, Min = -180, Max = 180, Rounding = 0})

-- 관절 원본 상태 저장 변수
local originalWaistC0 = nil
local originalRootC0 = nil
local originalNeckC0 = nil
local originalLeftHipC0 = nil
local originalRightHipC0 = nil

-- 4. 메인 루프 (Movement + Anti Aim)
RunService.RenderStepped:Connect(function(delta)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    -- [1] Fly
    if Toggles.Fly.Value then
        hrp.AssemblyLinearVelocity = Vector3.zero
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero
        local speed = Options.FlySpeed.Value

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end

        if moveDir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (moveDir.Unit * (speed * delta))
        end
    end

    -- [2] Speed Hack
    if Toggles.SpeedEnabled.Value and not Toggles.Fly.Value then
        if hum.MoveDirection.Magnitude > 0 then
            local extraSpeed = (Options.WalkSpeed.Value - 1) * 16
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (extraSpeed * delta))
        end
    end

    -- [3] Slide Boost
    if Toggles.SlideBoost.Value and not Toggles.Fly.Value and hum.MoveDirection.Magnitude > 0 then
        local boost = Options.BoostForce.Value * 5
        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (boost * delta))
    end

    -- [4] Anti Aim (다리 고정 + Pitch 180도 연산)
    local upperTorso = char:FindFirstChild("UpperTorso")
    local waist = upperTorso and upperTorso:FindFirstChild("Waist")
    local rootJoint = hrp:FindFirstChild("RootJoint")
    local neck = (char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Neck")) or (char:FindFirstChild("Head") and char.Head:FindFirstChild("Neck")) or (upperTorso and upperTorso:FindFirstChild("Neck"))
    
    local torso = char:FindFirstChild("Torso")
    local leftHip = torso and torso:FindFirstChild("Left Hip")
    local rightHip = torso and torso:FindFirstChild("Right Hip")

    if Toggles.AAEnabled.Value then
        local yaw = 0
        local pitch = 0
        local speed = Options.YawSpeed.Value
        local yawLimit = Options.YawAngle.Value

        -- Yaw 연산 (0~180도)
        local yMode = Options.YawMode.Value
        if yMode == 'Static' then
            yaw = math.rad(yawLimit)
        elseif yMode == 'Jitter' then
            yaw = math.rad(math.sin(tick() * speed) * yawLimit)
        elseif yMode == 'Random' then
            yaw = math.rad(math.random(-yawLimit, yawLimit))
        elseif yMode == 'Extended Random' then
            yaw = math.rad(math.random(-yawLimit, yawLimit))
        end

        -- Pitch 연산 (-180~180도)
        local pMode = Options.PitchMode.Value
        if pMode == 'Up' then
            pitch = math.rad(-180)
        elseif pMode == 'Down' then
            pitch = math.rad(180)
        elseif pMode == 'Random' then
            pitch = math.rad(math.random(-180, 180))
        elseif pMode == 'Extended Random' then
            pitch = math.rad(math.random(-180, 180))
        elseif pMode == 'Static' then
            pitch = math.rad(Options.PitchAngle.Value)
        end

        -- R15 상체 전용 회전 (하체 자동 고정)
        if waist then
            if not originalWaistC0 then originalWaistC0 = waist.C0 end
            waist.C0 = originalWaistC0 * CFrame.Angles(pitch, yaw, 0)
        -- R6 상체 회전 + 다리 역행렬 고정 연산
        elseif rootJoint then
            if not originalRootC0 then originalRootC0 = rootJoint.C0 end
            rootJoint.C0 = originalRootC0 * CFrame.Angles(0, 0, yaw)

            -- R6 다리를 몸통 회전 반대 방향으로 상쇄시켜 제자리에 고정
            if leftHip and rightHip then
                if not originalLeftHipC0 then originalLeftHipC0 = leftHip.C0 end
                if not originalRightHipC0 then originalRightHipC0 = rightHip.C0 end

                local counterMatrix = (rootJoint.C0:Inverse() * originalRootC0)
                leftHip.C0 = counterMatrix * originalLeftHipC0
                rightHip.C0 = counterMatrix * originalRightHipC0
            end
        end

        if neck then
            if not originalNeckC0 then originalNeckC0 = neck.C0 end
            neck.C0 = originalNeckC0 * CFrame.Angles(pitch, 0, 0)
        end
    else
        -- 비활성화 시 모든 관절 원상복구
        if originalWaistC0 and waist then waist.C0 = originalWaistC0 originalWaistC0 = nil end
        if originalRootC0 and rootJoint then rootJoint.C0 = originalRootC0 originalRootC0 = nil end
        if originalNeckC0 and neck then neck.C0 = originalNeckC0 originalNeckC0 = nil end
        if originalLeftHipC0 and leftHip then leftHip.C0 = originalLeftHipC0 originalLeftHipC0 = nil end
        if originalRightHipC0 and rightHip then rightHip.C0 = originalRightHipC0 originalRightHipC0 = nil end
    end
end)

-- 무한 점프
UserInputService.JumpRequest:Connect(function()
    if Toggles.JumpEnabled.Value then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- 5. Settings 및 매니저 설정
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
