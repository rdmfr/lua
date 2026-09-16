--[[
    ============================================================
    GAME CHANGER - v4.1 (FIXED UI)
    ============================================================
    Fitur:
      - Universal Anti-Cheat Bypass (opsional)
      - Auto-Detect Game + Preset Profiles
      - Smart Notify (suara + warna)
      - FPS Counter + Ping Overlay
      - Keybind Manager + Panic Key
      - FPS: Wallhack, Infinite Jump, Aimbot
      - RPG: Auto Attack, Auto Loot
      - MMO: Auto Farm, Teleport
      - Misc: WalkSpeed, JumpPower, Fly, Reset
    ============================================================
--]]

if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local SoundService     = game:GetService("SoundService")
local CoreGui          = game:GetService("CoreGui")
local PlayersService   = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- Paksa gethui return CoreGui (biar Rayfield ke-render)
if gethui then
    local _oldGethui = gethui
    gethui = function()
        local ok, result = pcall(_oldGethui)
        if not ok or not result or result == game then
            return CoreGui
        end
        return result
    end
    print("[GC] gethui di-override ke CoreGui")
end
-- ============================================================
-- [1] LOAD BYPASS (HARUS PALING AWAL)
-- ============================================================
local bypass = nil
local BYPASS_URL = "" -- ← ISI URL raw universalbypass.lua kamu di sini

local function loadBypass()
    if BYPASS_URL ~= "" then
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(BYPASS_URL))()
        end)
        if ok and result then return result end
        warn("[Bypass] Gagal load dari URL: " .. tostring(result))
    end

    local ok, result = pcall(function()
        if readfile and isfile and isfile("Bypass/universalbypass.lua") then
            return loadstring(readfile("Bypass/universalbypass.lua"))()
        end
        return nil
    end)
    if ok and result then return result end

    return nil
end

bypass = loadBypass()

if bypass then
    pcall(function()
        bypass.enable()
    end)
    print("[Game Changer] Bypass aktif.")
else
    warn("[Game Changer] Bypass tidak ditemukan. Script tetap jalan tanpa proteksi.")
end

-- ============================================================
-- SAFE INPUT HELPERS
-- ============================================================
local function safeInput(inputType, isPressed)
    if bypass and bypass.simulateInput then
        bypass.simulateInput(inputType, isPressed)
    else
        local VIM = game:GetService("VirtualInputManager")
        if typeof(inputType) == "EnumItem" and inputType.EnumType == Enum.KeyCode then
            VIM:SendKeyEvent(isPressed, inputType, false, game)
        elseif typeof(inputType) == "EnumItem" and inputType.EnumType == Enum.UserInputType then
            if inputType == Enum.UserInputType.MouseButton1 then
                VIM:SendMouseButtonEvent(0, 0, 0, isPressed, game, 0)
            end
        end
    end
end

local function safeJump()
    safeInput(Enum.KeyCode.Space, true)
    task.wait(0.05)
    safeInput(Enum.KeyCode.Space, false)
end

local KeyState = {}
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        KeyState[input.KeyCode] = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        KeyState[input.KeyCode] = false
    end
end)

local function isKeyDown(keycode)
    return KeyState[keycode] == true
end


-- ============================================================
-- [2] LOAD RAYFIELD (FIXED LOADING)
-- ============================================================
local Rayfield
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not Rayfield then
    warn("[ERROR]: Failed to load Rayfield.")
    return
end

-- Tunggu sebentar setelah Rayfield load agar UI siap
task.wait(3) 

-- ============================================================
-- [3] STATE MANAGEMENT
-- ============================================================
local State = {
    Wallhack = false,
    InfiniteJump = false,
    Aimbot = false,
    AimbotFOV = 100,
    AimbotSmoothness = 0.15,
    AutoAttack = false,
    AutoLoot = false,
    AutoFarm = false,
    Teleport = false,
    TeleportTarget = "",
    WalkSpeed = 16,
    JumpPower = 50,
    Fly = false,
    FlySpeed = 50,
}

