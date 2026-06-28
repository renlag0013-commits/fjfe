if _G.MatchaCleanup then pcall(_G.MatchaCleanup) end
local ScriptActive = true

-- Optimized Localizations
local mfloor, mabs            = math.floor, math.abs
local msin                    = math.sin
local tinsert                 = table.insert
local ipairs_, pairs_         = ipairs, pairs
local tostring_, tonumber_    = tostring, tonumber
local pcall_                  = pcall
local task_wait, task_spawn   = task.wait, task.spawn
local tick_                   = tick
local sformat                 = string.format
local Vec2, Vec3              = Vector2.new, Vector3.new
local CF                      = CFrame.new
local C3rgb                   = Color3.fromRGB

local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "selllemons_config.json"

local function clamp(x, a, b)
    if x < a then return a elseif x > b then return b else return x end
end
local function lerp(a, b, t) return a + (b - a) * t end

local DEBUG = false
local rprint = print
local print = function(...)
    if DEBUG then rprint(...) end
end

-- Core Game Service & Instance Initialization Loop
local Players, RunService, Workspace, player, camera
local initAttempts = 0
while not player and initAttempts < 50 do
    initAttempts = initAttempts + 1
    pcall_(function()
        Players    = game:GetService("Players")
        RunService = game:GetService("RunService")
        Workspace  = game:GetService("Workspace")
        player     = Players.LocalPlayer
        if player then camera = Workspace.CurrentCamera end
    end)
    if not player then task_wait(0.1) end
end
if not player then warn("[Hub] No LocalPlayer"); return end
if not camera then camera = Workspace.CurrentCamera end

local GuiService; pcall_(function() GuiService = game:GetService("GuiService") end)

-- Internal Utility Functions
local function WorldToScreen(pos)
    if not camera then return nil, false end
    local wp, on = camera:WorldToViewportPoint(pos)
    return Vec2(wp.X, wp.Y), on
end

setrobloxinput(true)

local mouse = nil
pcall_(function() mouse = player:GetMouse() end)

local errCounts = {}
local function reportErr(tag, err)
    local msg = "[" .. tag .. "] " .. tostring_(err)
    local n = (errCounts[msg] or 0) + 1
    errCounts[msg] = n
    if n <= 3 or n % 50 == 0 then
        rprint("[Hub][ERROR]" .. msg .. (n > 1 and ("  (x" .. n .. ")") or ""))
    end
end

local function _wrap(tag, fn)
    task_spawn(function()
        while ScriptActive do
            local ok, err = pcall_(fn)
            if ok then break end
            reportErr(tag, err)
            task_wait(0.5)
        end
    end)
end

-- Global Configurations & Runtime Automation States
local autoBuyActive       = false
local skipDecorActive     = false
local lemonFarmActive     = false
local cashFarmActive      = true
local autoStandActive     = false
local autoDealActive      = true
local autoRebirthActive   = false
local autoEvolveActive    = false
local autoAscendActive    = false
local autoWakeActive      = false
local autoBuyPowersActive = false
local disable3dActive     = false

local evolveProgress      = 0
local keyEspActive        = false
local _standIsTapping     = false

local CFG = {
    buyWindow = 0.45,
    afkDelay  = 6,
    zoomTicks = 22,
    zoomStep  = 1,
    standRest = 60,
    vineCd    = 4 * 3600,
    buyStuck  = 6,
    cheerY    = 0.85,
    exitY     = 0.76,
}

local S = {
    lastUser = tick_(), pmx = 0, pmy = 0, keyDown = {}, lastFire = {},
}

local RB = { 
    mult = 2, 
    lastPeek = 0, 
    lastReb = 0, 
    goSince = 0, 
    peekEvery = 60, 
    go = false, 
    status = "off",
    gainPct = 25,
    xFactor = 1.0,
    maxTime = 600,
    stallTime = 60,
    lastRebirthTime = tick_(),
    lastButtonBoughtTime = tick_()
}

local ASC = { ready = false, busyT = 0, bought = 0, total = 0 }
local STATS = { bought = 0, deals = 0, lemons = 0, bags = 0, rebirths = 0, evolves = 0, ascends = 0 }
local statsStartT = tick_()

