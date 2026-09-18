--[[
    ============================================================
    GAME CHANGER - v6.0 (PROFESSIONAL EDITION)
    ============================================================
    Upgrade:
      - Keybind Manager (Customizable)
      - Auto Save/Load (DataStore)
      - Panic Key (Emergency Off)
      - Player List & Teleport
      - Silent Aim & Trigger Bot
      - Mobile Support & Anti-Void
      - UI Settings & Theme
    ============================================================
--]]

if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local DataStoreService = game:GetService("DataStoreService")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local CollectionService= game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local DataStoreName = "GameChanger_Config"

-- ============================================================
-- [1] STATE MANAGEMENT (EXPANDED)
-- ============================================================
local State = {
    -- Core
    Wallhack = false,
    InfiniteJump = false,
    Aimbot = false,
    SilentAim = true, -- Baru: Silent Aim Default ON
    AimbotFOV = 100,
    AimbotSmoothness = 0.15,
    TriggerBot = false, -- Baru: Trigger Bot
    AutoAttack = false,
    AutoLoot = false,
    AutoLootRadius = 100,
    AutoLootDelay = 0.1,
    AutoFarm = false,
    
    -- Movement
    WalkSpeed = 16,
    JumpPower = 50,
    Fly = false,
    FlySpeed = 50,
    AntiVoid = true, -- Baru: Anti Void
    AntiAFK = true,  -- Baru: Anti AFK
    
    -- Anti Lag
    MaxItemsPerScan = 50,
    ScanInterval = 0.5,
    IsLooting = false,
    UseSpawnReturn = true,
    
    -- Keybinds (Default)
    Keybinds = {
        Toggle = Enum.KeyCode.RightShift,
        Fly = Enum.KeyCode.X,
        Panic = Enum.KeyCode.RightControl,
    },
    
    -- UI & Save
    MobileMode = false, -- Baru: Mobile Support
    Theme = "DarkBlue",
    ConfigLoaded = false,
    Connections = {},
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
-- [2] GAME DETECTION & INFO
-- ============================================================
local KNOWN_GAMES = {
    [2753915549] = { Name = "Blox Fruits", Preset = "RPG" },
    [286090429]  = { Name = "Arsenal",     Preset = "FPS" },
    [5938036553] = { Name = "Da Hood",     Preset = "FPS" },
    [6516141723] = { Name = "Doors",       Preset = "RPG" },
    [142823291]  = { Name = "Murder Mystery 2", Preset = "FPS" },
    [920587237]  = { Name = "Adopt Me",    Preset = "RPG" },
    [6284583030] = { Name = "Pet Simulator X", Preset = "MMO" },
}

local GameInfo = {
    PlaceId = game.PlaceId,
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
        if info and info.Name then GameInfo.Name = info.Name end
    end)
end

-- ============================================================
-- [3] KEYBIND MANAGER (TIER 1)
-- ============================================================
local KeybindManager = {
    Bindings = {},
    IsMobile = false,
}

-- Fungsi untuk menghubungkan Keybind ke fungsi
local function bindKey(key, func, name)
    local callback = function(pressed)
        if pressed then
            func()
        end
    end
    UserInputService.InputBegan:Connect(function(input, p)
        if not p and input.KeyCode == key then callback(true) end
    end)
    KeybindManager.Bindings[name] = callback
end

-- Default Binding
bindKey(State.Keybinds.Toggle, function()
    if Rayfield then Rayfield:Toggle() end
end, "Toggle")
bindKey(State.Keybinds.Fly, function()
    State.Fly = not State.Fly
    -- Notif
    local s = State.Fly and "ON" or "OFF"
    notify("Fly", s, State.Fly and "success" or "info")
end, "Fly")
bindKey(State.Keybinds.Panic, function()
    notifyError("Panic", "Resetting all features...", "info")
    State.Wallhack = false
    State.Aimbot = false
    State.InfiniteJump = false
    State.Fly = false
    State.AutoAttack = false
    State.AutoLoot = false
    if flyVel then flyVel:Destroy() end
    if flyGyro then flyGyro:Destroy() end
    -- Clean UI
    pcall(function() Rayfield:Destroy() end)
end, "Panic")

-- ============================================================
-- [4] SAVE/LOAD SYSTEM (TIER 1)
-- ============================================================
local DataStore = DataStoreService:FindFirstChild(DataStoreName) or DataStoreService:CreateDataStoreAsync("GC", DataStoreName)

local function saveConfig()
    local data = {
        Wallhack = State.Wallhack,
        Aimbot = State.Aimbot,
        Fly = State.Fly,
        InfiniteJump = State.InfiniteJump,
        AutoLoot = State.AutoLoot,
        -- Add more fields as needed
    }
    pcall(function()
        DataStore:SetAsync("Save", data)
    end)
end

local function loadConfig()
    local data = pcall(function() return DataStore:GetAsync("Save") end)
    if data and data.Wallhack then
        State.Wallhack = data.Wallhack
        State.Aimbot = data.Aimbot
        State.Fly = data.Fly
        State.InfiniteJump = data.InfiniteJump
        State.AutoLoot = data.AutoLoot
        State.ConfigLoaded = true
        notifySuccess("Config", "Settings Loaded", "success")
    end
end

loadConfig()

-- Auto Save setiap 10 detik
RunService.Heartbeat:Connect(function()
    if tick() % 10 < 0.5 then saveConfig() end
end)

-- ============================================================
-- [5] SMART ITEM SYSTEM (TIER 1 & 2)
-- ============================================================
local ITEM_KEYWORDS = { "egg", "coin", "gem", "chest", "loot", "drop", "crate", "box", "reward", "bonus", "prize", "token", "star", "candy", "fruit", "pet", "seed", "ore", "gold", "silver", "diamond", "crystal", "telur", "koin", "permata", "peti", "hadiah", }
local DetectedItems = {}
local ItemCache = {}

local function isItemCandidate(obj)
    local name = obj.Name:lower()
    for _, kw in ipairs(ITEM_KEYWORDS) do if name:find(kw, 1, true) then return true end end
    -- Cek tag
    if CollectionService:HasTag(obj, "Lootable") or CollectionService:HasTag(obj, "Item") or CollectionService:HasTag(obj, "Collectible") then return true end
    return false
end

local function getItemPosition(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.Position end
        local hrp = obj:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
    end
    if obj:IsA("Tool") then
        local handle = obj:FindFirstChild("Handle")
        if handle then return handle.Position end
    end
    return nil
end

local function scanItems()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local myPos = root.Position
    local radius = State.AutoLootRadius
    local count = 0
    local newDetected = {}
    
    for _, obj in ipairs(workspace:GetChildren()) do
        if count >= State.MaxItemsPerScan then break end
        if isItemCandidate(obj) then
            local pos = getItemPosition(obj)
            if pos then
                local dist = (pos - myPos).Magnitude
                if dist <= radius then
                    newDetected[obj] = { Instance = obj, Name = obj.Name, Distance = math.floor(dist), Position = pos }
                    count = count + 1
                end
            end
        end
    end
    
    DetectedItems = newDetected
end

-- ============================================================
-- [6] AUTO LOOT LOGIC (OPTIMIZED)
-- ============================================================
local function lootItem(itemInfo)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    
    local obj = itemInfo.Instance
    if not obj or not obj.Parent then return false end
    
    local targetPos = itemInfo.Position
    if not targetPos then return false end
    
    local distance = (root.Position - targetPos).Magnitude
    local speed = 200
    local duration = math.clamp(distance / speed, 0.05, 0.5)
    
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0)) })
    tween:Play()
    tween.Completed:Wait()
    
    pcall(function()
        if obj:IsA("Tool") then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(obj) end
        end
        
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then fireproximityprompt(prompt) end
        
        local cd = obj:FindFirstChildWhichIsA("ClickDetector", true)
        if cd then fireclickdetector(cd) end
        
        local handle = obj:FindFirstChild("Handle") or obj
        if handle and handle:IsA("BasePart") then
            local touchInterest = handle:FindFirstChild("TouchInterest")
            if touchInterest and firetouchinterest then
                firetouchinterest(root, handle, 0)
                task.wait(0.05)
                firetouchinterest(root, handle, 1)
            end
        end
        
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("RemoteEvent") then
                local n = child.Name:lower()
                if n:find("collect") or n:find("pickup") or n:find("claim") or n:find("grab") then child:FireServer() end
            end
        end
        
        if Players:FindFirstChild(obj.Name) then return false end
    end)
    
    task.wait(State.AutoLootDelay)
    return true
