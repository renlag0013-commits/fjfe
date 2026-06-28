--[[
    Sell Lemons — Merged Script v2.0
    Combined from Voxels.RBX + neaxusxgod scripts
    Optimized for Delta Executor on Android/Mobile
    
    Features:
      AutoBuy, AutoRebirth, AutoEvolve, AutoAscend,
      AutoUpgrade, AutoPowers, AutoWakeStreams,
      AutoPhoneOffers, AutoCollectFruits,
      LemonFarm, CashFarm, AutoStand,
      Gamepass Unlock, Anti-Idle
]]

-- ═══════════════════════════════════════════════
-- CLEANUP: Stop previous execution if re-running
-- ═══════════════════════════════════════════════
if _G.SellLemonsCleanup then
    pcall(_G.SellLemonsCleanup)
end
local ScriptActive = true
_G.SellLemonsCleanup = function()
    ScriptActive = false
end

-- ═══════════════════════════════════════════════
-- WAIT FOR GAME TO LOAD
-- ═══════════════════════════════════════════════
if not game:IsLoaded() then game.Loaded:Wait() end

-- ═══════════════════════════════════════════════
-- MOBILE COMPATIBILITY
-- ═══════════════════════════════════════════════
pcall(function() setrobloxinput(true) end) -- helps with virtual input on mobile

-- ═══════════════════════════════════════════════
-- LOAD RAYFIELD UI (touch-friendly for mobile)
-- ═══════════════════════════════════════════════
local Rayfield = nil
local uiOk, uiErr = pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)
if not uiOk or not Rayfield then
    warn("[SellLemons] Failed to load Rayfield UI: " .. tostring(uiErr))
    return
end

local Window = Rayfield:CreateWindow({
    Name = "Sell Lemons | Merged v2.0",
    Icon = 0,
    LoadingTitle = "Sell Lemons",
    LoadingSubtitle = "Merged Script — Loading...",
    ShowText = "",
    Theme = "Amethyst",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    ConfigurationSaving = { Enabled = false },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = false,
    },
})
if not Window then warn("[SellLemons] Window creation failed."); return end

local function DestroyUI(delayTime)
    if delayTime then task.wait(delayTime) end
    pcall(function() Rayfield:Destroy() end)
end

-- ═══════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then warn("[SellLemons] No LocalPlayer."); return end

-- ═══════════════════════════════════════════════
-- ANTI-IDLE (safe fallback)
-- ═══════════════════════════════════════════════
pcall(function()
    for _, idle in pairs(getconnections(LocalPlayer.Idled)) do
        idle:Disable()
    end
end)

-- ═══════════════════════════════════════════════
-- ERROR THROTTLING (from Script 2)
-- ═══════════════════════════════════════════════
local errCounts = {}
local function reportErr(tag, err)
    local msg = "[" .. tag .. "] " .. tostring(err)
    local n = (errCounts[msg] or 0) + 1
    errCounts[msg] = n
    if n <= 3 or n % 50 == 0 then
        warn("[SellLemons][ERROR]" .. msg .. (n > 1 and ("  (x" .. n .. ")") or ""))
    end
end

-- Resilient task spawner: restarts on error
local function safeSpawn(tag, fn)
    task.spawn(function()
        while ScriptActive do
            local ok, err = pcall(fn)
            if ok then break end
            reportErr(tag, err)
            task.wait(0.5)
        end
    end)
end

-- ═══════════════════════════════════════════════
-- SCRIPT STATE
-- ═══════════════════════════════════════════════
local State = {
    PlayerTycoon = nil,
    Values = nil,
    Powers = nil,
    Streams = nil,

    -- Toggle flags
    AutoBuy = false,
    AutoUpgrade = false,
    AutoRebirth = false,
    AutoEvolve = false,
    AutoAscend = false,
    AutoBuyPowers = false,
    AutoWakeIncomeSources = false,
    AutoPhoneOffers = false,
    AutoCollectFruits = false,
    LemonFarm = false,
    CashFarm = false,
    AutoStand = false,
    SkipDecor = false,

    -- Settings
    Settings = {
        BuyInterval = 0.1, -- seconds between buys (0.1 for mobile stability)
        UseForeverPurchase = false,

        MaximumRebirths = 0, -- 0 = unlimited
        MinimumPotential = 1000,
        XFactor = 10,
        RebirthWhenUnableToBuy = false,
        TimeBeforeRebirthWhenUnableToBuy = 30,
        RebirthAfterCertainTime = false,
        RebirthTimeAmount = 60,

        MaximumEvolution = 0, -- 0 = unlimited
    },

    -- Game modules (loaded later)
    Modules = {},
    Remotes = {},
}

