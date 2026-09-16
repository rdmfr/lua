--[[
    ============================================================
    GAME CHANGER - v6.0 (GAME-ADAPTIVE EDITION)
    ============================================================
    Fitur:
      - Auto-detect game → tampilkan fitur sesuai
      - Universal: Fly, Infinite Jump, Speed, Aimbot, Wallhack
      - Steal An Egg: Auto Steal, Speed Boost, Guardian Skip
      - Blox Fruits: Auto Farm, Auto Quest (placeholder)
      - Arsenal: Aimbot, ESP
    ============================================================
--]]

if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- Override gethui
if gethui then
    local _oldGethui = gethui
    gethui = function()
        local ok, result = pcall(_oldGethui)
        if not ok or not result or result == game then
            return CoreGui
        end
        return result
    end
end

-- ============================================================
-- [1] LOAD RAYFIELD
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then
    warn("[ERROR]: Failed to load Rayfield.")
    return
end
task.wait(1)

-- ============================================================
-- [2] GAME PROFILES DATABASE
-- ============================================================
local GAME_PROFILES = {
    -- Steal An Egg (game kamu)
    [76377501906469] = {  -- PlaceId, sesuaikan dengan game kamu
        Name = "Steal An Egg",
        Key = "StealAnEgg",
        Type = "RPG",
        Features = {"AutoStealEgg", "SpeedBoost", "GuardianSkip", "AutoReturnBase"},
    },
    -- Blox Fruits
    [2753915549] = { Name = "Blox Fruits", Key = "BloxFruits", Type = "RPG" },
    [4442272183] = { Name = "Blox Fruits", Key = "BloxFruits", Type = "RPG" },
    [7449423635] = { Name = "Blox Fruits", Key = "BloxFruits", Type = "RPG" },
    -- FPS Games
    [286090429]  = { Name = "Arsenal",     Key = "Arsenal",    Type = "FPS" },
    [5938036553] = { Name = "Da Hood",     Key = "DaHood",     Type = "FPS" },
    [142823291]  = { Name = "Murder Mystery 2", Key = "MM2",   Type = "FPS" },
    -- Other
    [6516141723] = { Name = "Doors",       Key = "Doors",      Type = "RPG" },
    [920587237]  = { Name = "Adopt Me",    Key = "AdoptMe",    Type = "RPG" },
    [6284583030] = { Name = "Pet Simulator X", Key = "PetSimX", Type = "MMO" },
}

local GameInfo = {
    PlaceId = game.PlaceId,
    Name = "Unknown Game",
    Key = "Generic",
    Type = "Generic",
}

local detected = GAME_PROFILES[game.PlaceId]
if detected then
    GameInfo.Name = detected.Name
    GameInfo.Key = detected.Key
    GameInfo.Type = detected.Type
else
    pcall(function()
        local MS = game:GetService("MarketplaceService")
        local info = MS:GetProductInfo(game.PlaceId, Enum.InfoType.Asset)
        if info and info.Name then GameInfo.Name = info.Name end
    end)
end

-- Fallback: cek nama game untuk Steal An Egg
if GameInfo.Key == "Generic" then
    local lowerName = GameInfo.Name:lower()
    if lowerName:find("steal") and lowerName:find("egg") then
        GameInfo.Key = "StealAnEgg"
        GameInfo.Type = "RPG"
    elseif lowerName:find("telur") then
        GameInfo.Key = "StealAnEgg"
        GameInfo.Type = "RPG"
    elseif lowerName:find("blox") and lowerName:find("fruit") then
        GameInfo.Key = "BloxFruits"
    elseif lowerName:find("arsenal") then
        GameInfo.Key = "Arsenal"
    end
end

print(string.format("[GC] Game: %s | Key: %s | Type: %s | PlaceId: %d",
    GameInfo.Name, GameInfo.Key, GameInfo.Type, GameInfo.PlaceId))

-- ============================================================
-- [3] STATE MANAGEMENT
-- ============================================================
local State = {
    -- Universal
    Fly = false,
    FlySpeed = 100,
    InfiniteJump = false,
    WalkSpeed = 16,
    JumpPower = 50,
    SpeedBoost = 50,           -- FIX: tanpa treadmill
    Wallhack = false,
    Aimbot = false,
    AimbotFOV = 100,
    AimbotSmoothness = 0.15,
    AutoAttack = false,
    -- Steal An Egg
    AutoStealEgg = false,
    EggScanRadius = 800,
    ReturnSpeed = 800,
    SelectedEggs = {},
    BasePosition = nil,
    AutoReturnBase = true,
    AvoidGuardians = false,     -- default OFF (semua egg ada guardian)
    -- Internal
    IsStealing = false,
    Connections = {},
}

