-- 1. 안전한 HttpGet (타임아웃 방지)
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
    return warn("[Eclipse Core] 라이브러리 불러오기 실패. 잠시 후 다시 시도해 주세요.")
end

local Library = loadstring(libRaw)()
local ThemeManager = loadstring(themeRaw)()
local SaveManager = loadstring(saveRaw)()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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

local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
local AAGroup = Tabs.Character:AddRightGroupbox('Anti Aim')

-- Movement
CharGroup:AddToggle('Fly', {Text = 'Fly (Space: 상승 / Shift: 하강)'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200, Rounding = 0})

CharGroup:AddToggle('SpeedEnabled', {Text = 'Speed Hack'})
CharGroup:AddSlider('WalkSpeed', {Text = 'Speed Multiplier', Default = 2, Min = 1, Max = 10, Rounding = 1})

CharGroup:AddToggle('JumpEnabled', {Text = 'Infinite Jump'})

CharGroup:AddToggle('SlideBoost', {Text = 'Slide Boost'})
CharGroup:AddSlider('BoostForce', {Text = 'Boost Power', Default = 3, Min = 1, Max = 10, Rounding = 1})

-- Anti Aim
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

-- 3. 캐싱 및 관절 보호
local Cache = {
    char = nil, hrp = nil, hum = nil,
    waist = nil, rootJoint = nil, neck = nil,
    leftHip = nil, rightHip = nil,
    origWaistC0 = nil, origRootC0 = nil, origNeckC0 = nil,
    origLeftHipC0 = nil, origRightHipC0 = nil
}

local function ResetJoints()
    if Cache.waist and Cache.origWaistC0 then Cache.waist.C0 = Cache.origWaistC0 end
    if Cache.rootJoint and Cache.origRootC0 then Cache.rootJoint.C0 = Cache.origRootC0 end
    if Cache.neck and Cache.origNeckC0 then Cache.neck.C0 = Cache.origNeckC0 end
    if Cache.leftHip and Cache.origLeftHipC0 then Cache.leftHip.C0 = Cache.origLeftHipC0 end
    if Cache.rightHip and Cache.origRightHipC0 then Cache.rightHip.C0 = Cache.origRightHipC0 end
end

local function UpdateCache(character)
    ResetJoints()
    if not character then return end
    Cache.char = character
    Cache.hrp = character:WaitForChild("HumanoidRootPart", 3)
    Cache.hum = character:WaitForChild("Humanoid", 3)
    if not Cache.hrp or not Cache.hum then return end

    local upperTorso = character:FindFirstChild("UpperTorso")
    local torso = character:FindFirstChild("Torso")

    Cache.waist = upperTorso and upperTorso:FindFirstChild("Waist")
    Cache.rootJoint = Cache.hrp:FindFirstChild("RootJoint")
    Cache.neck = (torso and torso:FindFirstChild("Neck")) or (character:FindFirstChild("Head") and character.Head:FindFirstChild("Neck")) or (upperTorso and upperTorso:FindFirstChild("Neck"))
    Cache.leftHip = torso and torso:FindFirstChild("Left Hip")
    Cache.rightHip = torso and torso:FindFirstChild("Right Hip")

    if Cache.waist then Cache.origWaistC0 = Cache.waist.C0 end
    if Cache.rootJoint then Cache.origRootC0 = Cache.rootJoint.C0 end
    if Cache.neck then Cache.origNeckC0 = Cache.neck.C0 end
    if Cache.leftHip then Cache.origLeftHipC0 = Cache.leftHip.C0 end
    if Cache.rightHip then Cache.origRightHipC0 = Cache.rightHip.C0 end
end

if LocalPlayer.Character then UpdateCache(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(UpdateCache)

-- 4. 메인 프레임 루프 (부드러운 상체 회전 연산)
RunService.RenderStepped:Connect(function(delta)
    local hrp = Cache.hrp
    local hum = Cache.hum
    if not hrp or not hum or hum.Health <= 0 then return end

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
    if Toggles.SpeedEnabled.Value and not Toggles.Fly.Value and hum.MoveDirection.Magnitude > 0 then
        local extraSpeed = (Options.WalkSpeed.Value - 1) * 16
        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (extraSpeed * delta))
    end

    -- [3] Slide Boost
    if Toggles.SlideBoost.Value and not Toggles.Fly.Value and hum.MoveDirection.Magnitude > 0 then
        local boost = Options.BoostForce.Value * 5
        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (boost * delta))
    end

    -- [4] Anti Aim (상체만 독립 회전 / 다리 완전 고정)
    if Toggles.AAEnabled.Value then
        local yaw = 0
        local pitch = 0
        local speed = Options.YawSpeed.Value
        local yawLimit = Options.YawAngle.Value

        -- Yaw 연산 (0 ~ 180도)
        local yMode = Options.YawMode.Value
        if yMode == 'Static' then yaw = math.rad(yawLimit)
        elseif yMode == 'Jitter' then yaw = math.rad(math.sin(tick() * speed) * yawLimit)
        elseif yMode == 'Random' then yaw = math.rad(math.random(-yawLimit, yawLimit))
        elseif yMode == 'Spin' then yaw = math.rad((tick() * speed * 50) % 360) end

        -- Pitch 연산 (-180 ~ 180도)
        local pMode = Options.PitchMode.Value
        if pMode == 'Up' then pitch = math.rad(-180)
        elseif pMode == 'Down' then pitch = math.rad(180)
        elseif pMode == 'Random' then pitch = math.rad(math.random(-180, 180))
        elseif pMode == 'Static' then pitch = math.rad(Options.PitchAngle.Value) end

        -- R15 상체 회전
        if Cache.waist and Cache.origWaistC0 then
            Cache.waist.C0 = Cache.origWaistC0 * CFrame.Angles(pitch, yaw, 0)
        -- R6 상체 회전 + 다리 보정
        elseif Cache.rootJoint and Cache.origRootC0 then
            Cache.rootJoint.C0 = Cache.origRootC0 * CFrame.Angles(0, 0, yaw)
            if Cache.leftHip and Cache.rightHip and Cache.origLeftHipC0 and Cache.origRightHipC0 then
                local counterMatrix = (Cache.rootJoint.C0:Inverse() * Cache.origRootC0)
                Cache.leftHip.C0 = counterMatrix * Cache.origLeftHipC0
                Cache.rightHip.C0 = counterMatrix * Cache.origRightHipC0
            end
        end

        if Cache.neck and Cache.origNeckC0 then
            Cache.neck.C0 = Cache.origNeckC0 * CFrame.Angles(pitch, 0, 0)
        end
    else
        ResetJoints()
    end
end)

-- 무한 점프
UserInputService.JumpRequest:Connect(function()
    if Toggles.JumpEnabled.Value and Cache.hum then
        Cache.hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- 5. Settings 설정
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