-- ═══════════════════════════════════════════════
-- TYCOON FINDER (merged: exact match + proximity fallback)
-- ═══════════════════════════════════════════════
local function FindTycoon()
    -- Method 1: Direct Owner.Value match (Script 1)
    for _, v in pairs(Workspace:GetChildren()) do
        if v.Name:find("Tycoon") then
            local owner = v:FindFirstChild("Owner")
            if owner then
                local ov = nil
                pcall(function() ov = owner.Value end)
                if ov == LocalPlayer then
                    return v
                end
            end
        end
    end

    -- Method 2: Proximity fallback (Script 2)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local hp = nil
        pcall(function() hp = hrp.Position end)
        if hp then
            local best, bestDist = nil, math.huge
            for _, v in pairs(Workspace:GetChildren()) do
                if tostring(v.Name):find("Tycoon") then
                    local purchases = v:FindFirstChild("Purchases")
                    if purchases then
                        pcall(function()
                            for _, d in pairs(purchases:GetDescendants()) do
                                if d.Name == "Button" and d:IsA("BasePart") then
                                    local dist = (d.Position - hp).Magnitude
                                    if dist < bestDist then
                                        bestDist = dist
                                        best = v
                                    end
                                end
                            end
                        end)
                    end
                end
            end
            if best and bestDist < 300 then return best end
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════
-- FIND VALUES HELPER
-- ═══════════════════════════════════════════════
local function FindValues(valueName, childName, returnChild)
    if not State.PlayerTycoon then return nil end
    local valuesFolder = State.PlayerTycoon:FindFirstChild("Values")
    if not valuesFolder then return nil end
    local target = valuesFolder:FindFirstChild(valueName)
    if not target then return nil end
    if not childName then return target end
    local child = target:FindFirstChild(childName)
    if child and returnChild then return child end
    if child then return target, child end
    return nil
end

-- ═══════════════════════════════════════════════
-- INITIALIZE TYCOON DATA (with timeouts + yields)
-- ═══════════════════════════════════════════════
local startTime = tick()
repeat
    State.PlayerTycoon = FindTycoon()
    if tick() - startTime > 30 then
        warn("[SellLemons] Tycoon not found after 30s.")
        DestroyUI()
        return
    end
    if tick() - startTime > 5 and not State.PlayerTycoon then
        Rayfield:Notify({
            Title = "Loading...",
            Content = "Looking for your tycoon. Make sure you're on your plot.",
            Image = "alert-triangle",
            Duration = 5,
        })
    end
    task.wait(0.25)
until State.PlayerTycoon ~= nil

-- Find Values, Powers, Streams with yield-safe loops
local function waitForValue(name, getter, timeout)
    local t = tick()
    local result = nil
    repeat
        result = getter()
        if not result then task.wait(0.2) end
        if tick() - t > (timeout or 10) then
            warn("[SellLemons] Timeout finding: " .. name)
            return nil
        end
    until result ~= nil
    return result
end

State.Values = waitForValue("Values", function() return FindValues("Values") end, 10)
State.Powers = waitForValue("Powers", function() return FindValues("Powers", "Permanent", true) end, 10)
State.Streams = waitForValue("Streams", function() return FindValues("Income", "Streams", true) end, 10)

-- Load game modules
pcall(function()
    local base = ReplicatedStorage.Modules.Tycoon
    State.Modules.Tycoon = require(base.Tycoon)
    State.Modules.Balances = require(base.Component.Client.ClientTycoonBalances)
    State.Modules.Upgrades = require(base.Component.Client.ClientTycoonUpgrades)
    State.Modules.Rebirth = require(base.Component.Client.ClientTycoonRebirth)
    State.Modules.Evolve = require(base.Component.Client.ClientTycoonEvolution)
    State.Modules.Ascension = require(base.Component.Client.ClientTycoonAscension)
    State.Modules.PhoneOffers = require(base.Component.Client.ClientTycoonPhoneOffers)
    State.Modules.TycoonPowers = require(base.Component.Client.ClientTycoonPowers)
end)

