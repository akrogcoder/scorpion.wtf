--[[
    Scorpion.wtf | Visual Private — clean / monochrome menu
    Insert — показать / скрыть меню
]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")

local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

-- выгрузка предыдущей копии
if env.ScorpionUnload then
    pcall(env.ScorpionUnload)
    env.ScorpionUnload = nil
end

local GuiParent = CoreGui
if typeof(gethui) == "function" then
    local ok, hidden = pcall(gethui)
    if ok and hidden then GuiParent = hidden end
end

for _, root in ipairs({CoreGui, GuiParent}) do
    pcall(function()
        for _, name in ipairs({"ScorpionSkeet_UI", "ScorpionCrosshair", "ScorpionVignette", "ScorpionIntro", "ScorpionESP_Gui", "ScorpionHUD", "ScorpionKeyGate"}) do
            local old = root:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
end

-- ============================================================
--  ТЕМА (белый + прозрачный)
-- ============================================================
local Theme = {
    Back    = Color3.fromRGB(13, 9, 11),
    Panel   = Color3.fromRGB(12, 9, 10),
    Line    = Color3.fromRGB(70, 22, 30),
    Off     = Color3.fromRGB(38, 28, 31),
    Black   = Color3.fromRGB(0, 0, 0),
    White   = Color3.fromRGB(255, 255, 255),
    Text    = Color3.fromRGB(235, 235, 235),
    TextDim = Color3.fromRGB(140, 140, 140),
    Accent  = Color3.fromRGB(255, 255, 255),
    Font    = Enum.Font.SourceSansSemibold,
}

-- чёрно-белая дорожка времени: ночь тёмная, день светлый
local DayTrack = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(18, 18, 18)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(18, 18, 18)),
})

-- акцентный цвет меню (меняется в Settings)
local AccentPresets = {
    {"Crimson", Color3.fromRGB(255, 52, 76)},
    {"White",  Color3.fromRGB(255, 255, 255)},
    {"Ice",    Color3.fromRGB(150, 205, 255)},
    {"Mint",   Color3.fromRGB(140, 255, 200)},
    {"Violet", Color3.fromRGB(190, 150, 255)},
    {"Rose",   Color3.fromRGB(255, 150, 185)},
    {"Orange", Color3.fromRGB(255, 175, 95)},
}
local AccentNames = {}
for i, c in ipairs(AccentPresets) do AccentNames[i] = c[1] end
local Accent = AccentPresets[1][2]
local accentRenders = {}
local function ApplyAccent(i)
    Accent = (AccentPresets[i] or AccentPresets[1])[2]
    for _, fn in ipairs(accentRenders) do pcall(fn) end
end

-- ============================================================
--  ХЕЛПЕРЫ
-- ============================================================
local L = {} -- функции, вынесенные из локалов (лимит 200 локальных переменных)
local connections = {}
local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function new(class, props)
    local inst = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else inst[k] = v end
    end
    inst.Parent = parent
    return inst
end

local function stroke(parent, transparency, color)
    return new("UIStroke", {
        Color = color or Theme.White,
        Transparency = transparency or 0.85,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function line(parent, pos, size)
    return new("Frame", {
        Position = pos, Size = size, BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = parent,
    })
end

local function makeText(parent, str, size, color, align)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Text = str,
        TextSize = size or 14,
        TextColor3 = color or Theme.Text,
        Font = Theme.Font,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.85,
        Parent = parent,
    })
end


-- ============================================================
--  КЛЮЧ-СИСТЕМА
--  Генератор: keygen.py (KEY_SECRET там и здесь должен совпадать).
--  Хочешь зашить ключ прямо в код — впиши в STATIC_KEYS.
--  Отозвать ключ — впиши его ID (8 символов после "SC-") в REVOKED.
-- ============================================================
env.ScorpionKeyOk = false
do
    local KEY_SECRET = {2887631307, 1495895038, 3466572428, 1261029285}
    local STATIC_KEYS = {
        -- "SC-12B88D3-4000000-0041FB4-95926DD",
    }
    local REVOKED = {
        -- ["12B88D30"] = true,
    }
    local EPOCH_DAY = 20089 -- 2025-01-01 в днях от unix-эпохи

    local function mul32(a, b)
        local ah, al = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
        local bh, bl = bit32.rshift(b, 16), bit32.band(b, 0xFFFF)
        return (al * bl + ((ah * bl + al * bh) % 65536) * 65536) % 4294967296
    end
    local function fmix(h)
        h = bit32.bxor(h, bit32.rshift(h, 16))
        h = mul32(h, 0x85EBCA6B)
        h = bit32.bxor(h, bit32.rshift(h, 13))
        h = mul32(h, 0xC2B2AE35)
        h = bit32.bxor(h, bit32.rshift(h, 16))
        return h
    end
    local function mac(data)
        local k0, k1, k2, k3 = KEY_SECRET[1], KEY_SECRET[2], KEY_SECRET[3], KEY_SECRET[4]
        local s, t = k0, k1
        for i = 1, #data do
            s = fmix(bit32.bxor(s, data[i] + 1))
            t = fmix(bit32.bxor(t, s))
            s = (s + k2) % 4294967296
        end
        local o1 = fmix(bit32.bxor(s, k3))
        local o2 = fmix(bit32.bxor(t, k2))
        return {
            bit32.band(bit32.rshift(o1, 24), 255), bit32.band(bit32.rshift(o1, 16), 255),
            bit32.band(bit32.rshift(o1, 8), 255), bit32.band(o1, 255),
            bit32.band(bit32.rshift(o2, 24), 255), bit32.band(bit32.rshift(o2, 16), 255),
        }
    end

    local KEY_FILE = "scorpion_key.txt"
    local hasFs = typeof(readfile) == "function" and typeof(writefile) == "function" and typeof(isfile) == "function"

    -- возвращает ok, текст, unix-время окончания (или nil)
    local function check(key)
        key = tostring(key or ""):upper():gsub("%s", "")
        for _, k in ipairs(STATIC_KEYS) do
            if key == tostring(k):upper() then return true, "static key" end
        end
        local hx = key:gsub("^SC%-", ""):gsub("%-", "")
        if #hx ~= 28 or hx:find("%X") then return false, "wrong key format" end
        local raw = {}
        for i = 1, 28, 2 do raw[#raw + 1] = tonumber(hx:sub(i, i + 1), 16) end
        local flags = raw[8]
        local minuteMode = bit32.band(flags, 1) ~= 0
        local data = {}
        for i = 1, 8 do data[i] = raw[i] end
        local m = mac(data)
        for i = 1, 6 do
            if m[i] ~= raw[8 + i] then
                return false, "invalid key"
            end
        end
        if REVOKED[hx:sub(1, 8)] then return false, "key revoked" end
        if bit32.band(flags, 4) ~= 0 then
            -- тестовый ключ: срок (в минутах) идёт с момента первой активации
            local dur = raw[5] * 256 + raw[6]
            local file = "scorpion_trial_" .. hx:sub(1, 8) .. ".txt"
            local fs = typeof(readfile) == "function" and typeof(writefile) == "function" and typeof(isfile) == "function"
            local start
            if fs and isfile(file) then start = tonumber(readfile(file)) end
            if not start then
                start = os.time()
                if fs then pcall(writefile, file, tostring(start)) end
            end
            local left = start + dur * 60 - os.time()
            if left <= 0 then return false, "trial expired" end
            return true, string.format("trial: %d sec left", left), start + dur * 60
        end
        if minuteMode then
            local exp = raw[7] * 65536 + raw[5] * 256 + raw[6] -- минуты от 2025-01-01 UTC
            local nowMin = math.floor(os.time() / 60) - EPOCH_DAY * 1440
            if nowMin >= exp then return false, "key expired" end
            return true, string.format("%d min left", exp - nowMin), (exp + EPOCH_DAY * 1440) * 60
        end
        local expiry = raw[5] * 256 + raw[6]
        if expiry == 0 then return true, "lifetime" end
        local today = math.floor(os.time() / 86400) - EPOCH_DAY
        if today > expiry then return false, "key expired" end
        return true, string.format("%d days left", expiry - today), (expiry + EPOCH_DAY + 1) * 86400
    end

    local function accept(key, info, expireAt)
        env.ScorpionKeyOk = true
        env.ScorpionKeyInfo = info
        -- ключ запоминается: вводить нужно один раз, пока он действует
        if hasFs then pcall(writefile, KEY_FILE, (tostring(key):upper():gsub("%s", ""))) end
        if expireAt then
            task.spawn(function()
                while task.wait(5) do
                    if os.time() >= expireAt then
                        if hasFs and typeof(delfile) == "function" then pcall(delfile, KEY_FILE)
                        elseif hasFs then pcall(writefile, KEY_FILE, "") end
                        if env.ScorpionUnload then pcall(env.ScorpionUnload) end
                        local g = new("ScreenGui", {
                            Name = "ScorpionKeyGate", IgnoreGuiInset = true, ResetOnSpawn = false,
                            DisplayOrder = 2000000, Parent = GuiParent,
                        })
                        local t = makeText(g, "Scorpion: key expired - run the script again and enter a new key", 18, Theme.White, Enum.TextXAlignment.Center)
                        t.AnchorPoint = Vector2.new(0.5, 0)
                        t.Position = UDim2.new(0.5, 0, 0, 40)
                        t.Size = UDim2.fromOffset(700, 30)
                        task.wait(8)
                        g:Destroy()
                        break
                    end
                end
            end)
        end
    end

    -- сохранённый ключ: если ещё действует, окно не показываем
    if hasFs and isfile(KEY_FILE) then
        local okRead, saved = pcall(readfile, KEY_FILE)
        if okRead and saved and saved ~= "" then
            local ok, info, exp = check(saved)
            if ok then accept(saved, info, exp) end
        end
    end

    if not env.ScorpionKeyOk then
        local gui = new("ScreenGui", {
            Name = "ScorpionKeyGate", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 2000000, Parent = GuiParent,
        })
        local box = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 190),
            BackgroundColor3 = Theme.Back, BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = gui,
        })
        new("UICorner", {CornerRadius = UDim.new(0, 6), Parent = box})
        stroke(box, 0.7)
        local title = makeText(box, "SCORPION.WTF", 20, Theme.White, Enum.TextXAlignment.Center)
        title.Position = UDim2.fromOffset(0, 14)
        title.Size = UDim2.new(1, 0, 0, 24)
        local sub = makeText(box, "enter your license key", 14, Theme.TextDim, Enum.TextXAlignment.Center)
        sub.Position = UDim2.fromOffset(0, 42)
        sub.Size = UDim2.new(1, 0, 0, 18)
        local input = new("TextBox", {
            Position = UDim2.fromOffset(20, 74), Size = UDim2.new(1, -40, 0, 34), BackgroundColor3 = Theme.Black,
            BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "", PlaceholderText = "SC-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX",
            PlaceholderColor3 = Color3.fromRGB(90, 90, 90), TextColor3 = Theme.White, Font = Enum.Font.Code, TextSize = 14,
            ClearTextOnFocus = false, Parent = box,
        })
        new("UICorner", {CornerRadius = UDim.new(0, 4), Parent = input})
        stroke(input, 0.8)
        local status = makeText(box, "", 13, Color3.fromRGB(255, 110, 110), Enum.TextXAlignment.Center)
        status.Position = UDim2.fromOffset(0, 114)
        status.Size = UDim2.new(1, 0, 0, 16)
        local btn = new("TextButton", {
            Position = UDim2.fromOffset(20, 140), Size = UDim2.new(1, -40, 0, 34), BackgroundColor3 = Theme.White,
            BackgroundTransparency = 0.88, BorderSizePixel = 0, Text = "Activate", TextColor3 = Theme.White,
            Font = Theme.Font, TextSize = 16, AutoButtonColor = false, Parent = box,
        })
        new("UICorner", {CornerRadius = UDim.new(0, 4), Parent = btn})
        stroke(btn, 0.7)

        local closed, attempt = false, false
        local close = new("TextButton", {
            Position = UDim2.new(1, -26, 0, 6), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Text = "x",
            TextColor3 = Theme.TextDim, Font = Theme.Font, TextSize = 16, Parent = box,
        })
        close.MouseButton1Click:Connect(function() closed = true end)
        btn.MouseButton1Click:Connect(function() attempt = true end)
        input.FocusLost:Connect(function(enter) if enter then attempt = true end end)

        while not env.ScorpionKeyOk and not closed do
            if attempt then
                attempt = false
                local ok, info, exp = check(input.Text)
                if ok then
                    accept(input.Text, info, exp)
                    status.TextColor3 = Color3.fromRGB(120, 255, 160)
                    status.Text = "ok: " .. info
                    task.wait(0.6)
                else
                    status.TextColor3 = Color3.fromRGB(255, 110, 110)
                    status.Text = info
                end
            end
            task.wait(0.05)
        end
        gui:Destroy()
    end
end
if not env.ScorpionKeyOk then return end

-- ============================================================
--  КОНФИГ
-- ============================================================
local CONFIG_FILE = "scorpion_config.json"

local defaults = {
    -- camera
    fov = 70, zoomFov = 30, zoomKey = "", fcKey = "", fcHold = false, wcEnabled = false, wcStyle = 1, wcCustom = false, wcColor = 1, wcColor2 = 2, wcTransparency = 30, wcShimmer = true, aimLag = 150, wcSparkles = true, wcSparkDensity = 18, wcGlow = true, wcSpeed = 20, wcViewmodel = true, wcThird = true, tracerEnabled = false, tracerStyle = 1, tracerColor = 1, tracerRainbow = false, tracerThick = 100, tracerLife = 50, tracerRate = 100, tracerRepeat = true, tracerImpact = true, tracerFrom = 1, noRecoil = false, noRecoilPct = 100, noKickVm = true, tracerDetect = 1, skyOn = false, skyPreset = 1, skyHideBodies = true, aimEnabled = false, aimMode = 2, aimKey = "", aimPart = 1, aimFov = 120, aimShowFov = true, aimFovColor = 1, aimSmooth = 60, aimWalls = false, aimSticky = true, aimPredict = 0, aimDist = 1000, aimPriority = 1, aimHumanize = 20, aimDelay = 80, aimTargetHud = true, fcSpeed = 60, fcSens = 100, crossMode = 1,
    stretch = false, stretchX = 100, stretchY = 75,
    -- crosshair
    crosshairEnabled = false, cOffX = 0, cOffY = 0, crosshairStyle = 1, cLength = 6, cThickness = 2, cGap = 4, cSpeed = 150,
    cColor = 1, cRainbow = false, cOutline = true, cAlpha = 0,
    -- world
    customTimeEnabled = false, timeOfDay = 14, autoCycle = false, cycleSpeed = 6,
    vignetteEnabled = false,
    -- fx
    trailEnabled = false, jumpRingEnabled = false,
    -- highlight (свой персонаж / оружие)
    hlEnabled = false, hlChar = true, hlWeapon = true, hlColor = 1, hlFill = 65, hlOutline = 0,
    hlPulse = false, hlPulseSpeed = 3,
    -- arms skin
    skinEnabled = false, skinStyle = 1, skinColor = 1, skinTransparency = 45, skinReflect = 20,
    -- esp
    espEnabled = false, espBox = true, espName = true, espHealth = true, espDistance = true,
    espColor = 1, espMaxDist = 1500,
    espSnaplines = false, espSnapOrigin = 1, espHeadDot = false,
    espWeapon = false, espRainbow = false, espArrows = false, arrowRadius = 200,
    chamsRainbow = false,
    espBoxStyle = 1, boxFill = false, boxFillAlpha = 85, espSkeleton = false, espLook = false,
    espHpText = false, visCheck = false, dmgNumbers = false,
    -- chams
    chamsEnabled = false, chamsThrough = true, chamsColor = 3, chamsFill = 50, chamsOutline = 0,
    -- hitbox
    hbEnabled = false, hbSize = 8, hbTransparency = 70, hbPart = 1,
    -- lighting
    fullbright = false, noFog = false, ambientEnabled = false, ambientColor = 1,
    -- color grading / bloom
    ccEnabled = false, ccBrightness = 0, ccContrast = 0, ccSaturation = 0, ccTint = 1,
    bloomEnabled = false, bloomIntensity = 40,
    -- hud
    hudEnabled = false, hudFps = true, hudPing = true,
    radarEnabled = false, radarSize = 150, radarRange = 200,
    sunRaysEnabled = false, sunRaysIntensity = 25, noBlur = false,
    fogEnabled = false, fogColor = 1, fogDist = 800,
    weatherEnabled = false, weatherKind = 1, weatherColor = 1, weatherRainbow = false,
    weatherDensity = 40, weatherSpeed = 100, weatherSize = 100, weatherWind = 0,
    atmEnabled = false, atmColor = 1, atmDecay = 1, atmDensity = 30, atmHaze = 0, atmGlare = 0,
    shiftEnabled = false, shiftTop = 1, shiftBottom = 1, shiftCycle = false,
    dofEnabled = false, dofFocus = 60, dofRadius = 20, dofFar = 60,
    auraEnabled = false, auraColor = 1, auraRainbow = false, auraDensity = 20, auraSize = 100,
    auraStyle = 1, auraColor2 = 3, auraSpeed = 100,
    hlRainbow = false, vigStrength = 65,
    trailStyle = 1, trailColor = 1, trailColor2 = 3, trailMode = 1, trailWidth = 100, trailLife = 100, trailAlpha = 30,
    ringEnabled = false, ringStyle = 1, ringColor = 1, ringRainbow = false, ringSize = 100,
    ringThick = 100, ringAlpha = 20, ringSpeed = 100, jumpColor = 1,
    jumpStyle = 1, jumpRainbow = false, jumpSize = 100, jumpDuration = 100, jumpThick = 100, jumpAlpha = 20,
    -- menu
    uiScale = 100, menuKey = "Insert", menuAccent = 1, notify = true,
}

local cfg = {}
for k, v in pairs(defaults) do cfg[k] = v end

pcall(function()
    if isfile and readfile and isfile(CONFIG_FILE) then
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        for k, v in pairs(defaults) do
            if type(data[k]) == type(v) then cfg[k] = data[k] end
        end
    end
end)

local function SaveNow()
    pcall(function()
        if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end
    end)
end

local saveQueued = false
local function QueueSave()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.6, function()
        saveQueued = false
        SaveNow()
    end)
end

-- ============================================================
--  СОСТОЯНИЕ
-- ============================================================
cfg.dmgNumbers = false
if cfg.menuAccentVer ~= 3 then cfg.menuAccent = 1 cfg.menuAccentVer = 3 end
Accent = (AccentPresets[cfg.menuAccent] or AccentPresets[1])[2]

local unloaded = false
local zoomActive = false
local FCApi = {}
local Binding = false
local originalClock = Lighting.ClockTime
local originalFov = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70

local menuKey = Enum.KeyCode.Insert
do
    local ok, kc = pcall(function() return Enum.KeyCode[cfg.menuKey] end)
    if ok and kc then menuKey = kc end
end

local zoomKey
if cfg.zoomKey ~= "" then
    local ok, kc = pcall(function() return Enum.KeyCode[cfg.zoomKey] end)
    if ok then zoomKey = kc end
end

local timeSlider -- создаётся ниже, используется в рендер-цикле
local fovCur = cfg.fov -- текущее (сглаженное) значение FOV, которое мы сами держим

-- ============================================================
--  ПРИЦЕЛ
-- ============================================================
local ColorPresets = {
    {"White",  Color3.fromRGB(255, 255, 255)},
    {"Silver", Color3.fromRGB(190, 190, 196)},
    {"Ice",    Color3.fromRGB(170, 210, 255)},
    {"Mint",   Color3.fromRGB(160, 255, 215)},
    {"Rose",   Color3.fromRGB(255, 170, 195)},
    {"Black",  Color3.fromRGB(15, 15, 15)},
    {"Violet", Color3.fromRGB(190, 150, 255)},
    {"Orange", Color3.fromRGB(255, 175, 95)},
    {"Red",    Color3.fromRGB(255, 90, 90)},
    {"Blue",   Color3.fromRGB(90, 140, 255)},
    {"Green",  Color3.fromRGB(110, 255, 130)},
}
local ColorNames = {}
for i, c in ipairs(ColorPresets) do ColorNames[i] = c[1] end

local function rainbowColor()
    return Color3.fromHSV((os.clock() * 0.25) % 1, 0.85, 1)
end

local CrosshairGui = new("ScreenGui", {
    Name = "ScorpionCrosshair", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 990, Parent = GuiParent,
})
local updateCrosshair
do
local Cross = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(100, 100), BackgroundTransparency = 1, Visible = false, Parent = CrosshairGui,
})
local function crossPart(name)
    local f = new("Frame", {Name = name, BackgroundColor3 = Theme.White, BorderSizePixel = 0, Parent = Cross})
    stroke(f, 0.35, Theme.Black) -- тонкая чёрная обводка, чтобы было видно на светлом фоне
    return f
end
local cTop, cBottom, cLeft, cRight, cDot = crossPart("Top"), crossPart("Bottom"), crossPart("Left"), crossPart("Right"), crossPart("Dot")
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = cDot})

local cRing = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1,
    BorderSizePixel = 0, Visible = false, Parent = Cross,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = cRing})
local cRingStroke = new("UIStroke", {Thickness = 2, Color = Theme.White, Parent = cRing})


-- стили: 1 Cross, 2 Dot, 3 Spinning cross, 4 T-shape, 5 Circle, 6 Cross + dot, 7 X-cross, 8 Circle + dot, 9 Dynamic cross
local spin, dynGap = 0, 0
local crossParts = {cTop, cBottom, cLeft, cRight, cDot}

function updateCrosshair(dt)
    if not cfg.crosshairEnabled then
        Cross.Visible = false
        return
    end
    Cross.Visible = true
    do
        -- режимы: 1 авто (точка курсора, если мышь залочена, иначе центр), 2 центр экрана, 3 курсор
        -- координаты берём из самого ScreenGui (IgnoreGuiInset), поэтому инсет топбара не сдвигает прицел
        local size = CrosshairGui.AbsoluteSize
        local px, py = size.X / 2, size.Y / 2
        local mode = cfg.crossMode
        if mode == 3 or (mode == 1 and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter) then
            local m = UserInputService:GetMouseLocation()
            px, py = m.X, m.Y
        end
        Cross.Position = UDim2.fromOffset(math.floor(px + 0.5) + cfg.cOffX, math.floor(py + 0.5) + cfg.cOffY)
    end

    local len, th, gap, style = cfg.cLength, cfg.cThickness, cfg.cGap, cfg.crosshairStyle
    local color = cfg.cRainbow and rainbowColor() or (ColorPresets[cfg.cColor] or ColorPresets[1])[2]
    local alpha = cfg.cAlpha / 100

    -- динамический разброс: прицел раскрывается при движении
    if style == 9 then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local speed = 0
        if hrp then
            local v = hrp.AssemblyLinearVelocity
            speed = Vector3.new(v.X, 0, v.Z).Magnitude
        end
        local target = math.clamp(speed / 3, 0, 16)
        dynGap += (target - dynGap) * math.clamp(dt * 10, 0, 1)
        gap = gap + dynGap
    end

    local showLines = style ~= 2 and style ~= 5 and style ~= 8
    local showDot = style == 2 or style == 6 or style == 8
    local showRing = style == 5 or style == 8

    cTop.Visible, cBottom.Visible, cLeft.Visible, cRight.Visible = showLines, showLines, showLines, showLines
    cDot.Visible = showDot
    cRing.Visible = showRing
    Cross.Rotation = 0

    if showLines then
        cTop.Size = UDim2.fromOffset(th, len)
        cTop.Position = UDim2.new(0.5, -th / 2, 0.5, -gap - len)
        cBottom.Size = UDim2.fromOffset(th, len)
        cBottom.Position = UDim2.new(0.5, -th / 2, 0.5, gap)
        cLeft.Size = UDim2.fromOffset(len, th)
        cLeft.Position = UDim2.new(0.5, -gap - len, 0.5, -th / 2)
        cRight.Size = UDim2.fromOffset(len, th)
        cRight.Position = UDim2.new(0.5, gap, 0.5, -th / 2)

        if style == 4 then
            cTop.Visible = false
        elseif style == 3 then
            spin = (spin + cfg.cSpeed * dt) % 360
            Cross.Rotation = spin
        elseif style == 7 then
            Cross.Rotation = 45
        end
    end

    if showDot then
        local d = (style == 2) and math.clamp(len, 2, 12) or math.clamp(th + 1, 2, 8)
        cDot.Size = UDim2.fromOffset(d, d)
        cDot.Position = UDim2.new(0.5, -d / 2, 0.5, -d / 2)
    end

    if showRing then
        local d = math.max((len + gap) * 2, 8)
        cRing.Size = UDim2.fromOffset(d, d)
        cRingStroke.Thickness = th
        cRingStroke.Color = color
        cRingStroke.Transparency = alpha
    end

    for _, part in ipairs(crossParts) do
        part.BackgroundColor3 = color
        part.BackgroundTransparency = alpha
        local st = part:FindFirstChildOfClass("UIStroke")
        if st then st.Enabled = cfg.cOutline end
    end
end
end

-- ============================================================
--  ЭФФЕКТЫ: трейл, виньетка, кольцо при приземлении
-- ============================================================
local trailObjects = {}
local TRAIL_STYLES = {"Classic", "Ribbon", "Thin line", "Neon long", "Comet", "Sparks"}

local function setTrail(on)
    for _, o in ipairs(trailObjects) do o:Destroy() end
    trailObjects = {}
    if not on then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local c1 = (ColorPresets[cfg.trailColor] or ColorPresets[1])[2]
    local c2 = (ColorPresets[cfg.trailColor2] or ColorPresets[1])[2]
    local colorSeq
    if cfg.trailMode == 3 then
        colorSeq = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
            ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 140)),
            ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
        })
    elseif cfg.trailMode == 2 then
        colorSeq = ColorSequence.new(c1, c2)
    else
        colorSeq = ColorSequence.new(c1)
    end

    local alpha = cfg.trailAlpha / 100
    local w = cfg.trailWidth / 100
    local life = cfg.trailLife / 100
    local style = cfg.trailStyle

    -- 6: искры из-под ног
    if style == 6 then
        local feet = new("Attachment", {Position = Vector3.new(0, -2.5, 0), Parent = hrp})
        new("ParticleEmitter", {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = colorSeq, LockedToPart = false,
            Rate = 45, Lifetime = NumberRange.new(0.6 * life, 1.1 * life), Speed = NumberRange.new(0.5, 2.5),
            SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8, LightInfluence = 0,
            Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
            Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5 * w), NumberSequenceKeypoint.new(1, 0)}),
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, 1)}),
            Parent = feet,
        })
        trailObjects = {feet}
        return
    end

    -- span (ширина ленты), lifetime, свечение, сужение к хвосту, поворот к камере
    local cfgs = {
        {2.0, 0.4, 0.5, false, false}, -- Classic
        {3.2, 0.6, 0.3, false, false}, -- Ribbon
        {0.35, 0.9, 0.6, false, true}, -- Thin line
        {1.2, 1.4, 1.0, false, false}, -- Neon long
        {2.4, 0.8, 0.9, true, false},  -- Comet
    }
    local st = cfgs[style] or cfgs[1]
    local span = st[1] * w

    local a0 = new("Attachment", {Position = Vector3.new(0, span / 2, 0.5), Parent = hrp})
    local a1 = new("Attachment", {Position = Vector3.new(0, -span / 2, 0.5), Parent = hrp})
    local t = new("Trail", {
        Attachment0 = a0, Attachment1 = a1, Lifetime = st[2] * life, LightEmission = st[3], MinLength = 0.05,
        FaceCamera = st[5], Color = colorSeq,
        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, 1)}),
        WidthScale = st[4] and NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
            or NumberSequence.new(1),
        Parent = hrp,
    })
    trailObjects = {a0, a1, t}
end

local vignetteGui
local function setVignette(on)
    if vignetteGui then
        vignetteGui:Destroy()
        vignetteGui = nil
    end
    if not on then return end

    vignetteGui = new("ScreenGui", {
        Name = "ScorpionVignette", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 998, Parent = GuiParent,
    })
    local edge = 1 - cfg.vigStrength / 100
    local seq = NumberSequence.new({
        NumberSequenceKeypoint.new(0, edge),
        NumberSequenceKeypoint.new(0.25, 1),
        NumberSequenceKeypoint.new(0.75, 1),
        NumberSequenceKeypoint.new(1, edge),
    })
    for _, rot in ipairs({0, 90}) do
        local f = new("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = vignetteGui,
        })
        new("UIGradient", {Rotation = rot, Transparency = seq, Parent = f})
    end
end

function L.spawnJumpRing(char)
    if unloaded or not cfg.jumpRingEnabled then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end

    -- высота земли под персонажем
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {char}
    local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -20, 0), rp)
    local y
    if hit then
        y = hit.Position.Y + 0.06
    else
        local offset = (hum.RigType == Enum.HumanoidRigType.R6) and 3 or (hum.HipHeight + hrp.Size.Y / 2)
        y = hrp.Position.Y - offset + 0.06
    end
    local center = Vector3.new(hrp.Position.X, y, hrp.Position.Z)

    local style = cfg.jumpStyle
    local dur = 0.7 * cfg.jumpDuration / 100
    local maxD = 14 * cfg.jumpSize / 100
    local color = cfg.jumpRainbow and rainbowColor() or (ColorPresets[cfg.jumpColor] or ColorPresets[1])[2]
    local alpha = cfg.jumpAlpha / 100
    local thick = 14 * cfg.jumpThick / 100

    -- одна волна: часть на земле с SurfaceGui-кольцом, которое расширяется и растворяется
    local function burst(delay, mul, d, thickMul, filled)
        task.delay(delay, function()
            if unloaded then return end
            local part = new("Part", {
                Name = "ScorpionJumpRing", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
                CastShadow = false, Transparency = 1, Size = Vector3.new(0.5, 0.05, 0.5),
                CFrame = CFrame.new(center), Parent = workspace,
            })
            local gui = new("SurfaceGui", {
                Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
                CanvasSize = Vector2.new(256, 256), LightInfluence = 0, Adornee = part, Parent = part,
            })
            local fr = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = color, BackgroundTransparency = filled and math.min(alpha + 0.3, 0.9) or 1,
                BorderSizePixel = 0, Parent = gui,
            })
            new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fr})
            local st = new("UIStroke", {
                Color = color, Thickness = thick * thickMul, Transparency = alpha,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = fr,
            })
            local ti = TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local grow = TweenService:Create(part, ti, {Size = Vector3.new(maxD * mul, 0.05, maxD * mul)})
            TweenService:Create(st, ti, {Transparency = 1}):Play()
            if filled then TweenService:Create(fr, ti, {BackgroundTransparency = 1}):Play() end
            grow.Completed:Once(function() part:Destroy() end)
            grow:Play()
        end)
    end

    -- стили: 1 Ring, 2 Disc, 3 Double ring, 4 Shockwave
    if style == 1 then
        burst(0, 1, dur, 1, false)
    elseif style == 2 then
        burst(0, 1, dur, 0.6, true)
    elseif style == 3 then
        burst(0, 1, dur, 1, false)
        burst(0.12, 0.7, dur, 0.8, false)
    else
        burst(0, 1.5, dur * 0.55, 1.6, false)
    end
end

-- ============================================================
--  ПЕРСОНАЖ
-- ============================================================
local function setupCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.StateChanged:Connect(function(_, state)
            if state == Enum.HumanoidStateType.Landed then L.spawnJumpRing(char) end
        end)
    end

    if cfg.trailEnabled and char:WaitForChild("HumanoidRootPart", 5) and not unloaded then
        setTrail(true)
    end
end

if player.Character then task.spawn(setupCharacter, player.Character) end
bind(player.CharacterAdded, function(char) task.spawn(setupCharacter, char) end)

if cfg.vignetteEnabled then setVignette(true) end

-- ============================================================
--  МОДЕЛИ: подсветка своего персонажа / оружия и скины рук
--  (клиентская визуализация только своих объектов)
-- ============================================================

local SkinStyles = {
    {"Glass",       Enum.Material.Glass},
    {"Ice",         Enum.Material.Ice},
    {"Force field", Enum.Material.ForceField},
    {"Neon",        Enum.Material.Neon},
    {"Plastic",     Enum.Material.SmoothPlastic},
}
local SkinNames = {}
for i, s in ipairs(SkinStyles) do SkinNames[i] = s[1] end

-- ---------- подсветка ----------
local highlights = {}
local pulseT = 0

local function getViewmodel()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    for _, child in ipairs(cam:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "ScorpionChamsModel" then return child end
    end
    return nil
end

-- все модели в камере (оружие/руки вьюмодели: у разных игр их может быть несколько)
function L.vmModels()
    local out = {}
    local cam = workspace.CurrentCamera
    if cam then
        for _, child in ipairs(cam:GetChildren()) do
            if child:IsA("Model") and child.Name ~= "ScorpionChamsModel" then out[#out + 1] = child end
        end
    end
    return out
end

local function setHighlight(key, target)
    local hl = highlights[key]
    if not target then
        if hl then
            hl:Destroy()
            highlights[key] = nil
        end
        return
    end
    if hl and hl.Parent ~= target then
        hl:Destroy()
        hl = nil
    end
    if not hl then
        hl = new("Highlight", {
            Name = "ScorpionHL", Adornee = target, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = target,
        })
        highlights[key] = hl
    end
end

function L.refreshHighlights()
    if not cfg.hlEnabled then
        for key, hl in pairs(highlights) do
            hl:Destroy()
            highlights[key] = nil
        end
        return
    end
    local char = player.Character
    setHighlight("char", cfg.hlChar and char or nil)
    setHighlight("tool", (cfg.hlWeapon and char) and char:FindFirstChildOfClass("Tool") or nil)
    setHighlight("vm", cfg.hlWeapon and getViewmodel() or nil)
end

function L.applyHighlightLook()
    local color = cfg.hlRainbow and rainbowColor() or (ColorPresets[cfg.hlColor] or ColorPresets[1])[2]
    local fill = cfg.hlFill / 100
    if cfg.hlPulse then
        local k = (math.sin(pulseT * cfg.hlPulseSpeed) + 1) / 2
        fill = fill + (1 - fill) * 0.55 * k
    end
    local outline = cfg.hlOutline / 100
    for _, hl in pairs(highlights) do
        hl.FillColor = color
        hl.OutlineColor = color
        hl.FillTransparency = fill
        hl.OutlineTransparency = outline
    end
end

-- ---------- скины рук ----------
local skinStore = setmetatable({}, {__mode = "k"}) -- part -> оригинальные свойства
local ARM_WORDS = {"arm", "hand", "glove", "sleeve", "finger", "wrist", "elbow"}

local function isArmPart(p)
    if not p:IsA("BasePart") then return false end
    if p:FindFirstAncestorOfClass("Accessory") or p:FindFirstAncestorOfClass("Tool") then return false end
    local n = p.Name:lower()
    -- убираем слова оружия, в которых прячется «arm»/«hand» (handgun, firearm, armor, handguard ...)
    for _, w in ipairs({"armor", "firearm", "alarm", "farm", "charm", "harm", "warm", "handle", "handgun", "handguard", "handgrip", "handcuff", "guard"}) do
        n = n:gsub(w, "")
    end
    for _, w in ipairs(ARM_WORDS) do
        if n:find(w, 1, true) then return true end
    end
    return false
end

function L.collectArmParts()
    local list = {}
    local char = player.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if isArmPart(d) then list[#list + 1] = d end
        end
    end
    local cam = workspace.CurrentCamera
    if cam then
        for _, d in ipairs(cam:GetDescendants()) do
            if isArmPart(d) then list[#list + 1] = d end
        end
    end
    return list
end

local function restoreSkins()
    for p, s in pairs(skinStore) do
        if p.Parent then
            p.Material = s.Material
            p.Transparency = s.Transparency
            p.Color = s.Color
            p.Reflectance = s.Reflectance
        end
        skinStore[p] = nil
    end
end

function L.refreshSkins()
    if not cfg.skinEnabled then
        if next(skinStore) then restoreSkins() end
        return
    end
    local material = (SkinStyles[cfg.skinStyle] or SkinStyles[1])[2]
    local color = (ColorPresets[cfg.skinColor] or ColorPresets[1])[2]
    local transparency = cfg.skinTransparency / 100
    local reflectance = cfg.skinReflect / 100

    for _, p in ipairs(L.collectArmParts()) do
        local s = skinStore[p]
        if not s then
            -- уже невидимые части (хелперы вьюмодели) не трогаем, чтобы они не появились
            if p.Transparency < 0.95 then
                skinStore[p] = {
                    Material = p.Material, Transparency = p.Transparency, Color = p.Color, Reflectance = p.Reflectance,
                }
                s = skinStore[p]
            end
        end
        if s then
            if p.Material ~= material then p.Material = material end
            if p.Color ~= color then p.Color = color end
            if p.Transparency ~= transparency then p.Transparency = transparency end
            if p.Reflectance ~= reflectance then p.Reflectance = reflectance end
        end
    end
end

local modelTimer = 0
local skinTimer = 0
function L.updateModels(dt)
    pulseT += dt
    modelTimer -= dt
    if modelTimer <= 0 then
        modelTimer = 0.25
        L.refreshHighlights()
        -- скины рук сканируют все детали персонажа/камеры: делаем это редко, чтобы не было микрофризов
        skinTimer -= 0.25
        if skinTimer <= 0 then
            skinTimer = 1.5
            L.refreshSkins()
        end
    end
    L.applyHighlightLook()
end

function L.cleanupModels()
    for key, hl in pairs(highlights) do
        hl:Destroy()
        highlights[key] = nil
    end
    restoreSkins()
end

-- ============================================================
--  ESP / CHAMS / HITBOX (другие игроки)
-- ============================================================
local EspGui = new("ScreenGui", {
    Name = "ScorpionESP_Gui", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 500, Parent = GuiParent,
})

local targets = {}      -- plr -> {box, boxStroke, hpBack, hpFill, info, nameLbl, subLbl, hl}
local hbOriginals = setmetatable({}, {__mode = "k"})  -- part -> {Size, Transparency, CanCollide}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- виден ли игрок из камеры (без стен)
function L.isVisible(cam, char)
    local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not part then return false end
    local ignore = {char, cam}
    if player.Character then ignore[#ignore + 1] = player.Character end
    rayParams.FilterDescendantsInstances = ignore
    local origin = cam.CFrame.Position
    return workspace:Raycast(origin, part.Position - origin, rayParams) == nil
end

local R15_BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6_BONES = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}
local MAX_BONES = 14

local lastHp = setmetatable({}, {__mode = "k"}) -- humanoid -> прошлое здоровье

local function removeTarget(plr)
    local t = targets[plr]
    if not t then return end
    for _, k in ipairs({"box", "hpBack", "hpLbl", "nameLbl", "subLbl", "snap", "head", "arrow", "look", "hl"}) do
        if t[k] then t[k]:Destroy() end
    end
    for _, f in ipairs(t.corners) do f:Destroy() end
    for _, f in ipairs(t.bones) do f:Destroy() end
    targets[plr] = nil
end

-- ESP рисуется обычными Frame в экранных координатах (не BillboardGui),
-- поэтому stretch камеры не ломает позиции и ничего не "плавает"
function L.createTarget(plr)
    local t = {corners = {}, bones = {}}

    t.box = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.White, BackgroundTransparency = 1,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    t.boxStroke = new("UIStroke", {Thickness = 1.5, Color = Theme.White, Parent = t.box})

    for i = 1, 8 do
        t.corners[i] = new("Frame", {
            BackgroundColor3 = Theme.White, BorderSizePixel = 0, Visible = false, Parent = EspGui,
        })
    end

    t.hpBack = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.3,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    t.hpFill = new("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(80, 255, 120), BorderSizePixel = 0, Parent = t.hpBack,
    })
    t.hpLbl = makeText(EspGui, "", 11, Theme.White, Enum.TextXAlignment.Right)
    t.hpLbl.AnchorPoint = Vector2.new(1, 0.5)
    t.hpLbl.Size = UDim2.fromOffset(30, 12)
    t.hpLbl.TextStrokeTransparency = 0.4
    t.hpLbl.Visible = false

    t.nameLbl = makeText(EspGui, plr.DisplayName, 13, Theme.White, Enum.TextXAlignment.Center)
    t.nameLbl.AnchorPoint = Vector2.new(0.5, 1)
    t.nameLbl.Size = UDim2.fromOffset(200, 14)
    t.nameLbl.TextStrokeTransparency = 0.4
    t.nameLbl.Visible = false

    t.subLbl = makeText(EspGui, "", 12, Theme.TextDim, Enum.TextXAlignment.Center)
    t.subLbl.AnchorPoint = Vector2.new(0.5, 0)
    t.subLbl.Size = UDim2.fromOffset(200, 14)
    t.subLbl.TextStrokeTransparency = 0.4
    t.subLbl.Visible = false

    t.snap = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })

    t.look = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 2), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })

    for i = 1, MAX_BONES do
        t.bones[i] = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Theme.White,
            BorderSizePixel = 0, Visible = false, Parent = EspGui,
        })
    end

    t.head = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = t.head})

    t.arrow = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1,
        Text = "\u{25B6}", Font = Enum.Font.Arial, TextSize = 20, TextColor3 = Theme.White,
        TextStrokeTransparency = 0.3, TextStrokeColor3 = Theme.Black, Visible = false, Parent = EspGui,
    })

    t.hl = new("Highlight", {Name = "ScorpionChams", Enabled = false, Parent = EspGui})

    targets[plr] = t
    return t
end

local function restoreHitboxes()
    for part, o in pairs(hbOriginals) do
        if part.Parent then
            part.Size = o.Size
            part.Transparency = o.Transparency
            part.CanCollide = o.CanCollide
        end
        hbOriginals[part] = nil
    end
end

function L.hideTarget(t)
    t.box.Visible = false
    t.hpBack.Visible = false
    t.hpLbl.Visible = false
    t.nameLbl.Visible = false
    t.subLbl.Visible = false
    t.snap.Visible = false
    t.head.Visible = false
    t.arrow.Visible = false
    t.look.Visible = false
    for _, f in ipairs(t.corners) do f.Visible = false end
    for _, f in ipairs(t.bones) do f.Visible = false end
end

local function rnd(v) return math.floor(v + 0.5) end

-- линия между двумя экранными точками
local function setLine(f, a, b, color, thick)
    local d = b - a
    f.Size = UDim2.fromOffset(rnd(d.Magnitude), thick or 1)
    f.Position = UDim2.fromOffset(rnd((a.X + b.X) / 2), rnd((a.Y + b.Y) / 2))
    f.Rotation = math.deg(math.atan2(d.Y, d.X))
    f.BackgroundColor3 = color
    f.Visible = true
end

local function hbApply(part, on)
    if not part then return end
    if on then
        if not hbOriginals[part] then
            hbOriginals[part] = {Size = part.Size, Transparency = part.Transparency, CanCollide = part.CanCollide}
        end
        local sz = cfg.hbSize
        local size = Vector3.new(sz, sz, sz)
        if part.Size ~= size then part.Size = size end
        part.Transparency = cfg.hbTransparency / 100
        part.CanCollide = false
    elseif hbOriginals[part] then
        local o = hbOriginals[part]
        part.Size = o.Size
        part.Transparency = o.Transparency
        part.CanCollide = o.CanCollide
        hbOriginals[part] = nil
    end
end

-- ---------- цифры урона ----------

function L.spawnDamageNumber(x, y, amount)
    local k = math.clamp(amount / 60, 0, 1)
    local lbl = makeText(EspGui, "-" .. math.floor(amount + 0.5), 16, Color3.new(1, 1 - k * 0.6, 1 - k * 0.6), Enum.TextXAlignment.Center)
    lbl.Font = Enum.Font.GothamBold
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.Size = UDim2.fromOffset(80, 20)
    lbl.Position = UDim2.fromOffset(rnd(x), rnd(y))
    lbl.TextStrokeTransparency = 0.3
    TweenService:Create(lbl, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.fromOffset(rnd(x) + math.random(-12, 12), rnd(y) - 45),
        TextTransparency = 1, TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.85, function() lbl:Destroy() end)
end

function L.updateTargets()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local espColor = cfg.espRainbow and rainbowColor() or (ColorPresets[cfg.espColor] or ColorPresets[1])[2]
    local chamsColor = cfg.chamsRainbow and rainbowColor() or (ColorPresets[cfg.chamsColor] or ColorPresets[1])[2]
    local camPos = cam.CFrame.Position
    local vs = cam.ViewportSize

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local alive = hum and hrp and hum.Health > 0

            local t = targets[plr] or L.createTarget(plr)

            -- цвет по видимости: зелёный — виден, красный — за стеной
            local espColor, chamsColor = espColor, chamsColor
            if cfg.visCheck and alive and (cfg.espEnabled or cfg.chamsEnabled) then
                local c = L.isVisible(cam, char) and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 90, 90)
                espColor, chamsColor = c, c
            end

            -- ESP
            local dist = alive and (hrp.Position - camPos).Magnitude or math.huge
            local showEsp = cfg.espEnabled and alive and dist <= cfg.espMaxDist
            local drawn = false
            local onScr = false

            if showEsp then
                local pos = hrp.Position
                local feetOffset = (hum.RigType == Enum.HumanoidRigType.R6) and 3 or (hum.HipHeight + 1)
                local top = cam:WorldToViewportPoint(pos + Vector3.new(0, 2.6, 0))
                local bot = cam:WorldToViewportPoint(pos - Vector3.new(0, feetOffset, 0))

                if top.Z > 0 and bot.Z > 0 then
                    drawn = true
                    local h = math.max(math.abs(bot.Y - top.Y), 4)
                    local w = h * 0.55
                    local cx = (top.X + bot.X) / 2
                    local cy = (top.Y + bot.Y) / 2
                    local topY = cy - h / 2
                    local botY = cy + h / 2
                    local x0 = cx - w / 2
                    onScr = cx >= 0 and cx <= vs.X and cy >= 0 and cy <= vs.Y

                    -- box (полный / уголки) + заливка
                    local cornerMode = cfg.espBoxStyle == 2
                    t.box.Visible = cfg.espBox or cfg.boxFill
                    t.box.Position = UDim2.fromOffset(rnd(cx), rnd(cy))
                    t.box.Size = UDim2.fromOffset(rnd(w), rnd(h))
                    t.boxStroke.Enabled = cfg.espBox and not cornerMode
                    t.boxStroke.Color = espColor
                    t.box.BackgroundColor3 = espColor
                    t.box.BackgroundTransparency = cfg.boxFill and (cfg.boxFillAlpha / 100) or 1

                    if cfg.espBox and cornerMode then
                        local L = math.max(math.min(w, h) * 0.28, 4)
                        local th = 2
                        local X0, Y0, X1, Y1 = x0, topY, x0 + w, botY
                        local spec = {
                            {X0, Y0, L, th}, {X0, Y0, th, L},
                            {X1 - L, Y0, L, th}, {X1 - th, Y0, th, L},
                            {X0, Y1 - th, L, th}, {X0, Y1 - L, th, L},
                            {X1 - L, Y1 - th, L, th}, {X1 - th, Y1 - L, th, L},
                        }
                        for i = 1, 8 do
                            local sp = spec[i]
                            local f = t.corners[i]
                            f.Position = UDim2.fromOffset(rnd(sp[1]), rnd(sp[2]))
                            f.Size = UDim2.fromOffset(rnd(sp[3]), rnd(sp[4]))
                            f.BackgroundColor3 = espColor
                            f.Visible = true
                        end
                    else
                        for _, f in ipairs(t.corners) do f.Visible = false end
                    end

                    -- health bar + число
                    t.hpBack.Visible = cfg.espHealth
                    t.hpLbl.Visible = cfg.espHealth and cfg.espHpText
                    if cfg.espHealth then
                        local a = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        t.hpBack.Position = UDim2.fromOffset(rnd(x0) - 3, rnd(cy))
                        t.hpBack.Size = UDim2.fromOffset(3, rnd(h))
                        t.hpFill.Size = UDim2.fromScale(1, a)
                        t.hpFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 255, 120), a)
                        if cfg.espHpText then
                            t.hpLbl.Text = tostring(math.floor(hum.Health + 0.5))
                            t.hpLbl.Position = UDim2.fromOffset(rnd(x0) - 8, rnd(botY - a * h))
                        end
                    end

                    -- name / distance / weapon
                    t.nameLbl.Visible = cfg.espName
                    if cfg.espName then
                        t.nameLbl.Text = plr.DisplayName
                        t.nameLbl.TextColor3 = espColor
                        t.nameLbl.Position = UDim2.fromOffset(rnd(cx), rnd(topY) - 3)
                    end
                    local sub = {}
                    if cfg.espDistance then sub[#sub + 1] = string.format("%d studs", dist) end
                    if cfg.espWeapon then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then sub[#sub + 1] = tool.Name end
                    end
                    t.subLbl.Visible = #sub > 0
                    if #sub > 0 then
                        t.subLbl.Text = table.concat(sub, "  |  ")
                        t.subLbl.Position = UDim2.fromOffset(rnd(cx), rnd(botY) + 3)
                    end

                    -- snapline
                    t.snap.Visible = cfg.espSnaplines
                    if cfg.espSnaplines then
                        local oy = (cfg.espSnapOrigin == 3) and 0 or ((cfg.espSnapOrigin == 2) and vs.Y / 2 or vs.Y)
                        setLine(t.snap, Vector2.new(vs.X / 2, oy), Vector2.new(cx, botY), espColor, 1)
                    end

                    -- skeleton
                    if cfg.espSkeleton then
                        local list = (hum.RigType == Enum.HumanoidRigType.R6) and R6_BONES or R15_BONES
                        for i = 1, MAX_BONES do
                            local f = t.bones[i]
                            local pair = list[i]
                            local ok = false
                            if pair then
                                local pa, pb = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
                                if pa and pb then
                                    local va = cam:WorldToViewportPoint(pa.Position)
                                    local vb = cam:WorldToViewportPoint(pb.Position)
                                    if va.Z > 0 and vb.Z > 0 then
                                        setLine(f, Vector2.new(va.X, va.Y), Vector2.new(vb.X, vb.Y), espColor, 1)
                                        ok = true
                                    end
                                end
                            end
                            if not ok then f.Visible = false end
                        end
                    else
                        for _, f in ipairs(t.bones) do f.Visible = false end
                    end

                    -- head dot / куда смотрит игрок
                    local headPart = char:FindFirstChild("Head")
                    t.head.Visible = false
                    t.look.Visible = false
                    if headPart then
                        local hp = cam:WorldToViewportPoint(headPart.Position)
                        if cfg.espHeadDot and hp.Z > 0 then
                            t.head.Visible = true
                            t.head.Position = UDim2.fromOffset(rnd(hp.X), rnd(hp.Y))
                            t.head.BackgroundColor3 = espColor
                        end
                        if cfg.espLook and hp.Z > 0 then
                            local p1 = cam:WorldToViewportPoint(headPart.Position + headPart.CFrame.LookVector * 6)
                            if p1.Z > 0 then
                                setLine(t.look, Vector2.new(hp.X, hp.Y), Vector2.new(p1.X, p1.Y), espColor, 2)
                            end
                        end
                    end
                end
            end
            if not drawn then L.hideTarget(t) end

            -- стрелка, если игрок за экраном
            local arrowOn = false
            if showEsp and cfg.espArrows and not onScr then
                local rel = cam.CFrame:PointToObjectSpace(hrp.Position)
                local v = Vector2.new(rel.X, rel.Z)
                if v.Magnitude > 0.001 then
                    v = v.Unit
                    local r = cfg.arrowRadius
                    t.arrow.Position = UDim2.fromOffset(rnd(vs.X / 2 + v.X * r), rnd(vs.Y / 2 + v.Y * r))
                    t.arrow.Rotation = math.deg(math.atan2(v.Y, v.X))
                    t.arrow.TextColor3 = espColor
                    arrowOn = true
                end
            end
            t.arrow.Visible = arrowOn

            -- Chams
            if cfg.chamsEnabled and alive then
                t.hl.Adornee = char
                t.hl.Enabled = true
                t.hl.DepthMode = cfg.chamsThrough and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                t.hl.FillColor = chamsColor
                t.hl.OutlineColor = chamsColor
                t.hl.FillTransparency = cfg.chamsFill / 100
                t.hl.OutlineTransparency = cfg.chamsOutline / 100
            else
                t.hl.Enabled = false
            end

            -- хитмаркер / цифры урона (враг в прицеле потерял здоровье)
            if hum then
                local prev = lastHp[hum]
                lastHp[hum] = hum.Health
                if prev and hum.Health < prev and hrp and cfg.dmgNumbers then
                    local sp = cam:WorldToViewportPoint(hrp.Position)
                    if sp.Z > 0 and (Vector2.new(sp.X, sp.Y) - vs / 2).Magnitude < 220 then
                        if cfg.dmgNumbers then L.spawnDamageNumber(sp.X, sp.Y - 40, prev - hum.Health) end
                    end
                end
            end

            -- Hitbox (1 = голова, 2 = тело, 3 = оба)
            local hbOn = cfg.hbEnabled and alive
            hbApply(hrp, hbOn and cfg.hbPart ~= 1)
            hbApply(char and char:FindFirstChild("Head"), hbOn and cfg.hbPart ~= 2)
        end
    end
end

function L.cleanupTargets()
    for plr in pairs(targets) do removeTarget(plr) end
    restoreHitboxes()
    pcall(function() EspGui:Destroy() end)
end

bind(Players.PlayerRemoving, removeTarget)

-- ============================================================
--  ВИЗУАЛ: освещение, цветокоррекция, bloom, HUD
-- ============================================================
local Stats = game:GetService("Stats")

local TintPresets = {
    {"None", Color3.fromRGB(255, 255, 255)},
    {"Warm", Color3.fromRGB(255, 232, 205)},
    {"Cool", Color3.fromRGB(205, 225, 255)},
    {"Mint", Color3.fromRGB(205, 255, 232)},
    {"Rose", Color3.fromRGB(255, 210, 225)},
}
local TintNames = {}
for i, c in ipairs(TintPresets) do TintNames[i] = c[1] end

-- ---------- освещение: fullbright / без тумана / цвет ambient ----------
local lightOrig, atmOrig
local lightActive = false

local function setProp(obj, prop, v)
    if obj[prop] ~= v then obj[prop] = v end
end

function L.updateLighting()
    local want = cfg.fullbright or cfg.noFog or cfg.ambientEnabled or cfg.fogEnabled
    if not want and not lightActive then return end

    if not lightOrig then
        lightOrig = {
            Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
            GlobalShadows = Lighting.GlobalShadows, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
            FogColor = Lighting.FogColor,
        }
    end
    local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    if atm and not atmOrig then atmOrig = {Density = atm.Density, Haze = atm.Haze} end

    local o = lightOrig
    local brightness, ambient, outdoor, shadows = o.Brightness, o.Ambient, o.OutdoorAmbient, o.GlobalShadows
    local fogStart, fogEnd = o.FogStart, o.FogEnd
    local fogColor = o.FogColor

    if want then
        if cfg.fullbright then
            brightness = 2
            ambient = Color3.fromRGB(190, 190, 190)
            outdoor = ambient
            shadows = false
        elseif cfg.ambientEnabled then
            local c = (ColorPresets[cfg.ambientColor] or ColorPresets[1])[2]
            ambient, outdoor = c, c
        end
        if cfg.noFog then
            fogStart, fogEnd = 1e6, 1e6
        elseif cfg.fogEnabled then
            fogStart, fogEnd = cfg.fogDist * 0.15, cfg.fogDist
            fogColor = (ColorPresets[cfg.fogColor] or ColorPresets[1])[2]
        end
    end

    setProp(Lighting, "Brightness", brightness)
    setProp(Lighting, "Ambient", ambient)
    setProp(Lighting, "OutdoorAmbient", outdoor)
    setProp(Lighting, "GlobalShadows", shadows)
    setProp(Lighting, "FogStart", fogStart)
    setProp(Lighting, "FogEnd", fogEnd)
    setProp(Lighting, "FogColor", fogColor)
    if atm and atmOrig then
        local clear = want and cfg.noFog
        setProp(atm, "Density", clear and 0 or atmOrig.Density)
        setProp(atm, "Haze", clear and 0 or atmOrig.Haze)
    end

    if want then
        lightActive = true
    else
        lightActive = false
        lightOrig, atmOrig = nil, nil
    end
end

-- ---------- цветокоррекция и bloom ----------
local ccEffect = new("ColorCorrectionEffect", {Name = "ScorpionCC", Enabled = false, Parent = Lighting})
local bloomEffect = new("BloomEffect", {
    Name = "ScorpionBloom", Enabled = false, Intensity = 0.4, Size = 24, Threshold = 0.8, Parent = Lighting,
})

local sunEffect = new("SunRaysEffect", {
    Name = "ScorpionSun", Enabled = false, Intensity = 0.25, Spread = 0.8, Parent = Lighting,
})

function L.updatePost()
    ccEffect.Enabled = cfg.ccEnabled
    if cfg.ccEnabled then
        ccEffect.Brightness = cfg.ccBrightness / 100
        ccEffect.Contrast = cfg.ccContrast / 100
        ccEffect.Saturation = cfg.ccSaturation / 100
        ccEffect.TintColor = (TintPresets[cfg.ccTint] or TintPresets[1])[2]
    end
    bloomEffect.Enabled = cfg.bloomEnabled
    if cfg.bloomEnabled then bloomEffect.Intensity = cfg.bloomIntensity / 100 end
    sunEffect.Enabled = cfg.sunRaysEnabled
    if cfg.sunRaysEnabled then sunEffect.Intensity = cfg.sunRaysIntensity / 100 end
end

-- ---------- HUD: fps / ping ----------
local HudGui = new("ScreenGui", {
    Name = "ScorpionHUD", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 997, Parent = GuiParent,
})
local HudFrame = new("Frame", {
    Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
    BackgroundColor3 = Theme.Back, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, Parent = HudGui,
})
new("UICorner", {CornerRadius = UDim.new(0, 3), Parent = HudFrame})
stroke(HudFrame, 0.8)
new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = HudFrame})
local HudLabel = new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
    RichText = true, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.White, Text = "", Parent = HudFrame,
})

local hudAcc, hudFrames = 0, 0
function L.getPing()
    local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and v then return math.floor(v) end
    local ok2, p = pcall(function() return player:GetNetworkPing() * 1000 end)
    return ok2 and math.floor(p) or 0
end

function L.updateHud(dt)
    HudFrame.Visible = cfg.hudEnabled
    if not cfg.hudEnabled then return end
    hudAcc += dt
    hudFrames += 1
    if hudAcc >= 0.5 then
        local parts = {'<font color="#FFFFFF">scorpion</font><font color="#8A8A8A">.wtf</font>'}
        if cfg.hudFps then parts[#parts + 1] = math.floor(hudFrames / hudAcc + 0.5) .. " fps" end
        if cfg.hudPing then parts[#parts + 1] = L.getPing() .. " ms" end
        HudLabel.Text = table.concat(parts, "  |  ")
        hudAcc, hudFrames = 0, 0
    end
end

-- ---------- убрать блюр / вспышки игры ----------
local blurStore = setmetatable({}, {__mode = "k"})
local blurTimer = 0

local function scanBlur(parent)
    for _, o in ipairs(parent:GetChildren()) do
        if (o:IsA("BlurEffect") or o:IsA("DepthOfFieldEffect")) and o.Name:sub(1, 8) ~= "Scorpion" then
            if blurStore[o] == nil then blurStore[o] = o.Enabled end
            if o.Enabled then o.Enabled = false end
        end
    end
end

function L.updateNoBlur(dt)
    blurTimer -= dt
    if blurTimer > 0 then return end
    blurTimer = 0.2
    if cfg.noBlur then
        scanBlur(Lighting)
        local cam = workspace.CurrentCamera
        if cam then scanBlur(cam) end
    elseif next(blurStore) then
        for o, en in pairs(blurStore) do
            if o.Parent then o.Enabled = en end
            blurStore[o] = nil
        end
    end
end

-- ---------- радар ----------
local RadarFrame = new("Frame", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(150, 150),
    BackgroundColor3 = Theme.Back, BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false,
    ClipsDescendants = true, Parent = HudGui,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = RadarFrame})
stroke(RadarFrame, 0.75)
line(RadarFrame, UDim2.new(0.5, 0, 0, 0), UDim2.new(0, 1, 1, 0))
line(RadarFrame, UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 1))
local radarSelf = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 5),
    BackgroundColor3 = Theme.White, BorderSizePixel = 0, Parent = RadarFrame,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = radarSelf})

local radarDots = {}
bind(Players.PlayerRemoving, function(plr)
    local d = radarDots[plr]
    if d then
        d:Destroy()
        radarDots[plr] = nil
    end
end)

function L.updateRadar()
    RadarFrame.Visible = cfg.radarEnabled
    if not cfg.radarEnabled then return end

    local size = cfg.radarSize
    RadarFrame.Size = UDim2.fromOffset(size, size)

    local cam = workspace.CurrentCamera
    local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local look = cam and cam.CFrame.LookVector
    local f = look and Vector3.new(look.X, 0, look.Z)
    if not (myHrp and f and f.Magnitude > 0.001) then
        for _, d in pairs(radarDots) do d.Visible = false end
        return
    end
    f = f.Unit
    local right = Vector3.new(-f.Z, 0, f.X)
    local radius = size / 2 - 4

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local d = radarDots[plr]
            if not d then
                d = new("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BorderSizePixel = 0,
                    Visible = false, Parent = RadarFrame,
                })
                new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = d})
                radarDots[plr] = d
            end

            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local dx = hrp.Position - myHrp.Position
                local v = Vector2.new(dx:Dot(right), -dx:Dot(f)) / cfg.radarRange * radius
                if v.Magnitude > radius then v = v.Unit * radius end
                d.Position = UDim2.new(0.5, rnd(v.X), 0.5, rnd(v.Y))
                d.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
                d.Visible = true
            else
                d.Visible = false
            end
        end
    end
end

-- ---------- уведомления ----------
local ToastHolder = new("Frame", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(230, 220),
    BackgroundTransparency = 1, Parent = HudGui,
})
new("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder, Parent = ToastHolder,
})
local toastId = 0

local function Notify(text)
    if not cfg.notify or unloaded then return end
    toastId += 1
    local f = new("Frame", {
        Size = UDim2.fromOffset(210, 22), BackgroundColor3 = Theme.Back, BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = toastId, Parent = ToastHolder,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 3), Parent = f})
    local st = stroke(f, 1)
    local bar = new("Frame", {Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = f})
    local lbl = makeText(f, text, 13, Theme.White)
    lbl.Position = UDim2.fromOffset(10, 0)
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.TextTransparency = 1
    lbl.TextStrokeTransparency = 1

    local tin = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(f, tin, {BackgroundTransparency = 0.25}):Play()
    TweenService:Create(st, tin, {Transparency = 0.8}):Play()
    TweenService:Create(bar, tin, {BackgroundTransparency = 0}):Play()
    TweenService:Create(lbl, tin, {TextTransparency = 0}):Play()

    task.delay(1.8, function()
        if unloaded then return end
        local tout = TweenInfo.new(0.25)
        TweenService:Create(f, tout, {BackgroundTransparency = 1}):Play()
        TweenService:Create(st, tout, {Transparency = 1}):Play()
        TweenService:Create(bar, tout, {BackgroundTransparency = 1}):Play()
        TweenService:Create(lbl, tout, {TextTransparency = 1}):Play()
        task.wait(0.3)
        f:Destroy()
    end)
end

-- ---------- погода (снег / дождь / сакура / угли / пыль) ----------
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local WeatherKinds = {"Snow", "Rain", "Sakura", "Embers", "Dust"}
local WeatherColorNames = {"Auto"}
for _, c in ipairs(ColorPresets) do WeatherColorNames[#WeatherColorNames + 1] = c[1] end
local WeatherAuto = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 200, 255), Color3.fromRGB(255, 170, 200),
    Color3.fromRGB(255, 140, 60), Color3.fromRGB(235, 235, 235),
}

local weatherPart, weatherEmitter, weatherSig

function L.ensureWeather()
    if weatherPart and weatherPart.Parent then return end
    weatherPart = new("Part", {
        Name = "ScorpionWeather", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        CastShadow = false, Transparency = 1, Size = Vector3.new(90, 1, 90), Parent = workspace,
    })
    weatherEmitter = new("ParticleEmitter", {Parent = weatherPart})
    weatherSig = nil
end

local function weatherColor()
    if cfg.weatherRainbow then return rainbowColor() end
    if cfg.weatherColor <= 1 then return WeatherAuto[cfg.weatherKind] or WeatherAuto[1] end
    return (ColorPresets[cfg.weatherColor - 1] or ColorPresets[1])[2]
end

local function fadeSeq(mid)
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, mid),
        NumberSequenceKeypoint.new(0.88, mid), NumberSequenceKeypoint.new(1, 1),
    })
end

function L.configWeather()
    local e, k = weatherEmitter, cfg.weatherKind
    local sp, sz, wind, dens = cfg.weatherSpeed / 100, cfg.weatherSize / 100, cfg.weatherWind, cfg.weatherDensity

    e.Texture = SPARK
    e.LockedToPart = false
    e.Shape = Enum.ParticleEmitterShape.Box
    e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
    e.Orientation = Enum.ParticleOrientation.FacingCamera
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-30, 30)
    e.SpreadAngle = Vector2.new(0, 0)
    e.Drag = 0
    e.LightInfluence = 0
    e.LightEmission = 0.2
    e.EmissionDirection = Enum.NormalId.Bottom
    weatherPart.Size = Vector3.new(90, 1, 90)

    if k == 1 then -- снег
        e.Rate = dens * 5
        e.Lifetime = NumberRange.new(40 / (6 * sp), 40 / (4 * sp))
        e.Speed = NumberRange.new(4 * sp, 6 * sp)
        e.Size = NumberSequence.new(0.35 * sz)
        e.Transparency = fadeSeq(0.15)
        e.Acceleration = Vector3.new(wind, 0, wind * 0.3)
    elseif k == 2 then -- дождь
        e.Rate = dens * 12
        e.Lifetime = NumberRange.new(60 / (100 * sp))
        e.Speed = NumberRange.new(90 * sp, 110 * sp)
        e.Size = NumberSequence.new(0.5 * sz)
        e.Orientation = Enum.ParticleOrientation.VelocityParallel
        e.RotSpeed = NumberRange.new(0)
        e.LightEmission = 0.1
        e.Transparency = NumberSequence.new(0.45)
        e.Acceleration = Vector3.new(wind * 3, 0, wind)
    elseif k == 3 then -- сакура
        e.Rate = dens * 1.6
        e.Lifetime = NumberRange.new(9, 12)
        e.Speed = NumberRange.new(2 * sp, 4 * sp)
        e.Size = NumberSequence.new(0.6 * sz)
        e.RotSpeed = NumberRange.new(-90, 90)
        e.Transparency = fadeSeq(0.1)
        e.Acceleration = Vector3.new(wind, -0.4, wind * 0.6)
        e.SpreadAngle = Vector2.new(25, 25)
    elseif k == 4 then -- угли (летят вверх)
        e.Rate = dens * 1.8
        e.EmissionDirection = Enum.NormalId.Top
        e.Lifetime = NumberRange.new(4, 6)
        e.Speed = NumberRange.new(4 * sp, 8 * sp)
        e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5 * sz), NumberSequenceKeypoint.new(1, 0)})
        e.LightEmission = 1
        e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
        e.Acceleration = Vector3.new(wind, 2, wind * 0.3)
        e.SpreadAngle = Vector2.new(20, 20)
    else -- пыль в воздухе
        weatherPart.Size = Vector3.new(60, 30, 60)
        e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        e.Rate = dens * 1.5
        e.EmissionDirection = Enum.NormalId.Top
        e.Lifetime = NumberRange.new(8, 11)
        e.Speed = NumberRange.new(0.2 * sp, 0.8 * sp)
        e.Size = NumberSequence.new(0.14 * sz)
        e.LightEmission = 0.4
        e.Transparency = fadeSeq(0.55)
        e.Acceleration = Vector3.new(wind * 0.2, 0, 0)
        e.SpreadAngle = Vector2.new(180, 180)
    end
end

function L.updateWeather()
    if not cfg.weatherEnabled then
        if weatherPart then
            weatherPart:Destroy()
            weatherPart, weatherEmitter, weatherSig = nil, nil, nil
        end
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    L.ensureWeather()

    local sig = table.concat({
        cfg.weatherKind, cfg.weatherDensity, cfg.weatherSpeed, cfg.weatherSize, cfg.weatherWind,
    }, "|")
    if sig ~= weatherSig then
        weatherSig = sig
        L.configWeather()
    end
    weatherEmitter.Enabled = true
    weatherEmitter.Color = ColorSequence.new(weatherColor())

    local pos = cam.CFrame.Position
    local k = cfg.weatherKind
    if k == 4 then
        weatherPart.CFrame = CFrame.new(pos + Vector3.new(0, -10, 0))
    elseif k == 5 then
        weatherPart.CFrame = CFrame.new(pos)
    else
        weatherPart.CFrame = CFrame.new(pos + Vector3.new(0, 38, 0))
    end
end

-- ---------- кастомная атмосфера и цветовой сдвиг неба ----------
local atmStore, atmCreated, shiftStore

local function updateAtmosphere(dt)
    local atm = Lighting:FindFirstChildOfClass("Atmosphere")

    if cfg.atmEnabled then
        if not atm then
            atm = new("Atmosphere", {Name = "ScorpionAtmosphere", Parent = Lighting})
            atmCreated = atm
        end
        if not atmStore then
            atmStore = {
                Color = atm.Color, Decay = atm.Decay, Density = atm.Density,
                Haze = atm.Haze, Glare = atm.Glare, Offset = atm.Offset, Target = atm,
            }
        end
        setProp(atm, "Color", (ColorPresets[cfg.atmColor] or ColorPresets[1])[2])
        setProp(atm, "Decay", (ColorPresets[cfg.atmDecay] or ColorPresets[1])[2])
        setProp(atm, "Glare", cfg.atmGlare / 10)
        if not cfg.noFog then
            setProp(atm, "Density", cfg.atmDensity / 100)
            setProp(atm, "Haze", cfg.atmHaze / 10)
        end
    elseif atmStore then
        local st = atmStore
        if st.Target and st.Target.Parent and st.Target ~= atmCreated then
            st.Target.Color, st.Target.Decay, st.Target.Density = st.Color, st.Decay, st.Density
            st.Target.Haze, st.Target.Glare, st.Target.Offset = st.Haze, st.Glare, st.Offset
        end
        if atmCreated then
            atmCreated:Destroy()
            atmCreated = nil
        end
        atmStore = nil
    end

    -- цветовой сдвиг неба / света
    if cfg.shiftEnabled then
        if not shiftStore then
            shiftStore = {Top = Lighting.ColorShift_Top, Bottom = Lighting.ColorShift_Bottom}
        end
        if cfg.shiftCycle then
            local h = (os.clock() * 0.06) % 1
            Lighting.ColorShift_Top = Color3.fromHSV(h, 0.55, 1)
            Lighting.ColorShift_Bottom = Color3.fromHSV((h + 0.5) % 1, 0.55, 1)
        else
            Lighting.ColorShift_Top = (ColorPresets[cfg.shiftTop] or ColorPresets[1])[2]
            Lighting.ColorShift_Bottom = (ColorPresets[cfg.shiftBottom] or ColorPresets[1])[2]
        end
    elseif shiftStore then
        Lighting.ColorShift_Top = shiftStore.Top
        Lighting.ColorShift_Bottom = shiftStore.Bottom
        shiftStore = nil
    end
end

-- ---------- кино-полосы и глубина резкости ----------
local dofEffect = new("DepthOfFieldEffect", {
    Name = "ScorpionDoF", Enabled = false, FarIntensity = 0.6, NearIntensity = 0,
    FocusDistance = 60, InFocusRadius = 20, Parent = Lighting,
})

function L.updateCinematic()
    dofEffect.Enabled = cfg.dofEnabled
    if cfg.dofEnabled then
        dofEffect.FocusDistance = cfg.dofFocus
        dofEffect.InFocusRadius = cfg.dofRadius
        dofEffect.FarIntensity = cfg.dofFar / 100
    end
end

-- ---------- аура вокруг своего персонажа ----------
local updateAura, cleanupAura
do
    local kp = NumberSequenceKeypoint.new
    local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
    local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
    local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
    local ARC = NumberSequence.new({kp(0, 0), kp(0.4, 0), kp(0.41, 1), kp(1, 1)})

    local objs, em, halo, orbs = {}, {}, {}, {}
    local builtHrp, builtStyle, lastSig
    local phase = 0

    local function clear()
        for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        objs, em, halo, orbs = {}, {}, {}, {}
        builtHrp, builtStyle, lastSig = nil, nil, nil
    end
    cleanupAura = clear

    local function emitter(parent, props)
        props.Parent = parent
        local e = new("ParticleEmitter", props)
        objs[#objs + 1] = e
        return e
    end

    local function mkSpark(hrp)
        return emitter(hrp, {
            Texture = TEX_SPARK, LockedToPart = false, Lifetime = NumberRange.new(1, 1.8),
            SpreadAngle = Vector2.new(180, 180), LightEmission = 0.9, LightInfluence = 0,
            Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-80, 80), Acceleration = Vector3.new(0, 1.5, 0),
        })
    end

    -- кольцо-нимб: SurfaceGui с вращающейся дугой с двух сторон
    local function mkHalo()
        local part = new("Part", {
            Name = "ScorpionHalo", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
            CastShadow = false, Transparency = 1, Size = Vector3.new(3, 0.05, 3), Parent = workspace,
        })
        local strokes = {}
        for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom}) do
            local gui = new("SurfaceGui", {
                Face = face, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(256, 256),
                LightInfluence = 0, Adornee = part, Parent = part,
            })
            local fr = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui,
            })
            new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fr})
            local st = new("UIStroke", {Thickness = 12, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = fr})
            new("UIGradient", {Transparency = ARC, Parent = st})
            strokes[#strokes + 1] = st
        end
        objs[#objs + 1] = part
        return {part = part, strokes = strokes}
    end

    -- стили: 1 Sparkles, 2 Flame, 3 Halo, 4 Orbit
    local function build(hrp, style)
        clear()
        builtHrp, builtStyle = hrp, style
        if style == 1 then
            em.haze = emitter(hrp, {
                Texture = TEX_SMOKE, LockedToPart = false, Lifetime = NumberRange.new(1.4, 2.2),
                SpreadAngle = Vector2.new(180, 180), LightEmission = 1, LightInfluence = 0,
                Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
            })
            em.spark = mkSpark(hrp)
        elseif style == 2 then
            em.flame = emitter(hrp, {
                Texture = TEX_FIRE, LockedToPart = false, EmissionDirection = Enum.NormalId.Top,
                Lifetime = NumberRange.new(0.7, 1.1), SpreadAngle = Vector2.new(18, 18), LightEmission = 1,
                LightInfluence = 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
                Acceleration = Vector3.new(0, 3, 0),
            })
            em.spark = mkSpark(hrp)
        elseif style == 3 then
            halo[1], halo[2] = mkHalo(), mkHalo()
            em.spark = mkSpark(hrp)
        else
            for i = 1, 6 do
                local part = new("Part", {
                    Name = "ScorpionOrb", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Anchored = true,
                    CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
                    Size = Vector3.new(0.5, 0.5, 0.5), CFrame = hrp.CFrame, Parent = workspace,
                })
                local a0 = new("Attachment", {Position = Vector3.new(0, 0.25, 0), Parent = part})
                local a1 = new("Attachment", {Position = Vector3.new(0, -0.25, 0), Parent = part})
                local tr = new("Trail", {
                    Attachment0 = a0, Attachment1 = a1, Lifetime = 0.55, LightEmission = 1, MinLength = 0,
                    FaceCamera = true, Transparency = NumberSequence.new({kp(0, 0.1), kp(1, 1)}),
                    WidthScale = NumberSequence.new({kp(0, 1), kp(1, 0)}), Parent = part,
                })
                objs[#objs + 1] = part
                orbs[i] = {part = part, trail = tr}
            end
        end
    end

    local function apply(c1, c2)
        local s, d, sp = cfg.auraSize / 100, cfg.auraDensity, cfg.auraSpeed / 100
        local cs = ColorSequence.new(c1, c2)
        if em.haze then
            local e = em.haze
            e.Rate = 4 + d * 0.35
            e.Speed = NumberRange.new(0.2 * sp, 0.7 * sp)
            e.Size = NumberSequence.new({kp(0, 2.2 * s), kp(1, 4.2 * s)})
            e.Transparency = NumberSequence.new({kp(0, 1), kp(0.25, 0.86), kp(1, 1)})
            e.Color = ColorSequence.new(c1)
        end
        if em.flame then
            local e = em.flame
            e.Rate = d * 1.3
            e.Speed = NumberRange.new(3 * sp, 5 * sp)
            e.Size = NumberSequence.new({kp(0, 1.9 * s), kp(0.5, 1.2 * s), kp(1, 0.2 * s)})
            e.Transparency = NumberSequence.new({kp(0, 0.25), kp(0.6, 0.5), kp(1, 1)})
            e.Color = cs
        end
        if em.spark then
            local e = em.spark
            e.Rate = (builtStyle == 1) and d or d * 0.5
            e.Speed = NumberRange.new(1 * sp, 4 * sp)
            e.Size = NumberSequence.new({kp(0, 0.55 * s), kp(1, 0)})
            e.Transparency = NumberSequence.new({kp(0, 0.1), kp(1, 1)})
            e.Color = cs
        end
        for _, o in ipairs(orbs) do
            o.part.Color = c1
            o.trail.Color = cs
        end
        for k, h in ipairs(halo) do
            for _, st in ipairs(h.strokes) do st.Color = (k == 1) and c1 or c2 end
        end
    end

    function updateAura(dt)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (cfg.auraEnabled and hrp and hum and hum.Health > 0) then
            if builtHrp then clear() end
            return
        end

        local style = cfg.auraStyle
        if builtHrp ~= hrp or builtStyle ~= style then
            build(hrp, style)
            lastSig = nil
        end
        phase += dt * cfg.auraSpeed / 100

        local c1, c2
        if cfg.auraRainbow then
            c1 = rainbowColor()
            c2 = Color3.fromHSV((os.clock() * 0.25 + 0.35) % 1, 0.85, 1)
        else
            c1 = (ColorPresets[cfg.auraColor] or ColorPresets[1])[2]
            c2 = (ColorPresets[cfg.auraColor2] or ColorPresets[1])[2]
        end
        local sig = table.concat({cfg.auraDensity, cfg.auraSize, cfg.auraSpeed, cfg.auraColor, cfg.auraColor2}, "|")
        if cfg.auraRainbow or sig ~= lastSig then
            lastSig = sig
            apply(c1, c2)
        end

        local s = cfg.auraSize / 100
        if style == 3 then
            local head = char:FindFirstChild("Head")
            local base = (head and head.Position or (hrp.Position + Vector3.new(0, 2.5, 0))) + Vector3.new(0, 1.7, 0)
            local h1, h2 = halo[1], halo[2]
            if h1 then
                local d1 = 3.4 * s
                h1.part.Size = Vector3.new(d1, 0.05, d1)
                h1.part.CFrame = CFrame.new(base) * CFrame.Angles(math.sin(phase * 1.3) * 0.08, phase * 2, 0)
            end
            if h2 then
                local d2 = 2.2 * s
                h2.part.Size = Vector3.new(d2, 0.05, d2)
                h2.part.CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, -phase * 3, 0)
            end
        elseif style == 4 then
            local r = 3.2 * s
            local n = #orbs
            for i, o in ipairs(orbs) do
                local ang = phase * 2.2 + (i - 1) * (math.pi * 2 / n)
                local y = math.sin(phase * 1.4 + i * 1.1) * 1.7
                o.part.CFrame = CFrame.new(hrp.Position + Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r))
            end
        end
    end
end

-- ---------- кольцо под игроком ----------
local updateRing, cleanupRing
do
    local ringRay = RaycastParams.new()
    ringRay.FilterType = Enum.RaycastFilterType.Exclude
    ringRay.IgnoreWater = true

    local ringPart, ringFrame, ringStroke, ringGrad, ring2Frame, ring2Stroke
    local phase = 0
    local R_ARC = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0),
        NumberSequenceKeypoint.new(0.46, 1), NumberSequenceKeypoint.new(1, 1),
    })

    local function destroyRing()
        if ringPart then ringPart:Destroy() end
        ringPart, ringFrame, ringStroke, ringGrad, ring2Frame, ring2Stroke = nil, nil, nil, nil, nil, nil
    end
    cleanupRing = destroyRing

    local function buildRing()
        destroyRing()
        ringPart = new("Part", {
            Name = "ScorpionRing", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
            CastShadow = false, Transparency = 1, Size = Vector3.new(7, 0.05, 7), Parent = workspace,
        })
        local gui = new("SurfaceGui", {
            Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
            CanvasSize = Vector2.new(256, 256), LightInfluence = 0, Adornee = ringPart, Parent = ringPart,
        })
        ringFrame = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui,
        })
        new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ringFrame})
        ringStroke = new("UIStroke", {Thickness = 14, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ringFrame})
        ringGrad = new("UIGradient", {Enabled = false, Transparency = R_ARC, Parent = ringStroke})

        ring2Frame = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
            BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = gui,
        })
        new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ring2Frame})
        ring2Stroke = new("UIStroke", {Thickness = 10, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring2Frame})
    end

    -- стили: 1 Static, 2 Pulse, 3 Ripple, 4 Spinning arc, 5 Double ring, 6 Disc
    function updateRing(dt)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (cfg.ringEnabled and hrp and hum and hum.Health > 0) then
            if ringPart then destroyRing() end
            return
        end
        if not ringPart or not ringPart.Parent then buildRing() end

        phase += dt * cfg.ringSpeed / 100
        local style = cfg.ringStyle

        -- высота земли под игроком
        ringRay.FilterDescendantsInstances = {char}
        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -60, 0), ringRay)
        local y
        if hit then
            y = hit.Position.Y + 0.06
        else
            local off = (hum.RigType == Enum.HumanoidRigType.R6) and 3 or (hum.HipHeight + hrp.Size.Y / 2)
            y = hrp.Position.Y - off + 0.06
        end

        local scale, alpha = 1, cfg.ringAlpha / 100
        if style == 2 then
            local k = (math.sin(phase * 3) + 1) / 2
            scale = 0.75 + 0.25 * k
            alpha = math.min(alpha + 0.4 * (1 - k), 1)
        elseif style == 3 then
            local k = (phase * 0.8) % 1
            scale = 0.25 + 0.9 * k
            alpha = alpha + (1 - alpha) * k
        end

        local d = 7 * cfg.ringSize / 100 * scale
        ringPart.Size = Vector3.new(d, 0.05, d)
        ringPart.CFrame = CFrame.new(hrp.Position.X, y, hrp.Position.Z)

        local color = cfg.ringRainbow and rainbowColor() or (ColorPresets[cfg.ringColor] or ColorPresets[1])[2]
        local thick = 14 * cfg.ringThick / 100

        ringStroke.Color = color
        ringStroke.Thickness = thick
        ringStroke.Transparency = alpha
        ringGrad.Enabled = style == 4
        if style == 4 then ringGrad.Rotation = (phase * 180) % 360 end

        ringFrame.BackgroundColor3 = color
        ringFrame.BackgroundTransparency = (style == 6) and math.min(alpha + 0.55, 0.95) or 1

        ring2Frame.Visible = style == 5
        if style == 5 then
            ring2Stroke.Color = color
            ring2Stroke.Thickness = thick * 0.7
            ring2Stroke.Transparency = alpha
        end
    end
end

function L.cleanupVisuals()
    if lightActive and lightOrig then
        for prop, v in pairs(lightOrig) do pcall(function() Lighting[prop] = v end) end
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm and atmOrig then
            atm.Density = atmOrig.Density
            atm.Haze = atmOrig.Haze
        end
    end
    lightActive = false
    pcall(function() ccEffect:Destroy() end)
    pcall(function() bloomEffect:Destroy() end)
    pcall(function() sunEffect:Destroy() end)
    -- погода, атмосфера, кольцо, аура
    cleanupRing()
    if weatherPart then
        weatherPart:Destroy()
        weatherPart, weatherEmitter = nil, nil
    end
    cleanupAura()
    cfg.atmEnabled, cfg.shiftEnabled = false, false
    pcall(function() updateAtmosphere(0) end)
    pcall(function() dofEffect:Destroy() end)
    for o, en in pairs(blurStore) do
        if o.Parent then o.Enabled = en end
        blurStore[o] = nil
    end
    pcall(function() HudGui:Destroy() end)
end

-- ============================================================
--  ГЛАВНЫЙ ЦИКЛ: FOV / зум / stretch / время суток / прицел
-- ============================================================
local RENDER_NAME = "ScorpionEngineOptimized"

RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 10, function(dt)
    -- время суток
    if cfg.customTimeEnabled then
        if cfg.autoCycle then
            cfg.timeOfDay = (cfg.timeOfDay + dt * cfg.cycleSpeed / 60) % 24
            if timeSlider then timeSlider.Set(cfg.timeOfDay, true) end
        end
        Lighting.ClockTime = cfg.timeOfDay
    end

    updateCrosshair(dt)
    L.updateModels(dt)
    L.updateLighting()
    L.updatePost()
    L.updateHud(dt)
    L.updateNoBlur(dt)
    L.updateRadar()
    L.updateWeather(dt)
    updateAtmosphere(dt)
    L.updateCinematic()
    updateAura(dt)
    updateRing(dt)
end)

-- FOV: применяется в самом конце кадра (после игровых скриптов) и не читает значение игры,
-- поэтому игра больше не перебивает его и картинка не дёргается
local RENDER_FOV = "ScorpionFovLast"
local lastStretched -- CFrame, который мы уже растянули (защита от накопления растяжения)
local fovConn
local fovApplying = false

local function hookFovCamera(cam)
    if fovConn then
        fovConn:Disconnect()
        fovConn = nil
    end
    if not cam then return end
    -- если игра меняет FOV посреди кадра, сразу возвращаем наше значение
    fovConn = cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
        if fovApplying or unloaded then return end
        if math.abs(cam.FieldOfView - fovCur) > 0.01 then
            fovApplying = true
            cam.FieldOfView = fovCur
            fovApplying = false
        end
    end)
end

hookFovCamera(workspace.CurrentCamera)
bind(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    hookFovCamera(workspace.CurrentCamera)
end)

RunService:BindToRenderStep(RENDER_FOV, Enum.RenderPriority.Last.Value, function(dt)
    local cam = workspace.CurrentCamera
    if not cam then return end

    local target = FCApi.active and (FCApi.fov or cfg.fov) or (zoomActive and cfg.zoomFov or cfg.fov)
    if math.abs(target - fovCur) < 0.05 then
        fovCur = target
    else
        fovCur = fovCur + (target - fovCur) * math.clamp(dt * 14, 0, 1)
    end

    if cam.FieldOfView ~= fovCur then
        fovApplying = true
        cam.FieldOfView = fovCur
        fovApplying = false
    end

    -- stretch: тоже в самом конце кадра, после любых игровых камер.
    -- Если камеру в этом кадре никто не менял, второй раз не растягиваем (иначе растяжение копится и ломается).
    if cfg.stretch then
        local cf = cam.CFrame
        if cf ~= lastStretched then
            cam.CFrame = CFrame.fromMatrix(
                cf.Position,
                cf.RightVector * (cfg.stretchX / 100),
                cf.UpVector * (cfg.stretchY / 100),
                -cf.LookVector
            )
            lastStretched = cam.CFrame
        end
    else
        lastStretched = nil
    end
end)

-- ESP считаем ПОСЛЕ stretch (приоритет выше), по финальной камере кадра
local RENDER_ESP = "ScorpionEspLast"
RunService:BindToRenderStep(RENDER_ESP, Enum.RenderPriority.Last.Value + 1, function()
    if unloaded then return end
    L.updateTargets()
end)

-- ============================================================
--  МЕНЮ: каркас
-- ============================================================
local ScreenGui = new("ScreenGui", {
    Name = "ScorpionSkeet_UI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Enabled = false, Parent = GuiParent,
})

local MainFrame = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(730, 510), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.06,
    BorderSizePixel = 0, ClipsDescendants = true, Parent = ScreenGui,
})
new("UICorner", {CornerRadius = UDim.new(0, 12), Parent = MainFrame})
new("UIGradient", {
    Rotation = 35,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 10, 12)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(9, 7, 8)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 5, 6)),
    }),
    Parent = MainFrame,
})
local mainStroke = stroke(MainFrame, 0.35, Accent)
table.insert(accentRenders, function() mainStroke.Color = Accent end)
local MainScale = new("UIScale", {Scale = cfg.uiScale / 100, Parent = MainFrame})

-- шапка (за неё таскаем окно)
local DragBar = new("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = MainFrame})
local logo = new("Frame", {
    Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(28, 32), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = DragBar,
})
local logoTxt = new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 30,
    Text = "S", TextColor3 = Accent, Parent = logo,
})
table.insert(accentRenders, function() logoTxt.TextColor3 = Accent end)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 6), Size = UDim2.fromOffset(130, 17),
    Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
    Text = '<font color="#FFFFFF">Scorpion</font><font color="#FF344C">.wtf</font>', TextColor3 = Theme.White, Parent = DragBar,
})
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 22), Size = UDim2.fromOffset(130, 14),
    Font = Theme.Font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "visual private", TextColor3 = Theme.TextDim, Parent = DragBar,
})
local TabPill = new("Frame", {
    Position = UDim2.fromOffset(156, 11), Size = UDim2.fromOffset(78, 22), BackgroundColor3 = Accent, BorderSizePixel = 0, Parent = DragBar,
})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = TabPill})
local TabPillLbl = new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 12,
    Text = "", TextColor3 = Color3.new(1, 1, 1), Parent = TabPill,
})
table.insert(accentRenders, function() TabPill.BackgroundColor3 = Accent end)
local hdrLine = new("Frame", {
    Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Line,
    BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = MainFrame,
})

-- футер
local Footer = new("Frame", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 22),
    BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = MainFrame,
})
local ftLine = line(Footer, UDim2.new(), UDim2.new(1, 0, 0, 1))
ftLine.BackgroundColor3 = Theme.Line
ftLine.BackgroundTransparency = 0.2
local ftL = makeText(Footer, menuKey.Name:upper() .. " — hide / show", 12, Theme.TextDim)
ftL.Position = UDim2.fromOffset(14, 0); ftL.Size = UDim2.new(0.5, 0, 1, 0)
local ftR = makeText(Footer, "scorpion.wtf", 12, Accent, Enum.TextXAlignment.Right)
ftR.Position = UDim2.new(0.5, 0, 0, 0); ftR.Size = UDim2.new(0.5, -14, 1, 0)
table.insert(accentRenders, function() ftR.TextColor3 = Accent end)

-- сайдбар (внутри ТОЛЬКО кнопки вкладок, иначе UIListLayout сдвигает их вниз)
local Sidebar = new("Frame", {
    Position = UDim2.fromOffset(0, 45), Size = UDim2.new(0, 132, 1, -67),
    BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.65, BorderSizePixel = 0, Parent = MainFrame,
})
new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Sidebar})
new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = Sidebar})
local sideLine = line(MainFrame, UDim2.fromOffset(132, 45), UDim2.new(0, 1, 1, -67))
sideLine.BackgroundColor3 = Theme.Line
sideLine.BackgroundTransparency = 0.2

local Content = new("Frame", {
    Position = UDim2.fromOffset(146, 54), Size = UDim2.new(1, -160, 1, -82), BackgroundTransparency = 1, Parent = MainFrame,
})

-- ============================================================
--  МЕНЮ: вкладки и группы
-- ============================================================
local Tabs, activeTab = {}, nil

local function SelectTab(tab)
    if activeTab == tab then return end
    if activeTab then
        activeTab.Page.Visible = false
        activeTab.Button.BackgroundTransparency = 1
        activeTab.Label.TextColor3 = Theme.TextDim
        activeTab.Dot.BackgroundColor3 = Theme.Off
        activeTab.Bar.Visible = false
    end
    activeTab = tab
    tab.Page.Visible = true
    tab.Button.BackgroundColor3 = Accent
    tab.Button.BackgroundTransparency = 0.86
    tab.Label.TextColor3 = Theme.White
    tab.Dot.BackgroundColor3 = Accent
    tab.Bar.Visible = true
    TabPillLbl.Text = tab.Name or ""
    TabPill.Size = UDim2.fromOffset(math.max(60, #(tab.Name or "") * 8 + 26), 22)
end

local function newColumn(page, xScale, xOffset)
    local col = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.White, ScrollBarImageTransparency = 0.6,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        Position = UDim2.new(xScale, xOffset, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), Parent = page,
    })
    new("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col})
    new("UIPadding", {
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 7), Parent = col,
    })
    return col
end

local function CreateTab(name)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Accent, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = #Tabs + 1, Parent = Sidebar,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 8), Parent = btn})
    local bar = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 3, 0.6, 0),
        BackgroundColor3 = Accent, BorderSizePixel = 0, Visible = false, Parent = btn,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = bar})
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = btn,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = dot})
    local lbl = makeText(btn, name, 14, Theme.TextDim)
    lbl.Position = UDim2.fromOffset(28, 0)
    lbl.Size = UDim2.new(1, -28, 1, 0)

    local page = new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = Content})
    local tab = {
        Name = name, Button = btn, Label = lbl, Bar = bar, Dot = dot, Page = page,
        Left = newColumn(page, 0, 0), Right = newColumn(page, 0.5, 6),
    }
    table.insert(Tabs, tab)
    table.insert(accentRenders, function()
        bar.BackgroundColor3 = Accent
        if activeTab == tab then
            btn.BackgroundColor3 = Accent
            dot.BackgroundColor3 = Accent
        end
    end)

    btn.MouseButton1Click:Connect(function() SelectTab(tab) end)
    btn.MouseEnter:Connect(function() if activeTab ~= tab then lbl.TextColor3 = Theme.Text end end)
    btn.MouseLeave:Connect(function() if activeTab ~= tab then lbl.TextColor3 = Theme.TextDim end end)
    if #Tabs == 1 then SelectTab(tab) end
    return tab
end

-- группа: заголовок внутри блока + тонкая линия
local function CreateGroup(column, title)
    local box = new("Frame", {
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.2, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = column,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 10), Parent = box})
    stroke(box, 0.45, Theme.Line)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = box,
    })
    new("UIListLayout", {Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box})

    local hdr = makeText(box, title, 14, Theme.White)
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 13
    hdr.Size = UDim2.new(1, 0, 0, 16)
    hdr.LayoutOrder = -2
    local div = line(box, UDim2.new(), UDim2.new(1, 0, 0, 1))
    div.BackgroundColor3 = Accent
    div.BackgroundTransparency = 0.6
    div.LayoutOrder = -1
    table.insert(accentRenders, function() div.BackgroundColor3 = Accent end)
    return box
end

-- ============================================================
--  МЕНЮ: контролы
-- ============================================================
local function CreateToggle(parent, text, default, callback)
    local state = default and true or false
    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Parent = parent})
    local lbl = makeText(row, text, 14, Theme.TextDim)
    lbl.Size = UDim2.new(1, -40, 1, 0)
    local pill = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(32, 16),
        BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = pill})
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.White, BorderSizePixel = 0, Parent = pill,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})
    local hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = row})

    local function render()
        pill.BackgroundColor3 = state and Accent or Theme.Off
        knob.Position = state and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        knob.BackgroundColor3 = state and Theme.White or Color3.fromRGB(170, 150, 155)
        lbl.TextColor3 = state and Theme.White or Theme.TextDim
    end
    hit.MouseButton1Click:Connect(function()
        state = not state
        render()
        if callback then callback(state) end
    end)
    table.insert(accentRenders, render)
    render()
    return {Frame = row, Set = function(v) state = v; render() end}
end

local function CreateSlider(parent, o)
    local step = o.Step or 1
    local fmt = o.Format or function(v) return tostring(v) end
    local value = o.Default

    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = parent})
    local lbl = makeText(row, o.Text, 14, Theme.TextDim)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    local valueLbl = makeText(row, "", 13, Theme.White, Enum.TextXAlignment.Right)
    valueLbl.Size = UDim2.new(1, 0, 0, 14)

    local bar = new("Frame", {
        Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 5),
        BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = bar})

    local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Accent, BorderSizePixel = 0, Parent = bar})
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fill})
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(11, 11),
        BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 3, Parent = bar,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})

    local marker
    if o.Track then
        bar.BackgroundColor3 = Theme.White
        bar.BackgroundTransparency = 0
        new("UIGradient", {Color = o.Track, Parent = bar})
        fill.Visible = false
        knob.Visible = false
        marker = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3, 12),
            BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 2, Parent = bar,
        })
        stroke(marker, 0.2, Theme.Black)
    end

    local function snap(v)
        v = math.clamp(v, o.Min, o.Max)
        v = math.floor((v - o.Min) / step + 0.5) * step + o.Min
        return math.clamp(v, o.Min, o.Max)
    end
    local function render()
        local a = (value - o.Min) / (o.Max - o.Min)
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        if marker then marker.Position = UDim2.new(a, 0, 0.5, 0) end
        valueLbl.Text = fmt(value)
    end
    local function set(v, silent)
        value = snap(v)
        render()
        if not silent and o.Callback then o.Callback(value) end
    end

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        set(o.Min + (o.Max - o.Min) * a)
    end

    -- кликабельная зона чуть выше самой полоски
    local hit = new("TextButton", {
        Position = UDim2.fromOffset(0, -6), Size = UDim2.new(1, 0, 1, 12),
        BackgroundTransparency = 1, Text = "", ZIndex = 4, Parent = bar,
    })
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(i.Position.X)
        end
    end)
    bind(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromX(i.Position.X)
        end
    end)
    bind(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    value = snap(value)
    render()
    table.insert(accentRenders, function() fill.BackgroundColor3 = Accent end)
    return {Frame = row, Set = set}
end

local function CreateDropdown(parent, o)
    local selected = math.clamp(o.Default or 1, 1, #o.Options)

    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
    })
    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row})

    local lbl = makeText(row, o.Text, 14, Theme.TextDim)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.LayoutOrder = 1

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.Off, BackgroundTransparency = 0.35,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = 2, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 7), Parent = head})
    stroke(head, 0.55, Theme.Line)
    local current = makeText(head, "", 13, Theme.White)
    current.Position = UDim2.fromOffset(8, 0)
    current.Size = UDim2.new(1, -26, 1, 0)
    local arrow = makeText(head, "+", 14, Theme.TextDim, Enum.TextXAlignment.Center)
    arrow.Position = UDim2.new(1, -20, 0, 0)
    arrow.Size = UDim2.fromOffset(16, 24)

    local list = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Black,
        BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, LayoutOrder = 3, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 7), Parent = list})
    stroke(list, 0.55, Theme.Line)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})

    local buttons = {}
    local function render()
        current.Text = o.Options[selected]
        for i, b in ipairs(buttons) do
            b.TextColor3 = (i == selected) and Accent or Theme.TextDim
        end
    end

    for i, name in ipairs(o.Options) do
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, AutoButtonColor = false, Text = name,
            Font = Theme.Font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = list,
        })
        new("UIPadding", {PaddingLeft = UDim.new(0, 8), Parent = b})
        buttons[i] = b
        b.MouseButton1Click:Connect(function()
            selected = i
            list.Visible = false
            arrow.Text = "+"
            render()
            if o.Callback then o.Callback(i, name) end
        end)
    end

    head.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        arrow.Text = list.Visible and "-" or "+"
    end)
    table.insert(accentRenders, render)
    render()
    return {Frame = row}
end

local function CreateButton(parent, text, callback)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Accent, BackgroundTransparency = 0.78,
        BorderSizePixel = 0, AutoButtonColor = false, Text = text, TextColor3 = Theme.White,
        Font = Theme.Font, TextSize = 14, Parent = parent,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 7), Parent = btn})
    local bs = stroke(btn, 0.4, Accent)
    table.insert(accentRenders, function() btn.BackgroundColor3 = Accent bs.Color = Accent end)
    btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.6 end)
    btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 0.78 end)
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

local function CreateKeybind(parent, text, default, onSet)
    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Parent = parent})
    local lbl = makeText(row, text, 14, Theme.TextDim)
    lbl.Size = UDim2.new(1, -70, 1, 0)

    local keyBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(66, 18),
        BackgroundColor3 = Theme.Off, BackgroundTransparency = 0.35, BorderSizePixel = 0, AutoButtonColor = false,
        Text = default and ("[" .. default.Name .. "]") or "[None]",
        TextColor3 = Theme.White, Font = Theme.Font, TextSize = 12, Parent = row,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 7), Parent = keyBtn})
    stroke(keyBtn, 0.55, Theme.Line)

    local listening = false
    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        Binding = true
        keyBtn.Text = "[...]"
    end)

    bind(UserInputService.InputBegan, function(i)
        if not listening or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        listening = false
        task.delay(0.1, function() Binding = false end)
        if i.KeyCode == Enum.KeyCode.Escape then
            keyBtn.Text = "[None]"
            onSet(nil)
        else
            keyBtn.Text = "[" .. i.KeyCode.Name .. "]"
            onSet(i.KeyCode)
        end
    end)
    return row
end

-- обёртки: контрол <-> cfg
local function CfgToggle(parent, text, key, extra)
    return CreateToggle(parent, text, cfg[key], function(v)
        cfg[key] = v
        if extra then extra(v) end
        Notify(text .. (v and "  on" or "  off"))
        QueueSave()
    end)
end

local function CfgSlider(parent, o, key)
    o.Default = cfg[key]
    local cb = o.Callback
    o.Callback = function(v)
        cfg[key] = v
        if cb then cb(v) end
        QueueSave()
    end
    return CreateSlider(parent, o)
end

local function CfgDropdown(parent, o, key)
    o.Default = cfg[key]
    local cb = o.Callback
    o.Callback = function(i, name)
        cfg[key] = i
        if cb then cb(i, name) end
        QueueSave()
    end
    return CreateDropdown(parent, o)
end

function L.fmtTime(v)
    local h = math.floor(v)
    local m = math.floor((v - h) * 60 + 0.5)
    if m == 60 then
        h += 1
        m = 0
    end
    return string.format("%02d:%02d", h, m)
end
local function fmtPct(v) return v .. "%" end
local function fmtDeg(v) return v .. "°" end

-- ============================================================
--  FREECAM (пружинная камера в стиле официальной Roblox Freecam)
--  W/A/S/D/E/Q — движение, Shift — медленно, стрелки вверх/вниз — скорость, колесо — FOV
-- ============================================================
do
(function()
    local CAS = game:GetService("ContextActionService")
    local StarterGui = game:GetService("StarterGui")
    local STEP = "ScorpionFreecam"
    local pi, exp, clamp, sqrt, tan, rad = math.pi, math.exp, math.clamp, math.sqrt, math.tan, math.rad

    -- пружина
    local Spring = {}
    Spring.__index = Spring
    function Spring.new(freq, pos)
        return setmetatable({f = freq, p = pos, v = pos * 0}, Spring)
    end
    function Spring:Update(dt, goal)
        local f = self.f * 2 * pi
        local offset = goal - self.p
        local decay = exp(-f * dt)
        local p1 = goal + (self.v * dt - offset * (f * dt + 1)) * decay
        local v1 = (f * dt * (offset * f - self.v) + self.v) * decay
        self.p, self.v = p1, v1
        return p1
    end
    function Spring:Reset(pos)
        self.p, self.v = pos, pos * 0
    end

    local velSpring = Spring.new(1.5, Vector3.new())
    local panSpring = Spring.new(1.0, Vector2.new())
    local fovSpring = Spring.new(4.0, 0)

    local on = false
    local camPos, camRot, camFov = Vector3.new(), Vector2.new(), 70
    local kb = {W = 0, A = 0, S = 0, D = 0, E = 0, Q = 0, Up = 0, Down = 0}
    local mouseDelta, wheel, navSpeed = Vector2.new(), 0, 1
    local saved = {}
    local coreGuis = {Backpack = true, Chat = true, Health = true, PlayerList = true}

    local function onKey(_, state, input)
        local n = input.KeyCode.Name
        if kb[n] ~= nil then kb[n] = state == Enum.UserInputState.Begin and 1 or 0 end
        return Enum.ContextActionResult.Sink
    end
    local function onMouse(_, _, input)
        mouseDelta = Vector2.new(-input.Delta.Y, -input.Delta.X)
        return Enum.ContextActionResult.Sink
    end
    local function onWheel(_, _, input)
        wheel = -input.Position.Z
        return Enum.ContextActionResult.Sink
    end

    if cfg.fcKey ~= "" then
        local ok, kc = pcall(function() return Enum.KeyCode[cfg.fcKey] end)
        if ok then FCApi.keyCode = kc end
    end

    local function step(dt)
        local cam = workspace.CurrentCamera
        if not cam or unloaded then return end

        navSpeed = clamp(navSpeed + dt * (kb.Up - kb.Down) * 0.75, 0.01, 4)
        local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        local velIn = Vector3.new(kb.D - kb.A, kb.E - kb.Q, kb.S - kb.W) * (navSpeed * (shift and 0.25 or 1))
        local panIn = mouseDelta * (pi / 64)
        mouseDelta = Vector2.new()
        local fovIn = wheel
        wheel = 0

        local vel = velSpring:Update(dt, velIn)
        local pan = panSpring:Update(dt, panIn)
        local fov = fovSpring:Update(dt, fovIn)

        local zoomFactor = sqrt(tan(rad(70 / 2)) / tan(rad(camFov / 2)))
        camFov = clamp(camFov + fov * 300 * (dt / zoomFactor), 1, 120)
        local gain = Vector2.new(0.75, 1) * 8 * (cfg.fcSens / 100)
        camRot = camRot + pan * gain * (dt / zoomFactor)
        camRot = Vector2.new(clamp(camRot.X, -rad(90), rad(90)), camRot.Y % (2 * pi))

        local cf = CFrame.new(camPos) * CFrame.fromOrientation(camRot.X, camRot.Y, 0)
            * CFrame.new(vel * (cfg.fcSpeed * (64 / 60)) * dt)
        camPos = cf.Position
        cam.CFrame = cf
        cam.Focus = cf * CFrame.new(0, 0, -40)
        FCApi.fov = camFov
    end

    local function enable()
        local cam = workspace.CurrentCamera
        if not cam or on then return end
        on = true

        for name in pairs(coreGuis) do
            pcall(function()
                coreGuis[name] = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType[name])
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], false)
            end)
        end
        saved.guis = {}
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g.Enabled then
                    saved.guis[#saved.guis + 1] = g
                    g.Enabled = false
                end
            end
        end
        saved.camType, saved.subject, saved.cf, saved.focus = cam.CameraType, cam.CameraSubject, cam.CFrame, cam.Focus
        saved.fov, saved.icon, saved.mouse = cam.FieldOfView, UserInputService.MouseIconEnabled, UserInputService.MouseBehavior

        camRot = Vector2.new(cam.CFrame:ToEulerAnglesYXZ())
        camPos = cam.CFrame.Position
        camFov = cfg.fov
        FCApi.fov = camFov
        navSpeed = 1
        mouseDelta, wheel = Vector2.new(), 0
        for k in pairs(kb) do kb[k] = 0 end
        velSpring:Reset(Vector3.new())
        panSpring:Reset(Vector2.new())
        fovSpring:Reset(0)

        cam.CameraType = Enum.CameraType.Custom
        cam.CameraSubject = nil
        UserInputService.MouseIconEnabled = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default

        FCApi.active = true
        RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value, step)
        CAS:BindActionAtPriority("ScorpionFcKeys", onKey, false, Enum.ContextActionPriority.High.Value,
            Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
            Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.Up, Enum.KeyCode.Down)
        CAS:BindActionAtPriority("ScorpionFcMouse", onMouse, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseMovement)
        CAS:BindActionAtPriority("ScorpionFcWheel", onWheel, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)
        Notify("freecam  on")
    end

    local function disable()
        if not on then return end
        on = false
        FCApi.active = false
        pcall(function() RunService:UnbindFromRenderStep(STEP) end)
        for _, n in ipairs({"ScorpionFcKeys", "ScorpionFcMouse", "ScorpionFcWheel"}) do
            pcall(function() CAS:UnbindAction(n) end)
        end
        for name, v in pairs(coreGuis) do
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], v) end)
        end
        for _, g in ipairs(saved.guis or {}) do
            if g.Parent then g.Enabled = true end
        end
        local function restore()
            local c = workspace.CurrentCamera
            if c then
                c.CameraType = saved.camType or Enum.CameraType.Custom
                if saved.subject and saved.subject.Parent then c.CameraSubject = saved.subject end
                if saved.cf then c.CFrame = saved.cf end
                if saved.focus then c.Focus = saved.focus end
            end
            UserInputService.MouseBehavior = saved.mouse or Enum.MouseBehavior.Default
            if saved.icon ~= nil then UserInputService.MouseIconEnabled = saved.icon end
        end
        restore()
        -- игра может перехватить камеру/мышь в ближайшие кадры
        task.spawn(function()
            for _ = 1, 4 do
                task.wait()
                if unloaded then return end
                restore()
            end
        end)
        if not unloaded then Notify("freecam  off") end
    end

    FCApi.off = disable
    function FCApi.setKey(k)
        FCApi.keyCode = k
        cfg.fcKey = k and k.Name or ""
    end

    -- бинд: нажать (вкл/выкл) или удерживать
    bind(UserInputService.InputBegan, function(i)
        if unloaded or Binding or UserInputService:GetFocusedTextBox() then return end
        if not FCApi.keyCode or i.KeyCode ~= FCApi.keyCode then return end
        if cfg.fcHold then
            enable()
        elseif on then
            disable()
        else
            enable()
        end
    end)
    bind(UserInputService.InputEnded, function(i)
        if cfg.fcHold and FCApi.keyCode and i.KeyCode == FCApi.keyCode then disable() end
    end)

end)()
end

-- ============================================================
--  VECTOR AIM (плавное наведение камеры на цель)
-- ============================================================
do
(function()
    local aimRay = RaycastParams.new()
    aimRay.FilterType = Enum.RaycastFilterType.Exclude
    aimRay.IgnoreWater = true

    local fovCircle = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, Parent = EspGui,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fovCircle})
    local fovStroke = new("UIStroke", {Thickness = 1.2, Color = Theme.White, Transparency = 0.35, Parent = fovCircle})

    local tHud = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(170, 40), BackgroundColor3 = Theme.Back,
        BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 4), Parent = tHud})
    stroke(tHud, 0.75)
    local tName = makeText(tHud, "", 13, Theme.White)
    tName.Position = UDim2.fromOffset(8, 3)
    tName.Size = UDim2.new(1, -16, 0, 15)
    local tSub = makeText(tHud, "", 12, Theme.TextDim)
    tSub.Position = UDim2.fromOffset(8, 18)
    tSub.Size = UDim2.new(1, -16, 0, 14)
    local tBack = new("Frame", {
        Position = UDim2.new(0, 8, 1, -7), Size = UDim2.new(1, -16, 0, 3), BackgroundColor3 = Theme.Black,
        BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = tHud,
    })
    local tFill = new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 255, 120), BorderSizePixel = 0, Parent = tBack,
    })

    local tMark = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1,
        BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = tMark})
    new("UIStroke", {Thickness = 2, Color = Color3.fromRGB(255, 60, 60), Parent = tMark})

    local target, targetPart, lockSince
    local cur -- наша собственная ориентация камеры (игра каждый кадр перезаписывает свою)
    -- 1 Always, 2 Hold right mouse, 3 Hold left mouse (пока стреляешь)
    local function active()
        local m = cfg.aimMode
        if m == 1 then return true end
        if m == 3 then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    local function pickPart(char, cam, center)
        local head = char:FindFirstChild("Head")
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
        local mode = cfg.aimPart
        if mode == 1 then return head or torso end
        if mode == 2 then return torso or head end
        local best, bd
        for _, part in ipairs({head, torso}) do
            if part then
                local sp = cam:WorldToViewportPoint(part.Position)
                if sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if not bd or d < bd then best, bd = part, d end
                end
            end
        end
        return best or head or torso
    end

    local function visible(cam, char, part)
        local ignore = {cam}
        if player.Character then ignore[2] = player.Character end
        aimRay.FilterDescendantsInstances = ignore
        local origin = cam.CFrame.Position
        local res = workspace:Raycast(origin, part.Position - origin, aimRay)
        return res == nil or res.Instance:IsDescendantOf(char)
    end

    local function pickTarget(cam, center)
        local bestPlr, bestPart, bd = nil, nil, math.huge
        local camPos = cam.CFrame.Position
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local part = pickPart(char, cam, center)
                    if part then
                        local sp = cam:WorldToViewportPoint(part.Position)
                        if sp.Z > 0 then
                            local d2 = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            local dist = (part.Position - camPos).Magnitude
                            if d2 <= cfg.aimFov and dist <= cfg.aimDist and (cfg.aimWalls or visible(cam, char, part)) then
                                local score = (cfg.aimPriority == 2) and dist or d2
                                if score < bd then bestPlr, bestPart, bd = plr, part, score end
                            end
                        end
                    end
                end
            end
        end
        return bestPlr, bestPart
    end

    local function stillValid(cam, center)
        local char = target and target.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (hum and hum.Health > 0 and targetPart and targetPart.Parent) then return false end
        local sp = cam:WorldToViewportPoint(targetPart.Position)
        if sp.Z <= 0 then return false end
        if (Vector2.new(sp.X, sp.Y) - center).Magnitude > cfg.aimFov * 1.3 then return false end
        if not cfg.aimWalls and not visible(cam, char, targetPart) then return false end
        return true
    end

    local STEP = "ScorpionAim"
    local pickTimer = 0
    local lagTarget, lagPos
    RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 20, function(dt)
        local cam = workspace.CurrentCamera
        if not cam or unloaded then return end
        L.aimEngaged = false
        local vp = cam.ViewportSize
        local center = Vector2.new(vp.X / 2, vp.Y / 2)

        fovCircle.Visible = cfg.aimEnabled and cfg.aimShowFov
        if fovCircle.Visible then
            local d = cfg.aimFov * 2
            fovCircle.Size = UDim2.fromOffset(d, d)
            fovCircle.Position = UDim2.fromOffset(center.X, center.Y)
            fovStroke.Color = (ColorPresets[cfg.aimFovColor] or ColorPresets[1])[2]
        end

        local on = cfg.aimEnabled and not FCApi.active and not MainFrame.Visible and active()
        if not on then
            target, targetPart, lockSince = nil, nil, nil
            tHud.Visible = false
            tMark.Visible = false
            if cur then
                -- плавно отдаём камеру игре, чтобы не было рывка
                local gameRot = cam.CFrame - cam.CFrame.Position
                local rot = (cur - cur.Position):Lerp(gameRot, 0.3)
                cur = CFrame.new(cam.CFrame.Position) * rot
                if (rot.LookVector - gameRot.LookVector).Magnitude < 0.01 then cur = nil else cam.CFrame = cur end
            end
            return
        end

        -- выбор цели раз в несколько кадров (рейкасты дорогие), залипание — пока цель валидна
        pickTimer -= dt
        if not (cfg.aimSticky and stillValid(cam, center)) then
            if pickTimer <= 0 then
                pickTimer = 0.05
                local newTarget, newPart = pickTarget(cam, center)
                if newTarget ~= target then lockSince = os.clock() end
                target, targetPart = newTarget, newPart
            end
        end
        if not target or not targetPart or not targetPart.Parent then
            target, targetPart, lockSince = nil, nil, nil
            tHud.Visible = false
            tMark.Visible = false
            return
        end

        local pos = targetPart.Position
        if cfg.aimPredict > 0 then
            pos = pos + targetPart.AssemblyLinearVelocity * (cfg.aimPredict / 1000)
        end
        local camPos = cam.CFrame.Position
        -- задержка при движении: точка прицеливания догоняет цель с отставанием
        if cfg.aimLag > 0 then
            if lagTarget ~= targetPart or not lagPos then
                lagTarget, lagPos = targetPart, pos
            else
                local a = 1 - math.exp(-dt / (cfg.aimLag / 1000))
                lagPos = lagPos:Lerp(pos, a)
            end
            pos = lagPos
        else
            lagTarget, lagPos = nil, nil
        end

        -- «человечность»: лёгкое дрожание точки прицеливания и задержка захвата цели
        if cfg.aimHumanize > 0 then
            local t = os.clock()
            local k = cfg.aimHumanize / 100 * 0.35
            pos = pos + Vector3.new(math.sin(t * 7.3), math.sin(t * 5.1 + 1), math.sin(t * 6.2 + 2)) * k
        end
        local delayed = lockSince and (os.clock() - lockSince) * 1000 < cfg.aimDelay

        local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        tHud.Visible = cfg.aimTargetHud and hum ~= nil
        if tHud.Visible then
            tHud.Position = UDim2.fromOffset(center.X, center.Y + math.min(cfg.aimFov, 200) + 16)
            tName.Text = target.DisplayName
            tSub.Text = string.format("%d hp  |  %d studs", math.floor(hum.Health), math.floor((pos - camPos).Magnitude))
            tFill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1)
        end
        local mp = cam:WorldToViewportPoint(targetPart.Position)
        tMark.Visible = mp.Z > 0
        tMark.Position = UDim2.fromOffset(mp.X, mp.Y)
        if delayed then return end

        local smooth = cfg.aimSmooth / 100
        local alpha = (smooth <= 0.01) and 1 or (1 - math.exp(-dt * (40 * (1 - smooth) + 3)))
        -- копим собственную ориентацию (а не тянем кадр игры), поэтому камера реально прилипает к цели
        L.aimEngaged = true
        if not cur then cur = cam.CFrame end
        local desired = CFrame.lookAt(camPos, pos)
        local rot = (cur - cur.Position):Lerp(desired - desired.Position, alpha)
        cur = CFrame.new(camPos) * rot
        cam.CFrame = cur
    end)

    function L.aimCleanup()
        pcall(function() RunService:UnbindFromRenderStep(STEP) end)
        fovCircle:Destroy()
        tHud:Destroy()
        tMark:Destroy()
    end
end)()
end

-- ============================================================
--  СКАЙБОКСЫ (картинки зашиты в скрипт, пишутся в workspace экзекьютора при первом применении)
-- ============================================================
do
(function()
local SKY_DATA = {
    Sakura = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc00011080200020003012200021101031101ffc4001b00000203010101000000000000000000000003020405060107ffc4003810000104020005030204040603010101000100020311041205132131611441512271063281914252a1b11523c1d1e1f03362f1162472ffc4001a010100030101010000000000000000000000010203040506ffc4002711000202020202020301010003000000000001021103122131041322411432514261235281ffda000c03010002110311003f00dad51aa9d2297dbd9d3443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b1443546aa748a4b144f546a9948a54b2f42f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a9948a4b142f546a995e51496285ea8d53291496285ea8d53291496285ea8d53291496285ea8d53291faa58a17a84505a7c3b87fab7991f7ca67b7f315a93f0a8670c1d59af41afc2e79f9118cb566d1c3292b4731411aaea25e170cb008f5a2d14d70ee173d2c4f82574720a2d34a71e68e4e1113c5287623546a9948a5bd9950bd51aa652292c50bd51aa652292c513a452652f7554b34a1548a4dd51aa58a1548a4dd51a84b142a9149baa354b142a9149baaf354b142e914994bdd52c50aa45266abdd52c50aa4526ea11aa58a1548a4ca4529b142e9149948a4b142e9149948a4b142e9149948a4b142e91499aa29458a1748a4ca4529b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e95ee1bc39f9d9036638c0d34e7348146ba2ab4ba3fc33cb0c9c3a568739c00613d4d0eeb9bc9c8e18dca26d860a53499659c170e385f1362fcfddc7abbf758bc63857a47327c7888875a7fbd1f9fd57791be26e2c913a10e7bbb3be160fe20219c2dedf51ca73ba6a059907c2f1fc6f2723c94ff00a77e5c31d1f15471748a4ca452fa0b3caa1748a4ca46a96285d2293291496285d2e9b8570ac5f4ccc825b3bde2efb86f80161e263b727361c773cb1b23b52e1ecbb6c1e1f1e0e28818e2eeb65c7dcaf3bcdcdaa514f93b3c5c5b3d9ae0808001400011c9f0aee9e16b60706193089a5739ad71e8074e9f2bc8f61df3d71ab91ce727c28bf1592375918d7b4fb385ad8cdc07e1cfcb751045b4f855b4f08b27da2ca3192b5d1c3f17c3c6c4ca0dc77f522dd1f7d566d2eb78e70ac7304fc40bdec91ad1d07671ec172d4bdef172ac98d73d1e4e7c7a4fa1748a4ca5eeabaacc285522937546a9628d0cee1993c3e40d9da0b1df9646f507c7855345d1711e31167e09c76e339ae241b711d2be16196d2e4c339ca3ff00915337c918a97c3a15a2f354d452decce856968d13a944a58a145a8a4c21794a450ba5eea98005eea96284eabd0d4ca4258a21a2f744c08516285162f744ca5a3c2387338865b9b2b888a31b380eeef0a939a845c9968c1c9d2320b45f751d577b370ee130e1bccb8d132268eaeaebfbf7b5c4960f61d3d96787c8596f8aa2f931695cd88d51aa66aa402e9b32a15aa354d2d5e5258a17aaf7553d6d7a1aa2c50bd5785a9faaf0b52c509d51aa616af294d8a17aa354cd51496285ea8d53291496289e2614f9b9020800bf771ecd1e55de29c165e190c531984ad79d5d4dad4adefc398cd8f867388fae57924f81d07faa57e289da3161c51f99eedcfd87ff00579cfc994b32847a3a5614a0e52392d51aa652297a367350bd51aa652bdc33863f89649603ac4ceb23877fb0f2ab39a82da5d1318b93a4676be51a15dae4f02e1ede1f2b628031ed692d7d9b04795c8d7d2b0c3e4472dd1a64c4f1f657d7ca354e2d5e6aba6cca856a9f899126165372226b1cf6fb3c5a8eabdd156494953255a768da6fe2698e348d7e3813ff000399f97f5056567674fc4276cb306b7568686b7b79fea925b48d5630c18f1bda28d25967355262b546be534b579aae8b32a21aaf43530354b551628452f4353b451d692c51168746f6c8c76ae69b07e0aedf86670cfc41256b237a3c79f0b8ba5d2fe1a95be9a786fea6bf6af047fc2f3fce8278f6fb47678b26a75fd37696b6071518d008666b9cd69e8475e9f0b290bc3ab3d19e38e45522c66e53",
            "b332398e01a07468af6f3e556a5eaf2c5d5f544ab82d18a8aa472ff88b3cc927a06021ac36f27dcfb05cf6ab538c3db37189dcc36d0436fec295311f85f49e3c5431a48f17349ca6db101aa4189fca46842decca846ab4f877039f886319db3b236ec5a01164d2a9a2bbc3b884dc3e43ab799138db9975fa858e57371f83e4b46afe4543d1449b5320951a5a16a205014a914a48a0ee3a20b0816a43a2f49b0a09a1242f293084529b2285d2929522905105e526522905105e852a5eea8288a6472490c8248a4746f1d2da694682f436d43a7d93439f2cf90419e67c95d838f4094e6a981414ba52a2a5d1057d144b53cf751215ec509a4529d2294d8a3c68169a1a08e8bc0c531f4aab628816d2881698e3651549628539a9749e4da810ac98a1748a4cd4a35296285d2bfc270199f9e2396f94c697380357ec02a94aff00069c637168dcf34d901613f17dbfaacb3397adebd97c696cace89d8d93c3f08c7c2a212fd561923bf2f90b9acdc0e2ae99f9197039ee7772d21d5fb7b2eeda46bde9569f271b1c174d332303f99c02f1b0791283bab67765c5b2a4cf9e8162d14ade6490cf9d34d8ecd2273ac0aafd52355eec65693679ed53a174bb4e030361e11139a05c96f71f9ffa171faad5c2e2f938589e9dac63dadbd4bafa2e5f2a12c914a26b8a4a0db66df1bcd6e370e7c6d3fe6ca3468fee7f65c6f60ad644f2e4cc6699db3cfec3c048215f06258e34525272ec5af694f55e86ae8b2944297a027b58148c602aec28ac5abc0d4f23d940b54d8a165abcd293dad1eea7408ec9628ae029e9d1488a5e5951628f35472d7a0af7623a258a2058bc8e49a07b9d0c8e8cb9a5a48f705301503d4a77c324d9e09c4a0c6c77c3953381dada0824557cabb91c7f163e9031d39f0351fd5734d349b4085c92f171ca7b33759e718ea8e8e3e3b80f65bdcf8cfc39a7fd12f04e2710e2f365895e5cc0046d77d342baac16c649ec9ec88b487025a47b859fe2c229eafb25f91275674197c17874913dfca10b8027769aa5cc08e82b8f9269581b24f23da3d9ce2425d001698612c69a93b32c9252e95082da502d5668151e592ba2cce8af4bc2d4e7444754b3615ac51373435248eaad3c071b4b733a284cbd08a452616af083ec2cab58a2148a57f2785e66244259636967b969bd7eea9eaab19a9ab8b25c5ae190a4529ea8d55ac8a2148a53d51aa58a2148a53d51aa58a2148a53d51aa58a214bd1d13a2c79a776b0c4e90ffea140b1cc7963da58e69a208a2146cae89a01d7ba082bda5e8082886abdd5398db3d930c06acaaec414cb5469597c7412b5564c5111d02f0953d51aa926880525eea8d50511a406da635b6a7a528b228f1b1023aa8b98026d3bba8b8daad8a2b90bcd53b5b469d15ac51a589c7a7c784453c4270d14d76d47f55953c8ec8c892792b67b89fb296abcd5671c5083728aecbb949aa62e91499aa355a94a174bd52d51aa0a22bca53d51aa0a3c14852d51aa13479b1054c1b1d54754528228950503d57b48a4268f1ad24a78650b5069a4d692e354aac8a165b7ec92e1455ee53abb24491106e9131422ba2002e706b4593d004c2d207416574b1707c46c3035cc25f1f5241ad8fbdacb36758aafecd71e273e8e6e5c4ca806d3e3be36fc91d12687caef0b43810e0083dc1f74a762c0622c104755d0168a5c51f3dffa4743f17f8ce2991971e81586c25a7aad0f412e36ae95ad1b123a1537441c282ee595495a38da7174ca428760bc738914159e400a3a37b1eca2c8a341bc05da0bcafafde9bd2ff759d97893e1ca1928043bb38762af419d958f18600d9983a0d8d11faa4e665cd97a36563636b0dd0376573637954aa5ca3597adab899e5aef652da827fd3aaaee02d75dd99511decd21d158b0a6d6b54cb9ad149628f1b0bcc65e237b98059706f4487104d05da9c78e488c6f682c228b474e8b372780e33e20207189c2cd9eb7f75c38fcd8b7f23b2581ae8e629147a11dc754d9227452be27905cc25a48ecbca5e8269a39e8e922e218799c3de25918c76843dae354b9603a260617db9b1b9c1bdc817480011d1638b1ac774cbca5b7642bc22bc2652296f65285d7845784ca45258a175e115e13291496285d78528e274d3470b7a39ee0d054a94a194c1911ccca2e63ac03eeab26e9d048ebb1b1e1c4c76c310fa47b9f7f2b93cf91b3f12c89586da5d408f7a14ae65f16c9ca61898c6c3191468d93faaced682e4f1f14a2dce7d9acdc6b5890af0a5aa9814a5d085d96634791bc33ad293a7252c84528e051e975a81014a914a450b2115e13291aa9b2685d2935b654a97a1bd52c8a00cd57b56532ba2f3a5aa58a240b436a921cdb3d158e5f4b5e340d87444c50911943850a5724680cb0aa9ee8a56284d2f4354c80bda56b2684908af098e007734bc001eca6c510af08af09948a4b142ebc22bc2652292c50baf08af0994ace1f0fc8cd24c603231fc6eec7edf2ab29a8ab90516fa295296a16a64f059f1e074a246c81a2dc2a8acda511c9197eac51e69d2d4754c057847556b228886f556236002d280ea9a0f4e8a1b145e88c754e4bc88db5615425c3aad5c0c16e4c0269e5d81ecd61edf7f2b9f24d635b32d1c6e4e90be19c3c4cf33cccb89a7e907f88adea5e46c6c6c6b1a2834500a6bc8cb95e495b3d2c78d41517b1b85cb938dce6c8d683d877541cd731ee6385169a215e8389e4e3c1c96eae68e82fd951249249364f525611bbe4887b367b75f467f13711147f4f4dba9f8541843bb15a19f2c6f85f8d64c8402001e566b207b0d85eaf",
            "8dfa5338bc84b7ec639963baaee85d6adb58e27aa9966bdd746d473940b8c63aa4bdfbf456a689d21b0abba1737aad13458486926827722fba231abadc9ce78229aa5b0562d03a5a81683ee15ac7c39f2240f6b1ae8daf01d6696f0c3c634d18f1f8fa42e7c9e4c71baecda185cd59a6d85e59b81d2ad25efe9ad01e559393fe498c3689156a9bcf55e31dd0b7fb18f97c222741b416266d9b27f3782b0bf8495d92c2cde193892496201ec712751dc2f47c7ced7c66cc72e2fb8a3670b1d906044c600006826bdc9ee563f18c1642e1950b435ae34f03e7e56be04e26e1f19e9b06eaef042871301dc32707f96ffaaca3370cb6bffa428b707b1cb5229300e88af0bd6b3945d22932bc22bc259342e914995e115e12c50ec0c26e64ce0f786b1944b7ddcba06e1e3b5c5ecc76586ea486f61f0b3b83ba30648f4024efb7c8f85d1439622c492030b5fb7671f65e379793229523af1aa85a5672fc4787418d08931d926c4f503a803cfc2cca5d2f12716f0f97520134d3faae780a0bbfc69ca50f919668a52e05d2f4053af08af0baacc28852f2932bc22bc258a1748a4caf08af096285d22932bc22bc258a174bd0a75e1149628d2e1dc363cac633cee7fd4486869aa012333873f0dc1c1c5f09341c7b83f055fe0b3b794fc627ea69d8790b572236cd8724640ea0f75e77b671cad37c1bca31d1348e598d7114bde5169b213e02dd012bd9a40e3402ecdb939ca8fb3d1208eaadbda48ba492da574c9a154ace261cd965e58435ac1dcfb9f8492282dfe14c0de1ec2055927faac73e5708da35c505295311c3706489d23b262675a001a253f2785e34ec3ac6237d7473057ee3dd5e5ed2f2de69396d7c9dab1c5475315bc09847d792fbff00d400167e6627a39c47cde6022fa8a21752913e163e4bdaf999b16f6a34b6c7e4c94ae4f8339e155f14729d3eff0064021dd882ba9c6c38f14c9cb269e6e8fb28e4f0ec6c920b9bab87f133a12ba7f315f5c197e3ba399a5a389c5a4c581b03a00f6b7b10ea2ad64f0bc48b1a49582405a09e8ebfeeb1c107a03656aa50ceb9337196365bcbe279396ce58688633dc0364feaa8d2657845785ac23182a8946dbe58ba4526578457857b2285d2937ba957845784b22899d2dbb746d8dbecba3c5c68b161e5c57a93764ddae648b14b7f853dcec06ece268968bf601707969ea9d9d382ae8d8c1c619596d89ce21bdcd7729dc470998723396eb0ebe84f55458f7c6f0f638b5c3dc29cd3cd3b83a690bc8ed7ecbcb69ed67438cf7524f816aa6467478f2f2b573dc3bebec9994f747892bd8e2c7069208f62b1f1e1269cf364f524aebc3894edc8a66c8e1c22c7a812cfcc73037a550eea6e703d47641c4b16d4b731cce8576a492a479edeced9212027ba913b0e894c89ce72b2d88b0296d10d0a0d3ad1092f05a0fd2af861f71d137d2191bf510c1f6b2a8f2a8f64c62e4e91cf4964f652898558ca8b9590f8af6d7de955738b07c2e852d95a2d5f46e60335c7240e85d615f8dbeeb2f856589a1e408c83137abaec1eab51ae00515e3e5bddd9e8e3fd150c8639a725b147b50b27e023270f231bacac0076b06c05abc09ecd24675deecfda95ae2cf8bfc39e1cefcc016d0e8e37d1637c9cf2f224b2fad2e0e610842b9da644d98cc5ce2fc5a91aff00fc8cec2fe6fe52f3788bb2a110c7116309b7171ea7c28e6630c695b4fdb724815d82afaaf4b1c20d291c32724da1748a4cd51aae8b33a1748a4cd51aa58a1748a4cd51aa58a16ddd8f0f8de58e1ee0abade2794d8d8d0d692deee7592e55b546aa928c65fb22536ba6793cafc998cb2002c01409ae8a1499aa35565495221f3cb1748a4cd51aa9b142e91499aa354b142e91499aa354b142e91499aa354b142e91499aaf43494b1441bb35c1ec716b9bd410ae3f89e5be07445ac05c2b71dff648d2940b552518cb96894dae8223ad0f65a58f8c321d40ea0772b3da28dab38f96ec59b6d768ddd1c077fbaae4dabe3d9092be4be7856c29939baf70b2b2f0f2315dfe6b4169341edecba08726195a1f1c80f8bea3f45e664b09c67b67734348aa3dcae4866945d335963e6e3d189c3f15991339f20b6c75d3e4add1d96570cc695a39c647061ecc07a3bc95acb2f225b4fb3a30aa880049000b256bb3823cc3b3e52d7d13aebd8fc2c8ea3a8e856eb38dc231c6d1b8bc74d47f7b5caca790f2aaf5986f63a391cc78a734d10bc5396432ccf95dddc6fe541591d0aeb92257a4100120807b585630f97eb61e6805bb7b9a1e16f711e41e1cfd8820b761d7a935d0f950e54e8e7c99b49a8d76731dd64f16898d8e02c68690e2280ae94b5950e290ef8dcd1771f5af0ba713a9a669915c598b480d71706b5bb38f4007ba652761bd90e74524869a2fafc745ea4a549b470a4266c69f19ed6cec0361628da5d2bd9f9232f243997a305027dd55d54424dc6e5d8695f04e0c2c8c98dd244d6d34d753565228d905b447420fb2d5e1996c877c79486871b693dad56cfd1dc42431904102c8f959c724b77165b55ad94e93239f22089cc864d438eddba846a8d56aea4a9955c746bb388e3360697cc1cfa174d3d4af63e278923412f319f87036b1f5526b7af50b97f1a3fd36f748d0e6cb33240e7dc6e3d3a7b7c2439fa9e9d004198359a851c66fa8cb646eead1d5cb4494136614e6f92cc394ed9b1b06ce71a00af26748240268cb01f7f63faad210442512e8ddc0aba53735ae14e008f82b93f239b48dd78cabb33d9344d1dc5a5bf2b53f215bcac78dd8efd616b9c07d22abaaca01d190d9d8",
            "586afaadf1cd4cc6789c0b3ebac501d41b57999f24b16a236c77dcddacb18d2bc19238e9a05dbba5a847248f7b58c16e77616acd425cff000aeb24a91a13620d7706efadacd65373a1d874dc2b832de018a405ae1dc1552601c360688ea15d729a2229a7c9bac6b58da634347c014a40a5c2e73e063dedd5c4590a6bcb6bfa7a899eb5ce63839ae2d70ec41a5ebdef90dbdee71f926d794115d540afb24237966f5f4fca9c6d8c1064048f85273c86007b0ec163e76449cc6c31cae6802dda9568c5c9d2292952b62f8a885d98d31f47014e17d87b2a54a61b5f73eebda5e8c16b1a395f2ec5d22932914af6450ba452652292c50ba452652292c50ba452652292c50ba452652292c50ba452652292c50ba452652292c50ba452652292c50ba46a9948a4b142f55268a52a452591405a5c140b530123b2f0f5516288b5bd5588b1c48eab49a4c63dcc3611b21a193e2860ea02a2e8c5920755a9b199bd5559630db36aa9ff004889a185931ccce5b185858002d3f0adff0065570a16458e1cd690e78b37dd5a5e6ceb6747a30bae40774c0014b5eb5dadf4b5425a1d1c71b9d4ee95e7baf26898c3f43afc7c286e145cfbec3a292893bb22505ce7001ce26bb595196464513a471fa47c775112c66212ec0308bb3d14a4e8b5a26b333b2660f931c31a18e1567b95ebf88c85cee544d2df62e555ef9657074afd88ec3d87d97563c6eee48c2734d52121bd17baa652297659850bd5149948a4b1428b41ee101a07609b48a4b142e9149948a4b142f55eea98c8e495c1ac6bab600b80ba568f0c782359fa7bdb5672cb18ba6cb2837d19ef043495b585145163379443afa970fe22b3e5c4999218dad74a281d83696ae344d8206b180b7dfaf7b5cf9e69c55335c5169f287b18e9246b1b56e342cab39585e9683a605fa8716d577f8555ae731e1ec25ae1d88529257c8e2e7b8b9c7b925717d9b352d953e05f755a4c66cb94d92416183a0f92ad20857526ba25a4fb3c4a8f1a089e5f1c61ae3ee9d484b62915b2b1db3c47a7d6d1f4958ae3d3a9e97d5742abcb818f3024c7ab8fbb7a2df165d55332c98edda2c802ba2f1500ecb872191b9db8e8050e842d1594951a465664c7959113cb9ce32b4f707a57d95c6e763b8757969f8702a910bcd574cb1c59829b44592cc2532b5e4937f98f42a34492e7125c7a927dd32821ad7bef971b9f5de82d385c941748a53f72d20870ee0f42bda56d88a1748a4ca45259342e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948a4b142e9149948d52c510a4529ea8a4b140d7168a0bd04095ae7b76683647caf294da431cd79687341ea0fb8556f82b54cd36b83d81c3b117d559c4c7f5394c86c807b902fa2acc7b24682c7070f0991c8f89e1ec76ae1eebce77f476bb71f89a7c4385b31b1f9d193d2ac5d8ff00b6b295ac9ce9f29a1b26b40df40aaaaa4ca625351a9be41787b2a7973bdae8db0bc0b04923aaaaf7cf20a7cc6be0745d11c6dab0e693a12e8aa578710e75f52d360a39628024903b027a04c0d00505ed2ec4738bd5149948a536285d2293291496285d2293291496285d2293291496285d208a165329785b6084b228bd8313a3c7b757d6765ab1e04f2e23b25b5a0eb47b959789203086ba5d9e3b83dc2bcc9e6646626485ad3dc05e665d9be0e9a7aad45ff6421086a085afc3b864791073e6b21d61a2fa0af9f94ae27c3d98bacb0d88c9d752ebae9ffd5060b3c1cfd7f666a1017aa4dc6438f3643f5899b7604fb0b52c8c3c8c53fe74743b6c3a8fdd6df05747e99f1877d61c496ffaa771731ff87bc3c904fe51ec4a8bfb381f9325974ae0e5d0842b1de6465c921ca735cf2d0dead03a7ea86e464b4573efee0157735cd18e5a7bbfa05440a5d98ea51e51cb3b4fb19aaf1c287656fd190c2798e73eba7b052831ba092516ef61f0a9ed5565b4774446145cb0083b7727e56863b6320c6ee9f1d52d39f89931c5cd7c2e0cf9aedf7f85cce57db356a2b8e8ad9588d9811d376fe572cb0091d4755b3bbbfe859f3c4c64cdd051209216b8e55c14947ecad5e15bc7e1e258048e739d7d7e93d0256a5498f9e2be4c85b7dc7b15acadae0ce88cf88f806ed76ecf7bee12a93df2644add2470d7dc0156a3a948b75c8697d0ad51af84dd4a352ad62856a8d537528d4a58a15aa354dd4a352962856a8d537528d4a58a15aa354dd4a352962856a8d537528d4a58a15aa354dd4a352962856a8d537528d4a58a154bdd53a289d34ba076a00b2512c3240f01c4398eece0a37574284ebe17949daaf3571706b45b9c6829b22856a8a565d8990d16035de014a1d4914411dc150a49f44d1180b61c80e3d1ae144abfcc8f99cbd86ff0a99658a2178185ae0e67470ec695251d9d978cb5e0bee7358d2e71000f72ab4d910189cde65ec2a9bd4a4b9af91c0c8e2eaec3d97a19e15563fe92e6caec8c068fa68a9ea9da95e6a56d66742b546a9ba946a52c50ad51aa6ea57a1a96284ea8d53f965785a5362284ea8d537528d4a59342a9149ba95e86a59142753f08d53cb7c28ea52c5082cbeb5447629e3272057e5343f7f2822bb946a543a7d92ad745a8653347b1147b109a91882a270f70e2acd2e57d9d317c1a1c3f890c4672a48cb9b7763bd7c25e7e71cc2d6b59ab1a6ec8ea7e153a452a52335860a7bd727817bdbaaf515d10d494534b0bf789ee63be41a5e4934b2d731ee7d74167b28a14f046aaecf1449a6935d85a9a84a7",
            "589c4fc2924cd7b9d349cc776fe11f0179aa632390b4064648f9f65210cee7ea63d3c9ecbab64b83969be4d2a452bf99c3a5c36b5ce70735df03b2a74b92ecda3914d5c488fa5c0d0346e96be4f158a5c130b63a7b8551ec165004fb5a29438d959c23369cbe8852a9334fa8fbb55d7586120d1af755cb1c4eee366a9691eec99cb8a11a2351f215c8f15a29d2fd4ef83d82bcd870b94018db75db5eaafb9937463688d15a7c2d8e4a613a9f63ecbce5ab6c495b4468acf2d1cb4d815b4468acf2d1cb4d815b4468acf2d1cb4d815b4468acf2d44b09706b6acfb9f64d808d11a2b02071076241be84289648deecdabdc28dd134c4e88d1580d045af796a7620ada234567968e5a6c0ada234567968e5a6c05e28027783dcb55bc8c6126039f7d7bfecab9639ae0f67e66ff54d74ef7e3989a08dbbdfb2cdf761be3829061a435bacd1bcf66bacab3cb472d6960bf244d3109233d167e4c0d734ca053dbeff00214a374908e5d97467b0f8562dae6f7ee165d3263754ccc0cb16bdd0ab0719a23a61fabd895e685aed5c6fa5dd2d14ec3542342a619d13b96a42353655954b5023b2ac988af43282582b98852818cab5a234b4b055d101855ae5a3969b13657a34bc2c255931af39696415b428d159e5a3969b1256d11a156c456bde4a6c4594c466d4b90e73c301abee7e02b1cba281b324dc376b15574a1bfe019e9711b100181ee3dcb9516c0f738889bf4d9a2e2acbdd3480b400c6fdec94d8e46e81aea63874a2a96d12a853386e50617364682e1d946363e10e6cae028f4b2ae1c80d1af3687c036ab3ff00ce22dbf48ed69761369d9174f1b47e6d8fc37aaf5b2b1c2f703c1e8bce501d8520c45ef0c6804f7ea9aa2dbb172bfeb01afb005fd254c64447f8ebee291ca73080e6817d88ecbde50f8534a885277641d90d1f91a5ff006536cb1b87e700fc1e857bcb5e185a7b80546a8b6ec56412435ac92acf5a3d52c32494888bfa345f5f756042d6f6007e8bd634b673f0429e91176f908a331c6185d74994a74ad61e0cb99210c3ab0742eaba59b65dcd415be8bbc4b88372e31144d70683649f7f8597aa76a8d528c2118e38eb12bbda68106abaaf4c2e7fe62037e07bab2d80921cff006f64de5a073290c7603f9548c408a56f968e5a9b2bb22981337a5078f9ec57a7984101807926d5be5a396a09d8a6d8689739c5ce3eea5cb0ad72d1cb53646c55e58472c2b5cb472d2c6c55e58472c2b5cb472d2c6c55e585e72c2b0ed5a68a569f27faa5964c839803494b6c746cf5253b964f77123e2d4b5aed402165c106432497a30bb5166bd944b483441047b15a9819adc46b9ae8cb8137615295c6495d2100171ba0a89cada6554e4e4d35c15447520ea68ddda986b4f6369ad8edc7c84d9191921d1823a7557b0df257e585e72c2b45b4db2901bd763dca584ec49147f2123c2f5a18f1d0a76aa26304dfba592479617bcb0a5a57626d39adb68bee96437457e58472c2b5cb472d2caec527307307c8054e388cb2b636f771a4c9232d76c00ebd3a9510083609047b8f651cbe8d13e381d9980fc3d3721c1df01527c774e1d0856e496599c0caf2e212f961e688b2144534be4562e4a3f3ec5e8da04f4520c015801818ed980b8f63f017ac8c86056b22c416023b28f2bc2b623eaa4e883232f77400592a6caec914b95e179cb175eeae3981ad2e7740059597ea64d9ee005b801f6ffbd55e1094fa21e44869d44ed8bdc827b7fdf2aa4d26b976dea1bd08f955fd4be1c96ea4534575f6b4c3d417ded7ef7dd75c7128be4c2591b45c63c4918706f526abe14b57927b0af1dd471b18c6798f75bc8aa1d82b6d8dcefcad2efb0b5c53a4dd747545bab9158501f5b483e026b630e163a8522d4c89a6a8f5f2ab64be05f2d48c448b565adea823e14d99ec5430f4eca3caf0ae6abdd428b2762972bc23940fb2b440ab516ea4d7bfc2593656e481fc2bde57857447650e8c04b2362972c2f59fe4ca2402c8e95e159e5a4b9bd4dd2596b4f83c943640e70140f5092033516426860028234177410b101183dbaaf79614d8d0d71a1ec9e1962c25956e8abcb096194e71f9e8af72d41d10167dca58525655d7c2bfc373198923b98dfa5dddc0590ab6a8d543565a694e3ab25349163c2669e40c6035d7dcf8460e4e366826190123bb4f470fd3e3aae61f3e4498f1e3be573a28ff002b4fb2b7c37873328ba59af94d3400e9b15d6f0a8c6e4ce7d9be0eaf4011cbf0a963b65871db03e412067d2d2051d7d814f932258f19c6060925fe10e343f55cbabb2ae2c772fc244f938b8a409e664648b009eb5d7dbf45cde6cdc5c3da72e5900e945a69b60d8edd2d5179925797caf73de7bb9c6c95d31f1ef96c8a7f675581c471b88173230e648db3a387f0df7bedee15fe5f85c4e34b262e4b3222add86c58b0bb3e1b9ace218bcc68a91941edf35dc78eff00b2a65c5a72ba2b2744f97e1418e64923d8d06d868af73a50d6185bd5ce1d68f659ec2f8de1cd3d8dd2430ed1b2bb334b97e1794d374474347afbfc28c5961cf3cca63436ff005bff006548c921616df77ef63bda88e193e18d99a1cbf0a326b1465ee1d028b33872c17b3eabeb5f1f2959991b1314641638017e6fff008a16295d3436640384ad0f1fc5edf08d54991363686b0501fd530005c013d2faa8697d1d29d213aaf4309ec1755262e247864189a0550e82ff00fbe5634f1b181ad68ec7a7d9522ece7c7e4ac9d233754a9258e3796b89b1ec01575edea40f7f859a19563e0d2df1c149f26b29b5d1a18c192c224683",
            "67bdf709bc969365aabf0f3acce8cff18fea3fe95a6586965923a4a8c5e4667ca7bb0049d559923735df5286aaa8e88c9509d51aadbe118b1caf9247b762daabae899c5b16064224635ac7dfb7737e145f3460fc94b27ae8c0d5498dfac266a990b46fd54be8ddcb825cbf08e5f856f45e1686b4b9dd0016554e6dccbcf6b4629611d5e6bbfeab358658dc087178fe5715a39923667b0b0db437b5763ff6955d17a18e09429a2767d90e7bf62447d2ba03ec9f89291269275dba0fbdff00cff44bd11a2b3c51aa25cdbec6663cb6531306b556477508b21f1c059d4b856a6bfa21c0b9c5ceea49b2bcd11638a8d3456d9ad072e68c3da6c7f650cf7866239a1d4e7741e7e7fa2cf617c7b6a7a381047b1e8bcc998bc89253d800b2582a57f4396793e6076139b28a774163dffed2c471739ee7f6dba7e8ae4eee61005ea12745d118a8f45abfa57d14f992362d1bd826e88d15851ab8a22f4cce49b6793d56b6066b7118f6b985d7d452e7b0a5663bdcd93e963fadfc15a6c9237c7cc0e01bf2579f971734cd9a8ce3ab07fd4f2eaab36a0c91cd9df1961d481447b7dd4d8e64b6d17fd979163f2c93bb9e4f4b7285149532cddd0f6c65cf0d68a2932e50c6e689e37fd1d6dadee3a27b4eb5d7a8f7519b696ec9ed56a124569b66661f107cbc46a43514a6837f94fb7fdf2b59dd6c7658ace1526aee64cd6d1e95ee3dff0055ab03045136204eade82cdad3228ba712a93fb225a5bdfb2f350ae3ddb41a16d91d8a43e29233ac8c734fc114b2a469195f6443dc3cab0d6ecd069562cb041f7545e65e1ac8c634a7473c92d70041e9ff000a542f84564bf869cc0b45048d52b1335d3931647d52776ba80b1f1d15af650e0e2e99317c13c6c29b289113474f73d07d9427c7931e674520fa87c762b47864ef81cf223d98eefd5273247e44e6578a23a50f654f95ff00c325927ec69f467ebd55a647f40e8a1aaad99c4e3c7e1cff004f331d91b6805825a7dc91fa7f656d5c9a48bcdff0bdcbf0831022885c8cfc57884c5a5d94e66a3b4675fecac47c7b88b4825f1c800aa733bf5efd2becb6fc7914e4e88e30bf755e6e5c07fcd7b582aedc6bdc0ff51fbacf8ff11cbce719b19862a3a86dd83ed67fe3fd96567664fc4256be70d1a8a0d6dd7dfa9eff00ec91c12be4b294becb581c34e65cb292d81a6ba7771f85bd1411c1188e3686b076013238d9146d8d8356b7a00a4939b9326e88d2f295bc79df05966bd4d9045a5cce6c92eed6065d581f3ee553ecaa93baa3338862cf950b638640c1b5b81ec573ae8cb5ee61a25a485d9c91398c240b701601f75c7b81dddb5ed66efe574e16fa2d698bd55de1b9b2e06587c61cf6bfe97463f8be3f63ff007aaab49b8d2360ca8a6736c31c090b792b54c86ad1b191991b1e5d90e707bacd169b2b34f109bd4091ad019d01677b5b7c423c7cae1ef91b4e686eec70fb2e6695212b455451d130b64607b08734f6217baac4c6c97e3c962dccf765f42b571b322c8219d5b257507b1f9a572ae343b55e39963e2baa6d2282152500934b7d9bea09f709b499c3f1b99b39d623f61f29b231a1ce6b6a85d2e392a65f757441b34a59ca3238b3bd5a3a9364da5f4bf2a32cba8d6fea3d82a28fd226bf847206d1badda855836829905c6dee2e23b785ed05d708ea8ab7641bb35db349691ee135b34ad9c4c5e5cef7ebdc7c28d2295da4fb2b45d93ea21e0ecd3d4150a49864e4c9b6bb03ddb756ad38c6e7131b839be1714a0e0ebe8b27f4114b2c1207c4ed4af723266c8239aeb0dec00e812c915d147a2a28abb27557b5720a518d9f4da241eb5ec96e7c6c1b39c1a3c9541b9f24134de964b6bc8fa9cd1d0f8575072e116775c1d14a7938ee90d5b474bf9f65953e43a7818d756c1c4903fa7faa9cfc5a29f86169696ceee85a3b0f7bfb2c833485b45def763a2d70e2a5725c9cf08bfb2dd57746aa939ee7b83893615d864e6b2c80085d26941aa354ca4b99e238efdcf4084506a8d5566e43da4977d57ec9d2cc1ad6965127fb21344f554a7717bcb7d9a530e438c65a4024f4b49a524a42f546a9948a42c2f546a9948a405ae1b8b04ee7f31ad7c80f40eec07cabb2f0f82e8c4187b82ce8b201731c1ec716387620abf8d9b91264c71ca5af07b9aeab09c5fec8723a285f148eda8820514da561cc2e8cbeba0f7485ceddbb64c58c8f132258cc91c4e7347c7bfdbe52752b7b0f8863330dac7bb47300147adfd963ccf124ef91ad0d0e3743d9651936e99963c93949a92a421d18918587b114697a1b4000a44802c9a03dd2a397992483a10d2288f70b5a37b2e60be287318f980d05f7174aff0015c8c69616b232d7beeec7b2c942cdc1376632c4a5353fe11d56667973b25ad756ad6db5694b2c70446491dab42c2e21971cd911be071fa5bd4d7cfb2e8c4be46df47ba9b041a23b10b4f0667cee31c841737ad8e96163b728580e6579053b133d90e635ef696b082d2ef85be48da215a3a864bcb8f50deaabccf0c6173dc0027b9e8a94dc5f0e269735e6677b3583fd561e5e64d9b26d290d60fcac6f60b9e38dc8aa8d3b34b89e6c270dd0473dbddd299d6c7c13ec162c303e79d90b3abde7dd143e13f1320e2653670cde81045d742ba231d1705cdec5e198f8cc05b187bfddee167fe163f18642338089ad0ed7ebd47bff00bab991c764747cbc68b4b15b3fb8fd163925ce2e712e713649f755841decc857f62f546aa67a05b187c2b1df0b6599dcd27ad35df48fdbbad25251ec9a36a2673666460f5710168e5f0c6e3e3195b2125bde",
            "c77ff6592d796b839a688ea15a9f88e46443ca90b437df5156bcd96d7c18ce391c938be3ecae851b543278a458d3985d1bdc451b6d2d126fa36a2e4fc46181ae6cb2b4b98db0d27afd97312cbce9df2901bbb8ba87b232b2064e53a611e97ec4da4ecbb31c35e470ba2768b0a1b2365a8181ce0c2c0f7061eed04d1fd1796143646ca28593b45a86c8d94834b1788ba3219392e67f31ea47fbad671fa6be7a2e5f65a1899e1b1f266700d68fa5dd49fb2868a35f67571c8e899a33a0499a4d2326fea3d02aaccf63e2d9a3677fea411fba53e52e7192420003e7a00b96306df25385c927b801bc925557d47a52a873f1180b848e7bbec6cfeea9f12c90e7b618de7e9bdc03d1676cba545174afb348f149f7b0d601f14534716fa3ea86dde1dd0ac8d91b292691bd8b9ccc82f0e1a16f5aefd15b0e6b9a1cd360ae5c3dcd36d7107e414f66764308a93a037543aa510e3fc3a2b5e0258ed987ee0fbac9978a97638e50d2527adf5a08878b532a76924762d1dd4357d95a66bb64731fb1b703dc050c8c922226b51e7dd50ff16835710d7d81d0103aacc7e4cefbde57381ee09e8a9eb5765959758f8a471d7a909b616487b9a6dae20f82bd6c8e63839a7aad09a356d4776d91b0b1d4f5ecb31d33dc6cb8f7befd9785e4b8bafa95228d29656c6c26c6dec1421cd2c943880052a0e91ce36e36579b28146d1e2b1740d8ddd7b93eca266e77d5b070f1ecb1f64c8e77c67a1b1ee105234ed16911cc256d8e84770ad6363bf24b8eda31bd2eaeca86d256c82168b5ecf0cb8efd5ff534f670f7492f00125c001dfaa269f280db45a5191a1bb122be5479f1d5f31bfba903ed1690c9d925869ea3d9498f32c86389a5ee1dc347647c01b6a514bc99d928ea1a7a8f0b3269e5e6b98768cb4d6bd8af63ca737a3fea08d5a268eb0710c6745c86cad2e3d7f4ff0075e5ae55b9449687815ee55cc4e28c8a5314a4f24fe577c7fc2e6962a5682491bd68b0b2ff00c620f582002d975ccbe97fec939dc599a98711fb3bddedec3ec566a126ea8b51a596f81b8af13bf5691d3e49f0b270a5ca764b9f8f197b00fa9b742bfdd663e47c8eda47b9e7e5c6d74dc1dad67096920073c93f7eab56b48f2408c4e23b737d63e388b4d004d1fb525e471963640dc667300fcc4f41fa2a3c5f51c4dfafbb413f75476531c717c93669647159b221745c9631ae146fea3fa2a16a1b2365b28a8f42c9da2c286c8d95813b08b50d91b2804ed16a1b2365209da2d43646c807c0c64b95144f716b5eea242e9b1e18f1a06c51dea3e7bae4b720db4d11d410ba6c19e4c8c28e592b63de973664fb251ec33736064ba96eed0ea3eca61e0dd1bae87c2e24644c1ba8c89037b5079a5e4733e23714ae613fcaea51e87fd276475599c499872b237b1ced85d8f60b0b2b2bd4e53e6a201e801f8549f3492bb69657c87d8b9d74a3bf95b431a8f255cacb3ba3755b7f28dfcad0ad967746eab6fe51bf941659dd1baadbf946fe505967746eab6fe51bf941659dd1baadbf946fe505969b2b98e0e638b48f70697ae9e47375748e70bba24f75537f28dfca02cee8dd56dfca37f282cb3ba3755b7f28dfca0b2ec11cd93308606ece3d4fc01f256d378006c572e4bb6ffd474557826562478f231f3319297f50e3563dbfd559cce378d0b0885e2794f60d3607dcae69ce5b6a8bd716634ec38f932405c1c586b61ee97ba43a5748f748f75bdc6c9f92a3bf95d2bae4a5967746eab6fe51bf941659dd1baac1e5ced180bddf0d1654de2589c1b2c6f8c9163615696ba03b746eab6fe51bf941659dd1baadbf946fe505967746eab6fe51bf94165c8e631bf61d7c2e9780e409b125690053fa8fd02e3b7f2b438567b7132cb6475452f427e0fb159e4571e070ce9b39a65c295adfcc012dfb85c9730bba9ee5753933b23c29652e1a86137f3d1718d75347559e07c32f2545b32388009240edd579baadbf946fe57414b2e45bc933238c90f79d410bb0c7c68f0f0db130751dcff31f95c9708703c5a2b3d8388fd97545e4f72572e697345d46f930b8e6adcf8dc2adccebfbaccdd4f89658cae20f7b4db1bf4b7eca9efe56f8d3515655be4b3ba3755b7f28dfcab91659d91b2adbf946fe50596775abc3b8bc78d8e60c80ea69b6168bbf0b077f28dfcaaca2a4a99365ec8c9764e5493b856c7a0f81ec95baadbf946fe5592ae08b2cee8dd56dfca37f282cb3ba3755b7f28dfca0b2cee8dd56dfca37f282cb3ba3755b7f28dfca0b2cee8dd56dfca37f282cb3bad1c4e2e31b1042e89cf735dd28d0a58bbf946fe5565152e1929d15f7f28dfca46c8d95ca58fdfca37f291b2364163f7f28dfcaf31e0c8cb9397033623b93d005ab8fc0dc2563f2666b9a0d96341ebfaace59231ecbc6129748a11c195346658e1718c024b8f414961cf735ce6b5c5ad1648174bb0a6e9a50d6aabda9260c5c6c6df93106efdfded73af23fe1bfa3fe9ca6fe51bf94fe2b8cdc3cd3a7d31483668f8f90a8efe575464a4ad1cf24e2e98fdfca37f291b236562b63f7f28dfca46c8d9058fdfca37f291b2364163f7f28dfca46c8d9058fdfca37f291b2364163cbafba3748d91b20b1fbf946fe52364fc38465674501716b5d7b11de8050dd2b64ae5d173030dd9cf78e708dacabe964ad23c0a1ae99325f90293703874782e7bc4ae91ee1567a5057f65c33ccdcbe2f83b218957c911c7c783162e5c2c0d1ee7dcfdd57cee1edcd7b1fcd2c2d15daec2b5b23658a934ed1a689aa3178a70f8f1e06cf8e356b406bc7cf958fbf95d665c667c39a11",
            "44bda40bf95c7cac96094c3330b1e3d8fbfd976609eca99cb961abb4337f28dfca46c8d9749858fdfca37f291b2364163f7f28ded23646c82c7f31c58185ee2c1d9a4f41fa237f291b2364163f7f28dfca46c8d90596639e486664d13a9ec360abb93c6b332a3e57d3130f7d3b9fd564ec8d955c5376c952687efe51bf948d91b2b1163f7f28dfca46c8d9058fdfca37f291b2364163f7f28dfca46c8d9058fdfca37f291b2364163f7f28dfca46c8d9058fdfca37f291b2364163f7f28dfca46c8d9058fdfca37f291b2364163f7f28dfca46c8d9058fdfca37f291baf5a5cfbd1ae7d7f28b406ec7c0e16e5ba592432466c88c8f9f92b2388e11c0c9d5a4985fd5849ea3c2eaed54cec01c4236465fcbd1db6d567ec179f0ccd4ae4f83bf2628ebf15c9c9ecbc2ea16b6b23f0e96465d8d3b9ee1fc2faebfaac237d41147b10bb63352e8e17171e19d0f06c5cd867e6bc690bd975b5edf1d16f5acee1792cc8e1f1ea6dcc1a387c10aedaf3b236e4ecf471a4a2a865a2d6e708c7c77e1f31cc0e7389049af63ecb378a471c39ee6c42811645551f0b1be4a473296478eba29bdac9185af68734fb116172bc5b1f1f17287a77b69df9a307f21ff0065d45ae738d6132073b304c7691e06847bfbf55d381d4bb19e371b465ec8d92f645af44f3cd0c2e1f959e0ba20d6460d6efec4f856a4e039cc6db248a4f1642f783715871e1f4992ed1b64b1f5d3afb15d13246bdb6c735e3e41b5c73c938ca9f474284651b8f6711232586431ccc2c78f62a3b2e83f10bf1bd1b5ae7379fb02c03bf9fd17376ba612dd598ca2e3c319b2364bb45ab9519b2364bb45a019b2364bb4dc56367ce8227fe473c03e4286e9592b9745be1d85ebe57b4ce230cea40164adcc4e0f0e1e532766448f2dbb0e03a8213f13031708b9d0329cfee49bfd02b5d49a0179f933393e3a3bf1e1497cbb277d3a2059340753d2942caf5ae20822aed739bd1bb1704698873647092fad550fb7cac79e2763cee89dd48ec7b58f62b6e2e338a2005e3470afa0027eeb132f24e564ba62080680bef414238f03cce4fd9d0bb593c75b03b07791ec6caceacb3d4fc85a56b0b8ee1970f5a1ed018d0d2d3f7e95fbadf17ee8e8cbfa33221689678a273b50f70692b5f8bf0b871b1fd56282d6b683db77d3e560ec7a10688ea16d6471b8b2b843e07b1cdc8700d200e9f75db3dad389c11aa7664ec8d92ed16b63319b2364bb45a019b2364b69dde18d22c903aad29382e7c6c2e6f2e423f85a7aff00555738c7b65945cba451d91b2b5170ae212b37108603d83dd47f655268a5c79dd0cc007b7bd1b4528b749871695b47bb2364bb45ab1519b2364bb45a019b2364bb45a019b2364bb45a019b2364bb45a019b2364bb45a019b2364bb45a019b2364bb45a019b2364bb45a019b2364bb45a0265dd3e56941c1f3a66ecf0d801f67f7fd953c6c1cacc89f240d690d76a4134575b8ac922c48a395db3dad009f92b9b365d788b3a3163dbf63260e02ee78395287c63aeacb167fd96eb18c8d8191b031a3d9a2946d16b8e5394bb3b6308c7a0735cc7963810e69a20fb28a9e44bcec99250350e71207c04b54255d7267718cf306298e2c8e5ce7b003a91fe8b95b3f75bdc77123e59cce616bc5375afccb9fb5e8f8e96bc1e7e7bdb93a5fc3c1be92578fcc5f47f6ff95b2b8ac6cfc9c3648d81c1a1e41248bafb2eaf065925c18a49482f736cd2e6cf06a5b33a704d35a97a39a68b6e548e66c28d7ba839ce738b9ce2e71ee49ea543604917d4284d332085d2caed58d164ae74b9e0df85c937bc471b9e6e9a095c8710e20fe213b5fae9133f234f7fb95b39bc5719fc2e474128739f6c03b1bf7e8b070b14e666478c1da03d5cef7a0bb30435b9c8e4cd3daa311368b5d843c2787c229b8cd71f97fd47faaf27e13833b4dc2d61fe66742168b3c4c1e292691c85a1a4b2f4716dfc1a529e238f932c05c1c63716d8f74bb5d1c3467d12f7b3d4fc945a8da2d4904ad16a368b404ad16a368b404ad371b9a7321108ff003371aa45abbc2a48e2e291be578634077d44d01d1526ea2d9687324767f6ecace0cf1e3e5b6495bb003faaa104f16447cc8640f61f7098bc7946f867aad29468bdc4a78a7cade21f4d55d7754c151b28bae88952a4231518a8a256a283d3baa51f13c4972ce2b24b905fb7435f055926fa0da5db1f95951e263ba696f51f02c95cb67f12973de06ba42d36d6df53e4ab3c6f3d93bdb8b0bb66b0dbdc0f427e163daefc18a96cfb38b3646dea9f04ad16a368b5d47292b45a8da2d012b5e389d4d2f2d5ee1786337329ff00f8a31b3bcfc055935156cb45393a47498d838d1e3c0394d73a31d1c475bf72ae288e8001ecaf70fc039a5e4bcb5ade9d3e5791297db3d36e38e36ca6a86470ac5c896499ec2647b6bbf406bbadae2187e8e70d6b8b98eed67afeaa91baeea6326b944271c91bfa385ea2c1ee3a22d372f1df8997240f3b51b0eaee0fba45af5d3b56798d53a2568b51b45a92095a2d46d168095a2d0c6ba491b1b6b6710d17e55fcfe139183109b76cd17671028b7fe155c9274cb24dab450b45a8da2d58a92b45a8da2d012b45a8da2d012b45a8da2d012b45a8da2d012b45a8da2d01d17e1d94726787dc3f6fd08ff85b8b99e010b9f972cf6435835fb92ba55e666494d9e9616dc1593631d248d8d9d5ce3416a3b824e22d84ad73ff00940e87f559d893fa7cb8e622c34f5f7f0ba37f12c31039c6763874140f577cd0eeb9d98f91932c649411cb246564c7898ee9e5bd47c0b2bd3958e271",
            "01998253d997d562f1ecb63b5c363adc0ecfaf6f80b6841ca491d139a8c5b3333b3e5cf9839e348dbf919fea7caaa842f523151548f31b7276c17ad73d9ff8e47b3fff002e2178853564128e59a1979b0caf63fe41eff756a6e2999918c6095cc731ddceb455342ab845bb68b29492ab3ca1f0a6c9248a56cb13cb1ed36085142b5153722fc4733595362b5eef96ba92a7fc4197234b618990df4daf621642165e985dd1a7b275561ee492493d493ee84216a66084214804f870b3326074d0405ec69abb167ec3dd21747f87f258607e23880f692e009ee0fc2cb249c6368b4526e99cdff423b85ead9fc418ec8b2e39d8dae683b57b90b195a12da36251d5d02f08b5ea15ca9bdc1f3b031f1392f97972125cedfb13e0ad98b2a09896c333242059d4dae214a29248256cb0bcb1edec42e49f8e9b6d33a619dc524d1dd1750249a09724f1c70ba67bc06345936b97c9e2f3e5e19c79226b4920973491fd15374f3bf1d98ee94f2586c37d9651f1e4fb359790be87b38966b247be3c8700e24ea7ea03f7552cedb5907e47442b7818273725ac904ac8cb49dda3fd4aec7ac159c8b693a2a7642e859f876012dbf2247c75f97a037f755f2b81482591d8b4d8832da092493f0b359e0dd17786695d18c85e0ecbd5d06208421002bbc2e4c9667323c6701cc20b81aea07fd2a9201735c1ec716b9a6c11dc2ac96ca898ba767783b2b389992e1c85f1806fb82b97e1fc6a693223c7ca0ca774dc7437ecb7ed7933c6e3c48f4938e48963272a5cb903e523a7603d9567bb4639d44d0ba08739ac697388000b24fb2c4c8fc4118696e2c4e7bbf99fd02420e5c4512e51c6aba32b8866b73b2192888c7ab75209bbeaaa293def92474923b67b8d92a2bd68ad5523cc93b76c10842b100842d8e038b8b912cae9dad91ecad5aeec07cd2a4e5aab2d15b3a318481ae05ae1b036174aee338591c2a56cced2531969657735edfaad9e4c5ad72995f1a859b9bc1317258e742c104dec5bd013e42e49648cdad951d11c6d2b8bb3931d97abd735cc7ba378a7349691e53f0b11f9b94216bb503ea73aae82ec6d256ce649b748ac481dca2c7caeaf87f0b188c904c592979fe5ec3f54c9384604b3095d0004770de80fdc05cff931ba3a178f26ace450ba8cde158870e430e2379807d3a7436b9a921961d79b1b99b0b1b0ab5a63caa6653c6e1d904210b633042108010842035f836763e1c53b677eb6e0474bbf65d1452b2689b2c6ed98e160ae14f65d2f0ee29c3d9891c264e4b9a3a893e7efd970e7c5fe91d78327f966ca1548f88e14b2b628f258f7bbb006ed5a5c8d35d9d89a7d1c3cd33e6ca7649fa2473b6b69ec7c25fb93dc9ea49f74217b0925d1e437608421480421080108420042108010842004210801085e58f9407a804b5e1ed716b9bd41068842140193e44f92f0fc899d2168a17ec96842249708021085201084200426410c993931e3c55bbcd59f6f2ba76708e1d8b8ae74d109356db9efefff000b19e550e0d230723932685aed30039bc3b1daf6eae0c1d0fb2e2c1ec40b00d8057698392ecbc46cee8b95b5d0bb58f93748dbc7ab66ae3f0f9f271dd3465a0035455323b83dc2b50e7e44109898e1afb03ecaa39c1a0973801ee495e7476b7675477b7b75f4721c4b08e165eb65d1bc6cd27fb2a6acf1091b2f1095d1cee999760bbb0f903c2acbda85eaacf3675b3a04210ae5410842005664cfcb9b15b8f24b6d69efee7eff002ab2155c53ec94dae8b793c472f2a16c323c36300021bfc5f75510845151e106dbec10842b10084200739c1ad1b389a01400528e5921944b14858f1d885a4de039ae8f62f89aefe5b2b5b1f82e1c30d3a312c84757bc5f5f01612cf04bfa6d1c33667c1f88a7600d9e0127fecd757f4529bf11cae8c8831831c7f89cebafd178fe00e661bdc24b9da496d7623e3eeb0c750a231c7376887be355d1e92e24b9ee2e713649f72b7bf0fe3c839992e6d31e35693efd5601ecbb3c1c9c6c8c61e9ac319f4d114428f21b51a45f024e56cb6a5cb9397ccd1da7f357451141c0b858bea3e42e99f9785fe1e5dbb5cd0daaefeddbaf7f85e6c9d1d3972b8552bb39858fc731a6c8640d821748f0e3f94760b647b7b2b4c83765dd0f65a465abb45f2538d338097033608cc9362bd8c1dcf7afd956b5f437eadb068ffaacecae1f8d956e9596ed350ebecbaa3e4ffec8e67e3fdc59c7217ae6b98e2c7021cd34415e2ed39010842900842101e57c743f216941c6b3e1686b8b26681fc63afee1672152508cbb45a3271e810842b95042108010842004210801084200421080f09016b70ee111e6e309df92e1648d58dedfa947028a2973251235aea8fa022fb9a2ba58e3644c0c8d818d1d801402e3cd95a7aa3ab0e2525b33220fc3f0473ef348e9983b348afde94b88f096cb8ec6e1c3131c1dd7a0163eeb5d4835ceb2d6935de972fb2577674faa15547159985360cc239487070b6b8763f2ab2e9b8e62c93e33248d9b188927e69732bd0c53de36ce1cb0d254810842d8c81084200421080b1839670b31b9023e6000b48baeeac67f17c8ce698a84511eed06c9fb959e854708b7b136ea813f1f332f15a5b04ee6b4f5d4f51fd5210a5a4f86136b94741ffe8231881c22267ba2cf6fbdaa5c5389b73638e189a4307d4e27dcfc7e8b310b28e18c5da349659495304210b732042108013b1201939d0c0e2435ceeb5f092a4c7ba291b230d39a6c287d034f8af0a6e0b5b340e73a271a21dd4b4ffb2ca5d064f14838870a740d638643e872e89eb7ecb3a2",
            "e0f9f248d6ba1e5349eae711d3f45842751f99aca36fe25042dec8e00de431b8af3cddbea7487b8fd150e23c35f8058e0fe646ee96451055a39a327484b14a3cb450421787b2d4c89b1924b208e28dd23cfb34595a7c3b857aa130c81244e6ebaf4afbf75b185c371b1b9733195286004df7f92b40775c393c86f889db0c1f723c68d5a1bf0297b46ae8d20ad9c7cec18f85725e01786d1696dd9ff5f95c32935d236c92704a9598ab97e2bc2ce25e4c24ba127ea07bb49ff45d42c6e3f0c8ec66cc260d633a161fe2b2ba70c9a92a2b9a29c6ce71743c1f88e20c66e2bc36091bf3d03fcdfcae797956bd0c905354ce184dc1da3bd041160d842c0e15c5e28e018d96fd3414d79ec47c2bd8fc670e76c8e73b9423f779ab1e179b2c724daa3d08e58b5d9a2a3b6b2d7388b1f92ffad2e673b8c4f3cfff00f2c8e8a202811d0bbcaa78d96fc7cd6e539bce70bbd8f5fbdad578f2ab3279e37477d84fc664e5d94d2e6d74fbaaf216191c6314cbe80fc2cdc2e2d8f97b0ffc4f6f5d5c7a91f2abe771989b84d7624a0caf3d011f947b92173ac32decd368ab9d995c61e5fc51e1d108cb401777b7c15417ae739ef73dee2e7b8d927b95e2f5a2b58a479f276db04210ae541084200421080108420042108010842004210801084200421080dbfc3f8c5d2499649007d0d03dfe7fd1744b96e139f910c91e1c70891ae7926bbd7fc2ea17999d3df93d1c0d69c1bfc220c47e21739ad7c8490eb1d478fd96564b99164c91c0e06307a106c2ac091d9c45fc142e651a762389a9b9377642591b146e9647535a3627e17133be2932a57c0d2d89ce25a0fb2eb7373717161773dc1d62b97dcbbc2e38d17121ba826c01ecbbfc68f6cc7c8974810842ed3901084200421080108420042108010842004210801084200421080d3e13852e43fd4453f28c5200687523baea5739f87e47b7265840b6386c7c10ba56901c091601b23e57999dbde99e8604b4b47a6391ac0f746e0c3d9c4742ab64e34395098a66ecdefdebaae8f2b3f0df80e630b5ce7348000a3e2c7eb6b0973424df3d16c72734f6547199d8830b31d0364e636ac1bea3c1f28c038cdcf8dd96e0d89b67af6bf65638cc5045c40f29ce2f77d5259b009f659ed3abdaf2c6bf537ab8583e0af5a37281c32f8cceec105b63dd694c3879e1d1ba33acc07503b93e573bc3f8a4198ee5358e8e40dbd4f6fd15fd9b64022c2f2a7077cfd1dfc4e9a7d135e2cacde3506339f0c6d7492b7a50ec3f55431f8fcac606e443ccafe269a2b68e19b569079a09d36746480093d82e3b3b3e6ce96de6a269fa583fbfdd0fe259b243244e9896c86cdf71e07855175e2c3abb67265cbbf0810842ea39c17943e17a8400842101e100a297a8400842101e1e8b45bc17893a30fe4b45ff0009700567825ae0e1dda415dc61e5c5998ed96323af717d8fc2c32ca51fd4bc75ff0047153432e3c9cb9e2746ef870eea0bb9c9c5872e030cccd9a7dfdc1f90b8bc881f8b95263bfa961abf91ec98b2efc3ecb64c7a73f4290842dcc8dbc4e03bb22972653445ba31d3edd547238049187be1c869601604828feeba9c68e39721b1cb272d87bb9467631933e363f760341df2bc9fc996f567a1ea87eb47cf97aad712703c532086e803b5afb0a552ed7a917693381aa747a84215880421080108420042f0b9a3b90ac6261cf9d216638143f33ddd82ab924ad92936e90963df1c8d9237963dbd4107b2d58b8fe5b75133237b411640a35fd919dc186260f3992492c808da87403e6951f4592708e5f2cf281a3f35f3f658b78f22b66b53c6e91d7372e07e29c96481d101b170f60aaff8c611c574e24e80d061e8e27ecb936b9cc0ed1ee6070a3a9ab57f87f0a9f326639f139901fccfedd3c2c9e08c799334fc893e1229cb23a79df33eb679b2a0ba2e2fc271a2c33918f1f2dd10ea076705ceae9c73525c184e2e2f904210b4280bc3d05af55ee1980ccf965649239818d046be4aaca4a2ad9318b93a4419c3388491891b8ae00f6d8804fe8af637009248c3f2a63113fc0c00903eeba08626c303226d96b0068b4c5e7cbc893e8ee8e08aece364e1999189ddc9772e23dcf770f91f2aa005c435a0b9ce3400f75de10b038770e7c5c5de668e8463661f637d96d0cf69ec653c14d57d9467e11990431c9a730bbf33582f45a789c171e4c067a988b6623a90e208f85b4bd584b349aa378e08a76723c4385cb81fe607732026b6aeadfbacfb157ecbbd2d0e1445f85e18a373757b1ae69eed22c2d23e4b4b94672f1d37c3383b40208b0576f26263493b26744d3247d1a7e165712e0ce9e513e20631c7f3b4f40ef3f75ac7c84dd333978f24ad7273c85296296095d14d1963dbdc1515d29df4737408421482c61e6498333a58d8d797375a776eebafc694cd8d1cae6ea5ed06be1710bd0e7b5a5ad91cd69f60e34b9f2e153e51b63cae1c1ddaab9b90c8b02795b2005ad20107b3bdbf55cec1c673a08c464b2568e8371d6bee1502e71696ec4349d8b6fa5ac23e3bbe4de5e42ae0f2c92492493d493ee8421771c47ad7398f0f63cb1cd361c0d109c3332db2cb2b6722497a3dc00b290850e29f64a6d741fd4a108524021085201084200421080108420042108010842004ec6cbc8c393998f26bf2d3d41fb849428693e18ba3719f89250ca9311ae75770fa07fa2c7c89e4cac87cf2d6cf3743b04b42a471c62ed22f29ca5c305e5d2f56a7028c3f3dcf31078637f31fe0f2a672d6364463b3a3771f88e26496b23941796ec5bf09b165e3e448f8e1943dccfc",
            "daf503f55c7e262499d3f2a103e5ce3d805d570fc06e040e8c3f72e364914b832638c3a67763c929f68a937087cdc57d5195bca2e0e2daebf6fb2666f06c7c961742c10cdec5a281fb85aad1b1a4f81b1899bb9a1f2b3f64b8e4b384127c1c4c9c1b89c4d0e38db8ff00d1c0aa0e0e6bcb1ed2d70e8411442fa6640c72088e893f0b95cae1995c438c3daf669046000f03a91fefdd7563cedba91c93c69476473a85a7c5f86c580f84c2e716bc10438df50b3174c64a4ad18b4d3a6086966ede602e603f5069a242174bc1f1b1a5e1b0bdf0b1ef6b9c6c8b20dfff0015724f4565f1c37748bf06262c513445031adaf8ea7ee9ed63197ab436fa9a14bd5ef7ecbcb6db3d34923c5e39ad730b5c2c11447ca63e392334f6399f714a2a07662e07058d99924b302e631e446d3efe4ade600de83a2f1a5ba004ac5e2dc61d8ce762e30226f7791d1bf6f95b272c8e8e670843e4cb5c7256c7c2a707bbc060fb95c7a76465e4e5b9a7266326bd87601257762c7a2a672e49eeec10842d8cc16d7e1e85e669b236a601a57c9eff00f7eeb156970bcf9e07331618049cc92c9f703dd6399370691ae2694d36754b6f91c3bfc2398350f2dfcddcdf458885e4ca36774e0e554ea8f47542022d58d410bc3d9757818b0c586c0031c4d38b87726bdd41866ccb12b68e5475ecbd5abc6b1e286464b18d5cf243ba502b290d314d648a922f41c2e69f1bd40735a2ac03eea8114483dc7456e2cfc9820e4c6f01bedd3b2a8ab1bb764477b7b75f4731c7311d1e47aa74db091da861eede9fd964ad3e3734927113138fd1101a8fb8b598bd8c57a2b3cfcb5bba04210b53304210809471c934823863748f3ecd16bc735cc7963d858e1dc38510adf0cca661f106cb27e420b5c7e01f75a1c7a4c59a38268658def26be936485939b53d6b82faa71b30d0842d4a02108400842100210840084210021084008421002108400842100210840084210026413cb8d309617963874e9ee12d0a1a4f8613ae51dd360831d950c2d659afa1a07eea696ecb83d47a5e6b79b5b6a98bc777f67ab1ea8b5818afcbc9d1a69ad16e3e15bcde1aec488cc1dbb01ebd3b2a38994fc49f9ac009aaa2ace7f1376646226c7a301bb27a9f0a9c984965f62afd4a8e7803a1ea96666410b9f2482368ee5c682f163f1f8b7e1e24b3fe5bc1af637d1690572499b4fe316ccae2d9edcecb1cabe4c629a48ee7dcacf4217ad18a8aa4798db93b60b77f0f3e5b9e3ab8851bf83ff7fb2c25d1fe1fd460487a5f30dfec1639ff00436c1fb9b4b478372bd71e6017adb493555d56723dec2f31ab4774e3bc5c4e978c724f0f76ff00981b6d1f75cd2939f24aed9ef73dd556e36bc2c205f4433c38fd51d6c4ced7bf1e46c4ed5e5a434fc15c66443363ce63c8691255f537d17579bc471f099fe63b6908e8c6f73fecb939e7932721f3cbf99e7b7c0f85dde32972fe8c7c87175fd168421769c808421002f439cd707b1c5ae06c106885e21402fb38cf10616ed287b5a4120b4751f16b59fc7714e13a489dfe701d2378a37feab9a42c65860cd639a6beceaf87f158b30089df4cdad91540fd968ae0c121c1cd716b875041a21751c17326cac7904efddcc70175dc2e6cd875f92e8e9c59b6f8b3556962f179b1e26c4f60918ce83ad1a59a85ca6f38466aa48b197992e6481d21a0d14d6ddd2af685e2168a51548f4900592b0b887196b5b1fa19c39fb7d40b4f6fd5793f1e2c9a689b8f61b6d6bb6f7f95cf8baebdd75e2c3f723972e6fa88c9a6932277cd2905ef366941085dc9570717608421480421498c74b2b6360b738d05008af287c2ea7ffcfe19c4d017736bff0025fbfdbb52e61cc74723a378a7b09691e5670c8a6da459c5a499e21085a95042108010bcb0bd4008421002763e264e5bcb71e12faee7b01faa4adce039d1421f8b310dd9db35c7dfc2cf236a3712d1abf91464e0fc4636971c7d80fe47027f6544821c5ae05ae1dc11442fa07423a2cde2bc3a2cbc67ca1a1b3b05b5ff0035ec573c73b4ea46dea528ed0672285e0362d7abb0e70421080108420042108010842005adc1b87372de679dbb44c341a7f88ac95d7f04a1c221aaebb5d7dd619a7ac4bc21bba4722e7bdd2195cf73a426cb89eb6bb3c2979d830c9776c164fcfbae2d5a8388656340f821929aeea3e5bf6519b1ee9517c59347c9d9a16170fe310b308fadc8b9438d0a24909391f882432b7d2c403077e67777edd971fa67754767ba0959d048f11c6e79ecd04f45cc67f17766e218043a5b8126efa0ff00a14a4e3d98f616b238e327f8ba9595f75d18b0d73239f2e6be2208421761ca08b21a407100f522fa210a01d9e0b81c184739b310d00bda6ed59b174b83692d274716df7a349d8f97918b2f36190ec7a10eea1c3cae2978cf9699d91f212a4d1de43cbecf76bfeaa324b1924466dbdad733371d1361c91181ec91ed2d0e6bba0f2b2629e78619228a52c649f980f7548f8f27d932cd14ed723b894cdc8e25348c36cb0d07e695542177c56aa8e36eddb04210ac4021084008421002108400aef0dce18395b3ef92f14faee3caa48559454953263271768e9e5e398b1e488803237a5c8d20816b54104582b82af85624cdcd95bac9952169f606bfb2e4978dd6a7547c87cec74597c6b1b1a711006623f36847d29127e21c70dff2f1e571f3402e700005014bd5a2f1e1f651e79fd0cc898e464c93963632f37ab7b25a10ba12a5473b77c82108520108420057b8435aee2f00755593d7e68aa29904cec7c98e767e68dd7f755926e2d225",
            "77c9de7b2e2788969e2b945b55cc3d9744fe3b80dc5e6b24d9e4748e8ddf95ca39ce7bdcf71b738971fb95cb8232b7266f95c525189e21085d87382f5ad2f7b583a1710dfdd7880e2c7b5e059690543e81d93b84e03b1463fa7680056c07d5f7b5ca65e2bf0f29f03faebd8fc8f62bb78a46cb132561b6bc070fd573bf88e3026c796bea20b4ff00dfd5716094b6a674e6d552461a1085dc7302108405d838af10c76eac9f76fb0906d4a53f18cfc984c4f7b18d70a768dab0a82167eb8ddd16de555608421685410842004210801084200421080158c7cdcbc58dd1e3cc58d7752281a3e157428693ec94dae87f2bc2395e16a7a6f08f4de165b94b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b27c33897a48fd3e4349887e5734596f848e2b94dcf9d9ca69e5c63a122ac94cf4de11e9bc2cd28a96c5de46d6a65f2bc2395e16a7a6f08f4de169b94b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b32f95e11caf0b53d37847a6f09b8b36fd2f847a5f0b77d2f847a5f0b87d863b185e97c23d2f85bbe97c23d2f84f60d8c2f4be11e97c2ddf4be11e97c27b06c617a5f08f4be16efa5f08f4be13d83630bd2f847a5f0b77d2f847a5f09ec1b185e97c23d2f85bbe97c23d2f84f60d8c2f4be11e97c2ddf4be11e97c27b06c617a5f08f4be16efa5f08f4be13d83630bd2f847a5f0b77d2f847a5f09ec1b185e97c23d2f85bbe97c23d2f84f60d8c2f4be11e97c2ddf4be11e97c27b06c617a5f08f4be16efa5f08f4be13d83630bd2f847a5f0b77d2f847a5f09ec1b185e97c23d2f85bbe97c23d2f84f60d8c2f4be11e97c2ddf4be11e97c27b06c617a5f08f4be16efa5f08f4be13d83630bd2f847a5f0b77d2f847a5f09ec1b185e97c23d2f85bbe97c23d2f84f60d8c2f4be11e97c2ddf4be11e97c27b06c617a5f08f4be16efa5f08f4be13d83630bd2f847a5f0b77d2f847a5f09ec1b185e97c23d2f85bbe97c23d2f84f60d8c2f4be11e97c2ddf4be11e97c27b06c617a5f08f4be16efa5f08f4be13d83630bd2f847a5f0b77d2f847a5f09ec1b185e97c23d2f85bbe97c23d2f84f60d8c2f4be11e97c2ddf4be11e97c27b06c617a5f08f4be16efa5f08f4be13d83630bd2f847a5f0b77d2f847a5f09ec1b185e97c23d2f85bbe97c23d2f84f60d8c2f4be11e97c2ddf4be11e97c27b06c617a5f08f4be16efa5f08f4be13d83636391e11c8f0af69e11a785c7b18594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d8594791e11c8f0af69e11a784d859fffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080100010003012200021101031101ffc4001b00000203010101000000000000000000000305000204060107ffc400371000020103030302040405040203000000010203000411051221314151136106227181143291a142b1c1d1f01523e1f12433165292ffc4001a010003010101010000000000000000000000010302040506ffc4002411000202030100030100030101000000000001021103122131042241133251611481ffda000c03010002110311003f00644e2bcdd51a864e2bebcb84dd53750b757a1a8009baa6ea1e6bcdd4005dd53750b754dd4082eea9ba861aa668184dd53750f754dd4004dd53750b7540dcd0017754dd432715e6ea002eea9ba85baa6ea0417754dd42dd53750017754dd42dd53750017754dd42dd53750017754dd42dd53750017754dd42dd53750017754dd43cd427140c26eaf41cd081cd1168111a8fa6416f717d1c774c5623927071938e07de80d426a5256a869d3b3af3a1e95751b2470b46c3f8831c8f7e7ad72ba959b69d76f6eec1b6e0861dc1e9468b5ed42de3d91cfc74c9504fea4506d125d5f548e39a562d337cce7ae3bfec2b9f14278db737c2d39466924ba672fc0af03538f896dec2da3b65b44546058363a91c727cd2304f5cd5b1cf78ec4a71d5d056e391d2bc193d39aafaacc02e33cf1c51e08ddba2e08ea0f7adb74641ab60f271515c6ee7a512789998614ae7839f359c901b1fbd0ba0682a1b257eb5e46a586462ab13818c7e6e8715771e9ee2a71d38279a5632b2615bdea9bbdead942379070684d2038c0a684183e78c8c5509c1e685bc9af4939eb9a28026ea9ba85baa6ea6017755a2569a548d39672140f73400d5e872a41048239045203a98be0ff907ab7643f7089903ef9ac3a8fc39756319991967894658a8c15fb56ad2b599f5090218a77987e69231903dcf8ae927778e1668e2f59c0e1010377dcd7993cd97149293b3b618f1e48b6951f3add53755660f1cae8e86360c415231b4f8aa6eaf4ce20e8371ebc54239c702871ce636c8191e2bcf58e7da800a4115e6e007bd08e7c8f3514e4804e28034aae573d079aab2b2b735ea90a990c0f3442770e6958c1ad15686060d1169811a84d456a1919a001357905c49693a4f0b6d910e54d7ae31c5088c9a2ad531785e5b892f6e449712e4b1e58f0057972a2297d3c824632c0e7343dcaad9c023dc54b86018147dc9d465718f6a555c405a2dfb86c8cbe7db39a6315c09f2b1831caa3db144d11c4eed1850a117200ea7ce6aba9468b76bf86973720f2bed5372b951a4b9602e59c30679d7d33c8c0acafb1c318f0a17a927ad52e629a090c7203c1e3c5046483d7819e2a8970cb34c29bb24b0e99e064f5e947b5b4b8d4ae8c68a72012c48fca3c9acb6b36c6fe22c46d002e7767b57d2343d2934dd39630811b00ca4f566c73fdab9fe4e7fe4aff4b61c5fd1ff00c10c5f0e58bd84acc24322a9db217ee067a74ae486588550493c003bd76df15ea09a6d935ac58f5661b7038d8bdcfdeb8945cc7ea0619070173cfd697c594a517397ef83cf18c5a8afc1e45f08ea32441d8c31b1fe076391f5c0a597d6171a6ca22b942ae46477047907bd31b6f896f6db124d12ce5782c588cfd71c52fd5b58b9d565569f6284c85441c0f35bc7fdb6fb551997f3d7ebe997755e389a43c74ea4f8a1c6af3304452c7c014c74f2664920fc31207560d80b5693a449207a459a6a3a8456d2486357ce48ea703381ef5d0df7c29691c5fec9b80d8e1890403ee315ce7a6df88dc4b298c8c79183fb53a8be31bcb73f8778d6420e03b29dc7eb835cd9965724f1bffe16c6e14d487f1c5068f6b1dbc51f6fff0047b926bd9f55b7b5b4fc45cb7a639c2e797fa5729a85fde5c4cd234f2c72336c3102401c704007814a6e84c24dd3bb3b119dcc73fbd463f0f6ecdf4abf92d3faf812fef0df5e4d72c369918b633d3dab3eea8d1b2c6927055bb8ed54cd7a0924a91c8ddbb65f754dd54cd4cd3104c9f7a80e6b7d87c3f7da85b9b885502ff0866c17fa0fef589a3757daca437704722b2a716da4fc34e2d2b65e36c1e80fd6b52b6f190314111150a4f1cf3ed454c0240a188f7bd5d6a9deaeb4c646aa66aed433401e4d8c63140dc149e01c8c73576a135084558ed5228278abb5509c53423669d673c938091c9c807729c6013d69a49a7adbce26b88c848800854704fbfd07f2ac7a7eb42c6303d253bb0ac7b63c9f34fadf56b7be461195040070fdeb9b24a69dd70a45211c1a5ddea21e4790fa79c6473bb1ed9ad326872e9f048f1ca8d95c12dc1cfb78ad7a7dded9a48d49db9e03373bb27a0fd298ca52589d6443b7a6319ac4b2493afc1a8a3851398e549109dea776e3e735dfe83f1326a119592e238e4e094721493fd6be7b7319866742a5769c60d5634695b6a8e6ad9b0472c7a18f2383b4763f105b594b7fb6299242e412a18719ef9f3ed49f58b43669b638cec0f90dc1edd2aba55bc771ba4b99c87002edc7000f3e283a9dd4d13ac29348ea0021f18cf5ace38b8b51bba149ddb3abb7f85f4cb8d3d0992533ba02ecaffc5f4e9c520d4b",
            "e19b8b0996348e59379f949c6d23ebfd38a63f0aeab6efe94371288ae62f91558f120c79f3ed5d36a9227e1e269080fbb0b93e7fc15c7fd7262cbab77674e919e3daaa8f9d8496c265dd0347228c062d8c934e74f36e6cd9a5112cdb0bb6de739efc565d69e4d46f5e1b783798176bb91c0a3687673c726248dd500c12ca579c76aec9bb8dbf4e65e9b13468e67fc4cfb8bba82506300d2e934dbb86ee39e14322bb2865519207dfb715d366aa02c609e83a9a82cad1b7142bbb582e2410a9ff0078824375ede694dee997b2a8d801455f9635233c1c6703bff7a797fa8da5a42c1a658d981da06493ef8ae726d684cebb43a60050c30081c67ebd2ab8b6f519951ab4fb596f2236f8458e22430cf249ff003f6af27d02ee49552320c63ce32bfe62b56957803950c06dc007382def8c76c5689e7921bb44f51a6565c957193b4fd29b9c94b82a5473725afcce2325c27e62074f354b7b769e645c1da5d54b7619a7fa9e950c9024968863695c0cf40a0f1fa52ab6b8b8d3ae4444166041da0e72d9e0f1558cf65c3354fa77da7d81b591b381181b140ea476a45abd8c3fead3c8171f37627af7a716fafc53db2dc2c6c262398d87e53df9f149ee18bb1663924e49af3b029a9b948ebcce1aa8c45f3c6194ae31e2b26d2ac476add2f7acaf5df0672b07575aa55d6aa223509a8ad426a00a11c673416a2b509a98813551aaed5463c631f7a1081b537d1e0b7bab6786660ae589525f1ce3c52d861f5d88ce00049ae9344d3e3fc144ea231231cbb725b1e3af153cd2491a8a091698c0ac2ce25890074623041c9c7f9deb35f3ea9a64a937adeac6460e13201fa56dd5355874cc025999c1380d9ffaa0da6b29716292ca584808040c7cc738e2b996dfe4d70a73c176ad6b7175862a257e0e5108cff9cfed436852ce048e40a970e02e49fca338eb4eaf165795268631ea05cb6e2063dbeb4a21b39bf1445f946795772a375623dfcf6f7aa467ce9968dfe94b6c0c9f36182b6d4c124fd7c77a51a8ddacd39b6608db4f2c0739f19adb776925d932aa49ea8016358c8038e39cf8eb43b4f87d0c8a6e99c6416900c050476cd38b8aeb076c4e118cee23db2a838c9ef5d0dac91430c325c31b69622b852c486c93fa79a477ef6eaca96cbb5172323ab1fafd6ba7d36cb75b1137a99654cef39e300ff7a7965c4d8a3e821346d7ff0087b6421c9de6653bbbe71fce9acb71f8754320cef709c793d294ea13cf6ee8b6a15bd3e0ee60bc0ec2a5bea90eacdb085f91496cb639e7a78ff9a838dabfc3698ce4ba8c7fb81dc88c12557fad73b7daacf24924ab218d3036a7473d7aff002fd29cde491d8c4d845612292c09c13f7a44ba52ed696e37408ff2800678cf07f415bc4a2bac52b144f712dc485e562cdef5e989e354908521ba0cd5ae6ca4b7b830a02e4360151d79e2b62e833ecdcee1011951b4e7ee3ad75392489d32d25f7e1e36685161720024724f823db15ebde4bbd36dceefe32ec3e5cf6f7fb52f9de68b11484310981c741fe135b2dae2dad6c085dad70e4365b9da3c565c783b1ffa897e8b6e8e5e30006994919fb74f6158fe2380c33dbdd23038006781d391d2985b5c8805b8455901405820e1063af1f5a3ea71a4b673314593726e5dddb8ae68cb59236d5a32695711496ecaae0b2e0b7dff00c34696b26960c301ca6d89c0c138ff0039ad0efc743c0e80536bedc0fc334bdeb2bd1de40e481dbad6698e055626595cf3575a12d156aa223509a8ad426a040da84d45393d2bd8ad9e6703a0ee68ba03235160b6590191f3e9a9c300704fd3ad127b7862563eb6e238c01ce7fb501de4400163c0f97af145df8035b4d352c1d2792e490dd906548f04fd715e85b982430ace7d29437319e471d703b66959bebb7237c8f2293f918f069d69dafc4b0059e344dadb07cfd3f5ed519a92efa693426b9894cb119cbcd21e1c0e3ce47d6985babc86d912168a3817d4218659867edcf5fd6955f5d35f5fb347c2b39d83a6326981d6eeed4bc662575255778c918c1efe6b524e902686e9ac2ee45cb487215be5c1c93c7fd50a18e2b8b96f51da628c48dfc15381807db9e291dadcdecacef12a9566326641c8239ebdfa574feb9b65134c1111c02fe54f4fbd4271d7c349d8ab4bba326a05a58f61401011f94f83fa66abf11b10408ee8c6dd19031e9fe1ac9752dbc57a6e11dd94b13ea021b9cf4c13e2a5c7a3aa0210833ff0866ce471c6476cd5147eca42be50db45b18a7b68aea558e527a64640238c8f7e29c3bac6859b851d78ae66c3523a4c8d6733991588f476630327bf8a7b74c896ec2e0828781f29393db38f7a8e48bdba6a2f873baaeae97374b6d0c7b36bed2dd739f1e0d0ed6048ee5409991ca642a64038c771db8fda994ba6d9dc4cb7305c7a61493b5572071d3a7d695c71459499af3d464902c6c01054e7bf91578b5548c32c8926a124d6f35d4afb72cb91963e31ed8a731696bbc0f52e3604daacd2741d0f1db8a5f712da5aea2b3cd30de319099019bdcf619c7e951fe273790886188aca4e325b008acc949ff8f8354bd37a69d122678731b7fb5d01e3b7ea28da81dd6b26f843ca14e23de3073d79f156d9140812590bcd18de18f0719fdf14b7e2397d3f4ca322c8dd0e32768f39e9cf3f6a9c6e52469f10925b790c5f8862acd21180b8f9463f6a1d9cc90cb978d5d482082338e3b574b1d9cd068b2883d29cca3823c1ebfa735cb491b44db5860f715d5096d689b5474526a908b78624592072833b579618183daa96da87ae16da6b9d8130164db92c",
            "be0fed40d3efa4bcf42c99226662b1ab11823dcb7e9fa574dffc22d26058dccc1c8c9da005cfd0f35cf932431f265618e53ec45bfea114131863f4fd15000c1e86abf8949d87a6e3dc79fbd0f59f86a6d2104e8c67831b4b8e0a9cf7158c423d07e09907e65e8456a1a496d16664a5174cd7332c60b63a9ed59a470cbc60d0cba98c677641fe2aa8c678e9568c68c175a2ad0968ab5a02350c8cd11aa940026c8abdb4bb6551d413d3dea32ede7ae7b5511cc3206000fa8a4fa80d0da709e5dc849527240ea2b67e0a0ba52ae3ff0058cf0403c8a158dcc9292c00e18023c8f35b842f7104bb50464f0bd4120542526bd3491cb3b625df101f2007a74359dcee624e3934e2eadc441228edb74ad93bb0460f3c1fed4b5ad9d25092c6cb91c28eac7b62ba2324cc3466491a270e870cbc8344b8bc33260ae188f98e7a9f38aeb745f84ade2885cea6bb98f2b131c2a8edbbc9f6abfc4ba4e956fa3cb32dbc30c8b8f4da3e0b367a7bf19ae77f2e0e6a295965f1e5aecce46cf539ade58c9772899f941c7d6afa96b53ea112a101110f0031248ed9f3f5a5e4e33d6aa71c62ba7457642d9a614ffc59082a5dc6029eb8ce4e3f4a15abcf1ceaf6e5848bd0af5155491f6fa6a7f37b7f5ae8be1ad2ee61b979ae119548c6d6eff5a5396a9b634ac65a5451456e8f751c715d92490f8ce7b1a1dceabea07855c90a48672980c7ae3dba1f7adda95b34718ba16cd206f97238efc1cf7a43ae6a302c6904018c990d26e247effdab920b77651f0f7466925bf49d99c46576ba1181c8e31edd29e4da4da4b1931c31060772e0639fb570f134a58ce0c8c8bb509ce0fb0fdab63ebda8c01d37b2866c82474fa7f9daad3c526ee2cca92ae9ab5bd3915e47b6f49c290b211d4378fdbf7a4acb35b4e4365258cf63c8229869f74a34ebc5691bd438600b6327b107c8a57b98924b124f539eb55826b8ccb3a7d3ee6d6f2cb17d701a45e76ee39fcc3073fd28df10417133c0caaad012bc9ce49cff00cf6ae734fba6b49cb28c875287ef5d068ab77aedf9b6bb69961886e7c70478edd4d4671d1eff0088dc7edf53a3876342aa170bb7a1f148a7d2ed2ff52655b967e819179c1fed8cd747affa561a52bda2a21899532c7b63be6b8f8ef657bf91ad9152497e50dd813e7f7ae7f8edc93944a658eae98da1f862dd3204ce195832b0ea0d7476d70ab8fc433121890caa2b829f53b88a5900b87326fdc1930053cd3b53dfa7fad752e7736d2d9c6d3ef5acb8a525f66661349f0e86fb51865b59228d19b78c7ce3007bd722da55d5f4d2c91a954cfcd231c2e7c0f3f6ad3a86ad08091c328f9b8661ced15d4a7e0cdba08da1300185c30c546fff003a5aaf4ba4f3376fc3919fe1dba8ed5ee9648e458c12e06411f4cf5a5ab5d1ebdaf5bfe19acac995f7fcaeebf954781e6b9c5aecc129ca3732196318ba8845a2ad0968ab562446a1938a2350cd033cf508ec09f7a1bccc3208539f6aeb34bb6d26e2ce106dd1d8801d9baeeee3ad2ef88b448ac6259e004439c10c7254f6c7b573c7e445cf46a995785ebb2762286fa6b552b19519f23a53dd2f5069e2679360445edd49ae708c9e3b9e95a5d2ea2b61b015403248ee33fd2ab9209928ba3ab7581a5477701803b79f34835c9e29445244d97cedc918c63ebfce8ba75fc4b0fab707d4b8520290b96eb55bed4ad2667124604c8c02fcdd39f6e38a8422e3236dda3c97e2c764861962042a006407f37039c773c527d6751b9d46709248af1c7ffad2318551fdfdeb5ae9492dca6d93646ea3046064e39fa7f5a06b16862bbf4955bd355f94918fb55611c716b54294a4d7451b5981201200e6a8699b473c312ca8115db28c4118c0c7079ea6961cb1ee4d5d3b27468b128d3244ea00638df8e47bd3eb8d7dada111a6fdc8554c85721948e09f7ef4bc7c2fad431adcada38230400c0b0fb75ac52cf2470cb6f2c6819d813c72b8fe5d6a4f5c8f8ecdd4a3ea3e99697e9a8fc3913187d5564f4e45f04704ff00515f33b99cc8f20254caae7e73d48e9c76ec2bdb4d62f2c2dda2b5b89220e4e76b638ac44e4e727358c1f1ff009b97fa66b2e5dd21a69d896de69662c5603b881f99b39eff00a9a15c3868d8ba870e41de0f29ed58439036e4edce48cf19abc6c6394aab2b0395c9e86ba35ed92b37d85a34f0326e011c82e719cf3c73edd6b75d6810d9da860c26958939e400a7a1e38ed5834d8dcde4702b0619e55bbe476fd6ba2b5765db6f2b2cd1b90106dc055079e7bf6fd6a3924d3e337156730d6b2da4e82642000180ce735d7fc177f07ab712ce8c984c33019ebc8cd1ad628668164923188c95519c8c038cfed4ab5716accd340eb1480a8f9783d79247dc75a94e4b2ad19a8dc1ec86dad5f5b4f1408d1e6dbd4190cc173c753fafd6b109ede2b432600688b6dc701b1ce3dfc7dab9bbd91e59b66f2e17f292b83d3f7ad091dc4b1c5129c0da01c1ee4e06477fb56d615149589cad994921c9c0073dab7ffaacad66d6c5130cfbf38e87d8741435b00514bca37bb11803f2e3939fda87342b14855240ea3bf43fa55b8cc751e6e2c727ad5d68628d0c4656da303eb4c4597ad1f80071834208c8c3231e28b838e40a432cb455a12d1568023509a8ad426a00b5bde5c593fa96f2b46dec7afd455afb58bebf8845713964073b400327df1d6b391938a1c831deb3a45bb6ba3d9d5583fcc40278a66865b6558c859493d077edd7ef4acd3ed3e4b792c0b5cb03b7e53bc636f4a591d20884ff004b86ea2dc88237ce491c0e38c1fd291dc69d70d772",
            "7abb230a705cf0bf6f34c13e21f4279623f3db9c80c33bbede2975dea51dcef26003764f5e871c5620a69f46e8a2ea22d3d445883313c93d88f02832ea8f2aa0914315c83f43d878acac7343357d118b2e191c1f55dc1eddf26a89197dcdb9404049391cf8c0aa9aa9ad501f44f877583aaa6e32a97c7cf1b30dca7c81dc52af8e74fb78a7b5bc0a11e662920e9b80c73ff35c82bb46c1918ab0e41070457b34f2dc3069a59243e5d893fbd72c7e2eb9378be1779ee1ab451c6188c639e955a9448a269a558d06598e064815d873968ad669e379238d995080c476cd4785ede40b32329c67047e94fada2b4b0b274b86c3ba37cb9fe21d011d8f22b9e9a4696577662e58e771ea6a7193937fe8d354312c269571809b771283009faf7ebcd35b7d62d2d0ac0c88f18504b024ed3e3007935cd7ace502162557a0f15017909ea7cd278d3f414a865757e1ad5634739c600071b473c71f5ac702fa8e10eeda4e4e067f6a24b64628837cc5891c81f2918ec69a6805209df6abb6146ee4838f38149b518da0f58ded2d6d2eed964bb9119c39cb72b83d7193ed8acf3df5ae9b79eb456db8282bc1e872723c7715e6a3acdac511b65823646e768e307dc63ef49e0d9226f9ee82a21c85237374f1518c1becbc36dffa3b1b4b26d56d96fa098db6e0507a801dde4e3bfd690eafa39b1b8944ae85f687050f524f70791c6684daacd0db8f42e641939049e57a76e83b56133c93bee95d9b272ccc727f5a31e39a95df072945aaae973b542c654e47e6e307ad33b5b20a15d0eee79278e3e94ae5003e5776d6e573d719a343752c44ed6201ea3356926d709a6329d07cc4fdb1d6b1923a753e4d6a8a4692304f3efe6852ae79acc79c1b06bd68ab435a22d6c08d426a2b509a81036a137268ad426a600cf3d28924bfed9545e180523be457b06df546e283c6ee99af2e1143168b18f00f3d697e818daa8d44704120f0686d5a10335435735435a115355356355340153518963935ed798a00f314644544f548661bb6f03001fe5f6a1e3ef4697d1f454472485bab211f283df1498c03727a9c76cd798af715314c44a25b49e94caf9231dc007f9d0f1500a006f6a96a6ee14966748e31bddb3c67a8c7ea299c77363697173782592662377a678ef8e7cd20b77ff65e3555677ea58e368fbf1e2ae1fd487734a4b2ae0ab6079e9e7b54650bf4da65efd62698cb06023f3b41276fde850c6659022f5342ce6888cc8db94907c8aa552a3231bab1862b58e68e7427a15cf2dd79fa6315916a80b360124e381ed571d79a4957a32e0e68831db3431575a0430b599163da783d6acefce2b1a1c51739ed59ae9a0b575a12d1569811a84d456a1350206d426a2b509a980335e468cee028c9ed51a8b6b2c7197f53246d385c64134302cf1466332481db7e76ecc0f9bdeb0c91481ca956dcbc118e453016df899c044488617083233d0719c93ef5b752d3adad6c76965f5db0cbf36338ea7f7a9ee93a1d58864b5963884acb85276f5e73f4acfb4b67009fa57d13e14bc82eaca08228235d8bb64e9f9bc9f39a3eb3f0ad99866b9b781526287714e011df81df19e82a0fe6eb3d26a8b2f8fb4768bb3e626ab5b2eac9ad98839277600208c8f341f448e5c15ce08e2bb534ce7a038a98adb6f62b773c891bed8d013bd87071dcf8a0bc014e1583738cf634b6414560b39eebff004c4f27201da338a711687335baab59b0640c5ce705bc0c77e6adf0dc6b06a444cb2c5205e010473e0ff3e6ba3bebb86085646b831296dbbc73d3350cb95a9523718aab3819ed9eddb6bf7a1e29c6af0a4bbae12447f9b83bb24af6febc52c8607b891638d773b9c003b9abc656acc340b153144922789da3752aca7041ed5ec70492e7646cd8eb814ec010e2b50b36fc309c488de501f997de805769238ad6f1ac312e6424bc79076631cf4ce6936081fa48222db8ee07f2e38dbe7354150391d091918383d68f650acf3aa33003a9c9c671da8f3d02a870720e08e45191d423e72588ee3ad1e78ccac8f1a0d873b48180ded8fda806221d941042f7f3493b1916888090719e286a0e338e2b6aca2e130c0215e7e5e847d286c0ac614a904e0d11485f7a1670d575a401168ab425a2ad0046a13515a84d40036a13515a84d4c0135509c55daa846681111d93715ea463ad6c446be75827977a44d8debd403e3db8ac6f16370f9b72f518e94329f296dc001e7bd26ac66ed12fdf4cd4b744c707e5ddd0d747abebdabc8e905a29f4dc659c639073dfb57256f048efeaa1055181dc41c67feebb4b1ba3710239511ff0953c63e9f7ae6cf18eca4d59484a4952625bbd36e1a349dc6e66007a71a64fb73e2ad79a65ec80342a8eebc7280647f87f9d74607246466b3c71153b5a5766c9f9b9e9fcaa6b2b1ea70b72d77692b44e5a37e7254e0907dfb8aceaaec491ce39a63aa5ac9fea92c523286e4ab1e770ea2b240cc920420e3382315dd17cb24c70f31b99bd556d8b0f3bc8197602837f20919d1be48d1ffdac2fe619ee7d87155d2afeda06649620dea0e4b9e339efedcd35b8f866f6fad7f1d1482403e68e2727738cf5e7f954252507f6e1b5172f05b63f0fcda9ef7b15df02b056698ece7c5307f8426b541233884bff00f4c363c807fea9469fab5ce925a2037465b718d891f379c8a633fc61717922ac9188adc1dc523e4b1f727b529acdb73c34bf9ebdf4f67f87daea30c3265ea5d8fe619c702974d0dbdb44541f4e707008f1e734dee7572f69eafacd1871f2e17e6db920f0693bdd4b7f0adba45ba466e5b6e4b760",
            "33da9c36fd30ebf0a582dac84b4fb71bb952393db39e9592ea3f4ae1d3821785c1c8c56e4d26491d2276319c752381ce38f6a16a1a6b58952640e1b2079aaa6afd32d70c861648c39e430c8e0f9c548d0bb6148cf5e4e2bcc9c633c0ed50715411d3da5b5e5d6909705a3c2659366329ce32c3c7d2923cae4857c92a791da9868df108d3ad26b596dfd647560a41c1191d0fb52bc82460638150c6a4a4ed73f0a4aa950cb4b8127468d9c00df9b3dbc5791478775c00a72158f8ac704ad0c81d7a8adf26a22421c20c8e99edc73fd6b4d3b3267db838feb575a1e77313e688b5b1045a2ad0968ab4808d426a2b509a8006d426a2b509a98026aa124720e2aed546a047beb7e62c58b37714163bb2481927a8ab119a81727029d006b0648dd9e40fe9e304a8e95b6e6f91245115c48f1201c1000271fdeb225bb6c753be3246e00f0081e6bc9044f0a05770ca0e43f4fb561a4dd9a18e937eed3825f0ccc7393fc38fdbfe2b56a372b6377ea4133a891395392074e9edd7f7a4b60e21b9590c425033f29e074a7d7d6a7518e431c85822f2a00c83d4e7cf6a94e294bfe0d3e08b53ba17737a83e62dcee3d71e0d646dc719e3c715b561b4650a646460a4b3379f18af23102b846f9d323b63af7fb5593495232664b6925864954642119fbe7fb57d0b499269342b631ab2ca9184391c8238e9f4e6b94d31edecde4593f30390dc83e4671f6ad371abcd632fe22c6e407240938e1b8e323bd72fc883cbf545b14f4eb177c4364f06af70044ea1db7f23ae793fbe69708f774047d6b749a9cf7024f59b73c8db8c8dcb0cf503c0a6566f6d7166b6d91f88653cf7073e7f4aba6e114993e3673be992768073e2b45acf24122952c181c820722b45f69cb640e260ee1b0ca0722b21fcc08249fdeb76a48cf869f5ae4ecbc98bb146c6090b9142d46e05dcfeb08de3dc3243316e7eff004ad96f1dd5c88c101a2cf427a77fafeb57d4f4d3123cad27cc1b0071cfbfed584d263ae09b6d4db44d9919af36d54c94031575a9b6bd031400585433004e056974548402b86cf53e28565913ab088c98e4a8a6325d5bba7ca9f301d31deb127d1a302d15684b455ad0208b455a12d1569011a84d456a135000da84d456a1353004d54233442335e6da04500a9b6b4dbdb898b6e60a00cf3e6ae2d1a660117c64e7814b61d193923048af0a8f35ba4d3da328339dfc703a55e2d34c93a02422b3aae3bf2452dd7a14c0476970b68d742298440e37ed3b4d19355991711058ce739ebfcebafd4e14b1d16f118aec2bb117b0ec0570eaa8a4ef04b740338c7bd470e459536d15c90d29175824ba959dca8eac5ba67e944b68638e42d76c5038257e5ce69a59e4460bae038ce3a803c50ef44288d215c93d307a56b7b74628ca5ad1633e892f290797ea734af1442371ce28a612b02bf07767ed544a8cfa67452cc005dc4f0056d82ce781c390001e0f3d28769e9a4cad247ea0f18cd329bff30ed120503f2f914a527e0d22d6f32dc2c90a86591c61c96e09c75ce294cf025bc8d1965660c0e54f6adb756ff8558c46df20fcd8ea6b0cca0c84ae307b0ed4a0bf5031a45756a9123232c4db8704648e39e7b8acfa85f7e35024a000bf919470697edaf71fb535049d86c5480001c1ef9aae2afb6a6dad9929b6a0039e2afb6a6da00d76b7e96b6ad1ac23d563f9bc8acdbb3cf424d576d7a06292490ec22d15684b455a60822d15684b455a4046a13515a84d40036a1919a2119a9b698020b83564da09c827c55f6d4db480f5628ca925f18ed5aade690aafcc303835940f6a2c64826b2d58cd21d8364e0f143e26f2b83e7bf9af37d78ce4026b3433dd4b54bbbfd897121611f403819f3f5ac279c71cf9a330cf3e6abb6b718a8aa426db76cd36739505598f800d56ea55dbe901c0e45511886c9a92a83f3679a55db00276e1481823af3d6a3c8eea109f941e055b6d4db5a112dcac720665c8adcae19fd4e338c0ac38ab6e60739a4e36346ab99774782a483d4560900672546078a36ee77739aa95cf3445503e81db536d176d4db5a102db536d176d4db4002db536d176d4db4002db536d176d4db4003031445a9b6a018a0022d15684b455a4046a1919a2919af36d000b6d4db45db536d000b6d4db45db536d000b6d7a06289b6a6da0652a55f6d4db4003db5e6da2eda9b68005b6bd23344db536d000b6d4db45db536d0205b6a6da2eda9b68005b6a6da2eda9b68005b6a6da2eda9b68005b6a6da2eda9b68005b6a6da2eda9b68005b6a6da2eda9b68005b6a6da2eda9b6800606288b536d7a062803fffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003011100021101031101ffc4001500010100000000000000000000000000000008ffc40014100100000000000000000000000000000000ffc400160101010100000000000000000000000000000304ffc40014110100000000000000000000000000000000ffda000c03010002110311003f00a6d16900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001fffd9",
        }),
    },
    Synthwave = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc00011080200020003012200021101031101ffc4001c0000020301010101000000000000000000000401020305060708ffc400551000010204030404080909050605050100010211000304210512311341516106152271143255819194d1d30716234252535493a124334392b1c1d2e1f062668295a21725357273a3636483b2f108345674b3e2ffc4001b01010101010101010100000000000000000001020304050607ffc4003d110002010104080405030402010403000000011102031221910413315161d1e1f0415271a105142232815382b10642c1f1156423165462724363d2ffda000c03010002110311003f00fc8ad0344b40d1f720e904340d12d17509791397367be67d39342041994b1d41ee81a25a06840821a068b340d082c15681a2cdca06e5081055a2c65284b130f8a4b081b940d6684082ad03459b940dca1020ab40d166e5037284082ad03432ba39d2e9255529204a9a4849cd7b6b68c72c20414681a1e34f213852679524ce5cc6002ae001bc429961020a340d17cb065840828d0345f2c1961020a340d17cb065840828d03430952053aa599292b2410b7b8e51965840828d0345f2c1961020a340d17cb065840828d0345f2c1961020a340d17cb065840828d0345f2c1961020a340d17cb065840828d0345f2c1961020a340d17cb065840828d0345f2c1961020a340d17cb10d081055a068b346d2e4cb5c99ab5cf4a14800a504175f742040bb40d16681b9420415681a2cdca06e5081055a068b37281b9420415681a2cd03420415681a25a06841208681a25a06840821a0689681a10207f0a9587cec569e562b51329a894b69b365a732923bbff9ee319d722925d7cf4504e5cea54ac895326272a9497b1237462d0347483705608bb7281a2c160a40d176896840828d03728bb40d081051b940d17689cb082c14681a2f9625a1020cda0cb1a340d0810679625a34cb06584160cda06e51ae5832c2041965e51644b2b5a5019d4583961e98d32c1979420b74b5651cca2ad9d4938a15324aca1465ac2d248e0458c619636cbca0cb081747eab0da09380d1d7c9c4e5ceaa9ca2265301da96071feaef68e565e51b65832c205d32cbca0cb1b658324582dd31cb0658df24192102e9865832c6f920c908174c32c19637c9064840ba61960cb1be48324205d30cb0658df24192102e9865832c6f920c908174c32c19636c90658412e945a648952f21595b1ce140000bd9b8d9a33cbca36cb065840ba63960cb1b65832c48174c72c4658db2f2832c20418b7281a35cb06584120c9a068d32c1961020cb2c0d1a340d082419b40d1a34465840833681b94699621a1020a37281a2ed034209066d0468d10d08105208bb40dca1020a40d16681a10482cd12d1dbe8d7472b7a55d21a7c130f9b4d26a2a1f2aaa66644060e6fa936d002639d574b328eb67d24d2854c933152d465ac2d2482c588b11cc474c260d8ab40d1a6583288b05828d03468c2061c2100a347426e2626e034d84f575123c1e74c9de16894d3e666006552dee9196c1ace61261c225b9420b052068bb44e584160cda272c68c23bb4359d1c95d11c568ab7049d518e4e9b295455e9a829453a013b44997a2b30dffb1af1a079f6112dca2edca272c582c19b7281a35cb03420b06796272887f0da6a1aac46548c46bfabe994f9ea36466e4b123b22e5cb0f3c2b978420b067960cb1ae58184582c19e5832c6ad1e96b30ce88cbe8061d88d1f48a7cfe934da85a2ab0b55214cb912866cab1374512c9b7f68e8d78f010796cb0658d72c4e58b05832cb0658d7288961082c1965832c6ad065e5081068b5521c3a54a452ad354998a52e719ae95a48195212d6620ddeefca16cb1b65e5065e5081063960cb1b65e5065e5082c18e5832c6d979419794204196588cb1d75d6502ba3b2b0e4e112d15a8a854d557098732d043097974606ef1cecbca09120c72c19635cbca06e5081063960cb1b3088ca21020c72c19636cb1196104831cb0658d72f281a104831cb0658d5a0cb0810639444658db2c465e51209064d10dca356832c209076a8a5744c744b10995f3ebd58f2940524a952c092800872b5137704d98336f78f3ec235cb06588a9241d0c228f04a9a6c4d78be2b36866c9a62ba342241982a27386413f3436f8e4b46adca21845824193411a6588684083381a3ad80e172f1ae90d06153abe461d2eae72652aaaa0f625025b31febd1063d85cac17a455f84c9af9188cba49ca949aaa7ba26805b30febd313c60873a6cf54d91224995292248290a420254a724f68fce376beeb474ea7a2d8cd2f44a8ba553e9529c2ab67ae9e4cdda24952d22fd9771bfd0793f298708b15acca4ca2b514249504bd812ce5bcc3d02104830681a34ca20cb081066d10d1a340d160905c71103459a068e906e08681a2cd0f6195fd5b54b9fe0549599a52e56ceaa5ed123324a7300fe30770771021020e7b44b45a084160ab0896e516689684160ab40d17681a2c160ab44b459a25a10582ad0345b2c59a105828d12d17023af3f1adbf45a8f02eaca297e0d3d73fc2d12da7cccc00caa5",
            "6f01bf01c2240838cd0345f2c4b458350532c4e58be589cb082c1468968bb081a2c160a6589cb17cb1396105833cb12d17cb12c21020a04de3d16369e88fc5ae8f750f87f5c6c6675b78436cf699fb1b36dd95ff000def1cac3ead7876274b5f2e4c99cba69a89c9973d19e5aca482ca4ef05ae21de91e393fa4dd23acc72a68e8e8e755a8295268e56ca525801d94eed2fc4b98cba5c88c4e2e5832c6997941963505829960cb1a65832984160cf2c19634631d5c6b1dadc77c07c325534bf02a64d2cbd84912dd29d0a9b531219219c5cb0658d72c4658b020cf2c4346adca21b942041a51cf4d255a2a154b22a825fe4a78250a70d70083cf585ca79468d78e96258bcdc4e830ca3994949213874834e85c89210b9a0acab34c23c653a887e11231241c8cb119635cb11962c083368868d1a061082419344658d72c465890483268edf4687467ace6fc6bf0ff0002f079bb3f01cb9f6b97b0f9b73fe2db9e390d10d074ca832d14203db48ab46b9637a1a29b886234d412552d336a26a652153660968054586651b245ee4d84209024d03474717c2aa305c6ab309ab5c8993e926aa4ad5226a66cb241639549b1108e5890483368868edd5f47ea28fa338763cbada29926be64c968912e7854f96505895a3e682f68e3b4163b0866d03468d10d160419b40d1768d694531ac922b553534b9d3b55494852c21fb59412012cece4448240b34434335429456ce144a9aaa6cead92a72425650fd9cc012016676263168410a340d176886840828d03459a0684120b344b459a068eb06a08681a2cd12d082c146e512d1689684160ab44b459a25a105828dca25a2d12d082c1d1c2fa3f8d6354f5f5184e19515b2b0ea735554b9282a12650d56ae03d8784735a1da3c4711c3e554caa0afa9a5455ca3227a64cd5204e964b942803da4db4368ec74530de8ce23555a8e93633370c952e994b92a972f36798341a1f46fd1c465fd32d8d98b3cdb44b45daf681a3706a0ab40d17cb12d082c15098968b344b0841a828d13962ed16cb082c19e58968bb0896e5082c14cb0d5752a29aa112e59510654b997e2a4051fdb0f6178953e1d5949513707a4acf079a99844d2bf94653b1014cdbb48f63f08fd34a0e94f496456cae8d53532514b2d2f314a2b5b8cf7282916ccc2da0f30c39bc946065ccc41f37cbca25a352c5448484b9d06e8d51495330b4ba798a390cdeca09ec0d55dd6378e90748166866829a4556254d4d55569a391366a5132a1692a12924805440b9005da3263c2258c20b0753a4f85e1b83f4a2bf0dc1f16462f432266595592c309a1bd16d1c58b38b471f2c69960cb1153082a7033cb1d0a1c47c068f10a6eafa3a9f0d9224ed2a25675c8650566965fb2ab33f024429958b41962dd917472828f0ca8a2c466d762be053e4490ba593b054cf0a999802871647649539b59b7c73b2c6b960cb08174cb2c19634cb065840832cb0346b94c4318408326832f28d5b9443084120cb2c4346b96232c209064d03468dca06112090639621a3b78a746b1ec170fc36bf15c2aa68a971395b6a39b3a594a67a2dda49de1883dc4718e434163b091266d1dec63a33d53d1ec1b17eb8c3eb3ace5a97e0f4f3734c90c7458dded046e8e23080888e97e065a31681a34688298b048332221a34cb10d082419b44346a5315cb1209066d10d1a341082419b44343127622a259a84ad52730ce1040514bdd9f7b4378e2b07998f574ce8fc9aa93852a6a8d2cbab5054d4cb7b0511678463048396d10dca3468884120a340d17688684120a340d16681a10482d9625a2cd12dca3a41b82ad03728b3186b0fa15e2389d2d04b9b264aea66a64a664f5e49682a203a95b807b984416051a272c74b1bc2676078f5760f3ea69aaa6d1ce54954ea599b494b20b3a55bc421960b1c4a915681a2ec625a2c160a318968be531396105828d12c62ed0f5362788526195b86d3cfc9495d936f2f224e7c85d3721c31e0d08dc5839ed12d17cb12d160d415cb12d17cb1396106a0a34484c5c26272c20b051a25a34cb1396105833098de7ae54d520c9a74c809425242544e6501755f89bb6915cb1394c20d5d3368d262e64e585cc515282425cf00180f4011394c4e58b05ba66d1d5c3fa418ee15357330ec5aae996ba6551132e691f20af1a5f249725a39f97944e5311d29ed2dd933cb0658d32989088b05833cb0cd0564fc3713a5c4694a44fa59a99d2cad2140292410e0d8871a18cb2f289cbca174b746f1ac5ab31fc76b71ac44cb555d6cd54e9a65cb084e626ec91611cf68d72c4e53c222a630415318231681a36ca7844658b02e993474f08c0312c73c33aba409be072155335d612c81a9beb08e5e516495a3364529398652c59c7088d38c08e9718186588cb1ae588cb1604053538a8a9972153e5c80b2c664d24253ccb025bcd18e58db2988cbca104ba6396068d72f288cb082419344346b94c465e5120903736b71bc6850e1d3aaeb71114e9d8d253aa62e6ecd3f465a6ec2da0e11cd68610572d6264b5290a4970a496222996174cdd312988cbca36cb1dbe8f62181e1dd65d7780f5b6de9172a9be5ccbf079a7c5996d5b84478232d408e13d1fc5f1cc4e930fc36826cf9f56b12e50ca42493fda36039c76fa77d0dc6fa35d2c9f4159459b3213365cca74954b98821b32481c410c40368e0d2e278950cf933a8ebea29e6485054b54b9853908b822f68eb74afa498ce37d25a9c42af179d553266519d33192c122c026c07211cdaaaf2dc61aaaf703cb1110d1a9115298e90583b78a74",
            "93acfa2982e03d4d8752f55ed3f2b912b2cea9ce5fe515bda3cf346b94c4a65a96b4a121d4a2c07131152919bb060d10c6365cb5216a4292ca49620ee315ca62c120c9a068d1a21a104833cb10d1a34434209066dca068bb40c624120cda068bb7288684120db2c19636cb0658d9e8b865922427946b97944e5816e053ccf07aa953f652e6ecd61792625d2a62ec46f10d6315fd6f8cd5625e094f47e10b2bd8d3a72a11dc216cb139625d5325b98c996589cb1ae589cb1a2dd32cb13963a94182e238951e2157454fb591874913ea559d29d9a0a825d89737500c1cde1ec5ba3f4d86601826272b1ec3ebe6e272e64c99494cb266d194a982668dc4ea3b8f22732a60b0a60f3d96272c6b962d963506ee1884f28b658d72458239420b70c426272c6c111608e5160d5c31cb139236088b04f281ab861922c11ca36cb121102dc31c91d5e8fe21478463526babb07a7c5e420281a5a824214e0806dc358482227241d32a195d9ca832580b98a52658960924243b0e41e345524f453cba95c89899134a9289852425643380742ce1fbc45b2728d09599699656a28492425ec1f5841ab856897269ebe9e7d452a6aa4cb9895ae42945226a41729245c38b46f8b54525763157594387a30ea69d354b974a8515a64a4e8904dcb463920c9ca118c97578c98648eb7472af09c37a4b415d8e613d6d87499a153e8f6865ed53c1c7a5b7b34239227241a95057672a02b154f3abea275252f82d3ae62952e4672bd9249b2731b961673ac619218c90648b05b82f920c9ca3af84e098a639894bc3b07c3e7d7d64c04a64c8415a8801cd8721092e4aa5ad485a0a5492c410c41861302ea9815c9ca0c9ca19c90648416e0b64832431920c9081705b24464867244648412e0be488c90ce488c90825c29509a42891e0c89a9509636bb45020adcdd2c03066b172ef1814433922b93944833705b24464867244648b04b82c51ca2b921a28e5152989066e17384627d53d6fd5d53d5db4d8f856c95b2cfae5ceccfc9e12cb1dd38fe39f16be2df5a54f53edbc23c0f39d9ed3e934724a2229f13371f88be58a94f2864a3945724525c17cb1053ca18288a9444833705f2c7b1e83f44e971ee9349a5abc4a54b948419d924ac1993086ec87f49d6c0c795cb1d8ad4e3786d6e19d6f475342b93225ae9c2e9f60b54924a92a160540b965177e368e7689b514b8673ae86d4219e99f4669f03e93d751d3625267cb47ca04ad604c4b87c840de3fa68f29963b98dd2d1caaa913e93144e206aa48a89a528524c998a24996a7d48b39e71c9cbca1669dd52e494d0eea930cb119637cb11963a16e186588cb1be588cb10cdc30cbca232c6f92232f2812e1865832c6d960cb025c36cb065e51b6589cb1a3d770c72c4e58db2c197940b74cb2c4e58db2c4e5816e18e489cb1b6589cb14b70c826272c6a131609841ab86596242635098b04420d2a0c72c582235088b0440d2a0c4262c111b0444844534a8320889088d8222c11034a8310889088d8222c110834a8310889c91b0445b24583570c727289088df24484420b70c0239448446f93944e481ab8619227246f923ad5582c8a7e8e61f8b2317a39f3aae64c42e8a5a899d2025994b1a00add11b483a528939d4136869fc27c370ef0dda4854b95f2c65ec6616cb32de335fb26c5e14c9ca18c9ca0c9160bab36c2b14c5302c4a5e2383d7cfa0ac96084ce90b28500431b8e46135e798b52d6a2a528b92a2e498df24192118c9756a6605b2419219c91a48d922a652e7ca33652540ae5a5594a92f700b167e2d081704b27288c9ca1b5a5256a28494a492c09761df15c9ca102e0b6488c90ce488c90825c16c91051ca19c91193942097058a220a2192888288419b82a5110511e87a3923a3937194a3a53515d4f87196b2574284aa667ca7259566767fe8c718a2f6d233e3066ee302a5110510c94441445825c15288828864a22a51032e8162888298672454a2065d04cc461dd572767e13e1fb456d7365d96461972ef77777b690a65860a22a51120c5c17cb0d57e23896293254dc4abea2b57265264cb5544d54c28969f1501cd92370d22851152884223a05ca6232431962b979420cdc30298ae48632c4658419b82f96232c3196232c425c3b34b8e619498150d2a3a33473b12a5ad354bad9ea52c4f96cc24ae5e995effd18e154ccf08aa9b3f652e4ed1657b3949ca94b9760370117cbca232c655296263569186588cb1be588cb1a2dd36cb139635cb13979468f55d32cb139635cb139605ba65962427946b96272c0d5d32cb16098d426272c20b70cb245826350989098a6950641316098d42394582606950621316098d4222c11034a832088b0446a1116088b06950621116088d8222c110836a831088b0446c1112110834a8320889088d8222c11160d2a0c42227246e111392106ae1864e51392180889c9083570c3244e48df247b9c0fe097a718e2d397065e1d24a8a153b10f9009212fe2919c836008490e7916f3691a55868b4dfb7ad52b8b83355da14d4e0f9fe489c91fa0306ffe9e53f2137a41d22fa5b6a7a195df972cd5f98974711ce3d9e1ff00025f07d454ea95534153892ca8a84da9aa5a54030ec8d9e40d67d1ee6fa47e6348feb0f8658b8a6a75ff00f55ce0f2d5a5d8d3b313f266483247eda91d06e84d3d34aa797d13c2148949084999472d6a2006ba940951e649277c5a6743fa132a52a6cce89e08942015294682530037f8b1f27ff5d68edc2b1ab3470f9fa3ca7e23c90648fdb92fa21d099b2c4c97d13c114955c114",
            "12bf862df133a17ffe2382ff0097cafe183feb9b04e1d8559a1f3f4794fc439223247eb8adf816f83baaa35c89184cea198a669f22aa615a2ef60b2a4df4b83af1bc790c5fff00a7aa15e75e03d229d25a51cb26b650999e65d9d68cb9526c3c5245cdf48fa9a3ff0058fc32d5c54eaa3d57ff00cc9da9d32c6adb81f9db2728bc8a713ea65493365c9131412664c24250e59cb02587747d171cf81ce9c60a854d4e1c8c524a5214a9987accd2095365c840593a1b24863ad8b7829f4d3a9aa2653d4495c99d29451325cc494a90a058820dc107747e9f46d3347d2e9bda3da2a970727ae9bb5afa1c8b54538915336489b2e70428a44c96494ad8b38700b1ee8c727286b2441447ae0d5c15c910510c944414420cdc15288828864a220a21066e0ae48a94477f0caac26970fc524e2184786d4544808a59db528f065e607330d6decde639051195b761ceecb6a058a22a510c94454a22c0b82c511528864a22a51032e817c91bd7c9a3456cc461f3a64fa60d91735010a360ee013bde0298730fc46a30cf0bf0797217e154eba65eda4a663254ce53981caab5942e232d3da8e7550f6a390531529864a62a51ca292e0b94c572c30531d7c0fa375dd20f0ff029b4b2fc069575733c227a653a13a84bea632da4a598a92a54b3cf944572c32511529e51609745ca7944658632c572c0970c32c4658df2c465819ba6196232c6f9794465812e9b6589cb1ae589cb14f55d32cb139635098b658a6ae18e58b04c6fb099b113b66ad995650b6b3f07e31196055499658b04c6a1312130834a832098b04c6a13160981a541904c5826350889088a695066110ed561b328e968aa173e44c4d5ca3352995302948198a5943e69b69c231088b04c219ab8f083108e516088d8262c13160daa0df0ac4abf05c4e5625864ff0007aa92f926654a99c149b2811a1319c89ca9299c912a52f6c8d9933101453705d2fa1b6a38988098b044485b4bab5330641112111b044582229d150621116088d8222c11160daa0c422242237088f6dd0ef837c67a5992a89f00c2ce61e193139b311664a1c155ecf61655dc3479b49d26c745b376b6f52a695dfe5f044aaed0af54e11e2e8e82aebead149414b3aaea263e49525056b53072c05cd813e68faef45fe02ebeab2d4f4aab3abe57d9699495ce3e30baee94fcd36cce091d931f5ae8e744ba3dd1690118450225ce29caba95f6e74cb07751b804a41ca192fa011dfcf1fcd3e27fd596f6d367a12b94ef7f7725eef8a3e55b69753c2cf0391d1ae877473a254e118361c89738a72ccaa99db9d32c1dd66e0129072864bdc011e8b3c2b9e273c7e16d9da5bd6ed2d6a7537e2f13e7549d4e6a19cfce0da42d9e0cf1cb5266e0ced39c429495a4a56029243106e0885f3c19e2ab225c184144b4044b484252180018089da7385b3c19e0ec9bc58b833b48369ce16cf06789a92dc19cf1c8c77a3d8174969052e398649ad969f10ac32e5dc1395619497ca1d8876630f6788cf1bb355d956abb36d35b1ac19552d3947c43a49f013b2a633fa2b884c9eb425d54d5ca4e65d89ecad20073d9001005c92a11f1ec5705c5304af55062d433a8ea12fd89a96cc1c8cc93a292e0b10e0b58c7ecfcf1cac6f00c13a454829b1ac3a4d6213e215865a2e09caa0ca4be50ec43b318fdc7c37fab349b06a8d2d5fa77ff007727de27d0b1d2aba70b4c51f8d4a220a23e9dd33f829c4fa3a89b88614b562785a12a99314c04ca7483f383f6831073246e51212047ce4a23fa6e89a65869967add1ea95fc7aaf03ebd0e9b457a96652292a2aa7a6452c8993e6a9f2cb9692a51df60231286d4475f0bc5312c1311462384d5cca4aa40213311a80431fc211999a62d4b98a2a5a8b926e498f5633c0972a9e028511528864a22a511603a058a22a510c94454a2218740b14454a219298a94c20c3a058a62a530c94454a62419740b14c54a619288bca909992a7a94ef2d19837fcc07ef88cc3a6044a794465860a62a53033705ca62b9618cb10530833705ca62b9618cb10530833745f2c4658632c414f2812e8be588cb1be588cb10cdd36cb139635cbca2c11ca347aee98e58b04c6b962427940b70ebcce92e2737a1f27a2ca127c0254e33d244bedbdecfc1c9e7cd8011c4098e96178775962b4f41e1326976cb08dacf565427bcc613a46c6a2649ce899914539e5974a98ea0ef119a5529b4bd4cd14514b74d3b76e62c1316098d724484728d9d950661312131a844582206950641316098d4222c1114daa0c8262e111a8445823940d2a0c8222c111a844582229b5419044582636083c22c11036a81bc3302c4f17915d3f0fa6db4ba0906a6a0e74a724b058aae43eba07308e48d420c5c220932aa1ce262111608e51b04728eacac02b66c944d44ec3c25690a01788d3a5401e20ac107910f19aeba28c6b697a9bba96d39f87d42687109158aa3a7ac12959b615292a96b3bb3004387bb3b1dee1c47d064fc30f4969e44b91230cc225499690842112262528480c0001760047931d1caff00afc37fcce9bde448e8e57fd7e1bfe674def23e6e9361a0694d3b7bb546f7d4c5565655fdd0cf61fed9fa55f60c2feea67bc89ff6cdd29fb0617f7533de47901d1caffafc37fcce9bde44fc5caffafc37fcca9bde4793fe2fe11e4a33ea67e5b47dc8f5ff00ed9ba53f60c2feea67bc891f0cbd2a3a50617f7533de4791f8b95ff5f877f99537bc8d646078ad3ccda53d6504a5b36646294e0fff00d21ff17f08f2519f51f2da3ee47d5f0ae93fc2562bd0face91d2e0386cca",
            "6921e5f656153024f6ca5256ea003e9c0ead1e48fc3274a86b4185fdd4cf791b6198f74da83a255f82c9c76844a98d914711a654c4051ed04af3ba411fb4b47939f83e315597c2710a29d93c5cf8ad3a9bb9e6472b3f867c365dfa288f0c7c0f2d868cafd7ad54c4e11b8f4dfed93a53f60c2feea67f1c1fed97a53f60c2feea67f1c793f8bb5ff5f877f99537bc83e2ed77d7e1dfe654def23aff00c5fc23c9467d4f67cae8fb91ebff00db274b254c0f87e1885a4bde4cc047fae2a7e197a524b9a1c2dffe94cfe38f315583e2f5b52ba9abada09d396d996bc4e9c92c187e93808c7e2ed7fd7e1dfe654def20be19f098c68a33ea4a745d1e314a4f59fed97a53f60c2feea67bc88ff6cbd29fb0617f7533de4793f8bb5df5f86ff99537bc83e2ed77d7e1bfe654def21ff17f08f2519f52fcae8fb91eb3fdb2f4a7ec185fdd4cf7911fed9ba53f60c2feea67bc8f27f172bfebb0dff32a6f7911f176bfebf0eff32a6f790ff8bf847928cfa93e5b47dc8f59fed9ba53f60c2feea67bc88ff6cdd2afb0617f7533de4792f8b95ff5f86ff99537bc883d1caffafc37fcce9bde43fe2fe11e4a33ea4f96d1f723d61f867e957d830afba99ef23c1631882716c40d6a70ca2c38a921265514b32e59237e5248059b4616767725f3d1caff00afc37fcce9bde441e8e57fd7e1bfe674def23d3a368df0fd16a75585da5bdcfa9aa6caca8734c23cf94454a23d01e8e57fd7e1bfe674def238e51ca3e9d169457f634fd0ddd4f60a94454a61a2886f0fa0a4abf0bf0bc45143b1a75cd979d055b65866961b42789b5a36f05262a4a952ce41445e9e993513c4b54f952010a39e69213604b581b9661cc88d0a22a506065d02a511528868a39450a3940cba058a22a530c9444094a5164a4a8f001e218740ba190b0a54b4cc03e6a9d8fa23d2e0dd20a6a0c0b14a1561126699c87ccf62ec9653b960ee188fdf1e7ca2206648500480a0c798d7f7473b4b355a8a8f3db68f4daa8a8c66a90b00269d129b7a49bfa498c4a618288a94728dc1ab902e531529864a394572409705ca61ec2b03c531cab5d26134532b27a25aa6a912c5c2121c9feb5d21728e51a489d534b30cca59f3242ca4a0aa5a8a49490c438dc458c469c6073aa871f4ed122863a474b1cc4a4e2f5f2eaa461547862512254932a9105285142424acbfce5339fe8c2652784465e51214c91d9e322f96232c3051ca232f28a2e8e093ca2763ca1ed8c5b63ca3cf7cfa3aa101262db1e50f6c7944893ca17cd6a44449e5161261e1262c24f28b7cd2b11112b944893ca1e1262c24f285f34ac4444ae5161261e127945849e516f9b5622224f28b8930f09316127942f9a5622224f28b093ca1e12794584985f36ac44849e516127943c24c5849e516f9b5622224c5c49e50f093ca2c24f285f36ac4cea67aeaa9e9242e449962965996954b96125633153a8ef37d630127943c24c692a5a51350b54b4cc09209429d95c8b107d0617e1605a74754a848e789316127947b11d25feed605ea7fce2c3a49fddbc0bd4ff9c793e66dff004fdd05457e5f73c7093ca2c24c7b11d24feede05ea7fce2df193fbb981fa9ff38bf336ff00a7ee8d2a2bf2fb9e3849e51224f28f643a467ffc7303f53fe713f18ffbb981fa9ff38bf316ff00a7ee8d5cb4f27b9e3b63ca27631ec7e317f77303f53fe713f18ffbb9827a9ff387cc5bfe9fba2dcb4f27b9e3b63ca2763ca3d8fc62feeee09ea7fce27e317f77704f53fe70f98b7fd3f745b969e4f73c6ec7944ec3947b1f8c5fdddc13d4ff009c4fc62feee609ea7fce1f316ffa7ee85cb4f27b9e3761ca2363ca3d9fc62feee609ea7fce23e317f77704f53fe70f98b7fd3f745b969e4f73c6ec79446c7947b3f8c5fdddc13d4ff9c47c62feeee09ea7fce1f316ff00a7ee8972d3c9ee78cd8c5a7528953952c4c44d092d9d0ec7b9e3d87c63feee609ea7fce20f48bfbb981fa9ff00387cc5bfe9fba3372d27edf74781c4b13c2b00c3978963099caa70a1290890015ad6a7601d868146e40ecf703b4999495f492310a039a96aa589d2ae09483f34b137497490fa831e33e1ab1e9b5f8a617870a0a7a1972e41a8526906ce5cd254529251c539557e0addbf0f82ae9ed0f46935382e2b4944ba6a99a99b2a7544913324c5290820e6b04e50e4b860956a4a5b8bd2eb554b5f893f3f57c5a9a34e7a2da24a9584f1dbb7d8f7664c54c9e51dbc2fe137a3b8e62b59478361186d44c9294cc1b5c38265a91a28a34558948399ae6ce23b07a49fddbc0fd4ff009c745a55b54a559fba3ed59d4ad69bd65152de9c9e28c9e515327947b63d24feede05ea7fce2657492519e813ba3b822251500b52689c81bc819af0f99b7fd3f745745694dd3c3193ca2a64c77311d8d4625513e9e4cb93296b252896829481c81259f56761bad099931eba6d1b49b34aca54c1cc3279454c98e9993ca2864f28b7ccbb139864f28a993ca3a664f28a193ca25f30ec4e6993ca040992579e52d52d4c466496370c7f08e9caa51367225998894145b3adf2a799678c4c9e512f9cdd92781cd3262a64f28e9193ca2a64c2f99762734c98a995ca3a464f28a193ca17ccbb139c64f28a995ca3a264f28832625f31a939a64c54c98e9193ca2a64c2f99d49ced8f288d8c744c9e515d97285f33aa39db1e51064f28e8ecb9446c625f33aa1fd97289d8f287849e513b28f0df3ebea8476516127943c24f289127942f9a5642225728b093ca1e12a2db1e50be695908895ca2c24c3c24f2891262df34ac84849e516127",
            "943c24c688a6cc0f69296e261ac34ecd252c4360424288b1d22c24f28f41518489586d2cff000996acefd9feb58f35d24c651d15c027e2e65cb9d3d2a12a9a5adf2ae6ab4761a0014adcecce1e32ad93527928d26c2ab2aadaf7d34ccfe19b893ca2e24f284fa2fd21a6e976142b2504a31094122b29e5a54d2d44a80209170aca4b3967624c77d5493259eda08df1b569389ecb07676f66ad6c9cd2f61ce127945c49e50e893ca2e24f28b7cf4ab111127945c49e50f093ca2c24f285f36ac44d14e56b4a0302a2c09200f393611eca4746ba31e0f2f6f8d0db6519f254cbcb99aece3478e3d260f5b5928cda6919d00e5273017f39e70c8e8ee29f65ff00b89f6c78b48b455b856b763d0f3dad14371acbb1e8750746fa27e593eb32fd9161d1be8a79655eb32fd91cb1d1dc53ec9ff713ed8b0e8f629f64ff00b89f6c79a3fec3cd1c7554febfba3a7f16fa2be583eb32fd9161d1ce8af960faccbf6472fe2fe29f64ff00b89f6c4fc5fc57ec9ff713ed8b1ff63dd0d553fafee8ea7c5ce8af960fac4bf6448e8ef45bcae7d625fb2399f17f15fb27fdc4fb60f8bf8afd97fd69f6c5bbff0063dd0d5d3fafee8ea7c5ce8b7960fac4bf644fc5de8b7960fac4bf6472fe2fe2bf64ff00b89f6c4fc5fc57ec9feb4fb63577fec7ba1729fd7f7474fe2f745bcae7d625fb227e2f745bcb07d625fb2397f17f15fb2ffad3ed89f8bf8afd97fee27db0bbff0063dd0b94ff00ee3dd1d31d1ee8bf960fac4bf644fc5ee8bf95cfac4bf6472fe2fe2bf65ffb89f6c33538254ae453269b0c54a988434d519c939d5c407b41afff007bcd1c9c5352a75cdcf8cd387ae3f8c246fe2f745fcae7d625fb223e2f745bcb07d625fb2399f17f15fb2ffad3ed83e2fe2bf65ff5a7db16effd8f7474b94ffee3dd1d3f8bdd16f2c1f5897ec83e2f745bcb07d625fb23cde172c635e15d54b9755e093954f3f22c7c9cc4921492e788f38622c418ed5661b8dd6ec36b45293b0949929d98968748d0963737d4de0e869c3b779a32e9d916f87aa19f8bbd16f2c1f5897ec8c2af06e88d1514eac9f8ca84a9282b591512ec05c9d3f1d0427f17f15fb27fad3ed8f8bfc31e3b5387ec7a3128a0a2ae9f6d5174ad246d126594a926ca065adc68cadf66971ed56ede47974db7a344d1eab776cea8f0518bf047ce3a6f8cd363bd30acaea19d366d10cb2e419ae1929480581d01566535bc6b80498f390411a6e5cb3f93dbdb556f6b55ad7b6a6de67b7f82aab934ff000938748aca9f07a3accf4f3d4e904a4a494804837ce946973a6f8fd4ff00177a28491d6eb0c5af3e58f45af1f89254d9b227cb9f226ae54d96a0b42d0a2952540b8208d088fb97c1a74bb10e93e258b51e2b512d752a58a990800a4250590a4824b25296430d5d44926e623a6aab0a6b74fa1faefe9dd329c343aaa74b6dc6ed9d3f327da4f46fa29e5957accbf6457e2d74509618ca9cff00e665fb23c62f1bc0a5d3e2550bc56984ac2d41158738264a88b06d4f0b3f6814ea1a3cb74f7a5cac13a314957806254e9acae32a64b7caa98242d25426042b47ca05c59c8b1d23b1b45ffe67ec7ebb48aecac2ceab5aada6ea98513bbf9c0fadaba33d141ae32a0f71f944bf6478ca9a334f50b92572e6642d9e5a8292ae6088f9ff00c1ff004f2bb1ee90556138d2d0a9b58a554532d3980428243ca02e0272a491a5c1724aa3e952c53d4a26ae96a64d40933152666ca605197312d992403621c58c77d1d5744baab754ef37f0db7b2d2ecf5b675ca6da87b6574c4e7193ca2a64f28e82fc1d355e066a64f85ecf6a64671b40876cd97567b3e8f0cd34ba14cba9f0c95394b32c89265900256faab88678f5bb483e8574a54ba929f438664f28a193ca3a664f28a993ca17caec4e6193ca2864f28e9993ca2864f2897cc3b139a64f28a9931d23279450c9e50be61d89cd3279454c9e51d23279454c9897cc3b139a64c54c9e51d23262a64f286b0c3b139a64c4195ca3a264c46caf716897ccbb239a64f288d947a4c76660f578aaa7605864cc3a8b22009132719a4280ed173c4ff5ba39464f288ad251ce9b375529b51c0e76c79446cb947476515d8f28b7c6a87f63ca2db2e50f093ca27651e0be7d7d508ecb947470a56194f3a7ab14a05d64b5485a65a51376792611d953ef00ee88127944895ca17c9568eaba5d2fdb011d8f28b0950f6ca244a8b7ceaac84849e516127943a25f28b0976768b7cbab4269924960924f28ba69d4559424bf08f25f091d271d1ee8ff0081d0d5ecb15adeca04b532e4cbf9d334b3b651a1b920ba63e6d5df0a7d31ada2974a9ad9548d2ccb99369e504ae6b8033125f29d4ba32b13dcdb4f79f9dd3be3ba26856aec6b4db496cfe3fc9f40c77e14703c16baa30aa7c2e7e215148a54b98b2a12d0660500520972c3b776d5219c1cc3e5bd34e952fa578e0a9972554f43213b3a79254e407bad41db31b3b6e005d9cf998232ea6f03f9d69bf18d2b4ca5d9d6e286e6173da7430ac6713c0ead5558555ae967a9210568009290a4a9afb9d21f88b1b1223d3f47fe12fa4383cc12eb6a26e2d48666d172ea2692b3d9232898a0480e52a6e29b3397f1104136b61e1b0d3748d1da7635b51c70cb61fa77a2dd20a6e956028c5a448f0656d152a6c8cc55b358bb6660ee929361bdb7477420708fce1d09e98cfe88e255134caf08a3a99644e9200054a48519642be6f68b137b13625a3ef743d21a3ade8627a50942fc18532aa664b45d4928073a03b39052a0f605b84744e4fea9f06f8d59e996095a3ffc",
            "94afabf1e3df89d508e513963ccf42fe17ba1f8be1d896138e608ba1c62aa6499586cd4ce54d054a5104164009f9baeafb99e3d9d32650a942a70f9349750fe5be2deda7d3d13e2563a65155760e5271ebf8dabf29646f478bd4d15309126549ca092e525c9e77863e3157fd548fd53ed8790ac2d490a08a600f14a41fc62dfeecfa34be84c785bb36e6ab3c4e355766db7559e221f18abfeae47ea9f6c5be3157fd5c8fd53ed8e9489587d44f449968a42b59ca1f2c41186a5452534ae2da260b55fa671d6d85eb9abc769cff008c55ff005523f54fb60f8c55ff005523f54fb63a00e19f4697d0989ff767d1a5f42635165fa65bd65fa673fe31577d548fd53ed89f8c55ff005523f54fb63a0f867d1a5f42607c33e8d2fa131a8b2fd325eb1fd310f8c55df5523f54fb627e30d7fd548fd53ed87ffdd9f4697d09897c33e8d2fa13162cbf4c97ac7f4ce7fc62affaa91faa7db07c62affaa91faa7db1d0ff00767d1a5f4260ff00767d0a5f4262c597e992f58fe9887c62affaa91faa7db07c62affaa91faa7db0ff00fbb3e8d2fa131b53d3d1554e126449a65cc20a9865d0024fe00c3ff17e991d76294bb339d231faa99512d138c893294a015332295903dcb0376e11c2e977c20d3f46b0cad9f3eaa954c8982992ea96ba922c320724124a6ec72bb98eee295f83e178455e233d34c25534a54d51080a600392c2e5b5b5e3f1362b89556318bd56295abcd3ea66198ab9212fa243925806003d80022ddb278aa20f8df15f88d9e85427451f555313b171dffe0f67d10f84cc4ba3031a99304cab9b894e9752467ca8da098f30b0b24a924b2868529b11a7dce93e193049d85d4574cad9326552892262a6a09513350149002097578c0817050a70c1e3f2e2eab0e3814aa44e1797104ce2b556ed94734b6608c9a06377d6108354d5f7293f25a27c6adf47a2e5495496c9fcf8eddaf25181fa3716f876a49cbc564e1c944d9526809933940a533a72949484896a6511da725c164ad86f3f05c6b1ec57a435a8adc62abc267a2589495e44a192092032401a931cc820924a1283cba67c4edf4b4a9adc2dcb05daf09908208229f30219a0afacc2f10938861f50ba7aa90acc8988d41fde0e841b1058c2d040b4d4e96aaa5c3432bafac9b22a24cda85cc4d4ce4d44e2bed2a64c48500a2a377edab7ddef05657d6620b92aaca85ce3224a29e5e6d112d0192903701fb493a930b41034eba9a86f008eb60dd21c5b02aca6a8a0ab584d3cedba642c954a2a292924a74729252fab1b111c98202ced2bb3a95743868ee747fa4b5f80749e5e3a852aaa6952b6e999315f94255e3051de4eae5ee0162d1fa7ca3947e448fd53d19c4918c74630fadf0c95573d54f2fc2172d493966e4495021364973a599e3a52cfdfff0048e94fff002d854f735ef3fe0e8940e11532c43196232c593fa0de1632c454ca86b2c4658cc8c050c9e514327943a53119625e62ea113279454cae50f14f28828e512f92e239e64f28a993ca3a3b31c22a65c4be4d5a39c6544193ca3a0654419512f99d51ce3262a65728e8995ca20c9e50be675473b65ca2bb1e51d212492c05cc42a414a8a48b82d0be675479ac33e11fa358be2b8761d47b59732bb3a4edc04190b0d912adc73ddb2a8df286bdbd8e420b111f91a3ef7d08f843c1a6f456548e90633b3c4a925accd5d486335093d9293f3ce520378c48363a9cd74cafa5627e47e0bfd46f48aeab2d31a4f6a7b17828f5f1cf61eff2f2832985308e91747f1e40384e294f52a292bd9a54d31290589282ca01db51bc718ed0920871a478ed2d1d9fdea0fd8d1a451694aae872b7ac4472f289ca7846b51514549b1f0aaa93236d304997b4584e759d121f527701731cec43a49d1dc2d73e5d7e33454f3642732e52e72768033f89e3124680072f68eb45fab65266bd228a14d6d2f56733a51d2ac2fa27878a8afcf32a26a55e0d4e805e7292ce3333240cc1c9dda026d1f37c6be186b578953afa3b49e0f49273674d5a52af08701b304dd394e66655ecfc23c974dfa5b37a5d8f0aa4cb5c8a2909d9d3c95289212ee54a0ec146cedb8017673e5e3d4be9c11fccbe29fd47a45adb55468d5c50a21adae38f17ed86f9e86338bd663b8d54e2d5ea41a8a85665644e5480000001c000071b5c931cf82081f92aebaaba9d75396f161041040c8410410011d5c27a458e6073652f0ac52a2984a9c9a84cb4a9e5ed010428a0ba546c3507411ca82055535b1979b3173a72e6cc5665ad454a3c49b98fb1f4efa6736afe0df009f4550b93558a2933a62e424a52954a62b4827b49226e5623e89bf1f8cc115383dfa2e9d69a3595ad951fdea3d31e52bf27bec27e153a4586747aa70d98bf0da957ff006f5950b2a5c97d5ddf3f27d0eae180fb8740f1ca7e92741e8f14ac9df962526554250b4925692c4900062ab29b7050dd1f9461c938ae234f8654e1926b66a686a5b6b4f99d0a20a4bb680ba1371760da45bcfc4fa9a07c7adf47abff00354eaa5284a72e538e1e88fda29a1a6524292b590438b8f645bc029fe92fd23d91f1ef838f84ec225747a8301c631014d554b2f64265424225a920ab280b160c9091da672cce63ea38763f87e2b2f6b41594f552c2f21994f304c485302c483adc7a443eada99fbed174ba74ab3569655ccad92a5707c51d1eafa7fa4bf48f644f8053fd25fa47b231aaaf93454d32a2a674b952e5a4ad4a59648003924e807330b48c7682a70d9388c9ada6994b3a609499c89a0a0a8ab28014ec6f6efb413ab89de6bde743abe9fe",
            "92fd23d913e014ff00497e91ec89da2b8884317c6e9303c366e21884f449a69492a5ad5a01fb492ec00b9368aaaab891d55ac5d43fd5f4ff00497e91ec83c029fe92fd23d918d257c9ada697514d3a5cd97310169520e64907420ef10c6d17c445bd57124d7bcaf8053fd25fa47b224504805c2e603de3d9122692480a0e0b18e357f4ab0ac371ba7c1eaabe9a556542332252e604a95da090cfbc9361a9bb6862aaaa7bc8eaa96daa0ed4da493316b9d3a74c2a512a5294479ce91e03a4bd3ee8e6028c82a44f9ebc3cd74a017d89ae404252a02e544966760092c05fd2f49f129d47d0ac6b10a39c94ce91453a64b5800e5504120b1b58b58c7e38a8abaaaad978554cd9fb196254bda2cab2206890fa01c3485f68f85f14f8ada7c3d536742c5ecdc8fa7f4f3e12697a47d0da2c370d0b9536a959eb652c3994124108721940a9885020b26e03911f2a8208e6ea753967e0f4cd36d74db4d6db3c612cbb9f5610410443c41041040041041001041040041041001041040047d9fe053164aa4e2780ad480a0a15728049cca04042dce8c1a5b0d6e75ddf188f69f05b57e0bf0998505546c25cf2b92b75e50bcc856549e2eacac38b6f684c627d7f83690f47d3acea5e2e33c3a9fa4f27288c9ca3a1b0e515d8728f33d2a93fb0eb51cfc9ca232c6f5f3e9f0dc3ea2bead7b391225aa62d4c4e54a4124b0be80c7c83e0c3a6b88637d30c4e9b1aaaceaae9626c8419b965ca282c512d078a54f6bb2092f731d68b4bf4ba91e3b6f88d958db59d855b6b98fc737823eaf92232f28c7a438ce1bd19c1a6e298a4ed9ca4765291754c56e4a46f27f99600986696ae92b70fa6aea65ed2454cb4cd96a0087490e0b1b8b1df1ce9b47525552a4f6d3a451557713c76c78c19e4e51193943322653d4a73489a89833290e92e01492142dbc10411b8885b18aea4c1306abc56b541322965998ab8055c121c80e4d80de4811876ad5571ac4d556d4d34dea9e0215389d1d263141854f2b4d4e2099aa90c974a8cb00a813b8b171bac77b3bb93947e679bd34c62b3a6545d26af9bb59f49312532e4fc90d98515194080ec42941cb963778fd3f493a9abb0ea7afa6999e9ea25a66cb5b11992a0e0b1b8b18ddb54a8883e37c2fe33469f55a2a708786f88e73ec2f94f088cbca1fd8bde14c4aa6461785d5e233c2952a964ae7ad2862a294a492ced7611e7a6dd5755da5627dc76c926df8196530643c235c3aaa8b16c36462387d422a2967a7322623423f71dc41b83631e63e10fa4c7a29d1954ea59884e2554ad9530500acbf497949b803910e52e18c6a9b4bd69abf138db69b656362edea7f4a53febd7c0f038ff00c2b26a6971bc3f0a336483925e1d572a5e5533fcaa964a9c387ca40043ee3a6d877c28e1d84f4170b9024785e2f265a64aa4250532d084282466513aaa5870466015a81a47c7e08f7c9fc9bff5069dacaad6f62d35e92e70e3e1e810410443e01b52d5d550d4a2aa8aa66d34f43e59b25650a4b862c45c58911f49e8d7c2de23856095187e292d75b311257e0b52a5198b54d249026e655d3701c10404b317b7cc2089b7067b744d3adf44aaf58d51fc6474f12c7b18c629a929f14c426d622933ec8ce39949cc4153ab556835259ad1cf9b366cf9f327cf9ab9b36628ad6b5a8a94a512e4927526290453cb5da5768e6b6dbe3c3041041040c0410410010410400410410010410400410410010410400474305c5276098f50e2d23395d2ce4cdca859415806e971a021c1e4639f040d515d5454aba76a3e9df09fd3d998d63430fc0f119a9c3a9e5aa4cd54898a4a6a14ab28162cb400000e37ab50418f2323a5789537466870490a2914588758499aa56632d600094a526c0039947572add77f3f0457536e4f75bfc42dedadaab67543ab7782dcb247e96c2fe16ba3b3ba3f4f5d89d6c9a0a899e3d36654f5a3b4b01f2a5ee10fa59c3f8c97f957c2974ca8fa598d51a30d589b45452c84cdd9a9056b5b1533dd804a45c02f9b50d1f3e8234eb6d41eed33e39a469761a8ad28c25f8b8f6db8e08fa0fc1d74f310c031fc3e82b2b7fdccbfc9d52d6c1328294a505b921bb4a39897ecf1ca96fb461ff09fd13aeca918c53c95a92a58150bd97642ca5c93604b3849399882447e56822d368e9c0d683f1dd2344b35650aa4b7ce1c1703ea927e16ab2917d26ada6952973710ad93329644e410108092952d59753951281198072e2ce23c0f4871fafe92e353315c44a04d5a52808979b24b480cc904961a9d7524ef8e4c1187537b4f9fa47c4349d228d5da5534ccc7196e7df23dbccf840ac9ff0006737a215885d4ad6b42513bb284c9948d9942580759ec29ddb75ceef1104106dbda79edf48b5b774bb5730a17a208208221e708208200208208008208200208208008208200208208008670fad9b86e294988c84a1536967227202c1292a4a810edbad0b410354d4e96aa5b51f76c27e1be9a61a8562740294aea64a6504ad5332cb3698b51cbf3589b07399200b154123e198a3a7b57475c8a597812264c952ea2595cc232be55ba5c28288dc078c2e58bfc2608c3b3a1b974a3efafea1d3a299a93873b36f07c3d20fa8fc26fc2349e92cb460d832d4ac3d2a4cc9b3d948db102c9092c728373985c80cd9413f34a4aa9f435b22b6957b39f4f313365ad81caa497058d8dc4630469249423e5e97a6dae956dafb478f0f0f43d7f4d3a7b88f4ca648973a426928e9d4552e4a6629649200751b051176b060a22f1e666d7d64fc3e9b0f9d50b994b4aa5aa4cb55c4b2b6c",
            "cdc8e505b4773bcc2d04539dbe956d6f5d5696b54bab6f7f83d1f457a5788746f1fa1ac15550aa392a099b4e164a552dd4e025c024675a8036cc5f798ed74f7e102b3a458c6234b86d529381ce4cb94251436d420e60bbb904ab78ca48097168f050448533e275a74fd228b07a35357d2dff00888f47e2823e8d43f0935745f05b33a3d2a7cd978a4b9a24c89e92429320dc90a2f74b1401d960a491e298f9cc10693da73d1b4bb5d19d4ec9c4a6bf0cfb9e15f0cf412f0fa4978ac89ab9c8a2067cc95da52e789997284e54a43a7b6eec01cbac7ce3a4bd3fe9074966d54b9f51b0c3e7d851a00ca94e64a83967517402fdecc0911e4e088a9a699696d3dda4fc674cd22cd59575e1e3184faef3ea7d0af8494f467a0b5743554fe17369aa10292509a9964a666652b73b24a49cddabad22c18c788e92f4a716e956208acc526200969cb2a4ca0532e58dec09372ce4924e9b80038704549298f1385b7c4748b6b0a746aaafa29f0dfba7d362f408208229f38f79d6f8f793318f427dcc1d6f8f793318f427dcc797eaba9fada3f5c93fc50755d4fd6d1fae49fe28ef71794fb1f316fbaaeff69ea3adf1ef26631e84fb983adf1ef26631e84fb98f2fd5753f5b47eb927f8a0eaba9fada3f5c93fc50b8bca3e62df755dfed3d475be3de4cc63d09f73075be3de4cc63d09f731e5faaea7eb68fd724ff00141d5753f5b47eb927f8a1717947cc5beeabbfda7a8eb7c7bc998c7a13ee60eb7c7bc998c7a13ee63cbf55d4fd6d1fae49fe283aaea7eb68fd724ff142e2f28f98b7dd577fb4f51d6f8f793318f427dcc1d6f8f793318f427dcc797eaba9fada3f5c93fc50755d4fd6d1fae49fe285c5e51f316fbaaeff0069ea3adf1ef26631e84fb983adf1ef26631e84fb98f2fd5753f5b47eb927f8a0eaba9fada3f5c93fc50b8bca3e62df755dfed3d475be3de4cc63d09f73075be3de4cc63d09f731e5faaea7eb68fd724ff141d5753f5b47eb927f8a1717947cc5beeabbfda7a8eb7c7bc998c7a13ee60eb7c7bc998c7a13ee63cbf55d4fd6d1fae49fe283aaea7eb68fd724ff00142e2f28f98b7dd577fb4f51d6f8f793318f427dcc1d6f8f793318f427dcc797eaba9fada3f5c93fc50755d4fd6d1fae49fe285c5e51f316fbaaeff69ea3adf1ef26631e84fb983adf1ef26631e84fb98f2fd5753f5b47eb927f8a0eaba9fada3f5c93fc50b8bca3e62df755dfed3d475be3de4cc63d09f73075be3de4cc63d09f731e5faaea7eb68fd724ff001448c26ad4592ba42589b55cad06bf3a1717947cc5beeabbfda7a7eb7c7bc998c7a13ee60eb7c7bc998c7a13ee63cd8c1ea72675cea44a6e07e5728b967fa4dc1fbe36ea89f2d5300552154a37cd572ac430dead092ec40d19ef1b5633fda3e66df755dfe0eff5b63de4bc63d09f731b26bf1d2a017438a25ca93aa0dc0b7e85989b3e9ac79f4e1b50264a12e652f69c4b06aa5581511f4896b78bda05d5bcc553413d32d0b13294897d9b55c9b3b38ba88bf6f5706fd90f1d558d0b16bbefbdcf98b7ff00e5dfe0f4a9c4b180c3abb163d9cce425cb8b8fcd6a0bb0b3fa01b1c5318015feedc4c909dc12cecd6f92dee0f1045c00f1e6461b55e289b48a52920208aa9473b100000abb40e51ad85eced11d5f51b30b4cda3b3839ab251007cd4a8e6ed1ec861e2db4b96eaa9a56ca7dbbef127cc5beeabbfc1ea06278c6703ab713202c0208468edf54c5d893761c43b442714c60dfab713d7784805b5fd13b117e2f60358f3270ea94d90aa652825929555ca75060732bb5a300c9d037eb1d5f392cb33a926210733aaae534f98fbdd5a0077eee0551629f297e62df755dfe0f4c314c5f2a4f5662843159242412012c0812b525ac340c78c5666298d264a88c3714528040b04bba81513f9ad478b1e71386d4266a1332652ac4b2674fcd5528e657d13daee17d0a8c63330eaa34680a9d4b9d7314b513592bb42c017cd7be6fc63352a61fd3df6ff91f316fbaaeff0007ad9989631b4584e1d890bcc48609f9bda07f35bfc51fbe2a714c5f2a8f5662803058202490090e0032b505ec750e78479ba8c3ea8aeb0a275305a6a3689fcae50290ea73e35af97f088561b50a9ab4cb994a813089d232d54a1955f4476bbc5b52911ba9533f6f7dafe09afb7dd577f83d2ab14c605fab713d7704901f4fd13b017e2f623489389e319c8eadc4c02b200011a3b7d53067045d8f12cd1e63abe729d627524b42ce674d5ca69131f732b4206eddc4a6018754aacb55325452ca4a6ae53a4313993dad18974e85ff0056453e52fcc5beeabbfc1e986298c109ff0076e26094ef096766bfc96e6278926c0868aab12c60b8eaec587673380970c2c3f35a92ce2ede903cd757d46ccad5368eec065ac94011f392939bb27b45c78b7d2c1e4e1b55e299b489525242c9aa943239208202bb20663a58dacef11d34bdb4fb77de24f98b7dd577f83d0aabf1d0a211438a298a53aa05c8bfe85981b3e9a463d6d8f792f18f427dcc70d5413d52d6b33294099d9bd5c9bb3b0b280b7634602dd92d16561b50664d132652f6584c02aa55c0501f4816bf8bd90193bc47276343d8bbefbdf7e62dff00f977f83b3d6f8f793318f427dcc1d6f8f793318f427dcc707aa27cc54b055481534db2d5cab92e372b4043b007567b462707a9c99d13a9149b03f95ca0c59fe93716ee8e4ec63fb47ccdbeeabbfc1e93adf1ef26631e84fb983adf1ef26631e84fb98f30709ab49652e901606f572b43a7ce88eaba9fada3f5c93fc518b8bca3e62df755dfed3d475be3",
            "de4cc63d09f73075be3de4cc63d09f731e5faaea7eb68fd724ff00141d5753f5b47eb927f8a1717947cc5beeabbfda7a8eb7c7bc998c7a13ee60eb7c7bc998c7a13ee63cbf55d4fd6d1fae49fe283aaea7eb68fd724ff142e2f28f98b7dd577fb4f51d6f8f793318f427dcc1d6f8f793318f427dcc797eaba9fada3f5c93fc50755d4fd6d1fae49fe285c5e51f316fbaaeff0069ea3adf1ef26631e84fb983adf1ef26631e84fb98f2fd5753f5b47eb927f8a0eaba9fada3f5c93fc50b8bca3e62df755dfed3d475be3de4cc63d09f73075be3de4cc63d09f731e5faaea7eb68fd724ff141d5753f5b47eb927f8a1717947cc5beeabbfda7a8eb7c7bc998c7a13ee60eb7c7bc998c7a13ee63cbf55d4fd6d1fae49fe283aaea7eb68fd724ff00142e2f28f98b7dd577fb4f51d6f8f793318f427dcc1d6f8f793318f427dcc797eaba9fada3f5c93fc50755d4fd6d1fae49fe285c5e51f316fbaaeff69ea3adf1ef26631e84fb983adf1ef26631e84fb98f2fd5753f5b47eb927f8a0eaba9fada3f5c93fc50b8bca3e62df755dfed3d475be3de4cc63d09f73075be3de4cc63d09f731e5faaea7eb68fd724ff00141d5753f5b47eb927f8a1717947cc5beeabbfda7a8eb7c7bc998c7a13ee60eb7c7bc998c7a13ee63cbf55d4fd6d1fae49fe283aaea7eb68fd724ff142e2f28f98b7dd577fb43a9f17f25d67dc2bd90753e2fe4bacfb857b2128224a3e7cd9ee79f41dea7c5fc9759f70af641d4f8bf92eb3ee15ec84a084a1367b9e7d077a9f17f25d67dc2bd90753e2fe4bacfb857b212821284d9ee79f41dea7c5fc9759f70af641d4f8bf92eb3ee15ec84a084a1367b9e7d077a9f17f25d67dc2bd90753e2fe4bacfb857b212821284d9ee79f41dea7c5fc9759f70af641d4f8bf92eb3ee15ec84a084a1367b9e7d077a9f17f25d67dc2bd90753e2fe4bacfb857b212821284d9ee79f41dea7c5fc9759f70af641d4f8bf92eb3ee15ec84a084a1367b9e7d077a9f17f25d67dc2bd90753e2fe4bacfb857b21554b521c2c84280f14eaeecdc8f7c5d484cb2a045c66b2ec4dd8586845cdcff003d409b3dcf3e831d4f8bf92ab3ee15ec8b8c131564a9787558048b090a25af766e5a16d442ebca952a5ac942580208bb8533e5160a67b1e77b88144a7289ac8505e62921c82e5d93a0d0383c06e8daa52da26cf73cfa0df5262812a4f55d567008fcd288705dc1b0d1c6f76e6234384e28b74f56550412545e42804be566ecee3ae548b03bb4e7afb27e53b2a032b2bb4ad1988d0311de1f7b458ab24d54c595216fa3bcc2733924fcd21b56074b5cc6d348b367b9e7d07baaf1556752f0cac026173f20b72ece1b52c58872d6e711d558a048cf85d59249514a64a8ebab5992e0f02414ee8415f26e89bd86b2a5a353e2b827769cd88d04133b08d9cdec90c0ca45ae01ba8f173a6ba8b5a0eaefbef81268dcf3e8740e158bb90ac32a96b2e5604a531621f32be73e57607521b840309c50a8a3abaa8a120bacd3a9b40094a5ae6daefb12cce109a421444e48cc08224a6c9471079b01cf897102c994b066b2e6807b04766597766d379ece837ef115d4bc7befb82cd9ee79f41eeabc54cb52d5865600b2028094a2b985dc925ac3f958b1302f0bc552b4ad58554ad797b32c48514cbe034bef2dc7572e21152954ea2a512aaa25c93732cff17ecefd217f9366929fcf5d3315f478a47ef3e6d358ea4b6f7d7f8f524d1b9e7d0e89c1f1533761e0156cb20ce9c64a8bef3bae072d48df6684e178a295b656135425c8004b9664a8e6bb806d7de4fa2ce239f3be412699365e934f12fe2f70b79f8da0a9f93c94a3f44f9bfe73e37a180f33ef83a9297bbb8fc6df52cd9ee79f41eeaac5c522d670dac54d9ea2144c953e50c786f2d7fecf388a9c27156932d38655a84b9603892abbbab86eccde684ab3b33f603492367e71e37fa9cf9e0adb57cf48d10b284f202c07a0089534935ba173f724d9ee79f43a9330ac5155f5e9eadaacb373b2b62a6b2b30ddbf2b79e31eaac5cd221630dac4cd90a01244953e52e786e2f7fed728c4dfa40b49d1750a42b982a208f4130bd1f6a7ec0e9386cfce7c5ff531f34746e6a8dedae5ee59a373cfa1d056178a255b64e135465cf044c9624a865bb902d6dc47a2ec62460f8a89bb0f00ab641264ce12541b78dd6079e84eebbf3a9be533d29fd2b65ff9c78be9723cefba093f2e914cabaf4947817f17b8dfcfc2f18554c3dfdc7e76fa89b3dcf3e83e8c2f1552d4b4e155285e5ed4b3214133388d2db8b71d18b083aaf1512d2b4e1958420909065282e59770416b8fe760e0c208fca72c957e7ac996afa5c127f71f369a4a54aa85052494d502e08b1987f8bf6f7ea552f0efaff3ea49a373cfa0f9c27140a08eaeaa08500cb14ea6d0805496b1bebbae43bb906158bb809c32a90b0c500ca530725b2abe6b667627505f84208266ac994c89a40ec01d9985dd9b4dc3b3a1ddb8412885a80929198924c955d2be00736279f02e62aa97877df7259b3dcf3e83dd558a149c985d58208504aa4a869a3d994c07004956f89eabc5539148c32b08965c7c82dc33b06d4397258b5f9473e5f6d1b395da25c094bbdc81749e2e34d7417bc09f94644aedbd932d7a8f19803bf5e4e4e8622abbefbe049a373cfa1d0184e28864f56551402141a4288536677ecef3a6649b11bb5cfa9314294a7aaeab39007e6940392ee4dc68c3733f230a85679a99882a5adf476980e67041f9c4beac4eb6b08aa3b47e4fb4a232b27b2ad1980d0b93de5b73c1b4f02cd9",
            "ee79f41938262aca5230eab2013632140b5aecdcf40fa18a753e2fe4aacfb857b23249254b32994b528b0018abb496053a11fd91fb0408caa5265a095a588000bb9533e5362a66b0e57b18c3a53d849b3dcf3e869d4f8bf92eb3ee15ec83a9f17f25d67dc2bd9182509985200b9cb645c8bb1b1d49b1b1fe544cb52d82085a88f146aeecdccf746204d9ee79f41aea7c5fc9759f70af641d4f8bf92eb3ee15ec84a08cca1367b9e7d077a9f17f25d67dc2bd90753e2fe4bacfb857b212821284d9ee79f41dea7c5fc9759f70af641d4f8bf92eb3ee15ec84a084a1367b9e7d077a9f17f25d67dc2bd90753e2fe4bacfb857b212821284d9ee79f41dea7c5fc9759f70af641d4f8bf92eb3ee15ec84a084a1367b9e7d077a9f17f25d67dc2bd90753e2fe4bacfb857b212821284d9ee79f41dea7c5fc9759f70af641d4f8bf92eb3ee15ec84a084a1367b9e7d077a9f17f25d67dc2bd90753e2fe4bacfb857b212821284d9ee79f41cdae11f61acf5a4fbb836b847d86b3d693eee1182124d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8460848d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8460848d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8460848d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8460848d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8504b538ce42038bab703705b566894a029360a2ec972c94a544d9cf70e5f845c46b6ae192e435b5c23ec359eb49f77173d549242e8aad04120855525c11b9b66e3842a9502a4843ba95697283163629737d19b5d7be212722659ce997705d175ea6fc9b838dddf1a486b6ae192e43a938385a14686af23053ccaa48043b1d25b90efa5ed1299b8584a08a0ac2920820d52129531cc43ecefbb9e9ca11018021094254c334cbea08240de1df71661bf500da28650a984000a965800c00ee63bc96d2349ee1adab864b90f05e16a065cba4ac5376494d4a12929cc1893b3d1cefe5019d84ab3265d1565c78b2ea52d97c6209d9b96e6fa6b61082d4951056b2b2c6c919425ee1bce4b86eed62cbcc014cc22507fcd245dfb4ce391b5cbb1df0bc35b570c9721d54ec212169f04aa4392324baa49de2c4ecee2d6b9d39bc4aa661484942e8aae5598a13529cc4f3f93e291626cee0422336ccae581265b94e626eab1b3f7162cc34782593b4c94c939c9b2d56218bb8fa3b9f836acf091adab864b90f09985212335155c9045c8aa495a87ddf0572040825ccc2b20578155c994f94ac55249362e07c9dec59830d1f8c73c2a5ca29525a6ad81b8ec837b36fddcac6c444a9196f50a515b14843f681160fc3bb5b6e70617bbeffc0d6d5c325c87a5cdc30cb39286aa5a41ed4c354970f667d9e9ad86b7d5ac226e16ea453d0566f0566a900e5240bfc9b247b48784bb538e65912a4824d85868e12379d3f79df100aa6b48928ca97259f5d6ea3c877017e7091adab864b90f09d84a16a954f4559314b64850a94b9e207c9e87d27939102a76112334b974954a5a832962a936e201d9fa4f9b4d512b4ca0b4493989b199a386b81c37df52385c1b23f26026abf3a47613f45c78c7872f4f074f7b86b6ae192e43bb4c2a9543f22abdbb5c78527e4ffedf8dfb3bf413330aa79699de0556262c3cbfca92e90ed9bf3762e081e736b473e4cb4a82e64c244b961cb6a4ee039fee04dda051995555648cf31402522c06e00701ba179ed5f8e635b570c9723a12666152a5aaa7c0aac149ca87aa4dd446a3e4f76afb8e582966614998a9e28aac1929ce3f2a49bb803f47c48fe7a4213d692532a517952dc24e99af7579ff00600374597f2542846a671da1e403a47e39bf08aaa878787f3fec6b6ae192e43b47330af0c96b4d1558d99da5ea926c9198fe8f9461b5c23ec359eb49f7718d2f65351346a8945bfc4424fe0a30bc61bfa52efbc06b6ae192e4756b66615d61539a8aac9daa9c8aa48de7ff000e0ac99857864c5aa8aaced0ed2d5491650cc3f47ce12aeff89557fd557ed305576934f34eab941ffc24a47e0911bade352e235b570c9721daa99852a62679a2ab2672739fca922ee41fd1f107f96904e99854d969a9f02ab25472adaa936501a9f93dfabef39a1247cad0ad1a1927683982c93f8e5fc62b21690552a6969531828eb96f6579bf61237c1d52f1f1fe7fd8d6d5c325c87d5330aa896a9de055666203ccfca92ea0ed9bf3772e403e637bc1b4c2aa947f22abdbb5878527e53fedf8dfb7bf5e7a4cca5aaba46796a21493707710788dd04e9694844c96499730387d41de0f3fdc41b3c4bcf6bfcf3eff00c8d6d5c325c87c4ec227e5973292a92b4864acd526fc013b3f41f369a067612b5a655451564b521d2546a52e3803f27a0f48e6c0426bfca419a9fce81db4fd261e30e3cfd3c5aa1699a1089c72916133560d6078eebea071b009ef78d6d5c325c8797370b74a2a282b3700b15482728245be4d943d803c1326e18258cf43553124f6660aa4b96b33ecf4d2c74b68f744954a791391992e0b3e9a5d2798ef06dca27b524e6411364920dc58eac14371d7f71df091adab864b90f4c9985642af02ab9d29f2859aa4822c181f93b5833171ab7180ccc2968ecd155ceec8d6a939936bfe8ee004f3007026104a335e9d4a0b609287ed126c5b8f76b7dec4c4154b9a54a534a5b1361d926d66ddbf95c58085eefbff00235b570c9723a0999852d2108a2ab9b6608554a7303cbe4f8a8d81bb3911099d8428213e0954b62064995491bcd81d",
            "9d85ef71af2784a613b4c952939c1bad3725cbb9fa5bdb8beacd01cdb30b9804e96e13981ba6c2cfdc183b8d5a1235b570c9721d13b094e54cca2acb0f16654a5b2f8c003b370fc9b5d6e602bc2d204b99495897ec82aa942921398b90767a38ddce124662026591343fe6942efd9761ccdac5d86e8aa14949250b282c2ca19829ae5fce0306efd21786b6ae192e43ea9b8594ac9a0ac09000005521494b9cc03ecedbf9ebce2147072b5a850d5e462a797549200761acb701db5bde122366a3982a592080a417043107bdcef05b58087049425694b8cd2eda0001237076dc1dcefd0def1adab864b90d8eaa510114556b2480026a92e49dcdb373c229b5c23ec359eb49f770ba8e74cc39d332e4baecbd45f9bf073bfbe254a014a0b774aaf2e6872c2c12e2fa3be9a77465a1adab864b91bed708fb0d67ad27ddc1b5c23ec359eb49f770aa90129b850674b865254a06ec7b8f3fc620cb539c842c39ba7781725b5668ce235b570c9721bdae11f61acf5a4fbb836b847d86b3d693eee1182248d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8460848d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8460848d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8460848d6d5c325c87b6b847d86b3d693eee0dae11f61acf5a4fbb8460848d6d5c325c87bc3a9bc8f47fad3bde41e1d4de47a3fd69def210781e332c9adab864b90ff008753791e8ff5a77bc83c3a9bc8f47fad3bde420f03c258d6d5c325c87fc3a9bc8f47fad3bde41e1d4de47a3fd69def2120851014cc0bb13605839bc48d9a48cca2bb82c9b38df73a1dda1f6dc4badab864b90e78753791e8ff005a77bc8b78548cb98e0d4603660eb9a1c3b5be52f785415a00f16494b2b31b28962411bfd16d1f8c55390ab2a10a9ab53048e64701adf4eed2f1a1adab864b90f0aba32b084e0f4b35449480854ebf023b6faee6fe529aea6458e174680487caa9a54c41763b4e06e1c6be8449ec90b981219272a2efd92c6d6efdf7ef813da6d9cb003e52a55c390d726c342470e368d27b86b6ae192e43a2b29c34d46094612962eb5cd2090cfaaefae9c224d6d2a94252709a69ca6ca8654e67cdb867720f9ae7d2829482accb5aa6a94e544712389d6faf76b78b3aca7e6c996b3dd627d24029e6cdc613e1df21adab864b90e8aea612fb585d1a014b6542a6ba83937699c40d6fa6b102b29d495197825184b00a2a5cd3767d73db42dbf75e100b9686284e6558bac586874f48bbb83a08b2d241267ac8500d94dd567001e0cc05efca179b1acab864b90eccaea32544e154b3564b9595ce6373c56e5ec5edbed165d648032cec2a8d197440335c166d3696f143bdf7de1013092532105218e97535ddcf712ecc2d0112e52994d3540e80f6776fdfbc59b9130bddf788d6d5c325c87935d259664e0d48843ea5735c58db367de1edbf8441aea29653b3c228d6b4924a899b94decc0aefe7e3a71486d2700a528042004e636091e6f39b5f53c60daa65bec4105ed30f8d62e08e1bb8e9ade17bbe4359570c9721f3574c1975184d2bb2484679d9943bf3dac3f659a2a9ae95310509c1e8f22466202a68167b9f94d6ede7684932d2965cf25297f1078c433f98697e7676882b5cdd9ca4a6c2c94246a4efe64ff5ba12fbda35b570c9721feb0a4933019185521524fe7334ee1b867b5defae9a41e134884954ec229012974a02e6b97d09edd86fe76e2e12797253f3664e7ef4a18fa14eddcdc5ed542573e6a8955fc65ad474e24984bd9df7db1adab864b90f0ae95513128183d19203019a68000ffd4b0d493de4c4af10a44054a938552149002959a70cddddb76f63f208cc9a92912a5022502f7d54789f66ef49332908128cf9a1d00e54a74ce7d837b711c5c25cc2cc6b2ae192e43c8aba5972b6d3307a304fe6c154d398bdc9057a6be7f3c513592a7cd6183d22d6a2492573bbc92769f8c73d731531656b2e4c6eb3e0f2552749cbb4c1f445884f7b873e61c44267d10d6be192e4373b10a47d8cac2a915250a2524aa75cd813e3ef616dd16975b4d2a9d551d534814a265a3b536f6ed7cfe040ff001728e6ca96674e4cb4900a8ea7403793c845aa26a664dec0225a465403b923f7ef3cc985f7f7beff00d0d6d5c325c86e5d5489b3132d18351952c84819e6dc9ffd48bd4e2148ba959461548b403950a2a9ce522c3e7f00214a739254f9e7e6a322799559bf5731f342cf11b6a98dfdf31adab864b91d615b4c9c3d64e134802e68ca334dbb02ff003f7661e98c3c3a9bc8f47fad3bde46338e5a4a540d141533ce5597f6247e30b3c2b6d42e1d46b6ae192e475ab6b698621520e1348a226aae5536f73fdb80d6d32b0f41184d21089a730cd36ce037cfdf94fa212ae3fef2aaff00aabfda609273525520e890999e70acbfb147f08db6efd4bd798d655c325c86e9b10a4454a0af0aa44209cab5054e709363f3f8131499552254c54b5e0d461482524679b623ff005239cf0cd41cf2a44f1f391915c8a6cdfab94f9e309b74c6eef90d6d5c325c876656d34da74d4754d21524896b754db5bb3f3f8023fc3ce2b2710a47d8cdc2a913256a05442a758dc03e3ee736df08d3cd4cb9bdb04cb50cab037a4fefde3981159b2cc99ca96a20949d46846e23918b7dfdebbff635b570c9721e5564a91358e0f4885a482085ceef041da7e3175d5d2cc95b69783d1923f3802a68ca5ec400bd34f3f9a1341f0892993ace45a58fa42e4a7bdcb8f38e023044c54b585a0b11098f4635af86",
            "4b91d2462148b09953b0aa4090084ab34e397bfb6eded7e460d74aa798a41c1e8c12188cd34820ff00ea5c6841ee22139a8419427ca0c8272a93ae43ec3b9f81e0e625cd48499534132897b6a93c47b37fa084b98798d655c325c87bc2691690a9384521212ea415cd70da91dbb8dfcafc1c9d61493a6133f0aa40a51fce669dc378cf7bb5f5d75841695c89a92157f190b49d781062cf2e727e6cb9cfdc95b9f4259fb9b835d2f677df686b6ae192e438aae952d010ac1e8f2286600aa69176b8f94d6cde668b0aba62eba7c2695d944a33cecc91df9ef63fb6cd1cf0b5cada4a526c6ca4286846fe447f5be2552d2a75c825497f10f8c033f9c6b7e576784bef68d6d5c325c87457514c2ada6114685a882140cdca2f770176f370d384aaba4b20cec1a91687d42e6b9b0b66cfb835b7708476a998db60497bcc1e35cb9278efe1aeb680ed2482a4a8142c14e6170a1e7f31bdf43c217bbe6359570c9721f45648232c9c2a8d79b541335c966d3697f18b35f7da2b2eba8c14918552ca582e16173985c705b86b97beeb42404b9aa64b4a513a13d9dfbf76e177e644066104267a0a830d6ca6b331ee019dc5e17bbef11adab864b90e9aca74a52666094652c424a57345d9f5cf7d43efdd68935d4c65f670ba358096cab54d748706cf33893a5f5d211424920c8592a21b28b2aec081c5dc8b5f9454ae5adcad395572e8163a9d3d02ccc06861798d655c325c8e826b69513321c269a4ac029512a9dabb17edb80ddff8c41aca72f357825194a9cba1734004bb68bb69a7084dd613f3674b41efb03e900957277e3154a9015990b54a5258a49e20711a5f4efd6d09f0ef90d6d5c325c87d55d4cbb0c2e8d6012d9953429800ce769c05839d3d306ae8c2ca1583d2ca5021242d53adc49edbebb9bf9a4aecbed25821f28526c1c06b1163a8278f1bc00f64044c0a0ca395766ec8737b776fb7741bde35b570c9721bf0a919730c1a8c86cc59734b076bfca5af15f0ea6f23d1feb4ef790aab205655a15296970a1cc0e074bebdfa5a2c4ad60f8b38a9d5985d40b0249dfe9b6adc63235b570c97218f0ea6f23d1feb4ef79078753791e8ff005a77bc84cecd44e55145c9655d86eb8d4eed07b20a140153380ce45c070e2f19c46b6ae192e43be1d4de47a3fd69def20f0ea6f23d1feb4ef79083c0f125935b570c9721ff000ea6f23d1feb4ef79078753791e8ff005a77bc841e0784b1adab864b90eed708fb1567ad27ddc592ac297a50563384b9ab40009d1cecd842a94a56bcb4e90ee582c5d88bbee60c6f6e3dd55a140833965c820376ac2c18e84386b1dd1b87b4bacab864b90e6d30509734958e43802a53abe87e4f85f7c584cc28a3b3875525241198d522ed73732f5d34fdf740175112a57d237ed166dfbac1eed0285c19b35cb6eed1160dcb80d6cda4246b6ae192e43cb9d839398d356cc5a8ba8f85277df532ee5ddfbb7c5c4dc2ce56a2aa92967cde1490e0f6497d9b9df60fbed1ce073132e4caf1cb0f9ca2e430fc3701a980875297366ba8dedda2a243fb1eef78b786b6ae192e43a2760a9293e0358bde52aaa481ae9697a37745f698619402a8ead12d9c3d52466f198b0977bb87dda5a39e26e424c94e4bb853ba85c117e4da86df019591f6aac843f659d4f7d46eb8df7be86227b86b6ae192e43a6760a1c2686b14e05cd52431b69f27de23454cc29442a7d256206e1e128700906c9d9dbc671a08e76d72ade4a766da17756ae0bf1d2e1a032b23ed559087ecb3a9efa8dd71bef7d0c59dc35b570c9721d4d46109040c3ea893bcd524b588fabe7f845d6ac28294a9f4b581649706a92544df5f93b5c5def7df1cf3359c4a4ecc5eeeea22fa9ee2d6607841b2ca8cd31591f44b768d9c16e1a5f9d9e248d6d5c325c8e826a30b2d2e561f5814aecf66a93994ee3eaf81661ac54ab064a5d54b5799ac94d520f0d4eced627ce34844cd671293b317bbba88bea7b8b5981e10094c80b98ac892094d9ca9ad61dfbf91d4868b32359570c9721f35185cd225a30fac0146d2d1549b972dfa373a9d5cc05782cb297a3aa98a04e64f85a5ac74712efe6e57e082a6f6724b4e445f7dd41dee77e8395b48132bb39e62b222dbaea0ed61bf43cadac26766235b570c9721fdae1b513424515628dd878520048b93fa360353c20db60b2fc5a2aa98549624d4a5924f0f93d5b7f7b6e3082e6e60512d39253b84bbee6b9dff00ccb33c0894e8da2d592582cece4f161bd85fff00910973862c6b6ae192e43e85e173e6a89a4ac7f196b555a6dc493b38054e1080d2a8ab01218abc292e5c071f9bd35ef04f1684264dcdd942724bb3241e0f73c4dcdf9ee168254aceea52b24b4f8ca676e4389e5fb9cc25cc53b46b6ae192e43f28e10b752a8eb112d3e32bc2925b90f93b9e5fb9cc41aac24ca12850d5a520b96aa4f68f13f27fd79cc23366e764a53925a7c54bbb733c4f3fdcc20952b3ba94ac92d3e3299db90e2797ee73127fb691adab864b90fa0e1065aa6ae8eb1281607c292ea3c07c9fa787a0189955854d502686ac0019291549648e03e4e119b373b2529c92d3e2a5ddb99e279fee6104995b5590559509054a536807f4c3991099fa691adab864b91d296bc225cbf08550d510e52849a949cca0cffa3d03837e56378c553f0a5a8a954758a512e49ab4924fddc273a6ed669504e440b210fe28dc3fad758244adb4e4cb2aca355299f2801c9f30060dcbbb48d6d5c325c8e989b84c8a70b145579a7a481f9525c25d9c1d9ef650ee7e30bed708fb1567ad27ddc2",
            "93e6eda72a604e51a252ef9400c07980104895b6a844acd9428b15378a379f30bc1bbceed235b570c9723a7366e132a44b91e0556e46d540552778b03f277b5c70cc617dae11f62acf5a4fbb8527cddb542e6e5ca145c25fc51b87985a0912b6f532a4e6cbb4584bb3b396854ef55148d6d5c325c8e9d5cdc2533f64aa2ab79494a08154901240b8fcdf17ef2e77c2fb5c23ec559eb49f770a4f9bb7a99b3b2e5da2ca99dd9cbc6712baa6a6d0d6d5c325c8ebd6cdc27ac2a735155956d54e455246f3ff00870524dc2553f649a2ab79a95200354921448b0fcdf16ee2c774215fff0012aaff00aabfda633913761532a765cdb358533b3b178e8ea8b597bc6b5f0c9721bdae11f62acf5a4fbb86254dc266c89923c0aadc0daa41aa4ee1703e4ed6b9e39447327cad854cd939b36cd652eccec5a09137635089b9730497297f186f1e7168c52eed50c6b6ae192e437b5c23ec559eb49f770c19b84cfa72b345579a42403f9525ca5d9c9d9ee748ee6e11cc9f2b6350b959b304960a6f186e3e7178244dd8ce4cc29cc34525db302188f382609dd776a1adab864b90e267e148505268eb12a05c11569041fbb8da62f08992fc21343540384ad22a5232a8bb7e8f42c4db9d85a39b3e56c672a585661aa54cd9810e0f9c110499bb29a14539d06cb43f8c378feb4d609c3bb50d6d5c325c87a5d561529448a1ab2086524d52594381f938959c204b4cd451d62906c4f8525d2781f93f471f48084e95b258015990a0149536a0ff004c798304a9bb32a053990b195697670efaeeb807cd098fa6a1adab864b90f0aac244a328d0d5a924b87aa4f64f11f27fd79844cd38421949a3ac5cb578aaf0a487e47e4ec797ee63084d959194956796af154ccfc8f03cbf7318254dc8e95273cb578c9767e6381e7fb9c427fb6a1adab864b90f9a9c2161a6d15612030578525c302c3f37a69dc00e0d02d785c89a92292b1fc642d3569bf020ece109b2b23292acf2d5e2a999f91e0797ee6304b9b97b2b4e79777493c5ae381b0bf2de2d165cc55b46b6ae192e43fb6c16678d45552ca52c08a94b288e3f27ab6fee7de60dae1b4f34a4d15624d9c78520850b11fa362343c2105ca646d10acf2c9676623838dce2ff00fc1811372808989cf29dca5db7358eefe41dda12e71c18d6d5c325c87c2f059854d47552d448ca9f0b4b5ce8e65dbcfcefc415185ca265af0fac2126f2d7549b170ffa371a0d18c20a95d9cf2d59d17dd74876b8dda8e57d604cdece4989ce8b6fba43bd8eed4f2be9098db80d6d5c325c8782b06525d34b5799ae95552071d0ecef603ce748b2aa30b0f2e6e1f58549ecf6aa93992cc3eaf80663a473cca7415cb5674800aacc52f6b8efdfcc684b4026ba528989ce84e976203b963e9d5c5cda131c06b2ae192e47410ac28a92a914b585608602a92140db4f93bdcd9af6dd14554610a001c3ea811bc55243d80fabe5f8c25b2cc8cd2d59db54b76859c96e1adf95da0135d84d4ed05aeeca02da1ee0d770384491adab864b91d14ccc2924aa452562c6f1e128720126e9d9dfc573a88cc4ec14b0550d62581b8aa49737d7e4fb842425676d92b392dd96653db41bee775eda0836b996f393b47d4bb2b5725f8eb72f16778d6d5c325c8e86d30c12884d1d5ae5b396aa49cbe2b9632ed760fbf4bc50cec154547c06b11bc253549235d2f2f46ef8484acedb256725bb2cca7b6837dceebdb41019b9c833939eee54eca3724df9bea5f7446f78d6d5c325c8e899b858ccf4555392cf9bc292580ec82fb371bac5b75a2889d8383985356cb5a4ba4f852775f512ec5d9bbf742203292b9535942f7ec94901fdad77b404e5225ce95e2163f35418971f8ef074116f0d6d5c325c87cccc2823b58755292001985522cf71712f5d75fdd6aed30529714958e03906a53abe83e4f85f742490cacf2a6b292c43f64bb396ee6e2e6d012ca026cafa26dd92cdbb75c35da248d6d5c325c8754ac291ad0563394b8ab41048d58ecd8c576b847d8ab3d693eee1542144932565c000bf66c6c5ce80396b9df16525285e5a848770e102ec059b731717bf1ef43da359570c9721e4e118ace64ccc32ae5242b315092a6009b9cad73a68d61a442707c5512829386562ca9b3a762b0353d9219ce80b8d212ed294555201b5ca8b28bf69f892789045c72813b20db2214bccc36a001ad8b69baee5bb5a59e3586dff00626cf73cfa0ef55e33373056115401751cb254804816b335afb9cb9e301c0f1108ec61f5931643b6c149cb60778bfce0dcb9b4248db95250a4670948196668949208bfcd049d6daf38809a7ec854c5391723c573a1d1ecf7b1d2dada60f6fb89b3dcf3e836ac2b192484e13568490d9532162ceeda5fcfc0448c1313413b5c36b0b16294495176237b371b87d21433276574002586999137486240cc2fc48ed6e3ce20a12849138645804003c6773a8dda335b71bef9809b3dcf3e83670bc672e54e15568490c42642efa6b6bdc03c1e0181e2a1399786d58716024289dfcad71bef77bc2aa524059a7504a013a96594e81fbc299870d37c67b298ea0505390b2b3598ded7df63688e3d44d9ee79f41f385e2e1c4ac26b258bdf62a2a22fa96e05acc0f08aa704c5ca4a8e19549038c955ec77372850aa5ca534b69841f1d42dbb41e9d75074119a94a51752892c05cee16111b5e226cf73cfa1d2eabc565b6c30aad041fce190acc6ee08b76741a5f5bc669c1718512061757604de4a87ee85552d329c4e27680b641a8b6f3ded6d6c748acc98a9874094bb8426c0683f70",
            "e715c7f709b3dcf3e8740e1189cb2a4cbc2aae616233aa9d4dbb40ddf73c74063356118cad654ac32b54a51724c95924fa214972b37696ac92eeea238358713716e7b85e033590512d3912400abb9535ee7bf7721a90f071e226cf73cfa1d0183e27218f55554c9a09b6c14529d470bf1e1def6c9584e32a2eac32b49602f257a0b0dd08a52a5a825292a512c000e498db32699472282e681e383641dedc4e97ef6dc6183e084d9ee79f41c460b89a02664dc2ead6e0912c4955f83dac35e76dce0c5178563330bab0cac3c06c1400bbd835b58e7c6a99694cb136692124f65235587bf70d6fc7ced253c121367b9e7d07656098a175cdc32b0213b84956651e02df8eef4031330bc666a81385558003252242d92380b4233262a6a812000032523448e02210854c5842039306d7db489b3dcf3e83d2f04c5e62c27ab2a9237a95254001e88bcec2f15594a25e155a2520324190ab9de4db53fcb7084a72d21e4492f25275fa67e91fdc377a49c60da4aea1367b9e7d07ba9b17f25567dc2bd91bcec271544b4d34bc32ad412732d424abb4a6d34d05c0f39df090fc9a4857e9a602003f35046be704f9afbc185e2b8a547889b3dcf3e83dd4f8bf92ab3ee15ec8dce118acaa34a13865595cd3996d255648361a717247fcb1cf912d3314a52c912e5a4ad4dab68079c903cf159b3153a72a6280054741a01b80e420a2953bc4d9ee79f41bea7c5fc9559f70af646f2708c565d34f99d59579d404b48d8a9c3dc916e01bfc51ca862a7e4c4ba61fa31995ff0039009ee6b06fecc29853509b3dcf3e86dd4f8bf92ab3ee15ec8de9308c553505670cab4e542c8264aac7296ddabb3738e543127b34553335cd9653779ccffe8fc616717a777f81367b9e7d0dba9f17f25567dc2bd90753e2fe4aacfb857b2118239e049b3dcf3e8756b708c5558854a9386559066a88224aaf73ca30ea7c5fc9559f70af64635fff0012aaff00aabfda6178e96917dfa966cf73cfa1d5abc2315554058c32ad5990824892ab9ca1f76aeefce30ea7c5fc9559f70af64633bb5454d334cb9a53771ccffebfc21785a45e9dff00e44d9ee79f43ab3b08c566534899d59579d20cb50d8a9cb5c136e05bfc318753e2fe4aacfb857b231a6f9413298fe90664ff00ce0123bdee1bfb50bc2a871509b3dcf3e87546118acda35215865585ca3990f255749371a716207fcd18753e2fe4aacfb857b21495315267266240252743a11bc1e462d3e5a65a92a41265cc485a5f56d08f310479a0e2a53b84d9ee79f43a12709c5572d54d330cab4851cc85192aeca9b4d343607cc77461d4d8bf92ab3ee15ec846183f94c92afd34b00103e7200d7cc00f35f713051528f11367b9e7d06e4e178aa0a91330aad3296194048558ee22da8fe5bcc5266098bcb594f5655286e5264a8823d11cf8da4ad25a44e2d25475fa07e90fde37fa0889a7f4b1367b9e7d06e5e178cca51230aab2086524c85b287036899b826281972b0cac2856e3255992781b7e3bfd2073d6854b5942c311132e62a52890010432927450e0609afb6a1367b9e7d0751856332cba70cac1c46c1441bbdc35f48baf05c4d61532561756860099664aadc5ad71a73bef6261154b4aa599b2892907b493aa03dbbc697e3e67ca12960d09b3dcf3e83e9c27194974e195a0b11692bd0d8ee8d4e0f89cf73d55552e6922db0504ab41c2dc787735d2cc9a950cea089a478e4d96773f03adfb9f798c549521452a494a816208620c5c171426cf73cfa0f2708c650b0a4e195a9524b8224ac107d11a0c231398529998555cb2c0674d3a9b7ea1bbae38684c2026ba0226273a4021376297bd8f7eee67425e0992b2f690acf2ecca038bd8f03636e5bc5e0a3c04d9ee79f41b560b8c248070babb806d2547f7469d578acc7dbe155a493f9c1215985dc936ed6a75be978e7cb98a96740a4bb942ae0ea3f79e7164cb4cd61249da12d90ea6db8f7bdb5b8d60a3fb44d9ee79f41b56098b84850c32a940f092ab586e6e716185e2e584dc26b260b5f62a0a02da16e01aee0708e7254a4974a882c458ee3631a054b9aa698d2c93e3a45b7ea3d1a680686226bc04d9ee79f41c381e2a5399186d59617064281ddcaf73baf67b4030bc672e5561556b480c02a42edae96b5c93c1e11d94c748082ace59396ee6d6b6fb8b4689524841a85052091a17584e85bb82598f1d37c551e826cf73cfa0d9c1313591b2c36b0396095c95067277b370b96d621385632080ac26ad6901b2aa42cd9ddb4b79b89850212b48124675900107c6771a0dfab35f79b6e9da4ecaeb00cb2f3322ac92e403945b801d9dc3945c04d9ee79f41d181e2251dbc3eb25ac076d82959ac4ee16f9a1b9f2683aaf1995942708aa203286692a58048bd99af6dce1870844a69fb413314e0589f15c6a747bb5ac35be9795edc29484a3205248cb2f4524124dfe70046b7d3945c16cf61367b9e7d075583e2ab9454ac32b1052f913b1591a8ec80ce3525ceb12ac231592e9978655cd495660a3254c4036395ac75d5ec748455b22fb5212bccc764011adcb69becc5bb3a5de0ed254154c00b58a4ba83769f8823880058f38b86dff00626cf73cfa1092a9a4ae6a368078ca2729d4ab5e258eaffb224a240cc25ac4d501f3bb2342e471dcce41e461c5d351cd2553718a40b6f19289d7d58364ee166000d20185c8002978c52046a4844d240b5db269da0c4b031227663df7bcceaeae19ae622a9b3d0f2944a402c6590c016676e2dbf58b1968caf306c4e5240172ab06b6e777776636d18b824d3a10",
            "132b18a44b5dca67120dae3e4ed74ea2fb9cc4780d1cd5012f15a513145821289c417274ec3f00d7ef89b7099efbdc35756f59ae628acc90b320012c123324b92347275008536801e11549993e665291316a07b46c757249f4dcee877aba910334dc6294829ece44cd2096075c9b9c38d775a2d325c898952558bd1328957893b57777c8e778bbea60d799fe06aaadeb35cc488a64f692a2b2d9b229db51671ad9dfc5e46226ae7821330b819b28b1487241ca34d5f4871387524e9c9448c6295d4f6526686bf1c8ccd724b6f8b2692964252a18bd292b0fda44eca439ddb3ed5c03c1c6862c3f44357570cd731244b42d217306ca5e609ce2fa0bb0de74de007dce204e62908a7033283963db24f672fe26c371bbb59b5d3d2cccc6662f465674504ce1c2cdb366005806fc1a23ab6994262e5e334665a0dd4a4cd1a9b7ccd7907d0f089ffd46aeae19ae673a36284c8244d19a60639370bdc2bd838ea08687d74f4f29e4a318a6494854b25689d999f46d9f67cdc4dd8b46668e8544938bd221c93d94ce2390628e3bdff9cba97a8d555bd66b9882d6a985d45f80d00bbd86ed6265cb54d510080007528e891c4c74656174ca2952f17a528510025299b996eec00d9dee087bb7e068ba6a75a508eb8a24a502c9089ccfbcf89a9feac042ec6350d555c335cc4d5312996654a04249ed28eab0f6ee1a5b8f99b2877c0a97cb347fab3bddc6e9a1a490cb998ad199840521251348bef2327a06f77d3590ea1aaab866b988a1094204e9c1c1f111f4ff0097edd06f2335ad531656b2e4c38aa4a75a8a958d522944b925338927eee04d053ad4129c5e914a2580089c493f7711e3821aaab866b989cb42a6cd4cb4075ac8481c498d16b4a1064c92e0f8ebfa7fcbf6ea7700f1a5a492854b463347b42e95ac266961c12423d277e9a3be1e054be59a3fd59deee2b57542da355570cd73128da4212ca9d343cb9766fa4a20e51f85f903bda1a461d4f3159518c519201578b3b401cfe8f808bcea6a3594a25e31482520324144eb9de4f6353fcb70852a3ea6355570cd7339cb5aa62cad65c98ac3be054be59a3fd59deee37a7a1a44accf5e2b46a972ae4144d627e682e8bdf51c1e22a5d4c6aaadeb35cc4e6fc8d32247ce5b4d5fa3b23d05ff00c5ca178795494eb5152b1aa45289724a67124fddc478152f9668ff005677bb8558b1aaab866b99852a1332a90260796975ac71480e47a018ce62d5366aa62cbad64a89e24c74d3474d2e8662bade9019ca080acb3741750f138947a217f02a5f2cd1feacef771aa9452977df31aaab866b9894307b386a1adb49aacdcf280dff00b8fa635f02a5f2cd1feacef770c54d1d30453cb38bd20522507eccdbb92a1f338284295836355570cd73395043be054be59a3fd59deee0f02a5f2cd1feacef771ce06aaae19ae6655fff0012aaff00aabfda6178ead6d1d31c46a49c5e9124cd558a66dae7fb10bf8152f9668ff5677bb8e968beb7ea355570cd73321dac356f7d9cd4e5e59817ff00da3d10bc7569a8e98a2a258c5e90a9728b7666d98851f99c12617f02a5f2cd1feacef770a94a4c6aaae19ae6292d6a9535331059682140f02234aa4265d52c4b0d2d4cb40e0921c0f4111bf8152f9668ff005677bb8615474d32865abade90992a282acb3743748f13885fa614a9a5aefbe4355570cd733950c4af96a69923e721e6a3d1da1e80ff00e1e71af8152f9668ff005677bb894d253a14149c6a912a05c1099c083f7719a706355570cd73118b216a96b0b416223a5514348a589e8c568d32e6dc0089ac0fce01916be8383461e054be59a3fd59deee0e974b1aaab7acd73309e84b2674a0d2e659be8a801987e36e446f78c63a7269a8d0548998c52194b0ca0113ac7711d8d47f2de628bc3a9e5ab2af18a30480af16768438fd1f0316a53f521aaab866b98aa1695a0499c580f117f43f97ecd46f07398854a9aa96b0cb4129238110df8152f9668ff5677bb8dc52d24e4265af19a3da064a16533438e0a251e83bb4d19895e50f68d555c335cce6a16a96b0b41622345a12b419d24301e3a3e87f2fd9a1dc4b0aa0a7428a558bd22540b105138107eee04d253a14149c6a912a05c1099c083f771161831aaab866b988c6a998954b12a682520f65435407bf78d6dc7ceefaa86927bae5e2b46260054b4844d02dbc0c9e91b99f4d30f02a5f2cd1feacef77161d2355570cd7315992d52940120821d2a1a287111085aa597496e23506ef71bf487d14d4e84ad1d7144a4ac5d251399f71f1351fd5898bcdc2e99254a462f4a1092414a933732199c11b3b5c80f67fc05bade348d555c335cc442133c812865985ce4dc6f609f61e1a925a318e88a3a1490462f48b620f693380e618238ef7fe5a229e9e6b495e314ca2a09960a113b333e8db3ed79f80bb0685d4fd46aaadeb35cc4559824a2a00cc90e1cf6c11d9cbf80b1dc2ccf7172d08495cb1b59798a739b6a2ce371d77905b7b186bab699225ae66334625acd9494cd3a1bfccd7916d47189453d2cbca65e2f461635514ce3c6cdb36620dc17fc5a2ff00f61abab866b989ca5cf24a6596072e616092c4019869ab6b120532bb4a51416cd912eda9b39d2ccde37330eaa92967a54a38bd28280fd944eca038ddb3ecdc93c1ce822aac3a924ce5227e314ae96b25334bdf8e4666b821f74587ea86aeae19ae622b0a944cb521292cc77bddddfd171bbbe34ccb9852baa3992b21d6b3da67670753e291a10383c392e5c89694a538bd1324857893b57777c8e370b36822a30ea4988c",
            "d2f18a50de3664cd0059f5c9a9655bf6c44bcb977b46aaadeb35cc504b46579636c728241b14d8bdb7b33bbb30beac2a99b3d6d2924a812c2580e096676e2dbf5877c068e5288998ad299892c50a44e00311af61f886b77c49934eb414cdc62914f77099c0937b9f93bdd5a9bee710d984c77def1abab7acd7313089072898b129447cded0d0313c37bb12790885154a217291b307c550398ea15af10e346fdb0e9c2e410548c6290a3504a268245eed934ec9721c08114d4728854ac6290adbc652275b470d93bc5dc10748b11b70efbdc357570cd7313f17b54976be6f9e1aefcbc5771a02c4c2e95290a0a4a8a540b820b1062c252b2e75108490e0ab7eba71b821f478dd55290a39524977138da613abbf7df8ee78e7b71781ccaa92912fe5d210a29053945cdace346b723da7bc4afb4929a6fcd5ec3c721c9ed7160906d61df19194ee652b689bd999405f51dc1ece0718844a52c15384a1240528e81ffad05ec62cbd900aa54a4974a882c458ee3630c84cacc1756928cc01cb2800540a9c96d059d85be6d9af0784a52b2424ac93f9d365f8d99c1dc4f12e79c6225676d92b3a8b765994f6d06fb9dd7b6820b0d9882eada2d1965e528480e946f604b91a96ed39dddcd19256a478a6ce14c6e091a38d0ef810852f3650f9466274610c8a84ca5961b65e7cc671b2b73e5fc6e5f7100188b1c5b805724940578405216c4042350406ed03a39fd86d711599b498465ca5172112f44f643db5d19cef6d4c66109525d2b1980ba556e3a1ee039b9d204ca98a9825841cc43b1b599dfb9aefc20db6a120405a800977487606e038636feb4860a644b0553905333316940b80db943517046afbf70cd1b7d9b290ada4e2ea3308ba545b43a921b53bc96e318912c85292a2962484aaf6b35c6a75dc348b82e20bcc1326cc52f309a4921d3c00e1b8372161ca2826a9c67026071656f02c03eacdc2216854b2ca0dc0ea0ddac77e861adaaa9982c05d400c336b2acc2fae60c18689efd2252db7802b965533674954f09f108052953d9fccf6bdc07de062b44c5ad4acdb524a89502e4b5c9e3cdcc434b536551416b855c58711c4beeb5af10a42920288ec9d08b836075f388373e1810ac327f2542d07f3eb1955ff0086378ef3a1e01c6a4b5d33554f282e600a9e47c9e6d50966ccfabd865e1ab68616025a8801450e40ed5c73248e7b9bf9d8bbb36f7df78529045b22b2e601c3662d760ed7e17fdd1bc9fc9d02a8fe71c6c81ffdde623ce78b111854cbc48137f2794aa61f9c53198786fcbede607072b41044a9c80866a3e447820f985e61e2b6b8f35c0f39df052fc9e7ab3fa16c9ff39f17d0c4f0ecb6f85a35f6d3ebfc008208668fb351b73a48066f9c78bfea61e78cd2af380159d89c29fece364fc4b92afc496e4d0b41042a72e404335d6af9a8dd2cec87727b23f01050db1090b3e2a1616a3c129b93e806168d6ca3d5ff001feca104104608335fff0013aaff00aabfda616866bffe2755ff00557fb4c2d1bb4fbdfa819a1bd7ca46e987647b95d93f8185a0866baf884f58f156b2b49e2955c1f4110db47a3fe7fd145a19a3edce34ff00681b27e05c14fe203f2785a08cd2e1c9020866b3b551b71a4f026f9cf8dfea71e685a152bae00cd3fcb0f043f3cbcb3c16d61e7b03e63ba168219aaf94c9563f4cf9ff00e71e37a5c1e1da6dd1afba9f4fe0a2d0ccafca252698fe712e659e3bf2fb3993c5c2d04669704082199df9420d50fce39da81ffbbce4f98f070230c8acb98860d983d9c3b5b8dff7c574c3c01b8fca90840fcfa0654ffe20dc3bc6838861a80eb45c8969241515b123b361c88279ee6fe4caa6aaa2515cb0133c0f94cbaad2cd99f57b9cdc756d4c6e2f6ddbdf7de345d089885a559b6441490a25887b83c79b88db2caa97c89299e53e2000254a7bb799ad6b92db815d285281501d91a93602c4ebe6312d2d2f994565ac136171c4f02dbaf7bc44e3c302019aa73900961cd93b81b10fab3718bcb13254c4af30944101d5c08e1bc372363ce361355524196022a410414eb308de0ea15bf9f7b3aa842a616487e27402ed73bb5106a1a6b128c04c89802a4a0aa6660f289605f701a9b90357dfbce55cad4414bb24b381605830b7f5ac4812c04a94a2a72094a6d6bbdce874dc758db6fb4752d5b39c194260175283ea7504bea3780fc62e0f802b2f692c9cd9422c4a2668aec96b6ba3b1dcfa88b6492b09f070a5ad80285ea490dd903563fb45ac63154a9899865941cc03b0bd99dfb9aefc20284a52ea58cc45929bf0d4f713cdc69113694340852d4bf18d9ca9858027561a0dd1aa768846599942140b257b9c02e06a1fb2c77f73c686a133561c6c579f309daab7b66fc2e1b79209859685232e60d986607571078629c818299598ae912579413966804a405382da1b338bfceb35e165294a2ea512580b9dc2c22e65647daab2283f659d4f7d46eb8df7be8636f094a9609494107f3a2ebf1b3393bc8e218f38af1db80211d9484d4fe6ad63e380e0f678385137b1ef884a5265fc8242d4124ab30b8b5d868d7e67b2f68c972948014e14851212a1a16feb437b88912998cd56cd36b33a88b683b8bdd81e3097b20145294b51529454a25c925c930c78ddaabb3df37cf2f77e7e33b9d406062535292a199241773385e603abbf7df8ee78c0ca565ce9216901c94eed35e17203e8f13662b10741785e2d394a5cdc26b44c512a2b4c85768dcdc371234660343145e078c21653d5956be0a4c95907f08484a6405cc5644a8129b39535ac3bf7f23a90",
            "d13b7523b3246cd1bc6b98382cae3a0b696d2134ff0071d26cf73cfa0ff52e2929b3615573560dd224af2863bc8177be9c45e26661f8d4f24d461559315765090a043927836aa7f64738ec96037c9a80bea41606fc43dbce4e820122699a2584ba8bb170c40772fa358df4b459f0a44d9ee79f41e56078b00552f0dab5a5f7c850235d4372dce2fac4a303c5401326e195995db2a64ab31b3f0b0d2fcf7b184734b969212d316a4f8c4592fab0de74beebf2310a9c66152a70da28b92b7ed137373bee6ef7b6a224d0bd7d84d9ee79f43a2ac3f1b5ca44a56135465a03253b05db5be8fa97f46e00450e098a2c8d9619581cb04ae4a83393bd9b85cb6b08994ee652b689bd999405f51dc1ece071894ca4a5299b3890851b2478ca1cb807b3fed631667689b3dcf3e8388c0f1851be19568019caa4aed7ee73e68d5587632996a91230bad125418e6a7512abbbe9676161c06acf1ce350b2020a5265024896dd90e413cf700eeec19e2ad2d4eca282d60ab836bdc73d2dbf5b42f52b0a44d9ee79f41fea6c4e62ff00e155929fff00016520bf73800779b738a9c131905baaab0e9a4951d7cd0989134cd12c25d45d8b86203b97d1ac6fa5a2fb44c80b44853a95d9337470cc40e00defa91c2e0cc36d4a04d9ee79f43a230cc6690291230dab33141a62c48510df445988e277e9a6b80c1f14212956115a9620152642cdaef622e74de348482e5ac9daa59cb952033391bb4e360dac4094a52732085d9c81a8d7777077168aea9d9b04d9ee79f41e381e30c48c32ad40369257bc3e8cf1ac9c2316912fc23aaeaccc24a529d82ad6b921ae2ecda1bbe8c79e84250813a70749f111f4fd83f6e8379155cf5cd5669acb37d43359869b83061a068274d38f889b3dcf3e83cac2f1898a52a761158b52be7092a05dbbbb89de5b588ea3c594f930dabb0d1521409b39dcdbbbcdad08912d44e55145c9655d86eb8d4eed07b253226aa6a65a52ea52f2248218ab803a6f1e989b7c244d9ee79f41f9381e2aa980cdc32b132d37591254edc05b5feb48b4ec3f1ba85ad73709aa5295a1d82dc683567360d77dfbef094c9c10944990a74208528b5a6283dc83b802c1f9d8398c8196a23324a2e03a6ec37d8ea77ea3d95ba52ba84d9ee79f41e382e28a272e195a8b92ca90b2c375c0b9dda0f641c131905baaab0e9a4951d7cd09094a5102590b2480027524ee0353c3fa11b48269e578582cbcc512b916babbc386e641dd1124de284d9ee79f41da9c23160a4c8978655944a195c4953295f395a5efa1e0042fd4d8c792ab3ee15ec8512b4d84c4052406b58b3bebc775de219252e16c407208d4be83cd7ddbfcf2a6aa7226cf73cfa0e753631e4aacfb857b21838462c8a04cb185d5954d5e750d82ac0064eee6af40f3f353226aa6a65a52ea52f2248218ab803a6f1e98b552d2b9ed2cbcb400849d1c01ab6e72e7cf154529b7df7fe44d9ee79f418ea6c63c9559f70af641d4d8c792ab3ee15ec84608e7284d9ee79f43ad4d8462c813e6755d5852651090642aee424eee0a27cd0bf53631e4aacfb857b2314f630e987433262520f10012a1e928fc3842f1d2a692484d9ee79f41eea6c63c9559f70af641d4d8c792ab3ee15ec84608e7284d9ee79f43ad5b8462cac46a549c2eaca4cd51044855ee7942fd4d8c792ab3ee15ec8c6bff00e2755ff557fb4c2f1d2d1abefd44d9ee79f41eea6c63c9559f70af6431538462cb1226755d5952a500a0242acc4a46ee0907cf1c98615dbc3a59d4cb98a493c0100a47a42ff1e30a5a69a1367b9e7d0dba9b18f25567dc2bd90753631e4aacfb857b2118239ca1367b9e7d0eb0c23165d02a59c2eac2a52f3a46c1570432b7724fa4f997ea6c63c9559f70af642f4ab4a27b4c2d2d60a14756046adbd8b1f34555226a66aa5a92ca4af22892182b813a6e3e88e8e2a49aefbff026cf73cfa0d753631e4aacfb857b218a6c23162a548998655844d195cc953255f355a5afa9e04c72d9212e56e487000d0be87cd7dfbbcd2a5a6e25a0252435ee59df5e3bacd1296a97226cf73cfa0e8c131925baaab06bac950d3cd12305c512466c32b57705932161c6fb9163bb43ed5e793512bc2c975e6089bccb595de58bf304ef8c4ca5249130841048215a823711a8e1fd18ad24f0426cf73cfa1d29387e374eb42e561354952753b05b9d46ace2c5acdbb7de2b3b03c5533099586562a5aae8264a9db81b6bfd691cf265a49ca92bb90eab38dd61a1dfa9f6eb2e705a57267a990b25492d696a2d7006e20316e562c22a74b57589b3dcf3e833d478b25b3e1b5771a2642891671b9b7f78bda25385e312d49549c22b10a4fce32544bb777791bc3eb08aa44d4cd54b5259495e4512430570274dc7d11004b4919945770593671bee743bb43edcecf081367b9e7d0e9cec23169f2fc23aaeac4c042549d82af6b101ac2ccda0b36ac32181e30c09c32ad20beb257b83e8cf09227ae52b34a641b681decc75dc5cb8d0bc59684ad067490c91e3a3e87b47ecd0ee274dd3563e226cf73cfa0d9c1f1401494e115aa724052a42c5acd602c75de758dce198cd58089f86d589890d2d6642806fa26cc0703bb4d34e5194a4a732c8459c03a9d377717736892b96823649762e14b0eec4eed3858be905546dd826cf73cfa0e0c131925baaab06bac950d3cd16ea6c4e5aff00e155935bff00016124bf73904771bf28536899e1089ea6527b226eac19803c40b5f5038d80a191344d32ca59419cb8600b317d1ae2fa5e261b695226cf73cfa1d24e1d8caa5a644fc2eb",
            "4c94861969d40a6eefa5d9cd8f13a3bc64bc0f1849b61956b05d8a64aef7ee71e7845a5a59d4565ae13602d6b9e7adb76b78b0a858050129128904cb6ec96248e7bc877762cf16f52f0a84d9ee79f41d1826288276b8656162c52892a2ec46f66e370fa45d387e36894b949c26a84b58652760bbe97d1f50fe9dc488e7aa5254954d9249424dd27c648e7c43d9ff006388812998cd56cd36b33a88b683b8bdd81e3098d826cf73cfa0faf03c54833256195995db2aa4ab30b3f0b8d6fcb738884e078b1015330dab425f74851274d0373dec2dac2299c6594aa48d9a8310b7ed036363bae2cd7bea62734b989014d2d694f8c0594da38dc75befb73312687ebec26cf73cfa1d09787e3520834f85564b559d4642892c41e0daa5fdb11d4b8a4d7cb8555ca59364992bca5cee2459adaf0378e7991344d32ca59419cb8600b317d1ae2fa5e01b2402ff0028a22da801c0bf12d7f381a88b3e156c1367b9e7d075181e30b584f5655a38a9525600fc22e8c2f1692a4ae56135a66248505aa42bb26c6c1b883abb83a08436ea5f6670da2370d32872593c3536d2fa44194e82b96ace94805566297b5c77efe63425a24d3fda26cf73cfa1266267ac19c722cd8ccd5f5ba87a2e3812c4c66b429197325b30cc0bbb88aa52a5a825292a512c000e498665cd4d21059139799d52d5da976717e26ee08b0e6f6cafabeecce664997d9cf30e445bbd41dac37e8795b58bf8490152d12c0905414659bbb713abf736a599e2b936e53b3529536c9085172593b8f999bb8078c60dddd9df7b886a132d60e4565500e52b3ab01a1f4db96f31450521452a494a81620d8830210a98b084075186515099094a00dab1baf4290096c8754eaefc776ae493c5e00a32699476890a9c05906e127fb5cc70e77d088aaea1534933de629bc727b5bd9cefd46b7b3388a8959db64acea2dd96653db41bee775eda08ce23a9ac16c06a65bb9947689bdb45017d47707b381c62a842a62c2109751e704a94a9aa2010000ea51d123898de6d4a66276594a900be7365ad57ed28efb9e6c2c0ea4d4a96a5e0521551b194aa7a753a15f9c511f9c3dc7707b6fdfc00cc194b607e49560f729dc2fbc6f3bfba20ca773295b44deccca02fa8ee0f67038c6712aa9f8ec2175214901453d93a105c1b03af9c45e54b49499b35c4a05adaacf01eddde80624a144a979ccb9690ca58e0770e24dedfb9cc693ea25d4cd52d52f6403e408d122e406f38b86de5893152512ca566d54c9ff9c4a48032a07d016603d1bdf53bcbc54a65ac8d9299cb04acb3393bf4e172dac54ca5329492169492ea4f0b5db502e358a447536fea21650524b29241606fc0dc4319d54b4c529244d9e9bb16ca8e07bec7b9b8c14ca32d3b798ca972c9c885874ad459c31e573dc34244645489d314a5a8a16b512544950b91aefe37b98d28a54adaca1b496b5bcc4657d4a073776d34b306dd1025a941391965440ca3572ec1b7e9bb888a9428202d9d3c45db5d786862b189de42f2d0a9b351290975ac8480fa931bcfa8499899680264894c94661e30049ef00924b3efe422c89aa9346b98b016b9e322736a9480c483a8dc06e2c41d216696a6caa282d70ab8b0e23897dd6b5e37f6a84f165246cd412331429c024dc6fbdae375afbfba20a14101795d3c4176d75e1a18852148f1859ca5c5c123563a1dd1095290a0a4a8a540b820b10631c190668d6a9466d4a4949968212416ed2bb218f1b93fe18c44c4923692c10e1f2f64b0b30dd7e2dfbe1898b4cba4a790b405661b453765401361dec0904bd970b25095b04ac0511a2ac1dd99fbaee5b7c74ab04a95db29212951010b0e480caecdcebc981e262a428049292028387de3488295009252405070e351a4014a01402880a0c58ea358e58106271c9454d2f5cd9a6bf79cadfe8fc617786eb56935010b40195090427b2caca1c368194e486172616c892d9160dae15d921839e5c5b796d23a5a2fa9a5e181595781e0525492ca490581b8dc6e222391066bcffbceabfeaaff006985de18afff0089d57fd55fed30ba52a5164a492c4d86e1731d2d3ef7ea01e189273d154cbd32e59afdc72b7faff08c72243e75816b04f68970e39707de1f48668969150508403990a002bb4eaca583685d4c40637022d9afa927e38150a80a2144249090e5b70d22c52949216b0e090c9ed5c69c989e062854a2120a89090c1ce835802544288492121cb0d0691cf0217331209d9cb00396cdda2c6cc775b8b7ee8dab16a9a6554a8951988014497ed27b25cf1b03fe28c1484a1c2960a80d1370eeccfdd770fba1996b4cca4a8908404e51b44bf69440371dec412435911d69c53a5f6ca2c10a282bcac9e24b3e9a71d4449d9a428662b539008b0dd7bdcefb5b7774514a52d454a5152897249724c4a50a5f8a2ce12e6c013a39d06f8e7c110629ea4227290a695266852159478a15cf520302cfb9b798c262152a6ae52d2cb412921f422069697cca2b2d609b0b8e27816dd7bde195cd54ea344c40085c8191597552486049d4ef07707006b1bfba986f6145ccb5242b3b20a49194eae19c36ed77f0313b49685bcb4666d0ac73776d34b317df194582145056cc9e26cfa69c751189dc418ceaaaa60951266c84d9cbe64701dd73dcfc21748528b25249626dc05cc5c2912662548515ad0a042812916274dfc2f631ad4a8cc4ede5b265cc233a10192850760c395c779d4831b715297b514c8265a09daa9d8b14a0bbb11bf4e370fa45a554ae49065a522c42ade30208209d4382459bd378c22e252992a510",
            "84a88652b85eeda9163a4653733490bcd96909136539944b5f541e07dbbfd2051285281504f646a49602c4ebe631b48a8974d352b4cbda82d9c2f450b121bcc6e5f71604467390a052bce664b5064acf01b8f022d6fdcc62b4a251409948703e55570f709de2dbcee3bbba34151b6949a7a853213f9b501f9b3dc3716befdfc415a3412998cd56cd36b33a88b683b8bdd81e31154fc361085a152d650b4b28738b096cc669d9a6d6d5445b41dc5eec0f18d6554a65a76594a504be7175a156ed24eeb8e4e2c4e84613652a5280241043a543450e222b54a52b105d150a944190f2d4de383dadcec776874bdd9cc599352a1b3484ce22e8160a3fd9e67872b6a042f1a19591f6aac8a0fd96753df51bae37defa188aa6f07b0154852d41294952896005c931729968033ab328870941d1c1d4fa2dcf718d975099e95208d939b2f52a0487ce75568efc7768cb2d0a96b28586508ad258ac41b0aa514ec968069f366d926c01bdc1d5efa97d03bb45152fb39e59ce8bf7a43b5c6ed472beb1946d936055b4529336e92849621d3bcf9d9bbc1684bab6f7dee0510852f3654be5198976611a098990b2649ceb1613346d2e91e9b9e20b031799353564964495e674cb4f665dd85b81b3926c7935d652548514a9252a05882188307f4fdb983ab325612894d2ab6ac4a525214a4d2a4b9b9627696b836e435678c36583fdbab3d513ef21242d52cba4b711a8377b8dfa08d02133c812465985cecf71bd827d8786a4968377b62ef81d2fd3e55efcc676583fdbab3d513ef23744ac266ca56d6b6aca101f68695208b304bed2fa0b72dc1cc739329299626ce24249eca46ab0f7ee1adf8f9dab366aa6a812000032523448e0209ddc5a17d7957bf33a7365613e0e912eb6af62087229537536ff0094ef03758b3dc9c36583fdbab3d513ef2114a9492e9510588b1dc6c6342a9734a94a694b626c3b24dacdbb7f2b8b010752ab1817e9f2af7e635b2c1fedd59ea89f791ba65613392b5cdadab2121ccc34a905cbb07da5c927beda80098e78a7505a84d3b3421b32b5d746e2fbb8eba5e2b366ed19294e4969f152eedccf1278fee6104eee2d0bebcabdf99d2992b0932026556d5ec92029596952492c2eaf94e6c37707b9386cb07fb7567aa27de42295290a0a4a8a540b820b1062e572d60674e5500c1481ab03a8f45f96f311d4aaf017e9f2af7e637b2c1fedd59ea89f791bcb9584d42c8995b5658152a61a54829d6e4ed2f72389360239e9a698a5a424a4a159885fcd64ea78e97667d2d7889b35252254a044a05efaacf13ecdde92749ddc5a17d7957bf33a3325613352912ab6af66805a58a54929d5c9f94b960e4e9a696030d960ff006eacf544fbc842343373bed539d45fb4eca7bea77dcefbdb5119752a9cb42fd3e55efcc7128c250a0a4e215a9502e08a54820fde46b2e460f3dd26b2ad394399829100245839f94fe649dfa4739729b32a5ab692c7ce02e05b51bb50383e84c6b3bf2749a54d962d38f1503e2bf016f3f1611aa70dab017d7957bf31d9b2b099c126556d594212c940a5495245cdfe52fbc922d7dda461b2c1fedd59ea89f7908469b5cebcd393b47d4bb2b5725f79d6e5e32ea5539685fa7cabdf98e25184a4ba710ad0588b52a74363fa48d65c8c1e7a84b3595614c4e714880c000e48da5d803a5cbef8e70959db64acea2dd96653db41bee775eda08d7f3345fdba8fc100fef50ef1979c6a9e2b017d7957bf31d9b2b099eb41955b5652c10896295248d400db4b92ce5ace79c61b2c1fedd59ea89f790845f6aa2c1602d830cdae8c2fad9830d232ea5539685fa7cabdf98ea5184a4ba710ad0588b52a74363fa48d65c8c1ea268966b2ac2d649ce2910909d1c91b46601f46fc239d925ad6d2d595f40b3cd99f4d2ee5b7c6d252a93227ce524a55944b4b8b82b1af714857a446a8db8ac05fa7cabdf98e4d9584d4cf2b955b565c009962952e90f9529fce5cb368ff00b630d960ff006eacf544fbc8422e26a9929500b4a4864ab85ecfa8173a465d4aa72d0bf4f957bf31d08c240501885680a0c5a95371afd646b2e460f5350895e195695cc21208a4400e55a91b4e6cc1b74735a5a9d94505ac15706d7b8e7a5b7eb6862910a454a6611e2a16b4285c664a0a87a2d6f4c6a8c6a4a3017d7957bf31aa8460f3ea26d426beac6726614f82a1d2ead2f32e7bbdb192a46128514aab6b52a05883489041fbc84952948713084280f14eaeecdc8f7b45b6a94a4cb482b4ba9b3e8c59881b8db8f2d358da6dba90bf4f957bf31d968c2f32512ebab544a8108f03410a3badb4bebf8c4ec704d902aaeab05ad96992e6e6e7e539335b718455352b4a83196e5f2a3c52d601b907bdcfe262a652994a490b4a49752785aeda8171ac26362917e9f2af7e6762b64e0c6b2a95e1b559f68bcc0d3a6c736a3e503eadbf79b42d31185e652265756a4851251e06801277db696d3f08c6ba52bacaa14a210954e53295c331bb6a458e918266a5094863318be55f8a1ec43730d7b1fc0c6ed1fd6e540bebcabdf98da64612b504a6b6b54a25801489249fbc8d69d183c8a89550aafab39089813e0a87532b4b4cb1eff6473c4d4901241960809251bd3a971bcbb1d77773553294b612c85a88f146aeecdccf73c61349a74a17e9f2af7e674a648c1e9aa172bc32ad4b964a49348821c2b50369c998bef8c8a3092120e215a424307a54d86bf591955a14ba954c03c64216b51b0cca4051f4dede885da5a59d4565ae13602d6b9e7adb76b78b5e1535180bebcabdf98e6cb0",
            "7fb7567aa27de46f2a56134d3c2e6d6d586042a59a54ba83e5527f3962cfab7ec8e619aa652520212a25d29e16b3ea4586b148caa952e5217e9f2af7e6756648c1e9e69962b2acad041ce6910a0ad5881b46621b57fc6325230951756215a4b017a54e82c3f4918ce4aa7489139292a56532d4c2e4a06bdc1253e8318e49685b4c5666d420f3667d34bb87dd1aaf6e0b017d7957bf31bd960ff6eacf544fbc8de54ac2642d666d6d584b142e59a5482740436d2c43b87b38e51ccdaa838400870c72eba31beb772e348a46554a97290bf4f957bf33ab32460f214658acab2a60739a44170416206d2ce08d6e1b7464a4612a2eac42b49602f4a9d0587e9230fcf517f6e9ff001413fb947bce6e51919591f6aac8a0fd96753df51bae37defa18d55c1602faf2af7e637b2c1fedd59ea89f791bca9584c90a336b6ac21696520d2a42942c6df296dc4136b6fd239bb5c8bcd253b36d0bbab5705f71d2e1a338caa9538a42fd3e55efcceacc9183c8648acab5660e261a4410a170e3e53f98237691929184ad454ac42b54a25c934a9249fbc8c24fe50914aabacda49e0a27c57e06fe7e0e63244a7caa98ad9cb3f388b917d06fd08e0fa911a78c5d580bebcabdf98decb07fb7567aa27de46f2e5613292a136b6af66b01e59a5482ad188f94b162e0e9aeb7079a26e46d9272283769dd4f6d0eeb8dd7bea6338caa9538a42fd3e55efcceb4c9584d3ac0975b561c052660a5492ad2e0ed2d70781170630d960ff6eacf544fbc85654d48499534132897b6a83c47b37fa0895534c4ad41452109ca4afe6b2b43c74bb33eb6b469bbd8a42faf2af7e633b2c1fedd59ea89f791bcb95848905336b6af64a0549cd4a90416374fca7263bb8b588e685cb40391399443152c68e0683d37e7b8c514a52d454a5152897249724c6554a9f017e9f2af7e675552b0992942e556d580a0e260a5492e19c3ed2c411df7d4820c61b2c1fedd59ea89f790a4a9bb374a939e5abc64bb3f31c08e3fb9c458d3a8ad2251da216f955a69abf06dfc35d2f1a6ef6297e05f5e55efcc676583fdbab3d513ef237952b09f0750995b57b124b134a9b29b77ca7703bae1dac47382a5ca29525a6ad81b8ec837b36fddcac6c4466a52945d4a24b0173b85844552a71817e9f2af7e675572b0995293b2adab08587da0a54926cc52fb4b6a6dcf7863186cb07fb7567aa27de4272a6aa52890010432927450e062ca94954b336492520f69275407b778d2fc7cce6d558a42fd3e55efcc6b6583fdbab3d513ef237972b095ca69b5b5665252a0952a95218d8b03b4bdc8b733a3bc73ca13209138669818ecf70bdc2bd838ea0868cd6b54c2ea2fc06805dec376a609aa76aef88bf4f957bf3212952d41294952896000724c6a36724215d99934f69b54a4359f89deda0def702d34f83154b957cc3299bf4ae41cbc8e8fbdb73910b3c61fd3ea723733b6c49a92a5a8b0da6aa17dff004adc780bb08a2e5290029c290a24254342dfd686f7119bc5e5cd54b3a0525dca15707517f49bea217a7ee05635952925266cd244a05adaacf01eddde80744d3a152d33466be5694e334c2ec72f2f33b9662c48c26cd54d5024000064a46891c0458bb8b068aa998beca824cb00a532fe6a1f870d05f7ef77310652560aa4125815141d5207edb7ec3660f18bc0f19bf3f762098b210a98b08407518d12bdbad289895296a2d9d01d4493bc7cedfcefac693d3e0d20c94293304c3da9a82e92c7c507d04bf2e44e952b6f802a670923654ea705b3ac8fce317663f35c6875d4ee0331b2582ff26a02da90580b710f7f391a08c9e0788eb9da0bad0a965941b81d41bb58efd0c562d2e6aa59d0292ee50ab83a8bfa4df511b48932a702b2a28421b305103312c000ad0125cdf4009bb41537bed04cb26965a6a1da72c3ca23545db377d881e9b307c82e5a984c4b6833205c69bb4360785cdcc44f5cc5d44c54d4e45bb14b365e4db9b468cde2d55782d80d0ca565ce9216901c94eed35e17203e8f14812b5214149252a05c11620c5c2d0a61352da0cc8171a6ed0d81e1737319c182d4f2933677ca1225a466591b9235f39d0732226654cc9cb52a604a81d127440bb04ef003e9a691acd96aa7a512d042ccc4a664c29f9a2c427bbb492fa12dc21378dd5342ba0d4a25ac8d9299cb04acb3393bf4e172dac5149524b29241606e371b88abc5d13549012405a1df2ab4dcfdda0b8bc62530561b9eb54993269927b211b458d415286b7fec948e45db8c14d4d2e754253354642032959b5cb94a891bf416b1d439e39d4a8aa74c9b35273cd255d9f15f317637cc2c7fa17e893a68756fef9033265a93e294280dd7074f46f3fb845d74d325b95948482539b810f62350ed6702333354e72012c39b27703621f566e3154ad485052494a817045883189a7c417065a4821256c41ed5873040e7bdff009312262e5d1d52c2b2852048ecd897566bf10c93f842e15b42019598804f6031b27d0c19f4e37873609187012e685ed669394075161d90068fdbb80490e3818e9669e2d710279d2a6ce8161aa6c4d9872ddde6f78b0925614a94a0521595d5d96e0ef6bf7ee3b84536812f9102e05d5722cc796fef16bc554b528ba892580bf01611ce578834284cb594cdcc54921d20377873a11a69fce04d524832c041041053a823783a8e3fd0884cd506cc02d2036555c33bb72bf0e262c99616941732dcb665f8a5ae4bf20d6b9fc0436fda0debe61389d566017f2d30df572757d630084cc584cacc14a259243f7071a93a69fc99c450115f58",
            "4bac89ca1993e2872e2fcc3dada77885153545f2808490d95360ceedcefc7808e969856ef6f0cb9925002a6a804956574f69f8b35addfbc6e315ce94be440b8d55722cc796fef16bc512b524ba490588b7036316da0536740b0374d89b30e5bbbcdef1ce5780199f317328e95655982506476ae432b35b80650fc617265a8925250e49ecdc72001e7bdff9b9b049c38899342365341ca432838ed02347ec58120963c442655b32409594900f6c39ba7d0c5df4e178e9689ca6f8065d14d326314149492139b892d60352cf7606280cb4a7c52b511bec06be9dc7f718a296a5a8a944a944b926e498b09aa719c0981c595bc0b00fab3708e734f801990b54e933a9947b251b440d005246b6fec850e659f8c291bd328a674b9b29273ca215daf15f306736ca2e3fa36d2a69a5c9a8526528cf4175272eb972850277e86f61a163c36d3aa85577ded02a94a94592924b1361b85cc5c225a09daa9d8b14a0bbb11bf4e370fa4557354a05200421df2a74deddfa9b9bc51e39ca40de5d4cc92b4aa584a40d53b962ce15bc82da69ac4544a4ca9df264996a19904ef49d3ce343cc18c5e1c952d5514a65ac84196954c9655f385c94f776545f405f8c6e99ad5d029171295973a8842487055bf5d38dc10fa3c05684b89497d46658b9d77682c471b8b18a296a5a8a944a944b926e498c6081a15cb4b89697d46658b9d77682c471b8b18d6613552d550ef3901e693aaeed9bbee01f4ddcb2af1a485cc4544b54a4e75bb04b3e6e4dbdf468d535783d80a4590854c2c90fc4e805dae776a2369f26549016145685be50920e521c1055a120b1b6a083678c664d54c3a04a5dc213603416f40bea623a6efdc0b7c9211f58b3de12037a4973dd6def1a09c270d95429807c8b03f36e5d987cd73a0d351bc159e0782ae0175a152d650b0ca11586a427c264092b52658967b33565921cf8a4fa486e7cc8cd4bd82d48969525692d9d6194083b87cdddcedac574adbe008129280153c90e028206aa07f65bf68b317894d4cc4765212259012a97f356dc78ea6fbb73308c1e078cdf8fb41b4d949091365126512d7d50781f6eff00481945a54d54a512002086524e8a1c0c6eaa74265aa69cd6ccf29c66965d866e5e6770cc1c13a8bd8a062894a582a70942480a51d03ff5a0bd8c5c4ed890698a90a0e369a28df77d1b70e26ec6339935530e812977084d80d05bd02fa98a3c4bd1f68373b39c16aeccb9a3b4da2541aedc0ef6d0ee6b039292a428a54929502c410c418abc3328f8494cb9b6ca3289bf46e00cdc868fb9f7b0105f57a81815784094651a0ac520970f569ec9e23e4fcdff00c089987074a4cc9745593253b05785206e76236763ec2ced1cb8b2262d19b296cc3291a82217e70675d6d5c325c8776d83fd86b3d6d1eee364ab0644b13a6d056313d841aa4f6ef7fd1d873e361bdb0d94b40dba25bcd29ce241be41f4afa8de06ad7360ea494a52d456b5152945c925c931a7346defbff635b570c9723a332a7099ab2b5d156151ff00cd2079bf376117f09c1a7cc1b6a3ac4a89bccf0a497b6ff93fc75b9378e54118d63f126b6ae192e47496ac25197361f58330cc0f85a0823eee29b6c1fec359eb68f7709a26a9095a18290b1749d1f71ef1fd58986cca4d3cb4cea7255356332527c79296776de6c6fb831b386da57b145d6d5c325c86553708a64197e0358272832ff2a4ba07d17d9ea77fa3888c915384cb2e9a2ac0fa8f0a4106eec46cee1c08e6c119768e701adab864b91d4133049a54d45572d448ca93569cb73a399766b6bcefc68a9984a1450bc3eb52a49620d524107eee39d1a266f6724c4ed1161add21dec776a795f485e9da35b570c9721e96ac266ac21187d6151ffcda079ff3761179d538330912e8eb152a5a959542a92333fcebcbde00b7285e64af07a55a259cd31406ded7961c325bfe6173ff0028b1244251aa9ba15d1adab864b91d315584e5c8aa0ab5a406015549b6ba7c9dae496d1e241c1d6db1a2ac593f33c29014f6d06cef73baf6d0472e08c5f7b1935b570c9721fdb60ff61acf5b47bb8da9d5832d6a5aa82b324a495a9ea92c780b4b7b92079e110a5cc403351980052959394f641b3e87516d6c006866a64cb91251250b335293b49a121883c15c080523421d4abc75a13fbbc11759570c9722eaabc2d53ccf3475bb52acf9855a017777b4b8b6d7075049998756212cf9c5520129709b0d980743a7378e689aa484e40105241cc9d5c3b17ddaeee02291cefbf1c46b6ae192e47557d4c94952292b27004b94552580b5ef29f52d703cf15f0ac243845055a1c0072d525f4637d9bddcb8d239a95290a0b428a5492e082c418d9204c09da4bca92e04c4b0d007e4481bac493ac5bcdfdb80d6d5c325c8e8226e112e8a6ccf01ac0269d9006a937008513f9bb3327d31926a70948291455994ea0d52083621db67adcc52b65265ad3242b6a29d265a8a2cc7524bddb3a88d06818ef84ccd539c804b0e6c9dc0d887d59b89fdb1badba5c6e1adab864b91d307055286d68aae9dc59ea924682e46cc90e0bbb7f2aa9783cb65757562d2a1626ad0cf947097a87fd8e37472e252a524ba545258870771b18c5fe04d6bdcb25c8e89a9c24829f02ac092ce0552002c1816d9ebed8d6a66e1094534b550d6664ca161549b392a1fa3bd883e78e7b098854c5cbc9a9ce9601478371729d341ba18ad42515d3993b64493b3e019042413bd886bdae7946d4dd6fbde5d6d5c325c8d5353852d593abab26a94c900d5249d1837c9bf9b908b23a8d41954f568",
            "5ee49ab417716becd873766e7a472ccc594043b246e167d6e789b98ac62fefc46b6ae192e474c4fc225a5fab2b3b61c29554936b82df26dffc45155184a8baa8ab5458073569d0587e8e114cc5a01483d93a83706c43b71b98d532d0bcb9c6c010f98e8468081a9bbbb3ef61684b7821adab864b91d1ac9f852312aafc8eb02b68b04a6ad21ee41fd1c6467e11312fd5959d80e549aa48b5807f936ffe633c41094e2558529da8da28e67b243905c0b8bb33b6eb5e1254c5ac0493d91a01602c03b71b08dda54d54d3de35b570c9723a8bea34864d3d5ad7bd3e1680cc2f7d9b1e4cefcb48aaaa70a42b2757564a525d240aa483a317f937f37331cb8b098b08287749dc6eda5c7036118bfbb01adab864b91d5a69b84291532d3435999528d8d526ec428fe8ed604f9a324d4e12905228ab329d41aa4106c43b6cf5b98a51212bae92e9d8a271d9f10cb25248dec03def71ce17612d09988979f439d4c424f06e2e15aea3747473753f5efdc6b2ae192e43a95e0f31d5d5d5884a45c8ab433e53c65ea5bf6b0dd1627054a8eca8aaea185daa920686e06cc12c03bb7f3e5294a517528a8b00e4ee161111ceff00026b5ee592e474955384a8049a2acca3402a9000b00edb3d6c2355cdc226514a99e035844a3b2205526c092a07f3777757a239626a9c67026071656f02c03eacdc0fec8728a52662d524ab642a1225a4aeee750435db3a40d0ea5cef8dd0dd4e178975b570c97234f0ac24b05d055ad810335525f4617d9bd9830d22c8ea65242974959241218aea92c45ef694fa86b03e6845404b0ad9cbcc90c0cc531d416e4091bae411ac62a5296a2b5a8a94a2e492e498c5e6beec46b6ae192e47536b83a428cbc3ab16967ce6a90484b94dc6cc81a8d79345535785a6789e28eb76a159f31ab412eeef7971cc8b99aa505670165449ccad5cb397dfa6fe2625f7e180d6d5c325c8e9542b0642d2b4d056649a90b4b55258711796f6208f3463b6c1fec359eb68f77134d265cf92b92b5994951da4a0a0e49e09e2480a1a00e94de162a5cb413291941012a58398f680b3e83436d6e4178e95a7f77831acab864b90e9383a1f6d4558823e678520a9efa8d9dae37defa18835584e5c89a0ab42486213549be9afc9dee016d1e3990472bef6226b6ae192e47564d4e0cc644ca3ac4ca98a4e651aa49cadf3ad2f7026dce2931584ca5942f0fac0a1ff009b41f3fe6ee239b0ecb95e114a844c3966241d85af303974b7fcc6c7fe6172008dd2dd6ae975b570c972344ccc256a08461f5aa528b002a92493f7717333049452f455731409cc91569cb63a389777be9cafc39ea9bd9c92d3b345c6b75077b9dfa0e56d2338cde8d835b570c9723a4ba9c266175515616d07852001776036760e4c6a99b8454a04bf01ac3392191f9525d63e8becf51bbd1c04722082b47388d6d5c325c87f6d83fd86b3d6d1eee2e85612bcd970fac3946627c2d0001f77198949a896a9d504a66a06652478f392ceedb8dc5f7873762ea2e6a969421825081648d1f79ef3fd5808d35771635b570c9723a5e138348987634758a503699e1490d6ddf27f8eb606d14975384ca585a28ab0287fe6907cdf9bb88e6c118d63f01adab864b91d552b065cb33a55056303db40aa4f62f6fd1dc73e363b9f1db60ff61acf5b47bb8452a5214168514a925c1058830eeca5ac6dd72da684e73205b38fa56d06f2356b8b174ed4d7b3beff00d0d6d5c325c8da59c1d49132651564b94ec55e1483b9d80d9dcfb43b3c41abc20ca12850562500b96ab4f68f13f27e6ffe4c7397316bcb98be51940d001158cdf8c10d6d5c325c8218ca9a650da242e7007b04590773f13adbb9f7883ffb5fff0063ff00e5ff00fafd9dfa2f19fb7d7f8efbe1c8b6d266d76b9d5b47cd99eefc5f8c6a3673d87665cd24df44ab53fe12f6e1dcce708222ab782549521450b494a9258821883111a89a95cb289c0a8b76563504060398b01cb76f06fb14c8699399693796906d339f24fe3bac5dadd9c56c0094a69d2264c4854c50742087007d257ee1bf536d71da4cdaed73ab68f9b33ddf8bf18264c5cc595acba8ff004dca2b075782d80d734b9a9014d2d6949ed0165b68e06875befb3ef314992d729650b0ca1e7f3f31158d11372a44b989cf29dca5db73383bbf9077684a7b419c312529972fc2662428394a1243e6536a790706fad8716114c2628a9131e50054a535d00711b8970d762480f113d495ce254a084a4a929969ed640340fa10fbfbcf7e92bbf53fc77dff0020cb69336bb5ceada3e6ccf77e2fc6369694d414a54912ae946d40648376cdf85f8025898c8ad209c88003962aed163663badc5bf74554a528ba945458072770b08caaa36e20bae56cd292b55d68ce9ca1c6bbcfa747e1abb42969b896809490d7ed1677d78e82cdfb60973552ce8149772855c1d45fd26fa88b265a66802513b425b21d4db507bdedcc6b0dbf683491754cac9df29b320b2af9d64d81e5624f736f8c369336bb5ceada3e6ccf77e2fc619aa4194134a5412648254379592ca1c8866ff0bef85d4658708495066ccad75d58696dd7df1aae57d3bbf9efbc416053325ab34b20a03e740d03300469ab5f99d62d329f649593312b0094832fb41dd839dc0b16df6d18bc64a98b5f8c6ce54c2c013ab0d06e8113172d61682ca1fd373897a9f10495a59494200049baae5acc1fcda803531b5376ea8d44ef944caf95999af9afa1ef240f3c64364b607e49560f729dc2fbc6f3bfba18d92a55114a8a50672eea27e624b386f18151ddf437b5",
            "b544cceeeff902bb499b5dae756d1f3667bbf17e317414cd212b965c0f1a58b8019cb685803c357262a0cb4849ca56a7048361bed6b9dd7b6fef883316414bb24b3816058302dfd6b184e3683534f95016662569673b3ed14d810fc03a80ef78cf3a436440162e55da25c31e5c5ace1f58aa54a4282d0a29524b820b1062e1685309896d06640bee1a686c0f0b9b984a7b3006b49f2b88ca5ceeda73ed26155dd22ea278d818c369336bb5ceada3e6ccf77e2fc61aa494a0674d414ac26511ab78cc8bbe8d9f5d2d0b012c25d4a2a2478a9b36ba9f47a7511b72a953c5802b4a92ca40cc05949b70d46fb03cdcb92636552e52fb4700dd007ca243a9c94ee2025c87de231335597224042486213bf4d78dc02da3c52317978e20be7486c8802c5cabb44b863cb8b59c3eb155294b515ad454a517249724c5f6b9d79a72768fa97656ae4bef3adcbeb00959db64ace4fcd6653db41bee775eda083c76036ae52918b54ad0a29526728820b107318c33a4be740360c53d921830e5c1ece5b5866b90062354662f2fcaad922e753e8b8df7bef85f6b9179a4a766da17756ae0bee3a5c3691bb4c2b73bc1aa697317da3026c823e5141d2c42779214e03ee31885a52964a06622ea55f8e837588e6e1c11148b89aacb91402d20300addae9c2e496d1e3179786008da4cdaed73ab68f9b33ddf8bf18deafe4b119ab93d84e7da4b29b324dd2470b1118912ca5d2a292078aabbe9a1f4fa3530cd5ca513266aca5015280d5fc57459b57c9ae978da974b8e005b3a4be740360c53d921830e5c1ece5b58d053e641589894259c6d3b255624b710e923bda285684b89697d46658bef1a682c471b8b18a294a5a8ad6a2a528b924b92631296dc41a2ca6512944b2e478d305c82ec5b40e08e3a38314da4cdaed73ab68f9b33ddf8bf1804c58012ee90ec0dc070c4b7f5a44932d414729429c9005c6eb5ee37defbbbe133b01b54f62a85449f934cdf959796d96fa0ee208f346216964a56804022e9b16bb87f3ea41d0433b254da209494acc95d940fcc51672fe280a1bfe9ee7bae7648703e55570f709de2dbcee3bbba375ca73bfbfe417974fb54a08989402424999d90eec58ef01c3efbe8c1e2a4a65cb4e59649587ceb1a866200d357bf21a451731730ba8bb683402eec06eb9302262e5974967d46a0ddd88df702337a9f001b499b5dae756d1f3667bbf17e31bcfb2a5d649f93da125936c8b06e072b823bdb7462932cb05a4a433664ebaeac75b6eb6e862950668552850519c0148de160b247325dbfc4fba2d18fd3bff902e95a6c2620292035bb259df5e3a8bbfec8944ada25450aba119d59830d771f46adc3567954b4ca044d27680b641a8b6a4f7b5b91d22b326aa61d0252ee109b01a0b7a05f5319d9f70359894d3952529136ea46d48749367cbf8df8105818c769336bb5ceada3e6ccf77e2fc6212a524ba545258870771b18b05a4919d00870e53d92c2cdc2fc5bf7c1d53b3006b3929992fc265a424384ad20365536a391626da5c7075e3790a4a27029505a5452954b5767383a87d007dfdc7ba574c25a829731a510149535d60f01bc862f760410f1a6af2bcbf3df7fc031972d73561080ea3e6f3f2117cd2e52484b4c5a923b44590fab03a9d2fbaedb8c42e6e649972d39253b84bbee67277ff32ccf19c6652d80b6d266d76b9d5b47cd99eefc5f8c6ca4a6a12664b484cc4875a006047d24fef1bb516d178b4b98b95351365965a08503c0882abc1ec056252952d410849529458001c931bec533de64964245e6249b4be7cd3f8eeb967a19a944b08920a4b76967524862390b91cf7ee0176317b0163b390e3b3326822faa53a1ff00117b70ef77196d266d76b9d5b47cd99eefc5f8c56088eadc0632a6a547669089c40ec01659dedc0e96ef6dc2178218ff00eebffd8fff00afff00ebf6f7ebafbbd7f9efbe233da0992f2cc2cb48ecab88e07f71f369a64f110461b6cc92f03c4411906928a04c0a9b74a6e53f4b9728b7842d4b266fca24ea9d1b4d38683d1c2d18c11a5534a102ca607b2acc3b98f9e21e220880b06209529b900e4ff5fbe242c24829487041755f4fc1a2904240c2e7a84a449973159521c9767245c770723ce78c514a44c4a96590b77602c7bb81dfc3b9af9411a75b7b412f00ba802a090779dd110464174a909624159e06c1dff10ddd1ac99e65052c299413952006773a9eed7bdb842f0455534e5034da95272cc19b82b78b300fc34b72b34556c164215993b8b3456088db7b412f12199cab8d80bf28ac1005cac329284800937372d6b7e1b9b7c6d5150a5ce56559521b2dee14c1b331de5c9ef261682357dc403451429d49ec6fcba8dda1f4ebe93147888232dc8245d40150483bcee8b6640660545af9adbb9702ff0084520848194d42934f300594accc4a865b36aecda5f2fa0708c82d2a61312dbb3245f76ed0d81e1aeb19c11a75b7b4126c6ca07ba078882320ba723665a89bf8a35ddbf76fe3a40662b2e54b252431037e9afa1e2904590315151b4a99ca042d0a5a8a5c68092cdbc6aed192b23664288bf8a75dfbf7eee1ac5208aea6dcb04bc02e6ea03be2208c8342b4a5c4b4beecca17dfbb416238e9ac6aaa852a9e582b2a5898a51cd77d19df5be6f49e30b411a55b5b017cc82ee0a4b5b2df773e25bf18a9b2880a0a0378df110466412f174942594aedefcba0dfa9f469e9119c104e00cd3d42913939965286cb6b04b86ccc378607bc08c42c3252b4820117162d7b7e3bdf745208d5f7100b16670ae1622fce21e2208c82",
            "c862b016aca9de59e2db5294e59632f156f36621f86b6e7778ce08a9c6c0313a799a12b2a7514e55021d98ea3bf5ef7e319294853900a0f0170eff00806ef8a4107536e5824d944050501bc6f81e220880d52a44b4a56196b77622c3bf89dfc3bded744f5194b933262b2a8382eec40b0ee2c07987085e08d2adad80b9585125490e492e9b6bf8344160014a9f910c47f5fba2b0466412f129627b4aca3b9cf9a2b0401b7842d2b0657c9a4689d5f5d78ea7d3c2d159a5066154ab255709fa3cb9c670457536a1825e078882320978d76825cbcb2cbad43b4ae0380fde7cda6b8c1153801041046640410410901041042404104109010410424041041090104104240410410901041042404104109010410424041041090104104240410410901041042404104109010410424041041090104104240410410901041042404104109010410424041041090104104240410410901041042404104109010410424041041090104104240410410907ffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080100010003012200021101031101ffc4001a000003010101010000000000000000000000010302040508ffc400321000020202020104010303020603000000010203110004122105223141511314617123819132f0061542a1c1f124d1e1ffc40017010101010100000000000000000000000000010205ffc400161101010100000000000000000000000000001101ffda000c03010002110311003f00f98b0bc0e19d56c5e178af0bc50ef29ac216d889766492280b8123c681dd56fb214901881ec0917f63df25785e28ac11acce55e78e00119b9481882429217d209b62028f8b22c81644ef15e178a1de575440fb50aedcb2c5ac5d44b2451891d12fb2aa5943102e81617f63df23785e2877945826681f616290c31baa3c814f156604a827d81215a87cf13f592bc2f143bc2f15e575b567dc90c7ad04b3c8a8f2958d0b1088a59da87c2aab313f00127db143d9d79356411c8d13128925c722c8299430ed49174458f753608041192bc5785e287785e2bc2f143bc2f15e178a1de179b68d0409289e32ececa6201b92800531eaa8d902893e93607573bc50ef0bc5785e28b340ebad1ec168b848ed1802452e0a8526d6f901ea1448a3d804f1352bcdc5b0d0a4c8a232264e0dca35620720de9245a9b51d8a3563d8906778a1de178af0bc50ef370c336c39486279582b39545248550598f5f000249f800e4ef0bc50ef0c301801cda48a892ab448e5d78ab313719b06c511dd023bb144f574438666d772e82324ab27ad15c532953d1045d1e8fb83445100e48e346db5e64d74d968641048ed1a4a54f16650a5941f624065247c721f6328d32ee3edecef6cec3ecb8322b95fc86694b8e5cd8b023a2e797a89200aec9139a248e3859678e5322726540d711e44716b005d00de9b14c3bbb009b57635e38249a09624d8432c2ce84095033296527dc72565b1f2a47c1cc89de178b0c077948209b69cc704324ae11a42a8a5885552ccd43e028249f8009c96180ef0bc59596248e3859762294c885991035c47911c5ac0174037a4914c3bbb0027794d985b57625d790c6cf1394631c8b22120d1a6525587d10483f192c301de1796d8fcb0c71eb49f8085feb031f063eb55345d7b3400f493e93c8503cb24d1ba05664650e392922b90b22c7df608fed80af3ae4f1b345e320f22cf0186795e25512a99015009b4bb03d43b23ff0017cf04a90b9678239c1475e32160012a406f4906d490c3e2c0b045833c21de6c22985e432a0656551190793020db0eaa85006c83ea140f753c30aa40d12cd199d1e484302e88e15996fb0188201af9a3fc1cc5e2ca40d0ab933c72489c18008e1486e2789b20f41a8915d80458bb018bcea925d03e3618e3d79d7784ae6598c80c6c840e202d5820f2eefe7fc7266e11134c82677488b00ec8a19956fb20122cd7c58fe46119bc2f161853bcbbf90d99207d7fcacb0398d9e18e923768d4aa315140b00cdea22fd4c6ed8dc446e636942318d4852d5d026e85fd9a3fe0e6701de178b0c0bed41fa593f0bacc9b096b3c52c7c0c4e1882bef67a02ec03762bab31c58c605b56249f6228a49e3d74770ad34818a4609ed9b882d43dcd027e81c98c4318cd600e238ce238d1a960962489e489d1655e71b32901d6cad8fb16a45fd83f593c671664535b5df6b622d78cc6af2b8453248b1a024d0e4cc42a8fb24803e4e28e1691246528046bcdb938524581d027d46c8e859ab3ec09cc65176f6135a4d459e55d795d657843908eea182b15f62407700fc723f67207b2b026ccabab24b2eb87611492c611dd2fa2ca0b05247b804d7d9f7c962c301e18b0c51d08638f59d88825794140adcf9c3454f3154a6fb5eefae5d03c4e4316180f3a76bc96eef41ab06d6d4d345a91fe2811d8911259343ebb27211cf34292a472c88b32f09155880eb61a8fd8b5535f601f8cc603c33bfc7c9e1d3c7791fd7c5bb2ef3222e97e16558d1b95b3b9364d0000503be47b14338a48d51226599242ebc995435c67911c5ac017401eac530eeec050de268d636250891790e2e0902c8ec03d1e8f468d51f623350eb3cf1cf2234404082460f2aa92392afa4120b1b61d2d9ab3540911ca4a2109098a4919ca5ca1902846e47a536790e3c4d903b2457565435d799b5df656190c11bac6f2853c5598315527d81215881f3c4fd1c9e2ce9f21ab169ceb1c3bb0ee298d1cc91060016504afa80ec1358a39f0c5862879d12e8cb0b3867d72522498f09d1bd2e148028f6deb16a3d4b4d60716ae6c303b23f2dbf0f8c9bc5c7b73268cf22cd2eb873c1dd410ac47d8b3fec0c82cccb03c0047c1d95c928a5ac020535581ea3601a3d5dd0ae987c7ebcbe1767c83794d58f6219e38934583fe59958312ea40e34bc40367e7f8be1c943c33a4793db5d8fd44537e9e5fc3fa72daca21b8ff1fe2653c00be49618fbb7262d65893cd9457676b63724126ccf2ceea8910691cb1088a1516cfc2aaaa81f00003db263163194318c676f8a8b59db625dc88cb0c3033955d8489b91a552bcbb7a665255413409f60738866b00711c672906b4fb6e63d786599c",
            "23c856352c422a9666a1f014124fc004fc63444e2ceadcf2336ec71a4a9aca236765fc3ad1c4496366ca282c2fd81be23a143ace5cc83163c590536b61f6f665d991625795da461146b1a024d9e28a02a8fa00003d80c4af07e9dd5a390ce5d4a387011569b902b56493c68d8aa3d1b044ce2c887785e2c32529de178e360922b322b80412ad74dfb1aa3fe32fe4b6a2def21b1b506a43a514b2175d7889291027fd22c938a54e58d238e1659e394c885995035c47911c5ac0174037a6c530eeec09de2c3053bc2f1618a57678c97c7c5b0cde4b5b63621314815219446c242a781b20f41a891ffa319b69e78e08dd620b0218d0a44a848e4cdea2002e6d8f6d66a85d28033348b2b8648521015578a162090a016ec93648b3f164d002809e0a7785e2cd9914c2b1889032b3319013c9810281eea851aa17ea364f54a56f546bbed42bb72cb16b97512c914624744becaa9650c40ba0585fd8f7c500819c89e49234e0c418d0392dc4f11448e8b5026fa049a35465860aa1914c2b1889032b163202793020503dd50a3542fd46c9eab179bd99df6b625d89046af2b97611c6b1a024d9a5501547d00001f18e199238e756d78a5322055772d711e4a792d102e815f502298f57442953bc33716b4d3a4d2450c922409f9256552446bc82f263f039328b3f2c07ce60651dd279466d493522d5d582190c4cc112db92271e4198961c892c403564d003ace3c58f2e2ab36b3c11c12334444e86450922b103932fa8024a9b53d351aa354412491ac69132cd1c8645e4caa1ae33c88e2d600ba00f56298777604b29244d0b0562849556f4b86144023b07dfbec7b83d1a232a32318cdeb6bcdb73c5adad0c934f2b88e38a352ccec4d050076493d566066b141ca0580eb48cd24a3603a848c460a32537225aec1042d0a3767b14015148b1b9668925055978b934090403d11d826c7c581608b19338d08e6e0892672af3c70008cdca40c4121490be904db10147c591640b206117e0421dccc59832140142d0e2435d924f2b142a8766fa9e646e08d659a38de54855d82991c12a809f73c41343f604fed93cebdbf2336ec1a9048902aea4662431c4a848e45bd440b6364f673933211c58ce2c89a336b1a181e533461d59544443726041b61d550a00d907d4281eeb0716443bcbd9dd6dad9d9dc5fcd5f94998bb3ec3970080403eaf516258814a7bba079f35122c92a2348b12b3005dee947d9a04d0fd81380af0bcebf33a3078cf2db7a5abe435fc8c104ad1a6dc018473007a65e401a3feefdf38f0291a2bac8cd2a2145e4aac0dc86c0a140f7449ee8503ddd038bc59481a1572678e4913830011c290dc4f13641e835122bb008b17602cdb709f2276c686b2c266fcbfa30d27e20bcaff001df2e7c6babe5cabfeabef37bd1f8d8f5b45b47676669de12db692c411629391015482790e3c4df5effd8716180ef0bcdb4a8759221046aeaecc6605b9b8214053df1a1448a00fa8d93d54f01de6cc12ac09b0d148217664590a9e2cca01600fb12032d8f8e43ef14d3cbb0e1e695e560aa819d8921540551dfc000003e000331816986bac70186495dd909995e30a11f9374a431e438f13642f648ae8132c58c6052589234859678e4322726550d711e44716b005d00dd58a61ddd81819d1adf9608a4db8ff004e557fa0cb2fe363fd4461611ac9a00fa80f49e26c12b9ce32e2e1e3ca32c035a3659653b05d83c6630115297890dcac924bd8e22a8766c855046b2cd1c6f2a42aec14c8e095404fb9e209a1fb027f6cd62abe3bc76df96de8343435e4d9dad8711c51462d9d8fc0c93c6f0c8d1c88c8e84ab2b0a2a47b823ef2c6a18b57675f9c5229219c4ea5bf229be4aa006414c805dd90c41f85e71950c631944851b56498ec44b223a208086e6e0862581ae34bc403641f5ad023911319ac50711c6711c684716338b3235144f34891448d248e42aa28b2c4fb003e4e5bc978ddcf0fbfb1e3fc86b4babb7aee6396191699187c1ce7c72caf34af2caed248ec599d8d9627dc93f273230716338b226a906c4da93c7b1af2c90cd13878e48d8ab230360823b041f9c96338b220c30c44e14f0ca6b4e90485e4d78b601474e1216001652037a4836a4861dd581608b06579287862bc2f147679497c7cbb08de375b635e0114619269448c640a399b00745ac81ffa1cf0c4d3cd1c2850348c1417708a0935db12001fb9343277949362699224925774857846acc488d7916a5fa16cc687c927e7031862bc2f1477f91f1dada5a9e3e783c9eaee3ed426596184386d56e6cbc1f9002e803d5fbff04f0e2071e018c62c6328a36b4cbae9b2d0c82091da3494a9e2cca14b283ec480ca48f8e43ec66062c632e18796d5d59f77662d5d58659f626758e28a252cf239341540ec924d00333afaefb5218e3688108f25c922a0a552c7b6205d0343dc9a001240cc66b15b9e16d79a485ca168d8a928e1d4906ba604823f7068e6462c6328ecf1126843e4f564f2baf3ece82caa678609046ee97d80c41a3fefaf7ce790a1958c4acb19278ab372207c026859fde86606319ac01c47291c32cee5228de460ace4229242a8258ff00024fd019338d08e2ca8d875d67d7023e123ab926352e0a86029ab901ea3601a3d583c454b3229aed02c84ec472489c1c011b8421b89e26c83d06a2457601162ec4b1e6e068164276239244e0e008dc210dc4f13641e835122bb008b1762091c58ce2cca6badfc5cf0eb0d8da23556487f36b8951bff00923985a420117d96f510294f76541e3cbee452eb4efab33a3b6b",
            "b34571cab22744df16525585d9b5241bb1ef98d79db5a78e7411978dc3a89115d4906fb560430fd8820fce44104f36acf1ec6bcb243344c1e392362ac8c0d8208ec107e72471e2391461861910652281e6499d4c60429cdb948aa48e417d209b636c3a166acfb0244f0c030c30c032904a90b9678239c1465e32160012a406f4906d490c3e2c0b045833c30018f10c7971706319d71786f233f8a9fcbc5a53bf8fd7952097642131a3b025549fb347fedf6339065418c62c63358b878f163cb8a318c58c650c6592146d69263b112ba3aa08086e6e0862581ae34bc403641f58a07ba88c63358039b9a4595832449100aabc509a24000b764f648b3f164d00280c1c471a11ca2ed4e9ad26aacf2aebc8eb23c418f07750c1588f62407700fc723f6713412ac093989c44ecc8b2153c598004807e480cb63f71f78a18d6572af2a4402b372706890090bd03d92287c591640b232318b3a777c7edf8d9961dcd7975e4645902c8b44ab0b07fb839cd90239b926691235608044bc178a0524593d903d46c9ecd9aa1ec00cc1c5994d0716338b220c471e522d8785268d562226411b178d5881c837a4904a9b51dad1ab174483152c30cdcd0cbaf33c3346f14b1b147475219581a2083ec4644630c30c032916bcd3a4d2450c922409f9256552446bc82f263f039328b3f2c07ce4f0c030c30c0a2ebccd03ec2c521851951a40a78ab3025413ec090ad43e789facc6218f2e2e34259044d107611b3066407a2458048fb167fc9c431659175ceac8cd2ca3603a848c460a32537225b9582084a1c4dd9ec500d512caeb4edad3c73a08cbc4e1d4491aba920df6ac0861fb1041f9c963197170f282795617804ae21765768c31e2cca08048f9203351fdcfde259e5585e012b885d95da30c78b32821491ec480cd47e391fbcce6b146520916262cf124a0ab2f1726812080dd11d826c7c581608b0678c65475e9f8bdef21afb7b1a9a934f0e9c625d874524449c82db7d0b233986564758a59d356695a06254332f06913958e4a0903d81ab3447b9abc90cd628388e3394816067236249634e0e418e30e4b853c45123a2d409be81268d516889c594d885b5a7920731978dca318dd5d4906ba652430fdc120fc64f3234eed21b7666200164df40501fe06631e2c828365d7564d60b17091d6424c4a5c150c053d7203d46c0201a0483c454719ca34c8dab1c235a25911ddcce0b73704280a45f1a5e248a00fadac91c40ca6a4716338b220ca4edaed1c0218a5475422667903077e4d454051c471e22896ec137d802788e4552281e6499d4c60429cdb948aa48e417d209b636c3a166acfb0244f370c8b14d1c8f124caac18c6e485700fb1a20d1fd883fbe63222fa9fa3feb1dcfd41a89bf0ac343949ec3913eca2cb1a049e3c7ae5c9618618061865279df61c3b88c108a9e88d5052a851d2802e80b3ee4d936493806d6c3ee6ccdb322c4af33b48c228d634049b3c5140551f400007b0186bc4934855e78e0011db9481882429217d209b62028f8b22c81644f0c0063c433b77a2f1d1eb68b696cec4d3bc44ed24b10458a4e4682904f21c789bebff02aa6ba337e8ff5b22b45aec592291d1b8cd22f0e488c05165122b1048a047c900c062c632a0caced03383af1c91a7050448e1c96e2391b00745ac815d02059ab32c632e2e2bacb036cc4bb32491405c091e340eeab7d90a480c40f6048bfb1ef98ca6c6cbed48b248b1290891d4712c6295428e940174059f7636492492679ac518c668c32ac2b398dc44ecc8ae54f166001201fb0196ff91f7991950c631886516795616804ae21765768c31e2cca08048f624066a3f167ef358a7aeb036cc4bb32491405c091e340eeab7d90a480c40f6048bfb1ef9238ce238d1d8de1f707875f30230da467fd3348ac0f0938960180ff004d80c45fbf16face1c6716645366549f625963823d74772cb0c658ac609e947225a87b7649fb27258f1641ae6a2168cc485998309093c94006c0eea8d8bb17e91447773c671665341ca2ecbaeac9ac162fc723a4849894b82a180a7ae407a8d80403409078ad4ce2c88a36c4cdae9acd348608dda4488b1e2acc143301ec090aa09f9e23eb2471e2391461861911b59d96078008f83bab92514b58040a6ab03d46c0347abba158c32906c4daae64826921728d1968d8a92aca5596c7c152411f2091813c30c300c30ca45b53ebc73470cf2c69b082399518812a060dc580f71c954d1f9507e302631e218f2e2e0c63167a3b3bbbc3c2e978e9f5a38f543c9b504875d55e50c7813f92ad9418c8f7ab047c7551c70449339579e3800466e52062090a485f4826c90147c591640b20826975e549a191e296360e8e8c432b0360823d88c9e31971716d6d97d590c91ac4c4a3c644912c82994a9e98100d1347dd4d104100815a01ad22b4729d82ea51c48022a5372056ac924ad1b1547a3608963cd62a9af336b4f1ce8232f1b0751222ba920df6ac0861fb1041f9cc0c58c654319bfc6e11642ac118950d5d122ac5ff0071fe46606753f92dc97421f1cfb52b69c3234b1c058f0466001207ef43fd9cd62b306dbc1519feaeb99125935d99847295bae41483eccc2c104063445e739c6711c684716338b323a743c6ee79499a0d1d69766558da5291a9621545b1fec0672e6d2478cf246652415b535d11447f7048cc6408e52295238e656d78a5322055772d711e40f25a205d02bea04531eae88a1dfd91b52edc72fe09a6fc81ceb8110a7043a855a0148623880051aaace6cca6839bd981f57625d790c6cf1394",
            "631c8b22120d1a6525587d10483f19d7e3fc86be96a790866f19abb8fb5088a29a52e1b55b9ab734e240ba04777eff00c83c1911d9bd2f8d935b4574b5b6219d212369e5943acb2722432800711c788aefdbfb9e2231e1914ab0ac78620558563cdc734b124891c8e8b2af0902b101d6c351fb16a0d7d81f5813ac2b1e188156158f0c41486149239ddf62288c481d51c31331e4a38ad022e896f510294f774092eccf3c70c734d2c890218e257624469c8b71507d87266343e589f9c7336bb470086295245422667903077e4d454051c471e22896ec137d8025806319b89612929964915c25c41503076e43a636388e3c8d807b0057763032a0ca4022662267745e2c41440c7951e22891d13409f8049a3546796d8d67d590472344c4a24971cab20a650c3b5245d1163dd4d8201040b8b89e5018bf0b028e652ca55830e2168d822bb24f1a362a8f46fa9e3cd628c6329abb2fa7b50ecc4b13490bac8a2589644241b1c9181561f60820fb107142eb1b1668925055978b934090403d11d826c7c58ec11632a32318c4328b34ab1342247113b07640c78b30040247d8e4d5fc9fbcd62b0711c6711c68a6d2ebac806b4b2cb1f0425a48c210e54731418f41b9006fb001216e86767667dcd897676669279e6732492c8c59dd89b2c49ec927b24e0d0b2c093129c5d99000e0b58009b5bb03d4289147baba34a6458a678d25499558a891010ae01f71601a3fb807f6cc8ecf012ea41e73426de98c3ab1ce8f2c835d3638a8606ff1bfa5c7dab0208f707d8e447a5ad14ff99249ff003444ea3a4a8a50892ae451ca8d2b7a4907b07d8839c58b33a84716339d2bb1a90ef413c5a5f9608ff133ebed4a59666007304a7060acc1ba0410081c891c8c35ca7165a2d878639a3511113208d8bc6ac40e41bd248254da8ed68d58ba241956447578b8bc7cbb0ebe4b67635e0114855e18848c640a780a24745a813ffb11d9d5d8d39047b304b048c89285910a928ea191a8fc32b2b03f20823df27595d9d3d8d29045b504b048c89285950a928ea1d1a8fc32b2b03f20823a3811c31d61580b0c75949266952246118112f05e28aa48e45bd440b636c7b366a87b00004b0c7585602c32db69ae9b532ea4b2cdac1d84524b188ddd2fa2ca1982922ac0635f67df25580b0c75948279b59cbc1349139468cb231525594ab2f5f0549047c824604b18c2b0c0318ca6d6cbee6ccdb322c4af33b48c228d634049b3c5140551f400007b0193197170f1e6a799b6679267081a462e4468a8a0937d2a8000fd8000667358aaeb4293c8564d88b5c0477e720620955242fa4136c4051d5591640b22633726c4d324492cb23a429c225662446bc8b52fd0e4cc687c927e73032a18c6310c63358a0e2395d6d87d4d98b62311b3c4eaea258d644241b1c9581561f60820fc8c35e149e46493622d7011dc3c8188255490be904db10147556c2c81643444e392292160b2a323150c030a344020ff00041047ec711cefdff2bbff00f10ee2ec796f2724f347008966d96673c234a441409ffa428f8b3648ece67479f8b292a2c6c02ca9282aadc901a048048ec0ec5d1f8b1d123bc9e41dba32c8353713f0e8cd0aa899c4e515ee8c6a51ac3920cbcb82920f10ccaca9d7065975677d693696095b5e3758de50a7823b062aa4fb02423903e789fa392ac885863ac2b2421618eb0ac422936dec6c4704534f2cb1eba18a157724448599caa83ec3933350f9627dc9ce991fc54bff002f448f6f582a85dd96d652c799b644f4fb2d7458591ee3df38ab0ac421618eb28dad32c09b0d1482091da3490a9e2cca01600fb12032923e390fbc112caeb2c0fb312ed49245ae5c095e240eeab7d9552543103d8122fec7be4eb0ac421618eb0ac4216195d98520d89628e78f6111caacd186092007a61c806a3ee2c03f6064eb046a3310490488ecc56a32ac0056b1d9146c558aebb20df54718eb0ac42163194d730acf1b6c2492421819123708ccb7d80c4100d7cd1afa38f5b667d390c9ad3cb0bb23c65a362a4a3a9565b1f0558823e4123e7289e55a543ae9108235757663302dc9c10b4a7baa1448a00fa8d93d54b1e5c551635303ca668c3ab2a88886e4c0836c3aaa1401b20fa8503dd6062c632a18c6310c63358a0e239dda1e2363c8eb6fecc2faca9a3089e512ce88cca595690120b1b61d0ffeaf84e0239d5e4f761dfd85960d083451628e331c258ab15500b7a893648b3fcff7ce538b33a0c58f0c829b2baeb201ad2cb2c7c10969230843951cc5063d06e401bec00485ba188e29269122891a491c8555516589f6007c9c58620e8f25e3773c46fcfe3fc86b4badb7aee6396191699187c1ce6cb1d83234ef3289e59877248cc595b9025aefb2688eefdcfcd112c40b0c79b8266d79e39902168d8380e81d4906fb560411fb1041c09e18f0c40b28cb00d6465925339760e8500455a5e2435d92496b142a8766c818c31074ea49a2906daedebcf2ccd181aed1c81446fc876c28d8abebaffc8e5c786205863c3102ce876d83a10ab42a35c4b21497f0a82cf49c97f255b5008789242f22401c8dc30c40b0caac4875a498ec44aeaeaa2121b9b8218961d71a1401b20fa8503dd4f0166e195a072ca1092ac9eb40c28820f441ee8f47dc1a22880733948161672279248d383106340e4b713c45123a2d409be81268d51412c786556645d59213af1348ee8e2725b9a00181502f8d37204d827d0b440e4084b2b3eb4faae23d886485ca2c816452a4ab28656a3f054820fc820e1a9b7b1a1b50edea4f2ebecc0eb2",
            "c5344e51e3753619587608201047b64c654318c6218c66b141cbae86d49a526ea6bc8dad13ac6f285f4ab1ba04ff0063998b59e78e7911a2020412387955091c957d20905cdb0e96cd59aa0489f36085031e248256fa245d1ffb9ff38d1838b3a9c6d6b692c52ebfe3876f8ec46ef00e52052e968e45f1be6085344af765457356642cea93c74d178d87c833c0619a5789544aa5c15009b5bb03d43bff00f339ab3690492ac8e91bbac4bcdca8b08b6059fa1640fe48c2279b86169dca218c10acfeb75414aa49ec902e8743dc9a02c9031c6620928911d98ad4655c00ad63b228d8ae42baec837d51c5614b0c7585602c32924f2cc912492c8e90af08d598908bc8b50fa16cc687c927e731580b0c758560536575d64035a59658f8212d24610872a398a0c7a0dc8037d80090b740d7d59f6e431eb412ccea8f2158d4b1088a599a87c055249f8009f8c9d67743078a6f0db32cbb7b4be51668d60d7584189e221b9b33f2b0410b42be7fc11c19489a10928963919ca54455c2846e43b614790e3c85023b20df5448a359188695220158f26ba240240e81ecd50f8b3dd0ef315852c31d65357667d2d98b6b567975f6207592296262af1b8361948ec1040208c09618eb0ac05863ac2b01618eb3a16b7a6feb4dafafc6234c63e2a7827a56914fa9b8816476cd6c4596c0df95f2b3f98d94d8d84d74748a384082158978a285069401743b39c78eb3bfc8f90d6ddd4f1f041e2f574a4d480c52cd0b396da6e6cdcdf9122e881d57b7f0011c51c2d2a4aea5008979b7270a48b03a04db1b23a166acfb0246f6214824091ec45b00a23978c3000b28257d401b524a9eaac1a245132acf57c6f98d3d1ff97fe7f09a5b9fa5d933cbf95a41fa943c7fa6f4dec28fb7dff361e7cd1ac53491a4c932a31512a0215c03fea1c80347dfb00fec33031c8c1e46758d630c4908b74bfb0b24d7f24e219ac56d0465642eeeac16d02a8219ac744d8a1566fbec015dd8c61949cc2ce0c11c91a7050448e1c96e2391b00745ac815d02059ab212ac2b1d6158836b220d7788c11b3b3ab09896e48006b51df1a3609b04fa4511ddceb1d61588290ec3c11cf1a2c444e82362f1ab10392b7a4904a9b51dad1ab1744826ceacfa5b32eaed43241b10bb472c52a9578dc1a2ac0f6082288393ac2b102acdc4b1162267745e2c4145e47951e22ac744d027e01268d51cd6158815655935c6b46cb24a760bb078cc6022a52f121b9592497b142a8766c802987f4eead1c8672ea51c380a168f2056ac9278d1b1547a37d4eb106e09e5d672f04b244e5590b231525594ab0ebe0a9208f9048c9d63ac2b102ac2b1d61588156158eb0ac41d3bfe3a6f1d22c733eb3b30620c1b31cc3d2ec86ca3103b4247d82ac2d5949e5ac7585620558563ac2b107547b70278c9f51b46079a495245da25bf2460020a817546c7b8f8fe2b92b1d615881566e1758a68e4789265560c637242b807d8d1068fec41fdf33585620dc334baee5e195e262ac85918825581561d7c104823e41232758eb0ac40ab0aca46ea8b22b448e5d7886626d0d836288ee811dd8a27aba2315880c067a04e8c3e1d1a1d891f7e7778f621935d0a2440a323239248624106803562e89e5e7e307fffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003011100021101031101ffc4001500010100000000000000000000000000000008ffc40014100100000000000000000000000000000000ffc400160101010100000000000000000000000000000204ffc40014110100000000000000000000000000000000ffda000c03010002110311003f00989b5600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003fffd9",
        }),
    },
    Galaxy = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc00011080200020003012200021101031101ffc4001c0000020301010101000000000000000000040502030601000708ffc40043100002010303020502030702050303040301020300041105122131410613225161147132819107152342a1b1f0c1d1165262e1f1243392087282173443635354c2ffc4001b01000203010101000000000000000000000203000104050607ffc400341100020202010303010606030100030000000102110321120431411322516105718191a1f0142332c1d1e10642b1331562f1ffda000c03010002110311003f00fc79b4d7b69a2c4391538d1518978c38c6306b5d15403b4d7b69a2fcae2a6b0cd75711c31461e46c22aa8c66a517403b4d7369a31a178e468a44daea4ab03d88a898b3daa51281715cabfcbcf41512840e9554515e2bdb6ac0a40a904c8cd5d10a706bd8346ce90bc9982368d3038273cf7aa4c78ed528a07aee2a4c39e95d55c8aaa210c57b06ad08335dd9c8aba214e0d7769a2447c57445f1528809b4d7769a2fc935c31103357c4809b4d7b69a20a6067153b7b59aea7482042f239c051dea512c1315eda689681d2468dd4aba9c153d41af7958ed554407da6bdb4d11e59f6ae04e6af88540fb4d7b1447979603a7dea324451cae41c1c70720d4e25328aee2a583ed5d0322aa8a218af6d3562a926a613dea515652c854e0d7306af6087685041c73939c9a8edaba2cab06bd8356ed38ce2bc578aaa214d7aa58e6bbb7e2aa884706bd8a2ac85a8ba5fadde61efb7ad4a48d5e00f146ab1f98c14961bc8ea323ec6ae88078af6d35788f8a918c55f1203ed35eda68958f23a578a0a9c480db4d7b69a2760af6c2391daaf8901b69ae60d15b0b64f53503191daa7121460d7b06af31fc544c6d55c488ab15ec1ab369a92a03d6aa896538af60d1cd613471c334e8d15bcc7d32633903ad098c1c0e9ef52884369af6d344ac59a9bc6bb46d52081c9ce735288078aeedab4af3d2ba232066a51651835d28c3190467919ab8a8af172db43b13b4607c54a25146d35ddb5732f19af2af1528ba29db5d2841c641fb55c00ce3156797528a0f0aa0722ab230189e28b8ad26b9b98e0b75dcd33044527a92700668cf11e85a878635dbbd07568963bdb421645570c39008c11f0453106f426186e147e757da69ba8ea37263d36d66b99510c9b6152cca14649e3dabb6e80ae0f19a77e1fbbd6b4dd415b41ba9adaf2706dc18b00b87e36f3f38fb1c1ed47c340f2d5996546dd92724d5c36e391446a76773a5ea33585ec2d0dc42e51d0904a91f6a1595cb175ce281d113251c259c8c715c92dcb70a3383475a2ee70a57071cd3bd42cb4ab7d2ec66b1be7b8bb9119aea2688a88581e003fcd9157c74338da33f6f0e982c2ec5ef9e2e828fa711e3693f342243bd471c8a3e484ca7838cf4cd593daada18d56e63b82d1abe63c8da48c95391d474f6a8953012f2c084040c62a2d0f07039a3b92413fdaab98ed04e31814de362dbb7485de482d8618c77a22cf4f7bebf82cedc28799c22976dab93ee4d7594b74ef53111dc013c50a8169de8eea1a44fa5ea73d85c943240db58c6db94fd8d02c8dbcaa8ad0ead369934f6efa5e9f259c2b0a2482497cc2f201ea607b03ed54ea17d75a8cf0cd792798d1c4b0a1da170abd07006687883dcaaf746bcd2c5bfd6c423371109a3f503953d3a50a107522a723b3b6d663955c0279e3b541949c11902ad2096d967920ae715130ab2e3344c314df446768a43086d85c29db9232013d33806b88048fc9c6298a026726ac0a667102dbb3ff0949655c773d79fcaa842f148b246cc8ea72194e08a6d7aed2dbc36e60851600d875401df71cfa88e5be33d2946e28db5b181ce6824a890958c24d2efaded20beb8b674b7b9cf9523747c75a19e300e3157417525dc905934fb5376c8c492611371e4f3c01dc9a75e22f0f5c7863c472e8f777b637b2c4aac64b19fcd88ee19c67039f8ab55d8676622587209a8185770cd18a0b30dbc76aae456dc411d07147c503ce9d0194cb7155b45eaa254157e56acd817af4eb57c531977a17f94d9e9c568744f0a6ababd9dc5e59d979b0c60a02580dcfecb9ea68287d122cc8082bc838cd6d7c33e35d574ad36eec84105c2aa3cf1bca0e626e3db008ef8f7a078dd5a01bf93e7cf16c7c30c638c1ea2ab65db92475a6775a8c97929f3a4328dc589c0e4fbf4a19bcb66e0103ed55c508e40c910db9f7f7a3b53bdb4bc82d12db4c8acda08f63b4649329ff98ff9dfad30b2bcd1e2d1350b2bad2bea2fa6d9f4d72252be460fab8ef9a5724712a1207abdaaf858c522b36b07eeb177f56a2732ecfa6da73b719df9e98cf14395464e383535258e0806bbb141e78154a2390184cb51b2456663805b89bccd9fc6df8c6ecff2e3b631d6a2aa02ff00ad5917a9b6fe99aa5023607247b1b07819a946bc9c5117516403fd455702aee39c8142d53a2d7d4e38217a62a76be50b988dc2b4910605d54e095cf201ed57c91ee041eb42aab29e84d5b541b887ea2f60da9ccfa64324366cd98d243b980f93fe7e7434913a315911918738618354ab316006",
            "7f3a71797979a9dd7d56a17325d4fb557cc91b2700600fd29918d8a692d8b5232dc915743692dc4e96f0c4d2492304455192c4f000a91186e3a7bd5b6d32c13b3bc1e78d842e59976311c30c77079a37140cbbe896a3a35f6917ef65a8db35bdc2004a373c1e41e382282f2c1ce47e54c2e2e2e2f676b9ba9649ae1b9692562ccdf726ab311c7dea71d0ae6bc8098b278c01556ccb36780298c69ce4839aaa408320f19a070d114df806585586715c30ed073fd2ae0c0ae1474f6ef5d6f4c6370ce3ad57141727d82ef21d30687a79b7bfb89af0eff3e0913090f3c6d3f3fe63a528da31c0a342074cf4e3bd6abc1be03bef17f88ad34ab7beb4804e0c8ce65476540327080e4b63b7f6a5ca34393b46396178d991d4ab024107a8356c714666412c8c89b806206481dce2b7fe3df025ef857c5d716525ddadc24abf528de6a46db589e0a31c83c1f7cf18eb587318120c0ea7ad4482483eded7c382ff00508eeaeee4dbac4c6d1d63e5dfb023ff001f952a58010324668a9212997da0f1d457230436f0b918e957c4ab4b40525be01dbde83f2f61e7834d675ccbc74343ca819718f50ec681c42ee81220d3481154b31e800c935d3b477eb4e352f10c93f8886b5a558dbe832222c6b1d86515484da48f93ce7ef51d722f0b47a4e8efa0ddea13df490e7505ba45548e5e388c8ea3af5f8fb50595629f3155b14f74fd3f4dbad2afee6eb5316d730283041e596f38e7a67b7f86b388a7f167a5176cd219007c8ab45a1889d55141e09e9555ccd2dc4cd753caf2cae72ceec589f924d12b144f103b3f8a381f1567d39642acb9007514cab0da62d13b2821718cf7ef44a5ec8b2a3c32159108605090411dc7cd513dac818e148039e2ab8a271ebcec278a2b629efb9db89a5bdbd7b8b991e5964725de46c963dc927ad17b3726d4c62bd6ba7234a3cd7c02c371c741ef8a73e20d3b4cb2d5dacf47d4ff00785a4614a5cf97e5ee24648c1f6352891b407690f90a77fab03f15157575693dce6d6d9e0876a8d8d26f20800139c0ea727a719c76a5aceca0e588c8c5081dc4b8e4718c9a8dd21b19f81d324728dc00e3a9a0705e6d85791432dd4b13b44a4e7be6ae76511f98cdeb07a7b9a8b61392a0931ee88ec6f5f43429b77e412483f3575ae5ce4e33444ab8e48e31cd698c53429c2bb00b8f2edf030587634099e47701c9071db8a3a560c020e3e6835846fc0e71c0f9a5648d3d02a2d0624a190239e3b55b30528a1860d0ca8631975076d77ea37c84b0c8f8aa5d81e2ec8380188e4022a489bd48208c74346fd3ac8ab2062323a579a0950f4dc3bfb53124b6469a61b1788b5cb6f0acde178efd97459ae45dbdaed5c34a06ddd9c67a01c671c0a3bc236de13bcd5a68fc5ba95de9b622da568e5b4b7133b4c17d0a47b13fe83233b8259a28cc58db8279a8a26c00f069ca29a2fd353dc8ae788bb97dc480296dc41bdce08e3b8e69c3b45246028cb2ff007a5f22155666f48ed9ef4ac914f6212a7f02b58ce4e38c77345c2405ce406ce3ad54a8087c1e68fb28809d77db453003f0c9b829fd0835992f81afdda1a58c30bd95ccf212ad16cdbf249c572789580c6307ad6efc3fe31b3b0fd9c6b7e1f97c3366f24cc184a18ed3bb032d9cb6571c608ebdbbe2ae6e609d50c76d15bedfff00c658e7ef926b4c1de982b039f762d0aa642a4739ee2a4f6f32d9a4ce8045233468dc72ca0138ff00e43f5a3ecad2dee0b9b8d420b4da463ce0e7767db6a9e95fa73c77fb1cfd9ae8dfb09b6d5f4ed65629ad956e6df5579cbc7a8c920505768c8c301c04195dbce7d5573924d23438c628fca07f86a7d3c628696e0bc46343f714e351861b57648eea2ba03044918603edea00ff004a44eb89093d7e3bd5cb5d8078d5d955a851751a4ac638dd86e7c13b477381d69a6b16b656baddd5b697a97ef2b18e52b0ddf9261f3941e1b6372b9f6342b479f51f491fad70388d76fe2c8efda93c284ca37b896ba0c2ba0e71dfbd53b1f6ef61bb8e6af037e0e08038e2bc652084e09cd3d41770e1071d82ac65583f404f3563a8c1503731a2b6e6320600a19a278e4dc8dc83d685c2bb174db2dbcd3af34c8a0faeb1b8b537312dc43e7c4c9e6c6d9daeb91ca9e70470697a06c9dd9c1eb8a73757b7fa88b71a85ecf77f4f0adbc3e74a5fca8d7f0a2e4f0a32700702a986150d9de303fad53c765ba4ac925b466000e68530a86248c11c0a2e2728cdec4f19a95c42a10b9c67af157c2d685a949bfa01c8768cf6c7343191d800576e68890314e315532158c67a9a5b8d1a1c8e451a9932393df35634be5fa0e7dfdaaab77db3104e5a8b976638ebdb3d455c7b684c9ec95b8122f07d5d715708807eb8c9fd288d2f4bbdd56f56d34bb1b8bfbadacde4db44d239550598e00ce00c935c3b0050147cd688f602536bf12c16e4583ddf9f102b2ac7e4127cc60413b80c630318eb9c91c55fa74b636d78b35fe9df5d06d7061f34c5b895214ee1cfa5886c77c63bd54d2285da4706a0cca186c3cf50289c6cccf94bc1211a05de0718e94b6e62f3385cfb9a64afb8738c8ed5449951e66c1d7b77a5ca3684c138c80a38086e3a62ac78d1d4823914447b4ae42ec39e86ae48c6776de4d2d446f2dd8ae6b7963185394f7abad65bad3ee21bfb5b996de78583c7242c55d0f6208e451734724ccc91216da37300bf847bd12574793c3c00377fbd44f8c1dbe4793b7ff96fddf96296d2bd1b22b481b5fd46e354f105f6a4f7135c9b9999fcc99897619e339f8c0fcaab451e5062b923e6a0b09775fe5007eb",
            "5e32484eddbc0ea7e2a55235478a5410fe59008279fe9551538dcc47abe2a2f2c61bcbe7dbdaa99fcc0a00c00b8c6681c81e317b38f13ab7e12c0f735c6b7571b83fe547c46365c30249193c77a1ee2658cac61542f5245532a297614dc22a82e1b24f2050a9b64952367112b3005db385f938ab2e54eedddbb552a9b8f4a4b059a5d6f46d3f45d766d3ec75bb6d6ede35422f2d4108f90091cfb671de9749b239c205ce3f3abadecd9d41072b8ce4538d3a7f0fdbe91ac43a9e8b35e6a7711a2585c25c18d6d5c365d997f9f238c1ff00bd150ca7458234c280a33d78ab49448ff00205550ac8ac36f2a071f1576e25b0793ed8a7a34e8a9e31247b5635fce970b4632132440a1fe94e48dbf8464e2a01559f70e7de89a4c54f1bee8162882f24f23a0f6aaae0127246091de98f923f10c038e281bddde51d884b0e41aaa15255113dd3bc6e173919e48a611f877566f07bf8a92389b4e8eefe8d9fcd5deb26d0df833bb18239c6334a04525c4db1a448c927d521c28e3debe8be0bfd9f26b3e0cf116b2fe21b285eda3daaa1c32aedc3e646fe5076e01e79cfb525bd8a3e701bd4ccf9193c1a907f33f19271deacbfb768423add5bca1b23113ee23ef44f87e1d22e3c41616dafdfc9a6e9924aab71771c3e6b4284f2c17be2aac24452eb2bb508fd3ad724ba94a15623a1e9dea57ab64ba9ddc1a55db5d5a4733ac13ba796654c90ac57b6460e3b50a63628770e47b8c53549d17dcba36dcbb9802dd853ad6bc577bae69da3e993e9da75ac7a45bfd3c725a5b88a49871cc873ea6e3afc93deb38859598eec91c641e956c0cbe677f7c9ef577ca8b96cd12f8675e93c1e7c52da64dfb98dc7d2fd6606cf3719dbeff9f4edd6b3eb0bf98d803839a7115f5e7d07eef37531b3dfe6880b9f2f7e31bb6f4ce38cd0ed112c5b71069f2868a845b276f2165c01eae99f9a332c2300f1c7141c2bb71d3f4a3864a820647bd521b0c74c2e3d06f2ebc3b7dac472db0b7b278d2557b855918be71b509dcc38e481c52e5b189f4a9ee85fc51cd1c891adb10dbdc1072c0818c0c73939e6a722cb132f9b194dea19770c641eff006aa0b924e3bd3a316d5309c52d1488fca0c59b27b5052a3b1dcdc01c8a6be5171b8f1db9a0e7214eded51c5d19256e4d4589f9f306077eb5aad06c349bad3357bbd5f5afa296d600d696c911792ea56380a3b051d492723b0349bcb4f301c647b55fe5827ba81d052161614557718da8b49b4ad47cfd57e926544315b8899c5c9ddd370e17039e68158d9fd112348e14b61413c01927ec0027ec2986852e8b6dad4527882cae2f6c00612456f20476383839fbe3da8ef0c78b75bf05eb33eade1abafa49a6b796d7d71a4bfc371823d43191c1ce3a8f6c8a62855d0fe497611088358cd399e30632a044c4ee7ce791c63031ce48ea28ab9d409f0969b62351925786e2790da92fb61044783cfa7921ba7e7d6805cb2907af7af08558e334d78ef688e365135c798a147534468da75aea5abc1617dabdb6910cbbb75e5d2b98e3c29233b013c900703a9a63ab6976ba76ad359d9ea36fa9c51636dd5bab04932a09c0600f192391d452e7b70548e98ef40e0da14e5be22f8a32f2223cc235760a647ce1013d4e0138efd2b4be2df0ee99e1bf135c693a4f892cfc496b12a325fd9a911c99504819cf209c704feb9011141b3691c0ae6718ea3fd28630a7b2d2f0cb236263c1e00a8140b207e4e3a7144c796523a81c8f9aa8b1076b714c6b42f56459c303e9fd29ef8674df0e6ab63acc9aff0088ff007449696a65b48fc8327d4c99e1323a7b7e79ec6903e0a7a4f3ed51442ca54e01ef4324df61bc5782a13957c678a26468d9032b6c23da8ff147866f3c27a9c3a76a12d9cd34b6f15cab5aceb328575c8048efff009190412982670c5481ef4ae5a133492b1ae9ba65eeaf7d05869d67717d7521c470dbc664924e3a051c9aaef0b244d1152acbe92ac3041f9a9e87e21d47c3badc1ab68b7f369f7f6e498a785b6b2641071f7048fce82be9e59e5795e4796594967919b258939249ee6ad49242552926422e571919aeac6642ab8c0278a1a1462db989a3e351c3eee9d0d545da1b2971da2afa375cb6cc11dcd4444ccc379ef9c53033c614ab1c9cd54d22b86c704f7344e2842c926b6837c3de28f10782f5b1ad786f517d3f5011bc42645563b5c61861811fedc1a522591c1724e6a2ec36e4e0907ad47796078c773409abb1c9dad8634a1a03cf4ef5524d873b8720605540b1180060f7a9b103048e471c53393224e1a7d83e239c9ce0d5ac318454c83de97ab02c406cf1da8c8670b161c74e9f345662cd169da2b557f346fe48f9a3e34088771fce8657f31c90c001db1d6882ebc292307b55242db6a934723bf9ac1ae16d2ea5b737113412f96d8f310f553f07da81440bceec8f63573aa96c819dddcd0ab949773313eacf1c56692a767470b4d0c523575c818e39cd09727ca8cba8dc7a1e28f8e456c28e38ce2a4d0c52a95181ef4cf03a6fe0ccaee9275c6723bd3f8e252143aee2075ae0b150db93033efcd1aa36b7518a5a8d170bbec0b22c414aa70d8ebed482e8b1b808066b4b3c6197a026955dc2a06e5e36f7a09458c92423915b76c3c9ebcd4e368c9d85792719ec2ac6819a566404f1dbbd5c96851509424f5fb52a85a4c7965a36ab3786ee35d82df7e99693c76d34dbd46d91c12a36e727214f20638a61a31f0d2e9facfefeb4bd92f5a01fbb9ad9d5523979c9933d474e9f3f159b818898aa9c2f5144a4e5898d97033c76a243a2365650db",
            "7383576707d4b9fb50f0c4d905b048e868deb4e487a4d102a08c8143f96cac4e7009c9a33185ae6d0473508dda048cb296ddda83bc9599d957182302984fb506719f7a0ae3c960a480483d050d09976a133593b02ca73c64835281be96c6fa33e628b988205527048756e7f4a60dca1505b774140ddb6d56e0f1ef53868c7292ba40d75a46a56569657579653dbc17b199edde44204c818aee5cf5190452f901c1273f9d3296f2eae63b75b9b99278edd3cb891dcb08d724e1413c0c92703b9a04ab3b118247b6296d1132db7da06dcf38eb56cd31f28faf7377f9af430c6c83b1fbd3df125c783ee3c2fe1eb6f0f6937769acdbc320d5ee269774772e5bd05064e005ce781dbae324b690665a376dd9e00a6d6712cca09e99ebd334910e24009e29c417184d8868f17722bad07085918e07a074f9a2f48d2756f11eb76fa268966d797f724ac50a90a588049e4903a035547b8c3b77006a9f325b6992681de1950e4488c548fd3a5696f5a1f1be3a22c66b6b87826431cb1b14653d883822b59e13f0e5df8ab59d374ab5bbb580df5c2dbf9924e80a64e09d99c9fb77e82b0ceefd0e777bd176b2cf6cd1dcc13bc52c6c1d1d090cac0e41047208354b7d89cbc23ed7fb5efd94c9e0e8f46b8b1d662bdb69e336dffa968eddd5900248cb6083bbb74efd6be39b3ca99a262a4a9da486041c7b11c1adacff00f1a7ed4ee1ee12f6e7599346d33ea2e1aee703cb55fc6577119278e9c9c73584dae73b78a742d469ed8be492a91abb6b9d32ebc2cba25a78764b8d75eebcd5bd89d999a20bf80463ed9cd65aea23220c0e49a64ba66b165a45a7881e378ac2e6692de1b859172ce8017180770c061ce3bd116561a45e685ad5edf78860d3aeac6246b4b3922676be62d82aa470b81cf3ff007aab5bb1792b92e251a2f85b5dd674fd5751d234a9ef6d347805c5f4b18f4c099ea7f4278cf009e80d0326c2a4eec7deaff0dd9789759beb8d17c3505fdd5c5dc2de75b59eefe3449eb2180fc4a300e0f703bd2d91888d483cf4618a1521128be48addce70bd8f357a1dcd961c55018e412a79abf77b914c8d366de28f1ae8383915027d55ede01209e053ad0cba2dde7debcec0a8f815004138cd48a6e438abf02e492f7141c907a62a1708f05ba348b812aee5e7a8c91fdc1a69a558d8df5f5b4377aa436313ccb1c8ce18ec52402dd31c67b915f58fda3feccf40b5f0ed83e84258ef6152a908df39b98802ef261413e91962c06dc1edc564cb91475f254a4a8f864770570a5c053daa9ba9594ed1f87e2a0e82398a2c8b22a9e1d73823df900d5c55655392091cd67b725467ad94dbc85589272315afb9f0cfd3fecd6dbc6835cd3a4fa8d41ac3f77a499b94c26ef30aff00cbdbf31ef58d71b78cd32d1f4d8b551a809f58b2d33e8eca4bb4faa62bf52c98c4498eaed9e07c50ac8e2aac626c001324a09e28d428148c838ed4046e32003c1a254057fbd1c240b9594b444ca5cb704f4ab10efb98c12a809c73d3ee6b9247cb328dcb55296320c1e71d3ad2de98ba1dcf69143793dbc73c37091b1412c04947c77524038fc8552d88482ca0ae31d689d5f43d7bc33a8269fae584d617324493ac72800b230c83fdfec4107914ba52ce3248c7c1cd3a32b5a14a0dcabc176a1f491bc6b6f76b724c6aecca8ca1188e53903241e33d3da817949c2e3344dde98d6da6596a0da8d9cdf59e67fe9e19774b06c6c7f1171e9cf51ee2970621f24d29cd8e51e2829264688a81c0eb5549b810eb9dbfdeb5be01b2f045f789233e3dd52eac347890cb20b484c92dc302311291f8739fc47b0f722906a2ba7c7a85c9d39a7fdde25616e2e71e67979f4eec71bb18ce38cd45bee2e2d260a932c6858939ec28696e998fa7815199c63d273542e3233412c8de91a2ecb926910e55b1f146c77a0a90e32c79c8a03d23201fd6bc9e96dd9e9551934038a9771bc171b47a83658f1c568f4ad0357d6edefa7d2f4db9bc8b4fb737574f121220887566f61fec7dab2b6ccd2b00a41cff004a796da96a56115d4365a8dc5a25dc7e45c2c133209a33d51b07d4bc743c56a8db56854a0aec657307875fc2964d6cf79fbf3ea1fea376df24c7c6ddbdf3ff007f8a59240d9002e41ed9a1da600009c007f3cd1714e1f671823e6a38ecd18f8c748e881b6e5400c38033daa787c608cb7be6a664466ceec628bd3ec6fb56d56db4dd32d24bcbcb9904514312e59d8f4005470a1c95ee80d01553919f807bd44b83c6707daaebeb6b8b1d427b2bb81edaeade431cb14830c8c0e0a91d8822abfe1904370ddb344a1e49cf8eca2595930704fda83bb3bd480a4023144dcb60e339ff005aa229c37e33c67bd54e3a2ed65a926030b14628579e99028d9368cb46096e9d2acc425f2571edda8e8a385d964901f2c1e501c122b2f10e2bc210a24fe619157af7e94ca385d1d5a43f24539d66e3459b5676d02c67b2d3885f2e2b87dec08033cfdf341baef3951d07156a3a22548b23640572c79ef5a2b9b0d1f4bd474a797548f55b49d239ae96cf2af1027d51e5b8dd8ffc562a573090771e689b6bc8e51e595230383ef56dec2e763fd5e4d326d6af5b438ae22d2da526dd6e58348a99e0311c668bd67488348b9b5820d62cb53f3eda39da4b462cb1161931b67f9877a488e7a6303deace849356906aaaec6fe31f0eff00c2fadc9a59d56cf53c431c9f5164fbd3d6a1b19f719ac63c255f78231df27ad376daeb9278f7a5b3afe2c11c51a467cb1aaa6569205562c06e1c50172ad345c76cf34448acc3d43d2055f77632e9",
            "77f3595dbc4f2458c98655910e40230ca707ad1b57a665f49f711a44c9856ebda895824126e03d23a514b08793790140a3f507d3bcbb71a7a5c2e2251379ccad9979dc5700617a601c9f9a8b0d770d69ec4ccbe4ba9c73ec2bd326e8cf000f9ab18077f53819e4f1d6879a63e5f939e9fda8651a064e498bda221b001fbd170b844519dc7fb556a17772ff006cd4072ed83c8f6aceb5b2bbe86d1df0897cb71eaea0d5534c5d0739ea49a5eeedbcb0f51f715c1210793cf7a2e77a191b416a5d949ce73fd699e9e2da4b9823be674b7322f9a630372ae46e23e714a239199f38e29ac59118e993fd2b4e36a819cf8c46576f676da9dda68b7370d625d922697d323c7ff501c73deadd2f49bfd6753874ed32d65bbbbb83b638a25dccc719e07d81a531ee390c71cd32b1bbbcb0952eec6ea6b7b88b94961728ea7e08e45694df11339bab289a236b23472a32c88486561820f7e283b95dea5b1c7b8a3676de59dc9766e4e7934136e7403a03d050bf81d89a6ad93d22feff004ebc177a6dfdc585caab279d6f2b46f8618232a41c1048a894f286d24e0d542078c939e739c0a9bb96003705692dd0cecec2ee7e83ebe5162d335b06fe119942b91f201201fceaa10b3bb7968ef8058ed52781d4d2bf325f38e3279e94d74ed6afb4a6965b1bd96dde589a190c6db4b230c153f06a2c96354ad014f22a12c48cfb50826dcb8cd46ea4591b8e4d03b886eb4ac995d896e86a939e09391f144adc058d87998522aff0ae836be22bbbe82ebc47a6e84b6b632dda49a8c85167740311263abb6781f07af4acfb4c5971d3f3ab59e9516ddaa0b9270a4957c1f7f7ad57867f689e2af09ea106a5e1cd4e4b4bc4b092c1a470241e5bb13801b2060ed23d8a8fb56149c9e78a20480a90295cf93d828292379642481f352789636cefe41c60535f0ef8baebc3767ad5a5be9fa6dd8d5ac9ac647bcb712b42ac725e239f4bfcff00b0a52b2a052ccd4c4d301df8069812d9354ec2e08c631ef4707577dc7057e68795d0310ac31d8d2e49772d3f00caacae3228a47dce3761b1da860e3201a36d6eac2df4fbf82e74d173733c68b6d702664fa660e0b36d1c3e5415c1e99cf6a5a75d8a6ac61ade9da8f87f549348d56d3e9eee0dbe645b95f1b9430e54907823bd077d61796174f6d7d6b3d95c2e37c53c651d72011907047041a090ee5c9ed475c5fdd6a170d75a8ddcf7970f8df34f21776c0c0cb1e4f000fca996df705aada23737d7b753092eeee4b99422c61e672e42a8c2804f600600ec2a11939e01aaa589b770700d1b6876e55bb8e3e28e09dd16be5144aadf89467ef5131ee88385c1ef4ff4dd264d4b53b6b508ecb2b852235cb633ce3f2a5a4a412346c4657dc75a64e093d9539c5f6028f6807d2466b9285c0cb673ef44390c876af0a39a026f48073cfb5679685c76eca1b1cd70d709c9cd7a923cef3c1ae920b64715c1cf19af1a840cb5211830eded4ce0bf582ea2b830c570b1bab98a604a3e0e70d820e0f43822a3ff0010dfc9e1087c3063b35b286e9af16416a8272e5769065c6e2b8fe5ce3f41858b136464fe75a21269522dab45f25cbc972c4208d59890a9d073d056934a7d1bf734a668afe7d6bea62fa78902fd3bc5cef57fe7dc4edc63e687d23c3da6ea1e12d7359baf1458e9f7da6f95f4fa6ccac65bedcd83b08e3d3f9fce0735343e21f0578891258a7d2b59b075902ca9b6489b019490477041e7de998e445a5a419ab5e5b6a3aadcde5b5841a7453c8ce96b6e58a420f4552c49c0f93435a5dde585e437d63732dadcc0c1e29a2728e8c3a3291c834b05e492cad3dc3977662ec4f524f24d75ee497c82718e95a2325240e29caf8a343a64769ab5f5e4faceb8b67279524fe7dc2b4a679073b491ce58f73496e2e107ab39f614b6695ca6ece31ed43b33b0cb3f5e69529d68b9ed8d8bee8b29924ae3ed5505236e7ee78e05516e54a925caf6c03443b6fcfb76ff007a9768cf6e0e917c6a301f2194d5cd39521147e2f6a26cf5464f0bdf68f25dcca93cf0ccb0244851ca8604b31f502370c01c1c9cf4154c69093b4e001de82b63e1269d943f9ca80bf73c1cf5abe39588193834d354d464d66ed66ba8edd1a3863840821589708a141214019c0e4f52681c0452b8c903b5451344727962e92e37c24151c8aaed432cebc01f1ee69adeeb97975e16b3f0ec91db4769673bdc23242a2525860867ea47fdb39c0c298f6374382bd3e6934ec1e6bbb193cd2a302bea39e82ac7bd2ee117049e08aa74ed56f347d5edb53b4d82e6d645923dea19720f707ad073df5cde6ad737ac55e79e4691ca80a32c493803a0c9abda64f52c6658f92039da7b8a1dde3cfaea8964648c169396ea0534d72d7c370f87341b9d1f5b9efb55b98a43a95a496c625b370de8556fe7c8cf4f6f9c06c740cb2de90bca99644b7b78da5772102a8c924f000f9a2f53f0fea9e1ed49f4ad734c9b4fbc4019a29936b60f20fe949e39668caba92aea72181c10698de6a97faa5d7d66a77d3dedd3a80659e43239c70324e4d6883b604677a226318c018cd53342514bb719a2d5ce0038033d6a6e14c6436307a7cd39a31bcb352d90f12e8da6e95a3e877963e23b3d567d46d8cd3db5b860f62fbb1e5be7be3fb1e318272ab1bb3123927fad3736e1e4c00769efed5e16644aa547a474358a78e4ddb3572ad314b5b306f5123e2b9c460856c31a6d7000209ea295ca3d448e452651a097c956194839eb538c069573c0f7a81208001e69ed8f85f5fbdf0b6a7e29b4d39e4d234b9238aeee432858",
            "9a438404139393ec0e322968bb1742c8b2e5795e94c6039976e303de82b6456dcddfb668a859525c1e31c11ef5a60e90ac8ad06a0f2e53e9c8a306a17169a6dcac31816f70163909881c904300188f49c807820fe545f8760f0e5cf8a74e8bc4fa85cd868924805d5c5ac7e63c6b8ea17ef8e7071d707a51777e3286dbc1daef82879fa8e8925c1b9d35d82c2f14a18012b800939407d19c027ad31c9a5657a6a4adeccddbbf9e37e78c74cd5770fb18e531f6a5f673bc4c413904f5a6370c0a2367711d850f36d0d863fa92590ed24a8e9c1ef4195625d891c0f6ad278d7c56fe2df123eb6da2d8e91ba18a1fa7b08f64636205dd8f738fed59877013860779cf3da8252bee33ef298ce49ee3dc8abe6887d3ef52323ad3ff000859f852f351993c61a9de69960b6d2b4725a402566982ff000d483d89ff006c807233f3602300c4a31fd296992f42c98af55ed43f53cd12eaa0100f7a1f1ce0f14b90074363b5136964f7305dce2e2de216b1890acb2aa3483705c203f88f39c0ec09ed44ebfa7e9fa5ebb7163a5eb316b36916dd979146d1acb9504e15b918248fca9650902b4fb44bfd5ad6ca4bb86cd2e26489ae27388e10cc06f623a28ce4d17abe929a5f8a2f344b4d52cf53482e0c097b6d27f066e701d58e3d27dcf14aabd54434fe39f04eafe00f12fee1d66eac6e6ebc88ee37d8dc09936b8c819ec7e08f623208272f927a9ae939eb5ea851d0ec3b9a3b468f4b9f5ab38b5cbb9ed34d79545ccf6f1096444cf25549193f9d19ab6bb6da9683a2e990e83a7d84ba6c4f1c9776c844b7859b21a524f24741fe0a49835364253ac4b3bac0ccf10621199769233c12327071f350c67a0aef35d1c54a204c386423a63bd5a2375038520d08703a118eb9abe29c1c29cd3e2d7664b0a7215163cf18e6bb14a0f0b8e3b9ef424f231382d9a362bfb25d125d3ce9b1b5e493a48b7a5db7220520c617a60920e7e28f9d32947e4fad7ecc7f681a5786b589d2e7451ffae548966b524c8873d30e7f09cf3823a0eb585f17f8a2cbc4de28d5358874182c96e5f2bea62e3000dc70429638c9e3a9acec178d6f769346ccb2210411d88af48032eef7e6ae494a5c90b969d7826fa8bc9a74367e45baac4cec245880772d8e19bab018e01e9938eb4b1d59c648fceba4666210f1f35df35b6943cfcd25efb96a35b40c460d72a55ea50c0b934cb88b46b7d559e0304f2bc2aab3299032852494cee03d43048c1a2f40d2acb57b9bb8aff5eb3d1920b592e124bb572267519112ec04ee6ed9e294d754126a5109a0c9193d28873c6131552a8c703f335c553bf1934e569165c01c67af1c512f2492c8d35c3bc923f566249381ef5db687ccc67a8a62346d45f4b9b5386ca596cad995679d572b1963e904fcd3d469594e4bb0a3ce0cfd71ef56aba1c8079ed4d345d2748d53585b4d4b5b8b44b531bb9bb9a2691430525570bee46290a6379087f3a152717448fd10448a40dbbb9eb43aafafd47f4abf256239fc5f3da850c72c33fad49b5a61f7d9ddcc9375e055ef26e181c1c773553485970074ea6bd14264cf3c8e7ad2fe885cabbb2ff31914e1ba54d6f887c0539ef8aa67f51da063039aa503f9800519ce38abb698305e47a939920f337609ea3dabc2f02a0241627e33432230429eff009d56a8eb30500e3bf7a649b2d3f70c1d21de06ddc3ed50112b4bc30cfb1a8c7721dc151d73da9e45aedac3e129f421a2d8c97335dadc8d4990fd42285c7960e7f09eb8a6b4bba33ca4d268cf5d2a900b11c7142aab37aa36f574c0a633ed2a091cf718eb4fbc33a8cf3687a8f83ad74bd2de5d5a54985eddb2c6f07941988576200040ff004ef4a94764c726d084db3880b4b8ff006aa63800c966c9ec735a1d6b47d4b43bf874ed512259e4822b95f2e5590149103af2a48ce0f4ae59689a96b097674dd3e6bbfa3b77bcb8f294b7950a6373b7b28c8c9ad2a2aad15ca515c5adb339962e415e07c75a9321505c751fd29e68fa84ba26b16fab5aac324f6ee1d1664dea4fc8ff003e297ea2d35dcb35c48154ccc5dc228500939e00e07da81a68a593c03a5c26cc31ce3fad10b2897003818a532472a818071d8d4ada5225004797276e077340b234f64707dd1aaf0f0d057c51a70f147d48d1bcf5377f4b8f33cbcf3b7fcfb50faa5c69bfbfaf5345f3db4e370e2d44c332795b8ecdd8fe6db8cd6ab44fd9cde3f9575e2549ace3e196d00daec3fea27f0fdbafdabeb9a23e81a344b158e89058718324080b1fbb1f51fd6b95d57dad0c7ffc9727fa1d2e9fecf965ff00ed2e3ffa7e729fc3fe24b940d6de1cd4e55c6432da487afe548efb48d634fcfd7e95796aa3d47ce81d38ce33c8f7afd9d0df5bdd7fecdc873ec5b07f4357b1254a31254f054f20fe55c197dbb9397bb1fea7757d8d8daf6ccfc38ca98c81cfc54d679a3864845c48209482f1ab10ac467191d0e327f5afd57e23fd98f84bc451331d3d34ebb3922e6c944649ff00a971b587e40fcd7e7bf1a781359f065e2adf28b8b294910ddc63d127c1ff0095be0fe59aeb74bf68e1ea7dab52f86733a9e832f4eb93daf93309318df2b8da7a55ed70245dbd5a802dc8f8a9a72dc12315d252f073da416259630509247f6ae4b36e88edeb55317299238aa8b3fe1c63e299cab45a6bb22d80b8c9e4f6a6487383ce78eb4be30db7db9a211dd9f1bc63e2ad3a44bad0ebc4be26bed7ac349b5b98ede21a6db0b48bc98f69740720b1ee6b3fb5de3c8c7a7835d9a60cdb400587b550ec50f0df3834b7565176f71c93c74c139a8fd44a",
            "5446a7d2a6a01832907927e6bca0b3614601e0d5fdc53654c79e2aa3c9268b9230bdbe2a82b9c903814328b0a8aebd5eaf720d0147aa6914b2eef2e367d8a59b68ce00ea4fb0a3352d6752d5fe8ff78dcf9ff456c96907a15764499dabc019c64f279f9ad343fb4df11d9dac50699169da705d24e8d235b5a2069e12724b939cbffd550862abd5eea6a5b703e6a108d74135c208af542c26311fd3962d839e9541183c1a90e1786f9ae9e538e4d1bd94555ee95a3f0f8f067ee4f10ffc4bfbd3f797d20fdd3f45b3cbf3f70cf9bbb9db8f6edbbbe291dac304cf209eed6d82c6cea5959b7b01909c03824f193c0ef404292c4f535c04839af57aa10bd64c7a875ad5f82ae7c14fe2323c7ffbcc68e60939d376f99e6edf4673dbaf4ef8cf19ac68ab923cae738068d36f4534bc96ac70c976e202fe56e3b37e376dcf19c719c577c9f51c104fcd5d259bd9cd10f3a1977c6b2831481c00c33838e8c33c8ea0d5c2303f19c8ed4c8c6d01275b15b28c91d08ae0898f27814c65b55285c37e5559538551de8783229df6065b7df1ee5ce47515580caf46b46c87663afb55b1da123715c11d3bd4e0573adb03dcd91cf15340ce0e09c8ee3bd316b252a0e0e73d7deb91db3f5271c118f7a6706983eaaf07ac4ec2136f2ddfbd1b3dd5ec36b35945752a5bcc43bc5bc85723a647438fe9541088c3638dc066869de4399666201a73d4681ef2b452db981563c62a908a8770e7b571ae41e3b7bd56d3295200c1ef48725dcd0afc91691ba0e4673500deac9e6b84e4e71d6bdde92d845aa4b1c01c53bd0aeff76eb16ba8c70c33c969324cb14e9be372a41c32ff00329c723b8a5512a6d0d9fb8a3523381b4123a8ad18d79024ed0db5ed4a4f11f89b50d6a6b2b5b57bd99a7686d22f2e2424f2157b0a56f0c492876ca8c516a48b7c0c7aba9a84909bb6b6b682dd16563e597de7f884b704e4e075038c0e298d52d233c5b67adca3670c5b278a27e993218903bfdeadd7b44bff000beb771a26a091c77768c15c45209149201ea383c1a0dae76aed2c09f6cd5c69ad8ca7214c6ef9c0eb9f7a26177f3012324734be22c58f6f9a390ec4c97392714b86c6b8a6a834c8cd1fe107daaa7954901060fbf6ae2f2319c0ee0d56461f3b72075ad0d68a8e2515a084ba48bf11f50e05110dedc2b1114cd1aba9460ac46e53d41f71f14a1d7736482467b55f0b153b70411ce697cddd099c28645fd408e4d5aec318900c11d2874590aeeea055f1879225c12056a5b6038c652433d0fc3da9f8a752fa2d1e1496e123326c79163c8181c16e09e7815f49f05f81ae3c21a9cdabf897c3b78f711fa61912359a3847fcfc672dec4741f3d337e11f0c685aa5c6991cbabcc6fe4ba63736623d8a96eabbb7893dc918c7cd7dfda36c3186e27b56639dd048579fea0fe95e57edbeb5627fc3becd6fe7f3fa9dcfb2fa49646f342bdaf57fbf00b6faa6997e4c30ddc523f7864f4b8fbab7350b8d16c65ce223037ffd671fd3a572f62d526d8648f4cd5d57236df5b84908f875c81ffc69735fda69c50dcd9eb3a3a670ca98bbb6c7c1e703ed8fb57938e357fc99feff007f43d1cb24aab363fcb6427f0fdd27304a9301d01f49ff006aad2ff53d36178658981246d330276819c81ce39ff4a7d657916a09bf4dbdb4d4d7ff00e8936483ee8dfee2af69a20de4ce0c2c7f9275db9fd783f9668a53cb1d648da0630c527fca9531341e224e05d5b95ffaa3391fa1a26ed745f10e9771a5dd98ee6dae536490b1da48f719e84750474356cfa3584dcf93e4b1fe68fd3fd3a529b9f0e4eb96b799251ff2bfa4ff00b52d7a327717c58c7eb455497247e64f1cf83eefc19e26974d977cb6ae3ccb59c8c79b19ff0050783f23d88acda0231c7debefbfb4dd02f6fbc2324b7114c26d3b33c45b91b780e01f6c73ff00e35f0153eaceeaf69d166f57127276d1e4fabc4b1e4692a414ae8ab97c735c31c6dc8cb1ef8a1588ce01e2ae8093919c67a735d14edd189468928718e7d24d5dcec50c707e2ae488b00187e42b92c4559700827a8346a235d2d3017568e4dd9e6a19324993c9a3624845c2fd5eff002f78dc108ddb7be33df145eab1691fbe2f1f41fab3a5195be97eb7679fe5e78dfb7d3bbdf14be2ec0b1645b449975ce38a73a05c68f63e25d3ef35ed3a5d4f4b8a656bab48a53134d1e7950c3a7f9c8eb4b5600d919e3e2b8cdb06de320f4cd1a54b65724cbf5892caeb57bcb8d26d1ecec249ddededde4f31a18cb1da85bf9881819ef41416b75773793696d24f22a172b12162140c9381d80e49a2a2667c8e0003b55b657f7ba65c35c69d7535a4ed1bc4cf136d25181565e3b107151c6fb113b7419e12f0d5a789b589ac2f7c49a6787d23b679c5cea52148dcae30808fe639fe87af4acf100b6383cf6ad37872cfc257a755ff008b355bed3bcab291ec7e92dc4be75c8fc08d9e8a79f6fb8ef99dbfc4f4e714b6b630f08cb31c74a815c2e6af3b532ad939e95d489a5e00c0c55f1bec4a2a8a1676e9c0ab9e301b3b48fbd150c2d1a290a39ef5618de5c2ed19f7c734e8e2d05402c8a41e3f5aa8459e3765bda9a4d64eb682560492707029681b5cae39155931f17b453454c0a3153d68bd374fd4355bd4b0d32c6e2f6ea5cec82de269247c024e1541270013f6142b658e4d596f7371673acd6d33c32ae70f1b15238c7047c5670195b8c1c63150ae9249c935dcf5eb544235d1c9ae57475eb8a944185f69771a66a92d85c34324b163718255950e403c32e41eb44e97a55fead76b63a5d8dc6a176c0958",
            "2da2691db0327d2a09e052d80e3387da71d69b689e20d67c33a8c7aaf87f55b8d37518c32acf03ed60ac30467d8d363a440411f92feb52bb5b0c84608e6ae798310bdbe29735d4b2ccf34f234b248c5999ce4b1272493ef9ae2dc10c7278344a680705dc3d254c94e9ed45d9d8ddeadabd9e956101b8bcbb9560822420191d880aa09f7240a50b21691416c0a30921964472ac841041e463b8a352b446921f7883c35aaf85f5ebbd0fc4164d67a8da102585d958ae5430e549072083c1a5a656f2f6818c74155cf7b71772bcb712bccf21cbc92316663ee49e68412b799b07ab279345ca8cfc6f6c6493bb42ca3a0ec454b92c030d9dce45556ad97dafc638355ea170b105f2f21cf514c725c6d8ba4e5491d68bce946c6195ef8a656be1ad5f5bf0feb5abdaac2f6ba34692dd17995182b36d1b41396e7dab3497277172e6a2d71924374e949791346b8daee0cdf888ed4d2d7c39aedf6817bafda693753e9560ca9737691131c4cdd016ff003a8f714af82783c7cd6db55d6757f0968d79e0bd03c6a9a9683aa4515cdda598c46ce5412872320f0b9c119c2ee1918194618935cae8241cf7a6be23f106a5e29f105cebbab344d7973b7cc30c4b12fa5428c2a80070a2a105b1b9dc0138e7ad34b7b953fc36c9cf7a50a70c0fb51514b97cf0314dc72e2c192b1d974841c8dc0fc552a03b060c029e4026a8fa8f4aee1c7b547767a301ed5b1c9329410f7c392786478a601e2e6bdfdd1b58ca6cb6f99bb69db8cf6ce2915d343e7bf94584593b037523b671de9c6bfe0fd4fc396da65cea2d095d460f3e211481b038e0fcf23a647cf0695eb1a16afa3476373a8d9b5bc57f00b8b62c4112467a1e0f1f9f359dcbc87ab0b97c3df4be0cd3fc47fbe34f95aeee64b7fa28e6cdc45b003b997b039feabefc071c21886c8c7539a1ade10d2ae467df14f6ce18da3c3fe40d370e36c194b82b04f2c06c9e4fc57b0abd793fd28a9a1dae4a83d78a86d2cf82b815ad45a0a13b57e0112205813c8270451115b924053c671d2ad30ec53eadbba89b6842ed6cfe1eb8a5b86cc5d464dda34ba0f83c6bde1fd56ea3d5edadee6c957c8b271992e998e02afc9380319e48e839a5f71a1ea1a2ea9369baadb9b6bbb76db246d8ca9ebdb8c63b8eb55c2e778299057904718a29e6b8baba7b8b995e596462cd248c5998fb9279269d083e577a303caf8f147d5fc29e02f2649b57d3356b2d52092154568721d0e4165604718feb5a4bab7d434a58cc53921972c101214fb10457cefc01af1d06eaf89b77904e10e55f6b2e3774f7eb5f59b3f1868d7ea23b8911643c7f14796dfaf43fad789fb5566875328cd725add7d3e9dbf23d97d9ca1fc3c5c5efe8f7dfebdff311c3e259158adc5bac807f346769fd3a535b6d6f4db8202dc889cff2c9e9ff00b530b9d1349bf5322796c5ba1fc2c7f31d6b3f79e12923c9b798affd332f1fa8ff006af3f286196daafd57eff23b90cb913a4efe8f4ff7f9865e787f47bf7134d648b2f513c27cb7fbee5aa96cbc41609b34ed73eb20ff00fd6d4d3cc047b6f1cd236b6d6b4a3ba359a341fcd19dc87fd28ab7f145d2605d5ba4c3bb27a4ff00b5450cb1578e568294b14f59634c34ea5243e8d4b4bb9d0c8e7eaacfff00516e7ee98381f97e746c57974f6c6e6d0daeb702f56d3df128fbc6c7fb37e55cb6d7b4db8c6273039ed28dbfd7a55cfa669d3dc25e8b7459c72b710131bfff0025c13412c917acb0fdfefea5c71496f0cff07b075d5748d4d65d325b810cb32189edee54c5261860fa5baf5f9afc637701b6bc9ed8e498a464e463a1c7fa57ed8d52d21d53ccfde36b6b7b09500095763c58ea564193f3c8afca1e35b2f05c5730df783f5bbabd8ae59fcdb5ba84ac96e463ab70181cf181d8e4d773ec7708b92836eebfb9c7fb51cda8fa8a9abfec64289b70a725bad521723eddabc1d9780715e962e9db386301724aecc74a8cb33bb8218e4f5ab740d2e6d7b5eb2d1e0b9b6b696f2658966bb9445121271966ec3e6a3aa7d1433c10d944e92c11f9772e6712acb2866cba1006148db81cf4273cd339e816ac1301c8639a9ac8c800078e9cd0e8f8704f233d2ad9761f52f19a14f44fa1699b08483cf4c0ed54edf358e7ef9a8c492cd2ac50a3c9239c0540493f602b8acea495e0f4aa72b2551706789bdd477a9b90c432f00f535cb75691fd47352923f5614823dcd315d017ba2431b0f42e7a5762b762a41fe6fe6a8a2b04c9193ef46dbc8a106ee4e3b0eb4fc714dec7c12069acbd3945fb7b9a32dec66b7812e981656ce00a65680163216c0038079cf3ff007a6130b68d1434a03641f7e6b747a687f5a649b49e81350d534bd4e3d362d3742874a6b5b6105c4892b39ba70493236785273d050e20884e3cbf53631c54bf7797576ce11ce4102ae82ca4b75059c0247a79c63e73458f149249a2af924cf5c42e11a0c118c60f18acecd6ef0cafb8673c038f6ad15ccceb0b286dc1490cd8f8f7a4b7b73b9300f4e055755c1efe0649db1316d921c8047b545886390315238924c85c0a9bc3b41c73fe95c4a6c5140e3b66af82349643b8ed039c0aacc655413d0d5913188ee00127b1ab8adec944dd5480029c81c715418c8c0ef44177d840ef4333127af22ae744a23d38ad17fc43a67ffa7dff000d7fc2f63fbcbebbeabf7d6e6fa8f2f6e3c9c74db9e7dbe33cd67cedd80e39ae6de33834ba2511af54b15255c9eb5288433cd1914a4ae00c67a573e901036b66af86010b966cf1d334c8c5a62a5254472ce4920f3d7152455dc72a718ea0f4a9",
            "cb226dcf3927f2aa232de61e783da99d980ae8291ca11283d686ba46794632d91926ae572b19d832e0f435191982a120ab1eaa2a3da0169d82b421180c67b9c8a19bf11e734e5204711ac9288d2461be4604ec04f5c7538a1f5cb1b1d3b5fbeb1d37538f55b382668e2bc890a2cea0f0c14f201a54950f83e42daf57715ec734030be6b2bab7b6b6b99a07486e559e172387018a923ec4115505f4e4f4a79afdf786aeecf468f40d0e6d327b7b358f50925b9328bab8c9cc8a0fe004638ffc947b8e315087823704558a300fab3cd703b28c034efc3fa7699aaddde45aaebb0e8d1c36924f1cb2c4d279d228cac436f20b7bd12a04034d7b25d56d4eacd71fbbcca82e3e976f9be5e46ed9bb8dd8ce33c66acbf96c3f7b5d0d24dc1b0f35fe9fea76f9be5e4eddfb78dd8c671c6697be474e9510e54d5f26996860f7ad218d24667f2d7628624ed1ec3d8734ff00c5369629e1bf0e5edbf8b86b377716eeb358147074c0ad858c963820e49e31fa60d65115e4390b93f1577932a121989c0fbd1b6e453ab1cd9c4aec64d9e9e87b51cdb620367fe6868831195c6d3ce3b559b49018e724575b1ad1508f397d0f194b63d5db9a84659d890b8c9e4d438276e7f4a3ed62f2c72720fb8a2a2f271c51a45e969e6448cf8dd8ab84053d00023ef455b4788b9a26da0b79afa08aeae3e9a07915649b617f2d49e5b68e4e0738a2713cfcf349c9a62f86062581381d314544ad8208c83d29beb7a769961e23bdb4d17543aa584329586ebcb31f9abef83fa7ce3340436ccd3a166c2fb51c1693429cf8da6697c16da7c9e2a8edb53406dee233080cb9c4871b79072391d7fd2be8777e0db39326cee2480ffc920debfeff00debe5966d369b7d15e5b4bb2e61904b1b8e4a90720f3f35f61f0eeb8bae6982672a2ee2c2ce838e7b301ec7fa1af23ff0024c39f14a3d5e17aecff00b3fedf91eb3fe3dd560ce9f49916fbafeebfb9979348f1368cc64b1694a0e49b67dc3f35ff00b55b6bfb44d5ac9fc9d42d92e40e0e3f86e3f23c7f6ade55535b5bdc061716f1cbb94a12ea0920f519eb5e4575ca7ffd61bf95a67ad7d152a84b5f0f62ed3fc6be1ad440599daca53da51b3faf4feb4d67d234ad42dfcd568a62c7a81b4e3dc30eb593bef0269d3e5ac6e25b463fcadfc45ff7feb59e97c39e2ad118cda6bc8e07f35a499cfdd0ff00b1a34b064dc254febafd57fb14e1961a6b5f9afc9ffa35f7be0e65cb5acccbff004c8370fd47fb52a8ed75ad1256963819976904a12cbc8eb81fea295597ed0f5bd3e5f2351b659f6f041061907e58c7f4ad8e93e36d2b582d19cc32a21765b850b803afa8714528e482f72b5f9ffe6ff40553ed57f97feebf531de21f1c5f68fe13d4ae6511bcc2168e27fc2c2461b54f1d704e7f2afcc3df9afbbfed23c79fb3ed79af744bad2efeea6b32c6daf6c67458da5d847391ea50d819e78c91f3f07c57a1fb3b02c78dcb8d3670fadcef2ceaed22f0a586d4c71d6a961b588abe0048e0607735d68803b9b91f15d66ad59ceba285c8f50ed4ef40f09f88bc54351ff87f489f503a75b35ddcf958fe144bd58e4f3f61c9ec2952a6785e829adbdd5ed933fd0ddcf6be7c6609cc12b279919fc48d83ca9c720f06ad41b40b9d313ac0c572462a05895c13d3de8db88c348027a48fe6e82ac7d13504f0ff00efd648fe8fea7e977798376fdbbbf0f5c63bf4aa92a2e2ecf683ae5ff8735db6d6b4b9163bcb624c6cea180c820e41f826839a579ee249e67dd248c5d8e31924e4d515605dc07228520d9744d97001c515b657c606463b502018b93ce7da9be9e1a508a060820835a71ae4f8812ec412d66695551401819cf0051fa7e9ee750f2a4656007078ebd851cd6e9e56d270ea0ee20f5f6ad878375c3a768daae90ba7d94e9aa2224b35c40249630ad90637cfa4e7afbf1dc0ae9e2e9ee49214f23e16656fb49ba8c065b62c8a3d4ca0e073c1a50b15cacbb6652cbbb8ddd6b7d258dda4130795d839e15871d7b7e542c7a201280ec02b8e727953ff006ae8cba19ce5ed4c3c529e45f3f805785d3453713378834dbabfb6165224096efb3cb9c8015c9c8ca8ff005e8696ea16ed6e1637895b6f231c66b4579751c3a8462c6c23b084451c7e5a397538500b64f7279c76a4d78aa64320259ffea6ad58fa6928372eeff419d361cf27792b8f8f9339e2382de05f26c354fac85a2491dcc0d0ed72a0b261baed3919ef8cd6258b16c3124fcd7d6fc416dad6b7e0c5d79b4ab58f4cd1512c5e782354de49c86619cb9cb2827fea15f286ff00dc2dc1c1e7e6bcc758bdd4defc8d9aa634b2d26ee7d3aeefe1b59e6b4b555f3ee122668e02c70bbd80c2e4f033d697ed936b31238ea3e28a8356bcb6b4b9d3e0beb88acee82fd45bc72158e6da729bd41c360f233d2854cee3821b3d0567b4d5205f63ca40882b8f57cfb544aa92074ed8353675dfd3d4383f14e7c2bace91a1f8961d435dd0a2d6ece35656b491b01895201f6e0f3cd03d22bb0924520ed03f09c576d6c2f351bd8ecf4db59aeee6438486142eedf603935c2de75cca6180468ec4ac60e768cf0013ed4f3c397facf8735eb7d5745bd92c6fa2c8591003c118208390411d88ab50793fa516937d8510d8169364c197070c3a15fb8ad3f84355d3fc39ac4b7daaf85acbc476af6b35ba5bdeb32a2332e04836f75ff7c1070472256bebd965bcb87b89ee24669253cb3b13925bdce7356df582c504c88405650463fd2b6ae97d9742a7954754651ad7f88c7214638af4502e09ea473ed57dcdb18903efc8c5",
            "4627dca1445918c035938a4fb016dab449d02818e0f638ae48b318417c9f624d4de3915d46d233ce0d1012462a0b2e3d8d1558ae55b146d724b393c57039c81fcdf15b2d0bc01e2ff17d9eab77e19d1db50b7d26213de3ac88be5210c47e223270ac703278aca7945144855a94d53a43ad55975917123103231dc5192b406466dc09239cf352d30319bd48083c03454fa607b632c1110e5b200e9f35a2317c74629ce2a7b009ca98dd656da71fcbfd852d9ace48e3476465de3700c0824763f6a789672cd1889d7d6a09000e7f3ab6fc5f5f9b5faf96e2e1ada116d0f9a72238d73851ec0738a196372d8cc79631d5997921645dc7a66b91a867c138ff005a67776ecdb4608c0c9cf4eb40950adc2f4e32291287166a8cad1e36edbb1fdaab689924da41c8ed5b2d7b56f0e6a771673e83e1f1a3430daa45347e7997cd900e5b27fc3d4d00b25a35aca3e9434aecbb2424ee40339007439c8ebedc53162525688e4d19f6db804741f1515ceef483cd1b3c11818e8715540844c0affe28783ba0d3b19e81e1dd43c4bafd9e85a708d6eef1f646666daa3009393f61db93db26bde30f0c3f847c5173a13ea769a93c01774d68c4a862a09539e4329e08ec45563cd49567de55d082acbc1523a106974a1cc8eec4b9273963d6af26368ba68e5ae430ea334dae248e794c8b0c507a546c881006001dc9eb8c9f92696dac64c9b81e472298c6b0a7ab3bdbd8fbd33147404959206485829241518e78ab85c79a005079a5f717124ac5198b6688b108c7732eec0e99ad5096f8c4351a56bb9a1f0e786b53f12eaeba7691109ae3634982e146d5193d6a9891c3e1b239c106bd67a94da6dd1934fb99ad6700a8785ca360f0464738c1c55f115902b9e1c7f4ad50b6dfc08c99252ffae8696a4185723073819ef52911baf706afb64778d4052bdcf157c9092a54d6971d1e6b24929bd11d3ed2eaf67f2ada0799faed8d771c7dabeb7e1efd95f8ae7fd9cdef8a2d55229322586d482276589fd4c076390703a9c7db3f2db2819148c77ad6e9baf6ad6be19bed0a1d5ee60b69e48e55b759085670dc9c7e43f41552c792515c3e50a84e1c9f25e1f610df69ba859ccd25f5b4d0bc87812c654923ae3355d8ead79a4df25dd8bec993a8232aca7a823da9d6af737dabeaf73aa5ec91b5d4c7748638c22f4c6703804e393dce692dcdaa2c4f3e49e9cf5cd697d3fa9070cab4fba2ba7c8965528b7a7a7e7e87d5b45f12e9dacc6aa245b7bbc7aa076ebffda7b8feb4efbe0f5afced3965823643b403efc8a6fa678dbc4f630909aa0bb55c612ed7cc18fbfe2feb5f3efb43fe2ad4dcba496be1ff0067fe7f33e89d27fc838c78f56b69d5afeebfc1f72af57c93ff00d58d4a0b40d3e93672ca3862aeca09fd4d20d57f6c9e237876d8dad9591208dde59761f6dc48e3ed5c17ff001feba2ea514bf13aebed9e95ab4dfe47daf564d20d8493eb6b6bf4918cb497580abffe47a7e55f9cfc75e2ad0a5bd7b2f09453c56e32b2ceee712f6f403c85f92727d856635ef10eb7aedd0b8d5f539ef48fc0247f4a7bed5e83f2149bcd5382dd715d9e87ecafe19f2c92b7f1e3fd9c9eafed279d71c71a5f3e7fd143c6770e319f6a69af69da2d85ddac7a1ebffbe6292d6396693e95edfc9948f5c5863eada78dc38340b3aaaf032287ce5b71e2bb2d1ca5619a569fa86aba845a76996925ddd4c709144b96638cf15278666cc6f0b23a9d84370411d8d474eb89ecaf63bab4b996da5424acb139475fb11d2ac33066e492d92724d1457c8b93de81f6346e130d9cd1fe46d458c6189e58e6bb1611f1260e790f9a3e02a186e0cf9ea7d856bc58930e31e48432a4c1801923debd38e392738f7a3ef648e38f7795eaddc64f6a532cbe6b67685fb52322506d0555a2b23e6bc3ad72ba3ad662c26de359678d65dcb1ee1bca8c9033ce077e2b63e569363a95ca6912cb73a7a4a4413cf188dd97f94b282704fb66a9d3afed6cfc3335845a65bcb7379b4cd77711abbc3b5f2be49e0a641c36739f8a2a2b12da7b4c02b63aae2ba9d2e3a7c8cf932455291eba8bea77f94446c06405e01a2fc3c97304c1483d0e0035569b716f2e127708d8c151c62b41650a432f9caa43f5e7b0e98fcfad777a3c5cf2a9a0ba6e7ea706bfc0ced2645918c8a1c6380791ff006a16e6e95665643867382aab4c75abcd057c27a7c1a6e9d751ebeb70cd737324d98658b1e950bd883ff93918c36a3ab8b7937dc00de59f49040fcebaf97a98c13724d57c9d4508727969a6cd04d72527533ba92471f9566eff00522657405761e86b3f71ae4b71a809999b6761bbfd2af976dc45190e42b7a9b3d4d72337da0b3271c5e0279135510bbcd6263e1e93418f625b4b722e4b12779655da149ce0af24818ea6b272231976b478c718f7a633c448037602f419cd0d3c2c8a8e41d87f3af3d9d726dd192602d1321cb0c66a2090720e0d10cbfc166dfd0f03bd5691928ce7b56171de851103d2cc5b9fef5c271c673f35200b6d50064d4fe9e4ce1860d449bec4ee4ec582cf9dbb89e95a6d36332de2a2a6d76ea7d8526b2b62aea5c6dd9d735f4ef0ee8fe11bdf0d6b97dab789bf756ab6312b5959880bfd692795dc3a761f19c9e05753a58b8a4e5f2338baa42f3a7476f32178cc7b8e431e08f62284d7b75bdc2476c1645201f5724e47734f6dd2d2eee2dc5f5c4d25b861bca30dfb33cedcf19c74a9ea1a25bb6a2059b4cf1caa2583ccc06da4e141e719c6338af4393045c1a8f9d812e9d2c7ea4be0c05d5b4970b960215e8c3e6858a15853",
            "6230249c03f15a9d5ec6e23bb920683cb923631c8a181f5038238ebd293bdb2c6eb1e30ec33c76ae1e4c0a2ed193db15dff02f7f0cebd3f842fbc4b05bab69b653a5b4d3091410ce38c2e72474e7e47cd258ed66122056ca9192451d22807ca5918a9604ae7a9190323a6464fea6b96f2b89c4654f3c64d65e172d8be4abda5b06a1abda595d59e9fa8dd5a5b5e288ee628646459947215c038619f7a00ee781a258f2472c4f7a6e62763c3632739c74a9b598927042f18c9fb568f46916e518452901e98caac23248383e9db9cd38b6291dc34722944c6063b57a1b150144037b77dbc1c7b67b532fa143653011112ed192c7e6998f1ca8e466c9194bef17ceb6967721e060e5b3804f5e28799cdc86f3576c99c0d83146da584d130b8919bc91c61bdcfc75a0aec84d58bc6376720039e7e7a51ce2e2ad86a0a2e93bd77fec2b7b37916455de5792ac79cd090d8b3b98a44e3a8c53e5668b734f1aa07e793415dcce906c5654e49049e4d21c23dd9bf1659bd096e62113ec51800f354adc884654127be6af9dde5936b0da49e5b1d6ab68032a803a1fd7e6b236efda6e8cb54c6bab6b235cb4d2e2fdd5a7589b0b616c5ece0f29ae3049f32539f53f3c9f8a50c42c615720d196f6ea339e0018e9449b18c421b695ebc1a643149ad17174c556e24e49627de8e8e08e77489da38cb11ea638519ee4d506074976a1cfbd5b0dbc85d8b2923ae4d32116bdad1a56bb85eb7a6c5a2ea773a6c779697de4b05fa8b297cc864e33956c0cff00b8a06383744a55cee3d07b55eb13676b283ec31d7e450811e09f7339073db340d53da132a6e88c76cb2ca7925851f05be25d91f1c753c5721818cf83ed9cf4a3e177b57dce015c1e3de9d871abd95197bb8ad94983612fdf14659a34920c6707ad46156998b95cab74c0ad4c09e1e1e1887cb8f50fdfff0052c2456d9f4be4638c7f36fcf5ed8adf18ab541659a517141360aa635f51c0c1e944c918cf4eb5658c39014291d07c514f6f80370c906b6f05c74787cf2873b457690e4640c530b6b704c64f5078fd6bb6708db9c6298c36c5800dd39cd69c58ce74f2eddba2c6857f94606281b88972147079c71d699c7084cf1cfbfc5573c388db68ce7b67a5697142219230c8e9d991bc85a73e4410492b13c2c6bb89ee70052cb7b5b76764de5463a63ad31bd8ee565fe0392c091c7047c71403010c51f2a665e369eb5cfe2dcddf63d6f4b0738f04eaff007b01d63f74dbf87af217b5b86d41a54304cb2811a200778298c92495c1cf63f9e04ab34a0b1e08c80475ad8eb16f3dc408b37258e42a9e9436b7e191a6785f47d6d756b0b96d43ccc5ac32ee96df61c7ad7b66b8dd5e3a99d9c30a8d598cb912208fcd8d9438dc8482030c9191efc823f2343f070071f7ad1788bc5faef88f4ad174cd5ae967b4d12dcdad9a08954a2139e48196ec327d87c939adc0f51cd71a4f7b34505955f20a30c1ea08aa04593c64fc568f47b6f116b1e1cd42c34ad20df58e9a0ea5752c56c19e040bb4b33e32131db38efda918fc05b3b777157a60f607fc0bf35e89b332e5b03dfdaa2ca4673cd45464fbd07665d0ce0f2a4982990e39c63a0a2d2e82398e643e85392281b381ce71ed5a6fa2b610a877566db9c93d2b7618ce4ad08c92e3a32f7931236320c1248c530f12dd7852ebf759f0b6957ba7f9764897df553897ceb81f8dd71d14fe5f61dd6dec5235eb4491966e4855193803341561c8db96c747b59e15e1d6bc01278ab963ca96c6315495867d0fc03fb42bcf04e97af69f0e93a7dfaeb7666d1daee2de621cf2bf1c9ca9e090a7b5734ebf8974d9619c8c0ec3af4ac4dbaeedb83b69fc51247101e62a87618c7527fcfed5d2e9e4e2ed2307531534931a5ad940cf23c4f95705829e1bf5fce8e4d41a28d2cad97791f898739e6a567ab5de97613c162c87eb21fa59b7287217a9c67a1e3b52db02b617cd25c3827195763919f815dcc5370a8ad7d4db8a6f8ab0fbc9a54b62ce41d9edd5cf7ac7eaaad28dce85030ce3dab47a8eb5652491a298d8a360bfe10690ea77eb72648a3e50f539ce4e293d6648e48b5c8d319b943dc67d61667f49ce28f86fa68e33110180e4027a54e084d991214de8463af5cd4512dcbb9906d0bc62b8d084a1b4e994935d8a64b96793cd28a413df357b3fd446a8aa768ea00fd698e913787adf58b793c47617579a5c7b8cb05ace2195f2085c39040c3609e0e706b3f14ab1cccf1b7a4740783d6865371954bc9575dc948018d81ea0fb722b91432b44cf1aee4ef4cb4dd0b5df1035c9d1b48bad405940d77706de22fe544bd5db1d00a969b0ac72ac9290cadd57b74a5422a73a42a5f416430b88bcdc146270063fad6c34dd04dce9a2f25daa0be016ed8ef47697a6f9f34be6db85c8dca391f1d2b4662274f92c4dbb12a7b30e39ea0d777a3e82bdcf6039b54e1f22c7d4a4d27c25a8f87e3b5d367b7d4658a579de00f3446339011ff941e87aff005a4f188bcf8832312dc12bfe7da8dbbd3c4eea26601ce430eb939a9dad9fd314513ab04e3fad6a874b3592ea91af162c916acd2e9306931dbc77377673dced7c90260808cfe1c6dc8e3e6b6be3cd63c19ac5c698745f0bcfa72c76e037952ac6181fc2a460e76e0f3d4e79af9e413c96eae8595948e39e86a2d7775713c4249328b104185ec3a57427d3dce33b7abf2fc8fcd09ca2d2f00f750c097ccaaa63527d058e495fbf7fbe2925edb4492895130e5bae6b4f731230247a1d47e1ebc528d52d9a3b527049e4e33dfb5737aac7ddd1e6334bdf7e5e85",
            "ab6300b856c160c3dfbf7a537a648b5064841017af15a5d5bc556d77e18d0f4cb4f0f5ae9f77a5c0e971791b65ef199b219f8ea071d4f5ec38acf2ce26469b23738cb115c9b5254953198e1252f9185acd118d411927bfbd133ccb1a483a657834ad6558d3f16d039a5b7d7934cc02b6549e1853e735185791f3e9949699a7b1d4638b0b105795fbe700115b2963d2a086030ea6ba94935ba3cc0c462f2256cee8fd47d5b703d43835f26d2e49a27e63dd2039563dcd1d16b2b1ea612595d0975c3b9f4af3c92306978ba9e29391cbcdd13936a26afea5adda78e48c796492a00fc43bd0b198a5180bfc43ea0cc31b47518f8abfc430e9da1ea922dbf886df5a511acab343ca8dc390077c7fe70781981aacb35e00086461d338ff000d33d78b4afb123d3ca9a677548aeb700ecafeb1b4e72463e3da84bab2ba58c493bfaf76323fe5fb56c7c6d3f83a3bcb0b8f08ade25b7d0c5f54d7a32df538f5818fe5e9f9e6b0b2dc9bd977aee193c9038e2b24a51afab3a386d452f8391413dccecab8183d734cbe8a58b11a0f31c8c00a3f3a16ca178e7285b0ca39c7bfcd349279a32b3c134903e305d18a9e783fd28a115c6fc873953f691b38828f521627a963d2ae9177e15514ae78ef553df0492352a5863d2714ce28247b712aa8e3a57471422d1a31a4a2a73d7e22c16443e150e79e4f6abedecf2db572431ad7681ad4ba0cd732a5adb4ef3c0d0959d370507fce4771d691e3c8904d13e3691c63ad3a18bdcd35a1b09b92717b7fa7e60d7da7c71c208e1b839c74fceb2f791319822e5803debe81710aceaaf0b32b8196ce3db3597d574e9c46246c866fe66a5f5581a8d8bc32718ff31ec0ee0cb04aa9b0291d00e7fad1366c27b958e652483ea19e6a896de6f34cc63ce3f94f6269bdac1a61d2f704ba4d5bce049f498bcadbff00cb767f2c5668f252ba249f05cbc8ced6d15231f80f0485e3a76aba0858dc92984e464371c50766f234c22903009d589c03f9d348a067b9de87058f0b9aeb638598f84949f292dafc0d6d9d9e910e830cf1eafbb53798a3d80818158c0e24f3338393c63ad0b24d1990a063e93d48febf6ab74b4d360bfb63aafd48b357067fa700c8cbdf6eee33f7a2af45a658d9991e02f98965c6f0b938071c6718cd6f586957738b9fa682719d377afc7e4bac51194953919ed472a85181d4528d36768f31152e59c9257a0a70a7393eff0014ce1c7479ceb7a7960c8e2fb11279eb8fbd4006218e739e871d2a53708485ce39a16569c88c4798d5c742b906aeb40e1c4f246d52fbc4775673334f2a05debd1f3c9a4091c91bbc8cbb9f9018f0335b42497914ed0c3920ff004ff5a063d46f34ebbfa8b62a0b46d0b7a724ab02ad8c8ee38acf2c7297f4f73d2f419b3646e0d6f5f957efcd181d42295009508de39dc48209e948af546e8cbfe23df1c56ef50b7b7f277c50a3216c907839ace6a51a1b61e8dbb4f381918ae6f55d3c926d9e8e2a5c2daddf730b771aa93b471ee281208ed4cee9563728f9393c500ea473dbb5795c8a98e56b4c22cb54d4b4e8aea2b0bfb8b58eee2305c2c32b209a33c94700fa978e878a1cb339a8577a9e2968b3c49ce335cc631daa5f8b031cd58e3f0823000c55d59063a3a09ae0466ed6dc1382ef9c28f738e71f6adff88bc16fe1682cef63f10695aed8ea7e7181f4f98b95447db9752014ce78cfb1f6ac3f87e1d1251a836aba949672c56e5ed55612e2797230848fc231de99c37b6c0b32485323240e01ae874c9492dd5032c7cb684d77f53697626b499e0976b00f1b6c600820804738c120fc1342e97a46a5ad6ab6ba56956735e5e5d388a18625dcd231e800a77776f15cea126d6186c904f5028549ee347b8b7bcd3ae64b5b880878e6858a3a30e8cac3906959703b72246eb62cfa77b7b878678da2922628e8eb8656070411ef91516241f83c9a32096da4372f75049712cc8763f99b4a48581dc783bb8c8c71d739e2869ced3b41f483d05252a41a3b1dc80c3afc538894b5a1718008e3359f0c8240719514cad2e165243315030360ef4ec13f75306b7668ec2dade4d0b50bcbad4e28ae2d963305b3efdf71b9b076f18f48e4e48f8cd67c6b01b7c52a2ba8fc2c739fd69d4a239ec5fca56554e9e9193f9d667e85e4982a00b9ebb8d6bea1ce0d283b0e495e89159ee009d4ee55e302a2b0bb1e58894f01475cd3bd3e14b778d66e557a91d3f5a7fe25f09ea9a543a55f4ba55cc316b3179b64c63fff0070b9c02b8e73c8e3a90c0f42296f02e3ce4f7f046fb188f3a688ac7229c9ed464d1c02dccaac01c7200f7a1eee3b882e9e2b8568a5438dacb8652382083d0d456e430c307d839f49efef41192569869d2d9099a3308c483775e98fca97e01563902ae917792532475c55001271deb1e4972603639d0f5ed77436bbfdcdab5d69df59035b5c182529e6c4df891b1d41a36db548e39f6c9086de0741852692db45e627a37efc8181d07deb536361630db08ae23df2fe2e0f238ea38ad9d262949fb7407053b4c77a45f44ab1c93379641c3febc1a7979731c604d6d708de77ac027a8acbc5671adc34b6ecc630a0aa92460e09354c72497728d8c5ca1c04e7fa57a0c79dc20a2ff010a10938bbfe97e4205e49717085518480f013f98d6863b00f146d247ea71c1079273fde97e9f6b14370b75705222a72c14e063e4fe7445c5f35b6cbc28ab092421538ec3d583d462b56297a6b96566c9e69465fbff217fbbf75c6f0090a07a7db156b4622c86631e3db9fd2aed2afaddedda659ccb9fe4c703dab4535",
            "d69ba9e95a65bc1a4456535ba32dc4eb2163744b655883c0e38ae8c72c2938ad3fdfee809fda50c7c9cf515abfafefff00e99692132491b64f964fe261c903e6b3facc8d0dbb20c024e07ab3cffe2b7f3a2ac657cb0c4be0e0f43ed590d5ecc9991d4216605428f7efcd72facb77470175cb2e7bad78f26126cbdc88d18a86e07da8bb7b396da01bdb07aedce73ef5a24d16359a0f38ab061ce39340ead666c64d91bfa546723deb8bfc3ca37366d8e65926940cb4d24b1ccc771c75f8a152e666942e72bedee2afbf326e7f30ee07953ef9a06393128c0d87b367a5732736a5567413b5b1b5a5d3c0cf20dcc9cfa71d87f9fd2849c4b77299880189ea78c9a2255945b195e3250701ba63ef8a0a6bb674c00c0a6001d315272d5484455bb4137132cbb55e3319550ac4138cfbd1b6d0c4b1466260ef21c0c74359fccce013212bd4f35a1d121fe289511d82fa781d09ef558e7ce5d8566f6c47daf6a5a54be1cb5b48f4d297aaccd2dcf9849752000bb3a0c104e7be7e2b356385c2637375c63b57d06e3c3f25cc71c31c6118e7202e149c75feb4a6cbc326c24226513b1c85206791daba13e9f239a673317578963e37b334cf24770f0c4ec991cb628c44f31b827781d0f01a9d5ce9f090fe7008ea31edbbbf5ed4bedede3e657dc1a3390a39e33c66ad4251746d8f51cd6bb8b596586740a982a47a6b536770ed12968bae064ff7a06e2d77cb0cb0ee562324fb114dd221e42ae0e48e73f6ae8f4b81b6d59b6108f5318c645e91afd3969554381c93dc5070a5b4d74b1ddbcc2d4b105a100b671d402477c77a656b7973616d77140e545dc460914804b212091c8e3951d3da834b7f3d8ba4414e41cf6f7ae87a6ef88fc38fd3934ce47986dcc7248484e09eb51b9b1177a616656f53707a671dbe28ff00253ca2e5c2ecf7e09349aeefe45864428a32dc21ea7eded479f8c6352ec37336e92d0165beb1a293080741d9fe2abb7124ced3ac6588fc273eddc55da8c7702f7732ed0d9c153fde8ab68595c33200146723eddeb9b3c5294a978119f1ca50f696e9a19e26475264439f9ad0445e2912568d09ce073c83491112cdda58c14f3070339e69a69d26e472db9f03a77cf6ae8e185249f8119b03708c9f65dff1eff81a48a3170bbde305400496e413f974ea2b925cc01d7746551721b8e01ebc55962d32583162e14673b875e2a177746faf6696dac62b70dcac5164a20cfc92715d25bfb8e5628ac93972fe98e96eabf3276a05c4be7c516d3ee4f07e4fcd328e47752b2fa71f1c5239656b419604391e90148c9cf7abacb517955a2dbceeea01241f9a54b6f4ce5759d1cf33f531bf6aed7f03595e5f3046aaac482483dc7fe6ad7b8b992d6381e46758b3e5ae788c13c91ed547d4c69cb91e60eabff28aa9f0dbc8e5dbb81bb18e783412697e071ede35c2abfbff00a17eae258e1548d9b7ca705d0738a16dddbcb6b696773951cb1e7db14f651a15cf86aee79f5299753f3112dedc47e9287f112dd73fe739e12065367e709448557246d2083431941b72bec7a3e9de38e08b9357fbfa7e1e3e87af6c20366a62914b919393827f2acb6bb63f4f63ff00b9918e481f8aaf97539c5d08a6006f6c36411b720f5cf5a6235527c1f7ba5be9d633add3a1fa9921ccf0edce7cb7cfa41efc7358ba8ccf2c1c608df1c9d528a829371bfdecf96ae97797cee9676b2dc344acec1232c5540e49c761ef495e376e7dbad6f34ed6b53d0eeae3f736a525a493c6626319077a1edcfcf20f515949a2081989c90d826bc9e5c7ee6742196dd3ee2a298c678cd702fc55f212252aeb5e584971b79acbc77a1f64113278239abc5bbbe769c902a2a8cb28dcb800e699c7672c8018f85c0f9cd3e10b45b692b17adab25ca24a0a1cf43de9ad9ea53d9d85de9d06c36f7a505c2f94accc11b230c46e41cf6233de994fe18bdbb89264f561030607d3ed46f834691e1ff168b8f1368235eb2582546b41318fd650aab67e09ce2b44ba7c98fb4742d4d497b5895ae5219d56140de807818e6aa9eccdd334adc203d49c669b2e9f0a08659255594e0023271edfa505a95cf990ba305050e3701c938e79ad128b517cc5c3236e902fd26edccb1908ab8da31c9f7a066808b369320b7b13500d346fb5c965519ebc570caf2c4538551c71591ca2d551a629aee00288b54669d70c01aabcb2a46ec734e348b758ae44cc4321040cf19acf871b94d225138b5092198c0f21da474cf07eff00355c904c2e8a82c171edd7351ba9ed4ea6ae176aa11900f1fad1f1a4d3ccb2c64b478c805ba0adcbdef8ddd3d12e29d0319e486211b6597ae475fbd5f278c3c48d3e93249adde33e8ebb2c03484fd2a83b805078033dbf2e9543c6f133ed6057a7bd6b353fd93f8cb47d29b5dbed3ad8e9d1dbc374f24372927f0e419070a49c8046476c8eb49cde136492ad995d46f2ff0054ba92ff005194dc5d5c319649dfab92726a7ae699a7695a6e9ff4dacc7a85e5dc2b732adb60c76eac388d8e73e6820ee18c018e7ad57793db2da88e26c903a7b505a61d3a6d62ce3d664b88f4e69d16e64b701a558b70de501e0b019c03de832d2a49913d1dd38e882c3523aafd7fd5f903e83e9b6797e76f19f37773b76eefc3ce714afbd6e3c62bfb3bb2fda596f07fd76abe128a5898a4ec63799783222b101803c80c403599d7ae348bbf11dfdce83a749a6e972cccd6d6b24a656863cf0a58f5ac6503d9caf149c1383dab63a54171713a9dc118a8db93dbdb1fe76ac72190a26c20738e0739afa0f876357d3bcc6b7f3651ff",
            "002ae4f7e6bb9f6641cf271fc438a77a1d47e1cbf1a4deea61e0115b4ab1c88665f30960c41099cedf4f5ed9ac25cdd9b4bb6660c8fc3600eb5f42533c9a718ee2e02cd26421dbd47cfdab19ab5b201bdf639270a7af15d1eaf1351e51665c7526d4be74529a94538649a2dcc7197f6e39e053657b27588cdea8554330618e3e3dab36b13dadcf9b820632d91f8451767a824b149821a5c60e4e40ed5cf8666bdb30326a3c576377a7c91c71c2e8008b8003773d7a7b538b89259248a5b7982c51803cb04119e6b136d6cf72ca12f0b7a71e5827f5c53e92f6ce3b786d238879bc7a82e187b74f935d58667c38cb48f3dd545b6a0f7dff00508d42f3e92550a7cc490090b00381f3f3d2b3977a8497b2298637554073c7008a3ef34d2da61965b866b9c0cb0181c8e9cfc52682ebcb99a25e770098c74f7ff4a0caa6bfab48e8f4dd1bc70735dd6bfd8d2c2fe3d4352b1d2e18e3fa89dd2dd496c65988500b1e0727ed50d6b449edb59bfd27559425d58ced048237122065382010483f7a4b3476c2430c8e986270c7bfd80eb5a7f1978eacf5fd2f44d3ec3c3363a13695682da492d07ffb920f53c0e38279c9cb3649cf18259a7caa5d87282db83a66275ab61e5c710da76a804e6b38200672a72003c83da9ea896473e749eb3f88633d683b6d3657d45649b725b97018e3391ef8ac19a1ca4a491b60b846aec7761676d7968624722300ee18c9271c7dabb368314972eb6f2870172037b0fef464ab67a3dfdc41a45c7d75bee2a92f9650cabff36d3c8a32ca39667410aa19578f2dc74ee79ae9e3c309c545ad8be3249b4c53e1fd0f47875bb3935e4b9934b59905c8b4c799b33eada0f7c57d152d3c256fa96ef0f8bf6b272ce16f9555d7d781cafc62b3d7b6d37d4c7e5a08df3962bdb1dc536b5b65730c85dbcdc11846e327deb4f4fd0709daf1f9187a9c73cb8b8cbcf946a764331539dbc15507b835286d6d52428503b28fe6192450d6d18548e261838cbb0e3d547ebfad5f6ab2413df797e65bc296ca63554ca81800e07f5ae9c9a4d3ad1e327183938c5b327a9e9710d464988c44feac018fb71594bcb291773c76ef196e0e7be2b7d6b7af672191fcb77442111d43af2318c1e33c9c1ff6a85f4d16a2d25e35945661555121838418182dcf73d6b364c3172d2d1e97a6c91e9e2a527754beff00df931da5583f17122babe70518f51d734da7b722647c10180c60d4e199e59b0b214788e117dc51ef7056d0aa2ef959b1bd9718f9ad1821082b8b3a38f3b864f520d36fc08e395526998b139e14ff00e6a66e3844284306da48f7a356de2b84f2536999412707e7fbd5060486dbc98a28cbef0e646e5b804100e71839cf4ed5b7836ae3b3d0c3d2cdb8ed917852142242e3cd195dcb8dc0d5da868935a081a47824f3e05b88c452ac9b41f7c1e0f1d3a8a32eaf64baf256e5e4768e358e32edc220e807b01cd0f756ab1a79ac8accc09186f8ebc50cf1dc52919f24971519baf8bd89f5bb601b740cc5186495181f6cd67ede3d9788cf2128406653c807b66b452c62e247b7c394cee3c6401f9543f734114bb98e5b03846ebf7ae2cb1cf34f92395832e49ae1296d7dc54669f72a8556273824e40147dac0c545cee0108e31dcff00a559a7590ba9dd597000057073bb3dfef462acf677af0480157fc0320e0fbfc56fc4a5cadf61afa99fade9a7bf29eb5e473a7ce6e11ada32ca48fc4dcf3f9d5c966b096dcc51bbba9c70719ae6997b69a0f88ed6f2fac1753b443b8da339449320ff0030e460e3f4a1e5d4565b495d542b4ac709bb21573d33df8ae826dca92d183274f39be7d2bf64dafd7c92b9c240b333e6253d33927fce697c26e1a5796dc101b25b3c7daad9a2696de38dc05001627fdaae2b6f15a4522cefbb0548e319cf007e47bd232a8c9d3119618f83c6f72bafc2c4bab5fcf0093e9e542ee0065c9e3e3ed9a43a7f8aa7b3924fab7937b3edc29c051ec2b4ba959405976a7991e7710a832d8edf159bbcf0fcb32cce23668411961d17a7eb5c5ea619a13b8b12b1e28c7865ddfe6191deacceca2ec392000a18024ffa638a2e1d5a682e552e01f2dd467be3e6b11f412457caed2108d9d8a38dbdb278ad8c1e4dc5892c0b2a80172767418c7349c192736fc172c115db6981ea171f59ab88d54b428dccbbb903dc8a65ad4f6bfb84c168564da39238cfeb54ded92456cb2cebe974f4989b00fe608a59771c2d6c6d59db6c4406663938ec315a3df152bf269c18f97177a5f1e5fef5461c3490dc1cb302b9e3dea6dffa881a5184039c67935d79a3f38c526d60a7f163934c9fc35ac2f863fe258f4db8fdd267fa6376223e57998cecddd335e74eba4dcac596f6b0cd19ddea3ee3dea3144f1c8ec57807038a2ac61547cb6eebc9a7b16812cda1de6b4ba8da28827483e91e4c4d26e04ee51ec3fdfdab44712e2a4cd3185ab32d2a48f21063f575c8f6a26dadeee09140902e391826b5b7de116d2bc3ba3ebcfabd85d0d50c99b5825dd35bed38fe20ed9a060b58a4b8559e4f2e291c2993aec19eff006a6e2e99cbdc5ac727f704da5e1fa636d72e628d57391919f9cd46c350f0f1f0bdf58cb6b7efe20332fd24caebf4e22e376e1d49ebd3e3e6b55e2bd0341d1b505b3d2f591abdb0895ccf1018cfb71c7cfe78ea0d63bc8895e5b9c8597a4600e9f3fd6b6e584f22838cb5f90a927caa2fb83a5adc18e49e5076c43730c9239f6a4fe6bbbc92c91c8d93c718c56c9fc43aea784adfc3b3ddf99a54570d76b008d46d98aedddbb1b8f1f38accef692e558c6c",
            "549e98e86b1ce0e3562e1170f7480a58cb4414125f3d0719aa2da21e76d923032727e2b43a84105b448f13297dbda91dcc9225aed50a37f1c76f7a5e5c7183b7e0d1194651b434f19785e4f0d49a619b51d36ec6a16ab74a2c6e44de5a9e8af8e8d48a1be78edde10a369e4e3bd3bff82f51bbf082788f499ceab0c28d26a115b42ec74f5dd85321c639ebf967a73596f50620127dbe6b9eb2bbe48bb3ccced2ef6c963cf229cdb2bb962a4a0ea401dea3a6d8adcc60e4331c8c1ed4e25786d2011025cedfc5ed5b3a7c2f7393d1516ac4120957ccc36e00e307deafb6d6afadac65d3d66996d272ad24424211cafe1dc3a1c678aa77bb4cc5943236703b7deb92ec242a81903a67a525df74c9b60126e6958ee3c9cf35e040f4b0c8fb579bcc2e59b25aa3bb24645652123b7233c8a81c16cd789c9e2b954d90b2290a371fd6b75e12b9d59a49059da4d742388c92f93197f2a31d5ce3f08191c9e0560971bb9e94ef48f10eb9e19bcb8b9d0354bad3a4bab77b599e07da6489bf121f8e07e95aba7ea2785f3891f668d9cfaf409fc3b988bcd9384cf3590d575059aeb30868caf1b7380334b2fe2d4ac2f5adefe096dae02ab324aa55b0ca194907dd483f6341ee63d49e69dd475f3cda62f87bb931cdd5cb5c5baa95070bb49cd28490c5291bb0bf157453103606c1e99f6a205aa4d862cbb80ec7935966de47c9772dd20fd2b58b94b9531b95c1c2e5b15f47f0e5843addddfdcfefab1d3a5b2b26ba2b752ecf376e3f869ee4e7a57caad6d9e3bc572840cf20e78ad19bc441b628576b0c3332ff006ad9832cd476ce7668c1e44e83f55d5e696d5ad6d0ee41cef230dcd2eb69545b34ae9fc5ea31d41c7fe282fa958ae77b2ec5e793c714fbc2de26d0749f1025e6a3e1e8b5eb0113c46ce595a205d9480d91cf079ad53ea2fdcdefe0da928c2a3d84b1c825ba3e6aaaff00d59c0c1eb570488dcaaa37989b4807db3cf5a2a4b1825b7799113786da5719c0eb5524df4d6d244888555b20e3923ef43185bf7098ff00365a236f0442f37dcae42a8c2f43d78e69bb4305c4ab6fb828c0656cf2df1f34a8dd2c6dbcb644831c7da9849ae5fea3158a6a376f345a6426ded5362a88d0b3315c81cf2cc79e6b4a8a8b515bf93565e95e9a7d86b06983cf8e48234748d403d78cf7cff9cd34b6b0dd219922c3ae783c93ee6924fa9111c6d03c89801d493dbe69ed95eadcf933ab619976b37e1c576b0c216e284cf0e58c656d76f2336d3d6505bc92a4a6323efc8fbfcfc5076b1c762aa3d6d960093f7f6ed4dc3472c28b23307c7003609e39e7ec28030330769d422a7a8639ff000d393e09e8e174dd4ca18a78f276f8ff0003863ba4c44e15cf73d4679c55316c91995892c5b2dbb9a1619cc30f2e5e4c8c7fcc4668a49e3677695970e4609e31f9521c93d33cdce3c571f803bcd9116678c65b80d8efdb9a0b5ad4ac2f6fa47d2f4f6d3eddc652dda66936103072c7939393f1444cef3808100d84373dbf4a02f74ff58900c1627f09ed4a70e5ee3b7d1431d565693133de986e3cdb94c670b85edfef4f11d6ee068a270c1800093c9fd2975fe9f334319818a6720063b41a86836973148030d801396cfe1e878acd8f9c675e19a1c538fab0648433d83b3ef3eb3c7f2f4a2a1955e5264cefe7a0f8a95ec33acb22b1ca93c6ee401daa88d65c97081d987f2f6c74cd76b125054bb1ebba5717853d7de49cba0c0c173f873d4d3783519934f4d3ae163585d9652c2352d95c8037119c73ce0f38accdd4f3fe03190ea7208a3edf75d5b46642c02afab3d73f19ff0038a0c99537485f5f34a2abb7faff0064c5fa5aecfa652a8339e325863afb567af35b95d648a3629203d540e9df9ff3ad1177657c91dbcad6d72b05c6ef2dc8212520e0953df07838ab26b182178dca8672429271cfe75cd949e44d41d51863870453517ee066b9bab35faadfb58e36943815e835d6b86917f0cc0e724fe218e47de956a57d1a5c22db23a40a7a30ce3dfef40c5322cfc2aef037305e323bd61967719545e8b58e32db47d06ca1fde56114c1f13c7c7a9ba8cfb568e3b2b4fa01230f3338dc01c1cf53cd7cfb4ad7a38d99d4819c8393c7f98ad55deba069e0da93b153321db9c64703dfdabad83a88349d9c9eaa39de48c212695daf15fbf016b3dbbca0280768c0ef444df4ae81258d6177c14e71bbb7fdab111eb8f6d6cd322057ebc1e7bd693c1de331a46bb1eb53e9b69aaf90aca20be4f323e548ce3b6334d9f530716e1b747433746a4fd483aaf3e7b97dacd13ca42a9c47c6300918e48c554f75771dabcd06dce33b5f3c8ce47c629558df446fa79bca589a424944384519edf03fccd3c927924b70cb19f2d8640073c77a4bcbea42dbd9c3eae4dee7beddcf9fddeb529d5d9c5ba28032e918201fb576cb518a5926f38b26558e4703ed575df936ed3acb06c576f2d4b6393d7b734990c3e62c4588058873fcdd7af5ff00315c173945f737e25170a8aa19df6a6668a3883e044c36293bb6f1da80d4aee6364089436e00b60648e314c21d2a33a716678e4639d8c48cd20b94f29984b22b2292a4e3d8f1532e49a8efc9b30e4834a10f02f48d1e565527691f8bb0ad3c37fa98f0d2f8764d62eff747d47d49b112b18bcdc637edf7ac999e25c147c63d8629926a6ec88b918519e063358b1bc7ff00637495aa43491524219142951d01e4fb714569e5579d9bc11c8618a5b1b4d72c2e55428e85578e29eda32baefdb904609c73ed5d9c0add8e8270854bb1368cba14445dbd40357da5b8f218b8",
            "0bce00c75c5464610cdb5814c74c74357d8dccab311244a622700b0e83dc57563c13d9a9ca2a1680a5964b3b96dd6ecb1b2e318e17fdc52269ee1271e6420a6ef491c7da9f6a96b7170e9345310a4614738fd3b7bd54f7d63a7f87f5206fee13572121b78d634785a33ffb9b89e54e3a11cd723ab9b8dbbd2ec73de4537ca2caefee3ccb48a464dd1852a5d17a1cf4341c2085891954798dc718cf19aaec6e0b5ac82546740a7049f7f8a61069eb791c2f0ce245539247b7b006815cdf333afe5a729762cbb4d33cb884590d180a432eecfc8a437d6c26568a1991988e5769c8ad2358cd249e5a26d55c61df82739c0c5082c0da6a2cb313eb5e76f239f7a664c52c9a6a90dc2f92516ffd8974ed7fc57e1cd0355d134cd626b4b0d56309796c98c4abd3bf238241231907078a5f71a758b4d6434db99e712408d70668827972f3b95704e547182719f6ad9ea1a05bee2e8c595c854f7f8fcabd0585be9f6e919f4bbb0cee1d4565ff00f16d4f7a46854c402c9f4a21e553875c6f03906915d5c39ba210e40add6bf05c59958efad26b62c8b2a24d195dc8c3d2cb9ea08efd2b1373146f73941851dcf5a0eae0a09431bd06d28c52456af34f1e22c8c74c54625fe20673b79f7a7de1cf0bea1e24fde89a75c5943fbb6ca4bd97eaae161dc8bd42e7a9e47c7b9159bf30aa950726b9ae4af62bc849784472b2a2963c7aa9793ef52527383f7ab2e2eee6e9605b899a45823f2a20c7f02649c0f8c93fad2652b052a28af57abd4b087d61e1fb5bcf06eafe2093c43a75adc69f2c31c7a6cb21173761ce0b46bdc2f53f9f4e32982bca012781c7ce2aaa923b02540077512fa90ba642ceacc59b81cb1e4fb5156d65632e937f733ea91db5d41e5f916af1bb35ce5b0db580dabb47277119ed9a181de855c92d8e3355a12c4641c67de89a57a2bc9c45241daa48a6d696457ca9082403eac76af5a5bc7f8d5c03d79e299c67e9a650a3713df3915ab1e1adc84e56d760bd4f4bbcb56b4f36ce4b7fa9856e22322edf311ba3007b50170f2dba98e520e09c0ff5ab2fee1e145deceeca008f71edf1ed4a1aee79eed7206d3c1028e7251fbcc9085efc10d4ae92e37040ddb1bbb714b1679372956da41e3028dd42344b991533b7a8342db40649d57a026b0cf9399b71a4a3a3402fa5585559f185c655880327bd546e634b7cf9c096e30a31d2b834e69092d2fa0b6101ea6a9bad3fc9dca11b706e063a7deb6af515ba2b0c545b71276f3c72dc293c20e5ab61a7bc6f6e0db461d812002339cfc1a45a5dbe892f86e41ffad1af8bac9cecfa616fb7ff0096fddf963e6b63e1ad32ddadbcc9e40cc09d88dd3b11fd335d5e814a4b6bb8cea73471e16e62ebeb2102c8ef088c03cae7afdbde8cd36f11d5667b656f2581dadfcc3da9ef88b42bc1e1c1acc5f4ab6715c081d7ce512172320843ea2063ae3158e8e57954ac4e09202fa472791ff6adb1cab1cdaee64e93aae7893c9b6cfa75dea506ab7f25f5968f159a36121b3b6c9f5631e9cfb9f6f7a14c53cb681444f14a5879a8f90ca41c63e39ed59db6d4a6b310ed7daaa432baf0cac39c8a7d63aca1cbce8e5a5f5166392c73d73dce79ad309b8d453a5479eeae39f1bf562bbfe5f97dfb1cae887529f4db2d12e1aeefae936cc9247e58865dc780c4e08da01cd2e96ca7b4beb8d3ef7d17504851d783823a8c8e0d75354dcec23631e0ee0ca7b83c608f9a3b467d1adb58b7bbf105addcf60cff00c48ed4812b641031938ce714869c5b95da4bf13929f2f6b54eff000fdf9623d5257862df01dc36fe3c01de97dbea517a9ae07a0a91b89cd3cd4e0ba8af27b3934f9ed7cb72ad05d465644eea0838e7159bbcd36d92deea6b896784ac41ad51103077dc3218e460633ce0f4ad1293e1ca3b3d1f458b1e5c3e8e4a4fe7c9c6d463b89361817ca07d273cf18a65f5d6c52158cec2cfc8239fd6b2d1466e20f31646429c103bd1d64f22ba22a74040908e377f98a4473492a6bb9b72f48a383b555f9ff2383a8c5e608add7cc233ea233939fed41c976219641180fbcee640b8078e79ed56dbc26212b3db798c3a12db73f6a0eed215525d82bf46048039fb536595f0af265c7971d7a71bbfc37e484d72b713e42f9522f5039a6b1eb121d3a3d2a4943db44cd222151e966c02723ae70072692c575a445a4df4375632cda8ca919b59d662ab000debcaff0036471f18a5d06f58ff00095dddc71fe76ac8b2ca556bb1afd194f1455b4bf5392ea77572208feb669e2b6dde5c6ee4ac658f3b5738193cf149af357b9781a3f34288c95037106b3d35fb433ba421950fcd032ddc92c85ce39f8eb5c0cbd62ed1d1abd18b7690de5b9b79864b16c0eac70734b5a52199998924e3157bdb471e996973e71dd7024dcbd9769c505c370a39fbf5ac72cae5b1ead686765743cde70a839233d71feb5f46b1d6b4b9bc137165168cd26ac6e5654bc3264ac7b70548f6279ffc565dadb53fd98f8cf46be99b48d4eea28e1d4120245cc23772239578c30eebd471cd55a8f8c2eb53f135febed6b6b652dfcc65921b38bca8933ce1579c0ad7d3750a2fddd8171ffb2ee3996fad248160740483cece39ef45df68fa858e9961a9936df4d7acfb634991e4408769de80e549ed9033dab2cba93b859a2000ce4b11c9eb4c5750c41b939ddc9cf35d78e753fea61ae4953387535864965853682d8393c6334ee2f14e6d45adbf0e7d2bb476ee6b017b3995090bb4f53ee450114f2c6c195f0477ae7ff1af1c9a5d8c793a4c5915347d02f64864f2a49496788ee2a0",
            "fe1fbd2ab992dc326650e8dc8db43c3a866d15ae0e5b1d7a934b6e3cd69c3b152addb18fe95324d5724043a5514b668ecaf1d6d1925da614e501eb9f634af579637b756d99ce4f419ff7a324b4596c609e18da30ec433b7018f19c7db238f914bf518a66b7ded3ab285c85dbf3fd28b2b93c7c46a8ab54a84e2312e582ed51ce0539b682316a8f856231939a596b1a386468ce4e7b74a7b6ba7c9f4fba62ec321a300e3359fa78b7b48d0e55b343a3e872b95b86f33c891b606552406c67191fda980956dae5adeda12f29e06f183d3dbfce957e91aa6ad6ba52e9dba5fa1128996003d25bfe6e94d1a069a36b89e18e32cb9014e49fd2bd2618370f8673ba8ccefddb4ff2b045b28e7581ee80f2fa1f7cf61fd69dbfee6820f206d4940c023920d00be5b5be66ce178e0f4fbd249ae87985a305a44ea769627a633dab54f8c229af263cf83d78c6a4f57a4f4c2259e3fac96c50865241322ae06d1d41c71596d4ac126ccca8c8b1f3c0c861fed4d9f5b8a498798a3ea78c2b0e09ef9a0750d664ba5b88d102381b5b1d2b9592509c5db1dd343242afe82580b9c5bc09e8e463da9ee957634c88b8c9618caf6f8358e17b716f31d843039cfc1a81d5268c18cb165ee0f6ac78fab863dbee7764a338f19ad1babfd76185a17925633139623918abfc3fe30b1d3b5e3737be1eb5d6a1920921105c13852c30b27a73c8ff00c60e08f9adc4e2e4ef24e47b9abed5e58312ee0a3fbfb5065ebe795f1ffa8b692edd8fac441aec25cce8100236c6ad8ebdbfce94b75a9628668c3286665c649a1f44d656ea1589ddbd3c862d9c1e99e683d4d84970cf23f9846463b8af412cf178138791b8bdaa92afa17ebbaa6abadada4faaddcf792430ac113cce5cac6bc2a8cf61593bc85cbb3a29d9fe94e0ea320b268b0148e0525b8bb949c94db8ecb5c4ea5e3aa45cb5e063a278b350f0ee95af697656d672c3addb0b4b86b9b7591d1036eca13f84ff00d8f5008cc1196246055b2b99097c0071da876703a75ae34a85106c835ccd748e720f14d2c7429efb41d53598ef2ce28b4df2b7c334c16597cc62a3cb5fe7c6327d8525942acd7b35e3d6ba7a0a859ccd1fa569d79aceab67a569b099efaee648208948064918855519e39240a039f6a9c52b4322c91b1491482181c107dc5444349e34f05f887c05e249b40f115b2417b0857fe1c81d5958643061d41acf2c9e8c13d3da88d4b54d5355bd96ff0055d42e2feea73ba49ee646924738c64b3649e299e93aa6836de1bd674dd5b48faabab9547b2ba8b0af048b91c93cec20f23be3f3176d1428fac6c000600a616574b23307b88e22aa5d4c84fa8819c0c03c9e829193cf15d53eae99a2f564549725b341e7dc6ad77169f676af73753308e28a352ccec4e000075a13f75eb0fabcba32d8dc2ea10ef125b9521d7602cf91f0013f950d0dedd585ddb5f58cd25b5cc0c248e58db6b2b039041154de5e5d6a17d35f5f5c4971733b99249646dccec7a926aa73949ec5c20a2b475e791a41e6396180083deb41e2483c2168da57fc29ab5f6a3e7594725ffd65b88bc9b939de89eea3f3fb9ed9727de89d3a08eeb51b7b69678ede396408d2c99db1827f11c7381d6813761d520a8ef2e154489212c7b7b0144497924b1b13c3364f279ab255b6d3efa5b78e78ae63473189533b5c678619e80d47e9adae0a47f5062591f990a6ed83e00ad719492d317192bd0c345b2f3449730481e6890c8ca7a281fdebe81e199a1863692e3cbde49caa9f4f3dff00cf7a7bfb1ef047ecff005583c42fae78c0c124168542645b794847ae7cbfe3db81e91eff0022be59793e9b66d2476bac9be0b29550b0345b979c373efc71f35d0e97ab589d57615d4e379f1f15a34de29bf0f6d708b2895548e7db1d81ac3dade9b5c659887e370eb4747764031cca0a11dfa1a221b3b7ba5531801471914ccb39669fa91ee2b1463821b45b6778f74aa58fa58e464735ad8f6bc5192412a071ed4178674ef0a5adc5dffc4f7da85bc62d646b56b2457633803cb560dfcbd73f974ea2cf0f78bf56d120d52cf4d78766a76ad67705a257ca1ebb723d278ea3fda990c92fe9977306787f11b4e905c976d1346538438070393fed4c6caf6fedeeedef2d672b716d209227cf28ea41538fbd66e194b30577edba9e691b4cc490c324e08ef5b612e4f89ccca9635a5b468b5dd7b54f136acdaaeb37625ba9f6a178d362a01c0000e82b35a8b4916e8d98ca07e1dffdbfbd3794dac285037328c03d08e7b529bdb7bcb5103df210971fc488920ee5048cf5e3907ad6f871c29635a37fd9b2929b94bcfcf7fdf8065b30d0f98c540dbed819e98fbd5ee6ea7b41651cbba188929116e149c6e23ef81fa554ee279c18fd31b1fc207420638a6f04296b6c7c89065d4eedd8cfde98b15ab68eae4965c78ae5b7e17f91649f4b169b0a7977c75449720363c91163f5dd9fcb142c36c753b372e7f8aa73f2c7daaf9ef1b6e524276b0519e7b57ad2fa082291a4f5be7713c71cd66518a6d332cb9f172e352d57eff1129b74863923930ce0e08ce581a12477b672b03e011ce79fd3345ea7736974e64848f531dc4f04d513584b65e1f3ac5c58dd9b3ba95a0b7ba518859d47f11738e4e0af4f9ebdb1e692c7bb3a714d454e4d9f317918aed60077e2afb3b8b18637177a77d5313e96f39936fe9d6846efd6a35e31edec69f66f1bf8e7c0fad7ecd3c23a6699e054b2b9b342b248ae136ed1b59432fa9c337ac96e73f3935f2696e505f0b9b28dad0290c81642c508ee0f5ebcd52f753cb6d0",
            "dbbbe628776c181c64e4d539cd5a7440fd4b53bfd6754b8d4f53ba92eef6e6432cd3ca773c8e4e4b13dc9aac39036139cf1c50e2bb9a352a207dbdc35be558e47b1ed4cec24b492ec25d5e496f0bab1322c7e61dc14951b7233960075e339e718acfab1c8c9a29654552ea01c0c735a2391d502d109df2ec7dfb5503ae2b8cd935d5ce09cd25bb7610de08d1ed42ac9ebcfe1ef8ae1553214918123b939a0617650719a218484095780466b629a69683b438875ab996dedac4cd3b41048d2a4458b22b1001217a0240193d4e0569a0f09ebfad782f57f12699631c9a7e95b16f5da450c81ce06d0793d7b57cf1252926c7e377523ae28c7bdd423b6f252e1d2075c150c429c1c827de89667c5a32ce29cac7da5c768ce9099146460b71e93ef914dcafd3c92c91ed6f2fff00e4518183dc562b43d42c2d756b69b59b7b8bab14955a58a09446eeb9e40620e0fcd1b7baec777e743a7452db5b6f2638ddc3305c9c02703271df8ad383ab84553402c7252efa67d0b4cba8de28d58b36012189c01f02b4169369ada34f3cd732adc24a156248c14119072c5b39ce70318ee4e6b2be1dbcf0affc03b5f53d513c506eb0613121b5306383bbae73f3f977a65646578a568d97191d063e09af4bd2751fc446d682cb0f55bf0bb2fd0656696ef00b7918bc523163e9e73ed9a1353d323fa371a74ce32c18bb1c8539e7e688373690148f71619c9da3057df154dc5e416da7240968ced25c330ba0c7ff006f6fe1d838ea739a7e5f4dae3ff8739c213c9ec74bc7c3fdfeecc44acaad2ee8177a70b20cf5cfcd7b5ed135ad1fc29a25e5dfd09b6d60c9730792434cb8210ab9c640e320648ebdf3475ddac66ee579bcc6ddeaebc034a9cc08b9d9b941fc24d79ccd85b7de91bb155ba5a600fa7c5168305fc7796f2cd3cd24325980c248954290e491b707240c1cf0693ad81d8f2bb045071ef4f140370a8a46d048209ef415dd84c8b2488b85ea327a7c7deb04e1adee86facbfa589e587cb2007186193f157c706f4645048e00c9a10b1594a9ce73822985bb49bc315661d3d22b3e3e2e4688d361f1ddd959683716926905efe49a3921bf5b961e4a2860c9e58e1b712a727918f9aa9eff00f888b1de25c09234258295dad8c95391d474c8e0d197b6e65b5661149b76e793cfe959e301590b64051c823b1f6ad19633c32f6bd0c7aa68612ca15b137a58720d5334dbc617a11c556640e3f8d8200edc556ee8620517a526591b16df92b2bcf2f8354ba9538eb5352771c8ed53542d9dd8fceb3d581f7830cf4ab4edda00273df8ab12dfd473d073cd30d3efad2cecf51b6b9d22daf5eee111453ccce1ad5b7ab6f4c1009c02bce47355c5a2589c9cd741f73d2bce06e38e99ae152173d287659d67c8c015e8b616c31233ed510326a6d16c00b77a9bee41fd9a7854f8675337e7543ae0922fa030797f4bb33fc4f373eace3f0edfce90b478cf7a25180b70abd73dc75aa5cb15da719a369502986683a9d9e91ad457f7da3dbeaf02060d6b704846c8201e3dbad2d760d2b3aa08c124855ce07c0cd693c4be06f11f84ad349bad76c45b45aadbfd45b30915b70e0e08078386538f66159bf2db3c734aaf211e6ce073503572819f58e0541f1d30055b442aefcd176d1be54a2ab127bd0cc304739a204de50c0383db9e9431d3d812b6b444cde64e7cce84f41c5697c29a3d96ad26a2da8788ed3458ed6d5ee2237009370eb8c4698fe63fafc1ac996f592a302a4d2b704718ab52ad91c746e20bdb7b4b49ca94733c2d11e718ce39c63e2976a5ab5c5c68fa669b3456c2dec04a6264b75576dedb8ef70373f3d324e3a0a450dccab1e50803bf345cf722e6d3202e54738e0e6b6bcb19c7ea0c7dab8b088eec80824c95038fb7b53cb79bcab50eac5031c819cd62fcd6c80ccd91d3068a5bf9708acde91d47bd4c7d4711393137d8fa843ff0add782b567bf17e3c406488586cc793b39f3377ce3fd3e6b37a1cb2dade97f22372030db2ae47208ce3e3391f340d8dfc6610bbc36318c9fd6af9249002f08019b1c0e7f5ad6a4a4f9b31db57163db6bc52e4cb22918e0014cacafe5f2865815078f8ff38a41a7c05a3569397ea08a6c8a91c59e98e0fb1ae9e0c94d362d3c319a4f687b25a3cb286322940015dc325b9e40a67a4af87adaeeedbc45657d35bb59bf922cd82959c81b19b77f2f2723fbe314a2da433ac52382d10e0f3f9d4753be2d13c67d1b94ed5ce7d1d85759f19c5efb8fc5294b228a69dfe9fbfd0aedfe996dd8310e777a464e4514279131b9494fc3907391f9d65c5d889c4182ce46467b71ff006a396e032812b6778c6076a38750a2a99d76bd28bf51df7fafe4157da85aa4016d903a3b1c923393ee2b3d35e9da634392475c63346dc69b1bda24b1ca42ab10dce4a9f7a1752b19ed6da2ba96d648e19d3744cc84798a0e32a4f5190791dc1ae7e5cf3a6df611873a845b8ed37dccbdddf3c0a4062598e6964dab6a53d8c7a7c97d3b59c4ed2c76ed2931a3b637305ce0138193df02abba2cf7041e476344e85ad5d7877c4761aed8c56f25cd8ce93c6971109632ca720329ea3fc15e4b36494d87df629241351a9f965866985e69d0da59584f15fc374d73119248e256dd6edb88d8d90013800f191835969b2ec59822bd523cfc544d551648139af1e2bc38a91e2aca3ca71d2ba4e6b82bb44887aba33edc546ac52769c0ab440eb6746e146481c9229e787f40d5bc5be2ab4f0fe88911b8bc6288b348224c8524fa9b8ec69359a22c6199c0cfb519e6247b7d5e927236f5adb1",
            "571db16e4af646e347fa5bb68d8e2485887da43608e31907079f6a0ee84e88c1bf0375ef5a6f0cea36da6789e3bfbfd2edf54b40a435b5c13b1b2319e3d891462f87edefa4fe1b08d6493a00488d49cfdf81f34c581ced4119a793d392e661ade0326d0ea446c7938ff5a6f79a2585aa69b269faa7d7cb73117b984dbb47f48fbc809b8f0fe900e471ce3b56fa3f0ce8ba6dedc27d535e5944e552e04462f3003c360e48cfb55d79a64461ff00d12ed1d8ed0d85c6739f9cd6ac7f66ca514dbff22bf8c4f2708ecf3f8221d2b4cd3f52fa94bab6b984389a2c8092e398ce7a907fb7c52f827319922456dfd1b07d59f83ed435ddd5cc16c6c9af1980cb244092a18f04f3d3a55760977752895954971c027695fcff00d2b6e093c7fcbf248e4715273d235765142248a33ba64521b0783f14d7588a68b4f492dd915c8c00c338fd7e2b356fe646892aa4ac239061ce768fe9f1d29e6a1751adb4ad3e14e0372719f71f35da854e2eb48c99ba6965cf0941fb7f7fbec642ee54b6577e198800fdeb3c6292e5a4639193455f4d2c9752147529fa6699278934cb3d17494b5d2234d56c6e1a69ee243bd2e46e055593d8639ffbd7073c92f6f83b31c5e941c62f6674c2e5d0acaabb3db9a22eb49d76ff004cbfd5ad2cee2eec34cf2beaae6352520de76a6e3db272050da95fc97b7f36a388a169e46919225d88bb8e480074033c0a0dafae5ade586298aa3e03282407c1c8c8ef5cdc8f5485cb13e4a5dc501cbbe5d0727ae2b51a645005cc855415e87a1ace4f1321f526cee7e68bb0732491c4c30a3a1a574f27098e8edaaec6eed216bdb37504ae4609001da3a62b29abd92dab98d3d5c91926b496303da5b2dc7d485561dcf0dd80c501a82c32aee6957737e24e78aec750e393125254cd1296171a4f661dc90c466afb625c84c71fdeadba84170db76d596965773a4d35adb493476e82495d10911ae40dcc474192064fbd79ea698154c6163a6da4b6d793cd7d15bbc116f8e39036673b80dab80467073ce3a506a23593240c0ea474ab61982c65080df26a87c1dcdc61874cd3d5201c6c24a279b8e077e2975c18f71eb9ab525c0eb9e28793ca92740f2140480cd8ced19eb8a09cb5a054288068c1c6dc8abcf944751f9d57a943676daa5cc1a7df7d7dac72158ae7cb31f9abd9b69e467d8d0c092719eb4a532dab2726d0dc516150c0a4f38e4814332aa85c7a89ed5ddf9501b81ed56b4f6468e79857d23a76af21cb7a9aaa6233c57012286c81979a86a17a96d1dedf5c5ca5ac7e4c0b2cace2240721572781cf41552a954de5bad7a030bdc44b396488b00eca3240cf240fb534f1047a25b6bb7306817735e698a479134ebb5d860672303be7b0ab55658a59f20fa6a93d2ad72bce3bd547a50488449c1a36d8e96da7df1bdfaafadd89f47e4edf2f76f1bbcccf38d9bb18ef8ed411ae0a021ee95c357328650c3b75aa88c546888eab103009a9ef21481c03558a90ce7a544c8301a4df8d19358683162f3b5bacbb87322a862b8ce7a3039c639aa920675071c9f6ab60dad11f33d200c71deadb704f0ab8c9ea29f1889949a20a1a1c14c003a1adee8ba17d5781effc5736b9a5c6b65731db7eef926c5d4dbc13bd53b81fe8dff2f38e301560c1839f6346db5990c8cfc2139c8ad10524f464cae2e3b1cf9f120c8ca285e00ef44457af246f1860a7aeff0063418891e44553c01d3deadb5b66691813853d01ff005ae845cae8e73516b635b08ae248c20dce80efc2b704e2a37a8d01775ca3a71b4f4233ef4cad6358f4e605c28dc3d2bf7e286bc6f3252aa81d00e1df915d7c4aa1c4d5d0e66e4e0bb58adbca9ee7ccdbb07ff750d12ca6e98a12d8c28279c55f748b00668f1fc3fc433d7bd42e8c563a0da6ab0ea96f25cdccad1bd960ef8d40e1cf6c1ff6ebce15972431a4a4777dab1f148756219a261792128ca76ed3f3ff009a47acde18636b7924778d136282d9da3d87b0e7a558bab19ace30250b8ebce3f4accea93f99786443900e39ef49cfd42863a8ecc18232c6ddf6f803d91843952491bb24631f14adf1b8e303ed4c659480c3a1c7bf6a56dc935e77335aa355790e5485537124303f8715e991c41e8248c7bf4ae2c6c18890f2c719ed44ff000e38429e878247bd5d5af8024d0a446e41600fb5447e319f7a7020658a467752a791834b9612b3119e3dcd26506a8a8cd4bb139446224318f574343b0e3a1ab0121b07902ab6393c702aa5b0d2382a436e39ce6b8a38c9ed526423076900d522cf22979150100b1032c7007dcd157b64fa7ea77362d3c13b40ed1996da512c6f83d55c70c3d88a17071bb1c5754fa4e0f39ab4530b823ba977adbc124db50c8c2352c5540c9638e807bd7a22f2caabb48e8315a4f08ebbe21f0cdcdd5ee83a8358bde5ac9673c888adbe17c6e5390719c0e47231c50765a72dceb76da78b9b683ea6558d67b87d9145b8e373b76519c93d80a7a8cbbbec67964574bb9b1f08ebdaa691a1eb5a259f95f49ac471c774af12b92a8db86d63caf5edfdc034524b2ab6022b061960070c3f2a45f4e745b89eddeee0b9682568bceb5937c726d246e46eea7a83dc628fb3b94b860ca0840a464745aedf4ee318d766ce665729da9763592cb198add08112cabb594630a2887367670a42d3481586e0c07538e98acc6bf16a3a45edbe9d7314915c2a072ae41c86e9d0fb541ac6e6ed1228ee0aa28c901b93f15d38666f7056645d14a2937aeffdc59756d7b75af5adadb5bf9977793f911206199199800324e00c9ea7deb63a7e9f26837b",
            "79a5eb107d2dfd8c8d1491f9818a38382320953cf7c9ac86a967b9dd26924c28c640c863df8ed5a3d32ce116d1ca1d648d546f5f8a1e970c9e56e4759e0866e9f86574fc57e9fe06ba48bdfddd35ac3764d9c9379be571877031bb3d693ebeb1491202a37f2a71d4d6ab4ef2635c46a8b18f91d680f14bc29a1c16cb636b1b24cd22dc247899f70036b377031c0f935bf24562c6d25f7983175af1f52f1e4b7f1fdd1f26be5105c3c7c0c8cf5aa74fd2750d66f92c6cadbcf9e5c8450c1738049e49007009a67a9c492b89030cfc0ef4a9e094c4631923766bcbe78b76771647921c98322216552e012718abedfc9f35a2d9c28c8c9c6686f2d62725b23daa50cbb2e03a82ca4739ed59e2e8b6a5c7409752037051b2141e839a251dd210a13737b2d49b6190f990f24e463a53386ead5e357489564e074cf35508d36ecae4e34a83ad4db3e85387b79defdca14712009128cee0548e49cae3918c1eb4a2f12e30599c05ce09cf5f9a61e7149551dd0163c11fdb14bb505965877331db8249028b234932e58d5d892e2762ea327d3de9ce8fe20d6749b2d46cf4ed426b4b5d4e210dd22749901ce0ff0051c7624742690c83d40e09cd1b6b70850ae3d7d0573b95bd8e8bb7b182c11bc7b5073d7a509736e626f476e3145add6c4380abc74eb9aa2e9a411ef200ee08346d8e953408b18dc048719a1a68c28c820d566662c4920d37d717c34969a41d02eafe7b86b456d405da2aac77193958f1d5718ebff85b9086c4b4458d95dea5a8db69da7dbc97377752ac30c318dcd23b1c2a81dc9240a1b3565bdccf697315d5acd2413c2e248e58d8ab230390411c820f7a004bafacef34dd46e74ebfb792daeed6568668645c346ea70ca4762082287278cf7a2a2992fb5849f58bcb8293ce1ae6e3ff00765219b2efc9f53724f279344f88a1d0edbc477d0786ef6e2fb494908b69ee23d8eebee47ebd867ae074abb20aabb5ccd7b35443a3ad74927a9a8e6bd9abb2121d0f15ce09e4e05740201c74a854641f78bec3c31a77889edbc23aecfade96228d96ea7b636ec5ca82ebb4fb36467fbf52805779ae74a12177a42e480723b555dfa57b248c57ba55bd9287de1fd7ed744b2d66dae3c3fa76acda95935ac72de4659acd8907cd8f078718ebff007ca2cf3915e5c6e0586457b19e474a842fdcc40cff004a2a1dca0797c0eb926878639ae1962863691d8e1554649f81538e52b10007ab38a7458b92b41f6ac0dc299188f81cd3e8c9c6dc0603a0a4b6ab12624e1b229ac12234c013823fbd6dc5aee73b353618a7cbc1e371ae1bb3131c21249ec6a8b895c4a142f03a1a824855882e4fb715ae2f740e1c49ee4686d9f7db22f466ebeacd79ee64803165cae3a8ef4921ba6dca11b2c78c138c515705e385d9dcb60600ddc735b2399257f01c63184ee5dbe05ba95ecb1b798b921f93f14a5a7fa862368c8e00c55f7a656665520e0e08dc08a8c568cb0a313b4e7935cfc9396499d5538ba6156d3ac4be94049c039a53a8b33c998ce54d30bbd91c2a631c7278ff0039a4e2640c58724f6a5e796b830a97c110422ed64dc4f7aac20f30f7ff005a732f87f588fc2f1789a4d3dff74cb706d63b92461a40325719cf4ef8c70693ac6647c29c1e833585fc2019017042f386e7352772f827200e7146f87bc37ad78ab561a4e8160f7d7ad1bca224600ed51b98e4903a0af681afeade17d76df5ad12f3e92fedf77972f96afb772956f4b020f0c474a4f2655034723185896c85c715c33a1386e0e31c0eb5c4dc24f574ee2ab9f617cfe11ed4cb6959231ad9c91573e834459e91a9ea169797561617173058c7e6dcc914659614ce32c4741ff7f6341f41907345d8eafa9e9f6f796963a85c5b417d1886e638a42ab326738603a8ff00bfb9a537613068dcc673b739f7ab8489e62ef3853d4557300842afb7355035775a1757b0997631fe18c0fbd50a84ca16a6855bf94feb4d2da380301b32c4628e31e4c072e2869a6a186dc0762bb8741ed537b4d92eec0651fcc4f4a9431e30a5b903bfb51cc14a05c01b7a66ba518fb4e5ce4f95af20cd2a92a801655ebc75a656b2840aeeacb823b707f2a54b091312ce047d781de8960cab949403d783c8fb53e136b61ca5ed490db50d45b56bdfe348ed2a2e048ee58f1c01cfdaafb0b97b3bbf364076fe124608ff006acf5a2caf7b1e6451c72476cfcd7d22c6d347baf04df4256d6daf2d4fd4a5c4acc5ee0636f92a07a7afab3d73f1923574f91ff5038924fd36fb8b2ea68a40a1adc15dfbf27e7df1d689290c51c6f133aaf4723f09ebfda85b5962b8b75b297d1804073c11f144406dd3f851c920477da03f6aeee16aecd385a8c945f78fe418212f2ac366c581c3024639f7a135e33cb6db642580e17deb51a55be98f7c16f6f5ad20319649228cb967c7a463fd6b2baccadb482a095241f7141d466528b81cdcbd54b3b8355af3e6fcfe7a3133858584670777504f7a1de2b89606b88d1fca8d86e60385273804fce0d5f75832312013938e73424b70cb0945276120b2e7835e725a674f1ddaad81dd2b485576e0d15a46817bab4f3269d6d2ddb41134f22c4a58aa2f5623d850ed7800c1200cf4ef5cb5d4ee6c9a49ecaf2681a44313794e54b21ea0e3a83dc56693566b5269d5506c1a7c5236f770c0f419c1aa6eed95248cc71f965b8e4e07deb43e18b3d4f58b0d66cb4f9ec5208edc5d4e6e4a2bed8ce711b37209cf38c67bd22b9b89668c44c5188207239aa9cd3548638dff005161b4f26d9965065c0c86a5925ded56b75c38e809ed",
            "538f50950c710ce075de686b810105e323767a8acb9269af6950881cd6ecd1820f3542c5e51c9249f8e9462b8328ebfa75a85cc5804a9c8cd671dc7c8c34d3e1f6d0b579353b9bd8f5248d0d824080c72396f57984f2063da914b73348a119c951d2a03729e4715e95958808381ef420595d7abd5eaa04f57abd5ea84a3d5eaf57aa1287371e16d7ad7c2767e2ab8d39d346bc99a082e8b2e1dc672319c8fc2dd47635dd2bc2bafeb7a26b1ad697a6bdce9fa2c692df4caca040ac70a482727241e99e84d2a6b8b86b64b669e430231658cb1daa4f5207406aeb6d4f51b3b3bbb2b4bfb9b7b6bc509730c52b2a4ea0e4075070c01e466a89409debd5e208eb5eab21ddc715ccd7a89974fbf874f83509aca78ecee19961b868c88e52bf882b63048ef8e952cb07ce4572bd5de08c77a84398e6bd530a00c93f97bd440c9a9450569834e3a9db1d5bea3f778953ea3e9b6f9be5ee1bb66ee376338cf19a22fa6d396feee2d2967fddde737d39b9dbe6f9793b77ede376319c719cd2dce3a75a92fdb27de893aec530db3bc934fbd4bab2ba9adae233ba3961728c87dc30e41a2742d46cf4bf1158ea579a5c3aadb5b4e92c96770488e7507251b1d8ff0099e94a947a88618cd4941126d07a55d83468758d42db55d66f751b1d321d2edaea77963b2b7c98e052721173d87f8074ab2cd0292ccc7dfaf7a8787ff74b6b7676fad5c4f6da73c8a2e278221248899e4852464d59a8cba7c5a8dcc7a6cef359ac8c21965408ee99f492a09da48c71938cd6bc74bb992507274593cd83b95fb73f350f3f7e39183c74a1755d5df51bc49dedededd96348c25b42b1290aa17710bc1638c93d4924f7a196e5d50c6bdfda9dea0ef42924bb874338b798b230619e3e4572eb51669090d907a82680fa85600b0c153ce0d093132c85b76076aa79dc63511f14a3e0396e099371c7279155b5eb4b2104ec0381cf4aa61072a54eee719357a5d456da7deda1b3b499aeb6159e45632c1b4e7d041006ee8720f1ed4994e5564924dd8c22d1f55d47c2faa78861f28e9ba6c91c73969943867e176ae72471dbfdeb3237025855b1a072ca580cf3c9a831d8768e6b3c9b97ba45870bfbf934c5d39ef67366b21956dcc87cb0e460b6de99c719a149d89db22aed364b35d42d8ea51cb2598957cf48481234791b8293c6719c54f5d7d29f5dbd93438ae61d31a5636d1dd30695533c06238cd0de8a1a5df88b4a6f08695a669ba1ae9fab5a3b99f528a421e65604638e79079c9c0c71d4d66d549e6ba231b4926ae8e3382c338142a2c8f474805793cd552ab71c75aba30d24a32718a9cecbb7701c814c69345df8050abf23dea0400dc1a93b96278c7c0aae94d9075a34fa1c5f5e75db1babddf67225a7d3ce22f2ae0e363be54ee41ce57827de953609f4e28f86eb4e8f41bab39b4af3350926478af7cf61e54601dc9b070db890727a6df9a5d83838350a2f818a9008f4d3fb1da0648183ce4d21b70ed22e33c7b0a79651c72dd4304b70b6f1c922ab4ae0ed8f240dc71d875ad585d6c46456a82167c4cdeac74ffc55ec5f3bb9e79a3fc55a3d8f877c737da2693af5af882cad59447a85a8023981504e3048e09238279068191d7d45bedf35b714ad5888c5c5d515312d367b8e87dab49a21f0cc761aabebf05ecd712da15b0fa69155527cf06407aae33d2b320e7d59248f7ab0a99414f3393c8e7a53780c78257f40bb500ceb2a28049eb8eb5f40d16cecf54d3ee1dae2dac0e9f034ade7ccd9bb3b8611463838fd6be7da6f991ce91990123a822b5914ef0c61c6dcb74e3b56de9e17d9d331e5854f8c56d96de5ca593192187f88e71b57a2d49e6f3e2858a9e0ee6079dbf6ff006a1af0f9996057039f8e68db6282d44c36e40c6d3caffe6bad08ab6d858f0e286359269f2eddc6f6ba87d17d2cf6876cd090c8c464023e0d6775cbfb9bcd467bcb87de656676c70324fc5172ddf996c62c1e071c5666ede5fe6dcc0f039acbd4a8adf9ec2b1fd9f922a4f75f0fff004a75ad3351d3bca37d632db7d4442588c8a577a9e84520c336558e73d735add5758b3d47c37a5589d3664d4ed19c4f7f2de3cbe7c64fa1046dc46147b75acc3c4c33f35c58cafb9d7e9a3c17127602cadf52b5babfb0fde1691481a6b6f34c5e6a8eabb872b9f71496e8a3ea53cb6f6c6d6da4918c70ab97f2d49c85dc79381c66b5fe22f0d3e83a3e85a80d6f4dd43f7bda9b8f22d27df25b6188db20c7a4ff00a861db2728c9b8ee6e33ed58f2a527687f16d95b5c94411a641cf268fb7bf845ba8658bcc0c5bcc00ee6c803079c638f6ee694dcaa66309f9d49221ea5c127148e4ee89b7a637bdd4adae5e3912c21802c2884464fa880017393d4f538e2924f75870b11e055ed188a203058bf18f6a5b22324a4118a098bb6986c73aed0075ea78a248694e02918e6942121fde9d594f1f964484061fd6816c6297801b82aaa028ce78a65e11b0f0c6a3e234b6f17ebd3e87a518a466ba86d4dc3070a4a2ed1ee703fdba802fa4439d9d49e4e3a501d4e49aa92f005d913c1383915ccd78d7284a3b9af66bc064e2986b3a3dd685a9b69f7925b4928449375b4eb32619430f52923383d2a12c5f9af66b95ea84b2fb6b76b967512c51ec8da426570808519c0cf527b0ef55838a85748a8424cc4f2454735ecd72a10ee4d30b8d7358bad0ecf43b9d4ae25d36c5de4b7b567263899f962a3b669757aa12c63a7eb175a6d96a5690476cf1ea300b794cd0248caa1d5f28cc32872a391838a5f935caf5425972e0c7cf245471dd78a88",
            "3c75abe17e3900d1ad90a0921ba608a2e360d18fe1827fb546640cd91c93d2b8aac84303b41e0e2ad2a60bd85246241d7241fd2aa7428c73f8bdb18aeab34530f2db20d5b236f90961c9ef4d4ad0318b6fe830b0d0f58bfd0b50d5ec74cb9b8b0b0d9f53751c64c706e385dcddb34a181dd9e72074a7763afead65a45fe8f67aa5cdbe9da86d1756f1485639b69caee1df14ae4da27e0f07ad1f1d0caa646309b72c7d469d8bdf0bff00c166d0e9b787c49f57bfeb7ce1e4fd3edfc1b3df3ff9ed48e63953b3057a7daa85daaa431c9239e6864e9d22de997372393c570c3b554f5f8aa70d807a8abbcf75e9d4715134fb913b24bb43ef2718feb42cee1a562338356cec597239a1739ebda8272f0434fad68fe17b2f04787f54d2bc53fbc75abef37f7869bf4cc9f43b5b09eb3c364565c64d78119e6bcc413c74a414732735e2c49e6bd9cf5a6fab7fc39fbb749fdcbf5df59e41faff00a9dbb3cddc71b31db1fd31df352c82b5930318cfc531b328c8519463efcd2b07068b8e4c10c0631ed4cc72d83257a2571b566dd103cf6a19cb92189cfbd10f89791c11d2ac82d1e4e0ae73de89c5c9e8aec0a14c8405fb1a3e3b58fca19cef27038ab24b47b158a5789b64b9dae54856c75c1ef8a92cc1a50a0718c668e314bb8b9c9d680a4b7f2d581c96ed42a2b336dc53c99084248049f6eb40ac6a198ed3f950ca1b2a192d6cbade2543853eaf7ab49647dcc3a9cd72242dea0d8e68b914300b92456a846d682b4caedf63dc0da36e39e2b77e15f16ffc35a7eb76dfb834bd54eab686d3ccbf87cc6b7cff00321ec7fd429ed58c890260818344a390319e29ca1ad99e71927ca248c6a7d58e7deab41b9b8ea39a9098fe1db9069bea5a769f6563a5dcd96b115fcb770192e2048d90da3ef2be5927863800e47bd688cab4c7e2c9286a5f817f876db4abcf12e9f6faddf369fa7c93a25c5d46bb8c484f240ff31f3d2986b09a6dbf89efedb43bf7bfd32195d2dee5d7619101f4b63fccfc564cbb07c2b673edcd30b372244e31cf526b762752e566a714af2791c793712dd476f6c1a59e465448d79666240007e757dc35ddac86ce68cc52c4c56542390c0e083f340096782e1258dfca914ee5653c83d8822a9bb5ba7dd74e59d9dcb3b96cb313c924d3de47662b53ae4d587ac8c14ae4061d79e9415e30740c082066b9bd84aa647c6d03f31435e5c2885ca29c13dab9f9e727dceabcff00cbf7f7fa0b5df6b124647b545648d97d247b9aa2594163b8952475f6aacc870170403dfdeb05bb31649f26a3e0d078907850e91a13f868ea435136c7f7a7d5ecd9e76e38f2f1ce31efdb6f7cd659e193058b139ed565c349c145c20ebf3504ba2982467db34896b43f1b4d15fd382849ce7da8eb38e37575520103827ad0af3960c179cf3f6a1fead53d03b9feb4b492d97269129f74590c467279343048e5e5db27b5557970f3396c9fceabb624904f34b72dd0b7bd1392030befcd56304e7919f6a2a5977a8848248a18ee443cf0075a5b54f4468ae498b6475e7a9aaf8c75ae1e4e6b943609ea93c7247b77a32ee1b8646323dea3455e6a17da87d3fd6dd4b71f4d0adbc5e6367cb8d7f0a8f60326a8a05af57abd5087a8db71a51d32f4ddcb76b7e367d22c51a989b9f5f98490471d300e4f5c5055ea843d5dae5740cd421e228ad3b4ebfd5f53b6d334cb496eef6ea41143044bb9a463d001ef4254e39248655962768e443b9594e083ee0d421e92392195e2951924425595860823820d42ba4e4e4d72a10f577935d5ea6bb8c727f4aba2ce0e33ef4c747b78350d52dec6eafe0d3a195c2b5d5c2b18e21eec14138fb0340020f6ab2353bc01e9a25f42985e9da75feada947a7e99692dddd499d9142a599b009381f604fe55532311ea18fcfa51703496d279913b2b0ee0e08355cae26ce02ad378d7712dbb042edb88edf14409303d3cf155c3092db986147f5a29515c9c640fb74a3c698f8fc22b8177e412714fd7fe134f055f8ba3a87fc4bf5118b429b7e9fcac1dfbbbe7fedf34902947d89c93de86b8639e4818a396a3413ee34f12e99a5695fbb974ad7a2d57ea2d5669fcb5c79321ea87e7fafbd67b71f7af31c9cd72b136c1098a4c8c13c0a9367d5d8550a0704703dea6db54805b22989957b24d2288f1d5a8627249ab06d627dab8627f2da408c514852c07009e833f91a193b2caebd5dda4f4ae74a028f574572bd5084957774e315746a0293939ec2a0c3674e2ad8e41b4eee4e2991abd902a045752dbb07dead66755ca13e93da8789d49ec07cd5f164bfa8e15ba5698f6d14e2e9b1dc9aeebbe20d334af0f5cde3dc5ada3ecb4b760aa119c81d71cf3ee6b71e35f0de9ba4e82b6dac5ee9ba678bb499a2d324d16c2cf6acd0ac7bc5cbca090eedb864f19c018cd7ce92c2d7f761bc6d43176b3aa2da7964ee8ca925f77418200c7ce7b56abc33e1fd33c596daf5feb7e33b2d0ee34eb53730a5eee77be933f814fbf4f73c8c2919206ab6cccda6e8c94c800de5b81db344c1a2ea52e947577b19869fe6f93f5210f97bf19db9f7c51fa0693a6eadac2d96abacc7a2da48ac5aee58cc8aa40c8181ef54c3a95fa69efa147a84d2e9cb3195620e446cfd37853df14dab95149269b0430045f464d5b147b892cbf61562b818c8cfc1ab572467a8eb5a2a84ce6e0a887963233d6ac01470a338a89f51c8f6abec25b78b50824be84cd02c8a65895f6975cf2a0f6c8ef457a16db947b95edc64e3fa53e83fe117f00dcadcbdfff00c57f5cbe485c7d3fd36de73ff56ecff4f9a1",
            "75fbad26f7c437b73a1d8b58e9d23ee86076c941fa9c73938c9c74c9a50e3072467154add178e4d4abc91c796558f3cf4a2eddff008bbc741546d52993c1fb54e1590c8367a54d6b84f66ff5d493bee3f48e292555deb107214b9e8a3df8a2b588e2b0bdb8b2b6be8afe18a468d2e61c84980fe61b80383f22a8d26fe0d3b5ab3bebad3e1d460b699647b59c9093283f84e3b1a86bda9437baade6a369611584171334896901252004e428cf6157cdd9c08479356ed896e33e7ffee63bfde879a450b90ed800d5af279b8661eac607de82d8c8ecc7bf4fbd2f2763d042dc2a4f6073c8738edd6b902fa08273f3ed51b9dd901b0307afbd58998e3f4e093c5628bdec646a3fd5dcb656409b08278a1c5bbc8cc00e0f238a2148f300c648e956f9d244d82a369ef9e941357dca9654d5217cb6ed1b7a87df14aee102cad8e335a190151bc9c83fda935dbc4ec063a7539a5648aa294b976169042f26ad824d9cfbf4af71d803ed5358c8f5e3a76f6acbe46a45ac770dc54f4e08ef42cac70a32718cd10921e411d393f6a1a6396eb9354d96fb15e4e7238ae55d68b6cf7b025ecb2456cd22895e34deca99f510091920678c8aae511899c42ccd1863b59860919e091da86c591af57abd52c87abd5ea7babea5a15e787f43b3d3343fa1bfb38a45bebaf30b7d5b16cab63b607f7f8a964145b5add5e4a62b4b696e240ace56242c428192703b01c9354d31d1b5dd5fc3f7af79a35fcb6571244d0b3c67928c391fe742011c8a5c4e4e4d4b21eaf57abd52c87abd5eaf54b21eaf57abd5087431073522c58d42a4bd6aecb243819f6abe39085dd807daa1163773d6ae60bb8041c114d8af24af0456e1fcd6cf35720dcc0923feac77aabe9cab8655c9ef579531a125719a624fc82e0149845c71834fbc49a159f872f2cadedbc41a76b6b776715d3c9a7b975859c12626cf465c723e474e94ae73a1b68da67eee5d43f7b7f13f787d46cf20fabf87e563d5f873bb777e9429b693cb32853d76e70719ec33ef4d8b7dd009a8f72b6c891a541803b5053b03927bf635d9da44049279eb42962e4927814ac93b7437cd9c5393822a4002b807a5579feb52524631484cb26a182e00ea7a57a453dc735746fd4eded8c515aae93a9e8da8cda7ead632d95e438f3209d76ba65430c8f9041fce89a400b978f9a323d63508b46b9d162ba74d3ee6649e5800186740429cf5e3268343ea20f435258f9c8f7a1ab2c61a4dce9d69a82dc6a5a67ef1b511c8a6dccc62cb14215b72f3e9621b1df18ef4ad8866e062ac91800540c669a785b54b2d0fc55a6eb1a8e9106b369693acb2d8dc711dc28ea8dc1e0fc823e0d46412e077e2b94c359bb8752d72fb50b5b08b4fb7b99e49a3b584e5205662422fc00703ed402ae4d090936ecf3c9a8e483d68a5452a49383f35548809cafe956e2c89d928dc0c0c53bd2cd92ea16ada9472bd979aa6658980731e7d4149e01c6719a491a9521b033ed44c137fea7693d4e29f8e55dca726968d3ebd26832f88af24f0d41776fa5b36608aed834aa30339238eb9c7c5278b7094863f88fe9cd5c6242b90c3ae3af4aab9899897cb751c56992aa33ce9f6ee1b26c0bc8e4f419a6fe23f0b5f7847588ac3529ed25964b68ee41b49d664daebb80247438ff71904139979caa1dc779ea3356433195492f86c63156a49b2a11a8ec2d24dd270b9a22263d1bbf7a1a5b99a594cb3bb4b2300bb89e780001fa0153560a80367a669cb681cb8f92d05e4019f6a61716ba0fee3d326b5d61df569e674bab5921291dbae4046f33a1cf53edfdd4c6eb229e38ce2a0d17a8f1815108c2a316d4cbf51b43a66b775a7fd6dade8825311b8b393cc864c7f32371907deb8ac08c1c838e943886457e3f5157a28e841cf6a2b1f9dc1d38920d821481815df38ac9970547b0aab2039cb702ab9a5f3004c703be6894a99518d4fb078bb2edbc2fa4f43529a61201b549f9aab45d36eb5cd7ecb43b09218ee2fa6482369e511c6acc700b31e828bd52ca6f0ef88ae346be30dcc96170d0ce20943a39538601c76e3af5a28cd5d792e3823192710292e02edc1e40e0d0c1839c1393da8bd6ae2c2f75abab9d2f4efddb6524a5a1b4f38cbe4a9e8bbdb96c7b9a561f0fdc628a4ed1b9638f1f6f72725b3b72c7a735510460741ed5a7f0ec5e189ecf5a6f12ea975677315933e9c9047bc4f7191b51f83818fb7df8c1ce4a4e71c1cfb5668c558b827cbdc4db05428249c514d776cda28b1363134fe7799f5596f336edc6cc6718efd334124c23c7427b8a8abc72e595769e7ad2b25b12d53a2a95d8a9c92179a5122032e07e1f7a7a9079996917d3edef40fd32f9cf9185078148945b0f1356d1089004e507c1aeca9b5c060307b51d0c5129c3124374c1aa2ec3193626081d3de96d577375348bfc3fe1bd43c5be24b1f0f691146b7f7ac562f3a511a1c2963963c0e01a45a9e9f73a56af79a65e051736933c128470ea1958a9c11c1191d455ecb233739e063ed4be442adee2912172446bd5ce6b9422c957aa3cd7aa10957aa3cd77a0eb50876bd47e91616da95ebc177aadbe988b0c9289ae039566542c106d04e588c0ed935dd2b45d535dd52d74ad1ac67d42faedf6436f0217773f007c73f039a858bebc319e7a55b3db4f6b772da5dc325bdc42c5248a552ac8c0e0a9079041ec6a93c7150a34be32b3f07596b5045e08d62ff0055d39ad627966beb710bace57f88a00ec0ff00a8cb01b8e70024d79325b8a99077648c0f9a8595e39c57769c671c55bb001bb9af190eddb8e3daac9453",
            "5d190335688c7520e4d702863b3daa225138c17e8074a210608607815e8a32e80a6700e0d16ca042b1aae0935aa08194b8b56754b3302a08eff7a3f49bd874cf1058ea97ba5c1aadb5acc92bd95c12239d41c946c763fe67a5542ce589a00d1b9370b989719de32578c7c823f2aa24c8c01f88d697b544e77d90cfc4dacd9eb5e2dd475ad3745b6d0eceee53245a7da9263807b0e9ed9e00193c0030296b5ddc35b340b7120b76612345bcec660080d8e9900919f93434d1ba302df8ba71519233e5e770ce334b5ad14924eca2edc390a0fa68af0fd9e8f79e25d3ad35dd464d3f4a9a744b9ba8d37b45193cb01fe7e7d296484bb7b9f8ab5237db823f3accfdec3ee34f1758787f4df18ea761e16d524d5747865db6d7522e1a45c0cf619c1c8dd819c670338a590c71b29dc79c715058b0fea35e652ad907355155b26c222551b9b60e98e6b923cb33992691e4918fa998927fad76362bea2719a7fa8d9f8520f06691a8586bd3dcf88279655bed39ad8ac76ca0ff000c893a36e1cf1efdb1c9bad0b926d99a68cb12178c735e55903fb0aeeec927bff6abeeedaf74fb9105fdacd6b3050c63990a3004641c1f7141a2b688dd6997b66d09bbb49adccf189a3f36329e621e8eb9eaa71c11c1aada1545cb1f9a60d7b777cf17d6dd4d722289628bcd90bf9718e88b9e80738038aa5d4b82ac719a6282ab25d2b62b3ce4d70060c08a65259f184539033d28768b68264193f0694e0d16a49f620cc55b1802ad1807791827b55930895866bc883279278c8a34b741aab3bb448011b471dea11c7b65c85a6565a46a37762f7b0d94f35ba4c903491a12a247ced4e3b9c1c0f8aa4c2f14851c6d604820f5fb532ae81977a3cbe66ce0f5ea05580811ef7e31d6a28ae589208fcab9303f841c7bd3d27564e369d9448e02650657dfe6a859640e3a81ef4508b703c631ed5c8a312310c080948a6d8b8b5b4196e59407dc08ee0d138dd260f39a0e1cef01413b7bd38b268ed9fcd9ada1b9e31b642c00f9f4915ae12540cf2c617f25b0dbc6da45c5cb31df1cd1c60678c3073fff00c8aa5bd3ea26bea36be3ff000fa7ec3eff00c307c1f6af7c6ed7f8833e5b16cb0949cefdea14a819c60f5ea0fcbef2ea39cae2ca1b60060ac4ce73ff00c89a919393768c9c39c953221885dd5353c67de86591795ce054da60ad8e7ee68a4e8278a49ed1399484051493de84181c2af3d30689f3b2a723154c8011bc0e3ae73d293c9f91b3a8aa070a45c9c1e9efd2af66758c1da30470050324d96f437a89e71ed5624ae4147018741835709d30a369a6c92f9854e5873efdab9e9dc072481fad4884590272d9e715ef2cf9dbf3b0638a6725e0d13c918d245d1a752c3271d2a724600181c9a9460924c9818ef5eb8f526e1d3145666f524f22a60ac9eadd8e470466a69173c8ebfd2a31924b0ebc64559182de96181fa500ecb1971b489bb800a67a7e9417d447b9f2320f426adb888ef001cae3a0342cd1aaa6dec3b525c9dd08c092d172b294472a7ef5c92550402083dcd08b2b0ca2f06ab9259029f71d71de91367514c35a5418caf18e4e6964fea6dcbd4f7f7abc6f9808d073539edc45080fcb01dbde92f65bb92153aed383f7ae6e1bb918a9c9cc98ce68d9f4c78b44b7d4cdc5b32cd2bc5e4acca665da14ee64eaaa77704f0707da9622896b9afea1e20b9b6b8d45a22f6d6d1dac7e5c4b18d8830320753f34b1465871c546ad41b9483d6a8a48e3e0b6067f3a895e71dea41bd5f353dd8907435643d14458907393d29d69b7fa9f876fad355d1afa7b1d42d9bcc8ae2ddcaba374e08fd0fb82452e84b95c28e734532b2c60bb6ecf6a34b4312d0ba79ae6eaf25babb9a49ee26732492cac59dd89c9624f2493ce6aa7193cf5a36355de44b9fb55326d6936907079c8a1a06b40eac51b22ba32464d5cb1a939c1638aa88285493cd515476366076ff4ab64b77e1f3919aeac7bb1ea028c9e2291ee521b3daae8351d0002d9db8f4fbd171584d34cb1c11492c8fc2a46a589fc8550f9c0ca8069d787b5fd57c3babdaeb1a2dd9b5beb5398a65504a92083c10474268a2889035aa6d4d806de3a9ad0787fc351788358b0b0935ab1d323b8ba4b779ae65c79619802e477033ee3a5249a791e79279a432492317663d493c93fad566e36f2a31f15b22bdb45ca09a3f56fed6bf645a37eccbc37e1df147853c426cb51d3255b40ba9caacb75b8b3165c8e1812c4803183db1cfe64bf667d4ae249e78ee27790b3cb11055989c92318ef446ade27d4b5fb2d261bfd46f6f469d6a6dd05d4cd208fd6c709927036ec1ffe20761498ee2f9c1a3c317156dd8b8c2b615716970a2de69eda589665df133a90245ce32a7b8c823f2a2f43bbd374ad545e6a9a245ad5b08dd4dacb2320259480d95f62735cbed6b57d4ad2c2cb50bd96782c23f2ad91cf112139c0fe9f9003b0af5ce93aa59e9563aaddd8cd0d8ea1e67d2dc3a6127d8db5f69ef83c1a7714d5318a3e04260456cedc679fb55889803b9ab5d812576d11a95cda5cea124fa7e9ff00416cd8d90094cbb30003ea3c9c9c9fce97c545e8baa174919128247e5536843a0651d3a8ab325872393deb4f0f88f494fd9edc7864f856c65d465ba5b85d60b379c8a07e01f1f9e304e4138229c56e8a7dad1919300ed2306a0b1a647393f6a224886e525b3cd5890856dccd918e00ef4aadeccaf225dc0de355237640cf6a3f54d4af75bbcfaed5afe6bdba2aa86499cb3155180327db156344b20dc07d862aa5b70bb8a8c8c715385b0564e5bec06118950a",
            "7a74ab9226fa805fbf6a35220a72e9861f150059dc103f09c74a3f4cb69b45c0aa46475e33cd2b9d325b7038c7146dc336e5539c67a0eb54cc80b919c01ee6ae7b5454635f894fd1b3b16cfb75a9f9088a5c312451ec8e32a01033da89112343c28cf5ac691bbd37e116f84b5fd53c2be22b4d734b086e2d64f351265dd1b1c11c8fb31e4608cf041af6b1a85e78835ebed675111fd5decad3c862408bb98f603a0aa6144407d2067b0ab46c6e173c569c75dd8ac98fdb60db561524ae71c502f89189e858d32900e4e2837d88dea5e3b53a5d8cae4d6c7fa00f077ee6d7a3f128d53f788b51fba459ecf2c4dbb9f373ce318e9db777c567fcafc447deab79712008304f7f7ab04d92c70703a9ed49e493606e8ec8443082ab838aaa3bb26318c91dc7bd55733a921705411435bc8c92119c64d0b9fb8150b5721fc5772fd3342ad88c90cc9d891900ff0053fad12fa56a8da1aeb6d6138d3bcdf24dcec3e5efc676eee99c529420ae72339a2cebda9a68e7446bfb83a779be78b5f30f97bf18dd8e99c53d4a905871f91868bad5ee8a2fcd83c405f5a3d9cbe644affc37c6ec67a1e07239a04e0b076e3e4f4a0d2e415381800d48cc58641cd0ca7bb4749a5414ea372866c83ce71d6975d4af1b3804eded8a8bcd2bbb286c569fc49e02f15e87e03d33c43abf87ee2d6d6e26622e180fc0ea863de01cae70c4640cd6794cc328372b31f148036ee413ce6ad8dcb92d9e3dfbd511a0c005f7023f3a3ecf4dbd92c27d421b19e4b3b765596658c9442dd0337419ed42a4c9e4b82f1bf2723a55b85232073d79a2752d52cafafa29adf4bb6d32348238fc9b7662acca8159cee24e58824fc9a03eac190ec1f1f6ad0a69f733e5e4d84a31e00c1f7f8ab491b76b1e3bd0d131f3791cfbd724386c83c1a7295a0631727430f120f0e41ae15f0bdcdedc69de5a61ef515242fb46f185e300e714a1a52d8258e33d315c2f1f3bc67e7fdabc8d1238c8c8ff00aa813a37bc9c2341025c47ea3c9e82a97c142814e4f435e3221901ca9c718ab10f98c7000c74ab6d3ec2f1f172b5dc09ed1c4a738271c1a6d6de14bab9f06df78956fac043693ac0d6cf3e2e1cb63954ee39ebf07daa1650a5d6a56b6725cc56cb348b134f31c2440900b37c0ea68df146936be1ff00135f68d6fa941a9c76b27962e6dff03f1f9f23a1e4f20f26b3ca0acd58e2ff00ec67a350a428e4fb8ae5ccd90ca400c477abc3c31e42af3fdaa89c824fab248fd290d50e7a40221da3ccc8e4f4a9c9b083db23ef5600806d238aae4848438cf3da8285d68058316e9538cb2b702b45e1bf127fc3f61ae5b7ee8b1d41b55b16b3df751ee6b7c9077a1ecdc7f6f6a516f1ae19881907bd524292b65663575071835286db2f9c74f6ab182efc8c003b53f835db55f0cae86745b313fd479df5fb0f9d8c7e0cfb535455d86926c060b6541b854e44206e017344a9460307d3ed54c9228c8030074a73546854b42cbe05583a6549ea7bd4634578b2d8ddfd4d13245e62ee0c09c719351f2d6370580248c7069328ec556ec148f2c3322ee19c67da85752ca1b9ebd289dc44846075ef54ccc5a5c29f8a5b403209900b038c55fe7bec219871d8d45a339ebdb800d56e4a8c1ebdea5503741b04725d29f2a177dbd762938fd2b6779e06f1069de03d3b5bb9b002de7919f6a73222b85d858638ce091fd719ac15bdd5c419104ef1e7aed7233fa56a6e7c53addcf8534fd2a6d6a7920b69a42b099395185c67b90096c67a64e28977412626991e1f44aacadecc306a0ac9924e41f6aa659a69a42d2cad231e32c726a51a336320d6a8bf825ec291020ca9e3ad5fbd55724e4d0cd9438030bed5e72afb41a7f2a4145e8d17887c55abf8baeeceef56685decad22b188c30ac404718c2e428193cf5a52f2cae89134aed1c79d885890b9eb81daa9846c002f249fc357345b79a283d503ea46f8f93d6f2cd697715ddb4ad14f0b892375eaac0e411f9d41d8c92348e4bc8c4b313dcf7aee0935308d9f4f6a6520a5430f10785b5df0bdddad9ebb60f632dddaa5e428cca4bc4f9dadc138ce0f1d78a50b090e0b02148a32579a6db35c48f2b222a2977270a380067a01ed5147046c03f3f9a5568cf29da7c7c0398cb131818c8cd491022e324b7eb52b9956288b6ecb8ed42c33a49ce083f7eb4bb8dd3ee668fb97b8250b798b8ee28db628ae0c89bd4302547191ed41a677ef079e95687f2c85ea40e6adb543ae2d550efc433695aa6b52dce93a5feeab36da16dfcc326dc000f27dcf34ac44b1c4486007cd502e78da5c6454e126604b64a0f9e94953a19e9f2548d059f886d60f02ea5e1a3e19d2ae6e2eee1674d5a68cfd54006df4237653b4ff00f26ebc6319711e1db71a76914414950411f9d0c6d43c8c5f1806818c58abb062a0c000018ef562955c026ba40db9c7342bc803d524745b514765c2a903183de8469d94955e475a95e3958b31364fb1a542e3d2fb860f6abe5c5d18e6edda349a178a2f3c31ae45ab58c36f25c44ac156ea212260a90783f7a59e725c48f23e15c92c7030327e3b7d852b8a5f3640b202483c5108e915c739fef51e46f664714ddb0878813bb76dcf435a7d0fc6d6fa3f80bc51e0ebdb692e2df59585e230aa298e68db2accc46edbf03d88e324d09e24d4f43bf92d068da2feee4481239504a5f7b81cb64ff86b38f0a8f5804fe74b6ecbe0c757ade0a93f67da6dbe9f67aa2f8b56e5daf2e25954dab43ced08a3d41bf0f5f66eb918ce84d84281c8ef8eb5479d8999738f7a2a14794ab479c13deaa2d1",
            "6b1d96c3ba4fe5c1f73529626319248fbd170285728e319a8dca11f847ce69e9e83585ad8b43e1781c55a0aac5b83601a14ab9908dc00268b4897c9f51071d28360b693d92b5d4ef74d8d8d94fe5b48464850738e9d41afae78cff006f9e21f13feccacf463a55ad8dc5c4be55ddd236f32f941181542309b8b027af4e300d7c6a658d63054648a15239198385f48e734a9a761c932ebabdbabdbafa8b993cc900033803207da9fe93e38f10e9be14d4bc296977b34bd45c493c5e58249e3386ea01dab9ff00ed156f86f5678b4bd5bc396be168f5abcd5e3d913ac4649a12a092540049c0f5718c119391c521b7015c80993ee6a2562a48323b50d1ef3d4f3cd190c0a22cb20cfc556f2308918718ea3e2a5e6058bd476e6b4c50894956ceed08d93c8aa9b2c770618ed42dc5c36e0148623b035d86627939e3b53549762bff00da25924593b80e3fb50bb0f19c9f81ed44348586e0d8a8890440ca075f8a097734b4e4b40aea8a4124919e9564575e59233903a9a1a698b4879f47cd41650c319c639159b96f454635dc25ee43ca173b1b35224a8c924eeeb8a081432162d915cf317f0863cf7ab736fb8e520a5b1b9ba252d639276037111a1623e78fbd7da74bff00e9d3c7d75fb16b9f162c76c6e26f2efe0d3581fa992dd55f907a0660c18275207b902be1d6f7f796e58db5cc91498c178d8a9c7b6457d66d3ffa80fda15bfec6aefc189acc4151a3b586ed81fab4b7657dc8af9e83685071901b19e9844dbf00c9fc1f3ff12f867c41e0fd68693e27d325d36f4c69308a420e518654820907f5e0e41e452459374a577673c56a757d2eeb53f00daf8e355f1b47a9ea12dc7d11b0b89da5b8445181cb127800718c052bcf6ac747b59800718ef514ac8a416eaaa71dfbd5810e319006339a11a422400b75ab4ca09c0e9d29aa82b416a11a21b8608efef4d2e75d8a7f0958e809a35a4535adc3ce6fd07f1650dfca7e3fd97a60e52798bd012466a6af1e768e4d334f45b2d4b97dbc7000e951494c92633e8f9af04c83b2aeb48904a1e44322a919407048ff004a36a4c16da22b208c6f5e87820d0935c3b3ab28cfc0ed47ddac4d7f3c96d135b40ee4c71b3ef2ab9e149c0ce0719c0cd04f19193818c7514892644dd031924dec0af35d8cab29751823a66aa91df760920e6b9e6fa38fce9565597aaed5dddcd56eb953b7ad79675006707e2ae478f3ef9fe94cd32f4c1157d58e71452202321fd5f6ae8883498dbb4fc517e400ca00393c516381121af8567d0ecfc476577e26d2a5d5b4a8d89b8b58a630b483071871c8c1c1fcab96d6d1dfea8b0c463b38a79c2a35c49e88416c02cd8e801e4e3b52f1fc118230bfdea2aeefce702b56a20e4d475dc3f50b336f7d35b09629cc523279b0bee47da71b94f707a83542c4593383baba8ecd839c6074345448193d3c30a746bb8953e293211dbcc22327964a2b00580e013db357b0ca82460d102e664b392d9279160760cf1063b598020123a12327f5341e5cb805c63bd45dcccd4a6f9d515ed1f509b49028df2d4751c918c8e2a1a7e9d75a96ab6fa7590f32e6e2411c60b00093d39344dfda5c699a95c69d7c812e6ddcc4ebb81c30ebc8eb51bd9a24b6a9814e848e739f6cd50771071e91ec28b665df83d7e68bd42df48b7b38d6cf519aea72e77836fb102ed520824e49dc581e3b67bd5a7f21a5e280ae8d9cda55ac11d8886ea30fe6cfe696f3893e9f49e17038e3ad2d8edbca1bc8f50ea28ae782a99c743ed536914f38e08c64526515dccce5c65b5dc1a3bb55620fe21da9f5eea1e1cb8f04d858db68b2c3afc773249737ed2e525888f4a85fd3b71827277719d316599d01cfb62ae8d4181b7707af3c629576b63a3ee768922a4bc0c1038e055d02489295618cd5568f124fdc93d85328a552198a9f49c034bb46dc716a56cea2600e7f5a9347b5762f53cf3559983b8da0e33573f4ca8e4d4bb3528a52b3ccc0020f4a5f395539e73deac5bae42b0ebdea174ead09c91f144a5425c9f9216d1d85ddea457ba87d0c073be7f2cc8538e3d2393ce07e7481c3336e66eb5295a4473bd805e954ab29939e47b934994ad99db1ae89fb95fc47609e229ee60d25a555ba92cd434ab1f7280f04d1de28d22d74dd6cc9a435d368d7399f4f96ef609a5b72ccaacc109c1255b8e0f1d05669990fa7a03d3e68eb6b7cc3b89c0cf414376c5b44819530e8778cf7aeb49706624f0bd7ed538e32be966f476c8a293cb276ecc86f7ab1914bc8ad618cce72c324f5a6d6912ac6594e581e2bd25b42d8754018738cd4e02ab0904904f351687c234cb645c10cbc9cf39ed433cca5c8271cf7ab5ca48ae81c67ef5d8345d5afb47bdd4ecec249ec6c768b99d4711e7a7f9dbbd3232a2a73f08a0429265b81cf6aa258595f629e73d2bb6ec400a09c0abf00cd95c9cf6229fcb9233354edb06917ca521c649e831425cbc8980aa1735f42f07f8535df1078816dec74d693ca8da590cd84455c10325b8c924003fd8d652fb4bbeb49a6b6bdb29a17b7731c81d080ac0e0827a75a5ca9e930db7562fd1f5ed4f42d4e1d5748be9f4fbf80b795716efb1d72a54e0fc8247e755d9b16639e8475350fa64336739f8a2a1850ae076ebef4949a60c4bda521391f18a8cf29318c3739e82a39f2c382c48f6354c9710a606dddde9ea5ad89945323e50dc5949627e29a6bba0eb9e16bf7d375dd3ae34ebd54590c3709b1c2b0c838f91495ae0a15937e07c55babeb7a96af766eb55beb9bfb86454f3ae65691c8000037312700002879a5d8aeda2a86",
            "e30ec77638e95cfac8da458dc958c919206481f6ef407ab3c703b8aec91fad78201a4b9ba1a9bf032d6574d8b56b98747ba9aeac14ff000a69e211bb0c77504e39cf7a5472ae39e7bd5e06241d96a12ec3c8ebf6a5b230abc861b4bf9ada0be8af62472ab3c2182483dc6e00e3ee28562149da739f7aa777a718e6b8339a9cbc12c237845eb8cd7aeede7b578d660a0c91acabb6457f4b0c8e84e0e3b1e477aa73c73d3b5758295caf6a8f64b2bae83835c009e82af5b766079c1eb54937d8876da3171742369e2801563be5242f009c700f27181f2455a190439fe63ed55f918230727357451a93ce69b18bb0e24e18dcb8c1c8ab04396dcb807a55d10da08e86a5bf690b80493cd69f4d256cb7a44a28c80dbb83ed4ceeb4d92c60b1b83736b27d5c5e6aac332bb460315c381f81bd39c1ec41ef40afafd4c79153f3954629f1aa16db712126049b89c8cf434be67cab11d33de8d6605493d683c2176dfce69392bb20a3da806621cee154e28b9a3ce767e1146cf7ba6c9e16b4d2e2d1228b5182e25965d444ac5e7460a1632bd005209c8f7fd71496ca6275193d68eb68db07381c7eb41c713bbe146714d62409180c391cfcd482d8515e4bad238da545924f2d0901df192067ae3be29ec76de1d87c60b6773ad4d2e842e3636a105a9123459e5d62620838ec4d2348fd43ae0f35c963cf2a0f15b611695a1976b45d76d009a4303b49006211986d246782464e0fe74079e81caaaff5cd5e02ec21c718fbd0d185490b10381c66a4dbd0877e46698f29570791d4f6ab229c07209e3b63bd068b772d9c97b1c529b789c23ca10ec5639c293d0138381f15c8a58c0041e7be2ad64bec25a6db4682c2f2de04b832d8c5766485a34f30b7f098f47182391f3c734a9a40253918af2be00249c1ed5c711b2e40e69d1f91f15c56fc972bb2b8218820e411c1156ed666690b6e6ce493c9f9a16263b8eec7db144a4b9639c0f8a36c19cdad20854523900e69e6bfe0bd5f44f0f68faf5e1b7369abc664804720661800fa876e083c67d8e0f148a4f3209764d1b23e01dac30464647f4353fa99244489e4628808452c485c9c9c0edcf34b6dada33629c94982a0ce7df1cd71a3558f71c81573b28231c73cd41e42e385c014163258dcd2a028addb76e00907a735e912447d87057e7fb5328405f56302a170f1a36e2327d8d679d764743161518d8020f2df2a9ce78e738a292e72d861b57ad2ff00aa4dfc0ef4660490f18c6339a4a612904457281f038e718a63ba361dbed59e3fc2954961f951e8e71e6e79228d32b9362d691ba96c0ce4e2b935c6f4db8231deabb99e2924630c3e4a60613716e7032727dce4fe754eef47fde97c8cfe419f2d2648c8cf7a65ad5f45ab6a06f60d36d74e4d8aa20b552a99000271ee7ad2f600f5a879fe5d0147bcbdbcd308e50f1a8e320d2b12e49cf435e1332fe13513a20ede0bcfa2178d0482d8bf96b211e9661ce28d95638618365d47397895cec046c63fca723a8f8e29436a4f34504207951c6a328ac4ab3777209fc47e2a5e7649fb512617d4304c154861d0f5aa59d9b277601a86cb87b496e96176822203b81c293d334234a593f162aec353a459e6b24a42351306b3a85ad85cd841792c76b75813c4ae42c9839191de94997d79efef55b3107ad572a14e4308a7769463a51bbdf72924ae3b8349e176dcaa80963c0039cd16b39fe66cd3a13d0126d1b2f0df8ab5ad1b575bab0d5a6b666468dd8be4118cf3bb23a807ef486e351bdb9795aeaf279bcc62ce5a427713c927f3a5a27c1c64d44dc8e723a55b920212f05c19b9c6319e3de8b8768418ed4ac5c3331a2566c2e334b4c6da41170c046db145474ed721d3f4ad574f9b45b1bd9350448d2e674264b4dad9cc67b13d0ff828669813c9a164018ee1d6adef62de9ec9ba33b60ae6a32c200c31a9aca1067354cb36e524553a16d4932b0141c93c54d41793278143a0c919356872a4e3b50a639772e96352be9e08aa963383bbad784c72771eb444a8896f6f225cc7219412517ac7cf7aa6d30f4086104e79a8edd99047268856daa40e73dea279ea3b55502f40848e95d5524838e2a6ca031cd5881702a25b21d48f3ce7f2a98077924f1d38aa5a42878a261865b8b6b8b8468d560019c3c8149c9c700f5a3b48ad9e408ae739ab630abce3a9f7aa1581739c62a65c819c74a38b4834e8b999979cd56643bc366a3e612b8245472bd3bd31cec9cafb9635db8ea3f3150376ccd80d8a8c806dc0a10ee19a54a6d13ee0a33b138cf15133e7ad509926b8dc1f9a57260d86accbc2a8cd75d41231de858c64ee345a37186e68b95f70d6c92318411838aec7be57dc4f1dabbe935e59020c0e2ad16dd68296511ae0e7e68857523a52d6901fbd4d67c0ebcd339b295d17de14200ce0e79342fa40c28ce6bad216241e4556ce172568796c272431fdf3aadbf87ee34283509134cb995669adc1c2bb8e84ff004fbe07b0aa747bc1a75c34e6d2daeb7c6f16cb98fcc51b863701ee33907b1a00cbb89e98aeaccab8f8a9abb15632320e3b7b51115f08ecae6d96de07f3f6ff001644cbc7b4e7d27b67bd283366a22661f9d3fd40a4db0f597af357c733472a488d8642083f23a1a58b262a6260075351e425a353aff88f54f136a8352d5ee166b811ac4195026157a703f3fd695f9bed4b84e76e09ae0b8c502c9a33fa6dbb6341280003d6ba1c0390695fd47cd745c1c7340e66a85a8e86be7ed1d7340de4ccebb40ebec6a9f3f1d4d52f2069339a06c6f36d6cad502b03bb00f6a716cf1ac58039",
            "c52a0c84f4ab5660063381429d151745938dd29c1efef4d3487d2ccb38d626b98e310b18be9d4313263d20e7b52812aee26b85f8ebcd4b2afe05be69ce735ef34e319a1b71ae64d2ac4d84b4a4ae335513ef55ee35ecd4b2596abe1719aeb2811a92ea77760791f7aa735ec9a9655972300739ab7cec509935ec9a965d867d5cab1344b2b88dc82c80f0d8e991deaa320e95464d72a592cb8b8ae16cf26aaaee6a5956156b79359ddc7756edb258ce54e335d92ee49e532cac0b9ea40033fa5075d0483c544ca0a3211d7ad437fe9553c8f236e739351c9abe45506c21a424263819eb5cf3be683dc474af6e353916146535c3213de86dc6bbb8d5f22504799ef512fed546eae97620027a702ab91289efc1aeefc9aac918181cf7ae66a59113cf35d048355e6bdb8d55845e1ff5aef9a687dc6bd9abb28b5981ae6ee9daabcd7b3539144cb6e35ccd42bd5565972be2ac326475a1b35ecd1291023ccab1d1e224b63f239a0f71aeee35391021a4c8aa8927ad57b8d7b26aac8481c1e2ba033b6d5193f150cd7b2455590b5491cf61560931dea912bac6501f49eb50dd5765a7417e6fcd70c9f3436e35eddc7cd4e446c23cc39eb5df379a1771aeee357c89615e71f7a8f9b9a1b26bd9353914cb4b73c57b22aacd7b26ab910b8486a5e650f935ec9abe4504893e6b8643bb39a1f26bd9353910284b5e32e685c9af16e78aae45a08f37e6a626e0509935edc6a722ec2ccdf35032e5b1546e35ccd5592c244a41ce6a465ef9a1771ae990939352cbb0a131f7af19cfbd09b8d7b71a964b3fffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080100010003012200021101031101ffc4001b00000203010101000000000000000000000003010204050608ffc40035100002020202010401030303030403010001020311000412213105132241511461712332814291f00615b172a1d1f1435262e1ffc4001801010101010100000000000000000000000001020304ffc4001f1101010002030101010101000000000000000102110321311241220461ffda000c03010002110311003f00f96f0c32f3c2daf3c90b942d1b14251c3a920d74ca4823f704839e84530c30c030c6ec4f3ee6c4bb1b12c934f2b992492462ccec4d9624f6493f78ac030c32d12092444691635620176ba51f93409afe01c0ae19afd5b4a1f4ef53dad3d6de837e1864644da803049803fdc39006bfe77e7326018dd858164035a49644e08499230843951c85027a0d601bec00685d056180618618061861806324d79a1489e48a4449979c6cca40917915b5fc8b56163ec11f58bc300c6340cb024e4c7c1dd90012296b5009b5bb03e4289147baba35ab566d9dd9f56395e3da8b4a2731c1b7b1c221129695a304b2d024b9e2a41667217e4c2f24d334ee1dc2021553e08105280074001743b3e49b26c9270298dd88921902c7b116c0288dce30c0025412bf200da9254f5560d12289561806186180618c5d799a07d858a430c6ea8f2053c559812a09f0090ad43ef89fc652b0231badabb1b9218f5a0967754790ac685884452ccd43e9554b13f4013f58bac2b0230c7c3a5b1b11cf24304b226ba09666442444859503311e072655b3f6c0792313c4e34230c30c031926c4b324492cb23a42a5235662446bc8b52fe05b31a1f649fbc95dad84d69355679575e57591e10e783ba860ac4782407700fd723f938ac09c90b792a3b18f85a4d5732c6226251d08923570032952698100d1347c8344104039a90521d779a58e25e01a460a0bb85504fe589000fdc9ac5152a688cd602aa024a8cb6d6bc69b4d047b10ce82431a4c96a928ba0c3985214f9f9006bc819bb82e99663134ce6047488b1e0aec19956fa04802cd7dd0fe0611fb6ae7de4775e2c00460a7951a3747a06891f63ab1e719ea1a32fa6ef4fa73344d240e636313875247e08e8e23eaf3088c66c40dad3c90398cbc4e518c6eaea4835d3292187ee0907eb179d2d6dfd1d1837a01a10ef9dad648e39f65591f564b566640af47b0ca09f228d0b2b9073718a60fd3bab47219cba9470e02aad372056ac9278d1b1547a362978607527f56ff00bac3a3a9ea062820f4fd592185f57523e6e7e6ea1e8af2b7600b1248049018f4dcbc6ac48759e533c6aeaeaa2121b9b8218961d71a1401b20fc8503dd544f2ac2f0091c44ecaed1863c598020123ec80cd47f73f9c0a6186180669dadc1b11c7126b6b6bc71d10224ed9b822b31636c6f872a27882cdc4283599b376e1f4b6f4fd13a6bb69bc03aedac9c4c6dd828c8c0dd9b60548eb88ecd9a0c38619a5749967f6769c691f64cc0ce8e390f6f9a000293f31c429aaf90248164066c62c8a35de33046ccceac2625b92001ad477546c13609f88a23bb04ccb0bc20271765724a02d601029aac0f91b00d1eaee852f00c6ed429afb33431ec45b291bb22cf1060928068328601a8f91601efb03c62b34f3d6826b8d7f53198aaa7429c5d9289015bfd2c49537df104af65703365928f47acb4904b1246f244e8b2af38d99480eb656c7e45a917f907f1950c2bb1dfe72c1b1123d49ff00b35f714c4477cc2ab3279ff49e484ffe9e4bfea5f28f6f1cdec45110bb025947b657821e041525812d44329e2b41483f220d01c97112e4b7fed79d269a8a18efc7d605788cd05788b3e7334879551c6534581f5a75d74da68245824768d252a78332852ca0f824075247d721f9195d8d79b527935f6229219a2731c91c8a559181a2083d820f55956195ce559180c30c81b1ff0070159bb4e6935278b622589a489d64512c4b22120d8e48c0ab0ebb04107c107314b1b6b4b242c50b2315251c3ad8eba604823f706b2033b0ebf9f39d71cb4b2b4e9c2ed3342043c846f21f72558c52a963db1009a0687963400248072b373b27ce479364e199b97e26d69e16d79a485ca168d8a128e1d4906ba652411fb8241c988c212512c723394a88ab8508dc876c28f21c790a047641bea8d30cc88ac2b270c08ac2b1bad2a41b114b2411ec2238668642c12400f6adc486a3e0d107f0462f022b2d146249511a458959802ef74a3f2681343f604e466bf4897d3e1f54d593d575e7d9d05954ec4304823774bec0620d1ff9d79c0bff00d41a5a7e9deb9bfa9e9db91eee9433ba41b11b1659101f89b2ab7d7df117f5d6646d69d75d365a1904123b4692953c5994296507c12032923eb90fc8c894c6647312b2c658f1566e440fa04d0b3fbd0c98da10928963919cad4455c2856e43b614790e3c850aec837d5105d6158c9a09b59c24f1491395570aea5495650ca7bfa20820fd820e53022b0ac9acd1119b6a14d35fd32ac4659c3308e363f005817345ba41c5493d92145b1b0cd58566a32cbb9ae17637cf1d3878ebc5333b7c4c96638e81",
            "0bdc8ef4788fee37c88073603619e61136a7bd28d795d6478958f16650c158af82407600fd723f939b25feafca595e521550331b20001540fe0003f60062f535184b0b334644b199102c8ac40e457e401b5360f468d51aa20e7421489cc858c50855662ce0f640240140f648007d591743bcf4f0e1bc775bc674c1ea5a0b1ecbbea215d590b490a34cb2ba27220072a07c857daadf46802332a2d8ae03beaff7cecc62268a940097c7bcca1e1d7b553ce5babaf19acb864ef6b706230108ac7e449e80c96dc765851963510a18d7846aa48e45be440058db1edacd002e80036b7a8eafb84c704b1af0414f2090f2e2035100745ac815d02012c459e7b2ab30a23e5f8face59493571acdff00887d8775e26bf9c5d9aafac08a2479cd51ea6c3fa5cfb4ba25f5d25456daa6fe9921a93cd7cbc9b04fc451166f95b6facb213969cc4d3c8dae8f1c25898d2470ecab7d02c0004d7dd0bfc0ca1c3320c30c302466b8f80d292513c41d1d5042cadcdc10d6c0d71a1401b20fc8503d909481df5de7063e08ca8419143590c452dd91f13640a1d5d58b96da9a45892595e44850c71abb122352c5a947d0e4cc687d927ef378dd1159b5e6d69024f1491395570aea5495650ca7bfa2a4107ec1072b903ce4e6431b61db5a3d72b1708dda40446a1c960a0db57223e2281343ba0391b894c4581891d178a821d831e54391ba1d13640fa1d59f259aa444b26c3c1afb08018b84b210433a3056015831e2472bed6c286041a28ca0c30c31a06197262f654047128662cc58712b428015d107959b3763a15db7592368f63dc92647f6ff00a4a9186123f2504312c388e258d80c6c015d922c821678a5da967db899c48246e3015840720f1200520286209500580402b60846335f5df6a431c6d12908f213248b18a552c7b6205d0343c9340024818bc80cd1bf1e9c7328d19e69a2f6d0969630843951c85027a06f33e18d030c325519cd2a93fc65d08c3020a9a22beb2f0c4d3cd1c2850348c1417708a0935db12001fb93432684c103ec39443182119ffa922a0a552c7b6205d0343c9340592062f2f344d04cf13942d1b15251c3a920d74c09047ee0d1c63b41fa68195dbf501d83a7b60285017890d76493cac50aa1d9ba1641d2ff00a7bd4373d0f79b6b563d5777864d77fd4c292285752a480c08ba268fd663d9d8f6e4a8647f6c1ec5f5fe322175895bddf896f0a47fceb35e90f4b97775d7d4a4935758cca259208c3baa5f642dd1fe3ff3e33d13531e9bfc2e009ec348b2736bb2bf8cc3337f579a7200f60b66ad5df4d33b7144a258b617dbb9117900183022ef835a8ed4dd58ba241cc89b1bfb116bc31bcd348c238e28d4b3331340281d924fd6633ce5c625bd21b6f61f5a3d579e56d78a4695212e4a23b050cc0780484404fdf11f8195990ad12281ec6532e93706b78d665e2ca15c9a160807a23b1763eac0b04759cb7d32355b5d36a16db8a597583a99638a411bba5f6158ab05245d12a6bf07c6503b08ca0660a48256fa245d1ffdcffbe40166b352eca3cba8bb710935f5e919600913ba732c417e26dbe440660c40a1d850320c87ce466bf54564dc652aea8153da326bac0cf1711c18a2f40b2716bb377766ece4cc830c3344734bb10a69cbba63d688cb346923318d5ca8ba500d33f045bafa5b200b00818618651d0f50f4fdcf4556d1f52f4b3adb3288b611e657591632a48005f1e2c1949b04da0a23e40abd49b7a4dd967f533b2db7b046cc926cf2324bee00e2425bb3c8306bfbe57f78b8e2daf509b8c6936ccab19621417611c6964ffe954527f002fe0659e15d3db9a0d902431178cfb132b2f30080438e4acbca8f5d30f045de02319b1ad3ea4823d886485ca24816452a4ab28656a3f454820fd820e2f0cb0336624836258a39e3d84472ab3461824801e987201a8f91601fc818bcbc73cd0a4a91cb2224cbc24556203af20d47f22d54d1fb00fd65328334cbbf24f324acb1215448c88a258c15550a3a5005d0167c9364924938ad8681b6256d68e48a02e4c692387655be81600026bc9005fe078c59367c565975e0d71eb472991838e2a7e8f75599e542addd03e6865a0505be5e3f3584d28918908abf5d0cddd5c57f159e35866923595265462a244042b807c8b00d1fdc03fb669fd0810a4a654a601a8fd9fc6275a2576e5203edaf9a3de50bd35066e20f5de4c7526ec27fd6a78b5560694cd1fbaacabec056b360d906aa81001ec1f90a07ba9d08d59e8c84122eaba3988b126fb26eece757feee91e947ae8d348927192788fc1048a5829144f2a5634c40239b0afb3bc32c7eb75659b55fd3c340cf195366ec9ff9599a3d45594a4f228016cd7d7f19692757e2e0f142f7c01bff00cf59adbd35f6e01b26787e2ca8b100dc9d48625875542803641f90a04591d2e332bfcc6b52f9185b5918a942a13c124f67f7cb6b687bc096e718ef8923ce7663d58d1f981f2ae24fe7336f13142f541aa8023aff0019d2ff009e63fd64d5c35dd61d57d70af1bb78ed5cf47c663614065c49fd50dc0023c003ef34ebfa7b6e6cc6b2cd1eb4524810cf202523efb66e20b50f3d027f00e79aef29a8e7eb2eaac0fb312ed492c5ae5d44b245187744becaa92a1881e0122ff23ce4471348b232940235e4dc9c2922c0e813f2364742cd59f009c895555a95b90af359054850c4747a19cac6569a79761c3cd2bcac155033b1242a80aa3bfa000007d000668dc468a5934f69e0126906810eb089d24612126e4434e3e4d4f6f6028078d564009f19217e3c8ff0324151d1cb",
            "17b07ac86249efebac7c5ed6b4bad330d7dc5ea4781b985e988e0e4713d817f16f0c3b06e832e18d82548242d26bc5b00a3a7090b000952037c4836a4861dd581608b055990618c896031cc6592447080c41103076e43a636388e3c8d807b005776178138c8a7789254511912a706e51ab103906f8922d4da8ec51ab1e0904d668576226d98e49200e0c891b84665bec0620806bec835f8394048f19434b6b9d68d562946c0762f21901464a5e202f1b0410f6791bb1d0a25a018bd875647331652ae1c050b47902b56493c68d8aa3d1be9632700cbc222672267745e2c41440c7951e22891d13409fa049a3546986580c30cdfe9dea3ada5a9ea304fe97abbb26dc0228a6999c36ab7356e69c4804d023bbf3fc83460c31914a91c732b411ca6440aace5ae23c81e4b440ba057e56298f574412eb4d024324b0c91a4e9ee44cca40917915e4a7ec7256163ed48fac0aab95228f8f195fbc66c4a93ec4b2c7047ae8ee59628cb158c13fda39126878ec93f927179469922dad482169a19228b650cb0b3a10255e450b293e472465b1d5a91e41ccd55e465f61a169e46d7492384b131a48e1d956fa0580009afba17f818ed25706798688dc8a185cc8183f18837c1642548238b3a9166b971041068866cd50c11a3c667b54617caac7f199737492cbb1492d71451fda814715000e8559fdfc9364f649cde13b5896d4679d0d0119a368bcac7ec3effdc67a0935e08b91d491e4d5f71e389a50ab2328aed901245823bf07bfc10389abb1347cbe04a28e36077ff3ce750480c5cc78abefacf7706337f51db093d5c9e209fc673cee7a7b7bc772195e609c222920508dc85961c4f21c790ab1d906fa20ec13abc41d7e562e877987d4b562764959c464f456bfbb37cdbb8ef16b3f3a73cec471cdee40b4b63e2c2ef05d99873e0401fdc07e3f8ff7cbec429aefc158300bdb578ca6ced34f18f343ff00359e0bb9bdd70f09be36dc8f3bff0004635b51d443248f1f19e33282b22b900332fc8036a6d4f4d46a8d5104a02d8b1f58f339dc9b9ef6cec3718b82bd7b8df04e31a764528e2abe7e2be01a00f2db2521882c81d5d98ad4655a82b58ec8aec558aebb20df5469e2c1bcd5a9b916bc1b51c9a70ec3cf18449242c0c07903c9688ee811dfe7fdd71c6b2ad0feeab2df8c926fc213742af05f0464c89c1aac1cbfb8abaaf118232eeeae2625b9a0018151df1a3609b04fc4511dd8248ac8c6aaeb9d5919a5946c87409188c1464a6e44b72b041094389bb3d8a0195980618633635e6d4d8975b6619219e1731c9148a559181a2a41ec107aac0b6b340ae4ecc72c89c1c011c810872a789b20f41a8915d80458bb0ac6426157267491d38b0011c29e5c4f13641e835123ec022c5d85e50ed45d77da8576e5962d72ea259228c48e897d9552ca1881740b0bfc8f38bc819380618635b65db563d62b1708dda40444a1c960a0dbd7223e2281240b2401c8dd82da05bf59122ee2e9094fb4fb0c5c2c68e38b16e00b15e24d800922c51f188c30ca0c30cd327a84d27a743a0561114323caac2250e4b000db5591f11d7ffe6051d62d8d88d3551a20c112a6954fce8063ca94052d645ff6820126acb7d5fd2e7f45f54daf4dd9781e6d595a2768255910906ba65344664c32830c31f38d31adadec36c36c10c760b80a8a7952aa5124f4012c6bb6ae3f1e4c0950598000924fd676f40732c648c02a38f13df59c685fdb7babfacea6a06e6525968a9f8853e7fdb3d1fe7eab7c7ebab17b5ee2fbaace960baa37162bf8068d1fde8e4ccb0bc2b1c51ba3142242cc086624f6050a1440aefb04df7439f14b1cf2911c8c1faba3f5ff00063b66491639381e3c4572afbcf7cce59b77dfea75f5a38634e7b4b11412961221e01550320565b25dd832d15001e24b5125791ea3b0769d4f4a147f69f379b26d7986a96919a4342b893d623434ff005c9349fd20d0af270f285241655e8120b1b61d0b3566a8123c9c9bbfc4fd72cb7e302f5d95bee8839aa3846c43c8b04551e09abcd9b3afaf172768d8903a43e3f9cc32fb0210196412f9ab1d79ebff0019caf1fc7559f9d7accb61abbbf1d6050fd106f239b75f23d7ef92b210e1fec1ce1d30808cd742eb1b6d1fff008f89fb3f9cab4b5213d11f81d038c2b2a40bb45a2f6e5768c28954b82a149b5be407c851228d1009e26acd452dbfa87f15f6714c0a920fd63254e0f51cab282aadc92e8120123b03b04d1fab1d1228e6bd34f4b93477cef4db71ee2a2b6a7b4aad1bb5d32b8344746c107aa3d1b199a8e761861980648c8cd7eab3e86c6f3c9e99a72e96a714090cb3fbce294024bf15b2482dd2802e80eb02b268cf140f34aab184318e0ee15c8752cac109e454a8be40102d6cfc96d146af2fb31241b12c51cf1ec2239559a20c12400d065e40351f22c03f903377a3ce38ed7a7a7a445ea5b5be8bafad61cc90c85d4831aa9ed8d71a20f9fe41a39c3342efecc7be3d42194ebed2cbefa49ae044637bb0502d04a3e38d57d565136b6135a4d459e55d695d657843908eea182b15f0480ee01fae47f27178061866fd4d0dcf55d3da997622317a6ebf32b3ec2a90864ae31ab1efe4e4d0fc9fb3dd8306186194196313085652538b31500382d600bb5bb03b1448a3dd7834d936136239e4d8fd44dbb2ca24f7da5b047cb9f20412cc49521b90aa6b07902a8cb06bf4c8f425d865f52d89f5e1114855a18848c640a780a24745a813ff00d8c98618064aa96ba1742ce464a1018122c0eeb10688b48ca5aa44a500b1bf00e680badfab93da92",
            "2820feabc5fa82ce40504aa12abdb35050680b209e22c899b6224d665476e52f6001407ed9cd02cd139db3d63ad35753c743d3f78473334a50023b623bfe066cd8dd596255080895792538245123b00da9b1e0d1aa3e08be2380ac403601f38cd7611bf322e878cb8f36527caccef8ebbed1f6d632699851602c0ce6176d29c80dcca9ff00179d0f4a5924dd49a18976a684fbe23310947141c892a410ca002486045037d6266f4e1c79c8fc4dd28166ff0003f9ce99fd67373f1abbbdade933e949bb23faa6dcf0c5ecc851a28bdd6f73892828b0eb950bbffe7396cc5d8b31b24d939ae5d5863647e6ded9f3d663357d5819e6cfea755ceeff004cda953636659a3d78b592476658622c52204d8552c4b50f02c93f92717865e699a770ee1010aa9f0408294003a000ba1d9f24d9364939cd14c94731c8aea14952080ca187f907a3fc1c8c83e720ddb3ea03d5fd664ddf5061aebb53f39db5605f8027e452305412078162fecfde622791ece5727eb28822b23193ac2ae0412492270524ba053cb88e42813d06b00df600342e86b87d3b5a5f45d9f506f53d58f6219e38934583fbb32b0625d481c6978806cfdff1791830c645aef34733a98c08503b07915491c82fc4136c6d874b66acd50242f0270c30ca2464e40c6ed429afb33431ec45b291bb22cf1060928068328601a8f91601efb0302fbb4931d749a0d88f5cb4493431955954313cbb556377d1601aa8755429b1af369ec4badb30c904f0b98e48a452ac8c0d1520f6083d51c8304ab0a4e62710bb322c854f166500900fd90196c7ee3f393afb53ea4864d69e585d91e32d1b15251d4ab2d8fa2ac411f6091f79605e187559b816f487f51d0dff004b1faba3aecbb2ae926a48ae397c6c530e254823aff7068c386186580c30cbc82209198ddd98adc819000ad67a06cd8aa37d7648aeac8532c840249048aef2a3b39b23892573c02f003c5f67ff0019ac71df8b26ca120894232ab0bbb158b0a1e52116c13d0fc63f6381d74577a9a3a4445855415258b176144b024558360f901402bd3d997527f7611196e0e9f38d5c532953d3022e89a3e41a208201c5bdea88f6cc52156e375e2c657dde96bfb87935848bf327cdd9bca62dd788e9c5eacc9a91ebb3168a32d22a12485734091f42c2add7e07e32763653d4975a2d4578668e091f61a7d8454765e4c78dd57c40016c92680b245f2f1bb0f14b2c92471a4219c911c7c8aa827c02c49a1e3b24fe4e5bc9959adafd55e7dd695e42914702339758d39111ff00fc82c49a1fb927f7c67a5eaed7aa6d43e95ad3a47fab9907196611c45fb0acc49aeb9377fb9af398f0ce76dbea264431c8c8c54952412ac187f823a3fc8c8cb99e668135da590c28cceb1963c559800c40f0090ab67ef88fc652b20320e3575ddb5a4d90d1708dd6320c8a1c960c4525f223e26c8142c0247217454e567f18169761e78e08dc440428635291aa923916f91001636c7b6b3542e800163f7c09fac634c8dab1c235e25747673382dcdc10a02917c6978922803f3364f540a3e72fb0b0aec4abad2492401c88de4408ccb7d12a0900d7d59afc9c879a595634924775897846198908b64d0fc0b24ff24e599a03ad1aac728d80ec5e432028c94bc405ab0410d66cdd8e851272235e07dad88a08cc6af2b8453248b1a824d76cc4051fb9200fbc5e3359a04d989b6a3965d70ea6548a408ee97d8562182923c120d7e0f8c5e04e1861943b5353637f6e1d4d4825d8d99e458a286242cf23b1a0aaa3b249200031641534456403d57d6324915d630224428bc4b2936e6c9b364f7440ea8501d5d934532f2344563f6d1d582d4859c10cd67b02850aa15df609bee8532f0cd2eb4d1cf048f14b1b0747462ac8c0d8208f041c414c30c32831ba9acfbbb50eac4d12c933ac6a6595624049a1c9d88551df658803c92062b0c030c32f046b2cd1c6f2a42acc14c8e095404f93409a1fb027f6ca1d1c7a24c7ee6c6ca830bb49c6053c651cb828f98b53496dd15e4d4adc4724a17ff4df595aeeafafce763d275008ccaebd37f6e74e2e3b9e5a8b8e3bba67f52d778135e6935a68d7610cb13caa40953932f2527c80cacb63ed48facc9fa82e6112050b12f11c11549164f6401c8d93d9b3543c000770ac32ecb1316bce023ab2485ba2ca406f891dad861dd581608b078fbb1a444a0400df91e33a72f1d97e9acb1d7644a54b929617f04de3f5b7bf4bfa6921d5d6f7f5a733fbb247eefb9fdbc51d1ee3650549a2bdf360dc8501970ce17b606185f5d8fe30ccd1a7d33522dff51d7d59f721d28a59023ec4c0948813fdc6813588914248caaeb200480eb74dfb8b00ff00b8cae1c4d5d1c0d489a907b4f3bfea965824631c0e636864f9aa062c841a215c85b054d7256278a60103c87f5324b1a70721a38c392fc4f11448e8b5026fa049a3545786406593a04d815fef95c978dd02b3232871c94915c859163f3d823fc6251d3d9f5b6daf43d2f49fd1e9450e9bc9209228aa695dcf65dcd93402a8028528eafbce709dd75e4d7023e0eeae498d4b82a180a6ae407c8d8068f577429597022f65c977128650aa14712b46c937d1078d0a3767b15db622791659a491224855d8b08d092a809f03912687ee49fdf299abd324d28bd475a4f52826d8d259019a285c23ba5f60120d1ff9d79c77aa4fe912c1a43d2f4f6f5a548986d34fb0251249cd882b4ab438951fe3fc9c8e7e18618138d9a148e3819762294c885991035c47930e2d600ba01be248a61ddd80ac32891939031d0ed6c6bc73c50cf2c5",
            "1ec208a6547204a819582b01e472556a3f6a0fd0c056375a149e42926c45ae023b87903104aa9217e209b62028eaac8b20590ac32c061865e1865d99a38208de596460891a2966762680007924fd6514c32f24f2ca91a492bbac4bc235662422d96a1f816c4d7e49fce5300c32e2095a179c44e61465469029e2acc09009f0090ad43f63f8c99e5499c32411c0022af18cb1048500b7c8936482c7eac9a00500d835e29a6938c11bc8e159caa2f2215412c6bf000249fa02f3ada5be258195fe3c0767f6ce2e592468fb5347f233af172dc2b58e5a75cc91482330461bddb344d51fbca6e38d786710ee345ee848a5d705834c84f2ee851556442431f3c4806891cfd668a312c8f2cb1ca880c21230c1df90043124711c791b00f600aeec2de4791b93b3337e49cd65cdf58eb4b72dc0c16978937f7795cd275246d43b422710ab2ab3853c558dd0bfc9e2c40fba3f8399d459ce5630ba2c26162d24825e6a154202a568d926ec1078d0a3767b15db75748ed39556a2059b184faab085a93958bfc5669f4ed8749442517ecdf8bce98613eb59b5277aad1a3aded1647856ff00b49f3941a892a961cb8c77c47dd7ed8c2e904bc81bf708007ffa7ff389db86756ea56afcfd0ff9ff00ce7aac931d6bc74ea473f60a194f15e23efbbef291b98e45750a4a9040650c3fc83d1ff38d8347676e668b5619365d55e422242c422a9676ebe9555989fa009f0319ad1a44af2c914737c1d7849c8004a901be2476090c3eac0b04583e1b2e55cbd47a9ef4beabbf3efce9124bb12348e228d510127e947406576fd4f777e1d5836b6a69a2d48fda811d8911259343f1d9399c9b24f8c83984466d7e9a1d8f522fb4936b37b623da52ebc55a38f974c542b22fc0804a015c432b662c6ebc4933957d88a0011db9c81882429217e209b62028eaac8b20591034e926bb6bfeb6578048e3dc8c44c658e22a8cb2056e2ac195ed472eebba0413930c3203193eccdb4e24d89a499c22c61a462c42aa8555b3f4140007d00062f0c076d2eba6d4cba92cb2eb07611492c623774be8b28660a48ab018d7e4f9c56320952272cf0c73028cbc5cb000952037c483609b1f5605822c15e51231abb332ebbeb2cd208247591e20c78b32860ac4782406600fd723f938a19380d65d71ab1b2cb29d92ee248cc6022a52f121b9592497b1c45715ecf22155d57ef861960908e50c8158a290a5aba04dd0bff07fdb2fb1b0fb3207711821113fa71aa0a550a3a5005d0167c9364924939b7df9e0f4110c7eaa0c3b33f297414b020a0f8bb755fea3f7f5fb75ceca19b3ad3e9ec4badb30c904f0b98e48a452ae8c0d1520f6083d10717865e11134c82677488b00ec8a19956fb20122cfed63f91814cbcdaf36b3849e292272aae15d4a92aca194f7f441041fb041c23584a4a657915c2dc61503066e43a636388e3c8d8bec015dd8a60316645d69213af133bbab89c96e680060540be34dc813609f80a23bb9db69a4d99259e358e494fba556211afcbe4085000008360000555758acddeafeb1b3eb52ebec6e6c6dececc702c0f2ec4dee585b0a17a1c542711449ec137dd00c387e70c3026c8041fc64648aa3777f59611d8621810b5975b1b34f5cce22e71b150dd15af1fbfed9d6f6b5e3d959e4884878320524802c100f441b1763eac7763ace326dfe9a28975a69199d0fba1d0008dc8d05366c71e26c81d922bab33b33ed2c49af2320019a4078286360020bf923e2281343ba0391bf4e1cb8e38f9b7499491bff00ede006a04afd8bedbef366cfa66f1f4aff00b8a6b6c26a194c027688fb464a04a72aae5441af346f39be9bb27822f3b174d67a18ef539a17d7a5925f715d4f144054af764b72e883c6851be47b1547bfd63f1f51bdcd6e314d18113848813f6e059bfbfe331899c2917e45127f19afd2b563f51f56d6d3d9f5187d3e19e458e4da9b918e2527fb88504d7fceb31ca82391d16459155880eb74c3f22c035fc819e1cf3df8e36ab97d85856402092491382925d0290dc4721409e835806fb001a174299073922334ec185f53599175a3910346eb1fb9cde8f2123f2b5ec3f11c6ba8fb504f26cd860466cdf71afb1bba716ac9ab09d82443b215e787896011a4e0a6c0621a82862012bd0ac78640dd5d59f77662d5d5825d8d899d638a2894b3c8e4d05503b24920003158631635303c8668c32b2a88883c98106d875542803641f90a07ba0d1e9b1e84b3b2fa8ec4f0422272ad0c61d8b853c45123a2685fff00632618ddbdbd8dfda9b6f6e79763667769659a572ef23b1b2ccc7b24924927ce5129acedad26c868b846eb1906550e4b062292f911f136402058048e42d79031eafb3b112eaa34d2451979562049553c473603ebe282cfe145f8c0a6bc8b0cf1c8f0c73a230668a42c16400ff69e241a3e3a20fe08ca648aeec7f1919418d9975d6380c32caeec84ccaf18508fc9a8290c790e3c4d90bd922ba04c3343fa74558e4138762ee5c152b4bc405ab041e566cdd8e851b5e360c30c31b179245748d5624428bc59949b90d9366c9ee881d50a03abb2698618d830c30c6c18618c9e07d6708e6324a2bff4e45714ca1876a48ba22c7906c1a208c6c114a91a4aad047219138ab316b88f20792d102e811dd8a63d5d11a80dfd413fa748fb1047ee879f5998a8f723e4a0b21ff52f271d8b1c987d9c53eac29bb3eb0dfd678a23270d95593db9b88254a829cfe7402f251fdc3971ee970cc22048be7e01bf03358eb7d91d4f4b99b5a4326acb247318de2e513156e2ea55858fa2ac411f60",
            "918a9f5a2d4d799a4459d9c08d59f95c26c37214477d11dd8a63d5d11822d892224a9f39b366113c72ccfb1af0948c3ac6437290960382d02010096f91514a7bba07bfde370f3c6f72c64d89229a59658a28f5c339658e32dc5413fda391268781649fc939114ec9f923ec5f9c5619c3eb5e31b31c175f70ba93e2bec62f2cae5681008bba38d32c5ed80230495aec9f89fdb1d55200bcb242d22b30a01459cb4b33cd3bce422bbb1621102ad9f34a00007ec050c6c3b71c6583c6ce8508a560a7951a3747aba247d81563ce3193f526889762699228e596491214f6e25662446bc8b7151f439331a1f649fbc36207d6708e6324a2bff4e45714ca1876a48ba22c7906c1a208cb6bebc9b72b468d12b04790992458c52a963db102e81a1e58d00092014e605d5a1fd3bab47219cba9470e02aad372056ac9278d1b1547a36297979a56d89a499c206918b1088114126fa500003f602863a3f4ddc97425f504d695b4e191629270a78233024027fc1ff8720cd8618605aec64618651233b3ac3d6ffe94f5223dfd9f44da93518f26e68cf149193c7a04fcc1a1f40916451238b97795e560d23b39002db1be80a03fc0006033575a7ddda87575a09362799c471431296791c9a0aa0764924000646bcab0cf14af0c73a230668a42c16400ff0069e241a3e3a20fe08c8966591215582388c6855990b5ca7913c9ac917442fc68528eaec9ac4017018f59607ea18a174d99175e7114a84eacdcc0997b2412b54bd006995be42bec8cf46afeb348d70be689bfaccf29b90d78f19ab8ea76b66918647785e6117263f65404712862598b0e25685002ba23e566cdd8e85775c8bc2f0272f0c6b2b9579a3840566e4e1882429217a04d92287d591640b217785e04e0013e3bc826c93921a8550efef28bcd04baee12689e362aae15d483c58020f7f441047e41ca65e39de34954042255e0c5903102c1e8916a6c0ec51ab1e09057781656e26f1b37068d595896249367bc4a8e5f607f38e49db4e58a6d59648a78d83ac884ab23036083e410479cd4bd552e689a099e27285918a928e1d4907e981208fdc1acae45e179846adfda8b7265921d48751446885222c4121402dd93d922f33578fdf232c8012791a032c168fb057ecf8a1946055a8f9197866311ba07fc63416da12c516a096563eef350c5d15558b0001ae35f224824701440bbd5d68fc6763672b8c826681cba08c92ac94e8ae2994a9e8822e8f47c83445100e2f322d3ccdb13c933840d2317223408a0937d2a8000fd800064091c218c33046218adf448ba35fe4ffb9cae19906186180ed8da9f6dc49b13cb33aa2461a462c42228555b3f4154003e8003eb224311588468eac16a42ce0866b3d81428550aefb04df74178650c84c4b3466747788302ea8e15996fb009068d7dd1fe0e4eac493ecc50c9b116b248eaad34a18a4609a2cdc416a1e4d027f00e2b0c06aedec26ac9a8b3cabad2ba4af0873c1dd430562be0901dc03f5c9bf2729c8922feb2b978444d32099dd222c03b2286655bec8048b3fb58fe4605965366d88b1f58bc8c7fbdac34442358fea4cbc9a7321e92a822af81d92493774b5c68f2bbd86fa5e943bfb0d0ec6febe8a2c5248249c3152caa485f8826c9143f9ff198f0c32030c31abb0ebad26b0117091d6424c6a5c150c053d7203e46c0347a241e2281586376a64d8da9a68f5e2d6491d9d6088b1488136154b12d43c0b24f5d93e71580c221f61195e4331660c850050b43890d76493cac50aa1d9be978618063769b5df6a66d48a58b58bb18a3964123a25f41982a86205590a2ff0003c61b4bae9b332eacb2cbae1d84524b188ddd2fa2ca1982922ac0635f93e72a22630b4a0a71560a41701ac82452dd91d1b2050eafc8b0a618635b61db5935c88b823b3822350e4b0506dab911f11409a1dd01c8d82c9bc8cbb8882c66377662b72065002b59e81b362a8df5d922bab2cfd1cfed09550489edfbac6360fedaf3e16f5fd9f2a1f2af2bf4c2c2abad3b6bbecac321823758de50a782b3062aa4f804856207df13f838c8b64c2095085b8b2fcd030a6041e88f3d9a3e41a228807152c0f0a42ecd19132175e322b103915f9006d4da9e8d1aa3e082577965d0743b33c11cd1c33c91a6c208e6546204881837161f6392a9a3f6a0fd0c9d8d63abb12ebcad19789cc6c6291644b06890ca4ab0fc10483f47137793c7ac066d6acdab288e6865898a24816442a4ab28656a3f454820fd820e248acb023ef22beb01a9a53c9acfb2102c280fcdd828620a8216cfc987352556c806ea81388c08ac3320c30c300cbc86229108d1d582d4859c10cd67b02850ae22bbec137dd0a63206855c99e39244e0c00470843713c4d907a0d448aec022c5d809d49935f6a19a5d68b6a38dd5da094b0494036558a956a3e0f120f7d107bc561979245748d56248ca2f166526e4364d9b27ba20754280eaec90a6186180cd6d69f77662d5d58649e799c471c5129679189a0aa07649268018bc30c031fb7b1fa8902a19c6bc5c975e39a5f70c51962c16e80f2c49a001249a1788cb8117b0e4bb89832854080a95a364b5d820f1a146ecf62bb0a61861806375975de4236659628f8390d1461c970a4a0a2cbd16e209be812406238956180619afd2e2f4f9761d7d4b67635e0114855e18848c640a780a24745a813ffd8c980c8161672279248d38310510392dc4f11448e8b5026fa049a35459e9fb31e9ef41b136ac5b71c4e19a09490b201f468de53636b63724126ccf2ceea8918691cb1088a1556cfd2aa8503e8003eb",
            "2a045ecb92ee260ca15420e2568d926fa20f1a146ecf62bb08760eecc1150124855ba5fd85f795c30c030cbcf22cb3c9224290abb161121255013fda39126878ec93fb9ca603655816384c324aeec84ca1e30a11f91e9482790e3c4d903b2457565586180617865e3111494c8eeac16e30a80866b1d1362857237df600aeec053346bebc52c45df7208184a91f070e4956e56ff15238ad0bef97c8506eeb3e181d1f55d6d5f49f52f51d083674fd5a24630c5bb17b811a9c1f7101af2011f204531aee9873b0c303ffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003011100021101031101ffc4001500010100000000000000000000000000000008ffc40014100100000000000000000000000000000000ffc400160101010100000000000000000000000000000103ffc40014110100000000000000000000000000000000ffda000c03010002110311003f0096db200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffd9",
        }),
    },
    Smile = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc00011080200020003012200021101031101ffc4001d000002030101010101000000000000000000030102040506070809ffc4004e10000104010303020304040908070901000100020311040512210613314161072251147181912332a1b108151618425255c1d1545672829394a4d2246292b2d3e1f017253334434563647374ffc4001c0101010100030101010000000000000000000102030405060708ffc40038110002020103020403050802020300000000010211030412210531061341516171a1142223819107153252b1c1d1e142f0336282b2f1ffda000c03010002110311003f00e3215e914bf6eb3f2928857a4525828857a4525828857a4525828857a4525828857a4525828857a4525828857a4525828857a4525828857a4525828857a4525828857a4525828857a4525828857a46d4b0510afb51b52c1442bed46d4b0510afb514960a215e914960a215e914960a215e914960a215e914960a215e914960a215e914960a215e914960a215e914960a215e914960a215e914960a215e914960a215e914960a215e914960a215f6a292c1442bd2292c0ca452696d1406f2b16517b5452716aaed4b02e9149bb546d4b02e91499b51b52c0ba45266d46d4b02e91499b51b52c0ba45266d46d4b02e91499b51b52c0ba45266d46d4b02e91499b51b52c0ba45266d46d4b02e91499b51b52c0ba45266d46d4b02f6a9da994aed0146c508d88dab410a8404b2d0ada8da9948015b20b2d5149d429576a581748a4cda8da9605d229336a36a581748a4cda8da9605d229336a36a581748a4cda8da9605d229336a36a581748a4cda8da9605d229336a36a581748a4cda8da9605d229336a36a581748a4cda8da9605d229336a36a581748a4dda8d852c0ada8da9bb69042581548da99b55c36c2582e5a101aad46d58b4d7858b28a2a295f6a90db29642d1c61dc26bf1486dd27c1038d1a5a9cd3b76d2ebcb253e0e650b4715cc2d3e15696d9d801f0b2ed5cf195a38daa2948a57a452b664a52295e914960a52295e914960a52295e914960a52295e914960a52295e914960a52295e914960a52295e914960a52295e914960a5215e914960aa857daa7694b02e91499b51b09f00a581748a4cd847904236a581748a57a452582948a57a452582948a57a452582948a57a452582948a57a452582948a57a452582948a57a452582948a57a452582948a57a452582948a57a452582948a57a452582948a57a4525829498c6da8da9d13493e146ca893012db0124c441f0baac6d32dc1669689e02e28cdb672b8a462ed95218404f047a85479fa2e4b6ce3a44b5bca7f6c16aa009ec3629624cb132b9945435b456fec58b212f631aee54531b476349b4510b4b9ccda566dcc6b784974a4ae171b7672a952a2939049596939d64a8dabb11e11c2dd8aa452652296acc8ba452652292c0ba452652292c0ba452652292c0ba452652292c0ba452652292c0ba452652292c0ba452652292c0ba452652292c0ba45266d5eb3a63a37235a7373333763e9fe4387eb4a7e8df6f7fdebcdea5d534bd334ef53ab9ed8afd5bf64bd5fc0ed6974b97579162c31b6ffef279dd3347d4757c9ec69d8af9dc39711c35a3ea49e02f7fa57c3385a5b26af9865779ece3f03f171e7f20be85a6e918b8388cc7c4c76e363b7c31a393ee4fa9f72baac8d918a63405f83757f1f752d7c9c343f838fdfbcdfe7e9f976f767e87a2f0e6974e94b51f7e5f4ff7f9fe8799c2e8fd170dac1068f8e0b6887caddeebfadbad7619a736366d63628dbfd563001fb02e8217c0e79e5d4bdda8c929bffda4d9f478e10c4ab14547e48e7c9a6b64686c8c86400dd3d8081f985c5cee8dd132e32d9b478013fd3806c70ffb2bd5215c1933699eed365941ff00eb26864863caab2c14be68f916adf0cdbf349a3e610793d8c8fdc1c3fbc2f03a86979da5e4fd9b50c57e3cbe4070f23ea0f823ee5fa65f1b2414f683efeab8fab68987a861bb1f371db9301e79f2c3f507d0fb85fa0747f1ff0051d0c943a87e363f7ed35fd9fe7cfc4f9bd6f86f4d9d3969bee4bdbd1ff8ff00bc1f9ce914bd5753748e568521c884bb234f24013572c27d1c3d3eff0007f62f3b14124f33218585f23dc1ad68f2495fbb687a9e975fa65abd34d4a0fd7dbdefd9af54cfcf351a5cda7caf0e58d4bfef6f733d2f41d31d34fd7b2a47492187120aee380f99d7e1adf4bfdcbd1e2741e1c1183ab67bdd29f31e3d50ff00588e7f25ea344d374fd2b1a5c7d3dd216c8e0f7090d9b02afc05f957897f691a186932e0e9391bcdd94b6f0b9e5a6fbbabae28fb0e95e16d4cb2c32eb2158fd55f3f03c86a5d37d327596f4de9f953c5aebf0dd9b142fb731f1b5c18497550f98d79fc297859227c52be291bb5ec25ae07d085f74d43222c4d3b232e4798c4719fd235a5c5bf4f1ef4be33993b32a59320e390f91c4b9e5dfac4f249f4b58fd9d75eeabaf8e486a94b2e355f79b4ea5eaadb4daaae16e6be4ce5f12f4cd169f6cb14a3097f2d3e57e49a5f9d59cfa452652297ed567c08ba452652292c0ba452652292c0ba452652",
            "9da96055229376a8da9605d229329149605d229329149605d22932914960238f73a97462c6dacdd4b2c141e2d75db2c622a5d6cb26bb1cf8d27dcc123eb858de45a7e4905fc2cd4b920b8b3129722cda29329452e4306c8e0b4f18f46e95627d10b56f1e8bad26ce68a425f75b6928e3170b5a5e78ba4b0f3e16537e8575ea637b0b784ba5a65e4da4d2e74ce16435b6559d1fd1587853e896046d46d4c514ad928a6d46d57a452b628a6d46d57a45258a29b569c0d3f2752cd8f0f123df2bcfdc00f524fa049a5edfa0236b72b3a47c643cc6d0c716f91bbe6a3f92f9ef11f559f49e979b5b8d5ca2b84fddb497e4aedfc11e974cd1ad66ae1824e937c9577c3f6478c0cbac46c9890d171d30b8f005937c9f6fc1793d4b4bcbd2b35d89991ed78e411cb5c3ea0fa85f52ea2e98d17aaf071f0b5cc5764c18d931e546d6c8e6548c362e8f23c8a3f55e7bae1d10d431fed4dee37b771b5bc11cf3cfd2c7ef5f8d784fc79d5353ae8e9f5779d4ef88c629c6b94e2d349aef7baa97367de755f0ce8e381e4c3258b6fac9ba7f07c377ed5dcf05b51b539e585d6c66c1f4bb54a5fd058e6e7152945a7ecead7e8dafa9f9a4e0a32714efe2affba4fe8536a36abd22972598a29b51b55e9149628a6d46d57a4fc4c49b37361c4c766e966786347b9589e48e38b9cdd25cb658c5c9a8c7bb3b9d23d3275bce33e482dc1808de47f4dde8c1fde7e9f7afb5e262b18c69d8d6b5a006300a0d1e9c2c1a26938fa76043838edfd0c0393fd777a93f79fee5db5fcb5e22eb993af6b5e77ff8a36a0be1eefe2ffd7a1faef4be9f1e9f8143fe6ff89ff6fc810842f04f4c10842004210801084203066e1c52c3235f1b64864696c91b85820f95f1bd5b4997a3fa9b17361699b13b82489cef240f2d3ee3ebf715f735e77a87458755d366c19001bc6e89ff00d478f07fbbee2bddf0ff0058fdd1a971cbce9f2fddc91f83e2d7caff0035c7b5799d4f43f6dc570e324398bf97a1c8c79f0f5ac7197a7ce1e2a9cd3facdf623d0fec5a20c5747207bdc2c78017c748c8c1ca7b373e09e27169da482d20ff00e4b78ea4d79acda356c9af79093f9afa4d6fec9e72c9bf41a94e0f95b93b4be6ad3fd11e6e9fc69b71ecd4e276bdbfdf63ea9a8e76269d8326466bdad8c34fcaeab93fea807caf95750eaffc71a997c4dd98917c90461bb406fd687a9f2b04f93919527732679267ff005a47171fda934befbc27e07c1d01fda324fcccaef9aa4afd973cfc7d9d1f35d67af64ea3f8718ed87d5fcdff00629b51b55e914bf47b3e628a6d46d57a45258a29b51b5336fb2b061214b14276ab068562294a594bb6305be125eca349ed7504b7725653e4ac56d46d57a452dd99a29b51b55e9149628a6d46d57a5d8d1fa7350d6773e06b6281a68cd2586dfd07d4ae96b75da6d0e17a8d54d420bd5ffdfa1cd834f9751358f0c5ca4fd11c5163c2b87babcaf4da8f456a98503a785d1e5c6c16e115877bf07cd7b2f314bafd3bab687aa6379745954d2ef5e9f35dd7e672ea749a8d24b667838bf895772546d57a452f50ea14da80db2af4a4794b03070aec710e45200e560a746289b2b567c98c31d413f12c0f2bbd174967e6e38c89268b18386e6892eebea6870bc3ea1d5b47d2e2b26b72a845f0afd7e4bbb3d2d3e933eafeee08393f81e50425c2d29ecda6975b2b0b2b4aca762e5c61afab041b0e1f507d42e74bcbed7a9a7d463d44165c52528c95a6b94d1d2c98e58db84d535dd0a0de142bd229762ce21748a4ca452581748a4ca4525817480d24800124a652bc2f30e447337cc6e0e1f81b59936a2dc55b2aabe4f79a3f4c6169b87165ea700c8cc70bedbf96c7ed5ea7eb6bbc339e00688da183c347002a61ea183af637771a4f9c72e8cfebb09f6f51ee9edd3dc1df339c47d03795fc59e20d7f53d5eb66faa36a69ff000bba8fc12f45edefdedf73f7be93a7d061d347ecd4d7bfabf9bf734b1e248daf6f8217373344d232f5066a19d08748d01a77bfe477d2c7aadb91918b8106fca9e3c78da38de6bf21e4af9ff537510d51ecc5c273db8719dc49146477d7ee1e8bd9f08743ea9d4b577a294b141a6a5915a497aabe2dbf6bf8fc4f33ae750d1e9b0d664a72eea2fdfdff00d9c2d5324676ab9394c6b58c7bcec6b4506b7c015f752c749948a5fd6d831430628e1c7da2925f25c1f8ce49bc92739777c8ba45265229735981748a4ca45258174bda7c3ed344daa4fa8c82c63336b38fe93ac5fe02ff0035e3e97d63a0b15b1f4dc2eae722673c9bf207ca3f715f05e3dd7cb49d172460e9e46a1faf2ff549afccfa2f0ee9d66d7c5cbb46e5fa76fad1eda0676e168f53c94c42f0ff0017b3b2f4df82fd5d9b833ba0c88f4e93648cf2dba69afc095fcfb8316f9c7147d5a47e9b395272673f53f8ebf0a349d4a6d3f2fac31dd3c276bfecf0cb3b01fa6f634b49fb8ac7fce1be107f9dbff0591ff22fc45d35d4b93d319d34d0606067e3e447d89f173b1c4b1cb1ddede796f20720fa05ea7f8abe1ff58f3a16a1fc8fd5dfff00dbf5390bf0e577d239fcb3ee70fb97e851f0be95afe395fcd7f83c996b6717cae0fd69fce1be107f9dbff0591ff22fa2e91ace93afe950eaba26a38fa8e0ce2e39f1e40f63bea2c7a8f50790bf985230c72be32e6bb638b7734d8346ac1f50beddf0331fe2deaba76b7a7fc39ea9c1d1f171a58a7c98b3581c1ef782039b71beb88f9f1e9e579faef0fe1c389e4c792abf9bb7d11d8c7a994a54d7e87ecfd5f59d2740d2a6d575bd471f4ec1805c93e44818c6fd05",
            "9f53e807257cebf9c37c20ff003b7fe0b23fe45f9d7e39e3fc5bd2b4ed134ff88dd5383ac62e4cb2cf8d161303431ec00173aa365f1271e7d7c2f87a9a1f0fe0cd8964c992eff97b7d50c9a99465497ea7efafe70df083fcedff0082c8ff00916cd33e3afc28d5b52874fc4eb0c76cf31dacfb4432c0c27e9bded0d07ef2bf9f28a07e53c83c10bbcfc35a5ae252fa7f838fed73f647f53927259be03f51c85e37e10e765ea5f05fa47373a774f91269d1ef91fe5d56d17f800bdc2fcff51876ca589fa368f4a12ba923e2dd7ba70c6d7db98c14ccc66f3fe98e1dfdc7f15e4a97d4fe20e2efd0a398345c19005fb3811fdc17cc297f45781f5f2d6744c2e6ee50b83ffe3dbe947e5dd7f4eb06be6a3da5cfebfeec5d22932914bedacf045d229329149605d22932914960ab4265868a550394ced9728ca84385a8a4e7336aad2a9905d1452652292c0ba46d4ca452581748a4ca4fc4c2c8cecb662e2c46495fe1a3ff005c058c99618a0f264694572dbe124bd59a8c653928c55b664dabecda763c589a56263c35b191368815762c9fc49b5e6f07a3b4dc4631faa4c7225e098d876b07b7d4fec5e9e07e388d9040435ac01ad6f3c01e9cafe6bfda178ab43d6638b4ba19b92836dbaa8be2955f3c73e95c9fa9f867a36a744e79f5114b72e3dd7f6fa9cbc3d025c5eb2d47a84eb9a84d1e6c114234f91e0e3e3967f4d8df427fbcf9be3c0eaf1618d5329e4761e6477e863161a6fdfc05f59f55e426e94c5865cdd5755cd7e5b1bbe6d806c2ff005f98fdfe8178fe0aea98b49aa9e5d4ea250e2315182e67e8a3d9ae3ddd3e7bf73d2eb78253c2a18f0c67cb7726ea3eefbaeff9f6ec7cf8817c0348da984592680bfa2297f57478491f8cb76ec5d22932914ad90652dba669797aae5f63159640b7389a6b07d4959b6af45d2baa41a7664b06510c872400643fd022eafdb95e175dd56b34bd3b367d0437e58ae17f5e3d695baf5aa3bfd3f161cda9863d44b6c1be59d5c5e96c585edef6a61ce041a63383ed64af45aae9d89ad6939ba56a11ba4c4ce89f04cc6bcb4963851008e4707c84bfb11700f8a56ba3778779047de3cadb1465913580976d1e57f22755ebdd4baae58e4d76472942eb84abb7b25ec8fdbb4bd3747a2835a65c4bbf2ddfea780ea666340fc4d2a10d8a0c081b14344bddb36801a4dfa57af3caf305bcaf69d49a8e8ee8a58b0a1826cc95e44b3865ed1c5907ea7c58f75e476f0bfa6fc0f8b2e2e938d64538af453abf76d24ad26dbadcdbae7b51f937887363cbab96c51bf571bf92bb6d5d77a48486ab6c5a6284b8abbb19de8bee1cd59f3ca2e8c8d88bbc287465a68ad71831bb90a9310e758452762b832ed45265236add981748a4cda8da960a34b98e0e638b48f041a5a86a5a986ed1a86481f4eebbfc5236a36ae0cb830e6ffcb052f9a4ce48649c3f81b455ef92576e91ee79fab8daad266d46d5cb14a2a9186dbe58ba45266d46d5ab20ba45266d46d4b02e91499b51b52c0bdabecfd24c6b7a7b4b0d681fa2be3eb6795f1cdabebfd1d3f77a7b4e3c0d81d19a3f471ff15f957ed2d37d3f04bd1645ff00d647d87851afb54d7feaff00aa3d5af03f19e2966f81bd631c31ba479d3643b5a2cd0209fc8027f05ef95658a39a17c3346d92391a5af6385870228823d410bf19c393cac91c9ecd3fd0fbe92dc9a3f9667c942fdb9a97f05cf86b9da8cb958d36afa64521b18d8b92d31c7fe8ef63881ed7c2c9fcd47e1e7f6c7507fbc43ff86bf445e21d135ddfe8799f66c87e2e5faa7f821c7208baca631b8465d88c0fae0b8094917f5a20fe217a8fe6a3f0f3fb63a83fde21ff00c35f61e95e93d07a2fa7a1d0ba770461e1444bab7173a479f2f7b8f2e71ae4af2baaf5ad3ea34cf0e1b6dd7d1d9cd8704a33dccfcedfc2f2290c3d1d308dc620ecb617d701c44440bfad027f02bf2b2fe98756f47f4ff5c74fbf43ea4c019986e7091b4e2c7c4f174f63872d70b3f9906c2f907f351f879fdb1d41fef10ffe1a74aeb5a7d3e9a3872da6afeaec66c1294dc91f8b903c85fb47f9a8fc3cfed8ea0ff7887ff0d6cd2ff82f7c36d3b548337225d5b548e276efb2e5e433b521ff00ac18c6923dae8faaf55f88b4495abfd0e1fb3643d9fc188a587e06f4747346e8dffc5b19dae14689241fc4107f15ef94318d8d8d631a1ac6800340a000f00295f9de6c9e6e4964f76dfea7a715b52478eeb76b4f4d67d8069cc23d8ee1fe257c8a97d6bae260de9cca04b6e5958c1cfbdf1f92f94ed5fb67ecd935d2b237d9e4957e913f3ef1534f5914bd22bfab1748a4cda8dabf4fb3e485d229336a36a5817b51b538369496d8f0a5968452746eda1576a291f213a2243b8aa5265236a2e082e91499b51b55b02f6a90d4d0d514a594516af71d0d0e3fd9f327a69c80e6b09f50cafef3fb978caf65a3073b2f4ec919189298de383ea1c3e847a85f37e27e959babf4bcba2c13db29553f4e1a74fe0e8f4fa56b21a2d5c351923691f479e3944ce2e69366efcabe3c123a56bc82d6b4dd95c0c7eb76d0195a79bf530bebf61ff14c93ade00d062d36473bd77ca00fd817f354bc01e218e4d9f67bf8ee8d7ebb8fd6978aba6b85f995f93ff07ac5e0baa35f7646449a7e14b78c1bdb91c0d891d60f1f7555faf2b16a5d47a9ea51985f208203e638b8dc3dcf92b8c197e17eade10fd9fbe99996bba9b529afe18ae545fbb7ead7a7a2ef6dd57c4f5bf127dae1f67d2a6a2fbbf57f0f90aa452696107c2362fd8ecf871548a4d2d51b55b0310afb514b0076367e6e1dfd",
            "972e5841f463c81f92be46aba965b4b7233a791a7cb4bcd1fc166a452e94b43a5965f3a58a2e7ef4aff5ab39d6a32a8ec5375ed6e85d291e55e914bbb6700c6cbb4504c6e45059e901ab0e299b536863dfbf9a49da494cda559ad57b13b8a319015693dc974aa6462e9149948a56c82e9149948a4b02e9149948a4b02e9149948a4b02e9149948a4b02e9149948a4b02e97d13a0f3376993e213f34128907dceff00cc7ed5f3fa5dae98d4069daec4f91db6197f45213e80f83f81a5f25e2fe9b2ea3d232e282b947ef47e71e7f56ad7e67b5d1354b4bad84e5d9f0ff33ed00873438783ca959f124b618cfeb35685fcd78e6a715247eaf254e81085f18d33a9356f87df10b50d1bacf50cacad23517f771751c9717edaf0ebf41469c00e0806a8aec431b9dd7746e18dceebba3eceb16a5aae9da4637da751cb663c64d0ddc971fa00392b54334591032782564b1483731ec70735c3ea08e0af8d7c42c8c897aca78a627b7046c6c40f80d2d0491f7927f25dbd0e956a72f97274bb9dde9da35abcde5c9d24ad9f59d3359d335885d2e9b98cc86b4d380b0e6fde0f216f5f0ee87c8c883ad34f10135338c5201eac20937f7503f82fb5e4e5636161c99799911e3e3c4ddd24b23835ac1f524abafd22d365d91769f26ba968969332845da6ac7217c6d9d41ad7c41f8a18ace97ceccc2e9dd24ffd232e13b04c0f26c1e0eea0d6822eadd417d9174e78dc293ee74278dc293ee0a1ee0c639c7d05a959732401a23b02f927e8175f24f645b33156e8f9ff005f650ec61e17ab9ce99dfb87f7af054bb1afe78d4f5bc8c961262bd91ffa2381fe3f8ae5d2fe9af0b74d7d37a4e1d3cd54aadfce5cb5f95d7e47e47d5f54b57ac9e58f6ba5f25c7fb174a436d5e90052fa7b3c925b11715b62c20e6fbaccc796ad98f941ae05cb866e55c1cd0db7c899b11ccf44a01a1b4472bad919713d954b96f2d26c2c425292e4d4d28be0ccf68be1529348514bb099d762e974349d1751d733861e9b8ce9a4f2e3e0307d49f409783833ea1a841838cddd34ef11b07b92bf46f4f68589d3da345a7e280481ba492b991fea4ff77d052f27a97515a382515727dbfc9eaf4ed03d5c9b6ea2bbff0083c0e9bf08610c0ed5f557b9c7cc78cda038feb3aeff0025af27e10e8ee8ab0f53cb8a4faca1b20fc801fbd7d250be425d5b58e5bb7ff43ead74bd228edd9fd4fcefd47d13acf4db7bf90c6e4621343221b2d1fe90f2dfdcbcc52fd5b2471cb1ba3958d7b1e0b5cd70b047d085e320f863d2f14f24b3433e407b8b846f9486b01f006da3c7b95ede97af47635a85caf6f53c6d4f4396f4f4ef8f8fa1f05a534bef19bf0c7a5f2622dc6867c27d70e8a52ee7dc3ad7cdfa93a1752e9e97b97f6ac171a6cec6d6df670f43fb17ada6eada7d43db174fd99e66a3a5ea302dd256be078fa561138f80b79c0900076f0b7e3e131b0dbd77e59924746389b6700c647a2740cb78042db3b226b8d2cfb835d602bbf7226ddacd6705a4072cd363068e1688b21cf21b6ba031dae65b8aebb9ca0fef1d851525c1e6dcca51b785d59f05e49735bc2c0f89cd3442ecc66a5d8eb4a2e3dcb39945576aea1c5dc682549885be42c2c8995c1a305236ad2630025ede56d33142b6a36a696102e9452b6417b54b472af48a4b05e9bb52eacf0ae470a00a2b28d59261245a0c34db4d6c9f2d15524b8d052d97833ede5488dc7c05b1988f70ba5d7d3b4cef3c070e16279a3056cdc314a6e8f3bda70f2141657a2f7d91d3f08c7dc2ae979dc8d34b2e8785c18f570c9d8e6c9a59c3b9c1da8dab449196ba8854da7e8bb899d4a15b51b53b6155daad905ed46d4ca4525817b51b5329149605ed46d4ca452583e8fd2bae1cec36c32bff00e998e28dff00f519e01fee3f82f64c7b6460737c15f0dc4c99f0b2a3c9c779648c3608fddf72fa8689aee3ea308960219281fa5809e5bee3ea3dd7f3e78bfc393e97a896b74d1bc1376ebfe0dff67e9eddbdaff4ce87d563abc6b4f99fe247b7c57f9fff004f48b95aff004f693d4da53f4dd6311b3c27969f0f89d55b987d0ffeb95d28e4648db69fbc7d15d7c4465ff28b3e9398bf89f163d01f10fa36673fa1ba87edb820d8c2c8706fe1b1df21fbc1695c2d7f3fe22ea324275ce8395d951b431b918903c17341e6c34b9a79f1e2bd382bf4323c78e17771eb278e4a692bf73bb8b5b3c5353495fbfa9f9d7419be2461e6493689d0f2b324b7b627cc81dfa2bf51b8b5be9c9e78fa2f451fc37eb8eafc966475ff0051ba1c5043bec58cf0e20fd0003b6dfbfe62bed1e7ca132eb27925bdf7f72e6d764cb2deeafdfd4e7e8da2e99a06971e99a46233171a3e435be5c7d5ce3e493ea4ae821525959136dc79f41f55d194abef499d1e64c249044c2e3f80faaf0fd5fad1c6c5760c2fff00a4e40f9c8fe830ff008fee5d2d7b5f874d889791264b87e8e1bf1ee7e83f7af98cf34d9390fc8c891d24af36e738f24afbef06f86e7d43511ea3aa8d6183b8a7ff0027eff25f57c7b9f2fd7baac74d8de970bfbf2eff0005fe5ffdf433ed46d4ca452fdf6cfcdc5ed46d4ca52425815b514532914960a72a28a652292ca2f6ae8e8fa16a5aee68c5d3718caee373bc3631f571f459618249e78e08985d248e0d6b47a92682fd13d3ba1e3681a2c3810346f0374b201cc8ff0053fdc3da9795d4ba87d920b6ab93edfe4f4fa7687ed737b9d45773cbf4a7c3b1a16a706ab9b9cdc8c989a76c71b298d241176793e7e817bf4217c2ea35393513df95db3edb069f1e9e1b312a40859f373b0b",
            "4dc1973b51cb870f1611ba49a790318c1f52e3c046167616a58316769d970e662cc3747341207b1e3ea1c382bae760d0842c5aa6afa56898473b58d4b174ec50e0d33654cd89809f02dc40b406d4ac9c6832f164c6c98c49148d2d734fa8568a58a785934323648a468735ec208703e0823c85755369da2349aa67c5f53d133b4bcecac776164498d13e993f6896b9be41b02bc2f319390492d61a0bf47af0dd69d198da8e14da969b0362cf8c6f7358284c072781fd2f7f5f0be9b47d56329a86655f13e6f59d32518b9e177f03e32f638f2544703dfc00b5c713dce00b4aece360ed6876c5f4d3cca08f9b86273670e3c67c6e048a5b1af7002cf0bab958bba2b68e571a56bc12da5c51c9e61cce1e59be3cb87b458eab5cacb0c73c96aa88a42f005ad9f60903373d6928e377661ca591550e6b9ac24959b2270ef0a2575f859c8255843d59894fd10a7124a0355f62b861a5d8b38285bb9154ba5a574e6b1ad3eb4fc27c8c069d21f9583fd63c2ebf4774cff2835571c8dc30b1e9d291c175f8683ef47f05f6e82087171d98f8f13628a314d6305001787afeaab4cfcbc6ae5fd0f6f41d2dea579991d47fa9f1dffd97750f6b7f7f0b755ecee3afeefd5a5e6f56e9cd63447d6a384f8984d0907ccc3feb0e17e8a4bc8c7872b1df8f9113658a41b5cc78b0e1ee17938bae678cbf1126bf43d6cbd1304a3f86da7fa9f99291b57d664f85988fd426919a93e2c426e38833739bedb89fee59f33e157e8b7606ab7201fab34740fe20f1f92f75757d23696efa33c27d2756937b7ea8f9752d10b597cad7a9e8f9fa3e61c4d431cc52791ea1c3ea0fa85883485e9294671b8be0f35c65095497277f0846f1b385d78a13036dabca634ef89e082bd043a883053bcaf33518e49f07a9a7c916b92997aa4ac7edddc2c7fc62d703b85dac99d30924242c1cae7c7823b4e0c9a896e1b921b2c84b52b6060e559a1de555f64aedae383a6ddf251f47c25d26ed4162da66189a46d4dd88d8ad92856d46d4dd88d8ad8a15b51b53762b089df45370a6236a7e2cd362e4327824747234f0e69a522171f452232d3e171e450c91709ab4fba66e3ba2d4970d1ee34aea8827daccc70c69ff00ae3f55dfe1fb97aa8f36da0bc0734f8734d82be5d83a73e7901ae17d0f48d30438c1c1c47d45afc7bae782b4d193cbd3a7e5b7ff0017cc7f2f55f5f851f7dd2fad679ad9a98ee5efebfeceb36789fe1e3ee3c26020f820ac2e6c41e5a78be2d2653142d2492efb8d2f859f40ead8dd792a5f14d7f7e4fa45acd3357babf23a8481e48096e9e26f9783ec395e5f2b5c820e198ee79bf578ff0005cbc8ea3cd7467ecf0c50f1e68b8fed5dbd3f857ad6a1f185417bca4bfb5bfa1d4cbd63438bbcdb7f047b29f3db1c6e7db6360f2f790005e3b57ead8e3dd169a7bd29f333c7cadfb81f3f8f0bcce6e6666649bb2a77cb5e371e07dc3c058f6afd03a3f8034f864b37529f9b25ff0015c47f3f597d17ba67cb6bbc4b972278f4b1d8bdfd7fd1496496799d34d23a491e6dce71b25536a6ec46c5fa9c54629462a923e3ddb76c56d46d4dd88d8ad928a065851b0ad2c00709a18da2b2e546946cc05a8da9ef67ccabb16accd0ada8da9bb11b15b1475ba49b11eb1d2bbbb76fda1bfadf5f4fdb4bf427a2f91fc32c3c5c8d5f31f918d14ce8a36be32f607163b77917e0afae2f89eb7914f50a3ecbfd9f69d131b8e9dc9fabff00409734f0634465c89990c63cb9ee0d03f1298b95ae6878daee1b71f2249232c76f63987c1aaf0782bc25f13df8a4dfdeec7e77fe1659b9f91d25d323027ef6892e64bf69744e0e619830768123dbba40fa8f609bfc11a5d59dd2fd4b04dbff008a23cb8ce358f944c587ba07e1da247d4fd495f7087a17a7dda165e8daa61c7ab626611de8b2d81ec7578f97c023ebe7dd65d57334cf867d33a7ff0014f4e322e9e8321b1658c18c8fb0c4ebb9fb6d692f01db777ad12ee68ae4dcb6ed449a8a97dd7c1ec97e3cfe16f2eaceeb3e9dc79b7ff140c27bf1c11f299f7912fe21bdbfc0fb95fa6b23e22742e2e8835a9bab749fb039a1cd99994c7efbf01a1a49713e80024fd166c7d3f4bf895d15893f58f4842d8321c6787075066f92266e3db7bac02c7b9b44b472376d24f2b317b5db327cf3f8346a39707c1180eb994d8311b9d3c7a7ba77868300ab0dbf2049dc03eea5f73648c9636c91bdaf63858734d82179bd4ba2b49cd83121c56ff174589188628b198d6c6c60f0d0daa15ecbb1a56998fa469b1e0e339ee632cdbcd924f2524d3e4e56a0a09a7c9b90842c1c67c9f53d2f1e2d4f2763406895d43f12b1cf911c106c6816bda75c478f87a1c73430471c8f9c34b9ad009f95c57cd77ba63457d76924f3e3537d8f94d54560c8e0bb92ecf1c82173a599ae792168cbc6313375ae5106d7b18a117ca3c6cb924b866b86660941217464c812c7417080376b4c6f70f55b9e34f9310cad7041692a362d3db476d6b718da66edf2bd0689d27aa6b80498f108b1ee8cf2f0dfc3d4fe0a9d3fa3ff001c6bb8f84e35193ba423c868e4d7bfa7e2bee30c3163c0c8208db1c6c01ad6b45003e8bc7ea3d45e9ea18ff89fd0f63a774e5a8b9e4fe15f538fd33a0b7a7b48fb1f784d23de647bc36ac900579f4a5db4217c864c92c92739be59f5d8f1c71c5420b84085e4b45f893d0fd45d5197d33a3751e2e66ad89bbb98ecddced34edae229f47ced2697ad58aa39010bcf75675af4bf43e9b16a1d53abc5a763cd276a32f0e73a4755d35ad049e3934380baba5ea9a7eb5a4e2e",
            "aba56645998395189619e176e6c8d3e082940c5d49a141af68f2e2bdad13b4174321f2c77f81f057c3f2b4ccdc2206661cd8e4f8eec65b7f9afd12973c10e4c0f832226cb13c5398f16085eae87a94f4ab6356bfa1e4eb7a6c354f7a74cfce619456963c06d2f49d5fd36cd13526bf14561e4598da4d961156dbfc78ff00c979ad8bebf1e586782c91eccf92c98a7826f1cbba14f659b4bd9cad5b7851b172a91c2d58431b5c2ab94498a41b015980b0d84fee9239587269f06d24d7273cc75c2aec5a9cddc6d476d72291c6e266eda3b6b4f6d1db29b89b4cddb5223b2b7430071a216a8f048782470b12ca91c91c4df639b16392f0297a4c1d15b3c438e569c3d2d8f01d5caf478584ec6a711c2f2b53aca5517c9eae9b476fef23cb65f4fba16ee6b5626e92e246e6afa63238b2184bc0007d563c8c381d6630385d2875097667767d3e3dd1e734fc10c0006d52ecc737686c0e59322530fcac14b9e5d905d62f9589a797967242b1708ec48f8dcd24bbe65867699212039666c192f76e37499f383b795230daf866e53dcb9471f2b01d45de565c7c09657eddbc2efd39d26c70e0aeb438b1c510735bcaee3d4b8468e8ad329cacf1b9da23a38f706ae1c988f61e5abea8ec31951500bcf6ada398585db57369f5d6f6c8e0d4686bef44f0c63476d6d963a791497db5eba9d9e438519bb68edad3db476d5dc4da66d8a402168eda3b6a6e2ed33165a3b6b4f6d1db57713699bb68edad3db476d370da7b6f860ddba9e7ff00fc5bff00797d497c0b0750cfd31ef7e0653f1dcf14e2c3e42dff00ca8ea2fed7c8fcc7f82f9ed6f4dc9a8ccf2464959f43a2ea58f4f8563945ba3edc85f11fe547517f6be47e63fc11fca8ea2fed7c8fcc7f82e97ee5cbfccbea777f7d62fe57f43edc85f1683ab7a8a09d92ff0019492ed3fa92539a7ef0bdbe9bf1034bc8880d4637e1cbea402f61fb88e7f62eb67e979f12b4b77c8ec60ea9832ba6f6fcce9e3f4574761eadfc6f89d29a3e3ea21dbbed7160c4d96f8e7786ddf0177d715dd57d3cd6971d561200be2c9fdcb81ab7c42c38a2747a4c2ec894d8124836b1bef5e4fec5d6c7a3d46474a0ced64d660c6adcd1ee50be26feaaea37c8e79d5666ee374da007dc2957f951d45fdaf91f98ff0005e97ee5cbfccbea79bfbe717f2bfa1f6e42f890ea8ea2fed69ff31fe0a7f955d43fdab3fe614fdcb9bf997d47ef9c5fcafe87bbf88847f2720fff00d2dffbae5f2e8e42d7d85b7375ad575280419b9b24f1876e0d71e2febfb4ac0385ee68f4cf4f8bcb93b3c4d66a567cbe645513933ba5145612cb2b5916abdb5e842a2a91e7cee4ed99b62b00427f6d1db5adc6769a362362d3b3d91b3d975b71cfb4f53f0fa291baecd376a431985ccde1a4b41b0689f4e02fa72f17f0fc569f9bff00f56fee5ed17c77529eed44be07d8f4d86dd3c7e20bca6a5d51a765b32f47c6c89a0c8998fc78f276d3192105a0d837c13e697ab58bf8a34cfb7fdbbec30fda6efb9b05dfd7eff75e7aa3d68382bde8fc4bf05be1ef5c60fc78d31999a467e9e34499f267644b13d91ed0c737687d53b7df144d837e17ee71e02465e39cac29f19b3cb8e658dcc12c2ea7c762b734fa11e42f1d8fadf5d69b8634fd4ba3a6d673a26b5833f032e08f1f20f8dee123daf8cfa9686bab9a256a52ddc9c5d8f8b7f0ace96ea3d524e9dd734cc3cacfd3b1592e3cd1e3c6f90c0f739a5af2d6834081b6ebc803d42f6bf0666c9e83f84ba468bd4f16547a848e972beca5877e2c723cb98c70711b4d73b7d2d7d53a7b1359c7d31f275066332351c895f348d84930c009f9628ec025ad6802c8b71b342e86cccd2f4ecf7b1f998714ee67ea97b6c857771b59c98f6295cfb0ec5c98733122cac77ef8a568734d5584e50d6b58c0c63435ad1400140052b8ccbabe0f27d77893e668d8f162e2c991289c3aa38cb881b4df8fc17cb5f0be291d1c8c731ed25ae6b85107e857df97c5f5a67feffd40ff00fb127fde2be97a4e76e2f1576e4f99ead81292cb7df838fb14ec5a367b2911d95eeee3c2da20424f8553190790baf0c2033710b34d1fcc682c2c96e8dbc74acc1b11b16aed9fa2eff4ef4c49ad48e9a6798712334e701cb8fd07f8a9933c7145ce6f82e2c12cb25082e4f302229ec8db5c85f62c6e9dd171a211b34e85fc7991bbc9fc4ac9a8f496919b19ed403125f47c4287e2df0bc95d5f1374d348f5bf746551b4d367ca43431d61696641342977a6e8fd584af8a3c7ee6d3fac1c0077dd6b0cda0ea382f1f69c57c62ff5bc8fcc70bbbf68c53ed25674fecf9a1de2e8d7a748fde0fa2f4f14e658c336af358b1c91116385da8b299056e0bc9d42b7c1ebe99d4791f23a4ddb18080b4c18ee60b773692ccb8dee0e684efb60602e7785d377d8ee2a1399a6091bb80e567c7c58e376d95ab48d51b21a099276e68ec1f99694a695332e316ed03df891c5b03459591ba70793201c14c6e13a57ee27c273e47c2433fa2144dafe165693ee840d25bfaee5258d67e8ed5e6ce35b1ab03f28878bf2b4b7cbb99fbb1ec3e373e071a3c2c99f33a6616bc70b49787341b4b9df03596f217243895d189ab8d1e2b3b0dcc7176da0b9c59caf4da9e4c32b4b630b8459cf85f43832371e4f9bcf8d297065d88d8b4ecf646cf65cfb8ebed336c46c5a767b2367b26e1b4cdb11b169d9ec8d9ec9b86d336c46c5a767b2367b26e1b4cdb11b169d9ec8d9ec9b86d336c46c5a767b2367b26e1b4cdb11b169d9ec8d9ec9b86d336c46c5a767b2367b26e2ed336c46c5a767b2367b26",
            "e26d336c46c5a767b2367b26e1b4cdb14ed5a367b2367b26e2ed336c46c5a767b2367b26e26d336c46c5a767b2367b26e1b4d3b11b169d88d8badb8ec6d3d174b6b581a462e44796e78748f0e1b5b7c52f45fcb1d17faf37fb32be77b11b179f97458b2cdce576cf4716bb2e282846a91f44fe58e8bfd79bfd99561d5da3bbc3a6ff0066be7422bf45a190903c2e17d3f02f739e3d473bf63ea7859f89a841dec59848df51ead3f423d1695f258dd918d289b1e57c4f1fd263882b737a8f5d8da1a339c40feb31a4fe642ea4fa6c9bfc3971f13b70ea714bf123cfc0fa4cb2c5044e96691b1c6d165ce3402e13bac3456bdcdeecaea35623345784cacdcdcdafb5e549301e039d607e0b388afd173e2e9904bf11dbf81c193a9cdbfc355f33e85fcb1d17faf37fb328fe58e8bfd79bfd995f3b31d2362e5fddb83e270fef2cff0003e89fcb1d17faf37fb32be79a8be3c9d532f222b2c96573db62b824951b11b176b4fa6c781b70f53aba8d4e4ce929fa19b62bb23b29db15daca5da723aaa3c9524b5b41371e16487e7542d5a74ec6765ea38f8a1db448f0d27e83d57149d45b3962ae491d0c4e9bc9d47e7818d6c7fd77f03f0faaf7da6e1334ed360c38c0fd1b6891ea7d4fe6b4451470c2c8a2686b18035a07a0575f31a8d54f370fb1f51a7d2c3072bb8217ce7e26fc5ee9df85c34c66af8d959b3ea0f76d87136973236d6f90ee23816001ea57bec1cec5d4f4ec6d470666cf8b9513668646f87b1c01691f78217529d59dc34287b1af6163da1cd70a20faaf9afc47f8cdd31f0d359d274ad620cac99f3ff4920c60d3f6686f6f71d6458bba0393b5df4e7e9114b1cf0b268646c91c8d0e6b9a6c38116083f44a6b9079ecdd29b0c8e31c6e319e41abaf65c7971ecd7a2f78b89ace2b1918c88da1b669c07ef5ddc59db7b6474f261495a3958d042d88d9e563ca79bed7d5679e696375b49521fdc01eef2bb8a2d3b3a8e5e8331e2630f257460a63adc785c924b8fcbe8a64c92c6ed255716c292476df9ac887cbe1649f304eda6f95cb6cc66e13f1f6c6fb772567cb48bbdb2ed6c974e06d0ec62fe6b95b5a03fe7a52f04b6d8a6e14602c731a403e17232cc8f757a2e9cf218cacb2be37464faaed62e1d9d6caf8a38d2c542d66d8b7c82ed24b17a9097078f356ccdb11b169d8b5e1e939f9fce2e2be400d6e0287e6785a96451572746638dc9d4558ed0fa73235890bf776719869d211767e83dd7b8c6e93d0f1d9b4e2779deae95c493fdcba781871e06043891001b1b40b1ea7d4fe6b4af97d46bb26593dae91f51a6d0e2c515b95b3cd67f46e93931b8e331d892fa16125b7ee0ff72f0d99a1ea187a83b09d8ef9241cb4c6d2e0f1f50bebc85ac1d432e2e25f797c499fa7e2cbcc7eebf81f1a9b4dcdc66efc8c39e26fd5f1903f6acdb17db5cd6b9a5ae0083c107d5788ea7e9d871e33a8e0c6191dfe9631e05f8207d17a5a7ea4b24b64d536799a8e9af1477c1da4789d88d8b4ec46c5eaee3c9da66d88d8b4ec46c4dc3699b62362d3b11b1370da66d88d8b4ec46c4dc3699b62362d3b11b1370da66d88d8b4ec46c4dc3699b62362d3b11b1370da66d88d8b4ec46c4dc3699b62362d3b11b1370da69d88d8b46c46c5d6dc763699fb698dc72ef44d0ce56c80b41a21665369706e104d9963c7a3c85abecff2f84e70687585474f46805d77394bb1da5051ee25f080d361607c7f3785d5b3236c2caf84eef0b709d7738f242fb188444a70c7706dd2d4c88fd16d8b1cb8510acf2d19862b384e8c83c851b17672319be839585d096adc725a312c7b599362362d222254f64dd15bde6369976290ca5b863f0a1d8c6ae967cc46bcb662d96badd398bddd7603bcb7b76ff1775e8931636e34576b438598daa36591ed6376b85b8d05c19f2fe1c92f63b1a7c57922dfb9ec567ce198ec194603d8cc9af90c82c02adf6bc5ff00298bfed85232718f8c88cffac17cd6d7ec7d3a9a4ecf90fc42f82e7e28e36993ebdac1d3b50c07b9a27c788486481d45cc3c800d8b0478be415f40e9dd53a731f125e9cd2e76e31d05adc3931273b24818c680c710ee4b0b6887f823d6c103bec9e191db592b1cefa0702573b54e9ae9dd7268a7d6741d3f52961aedbf2b1992b9946f82e06bc94b7d99a94b7b72fe87ca3adfe16f4a7c70d4b4eea5c4d6b231e1c07bf0a5c8861dd1e7c2d75911b891c0717b4482c1b755f057d3b4cc4d6f133c40f7e3334b89bb228a31faad029a07af02bc95da6320c5c76451b190c313435ad680d6b1a0500078012bedf83fe5907fb409ccbb163914134eb9f734acf978c32e0ed17968b06c040cdc377eae5c27ee78527331079c9887def0aa524ed238db8b55678ec88017b9a390090970c2d73b614c338391201c82e347f1401b5dbc2f5f9aa3c9e2cbbf1030f1eab1cb845cfe6d75a0777783e8b498587c858dee26b6a67163c30c6d01ca7fd8f80e5d210b03ad439f1b54ded976a4607173194d4a8e57c6487faad2f78dd75c24baa470e296911899f1fbad3b792b0fd85e1d4576e26edf2aaf864326eae17247238f0714f1a97270a4c2239a591f0107c2f54ec715cacf2e035c2c2ec4351ee7567a6f639ba2692352d444725885837bfdc7d3f15f458a28e189b144c6b18d141ad1402e0f4de31c77e492d34edb4eae38be3f685e85795adccf264af447ada1c2b1e3bf560b9faaeb9a2e871432eb5abe169b1cd208a37e5ced883de7c34171167d93352d4b1b4bc3395945db010d01a2c927d17e56fe115d35d53d71afe89aef4ce939face991e",
            "39c276363c4647e3ce5e5c4b9a2e83da5a3778f92891c2e9455ba67a5b25b77d707eb5f291999989a7e14d9b9f95162e2c0d2f96699e18c8da3c9738f007baf3ff000fb49d5f42f86dd3da3ebd3f7b53c3c18a1c876edd4e0dfd5bf5ae05fad2f11fc223a6ba8faa3e12cb85d3704b9734197164cf890f2fc889a1d6d0dfe9104b5db7d76f1cd225cd183eaf879989a861439b819516562ced0f8a685e1ec91a7c16b87047ba6bd8c918e8e4607b1c28b5c2c10be1bf0321d53e1ffc2ac6d37abb1f2b1b272f2a5cb830dedf9f1a076d00381fd525c1cedbe46ee402bee3148c9a264b19dcc780e69fa828d53e0d38494549ae19c3d4fa63072e273b1636e34e3905829a7d885e12481f14ae8e4696bd84b483e857d69783ea0c4946af933881ed84b87cfb0869342f9fbd7afa0d449b70933c3d7e9e292c90479fd88d8b46c46c5ebee3c6da67d88d8b46c46c4dc3699f62362d1b11b1370da67d88d8b46c46c4dc3699f62362d1b11b1370da67d88d8b46c46c4dc3699f62362d1b11b1370da67d88d8b46c46c4dc369a762362d5da28ed15d6dc767699db15abf6cb4a70610ae63242c391b5113e5a966329fdb20ab069f552e8d3e45c2762d4d11bf922927b641b5763093c2c4bdce48fb17edb77584d6bb68aa4bd8f0784d730b9beeb89b39a2a8448038f092f883930b1e3951f315cb175d8e192b1420dbcd25bd841f0ba51b4067ccafd98dc394f369f24f2ad70725a48e1341e395aa4c668fd559dd1b815adc999dae25376d3c27479040a297db280c20a34988b68d63246daa4bef3daee12b6a9a77a85c5b51cea4c6f7240448d716b872083442d235bd463650943bfd2682b1d9229528df8536465fc48be64a3fc2cb6467e6e5fcb913b9cdfea8e07e4167d9613f66ef2101b5c2e454952389b7276d938ef6c4773bd13a6c864c3e50b34ac25b412e26398ff001c2c38a7c9c91957030f07809e1e368b5218d772aa2173dde3859b47216fb4f69b6cf29b067bdffac2955b8bcdbbc297c71b45378597b59791efca716d0591d23af92aad7fcdca708f7f29490b6c010f16abbe369e4a820805a0acefc495dc8f0aa4bd48db34fda5a5c28f85ba3c86399c9e5721b0ba31cf94c6df92694714caa4cd6f9097fcaa44c5a3e6496cad68e792a923fb838528367a4d124ee6148eff00f211fb02e9af2983a949838ee899135e0bb75927ff005e8b58d7a7ff002767e6574f2609ca4da476f1ea2118a4d9de9238e68dd1cac6c8c7705ae160aac50c304422862644c1e1ac1407e4b82ed7f201ff00e599f994cc7ea02e940c9803187fa4c374b1f66c9574722d5e37c5997370fab34dd572333a7e4c3d4f1329ddc930b52c9922303e837f45235afa61ab2c2de0d907e6a1af43d3f5a8f272353ea0ce8e4cc9da236e2e239ff66c763492368772e79bf99e40ba680001cf5a3cbc595bba39d8e1fe92a4fa8e1e3b497ccd27faad36570ed937547339c52bb19362e364edfb463c536c36ddec0ea3ed69cbcebba866de7663336df16e368fe50647f9347f995cff0065c9ec703d5e3ed67a25c8ea217a3b87fd76ac7fca1c8ff268ff00ed159b3b559b3b14c0f858c04836095cb8b4f92335268e1cba9c72838a7dce06c46c5abb451da2bd8dc78bb4cbb11b16aed14768a6e1b4cbb11b16aed14768a6e1b4cbb11b16aed14768a6e1b4cbb11b16aed14768a6e1b4cbb11b16aed14768a6e1b4cbb11b16aed14768a6e1b4cbb11b16aed14768a6e1b4dfd9f64767d9743b28ecae87987a1e5983b1eca4446fc2dddbaf453db15e3959f30d2c662ec02aa71e8f85b7b27e8ac23fa84f3079660ecfb29edd780ba2d877780ac600d1c859794dac4636b69bc84821c0dfa2dce68f448319715148d3894f95cdaa4a3051f0b4b622d29c1808e56b7d1870b39c22797526985e16c2d6b39a5424b8f014ded954284b603564aa3e1b3e13e9e0fb2606923c26f688e09980c1ec8ec7b2e808bd91dbf65af30cf9473cc35e8a44608a216eed05531d7a26f2eca307668ab88079216e11023c23b7c784f309e598c42d553073c2d9da3f4571129bcd796636e36ef2acec5681402d65b5e14867164acbc8cd2c68e7fd95e3c27b1ad6000f94e24834025be37386e09bafb976d12eda470b3be1dfe15da1c3cab36f725d0ab330c42d174824c62805b4b8dd7a20b1a4eea4dfee3698a285ef7d90b7b63019b4a0015f285258f3e1472b2a8d195f07cdca4be104f0ba9d9b6f279493051b08a61c0c4dc32e36a0e2b81e070ba2d701c268aaf0af98d13cb4ce58c6757850622174ddc0e024ecb3e16964661e331766c7855ecfb2e808ebd14f6afd15f30c3c673bb3ec8ecfb2e87651d95af309e59cfecfb23b2ba1d947653cc1e59cfecfb23b3ecba1d9f647654f3079673fb3ec8ecfb2e87651d957cc1e59cfecfb23b3ecba1d947653cc1e59cfecfb23b3ecba1d947653cc1e59cfecfb23b3ecba1d947653cc1e59cfecfb23b3ecba1d947653cc1e59cfecfb23b3ecba1d947653cc1e59cfecfb23b3ecba1d947653cc1e59cfecfb23b3ecba1d947653cc1e59bbb68eda7d22974771dfda6731aa98f95aa82ab80a5370da29ad07d15c44d3e8ab60390f928584b654903dbb0fca90f79aa2981e49e558b1a45ab75dc518cb5c4a6b2127d138017e131af0157264da84f6abc855d8b4b9c1de15405370da8cce889086c40714b51af0a00f65770da23b614b63e568a0aa68785370da2cb3d954b1341e55a87d12c6d102357105f9e15f7529ee0ab4b6551453b21aaa621e536c10aa5d454b636a165a3e",
            "8abe027020a870692ad928cc413ca8dae3e56ae0714aae17e15dc28406714acd6d0da9955f7a5b83daeb0976289300a4b7b05534729a25374e439c01b0aa6c5212c8dde084cedd0f0982415e159af04a8db148ce06d7784e61047852e009f080434708dd8a12fde0f0a8370f216a0e0e52768e1370da6231baec04f8a89e55dce15412092d3c056ec550f76c07851b41e52d8d713653870a761564062b6c5715568dd4a58da536046c4c24151bc04b1b514d88d9ec996a411ea96368ad88d89dc2824296368ad9eca76268215a87d1370da23b68eda7d2295dc3688eda3b69f48a4dc3688eda3b69f48a4dc3688eda3b69f48a4dc3688eda3b69f48a4dc3688eda3b69f48a4dc3688eda3b69f48a4dc3685a8b4282b2689552a7d142016f1612c7ba750b54732cf0aa214355c281baf8572caf0861a345504b4168e55a94921dc2ad9685017dbc70a68d2a35c4a636ca852aa7d149042a970aa4050bf955dc0a827ca59b06d69203c3800ac1e1c12439ae6d5aadd1e14a039d5f54bd8e2784005cae1fb072a908dae0afb6f854126e3e15c150142ddbe109828faaa1f3c2149ae146ea0824a96b6f92841649be14d93e426500a0aa0cef6971b0aed8b8b2ac14871ba56c1431da9dbb472ae4d1e141f98280a7705d151c13c292c6a80295216e415241772806d587014290d68ab2aa40bb56bb3482d34850b6915e1435a4bbd92cc6e0777a2d111616d5a8f82a5656f9a415a0323faa5492471f0144ecbb451dd5c2b35a48b2aec918e6da53a5dae35e15e494585dab73e550480f809ac0e7f002128072a549616f950a0056b5553680b5a2d42101368b508404da2d42101368b508404da2d42101368b508404da2d42100282a108405345423781c214aba828ddc2b117caaed54846e45847aa8a5413614d82abb4151c8405b70078570fa16928bb4a163fb9697ebcaa6ea56dc4a50b25cd1492eb09c3dd0e6d844431d383b84e15ea82d501a7d5680cdc3d149692aad14530935c2c94a001aa49b455a8aae4a02390acd3c72825ae0a0040581e558154236a8b368071aa550d4bb24f953b883ca50b2e6804b3f55725a54717ec80a904aa0dd699b8046e07c2a423613caa9149809a521b7c952c0b0452b345946da3c20f08507b76f21362fd2352aedbcacaf9dd1b8ed3c255953a34e5bcedd8c0b9a2595afda09b5aa2cb61e641ca0b2391dbdb56b4beef0c3e7942db2ca0f24a9901037b8ad7d9022bf5591d1c92123d1134c35421b9043e815625ef78a3c2838925dd784d6465ac36395a6d7a13934c61ad68f54f665b23078b5923dbb289e52dcd1b87d171ed4fb9abaec743ed3de3c0a0ad5c2a40c8fb740f2995b782b1c7a1688b42a170ddc2b03615325d0aa85688590aa84a0590aa84a0590aa84a0590aa84a0590aa84a0590aa840428ba42854805d6154a9a4520004856dca8a501357ca8a42940514936821400a805149802820202a1b6ac028f0a5404a826d16a5bee805b85140e558f955aa5417f9479505d7e150f3c26441beaa17b90143f909ddb24f1e151edd8ef994b2d08a2ac2c70ace95a3c0503e6374b442cd04f9438205842842294116ae8a540ba4169faa6d2829604ed72b014ac8f2800153bb95154a100eae2c25bb950260d34530b98e6db4f2b3ca3629c287090f86d34ee0ee506f70fa2d274668c6ec62ef014b61918415b0bdad70b5595e0f0c3e55dccaa286452b4336b8ab47ccc2bc2cd1424bec95a24959033d2d61ae7836be26f0d8de6a82a4d0c4d612400b8ced45cd1719e52fedb939276925458a5dc6f444e1cc98edf08121aa2b5b63b886e16e487639bf1e57326bd4e3699303de5c083e16b965739807aa46d640cbbe52e398ba4bae166af92dd2a34b01ae53c784b6b814ddbea1659281085084250a10809428420250a10809428420250a10809b4284202108508014a808250022d421504950a2d08426d08a4202542853e10a0a7d1429be10051a55b2a77d28bbe501376845a10157378547120709d5694fe3c202f16511c10aef95930fa2c4f7868f0a8c79f44d9ea6b77a1abb7cda681c24c4f3e0a702864951e4a2d0a0250a2d4a005051684041503852854105d6aa7d55a941080438171a5501ecf54fdaa08e296ac857bdc5156eefcb40251681e54b0b47054a46ac54bbcf858dcf958e249f0baa5ad23859e78416f85b8b465d9899a9b9836906d565ccef32bd52df006bec85a21c66385d2dd45724b6f8320739a471c2e8412b43381ca548c6b3e5a511068779f0a3e5157075f1e46bbf5d59d4e269721f2bda6da55bed5236a971796fb9bde697425f21dcee15831ace02ce64739b77ca6c44f92b54c968d4c16139b235bf2959c128e6d62859a1c413c28556ab28404210a90108420042108010842004210801084202a84210582108416084210808421002147952801429505012108084285285282808f4404210124f09449f5572e5156552892c0e436201d653800145127d92c50c6e3b88042bf6c8f2a619b9d87d16a70696920ae272699c8a2999886814aa682a10e0e2e3e14feb0b0b465a050a14ad180420945a00b535c2aa8b280b28f2a14a005054a90384288736caa88893e1690c07941786b687956c5156376f94ceceff4e12c3c11cf954764bd8d202cf2fb1ae05e5628078e52622220414c1905fc3bcaaba324ef3e16d5f664e3ba28f607f34b3be3da7e55bb7348da12fb74eb5a4c8d0b6476ca2ae18c0daae55cb803c298d966d4b2311db21decb4b1a00099b01560d011b2121cddaa38278505aa5a2964b65d4a84",
            "280108420b0421082c108420b0421082c108420b0421082c8b45a28fd145aa425084250045a10802d08425004210940108425004210940108425005082a1010541b534a7854a5394cdd4a436fc04899f42bd54efc15703f746c6efb090ecab3f29e16099ef70a078558839be56943d595cfd0e9894be82b6fd8ef6591b6de7d133792b2e22cd45c0f21176a91d16f254f00a846590a2d04aa64142148abe50a14ae29a39504b6b82a8ef1c950a58b813c25ba4ae14aa3b92ad12c9321f44b7175da606f0a0b4fd15028124ab38d8a2131ad416aa4e4c85843ac2b6f791b6b85a368f0a430056c195b1bef84ed8edbc95a03420a960c85ae1c527c629aa4b45ab05182c842140415284200b4210a80b45a10802d1684200b45a10802d1684200b45a10802d1684202c666552a0e5276d14c0fae14aa2dd92a6d07955b5485ad16ab68b4165ad16ab6a6d01368b508541368b5084008516a4025400a6d4f002a12809428b53c5a0055256b644d22d5dd0348e42c6f46d419cf3339bc049712e3cfaad2f8dbbca0c6c0dbbe56d34669995b07a94c663991d4021aea7d38f09a72db1f0c46dfa1a497a8dfb196b6dde1672ca750512e7c8e007a2d58a192b6dc42c7295b3549f08ca3735c9a0df29f911340b6a402070b49df261aae092a2d085a3248504294280a107d154593ca610a295216b14aa69148a528b645d15712b0714a85536736945b1c4827842966cd9c9e554f9e1441852951746d49702785484da845a09401480092a3d11b88f080b1b08b51bad16809b45a842a09b45a842026d16a10809b45a842026d1ca845a80b2156d46ee5016b45a8b4202794070079505dc2a9e5010542d2c85ae0ab247b3d14dc8bb58a078529ac0c228f9557c65a784b5d834510acd6da90c24d52b64a2884cedaab9a5bca5a144528516516a909b536aaa69002b07802941f094f054ee5ec3c1616f9e546c2b332dafb3e16c1234051f06bb942c212dc9e65690a1b1b5fe0a5fb8af6327da6588d02695d99af71da4a66446c60af5594c6d22da7957865e51b283b9b59de483e551a5cc144ab8a239f289511bb10f27ca815b6d3f60aa5431f2b662c4005c69497ccc34cba4fd95e159847ea908d95148a794f0eb2b635a0b777aa228595654bd9b7969e17136af839127ea0e14dbf54b56ee871a283b7d15461a2108566903cad332b92bf7a1492d3e14200428b45a002aa6fc2b5a38402c30ddda60f08b45a003c8500529b45a0250842002a1168b400a545a2d0136a6d56d16842d68b55b45a02d68b55b45a02d68b55b45a026d0a14a141429a2a4349f4404215846e3e8aaee0d25968afaa9b5162d343016d851ba1562fbc58fbf45b639a27b3e63ca53e289ecdad3cac9da747279e171f123995a3498cbe4b62d422f946ef28c731866eb16972ccd91fb5aef0b0db6e8d524418c35e0fa261d95e550d3a3a27959dc4b05157b8aa264976848eeba4e12ddb9cff0064cdbb0585cc92470be4b01f553c25ee3eaa5a7e654c8e6c65c535f110ce0219281c57298c9439d47c2e272672a8a321691e551dc15aa7dbe0158c9e4adc5d9892a2af78540e7135e8adb6cabed0071e56fb19ee4069af2a7b8e88583ca5bb702a0dbf8528b60f91d2793e528c520f09ddb2d1ee8dc7c52abe04f995635dfd24cdbca8325f015b758a4e4161482028570db43252b8487920d85b3b448e12a481c072a5a354ca1cb0d686da8664b9f62d67309ddc852232d3616b6a1b98eb3b9358093488887704279a68f97cacb75c152b23610394b7d5f054b9ce297b1de4a8be21961e15ad5002a42a649420a85484a141b08b50128403f553b820210827e8a02a09bf745a141f282c9422f85165404a14052a9010842500421094010842500421478404d1578da5cea501c02aef736dc1659b46c11504c6c600e573a3cb903fe6f0ab3e5b9c681a0b1b657472268d934ad8ddb5bca86b5b2b7cf2b1c720736dfca3bae69b6957692cd2e6322fd63ca86cadb2078594b9d21b714d85803a9de156b8e489f3c17746e680f0555d23e46f039548e47914e4e8e48d87e6f2b3d8e431643a789b409169303e6fd7b2ba7246720d01c2abe11137681cad292aa26d7dc5b72b680e79e551f97de34c553872486cf01363c3ec1b213eea1f786318765faa901c5dc8e13e36122fd130ec028f0b1b8bb44ba0b6d84a0dda6d34e4007682aae91a1a772a9b32d213349b458597ed4f2681567ca1c6a92cc600b0b912f732dfb0c0f95eeb253836c7ba4b1f4df74d63bd55664b9000431a4926d43ded2a8e790de0ac946bbc78b540edbcd231b21a24a9470b4ce617d6cafc14ba74cd55f2640f25cafb6be62105bb7901417d8dab5f233f32281e4200e548f955aefc2a65a046e2141348b07ca110d8721adbdea93646f34df0b3ccddc7e550df94529b57737bbd068702adb5a7c2a376d72ae07d109dcadf6cf0b4c1b6404faa49682129d376be56f9597cf636b834b86d7d9f0a1d2b7d127ba5edb72ab5bbcf0554bdc8dfb0e2f04708690e1eea366d3ca9750fd5420c6c762d50800a82640db00d2af247288326ed145555b72d180508b537615210a545a8b4059428b45a50250a2d16940b2156d16940b2145a2d012855b45ab40b2156d16a02ca145a9b4007ea82e0680506c84b21c0a946d31f244045b879595ac0f347ca6c7338bf63870b58c70487b162f6f7392afb18cc342ad486ed0b63a0738d80ab262cb5b8354530e2666b49f44fa6f6c0be5058ed9c34dac6e6cc1fb8daaf922e06c249e484c7e297383ae95f20b213f2f8",
            "4e8a66cf1f0790b0dbee8e44bd1966fe8182b92a9b8496e3e5265c92de0f8591f93b5c1cd4516c3951bdf339adfb967399def96f9094d9ccbf2fd555b852364de3c2d28a5dccdb7d8d31e4ba2e1de12a7ca2ebf4b547b24be47857871bbae1bb85692e45b7c14869a77b94cf20908af0b54b8ed0dda3d1622c20914aa69f265a6b828768e6948b72b32224d3937b5b7ee5bb4718a6b68f29cc8ec155dbf4552f70348f908b96579296e3cd3559a4bf82ac21734d953b772fc85380d9eea62b68e4a6981efa2021b8f26ef1c2968d24cd31b048db252e489b1bb75dacf23a584d7202a19cc82aed6545f72b68d20b1fe4aaee0de02ce0393005c9b4e3722e5d6a2ad583784388038420baa28b03d15bca152595e0f84c610de4a59146d55e491c28d1a4c73e4a161652d2e76e2aed70f0e4ca14a7635dc50e78f44d69ed0b52197e1416ee76db4bb212642ef099035ce753936189ac6d944cf6c6ddcde161bf446d2f56363959bfb6eaa533b630cb0b9524a6ec792a629a571dafba4d8fb95c9761e68a8e2d340657954701e8b767134428b2a7706855f2b48c9642aab03f542021048f45540590aa8541642aa101642aa140590aa8541642aa1405903940a2a4d00a15051bb57dcc8c5b85aaf7016d24bec8e567b9c8b835b7b528dccab5d081ad646391eebceb25304b60f0993679636daef2b8e58dbe11cb19a47a4a00583c2589632eda1dcaf3ccd4e5747b49578e793707d1a58f29aee6bcc47a1da3e81737501b08d815bf8ce3118fad2545309e5224160a918b4ed95b4f8454c25e087a4b2330b8869f2ba52441a2c95cd9449bedab717665aa20c32104b8584b6e339cef1c2d51cb2d86b9bc2e908da23dd48e6e24514ce53626c4de4514c64cff0051c26cad64ae35c24ba4646d2c29765ec124ad2e029439e47ea25b4075b954cec6b0fd56a89674202c7b2deee551cf81aee69711b3cfdd3e76ad81ae97909b29f2c9bacd6fd8fe5897b5d5f32238cc42dca1cf2f770aaf81962c9a2afb370ba4d8b1f77254b9bb5d5e8ab91144406906c266e73e81f09cf8c066e1eab23dcff4513b35546b190d6fc815466b6226c795cf2e0d164f2a048c7b8029b10de6d9258b2010782b3b200c713e899f650ea746e4e95bb630df544eb8446af9625cd1e8a070a0077aa0ae5470b27713e157d54a15a258052a2d16809001349ad841f755644e7785ae02c8ff00f8a405c53957639611bee637e3d9ba54208207a2ea4936386ee69056090092dcdf0b31937dcdb8d7623b8d68a54dc3c859df65d5698d700297228986c939847ca52e498b9aae71c4843bc296c0cba253ee8e4ccd25de56b6b981be395474618a8daddcad3e4ca7430924da90ea08b691c290014207936a54eda50784202116a2d5324a145a2d281285168b4a04a145a2d281285168b4a04a145a2d281285168b4049521c08e555438150d228e710ee146e24f3e15eb856645bf808e9155b314e08161622c9247eef45e81983bfe571f2adfc5e19c053cd48da83671218de241b870bb4d745d9d807a254b0ed14024b65630ed3e4ac37bb936bee96fb302e26f85a58c6b5943ca88e27c8e001e0ad8cc3707024f0b8e52f7349181d9af758712ad16436edc9618c22cf959325c40a6ae4514f831b9ae4e9bf363f000437531b0b485c16b9e1d776b4465a5c0bf85a789222c8cd7265900ed1e56092491ce05cb78ed1aa00ab0c7121bae115223b62a294060b3cad0dc663c87949762f6dc0fa26092be50547f02a7ee5a6c76b4580971c8582805a37ee686946d6345859f832fc843f2091454349b055bb05eedde8afda0455ad704e46b25b140f8567cadd879e567edba3e42a10e25676a65dc0ec890bb68f0a407b9b64296b5a0ee2ae5f629aafc89f330bd84bb955735ad6923cad8e6023dd6773395c89d987c0b872a48da45ad30e4979b7acc63a7785602bc055c511499b1ce69e5a976494b69238570512a2376590a2d169464952d16556d1bab946546bdc636f1e4ac393dd90d03e530c8e3f82587bb7d9584ab9396fd088a19036894d76f6368283310e14ac5fbbc29c8b429b1b8f255fb6d1c94c0fdadaa49792e2b6ad997c1265ae0257cc5dbad05a50095689b86727ca82db2a45a954cd900529f1e14da84213bca2ed422d28a590a2d16944250a2d16809428b45a0250a2d16809428b45a0250a2d16809428b45a0254171254214a293e54173986c145a28b8a045c64ca1bb8152cca95fe4aa815f22b06ed2b89a47326cbba7045149740c91f6d3ca24da1bc794a8c48c3b81552f62b97b9d184ba0a5a24cca8edbe5735b23de2dc94e948752c7976f92efa162429a18241caa8605706bc2ec57b1d74ca7d9983c84b7440f013892556939162d80b1d56b6365daca480d0a08b51ab2a743dd3efe12c8ae555a294dda94371009bf2ae1e7d55691c2b42c7094f80a79bbb4a0420b8a9b4bb8d1dce3955739a470905ca2c83c29b46e2cedca1a6905cab56b544b2dbf95620116a800536944b2bb514ad68b0a908014a8b45aa4250a2d16809428b45a14836145f0adf7a3850b654114acd700a080a292858c041470abe029b528585051b54a2e95210a5422d5a21285168b541285168b404a145a2d01285168b404a145a2d404a145a2d504a145a2d01285168b404a145a2d404a145a2d4048560e0070a968b468d596dc6ed05d7f7a8b55a528b615cd92aed78028aa512a0b794a165dcfe29a95e793e55c0014116944b26d16a10b6649b45a842026d16a10809b45a842026d0a10809b45a842026d0a1080945a842",
            "026d16a10809b45a29084b0b45a11482c108420b0421082c2d08a508526d16a10809b45a842026d16a2914809421084b0421082c108420b0421082c108420b0421082c108420b0421082c108420b0421082c11684520b0b45a8a42149b4284202d68b5542026d0a1080fffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080100010003012200021101031101ffc4001b00000202030100000000000000000000000002010503040607ffc4003a10000104010302050301080201030500000100020311040512213141061322516114718191153242a1b1c1d1f02333e10752f11624254362ffc4001b01010002030101000000000000000000000001040203050607ffc4002c1100020202030001030303050100000000000102031121041231412251610513328191a11471b1d1f1f0ffda000c03010002110311003f00a826946e439212beba7ce07dc8dc92d16807dc8dc92d16807dc8dc92d16807dc8dc92d16807dc8dc92d16807dc8dc92d16807dc8dc92d16807dc8dc901b4134500fb91b925a2d00fb91b925a2d00fb91b925a2d00fb91b925a2d00fb91b925a2d00fb91b925a2d00fb94836b1829da801c90a772428052545a0a55248d68b4968b52303da2d25a2d0607b45a4b45a0c0f68b4968b4181ed1692d1683064be507800df5ec90917c28b50306568738d36ed413469345b433707b9af078a1d9622509c0fba905d6b1da2d081ed1692d16a4607b45a4b45a0c0f68b4968b4181ed1692d168303da9052260a00e13b5204ed504039214ee485008521590f5e5213d39524a111682949a5248d68b4968b4247b08b4b6a2d00f68b4b7c75e516806051692d4ee4035a2d25a2d00f68b4968b403da2d25a9b4035a2d4388bb68a1c7e0a0bf70038e3e10609e9611692d169803da2d2da2d00d684a0da60840c13848138420709da90276ac48072429dc90a010a429ca42b2250a5239394a50c8452d34e048dc07247ba9d8e36435d4393c288a37cb208e305cf71a007742523675181d8d91e5ee0e6ed696969b14402b5543adae21d6083c828b48ac2c12fd2549496a6d490386df7afba83c1212dfca8b403212da2d00c84b6a79ab404a12dacd898d2e6e4320858e7bde780d165437859612ce856dba996d1b88e4ff0094d230b0d17035c774f958b26386f98e05c78205db6bb15803e9a5bb47346cf50a13ced12d634c970dae22c1a3d47750a383d3f9a6607389da3750248f8eeb2230421677450bb14ccc9489049b7cb71175479f9e9fcd61009e8a13c86b033413dba2cae000e843b8e2fb29c601b333cc00b0f2e1c7216deab978f97333e96211c4c1b45b4349fbd2c1c9f6c609c6b26904e13321f41738d58b6fca50b2c9834384ed4813b5418839214ee485008521595ac2fbaedca96c4c3e979da4f424f013383248d72b2e3e23f2678a2b637cc3c17380e3f2b7b4cd1e4ccc9f25cd34e8c9691d3a706d74fa5e93a3b36634ed8dba8401afdd30731aea37f655eee546bf36cb1550e651cba3cda66499193331a7c5d9bbcd1c135763a8e2bbf0b4dfa4f9b8f2648cb3364b1e018c4761c79e8ebe94d5e81e21c1d4a6999262fd3c91cad6b246399c3c11c9771d3e3e173ba86a6fd01e717034fc6d9b5aec90597640e9cf5ab776eea9d3ca9d8975f4b565118b79f0e4b5478766c9ea739d677135d6cfb2d3b5b6e825c97cb3904820c96c163aff0025a9caeac3cc1465ee42d16a2d1cac8c49b52393c9a4b68b40307106c7545a5b573a6e9627c68b2617365c80fa30b9869a3b7dff001f0b09cd416599462e4f08b6d03c15166e2459da865186292f6c2283deeec05f5057a17ff4569aec08f11acb6361316f01bbb9bb23e6c93f16b6717438f2311f1663db92e04189ce8c0f2e87047bd11efd96ee9580ed2708c2e99d39692edeeea47b2f29cae74ec7952f1f877e8e2c60b0e278c78bfc327c33a8f90c984d0b86e6b8f0e1f055241933633cbe195f1b88adcc3469753e393fb535bf3d824679be96f9bc0146badd0e9d3e5727231d13cb1e29c38217a5e2c9cea8f77978d9c5be2a363ebe197272a7cc95d34ee32487f79d5c9fbac57cf443242c2689008a347a84bcab096348d2f635a2d2a60a481d801345db47babac5c5c6fa78636be69679c5811b450f5104f3db8feaa91ad2e20004926801dd5e6852f973ba476f7f95096889c0d3c3b823ad7176169bf3d728d95fb86669304e744d8e28d85f0fa4ee14f02cf603b745074e632095df4328745c0a24ee37cdf1ecad3443893e74d78ef921dc5eea3e969239dc076e07549aa6b471b6c4d7301a205740d1c7200ebd47e153564fb748a37b847af6672ef6398e20b4b7d81521679a5395b8b58d680ebe161a02b9b57d3d6ca524304ed4813b50c41c976971a099c9a31ca30886c527fd600f51fd56f8c5392e8e2fa76b9cd1d5bc0febd52363dfb48dc0823a2b7c185e2563dc1bb41edd7a559556db30b259ae19d173a0e2c98f2d16b9b1b636b5a1c6f9effefcae8b0b4fc57bdf33f198649406bf7804903a03fa2a9c697cb682477a5bdfb57e9a5fa67c2e9247025818090e1f26baff0065c1bdce6db4762aeb15b2d24c5c5d4666b7cd2e7c1b86d6915447423fa2f2b7689accb9f9d7899003eee16b89f305f1ea3d458ebd4f4eebd434e8b121cbc9931e0113a4a2e7347a9dcf5e78a3cfdfaacda8e1cd9b3c4c8a72c1082e3b87ef58fd7db9fbad7c7e53a24e2bc7f7fee6cb6856a4dff83c2d90e546",
            "c96363658de010f6bbd3c0ed47bf2162c37c4d97ff00b86ee8c02368ea49e9dc74ebf85d96bfa66b7aacd9f912623360792cf29a6886ff00151ec6c73fd9717362c904ad8e66ba279fde12348dbcaf4d4daad8fe7f0716cadc196ed8b131320641f31ef85e2706521de637a81dbafe7a7b15519791266e44b31e6dc5fc0aa04fc2b48b132b54c5746ef57d23418dcf35438b681ec01baf854af6be170208a2382de8b2a92cbdec89f9f82370db5b79beaa39abae12dacb279cd6343c16b1c0102a81ae87f9ff0035bcd78271d82595ad32323bfe27fee8fbaebbe9ceb3a8629825831b4d2e8a273a3029aedb41c6e8d9362cf4f9e8a8e3d09f2e9f2e4c2249cb3f8da2983af1cf37c13db80b5607c98b893b5c23a99b45afea288a23e79fd156b12b3717b5a374330fe4b47bb0d574ed31f0e1cfa8465ef03ca0e75b8b7a593f7ee557f8cfc510e81a6b2464edf36575358db25ede6e8f41f72bc64499d8af8f218d9e06ba9cc73aeabaf04f6e2d265bdd3ee7bb2bcd03d41bcd024d9a1db92572ebfd1a0a6a529657c97a7fa8c9c5a4b06f66eb6ccec8c9c9959219a52e78739c0fa8d76aa1f7f8ecaa9efdef2ea00b8d9593270e7c58e19256ed13337b383c8582ff002bb55c2297d27324e4dec9068abb6f87c4ba5b7518f371a46bada620eff91aeabaa558dc7272236796f3e600e0d6037d2f8b5d547e1e764c18afc282680073a391b236af804927dc737c57e169bedeb8de0db557db3ac9cd0d2b35d04b90dc6798613b5ef1d2ef91f35f0b6b487e09832a09e17be59233b0d93468d1007706bf17eebd0bc3de17c7c7cecd8713cbdadd81af95a4b9a78dc2af9e3b102ff0b3e99e068f41c8c999b262cec9086b46433a77b007caa167ea75ee2ff18f82cc3853d35fd4f29762cb1c4d95cc2184d5d77f657ba76b8f85ec1001e738865003679639268f7e3e38fd56aeafff00e373a581b1462378dcd6364dc1a493cdff00bdbaad4c5c8983666421ac64836b8d7ee8fbabf24ad865a2a27d2584757e11cc88372f1f318c81b338bd8d2ce1fcf4ddf07a2a8f1160b599d2498ed9e48fab9ce0481f63ed76baac5c1c6d5b458a3c5688dad600e731f6f0eee79f7feeb461d0ff0067c32b65702f93fe3b24d96d707eeb9f0ba31b253f1fd8b53a9b828fc7dce531985d13c1b00d73ee1061f4db4920f42aea4d34418be53dfe66d36dedf821553848c0448050a1402e842cecdb4529c3afa6beda4cd43abb21ab71a583934695c9a350fc08dfc476ee9fcd5b46c9a46b5b1bcc7cf24006c2a8c7fdf039e55e611268742a85ef1b2ed5b3365c2d6e3c96f7ff00d64c6d31921a6fb1f73754aebc14669311cf99a29aef2e3e3f84743fcd6b189b911363780f8efd6cf71edfcd5ee047242c643080d634b40dc2e9a3b71f1d172b91666bea746987d7d8b77bdecf2f60690e346dd47f0bcffc75ab6b7a6e54ad8b22f0dcd203c0162c8e2c77af7fbaef5b3c3339d8e6511c8d01d562c0146ffa2e67c658c3271e7640e2ec87b4b0137b1a6eff0077b1a6ba9df15dd55e0c946d5d964b1ca4dd6fab2bb45f1747269acc78315cc7bd863f3dcef5743c937ee38e7d972be29d6067e410f18cc0d6b5a444d3b88ea2cfbd1a3468d2aed4f3db067bce0b8b23b1fba36ed3c17015c1177faad09f31d2ef6b58c646e23d340915f2795e868e1c633fdc4bd3916f25ca3d1b2cb275f6bb4f8f0a1f318c029c29beabebcd77fec3aaa9c8cc9f2435b2bcbdade1a0f46fd876588a5eeaf42a8c7c4577372f4dec076297b7cd68b24306e6d8177cf039e7fd34a278a7d3e49985913a8805d41d5d7a7b7e3d96935ee8dc1cd71041b04762b632b39f962e573cbe9a3f7b8342ba7d804717dbf04a6b0775a66a7fb47c3193ce3c4e964647334bf8200a1fc4081445f2475e9cad8d5f45d37134781d8d8ad8daea95e4b43b69dbc117cd5fc73d2d70589a848cc09705b33d8d99c2da00a23dafafff000b6f0f56cec56bf1cc7e7363616b3cd6d989c0d87007a11cae7cb872526e0f0b39c16a3c88b5892f836b52c9967d3dd0cf0c90b0c80b585c5db1d5c920fc1f7f65a3a1b313ebdae9f21d046c1bc3dcdb048e80800f16b772359c7c56b72f1dcd97324e6464ac0e0081c3a871cd91efc74f6adc7cd123ccb34ec6132f9cf63996d908e6a80efedd39ecac4232e8d6306a935d93c96de259f07231aa09fea6488b5a1d18a6301b3c7bf4f8fb05cd03cf3ca798bbcc71dbb58e25cd0010daf858d6fa6be91eb935593ecf25fe9593999397a663e4c8d6e3876f63ded069a0d5fbd0db4bd6a6d4a1c7d2f28b4091b8ed22375025cee4922bb0e39a5e20ec86b98c6d1218d2c0280e0927f3c95d8c4cd4e5c28752648dc581ac8c410bb932d10038d7239e2c8ae9eeb99cfe329b8b6f1ffa5de2dce29a5b2c3c2fe290ed78c4eca926391920b6c0e5a5bd4d771fca96ef8f758ca8e2d98b13de1b28707bde0f41ced6f5ae47f55cbe9d88f7eaf2e6c3911c1958c0c81cc69631eee49da2bdbb745bf9f93fb70e2614b233eb36ec7cbb9c3a804dd0abec3f4b5a654415f19a5a4b664ad93a9c5b397d467cdd4de32a7885b8916c1c70076edd96fc6e7e8f2c032b1192636d6c8ef47fda38201bee0f5fb15632600d370e17c3533a3ff8df086dee2e3764583543f97cdab4d2e497528d91644709ca0c7c721737a47ee2fb922ba5f03df9b73bd28e97d2578d4fb6decc7a03cc625ca111931d80b990c6de5ae22fb71d0ab99d91bd86402fcc01c6ff00de15862e0c7a3e94c81cd6b1ad04bcb88e09f73dd56e5c",
            "f03222d8a463bd2480d20934b96ecfdc9b712ef4e91c3287529238412797006bbaa0965f35d6eae7ad2dac89a5c8c97b4bad975b81e9df8f7ecb4e68c37236836074a5d9a61d5619ccb659f0c4f6ed50d4d2256ab48acc1c9a34ae4d1f550fc08de80389abda3dd5ce21f29cda6b8b4f53ecaa71ba857787d950bd976945be29642649a4906ce01be8d56387e21d3bd5590d706d926fb57fa155539cd2d21c226b0b9ceb144fb7e8b4fc2b8ad933b31f91144d1196c965b5b6bf1db8268fbae64aa8ca3294be0bf1b251928c7e4b6f1665646743883498a69a4739c3cc845eda1cb4df17df9f6f955be38d4668a01a7c990c63e18b71ff008c39d27422ebf77e474a5a593e2466932bbe9479b1994cb2161b05dd0923fb7db91d4d5ebde259fc4190e7b8c58513a2a0092e25b5c8b1ee4717f0b7f1f8b2528ebe959dfc9aedbe2d4b7b6554b262bb19c5f0874af66f2e616d32ef8f7ec38ebd5539eab2c8035a1a0d9201771fa7f54508c1734dbda45383bfb7f75dc847a9cd93c984f5fba83f7595e7cb78313cf4bb1dbe1613d5668c484071160006c7b2148db4770375c5292478321d8d3b6788d3da6c71c044923b25ef7bfd523897175f5f7588906a857bab4d3b0e3ccc1ca7371e57491b5b4e63b81d6cbb8e9fdd6136a3f53328a6f4552159c5a6e2ba184cb9ac8e59640cd8470c6d1f5937d2e968887fe40c73d8d079dd7c57ba9534fc21c5a1371756e24d0a167a04e2190d911bb8a278f74b218cbffe20e0da1c38d9f957ba467ba2d32482295ad99d26ef5ca23e0348bbbe6acd0fbf558d9371594898c53786546345e64c1b44904703a9e7b7caf5178645a1c791a86cf38c16c7440be38768696b07b120f4e9777c2e2f272be9f48c5823c685eec77132643646b83ac820537ad13dcf2ab72b5ed4b363745365ca63710e2c069a48ef4a9dd54b90d35a49962bb15395ee4bb9b5ad2f50888cac099ad6398fdb0c803582aaeb9b278fc95d38d5f4cd6b270f1b159231cdd81be53776d1fc408ea47df81caf3163b69e6cb4f51eeb3c39b363cfe6432c9173ff00eb76d35d2ac7c70a6de1464be97e78630e535e9eb71687a4e9d9a62745e6bb25cd0f95ce754a1e7a8aba1dbeeba1c7c7863c46fd3b1a368dac1d6803c0e57949f156b52e001b1ccf3006196c90e6914d1f7b07f45d878034ecbc3c49df90e748c91fb9849f4fb58be7f3dd71397c69c21dec96ff00e4e9517c652eb08967afc1f53872b448f6d0361a7f7b8e8579fbdf287dc4d7b0b5c5af156232411609e9d3a2f42d6b29d8b16e6c124dea036b47cae527fab74f91396471736f2de4900700ff00459f064d47661ca8e6452bf18e230d18e9c6c00289effe16acfbbf880ba5924d5659f3fcb7b7630f001145464f52baf15258ec7364d3f0ae93aa56a6912b55b5e1558394b0d150e4345f0a5f811638879ea0abdc2ecb98883a38cf3c3bb83d15ee97e7894073b7461a0127adaa1c88e9b2e532de0ea30c070008b0adf171620d21b1b79147e553e23b6ed27a7bab98a49632dd91ef69f6eb6b857673a3af560e4755f0e40e7ccc931b3192892839ad05a633c9755fa8d9bb5c4e4e952bf33322c67473478c09749b831a403562fe57b5ea6d7ba063bcc6c2070e344bb9ec08e579fe998d06951cd0c9878f9b03e839f1bb965f207a855902e8f4e4ae870b992e8dfaca9c9e347b2471271dcf8a496efcaa0431a481f73d1639d9182dd9235de9e4f3c91f75dd6145a435b1e13c6fc6c873dd3b5fe9e806df50aae6fdfdbb2e4b5fd37f67e6b8b2464b1c9eb6c91b816baf9e2bb0bafc2ea53c8539757a29594f58e4ab7020d11494a63d529570d04282a5414248565a1ea834bc9739cc63a391a5aedc2eb8eb5f955a858ce2a4bab26327179467cb984d3b9cd2ed8090c0e3741751a7784c64e93f57a887c1e5c6e2c00b5a5f601673cdf5e95efcae561c77cf7b2b8ffdc401fa95d3c3af66eab85162e39d9950b1b1b6e7ade4771640e82be3f455b93dd24ab78fb9ba9eb96e473d9b832604823998f6b8d905cd22dbd88056b7759729d219dde648e91c0d5b89247c72b1056a39c6cd2f19d0ed739bd09080a00bbf85210c59213c6d73de18c69739c68002c9295a2dc0581f25753e06c1d332b598e1ca9499b7111d7ee9e3a8e2effa2d575aab839bf833ae1de4a25d7853c21979d8b1bce7cd0c5331ae7c45879f51ee6ba73faaf42c785f8e4c565b146d0d632874f75a1e27d4d9a2e2c32b431ad8c971639848736aac57b12debf2b52199bade83183a8be1c977aa42c21aedc458baed5f85e56e9d9c8c592d45bfec776b8c2afa23e96399b48e688ecb9fd4e06cad7023837c7450dd659a94be56319ddf4be904b08f34f4dc4fb0239ff6a8754f14ba1d41d8ce8d9e5b1db5db0927f5ff00795bf8fc6b3b617a69bae8632cd4d43001c963c5f03b740b4727d24d9bf6565913cb3381680e89dea69e86be556e47ef915cd72575ea6f499ccb12f8345e95a9a4ea95aaea2a307296f214392ee23a29211b318e85cdb163a2e834a076d9aabe2bd95060bb7bf6904ae8f0080d6f6f854b94f582e51ee4be877790eda4876d35b459fc056f8d34a1d116d3626d994bda6f81c52a9c4b15c917c0aedf2ade3825742e6c333a37b87a5c46e0d3ef45706ec7c9d7a8d8d5fcb8b0679dce97d11bac31c77511fc3eceba20f65cd62eada4b72220c7fecd006e9db93ccb30aa1f9b3fd574300ce7ce60c8c76cb13cd5968dad37c91dfa1e3ec9b27c27a7cf96ccbd8f64b103b5cc201fe76b557642b4e33ff06c9c25",
            "37da2799f881da73709b264e24d1673a591cd782688fe1039e9c8edfdd722f73e425ce25d542caf41f17785e28f224c887536cde73e9d198f718857637ef5cf0b97c18861fd562676df241f58f32adc2fa7cf65e8f89747f6bb45e7ffbf271efae5df0f45194a566c9646c9ded89c5d183e927b8584ae82792afc90a085285249148a5284067c598c5badc00dbd08bbb346be6bfa2c45c1b5b4005a4fabdd2a146379190249364d940ea842903296f5e7a250982103bd8637969bf717dc76579a0b19a74833652d6e447200d63de0168e2ddb7a9e0f041ec7e15135c5ae0455fdad75da4ea1a76b02766b113a476c06330b6a8807970e3a7c76fb2adc96d43ccaf936d29397e4f53c27e36a30451c8d6c8630d7b1f45cd71ece04ff4ecb435ec5930f167cdc3876cd4038318dbda0d761754495b5e189b1e7d3719b0c9903c86ec2d97826b8a23b8f9ff0014ac5cc787bdce7704f0dec02f1ee5fb7663edf07a1ebde0713a469396c74997337c92e68744c2eb02faf4ae3e08fcad5d734cc07343a4819e60e847049fbaebf2c9b22b8aeaa8b506d87501755cabd55f294fb7854b2a4a3d4e344992d66d9230c2492df573575d3f45a665f30383b878eaae337143c12fe5dcdd2a7c976c7101bf75dba9a97872ac4d1a6f1c92a1aa5ee04f0a1aae22ab07286b6ca972967081131b9b0c81cedc5b77c2bac7d631e111873c1dc79f854f2c05ccddcf1ecb0c1038c8096d869b23b15a6708cd6cdd0938bd1de62e789e164b8ed127967d5b5dcd57bf6e69757a6070859bc538f2e17744f34b8df0cf901d24ccdb1b4802b6800fbf35f6e175ba4e7332a1f3010035a0b8f400d2f3dcc8e3292f0ecf1a59db2f62ec9a620b1ed04d86dd0e4fe8b566cd8f130df96f23cb6377937c114a30b508b508e2c983798e58c3c3855007dfff000b95d1ff002f83a1d97868eada089f0990e2ce3118d3723ab702c1648a3d895cbf8afc2cdc8c78b63618fcb717cd2114da342c1f727faaf416c8c7d8638123b5f4fbae5bff0050757fa2d28627d219a4cbf447ff00f2ef7fd3fa85738775bfb918c4afc8ae1d1c99e3b9f28c8c93b62630f4a6106ff4eeb50820d11456de460e56108a69a17c61fcb7703d8f7f6e415898c7ce36b21dcf164b859247caf631692d7879e69e7660a4db0ecdfc55d7517fa26746f6b5ae2d203ba123afd92f2565931169149a914a40b48a4d48a402d22935229010a42290028048eaad7419278b5581b8992f63dc45968e0f7239a554130e0ac671ed16898cb0f27b3e4c7068faec39d0e4c92b6461f36089b7600a0eebd2cf6fd159ea5e22c6c48629031f2f9bfba1bc58f717d7f0bca713c6fa84784dc29c3258c3766f20efdbc71d7915dbecad5de2a933b4a820101c5c68080f9400e2eae9563bdf357dd79db3f4d9e62e7bc6bfa1d78f36387d745c47e326ea1a9c58ae85d1b5c6e89693d38be781d4fbaddcb91af66f69b6b8582b9bc43a6636a2dcbc473bc978d8f0e8c122fb0ed478edd0fd95f66be37bfcb6cd643482d6f3ff00c15365518c9745846309ca49f67928f5299b131c49e9d402b9e9e6124c763edaacf54c1f2e003cd7c843a8179e79eca85a363cee041f60babc682eb94ce75f279c31ddd784354570a5aad95983934695c9a350fc08de846e15647cab1d370d8e99ce91a5d4401bba1e157e351701dc2bdc2eca8dd269172a592df130e33008845196eeba2280e7afdd594536163cb366091afc98e2d8fa77e688e80f0b530ba0b5b78ba0603a67cae87ccf336ee6bcd8e070b8b64965f66752117aea8c7a8b7f6bc78b8997149243248000c2431d7d0b88baaae2cab1d1fc3d2e9d84dc61992b63049318a20bb759366c8068f1f29751fae7cac662c38f3c0e779727abd71b4802c7cf5597741a1e4c71b276b60dad6180558e3871b37f14abca7270518bfce3dffc37c6294bb3fee59b3163b12796d8de40ddb7b9f65cd6a9910e9b99e76acdf35a1ee6e282db2381cd9fb8b5d3e3e40c88849b4b413c5f71d8fe8556ebcc832063b0c10cf339c5b197004b6ff7a89e838e7dd69a2589e246db56639471d9b8fa7eafa213a86a421b0c6c71c6e6fa4827d240e4f51dbdbaae2a6c48f44ce64e5cd9e2f5b981a6c023801dfcbfc7bf75e25f0be3e9f8b973995f796f748c87ad10091fa0be9f65c6e8fa7b751d45eeca889733d723001440ee458be9fcd7a2e1ce3d25252fa7ec71f9117d926b654e566bf2378918c7121a03a85b40f90395a94ac73a1c48a664f8eef36094b888cf0e6806b9f6beab49f4e7bb6376b6c902ec81ed6bab06b1a4519673b31d2294d2296660452294d22901148a5348a40452294d229010a422948080c9139acb2e04b80f4fb5d8ea3b8ab5b4750cc9e230bf21e63ebb4f41d07e3a05a416c478b34a490c71f735dcf41f72b1925eb2537e22df4c1369c049961d140f2083fc55cf2d1f859f3b537e3e7372a094cb0936d278b6f71fefb2d5c8972b1c7d0e6974a612d223b2457fedbeb57ec7fa2d13b2495cdffa59c90d759dbf0ab28293ed236ca7d57545c64ea126561ee7168bfe63fcaac95c1efbddb800003492273a52d89c69a38b5b4e6321696340247b959c62a1a46b949cb6cd72eb4350e14690d5b51a98390d247443933003d54308ddc691a002689f856accd8e06073890dee551b5ae69e4583c0a5750e1b67c7f29e0906be0feaa9dca3eb2dd4dfc17da7ea304c4ec738bdbd18dea7e6bbaea713a05e6f89a6bf4c93ea1992d88ee07869a636fbd9fecbd1b4f91b2c4c91a438380363a2e2f36b8c771794",
            "7538b36f52f4df8a06b5ed0236806f90688ffc9f75adad46e8c8c863e304ed67fc9c36859a27b59a5bcc78685ada90fabc67e31631ed78f5070355fe57320df64d97a49752974fd664930dd266c90c3135ee2c68939d82f8af7ebc7d967cad674fcac7c7cc735e3ca91af84d38970e2cd37eff003d1553bc3adc781d2ea4f6386334ba270141cf239e3dbff2b774cd0a78217372f20999a4163b7021ed16769e3a593c7cabd38d3fc932b46567f168e2bc61ac64b75593231a6c98b1e570682c71693b476e2ab93d3df9eeb278299fb570f334e0c8239a500372b600f8da08ee39be7f92a9d625fdab9423c781c035e5a775176f77502bfc765dde91e0ac2c28e49219a66092168a7badb64724fdb8f6e8bab7ceba68507a7ff450aa32b2d725b457b749d3e3d127c266343973c71bdac99ed3b89aa268f4e87a5d5febc3eab81169b132131b84ee077bb711cdf4da79a15f1cfd97a1e6e5e6e9b872e9b063c591144e779a48dad00927817ec79a3fd579967e6cfa864ba79e4323cf73d87b2d9fa7f7936dbd7fb9872fac5258d9ab4a29321758a02d2293f15ded42016914990805a452642016914990801b40f20d2dac1cd7e365c52ee716b0825b7d40edd56aacafc77c4db9016d805bf2b1924f4c94dada2ff33538f3e130c6f73e69dde697001a184914d3fa7bd72aaa2736091dc35cea35b9a7d43e3ee16a35ee613b5c79e0d7161586990479d901b905ce6b5b540f27d9695055c5fd8cdc9cdfe4d898d403c860f5004923b8f6ff007b2d1f35c5e5e4db895924c995a7c82f919134fee5f214b181efde386f6bf65315d56cc24f3e084d8b286a6912b56c46b60e531ba8a8729675ba47e046fe38f31a29c47b10ad609dd13776c73c776d73f85578ae6b5b63a0f60ac239f7b0ba3918e00f0db209fcf6546d592e56c5cdc76ea79d141f51b016d7a8d55d7f6e1749a5c0ed0b4e77d23e49da09731ac707fe38efd3a2e4747c17e7ea2dc9924698e37dd5fabdf95dab325ac25c08dceea7dd53e5e5255ada2cf1f79997706799e164a0d07b038023a5a66e5923d4e6dfc2a5fadf949fb458252cdfea22ebe1737fd3fd917bf78bb194f3b839dc706c7f31fefbae43c54ecc9b25a66cb3362875fd3b46d1190d2438bba13d7aab4973f6c6e3bab8eab8fd56493508e67f9b1b090d2e6920971edcfdbbab7c3a313ec57e4db98e0dfd134193eb25ce732e1b25a496b6c036071f1dd7550ea751c9200590badc4d1278eb5efd3fa52e174bd632f134cdbf52d0c043434f26acf1cfdfaa48fc432e5be3c7c82c8b1d81c69838bed7442b5771676c9b9788d15f2230492f936b58f17ca35195b8d660f3048093eb69160f3f95ca4aef36473fbb8d9ecb365868c89035cd78dc4ee68a05622050afcae9d34c2b4baa28d96ca6fea31d2293d2296e358a412a293d22900948a4f48a40252293d22900948a4f48a404c32185c486b4d82df5341e3e2d6cc52e348eb9e2e0021b1b5c40e7e4dad5a452c5c53254b058e4330a22e630b5ecda5ed2d3dfdacfb557751a76b1269c1cd8e3653ba9e6fbff0095a0da0ef536c7b2858feda6b12d93dde728d87c8d9a7738d80e3c126e90c751ab2b0859015960c1b325f254b5204ed43107286f254b921348116104625141f47bd765678af7631db5bd9d39ec3fbaa2c7976583c5f52b6feb0346d2416814ab595b7a2cc2696cb4c4cf8d9bc9a6f3c90281e56d0ce0e6db5dd7a15cbbb24c9297500df6287e53dbb8349a70ae0ac1f15379325c8c17526b6d645212f3bc701a0f5f958a4d7af159b1ce327727b7de9511e794b4b6ae340d6ef91d245a8fd4c2e717b039a06dee42a4cff28653cb77511efd0ad71605026906cf525650a541e5112b7b2c31fcf7f96e6301683d6bdbfb258aa2906ee9de9473f2a296dc235f62677892691edba738904f54a0071e4d5a9a45291914f27b28a4f48a4232252293d29a41931d229640db514804a4527a452919129149e914832252293d2290644a4527a4520c8a98229480a00c13b5204ed504039210b2116a36a0128a7dc6a91b51b506443ca293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d40252293ed46d402009da8daa40a407fffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003011100021101031101ffc4001500010100000000000000000000000000000008ffc40014100100000000000000000000000000000000ffc4001501010100000000000000000000000000000004ffc40014110100000000000000000000000000000000ffda000c03010002110311003f00a2d7a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001fffd9",
        }),
    },
    Pizza = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc00011080200020003012200021101031101ffc4001c0000020301010101000000000000000000030400010205060708ffc4003f10000104020103030204040601020407000100020311041221053161134151062214327181072391a115334252b1c1d162e1437273f125346382a2b2f0ffc4001c0100030101010101010000000000000000000102030405060708ffc40033110002020201030204040602030100000000010211031221041331415105226171328191a10614b1c1d1f023e13342f152ffda000c03010002110311003f00f8aebe14d7c236aa6abef2cf4f503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08faa9aa2c3501af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c3503af8535f08daa9aa2c350faa9aa31629aacece8d40eaa6a8da2bf4ca2c3501a29a2388d6bd34b60d45b45344c68a6a8d83517d14d131aa9a2761a8be8a6898f4d4f4fc25b06a2fa29a23e8ab44ec3503aa9a2368af44586a03453547d14d07c22c3501aa9aa6355344ac3517d15e88fa29a22c3501a29a23e88f8b853e6e5c58b8d197cb2bb56b47b949c9256c7a88e8b631a6737611bc8f90d2bea5d33e92c2c08da5d1b72271f9a67b6c0fd07b0feebae709cd35b3abf71fd979d2ebf9f917ea77c7a09b5f3707c53455a2fb0750fa6b1339859978da3c8b6cad686bc79f3fbaf9cf59e8b91d1ba83b1a71b348da3900e246fcff00ecb6c3d64724bb72552febf6396781c129794fd4e2e8a6898d3c29a785d9665a8be8a6899d14d1162d45b45344ce8a688b0d45b45344c69e14d3c22c7a8be8a6898d3c29a22c3517d14d131a29a22c3517d14d131a2ad1162d4068ab44c68a688b0d45f55354c68a6a8b0d45f553547d47c29a22c3501a29a23e8ab44ec3503aa9aa36aa6a8b0d40eaa6a8daa9aa2c3503aa9aa36aa6a8b0d40eaa6a8daa9aa2c3503aa9aa36aa6a8b0d40eaa6a8daa9aa2c3503aa9aa368a688b0d46cc5c21e947b2705fb8456c2d705cfb5793a75106c767b22886d3261d7d9506907b24e561a8030d2c3a35d1111732e90fd204d29530d4434592cf0ba2e8285d201673d95a9d86a281be16abc23162a0d5762d4186ad6829174f0a687e14d86a2e59e1675f09ad0fc2af4cfc2761a8b6aaf447d0fc29a14ec3501a78534f08fa1f857a1f84586a034f0a688fa1f857a1f84ac350018a6a98d0fc29a1f84586a2fa2f7bfc3ae98d965cfea0f682626b6161f82eb24ff00415fbaf17a1f85f48fe19ccc30753c17386f6c9dadf902da7fe42f37e23371e9db5eebfaa3aba58aef476f73d739a6081cf32b991b0190d134285dff0065f3a9febfc8766b9f0e046e82f8f55eedc8f927d8afab64608cde9f910089fa3e3732490721a08217c7b23e85fa8a2cb30c785ebb2e9b2b1edd48f9e4f1fbae2e8fb1272deacf5facef2aed2aff007f33e91d21eefa83a747d431219a61234970a2e2c23820fe8579efaefa5c72fd3233680931256d1aeed77047f5a2bd77d3dd05dd17e9cc6c59e789c5b6e903241b389367507bf71e385c8fafa58a0fa4278d8d737f1333236071b3c7dc6ffa7f75c79326b9e0b1ff00fa55faf3fb59197fe4e95ca4d3fb7bfafa9f14d14d135e9953d32beaacf0b516d14f4d74b1ba5e7e6103170e69effd8c2576b1be87ebd3f32411e30fff005a400ff416571e7ebfa6e9ff00f2e451fbb45c714a5e11e4fd353d35f46c6fe1db010737aa58f76c11ff00dbbff0bb18df45fd3f8e017634990e1ef34868fec297879ff8a3a0c7f85b97d97f9a368f4937e783e422324d01cae8e2fd3fd63305e374dc878efb7a640fea57d9b1fa7e0e20ac4c3820ff00e9c601febdd305bb72e24feabc5cdfc62fc61c5fabfecbfc9b47a25eacf82e4e16461e43b1f2a07c32b7bb1eda210745f41fe20fe18e4e0c4dafc531aedebb86923507fbaf0fe99f85f65f0eeb25d674b0cf28d397a7fbefe4e4c989424e285b4f0ab4f099f4cfc29e995e8599ea2da7855a26743f0a687e13b0d45b55344c687e14d0fc22c3516d14d3c26343f0ab43f08b16a2fa78534f0982c3f0ab4f08b0d4068ab5f098d0aad0a761a80d14d7c23e854d0fc22c3517d54d51f43f0a6853b0d406aa6a8fa1f85343f08b0d406aa6a8fa9f85353f08b16a03553547d4fc29a9f84586a03553547d4fc2ad4a2c3507a8aecb4d8c15bd4ad34149b1ea321a88d0428c1c",
            "f28e22b16160d9d1a96d8c39aabd0a36891b5c1d49d6639737958b96a56a23600aa4178e784fcb8e1a802025c8525e43502d6ecda284f868ae81c5706d842313c8e5a9a92f40d4e77a66fb2b10b89e0268c676aa4e4113072e0adce913a9cdf45cdee15162edbe38dec3439493b1feee14c725f91ea23a70ab5f6a4ebe2d50c455c957b06a2858556899736d568aac5a80d15e88da2bd1161a80d15e88fa2bd1163d45f457a2634534f09586a0345d1e8bd4e7e89d5e1ea10343cc669cc3d9ed3c169fd92da2bd14648c7245c26ad3e06a35c9f71e97d4b03abc0dcae9f209e30417c4e34e8fc380e47ebfd1393398e99ce6b2360f66c77a8fd2f95f08c79b231261362cf24120ecf8dc5a7fa85db6fd61f53359a0ead21ae2cb5a4ff5ab5e04be1fd441d639292fada7faa4eff63d3c7d74e3f8b93ead3cb0e2e33f272a6663c0d16e924343f6f93e02f91fd57d78f5eea60c3b370b1c69035c289f971f27fe29239b9f9fd4a6f5b3f2e5c87fcc8ebafd07b2574f0bafa5e89e39acb99dc9784bc2ff002febfb1cfd47513cfc3e11d3fa63a341d5baaba3ca2ef4226191c1a68bb9000bf6e4afa2e3748e938841c6e9b8d1b87fab4d8ff575af9b749ea13f48ea0dcb81a1fc16bd8eecf69ee3c2fa97d2b9dd3fea56cad323f1b262e5d070496ffb81f717e385f25fc52bad84bbe9bed24bc3f0feabfb8f068953f217676bad9d7e3d9402c868164fb05ea99d1fa7c2d2e7465f42c991dc2f1bf537d61d04742cee9dd172c7e31ed0c6c9046437b8ba78f17cafcf316679a7ae38b7fd8efc5096596b14358b1bb35ee66216cce61a7063c1d4f9e785d38fa0e63f991d1c63f5d8ff0065f21fa75f991fd51d39dd3896e499dad1afbb49fb81f1576bf40cb2c5044f9a591b144c04b9ef7001a3e492abafdfa69a8c5ddfea6dd560ec49453bb3911fd3f00ff3677bfc3406853a8c1d3ba4f46cccf38ed3f8785f202fb772071dfcd26b0fad747ea1318707a9e2e4cbcfd91ca0bbfa2f3dfc47cd18bf464b058df2e46443f40763ff001fdd737478f3753d5e3e9e77f334bdb8be7f63867b45727c265324d2ba595ee7c8e365ce364943d135a7855a05fd189a4a91e66a2da2ad133a785345562d45b455a267455a22c3516d156899d14d1161a8b68ab44ce8ab44ec3517d156898d15688b16a2fa29a263455a2761a8be8a688fa2ad1161a80d14d11f455a2762d406aa688faa9aa2c3501a29a2368a6a8b0d406be14d51f45354586a0352a6a8daa9aa2c3503aab0d45d4a9a94586a301a1198ed452ad55eab17c9d1a8c42e68fb884d7ac2bed4833e13f89859598ff4f171e499df0c6dae7c9ac56d3748a51337b9e560901dc2f4d87f4865c94fcec8663b7fd8cfbddff81fd57a1c3e83d2b0a9ccc513483ff8937de7fa761fd17ce755fc41d1e0e20f77f4f1faf8fd2cd5616cf1bd3ba7676791e862bdd1fbbc8a68fdcf0bd1c3f4b63ea3f17359ff006c5ff93ff85e88926813fa04ee3f4bcdc8a2d8b469ff00549c7feebe47acfe24ea327e0a82fdff0057fd91aac515e4f0bd73e99e9f0f4e933305af89f0d1731ced8385d7bf63caf2a2025b6bdefd6723b01ede92d903b7636491c055f2687e9c02bc607340a5f5ff0001cbd465e8d64cd2daddabf35fed98e48abe05446583943ab722c85c5f43b2d881ce6d85f4375cb33d451edf74071be135330b7840d56d116a03557a2369e15ebe15d86a07457a7846d3c2d69e12b0d4068af447d15e8958f501a78534f098d16b44586a2fa785619e131a2bd12d87a8be9e14d3c267457e9a5b06a2da7857a784cfa6afd346c3d45b44df4ecdcbe95d421cec390c73446c1f63f20fc82b3e9abf4fc2cf2463922e13569f0d06a7d1feabfa95bd4ff8770e561174472e76c13b41e5940b9cd3e0d0fd42f96aebe1ccd647361e4ec71322848077691f95e3c8fee091eeba03e84fa8a5746ec3821ccc69407479314cd0c734fbfdd447e94bf31eaba0c7f099bc6dd424db4dff004fbafdd727d2fc3ba8c51c7ac9d33b7fc2c97ffc5ba8c1e8b0dc0d9049a8d9bf7555f7a37dbc20ff00133ab644dd6e3e901c598b8f1b64737b07bddcd9f9a155fbae57f09f2beafc5fe20f5de89d5fe9c762e1c71932643e3734c45a7f96d0ff00caf0e049e3e2fb2ed7f11303e95fabf0e7871beaac2e9fd47d2f44caf79f4de2f86977606cd77f7a5e04e3187c4b69f2a972b9ab5e78ff007d4e4c7d6432e7967c716d2bfd52fdbee7cfe295cd7c73c1296b81d99246ee41f9042f5bf5675a9fac743fa7bf10eb9ce3ba5978ab71716877ee197fba4be90fe0ef5fe998c307aae641145ea17be48dfbd035f6b1bedfa9f75bfa9cc4ff00a8f260c6608f1b16b1a260ecd6b06a3fe09fdd7d57c2160ea7e231789eddb4ddfdf8fef7f90badea639f0c2d54bd7d6be9679bd3c2ad3c26fd355e9afd1f63c6d4574f0a8b3c26b455a23616a2a59e1569e135a2ad13d83515d3c2ad3c26b459d13b16a2c58ab44ce8ab44586a2da7855a2674f0ab4f09d8b516d1569e133a7859d3c22c3517d3c29a263555aa761a8be8ab54c6aa6a9d8b517d556a98d7c29a1a240343dd161a8beaa6be11f555af84586a03553547d54d5161a80d54d51b55354586a0834285a11755354586a1b553547d54d16766fa9ee3a4fd2fd3a0c5866cc88e4e439a1e43cfd8db17543bfeebd0b1ad8e211c6c6c718ecd600d03f60bc7f4dfaa9d8d0418d9b8a658e3a6fa8c753b51e0f0480beadd260e91958516760eb931c82db23b93fa57b1f0bf1ef8f7f3dd3e4dfacb69b74fd3febede",
            "4e84d25c1c18b167963748d8c88da0b9d23b86b40e4924ae2f48fa97a167f5666164bf2206c8f0c8a5d468f278167bb6ff004fe889f57fd76639f33a1f4dc68a58c35d04f3484f7229c1a011dbb5fcaf27f4674cc6ea9f54e2e3e56408db19f58328dcc59cea0fb76bfd015e662c5278259732d555aaf27ab8ba55da964cbc71c1f6e830b1717fc985ad77fb8f27fa94c2f0bfc40fa9f3ba3b71fa774e90c13e4b4c8f9c7e66b6ea9bf049be5789e8df5b75ce99d42393273a6cdc52e0258677ed63dcb49e415e5e2f8767cf8bbc9f9fdce7c5d164c98fb887ff008824c9f56cda9fc9146dff00f8dffdaf1c4b815e9feb0983feacea5abb6025d41fd000bcd11657eddf06869d0618bfff0031fe8798d7250714c452d0a410158057aad261a97332cec97d134492296744d3a0d4068af447d15e89d86a003168311c315862563d40062d688e18ac312b0d4068ac313019e168312d87a8be8af44c08d6833c2563d45b45af4d3023f0b5e9f846c1a8b7a7e15fa69911f857e9a5b0f516f4fc29e9a6bd3f0afd3f096c1a8afa7e17b2fa27ea03d3f2474bcc900c498ff2dceed1bcf9f607fe7f75e63d353d3f0bcff887458bafe9e5d3e5f0ff0067e8d0d468f65fc48ea79a7a5e4f47f465831240cb9dae734bf9bd5a476edfd8fb2f8fb3a7ff00358fc8ccc8ca119d98c95c3569f9a68167f5b5f69e8b998bf52f4497e9beb2e73a42dfe5c97f7380e4104ffa9bfdc7eeb8c7f8599df8cd4757c7fc2dfe731bb7affe5ed7fbafcc31ca3f0c94ba4ea3e592fdfeabee77fc39e3c5192cf2b6ddae3d3d171e6bea7a2fa1baaceefa0dd9598e2f182e918d73bdd8d0081fb5d7f45f3294ba69e49a4e5f238b9c7e4936bea9d6f1717e9efa0dfd3705bac6ea8417777171b738f93457ccbd3f0be97f8471c5c73f55154a52a5f65cff00739733539b947c3629e9aaf4fc273d355e9f85f77b18ea27e9aad137e9f855e9f84f616a27a2a2c4dfa7e1518fc2360d450b16744d962c96784f616a2ba2c9626cb164b13b16a2a58ab44c962a2c4ec3515d156899d15689d8b516d156899d16744ec3517d3c2ad131a2ad1162d406abea3d2a1c68fa362b7198c30be2692751f79ae6fe4ddaf9ae8bdd7f0e1f0cdd4733a76537d463e2f518d77669079af8e0ff0065f2dfc4f8a53e89e68bfc1cd7bfa7ede4b87cac6b27a0f47cbe65c0631dfee88e87fb71fd971b27e8a81d670f39cc3fed99b63fa8ff00c2fa7cfd0f0c91e9cce84bbb024107faaf2dd633ba6745ccfc26575289d35fdcc6071733ff009b8fb7faaf80e8be39d5c5eb8323fb3e7fad9b471f71d455b3e7f93f4af59c7b2dc6190d1cdc2e0efeddff00b2e3c904b0bcb2589d1b8776b8515f617432b18d91d1b831c039afab6b81ec41ec50a56473b349e364cc3ed234387f75f4bd3ff16655c668297d571fe7fb19bc4bd0f9069e14d57d2727e9be8f9364633b1dc7de1750fe86c2f31d6fe9e774b63322198cd039da925b45a7daff0055f4dd17c7ba4eae6b1c5b527e8ffcf821e368f39aa9aa3eaa6abdfb2350da2b0d45d55eab2b3a3503aaef7d33f51657d3dd4048c2e9312470f5a0ff0070f91f0e1f2b8faabd7c2e6ea7a7c5d562961cd1b8b0d41f5384c3d426787fa90cd23a48a522bd46924dfebf23d8a5fa67d55d13e96faafa4e6759966643ea39d70c7ea16f1ad917dadc2eacf85e83a37567f4bc8a971e3cbc379b971a668735de45f67795f47ea38bf48755fa7317ac4fd0b0fa8e3e011363c6606dc2fb1c01fe93757edc5afce3e2d865f0f9ac7960e58e5c269af55e3e8ff6f5fa1ddd5fc4a6ba6952a75e5f8af5e3ec25fc42fa5dfd7ba6b327a7e7c187d4a38dd142ec8786324be4727b1079feabc27d07fc2ffaaa2746dfab3223fc3b65125b6712b9ece29a08f9ef67b05e7fea79bab75febd9d3e6f553f8799e5ad89b10da28fd98d7df02bdeafbf2be8bfc2dea39319cce945c4e0e340d962613622a3543c11ede178d28f53d1f42e319a7f972becff3f61c71e558a3d445f0971f697b53fd2f93c9f5a7ba7ebfd42570a2fc890d7c7dc521aa6662659e494f77b8b8fee564357ec3d3c7b78a10f6497ec70ea00356b4460c5619e16d61a81d158623062d06784ac7a800c5a0c470cf0b4189586a00316833c23862d062563d4006785a0cf08e18b41896c3d40062d08d1c46b4234b61ea0046ac469911ad08d2d87a8b08d68469911ad08fc29d87a8a88d588d37e9abf4d2d83514f4d5fa69b11abf4fc2361ea29e9a9e9a73d3f0a7a5e12d8351785d2e3cf1cf0bcb248dc1cd70f623b2fa9f43eb11757c012f0dc8650959f07e4782be69e9273a7666474ccd665639e470e61ecf1ee0af9bf8f7c223f12c370ffc91f0fdfe8ffde1fe62942d1ddfaf262e3838808a01d291fd87fc15e27d35dfebb98cea7d59f931dfa7ab5ac07b8007fe6d734437ecbabe07d3be93a0c78a4a9d5bfbbe44a1c08fa47e1518d74445ed4b7f827b8580bd9ee25e47a9c9f4d58849f65d218876a21186286fb24f2a42d4e48828f215ba0691c04fcec1d820b59439429b7c8b539ee82bd904c6ba6f1ed497746b58c835122cf0b259e13663592c57b0b5142cf0b2589b2c592c4ec5a8a162a2c4d162c962762d454b1568992cf0b2589d86a2fa2a2d4c16785459e13b16a2fa2ebfd39d50f44eb1f8e6b049ac323753ee7535fdc05cfd1171748f3217cad0636bc17023822f91fd17275b8967e9b26292bb4d7ec54524d59cfceea19bd4f2ce5f50c99322777fa9e6ebc0f81e027fa3742eabf52654c308b247c7a995f34b54",
            "0f00f3c9ec8dfc40fa6b2be8be8d93d7b1c0ea1d399235ad6b496be30e340bf82351db6fd3e57bcfa4198fd13f8667ea38609bf119788335f1cecd5cd3afdac23e013fbddf0bf29cfd5c61d3ac9839b74befec7b793e21857fc785dcb8a547ade87d35fd27a06174c926390e823d0be8d38d93c03edcd0f011a6e9b853d97e3b41f96fda7fb2fcf391d6f27aaf509b266ea6ec9ca63fef2d96cc67e281fb7f45f5bfa4bea932fd1b367f599cb9d852184c87f34a28168f2ee6bf6b2bc6ea7e1b9f15648cae527e17bbf6f7383a8e96508f776bbf21fea18fa7742c0fc5c990fb71d638782e90fb807dbf55f3beb7d707538998d042e8a06bb725c6dce35e38a59eb9d5f27ae7547e6e47dadfcb1c60d88dbf03fefcae5ebe17ea1f04f8147a4c70cbd4fcd97cfd17d3eb5efee715301aa9a236be14d57d6593a8c68a688fa29aae6ee1d1a80d14d131aa9a23b81a80d5763a175ccbe8599eac3f7c0fe25849e1e3fe8f95ced15e8b9fa8c78ba9c6f0e65717e506a7b8cafa37a17d564f59e939cfc274c6e563630e6efef6db1a9f9a347baef74de8181f4afd3f9c314ba494c4f9259df41cf21a6871d80f60be7dd13ace5f44ccf5a03bc4ee24889e1e3fe8f95f44ceeab8bd47e8dcecdc47db0c2e696bbbb1c78a23e795f957c57e19d57499a187672c32692fd7c3ff00791cf2657158dbf94f90e8af447d3c2bd17eb7b86a043158623062d0623b81a810c56188e18b418a7b83d40062d0623862d0625dc1ea00316c311c46b6234bb83d45c46b6234c08d6c47e14f707a8b08d6c47e13223f0b62353dc1ea2c23f0b423f09a11ad08d2ee0f516112d08934235a11a9ee0f51511785a1171d93623f0ac45c25dc1ea28225622f09c1171d9588bc25dc1e827e97853d24efa4a7a497743412f494f4bc277d253d247743411317856195ec9c317855e9784fb81a80631a3929a866603a91c21fa6abd22a1b52f24b80e4b1425bb32ad2ef8bf964ad44d3b8b3c26fd3f50ea3b158396bea438d1c07c64bd69b10228aeb4f8259cd257d020f2b759935c0f539b2c00764b988fc2ebba1f94173180552d23945a9ca311f85831a7dedf8084635aac81a89162c96270c6b06357dc16a2858b2589b2c582c4fb82d454b164b13458b2589f705a8a962a2c4c962a2c4fb81a8ae8ab44ce8ab44f716a7d03aafd4b9dd27e95e93d4618609229a20c93d404dbf5a0281ec689fd97cd317f887f594737e1facc23ab634a4c738263644f8cf04f1f730d1ec01e42fa274fe96cfa9bf876ee966411cd8f29f49e7b35c3ee17e0ec42f3bd3bf86bd625ce0deaae831b1186dee6481ee78f70daedfa9ecbf214ba3e9f266c5992b8c9ae7cd5f15ff00469d2e1c11539e49b4dbfa70b8f1c7fdd9cf87f8351746cfcdea5d37ab42dc0c91ea99729ce0e8e3bda88039eff28195244dc78fa7e13e4385012e697f06479fcd211ec4d0e3d8505e9feabebedcf7b7a674f76b81050b6f6948edfb0f6feabca68becfe05d267d1755d6bb9bf0bd97bbfad7e8bea445c96358d7097a217d14d131a2ad17d6f709d4068a688fa2ad11dc0d475f086842d5306cf755a2f3d4e8dd4406aaf546d158627dc1ea043159623694ac352ee06a035478659a18a58a391cd64cdd6468ece00d8bfdc2b0cb44f4fc28938c9549586a0047655fa68e2323d9596a7dc0d45b45a0c47d168311dc2b50018b6188c18b61897707a8011ad88d1c316c314f707a8011ad88d1c316c46a7b83d4008d10468e235b11a9ee15a8011ad88d30234411a97907a8b08d6c46991178441129ee0f51511785b11784d8896c44a7b856a28225a11784d88c2d08c7c29ee06a282257e9784e08fc2bd07c25dc1ea84fd2f0afd2f09cd3c29a23b82a427e97855e9784ee8a69e11dc0a423e97855e927b41f0a8c7e11dc1ea840c5e1411278c61518fe13ee0b5176e3970e136c80c6cbf75960735d6110c8edb959ca4d994a006673b5fbbbae7cad73bb05d278f50a1321b7d1ecaa33d44a226c8f66d3927341ab8aeecb8ba0b0b9f34649b570cbc892394635831aeac38136459634060eef71a1fd5323a4e3fff001325c4ff00e867fe553ea629d2e7ec9bfe80da4e8f3c634331af48fe8f8ee3fcbcb737ff00a8cffc2e7e574dc9c66eef60747fef69b088f57072d5f0fea9afea4dc6e8e418d60c69d2c582c5d3dc2b5132c582c4e162c1626b20b5142c592c4d962c962aee0b5152c59d13458b2589f705a9ec7e829a999d8b5cdb241fdc1ffa59fabfea0b6bba4e0c9e321edfff00a03ff3fd3e579ac1cecae9cf99f8afd1f2c6632ef8048e479e1265a4924f24af985f0684fe253eb72f31e1a5f5a5cb32ed7cdb316d156a98d14d2fd97d4770d3517d15689a31f8582ca4fb81a80d569916c51355a163b2370d43065a2b6215cabd696c76a5c1b9b38817c607659d51cb6d4d11b8d440eaac31183158625dc1ea08351a302f95618ac3292730d4238b2a80402d04f08c1968ac86d4ef4251a150c5a0c4c98a940c4770b510218b6188c18b6189770ad40862d8623062206297907a810c5b11a388d37061ba46195f6c8877755df80b39654bc84aa2ad88b634511f85d36b208ff2421de64e4abb6d11e8c7cffe956a395abafdc9b7ec73c47e110469cf46390d460b1e7fd24f07f42b1a10688a2162e6d3d65c32949302181103110356c314ee3720418b4188a18b6188dc8720218b4188c18b41896e43980d16b446d16b4f08dc9dc5f4f0af447d15e896e4ee2fa2ad3c267455a7846e1b8be8b3a26b459d11b95b8b68a06f2982c592d4f71ec6",
            "0c635b086634c006a961c10a40a407d3becb0eb6f03ba601ae2965ccbe51b169fb8a39f21e095714024b925ff2dbdfff0051f8442c45906819176d459fd4a76e7258e3ebfd3d7fc7e64ceb88af530e76c458d5a3f2b47668f80ab8ff00711fa8bbfe8aec68468d27fddcdffcac39ed6706c9f81ecbd58b8628d55244e8e5c2b8d7dbfeff00736d63df7ab1ceaefa8ba442c9a06dc90bdac7f043d840778e52ec903cea366b8f9ee8ef9e79226c524f23e36fe5639e481fb2ce718e68eae9c4a942526d4aabf738fd4301b0d4f0ff0092f3dbfda7e3f4f85cd2c5ea5ac13452e3bbb3dbc783edfdd700c7cd15e7e29ca129619bb71f5f75e84e2be60fca122c582c4eba3432c5d2b21b6a2858b0589b2c592c55dc16a2858b2589a2c592c55dc16a2a58a8b13258a8b13ee0b51711d9a4ec588dd6dc821b46d18c8e2ca054b937e08944c498ec69e0da51d1f299f4e422cdaa734d729a9d094453455aa63555a2aee17a87d15ea8fa05345c3dc37d40e8af546d3c2bd12ee0f503aab0c46d15e896e1a820d57a23062d7a69770350218b60108818b61897707a9802f857a22b5b4881b697706a20031103119b1ad86853dc2a80b5888d62206ad86a9dc3845e3c0249834f03bb8fc0f74ffa93b087c7196c723346b6adae6dd76f7e7fbf942c567db31b0d76a0024d01640449c64e33df8731746e89ee0597d8f17ff0174744b7c8e6fd38fdbff9f959c195ca736a356bdff70346f5a3638e54a3568b2bdf33f77badce03635567e4fc9f2a83574e4ead427ad7836be393145c1c40e00b23e3ff00646ff3630fafbdbc38fcfc14170d5c4236372f901eda5ff7475cbfe3ee7aaffe33192708ddf8aafb7f7206ad862206ad862f277139030c5a0c450c5b0c46e66e408316831143168312dc87303a2d688c18b5a25b91b80d14d131a29a23716e2fa29a263453446e1b8b68b3a26b4592c46e3dc58b164b13458b259e13dca53152c592c29c11851cd6552372bb8205aaa930e6f2865a9ee6aa5605cd0b4ec5cb9e595f0e34b288c02f2c6176a2bde9596ac640710d9413da8f2af0e451cf06fc3b5fafff0009949a945afb1514a198ef61c48a46bcff009af612e6fe86e928f69d8dfca286bdc0ead7968ef57415b58e95c1ad639eef868b2bd7ea20e71e1f83a20e9cada16d4d8a4c3bf31fd5685412dba20ed4d16bcd7edc1b55239af90b99188da7b341240febca3063963e24bc94b229be0de3ff00f9967c5ffdae4c8cfe63abb595d68bec8e4988b0050fd7dbff00f785cf2d5e4e4c89f53392f4a5fa79230fcd9272fb21373160b13de98284e8e952c875d09162c96270c68658a9640d450b164b13458b258abb82d454b164b13458b3a27dc16a2c5aadac1b728fe993ecb26320aa5908946c658620dd4d2c3a063ef541f4dc42b1bb0d028fb330d698bc90963a90f44f3fee1cf741d11b9bc55a0daa2323d8a288fe56ec37b2e1dcda4bd81be2010f546e4a9aa37a08c5810c5a0c45d568354ee69a836b119b0ec385a6345f28945878ec9ef66721731107b2b0c4c3a9cb14a77293301ab61aac05b012dc1b29ad5bd69580b6025b19b660356c356805b0d4b721c8dc0db2e8ff00de2abe4fb2b74dbc8c7c8dd88018fe7f381c7edc28d146c2dc91192e48c7ddddcd1ff2b7e973c71647bf87ebecff00c3ff000716451d9efe1f046b23f4dc5928716be8348a2e07b11f3cf71ecb2e7061734b48703441e082807e0ff428f9192725fbc8c1ea6a017df2e238b3fb71fb5f75ed4b0425353ab2fe68b4ab65efc7d3edf70366c9e39ee9ac461a7be851fb79418a07ca7814077257499186b435a380bcef8875719aec41dfbff831cb28b7ac3f3fc8c86a2062d86a206af2f732720618b6188818881896e66e40831683114316c312dccdcc0862d688c18b5a23723701a7857a23e8af44b727717d1569e133a2ad11b86e2da2ad133a2ad394f71ee03d3e3b2cfa0e27809e6b5b545633a2f57a74d0c4f2c91c3821294da56913dd77426603ad8e478407b082b85f83eab07dcc8de4103ee610eb1ecb27a875083564ae7b4fb6e0d9feabcf87c4a12f4fd19d11933b458b05ab9aceb1213f7c6d23c2337ab4245bd85bfa72ba63d6e37ea6ca6305ab3428b48b69ee8e29ec0f6f20ac96ae872538d3f0696a4a9884b0398411f734f21083a8fe62dbe0d7c2e8904581d8ac383083710b27baeec3f10cb8d6b35b2f7f0ff31a9e48aaf3fd45ccb1c5207e1996375105c5c2cdfe815064933dd248e26cdb9ee3dfc9461a34711349f9286f739e289e07b0e02ac9f10c938eb8e3afd6ed8e3dc6abc7d5f2ff006312bdae688d9c307cfb940f4efb2216ab69ae57246a2a91d504a11a8823196ac96822d19cfd8d52c1015ec689bf516205ac98ef94c18efb2ad08e11b1aa90a3a3432cf0ba4c881ee852c43d91b8d4d5d1cf2c50313058b3a12780ab72e903a03d960d13d93262fb7b728463a55b1955b28358e200eeadf0060d8a1ea5a760afd473f872d148c9c1d81751f658d531a053450e66f18f01c8b5459699d14d170770ad85c316b447d14d51dc0d8068ac311c316b44bb82dc0861a529dd91c3568302aee11b8b8695a0c28fa2db2306dcee1ad167cf853bb6e9132c892b02c81efbd5a481dcfb044fc31aff003233ff00ef08bea6ee6fa8d2631fe861aafd147888476c734d9ece0766fefd8af621f0f74b77cfd3fdff0006329cf804e85ec34e69055862dc7296023f334f76106bf5bf64c7a63bb3969e415c1d5609f4d24a5ca7e1992cd6da7e800316c3118311046b8bb80e60430a",
            "235847ea8c23f0b623f093c864e608b03ff3b1aef242b6e3c40822202932d8d1046b3b55473351f602d61a03d82db63476c68ad8fc27ba5e0873af001b1ad88d30d8d11b1a5dc317905c4688234c08d10469770c9e41611ad08d34235b11a5dc327905446b5e9a6847e16bd34770879053d3f0a7a6539e97857e9784bb84f704bd32a7a69df4bc29e97847703b823e9a9e994efa5cad0636b954a63ee9cf7464213d8485d27c6dae3ba018cdf65a7728b8e43e51fc40fa8faaf48c8c6e95d3a67e2ed1991f336b670ba01a7d801dd797e81d3baf7d59d6cf533d50b65c47c664c895e7668f6d4015d9a78e3cafaafd5bf4cf4aeb50b65ea44c061638b7218434b2be49e08e6e8fc7b2f98749eadd2ba27d1b9ff4564fd4f8795f504c5ed3930c6608a47bcfd8c2e77725b4dd80ae6bd8af3ae3184a1823f3df2eaf87cb7f647b987acc4b1c71c1549f97c7bf3f53e9d0677d39d57325c4c5c9c2cac88ecb991905c07eddff0065b9ba3e097811b1cc77734eb15fbaf8efd01d1fea89fea0c0c9cee8f374d9b166da7690406341235b3ee47142fe7b2fbcb61d5bcd171e49f92b9a3d0ac59e94ee2bebebedfdce7cf186371d1da6af9f3f9a1010b6360631b4d1d80592c4fba343746bd8534b8444720839886e6278c686e8d5770d964112c432c29e31ac98d3590d96410319592cf6a4e967b52ad00f656a65ac873dd11055b6224a79f1870e165a047dc2b532fb9c02663baac84392337c04cbf27edd5a826615c8e55db145cbcb1676cc14864f1ca33ade564c5410e47427ee2ae6f2b71868e4845f4d518ec5052a65b95a04f366c2c3807045f4c8e15088df656e61162a59ecb262f809b31aad294ac869b2160c5354c965fb2b318ae52dc7b86d15e88fa2b0cf0bceee1cbb8be9e16bd33f0980ca5749ee4ee2e22b5a31808e5aa83094f716e034f0ac3131a2d06287905b8b862b9816c0c03fd4e27fa7ff0074c062ce4445d8f63fd06ebc1eff00f4baba2cb15d441cbc5994a7cabf715631ae7801db023e2a8a6bd31f0825e4c6d9bd580b9bf696346afaf922b9eddd3114a267063000f3ece3417d075d8babc928bc3fb3f5fd8324fb70da6f85eaff00d42d2cb336318a667189a766b09e07747c41b40411d9c561e32638a7866644da3b39af0dddbe5a7bff0044d61425b002e144f3d947c5a6a3d3c632772b5fd39ff7ea67374bc2f3e9ebc79ff6fee6c3111ac450c440c5f29dc307302188ad8fc228622b634bb864e605b1f8456c68ad8d15b1a5dc3094c0b63456c68cd8fc2236353dc317900b634411a3b634511a5dc30790008d6c46986c688234bb864f20b88d6c469811f84411a9ee18bc82a235a11a6846b423477087905446a7a49cf4d4f4d2ee13dc13f494f4d39e9a9e9a3b81dc1231ac1893c63f0b2e652d2390a59047d220f2b25807b274b095831fc854f216b21c6ea58d1cd86e1231af60fccd70b05bd9c3fa12be1eff00e1a75693ea52c262184d9096e6bdc0bc32ef81dc3bfb716bf4249087b1cc70e08a2b8b8984e9662d92cb223abef9d88f6ffb3ffdd724f3e6c792f0ff00edc3ff0027a9d1f56f0294955958f8e7512bc1baa6df703cf9348ce8d3ee8a90dd1f85ae3ac71508fa1cfddb7673dd1f8437469f74684e8d6bdc358e41074686e8fc279d1a1ba34fb86f19883a3432cb4f3a3432c571c86d19899652139a9c730fba13a35b2c86d190b6ab2e607f0982ca432b553355215f43efa0adf8d7d9361a00b3dd63d40d255eecade5e82de850ba42d09344269d2d9f0a8eb56a5c8d149fa8a18f958737dc27086943747f0a54cd14c52893d95fec98d0016b25969770ad8016d859d533a2ad14770ad80003dc2c16925325a029a82af7e05bf233a0535a470ce15e8bccee1cbb8beb6ac32d1b45a0ca5a2c962dc108d6846015b26bb29dd5ec2d998d05f0ac3115ac4411ac9cc972a0018b419ef43f708fa2d062873a3373b472f230e53cc6ed9a3b349edfa257f0b393462e7f50bd0062d862f570fc6fa8c51d387f714334b1ad63e0e3e374e717074a0003fd21755b1800008e18b618bcfea3adc9d44f7c8cca795c9dc9820c440c450c446b172f70c1cc10622b63446b115ac4bb862e609ac456c688d622b588dcc25306d8d19b178446b6911a10a46129b06d8d11b1a28622b58a1ccc25304d8d1047e119b1a208fc28ee18b98011a208d1c316b509770c9cc008fc2d08d19446ec8d983f4d5fa7e16d5a7b315b07e9aaf4d1544d482d83318a42317299508b5a6d40a4d0a6807b2c1683ec9b31dac3a3a4f73453137302c68d69ec9c2c427c76a7b9c9aa98a3da0f64231a6cc6b0e614f7368c849d1a0ba34f161587310e66f198839884e6279cc427312dcde331173109cc4f39886e62a590de331074684589f73109cc5a4721bc6622597c21ba227d938e6907b2c9701dc2e88e436537e873a48de070862171eeba7f6bbd9568df85af74d565691cd3052cfa6574dd16c86e86966f2b2d6510f4d5514e18fc2c7a7e1477196a62ba5a9a784d69e14d14b98f715d15689ad164b14f707b8a3a3b54d6514d962c98d68b28f61ff43c2bf43c2e90849f657e878586a797df399f87f0a8c04714ba9e81aecb3e89beca921ace72c63dfb2d0c6af65d310785a101f84d83ce738407e1684447b2e9086bd94fc3d9ec9511df101103ecb620f09e18f47b23371fc28923379a8e78c7f0b420f0ba420f0b620f0b2a3179ce7360f08831fc2e8b71fc22083c29a3279ce68c7f08831fc2e8883c22360f095193ce73db078456e3f85d06c1e115b07849a319",
            "6739cdc7f08adc7f0ba0200b623684a9983ce2031fc2d8c6f09f0d03d95d2a51666f2b156c08ad88045a574abb6d99b9b660300574b54ae952c24d98a5296e94a54b00acc52ba5ba5295ac0166294a5ba5295764566294a5ba5290b0d0599a554b74a521e20b314a52d5294a1e31d98a0b2580fb225295e164f10ec0989a7d909d0784dd2aa496368a53620e87c2c18afd9744b41593104f534594e5ba01f084e83c2ebfa4161d07c28a358e638ce83c21bb1fc2ec983c21ba0f08a368e738ae83c20ba0e7b2edbb1fc211c7f0ad2378e7388ec7f0977e373d9779d8fe104c1e16b13a23d41c418e43bb2d3a0e2c2ea3e100764031f85af93659af9101195a2c6a6cc5f010cc04a352fb962be903c52c9840f64f0848f651d1d8ec96a3ee9ce7440f60abd1e3b2e8082bd95fa367b24d15de39be87855e8785d3f440f650c42bb29d43bc72ce3f855e8785d3f4b9eca7a3c7646a577c37a814ded6282aecba353928336450b820972cec8d47a8c072d6fc70817c281c423516a1b72b6d794b82b41c8d44e2321e8ad7a4c3abdd6c48a5c2ccdc0703d683f9498916c3d46866e03cd916c489212795a1229d0c9e31d12d22365f2b9feaab13794fb7643c47504a88265c93915d957e2fca6b0b33ec367684cd5a123572239f6f7453901a3ba7d932782b83a9bb7e56ac15c71906fba619942bba7da68896168e82b49fe294fc493d8a6a0ccfb721d51263280ee515990d70554d09c2483da96807218dee56465b0a693168fd86ad44013b4ad7aad4ed8b561544212b4ad6c0fba3615336a5acda8a77151ab52d66c7ca9612dc745a8b36a5a87202ed4b59b1f2ab76fca9d8746ad458f51ab0e987b25cb1a8b0ca89012c67f2b066f296acb58d8d178593204a19bcac99bca9d4b58c68cbe50cc89532f94332a7a1aac434e9108c89732f9433226a06b1c61dd220b9e84e92d09d22d540de38cd39c49582b05eab75746ea26c90a81a432ef2a8b914550427843db9592e545c9ea5a89bdd6b60816aed2d47a842e540d7bac6cb3b1b46a141b655b8b42d95800a350a03b92a6e87b0556ba7536d426cac3be5081564a350a0dea00a7aec0937b8da039c765b471261a9d1fc434f016c3af90b9a0d7368ec908094b1fb06a39b11eeac3ca5c3c9eeaf659e81a8c8939ee881fc5da40bcadb24db8476c8701e12ad097ca56bca8258c716a7b6469ec3264e3ba1ba6af74074e0f03b217a80b9690c6358fdc65b9744ecb07203a4b0784a4ed2e1f6f09674831e225e795d71c49f8355089d8fc7362006cac6617720af213e4cef9366dea8d0f50963d411616ffca71687d889eb59961df6df28b1bde5f77c2f3ff88fe587b3b94d41d49cc14e0b1785d70652c3c7ca7a3f546964f29639bcea0ae51cdf578615a0d73407dacd614bc98ae9d2fc4757d623ee2e5a19c00a05719f3bdcda0565af20f7e50f12f51ff2e9ae4ed0c9738f255fe228ae6b67b6d7bab12fcacdc48ec9d86645fba37afe57199322fafc55ac651e4c658793a5f89e7ba2b32b9eeb8ae96bb956d9ebdd0e1c12fa74d1df1923e551c9f2b8c327cabfc41f958f6ccbf973aff88f2a7e23cae4fe23ca9f88f29681fcb9d7fc47954723cae47e23ca9f88f2976c7fcb9d5391e564e4795ca391e557e23ca3b652e9cea19fca1ba7f2b9c67f2b267f29f6ca58078ce6fbaaf5fcae799bcac9995a81aac2744cd7eeb266f2b9e66214f55278e87d91e32f95832f94a7abe567d54b429621b32219912e64583226a05ac63065592fb4beeabd455a1a28072f592e412f55ba7a94a01b653641d956c96a3d42972c97158d94d93d4aa37b2bd90ad51752350d42972ab41dad4de93d4350c4daad8842d95ec8d43503b2bd90ad4d96d4504d8abdb843d94d914066479085f98774578b081a382da2d50161fcea998e46b47293d79af75971730d9ecae9310f7e243dd4052d927e526d732ac1e511b2071ab52e1ec2b0e4934023b23f45a6479a0966cf0c565c4709797aac794ef459c72ad636fc2e096db1b932aec34d04b343f7bbbb5b7e39308d3ba914130fcc384dc525c0d4a8259229699938f0ff009ae16a3d874e3bae167e1e4484b9b68c505274dd0eecece466c3234185cb9f348cc81ab9d45719beae3fdae7729674933271212755e8c3025e18247a7c630323314839f6b48644d1c72b9a3b7b2e64fd563001ba21084c725bea2d2385a7b31ab3a50f566c726afe5a1172bad44e8f58c0ba5c39e303ee418e11f9aed6dd983f98afa9dcc6eaed8bef7393ecfa8d8f1ad8aecbc6be290cda03f6947662eae03644fa7c6f9636933d863f53065e7f2a64e46ced9a785e621798d823f7f95d6c68e4d07376b832e34b944dd1d366512530d981ee52631f566ca3490579f257e02d33a626a1dd51c90d364a46ca149c85928f22a4745b9913cd6cb5eb81d8ae2fa746c23b1c6a8ad2515e81aa3a82715dd6bf11e573c1e15dac350d50ff00e23ca9ebf9485abb4b516a87bd7f2a7afe5236ab646a1aa1e338aeea09bca46d5ec9ea3d50efaca8cde527b2a2e494435436661f2b1eb80092522e71b587ca40d696f18580f372c3892e28ad9c382e234b84947b2798687053c9048287bd4f2a7a895d94d973ea3a433ea29bf94b6ca6c8d40397855b841b52d3a185dd56e876aad1401bd455ba0da969d0062f55b943b52d14017750b8215aad914014150943b5364501bd94d90ed4b45081da9687b29b2d68025a9b21ecaad140176565dc20dabb4a80a79a3610dce320aa5b77216360de02d62c016afb51db31b60ad826ed4772395aed",
            "c80839cf91f4e77099c6871e3fe6177212b956dfc8919a6958ce09e577463baa426acf46deb1031da875d26ffc4db237edf75e331318b9c5cf7f72bd16140c6d6cee167970e389128a43a333524bbb2526eb11b2c16ae84f8d01868385d2e43fa5b667ea0f6596358df2c4abd4e6644a72243237b2b899f8884b5c2a9751bd15cc22cd350b2f0ce3d18cf1ef4ba9658be225ecbc23cfcbd37793505398b82e6b7d36f647ad0124fdc56e0c9fc3fe71c95bcb249aa4536c03b12424b1c385c9c88678252d04d2f4d264c72c760d14b0635c769058530cae3e4499c28ccc5b4e0765d3c4c47cb45c69325b038ec0008d6d6b07a668a73cadf81b60dd8c63759174bb1811ba58fed5c596590fdbdd60751c8c51515ae79c253544b4da3d2c8e309f4dc56034bb91d97171b232725dbcb74bb114add35be571e4c7af02aa34e35c2c92998e36b9bc9e50a46d5f1d973d7235202ac2c59b560a1a283072bb42d94d945005d94d90b6503ebba2802eca6c8777d966cdd26a220e1c08f2a73485f6b392e5b06490fda15682b2f6e695106afd914633c3763dd0de5e1b44524a3ec1b032f0d7590b32cf003682e70a3696f4777124ae88c57a8e86cbd9272d4661a094630b0f74c5d289af600fb2bb14824f0b3b5ac75187d94d90b65364a802eca6c85b29b22802ecab643d94d91406ed5da16ca6c8a00b6a6c85b29b22802eca6c85b29b22802da9b215a968a00bb2ad90b652d14066d55a1da96b5a1585b52d0b6536450585b53642b5364505842e59e16792ae884e80d2c38d82a8b8ab6d3b829a402cf205d8484adf55d54bb6fc305b7694744c8cf02caeac73af009a390f648c20351a097203a9ce20271b1ecfddc38094cbdc12e670d1f0bae32db80f2307227db979a4c62f50fe786b8d2e2c72cb31d5a536315ce80d1a7a72847c31348f419b984c01b0bacf84863cb248e2273c1f95cfc3c7c969fe6b8d04c4cd95e358c1b592c718fca89a4b81b184d9a5b0780879b831b9b60d10b58d24914352707caba76449c3bed1dd4dc93bb0b6711b0ca64205d272dfe96ae06d7a1c7c4c61f71a46970311cddac0513ea137e07ba3ca450b9cf3f089e917921a7b2ebcd8f0b054442e7cb1ba005cdf756b26c3bb2e1d436a4e4acb9b0893b5a98ad74aff00bb8b4ccb8459f783612934985f263705a18c1410d9bb25ee50c48e6bebd934434c5b8fcc127c00f31d27a61ed3d90df9a36d1cb8eeea92b5de934709985867a713ca878ab990b5af23fbb6ac2ad905cc73480d28a080392b9a5119bf6b55b2adaf81d9538528a1d9ad95136b22dc682d96383509059a6c8d028a3358d78bec90a76dc85a9267ea342b550bf04b0b240f2eb0785b8f39b8fc3c764a3a69c81af28830269a2dde385a6aabe617dc63fc584927dbf942ccdd44647d91b795cc99adc525a0ace33f4937a57da8d5a1eabc8ebdae2690c8737b22be43567dd601dbbac5f0522e29031d6fe422ba56bcdb504b415000d1c2974c030793c2bb420695eca1a00bb29b216ca6c95005d94d90b653645005d94d90b653645005b52d0b6536450585b55b21eca6c8a0b09b29b21eca6c8a00bb29b216ca6c8a00bb29b216ca5a2801da9687b29b2d68025952ca1da968a0096a5a1da9b2280dec42b137b142bb59eddd348062ec5a1ee1a6d603cf65a11ba4340275422db96f2ea2784e31b0165bc8b5cc9a37c4ee42a3b960ab5b689ae04d179b3116d88709374fb41e911ca6c46e90801a505f8a6392dc16d16a2a8a54251b5f0bb668449b2de1a0b38299737edaa54cc2ddc091c2b5913e58f8f5018bd51dbe92f0ba71f54c78dc38b5cccae966478f47bf84d45d2a38b1ae53f7aa92c4d592f50d9799f88fb9838f0956673a01a5725318ac67a81a5b6175a6e850cd1b65670b373843e597815a471a1cdc8b06cea9e1f899dc1e1c4353bf808a1c7d782e438c98e2732abe164e71973144daf405234c7c07592860b8b83646d8588cc8322a4e45aebc6719f180ead94c9ea0dd1cac977a2d0626a5d997348dd1cba32e4e1c4f31bc82937989effe476f0a978e50d10c0e31ee4257d7746faf64c3f22403d3038422d6c9f98526b8f2518114523b7ae54133e334dec8c220d16141134b6d2721d9a8647bcda290f71a40648233413b8f34544bbb959497a89f02e1ee6f09ac7fe670e5b6e3b263f6f75a389243f78ecb374f826c21874fb804bbe52d29a8f25a7ec9381f296ca809fbe3e42518f3c893f72fd463db5c5a5648dfa97347087eab22ee79525ea0c23d36d52e88c1af0324798d89a4380b433d7a5170d70521230ba5d876286718b9fb7bad9471ff00ec5eabd47c8393f7b8f2b2e718871ec851091a6ad31ad8fb944a54c0d452ba4ee98069018037b226cb9e7cb0096a5a1eca6ca28025a9687b29b228025a9687b29b228025a9687b29b228025a9687b29b228025a9650f653645004b2a5943d94bb45004b2a5943b53645004b52d0ed4d914012d4b285b2bd91400ad4b43d94b5ad0826ca6c876a59450060f002b1f77640be56db208ca3502ec82b40177289fcb70b43f5357ea0708485656a76a4ec54d00a09746d65fba5e5c80d670ee5351720f2353112725131dd88d03d4705c6765485b4126ef51eefcc56cb1714d8f53d24f978b13bf95452b264b27aecb90c63c7727f74d46d3561278e3141543e238cb6ef95932916d68e52cd91cc77278446c837da94a8883b1e201ea3c8b5cf74d3e4e5d924476b3965f21a69550caf6c7e996f27dd74c234afd4747a7c08708005ce174b73751858f31b1e282f179b3e5",
            "60c7bb1e7ee4be13f2321e6591c40292e936f9dbe05a7a9eabfc5633954e3c2dcb9026907a6780b95f82639a1e1dca731d858cfb792a25082e50a90fba684b01a1b04a92f90b9d19406c3287905a68a6aff0d1801b76a2947c0bc1c7970322794bdc4a2c2e38669dcae8cb9043000292ce818f66d270b4736d54bc157ee5b3218f37aadb835f45a29018c603ab4a74c6228a8f72b3952f023226c78a3a90f282ec889c699c048cd13e49bc22080b40e50e090e9047ea4f0b2c12078a068a24510b05cba244460fb00d829da81b18c02c8dc1d23a8527723331fd273637071f0bcb4d9130047200408ba9b227d38da3f9672f989d2f91ccb9ded26b84087aac8c1e9bb90503272bd57db470509a1bdeb95d1aa51a922d2e390f2dc8e2e07ba57d373a40413c26076571b69d696f4b818589bf6d145d42c92d154a036785ccf911a03e16b9561c1a160cbc529a606ae94d90b6b57b228025a9687b29b228025a9687b29b228025a9687b296514012d58b5b8437dd6a42d1f942541646b0b82cb9a5ab78f92c63a9c382ba0e82395a1c28a97c7926e8e4f3de915b1970b4e08a2075242c4b232114d168f3e02c54c642c72d2b2fca713c2c0797157abf5282175aab5445058b28a0096a5a1d953645004b52d0f653645002b5365a1139e2c05831b82d02cbd968482a90f5729c527420bb355121c8488d6551b4e80d0df5e15b5ce1f985523b646b4552a91f1cadd1a28a3f20b1695e5dd8a58b0b8f28ee639a6940155d781d9230dd688545ad07851ede3859603b728035e993d911ad7378466005b68ad635c2af95162b1431b9c98f42e0a3c108c4b221448b4391dea476c3d934db158b3207b793ca148c90bef4348f166fa67593baee452624b89c81b10ae539439681b68f292b7f127d27f349dc7e9e1b1b6c801332e0b3d5f55a7ba581c833165fda16bbecaa2c776312b0b59a30a360445920f50d82aa200fe6e48419fd769dda486acb97f288f4933f19906ad68da979f9f21ed9e9cdb6a2e2c86700936427ce3c6e88ba5155f2b08a58dd3e495c0906b658c1aa296c81b0d1a795b7e4c2c2e635d45730e448d9cbbdad6f18b7c9490dc3048cb738f64ee3c8cca7d3c8b6ae4cbd41ee2351c7ba5bf16e80991868957db94973e474d9ea64c7858cd8016b932925e48ec10f133e5c93a1b2baffe1ae9581c380573b5db7f313e3c9cb6cedec542f958778ecb7dd3f274700ec0aa91acc78b522d38ca2fc0ed7a1cac8ca1202dd68ae4bf17f9963dd76a7c60e1bb077408621b7debae33515c149d03831c88c170ec8a58014fc618e6576a587e3f1b5ae694edf22b13a560d05b7002c1412794866ed6d9c72836a8b881c254019f2ecee1676b43055da6d004d94d90efca9695058506ca2e9c5a5dbc72b4252d3c94a846dc080b1b2b328770b146f84501bb4d6343ea9f0976c6e2dba5a8e69637532d1ab7e00e83b14b15c51b1c742163d799cc05c0da6629606517900a869a4472072f00451eec4ac195234fa66d74c6435f2e8e36d2998ba4c3ea7aaefd52dd4554c2ebc9ccf4647bc3f916af218400dab5e85b8f15702c29f868bb9603faacbbc89d8f34de9ae737622ad64e27a60d95dccacdc6c5fb5dc9f0b83999cd99d6ce005a437973e8526d982ce0a09e3ba5dd94f73a829ea17775b38b2c39736962d0ad5da280decaf9ab0860df65a0e238450ecec470b639353d8ad4f8cc67ddc72852899f1873014b3e5c82d01c09a50a0df36666a48dad69bee927b0037688e95ee34e1482f8a573ac0242d546bc9489a922c2c35cfda8f64d431bae88449a1f4dbb6a9a75c05988b573803d949622c936614b7acd8c137cac3b29ee16de55a8b18c190014feeabd466a6bba5d8d7cc493dd516988fdc938a0361e4c9498f4c916021431fa8e1aae83d862602470a64f91362644838010cbe589d77ca3bb29a5dab4594f63e2b6601ef086f55ca0ba396d6cd3726d5864ec3ab790baf346c6b83582825e6c9871fed3c9429b7e1059cc9a077e670a2936f509e09b4703aaecfa91e4b76baa4b64371b52681216f097a49149fb8c62ccfc96ddd3537244d1082c20bcaf3e3384475670d5d1c1c874b2ec4f03e54cf1b5f309a1b643243fcc978054329941606f0ba15f8b606f6015bb19913096b791c2e7ee2f5f24588e2b04127a84d045caea0c97ed0ea090cdf585b5a6815c96c19133f5d885bc7129fcd265a8df274a6c013482589fdd30ec16360fb8db9574f865630b5f7c223db2b9e01ec14ca4eeafc09b394715ed79a69a2b470c4a0003b2f59898b0cd8f4e1c856fe9b0460969e565fccd3a16e71ba662c50905c3b2ed479ac7c820880f85c99e5642e2c1dca1c52b7141989e4a528773e6626acef64b4451d972e6cac8a71c1048489cd7641372707e4a426cc7625d3ac94f1e092e3d46a2c633666c27d361ba48fa8ffcd482c6e464bbd57035dd3d018ff2c82974b4a2a8bf00c4eeecc5a6e5bb6d5c785b931dac3bb0d84accdf7014f0c5c047cc1c78432eb4116072aed4d004d94d90f945644f7f608a02ad6859ecb2e8dec34e690891bda0729019eddd583686f7ecee1587008a00a4d3508924aa73cdab690780394ea80dc6d24a7191b85585312124ec4709c9f22363756b790b36db7484d87c68e391baba815a38d14328908e1723d799eeb8ec26db3c85863783654bc6d7364d0ce5e6e3c600636ed72b2242f66cc0575313a6898dc9d8a7874a81a6b820a6a70c7c05a470f13206a03bf305da667c93462367e96832f498984b987f640664c786fd08e5296b9398a074fc",
            "0e1cf971006b8137f2b12f539a5680d15e52f2e7e3cf7d8d2d6366e21fb1e00fd54e94adc790afa11cc6e456fcb90a7e892160730f7f64d4b2c01b71105c51a1ea5ab0472004a1ca695c42dfa1c2774c745f9bba56585d115e87332637378eeb99330c8cda9546527cb1a6ce65952ca760c7dde0109e774e1a5b5bcaa7348767263fb4d94e63c4c99dc851f88e8fee78a0a3246b1c03024f95c01e9f19d039a630decb4cc38b62f2d06d70737aa0c38e983ee4a63f5bc99acbac342c974f392d911abf277f2ba54529d98353e1621c16c5190f1fb948e3f559a4269dd96e5eaa76d1fc5a5dbc9f85853f056446c64e341616f22582483d2006c8226672f3cfc248bee42f00f75aa85f9f41d0a4f84e2094184362058e5d779323410d34b9b950fddb3574464df0ca4c340e603417423c38f306a3b8eeb8b1821e2caee624edc61b82092b3c89ae63e44c6a3e96cc78cbc5d84865ca5cd3100ba3fe311bcfa6685a56687d525f1f34b186c9dcc957ea713d0742fddc13917556c6c31f628f2303a12d77e65c8931d91cbbbcd0b5d51d67f88b5cf91efc4cd2c6ed41bf65cff4a495e7d526c271d9f0c518f4802523265ba497ed144ab8a6bc2a1a188c887eddb845663b27200777483e192420dd277158e67677210d52b4f902a7e90c6f25dc2c35ac8788dcb5953487ed24ae4ce32873182b4c6a52552635cf93d1e3f568f159abdc2d351f5885c69c4515f3e70c8925fbc3afca8f9a6074dc8a5a3e8a32f5e4aeda3dbe64c267ff002cf05338788366bdcbc661f53922a6caeb1f257a5c2eb58c621bc805795865c3382a89328b4b83d2c91431306bdd6638a2782490bcee575b89e0b637da5475594b75638dae45d3646b933d19d4cbea72e0cc446784a9eb52be40e73f83dd2524eec8e1edb284cc17c8c207e62baa38a097ccb92d25ea3d97d4319cdbd86cb98fce33dc77f6fca2c9f4de648c120ba4097a6cb030503616d0ed2549d94a855cfc98ddf6b8ea9b826664bdad98f2101fb86eb480c6b9926c0d2d5d3451efb03f06e804640ec93ea3858ed76d1bc05e7a1cd91b4d6ba8a79f397460992caf3de194657665ab4cdc2d717fa64d85d61d3e1920b1c95e7865b98785d1e97972bf228bbed28c90955a06981cac4d1c434764b36025d54bd54f8ac91a48a2579f9dae82624f002ca13db8253351e0970ba4dc51458e2e4e109bd5626c400036409f2db3b76253d64fc8531e73229c5b395c6ca022948466f51663b0b4725253cc321db7bad218da7f4292a36d7348b5406c56191935ca23dc180007957432aa8f298c765bc1ab0b3046243f715d185b14635245a893ae04d862f31c74c08f8982d907ab31e0fca0b658c0fb8709593aa90ff459d82cd424d54454cf43174cc70fdc557c265d878ad1b398057baf1f2758c885b42d09dd6b2a784b413654ff002b95f362d19e832b3e2c5716b1dc2e6b3aeb8cfaf704ae49c7c9c88adce3684c608039affcc3b15d51c104a9f2cb5147ac194e7d3c1b092ea4d1233660fb8ae0c1d4e585c5af16d5d3c4cf64aeb7f2072a5e196376835a071e33e18f77dd794a4ee0f7544ea2133d4ba9fa8d3144de02e0b5d9365c1a4ae9c709496d2292be59d78269237fdceb47f565328939a0b9d8314d2c837057a08b1f41f70b14a32351627c02844b9328710750bb58b1c5231cde2c2e5499631985ac6774187324f546a48b5c93839ae3821a6ceb4b8de9cb6de026a19606464c8f0967b279f1f76d9e1238f8cf33eb338817d960a2a4b964d0fe49664b758c70af1fa5b191fa921e7bae845063e3c5dc59484d34c65d41a6288b6f88f817d8e2cb1473cd6ee40599a4c48a31132813f08984e8c0114ee01c56b27a640e25cd905feabbed275234fb88324fc24a1cd36d3dd744c3167343a32361ca49d86d10b839d6b9d1e63fa7ca435c4df0b5d77e63e4aabf077a46b59108bbb870b71fa61837a5c439924aef5072553269e696c9a0a7b4eb962a3d3c13633da62f72b1fe181c5c6f8f65cd8b485bb977dc9919b2b80ae02e67069fcac86bd8473715f0dd7b2e69c9c8676374baf933493fda172258a685c4b9a697562f1522d7d4199a6172b89b4d6275d74434714948c9656f038598ba6c92bc70ba1a835f315c7a9d797a83a7703124e71913f04114ba38982dc78adfcb96e6b73496317329453f95137ec70443246fe4d85d0c68438eeef64a4f23f620854329e23d47056d2da486f93b124f8e19ab6ad620c79a476d193496e9f8473241b3e977dc5bd3a30dab217349a8bd63cb27c7085874b7f1248169c71e3668e604ce27546cae22514d4bf50646e6b9cc0b24e4e5acc5cdf270fa9bf1dbfe5017e173462b3207a857662e92fc9b7770b6fe9af634300aa5df1cb18ad53e4d1492388ce8d34d6e6d8684b3fa5e63642d6425fe42f4ecca3137f0fc5f65d4c2922c71b4ad06d0fa9c90e6ac3768f1589d3725b3874ac2c03d8af41060c45d63baea4b1372e6de2035f0b1263fa2dfb0f25613ea1cfcf0c972b065b8b15035684e95b14cd91846a93c9c1ca91fb0068ad1c7919068f3ca4a2bdc28f430f566c91e800a41958c92c10082bcbc79671252c714f7f8aecce143e9dc5dc45ad78359d145130ea05ae382093c261f90e9e520f655242d0db6916b68ad7863f02869967e55473381a26ed61e1c5dca8d0010b7be07674a16b656d1ee8d24aee9ecd9a3958c661fb5e3d91325ae98539b6b0f5a7e04483ea07bbf370893e6b72e3f82926f4b6f7eca9d8ce839050e38eee20ebd01b627ee7cad3a37c6793c2c899c4d214b90f7",
            "9d4abe5816fa25469a3c7641dcad35dcd26d00d89e87056092e3b217a6e3c846c7697bc34a8a484118f95b5aa60b277d385da603228596ea48cbd48c6f3a0e0285727f2a0436e749e9e86c14bdc6d936777091ff00127993670e115d970c8df256aa0d143672316571da8521459789092785c89984d96f6280d68da9c785b471c6bc94923d341d46399f4cec999f15990c0e611b15e6f1cb2336d72e9e2e6bc496d3602ca78e9dc04d7b1d367476e4344600d9666e90705a2cf09b8b2ff0f8e7209a72e4e5f5c9331e633d9610eec9f1e095b331246c6bc102ed74a0c38dad0e7014573206bf625e0ebecb7fe2123a41081c02b59464f84376ce9cd1b2166f1f09593aa86532acad4a257c340d8a5c6313cc86dbd94e3827f88125ea7aec466364c01f255adcb858a5b7091b785e2a2cfcb8b27d26d86765e8f0322a405cff00d5639304a1ca64b8b477716774517a442dcf044ea981af95ccc9ea51c4e01a9739eec8610c72e658a4dede08d5f91c95d23ddfcb75d2cb9d2816fe1210e44b13cfb840c9cac99edadecb758ddd15471732595c4be324387c25b1f3738494f73cb4fca6e8fe626c260ba2998d63594ef95e96c92aa36b02fca948d36282f87667a8e36532ec70c20f75a63a377f2cacf64bf093626c9248d84b5b61464f902cd10176b0e0c6f5446f2297532b0f05b06b1eb642ca59e29d344b91e3867ccec801d7a84d3fac1ddac6378ec5333e2e3444b456c51b0fa3e3497238f95a4a78eada1da00735d186bfba6599adcea639a87374e7ba42d60b6ad458671c6e3b8eeb17a35c7927808e6b71cd16f0b70e6c2cf60147b5f90cfca785cac9c79762d682128c54b8901d83971bdf61cb7fe21147fcb2dbb5c5c38de650d7df0b7d4356105b761576a37a8e9179c59b6cc1c149b1a1c6d0fd7749c14ee1c05d2b41ec5695a21783a7d2d8e077bd404fe67f31b64d85471447080c21b6b9d3e7888881dcf95ca939cb6425c8a6564fa4fd6309dc6cc13b035d69bc7c4c59a2123c024fca08c36b726a2fcbe168e706aab9455a3a98f910c11571ca467c991f310c1f694be731cc6d309b44c2d9f0dc8dfdd64a092dc55ea29340e6c9ea8ee813e53daca79ecba125f2dbbb5cf9f1c4920638d2e8834ff11483e1f509226df347dd34dcd739fb104a59b1c4d8bd3053f8d0e3b59bc8e0b39eab9a13a3a70e447362d1003973e4adddea7012f264343cfa4ea012d2e419d86cd6ab28e2a764a40b27a7c7249eab9dc774b491c510b69b01624cd73c18b6f097f4de5b65fc2ed8a925f332fee175b69733ba54be563b9b45f59b0f176a3b2239076e51c92c91b83bf3280343b95914d17684f78bee8a03a90e5b228cedec82feae09fb5ab98f7978ab54c60279eca9638f963e0eab3a8b9e45f0b73e5b5cdab5cb7557d8b2cd89a252d23e507019d26a7855bd8bf75463777a518cb70053e056400957ab814f47035d549c9309831f6be564e690ac4e021cca2511cf640d2e07948bc39afa695894b8b792ab4b632e6cb9653f9b841dac73cac5aab5aa55e02cdf0abcaceca6c8e42c235d5c2a2d04ac5a9b202cdd01f6829fc47478f4e71b5cd068da8f79aee9b5b7052763f9f9e659358dc4355e13e000ba4ab0b90412abee1c0256bdb8ebaa2f8f07ab1d4719f0eadab41d62af541e570f1410e0495d511131db9dc52e7963507c325a48723cdae09b09d6c98af658aba5e4e59a48dc5a3b22e2ceff0073dd2961e2d03476a78e367dcc6871f9400ef4d9b6d4e55164863807f20ade43639db4d21a4a84ab8624318860c969f51e2d6d91fe1720d7e42b911e24f8b307875b6d771cf8e7c514417053354f8769830fbc4197c5a0c99113233556170b2731f8f2fa7760a1c6f7487673bbfb2a5838b61a8339a2835161cc6476eae573fd2d5fca3b220efd974b510b1dfc582d2e7772871bbd575b7828422e6fd9398d06b2077b2c9d2f02b3622958ddecacb72f243b92485e8e1c48b2a0d4385a049d2c42ee402b99668f890b638e219663ea9b4e4526acd03a885d9821822808781caf3bd4aa098b9878b4467dc7a82767631e721bad5a310d3775cae162f526868e2ca627ea018c0e6772a2589ec1a9d06e6c10bfd30059e1740e2e3e4c61cca04af378cd64d2095e79eeba81d235bb42ee028c98e9f0f91340b3a387081a1f77caf3f2cc66249b5df99bf8ab12774b9e96db002db1c9457cde47e11c38a13b6dec9b8b27d37000721755dd389a8a31dd6e6e92cc6c7f50f2537962fc936854cd953b2da480976e1be596e4e4adfa9306eb1b4d05d0c06bcb4be51c04dbd15a2fc21622785840baf644c6c992266cf149d3911b9c439bf6a573e58a480b626f23e1669edc341e46219e099f6f70bf285933b43c451703c2f326599920a2574a364859eb12b578545dd8f5a3a24068d89e504e1c9312f06825db33a7218cf65d2804ed84b5c3b28770178107c120e1a79095ca6e4b23b0e35f09f7c8e81ce73870b993e53e67123f285b42db291cd7e56447c59e569b9b23194e3dd5bda5efb2380939362f26b80bafe57e836d0733071b079504d2762784b0e16b7e14d1166dc6cf254da90f6e5517228418cae3c5acec4a16ca6c8a105b2b7ea0d692fb2bd914018484146673f724f65a12102ad27103a47219a504bba6b3c250b8fcab0e52a0900e3731ecec7b238ea2f948613c2e78161535baf28d22c63b33c81c14a191dd89593292792b05c9a8d01bd8a9685b29b2aa105b52d0b653645005b52d0b653645005b55687b29b22802800f756283b90861f4a39d68e47632c903",
            "5db0a4c09a4978ba01732d6db339a2814dab2ace83bd33de8a03880699c21365f95a6b87eea2a8563705bbf39ecb4e9b49851ec973b96db4a13f72cb37684ad8d31e97aa070f4bbf94a9cd971cd34920a598c00ec7ba698d89ed0d7512b4518c7d0b544f53d66091edb250cb8b5e08ba0baf8b140e8fd37000a5f2b0db1debcacfb8ae85b187b1a5f7f29b8f19a23bf72838f15b03dc9a0f008f0b0937e1188ce160891f4fec99c9c0746d223ec95ff106c6c15dd323aab5d05122d733ee5d8b938e33f2f0b24301356bd063e6bb2981c5d6573246e3cec2f756c97648714921dc2d6518cd78e4ab4cebe4cae068bb849e5c516463d6df72e7cdd51b74e29376697bb66b95430c9723a091422294b5c784f4631cfe778a5c89329d20f2977c921fb5ae5d1a3979633d4c50c5a9d24593952630d5b66d79b8b2e5c72097921767173e09e8bffbac6789c797ca11d4c695d3b36228a71aed5b65dcae34b9a1a6a1aa0b6dccb8edcee573cb1b7c92cecc192c89e5d214ae6f551312c690405c69f21d2464072571f6127de78551c0bf131d2f2763132633368e1c15d47461ecd637502b80f745a7d840721b73b223750712021e372e621e4ea64dc34d3d90a2313cf2e4b9cd764329fdd736774b14a342695c20df0fc8d1d76e031f3fe6e2d3ff00856b63118771d97263c973610ebe51a0cd713f7394494dfa89b6745b8d0e17f310a4eb316e1943e12595d403da585dfa2e3b9a5ee2414e18b6e6635cf93b9959104cca0ea5c67cad8e4d1a41169397706838acb46bf738aeb863515e4af07564d5f0ff002c72b93387b09b1499873d911a22d5666547332da00288a9275441ced8955b219772aad745082eca6c856a5f945005d94d90afca97e514017653642bf2a5f945005d956c877e54bf28a00bb29b215f952fca2806db200059552497d8a56fca97e52d4617653642bf2a5f94e8417653642bf2a5f945005d94d90afca97e514017653642bf2a5f945005d94d90afca97e514017653642bf2a5f945005d94d90afca968a019691576b25e43ac141b2a03ca543b3a18f338b807764ec9243e9d0ab5cc69fb3854d0e0762564e36ec06030c87ed476e0cadfe6134020c726a6c278e717b046024dc9781db169726469023ee1390650923a97bac470075b884b4bf6bf56852ea5c05d85198d035597e50afb4f2b88e9cdf0567d7703dd6cb09274ce512ee557e21d7c12b9a652795626a2afb63b3a8dcb93b6c690a6cb91c6af8497e202a32823ba4a15e81611e76376adaf0d6a5fd4a5873c95a6a163c24042adb5e6d24d908f744f56c25ad0838a79fb8a622a8c58290dd57ac4762938b7c0eceb1c8207741fc4c85fcbb8487e20aa329292c616754651ed6ace43bfd257243ebdd15b357ba5db01df5e406c92aff1c5bc1493a70421ba46b82344fc859d5667f14130d9848dfbbbae0b5e0145fc516f62a5e2f611dafc431bc1281266069fb4f0b927249ee567d6dbba162f703a0ecaf53df9563248156b9c1f4abd5e6d5e8876749af07971429650780524e9891c158f509f74d43d441c9af757b8aee96dcfcaad8abd42c29772ab642b52d3a00bb29b215a968a00bb29b215a968a00bb29b215a968a00bb29b215a968a00bb29b215a968a00bb29b215a968a00bb29b215a968a00bb29b215a968a00bb29b215a968a00bb29b215a968a00bb29b215a968a00c0dad6a5043a913d4e12680b556b3bf2a178a4a80decaf6081b29b27a80d896855a825375695d8fca9b7296a075217b6a8a61af8d8792b8ed948f7566524ddacde3b03d1332e30cd6d61d2447ee5c013381ee8a324d55a8ecd781086ea6e83b29b2eea186dd4dd07653645005d94d90b653645006d956c85b29b228036ca6fe507653645006dd4dbca0eca6c8a00bb2bdd07653645007dd4dca06ca6c8d4036ea6e83b29b228036ea6e83b29b228036ca6c83b29b228036ea6e83b29b22802eca6c85b29b22802eca5a16ca6c8a105b52d0b6536450c2da9685b29b22802da9685b29b22802da9685b29b22802da9685b29b22802da9685b29b22802da9685b29b22802da9685b29b22802da9685b29b22802da9685b29b22802da9685b29b22802da9685b29b22802ecaf641d94d9140176536f285b29b22802df952fca16ca6c8a00bb7953642d94d91401b63f2a6e83b29b228036ea6e83b29b2280ffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080100010003012200021101031101ffc4001b00000301010101010000000000000000000001020304050607ffc4002e100002030001040104020201040300000001020003112104123141511322618105713291a12333c1f01424e1ffc400190101010101010100000000000000000000000103020406ffc40020110101010100020301000300000000000000011102032112314113145161ffda000c03010002110311003f00fc921b0314fb47b4f61b1daab5b00b62580aa9ee5dc048048e40e46e1f5a38d1cc91cc9a1ec36284687b0d884bbc54b75828777a83108cea1599778240270e7ad3fd98d13b0d93b0d8d15b0d93b0d8d15b0d93b0d8d16fd808ec2cc3072c339ce7d9f7bffe788b64ec36056c363b3e905acd6eecc576c0ca0056d3c03a74661de3924671a6363456c364ec363456c364ec36347527456d9d0dbd686a7e95562d6ca6d50e4b02462ee91f69e409cfb27669d3d697f5155565d5f4e8ee15adb0315ac13fe47b41383cf009f8064dbfa2761b2761b2e8ad86c9d86c68ad86c6f5b56b5b128458bdc318120691c81e0f1e0f3987c112363456c228c4a0324ca32ba9bdfaaea2dbec15abdae5d8575ad6a093bc2a80147e00007a928ca3048e6232764458e4f32880070c0c54fd22e7eb59622f6b1051031eec3da3091c13809f40938730c6f1e645d5ef1c64aed5c1bba6663fb9a56fe493a40f715625867a93b37b14840491c8dd9cc7cf1129662b61b2612b956c364c2056c364c2056c364c2056c3655f6adae1929ae901157b50b1048500b7dc49d2469f5a4e00300ce056c364ca5b1d03aabb2871dac01c0c341c3f3c807f500d86c9840ad86c99695b3abb02a022f71d60091a0700f93cf81ce69f00c685b0d930815b093284062508846258a0c9328c9314232651932214211482c0ef015175bf1e4c4783f99a7fd852197ee3e181f1f895450b70d2c779e3e673bfaeb3f096a57a54877fabada8cb8bdbc6107793fe5a30660e4ef18cd7bfe8300486e3c7c199d8e1dfbb3344b2a58508b61b2a1c22d86c072cdf6b52941b5cd48cceb5963daac400481e890aba7f03e267b0d80e116c36039d567f2375bfc6d3fc7b25029a6d7b55854a2c258283af9a47da301339361b2592fd8708b669d4d6b47516d55df5f5088e556eac304b003c30ee01b0f91a01f9025d1108b61b01c388b61b01c0798818e039424ca12862508846258a0c9335a6b5b5cabdd5d202b3773862090a485e013a48c1eb48d20691918a119265188c88919bcf89d9d1d7752f4f55557596a9c38faa8ae8483a01560430e3c1041f7391495208ce3e6770b4dc023769d466e5c28c504fb239e38f64f001244e3bd77cc9fa8a6a5fe46cec07b0aa8e4ffccf5ba7fe368e94f71ff22306cf1fa1ea12ab54b06277e7d4f73a5ea2b6edec1bbf03fc7ff4cf3f9767a9f4f4786737ddfb795d6f424a8b98042c7c93e6702a216605f33c71e67d3ff21d30beb230f791827856f48b4a85b6b7571cf6e8e44ebc7e4d9edcf9bc597d38882078e3e65528b6dd5d6f6a52acc14d8e095404f93809c1f804fe22b13b4020823fe667b3679a9ec362d86ca87b0d8b61b01ec362d9a5e2957028b2cb13b1492e81486ed1dc3013c06d00ef20038370046c608d1a347b024ec3606dd4bd2dd458dd3a3d74962515dbb9957d02706ccb62d86c9264c0f63d93b0d945804824660f30f3992479e66a692801e4e8d5c1e61627309078309562b2b630c3f126581cb0306c80399ae6712ac28c446312c01926518a28931336e0f423311033cf325133ae8e9baceb7a6ea1fa7e9acb6be96bfa975889a2b4ee035be0691394fea20eca182b101863007c8ddc3fb0273d4dfa4f7f89279e25d7d55d559deae41ddfdc8324c59a6d9f4f717f97fa9d27d4b7ed6d0381bc8fc4e2eb7f95ff00e6360afb46e83bcce03e324cca78e4bad3af37566346b4b104e71236284d191ece8e9ba2b3aba7a9bab6a42f4d58b1c3d8aa48ee0bf682758e91c09cd092efe21ec36284aa7b0d8a68b5a9a1ec37561d59545443773020eb0e3306007483f70c079c08d86c5081a58d514ac568eac172c2cc0866d3c81830660ce7904ef3823628407b1c154b1c1296a660706f6f247e234c5568b65889a1493c933d775b3a6a7b6de52b4e141f3f99e4d3694b95900e3c69f13d2ea3a909d122872d610578033fdccfbdd8dfc76496b86d6572480c49e46fae7fe66649200cf13aeb06be9c97fbbee1847a3f1f89af653627dacdf5189257b4601c61dde4f9e33d0f3bc773ac73f1d70d6486e00fdcd1803cfcc770557214611240204ebfeb9ccf45188a313b880c079818898a07cf5339464c894a231c46408c933502afa2e4bb8b832854080a95c3a4b6e820f6e0c3ba7919ce464423146655b7597b07b6c7b182aa02c4921540007f400007e048225d2d52dd59bd1dea0c0baa305665de40241c39ef0ff46418a03d81fee28407b0d8a101ec3628407b0d8a101ecd92a0e8308eede47bc980e78026f4562c07ef099cefb92af2eae8d7ff00b480d61957f07c64f49ff8fa0d761a6a3ae777ce4cff008e03aa",
            "4288592c5043580eefe676bf57674eac8591981c5278ff007fb9e6ebabbe9ecf1f33e3b5e1dbd05f65ee2b42c14f9f9975d56943496ffb674023dfc4fa54552a0951c8e6459423295c001f391fdbf2baff001a7dcaf9e4e96cb1550bb024ef6907833a53a5fa6490c08fc4f4ebad3a7a9d02070c30162754e83a39f3eb9df27fb9cd60ce04ebfa5ae7f948f3af452fe3cfb989fb78f22765ca1872270b1edd59bf1ed8f7e93ee31108c4d63206499462314499328c9910d2db2b57547655b17b5c0381868387e46807f42418e23e64154ad2ce45f65889d8c41440c7bbb4f68c24705b013e81270e61c8c662322118a331480314662808986c0c2406c36108d06c36108d06c018404073a68b1a8058a29e3082399cd2bbd8f96274673166acb8f4ba5eb29a2e0e0ba9619f670019eb753d9754aace801385f39d9f30ac577d83e44e86bdcf4cb586fb158b0c03de7bcd238f1e073f2667d78f6eb6e3cd92cb1f5b52f6205ddcf11b4f2ff8eebac3484196768f3bcf3fdcee3617a55ca9fb80e37c4f2de6cbedeee7b967a17a1ad99095254907b5830fd11c1fd4e4b66b5da6d42dc792064cadf734e5c757638ae3dda01fee715a801e276b80bb8304e276de399eae1e4ed22696a2d57595a5a972ab151620215c03e468070fe403f899c626b190324ca324c517d4d0dd3751650e6b2f5394635d8aea4839c3292187e4120fa991c8cc9910a231c464126231988c884628cc5200c5198a02308184941084240421081a50d42b93d4576589d8e00adc210dda7b4e90780d848ce402346e8cc425356502312b8e3b86303ec8e73c78f07f07d89605188a312825d6ddbc6683e47cc894a708303aab42ae843b6f1c2fa9ee74bd51ea828ee64603953ee7843acb8a84161c3c73ebf73d2e8fadac3aa86441da4162bc9331f2736c7a7c3d495e9b8006018272ddee6ebf5055ff0050ab37bede04c2e1e44cb9fb7a7afa73fd2575b59ae4aca2f72ab03b61d030603ce1279c180f3b80f03285ddc9d167711f71cf530350353586d40cac00ac83dcc083ac38cc1801d3bf70cde73d5c3c9db28c45189ac640c9328c4628931106511c458c46e7125119111efd4700403cc889618649947cc6d629a56b15206566636827b9810314f3983091801fb8e93c64466628cc5200c5199a74bd2dfd6f515f4dd354f75d6b044ad069627d0125b9ee88aa8b7a87294d4f6b05672a8a490aa0b31e3d000927d006446eac8c5581560708239062804210901084201010809607188a3128268f7596a569658eeb52f620624845d2707c0d24ff0064cce31037a3a5b2e0ce14f620ee76cd08340d3f03481fb13d0fe17f89ea7f913d4d94d165d474c82cb9954915a92174e78e481fb99a7495594567bfb5f301cf3ffbf33d9e9691d37406de9fb47d42518778ee198795f207239cc387370cc7bf25cf4f478fc5ed598b80601396e24370275692809f339ae1a665cfdbd5d7d3ceeb09d007ae6729627c99e8755756685a85558b03331b34f73039f69e730612306fdc749e3384ae09ebe3e9e3efed2231146269198324ca31b5d6354b49b1cd48c5d509fb558e0240f93da3fd0f88a20910361ccf51193261a34678e60d8413e39f1144644231dd6b5d73dac1033b1621142a827e00c007e0711df6b5f73dae1033b16211022824fa500003f0064ccf99108c5198a40182b32306525581d041e41818a02308110c9010864b3f4fe9280ac2cee3dcc5bed238c006707cf3bce8e0672c11086432301010c80101c6228c4a09438f310ddd1ea32309070ff5e206afd458cdfe4401c003d4e9e9bac34583ef210a76fcf6cc178e9dc8ec201037b868277c0f27c791c0e3e44cbf5264be9dceacbbaf768ea1af41ff0053ed0bfbff00533eb2c7fa7a9e47c7b9e7f4fd5595e80d85b8ee23726fd3b8642d61f648df333f865d6d3c9f298e7b7b89fbc1ee93a489d7d4af70049c3939738e66dcdd8cba99484a1244a13b8e419265192628464ca32644288c711902324c662322118a332ad75b1832d49500aabda84e120004f24f2734fad3c00304820c51c320284bb516bb5d16c5b555880ebb8c3e468070fe4093db9ea40a11e43250a11e400d3820284790c80a310c84025498c40d56e74a1e8cafb5dd5c935a9604020636681f71d00e1e37706489223128b438c37c6cf42d08ea8f58ed4ff5ea79c250620669cf892cd77cf58edb2c000dfb87a3317fa66b5657636163dcbdb8a060c20ef24f3c6718393bc62589f3189d4e70ebad3128491284ea20324ca324c508c99464c885118e232093118cc46442314a8b240a12dab28a84f6e38d18c0fb239cf1e3c1ff00cc9c807af11b1d0393fb8b21901423c8640534a9d14fdea58611c1c8953b8f9c1ecfc4765410f0cac0f820c8b3fda3c93e043088e12a2611e432028c43238008c4423128a11ca7b9ad4a918560549d8bda8aa48ee2dc90358e93c9d3983c0004cb14e5093284a353d3dcb42750d55829b1d912c2a7b599402c01f0480cba3d770f992235453533fd450c1800877581de47198307bde466f3884b16031d77594316aac7ad8ab212a709560411fd10483f831192628464ca32644288cd2b3504b4588ecc572b2ae0056ee1c918746770ce3920ef18733209314a222c910b2191e4d2ebeeea5c3df6bdae155033b16215542a8e7d000003d000405d454b47516d55df5f5088e556eac305b003fe43b80387cf201f9026792b22c80b2191e43202c864790c80292a76187cc325872a8547b85415c39c7ea2c8f21908590c8f2190164323c96f4d95aa33a3",
            "2ad8bdc848c0c348d1f23411fa3025c2061f4d999706965c3b9c8f278dde7dfe3c442191810188e211caa7284994250c4a1244a12c50649946498a118fb067c931187711c4945d2f7b52fd3a5ae2977577ac31ed665040623c1203361f5dc7e4c4f400bdea4951e4e495b594f70cf8f1117623b74e4e729e9190c8ce60f984a875a07b151ac5ac3100bb6e2fe4e0273fa12723840590c8e10164323840590c8e102e8a96d72af757480acddce1882429217804e92307ad23481a44d6c12c57645b02904a36e37e0e1073fa22284605934ea7a8bfacea2dea7a9bacbefb9cd965b6316676274b1279249e4932253d5656a8ce8cab62f72123030d2347c8d047e8c08c8647080b2191c202c8647080808e12e8a5ba9beba10d61ec608a6c7545049ce59880a3f24803dc099b5f5ad37db525d5de88c556dac305b003fe43b80387cf201f90263284a189424894258a0c9328c93142305cdfbb721346e9ae5e9d3a86aac1458ed5a5854f6b32805941f0480ca48f5dc3e64464d9a7b77229590c80b22c96388db0c2e3384ac86422612b219026696d8b6252ab45759ad3b5994b6da7b89ee6d246e10bc60c51c6e93393a1fa4a93a0aba91d652f6d963a374c0377d60018c78cc3a7c1f525c83961351529a1ec37206565515107b981075871983003a41fb8603ce464a2612b21902612b219026137e9cd0b613d4576589dac0046ed3dd870ee1e01c99649fb82612b21928984ac8640984b546760aa0b3138001a498b204ca10c8406250922509628314728db6354b49b1cd48c5d5093daac400481f27b577fa1f128cf2192b2192609c864ac864609c864ac864609c864d17b02bf72b1247da41cc3a393c73c6fc7fe0ce409c864ac864609c864ac864609c864ac864609c864ac864609c864ac864609c864ac8646069f4c2bf7ab3315fb086c0a747278e4668ce3920ef1863256432304e432564323069d2755d4741d555d574b73d17d2c1ebb10e32b0f04199316762ccc5989d24f2498f2191f19ba6100346e91ef25f50696bec6a11d2a2c4a2bb77103d02706c9c8647c7de98518864251ffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003011100021101031101ffc4001500010100000000000000000000000000000003ffc40014100100000000000000000000000000000000ffc400160101010100000000000000000000000000000206ffc40014110100000000000000000000000000000000ffda000c03010002110311003f0092da600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ffd9",
        }),
    },
    Cats = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc00011080200020003012200021101031101ffc4001d000001050101010100000000000000000000010203040506070809ffc4004b100002010303030204040403070202070901020300041105122106314113510714226132718191152342a1b1c1f008165262d1e1f12433254334728292b2d2e2172644535663647595ffc4001b01010003010101010000000000000000000001020304050607ffc400361100020201040102040307040203000000000102110304122131410551132261917181a106142332b1c1f042d1e1f125526282b2ffda000c03010002110311003f00f9068a28c57a65428a5c5045009452814a173e2848da294839a5da7380326806d0012400324d04738a5da73402514ec714840c5009c63bd145142028a28a00a28a3140145145005145140145145005145140145145005145585b78daca49fe6503a103d23dce6808141660a3cd0ca518a9ee2928a00a28a28028a28a00a28a28028a28a00a28a28028a7c9e9e47a4180c0ceef7a650051451401454d35ac90450c8e54899772ed6c9c7dea1a00a28a28028ef462b434eb04bb95d4ce32a3381dcfdf9a033e8a9248d51982caaf83804679a8e8028a28a00a28a28028a50283402514b8a4a00a28a2805a2a582de7b994436d0c9348413b2352c700649c0f6009fd29a8b96c55a8900334bb703b54a22c1e694a2b01cf3e454d16a23f4c88f776a60c019a9a42eb8c02531dea32328369e68c50d24629a0e0e69cd1b2825b8a5890c92aa01924d4114ec170c7eaa93e81f49ee2a59e2d80284fabb1150152a385dc4f391ce285aa86be33814c3c1c507268a156256a683a7da6abad4361797c2ca397204ac063763807278c9acba72ae6a28824b9856def26816649963728248ce55f07191f6350d38a81d8e69510b30cf6a9a14370719a4a9f01b22a2652b52d0a1b451455680514514a0145145280514514a05bb4b192f23b9749618c5bc6656123ed2c0785f735528a2940966b796dfd3f5428f51048b860dc1eddbb7e479a8a8ad5d02d745bcd5961d7b54934cb2d8e4cf1c2652182fd2368f73febcd01954529efc52528051572d352bab1b5bdb680a08ef2210cbb9031dbb83704f6391e2a9d280514514a0145145280514514a0145145280514514a014528049000c93e052b2b23b23a956538208c1069406d4f6a96af31177349147b188289b896c703191c66a0abe9a36ab268526ba9a7ceda64730b77ba087d35908c8527df18fdc7bd01428a28a500a921711ca1d8640f151d14a01452e081920f3da9294028a945c482d5ad815f499c391b4672011df19f278ed515280514514a014b494a0e38a00353c66cc58cc25494dd12be91523681e7350b633c5368028a28a50244778df72332372320e0f3c1a74609618addeb4d5340d6bacf50d4fa5f43fe05a44eca60b0f537fa4028079fbb0271e338ac5897eaab225226119e49ec3bd4cb6eb22ee1df351484ac5943f9d74adabf4ac9d05a6e9965d3b710f52c372f25dea6d765a39e23bb6a88bb29195e7fe53df3c5f8b355574ce62e1d94ec6191e063bd2c481829d9e7c9ed569e06b8d8eabf48f6ef5a969a584412871bf3d81e07deaca2e4cbc71b6cc2bc472aad8381df8ed49696f732092e2185a458b05d80e173db35d00d327b866b6334102b64fa933607ef5ef7d11f03341d4fe06eabd4b73d50b05f491c8feac6ea6ded7d12484909e72d8e79180cbc1f39caa3d8942a56cf99e42ef6ceec0efcf3c76ff59aaeb0baa025b01bc7b5757aa695059e95191756f705c920c326fc7e7c563399638561d898c6771eff007a9a2658f9e4cd7b765566553b57dcd1e9ab461db2140ee056cdb4314a787552b83b479aa574acec634518ef83c629455e3a566611ce3bfe556a18085dcf91e703bd68d8d8c525bb492aed0bc6dcfd44d7416fa769e74edeec3711dc3636fdbef5a431ee2d8f037c9c7cb07a6a0b272c78a6471b336dd9daba0bab785d7e8902ec1f84f00fdff2aaed0b25996e0103fa478ab3c6d1578f9318c65094c81f7351ca851b19c8c77abb0d8c9210c1c1e3df9a64d11446523e9ef9c551c1d5d193451a2971462b1a2946aeb1a0cfa35b6993cd7b6570351b51748b6d3891a25248dae07e16e3b564d2e28c52850953d95b7ce5fdbda7cc436febc8b1fab3bec8e3c9c6e63e147727daa1c518a50a26bdb6f93bfb8b4f9886e3d091a3f5607df1c9838dca7ca9ee0fb5414b8a314a142514b8a314a142514b8a30294284a297146294284a297146294284a2adea17f77aa6a33ea17f37ad733b6f91f685dc7df00002aeddf4c6b963d31a7752dd69ef1693a9492456b7259489590e18601c8c1f7033838ed4063d14b8a314a142514b8a314a142514b8a314a142548904d24524b1c4ef1c40176552420270327c734cc56be99d49ade8fa36ada3e9ba83dbd8eaf1a457b0aaa9132a9ca8248c8c1f6c505190acc8eae8c5594e4107041a74d34b713c93cf2bcb2c8c5dddd8b3331392493dcd37146294284ab2ba85fae9afa62dece2c5e41335b090fa6ce060315ce338e3355f146294284a297146294284a297",
            "146280d1d4b51b6be86c520d26dac5adadc4323c2589b86049f51b24e1b9f18159ca327da8c5490c135cce905bc4f34ae70a88a5998fd80ef4046410718a4ae9fa775ed0749d135fb2d5fa4adf5bbbd46d84367772dc3c6da7bf3fcc503863c83838fc23c122b99c50094f56ee48cf18a6807b8a9228da421157258d492911518a98c0c242841069188d8170322942bdc8a8a7aa337e119a42a41e46294450da2971462a2850b53447073508a9e3231c8ed572c87890105586478aae480dc1a9894390383ef4d58d5986ece3ed425f25ab0bb11929231d9df15a4d791881981c03f840c703dab26454452a89f8792479a851b77d07819ab5b5c1aa9b8f074f6d3cf758643b405c1c1fc55d0e997f25b74e6a5a6cad3fa77de9fd0ae7d3255b39619e7c738ae6f4dc148d0863c0c37815d24514b1468c044541da181e718ed5ac559e8e28ee56cc3974eba8adcbb8db904f27279fb550681847112a588041e7b1aedafa1017e653078c6cc648fbff007ae2eff724a1d63689881c118a99c2b92b9a0a05582d1448ccd94954fd59ec3da9f7567e98575cb10393e3f3a824b8fa59770dedc9fcaacc57d0fa89ea648236fb815455d1c9f2be08ad6072a647760a46466adce9a8d88896eac6e2d7e62259e1f5a329ea467f0bae472a71c11c1e6b36eae49188cec2383f714d9f54d46ecc06f6f6e2ebe5e2582132cacfe946bf85173d9464e00e2a54ab8466e55c22eb33105443b4a8e4e7c9a7dbfcc4ac20551b8f1deb6fa23a5aff00ad358934fb5d634eb0920b77b9f5752b9104642e32a188396e7b7d89f159b34f6e92e77fd6ebdd79ad135d9a469f9295d18e08ca8c821880d9aecfa1be1b5cf5c747f51ea71b38b9b4558f4f03b4b28fadd31f75c28fbb0af3dbd72f2edde1813fb57b274efc64d1ba1ba1b4ee9fd1f41b8bfbc854bdccb71208633331cb10064b01db3c7e1153094252fe2708f2bd4259d42b4eae57ff002790dbf4d7515dc2f35ae83a8cf121219e3b5760a4641c903c60fed59d716f716970f6f7504904c870d1c8a5594fdc1e457dd5d27d57a575774edbeada45c028ca3d58037d76efe5180edcfefc1ac7f893a4f4e6a3d2af2f50e8377aa8122468da7c3beea22c768753df033c8391f6ada5a25b37c6478d0f5897c5f87931d78ef93e28a2b67aa3419fa5faaf52d02e6559a4b199a23228c071e1b1e320838ac6af39aae19f4319292528f4c28a28a8a2c14514528051452d2800527b504118cd2a9c1fceaddae9f757f7515ada4325c5c4ec1238e35dccec7b00079a9a24a5457b9c1fece7accd63653bf50da5bcd35ba493c12c0dba090fe28f2a4838e39f7cd733d71f0e2ffa3fa6ac3e63426792295c5ceb16f70648650c7f96a50806323b7239f739aad95b4799514f78d97271c7bd32a6890ab52ea3a84fa75be9d35f5c49656cccf0dbbcac6388b7e22ab9c0271ce3bd560335f49693fecbb710e8bfef4f57f527f0ce9e8ac52f27f42dcb5c2fd019c6d3c0033df927fe11556d2ec86cf9b704f614608ee2be90d3a4f833623d0e94f849ad7584aa0afcd6a133e2400f276a64038008fa4773daa7bcbcf85d2c223ea7f809a8e876fc95b9b09a546518e49ddb41c718cf1cd2dfb15de8f99e8afa32dbe00f4b75edb2ea9f0b7ac267b75702e6cb56b72b2c20f7dac000e47b76ff009abc1fa83489fa7fa9b53d0ee4309ac2e64b76dcbb492ac4671fa54a765934ccba28a5a9a2429cb927029a4628a501cd9c83814dc13ce29c091c6460d5db782191002d8909ede08fcea68b256568ede591b622fd58ce2a37431b6d6ef5a8d346bbc2a9563dd88aa171233b93b40038181468b4a29220a393452862176f8a8a331b453980001ce72334da500adce95ea9d63a37a8edf5fd0a7486fadc305678c3ae1860820fdab0e8a502c5e5e5cea1a85c5fddc9ea5c5cc8d2caf8037331c9381c0e4f8a80e33c76ab30e9f7d7361757f05acb25ada6df5e555cac5b8e1771f193c556a0248943e41381debb38fa33555f8623ae6303e563ba36e6303ea54e07ab9f6de4afdaa8e81af5ee93d35af68d6fa6e9d730eb50c714b35cdb092680236e0616fe924f7efe3c815ec365f183a57a7f44d1ba4a0e9fb8bad1e3892d6f2e2e82a8643ffb8c2219df9258e0919ed8adf0c62ef7ba39755933e35178637cf3f87f9d1f3eb5cc8d217da3278cd4f69682e037a80a1c1c1c57dcf05b74f6b3a34525bda69b7fa64e988ca431bc4ea7c0e31edc7dabc13e28f4768fa3cd7fa8f4fe997ba7c566d08b947848b593d5076981bce08c32f8cf15d19748f1c775da39345ead0d465f87922d33c5160087eb180077aaf347b6acc892c87712185577620e0d7133da92455a294d25568c87503ed45380e3b549020524d3802a73ce478a68386e2afc48654501073e6a68bc5588ac560f57ef820f9abf6d68a6d1a648c306c71ed4ed374e3733b41296119040e3cd75ba768ef0da00cdb940f6ec7c56918b677e1c129f26669d6e6dad645f4cee51b8301dcd4d6ba83081e2241914f6c76ad978e68a0301555327e1dc3bfe55872e8f35b5dbed70ca7b9f038ef5a535d1dae32856d37ecee7745ea480b861dc0ec6b035b7b56462adb8b1ee079cd67dc6a6d6dffa68dc305279ed9ac6176d24e4302c376704f156965b8eda39f2ea135b49a64df6d1be4119db9039a8195627553ca8fd452dc5c2c8c235c819c0dbd854131241cf047622b03864d781b3309642634c00300039a6a22905a570bcf029d0c7b58b3f6f001ef48eaad2307263c77079a8af265f524f5591f01fe8c706",
            "afc22de54f5240db978181df8acaf502fd283e9e33e734e1305ce011f6a94cb29d1a394137d7b73e00e79fbd65dc83eae58f245466472e58b9cd34924e49cd4395a2b296e34747d7759e9fbe17da26a771a7dc6305e090aee1ec7c11f635dc9f8e5f123e55a11acc2ae7ff009c2d220e3f23b7fcbcd79a8c679edf6aeabaf20e84b7d7edd3e1f5eea379a59b384cafa8205713edfac0c78edf6ce40c800d239271e22d9cb934f8b23b9c537f547357777737d7935e5e4f25c5c4ce5e49646dccec7b927dea1a28aa1b255c20a2b77a67a9ae7a5ef2f6e6d74ed3af9af2ce5b265bfb7132a2c8305941ece3c1fceb102b1f1414368a502959197b8a0a10027b0a922f4c31f554918e0671cd44323b51524ae0995627c73b3f3ed5f517c15e85b6d23a7e1ea8bdb656d4afd736e58730407818fbbf7cfb607935f2ca9018122bec41ac49a17c02b6d6207114f06870985b23891a3554efec581fd2ab27c51127c51cc759fc73b6d03a865d1b42d360d49ad58a5c4f348ca81c1c1540bdf1e4f6cf6f7aedfa47ab343f88bd2d34ab6ca411e85f584f87d8587e13ff001291d8fdbc115f1a31cca5a4c9727ea27c9ad7d13a87a97a685e4dd3fa8cd63f3517a533458cb2e723b8e0fdc723269b38e0970e38367e287473746f594d630ee3a7cea27b427bfa649fa49f254e47df83e6b8d86c2f2e2cae6f60b7792ded76fad201c47b8e173f99a7cd737ba85dc93df4f2dccf29cbcb3396663ee49e4d5ad0f459b5aea7d37438182c97f7515aa39ec0bb85cff7a9f029d5b3e86ff67de80d074682cfe2375b987d6bb768b41d3670a4dd38e0ca15bf111fd3ed82ded5efda9ea575abce64bc7f501c811f7403d80edff5ae0dac2df51f8bf76b145b349e8ab48b46d3a2c10a25280c8f8f70b81c7dab1be247502d96aba168175a8dd697a5df49ea6a17768332ac218290a3bfb93fe07b1c5a5fcccc1cdbb8af27a3471a41108628c451af02345daa3f41c0a764e08c9c1ee33debcafe1b750897aa75ae9ab3d4aeb54d1a0df369f737831288c385e41e7043038fb7619c56efc48d7e4d1346b0812ee7b14d42e8413dddba86960847321419196c76e455af8b33ae68ededd4596c5b68c5b88ce51635d810fb803b579a7c5ae8f83e27db6a86d2c3d1eb4d0e05b981e38f0356b62a0b2138faa5521b00671c0ecdf4d2e84ea0b68be21ea9d31a2eaf7bac74f38796c6e2f86255da01279e7072478ce01c0c915d275987d0757d07e20d8ae2eb44bb8d2e7191eadac8db1d4e3c0dd9fd4d42e7945d36a91f14042491e478c54e6db109909c015e99f19fa557a67e34ebf69648ab697120be802ff4aca37e31e304b0c7d857026446b4960906194fe2ff00ad6d1e559d908a6ad992463ce68009ec3356a58d046a6319f7aaa411906851c685c7b8abf6c029c2a9e47048f355205466218e3dbef5a6ab35b88e4c07046548a948d20bc95dad9ade3df3b727b0354e47575047e2f35abab31942b9e64206ec7f6ac5ed46322a74828a28aa98d17f47b06d535cb2d3d63964f5e5542b0a966c67920007b0c9aa2461881ef5eadf083e245974575badc374c5b4a97d18b4692ddd9668b2c30559d98019c0238c8ae4f5beae8357eaebdea1ff0075b4a824b8bb375e88591a30776eda5770520f63c7393db351cd8394a2a499ccb3c92fa691ef62db106157273803c0a8ea450f1248b1b22bb047c6e00f071db35a3d3eba236b96e3a8fe7ff85fd5eb7f0fd9eb7e13b76eff00a7f16339f19a34f485a075951599ce06ef15b161358e9515d4726936d7ed756f2449ebbb0f418e36cabb48fa8738ce473daadb78b3658ad591dbfcb5b3a98b2fc73ef4b7f6a976aae23014e4e4783ed552ca748d996423776c7b56cd82c8e92abaa1cfd409007e95a2e4ed854d6d28e99d41d55d2b398f41d6ef2c4383ba38643b0fff0064f04fdf15a3abf5275a7555bc635cd6ae6f608897447c222b63bed50067ef4b7368b3446e0c612419fc278354d6ea5891a2555607c8e2ad4d2abe0c3f73c31c9be51e7deb933a10120753c4a49c827b564dc6ef539ed5b775b0b7aac5573e078ac69c71cf03c564d15c9d51568a0f7a2a8728a29c79a4a7007f3a92c2630322b4f4e2d248a3b01df1545626623f3ad0b58248dcc884fd3e01ab235c69d9db59c6a6111a2e41e738ce2b77484952260e8149e39ae7f47c1081ae0a961fa0ae8a2b97504ed057dbfcc574c4fa3c154a44925919edd16573bd79c76c54890d84716c6cbc87f1e4e091dbc506f206552ae40ec4f619c7f7ae7be61a1bf692377681bf10c715a706d39c60efb3275ed2e18e532a46047d94815cbff0f9564f5729b01c633feb35ea129b6d461648d5c15e7ea03fb572fa9694f036f4c3827924763f6ac658fc9e56a74e9bdf1e8c7d1d342583551addb5ec92b5ab0b16b6750a936460c99eeb8cf02b0252518a835acc937aad1fa6cabfe359f7903c327d4a41f358b5479728d2b21f51880c4e71c546cecf8dde2ae5c7f0bfe17642d3e6fe7bebf9bf576fa5dfe8f4f1cf6ef9f3daa2582dce9cf706f105c09420b6d8db994824beec6dc0200c673cd56ccacae3819a439a780067239fbd36840dc518a751403715665b1ba86c2defa48b6dbdc33a46fb87d4571bb8ce46370efef50515006e28c53a95719e466a40b144d21381da9c5803cae1a9627659461ca71dc524c3f9848208ef9153e0b781048429fa41cfb8a6bbb39c9c66933c628a822c4e69314ea284098afaa3aa209ae3fd976de3810bb8d2ec9c81e1418c93fb57cb15f6874dd95a750fc19d",
            "2b4c33a982f3478ed9a45c36c6f4f693f9ab0fdc5525e0abf07ca91dad9c7a7a3cb979d8e31560490b5b88cc4b110319ed914dd434ebcd3b58b8d22fd1a1bcb390c726e181b87191f63e3dc1aedbe1e7c37bbeb476d42fcc965a3c2db3d6dbf54ec3baa67fbb761db935d1b925677fc48c55f83ce63b469ee592352cc3dc7ed5ea1f06b45d61be30f4cdcc9a4dcfcbdbdf46cf3fa0c115707049c600fcebdef44e90e9ae9e441a4e8f6f0c8abb7d7640f29fcd8f3fb62ba2867920b88a75625a260ea09cf639ac259135491c92ccaa9233341d2a7b2b9ea169609239ee75bbc9d965c86605c05600f8da0631e2b2bae3a2adfabf4f862798d9df5b12d0cc532307bab0ee41c0edd8d7a3f50db7a9a92dfc00341788b2a9c80338e473fa7ef4681622f2f996e1d658625dc630db831ce07e42b2bb567179b3cefe1f7c339ba5ed2e2e8137b777202bdcedf4e3451d954b1f7ee7cf15b1d5fd052f53f4ec961750ba05612457106d97d171e783db04823dabd3f5bd5f4dd1ec51b558a66b69b317d16ed32e7190a428382dd871c9e38aa3d33acd8dcc49a541a5de699796f1b3dc5a4d113f2a77602bc98dac5b391827201ed8aa6ee68d2a3b6eddfe878af42fc3d87a4669ef6e2ed6fb50997d30e8855634ce485079c9c0c9fb62b7faced3d6e81d7e3993e936131da4e09210918039ee057a2f52d8ac4a97903084c8db64190371c7073fa572175a35c6b4b168d1461d6f64549882182c21819188cf6c617f371ef5a45a2895c91f3b7fb482ccdd71a047f509e3e9eb4f554f2c1b2f907ce7f3f7af0873292564e0fb1afa0be2b5e1eaaf887abea96a2378229bd083680774718d8307ce4a93fad7905ee965efd020197ec0f0335d0a0d451ec4b4b38c22d9cec209638e07dea3752188ce4fb55ed4ac66b79c6e8f6679001aac23c812fe203bd451cd28b4f6b2b60839c55e86798ec5192073c8c8a92158a58195554c98381e69c9098ad7d6de30a70479cd2898c5ae513ca4cf012dc92739071cfb62b36e5180195c55fb6be540c1f690c08dc476aa123334d86e01f7a965a6d3565503de9314fc6391fb5014927b715539c586596de78e785ca4b1b06561dc11d8d22bb2e7efdead347eaaeee0155f6c540d1b81bf071f9528b34d0c538cf03918a9442aa15a6dc013ed4c41f5062b95079ab8d01da1f195233dbfb5098ab257d90cc8101d98ce3edfad58b978e48e3fa09e324a8c6055676d8b968813ee7b01550cd21756192a0f03156b3672ae0d7b3b00b73bb1ea6e19e3c56ed9da4f206f4d762639c2f8cf6acab0b89a792368c06743f8471c56cadedcc574e8917d4307e839f3578a476e1504acd59b4e0888843139c8da3c1f7acbbed356de4fa536ef27835aeb77ea40d333e2571c64fe1aaf730b4f1a4bea02ca093cf15ad2a3b6718c9708e73599e1bd6b7f96d2edec45bc0b0b184b1f59d73991b713f51cf38c0e3b573d22314fab1c1c57591e91a86b5a8c1a669d6deb5ddc388e18d580dec7ee78ac0d4ac6e74fbb9ac6f21f46e2091a2910e32ac0e08e3ef5835478f9234e8c66001a4c54a2292495628d19dd8e15546493ec0546410706a8720b8a9631fbd45566dd09619a948b47b2edbc3b9c2e315b12db3ad9fd0a59bdc0aa56f949148c004f735ba04c501573b4d6a91e8e282698dd25c451bc58df331d88a71cf38c7f7ad8bb92f74dd567d1b5a8fe5eeece468a484329d8ca7182549079f20d7197feaff342cbf493eddcf9ad0d06089ae6017f23c36fbd7d5911376c4c8cb63ce0678a26d1a433493daba3a6ba99e2b02a5163908ce48ce07f9d63dbc9730c8608594ab1c027b8aed748d0a2ea7eb19f47e9bba96fb4d8707e7658fd3091f009652339cf0079fb57aed87c24e8cb5b448ee6ce6be98779a4999093e7014803f2e6bc7f51f5dd27a7b51cadb93f0bbfcfa3d2c7a7c9a9a9c3a3c045c4b68a62c88a571dc540f6d34bfcab8b839241fab818fb7b57a27c45f859368f67375074d4d3cd6d02169ada46dcf0a81cba9f2a3c8ee3bf23b79526a13317848f524da0973dff002cd7a3a2f51d3ebf17c4c12b5faafa330cb196296cc8865cc0e67218efdadc015cf6aeafea8123176f18f15dcdae892dc593de94b8654655675425016ecb9f738381e706bdff00a2fe0774b5a74a4177f11f4c7b9d4a79c5d4165148c924716000b2904601c12573fdf353accf0d3437cfa38f2627354bb67c796d637976ff002f6d6535c4a413b6142e71f90a75d691aa584425bdd3ee6d518e034d0b2027ed915f660d2be251b9b8b4d1b5ed1fa2f4547296f068d64bea18c1fa096c03bb18cf3e4d2c9a47c58b681bd0f8969ad06e5ed758b05962703c73bb1f7fc8578cfd6b44a5b7e22fd7fad51cbfb96a5abd9fd0f89319ce4d262bed69fe0ff48f53e857d3ea9a1e93a2f575e5ac91acf605d6c56639dade99ced6ce3240c77c0af90fa8ba6b58e96d7aeb44d6ac9ed2f6d9b6c88dfd88238208e411c106bbb4dabc7aab78b94bcfb98e4c33c54a6a9b3182839c9c518a7ec21b04534820671c5765190dc518ad7d03a735aea9d58695a0d83df5e98de511230076a8dcc72481c0a8b45d1ef35ed7acb45b0f4fe6af265863f51c2a86271c9f150419eb90720669fb1cfd4abf6abbad69379d3faf5ee8d7fe9fcd594cd0cbe938652c0f83e45551732a2ed0dc77a944aaf2122308558c65724aeec70c4633fb647ef5063ef5d269fd6daf69d6fa4dac725b4d6da4dd9bdb786e2d9254f50ffc4187d43bf07dff002c73f34ad3cf24ce1433b16211428c939e00e00fb0a8",
            "e4322c518a5a2944098a314b4528098af65f839f13e1e9b71d33afcbb34a9e4dd05c93c5ab9ee1bfe463dcf83cf626bc6ea589941e579ce41a55f62acfa47e3a47a45c689a35ddba5bb6a17b36d4bd439dd028e46e070c32cb83ce2bd834bb1b6d3346b2d3acd40b7b685238f1e401dff5e4feb5f1bcd79069fac470e9f7f69ad59d9ca92465e1916097852ca63700e09e0f0338afa4ba13e258eae8a46d574b5d1e57b868ed9e3465b59bc88919b8dea08fa73c8c11ed559c6a2a899c6a2923d0a8a718e458c48d1b843d98a900feb4dac4c0dfd26eedef2c5b44d46411a125ade763c44fec7ec696d9ef3a7357ff00d4c070c36b283c3afba9aafa0d8d9dceaa916abba38590940f941237b67f2c9aefbd0d20d9ad9c8f04b02fe159650f8fc8939aa6ea655c6c6da6a36976a1ed6e9589f01b0c3f31dea49eea0b78f75c5c24683b6f6c7ed593269fd1f14a6396e2c63917babdeaab0fd0b64534d9f45e79bcd3f3f7bf5fff003d2d13b2460f506b43509e2b6b6576883623555cb4cff61fe1fb9c579775ef587fba3a55de93693c4fd59aa446095619837f09b7e331923ff9addc918fd9573ee909e918a2923b6d474e88c8a519e2be412608c70c1b23f4af97be3c74a741f4fcda4dc748ea623bfba9246bbb78af0dcef5273ea16258862491df9c671c1adb138ca54ce9d3635bd392383d2e3f4f700490782792335467d3259ee64926899648d8e180c71e2ac694ef2a0477dca085db8e73f7ae86fc082d94aae508c15ef8f7af4f6da3eba305921cf48f33d6ed2e58912866439fe66d396c7fdeb9595444020390a4e2bd2756bed4a5b28e19a476b788bac5113911e4e4e3f3c66b8194b497ad8405893f61cfb573ce34787a9854acce47f49f7143da9f24e195b6b3206e4ae7bd5f8f4ebad43508b4eb0b39ef2ee5fa6386de3691dcf7e14727cfed58ee1d1da3752a54e0823045667049b8f035896ee694b1640a7c79a6d155321d1a6e70b8ce4e2b71f4f48a11eb800e3b81dbfd1aa5a644925c61cedf209f18aea6e92de6b17def955ec09ad231e0ecc38d38b6cc28adae6f23658e48235489e52d2388f214676827bb1c703b9351a5a2dd5ac843b0645cfbe692559d5f1918f007635d1e8d6b344a1adee8c324830e1188c0f626895b2d0c6e72a2cda7c30ea89fe1f4dd411d946cac56e2288b7f3da101b2e063b1c838ce4819c76ae320b79d5d724edcf2bef5ed72f5df5269fd1b73a3bb44278996da3ba0099444c0f8ed9006377b1f7c5798de2ea92ed965924972bc348c4e07dbdaab18c937b8aac128b7b97463de2a3cdb503043c16f7355e087648c8fc71f49f1f9d68451c6b383745997b1cffd2a696086efd336e0a95183819c7dead56365bb1f6f31b1882a72f2ae32062b46c7e6272ac2331a8183b4f8fce8fe0b2cf6b05c0e76aedf39ed57b4c80585e8877964dbc6fe393cd5d2676e3849349f432d8acd71f2b1e4c87383838eff00dab56f2136566708588e0e39cd4165e9c3a94ca7080b6f5c7dfbfe95ab7b3c5711aa29ee7ea18ad52e0edc715b1b7d9c7dc4b73000e8cc8e183a95ca953dc11f7ae6a669a699de525998e493e6bb0d495426c236e0f7f3f95697427c3cd77acf53ba96c20b716765ff00b925cb6c52cca76a8e0e4f1fa773584f8ecf2b50a99c3cf06bdd29ad5adcb4777a4ea3084b9819818e45c8cab8ac691de595a591cbbb92ccc4e4927b935bdd5435f4ea0b9b2ea59ee25d46c4fca3faee5ca84fa4007c8f6f7ce7cd73f591e7b1477ab70b15031ef5556ae42b918ed5745a1d9ad0b7d2a594735d2e870d8cfa9d95b6a97ff25673cf1a4d725777a3196019f1e7039c7dab99b756550c08cd6aa9f53612db71df1dab548f4b1be0d3ea7d3748d3ba9eef4fd1b52fe2ba6c53ba5b5deddbeaaf8623fcfcd549eda14d397d3729296e70de2a94c8e602dbb0ea49539edcd4114ef3396963632e720fdbef5355c32db92e1a3e9df8536963a5fc365d6245113dd1927b9908c10a84a8fd00527f326bc2fa97aef57d7ba81f5179e58d776608b79db12e780a3c78c9f279af5ed16ee64ff6679ae49024f94b8539c11833329fec6bc3ee9552c96578564cf3f4fdbfd0af91f43d3c726b357a99f3253715f449ff00d7d8f5357397c2c7083a5567ab74f7c6eb1d3fa40c3d4b6f757ba8c4de9c688a1bd743ff001b37031c8f3918af19851e6d56e6f6ce01696d24acc9016de22424954dde700e338f159e826bcbd5e380780078ae834bb66b09c3997258e586daf7f49e95834b9679b02adef9f6fc91e77c7c9a871591f08f61f8636f25b596add597b1fad63a484686c998fa77178f910ee5ec76e59bf6c57b05e6b53d8f4ebeb9d4d71ba786dc4d76eaa07d58e55547dc8503f2ae2ba3e08bfdc0e94b68d432dfebb3cf3e32771860ca8e3c7ef5d4f57e88fd49d1da968d148126b88c18d9bb6f521941fb12307f3af97fda4cf1967c5a79f0aedbfa5d7fb9dda78bfe2658f32e97e5ff00254d2faaaf26ea76e9bea0e9dbae9ed4dedc5e5b4372eadebc27ce47661ce4738c11dc1abdd41aff00f044b282dac25d4f53d46716d65650b0569a43cf73d940ee7c5798fc3de8aeac8bad935fea84b98458c46288dccc24794ecd8aabc9fa1549e7b7602ba6f8a3d2fac6bba7e9ba8e83ea36a3a64a5d238df6390707721e3ea05548e7fbd7859b4fa25ae8e38cbf86fbe78bf6bfb79f2463cba97a594daf9fc71fdbee743d37d4c35d9b51d3efb4c974bd5b4b9bd0bcb09983143ee08eea79e7fea2bcdfe26f4c0d6fa4f509267175aef49843f3",
            "25363dd69d313e986ff88c4df483edf7adcf857d27ade8afaa6b7d42b2c57da86144733ee908dc599dce4f258f939f7ef5d76af616f73a9ca93c61a2d4344d4aca71c8dc8b1095707b6430f6f26bd3f4dcd8b4bea72c381dc25f9f4aff00dd18678e4c9a58e5cabe647c3b3db0f99c9ca823cf7a6dcc2a625311dc7c826a5d49b64e029ce40a75a32bcc03458c0e7dabf40955d1e3d2b68cf88cf6ae278a5785c02372315382307b546731b2ca8fb181046d3c835a70d9594f7d2adf6a42c6db63b2c8223265802553039fa8e067c673592c57fa78aca8c5aae01999d9a4762ccc7249e4934da28a8a2a1452e38cd6ce87a1dbeaf69ab4f3eb961a6369f68d731c776e55ae98103d28f039639ff5e00c5ad4e9ed6a6e9cea4d3f5db7b4b4bc96c6659d20bc8bd58a420f665f22b2e96940b9aa5fc9abeb57baa4b6f04125e4ef3b456d1fa71a1662c55147e1519e0781550231f15a379611e9e6cda2d4ad6f4dc40939f96663e896cff2df2a30e31c8191cf73551dcb487907ee38a245a868b5b96b67ba5b791a08d8234a1095527b027b03510e4e00ce6b7a0eacea2b4e91bde92b6d49e3d0efa75b89ed0229123ae30738cff4af63e05612825c63b934a2a58b77dadf53e0f6c0f35edff0535fd3ff00dead17a7bad2fd1ba6adee64b98209d7f90b76cb88d9ce3f0e4f93b7279f35e27346776f5030bc671deb434f33b02bbb0bdb19fdeafb6d6d3782e68fd42bd92d60d3a6b8d45e38ac510b4b24c71185c72493c62bc47a2faf7a6755f88b2e9d34696f66cce2c27958ed91b76137678048e467b1e3be2be69b4bd79b498ad66d467f4a33f444f2b1453f653c79abba75edb24db18176439040f39ad31e857316ececc5a386df9df2fa3eebea1bbd2b4ee9ebbbdea09121d3a34cbb4be7d82f92c4e318e735f2c5ef57ebba85bb0b7952d531ff00c85dbb81ff009b935cfcb3dd6aa912bdd48f120fa11e424203e07b55a0ab1600407231dffbd7461d2430ab972cf4b49e9d0836e7c9cb1b12b7334921333939667f27cf358379986e728cdf590401dbf7aec351b93020728161638607b83589736d04c733b8524e532303f2adb32b7754693c692db139543259dc1c9049e02e41a8ee5f57b3b5b1d720d3644b16ba2b05ccb16627963daccb93c1c64647b1a875032c73b4c87e9dc4648fef591733c86da3b62ede9a3160377009ee71fa0fdab8e71ae0f172cdff002a3b7d63e226a3d4dd517dd49aadbdbc177792ac92ada465235daa1460127d877279c9ab563d4a97904c2e5b8e4a8dd9cd7230e9da8c1a1db6b525bedd32f2692da29b2a4c922005d719c8c065e48c1cf154a6768a46cfd0ac4e31df1ed548c9a54ba36c5a99638aa7c1bfab5f99546c5660c48058e31ed8acfb3126d323e0311f4e45509b594f4d635841c7393dc559b4b8139c4aac383819ed5176c8f8aa73bb352d350d77a7f5db4ea3d12f1acf52b524c53a22909f4953c1041c827bd72fa85bcf24d25d5c48cf2cae64777fea24e49fd49ae91e491adb646cce99e093ca1ffc563df5c3cc843b22a8e39ef50d2eccf3423d983b1b76dc734053cfda9d283bbbe7357ad2ccdca3bfe0d832739cd6747128dba4334f4325c0466283fe23c576779757a745b6d3a5b92d6b096745e30376377efb47ed55f4ee9e87e595a52543024311de9d2ac67d2b7556978c64723fd76ad54691e962c528479f26046dbee645c0da7805bdab534a335a5d2a327079c7fc3ed53bd9490606c1bf390138cf1f7a6ab2168c86c3e7054e6a52a118383b7d9d13196eaddd19c4848fabee2a3582592156c8f4c9e37f8f7a8acdc340cbb5e2751c306e1bf4adcb1b741088e7991d08dcc3dab6efa3d2c71de735a86929206914e15b04823bd58b4d0d51636b4cbb9c6e24715d26a53da0b6f46cd44a5bbafe554edae84119672164ee100e01fb9a8da932cf06353e4d1b7b4b6b3b731b02cedc9da7207dab3ae6c15642f082c5f95cf9f614b6b7cd3c926c0b88fe96da7fc2ae4b33a0cc682423dcf38356e19d1f2ca3c18969a3dc19de5906c5393b4ff8d413c17697c8496d84723b7eb5d1cb7517a2a031dca3f3e3effbd65bb87864693248c609fdb02a36a309e38a548e7efa525883f4ba9e0f9fd2b7ba27e23753f4bea73456f7a9736f783f9897a0c8aacaa70c39183fe3e6b0e6843c8ceeb827818ac5bd842be0818cd6138df67959e3bb9657d6fa835ad6ef2eeeb51d4a7b87bb90cb2a973b49273f87b003c0f18ac02306b42e140381c0aa2e39aca8f364a8551cd598f0bcf7fb5561dea7538e477f156422769ac6b7d397dd31d3763a474eff000dd52c2195350bdf54bfceb16055b1e3001fdf1d80aceb2b4d52f61b99ade21225aa89a56dc06d4c85ce0919e48ed9ac78cb04dc3f7a73ddc980d8c63807157aa5c1d119522fc9eb994a48eb8233cf39a1db29b848b1b28e5478abdd45d567a9f50b1b93a55a6962daca2b422d136abec18de7fe635cc4f3e652637241ef93dea2c9791559f5b7c3ab08f59f8136fa43cabffaa82e6d99860ec2cef8fdb20d7ccd70750b1bd9b49ba49639617292c6fdd1c1e73fb5773f08fe275bf49de49a5eb5230d2af1c3171cfcbc9db7e3c8c707f207c577ff00136cba4354d73a4eeade3b6966d6af53d5be824e248015524e0e0fe21c9e78af8bd2e4cbe9bea5971648b70cadc935f9b7fa7f447b73d9aad3c2509538f0d7e872bf0f3e12ea9ad4e9adeb129b1d2df9451cc9703dd41fc2bf73dfc035ee563d0bd276107a316876f30f2d72beb13ffdeffa574491c70c6b0c51ac71",
            "a00aa8a30140e0003ed4eaf8cf50f5ed6eb66fe7718f849d2fcfdcf734da2c5823495bf7352c2de07e9b9ad60822492ca61711aa46015561b58ae071f7c53218679ee2385d149760b97e0ffd6abd85e3d85e25c2286032ac87b329ee2b466b5f9691354d30fab68183291c98bfe571e3db34c197e3638b76dc786be9eff5f67edc7b9c79f1bc591a5c2972bf1f6fefff0046b4e745d02c3d7be912d6dcb047ba9410133d8bbff40f19381923deb3ba6f58d2359b46b053752dd47bde582fa22258d77e14bf70bb860a8ce48e71df1b569aad95da0c4ab1b9e0c6e707fef5625bdb5850b4b75181dff1649fd2bea213c3f0fe5aafd0f9e97c652daeece6b53b01633a7cba298dc646fe483edcd715d4fd41a5f4d58ea3aff51accfa7d8d99b4f4e3e24965b960bb236e30c22473c11c1e715d7eab7ffc465792331c56f6e8499277091c63b96763c28fcfbe38af917e33fc40b6ea7d62dfa7f4393d5d0f4e76944c54a9bcb86003cc4781c6d41e17f3ad3d1f45f1b54f5115505d7b37d70bee6dabcb28e158a4fe67dfba3cf0c567a86ab34968af15a3ca7d3499b73469925416c609c79a92eacd2083d58642aebf48c793f6aa967b96e4ed60579ce692f6e276814fa848dd9db9ed5fa05707045c54795c99931063d8c06e07bf9aa9fa54f3bbbbe58e73e6a1ac1f67249db36e2b2e9c6e89b8bf975a993a812f1638b4e16c4c6f015cb4864ec086e31ff5e30ead5858dd6a7a95ae9b6317ab75752ac30c7b82ee762154649006491dea29e096dae24b79976cb131465ce7041c11c554a915399197f10c5490a024bb1c05edf734f9e4dcaa08e4791e6ad45ab8b2b514b4b83ed5054546c119ce052ca0172c8491e73e2840770f1f9d4c1f686caee1fd8d4975ca1d6d6c268cb12dc7b0cd4e74d6118972727b2e2ac69692094ed27ffabdabaab4b1b50544a199bf3cfe95a46168ebc5837a30ecf4a9ae51091f460631fdeacc5a6c16d2c8d31909c6718ed5df69f631b46aa8a8a813eafabf6ac9d734b9448cf119040c70e3deba5c29268f45e93643776642470b48208cb38030bcf6f3e6b59d618a389a28181031bb8efec6a8e9ba4df19d649602916de0839e3c57476b650c0de81669ddb180463ef568c9dd9ae2c4dae551269cf3cfb5846df4f07c56a0b99371915b2a83fa8556d30b4534d6d28285891b7b7152cb00818c6ae4a1ef93db9adadc9f07a304e10b22ba02e2d1e5e58938201e0fb572ef6d72cc0cc0c887ba2f700f9aebd6dcc96c523e109fc23b9fd6b2d11216953d225b382ce78157963737f530cb1ba6ce1f598521451010cebdd41cf1ef5c95c9c5ce0a0207807bd775a9d983785c1c29c93c633feb35c6dd424dd158c6ee33c8ae2cd16b867cfea23f35a2589a15d3c32c59719fd01a7faf1346a4213e0a93dbef55a1899a024b72a39c9fbd31a19ca839daa49ff46b9ed996e75d11baa7ac5d885c9236f91fe553a5cbc676a7273dc0aa6eaf92581cfe5562da33f2ef332b14185c81c29f1cfe40ff007aa144ddf05a86f6e22dc15cfd430db876a89e1665dac393ceef15d0eb0743be8ac63e9fd3ae6c996d505d1b8943fa928fc4cbec0ffa02a3874ffa14071bbb3336781f6ab24d9d1184a68c2862b68889246242f75239aecf43d29757d4ad6dad810d33e022ae703f2f60324fe55952d9471c05dd87d1dc81dc9aeafa2f5cb9b0d6e09a3b680a226d04a05dca46082c067b79a9a6baecdf1e3945ed4b936754d36eb48be92278040607dd1ee1b95d413b48ce410719e7f5ac9ea9ea7baeadeb09f5cd4a1b48ee5d1148b387d341b400381df81df35d0f56ebb777dab345b618618d0a22950c7b9eec47735c22c1235f45106581e470a5e5ced4c9ee7bf03be6ae9369392e4eb96edb1735c8cd5754544c2a664030bb7c0fbfbd54b7812fed0dc48c164419032460fdaaf6b3a19d3ba8aeb4f3aa5aea56f6970d1adc5a92d1cdcf0ca4f8a44b19eca27dd086427ea6cf6a98adcccbe69bdcfa29da5cdba5e7e2324aabdcf009ade791da344718246768f3f9d73af098d8cd045b7ebec0671ed5ab1c21224334a5a5cf241c6735749ae0b629349a20babdd90989213eb0ce1831ec6a95a6a3712b233c65b693f88d6d35ac12a3461333360026b3c5b4715d2961f503b467dfdea24b91253b4ecddd1a333c9eb4b858d72700e47fe2b4678edc5d2c321fa4f05a33cfe759e91fa3a788c101b393e99e3ff14d835085662ec7f9c98da08183fbd597077c64a315166bc965146bbd6400f61f955221044c063eaa96c35d92dba8a2bfb778ff0090adb1678d658d89520e55860f7e2a348e1f4b3dc8e39e0e2a572c972527f2ae0c8bd0a17083b0e6b99d4002a413dbcd7497ee1776de0f815cb5e6f673ce71e6b39a3ccd43326504673cd536ee6adca58f73e6b6353e956b77d061d2354b5d7ef358b65985a69bba596de46247a2ea0677fd87fe79d9e4c8e757bd5841db355d6a6ce5303bd490894c842e0771ce4546b2164c37e1cd22b1dfb4018a91b66361423f2a92d630ca028da08e319cfdea0620b123cd4f2dbc880657f4ad5d0fa4ba87a92d751b9d0b4a9efe2d361f98ba68c0fe5273cf2793804e064e01f6350f8ecabbf2622025c0ad58774091ba4ac189c6e538db8ed54e1b7f5241918047735bb0d840d6cced237d23776c015a2836acd7145b7c1f577c2feae5eb5d2acf4c124b71aec101377988aa1da701cb76e4609edc9200ed5e817ba6de69fb7e6630aadd994e413ed9af98be09fc52d2fe1d6bb7f0ea7672cfa7ea088934d000d2c2549dad838c",
            "afd47233ec7c62bbcf8abf1f2db59d22df4be839aeedff009a26b8be92311b6003844073dc9c93f6c57e77affd985935125a64e29f2bff0055efff0047d161f549c5253e52fb9ecd69a36a17b07af0c23d33d99982eefcabac8351d0b4d5f4367ca4a14074311ddfa9039fcebc43a1ff00da2ba7ff00dd9b6b3ead82ee0d4ede32a65b6815e3b803b10011b5bc11db8ce79c0f20f8a5f12b56eb4ea97bdb16bab1d15635b786ccca57781925e40a7058e4f1c80302b7f4cf41d569b2350493f2e4ad7ff5aa7fafe261aad4ad57192f6af6e3efd9f52ea3f13be14e997cf677babd989939711da3ca17ec4aa900fdaab4ff00173e0fdb4c62935ab5dc3cad848c0fea1306be308e6e155508c8c904f18a8efafad640ca5cb7d3e7c57de63f46d36c52c9dfe097fbff0073cb942ba93fb9f60defc64f81579a749a6ea1aa59dcd933067b79b4a99e3620e412a63c1e6be43f8a97bd25ac7c44d4b50e82b136ba33b2841b0c6acf8fadd10fe052790bfd8761c7dcbb9988520fb7355daee409850463c9aac70c31ba8b7472a493e4734c2388a2b9639078a8c3ba8520fe2ee48aaf21dc77f9f2734a1891c8fd6afb886c74b1eee517181cd56a9c3919cfd5ed9a88e73546558f43185c9fc54d6c6ec818a6529248e7c54014e73f63534507a8bb8903d87bd419f7ad4d3dd1a4c33260760c3bd4a56cb455ba160d37d452400d5599921764d809071c56bfcd42885225cb139ddff08fcaa95e4c814fe02de303b559a55c1b4a292e0a2cc661cf18e3b5022709bbfa4f35165b3f4f356ad658c4ea2789a4418ca83838cf38f6aa192e7b2cd93b9055093ff37602ba4d25fd49186f25989033e7dcd65ebd7fd3d2750cd274c69d7361a5b6dd905d49ea3a9da3773f739f7ff2a9e599deda34b42c3d31c9db8ada0d51d58655cfb1dd68b3dba4854c8ccdb886c9ce56b7d956e808d543c20e0927c5794d8ddb417eae2465dcd924107f315dd5a6b8eec8360642718033935d58e6bc9ede9f5119476b36c9b782e04601f4c60007b135625b787d2f5091db70fcaaa22adc46c246c2120918e453ae814b32617dca576a9ff8456b5cd9e827517c193777805e89e25dbb3196cf7fceb456ea294ab3e199fc0f1ff6ae52ea4ba5645c650e17b78f7a496f25b256da783c01d8815ae1516cf325a971b6ceb11c7cc32c632071953f878aa37974902bfa80b04600f19278a87a6fa8ff00876af69a822c73c90bef3148a76febf7fbfe46a8f515d3cf7535c12b0faec64291ae02e7c62a67b9cb8e887a8b836ba306ef517b8b816d1465da5611a0e06589c019fd6b3b51d26f2cf51b8b5bb87d0b8b7768a74dc1b0ca7079071dc78e2a1b80f70de995e49e01ed57934f9e0b6f564903a038001fc5f6ae59294dbb3c96dcdf3d199a5e89abf516abfc2f41d3e6d42ef634861b642cc554658e3d8015443c66d82920c80f0338ad596eeef4ebe4bad1ee2e34eb90853d5b7768df69186195c70467f4ac98ad03a36c25dd70401ce4d7138bba3169a9517a0b0965909b85650391819cd6c41a96a3a7f4edc74fc7383a7de4e934909887d4c3b738cfb7edf9d4160e2dd4ac841c8c0cf3fa53afaf659a47520009c82318ff00cd59c525c9d4a10db6fb29b5c3acde870847d3c540973245297dc163ce2a9bcb3a5c07917e93c815691a37b53eb22eef183cb554cf7b6cbbf3323911ec2f1b30008f22baed2278e1319dbe915e18638f6ae76c63b4bc9add6532476cd22fa8f1aee655c8dc707009fb66bd7be1af4f68ba9758df5ddacb25de9fa510d0faf18432b12446cc9920636938f7c5736b3590d1609ea327515ff4bee7a5a48ca59125e4b56ff0df5bd721f99bb782c63914321973bce707951dbf53fa5731d63d1bad74b58c9777082e6d72156e6139553e030232a7fb7deba7f891f15750d23a8dba7fa7e74b7680e27ba2aae4be32546ec80079ef93f956bf457c45d3baa7a6751b4eaf92d2da4b74d93b4ac123b989b8c807ce78207d88af915ea7eb38f1c75d9209e3957cabb49f4ffc6ff03d39feef924f12752f7f07864705cde08ee59197d323f17193db8aea34fb582e88db87471823ee3c1a74fa75959de4d059cd16a164cccd6d347267f97b885dc3bab71d8f3d8f9aedfe1be83637d757ba96aa48d27488be66e7681f5807e98ff363c7e59afbec5923b1646b87f738a118c16f917ba77e0bdc754e930eb13ddc5a358472edf5a58c932a01cec1c64e78ff0058aaf6bd35d0b0b6cd2fe1f752753b872ad7179726d149f24220fa718ec4f93e6bda2e7591a8d9437f2c434fb44843c7033055b68c0c8cf8181dcd67699ace97ae5a35d693a8c37d0236c6789b215bbe0fb57c0eabf6932c724d6385c53efc2efdbbfa724cb4bf15a79254df84799cda0f45b4ebfc4ba03a8fa6b38c5cd9dcfcd471f80595c739e7383e0565f5dfc227d03a527ea8b0d4c6a7691ca9bb6c255d11b1cbaff41191c76fbf8af61d4b58d3344b4175aaea10d8c0cdb03cafb431f61e4fe953aea2cba54b79a708afe29a12c22c8922ba423953e1830c8fd6b3c1fb479a7282c91db16fbf7e57bf5f5e7ec4bd36c4d4256fd9ff00967c7934d2226c27f94aa76e3cd43399e48d411b00030d81dabd1fe2474659e857f06a3a2ab1d075788ddda863f54393f5c23ee878fcb15c499e30bb1816651c363b0ffad7dfaa92b3957cd1b6ccf8db64eab0b1980392e73c575d2e91abc1d3906b72d84a96173234514e71b5980e47f8fec7d8d733a53d9412ea2ba969b7178f35bb476ad1cc63f424c8c391fd5c78abd16a9746c1",
            "2d7e6a56b78d8b2c4ec4a827f11033804e07ed5314db18f234dae8c7d4e45597248271820573b772ed5c60e49e6b7ef409f7ba1da071935cd5ec4578ddbb68aa4ed33933b7da28b918a769baa6a3a2eaf6daae93792d95f5ac82586785b6b230f20d562492734c358b3cd6c51dea455cf9a60a9236dbdea42170c8c081c83de9ed38392739f614f77478b83c8a80c4eb1aced1bfa6cc543107048c6403fa8fdea7a2cf8e898ccf220dddb156f4bb9bdb54b88ac6fa7b61749e8ccb14a504a9dcab01f8876e0f159a1d8b718ab76e5448aeec464f8abc69be42e59ad6f6c88784024078cf9aebf3d1bfee0003f889ea6f9dfa8650db7cbedfdc36eae1239985d03b898c79ef8ad189edd23551920724fb9ae8752e11d38da1d359c12a3cb08f48a8dcdcff008d5d8ed77db225bb894e06ec8e57b13f9d125b45337f28308e4e3e9ce3f5a9f4cb17176d6b0c724f264fd318c9000c9c01f913fa569185cb93751a7d176df495f978a62199972771f23daa84cefb5e29233ea0c15fb1addb6999637b775063c72cde4549259c2f03ba6dddc1e4939fb8ade78ab8475282947e53985b7956459dddb206d1f99aa3710b0b82c57ea6ce0e3f4ad19ef1543c5e9640383eca2a8bea491cac3d35c6dfa467b7deb19497f29c5351f733a5b5911972e093ce69b77a6cf0e8906acf25bb433cb25ba2acea640c80124a03b80fa8609183568a7ad6524cb30249c81e45639888243af6f7ae69af63966aba228edf72062dc138a96de079265b7531aee70a1e43855c9c649f6a960630233100b7b7daba569fa325f86e47c95f0eaff9ecfafbff0091f2fb7b63df3f6ce7ce38ac9aa48a52317a8f4493a7b5bbad1ee2f6d6ee7b56d8d2da4a248db201fa5bcf7ac2a91d9998963cd378c76e6a8518dae9b4dd1fa6ae7a075cd5efba93e575db39a04b2d2fd127e6d18e1db778da39fd3ee2b9ac5150d000a4f614f4fe5caa49c628456ce55735d1fcc4b71a05ae972c56ff002f04b25c232c28b26e70a086931b987d23009c0e6ac97b178c5be8c8694fa2c47d5fdaa9b9690eeadef97b730e2341829cf3dcd67ac230032f183923fc2ace26928328abb050aa00c739a5327d60aaed3f9e6b66f3a4ba86cba52cfab2e3489e2d0af677b7b7bd206c9245ce40f3e0f3d8ed6c7638c444dcc073545f431bf00599db2cc6b7edae5e1b34f4ff00183c93ed58613695c60927deb46c37b36c68bd4fab38f1568f66d89b4cdb82de3b8b662f204e0b07079fdaaa437f2dadd15f5d9e2078c79ad96b75974d7cc601c6e38038f38ae4a5252e0e1b2b9c671826b67f2d1d595b85347a1d9ebacd62218be8cafe36eff9f150cfac4ebf47aecf839603b63b5718b3cdb5584ca8aa3c1ed5a16c1ae52429300cdc1238ada391be0d56a65254685d6aa7d10aec1803c151dbfed4f177f3106e950851d8b1c9c553b5d52f743b1d4aca1582482fe3104beac21dc0ce72a4f63ff9ee01096771eb3c6ad11ce30067815be2c8d4a99cfbe527522747304ccc0f07b607f8d4d24cf23e2460fc6786c939ab1716b1950ea5a23b7ea1df3592bb639d0b92a738efd856f34e34c9e63f296e25db7aa5e354da39caf35a7327af6caac71c6403d8d66a5cb49723e5d77071b73c77cd5f68d9ed8965ccaa768553823ef53192f08d22b86accb92ca22ae2638761dc9e3354d6116703ec1b987727807ed8ab732ccd6ea8a8c0eee0f355a4b597d49119ff001632076ed5cd2c4dcad232724ba4565d4b6b92ea012319033522aa926491be9750413fd3f6aa77101b53f5ae7c027b0a8e5b8796cc43863b7b73926b9a69dd328a6d763ef2dd67997d363c28c8c7f7a6ccc218d5e35dcfd8e79c8addbdea9d5ba82cf41d36f6dec841a35b1b4b768605899c139cc8472c7fee7b924e2dd4121954fe10bdc0e7158ed756c8bb4e49172c6f59e5c06c11e00f35ef7f045268a5ea092440a08b72a339cffee135e11a7da2b16995c314193c62bdd7e06b3b49d42252c40f40609cf1f5d781fb4abff1395bff00e3ff00e91ec7a6dfc68dfd7fa33c1b5369f55d5ae3509b72492caeecacc7b96249cfe668953508a68a3650f192006c64135d5eada1ff0004eacbfd3ee2111b5bcec14f8299ca9f7e4107f5ae8345e91d43a9ef5a0b2808863c13331c2a03ee7ef8eddebd75970e3c0b339250a4efc57831869a536d79b3334bd5eece9a34666c59997d72a540c391b739c67b57b6f49e91141f0db4cb35019758d6b75c11e63863ddb5b3f739e299a47c2ed1ac21c5e5ccf76e46182e1147e5c135e8fa7691a741d290c5696c14e9574658c124ed1226d63cf7fd6be6b51fb4da3cb09e0d3b6e54da75c709fbb4febd783d29e9658e1172f75fe7de8e3be23daead77d0976346467b98a48a731a2e4ba238661b7fabb03b7c818fb5721f0c750ea5ea7eb9d7bac75703d2bd85629a48e211472ca36850aa38caa8393f7fbd7b35bc5f373a4290fd6c700a1c01f9e6b66e34fd234cb226eaf208656472925c1017e952cc42f9c0049f3819af96d1cf2cf4b3d3422a9befdbafa73d7e4736a638e3a88e69b69af0781fc4ad53aa7a5bacf4aeacd1541822b392d15e4844d1c4ce487054f00b295c1fb63ec773e1269faa69dd0289a947243eadc3cd6f1c830c919031c78c90c71f7af5eb1b4d1b57d2e19ad2ee0b867892432dab7d2430ca9dbe01e719c1e2b2aee036572f0c916e75fea63907d8d5b573cd0d2474d38aa4fbff008a2ba78e29ea659a0ddbf079c7c46d2627f86174f05c032e9bac895222a47a51cf164a03e4161bbfb57810586188",
            "a4b0005cedc364e7f2afa17e21df2da74a185cc6926ada9aed5238686de3da4fdbeb73c8ef8af11d42d105c3928180c6067b66bf4ff488ca7a4c729f2da5fd108c5d4e4bdd95edec6d46933c81e53765d442230bb0a60eec93ce41c7ef58d7d1cd05a88c292ea720e319adb8e436eaa85176e382a7b7deb3aee54623e92518702bd3963705699125171af232eedf441d2163736f7f249ab4af20bab46836ac2a0fd043f66c8ae2ae3715642a011e4f9ae86eca0b73226361e0823b5634773e8bcb2359c371ea44f181282421618dc3047d43b8f19f06b864706655c1852284cd563deb5b57d2751d22f8d96a9652da5c0557f4e552a76b0c838fcab29bbd6479d2014bd877a415d16ad69d210f48e8773a3eaf7d73af4deaff0013b59adc2456f86fa3637f5647e7fa76a1539e04f7cd5c9756d4e6d1adf4696fa77d3ade579e2b667263477003301e090a3f6aa429e91efce0f35340653d776e0d9fb66868994723f5a960459240247d8b9efde944a5cd1b56d0412c411d580fb7b559bad3e381a18e3908cf71df1ed8ad5d0858ac0c0be59063732f07f4aebba8d340d5ad7433a168634eb8b7b3486ee51217f9a981e643edff007fb0ae95e151eac706e8aae4e2ad1ee13f17081b1bb1e6ba3e99d6b58e9cd54eb9a2ea0d677851a23261495561b4f0411c83fe745be9b15b874932abff000e3b13c558896d915edb203eef6aeb84537f3746eb03aa908f6caf6a83701ce4914f964f4a38e20a58e73f6a963b22d199a394fd07b67218fbf3da9675d92c6e0e587257bf3e726bb9493e5236d8d2f6399bfb65954b72a841278c639ae6eeac833fd182883ea24e735d6dfc12cf337a88ca84f0479aab6cfa6daeb96efa969e2fece19019ed04a62170a3baef1cae7dc570668a5e0e0cb0bb673913471048c0057be41ce692f228dd42052ee4e401e455c7b385e6692d5046a589542df846781562585231109b0e546588e0d67b1b5f439d46d53305acf0ccf70cc80606dee6a02148708e3d303b1ae96e21b7b8b50123fac038e7bfe75cfadab19d63c0024e08158cf1b45270a7c12eb963a059dae92fa2eb136a134f68b25ea496e6216d3e4e63527f10c639ff00432eda38e6b848a594448ec019082420cf2703938fb55c7b658c90f820719352685a0ea1d45d4363a2e96886eaf665821f52411aee63c658f02b99c76f660e345feb5d0748e9fea79f4fd035e8f5fd39150a5ec4bb55c95048f6383c71fe39ae74c4c002c319f7ad1bdb1b9d2b58bad36f8aa5c59caf03ec70ea1d495382382323b8aaa2379a7046e94e0920027000c93f9003344b814895196344dbf5672715784848dca18aa8eca781fa563c84ee2c38fca9fea48d1e379c77c7bd5933453a3a2b643756c2dd1434a1c150a393f6fbd55bc8c262168b6cb19fa879073dab6ba1341ea0d51f50d6742bfb1b59740846a0cd733ac6c361c8280f7208f3c7604e48079dd4f53b8d4b51b8d42f2633dd5cc8d2cb29e0bbb1249e31e4d5b727c1a3c89a09eeaf4d8c7a735e4f25a44ed2476ed21288ed80cc17b027032477c553489a33ba45f4c371923347aa4fd414effce92433b801c9551c609aad1970461d44cb85fa0e33e6b7ed6570a675848118eddab312ce1521bd60c4fbf18adf8d90fa51464061c12478adb1c79b66b8d344971abb0856de38c46ae3eac0e4d733752afaec7d3c166e0fb0ae9ae6ca28d44fbc485812bb4791fe15812470453249227ab12302ebbb1bb9ec08f7f7a8c96cd336ff00240b72b1a3ab270dc022ad697722097793bb91c54dd5ba9e87ab752dc5e74e685fc134d60823b3f58cbb085018ee3ee726b32dc2b0040e41c93ed55c72768e58c9dd9d8bc91bc659d49451d80c11ff007aa7049b6633c60f0485dded5424bc710aa99491c03c78a9a1d90fd4c58ab721738fd6bd2dca52bf63a1cecd1c5edddc18ed6d679c05dc446a5b6fdce2bd2353f83fd551fc228fa9c981dcb2df4962b9f59612b80dec4f2095ee01f718af2d781e55129c8651c7b01f9d74379d7bd5127c384e9193a8657b259f68b5246444064296c6e29bbb027038f6154d42c9c53e2cc64e4cc1fab4bbc8e1bbb792dd88c8f554a9c7be0f8adfb39e3691954f18efdf35e792c73336e058fbf1dab674cb891d950310477db5ae1cf7f2345f1e47167a24fa0ea8fa09d763d3a41a5098426e3036fa80671febf2ac75b68269cff2b2d8f03bd4506a574b07f0f9ae65107a9ea08771d9bb18dd8ed9c719abf65796e93b6541553dcf915e8292a67642a72f98c5bdb58de192248f255b203e78ed557f823c687ea4518e40f06b73519bd6b9f988d5b0e7809fe1c55d686dfe5e2755732b0076e718278cd704b1c653b35f84a5673f06820202855b0bb89cf8fcaa8ff0d2d392cac0104fb6ec575f2c8ab6e9ba328e41190bc7e5566c2cd44a37a7e1ec09ef5cd38a6e8dd69632a48a7a6ddcd69d0d7ba0c7a3d938bcb88ee05ebc3ffa88ca82362b7b1cff0073ef5adf0f75793a6fabc4f79398b4f9229126091972e71955032307701cf8e6a2bf6961726244446e0e718aa6f05b1f4649088e4c0ce3fab3f7ac3368b1e7c32c1957125c9a2c4b1cae0f947b175ae9dd39a8e8d1f538d934d848e3963231303d837dc0cfdc76aeb742b1834ed06ceda0031e9abb1031b998649feffdabe76b896e208442cee62ddbd554f19ed9ff002af59f871d53f3f6567d3d751c8d76bfcab6600b7a83c29c7623fc3db15f9d7ad7a2eab07a6c70619bc91849baf29571f6e7efd1ece1cf17376a8f43abda5df7c8dd969177c12afa72",
            "a7ba9f6fb8ef515de9f796214dd406356ec72083fa8a75ae9b7d7b1b496d6ed2229c16c8033edcf7afcef17c6c5953827b97d3fb1d591e2c98dee6b6bfa9a520b8d32f61bc576b9b46398a4ddf4bafb7d8d6ccd168daf5a243796d6b7f0ab2ca21b88d5f638ec76b7623dea6b5bae9eb4b436ab2c710231247367767cee07cd644bd45f0da072b2eada5ab0383f531c7ea062bf40d1e8f249ff027195f2d26dd3fa34aebf147c8669efe258e5c79aed7d57fb1a715be8fa2a5c3db5b5a58fcc486697d18d50cae7bb103f113ef5ceddde3ddcb71a83dc7c958c007ab3b37d30a63b9f7623b01dc915797a93e1a30dcbac6967f57ff00a554d73a8fe156a5a735a6adab585c4112311146640cbc7250281f563b7debd187a4e7cb963fbc5ed5cd24edfde8a63c9f097cb095bf2d75f823e77f887d433f54751fcc5b20834fb4416f691e79110279207f536727ee6b99b6b391ec959cfaeec7fa7fa7ed57d228aeef25f96f516d416f4cb8e76e78c8f7c55db6b59227c1c18c0efdb9afd061fc35b23d1ede1d346957472f3c322ccb028cf196e3001f1597740a3076418dd8381fe15dbdec518705576b63f166b9cbb4f558230e5727e91dcd56726ccf2e0dbd339ad4a51e86dce467b8ae72797e9da3b5751a8c6aff00479038e2b98bb0b1654e3278e2b966791a8bb33efaf2eefae0cf7d752dccd80bea4ce5db00600c9f6159e6b5752b5d32dad34f92c754f9d9e784bdd43e8347f2cfb880993c3fd203647be3c5659ac0f29862b46eec3d0d274fbaf4a45372243b981c3056c0c545697bf2a8cbf296d36e39ccb1ee23f2e6bd27ab3e255cf50f41f4e6912e83a7c2966a46e09b8128020dabc6c047240f350eed5107966d38a7c6a49c2f7ab32ba4d2b4cd1471eefe88c6d51fa544b13924838f357a2f421918a98d97b52c2ac14b18f7e3fb530b11dc6493ce6aedbca8b0b967d9918a944c55be4e874791248c290a1720907b8aeb22bd8be58080a966fc4be4e7f4e2b80d3219e490ec62c339e07debafd3a16489a468f25792c3cfb0ae883b3d8d2ce5546d4f3b44638e4dc03aee2e3b63da9bf2ccb0b48497ded956c608fceac19edde3596e114960001ff09ff2a9e59a25902962a47014f39fd2ba949b8d1e93826eecc786fa6b7baf45c31881e48f00fdeb6227b73b9cb972ea70d531d3629a252ebb88e3818e2a0fe1d25b3ed71b63e707c77edfdeba21c45a6cafc39c5fba295fa2b90aaab90325738c57073a349333b39474248f3b8576774970f72f0fa79390dbb3deb0efd6dc17de313b0da0638ffb5714ce3d447773d14b4c316f91a56daa7ce3b54376d0904c4728c7f1119aa31b5c99fe563663bdf040ed56657458840e08c76da3cf9e6ad195aa3cd72b8d13c2919b312ee3ea31da79ed598ee2224b282412c081dab46ced0cc155cec849ce49ff003a27b7dd3945980894e3f0d68d5c515716d5a321e5f520de71cf007639aa691999181054af9ad99ac24219a2c6e619fb56348489c2027fe715c79153e4ca49aecabb7b8ddc0adae9cea7d67a56f64bfd12e45bdccb0c96eccd1ab828eb83c303cf9cfdab3e5483d48c2ee3b80cf14cf4dbd564442013c7dab071f06743608c4926263b4119e78a898147215bb7b1abe96d3346d905dbce3c55696da5806f74efda8d12e2d2e8ad93cd5dd26fd34dd62d2fa6b182fe3b79448d6d720b47281fd2c3daab7a7f492c70ddf151e706ab4674765d5dd5ba5f50b69afa5747d874ebda5b1865f933c5c3ef2dea1e063838f27efdb1cc07f98dc1dbea3ce7dcd572c5bb72df6a6292ad9070454ae384593ae0ba660a40070138c9e7fb55882e449334cee11b1c565649f3de9c1884fc5cd5b712a6d1d6fcec5269dc380cbc60f6358d7ef1b2a84ff87191dab310c872ab939ef52cbc429fccc9e7e9f6a972b36965725c9013f51c1e2a55902804723daa0a9e38d9b8da7155473a34ed61f5d0bef2c3daae398818c021bc7e55561478a168b7e32339f6a8b7ee424649fb739af422d451a5d1b973748b6cd1a81f556244fea5c1042920f249fc42ab4d3bb008b9c8ab36b185640464377a4f2fc492f642db66b43665c08c1508c39ffb53a2b578a4636ca4055ee3cd5e85618add5f703c6768e4d549f524588450aeddcc46dc77ae87b22746d495b24b99cc765e9f79079ef8af46f843d2d0750c3ab5e6a9fceb310fcb2fb891f92c0fba81fdebcf96063621445809f51c0ee2bd3a1f8cb61a56876f67a374cdac7781544fe9810c1bc2052555793c2a8c923b553e23dcb77479dea71d43c3b74ebe67fa19517c3feaf3acdcda47a6493476d2fa7eb921636fbab311918c76ad39fa5758d2605b8d434c951514e653f5018fb8c802bd53a3ba9e0ea8d020bb2c897ca83e6211c6d3ee07fc26ba2e0823b861823dc7b7deb7db6b83c65fb45abd265d99b1a75df77f7ff83e6c77412b472a9d8c7f0e3807deb2f50d600bf708c17d15c2ae719aed7a944177a42f5126817bd3ed25cc968f637918462cb83bd00fe920fee0e2bc7aeee253aac725cae3271bbbe478ae4c896d528f93ed31fa82cd8564879fd0eee09ae0dafad31077f00b37607ef53c764c2447bb90b2b8fc3dc03e2b22deee096cda19a6e4118c1f6ab66f0b9113be180c29fcfde8ad793d1538b4af92ecab0bc5233361d0edc11df9ad4e82f8910742f5b8d42eec1ae6d2488c13ac67eb8d491f52e78dc3038f2323cd622d8e2d9a5999e4639fa7db8fb561dce8b7c34e9b56f498da46eb1bb770acc09507db214fed5c99f1ac90709ae195cee5b4fa27e20fc6bb",
            "0d4fa7974ce8df99f5ae5959ef258fd3f4941ce1064e49c724f8fcf8d7e82f8c5a70e968ad3a923b95bbb552a27862dc271ee4646d6e79f07bd7cb506a896d0ab613d4dbd81cf03ff35b1a4752db4216d656c8230a4fb9f15e647d2346e1b1c79f7f3f7fec531fc269424f83bdebfeb8d4ba9ba924bf80dc5ae9a408d2dd643b594700b60e0b1ee7c550d2acb5ad5744bdd52ded1dacacc289a7500ac458e0679ffc563dc4f98506e055fd8d538f5bb9b669ad527716f2e164895caab1078c81c1c1e79af63169b1e9f1edc4923a5cf634a2f83a3b48e610bc72484b6720fbd56b89f706529f5270093e29897cc8a1b2591971939e0ffe69f1470ef320046e3820f915e8423e4e894ed6d89ab6ad63e8c260b6f979047895bd42deab64fd583f878c0c0f6a9a6cec66524606722a94d20b7877fa5bd88e31c62a78275961036b2923b11dea93c6eb723a714a315f0cc1bfbf05e35e3d4dc33e39f6acf924041d808519047bd6bea7651fa7c614007ef8ac03bd5bd05caaae473e6b8e57e4e4cb6a5c98dab3884158fe927b572b3c65d4b1249fbd757a9c6c49c8c851fae6b9bbd4748d8818359491e26a55b6604a06f3511ef534830f509ae768f258a056de9771a51d3750b7d52d6eee67306db168a70890485c12cca41dc0ae7818e7fb62819abd6c076c7353565a2ad8f30ec8f76ccfdaa55443011820f7c76ad0b5804e06fa924d25fd65112ee0d57da75ac4ead182b6e8c40cf3cf9a956ca79ad4c823ca86efef5d25be928171769e9b29e3eff6a9ada062937cbe02c64123380054a8178e9df920d1ed98c6638cfa720f6cf26badb780c4a91c681cc9c923fceb0bd3532fab0028df88a1e39ff42ba5d3144af1c89290078cf9ff0059ad608f534f04be522b97922dbb42c84724e7f11cd6ce9579e84d0df9811668250e3d6883af073ca91823f3a58eda20ee5a3dcccc719edc79a6336d0d6c655dee7f13f381f615ad1deb1d72fa2cdbdd446768565064625988181fa54e6e616936bb0f4fb82c7cd73b7b12db4aacc5806190c31c55393509a0b9dbb090bdc6739fbd6f128f51b3e568dd9da39ae1cab86d839d9fd81ac3d52dad2eeda40a816420047ce306953517b6b396568d9646c6148aa91dcc66d9a494fa9373c1e2a935c72613cb19f0625b697744bac876b27e13ed517caa0058cdf42f048e79f239ad896fd2391a4277b14ec0fe98aca8af05cdd3a88576b13c67209c56149348f3e5182e119ce2749da085db03b64605473c8635003e1fb30f0c6b7ef2d7d4b483748b139193918ed58b751c6966c03166ce55f1c135771e0e59c5c49e6ea7d66e6c6c34fbd944f67a7c4f1dbc66355f4c31c9e40c9e7df35ce997ff0055bd54e0f38ab2d3bfa187e4fbf9e6ab2a09189008c7615cefaa472b6f848b5616b3dcdf451c1119a563f446aa599fec00ef5d3df74675358e9c2ff51e9fbeb7b66e7d46848083be5bd87e75eadf0eb49d27a1fe1bcbd73aa0596eee22322370591371548d0f8663dcfe5ec6a6d07e2e5cdeebf1db6b1616b6fa7dd108b2445b7439e3ebc9218723278f3f9563be4ef62b4888ca4ef6ab48f02baf5ad648c8701c8c103b62a18a4590fa441c7b8ec2bd53e28f4e68569d4525ce8f7501f572d35b40c0fa3267ea1c7001e081e39accf879d29a56a17d36a9d4a8f0f4fe96a2e2f9e104bc8bb82ac4a3fe376381e7009f15a771dfe0db9adde0a3a57c26eabd7b483d4115bdbe9fd3f1a34936ad7b2fa76f1056da72402c79f001a7ff00b8df0f13e89be25dcc920e0b59e812c917e8cd2293f7ca8afabb5aea5d261e968e0bdf97d1fa6fd25863b29542c42323e94651f88e3c73fdaa2b1160f630c9a6adb9b49143c4605508ca7b118e2b87e2b7df079f932f3c1f28ff00fb22d635393d4e87d634deaf8948f516c1da39e05edba48640ac173fd4323df15e75246f1caf1c8a51d0956047208afb9b46d47a6ff8cde47a0dc580d4a0606e059854914838192a0670463c8af02f8cdd3165737baaf54e976296779677a20d5eda15db1b8941686ed17fa43f2ac0701c67fab1578646dd32613be19e2617352ed575fa7823c7bd308ec7b0a9a36046c38523c815ba3644655d01da720f91519c93926b402816f82bc9f22a9bc6c1fb77e6a5aa0d0d182e09e479ab58fa9486fa38cfdaaa6dfb8abd0329558d8fe608a98af72517e3479981c8240c0078cd68e89a86b1a15e35e69737cbdc4b0c96cc422be52452ae30c0e32a48cfdeaadbc7e8c46503729380178c7b5599ae63b6188f0c48c9e2bb6ae36cdd457fa8cf96d04672e8011c0acf904914db09e01e0f6ab9f3c1a3cb3e72d900f7150df4b1b04923e4b73f95633dad5a33755c1a163724c4cb82580c1c550b99a679f734b855e5573cd5169e5dbc3104f73ef51162cd93dfdeb394db541ced51d2595e5cba8842fa9bbe8403bb1f61526b1a1eb1a15ecf63ab5a9b5bc5552617e080467c560c770c13612368f3ed57ee752bb999ee6eae1ee27623749239662318ee7bf02aca57df45b7df6747d35aecfa76a16f7514d2c13c5801e324115e9edf16b5ab552a64b5b8017832c3f567dc918cd785da5eaac8ce4e78c63356dae9c665e18b0fa73dc1ae98e6a56278f06686dcd052fab476dd53d7bab6b6c8da9957da3f951050a8a0f7200f35c04d3c77138673c0a8e7925b9d864c9918f0064fe957353d2e4d36f3e5e48e688670a668f6e7819ee3dcd63932b9b216d8258e0a92e91b9a7db996d572a14e4156272715d05b4102ce3d53ebaa8e5871e79e2b97b1bdf9680c4efbd88daa7b1f",
            "d6ade95ac09a678d7ea28300b93839adf14d2ecf531ce0a9793ab79f891205da7f0e5ab9bbcf51267136e6c92a0b1e31ed56ada631cbb49215cf0739e7349aa24b31880da00e7f3ff58ad722b4d9b4a5ba273f3e91ff00b9212a30339ddc1159705d84bd2922ec03807c715b174f2987611866fa4a81ce3ed58a9a75ec8e418d9515b76e3f9d70354f83cfc9c35b11d6c7a92fa202bb30650b927efed4c851e78bff006cefde46e3dcfb5436c924291b6d525cf919e3edef5b709f4e548f67d1f8b70f7aed826e9b3ad5cff9997f474970d1b8de4723f4ed5d401fcaf5180dc3e92a7c7e959da742b164aa0e461893deafba29dc5016272c71e4d75b69f0951ebe0838439e4958fab08c633ee3cd471c6dbb11f0c0f354b65c4800497681dc639ab891ccb01562cae392c3be2928ec5d9b465bdf288afa2c867da063dfcfbd7373a7a65a527f170083daba69a0fe490cfbc0e79ac3b928aa19f18c7ef5c12e4ae68f9306f903f638fbd733a8270464d7417b298d880783ce3dab02f5f77d5d8573c8f133b4ce6e78c87ef554d685cf393540f7ae7678d254c51c1156e1247355077ab0990454a116749a7104038ef5d0c1190a0af8ae674c7200561c1e726ba88a431dbfd27ed5bc4f634f5441711c8c195d7e907230719a769d681e406157fe6606def9a86e6f1a4416fbff001720f9a6e977cf6976a9b4ef24a804e466ac9f26b71deacd3d4a092d1c410c5ea16f3b7fb56de936f2db428b2204271838ff002abfa481703370eb2b0feac71576fc2c707d046e0464f735aa8f93d5c7812fe2265466731b154c91c71c1aa126df57f988d19c6eddd8fe55a3f33194dcae0b21cb718e7deb3ae9be6d4ac5f88fd5b88ee3c8cd5e9364e47c70417770d26d6c06561b37e3354a7d3a5760f012dc73b8f8f6a8ee2578912d836101ce08ee7db35406b72c425851c9917383e6bb124a1b99e4e4cb173a992ea58bb516c8c56541caa8c0ac39a09e34f4da52429e08e79ab4b79248f1c8ee15091e307f5abade8b5a3ac6188077373c9ae492df6d18ba9f26259aa5ca3c20aef63b439fc47f6ab30416f14db00723bb6dfea39ab5f2a96d730cd1152a48e478a9498e0691e20d9c1ce718ce783cd64b1b5d9118d7632f183c205d61b2f93ce48e38e69ba3eaf63617734b71a1db6ad6a22923582e490aaccb80c3ce41ff00b60e08598b19247946015ec0fe2ac6ba8dd236720467b927cfdaa5e3754ccf34acc3bb2cef90bb00e00a6c00aed5720063dfcd3a767964043e4f814e8555d14c84020fed5ccd73c1e7f6cf69eae2cdf02fa2ace03b9656dd8e7eada1b1ff00e23fdabcae6ba7b750a63c30183b5ebdb974a6ea8ff67dd1ce907d6bcd353d4540396642e244fcf6b67ef81ef5e41d37d2dac75775226976788c83ba6797212141dcb79fb63b927159e392517f896c73518bf71967bd6dfe6172109c0dc7c11e7debd7be1d5a477fd17a45b32a91a9f52117283bba5b5afaa8bc7fccec79fb76aecf42f869d2fa35a4693590d4ee140dd2dd8dc339cf09f840fdebd0347b0b23a44da5da595b40d030b9b758e255030bb5c2e07076e3b7702b0c9a84d6d894cda8528ed89c17c40b2eab32e91ae749bbb6a1a6cb29f4d1559bf989b4b056c8240dc3b670d9abfd0bd37abe91f0f20d2ef048972cb2b65016f437e48191c65739e3ce6bd1b40b486f6fcadc3a4eb126f08467273c724723ed5a9ab5c6ab16ad6ff29d2d3df416a7709a2bd8a20c08c001188c90ddc360003702c7e9ae26e99c1149f0d9f38f4574d75b5bf57e9adaf068b4ed02da5b4b773b42c88c5be952bcb02cdb896ed815d275ee951cf67aacb247fcabee9ed4219b20fd46dd56e61233c7d2ea79f6638c77af68ea3b2852d52ff6c56f3960ac40ce723b76e48f7af0bf8c1adae8bd0fa8ce6757b8bd81f4ab5c3658bc855a76ff008805894293db3301cf357c7df04c6dc8f918ff00a14f8549638380064d30f7a72139c03dfbd7a08eb46bd904688a63736383ed9aab720ef118c86a7432adacc84e4a8e700f7a5b99d2e67dd82a7ec3cd6cea8d9b4e34671383c1e69d1b346c1f1f7ab13dbac718932093e2aa7dab26a9993e19bf06ac0c02168818c1fab8e6aa5ddc9918a838079c1ec2a95bb32b64123f5a7b38c12ebf9715bef938d365dcdb5c90946771ce4e2a36c93dea4de028c139a8cf26b0746620fce8c668addb9d0ada0e8eb2d7d75eb09ae2e67685b4d4726e21033f5b0f638fee3f4af0418a1c6d20814dc9f7ef4bc6dc79a4a926cb6cb66e2dd6d52656f487ac6570417c9c95c0185c6383939cf35b36f6b1a5b2b64921727778ae7d0a8e40e6b66d8b4f6e5669044aa0006b5c68db1559b5d37d5561d3bd51a76a371a3457896926e6c16dfd88dc3276ee19c8e3b8fd6ba8f8a7f125baab50b1d3a1b00da7698a4c5f3390ecee0166fa4f031818c9ed9af30793d19981dae3c7dc53649e4bab8691db7b3e0163dcf8ace58d39ee7d947cbb1a93b23121db1e467bd5ed3433c85c7f2c0393f5633505959896eda300b9f03b56f2d87a1080caaa0f39cf635ac22fb37c7094b9342d649607f4d07a89c90c7ef5a261949de920f50760be07f9d63dac6c275579495032431c023edf7ade92e22b648da2daa9bb39dd9c1aee4f7aa67a38952b665c915c9ba2d3292eedc93e6b56ce06c321856325412d8fda9b71791dda6f893615e59bb73f954d049eb4ea99df100082bc83f9f9ab287846915152bb223e806ff8dc1c019fef5ab630a5cc04a85f500c8c1ede3159ec3d7d4554a6d5638fa4631e2ae846b6",
            "98c300db9e549ae858da4b82f092dcdbe8d5911632238e4db8c739e7f6ab885991803bf3dce2b3a0db2cb1862a24fea238cfdb35ad1db4b6f642e987fe9a47281863f100091efd88ad24d25477637cdf49944dc881cc6cbbc6ec652aff00ae0a8f4db2071cf93fe7554ca1aecabc785ee50ae0e7de96e239170f182501c018acab73e4da32da9b5c8cba959811d94f9c8ac0bd9442859d7961c1f15b97092288d8aed63c7deb1b5781258426ece0fe55c9923ec6795b69b386beb969242d193b33c827354669818c2e6b42fad5e3fa723613c0c76a8351d1b51d334fb0bebcb3315adfab35b392312053827ff35c5274f93e7b2369f260ce6a93726b7350b8b2974bb3820d363b7b9877fad72b23b35c64e572a4ed5da38fa40cf9ac46ef5933867d883bd588b25b1508a9233b5b3528aa3a0d386d519ad9f988da331fb7201ae7ed250541c118f6adbb058e47762a55bb726b689ea617c522de996f1cd70c64c9e3b78c7835b91e8b1b5d45f2f1337a98553c939fb554d2232b3132aaaa1fee2bd33a32c05debf13c811aded7370c58e36e3b0fdf15b4636764a50c1a6966c9fe94dff9f89517497d1a692c2e53d299090c01ce7f2fb551b8dc64950a954c70c2bd6aeb4cd0f5cbc173248b732c0be9bfa32f8e70188fd7b54373d25a34f1148d25b663fd68fbb1fa1ae9f86fc1e461fdacd2c71c31ea6328ceb9e385fadd79eba3c0af85c413b2a6d001e5c79fbff7a8e1dd0459966c64908738e6bacea8e99b9d12f1a49ee15e1704ac8bd9c8eeb8f07edf7af38d4f5249908b5c1c1fc38ff58ac1fcaf93d7f8f8e7059b1cae2fa1979a80ced6503fab824fed588d248cdea3821c9c0f7c7e95656448223ea05c1e70bc93f6cd52174ab956230defcfea6adbf8a6cf2f24b73b66a5a46ecaadb3318e73f7ae8ace38258c3601cf2e324607bff6ae3adeeee43184337a40e3e8f6adc8a790cf1c96ce0855e739cf35a45c5f46d86697827d49edadb296c063b81939fdeab2dd19add24dbbca1dbee7155351c4c519a42718ce076f14cd3c149596319ce17268dd4a90736e7f4340dec12ca8ab962382879e2a8eb2c1c9fa0843ce0d3e1b0b98e7bb992d2578e2c34b22a922207cb1f1cfbd616af333dc9db2123bf06b2796a2d332c92f9792a48e89306072def51172ca36820e7bd4633efcd2b39d9b71dab8db38ecef7a0be20ea3d0d712ff002be6ec2e594cd6c5b6f23fad0ff4b7e9cf9f18f4af869d71a7ebbf133a85e68d6da7d636bda2b1192109fe5e7c9db83f7db5e09777cd7ed6dffa3b5b7f978161c5bc7b3d4dbfd6fcf2c73c9f35169ef02eab6af7324b0c026432490f0e8bb864afdc0ce2b1941493fa9569347dd552dbc9345751496ec526571b187707c568eadd55f0bb49f86cdacc5ae69d716115affe9645b957b99d82fd0bdcb972460e471ce7183597f0b3af7a0babba40dfdc5ce9f65a9c6585eda5fdc22b438ec54b6328473b87dc1e4579bcd5d186d67767a77508e78efed2482d2f7ff991a926327c91c700f91dbdab591758f4c7a96f68cfeeb2b007f4db5f267c44ff00684d4ad7a9b54d2ba0af849a75bb848750695e4dfc7d5b14e06ddd9009ce40cf9af1b7f8a1f11647777ebad7b7392c48d4251cfe41b8ada3826d5b0b19f7f6a7a0ebbaa9cdc5c408880948e16239fb12a4027b64838f63dabe29f8eb6fd5fa5fc411a7f56fca4605b2c9616f612992086dd99b0016018b6e0db998659b27b115c91f895f113ffebbea1fff00e94dff00e6ac0d4f55d4f5abf6bfd6351b9d42edc00d3dd4cd2bb0030016624f02b7c58a5076d9a461b4a3479a5a2ba28b8acc588e7b55cb3bd6b1d42def5ade0ba30c892fa3709be393041daebe54e3047b552a31405ad42f1b51d46e2f0c10db89a4697d1b74d91c7b893b557c28ec07b525b44ac4ee42d819a895403f555f88a04c6f181df15a4173c9648b17da45e68778f67aa59cd6773b55fd39576b6d2320fe4456593ba3c0248cf9abd7d793deddfcd5e5ccb752ed086495cb3100600c9fb551018b00a3bfb1ab3baa6417e7d4aeee3a72d747296c2dad679275758104a59c2820c806e61f48c02702b208c1c639ab9b97d209b463cfbd42c8002c32467bd52515e0108fbd2e2a63091097c1db9e3ef53dceab7f77a659699713efb4b1dff2f1ec51b379dcdc819393ef9aa34d1052da48e055fbed1753d36cf4ebbbdb6f4a1d4a13716cdbd5bd440c509c0391f52918383c54da1687abf51ea91e93a2584f7f7d36447040bb99b0327f4159f3413db5cc96f730bc3344c51d1d4ab230382083d88346813a2a8fe594e71cf350cacc92b01951ed52c6309919fce9e62924f4cba86cb019ff002abbe8bd59499b7f7f02ae5b0f4d77e0107b73561eca140006faf382a3b7ef5a5a36897fabadd2697a7cf79f27035d4e624cfa51263748dec06473f7a45532ea0d3e4dad4754b6d460d324b6d1ecb4b7b2b48ad246b48cafcc32e73339f3236793f61544ea1133188f8fab07c8a58e2665f40eec0c649f3f6a8a25b7927757859e4076f3d87ed5d096d548ec56a9219717d24d3298142af7031fe756bd39a72b134c42fdb1835763d2a1911da2fa71cf3c7e6055bb6b07404a22b305c20dbe7cd68a2db3558a4df26758c9b91a3997e9070011deae5b6a10d95d08e0e1c9c81271c7e74b6b652fcf8cc3cc782549c0a86f2013dc13085dca719f639ef576d978c6508a68d48752018bfa7be566c9c0c0c56e5b5fdbdc42eed1b4721c6d18e16b1b4db2930af21504f19c673fad6bd969c5662aea48dd8ce3bf35d119",
            "52b6cecc4b23f05a8617c0b899c6d6381b7b9cf8ad2482320f04718c79cd569e0224c8255148000f357e1996580b346720e3b56d293da9a3bf1412934c7ce2491fe6242d24ad80ee4e4f1c53f7c47690738f35564b80b36c41b58f9f149ebb7cbc854ee1e0631cd65f0dd237538c788916a2fb4008472715cdeab15efca99160631336c326d3b4363b67b671573520f0812cb265c9dddeaa5df51decda2ae93f3d225b193d5f9618dbbf18dd5c73b4e8e1d46472397be8d447b58e71c0ae7aeef2eee2182de7b99668adf2b146ee4ac409c90a3c64fb569dfcf1a641727b82479aab7da5ea763a6d96a17768d0daea08d25b4848c48aa704f078fd6b966d59e166926e8c499b9c5536ef5725e464f7aa8dc9cd66ce190034f1d85454f53cd4154763d1773d2969aaca7abadef6e2c1ada511a5a36184db7e827eddfed9c13919156e0bcb19d63f42091311aab02fbb2c0727b0c64f38f15c9c71b12a7071e4d74ba5dcff000b96dee5046f2c6eb222c881972391907823ec6af1e1d9dd82d3b35a3bb6997d144088bd8919fed5d768f72d945dc02639cf9ae3aff563aaea971a8cc90c734f2b4ceb0c4234049e76a8c002ae41a95c928b6e154723247007b56f197b9ec60cbb5db3d02cf5abcd1eefe62ce45f533b58119565f623c8aeb2cfe24e912065bfb69ed245ee508910fe4783fa735e4d7da9916d1089827d3c329ceeae7ee6eee950a80c49e095ecbf7ad7e238f4707aa7a768f5d2df9a3f32f2b87ff3f99d275df526836d6d79a6f4c69d730fcf5f9d4af2e6e1c9df2152bf42927039e6bccdee5c0791b9de3071ed566e6ed9a6c4e43e0edc9f3535bd8dacd1996495917db39ae77cbe0e2c1a78e18fc2c2dd7d59972c88d10882e18907279cd5782ce4b8721c81ce2ba0b4d12f7568aeee34eb49ae92c90cb3b44b958630705d8f8151a1820271b487180d83cd6904a4fe661c2d8cb5d306d2a929571ced27cd598888d7f98f9600edc78fbd564bc08a42677671fafdaa1d527ded13a0c11c12a715aca5082f94d134a368cd9f5366b83819da7009ab965a94aa06d66e09191fe15932448e4956fabb9c8c541116df90fb71ce4f6ae3f8924ece6539267696fa96a6967770a5e4d15bdeaaa4f1ab604a14e4023cf35cd5cb39999027db9157ed35758a26693ea65edc554bab85ba5fa380beddcd4b927c9b4f6b8da7c99ed0f7dac0b0e70298394c1c03fe353825493820b1e3db14970632a36ffe2a87352ecaea0e47de9d9024ce288a511b72a18638cd464fd59f151654b3eb031ec58c6e6f2291e16119761b71df350ab946c8ef57ad9edee6f208af6e1aded99d4492247ea145f70b919c7b6455934d724943385c0f352c51862093c79150b85123056dcb9e0e319142b953906aa9f3c952c32a1231c2e7bd5738cf0722b623d0b577e9e3d40f6328d2bd6f97f9ac7d3ea633b7fefdab25d143901811ee2a5bbe5123734669b4552c81d9a33f7a4c5152076ece00346e20f7229bda9cabbdb14ec0a1f8fb8a93d720f00546e850e3df9a60c93c54db40b7260a6f07ea3c9a8d250a4034c059402477e29c4263038357bf2892c487306e46fa47f4d40a9bd7db1df8a5de42853daadc10ff002430e77761deaf5bd93d9d27c30935d8fe226990f4e6bc9a16a333b4497b2aee44054e432e0ee040c608232457423a4be2b6872eb3accfa01d45f528a68ae679912e2470e496902e77827be48f3c8af4cf875d3fa4740fc3d93adb574437d736ff0030d281968e26c6c893eedf4e7ee40ec2b2b49f8e1a84fac7a9aa68f6b0690ce06616632c2be5b2787c7b003ed5f1797d535da9cd917a76153863e1b7e5aed2e57f7fd4f621a1c308c7f789b4e5d25e3f13c42c2d0b110cca17190411d88ee08ad15b4c5f27cbaac8339d87eded5ea7f1aba7b47b59ad7a8f4bb9b586eaf5b1716e922869c1195982e727d89039c83ef5e53a53c8970366de588c6739f15f4be9badc7afd3433c155f6bd9994f0fc0c9f0a5e3c9a16da16a9ae6a7fc3743b46bbbd9519d2dd17ea3b41240f7e3fbe2bd0b46f85b71a24492f5ff5069fd1c2e616c5b3cfbef24c8380624078c8ec48ce31debd83e19f4de93d0b632bccb15cf5a4d0a4b70cc993a6c522fd318278dcc01271f91e00ceedcdb6977daf35fddc36b75ab7a614cb305926083b77c9039af0bd47d7e1a4cf2c51575edc7ebf5fc3fa9ac34d3ceb7c5d2febf81e1b71d07d1d34616cfe29d924edff00b7f3ba6cd6f1938f2e49e7f4ac4bef859d5fa17a9ad496b0ea1a6088ccda8d8ceb35b103cee07fb601afa4ee2ded6e2168eee08668b04b2ca8acb8c73dfed4ed25acac74b6b2d32d6ce5d2e64646b44556b7994e72a40c839f35c30fdaddcd6e857e3cafd123a1e87245da95fd3a3e5686fa29098ca9532723683cd3eee59308d1e71ec473cd759d67d2d0e97a958f5074f293a06aaacd6d1b7e2b4901c496edf753d8fb7e559105b452c615d4ca7249dc7f0fd857e851c9bd5c4d305e68595ed2de7bb85d9c2acb903711c0fd6965d2e49f2a101ed9651b477ad6b3b710c6d8c0e4120f38c78a8a5d41325237c11c30f6e6baa0e3b6a474bc4924e4476560eb260a6d8939078e0fbd6d811aaabf0aa06493c55688a336e1296538c0a2f62334406ffa41c102aaa9b3ae31d91b488ccbb8aaf1264e71eff90ad086365425b1cf38f15996768f0b23b393c706b5c3295d8dc8f2315ae4926950c29f72283582fe1dff00889dc0f619a8628fd3cc29233aa9f6e056cdd5bda349b6da732c6554b12bb79c7231f63c55092382188c67e8",
            "1dc367cd670c8fb64bc716b7455183aa03346de94c011d81ee307dab81bb965378ea7b8382471cd779770dbab9769772bf38cf7ae66e560def3c60156cf9ff002ac73c39b478fa8b97672b790328de1b3cf663daa9cb348624567628830ab9c8519e703c5759a4f4deb1d51aa7f0cd12d7e66eca3b888b2a65554b31cb103800f9ae4e78ca3328c8c571c923c6c9c3e0ac165b8952086369649085554525989ec001dcd556c8383c569e93ad6a5d3bae5a6b5a35d35adfd948258260a09461d8e0820fea2b3ee6e26bbba96e6e24324d2b97773dd989c93fb9ac5be4e66c88726a78539cd40bdc55a80fd42a1131ecd5b30a7233dc7ed5ad15b44ec376e3f71e7158d1c52efc202377b574b6114f144a646058f6e3cd6b13d2c2af868922b670ca026e00e47b9adc0d04310df112187755e33daa94f0cd146b3fdf71e3cd432750decda4a684e205b713fcc07312fa9bb6e31bbbe31e338f357ba3bf77c224ea6bbb2d1b53167a5eaf1eab12a23fae90955524025707c82715992ea4d35b178cff00348c316e3fd7fdeb3af54bdc6e20b3636e46306b31ae5a30c8172cbc138eff006aaa6d1c32cd28f1265a921779bd23f4b1209707c1f15af26932c564e218cb153bb71359da534778e1a57512a1e43f63ed8aeae6b826c8469f51938ce7f4ce71578a4d597c308c9393391b5b8beb313c16d7935bc13218e758dca99149c956c7e21c763552799642b1c2080a7049e315d14b6823bc70539380581c678e40acbd434ab94d1e4d6edadf3606e3e57d52e0ff00336eedb8ce7b73db1546a8e7c90d88c996530b8f4dc7d3c7355c4ed713fd6c4e7c523c00a31f53eaf2a7c558d32d2d26706eafc5aa86009f4cb71e4f1ed59b67236ecb7158b421679b2629410840ce71c73fad674e3683108f663279ee6bd9baf7a63a4b44e94d3ee34ebd30bef0911f50cdf32a412cd807ec0e471e2bc52e82adcc821b8332f87c119fd2ab0c8a71b41c935c106f2320700fbd4914afbb86db81501249c9a334b33b2f49223a0c383fe66b4759d7edf54e9fd0f4b8ba7f4ed3e5d2e292396f2d50acb7a59b21a53e48ec3f33f6031123793b50e30700fe7cd4be7925bbe4455dc0d230dbc0a141c6e1d854bbd42670093dcd11143085280e4eeed8a682548c52fabc7e114c2793c628d90293924fbd5ad42cbe42e561f9bb6badd1a49beda4dea37283b49ff8867047834d7b509a5c17bea02659648b663f0ed0873faeff00ed55b355b04ff3775f27f25f332fcaeff53d1de766fc6376ded9c719abba2a68725c5c8d7a7bb86116eed09b55562d363e80d9fe9f7acb192700519a102fde941e31534663914444007c1f6a648851f81c78357af248d1c0e683c0c11f91a9638c36edc33fa546e541da071f7a552b0329cae570076cf38a6668cd56c161963662c1fe9c79a235849209208edc77a85580ee3353140e80a0c1c55d3b24e8edb40d2a7e80d4ba8a5ea8b1b7d46d2e63822d21d5bd7b8561cc8a7b607f91c907686e658ed7ec3b53e3539c67071e6848da425d949a53607c503caa65fe95ef8ad28444230eb26718c003b715afd25d19ae755ff12fe08b030d36d1af2e04f3ac5f42f7c6e3c9ae7d9c4537d20608c76e2ba20e31fc4947d01f102fbd2f82fd236a33e95d47033f38c8587201fd581fd2bc743ac76b92ca573c29f15ecfd73a6cb75f01fa66fa088c86c6ded9dc0ec236882938fcf6d783c933b20820cb9738f4c77cfdabe7ff0067270fdca7b7bdf3bfc6ff00da8f635cdc72a6fd957d88e7b8984ad3c726efe9049e6bd5fe07e8bd0bd43d416b6dae5ddeaf510bf8e6b58231fc99218c7a8e09c11c85607247f4e3b9c33a5fe06ebba9d9c773aedd2e8d0b9dde815f527c7dc7017f539fb57b0fc3ff00851d29d1fd63a7eb36f35f4f751395124f300abbd0a1fa5547fc47bd736aff0068bd3f1cfe0c725cbae3a5f9f5f6325e9fa99c1cf6d2ecdbe9712dce9b36bb74337bad5c49a84acc39c3b1f4d4fd9630a0735e256fad751ddf5768ba2268705b752d86a324973a846845cdd2bbe59663e6354ede36818c79fa2a1d3e0d2218f488e1223b2510265beadabc0c9f3c79c56d596816201d4ef76464c79672151827fccfdf1f6ce2be374faac8f3e79462a4e77df15f8fd3e9f43b3518a1f0f1dca947dbcff9ee7997c4cbad4ac7a496f74eb45bc82deee296f2ddc12b35ba92591c0e76121437d89f15ce7c26d4350d5b54ea4d4e3d3a1d3744ba984b05a5b022de1949fa9621edb719c719c76af6fb0b7d1b5292fad05ed9cd2dbced6e56da43b948504ab0627270790323ef54ae74b87482b6e910f4719411a88d00fc879ace7f174fa3969a514d377bbdbf2abfccb2f879754b2c65ca5d1c375169a9374cf54d894fe54220d6adfc08df718a6c7ff5b39c63b9ef5e34f748b19f488463ce2bda7adb514b1e8fea6bec227a96b069710ce03c9248656e7dd5141fd7c5781c975f336e622877f667c718fcebf4af4294a5a0839f74bfa17c73db93225eff00d91653581021528496cb150793ff006a8c5d3caf9438320e0141c1f6ac68d92d256b8656642080546703c55a7bb4668ee22dcbc13b587bd7aea469f15b5cb3734cbe944ae258bce06df6ad0b9b9007a6b28121270ad819e2b9ab4bbf9479279412800dbbb8aa52eaa2e65796452ca99e57c13daacb26de8d7e3a8c29be4f40d0e09357beb7b1334167eabfa6279db6c69f734f40bea490878dcc2cc9ba33956c1c654f91f7ae4f4e9a79605418f481cf3df9e69ffc52783524445631a9da4018c54fc47f91b472d3",
            "527d1d4209a304cc724f154af03c8c507d2b9c13fe55136a8654591086407ea1e69b2486e5b2a9965eddc0a9723a2528b548a1a8d9b25a9f59c9503823c79ae1ef5cc73b4409523b1c77af442d2490185d46e19ddce715cadfd9ac8270c1048a0ed2477aa49ba3ccd562be627346e59fe8c0db8c64f9acbba5db924735af711848c6587a99e6ab6b9a4ea3a52da1bfb6f4be72dd2ea0fa95b7c6d9dadc138ce0f079ace4f8e4f0f271d9cdca393505686a56379a6dec967a85b496d711e374522e19723238fc88acf35cb6713015d0f4ff004d6bfafc8c347d22eaf821c3343192abe704f607ed52f4174c3757f59d8e8c6431c2e4c93b8eeb1a8cb63ef8e07e75f4775575cf4efc3bd3a3d074bb38cdec51a3416288444884e32ec3ce013e49e09ef594a6d3a8ae48dcd3a4783cba16a3a4e535581ecee15c27cbce8caec39fa80c60af18ce7c8ad9b1c0da30081dc57b169fabf4ff00c4fe8ab9f9e8a3b29adc62432b026d1c83b645638fa783ed9c107debc72d93d0bd9207912431b142d19dcad83dc11dc56f8a6e569ae51eb68f26e7b5f0cdf6884b6acb80722ac4ff0009754b2b54d57a96fad7a6f4e91b09717e58994e377f2d10166e39ec07debd13e19697a1d9cf69d41d469eb99dde2d32cda3dcb3ca8012ede028ce0678ce7dabbcea0d66cb51bbb78fa82f2cd9e59336d05d3201bbff00edab7f95679b3b52da97f9f41ea1ac5196c8aff3e87cee3a3fe1e9d40a4df116f9902b64ae8d22459c1c36fdcc42e71fd3923c0cf19779f0bb5bb8b3b8d53a7ef2cba9b4b851e49aef4f9377a2a016c488c03c6768f2307b64d7d386184c7e9186331e31b0a0db8f6c6315068936936e247d024b3445919646b2d8407ecc1b6f04f7c8358aced7478cb52dbe4f8b6dadc5b3972a769f0a7fceb720b88e1b3cae4bf711f27f7af49ea52fd39ab3f5ef4bc16b69389e5d2f55b2f403456b7054fd68a72024ab9603c10c0718af2f8e5961b4669047b0b77618cfe55d5095f28f5b04b8b457bdd5250eb21014e707cedacd9e1721e71197527b81c2d6cc76705c66476dd8393ee476a9ae3d754f4a2b5616e470a3f7e6afcbecb4a0e5cc99c6ff00395a4dcb83e78c53a4fa235e403dc951deaedd1912577e71c818e6aa7d6d1c8d28fe581c1c7ed599c0d570589afa2b8b1821552ad0061cf9c9cd653b6e6cd2890a96040c7b63b5479aad99376387e78a060b76a4f1ef4f84032296e173c9a8209fd394282a709e79ed4c9142920905ab46f2e215fa2df233dce7bd64c8496c939ad654b845a4a8bba55b585cddbc5a96a9fc36110c8e25f41a5dce14954c2f6dc7033e339aa14a32c33ed4dcd64545abf6f1db436e2e351b0bb92294910c91c9e9a923f17254eec6476ed59f935b379d53af5ff4b69bd2f77a8bcba46992492da5b155022690e5ce40c9c9f7271938a820f75eb5eb6f83fa87fb3fe91a3e91a132ea0a5238608e1114b692a05333b4c5486dc0ff00cdbb78e0638f9e2e5ad5e7cd9c32c51607d32c81ce7cf200ff000a1aea46b18ecd88f4a276914639cb05079ffec8a833558c54423a3e8aeb0d4ba13abacfa9b48b7b3b8bbb4ddb12f21f52339041e3208383dc1045636a17b2ea5a9dd6a13ac492dccad33ac3188d0162490aabc28e7803815573466ad4aec914123b52ee24609a6e68cd4d827170e318f031f9d46cc59893dcd333464d4ee6c58be68a728047de80c5415c77a017d36271dcd5e8a38d22cc8ff563b1aa81b03701923bfda9ca5e762c47d23be2af169164741ab6a9697da569305a6816da7bda406296e22dc4ddb6ecef6cf9f1fbf8c0184ab285393850734f79e6644479649208b2114b12ab939c01e3939a80c8c640a5b8a9b4882759cc4ff5907f2a589966942f6c9aa0dc31a03b06c8e0fda8b273c8b3e92f85ff0010345bad04743f535c448046d0dbc97042c72c67ff0094c4f6232719f181dc0cbba2fa4ba6ad7e38eb36d62cf3c5a242af0a4cc1b12b6d0482319db92391df9f15f3633bb1cb1cfe75d17477576a5d1dd4b06b56004853292c2c4859a33dd0ff00623d8806be5f57e9125fbc4f47371f8a9fcbe377bfd2f95f99eb62d7a6f1c7346f6befcd1f7151c8390706a1e9192e3acba4acba934db19eded6f14b46974046e7048e079190707b1abb0d9dccf77f2b1c2c66c9054f18c77cd7e43934d9b14b64e2d3ebf33ec619f14d5c649a3664326b3662eaddcfcec4bb67854e0c8076751fe22b4acafacafec7e4eec465990c52c3281b5c630460f0411e2abe9c96fd3f1b4dab5a7f30b6639d07a800c76ff97cd72bd47f1bfe11e857422d4b538eeee98fd496b6c2e1971ff111c0fd4e6bedbd3f0cf36d96f5f11f71e7eff47fa3ecf93d64a306e2a0dc174ffb7d57ebe0ecedf46e9ed2a58eeed74ad3aca4822f4239628123648f39d808190b9c9c5646ada89bebc58ac581589492ecdb154797727f0a0c7735c38ff68df82ec40ffd6e7fff0057ff00eaa925f8fbf05f51b19b4eba86e67b49b89209b4a06393c80c09c1ec3bd7b72f4bcd9a49647f2f9abb7f99e7e3d4471f308dbfd0f16f8abf1061ea1d5a1e9ad1af3e6749d35d8b5d2fff00c6ce7ff725c7fc3d9547803ef5c6dbdfdbb5b18e24d8e786079247dab2ba827d32f3aa756d47a6ec9ec34a9ee9dadade46c98a32785efc71e39c76c9c66b3da748c150cc2641dc71b4d7dce14a10504a91be2c8e0ace8e5d5a28eddadca0328ed91cd470ea027d363b396d2057371ea1b8c1df8db8d99ce36e79ae7e1f5d824d3be71f4862739a6cd3a302229ce7c81c006927",
            "7cb34799cb96749752b4d06d8d4b468be7fd7deb3ad9164689e5dea5d8641c91dea9597cca26d9810ce7001e735d0c96c8b1fa9eae772e141f07efeddea2ef9368b793e62f7cf9b1c6f23d323e93b7208ce3bd3adf5285ae73b902c8304b1e40ae7ee6ceea582285eede631a9548da42cb18272768f1c9271f7a96cec274bad85892a3239e2a5499b472e4baa3b3b78e39a4312955443938e3357ede682da368c0cf39c9e71f6aa1a4db342ec652589ec33903ed4ed4a77b5291c2ab8638c1ee2b747a9196d86f6519b5411ddcbb3b31ed8fef583a9ea0928cef2ac3c7bfdeb56ef71512232f391db049ae56fd0ccfbcaee3d863c57438270b678fa8cd34f6946e27691f2e791f6aa5237a83eaf156360490866ec314c9d7f944818ae392e0f31b6ecc9b9769246776666f258e49aa4d57261f6fdea9b77ae5672c8f4ef813cfc51887ff00e24fff00e0ac1f881a84d7ff0012f5fb99b865bd922001ce150ec5feca2b77e05301f14a1058026d2e00c9ee76553f8ada0cba2fc4dd4c988a5bdf3fce40de183f2dfb36e158c5ff0010cd7f30ce99d075bea0b3d4e7d26c24bab7d32d8de5e32ba81144bdd8824671cf0327bd6869ca015d91f0de6ad7c3ae82d77a9924bd8ee1b4dd29b30c97073fcf1904a2a82370e0673c035ee1a67c39e97d363406da5bc75febb8909cfe8b815d12cf0870ceec5a98e27f31b7a6d8adb6b096ebcc3a56996967178fa9e3f564603fe62ffe35e61f11752d7b4eea3d734b5d2adafad75fb5820b79a5b5f5658550e76c2dfd2dbf713dfb83e01af7a9eda3021beb1b5455bb863f5b6ae4178d447ce7b1000fd315ada26890de2fcdddc7840d85457e09f727c7ef5e6ce4a5c9e5e4c8e73dc79aead69accbf0caeec43b49abb69be9b14e59a4d80301f73c8fccd713f0c6f357d63ab351d56e34d834fb48ec21b274b6b6f423678f0abc7fc780c5bf3fd2bdda1d67a766eac6d1869f7de91c5ba06d2e458bd70c7726fdb9c85c3127e9c1cee3d84dad68d1d895b8b54dd13b636bbf087fcf359a69b28d6de2ecf17eb6d3637bcea2b7dbfcad63a6ee67703ff00e7d9b2ca8c477cedfa73f7f35f35c2c66823122f11f1caf3fad7d2ff00137566d2b4cd6f53b88c22da68f269b6e597686b9bc7552abe091046ec7db23ce2be62b7d477c2ac7f1af9ce2bbf0bf73bb4af8e4e9b4d6b7b70433e1981e76f039fdeb49e46da2d95000c0e09e3f5fd8d72f348b20df685b030704f2df953db52b911ef9137b9186238aec4f83d88e65154cad77736f1192168f956c6fce48159129f987dc385ec055d9a58ca4920fa5dce30141e29f6cd0a2a308cc9f49078ed593e59c32f9dd1873c2d1b124707ef9aaf5d04da95e5b0bdb7b498a417b088a652a0ef5dc18771c72076ac0230483593e19c9354c7c632c32011f7ab0aaaa428fa81ed50c076b7e0dd9fbd5d88012ee4651bb800fbd5a24c5595a50eb856539cfe235010cc71c9c56e2c4f2cc5678c288c658f7cfe74e9f4c8e3b74951a36f5776d01c6e18c672a391df8f7e7daaea0e5d169428c558885e4673ede2a3280739e3c56bfcab880a8524af6359739fab61ee3bd4ce1b57266d51b76bd4ff002bd0ba8f4b7f04d326f9dba8ae7f88490e6e61d808da8f9e01cff76f7e39ea2945608a811494f670c3f0e0fda99401451452c0514a01270294a95032319a01b562d62f5652a403c79a89509ee38ab31b340aa57009f7ef578ae7925124c218c6c8feadbef54cf2f56162133b60e09391514f118a4c13c919c7b55e49d592c40e01c718abb6ce918dc00e7fa4f15994e2cc71939c76aa4654c29516da655958b27d27c7b55363939156ecaca6be79a389a153142f3b7ab2ac7f4a2ee206e2327d80e4f8ad0e9ee94d6faa3f88ff0006b659ff00875abde5c6e91536c6bdc8c9e4fdaab29d90d9899c9e6b43559b4797e4bf8459dcdaecb544b9f5e6127a938cef75c01b54f185e71ef59d4541014e53839a6d4f040b324ecd73143e9465c090906439036ae01e79cf38e01e6960fa47a1bfda821e9ce83b1d0357e9796faef4d805b4134170b1a4a8a3081c152410300919ce33deb83e99f8ebd4ba17c53beeb2bc57beb5d4a490dd69a26648b6b1c8d99c852b81838ec307b9af23a2b896874eb73dbfcddff9e0d3e2cfdcf78f8bdfed02df10ba6e2e9cd17469b4ab169566b9926983c9295ced401400179c9ee49c76c73e0f4a0027938a528c3c56f870430c7663548aca4e5cb10120e478aebb45d2f49bfe96d5756bdea586c352b2d82d74f6819def3279dac3818ff58ae65619628e396589d2298128cca40700e0e0f9e7da9c2e1e2e1081cf8ae98fbd84e8bffcf684b2b9033ef835de69daadfd97c15bfd193a8f4df4b50d4d1a6d29adb75d7d2a0894498c85fa47ec79e48af3e4bb8da1f4fd30a4f39ffbd5fd174ed7f555d42e74ad36e2fe1d3adcdd5d3c285841103cbb1f007fd7dab4938b69b35b5c724f75b61430aca77e3276f9acb5264218950c0f2c477ae97541d213fc3fd3ef2c6f754ff7b0dc38bcb795105aa43f560a30fa8b7e0efeeddb033c7471bc91b10c4738e3b1a894f7745a52b7c1ad16a26dee804025dbefcf15b916a266824dc40debc0cd605be972bfa2efb42b8ef9ec2b505afa10b476cacce7927efe6a6299d58e535df4696860477624b85fe5b0c0c9c679aec2016c6e1656907d608031c0ae22c6cae6f54969b604ee72467deba5b0211cab31f4c00339c9cd69167a7a69524ab83a69825a441609159c1ce335535ad22fed34cd3756d56d1a383540cf6b26e0448aad",
            "838f6c7dea96a1996d8b216c061804608354c694fb6379aee468a3076c6ce4aa0273f483db26b7a7e0e9cd39c9ed82e0cebad592defe4b55019703158f3c378b212d0c912950ea25520953d88fb1ad0d5ed54c8248d3ebce0b6eef56f5fea1d5f5d7b49b59bd7ba9ade04b58d8800ac4b9dabc0e40cf7ef52afa3c9cdb9cbe6e8e5668d4b9ccb97ce7354e695b61cb6715a73c5b5998b609e76d674be9fa783cd679125d1c724c8757d3352d1ee96d754b29ace67892658e652a4a3a8656c7b1041ac57ef57ef259257dd2c8cec005058e4e00c01fa0159eddeb8a472c8d8d23a9354d15ec64d3da28a4b2ba377148225dfbca8520be3715c0fc39c727debd9fab7e2374775a7c2fb869ad238f5d8f62c369329dd0c8c46e78dc775c03dfed91d8d7cfca6a78c90e3159ed4da6529367db7d2b1d8c5d1ba347a6051682ce231edf395049fcf24e7ef9ad9af24ff66e9356d7f50bce9db8bb8c68f656e6eb69ff00dd462c06d4ff009493939040fccf3eddd5969a4f4ccfa789b558a04bf90c308b970a4b8c719ed8e472718ae59c5a9edf2652834e86e9d711344fa75deef4253b91d57734527fc400e4823823fe95bda75cdf68521b5bbb4926b590ef47894b0e7c8f71f6ef5a961d371690e2f20b92f7712367d5c08c9c73f703ef9af3bbef8ef67142dfc32c22bf9bd83ba27ee793fa7ef518e13c8ea0ac98609e575056cf4c3aed97a5bb37278fc1e83e7f2ed5c6752eb77fa8a4b158d93a456a865792e2371143c7e394a827b7645cb1ec3be6b857ff0068cd523b936efd3566241838f5a53c1fd69d2ffb44eb31c4641d35644a9fa47af2e7fc6b45832aff004fea752f4ecde57ea7827c5dd6e6d5e78748b15b95d334f95e4dd71118e5bc9df025b8917fa49daa157fa5001ef5e5912491c648ed9e467bd7affc44eb26eb4ea3bbd72f2da3b7b891110c3103850ab80093c93f735e6374bbedbd40f853c61707f7aebdb491d13c0a15416b74a251ea602e781ed569dd6695658d82e06140f1f7ae7e41344c9232b20719524632324647ea0fed52a5e908564249c6148a953328e4f0cdb7b0790811b649cf2be07f9d3ae125b42640c8a8570707771fad6443a93433a32b12b9e41f15a0938beda7385c9fa49e3ff1564d335538b5c7666dc4af2be54800791542418735ad7f3411b6c4556247f7acf9f0ee318ce39aac91cd3ec6427eb0be0f735b30c31a234891ac9b479f159d65633ddbed8637770376154938fd2bd1adfa07abadbe195cf562e8f2fc9cb346c0950641180ea64d9f8b66e603763efd866a1351e593069767376d324e0457282207b3f9c7b5170917a61915b721da0e3b8acfbb4bab640f7693479c101d48ddfbd450ea12389101e1b9da6ba6393c1b39ae993bb98c32839007009f7f1590f0156264e09fdea592e8860a5b81cf1436d9413ea67ce4f71559c94ce774ca2c31c672056ae81d39adf546a674dd034f92fae846d298d081851dc924803b81f7240ee6b29c6c7201247bd5dd275ad5741bff009fd1b509ec2eb6347eac0e55b6b0c11f95723fa1994e48e486568a5468e4425595860a91dc1140c6d269acecee5dd8b331c924e493499a9b02f9adcd4b4dd0adba6348bfb0d7be7353baf53e72cbd12bf2b83f4fd5d9b22b0b3466a00f590aa918a77a99077727c5459a3356b164bea6e6cb0cd0fbc8dc41ae8745ea2d2b4fe91d7743bae96b1d42fb52f4be5b5399984b63b5b27601effa7df70e2b33d23e80323659c71cf18a956eecb256558e6f486e03248c532593d419ce4fbd5a78a0110551c8e4b55590283b547eb5677541a688a8ab1677b71a7dd0b9b628b28565cbc6ae30ca54f0c08ec4fe5dc7355b359951c4e4f3cd3925962dde9c8c9bd4ab6d38c83dc1fb5479a33402d1499a33402d1499a33402d1499a33403d71dc8ed569c821707c54763f22750b71a93ce9665c7acd6ea1a4099e768620138f722a36957d6ca962a3852460e3c66ad19244d9b7a97516b7ac699a468ba9ea0f7161a3a3c3651305020566cb0040c9c9c77cd537b5548e35dcacf9fdeaa35c2b9c85c13dea68e42c18b3718e327b55e3b6f82ca88e53e949b08ec2ac596a77f60b71169fa85cd9a5e44609d6195904c84e4a3e0fd4b90383c55399b71ef9a873ce6a8df2436692318e33273cf2327b52e9e8c67503b6eefee6ab21796158cfd59fbd49eb9b56f48ae571fae6acdf9344d2699d54772b142d1c8a11863bff00954c2eb7b88bf09e431ae66c6ea49c98d947b8f7a6497a229e40e1b71f39ff000f6aba9793afe3d2b36a4be11db7a519fac3e324e735ada55fa88970db98f2c09c0fcab871233be7717763d8d696993cc270ce8a43360e5a919f231e77b8f4f8b5282e6d94dc66dc26090e0726b31b521e848e2e098c1c1e39ac037b0facc9eab3b28c704fed599733b4b06d6720fb0f7f15ab99df3d53a3bfd1f49d635a678b4bb27bd3144d71208537b246bdd8fd8647ee2b0e7d9f36cac37150476a6e81ad5f69c8a6d6fa5b60c8f1c8d0c8ca5d186194907907c8aa3a8ea18b990200003b411e6b7c6ed72633c8b6d91dcee27002f1e7359aeb0fae8b348511980660376d1e4e3cd2adc0198d4124ff007aa774eea4e7f3aa4da7c9c329da135c8b4db6d66ee0d26f5efac1256582e1e3f4da44f0c57c563354f2b31e4d5726b86472305ef56631922ab277ab90f24521d84759d29d43ae74beaf16ada06a32d85ec60aac9111c83dd581e181f6208adfea1eb0ea5eb0d4a2beea5d5a5bf9624d9186015506790aaa0019f381cd72360003bb22b7eda1",
            "8658f20927ed5dd8b6a96e68efc78f72bf276f27c55ebc7e9cfe0937535d4b62d1fa457e9f519318da64c6e23c72791c5655b6a36c92a9855fd20a32b2104e71cf6fbe6b356d2391b6615801d8d490225a48f37a0436ee06720fe55d55187f2aab3b70c1e3768ea5ecedca8b8813696f23b9c8fbd0f6b6b35a22c87057b9f23f3aceb7d4dd92389572c7beee4839ed4fbc985bdb97930a4ae7bf73ed5ccdaa3da538b574721d433409232a9dc1f70f00fe75870e96d2e9524b1b738cb71c819aafae6a465bf91a3e141c63df1e6b77a7f4cbcea2e99d76f6d755b3b51a4da09e54b893634aa4e36a8f3ff52a3b915c5292be4f9dcb9612c8f71cd6bbd43abeaf63a669ba8dc2cd6fa54260b5c22aed4ce792073e3bfb7e75847f2a96e0b16058fd5e71daa218cf358fe0796fb12acdbcde91c8c93e31e2ab56969dabcba6d8ea7691dada4cba84020779e10ef100e1b3193f85b2a067daa6eba213a2b4ecace0924b79cd45bfea079c6734c2c4f7a4a592dd9661bbb9b7667b799e238c6e4620e3f4aebe1ebeea81f0eee7a71fa82e4d8add46c96e64c1da439600fe2db90a719c679ae2031031e0d4b1fa724d1472c9e9c5b802f8ced19e4e077a3e4597564bed5e4f4ccef2cb1c6eff00cc727e9552c7bfd81aa01f680509cf626be8bff679e97f84faa5debc7aa751b2d43508e20b6f0df39b58d6164712bae586e38e0ffc239f391e39d71a6f4958755eb31749eb26f34c8af1d2d14c6c7316e38c3938603c1f2307cd554ee54459cd45fcd6219803f7f356b0896cdf560b79acf562ac08f14e690b1f61ed5a295164d08c4e719cd369723c0a4aa950a28a2a00514514014559d3ec2eb54d4ed74db18bd6baba9560863dc1773b101464e00c923bd1a858dd697a9dd69b7d17a3756b2b41347b836c752430c8c83c83da80dae97d134cd67f8a9d4ba92c74436764f730fcdab1f9975ed12e3fa8fefec0d5bbcb5d1ed3a1f47d56dfa92def354bc9268ee74a58595ecd50e1599bb36e1cf1efe79c7234a39c0a94dae9929b5d164ca853001c9ef498564c1e07834d119504a904d6a5a5a690da76a2fa9dddcc1769006b348610eb34bbc02ae491b06d2c7201ed56b658c67da1b0a738f34da71461ced207e54b17a7eb27adbbd3dc376cef8cf38cf9aa9419455cd4ff00867f15bafe0df35fc3fd43f2ff0037b7d5d9e37ede33ef8aa750028a28a00a28a28028a28a00a28a28029dbceddb9a6d15205273de81c9a4a280b8b751a44018c171f6a81e4f51f711fa545454b9364db3a8ea8ea2d1f5ad6a1bde9de96b7e9ab74b78e16b582669448e339932dc8278e3edef9ae79d2460d23783cd471b153c77f7ab1f307e5cc7db3e71de8aaa895d53228d946064839ef9a7c4cf2caa818019e09f148b123a0607eaf233deaed9451ee287892a5265a29b745a9bd6841f438217ea607834c13b4a8bb724af727cf1cd48098d0c443393ec6a632a25b98cc42320e083fd55aa4ece8fccad6f7a43ed3c01c018ef52b4ce4fd4776e3903359acacb70ddb1dfb546971711dc2bc2ec8eb82aca790473c54ef6b831ded766bc81eda678658da1950f2ac0820fdc1e6aadcca1f9c678fdaa4d4f53d535bd465d6356bc9af6f6720c93ccd966206393f90154d9cb29cf1ef4e7c873b5442f923245566ef561db8ef5589c9ac6464c13bd5e831c55053cd5b809c8e6ab1744c4ea7a7f513a4ead67a90b2b4bef969564f97bc8fd4865c1ced75c8ca9f22b65277bcd4e6bd10416c2791a430c0bb523c9ced51e1467007b562f4ed959ea3add8d9ea3a9c7a65a4f2aa4b76e85d6153dd881c9c56dfa36b6daa4f6f6576b790c7232473282a2550701803c8cf7c577e37f73bf0d6e3a6d3356b9d3b48d4ec2da1b668f5254495a4855dd42b641563cafe9fe42b126bb9a02c6e36e47600f3f9d59579bd062bc0fcaaa5dd83cd64d745b9cf2315a497dcf49aa57044f14b0092de6846e2bce573dbef49adcd25f59ff00e9c83b0e30479a82ca0482c9c34d9e30770ff5ef505edf471da6c898890f008f6f7fcab29c69593f13e46a5e4f3fbe8a6172448b824f34b041be2da849c9c13ed52cf393293261831c67356a096d6dd5915719e7779fbd71793c4514e4ca5796fe944aa40e7fa8fbd66b0c3115b5aa5da4d126c70c80f00771ff007ac42726a25d99e5494b8128a28aa991774ad4a7d1f58b4d56d52279ed2559916640e84a9c8c83dc51aaea53eb1ac5dea9749124f772b4ceb0a044058e4e00ec2a951404d6f24514c1e6b759d3046c662a324100e473c1c1fd2a1a28a02dd85d8b2b9798c425dd0cb16d2718de8c99fd3766aa514500514e006dc9fd29b405ab33603e63e7d2e1f30b7a3e83aae24fe92d9072bdf2060fdea05da4104e3daa7d3f4fbed5751834ed36d25bbbbb86d91430a96776f60077aadc8a00abba5691a9eb77e2c348b19af6e4ab388a14dcdb54649c7d8551ad5d06df5db8d4d874efcd7cec704b2936ae55d62542d21c82380a0e7ed50c197dbbd252fe74952028a28a0141c7e54763c1a4a2807ac8cac0f7c78ab0f76cfb0f00af61ed5528a9b26da272d23a918ca839a848c1c56e5beb96f6dd2179a136876135c5cccb2aea2ea4cf0818fa54fb1c7f73fa619a8b204a28a28028a28a00a28a28029f1c52ca58451b39552c7682700773f9532b6ba7ba9f58e97b8ba9f47b85864b981ade42d1abe54fe63bd1fd018b455ed2ae34eb6d5229f56d3e4d42cd73ea5bc53fa0cfc1030fb5b18383d8e718aa47bf140251451401451450052e78a4a2805f34a4f1814da28096",
            "294c64fd39cf8ad485a4781644e241dfef58f5325c489c06207b56909d765a2e8d21318a505b8dd9c93da9b34e8d180250c58e78f15992485c9cf6ce714aa5890054b9df08b6f2dbba98c2018cf249a9ed52d8dbcaf2ceaaea06c520fd6738201038c0e79f6a22b78caab33a8e39c9aad2a057d99fa3c568d38f247d495de495d5172a17db8a66c639ce73442ff515278c539d893f8b38a5df2c1564ce483509a9e4c1aae6b1914602acc4c17191c555079a9e3ef9cd51128dcb29949181c79ad286eb6de0083b738ae7a36d843a9ed5b8daceab7fa769da75e5defb1d3bd4f958b628f4fd46dcfc81939233c938f15d5193e8ea8cdaaa3a51a8dcc87d12a231c673c6dfbd5b9ee1a1840406424f726b0c6a72dc5f7cc5db492ca404f51db270000067f20055fdb71770952173dfe93c6057a18a29a3be39a4d77c9464b8691195a32aea383dc11ef59572616b76dd2fa67182d9cd6a5ecad1c242802455c118c1007b7e75cecccea005c6478f735c9956df9598649fe663cb2397d840efdc52b5c80023a8620724532e58a49b411f7c0f355b93cf7ae06cf39b698e6607b7029b4515050334668a2805cd2668a280334668c1c6714500668cd14500e0e47ed8a6e68ed4500e491e370f1b9465390ca7045379a28a806aeaba15e68f069b3dd4b6922ea36c2ea2105c24a5509230e149d8dc763cd66b8d84609e453cdadd0b25bd36d28b567312cdb0ec2e00254376c8041c7dc54593402668cd6be8fa3c1aadaea934dacd969c6c6d4dc24774e55ae58103d38fdd8d6452c066b63f81ff00fba5fef07f13b2ff00e93f2df27ea7f3fb6776df6ac7a7290061bb500dc9a3269ecadb43edc0a6548a0cd19a28a00cd19a28a00cd19a28a00cd19a28a00cd19a28a00cd19a28a00cd19a28a00cd19ab179637ba75c9b6d42ce7b49c28631cf1946c11907079e4557a8b019a33451520334668a28028cd28201e466b7ad7fdd2ff71f50f9cfe25fef37cd45f29e9edf96f47077eff39fff004fdea2c1819a3271451520526ac5b862768fc4de3155d79600d6a5b223fd1ea2a9c704f7ad20ad968ae4b9069371793456d6d1b4f75332c71c4832cec4e0003df26997561796977259dddbb4535bb98e5471828c0e0a9fb820d393e62df1246e46390c0e083f635b635eb4d2fa96cf56e9e49e6f95f4a6c6ab1472ee9c005f2bf84aeece33ce319e6ba6a3668f8393906327b63da9bd946df357354bc9afb52bad42e163492e657998451ac6a1989242a8e00e780381546ea1bbb39445756f2c0e555c2ca854956190707c10720d63274f933226241a8c9a76ecf7a8cf7ac5b204152a121b8ab5f37a6ffbbff25fc2bff897ccfabf3febb7fed6dc7a5e9f6fc5f56eefe2a9a1258555305b4df9001cf3db1deb4237648fb1cfb0a6aeb37afa5dbe912dd48d636f33cf1424fd28ee143301ee42afed4e171bc80aa33ee2b68bae4de346d58b34b6e724061c8078fd6b622bb786c9caf0ec305c715c725ccbeb07ced19ce326b465bc57836862095f7aedc595a5674c722484bebcd929027e5b823c835893c8e1c1573f5f73562558da3396c939c363b5577b770aac77305e7f3c565964e7c9cb26c92d74ad435bd56d34cd2ed25bebdba711430c4bb9e463d80154af2d26d3ef6e2c2f2de482eaddda29629170d1ba9c3291e08229d06a37565790ded85ccb697503878e685ca3c6c3b104720fdc54734f35d4f24f2bb4b348c5de491b733b1392493dc9fbd713ef8327cb21c288cf70de2a3a710477040a6d56c80a28a29640a066929e31b40c536964894e5fc5db34da7004f206696070201007383de987f11a7670090383dbed4ca9b029a4a294e33c1cd45903e355249660314c6c67818149452c91feac86110991bd30c58267807b671efc0a15598120f6ef4ca507069609ed9519c890718e3f3ad2ea3e99d6fa57576d2b5dd3decaed63494c4c431dac32a72091dab1f79e71c7e557af752d4754b8f99bfbd9ef2e1902196e242ee40180324e780303ec2a4933e9412a78a31edcd25459048f2b3f070076e2a3a28a58b0a28a29640514514b01451452c0514514b01451452c0514514b014bc83ec69f0caf04f1cd1901e360cb9008c8391c1ef57f5ed72ffa8f5ebad6b5368daeee98348628c46bc003851c0e052c152f2faf751b9373a85e4f773950a649e42ed8030064f3c0aaf4f8a279a6486300bbb055c900649c7735a7d43d3fa8f4ceb52693aa2c4b731aab1f4a5122e186472297e0193451452c051568e9f78ba526a861c59bccd02c9b872eaa188c673d98738c7355696028a28a580a28a296051df38ce2b674bb982390078c127fe2ed58ea7eafceb4203947291315893321c1214640c9f6e481fad6b8e54ecbc5d3b2f4977eabbaa6319f07229b2158d5640461bbf1496f0a2c425421811f511cfe954af64fab01f7007b0f15d1bb6ab65e4df6c75ec81f1b0f6f6a9358d6f57d7eed2f759bd96f674896159243c8451803fd77249ee6aac215932ca4f81ed4926d3dc8e0e31584be67b999b5e4afce69a6a56c03511ef593204a553834dcd39464fb554843f7b06c8ed52c12ed6c6ec1ce7355c83db3403f5000d4a64dd1ac8cd38fc3e6b527ba92e74eb1b01676b035aef1ebc51e25977303fcc6f38ec3d8561db4cd1c671f880c0a905cfa6d96393e41ae88c979354d7937fa857a66cff840d02e3509e76b40da80ba8d5552e3272b1e3bae31dfff001cdcb3b1663b4819edcd482e637b91bc9e3c8ab9a9c7a71b97fe16b70d16d53ffa9dbbf3b46efc3c637671f6c54b77d32a67",
            "016ed180a0f1c9fbd43284c02a403fde999651b41c13ef519249e4d612652c76e62319e28186201a65009041aa1165b8608dc9cb018e39a962b4593243739c73dbf3a6473138665c0519ab91dc029b954053df3e2adc1b4545f66798305b0dbb68e71501ec062b46e22511e59f717e411daaaa5bbbe5554b6d1927daa19571e6915ead43858f3e3193555810719fdaa4de4c7b7391fe1509945c0b2b231ca8c1f3515071e0d252c862d149454102d1494500b45251402d6f5ff526a3aea6936ba9c90fa1a65b2d9c3e9c2a8446093ce07d479ee6b029c8d8619152bb25765e375359bdc259c8d1473a18e403fad320e0fdb207ed54b1919c55842a50975181daa1697e9da1462a4b31046db4b1e00a653f2d229e400be2a3e6a0ab168a3040cd266a08168addb187a51fa3b569750bbd453a89258869f0c51a9b79109fe61918f2081db1fdfc60f39c52c0b4527eb4501625b4b982dedee2685922b852d1391c380c5491fa822a0a4a2805a9ed6ddaeae042b2c5112acdba69022f009ee78cf181ee702b42ff0049b1b4e9ed2f52835db5bcb9bddfeb59461bd4b5da703767dfff0019ef58f4b02d6bc163a449d2f797f36b1e96a914e890d87a24faa841dcdbbb0c7f97dc563d1402d5cd2f4bbfd6754834cd32d9ae6eee1b6c71ae324e33dcf00601393daa954b6f717169731dcdacf2413c4c19248d8ab211d8823b1a025beb1bbd33509f4fbfb77b7bab7731cb138e55877155c9c9c9a259659a579a691a491c96677392c4f724f934da0168a4a2805a292aff00f13ffe01fc23e42cff00fa47cc7cdfa5ff00a8fc3b7d3df9fc1e718efcd01468a4a2805a2928a027b6b792eae56089a3576ce0c922c6bdb3cb31007ef5f457c2aff67d97ad3e196b9aedc7535ad94f70af6b6d1c45268d0c6cae4ccea4e012a06072073f6af9bab7f44ea5d4b48d0f5dd2edb56bdb5b6d4ed844f041332c731f514fd601c1fa778e7dc8f35596eae1820b9b6bdd2d57d496d8c4c4aed82e6397f7da491f99ace9183e5879fbd45b81e31c521635a6e7e4b5922c8ca060f6a42e49cd474545b22c7124d252668cd2c0829493e29b4556c81726928a280bd672c70b6e739c8ed515c4beab9fabb556a2afbdd5137c50e5273c7f6ab70ddb2fe21902aa29209c715622037293c0fb522dae8989a3aede43abdf477b69a3db695188628bd2b62e55d9502973b893962327c73547e5e3f4ca97db20f35a28f04701595032f1b706b3a574deec0818e01c77a9aa34714b929b0c3114678c50c4b1af48f861f0d35aeaeeaf48e4dda5db5885ba9669e1272038015578c93fb0c566dd189e7eb3058b1b73e39a37a94dbf848c62ba7eb5e83d6ba27a9af349b956bc8600b20bb8636f4dd186437fca7c107c8ae40924927bd2cb6e2d2b0643ea373c01f7abd14f2c5033222b718191fe359284672c4d5df99489484c9538efef574cbc6545695959891c1f6a88934b23877240c0f156acae6c20b4be8eef4df9b9a68825bcbeb327cbbee077e07e2e01183ef9aa599b2cf4e5ae877bd47676dd47aa4ba5e9523113ddc50999a3183821477e703f5acd9d624b8912090cb12b108e5769619e0e3c71e2a3a2840514514014514500514514014514500b927b71487838a283c9cd00a33e38a7a32ab64f229b902323ce69b4b24964707b1ce7bd45477a296091029fc469e1504836be73fdaa0a01c1c8a9b162b0c311907f2a4a56209c818a4a82028a28a00a28a28028a28a00adfd0b54e9fb0d235cb6d63a7bf8a5dde5a88ac6e3e61a3f93937025f03f171fe18ec4d6051dfb5005684ba45d43a05aeb4f25b1b6b99e48111674328640a4968c1dca3ea182460f3505f69f7fa5dec963a9594f65751e37c171198dd72011956008c820feb55a8028a28a00a28a28028a28a00a28a5c7d39a0128a28a00a28a28028a28a00a28a28028a4a2a2c0b452514b02d149452c0ec9ce7cd4c8c02e41e6abd1c83de964a6589266e541e3bfe75b9d25d1dd45d77ac4da4f4dd9addddc36d25dba34ab18088324e58819c9000f73ed9239f314de80b831bfa45b609369da580ce33db38f14914b2c2e5e291a362a5495241208208fc88241fb1a36d86c4208383deba1e8eea6d5ba5baa6d353d2f537b062c239a41821a22c372b0208238f6f158122854423238e6a3a320d1d6359d4f5ed62e756d5efa5bdbdb86dd24d21e5b0303fb0031f6acfa4a2805a327de928a58168a4ad5d3fa735cd574abfd574fd3a5b8b2d3d77dccab8c463bfebc024e338033daa2c1975b5d31d31ad757750dbe87a0d91bbbc9b9db9daa8a3bb331e1547926b12bbae80f89bae7427525bea56c91dedbac7f2f35ac802892238e030195390083cf239cd1b06775df48eafd1bd5f77a56ad61f27b98cb06d3ba392224ed28de478fb1041ae5ebd2fe28fc4fd77ac3ac2e19923b1b2b3dd6905ba00f85c9dc5988c924f3e00e00af33a27ee05a2928a9b02d149452c0b45253a48a585c24a8c8c54300c08382320fe44107f5a58128a4a29605a2928cf14b02d149452c0b5b5aff004d5ff4e7f0ef9e9ad25fe216897917cb4eb2ed46ec1b1d8ffacd62515005a2928a9b02d15aff00c26c7fdd2fe35fc76d7e73e6bd0fe1b83eaecdb9f533db1e3fcf3c563d458168a95ad2e92ce3bc7b7956da462893142119863201ec48c8e3ef50e6a6c0b452514b02d1dbb52514b05bbebfbed52f24bed4efa7bdbb931be6b891a477c0006598e4e0003f4a853fe1db9c9a8a943153de964a1c7038c02695d70a180e3b547939a7efe079fb1a581b452514b205a2",
            "92b42df44d62ef46bad66db4db8974eb46559ee523252327b027fd771ef4b050a2928a58168abba3c7a5cdadd9c5adddcf69a6bcaa2e26b7884b24699e4aa92013f6cd549844b3c820767883108ccbb4919e09193838fbd2c0da2928a58168a4a5fce8028a43deb7f46e91d6b5ee9cd7b5fd3d206b2d0628e6bc324ea8c15db6aed5272dc83dbfc480560e7e8ab3a6ff000efe296dfc5fe67e43d41ebfcaedf57679dbbb8cfe755e4f4fd57f4b77a793b7777c78cfdeab604a2928a0168a0819e3b525481d838cf8a5da719a6e4e314a589ef4e01a92750eb12f4c43d3325f336930dc1ba4b62061652305b38cf6f19c566019f34ca2a0130df348916e5cb1006480327dc9ed52ea3633699a9dce9f70f13cb6f218dda191644247b32f047dc554a2a6c0b452515005a2928a016afd9eb3aa58585e69f67a84f6f6b7aa16e228dc859403c023cd67d14074baeda747c1d31d3b71a06ad7977acdc43236af6f3c5b63b690361021c0c82b9f27c76ce073748304804e07bd741d5fa2e8ba07513e9da0753c1d4b64b146e2fa081a15666505976b73c138ff00a1c80b060668a4a2805a2928a0168a4ab363617da9de25969b653dedd499d90dbc66476c0c9c28049c004fe940471472c9bda28d9fd35dec5573b47b9f615b9d5bd65d41d6fabc3aaf51de2dd5dc36d1da23ac4b1811a0c01850067b927efed8159963ab6a7a5c5790d85ecd6a97909b7b858d8a896327255bdc71546805a2928a0168a4a2805a2928a0168a4a2805a2928a016bafe8af877d4bd79aa258e8b6e9109239644b8ba26385bd3037286c1cb0dcbc0ce339381935c7d745275af52c9d2161d29fc4dd34ad3e792e20890056467041fa87247d4fc67fadbde80ab7bac6b63478ba5eeefe46d3ec67774b5dc191243c310477f3e71c9c773591494500b45251402d28233ef4da2805a2928a0169f146f34c91468ceeec1555464b13d801e4d475dd7c39eb6d33a37ad34fd66f7a7e1b98e0568d9e22deb2ee5c7a8bb9b6ee1dfc7e62960e4f55b33a76b379605644f42668c09461b00e0647154abd2be2c75be97d59d7d777b69d3f0c690462d3d69cb09652991bdb63019e70339e00c9f15e6944c0b5a36fae6af69a35d68d6da95c45a75db2b4f6c92109211d891febb0f6a8f47d1f51d7f5bb4d1b48b56babfbc9043042a402ec7b0c9c01fad4fa874e6bda4c135c6a3a3dddbdbc374f62f3bc47d213a7e38f7fe12c3d81a5a065d1494500b45251402d1494500f5c6e14f93838a841c1cd293b8f35360334b9fbd368a801451454580a28a296028a28a580ab304b66969771cf6af2cf22a88245976888860492b83bb2b918c8c673e3155a8a801451454d80a28a296028adeb5d674783a2afb459ba6a0b8d52e275961d59a66125ba0c65027620e0ff00f7bec2b06a2c051451536028a28a580a28a296028a28a580a28a29602b5fa6fa9f5ee90d762d73a6f53974dd46256549e2c12030c1182082083e4564515007cb2cb3ccf3cd23492c8c59dd8e4b1272493ef4ca28a9b01451452c1621b0beb8b2b9bd82ca796d6d76faf32465921dc70bb980c2e4f033deabd6c69fd53d41a574f6a7d3fa7eab3dbe97aaecf9cb64236cdb4e467c8fd319ec7358f516028a29d1b2a4a8ed1ac8148251b386fb1c7353606d6bd86ad6569d3faa69b3e876b777379b3d1bd909f52d769c9db8f7ff0059ed47526ad65ae6bd3ea3a7e876ba25bc8142da5a925130a013cfbe33e2b22a080a28a2a6c90a28a296028a28a580ab1776cb6b3ac697705d028afbe124a8dca0ede40e46707ee0f7aaf454580a28a2a6c0514514b0147634514b03e69649e792799cbc92316663dc93dcd32b7b4cff00753fdd7d67f8b0d43f8dff002ff877a1b7d1eff5fa99e7b7b560d4581f14b243324d0c8d1c88432ba1c1523b10476356e5d63569b4a5d266d52ee4d3966370b6ad331884a460becce3711e719aa345005145153602ba6e98b9d134631752dec969a8df69f7d0b47a1de5ab490dec5f5172ce0e000428da739ddf6c573345402e6a97b1ea3acdeea115941611dccef32dadb2e228033121101eca3381f6154eb5f4cbbd0a0d17578353d225bcd4278d16c6e12731adb306cb165febc8e3fd66b2296028a28a9b01451452c0da923827952478a1791225dcecaa48419c64fb0c9a8b352473cd1248914ae8b28daeaac40719ce0fb8cd540ca2933466805a2933466805a2933466805ad1d234e8753bb7826d46dac156367125c121491fd23ef59b9a5cf1401e6b5350d561bed274bb18f49b3b47b18dd1ee204224b9cb64190f923b0acacd19a0168a4cd3914c922a0c02c40193814025152dcc0f6b7325bbb2b321c128720d439a0168a4cd19a0168a4cd19a0168a4cd19a0168a4cd19a0168a4cd19a016aeb58c4ba2c7a80bf81a4798c46d413ea28033b88f6aa39ab493db2e9d2c0f69bae19c32cdb8fd23c8c7fafed4056a2933466805a2933466805a2a782cee6e2de7b88622f15b80d23647d20f6a5ba49c95bb96158d6e32c9b0055fd00ed4057a2933466805a2ac59c36f3cec97174b6c811983b296c9032071ef55b3402d1499a33402d5ed3b48d4755f98fe1f6c67f978ccb26081b5479e4d50cd3d25923dde9bb26e1b4ed38c8f6a01b450324800649ad683f86d9596a16babe9b70da8320f9760fb4447dc8ffcfe9de960c9a2933466805a2933466805a2933466805a2933466805a2a48209ee6431dbc2f2b052c428c9c0ee6a2cd00b452668cd00b452668cd00b452669734014559bdb29f4fba36f72a0481437d2d9",
            "1823355b3401452668cd005145150549a19c4292a986393d44da0b8cedfb8fbd4345142428a28a10491b44ab209232e4ae14e71b4fbd474514240633cf6a7cbe97aa7d10c13c6eef4ca28028a28a00a28a28028a294b330009e0702804a28a284054b712c72c81a281610001b54e73f7a8a8a12145145080a28a2809ae2713ba32c11c3b502e106338f27ef50d145090a28a2840514514039155836e7da40c8e3bfda9b4514039659511d124655718650701bf3f7a69248009240edf6a28a123d9d5a24411aa95ce58776fce9945140145145080a28a28028a28a0004ab0652411c822a6b8b99aee4335c48d24a7bb13e3daa1a2805450ce14b0504f73e28750ae5430600f71e6928a12145145080a28a2802942128cd9185f7349450135bdd5c5a4864b699a272a54953e0d43451401451450052803072707c71de928a00a72042e048c557c90334da0120e41a122b3331cb3163ee4d25145080a28a280ffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080100010003012200021101031101ffc4001a000003010101010000000000000000000000020304010508ffc400381000020202020104010302040405050000010203110004122105132231415114617132812391d1f01542a1c10624255262334382e1f1ffc4001801010101010100000000000000000000000001020305ffc4001f1101010101010003010003000000000000000111022112315141032271ffda000c03010002110311003f00f9809ce5e070cf4105e17861805e17861805e179a60f1f36ce9ed6e23eb08b5787a8b26c469237234382330693f7e20d0ecd0ccd805e17861805e17861805e575e07d990a2188108ef7248a82954b1ed881740d0f926800490306d5d84d68f6da09575e5768d2628783ba852ca0fc1203a123eb90fc8c96017949e27d69e481cc65e3628c637575241ae99490c3f7048393ca36c4cd026bb4b2185199d232c78ab3001881f0090ab67ef88fc604ef0bc30c02f0bc329acd02ec44db31c92c01c19123708ecb7d80c410a48f8241afc1f8c0eec6b6c6a4823d982585d91240b2295251d432b51fa2ac083f6083f792bcd1e3bc76df96de8343435e4d9dad8711c51462d9d8fd0c8c91bc3234722324884ab2b0a2a47c823e8e02de1794d9681b6256d68e48a02e4c692387755be83300a1881f24017f81f1845aef34733a98c08503b73915491c82fb4136c6d874b66acd502407228e49e548a246924760aa8a2cb13f000fb38979bbc26fed78cf31a5b9a3e40f8dd9866568f70161e81bfeb3c41343ee8135f47e331cb2c93caf2caed248ec599d8d9627e493f67016f0bc30c02f0bc30c0aa880eac8cd24a3603a848c460a32537225b9582084a1c4dd9ec500d307399433334290909c5199c1080359001b6ab23da281343baab3600d899607d7596410bb2bbc618f1665042923e09019a8fd723f9ceedecbee6d4db32ac4b24ced2308a258d0126cf14501547e028007c000648e3cd3cbb0e1e691e460aa819d8921540551dfd000003e80180986195d5d67dcd9875a36895e6758d4cb22c680934393b10aa3f249007c93904b0cf436f6caf8bd6f18d0420c3236c099262e5bd444e880c541a517d58228d10731c8b08488c5248ce52e50c8142b723d29b3c871e26c81d922bab2045b33c11cd1c33491a4e823955188122720dc587d8e4aa68fda83f58a63711890a3046254357448ab17fdc7f98c5cd32793dd97c7c3e364da99b4e191a58e02c7823b000903f2687fb27025af3b6b4f1ce8232f1b8751222ba920df6ac0861fb1041fbc9e194d8d99f6e4126c4d24ce11230d2316215542aad9fa0a0003e8003027861955d59df5a4da58256d78dd6379429e08ec18aa93f00908e40fbe27f0702581c30c030c30c030c790c452211a3ab05a90b38219acf6050a15c4577d826fba098063c622292991dd582dc615010cdc8744d8a15c8d8bec015dd84c301a391e191648dd9244219594d1523e083f47170c300c30ca6b6c3ea6cc5b1188d9e270ea258d644241b1c9581561f904107ec604f29afaf36dcf1ebebc524d34ae238e38d4b33b1340003b249eab3ad0a2eac730d8899ddd90c00373400290c4d71a6e440a24fb0d81d12a266585e10138bb2b925016b00814d5607b8d8068f5774283bb3aefabb12ebc8636789ca318e459109068f16525587e08241fa39bb4b67534bc66d7abada5bb36e2340824f544ba6559184a2a94f2f728ec9f6b5802b967f17268c5e475a4f2704db1a4b2299e286408ee97d80c41a3fefaf9ce19b51fc8999b55d34da6e675a2969963e57c15d8351ae83107f241c8336186194180c32bb11241b12c51cf1ec2239559a30c16400ff0050e401a3f3d807f206512386070c030cd3fa58e09fd3dc9b82987d456d72937b9a3e48a6980164a86eed2dad4b2f1ccd9018619c381dca344835d2513c6cececa6101b9a001698f5c68d902893ed3607572bcdfe3a2f152ea7916f21b9b506cc7006d248600eb34bcd4157258711c4b1b00fc7f63061c319c4616331bbb315b90328015acf40d9b1546faec915d594bca3b8674b1bf8afdb357878fc7cfe57523f2db33eb78f69546c4d046249112fb2aa48b3fefbf8c0c986765e025711333c618f1665e248fa2459a3fb59c5bc0b36cbbeac7ac562f4e377901112872582836f5c88f60a04902d8800b35cb2fe476d77b765da58962331e6eaaa8aa1c8b6e2a8aaaaa5ac850005143babccf79069860310d7dbdad6d87d2794a1643c3d4e3c4ba2b904060197e8d72048efb918596159894e2ccca00705ac004dadd81ee1448a3dd7c1a9de1794772bb1aefab208e4689894492e3916414ca1876a48ba22c7c83608041191bcd51ec95f193ebfeaf693d49a293f4ca3fc1938ac839b1e5fd4bca97da7a91fb5f86096b6bbedecc5af198d5e5708a6591634049a1c9988551f924803ece765d7786385d9a2226432284915881c8afb8024a9b53d351aa3544131bcbb49b3b70aac93978f522e31ac928f6217be2809ff00dce5a97f2c6be4e0470cbeac3eb41b8ffa5d89fd1843f388d2c1fe222f393da6d7ddc7e57dcebdfd1cf780",
            "e2290c4d284631ab0567ae8137409fc9a3fe472d31974c6c78f7fd3b54c39b27a727b9390f6ca2fdbee3fd2dc5bda7ba521e2f33e460f153f898f7674f1fb12a4d2eb07223775042b11f9167fe9f8198ef206068e689265dc976b67736677d992e40c47a86590b8be6c5811d163cbdc490057648cb9dca0c30c79844b34820777883108cea15996fa240268d7d59fe4e0265269df61c3b88c108a9ec8d5052a851d2802e8767e49b26c9272780ca0386070c030c710b342f3029c5195082e0359048a5bb23da6c8143abab1699053d52d1240dc0223b3d845e564006daac8f68a04d0eeaacdd669c6f4db9b5bdb7b526d4b7289187a8d3ca5c723231604582edcbdc490057648cd9489a0549c4d14aeec80425240a11f92f6c28f21c790a057b20df44106d8d397561d5964042ed44658ed185a8764e89001ed0f6b63eaec10175614d8da86193622d6491d51a79431488134598282d43e4d027ae81f8ca6c699d6d3d59a44d98e4d90f220921e31bc40f10e8f7eef7acaa7aa053e49b0b19e45966924489215762c23424aa027fa47224d0f8ec93fb9c8130cb49123c6d3c0bc224f4d19649959cb953640e895b563d03c6d4124904c71a026f0c30c6830c30c6830c30c68d87cbed86d178a41af2e801e84b0288e45218b06e4b479027a3f398f35f93f273f96d85d8d84d74758a384086158d78a2851d2802e876732605367667dcd897676669279e6732492c8c59dd89b2c49ec927b24e4f0ca6c6bbeac82391a2625124b8e45714ca1876a48ba22c7c83608041181abc3f90d7f1bb4f36cf8dd6f248d0cb108b60b8556642a1c7120da9363f8fee21b1148ebfac1a860d69a5758f8ab7a6185128acc4df10cbf249a22fe721946950eb4708d7895d5d98cc0b73704280a7be342891401f71b27aa09e1863c534b031786478d8ab2128c412ac0861fc10483f904e342618e266585e10138bb2b925016b00814d5607b8d8068f57f029328a493bca90a308c0850a2f18d5491c8b7b8816c6d8f66cd50f8000eb4483592513c6cececa6101b9a0014863d71a3640a24fb4d81d5c86565680a42228e4470844a5dc3076e47b514388e3c45127b04df740092068922762844abcd78bab102c8ec036a6c1e8d1aa3f041cbcb178f1e2e0923d9d86f20d2b89a168808d23017890d76493cbaafaff003cd7caba163ef346ea999df7a3d25d5d69e67f4d220fe921144c68589278865f962688b26ef032e030c0651abc6898f92d41affa6f58cc9e9fea4c622e5c8573f53d9c6fe79fb6aefabc84222672267745e2c41440c7951e22891d13409fa049a35450e1806564d5975f69f57691b5a58e431cab3295313034430ab041f9157d62c722a24aad0a485d78ab316b8cf20790a205d023bb14c7aba21320d1e475a2d2de9f5a1da8b6e389caacf10216403ec5807331cac26159a333249244181915182332df60120d1afba3fc1c91c0329b31241b32c51cf1ec2239559a20c12400d065e40351f91601fc8193c78e568d645508448bc4f240c40b07a24746c0ec51ab1f04e4098618640f0c6b2b9579a3840566e4e1882429217a04d92287d591640b23b06ccdaae64d79a485ca3465a362a4ab29565b1f4549047d82466bf0fe1377cecbb10e844f3cf0c0db1e8a233348ab5cab88354b6ddd0a522ec8070c610c8a24665424722a2c81f742c5ff0098c068216d89a3850a06918282ee114126bb624003f726862669f271e945e43613c74f34fa6b2110cb3204774be89009a3fefaccd806186180655b53613563db68255d695de2498a108eea14b286f824074247d725fc8c96181ea69f8bf1d3780f21e4763ccc5afb9af2451eb78f113349b2589e4dcba5545504df66e850bbcf3e1d878239e3558889d046c5e356207256f69209536a3b5a3562e890678601861945d776d69364345c23758c832287258311497c88f69b2050e812390b09e186181a37bd1494410fe99d60e51fea20f52b67dec4494f4458200f6af405add939f1e495a458d582011af11c50024593d903b364f66cd50f803132c00cee3411acae55e68e10159b93862090a485e813648a1f5645902c85ca3645e3277f1b2791f62428fc17d4b5f548e3cb812298af38f9283c80706aac85f21b837b7f676c6aebea89e569441aea5628831278a02490a2e8024f43e732e181d26f38329346b138549a3981556e4818004a8257b00d8268fd583448a2663280e77acd3abad14f06e4924c6368211246a387f88dea22f1f7303f0cc7da18fb7fa6b932c0cac6158884e2ac58108035902edaac8e850268775f26c2bb1127a51ec44bc227f6716995df9aaaf2240a21496b163f22d8a9399f2912c052632c922384062088183b721d31b1c471e46c03d802bbb13c80ce1cee70e068d03b2b3b1d4804f27a3282a6059693d36e6dc4820715e4dcbe56b902080467aa18f6b55c6cd7cdfde6ad9865863d69f6756489678fd4858a1559503152cb63b1c95d6c7da91f47186317c668f1f1eacbb90aef4b2c3aa5c09648d3932adf640b178a9b73c293a43349126c208e6546204a9c837161f6392ab51fb507eb240d0fc83f2320acdb2e76e69e37286467ee3411586b04715e941048e23aa35f19c5991756484eb44d23ba389c96e680060540be34dc813609f62d103903cd8825d4d8975f6219219a2628f1c8a559181a2083d820f4464f2033644dab06f45e8eeee47acc88b34cb081228640250aa1e980b7516c390abe3640c7860196899a641af26cfa70a73914396281b8f740034cdc556ebf1640162386019bfc7785d9f29a",
            "9e476a0935523f1f00d8944db091b329754a45620b9b61d0ff004070618061863cf3cbb33493cf2bcb2c8c5de4762ccec4d9249f924fde0261861814d768164276239244e0e008dc210dc4f13641e835122bb008b1763bb0205907e9de491382125d0210fc4721409e835806fb001a17414c2cb024c4a71766400382d60026d6ec0f70a2451eeae8d2601470cd5a6fa4906da6debcd24cd1d6bb2481046fc8596041b1562baffb89baaac600019dbb247d0cd48223e73b9a93424688ccf601f8b1f27271011c86c72201f8cd7c6cfb5c47197beb3a07aaeaabc4163564803fccf43fbe68ddd17f1fb73ea4ad134b0b98d8c6e1d4907e88e8e65119a248d22659e395a44e4caa1ae23c88e2d600ba00f5629877760486330c5194073b579c39480c6b2a1955da30c392ab71247d8068d1fde8e02561c7abfacf47cc3f8d9bc96e4be2b5f635b41a563af0cf2091d12fa0cc00b3fdbfcfe73ce562a6c63052708ae023a38e2a6d2eac8048ec0ec5d1fab1d58ef3b0bc103413327aeeb25bc122911b28a2016560ddfb81aaa0051efa913d01f8c53905a10cc0b020115449f8cb2e8eccdcc22b3fa69ea4a4292235b02cd7c0b207f2464182c31a1592290c896c003719e4451b005f40f56298777605f4e15d9259e555641fd247cfef9be66f8d4f7c6708090a18766893d0193cd3bf198e736a058fa1599b31d4cb894618619945f636629d38c7a5afae7d57939465c9e2dc6a3f7311c568d7fcdee365baaae8f959fc7eb6f6bc29aec9bb0886432c2aecaa1835a922d4da8ec7fa54366649e40f1ebc5ae0222148cb104aa805bdc49b620b1eead8d002805322985231120656663202793020503dd50a35401f71b27aa0ec5b33c11cd1c334b1a4e823955188122720dc580f91c954d1fb507eb2786180e2795617804ae22765768c31e2cc010091f64066a3fb9fce75a145d68e61b1133bbb218006e680052189ae34dc881449f61b03abe422269904cee911601d914332adf6402459fdac7f231301e4915d63558910a2f12ca4db9b26cd9f9a20754280eaec9a43ac9504db3288f5a494c6ed11579500e258fa7c81f861574188201e8d431a3e21d4bab320239053448fd8d1aff2c05c07ef9abc91d4937a793420960d3691bd18e670ee8bf409a179948aca3a05e34442b062b607cf7f188091f181bf93f78947a303471e8b2cc60f4b6250410a8d221407ff00cd54f3fd8311f653ac6c559bfc35e2147c93d9c963259f6f744fc0fbcd7cb7c5d58ec4ae022b1039742fef281595f848e031f9aff5c9c5aad2490c6382b4ac1179b8402cd5966a0a3f7240c492532d022abeef35bfaba1f816aeefec8fbce8500022fbc73baf333bec93b12189225795999a30a142d77f4aa1403600f81d02245c9a1f5f599d654fd3ccdaefb2b0c8608dd6379429e2acc18aa93f0090ac40fbe27f07203189bc51801ce839c386074b139cce9ca6ace9afb50cd2ebc5b51c6eaed04a5824a01b2ac54ab51f83441efa23e7209670fce5a5d879e3851d620214f4d7846aa48e45bdc40b636c7b6b3542e80028ab07fc3a562f07afeac615583fabc69ef8d7b38ff4ddfbacaf1eb960576e3f1c5a66d5f5638cb9312492091d56fa562000c40f9200bfc0f8cd6be8eef99dfdef17e35f5b403bce35d59e51a503380a19cf6429644e4df248fb39e56d6d4fbbb32ed6d4f2ec6c4ce6492595cb3c8c4d96627b249249273babc0bb2cb23c6851bb450c7900788a24744d026fa049a354773af65c5df5b7776546f49ebc02542a5555c9a16a406144760904775605823acf31ab91af8beb3d26f291ff00c2763466f1faf26ccb2c722ee397f561550d68a01e347903d8fafe2bcdccf7d7cada75768c6795a458d4840235e238a0048b27b20767b3d9b3543e00cecf22cd3c922431c0aec58451962a809fe91c89343e3b24fee73bb1ab3e9c823d982581d91240b2295251d432b51fa6560c0fd820fde6113c30c3036c7e17c84dfae306b36c278f52db324044891af2e3cb92d822cfc8241f9f8cc59a34775f427f5512393a20a4a39237d8e4bf0d4c0351b04a8b0458ccf80f0ebcdb2e5208a495c2b395452c42aa9663d7d050493f4013898655a646d58e11af12ba3b399c16e6e0850148be34bc491401f79b27a002582920820d11de5e3860965d68ff005222f5284b24c842424b117ede4cca1689205fc800d02618156e52572523bb26beb10a713f208ace89980005820dddfce7b3e277e6d7f11e522d3f1cd38961237677896558613246108f61319f52817e5df351408ef7e5578fe8d43ea5a952c05fde766d768121763195990ba71915881c997dc01254da9e9a8d51f8209512547c40a35448fbca41adeb1a2e13f04fde4cdf21ff0010c2f28b2220954c28e5d78ab313719e40f21440ba04776289eae889e443995d8513778ebabb0fab26dac12b6bc4e913cc10944760c554b7c02423903ef89fc1c88cee515d6d87d5d88b62311b3c4e1d44b1ac884836392b02ac3f20820fd8c4505b2b1080452096391e465a88a481423721db0a3638f215d7641bea8b45acf224b2298f8c29ea3f2915490582fb4136c6d8742cd59f8048b820dd1c519a35248536e07d841242b22991082432df6283293d7e181fdc7ce53cbc5e3e1f2bb71f89d89f67416561af34f188ddd2fa2ca09a3fefaf8c0c673a05e7446ee1d9519820e4c40be22c0b3f8ec81fdf05c0538674e535759f736a1d68da25799d63532cab1a024d0e4ec42a8fc92401f248c8259cfbca491aa2c6cb2a3975e4caa0da1b228d81dd007ab144",
            "777604ce0196d39d3576e19e4d78b652375768252c12500f6ac5486a3f0789068f447ce4455f78d49c092deebf8ac0a6c44891c122ecc5334a85dd1037284f261c5ac004d00ded24530eeec0d5a51a41e3f63c82eee9aec237e9d752687d4791244756750ca54711f07e41208a201cf3f0cc831e1825d87290c4f2b05672a8a490aa0b31ebe800493f40139431c4da02444226494ac8ed3ad32b01c02c75cba2af6d647b94529fea86019a3f507477267f1bb7b2a9524492d7a523c4c0a10c158d7242432d91448b2333e318c802bdc4fe3ebf6ca3b31899c1851d178a821dc31e54391b00744d903e8102cd59ec52a46932b411ca644e2acc5ae23c81e4b440ba057bb14c7aba2279a76761b69526730abaaac7c638d63e95428e9401743b6f962492492494825b5b53ef6ccdb5b53cbb1b13bb492cd2b96791c9b2cc4f64924924e4f2b318d82fa48547ddfd9c962cc067a5e33c879230bf87d38ced0dd3e8a6bfa4256e6ec9ff00d31448762882d7b343f02bcdc320d3afbde97e9925d6d6d9835e63318a48f8fab7c6d1dd38b952100ae42ad8ad1624e704053edb27eef398f0c6b2b95695221c59b93862090090bd026c9143eac8b205914698e33bd212cd1075455015020202817d01dd0b27e49b26c927352a23ea7a21852db1703e0d0ffae7988c508700759d590b4bc9befe6bace9cf724fa6a5c527d578c72254dfe0fcfef91e078f2a241fb18f2c8ca42072557e05d81feb9d8f67d2428aa298fbbff964f353c447ce5975761b5a4db58253af13ac6f3043c11d8315527e01211c81f7c4fe0e7679d2555558c2d7dfde440bccd9f895d562a6c674b922b170c0e8ce0c2f1d514c4ce6540c1801190793037647554285d9bec55f7545f57c9eee843b506aed4d0c5b7188a7446204a960d1fc8b032da3e1f73729fd27875b8891f65e3731c7197e0643c412543020d027da7a359e79c756650c15880c29803f22efbfee0607028bece7ad1f9bf43ff0c6cf825d2d6267db8f68edf053252a32f0b20902dac712bff35f2b1c7ca1193d8facb6d6c24b16bc6bad142628ca33a16b98f227935922e885f6d0a51d5d92c567e343e714e31378a7f3911d5e3f0dd7ee0670e1862831e65855c081e474e2a49740a79711c85027a06c03f600342e8776361f6640ee23042225471aa0a550a3a5005d0167e49b249249cec3acf3c73c88d10102091c3caa848e4abed0482e6d874b66acd5024641af0a4f21493622d7508ee1e40c4121490bed04db1014755645902c8985245d6732cc02c5c7d453d9b0bf7964216289248e6669e388c681951c35ca7901c56811744b7b8814a7bba048104d3c6924c90abb056964e455013db1e209a1f3d027f63931d9ca6cebbeac82391a26628af71c8ae299430ed49174458f906c100823209e6893f451cbb691fea678bb5d595b8c4dfd6299d3ddf2b7ed0dd120f22051d1e0bca43e1bc80dc9bc6e9f910b1baac3b6a5a30c54857201ef8920d1b06b3cfc02cd559ac30c781616722792444e0c41440c79713c45123a2d409fa049a3544130c32c93f3935c6d19a6821a5f4d64e242722c5549042d92c7e08b24d1c08e00026aeb1d1d516456891cbaf10cc4da1b06c51f9e88eec513d5d10486229188d1d582d4859810cd67b02850aa15df609bee80510b96308e239fb6fe40cd3e43c36d78dd5d2d99df5d936e332a2c732bb20e457de013c4da9e8e66d09521db8de41680f79ee793d14d8a99a458e8755f7f8cefc7f8fe7cdb3f8dce766bc0d8555929248e452aad71860012012bd806c1e8fd583448a3955d5b803f32dd72e205d7ef9c962fd2cde916563d721f57fce68f1f2969246a0d7ffdb27a399e79f72a49ee54b5a2d631bcdb320608780d78d8ac8e595a9c1e2578ab05e40904f2007d95249de3d73ad0cd208246591e2e678b3af20a4afc12033007ff0091fc9ca49b46dc708812b4028fce640aa240a6c0c592790a1bdcc405e3dfc62f13759b4eaa21b26f176a59279a49a691e596462ef239e4ccc4d9249ec927ef178bfd4c6522b35f958a08b6d961e092727f5a288868617e6c3844e1dfd44e2148727bb23ba0cd07914c091885032b3319413c9810294f75428d5007dc6c9eaa233280e329c538ca302abd5d0f9c9babf2ec1cd314ee903c204651dd5c931a96b5040a6ab03dc6c0347abba1485791e21a89eebf39acd8d611215681e42d5c7e324ca681eb18c8c392a9f69ffae02622ec06247dfd666e227946680eb46ab1ca3603b17732028c94bc405ab0410d66cdd8e85126794d75819c8d89248d383906340e4b713c45123a2d409be81268d51ca29ada476df5a28a7d6136c4de8849641104fe9a6777a455258f65bae249a144e7c7827975a68e782478a58d83a488c559181b0411f041fbc4c8002cd7de186535b61f53662d88c46cf1387512c6b22120d8e4ac0ab0fc82083f6302787ce535e7975e4e70c8f1b15642558a92ac0ab0b1f441208fb04e2c802b52fc650d134212512c723394a88ab8508dc876c28f21c790a047641bea8cf2835a76d77d958643023ac6f2853c5598315527e01215a87df13f838f14a6182608633eaa88dc3c4ac40e41ad49b2a6d476b46ac5d120b0430c30c81e7825d69a482789e2963628f1ba95646068820fc107eb130c057de068fd2fea7c87e93c6aec6dfab2fa7aebe954b359a51c14b7b8f5ed04f66ace67ca46a8f13208a579cb02a55ba0b47902b564ff004d1b1547a37d4f2878dd55ad81f83f1963b92fe9c42d453ebf6c9ecc49afb32c314f16ca47232acf1860928068",
            "300c0351f91601efb03e327ccd11d77fb659d58baec8c19ac5ff00272fa0d02cc4ec4d2c4811ebd240e4b713c41048e8b5026ec02480d5462e622b188d1d582d4859810cd67b02850aa15df609bee82035897fa9af655357d132c87d67604fe481ff006cc46158a404df66e80c4d39923993d6327a65bdc1180247dd120d75fb1cf43cdece849e4f664f171ec43a324a4c11cd2891e38fe81600591fc7fae77bd4ea7d37b29bc6ecc5a3e420db9f562de8627576d6989092007b53441cc3b0c1e46608a809242add2fec2ecff9e3b384450083d7ce2a981629c4f1caee52a264902847e43b6054f21c790a057b20df4419d1508664864667d78e7051d784858004a901bda41b52430eeac0b0458311964d5d89a279a382578a3215dd549552431009fa242b1fe14fe0e44672615d6da9f4b661dad59e5d7d885d648a5898abc6e0d86523b0410082315710e3ae06946886bc80c72198b29570e0285a3c815ab249e346c551e8df575d0485f6e2d9d82b3456abe8f1951dc3804730d5c6b910cbcae80f83632248148073547f26c802be73a73256e3cf913d372b7759e96deb7804f130cbabe47c8cbe449ff120934d5235f6c7f0c2426b9194035642adaadf58f704424f631627e4de6639cfa9958aeaf1e42fe31e45400156b622cd7c0c9e19341863c02269a313bbc711601d910332adf6402459afab1fc8c4cc80503d8b19578906ba4c2788bbbb298406e68005a626b8d1b205127da6c0eae58607568b007e33b216e44124d7b7bfac5c328e822d7976a3e6bf197da7d77e02042b428fef88abae7564669651b21d024623051929b912dcac104250e26ecf62806e2ec4cbaefacb3482091d6478831e2cca182b11f0480cc01fae47f3965f30d4f0c32ab26c694ce11a5d7940789e89560082aca7f904823f048cc82185258e777d88a1312074470c4cc7928e2b40806896f710294f7740cb29acd02ec44db31c92c01c19123708ecb7d80c410a48f8241afc1f8c9e06dda9a48c4112effead6189046c85f8c4adef3180e011c5ddc100572e44120d9e68e9a6db1f50b20afea1dd1fdff199d75a76d693696194ebc6eb1bca14f05660c5549f804846207df13f838ab2b2ab2a9a0dd1a3f23f19be7a92fab2fea936b342d561afb146ec62a46ce0a804902eb1a0d8f49ad9038aaa23e33b2489eb0922017ec0fc1cbe7d9e241082c0a9f6fcfed8dea218523f45032b3319013c9810294f7542891401f71b27aaec96c39116d747bb272dada6f244670bca8d05fb2724e6db90c46d540e62fab15ff7c0bfbecaf5969b4ca0e4a19be8802e8e4f8911d151d8bb3d66acb172a933c28c160924922e2a499230a79151c85027a0d601bec00685d09b37317f1933d0ac607a1d5e4d4d57537b6bc74ad2ea6c49048c8d1968da89561447f707330c76c419101c606b14e181d26cde68944daf1c0ecd132ce86450b22b903932d30049436a7a6a3546a882630c6b2cd1c6f2a42acc14c8e095404fc9a04d0fd813fb6264da03de68f21b516e4eb243a70ea288d10c71162090a016f713d922f33e70e03cd0b40e11cc649557f63ab8a650c3b048ba3d8f906c1a208c4c30c030c30c981c46a60790cc81959544443726041b61d550a00d907dc281ee8d89df676259dc461e572ec238d514126fa550028fd80007d6263ebac2d3c6bb12491c05c091e340ecab7d90a4804d7d58bfc8c604c30c31829b3b336e6c4bb3b33493cf33992496462ccec4d9624f6493dd9cd7e37c7cbe7fcbea78ed44d5d69765a3813d49bd38f9505e4cce7ab3d9eeacf407433063c262572664775e2c00470a7951e26c83d03448fb008b176183471ffd465225d7d031b492298dd99119412aa8cbc89b202a9b22c82580b6c9ef6f6cf93dc9b77767936366762f24ae6d989fb389b1b53ee4824d99e59dd51230d2316211142aad9fa0aa140fa000fac9e306c8bcb6c43e2363c52a6b1836268e6766854c81903000391c80f71b00ff00ded23d589fc7cdb477214963915175886e72020db0eaa850fbfbfe2f3618c057e7ac32bb3b53eeeccbb5b534b3ec4ce64965958b3c8c4d96627b249ec939c896031cc6592447080c41103076e43a636388e3c8d807b0057760279db1c68e3c301989008142fbcd32f8e914a2a98e998286621459f8b27a19a9cdcd5cac43e7e7376af92920017da45103af8cdbb5e393c7f90d9f1db314065d590c4cf0caae848bec303dff00bf8cc9b5e3d60d786791fbd8e7e9a1460dc16807f8e254b7251449b46baeaf725e7fdb9ab259ec74f92565751ed27e187d9bccd144fb2e63468815467b7915052a9622d881740d0f92680b240c5ffcb9d78d44722ec0762f21901464a5e202f1b0410f6493763a144b51a0083931007fed3f4325ebaebecdb59b3a0d66ef25e475b7757c7c3078bd5d27d484c52cd0b396da62ecdcdf91201a20755f1fc00799f33b3e7b6d36b6a3d58e44822d7035e048578c68101214004d0167ff00d6619639da269e46811e384b1288ee19956fa0580166bee87f03106180ca0386070c0dba1a1afb9abbd34de475b51f5a1124514a1cb6cb7355e09408ba24f75f1fc918b0ca344835d2513c6cececa6101b92001698f5c68d902893ed36075704f1e59de648918460429c178c6aa48e45bdc40b636c7b366a87c000266ddfdfd7dcd5d0861f1bada8fab098a59622e5b65b9b3737b245d103aaf8fe000c35856770c06263f454047128662cc58712b428015d107959b3763a15df75e67d69e39d0465e360ea244575241bed5810c3f62083f78cab01d6919a",
            "4946c07508823051929b912d7608216851bb3d8a00cb029abacfb7b316bc6625795d63532c8b1a024d0e4cc42a8fc92401f24e4ab3b86072b0acee387510b466242ccc184849e4a0036077546c5d8bf68a23bb09d615969b59e08e091da2227432204955c81c997dc01250da9e9a8d51aa604ac02269a313bba4458076450ccab7d9009166beac7f2302758566886049a193819db65482b1a45c94c6158bb16bb1c697aa2082c491c7b56d876d68f5cac5c237690111a872582836d5c88f68a04d0ee80e46c2358565b6b576347666d5da825d7d881da3961950abc6ea68ab03d8208208392c0e561d8cee398655856631b889d8a2b9078b3000900fe4725bfe47e70186cca1cb5f6df3d7ce6ad58e6f212958a196694901235b3c989a0001f24f5f19832cbb120408ad400aebef35cf5fab289639189e284a8efa1f792019495aef2e9b4c9207604fe45d5e1b7b926dfa41e595921429123b122352ccc557f039331afcb13f78b9f70ace41e5df58eee5ba1d0ce0ae3f3fdb2b3b43c22f46491894ff00115d02846e47a5209e438853743b2457566221861949e09b567935f6227866898a491c8a559181a2083d820fd6413c06180ca0386070c030c30c829b1af36acf26bec45243344e5248e452ac8c0d1041ec107eb3ad2a1d68e11af12babb319816e6e0850148be342891401f71b27aa22d87863991562226411b178d5881c837b4904a9b51dad1ab1744832c033d1dbf073eaf88d5f2dfa8d3975b66468504738322baaa33068cd3003981754483448209f3b0c031e1312cc86647788302ea8c15996fb009068d7dd1fe0e2618065206855c9d88e491383002370843713c4d907a0d448aec022c5d8e4ceb2ccf224490ab31611a1255013f02c9343f724fef898061863471bcac563467201621459a02c9fe0004ff6c0ec30b4ee510a02159fdee1052824f6481743a1f24d0164818986181b3c5799f23e0f65f6bc66ecfa73bc4f03490b95628ea5596c7d10731e1860194924574895618e328bc5994b5c87913c9ac917440ea8528eaec99e55b5674d68f69a09575e4768d252a783ba852ca0fc1203a123eb90fc8c0e4104db53c7afaf14934d2b048e38d4b33b1340003b249fac9e1860740c14d1bcbeeb3ccebb536e0db9f6434d3312e5d5cbb5872c3b635cac122987776067c07799a4f9aff2c4c32bb7b7b1bfb536dedcf2ec6cceed2cb34ae5de476365998f64924924fce2dd1b7cc6af89d41aa9e37c8cbbf2f061b4e6031c41c3b01e993ee652a14fb954f7d806c0cc20fd16e42be47576447fe1caf103e948f1300c0a96535c90821b891441a231f47c54fe435b7b6217d754d2844d20966546652c1694136c6d8743fd2f1e4065f4f436bc8cad0ea6bc93c8a8d2158d6c855164ff006032196d550f2b03b49adfe1c879bf2a3484f0f6826dbfa47d5b0b20591447018603280e19d2339581bfc7791d6d2d4f2104fe2f5771f6e0114534c5c36ab7356e69c4804d023bbf9fe41c1856536267d99e49dc461e462ec234545049be95400a3f60001f58034a875d221046aeaecc6605b93821694f7c685122803ee364f553c2b0ac030c2b0ac0ac332471ceadaf14a64408aee5ae13c94f25a205d02bee04531eae88961585606df11e2363cd6d3eb6b3eb23a4324e4ec4e912f1442c402c40ba1d0cc58566bf1b1684bb0cbe476278211139568630ec5c29e22891d1342fff00ee41933578df2bbfe1f61b63c76dcda933c6f0b3c4e5494652acbd7d10732d615941861585603ce6269a43023c71162515dc332adf4090059afba1fc0c4c2b0ac031e19e5d772f0caf1b15642c8c412ac0ab0ebe882411f609c4ac2b00c30ac2b00c30ac2b00cd3a5e4b6fc70d85d698a2ed42daf3a1019658cd1e2ca7a3442b0fc32ab0a2a089ecec3ed48249162521123a8e258c52a851d2802e80b3f2c6c924924cab0293ca933864823800445e31962090a016f7126d882c7eac9a00501c9a569e69267081a462c422045049be940000fd80a1895942b17a2843b994b30652a3885a1441bec93cac50aa1d9be82786159ab7f74ef48a46b6aeb4518658e2823e2114bb3f12c6d9e8b1019d99a828ba02827a9a9b1bfb516aeac2f34f2b0548d059627357927f1de86945a7a7b7adb51445374cf286124bcdbb55e2388e3c451bf8fee70a3346eae8c5594d8606883f9ce01907ffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003011100021101031101ffc4001500010100000000000000000000000000000008ffc40014100100000000000000000000000000000000ffc400160101010100000000000000000000000000000104ffc40014110100000000000000000000000000000000ffda000c03010002110311003f00981ad000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007fffd9",
        }),
    },
}

    local NAMES = {"Sakura", "Synthwave", "Galaxy", "Smile (funny)", "Pizza party (funny)", "Space cats (funny)"}
    local KEYS = {"Sakura", "Synthwave", "Galaxy", "Smile", "Pizza", "Cats"}
    L.skyNames = NAMES

    local hasFs = typeof(writefile) == "function" and typeof(isfile) == "function"
        and typeof(makefolder) == "function" and typeof(isfolder) == "function"
    local assetFn = getcustomasset or getsynasset

    local function ensureFolder(path)
        if not isfolder(path) then makefolder(path) end
    end
    local function toBin(hex)
        return (hex:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))
    end

    local sky, created, orig

    local function ensureSky()
        if sky and sky.Parent then return sky end
        sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then
            created = false
        else
            sky = new("Sky", {Name = "ScorpionSky", Parent = Lighting})
            created = true
        end
        if not orig then
            orig = {
                Bk = sky.SkyboxBk, Ft = sky.SkyboxFt, Lf = sky.SkyboxLf, Rt = sky.SkyboxRt,
                Up = sky.SkyboxUp, Dn = sky.SkyboxDn, Stars = sky.StarCount, Bodies = sky.CelestialBodiesShown,
            }
        end
        return sky
    end

    local function setFaces(bk, ft, lf, rt, up, dn)
        local sk = ensureSky()
        sk.SkyboxBk, sk.SkyboxFt, sk.SkyboxLf, sk.SkyboxRt, sk.SkyboxUp, sk.SkyboxDn = bk, ft, lf, rt, up, dn
        if cfg.skyHideBodies then
            sk.CelestialBodiesShown = false
            sk.StarCount = 0
        elseif orig then
            sk.CelestialBodiesShown = orig.Bodies
            sk.StarCount = orig.Stars
        end
    end

    local function supported()
        if hasFs and assetFn then return true end
        Notify("executor has no custom asset support")
        return false
    end

    function L.skyApply()
        if not supported() then return end
        local key = KEYS[cfg.skyPreset] or KEYS[1]
        local data = SKY_DATA[key]
        if not data then return end
        local ok, err = pcall(function()
            ensureFolder("scorpion")
            ensureFolder("scorpion/sky")
            local ids = {}
            for kind, hex in pairs(data) do
                local path = "scorpion/sky/" .. key .. "_" .. kind .. "_v2.jpg"
                if not isfile(path) then writefile(path, toBin(hex)) end
                ids[kind] = assetFn(path)
            end
            setFaces(ids.side, ids.side, ids.side, ids.side, ids.up, ids.dn)
        end)
        if not ok then Notify("sky failed: " .. tostring(err):sub(1, 60)) end
    end

    function L.skyRestore()
        if sky and sky.Parent then
            if created then
                sky:Destroy()
            elseif orig then
                sky.SkyboxBk, sky.SkyboxFt, sky.SkyboxLf = orig.Bk, orig.Ft, orig.Lf
                sky.SkyboxRt, sky.SkyboxUp, sky.SkyboxDn = orig.Rt, orig.Up, orig.Dn
                sky.StarCount, sky.CelestialBodiesShown = orig.Stars, orig.Bodies
            end
        end
        sky, created, orig = nil, nil, nil
    end

    -- своё фото: имя файла из папки workspace/scorpion/photos или прямая ссылка на картинку
    function L.skyPhoto(input)
        if not supported() then return end
        input = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if input == "" then
            Notify("enter file name or image URL")
            return
        end
        local ok, err = pcall(function()
            ensureFolder("scorpion")
            ensureFolder("scorpion/photos")
            local path
            if input:match("^https?://") then
                local ext = (input:match("%.(%a%a%a%a?)[%?#]?[^/]*$") or "png"):lower()
                if ext ~= "jpg" and ext ~= "jpeg" and ext ~= "png" then ext = "png" end
                local sum = 0
                for i = 1, #input do sum = (sum * 31 + input:byte(i)) % 1000000007 end
                path = "scorpion/photos/dl_" .. sum .. "." .. ext
                if not isfile(path) then
                    local body
                    local okGet, res = pcall(function() return game:HttpGet(input) end)
                    if okGet and res and #res > 100 then body = res end
                    if not body and typeof(request) == "function" then
                        local r = request({Url = input, Method = "GET"})
                        body = r and r.Body
                    end
                    if not body or #body < 100 then error("download failed") end
                    writefile(path, body)
                end
            else
                path = "scorpion/photos/" .. input
                if not isfile(path) then error("file not found: " .. input) end
            end
            local id = assetFn(path)
            setFaces(id, id, id, id, id, id)
        end)
        if not ok then Notify("photo sky: " .. tostring(err):sub(1, 60)) end
    end
end)()
end

-- ============================================================
--  ЧАМСЫ ОРУЖИЯ / ТРАССЕРЫ ПУЛЬ / ВИЗУАЛЬНАЯ ОТДАЧА
-- ============================================================
do
(function()
    local TEX_DATA = {
        Galaxy = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc000110800c000c003012200021101031101ffc4001c0000020301010101000000000000000000050603040702010008ffc4003d10000201030204040404040602010500000102030405111221000631411322516114718191071532a123b1c1f0244252d1e1f116336217437282a2ffc4001b01000301010101010000000000000000000304050201060007ffc40031110001030204040504020203000000000001020311002104123141135161f022718191b1a1c1d1e105f11432233342ffda000c03010002110311003f00caad764a6baf8b415bceb43cbf4f1aa4e8f5c24756677457c0556c3004124e3a0e8012a3a49ebef69414972ad172a1a14f87a6691d8288d5bffb6080c1773d81c01b0c0e1eae361a1a3be22046ac12653ce1930806d938dfd3ebc52aab6c5432c1e2d198652c0a8d196d270431cfb77cee0e7a1e3f700d82a2b52bc86dddef5e5462d3960535d8396ac5a68eb24b599adf14e8b570d3b08d950efb3f6ef903dff4e73c1287f0b28aa6b64aa995618c48da56560e71b60e700138c7619f4df866867b5a621b2db24869658a091d27944a4c8134b1d80ee49dfd49c0c850629b45156a355a2d4a464379f7e9df1fd3e8789ef631e1396dd3f531352b138c793e04ab5df7aaf70e4eb0936e8282d2f489052a40cf2b19e49dc1186766d8818c0c630001b00a1675e4ea3448a2a4b7a6a6f349900608c649c7cfebc68149045cc8d24b494b224923991c94089938cefe9b0f7f5dcf12d551d65a2f354a2d49510cff00faa521b083502371b0db623e5ee0f991fc8b8986e6e3626be0cbaf2b88b272e93cfdab38aee4c65864ab8b42c928d421ce349c9cf97edf7e33bacb13db2e351f155255075329c63b1d8edd76ff00bc9dfa817e2ee55303d534aa8010d1819c8d8fd4ff00cefc56e6ce424bbd13082531a962408f2ad8237fe5c3f85fe5cb2e06df36355b07844a57981ac0285956b20ac8218e49a9a559d04e81d1994eda87423dbebd47036dbca9517ce688284470c72d5d400ab2958a30ec46fb6063638503d000490387bb8f2c56590b34b4c22849d885d23af006a222c7528d4e01c64fb71eadbc4a5c054d1171aeb5ea9cc1a0a429274e54bff9155d0d5cb0c460d00b2cda487c79ba2e93823aee09cf6f7d2292ff00574f6da0bc5eeaa92fef0c72d1436dad0ccf4c8100490ec01dcef93be3ae46501d05a6a6be82e13446058e8621348259951997505c28272dd7f90ea4029d5d72aa4ac9a142cf4c9846f00e594ec7237dd80ed919dba71f38918bf0a883975e771ee3d288d86d848226b68bd7e245d66fc39a0b7c768a75a89d9d19e4810218d748d4885749c9d436181a4e0e78c962792aae725c277d029f2485409bfbae37d80c63d3e5c7d7de7949a2a3a182e559596d810a5b9ead30160d654151d08d4b8ce7a2e3603013afd793541297cae88c0c80e7449b674301823a6f83f5df3c0705866b0cd28a1206624dbafeb6dab6e62102e36da9b286f86a2dfe34ff00c19a57c690765236c03be77cefb76e1d7982e86ed70a25a9bc57dee829e9e3894cca21917ca3c450412339046a39e833ab009cb6e172b7730dff00f30b6d053d8208183bdbe1c945c81e6c313d5b727a7b0dc973b7494d2dae0921d2b1e9182a3007d383adb0a0974883e9bc4e9a72b1ad32be2a6157a268f5b41f9dde397cfe5d6096a529a5a29eac7893444965560086230841d2738623246b3c2a5f2c12733f30cf574b5b4561b6d6ccd20a53148eb0e4ff0094a827b9e831ed8e1eeb396eae2b1c175a9a8a5f849d51f104f1bcca199c0fe1ea049fe19db23d32086d342e29454f573d3dbaa249a815d8432c91e96d3d891bfaf7fdba70b36e2164e43274913b46a6f27cef14ab383c8b289947de6acf397e16f2a72ef2dd8ee74dcd34b12c74fa1a37d5235566491894f2e4139237c7e8e3159ab268eb6a60929e38e1546713193aa107181d48f28c91d3a1c63774bd4d53355514113c938b7538022954491e159dc964230763923a6d92303850e6aad7e61adb95cee56aad6a8b82b4349353aad2d2a4aa63793a2e96001c91b632a4ee430db7fe46118f12ca8924ec279088e5d7a522f36d855869542de8c127ae78a3ad48b1a6462493d34af5c0c67d3f9f05aaf55cadd1d3cda43200aac8833a71a749c1c9246719ff00a4114f73a0a6929cc8f0c736ce84823afb67076fef7e0958692ed72aa869edd1b6177d7be9c7a1dfdb3f4f6e389c540085a0c9efce95757093168ad7ff000faf75f14359607b8d4fe5ac159a9a7918ab3a00a98cfa0c6c36c05eea3073996c56d96c8d5f531cb13c40ca8e91e35672a7076db20e77edf3e2a7247294cb5e6bde6631a281a9974e49eb85271db7e34ce648e4bb5a28edf54e1296869cc4d3658839277c312076d87cba0004e5bc197929037bf7bec2bca3ae8e36604da290eb6be8292ed495d5342958125493c195888e650724315c75fb7b1e9c4f2dce96f75c6aeeb502add631185918b84503651939c0c0ea49ee77249cd0f3751eb596a1964889d2ada1b7231b81fbf4db3c4f73fc4c925b5436ea2a7a77",
            "829ea1e5590448ae1d80d9db04b6cbeb8f6c0186ca51208d74d76e9af7e54ea706ea8049addb952d568b9dea268ea4505118fc5626653a620a5b5066c004e3df00e7a0e3c86ef68a8a4ae48fc496ad261f0d2ab803c3df21954ec49db6277fff00ac1ea6fd75f8137baa8c454f1c51a0d4c7c22cc3caa0e00076240db653e870f5f87468aa529fc296598b303addb67f6e9bf5cf7ede98e147f061254b5ac9b0b728eba99a3e33081090a22f5aef2bc7707a8f8db72b0a98a21e2790bb32f53f3034f41b927b1c70d171a17bed44b5eae67314ccb0cca34f85b90abea08cfdfaf61c2fc91c314de04727c3411e7510d8320c6ea71dc82cbbec77ce3b94b65c0222312854643aaea0108c9524f6d89c7b938e3ca6233295c646be5b5630c4470d745ed36696db28cc806bdd9446065b18209c9e0e4be2ba978d80f086a619018fb6fc2adcf99c504547fc2107c4c7e2404a1c4c013fa3f9fc883d08cc239c56e7571d35b293c7a990845823cf99bbee7a746273b0c6fd33c4e561b10e9e2287ad52c9e0cad9f4dea1e648a6b8a4e9228654fd11af723d38c5abe8a4a367f8a8c40cce4005b3b7cf8d52a799214b842d152c954ef0c89594d55198fc09465401b8248db6fb609c2e5b76bb7c3f30413555b92be1825123c33674c8076c8f913f6db191c7aefe210ea01445a27bfdd7306a7b065c79f54ab96dd3e7d286ca49835c7a5b008181b1fef6e0754f23f325349541a88d2b410254982690248e8e5557421dd892d8c0df3b1dce38a72d7c5117aa788aaea27c28b7d39230064e71c1fb6736535358aaaf1535b5705d68151adde08d7e2bae950accc46005c8c6e303d829f52ae3b29ccd09f49f8fa9f5da8aee2dcc40cfa014a37882e97d4a0b7d7567c541490b454b0c8c714f193938c8c0df23e5803f4edcb5968a148a91d53c343acedd5bab138ed83b7061a93e26862ba7e611d4dc6baa5d1e8e3d6d374521c9c10c496c7539c77df11d551d6d25d5edf7089a9eaa99889239060ae3fb1f3db8611926040d7a79fd77af938fe21e1a13e2b75aeac14b6da682ec6a6820a996b6010475136a56a61af5663c1c7418eff6ca92f040b4f4f1c0b8c2800903193dcf0022062790231969c64e5707ed8c9f5e0950dd692b20534f501df263c6e4e47639fbf0175041241d6f5e9704b1c301420d5ee64e67927a8355531d3ab450c719f05162002801760002481fd36181c2cd4736522cc213a82952410060b6e373d7191d40f7dc1e095f2822a9a32c5090408dd54e015271fb678a732d916cf6ca3869053dda0578aa008df132072524625ce58ea607007e9f40a38cb68425294a136d3cab4eadd4aa069432839aeeb457882e96bb84944ed13c4c612753ab820aec3a79b6ee30a7ae0f1cdeaf97bbaf2dd3d9a4aa9e5b7524ad550d14a40855cec4e31eb938ced962376624a5a6c16979de4b94d514b40629648cd346253e284608ba5b4ecc71befd07404b08228e3ac3089d4c6aac226289965dc8240db3d7d7edd786e19528ca4488bc79e9f5f29eb524e1dd5037b93bd64f74a9682b9e10933782d87071a5b6f5ebbeafebbf052c978969e49845138dc2b10082873e83ae7df1df839ced4dcb54fcc35a946d34a914ba69ea265f0de45cec5bb01d32db9c2f419e1499ee347531d742a43c6448cd2c42419ce77d6086f4c1ebd37e23b84a165732358fcf2a596c032955eb78b3f3c45476cca40de0a2e8f1ba09080b9d24ec700838ce775cf5e182dbccf1565b95ea64d52b75889cb039c0fefdb8c2ef7f8a774bb72c56d96e74d4b3cd5170f8f59230c9f0cc41122468a42283b6f827a9dc9c80769e66b8525e56b6a263246ac71e20c77eb807ae0e7e6075e9c2aa7185ea9854f3a8ef7f168376b5abf5bce1f1dc974bcad4b64b75241e4927ab8a0d7515322bc9a5d9dc965d9c82011edb1c7143c3b62f2e534b055cef7733ca2a29cc4be1c71851a70c189624ebea33b76c02dedb2e7556e8ebadb051c120b8d28865f1a9d26915032bab26d953903f4efdfb0206b542d2ace0445867118c795b7c0df3e9e9e9f6c25011736ab428ed04d788acc6cc95f3fe595d3a4e68d58e2475d4a8c573d71db6df1d48187fe5b8afb072e5457aa4d1db68a548964f0c9456604aa12bd0918dbb6a1ea3297476d920b7d15c279630b5f0f894c619d18c403b2e1f4fe93b1d8919ee32301ff932d705c28d2a2aabe5a6983eb1a4aa2068f3ba95db2b93bec40603186d9d4e54a33207dfce80e94ac14f2adf3974bdc2d66e2d4d2bacb2f86a090d863b91bafee3b91b0e8455f79c692db493c3467c52094281c63560e9db39eff7ec36e2f437341cb71d05ba512534cee8e73a98ef927b9277ea31be0601e14eaad16a9c4ccd17c2958d54943a4b939f7fdc63a9e3ceb0cb6a754a785a6c3f35e68aca1520e949c39d2496bbc0aab8b3cd4d1131a6e34e598b0f4ef9df1fa8f7e0edb799aed6e8e4b8d9ea248d9633e2344db2c6700963bedbae0fae31bf19f5f2c91d8ee951533b4ba25506250dff00b0e46751edbf4383d338e0753f3bd7d353d750d2d44b45f15108eaa2472524407207a9e83b77c74241f505961d4e5005f63a4777af4183712a4c93279ee2b4eb4f39c5597286d76ea76aab8d5308160886b62c7dbb63ae7a0e15eefcc934b769a3aba2f851167c549069752360086c693b1ce7e59e119f9a6d7787b735151a5a2b6dca03d552bb87a960fa83b3138523501b60f97e40069e27a925ea6a72eaba7544a3271eff00efbf1869080b2b6d36f3ebe7e558e02ffd499067d6b4cb5c",
            "95ad25aef4dcbc972b5cf54238d275664aa6523c802f5ced8dfd763b8e2a474f413c925755d2048d8b3048d8940a4fe91924e07ccfcf8096db6f337265ee9921bcc74ed4d1c35d14d4954b22c7e2a02a7cac4648c0ee0e31b83b9ca0866b852caf71935b924b4a1ce4fae73df27278a4d2cad1c43607913ccfa7aef47e0ac1f0267cea2af7912b212b13474bfaf52924b6fb280074ff008e04565ea335e2792a98c92b36657ce5c927249f5ebb927f7e0b3786b6bf0a95b32ab14666c8d206e4e0fcb1f3f5e13ebaa61aaac68dd804d3afc52061977cf4df1d71b70ce7084cfa09ac298cc52a02298a9a9d8cbe232b327883311c90c0608d5820e0f739efd7bf036e70c5557dabb8535ba9ed7453ccf353d2534ac0023600162760188cfae4e31b7135048b456885eb6eb088dc2b9770eca07a1d3939dfae31edd73a2ddb90394e2fc24b65e2939c68cd5cf512113a2cb22543158b318023c82303b0ebdf89d8bc4b48523383274d4ebe56dbbbd56090001bd2dc351555965749244768d72164275b1d882493efd0f1df2e50545de0b85ca0b73d425b21124bf0eb92aa3fcd91b1ddbec49ec78583554f4523b475703989b4831e426db060081bee3fb1c3645cc770e609be3ee2b4b4329a486924828e9d69e392388285c84c03fa14fb0c0002aa806595ff00ab711a9e971b75bef6a6d2b2a50e744de5b44d5669ac0f5525198d1de4ab83c161315cba05c9ce0f7fe630c48dea786748ea62b2c36ea5118842c25fc367441ad83313b9246d9cf98672492542c15024b95caa29a65ab8491839556037cffdf7fa705ef9ccd728b96451bd5bbdb20632c31313e1abb0eb81db6f9024e3a9e162d9cc920cc6a49fc5a69a4a864cc4d23f368b1d55a0c11dbead6f2279269aac4e0c2e8555514205076c1ef9efdf0b9f427c09e09a63aa1652ac8cdab0bb1231dbebdfdfa35569a8a98e79585424ac9a8440812676ec3a8df7c7518f9700ea21f0ee94f2cb4e674895488e652a1f0dbeac60e3aed9ce0f5e17c4b401cc8eef50dc24a8a8d14ffe9a5e6bedd4b5565a3ad9e46b549749e3a989612e892b213082c4c83014edbee3192ca384e12b46d1789111861b69db1b6defc15acbb8abbecd5f4d6f8a8a983b98e92191bc3823666cc6a49ce9f3367700ea3ebc74d2c557244c816031e2370a31a71d0f7eb8dffdb890d359a4cd0ac053955496692582bacf4b2d0e98954c2f3aca524d00391e5c635807183dba6400b1784a56a56fe0aad4e31231272064609cecde9b9eff004e3da7a89a69da2d05523728a77000d58c819db7ededc12a098c1452ac68ec7e20a108e4ea63df7f5cfed9f5e3d24a1d464e9126fdf9d2e90a36ae2c352969b45c2dd70b752a1b8d288a2a9ad59cfc2b975cba04ef852bb838cf5c12a76eb4f2072b58bf082ddcc6dce54cd7079e49d668c4af1485962cc4a34646063aaefabae38c7abecd724b3d15eab68664b5544cf4f15495cab329cb00c0f5009f4e8719c1c1ee51b7df6aeedcb112d81ae76ba8ba3ad2d3563b474f3c9a630ca581c745dfa8383b30d4388efb05242d0b8093d2f034bd87f747570e329deb4cb15f25aa49e8966a6ad925c61829c630318040c6ddf1c5eba3250c91c14f5eeacfd233903d3d77f90e313979be4e5dae78a06a5a4ab333a494fe1968e937d257396242ee41dc9c0ce78b951f88173a0fc475b9db4d05c45ae7d54d221f1627237ce863b8c77006927639009eab2e7f06bcbaf5d6a32b0398954d38f35ac5158a796a5a59db480182864562365cf63b375f4db8c8ad748f79af984724aa912f9181074b8ce37c63bf4ffb0fafcc179bbd96aad755512d35257489552d303e1c3b83a5f4e318c32f403234fa0216e95472b5fe789ed34d7685a9a5568a79240819e3215fca54ea5273b9f960e083ac169414e091d37f8a26102593955497719c5257c861778f5b752bb91df3fcbe99e085a2eef6ea8695ad91dd226864816099e4d2ace8555c68d27218e7af5f438229dd1e922ba524915297f071e2c72bb10cc0e749c1040f91efdb86bb3f35c66f372ba5bed96fb7c732ccbf0662f1e28525054aa87d58d8ec7b63a636e15402e3aa424c6bdcd54cc0893566aec55b63b65a63aea888d6d5d3ad4cd0346fe253a3b1d3ab2064e900e0671bedd336ed7ccb494362b9dae6a28ea854cb1d445566576642aadaa30490307cb918fb8c6035356d248e22aba9d4d2948c54b92da3650721724aaa800ed9c0000edc7d72b1d28e60aba24bdc577a2a56614b3c11948e7008dc1db3b637c753dfa9aa998421373eda73eccd11260509aabfd5cd50f4e95c6359bc352aa709191d80f4f970e370b0dba3fc39927172a8178a3982c50ac28229226ceb6672dd7214631df6ce72b0c5c9d516c82df5f5f6c4869eac0a8a79a73a4ca81c8d4a586e339c8db6d27a11c5969a9d28673333346f94986a1950db6c00dbe5d3df8da5852d0a2b5fb6d7923df5a2b10a1e21a8a59a8b54c2dd634a5bfd25c26ba0334f4b1c6c1a8df511a599971a8a8ce41fd8862e7609acbca7c9f55497ba47bacde77a56a790288256d01890577c84c7b60f6dc265155bd3db6b6d66c90d64d3cf1d4437162fe2425437f0d34b05d24b039c7f97e4558ec56782b6e3516f7bc416e8e382597c6a9064123786cda72a0fea3b0cefb8ea480536500a4a973234379e7b515a30640bd28b56c55b5ee65c53c72e92ae836031e9f6f4efb74e1f6cf4a295da449499a45659a295bcd295c02d93d4670474d9ba76e33ca8acb7d500b037852c44898c802e4eaebb75c7ae",
            "3e7ebc7d41ccf516f2d235419e6da320a96c2efb83f5edebc6dbc421b51ce6677ae36e042a4d6a56bb416e6a5a6b6f834de2d3ccf23554cb1c7a123d6575391e6f2ed8edd700120d5a12c778434f7baba88696481c96a74d6fe2683a5705863271f71d33a86636ae78b9d24c62b6c1034d5424458eae2594c625521b01ff00f8b794f61b6e0f0767a559ab685ecb47534750e21874554a25915801af4944e8cc361d77fa0305f14a82348d46c77d7d3ef4d21f1b0b57d7b8ed16f10a784efae412948f01c2e74919c1d2339f3608047bf0abcc6f41517daaacb3d34d05be49dfe1e195b5948f6003300016fe806e4ee746bf5155d9efa68ae70bc33a9314b03e01270300e719d81f9e7233df38bbc922574f1bc50a53c8ba984401ca86db7edb8236df82b8d85a42f35bbee694c690834b3f0d4f5b7045333c4864c4ac91ead23237032013bf4c8f98cf07aeb4569a5bd986d12cb2dbf5b1a796ae0313d444a4807486c1c9523391d0f43b7057978de23fcdadd6ab12d7c773a5c4a9f0c92b08d195d990f55380371839c637c714ab6bab6e10d1ac9593cf4b40be0d3472c9a8d34658b61475c64f51ec0e00e11461f2ac931adfcb9c54bcd22d51b57a68afb4d35b217a8a8a88ea9eba4d7e241a43655349c61b503bafd0f9713d6596f3476a827b8514f4d435b19a9a5a89721248c9c641cee015fdf3d08cd08f54f54e52691c3be4ba0d470c32463a9c1cff004df83f66b055f305cadf60d90d44df0e86ae50b1c40b6701f3851a98ec3a93b024e3822104e65036b933a7ea8abf0d07f12a851a53d5d54b246f23471abb1d28ceab97507be147b1db7db6a17f36db7c36886cd7caeaca88d0cd503c2f06282a3591988863abcaa9e6c03b039eca46e969e63bfdf1ac964b7cd707a4495cc74a4ccc1635c3b161b1185382339d400249e0572d592a6eb758a9286196a2e550fa29a0806bf11ba1040c9c6fd7b6e73b709e2941c73829361bd6801a8a1f456f92290d556424468461245397246dfcc1efdb6238250d4c3f979a7f1963134855a2006060e5483d71bfd77df8ed1398ee55ff009446d3f8f131f115d4a784c093e738ca9ce460f7c704283928ce952f555620689080883235f604efc75b68910c2491ccdbef5a4a4ac455eb65d39939a6fb059c4d5978aeac45a5a7d2c5a51a57c801cecbb6e4ed80493d78a7cc11df6c34746959f0f00ae85e555132c9346448c8c2400ea47d48db30c8f982002a9a1bad96ed4b3d4348b2a3096192225487183b1d88c63af162f569bc4762a3be359aa60b655bb430d5153a1dd0658038ea01fd8fa1c2af29d032aac05a37a0a90099a196cbd57dbee0d550086a25786480ad544b32e1d0ab1018100e09c1fe99c90b8da60e5dba474d15f63ad12d2c33f8f468e146b40cc84385dd49c67b11eb90075a69609e4692a65f0208ca892551964c9eaa36c9001db23e63af0539a6aed155cc3529609e59edeb3114f513c5e1bb27404ae48076ce7bedb0dc7186db09487546fb0e7b574aaf02bbbd4b4f7aad8a5b5d9e9ad51253c709869a46d121540a5cb393e663e6237ebeb9279b7db2ed15ae9ae970a3aaa7b4d54af04357a74abc8a06a50c47618f6d88ec7174dced12f31415174b29a3b5fc27c2c694152f1a89047a166627c46c171a88033b7f9883aa0b8a50db6f325be8eec973a5a3aa91609e07cc32f405d03818242a8cfb0c13807861bca1c1162350771dfbd64cc569fcb56bbfbd0d173243619eed6aa172cc66590d3888302cb95236cc85b6382751c1018054b8dba69af692343e1a4b26886346c98cb100000f5076c1c938c0c93bf14282e1738d26812b815ed1924ab6e36ebbe4a2e7afe9193b706a8218eff6ab8d74f73a6a0aea6843c749531b7f8c7cac7a142839f29db3fb8048bcb5032b5fa000f3e526f27a5130ea514f0d4289d2d3c74f553dbeed4924159149e15442ea40491401ab6e9b637f43e9c4170e5daeb745f9c8b7ca2dd2661866704453385c30d6760486073b1ceaf7e17a8ea2aa891a5aa859a59a40ef29dcbb1d8924ee492a3b77faf0ff00474372aee57a6acaaa5ab4b64b23a412ca331970a35819dba05f9e0ffa4f1a23c295a8807bd3b34fb2f870f0b7aceaf3cae95334f594406b6d2891449af5b1006077249c8ce384c962969503854642320107607a1c7d3afbf1fa4f92ae35d61aab44d67a3a4a3a08eb1a966e649e269440664d2030c151800e0e00dc02402c595aa7936d9ccb3d557545d28a9cd346d23894499ac6d6170ad8077d45b2403b0ce06ac48c432971c5641111ccdc93ac0b6c7e40ae9633094eb59ddbae951172fdcada94d0b8aa68ea51be150ba32646048572a3cf8d88dfb6e72e745045719a3f8dff00de493fe9076ce71f3efb75e25ffc524a68133571340a8a8c48d24e91b63b6c7a77e08c96cb9d8e14374b6496ca9302cc91ca9e628402a71df3b7d88f5e28e19b4b432cdcf7f715c502c8f10ae6a28ee57d9aa2ae8e0a9ab7b6835354d18d4c819f059db231d7d3d49ce0e15eaec93bb4b3cb3b3e24f10c1a760b9ce3638ea7707e9ebc1ea2b2de2f7ccb44b69a5ac925a976d691292245d408ca8076caa9df61804740786dfc43fc3be69e5ba4673473c9154410ff0089854b244de1287538071860d83f5efb10becb6ef01c5093a09f2eb48b8b538248acc44d2d3d354490c815a50f4fae350a22c865d208ff00290464647f31c4334f674b753d1476ea98ef31554a6a256706278f0be1aaa32ec41c9c93dfdf0be43521e38a81e06a5984aa0c891ab6b6231b83f3393f",
            "2f5e22e64abe5e4a4a08ed74b56661118eada793795831c151a54a80ba463a1c7ae4913ea488572efcfe8688254917aa369bdca96da1b5c7414d1cb4b2cd33dc0b39799195408b19c60119000ea46d9cea65ff00c92786d75f67d34e28aaa78aa1dcc48d216452174c87cc079bd7ed9390dc8ef256d96f14547c9f1df6ba580c626292134a01d7ad74b01ab4a3f51d0606465491ae84df2586aeed531c350628e0d3451a221550aa320637031ebf6c601822548c8819a2ff008fafc504954104da95e5b8b449345473491060f1ff000d882eae02b7cb6c8c6770dbed9e2a85a9a1aa58636782785878622720a3e73b1eb9cee0fcbd387fb6f2c5a63ad8e77662ea3650e48c91d7afcf1c1f96cf4551510cf1d323d4860abe1ae5f3d86db9dfb77e0abc2951974dfa69142cca4a6522d40b92aca28e9b554cec649880622a54afb107be7bf0fb6eb75aeef2cb4535ce1b4c469e494cf2ab00ccab90a348272703fe4e148da9b2dde8e9ee757576c9a08edd28a7aa262da19083a54ffbf4e9bf98647f2dde7e0ef0d3bd829aebe2534a0d34acde4ca3664cae3f4efd7a053b83820a5b05a3c03a0b446b13bdb91bd159c52c24a5498f9ef5a8ea282a27ab8c14d69a3cacd803aefd7a70bdcdd6df85b3e99515f0c5826af282d8dd7dce900e31d07a638d01aaa3b18b45ceb69a92e34b549f129019c378815cae870a72a72a763f5ce08e16abe5a7ae8d96a2208305962663851d94139dbb0249ebc1d254e8298b5efd6e3e9bd2afba84252d8be87bfb766b24b742e8c6298988b3630ca0823a1ebf4ebc114a0a7a5af8659e9e368848c444e4959b04601c30246fd8f6ebc77553d1cd2872a4be0a854c9db3b6fb1cef8fa7cf8eec368aee78e66b7f2ed0b47254d64a23811e551a3aec5890480327d76db890b4b4ca329831a7ef956924a95352dd2e14373e66a8aba5b752d050d59794505264a420e7ca809ce0607a0cf400715122b1c36caea6f84aaa9bb7c4c6f4d56b3058a184060ead1e9259b25704376ed821bbaab30e5eb52cb70b84125d7e2a7a49ada858cb4a63d23596c6960496c618f4db3be2d72dd7727c747713cc305c62b84bfc5a5aaa4d2d18c23f91908070cfa7cc0f61d0024aa5c69484858883d640fbd6ccc92285c13d653a4929916224f55206c0633f4c67f970f7c8d51412dfe8e5bf5335652ea1e3a46e159e204e402463276cf4f4dba84aac8bc4a37959b4302762373d76fb0e9c33d3cb6bb6c369aab3d6cb533084b56433c0104326a234ab0273e5d2738fe78575b94b9c324c1fbefd29d6550013a53c0e59b65451d2dfeb6b04166a9f898a9de9e78ea6a4488b950eb95f2e5865b6f9282a780d457fb7f2dd715b95347758d6190ad1d4cce238cc8ba7c55d240c8c29c672748c60e922bc778a2829a96e17ea69e6a6439969a9e610eb0480c14fa67a673d4e4efb66153312e7c047589df31ea6d6ca739eb801bb76ebf2e0f88794d27239791e51afaced3fbad2d694ab337a9a334b7931732c886aa77a69dd0bc6afe567c690581eb82c7dc7b9e341b3d6d353e95aa20ce64f0c92d8c6c30c4677e8338e9c64f414a5ea604484a4b23aac7a9c28c93804927639c75e9c6954968aeb1dceaa82ed3d3fc5d0c8d4f98e61226d81a95bbf7dc6fb9cfb0f02e15e642b7bd69b78a3c5134cd553543812191020620693924edfdff3e3c79ccf44ed53ac855544d6356c3017277d86140f4dbe8325afa78da9a924909c0c108ac4139f5ec3e7dbe5c5eaecc74ee89106330d187e80637f911fcc8e2965020456d4ef1153b1d697a1aa92c5765aa85d2353312f285f3239c156cfa64e0ffd0e343bb73edaae324778e61a84bb5d2ded4c94d6d97cd4f3a08878a58ab02ada80ec7b64104854795ad54b64b8cb78b74f515552a9f00f14c23585f5f99dc104b79030c0ebed90c126921b5d5f2e5da7b8dcaa699a38b553a4502c8677d60e9625bc9b6a3b7a1dcf428630a33c94dc6fd2d30761b1d08bd05290890054f15450555d669a93489649752a31d6a37dd575364e0138cb67a6fdf855b956492d63441b42231002f4dfb9f7f9ee3a76e2ddcea2d14d52a6c55d255538a78b51a883c1732e81ac6158820367727b77c64af96d4e58ee49cee788f88c5f110122d41ad03f305a1badf6c9cad7daf5e5b9ea9a78297cd08980d48ba97531d9588dc9c8009df610545f9684f867350a196308c3723186f4c9d8e3aeff00b0be5d828a5bc436fadb8474293bf84f573160910277660bb9f96df3c706eb4504f1181e489a1562a3661a80eadd88f5c11b6d919e2ae0810c14b44255debdf2b528b542e4d32d9ea0d62254ab158bc3d28bfe91e98e186d778a8b6554953470c4eff0f24256689655c3a152403df07aff00424158b73c51db4243e76ce9272371d319efd3b9f9f07a8544f2ad18a7699e63a10443277db4e06e4e7ef9fbd9752148f189115c60e65940350540af984b4c0b3a4f2092a359c163beedea776c1f7f7e2fdb85c6c956b516caba8a391e9e484c9131d4e853cd9c76c6a24f6c03d8104ef51d05b2ded6aaaa3aaa1be524b20ac69a5063f0f6d384c641ea7afdc30d20e9b986e94529a8a0b849493f82e83c36d074952a46dbe704fededc05254f36722441e7a1e477b1f8a2bcb65060ce6dbf154685a8e5ac77ba53545453bc6e163a69446eafa4e96c953901b1b63efd08fafa6a886458eafc42ea8acb1484a0d2c01538c742bbe7f9ed929448e29b55453aa02b95c1193f63f2f6ebc71ce9cd72dda6a2adb845fe229691691e7f159da6507ca5b5b6",
            "338c0c8c6704f7d982a21c903c3b99d234b7cfa5225190052b53b5245ca6a786d73db9ed34af35654c45ae0fafc5a70b925546ad055b50276edf2c08fcb278da0aba22d154ab1788265245d3bebec41c8db1ed8e196ba92d11d35a26b756d4d455cf0bcb5d14d008d209f5b00a8751d4a14e738ee0f53a543d7dc1d639d12995c068904aa9b292a4e0b0e872361e80f115d6592953ce4893a77f8de69842c939450b9c354563788591748661ab0a7e59d8761c454f3c74cc25929c4f4c18e9466ea47af5edf4e0c58ebab2cb7cb7dc214a799e0952658e54495095391a95b63f5c1efb1c11c54d10abaf7a88e1447572cd1e958c1391be800000edb018f970a869c51e2205fbfb568a80b1d299ee36bb42d343a6f34f7085a38e569e984883cc8ac548603f4962a76ea3b1c803e0a27a434eaacb5748ec09d3927e8064b01b704615b1af2fd4412534925d25950c3502506358f4b6a050839c92a479bed8dfcb72b44cb0b48b2d3ec401e56539ec7a76fe676e2e270ea90542e37b5ff55c4e253948af1de9ea64869de709f10441962aa63dc10b920055fd3b9e9dc8c710f3959399b94266e4abdd0c14f25a6792a55bc34cccb205d2e25032ca40180771d0e08005bb95a0c923cdac15c8505d479738386c6c46fb11ebbf04ae766371fc3d33a5be892a2df542292b9aaf3573aba058e3f0998e514478185000c63187253c634b5292affce9d64e9bfa446f444af3826b3f068d046525325439185490295db3d48ec71b7bf0c32b72f372fd1bdb6a2a24ac2545c1255280be5b0aa031d630a373f605b0a8d594951477230cec59b25973d4fa7c8edc3af2d72f4fcc88b434bf0f04924135507ad98428c514b336a62016c02075ea4f407131a7159d5984659b5369322051fe417b6dc2b161ba493d3d12ca16a24880660a49c90a4f5c77cf4ec4e413b5549e2554ba19d572705a355070080c7ae3a93b67e7b678c962f8da0bb454be1b348d3344053efd480318ebe9ebdbb71b5c34572aab55c64a534d18a28525733cea8e54b05f2838d4d961d3f9900d3c3be48f1182205fbeb14742865f10b0a559abab2db75b4d65be9d5eb69640d134c0494fab5127529d88c637eb81b60e38ab52b0dcf93dea2e978b44535147f0b051c346216911d9dcc80aae09058f71f4c8cddb8c56a86c93d5d65654c77089d3c2a78a1530cb1b06d4c5f2082084036db577ce4225c6a9e699636914a01a8a28dbb1c7a776db7e9ea78ee292d825cffd69df3def4a87495411a52b54d3b4133ab00b83fa436ac7d7fb3c5ee5caca0b7733db2bae96e8ae54505423cf4b28256540464101973b76c807bed9e237fe245223611dc8eb9f5ce38ae94729fd45577c6e78f2ca6893e116ae6614c16ca5a696aa9c4ecea3c65f1648d753a83fa8aa92327a6db7cc70e5cc6dcbf6de60a8a7b6d43d4db12432432cf0847704e35103bfd8fb0ce3805cb494c669652115a0190edb0001fd793b75c7fb7037981266a890534e65a646ca67000cee40fb1e9bedf7f4c951c3b1c64fb6debbd2900ab2aa9d282e749e2ad2f8c8b0ca7690e5906fd7604e0637c03d3df7788aa47285c2a7f2faaa3ac6225a68e73006495194a12038eda89ce373ea3ae194978ab732f825231282749200cf6c7beddfd06fb705adbccb1c9435768aaa585e792749a1b8bb33490955606318214ab120e483d3e457abc634f4055c2ac45a0fbd7c86d48cca4eb16e94f7354895dea9a46a891dc9660d9249392493d785a92f74de301244eaeefa54a0c839c0077fa74e2f1b0dd28ac95177bedca92d1344ae90d1cc4a544ce34790228d4be593396c763d0ea00edf4b14f04abe1ae98fc81d4027b74fdbafa7cf8a2dbc1cb326a6f078673397abcf7664a42f4d3090444ab2379c9df6dff6fa7dc10bd55d455bbbc2ac22024dc0d8ff0053bf6ec09e2f3d91de9e59adf14aae9fc498ae4828485c9c6c07980cfa9f5e3cb750c7495be3c98601b5e904e0b0fef3c65c46216a0916e71dfd28e9710257bd5ab6dcaaa8855469146c6be1104be3c019c018391a865492a37dbebb628c692cd68a9b52575645472d40965883931cc467493be32339fe79c0e3db9d4cb056a84f0be1dc6ad6772ebfa76c6e0e0e76df03e9c1bba5dac75bca168a2a1b4476cbdd06b5a8a88aa0b8ae8c9d485d1b2cac3560e0f6f42a104e06f370ca335efa72d6e7a79fa57c0a8f8c18a8ebadb62b2d5a5ba9eed49742f4d14c2640e3cec992b9751e604e36fd8e4086aa281a12cf8594745ce30d9e99e9ebc04aea6b77e59473d155d654d5bc656a84f00511b6b3808413a8692bbfbfd012e5fa8d76fd131336353649ce146c7fbf9f04c2bf30d11b773faa13ad91e3066823ce4c723c523695dd188201f3676faf7ebc32d968a46a08e591e44d0351390c08c7a6fef9e2f55728cd46943769a9a7a7a3b841f134a1d4e995724160739ed9dfd47af16229a8d60312158dfa10c304020e0fb75edff5dc3a0ffd933b5bce8d234d0d11a3823adb6dd1ff0031869278604992099326a0ea5051762350c9c03e9f3204582e16b86f74770b8524f5945154ab4b121505d7ba8d4083b03b637e9b769e4e5eb8c162b8f3753dd611494b2c71352cb3aab31656230350257cbd87bee012095ab983966ab963e12f964151355bf8d155c3218e4899508d009f2e32c0e0e32477c0c0d6f0f1817d88b48d058fd79ded4cb6da8a80dab36e74b8cb7be62b85faa604824aaa86711468028c9ce06140d877c0cf5efc7d4550282c3535863c78b22885c9ea46e7a6f91be0ec37df83dccf",
            "69e5aa5635367b8d7dc1e5ad910c1353782169f2be13860e772dab38d8f5006d958ba555a0d57c2d92967a2b63451868eae7139f182289245601460b038dba1edb058057c2733244482074d877d97824a75a97962fd67a2e7282f1cd141555b451248cb0d14ab130974108db82301b04fdf7c60eb166bef2e575ce9eb668a7aba056533ac474368c0240246c7e9bfaf4231ba8a4fca28a86aaa23a7923b8a7c442d04e8ce8ba8ab2b004953953b1c75f5c80f36fb95347c994f436ee59822929e56aaa9ad7f1449a2458c26ac9d3a3ce3a2e0ea5c632757d825f8885199d6f71d47eafa532d3840228fdca8686e4aef00912019d31b386122e7ca85801e833d380559cb1256c269e9685be25893142b96cb60e00c76cfa707a1ae85a898d3a3ace154e5d41c6e3237db6e87ee3878e5ce69a3e5fa6b7dd6dea95b714a92b3524f4512aac474e92b26ed9ce7a0fb6016b8fa9496884a334d84f95af78f5a483438c4137ac4b9a3931f979ab4d757c54d7086ba6864a0747f163552ba64ce900ab127183e9e8702a5a7b2ffe35493d35c6abf3879e5f88a57a70912c585d0c8fab24925b6c76ed81ab5ffc65e693cd7cf52454515a76984518922844ba039c13215f2e7b966c01f5e31ebe59aa6c7ccd5f69b83c4d57432b44ff000f28963d43ae197a8fb6fb1c10788280ac88ce21444913df7bd69d68a09934ed14762e70e60a6b7f2cd861b1d3a4a2921153585da70cee434ccc70080546c3b637c01c105b02fc0d75355471c843144552181201c10dd1ba9dc13ec71c0ab558619674816a163f19fccec719ff00e3f6278d6686ef60879721a551ae45f2ea1be7237c9fa0fdfa71496a561db0cc4cebcf53bd41c73f9480dd61adc9371a4ac594b68830de2be371edd363db3c52a1b4c9669fe3d32a157c685df28d95620329f6604647707d38daf9c2f76f6e5eb65b6cf67f06640f257d4cac499893b05c00028001e9fd4b205d6e72deeaadf475171927a6a387c08a267d4b12125b0b9e9b9fe43b0e2470e60445cebdef5a6f10b50f11f6a54be735df39cb9892a2f7749aaee12e987c59dd51576c2efb00bfb0c93ebc10ada1b8d8ee75968768b346cc84c256442c0e3cac1bcdd3e79c03c71cddc9f6fb2730474f6bbd417382a608aa219e15750350f3282c064ab02b91e983820a80ed2db21b2d6cd3d555fe7114b1a52c0b0a989a321b5bb3e4152085c0c7df395670588e020a8e9a08eec3d3da9d58e2c45355befb7e86b64e5ce5e5aaa9abbd14a77a288328a95d60f86c010707491918c0cef8ce4a5af952f5cfbcd8f3dbb969edb4525c929e786157d14a59b6425b74c0073f4e9b0e33eba0aee5dbed2cb709e3a8ae5582b626a6aa0ea81955d72d1b641dfb104751d8f0f7c85f89fcd56bfc41172b3b7e5f667aa5927b624d27802367d9402dd86ac76dce00e836ee35d796b2c0054a161f9f4fa5b4b5690c252066a131d3bd939c694731dad2a9e8274f88b7d5332473efbe70475041ff007dc71449f1ea6b0f851a3e9601175623232428d5be3a7527a0dcf6d5f952c3ccff008a9f8811cdcc1cc01a1692396656b8abe02b64ac7196cf4c63638cefc26fe24f2953f257381b6c1718ef10f871ff008a66a7591a42a352054738c1cec40e98dff516dac6b697f84e7fd9009892371ef7e55d5e194119869413f36b554d9a82d3516a821aca7a89256ad52c249c155f21cb69d2b838381d76c6e5be11db810e4189d70e1db75201dc1f418fe7c4b0d9ae761b8a9bff002e89cc94baa286b95e154f122ca49e5c313820ef8c11d8f1463a2a99a58a9c542c6acd952e09d2bab6274824edb9c0cfa714585ca490991acebf7f8da9471a2209314fb4335e39a2aed1638269ae1e0a0a5a2a753a846a493a573b0037ebd00ec06d5aaac7570d5307510e8628d0b8d2c08d8ab03df23a1efc053155d9efef6ea0b9a54253546982ba9f5a0974bfeb527cc0838dfb11b67af0df0238a651527c5980c17e84e0f7ff007e359ca214dc049da3d4f7ad69ac383255334b53ebf0559a318030c58f95875c11fdfd781f551d245c9662379829aba8eaa38d686446334a8c872fb02bb7cc7ee32d828c4c8cca8c9b654953d7b7b7fdf6e142e3c8f35c6adaac48b165461176eb9c83ea77c67be3b701c5294b47fc7ad3f8361c4a4822f4b1555d1cdfc079bc357640238f503181b9ea7a6493b1fb7026ecc9084a7a79564846703a9001c0dcefd8edc3441cb16a8e96aeaeaeea89353ca918a4766691d581cb29d1a703033bf43db6c8f16b4355389208969d700b990ee7a9193e847a0e22b8d3ae24831331bdb7f6a70824c52916c8c7403b0e1e6cfccdcf974a3bdb43cc724910a18a1ac8ea6b154cf4eac91ac6158f9f1b6c3df392d86155bca570a5bdd35054494ccb3c714aad4b511cdfc3750de5f3618807a67d37c107875b67e1b5a25e6ea6b7c3706a8a5abae14d492d5914e24c9f2ebc9f29dc6db93d80271c4e6b0ce28e716037da05642493422df35754d94982655975852430034ffa8f5f7df83b55702ac1231a880416277eb8c8c7d3d38237ab8586dd47494d4d414746b471bc333d3c864f19b51f3162c413838d8e3036d881c01f8a82450ad03448ec22504ef2138c0c7aff0079e3d934612331bc6ff3eb4a58d508f952aae8b5b53cbd435066a24f16a5e21a954671befb6edbe7d33d8f03e82c37a7aaa81f95d5dc28edcbe355c94e992885806cbe0e9ea06707d7047046492ec8812d713885980958305c2e41c3ae7d403d7a81dc70c968f06a6c17d92e753590dcd69f14d1",
            "d3465d6a983290afe65d2a373820f4cf518339cc3a64a920882340636ee6d44490af0a8d0ce754aae5dbc780248331a475022867574c3a8390c8c413e6c636236c6470b8d7d9d2bc46b53e144ee0b05c91f7faf14a08e47f88922d520a57cc8b2790fdbb1db1ec7e7c1036aafb90463432a472b6a184d5a4636f974e27ba971d95efd8a03896e648ad92df649eb6c1435170aca59a2af84cd00a6a8595957514c30072a72bd0fcba8601569397a96d17eab3242d528b8d1a46adcfea18ff009db3c52e5bb1f31515a2a6f56ba7a816fa391229a69170aaedd173eb8eb8ce323d470c32188596bae697da082be391634b74a596460c0f9d5b4f41b673feaede5d5d62f0a5dc831a6e7fb1f351f86b42ce4ff53493cd77eb8d5434b4b5553355d3514462a78ea58b88a30f9d201ed93f603d070bd4371b3c34d757ba53d65454bc3e1dbe48a711a53cbac1cba904b0d218633eddc156de7aacbb569b45aabacb6da6fcb2daaad536f60e65591c3869594901819147ff0091247ea038cdeaa09e388121f411a88ea31dbdbd7803ce2892a02074fd73d6abb4d65002aa2710748753375d6c3f5e76d87a707395507e72b0a160d229504e3031bf5edff3c2facce8d18641322b06f0d89c301fe53820e31b6c47054d5a5c799e5afa5a5a6b4c15139916089888e0527a0d5938fec01b0e00c3812f25405362b508e1bbf2d7e53ce541590d268ab655114ca64fe19566d48092170476c138f519ccea5a4aa91e5aca96795ceb92477d44903a90773b0fe5c33dda48a9ecb555095225591731a301e4c9eab82460ef8df03df7ca9555aefb45f9554d450494d15c504f492d4a058a750e57565fcba72bbeadb1b9db1c51c7b894380a8493f1b56d629af9279a2e947593bd34b14f532c0f4c8b510a4a16268fc338d40e30a063d0003a123871b45ba2a8ddea1de543a892482c0f6df3e9ebc0abacd4771b9d45bea686db4375b7c8d0d754db1868a8959d899060951e9b60edbfa0bb60aeac8a6f82ac8a362643e68f526940bd4e771f2cf43c52c283fe3858ff0068d47213436d612e043825269b2828ace95fe2dce8a7ac85617545864d0449a48439c1e871ff0038c18a9e9123a8f8732ab99428064214024f52c4e00cfdbe9c4b14f933659879b6db008c713d65ae8c5821aa8ee90c9513cae869006d7128030c4e318393f61d770045642a144dedb9ebe955f80d09534904f76a2b7aa3bec8f5d5b53431494f6b78e866a9a28d040acaba5775c0270a33e848071951c29d4c6664511b0494618055ce76381d3df8b54d248d40f4fe311164332a13a198674b633d464fdcfaf172e37da3b5b5b2aac8971a6aba78f158f0d4e0cedac9cc642f90e36efe9838d4d96c2da84244f28b0d37d77fb52c33a139947bfd509e61fc3abcda6d569badd565a686ae0672738d0cd23795893b79403f51c2b5db952cff0094c5594d73aa96e33cedae8da306244c2e870da8e77d59c8d864003009d1f9f3f1539939ae2a6a4a079edb6a60cad034ec2563e2b85d6463385d1d73d3bf5e16ae1ca72db3c2b7f3151bd3dc5e3154b1cb90ce08cae73d46fbfb820ee08e32c075c692718005924c03b7ea469d2868585ca45e8059e96df4369ad8ee3454758278d628a6a8f14ac0438f3a18c1ea148208ee3d482e7cdff87f63b77e0ddbaf5373a513d5b4d2488c44ba25ca44342809a815233be3f50df85aae5a3a2a68d22a38cf8bfc3046eab9ff00be132e9535973b4fc0b3b48d472c922459c280caa090338cf9071bc5e19c5a52a65445ee39c0effbbd2ce2d2daf21a82be4a16b27826b609e6f043a80092373d0900e7603719dfd382f4176b72d0c09ad27999551977233d00dc1037cee4fdfaf02796e5aba6a6bb45471d34b4d718d69a632d2c729540eb2651df753951b8df18db2148f2aa8516aa49e88244d8c18d703076208ce77c03f6e3786388502e651161e6282e2d092275a6da47b6dc090aecca5bc372ae406f98e876f9f5f43c599ad95dcbf70305651cb4b50516758cc663f163386c91ee0e067d0f083e2b40902c0ff0faf0a66918b0439d89c0391b74dfa7dfabfc957477e9e9cde45ce18a530ad5c529fe322ed919dc606074c0c0edc15cc5042ae36bff00743e22d69ca2d56cd65aa066a7a1a1f1ca80a4201e6ea3618f31c9cefc6adcb7c89ce5cd7ca576b8d9ec92534745483e13c45653349ad0baa03824e15ce067b0ff0030e32eb5bdbd39b68a7bf50d7575bc3915489261e440074639036f977e9c32bf3754d987345bf972a27b659ae51b253d3cd2891e25f15081abd7008fa9ebb9e16c4ff94a6d4866011178b6b71a83a50525acc0aa85d9ee37f82e3554778b6d55399119e486489869d0092fa4f70baf7ec09edc583554cf3cb23552cab1217739d58f302738cedd7b7603853b35e6f5cbb3c9372fd555534f246e9218e46dd58157d5a4ed907ae31b03d40c1ce5fe62adb0de26aca5a485f5c0c9509590a4a23565d2c554823a37dfd891c770cf29b4949b9f5d7da8d924786c2a186f9514369b9505354d4531ad1e1cb028235c65b2aaded91f4071df1c07293ba0f88a7f1a047cb2452a863b8d875d249d81238669296d55d70a5356d3a411b6cf472f86ce36f2eea7076206c40cfd382dccbc9d6f83998fc0472a52c917c4405ea454e88dbcc8aee9e5ce0f4c6738fd4305977da3c58379f49d29a584368cc76acc6f34f43f9e55b5a292a29680ccc69e39dc3b2267604edfde067bf1411a54a8f03c169b40666541be00c93b7a0073ec0f0f955cb15060b8d6ad7d02c56ea5",
            "134be3d4ac4c3cca84221c176c91b0f6ef8068dbed97c4bcc37bb7d7c343f9ad2cb347f0f560b0898b46cb214fd04e93d71bf7046d39d63239c341f14e9f5fc57510b129a0b77b35cecf1353d5d4d3485e086a334b5092a68902b052532011a9763ee4646e68c76bbb5c2f14b66a38e4b8d4b9f0296388970d924e13d06589ec3724f7e0f5e6cb353114e8fe2e800398c8503df6eb9c0dbf7e0254c7220a7aba695e09a2648d13243c64670c08f75276e991c7cfe15494df51d9ee6b24c2a28bf2b5c12cd552c55b4eea7c40b2c2328e7190cbb8383f4db3d38d848e59ada392b2c9256534df1320f81a94565861c029fc453963b9c8c7b760cd8f582d3e1d92aaf5f1d4df134d511c42dac1fc595486264040d2029519cffb6a7eb647728b11cd0223be43f50bdce37c60fb7f62ce0256c0049053ec475d8fa5c5032ffca2448a2b255cb1b985409514e309be1b3bae7dbaf162395d4e99c78677d05b1d475e9b0edc5f868d630a230aba4e7d76fef6e2ad7d1b4906b8b0c0677f7ec47d78682d0a396aaab0af23c64cf4efb155ae17aa3a9ba7c3d928aa6389e38e110487c691a6180d8d207ea7c8000ea46c33801eed5f3d92f9536eafa3a98a5a7611cd049852b29db186ebd0ee0f4dfa7162cb4ad70bcd1c55d5f05a92597c296a6a15bc28d490b9c7a7518d8671b8ebc41516bac5b8cb5cb5515532cccde2952e2423392c5d416ce33b8efb8e3413955c349db79f9f4f3a13814b01691fd52e5cef95835bd3d3cb1a839e8362586dd3afbf1e504dcc0ce2e570a8aa9b5218629e5dcb6945014377011976ed91ed93570ab96a6e55776ae8a3d7572b4b2c51c6151723200551803208f99ce4f7294bf984b616b5bd4cad6a86579d28de426389d8618a8ede519f6cb77278ca9b70ad2b51d351cbf3b50108cba518e46e4ba9e72e73b5c55570a38e28a549678c55c61d9430fd31ead44f5e83b7d384ae6eb04bc9978b95bea24a5ac860902b490d4c6d92c094074b1d24e09c1df0a76db8a115caaec7ceb437ea3ac684d3d44721657d27670739e98f281bedfcf81ed7ebc3c0d48f7ba9a5a4a8a94a9984533696a88f3a1db7ce46721b6e833d884dd5e283ea5208cb00011d759a49494a7c2ad6bee588ae557cd14960a2a191a6abab11494fe190e8c58020f7073b76c771c54bb4f51a6b5208ea23784013978c8f08060356dd3ccc833ee3db8d53f08bf106a28bf15d6e7cc377b7c72d5f89354d6d652ab4b2ec490b22c65816fd23040c60760a68f3973df327325bef75340c9462f1188aaa1a68638fc78f5e7cc55416dc75272413be09cacdaf1aa0b65206509066fadc102de7f4d26b8be1c851d66b3be5faab18b656adf29a7acaaf87d3412c33aa2d3c9904b48083a86904636fb90ca76e5f87d7ca2e50a2e66ae4f86a5aaaa990bc80e55424457a9f28cb1fb1db6c701edbcbad1533d7d257d4d37c3c61e69206234316d21750180739ea77c1e34bb8fe2cf345c7f0ea8796daf350192591249925769268f4c61109277c1d5ebd78fb80f8091941122654748feabb9d3723e291798ae11515d5292dd77a6ba40f0c72fc4d2abe952e818a10ea3cca58838fae0e401e23a049ae35176aea8a5aa8a9a3928c45002b2bb3291af70554a36a0467d7b00d25aad74b69d37de68b2dc25b4d424f0534f4d20897e25633a496c3020315cedebd704117cc179bb5ceb62abba5c6a6b4cd02468f3e4931279102e7b0d2467d751ebc6178b754921c3a77a7cd692c2526d4d333daeb396296923b55253d4eb79d6b10b2cf50aeaa0215d5a7482848d80dc74392c1e09a3928c462e72a08014cb47fe523007ea19233f7c63a6ea66b2b27568e3d423247f0d32547cbefc1baabdde24a2a0b7d5c514505ba230224502c6597597cb9400bb02ddf3f724f1846306694a6dbebe7f3464b7066b59fc3c5b6d2a35f96f944d73b4c6b2d1c55709956a5f50db4e0e938ee707b8c7ea5866ba5f29e3aa98c11c15930f208e34508589c90aa0003ae0018db1818e3ce48e5382d3ce34b4bcd55d3f2dd3c94ab51502ae9d99b43aeb50a003d718dfa1f53e536eae79eb43848fc6a8491913ca1142676ce09fb67bf53c112bce49dc81e51b418bee7527e953b14f2f348d290f9aeda6b20b754d651d3d254888ac8c8ec4d4bb3b317392403d06defdb0033f2ff002cd1f2e5b2e495b435753729a1ff000869a60b1a3ab02c482a4b8d20f7ee401b820e4b6e90a40248bc7319034e9c8cf7dc6ff4efb71dd55d99ee5f07e254b98b63a879739f51d7603f6fa199c3a42b30b9f59efed44c33dc44893499f97b3d5462eeb2515249fc46984592536c900e3271b8191f31c717ee5eb2b57bc963ab79e83c4614d34c8164740461986491db1f7c0ce3871b8cf48f4c12e920102a93d7a9f6ef9f6e136beb223130a5455591b3841b2e76cee73923f6dfd78ad21dbafdb6f3e74f219cb2a59d7dea2b52a23969a2c98e7f885caee4e48c91b8c0006db60fbf1a2d7c1496e829244b853574d551195d61d4ad4eda880ae58633800e7f6c60944a668852c1514be799bf501b8cfea3ff00ed8d3fd0f7e1d6313bc19aba3929e5950322c9191e53b82063047a1dfb67d84e00909bfefbd6aae0405124558566460a06a8986413dbdb8257a8ecf0ce12d55d34d0b42859aa2211b072a0b0c64ec1b3bfcc6f8c9e60b0dce0e5ba4bc4d473253cb34912b38d8a85420fc89638f971e2dd25b6d05ca9d2281e2ae804137890ac8e14306f264120e71d37e9dc2913ca829414d998b6b6d6fcee2ab84089acd60a55a992ae",
            "9a0ab934339312b36588e8738fd43206e37c0ebc10f8935d04656275f09b4863b927fd581d371f2e18ad9f155b66a286a852fc0d143f0b4c60a71148cb92c59c800ead4c47af73b924c371b3555049154cf1cd1c4f1eb50ea558c6c46965c0dd723aefb67af141b74484aac6a596968f16c680c51acbe240818e515446e00d1d7391e8463eff003e2cd74ab67b532d465c80cc70bd700939fefb707edd356545aa2a114aaf454523d5e5205320d7a15b5cb8ce320019ee4039db01af656e51575345019014c84d59dcb60000f5c123e7dfbf1acea2488d3b15f29203798eb592d4545c6e7be0ba170ed1a21c06e9df7276f97179e2aaa6b644ee834f4649148d2b92727008c0fbf7e19529a869635fe1c463707427566dc8c6c7d571dfa1dbbf1f4b2c5210502095b01c38c2edee7af5fe5f3e38c61601515f888af39892b4ae08b549ca767b2732dfac16fa9816c719824a617089494a9aa51ad4b33b85182c80e37c11b0c8d2bf79bcd3d2dc1e129ae18c95f0a194157009048719073d46f8207d38b574bddda3e5d4e595ad99e9d257929e958e63895d41761bf53a7e9938ebc04ac92ef77b7dae0b9454f4f0dba94c3132d3a40c62d6cda9d800643963bee763dc9264add7b0e4b6d6faf21fdda41d2980d856b5b67e16f39fe1cd0fe0e738d2df4d4a4b2188cb6b7ab0ed52bad74bc7fc1c2e1b03fcc7d40f2e7165bd44d7a8ea29a0ab868d243a21967473a77c0c8451fd9e0d5cf912e96ba48cc16fac8e79a188ca93445534b80e993d89d3d3d8fa1e173f2fa8a39633554f248ee0e94d1a86719fe9fb1e1161a75870b99cf8883adb41dfea2be514afc35fffd9",
        }),
        Nebula = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc000110800c000c003012200021101031101ffc4001c0000020301010101000000000000000000050603040702010008ffc4003c100001040103030303020404050403010001020304110512213100064113225114617132810715239142a1b1c11624d1e1f0335282f143627292ffc4001b01000301010101010000000000000000000304050206010007ffc40031110001030204040406030101010000000001000203112104123141135161f0718191a10522b1c1d1e11432f1231533ffda000c03010002110311003f00cdb39162bb9671121b7a2ae382d1d2405a79d560ee93e2cefe3edd791e6486a6990ea921849d44951f6f9f3b91f63f1c7c599bdbd2a2cc8c1f7bfa0b14b710bb5156a45fb4917edbdb55126b6f353371588ddc727170db91231c094b6e29bf4dc21436240342803b8b1b1e381faa4af024356fb7a2ec8b2688e620835f7eaafb7dc319484250974978ea691690a7001bd004ee688a3cf1bf818fe5d51244a8660a63c4796b2d142d2efbac82aa29db9ba20d103cee795e49ec208ccc04a165a404ad2a48595a8d7e935a8904eab15f3bd574c5db981c1f70e39dcc478aac60c632a764b53965f139e2e042020252421212b4d6af21207f89467c982799720e9e55fdf826bff49ef686877cc3a6dee7e880e0dd91fca5c8ad35f42b04467d86d6aa5a4252a1afe3846ff61cf1d5dcbe3bb81dede7f3b8ac64b7e4e2e382f38c235861b0a0905437dbddf9e4f8b0f91bb6ddfe4b3336203a5b6d6db656da693a4851abfb681f8bea2520a62ada6ed0db802562f9008551f9dc035f6eba31876f08c4c77cc2d5e5a7bd3f2961857b9a466fcf458bff0038c965a3b1100710b4829514fb50b343f4ff00f12761e0f15d1486c2ca996a6bad08c83ed653ed51b3ed175677238f9e9b1ec7b6e05e45d69d91f48d85ea690096d04a4150ae06f5bf93e7cade5b2186467a23b8dd7063c8d0b2994b0e8d6940d4a0aa4d0246dc6ea15f013c431d0bbfea731b5f41b01efebaa9420cb42e76e9dbb4bb95cc47d62e031f54c8b2a6deb4fa613b127700115b1dbf7eb6a85fc68edf5ff0ea436712dbf2d2e263fd334b252e2941475582563f49fbefb6dd7e38c964321dc32d4217ad2186b60865bf72c0412a590059a0951e3648f1bf5262673a65a9b7a4b91d907d6052ee959200d22c000ed7b1fc6db8eb98c4b44f2066a01dbecb6660e01a6b4079eeb575f73b9dc8b7d2f3cdb486ca5011182962cae87b964dd73ceff22faa0f65e646c264f13343498cf3c87d65d693ea2148d4014ad4014deae36fb559d49b35cfe4bdc663a253914ca4fb8a57b6ad7c1b06fcee48f3f27a636fb62477ce471d876b270db564545c2b7a430da9a45ff892a5824f8d86e78eac328c88978fea3427be8892629e6b9ae46aa1c1becc895f51ac144759f4d46826d26d54a06ac6a41201ba29be6ba37dc2722f76dae645c3bf29843cdb02486cfa6dbaab2949e3900dfc58be45d5ef8edfcf7667782bb295dc911786139d7e2217916525af51556a415fb3f4a41b02b7ff00dcabf33bdcac76eb33f0eebc99d3233aa69e311d0b64b893415a81a50dd5f7a246dd310e3219b0aeb8693ea7b0b785c49730b4be9e3743b1f264c64ba875ad121a5a541b4236d609b0828d828009248e09eabf7fe6300c34de23013572a3b519971d2fb4965685945a9213eeb014aae7f363dc447fc4526748f426acc59cd288524ea010a078d1b6e08e0dd59fd92a74a33b2aa5cc7cd169282e28924d26b7f24df43c6e2e36e1dad89d5adbcbaf74d7c917e25d7ca75b2f0db6e38a53816b71a490a52c1dc804fe68ddf5ebfdc3937518b6b5331ff9637e9b0b6594b6b03595ea52922d46d5cf3e79b24c65312d2f07dbf91c3e0322cb0585b52a6b8bf51990fa576a28f6809012a4f922f6f0495b9909f8896cbed96ca8705247faf3ff0071d72d2540ab764a383b54f586fe22cb6bb864e5b3ecb19f5c96dd65f3396bf785a4a42e92b49245d84f1e056c438c8ee4c38c446576db2af59b614a9e853e1c4b8ea4a940b67483a48007eaf3c5824e167f4a481b0e413d5ec5a5c7a5a5868d074d381565253c9d86e76dfa621c6c8c7549f74ee1f16f6fc8375af4bef24c8891d85b0b613a75c94b6b2a6d48daaca791609a3e424fdc5b81eb4e8ed97f24a4871db0d150d4b48f752543c69d8d7fbf59d20497d87a1ca82fae72884a8a892742d3ad0bd213a8ed6abe2a8d6e3a66edfca3b8e8edc771a61b533ad05b59295ab8d8ec4021563cdfed7d5ec3fc48e7ab8d8faf254e3799ddff005d3d169cb8308e0d8988c935f52fbeb42a11b0e2129008593c51b3e7fdc00d021499b988b120c45bf21d746865292a515ee0503b01c9b3d11c1a31b92813254c9ed455461ac365240916a09094d03f377b7f606a27585b2ebab643b1a5467340a2414a936471fe2077f9bababaeadff358416b4e63d7bbd151fe13dcd0f0694aa52ccc890ccf65c8ca58083eaa421d201d3b107efe3f07cefd4cde417960d87521b5b5fd55ea6c6e3717641b00d8bb1c9dbaa4eb4fe624262e37192f20e834ca5964a8ab",
            "e763c71e79eb46ce763f71762763c79d2fb49998f64617a2f3a50e2dc80f7acb503b103f450dfe46c46a0539e786296ce0413a774d3c5466e21d98871b1f759a230ce65a4ad0a222865c0e29c6d5bd92360823834373c6c37e3a644774afb562bb8cc64a09139a4b3223800a5e46a07dc0fb77fee41fbf4bf33213e7cb18d4455b29484a929d14b2424eebf1c93f1febd51ee66f1eec4c6310a24c665b2c05e4d7216161d56a5695a4048d034e9b06cf1ceea5025c73638c8cb527722d6ef55b7421a4ba1bd355bb633f8bb2b1fd80f625dc7b0f15b886d9754c348484282cfb91a689149a2479dcf4aa899eb6b05b6dd79e06cfa696d2904700253ff8474a9db6dc4770cd255314f2123de522f7df4a4fe28ff61fb96067889909f8dc5ca931a2301f5c8432ad0da0ab46a3b0f248daf83f069fc247878d8e90d1a5f7f3efdd34c90c14900b1bf5eaad43ef55f6d42cce3da8bea3d918a969b2eea4216b4a92b053be958355ee0472288242b2ceeb9137b8732ee49f84d372ded4ebcd450129415286c102b6d293c6fbd9e8f64bb9f1f9cedf8b163c47d5906243aec898a72d871b294842129ad5abf55efe3cd8001c8899481905b79386a8c5df4def49fd49d4829f6a8a7920d13c9f3b0dfa993d272eaee75eebc82978996379f934457b4604ec776a64fb930d9a918fc9444a63fa315c710ebccbae685e83c10358db6a3eed8d5d7c5c5c4b391c43f0673928a10e7d62e4321b430e82e504924922b4ab510289f07da9d6ff00855dd7db303b4f3b8493dab15c94b8dad4b4a9d21e3eaa34a17fd42adbda41007e9fcd28e3fb67f994862062b0ad7d4c8592d448ab7005aacec14b51208d5775b024ee0753e08c8934a06ee77a7ed33061e4701265b0dd6719fc5b71b2d2e43adadc0fa54b4a9c3ed3b8ba20d8092a1b102f7e98e04970e71b298cea34a5458742c82a20ea3b006cec6f935d2f770bec4aef7fa679b53498ea31dd69c17fa09d42ab6b29adbc0f1d1cc73f056959725badbec29613fd3a1e9edb823720829dc793f2777a2963e2bcc5402bd2fcfea958e3065236aa09de91f2590ee6c9772bcf3af3afc85bca2a5fa846a25577fbf8e95d13de8a969c8b3571df41d69719514ad24569dc6e082363ff005e9d1fca63b1b10296e36e48a4da9b4d95104dd9adc8f75fe074a99d84b6262df4490f7d61d6371f3bfe68f9fcf52f17136305f11f11cabdd1292b034fc8a39191c9e7f3327293a42e56464ab5bf2241d7ad6a357f6e7e36036a1d48c6431f8ec3646248c2c4c84b9cd6844878ac2a21d69505b7446f49adef9f8b063c6a14dad018714b5ab4abd329d89e7e6f8ff5eac65a3befa52bf49285213e9a82d69349bb1a68dedbeffe83a9c056334d579c23933208c4c90c24361e5fa3765bd4749dc5edff00c53fff0091f03a6a978a0cab343b9d52f1939884891063261a74bc56a4e9055a8691a144dee763e53a4aac74b685a0c945214ad891f1cff991fdbabf1dd1909fe9c95a9d5ba94b6d2966c8d202500f3b5002be38ae851b49a36baac31c69955cc34bc6ce82d613b865aa0e358122432fc484db8fa9f2dfb10a512925254948dcf9f0374fb1a17a7194ed16893a750d82520695027f27e09dbefd030e275d04a55574349dc6fd394e8b818f9684bc1cb973319a1a75cf51b4b5fd5d00b8348590695b7236bdcd59d461bbdd170e09364c9dbfdcf918fdc513b8b23934659c54738c52f2494ba50d9694dd2355a6f4815e4926eecf573211612e334608436c4a65b6e98165640253bd9005a4006cf140ec0155ce6423e65f71e6b1cc618223a195c68eb52d048480a59d448f71009af9be495193b6a5ba72498c8654a6de3a5c5fa7760d03455ba47b549bf24f8e3a75a2a44606aaee1710c8ff00e4458efbf25a6767cec361e5b8c6723688e74257311a9c72200527d668248166801b7dfe526195dc8276464e4d5905641721cd7aded96a4dea1a803408146bc5fdba548592c5e2e7494e7e3c95477e3a444509050ca165414a2b4d1d4922c049bba2455d8ad92cc435c86dc48525b59400a51d25403846c91b5569f8dbf15d52c3b9ac7179361b6e997e332b486d8f7df5543b6a7072130ebe56eb7189d8d0282929aa3477f36686dd3bf77778e5bbc3098f54d9ca90d63db0d909500851f517615f7d2b48a238e9220bd1a7e421e0e4e4d8c3419522d454da8b314150e79550049fd5beda8d0b1f4c4647b73b7d98f323bad22712f447de6549449675293ea0ba2a1a902b50078b15cad84c447fd25d0037eb452a5765606935a7d531627b7e4c6c3c3ee27970d5096a7623652ea4bc95a002a2424eaaf7d6a238f35a6c8e431d0f27016890e90f36ddb7a4fe95571a79ab3f1b6e3f2918efe203b1304ee37e820ae515a1e46416dabd46f4857f4c0b237be401bfec431603b87179c5fa61bf4dc4ea0595ab65d9db4dd6aa00723c9e8cd9a3980881f5dfebd84fe02783298f776c7bd95bc620c46db84ed00a682dd0f0a26d36a1f7f049fc03bf50776f7148c86298c54392fcc66280da505c2a4fa45417a3ec9b093f6d2361a53d7b925bf0da2b2e16c26d2d25baf7a5366e80abe4d0175b9f9e96a1ce69bcab7ead8d6bd3a8920a81be6b73bffb7555bc3746c8cd8f3e493c64ae8cba1d8a84f6f67b1b8d6a7cc80f44c7cf74b6d493b365d00152763f71f9fd8f5cbf25319c42e4bc0809afe9ac59a143937b5015b503f1c90ccca71fcdb18f6ca9a663b96a5246a010a14b2941344d24791fa46e36ab0de0b0f93cf484c196a7b151a516597e42348713",
            "b5ad406a3c781f175e3a03202257450dc83415e9f85288b50221db59d51c2c82e475302929148012f22ef6550baaff004e7ae0c8fe611ddc93f1e4232edbccaa1b91e4a92c30d36a5129752536a59568238048047c28de2fb4b1f073d23b7a0cf667c65c82d2252dc0db4ed50041213436076bdc79b16ab2b24d2bb85ac734f352f52ddd494b81cf4e93694eae17e45591f7aa3d7b886b0b1825e9ea4fd28aab5f2089ad7bbc92f64b1a846656869a0e15a90b4b4d9291aaad5a00fbfdb6dc50e7a3781c73af265ca92db90d4960ad2561214b3a2b48252011b71cefcd8dd85ccd37221e2e3c0edc838c7223452fb81e52bea54493ea149d9245d6d5fa6b614053cb4f96e474b5223c886f3add94ba5282ea0d6fa7909d3668df360fc84450c4c32b2ba9b53debf4428a20642e79eb4e6ad60701874b11ddee19df4f867964485c66f5b8849d8aa8f8fcdfe0f4b91bb4210cbbeeaa61fe5c80b71121f504380003dcaa25283bdd955781760f4bd9a96e2d697d125d76384fa68f5751d1400e0ec37bdbff000dfc6359077b3a5655e80f48c74392db0f49422d00af7092bd80340f279201e7a913e21af70b688ad930f9f23d961a5fbd51aef9770adb719bc2478b8e536c36971986a5282e920170a947dd6773bf9f9b3d20bb2b52dc1a12ba585deb241ae76e689fbf5d2d08a71711c4d152908d4a4a5611b83a87dc7e7edd45f4c8767a5b5381942d453ab902bff06df8e909242f3614494efe23aac141c971294953ad3a98e12875257a45d1dc835fb8ff002ea1887fe6db1e91709341237249fb74c258892b14f38a92eb59169684c5683412d96295ad4a55fb5436e079f3e2865118785976c60e7c894c069a5979f6034a4bba0158012a3602ac03fdaf92324d73259eca10765d3cf6113864c510241ca36e39ae425f05b28f6e901206c410ab3646ff0071a4a85e398ed98d355958a66990b6958e4a5cd6c042534b24ec52a26b9b15b5d2a86e330394ce459f2e0639d92ce3da0fc95b085292d22c241557c58fc6f7c1ea7c5a304b8f917b26ec8faa84ca1c88c06b5b4fafd548521d56b052920ab715ced4682bd6bc8badb0b9b76a2d86c4643b99d5223b8c32fa5dd0c85adb6108557b828aa8f1405d9dbcf5ab77b7f0ae6f64f6b61b39172f024bb22314497d998d254565d5abd96afea240a1b735f6eb30c8b39dc8f78bb89c676bff002d93925a5f898c8a9594a42c6a4048559ae4dd8af77e91b0a59bee6cd498f060e465ca08c62171531a46b56950756a237e0d38456c450e991391420f8a39701948371aa372b213d9804cd2ccc2a21b096085151495116791bf904f93c741fbb20e3f10ec5433958d964c8610e85c14a90db45491691ad20da4d82286f574411d1d63b7a62bb260e792fc553535d71a65b725254b484a524eb403a827dc3ddb78f94936bb672f8ced6ee5673a9c546cf34842d1f4793683adadb521295213b73baacd791c8b0a3621ce7345ea9f746f9599ba6fdf75488e7713d27b7e3e25e658a88eade6de4349d7a95a7652eb511edd8135bfd854f0fbb654999858fdd92b2395c06397a043449d2b4345454b4a0907493a8eff00b02281155103ebdd4216584a09d1ac14a08205d6e7ee075525c7c3b1848de9cc90ee57ea1c4bccfa203496804e852561475124aac578fb0267fcc2ea4cb9c5092a3c6e35ccff0071c6c4e34b4c2a6be1a63eae4252946a3b0538686df342fc0deba804696e495426dafa87592e1218a72c245a8da6f52404937b8a04f1d72da580cbadb885178d04fc27e4ff00e7c9e8d42ee8cfc4918e4c2c8270ea8d15c8099515bf48965c2ad7ea29b4ea5feb3bee76b1bee7cca45d28a5c7cb7e53cd368592869069a3bea470a1f9ae76dff3d106dd6189c9fad50404ac96d1a693f6077ffebfcc079715ac27744b851b2f1b271e33aa437358d696de03852428022f8f8be091bf473231d9c943c6ce878b9b0e9b532ecb7095b521e0b24291494e9212a458fb8fc9bf8498f0c068ababa2de62eb9462761e0bd25f98e3a545d365af50ea234ee069e41a51dbceadfab18f89071cd98b11b5b88d25614a3675736680abe01fff005dba8b1b19d86db68536a5a5085289524ea7014802ced605defb581c1e99951594769359dc72f2e896dcd52653a8674b2d04a52a6ca5cd7a8134af8dc78db5744ca44ee23982a4f9df5f74f06b1c2a2c502cbb0b52de6de9e185b2aa710f24a4a14934a4e93c79bdbe7f6424b6b8b9253ff537242943d4000d448ae06ffe2dcf3bdedcf47731929b989a663cfbb939935eb2b76fd47093e6ff003b50dae85d11d438ac6c650cb0cd62e5bafa991f40b6d69692d3a1c07dc3492a15a801b5dfdc14c8c63f8ce6e465fa13dfdd2cf2e7baa8949cbff27c7478ec8fa85ad0141441355e36dc1badebcfe6e9e7bbaf219ed2fcf71d933d094c741920a941012026b6236091e6c9513bef7da3b6a1bb8a72649c835056875a6cc35a14a71d490a2557c50f4fc9b1676e351c931112430b4cc516c02bf7250a0b51012a0001b0dbf62363d2c30d8a9ea00b054b899c1bd396e940399dc63f0a5222c7764b2f21e6da5a039eea040520ede7e3cf8adaae5f0791c763e2392b251be9f26d89888f1df42a95a968f73483ec50a5502050240dc11d3466dc8d1834943ce97dd4d250955108d4400071fe2ff23f1d439fed0ca76f4681959f231451293a5b662e4197ddff00d242e96941278707c6ff00629266e2f0fc27510248d85d4ad52c0c7bf1a3a5e4290fa1492b210e027da93aaf7a0373f3c75f415c5619",
            "7262d0ec99045a5b4ad494277a37e5446a1b71bf9b34c09c1c88928e3722961456d36f6a4480e210d2d2142d4924056fc13777c8dfa1f331aca24adb8b222a59616868b8b72d2951035122b5205d036281daf8e93cb4b84c0848689182df741a428b687d4dea75b4bdee5d109b2490937b0bd1c13668f35b0f5c796b91e9b8dacb9a35d1dbdb577fdba6769dc9ca62476eb595762c290f21d911fde86d4e0d92a2951e28f9a276db61d33270b8bc16352844554b59095ae4b852022c1b08246e289ba201af35d7ac89d21b21b306f9aae268d1bfda8b3d8e99f031eb9a86d62348fe92a95417c9008f22d37f94f5c445ad8b0ec1f5428ab56e52abd3f7db61678f3d343b8b4cc79dc9c6528ae595fa200f682083bd0f6ee7c73bf17d49dbbda997cb770c1c6c2ff9b7a64a6994fa7fe30a5e925441a1b9abba03c8eb72c0e88d0a03612285ba0dedeaac47ed4cf3909bee08d3f1ea69b849c8a14724d21e6da43a1a42529d615ac6c027c0a03dd49e96e746f732ec869410fa12e24045578a1f2761fdc74c192c6e6bb533f92edcca470dcd8ab54778b6a4a9544fb771fe15248dfcddf20111a71a0cf6e73b65a48fe9b4b4824848db578bb22c6e6eef83d0c0a8b26d90891bf2dfeca94263e9e2b93f5cafa75a8e84b69494a15a013674d0e6b6038f35b569d2da6e1292845856ca2b5fa8ad5e37278db722ba64504203e9910db7fd5a5a6869485059d0a22e8d857049ff0043d2c48fa272432dc686d1d0b052b0a3ab9dc2a852bc571fbddf5eb85022cece1b0341534665c546fa86509f496a016e148a001b48e793bff6d856fd586da9105223b8ceb5a929584a9a3ef2774aab61c71bd9e45744d96e6c184f32ea0fa6e8f55b4b946ca812391cf046f6391bf5ab7f09dac2f7ef7ac18fdd59d6e5bada1b663992e385e742174842429bd3c0e6f736793d34622cf98da810c08da3e6750d0f3584e3a1479043d934a928292101b484a49166d436343edf3cf51cc661a9d4a23470db7a9412e13baaa85ef637f8fdc7c74e7fc46c261bb6fbb327030d9e83958eba082d85a8a370742c9404ded7f6e9670cce32328ffc40cb8fc60cb894351e4a10a0e55a0ee9374492473fe848d229c30df3dff4a6bd834087c9794e4441f499487083605edb83b558ff00b79e9e264bcb4ced8c76115264b38c88e1931db50510db874eb2137ece0803c51f9dc043c74344a6c6426256b7f4b6971649423c12ad3b848bfcfc03cf4f59ac68c56525c58b35a9a96ddd0dbec0568780dad20f8255b73b9f20efd16030dc40e3272f4fc57c6bd50c348d52edbb21251226b88580a6d0b6c504df2154a03e38bab1e6ac6cc94e4754a88cbb25c1ad2a75951a4387fc0a2351bad476236bf1bf4cf3a00998f1150b1117a46a529b157ed3c1201a1b7edcf4ab35818e7634469d6a4cb901412ebe920016458f826b817fe7d318e6ba36d69e7ed4a73ff168b4d68a419ecb3903138d444658831262a4b6f31193eb02a28d54aab50011c2afee3da2b4151c648c6af5b6dbee3a9d43d456c4ee0707617f15c1e92b110533fb89a6d3314bfa7a74369480949456ca04d56ff1f3fb684e29b9111210b47aea17a780b503e08fcfdcf58f86b5aca994ff006efcbb0aa616290b1f9457c527e610a72339151eaacfa2a21213652a00d6e77f1ff4dfa9b1b81655db70253b9b61721c2e20c664b887db1a504294680dc95707c03bef53cd8eefa08f5bd30b2bb4b68ab1c6c0aab5781c5fb80fbf50615b90263ed3d14fb576948d4412493493bd8b009e393d549226f1c39fa7b73a77f953434b9f402e509cd45620494175e920bcab4a920af427dbab651d2685d0d89b167cf5d64705daaeff00115787ed9c84d918e4af52173e388cf173482b6c8fb1bf0373c6c097a951994350720b36e2085b6e36742d0aada8d129b3fe75e7a1a984e64fb8ce5a629c95927e47a8ec852885288af71df63b78a1c0aabea7637e1e669b332997977ba6d98673246e6d2a2cac8ec8991fd46e138d8048d4a7900ea09b2900e9e3511b6dfa7623ccd92fe1a669ac5469823aa44090ea92db8a40645822c83c1237bd3e47d88e9dbead1ed6dc495129b340927efc71d5b919a913198d1654f71d622a4a1969c51a6d3c9a078dc8fd80f8da0bf0803b280bf47380c3b9a32e875bedd36d79ac1dbc3cd672524a5286a40293e9a76f4ca748f7268df1f7bbf04f559c4657bc3b9198d2b248c543f510da9d7db2861909145674dd8e7edf71d6b393edac5c99e8cc2da53afeca294ad28d691bf35b1ae15bfefd0fccb98b73b87544c4bb161a094a1a72bd52817480a29ad81526c055050bbabeb030c436a6c3c755cee2fe1ae6d612ea36bebcbceeb3b8d133b955bcdb519d96940d4a712541a5da81253a803476354391c6dd3a7f0d7bea4f63f78b1959d8f8c5a2e371de4bb09a4b8941281a92b08d41405d9bdec1bf1d14418ae77dca38a69f8589a2e464a9ed64a0293495293ed559b079340593b1e94a542c7c0eea99967a7b3223a5df49a6a82dd4ad22cfff00cd524d8e3ed46c7380f68cf74a9f8696c40d753435f0d7b29c721de394ef4ee773339e69b604f5fa7150ec46d2b6b422cb7abd30a59015637f29f9048197db699d9369ac5e2a444c6b6963d354a9b4750035aaf4ee144d0db6e76baea1edfce3d37ba3118fcce527b38462639216d454faa5952bf5108b20da7f354a201bdcc42c9ff309ab790b22238b536cbaaa4fad6a36bd209f93b056c2fefd2ec0da65e4aae0d9048d1138684d29cade3fab20994ed2c8e632d217",
            "15c6fd76e32dd43b22536db6a4360b845a8837b1201db63e06aeb334bcdb7ff2cfad677f7253ed3e090a155437dc107afd1f96563f358291dbf854a23c175c655216a2d3cf29d6d042f4b800283a94555fe9a88eb16eeeec8ca41cb217152d3a140a82d00ea5915e2b6dabedbf27a1cb1bbfb0091f8a606615c446db7aebdd1307724cc74820424076595ad3f50a49a5049229008a50af8b1f1cf563f8750323956a543c276b199362afeb91935a96db8d7a0dbab0da77091ad413e2f6decd14f11314c4a5e454a9901a563a3a9c94dbb2929a42941149d4ad4556b1c5935b6e402c9d8bdfddd1d9e8c82f153952f1ef36f2434a755a58568569357577b8579ae79e9dc4b9c5c5cd22bc921888e49c9700330e4b1092879e5be6487da961641695447b4806e878b35b7fa6e33eb2489095b8b74ad27d9a95b83e47efd39cfccc873b8254beea9990ccae5a5f50099d47d4293a1475056dab4d0adfef54561ac629c255a92a53613ae8dd28f1f63fb1f1e7a528e34ca6fbae7a463f3508baaec4a91f5f1dd0a58295a415025241be3fd3e7ad531b998d3663d2b2b8593f4cdb4e368434e25b57a9a76de95b0347ff00aa2938eed794ea9b980537ad2a4b605a8f3c03cfe9fdfc73b346650bc676fb91e59d4a58d2a7164a492a2693b1dbc6fe6befd5ff0084f1191c8e71a375f4f7089c29236e670a05f31a5d650eb6a52d08b4b7a052749b2135e2ab4dff00dfa58cd44623ce44e666a13e92890a74eb3bd5709366f5736680f83d4ad64568c7b8f12f36dad49d16eee36fb83b13b722b6e46dd567b15272eb0888d3afa934ad495ea05374091bd6c2b7b3743c1e858f9b8ed6960b8f1f5f64461ab320152983b59e8656a93945262a57fa56541095201515e9d557b81562fc6f5d6852a2a132572a1460965c20b6a41008a1eed3bd573ffd5823305d930dc47d44f9a988ec521a8d0d6a70a88215ee47140048dcd1db71b8b75fa361a849d20274528276a4efe00fedb75ee0c991cd64869d42ed30381923c33aad16f5d2faa4f73eafe9254c7b53b23d3d012da49e056c926ceff3bedd5d85dc18ecfbe65bb8c85868ada5b65286dfd9cd28a2a5051275122cf8dfe4126dcd5e83685294a5137a05d0fdbaaee62c49525e5c769a92d24165f710145246e6be2bf6e7aea258e8d0e6ba8056dceaa3471bc622a0124242ee0cf2a597da65d695aad3f4e9428234f009fbf1c9e7fb746fb5b3fdb71fb7e1c2690f2b2c953bf532132ed0b6bd9a348d228a771b9fdc8fd3de37b2b29928f3b373f0ceaf1edffcbba5a41a68a413ab52773b6b24fdc5f83d077bb1b1ca8f21c81254ea8852d0c9480a5aabda9d476a147e3fd7ae7e6fe507711a6b4b75f7e7d84ac0c94cbc60057969ecb4180a8f2cb0944c5242d2a71095bb4e2cd803926c593fe55b744a4c6389831a5cb75e671ea7cb71d65c0d216401a91ab49df9006e4eff0006b0292c64fb667ba4cd61c5a521b284bfea2824568200e281dafc03fb6a723b5bb9f22a870bb9a6af1115861a9ea8f22d064a965341b1a79d1b9d5e411428d4d9317212465a3974584f88e706211fce36f6f2fb2659d97c5e4a54e5639a5458a12a71a57aa973db6456a4f279e01fc9f2a92b30a98d21a8729653452da53ee505594deded555f1f8f9eaf4aede653daf3b1d8a75c71721a53761014b4a08249247ea09015f602fa4dedfcdc8c73231d906836b4da56952ed2851a524f341247076aaabe6bd7e35e2310bb4e698c456399ad94d2a2e75bfe7aa640e45c763911e7bee264b6154b0a2492492149005124d0daf7af3d0dfaa8989654cc7c4b124ba96fdc57eaa5544d7eab0362413c5926f7ea76b2c2141cdb8d3f01b6a6c7f4a587996dff0045416950d255ba2d49ab4dd6fe52080fdf3de2de4b218ac176fbcec98b8d862382ee2d11de2f28ff00510a4036b214542cff00991ad53df2d0a4b138c10815a0a69a134d37fd220bcf61d942a3cded365c2149714b3a01559bd476df8ba200aeb87bbd204cc0ce86ee3a3fd6487db7d3296b5afd0d0149284d9d3bead4546fcdf09d2a4a6a4379d908ef08f2e098a54d38a4c416877428b283ba529d452aa37b8493c0be96dd9af12894d2de6508207b15e79e46fbefd09d3542932fc59e6db78007ce94faad53199b78c388a5a96fc7483ada6da2ddedbaac7817cf07ed46b4ac6370b27da5939128a644d8880e2dd9121a650db295695a74288d56a29360f03e400afcf5072aa1938cac7ca2c20b8a525add21249357f29f077343ad8f06b8fdc9da2fbad629ff00af87ad73a4a1c3e9a5a2469d29480534413cdee4df34d619d99c1a4ab383c799632c06f6a72b537af976501cb424ca7139288c69c8a5b01c657beaf0058af76c28fcd6db0ead47818d620231eee31ec7cb6e1a5c985f9017eb0f5146db013ec076079aaa3e546312158f2c3eb787d438b56921a0e5234d25438a37f37cf3f282bcc65f279269d77d630195d36b964952ff00c412546ac6dfb73b746c547c3929a9427e2a18c895cdf98edb69a9efeaa7878f8ea908d6d875f92bf686927d52a51ad2058a26f8b37668ed7d14c2f6faa3f7eff26ce0978e891e52599c94472a5c746a376935b907f551d8dd50dc7bf0244bee38f2720dbcee35c2da54e29447a5a813455b511a146b7a16793d396733af7f3b4e3a3417417d612e17c68512aad249e4da483648b041df9e850b32bea4d003e6a7086391a5cf39403e64fe3d54632986c634f25335c92f36e943368d25277dd49dc0add5f1b6d7e53bba207721ca16f2b1e4c76de089",
            "0d37213a0e8235215e46e081c13637ea330e6bab69c763ad0180521a235158052458ae765126af8e4f4758cbf6ec990a6b291e64d0e452d23d07834a6d496ffa67dc834900a455550d81a20bd9b3c649b0faa57132be60237d80d0734985c92f34cb1a52eb7ac12db6e00a5d2ac0ba22ff006f8dafad5f13070ec37f5d85c5bf123a5c5869b90f02e168a81f7ec37a16051d86e6e8f49788812666519690b432ed29c2b229c5a41e46db5d8dff00e9d31f71472853105442b5a14f2b6a36004d0550162cfde87df6670d18c8e9c935d057bb2fb0719849908a8d3fc5a43a21c6721a19971a497d92ea8a2c18ea4a88295d81b902f627fb51306632d840b6d38c6d65b5a124216e072d7c2d4280bb56aa007fb00a30991356dbb15d488ca47a4b682940ea26ad3b71e39f047cf459b88b8918fd2b6ea94eac0a65929013601b3cf17e7cf9ab0bb8be37673aeabbb86674d1db4bfa785abc82f5b8b364a3d52dab4b8410a528829df7dab6fdbcfdbaf3d37dc4fd33cf6b01c3ba7da941e2b83477e3cdf4df8c6e2b93232726f3ac465280796da429494f9a17ff009f7e3a8276395130e329eb34b69c716d215a921d3a68ee804948f77fe6d6fc53b9e5ac26fb2ccd848a1a9276bd743adbc529c69b93eda754b87907e0adc6d417f4ee105d4e9208a15628aa89aae47cf536330e81528a57a94bd4359ab49ff0d791477bbb3bf22c491158ff00f9c952b2f0db7c35690ea4a96f1d491a1005d5037b9a3cec0120bb72613be9292e0e02aaeb4fc58fdfa62495c49ca3e6163df7453f0584c3990b9c452d40562f93c3b93ff8912c061288cd28ba90a404eb4d6c455a6ac0a3cd017bedd3ac1c96430f8c910e3e5ffa12184b4e2e64712141b0410942ab52400802c1149d0057b4f4f8a878d8d2e5b5323bee9430eb486d977d2a728e85707850078fefc759dbf809d2a4a9865a58569a00d2502cd12a3449fd20ed7f079eb9b92231db9dd6bff3c40f73d8dcc5c6b5f1bd2c6b6573b7bbbf318fcdbab339301b5eb8a85b2485a8afda1375b822ff00703c8e91bbc64072e3975c2e5905691a92028d8d44f9bd344572a3e7a68c86366e2f211a3bab4969d1bad9dd6a58208f69277df579dbc75ef71f6e64313db10bb972212b6f2ca7125a505b4efa49a095ab5229493ee03ec0285ea23a59f5a50a5f199cc662935dcefa576e5f9590e51f8f072606072b35f67d36965d707a6a0ed254aad2a3c2c6c6fc79ab30bd949995cdc8cb669e7673f2165c90f3a4952d44727fe9b7c0adba606c3582547cc63186e4498b212f24bedfa8d05780a4a85720f20783608140643e87d84292a6d976d4b25168bb2760900240dcf8e36f1ba25b4375c43e2746ef98f54e18befcca6258991a3e73d4c664dd7132a3b8ca650515a1692e96ddab504afe459e49e95a6bd058ee395130f264cfc5a1e526339218d2e2d209292500d03cff007baf021f4a336d3ecc971487c1d052a494a92bbdf50abf0457532f032d986db8eadb0920a92a0a26c7fedfcec781f366aebdf98dc2db83e4399a3c688a48c3bcbc732ec769511f61b529412028396b00d56db037bd71c6e093fda1316a9d0f1cfadf2fc8414916024a756ab15c8b48a1f2011d2e63242045311c716598fa88692144bfed268efb0dcf8bdcfec63b51b96d644641e616ca40f48177d85c51013a52a34428004d8e3aa9848b3c8d2ddfec9d8a56b256b9a35a555892c659a632929d0a8911892db452b7c25d3ad2a5a29b242940a770a1c85ddf35126662198a98504af212024247b522ec5d59ab162eacedf61d0887def9c1dc18eee3cb4cfe6d3b1be998a6753a025a1496c855da76fef647b8df56a1f7062fd20cc9c7b51838e296bfa3d2d2b71e08b4f27e361c000574a36639b3557b04ed78a3881e3f4e48ec4eebf4f12fe1a4093160bd21a90e4369cd2db8e26c25640fd557ca6c9a068e915a4ff0f5ec1775ff001170f90fe2065f2122415b2d456a53414d929212da0acaec0d81363752893b9eb08cfe470eef784b7f1d1a545c6974a5965f735ad86f62917438f822f6ab3cf4c18332e5ca8929b9880a694975b74a88b237091c5106ff0037f3b0f0bcbea2b7468a433d621af4a57c53b774abb5b0f99c943edb9eecb652e294d3cf466d454aa01490e7aa6c6e37ae36fc222e53b8f98c644454969484a9d46a0de83b00e0144d501b7db8e6ee47c564b232918987156ec971d4b286d9b2ead479162c6fc93c00937e075c7f27c9c3852634f4086632cbde8956a5a4a6b56b142850dc5f5730ce7c90f0ef640c487b6414d42925e4a2fd7ac4798c8fff0020d2415bab2012490689d45542ec73e6c4ef8c93688ce3ccfaf1238bf58201202c92a5129e689237d858f9e92df6bd190976620a12f28adb4b67c9377b5ed479d8fc71d3ef6fe6b2b0bb62743727c81125b85a71d6dddc213fd44a5439aa07717b1ada883e42e1256270a1dbf6bc64cf91ee7134447b5e74d532ee3a427d65a1ef5187d6020a82d24d0401b56951fc7803ad1e27ae86d2878552473c93fedd673806e4cecce36630d5c76084baf929714014d27616792413bec6ec51bd5fd064621e9ca9ccb6eb4ea10232828adc4906d436aa15f3fed666975a2d796bbaee3e10e0d80caf275a788dbf15e9aa8a0b719ec8b49c8beb6a1ad69d6a6d3a8a45ee40daff00f363d5291114b7dd0890b530ad90de90823cdec793e46e3fde9aa4494bb5ab70686d668f56d1291a514bf7aebdaba491f26bfdba3491bb08f04dd538e58f1608b8e9dff8971fc7a60a653eff00a715807552",
            "d4afeaab72770a06fedc0ad87567b3327db29ef789fccb1f2dc8481a94b6dc494ebf17ec51d3fb83f3d51ee79ed16cc3f4d6f92a04058213b82681f35f238e2eafa0f848d9190eade0f3223e9282d2749d009048dffc46aab48d8dd8d34653e5739e4b77e4a562238cbc61d82c396bebb2d8bbeb31db990efa991b1115f0b6dc25c7d0e84a1c58510a0068bf04f3c574aef05b8ffa813ee6944b49045a94011b929f6f91b7c9f9e84a1d93064bcbc92404beb538e38d8568412411b11bff00dc0e89f74ae162b09065232ed29c9090a296f50f455ab8558e6937b78bfb1eb513008b5d3bd53f0bdb858444f26dcf5eff00c42fba3152da4e2f30a7e296dc0651692e05a94104a7f403615ed3b1f26b623650cc49566133b291e0c89cd4360ad6e29b53c988da89bbbb09a5289038049adad41ae56686733297bb8f16979bfa511c7d3adb8e8712901285fe9f724a8249f6fdc6c28c783edf449c4641a1897950da091212da9443685116a56e0801401def8d543c2e585fa1175326e24e4b45056f7aebb77cd649fcc1131d5b8cc74b4ebe74391d1fa54a22b527c69d8120926faac88f18e45c7e5487e32db1ea365b212a4397b11b8dac78f3f1d69194fe1c45731096b1882cbf151bbab2482000013f1ef20dfdcfcf48abc54fc36144a54a8ce36a74a64465292e0f16b49bdff50e0d716791d05f0f0dd493d97358ac26263ffeada8d7a7db9ae32b8b999dcf489d3e416e63a7d474396e15a8a6ff0057c7e90459f35400eac2dbfa1690c3ff004ce450b24850b3c01405d8340fd8fdeafab1849d09612dbf0525c2ea23a62a14a206ab04904929a209d8d1f3c592b2fbdb008ed518f1dbb124c94be95fd5ab5256c2424a7422bdbeedacd550e09ad343858611712b73e3efe1d3d120d0d655d5a552c47962338cc2127d36e4b881a14d280581edb2be49bfb57154360d50649990a51c74670b18c684b75c482a0db45564a8efa49d5b93b6e6a80d91e4661bcb478ad4f0cbc58d4edad451a8d81a49bba23900834363b745b299289371f9898e76f4889929b27d465702414468ed052b5b6b4949b3a824fea03649daa9598b166169e18afae9cbd5038a6bf29a84a997ca4e99171b8f9488a96f1cc7a0cfa0ca10a292a2bf7a920151b51dcffb926ce1bb7dc978b959fc9313d9c1462a6173a347f5529905054db6ab200b2059fb8e2c1ea773b7b288c52335260c8111f796d21f71bd4dad6900ac0236047f6e4783d4031cfa5a5e3da7d21a74a5d55afdb60109b3557ee205f0491e7a8658754af05ce36439319d769c4b6a52542c94827c8fcf9dbf71d5fc44ecbc19a1a8edb8495a4ada29035ef639fc9ebe5bd2222da8e953a9710a29482e5fed407e36fc7c9e8a63d591cee46163711156f65e5381a0400ad64d01446ff1bedfa6c9e7ad002bad11e3018eccd71042b68ee7950e4c792dcb400ca83a7d257b8a8806b55ded668fc8dfa97fe254c79ae3aca16ea500290b5b7ad3a810356957b48db820dfdf7e94f2265313551e5028971dc536b469a2857052761bded5f6e9823ab0ff00f09e2be8e6ca5e604971336329a4a596dab496dc4ac2895289246e36ae055adec3e3248fe4695a7cce95c412991ad1def33339fc96421439807ae863e9d48f5ca96014202052542c9b247144fea501b3fb732588c8e362671a7a144ca69763bc840a931c2b4828d4a015c935aac829ba06fa6accc2eddec9caa710e661e92977191f23add4b7a497594ae91e92d40f3b03577b150a515cc26025773e699c53121c61e6633cf467272d2c250846a74a5054a237b276377bdf27a6c00f607823afe115cd6e5665b93dfbad3b130b0d043f0f0935d91190b521a7de47a6eba84abda5490a3468fdbe68700c47775af4ad692502893b151ffcbe9470cee4dc8aebafb6c890d20053896f48746a3efbb163f61b857c8ea791dc38dc73e86a73edadd5a42adb2549e7757e00dfefd75313a010020d07bf9ae9a0c43a00dcc28073b028e649f4b31de7c15070a35a4a6b55022eafec7cf51359286e619c5484c86726979296184b216db88df5294a49db7adabfbef4b93bbaf14dbb0d972490f286e43654143835a45559dff2478ebb893214f92e3516421e4b6b00e936951a079aa3c81f8a37d640c3caec85f71a0b2f26c7499eb09d695e7cd323f29993d9d2623d2e0365f9acff00cb38c853e7485a7d442f49d2906ec5fcf1642ab4d90f42970835102a9d2da4a1e2907524528802a8fdee8f177d52431899531d90724c639b69a2b4c8792a536b5200d09b17fe2db8e7fb1b38e9335d909792e2d4d38e96cb4a47b4007650340d9abdfc9fc54e3846025a0d4f4faa760c51323b6248bd8e9e8abe6deee0959c8f929c2396db436da931db4a10ad084a75a903482a201f0781b802ba3137b77259c547438d2233125871e65521d4b41d6900a8a90555eef6ec0d8e09db7ea3cd6459871d0e351c3f25bfd0d9df49e2cd6e363c81d6799eee9cd211a1e65cf51254d1d2bd9b165549db61cd6fe49e85c36e1e3caed7a8aa1e3678f0e5ec6baad3b6bddf657b35fcb71b1587623898cb6814042410a68920159376a3f7bdaff7e81627b8fb9321907224398f2a28d96960042dc17a80511b9b29049dc0bf1c95c79d9b2e6351a64c75e692e00b2bf714a3e52926c9dcfc7df9b1b1bbdbd88edbcf2dbedbca27358e7db43ac3ed15b2a420e93452456aba49bffdbe0da5321e1d24803410029d86c43b173d184b46a40afdbcbbd2091dc797eddc2bf2e4644a7ea9bd12a3b29d295d6fa542cd7b878346c8",
            "f3d65792cce36462e3cb8921e19a7252c3b10b43d165814a6c257aad564aac691e78006ad05ec4e2b271de8f9f972988eb69c536b612972de4a096c7eb1ed5288b56e3dd563f504a6bf879959b8f54ac5b0322f30d953d1909248d35a8a6b62003f6dc50be89898e570ab6e00a9ef74b7c49d3be4c918200bfed0a7f233353b2632594ad68ad61408d4a14b200fd2a3b9f9dff007e97d71e4348d4a73d6459b1ba93ab7f3f7a07ae5f8aeb0eb7ff00a9a962d041bbfc573bdf445b8f2a3b83d35b8e2549d24a4f1e549bfc57dbfb753038bac740a13f34ae3985d16eed6e72327191946f1a999f431560e35c64b7a7d2494586881af4d5df9aadabaac33c531d719e47a885a4ec4d0df6babf71a37763e36f3ee3178cff00885a953e348958f539a96c46a4bab4820a882761b1f8e003b722aca5c6909714db4a8eeb0b343f595275105362b71c71bedc7442f70165a8c399520ad3ff008afd87dcacff001a67424ae364bf9a4f75f8f1203eca156b591ffa49512855245922f6b37b9397bf3de8d935b680fc57eca1f0bf6949077bd8d1db7d8f4e329fc9bfdeb92c9cbc82e54d7dc5c844942ca9e45acabdbb8dc5dede479beadb3d8d124c47a5267456de88c21e4b2b6d485bcb2a03d24e91b1f71dcd1d86dc948c44f0d4f43829cb6ad37dd668fc8912e5ac480a01d50011c559fc73f9e8fe2f1ca898246465c1c8221c97ca61cd66ebd76e8d366bf552b9b1646c763d5a11fb631d9f86e66d9fa884dc808971a33852bd1b5a7514900f23ff0089dc5857412687d520b6ceb101b5ade6595af514f8209adce9001550ba1c6c3a1508374b163a1792ea38faeab87a1e223ad0e21cfaa4e8d65a4a8fb81baf701b11b5f1c79dfaa2d3afc35bac360842d242ca06a56906ff00d6b7e883085179b6d2d38a1a920fa63de917b81637db7b3e537d145e362ff3b6a3c6961c121a537ef7028b6b4916469e2d29fc6e47d811ac27fad963845e333053f68cae3cace6463ae7bf273125a433192eba755240d2012af8f6f1f3e6f777c6bef45c64aedb4a1af457290e38a1190a7da012a034920148dd5401162b71a8dc5db4eab1919299b89610f386d2a451712ad346ef7a21248abf3cf3d3bc1978ac8b5018c8c03fcb9a7ccb717169a75fb00105c0352ac2457cfcec2ba6860310ab697db7f4d75a5174787c131d18737fb6e34f7e7e2917225e47733cd609d7e4c08ebf4da90eb650520fe952f6d292403b58d5bec08ae844cc04ac8bf2b2acb2fca6221315c536c171b43ab0a2848555157dbc58a37a475f663bc5cc761e576fe08ca4427a59f59b75415ead15682a354aa1bdd0ba4f8e05e30e6f1b2e0e7e2ce762bcdacc8674deee20109f9b0904feaaa0481c9e937e3408f86eb9aeea7e2dc3351a7373e4a39f85938eee0c2e3a5cc87117f4c9752a44c484a14e24a9275dfb6ac1dc8009e40dfab79888ce07be9eed233e1e2bfaff0049267058759689241505201a1eee3c56fa6b62fdd9db0f452c3a8cb37949a969a9065a35afd452c6b536a2b00aa8957e7f3b04aca769e5573e4a9f696af7a8faacfb82afdc7f3b5f9bbe7ee1cf72d86e7df448bc4cd6d9aa9c6ff8867c79821fab371b8d21e92eb4957a696b5682a3607b4eaf22eac9a17d6a1dad939f3f0d2e7c94222222b41ffeaba9414ff5341484ab4959b3c0e38e54907295619e4b41a6e6250568d0ea5009b1a813ae8514ea09f245d71d1fc265dc7622623d292cae324a8a9f5936a4dec0ef46c5fe0fedd670af9639412695e7747c14cf85e438edeeb5dc467d98b28ad1f4cb71c6969f55e652e213ac14dd281009b557ee08e415acf62a14c326319ceb250e2424a94123557dfc59af1c6dc5296b1dfcc44495dc4d4772762b1aa4a1c790d28b45c51b4b6a0a15e3e2b74decaa24bb9b2b3b3e5ecaa9488ef648b4a5a1b3e9b7642147648f6d92361b9b1c9dc52c4932125a41a77e8ac458f8e585dc465fbeea939b7a4439e969c91a4455d94a504102fee28583b58e00fc74e58ecfc46304af5dd4b2961c05214f290120a494de93c155ec2f63d79dbad76fe4b1b998f9857d3e49b4a5c8ca8ad0703cb2b48095ad4bb4ec177f228ee451a63b3b37dcea7b1bdb896e4ad14e2e3975bd4a597129fe9851d4a3ee248be06e781d78c9a66446a2a3afefc94860fe313346e5de573edb6f391dd4afeadc25b6d440206a09f8346856f5f00fcf56b1136261e224bc86cb1b8714176900836749f17a86e783c6fd676b8b2985389c80589117fa1e92e92a4900829a276fc1a3b50dfa78c420284385e920482d079d8ce8a514293eda040246956ab1b6d57b8afa379924341424587e7bbad61b16f91f99c6e39dd0e8b8d662442eb4b8ea438a500e36900b6aaa2091bd11b5edcdf8ea0d5161c188e4872385b9a82586c58555ee413b0fbfe3e762b0f0c9632aa31e5ae2e21f712896a641756ca751d2e00ad35a7ee48df7bead633b671a9c0bd264254f4978ba1b75e4538bd24ef564836951a24ff974184bf31616816df4fdf24538573e8221a5fa7925cb8f3202530b14d223ad75e9adcf516adf722c8e2ab751e2faebb1fb3b2f9eeeb66347978e65e5286b54998c6949041ad2b552ef6b1b8de88f1d53c74d8f15b29fa8d0a71d51f5161c236b0361b79241a3b9df6eac3911c465db4420586c250a614cac8d4287bb50e47249ff00bf535f595a08d4255f1e701edd7a7e933b1396ea04b754353beff41452da4294450480425293abc578a1e3a13dc53a42551612643612fa815340a6eeee88b1b5802afe3727abb8fede13",
            "1997132abc8c147a1af1ca2c25d696e057b8384d7a602356ff008ded2124fb1db98dc6898f4d4fd7cb94da4953bee5ad03948094a40162efcd0fb1ebdf99e68e5d1b229a788b18328dc9b7eeff00748af76fc24c6449c84c5a9b2af78291eedc7e9f09e68d5d79aaea77a0e1a234cc97196c15214a41439a414a79fd40dd950ad87e93fa48a24bb8e3bb12345fa4712d47fa86d0404a4369166c7b814d0213cf201f1d49907e5e532af4691010a9b3359436cc54a54a5bc91ee4a40a4dea4ec39b1b9249248e305c5ad6dd4d9a36c2f2dca3417eaa3647ad8b7e5294998194bc53ba8eba3b11e08b209e7707e3a528521b4e7dac82d0c3214ba346900105236f1b83f3f9e98179f38d8f12335050a2da8215a541b04595822b8def917f7dcf45b1b8ec7f7049567244d8ff0054cbadb28c798cafeb6ab2e3c9bbd855d9ff00a6af25aca5ac60b8faaf8b5b216e575c11dd7a2b39b8736584ab5b8bd442d2da8e940b147635b83f906bc6e08e5675c7231c7bd1dd7a2ada417ccb7424fb774ec9248e01e6f7fc0e9d1925b7fd003d77df580cb4816bdc555049bdff003fedd0ec8c0c9635f978fc92178e9b196124c96d5e936469255b5aac5dda410a02bddc0316499ae6eace223632ae63a95ad77d12a649d97dc19a665e4214754844565a4b6d3496804211a771b1355b926f63c0aad3b13db28c9c284cc89703141e4a195bcbfea29a2484de909344eafd893bfbac25a3b3b3d066e4332c4d83918ee4c7a335223bf65e0de9b21bbd601b147cfcd104b0c06b292724c440653c1b6be9dba49d295114401b8360a46c6fe0f484d0bdf59221d28b9ec3d2aead6fa2a309a38632e3e6f210cb2ab2d1285ad45295104a7f494f209040f1c52baf5e9fd9efe214ec8ca4b395d6d08ec4660869c4292a4aca97aac693440e6b4feabf6decff006b496b34e629c43af4b657e9ada7da217a89adb7217e38e6f6e93f3e728d77144eddcde2996978647d37a0a643457ef5286a581fd42351367903e4d97f09338cad89aca0f1af2dc7d82ccf3cb1b0336433b85a6f532fe2c179f718295b6b51b292285f927c51f8af1b29e390a8aeb729bf590b55216b028a2ec6ff006a17fdbe7ad2f270a0e2bf87ce7713e02e53f38c788f092d12cb4848d69533a757bb5228edc03b0fd742122165e0b6ea820ca7517a94ad3ead58268d5d0adb7e7f3d589f0d1cd291190d2ddad4e551e6a5b41964a9d5085488539b5458e03adbcbd0f94da0b8b483440e2fdc45f22cf855f4c4cce6be85c88f3a7521b086da7b84d0342c1fdbc135f73d470b0b898998fa3cdc7971b1cf7a8f36b88c25e57ae9428a1b55ac7b55a46fcf22c7223ee1ccb387c3b9dbcc65713271f925c594ff00d3c72e3ada837ee405ad1a93a4af8f35b55a93d4e771609331343bec3bdfcd5664a2363b38ba28ac2cec6c3fa4ccb0a8b2d6dfae864a06ed2ed49709af3766afe3f56dd5e9984c71c789cd66ff00964fc6adb5a22a42d2fb9b5faa15a6884e9039dac71ed0a44c3e5a1cb8d3344bc83725b79a6586acadb0c141412a5157b6b4a004d5014371745d9ee277199afa87319072901711e8cdb52ef46b57053a4820a7daadf63a76a34a0ec1886866775c741adfaec86e9e3920cb9790af8257998c72385b894fa6503d9e9a8aa81fd3b8d8ee280fb7efd1b44ecff70671533299379e9ed302387544aca9a40d3e9a6cff00edbdb92493f3d126fb73b8e776bab3d2a0ca730e24a9a331014a683b7c10689dcd7c0558bbbea48b191090a426f5e9dd6ae4007e3f6ffa74c33e1ed9ddc48f4f1df9594f85c18f1c949db4ec9621e4df95212f3afba8692a71cb37aa805724036917e36f8eaaf77392e7cc181869f546953ce38d27516915a94481e2b724ed5a89fb3d76be152d7694b99227c74be648288feed6a4aacea49e07036bdbf3c8b8ed41c3778cccb4ac9e47100c17db549809d6eacad252805208d947624edb8dd35a92ac9f2c5c203c6baf35d2cd0cbfc30e0eb7dae4f8a5dc6e320c252dd771cc4d47d329a6d990a3a774a87a9a505344155816783e40209f6ccbc563e5b39591256dccc6a50f6353f4a992d4870285a576764e9dee851dc6e12154a03d2d25501db7108424fb45046e45ea27715fe9638e83bcc446208c82a64e70fabe9202da2a5bce6e41a34471bdd9a0473b748e220119219a21b0b0b03c37c7c96b1df8f61f159d811b1cd4f8e66b7f52634e686a649512829344a86922c50af9bb015f20fa5f0eb51da4a1453a5c208097143822858177bfc57e0adf72c69b23b82121a74fa6fb64327d4fd00248d2092455246c3c50aeaf6362ca96b4296af6b09074ad469c5820a49d26c1a0363c579e7ac0f95ce6ea01d553662267930bab5d3dbbf24b13b333be9ce35d1afd35a54a51aa282abd20fc0140df35d1589dd19e73baf1f9c19970652369f45fd651e9694d253a882680db7bbb5137a8921e461f34ebaf3c1b0d156a1405274d580024555fc0e46fcf5a3765b18187dabeb4b8f1a74b7195a599da94853252bb2b4ee3dc38b50f03e2ba031ce7484152e1c2cd897e53b0df903fb42ddc731254dc7c8ad48c834f2fd45ba145497028124eae2d55bd9d5f1cd0b7a6ab0fa99892bd392f3846bd40ed6459db83c7c6db79eae4613fbc25e67b8316a933170fdd3e5b8c92128354a24ddefed22c1a076006e2e6469464a188ad3023c666cbabb001dc5ff6d37b1f1f146fe0e0058651424dbbfca4f178b26d10a5371ba3b6b4b915d7e4152d614ad0aad2e0354a550e01276fbf07a331b009cf60e62fea",
            "db91937e5870ce51d2b6801653b1adfd4249df7e7ec991f0af88dff32efd0c102dd29345692900015b81f6f9a146f63ebcd42c7c24a714f3ab6dd48510ceaff10277551e557b7d883b71b9b0972e90e5dc57b1dfaadb31ac7332cadb78dd6a51f02e64030d65bd37f291a3a10a4456528410848a514a40d43481bd0f374360e18dc33aee0e576eb18f6a6a5f5079c3e8852945166af9157fec392085ec19d31864484bae32eba816e253e9a8a4a48a247eaf91f7dc6fbf4eb1a334cc67a5b2853690a0953809f76a0abff21bfe7a8f887168319a6d43d53f46d9c1a0694afdd671dced3d0f12e7a51d925c52ff00aceb8507d457c9a279dff61c6dd63b2db8f232d902a4bae99292e97d6e9754adf93b50bbe76af9eb79ef29b8d18292993fd629040405049dfdb609d873f7eb248b8ec766307232832b162bca5371da84b6c34a7b58249bfd2102c59558df73c59300782e2f76bf9b725f63a36ca5b9ec526ccc5c35e3c4d796b282a59425d49d3ac0a4d0b1e01f27e76eaf6071711fc896e425cfa8695a12128282127dc9f76f5c71744115c9e8f643172204d9781921b0fbcf7d349723ad2eb692469250458f1f623e2efa873b171f8ec932fe361c68d19b6d0dc869a717ee286d36bf72ff0051290ada87e4924f93c8f91fc46b6c8b87c1c71524a022d5fd7d7a75555e519399c6242658f45c09b2b4948494f8013eed881c93bf37bf42fbcbb7a33319c9d2320892e07340b16a0bb0749a3b7b751f1c0a1bedd62239ee2930713010a464cb85b60b2da565449b20848db637cf8b2455f40f2cfe7fb65ecc6216186d89a04670ae08fe904efec0abd249f20ed7f6d812621c5841156fd10312f88c44b9b989deba5b716f74070b09a54c96b79ed0da0948457ea1677049aab4f9076d5e47457238a190891a546c92029b75c67f97fa4bf5d8427490a5129d22f59028f8a17bd50c7c86a6c86017d5161a144a02a934a16a049d8026cee0ff0084ede436e132986cbb4df6540c4c1448c9cd6f46424bea47a55a868fd41212a246ff006e09d3a75860ce180e3f293ebfa0b9c786960683fb56664ac645c261fb5bb563665f77d66a44b766db4dad6a4b6925284936b0a5148364f81abaaf96c9ff00c3d939f869b05f331a7bd35b247f50ac5248200afbdf1b8ae7ae7b8622e07a98c0d27d40ed3c86c001b50242b7163f55827ff08b460f2afe69129994b9deaa92fb85d552904a8294ab37eed4923824f57c492c148f0e6be869e1cfbd961d1bc1a5133c2cae4f160c9c8434b711e090d20491ed35bed468d253e6b9dcf4d91d8edfcaf664871d6673398329a4345280b406aceb55156e48236be4d5d59e8762bb7b2ca6e4cf7d97252a2b25c7fd32b5368074a45d92686fbeff003b01d74d38d875b435090db6d905badb623e3a65d8374eecd98dbc2bceeafc1370a3e0ca6dcb7fa2ae20b517b85f8d8c91ebc31ea7d3a9c21a2b4ea212e100d7008f1b93b01601963158218a919a726b497da7d0c96012a75d6ca540e93a4a0015a41503cfc94d8c9191c7ccc4bac965c6326dbc10cc94d694b29d416929af26bfcbf0aef24f60d4cb10a34c7e5b4d21a0a5adaf46dc08a5defa74a6eaef7d87c1339f86735f490db63dff00bc93f0e262e1e48b5d6f4eebd85fffd9",
        }),
        Aurora = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc000110800c000c003012200021101031101ffc4001c0000030100030101000000000000000000050607040002030108ffc4003c1000010401030303020405030304020300010203041105122131000641132251617107148191152332a1b142c1f05262d11624e1f11725333492ffc4001b01000203010101000000000000000000000405020306010007ffc4003111000103030203050901000300000000000100020304112112314151f0051322617114328191a1b1c1d1e1f1334252ffda000c03010002110311003f00fcc7363e3130a02f1d2a43f216c954b43ac8425a735901283a8ea1a6b7aff3431b41d4b9eaa104fa54a5103817e7f7eb6673312b3f9f9d9a9adc76e44d794f3888eca5a6d249ba4a52280ff86cefd35e37b244f63f30d4f4fa069a5baeb4a486c9ab51d249213c9a04d7cf4e8901249ea23840321b5d741df724ae3b18f60470b692c2d048526c580771bf3fad6fd56bf09e1e59ded2c96321e510fe3b22fadcf4dd4fa884ba96880e2d26f7d5a0d1f849e6a935dfc2982bc8659a47712250c702db460b0a7153496dc21c4a9548090b46955abf51b1372fc3ac7ab15d9788846029121a6b4bfaf6285dfb8d9e4593c1ae7e3aa9eeb858aedfab861a4029c8bbb7cfae4a9f770f6467f13dc58dcc2338425971b98a5a945080f24952c9a3ed3574baf23ee364092ccfc8aa0cb9d21cc62549fcd3cc37ea2bd2428da9239e48ba3c9f3c17bfc474b88ece7e53652036e20ba4a0abd9641e071bef7b503d21e26761f19da93e6c1ee8c93195c82ff2abc725bd31dc64fbad6aa346f6dbea9a2927af345ca554133eb610f9325b818e595d6264e3e25c5fe71a43cfb6e17582a010a6d5a94428fb94544d1bf71ab2383d38bdde89cb76b869b92cb65b51714e368a5858af3cec7491cf8fa7529ee1cee6b259343eec58ef2d0c0602a3369693ed4a5284e94a696a5000557c7000eb06632af62f1f327b791c6a1c6e52194c2082b79615aaca6814fb0a3e41b3bf8d4e5eca668b69f127f2765c1291a478ce7cb863f3ea993b8ff8936b4fe64adf0a4a5869d4382964a74803c8b268023ff3d7ab380fe1f1a1fa0571e4b95ea48d3648d8948de81a3f17bf49d8e9d9552da94720f3a56903d1f58a6c83ed4937fd3cdfebf3d3a49ee6ac632dca642884a9cd7b254972bfa2c583ed1fad7d3a7945269780e6e36bf2fd2730096073220d046d8c2dd8fc6cc9095613111de92f1d721c4b082494a45ad676db7bdb8f03c0e9561671c8199562f1e5287264bb7a944a5b3a8856c9dc6c071cd1ebc17dc7c65d9596a552994a126bd4d4823617f1b1bd88246dd78c07234b61531285a1e426d4a2b2161564aab63a86c38fbef7d3190b240226580fc714d1d0b1d1961182abe1f53b8f4c395254e34004ea2012af163c03f7eb44d8a8622b02d4a0ade86f4078ae38ea7b85c8e573891533f2a54a52d09427d3b29d89e059fdebf514d4559076121b97256b5277b1435555937bee7edd7a205c6ec161f7491b4af6c83bbf08bfcf18b7e57b227ac46898e6b1ad43754fadd7668d76b4e9034aa8e9f07f7fbdf8499f217ebb0c96dc4584aec137b7cff9fbf43e5a5f282028ac7c1362f9f3d1392ee36648653888afc18ea6db416e5480a25dd202d5a880002adf7dbcfb47b417ecec0fd645fec3ea9a7b035d28964c944d4e64bb7b19320cd665e2dd98c35adadd1ea347dc2c7efcf1ba4f047537c9b7dc5062cb9fdbafcb8ca8ed29c96ec35105a8ca052a2a23806fefb5ff00a4d3a4f873dbee0771335f4bbe892d2dc4381c4a424550570050000f155b557530cfb2891dcb8fc1b1291e8bc4b6fe972d4b1b28256a1742c5d1e09b0361d28aa7b29e3b0372ef966dd6e861a29652c04f136df1d05d254969ec2e1b0b8f8511731b754eb52dad7eac942d294a5a29bada8d002c5ed44a8ab52e56471f315d993f14cc65c17dc70a43212ea5d501ad2a72ac8f6edb915b6e00217bb832ec6672516061f14fe3dbf450d7a332487b438940d7a4e91b13600ff1fd3d1c8b1ff2ce9a4a96fa8ea54a75454a2bbdd4547faac93b7dbefd53048663ae2181ea73cb8f564c759732ed08ef727fe97c9f6e63b1adad709c0ca8497dd9295152ecda928da804d58b1e3cfb8c2bb822887985b216b55253fd6ab50dbc9e9c7be5f8327b9e240c0437da692d33ad9d5eb38f49dc288a09b249d80dcdfd809f4890f4a92e4890e171d71454a52b927accd4b4b6520a0e9699f0bc9270782f2e88cb5e25e850538f8b223c9698225add742d2f39acd14000691a48db7e3f523b9e8bc0c8331f0efc518788f4a321a9089ce82b5b494055a0209d0a4aac12083746c1da860989c26587d813f278f4bb1d6d475ad36db4fa561c51b000200346acd9dbf7ebd7b4f28e76de79ec16752e34c281654828ff00f8d77c906af93f3cfc7560fc3d92acae0d972136a7980f50ab1e91dc24d5d247f5023c8201d8d74273bf8619cc866e7f70bb2fd55a9b2e843a80545401355c01b501bf249af34eabdc15853dacd7c925356101bc39dd33f68f72c696d9c7c7c694389a087c36548469ba00",
            "2012926bcf24fc503431958cd07508694da50ba529642537409ab3f26b8e6fa9cf68c5c0c5c4fe5a54a76332ea1657218614b5a9d4a364a81363dc77fa800d5d8f73165cd8a52d171a68292a0d1685bbe37dfcd0dc73676ea0e6db2164ab28e37c85c30dbf15ed9def65ba1e851da4bb1c0f4dd71c50a55aa8e81e4820ef638b17cf51dfc4c853a0299958c8cfb58d94c25b7c0dd05692a3a76dc7b4df8b1aabcd5272d817b1cb429f663290f20a834dab76d02eae871c006ced7fa2fe523e433b8873132dc35192830df705aef52686ea00ec4efbd01f53738812eb04efb28c54f231f0fbbc7f7ea0ff0014ab1b90534d2a3c975e750ed0041fea5151215a86e4df9f8beb449c7a53de30838121a7db0b4216a1ec1a491f35fe41bfb74261457579431741b65d1a90a4d5f37fdeff00e6dd31641c8d8bcc62a1ac95966194482ad56952a96526ff00e90427c6e381c744b1d670056ddc744ba5bb907edba22b521297dc6d6b5b9a8292542a80f3bf079e7acf296e478ea79c9275b764a97548514915676dcaabf5fdf502a79a62434f82d1428295fd234906d5cd0038fb74bdde0d4c86e4a8d310233c1d482d253a292757b14281f694f9def917c31f6b7016baec3317383094d785cc631bc1c74badb2f90da90a1e80b7013b8268102c9e0f8e983b772780c565324de4b1729e52d9488019774a5b59711654937600d5b59fd36298c609f9689c90c3a501bf7dea20245efc79df6e373d35c13930f392a4ba10d1d49694e1a091ab91f241038dff005e994356f9d8d6dad6e5cbd51cf61782d54497dc6fe2b31154db01a8a9dc2196c029b228fdbdc07e9d7944ee4ee1c8b6fe63f28faf131e4263bab29a4b6b5de94dd036427cf163e474371b9b2a84fb729687a3b63d40af4c11e0017600d8f9f8f3d2e359c61b9b9581161b5353936d286dc714a3f96521429c484a802aad69def651ad890a615133435a6038be07150ee6322cc1b2b26232d8fc9c590bfcb287a6abd777636e2befe7e7afb02561262324d4a9925a7d864188db6d25697565406952afdbb5ff009f14a9e61a5b580763b93a527f34ca82d42bf96410a484aab6bfa9e3ebb1e9a6548435015916a334965655ff00f58ff59e783c57edcedbf4c69def7df51b73f2eb651883d921bede6bd4ce099e6347f495256da8682eb69342b9d6a03cf276dfa609bf83336376446ee2672f8b71e1264ca7899284b286d686c25095851074946d5e6b8bbea19120476de9b2cfaabf5d6a085ec8d81db81bd9f0287b6fcf4d190ef4543fc3f8fdbaa93210cb4ebaf7a61cb6d408469480abdfdb747f4e764f565d56d05f66807d70ad744d91aed632505c6aa13d9bca29d60a834b538c2db703894a801ac5eaa366bcff006eb833ed3edbb15b82a7890a2a58591e9a471e36f26fe3e7a0fdb81d6dd7721e929b329db084da894ffbdd81fbf1d68eea90fe03191a2c049419282a75d422926f84fd4d124fdfae41298a9750c017be339dbae4ad600d6868e0948e732f8cee767358f9cfc4c8c55a56d3c8552da5015ffd8f3e7acf8e8ade6728ff00f12cd33054a6dd90a93335afd45849569252092a511567e7c9a0472d6a71656b36a26c9ebb32cb8fba96db4952946875947b8bdc5dcd48ae82ef6164edc5f54b42e1f73c52fe5f04b7b2edaa232d3b00351d80c34dfa6b4a9b427dca3493aafc7fa40a2bfda6ecec1e64cd6588ee38b43914fe62321f42438929252142b55135ff00cf4d2de57f84a25418d8d6a5c2284a945c58f63bcdaf7209041a143700ee08b81052bac9dc0698b7554fc21859e8f196c4ec53d8e6591a7514a905ca5790aaa3cd9e09fb7541c93aa96d3ac46c922148ba42aac13c0bfa5837f1f07ac98fef7692cb90a604a1a71c428ad4d1242c0570b17f6abbd8ed477cf939f1e5479135892d4a437691b1041d89078db63f5f9e9ac546dd7ddc82e0f119caf9ecb4c66abd52b08d5c40bd8fc6e0fc6de88ab383971e1bacb7382dc7f51716a4f04ef69f8deaf6e3e08ebc3b7d9947212dd9086d296dc7107d35950593a483bf240f343622874b717ba948ee56e3c75a9c8ef2d1ea8706ed0291fb5029b37f7fa64ef076376daa7ca6f32ac8890d36b69c8324b686dd252a25d469a557bc57d77a26d2a6481d19f22968ecca82e31b88f15ac6df847ff12cc563b51e5b53595497e31012d2376fdc4685922ea8122bc8fb5c91195ed581d8f2c2f2efa3b95b094c687e8a969274da8a963606f48fb50f27488cee73319ac6974b8e2e3a145454a5048038d29df7163ea7603ee8d1e20cc4e6988c4c7d60979e58d414413ee4f9aaafa73543a61a34697377e18b75eab7bd9dd98d8221a8ec6f8f4f9f9ad1892b6243f2df529f91350ea50160ab5036952946eeeb50e7c9df9e85c990d3d21af5096024581fd3bfd6fe79fd7a312a0aa1e413aa1bc88711c4c7f514ad69425449f758e554b504ed66ebe3ae8bcb2f27371d0e4c488a6314c2d8052c2120da94ab7280d6751e49dfee4d86f6383adc53800ea2fdf0bec39ef3115942e5391e9ef51a75295053646fea0558360f03c69b1bd1e87e732b95eeccecfcee5252e5bae2b51716a00b94401cf9afa745fba22b3dcfde31a1765e367969e6da8edc675ef594b7c2005e9212362a4a88fd4fb47b523b050217f1f8317b8de930e0a9e4b72d4c3495baca46c7d848a23ebb8dcd1e3a8e78a9c6dd2dd7c4a39d8f88c74dcac985272b1e220455b81c94852c1d235840d00ee4803ee7e6810ddcd166ff00113ea1537a103f920d6849dd3b78b49078a3d12871d1",
            "1e3c988e38f06ca56bd6025b70201a1605d58deb51dfadf233199cfe4346727ab20e25811582b295adb6d290122ac91c551f924ee4db98dcc921115edfb44b25691ba56c2e6047c5e5f18ac4b3905ce8e1a6df71c5a0c5a712a2e2694137408dfe478b0a6aed9c221bc12657abadc53c6b58aa5252783f4b3f4fefd2c2f08ec4965c0f3898ea06dd6ed1a4efec56dc8a26bcd7cf47fb79e5b527f251dd323d520145eb42962d3fb11cd78ad8f5750b44520330f2ff0015d7005d3339db3955a634dc8e39f6f1f91654f30f14d7aad92a00a40e77036f820f15d1cc4632062d113f8963de9d110a08911987694ea0dd849deb9fd6c8dac10230a66c2c92db79f79515b0e35199354c04acd81bd7fd64d7cdf9be8b7701cfc16529c54474a0a296b6db0a22cfcfcf076f83f1d6821eefb8748fdf3b6ff05587b08c948d9c99fc1a1aa105ba998fbaad30c10ea9b6ff00d3a9400f75f3437e4d7950c8cf9738a22490b4a183ec6967cef63ef7d7332fb8ecb70c87017b5126b9366eff006ebac58cda9c5372a4a8cb4ff29b4a890122b650241db7e3acbcf3ba471634d9bd6ea408011ded79f21339b8afb2571d7640e02549dc91b7df9f3f6eaaf13b370594c44ffe2921d6a13719c536b6980ebc1d093a134a2286b037fb0245da53f1f05e8ed02805b7da20209005935453ced5ab63b8bfb7552671f0b17198c4c7c9479b224b4dfaeeb5fcb69b0b4a55a495e908559503c58f8a50138e5923063e07191c120aaac96370745817b1fdafca125954792b6569d2a49a22c1afd475f58716dba828009041a3c1ea83f8a9daf88ed6ccab1ede40bf996e53cdcb69a4a56ca52024a541c0add44a88228555109add0b1ec332722c30faca1b5ac05281028793bf4a5edd0f2d09f8702dd4559f1df86f9c990a03cf34b8a8cb361f8ccba4252fb40ff5247faa936401c037c559eee7fc27990f10246212b549536965c4a7469041144151be056d649a2474f7d8f8e6a261a2adaf749f43d205242cb4ddde949f09bf03837f72d1dcf904b18f44b831dc4c86b4a571a3207a40001295da95764d9a3b0adf80a5152536b94341b03d657cf6a6b6792b34c0f0d00ec78f0fd5909c9631134193081125d56b7db651bfb53ff6f0073f037f07a577e3ad6e2d01c5b4e32929f540bdf70362695befbf4d1db79d7718f3a7d6710a29291e983bdf23ff009ebc64ad7261bea723fa6b2a346acf15fb75aca761a77184b7c3c0fafe938a46be8de69a46dc022ce3e7cb89b7d31ba498b8e878dc5cc724c9723c90d831434dfa824b9a80d2a2a234800a8ed7f3b9a0503bdb319186b6e03a90633c12eab59ba578503e05922be3ee2aa53f1cf853254b4240550b22c13e4026ba40ee918c18961e56224429e97e94fae47aacb8d13ecb1a6d2a3a1646a571f3b002f6a398c8f48e3f44de59602f00007cd4cdf7dccc4c7598ba9a4384842500d9dacdfc8ff9f7278c437858cb959974a5a694036802d6792123e2eab8abdfe482f8e84ce4bb862e2589ece34bee94392e52752184804951d22c0a1bf8fa802fa1fdc471d2e36363fe5e047930595b4e3d18b8b3315ea28fa8b0b3ed34401b03b7d825344d6b0ea665de7808e8f4100350cce77d6532f1a4c1829fe118d9aa65d918d86eb9e83afb69af54851275136afbd13645f41187263b00c26d8529b52b52d43c9bdacf8debaf795163b4bd0da8a8ab6013455c7c7ebd680b2b52184215e9a52004b69feaa3775e77e851190e3a8abec005d30f19e54d2cb728b6e356b247b74a80b041e6c1ff001cf07a78ecbc7626162277f11c5c39728ad2b696b7141c4690ad86e11476d8d9a26ef6204b2c33fc3624c8280e942f5a82afdea068856d40d706c7e9bf5ab4c62dab20b7d4110dc5109d41042811b03bdd8af1ca4edc5c2231b5e0482e1299260f258ec03845b3b966bb822e2e3a31ed45662b1e83610c0696a0a5a947514dea364d13e413c924840b762f71b18f650ca96b006a5a8af4000ec373b81b7d856e3a6c8eb83928cecac7b8dbae0504ba848b2a48bdfec74d5d6ffe14f311a4c9ca7e6f14dbe1486aca74ec4d5da6bf4bd873faf55d4bbc78d901de874863d80bee98f3c98f070b9232d4d2d094212d058034b86f8037bab3b7eff21ff0fb12de54e6b2cbce47c6bd8f6c3ed47214a54b25d4a74a2810373e773b6c05a827cfc84e96d4861d756efaa12ad15ee34360af3607cddff83bd90de4158ccccec6fe4dbfc830975f2e4b4b0ead254000849502a3f35f6e4a41ba19c970ef0e02654f1be284890dcff155bb7b2ad3594ca393a2c596dae236cb6242d61f8eb0b07d44dfb428d57ffe7c582c139dc764f04a8df9869a124292d00b0822c105375560edfb6dd2862a245cd30e398e7170b31a54b7759d69778b052483c826be876f8d100b2c6054b9884b6da1d512d24d942af748ba3648f3e53e0034753d443de5b5101678be174c2ce2d2db614d7b8bb59dc4e6132186d524b8af616bde90b2782081468fc55dd71b6b87160acae6bce0d4948a3a4528dd241bfbee7e01e9a64e4e1ceccc97dad4c850436dc55a4052b7f76af00deafad5f5f24ab1707b4e7cc9afb48cda1486e2c74b229e6c856b52957b2aebeb55cee45ed10073a406edeacb42c9f50caf2c7f70349434ec774e98ea2a71a5b61c41344fb8104286dc715e3c74b5df9f89791cee5cbf1f445941d2ebaec6b6d3aceded48fd6eecdf9bb3d05912bffd2bec15ad25c73525295559b343fbdfcf402360731371ae656363a43d01a7db8ee486db2a421c5825292479347fb7c8",
            "e85aaaa7bec00b1eb644b61639dadc3236581d75f90f2dc79c538b71456a2a3ca8f27a7efc31c03b2f3ed651e652b8919415ee4d851bd85f8a2013fa7cd864edafc36c3398ff005b2cb5b8eb806c55e994591555e4fd7a79858d878629671cd11152aa4a5c3a8b86cf9fa9a3fa9d874ca87b1de25124fb6f6fdfdd5e48712cb268c466e4a738ec165bd0d86bd41e9d14806857df835d303bdc0eff001080f7a2d264c03694a9b484afddaa95b6e79e783b8df951885b66495389435eb286b4b569d86c01faf3fbf9e98b33021ab16cc88e521c228aaaaf83c7cff7dfa22aa9a2efd9de0f7b18fcac5d6d2c51d5c7adba75e31f9cff00578e0654b8d956b26da10ebf1805b297100a55bf07fbff00b6f5d7d5ca90cfe61e7025c43ce6a25b0915bd90129daacf8a1d4e3b07baa2e431eb8214fa0c76bd65389248d249b2ab340ef640b279dee836969dc2bd21999ae4b4edad2a4152b627fe9de81fa715d5a2a6191f7041bfd87f51f512b7be313edbfbbe42db67e2bc1ca7251a4aca07f46bf1fec3a41ef13383f3b04c6564318f756d3cfc60f7f2ca5b4d0551e0ef5f7af81555632588838d97365e39dc8434c75ada6da7128585e8f6d1208fea3bf8e0efc1fcfbdcddc5f99c9cc7848f46438a6c7a4140293cd0db63b1df7adbf717b5de246b46d6faff00423c97543c3e3c69b8f5db7f4555fc14c3762cfeea798ee198eb5967da79b8edc98e86d9014d28156bf50ea5049278b1b6e37ea419a8bda91f3f916b1b3a44a8edc857a6e3a8480e513bda5c5823e08241e6fa2f829cc4063251d5868329c9d054c21c77d41f942b34a712057fdc37bd8fc5a48fc9e398898b92ec34a148580a6c107dd4b008d238240503e37f3d66a2716bae72ad8e76b2cd23278a5b31a72d4c3bf907821d49532509af55214527493cee950b17b83e7a398e1111084d6da535edddb58f71d8d815c0f37e7ad7dc7ddb90c9e3e06284898ec7c7b41b8eda960b71d0093a40deec91ee35b50e00a4e9129e9c4495925efe9213494ddd8a038ffcf44b27d079945b247482e45933329c7b4c640090e161c6fd76dad290a4a93476248f04556ff02f6e8231ab2d290d3d216d871d485228aa93b51b009366c5d6db0f3d62752b7611515b6529f6da8513b7d3f4ebe407ea50dd34a1a5414292a1ff0077d2eb7e7aa8db6b6ebc22d21c78955cecb61a5f7463b058a421c3955984b53ce25b425c2426f734a03623e6e859dba69caf69ccc3645c38f92243ac2d487436f0582e0246a4ad3b55eff3cf1b810385dc192c2e6d396c4e4570e5b6f179b5b6bd4a4ac13449028ec4fd0f9e7ad4d778e65a9a99b1e5bdf9b57f5a94eeaf509ab2abfea24f377f3cefd00f049b8486a7b2e590eb8dd9e37d8fafed1dee8c6cbffd4acc8631c194680975206d66c6ad20ec08a23f51c0e99bb13b6f1733b93d192fb0148654e217ab481b104782aa07706a85ef5b1414f76e513973959e88b21e6d63534b456aa23da40e473cfc9f91d16edbcbb4db0fce8ab61b661203d2187969429292e2136deadd477badff0042403ecdaca5353549a6ee9bbdad70aab92cb764cc821e8733f299288c2521b6429b0e2b50bd208f72ecedfefbd2c66fbb32cf63f1f8b6d50bf2f0a4b939e3f966d2f38e2800ad4a15a894f81f07fa804e99765328a47718c8c7909527d44be1b6d5ed0a4f036db91e3f4da8f5b1deee120ad7e829a95614cbc2bd8aa00eaf0af3b91e55f3b4a3b34dcaae97b2cc1622ee079f0bf0f4e2ad98061cc8615ec9c5c3b2e3296dc9339e446f745005152a8906ce91e091a95c0348b96c863729ff00bdc63443652182b7125256a1ca8017e54078e3edd65cff0072e2a5f64e364e1f34b6e725b423258d799537a965c5abd84585a520239f9079a48073b2d8a6e4b48ede72764a14561b79d7a447f44b65411ad252952804a5c51f75ee555bec49bde0ff008da717ba2e1a0730dc73ebf01678eec45ce0fe4e04998cada7198f1e23ba57ea9494b67dc957fae8d79faf0798cc16660f79b784ccc69515d65e0b97195ed520a01a51076b01468efcedcf59a53f1ddd4ec86c3c50af751b48bde8015e4f3f4eb916764a6655c75a94e15c857bb5a895a8efbdf37c9bfafcd74530344ad2ece463af927adc05fa0a4c492c4d313251dd86ee86dd08750524a4a7524eff00f3620f1d12c72b1ebc9564129525ba0081b248f2456fb81ff0f4a98ccde6a76271cd64836a4e3e3a62321a6929fe5ea24eb501efae01e07dec9d51b2684a1a643816d2956b595051457cfd6c7f6eb72354b15df825553c625696936bf1183f05ed23b82363bb83f26a921282b4a42800689df749e051f937d3748cc9938f5bf19d6cb4a1a4a500100fc0375c7526ceb589ca44c9e7a34f698c9457d98cdc3735879d06c2d48ff450d236f82a27917826e7d7dbddb4d3d11d5dad642d7566d4090459e6873faf4a5d3445e6579c0ebab25f2d1c533d939dfcf8a5ec6caeecfc2f9d0f32b8a59632919484372e3a16990c28290a22ec581e47c8e42a8baf6f777c5cabc1bc74a58521a71c5b2e289aa6fdc5015b7f4a38fa5f27a910c94cc8c943682ece528fa6dc65dad6ab3b2520deadd5c0dec935d523f05b37f8698bcd64d5dd18995ebaa0c9f4dd764a56de9fcbb9ad013e958511601bf239eb1d0cfdcb83c36f6577b236621d20171d6423ddc521b576a4ec7bd994b7216a2b4a100a8aaf709483e7ced5faf51699887d8525ef4a4c92aa5396d905362c8a364d6f6781b74473fdc09772722676fb793858d75e712c7e6240701a209161",
            "b48ba50bf20287cf4b0b9525c714e3921c5ad4294a52c9247d7a32aaaa198ea0d23f08a8a1115f4f14f787ee15179114b65674116f29452935ee241dcf1b7c7d075f72af398d692ec45b2853ee28e80ab294d8094a883f17b1f07a410f3c92a297549d5b9a357d7552d6b20ad65440adcdf42b670d6d80cf35114ec69b8098a03f8c4641d7fb922cb9f1d6c3a8088b2d2d2bd528506d45452764aab6afde882c7f865f879dc3debdd1160e3f1f252c871a53f21c655e9b6d9580a5581f1d4e3a64ecaee3c9f69f77e3b398c94a61d8efa14aa1a82d21409491e46dd0fa8dee3757dac8dfe2276ef7ce0b28ca7bb308f420a690db0e221fa0d3a86806c11a4004fb45fdc7823a568086e23e4e450d965d4e95255654055822b83607d77e9932596fe398588330d32e651990ebc72256e29d79b557f2c824a4252ad44501ba89d8951566ee3c53f816930df5b2f4871969d0b8afa1e4043880a4825048ba276bfdc1be88634db53b828dc1c0594e171f1b1723303231dd4b6fa186e192a2eaf50512b0424a6869f9f3f6b04ebe4157a24242804aa80b3faf46a2c17dbc7b91d6ceaf50a1568412b048b1747806bf735e7ae093dbf1e2e4e3cf85265cb31d2884e32f06d31de0a492a70149d434ea157f4e774d4e0ddc2ad84136dd2f6b241b0093e7ad986c549cee76161e1b8c372263a965b548792d36093435294680ff0082cedd71d6b1230519e665c856514f2d2fb0a6406d0d809d0a0bd5649255b578f15bf9e331efe572b171b196d21e92e0690a79c0da0127ca8ec3aa95eb3bad2997dc6565054da8a4942c2d24835b281208fa8347aea059ebd64c67e1cc7a2496cb6fb0b536e209bd2a0688fdc75b5e63069eda872189f2979a5c87132232980196da013a1495eab2492ab15e3c502af2ea1a6af637d6fc7e6f2d8a8d3a363723222b190683129b696521e405056957c8b1fe4704f43fa21019c4390b22bc8cc92c496d80a8686590b4bae6b4829592a1a4692a37bffb1f2f22ee2ff88e31b9119252f1090f369ff514eda87dff00e79e893ddc9360f6e43c3bf0e2fe559717219508c84baa2b080415e9b58f683bfcef7b562ecccc45c5e42e4b6a754a58d082a1a55777c8dbc7f6fbf4c7f89ddbaa8c9c477147719307251cbe12d3e85fa63594fb9293ed248e3ec39040731b47b399d8ef172fca8b5b647709dd0c4aed80e21294142836a2e28024957915406fcd78eb34acd63a262a2b989cf30fe4e7c65ca9498cca902104a8a4b4a0aa05442471f3f0524a0e333ccc3c77f0e4c2548d67512a5e9008b29f9d81a3f517f3d7d670afb98e71f2a410b737d077140ddfc7076bbe3c7453bb4a6998d6b736195024bae1c16e810737957e764b098d96eb5147aaf38d82a28415016ab3f3fee7807ae4e899b79d898fca0d284d292d93c956d638e40ba06b9200be9b7b746260f6865330acdbece68b8d34d45d14dba83a8a89503abdaad240f2520eff00e947c8e69e5e412a7e4896e2169d4f396b208236bf2285727f4e964b7634076c782189797580c05e18c9f1b0513199dc0e5e631dcd1e538b5203410db08484942d2b0ab512750292288b047fd43d53e4cc7d525f57a8fab505b810352b58214a511b93bf9eb2bcd0617a52a2a0459b4d11ff002bf6e8c45ca4a93838b826bd10dc679d929d31d01c5950482952c0d4a1ed1c9a17f414bd10eb7bebca1771cf8cce371d3d4ac9e1b1f28ca4632438af40a955ab607c803e9cfc9b0ee90a796a0d25a0a248426e923e05926bee4f449f4075b0db68642b51041f6a81de81bff9e3ee31454a512a367af29b5d75d7ae75ceb9d794d19ed5cb43c1778e2333908467448529b79d8e34dba949b29f72543fb7da8ee35f77e71bee1ee89591831130212c84468c94368f4da48a403e9a52926be07d38ae86fe6db9189858a8d88644d4485aff0036d6b2f3fa82425babad88da879fbde25beb73495558bdc6dcf5d0b888cd9012c426d5456864051d22cddf3f342bfe5f58d994eb0429a75415f6bff3d3de0737daf8eec3ee1c5e6f0c9959b79688f19879a57fedd21454b742b58a7135a4029f35c158e87f6ec6c74e9a6245f7ca70696db4b64dabfdc9d801577fded1739ba18c858d25cdc04b067c90e977f30b26ee88d95f71c74516a97dd7270f86c46112ac969f4088e56a726ba56a56b505122e8f22850f02807677118a80f0cbe40ae4485b817fcc49a427fef26c9157bd8f17d649184c3cac947ca45908c706f42f4b24e8d5aac0d492143ee38ae7ae08dce360858eb18e70b34faa9abad3b1df7187db534eb6a285a1629495034411e0f5f5a75d8efb6fb2eada75b505a1c41a5248dc1047047447b83d25f70ce75884c4165c794a6e3c751536da49b01249bafdbec38034364a49d405703c9eaa208c14cc1b8bad394c9e4333969594cacc7664d94e171e7dd55a96a3e4f5e9896b10f4c7119a99262460cb8a4ae3b21d517020942482a1b155027fc7207f5cebcbabb210b71610da14b51e02459ea9bd97f833debddddb19bcc42c349434c471f970e32b064381d6ed28db73a4a8fe9d4c2fa7eed3ee6ca76f7e1e7748c7f75b10952c331462d495975e0a585175074e91a4228d9ff51e2c0570df82f24b998fc8635f5333e14888ea0d14bcd941047dfa3cacf2e4f6c3f05c754b5b81b4a90780124926b6fa7fcdfa59bd4bb513b9dcf4c98fc6e33f8a4299919ef42c43ae24487a2243ae328bdc84ec09fa78f83c745c0f7b03b46c467d170af485fc157df38cfe1b01c6a0a7d10eb52e425cd4a0901c5580055d903f",
            "f35d11ef7c8c61908e9c6adbfcb2136036da5002a813600f3f1c6c3a5a11c9d4fc68ee7a087090f14685292764d8b207dbf4b3d354263b5f0ecb39692f42ee2fcce2de5bd01c4ba910df56a6d1a95692540d2b6be2f6d95d5d1bdec89d1b7fed95591675d2dbf025e2e1c59d324c7537938e5f6db6de4baa5242d48a5049f61b49e6bf7b0029b2ae373bd74ef8eedec5c8c163951a43f2f3cebeb2ec179b4a184b60274daf505127dd6914763c502a1ddc70d2aee1992463118c0eb85660c70422303fe90544ed567e3ec380dc1da413b2877cdbdae9f735f8671e436a97829697964295e81046922a9239dcddf3e4017e50313819f9e9ea8d0834c2934124a95cd84d0a249dd43e685fc75fa3a741c145506fb725ae44553692b0a8c02eca53ad201b4940528937ff00511743a9bf71c2ff00d3f3a0e5a135e8bc9929595b428208ba514d9f15b6e361b727ab9d4af119946cb3749535018e6937e02ff94a123b4272f0793cacbc9466e7449298e98088ee17248a5296e3674d109a1767c9ba3a41527b1b202c96e3b8a429549594ed75b8f83cf5fa1f1ddc91b2ec20656234ce454bb285b65925b249a483b9a401b7fdd5cedd2fe71509129686232dc694b4905c45322c8dca89f8b22af8fa756c34bac5df8c7411d475b293a25658db86ca5a312d47eda79897829ebcd487db5c490dba3d2432127d44a9bd24936a46f7b11e28852ea1975c7d2c36da96ea95a12848b2a374000393d523b860417049cb43cb371df65e4b7f9256af5540b6a52d4820504a6aa893f5de8290a3ce9b8bcab392c7c95c6951d7adb79af6a82879e869181bb2710c85edb9dd7cc56424e2731132511e7987a3389712b617a1628ef4aa346be411f43d19ee96b111f2d1b33db9972eb53cae5a639756b9300faaa0943ae14a6d7b0558be793b294b8e38e3ceadd756a71c592a52d46ca89e493e4f5d4024d01d52ae5a721909b96c948c964a5392a6485971d79c36a5a8fcf5ab039c9fdbd9d8797c7c97989115d4b895b2a0958ae40241036b1b823e87af673253e476b44c23ed456e0c47dd92d3823203ce2d6948292e01a943d839343cf09005168846e950555efb0af9ebb90a26c458a65eeceeb5e7f3d35d82b96c635d7d6b61129d0e3a949513ef5a40d477fafdc9b2714a9a2547c6b6cc344211992daa434561528eb52b52ac9163556dff00800d76ff006fa938f732cb6123d5416a329c4a1d4fa9a45ea490456e3915479bdc1a938d69e8b1512e4cd7196524b45e74b89283ff0049f1b501f4f1d7aeeba58eaa8e376860c0e4a7d352e2db4ba76090126d3575b6c7cfee7ad3838227c9fca29cf492f500e041514106ec7ec7a649581d7357122b67d3006b43b60858fa55ef43fbfe85317879281aa7e3dd6d0509299484eb6c245ec520580469f1b7eb5d171465ef048dd5fed2d2d1e692735db392edfcbff0dc82195ba5087018efa1d4d2d21406a4922e88b1ff0091d0d8f0dc91290c586ca8d12a0761f3d52fb85882718871bd4e00955bacfb4a6eab4a41e08bf3c0eb140c47e5b1b897de111c726365f0b6dd4a8a52494d2eb749b49d8efbfd0d5dec4e12861e2af63dce172101c876a4882c15475225ff004abd66f504d11fd22eb7163f7e7a5b71a2971692140a49041dc837c1eaaaeccc7358a6c4871b46b6ca0a356e4f26afcd9bfa6df1d4f806b43ce684a9216b2a0a00280b007dff004e0fdfa956533222349dd48123de4350d3cda90bf489d40a906f9af23f63d1bc5bc0e2d6920ad0174b4ee3413c281bae6bfc74367b8a726a5b5ac14a004ec7648aaafa75f4badb2fa5c085fa4010805237a14091f3bddf41b09612a46e426044e65982a65c8ad5690db4a79253ed3c906abe0f046df24dbff6ce0f0f1d2c4c2dc792928f55e8ebf785a2bdc9f6ee6ef62082456fcf533cb772bf9fcbb33e73115b71a61b8c9433192d37a1b6c200294016481562be942807081929386111f01d6f1607a690e9a5049037238a000dc5f1e36e98c2f64a0b64d9095319923d17b5d35e6b0315cee45f7263e02715114f25d8ad4790561949b094b695591f15b0f8005006de82d65125a90873210e8a882801c695540da74823722abf7f019eee388e44a91004831c7acdbbe9a544a41048007238df7fd3add80ef7c0cbc6aa2b710422e7f2d56923522a8f1b5513e79e8b93d9e380c4f193cbee9354eb1011232ee18b8e039f346711226f64c765a9bdaec6423a61a9a790a59345493ef036277249f9df8d88d1171d0325846e54e8adbd0e49a4a1601b4ecbdbe0822ebe9e7a2786cc2a6619962384ca92d2544343c93bd1bdf83bdf3d71ac211920a66e28592036ebeb08d4a2480104903926c0b37bf53884914618f00b4dafe973d7f89677f2c71f773002e6e48df73cf23873413210d96a48fcf470594301715e65ad4526c949f9046a23e0df823a456bb6bb9b2fdc0f63f1f2d97e37a4fcaf564490cb6969092a59f750d7562bea09f6dabaac8c0436b24b879ac9c8f452d38a4bb1d90b5a5747427757048dc5f27c5ea0a71257f0d9b321487d6a616a714de9b5240e0f1e2eb6f1c747985923439aeb139bfaf5fd4fa95cd110998412efb7c547c265494b98f710e194e7f31a5a540173815f1e4d8277b1fa2b64421290090a593c837a47fd24d0dc7fce7aace770709e77253a7b92e329b652a8aa65a0b4a9e0bd252b51234029d46f73c91ff4aa74b0c42ee78edf72477666352ea16f36d3e94ad6dedb2575b6c78a1b7c72105745dd39cde3d5936696ea36dd2cf5aa2a1b59d0a584ea1ee511",
            "b2458ebc5ef4fd65a9a4a90d951d085ab52929f1668027eb43edd108f889aef6f4bcf36fc64468afb71d683210974a9614414b77a943d86c81fe0d28563b213a76043c59ee6626657f2992838d7448761c85a8475202e895572374d5ec4a80377a4d19fed7fc3562440ee06d91937512fd47203e5498aa64242929d40959db6f75f04281af744bb564770b9953dbf80cb980acd94437b5490c34ea4ac1016a240ab03ebc8f3472c9cce49b53d10bada136a43896941685720d1048ae6b49adefa8906f7ba4f51453be50f8e5215b31b0fb47270a262f1196713936e4b8e184842bd02d681a4214a36bd891e4fb77dd23528ce54bedd9a9f7a31d0c7b51ea85e85ae892a48b57149d893bef547a45edf67292b36db703d55cbb4a5006ea2750000f37c556fd5371d195dd5266f6b775e5722cb91521c8ed36c85a9e57a89242893681a493bd8d89d8000da0179b1c941c94e6294ea7ea6919e7ea91f25dcc993216dbf35c9ac857f5a13e97a809b558f8fa9dfadd889acbef879d92ebcdb042d4dc90a01d363da349d5a7c920a4d7c5d86aef4fc2ec6f6f6523c696578264c40f933895a96093a6803fd4782361b1e08204bd2975a5b91e3ad4a4850500bd81154493f175b79faf56e87c445d3189ac732d1dc7af56f9264cfe43199acb641e4e2d9c67e60b8fb6c47512db69d64809d46eff007e760914073b3f252717dc78f9f159654e46792ea43c94ba0a926c583f6ff3f702f1abc3bb955b5dc93e54184965d71b763301e5adc083e90282b4800a80dfebe01d43db17892aee331f2b9c630a84c1fcea5d9a85e976990ea1b012924155d035f6b340d914b67873f28e8c11bae6512f2f352989210d00a2ed1a40015e4247b40dc6c285103e296df6cb0fa56a524a89d452956e9366c13e0edfdfad9265c8c83a1519a73d409285a9249d42f6beb3cd86ec769a75dd20ac702f8a1b9eb939d64b86cadd8e538f68f6ce23ba1e742262e1a9b21d9325f428b511bd7a6d453e0ea1f6a3e013d639587631d37f3490dcf84852565c41d21c0a3c02a1eddbc91b58b1d07c0c17253eb01123414d92d9212a00834afa5807ee3e9d3b64e3227f6a3290ad0509db4122cf1ffcd7cdf4d29a213425c5a01031e6a491b24e625eee253f0214889885bda9a694b0a712d6af9a02eaf7ff003d5465b78c918b4ca5c9684029210f3435e8ff00b76bfd457dfa93aa03acaf43c95056e3503b579afedd6f7a5b78c714dc278ada75209df6b03cd50bdcfdbaaa8e714ed7891b706dd798eaeb960ab989c7e313879edbab7244871909c7488ee68f41c0a4d952ab510a48a20117fad8eb86ec4d25f951a5b2c4e45a63ea0436013ee37c93a750df8af3e66380c964e465036a325e65c5d9d16424f83f41f7ea990ff8b62e12dd50752a52920a4a534a1ce9207f9f17d302c8aae3ef2269047c7fc405640e730f726c7d2f74ef88663e2dd69b6905695381206bf7b9b6e5479bdabffae9c26668c486f3ca6d2d4e69c2d7a2e2770bf09df837cfda8f5309dddd031719b95f9f2c4916e200512b4ab9e46c0f1f5fedd22bbf8b19cc92278c8be870e4a5264bab79b49714b48a042e8140dd4286c38e2ec9ed131b5ad6170ba06b3b2bda980bce4756f8ab0fe69b8731a97924210ecad41c536b27d34ed55b8bb37f3d76ef1edc970e1c5cb345a533223a969f41c1ab4eaa29201dae81df6e6e8823a8cc7ee798fca452c11b2836a1a86de413bdee39bdbe3aa4c2fc4a99270c7132430b86b5256a0e3692e20a4101209b346f7f3b7d4835b267b9d18671dff9f4558a49e19232dcf3e43d07d37f9a1ddba892eae5c58cd4c2a0d8525a71bb176050df9dfee6b83c740bf10ff0d26e03250c650a1b727456e5301042d451a425616923daab1b7fb9bab476f66138d96ccd622c74a0a82cb6b8ed90baf824123ee371d3977aab0fdf0c01361250b6c32020c76d65c0a46a582e1f702926ab8fbdfb43ed08a4d4d6bb2d17cf2f25d92a23843e591f623d3e3ea7c97e2dcbc79988ed1918c8df957a14c90dbefacc6429d6d480a080970da929d2be2fedb1363b11db665a6329f69c756fda832ca815e8dc594f8e2f9e28d754fef6c4b38acdb2d07e204b8fd371c5b4d56ad5a14ad41236d009b1c5d8adf91b2594c07e2c4a65ac6c0c74b67227f2ccb004888daf504e906b64f8d44836af1e33f2b4b4916b2efb64aea7d6dfed94c9fed096b8c5fc628cb434508906b48694a04a413c59d2adb9d8f346b5aff0fb2f1463d7394db48c8325f64b0b4bc420385b3602ac1b076ff7040fd1b8977f35839f83ce49d0d87d125e6b16a2969451abda29211ed038f70b3c52400c922576d38a7232a1ff000fc436dad51d0d3297548ab08d850009be0f0af1762ca681d50e0d6a5f0f6c4f33c43136e6f63fb18b10a2bdaf886713916df7b18425a490c17e3e91f03dc294a3fee3737c55716da1f267b7052cca034a0ac0d451f00d58f239e3e7a18fcc71f90cbeeb84b8d1d40a80a00f3b78eb6e2b2eea5b90f47d3a1c3b2b4fd7622f9ba3ff00cf5a98bb2cd33750c952a9a0940121b179c6e6dbf5e6b0671861e7dffcf169d724a0b415252556909d213478d86df6f8ea33ddfdb917b3441d194893dac94654971a6d0a0b6176a4a5b2a29fa5d03e4f00a546d73c2b24a1fcd21081a94bb23dff001b0f9e3e0d7e8b933b79bcbe11e85916088ee2038dd28052295b0160def7b7ff007d76b29d92b749167018c7d3af923a291b1782506f816fd28ce0a4c78fdcb0b29330b0f271da50714dbe5d05606fb842c13f00fdafe7",
            "aa17e3877b76cf744f80d623b56332e4786c1fcc2c3a161259410814bd2529142eb81d2565f0791c3ce9319965671e5d4a0ca52484b20de90bdbdb74681e68d6dd64671f9596cb6e478a65969c4a3d378a92da923feeb1693445823efbf59b31692411917ba6cd9406ef840312fa5990a69d52430f1014909d5b8dc0dfebf5ebd3231152b38a8cc90e280482a48dd5bd5d5ff9e9c333d9f94ca649fcec1c4c5c3facf296604755351413b04a94a3ab6d8f03ec360d507138dc5c6c5b2ee1172324e3cbfcc4d44e496971d5a50dff002f48adcac8a579dc9240490da592c04a086f3f25d7cad6f8c9e0bb761f6d6424312ff28c3c1b86d29f94a0d149651c0d43ef55bded7c0b0e49ed087320fa725f4870d971e00aab9d902ebc73f5eb46160e3112d32b1f296c87ce87ad2a4ab424ee9d8ee36041f240238e99f1a89b332a31686d8407dd0d86a5d26b56e35124d9dc5f26f8b3d3682670b861f05b63f7e3e6b3327684d2cb6a736046c707979fe943f2fd8125e716a8480b25c52dbb3a47a77c13c56dcf9e85cffc39714c1275b6f240252a48525563fd24106ac1e479fbf56a71a8ceae4c3c938d24dfa40a9600ae0d11cf1e39b1d699dda8cc5c3c79d1a4b7214e474a94dfb8fa4816129a35e37fd4df826c7434c27113f37fced647b7b44453085e73b7aded6b1505edfc7a71b07f2ab60265a956e2d2750291bda49db8206d77b1faf543610d64a07e4e5dc62e242482dea49d34411a85df1f3d75c6766318ac52327273115d53afada463d293eb3284253a1c2a3b55150ab3e2afdc13a14ec58612b71c502534951346eced5faf4ea8e00212c381b7cbadf8ad0b9b7690a45938d11f86d4e76785d8080d348aaf3bddd6d57cd13e7a008c54d764c82c04ba194db8af0d24a8275122c016a4efff0070e88fad0f31e936e3e12f2d40807751513c59e7fdff00b7452048c9e131d9069bc9bf022ce652cca65b50b793ac1a3befb8037fb704f58196a04a6f6401a9b60efc92bb6eca80b537a50b1f52169bff0000ff00cf8ea8b8d65d9f2d97204465df5e3fa65d741213a81f7136058fa83e7f44339569c9ae173d35b2f7b568291c11f245022f9fa74c784cdc84651a9ccb288b8d861403bee4815bf00fdbeff3d594929d61aeba8bcbdf6b8c80bf42768e2f158eed779a6bf34fc869d4212853412db8083ad5aaec1df6dbe3907dac5896e626638e2d09432b553602c715638e4d0ea75ffe69c01c4c75e17f886427a982a92d2a3fa286dd0b2000ad4404115bf3547924271613f15e53ebf4333050a41729bfca95292bd477000049ae2fe78fa12daad2d7c4337fb796df358aa8a7ad2d958e8c5cef9bdfcc647cff004a8b90edded8cc7722c4998cc492d203ce8552c2942eb6de9440238dec55915d26f74e2e3c7ce2dc830d5a5fd2e10d214a51f7556c2c720d0e3f7e8860659ee8cc28602756412959950dabd6da41055440d86c45fc94f04f46f3f2a3612320b0b756b916296b24d802d56abe057cee6e8ee7a5b2341f15ee42516960731a4926d6b1bf97fa163c54e8789ed157e61d86f2e4b69913bf36c213f977c29494a52e59b14b03902cec46a23a31dbbdb923befb472f924ce8511d0ce88ecc794dbb4a0a4a95a9415b0bb1be9dfe07325fc439b231b828aaedecc649133267f2efe310925b437a52a075936a5297bd11bf1b0feac583ee077b7ff0b2576fb89761661e5a50ea932d012f305d42c10848b0b494a8126cee773749ba9dd3c435c18e66cb55d9f4c58d6d5ee4e2dcbfce29b3f353a341d3978b1da29510a75a7d2b6d7a76b0413c9f17faf9e8f62a5e3a3cc5a8c38f39a7d95a13eb2ce9b52480a05241daec7fb1a212e3f77bd8f65975b8edbf2e3ada710b90da5c0169249d8fdbfb9dc103a3986ee8c231d84e44fe0adcecdbcfc82a716d1683492a6ca0a1495e8d885268240dfe01d7aaa6ab7cc3bb7826fcb7f5e09dd2b9f3870931cbf688a8944331d25246c0b89f342be36b3d67702e5440a5364b5fd3eee0ff00bd743a14a9290dcf9fe9a356a0845fb52907923cdedb6e7cefd3b6166446718dbb231d1e6fa8d38901e59080a208ff0049b0a1615faec41a20c9aad9039adb5cb951356329266348f78dae91e4c9764639fc1a6428c192f21c7da754436a2807c5f8047ec3e011a7138a871a29734254d057f5920917e6f7f8e8ec8c4601ff00c8496a2ca8f2da67ff0072e7a89fe72c93ee490014ed5b79d878b3d09d2c223bacb8e362880b24ac7d4f530f639ee01b6befe6ac92a18f90c4c1beff00c5ad3dbd172d0da4e4e2c77a3b835210b47a802a8eff007dcf8eb646c4c2c7a196e3c36dd6fd4f51c71df7a96a1e77e2a8575d20f70e2d0eb2d4e8921d8a86969498cbf4e9652427729dc035c7df7ad24f427b1aa8a9a7d0e51b56adfa4b501f113248c26fb7a67f9bac8d6fb453b7bd95a4837000bede76f87c563c6e322685bad418cd3966901b48045f0686c3a5ecc4f90a9eeb2b6d2da4120e809377c1048f17d326424b6a8ed3701c28538e25097ef4a0155d593b0ba3cedb1e94738cbf8fcbcc6273cd2dc8eb5256b6d6169db9dc7ff7f3476eafecf89b24a667f1181c87451fd8545ed12baae76f848c037c2c58dc44454b2fc971d59365cbaf7ee2c5707e80f078e9af3d8b562590025c6b5360fa4f13a92956f62cdf9ff95d29e333f8191ea29e7c3c5a2aaf4885f07ca47bb9e36ad8df5bb2d9cc7e51a4bcd226a4b491697106fc242537b9f803fc7579745ed4d0c3cee984c19edec0db8037ff00cdbaf92f16b0ee65633cdb4b",
            "d1a136b56c348ea53dd3dc6b6bb69f65ef423488f290d223bfa8bef8215fcc4148d034d0b04f0b1c58d55cc63730c3973a24742d95da69d21416d006ed3e013f3fefd47ff14b0b0236331b96c102a4254af5508dd0df1be923ea05fd3a13b47b45ed05b1385bebd7a2399da61d56620e05a703c8dae6e9dbba333f87ddb9da59b95d9f1633ad4d1e8a597994254a4974292e6950246e00155ed1c5a0698bc7931322de41798969c64a82cd0656561720ea082da456c4037bfc1bf252b69c8cf434869b98f36db6b0ea52859480b1c2801c11b6ff004ebb49c84dca65ddc9641e726cc7d65c716e1b538a3d63c36caca4ece14ed70738b8924dc93b7244e16261ccc8a203321cd6f384208d2468ae2fc1bf3c50ea898deda8ade3ff0082baa6887d1a5453fd4a3bd28dedc1f1b79f1d0fc076eb1897189728bb33f32e04b488c9d68692a1656b5102857ebf7ba1ef8fc1774f7564f28f622639162b0f08c08689054ad54011c1b4d0adff006e8988b5b7d410b35407970d76681b9e682b58bc5bf9593856b27160c48f1dd5bb2de42f4075085522d215fd45207c1276dfdbd74c4e41c99882ccac7194d369fe6cb6d275a05f27720fc5d0fadefd55f29d92d76c764c7edcc7e04e67b973af1881a6d256bd690a55822a8a473bd01a8ff483d08c5768ab03838f09b69f6676456d894d486f4fa2b360da763437494d8af9dfa9c2048f19b2aa3af8a666acfbd604f1b6e505c34a7a03f2a62663d140692d3af30145296d4082a510084d8247babdb5e3aa2617112bb9f1f2b2d2f2e23b1059b8e87916ebd6af6d694e917a9540df8db7b06bb6fb6b0984812b1b3e746b9a94ad6d3e120ae8d0241ad812001f7f9e8ee0bb5636270f92697290ca01493a8aad49484a480471e4fd06dbee7a15f2b9921b6eb2757daccef5fa07886c4ec471b6ca23dc1364c5ef588a69d13188c9002dc503a6eed037f8038f93d1a7178fee67d316416da0095ac2dba50fd2fc1fd075b3b93b1d981904baa9ab119d797ec20da77bd944fdfe3fbf58d9c5e11c94430e697d2a03f96f2b723c9b48faf03c75afa10f91996eeb67452b67818e60cdb7b2092f06f626534e3ae8921d51f434936a3b583f0760478fbf4d7848ee49c482e444b51d9f51c28d256b525201fe9b2492a04d7ec371d7a468b8ac8609b2f34f292cbba4a890541c48dc9e45edf51b578d8cf6e64914f32fd4e5a1b0d2d684e948f6821239f9dabe77e7a9b209187da23f962d6554ce9c33bf60f103f4fb6cb365e66319c04580c63d80f3056efe65295ea7c2d23db574782680f3b51bb2efb129dedac7e5db89a21be0b21e48b492820900f02b7e0ef4ae4823a253b1584cb621796c8b6dc10d203819503a9df781a4148dcd7cfdfe481b9065709063b2a050804b62ed009005d0f242520fce9fa0e8aa79bbf2dc5883c73eb6f9aed2d5b6b746b6d9ede79c8c1eb9d8af68f9f7f19ea9c63719c73d25a0aa432160ea4906c1078bff00cd824102889948e51290e392a2b9a92b6d1b927e686f5c71f1f6eb6476d121bd6eb4ab5123d3676deaac127fdbadd2984468284a8175674848aa20defaacefb5fdbaba6eeda3403673be785e9e58e31dcb4d8b8f1dfe9d724ad2e76763c092a4a0d93fcbf55a00213a76adaec11c1bbb1d2bb9decec6240f5253e9d69285283600df50355b9036e781b7557cb63a4bb8f8790712cb8cbf1cbe4b6ea56529d7a2d612494ee3cf9247208134cbc4892c494a63329568d6a5a9344002d45407000b24f802fc6deee84b0f848f3be76eb8a654f13248b4bda3cc2f986ef37d5859b8f7b26e4261e21e763a564a545362fcfcf3f4ff00b4759656698ccc790e2e42cc06117a6fd30eaac7b555bff4ebbf9dbc12081c7c5c214489cb6dd70978d25636fe902f60761fdb7fa75e9898b11b82f47763fa4890a428b2dee4f9009bdb6b046dcfd7a19ad90c7dd922c6fb7d2e8b31780b2f843ce0f26ca9bc9c65188e52bf2ec6b012d240013b1bdcd91449276bdba1f2bbbf2992f45a92a71c61a090f36da92da4ab8dec035f4342c1f1cb47724c950bb61d2db9a7d65fbc25360115a46ff048f1f7ea5331c7a34d284ff25494a766d6689201b3b9f1b7fe38eb2b524c32398c3840c2c3239daac780555c4fe22770a214c8d1d4d498c96c34f21e742d69045152024d2bda08b3f6be475f637768898d8ec6621adf865c5b6ffaac7aaa2156a3b05d114ad803446c76bea4b0b25331d3933213c59793e520511f047046c3ad190ccbf3e42dd5212d8205241b09e3e7c5dede2fe9d08e70736c552fecb89c6da401be39afffd9",
        }),
        Lava = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc000110800c000c003012200021101031101ffc4001c0000030003010101000000000000000000040506020307010008ffc400341000020202010401020601030403010100010203040511120006132122143107152332415161164271243381912552c14344ffc4001a010003010101010000000000000000000002030401050006ffc4003011000102030604070100030101000000000102110003211231415161f00471819113a1b1c1d1e1f1221423324233ffda000c03010002110311003f00e2d45fb46c55c8e633992bf532224735f198fa51aac8cd1b147f2f20b128900e4a23fb11c06b7c2785db15b20d7203f4b3732c1631c427bfb01fd7f1aeb4325a8294734951d2bd827c733a30126bd10a7ec747fafe75be8fedefcb8e6607cad56bd5a26121a6b2988dad104c5c80daf2008d8f7efd7bd75c7b21014a351953b7ef78fa64959504a4b1bf2de91be8d79b3514f4b138c88495aa4d6a662fb9248e3e52336dbd0e29fc281c827f24f48890011d5d1cf54b91de920c551c5d2931ed56786088c3106df9113ffe92484c89b0cedadf0df0541d47cb8ebf0c3134d42789657e31bbc6c04878ab686fee78ba1f5fc383fc8eb24ac9242836f7ca0e7a28920bd32d8fb0635c55e79a26748c95505befa240fbe87f3afb9d7d87be9cae7445dab0e2220daf24de6878f18e40e10ab96079338645d0f4abe25f44bbeebf01dbb4e2cb54ad164eb51bd8d927125bad34d347725899a48e6468497e0001b6451c02172413ae9749daf8b9ce45c4b042a95ac5a478e57822874ec23012caabca1b8140aaecfa756d16478cceae2a52d4ca1415f5d8c7ac37fc7992d2149bc8def9f507178cbd56ce2ad64f2470d1df01aa589d1d4720c8b1b31d7a45da3efd80aa4804e8117239948fb72bf6ed0b16a4a505b9ec149bc9189792858dda1f2346ae177ed7d8e4412c00258e5b1f80c55235db2272d90ad020107ea345583acbe48c90402e92c919564631b68b1df22859cb72be46a54c44c7155ed0a912b39895da569a0d868d4c4aa9c54c6854153cf6ea5c9e48bf12a16438edc8e6687df93c4bb7feb14346c6b4ec5c6ef8e6dcb97dbafbadf785817a516e389258cf85842a8aa0a00bfec1c4fd86c8fb9d9d9249eb0314edc256858098929a4d06f7ef8ffe7faebaa0d018e4949721a1c76ed5a2f97826cb44b250449e46462c3cc6388c9e3057da963c5437b00b0241008ea9b0976f657111e38d1c65caf8da9624803430878938b79179cc031e02696503930e65481a52565f0f89cbdc9d64a345e55114b2b92446a6258e4693e6da00708e5fe77f1206c8e9ef67646db64530582a15ded5cb0d1c5358705ac46e388acf1c8de175693c6da2a0f21be407b5e77141c2882e47617d748e870e529212a17e7d2b75d7c1ddd35a9459ab388af25ccd607b6f8cfe0165621561696249611f2701cc9270675076c39805493d6ccee3bb3ff28c7cddb17a68af54a4275b090ccad2b198f8da4d2058d947e9bb2bbaf94c41743c8c14e053b870ddca898bc95386d84921758ac249556becbcab24aac4151f161c4b11e8865651d1af833dc32d5ab5aae1abdab365ac07a479a942ff00abe431b958923431bfb58d5579fed208333041482ba0c41bf371dcb8f6787d852d2a580de5e7d71d31ba660bc600a992c5d6bf24b13431adc124462db7c650e8c85882580e44aff608034eaf612dd8c6f392de32e70011a28240966158a04fd5f1954e285340961b668cecf22a4e76a2b5db51cd59fb7e45186bfa92c5e866a765c4f11f1c0e11d5823aa48daf4740e99799051f6ece8d9dc4d6b569e9d48ee24af6208cf92104af293920e642aaf2006f5a3ad1627aa8bac7888c3f7a61de1095252ab2aabebd322ff54be3a2db74cf47264862a1c4d5b94ab53a535ab362084490c11ab490f00cb308da0963dbbb11ce12dae0e49781c962bb6fb6fb8b112359aabf42eb0abaa2ceef32c7ca095c37055de832952480012ad1aa04797b389cae472f92af6ad3645da79a6af8d8d628e5088eb2724079a8746959ca970aa0ecb072615157334f3fde5909fbff00217ed7916558ac451098c4fb62a02348aa91ecec807d0040e25b9af34492b4317b218b55e8d9dfb222ef1049649a9b9fd30bbd4e57c7981cb65234cf64f17464acb32aadcb9034c0554925f68086e015ff006feb07d9035ecefa633dbc5d3a94f1b87cb9a4b91c64b0646392491035812bc9b729cf484148c02764c40c81469ce95bb906c1cd8ba794b5571d0d8796b63f4542caebf200720ee0c3cc17e0da278f15130268b17de588b39039dee3c3fe7b5ac4222146e23475eaca64122f838ac8162568b8943a6224550acbbe9b34972a097d01add4bfbe4fde0529525243d41ef9e9887e8f5859f86a7b7ebfd656eec5c6cd5f235debd35b32aaaa48ac92727219590303c43165e45590b2804857dc14315dab7afe2ab7d48cac561964499118d4552c3c42557e326f639931a13c005f8b1e98dd932998ed0a7520b391b42bd635fea266411414639d98c4ec37c8067aac03152bf10178946309626b361e691ec99b80d1",
            "76727637eb5cbd9fbfdbefadff009e9f250664d54c2aa1bc614bb96b9e709987c34243545c6b9545f86e915186ef71dbb23c989c3c11b23b9499b6cfe3642acadef60eca90ca410392b7914f1e8aa1672592ee2b3989f14f908679434ef46394576529e29620a8d1b48e0da8974b2a862da3e4f2026570b877cddc30099e348c7397c51795c46365d957637c50337b207af640f604bb2d78a24a298f35cc7a691cce5e491fc6a3d91f0e21b93280bb01c82cdadf4e322595908ffa6af2ef095ce9a500affe4f6c9a974118dc34d98ce8c6e1eb64721034ac50d7a9cec491027d884311cb88278862068fbf5beb0cac1845941edf6c8cd1977726ec688ca9b01174a58311ef6db1bdfed5d6cf4fa5dd7da18bfc22c96369dc6bb9a324d34d13f28c4819e489190bbe90ea657658472758f8b6d0bb05f967ee1ca76a55ca66a7ab791aaadb7b70e39d98aaf863114d6044be8473004abca432a86e2486084f1530cc752583b07a3eacddaef8f0912cff0016aadcfd28375ba02c076dd8ce58ca770cb7a1c5e3adde8e2829c9206b16da49a3244704518330459549e08a3e4388fe3a552e57ea33098a7c67d6d97bf332d8b45a592c09d42ab3156e4e437ea26988e4c49e7b24ba6eed6c6d7e19b5c74f6f2039bcb0e35a0b74236e7b2aa5238d849158629f261c4467e05538cd5a8adc762cd9b78c188ad2538eed6af714acd7223222a3c6ec9b91dbdb971a040978e87c7af4b4ad4a2562987a5313d7c833999a84242029eb955b1f3cbce3cbb6268a6c9d4c3d8b192c41450ed2c01847e811a27971e0dc955c104a96d710ec3aafc463e3ed5fc4399668ad632ce1448b24d526922951e42157d9f7222c6e482aa9e425541dba169580d0187a915a12445ed0b6f621648cf8831568c0d69a400865d11adb020ec6bdb50da18fc4f72c6d2cd8e89d2b1453ea293e5b00bb4a11dc46d21e5ad17daa7103a2989b62c3b02e399babd8ec55c0842ad10f71c29cb938ecd0db293b773772b5bef0cd117ae2ceb1da9a6575470acd1c6c35f042edc031f8a7f9543a1f2dd8f92edca72646fd5acb5a8de5a2d9013f96bcf2f8da40a23e05b6540fdc00047175dec0233798c5c99eb6f62ccd79e8628d082610a40b28f00af13857f9b0e3c1b5f7f9330f49f29bbf623c8f704964e4d6117252935991e43b0dadcb21d3336c925b40b1d1f449f7925331921344b5cde973533ed033ca12e4351a94d9a86c29a469c53516c8455dab19e221c7091b8f91829e1a1b2159bd0fe744faeaa301dc187c386c8ddc53fe755cfd2d8862ae045256d85939ea45659195994ba71f510560de691ba98cbabccf8e8cc7544d1d448dbc04976d6cf297d901803c7d6b4106c6f64efa78999acd6972cd2d5a93c8a82f48ad22c69e8c8ea003e4e01d58aa9de8fdbdec513508989751bf0de70949524d903fe4deda7d67da1a3776e16e9b306670b6af2cb3f923b31595af320332b313a46e4782950189d19246d9246a557735b1f4c1e7724b1f20d9935b2763fe3f8d9e9edeed71f4d47255e78aa4176ab598a2964691b51911c8dc9575c4c8b2f1504b009f2f443333c4e1fb68f6c5eb8f53219631d78e796da40f1478e97c7647864218a1579457d3120904e806daf5895c99282a43f2beb7721bc6017e34d583371c77f11a707dd55a2c05eedd6c250fa8cacb0c6b909d55969aa4819004f1b12365f99f6cc0a8ff0069e4164a97d26465c53db69a6ad39f3c4cde550c3434afb0256577941d00bf125598313d17176cf72cd90bb9cc68412d213645ac63a48d6387c5e3919a3788841c44d19e29a2a481c575ae88cce731d8985a8f6a48a0dad7d5584405648d77e38be5eff9dc8bae2d222b2ec2a374b166dffa6a4dfce979c297670c415592669a06eda7dc6acd8c21a7063eb642cd7c5d489e58a08d229d8dd65446624bab08e4486272c390427885fbf4152857078cbb57b8686468b666bd66ad63c4cbc6b19964699549512ec45a55242b124f252836be9bc191cd42329308e39bf4cc8abc1633c78a121118f1078ec2a9240207b3bea9fbaea76f95f0e0a796ed8acfcd72465763763d29566424f8d8865f40ec7c14a860c7a23febb3254e5eafd5efe77bbbf78c12c4d2a992a8d8690932a6a8c3e39e8650ced6d0c572b587612c53a152ccc0fc429e402b03ec2904020ecf5edd8ea773d9a7dd960c8ece1dedc76418c860184a5c8f906e68dffd88e435cb5a5391c22d0c4e2f26645e37de630c0e8db92142bc24dab11f22ce9a04713130277d749ee0a574762615a9e7aae4f217ac4147f26ad6e2b923a992568d79a12dc7f4a152a3e2c426fe69e95366d8094a1545121f1bfd99bb561d2c0254b9d7a5986f9bede11e27eb28f6659a1729bd349a5592948f7278da9c93208c4a61420b878c1258291a65d7a2239363c585ed7a587cac364cb34d4a0b61ab4c55602b3295280b093cacf0387e2e02005919832a2a5cec8d66a09b1d79164bd2bd99a9c11b460491867f378d368a155caab20d7efd1037d5560bb67b76d5c8a6cd770417e2c3cd2534a56ae1fa7558c821d18eb9c0ecccdb063fb9f43f99a628213e22c9625d83eefe99df5a5328aa6786801db3a5d5d39ecc22c7e37b8e85b9ac9c650cee2a3acdc4c9e3104f147f7785980278312cc53dfc5cbec73eb5770e3f255aa60f08b48264fe80cd3d44a6a9661f94a1fc8e0722be38525db7a0927ad2ecb1ddc595ce50effab85cae7eae4a854f157a36674634a3ac51151d22e257c2404660aac1b87a2e0f269e229dcc95178ec5b82dc92886ad",
            "111099c43c5560e52211cd8fd8a845de8103e7e9f2ed922629ae7a03916fba0ca262428584937e2d4ea5ba57ede4eb8dedda342c62459c8d2c8c10b3c76ab69659f8959947b0480de540eba2bb210ec1919463b0182931b05ecae49d7ea91d9618cc31c8240660badc87e1fa60b6d43eca2aa90cac6d97b471d9bc8566eca91b26b66f58a09523b70d7b56556366660e542aac90863cfc6003c91836918cbd4c919af65adac12471363e4afe2b73bf92081d0c08de555f888c7894e829915447a2246565cb9a54936097c6e7c806f7d3b14c4a5d200058506f1be9b2bf107b031f969573272f7e340ea925711204605c06e21c87257c6c0870aadbf52a8d36fc86566a1527c5dcc7c8d354b5cd8dbe6f2d59c47c65e03e29186909d8d161c23dfb8c6ceedc14bb72cdb8ef3e424a76bcb1886bef654c1247e53c5c6ca79800a46983b82caa4ececb2e67f20c8dcbddcc6ac91d86825c3493bc05e558e389cf88208c15f215d311a4475038c64062961536ae416bcfa529ac79329725241a1cbdfd36f113997c3dfbb2dac4c1629abf8638ebccd1c8ba28439691563556daae804d7c98ec71d1b2ed4edacde73b76c4757378cb233b65bff8b69a2b17a7b114533c32b2e8b420b1914b9653f225870f9743c9da53e170f5a3c9cc6b4f7aa4777c1603466c566f988a066898472fc5c9704a959029209646c6bd3868d097b9b056bc3957c959a71d10cb204ad240481e33b721d5a64e6090a53ee09e40a64d0b976251e4487baef3c6bde10990bb416a179def1eb0d64fc36c44bd996f358aee0a994b61803125b113536f0f94a32146fa82ccb242be3700b2860581758e6045691d71995c6ae1acad77512bd5fa67902724d9d8df22d18462a07fdb6dfb795fa717ede37b324a190a77e9e5fb8e26895a0679268a924691303b0151d9dc49e833041f63cf4cb8e4e7b5dd94562af86c4c39196a359f1e3bc491470af12aaab1b7212ed1c1594b16e68a14111ed52d5359d65d2713423ebb7b934a109986c5541e9ed86eb0abbb25b1525fc85279f234712f2d486cbdb6b55c386fd43012881469a31e87f9d9da719a220a96633e74b4aab1c9fa6a74490ac50f351ec6ca9f446c1d721a268f2c96f0f6718e5abd66bb44cf62ce3db4b3c66465d69078c6bc6000a0e9bf790e19535e6315894a74b270d89e9d89e73bc359ae5274aec04914a926b84aac8dae455093ae2ac0fab64ac252139f99c77ad58c4f345a55a06bcb79fc12207a34f037fba26af557212e3659a65ab180ad6845c58c6cca3e2ee3e27829018a95da060c3ebb9bc8c72c4b505bab2d6ae94e5b2d62467940529ecb6b8a95da0500011aaae890ccde76fe430f8d679ed5117e7019e0916592192bc837a238b007ec0ebf93a008f7b5566d433cd2c7593e9ebbcc580662c02ecf0fe37e8311ebee35eb63d984954c208240cfcf6d1e64a2505050b472df7ac5dd6a94333859fb966ee49e3b965a5a13459298cf3c8da05190aa9695444151b7c023f06e5c5b8099bd51fb7720b1f92b5b5758a6470036b6a920d904f13f2d32ef7f7debd1e81c6652fe2e6b35e85b68d2ea0ab398a30e658fca9268061ffda343fc6f5a3e891d31cae4aa65abdbcd5fab626cb4d6f8994714838855fdc557f55ce89276877f22642e78ad32d72d6c4ba4e1e9dab8c189a152e819431ae55d2b15fd97df763b6ed9a189bf1ad59992687f3260abe790c51cc5c2ed4a9e3cbe6cbc446086d17495077ce02dd0c8439692b55ab1656b8bc23a703475e32cfa31a6f6363d12a341492ba1a03a555b026f63ecdca527996ad7799d1496672a7d8000d83c03ca430d7089cf2f440a4ed9b10d6b74f0ad2656dd4b307962c7a4505c8e7befb8a37303f24886caaf221a465008e22501505299530ce957e233df2f78d3516169bea0e4fed11228db6a3f5be1615c3f0326bd722363d7dffaf7fe7ab3ecfcbd8ab432162f957ab90a53e20cf660161158a23460932298d87890a368ff00dbd283c4f1068e3ac0c464f0f7b1d616f5599ab55aabe412d8b923c71984c5c583140aeda0108620163b453479118d4ed1c6632fe2f195b275ebdf9ac0af6a9f96388a968964562089c382a57f72a6b4864238971136d8b045e74b99df7eb1b2532d3fd1c9c838d74c3cf1832e772f747e1d51930d5b2574e46b6a3912caf36c598a491523f9a323a30e0ca54f102494053cf7d738ed7b0c3bb68161ce4924f1c40c492289594ac44a3908c03153a6f8e8107d74557c9b59a7f995fc4e472395901ab52e9b463ae02449185e08819dd1594ec4a3db216046c335bb8fc6dceffb31662c57c5a4dc27b895d5106319d879a358bd86f1b33108ac58229de9c32ae210992952543fa502e46385d907c7d4d444c3356950b81e99ec5634ba58bb468e1b0d2cf62dd5b0d42b4d56591e29f7333a6b928d7b76208d7b653c11b933e819b54faac75ead919313569c95ea414ffe95659014dc96176e0920297d1276b180c022e9e63ad53b9d80f8ab17f118fb9879e6b315369268d6d011bb34adc0fea4e85d163d91a0a41e4bcb41f74a62725d83d9ff0092fd21c80b1606465648eb1f348620aaec642194146224f8a713fc32c9a14a815d850a126bdcbbebe4ed0c5ba5218546186bc9b74897c9e2aee1b3f1d2e266b12c11d8f10043149630e0301ad72460da07d06d1d1040face36d622582ee3b20b34f04c4f9e99910c122b7c75c955b7e838237e997d82081af1328ad3d498539645b24c73875e292272f6a847bd9008f5ef7e87dc826dcb9f92e42dbd7ad05fab3cd2",
            "aab596f4e0a0f92aa38655db0656de9b82fdf8b036952c2822f2ddf3847872ccb33174ae183871cf5db9d80eddb72d2c95a9f026c46907c252b31359902caeec9186da151e325c050d2a9daf13ab4c0673111cc732d0e4ed776c914b4e1871913c5341a8a426d2b823727c78151c4005cf06d7ce17b7279ac66d3238ccda62f2d4ca882496e8a6f6fd3f2267670b1b71d0d1d295d8e5cc8f23fee477cdd2ee0cb5bc90cb64f1d6122bb76a4134b5a4043c7cd651b8d51dd57882aa34b108ca8dac7071082b5d959bf27c58372347a87ef144a9a84a4a50585f522add39b5fe706632ddaa4983c7e4efc98bab2e33f3086a5d73f4cf3791d12775662342105d7e079044511bf21c96e604526744326791e1b96089cd8bb2301179902f918c61dc11fa9c8a027f705f88d87ddd36322ee19afe22c25aa33f8a282396c09c3578e38c2f31be684f1ffb7a5f180154b01eb57788c8633baae453c294eddb8d2c4f56281eb1a924b182e810b12a0827e3bd706505508e09b2a505292b142a04ef93c12a79425485d4eebabb72add0f3beb30f3d7c7f8f2d53236680459a68a61323bc8f24c2442f233c9c98b336d14c65823005b5d40457edc3389639df9e8aed8f20413b2083e8824fdba15bd1d1f47ac77beba327874ca458be39f33895ad569db9466eed23b339e4cc4924ff0027a7ddb590c6ae529d6ee49adc98749a2778a1209015c9200607fdaf2e97d02cdec8049ea78efa6781b95286660bf7048c95cf9551143091c7b08df25d29fb120ec03b1b3d1ce4854b22024aca6602ed1d2bf197318bccf7b366313258bb4721191143929ac1906c12b222b68c71132f9234e4402a4950ac148f47bba8d58a4c263ab7d7f6f528fea7c1905f31bb22c7e3526156555db383ae475c437ea15552a7ea30199992d3ff00f112152ed576bff51665750552590f18135a712383c17902cfa5071a0f57b57b83b77bc05cc56469582b62dd0ace9395fd63e4acf14acce088f5a765037a2acc4073c64c940929924174d03e7875617ddedd1b62496966840cae6d75eb4ef298bc8dec4f710b94163b13c6b24204c79c6c8d1b46437b0197813b07e247a20aec74bda0922760cbb09a3bd11b53ed5b4747441077fe47f7d36cb5ca930b26bd435fcacad1a89831543f756d2e997d2687a034343d9e97e3319672d7abd2a8d1f9669026e46e0b18f5f2763e82fbfbeff8ff008df612401e228353d3662198816bc341b55867898f2395b73e3eade5815eb4b23b4bf0e69146cfc3d0279305e0a3f925577ae93bcadbdb1e6fa0012436978eb5ff00ad6bfad754a3b82e536b54206b14a5459a1644b604415b919538a28055884f80f81e24713c87155264843879f1548d592a4d331679e8c26cfa2a5584850bc60803e0b211e9bf86f6082bb47f90c5bf69053830a29db3f83187d6d5ff004f4744d368afc169e55b4854174654531b7ae5e8a6c7cb43937af7bea8e8e5acf6ef6f2357a71bf9a3e71cf244ae52474750caea36a57e4cba6d8922524128022fc276c66f3596a7804ad3c13dde0f024913fcc146917438ef4cadc831213479310bb616ddbb6f3385bf153a168a51af5da5b36a957695a185272649049090b22bb07409c9a26f807f6a1925e266200b218e2cff00b8c53c32090750ddce5caae32880831e32324390bf9a83c73cc4dc91a50d621df366728e57cac55188e2c764aa9219d41db74d4cb646ccb73316325929a5e31cd24923095555d576ee9c989e3105d850037be3ef8bcee0c5dbbf9db78dc8e6b89c6868aafd5786110c7a7904522abea271ed787be0408f5b0aa22258044dc4952c09078b061e8fdf63d6ba7ca509b50aae991ae434842d265548041fccceb161364b3992a347b6637a1762edd8a7b00433aa324606ec2acbcf536c2ef69cfe28a534011d22b621fc8e9dda9138b131680cb1c3e21c638979fed72189f210df15f8c6ac76646e9751593eb57c734d0020a3bc3edf830e2c00d8e5b0c471d8def5fcf5598bb1262bbcabbd5c4e27358ea93c7e764a2b6619e257f17260ea0a83e555fb27226363b6d311527c1a279e4ffa4bfae71e4954d0e73f80ff007db282acf77622ef70d8bf669db971ca651132ccb525689f8218fc718f0ef8024854d31725830f8f5a2ddac1c97f2789c6559f1e94927fa6b464e524b5d049c51dd18a0f2472b02555958841e95d982f9fb72e59c8450e07117f251cd65a13561aecc1e68c169228da37712044607903bd1de80f64b34a2a35e14c64d51c5ea91066af2992755e2a64902318d4b82b22aa6b9004ec9dc72bcf62525ac13dfd7cf0e514a573166c1f20e4f7e5d9df086b85ed0bd2f6936625c53c3532512bade79218eb565595a1f1b83329e2ef257fd472ac079085700b103bcbb6d12cd4bf5abe42b9b516ddace2da9d591578856acec4b491f0e3b9250ac741dcf2908197e4504d831db58c958651a54b463791d064f9ba4558c49204f45666750ca1b831724860b18986edb8b39d9972ed7bd0d9cd35d8ead7c77e6095e451a1a93c4c87ca096641a742adafddcb5d6254428cd52d83b5d81b9dcf9d1dae784105412867a61f9015eecdb989bd225c75486ad811cd6e41c62d791a33a561e4e4191b68539e836d1789deab962d529acd2cac113e4a8dc461e9574a838347cd087e238c61554e80048d7dfa7f9acfd769da2b752278a9082048694f3bd4b6912fe8a9e6fb11368be8e9fd7ae258b29953338c82a4196b38fc33e47254ec86896a453c7b11a4108657e461983472ce4aa92e648c1f521e0626cd290a9897db",
            "f9d74baeac316844b21328eea2e2d77cdf09ec51edea10d780c792b991fa44f72cb12c31592ec4af05e65a2e0c843725d90cdaf905017774f39ee4929490fd3c98f8d68b278c23a941a647d0058ab6d013f65551f603add86ee3c95558b1f8ca10f02ef24a95d3c735a531e9a279935298880771ab00413fce88aa83b531b0dac5d59b0b90872d684504d888d5a5b257c28d24c889c9f440762085e3cd9472e2c17ca5f82bb536a58edb0f4d6090813505086097773a6adae91cd27af3566512ae8328607f83b50dadff00c30ffdf5a4100f5fa37f1230f8dce57bf937cf2dcc0e369ba619126588d93088964f03c89c1e25e474a1d9dbc5e8b172dd7e7ca38db996ca478ec5549ef5999888a28a32cefaf7f61bfe0127fa00f4de0f8c1c44ab6a0cd7e9e9d624e224896a0105c1ef03904ebac801afb744da827a4ed57211cab3c61a358cb6bc4c1c860411fd87f435ecef7f71d33c3e22d67319966ab8db5765c6d516b703e9628c3aab9281097fdc0fa2ba0ac4ec0eab54c094da3742822ad8c63429e2f2b065ade4b30b42d46a24ad0f8cb7d4bb13f00490146c8db16f437e8fbd6fc0496ee98a907ab616aacad1d59a37e453c6ef2306453a002104b9e239027e2accade3a56bb72686f9a8d87bf8c708f2cb1d885d25660e8c4b21d3b213c5401f00afad863d147bafbd3318f8568d18ec430d886797c74d6672d14612ba480afb4445d81ae24c8e4ef96873d7314b06c8fe73259b9531e78e11d24cb52194957f5a55c3bd778691373c55476e5882a600d8b104824b3912b36eb47fa6a1480fc176e483c97eec0027634ef257a3eddc6e3f113e331f66ead23c587c66a72bc8be4f3461d916753114074afc0a9701b8aa26c7d8c4548ac4f61af57b6d51cd7fa641c3ce5f4a76c7d2842e09d1208f5ecec2298bcb2bcae76f212cc47ad9277d3c4ab65957038bd7ebcb489d6bf0c85a0b1c85c3ef6f91b36644799ca5dc6557a105e33aa44961cb431481878f9fa2c34c01dfee0347d120e199c0e47016618afc3e31623f2c241df25e454ff4410caca41008652080474c694f8bbd1478ebd1dc829c1158950452c7b7711b326cbf15f4e4efee4a90aa37adf9dd37e3c9da9af7ce679ac728e412bcab1c7e353e132483948e9bd31f43609058382092a509812030c7da01684d826d3e54efbeb15df86189ca77550c876e9bbe4c6c0c2e0a365b8d7e7e3914caccafe54d0d0f8472a9628245d6ba2bf10128f6a5dc963b0996bd42ecf2246121a71d487e956165640e87c9207dc7ef8aa3e8f3690a2b2f33cacb911256ad7af496962ad0f88bf3fd38d915d50730080036bd7c4eb6a48d120991d91559cb041a504fd86c9d0ffc93ff00be9238452e778c55fc9ffcb79bfd467f9004b329bafb66dd61c61a6c9d3c8437a06b90f989816c42c519b97c59558fa3c86d4ef6344faf5d3ec663719919aa64eaf8e1356232daa522ccefca181e462a437b46110624b29532305056366ebdeca183a91bdaef0a2b6bb75de3331afe379c3061f003c88ebbf5b2a490a58000b6c26b1dc3629579b1f4855123cbe46bd0993ca43c41258793310d1b7b0db077a3a3c49075655316a4cba1147c3f47e5f140b32a5a54be6c6f7f8a5fd308bda7db5468e3f02d3dcc6d6ce8a1f5ab15892b184472891e20ebe3691a4e05a53cb7c5446aadcde245faedcc654bf2de38d6c68b55658a88f1fc64aee675657427f51f99f7c9b6ac01de90219a4a183bb5b96369fe842f031b064f0d8b11f3915880f232c6c42a965024d15670ca8197afabdbc2d4c45ca59dc9771e367485df195aa949217496275d3b92a74db879155d3223aeb6c38c2655a249249c9ab5d2b9e370778aa5ce32253a9208c32deeb15188af7d3b716957ccfd26471a933558ad25735debdaf156918cc1b6acc48849e2ca8c1b914d3940f2890775de97b72d774e17219d26795f2d72694472c88542471d9609cb9247a0260e8000564dc855435b98ec8566ed7c0364e96332f3c52c55a493eb0735561af1c6839ccff050404d300accdb32240ab59c664cf96278ac57938c91480a90c0fb5607ec763a648e1cad4a53b28545063ecef4789f889964849b8dfbe4d1d1cc199ed1ccd8c3cd3dc9b1c6176b54abd86ad0b3ce9a05a253b2555ff610797009ec12bd4dd9c6f7076464a6c7cd8e8dee9b4b0a3ed6c224f1324863d2168e471c939237351cf4472008a3c377658b398abdd590b5e697172d79a67783cc4f17465f0c25a30c448a8ae4c9c9bca640a4867eb645914ef8c858c3398ad497c22d7aa5c4328ba61091c90991cc6885d2289915b4c87e31a848fc40854c964f8a0337f5cc796bd81683e20cb517934fbc07481285cc9f79637334a9528d61a65b32f2cf31692027c7149e0550b120e4fcb8855d28d024a26a471592a94accb34b5ecdb97c8cc4998a472c6639159240ba7d3170095907c790f64822dbb832788faa8727da33ac0ff431d7b14a4ae862b31989659242562552166e49f2552ac9118c8e216291cd57c68c9a478da365a12bc0b73406599872fd30a08e0a59401f22c06f6bcc2ad1c3b10536581c3119bc2a605d90a3520faecbf687d5127c3f6757af351af42d5eb057c8f2acc92889df93588cb33d79233a546544254c80ec31ebdbdda98fa389c2e5b25948aabe45e623e96177458e36117904818c4cdcd5cf1570072420f170001dc10d9bb9582ae7ae04b55a924704ce7919a3e7b8dbd20257831652fc3518503d2a86abed2addab95ed2b192b993a58cc9d3a5a86b4b34091dbb35d8b01346e46d6",
            "58e48d175f12c92b3ab11b74cc5a909135ef356d6ea97a7c350430594a84b22839e59063bc6b117dd7769d8b2ad49e2e126cf08a38a3f1a6cb2a3788056219d976767489ae234a19ad0c5dca549bb4e6c856cdac5256bd5eceb9487c118e312c5187dc9219a30a39b151b728a58f4bb298f78eefd6e3e594589a35b53c96aaa53100911082880e802cefc428fda14a8feb7b64a2c8770ab14a786a18d8471af8a9fc0ce137218d249198b3960e79b33e89f8f3fd346a3ff0908c1f647a77e6b983fb2a5867cbe7d7b41f129ee6a784ecdedec4fe6f90af2598a3708409222ecf09e44820832ccc7f603b8f9ef86809354b7db35649a610e520bd5bc4d24747c9010ca79912cb1802642f169e356f527a71feeca9c39acb672959c6dac6e36cc751ac19aa068d0c4be5796591554fed41272403f68088a7d2f476772951b1192c38bb11af0434ff002eaeb1ae8a9058805013cc795f6cc4961e89f4a0a9d416102a0d48c6a6a5fad391ca1c25a4a54a51623b5c48f46ae99c20af9ecf64f2b71ab4325ccbe4663334e91b4b61be1209100074c8e1cf3041d81fd72de17ed6462c858479ee439d8e7b51dde137c3818d51c020ec9204a1fd90cba1efdf4bea55c5d8c75c927b9621b911430a240248e404e9b91e41935fc10ac09201e3f73da3f0b72f8aecd98770be43076f1b559aa4ce918fa9891e52cb2856e124accaad19f8808b3467e7a95159c4cc4f0e92b421c8a333747f6cf5a44a8b53124289cf7973ba38e0af6eef158926b5322492b2247c8a22f2776f5bf8800b7f43e47d0f658f6ef69663b92579a9d299f1f5c9faab4a3e1080a5b458e943301a5048e4c40dfbeab7bbaee027ce4d97ed08e2c6d989565c88178da782559d58cb0d9924e534858a6da3e3f63c59d4b3984bb6619a79ec25586a4113715820564425bd94e4db7214ebf712788f6dcbdb311357351fc0b24e62ee80f6aeb1a10970b5d6ec77845353c141376eddaf5b1956cd979d3c99199d960a71f22abc5c90183bc520e5ae28bb04bbb2f8d1e3edcb888e3cac16fc36517c58f95a2952483f51984e8ca42fa6571b25f5b3a5246d5d55ee19a2bddca6a4b2cff9a54e1299ecbac51a18c97fff00d079ba0da45cddf90f8952ce009aee4a747177131b42fa5c302b258916092122459194a90e013fb43025411cf89f6bd04a0a528a178b1f2abfa60fde0e629294da4866d75a50727e719fd6f6ad9a7485ca59082d560e27781d585c1b263001d78481a52c7cbf6075e8ab1f94c9f6d5bc5d0181c04b04f51384826d4acffaacfca57408afb05547c1481b049e2a7a97ad5a29a3b12cb3a462142dc49219cfd86bd1fe75fd7ffa0d7c26662c33e4a6c3c915484c51195d0a1dca8f346c0120b6e3463bd11c747f904d4a968043a8d0e79fefc6512a26287f440a8d9e786de09ee7cb63721dc13b76ed296860e1918d1a52bb49e14dfdc8666f6740b7b237bfe3400b4b0d36431572d422512d578d4a98fe2e5cb0080ef65c951a50092391f4109ea8d6b616b3245158fa3961dc394c4df83dc73c4a23128771fb5dd98f120346792e88d125768c38fb1f88351be95acf6fd4b0a924961923860605b83f2d88ddcac6c5430f99d82afa3b419fe1cb3601fe4637f57c4e6f57778a11c3db095a94ee59be34f8b9a16552c7b3a5a18eb094e68e099f222dcaa5a72658c88618f459085815cb7c49d3027414303620b8b153af7613171a8af12ce0c6cb1b2bc81c0d6f89fdc3474436ff00dfe9ce7307728e54d174293aed2adeb32f37b415490caf1725e4c542aa0662a7e049e24f4bb2f7f2f82906032bdb15b1962bf132c166b38773c235e4448c75b09bdaf1df9188ff006f1c96ab7ff0c5ebf7aec431494ca3fd92cde8d46c3cf38f26ce4390cad9af99bb3352791b7696ac734f200380670244567e3f2e5c892c06c9d93d006b62ee4f8cab444b5ccde38a6b5689f1876201255549014efd8e459403c54ed7a7f3d1cad9b95fb81e1829e42181f2d66fdf9148b727a9c3b42e0fb633428838f17d83f6248ea82487ba2078a2c359a98a8b113495129cd0df92a5a630b4114ec23f2c65c575894337265f1c49ae2dd22671224d92814c588a74c5f2ee040d854cff00e872bc60727fcd4c4027642717c62770e3ef132c50ac30b3d59252d1248cfc6689418d413fa8483eb6da56d85ad86eededefc4bb12e3a91c4e4f15685976a48f3c3417929e6400ede201d7d3063a3a3b3b0683b973b262f0bdaddc98db51d79ee57b70c55214853822848bea0f0d962d22c8a2460acc201fd1260f1b909eb38bf7abfd6d4918c4de4b2f1b10581902956076cacc8490c3521f5bd11e91e32d254a2082086d5d8e430cbd2ac9e6429a5a0b906fd39fd5219e355e4bd432166aae4eeceec9056483c8d248645000420a48497d8403dec923d8dbeef68f1b97af1da8bb3d3b733a631e7ad5a296288c89218da058b4c048b1885c9da01ca40c0b14ea6bb91a1af2c1512fd8c9548a331c4d2a3c2bc9085122ab6fe2c8abfc93ad7edf4a3386ebc959f318eca490e562963ab0c5f25904528939112f2d6d480befd91203eb474cb0494ce14ee390e5cc46ccb24996ac1b526e73cfaf3867dc19eb596c8c9dcf939ab599a4b93aa5710c72578c7c5f92207247ca62dc5942395db348c5c753d8b928e0bbea29a696c5ca98db6650d524e0f6044c5940747fd30c546dd58f00792f2200245bcde6eee2530d91bb7ad63e0f8d6abe66011d0704da7c802391d8f47e5f7fb7532b2489be0ecbc8713a3ad8febaa644a64145c2ea658443",
            "c410e045f64fb9ff0030c48a305eb15d1249f203111d7f15186477e45611cc931f0f9a860bc083a04b12526633e99e50b62296398cb2491859d56bc3cfc402ac41004016323e3adfc3ec1346758828a000081af43efecf588df472f85420b8bc7bc0ab89514d8174549ca9c76431b95a33d9a59a8963633a32c51c40724015631cb5c047f2deced8e8ec12554a589b55e2a57ac0151e492659b1b5fcf3d72c74a1b9700e84440056742a5f97af9066df87bd8c7bd615896692447b4b4ecbf8cb0c6f90a786603c89cf99491081be2b19de8b2b2a7af839703dcb7717974692086b34d2cb4c093c91b46b257652636318919e15e4ca0ea5e2c07c87521992ca952d0afed3b1f435c8d690ab40158749f284b66b64293352b5e48d6391a231162155d5b4c083f63bfb83a3effcf4ff001d93ad0d4a3884867ca550d24f6e18f68a3efcb872571be291b19380fda01521012dabe45728b3e5c632960e0b19235e2c8c370577a292ab1313ac285d95a32c3c85083c7d7a0eac78eebab90ab6ab2d9b2b8f87c36e75b15f50c5655bc6b2af85b51911b08418d002814845745701326a942ca9175ec71e8fea0bf787ca400b0a94bef9637d3ea24ebd0eeba99e824c3359932324c161b18f6612ab7ed0071d3c7bdfa042ec6b5eba77959e27fc4209dc190bfdcd2d586cd7bd2d8492fc9098fca098d4cb116450be4fde02073bdf120d276a66274ee1ee0cf76ae3de693198b490ff00d5a5756acb13f39675838ecebc6dc11cbab7104b90c44ce5e18f31999e3ca770e5af411e41a386e68d87958c617947173659246689176251bd2ec91ed5026a973485866178bea3dba3e504b949292a925deb5c2a77585b77279bbb140988a7150825ae638e1aeaab218cc644a39855692325a43a62e514004e86ca6b58c84f6fe26ed4824e739963b361ac031191587c154a2f12a8c8cda7906a453b53b515f96c7643b5bb967ab7bba2b4f2da78cdfcd53e76598390c543c857ca4aca8e7ec182020ec375393363a7ed2758b0c66b51e8fd720641013a610801d95d42ac8db203edcec809f2aa4cc0c0a052976af7bb7ce2d584cd956c02a776258f7a639e1a4078ba8d6b310d5c5afd2cf6662b11b93205f1920a7c9954291c4ee4d81ec682ebdd9e60be2e5822bb92b953bb0345fa771a57b104b23cab303c97d0248b28478c8367ef2150cb3797ee0c253eec9dbb730b362f11288e0bb452f09c5854705d51d83808e555b44ca03004123407b73be6cd892c4d0b64eac97d5bf30f0dc8d12ebf882a17548806024323373e4ceae54b6f6e7572e6cd2141346c59f91bfdf9b12c944e44bbef04fc52ef6eb1b56bd6c7f62ae5f24d14f35bbeb0c50cd189a69a18cb3b8472dc55032c60c81093ccaa9d091588b3dd5da0dde35f25daf89b5da1581784886d99428d2f8e56e51b9055c0725764705e215d7c8d0b6ef5ebd2bc976e4f65e495e7769a42e5a47d73724fdd9b4367ee7437d0c143baab30404e8b36f43fcfaf7d5238405ccc271baeae98f58995c4924148cbbd22d5b31ded9db6d8697336eec72848155d394b38919e44709ae6d23f91c73f6c44dc0b717e248687195ec59b52e0e534f238ff001d5b1656555e6be30f6805721c92acc51982a34c0fb0aa3a86982c138920711b46dc40563c81503e7bfe3676468fad1ff1d39b1dcb9accae361cbf70589a3a4f208bcdb90279a4792673bfdccccdb62db2db009d0000aa410c65d062d4f4beadd1e1889c9b56541cbe7f3a7ec5163b1d0e7ac6525a10cbba55259cc016048ea2204f13b863a98b333c6caaaa433ab0e44f027f6977c773e2a84f341152bb56a44d159ad6bc816e40c24e51c88a4248079247db824163a277aea144e71b92ad20786f9ab22b08a6459212a0870a46c820927901ebefececf59d9cddeb172cceae2b4761d9cd7876225dff00001277a1ad13b3eb7bdfbe815c37880a48052599f78f4ef5870e212927c47c5c6e943b11d47f1166ed39fb8a7c94378675258e4a8909b31a9acfe2f21b1a8d82efc92962a9b8a59448e1807f18e7740f6f2d8bf5a796558b6f2d3bf246c241c124288d1a3900c84a7be478b01ef8f2deac5642b24f13e4a9c766bd50351232d732a9750eaeea859f69cc7df6bbe40fad10ee3d296bd692b46b04a018e58955b5eb5a72ccc765b677a0a06bd0ebd2241949f049393eeeecd9bc296b4969890299e3f357f50d85658c766fbbe8d5ee3c966e00d7ae59803e4a748963588472315663b6db583b54524b6cfb27aa6c5d2ee1a355efc184b16a96210c790c2d9a6b1ee10b035c7462bb59399547708248d1a2d33053c3953d0bd0d282f495254ab63978a664215f89d1d1fe747d74ff00b572993ff526228c37acc45e64ad04d1791e5abccba868b832bed5a56708ac0337ee0764109d20d83648203d1bca98e11e4cdaff0040b9abef9c35b79ec20c0d49313264694f8dca9b154c93169e52d1af29b9a8088caf121d712c43a8e47c7bea1e5d19090fcf7ef91fb9dff7fe7ac0fa4238824ff3d154a4b07214fc2d0b4b1c8be216781881e5b01849f0e3b3ec37c7d9dfadf564b94250367ce1332699b7c30edeedbca770de8e1a55657879f192709fa71fc19fe4c7e2bf1473ec8f4a49f409e88eee4c77fac724b8ad2e3bea6415a4323c85a10e42312c49f6a011fe08fbfdfaa5872dde38afca7b4e4cd41362316d1d889224f340a272be452631b97dcec8c016fbbaa9d1f6ab21d996a8e6ad626de56a29a570d59ac0db471a85e45d8804ec0d0e1ae409e3ae5b5122673cdb4b5066a339a677",
            "5f753078ac4851956129feb1e9b30c6232d6ed2c66261b17a95292b4f929ac59af1b4534a668d5840c143840208831e6dc993d003d9d071776c61dfbef174a7c6d382d32c73473319a178fc7e3903b71e52317663c0ec94918222a747435b1d4a3b58dbd9446871881bcadc260bfab1997c68d115919b51850ae010c4b398f90eb1bb472967b72ad09298b33dba0b928ad9b90a8686342857937b711a4614461b71846f8ec9e3285b171473c9c1a9cb0ed93458b96903c3c866f5cb1c5eee6f8428872592ab83c9d1a1058b7db765de2124b5b87cc00c1811cbc4e7c7133a2b69bc6a18b05040588cb5b5886165c8a438b92433490ce3946cc38b151e8e8b98a35dfa1b0bc885d905f694866a19bc5fd4889acc313448ca803482554df91fd47c524909625575c8961ad16543f326bf5a4f2c33475610e6448da584c6b18d473344db4050b860849f99047cbaa16a4a4ad240d8beebf078548945494a904bf219b66291b7b6f2c98eecaca603b8ccab8e94b5986b099609164d2a9915590962596150e09655590052ad269256cbe2b1f6a4930eb7a2515c308acbc736a759810c8fc538fc1410c1396f6bad1df54d96ed0b98fed2ad97817857cd43156f0cbe6f3358e71b12555882eded941df28d8304562a7ae7f93ae2ae464aea13516943c7cc2ca001fa83980da6fdc3607a6fb0eb38712a71529389ae546c206715c809b2180b8e35d7e40e507647b8e7bd4969c68f4e25ac2b324733b89d7c8243ccbb13a2c15b883c032ec282c4f4cb036efff00a233f838689961967af605a40dfa16632de3d38f882c867f4c57614b03b5e2c861b4b6f288d9695a686cda496dccefa95fd9e47ca51d81219893c5b6744ab10074f65edbc7637b67b633b366ea4f3e656795f1f3c657c2914e2350cc8fcb8c9a7f7a4d70600ff21f35284242086721af3515f6c7ea2442d4b98e6afd223786fadd079e39566815b9c2449b037c7d8d1ffd91d58265e863713262a5a3505212576912096469af10a7c8e2420c7c763436a4c64af1077296512d2c8e5325f9d5782bd083276a611b55568e085f41de3551b64550e00fe35fc9009e9c2712f6830d7181f00a541292e74c22932585c04381a97ebc77b7dc41bf2a3908e38ab86597c7233cfe5d2b0643eb5a01919db4481cf2c2428fc6098cabaf6dc388dff3afe48ff2747fc0e9f59b777b8a7a9422ad14b6ed4eb1278a34124d2163fd0527934875cbf8e2a0854003eef5ed9bf5abd2c95d9ec99ed470aac523acb1463c31718d645964e3c432e91f8ea3311f5c8289e4afc1509731552ff5e58e90e9c9339ca40a641b33f7e91cf14443979159b63e3c5b5a3fdfd8f5538e782ec58e95165c5627153a19259626bd134ec8ceecd1b1f19924f00548f8aab2a2abb7c59c81dc987a586cd7e5f4ad5ab21634776b3047130661c800239655238953be5fc91a1af6cb090e368ab59ca4f59a6c5586924c74c9b33a3690f063c919d58290acaca7d960ca194be6ad2a96169c6eeba7cd2b124b94a2a295066ce9bfa8412e3afd6823b1629cd1432a878e4742164525943293fb86d1c6c7ada91fc74293a3d744cf65f2d47f0fe976f4b887a51168ee0e13492c11c33ac9342a03970bb595f88560480dcf9b01e389592b59823aa2b04746fd3f18dc9213bdec91efecbeb7f71e802c4f5b26729692a50a3f96704b949042526acfdf0de31f568f2366bcd4ebc8ed02016248bca027c7603104e891ccff0091c8ff0067ad13c162bac4d342e8b32978d88f522862a594fd88e4ac363d6c1febae8ddb9ddb520c0d8c565ebd5a93c74cc55b9d7f1ac88e79fea34603bfc4a94f27910e995918481915e52fdf8af4b076fe0ee610c490daad0d1b05fc75c4524eb2cbc416925f1cbcfc8cc3800e005501634a788996d49286eb7ebb061d3244b084a829f3fcf96ed1e41dd1dd167f0f67c364ac589703e6d2c8f1a148e66525416e058efc4c75cb47893ae4bbea6f1208bd1cff009a458e92bb2491cb29947cbc8a3e26352c0804befd7a43adb7105b52eccee9c8dba11d5ed7c9c71e45912091abbac727352ea55db4baf1a97d93ae2acdb006c23b759e9db9aac8f13bc2e519a191644247a3c5949561bfe4120fdc123df472932815265901eac1a173662d566d176fd8da71b78e3d6fad691aa3314f2a8e4a180d9048fb1d7bd1fe3df5b31d0e2e767af909a7ad2bbc7e29d0068d472d3875fbfd8ec30275c75c4f2dadc9eeacb76df67c1dacd998a5b54ecd86486130dd8112415dc29937246f192b23704fdb22866db6b8ce76e4f055a59b96d5796cc1f46578461888e46f82492052a7c60b71df21a6910e9f5c0809b31485288c68d887e5fb06944bb49af3c7e3eb58b74bb8b8bb11f1e7b896079249e6b4b15a9ab9be17c8c61f49a6e7c07a701579c0540679819fc8e66f631f19157c1d4a54112c58af04b665922b15dd8c6e14b38d06f115e49c646d1d36b8054b472f41ee39cc5585e0b35ac2ca6b548c3472b29f114038840b2246df123d171ec31539dba55c8a39186fa5e82c3327d190e8f1850ac54024e9073d03bd6d587b0bb32a78712d4cb7ab9d31e43bc5c66f880d8a5d93fcf68e81db3db716526c945267258568f9290bd2c66c53971d090d34b2ac8486016481a35849d1542447b597a95c964a4194b1063124c64a607b4e976ca3c44cd5dfced187006e48da351c79172a194e8a0153361ac643057fb4e6ee39ef5b82d7d75a9ded4e228c99520113412c4acd3067e6d2100f15651bd1039b45897fa99cdeaeb055a019657495889dc190",
            "8459555d39908e14e829119fe764a787016a52d6a7d3df077ca3d302d09000a28dfd2ee80ecc3dcdf6f1ab88a792c6c72bd7b10c6fce624589c0aeb2315aec791811d1d4cba284a1d1d0d753143e9a7cb42f93b4d05679034f2c71f91954b7b21392f23fe011ff0023ae9991fc44f2e12f34f5a1ad63296241357586268265d21123e8091846dcc22b825390e0c1a260569edec647dbf5b3ff00538ec8d14a89f514973289692790a979997e4413b28a02af16452eaf1a33cad933d68434e0c4d07edcfe5e9013e5ba814907414ee29846acef7860b37ded52fddc0d982a4512c730faa06694717e2368b1aa8d32a95d7a0ba040f5d24cb622bcf56c5ec2bcb77154e4480e46daf8e695da1dac7e2591f8a810c854ff0003618fa00505cad471b5ee612dd26bf4f192b5f8448ac24db269524f0b700b208a3769232e190a8f203c4893c4ce2a35eaf35770e63d49179de1f28475768e4500f35fd33f1f890dc5b7f1d1290004bca70c006bc3675d3660a75a5305b10492fe55ed485a68585a7359611a242eb1b2b4aa1f91e5e8213c8fed3bd0f5eb7ae437d1ff000c7f0d3bb337dc5f53062eac4b54b388f3304eb5ee00c639103aa153c49e2def6397af6091371dac11a555ad181628b24cd6aa56afca65af20507c72b12b270119d06000690105c3370dd7bbff00b9e5191c661b377862a659aba791235b52d66939f196445e4df61bf64005947c4904e79e22720cb94c1ef25eef7dd625025cb36812e2e806ed1973ddcf9c9f1b88ad4eb5769e7921a8e1abd68d4105c382cbc7edfb7d312a13f720ebcc5bfe599ba7597272d6c75aac5649ef2c90c330049603807668c4a8429d1db202429d85cbb62a587b8cd64d98abd48dadcd054568e79d0f0d297552550931fb63a00928198856ab8d31dda9df32d7af8a9684b5bea1dec5c9a197cf03209500f1c6f123188a8053929e679064255866ccb2f2afa7a0d6b956b7c3e4a09b2b058be5ca99742d12b53b47ea274b998c8458ea730e7aae8269bdabb7e9c6cc8ada64552a5c1db80a1cfae8ecb5dbbdabdb3276d26552e4f79bf5f80631c71231689e16e7af9f3724b22cabf24214330650d95b7932f52196086bd79d6cc76ef22c9662450b1aa9978972aaba3c17e3b04aafd8744dabf57238184c78792bd9c8d892096d4dfa90a8460ea9049212c9c4488197913ad12c79e8194cc2a4f8b50f75298ef518467faabe1ba49baaef5e59f4d625e662cde333192344e110fdc1472e5a1bd6bd927d0fb93fdf54dda39797b559fb884acd2a73fa18a3950f1b6a9a49a44276046252ca4a90e414fb17d34a7f86763339db388edbccd7c9cb0bc2a26f1b45149b5fd72bcc091bc6ff001015097009001d299fed7c09ee1ee28f14b7a3ac651208a7d33fea2a1641c17e679300a0282db601559b4a5ab9b226cb5249a00e4687e7bdf8c49e1cd96a0a5067bb7a46ccaa5c6c0d282e5a8e581217bb00a75e228b24af1f312321041e3c7648254854d01ed51d2c64d93b9154ad24113c9be2d6ac2578f606c832485507afec8dfa1f720754991ede38ec4543255b705b2d3477e948fca5aed170d4c6300704fd42bf2dfc9245d823d65db3522fcc7e96d4b5a9412fe84b2e4abf38a19ca488a3911c55c6c950e426fdb32f1e43533422515275c3e36618b936e607a53db56fae90a6ecb9cc0457fb6f2b464ad2cd2c56a786da32ca92aaee37209fb8491c6882352b6c6c29577dc7f889dcf9ac8cef7268aaca64591e3ad1f0f14c9a50eadc8b12020d1274a4b15009d92337151cf76d3e6854c6d0bd46157f1542211683caa6491959496911e4e240600ac89c155617050dccce3af5767971564e5647779f20d7999ed33f12e64057d9e5cc8208f4c3973209604044d65aa5b9143750d333750679469b724a936d9fcc74ce122823df5b4c72f896531b08d98a8723d1235b00ff006363ff0063ac3ec35d10d33cb147192c113678efe3cbd024003d121577fc9d6f7d5e5e22480c5e3e8629ac4852089e570ace5514b10aa0b31f5fc000927f8009e9af6d498d87b929be621f2d4e6a1d4a961a2402da00ec81b2a0ab2960bc9597929a7ee0c050c95ebb67b762924ab057631c5140e510466357f11d9620c86661e50088c292cce4a80b0bdcb061fb9e5ee39b1156de4963dd648088e282c864026d7b0dbe2e484d6b9ee368d829480cff001a59b02a45d71077e98c5a641944150ef471bcbca2bea60e8e2f362953b9563c978ec4f5d7fe9c411c895f9a998cf17ec29a6076ca38b6b88b1b45b473380bdda71d7b98f962b52b470558e0c7bba520b3162209e4b0cc7987909409be4763454133f5a8e67b8b172dbbb5e790452b17cacf23b2c08fb95b98f91d6c48e380049693f77a0175fbb95c264ef632b4d629ad7e7467843828c7d2c81828e2c19a307477fb57db1507a8d3c3da360a9d41bcbbe7cfbc5eb9d6542694909370db658677e4f2dcb73f38bb815a7f934134019ab58bb1c71b702c50f290a29011a4035a24bb01ecfa0e58eadec6e5a4b96e79ef52125ab53c0c654b32c8e88a5a725b6794d26fd056080722cfc957e221c7e496e497e191ada46f623b12db58aba98d5a46464f112e5c2f1550e9f2206fd8d035a7b1620b58fa58c59bc88f280a8d2495d5543cac9afb0e31fb277a507dfee2694ca62c28ccfb73867f10999c485ba8e2edb000bf2f430553b583aab7ab64b04d66c4854a4b24cf0357e31c81d422ec6d9990824694a01a209eaabbb66fc375eceaf5fb3f093d89f6e9f5f90b7bb90ea453a78e361181a3a521",
            "594ab7dc3ab011f9db1907ba94726d3f9e806ade3b2eed2d7d3b131373d688666d8000d93d614c66aad36b541add7ad60495cc9096459bd2ac91ec7eef8caa0afbf4e36347a62a4db299968823072c77b7896d80a5200715c33df48cb13dc39bc41bc31f75a239185ab5a62aacd344ca5590b11be277ec6f448527da8d51f65e4b1060b182ced68a4a258db5762032b281cb8f23c797052577e891c486e5c7a91b66ca186bd98042d047c5478446c5492e0b6802c7e5e89d9d686f40018c45f5222207e48790e0188034c48febedf71fc6ff00827a64d908989383e234ba3d227ae4adefbc31d6f117fdcbdafdb90653378cc5c5914bd8eb53ac4b2710b2d754411301a059b96f7afddcd4aec6f523dbd35dfcdabe371f107932522d3750a85a65774d202ff153c95486f441f7bfeafbb1b257d7b17b81076e7d5d75a0d592e88d8475b4cfe4b0cabbe6f10b48e640ace888aa00576755b2d6ecfc4f9f096a2ee017285a69d0cf12c50d9410c434c8f13346f23790a164609ce20dbe4cebcf973549b52140a9bae17f722914a8a156662459fb3fa1fa450e22f76ddeee26c245686095aa789a2799ac43332f8c9238460172b0c45b828695e12aacbe45226f393419dc6be4f05db50e2b1f35831c11c403001234137292495994a09e15d8011d4f3e319423a3a9476735dcf04342de2de935669aa516ae9621a1139333c4c4a32a15dc8be4935ad06628002283b8a2ad265b31673cb925b99069e7a304aff52f2448922342ceaccd22092031893913c5227d2af518509530354b5ce4f951fabb318bac198a02d594d6e6fbaeace72112bdc184edf8bb5713373fca322f4abbc74a48e76faa3a3e69599dbe0a483e906c9202a15d486570f015ca4992c54b1ab54492584ce6446120f4863f19d9914b2b8f7a0576db50417b95ee3cae6b050e063c4e2e3ad13cf78b56a5b9d7cb2792591dc29d7108a84803488a3475d4e0b15ae558a846f2d711e9c996456566f7ccef8af107d694effe49d75d3929982590b389d69bfd8856259580472e9af9f943ca7dc2f88ca25dc7815326678e4951276f1cc03fce177243201a03d37b52db66d83d1383c8535c9e5df292dba38fb314e90576f2491c12305e602331323a0e3c01607988599902b3093b579a5baf65638433865f8c400d1041f477f2f64ef648f5a235d58dbede4a18ec2e464c9d8968e4acc92895a1491d600e84cdc04ae85c8e00a31521978927f7759325a1000550aa9ad2be5062699aa201bb77675ef7e306ddb79ea125ac464a3a4f94ee426775b122d978a1b015833ba12391e28fa9365488e401480dd0f83a78aab53258f8e6b375d4456acd811c8b5da351305da98fc843c925528a176cbf22d11ffb6e2ce4e5c46131f97a5064e1bd127ff271c2516ab47208f932aa068b8372811d5d48df0464fda3adb8bed6ee280cfdf3dad4604a76d1da38684e6778fd2b93171405752281c5873895958fed32880cc0259b5fc83ab0247d5d7e662928ff0068ab9188bd8e63d7426e8d3df19ba99ac04d59f1cd888ece4561796c4af22549abc930742162e2015b61b8c65cfc0b31777663cdde4ab362e233c896275ae42ac7c94c3f30abc895d6f401d025486fbab6f7d361ecfc26431d95ff0058e56876e4f1b54868c740ab7d2bbc68ed0cb0101c2a2b69ddd95848a41695d8ee3ed76ba51bd91b54bbb30d1d6a50ac8b645827ea1db63c71a22b3ef92bfdd400002480c8cd4708b9284f86925c17c5b0b8d797488e60593e2350d0fabd72db40f85c1d5b585bf7e5a13cf4a25449ef027548b4ca15f4a7882c03205959412db0deb7d27cbe3ce2b2f6a81132fd3cad115b0823954a9d157404f1607d11b3fe091d130c990b79145a2cc9157b06dd5a99192392352ca1bd8902c6eccb1a0e3c7f534a389f43abfed7ed69b3892e3fc7061a78e085a74292da16a428e9e578246f8b8160edf5a465240407668993ff00c72573154cb2bb741d318197215c40b32d0cd8efdfbe7252f7d670e663c85794449144208e9b9f2d78a211a45e208fb050c71c6843722c10732db3b1afc981bb93ad662b56ec4b62cc86d28a10528c47c808bc6b1b9552cbb2c34aaa4e872d6c855c54821b54f298f31cb3c43c361cbab5760ea79711e9c15574d11eb96f7ebae83db95eaf6e5c4ef8a9063b318fc358b6c320d198a29ac989c558bc32942583aa4a56304857fb82875e9a51243a12c5985d5a503f3bb17c21490b3ff46ec3eb63584d9da18f5ab51e2ee048639a0ad3e53190a056ae6326b8611997524c3e4cd192acbe63a1c3915d580cd51b993acfdc78219a8aa2ac28f3d964021e211237603d85507c7c421e4c092caa17acb38d90a38fb396b32156c8da9e082d51c8c52b4e523f14ab61a26d39547d16f1a99bea1dcbb2b0e48249b0b3f6840895a3a999a964ab3a1918df86404f26d9288622817e2073128f5b425b108b72d955c1c61d9aebbd6e31ef1acccb6d425dbee2b73396c64f959ece124805740d7951618aa9a4ee91c5288e0038720db74f1bbb2aaa3172c8c40315abb8058ea0b02c4f91a8d918d600d035479177c788d101e35d3200aaeac876ea10f51277eba678ab1256fab8e3c9fd0acd105663cc0938c8ae1494f7ada83ec6b6a3f900861e14210c2a37fb0c97c4152c020537f4e61dd3c27e6b82cf66cc760d2c552164dd148059e59244896227f6a9dcac77ec9f1368fd8ac8223820985dc323328d11b1a3f2ff0081a27ff07aaf87372e529b2ddbf2c0b5639479ab4282cc824055fc92001a40579290efad3710406d",
            "75bfb3a57bbdf945e0910435e658e9d6bf39768a26949e08c028e4a199bd050c49d02582914cc5ca4aca85dbfbd3a412a578b3115a28d3df66ba988db5727961ad0ccb1fe920e2ca803303fdb7dce8003fc6bfe77aeada35ac0983f12011ae01c10411a20fad1fb7fe7a3a7a5bc557b3234b23ac4ced10e5f1424aabef890006001d91be4a07f24270083a23ab9165492044532da16144d687e21b62b396f18b76288432c376a495258a705919586c1d0236cada65277a6553fc75437bbac6429d5bf7e83dfc8a700b6ad5c2fe08c4d3bb428092cc0f922f94859870d7b5703a8923df4663abd8b592ab46bd76b525999235aea0932b16d05007bd9debd7bf7d04d912d5fd91192a6a9259e2aa8dcca76de4f1bdd559054dd8523c67daaa8478d9d086285b45c7224b80481c7db63dc3dd33dccd55b34f236de7a0812b5e2ab15891bc8cfe6774258b92dcbdb12189f7ebdaa9b1af7726d4b116125a1cbc9584939544e7c4156791235e43e2ace5554943af5ae8dcc767e470e6bcf0bd6cd529659238ede3dccb0ccd1b00e011a603647b60bbfbaed74c6509921692b22d6fcdbdf28b0cc9aa494a5343b2da3eeb1e65ee596ca0ee26669efdc9ff00307b52c684198b9621938f11b239f1d6b4e07b1a247ab86cbf71ccd6aa63e18215899e49471821d441048dec8524074242fbf96f5eface245a74157212cf62acb0c8a6288a910b6d846ea4861fbd367406d7d061cb61de3f33da5878abcd40770dab02bf8ad247752a2e9a25df09154b7c676760a415215360e8efc54a425a507370f8c3e209494da01744b3b53cb7a44ae6e0ad5328d5694934b5e30023cc02b36fdef4091ad9f47d721a6d0e5a0dfb7e28731262310e915675b7297b67dbc88eb180a17e25ca1524206db793407df7a73f2d38bb98a9932b7b1216110ae44a476fe978ab2206f984f8682b0046b4788078f58f6c64eb52ca526c9646d56a95acc7608810b332ab7260a43028dae5c48d6d986ca8f9062ad2a438bdbda132d48f19cd065ed15bdc782cdf6c43363ed5786ae4bc42acef5996268c2a48af1b280032ba490fccfa7f5a2ec480d3b1f3999c0768c9530d585a325bab93e334b00a75193f63cf6448be22ec8cbe0902b7a421f7e9c93dc5dbb93ee619eaf4ff00d3ddbd612ee221b08934b3912c1e36fd1333a808f6564e09c760c9ae4c00ea5681ca47919f23db78c173e9ed9b3763b30c31a5b58a612aa1ad1e8a47ae25e152ca3816de93e1c900cd9562680f425e81f2bda8d81c79c59354a5281940d0615a6eb7c3b878e02e653b9a25a165d5fea28d5bbab31d842f2577ae55488a55285f72a9653e30aa43b3048acfc99386f45dbb7bc14e286431ca61478bcee1e43e49449c599d3cae80b8054295fb86eac7ea30589ed3973182cbdb8b1f7624a592c2cd4fea6196c26a489240cebe35628e7c9be6096f172d4823d9d8398ca63ae61737730b91930f4488c4b571c26f20595acbc08a74adfb0cbb66063e25c7ed41d310b54b066b3b52b43414ed5b9ef77c232614cc52924d4573071c9eaed5884bcb5ea62a08ac2473cf23949a2579034653679722389626461b05b454ec0046f52e5a69218cadc921b3148b2c72150a63655df20e9a6e5cbedebd687bf67ab2afda1366f074ebe1eccb5daf5daf17d3ccbc20f9b4e90c84aafea1015d4b6cb215947b24858c15928b3f18e3c81f195951a36e318741c1d59483be4de8fdb6abbe4ac54db2a64b5ba6f50df4f78c9c26a096ff009e9ed7e3cb48acc659c5c19333776e317315a42234a21ec06acacf0b4b3a9551b254b05566da924b03a5e7abbfa2a18e8a0c5e02e64e1c4cef25d38abb59237a4e2468d52470c4c8c35211c87c55c6892edab6b10e1aef6ac389edcfc55ad62692401a295ad515fa995193d12a4306512a9242a856553a0cbae6d9f8f172ad18ab7d54d6e089e3b9664b826866915db72c6dc41e0c48d0e20fad6dcb72ea2e1956e685310d817e85880dcc561dc4a52a0a2853be3d6e3ca8cd4668979c44b66510397843108c7ee577e8ff00ebad635d3acfbcef2c75a7825ab2e3c3553524e40d5018931f06f6a439727dfb2db20127a463efd76e5aad2418e3cd4d95900bf28d8493ecfdfabbfc38c4d4ee1cc5cc4477ef51b13e2ac86860816d9c83a82fe248c8037c179a863fbe1521d5994a416fdf57bf86b731b472b3dccd486be3a14606515165dcaf1ba2ab3eb610297768cf259163752afbe267e36d090a29bf0fc82949b4b685592c6d3c5646c57cc5682bfd546b6abfd0739841c8b030fce505546dbdb7324c4854b23f3637b556c3f7c62d6fe32e5c292452357c444a2c958e3f8b46a1191d8290ec0825b8b722365ba2f2b5f1594b588b12ddab343341397b0b3342c0acaf145190164f1aaa244fa75e4448db73b5e39f74e072ddb98a94dfb56cd5c98ac78baf8c48c158b3344cfe40d1b892352cba605882a080d278a16912d66aa0d5ed4f56c74ab5c648402a45c0d0e8d8b7463ce1b76d771f67d7ede8fb6f26f90ca87f1c71477a664c7c2ed3b19a4d292c8ab0952a4237ea33b3ab858f5cb2ed78eb642cd78a78ec47148c892c44949003a0ca480483f7d900ff0081d651cf242cac8da2a4e811b1ec68fa3e8ec75a796b447dc7f8eac93c3894b52813fd7ac453265b481f83946923df4e692c92bb44ad0792431d5956c282fc4ba9054b6ca90542928010a35f666e9645c0ca892c8f1c2cc39b22f2207f240d8d9d13eb63fe7add0bcf1d8b1531935868acfe9155055a74e619559413bf6aadad91b51fd03d",
            "3d61e9012c805c878b5b4b86bd9ca7633d5ace2e0bf76092d4151c4bfa436961d36ccdc8b8246c1deff9e3ec6b5571d4f351d4eddc89971d2ffd421c9c559268be3cf8fa90fb09c7da94666f885e400eb2ee7ef4b599cc62b238f862c04743c6614a53cb2181c246be5e458e9b51a0001d858d54ecaf23438db557bcbf112a77177065f0ead3594ab33df93c924d1947516248f8347f11c1747828e29c87b693ae413325a02d61831a5f5177ebc756d05ccb48cc5716c496d600cb253c1f6a2e032471d968afda4b7f9c559c8b35b9a82dc616759258ca08994ca8836640bbe4b2750d2e32fd381722d46492916318999371b3714246d491b02443f7ff0070eba77e2ce02eea86471ea2d50bbe5bb1c35b25f5c2a16e6f30017d05dc6e4b8dfec6d92413d29c9e46eb76b6264b9dbd057c6e22bd748ac2baa3cad387953727cde546992594a8d71e3220e04faf70d3cf8695a6b68d6bd33bee14a7baa6c901652b550541ef4c8d7deb1cfe6b76ad956b1334bc15230cdece9578a027fa0a001bfb01a1d60ee5d51492420d2fbfb0d93ffe9eadfb6c52c1e4e2ad91827ab6523567b29663938c6d21f2b085800c1e0017c727252bcb92ea50518ddedda7f912cf67b7b2788a13de2cb627aad157accf2f1e02cb42647448d789527d36dc024147acf1694aacd9a61bdfa3a470b308725b9fa420ed6c4b662e47763c9cd1e516768eac159d2098cfe091e19439200512c69cdbd100ef7b3beba2d5eddedeecdfc3a58334933f76d9912fa2d758b9d5afcd847b93e6ac5c464f1d903e3f153f36e77559e8c7726abdcf2ca2894b500a2270a64e7e30dc4aa8428242c18e87be237c8ea8e6b51c7d994e9d2c2dabf56cd77bb5e24bb2b4b4a3569b96f88e3a0f1963a1ee3e4cda26330c1c5099314003fcb8d2eab396a69e781b78712e59f10de2b437eb8e3797e9135dcb57278e5960c9b4f5ad59b4ed66a6963899a35011f80d3720649576c83d86d3312e140a17ace14d8a5660b3592e42ab2f8dda194c4ea48f47e2cac1d4fc94ec01a237be9b6428c18efc4da94bbae9251a914b516f40b03c2561e1196e4a0060e53db151ed8b15f44753162496ddc92793c62499cb1e08b1a824ff000a00551fe000075d19402e5849b88074d1b97c44331653354b4dee63a0d0ca4997ee0c4b419ec0e2b2484c915ab31cab59409d95220a62648fdfea83c07b7691e42e74a5770e2a4a5d995b176295683f2d8a78eecf5598a4fe3776af3305e5b46366358a62aa58bba12abf332d5e3a9630b4ab519624ca40ad61a4a955ccf198da4625dc7a2a10f3e69f6543cbf62f4e7f38c5dea98dcc65ecc71cd1442a435e9cf3c7f4a09976ec584806dbe651432b06206892179eb9652b0500b03735716ca97b5e05f17cb16bfe942a1f0619beba51f38fffd9",
        }),
        Ice = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc000110800c000c003012200021101031101ffc4001b00000301010101010000000000000000000304050201000608ffc400391000020201030204050303040202020300010203110400122131411322516105718191f01432a123b1e10642c1d162f1243315435272b2ffc400190100030101010000000000000000000000010203000406ffc4002a11000202010304010305010100000000000102001121031231224151f07161b1e11381a1c1f132d1ffda000c03010002110311003f00fd0999908b9866814ac9fee3bf78dd40120f3feedc41b3db48191da4699a53e282183124b137ebfcf3e9a68412e632c8888ab6b1909d47400951679e39ae49f5d0aa18e1499198ccac2d1a305475aea4df4e846bd42d015de78c6b26fb46f0bf509e3ff5a58e5570b35ee08410787e051045798f25ba80092a1c349080b90d1b8dde2acb19fe9555dedb3dfaed03f9d71a28c45faa86640cb2ed10b80c40ab53d2987041e3d3d74eafc4dce495cac2825c790b2cab02a97d8369201e4855038e82ae8822c03b81b5941b48a6f7df7327fc464c69268da08e188189432c5ba81028deeeff002fb9367538c94fb41e346c89e0d8b1c38fe5058b331b637542e8740076eb7d8d695689c2a48ca4061b9491c11757f7047d35d48b428ce6736499a0cdbb4572c12c0d0f1e39a69d5117733745babf61ea7dbbe9f97c0fd124071a58f3124612333715d85570473fe6f82c688100160988a963fbbae9ccc603e1f8322b36ef098156aa03c47a239b3def8e3eba0ac44d8e83d74c0c25793122f86493cb9732159176eda26c100df4dbd7dbe6404622c13ee232026c0f73249247989ad55f85c863c49db2e31260964dc8e57cfe601b629165b693c820806efa6869871c911c53132662484513cbdd2eda3cd83d8024d9e95acc6d8988d3452c71cd281b4151bd7946079b174c4722fa583ea5c87150a028774f1f89b0cbc5ce3858ff00a9491a76704ff558d72c01b1ca9356073d28f239a3cef8a64499e71d41c89585a00a9b8004fc8006c93ee49ea74102042864dcebd5957ca7af4079eddebe9ab18df16c4825ccc78d72a3f85cc095c74716e6f80cc79008e0d7355d6b90dd1945cc6521f0ed891531e69e291c48cd1634418190550dca1957af467f6eb7c135a6b1d25c790c98f35218c825ad04940178ec707afaf22bb9034c7c2b31b01e6cac7289345036cf1a9bceceaa4a0e28ed3efd0f63c20ce5e6790816c6e800a3e80703e5a7b66241e221da002398c2c7e2e595c709e182595669553cb7d09240baf4d19de40ab0ce25d8a0f84be26e4537e62bd88241e9f735c867f02411340ce5f68f114c41429a038366fe7c6b9e24d6d7e6b5096c371a15544f4e8071db8d2d5d4d75887b50838ad75298d76d19e21322f818ee8021959dcf51d0fb502287727e60002b91e4a04024fed17cd77ea7a6901b131151e9669a4820501556043106450a48376091d6ecff003ea6daf85fe8a394cb979724212888e306e4ae6ac74e40ff001d753fc448cdc6de2abaadab02369ee383edefc1ec7a399586f022ccf1488aeee7c331b21450455ddf5bf7f993a83015b78b9652d7bf9a9a7c993330fc297cc71f7481c9e6988bbf536473f3d78bc51b9c5192b36221322b18eb736de9ea2c803afbeb44e2430c8f0cb26f24784ad182b24649e4d8e483c743c8e2fb004891ca9930247118191a99892edc76f4b04f6ababe9a40076109bee7fcf7fa835cccac5ca9d903623bd8654050a8bba1dc7235cca18be228c599e58f6ad975da6eb91d7d7f0f528611699971a477d9e728aa2edcaf000f721469c549f0335a3991e2963b0406da41af51dbfb8f9eae5429fac9d9233c7da6278cc6688f30fdcb441537546fbe8728f0a3597c7917208dad1b215f211c106f91b6bad751d469ac9cc9b21833b9daa495504ed5f5affbea7a9e74948188fda38d15bef14d038992008e2718b19556605ceefeafa83cf60474a3cfae8f9271e491201f0f4c6748fcd64a3d8535649da6c0527ca093c0eb64c615c8591f17c40519b6a3014a945af75f5a078ad25972c79138961c58f15422a948ee890289e7d7f2cd9241dc637020b73c4f1c8a7638f32b2372a41f6e878d3bfaa932e6925ca67926939de4d737f2e95d8576f4ad27b53c1dcc4efddc2d70477377f2eda671a478d8946da482a4fb10411f63a76039ef260918ed1a971f646926c711c83caecb56475af5a3a5906d7575728ca6d594d107d469d567cfc8c7832325628c0118918708a3e5f9ea7494b60f80855d549a651d7ea45d71df51527831c81ff423b17c3bf573438cc63f3945333cc16416a3680ac795163a0e6a81d2505c99af1e74ea773f9a57fea007a1360126c5f4239a37c0d6d23cb08d951a7914786ecaa0d02bb79ae960d5f737dc6988460cf92c67df0401084daa19ac0e2eaafe75fdef5ac8bbc88f835428fd62794166a4454114636ab786a8c471c9da39e9dc9f9f7d29fa7555bbd5131da5815a59c11c135ceaaad58122d93662cc06de3a8efacc62e891c8d19c7908047d3594001bedaa5e22c6b131e39a729264c78ca1",
            "1983c809160581c7afe59a05701cb1f4d1851e7afa6b6412b7406a7798ddaa31891cf1e064646e438db9239537287617742ec8e9ff00ba34399f1d801040d185bb2edb98fd4003f8ff000ce265fe8f15a4c7a194cd41f71f2afa6daa367d6fa741c1d2f96f8cd2838914914611410edb8eeae4f4f5fc1d04459636254d6d146164860fff00151658cd479b7946836d32f5364dd9edcd77abe3426ca4970584c4c990a5510bb31da9cfede68555737fbb8aae711ced8acd1a2a83655d95dbcebdd0ed3454fb7df40762eece42f249f28007d874d385f30161da5147c36871d716332646d5deafb8f88c58f9401d3fe47a1e0893230865b4b9103b426cac71bd107a816474edebfdb4bc398f845e58d232ee852d943503d681e3a58f913a424c8699ddddcbb39b249b249f5d15d326fc405c608e7e272332084c9b4ec0402c07009ba17f43f6d5348329f1e3cd66129c991a300386919b8ea3af37f962e6a65e4a603e126438c79183b460f0c477fcf41e8345c4c8c8c5c949f1dcc72a1b561db5570c7888a57bc6c00d8ef3a92c51802a07407b9e7d6874f9d58bd4704f90c891c76642552cd066f404f7e47dc6b98d90b1e4bcf918eb965d5811293cb11fbac1ebf9c1a209f0c730fc571243208d5655dcdbb68da4f367d2af516b00d47014910d1472624e639a558cd857523cdb594834769ae18d8ebd38b1c072f29f25218cc7146b0a95458d2a8124f5ea7af7fee493d950821df7788e2db79b2d7c83f2208d0245daeca1c3006830e87df9e741402771e612c40da389dc5c749a565925589545b3b301b458b347f71abe07274c1c3070e6cec727f46b208d4ca42b9245d55f35fe7d68671e25c249ce4a33bb15308bdca0573f9ff75c932f2248e28fc560b0a98d02f94283d7a7adf27bf7d63b98f49986d029843e37c4a6c7c76c78d63d8cc4b128096b1557d40abe95fb8eb329856532e2348884b280cd6fb6bbd0039b3f9d56009a03837aa195145fd29b1a278a075a01dc312c00ddd3a7f9be2eb4a4286c779ad8af3c4596678a0907892a0722902da4946fcdcf6f91ebdb54843853e13bab39cb08652cd26ef13a58adb7c79bfbd91c8ccf81345f0d872e7c6909594a912580178e08ebc9be78efeba034de1c68f0c822568fc36546f37fe57d09b3cfa7205f1c4c90f95941d1861da09838f2b065e01008ec458fe34ab824f99755b13132727026922859a3856c6db36c585f1ebb7d3d06a7cc0890c6ca5594d3291441d515812449329001ec62ac0eea155ad08ad77571ad2c372a82c1413459ae87db4ccb0ac1952431ceb3c68c4075e8daa16ed16b17158d698ee15a7256c43831aac6ff00a80c77396f291c5003f3eb7c08c458d8e06b73b24863452c52340a370160f53d3b6e27e9a439221180613c7c59bf532cb8a559d47842321551b8be2ba75ff279093f23bd688e36a800eb49232c83c26fd38913c390924a907826a8ff00cf3c8ae00c0571093bb98b90a4722b4bb3159027f3a6f21e17ca94c08520de762b1b217b0d2aebe60c2e86acbf593228c13962a558f5d2ad4a6875d3ae57ae919000c75658a669579abd331c725191549404026b804f417f43f6d363c5f86e13c65a2f172d5a29a0923b7840208bb1c13cfd81eb55d6e7195808e1590d8891d8eee5b9209355d39a35ebc9d4cbdc7d95f3044d0e0f3a63132228676797193254a150b212059157c7a7e51a21f9be119b062913e022356e698cbb8a2822d82a9ba17c9a3c5703ba7918e9879e6032acf1a116541048f420f20fa8ec7500eae284a9d37d3a623dfde1e59e29702267c877c9f118ba14140501bb77524d73f5e9de7cac3758e9a2accc5df8da1f82a38e3b0fedf6d2f383b81074c8b589366bcc6b182cb362c52590d280c3c32dc1a1fedf31f97dbae811a8a7dc58355ad0ea6ff8e2f47c4c0cdcd78e3831e460c6b7ed3b47b93abd99fe9bca8e547051e158d77ed241f2a8ddd8f248e3e7d3ae91f5511b6932a9a4eebb946048c7227465899047e11e632bfee140ee07af23a1e2ef8d57c6cd79e08864c986040a140961dcec8b6681aae471563a0e97cce8f0966959037e9dd514ed91685042cc48b27a027807a8e96068bfa278b0a59721d6196300085da9cd91fedf959f5e87a7593ec6c778e87517238ffc96737fd445fe0e15210f248cd1967515c573b4d8e6fa6a3cedfa9104d1e3c50b280ae515592aaf710a0f3c3922b80068a67dff000e5c544f1dda72af2aa070a1ae963460369344f15d073cd053222dbf0e8a4926841918c68198b6c450083496013b88362ecdf72753d3d354c015995d576d4cb1bc097f07e323070b2e1610c8f051511553ded160a802ac9f7edcebe7a5c89277679562049bf246abfd8695192db1626694c416950bf00f7238e962fe9f5d74d525c960f5dbd579aff3f5d55345509359321a9acda8029381366f771ce9cc58e59e19586c31c0a5cabbd75a1605f5e9f603d014ebc39515f7a29a2495e40201e05f3d78f5d1f21b1972655c6767841f2330a247e7e0e9a76ce0445c64cd302230db4ec62406ae091d7fbe86c6366b48fc350a0117766b93f536740043fed6abd741656e1a8fb77d10b12e151f6387d88c57a06163db8eff00db5acdcd932f2a69dddae55008550bcf06abb8047f00ebb14b8de3bbe644f22b2b7962212988e0f4a02ff0f42975a1d08d600136447b2168182db46eb8ee34fe6e1c9062e18758d5658fc45db5b8dfff00cb93f4ed5ef7a536798706f4d418cd3170d22a6d42e375f342e87be998d51b8abdc79935d53eda565e49a1",
            "d355b38c392e248b11203b42858dbaed5f3120f3f5f63d4d9d4e689844cf6a68d6dbe7fcfe7b6ac8d62cc465a3426a6776ca9320d6e90b137e6ebd7adf3cf5ebdfae98c49a259c0c99e586029b1cc000665b163df8f5d1be2137eb725b28a22492799d5176a83edc9bbebf327529cd1e3d74146e5a38849dad8ccad8d938f8cd23c4b2c53904452ace0f8408f65e4d58edd7a023599da249c9dd1c81906d685a96eeba1008e0551e49e6cdf33d2c8e345da3683fdb436006e1de48a85de0b7a6b8fcb5af27be80dbf7958d59c805881c9a02c9fa017aabf0af84e6e7e0e5e4c30ef5094849ab6dca481f4bd662a8371302ab31a5132996d0636308f1d619d1cc8b902f738e9df8a041fcbbadf16f8bac91c466963c96920dbb1769f08955f3743cdee15c103d2c1d7ca34c449b192883c83a22956b3fdf48da0a486328bacc0151debf89514785000922b6f16ccbbacdd794df1c117c7dce8c904b93218e381237a32799f6f9681ff71e8073eb5cf3a9f148475e469e984993290888a2314db4a804f24d1140f7a03b0ef5a9b0226520f3313180c312c30323aaf9d8beede7d6ab8ffd7d475939b22460cb91205da8bcb1007603d34667db82b1321da7732120f72a2c1bff00c48e87fe8715c6a2668b7c608bbe9df835d2e8eb0c080e4e62c8676518de337845b76c2f4a0d55f26aeb4e7e826c40b921a399548276f9bc3e011bc76e4d51ee0ebb9195e24ce2291dd4a850d2280c057415fb475e076e35bc3c5658a4ca3099238b692770156dc7041bba23a1d666357c46502eb99b118cbcefd3472c6402e44ac3682a05d9f414bc0e834bc9094255a8d1af29047dc68f24f264c2b01823880ba31f941624125874eddabb7615a2cd94de0c204b24b26d6ddb9d8052c5b777e4f20d8347b83ce90161090a7bc94436ea1a29554500c81a52c54a8e800aa37deecfdb4d78ccf8820964f22821405e9c9239045f24f5ba0c6b5c8d9715e09e965937db259fd95d2c1a21ac823dbe634fb8c50a3ccde308b1636c9c98125dc84468d54d7b96f8607820f63f4e0e93217920d8ec6b4e263e234f148d203148d4f1293ba1b26bb5b50a3c7cb8e2d61134992c89e185142f76d0dd058ddebd7fe86829164c2c0d00208824de8b1b6e3e1f9ba1ada2c935c6989155c478b0f86d44b095aa326c03449f4af5eb75ac28c75c35649dff0050c5848856976f0473df9fc1564eeb1176cf0866961ca7872239234855a4f1abd00a50ddc59008fa7500cd78955558313c79ac551bedebc56ae4ef343851872a5275b40b25855dcdd556b90c6c5f422bd40c65c18df0fc6548731a691d8b0fe88daca1ea89dc6c5a5d1b1c0e966d53528d799564b17e39911892b47ae9374a6e7565e200b36c52029e18d75e2c73c9e6fe9e97a49a000d9e4eba95c4e6222e1680a3ae78a458abd1190d56b088cf232a29620124017c0164fdb4ff00316671b27371263362e43c321528590d1a3d47e77a3d7577e15fea8cfc4c1cb86490cc553744d312c412ca2be5449d7cf33ed24751aca1ddb81f28d2be926a0ea11d355d0f49a8e679f8aa6488fe28723c4601c2cc4f43cdf3f8391db4ab48dba8715a14b233b8919d9d800bc9be00a03ec2b5d6240dfb75455a00446364d472167f04bed3b4100b01c026e87f07eda7f1326681fc486678dba1d8c5491e9639d4688f9fdf4fc6bb003d41d4dd41e632923227d1cf3cd2e36165e67830e279962551beabbed26eaf8eb5c0b15408e1971cbcd3c5095c76709e10f3168af730a3c8a02f703c1f9d89925c986a10b3786c598026947945d550b3c5dfa74efac7c432e743872c821698a80d448a6008e07a823efdb5c7fa602e4ceafd425850f1f6a8e4b8b871e44d91097931375c4563255bff00063b815f4f5ae7d35985ea6deb18016c2860adc73d78a27deb4ac8b2e3b9c594c64c0ec96aa059be79ab3f5d31197f08315214920357163aff0071a358c9b932d9c0a8e64e3bc6f08461219d03af863b9ed43bdd8e349ceed2b78f2bef91b820924f000b24fafcfedc68b0cb2c39093452147436186b7931ee2b29523c45dd65b716ec4fd483a41d268c2482091273bb350e9aa1f0ef873e5cac92cc22451c92a491f21df9a15d791a5649184231ca864562ea7b82451fbd0fb7cf47c1ca10487c70cf16e59182b53583d477ba27a11d6fb69df76de98136ef1bb89961241188e4622489f778654151605dfbf0051f4e6ab587c732334f1a24310ae5776d0483405d9ff691e97eda7323e2503fc762c9685863a5028aca7729249e83bee36a7d48bf458ce56278a38ae3521d8586a537b492b5c8dc7a9ea40238ad282d8351d82e45fbefda6a6f1b35628635959615aa2e5c805a850faa8a1e9aee4484c28d32ee9e42ecce4000db755da68f21b9aef5d86820ac8221e6823b093494587249bfb76ffc744933259d131e748e041b48a522857949ee4511c9b34057537a8822bb4176092799cc8fd3b4e644b68d5b6d20dbb945006fd4fcb43cbf19611e12b4304abbc46b212a7922e8fcab9ee3e5a2fc3f63e5a8927f0529adeaeb83dbbfcbbf4d6b24acf3c9288d630c4908a0000761c68dd301e20e549f33b9b0be24088e7fa932863b49a55b3e53efb8723b6dfb4c6b03a58d52860c9ce2b0431972a090a2801ea7fcfcbdb4966413633b452214910d153a6d320749398ae2fa80c49f2bed1c0efac63e5e562ca66c695e07652a590d120f6d18c4d2708acedcb5017d0593f41a1ae34f23523463ff00eeea83f9235d5d35464b20d88bc91491c71bb2f92404a9b1cd123fb8",
            "d006e2d5d8f7d7d8e77fa5e64ff4c4537eb2333464c84338094db780c4d7147e77af9511f82764c47009b8c87e6b8e86baeb696b26a0254f11b5749b4c80c2ae2acb5e51c9bd6e8f209d7761326e515a3b282b67aeac4c8d4c40858f3aa50c12cd2ac30a33c8dc0502c9d2f891b99163552ecc68051649ec35f45f08cf960f88c1e1c51302698945040ee4b55803a9f61ae5d672012b2da6a0900c5723e19931fc43253f4d28820259dc25d26ea047aff83e874bc993912ca93cb3c8f2a56d76625968d8a3db577e29f1832fc51878486289c466368d5bc550d66d88b02c0e3ebdb52be2599065fc5e5c9952528c1410b486c281ef5c8f7ad736933b56f1da74ea2e9adfe9b779864972237cb9668d999e88b018923aed1dbdfd4ea9e07c3c84676cd109d9e20652086a01ab83763b8ae281ee353e344cacf957e1f03ec624c71936d405d7f078e7eba30394e527314a63b243052549af31f9d2d9f91d67b2281a8ab40d917379589262cc11d918f4f2b5df00dfd6f5ee15648a442b203dc72083c83cf1fe3584ca2a098e28d251d241760fa8e6afe9d877d066cb964da6476628a1459e807000d6018e0c42579118c673164832233c1ffec50cca2882b64af35e6fe6bbe86d12bba445590ba5a579f71ae00af56e3d8f5e9ad62e63c4d1cab124be1036bb055134771ae4106b9f5fb9b321c68b2d9e161345254cbd02b0f90208f36e15c10068590d280029f1efbf992e20bb98b1414a480f7c9ae3a77fe3d74ee147832e14eb91298f2188f0c95f28a04d93d7dabdc707b655ff0062b08f6c6dbd49dc3a002a94d73439abbefa2e44511c313ac905b51da0112026ec50a5ab07dc023d86998de388aa2b233019108c68712431abf880c96cdfb8703695078160f3defb11c234dcd91a7e9d5a29a59b63c8ad3894162c4824007df72f5f7bd7127962c69c450a08e65589c94dd5df827a1344ff00e85329207be62b004f8ff3dfcc5f1579b6d3ae46db0458eda5b1a0965629182428dcc6890ab7c935cd6baa4f20f51e9acd9310604755e5c7b686468cd55a120e97cbcbcbcd58d72653208852dd58faf7e9a79d148b37a466a04003535a26eb31c92055e20209a7c498cb8f2b44cca54953468e9696352a3b6a9afc3679704e6078bc3504906401b82074fafe58b42a366292b305f5550ddfe63b5fe722aac09b1032b0001839f3b224f844582f33b223b1da4f154b43e94753d2305b8d545c781231e3973252b88d56ac13d093d38e4100f51a5b62f88fb4928a485245123dc73ab21001022303c98b0888bf36b37777db4e347b505695688fede7540d712a3df08962833167972a6c731ab323c6bb8eeae057a7febbd8f195e472ece5d9892c49b24fae811c2e1058ad15632b64ea4c06e2d1f71dbb66ccbb892c6c93df5e08187cf5b7c69bc05271d915d86d95c151df8b3c73d7e9a090f149b1fa83479bad0147882888d63cf262cc1e2778cf42518a923b8b1aa708db8cd3e5234b2ab302e50c8f0f36d6ac429167e9bec906819f8d938f01799e177994068595a82b0606cfe7fd8ab0e6e44701f8b37c415b2658e9f1a54e25a6dbd3814010455d9ddefae6d5bec3f33af440ee7f1f9f8fbc8b3b00e156368d946d7527fdc3a9e7a7cbd6fe40609ab1c9d18a393bdd76eff30f2d03cf6f6b0744c88a3c772b1cc928edb6fa7627e7e9dbbeac08e273104e66a2c59e5c07cb088b0c476962c0166e381f7bfa6b73637e9e085dca113aef1b58123922b8fcfb1d2cae0f954d5f5d1a1204cac503907ffacd00cb46c59e87d2b9e78e6b486c6638da715184c7c9100952348a293fa61e451b49a3d09e8783cf6f51ac895fc12cb1801d4abb08f68b2d7db83fb450e839a17ce8c99624c68f1fc00e02b16001bb00d1bb3d2f7570393c77d325b165c585241b0c16a046b7bc75e49e966fb1abe9a89620e44ad0aa064c0ad0cc69b695206e5a245106c1f98ea0e8d318a6c57753289079a455555414694800577a3d396e2f9d7b26358f21d56c056239ea3fb7f61ad63a4613c790a3c744328750c3b743f3bb00ff001c31380d116c12bda251bb47278908287695e69aed69bb77b3f9ce8b1447a1efa662c5f11cf3436b37d813ff001a3c50c263919a648d916c2b5db73d07e7fcd16711429316f140400b6967248a07593206155cebc3ca2bb9d381512e696f6f241f6d0245049a147fb68acd4bcf51a5cb166d3080cde465cf912893266695c285058df034a1703902af5e98358bd0c3213406aaaa00c404926cc307561e6e4e8a830ce2bb3cce3243a84409e52bcdf3f9f5be0040ab15635c450d44f1ac44c0d472320f04fcb4cc0b1aa36430593c265b88d5b037cfd081d88e45fa15176f4bad68ed0fc7a6a645e2329a3719cc395918e9993c45217da8a6340a8c5450b03ebcfcc0e943c3104d8d3b4303c2225f118c8ca7772280342b86bef7c7b697f1980085898ef94dc68f4bfec3ec34dc0c91248d13030b40c1ad9958310010768e9baaafca41f5bd4cda8c4a8218e621348ad23cbb557c425b6c6b4abcf4f61f7d18cc8d146a9194c6dd6ca1c17623a926bde871439ef77c10a6678ac64484c685a388231ddc9622c03d05f24fa76e473146208e759a291dcad4655a82b5f53ebc7e770f8af88a2fcf31bc9cb69d3f4d0164c2472d144d44addf7ebdcfafd74058662e8798cb820126b703c75f4ea35b8a06997fa6635db57be454ff00fd117aa0713c3c06c8cb9c21a031d4481839b3b80db7ff001c9d48b2a60470afa96c7f1ef88a4d1acd33cb1e2a42b122abac66d78a1777dc",
            "fe1e4e96d9e6f28ad30d2e3ae3b38b0dc5231fddc513c73609b1d050ef7cae9217e78f5e78d32dd49b7370a8761008d3cbe13e3c92b32ef66aaaada6eec51e957d8d71eba9d2536d54915cd06f283c7a8e4751f6d331a4d163ae5bc6560b34e40a2476a3d79fec7d0e95877856f38948418a03ee61107412219dc8e2ba505048344707a11c5f1a522511e7473b0d9099810e18a9dbed55408ef43a76a3a11c986690bb6d95628f6ac733b0dd5744574f95fad75143927794c6a5628ec02590281cd75da3dba75eba9aa1e259997913e8be1397f0bdf22ac6d132a9af168da0b24d8efd49ff00a1a919b261bc8ef8d13aa93c5b0afb57fce9496f0f2648ed5cd56f17d0af6f51cf5ae6b8d0e490a1dac08340d115c558fe34134406dc0f336a6b1640840c7d22c8ebbc0517eba3c8431e46831e54b263c38444411642ca4aaa9b34396f4e3fefa0a6678bc0ce6c69d81d84ab18c83f51ff005c7a71ae93ce673d62c711576ea06b6dfa73871aa4720c90e4bb96f295ec00fcfadf1b38a59ee23e2252ee7ada1491d093d39e2fdb5c11399844a14b16dbfb855dd75e9f5d6b13511149407e34b3454d60e9d752792b55a0ec1cdf7d594c4332a8429275a360d0f4d382584e0a40204591589328bdcc0d71f9ff0076b85e4d75274bbaf9848ae200310d47452cc9200dd681fa1163fbe9bc3f87c793931472e647087600821b77d38afe756bfd47f0cc181711a39a28191361dc18b4800147807a6a6daca1c279955d16643a9d84f9d501cf02eb4f2c616285de27894020c8a09ddc9da7a8e6c1efdbd8daff00fd3ba0b00f47dd18054827804f23f8d64c8aae021b1b68ee51dc73c7de8fd78d636788831cc65e4931a0290e0f8329411cac5775d834458b5256fa1e7563e1ff00048b3313c567ca4c9d9b58cc94bfb5942a8f6f29bf61d3902465e3c9fa182639b1ce2590b052c2c332a1624dfaf06eba5f7d6fe17f12cbc06f0d0468258db6b35004904a926eb8208b3ee0f415075664bd3399d48caba95aa2c7be20323166c294c5958d36d8e421a4a215d7b51ae3bf3cf5d75b31e57843c6d978d8aa46d62cb697d4d1f29e40fa01cebb34f858f999b87f14c76c9901244b1baee32d0bf301fb6ee876ee09e8ac0622b218c63b6d57a695995a8721aae89374145f4e9dcd80b164491e92429fdbe21f116319936f9e78160466f1116a453fb4022f8b240239f4b02c85e379b19e39e26bdac195c29adc28d723922c5ebb2e4498f93388e5249705a48e5277303fb81e2c5f22f9e9adc2eb1ee0e16a450a6d37320e0ee00d0bae9f874d479312c703b4ee3ac7248519b61653b4934037607e7d3b55df6d0ce3e718e22f0cab1c8dfd356046f2ddd477e8391ededa3642e12644a20c8778a898c94e49be01e95eb7f2e07414227c9caf8ca86cc3167c67c32d291e421c0a53ba98d1362a8f3c126f485eb23f98e880f49fe24f49a58b0a4c46450b232c87720ddd38a3d6a8fe59bda4eab1a6c4d8ea029208a7f313e615cffb7edf600c59f21b22613c4ec8cdb834abbda812cc05f2001d45fb5f3ac3cc8eaa235119da0372482477f6bfefe9d0350310ee1cfed18c99f23264492772db142824d9aebdf9ea4e972d77675ef12485451521c77a6e391f4ffd1f4d667fd32470363ccef2325ca1d682b5f41ebc7e734180ac45366c98056edaa7264e36f8862c5b52202cba8b76ee48e78f6bafb9d49ae9674684ddd8bd3b28398a188c4a91b63cb692432bccfc4663a1cd528db5cf357dff00e4b2653c185161b461248dcc8e41e4374008bab000f7edc736a461decc71b36d52cdb45d2f727db406656355a86c04ca07207ccf4f2b248c942d4d120d8fb8ebace2c4f95991e346543cac154b1da068b0ae3499718c9768e12c37b28b207e7e1d09cc618ecb65be091448f96abf41cc4aee789c68dd642ac543035c1047dc75d30b8b3a632e5b44c22762aaf5c123f3f83e9a14d9d2362458b49b118b82146eb35d4fd3f2856164919427884a0375d85f5fec35a98887a6109dc4de85999524b949323b07454556be415502efe635e692815ad04296e74ca05d989678949f27e259df0e32e427890c729679f60bdcc3a13e9c0fe07a6978319f32668a268c108cf7238514059ebf9f4bd2acceb1322b1d8c4122fa91747f93f7d2ccee477e0f3acba7821711cbd905b30c5bcc7cdc69ac8962919a4c38f212031a44fe23eeb200e09f4f2f03daf8e81340aeaccee51141b6db7e6da4a8fa915a3e19ff00e24872250b8c4d940cbbd9c03b78eb5e63678157cdd699801981738820aa78e9a65e492631493b78be12aa2a374dabd071543e5ea7be9606d6ebeba72294181226685510b3b2312bbca8bf31ef63ca003f6bb21bcc0be2725977e4c9911ef40e4dee937373d6cf7bb3a6209f02252dfa479a568ca9f11c6c563c580073ebd7bfb5e907931d8c86290aa502ab27ee3d38e3d2cf3c5d76e9a7313f4cb6e51a555a215980b3defb917d876ee353651b63826e32e726495a39631512db431aed1b6c12adb7a7bdf208f5d627f86c717e9fff0090acd91186454ff692680624803dcf620f1df5bca931e498c98f1c83728dc656dc777737ee7f07418feb2452dc62ac2bee404a9e78b3d0f07eda90bc1188e6ac839801131c331e3c5049248b453f7ca69af72f1c7a50375cd573a4a6653952ac2c1a30e423004022f834791c7aeac60e11cdcf4c772f0ba465e331855626b72f522fadfcbd07227cf8d224ee27903c9c331bb3645907df9a3ef7aaa30dc45c5653b0356389d1932a614986550c7230",
            "72760dd62fa1ebdff2cdae56c6ebe9a23515eba11bd8401cea8057124493cc67271e3c7902c7951e4a9456dc808009175cfe7c8d8188c016469d9703c393215c51403698f84bab2096e6e8115d6ec76ad02287736d2db643c226d625cfa703e9f323dc89861b7994653bb89456631c29f0e8f19ff568f22ba998847355c00479ba8e3afbdf0046f02462d8b089647016399180400f3cb1000b15dcf0791dc4c065e416126c9028f10cbd4bee0a6a859eb7d2faf5efc82538192b24a5d09b1be3abdb744a1ba26b70be47fc4b6e3eb2bbac8be3fa9d970b2638e49bc093c38caac8ccb5b588ba3f9e97575a5d954ad8d672b26179dce1c4d0633ed6f08b13442f3f3e4b51f7d0c483817d7b6aca1aacc836dba5982b60df5f5d1a23dbf9d2ccff00d42a3a6b28cc24e2f5522c44b8795c7894a2f5956f3574d0d8d30602ce86fbb79abb3a2166b8cc85401e6bf9684aa923534ab18eece0d7f00e994c1c69043bfe2d8e85e1691ac37f4d85d29e3a9aff00abe2e6a47b98a195519f852e696fd09ed7d2cf1eb4391968dc2548a9f6985fe9ff00874bfe979657ce562ffd43306da8854301762eb937a8d8f17c3a583f4b1cd2cb2bedf1278903aa02f5c2b2863fb905036771ec0030639e658e6f874ee60dd3a17de0d215dc0d8ebdf9e3b6aae1fc40a29f86e1636393992a84729e21552ffb763b1504d2717d859268881d175b25aecdfc4e91a88d436d50af99b6c78fe1a2459dfc4cc8e8bc2b09221e579666a1d4d74653ebc83a42d9d5d9558851b98817b458167ea47df5ac590e5e6168f30fc3d9226965c891d9bc460e59492075bd83e601e4d02a453b47148a05891429e48ee0f63cf4ef7f7ad5d548bbe641c8c11c468e2652614798f0b8c7918a2c847048fcfe0fa1d3ff000e30b4d59048408cdc102c8048167a5d7bea52b3b46232c4a02485be013566be83edaa1860894edc78f23c8c7648580142c9e08ec0f7d0d40769b8168b0a8f65c0d8d92639239222790b20e7fc8bb17df4d67471c0e921f102ca10088b798280035b762181155d8f038d4c31acaad263210c3733c239d8a00e413d472dc72405e6fae846662cce40058df0001f403a6b9c21359942c05e3e2331cd24692c2b2ed49800ebd8d1b17a6e48efe14652222ce540dbcb29ea6c83df93c9ea0d0e2c28937c4a0861c8469d200dfd3637b2f9e9dbd7f9d378704f9d3b081225665a00af0c6ae870402689eddeab41b1985413d3c98be763c18ee8904c935c6acc5010012071cf3eff005e82ab4bfe9a8875955a1f206908a0a48e411c9e0d8e9e9ea354b3616c50f859455ca83e1ba82db7d81b1c5d837746f8bea9431cb1c81e34f176b1a6da4ab85e4f51c8aea0f63ce8a374f333ad371f89ffd9",
        }),
        Cyber = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000504040404030504040406050506080d0808070708100b0c090d131014131210121214171d1914161c1612121a231a1c1e1f212121141924272420261d202120ffdb0043010506060807080f08080f201512152020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020ffc000110800c000c003012200021101031101ffc4001a000003010101010000000000000000000004050602000703ffc4003010000102040207070501000000000000000102030004050621941114162555b2d115333436446174071324515217ffc4001a010003010101010000000000000000000002030401050006ffc400351100010300050a050402030100000000000100020304111214310613212242517181a1f032416192b10552d1d234c116337223ffda000c03010002110311003f00f30beaf9b929f785525656b33ccb2d4d3a8421130b48480b200001897ff47bb38f54734beb151f51a974137cd634d7003ae3de995fd988eecaa071c196547d6bcc85c483d5727e9b92913a89117363aea1b4cddc53194fa8975a9d00d7aa39a5f586b765ff00734add355618ad4fb4d3736ea50844c2c0480b200034e0211c952a81f786fc1965439bce9541dafabe9ad81f98f7a657f6634192c1d3d56bb24e2bdb4598f03b4cdedf5497fd1eece3d51cd2fac1129f512eb53a01af54734beb0bbb2a81c706595054952a81f786fc19654003257e2eaac9324a1b27523f733f29e5d97fdcd2b74d55862b53ed34dcdba9421130b01202c8000d380845fe8f7671ea8e697d61d5e74aa0ed7d5f4d6c0fcc7bd32bfb3139d9540e3832ca827992d1a8f553d0b24e2347612c8f01b4cddc53194fa8975a9d00d7aa39a5f586b765ff00734add355618ad4fb4d3736ea50844c2c0480b200034e0211c952a81f786fc1965439bce9541dafabe9ad81f98f7a657f6634192c1d3d52dd92715eda2cc781da66f6faa4bfe8f7671ea8e697d60894fa8975a9d00d7aa39a5f585dd9540e3832ca82a4a9540fbc37e0cb2a00192bf17556499250d93a91fb99f94f2ecbfee695ba6aac315a9f69a6e6dd4a108985809016400069c0422ff0047bb38f54734beb0eaf3a55076beafa6b607e63de995fd989cecaa071c1965413cc968d47aa9e8592711a3b0964780da66ee298ca7d44bad4e806bd51cd2fac35bb2ff00b9a56e9aab0c56a7da69b9b75284226160240590001a70108e4a9540fbc37e0cb2a1cde74aa0ed7d5f4d6c0fcc7bd32bfb31a0c960e9ea96ec938af6d1663c0ed337b7d525ff0047bb38f54734beb044a7d44bad4e806bd51cd2fac2eecaa071c1965415254aa07de1bf06595000c95f8baab24c9286c9d48fdccfca79765ff734add355618ad4fb4d3736ea50844c2c0480b200034e02117fa3dd9c7aa39a5f587579d2a83b5f57d35b03f31ef4cafecc4e7655038e0cb2a09e64b46a3d54f42c9388d1d84b23c06d337714c653ea25d6a74035ea8e697d61add97fdcd2b74d55862b53ed34dcdba9421130b01202c8000d380847254aa07de1bf065950e6f3a55076beafa6b607e63de995fd98d064b074f54b7649c57b68b31e07699bdbea92ff00a3dd9c7aa39a5f58eff47bb38f54734beb037655038e0cb2a3bb2a81c7065950bae5fbbaae87f8943f647ee67e533fa8b2efaaf9ac104f8c7b9cc47eaaff00bc7a1dff007657e5af3aab0c5667db69b9b75284226560240590001a701127b677271ea8e697d63d2065b3595f2df4c9299738aa68f08f33bb820a4a59f0f0c4c39bce59f37856313e35ee731893bcee42f0dfb51cd2fac36bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c04680ccd9d27be6b5f2532f6dd5181f33bdbe8a27557fde0a92967c3c31306ed9dc9c7aa39a5f58264ef3b90bc37ed4734beb0b023af13df356492536c9d51ee3faadde72cf9bc2b189f1af73989cd55ff78b6bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c0420db3b938f54734beb07288ed9d27be6a7a0c94cbbc753460368eee08292967c3c3130e6f3967cde158c4f8d7b9cc624ef3b90bc37ed4734beb0daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7011a03336749ef9a5be4a65edbaa303e677b7d144eaaff00bc15252cf8786260ddb3b938f54734beb04c9de7721786fda8e697d6160475e27be6ac924a6d93aa3dc7f55bbce59f37856313e35ee73139aabfef16d775dd703175555966b53edb6dcdba9421332b01202c8000d380841b677271ea8e697d60e511db3a4f7cd4f419299778ea68c06d1ddc105252cf8786261cde72cf9bc2b189f1af7398c49de7721786fda8e697d61b5dd775c0c5d555659ad4fb6db736ea5084ccac0480b200034e02340666ce93df34b7c94cbdb754607ccef6fa289d55ff00782a4a59f0f0c4c1bb677271ea8e697d60993bcee42f0dfb51cd2fac2c08ebc4f7cd592494db27547b8feab779cb3e6f0ac627c6bdce6273557fde2daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7010836cee4e3d51cd2fac1ca23b6749ef9a9e832532ef1d4d180da3bb820a4a59f0f0c4c39bce59f37856313e35ee731893bcee42f0dfb51cd2fac36bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c04680ccd9d27be696f92997b6ea8c0f99dedf4513aabfef1daabfef0df6cee4e3d51cd2fac76d9dc9c7aa39a5f585551ef3df35d0ce537ed1e",
            "e3faa3bea3f9eeb3f35ee7311b177f51651c55f358207ac7b9cc47ea4efea3d2836ca4fd2e46dca2d3b23e174977c21cde9e70ac7cd7b9cc012724e878610e2f29374de158c3d6bdce634039b3c47f6b5f236f6dd3b27e5aa4a0b92ef8476a4efea0a9392743c3085006b56c9236c9d28fbd3ce158f9af73989b8adbca4dd3785630f5af73989dd49dfd41ca0db2a6a0c8dbb47a7c87c2e92ef8439bd3ce158f9af7398024e49d0f0c21c5e526e9bc2b187ad7b9cc100736788fed2df236f6dd3b27e5aa4a0b92ef8476a4efea0a9392743c3085006b56c9236c9d28fbd3ce158f9af73989b8adbca4dd3785630f5af73989dd49dfd41ca0db2a6a0c8dbb47a7c87c2e92ef8439bd3ce158f9af7398024e49d0f0c21c5e526e9bc2b187ad7b9cc100736788fed2df236f6dd3b27e5aa4a0b92ef8476a4efea0a9392743c3085006b56c9236c9d28fbd3ce158f9af73989b8adbca4dd3785630f5af73989dd49dfd41ca0db2a6a0c8dbb47a7c87c2e92ef8439bd3ce158f9af7398024e49d0f0c21c5e526e9bc2b187ad7b9cc100736788fed2df236f6dd3b27e5aa4a3a0bd49dfd476a4efea13515d1ce377af45bfeecafcb5e755618accfb6d3736ea50844cac0480b200034e0224f6cee4e3b51cd2fac5bfd46a5d04df358d35c00eb8f7a657f6623bb2a81c70659515bcc85c483d57be99932d34388911f846d337715b93bcae42f0dfb51cd2fac36bbaeeb818baaaacb3599f6db6e6dd4a109995809016400069c0401254aa07de1bf065950e6f3a55076beafa6b607e63de995fd982064b045aeab5f932dbdb4551e07699bdbeaa5b6cee4e3b51cd2fac1327795c85e1bf6a39a5f58c7655038e0cb2a0a92a5503ef0df832ca858ce57e2eaad93261b64eac7ee67e51f775dd703175555966b33edb6dcdba9421332b01202c8000d380841b677271da8e697d62a6f3a55076beafa6b607e63de995fd989cecaa071c196541c8642e353baa9a83930d3478eb11e03699bb8adc9de5721786fda8e697d61b5dd775c0c5d555659accfb6db736ea5084ccac0480b200034e020092a5503ef0df832ca87379d2a83b5f57d35b03f31ef4cafecc68325822d754b7e4cb6f6d154781da66f6faa96db3b938ed4734beb04c9de5721786fda8e697d631d9540e3832ca82a4a9540fbc37e0cb2a163395f8baab64c986d93ab1fb99f947ddd775c0c5d555659accfb6db736ea5084ccac0480b200034e02106d9dc9c76a39a5f58a9bce9541dafabe9ad81f98f7a657f66273b2a81c706595072190b8d4eeaa6a0e4c34d1e3ac4780da66ee2b727795c85e1bf6a39a5f586d775dd703175555966b33edb6dcdba9421332b01202c8000d3808024a9540fbc37e0cb2a1cde74aa0ed7d5f4d6c0fcc7bd32bfb31a0c9608b5d52df932dbdb4551e07699bdbeaa5b6cee4e3b51cd2fac1327795c85e1bf6a39a5f58c7655038e0cb2a0a92a5503ef0df832ca858ce57e2eaad93261b64eac7ee67e51f775dd703175555966b33edb6dcdba9421332b01202c8000d380841b677271da8e697d62a6f3a55076beafa6b607e63de995fd989cecaa071c196541c8642e353baa9a83930d3478eb11e03699bb8adc9de5721786fda8e697d61b5dd775c0c5d555659accfb6db736ea5084ccac0480b200034e020092a5503ef0df832ca87379d2a83b5f57d35b03f31ef4cafecc68325822d754b7e4cb6f6d154781da66f6faa96db3b938ed4734beb1db677271da8e697d63edd9540e3832ca8eecaa071c196542bff4fbbaae87f8c33ed8fdccfca67f5165df55f358209f18f73988fd55ff0078f43bfeecafcb5e755618accfb6d3736ea50844cac0480b200034e0224f6cee4e3d51cd2fac6c8196cd657c8fd324a65ce2a9a3c23cceee08292967c3c3130e6f3967cde158c4f8d7b9cc624ef3b90bc37ed4734beb0daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7011a03336749ef9ad7c94cbdb754607ccef6fa289d55ff00782a4a59f0f0c4c1bb677271ea8e697d60993bcee42f0dfb51cd2fac2c08ebc4f7cd592494db27547b8feab779cb3e6f0ac627c6bdce6273557fde2daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7010836cee4e3d51cd2fac1ca23b6749ef9a9e832532ef1d4d180da3bb820a4a59f0f0c4c39bce59f37856313e35ee731893bcee42f0dfb51cd2fac36bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c04680ccd9d27be696f92997b6ea8c0f99dedf4513aabfef05494b3e1e1898376cee4e3d51cd2fac132779dc85e1bf6a39a5f585811d789ef9ab24929b64ea8f71fd56ef3967cde158c4f8d7b9cc4e6aaff00bc5b5dd775c0c5d555659ad4fb6db736ea5084ccac0480b200034e02106d9dc9c7aa39a5f58394476ce93df353d064a65de3a9a301b4777041494b3e1e18987379cb3e6f0ac627c6bdce6312779dc85e1bf6a39a5f586d775dd703175555966b53edb6dcdba9421332b01202c8000d3808d0199b3a4f7cd2df2532f6dd5181f33bdbe8a27557fde0a92967c3c31306ed9dc9c7aa39a5f58264ef3b90bc37ed4734beb0b023af13df356492536c9d51ee3faadde72cf9bc2b189f1af73989cd55ff0078b6bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c0420db3b938f54734beb07288ed9d27be6a7a0c94cbbc753460368eee08292967c3c3130e6f3967cde158c4f8d7b9cc624ef3b90bc37ed4734beb0daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7011a0333674",
            "9ef9a5be4a65edbaa303e677b7d144eaaffbc76aaffbc37db3b938f54734beb1db677271ea8e697d615547bcf7cd743394dfb47b8fea8efa8fe7bacfcd7b9cc46c5dfd45947157cd6081eb1ee7311fa93bfa8f4a0db293f4b91b728b4ec8f85d25df08737a79c2b1f35ee730049c93a1e18438bca4dd3785630f5af7398d00e6cf11fdad7c8dbdb74ec9f96a9282e4bbe11da93bfa82a4e49d0f0c21401ad5b248db274a3ef4f38563e6bdce626e2b6f29374de158c3d6bdce62775277f5072836ca9a83236ed1e9f21f0ba4bbe10e6f4f38563e6bdce6009392743c308717949ba6f0ac61eb5ee730401cd9e23fb4b7c8dbdb74ec9f96a9282e4bbe11da93bfa82a4e49d0f0c21401ad5b248db274a3ef4f38563e6bdce626e2b6f29374de158c3d6bdce62775277f5072836ca9a83236ed1e9f21f0ba4bbe10e6f4f38563e6bdce6009392743c308717949ba6f0ac61eb5ee730401cd9e23fb4b7c8dbdb74ec9f96a9282e4bbe11da93bfa82a4e49d0f0c21401ad5b248db274a3ef4f38563e6bdce626e2b6f29374de158c3d6bdce62775277f5072836ca9a83236ed1e9f21f0ba4bbe10e6f4f38563e6bdce6009392743c308717949ba6f0ac61eb5ee730401cd9e23fb4b7c8dbdb74ec9f96a928e82f5277f51da93bfa84d4574738ddebd16ffbb2bf2d79d55862b33edb4dcdba9421132b01202c8000d380893db3b938ed4734beb16ff51a974137cd634d7003ae3de995fd988eecaa071c1965456f3217120f55efa664cb4d0e22447e11b4cddc56e4ef2b90bc37ed4734beb0daeebbae062eaaab2cd667db6db9b75284266560240590001a701004952a81f786fc1965439bce9541dafabe9ad81f98f7a657f6608192c116baad7e4cb6f6d154781da66f6faa96db3b938ed4734beb04c9de5721786fda8e697d631d9540e3832ca82a4a9540fbc37e0cb2a163395f8baab64c986d93ab1fb99f947ddd775c0c5d555659accfb6db736ea5084ccac0480b200034e02106d9dc9c76a39a5f58a9bce9541dafabe9ad81f98f7a657f66273b2a81c706595072190b8d4eeaa6a0e4c34d1e3ac4780da66ee2b727795c85e1bf6a39a5f586d775dd703175555966b33edb6dcdba9421332b01202c8000d3808024a9540fbc37e0cb2a1cde74aa0ed7d5f4d6c0fcc7bd32bfb31a0c9608b5d52df932dbdb4551e07699bdbeaa5b6cee4e3b51cd2fac1327795c85e1bf6a39a5f58c7655038e0cb2a0a92a5503ef0df832ca858ce57e2eaad93261b64eac7ee67e51f775dd703175555966b33edb6dcdba9421332b01202c8000d380841b677271da8e697d62a6f3a55076beafa6b607e63de995fd989cecaa071c196541c8642e353baa9a83930d3478eb11e03699bb8adc9de5721786fda8e697d61b5dd775c0c5d555659accfb6db736ea5084ccac0480b200034e020092a5503ef0df832ca87379d2a83b5f57d35b03f31ef4cafecc68325822d754b7e4cb6f6d154781da66f6faa96db3b938ed4734beb04c9de5721786fda8e697d631d9540e3832ca82a4a9540fbc37e0cb2a163395f8baab64c986d93ab1fb99f947ddd775c0c5d555659accfb6db736ea5084ccac0480b200034e02106d9dc9c76a39a5f58a9bce9541dafabe9ad81f98f7a657f66273b2a81c706595072190b8d4eeaa6a0e4c34d1e3ac4780da66ee2b727795c85e1bf6a39a5f586d775dd703175555966b33edb6dcdba9421332b01202c8000d3808024a9540fbc37e0cb2a1cde74aa0ed7d5f4d6c0fcc7bd32bfb31a0c9608b5d52df932dbdb4551e07699bdbeaa5b6cee4e3b51cd2fac76d9dc9c76a39a5f58fb7655038e0cb2a3bb2a81c7065950aff00d3eeeaba1fe30cfb63f733f299fd45977d57cd60827c63dce623f557fde3d0effbb2bf2d79d55862b33edb4dcdba9421132b01202c8000d380893db3b938f54734beb1b2065b3595f23f4c9299738aa68f08f33bb820a4a59f0f0c4c39bce59f37856313e35ee731893bcee42f0dfb51cd2fac36bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c04680ccd9d27be6b5f2532f6dd5181f33bdbe8a27557fde0a92967c3c31306ed9dc9c7aa39a5f58264ef3b90bc37ed4734beb0b023af13df356492536c9d51ee3faadde72cf9bc2b189f1af73989cd55ff0078b6bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c0420db3b938f54734beb07288ed9d27be6a7a0c94cbbc753460368eee08292967c3c3130e6f3967cde158c4f8d7b9cc624ef3b90bc37ed4734beb0daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7011a03336749ef9a5be4a65edbaa303e677b7d144eaaffbc15252cf8786260ddb3b938f54734beb04c9de7721786fda8e697d6160475e27be6ac924a6d93aa3dc7f55bbce59f37856313e35ee73139aabfef16d775dd703175555966b53edb6dcdba9421332b01202c8000d380841b677271ea8e697d60e511db3a4f7cd4f419299778ea68c06d1ddc105252cf8786261cde72cf9bc2b189f1af7398c49de7721786fda8e697d61b5dd775c0c5d555659ad4fb6db736ea5084ccac0480b200034e02340666ce93df34b7c94cbdb754607ccef6fa289d55ff782a4a59f0f0c4c1bb677271ea8e697d60993bcee42f0dfb51cd2fac2c08ebc4f7cd592494db27547b8feab779cb3e6f0ac627c6bdce6273557fde2daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7010836cee4e3d51cd2fac1ca23b6749ef9a9e832532ef1d4d180da3bb820a4a59f0f0c4c39bce59f3",
            "7856313e35ee731893bcee42f0dfb51cd2fac36bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c04680ccd9d27be696f92997b6ea8c0f99dedf4513aabfef1daabfef0df6cee4e3d51cd2fac76d9dc9c7aa39a5f585551ef3df35d0ce537ed1ee3faa3bea3f9eeb3f35ee7311b177f51651c55f358207ac7b9cc47ea4efea3d2836ca4fd2e46dca2d3b23e174977c21cde9e70ac7cd7b9cc012724e878610e2f29374de158c3d6bdce634039b3c47f6b5f236f6dd3b27e5aa4a0b92ef8476a4efea0a9392743c3085006b56c9236c9d28fbd3ce158f9af73989b8adbca4dd3785630f5af73989dd49dfd41ca0db2a6a0c8dbb47a7c87c2e92ef8439bd3ce158f9af7398024e49d0f0c21c5e526e9bc2b187ad7b9cc100736788fed2df236f6dd3b27e5aa4a0b92ef8476a4efea0a9392743c3085006b56c9236c9d28fbd3ce158f9af73989b8adbca4dd3785630f5af73989dd49dfd41ca0db2a6a0c8dbb47a7c87c2e92ef8439bd3ce158f9af7398024e49d0f0c21c5e526e9bc2b187ad7b9cc100736788fed2df236f6dd3b27e5aa4a0b92ef8476a4efea0a9392743c3085006b56c9236c9d28fbd3ce158f9af73989b8adbca4dd3785630f5af73989dd49dfd41ca0db2a6a0c8dbb47a7c87c2e92ef8439bd3ce158f9af7398024e49d0f0c21c5e526e9bc2b187ad7b9cc100736788fed2df236f6dd3b27e5aa4a3a0bd49dfd476a4efea13515d1ce377af45bfeecafcb5e755618accfb6d3736ea50844cac0480b200034e0224f6cee4e3b51cd2fac5bfd46a5d04df358d35c00eb8f7a657f6623bb2a81c70659515bcc85c483d57be99932d34388911f846d337715b93bcae42f0dfb51cd2fac36bbaeeb818baaaacb3599f6db6e6dd4a109995809016400069c0401254aa07de1bf065950e6f3a55076beafa6b607e63de995fd982064b045aeab5f932dbdb4551e07699bdbeaa5b6cee4e3b51cd2fac1327795c85e1bf6a39a5f58c7655038e0cb2a0a92a5503ef0df832ca858ce57e2eaad93261b64eac7ee67e51f775dd703175555966b33edb6dcdba9421332b01202c8000d380841b677271da8e697d62a6f3a55076beafa6b607e63de995fd989cecaa071c196541c8642e353baa9a83930d3478eb11e03699bb8adc9de5721786fda8e697d61b5dd775c0c5d555659accfb6db736ea5084ccac0480b200034e020092a5503ef0df832ca87379d2a83b5f57d35b03f31ef4cafecc68325822d754b7e4cb6f6d154781da66f6faa96db3b938ed4734beb04c9de5721786fda8e697d631d9540e3832ca82a4a9540fbc37e0cb2a163395f8baab64c986d93ab1fb99f947ddd775c0c5d555659accfb6db736ea5084ccac0480b200034e02106d9dc9c76a39a5f58a9bce9541dafabe9ad81f98f7a657f66273b2a81c706595072190b8d4eeaa6a0e4c34d1e3ac4780da66ee2b727795c85e1bf6a39a5f586d775dd703175555966b33edb6dcdba9421332b01202c8000d3808024a9540fbc37e0cb2a1cde74aa0ed7d5f4d6c0fcc7bd32bfb31a0c9608b5d52df932dbdb4551e07699bdbeaa5b6cee4e3b51cd2fac1327795c85e1bf6a39a5f58c7655038e0cb2a0a92a5503ef0df832ca858ce57e2eaad93261b64eac7ee67e51f775dd703175555966b33edb6dcdba9421332b01202c8000d380841b677271da8e697d62a6f3a55076beafa6b607e63de995fd989cecaa071c196541c8642e353baa9a83930d3478eb11e03699bb8adc9de5721786fda8e697d61b5dd775c0c5d555659accfb6db736ea5084ccac0480b200034e020092a5503ef0df832ca87379d2a83b5f57d35b03f31ef4cafecc68325822d754b7e4cb6f6d154781da66f6faa96db3b938ed4734beb1db677271da8e697d63edd9540e3832ca8eecaa071c196542bff004fbbaae87f8c33ed8fdccfca67f5165df55f358209f18f73988fd55ff78f43bfeecafcb5e755618accfb6d3736ea50844cac0480b200034e0224f6cee4e3d51cd2fac6c8196cd657c8fd324a65ce2a9a3c23cceee08292967c3c3130e6f3967cde158c4f8d7b9cc624ef3b90bc37ed4734beb0daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7011a03336749ef9ad7c94cbdb754607ccef6fa289d55ff782a4a59f0f0c4c1bb677271ea8e697d60993bcee42f0dfb51cd2fac2c08ebc4f7cd592494db27547b8feab779cb3e6f0ac627c6bdce6273557fde2daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7010836cee4e3d51cd2fac1ca23b6749ef9a9e832532ef1d4d180da3bb820a4a59f0f0c4c39bce59f37856313e35ee731893bcee42f0dfb51cd2fac36bbaeeb818baaaacb35a9f6db6e6dd4a109995809016400069c04680ccd9d27be696f92997b6ea8c0f99dedf4513aabfef05494b3e1e1898376cee4e3d51cd2fac132779dc85e1bf6a39a5f585811d789ef9ab24929b64ea8f71fd56ef3967cde158c4f8d7b9cc4e6aaffbc5b5dd775c0c5d555659ad4fb6db736ea5084ccac0480b200034e02106d9dc9c7aa39a5f58394476ce93df353d064a65de3a9a301b4777041494b3e1e18987379cb3e6f0ac627c6bdce6312779dc85e1bf6a39a5f586d775dd703175555966b53edb6dcdba9421332b01202c8000d3808d0199b3a4f7cd2df2532f6dd5181f33bdbe8a27557fde0a92967c3c31306ed9dc9c7aa39a5f58264ef3b90bc37ed4734beb0b023af13df356492536c9d51ee3faadde72cf9bc2b189f1af73989cd55ff78b6bbaeeb818baaaacb35a9f6db6e6dd4a10",
            "9995809016400069c0420db3b938f54734beb07288ed9d27be6a7a0c94cbbc753460368eee08292967c3c3130e6f3967cde158c4f8d7b9cc624ef3b90bc37ed4734beb0daeebbae062eaaab2cd6a7db6db9b75284266560240590001a7011a03336749ef9a5be4a65edbaa303e677b7d144eaaff00bc76aaff00bc37db3b938f54734beb1db677271ea8e697d615547bcf7cd743394dfb47b8fea8efa8fe7bacfcd7b9cc46c597d47f3dd67e6bdce6236325f1941f4afe145ff23e11725df08737a79c2b1f35ee7309a4bbe10e6f4f38563e6bdce63c3fd678a27ff31bff0027e5aa6e0b92ef840905c977c2163156c9e129cde9e70ac7cd7b9cc4dc525e9e70ac7cd7b9cc4dc1cbe32a6a07f1a3e03e11725df08737a79c2b1f35ee7309a4bbe10e6f4f38563e6bdce6347facf14b7ff31bff0027e5aa6e0b92ef840905c977c2163156c9e129cde9e70ac7cd7b9cc4dc525e9e70ac7cd7b9cc4dc1cbe32a6a07f1a3e03e11725df08737a79c2b1f35ee7309a4bbe10e6f4f38563e6bdce6347facf14b7ff31bff0027e5aa6e0b92ef840905c977c2163156c9e129cde9e70ac7cd7b9cc4dc525e9e70ac7cd7b9cc4dc1cbe32a6a07f1a3e03e11725df08737a79c2b1f35ee7309a4bbe10e6f4f38563e6bdce6347facf14b7ff31bff0027e5aa6e3a3a3a14ba2bffd9",
        }),
    }

    local assetFn = getcustomasset or getsynasset
    local hasFs = typeof(writefile) == "function" and typeof(isfile) == "function"
        and typeof(makefolder) == "function" and typeof(isfolder) == "function"

    local W = Color3.new(1, 1, 1)
    -- name, texture, material слоя-текстуры, tint1, tint2, shimmer1, shimmer2, sparkles(цвет) 
    local STYLES = {
        {"Galaxy (reference)", "Galaxy", Enum.Material.Neon, W, Color3.fromRGB(175, 195, 255), Color3.fromRGB(90, 170, 255), Color3.fromRGB(170, 110, 255), Color3.fromRGB(190, 225, 255)},
        {"Nebula",             "Nebula", Enum.Material.Neon, W, Color3.fromRGB(255, 190, 235), Color3.fromRGB(255, 90, 200), Color3.fromRGB(130, 90, 255), Color3.fromRGB(255, 200, 245)},
        {"Aurora",             "Aurora", Enum.Material.Neon, W, Color3.fromRGB(190, 255, 225), Color3.fromRGB(60, 255, 170), Color3.fromRGB(120, 110, 255), Color3.fromRGB(200, 255, 235)},
    }
    local SECOND = {Galaxy = "Aurora", Nebula = "Galaxy", Aurora = "Cyber", Lava = "Nebula", Ice = "Galaxy", Cyber = "Nebula", Gold = "Galaxy", Rainbow = "Nebula"}
    L.wcStyleNames = {}
    for i, st in ipairs(STYLES) do L.wcStyleNames[i] = st[1] end

    local HOLDER = "ScorpionChamsModel"
    local OVL = "ScorpionChamsOverlay"
    local holder
    local states = {}      -- деталь -> {orig..., E=эмиттер}
    local hls = {}         -- корень оружия -> Highlight
    local texIds = {}
    local list, listT = {}, 0
    local lastSig
    local t0 = os.clock()

    local function textureFor(key)
        if not key then return nil end
        if texIds[key] then return texIds[key] end
        if not (hasFs and assetFn) then return nil end
        local ok = pcall(function()
            if not isfolder("scorpion") then makefolder("scorpion") end
            if not isfolder("scorpion/tex") then makefolder("scorpion/tex") end
            local path = "scorpion/tex/" .. key .. "_v2.jpg"
            if not isfile(path) then
                writefile(path, (TEX_DATA[key]:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)))
            end
            texIds[key] = assetFn(path)
        end)
        return ok and texIds[key] or nil
    end

    local function getHolder()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        if holder and holder.Parent == cam then return holder end
        if holder then holder:Destroy() end
        holder = new("Model", {Name = HOLDER, Parent = cam})
        hls = {}
        return holder
    end

    local function valid(d)
        if not d:IsA("BasePart") or isArmPart(d) then return false end
        if d.Name == OVL or d.Name == "ScorpionTrace" or d:FindFirstAncestor(HOLDER) then return false end
        return d.Transparency < 0.95
    end

    local function collect()
        local out = {}
        local function scan(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if valid(d) then out[#out + 1] = d end
                if #out >= 140 then return end
            end
        end
        if cfg.wcViewmodel then
            local cam = workspace.CurrentCamera
            if cam then
                for _, ch in ipairs(cam:GetChildren()) do
                    if ch.Name ~= HOLDER then
                        if ch:IsA("BasePart") then
                            if valid(ch) then out[#out + 1] = ch end
                        else
                            scan(ch)
                        end
                    end
                end
            end
        end
        if cfg.wcThird then
            local char = player.Character
            scan(char and char:FindFirstChildOfClass("Tool"))
        end
        return out
    end

    -- запоминаем оригинальные свойства детали, чтобы вернуть при выключении
    local function adopt(part)
        local st = {Color = part.Color, Material = part.Material, extra = {}, sa = {}, l2 = nil}
        if part:IsA("MeshPart") then
            st.mesh = part
            st.TexId = part.TextureID
        else
            local m = part:FindFirstChildWhichIsA("SpecialMesh")
            if m then st.sm = m st.TexId = m.TextureId end
        end
        for _, ch in ipairs(part:GetChildren()) do
            if ch:IsA("SurfaceAppearance") then st.sa[#st.sa + 1] = ch end
        end
        return st
    end

    local function restore(part, st)
        if st.E then st.E:Destroy() st.E = nil end
        for _, x in ipairs(st.extra) do x:Destroy() end
        st.extra = {}
        for _, x in ipairs(st.l2 or {}) do x:Destroy() end
        st.l2 = nil
        if not part.Parent then return end
        pcall(function()
            part.Color = st.Color
            part.Material = st.Material
            if st.mesh then st.mesh.TextureID = st.TexId end
            if st.sm then st.sm.TextureId = st.TexId end
            for _, sa in ipairs(st.sa) do
                if sa.Parent ~= part then sa.Parent = part end
            end
        end)
    end

    local function clearAll()
        for part, st in pairs(states) do
            restore(part, st)
            states[part] = nil
        end
        for r, h in pairs(hls) do h:Destroy() hls[r] = nil end
        if holder then holder:Destroy() holder = nil end
    end

    local function ensureSparkles(part, st, color)
        local want = cfg.wcSparkles and part.Size.Magnitude > 0.25
        if not want then
            if st.E then st.E:Destroy() st.E = nil end
            return
        end
        if not st.E then
            local n = 0
            for _, oo in pairs(states) do if oo.E then n += 1 end end
            if n >= 16 then return end
            local ok, em = pcall(function()
                return new("ParticleEmitter", {
                    Name = "ScorpionSpark", Texture = "rbxasset://textures/particles/sparkles_main.dds",
                    LightEmission = 1, LightInfluence = 0, LockedToPart = true, Lifetime = NumberRange.new(0.5, 1.1),
                    Speed = NumberRange.new(0, 0.4), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360),
                    RotSpeed = NumberRange.new(-60, 60), ZOffset = 1,
                    Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.14), NumberSequenceKeypoint.new(1, 0)}),
                    Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0), NumberSequenceKeypoint.new(1, 1)}),
                    Shape = Enum.ParticleEmitterShape.Box, ShapeInOut = Enum.ParticleEmitterShapeInOut.Surface, Parent = part,
                })
            end)
            if not ok then return end
            st.E = em
        end
        st.E.Rate = cfg.wcSparkDensity
        st.E.Color = ColorSequence.new(W, color)
    end

    local function rootOf(part)
        local cam = workspace.CurrentCamera
        local r = part
        while r.Parent and r.Parent ~= cam and r.Parent ~= workspace and r.Parent ~= game do
            local tool = r:IsA("Tool")
            if tool then return r end
            r = r.Parent
        end
        return r
    end

    local STEP = "ScorpionChams"
    RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value - 1, function(dt)
        if unloaded then return end
        if not cfg.wcEnabled then
            if next(states) or holder then clearAll() end
            return
        end

        local style = STYLES[cfg.wcStyle] or STYLES[1]
        local tex = textureFor(style[2])
        local tex2 = textureFor(SECOND[style[2] or style[1]])
        local sig = table.concat({cfg.wcStyle, tostring(tex ~= nil), tostring(tex2 ~= nil), tostring(cfg.wcShimmer), tostring(cfg.wcViewmodel), tostring(cfg.wcThird)}, "|")
        if sig ~= lastSig then
            lastSig = sig
            clearAll()
            listT = 0
        end

        listT -= dt
        if listT <= 0 then
            listT = 0.4
            list = collect()
            local alive = {}
            for _, part in ipairs(list) do
                alive[part] = true
                if not states[part] then states[part] = adopt(part) end
            end
            for part, st in pairs(states) do
                if not alive[part] or not part.Parent then
                    restore(part, st)
                    states[part] = nil
                end
            end
        end

        -- цвета
        local t = os.clock() - t0
        local k = (math.sin(t * cfg.wcSpeed / 10) + 1) / 2
        local tintA, shimB, spark
        if cfg.wcCustom then
            tintA = (ColorPresets[cfg.wcColor] or ColorPresets[1])[2]
            shimB = (ColorPresets[cfg.wcColor2] or ColorPresets[1])[2]
            spark = tintA:Lerp(W, 0.5)
        elseif style[1] == "Rainbow" then
            local h = (t * cfg.wcSpeed / 100) % 1
            tintA = Color3.fromHSV(h, 0.8, 1)
            shimB = Color3.fromHSV((h + 0.5) % 1, 0.8, 1)
            spark = W
        else
            tintA = style[4]:Lerp(style[5], k)
            shimB = style[6]:Lerp(style[7], 1 - k)
            spark = style[8]
        end
        local mix = 1 - (cfg.wcTransparency / 100) * 0.6

        -- красим сами детали оружия каждый кадр (игра может сбрасывать свойства)
        local roots = {}
        local nLayer2 = 0
        for _, st in pairs(states) do if st.l2 then nLayer2 = nLayer2 + 1 end end
        for part, st in pairs(states) do
            if part.Parent then
                local col = st.Color:Lerp(tintA, mix)
                local mat = style[3]
                if tex then
                    col = W:Lerp(tintA, 0.3)
                    if mat == Enum.Material.Neon or mat == Enum.Material.Glass then mat = Enum.Material.SmoothPlastic end
                end
                pcall(function()
                    if part.Material ~= mat then part.Material = mat end
                    if part.Color ~= col then part.Color = col end
                    if tex then
                        for _, sa in ipairs(st.sa) do
                            if sa.Parent == part then sa.Parent = nil end
                        end
                        if st.mesh then
                            if st.mesh.TextureID ~= tex then st.mesh.TextureID = tex end
                        elseif st.sm then
                            if st.sm.TextureId ~= tex then st.sm.TextureId = tex end
                        elseif #st.extra == 0 then
                            for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
                                st.extra[#st.extra + 1] = new("Texture", {Name = OVL, Texture = tex, Face = face, StudsPerTileU = 1.5, StudsPerTileV = 1.5, Parent = part})
                            end
                        end
                    end
                end)
                -- второй слой: движущаяся полупрозрачная текстура поверх основной
                if cfg.wcShimmer and tex2 and part.Size.Magnitude > 0.15 then
                    if not st.l2 then
                        if nLayer2 < 60 then
                            nLayer2 = nLayer2 + 1
                            st.l2 = {}
                            pcall(function()
                                for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
                                    st.l2[#st.l2 + 1] = new("Texture", {Name = OVL, Texture = tex2, Face = face, StudsPerTileU = 2.6, StudsPerTileV = 2.6, Transparency = 0.45, Parent = part})
                                end
                            end)
                        end
                    else
                        local ou = (t * cfg.wcSpeed / 40) % 2.6
                        local ov = (t * cfg.wcSpeed / 70) % 2.6
                        for _, x in ipairs(st.l2) do
                            x.OffsetStudsU, x.OffsetStudsV = ou, ov
                            x.Color3 = shimB
                        end
                    end
                elseif st.l2 then
                    for _, x in ipairs(st.l2) do x:Destroy() end
                    st.l2 = nil
                end
                local shown = part.LocalTransparencyModifier < 0.95
                if st.E then st.E.Enabled = shown end
                ensureSparkles(part, st, spark)
                roots[rootOf(part)] = true
            end
        end

        -- свечение/контур на корне оружия
        local h = getHolder()
        local nHl = 0
        for r in pairs(roots) do
            nHl += 1
            if nHl > 8 then break end
            local hl = hls[r]
            if cfg.wcGlow and h then
                if not hl or hl.Parent ~= h then
                    hl = new("Highlight", {Name = "ScorpionWC", Adornee = r, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = h})
                    hls[r] = hl
                end
                hl.FillColor, hl.OutlineColor = shimB, shimB
                hl.FillTransparency, hl.OutlineTransparency = (cfg.wcShimmer and (0.55 + 0.25 * k) or 0.85), 0.1
            elseif hl then
                hl:Destroy()
                hls[r] = nil
            end
        end
        for r, hl in pairs(hls) do
            if not roots[r] or not r.Parent then hl:Destroy() hls[r] = nil end
        end
    end)

    function L.wcCleanup()
        pcall(function() RunService:UnbindFromRenderStep(STEP) end)
        clearAll()
    end
end)()
end

-- ---------- трассеры пуль ----------
do
(function()
    local rayP = RaycastParams.new()
    rayP.FilterType = Enum.RaycastFilterType.Exclude
    rayP.IgnoreWater = true
    local active = 0
    local holdId = 0

    local function weaponInHand()
        local c = player.Character
        return (c and c:FindFirstChildOfClass("Tool") ~= nil) or #L.vmModels() > 0
    end

    local function mk(size, cf, color, transp)
        local part = new("Part", {
            Name = "ScorpionTrace", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
            CastShadow = false, Material = Enum.Material.Neon, Color = color, Transparency = transp or 0,
            Size = size, CFrame = cf, Parent = workspace,
        })
        return part
    end

    local function fade(part, life, goal)
        goal.Transparency = 1
        TweenService:Create(part, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
        task.delay(life + 0.1, function() part:Destroy() end)
    end

    local function muzzlePos(cam)
        if cfg.tracerFrom == 1 then
            local roots = L.vmModels()
            local char = player.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then roots[#roots + 1] = tool end
            for _, root in ipairs(roots) do
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("BasePart") or d:IsA("Attachment") then
                        local n = d.Name:lower()
                        if n:find("muzzle", 1, true) or n:find("barrel", 1, true) or n:find("flash", 1, true) then
                            return d:IsA("Attachment") and d.WorldPosition or d.Position
                        end
                    end
                end
            end
        end
        return cam.CFrame.Position + cam.CFrame:VectorToWorldSpace(Vector3.new(0.9, -0.8, -2.5))
    end

    local function impact(hit, color)
        local part = new("Part", {
            Name = "ScorpionTrace", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
            Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
            CFrame = CFrame.lookAt(hit.Position, hit.Position + hit.Normal), Parent = workspace,
        })
        local e = new("ParticleEmitter", {
            Texture = SPARK, Color = ColorSequence.new(color), Lifetime = NumberRange.new(0.25, 0.55),
            Speed = NumberRange.new(8, 18), SpreadAngle = Vector2.new(55, 55), EmissionDirection = Enum.NormalId.Front,
            LightEmission = 1, LightInfluence = 0, Rate = 0,
            Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0)}),
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
            Parent = part,
        })
        e:Emit(14)
        local ring = mk(Vector3.new(0.1, 0.1, 0.1), CFrame.lookAt(hit.Position + hit.Normal * 0.05, hit.Position + hit.Normal) * CFrame.Angles(0, math.rad(90), 0), color, 0.2)
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.05, 0.3, 0.3)
        fade(ring, 0.35, {Size = Vector3.new(0.05, 2.2, 2.2)})
        task.delay(1, function() part:Destroy() end)
    end

    local function shoot()
        if active > 70 then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local ignore = {cam}
        if player.Character then ignore[2] = player.Character end
        rayP.FilterDescendantsInstances = ignore

        local origin, look = cam.CFrame.Position, cam.CFrame.LookVector
        local hit = workspace:Raycast(origin, look * 2000, rayP)
        local endPos = hit and hit.Position or (origin + look * 500)
        local startPos = muzzlePos(cam)
        local len = (endPos - startPos).Magnitude
        if len < 2 then return end

        local color = cfg.tracerRainbow and rainbowColor() or (ColorPresets[cfg.tracerColor] or ColorPresets[1])[2]
        local thick = 0.1 * cfg.tracerThick / 100
        local life = cfg.tracerLife / 100
        local style = cfg.tracerStyle
        active += 1
        task.delay(life + 0.3, function() active -= 1 end)

        local dir = (endPos - startPos).Unit
        if style == 1 then
            -- Laser: тонкий неоновый луч, который гаснет
            local part = mk(Vector3.new(thick, thick, len), CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -len / 2), color, 0.05)
            fade(part, life, {Size = Vector3.new(thick * 0.15, thick * 0.15, len)})
        elseif style == 2 then
            -- Lightning: рваная молния
            local n = math.clamp(math.floor(len / 5), 5, 28)
            local right = dir:Cross(Vector3.new(0, 1, 0))
            if right.Magnitude < 0.1 then right = Vector3.new(1, 0, 0) end
            right = right.Unit
            local up = right:Cross(dir).Unit
            local pts = {startPos}
            for i = 1, n - 1 do
                local base = startPos + dir * (len * i / n)
                local amp = 0.5 * math.min(1, i / 3, (n - i) / 3)
                pts[#pts + 1] = base + right * (math.random() - 0.5) * 2 * amp + up * (math.random() - 0.5) * 2 * amp
            end
            pts[#pts + 1] = endPos
            for i = 1, #pts - 1 do
                local a, b = pts[i], pts[i + 1]
                local l = (b - a).Magnitude
                if l > 0.01 then
                    local seg = mk(Vector3.new(thick * 1.3, thick * 1.3, l), CFrame.lookAt(a, b) * CFrame.new(0, 0, -l / 2), color, 0)
                    fade(seg, life, {Size = Vector3.new(thick * 0.2, thick * 0.2, l)})
                end
            end
        elseif style == 3 then
            -- Comet: яркий снаряд с хвостом летит от ствола к цели
            local head = mk(Vector3.new(thick * 2, thick * 2, thick * 6), CFrame.lookAt(startPos, endPos), color, 0)
            local a0 = new("Attachment", {Position = Vector3.new(0, thick, 0), Parent = head})
            local a1 = new("Attachment", {Position = Vector3.new(0, -thick, 0), Parent = head})
            new("Trail", {
                Attachment0 = a0, Attachment1 = a1, Lifetime = math.max(0.12, life * 0.5), Color = ColorSequence.new(color),
                LightEmission = 1, FaceCamera = true,
                Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
                WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
                Parent = head,
            })
            local flight = math.clamp(len / 600, 0.05, 0.35)
            TweenService:Create(head, TweenInfo.new(flight, Enum.EasingStyle.Linear), {CFrame = CFrame.lookAt(endPos, endPos + dir)}):Play()
            task.delay(flight + math.max(0.15, life * 0.5), function() head:Destroy() end)
        else
            -- Dots: цепочка светящихся точек, гаснущих по очереди
            local count = math.clamp(math.floor(len / 4), 4, 36)
            for i = 1, count do
                local pos = startPos + dir * (len * i / count)
                local dot = mk(Vector3.new(thick * 2.2, thick * 2.2, thick * 2.2), CFrame.new(pos), color, 0)
                dot.Shape = Enum.PartType.Ball
                task.delay((i / count) * life * 0.4, function()
                    if dot.Parent then fade(dot, life * 0.6, {Size = Vector3.new(0.01, 0.01, 0.01)}) end
                end)
            end
        end

        if cfg.tracerImpact and hit then impact(hit, color) end
    end

    -- ===== состояние оружия: патроны и перезарядка =====
    local function ammoName(n)
        n = n:lower()
        if n:find("max", 1, true) or n:find("reserve", 1, true) or n:find("total", 1, true) or n:find("cap", 1, true)
            or n:find("spare", 1, true) or n:find("stock", 1, true) or n:find("extra", 1, true) or n:find("damage", 1, true)
            or n:find("speed", 1, true) or n:find("rate", 1, true) or n:find("reload", 1, true) or n:find("recoil", 1, true) then
            return false
        end
        return n:find("ammo", 1, true) or n:find("clip", 1, true) or n:find("bullet", 1, true) or n:find("magazine", 1, true)
            or n:find("^mag") or n:find("mag$") or n:find("rounds", 1, true)
    end

    local src, lastV, sig, scanT, noticed = nil, nil, nil, 0, false
    local reloading = false

    local function readSrc(sc)
        if not sc or not sc.inst or not sc.inst.Parent then return nil end
        if sc.kind == "value" then return tonumber(sc.inst.Value) end
        if sc.kind == "attr" then return tonumber(sc.inst:GetAttribute(sc.key)) end
        local txt = sc.inst.Text
        return tonumber(txt:match("^%s*(%d+)") or txt:match("(%d+)"))
    end

    local function findSource()
        local char = player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        local roots = {}
        if tool then roots[#roots + 1] = tool end
        for _, m in ipairs(L.vmModels()) do roots[#roots + 1] = m end
        for _, root in ipairs(roots) do
            for k, v in pairs(root:GetAttributes()) do
                if type(v) == "number" and ammoName(k) then return {kind = "attr", inst = root, key = k, name = root.Name .. "." .. k} end
            end
            for _, d in ipairs(root:GetDescendants()) do
                if (d:IsA("IntValue") or d:IsA("NumberValue")) and ammoName(d.Name) then
                    return {kind = "value", inst = d, name = d.Name}
                end
            end
        end
        if char then
            for k, v in pairs(char:GetAttributes()) do
                if type(v) == "number" and ammoName(k) then return {kind = "attr", inst = char, key = k, name = "character." .. k} end
            end
        end
        for k, v in pairs(player:GetAttributes()) do
            if type(v) == "number" and ammoName(k) then return {kind = "attr", inst = player, key = k, name = "player." .. k} end
        end
        -- счётчик патронов в интерфейсе игры
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, d in ipairs(pg:GetDescendants()) do
                if d:IsA("TextLabel") and ammoName(d.Name) and d.Text:match("%d+") then
                    return {kind = "gui", inst = d, name = d.Name}
                end
            end
        end
        return nil
    end

    local function weaponSig()
        local char = player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then return "t:" .. tool.Name end
        local m = L.vmModels()[1]
        return m and ("v:" .. m.Name) or "none"
    end

    local function rescan(announce)
        src = findSource()
        lastV = readSrc(src)
        if announce then
            if src then
                Notify("tracers: ammo counter '" .. src.name .. "' = " .. tostring(lastV))
            else
                Notify("tracers: no ammo counter found, click mode")
            end
        end
    end
    L.tracerScan = function() rescan(true) end

    local function checkReload()
        local char = player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        for _, o in ipairs({tool, char, player}) do
            if o then
                for k, v in pairs(o:GetAttributes()) do
                    if v == true and k:lower():find("reload", 1, true) then return true end
                end
            end
        end
        local function tracks(animator)
            if not animator then return false end
            for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                local n = (tr.Name or ""):lower()
                local an = tr.Animation and tr.Animation.Name:lower() or ""
                if n:find("reload", 1, true) or an:find("reload", 1, true) then return true end
            end
            return false
        end
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if tracks(hum and hum:FindFirstChildOfClass("Animator")) then return true end
        for _, m in ipairs(L.vmModels()) do
            if tracks(m:FindFirstChildWhichIsA("Animator", true)) then return true end
        end
        return false
    end

    local function canFire()
        if reloading then return false end
        local v = readSrc(src)
        if v ~= nil and v <= 0 then return false end
        return true
    end

    local checkT = 0
    bind(RunService.Heartbeat, function(dt)
        if unloaded or not cfg.tracerEnabled then return end
        checkT -= dt
        if checkT <= 0 then
            checkT = 0.1
            reloading = checkReload()
            local sg = weaponSig()
            scanT -= 0.1
            if sg ~= sig then
                sig = sg
                scanT = 4
                rescan(true)
            elseif (not src or not src.inst.Parent) and scanT <= 0 then
                scanT = 4
                rescan(false)
            end
        end
        -- реальный выстрел = патронов стало меньше
        if cfg.tracerDetect == 1 and src then
            local v = readSrc(src)
            if v ~= nil then
                if lastV and v < lastV and lastV - v <= 3 and not reloading and not MainFrame.Visible and not FCApi.active then
                    shoot()
                end
                lastV = v
            end
        end
    end)

    -- режим без счётчика патронов (или Click only): по нажатию, но не во время перезарядки / с пустой обоймой
    bind(UserInputService.InputBegan, function(i)
        if unloaded or not cfg.tracerEnabled or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if cfg.tracerDetect == 1 and src then return end
        if MainFrame.Visible or FCApi.active or UserInputService:GetFocusedTextBox() or not weaponInHand() then return end
        if not canFire() then return end
        shoot()
        holdId += 1
        local my = holdId
        task.spawn(function()
            while true do
                task.wait(math.max(0.03, cfg.tracerRate / 1000))
                if my ~= holdId or unloaded or not cfg.tracerEnabled or not cfg.tracerRepeat
                    or not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                    or not weaponInHand() or not canFire() then
                    break
                end
                shoot()
            end
        end)
    end)

    function L.tracerCleanup()
        holdId += 1
        for _, d in ipairs(workspace:GetChildren()) do
            if d.Name == "ScorpionTrace" then d:Destroy() end
        end
    end
end)()
end

-- ---------- визуальное удаление отдачи ----------
do
(function()
    local STEP = "ScorpionRecoil"
    local Cr = CFrame.new()
    local prevOut
    local lastShot = 0
    local restOffset = setmetatable({}, {__mode = "k"})

    bind(UserInputService.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then lastShot = os.clock() end
    end)

    local function angleOf(cf)
        local _, ang = cf:ToAxisAngle()
        return math.abs(ang)
    end

    RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value - 1, function(dt)
        local cam = workspace.CurrentCamera
        if not cam or unloaded then return end
        if not (cfg.noRecoil or cfg.noKickVm) or FCApi.active or L.aimEngaged or MainFrame.Visible then
            Cr, prevOut = CFrame.new(), nil
            return
        end
        local now = os.clock()
        local pressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        if pressed then lastShot = now end
        local recent = now - lastShot < 0.9
        local raw = cam.CFrame
        local rawRot = raw - raw.Position

        if cfg.noRecoil then
            -- delta мыши доступен только при залоченном курсоре
            local locked = UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default
            local still = locked and UserInputService:GetMouseDelta().Magnitude < 2
            if recent and still and prevOut then
                Cr = Cr:Lerp(prevOut * rawRot:Inverse(), cfg.noRecoilPct / 100)
            elseif not recent then
                Cr = Cr:Lerp(CFrame.new(), 1 - math.exp(-dt * 5))
            end
            local out = Cr * rawRot
            prevOut = out
            if angleOf(Cr) > 0.0005 then
                local outCF = CFrame.new(raw.Position) * out
                cam.CFrame = outCF
                -- вьюмодель привязана к «сырой» камере: сдвигаем её вместе с исправлением
                local delta = outCF * raw:Inverse()
                for _, vm in ipairs(L.vmModels()) do
                    pcall(function() vm:PivotTo(delta * vm:GetPivot()) end)
                end
            end
        end

        if cfg.noKickVm then
            for _, vm in ipairs(L.vmModels()) do
                local ok, pivot = pcall(function() return vm:GetPivot() end)
                if ok then
                    if recent and restOffset[vm] then
                        pcall(function() vm:PivotTo(cam.CFrame * restOffset[vm]) end)
                    elseif not recent then
                        restOffset[vm] = cam.CFrame:ToObjectSpace(pivot)
                    end
                end
            end
        end
    end)

    function L.recoilCleanup()
        pcall(function() RunService:UnbindFromRenderStep(STEP) end)
    end
end)()
end

-- ============================================================
--  МЕНЮ: наполнение вкладок
-- ============================================================
local TabSet = {}
TabSet.Visuals = CreateTab("Visuals")
TabSet.Models = CreateTab("Models")
TabSet.ESP = CreateTab("ESP")
TabSet.Hitbox = CreateTab("Hitbox")
TabSet.Aim = CreateTab("Aim")
TabSet.World = CreateTab("World")
TabSet.Weather = CreateTab("Weather")
TabSet.Camera = CreateTab("Camera")
TabSet.Sky = CreateTab("Sky")
TabSet.FX = CreateTab("Effects")
TabSet.Settings = CreateTab("Settings")

-- Visuals
do
    local g = CreateGroup(TabSet.Visuals.Left, "Crosshair")
    CfgToggle(g, "Enable crosshair", "crosshairEnabled")
    CfgSlider(g, {Text = "Offset X", Min = -150, Max = 150, Step = 1}, "cOffX")
    CfgSlider(g, {Text = "Offset Y", Min = -150, Max = 150, Step = 1}, "cOffY")
    CfgDropdown(g, {Text = "Style", Options = {"Cross", "Dot", "Spinning cross", "T-shape", "Circle", "Cross + dot", "X-cross", "Circle + dot", "Dynamic cross"}}, "crosshairStyle")
    CfgDropdown(g, {Text = "Color", Options = ColorNames}, "cColor")
    CfgToggle(g, "Rainbow color", "cRainbow")
    CfgToggle(g, "Outline", "cOutline")
    CfgSlider(g, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct}, "cAlpha")
    CfgSlider(g, {Text = "Length / size", Min = 2, Max = 30}, "cLength")
    CfgSlider(g, {Text = "Thickness", Min = 1, Max = 8}, "cThickness")
    CfgSlider(g, {Text = "Gap", Min = 0, Max = 20}, "cGap")
    CfgSlider(g, {Text = "Spin speed", Min = 0, Max = 400}, "cSpeed")

    local hud = CreateGroup(TabSet.Visuals.Right, "HUD")
    CfgToggle(hud, "Info bar", "hudEnabled")
    CfgToggle(hud, "Show FPS", "hudFps")
    CfgToggle(hud, "Show ping", "hudPing")

    local rd = CreateGroup(TabSet.Visuals.Right, "Radar")
    CfgToggle(rd, "Enable radar", "radarEnabled")
    CfgSlider(rd, {Text = "Size", Min = 100, Max = 260, Step = 10}, "radarSize")
    CfgSlider(rd, {Text = "Range (studs)", Min = 50, Max = 600, Step = 10}, "radarRange")

end

-- ESP (ESP слева, Chams справа)
do
    local e = CreateGroup(TabSet.ESP.Left, "ESP")
    CfgToggle(e, "Enable ESP", "espEnabled")
    CfgToggle(e, "Box", "espBox")
    CfgDropdown(e, {Text = "Box style", Options = {"Full", "Corners"}}, "espBoxStyle")
    CfgToggle(e, "Box fill", "boxFill")
    CfgSlider(e, {Text = "Fill transparency", Min = 50, Max = 98, Format = fmtPct}, "boxFillAlpha")
    CfgToggle(e, "Name", "espName")
    CfgToggle(e, "Health bar", "espHealth")
    CfgToggle(e, "Distance", "espDistance")
    CfgToggle(e, "Weapon", "espWeapon")
    CfgDropdown(e, {Text = "Color", Options = ColorNames}, "espColor")
    CfgToggle(e, "Rainbow color", "espRainbow")
    CfgSlider(e, {Text = "Max distance", Min = 100, Max = 5000, Step = 50}, "espMaxDist")

    local c = CreateGroup(TabSet.ESP.Right, "Chams")
    CfgToggle(c, "Enable chams", "chamsEnabled")
    CfgToggle(c, "Through walls", "chamsThrough")
    CfgDropdown(c, {Text = "Color", Options = ColorNames}, "chamsColor")
    CfgToggle(c, "Rainbow color", "chamsRainbow")
    CfgSlider(c, {Text = "Fill transparency", Min = 0, Max = 100, Format = fmtPct}, "chamsFill")
    CfgSlider(c, {Text = "Outline transparency", Min = 0, Max = 100, Format = fmtPct}, "chamsOutline")

    local x = CreateGroup(TabSet.ESP.Right, "ESP extras")
    CfgToggle(x, "Snaplines", "espSnaplines")
    CfgDropdown(x, {Text = "Snapline origin", Options = {"Bottom", "Center", "Top"}}, "espSnapOrigin")
    CfgToggle(x, "Head dot", "espHeadDot")
    CfgToggle(x, "Skeleton", "espSkeleton")
    CfgToggle(x, "View direction", "espLook")
    CfgToggle(x, "Health number", "espHpText")
    CfgToggle(x, "Visible check (green / red)", "visCheck")
    CfgToggle(x, "Offscreen arrows", "espArrows")
    CfgSlider(x, {Text = "Arrow radius", Min = 80, Max = 400, Step = 5}, "arrowRadius")
end

-- Hitbox
do
    local h = CreateGroup(TabSet.Hitbox.Left, "Hitbox expander")
    CfgToggle(h, "Enable hitbox", "hbEnabled", function(v)
        if not v then restoreHitboxes() end
    end)
    CfgDropdown(h, {Text = "Hitbox part", Options = {"Head", "Body", "Head + Body"}}, "hbPart")
    CfgSlider(h, {Text = "Hitbox size", Min = 2, Max = 30}, "hbSize")
    CfgSlider(h, {Text = "Hitbox transparency", Min = 0, Max = 100, Format = fmtPct}, "hbTransparency")
end

-- World
do
    local g = CreateGroup(TabSet.World.Left, "Time of day")
    CfgToggle(g, "Custom time", "customTimeEnabled", function(v)
        if not v then Lighting.ClockTime = originalClock end
    end)
    timeSlider = CfgSlider(g, {
        Text = "Clock (0 - 24)", Min = 0, Max = 24, Step = 0.25, Format = L.fmtTime, Track = DayTrack,
    }, "timeOfDay")
    CfgToggle(g, "Auto day / night cycle", "autoCycle")
    CfgSlider(g, {Text = "Cycle speed (hours / min)", Min = 1, Max = 60}, "cycleSpeed")

    local cc = CreateGroup(TabSet.World.Left, "Color grading")
    CfgToggle(cc, "Enable color grading", "ccEnabled")
    CfgSlider(cc, {Text = "Brightness", Min = -50, Max = 50}, "ccBrightness")
    CfgSlider(cc, {Text = "Contrast", Min = -50, Max = 50}, "ccContrast")
    CfgSlider(cc, {Text = "Saturation", Min = -100, Max = 100}, "ccSaturation")
    CfgDropdown(cc, {Text = "Tint", Options = TintNames}, "ccTint")

    local a = CreateGroup(TabSet.World.Right, "Atmosphere")
    CfgToggle(a, "Screen vignette", "vignetteEnabled", setVignette)
    CfgSlider(a, {
        Text = "Vignette strength", Min = 10, Max = 100, Format = fmtPct,
        Callback = function() if cfg.vignetteEnabled then setVignette(true) end end,
    }, "vigStrength")
    CfgToggle(a, "Fullbright", "fullbright")
    CfgToggle(a, "Remove fog", "noFog")
    CfgToggle(a, "Ambient color override", "ambientEnabled")
    CfgDropdown(a, {Text = "Ambient color", Options = ColorNames}, "ambientColor")
    CfgToggle(a, "Remove blur / flash", "noBlur")
    CfgToggle(a, "Custom fog", "fogEnabled")
    CfgDropdown(a, {Text = "Fog color", Options = ColorNames}, "fogColor")
    CfgSlider(a, {Text = "Fog distance", Min = 100, Max = 3000, Step = 50}, "fogDist")

    local b = CreateGroup(TabSet.World.Right, "Bloom")
    CfgToggle(b, "Enable bloom", "bloomEnabled")
    CfgSlider(b, {Text = "Intensity", Min = 0, Max = 100, Format = fmtPct}, "bloomIntensity")
    CfgToggle(b, "Sun rays", "sunRaysEnabled")
    CfgSlider(b, {Text = "Sun rays intensity", Min = 0, Max = 100, Format = fmtPct}, "sunRaysIntensity")
end

-- Weather
do
    local w = CreateGroup(TabSet.Weather.Left, "Weather")
    CfgToggle(w, "Enable weather", "weatherEnabled")
    CfgDropdown(w, {Text = "Type", Options = WeatherKinds}, "weatherKind")
    CfgDropdown(w, {Text = "Color", Options = WeatherColorNames}, "weatherColor")
    CfgToggle(w, "Rainbow color", "weatherRainbow")
    CfgSlider(w, {Text = "Density", Min = 1, Max = 100}, "weatherDensity")
    CfgSlider(w, {Text = "Speed", Min = 30, Max = 300, Format = fmtPct}, "weatherSpeed")
    CfgSlider(w, {Text = "Particle size", Min = 30, Max = 300, Format = fmtPct}, "weatherSize")
    CfgSlider(w, {Text = "Wind", Min = -30, Max = 30}, "weatherWind")

    local a = CreateGroup(TabSet.Weather.Right, "Sky atmosphere")
    CfgToggle(a, "Custom atmosphere", "atmEnabled")
    CfgDropdown(a, {Text = "Air color", Options = ColorNames}, "atmColor")
    CfgDropdown(a, {Text = "Horizon color", Options = ColorNames}, "atmDecay")
    CfgSlider(a, {Text = "Density", Min = 0, Max = 100, Format = fmtPct}, "atmDensity")
    CfgSlider(a, {Text = "Haze", Min = 0, Max = 100, Format = fmtPct}, "atmHaze")
    CfgSlider(a, {Text = "Sun glare", Min = 0, Max = 100, Format = fmtPct}, "atmGlare")

    local sc = CreateGroup(TabSet.Weather.Right, "Sky color shift")
    CfgToggle(sc, "Enable color shift", "shiftEnabled")
    CfgToggle(sc, "Color cycle (rainbow)", "shiftCycle")
    CfgDropdown(sc, {Text = "Top color", Options = ColorNames}, "shiftTop")
    CfgDropdown(sc, {Text = "Bottom color", Options = ColorNames}, "shiftBottom")

    local ci = CreateGroup(TabSet.Weather.Left, "Depth of field")
    CfgToggle(ci, "Depth of field", "dofEnabled")
    CfgSlider(ci, {Text = "Focus distance", Min = 5, Max = 300, Step = 5}, "dofFocus")
    CfgSlider(ci, {Text = "In-focus radius", Min = 5, Max = 120, Step = 5}, "dofRadius")
    CfgSlider(ci, {Text = "Blur strength", Min = 0, Max = 100, Format = fmtPct}, "dofFar")
end

-- Aim
do
    local g = CreateGroup(TabSet.Aim.Left, "Vector aim")
    CfgToggle(g, "Enable aim", "aimEnabled")
    CfgDropdown(g, {Text = "Activation", Options = {"Always", "Hold right mouse", "Hold left mouse"}}, "aimMode")
    CfgDropdown(g, {Text = "Aim part", Options = {"Head", "Torso", "Closest"}}, "aimPart")
    CfgDropdown(g, {Text = "Target priority", Options = {"Closest to crosshair", "Closest distance"}}, "aimPriority")
    CfgToggle(g, "Aim through walls", "aimWalls")
    CfgToggle(g, "Sticky target", "aimSticky")
    CfgToggle(g, "Target HUD", "aimTargetHud")

    local s = CreateGroup(TabSet.Aim.Right, "Legit settings")
    CfgSlider(s, {Text = "Smoothness", Min = 0, Max = 100, Format = fmtPct}, "aimSmooth")
    CfgSlider(s, {Text = "Humanize", Min = 0, Max = 100, Format = fmtPct}, "aimHumanize")
    CfgSlider(s, {Text = "Lock-on delay", Min = 0, Max = 500, Step = 10, Format = function(v) return v .. " ms" end}, "aimDelay")
    CfgSlider(s, {Text = "Movement delay", Min = 0, Max = 800, Step = 10, Format = function(v) return v .. " ms" end}, "aimLag")
    CfgSlider(s, {Text = "Prediction", Min = 0, Max = 300, Step = 5, Format = function(v) return v .. " ms" end}, "aimPredict")
    CfgSlider(s, {Text = "Max distance", Min = 50, Max = 3000, Step = 50}, "aimDist")

    local f = CreateGroup(TabSet.Aim.Right, "FOV circle")
    CfgToggle(f, "Show FOV circle", "aimShowFov")
    CfgSlider(f, {Text = "Radius", Min = 20, Max = 500, Step = 5}, "aimFov")
    CfgDropdown(f, {Text = "Color", Options = ColorNames}, "aimFovColor")
end

-- Sky
do
    local g = CreateGroup(TabSet.Sky.Left, "Skybox")
    CfgToggle(g, "Custom skybox", "skyOn", function(v)
        if v then L.skyApply() else L.skyRestore() end
    end)
    CfgDropdown(g, {Text = "Preset", Options = L.skyNames, Callback = function()
        if cfg.skyOn then L.skyApply() end
    end}, "skyPreset")
    CfgToggle(g, "Hide sun / moon / stars", "skyHideBodies", function()
        if cfg.skyOn then L.skyApply() end
    end)

    local p = CreateGroup(TabSet.Sky.Right, "Your photo as sky")
    local note = makeText(p, "File from workspace/scorpion/photos or a direct image link (.png / .jpg)", 12, Theme.TextDim)
    note.Size = UDim2.new(1, 0, 0, 30)
    note.TextWrapped = true
    local box = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.4,
        BorderSizePixel = 0, Text = "", PlaceholderText = "photo.png  or  https://...", PlaceholderColor3 = Color3.fromRGB(100, 100, 100),
        TextColor3 = Theme.White, Font = Theme.Font, TextSize = 13, ClearTextOnFocus = false, Parent = p,
    })
    new("UICorner", {CornerRadius = UDim.new(0, 2), Parent = box})
    stroke(box, 0.78)
    CreateButton(p, "Apply photo", function()
        L.skyPhoto(box.Text)
        cfg.skyOn = false
    end)
    CreateButton(p, "Restore original sky", function()
        cfg.skyOn = false
        L.skyRestore()
    end)
end

-- Weapon chams / tracers / recoil
do
    local w = CreateGroup(TabSet.Models.Left, "Weapon chams")
    CfgToggle(w, "Enable weapon chams", "wcEnabled")
    CfgDropdown(w, {Text = "Style", Options = L.wcStyleNames}, "wcStyle")
    CfgSlider(w, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct}, "wcTransparency")
    CfgToggle(w, "Force-field shimmer layer", "wcShimmer")
    CfgToggle(w, "Sparkles", "wcSparkles")
    CfgSlider(w, {Text = "Sparkle density", Min = 2, Max = 60}, "wcSparkDensity")
    CfgToggle(w, "Glow outline", "wcGlow")
    CfgSlider(w, {Text = "Animation speed", Min = 0, Max = 100, Format = fmtPct}, "wcSpeed")

    local wc = CreateGroup(TabSet.Models.Right, "Chams colors")
    CfgToggle(wc, "Custom colors", "wcCustom")
    CfgDropdown(wc, {Text = "Color 1", Options = ColorNames}, "wcColor")
    CfgDropdown(wc, {Text = "Color 2", Options = ColorNames}, "wcColor2")
    CfgToggle(wc, "First person weapon", "wcViewmodel")
    CfgToggle(wc, "Weapon in hand (3rd person)", "wcThird")

    local t = CreateGroup(TabSet.FX.Left, "Bullet tracers")
    CfgToggle(t, "Enable tracers", "tracerEnabled")
    CfgDropdown(t, {Text = "Style", Options = {"Laser", "Lightning", "Comet", "Dots"}}, "tracerStyle")
    CfgDropdown(t, {Text = "Shot detection", Options = {"Auto (ammo counter)", "Click only"}}, "tracerDetect")
    CreateButton(t, "Scan weapon (find ammo counter)", function() if L.tracerScan then L.tracerScan() end end)
    CfgDropdown(t, {Text = "Start from", Options = {"Weapon muzzle", "Camera"}}, "tracerFrom")
    CfgDropdown(t, {Text = "Color", Options = ColorNames}, "tracerColor")
    CfgToggle(t, "Rainbow", "tracerRainbow")
    CfgSlider(t, {Text = "Thickness", Min = 20, Max = 400, Format = fmtPct}, "tracerThick")
    CfgSlider(t, {Text = "Lifetime", Min = 10, Max = 200, Format = function(v) return string.format("%.2f s", v / 100) end}, "tracerLife")
    CfgToggle(t, "Impact sparks", "tracerImpact")
    CfgToggle(t, "Repeat while holding fire", "tracerRepeat")
    CfgSlider(t, {Text = "Repeat rate", Min = 30, Max = 500, Step = 10, Format = function(v) return v .. " ms" end}, "tracerRate")

    local r = CreateGroup(TabSet.Camera.Right, "Recoil (visual)")
    CfgToggle(r, "Remove camera recoil", "noRecoil")
    CfgSlider(r, {Text = "Strength", Min = 10, Max = 100, Format = fmtPct}, "noRecoilPct")
    CfgToggle(r, "Freeze weapon kick (viewmodel)", "noKickVm")
end

-- Camera
do
    local g = CreateGroup(TabSet.Camera.Left, "Field of view")
    CfgSlider(g, {Text = "Field of view", Min = 50, Max = 120, Format = fmtDeg}, "fov")
    CfgSlider(g, {Text = "Zoom FOV", Min = 20, Max = 60, Format = fmtDeg}, "zoomFov")
    CreateKeybind(g, "Zoom key", zoomKey, function(k)
        zoomKey = k
        zoomActive = false
        cfg.zoomKey = k and k.Name or ""
        QueueSave()
    end)

    local fg = CreateGroup(TabSet.Camera.Left, "Freecam")
    CreateKeybind(fg, "Freecam key", FCApi.keyCode, function(k)
        FCApi.setKey(k)
        QueueSave()
    end)
    CfgToggle(fg, "Hold key (off = press)", "fcHold")
    CfgSlider(fg, {Text = "Speed", Min = 10, Max = 300, Step = 5}, "fcSpeed")
    CfgSlider(fg, {Text = "Sensitivity", Min = 20, Max = 300, Format = fmtPct}, "fcSens")

    local s = CreateGroup(TabSet.Camera.Right, "Resolution stretch")
    CfgToggle(s, "Enable stretch", "stretch")
    CfgSlider(s, {Text = "Stretch X", Min = 50, Max = 120, Format = fmtPct}, "stretchX")
    CfgSlider(s, {Text = "Stretch Y", Min = 50, Max = 120, Format = fmtPct}, "stretchY")
end

-- Models
do
    local h = CreateGroup(TabSet.Models.Left, "Highlight")
    CfgToggle(h, "Enable highlight", "hlEnabled")
    CfgToggle(h, "Character", "hlChar")
    CfgToggle(h, "Weapon / viewmodel", "hlWeapon")
    CfgDropdown(h, {Text = "Color", Options = ColorNames}, "hlColor")
    CfgSlider(h, {Text = "Fill transparency", Min = 0, Max = 100, Format = fmtPct}, "hlFill")
    CfgSlider(h, {Text = "Outline transparency", Min = 0, Max = 100, Format = fmtPct}, "hlOutline")
    CfgToggle(h, "Rainbow", "hlRainbow")
    CfgToggle(h, "Pulse", "hlPulse")
    CfgSlider(h, {Text = "Pulse speed", Min = 1, Max = 10}, "hlPulseSpeed")

    local s = CreateGroup(TabSet.Models.Right, "Arms skin")
    CfgToggle(s, "Enable arms skin", "skinEnabled")
    CfgDropdown(s, {Text = "Style", Options = SkinNames}, "skinStyle")
    CfgDropdown(s, {Text = "Color", Options = ColorNames}, "skinColor")
    CfgSlider(s, {Text = "Transparency", Min = 0, Max = 95, Format = fmtPct}, "skinTransparency")
    CfgSlider(s, {Text = "Reflectance", Min = 0, Max = 100, Format = fmtPct}, "skinReflect")
end

-- Effects
do
    local function refreshTrail() setTrail(cfg.trailEnabled) end
    local tr = CreateGroup(TabSet.FX.Left, "Trail")
    CfgToggle(tr, "Movement trail", "trailEnabled", setTrail)
    CfgDropdown(tr, {Text = "Style", Options = TRAIL_STYLES, Callback = refreshTrail}, "trailStyle")
    CfgDropdown(tr, {Text = "Color mode", Options = {"Solid", "Gradient", "Rainbow"}, Callback = refreshTrail}, "trailMode")
    CfgDropdown(tr, {Text = "Color", Options = ColorNames, Callback = refreshTrail}, "trailColor")
    CfgDropdown(tr, {Text = "Second color (gradient)", Options = ColorNames, Callback = refreshTrail}, "trailColor2")
    CfgSlider(tr, {Text = "Width", Min = 20, Max = 300, Format = fmtPct, Callback = refreshTrail}, "trailWidth")
    CfgSlider(tr, {Text = "Length", Min = 20, Max = 300, Format = fmtPct, Callback = refreshTrail}, "trailLife")
    CfgSlider(tr, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct, Callback = refreshTrail}, "trailAlpha")

    local rg = CreateGroup(TabSet.FX.Left, "Ring under player")
    CfgToggle(rg, "Enable ring", "ringEnabled")
    CfgDropdown(rg, {Text = "Style", Options = {"Static", "Pulse", "Ripple", "Spinning arc", "Double ring", "Disc"}}, "ringStyle")
    CfgDropdown(rg, {Text = "Color", Options = ColorNames}, "ringColor")
    CfgToggle(rg, "Rainbow color", "ringRainbow")
    CfgSlider(rg, {Text = "Size", Min = 40, Max = 300, Format = fmtPct}, "ringSize")
    CfgSlider(rg, {Text = "Thickness", Min = 20, Max = 300, Format = fmtPct}, "ringThick")
    CfgSlider(rg, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct}, "ringAlpha")
    CfgSlider(rg, {Text = "Animation speed", Min = 20, Max = 300, Format = fmtPct}, "ringSpeed")

    local jr = CreateGroup(TabSet.FX.Right, "Jump ring")
    CfgToggle(jr, "Jump land ring", "jumpRingEnabled")
    CfgDropdown(jr, {Text = "Style", Options = {"Ring", "Disc", "Double ring", "Shockwave"}}, "jumpStyle")
    CfgDropdown(jr, {Text = "Color", Options = ColorNames}, "jumpColor")
    CfgToggle(jr, "Rainbow color", "jumpRainbow")
    CfgSlider(jr, {Text = "Size", Min = 40, Max = 300, Format = fmtPct}, "jumpSize")
    CfgSlider(jr, {Text = "Duration", Min = 30, Max = 300, Format = fmtPct}, "jumpDuration")
    CfgSlider(jr, {Text = "Thickness", Min = 20, Max = 300, Format = fmtPct}, "jumpThick")
    CfgSlider(jr, {Text = "Transparency", Min = 0, Max = 90, Format = fmtPct}, "jumpAlpha")

    local au = CreateGroup(TabSet.FX.Right, "Character aura")
    CfgToggle(au, "Enable aura", "auraEnabled")
    CfgDropdown(au, {Text = "Style", Options = {"Sparkles", "Flame", "Halo", "Orbit"}}, "auraStyle")
    CfgDropdown(au, {Text = "Color", Options = ColorNames}, "auraColor")
    CfgDropdown(au, {Text = "Second color", Options = ColorNames}, "auraColor2")
    CfgToggle(au, "Rainbow color", "auraRainbow")
    CfgSlider(au, {Text = "Density", Min = 5, Max = 100}, "auraDensity")
    CfgSlider(au, {Text = "Size", Min = 30, Max = 300, Format = fmtPct}, "auraSize")
    CfgSlider(au, {Text = "Speed", Min = 30, Max = 300, Format = fmtPct}, "auraSpeed")
end

-- ============================================================
--  ВЫГРУЗКА
-- ============================================================
local function Unload()
    if unloaded then return end
    unloaded = true
    SaveNow()

    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if fovConn then
        fovConn:Disconnect()
        fovConn = nil
    end
    pcall(function() RunService:UnbindFromRenderStep(RENDER_NAME) end)
    pcall(function() RunService:UnbindFromRenderStep(RENDER_FOV) end)
    pcall(function() RunService:UnbindFromRenderStep(RENDER_ESP) end)
    pcall(FCApi.off or function() end)
    pcall(L.aimCleanup or function() end)
    pcall(L.skyRestore or function() end)
    pcall(L.wcCleanup or function() end)
    pcall(L.tracerCleanup or function() end)
    pcall(L.recoilCleanup or function() end)

    setTrail(false)
    setVignette(false)
    L.cleanupModels()
    L.cleanupTargets()
    L.cleanupVisuals()
    Lighting.ClockTime = originalClock
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = originalFov end

    for _, g in ipairs({CrosshairGui, ScreenGui}) do pcall(function() g:Destroy() end) end
    env.ScorpionUnload = nil
end
env.ScorpionUnload = Unload

-- Settings
do
    local g = CreateGroup(TabSet.Settings.Left, "Menu")
    CfgSlider(g, {
        Text = "UI scale", Min = 70, Max = 130, Format = fmtPct,
        Callback = function(v) MainScale.Scale = v / 100 end,
    }, "uiScale")
    CfgDropdown(g, {Text = "Menu accent", Options = AccentNames, Callback = function(i) ApplyAccent(i) end}, "menuAccent")
    CfgToggle(g, "Notifications", "notify")
    CreateKeybind(g, "Menu key", menuKey, function(k)
        menuKey = k or Enum.KeyCode.Insert
        cfg.menuKey = menuKey.Name
        ftL.Text = menuKey.Name:upper() .. " — hide / show"
        QueueSave()
    end)
    CreateButton(g, "Save config", SaveNow)
    CreateButton(g, "Forget saved key + unload", function()
        pcall(function()
            if typeof(delfile) == "function" and isfile("scorpion_key.txt") then
                delfile("scorpion_key.txt")
            elseif typeof(writefile) == "function" then
                writefile("scorpion_key.txt", "")
            end
        end)
        Unload()
    end)
    CreateButton(g, "Unload script", Unload)
end

-- ============================================================
--  ПЕРЕТАСКИВАНИЕ И БИНДЫ
-- ============================================================
local menuOpen = true
local ModalBtn = new("TextButton", {
    Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Text = "", Modal = true, Parent = ScreenGui,
})
function L.toggleMenu()
    menuOpen = not menuOpen
    ModalBtn.Modal = menuOpen
    local base = cfg.uiScale / 100
    if menuOpen then
        MainFrame.Visible = true
        MainScale.Scale = base * 0.94
        TweenService:Create(MainScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Scale = base,
        }):Play()
    else
        local tw = TweenService:Create(MainScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Scale = base * 0.94,
        })
        tw.Completed:Once(function()
            if not menuOpen then MainFrame.Visible = false end
        end)
        tw:Play()
    end
end

local dragging, dragStart, startPos = false, nil, nil

DragBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = MainFrame.Position
    end
end)
bind(UserInputService.InputChanged, function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
bind(UserInputService.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

bind(UserInputService.InputBegan, function(i, gp)
    if gp or Binding then return end
    if i.KeyCode == menuKey then
        L.toggleMenu()
    elseif zoomKey and i.KeyCode == zoomKey then
        zoomActive = not zoomActive
    end
end)

-- ============================================================
--  ИНТРО
-- ============================================================
task.spawn(function()
    local intro = new("ScreenGui", {
        Name = "ScorpionIntro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000, Parent = GuiParent,
    })
    local bg = new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = intro,
    })
    local lbl = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(500, 80),
        BackgroundTransparency = 1, RichText = true, Font = Enum.Font.GothamBlack, TextSize = 46, TextTransparency = 1,
        Text = '<font color="#FFFFFF">SCORPION</font><font color="#8A8A8A">.WTF</font>', Parent = intro,
    })
    local tin = TweenInfo.new(0.3)
    TweenService:Create(bg, tin, {BackgroundTransparency = 0.35}):Play()
    TweenService:Create(lbl, tin, {TextTransparency = 0}):Play()
    task.wait(1)
    TweenService:Create(bg, tin, {BackgroundTransparency = 1}):Play()
    TweenService:Create(lbl, tin, {TextTransparency = 1}):Play()
    task.wait(0.35)
    intro:Destroy()
    if not unloaded and ScreenGui.Parent then ScreenGui.Enabled = true end
end)