local Connections = State.Connections
local function addConn(key, conn)
    if Connections[key] then Connections[key]:Disconnect() end
    Connections[key] = conn
end
local function removeConn(key)
    if Connections[key] then
        Connections[key]:Disconnect()
        Connections[key] = nil
    end
end

-- ============================================================
-- [4] NOTIFY
-- ============================================================
local function notify_safe(title, content, type_)
    if Rayfield and Rayfield.Notify then
        Rayfield:Notify({
            Title = "[" .. string.upper(type_ or "info") .. "] " .. title,
            Content = content,
            Duration = 4,
        })
    else
        warn("[" .. title .. "] " .. content)
    end
end
local function notify(t, c) notify_safe(t, c, "info") end
local function notifySuccess(t, c) notify_safe(t, c, "success") end
local function notifyWarn(t, c) notify_safe(t, c, "warn") end
local function notifyError(t, c) notify_safe(t, c, "error") end

-- ============================================================
-- [5] WINDOW
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "🎮 Game Changer v6.0",
    Icon = 0,
    LoadingTitle = "Game Changer",
    LoadingSubtitle = "Adaptive Edition",
    Theme = "DarkBlue",
    ToggleUIKeybind = Enum.KeyCode.RightShift,
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "GameChanger",
        FileName = "Config",
    },
    Discord = { Enabled = false },
})

task.spawn(function()
    task.wait(1)
    pcall(function() Window:Show() end)
end)

-- ============================================================
-- [6] TAB: HOME
-- ============================================================
local HomeTab = Window:CreateTab("🏠 Home", 4483362458)
HomeTab:CreateSection("📊 Game Information")

HomeTab:CreateParagraph({
    Title = "🎮 " .. GameInfo.Name,
    Content = "PlaceId: " .. GameInfo.PlaceId .. "\nProfile: " .. GameInfo.Key,
})

HomeTab:CreateSection("⚡ Quick Actions")

HomeTab:CreateButton({
    Name = "🔄 Refresh UI (re-detect game)",
    Callback = function()
        notify("Info", "Restart script untuk re-detect game")
    end,
})

-- ============================================================
-- [7] TAB: MOVEMENT (Universal - selalu ada)
-- ============================================================
local MoveTab = Window:CreateTab("🏃 Movement", 4483362458)
MoveTab:CreateSection("🏃 Character")

MoveTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 500}, Increment = 1, Suffix = " studs",
    CurrentValue = 16, Flag = "MV_WalkSpeed",
    Callback = function(v)
        State.WalkSpeed = v
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})

MoveTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 500}, Increment = 1, Suffix = " studs",
    CurrentValue = 50, Flag = "MV_JumpPower",
    Callback = function(v)
        State.JumpPower = v
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v end
    end,
})

MoveTab:CreateSection("✈️ Fly")

MoveTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false, Flag = "MV_Fly",
    Callback = function(v) State.Fly = v end,
})

MoveTab:CreateSlider({
    Name = "Fly Speed",
    Range = {50, 1000}, Increment = 10, Suffix = " studs/s",
    CurrentValue = 100, Flag = "MV_FlySpeed",
    Callback = function(v) State.FlySpeed = v end,
})

MoveTab:CreateSection("🦘 Jump")

MoveTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false, Flag = "MV_InfiniteJump",
    Callback = function(v) State.InfiniteJump = v end,
})

MoveTab:CreateSection("⚡ Speed Boost (tanpa treadmill)")

MoveTab:CreateToggle({
    Name = "🚀 Speed Boost (ON/OFF)",
    CurrentValue = false, Flag = "MV_SpeedBoost",
    Callback = function(v)
        State.SpeedBoostEnabled = v
        if v then
            -- Set speed ke nilai boost
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = State.SpeedBoost
                hum.JumpPower = State.JumpPower
            end
            notifySuccess("Speed Boost", "Speed: " .. State.SpeedBoost)
        else
            -- Balik ke default
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
            notifyWarn("Speed Boost", "OFF")
        end
    end,
})