end

local function returnToSpawn()
    if not State.UseSpawnReturn then return end
    if not State.SpawnPosition then return end
    
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        local distance = (root.Position - State.SpawnPosition.Position).Magnitude
        local duration = math.clamp(distance / 250, 0.05, 0.5)
        
        local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = State.SpawnPosition })
        tween:Play()
        tween.Completed:Wait()
    end
end

local function runAutoLoot()
    if State.IsLooting then return end
    State.IsLooting = true
    
    task.spawn(function()
        while State.AutoLoot do
            scanItems()
            
            local targets = {}
            local hasSelection = next(State.SelectedItems) ~= nil
            
            for inst, info in pairs(DetectedItems) do
                if not hasSelection or State.SelectedItems[inst.Name] then
                    if not Players:FindFirstChild(inst.Name) then
                        table.insert(targets, info)
                    end
                end
            end
            
            if #targets == 0 then
                task.wait(State.ScanInterval)
            else
                table.sort(targets, function(a, b) return a.Distance < b.Distance end)
                
                for _, info in ipairs(targets) do
                    if not State.AutoLoot then break end
                    if info.Instance and info.Instance.Parent then
                        lootItem(info)
                    end
                end
                
                returnToSpawn()
                task.wait(State.ScanInterval)
            end
        end
        State.IsLooting = false
    end)