local Connections = {}
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
-- [A] AUTO-DETECT GAME
-- ============================================================
local KNOWN_GAMES = {
    [2753915549] = { Name = "Blox Fruits", Preset = "RPG" },
    [4442272183] = { Name = "Blox Fruits", Preset = "RPG" },
    [7449423635] = { Name = "Blox Fruits", Preset = "RPG" },
    [286090429]  = { Name = "Arsenal",     Preset = "FPS" },
    [5938036553] = { Name = "Da Hood",     Preset = "FPS" },
    [2788229376] = { Name = "Da Hood",     Preset = "FPS" },
    [6516141723] = { Name = "Doors",       Preset = "RPG" },
    [155615604]  = { Name = "Prison Life", Preset = "FPS" },
    [142823291]  = { Name = "Murder Mystery 2", Preset = "FPS" },
    [1962086868] = { Name = "Tower of Hell", Preset = "MMO" },
    [920587237]  = { Name = "Adopt Me",    Preset = "RPG" },
    [6284583030] = { Name = "Pet Simulator X", Preset = "MMO" },
    [8737899170] = { Name = "Pet Simulator 99", Preset = "MMO" },
}

local GameInfo = {
    PlaceId = game.PlaceId,
    JobId   = game.JobId,
    Name    = "Unknown Game",
    Preset  = "None",
}

local detected = KNOWN_GAMES[game.PlaceId]
if detected then
    GameInfo.Name   = detected.Name
    GameInfo.Preset = detected.Preset
else
    pcall(function()
        local MarketplaceService = game:GetService("MarketplaceService")
        local info = MarketplaceService:GetProductInfo(game.PlaceId, Enum.InfoType.Asset)
        if info and info.Name then
            GameInfo.Name = info.Name
        end
    end)
end

print(string.format("[Game Changer] Game: %s | PlaceId: %d | Preset: %s",
    GameInfo.Name, GameInfo.PlaceId, GameInfo.Preset))

-- ============================================================
-- [C] SMART NOTIFY SYSTEM
-- ============================================================
local NOTIFY_SOUNDS = {
    info    = "rbxassetid://6895079853",
    warn    = "rbxassetid://6895079853",
    success = "rbxassetid://6895079853",
    error   = "rbxassetid://6895079853",
}

local function playNotifySound(type_)
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = NOTIFY_SOUNDS[type_] or NOTIFY_SOUNDS.info
        s.Volume = 0.5
        s.Parent = SoundService
        s:Play()
        game:GetService("Debris"):AddItem(s, 2)
    end)
end

local function notify_safe(title, content, type_)
    type_ = type_ or "info"
    playNotifySound(type_)

    if Rayfield and Rayfield.Notify then
        Rayfield:Notify({
            Title = "[" .. string.upper(type_) .. "] " .. title,
            Content = content,
            Duration = 4,
        })
    else
        warn("[" .. title .. "] " .. content)
    end
end

-- ============================================================
-- [B] GAME PRESET PROFILES
-- ============================================================
local PRESETS = {
    FPS = {
        Wallhack = false, Aimbot = false, AimbotFOV = 120,
        InfiniteJump = false, WalkSpeed = 20, JumpPower = 60,
    },
    RPG = {
        AutoAttack = false, AutoLoot = false,
        WalkSpeed = 25, JumpPower = 70,
    },
    MMO = {
        AutoFarm = false, WalkSpeed = 30, JumpPower = 80, Fly = false,
    },
    None = {
        WalkSpeed = 16, JumpPower = 50,
    },
}

-- Forward declaration (biar applyPreset bisa panggil applySpeed/applyJump)
local applySpeed, applyJump

local function applyPreset(presetName)
    local preset = PRESETS[presetName]
    if not preset then return end
    for k, v in pairs(preset) do
        if State[k] ~= nil then State[k] = v end
    end
    if applySpeed then applySpeed(State.WalkSpeed) end
    if applyJump  then applyJump(State.JumpPower)  end
    notify_safe("Preset", "Preset " .. presetName .. " diterapkan.", "info")
end

