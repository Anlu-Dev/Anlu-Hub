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

-- 탭 생성
local Tabs = {
    Main = Window:AddTab('Main'),
    Visuals = Window:AddTab('Visuals'),
    ESP = Window:AddTab('ESP'),
    Character = Window:AddTab('Character'),
    Misc = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings'),
}

-- 2. Character 탭 구현 (직접 물리 조작 방식)
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement (Velocity Mode)')

CharGroup:AddToggle('Fly', {Text = 'Fly'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 150, Rounding = 0})

CharGroup:AddToggle('SpeedEnabled', {Text = 'Speed Hack'})
CharGroup:AddSlider('WalkSpeed', {Text = 'Speed Amount', Default = 25, Min = 16, Max = 100, Rounding = 0})

CharGroup:AddToggle('JumpEnabled', {Text = 'Infinite Jump'})

CharGroup:AddToggle('SlideBoost', {Text = 'Slide Boost'})
CharGroup:AddSlider('BoostForce', {Text = 'Boost Power', Default = 5, Min = 1, Max = 20, Rounding = 1})

-- 3. 핵심 물리 엔진 로직 (RunService.PreSimulation 활용)
RunService.PreSimulation:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    -- [1] Fly 로직 (카메라 방향 기준)
    if Toggles.Fly.Value then
        hum.PlatformStand = true -- 캐릭터가 넘어지지 않게 고정
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.new(0, 0, 0)
        local speed = Options.FlySpeed.Value

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end

        hrp.AssemblyLinearVelocity = moveDir * speed
    else
        hum.PlatformStand = false
    end

    -- [2] Speed Hack (Velocity 강제 적용)
    if Toggles.SpeedEnabled.Value and not Toggles.Fly.Value then
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * Options.WalkSpeed.Value, hrp.AssemblyLinearVelocity.Y, moveDir.Z * Options.WalkSpeed.Value)
        end
    end

    -- [3] Slide Boost (이동 방향으로 강한 힘 추가)
    if Toggles.SlideBoost.Value and hum.MoveDirection.Magnitude > 0 then
        hrp.AssemblyLinearVelocity += (hum.MoveDirection * Options.BoostForce.Value)
    end
end)

-- [4] Infinite Jump (이벤트 기반으로 훨씬 깔끔함)
UserInputService.JumpRequest:Connect(function()
    if Toggles.JumpEnabled.Value then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 50, hrp.AssemblyLinearVelocity.Z)
        end
    end
end)

-- 4. 시스템 설정
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