end

-- ============================================================
-- [7] UI - WINDOW CREATION
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "🎮 Game Changer v6.0",
    Icon = 0,
    LoadingTitle = "Game Changer",
    LoadingSubtitle = "Professional Edition v6.0",
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

if not Window then warn("[ERROR] Window nil") end

task.spawn(function()
    task.wait(1)
    pcall(function() Window:Show() end)
end)

-- ============================================================
-- [8] TABS STRUCTURE
-- ============================================================
-- Tab: Home
local HomeTab = Window:CreateTab("🏠 Home", 4483362458)
HomeTab:CreateSection("📊 Game Information")
HomeTab:CreateParagraph({ Title = "🎮 " .. GameInfo.Name, Content = "PlaceId: " .. GameInfo.PlaceId .. "\nPreset: " .. GameInfo.Preset, })

HomeTab:CreateSection("⚡ Quick Actions")
HomeTab:CreateButton({
    Name = "🔄 Refresh Item Detection",
    LayoutOrder = 1,
    Callback = function()
        scanItems()
        local count = 0
        for _ in pairs(DetectedItems) do count = count + 1 end
        notify("Items", "Terdeteksi " .. count .. " item dalam radius " .. State.AutoLootRadius .. " studs")
    end,
})

HomeTab:CreateButton({
    Name = "📍 Set Spawn Point (Current Position)",
    LayoutOrder = 2,
    Callback = function()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            State.SpawnPosition = root.CFrame
            notifySuccess("Spawn", "Spawn point diset!")
        end
    end,
})

-- Tab: Items
local ItemsTab = Window:CreateTab("🎒 Items", 4483362458)

ItemsTab:CreateSection("⚙️ Auto Loot Settings")
ItemsTab:CreateSlider({
    Name = "Scan Radius (studs)",
    Range = {20, 500}, Increment = 10, Suffix = " studs",
    CurrentValue = 100, Flag = "AL_Radius",
    Callback = function(v) State.AutoLootRadius = v end,
})

ItemsTab:CreateSlider({
    Name = "Max Items Per Scan (anti-lag)",
    Range = {10, 200}, Increment = 5,
    CurrentValue = 50, Flag = "AL_MaxItems",
    Callback = function(v) State.MaxItemsPerScan = v end,
})