MoveTab:CreateSlider({
    Name = "Speed Boost Value",
    Range = {50, 1000}, Increment = 10, Suffix = " studs",
    CurrentValue = 50, Flag = "MV_SpeedBoostValue",
    Callback = function(v)
        State.SpeedBoost = v
        if State.SpeedBoostEnabled then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = v end
        end
    end,
})

-- ============================================================
-- [8] TAB: COMBAT (Universal)
-- ============================================================
local CombatTab = Window:CreateTab("⚔️ Combat", 4483362458)
CombatTab:CreateSection("🎯 Aim Assist")

CombatTab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false, Flag = "CB_Aimbot",
    Callback = function(v) State.Aimbot = v end,
})

CombatTab:CreateSlider({
    Name = "Aimbot FOV",
    Range = {10, 500}, Increment = 5, Suffix = " px",
    CurrentValue = 100, Flag = "CB_AimbotFOV",
    Callback = function(v) State.AimbotFOV = v end,
})

CombatTab:CreateSlider({
    Name = "Aimbot Smoothness",
    Range = {1, 100}, Increment = 1, Suffix = " %",
    CurrentValue = 15, Flag = "CB_AimbotSmooth",
    Callback = function(v) State.AimbotSmoothness = v / 100 end,
})

CombatTab:CreateSection("👁️ Visual")

CombatTab:CreateToggle({
    Name = "Wallhack (Highlight Players)",
    CurrentValue = false, Flag = "CB_Wallhack",
    Callback = function(v) State.Wallhack = v end,
})

CombatTab:CreateToggle({
    Name = "Auto Attack",
    CurrentValue = false, Flag = "CB_AutoAttack",
    Callback = function(v) State.AutoAttack = v end,
})