-- ============================================================
-- [4] WINDOW --
-- ============================================================
-- Pastikan Window dibuat setelah delay load
local Window = Rayfield:CreateWindow({
    Name = "Game Changer",
    Icon = 0,
    LoadingTitle = "Game Changer",
    LoadingSubtitle = "Select your game mode",
    ShowText = "",
    Theme = "Amethyst",
    ToggleUIKeybind = Enum.KeyCode.RightShift,
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    ConfigurationSaving = {
        Enabled = false,
        FolderName = "Configs",
        FileName = "Config"
    },
    Discord = {
        Enabled = true,
        Invite = "discord.gg/invite",
        RememberJoins = false
    },
})

-- Debug: Cek apakah Window dibuat
if not Window then
    warn("[Rayfield] Window object returned nil.")
    return
end

-- Tampilkan UI (SETELAH CreateWindow)
-- Call Show() dua kali dengan jeda untuk memastikan render
task.spawn(function()
    task.wait(1)  -- tunggu 1 detik
    pcall(function() Window:Show() end)
    task.wait(0.5)
    pcall(function() Window:Show() end)  -- panggil 2x
    print("[Rayfield] Window:Show() called successfully.")
end)

-- ============================================================
-- [D] FPS COUNTER + PING DISPLAY (SETELAH WINDOW)
-- ============================================================
local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "GC_StatsOverlay"
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true
StatsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Gunakan CoreGui atau Override gethui
local parentTarget = (gethui and gethui()) or CoreGui
pcall(function() StatsGui.Parent = parentTarget end)

local StatsFrame = Instance.new("Frame")
StatsFrame.Name = "StatsFrame"
StatsFrame.Size = UDim2.new(0, 180, 0, 60)
StatsFrame.Position = UDim2.new(1, -190, 0, 10)
StatsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
StatsFrame.BackgroundTransparency = 0.3
StatsFrame.BorderSizePixel = 0
StatsFrame.Active = true
StatsFrame.Parent = StatsGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = StatsFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(150, 100, 255)
stroke.Thickness = 1.5
stroke.Parent = StatsFrame

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Size = UDim2.new(1, -10, 1, -10)
StatsLabel.Position = UDim2.new(0, 5, 0, 5)
StatsLabel.BackgroundTransparency = 1
StatsLabel.TextColor3 = Color3.fromRGB(230, 230, 255)
StatsLabel.Font = Enum.Font.Code
StatsLabel.TextSize = 14
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.TextYAlignment = Enum.TextYAlignment.Top
StatsLabel.Text = "Game Changer v4.1\nFPS: -- | Ping: -- ms\nGame: " .. GameInfo.Name
StatsLabel.Parent = StatsFrame

-- Drag manual (Draggable deprecated)
local dragging, dragStart, startPos
StatsFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = StatsFrame.Position
    end
end)
StatsFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        StatsFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

local frameCount = 0
local lastTime = tick()
local currentFPS = 0

RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = tick()
    if now - lastTime >= 1 then
        currentFPS = frameCount
        frameCount = 0
        lastTime = now
    end
end)

task.spawn(function()
    while task.wait(1) do
        local ping = "N/A"
        pcall(function()
            ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        StatsLabel.Text = string.format(
            "Game Changer v4.1\nFPS: %d | Ping: %s ms\nGame: %s",
            currentFPS, tostring(ping), GameInfo.Name
        )
    end
end)

-- ============================================================
-- FUNGSI UTAMA
-- ============================================================
local function StartScript()
    warn("[Game Changer] Script is running...")
end

local function StopScript()
    warn("[Game Changer] Script has been stopped.")
    for k, v in pairs(State) do
        if type(v) == "boolean" then State[k] = false end
    end
    for _, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}
    if bypass and bypass.disable then
        pcall(function() bypass.disable() end)
    end
end

StartScript()

-- ============================================================
-- HELPER
-- ============================================================
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function notify(title, content) notify_safe(title, content, "info") end
local function notifySuccess(title, content) notify_safe(title, content, "success") end
local function notifyWarn(title, content) notify_safe(title, content, "warn") end
local function notifyError(title, content) notify_safe(title, content, "error") end

-- ============================================================
-- [5] IMPLEMENTASI FITUR
-- ============================================================