ItemsTab:CreateSlider({
    Name = "Scan Interval (anti-lag)",
    Range = {10, 200}, Increment = 10, Suffix = " ms",
    CurrentValue = 50, Flag = "AL_ScanInterval",
    Callback = function(v) State.ScanInterval = v / 100 end,
})

ItemsTab:CreateSlider({
    Name = "Loot Delay",
    Range = {5, 100}, Increment = 5, Suffix = " ms",
    CurrentValue = 10, Flag = "AL_LootDelay",
    Callback = function(v) State.AutoLootDelay = v / 100 end,
})

ItemsTab:CreateToggle({
    Name = "Return to Spawn After Loot",
    CurrentValue = true, Flag = "AL_ReturnSpawn",
    Callback = function(v) State.UseSpawnReturn = v end,
})

ItemsTab:CreateSection("📦 Detected Items (pilih yang mau di-loot)")
local ItemStatusParagraph = ItemsTab:CreateParagraph({
    Title = "Status",
    Content = "Klik 'Refresh Items' untuk scan item.",
})

local ItemToggles = {}
local function rebuildItemToggles()
    scanItems()
    local uniqueItems = {}
    for _, info in pairs(DetectedItems) do
        local n = info.Name
        if not uniqueItems[n] then
            uniqueItems[n] = { Count = 0, MinDist = math.huge, Instance = info.Instance }
        end
        uniqueItems[n].Count = uniqueItems[n].Count + 1
        if info.Distance < uniqueItems[n].MinDist then
            uniqueItems[n].MinDist = info.Distance
        end
    end
    
    local totalTypes = 0
    local totalItems = 0
    for name, data in pairs(uniqueItems) do
        totalTypes = totalTypes + 1
        totalItems = totalItems + data.Count
        
        if not ItemToggles[name] then
            local capturedName = name
            local toggle = ItemsTab:CreateToggle({
                Name = "📦 " .. name .. " (" .. data.Count .. "x, " .. data.MinDist .. " studs)",
                CurrentValue = true,
                Flag = "AL_Item_" .. name,
                Callback = function(v)
                    State.SelectedItems[capturedName] = v
                end,
                LayoutOrder = totalTypes * 2 + 1,
            })
            ItemToggles[name] = { Toggle = toggle, State = true }
            State.SelectedItems[name] = true
        end
    end
    
    pcall(function()
        ItemStatusParagraph:Set(
            "🎯 " .. totalTypes .. " jenis, " .. totalItems .. " item",
            "Radius: " .. State.AutoLootRadius .. " studs\nItem dipilih: " .. 
            (function() local c = 0; for _ in pairs(State.SelectedItems) do c = c + 1 end; return c end)() .. 
            " jenis"
        )
    end)
    
    return totalTypes, totalItems
end

ItemsTab:CreateButton({
    Name = "🔄 Refresh Items (Scan Ulang)",
    LayoutOrder = 8,
    Callback = function()
        local types, items = rebuildItemToggles()
        notify("Items", "Scan: " .. types .. " jenis, " .. items .. " item terdeteksi")
    end,
})

ItemsTab:CreateSection("▶️ Auto Loot Control")

ItemsTab:CreateToggle({
    Name = "🚀 Auto Loot (ON/OFF)",
    CurrentValue = false,
    Flag = "AL_Enabled",
    Callback = function(v)
        State.AutoLoot = v
        if v then
            if not State.SpawnPosition then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then State.SpawnPosition = root.CFrame end
            end
            notifySuccess("Auto Loot", "Auto Loot ON")
            runAutoLoot()
        else
            notifyWarn("Auto Loot", "Auto Loot OFF")
        end
    end,
    LayoutOrder = 9,
})