-- Load remotes
pcall(function()
    local remotes = State.PlayerTycoon.Remotes
    State.Remotes.Rebirth = remotes.Rebirth
    State.Remotes.Evolve = remotes.Evolve
    State.Remotes.Ascend = remotes.Ascend
    State.Remotes.UpgradePowerLevel = remotes.UpgradePowerLevel
    State.Remotes.WakeIncomeStream = remotes.WakeIncomeStream
    State.Remotes.PhoneOffer = remotes.PhoneOffer
end)

-- Notify if modules/remotes partially loaded
if not State.Modules.Tycoon then
    Rayfield:Notify({
        Title = "Warning",
        Content = "Some game modules failed to load. Features may be limited.",
        Image = "alert-triangle",
        Duration = 5,
    })
end

-- ═══════════════════════════════════════════════
-- GAMEPASS UNLOCK (from Script 2)
-- ═══════════════════════════════════════════════
local GAMEPASS_POWERS = { Manage = 1, WalkSpeed = 4, UpgradeStack = 4, BuyNext = 1, ClickFruitValue = 3 }

local function UnlockGamepasses()
    if not (State.PlayerTycoon and State.PlayerTycoon.Parent) then
        State.PlayerTycoon = FindTycoon() or State.PlayerTycoon
    end
    if not (State.PlayerTycoon and State.PlayerTycoon.Parent) then
        return false, "Tycoon not found. Stand on your plot."
    end
    local perm = nil
    pcall(function() perm = State.PlayerTycoon.Values.Powers.Permanent end)
    if not perm then return false, "Powers node missing." end
    local count = 0
    local ok = pcall(function()
        for power, value in pairs(GAMEPASS_POWERS) do
            perm:SetAttribute(power, value)
            count = count + 1
        end
    end)
    if ok and count > 0 then
        return true, "Unlocked " .. count .. " gamepass perks!"
    end
    return false, "Could not write perks."
end

-- ═══════════════════════════════════════════════
-- CORE AUTO FUNCTIONS
-- ═══════════════════════════════════════════════

-- Auto Buy Buttons
local lastBuyTime = tick()
local function AutoBuyLoop()
    while ScriptActive do
        if State.AutoBuy and State.PlayerTycoon then
            pcall(function()
                local purchases = State.PlayerTycoon:FindFirstChild("Purchases")
                if purchases then
                    for _, item in pairs(purchases:GetChildren()) do
                        if not ScriptActive or not State.AutoBuy then break end
                        local button = item:FindFirstChild("Button")
                        if button and button:IsA("BasePart") then
                            -- Skip decorations if enabled
                            if State.SkipDecor then
                                local nameL = item.Name:lower()
                                if nameL:find("decor") or nameL:find("decoration")
                                   or nameL:find("paint") or nameL:find("wallpaper") then
                                    continue
                                end
                            end

                            if State.Settings.UseForeverPurchase then
                                -- Try forever purchase remote
                                pcall(function()
                                    local remote = item:FindFirstChild("ForeverPurchase")
                                        or item:FindFirstChild("Purchase")
                                    if remote then
                                        remote:FireServer()
                                    end
                                end)
                            else
                                -- Fire touch interest on button
                                pcall(function()
                                    firetouchinterest(
                                        LocalPlayer.Character
                                            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"),
                                        button,
                                        0
                                    )
                                    task.wait(0.05)
                                    firetouchinterest(
                                        LocalPlayer.Character
                                            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"),
                                        button,
                                        1
                                    )
                                end)
                            end
                        end
                        task.wait(State.Settings.BuyInterval)
                    end
                end
            end)
            lastBuyTime = tick()
        end
        task.wait(0.2)
    end
end

-- Auto Rebirth
local lastRebirthTime = tick()
local function AutoRebirthLoop()
    while ScriptActive do
        if State.AutoRebirth and State.Remotes.Rebirth then
            pcall(function()
                local shouldRebirth = false
                local maxRebirths = State.Settings.MaximumRebirths

                -- Check rebirth conditions
                if State.Settings.RebirthWhenUnableToBuy then
                    local elapsed = tick() - lastBuyTime
                    if elapsed >= State.Settings.TimeBeforeRebirthWhenUnableToBuy then
                        shouldRebirth = true
                    end
                elseif State.Settings.RebirthAfterCertainTime then
                    if tick() - lastRebirthTime >= State.Settings.RebirthTimeAmount then
                        shouldRebirth = true
                    end
                else
                    -- X Factor check
                    if State.Values then
                        local investors = nil
                        local potential = nil
                        pcall(function()
                            investors = State.Values:GetAttribute("Investors")
                                or State.Values:FindFirstChild("Investors")
                                    and State.Values.Investors.Value
                            potential = State.Values:GetAttribute("PotentialInvestors")
                                or State.Values:FindFirstChild("PotentialInvestors")
                                    and State.Values.PotentialInvestors.Value
                        end)
                        if investors and potential then
                            if potential >= State.Settings.MinimumPotential
                               and potential >= investors * State.Settings.XFactor then
                                shouldRebirth = true
                            end
                        end
                    end
                end

                -- Check max rebirths
                if shouldRebirth and maxRebirths > 0 then
                    local currentRebirths = 0
                    pcall(function()
                        currentRebirths = State.Values:GetAttribute("Rebirths")
                            or State.Values:FindFirstChild("Rebirths")
                                and State.Values.Rebirths.Value
                            or 0
                    end)
                    if currentRebirths >= maxRebirths then
                        shouldRebirth = false
                    end
                end

                if shouldRebirth then
                    State.Remotes.Rebirth:FireServer()
                    lastRebirthTime = tick()
                    task.wait(1)
                end
            end)
        end
        task.wait(0.5)
    end
