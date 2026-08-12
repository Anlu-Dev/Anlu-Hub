-- 1. 라이브러리 불러오기
local function SafeHttpGet(url)
    local success, result = pcall(function()
        return game:HttpGet(url, true)
    end)
    if success and result then return result end
    return nil
end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local libRaw = SafeHttpGet(repo .. 'Library.lua')

if not libRaw then
    return warn("[Eclipse Core] 라이브러리 불러오기 실패.")
end

local Library = loadstring(libRaw)()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
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

RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})

-- 3인칭 & 커서 상태 제어 옵션
RageGroup:AddToggle('Disable3rdPerson', {Text = '3인칭일 때 자동발사 끄기', Default = true})
RageGroup:AddToggle('DisableUnlockedCursor', {Text = '커서 풀렸을 때 자동발사 끄기', Default = true})

local TargetStatusLabel = TargetGroup:AddLabel('Target Status: None')

TargetGroup:AddToggle('TeamCheck', {Text = 'Team Check (팀전 게임에서만 ON)', Default = false})

TargetGroup:AddDropdown('TargetPart', {
    Values = {'Head', 'HumanoidRootPart', 'Torso'},
    Default = 1,
    Multi = false,
    Text = 'Target Part'
})

TargetGroup:AddSlider('TPHeight', {Text = 'TP Height Above Enemy', Default = 3, Min = 1, Max = 15, Rounding = 1})
TargetGroup:AddSlider('RageRange', {Text = 'Max Detection Range', Default = 10000, Min = 100, Max = 99999, Rounding = 0})

TargetGroup:AddSlider('HideTime', {Text = 'Void Hide Time (Sec)', Default = 0.05, Min = 0.01, Max = 1, Rounding = 2})
TargetGroup:AddSlider('AttackTime', {Text = 'Attack Time (Sec)', Default = 0.1, Min = 0.01, Max = 1, Rounding = 2})

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

-- 2.1 무기 스탯 후킹 로직 (Rage Bot 연동)
local OriginalStats = {}
local clientItemModule = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
local inputFunc = clientItemModule.Input

local oldInput
oldInput = hookfunction(inputFunc, function(...)
    local args = {...}
    
    -- Rage Bot이 켜져 있을 때만 작동
    if Toggles.RageEnabled and Toggles.RageEnabled.Value and type(args[1]) == "table" and args[1].Info then
        local gunName = args[1].Name or "Default"
        local info = args[1].Info
        
        -- 원본 스탯 저장 (나중에 껐을 때 복구용)
        if not OriginalStats[gunName] then
            OriginalStats[gunName] = {
                Recoil = info.ShootRecoil,
                Spread = info.ShootSpread,
                CD = info.ShootCooldown,
                QCD = info.QuickShotCooldown
            }
        end
        
        -- [Rage 모드 활성화: Rapid Fire, No Spread, Rapid Melee]
        info.ShootRecoil = 0
        info.ShootSpread = 0
        info.ShootCooldown = 0
        info.QuickShotCooldown = 0
        
    elseif OriginalStats and type(args[1]) == "table" and args[1].Info then
        -- Rage Bot이 꺼져 있으면 원본 스탯으로 복구
        local gunName = args[1].Name or "Default"
        local orig = OriginalStats[gunName]
        if orig then
            local info = args[1].Info
            info.ShootRecoil = orig.Recoil
            info.ShootSpread = orig.Spread
            info.ShootCooldown = orig.CD
            info.QuickShotCooldown = orig.QCD
        end
    end
    
    return oldInput(...)
end)