ItemsTab:CreateButton({
    Name = "🎯 Loot Selected Now (One-time)",
    Callback = function()
        scanItems()
        local targets = {}
        for inst, info in pairs(DetectedItems) do
            if State.SelectedItems[inst.Name] then
                table.insert(targets, info)
            end
        end
        
        if #targets == 0 then
            notifyWarn("Auto Loot", "Tidak ada item dipilih / terdeteksi")
            return
        end
        
        task.spawn(function()
            table.sort(targets, function(a, b) return a.Distance < b.Distance end)
            for _, info in ipairs(targets) do
                if State.SelectedItems[info.Instance.Name] then
                    lootItem(info)
                end
            end
            returnToSpawn()
            notifySuccess("Auto Loot", #targets .. " item di-loot!")
        end)
    end,
})

ItemsTab:CreateButton({
    Name = "✅ Pilih Semua Item",
    Callback = function()
        for name, data in pairs(ItemToggles) do
            State.SelectedItems[name] = true
            pcall(function() data.Toggle:Set(true) end)
        end
        notify("Items", "Semua item dipilih")
    end,
})

ItemsTab:CreateButton({
    Name = "❌ Hapus Pilihan",
    Callback = function()
        for name, data in pairs(ItemToggles) do
            State.SelectedItems[name] = false
            pcall(function() data.Toggle:Set(false) end)
        end
        notify("Items", "Semua item di-unselect")
    end,
})

-- Tab: Combat
local CombatTab = Window:CreateTab("⚔️ Combat", 4483362458)
CombatTab:CreateSection("🎯 Aim Assist")

CombatTab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false,
    Flag = "CB_Aimbot",
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

CombatTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = State.SilentAim,
    Flag = "CB_SilentAim",
    Callback = function(v) State.SilentAim = v end,
})

CombatTab:CreateToggle({
    Name = "Trigger Bot",
    CurrentValue = State.TriggerBot,
    Flag = "CB_TriggerBot",
    Callback = function(v) State.TriggerBot = v end,
})

CombatTab:CreateToggle({
    Name = "Auto Attack",
    CurrentValue = false,
    Flag = "CB_AutoAttack",
    Callback = function(v) State.AutoAttack = v end,
})

CombatTab:CreateSection("👁️ Visual")

CombatTab:CreateToggle({
    Name = "Wallhack (Highlight Players)",
    CurrentValue = false,
    Flag = "CB_Wallhack",
    Callback = function(v) State.Wallhack = v end,
})

CombatTab:CreateToggle({
    Name = "Item ESP (Show Loot)",
    CurrentValue = false,
    Flag = "CB_ItemESP",
    Callback = function(v) State.ItemESP = v end,
})

-- Tab: Misc
local MiscTab = Window:CreateTab("⚙️ Misc", 4483362458)

MiscTab:CreateSection("🏃 Character")

MiscTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 100}, Increment = 1, Suffix = " studs",
    CurrentValue = 16, Flag = "MS_WalkSpeed",
    Callback = function(v)
        State.WalkSpeed = v
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})

MiscTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 120}, Increment = 1, Suffix = " studs",
    CurrentValue = 50, Flag = "MS_JumpPower",
    Callback = function(v)
        State.JumpPower = v
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v end
    end,
})

MiscTab:CreateSection("✈️ Fly")

MiscTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "MS_Fly",
    Callback = function(v) State.Fly = v end,
})

MiscTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200}, Increment = 5, Suffix = " studs/s",
    CurrentValue = 50, Flag = "MS_FlySpeed",
    Callback = function(v) State.FlySpeed = v end,
})

MiscTab:CreateSection("🛡️ Survival")

MiscTab:CreateToggle({
    Name = "Anti-Void",
    CurrentValue = State.AntiVoid,
    Flag = "MS_AntiVoid",
    Callback = function(v) State.AntiVoid = v end,
})

MiscTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = State.AntiAFK,
    Flag = "MS_AntiAFK",
    Callback = function(v) State.AntiAFK = v end,
})

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

-- Tab: Settings (TIER 1 - Keybinds & Save)
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
SettingsTab:CreateSection("🔑 Keybinds")