-- Configuration Management System (JSON Persistence)
local function saveSettings()
    local data = {
        autoBuyActive       = autoBuyActive,
        skipDecorActive     = skipDecorActive,
        lemonFarmActive     = lemonFarmActive,
        cashFarmActive      = cashFarmActive,
        autoStandActive     = autoStandActive,
        autoDealActive      = autoDealActive,
        autoRebirthActive   = autoRebirthActive,
        autoEvolveActive    = autoEvolveActive,
        autoAscendActive    = autoAscendActive,
        autoWakeActive      = autoWakeActive,
        autoBuyPowersActive = autoBuyPowersActive,
        disable3dActive     = disable3dActive,
        gainPct             = RB.gainPct,
        xFactor             = RB.xFactor,
        maxTime             = RB.maxTime,
        stallTime           = RB.stallTime,
        afkDelay            = CFG.afkDelay
    }
    pcall_(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function loadSettings()
    pcall_(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local data = HttpService:JSONDecode(raw)
            if data then
                if data.autoBuyActive ~= nil then autoBuyActive = data.autoBuyActive end
                if data.skipDecorActive ~= nil then skipDecorActive = data.skipDecorActive end
                if data.lemonFarmActive ~= nil then lemonFarmActive = data.lemonFarmActive end
                if data.cashFarmActive ~= nil then cashFarmActive = data.cashFarmActive end
                if data.autoStandActive ~= nil then autoStandActive = data.autoStandActive end
                if data.autoDealActive ~= nil then autoDealActive = data.autoDealActive end
                if data.autoRebirthActive ~= nil then autoRebirthActive = data.autoRebirthActive end
                if data.autoEvolveActive ~= nil then autoEvolveActive = data.autoEvolveActive end
                if data.autoAscendActive ~= nil then autoAscendActive = data.autoAscendActive end
                if data.autoWakeActive ~= nil then autoWakeActive = data.autoWakeActive end
                if data.autoBuyPowersActive ~= nil then autoBuyPowersActive = data.autoBuyPowersActive end
                if data.disable3dActive ~= nil then disable3dActive = data.disable3dActive end
                if data.gainPct ~= nil then RB.gainPct = data.gainPct end
                if data.xFactor ~= nil then RB.xFactor = data.xFactor end
                if data.maxTime ~= nil then RB.maxTime = data.maxTime end
                if data.stallTime ~= nil then RB.stallTime = data.stallTime end
                if data.afkDelay ~= nil then CFG.afkDelay = data.afkDelay end
            end
        end
    end)
end

S.saveState = saveSettings
loadSettings()

-- Performance Optimization Utility
local function toggle3dRendering(enable)
    pcall_(function()
        RunService:Set3dRenderingEnabled(enable)
    end)
end
toggle3dRendering(not disable3dActive)

-- Dynamic Plot Tracking System
local myTycoon = nil
local function findMyTycoon()
    local pname = player.Name
    for _, tycoon in ipairs_(Workspace:GetChildren()) do
        if tostring_(tycoon.Name):find("Tycoon") then
            local owner = tycoon:FindFirstChild("Owner")
            if owner then
                local ov; pcall_(function() ov = owner.Value end)
                if ov == player or (ov and tostring_(ov):find(pname, 1, true)) then return tycoon end
            end
        end
    end

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local hp; pcall_(function() hp = hrp and hrp.Position end)
    if hp then
        local best, bestD
        for _, tycoon in ipairs_(Workspace:GetChildren()) do
            if tostring_(tycoon.Name):find("Tycoon") then
                local pur = tycoon:FindFirstChild("Purchases")
                if pur then
                    pcall_(function()
                        for _, d in ipairs_(pur:GetDescendants()) do
                            if d.Name == "Button" and d:IsA("BasePart") and d.Parent then
                                local dd = (d.Position - hp).Magnitude
                                if not bestD or dd < bestD then bestD = dd; best = tycoon end
                            end
                        end
                    end)
                end
            end
        end
        if best and bestD and bestD < 300 then return best end
    end
    return nil
end
myTycoon = findMyTycoon()

-- Automation Injectors & Perks
local GAMEPASS_POWERS = { Manage = 1, WalkSpeed = 4, UpgradeStack = 4, BuyNext = 1, ClickFruitValue = 3 }
local function unlockGamepasses()
    if not (myTycoon and myTycoon.Parent) then myTycoon = findMyTycoon() or myTycoon end
    local t = myTycoon
    if not (t and t.Parent) then return false, "tycoon not found - stand on your plot, then retry" end
    local perm
    pcall_(function() perm = t.Values.Powers.Permanent end)
    if not perm then return false, "powers node missing (game update?)" end
    local n = 0
    local ok = pcall_(function()
        for power, value in pairs_(GAMEPASS_POWERS) do perm:SetAttribute(power, value); n = n + 1 end
    end)
    if not (ok and n > 0) then return false, "couldn't write perks" end
    return true, "unlocked " .. n .. " gamepass perks"
end

local drawObjs = {}
local function D(typ, props)
    local obj = Drawing.new(typ)
    for k, v in pairs_(props) do pcall_(function() obj[k] = v end) end
    tinsert(drawObjs, obj)
    return obj
end

local function _osNow() if type(os) == "table" and type(os.time) == "function" then return os.time() end return nil end
local function _saveVineReady()
    pcall_(function()
        if type(writefile) ~= "function" or not CFG.vineT then return end
        local rem = CFG.vineCd - (tick_() - CFG.vineT)
        if rem < 0 then rem = 0 end
        local onow = _osNow()
        writefile("selllemons_vine.txt", tostring_(mfloor((onow or tick_()) + rem)))
    end)
end

pcall_(function()
    if type(readfile) ~= "function" then return end
    local saved = tonumber(readfile("selllemons_vine.txt"))
    if not saved then return end
    local onow = _osNow()
    if onow then
        local rem = saved - onow
        if rem > 0 and rem < CFG.vineCd + 60 then
            CFG.vineT = tick_() - (CFG.vineCd - rem)
        end
    elseif saved <= tick_() and (tick_() - saved) < 7 * 24 * 3600 then
        CFG.vineT = saved
    end
end)

local UX = {}
function UX.fire(id)
    local now = tick_()
    if S.lastFire[id] and (now - S.lastFire[id]) < 0.30 then return false end
    S.lastFire[id] = now
    return true
end

-- UI Framework Library Connection
local Lib
do
    local lastBody
    for _ = 1, 8 do
        local body = nil
        pcall_(function() body = game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua") end)
        if type(body) == "string" and #body > 1000 then
            lastBody = body
            if body:find("INSUI_FILE_END", 1, true) then
                local ok, res = pcall_(function() return loadstring(body)() end)
                if ok and type(res) == "table" then Lib = res; break end
            end
        end
        task_wait(0.4)
    end
    if type(Lib) ~= "table" and type(lastBody) == "string" then
        pcall_(function() local r = loadstring(lastBody)(); if type(r) == "table" then Lib = r end end)
    end
    if type(Lib) ~= "table" then pcall_(function() Lib = INSui end) end
end

local function notify(title, text, duration)
    if Lib and Lib.Notify then
        pcall_(function() Lib:Notify(title, text, duration or 5) end)
    else
        pcall_(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = duration or 5
            })
        end)
    end
end

local UIRef = { win = nil, t = {} }
local function syncFromUI() end

local function stopAll(save)
    if save == nil then save = (S.stopSaved == nil) end
    if save then
        S.stopSaved = {
            ab = autoBuyActive, sd = skipDecorActive, lf = lemonFarmActive, cf = cashFarmActive,
            as = autoStandActive, ar = autoRebirthActive, ad = autoDealActive, ae = autoEvolveActive, aa = autoAscendActive,
            aw = autoWakeActive, ap = autoBuyPowersActive, d3 = disable3dActive
        }
        autoBuyActive, skipDecorActive, lemonFarmActive, cashFarmActive, autoStandActive = false, false, false, false, false
        autoRebirthActive, autoDealActive, autoEvolveActive, autoAscendActive = false, false, false, false
        autoWakeActive, autoBuyPowersActive, disable3dActive = false, false, false
        syncToUI()
        toggle3dRendering(true)
        print("[Hub] Stop All ON - Everything Stalled")
    else
        local s = S.stopSaved
        if s then
            autoBuyActive, skipDecorActive, lemonFarmActive, cashFarmActive = s.ab, s.sd, s.lf, s.cf
            autoStandActive, autoRebirthActive, autoDealActive = s.as, s.ar, s.ad
            autoEvolveActive, autoAscendActive = s.ae, s.aa
            autoWakeActive, autoBuyPowersActive, disable3dActive = s.aw, s.ap, s.d3
            S.stopSaved = nil
        end
        syncToUI()
        toggle3dRendering(not disable3dActive)
        print("[Hub] Stop All OFF - State Resumed")
    end
    saveSettings()