-- 3. 자동 사격 조건 정밀 검증 함수
local function CanAutoShoot()
    -- 1. UI 창이 켜져 있을 때 차단
    if Library.Toggled then return false end
    if Library.ScreenGui and Library.ScreenGui.Enabled then return false end

    -- 2. 채팅창 등 텍스트 박스 입력 중일 때 차단
    if UserInputService:GetFocusedTextBox() ~= nil then return false end

    -- 3. 마우스 커서가 화면에 자유롭게 풀려 있을 때 차단
    if Toggles.DisableUnlockedCursor and Toggles.DisableUnlockedCursor.Value then
        if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
            return false
        end
    end

    -- 4. 카메라 시점이 3인칭일 때 차단
    if Toggles.Disable3rdPerson and Toggles.Disable3rdPerson.Value then
        local char = LocalPlayer.Character
        if char then
            local head = char:FindFirstChild("Head")
            if head then
                local camDist = (Camera.CFrame.Position - head.Position).Magnitude
                if camDist > 2.2 then -- 카메라와 머리 거리가 2.2 Studs 이상이면 3인칭
                    return false
                end
            end
        end
        -- Shift Lock이 해제된 3인칭 상태 감지
        if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
            return false
        end
    end

    return true
end

-- 4. 관절 캐싱
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

-- 5. 필터링 및 유효 적 검사
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
        if LocalPlayer.Team ~= nil and player.Team ~= nil then
            return player.Team == LocalPlayer.Team
        end
    end
    return false
end

local CurrentTargetPart = nil
local CurrentTargetPlayer = nil

local function GetValidTarget()
    if not (Toggles.RageEnabled and Toggles.RageEnabled.Value) then return nil, nil end
    local maxDistance = Options.RageRange and Options.RageRange.Value or 99999
    local closestPart = nil
    local closestPlayer = nil
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

-- 6. Silent Aim Metatable Hook
local rawMetatable = getrawmetatable(game)
local oldNamecall = rawMetatable.__namecall
local oldIndex = rawMetatable.__index
setreadonly(rawMetatable, false)

rawMetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if not checkcaller() and Toggles.RageEnabled and Toggles.RageEnabled.Value and CurrentTargetPart then
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
    if not checkcaller() and Toggles.RageEnabled and Toggles.RageEnabled.Value and CurrentTargetPart then
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

-- 7. 초고속 자동 발사 (Void Spam 시 쿨다운 즉시 무시)
local lastShootTime = 0

local function BuffedAutoShoot(targetPart, forceShoot)
    -- 조건 검사 (3인칭, 커서 풀림, UI 열림 시 사격 안 함)
    if not CanAutoShoot() then 
        return 
    end

    local now = os.clock()
    -- forceShoot(Void 공격 프레임)가 아닐 때만 쿨다운 적용
    if not forceShoot and (now - lastShootTime < 0.03) then 
        return 
    end
    lastShootTime = now

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local tool = char:FindFirstChildOfClass("Tool")
    
    if not tool and hum then
        local backpackTool = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
        if backpackTool then
            hum:EquipTool(backpackTool)
            tool = backpackTool
        end
    end

    if tool then
        tool:Activate()
    end

    pcall(function()
        if mouse1press then
            mouse1press()
            mouse1release()
        end
    end)

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.zero)
        VirtualUser:Button1Up(Vector2.zero)
    end)

    pcall(function()
        local vp = Camera.ViewportSize
        VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
    end)
end