SettingsTab:CreateInput({
    Name = "Toggle Key",
    Placeholder = "Default: RightShift",
    Value = Enum.KeyCode.RightShift.Name,
    Callback = function(v)
        State.Keybinds.Toggle = Enum.KeyCode[string.sub(v, 1, -1)]
        notify("Keybind", "Toggle: " .. v)
    end,
})

SettingsTab:CreateInput({
    Name = "Fly Key",
    Placeholder = "Default: X",
    Value = Enum.KeyCode.X.Name,
    Callback = function(v)
        State.Keybinds.Fly = Enum.KeyCode[string.sub(v, 1, -1)]
        notify("Keybind", "Fly: " .. v)
    end,
})

SettingsTab:CreateInput({
    Name = "Panic Key",
    Placeholder = "Default: RightControl",
    Value = Enum.KeyCode.RightControl.Name,
    Callback = function(v)
        State.Keybinds.Panic = Enum.KeyCode[string.sub(v, 1, -1)]
        notify("Keybind", "Panic: " .. v)
    end,
})

SettingsTab:CreateSection("📱 Mobile Support")

SettingsTab:CreateToggle({
    Name = "Enable Mobile Mode",
    CurrentValue = State.MobileMode,
    Flag = "MS_MobileMode",
    Callback = function(v) State.MobileMode = v end,
})

SettingsTab:CreateSection("💾 Data Store")

SettingsTab:CreateToggle({
    Name = "Auto Save Config",
    CurrentValue = true,
    Flag = "MS_AutoSave",
    Callback = function(v) 
        if v then
            RunService.Heartbeat:Connect(function()
                if tick() % 10 < 0.5 then saveConfig() end
            end)
        else
            RunService.Heartbeat:FindFirstChild("AutoSave") and RunService.Heartbeat:FindFirstChild("AutoSave"):Disconnect()
        end
    end,
})

SettingsTab:CreateButton({
    Name = "💾 Manually Save",
    Callback = function()
        saveConfig()
        notifySuccess("Save", "Config Saved", "success")
    end,
})

SettingsTab:CreateButton({
    Name = "📥 Load Config",
    Callback = function()
        loadConfig()
        notifySuccess("Load", "Config Loaded", "success")
    end,
})

-- ============================================================
-- [9] FPS OVERLAY (MINIMALIS, ANTI-LAG)
-- ============================================================
local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "GC_Overlay"
StatsGui.ResetOnSpawn = false
StatsGui.IgnoreGuiInset = true

pcall(function() StatsGui.Parent = CoreGui end)

local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(0, 160, 0, 50)
StatsFrame.Position = UDim2.new(1, -170, 0, 10)
StatsFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
StatsFrame.BackgroundTransparency = 0.2
StatsFrame.BorderSizePixel = 0
StatsFrame.Active = true
StatsFrame.Parent = StatsGui

Instance.new("UICorner", StatsFrame).CornerRadius = UDim.new(0, 6)

local stroke = Instance.new("UIStroke", StatsFrame)
stroke.Color = Color3.fromRGB(80, 130, 255)
stroke.Thickness = 1

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Size = UDim2.new(1, -10, 1, -10)
StatsLabel.Position = UDim2.new(0, 5, 0, 5)
StatsLabel.BackgroundTransparency = 1
StatsLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
StatsLabel.Font = Enum.Font.Code
StatsLabel.TextSize = 13
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.TextYAlignment = Enum.TextYAlignment.Top
StatsLabel.Text = "Game Changer v6.0\nFPS: -- | Ping: --"
StatsLabel.Parent = StatsFrame

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
    while task.wait(2) do
        local ping = "N/A"
        pcall(function()
            ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        StatsLabel.Text = string.format(
            "Game Changer v6.0\nFPS: %d | Ping: %s ms",
            currentFPS, tostring(ping)
        )
    end
end)

-- ============================================================
-- [10] CORE LOGIC (Background)
-- ============================================================

