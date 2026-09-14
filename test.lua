--[[
    ============================================================
    GAME CHANGER - FINAL VERSION
    ============================================================
    Fitur:
      - Universal Anti-Cheat Bypass (opsional, fallback jika gagal)
      - Rayfield UI
      - FPS: Wallhack, Infinite Jump, Aimbot
      - RPG: Auto Attack, Auto Loot
      - MMO: Auto Farm, Teleport
      - Misc: WalkSpeed, JumpPower, Fly, Reset
      - safeInput (kirim input lewat bypass)
      - Clamp speed/jump agar tidak ekstrem
      - Delay acak saat respawn
    ============================================================
--]]

if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera


-- [1] LOAD BYPASS (HARUS PALING AWAL)

local bypass = nil
local BYPASS_URL = "https://raw.githubusercontent.com/user/repo/main/universalbypass.lua" -- ← ISI URL raw universalbypass.lua kamu di sini
                         -- Contoh: "https://raw.githubusercontent.com/user/repo/main/universalbypass.lua"

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
        -- bypass.setDebugMode(true)
        bypass.enable()
    end)
    print("[Game Changer] Bypass aktif.")
else
    warn("[Game Changer] Bypass tidak ditemukan. Script tetap jalan tanpa proteksi.")
end


-- SAFE INPUT HELPERS

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

-- Rekam state keyboard sendiri (tidak pakai UserInputService:IsKeyDown)
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


-- [2] LOAD RAYFIELD

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

if not Rayfield then
    warn("[ERROR]: Failed to load Rayfield.")
    return
end


-- [3] STATE MANAGEMENT

local State = {
    -- FPS
    Wallhack = false,
    InfiniteJump = false,
    Aimbot = false,
    AimbotFOV = 100,
    AimbotSmoothness = 0.15,
    -- RPG
    AutoAttack = false,
    AutoLoot = false,
    -- MMO
    AutoFarm = false,
    Teleport = false,
    TeleportTarget = "",
    -- Misc
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


-- [4] WINDOW

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


-- FUNGSI UTAMA

local function StartScript()
    warn("[Game Changer] Script is running...")
end

local function StopScript()
    warn("[Game Changer] Script has been stopped.")

    for k, v in pairs(State) do
        if type(v) == "boolean" then State[k] = false end
    end
    for key, conn in pairs(Connections) do
        conn:Disconnect()
    end
    Connections = {}

    if bypass and bypass.disable then
        pcall(function() bypass.disable() end)
    end
end

StartScript()


-- HELPER

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

local function notify(title, content)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = 4,
    })
end

-- [5] IMPLEMENTASI FITUR

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

    for _, plr in ipairs(Players:GetPlayers()) do
        highlightPlayer(plr)
    end

    addConn("Wallhack_Added", Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(math.random(5, 15) / 10) -- delay acak 0.5–1.5s
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

-- ---------- FPS: Infinite Jump (safe input) ----------
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

-- ---------- RPG: Auto Attack (safe input) ----------
local function enableAutoAttack()
    addConn("AutoAttack", RunService.Heartbeat:Connect(function()
        if not State.AutoAttack then return end
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
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
            if hrp then
                root.CFrame = hrp.CFrame * CFrame.new(0, 0, 5)
            end
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

-- ---------- MISC: Speed / Jump (clamp agar aman) ----------
local MAX_SPEED = 100
local MAX_JUMP  = 120

local function applySpeed(value)
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = math.clamp(value, 16, MAX_SPEED)
    end
end

local function applyJump(value)
    local hum = getHumanoid()
    if hum then
        hum.JumpPower = math.clamp(value, 50, MAX_JUMP)
    end
end

-- ---------- MISC: Fly (pakai isKeyDown state lokal) ----------
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


-- [6] TAB: GAME MODE

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


-- TAB: FPS MODE

FPSModeTab:CreateSection("FPS Settings")

FPSModeTab:CreateToggle({
    Name = "Wallhack",
    CurrentValue = false,
    Flag = "FPS_Wallhack",
    Callback = function(v)
        State.Wallhack = v
        if v then enableWallhack(); notify("FPS", "Wallhack ON")
        else disableWallhack(); notify("FPS", "Wallhack OFF") end
    end,
})

FPSModeTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "FPS_InfiniteJump",
    Callback = function(v)
        State.InfiniteJump = v
        if v then enableInfiniteJump(); notify("FPS", "Infinite Jump ON")
        else removeConn("InfiniteJump"); notify("FPS", "Infinite Jump OFF") end
    end,
})

FPSModeTab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false,
    Flag = "FPS_Aimbot",
    Callback = function(v)
        State.Aimbot = v
        if v then enableAimbot(); notify("FPS", "Aimbot ON")
        else removeConn("Aimbot"); notify("FPS", "Aimbot OFF") end
    end,
})