-- 8. 메인 프레임 루프 (Void Spam 0.01초 정밀 사격 제어)
local voidState = "Attack"
local lastStateChange = os.clock()

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then 
        TargetStatusLabel:SetText('Target Status: None')
        return 
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then 
        TargetStatusLabel:SetText('Target Status: None')
        return 
    end

    CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()

    if CurrentTargetPlayer then
        TargetStatusLabel:SetText('Target Status: ' .. CurrentTargetPlayer.Name)
    else
        TargetStatusLabel:SetText('Target Status: None')
    end

    -- [Rage Bot & Void Spam 루프]
    if Toggles.RageEnabled.Value and CurrentTargetPart then
        local targetPos = CurrentTargetPart.Position
        local height = Options.TPHeight.Value
        local abovePos = targetPos + Vector3.new(0, height, 0)

        if Toggles.VoidSpam.Value then
            local now = os.clock()
            local hideTime = Options.HideTime.Value
            local attackTime = Options.AttackTime.Value

            if voidState == "Attack" then
                if (now - lastStateChange >= attackTime) then
                    voidState = "Hide"
                    lastStateChange = now
                    hrp.CFrame = CFrame.new(0, -500, 0) -- 숨기
                else
                    -- 공격 상태: 적 상공 TP 후 0.001초 즉시 정밀 발사
                    hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                    BuffedAutoShoot(CurrentTargetPart, true)
                end
            elseif voidState == "Hide" then
                if (now - lastStateChange >= hideTime) then
                    voidState = "Attack"
                    lastStateChange = now
                    -- 공격 상태 진입 즉시 TP 및 강제 즉시 발사
                    hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                    BuffedAutoShoot(CurrentTargetPart, true)
                else
                    hrp.CFrame = CFrame.new(0, -500, 0)
                end
            end
        else
            -- 일반 TP 공격
            hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
            BuffedAutoShoot(CurrentTargetPart, false)
        end

        hrp.AssemblyLinearVelocity = Vector3.zero
    end

    -- [Movement]
    local isRageActive = Toggles.RageEnabled.Value and CurrentTargetPart
    
    if Toggles.Fly.Value and not isRageActive then
        hrp.AssemblyLinearVelocity = Vector3.zero
        local moveDir = Vector3.zero
        local speed = Options.FlySpeed.Value

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end

        if moveDir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (moveDir.Unit * speed * RunService.Heartbeat:Wait())
        end
    end

    if Toggles.SpeedEnabled.Value and not isRageActive then
        local multiplier = Options.WalkSpeed.Value
        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * multiplier * 0.5)
    end

    if Toggles.JumpEnabled.Value then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    if Toggles.SlideBoost.Value and hum.FloorMaterial ~= Enum.Material.Air then
        if hum.MoveDirection.Magnitude > 0 and UserInputService:IsKeyDown(Enum.KeyCode.C) then
            hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + (hum.MoveDirection * Options.BoostForce.Value)
        end
    end

    -- [Anti Aim]
    if Toggles.AAEnabled.Value and not isRageActive then
        local yawMode = Options.YawMode.Value
        local yawLimit = Options.YawAngle.Value
        local yawSpeed = Options.YawSpeed.Value
        local pitchMode = Options.PitchMode.Value
        local pitchAngle = Options.PitchAngle.Value

        local finalYaw = 0
        if yawMode == 'Static' then
            finalYaw = math.rad(yawLimit)
        elseif yawMode == 'Jitter' then
            finalYaw = math.rad(math.random(-yawLimit, yawLimit))
        elseif yawMode == 'Random' then
            finalYaw = math.rad(math.random(-180, 180))
        elseif yawMode == 'Spin' then
            finalYaw = math.rad((tick() * yawSpeed * 100) % 360)
        end

        local finalPitch = 0
        if pitchMode == 'Static' then
            finalPitch = math.rad(pitchAngle)
        elseif pitchMode == 'Up' then
            finalPitch = math.rad(-89)
        elseif pitchMode == 'Down' then
            finalPitch = math.rad(89)
        elseif pitchMode == 'Random' then
            finalPitch = math.rad(math.random(-89, 89))
        end

        if Cache.waist then
            Cache.waist.C0 = CFrame.new(0, 0.85, 0) * CFrame.Angles(finalPitch, finalYaw, 0)
        end
        if Cache.rootJoint then
            Cache.rootJoint.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(-180) + finalYaw)
        end
    end
end)

-- [Misc 탭]
local MiscGroup = Tabs.Misc:AddLeftGroupbox('Misc')
MiscGroup:AddButton('FPS Boost', function()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Decal") then
            v.Material = Enum.Material.SmoothPlastic
            if v:IsA("Decal") then v.Transparency = 1 end
        end
    end
end)

MiscGroup:AddButton('Rejoin', function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end)

-- [Settings 탭]
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddLabel('Menu Keybind'):AddKeybind('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu Keybind' })

Library.ToggleKeybind = Options.MenuKeybind