end

local function toggleFeature(slot)
    if not UX.fire("slot" .. slot) then return end
    if     slot == 1 then autoBuyActive   = not autoBuyActive
    elseif slot == 2 then lemonFarmActive = not lemonFarmActive
    elseif slot == 3 then autoStandActive = not autoStandActive
    elseif slot == 4 then cashFarmActive  = not cashFarmActive
    elseif slot == 5 then stopAll(); return
    else return end
    UIRef.t.AutoBuy:Set(autoBuyActive)
    UIRef.t.LemonFarm:Set(lemonFarmActive)
    UIRef.t.AutoStand:Set(autoStandActive)
    UIRef.t.CashFarm:Set(cashFarmActive)
    saveSettings()
end

local STAND_NAMES = {"Lemon Stand", "LemonDash", "Lemon Depot", "Lemon Trading", "Lemon Labs", "Lemon Robotics", "Lemon Republic", "LemonX"}
local standEnabled = {}
local MG = { active = false, enabled = {} }

MG.lemBusy = function()
    if not MG.active then return false end
    local t = tick_()
    return (t - (MG.busyT or 0)) < 4 or (t - (MG.entryT or 0)) < 4
end

local _bagSeen = {}
setmetatable(_bagSeen, { __mode = "k" })
local _lemonPending = {}
setmetatable(_lemonPending, { __mode = "k" })

local function fmtN(n)
    local s = tostring_(mfloor(tonumber(n) or 0))
    s = s:reverse():gsub("(%d%d%d)", "%1,")
    s = s:reverse()
    return (s:gsub("^,", ""))
end

local function fmtClock(sec)
    sec = mfloor(sec or 0)
    local h, m, s = mfloor(sec / 3600), mfloor((sec % 3600) / 60), sec % 60
    if h > 0 then return sformat("%d:%02d:%02d", h, m, s) end
    return sformat("%d:%02d", m, s)
end

local function fmtPct1(n)
    return (sformat("%.1f", tonumber(n) or 0):gsub("%.0$", ""))
end

local _cashCache = { t = -1, v = nil }
local function readCashText()
    local now = tick_()
    if _cashCache.t >= 0 and (now - _cashCache.t) < 0.5 then return _cashCache.v end
    _cashCache.t = now
    local pg = player and player:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    if not hud then _cashCache.v = nil; return nil end
    local t; pcall_(function() t = RB.text(RB.node(hud, "Balance/Main/Cash")) end)
    _cashCache.v = (type(t) == "string" and t ~= "") and t or nil
    return _cashCache.v
end

pcall_(function()
    if type(readfile) ~= "function" then return end
    local saved = tonumber(readfile("selllemons_mini.txt"))
    if not saved then return end
    local onow = _osNow()
    if onow then
        local rem = saved - onow
        if rem > -24 * 3600 and rem < 2 * 3600 then MG.miniEnd = tick_() + rem end
    elseif saved > tick_() - 24 * 3600 and saved < tick_() + 2 * 3600 then
        MG.miniEnd = saved
    end
end)

MG.saveMiniEnd = function()
    if not MG.miniEnd then return end
    if (tick_() - (MG.saveT or 0)) < 20 then return end
    MG.saveT = tick_()
    pcall_(function()
        if type(writefile) ~= "function" then return end
        local onow = _osNow()
        local rem = MG.miniEnd - tick_()
        writefile("selllemons_mini.txt", tostring_(mfloor((onow or tick_()) + rem)))
    end)
end