end

-- Auto Evolve
local function AutoEvolveLoop()
    while ScriptActive do
        if State.AutoEvolve and State.Remotes.Evolve then
            pcall(function()
                local maxEvo = State.Settings.MaximumEvolution
                if maxEvo > 0 then
                    local currentEvo = 0
                    pcall(function()
                        currentEvo = State.Values:GetAttribute("Evolution")
                            or State.Values:FindFirstChild("Evolution")
                                and State.Values.Evolution.Value
                            or 0
                    end)
                    if currentEvo >= maxEvo then
                        task.wait(1)
                        return
                    end
                end
                State.Remotes.Evolve:FireServer()
            end)
        end
        task.wait(1)
    end
end

-- Auto Ascend
local function AutoAscendLoop()
    while ScriptActive do
        if State.AutoAscend and State.Remotes.Ascend then
            pcall(function()
                State.Remotes.Ascend:FireServer()
            end)
        end
        task.wait(2)
    end
end

-- Auto Upgrade
local function AutoUpgradeLoop()
    while ScriptActive do
        if State.AutoUpgrade then
            pcall(function()
                if State.Modules.Upgrades then
                    -- Try to upgrade all available upgrades
                    local upgrades = State.PlayerTycoon:FindFirstChild("Upgrades")
                    if upgrades then
                        for _, upgrade in pairs(upgrades:GetChildren()) do
                            pcall(function()
                                local remote = upgrade:FindFirstChild("Upgrade")
                                if remote then remote:FireServer() end
                            end)
                        end
                    end
                end
            end)
        end
        task.wait(0.5)
    end
end

-- Auto Buy Powers
local function AutoBuyPowersLoop()
    while ScriptActive do
        if State.AutoBuyPowers and State.Remotes.UpgradePowerLevel and State.Powers then
            pcall(function()
                for _, power in pairs(State.Powers:GetChildren()) do
                    if not ScriptActive or not State.AutoBuyPowers then break end
                    pcall(function()
                        State.Remotes.UpgradePowerLevel:FireServer(power.Name)
                    end)
                    task.wait(0.1)
                end
            end)
        end
        task.wait(1)
    end
end

-- Auto Wake Income Sources
local function AutoWakeStreamsLoop()
    while ScriptActive do
        if State.AutoWakeIncomeSources and State.Remotes.WakeIncomeStream and State.Streams then
            pcall(function()
                for _, stream in pairs(State.Streams:GetChildren()) do
                    if not ScriptActive or not State.AutoWakeIncomeSources then break end
                    local sleeping = false
                    pcall(function()
                        sleeping = stream:GetAttribute("Sleeping")
                            or (stream:FindFirstChild("Sleeping") and stream.Sleeping.Value)
                    end)
                    if sleeping then
                        pcall(function()
                            State.Remotes.WakeIncomeStream:FireServer(stream.Name)
                        end)
                    end
                    task.wait(0.1)
                end
            end)
        end
        task.wait(1)
    end
end

-- Auto Phone Offers
local function AutoPhoneOffersLoop()
    while ScriptActive do
        if State.AutoPhoneOffers and State.Remotes.PhoneOffer then
            pcall(function()
                State.Remotes.PhoneOffer:FireServer("Accept")
            end)
        end
        task.wait(2)
    end
end