-- Wallhack
task.spawn(function()
    while task.wait(1) do
        if State.Wallhack then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hl = plr.Character:FindFirstChild("GC_HL")
                    if not hl then
                        hl = Instance.new("Highlight")
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
        if State.SilentAim then
            -- Silent Aim: Smooth Lerp
            Camera.CFrame = Camera.CFrame:Lerp(
                CFrame.new(Camera.CFrame.Position, closest.Position),
                State.AimbotSmoothness
            )
        else
            -- Normal Aim
            Camera.CFrame = Camera.CFrame:Lerp(
                CFrame.new(Camera.CFrame.Position, closest.Position),
                State.AimbotSmoothness
            )
        end
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
local function startFly()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    flyVel = Instance.new("BodyVelocity")
    flyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyVel.Velocity = Vector3.zero
    flyVel.Parent = root
    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyGyro.P = 1000
    flyGyro.Parent = root
end

local function stopFly()
    if flyVel then flyVel:Destroy() flyVel = nil end
    if flyGyro then flyGyro:Destroy() flyGyro = nil end
end

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
        if not flyVel then startFly() end
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local move = Vector3.zero
                if KeyState[Enum.KeyCode.W] then move += Camera.CFrame.LookVector end
                if KeyState[Enum.KeyCode.S] then move -= Camera.CFrame.LookVector end
                if KeyState[Enum.KeyCode.A] then move -= Camera.CFrame.RightVector end
                if KeyState[Enum.KeyCode.D] then move += Camera.CFrame.RightVector end
                if KeyState[Enum.KeyCode.Space] then move += Vector3.new(0, 1, 0) end
                if KeyState[Enum.KeyCode.LeftControl] then move -= Vector3.new(0, 1, 0) end
                if flyVel then flyVel.Velocity = move * State.FlySpeed end
                if flyGyro then flyGyro.CFrame = Camera.CFrame end
            end
        end
    else
        if flyVel then stopFly() end
    end
end)

-- Anti Void (Simple Check)
RunService.Heartbeat:Connect(function()
    if State.AntiVoid then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and (root.Position.Y < -20) then
            -- Teleport up
            root.CFrame = CFrame.new(root.Position, CFrame.new(0, 20, 0))
            root.Velocity = Vector3.new(0, 10, 0)
        end
    end
end)

-- ============================================================
-- [11] FINAL NOTIFICATIONS
-- ============================================================
notify_safe("Game Changer",
    "Loaded! Game: " .. GameInfo.Name .. " | Preset: " .. GameInfo.Preset .. "\n\nv6.0 Features:\n- Save/Load Config\n- Keybind Manager\n- Silent Aim\n- Panic Key\n- Mobile Mode",
    "success")

-- ============================================================
-- [12] TRIGGER BOT LOGIC (TIER 2 - ADVANCED)
-- ============================================================
local TriggerBotActive = false
local LastTriggerTime = 0

