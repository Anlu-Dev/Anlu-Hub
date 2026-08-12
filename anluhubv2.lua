--[[
    Bypass :shush: + Anlu Hub Integrated (Fixed Version)
]]

-- LPH_NO_VIRTUALIZE 에러 방지용 정의
if not LPH_NO_VIRTUALIZE then
    LPH_NO_VIRTUALIZE = function(f) return f end
end

pcall(LPH_NO_VIRTUALIZE(function()
    local bypassed = false

    local kKickNames = {
        "Kick",
        "kick"
    }

    local kProtectedProperties = {
        Enabled = true,
        Disabled = false
    }

    local kSlotMap = {
        [69]  = 2,
        [138] = 3,
        [207] = 4,
        [276] = 5,
        [345] = 6,
        [414] = 7,
    }

    local kFilledSub = {
        1,
        2,
        3,
        4,
        5
    }

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
    if not setstackhidden then
        local function ValidTraceback(s)
            local dotPos = string.find(s, "%.")
            local colonPos = string.find(s, ":")

            if not dotPos then
                return false
            end

            if not colonPos then
                return true
            end

            return dotPos < colonPos
        end

        local function TracebackLines(str, lvl)
            local pos = lvl
            return function()
                if not pos then
                    return nil
                end
                local p1, p2 = string.find(str, "\r?\n", pos)
                local line
                if p1 then
                    line = str:sub(pos, p1 - 1)
                    pos = p2 + 1
                else
                    line = str:sub(pos)
                    pos = nil
                end
                return line
            end
        end

        local old_dbg_traceback;
        old_dbg_traceback = hookfunction(getrenv().debug.traceback, function(...)
            if checkcaller() or not (pcall(old_dbg_traceback, ...)) then
                return old_dbg_traceback(...)
            end

            local StartingString, StackLevel = ...
            local Traceback = old_dbg_traceback(...)
            local NewTraceback = {}

            if typeof(StartingString) == "string" or typeof(StartingString) == "number" then
                table.insert(NewTraceback, tostring(StartingString))
            end

            if typeof(StackLevel) ~= "number" or not tonumber(StackLevel) then
                StackLevel = 1
            else
                StackLevel = math.floor(tonumber(StackLevel))
            end

            for Line in TracebackLines(Traceback, StackLevel) do
                if not ValidTraceback(Line) then
                    continue
                end

                table.insert(NewTraceback, Line)
            end

            return table.concat(NewTraceback, "\n") .. "\n"
        end)

        local old_dbg_info;
        old_dbg_info = hookfunction(getrenv().debug.info, function(...)
            local ToInspect, LevelOrInfo, _ThreadInfo = ...

            if
                checkcaller()
                or typeof(ToInspect) == "function"
                or typeof(ToInspect) == "thread"
                or not pcall(function(LevelOrInfo)
                    old_dbg_info(function() end, LevelOrInfo)
                end, LevelOrInfo)
            then
                return old_dbg_info(...)
            end

            ToInspect = math.floor(ToInspect)

            local ReconstructedConstructedStack = {}
            for Level = 2, max_stack_depth do
                local Function, Source, Line, Name, NumberOfArgs, Varargs = old_dbg_info(Level, "fslna")

                if not Function or not Source or not Line or not Name then
                    break
                end

                if isexecutorclosure(Function) and not hidden_fn[Function] then
                    continue
                end

                table.insert(ReconstructedConstructedStack, {
                    f = Function,
                    s = Source,
                    l = Line,
                    n = Name,
                    a = { NumberOfArgs, Varargs },
                })
            end

            local InfoLevel = ReconstructedConstructedStack[ToInspect + 1]

            if not InfoLevel then
                return old_dbg_info(3e4, LevelOrInfo)
            end

            local ReturnResult = {}
            for idx, info in string.split(LevelOrInfo, "") do
                local Value = InfoLevel[info]

                if typeof(Value) == "table" then
                    for _, v in Value do
                        table.insert(ReturnResult, v)
                    end

                    continue
                end

                table.insert(ReturnResult, Value)
            end

            return table.unpack(ReturnResult, 1, #ReturnResult)
        end)

        local old_getfenv;
        old_getfenv = hookfunction(getrenv().getfenv, function(...)
            if checkcaller() then
                return old_getfenv(...)
            end

            local ToInspect: (...any) -> (...any) | number = ...

            local Success, ResultingEnv = pcall(function()
                if typeof(ToInspect) == "number" and ToInspect >= 0 then
                    return old_getfenv(ToInspect + 3)
                end

                return old_getfenv(ToInspect)
            end)

            if not Success then
                if typeof(ToInspect) == "number" and ToInspect >= 0 then
                    return old_getfenv(ToInspect + 3)
                end

                return old_getfenv(ToInspect)
            end

            if ToInspect == nil or typeof(ToInspect) == "function" then
                return ResultingEnv
            end

            ToInspect = math.floor(ToInspect)

            local ReconstructedConstructedStack = {}
            for Level = 1, max_stack_depth do
                local StackInfoSuccess, Data = pcall(function()
                    return {
                        Environement = old_getfenv(Level + 3),
                        Function = old_dbg_info(Level + 3, "f"),
                    }
                end)

                if not StackInfoSuccess or not Data then
                    break
                end

                local Environement = Data.Environement
                local Function = Data.Function

                if typeof(Environement["getgenv"]) == "function" and isexecutorclosure(Environement["getgenv"]) then
                    if shared.Hooking.IncludeInStackFunctions[Function] then
                        Environement = setmetatable(ResultingEnv, {
                            __index = getrenv()
                        })
                    else
                        continue
                    end
                end

                table.insert(ReconstructedConstructedStack, Environement)
            end

            local InfoLevel = ReconstructedConstructedStack[ToInspect + 1]

            if not InfoLevel then
                return old_getfenv(3e4)
            end

            return InfoLevel
        end)
    end

    setstackhidden = setstackhidden or function(fn_or_level, hidden)
        assert(typeof(hidden) == "boolean", "hidden must be boolean")

        local ok, fn = pcall(function()
            if typeof(fn_or_level) == "number" then
                return debug.info(fn_or_level + 2, "f")
            end
            return fn_or_level
        end)

        assert(ok and fn, "invalid argument #1 to 'setstackhidden'")
        hidden_fn[fn] = not hidden
    end

    local TrustedFunctions = setmetatable({}, {
        __mode = "k"
    })

    local function TrustFunction(fn)
        if type(fn) == "function" then
            TrustedFunctions[fn] = true
        end

        return fn
    end

    local function IsTrustedFunction(fn)
        return TrustedFunctions[fn] == true
    end

    local SafeHook = function(hookfn, ...)
        local args = {...}
        local func, inst, metamethod, detour

        if hookfn == hookmetamethod then
            inst = args[1]
            metamethod = args[2]
            detour = args[3]
        else
            func = args[1]
            detour = args[2]
        end

        local original_func

        if hookfn == hookfunction and iscclosure(func) then
            detour = newcclosure(detour)
        end

        if not iscclosure(detour) then
            detour = newcclosure(detour)
        end

        setstackhidden(detour, true)

        local ok, _ = pcall(function()
            TrustFunction(detour)
                    
            if hookfn == hookmetamethod then
                original_func = hookfn(inst, metamethod, detour)
            else
                original_func = hookfn(func, detour)
            end
        end)

        if not ok then
            LocalPlayer:Kick("[AethSec]: Bypass failed! n1")
        end

        return original_func
    end

    local SafeCall = function(func, ...)
        if checkcaller() then
            return func(...)
        end

        local old = getthreadidentity()
        if old ~= 2 then
            setthreadidentity(2)
        end

        local result = {func(...)}

        if old ~= 2 then
            setthreadidentity(old)
        end

        return table.unpack(result)
    end

    local monitor_conn = ScriptContext.Error:Connect(TrustFunction(function(message, stack, _)
        message = tostring(message)
        stack = tostring(stack)
        if stack:find("PlayerScripts.Controllers.MiscellaneousController") and message:find("attempt to index number with number") then
            LocalPlayer:Kick("[AethSec]: Bypass failed! n2")
        end
    end))

    local oldindex; oldindex = SafeHook(hookmetamethod, ac_script, "__index", function(t, k)
        local is_caller = not bypassed and checkcaller()
        if t == ac_script and not is_caller and kProtectedProperties[k] ~= nil then
            return kProtectedProperties[k]
        end
        if checkcaller() then
            return oldindex(t, k)
        end
        return SafeCall(oldindex, t, k)
    end)

    local oldnewindex; oldnewindex = SafeHook(hookmetamethod, ac_script, "__newindex", function(t, k, v)
        local is_caller = not bypassed and checkcaller()
        if t == ac_script and not is_caller and kProtectedProperties[k] ~= nil then
            kProtectedProperties[k] = v
            if k == "Enabled" then
                kProtectedProperties["Disabled"] = not v
            end

            if k == "Disabled" then
                kProtectedProperties["Enabled"] = not v
            end
            return
        end
        if checkcaller() then
            return oldnewindex(t, k, v)
        end
        return SafeCall(oldnewindex, t, k, v)
    end)

    client_id = ""
    last = tick()

    local oldfireserver; oldfireserver = SafeHook(hookfunction, ac_event.FireServer, function(self, ...)
        local now = tick()
        local args = {...}

        if not first_seen then
            first_seen = true
            local first_arg = args[1]

            if type(first_arg) == "table" and #first_arg >= 1 and (type(first_arg[1]) == "string" or type(first_arg[1]) == "number") then
                client_id = tostring(first_arg[1])
            else
                client_id = client_id or ""
            end

            last = tick()
            samples = 1
            hijack_ready = true

            local res = SafeCall(oldfireserver, self, ...)
            return res
        end

        local interval = now - (last or now)

        if interval > 0 then
            if samples == 0 then
                expected_interval = interval
            else
                expected_interval = ema_alpha * interval + (1 - ema_alpha) * expected_interval
            end

            samples = samples + 1

            if expected_interval < min_interval then
                expected_interval = min_interval
            end
        end

        local res = SafeCall(oldfireserver, self, ...)
        last = tick()

        return res
    end)

    local BuildSubTable = function()
        local num_empty = math.random(1, 5)
        local empty_map = {}
        local empty_slots = {7}
        empty_map[7] = true

        while #empty_slots < num_empty do
            local slot = math.random(1, 6)
            if not empty_map[slot] then
                empty_map[slot] = true
                table.insert(empty_slots, slot)
            end
        end

        table.sort(empty_slots)

        local result = {}
        for i = 1, 7 do
            if empty_map[i] then
                result[i] = {}
            else
                result[i] = kFilledSub
            end
        end

        return result, empty_slots
    end

    local ApplyTransforms = function(t, mask, empty_slots)
        local payload = t[1]
        local outer_index = #payload
        local inner_index = empty_slots[math.random(1, #empty_slots)]
        local derived
        local outer_val = payload[outer_index]

        if type(outer_val) == "table" and type(inner_index) == "number" then
            derived = outer_val[inner_index]
        else
            for i = outer_index, 1, -1 do
                if type(payload[i]) ~= "table" then
                    continue
                end

                local candidate = payload[i]

                if type(inner_index) == "number" and candidate[inner_index] ~= nil then
                    derived = candidate[inner_index]
                    break
                end
            end
        end

        local function MapSlot(val)
            for k, v in pairs(kSlotMap) do
                if v == val then
                    return k
                end
            end
            return 0
        end

        t[2] = {
            [MapSlot(outer_index)] = MapSlot(inner_index)
        }
        
        return t
    end

    local BuildPayload = function(challenge, mask)
        local sub_table, empty_slots = BuildSubTable()
        local total_idx = math.random(1, 8)
        local payload = {client_id, buffer.tostring(challenge)}
        local extra_strings = math.random(0, 2)

        for _ = 1, extra_strings do
            payload[#payload + 1] = ""
        end

        while #payload < (total_idx - 1) do
            payload[#payload + 1] = math.random(5, 100000)
        end

        payload[#payload + 1] = sub_table

        local t = {
            payload,
            {},
            nil,
            nil,
            nil,
            nil,
            nil
        }
        return ApplyTransforms(t, mask, empty_slots)
    end

    task.spawn(function()
        getfenv().script = ac_script
        while not hijack_ready do
            task.wait()
        end

        ac_script.Enabled = false

        ac_event.OnClientEvent:Connect(function(...)
            last = tick()

            local remote = Instance.new("RemoteEvent", nil)
            remote:FireServer()

            local t = {...}
            local challenge = t[1]
            local index = t[2]
            local mask = t[3]

            if typeof(challenge) ~= "buffer" or type(index) ~= "number" or type(mask) ~= "table" then
                LocalPlayer:Kick("[AethSec]: Bypass failed! n3")
            end

            local payload = BuildPayload(challenge, mask)
            task.defer(function()
                local since_last = tick() - (last or 0)
                local desired_wait = expected_interval - since_last
                
                if desired_wait > 0 then
                    task.wait(desired_wait)
                end
                ac_event:FireServer(table.unpack(payload, 1, 5))
                last = tick()
                remote:Destroy()
            end)
        end)
            
        bypassed = true
        monitor_conn:Disconnect()
    end)

    for _, name in ipairs(kKickNames) do
        local func = LocalPlayer[name]
        if type(func) ~= "function" then continue end
            
        local oldfunc; oldfunc = SafeHook(hookfunction, func, function(self, ...)
            if self == LocalPlayer and not checkcaller() then
                return nil
            end
            return oldfunc(self, ...)
        end)
    end

    for _, conn in ipairs(getconnections(ScriptContext.Error)) do
        if not conn.Function then continue end
        if IsTrustedFunction(conn.Function) then continue end
        SafeHook(hookfunction, conn.Function, function(...)
            return nil
        end)
    end

    SafeHook(hookfunction, ScriptContext.Error.Connect, function(...)
        return nil
    end)

    while not bypassed do
        task.wait(0.5)
    end
    task.wait(1)

    -- [[ ANLU HUB START ]]
    -- 1. 라이브러리 불러오기
    local function SafeHttpGet(url)
        local result = nil
        local success = false
        local attempts = 0
        while not success and attempts < 3 do
            attempts = attempts + 1
            success, result = pcall(function()
                return game:HttpGet(url, true)
            end)
            if not success then task.wait(1) end
        end
        return result
    end

    local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
    local libRaw = SafeHttpGet(repo .. 'Library.lua')

    if not libRaw or libRaw == "" then
        libRaw = SafeHttpGet('https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua')
    end

    if not libRaw or libRaw == "" then
        return warn("[Eclipse Core] 라이브러리 불러오기 실패 (타임아웃).")
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
        if Toggles.RageEnabled and Toggles.RageEnabled.Value and type(args[1]) == "table" and args[1].Info then
            local gunName = args[1].Name or "Default"
            local info = args[1].Info
            if not OriginalStats[gunName] then
                OriginalStats[gunName] = {
                    Recoil = info.ShootRecoil,
                    Spread = info.ShootSpread,
                    CD = info.ShootCooldown,
                    QCD = info.QuickShotCooldown
                }
            end
            info.ShootRecoil = 0
            info.ShootSpread = 0
            info.ShootCooldown = 0
            info.QuickShotCooldown = 0
            info.ProjectileSpeed = 99999
            info.BulletVelocity = 99999
        elseif OriginalStats and type(args[1]) == "table" and args[1].Info then
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
        if Library.Toggled then return false end
        if Library.ScreenGui and Library.ScreenGui.Enabled then return false end
        if UserInputService:GetFocusedTextBox() ~= nil then return false end
        if Toggles.DisableUnlockedCursor and Toggles.DisableUnlockedCursor.Value then
            if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then return false end
        end
        if Toggles.Disable3rdPerson and Toggles.Disable3rdPerson.Value then
            local char = LocalPlayer.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    local camDist = (Camera.CFrame.Position - head.Position).Magnitude
                    if camDist > 2.2 then return false end
                end
            end
            if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then return false end
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
            if LocalPlayer.Team ~= nil and player.Team ~= nil then return player.Team == LocalPlayer.Team end
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
                if index == "Hit" then return CurrentTargetPart.CFrame
                elseif index == "Target" then return CurrentTargetPart end
            end
        end
        return oldIndex(self, index)
    end)
    setreadonly(rawMetatable, true)

    -- 7. 초고속 자동 발사
    local lastShootTime = 0
    local function BuffedAutoShoot(targetPart, forceShoot)
        if not CanAutoShoot() then return end
        local now = os.clock()
        if not forceShoot and (now - lastShootTime < 0.03) then return end
        lastShootTime = now
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool and hum then
            local backpackTool = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
            if backpackTool then hum:EquipTool(backpackTool) tool = backpackTool end
        end
        if tool then tool:Activate() end
        pcall(function() if mouse1press then mouse1press() mouse1release() end end)
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

    -- 8. 메인 프레임 루프
    local voidState = "Attack"
    local lastStateChange = os.clock()
    RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then TargetStatusLabel:SetText('Target Status: None') return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then TargetStatusLabel:SetText('Target Status: None') return end

        CurrentTargetPart, CurrentTargetPlayer = GetValidTarget()
        if CurrentTargetPlayer then TargetStatusLabel:SetText('Target Status: ' .. CurrentTargetPlayer.Name)
        else TargetStatusLabel:SetText('Target Status: None') end

        if Toggles.RageEnabled.Value and CurrentTargetPart then
            local targetPos = CurrentTargetPart.Position
            local height = Options.TPHeight.Value
            local abovePos = targetPos + Vector3.new(0, height, 0)
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
            if Toggles.VoidSpam.Value then
                local now = os.clock()
                local hideTime = Options.HideTime.Value
                local attackTime = Options.AttackTime.Value
                if voidState == "Attack" then
                    if (now - lastStateChange >= attackTime) then
                        voidState = "Hide" lastStateChange = now hrp.CFrame = CFrame.new(0, -500, 0)
                    else
                        hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                        BuffedAutoShoot(CurrentTargetPart, true)
                    end
                elseif voidState == "Hide" then
                    if (now - lastStateChange >= hideTime) then
                        voidState = "Attack" lastStateChange = now
                        hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                        BuffedAutoShoot(CurrentTargetPart, true)
                    else hrp.CFrame = CFrame.new(0, -500, 0) end
                end
            else
                hrp.CFrame = CFrame.lookAt(abovePos, targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
                BuffedAutoShoot(CurrentTargetPart, false)
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

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
            if moveDir.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (moveDir.Unit * speed * RunService.Heartbeat:Wait()) end
        end
        if Toggles.SpeedEnabled.Value and not isRageActive then
            local multiplier = Options.WalkSpeed.Value
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * multiplier * 0.5)
        end
        if Toggles.JumpEnabled.Value then
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
        if Toggles.SlideBoost.Value and hum.FloorMaterial ~= Enum.Material.Air then
            if hum.MoveDirection.Magnitude > 0 and UserInputService:IsKeyDown(Enum.KeyCode.C) then
                hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + (hum.MoveDirection * Options.BoostForce.Value)
            end
        end
        if Toggles.AAEnabled.Value and not isRageActive then
            local yawMode = Options.YawMode.Value
            local yawLimit = Options.YawAngle.Value
            local yawSpeed = Options.YawSpeed.Value
            local pitchMode = Options.PitchMode.Value
            local pitchAngle = Options.PitchAngle.Value
            local finalYaw = 0
            if yawMode == 'Static' then finalYaw = math.rad(yawLimit)
            elseif yawMode == 'Jitter' then finalYaw = math.rad(math.random(-yawLimit, yawLimit))
            elseif yawMode == 'Random' then finalYaw = math.rad(math.random(-180, 180))
            elseif yawMode == 'Spin' then finalYaw = math.rad((tick() * yawSpeed * 100) % 360) end
            local finalPitch = 0
            if pitchMode == 'Static' then finalPitch = math.rad(pitchAngle)
            elseif pitchMode == 'Up' then finalPitch = math.rad(-89)
            elseif pitchMode == 'Down' then finalPitch = math.rad(89)
            elseif pitchMode == 'Random' then finalPitch = math.rad(math.random(-89, 89)) end
            if Cache.waist then Cache.waist.C0 = CFrame.new(0, 0.85, 0) * CFrame.Angles(finalPitch, finalYaw, 0) end
            if Cache.rootJoint then Cache.rootJoint.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(-180) + finalYaw) end
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
    MiscGroup:AddButton('Rejoin', function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)

    -- [Settings 탭]
    local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
    MenuGroup:AddLabel('Menu Keybind'):AddKeybind('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu Keybind' })
    Library.ToggleKeybind = Options.MenuKeybind
    -- [[ ANLU HUB END ]]
end))
