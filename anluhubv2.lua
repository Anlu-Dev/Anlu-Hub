local repo = 'https://raw.githubusercontent.com/Anlu-Dev/Library/refs/heads/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua'))()

-- 서비스 참조
local RunService = game:GetService("RunService")
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

-- 3. Character 탭 구현
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')

-- Fly 기능
local flySpeed = 50
CharGroup:AddToggle('Fly', {Text = 'Fly'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200, Rounding = 0})

-- Slide Boost
CharGroup:AddToggle('SlideBoost', {Text = 'Slide Boost'})
CharGroup:AddSlider('BoostForce', {Text = 'Boost Force', Default = 2, Min = 1, Max = 10, Rounding = 1})

-- Velocity(WalkSpeed)
CharGroup:AddSlider('WalkSpeed', {Text = 'Walk Speed', Default = 16, Min = 16, Max = 100, Rounding = 0})

-- JumpPower
CharGroup:AddSlider('JumpPower', {Text = 'Jump Power', Default = 50, Min = 50, Max = 200, Rounding = 0})

-- 4. 로직 연결
local flyVelocity = nil

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    if not hrp or not hum then return end

    -- Fly 로직
    if Toggles.Fly.Value then
        if not flyVelocity then
            flyVelocity = Instance.new("BodyVelocity")
            flyVelocity.MaxForce = Vector3.new(1,1,1) * 1e6
            flyVelocity.Velocity = Vector3.new(0,0,0)
            flyVelocity.Parent = hrp
        end
        local cam = workspace.CurrentCamera
        flyVelocity.Velocity = (cam.CFrame.LookVector * (game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) and Options.FlySpeed.Value or 0)) 
                             + (cam.CFrame.RightVector * (game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) and Options.FlySpeed.Value or 0))
                             - (cam.CFrame.RightVector * (game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) and Options.FlySpeed.Value or 0))
    else
        if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
    end

    -- WalkSpeed & JumpPower 업데이트
    hum.WalkSpeed = Options.WalkSpeed.Value
    hum.JumpPower = Options.JumpPower.Value

    -- Slide Boost (간단한 예시: 이동 방향으로 속도 증폭)
    if Toggles.SlideBoost.Value and hum.MoveDirection.Magnitude > 0 then
        hrp.Velocity = hrp.Velocity + (hrp.CFrame.LookVector * Options.BoostForce.Value)
    end
end)

-- 5. 시스템 설정
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