-- ---------- FPS: Wallhack ----------
local function enableWallhack()
    local function highlightPlayer(plr)
        if plr == LocalPlayer then return end
        local char = plr.Character
        if not char then return end
        local hl = char:FindFirstChild("GC_Highlight")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "GC_Highlight"
            hl.FillColor = Color3.fromRGB(255, 0, 0)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do highlightPlayer(plr) end

    addConn("Wallhack_Added", Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(math.random(5, 15) / 10)
            if State.Wallhack then highlightPlayer(plr) end
        end)
    end))

    addConn("Wallhack_Char", LocalPlayer.CharacterAdded:Connect(function()
        task.wait(math.random(5, 15) / 10)
        for _, plr in ipairs(Players:GetPlayers()) do
            if State.Wallhack then highlightPlayer(plr) end
        end
    end))

    for _, plr in ipairs(Players:GetPlayers()) do
        addConn("Wallhack_" .. plr.Name, plr.CharacterAdded:Connect(function()
            task.wait(math.random(5, 15) / 10)
            if State.Wallhack then highlightPlayer(plr) end
        end))
    end
end

local function disableWallhack()
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char and char:FindFirstChild("GC_Highlight") then
            char.GC_Highlight:Destroy()
        end
    end
    for key, conn in pairs(Connections) do
        if key:find("Wallhack") then
            conn:Disconnect()
            Connections[key] = nil
        end
    end
end

-- ---------- FPS: Infinite Jump ----------
local function enableInfiniteJump()
    addConn("InfiniteJump", UserInputService.JumpRequest:Connect(function()
        if State.InfiniteJump then
            local hum = getHumanoid()
            if hum then
                safeJump()
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))
end

-- ---------- FPS: Aimbot ----------
local function getClosestPlayerToCursor()
    local closest, shortest = nil, State.AimbotFOV
    local mousePos = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < shortest then
                        shortest = dist
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function enableAimbot()
    addConn("Aimbot", RunService.RenderStepped:Connect(function()
        if not State.Aimbot then return end
        local target = getClosestPlayerToCursor()
        if target and target.Character then
            local head = target.Character:FindFirstChild("Head")
            if head then
                Camera.CFrame = Camera.CFrame:Lerp(
                    CFrame.new(Camera.CFrame.Position, head.Position),
                    State.AimbotSmoothness
                )
            end
        end
    end))
end

-- ---------- RPG: Auto Attack ----------
local function enableAutoAttack()
    addConn("AutoAttack", RunService.Heartbeat:Connect(function()
        if not State.AutoAttack then return end
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool and tool:GetAttribute("Equipped") then
            tool:Activate()
            safeInput(Enum.UserInputType.MouseButton1, true)
            task.wait(0.03)
            safeInput(Enum.UserInputType.MouseButton1, false)
        end
    end))
end

-- ---------- RPG: Auto Loot ----------
local function enableAutoLoot()
    addConn("AutoLoot", RunService.Heartbeat:Connect(function()
        if not State.AutoLoot then return end
        local root = getRoot()
        if not root then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Tool") and obj:FindFirstChild("Handle") then
                if (obj.Handle.Position - root.Position).Magnitude < 30 then
                    local hum = getHumanoid()
                    if hum then hum:EquipTool(obj) end
                    break
                end
            end
        end
    end))
end

-- ---------- MMO: Auto Farm ----------
local function enableAutoFarm()
    addConn("AutoFarm", RunService.Heartbeat:Connect(function()
        if not State.AutoFarm then return end
        local root = getRoot()
        if not root then return end
        local closest, shortest = nil, math.huge
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= LocalPlayer.Character then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local dist = (hrp.Position - root.Position).Magnitude
                    if dist < shortest then
                        shortest = dist
                        closest = obj
                    end
                end
            end
        end
        if closest then
            local hrp = closest:FindFirstChild("HumanoidRootPart")
            if hrp then root.CFrame = hrp.CFrame * CFrame.new(0, 0, 5) end
        end
    end))
end

