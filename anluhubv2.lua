--[[
    Anlu Hub v2 - RIVALS GOD EDITION (Anti-Kick Fixed)
    Optimized for Stability & Performance
    Bypass: Pure & Clean (No self-kicking logic)
]]

-- [0. Rivals Core Bypass - 절대 안 튕기는 클린 우회]
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

-- 1. Anti-Kick (안티치트의 킥 명령을 무시)
local oldKick
oldKick = hookfunction(LocalPlayer.Kick, function(self, ...)
    if not checkcaller() then return nil end
    return oldKick(self, ...)
end)

-- 2. Remote Protection (안티치트 신호 차단)
local rawMetatable = getrawmetatable(game)
local oldNamecall = rawMetatable.__namecall
local oldIndex = rawMetatable.__index
setreadonly(rawMetatable, false)

rawMetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    -- Rivals 안티치트 리모트 이벤트 무력화
    if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
        local name = tostring(self)
        if name:find("AntiCheat") or name:find("Cheat") or name:find("Kick") or name:find("Ban") or name:find("Check") then
            return nil
        end
    end
    
    -- Silent Aim (Raycast Hook)
    if not checkcaller() and Toggles and Toggles.RageEnabled and Toggles.RageEnabled.Value and _G.CurrentTargetPart then
        if method == "Raycast" and self == workspace then
            args[2] = (_G.CurrentTargetPart.Position - args[1]).Unit * 10000
            return oldNamecall(self, unpack(args))
        end
    end
    
    return oldNamecall(self, ...)
end)

rawMetatable.__index = newcclosure(function(self, index)
    if not checkcaller() and Toggles and Toggles.RageEnabled and Toggles.RageEnabled.Value and _G.CurrentTargetPart then
        if self == LocalPlayer:GetMouse() then
            if index == "Hit" then return _G.CurrentTargetPart.CFrame
            elseif index == "Target" then return _G.CurrentTargetPart end
        end
    end
    return oldIndex(self, index)
end)
setreadonly(rawMetatable, true)

-- [[ 1. 라이브러리 및 UI 로딩 ]]
local function SafeHttpGet(url)
    local success, res = pcall(function() return game:HttpGet(url, true) end)
    return success and res or nil
end

local libRaw = SafeHttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua') or SafeHttpGet('https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua')
if not libRaw then return warn("[Anlu Hub] 라이브러리 로드 실패.") end
local Library = loadstring(libRaw)()
local Camera = workspace.CurrentCamera

local Window = Library:CreateWindow({ Title = 'Anlu Hub | RIVALS GOD EDITION', Center = true, AutoShow = true })
local Tabs = { Main = Window:AddTab('Main'), Character = Window:AddTab('Character'), Settings = Window:AddTab('Settings') }

local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})

local TargetGroup = Tabs.Main:AddRightGroupbox('Target Settings')
TargetGroup:AddDropdown('TargetPart', { Values = {'Head', 'HumanoidRootPart'}, Default = 1, Text = 'Target Part' })
TargetGroup:AddSlider('RageRange', {Text = 'Max Range', Default = 10000, Min = 100, Max = 99999})
TargetGroup:AddSlider('TPHeight', {Text = 'TP Height', Default = 5, Min = 1, Max = 15})

-- [[ 2. 무기 시스템 후킹 (Rage Bot 연동) ]]
local OriginalStats = {}
local clientItemModule = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
local oldInput; oldInput = hookfunction(clientItemModule.Input, function(...)
    local args = {...}
    if Toggles.RageEnabled.Value and type(args[1]) == "table" and args[1].Info then
        local info = args[1].Info
        local gunName = args[1].Name or "Default"
        if not OriginalStats[gunName] then
            OriginalStats[gunName] = { Recoil = info.ShootRecoil, Spread = info.ShootSpread, CD = info.ShootCooldown, QCD = info.QuickShotCooldown }
        end
        -- Rivals 전용 무기 스탯 강제 고정
        info.ShootRecoil = 0
        info.ShootSpread = 0
        info.ShootCooldown = 0
        info.QuickShotCooldown = 0
        info.ProjectileSpeed = 999999
        info.BulletVelocity = 999999
        info.ReloadTime = 0.01
    end
    return oldInput(...)
end)

-- [[ 3. 타겟팅 및 사격 로직 ]]
local function GetValidTarget()
    local maxDist = Options.RageRange.Value
    local closestPart = nil
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            if not player.Character:FindFirstChildOfClass("ForceField") then
                local part = player.Character:FindFirstChild(Options.TargetPart.Value)
                if part then
                    local dist = (part.Position - myHRP.Position).Magnitude
                    if dist < maxDist then maxDist = dist; closestPart = part end
                end
            end
        end
    end
    return closestPart
end

-- [[ 4. 메인 루프 ]]
local voidState = "Attack"
local lastStateChange = os.clock()

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    
    _G.CurrentTargetPart = GetValidTarget()

    if Toggles.RageEnabled.Value and _G.CurrentTargetPart then
        local targetPos = _G.CurrentTargetPart.Position
        local abovePos = targetPos + Vector3.new(0, Options.TPHeight.Value, 0)
        
        -- 카메라 락온 (Silent Aim 보조)
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)

        if Toggles.VoidSpam.Value then
            local now = os.clock()
            if voidState == "Attack" then
                if (now - lastStateChange >= 0.1) then 
                    voidState = "Hide"; lastStateChange = now; hrp.CFrame = CFrame.new(targetPos.X, -100, targetPos.Z)
                else
                    hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                    local tool = char:FindFirstChildOfClass("Tool"); if tool then tool:Activate() end
                end
            else
                if (now - lastStateChange >= 0.05) then 
                    voidState = "Attack"; lastStateChange = now
                else hrp.CFrame = CFrame.new(targetPos.X, -100, targetPos.Z) end
            end
        else
            hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
            local tool = char:FindFirstChildOfClass("Tool"); if tool then tool:Activate() end
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end)

-- [[ 5. 이동 기능 ]]
local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
CharGroup:AddToggle('Fly', {Text = 'Fly'})
CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200})

Library.ToggleKeybind = Options.MenuKeybind
print("[Anlu Hub] Rivals God Edition Loaded! 🚀✨")
