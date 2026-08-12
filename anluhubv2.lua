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
    return warn("[Eclipse Core] 라이브러리 불러오기 실패. 다시 실행해주세요.")
end

local Library = loadstring(libRaw)()
local ThemeManager = loadstring(themeRaw)()
local SaveManager = loadstring(saveRaw)()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 2. 윈도우 및 탭 생성
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

-- 3. Character 탭 구성
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
local AAGroup = Tabs.Character:AddRightGroupbox('Server Anti Aim')

CharGroup:AddToggle('Fly', {Text = 'Fly (Space: 상승 / Shift: 하강)'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200, Rounding = 0})

CharGroup:AddToggle('SpeedEnabled', {Text = 'Speed Hack'})
CharGroup:AddSlider('WalkSpeed', {Text = 'Speed Multiplier', Default = 2, Min = 1, Max = 10, Rounding = 1})

CharGroup:AddToggle('JumpEnabled', {Text = 'Infinite Jump'})

CharGroup:AddToggle('SlideBoost', {Text = 'Slide Boost'})
CharGroup:AddSlider('BoostForce', {Text = 'Boost Power', Default = 3, Min = 1, Max = 10, Rounding = 1})

-- Anti Aim
AAGroup:AddToggle('AAEnabled', {Text = 'Enable Server Anti Aim'})

AAGroup:AddDropdown('YawMode', {
    Values = {'Spin', 'Jitter', 'Random', 'Backwards'},
    Default = 1,
    Multi = false,
    Text = 'Yaw Mode (Server Side)'
})
AAGroup:AddSlider('YawAngle', {Text = 'Yaw Limit (Degrees)', Default = 90, Min = 0, Max = 180, Rounding = 0})
AAGroup:AddSlider('YawSpeed', {Text = 'Rotation Speed', Default = 15, Min = 1, Max = 50, Rounding = 0})

-- 캐싱 처리
local Cache = { hrp = nil, hum = nil }

local function UpdateCache(character)
    if not character then Cache.hrp = nil Cache.hum = nil return end
    Cache.hrp = character:WaitForChild("HumanoidRootPart", 3)
    Cache.hum = character:WaitForChild("Humanoid", 3)
end

if LocalPlayer.Character then UpdateCache(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(UpdateCache)

-- 4. 메인 루프 (서버 복제 CFrame 처리)
RunService.PreSimulation:Connect(function(delta)
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

    -- [4] Server-Sided Anti Aim (CFrame 회전식)
    if Toggles.AAEnabled.Value then
        hum.AutoRotate = false -- 캐릭터 자동 시점 회전 끄기 (서버 반영 필수)

        local yaw = 0
        local speed = Options.YawSpeed.Value
        local yawLimit = Options.YawAngle.Value
        local yMode = Options.YawMode.Value

        if yMode == 'Spin' then
            yaw = math.rad((tick() * speed * 50) % 360)
        elseif yMode == 'Jitter' then
            yaw = math.rad(math.sin(tick() * speed) * yawLimit)
        elseif yMode == 'Random' then
            yaw = math.rad(math.random(-yawLimit, yawLimit))
        elseif yMode == 'Backwards' then
            yaw = math.rad(180)
        end

        -- HumanoidRootPart CFrame 직접 회전 (서버 복제)
        local currentPos = hrp.Position
        local currentRot = hrp.CFrame - currentPos
        hrp.CFrame = CFrame.new(currentPos) * (currentRot * CFrame.Angles(0, yaw, 0))
    else
        hum.AutoRotate = true -- 원상 복구
    end
end)

-- 무한 점프
UserInputService.JumpRequest:Connect(function()
    if Toggles.JumpEnabled.Value and Cache.hum then
        Cache.hum:ChangeState(Enum.HumanoidStateType.Jumping)
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