-- ---------- MMO: Teleport ----------
local function teleportToPlayer(name)
    local target = Players:FindFirstChild(name)
    if not target or not target.Character then
        notify("Teleport", "Pemain tidak ditemukan.")
        return
    end
    local hrp  = target.Character:FindFirstChild("HumanoidRootPart")
    local root = getRoot()
    if hrp and root then
        root.CFrame = hrp.CFrame * CFrame.new(0, 0, 3)
        notify("Teleport", "Berhasil teleport ke " .. name)
    end
end

-- ---------- MISC: Speed / Jump ----------
local MAX_SPEED = 100
local MAX_JUMP  = 120

applySpeed = function(value)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = math.clamp(value, 16, MAX_SPEED) end
end

applyJump = function(value)
    local hum = getHumanoid()
    if hum then hum.JumpPower = math.clamp(value, 50, MAX_JUMP) end
end

-- ---------- MISC: Fly ----------
local function enableFly()
    local char = getCharacter()
    local root = char:WaitForChild("HumanoidRootPart")

    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.Name = "GC_FlyVelocity"
    bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = root

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "GC_FlyGyro"
    bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bodyGyro.P = 1000
    bodyGyro.Parent = root

    addConn("Fly", RunService.RenderStepped:Connect(function()
        if not State.Fly then return end
        local move = Vector3.zero
        if isKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if isKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if isKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if isKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if isKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
        if isKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end
        bodyVel.Velocity = move * State.FlySpeed
        bodyGyro.CFrame = Camera.CFrame
    end))
end

local function disableFly()
    removeConn("Fly")
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            for _, v in ipairs(root:GetChildren()) do
                if v.Name == "GC_FlyVelocity" or v.Name == "GC_FlyGyro" then
                    v:Destroy()
                end
            end
        end
    end
end

-- ============================================================
-- [6] TAB: GAME MODE
-- ============================================================
local GameModeTab = Window:CreateTab("Game Mode", 4483362458)
GameModeTab:CreateSection("Select Game Mode")

local FPSModeTab = Window:CreateTab("FPS Mode", 4483362458)
local RPGModeTab = Window:CreateTab("RPG Mode", 4483362458)
local MMOModeTab = Window:CreateTab("MMO Mode", 4483362458)

GameModeTab:CreateDropdown({
    Name = "Game Mode",
    CurrentOption = {"None"},
    Options = {"FPS", "RPG", "MMO", "None"},
    Callback = function(option)
        local v = type(option) == "table" and option[1] or option
        notify("Game Mode", v .. " Mode dipilih. Cek tab '" .. v .. " Mode'.")
    end,
})

-- ============================================================
-- TAB: FPS MODE
-- ============================================================
FPSModeTab:CreateSection("FPS Settings")

FPSModeTab:CreateToggle({
    Name = "Wallhack", CurrentValue = false, Flag = "FPS_Wallhack",
    Callback = function(v)
        State.Wallhack = v
        if v then enableWallhack(); notify("FPS", "Wallhack ON")
        else disableWallhack(); notify("FPS", "Wallhack OFF") end
    end,
})

FPSModeTab:CreateToggle({
    Name = "Infinite Jump", CurrentValue = false, Flag = "FPS_InfiniteJump",
    Callback = function(v)
        State.InfiniteJump = v
        if v then enableInfiniteJump(); notify("FPS", "Infinite Jump ON")
        else removeConn("InfiniteJump"); notify("FPS", "Infinite Jump OFF") end
    end,
})

FPSModeTab:CreateToggle({
    Name = "Aimbot", CurrentValue = false, Flag = "FPS_Aimbot",
    Callback = function(v)
        State.Aimbot = v
        if v then enableAimbot(); notify("FPS", "Aimbot ON")
        else removeConn("Aimbot"); notify("FPS", "Aimbot OFF") end
    end,
})

FPSModeTab:CreateSlider({
    Name = "Aimbot FOV", Range = {10, 500}, Increment = 5, Suffix = "px",
    CurrentValue = 100, Flag = "FPS_AimbotFOV",
    Callback = function(v) State.AimbotFOV = v end,
})

FPSModeTab:CreateSlider({
    Name = "Aimbot Smoothness", Range = {1, 100}, Increment = 1, Suffix = "%",
    CurrentValue = 15, Flag = "FPS_AimbotSmooth",
    Callback = function(v) State.AimbotSmoothness = v / 100 end,
})

