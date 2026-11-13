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
    Back    = Color3.fromRGB(11, 11, 13),
    Panel   = Color3.fromRGB(16, 16, 19),
    Head    = Color3.fromRGB(24, 24, 29),
    Box     = Color3.fromRGB(21, 21, 25),
    Line    = Color3.fromRGB(34, 34, 40),
    Off     = Color3.fromRGB(27, 27, 32),
    Black   = Color3.fromRGB(0, 0, 0),
    White   = Color3.fromRGB(255, 255, 255),
    Text    = Color3.fromRGB(225, 225, 230),
    TextDim = Color3.fromRGB(135, 135, 143),
    Accent  = Color3.fromRGB(255, 255, 255),
    Font    = Enum.Font.Code,
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
        local status = makeText(box, "", 13, Color3.fromRGB(255, 110, 110), Enum.TextXAlignment.Center)
        status.Position = UDim2.fromOffset(0, 114)
        status.Size = UDim2.new(1, 0, 0, 16)
        local btn = new("TextButton", {
            Position = UDim2.fromOffset(20, 140), Size = UDim2.new(1, -40, 0, 34), BackgroundColor3 = Theme.White,
            BackgroundTransparency = 0.88, BorderSizePixel = 0, Text = "Activate", TextColor3 = Theme.White,
            Font = Theme.Font, TextSize = 16, AutoButtonColor = false, Parent = box,
        })
        new("UICorner", {CornerRadius = UDim.new(0, 4), Parent = btn})

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
    fov = 70, zoomFov = 30, zoomKey = "", fcKey = "", fcHold = false, wcEnabled = false, wcStyle = 1, wcCustom = false, wcColor = 1, wcColor2 = 2, wcTransparency = 30, wcShimmer = true, aimLag = 150, wcSparkles = true, wcSparkDensity = 18, wcGlow = true, wcSpeed = 20, wcViewmodel = true, wcThird = true, tracerEnabled = false, tracerStyle = 1, tracerColor = 1, tracerRainbow = false, tracerThick = 100, tracerLife = 50, tracerRate = 100, tracerRepeat = true, tracerImpact = true, tracerFrom = 1, noRecoil = false, noRecoilPct = 100, noKickVm = true, tracerDetect = 1, skyOn = false, skyPreset = 1, skyHideBodies = true, skyMethod = 1, aimEnabled = false, aimMode = 2, aimKey = "", aimPart = 1, aimFov = 120, aimShowFov = true, aimFovColor = 1, aimSmooth = 60, aimWalls = false, aimSticky = true, aimPredict = 0, aimDist = 1000, aimPriority = 1, aimHumanize = 20, aimDelay = 80, aimTargetHud = true, fcSpeed = 60, fcSens = 100, crossMode = 1,
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
    hbEnabled = false, hbShow = true, dlogEnabled = true, espRate = 90, espReload = true, espWear = false, infoTarget = true, infoNearby = true, infoRange = 300, infoRows = 5, dlogTime = 4, dlogRows = 5, dlogPos = 1, hbDrawPart = 3, hbColor = 9, hbFill = 78, hbOutline = true, hbThrough = true, hbSize = 8, hbTransparency = 70, hbPart = 1,
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
if (cfg.skyPreset or 1) > 4 or (cfg.skyPreset or 1) < 1 then cfg.skyPreset = 1 end
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

local NOT_ARM = {"armor", "firearm", "alarm", "farm", "charm", "harm", "warm", "handle", "handgun", "handguard", "handgrip", "handcuff", "guard"}
local armCache = setmetatable({}, {__mode = "k"}) -- деталь -> результат (имя/класс не меняются, считаем один раз)
local function isArmPart(p)
    local cached = armCache[p]
    if cached ~= nil then return cached end
    local res = false
    if p:IsA("BasePart") and not (p:FindFirstAncestorOfClass("Accessory") or p:FindFirstAncestorOfClass("Tool")) then
        local n = p.Name:lower()
        -- убираем слова оружия, в которых прячется «arm»/«hand» (handgun, firearm, armor, handguard ...)
        for _, w in ipairs(NOT_ARM) do
            if n:find(w, 1, true) then n = n:gsub(w, "") end
        end
        for _, w in ipairs(ARM_WORDS) do
            if n:find(w, 1, true) then res = true break end
        end
    end
    armCache[p] = res
    return res
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
function L.cornerPut(spec, i, a, b, c, d) local r = spec[i] r[1], r[2], r[3], r[4] = a, b, c, d end
local visCache = setmetatable({}, {__mode = "k"})
function L.isVisible(cam, char)
    local vc = visCache[char]
    local now = os.clock()
    if vc and now - vc.t < 0.12 then return vc.v end
    local res = L.isVisibleRaw(cam, char)
    visCache[char] = {t = now, v = res}
    return res
end
function L.isVisibleRaw(cam, char)
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
        local tr = cfg.hbTransparency / 100
        if part.Transparency ~= tr then part.Transparency = tr end
        if part.CanCollide then part.CanCollide = false end
    elseif hbOriginals[part] then
        local o = hbOriginals[part]
        part.Size = o.Size
        part.Transparency = o.Transparency
        part.CanCollide = o.CanCollide
        hbOriginals[part] = nil
    end
end

-- ---------- видимые хитбоксы (заливка + контур вокруг головы / тела) ----------
L.hbDraws = setmetatable({}, {__mode = "k"})
L.hbSweepAt = 0
function L.hbClearDraws()
    for part, d in pairs(L.hbDraws) do
        if d.fill then d.fill:Destroy() end
        if d.out then d.out:Destroy() end
        L.hbDraws[part] = nil
    end
end
function L.hbDraw(part, on)
    if not part then return end
    local d = L.hbDraws[part]
    if not on or not part.Parent then
        if d then
            if d.fill then d.fill:Destroy() end
            if d.out then d.out:Destroy() end
            L.hbDraws[part] = nil
        end
        return
    end
    if not d then
        d = {}
        L.hbDraws[part] = d
    end
    local col = (ColorPresets[cfg.hbColor] or ColorPresets[9])[2]
    if not d.fill or not d.fill.Parent then
        d.fill = new("BoxHandleAdornment", {Name = "ScorpionHbFill", Adornee = part, ZIndex = 1, Parent = EspGui})
    end
    local f = d.fill
    if f.Size ~= part.Size then f.Size = part.Size end
    if f.Color3 ~= col then f.Color3 = col end
    local tr = math.clamp(cfg.hbFill / 100, 0, 1)
    if f.Transparency ~= tr then f.Transparency = tr end
    if f.AlwaysOnTop ~= cfg.hbThrough then f.AlwaysOnTop = cfg.hbThrough end
    if cfg.hbOutline then
        if not d.out or not d.out.Parent then
            d.out = new("SelectionBox", {
                Name = "ScorpionHbOutline", Adornee = part, LineThickness = 0.03, SurfaceTransparency = 1, Parent = EspGui,
            })
        end
        if d.out.Color3 ~= col then d.out.Color3 = col end
    elseif d.out then
        d.out:Destroy()
        d.out = nil
    end
end
function L.hbSweep()
    local now = os.clock()
    if now - L.hbSweepAt < 1 then return end
    L.hbSweepAt = now
    for part, d in pairs(L.hbDraws) do
        if not part.Parent then
            if d.fill then d.fill:Destroy() end
            if d.out then d.out:Destroy() end
            L.hbDraws[part] = nil
        end
    end
end

-- ---------- цифры урона ----------

function L.spawnDamageNumber(x, y, amount)
    local k = math.clamp(amount / 60, 0, 1)
    local lbl = makeText(EspGui, "-" .. math.floor(amount + 0.5), 16, Color3.new(1, 1 - k * 0.6, 1 - k * 0.6), Enum.TextXAlignment.Center)
    lbl.Font = Enum.Font.Code
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
    L.hbSweep()

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
                        local CL = math.max(math.min(w, h) * 0.28, 4)
                        local th = 2
                        local X0, Y0, X1, Y1 = x0, topY, x0 + w, botY
                        local spec = L.cornerSpec
                        if not spec then
                            spec = {}
                            for i = 1, 8 do spec[i] = {0, 0, 0, 0} end
                            L.cornerSpec = spec
                        end
                        local put = L.cornerPut
                        put(spec, 1, X0, Y0, CL, th) put(spec, 2, X0, Y0, th, CL)
                        put(spec, 3, X1 - CL, Y0, CL, th) put(spec, 4, X1 - th, Y0, th, CL)
                        put(spec, 5, X0, Y1 - th, CL, th) put(spec, 6, X0, Y1 - CL, th, CL)
                        put(spec, 7, X1 - CL, Y1 - th, CL, th) put(spec, 8, X1 - th, Y1 - CL, th, CL)
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
                    if cfg.espWeapon or cfg.espReload or cfg.espWear then
                        local g = L.gearGet and L.gearGet(plr, char, hum)
                        if g then
                            if cfg.espWeapon and g.weapon ~= "Hands" then sub[#sub + 1] = g.weapon .. (g.ammo and (" " .. g.ammo) or "") end
                            if cfg.espReload and g.reload then sub[#sub + 1] = string.format("RELOAD %.1fs", g.reload) end
                            if cfg.espWear and g.wearShort ~= "" then sub[#sub + 1] = g.wearShort end
                        end
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
                        -- детали скелета ищем раз в секунду, а не каждый кадр
                        local nowB = os.clock()
                        if t.boneChar ~= char or nowB - (t.boneT or 0) > 1 then
                            t.boneChar, t.boneT = char, nowB
                            t.boneParts = {}
                            for i = 1, MAX_BONES do
                                local pr = list[i]
                                t.boneParts[i] = pr and {char:FindFirstChild(pr[1]), char:FindFirstChild(pr[2])} or false
                            end
                        end
                        for i = 1, MAX_BONES do
                            local f = t.bones[i]
                            local pair = list[i]
                            local ok = false
                            if pair then
                                local bp = t.boneParts[i]
                                local pa, pb = bp and bp[1], bp and bp[2]
                                if pa and not pa.Parent then pa = nil end
                                if pb and not pb.Parent then pb = nil end
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
                if prev and hum.Health < prev and hrp and cfg.dlogEnabled and L.dlogShooting and L.dlogShooting() then
                    local sp = cam:WorldToViewportPoint(hrp.Position)
                    if sp.Z > 0 and (Vector2.new(sp.X, sp.Y) - vs / 2).Magnitude < 340 then
                        L.dlogAdd(plr.DisplayName ~= "" and plr.DisplayName or plr.Name, prev - hum.Health, hum.Health <= 0)
                    end
                end
            end

            -- Hitbox (1 = голова, 2 = тело, 3 = оба)
            local hbOn = cfg.hbEnabled and alive
            hbApply(hrp, hbOn and cfg.hbPart ~= 1)
            hbApply(char and char:FindFirstChild("Head"), hbOn and cfg.hbPart ~= 2)
            local drawOn = cfg.hbShow and alive
            L.hbDraw(hrp, drawOn and cfg.hbDrawPart ~= 1)
            L.hbDraw(char and char:FindFirstChild("Head"), drawOn and cfg.hbDrawPart ~= 2)
        end
    end
end

function L.cleanupTargets()
    for plr in pairs(targets) do removeTarget(plr) end
    restoreHitboxes()
    L.hbClearDraws()
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
local espAcc = 0
RunService:BindToRenderStep(RENDER_ESP, Enum.RenderPriority.Last.Value + 1, function(dt)
    if unloaded then return end
    -- ограничитель частоты ESP: на 144+ fps не пересчитываем всё каждый кадр
    espAcc = espAcc + dt
    local minDt = cfg.espRate > 0 and (1 / cfg.espRate) or 0
    if espAcc < minDt then return end
    espAcc = 0
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
    Size = UDim2.fromOffset(860, 560), BackgroundColor3 = Theme.Back, BackgroundTransparency = 0.02,
    BorderSizePixel = 0, ClipsDescendants = true, Parent = ScreenGui,
})
local MainScale = new("UIScale", {Scale = cfg.uiScale / 100, Parent = MainFrame})

-- шапка (за неё таскаем окно)
local DragBar = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = MainFrame})
local logoTxt = new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(20, 40), Font = Enum.Font.Code, TextSize = 28,
    Text = "S", TextColor3 = Accent, Parent = DragBar,
})
table.insert(accentRenders, function() logoTxt.TextColor3 = Accent end)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(200, 40),
    Font = Enum.Font.Code, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
    Text = '<font color="#FFFFFF">scorpion</font><font color="#FF344C">.wtf</font>', TextColor3 = Theme.White, Parent = DragBar,
})
local ftL = makeText(DragBar, "hey, " .. (player.DisplayName or player.Name) .. "  |  " .. menuKey.Name .. " - hide / show", 13, Theme.TextDim, Enum.TextXAlignment.Right)
ftL.AnchorPoint = Vector2.new(1, 0)
ftL.Position = UDim2.new(1, -14, 0, 0)
ftL.Size = UDim2.fromOffset(420, 40)
local hdrLine = new("Frame", {
    Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = MainFrame,
})

-- нижняя панель вкладок (иконка сверху, подпись снизу)
local TabBar = new("Frame", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = MainFrame,
})
local TabGrid = new("UIGridLayout", {
    FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
    CellPadding = UDim2.fromOffset(4, 0), CellSize = UDim2.new(1 / 11, -4, 1, 0), Parent = TabBar,
})
new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 4), Parent = TabBar})
local tabLine = new("Frame", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -52), Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = Theme.Line, BorderSizePixel = 0, Parent = MainFrame,
})

local Content = new("Frame", {
    Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 1, -52 - 52 - 12), BackgroundTransparency = 1, Parent = MainFrame,
})

-- ============================================================
--  МЕНЮ: вкладки и группы
-- ============================================================
L.ICONS = {
    visuals = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de0000076d4944415478daed9b598c55451086bf7befcc00cae0165c70888002220a1a05dc1045d468dce21e8dcb8b2683d1c468a20f3e189fdc127709bc68d0986834fa626222ee8a08a291b8001a14178c1aa30828cc5d7e1fac8eeda1cf9dee33778649b89d9cdcb967cea9aeaaaeaeaefaab6e4912bbf328b39b8fb602da0a682b60f71e1d43304729f35d2d7e7ed82aa0d444808a5dce021b40dd2e05e894ecbe86bb024a26942f4817b02fb0373016381c3808d80bd8c39ef90bd80c6c02d602bfdaf7df80aa47ab62ca6a99224a2d0a847cc1dd180f1c099c06cc036605cc3b6f348055c05bc0dbc07a60c36028a2150a287be6d9091c0b9c005c0eccf19e73265ef21491dd268e8edb226e7c093c07bc0aac066a1e9dc6ae5440a79928c0c9c025c0f59e69f779d6514eb00099606e95bbecfe366009f022f07e808721538013a8064c02ae056e04f63386ab81551cc868d85c4e11bf028f014b816fcd97350a5983a4d4abe2fd7dbea4f7f4dfd821a9a1c11b0d9bc38d77249d97c35bd4956a011db612a3815b805bcd9bd73cab8859cd46ce71974aa303f803780078c8b688e3b1e516d0619f07495aeaad425fe4caf5453eeb9e6b443eebc6d3927a32bcb6cc029c560fb7bd77bab78afdedf3ac756c003e077e02b6d8bd6e601c301d981858e566a3ee59cf9b402fb02ed612621450b1498e009e0466dbf7febcbaf3e415603bf004b00cd86801ce163b255cb0d46d4e740270860932a2c05c2b81ebece8ac646293e42de09cca1449abccd46a11e6e9ffff714933258d4cd86e23251d2d69510ecdbc396bf6f74a4987c538c6664c94edf36049cb128477e3674967481a95a1599654b2ab9c73b9e747493a4dd28f09a744d5fe7ec37c422943334a0125fbec96b4c408561384ff48d2e48ce0a5040bc8323d45d2ea024a5822697446a6680b40d2428f60acd9afb393829c89ddf71192ce91749ba48b248d6fb210481a27697dc276a84aaa4bea4ddd026ed2799ec9c7aefc1f928e4a3852ef34da7f5b80b34ad2c5923a73de9b21697382253845cccbb3823ce1c74bfaca08d5232673267745624c71aea4df03f496499a98c3f4559e3fea6fd43dabec09d1cbf3fc8f66046b361c23ef99cf2062bf3bcf3cc798f3e9386bfbde563ce497962728c1c9f070e8440831774a0271df399e59209f98e3edeb5ac09f7c2e696ce0fdb332ce2e7691e6666965e3ee31c07d1654c4c6e41dc027c0c739985e33b86c1c70a00532a5ccff1b167cdd1578ef63608d9705c6ccd730d9ba9ba1c2977920468c202eca7a19f833013d2a599476a231540bf05236a67b2de5f6c766e0a50c0f31e8f7f1c0a5790a180ddceec5d6b1c005167ef679e0a5cb1fca19f4a762f7abc05c63a6d1249f70f4aef4e62bd95c2b3d2b8c557c1db8c364dd49019700872522372ed6de14b09a9ab7953a3d06aa8615de0d1cd2cf767349cefcc036f8c1e8551271cbc9c0c52105dc64cca4009715cbc77704265b6048b013ba6189ceb5c0d36601b548647a4a80af3edb0a1d8956d0006e0ec1e2930a568ab607182801cf002b2cfbdb02ec031c6582634ae98c9ca33b6701b61784f3268514b00138ba80124606de7140e6054d52d7ce8439b6e60832b20034de305977da028f7a1077ac266b66e65d01213fb355ae9ab9563d8022052c95154bb27c7565e0b8585a65e09190025e00be4e2c383827d4132883bde679fd2e5bf18e041fe3d37b3d70afc7e82b116a5f6fb0fa4e0ad80adc9b48d4bd3fdb84f4039a67122d2a8fe91af06ce658ecb2339dc423bb02dcf3bf2d95090dc7485a6149442321d9f8c40b59fd3ce0b184842a2f7c7d38900fec2fe9d304da75bb967bf94acb7381b302b4c64a5a5b4009eed93592f66b612e70524c3254341b5c9e930d4e97f45d2490914d61a7e564832b0a64830fc564836e921e2f4bab2728e1ca9cec6f82a457122ce0157b2744ebea0278c05ac336a3f0808120429b3339bc7f754abad02c65871535dcdeecb37bef4abaa009223453d2964444a8cfb67510a7e8af2ed00b3cee1d77fd61f325e02be0d44c7e909de440e0384b87cb16d7afb66249281972a9f33bc0a181f439c48bab272c0416a7d605068a0aaf9634b585a8f0543b695251e1c5034185fdbac06b0594f08ba144a1ba407f977b7e0f49f3256d4a10bed68aba4016ba9a6cd5962295a14556e549a90c8d92748cad6091cad00a4987c65486526a83d380a70ad60677008b2c3cf66b832e8d1ee1d506275a2add6b115f2dc2fff885da0fad36b836a636985a1d9e6ad5e10503a80e6fb444699307a38d312777a4812443561d2ed21f7080a4a786617fc0d2c1ec0fc85ac29e86aadc6a66bbab3b44ee071e04fe1ecc0e91501fced992decef40815497c527204bf47e8ada1ee110a75894d00aeb12eb1fd3dbcae955d62aec7d0012f3f5b80b6d47c4ae12eb156f6099e6868eb0d1eecdcea3ec1add627f802f0c1aeec13cceb14edb04ed105566499d1a24ed135c0f3d66233ac3a459bf50a4f340cfe54feed179e95b025eafcdb2bfc26fff50a7f93894d864daf707f8ae8b493622ffb3c829dbbc5b7594cf013f085054a7eb738c3bd5b3caffe9757ba6af67b0186f2f70283a580f62f46062080da3f9a6a2ba0ad80b602da0a682b6068c63fb398293b5729dc730000000049454e44ae426082",
    weapons = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000004c84944415478daed9b4b881c4518c77fd5f330c425899b448d240a2aa2876008ace2ea494f06f5a020222a5eccc5a38a0789087a100f5eccc18b8a0f422e2a881e041f6c34a8e00b141f87204450896e368a667767a6fbf3d05f6b594ebfa66776bb26fd41d1ccf6744dd7bfbee7bfbe3522c2992c0167b834003400340034004c9b989ccf530f4012d737389f874a7bca765e802dc0adc01cf031f02af067ea434e22648096a78b6fe9f571e001ebde63c053405f3f87b656d8000440e4b916cc026f0057e9823bc0b7c03cf09763fa916b0211b009b80638c733ff902ce82260a72e3c50ad381fb80ff80538057c689b84ad01e7014f03774c71780c8143c083c00957031e01ee5424573d76841d27f4899a83e8bdbb815f133f616bc01270b68262a6540304180027d534fe034034c50b776535c913da05322651db093d5858bb601837651221a3df6b7ba4e6a60c6279139d069e015e5774c39a66805de021e0667dc7565500229de413e051a0e7c1eeb780dd9a0f140221283869e84955db0136ab561432033b0a4846f2b0a0296664a95c9d4c6000ec006e072ed3f7ccdadc1e705651008ade5f6fc757267bedabcf28e5d9eb9c2398925cc11fd3c8079401eaed323e609a62ff0a700cd8071c77356060910a3e89edf0de03bed46820439cf90fc0739adbfccf043e03ae560711582a138cf9658bd41c92b219e290369115eb0f01f76bcd9f1732ff8964b609dc023c0f6ccd40b8aef28266814bbafb514e5d23699ce06d1a4bb7aa76ec022e1ee38bfe087ca73158321cd52ab007d8eedc5b02bed0778bd49b1fd5547d7994a4cd06c07e7893227939b01fb8a76c913144968909ca83c08cfa9cb4ccf3347004d8eb68e241e080c6f05001b1bd7b79472e22f6688b48c7f9db4611794b62e94b7909f57a5c44f6e89cc6f90d77cc89c8a23e17e9b527225738df0b44a45b60bed4e1daf64047a0a3abbb71d8da8551659198a1ed58f3bb6383eee6bd9ad3dbd5de57fabcfd7dd1b456aa1008c31c85382966af42ae9080fcb5da7637c54e8dfece0c70ad9a825885cd2b7a8dc6cda0e41519025c5a314159d1b23ad9fd4e46d5793d70e1100aebf02492b53c00228d087b2b9e252e2aa1d2e7df139a61050ac4c75a5b1c2d7c1ff879521c5a5edebcd302a03562ee3d033c9cb38311b00db8c9f1ea06787162c541469354a292fb8037d51c3a6bc5d559cf2c692ef2fb5af60718cb515d392612c48c90361be089492dbe884d6f233e685c8f5e8200780d78763d3a4492dd3a774c0048895d0f75c79f04eed20c92491e2464c9053a7a098534827ca47c62b700102b5a2fbc03fcc61a9da464d9df5cc5f97baac22f51e3a3a4b4838659e2c6822aeadf033eb09e97319bcc444d6056ed5f2ab4cdfca42c4c6dcf16820c07b84b9d60bf4219bc50c373845c00129a69be2207305000c4a746c964b19bb522abc209864a5252e7e6abb4c5cd1013a455f8c0635ac0189f342051d74b883bc5061516f0ae0f147b3ba508ba6e84f33617c8233e1cb60429a0eca8a0fe09a3b4007e768bf7814f551356acfea02223617a8f12b7a2d55e86f50a8bb2402f03378e30e729e006e0731f01b0653b71bfcdbc4685bc23ad3ef03d31f5f50d9e8829f06f731b2d0adae4d8feb26f0dd759008c9ac21a9f8edadb052b32533202300d00f8d21fd4fcd35403400340034003c0a8f23781b91f67d705f07f0000000049454e44ae426082",
    esp = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000004504944415478daed9b4d6c545514c77f53488100456d45a2282258239a6855686dfc8c46113f164849882b656974a589628c31bad31d2446a36e5c190117125c9920315140a841fc6aad52fa2168a165ac1fa185bf8b7748863a6fdee7dcce9bbe93dcbca6f3ce997bfff7dc73cefddf3b0549cc646960864b0e400e807b590cbc0e7403e3d60e01afd9676e4592cbd625a9287f294adae0b24f058759a00bf8102804cd09b011d8eea253ae00580cfc0c2c0cf97e115809fc512f31e0d908830768029ea9a720f888239d9a5d027f020b62e834d58b07c8914ecd02d0e748a76601d81543e793999c064f5b1a1ca9170ff81d782ae4ba96bd3b526f7b81ed56e11503667e03b0d355a70ad340885c6a45cec340abfdafc7e2c45657333f9d00e47c400e400dc96c87df7513d0015c14f0de28f025f06dbd1022774a3aa8e872405267d609912781771278da04b019f8208b59e02ee0b31496d90470b72d8b4c017008684bc9d67ea03d4b00b4190069ca8dc0775949831d55b0d999a53aa01afcfe6559026056566a96bc14ce01c801a819163848ce650980de2ad8ecc952217489152d4b52b2370cdc008c65c5034e018fa5e4093f99adb12c5262053cde6f87cd601439023c6e202aab594036833fc6d0fdded6bdea210d0e38d2a95900061de94c4b7ddd002c03aeb3b60ff8aa4a00b4036b6c49f500c7922e9138003402f7027700b703abb9f01cff9532000ca404c083c0ab5c7892741ef02f80cf8133d500600ef028b01e58072caaf0eed294dc792084ed45c003d6b054b90bf8d89e6792b2c27325bd20e97804367777193bb3254d46b031216956193bbb23d81896f49ca43995c65869f0ed92fa62d0d9877dec0d46b0d1ef63e3708cfef44abacd6f9c7e59602db017b82662ceefb7bc9f34aa0f56a80a8f46dc18adb4f8707fd8187015de517663884eeeb120b4cf6affbf03d6747bc21aa0cb9ef3805578dc6307708f4fec298d613b4d67302806bc5dc19dc624bd21a94d5221e229cccb11dcf6c588b60b926e91f4a6f5d14fde0a13037a7c94f7486a49700cb542d27888c117252d4bf03d2d92f6fad81e0a13032ef771a3f7487679a1cf36374301aebfde62495c1901def5f9ac25cc6eb01bb8b98cf26f78e7749fa6507d5ecfff69ee13c00fc06442fb0f01effb7011bd25b7527c63c04b012eda2de97949ad8eafda576aadd6a76f02fabe25cce9f07cf3826b43a07d1c3860eda021dc1fb51c8d58865f6da9ed562bc35787649e7af18eecfe0a43882cc73bd95d1ea393676d2d1f35804e96b471bc3bc000ff00ffdadf732db561fb8af94073495b6203bf9278872ebf02f7d93334237431b00dd814e2470eb52ac2fb91c6d346d345e203468127acd0d861339b1539671ba24e9bc053697082cd7877fbba6cf7d55863833e6bdbe28fac0d5793146d2a2127d65840bac2f1808780af2d00efb772bc389dacf002db3cadb0e7d22981acd9e24a83d5020bcbfc4062d2dc77744af03c6935fc2f5650f54d8de6f94dd1fc7034072007208efc07c3b7e0bb5bb703870000000049454e44ae426082",
    hitboxes = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000003014944415478daed9b4d48554114c77f4f4da848488a3ec03e8c30a868a1d02268110619186daa45e1a245425046b96b63ab943ee455100505b97021458415994544052d82282482347251425fd097a669ff16775611bd37f7bd7bdfbdf7cd1feeeecebc39bf7766ee993367529228669550e472001c80f054057401caf0f403ab421b95a4a09f1992da248d297bfd92744ed29ca0c71764e72949db240dcbbf3e496a91541a3700b5921e2a7f7a2169531c002c30ae3ba560d42ba93a8a00a61957fda2e0352e292da9222a001a250d2a7cbd93b4475249a100d448baa9c2eb89a4757eedf01307cc06da81e740430462995ae001d0032cb66d9cb2d80c9500bb80e3c0dc880676a3c031a00318cb27800d403ad4082d37bd015a812bb986c265c6ddefc4c8788025c065e002303d170f4803fb63bedfe90176f801b011b89d904ddf4ea0db760a1c4ad0aeb7d5d603cacd8a5a9a2008f380f7d97ac0a284190f506d33052a1298fca97029310720f90054ac00468066e07eb10198004e012b80f3c0946d07653136fe3ad002bc2eb635e0a5c94334e66a7cdc007c060e00ab815bf9ea340e536012b8081c063ee6bbf3a803b86bfef581628b035e01db81fa208d8fa2077c074e004781f1307e306a00ce006d2e1476001c0007c00170001c0007a09081d0b798d9516e72036bfff3ce571b00c378d995389c0d6cc13bb25f9ee1bd219b29308177221c65d50037806b5918ff18f860bb067446d4f04abc3ce000b039cb369d7e16c13ee074c416ec26bc94d83e8b8d5c37de11b9afafc041e0243ef2ed79563df00cb8845d79ce5960772e9fc149bc63f206433e6c2d03ae625f403d6816c7bd99f20ad9c6017d78c9c86602c8cbfd43334d5e6000d86ad1ee0770c48cb59780aac52b4da5e66400357f1d929a248d58b6fb2da94bd2fc300b25d748ba9767003f7db47924a9aed0a5b24305a8107d6bbc25158562e9f2108ba54725b54b9a15c572f9852194cb2f8dc38589ba3c5f98782a69bdbb32133300b95c9a9a48c2a5a9bf9f2af3adcea47e492bc31a974db9bc4b8939000e40f2f40736dadab4d5e32c680000000049454e44ae426082",
    aim = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000008594944415478daed9b6b8c5d5515c77fe7de99299dd27610a5d0b445a085962a469412c3504262144c7c46c5c46afca020123f6aa2018c1193167c258d22628ca47c28a6311aa5450d626b35d580b4a1a2424529a0562d422b9dcedcc7df0ffc77b2b33de79e735f632bb393937bef3e6befbdf65a6bafb5d7e366927829b71a2ff13647803902cc1160d6d7ba18780610d0f223f75d3cdb78cdd64299d7aa014b80a5c04cd4d770df92a82f3bd9099045f30b6802eda8af1dc1b6227cda8655d43734628c0c71e3ad6813a7012f03c681f5eeab4763c2f7f5c041e018f02cf0af8850757f1fe8c5251bf045a81e71731c5809ac03de025c0ebcbce23cff047e0edc0bfc1af8a38992ae71c21020e6fa29c01b80f7021b805323b870ee8b242f1c93b1a8ef287037f01d600f707c90d2300802c41c59077c08b83e3afb0dc3747396e50db680518f13703b7097a56230d220a99f67c49ff3245d2fe969bdd89a926624b5d57f6b7bae967f3f25e9a392c6121c7a7afad9fca83f974bfa7a8470dec6db921a92a6fd59d4629876012142fb9aa465092eb3468040f5359276445c6f1620dde881f38d0262c6eb6c97b4ba1f49e84507847377017007708595573d39e3c10c0685b713b80f380bf8b8df8f44caaf0e6c06fe0a5c1d99cba6e7ad273a228cff19702df0784f3aa14b8ad524d5259d25e90711a7da39dc0bed2e496f9774aee79874ff540473dc9f938639cf63b614cc191f2b49fa9ea425c6ad36ac239079f29aa4af18816687cd3f24e9ad92162504bc42d2519ff566a4308ffa5dbc81c59ee3e10e4408387c31c2311b0601c219fba0b9d78e34737c3e25e90e2bc730b6ee0749f3256dce39f39bfd2e8547d20a4977266b84d6322e53923674ab0faa6ebe6eaaae95b4b7801b01b19b248d475293c78d5325dd2069a7a45d923ee6be3ca90be3c725dd5c408480cb6fac98b384807d112046e2961c731423b431a27e15315c2c69a2220e81b39b0a88102cc6674b88df350102255f2fe9402476e9e6b7465ccc2a6ea8ac2feffd4249db728810707a4cd2eb12dc0b9f5ac56b29c09b80f3a2fb7c7857030e033702ff8eaead55e6cc22d359654c66dfe053f6166b89db3c03ac02de5871ce520204fffc95c0553963828dfe0470a0eaa2c9a6ba85c736ff935ebb99b39fab811549fca1670200ac05263d613d0a688c02bf057e1c71b4aaf79875f85d3616e047c0ef8c431a33b81c7855953dd64a160a227e917f372204c28deb1bc05fbadc40ca7945225e758e67803b135c028e35e035d111c9ba890865c975735114ac8cb95f03a680070c5b4fc25c9dc4f834608d032619f098b9f95c17a1bc1670bf71188b700a38bed6b1882339fbea488000b0d893ad025627121336fcb0275e68e55485f36b805b807725efb7013701bf2f51a481310b0db7d701985682e31a3f8ffbddf3550322f381f7d9c999ef30d665c0bc489cc2e79f80fdc03f80ddc05673a468f3673bb2b32e8aec1045927ee548d2c10e4408f84d02aff0593f2707b769e0170eaf4dd919fb6ffc729c9d8d7d042f367670464625dd68b81772c61ef3e7a70d9b15386303c52f5de05c034e477e7cb3245a13fcf669f79d537081592ae997057183d8cfdf6d6f33ef7294875fa7a853b30cbfd40a2cb75dadd9bc8c247e789e688f18b6e6b1cb0b60e70167e4c40de2b9ea8639a5608e3cfcb292d84547fc52023ce5016d9b936649802128a486c78cf8fce6b5e3c0a1245f9037d721c3e6b514bf56c945aae53d14e29712e0cfc0269b95aa125037ec98c71e2cb02a87811d869fc9996bc6efb65b71e529c114bf7a1712908b5f9115b806b8d216e074dbd4b11c4dfbb4cdcc93d6b2f794588115b602971658813d5ebbcc0a5c632bb502381f589683db8ccdf46113f4815cfc3a784a130e334d4ada9f785c4189edb1e7b5a80b97f60249f7e428acad7e57d5955e640f754f8253c0f1114997790f852e77a79b60b8951df32d6d6d74dbcaccb557dbde1eb1a8b54a2e30007f00ae03be6cee11dd049fafe050856377c4527491d7cd925beaa3c03e7ba83ddd0443baeb05e021e0dd512436a4b4c7ed7a3eda4534363371f7f8c93b2a65ad651cdeec23d1f03927c271af99d7318d56abe07fb78147dc371a4d14ceef471ceaaeead6aa8337d8cd1c4b810f27b828f20ef7f9b3e3bc65ee70706ef603bb222784480a2e3427e87203ea312e10e0aeb28fd288f61124639771a6cc41ab42809ab5fc7d39138e18a15bed34d1653143d6033cd61db726899718b71db624b57e09102ffa13477dc6a249c311391df8bcddcf2a7e7d96c3f9aca237b910d86897ba9dc427c66c96efafcc8c2ea3c29f2b890a6fea322a3cd165547854d26db31d158ef302173af6de292f70b3a40515f302bbfcdc50212fb040d2674af2020f3a593ad0bc409a19da502133f44d67730695193a5bd2b72a6486de3faccc1049deed4b157283fb24bdcdc98f5e7383139e635f85dce017a235b261d50784ecf09992be5f313bbc45d23b24adec223bbc52d23b25dd5d313bfc5d4967f4921deea73e6095eb03aeac581fb0db9ede9925f5017f7355d964f4ae9658acb83ee0a7be5a1f988dfa80541fac9674ef102b441a2515223f94747e3f152283a8115ae67a9db21aa166173542cd0a35425f7598ed7f5223944ac298a4eb241d8c34f3b0aac49e94746db4e9beaac4065d27784954279825919e5eeb04c7a26beeedc0b7810707552738ac4ad14b81f7b85274719f95a2cfb952749bdde7e913ad52b4481ae63bf57589b5fa7a2732aab4bfbb56787b542b3c7522d70a1749436813bc582dbe00f880d3e97110237cbf0dd8e220ccb349ae7028d5e2c3f8bf80a210552d12e3271c58d9996474e3ef3b0df344b4f93804a793e1ff0214b8ba8183ed1ce2a759e7f8ff066dfe0ffe32a368f3875c4f3016f58d3adf7f28ea9b957f740e430730f7afb13902cc11608e0073043849da7f00119bca91bce2c8aa0000000049454e44ae426082",
    world = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000005654944415478daed9b6d68965518c77f9bf3adadd7b55ec63697c1362a42aa19ca08c349335b36b04fe517a3774a0cfa12f4298d9111a594e507a112fa5294c962a142a40985ab4584adc2e92c45f7ccadb6b9a99bff3edc4718e3be9fe7dccf39f7b367b93fdc5fee9773aeebbaaf9773aeeb3a0592b89c51c8658e19015cee0228cad11c77030d401d500b5400d700258080616000f80be8027e030e001dc05892c41524e404e700ab80b54023706596e3fc0bec053e06be02cee7bb00ca80f5c03340a9675afb806dc03b40cadba8927c5c25925a250d29790c497a5d52b10fda7d30ff88a41ee51ec724ad76a5dfc504e619757ccaf2fd14f003f0337014e80506cdb3cdc0a22ce9d806bc048ce6d2042a24755afca5e3923649aa97549066bc271cb5e14749e5b932813a49473310d429698da4599663aef26012dd926ae3f213772154077c0b2c88783e04bc08dc057c0a8c5b8ebbd8833faf36b4d524650215c6f144e16b49d55968d4ad92063d3ac7ee38e6604be4bc0c36ff46061b8fbaaa0dc1bed12169ae4f017c1031d1b8a40d593ad2f28498bf84777d09a025cd24eb1c62f0f61cac159a5d9d608989f561781bd8e1e0b4aecdc1466c2b70858b136c8d90ec3e49458eabb0c592cee6400b3666bb122c03ba81e2904dc96dc0690f7f6805b00b989fa0160c9910d9173721b23e847980973d310fb007580d9c4b500025869758263047522a449d7e9154e8690739f1dae849ddf749fa33e47eafe1c9da093e14b19f7f0db898c05fdaeff8fd28f028b0dcd03819d7032be398c0e321f7fe063e4f484def7164bec52cbd013e014e84bcf798ad091449fa27448d5a1350fd62496b250d3ba8fd7321e3be19f25e7fd8e62c8ca87b23265aeac068a5a47649239e435c2a6209de10f17ebd8d0f688850b5574d12241bbc0f3ce0f07d147e3559e5c9381811f61a6c7c405dc4644dc60764c3447d42bee342c4fd8b40a70d6f6102a84d3361b642383805358f4e1bdec204509961e026b38059188398e781233916c01f21f7aa6c2a4336458c06334197098f006781efcde6693824842e03be8929b84cb83acdb3012bde423ce83947cfdc25a92a221a944ada21e9b4a7283022e9aa88b99a42de1f75cd09daa0c6fce9aa88eace3ae006a0c0e2aa3069f7fe34a9f9ad11a65c986d692ce5a9acd56dd4bec7c358f5c69116a571b21f4ef233f703af84f056964900dd66fb882721d4476d4563e20bb37374a56761263539eed11c6e31559fa4c25a5cf4d8d84997679ff0a0a7717c94c6bb6c0470d8b3006e247f70d84600dff1ffc57e1b0174107466e41b4a1cbfef0ff32361021823684bc9372cf1907f1cb75d2ceccc333fb0c6ac295cb0334e4aaccd53ecbe84950edf36021f39cedf0bb4c711c07982ce0b5fd89ce5e2aa11f812f7bac17b51b98374859152825696124f42e831cb53db6df17d04ad71c58ef30e1be1a7e21646facc46c317aa80cf80d916ef2e372a5bec61deb7d2b6d559646d8f794e64b664987399c79ae11149f35daac3c3042d2f3e71479a67d711e4f57dd50a5f0046706c96de4590d5f585d919d26d37e1af34de86a76ef10dc04f9e089b4bfa262c1f384450c4c5970046816613155c71679a678bf093837818db8a73cc0a4fada4538e8e694cd2928886890b8e639f92549374a3648d87e6a67e494f9b46a99b253d29e98c078f5f93ab5ee17260374143643ee09051fb93e4e8c8cc096029b0250f98df4e50a738c9141d9868362167418e19ef3671be8d293e34b59ba0696a13414352d21824e802b9dd95f9248ecc941234243d4bd096e213bd6657b70538c3343834d544d06ab382e08458b669ac3d2699d19ea61c9e7702988859265a4c3c365739e1d81cc67406cc96f97782eced01b3fa1c671a1e9b63e6e4e88c006604302df01f1f13ca2e9f5965a60000000049454e44ae426082",
    weather = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000007024944415478daed9b69ac5d5314c77ff79c7b5f798656b541856a2a35142115f3d4062d3586568d21a90f7c209134621621bea01f4844422a41a5a61014a16813141f680dd198690dd52ad141efbbf7fe7d786b272bdbb9e31bee2d77273be7bc73f7d967afff5eebbfd65e7bbf9c24fecf25e17f5eba007401e802d005a00b401780a12d39206f35b1bfb3da14801478041050b16bc9ae8f5abba4c67712f7ad5c43836b5320d4634205411313749601b0a3fd168495097411f0a47b1e00cd017dd6aeb9d91906007a80136c70df02df03e58cd91b07bc0e1c60bfa7eef730c85f81238035065cdcc778601f607be06d608b3daf2a647e08052fd8accc03ae37a1be037e3010be0456019f01bf013757111e27c4eec0bdc06c604f603f57c75bdd1bd801b80db8cffaab0ac2506a400f50049600d3aab4f91df805d80c1c086ce7543aab84597f1f18058c05c65469fbb201b5b9160043a901e1832b80a9cee6e5be3dda6ab3a47d74f4bce434a56c7d7f6a2640bb4ca0e200e873c4978b06254778b9e8993701af15e5e8593efa6e02ac74fd56dae10683002b814d55dc56705da9dd57cc6cc2d81237c6a213248d3c402c5309f8c67da72d7140c53efe05b0b181f6251b4f8fbdf713f0b55d73f63c71ea9e5502817e0facafa7fe436d0201fd2dc6fe7bd521b7bcb57b02f808580dfc6d2e6d1c70a891da7e9129659555e6591ad05369286b22292769beb24bc5ddcf9734a94e7f1325dd51e57d49da6ad7fbdcb76b8e71a8010803989d31d8f07751d255366024a5927aaca6920a9246d87de8f712497f678050b4eb5c6b37a2de189361308171c051cece1591d3cdc0838ebd03e115cda6fb80ad51e8fb38709df557717d86f7f70776b6f7d29a5c3784339f93943795fd399af9a25d9746ef042d9820e91c49d74aba50d2fe519bc434e329ebb3e4fa2fdb75a9a4635cfff9e13681a0fe3d92264bba46d2f392fadc404f76edc2f50c491f47e6f283a44b5dbb82dd9f2ee9af0c5308206c9474a3a4916e2cc3ca01714d259d25e96d496b248db6e741a053337862b323b8690e845452afa4f733b420fefb0d49c7674ccea0ac05720df8dbd46a58b28eb5d8ff037393a9d9fb4ce048fb7b4f0b7927b97e5e034eb33ec2626b217061c421debd0617bbd61652f3edbd41e1802443ed0373e7337e4fdd6cd7ab23248d9174b8a487256d31f32938adc949ba47f54b9fbb9fe5bf33904028cc5a0f3019381338199800ec6233fb15b00c7806f8c4029b109f67c5fb7ee9bbd5ea3a602ef00070a7d3a47821d44868feefd0b9c5990f8c7ab0a4056aac2c927468142079524b33b4ab27438b8878e3b188f814916198fdb5926e888970206a7f9e1159209c729560a7ec0869ada40b9c392491807b58b437ae8a7bcc45e3d8be0e0986f12c9174521609b6eadace96b429c3be6a95a2734db3a23eaf94b450d2bb9256485a6e3efe6a1332e69ba081d325fd59c30d6e96748ba45191d6b4a4018953fbd555506f848c2a92d64b3a40d25e92deaca2bea12c3322f4a613c876618d40e81d49c70d6620143a58d4a2f031232f93b42ad29092ab4537abab251de640c81b080f599b006cc92dac46baf6c940d702a9b1ed54637a359a77afb2041770bcf9f88af3eba9ab056bdf6731c1fd9607ac384ff134b0c1eecb2e61f239f02730c2a5de0794100959da532c875719000071f094d4e82b6c985480638119cef5e52c39faadb5c93bf738d9fa2d0ec6ce50621d178083a26ccf6045918db4137099bb4f80bf80db814576df6be04cb2d5a0066b6b4c16dc8c6ed39e620860a6386d0c89d1978039c0b9c062d38449166e0f5a4e30679b0dbd6ddecb1c15cdaadc9ee312e062e06e6062a300e41b3481926d626c6a33007f98297a622b9956e4edf71b2d3c9f00bc5b8b001b0120b07f2f700cb05b9b01180bfc0cfc082c37db5f6e1393b83d8079b64d5688d60d4d6584426c3e59d20b351291ed2e8b254d89c6dc70ad960f084c3b0d58601b8e599b96ed2a72de28b514f815b61f986b669b3c0b80b0543d047805d8c3cc204f67963031eb2ca1f2a1c9506ee58448ce4579776d03c2fbbcc4181b735a8ff86a01901a006758d85be920b5af274705381138df85d62d9f119a69cc5f1ea4886f3802a5b2093dbd191e48a24e4af49fcf99d864a8da292000ec0becea365b9b0200b3a55db6610046b9f1b76402e5664884ffd039c16033eb6d8d4d2bc7ce3a2036d860617b4b0014e83f54f4e53638990180af0d807c239a9c54e9e4550322dd46b4406ebfe0b56632564986fd27c08bc01bcebd747a09db624b8167ddc9515ad58004b895fe1399f926765fda1d0adfd4a8fbabe5054292720570a9e5dcf2f6217598da97dd62e872fa375b69466b933a36f5964585cfb9a36c9de4f7534b89cdb09560d39c556f7b3c2c347ae9dfb69e638991f1c04e6d127c13fdc7e096d37f72fc3d9710a974e269f1ee7f8c7401e802d005a00b4017802e009d59fe0128e56dafd7d014df0000000049454e44ae426082",
    camera = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000003014944415478daed9bbb8b14411087bf9ec7811a88828a7aa06686078ad105828a91868a226760602a17c921bef50f3830120545d0d8f054c45011f4ccc5403cf5041f892737bbd306538dcdbabb33ab7bb3c34c352c0b3bec6ed757d5d5355dbf31d65a9a3c021a3e14800250000a40012880068f680050465e650f0ba4f25e3a0023c6b72be2acd6b07fd4f4298503210fb015d809ac07e2123dff0bf808bc017e02e1b09d11f5f17c2ac64e0147814960d5083cbf00cc017781a7c386d02d028cd05f0d5c03cec8e7a984a02d3949bb88fb2c7379e0cd71e8005c928b81d3c0ac677434822468e5d596397d07f601f35e722c3a42016afd5cd20d8005b603cf8175de17473d5299c763e0c080493106920e18ed6e7580a331096cac58ade09cb30bd821069802df89c4f8bdc034b0dfcf21510f5a131e712a04c0cd790278979310ddb516701538096c02be0017819bbdbc1b016b2b5c2546b21de7857c1bd800dc07668071f97c0b70bec83658d5915791baf5be1bb801ecf172885b46e375bd1708c5f813c043cf78eb95f3411d6f868ce7e54bc02d60b397d4cdffde0c55fd8e36955d6b56aad6c24b39a881e75d313423c6274d3c0f8881313d1051000a4001280005a00014800250000a4001280005d02c0009b0dc4400d6b3e13a59db2c6e5a04b8d3de45e03870d98b06db9425603d7b2e00a7c8daea260f44dd92a06ba2de030e93f537f1ce0eff6aa8063944abea6d9b931063e0257048f242675fe03d7d8ec55bc08f015bcf658e16f0b5c0ae1092f5018f016ff9d31b5c04aef4039000af8594fba12aadf396cccfe438c9758f43e01cf088acb33c0f3c21471fb00d784135f50173c0c101a53285f5010ec28284492c7f9c8c282f58efff03e01b70560c48072c9442b127eaa70fb00220016e930911a6bd6bcb258308658e01f0894c23f4ea1f3542ed6e11d34b26673c5dd01470844c35b2660451f041c2fe0ef0ac0c95582704c844054e27385662f82f793ac1a595d0099a9c6786aaa4140d57621ea6e043538dd50afb5b909e07280005a00014800250000a4001d469fc06056acc60b93c610d0000000049454e44ae426082",
    sky = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000003514944415478daeddb4d88d5551806f0dfd470197392408da0d18ac08636e2074169b831944c2c681162db4a1074a7880822d1ae8589a1ab16914250820e1a08414921842d246d9270289508cb4647d271bcd7c53903264335c33dfffb5eeebc9b0b77f17fcefb70ce799ff37e74351a0d9d6c0fe8709b26a0d309e8ae08630996a31fcfa00f8fa017755cc3755cc4399cc5d7f8bef4e2ba0a5d8235acc19b588987a7f89dddd8d94e04ccc566bc83d94df85e1df37129fa11e8c50e6cc2cc26df518f4627e055ecc1bc02ebfb1967a246811eecc7e7859c3f8955188b1805fa70140b0bace922b6e2201a11c3e0d3f822ff36db06b0017f451542fdf8b690f3bbb0b64ae727bb031ec7b11cea9a6ddbf15e6429dc93b7e79305d6f06eab9c9f8c10da8fb70ae07f9995623d3201afe1b302d8bfe728f25be4d7e04378bf10f6f6563bff7f08d859e8dc9fc547119ec3ff7604e6e24293b5fdb8adcf42277442644b21e7877158f08c500d6f17c23c84bfa313f04a93def313d931e2e7043714c43c158980892ec16efc815905f07ec113d177c0d242cec3afc44f8b2f2b8877b51d08e82f8837dce904d4da8180be8278b3da8180928b7c2a1a011385c15b05b7ea985443b8d5a9c5d16e3c17fd085c2f8cb9b2d30978233a01a5d5da02bc189980c10a70b74626e05c05b82fe385a8049cac22fc625f451d2a9326e0b4d4b252da164ae5b070048ce14445f8dbb02ea210fab842fc83520355a8b4780d9795cb0bde6f23785d2abb87d801a3f8b0c275f4e288948aef8a5218998321656a03fea3496253c66ee963e88ad4fc54b5adc10f52d97c4eababc333a53adefc16dd5137f069be94bfc2ed5694c7d78951ca1ac922ed4c96eb57b35ee9c28cfcff85520d12fbb0516cab4b5daa7b4b10d0836fb0283809a35267e970b3334237a50eaea1e004d4f058a994d825ac965a5ba2da20ce97cc090ee66446c49d3024f52dd74b27457f92ca67a70339ff1d9ec78f5565852fe784c69e163bdec001ac30c586ab660c4cacc507aa2f7b0f65c93cd0eabac0113c9ba5eb4845826857c61c106c64667616231b0be8f82b59e4ec951a38c20f4dad965a6d5e9226c44cb19c7e1c9fe4dfd176991abbd71ec462ff1c9b9b77cfd8dcf8a3e74fa926715eca4c8f8fcddd69c7b139d393a3d3044c13d01676178f5fcfeb9f5a7f370000000049454e44ae426082",
    effects = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000007964944415478daed9b6bc8655519c7ff7b9f33ef5c521c2b4dd34a1411c162322c28265f91cc98a8d15154a4429b70328684019b6ca6996ea668bdcd242105499194038e7745a56f9604e50733480dc64f829774c6fb9cf79cfdebc33c0b1f96fbb2f63efb1d8979176cce3efbecbdf6f3ffaf673db7b54e06e8506eb90ef1b648c022018b041c94369074852424bd6e9ff7485a3165bf674afab3a45725ed93b44bd22afb2d4bea0158c8e330e053c02dc06b1c6885fb7c04b810380ac85bf6fd75d74f014cecfb0bc05abb2707b2ba7eda02ca5b087a19f00fd2daf3c0b546849a8406d6db736347288e849780f35c5fd9340484878f0136db714c83a019f07404b268f8fe2a306bcf0f2a6410f00dbb7fbea48f40421191904f43400ecc0037ba97dc68d7eab4e1c336aa8f017b2b467e1ef837702bb0da01cd2ac05fe19eab6b81849781f3eb06ab097c18898f034f01fbed78caae958d567c0c81af007f33e14626dc73c036e043156063f5bdd2a97d4af324aca99a0a29a33f00be6d9d0602b06b831a2dc881258ea05913e82d7bfe6677ef4c85da87be37b6048fbb7f02ec014e2c23396f705db9a4e3255d6aae6b600776ed78bb6750f27c2169dece87929e94f4773bffafa487ed7c99a491a4897b36b37e0b495749da69bf0f3ab8df794927483ac7faa4290ec825cdd8f958d2e992ce30610201855d3bddee913d53d6dfc48e1724dd62cf3f66fe1b49fba3fb33bb3e91b449d29cbdaf6bcc32b4be3e266949d98f1ef8d0466364d7d69a1045c41c766d939ddfe94670c64829225063490f4afa93a4fb24edb5f751027e85a48d92aeb5ef5972605312ea18b617dd60bdfdc29274f86849eb247d5ed26724bddf0911779c59c77f3170b74b7abe4125971bc1f3b13a3a02de27e969492b1d80ae6dbfa4a592564b7ac4bde31d91e0b1c04f81479da1f3c14595a5c519c84781eb5c9cd0e5c8cc737c11d8e722bd2e2d18dcebcd20d7bac1bb4a7cf424d1ddc47ef9fe8620292bf118c392eb5fb010ba0b0961107702cb5302a1bdeec14907b627eea5a38470369031a88825c2f3e700afb720a0b0f703ec0096a506429700cf960412292ff4843d6b7da582974d9b5dc01151e81a843e3b9184c269e32f1cf8e450f868e022e0af1d34e0096003f08144f001dc775d80b30b38b262c4ce72196515f8b11bf99926f07591e00ae0d3c06e17ba16d1cb82aaedb67b0f6b61e4c2f91627b427e1880a12664d13eab47087d913a564ae75c285387f7b6454fcf9b686ccadaeffcd1199deabdc0eacace8ef4ce09592da02c02f4ba68fbad60302b033cc1d79bb5098109f4c4c8814657adfa9b1338184dd0d24ec8bc0df54914d76262073559ddf38eb1e2cecaf9dda6789e073077e5c63d40209773490f0b21bf9c6e2c734e9f0970c78c80647c09713473f73f76d6e2866949170570909e1f3dc69c0a710103a3d1678c009f7805dcb12e7fcc00c9eaf07a4c6164113de5be122d5a19ed8ba2224e002e03f76ac4b78b107bfb5c490d292843b4b6a86b9b3f80b46801fe58f02a725a89c17709b03df35a61f3b124e49a9f6f64940999ae589846d776a3f4df3e1eda5d3aafd3465f14183d1f365ac1f241630db68c07516e1657dad5df4b908e2c1ffb8630daf0efcf589c1d6bb42409cd8b449a6ea5ad09e9f4ce3ea169a80cc59e21b4ac2dbae2dccf91f7689f00e16011efccf7a025f3877b93d31b61f58c5273f980478f073354b5e74ace46c75d32a35c152dfa170ca9cdf5992954debeab62480f7b1c6b966274e6d919c7526c05bfb9b7a041f0cdef712473edcb3da92a2097037705c2463af04782bbca347f063073e6fa1f62b4c03bdc7b8cc7e5bd237015ea039fa69be92b3a585b50f249d06bc18ad39fe11784fd78a504a3163ae476b5f38f06d8c58b867534925fb25ab242b25516a93030c819ff7047ee2a2bcad2dc0fbdf3f08fc338a168307996b588768b53c1e96af7724547252473eccd9d4918f55f948b75f60541236ef31cf7078938b4c01bfd40539f33d811f01df77d63c45ed87c04780cb6dd749d5b25d11156ed658f1a6950604819639b51f2d00f861a2c1fb842558cf958c76ca62cde3c0b7dc2689240d58eed47e7f0fd63e80df92083efcb62e4aa9472d96ee26d114f997c5098d04ccb8c4e6ad9ec0cf03d7381f9deaea7ee706a18b164e0c4318c4d9948591cff60c7e6c15e154f05e9659deb9df30450bc6d1e8bf01dceb96de2a356000fcc83a98efc1cf4f80ab5bccf9b2e354ebe3c1c4f25abc58fb7be0ab65cbe4652f5b0afccaedb09a36c2db3425789fd81c055c0cfc9603bb4b2735323e6109d2e7ea5c61d5dcfbe694c62f58e8ab5ababa3a1266a2efeb4bbc4188511e8fe67a5e552fa89a772701cf18bbe38ee037a66e586e59990e441cce812d395ec6303dae71c67c49db4830848e6b2ccd2c5a4c8520c8950b55c3731a3004bee6808729fb8c2dd7677de402e7b7202118cc0d0b51bdad709127034f9a6c6ff2f60ed4a5a99a9737fc9962b7a4cb6d4f5f16edfdf3dbe5c6b6e76f83a49ba32d6f0bd1821c7b24fdc1ed56dd2be921db1a9727bd3fb1f8719ea599b18bf1c58cf50bfce78b2a2d58656a1f6a01337d6d9088cb5f6b39f06f8c78a30496a0e85d38c2209d64567f659f1b24cabcc32ae036db9df10af090d5e4f4ff7a648bff1c5dfcdbdc22018b042c127008b7ff017faf011d48c7442b0000000049454e44ae426082",
    settings = "89504e470d0a1a0a0000000d4948445200000040000000400806000000aa6971de000004244944415478daed9b4b6854571cc67fa3455bd49a6951d4446b2db4c52241f041ad95a80925d2e2ce851bddf5b15183b4d82e2a2a8a28d2952b376e74e1c282b559081221f581822eac18f0856815a28e5a45eb64f27531672086ccdc73ce3d7766bc993f5c06c2fde79eef3be79ef3fd1f372389d16c6318e5d620a04140756c3320c76b7b9a08f8c6c36775350696a9c2293006780c4c72f42b009381e76ffa0a98eb011e602c303f0dafc0c21af93608681050079be078e089f9f53101538087490df02dcbfb3e043a8017402f70d3d2af230678800cf01570c8f2fe66e04bb3e99e04ae47532c455ddf49fa4fafdb79493f4a9a53c6679ea4a3920615c68e4b5a50e6592d923648ea955418e2f34a525714be28f08b250d440cee82a49f247d24699ca4ed92f20a6f0392f64a7a47d24c491b25fd350cf4701b94d45e0963a53d20039c01163b2cd947c07b09ef5b0fcd333296f75f015a8101d753609d2378aa001ee07d07f02521f6bdeb293011e80366a424e8cb011f030f6c57c0cf29020f9005b6daae8039c0dfc0db290bfd074c6c71396a056c4821f892e6e9b2790516a53801f4b90d01fd2926a0df460aef07be763c6a5cec09f027d003fc63fe360368035699244852b6df560a6f0a2863874ad39d92265750664d927625a424b7b94ae1b523c400bef648d2728bb8a374ad90940b28a17ff08d05964b7a1c60e65738802f5dcb024cc04b496be20443486a957437c6207678802f5dbb633cf781a42fa29e619b109905741b5dedbae17d607e7dac09b8ed9154bd0574025743a5c46e034b817b8e03391e033c269ddeede8f32fb0c406bc6b4e3007bc741ccca90047578f471aed5e524951d733fa6e0002ee38de3fc90557d259e14c9dfc8f6004b8becfcd01c6d8ecb1070c264140d6234a6c0b40409bc78a991e9a8059261d3edd713071b57dd61c67ae7bc069e0d35004b49ae4e85c0f00ef025b6210b0c5b3b03adb4cd892b875811052382f69a5870a6c0f1014c592c22183a19c23091db50e86920887f326d46daa003c2b694f35c3e19162814e2361933a7f9f1a79db334428cd34bb7da749c927656b81c35159e16326239446eba5583cad780a4c49714e70aacd31782ec5049c1dcd859102b000b814b5026e00fb5238fb0786831f4dc5d1a7c027c07d5b29fc8c6281342db67524f0514d52f5da209133b9425b9dd207cc03f2aec19028164a0b110fb808fc42b1fe3e0df815789500f041e037a0c5043b5d66821481616339f0b64d52df9aa0a25c5fd0483e9f493a12d1bfe362dd159aa4caf50be5256d0e95169f0db4536c933b8d7d9b5c3b7022e6ccaf070e5adedb42317b3dd148ed6bb56e941c6bd2681362aab7fe37b555b660f6085fbb9974b9be1abdc2176ae45b37049caf916f8300eae493998c11484db897b8b2316b8b75b102e4f92ef7250dbe9a5f8dfde1e1f33b29f96a8cc687930d021a04d4adfd0f0ccaabc5dcfd44850000000049454e44ae426082",
}
L.TAB_ICONS = {Visuals = "visuals", Weapons = "weapons", ESP = "esp", Hitboxes = "hitboxes", Aim = "aim", World = "world",
    Weather = "weather", Camera = "camera", Sky = "sky", Effects = "effects", Settings = "settings"}
L.iconCache = {}
-- иконки (Font Awesome Free, CC BY 4.0) -> png в workspace -> getcustomasset
function L.iconAsset(key)
    if L.iconCache[key] then return L.iconCache[key] end
    local fn = getcustomasset or getsynasset
    if typeof(writefile) ~= "function" or typeof(readfile) ~= "function" or typeof(fn) ~= "function" or not L.ICONS[key] then return nil end
    local ok, id = pcall(function()
        local name = "scorpion_ico_" .. key .. "_v1.png"
        local hex = L.ICONS[key]
        local want = #hex // 2
        local have = -1
        if typeof(isfile) == "function" and isfile(name) then
            local okR, d = pcall(readfile, name)
            have = okR and #d or -1
        end
        if have ~= want then
            writefile(name, (hex:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)))
            if #readfile(name) ~= want then error("bad write") end
        end
        return fn(name)
    end)
    if ok and type(id) == "string" and id ~= "" then
        L.iconCache[key] = id
        return id
    end
    return nil
end

local Tabs, activeTab = {}, nil

local function SelectTab(tab)
    if activeTab == tab then return end
    if activeTab then
        activeTab.Page.Visible = false
        activeTab.Button.BackgroundColor3 = Theme.Box
        activeTab.Label.TextColor3 = Theme.TextDim
        activeTab.Dot.BackgroundColor3 = Theme.Off
        activeTab.Icon.ImageColor3 = Theme.TextDim
        activeTab.Bar.Visible = false
    end
    activeTab = tab
    tab.Page.Visible = true
    tab.Button.BackgroundColor3 = Theme.Head
    tab.Label.TextColor3 = Accent
    tab.Dot.BackgroundColor3 = Accent
    tab.Icon.ImageColor3 = Accent
    tab.Bar.Visible = true
end

local function newColumn(page, xScale, xOffset)
    local col = new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.White, ScrollBarImageTransparency = 0.7,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        Position = UDim2.new(xScale, xOffset, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Parent = page,
    })
    new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col})
    new("UIPadding", {PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 5), Parent = col})
    return col
end

local function CreateTab(name)
    local btn = new("TextButton", {
        BackgroundColor3 = Theme.Box, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
        LayoutOrder = #Tabs + 1, Parent = TabBar,
    })
    local bar = new("Frame", {
        Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Accent, BorderSizePixel = 0, Visible = false, Parent = btn,
    })
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 9), Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = btn,
    })
    local icon = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.fromOffset(17, 17),
        BackgroundTransparency = 1, ImageColor3 = Theme.TextDim, Visible = false, Parent = btn,
    })
    local iconKey = L.TAB_ICONS[name]
    task.spawn(function()
        local id = iconKey and L.iconAsset(iconKey)
        if id and icon.Parent then
            icon.Image = id
            icon.Visible = true
            dot.Visible = false
        end
    end)
    local lbl = makeText(btn, name:lower(), 12, Theme.TextDim, Enum.TextXAlignment.Center)
    lbl.Position = UDim2.new(0, 0, 0, 24)
    lbl.Size = UDim2.new(1, 0, 0, 16)

    local page = new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = Content})
    local tab = {
        Name = name, Button = btn, Label = lbl, Bar = bar, Dot = dot, Icon = icon, Page = page,
        Left = newColumn(page, 0, 0), Right = newColumn(page, 0.5, 4),
    }
    table.insert(Tabs, tab)
    TabGrid.CellSize = UDim2.new(1 / #Tabs, -4, 1, 0)
    table.insert(accentRenders, function()
        bar.BackgroundColor3 = Accent
        if activeTab == tab then
            lbl.TextColor3 = Accent
            dot.BackgroundColor3 = Accent
            icon.ImageColor3 = Accent
        end
    end)

    btn.MouseButton1Click:Connect(function() SelectTab(tab) end)
    btn.MouseEnter:Connect(function() if activeTab ~= tab then lbl.TextColor3 = Theme.Text end end)
    btn.MouseLeave:Connect(function() if activeTab ~= tab then lbl.TextColor3 = Theme.TextDim end end)
    if #Tabs == 1 then SelectTab(tab) end
    return tab
end

local function CreateGroup(column, title)
    local box = new("Frame", {
        BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = column,
    })
    new("UIPadding", {PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = box})
    new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box})

    local head = new("Frame", {BackgroundColor3 = Theme.Head, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = -2, Parent = box})
    local hdr = makeText(head, title, 15, Theme.White)
    hdr.Position = UDim2.fromOffset(10, 0)
    hdr.Size = UDim2.new(1, -10, 1, 0)
    return box
end

-- короткая подсказка под заголовком группы
local function CreateHint(group, text)
    local lbl = makeText(group, text, 12, Theme.TextDim)
    lbl.TextWrapped = true
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    return lbl
end

-- ============================================================
--  МЕНЮ: контролы
-- ============================================================
local function CreateToggle(parent, text, default, callback)
    local state = default and true or false
    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Parent = parent})
    local box = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Theme.Box, BorderSizePixel = 0, Parent = row,
    })
    local tick = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Accent, BorderSizePixel = 0, Visible = false, Parent = box,
    })
    local lbl = makeText(row, text, 14, Theme.TextDim)
    lbl.Position = UDim2.fromOffset(28, 0)
    lbl.Size = UDim2.new(1, -28, 1, 0)
    local hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = row})

    local function render()
        tick.Visible = state
        tick.BackgroundColor3 = Accent
        box.BackgroundColor3 = state and Theme.Head or Theme.Box
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

    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = parent})
    local lbl = makeText(row, o.Text, 13, Theme.TextDim)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.TextTruncate = Enum.TextTruncate.AtEnd

    local bar = new("Frame", {
        Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 18),
        BackgroundColor3 = Theme.Box, BorderSizePixel = 0, ClipsDescendants = true, Parent = row,
    })
    local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Accent, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = bar})
    local valueLbl = makeText(bar, "", 13, Theme.White)
    valueLbl.Position = UDim2.fromOffset(6, 0)
    valueLbl.Size = UDim2.new(1, -8, 1, 0)
    valueLbl.ZIndex = 3
    local knob = new("Frame", {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false, Parent = bar})

    local marker
    if o.Track then
        bar.BackgroundColor3 = Theme.White
        bar.BackgroundTransparency = 0
        new("UIGradient", {Color = o.Track, Parent = bar})
        fill.Visible = false
        knob.Visible = false
        marker = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3, 18),
            BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 2, Parent = bar,
        })
    end

    local function snap(v)
        v = math.clamp(v, o.Min, o.Max)
        v = math.floor((v - o.Min) / step + 0.5) * step + o.Min
        return math.clamp(v, o.Min, o.Max)
    end
    local function render()
        local a = (value - o.Min) / (o.Max - o.Min)
        fill.Size = UDim2.fromScale(a, 1)
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
        Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 1, 0),
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

    local lbl = makeText(row, o.Text, 13, Theme.TextDim)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.LayoutOrder = 1

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.Box,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = 2, Parent = row,
    })
    local current = makeText(head, "", 14, Theme.White)
    current.Position = UDim2.fromOffset(8, 0)
    current.Size = UDim2.new(1, -26, 1, 0)
    local arrow = makeText(head, "+", 14, Theme.TextDim, Enum.TextXAlignment.Center)
    arrow.Position = UDim2.new(1, -20, 0, 0)
    arrow.Size = UDim2.fromOffset(16, 26)

    local list = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Head,
        BorderSizePixel = 0, Visible = false, LayoutOrder = 3, Parent = row,
    })
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
            Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, AutoButtonColor = false, Text = name,
            Font = Theme.Font, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = list,
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
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.Box,
        BorderSizePixel = 0, AutoButtonColor = false, Text = text, TextColor3 = Theme.White,
        Font = Theme.Font, TextSize = 14, Parent = parent,
    })
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Theme.Head end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Theme.Box end)
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

local function CreateKeybind(parent, text, default, onSet)
    local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Parent = parent})
    local lbl = makeText(row, text, 14, Theme.TextDim)
    lbl.Size = UDim2.new(1, -70, 1, 0)

    local keyBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(66, 18),
        BackgroundColor3 = Theme.Box, BorderSizePixel = 0, AutoButtonColor = false,
        Text = default and ("[" .. default.Name .. "]") or "[None]",
        TextColor3 = Theme.White, Font = Theme.Font, TextSize = 12, Parent = row,
    })

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
--  ЛОГГЕР УРОНА: мини-панель на экране (кто, сколько снёс, килл)
-- ============================================================
do
(function()
    local panel = new("Frame", {
        Name = "ScorpionDamageLog", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -22, 0.45, 0),
        Size = UDim2.fromOffset(230, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.05, BorderSizePixel = 0, Visible = false, Parent = EspGui,
    })
    new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = panel})
    new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel})

    local head = new("Frame", {BackgroundColor3 = Theme.Head, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Parent = panel})
    local title = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.5, 0, 1, 0), Font = Enum.Font.Code, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "damage log", TextColor3 = Accent, Parent = head,
    })
    table.insert(accentRenders, function() title.TextColor3 = Accent end)
    local total = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), Font = Enum.Font.Code,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = Theme.White, Parent = head,
    })

    local rows, order = {}, {}
    local sum, hits, lastHit = 0, 0, 0
    local lmbDown, lmbUp = false, 0

    bind(UserInputService.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then lmbDown = true end
    end)
    bind(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            lmbDown = false
            lmbUp = os.clock()
        end
    end)

    -- урон считаем только пока ты стреляешь (кнопка зажата / только что отпущена / игра сделала выстрел)
    function L.dlogShooting()
        local now = os.clock()
        return lmbDown or now - lmbUp < 0.5 or now - (L.lastShotAt or 0) < 0.6
    end

    local function dmgColor(d)
        local k = math.clamp(d / 60, 0, 1)
        return Color3.new(1, 1 - k * 0.65, 1 - k * 0.65)
    end

    local function removeRow(name)
        local r = rows[name]
        if not r then return end
        rows[name] = nil
        for i, n in ipairs(order) do if n == name then table.remove(order, i) break end end
        r.frame:Destroy()
    end

    local function paint(r)
        r.dmgLbl.Text = "-" .. math.floor(r.dmg + 0.5) .. (r.hits > 1 and ("  x" .. r.hits) or "")
        r.dmgLbl.TextColor3 = dmgColor(r.dmg)
        r.tag.Visible = r.killed
    end

    function L.dlogAdd(name, dmg, killed)
        local now = os.clock()
        local r = rows[name]
        if r and now - r.t < 1.6 then
            r.dmg = r.dmg + dmg
            r.hits = r.hits + 1
            r.t = now
            r.killed = r.killed or killed
        else
            if r then removeRow(name) end
            L.dlogSeq = (L.dlogSeq or 0) + 1
            local frame = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2 + L.dlogSeq, Parent = panel})
            local nm = new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(0.55, 0, 1, 0), Font = Theme.Font, TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = name, TextColor3 = Theme.Text, Parent = frame,
            })
            local dl = new("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.fromScale(0.55, 0), Size = UDim2.fromScale(0.45, 1), Font = Enum.Font.Code,
                TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = Theme.White, Parent = frame,
            })
            local tag = new("TextLabel", {
                BackgroundColor3 = Accent, Size = UDim2.fromOffset(34, 14), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.55, -38, 0.5, 0),
                Font = Enum.Font.Code, TextSize = 10, Text = "KILL", TextColor3 = Color3.new(1, 1, 1), Visible = false, BorderSizePixel = 0, Parent = frame,
            })
            nm.Size = UDim2.new(0.55, -40, 1, 0)
            r = {frame = frame, dmgLbl = dl, tag = tag, dmg = dmg, hits = 1, t = now, killed = killed}
            rows[name] = r
            order[#order + 1] = name
            while #order > math.max(1, cfg.dlogRows) do removeRow(order[1]) end
        end
        paint(r)
        sum = sum + dmg
        hits = hits + 1
        lastHit = now
        total.Text = math.floor(sum + 0.5) .. " dmg  /  " .. hits
        panel.Visible = true
    end

    local acc = 0
    bind(RunService.Heartbeat, function(dt)
        if unloaded then return end
        acc = acc + dt
        if acc < 0.15 then return end
        acc = 0
        local now = os.clock()
        for _, name in ipairs({table.unpack(order)}) do
            local r = rows[name]
            if r and now - r.t > cfg.dlogTime then removeRow(name) end
        end
        if #order == 0 and now - lastHit > cfg.dlogTime + 0.4 then
            panel.Visible = false
            sum, hits = 0, 0
            total.Text = ""
        end
        local pos = cfg.dlogPos
        if pos == 2 then
            panel.AnchorPoint, panel.Position = Vector2.new(0, 0.5), UDim2.new(0, 22, 0.45, 0)
        elseif pos == 3 then
            panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.58, 0)
        else
            panel.AnchorPoint, panel.Position = Vector2.new(1, 0.5), UDim2.new(1, -22, 0.45, 0)
        end
    end)

    function L.dlogCleanup() pcall(function() panel:Destroy() end) end
end)()
end

-- ============================================================
--  ИНФО-ХУД ПО ИГРОКАМ (как в читах на Rust): что в руках, перезарядка, во что одет, состояние
--  Панель «Nearby players» (список ближайших) и карточка «Target» (тот, кто ближе к прицелу)
-- ============================================================
do
(function()
    local cache = setmetatable({}, {__mode = "k"})

    local function ammoOf(inst)
        if not inst then return nil end
        local a = inst:GetAttribute("Ammo") or inst:GetAttribute("CurrentAmmo") or inst:GetAttribute("Mag") or inst:GetAttribute("Magazine")
        local m = inst:GetAttribute("MaxAmmo") or inst:GetAttribute("MagSize") or inst:GetAttribute("Reserve")
        if a == nil then
            for _, c in ipairs(inst:GetChildren()) do
                if c:IsA("ValueBase") and type(c.Value) == "number" then
                    local n = c.Name:lower()
                    if n == "ammo" or n == "currentammo" or n == "mag" or n == "magazine" or n == "clip" or n == "bullets" then
                        a = c.Value
                    elseif n == "maxammo" or n == "reserve" or n == "magsize" or n == "reserveammo" then
                        m = c.Value
                    end
                end
            end
        end
        if type(a) ~= "number" then return nil end
        return m and (math.floor(a) .. "/" .. math.floor(m)) or tostring(math.floor(a))
    end

    local RELOAD_WORDS = {"reload", "rechamber", "magazine", "recharge"}
    local function reloadLeft(char, hum, tool)
        if char:GetAttribute("Reloading") == true or (tool and tool:GetAttribute("Reloading") == true) then return 0.1 end
        local bv = (tool and tool:FindFirstChild("Reloading")) or char:FindFirstChild("Reloading")
        if bv and bv:IsA("BoolValue") and bv.Value then return 0.1 end
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
            if ok then
                for _, tr in ipairs(tracks) do
                    local n = (tr.Name or ""):lower()
                    local an = tr.Animation and (tr.Animation.Name or ""):lower() or ""
                    for _, w in ipairs(RELOAD_WORDS) do
                        if n:find(w, 1, true) or an:find(w, 1, true) then
                            local left = tr.Length > 0 and (tr.Length - tr.TimePosition) / math.max(tr.Speed, 0.05) or 0.5
                            return math.max(left, 0.1)
                        end
                    end
                end
            end
        end
        return nil
    end

    local function stateOf(hum, hrp)
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Seated then return "Sitting" end
        if st == Enum.HumanoidStateType.Climbing then return "Climbing" end
        if st == Enum.HumanoidStateType.Swimming then return "Swimming" end
        if st == Enum.HumanoidStateType.Jumping then return "Jumping" end
        if st == Enum.HumanoidStateType.Freefall then return "Falling" end
        local v = hrp.AssemblyLinearVelocity
        local sp = Vector3.new(v.X, 0, v.Z).Magnitude
        if sp < 1 then return "Standing" end
        if sp < 12 then return "Walking" end
        return "Running"
    end

    function L.gearGet(plr, char, hum)
        local now = os.clock()
        local c = cache[char]
        if c and now - c.t < 0.25 then return c end
        c = c or {}
        c.t = now
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local tool = char:FindFirstChildOfClass("Tool")
        c.weapon = tool and tool.Name or char:GetAttribute("Weapon") or plr:GetAttribute("Weapon") or "Hands"
        c.weapon = tostring(c.weapon)
        c.ammo = ammoOf(tool)
        c.reload = reloadLeft(char, hum, tool)
        c.state = hrp and stateOf(hum, hrp) or "-"
        local wear = {}
        for _, ch in ipairs(char:GetChildren()) do
            if ch:IsA("Accessory") then
                wear[#wear + 1] = ch.Name
            elseif ch:IsA("Shirt") or ch:IsA("Pants") or ch:IsA("ShirtGraphic") then
                wear[#wear + 1] = ch.ClassName
            elseif ch:IsA("Model") and not ch.Name:find("^Scorpion") then
                wear[#wear + 1] = ch.Name
            end
            if #wear >= 12 then break end
        end
        c.wear = wear
        local short = {}
        for i = 1, math.min(3, #wear) do short[i] = wear[i] end
        c.wearShort = table.concat(short, ", ") .. (#wear > 3 and (" +" .. (#wear - 3)) or "")
        c.wearFull = #wear > 0 and table.concat(wear, ", ", 1, math.min(#wear, 7)) .. (#wear > 7 and (" +" .. (#wear - 7)) or "") or "nothing visible"
        cache[char] = c
        return c
    end

    -- ---------- панели ----------
    local function mkPanel(name, anchor, pos, width)
        local f = new("Frame", {
            Name = name, AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.05, BorderSizePixel = 0, Visible = false, Parent = EspGui,
        })
        new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = f})
        new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f})
        return f
    end
    local function lbl(parent, text, size, color, font, order)
        local l = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, size + 4), Font = font or Theme.Font, TextSize = size,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = text,
            TextColor3 = color or Theme.Text, LayoutOrder = order or 0, Parent = parent,
        })
        return l
    end
    local function header(parent, text)
        local bg = new("Frame", {BackgroundColor3 = Theme.Head, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Parent = parent})
        local h = new("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -8, 1, 0), Font = Enum.Font.Code, TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left, Text = text:lower(), TextColor3 = Accent, Parent = bg,
        })
        table.insert(accentRenders, function() h.TextColor3 = Accent end)
        return h
    end
    local RED = Color3.fromRGB(255, 90, 90)
    local function hpColor(a) return RED:Lerp(Color3.fromRGB(90, 255, 130), a) end

    -- список ближайших
    local nearby = mkPanel("ScorpionNearby", Vector2.new(0, 0), UDim2.new(0, 22, 0, 120), 250)
    header(nearby, "nearby players")
    local rows = {}
    for i = 1, 8 do
        local fr = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 10 + i, Visible = false, Parent = nearby})
        local name = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(0.62, 0, 0, 16), Font = Enum.Font.Code, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", TextColor3 = Theme.White, Parent = fr})
        local dist = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromScale(0.62, 0), Size = UDim2.new(0.38, 0, 0, 16), Font = Theme.Font, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = Theme.TextDim, Parent = fr})
        local item = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(0.75, 0, 0, 14), Font = Theme.Font, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", TextColor3 = Theme.TextDim, Parent = fr})
        local hp = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromScale(0.75, 0), Size = UDim2.new(0.25, 0, 0, 30), Font = Enum.Font.Code, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Bottom, Text = "", TextColor3 = Theme.White, Parent = fr})
        rows[i] = {fr = fr, name = name, dist = dist, item = item, hp = hp}
    end

    -- карточка цели
    local card = mkPanel("ScorpionTargetCard", Vector2.new(0, 0.5), UDim2.new(0, 22, 0.66, 0), 250)
    header(card, "target")
    local cName = lbl(card, "", 15, Theme.White, Enum.Font.Code, 10)
    local hpBack = new("Frame", {BackgroundColor3 = Theme.Box, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 8), LayoutOrder = 11, Parent = card})
    local hpFill = new("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = hpBack})
    local cHp = lbl(card, "", 13, Theme.TextDim, nil, 12)
    local cHold = lbl(card, "", 14, Theme.Text, nil, 13)
    local cReload = lbl(card, "", 14, RED, Enum.Font.Code, 14)
    local cState = lbl(card, "", 13, Theme.TextDim, nil, 15)
    local cWear = lbl(card, "", 13, Theme.TextDim, nil, 16)
    cWear.TextWrapped = true
    cWear.TextTruncate = Enum.TextTruncate.None
    cWear.AutomaticSize = Enum.AutomaticSize.Y
    cWear.Size = UDim2.new(1, 0, 0, 0)
    cWear.TextYAlignment = Enum.TextYAlignment.Top

    local acc = 0
    bind(RunService.Heartbeat, function(dt)
        if unloaded then return end
        acc = acc + dt
        if acc < 0.2 then return end
        acc = 0
        local cam = workspace.CurrentCamera
        if not cam then return end
        local camPos = cam.CFrame.Position
        local vs = cam.ViewportSize
        local list, best, bestScr = {}, nil, math.huge
        if cfg.infoNearby or cfg.infoTarget then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character then
                    local char = plr.Character
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then
                        local d = (hrp.Position - camPos).Magnitude
                        if d <= cfg.infoRange then
                            local e = {plr = plr, char = char, hum = hum, hrp = hrp, dist = d}
                            list[#list + 1] = e
                            local sp = cam:WorldToViewportPoint(hrp.Position)
                            if sp.Z > 0 then
                                local off = (Vector2.new(sp.X, sp.Y) - vs / 2).Magnitude
                                if off < bestScr and off < math.min(vs.X, vs.Y) * 0.4 then best, bestScr = e, off end
                            end
                        end
                    end
                end
            end
        end
        table.sort(list, function(a, b) return a.dist < b.dist end)

        -- ближайшие
        nearby.Visible = cfg.infoNearby and #list > 0
        if nearby.Visible then
            for i = 1, 8 do
                local r, e = rows[i], list[i]
                if e and i <= cfg.infoRows then
                    local g = L.gearGet(e.plr, e.char, e.hum)
                    r.fr.Visible = true
                    r.name.Text = e.plr.DisplayName ~= "" and e.plr.DisplayName or e.plr.Name
                    r.dist.Text = math.floor(e.dist) .. " studs"
                    local item = g.weapon
                    if g.ammo then item = item .. "  " .. g.ammo end
                    if g.reload then
                        item = string.format("RELOAD %.1fs", g.reload) .. "  ·  " .. g.weapon
                        r.item.TextColor3 = RED
                    else
                        r.item.TextColor3 = Theme.TextDim
                    end
                    r.item.Text = item
                    local a = math.clamp(e.hum.Health / math.max(e.hum.MaxHealth, 1), 0, 1)
                    r.hp.Text = math.floor(e.hum.Health + 0.5) .. " hp"
                    r.hp.TextColor3 = hpColor(a)
                else
                    r.fr.Visible = false
                end
            end
        end

        -- карточка цели
        card.Visible = cfg.infoTarget and best ~= nil
        if card.Visible then
            local e = best
            local g = L.gearGet(e.plr, e.char, e.hum)
            local a = math.clamp(e.hum.Health / math.max(e.hum.MaxHealth, 1), 0, 1)
            cName.Text = (e.plr.DisplayName ~= "" and e.plr.DisplayName or e.plr.Name) .. "   " .. math.floor(e.dist) .. " studs"
            hpFill.Size = UDim2.fromScale(a, 1)
            hpFill.BackgroundColor3 = hpColor(a)
            cHp.Text = math.floor(e.hum.Health + 0.5) .. " / " .. math.floor(e.hum.MaxHealth) .. " hp"
            cHold.Text = "Holding:  " .. g.weapon .. (g.ammo and ("   [" .. g.ammo .. "]") or "")
            cReload.Visible = g.reload ~= nil
            if g.reload then cReload.Text = string.format("RELOADING  %.1fs", g.reload) end
            cState.Text = "State:  " .. g.state
            cWear.Text = "Wearing:  " .. g.wearFull
        end
    end)

    function L.infoCleanup()
        pcall(function() nearby:Destroy() end)
        pcall(function() card:Destroy() end)
    end
end)()
end

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
    Sukharik = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080300030003012200021101031101ffc4001c0000010501010100000000000000000000000102040506030708ffc40041100001030303020503020502050206030101000203040511122131061307224151711432611523083342819152a1162472b1c135621734364373922553b282ffc4001a010100030101010000000000000000000000010203050406ffc400281101010002020201040203010101000000000102110304213112133241511422053361152371ffda000c03010002110311003f00f14257d1b72fe21ed9d01e1c74e525ba26d757476ca685ed07f96f10b41ff057cde4a8262d133dc5fac1713a4fa2ecce1c792ff6fc397396f1f989979bcbfa8ee735da56963ea1c5e5a7d32a1a0fc610bdb26bc3c96eeec210852808421008421008421008421008421008421008421008421008421008421008421008421008421021420a11010842010842012a44a898108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420108420123c6a691ee12a107a3f4a78e7274c7425c7a29f406665c29e5a56c9ff00f59918599ff758505446101c3ca39e70a402bcb9e131bb9f97a71cee5357f0525457fdeef95dcb97077dc7e55f8bda9cbe8884216ec421084021084021084021084021084021084021084021084021084021084021084021084021084021084061214677c250dca040948411849940250120297281400936ca6ee4a52d501db230998294121029184209ca14810842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842010842056fdc3e57705701c85d03961cbedb71fa05cb91e4a5d49138bda39021085bb20842100842100842100842100842100842100842100842100842100842100842100846e840211942010840df840842425c3d0a7b62797e31b2b8a1a18646fee2846e45202e3e85386caeab6861637f6d533e2735e411b29370d27d93751f653e9295929c1566cb4c2079b087ca33c1f81c240e713c157eeb5c1ac259e92963663232a132c51077ba5c02ba54318d3e55c1aedd0388c2104e51940211942902108402108402108402108ca0108ca4ca05424ca1a751c3502a13bb4ff648e6399f7204426ea0ba089ee1a80d9035094024e3082c7019c6c88d910809321125424ca3281508ca3280423284021084021084021084021084021084021084021084021084021084021084021084027029a932b0e5f6d78fd1329c385cb2ba0e029e2f672150842d9904210804210804210804210804210804210804210804210804210804210804812a38402428ca14a0897490840273ca2db21c84e01c06404ecb411956f6f8e17b72e682a14b90b753b648b53c60a9586b0e02473435d866c128667956637d821afd8a8b72a56b69cb998254a7331c240356cfdc213c2a6dcc941c9571a9da77446c8dafd86c966fc226ddf92e32c2553574ae0e23255bb43bb44efc2a4ad3fb85455b04673b23748cc25236481aa1a94e3d122318422020210102a10844842108042108048952222840c7aa10103f2cc614aa08a37bf70a0bb9d94eb6675282fa5ab69e21c85577484b9de41fe15a3c127017564318693229672eab390c4dc00f1bab8a0a70f6e31b2855f4c5d2e62e14ca2a910c5a09f31432bb767d0c0d71c00b8d553c4d80e00ca910b5e492edf3c2e3591b8b748528914ae001202636339c95d9f492ea29af81f18dd43594c763d122004ecb50a1ba7d534f2823",
            "3c214902021011347aa549ea95422042108908421008421008421008421008421008421008421008421008421021e0a6653ddc15cb2b1e5f6d78c995d9bf68f851f2a437ed1f09c7ece42a1085b32084210084210084210084210084210084210084210084210084210084210090a10774064212061d413c445d28014a69adc9200528d0481a1d8382a4c341821d8562c76a60611c22972676781cc70cab8b6b5bd9c928aea5d7c0450c0e6f94f0a14b96e2567741ca8d3d4b2297402a4b3ced042b2343740dd3a4f290901df6454d6f95e99515219caeb8cb8aadb96c762899129b7363632df7551573073f2b9ff74d7341e5456b8cd17564268ca5c6100e1424833ea95077420101080815084224210840210840244a911142021081f86e32a5504cc63f72a10c676439a5bbb54166da0158c0e18533e8df58ccb338fc2a2b7b0480179dd6c6cde56631e8a631be2a88d37d3021e32551551732a4387195acbb8fdc71594ae7e24c7e517c3dad61ba303180e3213beba3964036dd509c100e577b680eaa1a8ec8b7c57fdb616e74aadb9bb03002b495cd6001bc2aabbb806023952acf681140f9780bb7e9cfe77526d5234b770acdd8730e0284db633924463d8a62b2a9a47c8e380ab9cd2d716fb2265d910126e8dd4ac5f54a90255004210804210804210804210804210804210804210804210804210804210811df69f85c32bbbbed3f0a3ac791a71932a4b3ec6fc289952d9f637e138fd9c854210b6661084201084201084201084201084201084201084201084201084201090a56ee81437291c08e13c6072523bdc2881370ba5292ea8685c4b89385de90627054a2b42d68d031ecb969731d94ad79d2364f7480b7f2a596c870efb90e1a1a4850aaaa8c4a38b9ea1ca1a45ac73bea75654b82bcb035b955f3c9dc79288da4c8df9469af0d01799304ae9a31ba463408987f09359254b2a5077559723bab26e49d86555dcf39dc61138a00485204a5456b4210850042108040420205421089084210084210194883ca0220a020b764e012edee8972030539c764b8d476449191ba81636b6ea195a1a4ad14edc2ceda9fa480ad670d0362a631bedd2b6a3ea1c70a9ea280bf2ec29e069194f24ba07e06765298ce188b490bbd047fbe0ae05cf323f3ee96199f1c99c60286976d0bd9b0dd47a9a4eeb4677511f7121b9caed495c67d8a967abedda968db13760bbe74ec12b5d848e1ba2b68f427f0b3f3ff003dcb42e3a587e167a6399de8be2e78dd2a546dee8b93d50828509810842010842010842010842010842010842010842010842010842010842047fd8ef85172a4bfec77c151563c9eda71932a5b3ec6fc05114b67d8df809c7ece4390842d9984210804210804210804210804210804210804210804210502652a441428e5217e9194e68c9492050458d0db056c45e5d8d9459e3743218c0270aced6e2d8801eaa54d6ec8ee06e728cae5aacfc71b8c832dc057515042c8c4ba86af64d7d286c65c460855d0d4b9d53dbc9c2b6a16ed771bc39bc24c00729c5a1918c2633cca74a6d5773f365563585a3215add18e00e02ae8daed3920a8d36c6ea0635c77c27b1dfba0615952d1eba7d446f8509f4ee6d40c0d91172daed83540d3ec10c19d93a9ff0092014808664fa23288b5358ea339032ab2a6b4d66e4614daf735e0aac1804a5adb1860e53b0931ba550b1308c254204c230950813095085080930950900937f64a86bb3b28a9836f5293e12b980a191927657fc1b377f64e01d8ce1747b0b00c85694741de881d3ca8936adc9510973dfa70558bed43e9fbbab7f65611da5ac05fa5255e1b4a58de55a447cbca92822ef4fdb3e854caea36c2dd8a8f6d86415076df2a65d5b206eea97d197b40866301d93e4b849905451a8943fd1254fc62f2965efc40953229442c2d23390a0507f24296e56f0a5449e81818f9873ecab69ffe666ed96e3d15ee358d2782b87d0b619358182a744cb4835d41f4ed1a7751e39cd20ce15e7684e70e5577783b380145899e7c24d0d43aa773b2965dbe143b3372d0ac2460072a24b55b354c90e6323f0b3d291de7efeab40770ef85",
            "9d9999a978fca9cbc4698c87d3b054ca23f752ab6dbf46d0ece72b9d0405938715617525f1edbecab84b67932f6a5ce46526538b481b84dc22d072952612f09b4049946e852408084a116a1084220210840210840210840210840210840210840d7fd8ef82a2654b7fd8ef82a22cb91a71852d9f637e0288a5b3ec6fc051c7ece4390842d99842108042108042108042108042108042108042108048952630817091194a880dd90ef31438e0274503e56e5a140b6b70f20c2d351490f60b64c70b3b6d8cc6c01fb290f964d7869d94c6397b3ee2f6f9db1f0550454b20abd7838576e6648250e6b00d86eac4b67a2e498c02963f2f29048d633cc54715b197119444c5d6a446f1e64434d4e59e8ab6b2ab51f295d6824711e628b6964dd2cf2b785c9d4e1cece13c8d9235c42229c3ca30a356c85909214a182a15d06202a0c552e9dcf0b96774b18d9296eea1beb4769db29a9d9db09aa008421481084201225483944529424284070949006dca4498dd4ad29cd63de765674349b8d6173a1d0e201c2b86d2b9ecfdb1bac79b2f8e3b471cf9e5a7396969c86838cad05aa9a9c403ca38544db7d4170d40abfa0618a20d72e77f3acf0f7ff025f3b3ea218846e0d0a8a6a42f2435ab43804e0faa7186203200257b3add8f9bc5d8ebfc2b2d4f6f7c72674ae17c8ded8f38c2d6384510d6e60c2a2ea3ac8268711e3217aad7971ded90638929ee4d8dc09384e71e13dbd17dae283f9214a77a28b6ff00e480a53bd14e98da3382139d26a3840c6375cc91a94e94d9cd7163940babbb9bab00dceeabae4309715e1b6e9fb5b2b3ef7702ceb242d3b2b3a4ab6704eea31c96f87e53c70ef854a699ceab271b655c6b0402384b242df2b9bca9cbcb3f9595ca3a6edb412175edb653872e8f765a02466dba89747caaaee903621e555d8f285697285f39f2aae7c7da680e516f96d8df0e7c244a46784836d9162a3184a0242a36822508e109bda42108520421080421080421080421080421080421081aff00b1df054452dff63be0a88b2e469c614b67d8df80a2296cfb1bf01471fb390e4210b6661084201084201084201084201084201084201084200ec3288dddd38080353c33dd59535af410e239445ba8e515b8bdb95caa28dd0fa2bd8836218c28972702dc808a4b54647bab7b4b806eedcaa971c92adad3f6845b2f4b079c9d86123480877290ee14b2a51ba4ed90e4a0e94d96a34372a488b5ec7169c6ca9f49d44071ca9955702f25bba86010ed5ba8ad719a48828df211c95670d1ba36e48c2ae82bcc240c2b5a6adfa9d94c572ffaecdd86e9ae704e78d2b9e0928ce941dd70ba1cd31528330a25d08fa620150b63148cfb13b29acfb12a86c10952280210852042108049ea95080488e1185169215348252e13f4eca767a77b7821e16caccf6e5ba802b236f0352d1d2540880c15e6ed7faeafd7ff0066da095cdd5e5605cc827d30aacddcb5c97f5a2b81adf977567871f44d71742dd6ee156feb47dd327ba9a888c7eebabfe3a561cbc133f6ed5d716544458d202cecf4a09397e72a40003ce4eca5d15032b266b464aeb5c58ff0b09e5979e06d2bb249dd730f8c9ce57a35c7a11b3d28786bb85431f44f98b74bd675e0e5c66354b4b5d1c7b172b4a69a19883a94a3d0b877daf53a9fa4440dfb5cb5c66de6cbe3f856cddbd4034ae73358c664156f2f4f1634b835db2812dbf39696b961cd9dc67853c39c3a5f172aaae981b13b2b67c4da58fcc1c156d608aa5b800ae4f2f7b397516c6cdaadba03795c180f7861deaac596f03d0a7b6d3bea016dd6ece59e5aad7e722c28e30f846e9f920e95ce9637c63485d43bccbab3cbcf9ebf000f5287bb0339439fb6174a7a6fa8f2ae7f6b9f2e3cb4e9757af8e73c9f434bf544ed955d76b4b8c8719185a9a1a5fa219c24a9a715049c72bd1c39ccf0dd7979f0bc7c9a8c0cb18a7d895c490e3b157d76b637b9b0504db591b32395afff0088c739af2801f8d8a3929d2445a5373809a5b7b291a9006364b1e33ba1ff00724088421481084201084201084201084201084201084206bfec77c15114b7fd8ef82a22cb91a71852d9f637",
            "e0288a5b3ec6fc051c7ece4390842d99842108042108042108042108042108042108042108159fcf61fcad1c526b8dbf0b391ff3dbf2b4110f2b71ec914cee8ec12e51ae20363dd4b1b2877005ed53a678df2a4c8713856d6a3e5558e676c1d9595a4ea6ec9a699fa58bf94994841d694ccc3e5f509a653c9d80709d2d187445da82e4f70ec39c0ee155d2d4cf24fa0bce32a5331a902dec7b8ec9ceb706f2a530687729e4927744ed03f4d63bd1778697e9f70bbf09492511bd933a923794f6601dd739256e1d8e546d120a87f6d99c854f5557ddf265739aa647cae6976cb8b879b2a36d71c74318d90126519458e4883c26e4950990e4219f94872e760290a93295ed7308db94e2d206e111b3509ae1ec9cd3a46e8908ca31a92e30a348d931ea943b3b26faf294b31b85152e90ce622ad28aa4cee0d0553e9c84d6d43e9dde5382bcfdaff5d7a3adaf9c6a0c1a4eee4d2d03d5500b84cfc65eada84f799973d7025d3ad97b48d212868276476c03f784daa2d8612f0fdd757fc7d48ae8cc116bd432b51e1bdbdb74ab6ea19dd79bcb5d34b2e1cff2af56f095bff32c737dc2eae56adad7b7b852f46c12d2b1ae637840f0f28187518db95a2a294fd330677d9772f71e4ae47679b3c6f8ac72e1c2fb8cdb7a0ede46f1b135dd0540e3811b56972ef7402e1be579a76b927e54fe371fe9969fc35a47c474b1aaa8784704c4b84417a1d3ceff00a86b49d8ad006b598c0036f65197633beea3f8bc7fa785defc188dd0e4461642a7c271479718f2be96bbbc987000ff000a89b44d9d87b9183fd9636ed33abc7fa7cc17ce9a65bf88b1859ba899b030f9385f4af5174647712ed308dff0b0573f0cdb1b9d9876f85386771bb8f2f67af8c9e23c34de1dded21a5bbab58246c8c0707255e757f45be91baa9a98e5a72480b3d057bfb629fe9887b76270babd5e6cb3acfabc58e57563acadc2976c71120505ce7bf9185616a735b20c8caf3f7e5f93a98e130f4bf3e660cfb26b5a1025d4ec630135cff3602f3f1f3658f865cbc38e7e51aaa8592bb240549708990bf461698375851e6b7b1e753802576b87766eb85cb3596a31b5108c13a555cbb1c2f40aba181b4ae3a0670b05281f5520f4caded4e0634e129393948e1b1c21bc285ca84242815091088d95091086ca8421121084201084201084206bfec77c15114b7fd8ef82a22cb91a71852d9f637e0288a5b3ec6fc051c7ece4390842d99842108042108042108042108042119402119465008465194033f9cdf95a1a7dd83e16799fce6fcad04070c1f0a7167c8e8f385cdd1f712bce57466c32a59e2aab8529634e02ed688cb199214e9a313353216089b845edf1a74ce4955350e9192bb19569183ab298216bde4b9158a56d45439ae18385c592ba19357aad03852b21771a9504b874a71c235c6a75155ba59372ad7d152518c4a30aec7d83dd19e4108422908e3805544d5243dc32ad88c82a82a4113b956b4c66dcc1d4e252bb948d094fba86a44210a503d12342724c6022d29c9d4cdd52805346e174a3389c6542b95f0b7340d70692147aea66c2dd95a1396371eca0dc232f6eca58cbe54c06a4c7b482ba39ae88e484d126b70ca96f0a0e9010637bfed05751017b9b85776eb61716e5aa15b96bd284d04fa3560e1200e03041d97a2c9651f419d1e8b217182381ee18194d2f31cacf4a88ce5d82b9cec1dc4e7b8309213591be77642f376bfd75e9e0e2ca67b72918efe952619aa238fcb94d30cad70f29215d5be0668f3b57074eae947f5b585f8c39749e6aa7c3820ad0fd2c25de5685de8ed9f5556d88b362ba7d088e4ce63a637b3396b4e93bfe17b3f83b0bda439e0fa2afa6e8d8ea246c6d6657a7f44f491b6460e8c6cba995f0afd6c7f6f40b5cdac019568fd8aaab753ba37f0ad5ff00705c3ed5f2ae3cf87ec884142f22d39b1be8ea6ffe6d8b4cfc7971ecb3b49a04c0b95e09daec00516defd1d242d946084c148c6f002ec06c9b928b4b6398a389dcb42a4ba5be07c982061687390a8ae61c645311709978aa9abe91b6d6427b8c69d5f858bbaf859d3b471cd53ae30fc138d97a03daf30bb04f0bc9fae6e1",
            "2d3b2a1a2570c83eaba3d2f6ae3c731f4f27ea5a5a3a6ab923a7702013c2acb3b40ab1a8f95427b9f3d5caf73c9dfd5768e4ed9cb4eea3bdf72fbdb4f51510c670d2173639b26e16664a899f26493857569739e37dd783f28a9e320ec83238bf49e1746e3384c9367ecbbfc1f6c7cf73fdf5cae0dff96701ecbcf2785df5521c7aaf44a81aa2703ecb215700124871eeb6aae374a667aa4e0a407cee1f9460a85c1423085204210804210815084224210840210840210840d7fd8ef82a2296ff00b1df0544597234e30a5b3ec6fc05114b67d8df80a38fd9c8721085b33084210084210084210084210214ad1a92820ec961617bf010308c206ea654d218981c42840e502a44ec230022047fce6fcad0c03318c7b2cfb1e3bad0b414dfca0a715332e374e71c0483ee4394b3f456bb484d1973f0ba3402d51a4a96c0e3944c74a8aa653b704ee880f72273ff000a8ebe67cf2020faab8a1065a4d00ef84dad71d4da9a774bde779b6ca6e9f2e7d54c9a85edd4e2a0ee0e142f2ed2ad6733e0abb2152db0626e15d6ea6299fb372819297501ca3b80233850363f0a82acfefb95eebe7e150d5106672ad698fb7109dfd29b8480150d4a84214a014a77082914073760ba52ef382b8fa2ed47fce0859e17e41d0d416870c14e6b496b4a43fccca98c7d2aab831a7054334c5e5ba072558dd29dd39f204ea2688cb18e1ba95e65e3c255bed52795ee1b2d350471c78c8190a65aedbdca3d7a7d146744593968db09af28c2eeb40faea416f730819c2f2bbdd34d3d6c8e8f3a73b2d85d35454e4e780b2b4b72654543a338247295dee1e39f18a0fa0a873b04156d6fa514ed1ac6559bdd1b770c090697fa2f376bfd75acc757c104703ffa774d2c0d04351b35d809c7ca092b83b5ed2521c4e0381dcad5db238db2b1c1be658c8aef0c1521aec672b4d437c86495800192ba7d072fbd9d8f44e9c8c1a96bdc015e9d6e91a180068e179974987cf235e01217a85bf4e86b7460ae8e7e9cf9c95714ec686e53dfce5318c735a0f097eef55c3ecfb53e74a0828cee98e61f429c1b8dcaf3786bc5c9aa1ec764381c614ca292474837d9433970d8a91493884e4a787578fb38c9e57ec3e519484a8b1dc1af1b290c943fd123d18f36397a746eea8aeba84de53b655ee3cbb2a2b834f78e4a34f683515eca2a691d211c2f9f3c44ea78a5aa9dad78e4ecbda3aa1aefa39bcdfd2be51eb07ba3bb54eb9b6c9d895d2e8fb4652b8525c2191ef6fa9524c643752cadbe611ce5e5d91957c2eec94860213bf7fb264496b867756b6eac645b12144a5a075633c8b954514b4eec6e0ae7442fdb5f16bce512dc212f18216600941cea2bb441cd7891cec80be8783ed8f9de7fbeb4ef1dd81ce1ecb27703a1ef1eeae85c40a6201f4599adab1248fdfd56b55c5558c3dc7f29c3cc51a812575a7a774cef2a8695c48c245d6a60740ef3260707350842309100fba70c206a139c364cf55268e42108908421008421008421035ff63be0a88a5bfec77c151165c8d38c296cfb1bf014452d9f637e028e3f6721c84216ccc21084021084021084021082810377ca914471305c3274aef44dcbf7508ab9ae689a101a3d153494a6104e15e44d1a46532a69db2b70022bb67f51499ca99514ed84150c8df645a52b2326669f65a2a6fe5059f8cb84ad0b414e34c632ad14cefa2ff521c93500edd29df852a53d8ddb2aa6eac2e7ecad584f0aaae8f31c9bf0861bdab9afd2e00abda1cc71eac72a0d2d10a968700ace11a1ba0fa22f95d92797540fd96789cca7e5694c6d746e07955cdb702f248425d23d0ca1b300af1c72d07dd41a7b731b36a2a58ce71e8115a61692539b1e794aee36506a2b0c471ea8ac588634076e3859cab189dd852c5c1c7392abe4797ca49e152b5c206b938b8118469184c0d20a2e542308c29414a4c6c9522247a2eb45fce0b97a2ed47fce0a117d2fdd239ac6b5a3290b8b76212ba4d0d6edba578320ca963ecdef4710cbbd575a3a464f3b651c2b2b374f32e85ad7add5bfa2a959186b0824298f4e1c172f4e768318b796fb059fab38ad763dd6ee2e9dfa7a5769c630b11776b692a9d923",
            "20a95f1e9e52abef21f2d3c81a3d179d5a488eed282edf2b6b5d757973a368ce46150476764750ea91f738e4a3b5863f1c22c1c43c6c95ba5a37d9358dd2135e0b86cbcbdbfb2a7442dcbf217473c3e32c4d8db8091a30edd7cfd34aa9ad2e92a43c2b7b75298aa59bee0a702350c246c8f8aa048df45d4ff1ef176f87e5e9ea5d27d41f44591968caf51b4dd249da1fa365f3a5baed2b6a1ae1c85baa6ebbaca2a60d6e385d5b371e09d3c9ee74f34b5634b5abb9a79221e61baf2de92f102bea1fbe168eafac2add20c90b93cbc173a5e964d708de7d11a1e4e30a9286f9553c3af6c2aeadeaaa8867d0d232b2fe1d44e9e4d7b69dede426be17b7d16327eb4ac8cb4397683ab2a65232364fe1d5ff008b946be173a33ba98cb9b61e550dbee5f52d193b952a485ef3927655bd5b8bd1c3c394ad2d34e6adb96854b740f65460ec13a8ee2ea21a415caa2792b26d6ec61531e2bbf4e9cf0acbada9f5d47281ea17cf3d4fe145457dca79b2719257d137cbb7e9d46fd18c80bc33a97c41aca7a9958c6724af5f07f4be4b76f2ab8f459b5bcc449ca8f4d6714eecb8abcafbe497190be6182541ee17ee41c2f2f7393e592769b477134230d194daab89a939230a297c406d9ca73341e579e2b48e3a9a9a41ed9195d073f848e23380be8783ed8f9de7fbeb949a9b01dd50bc974af5a1abda03ecb399ccaec7bad2d461f9206f2acecef0d94072ad2ec6c558dba220ea3c2272be12ee74c2a1d86a89fa4ba366ac6cac1d92e05bbaefacba3d2e08a4acd4f1963b185cc1215c55d1ea3a80d9574cc6b4e3d51a4ae39463d5184e180112442328ca9021194650084651940210840d7fd8ef82a2296ffb1df0544597234e30a5b3ec6fc05114b67d8df80a38fd9c8721085b3308421008421008421008284204ca9345fcc0a3614aa11fb8a11576dd9886bf00a763c813447a9599571969db39e17192d8d60c80a6069614ecea1829067e5618aa5a31eaaf2076a637e173928d923b51c642e8d1a06c85bb2bd8329edd206e980979516ba4744dd91122635ed6bb9557782243b2e2dac769392a2c93194eea1ac8b7b548228b7534e1c721679950e8c0015cd1c8648c12a633ca79dbba32842954650d76508637052a001baa6ba6d2abc00054b751fbaaad70f6820e425c241c254681084201084200a6a714d2a6261470bad1ff00382e4385d68ff9e14a2fa680b410d3f85cea25735a3405d4bb0c6b40c95368691b238771bb22dc7c1735d744caf71f334ad78b8cb04843765456330d2bf0000ae83a298b9dc23b3c1c7f0c7494ebdd43695f977a15e657cae9ea6e246adb2b4774bb4701745aff001cac6dce4cc8656b9235d11edc3f25c3282edbee0b3959719ccb86b937eb6ab4f0552fb1a50e1a4f9825846b0770b34cabaa2d3b15616e92a64e4158f6e6f016ae6969e5732707749dba927ec251db987dd195c1ca0e9918d93007976e76484c83fa0a61efc874b5842e9f43d0eac7be29720a993dca6ed6ce3b285f4f3347981ca577919872ea626a343d31d473d3bb01c55ed675655170c38ac9d86064872ae1ec677002dd928d9d9bac2b05211a8f0a96afa8eb5f5c5d9772ba5b65a78d9a485da4a585efd61a3751a8693a86eb2d596f77395a38660c88382cc52f6e29000375a5a72dec8d41350d2e2c7760c932e3c2d17fc44c27482160b5963b318ff09e6691e3d4155cb0c72f636d51778f230e095b7ac4640705866c9203fb929ff2bac956d6c47f7f7c7ba8bc38c82c6f572fab6c8c320e178bdf631256cd939c12ae2fb76aa8eb1c2394e33eea92a9ce918e711973bd573fbd84d7819f869e39aab49c60157ceb5d28880c8540f8e5a77ba54e65c66987dc765c9c85d4766a4232304aabba52b20fe58e14bb55439d26247a6ddbee38190a70f34b7c32d535b2c52060cab1a6cc90071e523e87bcf0ed1fec9cc77ee0a660f3138c2fa2e09fd63e7bb1f71d54dff95dcace39ba5ee202debfa52ba4a212089ce18cf0a8a4a07d1b8b67a723e42d329e59e374a6a184544a3537d55aba2ed3835bc2e94ec8b24b5b85d1e32ecabc2e5b2c63012b8e02409afdc28ace9756607fc2cf",
            "4ffcd3f2b4006207fc2cfd47f34fca86b818872104a86844210a501084201084200254812a10d7fd8ef82a2296ff00b1df054458f27b6bc614b67d8df80a200a5b3ec6fc04e3f666721085b3308424280ca3284220651940420328ca11840b9c05d2965c48173c6c91a34ee3950344c90680baebf2e42a5b6d4492ca1aee15d48d0dc00accf29aa68717048e0528d92e51572f383f85d037504b9c04d6bfd9285c88b72a05c2a18f0a5cd1be569d3caa3a88e66c843f845f18e7a86e86809d1d33e670d3b84e969dd0bb042869e1c9fb615ed001d90a8a46ee30afe88014cdc72a62b97a764210a580094bb482818c20341e52a63909bcdcaaab8bf32a91707ba1ce85585ee977772aad7183394238422e1084201084200a4dbd52faa6fd2d4553c360049fc298df878be74b9185d688fee85da5b056d3d3f72461e33ba876e73fea74b94bd17a95aea0119918242af0887bad6c642ce39ba236bb3e652ed351aaa4194a3d3c3c3f08be74eda3dcb805d24bb0fa57963f7c7bacef50d731ae01aed941a7ac2e8835aec828dfca96f576a992e25a1c719579436f9ebe981209c84b1da69a67f7a5c646eada9afd436c8fb796ec912aa6f48c99d6e6a1f6e8e31a0b0642b2a9eb5a6d04330a80f50c524ce24ec5459e47734b131a7ca159daa28b48c302a817181e79e558dbae7490b802e1859f34de236f68a0a49983b8d682ac4f4fd04a7fa42c34bd530407f69f81f291dd70c89b9126ff002b9f7a9bf2373ff08d13b71a536b7a560a7a432c6c05c16269bc4568900321c7cad1d2788943db1f50f1a3d7257ab8387e02abf4e9a698b045ebeca2ddfa72aa38f508c8fecb5f6aeb6e997d407b9ec57175ea9e9fad83440e8c95eb9968797daa96a691d82c2ae01d472ee5692823a1aa271a7755779a0114ff00b046173f9bb530a2b3ea5d1cad00ad2d1bb5401c55132cd55316bc0f55a486d157052b4969c6163fce81f4ed63ea1ae71c60ad1495103600038656729ed755335cf603b7b2e12b2b5afd07527f3a0d4d2d5538075b825755d339fb3800b3eea1a9fa70f248507bfd9c87bf74fe70bbbb48d2cfd993fc2c757d755c4e23b8ec7cab98ae14e5a75bb2567eeb52d926c346ca7f9bb0cde66f724392b93a789ee0cd97560d50b81db6d951474f52dad738e746579b9f9fe5059d7d3b1d0e1801cacfbe9dd4e4edb2d4401a5989142b8d289011185e4be450092463c39a485714b2c52463ba465563e0961c87b5319ab5632404c6eaa2cdc6923344632323292cfd382aae6ca960d58770b3351dc8e402371dcaf4af0ee9e673e32f6e4657538fb72473b93a972bb7aef4fd9e0759da25a704e9f50bcf7c42b0431b647c5001f017b3dbe102d8cc0c6cb21d656896aa99fa599d8ad70ed4cb263c9d4b8e3b7cc8e6ba199ed2dc61381ceeafba86c93d1c923dccc72b3f164839e57bf1bb8f05f17476518ca43b27b37638fae12ab03db881c56727fe69f956a6adcd0e6bf85593b9a5e4846d8b92429490901caaae109764d5282a1084021084004a9025421aff00b1df05452a53fec77c151563c8d700a533ec6fc05154a67d8df809c7eccce4210b6661214a910184612a11042149a6a7ee82a33b856f680dc6ea0fc2ae688c6f4d272adaba975925a155399a1f83ca1293d120f54e70c2444a55ace665792f21515aff009dfdd5ecbf7052cf2f66a10852c81dc6138b591405dea9a785c6a038c04652a61282bdb254161e172be463773555d339d4f5249f7526beb3bad50d75a3ed0ec3802bbdc60738e4051ad672f055c4d87819088caeaa8c513dfc85694b13a26005741a5a384e126a18c2952e442774ec6530f2ba0e14aae65d876174edb8373eea3cced2739515d7639d00f0a2ad2197104672ab4719522aeb0cbcae0df334a36c6101ca5498c14aa121084201084201df69575d22f67d537b8073eaa94f0ad6c00198683be54c7b7a9edbbea29217dbb4c6d6e74fa2f33a7a69995c5c5a7195e90da5134235b86e143aeb4c30c45e1a32a5d38a361ee690532aa5148fcf09d1ff003f006c143bf64b739c2232565e2e0e9c8c15616a25f003ec15641426a5a30752bca1a5ec",
            "425bf844e3ad127b8b6269613baa89a91f58fd409c152a6a27545572b474364c53077ae1064c5a36f54c367713b656c99682e7612fe918710831a2cd51cb4941b25711e52e5b3fd35cd5616f8238dc3b8d184d6c79fc7d35709064eb5d9bd255affb8b97a6cb2d3c63c8c1fe146358ccecc1fe126bd0f3c7f48d442351d4a2bed13bff0068b9d85e95339b3371b2aa9ad85eecb7656a307556396862d6d7bf3f2a3dbee35514ba5cf7edf95beaab1ba78f4170554de8e2c7eacaafc761d45d64fa12d6979536a3af064389caa8aae8c9a47873725479fa74c5e4785c1ed63fd86dadfe26d3471b03f1cadc52f5f51d75131a0b7242f9f2ae89b03b48e42954f76928d8d6b5c76fcaf2687d2d60ea1a1634b1ee6f994ba9a482ae6d5111b9caf9da9bab678e46bc48703d32afe9bc5d96808d59384d0f69aeb4cff4a5ac3e8b0b5bd2f74a89c91ab1955f4be3b44583ba36fcab7a2f19edf58343437526854d4f4ed6d191ac9482dd81970c95772753c17593770192ae28ac715743a9af1baa8c154b843b009039a59c0cad55cba31e5e4b770375486d0e89e633e854fb156fca74240779b753a6a22c1c284e8c34e32a444ba41f503c81534f0ba0e42d3c41a39dd535e5cd0fd872a2c4e955a8995bf2bd9fc37883e067195e2ce7697b5d8f55eb3e1c5cb446c0a0974f7aa61a2dec03d9479e9bbf116b9b9ca8941751240c613e8aca7ab115387695e8eb7dec7b17783c37c57b71a48a473001b15e41464be3793c82bd8fc5db9b65a7900c70578edb8ea81e7f2be8309e1f3bc9ece295a7ca50e48dfb4ab55715357b8879c2858c952ebcfee1dd728230f76328f463e9cc8c05d1ba4b78dd4dfd38bdb94b1db08df2aa5aacc104e528dd4caaa7edf230a10233ca949c4244a4ec91101084200254812a10d7fd8ef82a2a96ff00b1df0a22c791af185299f637e028aa533ec6fc04e3f667e8e4210b66612254888a5465090a01db0cab5b630b9b90aa9df6ab8b2eedc7e1217d25870396150eaad593de054f73035c4a573b5c7a534cae559b9c963b184cdf19572fb731fb90b954d0b1919c29d2d3346b48065ce7d55eca06c41caa1b7b744a79c2bbd4d7018e53465ec2563439046c98496b4952ccf1827194da80d109395592d616b8e0ae4faf73da465455a445a87ea94e174a78bea1c185713e67654bb7ff0037650d6fa59414229707dd4a2ec8c259338194c2a585bb05a9700047a214e91a334ee9e1d8184dca54a39c9077b6cf2abaae80521d47d55ab5d872897724b142f8a9a401c9ad7e918434e4a768df2a1b4fd0e774253f848804210804210803bb08567d30dd358184e7255625a3ae7535630b7dd5b17bba7edebf51687436f152c77a65642e37b934be22360b47497a9aa6ce18771a5632e8f697bf38c95e0ed736587dae92ae3bde87b9d8e10e9cde876f8556f006bfc953ac274cbb7baf061dde5b5122ca868ff4e01a4e55cd1518a8ddc700a892f99c32aeecec648dc38e02eb75f3b9cdd4ea388b0c2d7f703f70ac21776d9a0709d246d6bf0d7653bb7a4657a4dc7193c8721384ad2d1beebb44d63dc03bd55955da29e2a512823242236a8ee0293208d9210cee690ba3e3d2d51e969037486ee535a1af7e07aa6b181e709da4b1f96fa249f942d61b136483bc5d8db2abe20d7d67d3a911dd1ed021c9c152e9adc35fd4faf29437f46025fb93a4b4b7dd5833cc729cf092dd08705044ce46543ade9c86ade5e0e15b06ec9cd8c80bc9cdc185f3479d5d7a300a973c12557c9d14e78d4015e973d335eedc2ed0d3441982d5c9e6c2637c0f28ff0082e411b9e41185515365943cc622cff65edcea4a7742e05a171b674f505554f9da3958c968f13774dcf3b34682dfeca27e9b3d8e4d6e270be89b874a5040dcb1a162ba8fa4e2ad6e18c5165d8f3ea5ea19d982c795b4e9df10ab29b4b493855707439a7049615c67b6ba81a486118fc27c68f52a0ebcfa803b98cbb6dd4f9a3a6701501c32fdf195e0751d4553492e1a1db7e14da3f10ab5ef646f2ed213e347afd6d3b5ce0c6ff52a7b85a7e98ea2efcaabb7759c733a33238647bab6aebcc170600d70ca8fff0045",
            "6b41c903754d7c062702795791e23dc10a8efc5d2bc612155ff78070bd0fc3fdded1f95e798735816aba36e12d3ccdc7ba11eef4c1d046c78f6565517874b4ed84b39db2b2b6ebac9342c0ef6578d697b18ec2dfaff731ec7d8c775e749b6b6df25438fa12bc41f07d148f89bc02be88eb49a5659ded19fb4af9faaf79a4279caeff001fa7cfe7ed11e50d1e5291c901d95d5417db8543c92ec274569113b50394caa9df14a0354ea6935346534b7ca9cd3a1b8433eeca24e52b30028d1b72aba5157e5e32a9eb6dff004479cabdc90e1855b7725c77555b0caaac3750ca5c26e4809cde11a508c212952881090254491ff63be14452dff63be14558f234c08a5b3ec6fc28a0294cfb1bf09c7eccca84216ccc242952140142108821dc615b5ae61100aa93d9316215a332078242e6d710b85bde646eea539a070a58d384adc608492864830426300d5b85d1e40e14ab2b8c54b1b0e404ff002838086c9ee1388046422db2e7648e6658e4c2ec27b7263722b14154312b82e01a756177aa244e7288407ccd0a2b69e8d9612c8f56174b59cc8ac6b6987d28c738506db048d9776901427f0bc937013129e06522b31b004a5204139454dceeba0e173f55d320377d92ad1c5eed2e512e328923c2eb5134601c3865543e673de47a2aaf8c7203053dc7ca908c94b8c850d4d69ca5401842902108402108401e146d04cc08f7524ae521c0c8e54caf6f53db534f709a1b7696bfd16725af9669dc1e7212c75123e2d3a8a88c8cb642e71ce572fb98e597a7525f07cc32d2429961fe6ff7515dbb0a99657b22933210d1f95cfe3e2ca5f488b9ab97b646f85de0b9111811bb0555dda4ef0fd876af8552ca99d9e539690bb7d696629b3c357fa9cf1e5ce7aed4b7c748fd2f7ecb14eaf973a5d2256c920f33642bd2ac8f518668dcd0eee0f75d9f761333b464180bcb595f5a3204c71f2bb505c2a4ca43e63fe55a21ea56f8609a4dc8ca9172a78e36f930b1f65ae76b199ffdd5f4b561c46a901feea9c97517d191b1c0929da5f9e0a0cf1370758dd5d510a5308738824aa4e5c75ed1148ca595f3b48070169a16b994c0727d93e082170cb40cfa2ed450c9f5a039a4c6b4c3297f223c424d3f694e73643fd2569bb30076cc184a62a7ff004053466007e7ed282c9b3c1c2d308202efb0225a584f00049afc8ce3607b86484c70d070569852c7db200dd51d7d13fb87485965c38dfc08990e1a47aa916da731540760a652d1ca2a5ba9874ad11a7899a4b70938309f8054304ac1b2e5fa6c0d607c8d054bd4d2cf85c4ca5ced046c97830fd060a0a195a418c28d51d316ba861d71b559e86b46c395ce50741518f161fa18bace87b2191c5d1b37592aff000fa9d923e485a037d16f6e11bdd2fdf8dd47933f4ee048e15b3e2c35e87905c2cf3d19718c9f2ae76bafac649a5ce71016dae1036464b9192b3d4f47a6527b7fecb95cfc7af50747de256000b884dfa9754ee4e556dea19b5791a40496a798c0ef3f1f2bc17c5f22c5fab38579d2ce2cae6079f2e5513ded91d98dc1cba4556fa57b5ed760e557647bc5b9ec73630c77a2d58263a78cfe1795f43dc8d5363ee4abd32e12b5944c2d901385e8ebfdcc7b1f62a3abe432daa4dffa4af01ad716d4480fbaf68be553e4b7ca33e8578cdc199a9933ce577f8fd3e7f2fb90dc95a36ca478c20125a55d572fa613bb27d13c33b5b26c4f73090ba1f3203394ddc3928e574681fdd28697359caaab9c81e4e14ab8bdd1054ee94bddbaa34c61ac6eae529d8e12e749d9349c94681294895490812a10811ff63be145529ff63be14558f234c3d05299f637e1455299f637e138fd99950842d9984852a0a044a1204a880135c32e09c91db9d94257d6b8c3a3521ccc3d5650d676806e54f64dace5598d3ddca08d82576fba5f40a5491ce79031bec929e61333485c2e27119c281435bd93927d517f8ae0b0b4e0ae53573636e83b27d2d4b6a1c4aa9bae44db7ba18e3e5cea8b647642e54ce2da80137276257480833b5456b26a2f40d6c19dd2cb3c74d18f28088b6605cabe13347b233d9d0ce27190ba83950a863740d21ca6332a514e23d5340c27",
            "fa247708ccd0b9d664d33b0705746ae759ff00cb151568a0707071cb89421dc94286e4294244140a840422421084021084087ed5cb195dbd17356c6bd9d435be54ad6991e90ae943e69c0299495d39e9d2680c4c0e3b05ca2a67dc7c94ee3abf0b43536f1574e2260dca93d39d393daa71248dc8273baa7c3146d5b66b555d0cbff30c2e07dd5cbba6db5b97b5806568ea5d1ced01ac0084ca794c23015e786797349ed81b9747cfdccb01d9453d3f590337695e90e98b9d9734249cb248c8d015a6938f631be23cc8514cc3e66909cdb7c8fc9048256bea6d4f95c4b589b05a1fbf9552df2d279f4cddb6867866c991caea5749803590a58b73daed9aa3574523063072bcfdbcb58a7569053d5ccd6e871202bda113358d6b9e72142b5dce2a688324032add86395bdc6630570f2ccf4d3591a6700e760b4914d4e30cc0d4b0f66ba7d3c9daf75774ee91f5cd793b2e8f4aee0d1ec52e8ca460d5ba52fd270ba57c033dbd9768695f38cb775c9c011bab1b5d5329fee56be840730c3261fb14e9291f28d61991ef84eba4827a86b9bc6568684446da41033853065daf6e7b218357c2edfa6cc37c1dd23181974fc656a5cd05adc3470a28cac9493403539a70b8b4994ecd5a2bd6a6d2fda167e07e904faa03259ca57b8ba3202e45ee91c76526201b1e4a819aaca3a89263a41c2e1516dac6c2e3db2af66bad3d3bcea0321439bad689cc74586e429d8c4cf04cc2fd6c5c29991971d6c015d55dce0a90f2c03754efdf25aa2fc6fb15f7a81ae6e228f3f0b2f5b68ab9c618d2d5bda4a3927c9d3944d1f6890e60d971fb1c3bced830f6da096886994927f2a73adf34e416b4e175bbcbdb9c103032ac6dd75819080e03385e0cb1d1163d2d1cd49335ba885ea0d32494ccd4f2410bc9ad576649716b5a792bd729c034113f3e8b4eb7dcc79fec56dee331503cfb85e3f747e2a1eefcaf63be3c3edef07d02f1cb9b43aa646fe57d0f1fa7cfe5f722b5bdd195cf5f6dda5739ea8526c4a7c389c6b0aea9e46467091a9ce3b6135a8163fb9739dddb76acae8dfb970b86d1944c43aeae6ce31b6cab700b92b7049dd2ec152b6f4084d4b9050804210a5210842047fd8ef85154a7fd8ef851565c8d38c294cfb1bf0a2a94cfb1bf0a38fd99950842d9984213998c6e81a82709a4eea450c4269434842f84773f0338536829c5483b630a5c96f607e3030bbc508807936452e514f38304da4056f44c2e8b5148fa56ca75380cae8d6963748e14e94b96dd1db040764048371ba701b852aed16e23312a40ddc857974da2dbd951b72412a1b61e93696a3b03395c6ae7ef3b2a382e295b924e426d3ad00d73b7f40ba5291f501235f805bee929d85b383f944efc3443760c7b27b9a5acc94c6b8080639430b9eddd34c0c0325746a46b709c14968270901ca529bf08a00b9d67ff002c574c692b8d63c7670a36be2a27725052923594d3ca86c020a108142121422d2152652a115d8424295124e57393ca174f45cf412edd4c7b7a7ec8c3a814fa19036a7185cdce2d786b42baa1b6094b1da7729a7522e6dd2832b3cbbad2cb3bb40040e140a5b6b29e36388dd4b779f953a573f46ef8c840c8dd28d86128e51c5ec6577a206b9e9ae6909e5f8e12672522783833b7658c909cd99adcec10de1104625974e1572baf35d7e39a87d1c42a9f80144be5b8c20b8372b5d66b1ba695bdb6f27d96c29bc3c75c640c9599047a85cfedf6b1cb1d45f6f9fa4881f3118215df4e39d5b98c1d9ab5dd77e1d4d6895e628bca3d82c05156bed1582220b49382b8f95f05f2d1bfb74f520fa82ad68ef1ff0034c1e8b97e9cdaca3150d39246556d24ad8ab3b4e1be70ba9fe3eec7a1525c1b2600f55674f4df507202cc5b1a758216c2c728ee00e5d5cff438d5523a2db85575559f4a7cc569afccc3da59c2c45fc177092ee0b6a69bea5a1e3857b4d706474c5879c2cf58a273a8c0f5531c430e9f553b0f8dc1f50e989e0ab26ddf20007854af81e3cc090d50ebeeb4f434c4eb1a87e50682b2e26a23d04e556e594fe691c037f2b2c3ae600d2c182e5c995d57d42e31c3900a8f434935da99a7c85a4aed0d58aa",
            "8f0d55141d13570fee4ef241f72ac83e9ed634b9c3214ee6b62154d91f53238efbaa37f4448c7c929ce0ad4feb70f2d721f7989edc1906ea71fec3072db3e903860a863618cad65e4c12444b1c32b23f4ae74a70e5371905950d70a41be085ceb6b21972e006ea2ba3edece2b9be16bb7cacb938e542155dacd702e6f0153be9c53c9db2775aa6131c4434acd5c2371a92ecae1736b7a4c3286414158d95de857af583a8a3afa58a1077c05e3d1c425900715b5e9bd34a5841e3f2b3e1bf1c99f2e3f2c751b9ea2a4732dee783b10bc4af359f4d53267dd7ad5eeee64a4edeac8c2f36b9d945c247380ce57567770c669c9cba59ed92ada9fa9f305da9abfb2c0ccf2ac2a2c229810765493c1da9c6fb656bc5dac73be19e7d7b8cd55ec4ed6cd49cd5ca90e620bb70bd4f350d1e651ee674c4548e0a6cd1899b8288975543430fd43880a7bad074e577828842496eca6441ce3825574d2e72fa5432d6e24fe142959db796fb2d2346991c33e8b3d587352f50b63e5c9052252a56204a902544423fec77c28aa53fec77c28ab2e46bc614a67d8df85154a67d8df851c7eccca84216ccc2471212a03752068e32a6db1c04c32a11e70ba44f3138144568c96b9dca5d95750ce657a9e762a59585c2364dca32a62a0f29dec9a9deca11516ebfcafeca8e3769ce55e5d3f95fd951069782a1be1e965454ec9d497db1ad692b95ad858d0acb3a810a55cab3f347db71d91480be404856aea212c9bf08aaa114f1ea8d223e5e12181a231b8435fa785514b512ba6d0738572c60c0254a2f826729421e31c2445294a01c7284d93ed29513d9b3c8d0dce55554d417640296a6a88716e5432492a8db1869dca138e0048a5a110840440425422664108481105284232803c2e2c91ce983485d97304778298f7752f95d505b6398b5ce0b5315b9b4f1b080a82d9901ab599ff978f3eca5d39e8ae7173403e81225272024447b8101184052f072f0ef2d8290252847ab8b0d43dbf6a7da5e5d59a08e4a6377202d3d8edd48f96278c176d95873fdad63d07a36d6d1db91eddb6f45e9d6f8e26c8d735a36594b1c70474d1b5846765acb6e1840715f3f9ddd117aa6c74b74a6935301763d97cb3e24f4cbedd712f8e320077b2faf9cc8e6796b8ecbcabc60b1d1328df2868d582abadcd25e59d10cfaba31148ef45cef567868eb3bcd70ce55158ef1251d5ba38ce002a65d6e52d4d4b4389dcae9f47588d674f6994025686191b4efcb48cacb59276414bab3be149a2ae927ab2ddf4aeadd5a349555af9c6eaa2a293ea5d82ac25c31a3e137234e472a663a1ca1268220d685dcb1a69df50f38d232884c6f04ca718f7588eb2eaf145aa92070c3b6d956921d72ebb8e38a6858e05cdc81bac10bc5c6f570308d5a1ce51a9edb5957716c98718e4392bd2adf67b6dae91b3bf47700ca981b60f0e854c6d9a67636ceeb47053d0f4d725b90bceeefe28545b6a4c14f9d20e3654d5bd535f7a66a6b9d92a6cf08ade75478a4da606284ff008586a9eafacb938c8d2ec28d4bd35557376b9b255b41d3e2880696eca31f5e52ab6f53d6c474904a71ea1ab76e09566fb6c07512df4d950cd4f2b27700d3a52dd7a130dfea9c30e24a67eb73337c1ca8209d5820a7bd85bb90ab32f3e44e65d249c65d90b8bef0f649a5476bc69d933b41e73eaaf965343474557dd8b25525c5d27d4ec0e1362ac34ee0dcab86d3327a3ef6375f3bcff70a36ea0ed4acad77391b2867b2af903f51f29c2eb6c735f29e32bcd72f23575354f969f6dcaebd3f4e6a242d785c6858247063b82af0c94d6884ca0b41c29996c98b29d5b4eca79dcd070b09738f4bdaecfaab5eb1bfc957564c47232b392cd34da352f774fdbc5da9e1a0a2fe485dd70a03fb21775db71f28118425052b2d1a5ce09ad95cd7642ea4848d009d8285a456d5573a390fe556c8ed6f2ef752ae786caa1286d3d1508422404a90254211ff0063be145529ff0063be145597235e30a533ec6fc28aa533ec6fc28e3f66654210b6661398f0cce535214072eca7bc6b1b26009c36412adf3b695f97eeae18f6cbe61eab3e48c6eacadcf739bf84679458f6f6ca66",
            "c4e13c6404c6fbab467463746770903fcfc27078cf0a108b7276a8b0a8daec1202bfb837b8cc35aa91d4ee89c4b8286d87a5850cba4004a9e24540272c3b156d6d719c8ca95339531a5c5a71ca23ce82d9375da5676b65c7953157365346c9356027bf24f952a1019c84210880104658ef8425ff00edbfe12a633952099cfca6fae13e7fe73933fa951bfe0d76729c3848fe5285292140414be88808488ca682a4e10128521094a065290085c9e4b4e0235e2c7e473dc18709194b23a5120052c74924ce0ee5686dd1c6d8f123123a3c1c3f116c7921ade085ab6b87d3b757a0597680da81a0606568fbd1fd16350ce14bd4eaca889fb070184a668ffd6165dce9bbaed0f38485f51feb2898d4f7e3ff0050477a3ff50596d751feb28334f13812e24227e12b525e0f09cc6176ea2db03a78c12a5bb2c1b2435a2ec36f553fa6ea268aacea71d3e8ab58ec939522867eccb9cacbb17faa1ed5d2b5ae9248c17ecb70fa821edd1200bc22d3d432c0f6e97118fcab99baaeb4bc6891dfe57cd65bd91eb5f5f241282e94609591f16aa23fd15cf2ec9702b1bff1556ba6687c8ee7dd72ebabe3abacc1af79381eeadbba1e314b532c7757904e9cad24b99d8d78e564e1aa8995eecb872b5905742f85ad6904e17a38b97e026daeae5cf6c92b5b663131e0bc6e563edef6c730795a0656b2566233872f5e1dbf23553c8c7901a41ca464d1c07f7385516999ec766676af645daa35b8b83b48c2f7f1f34ca1b27505e228e17885e01c2f22bab2a2aee3adfa9cdcaedd497f7fea4608e7f5e32ace827a78e9db24f82e3eeb6ded3b6c3a5996f8ed04d4068940db2b21d415b572d4b990c87b79e014fabad33427e9dfa07e0aa3a5a877d5e25972110e525b5950ecc8d25cac2d94ec8240c0dff656ac9a931b004e14eb4450cf52d1dbcff651b4f85adaa82a248c398cd94a96901769923395bfe99b5446986621fe15b9e9da491f9308ff000b0e5e4f8443c95d6a879312e335a692489c445b85ec5ff0c52c81cd110dbf0b2977b7c146e959da000fc2af0734cbd8f267db601239ddbd82416d86b9ddb8db85a4ae6c2d8e4218154dae40e9ce86e082b3ec737c3d0a3b9f4dcf480e8693f0a98bcd13877b6f95ec34efa7ed38543038e3d42f2af106d93cd505f4b190ccfa05e6fe4db11505f510cce05a42d25ae78dd4bda242f3685f35390c95c5aefcabfa2aec45a44be63f95e0cf2dd4b57526899116601710a868e9e582b8c983a094ca77bfb8d748ed4b412d65241461ce033854b1312057c7106bc38371caa6ea8bc4b554844327a7a2a0b9dc9f525dd993481ec5553ab662c31b9c4a4c744ce557075549310f713bab18ddc02b944cd27513ba7b64065017bba7ede1eddf0d05bc6635208c28f46d73a2042e843976bf0e2dbe4ed6384f6b752e6d67aa787e364a99485a41477990eee4a438eeaa6e723d848dd0c639dc8b657ea0a10e1399aa51b9416e3650d75f826109522002548394a8423fec77c28aa53fec77c28ab2e46b87a0a533ec6fc28aa533ec6fc28e3f66654210b6661214a8281025ce0a4e121281ce3b29b415623182a00f31c27b99a30414458d0c33095a9c546b5375c7b9dd4931bdaedd4c63942379c6105a73c203b0f4d96a43394544b33598c855d71a86cacd2c001456d6c6e1869dd57f70e51be10d0cc3375636caa10b80504bb526b4961c844e536d4c9289c020ae6aae96bb0e0c27956bfd20fba4659cd110842950bc2329320ec970891947ff006dff00082c70dcf0940cc6fc7b28a99ed9b9cfefb9307dc9f51b4eef94c1f72ab70f3e64049272940d94a414a522115084236529d848e3b6c94a43c22f863f2cb4463f098f9003ba30729b2333ca3a7c5c131bb682ca23923c95324c670d0a0589a3b64654f70c3923d935a233f3ca73df291804e1348df286bc8db0a55a231a06fca5d483bf09361ca20ba9238838ca5c646dc24f29d916956d415e206602b18e6ef8caccb33dc0067195a4a06c6211bef8452df2e806e86b34b894993aff0009ce72ae587ca2ff0084ba5a9113c64ab48ee90b5c0b885401bb6e992332362578bf872aad27d7c12bf56a030a",
            "8ba92f31cb4ef89afe07bae14eccea01c72a82aa9deea89448ed8f097a734963e42e757921e795a7a190d331b33de71f2aa64b53a3abd58db2ade5a70fa311af176787e3e868a8aad95516b63bd15a59d923e6201cac8d85e20fd924e16b286b051bb58f45cf9b82eea2b3e808121d25545e6f4d9a22d6bf191ee9d5d23af18909c00161ba82e228ea7b41db70ba3c1c9a46b6a2abb5cb25e0d49792dd5957b3173e18d8d763185ce99f1d445abd5283aa41185d5e2cb6b5c5df57db135dcae82c12b9e24693ba914d6791923643be7757b1c86101ae1c2f4563c997c629a96df344ff003938fcad6f4b86fd5b5b8df654d34f9770afba661cd435ece56763c38f66dcb4f6fe9f840a36e198d96829edef91ba835656c7707c74cd6b88c85b0b45cdfd93a805ccede55d3412c9209c8d3b2cd7585a5dd874c1bf7655f57dd5edabc9c690557f50f50d1cf4063d4dd602f0f0f37c68f0fbdbcd33240e1859fb4dc591cc49c72a475ede3b2f931f6eeb076ebf3249701c794e7e5f90f5b8277558063190a3ddaa29d94ee64b182ec28163be329e9b3c92176308bcb9ce58e36e936787985fadc6a2b0be2186e7d1438acf3b256ca1e7016e2ef69741361adc854f39ed48232142b1cdad11401ce3ba8771ad1345db6bd49af63df010d59ac3c4a41393953b53932d439913a3c92e3ba708c96e70ba06ede6439f86e1a936e7e5cf65716871384ac66990128638876eba3c6ae17bba92cacb9393e4b8a4af6451694f15cd7bb0a9065a3629f4c49906ebb3bf0f2dc1a363839aa3cafed1c95da99a7b609516e01da0a567f1f205d6327191b2855f3b67390a0471e1e4929ef18e0a6dafc64be08d716708ce52b78dd26d945824097291114a84210847fd8ef85154a7fd8ef851565c8d70f4015299f637e1445299f637e028e3f666721085b330827084846500374b8fc2910401c54f8edcd78e420a7c8072975eae55c8b3309c92143ada46c3f69501b057fd30d8e1486de7bbcaab0dcf2801ac446a3470b848cd64a4969db28c03caaa8ebb4c5a41436e4f695656e27555b3b675280f6e9385365b83a56e0950892e76516c6dfc868253b49f65329697ba360a49a0c03b7088daa599152cf95a26bf2d68cfa2a19d9da9357b2934b5fac86e542339b8b8184392420399ab528d555422ce0a953e290c033b951ab2b442ed8a83fa9b89d947a89fbc7750b4c539d762f18cab0a697303893e8b3a1a1bba9d4f5bfb659944fc7cf843aadea0e134f21136f212850b91fc207094f084804210a4220a5c234a209848fd82784c9361ba6eb5e1bfde3935e95f9295801449b70aced4abdb234088eea63b959ba4b83a095accf2b411c9ad81dee8bedd129df64c0e24e13bcc37c220d396a7b19dc1ba607771d84f91c636ec8394f21840006558d05bbea630fc72968a81956c05e42b8860fa46e1a76410596ad2ee38532180c6175129723b9e8a284271b2476794ec6add38918c29f21a776a1adf2a01cec946cec653c481618f46a77b058bbeddcc75da1befbad1d557981ee602b117c735f53dcfcaafce0bc8e76cf1b1c7195d602669445eeb3905cf4b98c0afa9652d0251cae576f2945d525a8325c8e54c7b741d2556dbaec649719dd5a93ac82573a024affa3a5763d961abe2fd4ea8b8f395adbd398d874e7d167e1883497355f0fb8369e98d3374aed181149dcf54ad7979dd20f34819eebbbd7fb458d3de9f2ccc67a0d95c3b3280e55b4f696c659261593ce960016de76c3b1e711246d0c1eeae7a76a7b0e041c1546dd4e1baef0d49a5dc2be9cae2c2fcf6f4eb7dd26d4d3af65a587a8248a303b9e8bc6e0ea8962db0e5d5fd613bb61a973fb7371dc7a7565e649cbb0fdd62ae77199b24997b8aa58faae604e43b7515f79faa7bb3c95c6fa77628fa960fd422901f558fa6b23695ae90fbadd5c0834ef705997132465a4eca72e3c85b59889a30dcfa2d758da210ec158eb337b43ca72afe92b5d1129863922bb5d5c0bdd9c12b197469139785a8a990cc0959aaf6b8ce41e152fb4a86a2eee89ee8d5735ddc90bcabaa8b63242e79032a9980473b99e816fc384cab2e7fb5d3b9a8612346",
            "0ee9d231addda520e32ba7875a69c6cbd91fcec95bb35373929ed5be3c127a5762366a072861edc9908787b47942e61c73b85acc742cd9737318065739ae06469195109184d23214aba2071c94bac8e42976fa4123bccad4da61733908b567c480ec8572db2b1ee7608d9555447da95cc1e8839a108528012a40950847fd8ef85154a7fd8ef851563c8d702294cfb1bf01455299f637e0271fb390e4210b6661214a840e64ce670ba8b8cade32b86e941083bfea751c6eb94b52f979ca1ad73b81b24744ff0040540686388d93741d5bae8d7be3d884c2e2e931840d230e4f046174ec13be365c9ed00ab1bd8d8a71186e535b80101f9382a11a5b5a5f8560e99ba5df0b3d1d4be0fb159d2cf1be325e77214ab66bcabaa9c1d290b935a23390bbd4424bc96ae5d97f24150997c3a36be468c03b2474ddefb8ae2e18294018e54a4a5ac1b24d202690094be88929230980e828c234829525e774a803085082fa24421401084290a126774ac3e600f0ada3a4a5741a8b86a5085484c98173309f39d32e1bc2473b0d532b6e2d7ca38c60b06e949ca78064e02696398770a5dac638ba3fde6bbd8ad2dbe46ba1036d82a02dc84b054cf0ca1adc96a95ac6aa0d0e903765713db9ada4ee63d150dac091cd7bb95a3aa74aea40d6f184433a301cec7a25d5ac6102967648ed8e094f14d2b786a0054cd001a32aeadb3c950c1dc54ce8a718f2ab8b607b18358c209e5a070987629e5cdf45c9e7d907560ca710d5ce273bd53fb6464a9dec346cabebeadd112415398097e1565e8b21272765e6ed6571c3c0ae33f7dee2e3bacd5d9a5f310a45c6b9f19cd39ceea0ba5748017fdc571e762e8329a9c77d84ad641a3b2d68f659aa68a43335c46cb496b6b25a86b1c765872725c849b6537efe4057e5a4602e51d136193f6b752db138105c1571196eaea87d3479c955966acfa8809772ac7ae4b5cd0d3ecb230543e962fdb569ec6aa121d21c20b832a1a3f2b85aa4d74e243f7152852bdf3364c2ef75aff51a7a70e34ad71f64d6f9ca4a7ac632011bc80904b1e72d217a3f29cb1963b35cd6ec99fd792364ba43b7499df0acc71e193c964737d1a135a47ab427b800dca635c0acf931c726a717340fb4263606b497fba0119c27f380b3c7831bf81c2a9c1d4ef1f858fbb4eea7a77399cad6dc98638096efb2c8de07fc8b9deaad7af87e84ce8bae755c85b215ad923d2f761633a15a1d267f2b6d29c38854bd7c644524641610540a8a20f25f8528bb036492543194eed4570fb18c992599b87ed9700565e4697cee2395a7b94d0bc38b5dbacd533bfe78b5dc129d6b7e5a63cf7fa9190caee41c2e8f1a060ad27d1c3da6968e42abb9d3c318cb4eebbd84ba716df2ac6a7b794ce06539a4e32afe4ab5a1863742e7498d940a90c0f3a531955201a780b99f31c929e505d190946c9038818485343ac750e8bed4f3729fd32a383eeba318e78f2844ba36eb50ccf2b83de647179e4a7163987ce130e3d10a10842940095204a8423fec77c288a53fec77c151563c9edaf185299f637e028aa533ec6fc04e3f6721c84216ccc2471c25484650283b241ca4c14b9c209d4cf68032ad29a382569c81959dd6e1c29f415bdbd9c81b716b2390e91b28b1969782bbd74cd95c4851622358f950340e822143af0338545216979c2bc21cfa10d0a9e5a37b32e2a549edc469c240003929d042e91d81ba946db23c634952b6f48980e3b21af7b1e06765d2481d4c7042e24ea2a131774af80c78763515de4a46760b82a06eb1235c1c7015b1af069f467d114f8e95536d290b99e53a439909401be51718c212bce70914a061090a02054210a121084201084204f55d5b390dc657203250f202caf2e32ead35b293a8e5324c819499c6e9ef21d16dca4e6c3f6f471715f9448b446279b495def50083ed51ad130a793512bb5dea4549d8a9fad87edd7c7c557b49212b1e448329addb091eed47653f5b0fdadb68ed55318737256c629a39a9da1a470bcb209256480871d968686fae83487393eb61fb435e608daef337291f1460ecd5061bfc3269d58ca94ebac2edf484faf87ec3dd1331f6aed118cb31a70a",
            "21bac3a71a42197289cd200c15179f0fd8e9354c513b4e575883641a82ced64cf7540201c2b6a3b8b238403ca7d6c2cf6273881c2646f7927570a2fea51ea4db95de38e94960c15139f0fd898fae829f25ce19593ea5ba36a0111954d55769ea24761c70a3375b86a79caf376f971cb1d6c738cbfd4aeeda77c8f61009195c1e49234abcb7d55347181211abf2b8fe0498a08c44d18dd77a18c0aa01bf72e6c709e4019c2b4b4db5ecb93257fd8a3d8d35be91da1a5c14aaf84471b4e159451c6e8da598d82aebc3f60de15b5e079ef5b60aca47a4c2b63d5546e9d99e7658f7d33a061ca897c8beb61d34ecc2d6d35207d187e37c2c95b47fcab0fb2d3d0dc9ac80447d42edf5f9b1c71f22a6ba2ab9a6c459d214ba282a1b8d64ab8a711805c5a37485cd1c00b79d9c2d45b4e87cadc1439ecca03b3e898e6ef95bcca59e112d7476ed4d01a06e9c376ae6f639cd38511620a8898fc1210723cffd2aa2b28e77cadd24f2ade5cb2d841fb9a148e15b5b17d23c123202c7dc661534ce633d536a2e65e2566be0a8b6977d44ddbd59dd45b45df4553ba07f982d64c72f2a0dbe83e9630fd38ca9a013be12df0505b96154175aa7301664ab79aa44408270a8eb4b6590b8f0be77b3f7519896adcf9dd1ee9b1504e6a1af19c129d3b5bfa80d3c12b676db477216498ca8ea7dec3b1f69f43478a20e78dc0593bcb89aa2c1c656fea1cda6a43191838588aca533d4b9e06d95f438df0e26f592a882027b479576a98bb6b883b28a9d93184612b9228d830800212156495e3d9585b1cc68f361578dc6e812b99f6a8132e6f6b9de5c2823848e7b9e774e006394284210a500254812a10d7fd8ef82a2a94ffb1df0545597235e30a533ec6fc05114b67d8df80a38fd999c84216ccc2338424281d9042e6e0952eeed903e3231829a762709a5a5a9502119f55d23606b839313da723083434844900f65ceb434c5a4055d05c3b0cd00a596bb5b794534e34f2b692524ab037a8f1b00a9a4fdc29bdad23950b6a5f6995b562a780145600d08633d5388013699e0c248402ef74b908054842d2774a36184a9ae4089539a010908080c6c9a5d84a4e10232edf0a280254876d92a6c012652e764614c4e89ca5c2004b85155a6f0523e32edd3f64c739c06cbe7fb1fecabe1ecd78db09a1d8182505c7d576a485b532861596dd9e3935b72cb1835072687f70f395794bd2ceac94b1b9c28779b3bacc7cc0a6eb5d7e501c40d901c014b186d43750408f0e4f9541253db697855aeb9ba498306dbab5986a8cb42ac6500136bc27caa56d4f50e058f2ee1597eafe5032a9f4e1a024d0394dd171faa8f74e6de0019055368086b00d894dd1742ff001c9e538ca6b2edaa60c07954cfa78d9e60774b4cc2241213c26eeb434d2b9d145ddcaac9ee7f50d2c2760896e5dd8bb590aa9c7b6f25dc281d1b18c9d3b9291efed370fd828d25608c131025cadfa76d3375049a256e01f74ddd6857b5cdc65a72a4416a92b1c1ed71002baba74bfe96e11b775d292375345b0e546876b742298b5a77216a6d4e3513b5985938a4225c9cf2b65d2ae6cd50df7ca483654f6d3494e2476e30b3b7a8ccafd43d16debfcb40d076d9636ba4043829d8c7dd640ff21f458dbd3833ca02d9dd18039c5632ec35cdba482caccccd26e5496b9cda860076caa6a3af3080ccecaea22d735b26ca6e7f81a985a040cfc848e6e375574f71d4e6c7956e19a980adf83cd08dc143b00a3469dd49a1a4fab7e02ef70c9f111f3b203f4eca5d7521a5206ca2884bc676570d01a4e484caa3aa96560f509fdb70384ca889e2173826c79e9b1c826989270e254eb0589d056093248ca9b2cae323c10a7d9cbdf2e9030a468a5903e9db1b46e0282eaf6c034b829203a227572b397b7912ed9e552ed22ba7efbb63b289282632dcfa270fb01448310179c7b2f9fecfdd50cc35daee8d8b39dd7a8d2482d96c63dc33b2c35aeced9ab85460f2b6b73c3aded8f3c055ebfdec3b13faaaebee9f5e1da76c2af8800d21c374e8620cd401516aa6ed6775f4185d4db8377f242ba003385581d9526a2632b8ae18d255ab4c7d7929d92651ca124587",
            "29708424aa90f184e8f0394d421b2bf19ca951db1f2c7dc1c286fe02d1d248050636e112cf399a1fa7d9238694f9ff009ee3f94c779884004a97184881affb1df0545529ff0063be0a8ab1e5f6d38c8a5b3ec6fc05114b67d8df809c7ece4390842d9984852a42801c293450895ea38fb54cb4b809bce70103ebe94443202af56f7a9198f238154ede37501c8ce10534a90119394b8401919470a0a4df29c5c484021239c4ecd1940e070131ce24a5dc73b2236873902b6373c7093439be8ae28e923737770096a692168d9e148a5c94a374f9981ae384c67e5019c1c2339294804a08c1d94043b1195670526602ec2ab79dc2d1d03a275190e78071c2159f9862421227556d50ec7194c71e134028050ffb5720ff006568f471f0dc9d73840785cf57ba352ae4d7f87953cb4bce47091e4b42619748d8efec9595521706ba0273eb85f3fcff007d4cebd85818657e9c2bda3b6089a25d8275aadd2cf83d8209fc2d0bba7ea9d4a7c85bb7b2c5d0c66a38d82b445540170dce158f575aa1b8519932dce16322a6a9a2b891238b403ca917ebe5447008d92170f945e5f0cf180d248e634ec11af744731946a7f25308dd136ece2f24a70c61340d900e4e1152a12918488049a0c87012a42e2dddbca04923734e0ae924821a52472b9fee3f7c129d4904f575022311d24e38414715c26fa8f704e30b7bd37d27375069f2101deeadad3e1e534d1b26735b9e57a0d1514167a689b080c231ba0cc9f0a20b6c0659b49f55412cf1d9aa3b748d01c3d97a1df2e6f9220d3501c08e32b0774a789d219460b9044a8ac9eacea9ce4ae6d765cd6fa14c12e490470b9be5d3333036ca0ba16d69843f1cabae9088b2b86db02b8d298e5a268d4338e168fa52dd134f70bc6aca0d1f504c62a018f65817d5991c4656f7aa5805b7237385e6f08fde3ace065056dd5e41c1591ba001c4faad95e2366721c0ac55ebb9abc8c2e410483b38153a0b8b8696654360718bcc307d9244dfde6fcaad8353451be49a3702b55187089be60b2b0bc471b0877a2926e8e0dc07e4fcad78b2d0d0484e9fb94ab7ccea4697ea5936dc2a1dee94dcea19b381c2eb70f3fe05a5eef334b2f94a851dda70cdca8af97bbb95c8ecbdd3744d3759f3f714efd5e69237349500399eae01366732389ce6bb27f0ad20730775ce24eebad354ba99f969dd65e4ba54c6f780d3852adb5d34eec3da506d286e2ea99087eebbcb6e8aade4bb1b285641fb9e66ae977ab34ae3a1d84b7c0857585949e5690b3135ca47d50a7192d2576b95ca47480bdc4aeb67a5755d5b64ec12dcfdd85f3bd9bbc911a5b653b60a30fd3be144b8dc9e5ae683c2bfa86c71508680338592ae3ab56ca7af3fb33e6fb5566e73090805327aa328dceea2bda7ba4fe52b7ee5ddc7cc7132c7c946db94d272539c80ddb2a40424f54672955bf082210851a4828421104e54c8eb5cd8cb32a2256b5005dadc4a0f2906c959bbb7448df284ae18291035ff0063be0a8aa5bfec77c288b1e5f6d38c8a5b3ec6fc05114b67d8df809c7ece4390842d99842108046fe870842032efea712912a4445084210084a108689e8a6da9b1ba5c4806142c256bdccddbca09f72a789b2e587655ed1a4ec9c6591ff714d5097513bc0c07109a5cf277792980846502bb3ea9a4652f2970a5068d92a0a10095a5f9d9e40488e0207e756dc94e34ee032b9d39ccc02bb96987601c7a28465b9542e1be13446d66e0e54aaa84b1a4e1438879bcc76578eaf526e15ce04a1f049dbee301289a1efbb4c4093f85e83d1dd1f25752074b19c7e55728f76a6d95e9fe9f7dc1ec9240773c2f57b67415254410b8c4dc8c13b29f6fe8f828626bb00615d32ef436ea72d73db968f75f3dd8ff00654590e6f4c5be90c5a58c1a795cfa80d1c14a7b6d68c0f4596b978814e0c9a651b7e565eb3ac9d72d4c6c9958a6a9fac666bb53a3f29cf21651b397330e3a95d5f8be68ce792a8a166300a2ba3833d784a925cb4e02070892a1084067091ceca0b723286372374039d8627c51b88cb464a7b612fc615adbe944632e0812d549dd78eeb3016be8a8e869d80e96eaf754190d3e5184bdf978",
            "0e283522ee29f018ed82e771ea932c3a01dc2ccf7253c948f8f3824a0eceafa891c5ce9091f2b9999ee3b9cae72bd90b324a6d2543267723081ef7333e6202677211fd4095597895ed9711921579966d2373941afa2ac631dbcbb7cad15aaf51d3d435c26dbdb2bcb3bd3b770e2bbd1d6d409c6b71d283dc6bfa9a2aba5ed8703b6162af533c7999b6eaa6d772124c185fb2b4bd39bf4e08f64151aaa2661c65cadad36a8278099c02ec7aae76321edd2464156ae80b768d45ba183ea2a19a2ab2da78ce8cfa0552e6ba9802fd9cbd50d253888999a0bcfbac2f5274cdc6a6633d346eed839d829154db9cda307380bad15439f207bddb28ae70a48fb552035e1322aa8f18695106e2c9daac9346ca5dea38a9b0d0d0b37d315eca5a8d523b65a1bc55d356b4189c095e8e3cfe3762b1c0119ca63e60c614a1a4eca641687d53760babc3d9b90cbd4d4bdd21c3c8490c953ac6412df85a493a51e656923d56922e938db4ac76919c2f7cbb832f416bfae73418b9fc2d75aba1e373dae2c014aa2a28a8487380d977abeac86dfb823002ada1970b552595a5cf7069c2f3bea7ab69935c6fc8cfba93d63d552ddc62179e7d165269a47c4d6bce4a8b65898686d45caa58d63090085ec9d2b6e641660d7403b98e70b21d116d8640247b41c2f48370a7b75bcbb6180be7b9e7f6432d5f04c2470d3b7b2ca5e229a2d4ed070b4751d6149254904b79516ef71a2aba4716e9ce1658f27c7265cbe9846cc24241182941c2e65a0cefd3c653f385edc3bba71f931f25ca32935232bd5c3d9f955345ca1265195eebe8d1505194985111a08421481084201084200254812a2611ff0063be1452a53bed3f0a310b1e4f6d38cc52d9f637e0288a5b3ec6fc04e3f6721c84216ccc21090e7d102a1260a569df740244af38e127f7440425d90800842112100e374242817564aed1d23e5e1718c807254e82b9b08f45087275ae56b75e0e028fa71b2b875de3740e660648552e702e2512611ec933848f76fb2eb05399ca91cf39429ceb4c806465479699d1f288714a3748764a1c1a898585ba6769fcad230f72103f0b331b889838f0af29eb5b239ac6948ae7edceeb4c23a707d4aaea7e9dadaa66b60241f65755919943584e57a0f415aa39226899a08c7a857753a57c31fd23d0b532ce1d330e33eabda6d96da7b3db30400404c9218ad23b8c8863e1643aa3ae8e9753b01071855af759e4dbff0057ba096486376c3d9799dd7aaaaaae79636bdc37292e77474b33dce2724fbaa491ad0f320e4af9dec7fb288d20ab3a8ba471ca99667ba924d72b890b897b9dea924d4e6602c45bdd2e31cedcb554eaf50b9c6c7634b8e57621a1a81bf7ee91203e6db84f79038288221264612b7051270fb533b818dc948e76f8095ac0ed8a0b4b545f52010ad4c7dbf2aa6a3ad6d18c370a5b6f0c24976105806e37282e558dbbb659748e14f6bc39a1c103cb8a4712e2021a7290b72720a0857a2628739f451fa7ddde254db8521a98f492b95b69c503b39d9045bd3845390ab84e081b85a3abb2baeefd4c3ca747e1ed4cad1a72833a1e08f44c71c7042d2cbe1ed74319761db7e15549d3557484c9203a420e14131a7935ea57535e9b3c5a1c7859d923923932766a1f2b437670ca0d8d8ae9030969c2b7fd62282505c461622cb11924d41cadaa6273dc1b9390a069a577d716c8c3e5ce56969ee3411db0c0f634c98f50b0f6faefa58c44e3f8dd583186570933b2b4d0c375874d5555d4c959037f6c1270b2f6fa497ba43b230bd96e4f64b42e898d1c6ebcfaaadff4e5ee68f5514410d733cad3bfe14ba096681faa4712156cd5069cea2785cdf7b0e6e14791aa75ce22463d15fdaefb0c3165c46cbccc5c863395ccdf2469c0270bd1c7cbf11eab2f585235c41c642e3ff1fb1c4b07017997d7893cc4ee7f297ebe36fcaf4ff372fc0f449fabbea2321ae59eb957beb184079dd501b9b5acd8ae71de034e4955fe66425baa451b7f70e7e5253975ce60231eaabea6435e4695a2e99a76d210e23254cedda367d394b250c6d8ddb6429fd47728e9e80c2e3b909945309a1d6060b541bd5bdd71a573b3baf1e5",
            "95b774602a1a6498b98e3ca5134ed616971c29cfb4be975173b2a09906b2dcaa5d5aae5370ea669192e29e4e4a66fa4e1231e43770a3e2f2cebeef93d19c2914744facce9f45cdd0f664746fdb0bdbd5c7cb0e5e1f898384612b5b838ca251a176bd478e910963703ca73b1e892ed0672843869195de920338ce14a2f89b7042eb3c5da760ae45423d8420254490254142108efb4fc28ea43bed3f0a3acb97db6e3f4e6a5b3ec6fc05114b67d8df809c7ed1c8721085b3308ce108c65001d948e0943709ae39412a969bbfe55225b23d8356f851e9aa3b1b8e57796f5348dd38d8281125a5745cae59d2ba4954f94eeb9e33ca05ce7742318429020a10811286652612eea029880df293011e6294b34a0616eea452d4f6082b814ac682774169face1b8c05127aa336eb816b47aa617008020f280dc9dd1ab29cc19ce5036576e0009d4eeec4a1e5c5247a1f3b5a7dd5abed2c934e9dfe1312dfc2f6c548cba169257a574c52189c18c1f6ace740586318d60af418a8bf4ed52478d829cf291d1e9297ad3a8e5b5d239bdb0765e295dd42eafab738b405aaf12fa96a5f23a1db1b85e7713868323b92abf5269d03eb65324b90b900e212093b872175690b81cffeca833ed4e6c8384ae00ae4598390b11d48cf098e3838ca563f0374c918e79d820b0a2a0ef8d94875880764b975b338c6cc11ba9d265c764154eb337200289ed02180bb2ad9b19182573aec3a9c805065a36e82e19ca7819476cc6f767d4a3840e11e79290c3f9465de8825c3940913044ed4ac69ae1e60cce557021c9f4ed6b2504a0d2c6f2e60384f780d00e5718261d81b15d69a2efbf041c20e91462a1c1a0ab8a4e94fac68193ba9767b443a8388dd68ce8a1607301d90565274eb6dac009dd5bd2d43294674e7fb29f6f8d9728b53c3829edb2c0463082b7ebe39a270318ff0abdd6b86ee4d30601abd70afa6b6430c670aabbc689e648479c7b20a9bcf858dfa4218df36160ea7c38a981eec8763e17ae45d495726d2b4ff0074d96a04fb960dd078f5359a6b549e7c80a2dc6e9d89800bd07a82dee9ddfb6d0b1372b1863cb9e0e5073a6a8352d6b8f2b5d6d8dd25363f0b2d05288a318f456b4f77753c5a0141693b7b103c6339590b893a5db2b692eb2398e0ee0a81237ea1a72831976d9a551f3c2dcdd6d0d743923959d65a00714153c7aa4e54cada410950c0ca00e47aa76838ce52b580a091c2069f95d60a6339c02960804cec2b6a4a26c382420752508a76825682d6dc10554caff28015b5a3703283616bfe49530304ac2cce32a25b7f925486b8b77522b6e3676bd8e39594fd11a2a5de6f55bf204e082a1b2cf13a4738aae8626b28db4ec273c2adef891858d1badc5d6d5018cb46ea863b4431bce02bc8690ed375fa276870e54c968bf5071999b7c28774a18e21a9bb1533a7a79247b62f43b2639dc6f878bb32e9164a0962dc0271f85c99fb8fd0ee57aedbba529ea28754a1ba9c162afdd292505597c6d3a415b7f27272bca926b5f6e0ee2ad3b3b195a4aa71147a0f21671d190f2ba3c1cdb89c65fc9cedd855b589ad2df32a707ca4291495469f82bd9c796e194f1a76bc002721beea0fa2ed2cbde93515c9dca9fc926a10a1184a953b0842122211df69f85c30bbbb82b96165cbedbf17a7052d9f637e0288a5b3ec6fc04e3f6af21c84216ccc24767d12a0a04c9c21bb1dd084415f83c26a54205d919091086ca84042242108402374210049c2682ef529c910090e7d12a1106e1c52800729c137ee2a13b3bcb8d9213a4e118c24e4efe8a4488636771bfea2b59d330326b8c704d8dcac6421c6a9983eab5f61d4cbc42eceea3d2327b25b6db4f42c6f6c0ce157f59dd6a28e89c61c838526dd564bd9acfb283e20d45332da4ea1b85e0ecf37c5d2e93c2af5729ee554eef1270a1319b60f0a4543e296a1e5ae19ca8ee69ce015e0fe55740ba58dd9bc24469c2161965bbb4132500e394a90b4bb8dd406381d591c2b4a081b301b2ad314d8da33856d69788b1dcf2a0b18e16c238dd3f241cae9ae378c820ae6f2812aa47b622e0a825af95cf7333c2d0cedd54c565651a6a1c8172e76ee4727",
            "093439cec8e12bc7fa500416a0e71b8ca4d5db682f2ae6cd422a3cc5ba820a78865df63bfc2b8b7503677b72c2b4d456da51b3a01fe15932dd4ec1a98d0d41cadb68a431b5af6e4abf8ba729218c481a3754cdaa8a94eee1b2907ac6073045a87976e5069ad96da7ee818002d95074edbea3499b4e95e483ac2289d96bc0c7e55c5175e9ed8026ff00741eac6c96fa601b033fc2b2a5e91fab8bb8c66cb39d2fd57413d331f513373f92b7f6ceb1b58a7746c999c7ba0c85cba55cd6398300aca3ba71f4b505f28cb57a0d5dc22ab99ce6ce307f2a0570a6ec1d52873bdb2831173b74423d710c2ccd5d53e941056c2e8d76925bf6e564af0c1246406e5c82a45c5c0973f70a1d4b23af7938184f8a3747912b4ff7434b587cb808339718dd14ba19b0cae1a81007f529f7189f24e5c02834ed0d9f0f40d731cd6f981288dc40fb485a5820a52d68760e572b951430c7a9ad0832d7294ba1d206e15142e76a3969d9698f6e4710464246d253b4925a374182bb487b9a71855dbb56d6f16c89ee2e6307f8595ab84c73634ec822e1c0671b2035cfce02bea2a589f161ed4b514f0c113f4b4648414f44e2260d1eab419d0d008dd50d0380abdc7aad24a1a180908381c3c602b7b5b8330154921c3cbb2b5b1c124cfe09c20d9da9d984a96002082a3d001147a48c2925833ab524968e6d3a0e027b24d04eaf54d201394aec1c2d7e965423e18a60750e5478add4ee9082d0a56a0025610d3a947d2c9318beb2a4d1e580630a92df5b2523016ecf0b6b79a7faa2e3a72b1f5146e64a5ba71ba5c2cf6a6584cbdb53d33d6f546b190d43ce9ce17a1ddc53d75afba349716e5784c4c741718c8711b85ea765aa755c0ca73267231cacd8debe2c95cc9639cdc6d959f7977709f45ebf7ae8a2db7fd408f56d9e1799d6d14ac91f1884f3eca672658d787978acbe156483b849a750c85d5903e9daeeeb719f74cce5be55ddeae5bc5e7ce6a9bab4a50eca74308cf9ca4734071c70bd31503741d928d826bb8504801ca54d6f29c803c2e785d13485972fb6fc5e9114b67d8df80a2614b67d8df809c7ed4e4390842d9984852a4280421088084210084210284244a8908421008460a0ec8048979e11a48e54229108405214f09ad4ecec86e308927270bbb68def66a00a8ed24ca0346568e2824a7a3d6e61c10a1325fc2860776ea5ad237cad5d99e59718dc42c9b9c1d5c0b79cad45a1e4d6c61dca232c6fe9ea141aea037403c2ccf8974f56db7900bb85b3e9c669634e33b2e1d7f49dfa027483b2e47763a3d3963e69a18e7fa876b255996695deba114f50f1a7072a36b2ee57371c5d00794230857405dededd7500633f851d49b74cda69c48fe1069a28e9f1a5ec19c2a5bac1235e4c036fc29d154475736a8ca7cf55152ff371fdd043b63260cfddce54e78f2e5363a98ea1b98f18fc2ea71d977be10459aa83622dcaa097cd313f95d2bea4b262d5ca221db940baf4b0b47298cd43729ce003b2874ba86070809299f52d6e80b67d26c6524404dedeab3b6a9a36bb0ec29d2dc9ad716b0e106b6a6e7450b5ced4d0565eebd64d8039b1b950dce69e4692d79597aaee6b3add941a29baba499f82e3827dd23aad82312f7b777e5665ac0794e635f29d01c7083402b838ff0030ff0094f379307121dbf2a9194530dc1291d473c8e41763ae2e1010c8a67068f62b416cf11aba08b53aa1dc7bac1fe9d28382138514e0607083d129fc61ae64e1bdc7633ce568edfe24d454ccd74b29d1f92bc5a3a1944cd046d957ee79a6a6049c0c20f7187af68eadbda2f6938f75d207b6addac6ed5e1565af67d487994e32bd73a5afd49342220f04e104cbc465ce0d898aadf4ae8dbe6e56926a8a789d971073c2a4ba54771e4b31841123a58de1c5decb35728fb3544b3d0abd3582307270a86aa632d41cf08160ab93bcccb8e02baac9592d2e0b8670a88b3187048e9e470c676403216879dd3266963b6281a9388d58ca0511b648cea0a8ebadac73cb8355e3f66ec81031f112fe5065b4f68e9e136b21d54e5d9522b8359311e8a3b89963737d1067e99c1953a8f00ad07d5c733000775435348f8e471f",
            "4caed6c639f3800e774174ca72e034e56c7a4e16b4799bbaaab6dadef6b49695a9b5d20a4c1c6145139f4723c92c1809450cf8f556d4757106e1c06558441b2b3cad185af0eb7e4673e8a46b324151cb087e0ad555c6194e760b312bc199c07baeb71fc34020613740c67295c13067383c2bff00446f4ef04713b3a80dd676f3471b64739a3657c7cb8c1506f346f9298ba30495e5ec7c75e16936c15646d7d7c65a782b4b63b93696e310326d9f7594a88a786a899339ca299d31b8b09270172fe5e55fcbe9fa1bb5257d95b112d73b4ac4dead71c331798469279c2ace8ebbb7bb1c0f93d82f40eaca06fe92c998dd8b73956b6694cf097cbc6fa96823730985a385910c7404872dd56cb19d6d3b9596aea374ae25a1763a3778395d9f19e91440fa867932b898dd19d2ee42bcb5d3982325c140ab82433b9d8d97ba3cb32fc21652800a1e5ade5731237d1446d8e16ba10024481d9464222e3614729c5a91bc8f95d4b563cbedb70faaad5299f637e028aa533ec6fc053c5ed4e4390842d990421080c2308420308c21080c244a82800108085082652a44e68ca948d4384d3b94ae6e0a41ba80a0e919f64a1fadb94d20a744439c2368dca8a81133bafd2a5fd091e8ac287a7aa0b44da0e0fe15a456878fb82b456e5fa674d0ed8c6eb98b64a4ed95b065a5aedf6d9575c18699de51c29d2bf2a4b0f4d776663a4f7f55bcba59e89b662d180e0d58ca0be3a9a3ce3850af9d6f2f69d1b49e15e3ddd3f37cb35503e9af3a796ea5a7b69325ca12d1b6cb2d690eba5cdaf78e4af47b75b190d5c4400b3b6babf1c7f4dfdaeb594b4ccd5ce13ef1728ae34bda03391855f247fb200f65d2d745df7693cae7f3f16597e13249e9e57d5fd3ef86633306dcacab8067f65ee9d45d2afa988b89db0bc6ba8683f4eae318e32b9d7ab9fe92afd5a9094e31b24595c7e3754091cd0e6e0a548ee140b1e9d696546927213faa981ce01a70996007ea0e7dd75ea58cb8820a09fd336d33526ae70177a98cc596a5e93ad6c14a58f3be12d6c9dc94b8719419faca0d521790a0be32c380b532363309271959cab21b29c20e0738dd39ad6e8fca08c8ca6838d902c24b1e7751ab6add4eed59292a6a3b40eeaaaaaa0cdcee82c05e75b31955f3c82793e5460709f167b8104c6503deccb42eb4940f649bab3a21888276cd76503e36358cc10130bd81d9002717e426681c940e2e6bbd02063d93096b4e0278e32814b598e06547afd4691c0f0ba176125434d442621ea8296df9749a5ab5563ad92d52771cf38549496e34ef249dd4e702f182836d0f52fea2e1871d95b4550676e9072485e734550288faad4d9eee367b9075ba892124e7015136e2d33e9277cabfbb55b6aa33a7d962e461655e7d906abf98c696f0534b70155b2ee228c341e121bc8282cc9c2e55129859a8aae75d73bae5595e67669fc20b3a4ab6cea43f246cab6cd1f955911841555b6f336480aaf4e87960f45a8270d77c2ccd58d350e283855c41f19c0dd73e9eb7c86b41236ca9d0344c437dd5e59e844550d38f541b4b45a75d3b4b5be89f534e607004615b59666b210dc0e144bc49fb99c26d0ae95e5982d255bd25d5b0d2efcaa673b504b1b81f29e1369d2e24bbb67874aa8780642e09ce6b5bb04863f2e729f2bfb1da2a674ee01abad5511859f95cedf5bf4d279977aeae150ef2abe39dfda55e4e060aed0cac10bf580461717b09dd3e260744f07d9572cad571f0f3aea690bee07b43032a341286bc13cab7bbd06aa873c0f55413b0b2655daf5a5e99ab79bb42038fdc17d0f728c5674bc6d1b9d017cc9d35505b758f7e1cbe97b1d536aec91b0efe552ae51e257e805ba791d26dbaa58eeb03da40c15b9f112c52554ce118c65799d4da66b638f702edf4e7ff00371fb725cb5565faa31840240054990c73c59681bacbd465ed69070b4940d26919b7a2f66b4cf8f82f8aad9ed6f91d91c2e62cd237dd5e88cf286bb07756fc3b38612467e6a37c0ddc28c1a415a6aba7faa6600549534ae88e3d9430ece33e3bd39337737e42925aa3420eb6edea14e2d5e7e6f6f1f07aaa30a5b3ec6fc05114b67d8df809c5ed9f",
            "27a390842dd88421080421080421080414210204147aa110546ad2509a77449e5c084d6799d84ed01ad09b90c70c72a05953d18919bf255cf4d749beb2e0c76096eaf6533a5add056960956fa929e1b496980025246595d2dbfe1fa7a3b6b5ae60074acc5c69a285a481857b53759ea581aec84da5b7415db541002b296b171398e272e51ea691938246ebd21bd196c71cb5eddd45aee9fb6d18203dbc7ba22df0f2da9a58a3043b01535459629c97370ecadbdded50492bb1f68e30b25514b570cee6d3b1e5a0a995d0e9385aaddf4954d2d6e375b6b7bf5d5c632564adf2ccfb8c71398e193baf4ea6b2c1042ca83f7612edd94a73b4b003ec9d6dab74752d007aa8ef7ba56f901565668a290e64c07851ec68eb2826aeb6e6361ce95f3b788d4eeb7573fbb9072be9fb155911989e016e1607c4df0fa96fc1f50d1e6c67651711f3ad34bde8f505d574b9508b3573e8fd01c2e6f18190be7bb1feca0484123643083ca71d8ecb11da86a8d2bf28b857fd53c0ca8e464e53444d0ed5ea824c555252e9d3b05794b21a8875acf39e5e434f0b416f7c71d291919c20aeabb86890c7950257771d945731afabd40a71680c08131a7012166e941d5cfa203fcf8414d7605a709b41426a1b92176bd81918f75decf29ece0206fe9407b21b6e0c901c2b06bf0edd73925f32078c44c01238823210e1dc68cae15af304398f7283ae977b2895952e841f4503f57a91ea1729aa249c65e10768ebdce7eeada9e6ee342cdf07215f5adbaa2d479c2094e6650d0587504a1f927297b8dd5840c74af2fc90bae469cfaa47918e135cf0d081301cedd498ee029db854d70a931b7319dd2db251520f79c3641b3a173aa62d58c8c28f25b5b2979e0aac65d26a60d8e0ddbc2bea5918fa373dc7ce470832ef84c5239b9ca40309f21709df9e33b206e811121c809480b93c90505f59f68b7f653c1d4540b290f6e09c2b094089db10812401ad39599abf3ceec2d348d3244e3f859c7b43ab340f53ba05a021b50c19f55b0b532396b18ccee7d1547e95042d6480f9d7a7f86dd316eb9c8d9aa7678416b68b20ed8278c28f7bb431a42f4765aa929de2360f2e154f505b29fca5a0ab695fcbcec5a4695575313619719c15e8cdb640298920e70b335b6a8269cffab2a8bed98abcc5197e557d25d4cb2f6cad955d9e0fa72d71df0b2a2cec82a5cf68f55284c745e5d476ca6c6df327ebd4dc1f446063651e93b2bdc3184439d0ff0085c4b5c4eea4372c8c81ea88666e258d2fd47dd65aa407cc70bd066b4c1534b2cb29c380d979d5c0490d5b9b1824029a4edd2d5fb57169e3057d05e1dd67d6471c39c83b2f9f2d99358dee0c2f6de8395d4423922e76569a45ad6f5ad9594b2b1ee1caf35ea5b1c35ad7168c607b2f51be49537bd0d70e36552fe9295e08735d821773a5949c6e2f76ff00f47cf37ba38e89e236bf70576a4be321a76b09190bd17ac3c3b8e3124ec075632bc9a5b5986adf1bf23495eab76e975f1978e2d65bf9c7953a92e6e9ddb855663634e90549b7b7154187ed568f4e9a38e7019951a7844dbe394f7e9074b4ab0b653b2a0e1ea1873619653c2985bf482fc71ba6162bdb94229f535836230aa0b179f9bdc7930e2b87b6614b67d8df80a2a94cfb1bf01470df35e6e5f4721085e8621084201084201084201084204297084201012232893b39d9218f2f6a4e3743b5973480a2a1e81d3619051ead43563656f495d3492f98e46561a82b6a18e8e319d256bedc092d255f18c326a603ad832b857d5494b1e5870bb528c46145b9b0cd19039c28aa2b63bedc5eec47210170aaaeaf9882e713bae3153544321f29c655edbadcea903534a1af0b6e9de9e6dd299a646e5c795b1a6f0e2deca72e744dd447b28fd1fdaa291b1c981f2bd18c8d7c63b4c0e047a05872f2fd39b74ba31e435fe1c52d339f510c4350dc602ada4a6a874fd99627060db75ee2289a3065872d3c8c28770b6d0c8d221a40d7fbe178eff90761e6359454d414baf4632167a49dcc903e13caf42eabb4bbe80b59112ef6c2f3dfa29e872ea869637d329ffa1ff05f5aee93b1a353f0afa6ae824b73cc84176958",
            "28ab016bb12602ed055cb202d0f2e6e156ff0090ff0083c67afe9dd27514923061ba954f31e0adcf5b51c667748700ac21779c81b8cae7f265f2cbe41a3629e868091c7cca8150848817f2bac756e6374e57248588024c92ea295eec6c95b81ca63b73940ece026005cfd974d8b52c04076e82a6f3b6015d6ccc3dbc8e147bcea74dc6ca558de5b1b810824bea18c7e1c97bb0bddb10a96e6f71a9382709b4d14ee78209c20d0e46365ca40241828a7cb5835729c48276083932dd03bcc40caafb8d3f681d23656ad2414f2d89ff007b72832c237bb86957b6c6ba38b0ef65264a683196b4040018dc040e6b41ca668df2959920a735848ce50722e24e170b83cc718214ad3e650eeffcbd90544b39912b5f2359e4c8f85c40ceeae2d71472c7e641ded923cc40bf9fca9c2b6469d23385c835b080005d808cb327941c9eed47280365cc1cb8aea3840852603777708f55d5f11919b2023a8999bc0aded8ca9ab21cf6929964a0328c167fb2d9db5b4b4316995a1a71ea1066ea5c636ba31b1c2ccc70cb1d6ba47f195aeac84d5dc1dd86ea6e7d12bac12bce0c4727f0817a720176af8a9cb739217d0fd19d2505acc4e7c58042f3cf0c7a2a565d219e484e9041e17d0d30a6a6644340180822c94342704337c2a6bc5b69e4034b38574d9a395fe41908a89a9e30048c19fca7c8b1948ed703a220c65676eb6ca685e4b19e75ea50b69258496b070b3572b6b5d5264ede5b9f6516a318f2ba8a49a694b7b6ec2acaea0fa76b8b98bd7fe928da0b9d081fd9643a8628267b9b1c63fc2d38b1f955792fc63cd9a3597794a63439aee365ad86d916ff00b7fecabee76ded34b8370174274fe71cecbb9f0aa573c1e101fe5213a3a77bc920264996481a46e9ff009e4ff23ff0bdd6329246bc6e42c9fe906baadddb8c9c95ae7c25c0374672b51d236885b3b5d2d383bfa8537a1a9ed37fc87fc7934fd255d04ed91b03f1f0bd33a2a92a618581f1b811ee17af7e8f6a9691ae7523338ff4ae11436f8416329dadfce178b93aff001fcbd7c1d8f9cf4a6a1eebaa1834e775bba0a08658819183855769829c548f28232b552c4d6460b060616bc5cdf1c5873f5fea5db05d5f606cf1cc228f3b2f9bfa87a5ea63b84eeed1c0257d891369e41209b076f55e757cb45254d4d406d38237df0ba9d7e4f9f87af8b1f86123e4f928e686625ed231ee9639887e5a775eadd4bd1daa39a48a1c633e8bcc2aad3351c8e2e0400bd35a3a50d4caea83addb2d758ea206c9991c16198f1ab01e0144b575107d921fec511ede9b73fa49a9e573082ed071f385972c506d15b53346d0f7120ec55a162f2f63dc65cb3cc6314b8fec6fc0510294c3e46fc2af05f35cde59e21c84242bd2f39508ca4ca881526508c294c2e50931ba5c29404211c9511008c0ca064a602e73f4fa2e8dce70064a95b44c6064a6920f0bb0a2a8a870646c71cfb2daf4c78715571602e8ddba8fca32ca49b6323a474ec1807fc2bcb4d94d516b0b4e7e17a2537861353b834c670b5bd3fe1b76cf70b0ec997861f3b589b7f438348662cf30dc6cb953d0cd04e5ae690015eb55168751523c0670b0d55bd43869c6eaf3c2be5ce3701186a4d3be48d938b03774e2f04009506931869f20cfc2b5b269ce74aa778278561415829c60a9927e4dd5c4f1491ccd9633a42dd74f751d2d152033b839c07aac2b2b3ea2200274500731e4bc8185e1ed5feb647a78b972c3d37553e2351ba7d1e50d09d0f5d5baa2a5b130b0b8af1cad60efb8079e549e9ba68ff578de652483c2e17c6bd1fcee47bbc34b1d7e259631db3beeb2fe21749c171a56fd1b40239c2bea5ba8fa36400fa22694b299eefbb23d54eac7b7879ee7edf3ddf2c33dbd8e8da5da973b1547d144e6d49dc8f55aeea87192b1c48f52b0b7c25aec8dbe11edfc293abe964b8bdce8b38fc2f3d746296631bcf9b2bd4192134ce18c921632e3d373cf54ea82d38ce510a1782c20fa140dcedca7563bb72884f2171a879a46891df6a0ea1a5c70b8cf58ca538795ce92bc4f212173b9513aa1e1e36412e19454b753784fe3651edf11a78f49520ee7281af049d9387084204d2523",
            "763943f51d82568c0412e1b536e2de3242e2fa4141a98070a6daeb7e949fcae55d50c9def71f54195ad766a55c5031a220e2153d7e3ea463dd5dd010ea7d283a38b5fb04e863ee9d2ddcae7da2d270bbdbc3a9a62f76e0a0e86dd3e3218a3be07c470f1857ccbd42c6e9206540abff00f9077ed8dca0ae70046c521c6395631d9660ccb8281550ba07e0a01a70d2021b90374c6f94652f772d40176a381ca87738dc19b8520c820f3b956d7dcc5465a1057920642b3b5e74e02854d4e672480ad68e0ed10104d03230535cd20e3d12938294bb281ba3042793818484ee123b772042341c95636a8c4c493c055f3799985616524e183e106bba7631dd0746c11d4714b5354d8e9f23e14037d8acadd2e235157961945c7fe6c80473ba03a7e016d20d4b727f2b634060b84ecedc40ff006596ab9db5154231b676d96dfa5ad4fa26b2778f29c141e9bd2f253dbe0607461aec7b29977ae15230d38542cae8640d68760aefa6473b3e882759ab4534a7bc764b79a815126633b6557988c8ee709d23748009518cde5a4cf3e17d68c98304fa27d454c11b4b640157d1d736084827d152dd6e6ca879898ff315d2e2e9e19fb37a74bd5c206b488c859a8436a653ab724a98eb5cf28cb892bbd059656ccd385ebc7a9861e630e7bbc50cda4b083a7950ee76692aa2d0c664fc2ddbed5239adcb523e99b4a32e60caf4639c9e23e7f97c579732c32d2b087c7bfc2ce5cedd243521c58719f65ea578ab6071f2e1672b6db25c5b96332b4dc6715165b78ac9a31a33c2f58b374dc5153364ed8071ecb1fd376792df26b95a700af4082ef1c74c1bc00163c972d786925b74ed3411b69c82000162afd7aa3a06c9e76823f2acfa9baba929a85ed648dd785f38f5a756544f51335b21c12785c9eccb2f9763a5e2797b4f4775bd2575d053f78125d8e57b1d4867d134b4e49195f26f821679ae57b8ea247bbee057d5f591fd35344de70d5e59eb4f76ff000c75d2a6a22790ccf2a041778991bdb2341790ae6e2636ea73c72b1758d1de7bc1d97a787b3961fd61bdf873af9192c13462204bf385e61d4bd2b5334523a380e4fe17a10ae60a80d254db85543f4b9d00ecbb5c7c9f39ba99269f3849d0f717cae7687000fb2815d6e9690f6de0e46cbdddb50c9e47b1b10dff000bcd3c42a0751c8e903719dd5e5577a5259666c6d64646ee202bb2c59db031d33e273b90e07fdd6a4b1793b3ee31e5bbaf3f521870d1f0a3aecd3e51f09d6f36b1c38fe4ea0a10de12af569cfe4c759112a10b3e5feb8ee3308e109571f93b59cfc84e50849baa4ee67fb242a1225e3d147f2f3fd9a30bfb6738c953acf4b255cf9ed92148e9eb4baed5cc8b46413ecbe85e93f09a9851472ba3682403c2bcece7fb572cfc6990e85e886dc65617c4391caf6fb474a416889986313ecbd2b159dbaa30d047e15b12f70f33b609fc9cff006cad459add1bc6a0c6e53e9603135c0001768e43a8b40c850ab2e2da50fc9c1f64bd8cefe533c19556a7d4d24ae276c15e39d4cd16ea979cfaadddcbafe3a28a487b83273eabcaba86ebfaad438eae4aeb75b2cb29e51722d35cc54bf4e5591888602b2f0b3e8cebcfe55ad25dcce43395e8d22d588ca241809c640d036dca63c39fe9853a45abeb4b35419fc299b96b9a3d428d6969641e63e8a4eb0e7e06cb0cf8fe5edefeae13255bad0e76b90a876d2296e63f0568aa9dd9a5760acdd19ee57e4f3959ff001b1fd3a3fc5c7f4f4ab0dc5b3ced638ad1dc8f6e9f0df50bcf6cf5660ad68208fcadf324fab81bb642e7f678a62d71e298bcb3abd8f866d785959287eb5a491e8bd3bac6d62419032b112462932d23d1739ab215117d349a3d329d34d10a37e40ce174bb9fdd73c7a2cf3ae22697b1c655e0c1df350b8b9e06d95cea186b20119f65b4bdf4b3041f540839dd644ca1af3181821040a5a234ae3ca9e5c480121d8fbae8d20f23081350030910f8f51c828e100849909503269bb3192544a6aeefc9a42ef71c7d2bbdd56599baaa3082ec82d1cae6e6123729d3c9a5fa50e24341f4410e6a0d5e7c2e3f57f4db038566f7661273e8b3b54e73a523050580ba93eaba53",
            "dd8ccfd055310e03184e8a4319074941a66d3eb01e4ffba974552da67839ce1668dce46b30095328263524073b1941a892fed20b46153d5ca6a64d41365a6630021c094e6b991c45c79081ba3c985cf4690a07eaa5d51a30719c65589396072064d109a2d2ab7f49dd5e50c3f52fc70a5d6db8c0cce5051d1528836c294e01a523461c898e380814ee135bcaeac00b374c03728151ea912a053b85228ea451b839476ee9b2b3bbb6505955509be3daf693b2d15aabcda298537f6592a6bb3ed23ca0b96afa7695bd46e1248741e7741b1b5da9b59032abd46eb5f4b73c40ca6181a56421ab3676fd3b5da8613e96ee5f50086919f541e834a74bdb217156dfac86b434158d65cc88da757fba9145586a6500e5069d97a0c7ee54a82afeadfb1e567a7a700820a9b453fd347abd9278bb5b168a488361fb9656aa3753d6fd413b02b8d7755bd92f6f74b154fea2035db656f39f2c7d22f95d477a6398360ae2dd56242d76152d159010df5056ba9acf1d353b1c08256d876b2bede7e69fd531d382c6e0285574e67054b669e0a1e71c70bd585fd385c937933757d35f518710a7dbac1153c597346cadb396e132490b0068df2aff0052e91248832dadb52d708c018f655177a4fd3adf23dcfc1015d5cebff4ba374e3db2bc27af3c5dd2e969dae27d3195bf1726fddf0f675b099563bae3ab6a21b8491891da72b2d441dd4754d899bb9c70a25c2e42ff00567009738af44f0cfa21f1d6455320c0041dd737bb7cba9c7c7f17a9f84bd1351d3ed8a678c67057b336275639a1c73854140c0ca18db1e0e90385a1b21716e5dcae7cad74cef58d2c7474c481baf3b32f798ffeebd73aa2de2ba070e480bc9a788d3cf347a70012ad3f6ae7b936cc3b26e1827d568a4a312d3004fa2cccdacdd00008195a9ed11037127a2f7f5b9aef4e365daca5d6d47516b3447b8df52b15e23402a691a40c9c2f48ba33b345ac9d47d964e4a0179cb251a47a6575f19b8aded64f25b3934f511464632f03fdd6a8b136f3d3cdb75ce32ce1b234ff00baee5abc7daf163d7c1c973c775e6a1751c05cf0ba0e028eb6525bb7a78ff2e8ce138260285eafab8fedcfe5e3b723d18ca667095aec72b1e7e4c6e1ed97d3c8e20a420a735c0849a86570b926ea7e9e406dca0bd729650c76fc2ebdc89c1ba4eea93145c6c18717b76d95bd1db0ce03b07099470b24d390bd23a4ecd455108ef6028d30cf274f0d2c0d15ec798f3bfb2fa42919d8a26346c301797f48dba1a5ae6b61034e795ea5213f4ed03d969bd32ffa3bc7077cae7ab59d24e13980019291b1995de44b5a6385a6d4d74569a77bdd83b2f2bbef563aa2a26d076dd6d7ab9e453ba227070bcae48e064b26b70c9ca9c6eea994b3c307d4378aa96b8b81380557c7749a69da30b4973a1a67f71db677c2cb35dd9adc60632be87af358af38b2f723534701a9680f3cad35a2c54cdd2ed432b28c9de20063e70ae3a66b2a65a80d9721ab6cae8bc59fe9b07da20680ec8d927e9b0b8e72000a63e2690cc3b655978b84544dd0d78cac7eb445e2cbf498c6b59e469d9766470e92e73c02167e96f70b63739f2373e9959eaaea499b58e05ffb64ab7d6c5d0ea6194be634b70bb39af30b3cc147b7b4b6a84a547a5961a98bb81c0b94ab3d3d555dc5ac0d3a33eca979f1fdbb124686199d2ccdd0cc15e9bd290b6a606b24e70b3d6cb0321d0646fa2d9da618200ded9c15cded673246959d5f656434ee91bbecbc5eeec71a976af28057d0d7a6453d31126fb2f24ea8b75234bdc365cdd0c14b6a8268def2e04e179cdca26d25c5e5be856cae32d4c15123622742c5d6665a991d22b41d0dcdd554e622e24615255da991c6e98632ac22753c61de619526d9251d6557627700c3ee831edfda717bb8cfaa52e129cb56b3ab2d56ea58bfe5dc0ede8b230b5ac1b207067e52e356c98266e48253f56a1e54086203d5349c25edcd9c90709c1a3d5071929fea5b825329e8452bb500a56cde105dab628394cc331fcae824d31e82119d09b21c8ca0696e785c9d461dfd3ba974c185c32ade9e9a9de06fba0cc9b7e4fdab8d5d298e33e4e16d5b6d89db8c2e15f4",
            "54ce8f4b4799079de0e4e42ef04ae8f8385772d8f53ce18ec14d75a9b10dc1082a7f509daee729cfb94d237182ad63b7c2ee42575b63f40828a22e74a0e9feeafe9b53a1030b9b68034ecd52a91a5b286969c20ed6d95cda8d18c60ab6ba387606f9385cea69e1a783bcc23561540af7d539cc767641c98dd4e252b8e3d12799affc27487210207e504909ace574763081b9d5b27b4471b705c32a3cae2d8dd8e552cb3d4824b8b8041715b51d98cb99ba8d6da996a6521dc2e76f90559edca558f61b01c443fc20b5a7a38e42dc80e5754d2ba840ec9d1f0aa2d3adb82f055b3dcd2104a3777b8b4b8ea255e45318e9d9206f2b2ec6b0ee7d375228eeb3cd288083a0708363475ae95c012af1950ea68c3d83759164e206b5d9dd59db6ea6a2611b8e420d8d92b1d5ef22638c25b9dc9d46f746c190aa9f23e970f88f3ecad6dcd82b999a82357e5052194cf501ee6ad25bd85cd69e07ba5368a6d7969185d04b142f1034eca37692e9aaa1788a9410ec9c29d4772925903093855b42f85b4a1bab7c252f7c2ed7185e9e1e2af3763967c5a97464807dd0403b15556fb8cf50e0d2ad8337f36c57be4f8fb7132f376e65e23380775da9e132c6e7b86c171742d6bf513b2a0ea7eb58ac5432b039a0e0e163cd9cd2931b95677c40eada7a1a19e99cf6eac11caf96afd30aeba48fce5a4abaebaeafa9bb5da4cc9e424acf39826c39872e2bc58f3595d3ea715c7275b0d339b7461637232bdfecf5afa6a08b0cd2401e8bcbbc3ab3892bdafa96ed9f55edb574b48ca4608b1c0e133cbe4ea363d23727545290edd6e2ce73e985e73d1b232301a17a3db7ca42c748889769e564c5ad0482b13d416e6b627cc1b871caf4d752c733dc5e070b3973b632a5ef8f1b2b6d19eecb1e095950f6553bc8460f385362ad91b06a2e2b6bd41d191b227c91b77fc2c154d1d4d2b9cc7b4868f75b75eeabe7b9b8b296d4aa0ab7dca4ed3f70bbdd28044d6f6fc847b2a882b5b40fd6d232bbcdd4314a5a25705dcc39e698dbe192ea591cdaf8d87272e03fdd452d5a2bd43455999d8e69735b91f215010bcbdace65669d3e9fdb5e5e0278e12009cbc3c99d91efe3f63384ba9333bae8002163f56b5fa729329ae3b2427052bbd13ea5a8fa589d16484d27cf84f3fb78c7aa5d2dfb9656978f1575ce52c1b25b6b9d2632571bbbb232ba5a33809b79b9f0930ad75b580e90b5f6c9a68435919c158eb6b8b246e7dd6be95a4b58f6bb748e367adbd5ba17ba4b0bce4af541930b73ecbcafa025f247ab95eacfff00e5d847b25676fa84c02dc2e90e21617051e38a591c000a59a195a00c12a5d7ea71cb8f9637a9e9e7a9748e6838c2f16bc4756daf95a3200257d1d73a4d14cf263c923d978d751d3329aaa4796e324ab61e2bc3d992726982919298ddab3959e92191d57f69e56b6a5f1893ee1f0a3bfe9e23dc7342ede1dac2631d6e1e29f18e96a747081df1b7e55f4772a08403139a1cb2370ac8ea622d85d83f859e06aa9e6d4f94e907dd539bb78d9a8dbe962f4bba7578a7a721b260e1606bfa9eaeb677665dbe5677a8aef2ba2c4529247a654fe8fe92b9751c0656b5cb99972dd9f4b141ba5e2ea1e04329d39f752e2bebc40c13c835fcad3bbc26bb4ae0dd2e24fe14da6fe1c2f35d0baa4c8e6868ce153eae4bcc64f44e98bec106974f23747e4af59e8cea7b0cb54c0258b567dd788cde165e2969e687b8e0e664058ea1b775274e5ddaf2660c6bb7764e084f98fba5fd41666005d24606131bd676480f92a23247e57c8f76eb4b84f4a238eb1c24c631a971e9987a8ae6e739d55211ff0052adcb697d8b1f5ad9ab0689278ffb958deb6bad95f13c433c79c6795e1b0f4df5348e776ea241fdcaadb8f477575448419e53fdca84ad2efd51470d5490b5ed273818595ab99b53dd918463959ebc58ae368adc55b9c5f9f557b4568a89e89ba33e718508663f52c543d85e39f74f7d4161d714803be559d4785b727b8ccd2e1ab7e120f0caee61f297121057c73d4dc7f6df264fcae7346290e9790af6d9e1edde84f7246b8e7f0bb54787175babc90c70fec83384d2fd339c5cdd7f2b95a6406a0e",
            "b20b72af9de10ddc1d45ee0d1cecab6b2c12d9a4d0f76e105ccc295d17974f0a8a700c843709b49f535b5229e1cbb271b2de51f8655b2533277b0f9b7e1060252626e4f0b94352d94e1abd02bfc36ac9212d6b0ff8594a9e9596c4e2e9723e5056cd3b21fbf64f8dcc9c64382afba446a9d961f5532d162acaa606c793940af2223b382eb4f5e58eddc3fcabca6f0c6ed56cd78760fe13bff8497671c343b3f0839d2dd630df33c29b435d6e9a60242dca86ef0a6f913b76bc0f851ee5d0773b5c5de1ab2106d59258db18d4184aadb9fe91283db0d5826c956e93b6f79047e536b24a8a6687179dca0d4b6968c93a74a911dba97192e6ff0094ee98e88b8f50d00a984bb18ca96ef0faf4c98c5e7d90417d35133d5bfe547ae651b294ba2d3aff000aedde175dde3512e4f8bc2cb9423bb297160f4c20c177e69321db352358c61c8c64ad75dfa3ea29a22e8e23b0f658cfa5aba7a8226610d07d4207d4544710df0094914ac91b9242857580ce418dc091e88a0b64f2334871c9f4413dd244c19c84d6d4464e0b82bea1f0c2eb72a41331ae20fe13c783f796e4e97ff82833d231ae76b072c1ca8d719299f0623032a65ead555d3a0d2d403a9deea86929259aa9b09cf98a05b6e1b267216bed935081999cccfe4aef45e155c2ba013c0d7608cec123fc1fbeb9fe4d5fe0a0b06d450bb68dcd1f091f2c2cdcbc61409fc37bd5a299d2c85fb059f0faa74c6091e4107083562e746dd9ce013c5ce92321d1bdb9548de86b8dc631240f71cee9e3c32bfe5a009307f0505ccb7c6bc81dd6ff00952e86fb1c528d320cfcaa97783dd40e884a4bc6df95515bd2775b1e6599eed907a39eb58a9d9fbaf042e7ff00c4281ae0639001f82bcfed165adea77f6585d952eafc2cbbd2ca1a0bf054df43d66cbe21d2cd1e2491b9f95aaa5ea2b3cf4fdc33c624f95e376cf08ef2ea6123247e719599ea1e9eea3e9d9cb9f34a221f9215f83eef2a673c787d31457aa7934964cd23e56a29e78a6a604381385f287465fee551591c26a1ce19c72be94e9cb756496f8dee24e405dce398cc5c3e7cb29755a3b6e45461a7d55f3dc44807aaa8b751494ee0f7e72af69e30f7f75e30d03395e6ec59f879b6aeba56328a073e5786fcaf9dfc67bfbe563c52cd9ce782b67e32756491be4a6a3948236d8af9dae7575d592e6a647119f52b95c995b5edeae3e7cb2ee96ae690979739c7dd5ff4b51d43eada6707467d53631019da080b576d116a6e8680ab24fcbb78c93cb5b6f8d94cd61800071e8b5f6aa89278c36424ecb236d180df55a9b73bb5a5c760ade11b6eba5e46d3d4343b8257aa514f0769ae07d178dd15c22706bd84642dad86e0fac6001c5454796ec3c3c642e6fa788b5cec79947a12e2034e4a9a00ed3fdf0a9655a550cff4d97366d38fcaf37f109948ca579a60d0fc7a2b8eaab84f4d5858090160ba8ab5d234e5da96b8dd3c9cf84f8d61208eb1f3bcca4e8ceca05de9aacea3113f85b3a78bea22c362dfe14886c9f5070e663fb299cb5c3e491e594925c99531b242ed05e01cfb655fe16b2e9d33153d3cd3340cb18e771ec32b2856ff002b679747a53fa57986109e1a98792b3e5f4f7f1fb26374a4e100ef84d7f2b06e701943bcc4008274b1573ae1d990ee82c6469006523039cabdf76d4dc6574a1b887bb055f19f20db9d3b9c385d6d71987195266789b1b2974745af1b2de756d79f9f1b6696d43e773485aab7f903493b6566a9e3fa77342d2db7f774b4f097a99395975eedeb1d0d139f1c6f68d97aa82e6d3b011e8bc73a46e8fa32c89a765ead477074f4ecce380b3e5e3f8cf2adeb55ad355b6270cb42b21748b1bb42a270d5828735d9d8ac76ea7578ee38acab2b229e373748dd79175ddbb53a47346395e981846492b2bd4d4a2a1aedb39568f1f6382e5c9b786496795f2ba524e1aa256c22688b01c11b2f439ad819149186799dc2ce7fc2358e91c4b48692af3274f8a6b18c14d4aea2697971c2a2afb9beb4ba1a724b87b2f44eb6b09b7da1f23b63a5633c16b543d41d55f4f51e66977aa8b5a2e3c33f0b6aba9eb03ab1aed04fa85f4a583a0a87a469e38a360271",
            "becb5541d196fe9da680d1c6038e3385d2ba99fde0f933855b436dd4346f05ef85b903d92b6b8b647d3b22c30edc28b5159f4cc739aec34059b1d7b442e020d6cd795417b2f4732b9ce7b9980efc2afbdf8476eafb648c6c2deee9e70b5d43796d5451e9f51e8ace390c6753b2410a47c21e21f87957d2b787c8e2e11eae16dfc23fa7ad2d8cf2765eb3e32f4d53dfe091d1c635805790f86b6b9ec7d40219090dd683dee9ec34d4e187473f8567059a8dd2177641f2fb298fa373a862947a80928e421ce079c6107cade3e470dbef45e1ba46ae12f87f5105c22a661c1c90b4ff00c4374dc557fbe73ab3959ff0aec618fa5c13b1083dc59d2303e8e27067dc07a248fa562a6767b3a8738c2da5353814b037d8052eba88c546e943786a0f30ad829c4c2214edcf18c2d2f4e74bc13c25cea70323d979f5c3a89f0f52189e4635617abd82f05d44c2cc6e3d105557744b652f8d91739f45e29e2c786b25042fa82d2ddb3c2fa8e86a4caf048cac278d14ccabb23c166fa7d107cb7e13d9a9a7bf88e63ab0fc6ebeb1ff0087a845b62631a381e8be7cf0afa69acea13261c3cebea0fd2dcca06b9a4901a1065abfa7e9a9edef91b103e52785f2f78a355ff3f240d6e375f585da6923b44eef46b4e57c75e24d7fd45e652cc1c39065a9ecf513c8dd009c95ef3e16787cfaa8a3924849d87a2f1de99bb345647139b9395f5cf866e34d6c8a531e0168417b6be8ba7820d2e800fecbbb7a5a9699e5e61047c2d3d3d477da481b259b12b0b7d50632e36aa29416b6019f8595bf744455145238c5b107d17a3d45adcd717e0aacaf9c8a4958e6ecd0507c5dd7768658ae4f38d232562ee571fa889ba4faadf78dd58d7de1f180465c579870c6e3dd07d83fc39d2455bd3918963192df65ead3749d3baa1cf100ff000bcbbf86c90fe8716ae74af7b6b8e49c7a20c89e998f04767fd945adb042ea7747dbc1f85b869cb4e42c95e2eb1b2b3b0c70d44e106719d114b55aa39231fe1643aafc1f82bb5474d10d4ef60bd8e92866fa7ef1c6e33b28f154369ea83a419c141f22f57f84373e9885f52e89e59cf0b1bd391cf35c1ac730801f8c617dc1e20414fd4361918d85bb34af93aa285b66bf3a20d03327fe507d1de1c5a295f608bb908ce9f50b4535ae8f3a1b00ff000abfc3e6b8f4e46f1fe957f48cd7364fa141f3978e5d1d11985568d1a77e178c586962abbfc70b4ee1c02fa57c79958f84b78185e13e1f58d957d5ac2c04f9d07d5fe1d74a53ff00c3f117c59259ecb45174b523663fb237fc2b0e97a636fb3c2cc60690ace42400e684184eb3e8aa796cd33db08fb4fa2f8bfade8ff4abebdad1a7cebefbea399c2c536a1fd057c21e2b3bb9d42f236f3a0f60f066d915de9e2120d5b0caf7693a62d10c0c02369781b8c2f16fe1ef5369e31ee17d033da7c866d478ca0cbdd2869d948e6c500c01ecbc4bc40b6472c4fd4cd23e17bd57cbdaa791b8cec57887893520d3bfd374107c20e97864afcb1bab75ec975e8e876776b27e160fc09840789795eea58daa7b810a3659e191b358e2637b659b63d979578eb658596f7c6c8c076395eece60a697202f07f1eef61ad7c639c616bd7fb94cfc635e1be1f5148cbd46cc1387ff00e57d83637fd159e02e67f485f2b787327ffca0948e1d95f49d35ebbf49040df60177f1c67c74e0f2ef3e4698dc9920c9c018553d4bd6d496eb548c6c8d1269f7507a81d35050775ae032d5f3ef5df51d63df23448795e5ece331c7c2f3af55fd47d4725c6f72be476a66a3eab3571aa64b2e968e4a8e6a1f202f71f31519fb4cd79cec571f2f6f670715c6a6c56792591b36e02d15bdba5ed67aae54550d9a16b1a15b525069c4b850e9e3e975424c0d6b8abe82e8278c4630b3d1bcbd81aa65b22224c6528d659d8f6f2ec82b7dd3b53f4ed6eeb0d6a86418cad2413ba99a37c23cd9f626396abd4ad9736968e3242b588b9f938d8af3cb5dd70c692e5b3a1b938c0d71231846d2fca6e329d71692fd52631eb95e2bd4958cb73dc647f1eebe82ea09bf5088b00ced85e19e227474d3c723c070c84472cde2a0b175ed099fb24b739c2df5057c15d0ea",
            "8b1c2f9be4b254daee05e4b800e5e87d33d52ea2834b9dc0f5531c5cfad6df0f4db8d1c92596e12e9c86d3c873f0d2bcb0af44a2eaafafe9bb8c7b79e9a56ff9615e7595b4be1eceb71dc31d579b86ae4ee4fca938519ff79f94e6f51ebe2f6600494afd8a70d935c351583524e0f64e167270eeebb3eeb4e5996615754dbf4873f095314c1b90a6db437ba32a28d4d2e1853283531d92c3cfb2f4f5e4b53a682969db5b20644370aee9a0ec0d0e1e6099d1cc6cf52488ff00d95a5c69df1d53888ffd97778b19a56cda211a256eb3b2d3daa205ad903861602e97099950d6e0f2af6db739db086824642b67a2631bab6dc9f4f58df3f973c2f54b0dde49a16104e005f3b5b6bea65b9b18fc86e57d01d1cc80db9a5cf19c05c8eecd4da26136da525c05439ad1ca9ef0e0401cacfd0168ab0187d568e66680d7972e6c5817619a4f2a14940c9c9d636531a4386795cdf2e0e0056fc164aa6aae968e4777580602cb751d5b2d91b80681a42f488c97d33ce7d385e4fe22eb8e9a57e93b02ab8d1e4de20f5bc55d4d251e7cd8215378007b3d5ad90b4eef1ff758abed6ba6bdc8d2d382ec2f5af032d508bac536067215f63ec19240fa7a527d82857b0e2f0d0765d2b676b68617379680ab195c6aa521ea062bc4aba4b69b348e85c5a74af9b2d9d515751d4f197c8eddfbff0095eebe3a55ba1b4bdacf65f36f4d81557d877c12ff00fca81f6ef46c42b6d14d2b0f983412b4f2482384879ce36592e8261a5b0439931e51ebf856b355ea6105dea8293a9a97ea29e67c6338695f3757751c96eeaf6c23ca449bff0095f5476e396927d4e1bb57c8be255332dfd67dd6f064ff00ca0faaac17692bec74e49ce5a176a493152e0f597f0bee0cadb3d382ee1a16c5f0304f90420f39f1b6ceca8b68946305653c36b4f6c42e681b1cada78c12c8eb588da32166fc39748191e47083d75b23e364783b340532e775cda24c1e18a035daa200fb28dd452762c133c73a0a0f99fac7a89f0f559d2e3f7af71f0dae86e96f637392005f2d758dc73d50e2eff5afa0fc0fb8324a760cfa041ed7444c0093e8aafa96923bcd33a191b91c2bd81ac7c67f298ea16b9060fa73a3a8ed356256c401ce72bd1187b94a631c1180a28a06b40e17491e608b64180f102ae4b3d9aa41761ae695f1b5fa535d759a5ce46a2be9cf1a6f52476a9d8e27ed2be4e8eadd2cd2b8ff00a90687a368e9e7bdc4d7372ed417d89d2b4bd8b34000c37485f27f857442b3a8632467ccbed8b1db58cb442dc0d9a104ca121b4e74fb28adb9363a9edbb9cab286211b0b4059facd11dc867dd0685efef479c72ab2b6d8c9617b48ddd95651399da047184bdbd7841f1ff8f9d190d2d53aa34e0ee578554d2f6a9448df472fabff0088ea2229dce1ec57ca956f77d239878d483eb3fe19099ac91177b2f7e7820bb1e817817f0c5e5b24407b2f7f772efc8415aeba35baa0c79c8d9789f8af79abe9b90d631c43b390bdc62b5324a9ee11baf06fe22b408cc5f941adf0cbaf6abaa2ccd69712f03056e296904d3626dcaf21f0220105ac1017b2dbd85d5649394117aba8c51d8e5741c692be4abdce27ea12d70f3773ff002bebeeb5762c92b71b1695f205ec31bd5040e7b9ff00941f4c7872d79e9c6373fd2af68f58aa23d32a93c3fd5ff0fc58f56ad9505080f6b9c3941e11e3e3e36b366acf7829d22caeab15ec60d8e57a0f8db626dc2a1b0c6dcea2a6f84bd33259a10cc601f441e8f415630ca523ed1853dc08207a2e2da48e194498dd772751ca0abeabff00d066c7fa4af837c51cff00c44f68ff005afbcfaa3ff439bfe92be0df147ffa9ddffe4ffca0f70fe1f5c5d144c1ce17d2993d8d0ef65f357f0f3f7c6be969f6849f66a0aba9b3473d3c84fa82bc0bc5eb5b68a89eff00caf7596e8fcbe207f0bc43c6eef3adaee77282c3c056875287fa2f6ea07b5d34831baf0ef008b996e1a82f71b6b59dd91c4fa28d873a83bce24fb15f327f1171c703dcd03cebe959ae2f85e4378c2f9aff008877b260f909f32df83ee5797edaf33f0d246b6ac078c9257bdc70ba38229a2380002bc0fc3d2d8e512387f52f5daebf88",
            "2db86c98c0f75dee39fd5c3c7fda85e2375f4f4742600f248185e21557a92e8d7be4ce49577d5b7a15f3b98fcb966435b18f2b765e7ede3ac5dac31961ad7f6c65e3653e96885539aed3e54b4d4c2a5adcb3fd96bedb69020690ce3f0b8997b69309096fb4c4c8439a370ada36b443a7098c63e26e90d2ba358ed39214040cedb7213e96a9f0bcbb52e150e2d8cef855b4b524d416b9db6549637368bcccf70c9c2baa8b9cb23000fdd6221a9106349523f52908d8950e17737391e8d65ae91f1e9749bb4655d5b3aba47548a32e3ec1790bba8e7a1d3a5c7cc70775b4b118de21ac7bfcc70794767abe708f61a46b58c6be739d4a0754daa1a9a074a0374e1408ee827114624e00f553ba89e5b60710ff00e946963c4ba9ba462afd5d80dd59f45907f4fc96a044ac256ea9ee3232b4b5cec8d4b574361a5bf463531a5df09a44c63c7292a2a608dd1464b6370208fc232b61d6dd36fb2d43db1c44300dce3d163352be0ae724f4c186a8727f31df25586950241fbaff00fa8adb9fd465c796b642dd92346375d198c60a1b0be49006b490bcccf3eccc5c8ca5a9ae9dd30d0d04ff0065a7a0e9d1551e5c375220e9a8e8e705e36255b0c7e574c7f9b192a3b4ba69bcd19dff000b402c31450825b8fecb5c2cf471358e680a35d6389b0e07a2e9f0f56e2b61dcf95d1fd0d474b154f9b0b635366a3aa73dc305606ca7b2fd4c715b3b24ee98bb512ba9861a8e8e3665188ea5b24515602d6ec0a86c7b6191add216d2f341de90b802563eba3653d58d4a3242fa9a9a9bb0271812057b61ea2aa8a56c21c74f0b094f5731a80d04e85abb4bc6a6edbae577fd446fcbd82cb706e963dcfdcab8aabe3dce033b2f37a3ab9a3730e70d579f5c658c60eeb992784bd02d7706c8df31cab0c364c90b0766b898c86c8e5b1b755c52309d5e893d090c9bb796e5653adeda6ba824686723d94facaf74559907c80eeadaa2b6dd556c25ee6ead3baad1f23756f449a29e4aa2cc6e4f0b51e034867bc0873c3b0b53e2b4d42cb6c822d39c1e1647f87805dd44f73771a9363eadab618a9e363b83850c5210e2583953ae32075282ee42758f13e758561e55e315b84d6790bf9c2f98ac70e8ea689b9d203fff002beaef1d0f62d3268f65f1dd65c9f4973eec07ce1d9523ed6e9cafa78ed34b1999a32d1eab4c29e89d465e676e4ffee5f17c1e2adda9a95804872c1ee9d1f8e97d70ed771d8f9503ec4b94b43476a964152dce3fd4be44f146bbeaefc5ed390d772abee7e305f6a69fb5dd7693ceeb2d5bd446e6d2f95d9939283e8df066fae929a2843b7c01caf6a6c739c3f0775f2f7807776c9738e32edb505f6353411494f1b801f6a0f3deb7a38aaedf897ee54bd176f8627803030b4bd674324c5c22ce3f0a97a4e8668a721e08dfd506c260d681a7d956f54bb1d3f36ae341561334b5c02a8ebe94c3d2b3387fa107c55e20cad8fa89e5a7fad7b2f80f729086b41f65e13d65377ef4f39df5af6cf00a091cf660641c20fa9ad5339d082558b5d950adccd14e011beca635b8dd038a42c12370504e139846020f9cff00888905353c918db20af99236b5903ddeb95f4c7f1214b2bc39c01d385f30d54823a77373be7083d57c08b7beaef31bc03cafb3e89869e858d3e802f97ff868b7c7248c95c0657d4cf2d3e41c00102c2ed6e0bcff00ab2ebf457a6c61d8dd7a031f1c44127d1787f889741ff15b181dfd483d4ad358fa8a661cecaf03fb7134959ee926896dac71f657931d41adf441e2de3cc22ae85e7ff695f235ea9c4303f1feb5f63f8d3069b548fc640695f1c7505435fad8d3fd683ea9fe188eab345f0bdfa576890af00fe18416d9a2f85f40c8dd521ca019261a5d9c602f9d3c7882a2bea3f69a5dbfa05f44b999180b2f76e8c82f157aa6602de774186f06283e9ec6dee8d2fc7042f47b6e595673c2870f4e32ce34530c347b258e595b2630414161d63a4d8663b13a4af8ceeac7cbd6e47a7717d3bd79d4cdb5d8a713bf0749e57cb74f7365c7a85d52cc1fdc41f56f8792b45aa288ff00a42dceafdaf27a05e75e19b5f2d0c6f76434b7d57a3b5a1836e30832f76b28b9540965",
            "1920a9b6883e8dc1ad6e00570f85ae3c256c0c6ee1074243f74d270404004141009082b7aa3ff439bfe92be0df147ffa9ddffe4ffcafbcbaa3ff00439bfe92be0df143ff00a9ddff005ffe507b7ff0f3f7b3e17d2f37ff002cef85f347f0f3f7c7f0be979fff009670fc20cac603ab5d9e32b27e26f4e36eb43a18cc9f85b18e99fdc7bf07948fa5755b30f6928321e18f4efe9344185b82b6923e6a591c7fa4aef69b6b627603700289d5d726d152b8307980f45131f3b45be1220a9a69237195cd0ec1e4af93bc7dbb3e5ea234b11cb09f45e8372eb8aba7ab2c25cd6eebc7bacae315d7a91b24a411f956e3cbe3929f74b0ce968c40df3797d574ea7bfc9030c6c767fba895d54ca46e603e9e8b3f354495afcc9feeba5fcbf8c78f1ebff7db9fd41973249c9dd4fb6d39adfb5b90aa2b47974479cf1b2f47f0dac8c9a943a669cfe5573ecfd49a7ba63a73b5d8de037c87fc2d9dae87b7169733fd95fdb6cf4ad7e92d036563f414ec7e1bc2e7e5ed765cdb5af270dff65c2a6de638ce1ab64fa2823231be573aca185d01206ea111e61718640c2002b30593433171c8c15e9f71b602c779563ee340ecb806216a2dbea3ea0805cadf3131bbb82cbc2c9e8dcedb095f5b33f6c9473f9fad73cf6d27ec4e70e70d94a8eff253bd90b1fe51b72b1df513b3704a7b279bb8d77e51eee29f0c74f5cb6f503c1638bffdd68ee3d51f556a31193271eebc860b948d8dbbf0bbbef3306603d068048c8a432388e72b79e1ddc43aa465de5caf2192e2e7c3973b0afba4baaa3b73fccf030a654efcbda7c45a3a2aab05ce7c34c8ca395c3e430af9b0b97b0d7f54d3ddba6ee63ba0b9d4928033cf90af1a2e5688c9920d557504b657e067cc55b86ab3e9ee9575d6a897b7cae390ba58f04e5f15cee5e6fa719b86df3d59063070bd0ba63a5a27d2772767982eafb0476a7e92d0af686e51535298c01c2b7fe7cfdb9fc9cbf253c94c29652d8c6021da5e7f7067d92d44fdd9c91c2638655f8fa530cbe4ca528e7f0a1dd20efc7a58375301f2e114e03a4c397bb4dfad7fba9a887d100245acb25432669ed9192167af74a64188c6ff008537a3a9e6a79c7709c2977f0be1b28683bb03cbdb938d979a7525ae58ee45e410ccaf6c8044d840d2370b0fd736f63dae730007945b6f3f823777869e16aadb88c349e56420aafa69cb1c77055e47766b5838d9727bfe86cdf736b58d682a65b2f71c730ee9d979f3af81ee032bb475cfa820464ae67e07aa1bac323c3a2380b416bba1645f71e1791d0d7c9086b5c4e56c2d972260ce4f0a20dcbab219a9e4d5f7636593bcdd65a4a5786bc80a1bfa91b4ef2d27fdd67ba9aea6ba27361772148c8f575d26ad89ec73c9e5687f87184477b7970db2bceaf5512d139c66271f95bffe1eeeb1d4de0b19ce507d45758249dec117db9195616b80c046d8d9358cede8d7eb8529d33209f07641e5fe3ab01b4ca7ff006af87ee065375958cc9717e000bedff1ba712daa503d5abe3eb5d130755c7de6ea6ba4ff00ca0aa93a7ef0630fecc8e691e8b98e9dba01914f202bedfe93f0e6d175b2d348ea661d4d1fd2ad65f092cad69029a3ff00f5503e0dff0087eee5b9741201f9516a6d7534a097b48f75f75752785d6aa2b4be465333207fa57cbfd7b434f49552c6c601824615837c1091d4d798f7c65c17dc76194cb6f89c4e7cabe0af0f6a9d457d8b1b02e0bedee8aba092cd0b9dfe95225d6d13a79cb9c32d51a4b60886b85b82b41148c99b90014fd2cd0e6e91baa8cac6e7c9268772a97c49a8652f4c4cc93d5856b9d45d99ccb8d979a78d1756b2c9237ff6a0f8ebaa69a492ef24b18cb5cedbfcafa4ff0086aa563610676ef85f3cd5d7c75958226e325f85f53f81967fa5b6326231e5083db5859a8e91b2e8e76db2834750d7977e175757358ec10824024f2129ce5b85185c98e380d5d8d46966ad283cb7c73b7c1596099fa019034e0af87ab29e735d24273f7afbe3c46a7171b0d4edc34af892f748692fefd5b0ee20f7ff00e1aa965a7958d7f185f4c6cd321fc2f9f3c0401ba2418e17d051bbbbabe1055c92485af25d8c670be7bebfab7b3a",
            "b18e73b87afa22aa865998f0c38d978c759f879595f77fa819d8e507aaf41d74151618c0235690aeeadfdb030b0bd19413da29591c8e230b693d632ae36b1b8d4020c2f8a54acade9ba8d582ed057c2f7ea59296e3335dc6b385f7f757f4fd456d8a7d39c1695f11f88560a8a2bbbda472f2107d2bfc34399fa34607fa57bdbdfaa4385e0ffc35d21a7b3c7af9d2bddc0fdc7140f6839512a2e31534fdb7bc0454567681c1df0bc4bc59ebb96c41f231e4387e507b6baf56fce1f331677ab3ae6c3628049de8f5af91eb3c61bb5446e7c733c6feeb3174bfdf3aa9e186a24c1ffdc83d97c4bf11687a8e9248a1946e3d0af21e9263bf5b6ef98cbd5457d8ebadf1832543b7f425683a2e3d32c6e76e757283ebfe8f0c8fa729cd38c3b485b5a22e753b4bf9c2c2f403fb961847e16ea93ec0107679d2d257035f0c4c25e775d2a73d8763958fbec9353d1be4c941ac8ee54f38c35c32ba472b1ced8af2de9dbccf3d516171233eebd0adb1c84ea71280ea9ffd0e63ff00b4af83bc4edfa9dfff00e45f78f557fe8737fd257c1de26fff0053bfff00c883dbff0087bfe646be9770d4c03d30be68fe1ef7919f0be960761f01073732081a5ce031eaa07ead6f6cda4b9ad0a55c5864a7706fb15e0de2b750d5f4c523ea63739b83e8507be99e9db1f72178703eca04b6a82e79ef8c82bc77c15ebfa9eae88472bcbb1ee57b20ad1472163bd10798788be1d31f4d24d44cc1009d82f95fa9ed7576fbc3c4d9041f55f7c55d553d750c9110dc969f45f24f8dd65fa3ae96460c1283c926b9bbbdda2ecaecd98359f92a8e3864155addbf9b95a5a4b44b5ec6b98d2709b349560b0c95954257b4b9995ee1d2741454d4ec635803b0b17d1d4cca3884733012b796a6b44e0b4001362e1d1318ecb460a03473ea9d27de902006e374633b1e10d499dd047aba663d9c2cddd2d8cd2486eeb5e70e0a2d551b656e00e507955ca85c03b6543d97c6f3a97a7ddacd8076e5636becee0f3838419f92aa388f9c843252f1a9bc2acbeda2774a34cb800a9f46f1052063b7701ca0ecc9ea33ca513d46bdceca2fea91b09c9098dbc44f7632104d3354c8ed21c74a43df69f23882a2baecc61d937f5966794b362f286e9590c460321d2f1a5c33e8765d4b954535577e46381db2159972be33515aa0017a3dae68ed16ba3a83b1740c77f9685e7402f4da3b7c773b2d0c721c014f1fff00e42edf5e79ae376bcc88771ae6dc06b69ce5408dafc6fc29b5b42ca03a18721476cbb60af5ea3c348d31838cee94601dd4f8ecac920fa8f5e5429835afd00a22b994832d390967218004070d28f475bee3da04b9ca6535c5b4b5ac60db75d606020e0855f5940ffac648d3c147d071d963d9ec94925c28192b5b918e551f52d9c4cc7b4f2ac7a46f534140c80608c615f4d6d8aaa9ccb27dc7745afb7825774998ea5d26f8caaea8b7f683834e70bd99f6aa6a9a8744f1b670b39d61d2d4b6c8b5c393a9727bfea0f2b89a35386775674154da4702774e9edb1d3c6e97d5408c367692d3b85ccfc0b6a8bcf98380d95a51754b6283048e3dd651d0b9c3494368de5b8ca882eeaafa6a243a5c9b4b74d73e82725533695f0838394341a506a33e60a442ebcd52b1c0371b2d2ff0d0c78ea52e1c170588bfdddd58c76ae405b0fe1e2b5f4d7ec8d86a41f69561719a9c631c2e37b0f654b71b6ca34b7092a5b0c8dc12dc2755554952e0e7f2020f38f179c7f47793ce17cc16d8d927524247224ffcafa9bc5da2967b0bdcc692e23d17cf3d2bd2b3cf7b6cae63b21d9ff741f5df87d5862e9c83f0d1ff0065662f80cc5a5deaaabc3ea678b4b609360001babb92c116b2f0467941c2ff00718ea2d72b0609d2be23f16eb0d35f26f62e2bebdeaa3250534da1c385f1578ad56fa8becbdcff00514d8a8e9dbc98af54c718cb82fb73c3ca87d4f4e44ec7f4af84ac4f81b7285f207795c0afb77c23b9b2b3a7236c60ecd51b1e916bd4d8402a6bdda08fca896fcf6c0214b70d4548e55f2b62a17bfd402be76f19ae4f7d9672479704657d155d4a26b74b920794af90bc77bdd55319681b8311241c20f2be83b0cb7fbe8d00",
            "b807e57d9dd03471da6d6d81e74b8346cbe5df06e565055891adcb895f58f47d18ba3048fdb2020d3da21d42473770553f515c1d40d7380e15c4930b4ca2069d8ac57895717d25b9d2b71c65073b3f574b51581858300adbcb7312528cb71b2f99ba33aceaeafa87b03046ac2fa228c77a922ee7f500823dca16dc2d73c6372e695f217893d3bf497d70dc12fce17daf556f8a8e84bd9be5abe74f136c5055579ab734ea0e41a5f02e81d1503091be95ec74b728e9e77324760e179af846638281ba460e30bd14da63a997bae38ca0b8a7a86ccd2f1b8559553415153dbd20b959d152f699db69db0b2fd4f336cb377db237567dd05acd66738794632960b73a886b7f0a158faafebe9f2f2d270a6c55d2d6c8e8de30cf4405cef317e972c6064e9217c63e2c5530f519696ec5ebed0aab3d332864738ee415f2678c36183f5833b790f41eb3e04c83f4d8c33d97b586bb4389f65e33e08d2fd2d963987b2f63a79ccf0bf3e8d414b5336b94b33eebe6ef1fa2226734f057d1f86be77bbd4657ce9fc4039cf95e7d020f0ca5823d04000ab1b34861a9f2b382aba93cac2efca950553a99da9bca0b9bb524d742ddc8c7a2976184d14d1c4e1bea5462fd3c7e6c70ae6c154fb8d5324237d4107d5fe1de5961849e3016fe94e6307f0bcf7c35799ecf142ef40bd16360821f80809cbc40f2d6e46179bf5cdf4d35be466375b5a9ba4dd991b10c8c15e1de2a5dea61a77e08dca0b5e81abfabaad6edb75ec76daa6b8681ecbca7c0eb6b6e946279b9c657aeb6df1d24e749f4410faabff439bfe92be0ef137ffa9dff00fe45f787557fe8737fd257c1de296a67523dc3fd683dbff87cda467c2fa5c0040c7385f347f0f2e188dcee485f4abff6e032b7d9072ac73a38c82de42f9d3f888d26c52170c0caf747dde4a894c6780bc4fc7ea515567746782829bf85e8d91b03dbea57d137a634b891b1c2f05fe1dad868a99ba38caf7bb93e22cf31df082ba923739c3076c2f03fe2158d898f785f4150cb1ea2d1ecbe7afe230b835edfe9c20f0bb25245727019df52f4db1db61b652ea900dc2f2fe89786d790738caf5b259531318320101074b7cac92725bb0cad8da1cc74cdd25535a2c9182d03fa969e9ed71d0b8169dd04c93ef4d082751c94204ce1272948c941d86c801909c0e1c0a4667fa92b883b041c2be1152360a8aa3a6dd544ec405a209ed90b460041e6376e8a0f95d9791854153638e9c399ab85ec33d0b2a1c49f555157d274b2c7248e3b8dd0786dc2da2373b0e38552d8344db397a45dec94ec32020ed9591aab74318748dce420a9734e794c92271e0a0bcba52d0360ba46fd448f655b97e1316368a91149146e3b9701feeb484ac652eafd429fdbbacffb85af2e5be3e95aac0bd46c996daa889fff00a23fff00c85e5cbd52ca6192d142dee80453c7919ffda176f83dd717b32d934afbc381955639ba9e31eead2f10927c9e6c2ac8a3943f7695e8782cb3db534af632d85a48ce165276bdb58e7107492a57d5ce1c23c1d2ad8d3406943df80ec21a5390c7e35289592b236f95c9d719d91e431c3659d9aa269642064852be36e376932dd6688f94a5374a899a0876e141ed48e760b4a7343a1d8ec8e875b9edba6afa6ba9aaa2a9642f90f202f6eb3096b2da1ee39042f97e3aa961b9c4e6e7190be96e84b8c75163631cf1ab1ee95d7fc6dd85ba364dacb77ca87d576c82aa91b86e55fccc6b6207951a783eaa1d38cae4f7fd0f0eea4a2653c6e686fbaf3eaeac7d046f731ae5ed7d696e653876b680b082d349521ddc6021733f03cf63ea1a87b75687aea3a8e703ec72ddff00c3b6d030236ff84dff0087ade7ff00b4dff0a20c1bfa8ea09c6872537992666820e0adf8e95a1918408464f1b2e0fe80d6c2e6478feca479fc94e27692472aeba22f2de98ae3283a77cabeaae85a8869f21a7fc2cd5d3a7aa29637bb49ce107d57e17756ff00c530b7f7738c2dbd6f760aa68c12d2be4ff067aa26b1d7864b398d9abd4afac2c9d4964ba5332596b23d58ff0052065c21a6bc539a69980edeaa9adde1fd0534ce96263015a171b74b505f054b083ec51a7b4e2e6cc08f",
            "c1411a37cd6c3db878fc2b9a7b93994ce926763033ba8304f40f77efd4b5a7f2564fc43ea3a3b6d04829ab1b9d3e8e52311e2c788aea27cd1c72fb8d97cc571ac3d4f7f6093387bf73fdd5ff0059ddaaef170934b9d234b952d1d21a6a98e4d058e041caa51eebd2fe045b2bed50d5318d2fc02bddbc38e94a7b05b4d3e002360bcd7c22ea78df40c86a2a9ad0001b95e893f52d052c81acae66e7fd4a9b1b36b5b09c0e17460d6e183caa6a7ea1b4be8753aba3d78ff52a4adeb0a280bbb758d38f672d2093e215d6aacd6699d0cd83a4af8c3ac6e95977b94afab935c7a97b178abd7d2d6514b0c3505db103057cff006c7cf5f7074754e2185dc9523d3bc2ab3455154c7471f972beace8fa78a8a9437182005e1fe13d35a684b03ea231b7baf587f51db29dc5b1d6b38ff520bcbbc4ea8ab0f6ef85e53e355d1f4d677b32410d5e9966be5aea0932d747ff00ec178aff0010b71a39e964652d4071c1e0a0f22f092b65a8eacf349b7717d954b03be8a0773b05f03f8795b35bba9a3903cb407798ff0075f72f48f53db6a6cf077eada1c1a39720d5d748c34018e1e985e7d79e8b8ef7abc99c9cada4975b454f97eba303fea5d23b859a91b9fae8bffd820cbd93a6dbd3b4c1a1a42d55a6a1b50370570acbc59276e0d7c5ff00ec1253deac348cc36be2c9ff00dc1077bdd54f454324b0920b415f25f8a7e265f5978753899c1bab1cafa7ba87a8ed42d9286d631d969fea5f1ff8930c370bd3a48a4c8d5c8283d7fc16ba575e583bf293b6772bd9e827d154622d3b7aaf9cbc22ab75ae58b351a5a480775f4bb2e163651c539ad883cb412750ca0b49e36494fa1fc10be6ff001ced90d1933340fbb2bdd2b2fd6ea8731b05730ede8e5e27e37082aa94e2a03b27dd06b3c1491b374db370365eb14803217e37f2af11f07fb14f61635d56198fcaf5bb2dd2de1af6c95cc3b7ab904590fee49a187d57ce3e3c0975bc9070be9e8eedd3f087e6ba1277e5cbe6cf1fee16faa323696763cfb0283c1e9f1da38f74f2994c08848230729e5023db9616fa95a6e8d676646173bfa966bd429f6caa747511b44981a907d7fe1817ba8e37019185e9334ad30918f45e7de0ed4dbdbd3b13a7a9607e91cb96da4b9da8b9c3eb598ffa820a5bd3a682d751343918057cbdd71d4f535d58fa695c71af0be84eb9eb6b6db2db353c552d90b9a782be45eb2bf46fba3a461d8bf3941f5078332c9436663d809d97a7d15d7eaaa0b5ed395e45e02f525be4b3319532b46dea57ac36e9648ea750aa8dbfff00d040bd5809b1cd8ceed2be11f14e391bd40f24edad7db1d6fd596a82cb2b63aa638e93fd4be20f10ab7f51bf38b1d96eb41ee9fc3bb9bdb8c3812be959256fd2bdb8fe95f39ff0ef516da2633eaea18c38f52bdfea6f766ed498ae8f8f4704143160d5bb1f95e53e39b1c6dc70765e8afbf5ae196470ab67aff52f23f186f94d71a17321a86bbe0a0b6f00a4029830b872bde3f4f8aa039cfdf65f26f845d43fa64c18e9f48cfbafa5ba6ba8a8aaa1265ac6ee3d5c824982282a30c0bc3bf881b689e91ef2470bd8ae57ab6433122b184eff00d4bc2fc75b90aab7bdd04fab6f4283c8fa16c7049524e46752f57a4b2471b981cdf65e2be1c57557eb4d8f24b4bb75f493a8dbf470cd919c040d8685b4a18e014a738bce505ddc8da3d826b4691840a8421021e13a2dcf992632532a9c628896a0eb348cfb5a775cdad3caa6a6b817d4e971f5578656160c1dd0221084021ad6c8d731c39421c006e4728292e1d27155c721c0c958abdf45fd2d3bdfa765e9f1543c823d144ea1844d6a76c33841f3d5c281b4a490dceeaac3c46fcb9a4657a31b63659dc1f1ea19f654bd4b698e9a3d4d8b1fd97a3831c72cb5466a9646c95b0168ff00ee37feeb504acb5bf7aa8b6c61edff00bad312bd5dae398eb49a8415ed9ab9ce2c8ccc406803195421458ab853d43fcd8f31ff00baf7f0fbaf0f0e332dedead6c9e097cb2b8153658a898ffb82c658aa0d447a838aef555989749795e872bb1a9958d5cd15118b535c323759bb9dd461d131fc2e325706c47f737c2a07b9cf99ee27628f3c3259a799",
            "ee0d25ca6daa95c640256ae36d70fa8c633babf11e990380c22e0c14b0bbf7301545d040e77ec90549bac324e76242ab16fa86ee3251ebea63fdb6e12300918ec6e17a6742dcaa3c918710d5e7b1d04ef702f6ec16cfa36ef474156c8ea1cd1bfaa3bb77a7b4425eea4693beca5db1d1eac48a1d1dc29ea691a69c82d212b400f07385c9effa463e7db2de26db8cf1b9d08c8fc2f2b8a37441cc71c15ee7d434ee9e88e91ab65e3578a3962aa71231bae67e11b4331bb19c94e871a802e47730dc14d6b038e42817749d912301785b1a6146690004172f342f732a18d0e39cad55b8bd81a5ce296a57f5f04468b666565abad54d5f198f48d4b4d355b0d269277c2a0d6c8652fcfaab59a89925f6f33ea5e98a9b607cb4b96bbd30aaecf77ea78212c64f28c1f72bd3eef55154b0b4b412a9e9da2005cd89bfe15653c196aebabddb69877e690b87b92a69f1d6aa923746f91c5dc72bb41d3f25e232f118dff0a86b3c2d92a2a1ced2765196731f69c71b97a41adf162f171a93da95ed04edba8173b95faf0d0d32c8ecfa64abc8fc3ea8a695a445b34fb2bea0b3be9a56e621b7e157eb617f2bfd0e4fd293a4ba51c63325747bf3baa1eb5a0928a7718223a41f40bd658c73c76c374fc28575e99757346b6672b2cf9b19e8fa1c9fa793f4f57de58cfd8748df8563515dd44e764cf2e7e4adb37a62a2d833143907f0aded7d3efaaf3cb08cfc2f1f276f5e8fa1c9fa79c455bd59da244d369f92a34375ea48e47895f29cfbe57afcb40e88f6840dd3f0bad35829a776658980fc2f671f631b8cb59d9abaaf21b75beeb74aaff9963cb09f553fa9fa326a4b699e963224c7202f6882cd434ed1a6368f851ee74b0cb01883010b4fab8ef50fcbe76b349d4942d25af946ff0095622e9d421e4cb3c833f92bd26e746ca288910b7fc2c7deea8ec446d1fd9696a3f2ae8aedd4ac617c3512e07e4aa3badcaf17190b6b1ef70fcadcd96b1c698b7b4d231eca05ca87ea1e5cd8c02a4608524d44fef44d391be54a83adfa859332086691ad071b12b50cb639c3416256d8453bbb8226e7e10707f53f51b2363c554b9f5f3140eadea399d87554b8ff00a8a96f6cef186c430171ec54839110ff00082aae9d45d5007ed554c7e1c5559ea0eae25a7ea67ff256b432a40de10523a6929f77c2dff082be9ba87a86689b0cb3c849db92ba4962bad447df7b5eef5caee2b7354d2d8dbcfb2f52e9da596e16c03b208c7b20f2986a6ef41186c0c7ea1eca3dc2f3d5a2171654cfc7db92bd920e9c6b263aa269f90bb1e978aa096c703493f841e0f64eb9ea6a0a9ff989e6207fa894fea3ea9bddf480d2f7356c3aff00a3eb2db1be58a9b4faec1637a7ab2a2191cc9e21b6db849e4438baeba8acf4e2962748cff2af2cde20dedf4ef33d5c8d711fea2a2dde27cd2992385a47c2a79320f9da1aad71d09155d5dd466b496574a584ff00a8a8f55595b5d389aaaa1cf1ea094f1511b19bb5a7f2a156d7c5da2d672ab077355117e96909e78caa1a205f51a893cabf76ec68501a784ced168d61c41ce538e709ac25c403c291a7a1eb5bedbeded8692590003d0ae91f5d752ba27974f2e71ee543a0ae86085ad2d693f9568e69969cbe389bb8f40832d2f53dfaae57b6a6491cd3ee4aaeb953baa60d59cc9cab9a88ab1c5f887007e1436d2c832e78dfd905af48f5056d96974099cc23f29d7bf116fcd79ecd4c98fc12a97ba7b85b8c249278d9b3834fca0971f5bdf6b6231d44f2381db725456c26a5c6494f9b9dd2b26888f2b5a123deef453402f378b5bffe4657b40f62ba8f10faa70586a653fdcae6caa9631b301f94f64f924ba36ff855d848fad3a8a46b819a424fe4a6feab74ac6e9ab91d8fc94f154d8dd90c6ff84d9ab1d39c6903e02db0e2cb204773aab679e079cabbb578837c6f9239a419f625523b408f2e0a6f4dc627ab6b43011954cb1f8dd516f25ffa9aa6a049dd94b73ee53eb2a6eb73688a70f734ec72b774b6994d202d8071ecb83282613e97c400caa881d0fd210d34cd9dec0d3ce70bd4dd2c462645af66e3d56569a3753b401b2eddd937c39069df2c0c68d2f057235717ab96",
            "6993cdab7714e91f213f7141a3fab88ff525355101f72ccb64783f715d4c8f2de4a0d00ab888d9c99354c4f84b49dcacfb5ef8ff00a8a432bcfa9403e22ca92f6f0a7d3d59d4d0e2abcbde520d60e506a5f53106b70471ba4fa98bfd4b33de97dd1de97fd4834df53163ee4c8ea6124ea7801673bd2fba691338e75141a813d3358ec3c6571aa961a8a57465c3256734cdfea29cdefe792815b6ea7a57991d8dcacef58329a68b0cc2b4ba3a60cc1242c97505418220e7397a3ab3fb8c9f6043591e063ce3feead495502ad9355c783fd63feead4af7f77de22285457069133c8ff51ffbabc0a96b1ffbd20ffdc7feebd9c5ede4ebfbad7749d6b63a52d71df09d5d3174c5c0acdd057ba9a3c85d997cee38e42d9e2e6eb5b95a9751707b5e1b92a583dc8411c959f7d577ea06cafe9633346c683847872c7e3e1d28c88260e2afd9718e5c06aabadb698210fcae568cbe7c1f7452785dbc770e5768cb18c396848e676d00891a4611ebe0e598d70fad8435cd38cacc5436692e4d313881abd14dba3cc32e028c096e2507708eaced4d69ed7d0b5af6dbe389ef24e30b6950eec42d79f65e3fd017b7cb2b233eebd86e8dd56b6bc7fa5727fc87a6bc39fca9915c62a8a6730e0ecbcbface564150e200c12b6b6485d51239b92a93ad3a604a35e4fbae6fe17bed87a6a3756b4b9a1739e07523b0e53e96a45a818b00e3dd44afaa15ae55fc0e4cd2f95b29f457b05d192696b7d15068318d1ee9d4cc34f26ac953a2b53dc7cc300955d79cd1425ee384da1bb7ef8663d537ad5c64b7ea69c642b55f8f0b95d338dba32771c9e1486d4b5f161beeb2740c90891c5c7957b648dd36c4faa4c5bceb65b7a9745968a41a80ce15c4858c95ce2d0564ecb5c68d8d8c2d2d3cc256ea70ce573fb7758d7b3afd7d5d94cb0989e4b1b959f9e506625a061681f037b12380597ada814dab65c69c993a3f1895452ffcce5dc2bb7d5c5380d8f04858c82e5dc790060abde9f6bbbc5cf3907dd5be769f18bf63a29a3d2f68ca68220d98000a2dd2ac519cb425a3a8fac8b56152cb4f8c492e63b770195ccf3b27067a148764f9651f3fd8ff00653817613a2d064f3ee17304929746375e8e0cedce3152756c0c923c44179e5e6d3318c1c2f55a9a1faa041596ea4a314ccc05dfc678194b4c0fa78b4b94bd81dc2485f8083fb854876969390025243869384818581309dd03f432377017473a203ed0b981a9b92983cc7083a38b0b7668557594eeaa3a40566408c2580b0871c0ca0ca4f4eea49da7f2bd87c3db934d0863b1c2f27bb4a0ce7e56c3a1eb5cc2d68e156d1e9333c19496e175b43fb7559771950812f39f70bbdbe370a81939cabcf22cbaaad705da88b4b1a491ecbc03aa2cecb45739ad686eebe8eab99b4f134168390bc87c42b436e152e7b76f851e879ccb5d0c3090ec6567aaa564f21231bab7bad85f182353954badfd90372abf3d88d511b4444e567e569754100faad33e85d50340246572674948c7894bc919ce15e415b454c58ece159171d82b48ac19664129adb192ff00b8aad10381929400e1b72bb57dbdd08c6a2a246eecb751df0a4778a86a25959827195e9961b6b0d131b2fb7aac2505dd91c40968d958c1d72f61edb000020dc55daa8e1a57ecdc90b0b738191ead202b26f524b5d0924aaaa897eab23dd0668bdbf52e1f951ae50b9e32ccabd758b2fee64fbae35746201ba0a5a38a46e35655902d0ddd3620d77012be229ec35d281c2487333b010221c2eb4cd14d26b559e0757db646b75905470d0d760ab59eec1f069d215438ea7172e975f971c7d8e859de7060f55b2e92b098e4649a7d965acf4bf5756d19f55ed9d376463289aef5c05e6ec6532cf70692d314668dad2064054d74021a83a5beaa5fd71a23a02875352daa7e4819580e32bcb22d4542a7b807cba14cac7814e46167229bb5524fe5069243800808692f6aaf37b68606168ca7c1565fb8e104d2c2935109cc76b6e535e3080fbb94a3091bb276c8103b0975a423251a4203746e9307dd183ee81cd05dfd94692eec85fa09190a4c4c3977c2cbd7c67eadfb9e505f7eb31fe128bd4637d966fb67dc",
            "a3b44ed9282e6e1716d5370d58deae39a7c2b59aabe87cc77599ea7b819e3c8d97aba9f78ced0c78aa8893fd63feeb46566ade1c6a6239feb1ff0075a52bdbddf707ffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003012200021101031101ffc4001500010100000000000000000000000000000007ffc40014100100000000000000000000000000000000ffc400160101010100000000000000000000000000000405ffc40014110100000000000000000000000000000000ffda000c03010002110311003f009900d540000000000000000000000000000000000000000000000fffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003012200021101031101ffc4001500010100000000000000000000000000000007ffc40014100100000000000000000000000000000000ffc4001501010100000000000000000000000000000004ffc40014110100000000000000000000000000000000ffda000c03010002110311003f008580b538000000000000000000000000000000000000000000003fffd9",
        }),
    },
    WhiteCat = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080300030003012200021101031101ffc4001d000100020105010000000000000000000000010208030406070905ffc4004a10000201030204030603050407070403010001020304110506071221310813411422515261913271b12333426281157292a1162434435382c117183644546373252637d27583a2d1ffc4001b01010002030101000000000000000000000001040203050607ffc400251101000202020203000105000000000000000102030411120521063141221423326171ffda000c03010002110311003f00ca9003692cb00473c7e68fdcd0a959b785d8d27d40de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c7e68fdc73c338e68e7f33e7d5a9c8b24dbcd3a4ee26f11826de408d5372689a1c39f55d674ed3e3f35d5cc292fff00d347c78f15b87d2788efadacff002d5a87ff00b98a1e26b8815f51d7de976ed79093cc8e8783953eb14faa03d2cb5e266c6beaca85a6f4db57155f6a74b53a1293fe8a4721856a7569aab4ea4274daca94649a7fd4f2f749d5eb68d7d4ef2d7a5483cf532fb807c77a5b968c348d57969d58622b2fb8190aaa41f69c7ee4f3c3e68fdcd9d4872627169c25db000de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc73c3e68fdcd980379cf0f9a3f71cf0f9a3f736600de73c3e68fdc7990f9e3f73664760379e6417f1c7ee4f990f9a3f7360d364ca5ca80df7990f9a3f723cda7f3c7ee7cf757a75ee5a9d27494abd79c634d75ebf0037fcf1c679963e393e46a3bcf6ce8f2e5d4b7168f632f85cded3a6fff00f52474d71a7c4158ed4a52b2d25c6b5cf5584fd4c52dd1c44d5f7657956bfe5eafb2f403d017c57e1f2efbef6aafcf56b7ff00f723fed5f87b8cff00a77b571fff002d6fff00ee79dbb7b6dea3baf508dad85194e72eed2e88ddeebd9ba8ed3a8a8df53945fd40f46349debb5f5f9f97a46e4d1b529afe1b4bda555fda3267d873847bca2bf3679d7c21e2057d95b828b8c734eacd26fe067de89aa52d7f44b7bda528b94e29bc01f63cc87cf1fb8f321f3c7ee6c53eebe04c56181bee787cd1fb8e787cd1fb9b3006f39e1f347ee39e1f347ee6cc01bce787cd1fb8538bed24ff00a9b32549c7b01bc6f0b26daad472785d8bd6a985846800000000000000000000000000047a9129728071552518fc5e0e11c61de10d9bb6ab79753967383c2f5ec739528d2b7a95e7d39136617788fe22d6d6b58969d4aab708369f503a77716bb73afea55aeee26e4e526d64eeaf0fbc27b3df54255efa9274d2eece95db7a2d6d7f59b6b0a3072752693c7a233f7845b1e3b2f6c51a74e318d494537d00c49e39f086b6c1d5a75ad693f6393e985d0eb7db",
            "faedd6ded4e8df5ad494254e49b4bd4f42b897b2ad77d68152dea4232ad18e174304b883c3bd4764ea5569d7a5254399f2bc7640665f0638b367be347a36d5ab47da23151ebdcecc74e549e24f397d19e706c1df17bb2757a7796f526a9a92728a667470bb89d63c43d1a94e135ed0a3d567ae40e6e0a3e6a4d424b0cab72cf4035411179448000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000043e88852c8162329bc0456325ccf3d0099be545629d4e98659539569a493e5f56718df7c45d236269d52a54b883aca2fdde65903eeeafabe9db72cea5d5f578454639c331538afe252fae6fae34ed1aac9514dacc7b1c138a7c6dd577add54a16d5ea52b6ce3a4bba3acade856beaca8d2a52ad5aa3f4eac0d5d5752bbd5aee5757752552a4de7abc9cef86dc1fd5b7cdd526e8ca36f95dd7a1cef847e1c2ff5bab4b51d561cb47a4b9648cb0dbbb6b4bda7630b5b1a14e338ac36901c4f871c1ad0f61d18579d0a4ebe3bb5ea707f123c3b86afa64f52b6a31e8b3eea3bceaaa95fa5479468eaba4d1d774aad635a29a71c2ca03cc992a96574d3cc674a7fe68cb5f0cbc4cadaad27a5dd5479a788a4d9d19c6bd8f2da5b92bb8c3969d49bc74369c1cdd2f6d6ebb797338c2a4d67a81e84d68f9724fd24c7736da66a14f5cd2adaea8be64e29bc7e46b47205f9bae092a922c0000000004ca5cddc8000000000000000000000000600111e868f59d5497c4d56f1d0853a56b4ea57acf118ace581c378c3bc28ed1db755f98a339c5aee6006e3d5aa6b5abdc5dcde79e6f0778f89be20c75abd7a6dbd6cc632c349fa1d17a1e975f57d4eded68c252739a4f0bb01905e18387b1d4abc755b8a39e5965368cb694a34f92941fbb158c1c1f833b5a3b636ad284a1c952714ff00c8e654a0f2e527d72055d59dbd5525d62df5385717b87565bef6f559d3a51f68845b4d47abe873a938ff00116a1883e5ef09774079a1b9b6edded9d56b585dd3943964d26d77472be10f11ae787fb8a8cdd47ecd292e659e864c71f38314372d854d474fa0bcf8c5cbdd5d726196afa3de68b7b3b3bca52a7520f1d57703d20da9bb34fdeba652bdb4a907371cb499f5a73f2fdc6ba9841c02e2bdc6d4d6e8d85dd77ecb3785ccfb19b56f7f6baae9f4efede7192a914fa3035a0bd4b14a4f99752e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000301815eac742515728fe1cf5013a9082efd4aca0a50f366d460bbb6c4e16f6aa55eeea42108f5f799d13c75e3cdae8967534ed12bc6759fbadc581cab8a1c72d236669b5adaceb42a5d61a58975c985dbbf7c6afbd351a97379713f2e4de21ccf091f2754d5af35dbda9757b5a552a4de7abce3f23ee6ced83adef0d4e85bdb59d5746535cd3c74480f97a1ed9d4f70ddc2d6c6d6a54e678e651e86587057c3ddb68f4a96a3ac5252a9852c4d1d83c2fe13691b2b49a352b5084aeb972f9976673d9d45522a315c914b18405233a367495ad953508c56172a14e2e3973796c461e5be9d4d4e92ea03ba2946b4a3539574cb2f9c3fa157159524074178abd92f50d2617d6d4db9a7ccda461fd29d4b1bb8cfac674a593d2ddd3a2d0dc9a15cd0af1526a2f97ec79edc48dbb5f6fee5baa53a728d3737cbd3ea065cf872dfd4759dbd1b4ad553a8924936770fe0975eccc0be02eecaba1eeeb6b6955e5a3524ba36679f98af6ca8d7a4d38b8672bf20252eb95d8b14a49aa6b3dcb80000000000000000000000000000000002b29a8772c567152596055fbdd51c778a1b8edb6e6d4af5aacd464e185f6393dac54a6d35d3062e789fdfea9d6a9a3426dfa613031bf736a73d675dbbbb94dc954a8f973f03bafc3470e6aeafaabd46ee8fece324e393a2b4bb49dfea342841372a935fa99fbc15da7fe8d6daa15a7149d4827d80e7f3a50b7b7a7468a4943a611a74dbf52ce5cd297e64e308089414bb89652c44900447137e5558a9536b0d331b3c4bf08e33b5a9ae69b6eb29733514649b5934351b1b5d76caa69d774e328",
            "4a38ea80f32694a542598f353af4df47ea647f878e374e85d4345d72bf343a460e4fb9c778f1c10b8daba856d534fa7fead3973349743a4ec2eab58de52b9a2e51a94a4a5d3bf4607a78ea539d08dd517cd4aa24d63e0215635566274ff0278d9a76efd2a8e9377250b8a3150f79f73b86746343ac3ac65d5300a49bc0cf5c15e91f78b269f5024000000000000000000000000000000000000000000000000000000000000000000000000000000043924f0490d2cf52925253e6cf40350acde115e6f31e17412a98f73196c0953e9f534afeead747b1a97f755142308e7a9b7d5353b5db3653d4afeaa84209be56cc51e35788e96e475b4ad1b9a145660e49f4035b8d9e216e6fee2b697a2d67149f2b92ec8c78bdbeb9d42bcabdd559d5a92796e4ca39d4b8aee4f33a937fd5b6773f08b807a96e6b9a3a8ea349c6d7a4b95a03e3707b845a86f4d4e957af6f28daa6bbaee8cd5da7b1745d99634e9dadbd3f3525978f5375b6b6be99b4b4e85ad8d1a709a493691f4392529394faa6024bda26a52e897a1a9ca974f4097c3b12042490c244802b2598e177262b11c324011473cdc92eb193c3463478a7d8f429d25a85bd249b5ccda3261749c65f06706e33edb5b8b6adc4e314dc20c0f3ff0044d467a4ea96f7906d3a734fa1e80f05b737fa4bb428d573e66a079f7aad8cf4ed42bdb4d61c26d1939e1677d42953a7a454a8fe18c81939193e7e5fa1a85aaa8f99cf1ecd15000000000000000000000000000000000051b7d9172d4712aa977407c8dddadd2db7b6ae2fe73519460f1d4f3eb899b9e7ba773dc5dca5ccb99a5d4c91f149bf1e974e5a352aa973c7184cc46a34a777731a714dcea4b0076a7003664b726e38559d3728424b1d0ce9a5463a7e9d46d60bf7714b074df870d88b41d1e9ea1569e1ce29e5a3ba6ae2a5493f402b16b192575ea31d3042f75e009c0c12008c156bae63d19734e79875407c9de5a050ddda2d6b0ad052938b4b28c11e2870df53d83add672a13f669cdf2cb97a23d0553714a4bbe4e2fc4bd97a7ef5db7731ad422ebc20f95e3ae70079fbb67725ded5d5e86a1675251c34e493ee8cf5e0ff10ad37eedca539558baf08aca72ea6046e9dbd77b7358b9b3baa33828cda8b6ba359396f07b89375b1f5ca31755ab59cd6567a2033fb128cb924b059fc11f3b6eee0b4dd5a252d42d2a425270cb499bea151c9625f880d55d80000000000000000000000000000000000000000000000000000000000000000000000000000019c010e39790faf40ffccae7a7d40a549a87487597c0dbeabade9db72c657ba8d6852e54da52782d77a869fa250ab79a857a74d259f79986de2178b971bab55969fa75c4a36b0934f91f7406b71e78e373baeee7a669959c6d9662dc5fa1d1d4e84ebd48d1a50955ad3784a3d596b7b7ad7756142da12ab5aa3ed159664b787fe01d69d7a5acebb6ee387cd18c974c01f3f81be1e2b6b52a5ab6b54dd3a69f328c91961636567a158c34fb3a6a118470b08d44a8d9d085ad9c153a7158f75608e47cab2f2fe204479a6f2de4d57d4851514465a60592c12000000000010cd3bcb78dfe975ad64b3cf16b06a91465c95a2bd18180bc76daf2dbfbaea3506a136fd0f93c24dc13d07775ad4527184e493ea64478a2d9aaeada7a8d3a4df2c73948c4ad3ee25677f46aae8e13407a67a15e4751d06deed34f9a09e4dd2794706e0aebb4f56d976b4f9d4a7182e9939d35cb2680000000000000000000000000000010490c03ec56b578d8d855bb9bc7245b2cbace31f89c238c9b996dbda973053e594e0f0061ff00880dc6f70ef5a9514f9a10cafea71fe186853d73755b53507284649b38eeafa854d4f50af73564e4e736d64c8df0bdb223773a7a8d5a69fae5a0327b6fd953d2f6d5b5b538a8f2d34b06f63d91355462d518768a217402d8180000000118cf7248e8056a2f77a114e0a6e3097e17dd17e65d8d3a89c7aa03a5fc41f08ad35fd2a5a869d6e957845b7cbf130bafec6be997752dae212a7569bc753d3a8c68dcc1db57846509ac34cc4df12dc1bafa75fcf5fd2e8e6df199a8a0367e1af8b55746d569e9",
            "1a95c3f677d1393f432fdd4a3714e37b42719d29c534d1e615b5dd7b2af1ad42a4a9d583ca68cbef0edc645b8ad29e83a8d57e6d38a8fbcfb81dfeaa2961a2dccbb14ad156efa65c5f661471d581779c92467a642790240000000000000c8c800320000000000000000000000000000000000000000000000119ea49003b15aa9bec5bba28aaaeab0056726a0dfaa23db6dec2d2a5e5e54842118e7de2f3952b5a13beb89f252a7172927f0312b8ff00c77afa86a35748d0ebca14a3eeca517d00f85c7be30ea3adee1b8d334db970b483c663ea74bd25737b5fca8a955ab51e3e2d9152b57bcb8e793954af51f7eedb326bc3df0329df53a7aceb141630a4949016f0fbc0a946a4359d6687c25152464fb54e8d08dbdad350a70e9eef422953b7b1a11b2b584634e092c22d18c69ae8bb815a7070e9dcd5455f55d098a697501824000000000000000694e4a3346a94a904d640e27c5dd2e9ea7b1eef9a1cd354de0f3cf56b6959ea55e8b58719b3d30d66d21a8e855eda694b9a0d1e7ef18343fec5ddb7108c796326c0ef5f0a7b9ea5d4fd86a54ca8ac60c99aebf6b2660bf86bd7e5a4ef2f2e536a1348ce85355ad635e2f3ce930292eb1e821dba88160000000000000000000000010de0092184f287402d4967f69e90eacc59f153bf617528e9b6f2c72fbad2664f5ddc2b2d22f2bc9a5c9093ebf91e78714f5ea9ae6edbc94a598d3a924bee071bd1b4f96aba950b48f7a9248cf8e086d5ff0046f6ad1e68a8cb933d8c4ae03ed17afeecb6b89a7e5d39fc0cf3a36f0b1b1a36d4961282404e79a7cc58a52872c4d4c0000000000212c3c924359021c72f28b77ee4258240a4e2b95b5d25e86d754d2ad772e935b4bbd8464a70c75593753865e447319f3ae8c0c11e3a70aea6c2d6ead5a31ff569cba6174ea705dabb8ee769eab4353b49bca7ef24ccf2e2e70d6db885a155a4d66b46394fd4c11de1b46f7686b15ac2f29cd42126a336bb819dbc23e2459710741a29d44ee2115959ea7349f353a8e325859e9f53cfbe13f126f760ebb46709bf679cd732cf45d4cf3dabb92d37a68f42fade51ce1396181f57bac129611a6e7caf0bb9a916daea0480000000000080449f2ac883e65902422a9b6f1d04a4e3d80b82aa59ee4e57c409055cbe01480b019000000010993900000000000000000000000060087d10c919ebd4039722ea4454692f3ea2c538f764f279cd2e9ca9f53abb8ddc56b3d9da157b2b7ab0f3ea45c7a3ea0708f10dc77a7a750a9a0e91579a5522e32707d8c48b9a952bd7955ab273a951f337dd9aba9ea371ab5f56bcb89caa54ab26f2de4ed5e0af05aeb7bea342f2f2138dac259c35d181cb3801c0696e07475cd529fec7f125246595bdad0d26d21a7d8c234e108a5d11a7a36956bb6748a3a5d94545538e3291b88aecdf56042a7caf3eacd5c649488c7501d112472f5c920000000000000000003eab00ae7a80a1efd49517d9c59871e28f428d8ebb3b858596663519b575cd8e98c18fde2a36ac2ff4f9dfa6d492c818b7b2358968bb86dae22daccd2ff33d0ed95a83d4f6bda56975cc23d4f35a9c9d1af092ef09a7f667a09c0ad55ea9b3ad612fe0a6bf4039f76c8e6e84c97bd25f06579700590217624000000000000000000000ab7e88d3c4b997e66a358ea4d2fda4bf260711e2f6b71d136a5c72cd4653835fe479e5ab57775a9dd5693cb9d593ff00332e3c526ee565a7ab48cda6fa60c45b4a52bdbfa74d2ccaad44bfcc0cb4f0a9b3e9cf46fed2a90c4975c99153a8a4d7d3a1d7fc03d1ff00b1b64d3a6e3cae493ff239df23e5cfa81aa8111fc2890000000000000000005739782c52a45f75dc07b4ab6961aca93c60e8ff00137c34a5ad685fda7a7d05e7c7de972a3bb7ca53fc7dd15b9b5b7d56d6a58dcc14a1358ea079895294e9549529c5c6a41b4d7d4c8df0cfc588e8f730d1b50afeece5cab999f3fc42f0527b66ee5abe994b3466dca5ca7445adf5c595dc2f2da6e9d5a6d34d303d3baaa35a10b8b6929425d728425cd1cb3a3fc38f1627ba34da7a5dfd6cd78fbbd59de55a3e4cd4565ac77000aa7d0b000000003ec055439e",
            "787d8e27af713f6fed6bdf66bfad0835df2ce636def5469fca60ff0089eaf5e9ef8a94e35271865f44c0ca2ffb74d9935ee5dd36ff00346e297193695459f6aa7f73cf285c5cc166356a2feacd68eb17f15857353ee07a27438a7b5ae1e21754fee8fa56dbcf41bac725cd2ebf53ce1a5b9755a2f30bca8bfa9f42df885b8edbf777f3407a390d674cadf82e293fea6bc254abf5a75a9fdcf3b2d78bbbb2da5ccb5093fa753efd97884dd76b8cdccde3ea067bfb2cfe78912a338aee9fe461359789edc54e6bcfad51c4ec7da9e2a6ce508abf93ce70f20646f3a5d1f72c99c3b6f71876d6bf6d0ab0af4e3297a368e616b5adf51a2ab5bd78ca32595802ddd111582ae8d484dacb6bf22c9fc50120000000000000000000043248600a54529c711ee4cdf2c1cbe05655e3656756f2b4b96318b7d40f8bbe776596cddbf5ee2e2ac2351c5e137ea600f1077a5eef0d76e6e2b5594a829be45f4c9ceb8fdc51bddcdb86e34ca15e6ada94f0f0fbfd0eabd134dabac6a76f614a2e52ad3517803ecf0ef68ddeefdc96b69428ca749545e634ba247a05b336a596ced0e85ad2a4a33e5ead1c3782fc20d3b61e8f4aeebd283b9aa94b2d754d9d9b51badf8bb2ec069a8f4e6ee5a09a7964c5616086a4df4ec05c05d8000000000000000000000021aea4802afdd7cc75f71cf435a96d1ab530de2276055fddb3e4efab657bb52e69b59f73fe8079bbaad0f65d46b53c7e1999a3e17b598dee83ecfccb3082461fef6b7f66dcd7b4b18c4d9dff00e1335d742bd4b79c9f578c0195551e2b4ff319eb826b4713e7f99e486bde0240000000000000000000030437800de16596a338d0a55ab49e125934abbcd2e87ccddf78b4bdb57159cb97307d7fa01871e24b72c758dc53b784b2a9cdf4c9c0786ba3cf58dd5674d479a31a89b36fbfefdea1ba2f6af3f32e778fb9d93e1a74695e6e0f6874dc9466b0f006656d9b25a4e856d41471ee2fd0dec1bf5356a351a3462ba611a69e7a017c0213f4240000000000000000015cf52c00aca2fd0af2f23535dd1a81acac01f337068969bbf47ad61770849c934b28c0fe32f0f2a6c0dc13a118628d59369a5d0f4069c7c99f3ae875b71a78576fbfb45ab734e3cd7318bc74ea0617f0f77c57d8facd2bda2e5caa49c92667970e388163bfb6fd1b8a5522ee1c3de8e7ae4f3e772edabcdb1a9d4b1bda728b8bc26d60ec1e00711eaeccdcd4e95c576ad67d145be880ceb79a72e47dd12a468e9fa85bebb614efed651946714fa33594567f202c0a75e6e9d8b8000017b55fb67fdd308fc54c7977d4f1db266ddb3fdbb5fca616f8ada2e1bcea4b1ea075b70db6c7fa5baec74f72e8daee647d4f0976f5ad69ce15a9a9b49b4740f056f7d8779d09f372e70bfccf412debce7a45bd58cde6508f5031babf84658f72ac73f43e45df848ba59e4a9f632ad57a9eb364f9f3f99818835bc26ea71eb1ad23e06b3e1a75bd320e71752697c119bbe7b5df2ffa13cf42ac796ad2524fe280f38b56e1beb9a64da76956497f29c76e74dbcb3962bdbd5a6d7c627a5b77b6b44bd6dd4b2a797fca8e1bb9b817a0ee08c9c28d3a6daf48a0302ac75dd4b4d9c656d77569f2fa29743b4f687888d6b6f4614ebd4ab523158ee733ddfe166e28dc54a96129e3d1451d45b8b847b8f41a93e6b3ab3845f7e50325f64f8a2d3b57a90a1769424f09b91dd7a46bba66bf6f1af6d7506e5e8a48f332a52b9d3eb6271a946a45fe4ce71b2f8bdae6d5af4ffd62a54a69ae8e407a1128ce2fa41b8fc48524fd7a9d2fc3cf125a4eb74295a6a12853aad632e476f5857b0d5682bab1b88d4e659e9203760d1e69a7cb3582f002f9239967044a3f02397a640b82b1658006f0086b204e7a11278590d7428d737babd40bd15e74f0ff00063ab3a33c43718a96dab1a9a3594f3564b97dd676bef6d7e96d5dad737539a8d45078ebd4f3eb7e6e7adba771dc5e56a8e70e7697503e25f5dd4d42f277336dd5ab26dfe6648f875e0bcebd4a5aeea14d7a4a3ccbb1d57c18e1bdc6fadc94a12a52f66a6d36dae8ccf1d0746a3b7748a5a7508a8f9714ba2037d51f3528d28a58a785f6223f",
            "8498a5d70481544f624000000000000000000000000002b8792c32052afe136fabd3f69d1ee292597c8cdcc9649e4e6a15d633ee303ce6e29dbbb6deba841afe3ffa9cf3c366ab0b2dc2a94a58e79a3e071e34f76bbdaeeaf2e14a6cd8706ee5dbef3b4f7b09ce3fa81e8754ff0067a327ea9151cdcf616cd7ac62ff00c8ab7e805810bb1200000000000000000086b2480342b3e9cbf538771caf3d87625797361b58ff00239ac69f99519d2be28b5e95a6d895ba9e16318030bafe6ebea15a6de5cea3fd4cb9f0afb615be9f2ba9c319eb93112db35af6967f8ea47fcd9e82f0434a869bb52de4a1cbcf04073aab2e6a98f44caa8e2459accdbfa893e5018ea4909e4900000000000000000000000002b5165608b693a53e59f5834591a751b97ba063ef89ae16ad52cea6b3a750fda457335146224a356d2bb8c94a9d5a72ebe8d33d3aad656da95ad4b3bc84674e51c7bc61bf885e0fcf6a6a35b58b4a4fd9ea4b388f603977874e34a8f97a2ea95926928c799993f271a94e35a8c94a153aac1e62e9ba8d7d2af695ddb4dc2a539292c333a380dc4fa1bc343a5695ebc7cf8249293ea0769c7dd7ca58895374a589bcb6fa324000009b77feb4ff00ba624f8b6d3a4b5a95d28f4cf732d294b96ebfa18f9e2bb4c8d4d1a773c9978ee062cecabf7a7ee2b4aa9e3df4bfccf457695ec752dab655134df971c9e695ad4746e69548bc38cd3ff33d01e04ea13d4768d0e7a9cdcb04073f4fd3e04a2abf7935f065d010d0ecba12465014c7c5b25c9c57bb27f726493114901a94eb7b9efc399fd4d9ea1a4699acd3746ead69fbdeb846e3de72fa112a7197e60746f13bc3969daa51a973a7535e63cb492319374709b736dbaf514ec2ace82ed24bd0f43a32943ba4d7d4db6a3a2e97ae5b4a8dddb526a4b1d80f32632af637194e74aac1fe4d1db1c2ee3a6afb5afa950beb873b6ed96ced3e2ef86a85c79da8e8949297e2c44c61d776fea3b7eee76b7f4274e5178cb5d181e836cee29edcde3694bcabaa5e7c92f773ea72d9d2953c4b29c1f668f34b6eeead4f6cde53b9b0b89c391a7cb9e865d7073c4259ee4a5474fd52aa8d6588fbe07793974e83395d4951856846e285453a72eab0524f9d7bbd00ba24ac134ba9600437844912ec047324ba97a69422ebc9a508a6de4d0ab0737051f56719e2a6e37b5769dc54855519383fcc0e84f137c528d5af2d1ecab269a69a8b319ecad2aea1774ede945cea54963a1bcdc7ad57d7f56af7b5e6e4e5278cfc3276cf870e1dff00a4daed3beb8a4dd284ba37d80c8fe026c6b7db1b4e85e4e8e2e270eaf1d4ec8f3655aa49b585e869d2b78e974a16745254a31c248d48e1aca02d18f2924224000000000000000000000000000000603023d0bd069aaabe853d09b64dce6be80616f89ad3bc8d7275f97199f73ac786f53caddfa7bce3f68bf53bcfc57d9c69c95451ebcddce83d8d2e4dd360f38c545fa81e9169f53cdd1aca4bae69c7f4353f8cf9fb56afb46deb379ce20bf43e97459604809e400000000000000000021f624893c4405965d79fc3062a78aed4aa54b89db29be452ec656dafbaea4fe1130a3c4cea9ed1b96b51cf6901d43b6edfdab5eb1a58ca75a39fb9e8fed2b685aed5d3e34a3cbfb38e71f91e7ef0b6c15feecb48b59e59a7fe67a21a652f2343b3a6ba72c2206ab6f98b349956895d80258240000000000000000000000000023b10d7a96200d39c72ba77c9f1b7eed5b5debb76b58d7846535178caf53ee32aea3b66a6bb37d40f3ab88db16f763eb95adeb526a8ca4f91e3a7e46d7636edd4b696b56f776771529d3535cf14fa3466e719385d61bef43ab754e947cfa71725d3a9825b8748ada1eab5ec6b45c5d3934b207a1dc37ddf6fbdf6e51ba8d553ad18acf539042ab52f2e4b123087811c5cb8d97abd1b1b9aafd9672c757d0cd8d3352b5dc3614b52b392929473d181b99379c22d14d2ea69c2a29f47dcbb975c01128b6f9977383719f6b435eda35b9a2a728c73fe473a9bc43269dddbc755d3abdb4faa70c600f32f58b4f60d52e6d92c79551a326fc2d7105ace997157e1149b3a878e1b2abed8dd",
            "7755dc1aa35a6f1d0f91c27d7e7a0ef0b2a8a6e309d48a7d7ea07a25569b8fbdf3bca0b31587dcd2b5bb86a7a5dadcd0929c5c62de1fd0d4fde75c81644e32425d0901818400000006b28a38a8f645c8604baaf91c6a28ca9be8d35e8706dfbc24dbdbeac2af976b4a172ff8947d4e6cd7c7b130cd3f7a0f080c01e25f07357d8d7b55aa32a96c9bc34bb2380d9dedcd85c46b5a559d1ab17d1c5e19e976b9b7f4add1692b5bea109ca69acb898a1c69f0ef71a0caaea7a45372a5d65cb15d00df704bc43dc583a5a5eb9712a8b3caa5266536997b6badd9c2fecaba9c251ce133cc8a94eb5a57709a952ab07ebd1a6772f0738efa8ed4baa3a75fd694ed5fbaa529019b4a4e7eee30d08b69e19f3b6cee2d3f7569d0bbb2ab194e514da4cdfcaa3a73e592c016936a44b4e5d7d025cfd487269e00bd0c494a6fa2a7d4c4ff0014bc42ab7972b4bb5aed41371924cc8ae236e8a5b376f5c5c4e4a2ea45a4f383cfade5afd6dc3af5d5e549b946537cbd40da6ded35eadac5ad9a8f32a9349afa1e8070836659ed6daf465468c6155c339c7d0c53f0f3b0ab6bfafd1d4254dca9d39af4337d528da5ad1b7a7d14638c202a9bacf9a6f2c8a49c64fe05e9c7963d4b2c64094f20000000000000000000000000000000043248601762d47a4e582a29bc49818e1e2da953fecb8c925cc62cedda92a5add94a2f0d554658f8b6a19d0e323127489726a96b2f854407a31c32ad2afb5ed9cde5f22fd0e40bac9fe6712e0e5c7b46d5a3d7388a39745756fea05800000000000000000000acd662cb15a92e54056e2a7b358d6a9f083300f8e97f2bcdeb729bca5266776ebba565b76bd66f18833cf5e26de2bedd977553cfbcc0e4fc01b1577bb2126b3cb2467ac52858508fc23130bfc2ee91ed7af4eb35da48cd0ab17e5421f2e0087d505d82584480000000000000000000000000000000011828da9be5976350a558657bbdc09b78e14a8cfad39e534633f88fe0abb89cb5ad2a937249c9a8aee64b45b70c7aa34ead9d1d52cea59dd4233534d7503cc5ad46b59d774ea4654eac1f67dd1945e1a78bb1a70a7a1ea35d745cab999c03c41f0c2e76d6bd5750b5a0fd9a7d5f2aec753691aadd68b7d4efed66e1384bd3d40f4da50a73c5c529274e4b2b03a48ea6e02f166d777e8f4ec6eab47cf8452f79f5c9dab562e355f2bcc3d18176f3ee95a2e546a36bb32d1c771292cf403a23c576cefed3d0a17b6b49ba907ccf0be061c50ad52cee6156398d4a52cfe4d1e976e5d0a8ee5d16e6dabc549f23c67f23cf3e236dc9edbdd1776ce0e34dd46e3f7032f3c35eff008ee3dbbec971553a90e893676f283a5530fb36606f02b7dcf6aee6b7b795471a35aa2fc8cf1a1794f53d3a85dd0929271cf402fccf9f05cd3a0dca1ccfb9a800000000003e803ea069bf7fa174b95610514890349d2e67cdccd344d6a56fa8db4aceee9aa94e4b0dc8d46b252715cad7a818c5c78f0f9cbe6eafa1d26de399c628c61bcb5b8b1af2b6b9a52a5569bc34d619e9dc634ebd195bdc414e9c963de31eb8ebc00a17f46aeafa4514aa7e26a280ea2e0af192eb675fd2b5bbaeddbb697bcfd0ccfdbbb9f4addd614ee6ceb5394e4936933cdabfd36e74abc9dadd53952ab078ebd3a9d81c2ae2e6a9b2756a34ebdc4e56ae493cbec067b4a5e4d4e466bd38a9e5bed1ea7c1da9bb34edeba3d2bab4ad0755a4da46fb5cbe5a1e8971735a693517d5818ebe2db79c6b5952d2edaaa4d4b0f0cc59d3ac6aea57b4ad68c5ca7524974396f1637456dc5ba6edba8e54a13691f67809b65ebbbb68d49d3e6a74e6b20655f87ed94b6b6d78cebd2e5ab349e5a3b2962a3e6fa91569c2ced2dede8c5462925844d3872c7a81136e5d1168a497d49c22bcaf205912000000000000000000000000000000000011ea427ef93dcaf6967ea0744f8b782ff46e0cc38b29725e5197c26bf53347c5a50e7da54e6615dbfefe9ff797ea07a03c03afe76d2a6fe11476067bfe67597872abe66d2fc923b333d5afa8165d890bb0000000000000000000564b258abfc4071ae285d2b5da15f2f09c0f3df765655f5db99aedccccf2e37d",
            "cfb3ecbaef38f70c00d52af9d7f5e7f19303247c27d8cbda65531dccada9ddafa98ede142cb96d1d56bf84c88a9d6acff3020000000000000000000000000000000000000021f40222b0d9569c25cff0353288eeb0c0f87bc767e9fbdb48ab69714a0ea38e1368c12e2cec3afb1f5fab6fe5356ee4f0f1d0f4222dd06e713af78cbc2cb3df9a1d6ad0a71f698c7394ba81839b3f776a1b4355a379655a718a92728a7dd19f7c30de56bbdb6e50aaaaa75945732f53cfad7b43b8db5ac57d3ef29ca2e9c9a595dd1cfb83fc5bbcd95aad2b79d497b34e4977e880cef92f2db8bf8909a8f57d4d8edbd66df74e914afada6a7949bc3379755ec34ba2eb5fdcc28a5d7de9600d4b7a9527270519284de1f431dbc4b7096dee2d1eb56d52319acc9af5393f117c48e91b7233b6d3e50ab34f0a51663a6f6e3c6afbb69d4a13a951529e561b03ac2d6e27617b0ad07efd19e563e866df878e25d0dc5a0d3b0af533562b186cc23538f24d7e29cdfc0ed9f0f7535cd3b76519d1b5adecadf56e2d20339a4bcb9f2ff524a426ee6de9d66b964e2b28b47f0a0240000000000000000aca3cdd8b10ba014941f2858ad4a542e231953974c32e9e590f00741f1df807475ab69ea7a3528c6b2cc9f2a311355d2aef45bc9da5ed2953ab078ea7a6d1aca09d3ae94a9cba61a3a4f8d9c04b4dd56b5354d32318568a72f7575031df845c5dbfd91a8d3a75abce56b9ecd9dd3c61e39da6b5b1d7f66d4e5a938f549fa98b1af68775b7b52a963790709c1f76bb9b79ddd59d2f21d594a925d1640d2a95277570e736e53a92eafe2d9995e1936052d3f4a5a8d5a494a494b2cc62e166d296eedd142d5473083527d3ea7a05b6744a7b6f40b7b4a4945a8a4f0be806fe78ad55b5da2fa1a86947f679fa9a91edd4090000000000000000000000000000000000000c10c094527ff545ca4bd3f303a6fc57c5bd990fea611d078af4ff00bcbf53387c55aceca8fe6cc1da7fbe8ff797ea0678786b79da4ff2476863de6fea756786879da5fd11dacbd7f302400000000000000000000a3fde245caafdf203ac7c43dc2a3b32b26f1ee181951ba95a4d77948ce1f1312c6d2abd71ee183d43ad7a7fde5fa819afe17ed654344529471981ddb3fdecff0033aa3c3bc7976f52e98f711daf3fdecbf3020000000000000000000000000000000000000824ae5a7d7b011d13ee59b4bb91cabba226d3e9ea01fd3aa269cdd26f9bac25d1a0fdc895a54aad67d5a515f103a3bc40f052df7158cf55d329255e3993e55d4c37beb1b8d36f2a5b5c45c2a526d75fa1e8cef1dfdb776c69d5e95fdcd372e569c32ba981dc4bd574fd7b7156bad3797cb727d80ecbe1271fe7b174195b5c4955963a464ce2bc4ae3b6b5bdeb4a14ab4e8516ff0085e0eae78edd72ba1c976b70ef70eeead0a7a759549464ff00135d00e3ae55eeeaf5954ab393f5796ce55b5f85fb8b73d78c6858568d278cc9c4c86e19785e561529ddeb94df3e136a464069bb774edb56f1a3a7da53e8babc2031d3627850a52a94af353ab2cc5a6e12320f40d97a26d6b5851b7b3a6e715f8b9564fb2aa657e1e56fe05651cfab022126de12c47d0d4223d16090000000000000000005249f37d0b80212c14945f364d400695c52f3618ec5ad979749d39b738b58c32d9293e65d501d35c5cf0fb67bd14f51b5fd95c2595caba98b9adf07773e95a9cace9d8d5ad1ce14f07a154eb3c61a6fe86855d36d2bd4f3276b4dcbe2d01d03e1b384d576f5796a1a95371aad67aac190d71ef546b3d17634e9d0a5416214d43f2351e240517bccd4212c120000000000000000000000000000000000000086490c0934e7dd7e68ba2935d57e680ea4f14e93d931cfc598350fdf47fbcbf53387c564b1b2a3f9b307e97efa1fde5fa819d5e19935b4de7e08ed85ebf99d57e1b3ff0009ff004476a2f5fcc09000000000000000000002abadc4516229ff00b4c40e98f13b53976bd58ff2984b6ab373497f3afd4cd1f14736b6f555fca61858acde51fefafd40cf4e0151f2f6c507fc88ecd9fef25f99d7dc0e8726d4b76977823b025f8e400000000000000000000000",
            "000000000000000ab7cdd0b10d012960a4b9575eec99cb1178ee554e9db5b4eeae25cb08a6fa81672a76d4a573735153a5159f78e90e30f881b6d028d5b4d26ba757b662ce11c7fe3cd76eb683a3d6941f6738bec8c6ab8ab7b7f579ab4eb57a9279eadb6c0fadb9f7c6b3baaeaa56bebba928c9b7cb93e7e93a1ea1acdc428d95bd4a9293c652e88e69b07831afef1b9a4d5ad5a741b4db71ee8cc1e1bf07347d95a7c2577674eadc24bab8e70c0e91e17786895f79377ad52cc5b4f12325b6cec9d1767db421616f4d4e2b19c1f5a337cbc96d495382ec92c1a4ea558cf96549bfa81ba95c4ea2e571497d0a4572956e6e3d20c8cd4974e4606a38f527042f331fbb63155bfddc806092396aff00c2913c957fe1c8001c957d69c8797517570600000000000000000000047443993e8448452027952eddca38cf9b25d8cf40349c27266a422e2ba92d84c037825104800000000000000000000000000000000000000c10c02ec4777fd495d888fe2fea074a78b2ad8da50864c29b759af4d7c64bf5332fc5bcf1b6a08c37b259bba3fdf40678f872872ed25f923b353eaff33ae3c3cac6d14f1e88ec68bf79fe6c0b800000000000000000000a4b3731fc80a6f1711fc80e89f14cdad06ae3e530e34c8f36a16e9fce8cc9f14abffb7ea7f74c35d35e2fe83fe7407a0bc198a8ed3b64be447397f8d9c1782ef3b4edbfb88e74ff001b000000000000000000000000000000000000000159b6bb0134d73d58a7db274bf88fe26cf6969cec6d6789d48e3a7c4ee78d48c251f8e4e9be3d709ab6f6b5773689ceac565600c2bbbb9adab5d56bcaf273a927967dfd8d77656faa53a97f15c917ea6e755e12eedd1a7353d3eab8c7d63ea71fadb6759a0df9b635e38f8a0331f6bf1db68685a552b6a30a309c62965611f7287886dbb59fbd5e924fea60856b1bcb6eb568d487e68d1f32a2ed397dc0f40571e36ce32ae692ff00987fdbc6d9f5b8a4ff00e63cff00f68adff16a7f898f68adff001aa7f8981e807fdbc6daff00d552ff001149f1ef6d43b5cd2ff11805ed15bfe354ff00130ebd57deacdffccc0cf89f883dbb05d2e293ff0098dad5f11fb7a9f6ab49ff00cc608f3d67fc551ff564aa55e7da351fdc0ce5a9e2634082ca9d27ff0031b39f8a3d162de3cb7fd4c285677327fb99bfe86b53d1afaa26e36f3fb0199353c54695fc11a7f734f40f1396bad6e1a5a772c52a8f0b061f436fea53cb56b3e9f43ee6c4d13525bb2c25ecf560a155394b007a2f6f70af6da1730fc328e4b27946c36b67fd1ab74fbaa68dec3f0202e0000000000000000d6484b048000000000180000000000000000000000000000000000000000219200a4739c08bfda60b94a4b35581d05e2e6a636fc11883a6c79b50b78fc6691969e2e6bfff00478c326296814fcdd66d21f1a880cfde06db2b6da5492fe2499ce231eaff00338bf09edfd976b504fd628e511eeff302c00000000000000000000443fda17e4491078b85f901d21e28e3ff00db955ff2986160f17b41ff003afd4cd3f1414dcb6cd597f2985566f17745fc26bf503d02e08cf9f69dbff711cfe5f8e475d7026e235b6b508c561a823b1a5fbc901000000000000000000000000000000000000043c2ee486b2051d34df316f3b97a72a92fa849a1ca80dbdc699a6ea4b96e6da93cfd0f8b7bc33db37b9e6b5a4b3f4472074a3e889e4e9d00e01a8f0276adf41a76f4fa9c7a7e19b6d37271a30ea770463244f3545d981d232f0bba04a59f2603feebbb7ffe040ef1556a25dd0f36a7c501d1cfc2e680ff00dcc0d5a1e1876f53ef46077679b53e2887526fe0074f53f0d7b722fad181bda3e1df6cd36bf610fb1da6e537ea8a4b9dfc00eb9a1c00daf4e79950a78fc8fa34f829b5692495bd3c1cca50a8d7468b538492f780e271e10ed6a7d15bd3fb1ad43857b66cea79d42de9c6a2ea9e11c9d41a7d48707cf95d808b5a31b4b75429f482e85fb13818024000000000000000000000000000000000000000000000000000000000000000000008648c8156fe25ad639a92fa22b245ed5e27517d00c5cf1697ea74951cf6918ebb32",
            "9f9bb96c63ff00b8bf53babc536a31ada93a0bba99d3bc3e8799bb74f8fc6a2fd40f4336550f65db968b1de0bf43ebaeecdae8d41dae876507df923fa1b95dc0b00000000000000000000155d2b2658aff001e40e9ff0013345d4da5564be530768be5ad07f092fd4cf3f10f6ceb6cdacf19f70c0dab174eb4e3eaa4c0ceff000ef70aaedba497750476acff007b2fcce90f0bd79e7e8b1867b40eef9fef67f981000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041200ac9e3a97a0d45559fc2269d5fc0ca5c55f234db8a8fa7b8c0c20f11da8c6eb75d6a49f69b38670b2d9dc6f2b1c2cf2d44ffccddf196f9deef8beeb951933ebf00f4b77dbb2954e56d42680cf3a0b934bb44fe48fe8597c49ab1e5b3a115e8a2bfc888f602400000000000000000000abfc458acba75038071d293a9b2ebe167dc6600ea11e5bdacb18f799e8b7156d15e6cbb88e32f90f3d371dbbb6d6aea9b58c4d81963e142ba958ca39fe13212a7ef67f998afe14752942bca9f374c195353f137f102a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010d814aaf3168da6e29aa1a05c4dbc7b8cde556b95af538f713eefd8b66dc4d4b0dc3fe80601f122a2abbc7509a79ccced5f0bf60ebeaeea72e712ce4e98dcf5a571aeddd493cb94d993de133468c68cee270f4ce40c97adfbaa71f5469e702ae5d46be0c3590250080000000000000000002b53f032c44f1cad303e76e6b7579b6ebd26b3ee33cf4e25da7b1eeebca78c7bc7a353a6abd9d6a4fb38330238f7a67b0ef3b89a5d1c981cabc306a2e8eb92a4dff00124669cfad084be383007815aa3d3f75538a78e79233ea8cb9f4db79bf58c5ff009012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000435d72487d80d3c73d4c1d63e21b5b5a7ed3ab494b95f2fc4ed2b659b8cfd0c60f157b925194ec14be980317aeab3b8bba951bcf34b2671f868d36369b66357970e705d7060f69d6eeeefe8505fc734bfccf437841a57f646ceb4e98cc101cc27fbe9fe649472e6a8feacb80000000000000000000002b259582c47a817b44b9a717db0617f8a0d2d5bee1ab5e31c273ee666d19f25c3faa31afc57e81cb652bd8c565bce40c71e1f5f3b1dd36534f19a893fb9e8c68b5fdab6f58d5ce734e3fa1e6868d70ed755b4ac9e396ac5ff99e8af0cafd6abb4ad1f367960bf40392a7921e485d24d3f89600980000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000149f45d0b959f660154f67a13b87d3962d983be23f5cfed2dd3529a9278919a1bbefd697b4aeee5bc72d3679dfbff00579eb3b96eae252e65ccd2037fc2cd0ffb737450a5cae5cb24ff00ccf42340b3f60dbd6b6f8c72c5230ffc2b6de57fb9657356198aecd999d5a5e5a5497e18e30069f2e2459e71d035d995cbe6c7a0165d890000000000000000000001f6034e5d25cc759f88cd096abb3a7351cb8af81d973cb89f1788960f54dab5e8c63ccf933fe4079bd569bb5bd707feee7ff5336fc38eed86a5a1c2d79b99c525dcc36ddd633d3f70ded19c5c7151e327737858dc71b1d62a59d6a988ca6945360663cd72cdb7eac8efd4d4b8c4a9d3947aa7d4d18cd3f77d40d45d810be0480000001bc109e409047320e4901208524c9ca0008ca0a49fa81208caf88ca02411ccbe23997c40904732f88e65f102411cc9fa8caf881208e65f11cf1f881208e75f143997c4090579d7c5072c0160554d32c000000000000000000000010de067a012013e5557fc20402551abf2afb8f26ae7f0afb81009f22afca83a3557f0afb81009f26afc8b",
            "ee4f9555ff00081505bc8abf2afb8f22afcabee05413e4d4f58ff993e455f957dc0a82de455f97fcc79157e55f702a0b79157e5ff31e454f940a82de4545de2bee3c9a8bbc7fcc0a82de4547d92fb8f67a9f2afb81505bc99bec97dcabf75e1f70001190240c80000000000425cf351f886f04e634ade77126928a6fa81d61c7edd54748da77162aa2539c1aee606d594aeaea4fbcaa4ff567767892ded5352dc12b1a1573059ce19d51b3b4ba9abee0b5b6a70726e49bc2032ffc356cdfec8d1295fca1894e29e70776d65cd564cf85c3fd3bfb2b685adbf2f2c9416560fb52c8129e5938eb9115841812085d890000000000000000000002319582ae11baa15ede4b398e305cac179753997ab0306fc43ed49e8bb8aa5cf96e319cdf5c1c1f873aecb42dcd695b9f962e6b2655f8a0d9cb55d1fdb2953cb8a6db46184252b5b94d749539fe8c0f4b768eaab5bdbf6f7519292515d57e47d1a71525ce8eb2f0ddb821ac6c98529544ea471d1fe4766c22e9fb9f502e9e592318000acf3cbd0b0034dfe1592e93697291f89e19b7d5ee2765a45cdcd3ef4e2d81bcf649beaa511ec93c639a261fee8f12daee99acdc5adb55972d39347c87e28b71c9a6eacb2066bab49afe2893ecd2f9a0613cbc50ee292fdeccd1a9e27772b5eed59819baedfe3387dc8f2a2bfde53fb9839ff798dcefbd59fdcabf127b95bfdf4c0ce497950fc5569afea42951976ab4fee60c56f119b8eac7f7f3c9a50f111b9a0ba579fdc0cec6a8c3abab4fee57cfb55fefa9fdcc127e22374cdfbd5e58fccd397880dcafb579fdc0cf1f3ed5ff00bea7f723daaca3deb53fb98153e3eeea7f86e24bfa9a52e3bee9977b997dc0cf9f6db05fefe9afea3dbec3fe3d3fb9808f8e7ba1ff00e667f728f8e3ba5ffe6a5fe2033f5dfe9cbbd7a7f72bfdaba52ef714bee6004b8dbbaa4b1ed52ff11a2f8c9ba5ff00e6dfdc0f40deb9a3c7bdc52fb9a72dc7a2c7bdc52fb9e7dcf8b9ba27ff009c92fea694b8a7b9a5def65f703d09ff0048f44c655cd2fb9b79eeed11cd535714f2fea79fb0e296e68f4f6d9bfea2cb88fb8a57f45caf272ccd74c81e8a5174abd155a9494a0fb60bc4e2dc2bbcaf7fb2ad6e2e1b739417567294809000000000000000000378021ac90d61129e49eed7e607cdd6f525a45854bda8f10a69b6754bf133a279d56846b5372a4da7d4e7bc5893a7b2afd45e334e5fa1e75d5527775d2934f9a597f1ea066a2f133a363f7d4fee42f135a3b7fbe87dcc27c3f998c4be66066bcfc4f68f1ed5a995ff00bcfe91ff001a99852e3f16397ea066a3f13fa4bff7d4cd3ade27f4b8c730ad0cfe6617f2fd48c7d40cc68f8a6b1cf5ab0fb8978a6b1f4ab0fb9875cbf5231f503306af8a4b297fbd87dcd29f8a4b750f76a47ee622461ccf0bbfc0dc474cbc9acc6dea35f1480caf5e2928fad4890fc5352cfef238314ffb26fbff004d53ec47f64df7fe96aff840cac978a5a6dac548e0d3afe29634d654e262d4345d42a2cc6d6a7d88968d7f05995ad44be3803292a78aba52a2bf691c9b6978a97563cb19c4c5b74d464e336e2d7a60d5b5b0b8bd9b8dbd39546be080c9f8f8a49d38bcce2527e2a6af2b4a7131ae5b7f538f7b4abf621683a93ffca55fb019276fe2a2aa9c22e4b32783bef616e6ff004b34aa77d94dcd64f3c7fb0752528a569572de1622672f879b5ad69b4a853b85252505d181da29f56be01c7a918c55912c09c0213c92000004764567278ca264f3d084d4561804d49c63eade0e25c59dd51da7b5ae25ce94a5078396c142de13b9ab2e5853ebd4c4df133c4fa7abd77a5da55cc6398b480e82dc7ac54d7b54af7d52597293c7e4779f864e1ec753bea7ab56a6de1e5651d13b7f4e96adaad0b28c799d5925833df831b3e3b5b6cd14e9a8cdc32073ef2e36d18d18748a8a5805149ce7965c000000000000000000000000010de0900464892ca4588607c7de5a3d3d7b6cde52a91527184b195f43ce9ddba7cb4cdc37d6ee1c8a356585fd4f4c29f2ca94e84baaa995f730f7c4b70d9e93a83d4ada96149b93697703e77870dff574ad668e913ace109cb0ba99a398ba34eac5",
            "f32947393cc7d1754ada36a742f68c9c674a49e519efc11df54f77ed7a30a9353ad187ab03b0632e65924d34dc6a796d6308995471f402e0aa7cdd49cfa010de19b3d760ebedebda71eae50974fe86f9956934e2d662fba03cf4de9b235996e5bc951b2ab28cea379c33e6ff00d9d6bdca9fb1d4ebfcacf4467b7b43ab2e6a9614a527ddb8a2b3dbda12863d829ff8501e7c50e186bd521cd2b5a897f74f95abed8afa3f4ad2c35dd1e87ee9b7d0f44d02e2e2a59d18c791f2be5f53007889af7f6a6e3bc545e28a9b492038ba8aa8d429c65293ec8e4fa370df5cd6692a946d6a24fb7ba727e056c09eefd7e356749ca8d392f4ca338f48db3a36896346853b2a49a586f900c059f07772c5e3d9e5fe164c3837b926f1ecf2ff000b3d057a769535fec74ffc2158e951585694ff00c0079ff5782db8e18e5a1279f8c4dfda700b725c439e506be8a2679bb2d31f7b4a7fe026de8592b9e5a7420bddf940f3a773f0ef50daf172bb528a5f147154e2fe265178b67428c9d3a34d41b493c2c18b6bb302d989198fd4a003539a3f521c97d4a002fcc864a003513f7b06ad8cfcabea127d7135fa9b74fa9af60b9afa827d7df5fa81e89f09e4a5c3cb09af5a68e5717948e27c2358e1f58af4e4472d40000000000000000006011ea043ee4e70d0f527d501c538b2b3b2ef9ffedcbf43ceda8f17970ff9a5fa9e89f15fff0005df7ff1cbf43ceab8ff006caffdf97ea068f3b2399fc47a05d809cb23999000b733219000d4cfba443acd2fa9545e1f8901bdd2a846aeb96d465f8655526671ec2e13edbbcda342e2adad39d49c339c1833a6c9ad5ade49f5f351e84f072aceaec7a1cf2ce23ff4036f4783fb6274166d2967fba6a4383fb5e3dece93ff0094e63172514b259671dc0e1bff00647b662f31b4a497f748d4f845b6ae6c2ac68d9d253507fc2732f7be26adb3cce49be9803ce7e2be811dbdbc2eed210e4827d160e61c015a3df6b2ad7518c136d2f78e41e28f6d4e86b753518526a2e59ca47496d9bfafa76b76b5a85574daa8b2d3f403d0d5c33da72b784fd86938c92c4b0ba931e19ed28ffe428bff0094af0d755fedcdaf6ce5554e7182cbce7d0e46b316d3f881c7d70d7692927ec147a76f74faba6e916fa47b969050a4bb246ed45e4b815cfbcdfc4b0004630490db433859024155f12b3abe5ace3b01a9849e4d28d2955add7b265684a7732cc57f438ef1277d586c8d16ad7a95a31ad8e8b980e1de20b88ab64e892a36f5bf695535ca9f5307b55d52e358beab77712729d4937d5e70729e24f116fb7dea752a579c9d18cdb8e59a3c33d9d71bbf71dbdb53a4e74a335cfd3207697872e174b5dd4a8eaf5e86234da6b28cc2f329d9c29db538a518c797a1f2368edab2d95a150b6b7a718cdc5670bd4fa94bf6bef497503562d3ec58851c1200000000000000000000000000000086490c02e938cbe0715e27ed0a1bc36e5652866a420f072a2f4b1522e84966124d303cd0ddfa1cb6febb716328b8f2c9b49fe6769787ee23ff00a2bac52b3a9552849e30d9f7fc4e70c6bd9eb33d66ce9374daf7b1ea8c7cb2bba9a7de53b8a6dc674e5903d3aa3731d42c295fd3c62a414ba164d38acf73a8f805c55b7dcfa251d2ee2ac5d4a5051ebdceddad0c4de3b0131490c67a85d160aaca605b04800432b0e6ab55c17a166fa32694a34154ad2e89472074cf897de51d1f6dcece9d44a6d61e3b98536b4a7a9ea54e9c9b72af5127fd59dc9e25f74d4d537255b4551b8465d8ebde19e85535bdcf6b1845c9539a6fee0667f01f87d6fb4b6ed2b974d29d58a7968ec9ab294db4be26d743a1ecdb7ece8b5cae108ac7f4374df2a0260b11ea3196446595d43ce7a012fb136d1ff59e6fe521f62f6dfbdfe80625f8b8bb52d5bca4fb348c6c5f859df5e2b2e5cf744a9e7d4e85fe1605400000000000592ea6b69dfedd43fbebf53457735f4eff006fa1ff00c8bf503d12e12fff008fec7fb88e58714e12ff00f8fec71f22395a00000000000000000043ee490fb80f527d511ea4faa038af15ff00f05df7ff001cbf43ceab8ff6daff00df97ea7a2bc57ffc177dff00c72fd0f3aa",
            "e3fdb6bff7e5fa81a1e810f40808000025104a00bb968bea5577263dc0dcd83ffea545ff00ee23d05e0954e7d91457f2ff00d0f3e2c9e2fa8bfe7467e701ea736cea49bfe1039fbec8b2ec55f745c087f85914aa7265fa9634a7169e40eb1f10fb5a8eabb52a5c469e6a24f3d0c12ad1959deca2ba3a73fd19e93efab08eabb6ee28e39bdc7fa1e78ef9d2de95b92f28f2b49d46d01955e17b75cb52d3bd9e73cf2f4c64efaaeb137f5661ef855d5a56fabd4b6e67873ec663dd258a72f88148f489247f092bb0000010db0bb09f459291a9f102ce4a1d65d114941d792f2f0d16a74bda24dcde22be2701e27f18746d81a7d4a51af0773cad2c7c40e47bbf7be8db234bab7173714a35a31e91cf5c9835c5ce275fefdd6ab62abf638cba24fa33e77103897ab6f8d42ad4af71356edfbb0cf73e16dfdb9aa6e5bb859e9d6f3ab293c745d1013b6b6ede6e7d4e9e9f654a53949acb4bb19bbc12e0f5a6c1d2a177774d7b4cd27ef2ea7c7e03f02e1b2eda1a9ea94d3ba9a527ccbd4ee5baf32e27cbd634d76c013523ed2f9a4de22fa178e39708a4a2d43962d8a51705d5bc8174fd0b14f5cf5254b3f1fb0160000000000000000000113972ac95e6972e7964c99ce34613ab3fc31593ae9f1db43b6dc15349b8ab08383e5eac0ec4f33e3164a9e4f8569bf76f6a6d7977b4f2ff00991f6e955b1b887350b88cf3db1202eda439931e44a4ba2cff00523c9ab0fe0604b7d0a4652a6f99771cf35d1c06543f101f1f78ed8b7de1a1d6b4ad08ba8e0f0da30338a7b0ee366ebd5e93a6d51727867a150b854e784d24cea8e3b70ce86e3d1eade5084675b19e880c47e186f6afb3b5ea55a35251a73924f0fa19f7b3372daeecd068dcd0a8a551c53691e6f6afa6d6d2350ab6b5a2e12849a4773f00b8c55b6d6a34f4ebdacdd19b515960667acb93cf4c3f52e9a91b5b5d4e86af6b4ae6d1a9466b2da3730585dc09c318240156ba1f37775fad2f6e57af9c35067d37df070de2fdf7b16ceaedfc8c0c19e276adfdadba2e2ae5bf799dabe1676e42fb5695cd4827d73d4e8cd7ae3dab56b8a8bd64ccb0f0aba3ba16bed0d63314fb0190f5314e0a9456147a1185ea4d6eb565f990031d3a13d9041814ce726a50972a94fe116517665a0b3192fe560612789dade7eec94bf98e94fe16773f8998f26ec92fa9d31fc2c080000000025772001a9cb835f4a873ea56f1f8d446d936d9bfdbf0f3359b58aff8880f43f8594bcad8160be34d1c99763e0f0ea1e5ec4b08fc299f760f2058000000000000000086480213ea4faa212ea4faa038b7155736ccbe5ffb72fd0f3a6eba5edc2fe797ea7a31c5159d9d7dff00c723ce8bcff6fb9ffe49feac0dbfa13d907d03ec054000095dc8263dc07664c57521f7260fa81ab6af96f293f84d19f1c016e5b3e93fe53026cd735f525fce8cfae0253e4d9d4be1ca0760bee5a32c918cb44a58019227d2390fb933598e00af94af2d6bd27d9ac1827e207465a66e9ab2497bd37d8cf2b58fb951230abc4fda4a8ebfe63f59b03e57870ba743754567f14d19d371ef52a2ff00aff9180bc05b854375d1cfacd19ef09f9b676f35eb15fa005f024ac4b0019054049e7a63239295b4255ebd4e48c7abc9b6d4756a5a2dad4b9ab8c456518bbc66f105abd4af534dd2a94a106dc799640e71c64f10369b7a954b0d2eae6b75598bf5312371ee6d4f76dfcaeefebcea65b6937d11b7be8eafabd695e5d52af567379e671668ab2bf4b11b6aa92f8440a59d055ae210e6c2cf5c991fc20de7b3f625bc2ade53a52b84bbb48c725657e9e55bd64fe9126569a8cde254abbfe8c0cd8b8f143b76336a0a3c9f9948f8a3dbdd9e0c29feced43ff4f5fecc7f666a1ffa6aff0066066cff00de8b6e7325d3ee6bff00de6b6e6136e3f7307ffb3350c737b356fcf047b15fb78f26bfd9819e16de2276d5682939c57f53ef68bc5ddbfafd58d0b7af0e7974ee79e0e17b4bdd94aac3f39347d5dabaf6a3a26bd695695c545fb48a6b99b4d640f4a1a5cb19c5e632ec449e164f81b07559ebbb6adab4f2e4a0bf43edd36db7cdf103513cac92000000000000fb00052ee9f9d637",
            "107d3f66cf3cf8b96771a66fed425cf24e551b8c93c60f446928d455212f58e0c2df137b4eb697adceff00cb6a9ce7dc0ea1b1dd3ace99353a57957bfac8ec0db7e2035cd1b95549ce78fa9d58aab9c63069773925870eb5bd52cdddda51f329a59e880efcdb9e2aa6e5157585f9b3b074cf12ba2dda8aab52945befd4c2bbddb9a9d84a4abdacd72f7e87cfcd4a52c66506bfa01e8559f1a36d5db8735cd259fe639052debb5af395c750a397e9cc79bb4b54bda3f82e6a2fea6fadf77eb36cd3a77b53a7d581e903d5341a91cc6f283fca46aabbd1eea8ba32b8a538cba61c8f3c2db8a3b8edb095dc9afab67d2a1c6adcb41a6abbe9fcc0776f88ae0b5af90f59d2631e6799351316654ebd85cfac2a529672bd19d9b71c7dd7b51b1959de3e78358eaf275bdfddcaf2eaa56c2f7de40cb1f0d3c55a77d691d2b51ad1f357bab999913529f2ca32834e12eb93cd2db1afdded7d5a8df5bcdc54249bc3ee678706f8834f7c6dca555cd4aa28e00e7a034e2f0fb8023f88eb9e3dd4f2f6557fee33b1bf88eb1f10d3e5d955ff00b8c0c0eacf9ef65f5a9ff53383c375baa5a0539631982307e975bc8e7d6a2fd4cf0f0fb08476dd2fee203b3eabcd597e604d7ed67f980250080112ec5edfde9e3e851f54c5a4b173cbf188185de296d654774ca4d6164e8cfe1664678b6b49c35c75797ddcaea639afc2c0a80000248000002f1ee7d9d9945d7dc96704b399a3e345e249b395f0becea5e6efb4505951975fb81e81ecca5e46ceb287c2923eac7b2369a041d2db76d4f1d5534b06ee3f8501200000000000000001f600084867de4135d82fc480e39c4b59d9b7ff00fc72fd0f39af57ff0050b9ff00e49feacf46f88d173d9ba828f5fd9cbf43ce5be4e1a8dd2977f327fab036d25d03ec4b5d0869e00a8000131ee4131ee03d42fc489f5623f897e606eb4e8f36a9423f1a88f41b82b6de46caa0f1de3ff43cfdd1a2ea6b56b18f56eaac1e8870a68cadf64dac66b0f973fe407258fc496ca41b70582cd3780249cf5055bc3c81ad6cf0e6620f8b1a0a17d4e78ef332f2dfab93313bc5c4579d45af9d01d3dc24baf66dd76bd7199a3d05d1aa79fa45b4b39f751e74f0ee6e1baacdaf9d7ea7a1db526a7a05b3fe45fa01f46258ac70d160057d72588c01f375dd196b76ce849e1358388c7819a0d79799734a9d49b79ea8e7edb4ba10b99f76c0e13ff627b714797c9a692fa22bff00625b793c4685369fd0e6f529b97f13fb9318b8ac65fdc0e10f821b75ae9461f636b53813a0b9655287d91d84938aeefee13cfab03824381bb7d45274619fc8b4781fb7d77a30fb1ce1bfab2b39b8aeef20705bae07e8328350a50fb1b2bee06eddb3d3ab579c29a7083796b0764516d42556b49a8259ea63c71fb8dcf49855d274daf9a8fddc45818e9c4d56d69b8ee6ced30a14e4d74363b07469ebbb9eced945c973a6cf8b7b775f54bd9dc556e75aacbafd5994be1cf83de5c296b37949e5e24b206426d5d1e3b776fdb508f7e459fb1f4e2d4936fa17ab2e651a497bb0e851c7d00b201744000000000000006795e4eb7e3c6c086f3db751d3a71954a71cf4ee7633eb2c17508d7b7ab42a61a92c6181e61eaba756d2351ad675a2e33a5368c8ff000c5bbb4da907a5eade5be67cab98e27e24b614f42d765a850a38a5393e6691d53b5f5cafa1eb36b7346a4a0a335cd8607a0ba970b36a6ab25565694b967d7a2586712d6bc38ed6bf94a76d6f4d37f4393f0ab75db6eadad45c6b4675d431dfa9c9e84ab5bcf924d640c7bd5bc295ad45376f4e09f5c60e1975e13f598ce6e9fe1f4330bcfabf32fb0f3ea7ccbec06105f7860dcb41bf2fae3e87c7ade1db77d3934a945ffcaccf6734ff001a8bfe85792d9f7a71fb018015b80bbbe8fe2b64ff00a33675b82fbb28ff00e533fd19e844e9d8ff0015083ff94afb1e9557bdb527f9c40f3dd706776b8e5597ea64d786ed89ab6d3d3bfd779a29b6da7e87777b16971f755b52ff000978f934bdca10518fd101a9564a5532bb60a80047f11d71c7eb4f69d955da5fc0cec77dce25c5ab277bb3abc12cbe46079db553b7bb92f927ff0053377c36",
            "6a2af342a70ce71046176e3b5959eb1714a4b1893329bc276af09d076f29f551c770323aaf4ab25f5209acbf6b27f520094020fb010ba116ff00ed8bfbac47a95a52e5ba52fa018cde2e2d25393ad8e892315d76666878a7d22575b7aa5cc2397cbf030c23ea9815c1059ac321a019200000002efb1d97c03b4777bc2945473868eb37f857e677d7857d15dd6e58dcb8662a5df0066459d3f22c29d2f841175d8b5cb509a4bb72948cb20480000000000000000000af2f5c96042ee07cade547ceda5a8452cbf2e5fa1e706e1a4e86b97d06b18ab2fd4f4c2fadfdb347bab7eeea424b079f5c66db7536e6f0af4e50e5555b92e9f50382f50de560bce188292f5469c3a3cb021ac105a6f2ca802d178654012fbe49edd484b26b4209d36dfa01f5765d0773ba2c20bafed533d14d9149d1dad6f06b0f90c02e12da3bcded6314b294d67ee7a19a5d1f65d2ade92e8b9101a94ff02350a4561170055a4fa1288fe20352dfa39a313fc5c2c55a3fdf46585bacca6625f8b6aca7734629f5534074770fbff1459ff7d7ea7a1db397ff006f5bff00711e7df0c2d9dceeab449671347a15b7693b5d0eda0fa7ba80dec161162b9cc495d8090000000000014596f1e84b928bc2265d1651451fe2605f0bb885255a4bd17c4a528caa4f0f3cbeace13c54e24d8ec9d1ab2a75d79fcaf0b3d40f97c68e2cd86cdd16b59d1ac9dc4a0d2c3ea60cee2d72e370ea95afae272939bcacbec8fa1bd7795f6f2d5eade5d559b836f962d9bee1bec1bddedae51b6a5464e8f37bd2c746072ee05708ee77aeb34eeae68b56b4da92e6ecccdcd234ca1b7b4da7616f18a508a5d0f95b076759ecad068dad08423594165e0fbf34ea3e69776023d72c95dba9115819cbc0160000000000000001592f5119f238b7f125bc2c9a7cbe63ebd80e1fc5cd996bbbb6ddc374d4aa460f0f1f430077168771b7f55ad65710717093e5caeeb27a5f1a71adfb0abd60f394632f896e1379b37aae9941fba9c9f2a03aefc3e7122aedad7e8d95d5c356f397452919bb6d736fab5ad3beb59c670947394cf3122ebd85c657352af4e5fd51935e1fb8e5529795a36af5972fe14e4c0ca29cf0963b968c9e0883a779423756f38ca9cd65609e65dbd40b10d219c752afde59405bddeddcaf2a8be84c63f1ee580acb192177ec59c72480000112ed936bac594755d2ab5b4d7f03376fb16a38939c5fac70079efc68d19691bb6e2118b4b999c87c3bee89e93b8636ce788ca4b1d4e61e27b66bb5baaba9a83eaf393a2366ea7574adc3675a93c66a453fb81e95d3a8ab58d2adf324f242793e6ed3bcfed2dad65553529724738fc8fa304d67205d01945567204fe12935caf9917690c27d00e39c41db74f74edcaf4251e69283e983cfadeda3bd0b735dd8f2f2f973ed83d27a4d46a4e13fddc960c57f13fc29a1a74aa6e2b483ccde5e00c6692c752be86ad0a7e7e63eaba94c61b881a60bf2a4ba8e54c0a02d8c1785273f7bd177021afd8a7eb932efc24e8ea3a2abf71ebd7ae0c59db1a056dcbae5be9d423271a934a58f447a03c2cd9b4363ed3a36b058938640e5d70d4ea2c7c0ac6382949b789b2ede3a8120ae5b5d095d175024109a61e409057a96c800437819cf602487d89f42ab390253e817a93818022dea7ede31f4ea630f8b8da1e6d6a5aadbd3eb08e64d2327941465ccbb9f037e6cfb4de1b7ae2dee23cd55c1f281e6fd297341c5fa234a49a78396710b63deecbd6eb51a94a6a8733e5963a1c725c95a39a6b0fd501b406a3a6d747dcab405494b2304c53c804f01c9a4d1a8a9a8c5ca47d7d9fb76bee8d7adeca8d394a3292e6c7c00eeaf0d1c3e96a37d0d56706f9649e5a32fe6d538d3a4bf8560e29c33d976fb1f6fd0a71825394567ec7288af33df605ff8488bc93e812c00c1597bb1c97ec69d67ee3035ed5fb9524617f8a4bc75b5b8c3394a6662df5d2d374ab8b89b514a2df5300f8d1b965aeeebb98673184d81afc0bb4f6addb43a6713467dc60a858dbc17a457e86117869b0f68dccaa34da534670dcac52a497a7fff0000d3a7d8b1115844800000043ec5537902e1f62adfc0278fc404c649f464",
            "4233ab3e54bdd4453a52ab3e64d28aeed9d7bc57e30e9bb174eab4edeb537758c613f5035b8afc51b1d89a6d48c2a415769f4c9849bef881a8ef2d42756b569f94dbc472537d710354df1a8d4b8bcaafcb726e31c9b7d95b36fb78eab4ed2d694e50724a524bb015d9bb4af3776af4aced6949c6524a4d233af84bc30b0d8da2d1a93a31f6971cb6d75365c28e0e68fb174fa571529c5dd359ebf13b1ea547570d744bb20227394ea73b7d3e059b7e844574ea58084c86b0f24f2ace496b20339000000000000000112c3580ba2e830447f1010e3934350d32cb58b29d95d538cb9e2d753709f52b2a799732ee061871e783375b7351abaa69f41ba12ead451d2f637f5b4eb98d7a72942ac1fe47a5bad68363b96c2a59df5384f9a38ea8c47e35f87ebadbf715752d2e9e68b796a2ba01f57845e236e2daadbe95aa557c8f114e4654dadedaeb1654aeed2b464a693e8cf31a51ad675f0d4a955a6ff2699dc3c32f101a9ed7af46defead4a9422d2cb7d00cddfc0b13c90a5f2f638fecbdf3a5efcd329d6a15e2aa35db2722f2ddbae569b5f102512562f258000180c8c9000934aa49d2cc91a869568b9470075f71f76dd1d736655abe5a738c7b9817539b4cd51f2aeb42a745f933d2adc3a6ad6b43ad672c7bd1c2c9897aaf86cd4f51dc95e74f9a346a4dbe880ed5f0dfc497b934c5633ce69251c33bbea3c37f56754707f838f8754f9e4f329f56ced8961e18109740de0921ac80c361742489302b5173ac1f1f7a6d5b6de9a1d4d3abc149a8f4c9f662594fcb7cd17d40c02e29709b53d8faa559d0a1395b393c72aec75e529c2126aa43afd4f4a75fdafa4eeab59d1bea14e7369f568c7bdede14ea5f5e4ee34c6a9c5f65103162a494a595848aa597d1ac1db9acf871dc5a6d57183725fdd3616fc02dc95e5cbc8d7fca075b39538c7b26cbdb5add5ed556f6d467394de1248ef0d0bc2aebb7b5233b8a8d43d560ef3d87e1ff47dbb1a756fe8d39d4863ba03897870e0c434db58eb3aa515e737ccb98c839d48559c6941621158c0a3468d9d056f6918c29ae98489a74d43afa8119ccb917a166ba6028a526c9cf502b0c92e492ea454972f4425e452a7cf715e34d7d5e002925d516e75f036371aee91670e795f536bfbc8dac77a6852ff00ce53ff001203ebf3af805246c28ee4d1ae3a46f69ff891bc856b0aebf6779079f849017e64de09c608f67a2bde8dca6ffbc8ac5b52c3ec05f2113823004800086f08ad397bcdcbaaec5cd394d27cb8ee0708e25709f4cdf761517930f39c7b986fbf783bae6d1d42ac29dbcea504fa35e87a01194e8be689b3d5345d275fa4e17b6f4e537eae20799f5ad6e6de4d55a338bfaa34e33517ef4726796b9c00d0b5294a54a85259fa1d7dacf85085ccdcadf963f90189f2a917da18213753dd8432fe8651d9f847a94ea295592947e0ce5ba07864d36c6b4675e953697c50189bb7f636b5b8ee69d2b6b5a9cb27f89a32df82dc09a5b4a853d46fa9c5d7789665df2765edee1f685b752f2ada9a9c7b3e5390d5a939e211c282f44044ea2ad8863118f444a5cab0884944b672006486c8c816c91249a7911ebd4acd81c138ddab5d596d4ab0b252e7e5eb83013579dcd6d4abcee633556536da6ba9e936aba3db6b542542e60a71974ea757ee4f0eda4ea372ae68518279cf603817851dad2c4af2b5369b7959328ab4f9a4a3f2bc1c5b60ecda1b3ecbc9a508c5e3d11c89b7cedb03570d1269aad9972e0d40000021e1772319ea84fb60a293a7e99c8169492eddc457353954a92e484565b65714eda9cae6e65e5c23d7a9d09c6cf1056da350aba5e95539aab4e398303ef71738ef63b46c6ad9d8d68bb8e5e5f77e261beebddda96ecd46a5dded69c949e545bec6cb59d66f75dbb9de5ed69549c9e526fb1cbf867c26d538837f0852a72850cf5963b81f3b87bb0afb7b6a70b6a3464e8b786fd0cd5e17707f4cd83610ad2a3075da4de7e26eb86fc33d33875630a4e8d3957515ef63d4e715653ad2cc9ae47d9014a8e159f363093e85a1db3e83cb49610e578c0129e5962b1e9d0b000000000000000000000118ea438e4b00212c1128",
            "b7d72583ec068b52cfbaf0c8bcb3b6d62d27697b08d452e9d564d451e579128f5ca60634f17fc39c6e5d7d4b4a872359788a317b55d26eb47bba96b754a509c1e3aaee7a72dc2a51951ad1e78cba753a97889c00d2b745bd6bba34d46b34da4913086226c4e25eafb26f29d4b7ad525453eb1e63317859c70d277a59d2b7bbaf0857c630e5d7261b6f9e1eeabb3f54ab42adb54f253f76783e1e93aadf681794ef2ceaca9ce0f3d1f47f99097a6de5c5454e9352a6d6534c8c98d5c1cf10379ae3a5a45fe7cc8a51cbf532428d5f3eda159766918cca3e9ab9239bae047a95697367d48e65310994dc3b2c8538b59c85522df2b688ab4e9518bab5271515f533898e3d9c4f3c1cf9782651945e79728e3daa6f6d134f6e3ed10e75f53856b5c6ab5b39f954a7169bc772b5b671c4f1cba383c56c668ed5afa76ac94b195d0bc254925ee252f8e0e1bb2f78cb71c14a3d53399631d1962b68b4730a99b14e2b75b13ad36b0de4ac53c7564e3a3e8553c2ea21a7fe2ca387dc88cb32623d49c61928994e4632000ec5391b96725c9412aa8e3aae85956a917d64da000ad4a36b5fad5a4a4ff214edec693f76de3fe12c00b3aaa3fbb5cabf234ea3a951af7ba1600554704b5d090042e8889162ad65816a094aba4d6560e8cf131b9751dbba6cea5956953e9d30f0779464e1554be8758f1c362cb7be912a1462e526b1d00c30a9c48dc5560e33bfaaf2fe666cdef6d79bcff68555ff0031dc5a3f85cd4abf5ba557973dfb1f761e142327f8ea7dc0e88b7e216e1b79271bfaaffe667dab5e336e5b6492bbaaf1fcc76b5ff852ab4a9b749546ff003387eabe1bf5fb56fc8a3564bf20390708f8c1aeebdb869585cd6a92cbf8e4cbdb76ff00b3e9ce5f8dc533167815c21bfd0772c6e750a32524fd5195359724634e3d92480ac738c974f246524912809000021c532400c7c4a4a9a7d63d197005612a905f8d97f3ea7cc40027cfa9f3875aa7ccc8005249c9e5b27d305b0476021470ba858f425f5582aa3caf2483693ea42ebf909c14fae7a910724f95e127f1308e627da1129b52c47a9a8e9a6bab4bfa9f0b71ee6d3f6dd16ebd5829b5f13a577271debdbdf3a76af9a09fa1866d8c7476347c3ec6dc76c71e990adf96bdd59263713f597f43aeb873c47a7b8a94635a4b9d9d8752973b528766638b2c5e3973f6f5b26bdfa5d32ab293f896fd963df928bfccf9daaeb76ba2db3ab7538c70b3d59d15be78cd569de35a74f9a29fa194e6aae68789d8dcf748f4c818f2a9fbbd57c4d6c9d37c35e2c2d75c6daea58a8fe2770c1a9528ce3d9ac88bf2d3bba77d5b75baf91921126c85244bb64dbdc5dab1a52b89acc61d4dc4fac7068dedbc6ff4fad6dfc5358448c6be39f88094635349d327cb3eb17cacc5ebcbcb9d4eea55ee272a9566fbb676c71d385baa6ded66bea5e5ce746a49b7d3b23a92deaa85cd3a925d22d640ec6e17f07354de5a951955a528daf326de3b99adb2b63e9fb0f49a746da947cd51eb248eb6f0edbef6fdc68d4f4fe6a50bbed9e993bbab24b1272cc1f6034a52f698a9cbab269e5f4f808ac755d997021ac929000463a920000000000000000000000000000030225d5158a92643849bca64b9f2f4604c9c5f716f29f9f1496618ea44b18fab361b835ca1b6741af77713519460dac9303a37c4eee3dbf6b6d2b271a5ed6e38e8bae4c4195694a52c7552672ee2beec9eeedd97178e6e508b718f5fa97e176c6b8de1afdbd3f29ca84649cbea4493e9db5e1bf84d717b750d66e6328c1a4d651963cb1b5a51b68f68248d8ed6d1ad76ceddb7b2b58421385349e175c9bdfc6f9a5dcc249f6ba960a38b52f3252c43ea4559429d3739cd452593ac7883c54a3a4d19da5bd4ccf18ca66bc93d6bcaee96865dabc571b976ebdd763a25b4aa79b1e64748ee4e375cdccaa5b509be5eaba1c0b70ef2d4b5aab252ab3706fb64d2d076d55d6ea28d3a53726fb9cbb6d5ad0fa3f8ef8fe0d4a45f63899ff6d2bdd6352d52ebcdf3aa61bf89b0bd8d694e0aa5493964e73a86c1bbd02dbcfab94b19ea70c757da3508c719c4f073e62ddfdbd3e18d5be1b4e28fc643f046",
            "93a5a74252cb783b65d4752a74c9c0784b670a5a45394a3cab94e67a8ebd61a546539d58e52f89ded7c9d6bedf19f294b65dab5691ccb7b51b8a5d706cafb5cb2b0a79ad5608eb0dd1c68b5b49ce9d19e5f5ec7506ede236a3ab372a15e518bfa98e4db88b7a757c7fc5f3e78ed93d432a2c771d9ea0f92de717f91f469ca4dfbc6337073795dbd4a346e9ca49beecc97a75557a10a90f548dd8b37671fca78ffe93275e5ad82485d892cb9c1240410900000000000000000c10d8092ca2908a8f59c54bf32e889f5e806a2b94e3cb1a6920a7cbd5411a515ca89c81aded0fe4443a91977a307fd0d3c31d901a53b6b7a73f369d28c67f4351272596554332cb2f9c011c8bd4b2299e6e84c7280b000001d88cf4024109a64e400000000010c921810de0a4f9a5f84b3cbe87cad6b7050dbf6f2ad5dae8889bc57dcb3a526f3c57edf49d5a76b0752b4e292f89d7fbef8a763a4529428548f3c73d8ebadfdc61ab7b29d1b1aad75c746753dc6a377ac5493af394e4fea7373eefe55edfc37c63bf19f3fd3ee6ecdf77bba6bb94ea4f957638dba14a74fcca927cc728dbbb02f754b595c2a728c52cf547c5d6ac7fb32bbb697e24ce564ef69e65f44d18d5ac4e2c5c730ec0e0ad0a93d4e1893e4c990db8770db6ded37ccab5229a8fa9d15c29ab4b4ba1e7ce4a2d2c9f2b8b3bf2e352aaed6855972f67867470e4eb8e63f5e077fc4db737b8e3f8c4b4b887c4badb82bcededeab50eaba1d7d6f6356eeb2a70529ca4cdc68fa3d6d5eac69504e5526f193be7867c27858c6173a95352977ea8d18bb5a5e8b63675bc46bf4fd7c9e18f0bab5054efdc6519773bdada9ba56b0a52ee96052a5474fa31a76d18c62963a23513e6593ad8e9c3e57e437edb9966f3f42ec480588f4a123ec69a84a13535f1c9a857ab1ca5f177b6d3b5deba355b5ad4a0e7cad2cf730438adc38bbd87add4a52a72542726e2fd11e835394e9554d765dce01c66e1bdb6f9d0aad68d28baf18bc74ea060d6cddcf73b535cb7bfa352718c24b9927dd19ebc2bdf3437de81466aac5cd43fa9805b976fdd6dbd56ad8dd41c5c1bc67d51cfb835c5ab8d8ba8d1a139c95bca58efd1019e6d2a52f2fe0893e66dbd76db74e8d4b51b69a9ca704da47d0a6de5a974c017000000000000000000000000000000002b2592c0088f4469ca3ccf25dbeb80da5840210f312a9e94de598d7e26f89abca7a4da55c3c38b499913ae6a14f45d02f2e6a4945a849acbfa1e7671175fabafee8bcaf39b946351a8f5fa93038fdbdbd5beba851a69caa549617e66697871d810d0f47a77775412a8e39cb898fbc03d8557746e7b7b99d372a14e7f0e867550b4a1a3d952b3b7828a8c71d082617a8b159c97e1c146bccec5a32528a4fb918e479460c6d0eb5e276b7a9699615236d19767d518d3a9ea375a9dd49dc4a52aae5f8599a3ad6916dabda4a9d5a5196563b1d44f8254eaee1f6c51fd9f36718e8617af68e1edfe3fe570eb639edf70ebbd89c3bbad76ac675294945fc51909b3787b61b7e8aa952945c92f547d8d0743b4d0e8c69c29a4d2c76377abdcca16156706fa26569d4ad23973fcaf9dcdbb93a5678874b71bb5ca34632b6a324975e88e97db9461fda0abd66b954b2722e255fceff5a9c2ac9f4671aa718d0928a9359471f34cc5df4af01a75ae9d799fc777c38996ba268aa8dbb4a4a38e8ceb1d7f889a86b15a718d5928bcfa9c6a6aeaf2baa36ee7533e8732db1c33d47537175ade518cbbbc1be26f6aaa5b4b474af396d3edc329db5e6a357dd8caac9bfcce5db73859a8eb338ba94a718b7f03bbb68f08ecb49846a568294be0d1cfedad2d34f82a7468c563d522d61d4998e65c1f25f308acce3d78e5d6fb3783b474770ad2c29aea766d0b7f65a4a96738582f194a4b396916c64bd8f0f5782dadcc9b379b644a0c12585647a12000000000000000046464092b292893921c79ba810a4f25de10e98e853ab7d4096f2ba0ca7d3b3295aaf94972f56c549d1b7b77717338c22baf56059cdc3d3a13cc9ace4e3ab88fb595d3b5a97b494d74fc47dcb6bfd2afe9a95adcd29a7db1203554bd7d0b27927c89c962",
            "0a2d7c7269f2ca93c3c0166f0f180e3d32514d37d706a7326bb804fa1253a279c92e6b1d004d6484d63973dcd195497372c7bb2352bab6d1f4aab79795230e48b796f006e634a9a5cbceb9fe1922709c3bac1893b8fc48df69dbda54ed9f3d9d3a98934fa77320b60f15b4bde9674e34eac5d671594981cd62f2892a961f52c00000086490c08ce19c4b883b5aaeb9a5d4f2e6f3cbd91cb5f5582934a54dc24fa3e86acb5ed1c36e0cd38b245e3f1857a96d6d46cb5c9db79339a72c670765ec8e0fd7bba94eeae20e31786d34774cf6569f56f3daa74a329673d8fb94a14eda92a5460a297c0ad4d2accf367acdaf94e4b618c58e1f0ee740b2d076e4e1429c54a30eb85f4313b784a75b72d56f38e6ec6636a941dc69b52196f316625f1234cb9d3b70cea42949c1bee91577f1f48e2ab9f0fd9edb169c96fb68d0d7eadbd37421270583e4c2dab6af7ce116ea4a5fd4d19d2bbd439552a52727d3b1dc1c1be1dd59558dd5f537f1ea8a9ab5bdadc4bdaf96f21afa58e6f1f6fafc25e1d4b4f71babaa7df0d651dd728c6318c29a492fa14851a36b4951a314947a743512c2c9ddae08abe39e4fc864ddcbdecd34df372b46af6230a5d4b763771c287d2096490249f62240222030898c94135259863aa2087d891d09e2138314f5fd36aeb5a7524abc1736231ea61e5e5a57b0b89db5c5374eac258699e9fc634ef29cedeb414e94a3869f630e7c48f0b2be97ad56d56c2d9f90de5f2c40fade17f8aab4db87a46a770fcb6b961cd232b2a4a35a1ed36ef9e13c34d1e6369f7f71a5de53b9a13942a53927d3a19b3c02e2c5bee6d2a969f75562eb4528f57ea0770536dc098b79ea45652a153b7bb27d0be5497400bbe49212c120000000000000000000000000086890042c321479a6bf325742f45a846ad49e3115903a73c48eeea9a06812a10a8a3e6268c1f9c9ddddb93eaeacff0056778789add95f55d6e565e6b74a136b07526cdd2deadb8acedf979a2ea26c0ccdf0cbb52db4bda71bc74979b2c61b3b65c9d4a9cf3c9f2387fa5d3d136cdbd0a71514e09e3fa1f66293581288e7f50e3caf2bb129268bf2ac6028e0c782795147a34c85250ed13530472223ac9332d2e4f3259656ee846ada4e92eed335f9701a131331c4b2a4f13cb19b89dc3cd4abea72af694a4f2fd0f91b7f85bacdfce2ae294cca6af616d72f3569c5fe68bd1b3b7b6eb4e9c17f429ce9c5a7997abc5f29cd8b0c62afe3ad366707acb4d71af774d392ebd4ec6a1636967154ede8c56163a1bb937258c2fe85614e31792dd3156b5e1c0dcf219f66fdb2593d71f04472297545d7558254523388e3e947f558b69618794f28b35918e84a60248c12046490000000004378024156f2ba1342329545cdd80284a7f8591d9e1f73ad38a1c64b0e1fddc694eaa7d7aa4722e1ef1134bdfda72ad6f5a2aa63b640e54449b4ba16a949d26965cbeb829c927e92fb008be5596523295696206b2b651839d5abcb14b2f2702dff00c61d136759d5846b4255a2ba61fa81ccf55beb4d02c677b7f560a9c3e2630f1a7c43d3ba8d4d3b43adead7ba75a71238efb877957ab6d4aee70b4cb4927dd1d5f0855b9aca3152a9526fd3ab6c0fa157716ab3bb7733bbabe6379ee72ddbdc6adcda13846372e708fc59cd3867e1e751dd1a6bbabfa2e3ccb315238e6f6e046e1dbb7d5150b775287a74ec076bed0f14ca1429d3d42a252ecf276c683c76db5ab528ba9714d49af898157da4dee9d5a546e2dea4651efeeb2b6da8ddd9bfd8d69c1af4c81e9258ef8dbda825e55cd2ebf53ead2bab3b849d2b8a5d7ea79c167c40d7ec56295e4d3f8e4fb365c6bddf64d72ea12925f5607a16e829af76ad3fb88dab82ccaa43060543c43ef082c7b5cfee2af88ade7522e3edb24bf30338f52dcfa368b4a55ae6e29274f39ea62c71e78f2f5b954d3348affb3eb17cace9dd638a1b975a538dc5f4f967dd64e2f18d5bbaea3152a956a3e9eadb012752e6ab6f9a75672fead9975e19386b79a75953d5eedce3192e6499c1f81be1fee759baa3aaeb3471493e651976465bd95a5be8f634f4fb284634e11c7403713929d46976c12529",
            "c1c575ee5c0000010c90047a1a4d36f2fb1ad82ad67a044c2926b1ee958a7ea6a28244e118ff00283851f54e12ecce2faef0f74ed664e75a9c5c99ca651cbc869b6636c75bff0092c60d9cb827b629e25c0f4ce1269b6571e6f971714f2734b4d3edac292a56d051c2c74372e4dc794ac21cac9a62a57ea1b3637f3ec4ff0076dca8e0fab5dcbd3e6c6245dac0e65f0339954fd16113dc8e8fb12918fb124120c813008ea0487dbaf62323ba029eb88f63e6eebdbf67bb749af61569c652e5e8d9f52385d115a71546b73aeedf503cfbe2e70feb6cad76b47cb9468ce6f1f0361c32ddb5b6a6e4b6af1a8e34e535cc65d7886e1dd0dcfa24ee69518bad14de52307efec6be957b3b7ab170a94e4d01e93ed3d7a96edd0e85dd29c5fbab38fc8fa10cc6583133c37714ef6d6f69e8d735e4e12928acb32e2aa53a54ea53ebccb3901959c1269d392f5ee6a000000000000000000000000000fb021f6034eac9c6193e7eecbe7a56ddb8b8ce3dc3e84e3ccb0709e39ead1d2f64d6f7b1292f8fd00c1ce236b93d6b735dce4db51a8d7739df870db2b5bdc4ab4a3954e6b1d0ea5bfa8eeb51ad3f5a951fea65c785bda5fd9f63ed6e2f33f7b380321636f1b4b6a3463d14560d39fbbd89ad394aae3e0c99a4c098f58a6490bb120000019565b243028d64b2486494000c0c0044800000000000000000044bb111eaba96213cb02b8ead9b6d4af6769a2dcd6845f9918bc23752e8cad4853aa94269383ee80f3e78c5ae6a9aceeaaeefe15210849f2297667ced9dc44d5b65d584ac6e27c89e5c53332789bc0bd237b519cada94695571ce62bae4c5cdfbc08d6f67ce72a54eadc534fa7403b7b63f8b0a75214edb54a5253c24dc8e71ab7893d16cecfcda7284a4d764cc20ada75e5acbf6b6f569b4fd62479777556315a4be0f2077c6f4f13fa96a6ea51d3dd4845e5653c1d2baf6e6d4770dc4ab5e5c4e7ccfb36574cdb7aaead5e346d6cab4dc9e33caf08ee7d87e18f53d6ea52b8d41d4a74fbb8b5803a5f46dbba96bd750b7b2b5a9525378ca8bc2329383fe1aa9dad3a3aa6b318ca7d25cb2476eec8e15681b26d61feaf4ea5651eee28e66eae56297b90c744901a5674ed74da10b4b2a718429ac74469dd5b585e4f92f2842a737c626b452596bab27954d755d40e0faf705f6eebb5e75a36d4a2e5fca700d6fc2969d7b394eda74e0dbce0ef54a71e919b45e2eac5f5ab260621ee3f0af7d60a52b793963e0700bee04ee4b59350a33925fca67f79917fbd5cff9a2afd85fe2b783fce080f3a2eb857b9ad64d7b055963e11645a70b3735d4927a7d5867e3167a272a5a63797654dfff00d4898d1d37d2ca9aff00fa90182fa4787cd7afab53552152319359cc4ef9d85e19b4ed26742f2fe109ce387868ef45ec915985bc53feea457cda934d733480d1b4a36da55bc2d6ca9c6108ac7446a24bbb5d428a8f57d49ca7d80b20422400000000010c90040240118c8c12008c0c124369012de3b954d3f42392755e228d48db548ff0a7fd408e881156dea4976c7f522398ac302c08c8e602486b2439e0853c8128b7a14eac94a6de120214312cb645487334d4bb1ab2b6ab2f44bfa9576ea9f5ab2515f981a75eda95fda4ed6b25253e9d4c3af119c2dada16a0f51b4a19a726db715e866157d4f48b16a55aee941af8c8ea9e386eddb9a96ddad6d0af4abd5e56934d0185db575da9b775ab7bea726b924b3833f3849bc696eedb346b73f35450c773cf6bab64abd6e4ebef3c1dd9e1bf8992d0357a7a4dd546a949e16581998a93854ea6a1a74ae237b4a1754bad394534cd4400000000000000000000000000acf25889bc47204505e64dc4e86f14db86950d0a566aa7bf8c60efbb269d49cbd3061ef8a6d66173acceda33cb52ed903a0f4fa33bbd42de94566552ac52fb9e8870936e54dbfb52d3cce58caa534ffc8f3cf4db8563796d769acd29a97d8c8bd2bc534adf4eb6b4ab269518a5dbe006583b6a9cce4daee693a5514fbf431e2c7c56d84f0aad44720b3f135a2564b9ea440eeaeabd48cbf89d5747c456dc9aeb5626ea9f881db525975600765757ea5953949e328eabbaf1",
            "15b6e8c5b8d5833e35ff0089dd0e145aa3523ce07787b2d4f9a21db49779c0c5bd57c57f96e51b79c9bfa2388ea7e28b5caedf9152680cd1f27f9e9fdc4a84e2b9b9a2d7d0c1da1e26372c679a9566d67e2764ec2f1450bcb9a767a9cdae678cc80c9475631eecb464a4ba1f2345de3a26e0b684a85cd3e692f89f63d99c21cf09f347bf40232864d1949f37666ac649a02d90525d7b131fa8160000000000010d65051c12008c67b949d3cbe86a002908ba524e2db34351d32cf5a8ba5776f1945fab3741ac81c1f53e076d1d55b756824df5e891b0b6f0edb3e849b749b5e9d11d87e4c3bacfdc974a2fbe7ee071cd1b85db6b41929db5b41b5f148e4f09c28c152a545422be069aa518f6cfdcb81a4e829cb99c9fdcbe1ae88b002aa1cafa12d651200859482fa9200359239512008c10b392c00879cf429372e65caba1a8008e5cac30a0a248000000437824359009e40c606401552cbc13923a260580fa9a73abcaf005b39ec43928f72929be65ca9f535256af97cca955422965e40a799ccfdd359d38d187995a708c577cb38aee9e286ddda76d3f36e612a915d97c4c64e227896d46fee2adbe935a4a9e5aca032237a719340da7192f68a7cf1fa9d5775e2aedead76a8d48f298bbadee4d477056752f6b4a726f38c9a36fa16a1754fcca56d5251fc80cc8d0fc4de8b594637b5e116fea736b4e386ccbaa519fb653cb5db279f7574dbca2da9dbd44d7f29485d5c50788d5a90c7a6581e8cdb714f6a5cfe0bba7d7ea6fe96fadbb57f0dd52fb9e72dbee4d52dbf777535fd4df52dfbaf52fc3793fb81e87cf7a6df82cbbaa5f73695b893b5edff1ddd25fd4f3fdf10f70496257927fd59b2b8ddbabdcfe3bb9fdc0cfdb9e30ed2b78b7ed749e3ea7c1bff10fb4ace94f96ea9798974ea60a54d62feafe3b9a8f3f536dcb5abcb389d46ff36065c6bfe2a28d2a53f629c1cbd30756eb5e27b745f549aa2d4619e996751d2d1750ab8e4b5aaf3f43eb69dc3edc1a9ce31a365349fab407d3d5b8bfba3576fcebb714fd13671bb8dc7a9dd26ab5cce69fc59db1b6fc37ebba9c232ad49acfd0eccdb7e146de9e25a8538bfcc0c50b7a7737359468c673949fa2c9cb36cec0dd55751b7bab3b3ab1719a973ac998da1f87bdada54a33950a7cc8e7ba7ed7d1748a6a16f6f4963e807c9e1bcafe9ed4b7b7d422d568c1279392a582917152e5845457c11a80000000000000000000000000089a4e2f24959aca0213c51a8a1ddc70626f1ab83faf6e0d7eadfdb294a2de718c99630838bc97a8ed547f6b4632cfc5640f3b351e14ee2d360e552da52c77c459c7aaeddd568b6a5635ba7f29e945de87a3ea11fda5a53ebfca7c8afc37dbb719ff0052a4b3fca80f392761774de276d597fc8ca2857a7fc3523fd19e85dc705b6e5cb7feab497fca8f9975e1f76f56cb8d1a7fe103027ceb98ff001555f727daaed7fbdaa67255f0dfa2547d29d35fd11b79f865d1a4fb535fd00c2275ee67d1cea3fb95f22e25d7cbaaf3fcacce4a1e1a743a4f2e34dff43e95af87cd068cd3952a6d2f4e5406095b68ba8dd35e559d6967f959ca340e13ebdae4d28d09c13fe5339ec7855b734e58f63a4f0be547dab0dbda46992cd1b582fca206086bbc12d7746b7759d2a93c2ce394ebfaf6d73a75770ab4ea51a907eab0cf4e6eec34cd429ba55eda128b58eb13abb883e1fb46dcb6f52ada52852aad7a440c39db7c42d776f5c4274afeaba71fe1723bd36478a79d2953b6d454da585991c1775f870d7b42752adba9d5a69e52e53aa752d1efb48af2a5756f5294a2f19680f44b6a712741de16d1a94ae69c25f072472554a9d65cf42a798be8cf35343ddbab6dfaaa767775631f9799e0eede1f789cbcd19c28dfa94e3eae4c0cbd93953fc54e423352fa1d79b5b8f3b7b724611ab569d294bd398e7f6b52c75182ad655e3532b38520358070ab1ef0e9f12bcc9776901625154d3ecf259000000032977194fb0000000000000000000000000000000000000000000000032001137cab24912c35d5808bca2b3214b0f0ba9aaa94e4b3cbd00d38b5eac9937e916ff2295e169422eb5c578d3515eb23",
            "8a6b9c59db9b7f9a2eee9ce51f4e60396c21567de128a171ec76894ae2e230fcd9d03bafc55d95a73d2b2845b4f194ce94ddbe20b5dd7ea49509d4a7179fe2032cf7871976fecda6e33ad0ab2c3c6198ff00bffc51dd6a6aa5b69729d38be994740eadaf6a1ad56f36f2e6a547e89b35b48dafaaeb55630b5b4ab25278cf2817d7375eadaf57954bcbca935279c731a1a36dfd435db98d0b3a139b93ef8e8771ec5f0d1aaeb35e957bf73852efcad60c94d97c1ad1768d184e5429cea452ebca0741f0dbc345dde4e9dd6a91cc5e1e248c88d1b843b6b48b58d1ab694a4f1f29cc235214e2a1421e5c57c110eace6fde7903826adc13db7a8ca52a36b4a39fe53826a5e166c2eabcaa5354d26fa23be13925d2582bed3593c737f9018d1a8784d6f3e4b8a3e44fc255f67a5432c637151f793fb0f68a8bf89fd80c4d8784abe6faccde5bf847b94fdf9a3295dd54f8bfb12ae6a3fe27f6031cf4ef0a1429cd3afc8ff3398e97e1c343b19c2552952925dfa1db9e755f9ca3ab55f79b0389daf0a36b5a72e6ce93c7f29f76d36beddb18a546ca8471fca6ff000e5d5b0a080987936cb16f4e115f4455d6b99f69452fc8b24be01af8015c4e4fa894325ba848088c12ebea588f5240000000000000000000000000000010d649004258f5187f164802126bf899399fcf2000734fe690e69fcd2000734fe790ccbe69000434df79318fa92008c154e7197e2782e47327d009ad2a373074ab50538be8f28ebddf1c0ed0b7550a938d18c2a4b2fa23b05ae9d0d24eb465d338fcc0c28df3e1c35cd1ee272d2adea56a7d7a60eaed57686b7a2d470bdb0ab4daf5c743d2d75e9a8a854a31967e271fdc3c39dbfb9a84bda2da9a9c9774901e715adf5de9f594e856a94a717e8da3b336371f75fdad5a11a951d4a4ba7567677103c2f559d7a973a553c47bf43a1f79f0f754d9b3c5ed394639c65a032c3677897d2754a515aa56a74db4b396766695c42da5ad453b7d42ddb7e8d9e6ec29cdc79a326bf237fa66e3d5347aaa76b77520d3ecdb03d30a13b7ba8e6cea426be8cd4746b457bdcbfd0c1bd97e22f5ed02705735a538c4ee1d07c5569b7dc90bba8a33f5c81dfd2a9c9f8988d7849e13389e83c5bdb3ad508b95cd38c9af5c1c82df7068974ff61734baf6ea06f9ae60972a2f074ab24e15e9b4fe0cb790f19538b028190e2d3f52af3f502c910d372fa11193cf5cfd8b737d18071f8128aa9f33c22c00000000000000000000000000000000057a649ea4382ce4ad5949748f600e6dcf963d595b9d434fb08377d5e953c7cccd96e3ab534fd16adddb26eac60dac184dc4ee306e5bcd6ae6c5d59d18d3963ae40cc5d538a5b3b47a72955d468732f44cea3debe27acec9ca1a55484d2ce30cc4abad4b51d4e4e77171567eaf2de0d2b5d3ee6fa7c9429caa4be0901da5ba7c43ee1d714e9529b841ac6727596a1ae6a1a9d5955b8b9ab272f4e66722dbfc2ddc7aeddd3a30b29c212787268ee8dbde14ae2baa756f60f95f569b031c6d34cbed4658b6b7ab59bf95672728d1384dbab59a89474cad4e1f1944cd1d99c0ddb9b72841d4b784aa2473ca1a769fa7ae4b7b5a492fa018a7b03c2d55bf71afab73c795a7cacc84da7c27d0f6bdbc146842728fab4731f3311c469c63f91a4d49bf502f4bc8a14fcba349412f81473a93961b782631c160212490c244800472a2400c0000610c20000c000000000000000000000000000000000000000000000000000000000000000000000000aa5d4b118021cf0f03abf52d8455c73ea044a117dd659a5e4d4555493f77e06be0293ce00d48d793f764a2d76ea63d78b6b1b2a1a042b2a50551faa464037ef7f53a63c55e912d4b6ac2515f87ae40c27b77275234d3e92783b4f6f70075cdd3a57f685936d633d8eaa8b746b27eb097e8cce2f0c9b9286a1b5fd979973ac0188fb8f861b836d392b9b694945ff0c59c56546b5296254ea4649faa68f4bb58db1a2eb2dc2eed69b72f8c4e0fabf87bdbda94a53a74a953e6ebf840c16b6d7f54b158a377569fd327d8b1e25ee6b09a953d46abc7a36648ee1f0a346b29cad66be983ac75af0d5ad5",
            "8ce4a82a924be0b207cfd0bc43ee2d3aac5dc57a938af4c9cf34af1673b79c7da69d592f5e8752ea1c19dcb61269da54925fca7c4bbd81b82d32e5a7d6697f2b0328ac7c5f6893e58d5a324feab0722b2f143b72e7194967ea613d6d0b53a0ff0069655a3f9c4db4a95c507d61521f7407a0365c7adb37b8e5aa937f53ec5b71536fdeb50a7710ccbea79d34f50bba0ff6771563ff0031bbb4dcbab59d7855a77b5b3179c397703d2bb5bba17f4955b69a927f03561cd97cc75ff033daeef675b6a17551ca5382786761b9294db4000000000000000000000000000000000570c8c74792e44a3cc044552aaa50ae94a9b58c3ec63d7882e02d0d568d4d6f43a2a35b1ccd451909e5f4c17e5a7568ce8574a54e6b18680f312fad6eb4ab8a96770b92a41e248ed5f0fba86814b5c8d0d6a106a52587239a788ae0a55d26bd5d7b4da5e646a3726a2bb18e342e2e2c2e554a52952ab4de7a746981e98d868da0c2de9d7d3adadf97a38ca0bb9f4237353979528ac76318fc3df1bbda674b48d5aafbf9e55cd2ee64c4df37256a2b9a9c9672044a339bccb04a8af5239dbebe85a2f204e4751dc35900d36104b04e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ac9e192ba225ac8f4021af5fa9c73897b763ba36dd7a0a399462f07236f088a5513f726b3193ea079adbc76edcedbd72e2d2e29ca2b9db8b6bbac9ce7827c56abb1b56a36f55e2de7249b7e877c7888e0d53d7aca5aa69d47f6b04e4f94c3ebbd2eeac2e2742bd374ea41e30fa01e95681ad596ebd368ea36756326e397866f212a9cd89559230ebc3d7192b6ddbfa5a46a35dba12784e5f03312daeadb59b485e59d584a328e7a017771383c294a44fb651ca53a09bfc8d3a3eeb6a45a54d4a5cc8054a56372bf6967097e7146cee36ee89751719d8d259fe546fda58ea5251f83038b6a1c25dbda927feaf4e2dfc228e29a8786dd06f39b0a2b3f43b4a3192eb965f325eac0c7fd47c2669b524dd299c76e7c2a2b4b8a7529f34a3196706513a9513e997fd4957351749413407c4d91a37fa37b6e8e9f8e5e48a583ee4563a913cd459c6094b080900000000000000000000000000000000000034ee39b91727735086f080d0bdd3edb5cd3aa595f4233534d2524616f1f383b5f67ea55351b3a32f679b72f7574c19ab26e6d4a2f0d3cf43e46f1db169bdb40af67734a2ea72b51c81e70e93a8d7d2f51a37d6f2709d292974667070338bd65bab46a3a75dd68fb4c572f57d4c49e25f0eeff63eb75a94a8cfc8726e2f1d11f2365eebbbda3add0bfb7ab28c6325cc93e9803d22abd27c8baac6728ba588a38d70e3775a6f0dad6f791ab095770f797a9c8a9d4f79c5fa01aa8108900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028d372fa12e08b0034daa5714a56b7108ca13caea62af88ae0add5bd79eb3a4d1cd25994945195928a7d71d51a57346d755b7958ded38d4a725869a03cc68cebdadca71e6a55e0ff002699de5c10e3aea7a36a9474cd52e652b77d136ce49c7de0346c9d5d5b45b758fc4d462635cbceb0ace128ca957a6f19ecd01e9ad86a16bafd842eeceb465cd14f1166ac54a3eebce7ea60ff0009b8f1aa6d1bda36d7d5a756d9b51cb7d8ccfdb1ba34fde3a552bbb3ab194e514dc5303e9252cf57d0b6306938d5536a51715e86a27858ee05b0bb91dcaa4dbefd04f2bb012f290c663d498f624085d888b79ea58000000000000000000000000000000000000000fa821814a70719b7e8cba6a8cb9d2e8bb84c96b9963e2075ff0017f87765bdb6ed7af4a8c3da6306d3c75302f70e8b71b7f56afa7dcc1c5d393c74f43d2e51e56e93c79725868c78f10fc1885edb55d66c292f352e6cc501d49c0ae2added3d72959dd5c49d9c9a4937d119bd617f6fae69d4afece6a4a714de0f326a42b585d383cc2ad297d9a3297c35718677153fb1351a8f314a31cbee064ca9ac63e04a7915e092f312f767d51106b0059bc10a590c2580240",
            "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055c93e85654bae5772de5a6f2593034ee68db5fdb4ad2f20aa464b1d564c73e35f871a15e957d67488fbfd64e314646ba4a4f99bc31fbd52a15e3cf4a5d1e40f316ff4eb8d2eeea5addd3952a906d3ca3b1b84fc67d4b60dfd3a752a4aa5af32ce5f64640f1c380365af5b54d4f4ba5cb5d665889883ad6817ba0deced6f69ca9b8b6b2d01e856c7e24e93bf2ce954a1520aab5d629fa9ca6519539f2c974f89e746c2e21eabb1b53a55edab49d052f7a39f4333f861c68d277b5953a552ac3da79718cfa81d8b2ce7a17ee8d34e4a79fe07d8d4efd40940000000000000000000000000000000000000000000001127840304909e506044ff000bc7734afada8eafa6d6b2af152e68630d1ac9e3ab345b71abe643b81827c72e1cdded6dc37378a94a36d526dae8702dadaf56db9addb5fd1938f9734e5f964cf1e34ec286f9db5563468a956845bca5d4c08d7b46b8d0754af6173094654e4d2caee80f41f859bfacb885b768d5a35232a94a3152c3f8239672b84dafa9841e1db88f5367eb9fd9f3a98a7733584fb19bb6d5d5dd9d2b88b4d4d736501ab921911ea8b76000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000180042e9dc9c14cb6c737bd8022536a5815ea79704d967ca99a70c49ce771ee52a7d799f60356872bb7954acd2a29372e6ed83103c4e6b7b4af3517434b8d3772ba49c17a9cf38e3e212868f4abe89a44f351a706e0cc45bdbeafa8de54bbb99ba952a49c9b6f2069f98fcaf2f19cbe877df873e1ceb95f53a7aba8d4a76efae3d0f85c18e09df6f7bfa3a85c526ad23252c35d199a3b7741b4da7a653b1b4846388e3a203e824e9db4294bf1462b24c1f434a9b939f34fd4d67f40240000000000000000000000000000000000000000000077000258000118e9828d28335086949013426973464938cfa3c98b5e27785d4e94deb161452965ca5ca650f234d7c133e2efcdbb4b746dabab794232a9c8d2e9f403ce0d3af6a69ba851ba83719d19a974fa19e9c0adf94775ed3a542a564ee631c25ebd8c20debb62eb6b6b97167710715cedc7f2c9ce3807c44abb4b745bd0ad525ecf397c7a2033b29a7492a73fc45cdbdb5e53d5ace96a541e69ca1935e13528a605800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006464090c002b9c15935f91672827d5f52bcbe6d451ec80469a9a94e4d28c7ae7274cf1e38d567a06955b4bd3eb2f69794da9753ecf1c789d6fb1f41ab4ed6ac7da5c7184fa9837afebd79b8f52ab7d7951ce75259c37d80d1bbbdadab6a152e6ea729d4ab26f2de7abf43b4b84bc10d4377dfd2b8baa528db2927d63d19f0f857c30d4f7aeb36f25426ada13526f1dfa99e7b7b41b4daba250b5b6a315384126d2ead814dabb72c765e8f4b4fb5846324bae11f4e29c9665d59a3052ab2752a379fa9ad958c80787d112960a2493c976f20480000000000000000000000000000000000000000000000000001594b97b162bc9d7201cba16a7539671835eecbb95c138031abc54f0da579386b361470a11e6938a314e8d6a969711ab06d4e9cb2bf347a53bd748a7acecebdb6ab05393a4f1f99e75eefd1a7a16bf756938b589b6b3f9819c1e1fb7647706cbb7b49cb9aac21f1fa1d91c9e555707e861bf86ae214f45d6e1635669425d30d999526ae2946f218719c5302e084fa139000af375c1600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030001032190d81a73a49cb27c7de1bb6c76be855ae6ad48c6ac60f09f73eec254e8d295c579a842196f261bf899e22d4d4f5dfecdd3ae5f90b3cdcac0eb6e286fcbcde7af57a93ad29508cb115f1367c39dab5376ee4b7b254a73a79cc9a5d0e394293af5a14fd64fab6660705754d89b276e52b8ba5415fb8a6e4d2c81dbdb3768",
            "693b1f42a14ed6de2ab382cbc75c9f6e139c9b9cd4b0faf638455e3b6d493e956324be2d1b4b9f11bb4ad961cdb7f49203b1f994d74cfd8aa5878ebf63a9ae7c526d4a117cab2ff336d0f169b47f0ce12e6fa303b8652cf459fb1a919651c1f6971af6eef1a8a9dbd48c1cbb26ce72d47954e0f9a2fb302404f20000000000000000000000000000000000000000000000000000003209640168c635e2e84fac25179461c78a0e1f4b49d6e7aadbd3c527ddaed8330f99c25ccbba382f1c76ad2dcbb2ae1f94a55943a3c7d00c08dbbac55d0f55a1794a4d38c96707a05c27dd70dd7b4edf1352a91a6b279e9a9d8d4d36fab5ad558953934658f84ad7954b6a96756a3e91c24d819114b2a728cbd0bbee4575c95e6fd1b262d49006bd495d8000000000000000000000000000000000000000063000000000000000000000000000000000000000000000000000000086571ef2fccb860718e2453beadb76bd1d3b9bcc945fe1301b78edbd7f4fd5ae2aea56b5db726f9da6fa1e8faa91a69f3c14d7c19c7b72ec1d137851942e2d69d393586f9501e6f2ab3a753997492fa1ad2d52f64b95dd55c7c398ccebff0009bb7ae2bcaad3ab8cf5c60f935fc21e95526dc6b34be806227b6dcffea2aff8994957ab3fc5566ff39332e69f840d31cb12aef1f99bb87843d1e135fb6e8061ed2b7b8ba7cb4e9d4a8fe8b25dd856a6dc6ac1d392f4666a6a3c09dafb1b41ada8ce5194a947af32f5311b7d5fdb5e6bb59d9e1524daf740d3d97aa5fe97b86d3d92b4e0dd449a4fa347a1bb2abd5badb36b52bb6e4e0bab306782db2ae7746e4a55214a52a74a49e7067be9968b4ed22ded718708a4d7f403711f52484b0480000000000000000000000000000000000000000000000000000064120086ba115ade1a95a55b5aa9384a382cfaac17b45cb524be8079efc73d1168bbfefa9421cb4e4fa74e87d7e006ec9687b92142551c23392c75c1cb7c53e815286b13bf54df2b97e2c1d1db5ee9da6bb69579f97135d40f4be9558dd69b46e22f3cf14f2569bea7c0e1beab0d636b5aa8cd49c60bd7e87208746d7d40bbee490d656094b000000000000000000000000000000000000006ad6863b1a46f251e65836b38b8bc01500000000000000000000000000000000000000000000000000000c002b8e6ee438a6ba364a44a580291cc3bb97dcb73c9f6cfdc97ef111787802919cf2dbe6e9f52f6952556afbdcdca97ab12784d7c4a57ff0056d2eb5752e56a0de40c7af14bbf2a5a69f5348b4aed732c3c33122dedeade568d2a49cea4de30761f1d35db8d4f79d784aab9421f5361c1fdbf3d7777db43cae6a717d40ca4f0d7b065b73458dfdd51c4ea4329b4773ce7e6d693f4f436b61690d3b40b7b5a515171825846bd38b515f1035410890000000000000000000000000000000000000000000000000000000002b26d1109ca32ca2cda4f0c896101d4de2436b4356daf52e234f324b2d98335232b3bb947aa9539fe87a4dbfec61a96dab8a528a97b9ff43cf0deb60f4edc97b4b97963e63680cb7f0bfba3fb4b4976f3a9971491de335cb51fe661ef856d6a76faaced799e1cf18331ae6292a72f881a6dfbc5884b3d49000000000000000000000000000000000000037a56705345801b49c795e0a9bd006c81bd006c81bd006c81bd006c81bd006c81bd006c81bd006c81bd006c81bd006c81bd006c81bd006c81bd006c81bd006c81bd006c860de8036457f88df803e7e7cca918fc4e21c5adc7576eed5b9549e24e0fa9cfc01e5e6bfa9d5d5b55b8baad26e529bfd4c9ff000a9b4ece54a1a8d4a6a551ace5a329001b0aab37328ff0a5d82ef837e00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d835979135946fc01b1f261756b5a954598b58304bc41e91434ddd15654a2973547e867d803023c3a5dbb6dd514bf8a68cedaaf9e8d17f149ff0091ba007cf4fdec1737a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00d9037a00fff",
            "d9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003012200021101031101ffc4001500010100000000000000000000000000000008ffc40014100100000000000000000000000000000000ffc4001501010100000000000000000000000000000001ffc40014110100000000000000000000000000000000ffda000c03010002110311003f00a8c050000000000000000000000000000000000000000000001fffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003012200021101031101ffc4001500010100000000000000000000000000000005ffc40014100100000000000000000000000000000000ffc40014010100000000000000000000000000000000ffc40014110100000000000000000000000000000000ffda000c03010002110311003f00ba000000000000000000000000000000000000000000000003ffd9",
        }),
    },
    SakuraPhoto = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080300030003012200021101031101ffc4001d000100010501010100000000000000000000010203050607040809ffc4003b1000020104010303030303030401030501000102030405110607122113314114225132617108152316428124335262911725a126438293c1c3ffc400190101000301010000000000000000000000000102030405ffc400251101010002020300030100030101000000000102110321041231132241511432614271ffda000c03010002110311003f00f950000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007d479db5fe98b1d6953e9b0f1ab73dafb22b2175e1fe7fee9c1391d4e2f2baaaf0f68a8d2dbec5eace5a5ff00f26cd6528fcb6bfe087afc81554edeefb7d8a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a20013a1a0890234192430209440027406c0100920000090000000013a1a24042344a4812827e23486915060f653a43489029b4690d2241023486912009828efee5e0cfe065c723714ff00ba5b2ab4f7f72f5271daff00868d7c76afc81f4cf1ea7fd335f5adbd3bec2aa7792494bffb85d69cbffed3ab62bfa72e8a67ac69dee3b8d46ad0a8b6a51c8dd3ff00fea7c20e30d78936ff001a376e23d62e5dc3a8fd3d864ab2b7f88393f0068c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009d12a3b0292468aa34db02920afc7b6c8716825041528ec28b6f4821482b9c1c1e8a74c9d02418d06b44020c049b020904b4d011a1a1fb071d2d81200d1204a1a09040095e5e834d3d05f534804e88fd8550009d10940274400000101bdfbb63e43f0052000000000000000000000000000000000000000",
            "000000000000000000000000000000000000000000000000000000000000000000000000000004e82004025a20094c9d688455e42611697b95c9d48453d3517ecca69c3be693f66fc9d5f82f1ac0728b7a7635a70f557ee16c66eea30b85e9cc72f83fee509b6fb7b9a348bba4adaeea507bfb24e27d5d65c42df8fe35d9d2f34e51d1c5b9f74fa8632e2adf46a3d547dda4c9ae9e5e0b8ce9ccfca9697c9e8ec54e3a49b9bf645aa8b753b29a6def48dab86f07cbe6f336ae7695151ef4e5292f7444734c2dba8c03c464552fa9a96f51535e76d1e2937397b1f685ff004db135b8bc2d55282abd9a7e3e4e3fcb7a2dfd8f075efa8c1b9796b46ba6d7c7b23894e938c77a2d38cbdf4cbd2a7712aae9764dc93d6b45551ba1fe3ab0927fb99b0b2a8852a728ee52d3298b51da467f8f709c8f27a72a9634e724bf08c6663097982ba76f794e50927f28691eb7ebc1ed2db44cdedf825a735b4994f6f91a47c17b9549ee21526fc87e3c31a36a52241213044a7a409d49c7ed5b08937511ed4bb9bf243a8e5edee742e99f4e23ca6ea32bcfb68fee67fa83c0b8f715ff00b1560e5af64c379c36cdb90fa4d43b9f8651da7a6e9caa5497a4bec4fc1e66be3e431b8eaa37a1dc4e838ec208b04a5a44010c30c010b7b2a92f053dda0db212a40010000000000000000000000000000000000000000000000000000000000000000000000000000000000000004810094181001504e94824042013f2181009d0604004e801247c9204320a80d88456bca29f61b6bc04caae2d456cda7a676592bbe4b6ff00dbdc934feed3f7355a6949f9339c7b90def18ba8dd58bd493d92b637b95f5bf22a7538d717577939c54fd3daf3fb1f3664f3d92e6f949d9dac652a5dda5a2ff2aeaf6679c63618caf526debb75f936ee84f0daf619385f6469254e4d6b7ec2cdbd1fcbf97a8e677fc3ef78f662d65774a4a939c5c9b3eb6e0d538f5c71fb7fa2a54fd7505b697ce8e7ff00d43585ad5ab6aac29c5a7adf69b074ca16186e3aaa4a5fe5ecf665b19a5b8f8663596cdd4c950ab29d36fd34fd89b3cbd0cf5abc65ec5795a7b30b3cf5e64afe54d7fd9d9eaab4295bd45568c5fa9adf82f6bb71c66534c7cba2f888e41d750876c9ecc0f3be8558dec2152c63a9ff00ea6c94b9b54b7bbfa7af196fdbc9b862ef5d782ad38ee0fdb65632e4f1719f580e94709b6e158e71b8a516daff007189e5fd2ec6f34cf425e9c54652f3a36ce476b92bda5df66dc20bf061f13cfb1bc5612fee55212af0dfbb274cf3e3c24712eb9f4eacb8154b7a565ad492de8e48a1e51d27ad5d428f35cca745a9528bf1a673bab4dc22a5b5ad10f2f9719be9e8a16fdf0da3c55e0e351a3d9673ad77fe0a14db93fc145ee22faca5df7142697e5a159cc2eb6f1fb225792a845557e3c0adf64bb22b6caabf048aa954eca8bf07aa586bcb6b78dcd5a52506b7ec79a950a97b5153b7a7294b7f017c71bb6e989ea2d4c059fa36f17dfad6d18ebcced5e4f55cef653f7f966d7d37e98d2cadcc5e5a934a4fc266edca3a211a0a1531ca31a7fb0d577f1f1e76387de62ae1d3d59d29ca0bcbd18b84a0ff00c5284955de9b67d69c3ba678e8623b2e2107575a7b399f58383e0389c65776b4d3af2f7ed27d5cfcbc194bb71895371f72dc82b96e6dc96d3f8362e3dd3cce7285ead950d53fcc88d7f8e7c71b7e35b5252f81ec740c9f47b2d6364eb460dca0bc9a1dc5bd4b1a92a35e0e3523f0c69396171fab2fdc32b8ce3ad3879fc911a6e72fd8695d29515ee3ba2fe0f4d2b29dccd429ff00c991bdc7db58518f74539ebc94da755820012a8000000000000000000000000000000000000000000000000000000000000000000000000000000000002502090087b8d0f601a1e4120412412bc811a2a5a6898c13f796838a8fcec836a7e499ebc683452c26c4124128941a2402080009d27494b64344c5e8128d107a3d30a9a5e7f079d7b95d27f7f9f606f4f4e22b46d72942a4bf4a923ec1e311b4bce2346a50946357b13f1ee7c6f38b8d48cd7b27b3a160bab375898dadac652f4a2d29792d1d1c1c9eaee72c27d763ef6f32",
            "8fc504dc7b8e71c3396bcdf22a989854eca6a7dabcfbad97fa85d54855c052b7b1a9a9568ea7a6723c1d6b9c56529e4a95570929777b875fe77d6393c051e3b469d79578ea4b7ee7af0b96c35483a956b53935f1b3e70e5bd57c9e66c236aae27dd15adecc2f01cb656ef3b4ad9de54ec9bfb94a437fc698f9326523e91cb4b11717eaad3a49bdfc23357d99b5c362615e4bb6105b662ad70b1c7d953af557a9b49ecd53ab794abfe9ff004ed60fee8ebc131ddefef13c9ffa8bb19e36b63f1b49bac938ed238552b9cbf2dc8d655aa54dd46da5f83a3743fa6563c86adc5e64e516e29ea3229cf5bd9f1fe694eced29c634fd44b697ee3b716532bf5e7e39fd3ee4f258da97b5e5a7adc5334fc9f4c733699076de9b7152d6cfb12c370c45a7d3d45db282ee4bf813e33637dbab2841cff3a1a67f82571fe97f47adad68c2eaf6945cbdded1ba734e0382bec5ba54ade9aa9dbade8dceda953c72f49ca318a30d9fc95bbd53a528c9b7af04ba70f1e69f34dc7453272b9af52dfcd28eda48f374ef807d77239dbe4e9fdb4a5f28fa4ef2a50e3787a990b9a91d4e3ecce1153a97656fc8a72b6518a9cf4e48aea31fc384cbb755cf74ff000f79c7aad0a6a9c2718e91a174f3815862b29527774d568a978f1b2e72be6170f0aebdadce9ca3bf0cc4f4cfa8b468bab4f2551396fc3906d94c27c777a387b19b84ac692834be11aff27cd64ac25f4ea9c9c37ade8d717596cb1b7d18539c5c5bfc9bb64f9d71fc871cfad9c69baca3bd7c928c3292bcb8bbdbefedceac613deb6ce7bccabdb64dd68645c652d3d45998e3bd75c4bb89e365413efdc53d1e6bbe9a5ef2bcc7f758d474ed64fbb4fdb44e2ae7ac9ce380f04b7cce7a4ee68a8dbc65e36bc1f4763f8edae2ac2347154e14f4b4f4bdcc3ffa46d317428c2d2ac21521aeed7c9b4595f538d08514d6f5a6cb231e0ff1451b5a31b3a946ee9c65dc9efc1c2b95748a79ae55f516c946de52f291dc73398b5b0b79465252932ce22853c8d84ee21562a7ee910bdf1b7f5c9739d0ab7a38e7568c61dea3f0714cc71abfc4dece93b79f6c5fbebc1f6256a174addcaacf7035fe436f81bbc6d5a6eda9cabb8b5ddaf915965e36df28db5f7d24fb547eff006d1b8e1f8bcf2f4557b9d6a5edb165c06b5d7269ba90d5bfa9b5e0ddf91632b606d69c2da2daedf8461a73fe2b3eb8100097000000000000000000000000000000000000000000000000000000000000000000000001280805400a41510c080000275e082a8a7f826088ad93ad3256e2fc17614bd44dfc827d596838b5e0bd468bad55528a6e6dea2bf27b6eb8ee5ed29aab5ad2ac61ada935e0696f5b7e319a7ec572a4e10527eccabbbc7dcb4d1ecc5e2aff00905c42d2ca93a92dfc13a46adba8f7f1de177fc9b7f4309546be1229c8f07cde36bca8d6b4a89c7dfc1f46f4578add701a50b8c9da37debcf7237ce634b077f61717ea85353716f5a5f81a764f17f5dd7c3f56d6a5a4fb2b47b5fe0b7569b8e9ebc332fcb6ea3759cb854a3a8c26d2d18af5f715196fc10e4ca6ae9694434f7e0bd0a6eaafb16ca2519d27a9449d2ab7a64e9fe0b9df04bf7263529ebcef605a516fe069ef45c946b47ef9424a2fe74569c651fb7cb02cca2e2447c97e29bfb66b4d944e94e8cbcc5e868531db7a27b7b597928aa7dff25a5fe46342b9d46e1ad14c692979f92a5e3ed21369f825254ab56a351a926d47d96cb8e559ebb5bd16e516deda32165568c60fbf5b098f3c2da771512ed7b364e17614edf3d47bab764bbbf2605e47d0ac9d3896ad2faac72d4ee5c9c753d85f1cb55f63d2a93871fa5dcbbe1dabee30f77656b98c7d4a751293d3d235ce2bd4db2ca61a8e22538ba9a51defc9b3723a5438b6023919544938f77b968f5bc7e596348e2189cb61f3d569d073a76f297c7b68dff23d2db1ca4165255e2ee23f77ee613a71cdec3925c54a3db1eef6d9b3e4a37765565e9559ba6fe037c6cb5e6c566ab594d584db7187846f18e9567494a29bdad9a5d8e36add5c46b767eecf7e43a816bc6e71b7a8e3debc682f971ff8bdca2393a8a4a85197f28e797d737f8d9ba95949",
            "c93f6667f93f5c2decec3ba9528caa3f1ec55d3dff00f5f4feb6fe92a749f9f2894e394c676d727572bcf2d9d85684e9514b5b668b94e845cd1b9955a15652517b7a3e85cffd161f76d634a2b4bf544c7626e2a4a13f522e5ddf929631e4e099f6f97f95595fe27b31fb94fe347829702cebb1fada542a28fbf84cfa52bf4eecb3194facad14da7bd33708e36c29da43170b583dad7b0b36e6cb83bedf3074f3a6571c86efbef6a3876bf693377bee9ed7b6bf562ae5fd3b5af7f06c5cbe10e0f70e71ff001465e7c7831963caecf3b0728574eaff0021a618e33a68dc87a79478b5e53bfa7554929777b9db784f30b0ccf1ea5614ee230aaa2978668b718a5c8aa3b4ab55b6fd8b381e9ce670193f5a97a9e86f68b62b6a63f1d41f19a939bab2bb6d7c793c970e58e8b8397ddf0cb771777d468412eedaf73039acc54ad5a9c5ef6bdc976f0c9adb1795ad90becac28454a4a4fc1be71bc1e42cea538d6528536bd99af57ca5be26c3fbace09d5a4b691a0df7f50b9fc95cba56b68d422fb534bc8dabcbc925d3b472eccd1b2a1f4b4e4bbb5f9348b78d5b99f7c96e2d982c765ef338a37590dc37e7c9b2c3276942de31a2e32912b638ee6def586a3514250828cdfec390d8dadbd0a6aef5edf25cc65f55abdb2717a451c9ac27c82318ca4e092d782beae0e6c5f1f000c9e20000000000000000000000000000000000000000000000000000000000000000000004a2094048000001000480212f25c9b4a3e3dca7dbc8d7cbf620d8a5dabc9edb0c3647210954b6a339463e5b4792bf6ee1dbf83e86e8a57e391c25557de977f67fb86da7161ed969cbba6dc36ef27c9ada7734651a34a69cfb91f48f5529717b7e1d1a742341578d3d3d6b7bd1cdf2bce705c7657b0b150f51b7dbda72dadcaf23c86fe54ab569fa537e22d8f6d3d0c70c30e9ad5c538d5baaaa3e1773d1baf47b350c4728a5174e336e5e3663f2dc36e69d25736fad35b662b0d42f30f92a57ae2e3e93ded13ece3b85c73dc7dcb714afb9162a9ce9d18c20a29ed1cdf9ddcd2c7632ad9aacbd7716bb53f9353c67f52af1787958f97350ed4da3984b9c64f95f2da552ace52a53a9fa7f634e9db3c89af55381e9fe5b2b9fefaf6d3f42736dcdaf7d9d7efbfa79c7d4c4c6bd15fe571db3b2f1ec2e229f19b4aae8c156704dbd7929bbbbfa7dd3a7a71f8424d230e0997c7c51cb7896438b65254552a9e9af669184b8af19c146716aa7c9f6ddef07c4f28a4ddd5287aad786ce03c9ba5542c799c68ce0fe9dcfe3dbdc6bfc679f8965e987e97748ae3975457171092a0d78da366cb7f4ef714b2d056ea5e8772dff000773e2d656bc6b094e1694e2a0a3ee8f74394d196a328c37fb9323a30f0e49db42ca7423155f88a8db453bb8c3ca5f93e62e47c72eb8a65676f754e4926d4768fbbad3276ca0bd2fba53f7471feb9f4ee195b4964234d2a89392d11631e5f1f4f97aa4673d556b5f28c95afa7794fb6a249a479a8775a5efd35e5392517af3f07a7294a36ee33b67e1f9f0438ae2c7de5955a555a8a6e242a12a71db465695e42a59b8496ea688b2e299ac8bf529dbd4f4dfc908f5629387fc8d6bce8f6e4b8fdce2e7dd562d6bdd33cd46b52ab1ecedd4895245a94fb96922d3835e5b3d4e8a83d94cbb6a2d240da8a4928f7325ea6bedf71e231d114b517b08bb5fc3ded6c4df42e61269c5efc7c9b6728ea9e4b91e2a38dad26a9c568d366f6f7f0455a5eb28fa5e5fc8fe74bf1f2dc7a8ea5d03b4b9ab9a73837d8da3eb08e1695c5bc54bb5c9a3e58e8df30c67105395fca0a697c9d9303d4b7c9ebcd6367dcb7e345a3bfc7cef4d9f93646db8a63aa4e5daa693d1c5eadacf99de4efdca4a3166d7ccab5d642e15b6424d293d79335c678cdbd8e3fb69a4e325b0f571cfa6b388e9ae3f2338d4bd9af4e3e5ecde639be3981b0589c5d587ac96bed659cd58ce58795bd826ab34d78343e11d35cac390caf3232a8d776f52619655b75657773fe45b97f22daf2e2d93538eb46c6ed9dadcfa4a2bb7d8c4732c4ded1b0956b55e5af821d1c3963fd5fc4666d3d5ff003cf4ff0093393bab44d5e5196fb16ce5",
            "5c271790c8dfc95e77a8a7f2754b6c2d25285a41bd49698579bd77d3e6cebcf38a998cb3b286d28f839c616eaff0d70ab41cbb1f9676febaf49ffb74de5694a2fc771c5edf25176f3a5554538f8234f17972d65b756e95e52b67b3104df9d9f435785e53b68d15422d6bdf47c59c43975df1acd46b5b4b51ee3bad7fea0e95ae3a92acd3aad22d1ace5dba3dfda55a349bab4d6e5fb1a8d7e3b56e6ed54717a6fc19ae07c9a7cf28f7cda51d6d6cdb2384ab6555d4ace1e9c0b3b78b97ad39ce6b178e95a7d15d54519c96b4cc16378762b16a4bd2a7272f29e88ea7d775b91d1ab66dfa707f7769efc6e4aceee74e1536a4a3e434985caed8fe536f4ad716fe9928bd7c1a7f1f95d3b88baae6e1ddf26c79fcf59d5ca47190f2dbd1b9e2f875bac642b38a4dad86f6ea69eec453b7b8b282a093a9af2666860ea578f9514cc458584b1b4a7528ef6978395f35eb26638de4e76d0ee5e7c16b1e773673faf9f400733c500000000000000000000000000000000000000000000000000000000000000000000094412809000008040480007c156fc68a49411a35bf73d96797bdc7c250b7ab2827f86791124e97c6d9dc6c5c4aef1d2ca29e65b9c1bf3b321ceaae3d64a8d6c1ea3492f3a34eec737e0ae6ead3a7fa9e89d46b3937f59e7c972b78e369414a4bdb48ccd1a73c6da7a993a2d45af3b46c1d15a98ab8b98c2f6c9549ef5dcd1d67aa1c4b157fc79cad6de317d9f089f58e9c78ee536f9de56385ccca5f48a5ea35e12fc9b97487a69795b3aae6f6938d18794e48d5ba6562adf99c28ddd26e9c65a69ff27d6d5aa63a962a2b1b4e109a8adf6a2677dadc3c5ed77676f5ca54adec951a7249525ec6b52b8bbc964a3e8c65e945f93c946e2f2eee34a4fb53fb8dbb0f9bc1d9c55b4ea538569787b64bd1f4f59b8f6559c2dad215292d4d2f26a37189a7c8321dd3ed5553f766dd93beb2a36ed2ab06a4b6bc9cb731c82eb13927716aa528efe035c24bf5bb2bca1874ec2e649bd691a96571190bebe552c54d536fe0c6e1f2575c8f34abdc464a29fc9d1eaf2fc56068428ce9aeff001e592b5cb534bdc57172c559fad9193524b6bb8f0e52ee39ebe56d2d4a86f46339cf3477d8b83b04d6d7c1af714ce56b6dd4b88b72fdc31bc5b9baf6f537a3dc7eaf1bad92b4a305731837b4be4f952939d0ad5adabadca2dc5267db1f5af9171aba825dba8bf0cf9823c22e2e39d3a53a4fd1955f2f443879386ef6c674f386d7cf720a34ead292a4e5f27d6dc7fa778dc658f654a54daecfc18ec0706b2c0428dcd1a51ef514fc232375ca25675bfcde20bc79234d38f8258e17d49e9fdde6f3eedb1f49aa6e7af08c4f24fe9eb2985c1c2fa9c1b9eb6f47d0b8dc9e37277b19d18c3d4dfbe8da7955d5ad971aad2bca9071507a4ff8234c797c798bf3eee2d2e2c6aca8d784b71f0fc16a955a7a69c74ff7375cd720c55ff21b88aa71ec536b7af73cf75c6ad736a352caa469ebdd0ae3cf8ffc69b2a5394fbf7f697213a73976a3d77389baa1905614a2eab7e1696f65593c15ee1a5175ad671dadeda2b6a938aff5e3947d09774fcc7f05cb3c6de65ab38d95093dfe0cd703e1b77cd7310b78c5fa69f93ea3c0702c0718c7c2de56d4ddcc63e5ebcecbe15af1f07bbe4cbce1f99b3a33ad5ade7a8adbd6d9d3ff00a72e456b8bc8dcd0bbf77e61b3be6370b83bfa55e8dddb536a4b5e6273abce975be339346ef174946939eda893ebfe37e3f1ee177b67393632ef3d908dcd24d414b68cce3ab56b0a11a757e168d9636d4a367429c20a32515bf0792ef17ea2f627d5dd8e5a8ab1b7545cd4f49b32b2ab52b3dd28a5fc186b4c73b7f2fd8cfd85c52b78ee4b7b255cadbf1e776fde9b92fbd1a6f2bea3d9f18aaad720e33537a48e84ade34edee6eaacbb23dadc767ced79c3af7a8bce5c2a774ade954f7f8d6c84639ebe3b0714af6795b3791b4a4a14daeede8c3f27eb9f1ee271a96f3a7ea5e476938f9f26e790c459f13e1bfdbad3b6157d3eddaf7de8e0343a7b677d91af7b985eb3726d6fc9161bb9f71adf2bea2f21ea2dc4ade842a7d3cbc2dfe0d3ef7a6999b58baf283717e4",
            "fa1f0d87c059514adeda31947f63233a56b770f4a74e2e1fc1171aa5f1f7dd7c9f6bc67235aefd38519ed3f7d1d0789f4d7fbecd53beee8387fe4775c7f1bc35a4d5576b06dbfc184ea65a3e398b790c5a54db5bfb4a5c6c4e38638469d77caa3d268ba3426e5af0bb4b785eb167799dd3b6a339a8b7a68e4b97e512e475270bfee94937a6673a6b93b4c165235252d7dcbdc996b0fcbfb7ebf1ddadf8cd4ad4954bb5b94bddb2f5f606c6cec653a4b55fe0daf175e867b0d1bda55128c23b668796e414d5eca8c25de93d7834963d1e1cf71afd9f118cefd646bfeb52dad9d5f1ea5758c851a535b4be0e7d717f52e23e9d26932fd9e5f21c7693b9afdee9456c94f2d740b7c7558d2929cb518fbecf9d7af0f155f27db6ee3eac3df5f9360ccff52118aaf696f6f36fcc7b9238af20c95ef21c854bc9d3a9f7bdfb18dcafc793cb9cbb9f5840010e0000000000000000000000000000000000000000000000000000000000000000000000944128090000080de809000025104836944908925355d39fdea3f92aacbb2e23072dc5b5b222938bfc96a74df63937b7b255c7a7d61d15e3187ff4d2bd85384eba5bfdcda6770b2f5ea63ea52508a4d794714e807378e32e636b7f71db437ad49f8d1f41d6af82baba95e5ad7a6938ef6a45a3d5e1e5931704cd595871ce5ae3b8c1ca7efec76fe3786a375868dd2aea4a71f1e4f98fad97feb72393b7aada8c9f94ca707d6ecd60b1d6f650ee9c69eb7b6368ff009125afa9ac38fab7b4bbaed7849bd9c133188cde6394ceae36e2a3a74e7e545fee66af7fa8482e2b528d36bd7ad4f5adf9de8d67a37d4ab3c7652eaa66aa452ab2da7264ed7ff95be9d5ed38f656e2c29cae2acd382f3b665b0b84b7a91f4ee69aabf1e4c0f21ea65a5dd9b86164ab49fc47c9b2f4eefe7531b2b9ca47d17eebb83af8b93713c8b1969c5ac5df52a4a0b5bf6398d1ce2e659256f4d6da968da7a93cbaa66632c65947d487b6d1ceb8927c6326ee2a2fb94b7a0de5eb75db2d384c28e361f511f097c95d8f17b3ab53b61ad7c9ccb99f5fe56746369457dcd6b48d8fa57c93279aa0ee2bc24a335b4d873fe7de5a6d59caf438e5174a8cd28b5e5235ea0ecfd1964d515dd1f3dda3dbc9709757d526e4db6fd916b31695f0bd3fba94e8ea5d8f4c35cb5eaf7f1dea2e3af6afa15ee20b5e34d973995a7f77b68bc7c7bfbbe627cabc6e392c96665529d79c12a9b7e7f73ea4e099f86371f0a3789546a3eec473e16cbd3d382e1d5f05879e42b36a715dda6704ea7758b2b7b7d5f131728d18b717e4edbcdfa9329d195a59c7716b4d2398d2e995b7399cee7d351aefcfee56ff00e239b1cf28e252c577afa8557729bde8b7ea64b1d172a5527182fc1b4f3ae1390e1970e13efec4fc7835d79694b1f3a53a7b93f9d117a8f36f1d974ebbd09c3db662f2394c95355234dedb923a47536b713ca4216f429d18d44b5e1234fe814a957e395e8d46a9c9ed2660f97f14c94738ebd2ad374bb9bf043d4e2e2971dba274938cd8626f257145c137e5237abbb59d5cb4aacbcc19c93a6f7394a1978d1a9dfe927ee774746955a51941ee7af28b6314d6abcd5b1f4a3493a5a8b65bb58c2da69d749ffc1efa741579463296b460f9a64618ef4e9d1f3bf766b1acc2e5d33752a52acd3a691667dd39a5a31fc7aee8ced556af5125afc993a391b4b89ff866a497e09da33c2e3f5557b654ad9d493d78d982a39db7a15e4aa4d351f3ad992cfdfba96ae951fd4d7c1ce6582c85c5e394bba316fc94b1d1c1c78d9dbd9cb3a87759db886271f19423bed6d1bbf12c1d0e3f8ca777e3ea66b6dfc98cc1f09b2b751b894632ac6c556daa51845cdea9c7e033cb8e6da5739cf5f4eab8ca32ec7f269d42b579d45f73945fb9d0399e46c2f31d3a70847d58ad26728c6e71e3e75695c475b6f4d932b5e2e28dc2855a0a0a11d77b32967424e29f69a0e3f2517918d4757eddfb6ce836dc82c5538c7be3bd16f68d7971923336d25e9c69ba3dcf7f8305d56b28be37395496976f88995b7e598ab2839d4a90daf3e4d2395725a1cc2b3b4f59468a7af7299e51e76587b3e5efa69d",
            "5ca548422d2ef6577f42b59dd41d29b6ff006fc9d4798e170b80a0dda5584eb3f7d1aa71eb0c7dc577757d5e2bb7ca8b660f373e3f5e9b1e2baab96c07169d92a5514a51d6cf6f4d3235b9054a952f1b72949fbb3079be4388a90fa6852a6d2f1b30365cca780b94eca09453df8265adb8f9fd7fafa3ecb8a56a9710ab0849c1792d757f398fc0713f47b17ace3ad7c9cef15fd4755b0b1f4a56ee53d68e75ce3a897bcd2b375d3853ded2d9a4cfa4f2793b7938e4b1f52fe7757947ba2e4da4fe0d9d722c35bce5156f0d7f073aa55671d422f4b7ee6cb6387b2bea2a552e22a5f3e4c6b971c9a9800b30000000000000000000000000000000000000000000000000000000000000000000000000000000004a2511b098156c11b1b02af72514a2530857dde0b91ed74da2ca697b91dddafc1686d769dcdc5b3ff0ce507f9467f1dd41cdd851f415c4e71f6f2fc9ae7a8dbf62e39a8476a2b64a7dabd792c9d6c9d7756bb7293fc96e94a9a8ea74e2f7f2cf2c24e72d9794a32dc7e4b2f8d44ada2aaa7de9c77bd1d038f74c61caf1eeb5bd6f4aa457b2f939dc62fea231fcb3e88e935afd3e25ca0d3935e16c8e9b716332ba627a73c2eef8b66e2af5fab454bcefd8ebfc8afadb231858d838d37dbe7b4f0db507385495cc1475bf26a19fe5b8ce3375ebfac9cf7ecc97a9849845f9429f1dba97d5ea4e4fdd9aff003cb69d0b19652ce3b525bd23276559f5024abd392ed4f659ea1646df038458fa8e2df6e834cb965c751c4ec71590e57955e9c1ce49f9f1f07d61d2fa94719848d0bca51a52a515f071be8e5aeef2addc69a945ed9d3a17156eee2a518fda9bd69091cdc18cded99bfe636f533518a6bd34f46a3d5eeaed8cacd606d9c5caa2ed6916737674f1b2dd49ea6ff273ea5c02e391734a17539395bf726ffe08bbfe37cee5ff00cb65e99f0875a2ebce9e94df76ce8592c6ac75151a6fceb478731c86cb884e858dab8f76945e8dab8cd8ae496b1b8ac9e9adf925adf58d2adf8e5cd5efb854dd4dafc189c7726b8e219d842e23284673d68ef5658ab6c7c553704e2cd33aa3d34a599a54efeca094a9fdcfb4845e797a61f9ff001fa7cea8d954a74538d4d6da472dea5f4a23c668d1ab429ee9eb727a3b170bc94a10a58faeb72a5f6ad9abf5ef3d3b1c454a138bfb93d32b5cdcd8cfae55c3b31796d5559e29773de9a89dbb8de26e7234610c9d17193f968f9cba4fcaa8f1fe4d4eb5e69d194b6f67d676bcb715c9234678d704fb7cf691fc470f9135d2bb7e3b698c4bd2a71dfe747b2dd56a32728b6d7e0bd46ac24d52a8fee3d4aa53a7f643cb34e35fdbb6a39acc64ad6b6e8d396b66a3c873d5e714ebefbbf73a7666a50a16939ce11eed1cb6b626e7905ece3183eddf82d5e8707263276b789ca5ee4a3f496ce5a9783a0719c0dc62a97fd449b94bcf9345a14abf0dc95273a7f66d6fc1d5acb271ce58c2e28a5e179d158cfc8e4c72f8f1d6b6a90b95535dc8f4d78f752daa497fc1768dd537ba7517dc5db752bcaae8d35e1178e399d9f181c966171fa3f51713ed82f3e4d7aa754ed73509d0b6a8a4d787a6787ae57bf4d8ff00a5a9351f8f072ee9fd851b7adea2aae5ea3f921d133db7b95c54bdbef136d37e51e0e5b8bb5fb3b5a8d46be0c864a5470345d794a3b7e4c56322f955daa9b7db1652b6c33d358a16d714ef54772edfc9b763f1152ab8c9d4696bf25eca606ad1b88468c37a32556dabe3b15eacd69a456ed39e72c62ebf1aa77757b6772e2bf935ce71c6af7098f75716e5524d797132b6996faaada949a7b369b355676b515cc14a8ebfdc532db932beaf95afae6fd576eee751cb7e5499e7dcae65b8d571d7c6cde7a876f63fdda51a6947ba5e7462ff00d115ee2c7eaac5392d6de84797cd8e56b5995aed6dd4db149d382ed924c8ab69734abba138c94d3d68ce62b85dedf2537069316c7363865b61274e9ef71d7f05eb5c55cdf492a74b4bf3a377a3c061420a55bc6bf25d95cd96120e1a8ed19dc97fc75afcb8cca9dbaee5a968c4d4c4d7b79ea3564bf833194e52aa6fd330f4af6eaf26da8ecb446bf8c4800bb20000000000000000",
            "0000000000000000000000000000000000000000000000000128680804e8010001a0048604123c100492420c09f624a7c93b08d2b493f729697714f92513b4abf099553d549f6bf62dfb9547ed7b2769abb251a52d221a49a922dc9b9c8b8e2d45792db27c5739c63a92fd467f03cff2f81ad0f4ea3f493f28d762926bb8bd51c145466d34c5abe1959771f50f4f397d0e6766a33a918bd79d9c9fad36f694733f4d4aaa73dfc334bc1e4b358d7bc3549e9fbf69e3cb646fef6fd54c9b93afff00b0dba33e7b669b0f12e777dc4e4e8424fb4a39d72e9728509773735ee8d66ad78549ea5fa8a676de9c54d4d79f8d8facef25b351d4fa3fcd31fc7694a8e41a5b5e3675ec0dcd0ce5d4eeec67154f7b67c9d2a6ea384a33d7f0cdb719d44c871aa10a169524a2d6a5e496bc5cfebf5d77a9b29dccb76f2f34fdf464380d0b8b9c44eb45c7d58c7dce5b2ea4d2bbc7cfd77bab35f279b11d5caf85b3ab428b9272da5a0e9be562cce7b3946d79542195a9bd4fe5fee7d3fc1aef1b7fc6293c6f6f776fc1f2071ce9ff0022ea8e55e429a72a7396dcbf63e9de0f80bce0d8ea7695bb9b51d7910c392e7f5ba454a71eca8fee4534ef674e8d6a3574e3a7ad982ad90b99dc77ada4cb198c855b7b4949b69b456dd3ab8787dbb626ca852a3c8538b5b9cbc68c0f5f3136f5ac69c6e1aee947c196e2d6f717b7aefaa6fb69bdece53fd40750257797a36b4e4daa5e1a447f0f264c276e7d438b5a5b529d4ab349fba372e9bf3ec6f14c84215eaee9a7af2732c8e56f6f2ac3d37254daf3a3177925dea3a97790f27f26aee3ee7c572cc1f22a71b8b4ad4d49afc99bb4bbc7d097757ad07ff27c45c5efb90e2d7ad6f5eac2925bd3665ed3aa19ead97a36f56e26e2e4a2fc96c7a7463cbb9dbebdcc51b6cbad50f31fd8b38fc5d0c72ee8457722cf0f9fabc728dcbdca728a6cc9dba571dcbd8d2349c8c2e7b05433f6f34e0bd5f8d188e3f7757885476f7af549bf9370b7ad4eceed53947b9b346eafc67f46e74b719ebc689dc6d8ddb74a19fc064269d2a90eff009309cbfa9787e156d3aaa71751af1a38860eeb236d42735527dfbfc96f2d82b8e491eebfab2ed5f9656d6b8f15af367b93ddf52afe551777a3dc7aec70f5ecad1c6d93f520bc1778de26d71137428c97e0db2c31757eae13f78c9f92bb6be9d38ee472dc82e33b4ad321eaaa2e696b5e34767c458d2c5dbdb3b3f2e714e47a79be0b136d674ee9c21eb456f7a3c3c3b254726fd252f31f089964636e9b3422dcd4ea24d98ae5d96850b06aa6a30fdcd9ecf1151dd465564fd3673feb65252c7cadec67a9b5af04fb4639736988c5f22e3d6f1752b4e1dc996733d51b2acbe92d66945f8f0733b6e0b94a98f9dcd4ace3f3ad9ad429cadafe54a537dd17ee532ce39f3f21bcf22c2c73abea2da5ba9ee7a38ce42eb054256971a716b5e4d62872aa98c5daa5b31f90e575eeea77463a32b77f14bcb8ff005d1e186c65dca5793ecdef6cabfd4d6560fd0a2a3b5e0e776fc92ee54bd35dc93298d64dba9393ee29ab51792375cc72593a3296d25a39ce57213beaf269bd6c9bcbdaf713f4d4df69eac3e02792b8a74a32f327a271c195b72ea31549c2a354d45f73f936ac4e22a5bd25371da66f195e945a718c0432b5ea53739477ad9e2e01776992ab3a573dbdb17a5b3598b6e3f1f2feb91000870000000000000000000000000000000000000000000000000000000000000000025124224010480234344e8689d88d0d13a1a20468689d0d11b46d1a24689262500904e8b51a2468948688225ada091315e46916e9315b5a5ee44233a953b765728aa6bbb7ee5c8a8420ea7724cb68ded1710ec94692f327a3a770fe8066b9562257b06e1b5b8f834ee19818722cbc2552b28c69c9369fc9f67708ced9e378fd3b1a0e3b8c526d0937f5dde3705cff009b711e9ef4aea71bc94edb2bdb36dfe0e69d65c7d1c57339d2b74bb524f4bf93e8fe5799a38daf3bdf5137b6738c4f02a7d47e611cad797751525b4fd83d2f2bc29e9262e0d71752954dfd3a8b6bf06d7c37a579de69353a34e50a4fd9b47d2b9ce8461aaca94a851878",
            "d7b2377c263ac788e1a8dbdbdb46338eb6d4469e74f16efb7c7fcd3a359de194d56ab194e0bcb691a44b55b4a69f747dcfbf79550c6729e3573f54a1df083f7fe0f84b354e8d8f21bca54da708549244fc579387d66d8f9d38d46a514d2450e9d2b8ad18537a727a3d16f4eef25731b5b5a32939cb49462756e33fd3be5afe952beaf55c23e25dad11f7e32c38ee5751ddff00a76c253c270f8dcbed6dc7f0742ab528e526a538a343e1d3b8e31898e2f4e692d1b0d3c8d4b7a6a6a0d3fc177a38f0ebb7bb258ca4a0bd35ad1a1f3dc9fd1d3a342316dcbc3375feeaae29372f0cd5b336b0c95c2f529f776bf72b9c7670ef19db2dc5ade95bf18ab55e94e706ff00fc1f21754e9549f2badeb269393d37fc9f56c6e6a538d2b687887b34720eb7f06a977ac8da52f315b7a452cba65cf3df7b72bb3b4a2e34e92ed72691e9bce3f1b487d43a1dfaf3e11b5f4b3a7175c9aba9d7dc143c7947659f4eec6ca9ab6ad18546d6bd8cf55c97823e52bae475eaafa3a31f497e9fc1ebc67189c2ad1bc9565296d4b49f93b173be8752a346791b2a693f7d24726a58bc9e16f1cebce4e307fa5fc9a4ff00d571e3d7d7d4fd27cf4258685adca7e2292d9b8d1a11ab5e6d4fd38bf66cf94715d68bbc5ca345da3a71a7f3f932d98fea1ee2fe84695bc654a496b6bc16dad751f4dceae27172f5aeaf29ca6bd9392395f51f9353cb5774eda2e505e368f9d335cff3b94c8c6aff0070aaa1bfd3dde0e93c4f9350c85b42dabea759ad6db236d3872ddd3d742e61689b918acbe6ee2a6e341b8a33794c3d6a51f59536e2fc988bab3a173435b509ff0024ede863669af5ae4aeed6ee1395472db3adf1ecf46a63e35251db8ad9cd2871b9caa29396d236cc6ddac6e3eac250da516119e7d3cdcb392bccca76bea767c7b9ad6273eb87dcfab2afdc9bdfb9a2f28cf57ab93aaa8c9c3ee7eccc2c9de5e34aa4e72dfe594b5e672f3eaea3bb5eff005094a9d250a69b696bc1a0e73aab5331712a9352d3fc9ac52e3f4dd9bab56a6a5fc945a60a8d6f2eaa7afdc87265c995af65ef39ca5cc254a84a51a6fe0c1d355b2171a4ff00c92f9364854b0c65374e54a327ad6cc45370a178ee63f6c5bf088572efeb2769c1abb51ad7155763f3a33b4e860f1d18d2ab463297e746ab7dc8eeaace14e9d56a27b6f61095946b4aaa73d7b6c85a6b4720bbc7d2aa95ac124ff06bd715e751fd8fc08c2a5dcdb96fc1e9a765184772922d15faf1d3555f9516d993c5df5de3eb2ab14d35e51eac3dc5b46bc69d48a66e9470b6b7d4e0e9d35e7f6274be18f6c746eb9273ba0aca55e5e8c56926fc1eac5f0dbde335652ab59773fc1b9d8e3a971fb0f5a92ed9ebe0d7ae6faef33732dc9a49e8be9dfebaedc680051e30000000000000000000000000000000000000000000000000000000004e827a2bf1adfc816c9d15c22a5ee4f6f9f04e92b7a689d15ed3f0c7c30853a1a23bd9579944085e587e1e8bb0518c3ff62950f3b97c902849b2545bf82e4d2a4b6be4b7dd297e94dff049a145bf641c5af72aa757d3fd49ec4a15aafdea1271fce88d1a5097c12d68bd4e8b71ee68a1c5b9132194d28d105d947c248a942328f8f724936b2d76845c6e315aa9b5f82230eff11f721326909a93d2f7264a54dea49a4666db8f55858fd6cd7dabc97b0f67699babf4f36d4be02f38f6c14e943b14bbf7b33bc7f86de7236a16aa526fd9245ce47c2af70f1a751539ba32f67a3baf417094ec6d68de55a6a4d69f91eedf8fc7b6f6c3704e85e57136b7192bfefa308c77b6b4453e653c3c2ea859d475a54b6bc33b2752f9ed7b9c4d5c65850ed528f6c9c51cdfa71d3ec7d4a1777579514aa54db6a4c8f79fc7ade3f1de3e3dd9db91e579d66b3d5656ce137dcfd926746e9764f29888c69ce9ce3297ec67170dc4d9decea52a74dc94bc2377c5e26ca8d92b99d38465145666e8c796dffb3253e4d52cace3737555af1f25365cf71794a738d7ad05dabddb2dc2960f90d195a5d57853d2d2f273dcc74f6b52c954a78dad29516fc38b34c32da7871c6fd7b737cc695dde55c6da5cfd95771f0cd5abff004e73bb9bc97af292",
            "acfb9afe4bd4f815ce2b254ae2a3937ddb7b3b8632f252c451a114dbed48be95f238f1ad1381749711c7e51ad714e139c1efca3a15c5ed34a346de3d94e3e3c2229d8787df3716fe087652a1069eb5f961cb87176c5fd64696414153eedbf7330ab51abbee8a5e3d8c652a508de773d3f2666a5853943d5ee4bc131ae5bc5a6df659d1c8ba49ea1bd196edff00042a45777714e4705695ea2a9ddf7ecc9dadbaa36aa1adc57c93626e7fe31d529535db2f1ddf817b42df21692b5bb82d49696cf4b78ffa88eeaaeefc6cd5b9ae6ea5ae468d1a0f516d7b117499c56f6cee038fd0c0509bb54a3ddf847b61692b8a9eb4e6db5f92bc17a9718f8ca7e5b44559ca8cbc16c6e2e7e49715b9d7f5aa4adeaa7283f1a6685cbf81636770ae66e318b7b68e91678db8aca771382504b7b380f5c3a890b1b97616759baa9e9a4fd8cf92cfe3199c9dd66b92703e2b90c149d3951a75e11f74d6db3e79bae39751c955a1468ca54e327a92fc1937cc2eae2d53ab75513fc6cf2d2e677b4771a5494bf7d195ed8f2e78dfaf758f0c856ed9dc4fd3d7bed998b39d871cba8d58dcc5f6bf6d9a8d6cee62f1f98ca317f85a2edbe067925dd56bb527f9636c71e4fec743c8f58694edfe9e9414f4b5b34ab5e5590c966211d38c252f645cb1e316765353b9aa9ff2caf23736561aa964a329c7f036d2736574edf8de3f2a985a3734e3dd292db2e5f61e9d1c5559d74a2fb5fb9ca38ef5aaff001b495b5c47ec8f845ae4dd5cbbcb52952a5b5192d782ed32e7dc691c93b2399add8d35dc5a59154a114a3e7479aacdd7ad2ad55fdd27b2874fbdefe11570e595daed4bcaf74fb54dc625a8d7ab6b53eca8ff00f922734beca6bc9efb3c6af4fd5afe3f90cf6b54ab4ee1f7557ffc962eaace72ec5ec8bd71383938d2f6459a3dd5eb469c56fcf9217bf17acac275f726bc2f92ddd39c6a76aa8da5f1b33d795218db1496bbe48d6bb9caa39bf908de9e8fadec4a2a3a2dd5b897b6d944a2dfdcbdcd9f8ef04bdcfd1f5fb1a8fec5a426eb59a15650a8a716f68e93c23915939468ddd7516be1987b5e037543291a5383ecdebc9b272be92d3c561964edeb38d4d6fb53123a78f0ca76d87319eb39c234a8d58ce3fc9ae66735431308ce96b6d6de8e6f4ef323426e0a537a7f25bbcc85dde3edaae5e3e09f65b2f22ebe3c2002ae10000000000000000000000000000000000000027404004af701a1a274340468689d04808d0d15686808496c3f7f04a5dcf48adc54179f7260a16fe0baa128a0e1e9c14ff24d2a57378daa34a536bdfb504a9741fbc8ad462a0ff25ca78dbeafb5e94d76fe51664a76b53b2ac36d7c016947dcae1e0b9ead3ab2d461da2a526d6a248a153ee96cb95a2d4372f623d58c61d8a2dccf6e2f097b95b9852746a76cbe744af26fa8c9707e2373cd3291b3a109349ade8fa3719fd3be2f1f69495cc17a924b7b3d5d0de9bc38a50fee15692efa893fb8eb3712ab7951ca51d25ec5a62eae3e1b3ebe7de45fd3a52fee7095bc1fa6fcf82e735e9a60f8a70ea952518fd4287fc9f414a551d2dca09b4b473fe5fc3ebf2e6ed6517d92f04faaf78e7f1f15f7559ce7e9c64e3bf85ec5d8f6bdc5ad4bf0cfb2f1bfd3e602df13528ca943ea5c77ff0027ce1d50e9564f89e52b56a749fd3f76d7ec56cd3972e0b23408c1d393eff62e5ae2af2fa352a5ad294e31f2f459ab72ea43b1c3525e3676efe9cb11619a9dc5bde7a7e7c6a457eabc5c7ed74d27a75d3dabcbdd7857a725287e9d985e5fc6ab710cd7d2d68b4b7e0fada9f0db6e2b5ea57c7c23a6dbfb4e13d5ea2b3f9c8518d27f51bd2d20ecbe2df5e9a2e36eb2398bca58ca106e8cda4f48ed7c7fa073a78fa77b6f17ebbd499e3e9cf12b6e374a9dce4a92f53c35b475db5ea051b0b75e8a8f6a5a4837e1f1ab47e7fc76385e336d0c9d28c5f85b631f90a3c7b8c52b9b4695371f3a29ea55de439959a7536a843ca349c45be4b3ca9e0ede6dd34fb5a33b83af1c663f5d038772bc5726a5734e4d4ab69fb9ac642a663177171f45dfe936ff0049b7d9f4aa1c23152bc8b7ebd48ed989c7728b2c5d0b98e5547cef5dc56e35",
            "bfb4f5db016197b885bcabdc397a8be0cae173f95cdcdd1a6a6a9fb1ece2f89b4e6d7cd5925e8b7e74673905a5af0692a5412eff00d915f5672ccbe39ef35b2cde36709d94ea7a8df9ed3aaf4aa8e4eb61a357234dba9dbef234eabce31d082ab7ea127fb9bef0de5947296f18da452a6d7c1af14d33caff008f4df62ae3217353fc7e23ec786caeaef1b5a50a917db17e0dce30a917dd16bcfb9e1cad9d0ab4255371ee4bc9b18db95d3cf6f9685c537526f4d1a8f29e7f2b2eea517e5784646d251b8a92a14a693f635be47c36a56bb552a4b69bd876f1f1c9dd38a720bfca5f294d3f4db3a22bd6e4a9ede9a30bc4b8e428dbaf4d69a4652b57b6b6aea84a71553d898cf92e37a7abe86353fc8d97d2efa4e8c7ddf8255ad6f4154525dacaa941c60e71fd4bc92e3bd573ce5b8bbfc5d67754e52d7b9a3dd66ee6feee13afbee833a4f26af7f91afe828b70de8d2f25868e3af69aab1fd4fc99e72bd0e0e49eacfe0f99d7a708d169e97836b864a15adfd697e3658e3dc6f1752ca35a715ddad9ebbac751749c697e9f618e15c7e4658dbd351e47d64a78ca33c752fd52fb768e0bcf38bd4c9d696665537ea3deb67d119be9861f256352ea297d4a5ddff27ce5cba9e7a9661e29292a0a5db12971b3eb933e39676c4e0b8d5a5daffa87a48d86da8719c6c24ab4a9f747f264acf83dfd861a5755bfdd1da3946668d5a590a90adddfa8ab97971f58d9f31c8b18d4a165186bf635a59cad4eaf752f08f3fd2d3f0949b6cf651c1d4947bd497ff24b9376d79eef2b7579e2726917ec62a9c5cea49bf1f2513b7f4a7db2d6d0ab754a947b1c77fc05b762251a57b71db169793d3758d5674d4b6996ec7d1a2d57ec7e7f27a2eef3eae1a4d69178bcde98dab08d4692f71e9ca9af4fe644460e53fb5f945d753b26a553dd1158dfaf6d96155182af57d979f2797237aebcfd1a5ecbc7817197ad5a1e9c7f49e252549f77cb21038ba2927fa99b16131b4ede84aeebebcadad98ac6e3eadf54f567fa1793d599caea8ab4a2f5dbe1e885e7c63b25792bbba92dfd89f83cf3f0968851fb77f223e7c3f7254f64d394bd45a5e3675be0dcdedf1b64ac9a8f7bf072db78c68bdd416971e864e15d36a0a5b2cd38f392bbbd7bba9714fd7a705bf74cb14f257b998cacae37e9af865ac6729c6c30aa52947b944d5e9737a50c8b8d292d49e897a787263a641e0f1946eea42718f71e3584c346b49d6ed5e7e4db71bc7e1908abfa9523a979f734fea742db1f38c6d27e75e74c965cd8e3adb96000cde6000000000000000000000000000004a20901a03e43027b5eb6550a52a9ec531db454a5287b041d9d92d485471dfda894d3f327e4a9b8b8f8d6c9e96d55bf8048234aed1a2541c9f80574e7dac688b724e2f456a9ee3b26a34ded94a729bd2f62749424e0fb8aa6d496d93e979fba492fdc9f4e327daa6993a4226a5295386fc4b47d71d10e8a61a5c76192bf953ab2ad1debdcf926b537a5af78fb1d2ba6bd68ce715ad4ecaad6a95addb518c5fc169357b74f0c9edaaeb3d44e9e6330f715a56718463efa35be31d11a7cb27f57529a74e3e5f82bea1f34ca646de9ddc6da7d9349bf06efd25ea0d0b5e375a35f54e6a2fdca64f772f0f0cb0de31f3d755f87dbf13cc2a36a9462bc348d3fd5d50efd793aaf53ed7fd4d91ab7aabaed526ce6379b5ab3a14bbda7af0b6c8c6bc5f27c7b865d37de87705a1cbf3d1faa8a9d3dfb33ea7874a38fe33b152b7a6a715f83857f4e2aeb11918cee2de54d3ffc968fa76bdeaaf514e2d3f06b1b70f16b1dbc755c3176d08282508af82e585ed3caf9a2d4547dcf45c429e4683a52493669b93ab3e32e6e955f12fdc975f0f15e4ba8d83279785a565477bf3af064b1f522e8faf08aeefe0e511e5f1a97cbd5fbdb6742c4f20a756d1254f4b436d79fc5b8465ad69dccef677329a505e74718eaff0035c664722f155630eedf6b66ff007fc92a42b4e953a9db192d7b9c7398700b8cf6615ed1df7396db22d6538bfd63ae3a7b81bec3cea5adb47d792f748e738959ee9c7248ca9d3a8a9ce5af09e9ad9f4bf19e3d0c7e368d0ab1529a4b7e0da6e383",
            "e03278b9d4bbb7a72afdbf6bd794ca699e78632cb1abe3f9850971fa77b79714d7dbb945bf26956b94e3dcb393c2a518c3be12f735be5dd30e517b7f561655aa42cd37a8a6f5a3038ae3794e2d92a74e309fa8df9912d2675dff0092622cdd0a718ce9fe9f83489621cab287aad43bbf25d8e37397768aacaa4e5a8ef473acff0036cb63afde3fd0a9169ebbb4435c797534ed3c86c2de971470a1710553b3f271ee0599abc779254ab5ebc5a52f96627259be4b7b6aa14a7565197c231d4b8466aea8caeaa4ea426d6ccf6e7e4e4afa1323d46a39ca31a33b8838fb6b6730ea06223948395b56f0fdf4ce555219ac45db8cae67a4ff00f22f4b97e428dc42352aca505efe46d94e6bad3baf47b274f8ad9494e5db24bdd94f50b99595f5475aa5784a5fc9c7725d40ad3b556f669a9c96b68c759f12e47c8697d4cfd5ec6f7f7ec84fe6b8fc741e3bc66b73ac82a74bb9d2dfba3bc71ce1d1e21671a5ef248d67a0d84a184c7c28d5a89dcebfe7674dbfa176aefbead394a9b46bc6b639d8c25cdc5fd76d519348c5ddd7beb6a335564ded1b54e9a54dce10d68c05cdc2b8a8e8ce3ffc9a67f3a76f0e737b6815b2977635a752949a7b33586cb5f5fd0f5ee939422466f01253f569c7ba3f3a368e2f6d6b57172b795249b5ade8cf0defb7765cd8eb50c7f26a746d9ca9475a5a39c720bfc9de665dc519cd462f7e0e9d4f8ed3829c230fb7dce47cff00955af15c84a936b7bd346d6c70e7cb8cbb6d5c6fa8f77755e38ba8a6e51f0db3a2ac8c6d2de2e6b6e68e29d3ae5d84cb5ea9a8c15793ff0093b47d2c650857947ba1e1a2186594cbe2f76db53a7ead582ee97b6cd7725c69e52e557925a4f68d8b21714af634a95286b5f82e5cd3a9638f75e49a8a442b32cbe4797198d95adbaf0fb11769d3552b697881e1c2731b3bf72b495449ef5bd99c96328fa7dd4ae179f3e1932a3bfebcf694bd5bb9d14bedd1f3d75f6bdb60b2509db38faddff076de55cc6c78863ea547562eb35f93e46ea367ae793e56a5ecdca54fb9b4533679db1d438de5ee391f1ca54dcd3f1ec73fe6986a1633a93ad4d297c3d16ba61c9a542fe9da4e7db4d3f966d3d64ad6156ce9aa1520e724bd99124a5cb1cb1e9c615493a8d423dcf7e0cd5ae0f37736aea538c92d7b1d33a49d34b4c9d9cef6efb2a7cafd8e958fe3f8fa127423463dabc7b098ff00ae79e3db36f946e7ea6cea3a77106a6bf26f5d39e9ccf965455ebc7fc5efe4e9dcbba436d97aeabd184579df846cfc4f8dbe398b56f4128cb5ade8b4c56c3c7b2fecd2727d28b49519dadbd38b9457c1caeefa6b9aa59276d0a6fb5cb499f4e5953ab65732af59a96c8bea96752bc2baa31528bdef44dc65745f1a651f30726e0195e25469dc5c45b52f3ec6b752bbb95a71516be4fab3965bda729546854845c62b5ec681cc7a474d593ab8ea6bbbb7fda8ad8e5e5f12cbd38953518d37e76c9b4b2ab7d594229ebf27aaae02f2cef9da5c537069eb6d19e83b4c2d1ec738baad14d39bd35f631f757b1c55afd343f5e8c1799c9d493db67a723277359d66f699e75eda222951bf246f4f6494928d2e39ba8b4c8d6a3da445e837e46c934b8af6e214bd153976966339539a9a6f69ec3652c84eeb65a3cfb2d6f68ada9d5928a5af730f7f98bcc9d4efb8a8e4cf1a4813b4de4cafdaa00042800000000000000000000000000009449089d048068ab5f6b611a505d84f51f0bba5f836ee99718c7728cbab4c8d654a9b696db365ea374f70dc33905942c2e635e84da72d3da0db8f8bdda9701e0d75cdf9051c76a54a137e64d68ce755fa533e9cdd4292adeaa92decdd6eb3b63c42d68e4f12a3eac21bfb7f2695caf9d5e750a949dc294abc5784fc8f68ebff008b8cc7ef6e790f316dfc12572b79d2aae8ce2d4f7ec44a1d8fb65b4cb4ae1b8a90a0f7b134e3e4aa127ad344a262897dfe11736a851fb56e4cae343b693a866fa7d89a39de4742d6e1fd9292f7049de9e7e3dc3b2dc9aaf6dbd0a9dbf9ed323c87a619ce3b4956a942a4a3eef51f63ecce2fc2311c5f1546b50a109cdc53f08ccbc3e339459d7a5796b08aec696d1692379c1febf3",
            "d29cfb54e3576a69784d7c9d3ba09c223cbf912fadb77e85269a94a3e199effe87dce5ba915a87a6e9d82abbdebc35b3e91c6702c5f0ec75bd3c6c631ac92ee715ee4cab6185c72ede1e61c7b05658276f3b6a69538e93d1f30e7b3342d3312c7d8d550a737a7a67d29d46a3717582a8a9b7e62f6cf9032786952cc55a8eb77353dbf261c8f5273dc71d3d5cbe9df62eda2e9ce52a53f7923a27f4ebc231fc86afd7df4235649fb35b353bccbe3ef704b19dcaa5db5a8af766f5d03b0e45c7af54ebdb5485ab7b4daf1a2308e5cefb67bdf4ed392c0da636eb56166a9e97fb63a3cb8dce5c5bddfa3560f49fc9b44f3146bdc774a09aedf2632ad0b6b9ba73a718ef66eecc26f1d32deb7d4dbb9d3fb5e8d5f35c7ae32746ace726fb4d8295cd2b58f6d49248c766f9359d8da548d29a726bd898d38a6585ea34ce3dc29dcde4a5517e97f2748b2c0d3b7a2a976a5e3dcd3b8bf26a2e739569766d997bee674d4fb294f6b5ee3a5f9fdf3bd311c8b0e95f38c2a6b4ff00258b2be56f3fa69477f1b35de41c86fddf3a8a32f4bff231369cb5d5bbf4daf2be48ae8c387f5edd72ded5d1846b25dc9990a16d56bb8c949a8fca39ed1e71796fe9d1549ca0fc6f46db3e435a9e3155a316e525b6bf043879b09b64f2f79654231a092ef7e0d5ef70f6756e555ab463b7e77a3151c9d4bdbb771565a717eccf55c720a5795214e7251d78f70be1c3b8d82c29d3b7d6a92953d6b5a31dcaf8161b336d2bc56b08554b7bd1efc6e5ade34fd18b52dfc96b23777b75bb5b78b706be08ae6cf8ecae2d9acde3f874a54a542355c5fb68d2731d62a9731952a36de9c3dbc2d1d9723d34b3c85cceb656a282defee397f52781e0ecbb618cab094dbf7899b3e5c2c9d39864390d5bfaae693ee65fc1e2ab66aba856a6e2b7fa9ad1b971fe018cb5b5facbeaf1ee4b7a933099be4f431f72e8e3e31d41ebb9070f73fed5b6e3f80e231108dedd56849c7cf6b6652f7a9169678f959e3ad54bb56b714724bfe417b94a5dbebcd7febb2ee172d5b19197ab47d44ff3e42f336cbc77ab795c067e373514952eff0031dfb23ea1e33d76c0721c4c2379529d2a9dbe76d1f1c646b53c8cfd67414367865677497752ace10d7b29689c6e95b9d7dc167ccec3255674ec271acbff0057b2e5bd0579564e70ec670cfe97fea9e62ac6e1ba94dfb293d9f4e5de3177cea462a08de76ebe3cf51af42d295397d3d5d4bb8a27f498aaead94e3194fdbc993a98d9493b9dfdb4fcb6732e4393a575c960e171e61f1b1ad3ab0bece9b97cbe3b0985ab56ad687a8e1e3cf93e21ea967679be4f5e6a6dd34debc9bd756f99e45e6236146b4bb35ad266abc5b8a53e4793ecbb96a4defc99e576e6e6e2b9751b5f453a775efebc322abeb5e7b533e91a79bb1c7518d85ed58c249249b6707ab94b8e9753ff000b93a7af073fe65d4cc8f23baa55e8d59d3d3df827f889fa4d3ecbb6a58ea74d5d7af071f75e4d579973994eda78eb2a3eaf72d7723e729f56b2d6f8da36d2ab2f0b4decd878d7562cad2c675aedc2a56d78db24bcb2309c9b965ff14bb9e9ca3566f696cc8e03ad795fa27ea549b7edee735e73ca9f2dcbbb98c3b629e92467387632857a3db7118c63af7644bda939bdb2ff00c6e77b2b9e6f4655ebdcb51d6fb5c8e6598be8d95e54c7287728bd6cf7667925ce13213b6b47fe15e3699afd6af3baaf3ba947727e7646d9f3f2efe3cf1a9531b5bd6a527197c191a7699ee50f6a156ac63ede1e8f3e26da399cb51a137a4e49347d51c63038ee3987b7946da1394a2b6f434cb871b97ff8d67a258ebdc663a76b7d29536fc2523a350c7c28ddf6b7bdbd9e78dad3af5956a3054be74bc18ecf64ef31ff00e58c1bed5ee5e3d6e1c67c6533b7f1b06a0a68c858d28d4c62b8d6f672dc972377d0f52b4f525f932dc6b995fddd35614693943db64c76de0971db76a56d1b86db5e11aa726c8ab3aca95387ce8d93d6b8a14d6a0fb9fba3cf5f0546f60ebdc694bf725cf8f558ec1e2bfb8c613df6b66e38cc12a75e14ab47d483f7d9a05c656ef0b72a9dac1b86fdd1464fabf5306a3eaad48aaf949583ebaf16b5b4",
            "bbf5aca928d4d7c238ac783e5b25df72e326979d68edcb35579d5cabba91eea5fb9b25958d95b427df4a2a9f6f97a2b6383c8e1963e4cc8d0ad655ddace2d4a3e0b096a3a7ee6dbd4dab670e4d59da34fcf9d1a977c65f76fc95af2729aba41495b4fdfe0a08550d91b122920540a49404823636108000000000000000000000000000124909129007ec42f72ad0d0048aa2bc682456bc13a2aab5bbb8c757552dea4a9cff00299b55af1ee5bcaa9abc70ad5a843cf7cbe11a9c62e75e33d784d6cec5c77ac96981e2d57150a74dd5947b77a29946fc1949f6ad62adf10b192b0beb852bad76f6c9fc98cc571b862f2eeb38af45bf0be0d2ec72b4e79f790bd9b5073737a36ae4794bde41468cb034aaca9a7a6e08cbd2eddbf96555cbfa7f96ad5de571f6d29d2979fb51afdbf4f791e42954af1b3a8fb16df83eace89d8d6bde1b0b5ce505eb76ff00bd79364c663acf1b7b716f2b787a55138af074cc54bc132bb7c81d34c4e27219e963b904bd1ed7ad4fc79333d5fe178fc1ce8d5c26ea507eee265bad5c0e9f18e534f294374e8d7a8a52edf1f2765c0f0dc072fe9ec6741aab72a979dbdbde8484e0eb55f1f5055ae9c2d69464e72f1a4764e94f487334aee965ebd19c29a69ef45ce23d35a561cb67f570f11a9f6a7fc9f4d51b8fedf89a769428c543b75b44c9fead878d65dd538dbaa74ec614a536e515ad33d56b70b72529764527e4c3fd24e74652a3bee7e4c167b237d8db6977ed78f815d9c7c132baacfe27276d7399ab429c23dc9fea3314e1555e6aa49ca0dfc9c83059cab1bf75addc9d46fc9d370f7f757345bac9a935e045f9fc6987c633abbc9b1b81e2d7346138bb89c1f6af93e288cf2f7d5ee2ba8547dedbf2bf73e92eae71cbebe9caf6b39fd3d3f2ff001a3913e6183b45e8d3a71728f87e3e4ae6f3f3c24d76f67453a76f37c9285e6525d9084f7db2f93ec1b8a767676d4ec6d6de9a828ebb923e25c5f52ae71d9da53b4fb6877af63ebbe019aa7c9b054ee14d3abdbe76c9c749e1c62d64e946dd76d297dccaed28ab3b595c56979d6fc990c8d4c76112b8c955825bf9661b2b93a1c8add4316f71f6fb4b3d0e3ce4ba6b17d9ea97577520e4d413f730391af4669cfd6debe366d2b89d7506e6bcbf7347e5b88ad66a742dd49d49fb683d3e1cb1acc71db58661ea13d6bf0676ef054eda1a53dd4fdcd73a5d8dc8e26e37918c9425e56cd83a8f715ec2dfeb6cb6d456fc0539729be9ebab8375b1125569c7dbdcd2b11c49d4cc3f1f6f716789f552b666b3c7578c9493edf28dead22ed6b2ab18fbf92632c79f734cc63f8c5a2a5aab18ee28f7e331f46539507a717e0a2cafa9564b6f5f93d7fea3c262d6ea55829fcf925c7c996eb40ea150a3c726dd1694a7f072fad92c8d7bb8b8a92837ee8e85d45bda3c92f69ced25b82658b2c4dafd347ed5dea21d7c567ab6ce036369571d1ad775529ebe59ba4eff001585b39dd4e54dc52decf9e72dc9afb1579f4741c945bf83d1699cc9e7fbb1b5673edd7b87373632ddede1ea3750aeb90e71da62e4d5373d3717f05fb9e3986b6c0c6eeeaf14af35b7172f9340e56e7c2f2539c7ee949fc9aa64394dfdf45d69d49a8cbe3662e3e4e597a55ca731755aee56f42a49514f5e19afba34e124a53ee72f7d9eca32ad73b9496d7ee79ae69d3f5569f9434f37972edeca16b4683551b5a2ab9bfa72fb29a5e0f054ad251d37f695d9d84f235151b48ca551bdf80a6195a56ab7728f98354fe348bf56370ad632709766bdf46d3c6e8dac2ea9e2f2b4fb6a37af28ecd75d27c75ff1d8cad6117dd1f826475f1705cbb6a1d0ae51431b72a34fc4d7b9f47d0ea1e36bc553b8ab14dfbf93e73e39c0e7c32f6a5c5cb6a0fd8c8d5bba1797c951acf6dfc16c6e9db87175dbae72eea1dbda50763613529555af0723cadb5ce3dcf27566fd47e526cd9a182a30a74ef6bcf728adad9cf3a83c9ae255d47dade0f4cbe55a4fd2a9c2f1f9f31ccabdb98efb5fc9bce1383dae2b35f5155f6412d9e1e9edddbde62bd4b2d3abaf3a32f91beb88c5c2e371968ce4db596303d47fa5cf5c53c7d06a4b7ad972e3a4388b1e2df5",
            "adc3d58c7bb5ff000631d054ef7ea1cb7e77e49e4f94ce64f1ff004b8f7271d69a4598736335b712cb5d4febeb5be928426e2bf83c52b752d38545e7e0c967b17738daeddd2d5493f26320d525e7e48d3c6e4ded7214a3464a5eed1908723af4697a74db5fc18d7b9ad94a718f8619ccac7a6b5ecee7ccd6dfe49a174a11945af7459834fd8a25aee0bdb6bdb85baa76196a771396a2a5b3eb0e01c8315c87154a0eb41ca115e1b3e469d2a5520bcea464307cab2bc76a38595692ee7a487c6dc5c9e9f5f6776d355bfc6d349fc18ee40a7750f4634d3dafc1ac748efb2b93c5bbaca6db6b6b66f54142b55726b6932f1e8f1e77eb91e5f8cd79d6718a6b6fd8ca6068df71b8c2a4687727f3a3a0de62a15abaa8a3e0f62b4b5b8b7546508f72263be73df5d2d595d46eeca373522bbdaf626dac6b64a4f7f6c1162ad2fa5a728c7f4c4e5fccbac7578c4e76d6efeef2bc0db9f3e4f5edb1736e4b88e2d7d4e85cce9f97a6d98dbec2f1ae7366ab595784a6d6f499c0394f27b9e6570ee6b4a4e69ef4cdeba1969790c9f6ce5254a4fd9fb112eeb0c7c8b965a9f1b8d1af4788dacac29ebbdbd232f615eef298f74a49aee5ee623a998976b9aa35e9bfb13dbd19ec1e62da863549ebbb5a2da6f9771a4e5fa498fbdaf52e6a566eb4bceb672fe59c22eb8fd694dc5aa5bf0cfa1f1f4a57d78ee1c9286f7e59a5f59b25655ac7e9697677c7df45338f27c9d6fa706f55b5da53ec550a7a7e4a5afbf466e5402a9c522920086490c0800040000000000000094008048020120082513a2740121ec4b834b7b2ba3dbafb8236a57909698a9249fda4c5a4b6cb4a9a9455b505b7e4a924e3b2e632d7ebb276f6f27a84e6936ff045a9c26fa79a571e7ed8a48f5dbe3e1774bd5a7ddb5ee8fa2b21d37e1f89e171b9954b77753a7bf75bde8e5dc471d6747255a84fb6a53727a2bb7563e2675a052747eb210b98b5494b52fce8fb53a1dc5387dcf0fa75a8c294eab5e7bbdcf9cf9df15b1b6b37716d41297bf84677a15c932f42f63614e1515bef5f3a2d329b5f0e1b8dd57d415ec6963b5f4a9461f845bba76d3a119fff00b917b652ae653a7184979d18abaf5294a4dedc59ac7a5c38352ea8f16abd42b28db59c7fc94d7865ce8ef16cb70cb2ad6990727169a499b163ef7fb7567521feefc994965bd75dd2d7fc0e9bfa4db58bfb2a16f7f3b894129b96d33398bbd9555175a7aa4bf26bdca3314a927371d68f0d6b8bacc715ad2c7cdc6aebc686e37cb87f5dba62c959469ffd3ce127fb331d7d614f311946b24d34733e9963337ebcbfb8dc4a4bbbd9b3aed1b58c27af5124911b8e4c7785eda663387431b92f575a837f837da58f8f653f4b4b668bcf3a8b69c75469694a49eb68b383ea752cad92951a89492f6d8dc396e7c8d87a993b5b1e23770bbec93707afcfb1f23714e0543965d5e7a319efb9f69f406772373ca554b5afdce9bf1e4f4706e358fe30dd48d38294bcbf0679636fc637c6b676f9e65d1acf5b65a345529ba7dde1e8eb18fab9ce9b625547ea2a718ef475ca9cbb076d70bea28d3535f2d180e559bc5f2d83c753a719464b5b48638d871f8d67523e73e75d5dccf35ad4ece84aac5296bc3f2cef5d2bc951e25c52856cab72ad38afd5ee6bf6bd09b3c5d75938d38e9bee48db69f129e568d2a334d5387b22fab3eb4e2e2d6fddb45966e194552b412509afb4c5ac5dbdc5dbad7314da7e366423888e2ede951a4bf4e91e8a98f7569c64bc7e4349c931ac75e423560a346096978d1e39584af28bb7bc8b749f8f26c31851b5a0e7249b4636fb92d8c6d271704a4913a6d8e5ecc259705e376173f516f18facdefc233caca105dd28becf8340c7f288d0cf7a955ee8a7ec6eb57a818eba9468c29a4bd84aaf3f1de3edefc763d5dd1b9f4b69a4f47cdbceaf73565cb256f3ad3545cf5efe3dcfa0335ce2db8de2ea5c51a7bdadf83e6ae57cb7fd6792ad5682f4aa45b698f6715cfb746b0b1ba95a50a94aa777725b361c74e14abc29d5a914fe76ce4dc439ed6c3dad4b7beabdce3e23b66b5c8fa8990790752dabb51ded6991ef16be44c31dd76de51c7e8ab98df2a9",
            "0edf73dd87b7b3b1b49e4bd5a7e11f3c5e752f337b69e94ab4bdbf2783fd7d9b766ed3ea25d8ff0071ed1cf9f998e9b1754f925a667293a70d49a97c1afd858a56aa571ff6fe3663f1f652bcaeee2e5b7e76f67ab29907731fa5b77a51f1e0ab8bf2ede7bebe85193a747d8c76a552a2937ee2749c1a52f727b650927f034c33bba8b86db50f9d9da3a39c4aca9a8e46e9466f5ecce33710da538bdb3a2747b93568672958dd55ff00a76fe4869c1af6edd0b9bf0dc757bb8652ce9f6548bdf836de33ca7bb0d4f1f4d6eaa5a3d7c96d2cae614e1695a1a92f64cbbc6b87d1c150794bba89417dde4be3751edf0c9ae988e5171f458fa957251d47b768e63c479058dee62a463f0fed372ea3734b1e474ebe3ad60a6e29afb4e35c7a2f097d5abd652876b7ad94d5db3e4cfd2be86ad3f53133ab52ac5452f0b6710e757f0bab6ad4a93db4cf257e7b93c95f46c6deb495193d3f262b9456958578d297dce6b6c9ae4e5e7994d361e94f3db6e2951c2ee5f6b7f274fcf725b3e456aaeecaa4578f83e6face9d587728f6b3d98fcfdfd8d17469549767e365b0baeab2c79ee1d575aab9784e8ba4a6bd48fb98eb4e7f1c53ab49c9397ee73179bbdf56535396d9e6af52a5c4dce527dcfdcaed19793bf8c9727ced4cd5ecaa4bdb7e0c4fbc57712fb56b6535249fb072e777531a8d2d14f6f74bc88fb0f29ec2917e1db141a8bf3b4536d6b5f215952a10726ff066aaf04cb51a1eb4a9fdbadfb13377e3492df8c3460d4b7bf055565d95635a1fed69915dd5b793a52869af05b8d5fb5c67e1317a2ee74fa67a25d44c75de25d85d4e30ab15dbe4ebf656d6b3b49d78d6869f95e4f88f078cc8d2a72bfb1aee0a3e5e99b7d8f567374f1f2b1fa89f7c576fb91338ece2e4d63dbe85add45c4dae53fb64aac1d46fb766cf4f0b52e2846fa8d58b8496fc33e1abdcc64a393faeab5e6eb777727b3baf4ffa999ba9878ab89cfd38c7c6cb4ce36e3e6f6ba772af69471f615abde548e9c7e4f9839de22d390676aab796fee7ad1b3f21ea165f90549d850f5147db68d5f1588beb7c82ab5f6db7b7b2fa75dc373b5de39d38a16f5e97ad14e327e766db98b25c4e54eb635249797da7a6e23711b48d5a6b6e2be0f27d655c8e3ea53af4a4e497be89da930c71f8f23cc57e4b513afb697e4f651b5ecff14536bf630188bca36372eda72ec94a5f274cc263acededddedd578386b7e58f68ae7c9a8e51ccf95e4b8d5371b7728c5f8472ac96732196aaeadc5594b6ce8dd65e4d8cc9567696693945fba396c1b54f4ff003ec679ddd797cd7792a8b708ee4509773d9329f72d14a976f828c51296d9025ee46c812431b00400020000000000001289211200824004894824496f55a0d129104b8ebd9f9634ae49d397823d3edf92f7d35ec69f7fa153b3f3dbe0a28b8ce5f7cb4c8d44e335f534e9a7fa8b6d7f935f0575bbb7a86dafc95c60a74f5fee2749bd957ed8250f255194e1528aa12d566d6b5f9221256ff6cbcb7ec6d9c438066b2592b4bd567395ba9a9b7dbf034618db7a6768f4df9ce7b0caeea5c55f4147718b6f5a32fd31e9de521909abca72dc65f28fa8f0d2b09716b7b3f4a34e74e09496bf62de32cf1d4a156bd3846325fb13e9dbd4e3e3ca7ed5a2dc74be9e469429d68a517f9467f8e708c2719a7aa5461eafe523039bea2d7a59c8e3a9c5a8b96b68d9eda9569c2373526da6b64cc1d330ebb6761694eac54d7bfe09b8c643e9e52a8bc246b57dc82a583ee5bed461b94f52eb51c6b8d08372d7c175b0e3ca2bb9ba6b20e8c20e493f83314ed5fa51a934e2bf739cf0ce695ef2fdcee2ddbf3f28dbb9072a756ddc29c3b3c15ad7576f1f26b2a79383a1452dbfc1eae3d84af84c354534dc5a3d3c2ec1642854bbad2db8f9d336f495e63ea5254d34a2fe0aaf9736a69c9e8e7aadae49a8c9c229991b8e41909cfba8ce4e2fe51c939d734a98de62f15e9f643d449cbfe4ec98658da1c5d5dbab1a953b37ee432e2ce67581cb713ff53dbd4a95deea25b5b39f62ac321c7337f4ee9cfd1eed1987d49af699d56d04fd394b5a3aadbe26d3358fa5792a3153924f7a25af26527c",
            "538cb7b7ab630a8928ce4bc9555b7745fa9dc9c51eca78b708aa74df85f82ddfda3b7b6947bb7264c38b927f5a472cb579483fa55aa8bf067ba77c5a50a0a7751ff2fbed94e37133a159dd5c6d524f7e4d8edb376b29a8d9c936bc69168d73bb9fab33752ace0adb5dd18afc1462efed2b5576beac69ce3eeb62b66adf176556e2ef517dbe367cb5cbfa9f94b6e5371531d37e9f73d69917271f7276fac2f5525fa6aa9b5fb9e58d59d65db16d1c7ba57ccb319b7bc8426a2fe64762b66bfd8b7b11959768549493a751f87f9352e5f85a746849d29adb5ec99bc4ac9545dd2976bfdcd533789ad5aebb554728135a71f27ad72ec7e32ad4c86aa6d45bf73a558f04a15ace35e0d396b6572e290951528fdb2364c4dad5b3b38d35372d7c0c634f23c8f6e984ff004ad0ca51fa2baa7b8bf1b670feaf74bab710b8856c5d16e355f9ed47d2d28d494a1e9c352df967839bd5c4c318a593941ce31f0a445c5cf8eadd3e428f01cadedac6b2a33db5b6f4793ffa6d75577dd53525f07d2fc7791f1da98eb8a353d24f4d44e5d92aebfbf49d096e9397848afab5e4e1c729a71bccf1bbac226a54a525f9d18cb2a7eb54d38fb1ddf9ad4b7fecfdced94a5dbefa38dfad4e0e73ec507bf61eaf1f9b8a4a8bcb8fa6a1d907a7a3c18ddfab29cbddfc96ee2a4abd6db7f69e8b5718785ee431dc53731dd46ca3c548f6efc9564374dad7c9e78c5f7465bd2254cbb570dd07a9bd9e9b2ad7d615d5e5a519ad79ee48f25ca526a49ed1d6ba63778bcad92c75c5bc2551f8db4434e2c6dad4b01ceb353cb51fa8b89ba7bf29fc1dab3bc9b239fe330b3b294f7d9a6d181ea1f4e313c7f0b1c9519c29d4fd5a4623a7fcd2ac6c6b518db3aca31694847a7c795e39ab595e0dc72cf1b52a57c9d78baafcb526687d53baa33bf74ec61db4dbf2e279ad729759be5572ae2f256d4e327f6b7a47979464a8a73b6a1255e7bd772f237d33e4cbde5af1719c74dde539a4e526ff00f837cafd36af9dbca55ab3d47f72cf48b0556e556bbbca7254e0fedee4767c55bd0ca5aca146494e2f5e0993a5fc7f1a59bb1c9792747676d8ef5ad9a7a8ef68e517169fdb6e6542b4bee4f4cfb2ae2ca9db612a51af3ee9b8e96cf9ab35d3ec9e6b94578db5393a7397ba434c7cae0d7c8d1a72a527f6b2dca3af299b3f28e9ddff001a839d6eeff946a906dbd32af3f2c6c53296d85b64cbc327de3f80847b48bb5b5e945af729825dbe4a7ccde8263ad7467058ebea91a972e1dfefa675ebce3f6d5a52a3d8953d787a3e5bc1722bde3b751ad6f37e3cf6ecedbc37a8393e534634a56d28e96bbb5ee698576f8d67c5fbfe9ae31d694e6a1e7f6347e45d29752bf7d9568a5f8474ebfb5beb84e2a524d1ade41dee353ee9ca4cb5c76f42f8d8e71a057c0e478f63e7420e53525e746b78fa5e95697ae9c66def4cec78bbbab7b071af6ae71d7bb473ce6b81bd8e4fea2d6da7e9fe22bd8cee0e4e5f1bd7e35bb9a2a37f0a955ee9f77b33bb7138595ff1da74e8534bc7968e130b5bbc8de53b7ab1943ceb6d6b47d0b88c7daf19e130942ac6559c3f2564ed6f171d5ed93c560f136d1727d9eb7c9e0c95bd284e752924d47f06b383b9bfbdbb9d67525dbf833b657159faf09c7bbdd1b3bf932922f71de4d6156b4acaf2518edebc998cde738ff19c7ce4a54ea4a69bf1a3e7ee737775659572a33952f2fd9e8d6ae72f90c8254ebdcce6bdb4d94b93cae5e7d5d331cb793cb239995cd9cdd3827e34555ba8599ad8f566ae2696b5bd9adce97a7e25ee441c60fb9ad95edc77932abb19ca751d4b8729c9f9dc996e72ee9b6bd855a8ea3deb48a53f045537b4b20104086412400000000000000000000012892112806824f654898a94a6a315b937a4029d39d59a8538b949fb245dad67736c94abd29c22fe5a3a274d7a6397bdc8d2c9de5ab85847cb94bd99b675678c595fd8c28e0e109d686bb9448b93a70f1f2cb1de9c322b68b96308cb2542353c45d45b2fdc61efac370ad46509efd8b56d4dd1bfa12ba528c3b936c7b319c7659b7d77c7ba7fc632dd3f73ff0013b974f7f1bde8f9d790f4fe9632add4dd5ed5193e",
            "d47428751b0d82e3d0a5697add5ecfd299ce2af289f25be952acda84d93727ab78b8ae325bdb59863afa841d6f464ede3ef3d78d1e5f5a9aaae5172d1d4b177f657928f1c9423aa9f6f71ba4bfa618cf1caf68ca528b8f77864e36d7165e3eafeae25c578ae5396e56951c7db4eb2524e4d2f647dbdc26c2d305c66df1f56ce0ae6304a5b8f938e74ef1577d36c9b542d7d4ee7adb4758b8bfbd9529643b5a9d45b512d3a75f0f8feaca646dd5ad0a9384946735e228d7f1756f6d28d5af7e9d3b75b7dcfc0c4e6e52baf5f32fb2947cf934aeb875831b3c0d6c5e166bb9aed6e24edd9793d7ad2dd78d1cf729854c5a8d68467f735e4ead5adeadbe3e14b5f776fb1f33f40f9e5af1dbfab3cb546e1296f733e86a5d48c1727bda76f8bad1a937e3484cb6ae3c9ed65fe31394b6a95e8fa7dbf736534389d2af6bbaf14dbfca37d9e2ad2dadfd6ba70526b6933155294ee269d1d7a5bf82f63a273cca74d2eae0296169d4ab42947696d78317865532f2aeef20a10837ee6f3caebdad861eacdb4ea462fc1c4b09ce2ae43217160938f7369153db71d578af23c163ef7e86addc209bd3fb8d839bf5178d716c54d5addd19d7943c2523e4aea36373380ca2be854ad1a72f29adf8353b9c95d665aad7177394a0bd9b2bbfe3cce6e4d65a65b9ae52f394721ab7f0a0d272f124751e119ab2a586fa7c8dea8b51d69c8e3b4f9155b7a7e8c69a7f1bd1e195d5d5dd56e752508ff247f5871f91eadff3f94b2a59fa72b1946a2eef747d27d3ccdd8dc6068c3215634bed5adbd1f17d9d6542ee1284dce699b95e73bc8db53b6a12a8e9c7c6b44b5fcfb7d8abe8dcdfd2545522fe51e6b8c746e2b28a7b6fe0d77a311ad96c1ab89cfbdf6a7b6cdde85b384ea567faa0fc265a37c33e98be536346db8dd4a53d539b8f8389e0b315b0d939a8cdd4fbbd8e8dce32191c8374d7882f1e0d4f1f82b4a4a55a6f75dfc12f4383e7edf56f96720afc82dd5bb93a7b5a69184c0702c2fad4eaddca139b7b7b3395315df5dce6b48c7ff69a956e9ca94e4943cf86534d7291d3e871fb1c7d9d1fedd4a0934bcc5193af76b0d89a973e2538ade99aff0008cc2ab1769525dce1e3c9aa7573a83438f46566ea252a9e122d3a72726b15cc7f53eef2d99767aedfbb4bc9d22d76e30957f0e4b67c8184e7352cf96d0b96d7a529ad9f62f1dcf61b3d87a1732ad4d494178d932b8f2e497e2ed38c6bd4ec8b3c39dced0e310552bce293fcb3358f7636b3a97756ad35412def67ce1d6dea65864f353c75adc2f4e32d6d316e95fc927d772b2ea6f1d8584ee6e6e69465adadb38773ce64f9be4aa50b1b9ff145bd76cbdce55c8f214ee31b0a76f772ee5ee9330387e417384abdd4df748afb33bcf31c9d2a38eaf8f4bd6b974d7f3ee62f2bca69e265ba53552a2f6f26af93e6590ca47fcdf6ebdb463ecadea642e556acfec4fcecadc95cbcbb5b64ba837193b6951baa69475a34dc9d6756bb74bf4b7f07ab37569292a56fa4be7463a93705a7e48f67172725caed53d2a7ff00b16a1525096cb925e765b68b225dbdb51d2af47727f723c6a4e5b890a2f7ee54d6822c1c350d6f667b83e63fb365a35673ed818141c7b96b7a2349c73f5bb751e6dcb69728a11b5fab7d897b771ace33974b88c3e9ed2942b77afb9b355a545f7f99f82ed3b4ab92baa74282739bf04b5bcd7376de17d2ac7f33b2a99dbbb8fa59558f76b7a2c62ba518eb6cd544ae3d7a707eefc9ba70bc05f53e3742daaf7d34e2978f0669f109616854b88ca52725b6f64e9eaf0612ced36b82b4a18ffa5b384629ad368d4ee329578ae5151a3272529794574790df5adecada9294bb9e8cbdc71e57f495c4d6ee5f9498d3ba7eb1b3616954e494a33aefb135b321698eb3c35e371a519cbf3a34ce39c82eb059056f948ba5477adb3a558dd61b21555c46bd374d796f634e0f2338e35d7a85c54c7cab42df507f3a3e6ba3e66f67d5bfd43730c33c23b1b39539544b5e0f9463f74dcbf2ca5799cf66e26a7dd2fb7e06dc96b4233f4f7af929ee6839d1a68b94da83dfbb284db654b4bcaf704faf7606d6190cb51a5552ed94bca67d6fc3f8",
            "c5a6278f51af4ade9adc57948f8fed657142bc6b5052ee8bda691f45f47ba9756f2de18fccc9429416b72271aecf1ee9bf5d50934e74e9a7ff0006bd7388a77ae4eac74d17f9f754f0181ad4edecab53939e93d332789a5fdf7150bdb769f7c76f46d8d77e3cfae9e0c1d851a73fa78d08b4fc6f4646eb8c5095754be9e33525f829b4a756c7bf6bee4cf3bea15962aefd3bd9a52fdcbd74cd671cc3abfc56af1ca1f5d696fd9e77b8af628e9b64adb9363be96feeb5523e3b64cdaf90f2cb6e6592fedd349db4bc6d9a5732e11fe95a3f59c7aa39557e7b60cc6e3dedcb9cb8ddc747c362f1969772a119c3b52fc99eb5a3c72d2dae6a57b8a519a4f49b3e659f22e5589a7f5172aac7bbe648c4dd72ecb5fc9a9dccd777e191b8e2cf9ede994ea5e4adef3395216ad4a9a93f28d4e4a305192f7d13523372739b726fe596f7b21c996577daa9c9d4f2ca52008aaed714d38f6b287e1900a8104802904b20000000000000000000000944a211280aa3e195d0a9e8dc42abf68c932844c529cbb584cbabb769a7d7485a70c8e1ade118d551edda5e4d2711d42b9b2b8956a927394dfb3f269ee8d383f326caecbd2a7750a95ffeda7b22c74e3e5e73a6f3779485f5657b79051849efd8bf771e3f96b54a0e0a715f062b91f24c45ee269dada43538ad3691a8dbc6e2a4b543bb6ff0571865cdb67ffb158d4aed2aefb13f6d97ee6d6cf1d4954b792ef5f83156d82ccdd578d1a54ea394fdbc997bee9d721c75baab734a4a2fcf9d96b1186372bb919ce05c43239fc842fed54e55632dad1f5271ecae671d89863efa9cb6a3af272dfe9ff976178fa8d85eba6ae77adb3b5e7796e09a4d56a4e725e12d1a71ce9ddc7a9d357bdaf6d1aea738c54b66528e455dda7b2ed82d983bee3f759192bea4a5e8c9ed33298ec3d6b4b29fa92d26be4bfabbb8f28d3f3d9259cbe58fa7f6c77a7a3119ee8553b98c2bd09b929adcb66c76dc7673cabb8a116fcedb3c5cf3aa93e350862e3e2bc976a1eaaf25c6b41cef0ce3b80c7cacaace31bb7e176bf3b321d31e0f75839bcc5bd49ca2bcad9e5b2e9de73975dace5e4e5e8efbd26fc68df707c829e324b13a4e115dada23d15c70df6c2f3ee61c96baa7e84a518a7a365e27cb2f560e10ad2eeacd1a07583904ac2d3564d26bc9aef4bfa9d6f42a7a5969ef4fe49dff1965cd8e374ee9618bb8e474ebfd64b5069fb9cfd70db5c172177119c3b632db2c72debbda63a854a38c92dc969769c867d4fcc5e5cd4a956a49c64d95b517cac675b773ea6e578ee438e3a33f49d78c3c7e4f992118d3af5a10fd2df83d196ce5f652b6e5567dbf8d9e4a91692945f921e6f3f2fb5555a0a8aeef0534dcea25a5e19669c2b5ed55456db3376561d8e36dfaaa3f64430c71b555ad0b0c6d2fa8b95b93f6479654ef3945db8da527254d7da8e9381e8c5fe76d7ea2e9354b5b5b368e0bd3ca5c6721525569a9457e469d7c7e3e597df8da3fa6fca64f056556d730a50a696a3ddf836be6dd60c3f1aaf384e4977330d3bba0ae634ade2a0be746b3d4be9d52e4161ebd1a9fe64b6b459e94e2f59b9f58fc8f57a9e7eebd3c7beeee7af06e7c7ed156b457775b526b7a385f0bc6d3e259cff00eeb4de94b49b5e0fa2b171b7cdd9d3a967560a96b5a4c98619d93b632f2e29559a8538fede0f25ddad6b4a5ea505b72f736eff004eda616daa5fddd58f628b6b6ce5986ea8585f730a98d9ce3e8f7f6a6fd89913ff00274d8716ebe3e5df4d4955a8ff00fc9c7fad98bca2bf85e5f3976bf64cfa8274f07678f591a95a96a2bb97b1f3175db9e51e4d918dadab4e9d27af0464e4f279b78b97b52a8a33a6fee8af066f1fcff91e2a87a16f7738c17c7930d6f2ec8ad7bb454eacbbb5b2af37daedb554eaff002eab64ed25792f4dad3f0cd4273ab7d732ad5e6e5393db6cbb2b9941e9bf0454a90841497bb1622e56fd5a96e954d36defe0ce5a70dbfbbb495ec69cbb12dfb13c57885ff23bb8548d37e9269b67d1187c4595ae1e3633841351d48998edbf170dcfb7cbb4edaeaeee3e9e3093927ad68f7ddab8c3d054270946525f27d1b8ae0dc7e1948d48c29b949f",
            "9305d6ce0d8cb4c67d65b3829463bd222e29cfc7b84dbe7ca52dee537b6cad45cded7b14505ea466bf04c2aba3f694d308adf8f0cb4fdcaa73df92d39965245c424ca14c96f64a6a53277e4a49045ca7249bdfe0cb708af1b5e4146acd2ec8bf3b30f1f2fc972771f4faf41b527f286932c95f696339df1d971ea54d3a7eb420bc230373ccd655cede935d9ec70fe9758dddfd79caeee5c69c9785291d4ac38ad7579ff4d3ef4dfc177b1e3e7d4af6585950a5908d6a89797b7b33194956a5754eeadfcd38eb7a353e6f7b3e2aa11aadf7bf63d5c679c5ac7133a97f25d9adf90e9cb93a6f7cab8d5af20e1353250d42e210df8f7d9f28ddf3ce4986bcb8b1a57928c21371d793b2723ebbe3a9616ae3ac65e1a71d23e79c95f4f2593a977f3296c8bff8f1bc8e4b6a72597c865eb39de569ce4dfb33cb2d28e97b935eb39c9fe4a69c75e6466e6b6d5bd3df92a7a7ec44dee5e0adc3b5790852b5f022b534dfb6c28fca1b4fc3098dbb0d91c35b5b2f5d45d4d7c9e2bfe452a5565f433ed8bffc4c0d1a2abcd538a6e4fd8f6dc71ec85a5255e7427d9f9488db6c6e567eaf35dd6b8bda8ebd7a8e52fcb7ec772e8f7582cf0f6aac3212d460b5f71c56c684ee26e138f6afdcf554c5d1a34e6e137dff00b31eda4c965dbeb2afca7159fb3a95b19521ddfb1a1de714a597b895cde54d35ec716e2fccaf38cd6717526e9efdbdce8987e4990e58d4ecdc9535fa8d267b77f073e3f172e71d1b3c8fa564db6be4c8d38e469497aebbe3fb94d2ab4a9df46de535f52cd8ed70b7f7926a69e92f7d1a4edbe7cb2c606ef01579453fa7953825edec73be6bd37bae2f175b4bb7dcde39272e9f07ba49bee96f5a4697ccbaa15394da2a4d6be3d8cebcde4ca56810a8e52ed994d5828bf05293726dfb86e5ecca6dc95000211a00000000432096400000000000000000000002a292a02495e3caf72094054a7ff97b89cbbd68a417244f6c147e7666f8a5c50a591a74eaa5f735ad9844576f55dbdcd3acbfdb24c8f8b63f5f56718e1f67f410cb3a69a8252f632dc9b298dccf16b88d2a7175a9c5a5a4724c4f5ea38fe352c6ba4dcbb7b470de796f7d42e25732508cb7f6b64ede963c98c9a8e4f90ad7b8bcc55ad4e73a5514db4d1e8a1ccf370bba55eade56a918493ed6fc32ff003cbba1799a94ad92ecfd8f5708c659e66edda5d351497bb227fe38b797b755f48607aef89a1c2ede85582f5e3049ecd6f91f5e68d68d2a56fb49f87a390e4b1d6f6b95958d2ac9d38fe198cced3a16945aa7a94f5f9f62dbaeaf7b8c7d75d37e658cbdc3cabd4719d471d9f3e75832f4725ce69548d392846a7ffe982e99f33ad85ad3a75eab749fc367b39b65adb335d5c5a53529a7b6d09955f1e4dcdbaed872e9cb0346c2cee2316e0976a65386b674dca573424eacbfdfa3e7bc4f28bdc5e72955ab526a9c64b716fe0fa02af577054f8caa8a10fa850ff91ed6ad8793a96357ea8625cace75a4db5af6382c9357128d26e2f7f937ce4bd53ad9c8ce8fa4fd36fc33469ffd456728786d95b76e1e6cfdaf4bd4ec6555eeaca4caab2a7463db1f2532a93b78e9c9ecf3caa36f72258cbfeab53d45f922942b579f6453f3f2556f6756f26bb5351fc99c8d5b6c55bf63d4aa68834bf8fa36f8aa3eb54d3a9a3cbc572705caa8dc5cbdd294fca7fc98bad56b579bab26fb3f058f2aa2a90fb5c7ca2749df734fbb78ee22966f8e51ab61774e11705f6a6512c0d3b46e155c672f967ca5c23aafc8f137146ca856a93a4da8f6a6cfa5f0394b9bdc5c2eaedb53a915ee4cd3d6f1f9258f16671d4a9b72b7d297ec699779dc8633250f5e4e5413f299bbe476e6da96d33037f8aa77f354e715b65a3d1c72c75da737c671bcdf10ee2d2108dc28efc7bece33539b67fa79959d854f53d18cbc2fd8ee785b5abc72a25ddfe37f079bac9d3fc065f87cb371a94d5d28ef5f22fc71793773f5713e57d68ccf25b1fa3b7a952316b4ce7b467756d5d5cd39c9574f7bdf932786a34a9caac650dc93d2663eee72a57b36fc47665b79596397dacbdd750b915c5a7d24ef2a2a7ad6b66bee53a93752ab7294be595ca51aafc2",
            "2864ed8dcaefb136995777929d80aef69edf565a298d373ad0a4fd9b48a94bb5ed0a9dde271f75e426cd3ea8e9571cb0b7e394eaa9c14dc111c8a13b1f5fd27b935e34712e1dd48ca58ce95845ca507a4b4cef58ac4dc6571f0bcaf193ee5bf25bd9e978d9cd350e2952fe94ead4b993ee7bedd9cf3aa3cab292bd7615aa49d37bf77f0770fece95cc6318f6a4715eb6d842df2d4e718ebc7b916db13e4e5bc7a7388af496d7ca2d4b7296cadcfdbf825b8ca3e03ccbf546fc688d10fc3d02a84e912520915264a2925302af2fc2274a9adcbdc88cbb5eca6b4dcdaf1e10da3facc62bfd4170f78d571dabff000f63b0f4eba8b7bc5ad26f2f4a756a417fb91e6e9d732e3d84c3c695cd1a72ace3af291b5e169e1b90ddca556de2a9d47f2899d3d2f1eebb691c8f9ddbf51330a9d48fa3e7514fc18ae678caf88c67652aafb251f867b3ab1c19e0b274f25848354a3e65d9f068b9be5d7599a10a155b4e31d3236bf2f2f5635fa50ee6dcf654d28bfb4a1370dc7f25497679627c799921c96fcfb9129777b14bf2f6084252d3d95397a9a4504a7a012fb5e8a9c5457716b6dbd975bdc74067f84dad0ab93855aed76a7eccfa1b8ddd71bccd18e3abdb536f496da3e5cb5bbab695232a7371f27d19d3fc3d8d5c043273ba842b463dcf6c3d3f032c64becc1f59381dbf1cb55778da5a84bcfda8e3d8da3737d2947b9bd1d7f99f55ad324aae22a25554371eef739cd857a542756b535a4f7e08d6d3cb31caee3115b8fdcfa33af2dea3e4dafa7dcd6d78de3ead1947fc8f7e5986b8e4ea76d56d9c35ddb5bd1af428a54e536f6d92e2cfabb8cf5d72fb8ff52ac94672ec53debf63b05b75bf1d6984de97ace3a3e7c504d6d92a8b7e7fda4ccac5272d9f59de57c9e7cab232ad53b9477b4611c69c178db64b508c7515a650ff007219ed4f769ec894bb886000006800040000086412c8000000000000000000000054525404928825000016da2055a5a292137bd0d9b5718292f62b84ead18b54aa38efdf4c87db04bb5eca7fdfbf80b4c9729d5716e553ee97ee570bead6b5555b79ba727eed162abdf944762edeef9fc044b76de30bc67eb6ca593b9bbff238efcb353a9564b21569ce6e714da5b65c59ebb85b2b784da8fb6b6781afbbbf7b6fcb0d33cad4cea4fba4a1b8eff06f5c095953b2ad3bfa91ee7bd2933486f6969143a95b7f6ce515f84c132b191e4b3a7572739504bb3e34787d2ad516bd46e3f8d9577374fee7b7f92d7734bc31a577b57fe3847b1c16ff00250bfc52ee879651f74df85e4b94a956eed422e52fc0442737596e5e19e9b0c7cef27fe44e305f2cc863b150a9fe4bcd534bcf929cb6529d25f4f6a96978da0d35afab95afe8e2e93a1452949ad6d186a9df527eb5496fe74ca1aed7dedf7363b9d47e7c067579dd29c35ad10e71ecf3e0b2a094f49f8333c47051e4d98a763567e9d37eeff0168cbf4c2f2d6df3b1fa9a319c37bdb5ec7d2f5b274afece852c6c53f096a3f070be73c5f19c0b1f4e58daf1a95e5adbdf930dc4fab393e3553d492f57f09932e9db867309aafa7e5676f6166ab642aaa73d7b4996b15654b2d275e84938c3e51f32f31eb166f954d6e4e8c17c2676cfe9ef9ae32e3152b7ca5cc6355ad7dccb4bb5a793bea37aa98f57d5be9d34da47cf9d5bcd66ecb38f09eb5456cdebb77e0fa82b67388e1613bcaf7d494b4da5dc8f92fac7ccecf31cae75f1bd952117bee42de9197349db21c7383c2e2de9ce5ef36b6cd97a89d128e378c432b457dce3dcda39ad9752af2cade94211f31699bbf20ebad4ccf1486367e64a3ad19b5cf970cb1714945d1ab2a4fdd3d0d38fb954e7ebdc4eacbc6deca652ef7a11e5e5366c6ca77a253dbd065aa94f6fcfb190b6a1df15dabb8c776ca7354fdbc99ea3db8cb353f76d13b6b8c5765776f86b9a75e7497727b3b4f1feb75a53b1a56b3518ad24700f5a191b85eb49c76cab276d4ed14153a9bd8db7c72d4dbe91cbf51b1b4ec257942b45cd2de9338672de672e5b713955876ebd99ad42e6b2a7daeb49c5fc3679d787e08da33e5b554d24f4990d76fb32a708a8776fc96fe09db1fa6f608d8d",
            "90aa422361015125289404b7e0ab7f6fb111d37e4ab69f825098aa94da9c27b4bcfb9d238af378ab254a7354a705efb39aa7e9b7af24272dee32ed0db0cfd5d4325d4e4ed6b59575eb2926937e4e6b7338cee275211d293de8b52fbd6dbdb4530934f4c6ccb92d4d45bfb88ee725a2a94b6ca5b6bd90db2bda9f6046d8db2048236caa1efe406b4888f964cfdfc1314920128ecc950e4d94b4b6fa6a37538d3d6b4998d6fce8464b7a682d8e567c6e1c478dda652156eaf2e52a9a6d26cc35ed4ab63939dbd14e50eed2f1ee63a3735ed66952ab28efe133bef47fa594b94508dfe46292494b720eae1fdbf59d38e5e71dc9ddb854a36737dcbe22796eb8d66ada1dd3b3aaa3fc1f605d63b8cf1c8f6548d27e9f8f3a343e41cdb03717df4b4a8d274df86f4869b72f0cd6df33ca3529cfb2ac5c5fe1a21ca4bc2369ea2ab3feeae567dbdaff0006b1092516dfb879b94d553bf1fb90dec37b7b20086092340000000028020100c82590000000000000000000000094412809449089000024b0008611a4af1f2548a764ec274924844931132d53fe001f0dfe095b2c95c67182f250aa773f1166478fe02e791e469db5badeda4d9f43e3ba2189b4e3a95cc23f553878fe486bc7c5737cd1dfddf6a0dc69ad34db366e53c1ef70b9995ac694b5297dacd9f85f482eefef29d7c9452b6f77b1daf3c6ce5d69cc68ce51a89c62cdaace9db59daab9a9aee6bd99d6f96746b1f431eeb62e31728c77e0e179957165733b2afb5d8f5a1f139717e3fa9c9e55df4dc20fb63fb18cecec7e5ecae2a305b444a5dc4b0b7680005762f07b30f97af86b9f5e96d3fca3c4fc2da2a4e2e3e7dc8a99d3df98cfdd666af757a9292fc36792ac54a947b52f050a0a4bc7b94c2524da7ec0f6b7a5ca728d5876c924d7ec5cb1c9de626b77dad6941feccf3bfb5f8f91bffc893b8c8e479365730953b8baa8e3f852663fd28c16dc9361ce3fedd14b7bf708ded3eff829edfdc9d91b2a6c64c5a48a59315f209927b535fb94afb3cfc954bdbb97c1efc3e39ded653a8b54d045af4612c6359fd45c788af3e4b590ab2bebc56d6be63bd783d199bd85b2fa5b77e3e7462a8569d938d7a6feff00815795d1719c0f1742c295d5f55519e939793317bc438be6f172958d78baf4a3f0ce6cf2599bda4a35673f4a7e17c14bfee9c77fc94a728c6aaff821b7b4d74c65f5bbb3bba941fb424d22c172e2ad4b8a8ead5f329792d8735a0f8002654320025012882501200008a8a49d845482363604b1b236360364b646c6c262000002010120000de8463dcf612dbf24b7f1102fd8c635afe8c6a7e9ee5bfe0eed53ab5438a62ad2c31f249ca294bb4e0b197a7e57ea2253a95e5dd526db5edb0d30e4f5761e4fcc6192b1955a972d4e6b7ee72aa992adf512946b49f9f7d9e6a97171711519cdb8a2c798b0be5e45bd2edd56a95ea774e4e5fc9478ed2a5173452e29780c2dda0000086c92180d8d91b1b0276524ec814000400000000000000000000000001288250128929d8d81502363616da487b1b0fc856a0a91089d3d812bdc925475e59315b96daf04c57fa80ff4b2a8c54ea6b69222a351da4d3276bc6efd20b6b9b9e474a36ef5f72d9f57e5b137b6f4ed1cf727a5ec7c79c0795ffa5b291b9d7b34f67d0765fd47e32bc28c6edc5b878f22577f8fc9318bfcf71f6708aad5a8afa84b6bc185c7662fa38d74e0b497b23cdcb7abd86cc5d46ac541c3dbc19be10ad797575f4c9763fc0dbbf1e6c7ed55c7b297d9473b2927b978f272eead74ab2785b8a995a89fa73f3ec768e515b1fd399abb9ca3dcbce8e67d52eb959f30c1ab2a515ddad0db8fcae6e3ce74e1b194651edf921a69f92209c5f7b5ee4bda7b7f22579776023636368d263efe7d838a94bc11b09e9ec54db45274e45739ad268a65252f821b4d68821dddc54da92d16f5a2b524912b6d42d4595b5bf243d30b7b1b421b20992d7b10a0e440130fd5e7d88945c3dcb96d6d3b9a9a8a7af961117295b4abd68c62bec7ee65eeaee9e3ad7d1a3aee6be03a9471f6ae3e1d4d7b9829d4956a8e536d8dac6e55a4e737b6c89b7e17c22653edf62994bb",
            "882ffe3395f3d4dd850a34d7dd0d6c9caf228e46ca9d0d7dd15efa303f6a5fb929c57baf213ed748ee72f7047b0d85521a236361080013b484a2094362411b1b1b123646c6c842763646c6c26247c11b1b0948208085408d8d9224223636362a053b1b1b1522a8aed7b2decae33d2f23694feb64bfb5a28f9da236fe46d0bd3a9bd76fb112d35b28ee4914f96365915faba5a453a72f2468952d0da6680437e48d8da1514c86c37b1b10001b000100000000000000000000000000000000004a20940480000d81adb0216d9722d45790d76a229c7d5a8a3f9027d4dbd7c0757e179333c538fc33f9fa58dab53d3849e9cbf0763a5d0ac5d0aaa942e6351b5bdef64b6e2e1b9fc70ec7636ae52a7a74fc3325fe93a96edbaf3d246f19fe270e0576ab3ffb6deb66039964a956b0a556da7e6a7be837cb826137584fa2a1397a349294bf6370e2bd1dafc9aac20ab3a6e5ecb668d85b98d9cfea272dbf7d336fc2755eeb1390a55e9f74614dfc7c8538f2c7faf7f507a377dc22cfbe6e53f9d9e1e9b7546a7087284a2dfe19d233dd4eb0e7f81edb99c54e31d7967cff0094b7a7472152149f741cbc31a5b97393feadb7a8fd4abbe7173e65254ff1b347f4f4b6cadd28a9912879f70e4aaaa4f70492f62dedebc92a5af044e5bd041b1b29d8d8156c6ca7636055b1b29d8d815021120037a5e00f6011927ee4f7bdea2b6214bd47e7c1edb7a54683ee9352205365692bc9f6cd76afdcc9d68d0c451718b4e4d1e1b8c8c52d525a7fb18fab52ad79774db602ad59d59b726ded92e2b442d688726981469efc924ef6430000021904b20000000000000000000000000000000000000000000000124002a05200a814802a0520000000000000000000000000000000000000000000000000012880048200124ef45254809df72f222dc25dcbe0003db6794ad8eaf1b9b77db557c9defa5797b8cb592bebdacfc2f967cefa72f08d8717ce32587b17676efb61ad08df8b9ae0e81d6be5367956aca84d39c1fc33924ab54749539b6e2bd88b9b9ad7b712b8ad2729c9edb644df7a5fb128cf9ee57b4c62bf3e04a316d47c2dfc96ff0064031dae77d5b66e14eab517f86273ed8fbedfe4b7b0fd8274b9f6ba7ddbf25bef7ad1480855a5a29000000274000200001289d94802ad8de8a4015faad2f052e4e5f2c804095a5e4aa5576b5a280042f72b7a91480274922086401208004b20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a64002ad8d91b1b025369ed17538b5b97b9653f25c8f6b64c49ddbf08777c09aedf6223f77f215b3fc1f823643dec0244ec6c8016000150001200105801808a000200000000000100000000021904b20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000095ee4bf7da211204a97e48db4f600072d91b2404ed1b0490c20d8d90009d8d90009d8d90009d8d90009d8d90009d8d90009d8d90009d8d90009d8d90009d8d90009d900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012892100241000904002486030200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007fffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003012200021101031101ffc4001500010100000000000000000000000000000008ffc40014100100000000000000000000000000000000ffc4001501010100000000000000000000000000000001ffc40014110100000000000000000000000000000000ffda000c03010002110311003f0095c050000000000000000000000000000000000000000000001fffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003012200021101031101ffc4001500010100000000000000000000000000000008ffc40014100100000000000000000000000000000000ffc40014010100000000000000000000000000000000ffc40014110100000000000000000000000000000000ffda000c03010002110311003f00958000000000000000000000000000000000000000000000007fffd9",
        }),
    },
    AnimeMask = {
        side = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb0043000604040504040605050506060607090e0909080809120d0d0a0e1512161615121414171a211c17181f1914141d271d1f2223252525161c292c28242b21242524ffdb00430106060609080911090911241814182424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424242424ffc00011080300030003012200021101031101ffc4001d000001050101010100000000000000000004020305060701000809ffc40051100001030303020502030405060a09050101000203040511061221133107142241513261152371088191d1243342b1d216839394a1c1345254556272737482a325434445638492a4c217355364b2e1ffc4001a010003010101010000000000000000000000010203040506ffc40026110101000203000203010002030100000000010211031221043113415122526114329171ffda000c03010002110311003f00f9e004e342e009c684d93ad09e63521ad4f31a80718d4446d4db1a898da919d8da8a8da998da8a89a807e26a2e26a6226a2e26a467e26a3226a6226a2e26a467e308a89a998da8a8da919e8c22181351b510c0919c604f342430279a1232da12c05c684b0106e84a0b80250080f2e2eaf148dc5e2bcb8520495c2ba524a46e1292ba524951551e25732b84ae12a2aa3a4ae65272bd95955c2b2bd949caf6e59d5c2b2b9949dcbdb967570a5cca4e5732a150a252095e2524941b8e29a725929b71411b7a69e9c714cb8aa85a34f4cbd3cf29972b856197a69c9d7265cb488b0db934538e4d95713a20ae2e95c2ae26c797971755c49412da9012daa93a3ad4eb534d4eb5323cd4fb130c4fb1323ecf64fb3d90ec4fb100fb53cd4cb0a75a823cd4b4db538100a0bdecbc175304948704b292e4119784c3c225c132f08016408690231e10f23532052042cad4748d42c8d5440246a1646a3e56a1246a69032350d2351d2350b23532052350ef08c91a8791a9904784cb8229e130f09918704d909e704d38208d90909c2907ba089292575c9252279732bc57901ecaf2f2e148886b53ad6af35a9d6b55b4798d4f31ab8c6a7d8d48ca8da898da9b8d8898d8807236a2e26a6a3622e262467226a322626a2623226246722622e36a6e2622a362467636a2636a6e36a2636a40e31a9f635218d4fb1a832d8d4f3424b5a9d6b52375a12c05e0128041bd85d5dc2f6101cc2e14a5c210095c2ba9254992524a5148295370948257494825455478949257894825455428b9732924ae6567570bcae652372e6e5955c39b97b726f72f6e59d5c2f72f6537b97b729aa85172492925c925ca54eb9c9b715d2536e29871c532e296e29a714e110e29a714b714d38ab8561b714d3938e29a715713a36e4db92dc90e5a4458415c5d29255c4d8f2ea4a505513a2825b5202535544d3ad4eb532d4f31544e8fb13cc4c313cc299086279898627989810c29d6a61853cc2823cd4e04d353ad402c2ea484b0827084829c2924260d38269e13ee09b704105784c48d45bda987b532052350d2351d2350f2313247c8c42c8c5212310d231324748c42c8c5212310d2313247c8d43c8d4748c4348d4c80bda987b5192350ef6a6415e134e088784cb8208cb826dc9d704db93220a425948291385272ba524a09dcaf657171202dad4e35a94d6271ac54d1e6313ec62e318886312d9bb1b1131b1263622a38d00a8988b8a3498a345c51a465c4c45c4c488988a8a3fb20cb8988b8d8911b1151b120546c44b1a931b110c6246eb1a9f635718c4fb5a8379ad4e35abcd6a703501e012805d012835009c2f612b0bd848c85c29442e1402121c96536e48c9726ca5b936e2953249482575c521c54554709482579c520959d547495cdc904ae172ceb485972e6e4d972e6e59d5c3bb97b726b72e172ceae1ddcb9b935b97b72851cca4972417249724a2cb921ce492e4873921a75ce4d39cbce72438aa834e38a69c575c536e2aa1584b8a69c529c536e2ae27449482944a6dc55c4d8e1292ba5732ae54d8f2e849cae8572a2c2c14b6a6814b695513a3c",
            "d29c6a65a53ad2a9361f614fb0a1da53cc29908614fb0a19853ec29908614f3530c29e61411e694eb532d4eb532381282434a5040297085d5e4110426dc13c424108061cd4cbda8973536e6a6409ed4c3d88d7b130f6264024621a46290918869189923a48d0b2314948c424b1aa24748c42c8c5232310b2b13247c8d4348d47c8c4348d4c80bda98784648d43bda820ae09a70443c265c10464a414e3936e411252574a49413c57095e25272824d3589d6b129ac4f31886ae3189f8e35d646888e348de8e345c51a4c6c4546c402a28d17146931468a8a348cb8a345471a4c6c4546c41971b1131b1263622a36241d6313ec62f3189f63106f31a9e6b579ac4eb5a80e35a961aba1a961a80480bb84bc2f61008c2f612f0b84201b2120a7484870419a29b7774eb936e52669c9b7271c9a7246438a69c52de536e2a2aa12e29b2575c5364a8aa8f12925cb85c905cb2ad2145cb9b9365cb85cb3ab870b973726f72e6e59d5c39b973726f72e6f53570e17ae17a68b970bd499c2e492e482f482f4194e7241724972439c98d3ae726dce5c73921ce5509e73936e2bce726cb954279c52095e2e48255c4d8e92b9949257372b892b2ba0a465772ae22c3894d29b052c1551361e694e34a61a53ad2aa24430a79a50ec29e614d34430a7d850cd29e614c84b0a79850ec29e614c8434a75a530d29d69411e694b09a694e0280585e5c094132717084ac2e201b2136e6a7c8487350419cd4c3d88c73532e6a6409ec4348c47bd8879189847c8c42c8c5252310b23134a36562124629295885958a891b2b109231494ac41cac4c8048d4348d4748d42c8d4c81bc261e1172350ef0820ee09a29e784d393236520a59ee90504495c5d292825a9b1a7991a5b589d6314b5718c4446c5e631111c691bb1c68b8a3498e34546c402a28d171b1223622e36246546c45471a4c4c4546c402a36226362e46c4431883758c4f318bcc6279ad4071ad4eb5abcd6a703501c0d4a0d4a012b6a608dabb84adabdb5008212484e10924240d38243827484db900d3934e4f3932e48cd3932e4f3932e53550d38a69e538e4d38a9aa86dc5344a5b8a69c567570971482e5e714db9cb3ab8e9724972492925cb3ab85172e6e482e492e51570e172e6e4d972e1728ab870b970b935b970bd251c2f492e4d9724972465972439c925c905c9874b921ce5c2e487393855d73936e72e1724172a8451724172e1724972b89a512b9949cae65544d2f2bb94de574157114e0296d29a052c155134f34a75a530d29c6954910c29e614330a79853212c29e694330a7d853489614f30a19853cc29909694eb4a1d8e4eb4a6421a538d298694eb4a01d694b09a052c14116bcb8177080e61248ca5e17084c8d38269cd441090e6a082bda879188d73530f62a0064621656290918869189923a5621256292958839589a51b2b1092b1494ac41cad4c91b2b50b235484ac424ad4c80c8d433c23646a1646a690af09870453c261e13230e4db93ae09b72010524a5249412f6d8d3cc628b6ea7b303ff000cff00cb7ff24f335359ff00e57ff96ffe4a355a769fd4a3188863144b754599bdeb3ff29ffc92dbac6c2def5d8ff34fff000a7d6ff0769fd4ec6c4546c55f8f5ae9e1dee1ff009327f85131eb7d3a3bdc47fa193fc2975a3b4feac31468b8d8ab91ebad39ff0038ff00e4c9fe14e7ff00a8fa522387dd71ff00cbcbfe1475a72cfead31b1151b15459e2868f6f7bbff00f6d37f81110f8a3a3de70dbb927feed37f811aaadc5b98c4431aaa6df13b48b4869bb1cfda9a63ff00e0a6adbaaacd7300d255ba4cff00f05edfef684fadfe27be3fd4c31a9e6b50e2b29da3264c0ffaa53b1d5c0ffa5e4ffe12975a3be3fd3ed6a586a55346eaa76d88171fe1fdea562d337595bb994b91ff0068cfe683ed11602ee148bec37088e1f4f83ff5da7fdebacb0dc1ff004d3e7ff1b7f9a0d1b85ec2951a6ee87b52ff00e637f9a4bb4edcc77a61fe91bfcd1b811442490a5869bba3bb530ff48cfe6b9fe4c5d9e70da519ff00b567f34b70219c136e0a74e92bcbbb5237fd347fe2496e8fbdcaec328da4ff00db47fe24b702bee4d3fb",
            "2b2cba1350b1a5eea06868f7f3117f890d1689bfd483d2a16bb1ff00c78c7f7b91b8a8aebfdd32f5673e1fea47bf636dcd2ef8f3117f89225f0e35437bdb00ff00e622ff001293555c987ab51f0eb53bf21b6d04ff00de22ff00126c786baae52432d5923ffec45fe2526a9bca69c55ba5f0bb57b5a5c6d2303ffecc3fe3409f0fb5338e05b391ff00c78ffc4a2cab962b4e29a7156297416a48feab691fe7a3ff00120ce91be193a7e44eeed8ea33f9a8b8d5cca218b920b94d5c346dfad9089aae87a719f7eb30ff0073946b2d35b2fd10673ff487f358659e33eeb6c70cafd4085cb85ca4869abb3c65b4b9ff0038cfe6971e8fbecc70ca1cff009d67f3595e5c3fe53ffad3a653ee220b97372b1c7e1b6ab99b98ed5b87fde22ff12747855ac9c322cfc7fde61ff1a3b637f65bd7daaa5c925cad07c2ed6038fc23ff00b987fc6bc3c2ad64f19167cfff00330ff8d2ed3fa7da2aa5cb85cad63c29d66fe1b6707ff9a87fc6bc7c24d6bff337ff00750ff8d1b87da7f5512e492e56b9bc2ad6508cbecd81ff007984ff00f9a63ffd33d5ae19169e3fef117f891b83b4bfb560b920b94ed5685d4749933db8b71ffc68cff739415753cd6fcf9a8dd1e3f7ff0072a937f42e527dd20b920b9473f505b9afd86a0877fd9bbf9251bc51019eb8e7fe89fe4b59c795fa88bcb84fdc1a5c93b9042ed46e3c4d9ffc27f9251b853633d518fd0ab9c59ff2a3f371ff00ca7ff45657b283372a5032661fc0a61f7eb747f55481ff0085dfc957e3cff94bf2e1ff002893cae82a1c6a8b46ec79be7fecddfc91905ca92a71d2983b3f623fbd3eb97f137931fe8e05380a55350d45510226b5c4ff00d368fef2a569f485eea0663a36b87fdbc7fe24e4a5da7f516d29d69532cd07a8dddadedff588bfc4b8fd1b7d83faca203fcf467ffc956a95b118d29e694ecb67afa619960db8ff00a4d3fdc50ae95b09c3f23f714f553da7f45b0a79854636e74a0e3a8ecffd477f25214aef338e9073bf711fde9e8b704b0a79a579b41543bc479fb844456cac7901b038e7ee11a2dc25a53ad2a628741ea3ae68753db4bc7cf5a31fdee4733c33d5a7b5a7ff00b88bfc49ea96e2bcd29d69560fff004d755b064dab8ffbc45fe24893426a280664b76d1ff6d1ff00891aa3710c0a70152234a5e877a2ff00cd67f34fc5a3efb2b496d0e40eff009ac1ff00e4808909411c34fdcfabd1f2c77fc6f6ff00345bf475f2266f7d0e1bdf3d567f8904875e213175afa7b1922e0f742477f439dfff0090542bbc41d34d3875c483f7a797fc29fa9dcfea7c8497050bfe5ce9d2dddf888c7fd8c9fe14d49afb4dc632eb8e07fd849fe14f54bb63fd4db8265ed51949acec3707865357f51c7dba4f1fded49b8eaeb1db251155d774deeec3a4f3fdc13d52ed8ff473da8691a80935ae9f0326e1ff009327f850b26b8d3bff00387fe4c9fe14fadfe176c7fa3e562125620ddad2c0fed5f9ff003327f8532fd5565776adcff9a7ff0024f54bb4fe9e95a8395a9326a4b4bbb55ffe5bff00921df7cb73fe9a8cff00e077f255d69769fd2656a0e56a78dce8e43864d93ff54ff24895ccc673c27a2dc032350b2351353510c5f5bf1fb8a728ad95577ff814625ffc41bfde420b7114f0877853172b1d7db01355008c7fd769fee2a23a8c91c5ad392996e18704d3822a385f51388221ba43ed9c7f7a32b34c5d68a0ebcf4a191f7cf5587fb8a5b856c4314928aa2a1a8b9c863a48fa8f1dc6e03fbd3b5363b852b8b66a7da47fd369fee29f685da7f501147bde029ba5b5b6460717b54343475954e1d385edfdcac56bd3371a903f30b02b951a455c7a7499cf2a1e4af63b86c655fe4d16d60dd533b4fea520d9ecb6d6f525d8e4f75524fda84c32cdc323767f447d2d8ae153821a4056afc46cb0faa3899c26ea75a51c2cd90c401fb04823e3d255c19cbf94e53e8d9247fe74810536b2a8738969202127d495f51fd5c84146ce63a4f9d31474f306c923484ab9d2d9ed34ed7c65af7bb8c0eeaa12dc6e0f20be67171e31eeb56f057c13bb6bcbbc55d71639940ce497fba3b1f54cf859e1ad26a302bab632c88f23216a3269",
            "bd3d600638002e01592fd6ba3d2346cb5da98c2e6b71e90a128b4dd4dd489660467ba57934cb2c3751d0d3c55d26d898705596d3a5e1680f9461aa62db60a2b647990b411f287b9dfe2a4cb2201c3ecb2cb95b71fc71b152db20c362187a303e48d9e99006feaa9b25edd202e6c4e05072dcae351c31ee6858e5c8eac78a45d26b9c301cccf07f7a16a357514231101955016fada93f9931e7ee94cb3083d52bf72cee67d627e6d751b070d2a36ab5e38e76b0a15b15134fada94f65a5cde4b414bbed5f8c2cbe22d4464e18e51d59e23dc7bc2d20a26ae2b58ce361400b4c756e3d18b23ec13f6898c86d9e225f641c77fd5723f1035040e2eddfed4dd5d966a3e7a271fa2451d8e5ba3b6676129f5a7fe450f12b513c10f70da7ee970f8a575a3181dcfdd4a507843595037f98e0fdd1cef05677349c971fb2a9852b62129fc51bc197a991fc5150f8af758aa4cb52731feaa3ef7e1d5c2c8d73c44f735bcf6545aeb93a96a1b0d444e68ce0e53e953de34f1e36c90cfbba0e2c5223c7aa40c019090ff75ed07a6f4bea2b6b5b3ba36ca47be14b56780d6b9a532d339a5a7ee8e9537386ed7e30c55ad22501a0a93a7d796c90e7737959cebaf0fa6d330efa76bb0df8552d3b6bb8dd66387b9807dd398d45ce4f5f4053ea8b4d6cdb5cf68fde95132df5558ee97abdc10b0bd4f6dbada299afa695e5f9f62b5bf0e4490692f3d5c0f58b7b95873e7a8be1b32c913ab2bcc950fa57fd0deca0edb4ad9890d1c05dbdd49b95d5dd33c12a5e869d9474dc8c3885e0fc8e4b6be87831d402e8a5128647d94ed046226b43bea49b4db9d2ca6478e32a6996d324cd2d1c02b924abe4cf19f692b66e0c19eca57ae191f299a5a60c8c0c20ae95062690169df28f332933cbc0d71af95ae3d32858aed52c61c9ee82eb4923ceeec932bb0154e4ae8c3860a8efb510bc977645c1aa7070f2abf21c8414bdd693969e5c12fe97f8ef94b52dc4842574e2a8fea5c30b3af3123380e21134da827a3eee38fd557e5b7c45f8f27d2e15965a77b73372aaf76d1364b935cd319cfe8a4e8f57c3280d9c83faa948ae56ea91e9da09578f3658a2f0ff006312d4be0ac12d3cb25171260ed5964de1a5fa8a57b650e201e17d812517507518e05bf0a16e56d8aa097185a71f65dbc5f32cfb73e7f171bf4f97a1f0cef950c2e8c3b28597c35d4f1bc8d8f217d3b0d652db4ed753b71fa292a6bed9e4c7569d99fd17a5c7f367edc79fc2d7d3e449fc39d52e386c6f4c3fc2fd4a065f13ff0082fb5a2a8d3f237718e21fb826a7aed3ade0b223fb9697e44acbff001f4f8827f0dafec39103c9fd136cd0fab61e63a797f715f69cd5da6b39e8c5fc132ebb69a8c7f5117f0097e554e3af8e63b6eb7a0707362a8e158ecdaa358d1b9ad9a09303ec57d313de34b38106088fee0a26a6bf4a1248a68f3fa059e5c8b9858cd2dfab7504ad6ee89e0ab1515cee3337350d772a79d72b037fab8183f726bf19b6c64911b4851335c93f601ac6ce7f39a70bb25b6ce06646129d96ed0544a1b14240f90118208246076c04fc2bec7d607a3d31609bf38b70149d25b2c8641153c24bbb67089b75965ab8c06445adfd15d2cb67b65a2012d446d3201ee11d93d602b3e85a3a901f28c0fd159a9f46592980dedc90833aa2943f643b5ad1ec9d8b514750e0c233f74764f54bc5051d20db4c30174caefeca444d6cac0e6a7991616b3245865f33f182a3ee313e78f0deea5ded601ca663d8f7e3d92b4442416593a7bde78099aa9033f2a0efd89475d6b9f1931b1d80a0e6a80de5a72e2a2d50a6d3d342ddf211d5295154171c4bcb146c7455352fdef24052b05386370fe52991f5d82ba695d397d616d4370f21675ab3f67da7a885f516d70c770b4d9e9c1e631829fa5a9ab89bb5f27a7e15cc93f8f6f8db5ae90bae857992aa273e2cfc2ac8d434b57010581aefbafb7755698b56b9a2751d542c2fc7721619a87f66193cc39f4580cc9ecae648bc5195e95ae8cca5c0b5a476e509ab6e2f96b9af2e0ec1f656dbd782b7ad3d4ee9200f240cf0b2faf370b7d5965740f05a7fb4154acaf1a55d73cb003f09b64c6539f64c",
            "4661aa68787347d93f1ed67b2de7d33ea7db196f296c73895c8ceeee784eee6818091e892fdbdd76395c4e02486f51c8ea6a5006484f6342e82000ef7f64f56d6b1c3647dc21649fa2319404b500b89091e8a9dee7f0e45da6fb35a5d98d43cb392525b2e4e0a9b054e5defb57783b7e5471a47d2c7d47774d415aca6a9635dee51d7eb84628816f721458988582b278ab3ab1824845dd7505deb23e938111e13ba4e26d5c9ba48f232ad5516482a486c6d014d89c94ed3775750cfc8c38ab74f5913da259de3d480b86897c31f5621c8f8551ba36e14cfe9c8e76029d1492ae926b0b642cc474cd07f451951ac1cecf406cfd1571d18f7c24bb0c1c85bc6c22e17cb854e409dc33f7518d656d7bb63e5711f729c2edeef48ca2647c74b4e2469fccf8547039a47518dae7650cf7b01c96e529f3bea06e395e8a274a700654ed5a25af64c76b589f7b1b4510796e0e780b84c54472ec8907b614b69cd1fa835bdca0829a8a77c4f78cbc33d2d096ce458bc15f0f2ab5e6a984c9138d235f97388e17dc70daa974bd9a3b4da98d8e4d9b773472a07c26f0ee8fc3fd33147d20da82de5d8e42b5c316e93cc39dbddf753d8e455aa34ffe1ecf3d7093a8e77382a1aaef8e83d3491647b602bedded82ed186cefe9b142cd6eb6da63e0b64217372e5ef8d30c6554991d7dd4fe639d1829c75a29e886f9a50f3f7288ba5e5872d898183ecab5513ba6712e98fe995976ada5d24ea2e546c058d89bc28e96e1103e9680a3269487e324a474279ce18d2728f4fec7497177f65f842cd7291a3ebdca4edba56aeb0fa98ec1fb2b45a3c346ccedd50703ee9cc6da3723359ea2beabd30c2e77e813b43a2af5759013bd80adc6dda46dd6def1b5d8fb2986c74b10c47035bfa05ace245e46436ef07eb1e1af9663f382aef68d134f6c8436401c47d95a3a87db2121c4b8f72b49869173a8aabd2f415916ce9b73fa2809b418a5797c040fd15d4308e72bdbcb4f3c857222e4ceab6a6ed65e230f781f012697c4eb850b832a291ee6fbe42d1e46534bf5c2d77ea10b5562b756b361a6602477c2a810745afecb7a8ba55cd647b8630e553d5de1a58b52364a8a19a3dddc06a96bf78471d6e65a59cc67be02ac1d317fd36e7082496668fde9ed36323bbdbf5168db839b472c82261e08cabe7871e33d5d2ceca5bad41c1207a8a2aaeb9f7490d3d7d2ed776248558d47a0a8a402a68e50d947200296e33b34fa2ea69e835adb4398e6bc387f059e5fb47c9a5637cb4ace3bf0141f869aa6eba6d869ea9ae74238c95b150dded9a9ade44ce6124720a7e159da312d3d3c9a86ee28eaa33b41f70b46d50e86cd641430607a7b04b6698a4b55cdd5b1340677caa7eb8bc8a9acdb0bf78070bc9f9d75f4f4be0f0fa8fb0d0b9f3ba6907ba91aa9bab52d8d9d814141716d3510c70f212ed2f35151d42bc0cedb5f418cd45d6876474ec0382429eb6b18e61cf75568e47868dbeca76cf3bdd8ea0da12fa717c89b9e25a69590b0f2a0eabfa4bcfba6ef3710c9f631c9744e0e6ee251f6e7e3e3b3d093d2089b9c28c99c39537709637308cf2ab953200e2014e47661290e9064a1a5702947e533215a48e8988699e47643c9265b8213efe4a167700539747d423a2797e5ae2138daca9a320b64271f7497b881943c92e7bf2aa5d95913d45ad67a523a992d1dd5b2d5aba86e8034b5a3d8acbe470730b481ca6a9a492df9746ffbad260c72c656c3596da2ad6ee8dad2540d6d8fa392d661546dbae6a69640d909202ba506aba2b8c404ef6b49fba7bb11f8d55b85355b3223790156eafcf31fcc8ec7eab529e860ac05d090e0556ef3660d69da395d7c79f9f6c32e18a6b6aa603d4f3fc50f515123c11d4c276b68aa192901a709315a5f543a672095d9857365c5a47e24feccbb92e2a7a990f6254fd1e9334b874a7d3df24a2e4a8b55bd87748ddc3eeb6e9b63669154b669a4009079524cd3f0c4cea54481ad1f2542d66baa2a673846f6f1f759d6adf12ae3719fc9509765e7036a5d349cacb3c6ab517db6503ba14a5934bdb03957dd01a6e7bde2aeaa22c8fbe08599f833e19d5544b1dd6f92380243b0f5b7",
            "def5a5169ea214d4a1ac8d8305c10cf5563ae8686d54798d8d181dd67778be3a690b6076fe7180a325d71597f06968c192327ea08ba0b6c56ffcfa976643ced28aa91ea5b74f503ab212cf753f6b836100fb7ba1e9e775cdc1a1bb183dc29865388630df61dca0f493a6ace8fa43b214932b1a5bdd561b514d064754172763aecff6b857b4589e92a03bdd21d20630b9a7951ec91d2b72ce50774bb45450e03c194ff67295a7a097eadc12233979435a28de1dd6a93c77e50d1c8c95de61eecb8f3b53e6a2b2a874d9196b3e70a29e9313d642e1b6270e1362b0e3081a7b63e33bdce39f85211c20f0423d3d12d94b971f239a9d31ec39017886bce3dd54a44b41700e88ed77ca79f7496999b5cedc7f44fb681ec8c3c0eeb8fa02f192dcaa9491ecaaa7ac76daa803987be5aaadac7c1fd3faae9dcea68a364847b057fa7b709e331b99b33eea1aae9a7b3d56592b8b32aa54f57ca3adbc0bb9e97924a8a40e91a390d01678da89e0a834f5f11a7da71ea185f7bd4f42ae94c934225c8c10465661ae3c10b56b78649e976d3d47701a31cadb1cd8f57cbb24ad71c53bf78f909c8e42ef4fba3b58684be787758e8aa6090d3eee1e5a99b3c31d6c6258f971f655d937115450e7928f9246c4c4c3bfa38c3b840d55517700a7b4522aea0b9dc14c6fcb534e767b94d3a420e3d95094eb8e575a3dd0c65fba50952a2896d30a895aef7088aaa33396c64f0838aa0b0e422c551772392a2a645c74f5151dba8773b68761263bbb0d6ed69e32ab11d754ca366486a7a16ba076f07254d2cb15eabaecc8293279e150af1511dc66243709ca9b9544c36107084240e4f09a71e3053411b1bbb3c84dc14c2b416844f44ce76fca262805063039572b591193d13681bca869640f98971f4fb297bbc92540382a1a56b58cf57253b5521d86299ce2e6b7f2c7bae8a87ba410d235e6471c0c7727ec8cb0586f1aa2a99436ba79242e201c760bea8f0bbc04d35a2adacbceaee9baada03835e7b28b9349198f847fb3e5c755554771d4713e0a3243bd7c647dd7d516bb769cd1142ca1b2d345248063700095519354d76a1acfc36c106ca261da0b47b2b75af4e45688db3d53cba5232727dd65964b98a4e8aaabaaff00e10d2c8cf29fa9b9525180c63c17fc28aafbe4bb7a50e00eca0e6958d775667fabbac6d693159ee13d4d4d2ef3e961ec42a65cddb0e5d213fbd1b36ad7743cb92360e02abdd6ae5ab7622c9cfc29be9cf206afac1c869c94053d2cf552701dca97b569ea8ac90191a7055eed3a49903439cc19558c2aa95b747cd52d6bdcc255c2cda36085a1d23470ac34d4eda760635a30886f030b7c7145a6a9e860a5003231c271ee2780303ec94bd90569d62766704fb94a194b70012776d290dba32ba1abc1e0af649ec98772b9b4149c14b1c7729913b36f65cf57ca59c9ec5709dbdc84bb483d23a8f6fca58a96163b7c4d3fa84c4d571b060bda8396e70b5ae1d46f2a72ce7e8f5546d5b4b48fab7bdad6b1c4fb2a357d279670943dc403d96817a860ac9cbdaf69e7e5468a3b73d85950e6e14e3596585db3ab86b68e37368c336e7824053ba66ed3472b590caf3bfd94bc9a5f49f5bcdd4b9bb59c9527657699aeb9c6db5805ace0e1472e5a8d78f8ea7ebee219602c91d8796f72b25e9554d70739bea6972bb78935a2858190bc06e3b2cb24d7b0dadae0e70df95e572cb9bd8f8fac62fd476533e0c840fb1563b5d8191636ed587cbe22dd2a8e691de952968f116f54f237aaf385cd7e2dae8cbe437da6b46d209c61484b0c5143818070b3fd3be29d2f4da2b1e33eead74dad2cb7301b1c8dc95867c1638b3e4b954757d197ca64072930d43e3f49e029b9a08ea19be07b4b4a89a9a72c272b9ae163b78acb01d6d4b71f572a37025c9ca5576013ca09b51b4ed4a3a71870bb92134f4e631cfca625786ade43b4d39dcf281a9397709c9ea319c215d26e4693b26576e6e10cf384b6bb2f20a664777550e10f3bd332bc307294d7f049424d27532ae6c590d4ae0f3ecbb0c8e69feb48c7dd34e04216a642d1e95726d958b250eb99adae10ee2e6f6cab6db6ff004974602f73771591",
            "901fc9eebd4f739edf20731e70154953f4d6ae36b0f697c4d047755cb8b66a581ee85bf9a070020ed7af89608a577f153115ce9ab48782ddc7d96fc76c679cdb0dd55e296a8a2ae7d13986368381907949b754de2f5075e673c6792b4ed45a56dd78a832ba3675bb8e151b505d468f8df13e3f49e0602f4f8f3dc934f339b1d5daaf7e31db5a7ab37e63876cfbab8782fa2cdf2b457d6c79634e5bb82a1586c572f10afc1ed63ba01fcfd82fa0e6b8dbfc3cd3ac898e63658dbeaf95af25f1cd8fdad37fd4d0596904076c31443191c2cc6b2ff55abae628adee73e9dc70e7054ab86adb9788f76f276fdfd2270e216cda1b49d268bb5b65a8c191c32777cac74b4f69fb6c1a3edcd2435ef70e4944d1b1f7ea912924373d940c95b35fab0450e7a40fb2ba51361b2d08191bc041a4e1a66504603b000f741dc2f0dc74a1392541d46a47dca530464e7b2ed1d33a99dd49cff1410fa5b6bdef12bde794719636110077aca8da8bd36388ed38da86b209ae37015873d369e5254592b6eadb1db8c848de470aab6f86aeff0057e6c6e2d27b22efe1d78b9b29e33f943838566b6454f62a40c686eec26a86a8ec10c7eb99d877c239b2180ec6460b7e50f2dc18efcc7b80080aabeb64fcba6e5df6422a5e59626b72e203be10ed9f71f4f6415051d5547ae7ced520da611900764ea61449213b4f0b37071ee9b7bb68c04e43c0dc480024aa99a679737611c27dac00f60a145e2269e9c646e4fb6e448ee9c4d893706e7d8202be8993b7d8a61f5eef94835c5e3ba7b1a08e68a7698fd8a11f432d1b8564049e725a0a26a32f04fba8d65de5a79dd0ca3f2fb72894fabbaa2c16af12ad0ea1ab818d9c0c038e72be55d6fa0ab3c2db8c8658dfe5dc4ed38e17d35d59e96bc55419db9ce11fab2c168f132c6ea4af8d82a834861f7cad31a8b8be2b92b9d730246763ca02a260c3b01f529af11b435e7c35bcba29e37f96793b0fb61551f299809dbdf192b59595c4ff005833890e137d6dcee3b266495b571e49c3824c64319b7dd69bda6e3a145cc1dcaeb268bdca184324dc04f45669dff292adf12146d8e504829e0d119e10d0d24942dc1ca1e5ac7b1fc8384d85bea464ab7463d23f8254370239777fba1e9ea2295bea4cd4bd8de5a524d48c155354485ad6f098b9c15b11cb5a70a329af0fa4973eca6a1d402e0dc10385272582a9a0c65fdb099a97199d8089af7745bb62f7f850f555c28e9c9690f94f1846db4802e755e5dc6304389563f0dbc2abc6bfb9c6d640f652e46e791dc294f0a3c25b8ebbbbb2b2ba37c344d76e739e301cbe83d65e26e95f05f4f0b5d95b0cd707336fa00ce7095be34c60af2ba2fc05b034c8da796e259c018272aa1638f56f8d778f37b9f05adaece09c0c2a5e80d17a9fc68d482f77f32fe1dbf700fce3195f51364b7690b4c769b0c6c8dec0012d0b9f6da624dbe8ed3a2e81b454ac69ab68c39df74c1a9aba8739f50fe0f2108246b374f567a92bb941d45d0ec387631d8256ecf5a3971ad6d31241ca82adb8baa4139213bf9b54f324ad3b10e2dcfaca80c8465bf653a3f0053f52e53f4230720abce9ed2de90666f6f947697d270d0e2695a371f9568e9b59c300015e386d16fa6296db4d4a30d6b728a79da381c24b58472528e1c30b5c71d22d79bea6e5700395efa7b2e824fb2d2781dcaf6ec2e867ce42f3ba0de5d286fea9d27b20fb2e7a7e0a12a6f5434432e99871f750572f1028a10446e69207b151b1a5a30c1ce709a7d64117064190b31aff0013a404b628dc7f450736a7bb563cc8c8e4da545b57d635fa8bf52c03991bfc54455eb4a688e048dfe2b2c95f7cad3c324e52e9f4a5e2bbebea05172a7d57aacf1161a71c381fdea0abfc53c03b494241e1bd6bf1d52e3952b4de0ff5c02fff006a731b7d1b9151adf126ae724461ea365d61759f3b5b272b54a6f0868e1c1786952b4be1c5b22077b1bc7d92e94768c4a0bade092f7ef00fca166a8bacf29c3dd83f75a46b3b7d05bb31401b91c70a9b033a40ccfe1ade4adb1e2ba7367cf3682b8dd0dbe89f0d5b8e5c3b15a6784762a0834c545e5cdda5a0bb2563b772ed55abe8e82946",
            "f8cbc07616ade215ec7877a4e2b0d30c3ea23c1c7dc2e7f91358b7e0cee77518ef89de27beb2f5252c0f2e6b5db7854595cfb8bcbde1df2a6ed9a065b854c971aa713b9dbb95648b4dd34606dc70b8a658c7a98e1545fc424b5b4068727e3d48f760bb215aaa6c34d507616038fb287b869b8c37118fe0b6c79304de3a7292fd139bea79ca91a4d47342e029e5735d9f954f96cf353e482504ea9a9a67f1bb213b8639232c75f6daf4ff008ad576b959055ca5c338e56ad6bd4f497fa30e8dc3790be4aa6ad33e0cc4ee0aeda17574b455ec83a84b738c6570f3fc78d78b91b6d7c2f6484b8f082e987905bec9d9ebff0010a4639a7921330b1d4cd05c7395e5e78eabd2c2ee1d91f86fe8a3ea25ce53f50e703f62a3eaa40df7e55634e9993d49a77a111144e7b776d29892191efc6d3846c430f76cf5219eecf28e963c8d878c20aa19d3ecaf1bb1b0f292d614144fc9394ed44c490d5c6c41a3256f8c45224c6d40cbc92889e50de32857bb232b489a19e7053130c8e4a54d2e0a1257b88eeaa46769b2444ec82511497c9a8a60f2f3b07dd474cf21092b8bda5ab6c71db2b9345b7eaaa2ac21c07ad476afd314bab29db9fabeca974937913bc6558acbaa0b251bbb1f95b636c619c952ba6850786d6e7b9cd607019c95956b4d5d5baf2f5e5a8b7f4deec60762b4ed55a7e6d5542e313f01c3d943f879e1c36cd723515677b8762575639cd6ff006e3cb0f570f0a74352694b6b6b676833bc64977ca94bfdee5b9cc69622719c60222ed7214f08899c347b042d8edbe66ac56387a07254dbbf68d2cfa7289b68b679897eb233ca12bef8fae76d613df099bd6a06bb14b10f48e3850f0d4368ddd47720fca06964a18e1b7b3cc388de79e53d2dd5d5dd8fa42ad99e7b83b7024468da5dd911460927dd0343f71aa9440cc9cf0559e002cf6c7538e247842596d5151b7cccce05ddf050f73b81aaae6900ed6948f492b433cac6ea89b9777e50f75beb725dbb8f85eabb9c2da40ddc070a2ad3a7aaef157d4703d1ce7ec993d0cf5b7590361c86956eb1e9d34ad12ce32e4e5bec6da190318de47bab5d3528e902fec888a043daf1b18dc00932b035a71dd1759d160c47c15075d7265030c92bf181ee9d10e4b3c54cc2e95c07eaabf577a96a2631536483c70a0ee37d9af95bd0a7c8667190adfa56c0ca72d7ce3793ce523aed82c9505e679f383cf2a666a66c4785324461a1b180028faf8c86a652a325200433243b93b20223739dec86a27f5e420200e8da1ee05dd90373a489efc81c2927d2c85be9e131511131ec23d5f299ecd476c1514c0478cfba625b3cd0bdb3d3643a3e4a91b11752c9890e4152f342257e622369ee1544dacef5f596d9afb4f4d4b708186b58c218e239caf8af5269eadd1b789a86ae33b093b4fc85fa175fa7e29407c0d01d8e5611e38f8731dc6db2d50883aa1ad2410395a4a8af9664836c81f19f490bbd324e520b26a1a87d34e0b5c0e3053c5fb3d2b4c51908a69c424128c7de9b1b78c28573f73b0b8d6673954cefa948eebe69d87945ba9a29599c85000169cb784eb6ae6031938422e0266618c90c29a7325777ce17619b73c6e2a6236c261cf084e909042d95e5af09ddd1d03b844980f509633f7a1a76095c411c84f47bda5ae776651c4e8587a933b801681e0e783b53a96a85e2f9198a8da77e1e300841783fe13cba96e22eb7acc74b4ff98e0fe33856ff00163c6da6b3d17f939a6435ad637639ecf6595fe4744896f15bc61b4e89b67f93ba5a36367da585ecf6540f077c25bb789f7c65eaf6e924a10edee7c873bfff00f8ab3e19f87772f12b5146eaa12ba95cecc933bfb4becca2a0a4d19a7e1b05ad81a5ac00bdaa72ba8bc67a3a496dda7ad6cb259606c5b1a1bb98142970b7b4c93384923925f5adb7c1be421f29f9eeab757749659cbdf9fb05ced76919eade0b9ef3dfb046da2c52de1e27932c887293a76cb517ea98e5aa618e06f7254f6a9bac36ca76db6d5ea791825aae629b921aeb5710905aa9181c49c6e015ab4ce9a650530967e5e79e505a3b4d6c679cae1994f2372b54af24e070d5a4c11727b01c7d27012f81c269b1",
            "b9df4f297b760cc8701692693b75c09ecba18473842d55d69206e04837283add4752411030bbf44c2cc5f4ec199250dfde80acbfd0d08244ad247dd52e575e2e337d2f6b4a269b4554d5bb74f2bb9f6296ccf5cf5dc926594f193fa2ae55dd6f57276236c8d0afb43a3e928c02f01c54947474907d3037f8247ffe32e8b4a5e2e98ea4af1952545e14cce7074d3123ee56901d181e88c3524bddec48468b6acd2f8736fa603aad6b8852d0e9bb5c0c0d10b78fb233a6e79e5e5284447ba7d46cdb28adb00005337f8275a2947d10b47ee5ed81283404fac1b7b2d3ec07ee5eeb3da30d76171c7e170b328fa4edc0e95e7eb2a2eff723414cec4b838f952734aca685cf73b1c2ccf56ddbcd4ae8dafe32963f69e4cb515bb8cd3ddab5ce2e2e00aa86b5d431db295f4513bf35c3000560b9de22b052492b88dce1c2a4696d315be21ea56d439ae742d7e574dbac5c5aed92f5e0168c91bd4bddc63e47a9ae704278c1718efb77691eb111c05b1579a3d2ba4fc841b592066d38f95f385d2aa692e9303ea739dc2f0fe5f37e9ef7c1e0d5d9ea79ff0023a21fb0613587b0e1b26e5256ad2f597191ae9a32c8cfbabfd974358230c35754c0ef7c95e77b5eb5ca466904139c9d99cfd905534d2c4f2e78e0fd97d1747a2b4c3e10209e373bf50a075078754af639cc0d03d94d99e3ea30e6e3ceeb17cfb534a24c950f57451349f4ad1afba61d4323837b054eaea0737390ba38f96c1c9c52c53eae864dfba3e111a4e39a3bbb77027952e436304382274e53b1d726b837dd74e7c92e2e5c38b55b1daa426823cf1c047c9365ad1dd4752fa28d807c277a99195e3f35dd7a3c73c395554191e08e5474503aa25deefa576b2532bc0f60a1b506a68acf48e01c03b09f161d8b3cb4b4bee1474b174cb9b9fd50c6fd44d691e9cac4ea75acd5b50e2d94e33f29cff28a42de643fc576cf8b6b972e791adbe586a9c5cd7800fdd71d4d1b987d60959743aa656b70d7ff00b549506a99b3ea771faa2fc5b1587c895679e9dc65cb5b9012276bb6fc2129355423d326de53d35c21a9fea9c0e54fe3b1bce4951752e70714319cf62a42a217069710a2a773492328d54dbb2247828595e9c71da8599eb6c316395312bb25324e0e575eee523bf0b7918d36fcbdd9f64f471e0b5ccf64d3dc038307747d1c2e3b78cabd32caae9a76a5f353363dd8e14b485d4e77077651da7681d1c41e7b222ef58c843980f253c3ed19112cc6e350d8dbcfca9f354cb5d0f401c39c14169da6318754c8381cf29abd571aa977b0f0d5ab3d1e7cacdae95e79eebd6f89f73970ee231ee81a5a696e9f9632023a7ad16e845141fd6f63840d0ea8af14cf1494eddded90ac36a7c34300967037bbe541da299b0c5e66a002fefca0ef177ebca18c7600f6081a5aa5b9bde4b9b27a3e1032dfa30ec3705dd946d2cc64a6da4f38533a5b489b8d4f5a5fa339e52160cb0d8eaf53d535af0e8e2ce72b5ab75152d9e89b41180e781f52cfefbaa69b4dc2da1b7006a3b7a7baba68e6d45c2d0dababcf55c3b14d9e4968a9a3637790094154d7f4b70053d5d52da36e4b864fb2a86a3bdc54b1ef63c127db29a64fd9cb8dfd94c1cf7bf18fbacf6ef7aacbfd78a5a6dc63270484c5c6b6a2f53f458480e5396da7834f51fd21f3bbb7ca2ab490b55aa0b6d3362187541fe2aef6370829f13bb6b80ec555f4fd04b21fc4ea0904721a54956d53eade1f11dbf609154cc775df52583e91ee97533f59c003c28fa4831103fda4644cdac739dedca648ebecc20688dbdca274ed0ef66e70e4f2a0ae33bab2bc34720156db4fe4c6d68e32132a90e835adc2664a2648c71039c2225761abb4c7391f65a691b57a089c2adecfe0a4286734f339b31e0f6ca43008ee049f94abed33a4e9cb0f66f2708d1241f218bf4728bb95861bbc6e8a5008734f708ea378ae8983dd8394fb9fd33e93c809e83e1bf1ff00423b4dea17d5c11ed85c79c0598d303521cef70bed7fda0743ff00943a5269e38cba60dce405f13626b5d54b4b334b5cd76d20ad302c8b7c5b4ae118c27633d57945c7461ec713ecad96d192ccd6f64a88ef1d935345b663944c",
            "6f0c6e0042a987b1c1d91c275b53335a00c9c25bf2e192384982b208dd8939fdc845f53965b9c1291048d1b9dc298b9e988a958da82e003c642a9b22a70f1514b212e6f385394f70baea78853c31b888fd2b4d33b8fbe346f143c5086cd466d9a65cd6473e5ae737d82cbf42688b8ebcbd3218d8f7b1cffcc7fca86a0a1a8bf5da1a3877ca64781f380bec7f09fc3e8741d89953d26f59eddd93df2b96e5d63b31c76b068fd2741a0b4fc76e82268a92dee3bae575cc52444b9dba7fba6ee57aeab9d313898760ab92d61a89dcf98facfb2c6e4d7aebd39515eeac7f24ef3ecacba4f48cd7399b2d6b0b631c8513a4f4ad5dc6e5d791a7a40e42d677b2d36d7876d6963784f1c6545a89d455d4d61a0f23000d7b86063ba89d25a72474aeafaccbf2770dca368e0aad5b7ceabb3d38ddfb9689335b45046c180c68c1c2d64457a41d4c7486dc7b04873c46312f081aabd450b48839283a77d55c9feb04355e35360faeba369d83cb1dce403aa2e15cdf5348051f0504303ff379fd518c78190c68c2bb06907169cebbb74af395294b6aa6a6182039141fb4f2171c43cf0a29e9d6f4e33e989bfc128c99ec30901b8eeba9c370e4fb95e6b5757427a327760a5029b7c8c88e5e7092dad86576d61053d11ec85dcf092ef4f2bad3919489c071dd281cae1195e6f09078f009f75c89e5cef570171e0ee00266e5591d0531739c01c228be440eafbab2189d144ef561676e68ccb3d61c3473ca90b9d7bae1723b7711950faaed171aca50c80e1aee0e144bfb619eeb33bfdc1dabb5032d76e2e7343f0ec2fa234569ba3d0b6281fb1be62468cfce550f4d696b268fa517290b1d58464e7be55a74edf1da8e7225c8634fa7e1472f3f9a69c1c3bbb44789177918c7ee7e1f20f48595c174b6daf7d65e9cd6bc72d1f2ad7e33df20b79c3de0cace1a02cd748f855a97c54bc475554c9196d0467d86179df8672e5ebd9c7967163e3d77f14eff007594d369aa691f10e016b545f92f142bcf53a354dcf3c02beb7d1fe0ee99d234d1c7040c7ca07a8bb1dd5afa54148033cb45f1c342ebc7e2cc669cb9fcbb93e1d96efe26e9e01e195476f7e09561d31fb415da195b4ba8c48cc71970217d7753a62db7266e929e2daef6da166be207ecdf62d554b23e8f10556096f18e517e34b3d8587c8d5daa9f8bd1eaca1f356f735edc64f2a8d7860eab980723baa5dcedbabbc16bef91aaea9a273b19c1da42b8baeb497aa465452905ee1970fbae1e6e0e9f4f4f8f9fb44055d3347d4a474ad16eac05a33ca0ab838c649eead1a0685d2481e5ab0cbff5698fdafac8991d2341ef840cafda0e11d58360daa16bea853b092785e7d9bae8941d7dc9b046e248cacb35655d4dc2673413b5592ff786c84863955269cc84eec15e97c6e3d7ae5e7aafc740f872472521fe603bdf0ac21acdbd86532f81ae3d97a3872c9e3832e2ec826554f13b90708d82f0f04045be898f18c219f692396857793147e3b0736b0c807ab08fa3bc9a278f5e556df0d4c3d81c04b8652fe5fdd4dc31c8e72658b47a4bfc55916d791929aa881ae3bda72150a3af7d3ca0b5c70ad56ebb36a20d99c9c2e7e4e1757172efececa40c841ccf6fca7a704124a09e32eca527e8f3baa43b2392b80e7b2ec8ef4e1371f055c9a6772d89869daf3bbfb4a6ed34ee91ed696a8ba58c821cad763832e6bb09ed37158a08e48a8b6c6de405046964adabc49ec7b2b4c7274623f70a16a256b262f8fbaa9e33b0f4b31a3a6e8f0010a2191174f8ef1bbba5569a8ab70c1e149da28da0813b835bef9572ed2e364753343689bb9c9ea4a184486a6a48eb7c152d595967b752ee81ec74d8f65596be7bd4e453bc750fb045a342ab2ec2493a1177ed8088a4d3ef97134a0f3ca3f4fe8c962aa6cb58d24939e568d5769a486da368682028b9b59c5b9b5120b3b9ce6b621c29aaed430e9ab3b9a0812e308337265ba395e3076f6545abac97545cfa3976ddcaa567963a59f435b26d4779fc56ac97461d9c396bd72d4f4f6da76d3d116ee03180a9b65859a6ecc22e038b5433ab80a87543de48cfba7b61564b8ea47490b9d33b0e546acb94974aa313",
            "5c4827843de6f0ead9ba7113c9c70a7b4de9d31442b2618c73ca36d31e31368b6c76fa633d5001c39194edbe91f75b80a939e830a16e758ebad63292007683838561836da290528c65e394f7b4d891aaad635ad8e0c06018384c5339e5e368c8510e9cc47a7939254cd0bc47083fda284d4dd29cb401dd26e95d1d2d3b9ae387109ba298440bdcab7a8ae02aaa446d77ba0b42ed30baa2674a7919570b7b410327b281b2c1d1a4048ee14953d50873ca7b2d25e5a9a7670f704ba53b9c5cdfa5552b6a4cb38c3bdd59ad2f0697693ecb499a2e28eae904355b8fb9524c799285dc672142de5e0ced19f753342efe84023b0d7802cb2ba9a691b27b9522f04bb3ec547cadd9520f6ca267ac6c65adca5dcf45dde95b70b5cd4ee6ee1b3b2f80fc63b04b65d6552e3116c4f77070befd8ea83dae6e7b85f347ed35a66134aeac647ebce7215e39a6c7cef4d0131095a32d29553582266d67d4a4f4c745f47d19bb938098bb585f472ba7703d33c85d18fae5cbcaaec8e91d265c3ba2e3d819cf7499b13101b8e1798d6e76b8f28d2b7b3f4e249de1847a4abc694f0b20d5af6c70c84487d8154126a59235917b9c05aae98b66a7d21661a82277a36ee09c83e86ea9f012bb4bdbbad460c8fc723baa9691bf3744d43e3ba441af2efed056dd27e3e5c6e1757417e2d7407e544f88b0da35bd7798b2b9a1edefb7e556ff0083f7eaeffb39f8581f5aeafba4203d8370dc16dd7fbbb6923e9020323e3011b5d4f47a6a13e476301e0e1502ed5eeacaac177a0f75c195dd76610d57d4124d6077a3e113a634fd56a0ad6d40691102a2e9e9e7b95c194518261279216cda7a921b0db190b1803f1c9c2cf6bb52d6ba786dd44d898d01cc1c9541f10f55bea2b21a1a124e4ed76d572badd60a3a27bf78ea48318cac96b2b69ec55d2dcae4e01849734b9698d63a6856bae874ddb23c4799a56f271eeb91b2eb76717073831c546e88d5568d724b59231dd3ec32afb186526238c003b05a15036eb3450478a81977dd1b1f4e176d8800bafcb8f252e38d81a5cf3b40e49578d4d25ed0fe485e68681e9519fe56d94d59a315b1f541c6370528ddae6891872d3eeb40e0683f524ecdaec8ecb8f25c784a190de549944e57179bd979103cbad76085c2bd8c85410fa97ace8f10e7f72634d514e017cd9fdea74c71bbfac0bad2d8f88c60261e79dc709406385c23dd737e0a9b417ca41c9294e76d6e573aadd85c4f653b0e97889bbddd82a46a66d5ddeac3209088fdd48de35753d146f81ce05c738e566da8b5ec96a85f2b7233d8a9bf427f162acadb5e9ba622a0b5f363fdaaa373d70faa6b9b4ec2d6fb7084d1d67b8788d72f33339c60073f6521afe96d5a65a28602c74f8c6077cacd531954db95e2aaa6a228e471735eec6015b469cb5c1a7f47cb73970d708f70cacf340e82a8d43531565402d898eddcab378cb7d75b6cb1d968dd805bb4e1727265bae9e2c77f4c529e9ebbc55f108b0873a9629707e3195f5dd8ed34ba5ad14d4345131a03403c77385967805a469edb0c95b2463ab27ab242d7a670712491c1e16bc135ea39effad1a70797f6cb89f64cddae56ed3f44faaaf91a48190df745b5eca2649573bb11b5b9c95f2378a1e2c55d5f889e4c4ee750365c1683c632bad87da7fc44fda1ee76aac91b6f8278a0c90d76080a8945fb50ea9a2af8a6323df08397027b8578f18757e85ba787f4f4d414b17e221a3716819ce17cf742ea03108ea21cee4e62257d4359e2069af1bb4abe2a96c51dc18cc0c8c1cac5adb473e91b9cd4333896bdc433f454fb7c372b2dc595569eaf48904e0fb2b957571bb74aa26feb99dfe5727c8c1dbc39a42acb9f50c6e72095aae82b516d309037d9655a777dcebe389ede777bafa2b4fda5b6eb235e40076af139b3d5d3d5e3b2c56ae996ce41f654ed595cd6539635dce15a7505506bdee0b22d597873e63182547161bbb5e5751072c92ba47924909a01c57a37b80cbfdd1d45452d6bc3628c907dc05e9e1351c97da15808f6ca2e187a8dfeacab559f44191cd74f9683f2af96df0fadd242099580e14679587319b63a289c4f0c295d02d1cb56d13f",
            "8794ad69e996bbf4555bd691349922338f9c2ca7255f4959eba9d92705a147575a4b4ee670acf574629dc723b28f9641271ecba78b918f270c54ea22310c1089b3d41865e5dc654ad6db44b11701caad625a5aa00e7195d335939f5d6aed34e268811f084ca6a8e6ea4039f65e73f056367ad2ddc25cef561391b32f09ac73946d233241284c174ad2646b3e55eac5481908247b2acdae83ab3b5f8e02b9d3914b103f64ced72be70d6ed0a19f2b4673dca7eae7ea3c9ca8d98ba6ced07d3eea99582a85b31a96b49c872ae788d2de68dcd82dee7073bfe2ab9694824aca9682ddce078e1586bb49c570bd42caa2184fb15b618ed965e325d2560bd5752b9d70a92d7e3237155f87535cf436af61a89cbe9cbfe7db2ae3e36515cb48383adf50e6478192df858bd65454dd697cd54cc6491a4f27dd6b78ff00a8bc8fbbb4bd652ea7d3b4f7081cd739cd0480a3f59d79b7d096838202c83f665d6752e73adb50f718631c64ab9f8977dfc42e5e5297d5938385c7c9355dbc59ef141db2a25bc9958ece14b582c515b6ac54380ef9e53f6ab38b451b257370e78ca66b6e0e635c014e7d23905ea2bff98944119e071c280acb83a48440c397151d3d4ff48ea38f7561d2fa764b9d536a1cd259dd365861ba2f4ae957d416544e0e073cab26a1bab28a9850d3e37386384657d74367a330c780edaab765a196f3721553026363b286b979135a5ed0db7d04d5d5830f232dca621ab75c2492779e18785cd677e6cb243414470d186bb0827ca28294440e1cf1ca71cf6fa2627f99ad0ef60ac14513df301fd950563a673d9b88e4f2ad464651d26e380fc2a4d22e952da681cc69e70a9f47bebae6d3c901c89b85d0cef78c944692a7135439f8edca096f7b8535346c1df0987bc861726eae6ea4cd8fe172e4ff002f4b9fb20804733a4ad03271956db7cfd366dfb2aa58e2f332f50f3ca9ceaf4e52d4c18b94bbea47eaa7e81f9a76855a9fd7383f75354d2ec85bf6403d5cddb3b70a26f53186563b3c2327a9ea4ed51da9f8a5eafc04011475796efcf0a8de3bdba1afd2af976824372ac568a9ea5039d9519af22371d392c4eedb4aac7ed397d3e2ab74fbaeada767a431eae5aa2ba9eb6d6ca7880ea3460e152af104965d493ec69c079c613aebc74dc1efe49f65d9839339ea2a4864a771f629109735fb9fdd1973a9156e6cb1b70077c21f22621e38c2aa73e8e0a973246bc77072adf59e25dceb34fb6ced9311818c2a5cb87723b244636bb2110414db73ab184c39328e4e15cbc2bd0978d47532f93798b69c1caae592e51da9ef9646eedc3b299b1f8a95ba6a791f6e8cb038e78e12a26ef8fa8af9739a466cde5c0f1dd579a1d5528a68f25cef75c96bdd330c6cf538f6567d1f62d83ce550c11c8caf3ed76cf160d2d6386cb4626a968df8cee2a4d97d1512be3032d03ba8ab857cf71229210434719088bb5343a7ec5d62e1d57059ec5546bee35974d4515231ce318900c285fdaa6ceeb768fa69299e5a768df8e3f5573f0fadcdb95c8564ace0bb20e145fed45446af4b3c72435856d833ac83f658352ebc3ffa43b6177d24afb0ab30de915f137ecc554e8b5518f7100b870bed9aff00eae12b5cbf69333676ee070a3b5d573ed7a56a2a23387f4cf3fb9484e7f272ab1e32560a1d035329c7d1fee5580af89edda96f53788c246d6cc5cfa920b779c6dcafbdf4c17bb4bd2c921dcf73012be04f0da94ddf5f47206e4754bbfdabf412d31797b053c7f0c0aed07a3f75d27d9718ba14ec38bcba5713943cbd9c2f2e8e55ec12f6178c0e1758ce9f0794ace1789e3853687095e2cc8ce17071cbf801445db51434f98a0702ff0080a761232cd1636b9e061415eae869e173603b8fd909036bee520243834946d450d350b5afa87838ef94ad0a1c962a8ba4aeafab718e367272567da9aa63bfdf1964a067572e0d2472adbe286b9e90169b4e732fa496a2bc24d00eb4cedbdd7b4be43eaf50553e995cacab7dbe8a8bc2dd0ee91ef6c752f8fb7be70b23d31a72bfc43d526e757238d387e467b61681e235aaebadab590401eda769c607653fa674eff92b646c0c8f6cb8e4acb93523",
            "4c6dda6594b4b62b73a9695c1ae637b85857881727dc2f4c61f5ed77256ad7b95f494ae99ef3b9c3e564f5d0896b9f2b8672785e6679cdbd5f8fc7ac775adf8792b596a8d91f7c0cab5e5db5c09e566fa16e268a0209cab9c3766ccd2e710177f0ebab979a6e97e25543e8b42564ac76d7060e7f72f82aa2096bafd5154f25c4bcf257de5afa99d7dd09550539dcf7b3b0fd17c576ea78a8b52545b2bbd0ede7195bedcf22a15d433d3563a47cdd46939db95c9035edc91b4fb292d5568aaa0bac92d28749177f951f456eb8dfa66c70c4ece79c055322d2c5a6754d3da28e48aa22129238250df8b1acadf3110dacddf484baed3df83c0d6d48daf3ec5234e5ba4acbac74f130b9ae70ec173f3e51d3c72b65f0ab4e7e35591d5ecda07d96e17ac515bc403d9b8407873a5a3b169e64ef6ed7edca1f575d07947bb3d97cf73cde7b7a5c176cb7595d45287e0e4e56575f28aa9baae3eeacda9ae66aeae48f39e5565b4464972f386fbae8e0c1be77c3d434aeb94ac606e183b956976a0b3690a70048c927c7d3ef95022b3cb86d05b1a659e4e06d0af3a13f66ab86a3ad65d2fb2491c6e3bb6b97a38e3b717272cc540aef14efb5f218e86824dbec5ad2876ebcd6f091b28ea31ff54afb0ad7e11e9cb2c4c6c7491c85a30496852c34769e0cdbf87c25c78fa42d3f179ec735f93b7c7d47e35dfed61a2ba9e46e3be42ba587c59b56a88fa155232395dc60ad8354f81768d42d76ca78622efb2c3b5ffecc776d3313eed6679788bd5b5872b2bf1a59bb34d30f93ff0063af3631231d346331bbb1544ae8bca3dcd6f293a5fc4cac866fc12fcd31169d9970c294bfd3c71013c043e37f390b2bc5707563cb3245c72e62e5445e6998f883d83d48e12878f4a6e58c48dc1578e7a467884b448e64783ca2a43976522287a5d938d6e4a2ff0059fd42e21bce1495245ea0d084a78bd4a66df4fba668c2622c366876300f75250cfe6aa0d3b8e309b6c1e4e8c4a7be134c69111aa1c12a99e596825c774756208f9e7b84557c6ca0a68f0dcbe4c276c549e7eadcf78ce3952935abf10ab6b47219ec8abc66d6ef0a74eb44d1d5ccc1b0f272167ffb43eb8974eeaba775a8e5acc6edab5db25e6df66d3b2d3c92064e1a43560dafec955718aaaed2c7d56349209e57471d61cea16b3f11eab57d28a7aa89d9da064aa2be95d153ed2e21a7952304f5373a97b053ed8dbc6404e5bed15ba8eec2d3491bdc7b7016f7271eadabbf8075ad82e53b01c388eeb69b0589d57799aaaa46f00e465517c3ff000beb74a54b65a9639ae77c85b95ba81b4f49d50dc642e2e6bbbb8f47831f15dd47571f4f60f4867002a25cee43a6e23b8537ad6b36ce446ef7552a1824b95c591004b49e544fa3b3774334e5b67beced6381033f0b6eb650d3698b2e64201dbdd43e94d331d19665bb4e33d9466bebd3e470b6c0f39071c26d71c7510f515d2dfaf2e6373d3ce32ad26aa1d3169901c0739bdd57edf466d5431cee6fafb92a2757de5d5ed8e207bf050e7e4be9ed38d371ac9aae53b86490975b3495774644cc900e1056ea8169a3d8c3973c2b0e97b6991c6b6a1bef9e5563582e56aa16515089a4e0e3b280bc5ddd24858ce422ee57812c5d38dd800615626abc4841eeaca953bbb1f772b8e94a4f2b4af94fb8caa6443cccd1b47cad05ad1436a67c9082728da2a2a5ce27b1426a2aa25bd2edec9fb3bbd6e71ec544df67eb5c59137e50139a7a2f2f44643dd1cd6755c6443c0df2b6f0df909fa777f452f3f098d01924fe9207dd4a39fb216fdd41093a95b8f82a5ab65d91c6d40781cc81c4f64c5fa4eb5b9c3e024d64bd16b4fc842dc26ea5b9ff00a20222c75986ba9bdb295ac2af6da9f03067d3dd41daaaf15e63edca375055b5f0cb14787bcb7b2ac7ecabe6bd494745f8acce95cd2f24f050967f0f85f193549936c6cc9519e24d0dc2dba81f35407b18f765becb56f052cb51ac2d4fa4a6049906095d7839329fb62373db4551251d30eaec3824051deac10e1b095f41eabf07e87c39925acbc48dc4b97024e562da963a2adb86fb6bc3a11dc85744444711d9b49fdebad25be8c647ca3051c950",
            "d11d382e726e5a5aaa31b2aa22c6fc9088529564859575ed8a53e8256b0cf0eb4dba8639a7a889ae70ce090b23124542e6c8c79c9ed852b4f2d55f19815b2300e319415febebab7e9886dd2092ab191f28f9ab267cad8a0188beca145dea2f2e1bb20052b4b2185b8eebccc9db728b25ba18e18ba8002fc65533585f1d74a86dbdae25c1d8c056575c1b4d42e93383854ad3f42eb9ea8754c9cb377bacf5434ad2946db4dae98e30f24286f1fe8fcde8a9e4033f967fb94c1ad6d34ec85f9da3b6131e235baa2eda22b9dbc06888900fe8b5c7288af917f679aaf2bae030f1c8fef5f75d44ad96969dd9ee015f067827534f6cf110b6ab180f2dfe0e2beeb37bb6f94a77751bb4818fb70b6cf29296ae8ac89016059bfed3174143e1e4b10387381fee5a3d1cd0d6d4134ee05ab0ff00dacae4c6e9c34c1deac630ab0bfc2b189fece56df3daac3c8ced700bee7feaa8e38be005f1a7ecab4ae9f5148e68ce1c17d93579e1a3b8c2aca877186af05e0e1b405cc72b3d828ae2f121bdd73704e50eaf670bc395ec6ee15ca1e2449c0ee999647d28cbfb21ebeeb05bc63397a81aab9d5d73bb90c4f606dc2e351564c74ffa7098a1d38d63fcd55bb9ef82bb44c9216ef6f2518c927a93b66e1aa6d3d0b9eeb4b474fb29da0bb1ecaa75f4d5f7a7bda77069ecacccb752b5fb9ce461a8a6a768e986f0a6d2526cbe13d23aa056d77a9ed391b95cba5052c229e301ac6f1c244f74320c0e07d934ca989ec21ee4fb2b1e3dddd150554148c3b236b8fca8dacab9ea25710df484f830b5a5db86144dd2e82dac74cec08c85cdcfc9e34c30ff005a8ab6a9ac92ae414cdef9c6155b525ae6b6d23262d232acb478ba5cc5477617655835658c5d6c8e11b3d4d6f0bc3cf92dc9ec5d618c8cb6c7a8453fa5c70ae56dba9ac66d8dc3959e5a29a1a2ad9a96bc6d79243729fad92e563a86cb4efcc47918f85ebfc6e59ad57072616b5cb6ea16d0975355381639b8c15f3a78cfe1fd5bafb25f6d6c70693bbd2ae8cd650cc41a9710e0a519ac6dd5d4c69676b5cc23192babb461d2b06b2de618c186eec3bbb1dc14fdaaf366b1bdf35286b9ceecac57dd2562ba4ef919b5befc2ae7f93b67a0936c8f07078e54de4d7d9cc2d57753cf51a96abacd690c073c2d27c1bd1acabb943398c9da4672aa8ea11357c74d44cdcc79017d33e17e97a7b1595b51230090b72b8b9f976de63d66ea76f73f90a2653b7d2d0decb28d67746b29246870cabaea6bc074af2f77a02c435ddf04d3be385dc6579b2f6c9dfc53ae1ea9924c65af7b8f23298b8ccfcf4221ea7f0309f899c171ee9eb65b65b9dfe8db10c8dc32bd1e2c5972e7e35ff017c278a47b6f17361739a439a1cbe829e72f6882261635a7190a2ec56cfc2ac546c89a1a4b06ec7e8a40c9d21b97a3c335e3c8e5cf75e70e8c780e71714cdc2ae9ac740fafad9435ad19e4a7fab1524525755383626b7392be5fd4fe353b51788efb04d2916bea6c27db0b7b269116ad4dfb51525a6be5a7a53b8309032147e9efdaba92e757e4eef14629de70e247b281f1c748e82a5d391d5d9e661ad70dcec1e72be7ea4b552d553b8ba42d78ec89373d3fa7d11e2ef87da775bdb1fa974a3e2eac6ddee11acb3485ee4aba19edd5e4f562f4b7777513a17575ef4e559b744e91f4529daf69ce00525a8e89b0dea2aeb71c46f3ba40173f2e335a7470f25d93875255185dee5172b4b39f65caa732b2464cdee072bd2499600571dc5dbdb70a69dcdcaec4dcb93593b30d4ed1b1ee7e4a7a4548d343ea0ac964a4dd54c2470a1e8e2dc41c2b758a9c17b5e47a4729c397c3b7e9d90c423c8010fd4dd6c6ede42afeb4bfc325c05140ecc99c70a7b4c51cf5d4d1d33812e5a4958657d5af42d9df2c6e7969e4299b6dadf4975707b7d2e2ad3a72d315bed41a1a049b50a217f9c739e3f452e8e3fa513c58d3972640daab5979c0c90d551d3bab9b35ba4b2df632c2e1b7242df4165406c53b1ae676390a1af3e13586f350daa635ad7f738578e4cf9f1dbe79bb69fa4825e85a222fea1ee02d67c17f0a21b1ca2f95f08de467d415e2d1e19d96db2b64735a5cded95659",
            "cb1b00a585a1b18e384ee6c71c00dda8e0bad46628c0681ec999e114f6e95878da0a2f6f9768d9dd017e95eea42d8bbb872b1caedbe374c3351cb2d45ca560048dcad3a1b4e97c8ca87b391ca29da69b2d497b9bea71578d3169f2906d2d038445e33ddd1954e650d1f5bb10dc2cde3b7c972bf3aade0966e56ed6771e953795667776e13163a334f6a33cade719ca6d6df025e9d08a47b09036859354563abaec208f901decad3ac6f0f2f7c50139771c288d296c65bdd25757fd47919439793d4abedce81d03e5fa7856b8ee703684430903854e96f0ebb4ee8dbf434f0bd2578a2c47bbd455e0e7fda4aaeb4d39738bbba129a6f3929765045d2d41dd27d2bbd4e811d1562c58ec1197d7e0f6055beed59be2644d3db855bd32c058653f56328f6cc6a6a4b41ce0a092d0ce29e9b7679c28ca38cd75cc4a7900af57d6c70d3989c7d5ec8fd29135903a597f50824cd63c10d8dbf0b9512f97a2c76e10cd93cc56e5a7d20a4ea1aa8db008d87d5d9330d6efcd98bcfca26b6af74cc6e7b14c59474a12f97e10534e1f56483c02821d77a91f94d050957518a531e7b84257d746e9e36e794d5ce62d7b79e30835769a5e95e882700949bc563e96e4c730ee0e77210f58fdb73ded42c158d9eee1b5040634e79558955ab5e78314fe226928eae06b5954d66e0477cac7b45deaf9e075c2586687731a4f7f75a0f897e3854e8fb553dbacac7be493d236aa35f3496afd556882f973618e2946ee42ebc1c99fd95ac7c49a7f17e78a92eee14d10e001c00150752694b7592a99456894cfd51cbb39425db4cd5098795930f8fe14adadd150d275eb5dbaa59db2aad8576a74d05ced55e2969637ba73ce00cabe599f6bbdd0fe1f7c6f46b837b3b82b41f03adf60d43a9c55dd84464ecd0ff7527fb4378092195ba934c9119cfae3071844a3574a4786fe05536babbcd4f23f6d345c8767d90de2ef8670785d55e5e91c1ccc6e047bab7e90a3d67a4f4e43536b78356ee1d83caa5f8c126acbe18e6bb452ba52de505fa6bf47208bfaa5336973ea2a031ed3855ea49d90bc7677d94a49ab196c664529dddb385e7e5645e18dca8fd5d5f0d2c02958f0d71e3ba374869d779115a2a636fbf255325d3b74d79389e00f60ce54d4da0b54416f1454d592338f62b0bcd3e9db38aac778d7166d3cdcd66d95ecf8e565be20f8f151a92df2d9ecb4f234480b780a5a7f0e2aa9c34dde73293df71565b3e91d2367a1755c90466468ce480b3b96eb6c3e3ed897855e0adea6b97e35599600770fef5b25dae2fb7533602f398f84143e28d21b81b5d139ac667680137a9e926918d9412e0f19cacf973caddd7571fc592277c2ed6aeabd446def71390b2ffdadee645c45282707d94a7862efc335e75e624347caa5fed537486e3a8e2744ec8caecf8d96fc707cae3eb566fd91ed663a87d511f51ce57d4553286d43c15867ecb36b34f618ea1cdc6e6e72b6cac3fd29d8ecb5cf2f5cbd76703f2729624c84cb7e95d69c153b1d4e1764e0a43898f9f64b7372dc8eeb9182fe08ca7323d3ce2e7b418d0974bbc76c88349cbdc9cb95d21b2c45db839ceecdf855ea6a675ea735131c33b8053ec1d733ce833cbdbb808396f5153e626c6723df0a7e3a2dd88da30d088fc028241b9cd6ee55b3934ab53ea3e83fd71bb6a9665f239981cd1808c9ed36f6b4b0c6dcfca8c96d71b0911761f0a76d0b96add28f4bb086754bd9f53894054cefa57ede70b86a3ab1939e51b120e6d70c11951573bc3e9fe9250ed99cd90871e146ea1976405e3e147ed5a4b5bafd2561e8ee39426b5bb0f20da527d4a0b4655996e8720e10baaab3cd6a1f2e0f00ae4f95978ebf8b87ab768f633c9c79eeaff4a19d0e9bc0c382cef4f4a2958c6e7b2bdd2d632689bce0e179132d56ff002b0bfa677e24f87f2556eaeb7b7120e46d594baff5f6971a5bac2f706f03217d3eea8681b2501cdfbaabea2d2165bce5c69d9bc8ef85be1cbaa8e1b6dd5608ebbdaea0e7a7b49f94254dde829da4b48cfeaafb7cf0859339c699c199f855e6f8155f3cbb8cc4b72ba71f91a6d9f17ed44add5e43ba54f1b9c5dc0c25d3d86e7716f9a99ae0",
            "d3cf2b5fb1f835414187d586b8b7e539aa1d6eb531b474ed68cf1c059f27c9da70e157fc3ad2e2a6ba32f6025a4775bbcf20b7d03601c71ecaa5e1d597a508aa2d00119eca4b545cfa5939e1a1735cf67aed948a3eb7bb36086468772b17b8d4f5ea1ce249e55ab5d5edd5350e6b5c551c6e73b27e56fc5c7fb6d9f93431acdcc2acde1fc21b7a85c40c87055e847a14fe93a814f7289c78c10bd0e2ba72673c7d5f157628a999f609e93d6e0cf90aaf6abab2aa9207673b40536cb933787e4602edc32799c98fa86f17aedf84688a86b096b9ccf65f0e747ad749abe32e33179395f6b78db46eba685965841276fb2f8f2cb49b659a393eadc785d12a2202e170b9d75418aa257967c12867b4d1e307ba7af2e9e96e720d876e7ba169db3dc676b4349194646bfe99b8da23b34c2a5adf305be92a322ab71a79f772d24ed51759679a0746c04b49c70a64d2791b611370e238cae6cda605d08fe82e7a5c63a91e4a6ed4edf40e094d3b46d0b9f276e053490ec294a2671d9031460e09531451870185155b48dbe22640c03bab4d54acb3595f2b8e0ed4058ade241d62386aaf788f7f2da07d3c6eec31dd6bc71cfcb92a16e95f78d59e60925a1eb7df0e29e3a8bc36218240ecb08f0fe003754bfbf7cad93c15ba79ad6862ce405be53c63865badadf19a79dd1f6c04c3e0123b385255f1e6e4f1ed84cbe3da780b8f3fb76e37c0cd800ee9d69923188d2cb78ca5c0013ca50659101f2bbea4e3415e91ed6bf09c639ae1c29a99f5b378c9e531514e1ed39443f8290e248c222665ea21b44c74bc019520c2fa2c388c81f0b8fa63bf734e122beed1dae95d254372d03dd691af6566fd75a59ab817c0e383f08ebc5ee929f4e82d6edc8c2af54789da6279dd04ad8dafce325456a4bddb2f54cc828ead9c9fa4395cc117244b699b5529ab9796039e50179bac7583cb41c06f070a7af546db6e9e6163b2e2152adad0f90c8ef7ee9f5d33b7693b7c62088b9bc14ec1432574dd57720211b2991fd08b9278e15cad743f875a9cf9c61e47194e5298e95babab104a29c15da7fac67e5475583357ba5f60549dbdbd6947be13156cb649e5a0cfc844d2ca29dcf99c7ba8e6ca046d8fe10d78b90829b6b4f38422b95d5e6b2e2d603919577a43e5eda076242cd74fb1f55706c8ec9195a256cbb20631a7d908a32d2fe0bca8abacfd5ad03391944415220a5773ca8ca526b2b727b65334ec8f10dbc1edc288a27f57a8e3ed94f5eeaba503626940412182027fe32023249cbee3c93869465dab039ad2d39c0513707f4f7cadee83a4af157139af3c8e1003565608e73293c20a0d3771d635cd8ed8e731d9e484ddd410482703ba6e4f16697c39a13252e24a978c340ef95af133e46a8740691d23688aa756cd0cf53100e01c413959bf8a7e3b50dcad86d3620c653c436b5adf7549d2b65d6bfb405eaa6b2a2b658a8999382e38c20dfe11bceb4a6b3c2f3236390090839cf2b764cea6d5f7192673c1d99ca1ff00ca0aa95dbe666f68ef85f4778cff00b3bd2d150dba7b310c7e00938f7f7565d07fb3d69ca9d10e6dc6460a97b0face3d271dca03e51b7ea9badb6b4555be67c45a72005a0557ed09aaaeb686da64a971006d05c503e2278690e8e7ccda0a96d4fab01ac3941690f06f516a9a47d643493358c1bbe9ee80b068df10f53d9aba192e13ba4a671071ecbeacd394362f112cb0d4d55330bcb467217c7fa7fcf53ea9874fdca85f88dfb72e6afb7b49d9a1b269ba534d1ed2580e13db3d30ed15032aae0cf352719f75ac5d34cdb66b4f563898e2067b2c7b5fd92eba4ee94efb7b1c61de3711f0b55d257a8ab2cac6492873f6608257859f3edeaf07c7d4daa34be2752690aa75074834e71d949d4f8b2de999d83271d957f5df86a6e0e92e74dcc83d580b23a6b95c29eeeeb7d4c64069c72b9e6576ed9c736b9ea6f13abeed524461c06557ae7acabfcaf45d2380771dd133c0c85c1c631ca86d4d481f4c2489bc8e785b61775794eb15fa2abf277e8aa1f2e09703dd7d27687c77ad3cc978716b3baf8f6baa2a0dcd8d712dc10be9af0aafad8ac020a9761a5b8c957f230b24a8e2",
            "e6ddd23ae94b2daa696ba2e081dd7cff00ad2ef3ea4d4819238b887eceff00257d517c75b6ae8658848dc169e72be5faab6c435f362808733ad9e16ff0aeb75c7f326ebecbf06285967d114d80038b02ba997a8e2ef9501a469e3a5d194dc8043070a4296e10386dde32af3cbd726b5122d93d92c3b0836b9d265ede5a3dd3ad93a8ccb39c29ec546b25c8f95cabaf86dd4e65246f23809a648da6a733c9818f65599a696e75c4bc91083c2b99243d3c55175b8be7aa27a39c807b2b052d382ed919dad0847bc3c0818ddad1ee11b4ff00951e33fbd54a7a192bd94eddad764fb951753533467746e27ec9c712f279ce5230223ea1954615f5924adcbf20ae53d5b41c39f929ca887ae3d230a02b69a6a390c849c20ce5fdc082e6055c82eae6cc23208e517577532b4b07254156ca29c194f0e091c4f56cbb5a1ed1dd46dddc25b548f3ec13163b8bae998e6e31d9446aab9be91c6dedfed9c23ea34962c3a2adcd1412560f60551ee95c5daa9c473cad2ec107e19a3247b8e1c5b9e563553564dedf37bee5e6fc8cb6eef8cd3ac159be5024380adb15688482d770b2cb7ddcb88e70558e96ef8032ecaf2b2976f433c2651a032e0d919ea2869ebc3410d772aae2f1e9e1c132fba632f2e1c7dd4face70c9ea6679267bf3d4202721b8c90b701c4aacd66a88db016b48dcabf70d7aca080e1c0c87d96f86375eaacf34b9ddaea59148e7cdb481db2b3eb751cfaa6fcd1b8b98c72065aebc6a07b1cd63c44f3dc2d7bc3ed1915a691b56fe6470c94f2c59679cc22cb4f1c765b3c710c021b859d6afba66094e7d95db50d51dae6e7858bebaba3e10f603c151eed3c18f9dab3ebc5575eb5dce794237ea5c7fade5f9e4aec60172f578a7f81c996ea46166588aa37982a5ae1ec57286212000a325a3118de39c25df553d771a6e99d45b616465df1eeada2e84c580793f7587daee723641d239daadf45a99e037aa7185d5c5c8e2e5e26b1e7a2bbd965b64e410e69c657c99e20db2bb49ea991f153b8d317fd58e16e316a21f5c4fe7ec572f14b6fd5944e86ae260908fa8aecc7371dc2c62f0d259750520925958c95c3944db34e58ace1d2bea6324720232e7e10f96aa73e8ea9db49c800a437c2d748cdf5b58e8da3e4a7790e63b566e74b5573bec3351c45f4b1bbd4e038c2e6b69db553c10529ec00700ac72ea0a2d234cfb5d2b5b3b9e36efef855b8e8ff0039d5321dc5e7201f65865936c70228e334d4dd2239212c0c774a95f97e57701c32b1b93a31c7472269776539628ccb3061f75194516e202b3da29e3a7958f1f524552f72b847a76daedee0d2e0b23d435ff8bc72bda770cadf2afc389f5c5a5cf602086f0160bac74a5db45d4490cf0bc400fd585d3c51c5cf90dd332f95b339dd8e15f3f673ab33ebc73b39c959d5b6ae9ea6ca594eecbf1c8560fd9eaeefb56ba026f4e5deeb7ce78cb8afafb1ef0de9d7177c84d8c3980944dc87998db543e92dca1a9d8ea82c6b391eeb8329fe9db865fe5e311730ed194dc4c2339e145eb3d7963d10e6455b511b1ceef928dd337aa3d5747e72dcf6c916339053d0defd017ba8752b77e709368b979966728abcd1b6b5863435b2d3e49b80a2c6f8eb497fa86577002e370d6ae13919f84a467af5d7443783bbf720f515a9b76b6be068e4b7ba368207d5d5341fa3dd663e2c78a6dd17a8e0b6c4418df80e20f65ae1139e5af18678a7a0ea6cf5b24f1d518f9ce372cde9ee176b2ccda98eadf26d3db712b6df16ef965bfd84cf0558356e6e7683eeb0ca3df0d217386f713d8aecc31f1c7793d69fa73c4e9efd4eca2ad716e38e4ab7d3c0de9e6170767e163169a47480ced6f4cb4678574d07ac69ff00146d0564a3bed192a39316fc596efad4f4ae9e7f9c6d548d2e683952fac6ead706c10fa4018c053f046ca3b5b26a601cc78ce42ceb50d5ba4afe39e573e3f6eae49263b0b2e2384b8f747d91f8c3d4791e630c7765254907978c35bd95b9ea51d3eddcef655baead755d498c1f746dcabfa30968ee5465ba1124e2477b9426ad9a72110ed763b2b2d4541919bbe155a1a8f2ce631bc82a72a6a4476d32379384168d4f5e43",
            "4b728bb63ba2d331555a2a992b64391d8a9eadac6d1dbc35a46f3ec9872aaa8d6d56dcf62975b374610d51b6f90f331ee99afaf32bf07d900c564b989f9f755b8aa5d4f52403c7752f55501e3195133361eae0b82022758ea164148e0d761d858f54412dceb7af51297c60e704fb2bc788b493081cf832e1f659ec124bd0da33bf38c2db89972355b178d3268ab41b659a90c6e73769730289b2f8b171d397496ef344e9a694e467d8aa5345e28e2eb1a22f663eadb94e526a0a691db6b2119fb8e16cc9a7d4fed1378bf1db54c7968fa41f65097af143525c2034d43592c0d771869c2ab4b70a47387978998fb231957491b448e0d0e4011a527ac82eeca9bed4ba787702448ecafa62c5fb41693d3d6a8a923a76343460edc0cfeabe52aead6dc9a6263b60f9085a5b589646c1254f0e38c9280fa86e1ac742ea0b9477588d3c3397649185a9dbfc53d21f864309bac396b4348dc17c9b6cf00eeb79a165459eadf2b9e33869ec8b3fb336b180073ea266b8fb0252da74fa23556a4b65cecf300d63df8e0958f58f584d6dbc3a9c3c861776529d194523c1738f0a8af0c82f0379c1caf98d5b5f478c98f91bd52ebaa31088a421c5cdec5627e20dc69a9ef7e7626b5bb9deca7a8e90cd50d90b8edc2a3789d4ce8de1edced0574618ec5964daff0064a28af9696cf905c42e3f4df5039af1968f9556d01a95f4b6f6465dc056fa8d5113a0735b8dc42784d669caf6c589f8834915bafd1323001dcb4cb0cd241a6c3da76fa5651afe5924d42c95f9c673fed5a5592e51cfa7d90b48ced01767c8c3fc472f07fef5c17b90d149d494fb8eeb39b21336b21303bbd79578bc5b258ac524ed047754cf0f580ea0ea4fd83b9caae0c758d1f22cb63ea5d297eadaaa08e932768680ad515aa76534950d77202a150ea4b7dbe99bd07b03dade50176f1c60a0a692998e0e7918e1736795d9ce29a5e6c9ae594f7236bab70cbced0af2f6b682466d39649caf9df4153566b2bf36ea43c31aedcb79b95c18ca48838faa318558dac73c242350dc77c7e5e23c9f842da83ba0239060fca0adf1bebebbac72581494f2b209f0de17462e6b343db1b5bc7ba329a16c8d3bce0288a49ccd21cb80012aa2b259c98e94f23be16ba83431ee6452100a44d246464951819541d9909ca53a09a638c953b3988892adb10c840cf571578313f011edb7622cc8ab174069e72623d8a5b6d38d1974a17d0ca5f1f2dca81ae7b6a617b89e5a14fbee82a3314a39edcaaede699d04523d87d251b2cb1d222c976732e1b738634a4dc5e6f5ada9208bd4c2e19c2868ea1b4f054499c3c2b6784b6b75cae5f8a4e3708ce7252ceff9449b5cf5d5432c767651b4804c7d9614e97356f79f95a378b37cf37766c71bbd2de16712b72e24775e5e7feabd4e0c353690a5aed8feea621ba3703d4aa3248e8464a65d79110e5ca2f16dd5db4bc3af85a38720e6d412762ee1516a352ede46e2986d7d65dcf4e9daec9e129c327a9fc8b0ddf523698751ae273f088d15619758d7896424301ce0a2b4a785f5b7923ce34edefca77505fd9e17cde5e9d983db21698c9f51172d56b360b442c9596f8a36131fb80b48641151d08634e1c0721605e18f888c96a8d7d5bc7e67cad464d654d51b9e256ed7765867e39b970bc9600d4f57b438e561fad2b7af3b9995a5eadbfc2e85c5b20c958b5eeb0d456170c91957c386dd78cd63a46bda580a6193ed9002a560a6f303b28fb8d2f97907b72bb7ea69cf978b0da8ef68561a7a4152dd87b155bb0faa36f2ae76e8dbb73eeb973ba6dc73684aeb54f6acc94cddd940c5771bf6d4e5a55f6080d49d8f6e5bf74dd7681a6af8cbe36facfc29c79b433e2dab74d718d9cc6ec84ba9be5434663763f44257e84bc51bcf403b6205d68ba44363daecae8c7e4b973e01475656d39c9cbb0a16f7ad2b2e6d300dcdcf1c2726b2dca438da794a874954427ad30cab9cfb18f02b94d663249d799c5ceefca39d110d03e14ebe9e36445b80085133e0655fe4daff001e91930f525b0642ec8dc94fd3c25f84fed9df05dae17f5071c1577b65b230d12bfb850b65a1df818ecae54140e919b405ac8c",
            "b3ab5e91d791595e29de06cedcabaea2d19a7fc4dd3f237a71895ed3870ee0ac6ea6c6eeafa49072a66c1aaebf48d6c6c739e612795d1c574e1e4f5916b3f07aefa02a66753c723a9f24f03d9553c3dbb4745aba37d4031bb7e39e3dd7dcf4d5565d7d6b315432376e6e083dd7cf7e2c7ecf735a6bdb76b2b098b7ee3b3d96f9cf1963e57d050d68abd2f4afa73bb7b40c840dff0050d3e8bd3d255d438097612dcfca8df08eadd369b868ab33d488630e550f1c04d7773691ae2236f1c2e3b3ddbb38a76bd63e68d7f7fbdf88d7f9e625ee8d8e3b01ce1697e01f8932e8691b64b93cf4e438f51ecb949a6a0b6d26e8e3697e3e1576efa565aa89f5d082c9987230ab7e69d77e3fedf61b66a0b95232ae92463c386782870f002c43c0bd457796a5b6eaf73dcc07032b71b846d8650d6f6c2cb267275f0cb9eb9d5038f9439792571d1b9cf6bbd82983432e1746592c73d40c0903490be53d674b55ac2e33dcaa4b8b6327057d37abadd2dcb4bd4ba03ea6b0f658ce946d2555b6bad1561adab7e4373dd74e1839f9581dd2dd19a92f64ee76de36e545bdcf64c1ad6e55a7567869a8ed17c90869303dfb8381e004d4b676d1c45d28064c2ea9e3941b2e2da2a6c3c61cfe30a0eae92a2db7186ac87358f7878729cb2e9bacd4f758a2644fe9b5e3d95b7c63b0c361b351421a04a000a6fdaf1adbf406a582e3a24073dae7323ff72a1cf53e62b6777b071557f096f1522cd2425eeda5b80a7e9d87a9213dcb972dc755d973ed8a4e9585ee054a492b628719e505485b1332e405c2bc9761a50cc8ab98d44bb7db28aa51d3c20223d9c7ba94a56076094049c32f62548d454916e70072ab95f55e59e034f0a6adcef3b44477e10939a7e0018e9dfc0eea36e15ef9ee5d369cb329fabb80b7d1ba169c12a36cec33cc667a6a58632218013dca88ba3cc60bc7ba5d6561eb6c0780bb511f9d8006f70101599eae79260d683849a9a69721ee2423276369271bf195cb84e668f118e70808abb508aab73c16ee202c6eeb49534173696b0ed0ecff00b56f56fa674d039b20ce42a0eafb1c8ca87b9ac1b4656bc4c795b7f8236bd2dacac1e4ee11c4ea8d98c719503e24feca9d4a99eaec01d8397001513c01bc9b6ea7e94d2b9a37600cafb4e1ae93ca472c6c0f690395bb17e736a3f0ff0051e93a93155524a00fed34281eb3d8ed9522407e0f0bf49af3a42c3a9e3cdc29632f2393c2c775e7ecc16dbbef96d91b5afc71b501f22c32b08fca28a8c9fa89c39bd95975a782ba9747d43cba99ef89bd88eea931d54b472964f13b737820f0420344d05e3a6a1d0356c6b5824a70705aef85f597875e38da35adb592d46c866f7195f14db2182ff88f0d6e3839527709eaf47c6d6daa7764f7da546c69bb455d01616b88e5671aad81b786be270c67d92ff1a9241e971fe2ab779af9df541c492bc7fc51ef776b1631d6b6821e376154fc468a336dc1702f5156ed4f534b0ed6938c280bcdfea2e350592e76fdd5ce3d165cd6cd0ad2b2ef8c460e08563744f8e66e49c65536c550ea7aae060655e293fa74d1373c9214dc7596d18e5e694af11e998e7472340dc137a36ef242d1148496856ef12749be2a48e669e319547b46ca785cd23d402ebc6fe4c75595ff00376d16fbaa2867d3e68232d1290b3fb3533ed933aa0b877ca87af75436ababbce33db2acfa66c55b7c2dda0963b85af5eb34c33cfb5dbd25f6e17ca9f276fdfbcf190aff00a2bc15adaf7b6aee9b88382772b2e8bf0c6974e165c27687388ce085a6c779674045000de31c2e2cfcba3bcd4f698b1d0e98a514f48d683db8084be5cc4729a7392e794fd3cf232374f2738e543d139b7cbf47c6435cab165965b5e74bd16683918710a3efd1ba8497b95ae9e9db47b23671c2af6bec47421deeb6ebe6d9cf6e95e656cf50dc53672783853762a79a9732ca4927ba1741c713a22f9999f8ca22e97e8edd70e93c6d638e167deba31e3da524a86cc0e060a0db58629b69e11ac114e22921390f19282b9527f4e606fd3ee8b91f5d0b95f24f11dbf0a937a95f4b5277f6cabd49b29a3fab8c2a0eba7010ba46153ddd3c58eced3d252d",
            "ce0cc2475553b563aa6ceee8ccd25aee02e697bb4d4f56d2e90edcf6cad26eda7a8756598ce5cdea46dce554a3978a48f9eaea5cd774587d53760b6cf0d2dbf8068a9e4a81891cc24159332c33546b18a0197471bf1fed5b36b0a96d9f4dc5033d3f97ce3f459f2725d7561861ee98dea5acf395b2b8925c1c70a2606e5dea5d9e532cd23cfb94ec51ee68705c93ef6f530f2682dc60ea370d0a320d2f515cfce486ab1481bb4709caab8797b7bdb08c498e15772cbc336dd0f48086cce6bc9573b1e8cb7d04ac95b1b719cf6591e9cd437786fe22ac0e1139ddcafa2ed344daaa486485dd5dc0671ca8e6cec9a4e1ed134f50295a3cbb401d9543c59f0fe0bfd88d706667033c2bcb693a6ddae8f0529f52d9227d2ced05846395cd872dc6ed5947c936bae9ad331a13b985870ac106afaf88ec2f7ed1d959bc53d04ca295d72a366327276859a437663b10bd987b7baeac719c9eb1995c162acd415957f548ec7ea9a8658a6187b86e5053d697348665002a2a637eec95d18f04c7e9379fddb40b73a3a7765c461456a799931cc4a2e96e923a2c389ca44933e5760f215dc077997a9ed37396b1a1ddd5dadb390e19eca8169262703d95c682a81c72b979316fc796976a691986e029ba3a8e98042a8d2d680072a562b800d1cae1cb1d37edb59bce3663b5e1b850f7386977976c69285173683dd0955716bb392a71b53d7662aba4c196b4287acad2e6969c613d5b5cd20f2a06b6ac1ce0adf0d95f01577724150b54ec9e1195752707951a1dd42576f1c73e799adb92a4add0973820fa782a6acf16e2d5d11cb95dac56884c78e15c6d5f97824284b6538dadf4ab55040d6c7970c2da4f19e75caa68feb1a0021073c1057c05d281b8222a5c492d1d946ccf307a41eeaa65a63d0cd354dd2c9209a8e578881ce32b56d21e20525fe93c8dcc377e304bbdd656daa2e6ec77d2bb4ee6514bd581d877757396b2cb8fdf1af535a194170926a370111e400a95e21b4c92ee0de73c9297a5753d5cb52d8e72ed9f756cd4963a7bd506e88b7a8428bfd767c6bd6fac7c53b250d1b9aa2ef73b6929cc11479738e3856a8f40dca0ac272e2ccf0acf41e1fc3296c954c048f90a7b3d0cb966807849a75b1520af959b64efd968756feb3839228a9a0a1a514d000d1f649744e6772a6d71db2dd86733694dbe52d1809c94909873c0ee14ed526c4c15a62a49217f2c78390b07d7564a9a4bf79fb69e97ab271c2dc636079c1e47c2adeb4d1d2dd685eea63b1d8f65ae3cb632cf876cc2a8dcefd4618f95af936e144d8fc1ebbd65c05456e4c04f62a6ec164b9582e59aa0e7461deeb49b96b6a7b75a7f2434bf6e3016939ab9efc60b6bd25a7b45503aa9e2212019e7e57cebe325eceafbc0869465ac760615eaf979bb6a699cddef6444f6556934fc56f9ba9210e7e7dd57e4db3bc5a2f42db1d69b6b58fee42b2d2d3932979fa72a2e90b9db71c351f515fd1876b072a72f5acf45d7d646d6ec8cf2a20073c92e49818f9cf51e53fb8670148be1c85a491f08fa8ac6d3c4c6b472506c708864a7e37472905f8c048b66e50e9c65e792ac7a7de69e9cb4f3c2afd57e648d6c4723eca62dd5cca66089fcb8a06d157b98d4d6745bdf2a628d8ca1a201c30f2107e47374152e1e9ee9772ac64d316076d0169d4bb1c7dbdf21f31bbd2395d8aafcc662a7192def850efbc563aa23a2a663a5121dbc2d1a9744b74a584dd6b480f99b9c14ac2ed59b5de9e59661cf20f290c69680d7774e1ad75657ca5a3d19e12e62d925686f7534e5d8ba569647c7ba06f96af3548f76017614cd242434170e309ba09056dc1d4aefa7b2be3cb459e3b608eb9d4696d4f14b192c01e09c7c657de1e19ea18b52690a57b5db9fb0657c7de36e8992d32b2e0c6619ee40f65aefec9bac7cfd29b5caff0054436e095bcbe6d859a7d0c230d73b2390b91cf5313f8c16a7aa462571fba47b728b7493770b65b2fb118ee10472646390b25d6dfb35d87513e49a8218a379e42d70b47b04a6cb3463d0e0028fc87a7c4faabc00d45a3269a7a50f7b1b9230abba234adeb50d6cb156412fa4e3d617def33e92b1861ae8992077",
            "1cb546d3e93b05ba574d4b4b1b1cf39386a2d0f86e9ee66070dc99afb8c72bc1002e55c11b99e82828e93272e2b8662f57b272db342f6e1e0266b6963924cc6d084a68cb5e034a9aa0a70f97f30e02aea253b6fb435d0ee006e01114754ea0ab6bddc0614443590d317343b855abcde18fa9e8c44ee79c70a72c0fb45a754ead8eeb4221dd9c0c2a558e9a3adb9743a83d4522e561bc41486a5913cc479ce16cbe0078456fd5542eb9d5cdb668fdbeeb6e2c5cdcbc8c7f57d9996fa88e26bf249ecb6af0a2df4b4b6164d2306ec6738599f8d16496cfafe3b6479387e00fdeb68d29a42ef1e958a58617e3683d96f94f1c9dd262e66798c4f71118ec9f86486193878c2129f4ddd278da2785ccfbe14ac1a4e5006f2e5cb971eeabb3d72bbc30dbdf1b5dc90a57c30b543287d648f19072867e8375680012558ecda766b2d218199194f1c0ae5e2cc5d4e6712194607dd53f58554572985346f0402a762b2544b4c4179dc5421d38e82a9ce95c772d329e0c2fa7ecd0c14b46c8e370de3ba0758597f15a6eb4030f60cf099843edb5e4cae3b1c7032ac81ed6420f0e6cab932fb77e17c56f41d6c8d63e9aa8fa9bc0ca94be54ba8207cae1cfb287bec674fce2b80db1f72bb1dea1d634a5b4e5ae0d1ce12dae63daa364d4f25552bb04ee0a2aae4a8bbd2be3d849012ea69194156623c64f647d0d4b695ce2580b48c28aeae3c74c62a2ef516bbe1a57020072d22db7daea5b43c87b835edf9558d676412dcdb5ac8f00bb2a50d618edf0d3ed1ea0025db4339afb4df8756b6d7d74b5f30c969ce4a6bc50bc799fc88cf0de3853da5e2fc22cf2c98c17b4acd351d5baa6ae573ce792b3b7759e387bb568b48041f746531fcbda86710e91134edc3beca2f8e8c44c50079f525436cf3756cc0cb1a794fd335b3bb682a6e8a9d94a474fd44f759e55a59b1d74d1f6cadb0ba6823632a58de3039caa4693f14aaf445c1f45726931eec02ef8579a9a9929698cbb8e00ecab15fa3edbaee091c0b23a9038c774b1d5beb3b8e9afe9ed6762d4f03676d4461c476ca97a8b55256c65d4cf6b8819e0af912eb65bff0087d3911cb2f481e319ecac7a2fc6cb8d14cd8ea1ce2d3c1caabc1e6e7b1177b683aeae6607ba8266e4138e56597ed20c863f370b465fcf016a12d6daf55b4554f231af233dd2a3b451d64661ded735bdb95a71e3712cb5584c748e8091235372c3b8f0de168fa974b36290989a31f655e367d8396aea9cba63970ed5d8a0e3b611f49481cee422bf0ef5e0046414663f645cf6530ebe1b6d3f4c02148d1cc59849e964265f2089d85cf9fadf1f16082b718e51ecafe3baac4539e0a23cd903bae7b86db4c93de7893dd313d763392a17cf907ba667af27dd29c42e63aa6b33eea2eaa72e079434b5a4fba164a927dd6f8f1b2cb3727797029ba604774d3a605f84430765d18e3a616ece005ce002b569aa2de464282b7d389640af365a5e831ae016d1954f5a191c7286c9c0566969e3e883190aa72bb0039a70e44525d260cdae2b58c32be8aad3b1dc28aa8393b9c709da9b88dd97ae53d0545ea40c81a483f64f4cfb2327ab95de88232efb80a4acb61aaa978966c81df055eecda3e8add481f598ea7c146c56f2f38a78ff002c7b8095f0e59502c85b48c0d8d9eaf95214374a8a5f548f38f84554b296941133807fc28995c2a5fb62196acf3c9d7c58ac70eada777a5cd19f9474377a79ff00f581aaa22d1b5bbdc7082a88a48cfe5c8567deb7fc53f4bf97439ea32507f7a4baa03bdd50a2b955d38fa9ce4e7e3f523ea0425b2fc35709a7637b940cb7089808c855efc68c9c39d848334733865e96da6386938dbcc74cedc5c0848a9d60c238c607b285aaa685f112c932ec7ca8c822898f3e61db5bf755bad3a4fb1178d466b418e3a4ce7fb5850725141044ea9ad9435bdf692957ed574b6c618a95ad91dd956c525cf579c49be28bfdcaa31ce480eeb7dcd4086df0ee0e38cb42ed658666d20aba924123382ae7a7f4f596d31964b232499833cfca80d4d5d5374ae6d253c64420e381c61693273658ca87b3523eb83835b80df75eac8994f218dd8ca9da90dd396d1b",
            "1a0c8e6f2aa0d9a4ae91f2cb907390ae64c729afa11d42d3b5a9c1b621b9c794299361cf28db5daea6f13b58d6bb6938539648e96867d64b3c8190b0bbf72bf695d1525fe85ef765ae014953e8386c742caa99a0b9c3dc2b2e9aa975a682799eddb1ed3853d9b4e266357688ac3512c73c9ea078ca8fa3ea54dd98403b3295aa6b997fbbcaf8e5236bbb052964a27ba16be16973dbf015cdd679cd09d493b28695ae6f0ec280b5d9ee7a91cde8c4fda4f7015fec5a3e4d4b54d8ae20b1b9f75ad5874a5b74cc0d86089af23df0b7fd39edd2a3e1e78694769a7f3b728daf918370dc3b2a2f8cbaedd73ae6da28dd889876e02d5fc41d44cb45a65e9bc31c5a785f36d9e19b505fa5a9906e01c4e54d13fa95a4a1650dbdaf907adc1054909f30643c8ca92be3f74b1d330e31c2e4507979591bc63728698a518e12537031c28fa28fa57063dbc12e5352411d3d1e73c90a06db319ae581ec5189d5c3c4cd28cd5ba22410b37cac8bd87d97cfde03ea37e8ed7de52a5c63deee99078f50385f59f8733c37065550d4e1c1ed2d00af957c7bd212e80f10db5f4ed2c8a5904ad207b83fc974617f4e7cdf733656d5d04350ded200eca6c2adf855a819a9746503c3817b626e79fb2b2e30e70f829d4c797b2bcbc7b2ce987936eefbae6d70193d938e8e33c83ca4ee73b82380925f9f7d6c700e53ad9001ca77ca37d8299b3e939ee6461a70b398bd0ec8489ee0e06304a900eaad830d392ad0dd1c6dd832351b35ba9a1a78df819caaea5dd17a6f40deafcf0e8a3796b96a7a43f67ba792b619eeadc10413956ff0be48692db1bdb1b49c2bbcb7096a2a581ad007d93e9b4dcd9ff8c9a46dba7343541a081b9630fb72a0bf648a935168ae7c8e208278fdeb41f18e944be1ed748fe488cac87f65cb9f94b3dcddbb00172d71c755cf6db3d523c49ac378f1ea186519689b1fed5f62d9591d0d8a9e2647e96c638f95f15cc1f7af1fa270cb875c1ff6afb6248fcbdbe2847fc403fd8af4c8d931553037a4d1fb934fb7b1c386a4c398da0a29926544c0c16c9298e636a50a8aa90ee733b23f682bb81b70308eb05405def95b4711742d2481eca8b41ac2beb6f5d1a96b9a37616a32d2538cba700b540dc6c56b123aaa0600e1ce40539f91a714dd07ad290bed4da883ea68cf0a2743df1f767f96a9383176ca4dc7518983a84c83e395588e9abad5546aa99dc139e170677d7a7c7c7b8d2358514759a6aa995381861da57ccfa33c429f496b07db1cfcd33e4c127f55b74dace296c92d35c640242d2002be54d693474baa1d3c6700bf208fd5131d893a4f5f4deadaba59218ee90bdbd32ddc4a074dde20bfb4c713c123e163b55aee7acd382df1bc976dc223c1bd5c2c97631d7b88693fda47e3698f2c8d3f52e0bcd38eec5096ea865cae30530e4b5c01c24f8a1abe86801aaa591a4ca3d92fc1ab34d7790dd643b983d4b2cb03cb9264bceae9df66b5c31b380e6ac9ee3526591ce3dcabb7895a963ac9bcac47062e16715131739617cabc27f92e36873b251b1b38404079ca9383070a32ad711d6e85b1bb23b95354c363b23ba8aa3182a561382163956d0bb9b9cfa52cf954ca1bb3ac1780fde71bbb2bb55b83983f459e6ac80365ea00723e11c7edd233f1b553515935e5ac36a84424dbeeb1cf10bc21acb448f96d6ccc60e7d2145d835c555a2a035b23800568f4fe27c55f4a22a9daec8c1caebc71b185cb6c222bbdd2c92746a4c8dda70a5e9fc43afa703617e16b2fd2d61d4e0caee9879e556eebe17c1097740b76fb6169da7f1171a86a0d766bb02abfdaa5bcfd054c7e973412aab5ba12b2090961207d9474d67ba518f4b9c89254eec5d8d3c2e1b98412b8ca57bb9c0c2a2475978a7761c5d84632fb722dd987653ea73259a69d903f6b88487d28a96f51841c2a7d5c576a87753d585336496ba288b6527f7a8b1728fdf83b47b243e5715e1f513eebce0a45a6ba87dd3334c729523b08499e49578cdd4e57c7249134497243dc5798ec95b4c585c8b6443782512c64af95a183d2993f4e47752d6688b99970e72996d3765b7e5ed2472ad2c73a1606b41ca8eb1c278711c2b1d1",
            "4113a6cc98015e28ca98dae31879f6eea22f5aa292863e946e1d5ec8ed557da6a185d142412463859ffe1a6be47d6484f1cf2b691c795f56bd3115c2f77060981e8b8add6db6aa1d3f6f648c00c98587f87b7a91f748e9f1e86380cad8eba4335540c0efcb38ca607c34925f497bc96b014fd6dc61b1d29822c39d842d75f22b4c422808e47b2aeb8cf76a8ea1271959e55d5c5c3bf4cbe09aef566594b8372a6a9edd1d2b5a19c94452c11d34403b194e1a885a7b2cacdbbbfce308969df2c7d9425440637953b2543e46ed8c28e92cd5f54fcb41c23a26f348897e18771030b85d0483b29ca7d1f5d3481b203b54c52e888a3e2509ce3acefcbc62892d3407b6525b6c7bfe8ddcad20e94b7c4325bca721b6dba03cb070abf133bf2b6cca5b0dcd8ddd135c428aaab2dd27c8958e685b448f81986b18dda9b7c5472c7eb8db929ce344f9358dd068ea10eea561248e79446a4bb51da2da60b6b075318e16a474cd056b4e1a39f8559bff0086d0e1d2c4d24a7d0b2e7958450bee9517564d23a401eee42d5aba1b3daac2da92586a4b73cf7ca09d4145a6fa8fb835a3fe2e5506f725c352d53fc8b9fe5da7dbb613ea9fc81ea6e1597bad760130b4a62ba17b808699aeeb1e30148d8eb20b6bc51ccdcc8782b48d3d66b2b36d45435a653c8ca566a0c6eeab1a3b43bea6984b75696fbf2aeb64d3f4d4758d6d334100a32a6ae276238c00c1f082b86b4b5698a5323f0241eea34de59169be31868879c2d6b2319540b85fa6be9fc32d382c1e9710a8ba97c5baabf39f0c0f3d33c70a3746deebad15e5d1125d21f7578e0cb939a4fa582e9a5ff05ae644e04cd31e70b66f0f743c74d46c9ea59cb8640281d29a49fa8a58ae5726ee2dc386568c5c207b228462360c70ba70c3fae2cb92d52ae33791beb638dbb180e3857263c47426a4bf80dcf2abfaaad666fe9100f50e78503a9f58fe0ba5e48e57e24d98454ed9af8c9acdd555628e9df925d8c05ed1b6dfc32cc6ae46e1ef6e795995a27a8d5fab8b8e5ec127fbd6cba8e48ed3648e9db80e0dc61456b154a5cd65ddcf7f203b847dcdbbae108c63184c69d84cd3f508ee8db847ff00a4e3fd545691215f10f2239e70ab96001b757077cab25c8114e00f8559a0fcbafcfbe5282b4ed28e141738e469c07386531fb49682a7d59a58dc9b1e66a766e0e099b6cc71139bdc61696ea765eb475541380f0e85e39f90385be1fc73e7f6c13f64bd64f78aab2d6c9b4c3e8682be8ea86b9b2e40f4b8e42f86f415c2a34778b93519718e396a0803f7afb9a6937d153c839dcd69ff0062d3f49843f8ecba305bcae37d6cca4b324e0a8b0c810b43b20a514a230570acc9f0cdaad6fabaa6b48c85ab58adecb55207968ce15734e589d1c9d478c6159a7abd90f4f1d9548eab9cda1afd72351216b47ba89ac79752c633ee8dac2d2e271ca89ad2ec37d86556916b67f0eea58cb5c61df0ae91d6b44cdda70b27d1572e95235b9ec15a597c02457345ead5e2538dc3c3eaf667ff00567fb97ce9e0e5c8586cf738c9c12e72d97536a1ebe91ac833c9615f35daef22db495d1138739c55e9356bf0c2845cfc5a8eb48dd89339fdebec6aff00a9adfb2f923c0701ba9595d276dd9c95f5255dfa9a495a1ae18c7ca19d85d49db18c774cc7311dd313dc6223394cb6ad8fec525e33fa966ce7090fa823dd04cab0d1f29d87354fc81c28bb3d1ef30c95a44cf0d68ee4a81d45abad36ca5921648c7bf18e0aabf8a9a8a5a1a375250b88988c70565163b15eeb243597192431939e4fb2e5e5e491d1c5c76d476aad4f71fc65f3d33640c2ee15834f788eea4a51f8830bb1f2a42e31dae583a4d89ae91bdf855d928e92a5e207c5b01e395e7de49d9eb618eb155bc41d63517ebac66d85d1c40f384dd6e809aff67fc49b203231b93f2a76f7a2a2a387a94d825df0abf4da8ee36171a3937745dc15d58658d72f24b556b7c2eb5970a8ce5a71ca26e773a56d3f5295c1b37d935a9abdb552930b7eaef855c65a6a647754b886f7c2ea92570e5958f56de6e172c36aa47b98ced92b66f037c5b82c50c96da96f0e18195921a1ea465a0738eeae7e16e836",
            "5f6e2dd870e054e784b3e97c79dfdaf9ab6a62aeae7d5c27024395058de47bab66b8d135b648231131cf03e15429e6742ee9cedd8efbaf3b9b1b2bbf0cb70546c20a90a669e1311b1a5a0b5c1c8ea4693ddb85cd6574e091a6186828c6b90b0e1a896bdbf2b1ad252a5797370a06f54d1be276f6e4e15898d6bd724b6475030fc29c32d65b4724dcd315bac1d2a871630819421a895832d2e042d6ee9a469a461700dcaa65d34b9889d83f82efc792561d748bb66aeaeb7e1ac7bbf8a9c8f5fd6bb1d4792155e7b5c909fa09e534291e7d8aab8ca9b9d5cddac0cede5c3250b25dc4a72e20aacb68e469e328da6a579fa9561244f6da49f5f4ce3873414ed3414f2b83c31220b6b0804808d8e36c230029cb2f4e63fb13218043b5ad1951e5b8271c04f7506ee531512e1c36853bdab46c0209497bb0138f700d086964ca7226d3133b298772394e3bd49a7fa56b8e2cf2a6240b918395c91c49fa4a769e32eee30b5918da7e066e780ac94108606b437ba86a689ad7824856cb316ef680cde958254fdb23020003794bbe99a8ade648c10ec236821959307ba0219dfb267575ea1752f41b18cf65a60cb3acf29c4d70a82ea9248cfba2eae37474b208dc1ad012a395ac66ee1a5455c9f57591c90d3871dc31c2e8f1844e78695b01b916e4176eeeb65abae1146cc3c172c47c3bd2f5968ead4ce1db89c8cabdd31aca8983a473b6b4f1959e4d71c62cedaa6ccf1d6e4a98a670118e937f828bb55b85439ae7156eb7c10d36039a1cb2b2ba273f59a47c3455554f19c80a5e0b3b2360de3251cf923734749bb7f44ed282ee1c72ab0c7d619735b41c149146fe5aa6a9ba4c6f0d091e50139c2574f62de60e6cf2b44751c47a700a4ee7ff0068af3786e5747abbad26310496b64e0842cf6c129cb5165b8ecbc1ce1eeaa630f77f4159471b1bb5c325335142d6b09038461c972e559dd096858d9e9ee80a09442fe484fdd6ff004d69a7334e03da4701459a790484ee287a8b47e26f11ceecb07b148e4db39d63a4ae3afa57545187321ce7010164b17f92d11a39da37bb8c95b3d3d5c16d8051c1186e38ce157b5558d95d1f99601b9bc94973c63f76b253d0dc9b592373b8e55969e315f4cc9a0380d1ec82bab3cd074520c967088b0b5f053b999e14df5a6347db9e5d316c873ecaabe2be9cebdbccccc8185646c9d29770f94bd5b04973b139ace486a3182e4f9eadd0b295cd6725d9e5592aee11db5f4f346338c138510ca6e85c6485fdda4a319009592f546401c2db1c639f3dd7d4fe116a58aff626b18465ad0ada0161783df2be7cf02351fe1d5c68cb880e7600cafa2e68c7a1c07d5cada20355be2a7a29249861b8ee57ccde315e5f729dd4b46f2e04e30d5b378b1aad96ab1be9a276262318588e98d3d53769ff0010ad04b0bb3ea58e54e0cf07b461b7b1f5d50cc3beae52b585d4d75c9f034fa5a70af72d4436db6ba3840682dc70b329c09ae523cf249516b6c62c7a5e1c31b94edd99b2e0c3f74ee9d88b769f65dbec0e74ed91bd81515a6c70a6f390600e76aa8c919a6bb6c771cad074bc02a5b8efc2a76b0a1751de378e0654d4ee2d56b2190b5ff65a368bacf35432d33fb3810b2db1cfd7a668255f74a553692a6260fed15ae159651f30f8f5657690f13696e310d8d3287123f55f5978777e8b54697a4983b71646d04fee588fed77a7baf471dc98de5801c846fec9bac455d925b74efcbd9c0c9f85bc66df5876b8b7eeba406bb2b8e8cc6727df95e272958a78f3cae14ac642e61664f9a2baba2a18896001728248ebe8df2923202ac4b592577a064e5485be19e088c433872cbf348db1f8f95c91f575ac6d61613c28bbc5cd99d91f2a4ef3619c30ced073dd56db41239e4c99cfdd2fcfbf1d97874b9e86b93a5f413d95adf566297055134596d357ed71c0256815b4c0b4483b15a6159678e9cb9cae9acb301eed2be6ebfd4795b8cb0e7197f65f4cc50092daf69f70be63f1029fa3aadf18f770fef5d38d72e55b0f850e34f4ad907071dd69adbc4dd469de4fef54af0f6d063b146fc1fa55c28ad6e91bbb04a33abc224c5f24da0125151df1cc039eea3996c7",
            "17018453ed8e633383c2ce5d2acf5334b790e2038f74bbf6b382c1697ccc702fc7ca81a7a396a251b3d957f55511aaa96d14afe1dc1195972f3758d70e2da129f504daa2e2eab9985d1872b24f7b82783c8c4c0c38c2453d829acb6ed91005ce1eca1df03a0799bfb4bc4e7e5ed5e971716a02aaa192d351d771dcd714456504772a76cd4f86c9f64509d972674e5fd394338bed392cc91ec173e3375d1dbac47432c9487a558490381941ddecf6eb9d338c65a64c70a7e92c755aaa501b1b9a3e70ad16ff00094d362499eec7c2eee2c2c71f2f23e63be5aee169a87165339f167bed5166ed10e1efd8ff00f8abecc93c3db5d6d23a99f135ce2319216597afd9aa9e6ba3ea23710d27380bd2e3f1c1965b6290d5d1f40b8ca0388576f076eb3525e331389693c70ada3f66596695bb4bb62d4b4578216bd290b26a87343c0f75b7646d31254c772a3632a610fc8ee42a2eabf0d195ed754528daeef8016a533ecf08e9751a08ec9311a7ce5877b173f261daedb61cb678f9b4da2e565a82c96271603dc852b04c24038c15b25fed349718cb5908ddfa2a99d03202e7b1a7ecb9b3e174e3cea7b8b5adfab94d899a0fd4a5eaf445d4ceedb13f67e886ff0021aee4ff0054ff00e0b973e0ade73c0adb8322e4b97a5bc31e7d2f5da9d0b77c7f54ff00e0a1eab45ea189df91048e1fa2c7ff001eecff00363a48cb732e6e37941ba4131e465032e9dd4d0379a593ff00a530ca3d4111c3a9a4fe0b49c3617e5c46cf6f8a4613d3e7f450efb39de48671fa23c8bcb7eaa77ff048755d7818742e1fb95f5b076c6a30dbcb4fd294da72decd453eae61f5b1c3f72479e89a7d791fb93f4f58d76369039497839e1224b8537b3ca69d73a668faca7d6d1bc614f6b93473ee125f7389df49291e6cbc80c0e27f4553045ce3a43cf709b7b5a3ea384f9a2bb4c074a9de73db844d2e87d4b7170fe8b2007ecae62cae710ee9699a7d528084a8aea50ec3660568945e04ddabda1d3b1edcab0db3f664ea16be7791f395ae18facb2ce6989c95e18dcc6377e812a86b6b2ae50c6c0efe0be9ab6fece96981804cf071f2a562f066cd6d76f89ad247d96ba61de561563d0d71ba398e746e6b0e39c2d4b4de8ba0b3163eaa56923be55f20b6456fa730c500ed8ce157aeda6ea6b03b63de33f08d0da6dadb1d5c4208cc60e31951b59e17d256e658dcd7e79c2a3d7d92f76871929dd238846e9fd7776b54a1b700f6b01f742766aefe14ca243b1a40fb050d2e999ac5eaf2c64c7fd15b45ab56dbaf313769697108caab6d355309744d2d5511585c17995ef0c7d398c0fb29ba2aba695ed6921b95a2bb435a6bb39dac7150d76f0c840c3252389239184c81d2e1920e8bf70565a02e2d1bc2a8d2db2e56a3eb638e14ed05d5d261930d9841ac2e708c659ea4f524a4bb2e184dd0f977b721c1c52a625aee060272954ab6adad680b8faa61eca28bc91dd71ae713dd5f64754cc520704e051504ee6bb07b235b503384e645a12ee021e49b695d7cc30829a4ce53ec3a89154df748967691dd463e5702926571f7536ab47e576e3c24f27b3b099dc570bcb545508696bced23d43dd29f18960923cf7085de59eaf94e433e1c33ee943669a8e80d0d53f8c6e29bb7b36c2ac5aea977bdb200a0a80662c7c04ce1b963c0ca97b71654d24913803e9413a2dc30956da8349505a7b12890562dabedceb66a0965236b4b8e3843533c4919ff00a4b41f16accd34edab6b71bb9cacee9c74e16616b19549e92af75a353d39ced05e17d7f49718e5b2c35ee236b5993cfd97c6648f32cabec6320ad874c78815379b09b5447271b785a4457b56d3c9abb501319dd035dca9b8add1d1d1368a16608f809eb0db9b69a371a81f9cee794503b4be778e02e6bf6ac54ad6353f87d108c1f52a652e5f231e7bb94d6abaaf3f5ee8c1cb415194f06d9a268f949d18aeb66674a1048ee97731f90e384fd347b2963fd172ae3ea523908cd29a17d44850fe24d274e7df8535a15bd279cfca2fc42b70aaa5ded19e12acbf6a5e999731302bd5b9dd1aca7767dc2cf34d131d4f49dc60abed33f74f191d9a5562d37e04fda1e8c5d3",
            "4891b73e85f39fecf37f3a7f5b7917bb6b5f26319fbafa87c448ff0011d2529c676b0af8b2d550fb3eba356d3b4472ff00bd6f8b1bf6fd13ab7f55b0bd9c870ca431b90a1bc3fbb0bf696a7ab710ec3719fdca618f05990b61b2885e5e1f2bcb2ea6f94ac567265cb82b4b2df1b00380a369ab23a7ec0651acb8078eebc0cf92be830c6099e89b534ee66d1d967b78a3f2b56e6edc057b35ae68f4950fa8a085f4866c7e6258677b2b3c6551a1ac3455f16382e705b3d2513e7b3c533b90e6e56295ec196c83ea69c85aef85b7ff00c4a8cd256b861a30dcaf538f279fcd8a5a8a889a670c1ecbe63f11a95c7c436c38faa46e3f8afb1e8a82186290b80c1ce17cc9e2259daef1429a4c7a7a83fbd76635e7e51bce8eb07474cc076e32c07fd8a7add46d6458202f5b2b62a6d3d046dc6046020e2ba86c790535e2957d235a4100272785a60c602867def78c34a627bd3c467d5d94651745baba2b440f99f8e0158d6aad6e6aef625873b5aee70adb76aca9bbcde563276bb82a2ae9a328adf44e0f6e6778cae3e4c2e4ede0b12f6bd454b71b70739e3a98ec9c6c6dad6ed66093ecb328e9eb6d3239d9708c1eca6ac3abfa35403dcbcee4f8f5db3922c9536f9681c5efc80a5349db3fca7a82cc65adef94236e8cbe38332082ad1676b74fc61d4b80e7774f8b8bdf587372f8b9daed14761606c6d69785212cefa86e3186aaf515c7cd02e91dea2a422ae2d1b73c2f471c34f3b3cf62c42d67a9a7d491535f0c711dc3d61055753247197b1415c2b1ce85cfddcab67b1172f10ff0d698a3682e0ab753aa6f9a824d9009034fc289828dd73b9fac9232b4cb35aa9a8218cc6c1bb84ad520ed1a56ae6025af7bc1fb95668281b4d1ec61ce11f51d699ad000c7d92440f0de55e37c4dc82c5471b5fb9e9f7b9a386346170c6e2795e236f1855a1dce0a966c0d31373fa2f09e31ff00aa6ff04c1c24e79537083bd3b2cf1b987f25bfc13f6b10381dd030fee4d430b24e0a92a4a664613c38b1d95cf2d16fb6d1d40c3a9e3fe0839b4adb6424f423fe0a45dc0e179a73dd69971444cf2fbdab355a42db923a2cc7e8807e84b2c99cb1b92adf511b482a31d4a0389195865c51a4e5c956a8f0c6c936490d0a3a4f072c533bb857f8284bcf2bb5744628c968e547e28b9cf59955782367cfa08c214f81d6a2792b446be404ee0577aaecf214de387f9aa83078296661f56149c1e10d821c3c6dc856de5dec90627673ce13e85796a223d256fa403a7130ededc229b3494031153338fb23c8f85ce9eeee15752fc88b9b54dc63186d363f409a66b5b8b061f13829b6d2c0e3eb01226b651c9ec1568bb5a8b87583e578131737f7a98a6bdd2cedfac93faa8ca8d3b4ef196f7413acefa63e8251a2ecb31a96bcfa3057baad6b705a32ab2c96ae078ef80a4e1adea904f7416c7863243f991b4b7ee145deb4adbef5198dad6b5df6526d93a8dc0496c4e89db9bdd036ce24d2574d3b53d4a52f3183956ab1ea4936886af20f639564754759bb2568214754d9291e7a8c0039303ff2a402485e73faa2e9aba48ce1e32d55b0da8a4780c276a92a6ac130111e1e5069991f495430f6346547cfa7a8ea1c4c6402530f63a8ddf98490bd56fa8753ba4a52770080efe0557484184e4223a150c8f332ceee1aeef56daa313f2003eea52d3e24325c36b8e7280b53678b2438f64e47231e70c4132f36bb8b4741ed04a70d1ca5bbe0907ee4b63425cd919264f64b1290a2bccd5d2bf35192c0bacbf533a5db8c265a4b1a8e130f973ee91248d999ba270c21f25bf51ca63471cf091d5194cc950d69e534670eec9ec0d328c269f3071c217aa7dca49a863392a6816f9c1686a5c4edc5b82a3fccb0e4a4c354f1551b41f4928801eb59c3230df7c281b4b334ee7147f8ad3792a26ccccf6ca0fc3ab9515d2cf2f5a560900f72af462a38b2370ec86aca7d9b6403dd48474ef0f203c16653cd6452131bda484f4555bd77466eda7dad8c65cc1cac5a0cb66753bbbb0e0adf2b237321a86edcb3070b08ad6f4ef950470371551148958e7031b7dd69fe1752d25b1a2695cddddf0567349246fae8d9dc13ca96adbd",
            "badf78a7a6a7716b1c465521b5d5d60b95537a7f48f85cd4956da0b49ec09097a4a9a39691b33f925b9caacebbab7cf379769f482b0bf6ac5548e27544cf9ddc82729ea5843aa9bf62886c260a21c617ac6d12d412ef949d18ad31734cdfb04a68df4ce0bc006c786f64885e43f6fb142334b69b6f4871f2ac35d0f9ea67b1dce02aed13fa4e1b7b297b7d5bcce5af3e8210c2b3820515edf18e3d4af16d8c983abf6505acadb1c1562a611c9394659eb9f2523580fb729c692ed3f56ff3ba5eb63773e82be32d5749f87dd6a5e060f50ff7afb3696232dbe589bd9c0e57cb3e2e5b19457f2c0dc35cee56b8d6793e80fd9cb5579cd34cb6b9c0bb1c2d7fa46070615f23f807a9bf0ed570518711192385f5e4f2099ec7b4fa76e5692947171771c2f632acf6f95df1ee213f1bb60eea3df57b7dd36ead3f2be6ee1b7d259244cf99681dd3559332a202cca847d69f94dc75a438e5c8c71d567b465c23024737e13ba6afd259ee718dc4349084af9374e5d9eea2ae6fe9b448c3ea032bb78f261cb36fa9edf7365d2cd1cf11ce1b9385f37f8817767f97b10c8dc1f8ff006ad03c29d62dfc0a682a1fea0d2064ac3f5e4934daf44c33b7a8307f7aefe3bb79dc98e9f4cdaeae4a9b3458271b02f444b63c38a07484e25b1c59e70c09c9a521c402b544a7249ba39395195559202407677760955136d692e2bba72d13dfab812d223614349137a62d98699e46fabb8ca3ee568f360cf2b721aacd0dba1822646c03d3c14cdc630e8fa6d180a6c8db0f19a5dac0db88736260ed8e16637dd395769ab739ad700395f41d1d2329e720807284d43a520bab5ee6b0648f8595e395b76ac47435f668ee3d2949ef8e56c0ea92ea76bb3dc2a2d2e8afc3aeae9037b1cab5b2671608dc3002e7fc7aacb2bb4adbeb9f1b8649528fb91033955f6b806e5a729e6c85f09395a6d858b952ca2b6848072542dde8e58617120e137a76ee217889eef756dbad3475d6c2e8c0276a9fb3eaa2e898d95574735d82415a48a50c780070b2ed2dbedda81e0f00b96c1133a91364f95731da72ba3d1c4d118c85e746d212c7d385c2385bcc7c61b0dd00e761726a201aba660d930892edcdca560b50a29dc64231c2f494c5beca55b106bb71098aa734059554a129486bb0549091a30a1fa9b5fc273cc3b7009e197aaa9807705e1c24531dcc4f6395d1bda366246171487c4004490125dc2ce8d91065bec973337b794d3aa58ce125d58d77014ef441a5a20ec901013c1d32a51d54183951f533090aceb48663763ba7cbda5a8603296384079a304af3e40024977290e05e980b5758636e4226db2f5e3dceee99928c4830427a9e9fa430de02291f7ce18ec0090e9049c1097d204f2b86368ec9037e5a37b79c21df4423e5a8a2d77b15d603fda4007139ec3ee8c6cdc72bcfd98ec90d1b8f64029feae426c48e070964ede179bb4f285474b44839083aca774311961fac764693c7092d1876e7f2df841a36dd7d0f7746b47abb64a93df8e617ee69f85137eb436b2232520daf1cf0ab76dd495161aae857025b9c64a026f58e9a8eba90cf10fccc64acc85098a47452e43815b4dbea61bcc4646c80b5c3b2a5eadd3ae8a574b10c7be5022a749157d33b30bdd8f652f49ac2e76b95ad9cb8b72bb6723a8d63f9c29eaab053dc0370c19482d1a7efd47a8298472b417909559a2facfdd071efc28bd2963f2158034f19575adaa7d10ddbb0004e26dfe29770b35cad311702e700a1a3d56fa393654c4efde15fa1d494754f30d41691f74d5cf4f59eeb1ee8dacddf64c6d568afb4b5d870c35122482419648d51f71d12f8b3e5e4c7e8aa95f4977b43cb86f73424b5d25711d8929bce47a952e975c4909114f11047192a4d9a9e2a86e770096c275ee18f4a5d2cbfd21870782a2696fb4e73b9c0a7e82f10492bb18384e11df134c55da79ecc65fb4e17cb34ba86f9a7ae92c714cf6c65ddb2be97be558ad81d13bb1057ce9e20509b75ef78fa495a625575b278b53d16c157b9c3df2b46d37e26d9aece6b5c5ad71f95f3fc72d2d5530fcbf5610420aaa67efa694c7f182af49dbeb474b6faf8a4e9d4c6770ec0af9f",
            "bc4eb7bec75f24d11c8713d955e8b526a0b1cc267d5492333db289d47abdd7ea502704bb1ee92527a2278aa76cd3f71cf284d515265d470ba9cf0d70ec87d2a4ba8e4730edc22b4dd2fe25a85ac78dfeb4157d29a14386936cf270e0cff72a1d7549aebdb984e4072d0b736d1a59b08f4e58b3db55375ae2fa8efea5953c4fdf2314d4a00f842e998f7b9ce29dd512e46d4ee958f11127e127463f49d886e0421a67749c8ca3197b87dd09726ed930846693a376e837a3a09b001082a16ff43c27207ed3828736626fd4adaba1dd80480aafa7ea4c752f85c7b1c2b63651346e8cf230aa93d31a2af749d8129c561577b4d4067e59fed2c0fc79b5b21bc36538009cadbac6f1512c64bbb2cd7c70d295b7cae67976b88fb05729e6c87c35be53db758c2f38e1c17db56abd4371b5432c6704b42f96f447815562ad95d365a41cf2b79a063ec56f8e9c1ddb46156d9c5fe178742d39c94becaad6fbc38b1a5c7f7294fc51a5a394fb9edf25beac76ca43e7cf62a30483192570d49ec0af27abe86e635d3127ba6e594b1bb906ea8202625ae73dbb13e88dbb3d46e3dd092b4cc3d5d979bb9ee29477636e15e18b3cb23f66ae7d15632185d86b8e0e0abcc9e1c0bef4ebdaccb8739c2cda9f7437789a0672e0be92d2d33e9ec2d3b3276aede3b638f911b64a336bb7f9677703090f89c5e4fb290ddd70e711839496ede439747db19109554d254ccc8da0e33cad16c304167a18f6346f70e4aabda2115158e18e02b2c64978881ce12b75e37c714dc20c99901ce5375003811ee8aa3674a9f9f7082a80ede70a172041100ecfba50a831920f63c2560077a93552d1805a855aadea260a371a978c33be5475056dbaf7198e095bd51ec0a9cd7ac6cb607b7b1dbdd7cbedd4574d257e7be9e47bd85ddb2a6e28b1f41362968cb9afedf28aa77874271eea2343ea16eacb7035236c985352521a20ec7d2b2ea9414f552d35582d240cad2b49dea2aba43048f05db5679571327396f2526cb573daebdaf73886129484b754518a6bd7548c37395a5dbe686a28182370240f959f5f5e2b2d8da8a6e5f8c9c28ad3fabaa2825114ae3c77caa99e91963b6b6d246721741c82a12dfa9a9ebe204386e46b6e2c009dc157e5acee01ea65d95201f952900df16e557b8d70336e04774f536a00c8f66e0977a2e09d9ea0301195135155bc91942545d5ae19dc101f8834bbb853b130d2563e5d929d3874830a3a3ae663b84f4556d2ece42253b8f8b2523808f096f9834e147d3d534b7ea094e9dae7770afba3a8f6bb72f3ce426e091b8ee138eda7dc27dc7ed1f531e7dd0a18e6bbba9295adf942bf0d516ab40aa1ef0980fe792a476c7234838ca8faca395b97307096cba9408c70521cf20a03cd490bb6bf211514ec9877e507d4eb5c1c9cec135d32c394ade077299e9e321094d94a69cf69ec91d6c1c2363420bcfcae753ee8633ae7593d8d0b1280b8f973d907d6c9c652f7f08d8d1e1cf72961e1810865fbae7578ee8d8d0c2f0e49047ca0faf8f75cf3207ba4121b8009b2f2e3b505e6c7cae79d1ec809466da76ef273f655fd4fa7e2bcd3ba58d81af0328f6d507f729e86a5a4ec27829065b6cd415fa66e42965ddd207192b4e8eae9b50db3731c0bc8eca1757e978aaa9dd511306ec67215374c5ea7b2dc453c8f3b738c141e87574735a6e5b4b08692add6c98c90b08f84e5eedf0ddadde6e368de0678511a66b9ec7be19c60838194b4171b67e5ca1e4f2a52e0e6d5c25a4e0e143c24870213cf95c7b94c6956b9da2a2198c90b8f743d3dcae34a76b9cec2b5b9cd77046532ea2866072d00a0680d35d642039ef2519e669ab99b25881f6ec83968031fe9ecbdb0b02668dbce8ca1ab699226b413cf0a9b5da4aa699c7a65d85a03e47b4fd44a6a59f7b76b9a9486a351696ac7724bb9566b1e92929ddba4279f952d156b18034306422d95724d231ac695a4c51683aed24f745d48f9c05f3e78b76c74354e2f6918fb2fafe8630ca76b241f50593f8d1e1c4974b54d5345197498240016b8e3a65727ccf6c6134c5c07089109785134115f2d15f2515753bd918763242b036680bba6c3eac2",
            "74bb5a43208e46ec78dca36ba8a26bf6000651f992390e0265f4cf9ea585df2a29ef6368690db6c93ca38e14df8174cebd6a1dee69203d42ea1a87d15a5d4f83ea185ad7ecd3a5d91d0497070e7ba93d2e7e22560a68a3a28cf24614758acae86da6a1c393ca8ed797164ba85ad2e1c3b18565a496a3f081e83d3c775144fb51f5165d2fef525a65b884fe8a2efb26e9c01f2a76cb1f429377c853b744fa4a50b3f30fea86b9c65d54d1f746dabd6e71fba6eb9bfd29aab19b65953f48e0c68695c95a5afdc3b2681c4e07608aa969e902decabab0fb729a5d8fc9435f29baed12307dd2c72c1f29c925df0160e51a4e396a82b4d516c83071b5582a2aa3a88c492441e5bee42ac53b3a129fb9561a294490188819296dd171961f86e6d7405b10d9fa26d9317bb0fe509b3a1374be53a4ec77dd1b73df28a0761c85df32ff0094c6ee17b7848a57cabd573fe94b1216f70a5bf00925e6073404ec7a76571c3812b2bc6f5af2440c9500f1ca6e26ba47f00ab8c1a3b77a8b71faa3a1d2b141ea2004a719ce45219048d27d252e28247071da7856f75b202f2d0d49fc3628dae180b4c78cae6aa586d935c2ff000e184b4382fa42085b43698a2039daa8de1fd829bac6a1d18c83957baaccd200de18d5be38e98e5768c0cc024f0a22e550f0e0c8725c4a93bb4ed69e9423d5f217ad56e660cb3f2e1cab18e226807e1b42d9dffd638298d3ac7d74c6520e0a876bbf13aa14ad0700e15d2df46cb3d302700e14d6d26a0b9418c06fc2126701ca6ea6ef1bf2410826d7b67760148cb9417bb213024cbc30fca21d2371b41e50c6221e5c8243f8873c70d95c33ce17cb574ac68beb592c676bdddc85f536a1b3cb7963633cb73caaa5efc15a5ba3a19a9e31d46104e114ddd0ba6dd1583ced283f4e7845505f8cd3be96af820e395a0e90b3b2c5691432b4636e15135d58594f23e6a3f4bce5d90b3d2342df6f8cfae173483ca88b9649118187059f5b3c42acb35f851d7c84c79c72b563e52e7462ba02d396e7853a4d83f4556f5e37d3541c8c6065425f695f477291d8c31c784c5254cb435ac73090d255c2ed6f8eed6c6ccc00bc0c94b4957ad97075060879e54f33501737ea54ee9bc4a63771b53bd4747ee521a5aa5b9755b9dc858ab1dbcfa941c75a7b651314fef948692b2d73cf1b9302b1e0f7285eb03eeb8e7a3634916dc5c0774e4777730f750c64fbae64bfb14f6562d10ea0c0fa93ccd4193f52a71739bee529b2b87ba0b4be41a8f6e3d48d1a88607a96742a5e3fb45382bde00f51451a6826fc1dfda4dc978047d4a8adb8c99fa8a75b5ee70e5c521a5d61b983cee52305ea07b431e42cf5b717b780e5efc45ed76e0e2aa43d340aba3a7ab617308caafd543351bf2c3c050d0ea8960382e3847b353d3ceddb2639468b42e0bcf53d2e3d91ad9d928c87055f99d14a0ba0772546cd535b48ecee2423434b6c9288f9ca6fcc077baaed25e4cc76c848526d903c65ae051a1a1a660123af9f741ba5c77291d748f4384dcf74ef9818eea2fadc672906af8f740d251d503e5366a467ba8b7551f94d9aa3f29fa5a4a3ea47ca69d53c7751a6a4fca43ea09f741e920eaafba6fce6d3927851c673f29b7ca5cdda0a0f495171cbb20a75b5ce04381506ccc6de4a762aa0de0a0b4b3437a13446194f078e554b50d9a36cc6aa0efdf84e5448f27730e177cdb9f19649ca05891d217b73cb692a0fa7b1ca93bddbdb4f54ca8a6c6d27270a9dbfc9bcc91f07ecac76abc79e83a121f51ed9412cf413364a50fcf202e495231dd4232b1d447a04f74a75703c650120faada7ba479dc7ba8b92a78ee867d4b8762809df38c3eeb8e998ef755f150fce729c6d5b87ba6349491cdc21deec8c04389cb9391025d929c85689b5d279899db9586d94204df4f651340d74320701c156fb6400337bb8cad718cb2a2c90f60038c2e0225fca99a1d191ce53526eeb0633dd46eb0bfc3a76cef2f78ea91c0f75a4676b38f18ec5a7e7a57c7431c62b9decdef9592c1e0f5ee1b63ae3d27e4f216aba3b4bd5eadbbbaf1521c600ece1dd96aee9a9e0028e489869c0c764a88f8aaeb64bb598996aa17e",
            "cfd143b6f8d372a68dcc70dce00e57db570d1761bfc6e65442cd87b70b27d63fb3e52c958ca9b6c6006bb230a2aa7d335d55434b5305234632f016e3e13510b1e957e0601665631aab40df69eef470b438b1842dc6d11c964d221951c3ba7dbf729aa8c4fc44bc9a7d41d7dfe9127fbd6d3a5afb4377d10d6c65a65d9eddd7ccbe295e9b2553c33bef5a6f81acaca8b56e7b898f1f2a29c9e9fbbb1d1d786bbfe32b551c7fd05bfa284d5108fc5401f2ac14c432dec18e70a5b7e865a016ee298ac766ac0fba36cecded714355c1fd2c1578b0ce11334821deea429889e9f67ba127e1c061229ea0c12f7e0ad1cbbd571d98a5735cbb4e70e25dd8a26ba9f746261eea3fabd80527f57662bbd13070ed952741503d2fcf0146d60dd19f949b64c5ed34f9c38a9adf0cb6b0ccdea9f323b0431977bf7fb22e1f4521a43cbcfba8e77e4bfa27b8493c904f5570ca87248e32b85c7e51a6318c788fa3b5078650799735f3460f247211be18ea4a1d4911f33246c947f609e57d395d4d69d676f7db2e50b25ea348e476fd17cb9af7c0abc787fab1978b248e7d039fbcb199edf0ba3ab5ed76badd22104998c00d5095734929c30e11e2e4fbb5131d233a7231b820a024674d9f753d5d1850dba3734b71eb1ee8121f3563226f209e51320c8711c14668fa135f71dcf6f0d3dd548bdb47d354305badad2e680e704cd656ecdd1c7c93f08cae9808e3a68793db8439a16d0b77cdc93cf2ab440246c7053196419911f6c85c69bcc3fe93ec81796d4c833cb72a7edf0ef844607a7e1456b81567a5863a8350d6804f29ebd5c2499a58d7221f4de5a1c8e32142bf73a73bbb149ad4789656121c4ae4751235f96947d65165996841430e383dd25c891a4a92e2371e54bc5891b955c6662907c299a1aa1c0283b07b2320f08aa791d064371ca543b6468213860c7ab1c043333307b585ef3dc2cff5cd6f4e8647878dc01575bc5607425ad76301621e235ce5859237a871faa5a1a63f799df5b7a2e7125fbfbadd3405b6b9f6963a590f4b1d8958a586885d2f40672772dd692aa5b4da9b0349186a9d22c4a5ce8d8d6b763c6429ed29564406099d9c8c72b3b6dd2aa77f24e14cda2e8ea7ab88bdf8683ca5621317fa2f29505e1bb438a8c2d0f1dc2be5cadd4faa28a37533c1701ce154eb74dd45092064e14584897438390570c8e627bcad434e0b0af181dfda694751b729aa327d49e32973b01352c4d85995ca79e30ef53804751b3af240ce175921fd11026a57f064012dd470cedfca907f14680474a0fba435f83caebedb246fce490bcfa690373b4a41e73fdc15eebb48c7ba19ac91a4ee5d0ee7b24625a729c6e47ba177e3df0bdd63ec5004b83c9c872e3a423829b64a71c95e2f0ef74f6443ddbbdd20380f94878713c2f6768e7ba366262ad9a0390e3847477964836ca32a1c499f6caefd5fd946c252696297fa9e0a6a2aca8a7760bc90816ef6f6052c48e3f5029ca49ca7bb333f99ca35b5f4f30c3782ab6d84bc6402bce6cd0f2c051a0b2167f6c3b84d4b3c647a4630ab62e7571bb05aeda8b8ee224c6461006c929ee1326524f75c7ccc78e0a6db1979e100e897eebc6443c8d7b0f64b6876de42016660bcd9467b260bc0772138e7b76631ca01c926090256e50e394b6b43500eba62470993264af3e50de30982fdc500f3dc08e52e92630cbbd87053206e4e471107282d266a6a4c94fd527d61314d716be3da4fad30092dda4f0a3260ea59ba80fa50349deb98f979e0a65f3179c83c200570ac6e01ec9d0e21bb420685759ce38053ccdc7842d330b4e5dee8ec06377221dfa3d03c467d68ca4a796a6605a70c1ca8ea569ab9001db2acb6f88b36c6c1ea2b4c631caa62d914759881ad01ccee54eb9a446228f82d4c52510a681b2b461e7ba2e0191d57701bc92b6918da6df236df4afaa9ce0b07bac9aeecacd73a8dad6973a95aee47b2b2eb5d4c6baa45ae85dbf79da76a9cd23a75960a312c83324832aaa7ec7d0d24362b6b28295a1a4b79c26cd2899989065c8de9895dd57775c0df5e54d540c23e9b435a3b253e795b4efedc04448c1dd373c41b472bbeca2aa292fe9d",
            "6d7e670d2e078c8515aaab9c5cda107d2e1b70a42219ac91ff000557ee8ff3b7d8a36f27729aa8a46b1fd9eabb505bff0012a67e07d58572f0ab4954697b31a7a878cb4616a31cd2d25a1b4ef23696fc2acd4c12e1e58ee3ec952c7ed40bc46e75f893cb772b1398d75231ad18e145cb4fbee5eae4e54c5c8f978220c1f0a1be34fdb5fe5c867caf5c29a6654b670c2634aa56021921f6e55ded10dbeeb43d171697e30af165c8a2c92455b80cc35c028eab89ff00d5b41dc3dd4e6a0d2b5569a9754c0d263ce78515f88c4ff4c80364edcad2b9729e9fa4af0fa7f2cfe5c061474d0ba395cece027dad644fea34824af5c2174d187c7c7ca917e830903816b947ccd92966134648c220c9ea03dc2ece44b1e3dd21865aa99b1570aa78321cbd3b78a7731fd56f755cb74cfa29c1cf1957284b6e94bc7240535b5bb56ccaf2383ca5751d8ee9350c34952e63f84d0930493d938c2c5ce96b0c4eea46edae1d8ab051dc29eeb0982e2c12b718cb82a2c35407728c82e8f1f960e1bf2b7b5aca175b6878e06beb6d8c05bdf6b565b52e919239b382c767185bbd15dd8d8ba0ff00cc6b873955dd4ba0a9ef4c7d4d101d6c676851eb7c6cd32091adcf07bab7e93a314f197b072ef7548bd5bae76ebb3290c6ff00ab0785b1e9cb20a7b3453bc7ac80482acf6e5051ed73a794e48e46522e2c75c1df00225f3073cb7b262797a5cb53110eca6736a445ed9571b45386461ae1eddd557ccb5b521efe14e535f22da1a1c1456f80fad90b9db076519514e410e52ac92199a0b5c0929d348d7b32ec049aa263707425a4201f0ec9728da978a59b69e02285247534fd46104e125e374889630464774885ee6393f2c32464e47090d6ee3d9076ed2f435db70095233dc63640727d9565ce7423287acae7491100f64d1a3777b83dc1fb0e565dac6cf5973a591ed6389fd15f29e6749216c9fed5394d434f514e637b01ca1563e70f0f6c75b4fa9c19a37066ef70b6cbc53021a00e36a9a7e94a2a226a636343fbf0a1ae550647160ee3853633b11b4f4f001838cae1b53ea49e9673f65173c3716cce731ae2d4ed0dd2e146487c6efe096995596c973b9e9b0e6b1af9014aaed6d7191c4ba91dfc146d2ea89e23f9d0e7f50a461d494350ec4f1b47ee553145a8d9358d63b8f287f82125d475f2938a670fdcae74b5fa6df8eab980a9ba43a5ea1a035d1aaea5b64b3ddab65e0c647ee43ba5ad78f4b5c3f72d9ce9fd3d33b735d1f29e3a3ad85bba20c211d46d8674ae64f1bf94b86ef71b64c1b26e395b88d1f48d6f50b1b80a81ab6db4a2b3f258dc0f84ba8da199ab666b0174651b4daae299b890009305aa2a866cda3284bb69a34f0ef6f097e38ada5e3afa2a839ea00961f4721c3640a996fa07cb216091d9eddd4b4561ac81fb8b9c41ec9742da6a5a5808cb64087114519e5fc267f08b886e407108bb7695badc5f8d8edbf28fc67b7b635eccc6721723a7603b9cec262fc4e9d3e5892643ec81b5d0deaeafdd1c4fd87ec97e31b1efa9631fb4729326f90821bc153f41a57a587567a5df74e5c2929a26ed8b04a5f8c6d04ce8c2d0657610f5574a58ff00ab7025490d3155753801c01f852d6bf0be06383eae423f547e31b51df7baacfe5425c3f44a6dd6b5c3269dc0fe8b5e87485969231b3639c12869bb63fbb5a154e316b1c75febe13c42efe092757d533eba73fc16cced276870e43147d5e84b54c3d21aaba42db2776b32f696ba0c67df08766a107242d26a7c36a27b4ed0dcaaf57f8672c4d73a16928e90b6ad7e39211b9b92999b57d4518043094bacb05c2def2d7c4eda3ec878e9e17122a9b81f74748369ba0d5f4f530874e435ca420d43472e407b7f8acf6f968701be95c76fd946d1baa20fa9eec8595c6ed5b6b50d5534cffeb07f144bc53bf0d6c80bbe32b32a0b8bf3fd614fd55fe6a37895af271eca06da37952d1d9332b246760aa966d69515d2069055aa2b96f68ea008d8d98739f9e5a9b76ef8473a689c33c268ba22806a171ca908c7a50f0c6cddc10a42389a5bdd061de78c0ee98a987ad0e0f7520694e770e534f81f9ce384682b6d64b472f6382a629270e00b",
            "9132d1b246f239433e89ed386650124d731e3d29c8dae95db7d90d45473371bb3853705380cdc0728928b61eb7d188482072ad962b7fe6899e3851363a196778739a70ae2c6b6185ac605be31cf9d2deecbc068f4aad6bad511d9a88d2d338196518e14dde6e70592db2cf50e01c5a76acbf4a5155eb5d41254558269e3765b9ed85b4636a77c3ad2d2b9efb95c412e79dcddcafb24bbbd3fd96f01352bd903194b0b7688f8e12cb411cf745292b9927b764b180395c61dbc24c993d9458b8f3f24f1d922b1d8a4737e42759f4e0f74c55e76e0f65361c52aa59e5219e43c77503a5a8cdc2fa273c86b94feb17b60a37b5a792177c31b717c124ee1ef9ca8d2975bb5335f4ed000180aa5520b0bd8adf58f262c9f6559aa0247bd191e2a1cec2cb993f752571c3a28f280ace6e641f628dafc1644dcaceb6890a7a72fb7388ef854ea8d4f72d373ba66176c6957ea6618ada5d8e30a31f60a6bfdb2769602fc1578b1e54ce8af126dbaa690415ae607918f525ea4f0fe39cbab285d9079c0585ddb4dddb4ad4baa290bc343b3c2d0fc3ef1943638e86e8ef57d3ea5afdb0dff43d4d3d55ae4c54038cfba2a96bdaf6edee1cb48b95a2ddab6ddd6a52c2e23230b22bc5aae5a76b9c2563844d3df095c6a6c1f5f48223bdbfda42c67e53d457282e30ec2ecc8021651241361e300f6536545f09a81cf0a774e5cbcb1daf3c1e143cf18316f6f285a6a9731e33c60a5aad78f2fd55a352d289da278bdf9e142c3f9ed0c1dc29ab7d48b843d171cfb0554d5b5926929cb9e086bb9083cf1b13065e782888ea303ba8d8dff253a1ff0075aa9354f541a472a66d3797514fbda776ee082aa11cc41ee8b8aa4b307280b3d759ad77898d59633ae7940d6cd350b44183d3ec87a7b88848703ca9b8e5a5b9420498dfec99c403dac68ea120212a2e9451b487b86426753daee4d93fa367a7f651947a7a6a81fd209ddef9436c6a2ef1798cbcf4494053ea2103bd6e2ada348538fab04a12bf4341230b980650da53147abdb06d71770a79bada3a863431c153a4d213b72de7083fc0ab29090d2efb29aaecbf55de29aaa0dc5eddff00aa62d17e92194b1cefcbcacf64b75e5938792fe9a9235ee8a0e9ff00eb30968e66d3e6bb504b1f2e6ee5132dca9d8ff4382ce1951701217173b6a30564a46493942bb3448eaa0a8672e0869e189e711b815458ee9565c191eee513535173a58c49ea1946953258e7a3111ddc2536bfcbb33bbb2abc35973aa1ceec24cc2bc9da43b9468ee6b0c97f7ca4b3728d958f74fd4f62818adf56df590e4e369ebdceec76a6cb2c962a263648fd4c694b16fa69651b98020ed90d5021ae070ad341691261ef09699daed1692b5d6c5f9a00e1265f0eed321387614d470b620033b25cb3323676e55c67554aaf0ae85ed2e8a539c7caafd7e8c9edb9e8c8fe3b72af2fa9ac91f88b384e3adf573337483ee82654ca0d46d9ff002cc8583eeac36eb8dfe95bb650fe15c2dac70a931bdadc294a9a5a7182e6b484128751ab6e7130c4e0fc39354b48eb830cb264b8f3cab9565badb363d03286750c310c42dc041aaf456e732b0340385297ab76fa6da5beca628e89825de40ca55ea1dd17a42032faab6bedb3326634e33cab8d18fc5289861682f68e7088fc1db72a57b768cb47085d1321b5dc278aa78603c65012b6ba6a97bf6cb180c1df29dbf6ae86c34869e898d33918184ddf6f9f9a60a16f2f3dc216874b75241555e724f3ca06d0569d3559aa2acdc2e4d2067232ae66a20b153086962697018ce12659e48f1052370dedc2ed43a968a94cb5446fc7ba020eb6aeb2a9c64906d6a6691b0cf2e1c49728a75c6b2ef71e8d283d2ce3215c68ec51d153b6597ebee803687348c1b5a13f3cb2551c1e07d947beaf9dadf64753cb866e280f0a48e16ee73ca69f3b0701c83b85cc071682a3455b9ce404e3640e3c38ff001443064773fc546d1e5f8254a3006b501e7640e3baec75323387332136f930784a61eab79e1044cd6ea3b982258da09551d45e1f4150d71a718239e15bfa66339052bcf321077807f541b197e9da8a790c0f612d07dd0b53a72263492d0095afd6",
            "4145559786b771556bee9d9dd199626fa4729538c96b6cf3d24b985a707e10d2504f28c48d2afd4f4ec32164e0647cae5650c0e386342e7c9515fb05abcb10fc2b1b86e00af454e2083002542378599c25afe3194990484e5a53e69cf7c2eb7d3c154a8644d333b27e3ae9dbf2bad66e29f6536501c6dd6a1832e0709e65e491c85d65203f50e1190daa09470132b43477289eec15356f64338cf0a2a7d3db4ee67fb12a0a2ad85c3a64e02136ac6295cf3e91e908da1a1749335a07a7dd47d0d63d80427971576b1d03594fd478f51e56b1965475153454708181d93fba3a78df3cce01806794886074af2d71c3472a81e246ac92402cd6d71336769dab6c58e48ad5176a9d6d7816da32ee931d838ecb47b0d9a2b05ae28a06012e3d47dd42f87da5a3b3dbdb5d50d06a5e3273dd5a8e77977cab4cc48e98ddb8fd45288f95d1f25771949a1385eec97b5736a552481ca0ef137418dfba3b1821436ac7ec898429cbe9714fd5cf334271cf0acbe1ab4b2cf2646157eaa1f3d171cab668f87cb5adedc6385187d8a90aa7034ae2ab24e659158aa8e289cab113f32c814e4714eae77fe9677ea89ac39317ee415c4e2eeffd51550ecbe1fdcb1ad62d2dff00f6839f84e69185af825039395e7b7ff43f1dc841690aee8d69849c64aac51925aeba745ca3744f881c8f85946abf0a26a599f554c1cd2391b57d0120dae6901312d3c7544b656b4b4ae8c18658edf38695f11af3a32e2da5acea7401c7abb2dc686fda7f5edb831ee8baaf6f63dd446b8f0d2d975a57c90c6d12fb6161f25befda22e2e9a132f4987856cfd8d2355e80aed392babe8b2e8073e950f417b82f0de83c6d9dbc72adbe1e78bd6fd4b00b4de36891c36e5dee9ad6fe187946baeb6139ddeac3521a574c33d3bf649cb4ae981bcbf81851d4377a800d3d7b1c256f1ea4edd6b7a344f2de0edeea690cb65ee18eb0450bc6e69e54e6a6b452eb2a78c4a3d4d6e0ac2acb7f9a9751b8c8f3b5ce5bd69fbbd0c744d95ee0e2e1950e9efda69508eac93dd151cfc7755e8eb5b2f2c289a7aa2ee49c2b4a759364a7ccd96f0a261a90f202284a00c653036295ce38254a4352e836e1cabe26c7629c6d53891ea408bf52d7c53c41b2904fdd015f6f94bba901e3ecabf4f5af6e30e5374374e36bce421a4a8e96aa6825c4894eaf7380c39495750c75919733baad54452d23c820e10d264998e56d4b768c0210951103335a5b9fba129a6731d907ba9633430d317bf05d84a9ecddd6a2868edc5a434bc8eca8b4d49e6ea1d33984372a61f493ddee00e498c1eca4ae94b0d1c0d8e268071ca5a38af55358301a06021a16b1d20691dd1ce84961cf75ca4a6cca0e10a953767b3d3b9cc7b9a0f2a4359b692929e16b5a39013963849701ec1476bb6ba49a16fb02133da4ec36ea59290485a3b6537534f4a263860e11769063b74607c266480bde4e108ec65f25316ec0c0b8c6c2070c09e344719da96d80380681ca07639454ec73810d0a76001ac0d18098a0a66c71648e512c89cf77a4213b2253d1e4a681139eca4e0b53ea7eb46c7686c63184cad43320e9fa825b6b1d9d84e148d65018622ff651724264665a30501daba510b3aecc127e1374928abf4c8718f94fd14b9cc531c8415c6924649be0e07d900f4f046c386b729b0c1db09da1a86166c9b97a79d0edf57ca018862f5e172e2d019b4f29f8c12ee176a699ef6e48ca0b612dd18a26ef70c87285d4b6492ae513501da49e70ac118739bb0b4a268e8df1b8b9ff004a06d0167a3828a102ad999b1c128a96499c092ecb47608dba471c872d6e3081841ea65df4040d9f8fa34b4ceab9486803dd6757dbc546a3b8f95a50e2cdd82429cd597392b5df87523b19e384e69eb3c1a7a98d454b41948ce4a0d2362b5d2d828449363ab8cf287abbe9a87b8077a7d9415e6f5257d490c7e19ec12ad94524cf693921013f6b89f52fdc728fb84eca2831b8129b13476da5c0fab0aa95d5d3d4d460925b9403efa8755cd904f752547485d8c84cdaadc65707e385668691ac68c0ec815ca5a7d8cec935136c380572b2f11524663e32a169e69ab6a3773b5094c432ee702eec",
            "9ea9aa6b5bf96dc26db4dc34828a644c70e420d1cc7544ee3dc04a9a8dee690e4796b19f48c26ae12e2949079c202b1572be9a7003b80559edd3c370b73a3701bb1eea8f59339d53c9cf2ac7a7e425cc68ec4a55514ad476e928ebdc5a30094c4518da0bbbab678850b60731c072555a16195b90b0c95090dea1db85c23a2ec61170b035d92111d06c9ce167fb386a2883d995c7d039c720229b096f65236f0d94161192a9480e83a338c23a929cb8852f35b9ad638ede547d2e61aad8fe06524ec7c16eea601e0225945d1e00fde8c11f5636b63e0e115186f43a440dff0029a6d4598dddbba7618f634823ba3e0a1dae2e7f645430c73ca1a1a384276458b4ff00566ebca381cab4b0fe63618c703e1022a052c62267729caeba53d8ecf25c6a5c1ae6b4e3256b19e540eb5d570698a02e6c80cc4636e79549f0fec52deaf4ed415cc26371c80e55aa0a6b8f88fab8561739d42d7f6f65ba5350d3daa8d9474ec0d6868ec16b197ecec83327a3023c7002f076deeb8dcb5b85deeae2a477eaecba1700c2ea03abdeebcbdee80e119c2af6b37eda5ce7b0562554d7ae2ca53f70a32fa5442e967f9fde0bbb7b2bcda9822a72ced9593e97aa922b806b5d8693cad6699c36b36fb859e3f629ab98d94c42aad31ccf22b3dedc5b090ab142733bf2964ac54cb99ffd30f1db9463dbb9d11cf6c213508e9dc9ce6fb94a8253ba304f72b1ad22f94e04b6f6b3ecaab0d41a1d48c8c700b958e8de6386327b61406a08436bd956cfec9ce55629c9a8bddba08dc0e72d4889f9192a3f4d55f9eb50909ce0291611b57460ca92ff0059c6061436a3d294778a63196377387c29de17092a9363e6ed5de18d6e9cab757db9ae041cfa558fc3ef1a1d6bdb6cbf9cb07a72ef65b3d5d353d753ba9ea181db86012161de26f84b246c92aa82225e791b424caf8d16f5a3ecfac29bf16b5cf1b723710d594ead6c5d37daa3907587190545e8fa9d4d6189f054544b1c4063692aadaa2aab22bd79d64ae7f393ca55372415e2df55629fa9246e71cfd4ae9a0350be5a7fe97292df604a96b0cf41ad6885155c6d64bdb710ab1adb47dc7454dba818f9a370c8da96871e7e87b7dd1f49280f39055969aa5b50d0f6154f7c41ddd760bacb6f90341cb53742f71556d382708d8ea4e156edf5d1d7b438386e524daae98da530976cf94b1372a3609f7762890f412462a9c7ba3e0abe382a05b2e0e13c2a0b064141ed6fa0bb167a5c7845d4c7056c7b863255329eb4bfdf0a5696e0e611eae10adb97285f6f69931c0e545d3dddd70944393856a7ba1bc41d17632a02b74f9b54bd58867df842f1a9da1a61450ee039287af88cf1ba477b2ed9ee1e662e9cbc11f2955c5c1a59ec50bda0dad0f053b4f106b814970e99c04eb1d800a152ad1646b40ca8ad551f52a63fd519649f243729fbed0995ec70081b1767a6ead1b1b8f65290d94b81716a7b4e520103723b0560c31911e13d33b74a85653b62696e3951d4b03bcc1247a51f799ffa56d1f29b89e1acfba428d0f1c34298b652838738286a0675e40ad34ec6c30e0fc2136bd280c3e8093d724ed4e0c1c9f6486ec2eca627fd87beceda3b6995c42adda2f305692323e177c42bcb21b5ba2dc070a8962aa305375daff7ca4a8d06e11184f523e72954952d922db20e4850f69d431579e8c8e04f647d4011faa33c20cc5452ba39baac3c23a9e7ebc433ec9886a5923763fba6a79852762824ad143ba4eca68534658010a16c552da870e5581eded8284da1c50460e40095342d31e1a3b27864043d555369d841ee420b755cb880d90b4150d76b932868dd18c750846de2a7a01d2fef5536365bcd707bbe81f283d9766a2c48eb8d4fb73ca06ffa8fcf4c618ce18385dd51781451f9280e3db8556c38c7bb397942e0e8e27cf331b1f273cad0ad10c74b420c980ec280d216b01867987df95275552e74ae8d9d8764184b8d639f31683c27e82d46ab0fd889a1b38a93be452d0cf050623184039414ed81822c60a4dd6be1b74272f1bb098bb5ca3a4a7350c70ce15468d95fa9ebb18774f282a2217cb76abc8c96e55ae8e8c52c432de54ad9349456f85a5e3d",
            "58527556c8cc796a11b413185ee00235b42e0015da6a17b6a0120ed0a78c2c735b81ec81b55aaa131a0ae40f9377e8a76eb18692a1ae63140f3f640db389ea77579667dd5bf4fb76be33f75469ce2e84ff00d25a0e998baa2327ec8abc42f88ad12323fd155a85a1b1e31ecac3e28548a631b4155cb4bfab0fee5864b12d8f27808d8224885807745c6ded859e8ca14c1c384e51c1d09329fa76fca78b013c2663a1636a9cd69507aa288d14a268c7014ad3bcc0e05157281b72b73b70cb924d03a76a3cc53754f3852aca52e93adeca2b4d523e0cc0e181953f5530a46ec086743d5d4ee023677ec9c6014b10901f57743b0c718333c8e50b0d53aa2adad07f2c9e5345a9db7b0557f4b98e238f939596788da92ab545e5962b5973a12edaedbd94cf897addba7ede6d942eccb30c7a53be0b6917889f76b93374ae3b9a5c395bc9e32dae1a074cc5a3ec8c81cdfcf78c92a7c174837bbba54e44f235fd8378c2f1208e13391e5d0b83b2f05a62a8505d494a0aa8aeaf7baf2f7ba44e3bb8555f117d1439fb2b51ee3f5550f141fb2ddff85465f4a8a0e957192b777c15abdb67de580accbc3fa5353239d8cf2afd4d3186b1acec32b3c7ec5485fce23fdcaa90c9b2571568bfbf741bbeca9d23f6e4fdd2c978fd2bfa8db9a8dff741c72fe6423ee8fd42dfcb0f5110bf74b17eab1ad1a1364cd2478ef840dd6032db643fdaf64fd21cc5134fb852153427cbf20ed232ab14e463c3eba6da6344f3eace30aea632c38593daea0dbb50b48386656b51ccda881930ec42e8c19d2769c25346129a72171dc2b67487c66478c77405faff006cb45296d7b9a5db7b147c93082924a8f76025601e20d557ea4bc11bdcc85a794ab2cb235acf54c37099eda28808fe42a732804ee2f93d59f952b5629692014b1b83e6217a8e8e4a787a95030dfba9ae6ca876d1b681be6207f49cde7846d1789904a3cadda11206701cf5037eae2e6910bbb2a6d7b8d7bb6bff002c8f755a18d4f5446e6840cacde305499240c48dc67e50d2c20f652f4340e92b24a19874c9c655c6db5915c220370eae153dcc0d3db9491555342f12c04fdd39097c64a69dfb5c51ec99ae6e72abd66bcc15d10139fcc524e7188e41cb7d93aa9254935f94b63893eaec80867dc8a6c99096d229d231a3d052e2aa767928304250761012915c2581c1d11e5586dd718eae3db57dcfcaa743212e46435a1aec13ca5b3956192876558929cfa33ec8dadd9244dc7d4072a1e9ee4f6b700f08a8eb1afee55c56351b53e8772ba1de8445542d95dbbba6ba60370a6d692a4ac52e266e7e55d6a2944d0b1f8e151ace409da3eeaf4fa8c52b003ec97aba92b496b19b4774e5c2afcb44771c28eb6d500f1ca4dfa712467251d915055330a8a82f0784e35cde07ca0810dce11d6e8baf2341f946d37699a38bc9c3d77f0d5dfc6cd53cb6239c263554afa2b580d07007b280d1d7482598b1e70e3f2ab634bdd04ee96321ddd2ea008a99ef6fd40209f14b0bc3e33969f845d64823b5be77646d1ca9d9eb4c7f5f32e35ee7b584edcaac9af9adf6ce803eb560d45aa1b2cef8a2e4e70abada692a6432cad21bdf94b6616cf79ab8aa9aecbb24ad76c35be6e90194f38f759953de2d14b2989cc0640a529755b62786459da7b613d85c6bea9b4f3e5a7805224ad6d6b400794088dd72a43202771087b647252c85b2e739e11b1a592cb5a68e70c71f756efc49bb03c918c2a53dad7441cdfad3b497273e3e8bc9047ca65a5b3f1a89fc02137507ceb7703f4f2aaeda81d60d694754dc5d053e2327247281a45def7d44a211dbdd0d3ba0b35bdce180ec27e17999c5eeeea9dac2e32097a3b8ed3c20690971a9f373baa1c720144e9ca37dceb0607a0284a77493d50a7c12d2568b67b33e8a91b24030e21063e5aa8a82314edc02060e10d31765af603ca720b4c92cdd6a8c953f4d4b48f6866de42001a792a1d108e3072510fa31454cea8ad700719e549491c36d80d51734060ce16797dbd5c35657f94a30e11038242006a9b9545eae82969b7187760ad7f49d929ed76f638b5bd4c65556c364a0d3f420ce1a6a08ce4fca99a1bd65e01770",
            "84e57c5a9ef279292d21fc24d3c82a220ef64a0361384f488f6c0390175a49195d69c82bade06102d405de5dce2d1dd465cc62def1f6523766ed9f23e5475e3d36e73bec8d2b1f5964ec77e2bdbfb4b52d35074e89b29ec392b35a369a9bc00791b96a82334362796f1e95392e283e21cbf8bd636384e4b4f385074137e1d511c33719f946534eea9b8cce77383eebb7db61aaa6eb443f3076c2e7caaa263a06501f172defc2f473b627ec7f7513a4afde57fa2d6f0fce0654e5e6da658bccc1c8efc28da874387b72d2898a23c9f8552a1bb4b4cfd92640fba9fa5bd46ec65c3053d9d1cd69964c0ec148d3c44c8d67f64a00dde9222361049ee80bf6a98e8e94c90b86f08454fd5d6d2db66032377d934f9454b4cee386aaf697a4a8d4719ada8dc5a39e50f7abef94aa34319f4f657316590badb93a6984119e3384e56df68f4cdaa592adcd1296fa1455aa179ead4c876860ddcace7515e9fabf52476d6b9c6363c038fd55cc231cb24f68dd3b5fe226a4371a80e34d1bf23776c2fa1590416fa48a9a9da1a18034e142692b553697b0c0da56b7739a37291a797ac5ce3ee53de8a4fd8c0e05985d68f4e134de4e0277e946d51dc2e818490ecaee72af1caaa3c940a4ae85a6ccacaea42e848b4e93c8fd552fc5a76db683f65741cb87eaa9de2cc7bad79f60d4b2fa115ef09f6cad78f72ac7727795bab5a78c9552f0866cd53983e55db54d36dae8e6c762a31867aef52c75206e79c2a7d53f0dfdea66ba6ea419f8185055c7f2323bac73ad30f51b7e3ba91b85074f933c47d815317270969437dc2858dfb2660fba868d0291c2510ed3db1956c7d3f99b76d60f561512d55043a303df0b47b53775267df0b6c318cf2acbef3472503ccae1eadcb40d27728ebeccc85aefcc01466a9b39a989cf2d55cd1d727d0dd8d31240ce16b3c4eb71a6c4fd9f96eee129cedce0d09150321b23792ef84cdc2e54d69a07544cf01c064654dc99e5f413525c22b650b84af680e0b08d437e6cf56f8a8c6e24f709dd61aeeb352dd0d152973999c7a51f65d1460636b2a78c8c9cacae75c9c9ff00483b769973dde7aa09dddf05476a4bc8da6986001c70a7f55dfd94711829c8e063859bd64afa87191e4e4ad31b6b247d5d54ad2430e7951150f717127ba93a838054454cbeae56f22a4d35bd41a7a3d9ba10323e153aad925349b5c385a40cbb879c850b7bb432569731a32b27a794534c424194dbda00da4232481f4ae21cd384cbc827384bb32b8d00219295e258c9fd02b15a2ec2a1a1931c63e5453467bf64dc80c6edd11c14f7b18f8b935cdfec1ca223900182556282e858031e7952f0d407b770720ed4c46414e6dca8fa7a824f2a4a121fee8855e8d843b84e98c0e7dd3adcc433b739487c24fe61760208e53cfb4fa8f099b85e1b4c7f2dca22eb77653b0b18ee42af3ae12cb973c93946cf169368b90ac8793ca31fdd51f4957996ac464e02becf1ed008ed844adb12686431ce0ab64555d4807d95386637021592dc77d3f3f0a957ec7d2d56d7f74bb8547519851ad79131013f31dcd0a740c42373f054dd1b1b135ae6f75134edc9eca5a8a33b864f081a4f4d44cbbdb9d1c83240592de9b369cba1742c3807d96bb473f49bb47ba02efa5e9ae87acf6827ba5b45a8fd25aa1970a568a91b78f74d6b5d634b456b969e370248c70abfa9de2c548fe8376168f659fdbeaa5d4733a3a979033ee51b386f4eb3f1dbe399b0905d956bd68ea5b251369e3681291843da6969b49d70aae1c3e5097b136a9b97996b0ba241abf4562654b5b52e6e5cf2ae164d25146d134a011dc276d96811b031dc63d94d47ba26eccf080e31be58ec8ce1a139253894878eeb8d84bdd9253b9e98c27009a30c2dc39445fe7fc3cf523ee51324869c19cbb007b28b63dd7bacd8e196653093b035f57175ddee9770b9c304dd22e19ed8443dd1d8a89f823e9ecb3396e735d6fa035c71bbb203467bdb15119f3c632b2cd477815756e63397038577d515c6d560c48edae2de167da2ed925fab9f33c12cdddd0171d19618e684544cd1bbbab9b0f4c06347a420e969c5be36c71f6c7b27a3aa2e7f4c333f74",
            "01f138cc3605e7491dbb2e79e7ba6e79596e8bac48dddf0a318e97504bee1a100c5ce6adbc54086124424e0e14e5bed34563a705a1bd623bfdd3904705041b30378f7518d9249eb835ce2e692802e7a1a9b9e5c33f6512f8aa282a031c4e32b4bb451c71d30240ce1435f6d314f287b700a136efc48e9e98cb48dcfc2927f751f628ba1006fd9481e4a7b47ede8c2e3ced294384d4e70d24a3610b7570749851ba846cb393f646553f7d463ee85d5236da7f7236b8a1698a37545d81c7f6968daa2a1941691138e096aace81a46bea9d238763941f8937a71a96d34673838e1464b40c403267bdbfda2a4a86a9b1bb128cb546420b62639ddc84645109072b9f2a70cdeb4c3ab2415f487681ce0294d3b7e0d6791ab1c8e394ba4b8187f20f2d3c2ed559e39bf3e018777e14453d79b0b27fcda73907e141bed75910e038614a0bc4d68c36605cdfba725d63452c472d682aa9a1991cf1c65f21390a3a9e09af5716d2e49697255c7500a898c300cee3ecaeba1b4d189a2e528e473ca70aad968a7834fd9bca6007b9ab2fbcdb649ef46704968764ab96a6bbb1ce3219030378c65663a83c4082d8e9304389e02d239f33de236b886cb68651d13875dc36b80eeaa5a33a74120b9d4732c9cf2aa6e925bc5ddf5d54e2e889cb5a4a9a8a57c92358c388dbecb48e4c9f47689bbc979a7c3dc768ecad24b6205a0fbacb3c3ab9b608db135d8271eeb45748e3877b1535be3f4918a52df514e09cbddf640b67dccc22222dd9f753b5090fe538d7650cd29e61e15ca47815e2579b85c3dd56ce140aea4ae84e5371cfd8e6feaabbe2441e66c92380ce1a5589ccdc47d903a869c55d92a598ce1a52ca8647e0fce59759587d9cb5dd474dd6a4126325633e1f3bc9ea69633c65ff00ef5bb56c626a6637e4231fa0a208c9a7735ddd413ddd49dd09f6564b8ff47ab30e30157eb6314d52e9072b0cd78a12a9df9cf8fd8284a976ca91faa99aafeb5d27b95055649a869fbace345c2caedcf8ff0072d52d23146dfd1643639b13443ee16b96a77f4169fb2df8eb2ccfcd4eda989cc70078597ea1a17592ea2a58300bbd96a31c84125416aeb341594a6491c1a4728cf2d22667ec9a829dd6833543c02d19e563be206b1abd417175ba81ce2d276fa4a3eef3d418bc9523ce0f1c146691d0d4d6c26eb5f202e1eac38acfb32cf27b44f87d05968bf12b90f591bbd4a2758eb9606be928f186f0308cd69e203ee6ff00c32de3d0df4e5aa8571b7b68d86799d97b867bad31c76c2d4255d44952f73e57124fca8a9e7c3884f54d5992421a30028caea80c0485bcc34cac0f553f246543d4bf2e4fcb3179ca0e5393dd68d237e71c8c84d75792d78e13ade3bf64c541693e9eeb0af56c0174a08a48cbda3954f9e46c73ba3f8572ab6bc42eefd9512e21c2b091df2b9f3cb4db8f8e587a395a1e779c049f4b9c4839084ae865746de9e727e148436f923a56b9f9c90a70e567c9c1afa30e66796a2a8aadf13c071e10d23648b3c129113f7fd5c15d33925735e3b16ba7ab8ded00100a93a493691cf0a846ae5a67820f0ac969b889a3cb9d83855f69d2de6e10c708df855dbc5f782d8dd80a3aeb717483631dd94492f70e4e52a2b8f95f3c85ce39ca263682dc26a2893db48e023450bb4ce692e4d238195ac515436aa89aee09c2c9cc3801edfa82bc695b907d3085c7d5d946574e8e3f538d907536953347216b300a83aa674cee054c58f154dc6790b29cdbcb4e8cb8fcd8d8ce0e4a5e77b80f64a923e9920a491e9c85bed968547860185274997346141d34a4bb0e5314936cc7c262a76923c8194549b9a5bcfa507492ee0085db9d7b6180f2328d32aa5f8a90b64a5cc0373b1d82c96d86489ee0e0637fb2d52e356dae9f121dc3eeabb78d35d6984f4edc11ec11a3882b8d466dfb67939fba4e93d5f1d33fca0607f38ca8fbddbabeaa6f2e5a5a3b22745e92929ee39a918667392836803d6d138e014aea1760ae4b88dfd26fd00709b73b08025b2ed0bdd5cbb27b213ac99a8abd911f94c1177a97d4011459c7d94ad82065152ef78f5614559e1754cbb9fc852170a810fe5c65011fa86add50241b",
            "b8c1556d2b6beadd0d40e431d92a62e729e91cf7291a64fe1d15439ffdb0708085f12ae33df6b21b7d28380434e15b347d962d39680240048f6a02cd6d865ab9ab650090723288afbc3aa26033b58ce10699a7a83213bbb65395173a5a26e5843a4f8555a9be8fea69b990f1c290b158a7aa78a8aa27e7050491a6ebdee51d5cb59953f153c76c870cc03f29b6b61a666c68031ee84abac7386d27840267ab2f2e19ca6289c63a8de7e534d6bb249ec9d8de1a7080b8535f8434e013ec8615cfac9c1078ca89a787aad193c298b752863861049fa06e2308a7245330363096e70c211fb73700392a3ee156d0080522b6b3a476e7ba84aba939e4a04391bfa939426b498b2dad60ee53d6b3d6aac26b5453baa9cc880ce0a1708d2f4c6df6a754bb8c8eeb3fbc4be7aef239dc805683a96be3b46998e26901f8c2ce2801a891d2bbfb4b2caae0e6b37b1a00ec9e635c1bf09ca48b00828af2fb9a400b1b40263c314a5beb0e403c8515340f89dc8384550bd8d23254c34cd459a2bab082d00aa95ff434f164c39c7d95eadb217e3615272c6646fadb95419b691d167ccb5d523383eeb44acad86cd4829d840184d358203960c2abea6ae2e97617729c4ed4af12ae355152495113886fd9630c9e6bbb8ba4713cadd75fd187e8e95f804ed584db01a784b88fed2d22329b4e4142f6c21ad0404640e300c7ba8c6df1cc606e1154955e6b95a461960bae8dbc3e96b1a5cec0cadcadb748eba8d8e041385f325357ba9ea1a1bc72b52d25a9b63191b9e12a278d5a9e56b8e0944364c3b00aaf5357b1c1af0e1ca97a591b2343b232b3aa48b64e5111bd04c394fb1d844a24181c4fba5843b1e9d0ecaa956742ea6c39380a72915ec9b2cea515430ff6814a2ec05d88e7d3ec53b430c733f09d68d18dbbe4ff007add9aeea434eef62d0b1ef132dc68b50d3d5460801c092b50d335a2e56b85f9cec604602a0b5845d293ae02afcf4e66a0ebf756ad58d1351387baaddaea193d33a91ddd4722f1542a5f876d5175ace890e70eea5f50d33a82b32461a4a8fbb81514d1962c9706e9f9c1ab8dbf70b68b59115bdae7f030b03b15418af14ec776c85adea4d450daecacdaf00ec5a615972dd262e17da5a2a77485edc8fbace2f9addf7999d494f27be382a9b70d575575df146f2413844592d6ea3fe9729cb8f3ca8e4ae4b9acb6fa78e80756a4e5c79e5057fba55d5b7a14ef708ddc7082acaaa8b94a18cc86852919a6a6a3fcd2dea347ba3189b92bf4f474d64a77cf53874ae19c9543be5ddf5b54e6871d9f0a6355dca5aca82c0e21a3b2ac4d186b724f2bb308cad33512b2361ed950159560bc8253f5d5603cb7728e958d93d595a9c844aee3210323c828895f8184148fc9497a7d0ef7ba4e1a90da5735db9c8ca18d80e5c1395433d9636bd6cbfe81556d3016e39c2a6d6d246da873dcae9306889d91ce1536e91cbd7738fd0b8b9a5d37e1beea98b5ba19ea8b1f8c03c276f755e5668e318da4a829ea4d25434c7c127946dfd9255c54d2b739182570ccefe9db7097ed3869e13144e781870e542dee0653bc490fd211d35509a818c67d6d18512e12d453be0772f3c05be1cbafb63c9c535e04f34d9c7b70954d7074126c0784ed0694ab0c2e73b19e5075109a2a9d92771eebb78f9b1af37938b2952e242ff593dd29afdc80a7989f7e1484201e56bdb6c6c3f1e4a21ac18ca4c31646427834818572c2707645d92a24a6aedc73b72986b1110bd8c38f758737d78db86c97d5c1f7013c5c1f64f59af26df37a8f05562df73609ba6f2a46ae02e6751878f65e577b8f27af5e6132c3c68b157435d0ef6b86e41c954e89fb7d8aa25aaf93d1d408de4edcab9c35f05546d711c95e963cd8dfa7165c5963f63e19039d953101dd18c2afb038f2c3853342e2d8c6e2ba31feb9ad4f524e228b92a12f771dee2d0e4aabb806336b540d4bdd2b8b895534341a6dc5fb9bdd49d3ce60a432c83b0f7518c76f7edf743deeea28a94c2e3c94ac10254d60aaac3235a0e0a98a72248c61a01503628c4f991dd8f2a6a53b4010f05205b9f825a7ba6def492486e4f7480edc506e39fca6a4619ce02ebd",
            "dcedf74752d2ec8faafec9839498a4872a38ceea8ab77c27aaab1b2e58dfd1314f018f3267ee81a017f7069681f29d859d6a78c0e07ba06e9379ca86c4def9c2939e58ec96d0f99c324701041ebeb23b645b1ae0323955e92ae6ad93a54e092ef709971aad475459087609e0ad074c69486cf4c27ac00bfb8ca0d13a734abe1736a2a012fef82ae9d46b210c0d03013227133b2c0034245438fb2088924ddc650ce6b83bf33b7b2747a87dd2a366efeb47e880e31a0b575949b9f94e061278ec8c81bc7dd00fc1096c600eea56df9663728f81af0ee7b23a27f380824c1aa0c62453d4759c402a3aae530b393dd3f6563a425fec92283bd6593050b5d376e5596f76f92a2274ccecd5499a6748f737dc1c20f189db09fcfdc548d5b5a6a5cf7760a2ec5bb23e51d7f97c952991c70484b6b67baf2e2fa993a0d27682a2ed0f0d8dadf74fdcbfa74af9072a268ea0d25516499033c2cb2aa8b8c0cce308e8e2c738425b5e2488380ca98a6a72f6e7070b2b0ccfe182ac7651b5f6792986580f0acb4e0b3800a21d47d71ebedf74a4252296f535b9fea078564b5eab82b1bb5e46572b74dc151bbd6d05552b2dbf844ae2c7e7f42a82d571bc450b4b9ae0a932d43eef766b01c8ca1aa2a2aa7f4f38289d356f9e2bb32579cb7ba70ccf8af591daf4a3a981fcc2decbe7ca1a97be95dbbe56b7e385ddb2d50a50ef6c61640617b2121bc2d226e8534179e0a22196680fa33ca8b82a24a63993b298a2ad867c1c05a46745c73b810e7672acf63b8b9987648c28681f4b2371b7952742d8c3b0080954f568963bfba42d639dc2badaee87701bb859252b64610e8a4569b45d1f001d57670b2a5d6b54a5ac0f3dd48364046550ecba9a0a89fa43390add055b5ed182a4245afca79af4232569e729c6bf3caa9742514244e35e846bd3cd7709cc947f7642ec2f01fcfb14d35e0039496b8b9e48ec9dca05775fda45c291f501b92c1c2ef863580d0494f23bd4380ac55b4c2b2db2c58c92150b4ecceb35ff00c9bce37b95634968d471b831df0b3e74cfa0aeea02402e5a6ea8dad85bf70b37bb35afc81dc153c9a5e344eaba36dced51cd08cbf1ce1542389c6111bbbb55d34ad632a1925354f6c606540dce8cd0564ee23d049c2cab4915bff83d5098776a72f378a9bcc6d803890384ccc0bcbc7cf652da76cf93be4ff6a78d73f305d3fa79b13774a393f2a7bcb17623ecd09752de8c81ace00425c2e9d080b587d68ca5ae0cb2d19b954c56a88ecc172a3575faaaa6a70d71db95215b572ce5c66390543328257cae7372015ae18a3b0b9e94d5c1d41c9039555b9bfa6e2ccab31aefc329dd1ca725c3859edf26aa92a9cf613b495d1268e7a16b699cf93720de1ec443e793a5927940756499c427b5c2657a0deee51137a490837bb053956fa720e0a7decdc135130b4a3236ef0b9ebd446d4c3f965566b61fcc76eecaeb530e632ab37aa57362739a3959724de2d30bfea292fa31515f81d81523782c8a8d8c6f7010149398eb1fbbbe50d79aa7bf773c2f3ae1a7776da4ecc054c2ef9c2542c6c35997fca034cd680d2d253975a82c717838e542adf12973ac9e021f13bd0a22e5136e34fd46ff0059df2974f57e769fa6792930bfcbbcc64e56b878cf2c7b22696431b844fee14fd23773428caea4113fae3dd48dae60e600bd1e0f71799cf8dc6a4a2f4f09f6b32134d1ca2a3e42d751cd29bc612e99a0c872b8f660a7226e3d48b370e5f513713252d509199c6559edb7965652363ddc840d5d347534eee3d402a7475f35a6e05a49d84af3be470fedebfc5e6fd34ea1b732aeada31dcabac9646dba91b213ed959859f564704d1bb70cf1eeaf326a692e94ad60ecb8f8ff00cd74f37b125493f559e9f65294f316b3692a1ad2cd94e49ee51f1bf95ee70e5bc5e467354fcee0eca89aa9f612015252b835a4955eac977d48683dcaa93d17e87d2f113a63edcaa9ddab45c2e222efcab3d74e28ad2fff008c470a9fa7295f597074cf1c6e5592645b6dd4de569c0c632113270cc8eebb29036b47b04d1767d2a4f44c8f3b4241761bc2e3cfb24c277bf6a01c823dcfdce4f545596b7a60f091",
            "52453b383ca062775ddbc941c79ec76ec81dd3955398290b8b93ee963d9b48c7dd566fb7131031b4e72928dd35d21150f7bbb841d4bebf54d5f419bba6d385cb4d8ea2e7307e0b5a4f2b43b65b692c10870683211ca1349d3365a6b1d3032347571eea4669a6aa7f27d0877b9f5cfdd9c0ca2d83a4cc61045336c6dc0e1364ee29e64465ec9f8e85ddc84c068e1ca77a3f289e8f4c765c2328061b19051310dabc1a025e3080783c809f63c319b90a070bd24843309c276599f552060c9565b54069e0e78e141d8e0124f97056a76033684914dcc77d248cf62165f7778a3ad701d895a5d63ba1412c99ec0acaae728ac9647e79050ac571d25b6a65191c6141f899751138d331ff006c0537a55cca2b5baa5c7043564dab6f12dcf513dad25cdcacf2551d68734c7991dfc522ed4d4ee78746465453bae46c8f20a768e86ae57fe638e1616ae2e5a62aa082302770e07ba9ba8bf52d337733696fc2a9d358279c0d9210a7683486e6fe74d9fd4a5b0706b8a6fecc393fa253b54c95636c50b867ec8c874b50d310486b91ec868a9db86d3b7f82364aa55d25dabb98652cca18d8eb2946fac977ab355d601c306cc7c286afac7c8c21ef242611155253b632d6346e0bd495268a89f5927a43414c4319a9ab01a3737dd57fc4ed4d05aeccfb7c4f0d91cdc632aa42db33d6978fc7b5039ed3b9a0a8ba88dad38087b54444324b29cbc9cf2972bdce72d22299a8a7059d922de035d808971dd1905074f274e7c2b88ab0d348c68c6394438ce0e58e210509c80e4509f901456b3e8752dcaae17005e70acb69bd871c4993c2a80907745d1540de00514fed78a1be43495ad7378c95a95aaeb1d451b1ed3ce02c21c325afcf215fb48ddc3a01139dd87ca22328d2a2b865d8ca3e2ab6f032a9b1d78049ca361b9679dc8aca55c84ccdbc15e15233855da7b96fc02e47c53870eea2c56e259f37a785e8e52070848640ee329d63873ca241b1d0541cecf954ed494268aeacad03b1ce42b231f876ef85ebad236e96f70032fc2d20d932cedbad8faf9dcf6b70a855b116e4bbbe54f59ab5d6e7ba8a73869f951b7f662a0960f4153558215d2ba2730d3e43b3ce14fd550b2e96d0ee0c8072a12063602e7bb9cf64fd9ef3e56b0c521f4487014d6ca8dce3f2d5e2323001563a1063a41234f184bd71a7cfa6b60190793851349750681d013ea03088e5e7be1771ba0730b5a72f5046492527a84a5b237999ce79e094fba9c4c711ad7079797b51d151beaa7da41da87bed5456687008dca72e1594d66a22f247530b2cbc5ddf78aa76e77a72b68240f70bb49592ef24ed090de9d6c04701d84254344643476424b52fa33961e1691ae311f5e64a6a931b81db9499006c7bd87952b2b62b8d39771d4c284c3e094c72fd3ed94d70c17179e7baeb694c9dda8d651b41ea7b225b2c510c6027a1b7d0c1a4fb27e0efca7fa4dc26c47b4f0b07aa54addcd51b5144270e63870a55bdb09324608ca566ce5d330bcd99f4b54e7b1bc6557ee116e6e3dd6ab78a313c2ef4e4ace2be9bcbcafdc3dd71f271bab8f2da128f34730dbee8db81352d0820ecd5007b2959da046dc7c2e7eba74fda3edd2f97976291a8635a44a5dca8a2c2d9fa89f99cf9877e12bf4208ac94cd001ecb96a95ad903495d8409212c3dd4516cd4d59bb9db95d1c1c9af1cdf230dfabc8682c05a729d8c9010b6c91b3d3039cbb0886b9dbb6e385df8fb1e5e58ea9e6e24e3dd2c71e9498a9de1db8224be9e31995c011f745f0f19b2218a439e38552d494d1998e3876558abf50d3d244e6c4412a97254cd71ac2e39db958735963b782595db753cc6ae3c93b72b5cb2ec6d1371825671134445a00e5695a4a91d51499395e3677593d3fb89eb6cdb86d28dde448005191e69e7dbd949538dcfdc7b2f63e2df1e673cd52ebe4d94c49382ab54f33a7af681c8ca96d4551b22c34fb20b4d52f537cce1f4f2baab035ad2a0c221859fdaee9db1518a5a70fc609085bb1170ae00f21854b46ee9d3b59f65221c0edc739497f072136c71c2eb1feae506f16bbbe3ba56c6c2c2f27053ce7b43727b050d71ad74cf11c5f282766ab74f26d1c8",
            "4e411b84a00fa4a453d3f4d809ee52aa6b1b4b4ce03facf6419abe56329dbb22765ff651f6db1cd5ee1354b486f7e51167b54b71a9f33539db9cf2ac6f986452c2dc0ed9091bd4b1c54310642dc9c7b295b7da65b83839f923e0a55aece5d87609255c6db41e5181c5a84a259a736b40030973d94c7090064ab087ee7764b7b5a4648416d57b6db1ec387b7dd4e32d8ddb9c221a19bb800274bbd827095cb842232428ec72a66eadc951bb006e50640ec94123b2f025067472bc181cec24029c85a5cf09925ed5074c8214cb4e48ddd94751618c195cafaf6c511da794aa748fd597665353ba163bbacea376667309fa8a95bcd43eaaa7d4785122322b19842be963ac9df45a79cd69c642ce29606bea9d52fe492af5a96a44562da4f38544b6c9d48f9f959e47b1ed7064dbc3785274d54d9380d0147b718c23295a0105616359f49fa198b00c1520c334af1b5e405154ae68c29386a8469680f68747f53c94a7cd86a0dd5b13ff00b5ca6a474f30c43c8468b41ebaa1b93920286904d54e2d2dc30fba36a3642e2eae73581a7dcaa26baf13a82cf4ce8289ec2fed9055638a32a94bdea4a1d274ee2d91ae908f9580eb3be54ea3baf9bdc7a60e7099aed4157a8ab0be691db09ecbb551361836800f1dd69a46cba69f7c2083ec888c87f2a2a81fcecf652d133e1568a9d8630f241433e8cf5c168460611d9130421c4642645d3c7b6300aebdb83c229f17a38498a32eee9587b32ccb8f28df2e63843e3e5c532f600303ba3adc4c7832f6fba9d34c4ec6e93a00bb39c291d3f707d34f82701230c9be90309063e81c8e0a50722f115cfb7abba3a2b90181b95129ee240c12a469ab892092ae4db937aabc53dcb6ff00694bd1ddc700b967ecb8f23d48b8ae65bfda45c0bbb4ca7af0796bb28b6d501ceee4acf28b500a620b9c3f7a9da4bb0a8c38386145c5732dae114c1cc3cf25394b58e824c3be95070dc181b92e088656b6777040507697a8ad6c959e762383df855d96a84f4dd3772e0a46f77be8539801c85071466487aa3dd07c797a648dde83ec80bad3ba0db333bb395223d4ec7ba4d7c7d6a72dc7b29aebd6d27a76eecbedb9f49372e03032a9f74b53ed37276fc88dc51162a836ab8039c0cab46a5a06dfe883e01ebdb9e138e7e5c3714ba9607faa2fa7e54755de61b431d217027f54cdcee8fb0c6fa4a8c877dd66f77bbc95b54e6177a16d83cfcb8f5455ff0052cd76a8700e3b72a19c76f23ba61d2b2379487ce4f65b44f53ce9370e4f28494eec872eba4da130f93795a9c844733e9a5dcd396fc22a68e2b8b3270d720a4735a394cb267ee05a7848c538cb1b7a401207ba1259369c38a31f7189916d38de547cf0f58ef7762b4447d5cd6e4a5399809e8e15d74790b99eb83ce0aeb8e5bc2724848e534784111d1648d7070e4aa06acb2c8d73a4634e168db06cdd94155d2c75ac313da39e167963b69865a60925408ab031e3072a74b7a94ed70f84f6b7d1d2d355f5a0612339e126df0ba3b6912f0e03dd71f24d3b38f3d809e1fc82e1dd37413097319ee88ea6e81cd2a12299d4d5d9270095834a986131cd8f645cf14551112d03721deddcc128f744527a482eeca3771c97a9605b65554515506bf3b32acb5375a68e10f6f7c267cad354c7c603926974f99e4c3cfa3eebaf1e7b23932f8f2d3126ab6ba02c87ebf655c9eb6e9513973f7ed255b2b74b53c041871b91d6db54022c4cd195197c86987c68a5b2827a8197177ef47d2518a7c023956b9adb1467f2c0c28faca3f502d0b0bcd6d6f38a40d0d199a56e07bad7347d2b21b7fab1d966f401b13db957ab5dd04547b5a57365ee4db5e1eb8381ad1b7e54ac4de9d2ef3c70a16949aba9c9e7952976a914b45b7ecbd9f8b3c795cff682b9541ac9c44d39e54edbe16dbedb239dc12156ac83ccd76e77232ac5a8ea0414cd8d9ee1745beb191056c6f5eb257bbb64a919e4c1c040d0110b0bbdca7d8eea39321113891844454a644cc5190e4fd4d7b2860249c1c20c15e2b594d1f49a7d478405a69dcd71967e7776ca1210fba56991c4ed072a74398e8b67036041189a614e097fee41c14725c6a04e73d26a",
            "4ce1f70a91180768382a5e373686214edc60f7419f64ed6b4430000762a5a8281980feee50b4f16c9323dcab0524e2260f94893f6c023c0c72a7c49b9801eca0ecf1ee3d47f6535110f38f6424b031c85e04b8e09e10770b8c7440fa821e86ecdaa76014caa58b06785c3c149eaed08496b007f7411bb9372a2ded01a8daba8ea041bf908540e42e009cc24a0dcec1154d8032857764ec6fdac4c51eeacd8dc65435c6b9c41e576695c495155b270729508ea994b9fb8a6a8c3aa2b98005d979c946d998d32f51a3903282be03d5f93088378190a0a86ceff2d96bdb959ff8c3adae1417ef2f4ef7019eca96cf1175146cdad91e02cf228df63a0941c17b51f4d412647e6371faaf9fa1f116fc1b97caecaf3fc4ebfb386ccefe2a7aed5db4fa6692958c037cac1fbd496ea08222f9668f68efcaf91ea3c4dd5127d13bff008a8f975e6b0aa3d375449b0fdd3e83bbeb3add5ba6a8c12e99991f7550bff8d168b6c6f144f69705f3fc55b72a869f3533ce7bf282aba66ca792efe28e85dd6ad5be2e5d2f723994ef7004fb2a73d93d69ead4c8e2e3f2bd1d2361e5a52def91c4009cc51967b1b430c710e709eaa6991876f64c534323b19528200d8092ab499509451b993e0f6562a68738e157e37915fb476cab55033202470a6d3f3d915153e06538c8c6518c8874c9c236615803bd29c6c3b7d908d9c36ab62979580421d8f64e9c00230e98047ba9f7c5b40c20a277e6e54a40f070a2ae1a803a9db82bb2ce1fdd14f0cda493850970a96c44ed282caec475769c829d8ee0583195002bc976094435e5e32b4c1cf9e29e86e44bbba34579c775598242d76729f7d7ec38cad74e6c9668ab4c8007394bd05e5d000dddc2a6d35687b78288a6ae2e9707380a32c15326874d7696420eef4a3dfa8a3a6661aff52a054ea365241b18ef52068aeef9a4df2bc819f758dc139722fd515cfae6ef71561b2e26a4d9ef85453758db441cc39567d11736d67a73caceb5e1cb74fd4ff46a92112d8fab039df648bb438ab24844da009a3734a8af4b1be2ad2c3bab76f6e54fd05edb67a96367feaf1ce7b285bcc6fa3afded1c6539a9a85d5da4e4ab833d66b72309c2cbe8ef89ba3a2d476875dadd8738373e95f3355be7a0ac7d3d435cd7076395bb782fe25b25ab934ede241c92c01e80f1bbc2f02adf72b6c598c8dd9685b71b8b9231691ae906e694b86468043bd9050c93d1cee8271839c72972641c83dd6f8b1b0f39fd4771d826e57e061bdd0ee91f1b80009ca321630b77bcad244d0387b8fafb2eba46c630d4e564ec3e96a8f91c63697128495306c67ab21fb84f5badf71d4076d146fda3844e93d295fabae0d606b8440f24adf34ee97b6e94a36c2d8d865039384ae434bf42d0010ba602794f451277a7c2c9ea691d347818413998772a5a788a0248ce5000b9af0f273e9f85e7381c63ba76669010e4e114a3d51053d647b676027f4546d4d619236b9d4cdcb7e02ba3e5c70970089c712b4381f658e7c72fdb5c32b3e9864d5325248639632dfd428cad7099e1cc23be56d5ab74452dde95d2d2b035f8cf0163771b0d65a2a9cc99ae0dcf72163f8716d39724ad15ce29691b03b870f75d35059c03955e90bd9ea8d3b0dc8c780feeb3cb8e6da63c953d4f592b24077602998ef0e11e049caa69afea7d3c2f36a260787151962d266ba4174903f323f7235b720f39055322ae701827946435c40eeb2b846b392adc6e008c6574554728edcaadc75a484453559254f59b3efb4a3cef77a4e14ddb27774c3725559d525ae182ac1637f51ed0a6e136ab7c5cec309dfb9dfaa0b545ddb24de5580e7b292eab68e9039a7070abc6315b53d5239caf53e3cd4797cdf692d376e78fcc27ee9ed453e5cd61e7088a1dd4d11c1c0c287b8ce279b9ee0ae9b232b751eeb06300f945d177cf751f905a07ba91a002166f93b048a5d8e96b23a18baafe78ecab770ae75f24d9165a13972ad35551d26f2dca5434a206073460a424a22d74fe599b09da47ba455cb24d308e9c1e4f242e4b23a70d634ed776254a504105be02f9087bc846d5a762859430027991c12181d21dce1cfb2f44e6544a4bdc",
            "30a4e186070e1c12d919a669c8ca96a38f905c784d4548c71f4908a6d2b9a38ca254d4e5156b6101b9e11559798e9a2cb4f2ab859231a5d93c288acba1738c64ab900abade1f5d2ed6b8f75276073e1c120aae515219a5ea03c2b65b64646d0c737f7a2c82c8949ae61980504fa8323b72e5486e7e532d282d1f32ee5dea64613412b03195343ddd7b6a6f77295b906e96a6dcfdbc2eb9c532f77ca63edc92a1ad1c850d5f3090fa784654c8002a2e576e7229c343869ca97b4d2eca774ffd900a8b2dcb4a949e7fc3f4ccf3938c34a49c9f35f8a553157eb6e9e3b394357d3454c7007b276fd3fe25a8e4ab1ced7774d57b8cd2a9b1111ee8cb86414c16e5fb54898b6b1371d36e76ec273c149650e1a1f94e4507c14460e03579a0b5d846cb4f474b2487eae13359074473dd49440b3940dc9db90348be9b9dce784b89a378052e3196a7608374811b2d24a960dcd04224d3b9cc2d4aa588b58113b0b5b946cf4af490361a9e7be558add19e987284ae61eb077dd4ddb9dfd1c20f4948e2ec518d0042efba12271da13cf7e222525695cab9bcad7871ed95656d436b291a5bc602aa5d087ca5df0a52c758258b603f64c85c7116a7e1ab113b042f3da5a9b747c6ec29394babaa2e69dbc285a88df3924b91f50ef4a11a7948c23691dbc23e27ecc4447252e28b2729c318dd9f7558e553963b845586d053f5dee18ef8505f8b32b9c7a67b21f57dc26640636938f8554b4564b148776464ada5ae4e4c62ed47a876d4797da78f7537537a86080160cbc855289d1463adb46e3ee8eb7113bb7cbf4845aca44d5017566679890d1ec531535cfa99fa14c48e7190a2ee379e9bc53d39c03f08ca2db4b0f5dff51e54232c56537136ab56c9cee7632ac3e106a8657ddba183dd6615f78359196939014a7839736d36ab0ded972cf2c637e2923e8ed4d1e24cb78e12ac346e95adda7ba7350377d2b661eed09ed22ecbd8d3eeb1b1e8e37c43eb0a014b1973bba1f4b5632ba9df4328cb1c08e5597c45b7b8c01cc1c10a8563aa14559f184a2afac2fc53b655e84d78dbad197363ea6e1b4fdd7d23e15ebeb5f8ada6c5b2a8b595019b72eef9541f1b34a7e2d6375cf6efc373d9617a1357d7e8eb8324a52e8c7539c15b617c72e53df5acf8c9e114da76b1f5303731e776e016450efa87f47b39a7057d9169b9d078b1a3842e95b25674f919c9ecbe6ad79a2aa7465ca773a32d68271c2d3b699dc5539fa748035f82e28296a1f9c34f09a6549ac7b9d21e4764b798d8deb3ce0355cceb1a1a790c23738f27d959b46e83add5b3b1f82d881c9507a72cb57ab6f71c313098b77271c2fa66d56aa4d256164116d6cfb79c7755b1d5156eb452e9ba56d25231ad9da3d4e013f2d4197fac3977ba624a832b8cae3ea29974b929693b6a9084f866421a22422a33c287a86268b8414d0e39c2957b43821a68f840a84a88ce3b20a48c85315119f8404acc77096ca2324695c8b0dfa8e1152463be1033c6e7f038535506c352637707737e1456a5b0d3df29dc5b186bff0044442f30fa5dd911d5f7694b4a6357bd373db1c5a633b73df0abb35273970c2fa0aed6ca6bad2105a37ac975569e9a9243d361da3e1659e3eaa64aa066cec9f866c7d41719098c61e0e7eeb840ca8b8ae6474c837653f1ce07ba00e414a63f9e0acb2c5a4c93314e31dd194f38cf70a0e3931dd131cfb4f0563715e3927e376fe558ec126d209f6551a19b76012acb6d9034800a89e56f3e9687dc1d31116728aa3883084053538da25f752d4203f1f2bd0e1e48e0e6c7d173c823a73fa2acba52ea871f65377d97a3006b4f2a16958d7465cf382ba9ce26105fea1d824575cb23a519e7b26609e466f601c26ba0d12f51ddd2aa82e869486f51fdd1f1bd8f25a4a4d0b5f52d0d60e133709e96d597cf23411ca47da4475cea2a6865dc59867b143baeb5724796e5c156b59f8914f3c269e98b4b9bf083d0bae62a99bcbd76d009c0ca69efb5b22bbd4e4800e5131deaae3e465395b460344f4c1ae63b9e10ac90118da3211551211eaeae80f0d251b06bfaa180f6150a1dc72d092f8c3c6400889ab3b75d7506d77194ba6a88",
            "6ba5de5c325532481a4f7e575b553d2e0c2e27095cb4262d6ad94af8da0b0642966b4b7970c2cc6c3e231a07b63ac200fbad12d7aaad17863712b013f759de43b80b2eddef95eec9f7d30906ea62d7350f243347f505a6396e235a2b785c320c7742c9306f729a3367dd5c2181e3295bc20c4a3d8a57571dca60fb9fca1e7940cf29265284a9973c03ca421aa9972856f2529ee24f2bcc1c709559d859be56b31dd03e23dc5b6cd27343b80739a54a5b06fb844df6541f1f2e2da6d94ac70f50ec933c98b5b9bd564f2bbb97129622dd26e29742d1152b87b94b230cca490d37d5809f863c332426610e965e4708e99a191e077400a1beb4e887d40a60176e46d382eee80539bb59950d5aedce53d500088aaf5411d42804c4cca92a283242061c93c299b7b3b65006c71ed00271edc31288c61726e2228081ae1ea5296e38a70a2ae0e0d6928ba095c69c6106b042ecb02ed43f10bbf442c12fa024d64d881dfa206d0b31eb093ec9bb1d5182afa6e3ee956e7099ef07df281989a5bb307619405f5ee0f008497636e12299ec92269047648964daec293862719430610e4fb9fb9c94d8c921233b037d2952c5d36179ed84fc118e176f2f8e0b6bcb880709e27bf19edf6a639ea8b0e144cf146c036610f70a82fad7b9a7d394cf98739d8f65bc71f225619cba30d2780973dd8c11f4d87ba8e13ed6e10fbc3e4c94544898a121cfeb48727bf28ca8baba51d30700285136d0002bce970320a9d0ca242293f336e7ba2f46d6fe19a9e2989c02e5094f53f99929babab7d1d541334e06eeea72878cd57db51cedb8e9b82569ce5813b6369a69622140787b58db8689a5735c1ced815c2d74a642081d97364ebc6ac37aa165cacce7119706ac3ee503e8a794f6c15bcd2bfa94ae83e461643af28cd35798c34e1c5436c2fe86450c5a8b494b4720cbb615f256a7a56da3554f6f2cc3438e17d4ba46b7a55a695c7d2e6e1629e3f69075a6f2ebc46c3b5c7395bf130e6885f0d7c48aef0eb5146f925269a47004678017d517fd376bf1774bb2e543b1d339b9763e70be20762eb45bdd86bdbd8ad6bf67ef1a6a7455c9b68ba485d49290d1b8f65a54455bc40d0b53a66ba4e931c1b193bb0156ac162b86adae652411bb6679202fb43c45d176bd656375cad619275dbb9db79598689d3f45a3e695ce881901f70962cf3c7f8234668ba2d0b40d32b1a6a08cf2395cbc553aa66ea97f1f08dbc5c1d72a8ea67007b2aed44fbea0c64f65d18b1fa3fd405b9ca4978429970eda0f0bbd51f29e8b4d99a02798838a4dc9f63cac5ea09c0497303861703b85e0ec77400f3538c7651f514ddf852d23c108398651a242494e7286922dbeca69f182829a0c941ed0d337e534d7ececa42a299012c65a52394ec536d39ca1ee36d86e51905a37240710e4ec3542270254dc767b66da8f49cb4ae748c61c0552929de1c4104616ff00530417580b0b464859eea3d25e5dce922e02cf2c552b3d73083b4af6033ba2aae99d0ca5a4f210ce89ce2b2b8b49490f2e3c22a3f4f250bc4694262e53963e2f696a69b0460ab15aea0970c9552a7908214e5baa0b5c173e583a38f2f1a0dbeab7461a4f0a6a958e0d2f62a5d057ed20156ba2afdd006b544cfad567c7d91975af7f98d9267baeb69e7958d919f40eea52aadd0d5c7b88f5af5b2965a324ca77423b85ddc5cf2fdb87938ac05ba2a8c45003bc7051b0db5b4cceb563da18067940df7c41d3f62059153b7adee7eeb2fd4de215cef6e7474af2c88fb05d1db7eb9aee2fda87c47b559e374346f69900c70b29bfeacb9dee571dee0c2544c948e738cb52e739e79e5272e3c46784d9da68d2b07adef25c7be532f6be178960716b9bf09f24f6290c9031c73d9342f5a1bc48d8e6d05c5dc76f52d30db1b5708aea47874279385f3756c4d7fe6c04b641d88570f0f3c59abb1d4b2df72fcca773b6f29e9a4cdab7a6525ac18c709a90c909da41c29c96920bd5036e16d6f4da464808288c6f88c528cbfe50b951ce63646e5bdd3043a2ee8930ba198907d287ab76e69c2e7e5cb4eae3c7681bd44c9ddc3b07ec87b7d657db9c3a12bb1faaf56ef33774444d",
            "718f23bae3bc8ea9c4b7d9bc50aeb644239dc4ab1d0f8b7493e054387ef5951a51267aa49425551c6dfa09055e3cacf2e0f5be53eacb4dc40d92372515d48e66e6291a72be6f8eaebe85dba195c00fba94a6d7d75a421a64270b7c3998e5c2dcfa552c25dbb2171b56f2edaecacba87c5c969f6b6a46e0ac147e2f5a24203e06ee2b7c739586582ede65bf4fba1662f0f2ecf098a4d45457c881a58c35c7e17667be21b5fcabda24d3a1c64723228c36339ef843d3b9ae6e4044461ce2421432cd0637549ecce72b00f1aaeefb8ea26b5aecb5a70be8692516dd3357311c869c2f952eb52fbf5f277b89f4bce3f8a4cf233165c5ad1f0889f11c61a7ba724a6f2643cfc20659bcd49c76ca553045306b46e5d91e1c7949dbb1984d39d8403ec6b0944c5b5a7eca344e027055fa500f5c2a3008078504fdd249c222aea0b9334dea720246829f38c852d4ecda7841d210d08e85deae1020d001c24556046574483087ac9f0c210680b8679f85236a03cb851b5677b4a91b68db4e10122c3829ab81fc972eb1dcae568cc250485b50779b207cae6a187a752c900e5136b8b6d567ee88d4f4ff00941e3e1004d8ea9ce806e3ec8c73c97f2abf62ab22220fe8a6d8fde32a550b6f2e523044d737b28f637d40a95a4186f2919c829dc6507d956fc41ab7b29cc511f656f8e511c2e763b2cd7565c8cf5fd3f655833e5cb514c6c6f11b8bfea486c81839ee89ba3ba2ec0f741c30baa0adf1735cbf6e995cf3c250dc067dd194d4001e539514818d2422c47647b657653bd4e3ba19f90f202e3dc4052d31a2b3b46e05377699b25342077050ee9dc1b85d0cf30ce7d86515a47d3ffb3c5f7cfd9a3a291f9dadc616f3626b1934ad38edc2f8fbf672d40fa3d44ea37e4b48c85f575b6bfa552643d9d85cbc9355ae3168a68ba32389ec555f59d84570350d6e481956192e6cc34e384fbe48ab694b368e42c17bb1830eadb6e7bb0460e14af8a3a6e3d57a2cbc303a46b33c29dd5da57d2e9a33839cf098d215c2b1b35a6a407646de56dc5969571dc7c59d375b6e52503c11b1e472bd5d11aa99af87d3237b615ebc73d0b2e96d4b357467f2a57e40f855bb2c0c9618e7c7a8ae8fbf63933de35b9f801e25d65ae36596f8f2e8e4f4b77ad2b5ee8bcc1f89dbfd513fd476af9c6967c013b0e268f1b485ba7851e2bb6ae8ff0006bcb04b91b5a5c9cc0b1ce55325aa7b237370439bc72a2659c97177f6d6a3ae343b0b8d7d17a2277ab016595b432534ee7977195732d272c77f4f098fb9e529b238fba07ad872222932168cf495fc6aeaded72ad1fa4eefe6b86fb771dae95e3ff987ff0034396a496ae57a620dfef23ff7b5c3fd61ff00cd21da82f5ff003bdc3fd65ffcd0c5a9b7352310ed437aff009dee1feb2ffe69b76a0bcffced70ff00587ff34339a9b7048cfbaff78ff9dabffd61ff00cd36ebf5e3deeb5ffeb0ff00e687704db824043af9763dee75c7fcfbbf9a69d78b91ef70ab3faccefe6987048296ccf9badc33ff000eaaff004aefe6b86e95e7bd7551ff003aefe6872b896c0c65e6e51fd171ac6fe93387fbd724ba57ce312d6d4c83fe94ae3fef422e8290d3ae8a390e5ec6b8fc9194a6d3c1ff00f0c7ff00d217014b6941bc28e95dde9a03fab0271b43483ff6583fd185e694e34a60a6d1d28ffd9a1ffe809f6410b7e98a31fa3426da53ad28d41ba7d8437b003f444b2aa767d3348dfd1c420da538d727d67f0bb5fe8e6dc6affe553ffa429cfc46b1cd2d357505a7d8c871fde81052c395493f856d373db282b1dbaa68696677cc9135c7fda17a3b3db23fa2dd46dfd2168ff727c14a0e55114d3ad36e93eba0a477eb0b4ffb971b65b50ed6ca21fe61bfc9100a5872a2d05fc0ed27ff007650ff00a06ff25d161b39ff00dd541feaecfe48b0528141682374fd9876b4dbff00d5d9fc973fc97b0176f363b5976739f2b1e7fb91c0a58298d08a69e5a387a14d2be087b74e3716b7f80e17877ddeff0029a052da500ef0eefcfeabc2188f78d87f56849694e028d43dd23c851b8e5d494e4fde309c6d0d201c53403fcd84a052c14bacfe0ed97f48f23487ff006583fd185efc",
            "3684f7a2a63fac4dfe49e052814759fc1db2fe9836ab79ef434a7fcd37f9241b25a8f7b6509fd606ff00245e57728eb3f83b5fe81769fb3bfeab4dbcfeb4ecfe4b834f595a72db45bc1fb53b3f923f2924a7a85bae53b1945ff056360ffb21b7fb939255cf27d73caefd5e4a689487390477ce5437e99e568fb3ca49b95637b55d40fd2429873934e72404cd76af961741256d4be27778dd2b8b4feeca85fc2adb1bcbd96fa46b8f25c216827fd88b73932f7a083cb4344f187d253b87de307fdc8736bb733e9a0a41fa42dfe48a7bd32f7a403be868bfe494ff00e8dbfc930fa0a1ff0091d37fa26ff2443de997bd201dd6fa1ff91d37fa26ff0024d3a86887fec94ffe8c7f24fb9e9973d0661f41427bd1d37fa26ff24d9a1a36fd3494e3f48c279cf4d39e8220c300ed0c63f46849218decc68fd02f39e9b73d00a2e09a7ed777683fa85c2f482e4071d0c27bc519ff00c217406b061ad6b47d824972e6e4039b974bb70c3b91f74cee5ddc823ac6b1872d635a7e404e3f6cc3128120f870ca1c392c3900e454f4f1fd1044dfd18027dbb476681fb90e1c96d7a6429a47c04fb2570ece23f7a09af4e35e901cd99c460b8e0fb6532eb75be67ef968695eeff8ce89a4ff0072435e9c6c882ae3acb6997facb5d0bffeb40c3fee4e4764b433e9b55037f4a760ff0072eb644e3644d3a8f36d36b1ff00bba8bfd037f9251b45addc1b6d11fd606ff25d12258910350cff0093f652726cf6eff5667f25dff27ec87ff73dbbfd599fc93e1e95bd2014e9db19ff00dcd6dff5667f25c1a7ecadfa6d16e1fa5333f922f7fdd78bd00cd0dba82d5375edf454d472ff00fc94f136377f1002943a86ee3b5d6bc7e950ff00e6a3cb921ce48249faa2fb8fff007ab9ff00ad3ff9a47f95fa899f45feecdfd2ae41fef518e7265c51a85ba929f566a098625bedd1e0fb3aae43fef40477cba534a6582e55b1487fb6c9dcd77f1050ee2997955241bae5e2aea2fb8fc5a796e18ff953ccbfff00aca8c6d152c2ddb153411b4760d60011cf4c3d389a1cb4307a406fe8b91544d4b28969e592190767c6e2d23f784b784cbc2a4a466d63a9658ba526a1bc3e3edb1d59211fc3728d96e75f2e77d7553ffeb4ae3fef4db826dc13278d5d4ffca25ffeb293e7aadbdaaa71fa4857084821326945a9b2d4416a439ab27a21dcd4db9a8873536e6a40339a9a7044b9a9a7354986704d38225c132e091982136427dc134e0919b21252c848291bcbcbcbc907414b0536940a0cf0296d299694e34a08fb4a71a530d29c694c1f694e35c986b938d72647c14b6b9301c961caa24f82941c990528395153e1c941c990e4a0e4c8f072502990e4b0e4c8f072587260392c3900f82960a60392c393021a52da530d7271ae481f052c14c35c961c823e0a502990e4a0e4c1dcaf65232bd9402c9492e492e5c2e413a4a6dce5e73936e72038e7269ce5d73932f7241c7b932f72f3dc997bd04e3de987bd79ef4cbde9079ef4c3debcf7a61ef4075ef4cb9eb8f7a65cf4029cf4d39e92e7a69cf4029cf4db9e92e7241720145e925c905c925c805972e6e48dcb9b9047372f6e4dee5ddc8074392839300a507201f0e4b0e43872587208407a703d0a1e961e8216d7a71b220daf4b0f410c6c89c12208489c12200c122589106244b122086091284884122587a009dff75edff74c07aeef481d2e492e48dcb85c80eb8a6dc57494db8a088714db92dc536e4e11a7265c9e7269ca88cb8265c13ee09b704e11821364279cd48213499212484f10925a9934b2d487353c42416ac9e81873536e6a21cd4db9a918673534f6a25c134e0900ae6a69cd44bda997049419c136e09f704d3829332e0904275c136424642f2f15c2907574149cae841960a5829b05281403cd296d726414b69411f694e0298694b0e5508fb5c961c980e4b0e4e11f0e4a0e4c0725072a49f0e4a0e4c0725872a23e1c941c980e4a0e4c8407258721c392c390040725b5c876b92dae4012d7271ae4335c9c6b900407270390ed72587201f0e4a0e4c872507201ddcbbb935b97b77dd00e17249724172497208a73936e72e1726dce413ce7265ee5d73932",
            "f72012f7261ef5d7b930f720897bd30f7aebde987bd01c7bd32f7af3de987bd01e7bd34e7ae3de9a73d2275ce4d39cb8e726dce4028b920b924b920b900b2e492524b9272805e57b29195cca01ccaf65232bd940380ae8726c3974390474392839320ae872647c39743d33b9743920203d2c3d0c1e941e990a0f4b0f4207a587a08587a587a103d2c3d00587a587a15af4b6bd20283d743fee870f4b0e403db97b726c397b280592924ae657101c290528a49411a726dc13ce09b215119704d909e704821389a65c12084f1092426464b524b53c5a925a9934a2120b53c42490b3779873536e6a7dc136e6a40339a9a73512e0997b5230ee09878453c265e12a619ed4cb8225e132f0a4c3b826dc13ce09a704a99b212138520a9325772b8bc832814a052174140380a5829a05281411e0e4b0e4c82961c9c14f0725872603928395269f0e5d0e4c8725072a2a78392839301c941c9c49f0e4b0e4387a507264203d2c390e1c941c98121c9c6bd0cd725b5e8029af4e35e856bd2daf4b60535e9c0f4287a703d06243d283d0c1e961c807f72f6e4cef5dddf7411c2e492e482e492e4c14e726dce5c73934e7209e7b932f72ebdc997b9044bdc877b92dee4c3dc8221ee4c3dc94f7261ee4025ee4c3dc94f7261ee4138e7265ce5d73934e7203ce726cb971ce482e483a5c924a4972e6500adcb9b9272b99402b72f65272bb9402b2bd9495e402f2bb948caf6504732bbb93795edc991cdcba1c9acaf6e411e0e4a0f4c6e5d0e40101e941e870e5d0f41090f4e07a143d2daf4014d7a71af42b5e9c6b900507a58721dae4e35c903e1c9594c87258280732bd9495eca03a524aeaf20882121c138424909c068848213a42490a92648492d4e96a490991adab85a9d2d5cda99348212484e909042876992136e09f704db82461dc134f088704d3c240338265c110f0997848c33c265e112f0987852a0ee09a704fbc269c9199290538eee9b7293257174a4a46eaea4af6500b052814da502807014a0e4d02940a6474392814d02ba0a69a783974393595d0e5454f072e872672941ca9274392c39301cba1c99080e4b0e4387250720090e4b0f4307271ae41896b938d7215ae4e35c9012d7270390cd7258720090f4a0e4387250720080e5edc990e5ddc807772497246e492e4c8a73936e72f39c9b73901c73932f72539c997b93490f721dee4e3dc98794036f721dee4e3ca61e50443dc987b92de530f28225ce4d38a538a69c501c714d92bae2904a03c4ae12b995c40772bd95ccaf6501dcaf6571792056577292bd94c1795eca4af65045657b29395cca08acaf652095cca08e6577726f2bdb904737250726772502983c1c9c6b90e1c96d72404b5c9c6b90cd7275a5004b5c9d6b90cd7275a500402960a65a538d2903a0a526c258407579782ea61c49212885c4110424109d2124855134d1092427085c21323642e612c85ec261a390904270a4150ec36426dc13ce09b704030e09a704fb8269c1230ef0987844bc261e14987784c3c221e132f09187784cb827de132f0a4ccb936e4eb934e4aa88292528a41526f2f2f2e650456574148caea0cb052814d82940a708bcaee5232bd9e5323995d05232bc0aa49cca50726b2ba1c9a4e072507268397414c8f07258726014b05307c392c39301c96d72467dae4e35c876b938d724621ae4e0721dae4e07201f0e4a0e4c87250280783977726839777201cdc924a4ee5c253274b936e2bc4a438a644b8a65e52dc534e2991b794c3ca71e530f28234f298794ebca61e50469e532f29c794cbca08db8a69c52dc536e280492904aeb8a49280e65732bd95cca03b95ecae657b28052ee5257501d5e5e0bc907979797932797895e5c28278949caf1292822b2bd9495cca645e57414de5741403a0a5b4a6414e34a08fb4a75a50ed29d6948c434a79a50ec29e61403ed29c694cb4a75a903a12c26da9c6a0141770b8129103985cc252f61304617084b2125389a410924259092a889212484e10b84264ffd9",
        }),
        up = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003012200021101031101ffc4001500010100000000000000000000000000000006ffc40014100100000000000000000000000000000000ffc4001501010100000000000000000000000000000004ffc40014110100000000000000000000000000000000ffda000c03010002110311003f00a4012a90000000000000000000000000000000000000000000007fffd9",
        }),
        dn = table.concat({
            "ffd8ffe000104a46494600010100000100010000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc00011080040004003012200021101031101ffc4001500010100000000000000000000000000000006ffc40014100100000000000000000000000000000000ffc4001501010100000000000000000000000000000003ffc40014110100000000000000000000000000000000ffda000c03010002110311003f008f01158000000000000000000000000000000000000000000001ffd9",
        }),
    },
}

    local NAMES = {"femboy", "silly cat", "sakura", "tung tung sahur"}
    local KEYS = {"Sukharik", "WhiteCat", "SakuraPhoto", "AnimeMask"}
    L.skyNames = NAMES
    L.skyMethods = {"Sky object", "Dome (fallback)"}

    local assetFn = getcustomasset or getsynasset

    local function report(msg)
        Notify(msg)
        if L.skyLog then pcall(L.skyLog, msg) end
    end

    local function ensureFolder(path)
        pcall(function()
            if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(path) then makefolder(path) end
        end)
    end
    local function toBin(hex)
        return (hex:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))
    end

    local sky, created, orig
    local applied          -- {Bk, Ft, Lf, Rt, Up, Dn} — то, что мы сейчас держим на небе
    local atmo, clouds = {}, nil
    local acc = 0
    local dome, domeWalls = nil, nil

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

    -- прячем то, что перекрывает небо: атмосфера (дымка), облака
    local function hideOverlays(on)
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                if on then
                    if not atmo[a] then atmo[a] = {a.Density, a.Haze, a.Glare, a.Offset} end
                    a.Density, a.Haze, a.Glare = 0, 0, 0
                elseif atmo[a] then
                    a.Density, a.Haze, a.Glare, a.Offset = atmo[a][1], atmo[a][2], atmo[a][3], atmo[a][4]
                end
            end
        end
        local terr = workspace:FindFirstChildOfClass("Terrain")
        local cl = terr and terr:FindFirstChildOfClass("Clouds")
        if cl then
            if on then
                if clouds == nil then clouds = cl.Enabled end
                cl.Enabled = false
            elseif clouds ~= nil then
                cl.Enabled = clouds
            end
        end
        if not on then atmo, clouds = {}, nil end
    end

    -- выставляем грани на ВСЕ Sky в Lighting (игра может держать несколько)
    local function pushFaces()
        if not applied then return end
        local sk = ensureSky()
        local function setOne(x)
            if x.SkyboxBk ~= applied[1] then x.SkyboxBk = applied[1] end
            if x.SkyboxFt ~= applied[2] then x.SkyboxFt = applied[2] end
            if x.SkyboxLf ~= applied[3] then x.SkyboxLf = applied[3] end
            if x.SkyboxRt ~= applied[4] then x.SkyboxRt = applied[4] end
            if x.SkyboxUp ~= applied[5] then x.SkyboxUp = applied[5] end
            if x.SkyboxDn ~= applied[6] then x.SkyboxDn = applied[6] end
            if cfg.skyHideBodies then
                if x.CelestialBodiesShown then x.CelestialBodiesShown = false end
                if x.StarCount ~= 0 then x.StarCount = 0 end
            elseif orig then
                x.CelestialBodiesShown = orig.Bodies
                x.StarCount = orig.Stars
            end
        end
        setOne(sk)
        for _, c in ipairs(Lighting:GetChildren()) do
            if c:IsA("Sky") and c ~= sk then setOne(c) end
        end
        hideOverlays(cfg.skyHideBodies)
    end

    -- запасной способ: куб из 6 стен вокруг камеры, на каждой картинка (не зависит от Lighting.Sky)
    local DIST = 1000
    local WALLS = {
        {Vector3.new(DIST, 0, 0),  Enum.NormalId.Left,   4},
        {Vector3.new(-DIST, 0, 0), Enum.NormalId.Right,  3},
        {Vector3.new(0, 0, DIST),  Enum.NormalId.Front,  1},
        {Vector3.new(0, 0, -DIST), Enum.NormalId.Back,   2},
        {Vector3.new(0, DIST, 0),  Enum.NormalId.Bottom, 5},
        {Vector3.new(0, -DIST, 0), Enum.NormalId.Top,    6},
    }
    local function domeDestroy()
        if dome then dome:Destroy() end
        dome, domeWalls = nil, nil
    end
    local function domeBuild()
        domeDestroy()
        local cam = workspace.CurrentCamera
        if not (cam and applied) then return end
        dome = new("Model", {Name = "ScorpionDome", Parent = cam})
        domeWalls = {}
        for _, w in ipairs(WALLS) do
            local big = (w[1].X ~= 0) and Vector3.new(1, 2048, 2048) or (w[1].Y ~= 0) and Vector3.new(2048, 1, 2048) or Vector3.new(2048, 2048, 1)
            local part = new("Part", {
                Name = "Wall", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
                Size = big, Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic, Parent = dome,
            })
            local sg = new("SurfaceGui", {
                Face = w[2], LightInfluence = 0, Brightness = 1, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
                CanvasSize = Vector2.new(512, 512), ClipsDescendants = true, Parent = part,
            })
            new("ImageLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = applied[w[3]], Parent = sg})
            domeWalls[#domeWalls + 1] = {part = part, off = w[1]}
        end
    end
    local function domeFollow()
        local cam = workspace.CurrentCamera
        if not (cam and domeWalls) then return end
        local p = cam.CFrame.Position
        for _, w in ipairs(domeWalls) do
            if w.part.Parent then w.part.CFrame = CFrame.new(p + w.off) end
        end
    end
    local DOME_STEP = "ScorpionDome"
    RunService:BindToRenderStep(DOME_STEP, Enum.RenderPriority.Last.Value + 2, function()
        if not unloaded and dome then domeFollow() end
    end)

    -- что именно держим сейчас: Sky или Dome
    local function refresh()
        if not applied then return end
        if cfg.skyMethod == 2 then
            if not (dome and dome.Parent) then domeBuild() end
            domeFollow()
            hideOverlays(cfg.skyHideBodies)
        else
            if dome then domeDestroy() end
            pushFaces()
        end
    end
    L.skyRefresh = function() pcall(refresh) end

    local function setFaces(bk, ft, lf, rt, up, dn)
        applied = {bk, ft, lf, rt, up, dn}
        if dome then domeDestroy() end
        pcall(refresh)
    end

    -- игра может сбросить небо / пересоздать Sky — держим наше
    bind(RunService.Heartbeat, function(dt)
        if unloaded or not applied then return end
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        pcall(refresh)
    end)

    local function caps()
        local function f(n, v) return n .. "=" .. (typeof(v) == "function" and "ok" or "NO") end
        return table.concat({f("writefile", writefile), f("readfile", readfile), f("isfile", isfile),
            f("makefolder", makefolder), f("getcustomasset", getcustomasset), f("getsynasset", getsynasset)}, "  ")
    end

    local function supported()
        if typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(assetFn) == "function" then return true end
        report("no file/asset support: " .. caps())
        return false
    end

    -- записать картинку в workspace (плоское имя, без папок) и проверить, что записалась целиком
    local function putFile(name, hex)
        local want = #hex // 2
        local have = -1
        if typeof(isfile) == "function" and isfile(name) then
            local okR, d = pcall(readfile, name)
            have = okR and #d or -1
        end
        if have ~= want then
            writefile(name, toBin(hex))
            local d = readfile(name)
            if #d ~= want then error("file write corrupted " .. #d .. "/" .. want) end
        end
        local id = assetFn(name)
        if type(id) ~= "string" or id == "" then error("getcustomasset returned " .. tostring(id)) end
        return id
    end

    function L.skyApply()
        if not supported() then return end
        local key = KEYS[cfg.skyPreset] or KEYS[1]
        local data = SKY_DATA[key]
        if not data then return end
        local ok, err = pcall(function()
            local ids = {}
            for kind, hex in pairs(data) do
                ids[kind] = putFile("scorpion_sky_" .. key .. "_" .. kind .. "_v4.jpg", hex)
            end
            setFaces(ids.side, ids.side, ids.side, ids.side, ids.up, ids.dn)
        end)
        if ok then
            report("sky applied: " .. (NAMES[cfg.skyPreset] or key) .. (cfg.skyMethod == 2 and " (dome)" or ""))
        else
            report("sky failed: " .. tostring(err):sub(1, 90))
        end
    end

    -- кнопка «Test»: проверяет, умеет ли инжектор писать файлы и делать из них ассеты
    function L.skyTest()
        local lines = {caps()}
        local ok, err = pcall(function()
            local t = "scorpion_test.txt"
            writefile(t, "abc")
            lines[#lines + 1] = "write/read: " .. tostring(readfile(t))
            local id = assetFn and assetFn(t)
            lines[#lines + 1] = "asset: " .. tostring(id)
        end)
        if not ok then lines[#lines + 1] = "ERR: " .. tostring(err) end
        report(table.concat(lines, "\n"))
    end

    function L.skyRestore()
        applied = nil
        domeDestroy()
        pcall(hideOverlays, false)
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
        if st.sk ~= cfg.wcSparkDensity then
            st.sk = cfg.wcSparkDensity
            st.E.Rate = st.sk
        end
        if st.sc ~= color then
            st.sc = color
            st.E.Color = ColorSequence.new(W, color)
        end
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
            listT = 1.0
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
        local nLayer2, made = 0, 0
        for _, st in pairs(states) do if st.l2 then nLayer2 = nLayer2 + 1 end end
        local nowC = os.clock()
        local doAnim = nowC - (L.wcAnimAt or 0) > 0.06
        if doAnim then L.wcAnimAt = nowC end
        pcall(function()
        for part, st in pairs(states) do
            if part.Parent then
                local col = st.Color:Lerp(tintA, mix)
                local mat = style[3]
                if tex then
                    col = W:Lerp(tintA, 0.3)
                    if mat == Enum.Material.Neon or mat == Enum.Material.Glass then mat = Enum.Material.SmoothPlastic end
                end
                do
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
                end
                -- второй слой: движущаяся полупрозрачная текстура поверх основной
                if cfg.wcShimmer and tex2 and part.Size.Magnitude > 0.15 then
                    if not st.l2 then
                        if nLayer2 < 40 and made < 2 then
                            made = made + 1
                            nLayer2 = nLayer2 + 1
                            st.l2 = {}
                            pcall(function()
                                for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
                                    st.l2[#st.l2 + 1] = new("Texture", {Name = OVL, Texture = tex2, Face = face, StudsPerTileU = 2.6, StudsPerTileV = 2.6, Transparency = 0.45, Parent = part})
                                end
                            end)
                        end
                    elseif doAnim then
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
        end)

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
        L.lastShotAt = os.clock()
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
TabSet.Models = CreateTab("Weapons")
TabSet.ESP = CreateTab("ESP")
TabSet.Hitbox = CreateTab("Hitboxes")
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
    CreateHint(g, "Draw your own crosshair in the center of the screen.")
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
    CreateHint(rd, "A small top-down map of players near you.")
    CfgToggle(rd, "Enable radar", "radarEnabled")
    CfgSlider(rd, {Text = "Size", Min = 100, Max = 260, Step = 10}, "radarSize")
    CfgSlider(rd, {Text = "Range (studs)", Min = 50, Max = 600, Step = 10}, "radarRange")

    local dl = CreateGroup(TabSet.Visuals.Right, "Damage log")
    CreateHint(dl, "A small panel that shows how much damage you deal while shooting, and who you killed.")
    CfgToggle(dl, "Show damage log", "dlogEnabled")
    CfgDropdown(dl, {Text = "Position", Options = {"Right", "Left", "Under crosshair"}}, "dlogPos")
    CfgSlider(dl, {Text = "Keep rows for", Min = 1, Max = 10, Format = function(v) return v .. " s" end}, "dlogTime")
    CfgSlider(dl, {Text = "Max rows", Min = 1, Max = 8}, "dlogRows")

    local pi = CreateGroup(TabSet.Visuals.Right, "Player info")
    CreateHint(pi, "Rust-style info: who is nearby, what they hold, if they are reloading, and what they wear.")
    CfgToggle(pi, "Nearby players list", "infoNearby")
    CfgToggle(pi, "Target card", "infoTarget")
    CfgSlider(pi, {Text = "Range (studs)", Min = 50, Max = 1000, Step = 10}, "infoRange")
    CfgSlider(pi, {Text = "List rows", Min = 1, Max = 8}, "infoRows")

end

-- ESP (ESP слева, Chams справа)
do
    local e = CreateGroup(TabSet.ESP.Left, "ESP")
    CreateHint(e, "See players through walls: boxes, names and health.")
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
    CfgToggle(x, "Reload timer", "espReload")
    CfgToggle(x, "Wearing (clothes / armor)", "espWear")
    CfgToggle(x, "Visible check (green / red)", "visCheck")
    CfgToggle(x, "Offscreen arrows", "espArrows")
    CfgSlider(x, {Text = "Arrow radius", Min = 80, Max = 400, Step = 5}, "arrowRadius")
end

-- Hitbox
do
    local h = CreateGroup(TabSet.Hitbox.Left, "Hitbox expander")
    CreateHint(h, "Makes enemy heads and bodies bigger so your shots land more easily.")
    CfgToggle(h, "Enable hitbox", "hbEnabled", function(v)
        if not v then restoreHitboxes() end
    end)
    CfgDropdown(h, {Text = "Hitbox part", Options = {"Head", "Body", "Head + Body"}}, "hbPart")
    CfgSlider(h, {Text = "Hitbox size", Min = 2, Max = 30}, "hbSize")
    CfgSlider(h, {Text = "Hitbox transparency", Min = 0, Max = 100, Format = fmtPct}, "hbTransparency")

    local hv = CreateGroup(TabSet.Hitbox.Right, "Show hitboxes")
    CreateHint(hv, "Draws a colored box on every enemy so you can see exactly where the hitbox is.")
    CfgToggle(hv, "Show hitboxes", "hbShow", function(v)
        if not v then L.hbClearDraws() end
    end)
    CfgDropdown(hv, {Text = "Draw on", Options = {"Head", "Body", "Head + Body"}}, "hbDrawPart")
    CfgDropdown(hv, {Text = "Color", Options = ColorNames}, "hbColor")
    CfgSlider(hv, {Text = "Fill transparency", Min = 0, Max = 100, Format = fmtPct}, "hbFill")
    CfgToggle(hv, "Outline", "hbOutline")
    CfgToggle(hv, "Visible through walls", "hbThrough")
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
    CreateHint(g, "Locks onto the closest enemy inside your FOV circle. Fine-tune the feel on the right.")
    CfgToggle(g, "Enable aim", "aimEnabled")
    CfgDropdown(g, {Text = "Activation", Options = {"Always", "Hold right mouse", "Hold left mouse"}}, "aimMode")
    CfgDropdown(g, {Text = "Aim part", Options = {"Head", "Torso", "Closest"}}, "aimPart")
    CfgDropdown(g, {Text = "Target priority", Options = {"Closest to crosshair", "Closest distance"}}, "aimPriority")
    CfgToggle(g, "Aim through walls", "aimWalls")
    CfgToggle(g, "Sticky target", "aimSticky")
    CfgToggle(g, "Target HUD", "aimTargetHud")

    local s = CreateGroup(TabSet.Aim.Right, "Legit settings")
    CreateHint(s, "Keep it human: more smoothness and delay looks less robotic.")
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
    CreateHint(g, "Swaps the sky for a picture. If nothing happens, try the Dome method.")
    CfgToggle(g, "Custom skybox", "skyOn", function(v)
        if v then L.skyApply() else L.skyRestore() end
    end)
    CfgDropdown(g, {Text = "Preset", Options = L.skyNames, Callback = function()
        if cfg.skyOn then L.skyApply() end
    end}, "skyPreset")
    CfgToggle(g, "Hide sun / moon / clouds / haze", "skyHideBodies", function()
        if cfg.skyOn then L.skyApply() end
    end)
    CfgDropdown(g, {Text = "Method (try Dome if Sky does nothing)", Options = L.skyMethods, Callback = function()
        if cfg.skyOn then L.skyApply() end
    end}, "skyMethod")
    CreateButton(g, "Test file / asset support", function() L.skyTest() end)
    local status = makeText(g, "status: -", 12, Theme.TextDim)
    status.Size = UDim2.new(1, 0, 0, 0)
    status.AutomaticSize = Enum.AutomaticSize.Y
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    L.skyLog = function(msg) status.Text = "status: " .. tostring(msg) end

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
    CreateHint(w, "Paints your weapon with a glowing pattern. Pick a style, then tweak colors.")
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
    CreateHint(t, "Draws a line from your gun to where each shot lands.")
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
    CreateHint(r, "Calms the camera and gun kick you see on screen.")
    CfgToggle(r, "Remove camera recoil", "noRecoil")
    CfgSlider(r, {Text = "Strength", Min = 10, Max = 100, Format = fmtPct}, "noRecoilPct")
    CfgToggle(r, "Freeze weapon kick (viewmodel)", "noKickVm")
end

-- Camera
do
    local g = CreateGroup(TabSet.Camera.Left, "Field of view")
    CreateHint(g, "How wide your camera sees. Higher shows more of the world.")
    CfgSlider(g, {Text = "Field of view", Min = 50, Max = 120, Format = fmtDeg}, "fov")
    CfgSlider(g, {Text = "Zoom FOV", Min = 20, Max = 60, Format = fmtDeg}, "zoomFov")
    CreateKeybind(g, "Zoom key", zoomKey, function(k)
        zoomKey = k
        zoomActive = false
        cfg.zoomKey = k and k.Name or ""
        QueueSave()
    end)

    local fg = CreateGroup(TabSet.Camera.Left, "Freecam")
    CreateHint(fg, "Fly the camera around freely. Tap or hold the key you bind.")
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
    CreateHint(tr, "A glowing trail that follows you as you move.")
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
    pcall(function() RunService:UnbindFromRenderStep("ScorpionDome") end)
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
    CfgSlider(g, {Text = "ESP update rate", Min = 0, Max = 240, Step = 10, Format = function(v) return v == 0 and "max" or (v .. " Hz") end}, "espRate")
    CfgToggle(g, "Notifications", "notify")
    CreateKeybind(g, "Menu key", menuKey, function(k)
        menuKey = k or Enum.KeyCode.Insert
        cfg.menuKey = menuKey.Name
        ftL.Text = "hey, " .. (player.DisplayName or player.Name) .. "  |  " .. menuKey.Name .. " - hide / show"
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
        BackgroundTransparency = 1, RichText = true, Font = Enum.Font.Code, TextSize = 46, TextTransparency = 1,
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