-- ============================================================
-- [9] TAB: GAME-SPECIFIC (Steal An Egg)
-- ============================================================
if GameInfo.Key == "StealAnEgg" or GameInfo.Type == "RPG" then
    local EggTab = Window:CreateTab("🥚 Steal Egg", 4483362458)
    
    EggTab:CreateSection("⚙️ Settings")
    
    EggTab:CreateSlider({
        Name = "Egg Scan Radius",
        Range = {100, 3000}, Increment = 100, Suffix = " studs",
        CurrentValue = 800, Flag = "SE_Radius",
        Callback = function(v) State.EggScanRadius = v end,
    })
    
    EggTab:CreateSlider({
        Name = "Return Speed",
        Range = {100, 2000}, Increment = 50, Suffix = " studs/s",
        CurrentValue = 800, Flag = "SE_ReturnSpeed",
        Callback = function(v) State.ReturnSpeed = v end,
    })
    
    EggTab:CreateToggle({
        Name = "Auto Return to Base",
        CurrentValue = true, Flag = "SE_AutoReturn",
        Callback = function(v) State.AutoReturnBase = v end,
    })
    
    EggTab:CreateToggle({
        Name = "Skip Eggs with Guardian",
        CurrentValue = false, Flag = "SE_SkipGuard",
        Callback = function(v) State.AvoidGuardians = v end,
    })
    
    EggTab:CreateSection("🥚 Detected Eggs")
    
    local EggStatusPara = EggTab:CreateParagraph({
        Title = "Status",
        Content = "Klik 'Scan Eggs' untuk detect.",
    })
    
    local EggToggles = {}
    
    local function rebuildEggToggles()
        scanEggs()
        
        local unique = {}
        for _, info in pairs(DetectedEggs) do
            local n = info.Name
            if not unique[n] then unique[n] = { Count = 0, MinDist = math.huge } end
            unique[n].Count = unique[n].Count + 1
            if info.Distance < unique[n].MinDist then unique[n].MinDist = info.Distance end
        end
        
        local count = 0
        for name, data in pairs(unique) do
            count = count + 1
            if not EggToggles[name] then
                local captured = name
                local toggle = EggTab:CreateToggle({
                    Name = "🥚 " .. name .. " (" .. data.Count .. "x, " .. data.MinDist .. " studs)",
                    CurrentValue = true, Flag = "SE_Egg_" .. name,
                    Callback = function(v) State.SelectedEggs[captured] = v end,
                })
                EggToggles[name] = toggle
                State.SelectedEggs[name] = true
            end
        end
        
        pcall(function()
            EggStatusPara:Set(
                "🎯 " .. count .. " jenis telur terdeteksi",
                "Radius: " .. State.EggScanRadius .. " studs"
            )
        end)
        return count
    end
    
    EggTab:CreateButton({
        Name = "🔄 Scan Eggs",
        Callback = function()
            local c = rebuildEggToggles()
            notify("Steal Egg", c .. " jenis telur terdeteksi")
        end,
    })
    
    EggTab:CreateSection("▶️ Auto Steal")
    
    EggTab:CreateToggle({
        Name = "🚀 Auto Steal Egg (ON/OFF)",
        CurrentValue = false, Flag = "SE_Enabled",
        Callback = function(v)
            State.AutoStealEgg = v
            if v then
                if not State.BasePosition then
                    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if root then State.BasePosition = root.CFrame end
                end
                notifySuccess("Steal Egg", "Auto Steal ON")
                runAutoSteal()
            else
                notifyWarn("Steal Egg", "OFF")
            end
        end,
    })
    
    EggTab:CreateButton({
        Name = "🎯 Steal Selected Now",
        Callback = function()
            scanEggs()
            local targets = {}
            for _, info in pairs(DetectedEggs) do
                if State.SelectedEggs[info.Name] then table.insert(targets, info) end
            end
            if #targets == 0 then
                notifyWarn("Steal Egg", "Tidak ada telur dipilih")
                return
            end
            task.spawn(function()
                table.sort(targets, function(a,b) return a.Distance < b.Distance end)
                for _, info in ipairs(targets) do
                    if State.SelectedEggs[info.Name] then stealEgg(info) end
                end
                returnToBase()
                notifySuccess("Steal Egg", #targets .. " telur di-steal!")
            end)
        end,
    })
    
    EggTab:CreateButton({
        Name = "📍 Set Base Position (Current)",
        Callback = function()
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                State.BasePosition = root.CFrame
                notifySuccess("Base", "Base diset!")
            end
        end,
    })
    
    EggTab:CreateButton({
        Name = "✅ Select All",
        Callback = function()
            for name, toggle in pairs(EggToggles) do
                State.SelectedEggs[name] = true
                pcall(function() toggle:Set(true) end)
            end
        end,
    })
end

-- ============================================================
-- [10] TAB: MISC (Universal)
-- ============================================================
local MiscTab = Window:CreateTab("⚙️ Misc", 4483362458)

MiscTab:CreateSection("🛠️ Utility")

MiscTab:CreateButton({
    Name = "🔄 Reset Character",
    Callback = function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end,
})

MiscTab:CreateButton({
    Name = "💥 Destroy UI",
    Callback = function()
        pcall(function() Rayfield:Destroy() end)
    end,
})

-- ============================================================
-- [11] UNIVERSAL LOGIC (background - Fly, Infinite Jump, dll)
-- ============================================================

-- Speed Boost: auto-apply setiap respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if State.SpeedBoostEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = State.SpeedBoost
            hum.JumpPower = State.JumpPower
        end
    end
end)

