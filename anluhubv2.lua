--[[
    Anlu Hub v2 - RIVALS FINAL INTEGRATED
    Bypass + Rivals Perfect Optimization
]]

-- LPH_NO_VIRTUALIZE 에러 방지용 정의
if not LPH_NO_VIRTUALIZE then
    LPH_NO_VIRTUALIZE = function(f) return f end
end

pcall(LPH_NO_VIRTUALIZE(function()
    local bypassed = false

    local kKickNames = {"Kick", "kick"}
    local kProtectedProperties = {Enabled = true, Disabled = false}
    local kSlotMap = {[69]=2, [138]=3, [207]=4, [276]=5, [345]=6, [414]=7}
    local kFilledSub = {1, 2, 3, 4, 5}

    local Players = cloneref(game:GetService("Players"))
    local ReplicatedFirst = cloneref(game:GetService("ReplicatedFirst"))
    local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
    local ScriptContext = cloneref(game:GetService("ScriptContext"))
    local LocalPlayer = Players.LocalPlayer

    local ac_script = ReplicatedFirst:WaitForChild("LocalScript3")
    local ac_event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RemoteEvent")

    local last = nil
    local first_seen = false
    local hijack_ready = false
    local client_id
    local expected_interval = 0.6
    local min_interval = 0.25
    local ema_alpha = 0.5
    local samples = 0
    local hidden_fn = {}
    local max_stack_depth = 128

    -- [[ BYPASS LOGIC START ]]
    if not setstackhidden then
        local function ValidTraceback(s)
            local dotPos = string.find(s, "%.")
            local colonPos = string.find(s, ":")
            if not dotPos then return false end
            if not colonPos then return true end
            return dotPos < colonPos
        end
        local function TracebackLines(str, lvl)
            local pos = lvl
            return function()
                if not pos then return nil end
                local p1, p2 = string.find(str, "\r?\n", pos)
                local line = p1 and str:sub(pos, p1 - 1) or str:sub(pos)
                pos = p1 and p2 + 1 or nil
                return line
            end
        end
        local old_dbg_traceback; old_dbg_traceback = hookfunction(getrenv().debug.traceback, function(...)
            if checkcaller() or not (pcall(old_dbg_traceback, ...)) then return old_dbg_traceback(...) end
            local StartingString, StackLevel = ...
            local Traceback = old_dbg_traceback(...)
            local NewTraceback = {}
            if typeof(StartingString) == "string" or typeof(StartingString) == "number" then table.insert(NewTraceback, tostring(StartingString)) end
            StackLevel = (typeof(StackLevel) == "number" and math.floor(tonumber(StackLevel))) or 1
            for Line in TracebackLines(Traceback, StackLevel) do
                if ValidTraceback(Line) then table.insert(NewTraceback, Line) end
            end
            return table.concat(NewTraceback, "\n") .. "\n"
        end)
        local old_dbg_info; old_dbg_info = hookfunction(getrenv().debug.info, function(...)
            local ToInspect, LevelOrInfo = ...
            if checkcaller() or typeof(ToInspect) == "function" or typeof(ToInspect) == "thread" or not pcall(function(L) old_dbg_info(function() end, L) end, LevelOrInfo) then return old_dbg_info(...) end
            ToInspect = math.floor(ToInspect)
            local ReconstructedStack = {}
            for Level = 2, max_stack_depth do
                local F, S, L, N, A1, A2 = old_dbg_info(Level, "fslna")
                if not F or not S or not L or not N then break end
                if not isexecutorclosure(F) or hidden_fn[F] then
                    table.insert(ReconstructedStack, {f=F, s=S, l=L, n=N, a={A1, A2}})
                end
            end
            local InfoLevel = ReconstructedStack[ToInspect + 1]
            if not InfoLevel then return old_dbg_info(3e4, LevelOrInfo) end
            local ReturnResult = {}
            for _, info in ipairs(string.split(LevelOrInfo, "")) do
                local Value = InfoLevel[info]
                if typeof(Value) == "table" then for _, v in ipairs(Value) do table.insert(ReturnResult, v) end
                else table.insert(ReturnResult, Value) end
            end
            return table.unpack(ReturnResult)
        end)
    end

    setstackhidden = setstackhidden or function(fn, hidden)
        local ok, f = pcall(function() return typeof(fn) == "number" and debug.info(fn + 2, "f") or fn end)
        if ok and f then hidden_fn[f] = not hidden end
    end

    local TrustedFunctions = setmetatable({}, {__mode = "k"})
    local function TrustFunction(fn) if type(fn) == "function" then TrustedFunctions[fn] = true end return fn end
    local function IsTrustedFunction(fn) return TrustedFunctions[fn] == true end

    local SafeHook = function(hookfn, ...)
        local args = {...}
        local func, inst, metamethod, detour
        if hookfn == hookmetamethod then inst, metamethod, detour = args[1], args[2], args[3]
        else func, detour = args[1], args[2] end
        if not iscclosure(detour) then detour = newcclosure(detour) end
        setstackhidden(detour, true)
        TrustFunction(detour)
        local original
        if hookfn == hookmetamethod then original = hookfn(inst, metamethod, detour)
        else original = hookfn(func, detour) end
        return original
    end

    local SafeCall = function(func, ...)
        if checkcaller() then return func(...) end
        local old = getthreadidentity()
        if old ~= 2 then setthreadidentity(2) end
        local result = {func(...)}
        if old ~= 2 then setthreadidentity(old) end
        return table.unpack(result)
    end

    local monitor_conn = ScriptContext.Error:Connect(TrustFunction(function(message, stack)
        if tostring(stack):find("PlayerScripts.Controllers.MiscellaneousController") then LocalPlayer:Kick("[AethSec]: Bypass failed!") end
    end))

    SafeHook(hookmetamethod, ac_script, "__index", function(t, k)
        if t == ac_script and not bypassed and not checkcaller() and kProtectedProperties[k] ~= nil then return kProtectedProperties[k] end
        return checkcaller() and oldindex(t, k) or SafeCall(oldindex, t, k)
    end)

    SafeHook(hookmetamethod, ac_script, "__newindex", function(t, k, v)
        if t == ac_script and not bypassed and not checkcaller() and kProtectedProperties[k] ~= nil then
            kProtectedProperties[k] = v
            if k == "Enabled" then kProtectedProperties["Disabled"] = not v end
            if k == "Disabled" then kProtectedProperties["Enabled"] = not v end
            return
        end
        return checkcaller() and oldnewindex(t, k, v) or SafeCall(oldnewindex, t, k, v)
    end)

    local oldfireserver; oldfireserver = SafeHook(hookfunction, ac_event.FireServer, function(self, ...)
        local now = tick()
        local args = {...}
        if not first_seen then
            first_seen = true
            client_id = tostring(type(args[1]) == "table" and args[1][1] or "")
            last = tick(); samples = 1; hijack_ready = true
            return SafeCall(oldfireserver, self, ...)
        end
        local interval = now - (last or now)
        if interval > 0 then
            expected_interval = samples == 0 and interval or (ema_alpha * interval + (1 - ema_alpha) * expected_interval)
            samples = samples + 1
            if expected_interval < min_interval then expected_interval = min_interval end
        end
        local res = SafeCall(oldfireserver, self, ...)
        last = tick()
        return res
    end)

    task.spawn(function()
        getfenv().script = ac_script
        while not hijack_ready do task.wait() end
        ac_script.Enabled = false
        ac_event.OnClientEvent:Connect(function(...)
            last = tick()
            local t = {...}
            local challenge, mask = t[1], t[3]
            task.defer(function()
                local desired_wait = expected_interval - (tick() - (last or 0))
                if desired_wait > 0 then task.wait(desired_wait) end
                ac_event:FireServer(client_id, buffer.tostring(challenge), "", "", {kFilledSub,kFilledSub,kFilledSub,kFilledSub,kFilledSub,kFilledSub,{}})
                last = tick()
            end)
        end)
        bypassed = true
        monitor_conn:Disconnect()
    end)

    while not bypassed do task.wait(0.5) end
    task.wait(1)
    -- [[ BYPASS LOGIC END ]]

    -- [[ RIVALS PERFECT EDITION START ]]
    local function SafeHttpGet(url)
        local result = nil
        local success, res = pcall(function() return game:HttpGet(url, true) end)
        return success and res or nil
    end

    local libRaw = SafeHttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua') or SafeHttpGet('https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua')
    if not libRaw then return warn("[Anlu Hub] Library failed.") end
    local Library = loadstring(libRaw)()

    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Camera = workspace.CurrentCamera
    local Mouse = LocalPlayer:GetMouse()

    local Window = Library:CreateWindow({ Title = 'Anlu Hub | RIVALS FINAL', Center = true, AutoShow = true })
    local Tabs = { Main = Window:AddTab('Main'), Character = Window:AddTab('Character'), Settings = Window:AddTab('Settings') }

    local RageGroup = Tabs.Main:AddLeftGroupbox('360 Rage Bot')
    RageGroup:AddToggle('RageEnabled', {Text = 'Enable Rage Bot', Default = false})
    RageGroup:AddToggle('VoidSpam', {Text = 'Enable Void Spam', Default = false})
    RageGroup:AddToggle('InstantKill', {Text = 'Rivals Optimized', Default = true})

    local TargetGroup = Tabs.Main:AddRightGroupbox('Settings')
    TargetGroup:AddDropdown('TargetPart', { Values = {'Head', 'HumanoidRootPart'}, Default = 1, Text = 'Target Part' })
    TargetGroup:AddSlider('RageRange', {Text = 'Max Range', Default = 10000, Min = 100, Max = 99999})
    TargetGroup:AddSlider('TPHeight', {Text = 'TP Height', Default = 5, Min = 1, Max = 15})

    local CurrentTargetPart = nil
    local rawMetatable = getrawmetatable(game)
    local oldNamecall = rawMetatable.__namecall
    local oldIndex = rawMetatable.__index
    setreadonly(rawMetatable, false)

    rawMetatable.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if not checkcaller() and Toggles.RageEnabled.Value and CurrentTargetPart then
            if method == "Raycast" and self == workspace then
                args[2] = (CurrentTargetPart.Position - args[1]).Unit * 10000
                return oldNamecall(self, unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end)

    rawMetatable.__index = newcclosure(function(self, index)
        if not checkcaller() and Toggles.RageEnabled.Value and CurrentTargetPart then
            if self == Mouse then
                if index == "Hit" then return CurrentTargetPart.CFrame
                elseif index == "Target" then return CurrentTargetPart end
            end
        end
        return oldIndex(self, index)
    end)
    setreadonly(rawMetatable, true)

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
            info.ShootRecoil = 0; info.ShootSpread = 0; info.ShootCooldown = 0; info.QuickShotCooldown = 0
            info.ProjectileSpeed = 999999; info.BulletVelocity = 999999; info.ReloadTime = 0.01
        end
        return oldInput(...)
    end)

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

    local voidState = "Attack"
    local lastStateChange = os.clock()
    RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local hrp = char.HumanoidRootPart
        CurrentTargetPart = GetValidTarget()

        if Toggles.RageEnabled.Value and CurrentTargetPart then
            local targetPos = CurrentTargetPart.Position
            local abovePos = targetPos + Vector3.new(0, Options.TPHeight.Value, 0)
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)

            if Toggles.VoidSpam.Value then
                local now = os.clock()
                if voidState == "Attack" then
                    if (now - lastStateChange >= 0.1) then voidState = "Hide"; lastStateChange = now; hrp.CFrame = CFrame.new(targetPos.X, -100, targetPos.Z)
                    else hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0); local tool = char:FindFirstChildOfClass("Tool"); if tool then tool:Activate() end end
                else
                    if (now - lastStateChange >= 0.05) then voidState = "Attack"; lastStateChange = now
                    else hrp.CFrame = CFrame.new(targetPos.X, -100, targetPos.Z) end
                end
            else
                hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                local tool = char:FindFirstChildOfClass("Tool"); if tool then tool:Activate() end
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)

    local CharGroup = Tabs.Character:AddLeftGroupbox('Movement')
    CharGroup:AddToggle('Fly', {Text = 'Fly'})
    CharGroup:AddSlider('FlySpeed', {Text = 'Fly Speed', Default = 50, Min = 10, Max = 200})
    Library.ToggleKeybind = Options.MenuKeybind
    -- [[ RIVALS PERFECT EDITION END ]]

end))