MG.list = function()
    local out = {}
    if not myTycoon then return out end
    local pur; pcall_(function() pur = myTycoon:FindFirstChild("Purchases") end)
    local mg = pur and pur:FindFirstChild("Minigames")
    if not mg then return out end
    pcall_(function()
        for _, c in ipairs_(mg:GetChildren()) do
            if c:IsA("Folder") or c:IsA("Model") then
                local ok = false
                pcall_(function()
                    for _, d in ipairs_(c:GetDescendants()) do
                        if tostring_(d.ClassName) == "ProximityPrompt" then ok = true; break end
                    end
                end)
                if ok then out[#out + 1] = tostring_(c.Name) end
            end
        end
    end)
    return out
end

MG.timerSec = function()
    local now = tick_()
    if MG.tsT and (now - MG.tsT) < 1.0 then return MG.tsVal end
    MG.tsT = now
    MG.tsVal = nil
    if not myTycoon then return nil end
    local pur; pcall_(function() pur = myTycoon:FindFirstChild("Purchases") end)
    local mg = pur and pur:FindFirstChild("Minigames")
    if not mg then return nil end
    MG.lblSeen = MG.lblSeen or {}
    local rem, ready
    pcall_(function()
        for _, c in ipairs_(mg:GetChildren()) do
            local nm = tostring_(c.Name)
            if MG.enabled[nm] ~= false and nm:lower():find("minigame") and not nm:lower():find("trade") then
                for _, d in ipairs_(c:GetDescendants()) do
                    if tostring_(d.ClassName) == "TextLabel" then
                        local t; pcall_(function() t = d.Text end)
                        t = tostring_(t or "")
                        if (t:upper():gsub("[%s%p]", "")) == "READY" then
                            if MG.shown(d) then ready = true end
                        else
                            local hh, mm, ss = t:match("^%s*(%d+):(%d%d):(%d%d)%s*$")
                            if hh then
                                local r = tonumber_(hh) * 3600 + tonumber_(mm) * 60 + tonumber_(ss)
                                if r > 0 and r < 2 * 3600 then
                                    local k; pcall_(function() k = d:GetFullName() end)
                                    k = k or nm
                                    local rec = MG.lblSeen[k]
                                    if not rec then
                                        rec = { txt = t, t = 0, seen = now }
                                        MG.lblSeen[k] = rec
                                    elseif rec.txt ~= t then
                                        rec.txt = t
                                        rec.t = (now - rec.seen) <= 2.5 and now or 0
                                    end
                                    rec.seen = now
                                    if (now - rec.t) < 3 then rem = r end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    if not rem and ready then MG.miniEnd = now end
    MG.tsVal = rem
    return rem
end

MG.name = function()
    if MG.nameVal and (tick_() - (MG.nameT or 0)) < 5 then return MG.nameVal end
    MG.nameT = tick_()
    local out
    if myTycoon then
        local pur; pcall_(function() pur = myTycoon:FindFirstChild("Purchases") end)
        local mg = pur and pur:FindFirstChild("Minigames")
        if mg then
            pcall_(function()
                for _, c in ipairs_(mg:GetChildren()) do
                    local cn = tostring_(c.Name)
                    if MG.enabled[cn] ~= false and cn:lower():find("minigame") and not cn:lower():find("trade") then
                        for _, d in ipairs_(c:GetDescendants()) do
                            if tostring_(d.ClassName) == "ProximityPrompt" then
                                local ot; pcall_(function() ot = d.ObjectText end)
                                ot = tostring_(ot or "")
                                if ot ~= "" and ot ~= "nil" then out = ot; return end
                            end
                        end
                        out = (cn:gsub("^[Mm]inigame%s+", ""))
                        return
                    end
                end
            end)
        end
    end
    MG.nameVal = out
    return out
end

local function _standPartPos(c)
    local pos
    pcall_(function() pos = c.Position end)
    if pos then return pos end
    pcall_(function()
        for _, d in ipairs_(c:GetDescendants()) do
            if d:IsA("BasePart") then pos = d.Position; return end
        end
    end)
    if not pos then pcall_(function() if c.PrimaryPart then pos = c.PrimaryPart.Position end end) end
    return pos
end

local function _standUpgradePos(folder, nm)
    local pos
    pcall_(function()
        local n2 = folder:FindFirstChild(nm)
        local n3 = n2 and n2:FindFirstChild(nm)
        if n3 then pos = _standPartPos(n3) end
    end)
    if not pos then
        pcall_(function()
            for _, d in ipairs_(folder:GetDescendants()) do
                if tostring_(d.ClassName) == "ProximityPrompt" and tostring_(d.Name) == "Prompt" and d.Parent then
                    pos = _standPartPos(d.Parent); break
                end
            end
        end)
    end
    return pos
end

local STAND_ORDER = {"stand", "dash", "depot", "trading", "labs", "robotics", "republic", "lemonx"}
local function standRank(low)
    for i = 1, #STAND_ORDER do
        if low:find(STAND_ORDER[i], 1, true) then return i end
    end
    return 99
end

local function getStandLocations()
    local out = {}
    if not myTycoon then return out end
    local pur, loc
    pcall_(function() pur = myTycoon:FindFirstChild("Purchases") end)
    pcall_(function() loc = myTycoon:FindFirstChild("Locations") end)
    if not pur then return out end
    for _, folder in ipairs_(pur:GetChildren()) do
        local nm = tostring_(folder.Name)
        local low = nm:lower()
        local rank = standRank(low)
        if rank < 99 and not low:find("ground") then
            local pos = _standUpgradePos(folder, nm)
            local lpos = nil
            if loc then
                local lc = loc:FindFirstChild(nm)
                if lc then lpos = _standPartPos(lc) end
            end
            if pos and lpos then
                local d = lpos - pos
                local m = d.Magnitude
                if m > 0.1 then
                    local step = m < 6 and m or 6
                    pos = pos + (d / m) * step
                end
            elseif not pos then
                pos = lpos
            end
            if pos then tinsert(out, {name = nm, pos = pos, rank = rank}) end
        end
    end
    table.sort(out, function(a, b) return a.rank < b.rank end)
    return out
end

local function getBuyLocations()
    local out = {}
    if not myTycoon then return out end
    local pur, loc
    pcall_(function() pur = myTycoon:FindFirstChild("Purchases") end)
    pcall_(function() loc = myTycoon:FindFirstChild("Locations") end)
    if not pur then return out end
    for _, cat in ipairs_(pur:GetChildren()) do
        local nm = tostring_(cat.Name)
        local pos
        if loc then
            local lc = loc:FindFirstChild(nm)
            if lc then pos = _standPartPos(lc) end
        end
        if not pos then pcall_(function() pos = _standPartPos(cat) end) end
        if pos then out[#out + 1] = { name = nm, pos = pos } end
    end
    return out
end

function UIRef.t.AutoBuy:Set(val) autoBuyActive = val end
function UIRef.t.SkipDecor:Set(val) skipDecorActive = val end
function UIRef.t.LemonFarm:Set(val) lemonFarmActive = val end
function UIRef.t.AutoStand:Set(val) autoStandActive = val end
function UIRef.t.CashFarm:Set(val) cashFarmActive = val end
function UIRef.t.AutoRebirth:Set(val) autoRebirthActive = val end
function UIRef.t.AutoEvolve:Set(val) autoEvolveActive = val end
function UIRef.t.AutoAscend:Set(val) autoAscendActive = val end
function UIRef.t.AutoDeal:Set(val) autoDealActive = val end

local function syncToUI()
    pcall_(function() if UIRef.t.AutoBuy then UIRef.t.AutoBuy:Set(autoBuyActive) end end)
    pcall_(function() if UIRef.t.SkipDecor then UIRef.t.SkipDecor:Set(skipDecorActive) end end)
    pcall_(function() if UIRef.t.LemonFarm then UIRef.t.LemonFarm:Set(lemonFarmActive) end end)
    pcall_(function() if UIRef.t.AutoStand then UIRef.t.AutoStand:Set(autoStandActive) end end)
    pcall_(function() if UIRef.t.CashFarm then UIRef.t.CashFarm:Set(cashFarmActive) end end)
    pcall_(function() if UIRef.t.AutoRebirth then UIRef.t.AutoRebirth:Set(autoRebirthActive) end end)
    pcall_(function() if UIRef.t.AutoEvolve then UIRef.t.AutoEvolve:Set(autoEvolveActive) end end)
    pcall_(function() if UIRef.t.AutoAscend then UIRef.t.AutoAscend:Set(autoAscendActive) end end)
    pcall_(function() if UIRef.t.AutoDeal then UIRef.t.AutoDeal:Set(autoDealActive) end end)
    pcall_(function() if UIRef.t.AutoWake then UIRef.t.AutoWake:Set(autoWakeActive) end end)
    pcall_(function() if UIRef.t.AutoBuyPowers then UIRef.t.AutoBuyPowers:Set(autoBuyPowersActive) end end)
    pcall_(function() if UIRef.t.Disable3D then UIRef.t.Disable3D:Set(disable3dActive) end end)
end

-- UI Window Assembly
if Lib then
    Lib:SetTheme({
        accentA = C3rgb(252, 211, 49),
        accentB = C3rgb(240, 165, 25),
        bg      = C3rgb(18, 17, 13),
        sidebar = C3rgb(18, 17, 13),
    })
    local window = Lib:CreateWindow({
        title = "Sell Lemons",
        subtitle = "auto",
        size = Vec2(580, 560),
        badge = "v24-Mod",
        menuKey = "q",
        gameInput = "always",
        logo = "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f34b.png",
    })
    UIRef.win = window

    local tab1 = window:Tab("Main", "home")
    local farm = tab1:Section("Farming", "Left", "auto-farms, stands & rebirth")
    
    UIRef.t.AutoBuy = farm:Toggle("Auto Buy", autoBuyActive, function(val)
        autoBuyActive = val
        if val then pcall_(function() myTycoon = findMyTycoon() or myTycoon end) end
        saveSettings()
    end):AddKeybind("1", "Toggle")
    
    UIRef.t.SkipDecor = farm:Toggle("Skip Decor", skipDecorActive, function(val)
        skipDecorActive = val; saveSettings()
    end):Tooltip("skip decoration buttons while auto-buying")

    farm:Divider()
    UIRef.t.LemonFarm = farm:Toggle("Lemon Farm", lemonFarmActive, function(val)
        lemonFarmActive = val; saveSettings()
    end):AddKeybind("2", "Toggle")
    
    UIRef.t.AfkDelay = farm:Slider("AFK delay", CFG.afkDelay or 6, 1, 1, 30, "s", function(val)
        local s = mfloor(tonumber_(val) or 6); if s < 1 then s = 1 elseif s > 30 then s = 30 end; CFG.afkDelay = s
    end)

    farm:Divider()
    UIRef.t.AutoStand = farm:Toggle("Auto Stand", autoStandActive, function(val)
        autoStandActive = val; saveSettings()
    end):AddKeybind("3", "Toggle")
    
    pcall_(function()
        local names = {}
        for _, s in ipairs_(getStandLocations()) do names[#names + 1] = s.name end
        if #names == 0 then names = STAND_NAMES end
        local labels, labelOf = {}, {}
        for idx, nm in ipairs_(names) do
            local lbl = idx .. ". " .. nm
            labels[idx] = lbl
            labelOf[lbl] = nm
        end
        local standSel = {}
        for idx, nm in ipairs_(names) do
            if standEnabled[nm] == nil then standEnabled[nm] = true end
            if standEnabled[nm] ~= false then standSel[#standSel + 1] = labels[idx] end
        end
        UIRef.standDd = farm:Dropdown("Active stands", standSel, labels, true, function(v)
            local set = {}
            for _, lbl in ipairs_(v) do local nm = labelOf[lbl]; if nm then set[nm] = true end end
            for _, nm in ipairs_(names) do standEnabled[nm] = set[nm] == true end
            saveSettings()
        end, "which stands the bot upgrades", true)
    end)
    
    UIRef.t.CashFarm = farm:Toggle("Cash Bags Farm", cashFarmActive, function(val)
        cashFarmActive = val; saveSettings()
    end):AddKeybind("4", "Toggle")

    farm:Divider()
    UIRef.t.AutoRebirth = farm:Toggle("Auto Rebirth", autoRebirthActive, function(val)
        autoRebirthActive = val
        if val then
            RB.lastPeek = tick_() - ((RB.peekEvery or 60) - 10)
        else
            RB.go = false; RB.status = "off"
        end
        saveSettings()
    end):AddKeybind("5", "Toggle")
    
    farm:Slider("Rebirth at", RB.gainPct, 1, 1, 1000, "%", function(val)
        RB.gainPct = tonumber_(val) or 25; saveSettings()
    end)
    
    UIRef.t.AutoEvolve = farm:Toggle("Auto Evolve", autoEvolveActive, function(val)
        autoEvolveActive = val; saveSettings()
    end):AddKeybind("6", "Toggle")
    
    UIRef.t.AutoAscend = farm:Toggle("Auto Ascend", autoAscendActive, function(val)
        autoAscendActive = val; saveSettings()
    end):AddKeybind("7", "Toggle")

    local autoR = tab1:Section("Automation", "Right", "deals, minigames, vine")
    UIRef.t.AutoDeal = autoR:Toggle("Auto Accept Phone Offers", autoDealActive, function(val)
        autoDealActive = val; saveSettings()
    end)
    
    UIRef.t.AutoWake = autoR:Toggle("Auto Wake Income Sources", autoWakeActive, function(val)
        autoWakeActive = val; saveSettings()
    end):Tooltip("Automatically interact with resting tycoon workers or structures")
    
    UIRef.t.AutoBuyPowers = autoR:Toggle("Auto Buy Powers", autoBuyPowersActive, function(val)
        autoBuyPowersActive = val; saveSettings()
    end):Tooltip("Automatically acquire performance and layout power elements")

    UIRef.t.AutoMini = autoR:Toggle("Auto Minigame", false, function(val)
        MG.active = val; saveSettings()
    end)
    
    autoR:Button("Cash Vine TP", function() CFG.vineGo = true end)
    autoR:Button("Unlock Gamepasses", function()
        local ok, msg = unlockGamepasses()
        Lib:Notify("Gamepasses", msg, 4, ok and "success" or "warning")
    end)
    
    autoR:Divider("Visuals")
    UIRef.t.KeyEsp = autoR:Toggle("Key / Lever ESP", false, function(val)
        keyEspActive = val; saveSettings()
    end)

    local perfS = tab1:Section("Performance & Optimization", "Right", "Advanced configurations")
    UIRef.t.Disable3D = perfS:Toggle("Disable 3D Rendering", disable3dActive, function(val)
        disable3dActive = val
        toggle3dRendering(not val)
        saveSettings()
    end):Tooltip("Turn off 3D graphics to drastically boost performance and lower CPU load")
    
    perfS:Slider("X Factor Multiplier", RB.xFactor, 0.5, 1, 10, "x", function(val)
        RB.xFactor = tonumber(val) or 1.0; saveSettings()
    end)
    perfS:Slider("Max Rebirth Window", RB.maxTime, 10, 60, 1800, "s", function(val)
        RB.maxTime = tonumber(val) or 600; saveSettings()
    end)
    perfS:Slider("Stall Threshold", RB.stallTime, 5, 10, 300, "s", function(val)
        RB.stallTime = tonumber(val) or 60; saveSettings()
    end)

    local tabS = window:Tab("Session", "activity")
    local stOv = tabS:Section("Overview", "Left", "live stats this session")
    stOv:Label(function() return "Runtime:  " .. fmtClock(tick_() - statsStartT) end)
    stOv:Label(function() return "Cash:  " .. (readCashText() or "...") end)
    local stCol = tabS:Section("Collected", "Left", "auto-farm totals")
    stCol:Label(function() return "Buttons bought:  " .. fmtN(STATS.bought) end)
    stCol:Label(function() return "Lemons collected:  " .. fmtN(STATS.lemons) end)
    stCol:Label(function() return "Cash bags:  " .. fmtN(STATS.bags) end)
    
    window:AddSettingsTab("cog")
    syncToUI()
end

-- Lemon Tree & Drop Parsing Cache System
local function normalizeColor(c)
    local r, g, b = c.R, c.G, c.B
    if r <= 1 and g <= 1 and b <= 1 then r, g, b = r * 255, g * 255, b * 255 end
    return r, g, b
end

local function isGreyedOut(v)
    local ok, color3 = pcall_(function() return v.Color end)
    if not ok or not color3 then return false end
    local r, g, b = normalizeColor(color3)
    return mabs(r - g) < 14 and mabs(g - b) < 14 and mabs(r - b) < 14 and mabs(r - 102) <= 22
end

local BUY = { poll = 0.03, window = 0.45 }
local abModels, abTyName
local function purchasables()
    local cur; pcall_(function() cur = myTycoon and tostring_(myTycoon.Name) end)
    local fresh = false
    pcall_(function() fresh = abModels and abModels[1] and abModels[1].Parent ~= nil and abTyName == cur end)
    if fresh then return abModels end
    abModels = {}
    if not myTycoon or not myTycoon.Parent then myTycoon = findMyTycoon() or myTycoon end
    local t = myTycoon
    if not t then return abModels end
    pcall_(function() abTyName = tostring_(t.Name) end)
    pcall_(function()
        local pur = t:FindFirstChild("Purchases")
        if not pur then return end
        for _, d in ipairs_(pur:GetDescendants()) do
            if d.Name == "Purchase" and d.Parent then abModels[#abModels + 1] = d.Parent end
        end
    end)
    return abModels
end

local buyList, buyListT = {}, 0
local function buyCandidates()
    if #buyList > 0 and (tick_() - buyListT) < 0.4 then return buyList end
    buyListT, buyList = tick_(), {}
    for _, m in ipairs_(purchasables()) do
        local btn
        pcall_(function()
            if m.Parent and m:GetAttribute("Shown") == true and m:GetAttribute("Purchased") ~= true then
                local b = m:FindFirstChild("Button")
                if b and b:IsA("BasePart") then btn = b end
            end
        end)
        if btn then buyList[#buyList + 1] = { m = m, btn = btn } end
    end
    return buyList
end

local function isDecorModel(m)
    if not m then return false end
    local inDecor = false
    pcall_(function()
        local p = m.Parent
        while p and p ~= Workspace do
            if tostring_(p.Name) == "Decor" then inDecor = true; return end
            p = p.Parent
        end
    end)
    return inDecor
end

local lemonTrees, lemonTreeSet, lemonTreeCacheReady = {}, {}, false
local function _removeTree(folder)
    if not lemonTreeSet[folder] then return end
    lemonTreeSet[folder] = nil
    for i = #lemonTrees, 1, -1 do
        if lemonTrees[i] == folder then table.remove(lemonTrees, i); break end
    end
end

local function addLemonTree(tree)
    if not tree or lemonTreeSet[tree] then return end
    lemonTreeSet[tree] = true
    tinsert(lemonTrees, tree)
    pcall_(function()
        tree.AncestryChanged:Connect(function(_, parent)
            if not parent then _removeTree(tree) end
        end)
    end)
end

local function hookTreesFolder(treesFolder)
    if not treesFolder then return end
    for _, t in ipairs_(treesFolder:GetChildren()) do addLemonTree(t) end
    pcall_(function() treesFolder.ChildAdded:Connect(function(nT) addLemonTree(nT) end) end)
end

local function hookTycoonForTrees(tycoon)
    if not tycoon or not tycoon.Name or not tycoon.Name:find("Tycoon") then return end
    local constant = tycoon:FindFirstChild("Constant")
    if constant then
        local trees = constant:FindFirstChild("Trees")
        if trees then hookTreesFolder(trees) end
    end
end

local function buildLemonTreeCache()
    lemonTrees, lemonTreeSet = {}, {}
    local rootLT = Workspace:FindFirstChild("LemonTree")
    if rootLT then addLemonTree(rootLT) end
    for _, tycoon in ipairs_(Workspace:GetChildren()) do hookTycoonForTrees(tycoon) end
    lemonTreeCacheReady = true
end
buildLemonTreeCache()

local function getLemonsFast()
    if not lemonTreeCacheReady then buildLemonTreeCache() end
    local temp = {}
    for ti = 1, #lemonTrees do
        local tree = lemonTrees[ti]
        if tree and tree.Parent then
            for _, fruit in ipairs_(tree:GetChildren()) do
                if fruit.Name == "Fruit" then
                    local cp = fruit:FindFirstChild("ClickPart")
                    if cp and cp:IsA("BasePart") and cp.Position.Y <= 14 then tinsert(temp, cp) end
                end
            end
        end
    end
    return temp
end

local _cashFolder
local function getCashDropsFast()
    local folder = _cashFolder
    if not folder or not folder.Parent then
        folder = Workspace:FindFirstChild("CashDrops")
        _cashFolder = folder
    end
    if not folder then return {} end
    local temp = {}
    for _, v in ipairs_(folder:GetDescendants()) do
        if v.Name == "TouchInterest" and v.Parent and v.Parent:IsA("BasePart") then
            tinsert(temp, v.Parent)
        end
    end
    return temp
end

local LSM = { mode = "classic", annAfk = false, annBuy = false }
local ANTIGRAV_VEL = Vec3(0, 2, 0)
RunService.RenderStepped:Connect(function()
    if not ScriptActive then return end
    if lemonFarmActive and LSM.mode ~= "cd" and LSM.mode ~= "sig" and (tick_() - (S.lastUser or 0)) >= CFG.afkDelay then
        local chr = player.Character
        local hrp = chr and chr:FindFirstChild("HumanoidRootPart")
        if hrp then pcall_(function() hrp.AssemblyLinearVelocity = ANTIGRAV_VEL end) end
    end
end)

local function _tpHrpTo(pos)
    if autoStandActive then LSM.standBusyT = tick_() end
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return pcall_(function() hrp.CFrame = CF(pos.X, pos.Y + 3, pos.Z) end)
end

local function _windowFocused()
    if type(isrbxactive) ~= "function" then return true end
    local ok, r = pcall_(isrbxactive)
    return ok and r ~= false
end

local function _anyLiveButtons()
    for _, c in ipairs_(buyCandidates()) do
        local btn = c.btn
        if btn and btn.Parent and not isGreyedOut(btn) and not (skipDecorActive and isDecorModel(c.m)) then return true end
    end
    return false
end

local function tpBuy(btn)
    local pos; pcall_(function() pos = btn.Position end)
    if not pos then return false end
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    LSM.lastBot = tick_(); LSM.buySweepT = tick_()
    pcall_(function() hrp.CFrame = CF(pos.X, pos.Y + 2.5, pos.Z) end)
    task_wait(BUY.poll)
    local deadline = tick_() + BUY.window
    repeat
        character = player.Character; hrp = (character and character:FindFirstChild("HumanoidRootPart")) or hrp
        pcall_(function() hrp.CFrame = CF(pos.X, pos.Y + 0.8, pos.Z) end)
        task_wait(BUY.poll)
        if btn.Parent == nil then return true end
    until tick_() >= deadline
    return btn.Parent == nil
end

-- ============================================================================
-- PARALLEL WORKER LOOPS & LOGIC EXTRACTIONS
-- ============================================================================

-- Worker: Automatic Button Purchases
_wrap("autobuy-worker", function()
    while ScriptActive do
        if not autoBuyActive or _standIsTapping or MG.lemBusy() then task_wait(0.1); continue end
        local cands = buyCandidates()
        local didBuy = false
        for _, c in ipairs_(cands) do
            if not autoBuyActive or _standIsTapping then break end
            local btn = c.btn
            if btn and btn.Parent and not isGreyedOut(btn) and not (skipDecorActive and isDecorModel(c.m)) then
                if tpBuy(btn) then
                    didBuy = true
                    STATS.bought = STATS.bought + 1
                    RB.lastButtonBoughtTime = tick_()
                end
            end
        end
        task_wait(didBuy and 0.02 or 0.08)
    end
end)

-- Worker: Lemon Fruit Harvester
local lemonFailCount = {}
local function processLemon(v, hrp)
    if not v or not v:IsDescendantOf(Workspace) or !_windowFocused() then return false end
    local vp = v.Position
    pcall_(function()
        hrp.CFrame = CF(vp.X, vp.Y - 4, vp.Z)
        task_wait(0.01)
        camera.lookAt(Vec3(vp.X, vp.Y - 4, vp.Z), vp)
    end)
    pcall_(function()
        local vps = camera.ViewportSize
        mousemoveabs(mfloor(vps.X / 2), mfloor(vps.Y / 2))
        mouse1click()
    end)
    return v.Parent == nil
end

_wrap("lemon-farm", function()
    while ScriptActive do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local afkNow = (tick_() - (S.lastUser or 0)) >= CFG.afkDelay
        
        if lemonFarmActive and hrp and afkNow and _windowFocused() then
            local snapshot = getLemonsFast()
            for _, fruit in ipairs_(snapshot) do
                if not lemonFarmActive then break end
                if processLemon(fruit, hrp) then STATS.lemons = STATS.lemons + 1 end
            end
            task_wait(0.1)
        else
            task_wait(0.5)
        end
    end
end)

-- Worker: Cash Drop Magnetizer
_wrap("cash-farm", function()
    while ScriptActive do
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        if cashFarmActive and head then
            local snapshot = getCashDropsFast()
            local headPos = head.Position
            for i = 1, #snapshot do
                local parent = snapshot[i]
                if parent and parent.Parent then
                    pcall_(function() parent.Position = headPos end)
                    if not _bagSeen[parent] then _bagSeen[parent] = true; STATS.bags = STATS.bags + 1 end
                end
            end
            task_wait(0.3)
        else
            task_wait(0.5)
        end
    end
end)

-- Worker: Auto Accept Phone Offers
_wrap("auto-deal", function()
    while ScriptActive do
        if autoDealActive then
            pcall_(function()
                local pg = player:FindFirstChild("PlayerGui")
                local phone = pg and pg:FindFirstChild("Phone")
                if phone and phone.Enabled then
                    for _, d in ipairs_(phone:GetDescendants()) do
                        if d:IsA("TextButton") and d.Visible and (d.Text:lower():find("accept") or d.Text:lower():find("take")) then
                            local apos = d.AbsolutePosition
                            local asz = d.AbsoluteSize
                            local inset = GuiService and GuiService:GetGuiInset().Y or 0
                            mousemoveabs(mfloor(apos.X + asz.X / 2), mfloor(apos.Y + asz.Y / 2 + inset))
                            mouse1click()
                            STATS.deals = STATS.deals + 1
                            break
                        end
                    end
                end
            end)
        end
        task_wait(0.5)
    end
end)

-- Worker: Auto Wake Income Sources
_wrap("auto-wake", function()
    while ScriptActive do
        if autoWakeActive and myTycoon then
            pcall_(function()
                for _, desc in ipairs_(myTycoon:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and (desc.Name:find("Wake") or desc.ActionText:find("Wake") or desc.ActionText:find("Activate")) then
                        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        local part = desc.Parent
                        if hrp and part and part:IsA("BasePart") and (part.Position - hrp.Position).Magnitude < 25 then
                            fireproximityprompt(desc)
                        end
                    end
                end
            end)
        end
        task_wait(1.5)
    end
end)

-- Worker: Auto Buy Powers / Gamepass Attributes Injection
_wrap("auto-buy-powers", function()
    while ScriptActive do
        if autoBuyPowersActive then
            pcall_(function()
                unlockGamepasses()
                if myTycoon then
                    local powers = myTycoon:FindFirstChild("Powers")
                    if powers then
                        for _, btn in ipairs_(powers:GetDescendants()) do
                            if btn.Name == "Button" and btn:IsA("BasePart") then
                                -- Step on purchase structure if affordable
                            end
                        end
                    end
                end
            end)
        end
        task_wait(5.0)
    end
end)

-- ============================================================================
-- ADVANCED REBIRTH LOGIC ENGINE
-- ============================================================================
local _log10 = math.log10 or function(x) return math.log(x) / math.log(10) end
local HUGE_EXP = {}
do
    local BASE = {[0]="thousand","million","billion","trillion","quadrillion","quintillion"}
    for m = 0, 5 do HUGE_EXP[BASE[m]] = (m + 1) * 3 end
end

function RB.node(root, p)
    local cur = root
    for seg in p:gmatch("[^/]+") do if not cur then return nil end; cur = cur:FindFirstChild(seg) end
    return cur
end

function RB.gui()
    local pg = player:FindFirstChild("PlayerGui")
    return pg and pg:FindFirstChild("Rebirth")
end

function RB.text(node) return node and node.Text or "" end

function RB.cashLog()
    local pg = player:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    if not hud then return nil end
    local txt = RB.text(RB.node(hud, "Balance/Main/Cash")):gsub("[%,%$%s]", "")
    local num = tonumber(txt)
    return num and num > 0 and _log10(num) or nil
end

function RB.computeDecision()
    local cashLog = RB.cashLog()
    if not cashLog then return end

    local timeSinceLastRebirth = tick_() - RB.lastRebirthTime
    local timeSinceLastButton  = tick_() - RB.lastButtonBoughtTime

    -- Dynamic Threshold Check with X Factor Multiplier
    local targetMultiplier = RB.xFactor or 1.0
    local thresholdSatisfied = false

    if RB.gainPct and cashLog > _log10(RB.gainPct * targetMultiplier) then
        thresholdSatisfied = true
    end

    -- Advanced Timing Evaluators
    local maxWindowExceeded = (RB.maxTime and RB.maxTime > 0 and timeSinceLastRebirth > RB.maxTime)
    local progressionStalled = (RB.stallTime and RB.stallTime > 0 and autoBuyActive and timeSinceLastButton > RB.stallTime)

    if thresholdSatisfied or maxWindowExceeded or progressionStalled then
        RB.go = true
        if maxWindowExceeded then RB.status = "Forced (Max Window)"
        elseif progressionStalled then RB.status = "Forced (Stalled)"
        else RB.status = "Optimal Threshold" end
    else
        RB.go = false
        RB.status = sformat("Waiting.. Stg:%ds", mfloor(RB.stallTime - timeSinceLastButton))
    end
end

function RB.prepClick()
    pcall_(function()
        if lemonFarmActive or LSM.zoomedIn then
            LSM.zoomedIn = false
            for _ = 1, 10 do mousescroll(-1); task_wait(0.01) end
        end
    end)
end

function RB.executeRebirth()
    RB.prepClick()
    pcall_(function()
        local remote = game:GetService("ReplicatedStorage"):FindFirstChild("RebirthEvent") or game:GetService("ReplicatedStorage"):FindFirstChild("Rebirth")
        if remote and remote:IsA("RemoteEvent") then
            remote:FireServer()
            STATS.rebirths = STATS.rebirths + 1
            RB.lastRebirthTime = tick_()
            RB.lastButtonBoughtTime = tick_()
        end
    end)
    task_wait(1.0)
end

_wrap("auto-rebirth-loop", function()
    while ScriptActive do
        if autoRebirthActive then
            RB.computeDecision()
            if RB.go then RB.executeRebirth() end
        end
        task_wait(1.0)
    end
end)

-- Worker: Evolution & Ascension Automated Remotes
_wrap("auto-evolve-loop", function()
    while ScriptActive do
        if autoEvolveActive and evolveProgress >= 100 then
            pcall_(function()
                local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Evolve")
                if remote then remote:FireServer(); STATS.evolves = STATS.evolves + 1 end
            end)
        end
        task_wait(2.0)
    end
end)

_wrap("auto-ascend-loop", function()
    while ScriptActive do
        if autoAscendActive and ASC.ready then
            pcall_(function()
                local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Ascend")
                if remote then remote:FireServer(); STATS.ascends = STATS.ascends + 1 end
            end)
        end
        task_wait(2.0)
    end
end)

-- Input Pooling & Keyboard Fallbacks Execution
RunService.RenderStepped:Connect(function()
    if not ScriptActive then return end
    pcall_(function()
        local mx, my = S.pmx, S.pmy
        if mouse then mx, my = mouse.X, mouse.Y end
        if mabs(mx - S.pmx) > 4 or mabs(my - S.pmy) > 4 then S.lastUser = tick_() end
        S.pmx, S.pmy = mx, my
    end)
end)

print("[Hub] Unified Automation Engine successfully loaded.")