-- Wallhack
task.spawn(function()
    while task.wait(1) do
        if State.Wallhack then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    if not plr.Character:FindFirstChild("GC_HL") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "GC_HL"
                        hl.FillColor = Color3.fromRGB(255, 50, 50)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.5
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = plr.Character
                    end
                end
            end
        else
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character and plr.Character:FindFirstChild("GC_HL") then
                    plr.Character.GC_HL:Destroy()
                end
            end
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Aimbot
RunService.RenderStepped:Connect(function()
    if not State.Aimbot then return end
    local closest, shortest = nil, State.AimbotFOV
    local mouse = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local sp, on = Camera:WorldToViewportPoint(head.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                    if d < shortest then shortest = d; closest = head end
                end
            end
        end
    end
    if closest then
        Camera.CFrame = Camera.CFrame:Lerp(
            CFrame.new(Camera.CFrame.Position, closest.Position),
            State.AimbotSmoothness
        )
    end
end)

-- Auto Attack
RunService.Heartbeat:Connect(function()
    if not State.AutoAttack then return end
    local char = LocalPlayer.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then pcall(function() tool:Activate() end) end
    end
end)

-- Fly
local flyVel, flyGyro
local KeyState = {}
UserInputService.InputBegan:Connect(function(i, p)
    if not p and i.UserInputType == Enum.UserInputType.Keyboard then
        KeyState[i.KeyCode] = true
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Keyboard then
        KeyState[i.KeyCode] = false
    end
end)

RunService.RenderStepped:Connect(function()
    if State.Fly then
        if not flyVel then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                flyVel = Instance.new("BodyVelocity")
                flyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                flyVel.Velocity = Vector3.zero
                flyVel.Parent = root
                flyGyro = Instance.new("BodyGyro")
                flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
                flyGyro.P = 1000
                flyGyro.Parent = root
            end
        end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and flyVel then
            local move = Vector3.zero
            if KeyState[Enum.KeyCode.W] then move += Camera.CFrame.LookVector end
            if KeyState[Enum.KeyCode.S] then move -= Camera.CFrame.LookVector end
            if KeyState[Enum.KeyCode.A] then move -= Camera.CFrame.RightVector end
            if KeyState[Enum.KeyCode.D] then move += Camera.CFrame.RightVector end
            if KeyState[Enum.KeyCode.Space] then move += Vector3.new(0, 1, 0) end
            if KeyState[Enum.KeyCode.LeftControl] then move -= Vector3.new(0, 1, 0) end
            flyVel.Velocity = move * State.FlySpeed
            flyGyro.CFrame = Camera.CFrame
        end
    else
        if flyVel then flyVel:Destroy() flyVel = nil end
        if flyGyro then flyGyro:Destroy() flyGyro = nil end
    end
end)

-- ============================================================
-- [12] STEAL AN EGG LOGIC
-- ============================================================
local DetectedEggs = {}

local function getItemPosition(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if pp then return pp.Position end
    end
    return nil
end

local function isEgg(obj)
    local n = obj.Name:lower()
    return n:find("egg") or n:find("telur")
end

local function hasGuardianNear(pos, radius)
    radius = radius or 60
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                if (hrp.Position - pos).Magnitude < radius then
                    return true
                end
            end
        end
    end
    return false
end

function scanEggs()
    DetectedEggs = {}
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local myPos = root.Position
    for _, obj in ipairs(workspace:GetChildren()) do
        if isEgg(obj) then
            local pos = getItemPosition(obj)
            if pos and (pos - myPos).Magnitude <= State.EggScanRadius then
                DetectedEggs[obj] = {
                    Instance = obj,
                    Name = obj.Name,
                    Distance = math.floor((pos - myPos).Magnitude),
                    Position = pos,
                }
            end
        end
    end
end

function stealEgg(info)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local obj = info.Instance
    if not obj or not obj.Parent then return end
    
    if not State.BasePosition then State.BasePosition = root.CFrame end
    
    -- Teleport ke egg
    root.CFrame = CFrame.new(info.Position + Vector3.new(0, 3, 0))
    task.wait(0.1)
    
    -- Pickup
    pcall(function()
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then fireproximityprompt(prompt) end
        
        local cd = obj:FindFirstChildWhichIsA("ClickDetector", true)
        if cd then fireclickdetector(cd) end
        
        if obj:IsA("BasePart") then
            local ti = obj:FindFirstChild("TouchInterest")
            if ti and firetouchinterest then
                firetouchinterest(root, obj, 0)
                task.wait(0.05)
                firetouchinterest(root, obj, 1)
            end
        end
    end)
    
    task.wait(0.1)
end

function returnToBase()
    if not State.AutoReturnBase or not State.BasePosition then return end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = State.BasePosition
        task.wait(0.15)
    end
end

function runAutoSteal()
    if State.IsStealing then return end
    State.IsStealing = true
    task.spawn(function()
        while State.AutoStealEgg do
            scanEggs()
            local targets = {}
            for _, info in pairs(DetectedEggs) do
                if State.SelectedEggs[info.Name] then
                    if not State.AvoidGuardians or not hasGuardianNear(info.Position, 60) then
                        table.insert(targets, info)
                    end
                end
            end
            if #targets > 0 then
                table.sort(targets, function(a,b) return a.Distance < b.Distance end)
                stealEgg(targets[1])
                returnToBase()
            end
            task.wait(0.3)
        end
        State.IsStealing = false
    end)
end

-- ============================================================
-- [13] INIT
-- ============================================================
notify_safe("Game Changer v6.0",
    "Game: " .. GameInfo.Name .. " | Profile: " .. GameInfo.Key,
    "success")