-- ============================================================
-- TAB: RPG MODE
-- ============================================================
RPGModeTab:CreateSection("RPG Settings")

RPGModeTab:CreateToggle({
    Name = "Auto Attack", CurrentValue = false, Flag = "RPG_AutoAttack",
    Callback = function(v)
        State.AutoAttack = v
        if v then enableAutoAttack(); notify("RPG", "Auto Attack ON")
        else removeConn("AutoAttack"); notify("RPG", "Auto Attack OFF") end
    end,
})

RPGModeTab:CreateToggle({
    Name = "Auto Loot", CurrentValue = false, Flag = "RPG_AutoLoot",
    Callback = function(v)
        State.AutoLoot = v
        if v then enableAutoLoot(); notify("RPG", "Auto Loot ON")
        else removeConn("AutoLoot"); notify("RPG", "Auto Loot OFF") end
    end,
})

-- ============================================================
-- TAB: MMO MODE
-- ============================================================
MMOModeTab:CreateSection("MMO Settings")

MMOModeTab:CreateToggle({
    Name = "Auto Farm", CurrentValue = false, Flag = "MMO_AutoFarm",
    Callback = function(v)
        State.AutoFarm = v
        if v then enableAutoFarm(); notify("MMO", "Auto Farm ON")
        else removeConn("AutoFarm"); notify("MMO", "Auto Farm OFF") end
    end,
})

MMOModeTab:CreateInput({
    Name = "Teleport Target", CurrentValue = "",
    PlaceholderText = "Nama pemain...",
    RemoveTextAfterFocusLost = false, Flag = "MMO_TPTarget",
    Callback = function(text) State.TeleportTarget = text end,
})

MMOModeTab:CreateButton({
    Name = "Teleport to Player",
    Callback = function()
        if State.TeleportTarget ~= "" then
            teleportToPlayer(State.TeleportTarget)
        else
            notify("Teleport", "Isi nama pemain dulu.")
        end
    end,
})

-- ============================================================
-- TAB: MISC
-- ============================================================
local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateSection("Character")

MiscTab:CreateSlider({
    Name = "WalkSpeed", Range = {16, 100}, Increment = 1, Suffix = "studs",
    CurrentValue = 16, Flag = "Misc_WalkSpeed",
    Callback = function(v) State.WalkSpeed = v; applySpeed(v) end,
})

MiscTab:CreateSlider({
    Name = "JumpPower", Range = {50, 120}, Increment = 1, Suffix = "studs",
    CurrentValue = 50, Flag = "Misc_JumpPower",
    Callback = function(v) State.JumpPower = v; applyJump(v) end,
})

MiscTab:CreateSection("Movement")

MiscTab:CreateToggle({
    Name = "Fly", CurrentValue = false, Flag = "Misc_Fly",
    Callback = function(v)
        State.Fly = v
        if v then enableFly(); notify("Misc", "Fly ON")
        else disableFly(); notify("Misc", "Fly OFF") end
    end,
})

MiscTab:CreateSlider({
    Name = "Fly Speed", Range = {10, 200}, Increment = 5, Suffix = "studs/s",
    CurrentValue = 50, Flag = "Misc_FlySpeed",
    Callback = function(v) State.FlySpeed = v end,
})

MiscTab:CreateSection("Other")

MiscTab:CreateButton({
    Name = "Reset Character",
    Callback = function()
        local hum = getHumanoid()
        if hum then hum.Health = 0; notify("Misc", "Character di-reset.") end
    end,
})

MiscTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        StopScript()
        pcall(function() if StatsGui then StatsGui:Destroy() end end)
        Rayfield:Destroy()
    end,
})

-- ============================================================
-- [E] KEYBIND MANAGER
-- ============================================================
local Keybinds = {
    Panic        = Enum.KeyCode.End,
    ToggleAimbot = Enum.KeyCode.X,
    ToggleFly    = Enum.KeyCode.F,
    ToggleWall   = Enum.KeyCode.V,
}