FPSModeTab:CreateSlider({
    Name = "Aimbot FOV",
    Range = {10, 500}, Increment = 5, Suffix = "px",
    CurrentValue = 100, Flag = "FPS_AimbotFOV",
    Callback = function(v) State.AimbotFOV = v end,
})

FPSModeTab:CreateSlider({
    Name = "Aimbot Smoothness",
    Range = {1, 100}, Increment = 1, Suffix = "%",
    CurrentValue = 15, Flag = "FPS_AimbotSmooth",
    Callback = function(v) State.AimbotSmoothness = v / 100 end,
})


-- TAB: RPG MODE

RPGModeTab:CreateSection("RPG Settings")

RPGModeTab:CreateToggle({
    Name = "Auto Attack",
    CurrentValue = false,
    Flag = "RPG_AutoAttack",
    Callback = function(v)
        State.AutoAttack = v
        if v then enableAutoAttack(); notify("RPG", "Auto Attack ON")
        else removeConn("AutoAttack"); notify("RPG", "Auto Attack OFF") end
    end,
})

RPGModeTab:CreateToggle({
    Name = "Auto Loot",
    CurrentValue = false,
    Flag = "RPG_AutoLoot",
    Callback = function(v)
        State.AutoLoot = v
        if v then enableAutoLoot(); notify("RPG", "Auto Loot ON")
        else removeConn("AutoLoot"); notify("RPG", "Auto Loot OFF") end
    end,
})

-- TAB: MMO MODE

MMOModeTab:CreateSection("MMO Settings")

MMOModeTab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = false,
    Flag = "MMO_AutoFarm",
    Callback = function(v)
        State.AutoFarm = v
        if v then enableAutoFarm(); notify("MMO", "Auto Farm ON")
        else removeConn("AutoFarm"); notify("MMO", "Auto Farm OFF") end
    end,
})

MMOModeTab:CreateInput({
    Name = "Teleport Target",
    CurrentValue = "",
    PlaceholderText = "Nama pemain...",
    RemoveTextAfterFocusLost = false,
    Flag = "MMO_TPTarget",
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


local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateSection("Character")

MiscTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 100}, Increment = 1, Suffix = "studs",
    CurrentValue = 16, Flag = "Misc_WalkSpeed",
    Callback = function(v) State.WalkSpeed = v; applySpeed(v) end,
})

MiscTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 120}, Increment = 1, Suffix = "studs",
    CurrentValue = 50, Flag = "Misc_JumpPower",
    Callback = function(v) State.JumpPower = v; applyJump(v) end,
})

MiscTab:CreateSection("Movement")

MiscTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "Misc_Fly",
    Callback = function(v)
        State.Fly = v
        if v then enableFly(); notify("Misc", "Fly ON")
        else disableFly(); notify("Misc", "Fly OFF") end
    end,
})

MiscTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200}, Increment = 5, Suffix = "studs/s",
    CurrentValue = 50, Flag = "Misc_FlySpeed",
    Callback = function(v) State.FlySpeed = v end,
})

MiscTab:CreateSection("Other")

MiscTab:CreateButton({
    Name = "Reset Character",
    Callback = function()
        local hum = getHumanoid()
        if hum then
            hum.Health = 0
            notify("Misc", "Character di-reset.")
        end
    end,
})

MiscTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        StopScript()
        Rayfield:Destroy()
    end,
})

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(math.random(8, 15) / 10) 
    applySpeed(State.WalkSpeed)
    applyJump(State.JumpPower)
    if State.Fly then
        disableFly()
        enableFly()
    end
end)

notify("Game Changer", "Script berhasil dimuat!" .. (bypass and " (Bypass ON)" or " (Tanpa Bypass)"))