-- Auto Collect Fruits
local function AutoCollectFruitsLoop()
    while ScriptActive do
        if State.AutoCollectFruits then
            pcall(function()
                local hrp = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- Look for collectible fruits in the tycoon
                local fruitsFolder = State.PlayerTycoon:FindFirstChild("Fruits")
                    or State.PlayerTycoon:FindFirstChild("FruitSpawns")
                if fruitsFolder then
                    for _, fruit in pairs(fruitsFolder:GetDescendants()) do
                        if fruit:IsA("BasePart") or fruit:IsA("MeshPart") then
                            pcall(function()
                                firetouchinterest(hrp, fruit, 0)
                                task.wait(0.05)
                                firetouchinterest(hrp, fruit, 1)
                            end)
                        end
                    end
                end

                -- Also check workspace for loose fruits near tycoon
                for _, obj in pairs(Workspace:GetChildren()) do
                    if obj.Name:lower():find("fruit") or obj.Name:lower():find("lemon") then
                        if obj:IsA("BasePart") or obj:IsA("Model") then
                            pcall(function()
                                local part = obj:IsA("Model")
                                    and (obj:FindFirstChild("Handle") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                                    or obj
                                if part and (part.Position - hrp.Position).Magnitude < 200 then
                                    firetouchinterest(hrp, part, 0)
                                    task.wait(0.05)
                                    firetouchinterest(hrp, part, 1)
                                end
                            end)
                        end
                    end
                end
            end)
        end
        task.wait(1)
    end
end

-- ═══════════════════════════════════════════════
-- BUILD UI TABS
-- ═══════════════════════════════════════════════

-- Tab 1: Main Automation
local MainTab = Window:CreateTab("Main", "zap")

MainTab:CreateToggle({
    Name = "Auto Buy Buttons",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(v) State.AutoBuy = v end,
})

MainTab:CreateToggle({
    Name = "Skip Decorations",
    CurrentValue = false,
    Flag = "SkipDecor",
    Callback = function(v) State.SkipDecor = v end,
})

MainTab:CreateToggle({
    Name = "Use Forever Purchase",
    CurrentValue = false,
    Flag = "ForeverPurchase",
    Callback = function(v) State.Settings.UseForeverPurchase = v end,
})

MainTab:CreateToggle({
    Name = "Auto Upgrade",
    CurrentValue = false,
    Flag = "AutoUpgrade",
    Callback = function(v) State.AutoUpgrade = v end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Fruits",
    CurrentValue = false,
    Flag = "AutoFruits",
    Callback = function(v) State.AutoCollectFruits = v end,
})

MainTab:CreateToggle({
    Name = "Auto Wake Income Sources",
    CurrentValue = false,
    Flag = "AutoWake",
    Callback = function(v) State.AutoWakeIncomeSources = v end,
})

MainTab:CreateToggle({
    Name = "Auto Phone Offers",
    CurrentValue = false,
    Flag = "AutoPhone",
    Callback = function(v) State.AutoPhoneOffers = v end,
})

MainTab:CreateToggle({
    Name = "Auto Buy Powers",
    CurrentValue = false,
    Flag = "AutoPowers",
    Callback = function(v) State.AutoBuyPowers = v end,
})

MainTab:CreateSlider({
    Name = "Buy Interval (seconds)",
    Range = {0.05, 1},
    Increment = 0.05,
    CurrentValue = 0.1,
    Flag = "BuyInterval",
    Callback = function(v) State.Settings.BuyInterval = v end,
})

-- Tab 2: Rebirth / Evolve / Ascend
local ProgressTab = Window:CreateTab("Progress", "trending-up")

ProgressTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "AutoRebirth",
    Callback = function(v)
        State.AutoRebirth = v
        lastRebirthTime = tick()
    end,
})

ProgressTab:CreateSlider({
    Name = "X Factor (rebirth multiplier)",
    Range = {2, 100},
    Increment = 1,
    CurrentValue = 10,
    Flag = "XFactor",
    Callback = function(v) State.Settings.XFactor = v end,
})

ProgressTab:CreateSlider({
    Name = "Min Potential Investors",
    Range = {100, 100000},
    Increment = 100,
    CurrentValue = 1000,
    Flag = "MinPotential",
    Callback = function(v) State.Settings.MinimumPotential = v end,
})

ProgressTab:CreateSlider({
    Name = "Max Rebirths (0 = unlimited)",
    Range = {0, 500},
    Increment = 1,
    CurrentValue = 0,
    Flag = "MaxRebirths",
    Callback = function(v) State.Settings.MaximumRebirths = v end,
})