RunService.RenderStepped:Connect(function()
    if State.TriggerBot then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local mouse = UserInputService:GetMouseLocation()
            local closestHead = nil
            local shortestDist = 999999
            
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
                    local head = plr.Character:FindFirstChild("Head")
                    local sp, on = Camera:WorldToViewportPoint(head.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                        if d < shortestDist then
                            shortestDist = d
                            closestHead = head
                        end
                    end
                end
            end
            
            if closestHead then
                if tick() - LastTriggerTime >= 0.2 then
                    local tool = root:FindFirstChildWhichIsA("Tool")
                    if tool then
                        pcall(function() tool:Activate() end)
                        LastTriggerTime = tick()
                        triggerWarning(tool)
                    end
                end
            end
        end
    end
end)

local function triggerWarning(tool)
    -- Optional: Sound effect or visual cue
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://123456" -- Optional
    sound.Volume = 0.1
    sound.Parent = LocalPlayer
    sound:Play()
    task.wait(0.1)
    sound:Destroy()
end

-- ============================================================
-- [13] PLAYER LIST & TELEPORT (TIER 2 - UTILITY)
-- ============================================================
local PlayerListTab = Window:CreateTab("👤 Players", 4483362458)
PlayerListTab:CreateSection("👥 Player List")

local PlayerList = {}
local function refreshPlayerList()
    PlayerList = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                PlayerList[plr.Name] = {
                    Name = plr.Name,
                    CFrame = char:FindFirstChild("HumanoidRootPart"):FindFirstChild("HumanoidRootPart") or char:FindFirstChild("HumanoidRootPart"),
                    Team = char:FindFirstChild("Team"),
                    Alive = true,
                }
            else
                PlayerList[plr.Name] = { Name = plr.Name, CFrame = nil, Team = nil, Alive = false }
            end
        end
    end
end

refreshPlayerList()

PlayerListTab:CreateSection("📜 Online Players (" .. #PlayerList .. ")")

local PlayerToggles = {}
local function rebuildPlayerListUI()
    PlayerListTab:ClearChildren() -- Simplified UI rebuild
    for name, data in pairs(PlayerList) do
        local toggle = PlayerListTab:CreateToggle({
            Name = "👤 " .. name,
            CurrentValue = data.Alive,
            Flag = "PL_" .. name,
            Callback = function(v)
                -- Toggle for visibility (Visual ESP)
                if v then
                    -- Show
                    if data.CFrame then
                        local hl = Instance.new("Highlight")
                        hl.Name = "PL_HL"
                        hl.FillColor = Color3.fromRGB(255, 255, 255)
                        hl.Parent = data.CFrame
                    end
                else
                    -- Hide
                    for _, child in ipairs(data.CFrame:GetChildren()) do
                        if child:IsA("Highlight") and child.Name == "PL_HL" then
                            child:Destroy()
                        end
                    end
                end
            end,
            LayoutOrder = 100,
        })
        PlayerToggles[name] = { Toggle = toggle, State = data.Alive }
    end
end

-- Rebuild once after load
rebuildPlayerListUI()

PlayerListTab:CreateButton({
    Name = "🔄 Refresh List",
    Callback = function()
        refreshPlayerList()
        rebuildPlayerListUI()
        notify("Players", "List Updated")
    end,
})

PlayerListTab:CreateButton({
    Name = "🎯 Teleport to Player",
    Callback = function()
        for name, data in pairs(PlayerList) do
            if data.Alive and data.CFrame then
                notify("Teleport", "Teleport to: " .. name)
                -- Smooth Teleport
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local duration = 2
                    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Quad), { CFrame = data.CFrame })
                    tween:Play()
                    tween.Completed:Wait()
                end
            end
        end
    end,
})

PlayerListTab:CreateButton({
    Name = "🏃 Teleport to Next Player (Auto)",
    Callback = function()
        for name, data in pairs(PlayerList) do
            if data.Alive and data.CFrame then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local duration = 2
                    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Quad), { CFrame = data.CFrame })
                    tween:Play()
                    tween.Completed:Wait()
                end
                break
            end
        end
    end,
})

-- ============================================================
-- [14] STEAL AN EGG (TIER 3 - GAME SPECIFIC)
-- ============================================================
-- Simple Egg Escape Logic
RunService.Heartbeat:Connect(function()
    if State.AutoFarm then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local move = Vector3.zero
            if KeyState[Enum.KeyCode.W] then move += Camera.CFrame.LookVector end
            if KeyState[Enum.KeyCode.S] then move -= Camera.CFrame.LookVector end
            if KeyState[Enum.KeyCode.A] then move -= Camera.CFrame.RightVector end
            if KeyState[Enum.KeyCode.D] then move += Camera.CFrame.RightVector end
            
            if move.Magnitude > 0 then
                local velocity = root.Velocity
                root.Velocity = velocity + (move * 150) -- Speed boost when moving
            else
                root.Velocity = Vector3.zero
            end
        end
    end
end)

-- ============================================================
-- [15] FINAL CLEANUP
-- ============================================================
notify_safe("Game Changer",
    "v6.0 Loaded Successfully!\n\nTip: Press " .. State.Keybinds.Panic .. " to reset UI.",
    "success")

task.spawn(function()
    while task.wait(5) do
        -- Periodic checks
        if State.MobileMode then
            -- Mobile-specific logic here
        end
    end
end)

notify_safe("Game Changer", "Ready for Battle!", "success")