local KeybindTab = Window:CreateTab("Keybinds", 4483362458)
KeybindTab:CreateSection("Global")

local keyList = {
    "RightShift", "End", "X", "F", "V", "G", "H", "Z", "C",
    "Q", "E", "R", "T", "Y", "U", "I", "O", "P",
    "F1","F2","F3","F4","F5","F6","F7","F8",
}

local function safeEnumKey(name)
    local ok, keycode = pcall(function() return Enum.KeyCode[name] end)
    if ok and keycode then return keycode end
    return nil
end

KeybindTab:CreateDropdown({
    Name = "Panic Key (matikan semua + destroy UI)",
    CurrentOption = {"End"}, Options = keyList, Flag = "KB_Panic",
    Callback = function(opt)
        local v = type(opt) == "table" and opt[1] or opt
        local k = safeEnumKey(v)
        if k then Keybinds.Panic = k
        else notify_safe("Keybind", "Key tidak valid: " .. tostring(v), "error") end
    end,
})

KeybindTab:CreateDropdown({
    Name = "Toggle Aimbot",
    CurrentOption = {"X"}, Options = keyList, Flag = "KB_Aimbot",
    Callback = function(opt)
        local v = type(opt) == "table" and opt[1] or opt
        local k = safeEnumKey(v)
        if k then Keybinds.ToggleAimbot = k end
    end,
})

KeybindTab:CreateDropdown({
    Name = "Toggle Fly",
    CurrentOption = {"F"}, Options = keyList, Flag = "KB_Fly",
    Callback = function(opt)
        local v = type(opt) == "table" and opt[1] or opt
        local k = safeEnumKey(v)
        if k then Keybinds.ToggleFly = k end
    end,
})

KeybindTab:CreateDropdown({
    Name = "Toggle Wallhack",
    CurrentOption = {"V"}, Options = keyList, Flag = "KB_Wall",
    Callback = function(opt)
        local v = type(opt) == "table" and opt[1] or opt
        local k = safeEnumKey(v)
        if k then Keybinds.ToggleWall = k end
    end,
})

-- Handler keybind
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    local key = input.KeyCode

    if key == Keybinds.Panic then
        for k, v in pairs(State) do
            if type(v) == "boolean" then State[k] = false end
        end
        for _, conn in pairs(Connections) do
            pcall(function() conn:Disconnect() end)
        end
        pcall(function() if bypass and bypass.disable then bypass.disable() end end)
        pcall(function()
            if StatsGui then StatsGui:Destroy() end
            Rayfield:Destroy()
        end)
        warn("[Game Changer] PANIC — semua fitur dimatikan.")
        return
    end

    if key == Keybinds.ToggleAimbot then
        State.Aimbot = not State.Aimbot
        if State.Aimbot then enableAimbot() else removeConn("Aimbot") end
        notify_safe("Keybind", "Aimbot: " .. tostring(State.Aimbot), "info")
    end

    if key == Keybinds.ToggleFly then
        State.Fly = not State.Fly
        if State.Fly then enableFly() else disableFly() end
        notify_safe("Keybind", "Fly: " .. tostring(State.Fly), "info")
    end

    if key == Keybinds.ToggleWall then
        State.Wallhack = not State.Wallhack
        if State.Wallhack then enableWallhack() else disableWallhack() end
        notify_safe("Keybind", "Wallhack: " .. tostring(State.Wallhack), "info")
    end
end)

-- ============================================================
-- [7] HANDLE RESPAWN
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(math.random(8, 15) / 10)
    applySpeed(State.WalkSpeed)
    applyJump(State.JumpPower)
    if State.Fly then
        disableFly()
        enableFly()
    end
end)

-- ============================================================
-- [8] AUTO-APPLY PRESET + START NOTIFY
-- ============================================================
if GameInfo.Preset ~= "None" then
    applyPreset(GameInfo.Preset)
end

notify_safe(
    "Game Changer",
    "Loaded! Game: " .. GameInfo.Name ..
    " | Preset: " .. GameInfo.Preset ..
    (bypass and " | Bypass ON" or " | Bypass OFF"),
    "success"
)