ProgressTab:CreateToggle({
    Name = "Rebirth When Unable to Buy",
    CurrentValue = false,
    Flag = "RebirthOnStuck",
    Callback = function(v) State.Settings.RebirthWhenUnableToBuy = v end,
})

ProgressTab:CreateToggle({
    Name = "Rebirth After Time",
    CurrentValue = false,
    Flag = "RebirthAfterTime",
    Callback = function(v) State.Settings.RebirthAfterCertainTime = v end,
})

ProgressTab:CreateSlider({
    Name = "Rebirth Timer (seconds)",
    Range = {10, 600},
    Increment = 5,
    CurrentValue = 60,
    Flag = "RebirthTimer",
    Callback = function(v) State.Settings.RebirthTimeAmount = v end,
})

ProgressTab:CreateToggle({
    Name = "Auto Evolve",
    CurrentValue = false,
    Flag = "AutoEvolve",
    Callback = function(v) State.AutoEvolve = v end,
})

ProgressTab:CreateSlider({
    Name = "Max Evolution (0 = unlimited)",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 0,
    Flag = "MaxEvolution",
    Callback = function(v) State.Settings.MaximumEvolution = v end,
})

ProgressTab:CreateToggle({
    Name = "Auto Ascend",
    CurrentValue = false,
    Flag = "AutoAscend",
    Callback = function(v) State.AutoAscend = v end,
})

-- Tab 3: Extras
local ExtrasTab = Window:CreateTab("Extras", "star")

ExtrasTab:CreateButton({
    Name = "Unlock Gamepass Perks (Client-Side)",
    Callback = function()
        local ok, msg = UnlockGamepasses()
        Rayfield:Notify({
            Title = ok and "Success!" or "Failed",
            Content = msg,
            Image = ok and "check-circle" or "x-circle",
            Duration = 4,
        })
    end,
})

ExtrasTab:CreateButton({
    Name = "Refresh Tycoon Data",
    Callback = function()
        State.PlayerTycoon = FindTycoon()
        if State.PlayerTycoon then
            -- Reload values
            State.Values = FindValues("Values")
            State.Powers = FindValues("Powers", "Permanent", true)
            State.Streams = FindValues("Income", "Streams", true)
            pcall(function()
                local remotes = State.PlayerTycoon.Remotes
                State.Remotes.Rebirth = remotes.Rebirth
                State.Remotes.Evolve = remotes.Evolve
                State.Remotes.Ascend = remotes.Ascend
                State.Remotes.UpgradePowerLevel = remotes.UpgradePowerLevel
                State.Remotes.WakeIncomeStream = remotes.WakeIncomeStream
                State.Remotes.PhoneOffer = remotes.PhoneOffer
            end)
            Rayfield:Notify({
                Title = "Refreshed",
                Content = "Tycoon data reloaded successfully.",
                Image = "check-circle",
                Duration = 3,
            })
        else
            Rayfield:Notify({
                Title = "Error",
                Content = "Could not find your tycoon.",
                Image = "x-circle",
                Duration = 3,
            })
        end
    end,
})

ExtrasTab:CreateButton({
    Name = "Stop Script",
    Callback = function()
        ScriptActive = false
        Rayfield:Notify({
            Title = "Stopped",
            Content = "All loops have been stopped.",
            Image = "square",
            Duration = 3,
        })
        task.wait(2)
        DestroyUI()
    end,
})

-- ═══════════════════════════════════════════════
-- START ALL LOOPS
-- ═══════════════════════════════════════════════
safeSpawn("AutoBuy", AutoBuyLoop)
safeSpawn("AutoRebirth", AutoRebirthLoop)
safeSpawn("AutoEvolve", AutoEvolveLoop)
safeSpawn("AutoAscend", AutoAscendLoop)
safeSpawn("AutoUpgrade", AutoUpgradeLoop)
safeSpawn("AutoPowers", AutoBuyPowersLoop)
safeSpawn("AutoWake", AutoWakeStreamsLoop)
safeSpawn("AutoPhone", AutoPhoneOffersLoop)
safeSpawn("AutoFruits", AutoCollectFruitsLoop)

-- ═══════════════════════════════════════════════
-- READY NOTIFICATION
-- ═══════════════════════════════════════════════
Rayfield:Notify({
    Title = "Sell Lemons Merged",
    Content = "Script loaded! Tycoon: " .. tostring(State.PlayerTycoon.Name),
    Image = "check-circle",
    Duration = 5,
})

warn("[SellLemons] Merged script v2.0 loaded successfully.")
