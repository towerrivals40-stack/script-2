-- ============================================================
--  Bike Universe | Auto Farm Script
--  Features: Anti-Fall • Auto Stunt Farm • Auto Air Tricks
-- ============================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInput      = game:GetService("UserInputService")
local VIM            = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- ─── Helper: simulate key press ───────────────────────────────
local function pressKey(key, hold)
    hold = hold or 0.08
    VIM:SendKeyEvent(true,  key, false, game)
    task.wait(hold)
    VIM:SendKeyEvent(false, key, false, game)
end

local function holdDown(key)  VIM:SendKeyEvent(true,  key, false, game) end
local function holdUp(key)    VIM:SendKeyEvent(false, key, false, game) end

-- ─── Stats ────────────────────────────────────────────────────
local farmStart     = 0
local cycleCount    = 0
local CYCLE_SEC     = 14.5          -- seconds per full cycle (0.5 + 3+3+3+3 + 2)
local COINS_CYCLE   = 55            -- rough estimate per full trick cycle
local enabled       = { antiFall = false, autoFarm = false, autoAir = false }

-- ============================================================
--  G U I
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name           = "BUFarm"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = player.PlayerGui

-- ── Main window ──
local WIN_W, WIN_H = 290, 410
local win = Instance.new("Frame")
win.Size              = UDim2.new(0, WIN_W, 0, WIN_H)
win.Position          = UDim2.new(0, 24, 0.5, -WIN_H/2)
win.BackgroundColor3  = Color3.fromRGB(12, 12, 22)
win.BorderSizePixel   = 0
win.Parent            = gui

local function addCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = parent
end
local function addStroke(parent, col, thick)
    local s = Instance.new("UIStroke")
    s.Color     = col   or Color3.fromRGB(90, 90, 230)
    s.Thickness = thick or 1.5
    s.Parent    = parent
end

addCorner(win)
addStroke(win)

-- gradient background
local bg = Instance.new("UIGradient")
bg.Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(18,18,38)),
                                   ColorSequenceKeypoint.new(1, Color3.fromRGB(8,8,18)) })
bg.Rotation = 110
bg.Parent   = win

-- ── Title bar ──
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Color3.fromRGB(55, 55, 190)
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 2
titleBar.Parent           = win
addCorner(titleBar)

local titleGrad = Instance.new("UIGradient")
titleGrad.Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(80,60,220)),
                                          ColorSequenceKeypoint.new(1, Color3.fromRGB(40,40,170)) })
titleGrad.Rotation = 90
titleGrad.Parent   = titleBar

local titleTxt = Instance.new("TextLabel")
titleTxt.Size               = UDim2.new(1, -70, 1, 0)
titleTxt.Position           = UDim2.new(0, 14, 0, 0)
titleTxt.BackgroundTransparency = 1
titleTxt.Text               = "🚲  Bike Universe Farm"
titleTxt.TextColor3         = Color3.fromRGB(255, 255, 255)
titleTxt.TextSize           = 15
titleTxt.Font               = Enum.Font.GothamBold
titleTxt.TextXAlignment     = Enum.TextXAlignment.Left
titleTxt.ZIndex             = 3
titleTxt.Parent             = titleBar

-- minimize / close buttons
local function makeIconBtn(symbol, xOff, bgColor)
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(0, 26, 0, 26)
    btn.Position          = UDim2.new(1, xOff, 0.5, -13)
    btn.BackgroundColor3  = bgColor
    btn.BorderSizePixel   = 0
    btn.Text              = symbol
    btn.TextColor3        = Color3.fromRGB(255,255,255)
    btn.TextSize          = 14
    btn.Font              = Enum.Font.GothamBold
    btn.ZIndex            = 4
    btn.Parent            = titleBar
    addCorner(btn, 6)
    return btn
end

local closeBtn = makeIconBtn("✕", -10, Color3.fromRGB(180, 45, 45))
local minBtn   = makeIconBtn("−", -40, Color3.fromRGB(50, 50, 120))

-- ── Drag ──
do
    local dragging, dragStart, winStart
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = inp.Position
            winStart  = win.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInput.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            win.Position = UDim2.new(winStart.X.Scale, winStart.X.Offset+d.X,
                                      winStart.Y.Scale, winStart.Y.Offset+d.Y)
        end
    end)
end

-- ── Content wrapper ──
local content = Instance.new("Frame")
content.Name                = "Content"
content.Size                = UDim2.new(1, 0, 1, -48)
content.Position            = UDim2.new(0, 0, 0, 48)
content.BackgroundTransparency = 1
content.Parent              = win

-- layout
local list = Instance.new("UIListLayout")
list.FillDirection  = Enum.FillDirection.Vertical
list.Padding        = UDim.new(0, 6)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Parent         = content

local pad = Instance.new("UIPadding")
pad.PaddingLeft   = UDim.new(0, 10)
pad.PaddingRight  = UDim.new(0, 10)
pad.PaddingTop    = UDim.new(0, 8)
pad.Parent        = content

-- ── Stat row helpers ──
local function makeStatRow(icon, labelText)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 26)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 38)
    row.BorderSizePixel  = 0
    row.Parent           = content
    addCorner(row, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1, -10, 1, 0)
    lbl.Position           = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = icon .. "  " .. labelText
    lbl.TextColor3         = Color3.fromRGB(170, 170, 230)
    lbl.TextSize           = 12
    lbl.Font               = Enum.Font.Gotham
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = row
    return lbl
end

local lblStatus  = makeStatRow("⚡", "Статус: ожидание")
local lblAF      = makeStatRow("🛡️", "Анти-падение: ВЫКЛ")
local lblFarm    = makeStatRow("🤖", "Авто-фарм: ВЫКЛ")
local lblAir     = makeStatRow("✈️", "Авто-воздух: ВЫКЛ")
local lblCoins   = makeStatRow("💰", "~0 монет/час")
local lblTimer   = makeStatRow("⏱️", "Следующий трюк: --")

-- ── Divider ──
local div = Instance.new("Frame")
div.Size             = UDim2.new(1, 0, 0, 1)
div.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
div.BorderSizePixel  = 0
div.Parent           = content

-- ── Toggle buttons ──
local function makeToggleBtn(text, offColor, onColor)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = offColor
    btn.BorderSizePixel  = 0
    btn.Text             = text
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.TextSize         = 13
    btn.Font             = Enum.Font.GothamBold
    btn.Parent           = content
    addCorner(btn, 9)
    addStroke(btn, offColor, 1)

    local function setOn(state)
        local col = state and onColor or offColor
        TweenService:Create(btn, TweenInfo.new(0.25), { BackgroundColor3 = col }):Play()
    end

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.new(
            btn.BackgroundColor3.R + 0.08,
            btn.BackgroundColor3.G + 0.08,
            btn.BackgroundColor3.B + 0.08)
    end)
    btn.MouseLeave:Connect(function()
        setOn(false) -- will be corrected by toggle logic
    end)
    return btn, setOn
end

local btnAntiFall, setAntiFallColor = makeToggleBtn("🛡️  Анти-падение", Color3.fromRGB(35,80,160),  Color3.fromRGB(30,170,90))
local btnAutoFarm, setAutoFarmColor = makeToggleBtn("🤖  Авто-фарм",    Color3.fromRGB(35,120,60),   Color3.fromRGB(50,210,100))
local btnAutoAir,  setAutoAirColor  = makeToggleBtn("✈️  Авто-воздух",  Color3.fromRGB(140,60,30),   Color3.fromRGB(220,120,30))

-- ── Bottom credit ──
local credit = Instance.new("TextLabel")
credit.Size               = UDim2.new(1, 0, 0, 18)
credit.BackgroundTransparency = 1
credit.Text               = "Bike Universe AutoFarm v1.0"
credit.TextColor3         = Color3.fromRGB(60, 60, 90)
credit.TextSize           = 10
credit.Font               = Enum.Font.Gotham
credit.Parent             = content

-- ============================================================
--  MINIMIZE / CLOSE
-- ============================================================
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(win, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0, WIN_W, 0, 48) or UDim2.new(0, WIN_W, 0, WIN_H)
    }):Play()
    minBtn.Text = minimized and "+" or "−"
end)

closeBtn.MouseButton1Click:Connect(function()
    enabled.antiFall = false
    enabled.autoFarm = false
    enabled.autoAir  = false
    gui:Destroy()
end)

-- ============================================================
--  ANTI-FALL
-- ============================================================
local antiFallConn

local function startAntiFall()
    antiFallConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            local char = player.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not root or not hum then return end

            local up = root.CFrame.UpVector
            -- если велосипед завалился (UpVector.Y < 0.25 → наклон > ~75°)
            if up.Y < 0.25 then
                local lv  = root.CFrame.LookVector
                local pos = root.Position
                -- выпрямляем байк
                root.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
                             * CFrame.Angles(0, math.atan2(lv.X, lv.Z), 0)
                root.AssemblyLinearVelocity  = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    end)
end

local function toggleAntiFall()
    enabled.antiFall = not enabled.antiFall
    if enabled.antiFall then
        setAntiFallColor(true)
        btnAntiFall.Text  = "🛡️  Анти-падение  ✓"
        lblAF.Text        = "🛡️  Анти-падение: ВКЛ"
        lblAF.TextColor3  = Color3.fromRGB(80, 230, 130)
        startAntiFall()
    else
        setAntiFallColor(false)
        btnAntiFall.Text  = "🛡️  Анти-падение"
        lblAF.Text        = "🛡️  Анти-падение: ВЫКЛ"
        lblAF.TextColor3  = Color3.fromRGB(170, 170, 230)
        if antiFallConn then antiFallConn:Disconnect(); antiFallConn = nil end
    end
end

-- ============================================================
--  AUTO FARM  (Ctrl → 1 →3s→ 2 →3s→ 3 →3s→ 4 → repeat)
-- ============================================================
local farmThread

local function farmLoop()
    while enabled.autoFarm do
        pcall(function()
            -- Активировать стант (Ctrl)
            lblStatus.Text = "⚡  Стант запущен..."
            pressKey(Enum.KeyCode.LeftControl, 0.12)
            task.wait(0.5)

            local tricks = {
                { key = Enum.KeyCode.One,   name = "Трюк 1" },
                { key = Enum.KeyCode.Two,   name = "Трюк 2" },
                { key = Enum.KeyCode.Three, name = "Трюк 3" },
                { key = Enum.KeyCode.Four,  name = "Трюк 4" },
            }

            for i, t in ipairs(tricks) do
                if not enabled.autoFarm then break end
                lblTimer.Text = "⏱️  " .. t.name .. "..."
                pressKey(t.key, 0.1)

                -- обратный отсчёт 3 сек
                for s = 3, 1, -1 do
                    if not enabled.autoFarm then break end
                    lblTimer.Text = "⏱️  " .. t.name .. " (след через " .. s .. "с)"
                    task.wait(1)
                end
            end

            cycleCount = cycleCount + 1
            lblStatus.Text = "⚡  Цикл #" .. cycleCount .. " завершён"
            lblTimer.Text  = "⏱️  Перезарядка 2с..."
            task.wait(2)

            -- Пересчёт монет/час
            local elapsed = tick() - farmStart
            if elapsed > 1 then
                local cph = math.floor((cycleCount * COINS_CYCLE) / elapsed * 3600)
                lblCoins.Text = "💰  ~" .. cph .. " монет/час"
            end
        end)
    end
end

local function toggleAutoFarm()
    enabled.autoFarm = not enabled.autoFarm
    if enabled.autoFarm then
        setAutoFarmColor(true)
        btnAutoFarm.Text   = "🤖  Авто-фарм  ✓"
        lblFarm.Text       = "🤖  Авто-фарм: ВКЛ"
        lblFarm.TextColor3 = Color3.fromRGB(80, 230, 130)
        farmStart    = tick()
        cycleCount   = 0
        lblCoins.Text = "💰  считаем..."
        farmThread = task.spawn(farmLoop)
    else
        setAutoFarmColor(false)
        btnAutoFarm.Text   = "🤖  Авто-фарм"
        lblFarm.Text       = "🤖  Авто-фарм: ВЫКЛ"
        lblFarm.TextColor3 = Color3.fromRGB(170, 170, 230)
        lblStatus.Text     = "⚡  Статус: ожидание"
        lblTimer.Text      = "⏱️  Следующий трюк: --"
        if farmThread then task.cancel(farmThread); farmThread = nil end
    end
end

-- ============================================================
--  AUTO AIR TRICKS  (обнаружение прыжка → X зажать + Z)
-- ============================================================
local airConn
local wasAirborne = false
local airCooldown  = false

local function doAirTrick()
    if airCooldown then return end
    airCooldown = true
    task.spawn(function()
        task.wait(0.25)                     -- небольшая задержка после взлёта
        if enabled.autoAir then
            lblStatus.Text = "⚡  Воздушный трюк!"
            holdDown(Enum.KeyCode.X)        -- зажать X
            task.wait(0.4)
            pressKey(Enum.KeyCode.Z, 0.15)  -- нажать Z → трюк
            task.wait(0.3)
            holdUp(Enum.KeyCode.X)          -- отпустить X
        end
        task.wait(1.5)
        airCooldown = false
    end)
end

local function toggleAutoAir()
    enabled.autoAir = not enabled.autoAir
    if enabled.autoAir then
        setAutoAirColor(true)
        btnAutoAir.Text   = "✈️  Авто-воздух  ✓"
        lblAir.Text       = "✈️  Авто-воздух: ВКЛ"
        lblAir.TextColor3 = Color3.fromRGB(255, 180, 80)

        airConn = RunService.Heartbeat:Connect(function()
            pcall(function()
                local char = player.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum then return end

                local inAir = (hum.FloorMaterial == Enum.Material.Air)
                if inAir and not wasAirborne then
                    wasAirborne = true
                    doAirTrick()
                elseif not inAir then
                    wasAirborne = false
                end
            end)
        end)
    else
        setAutoAirColor(false)
        btnAutoAir.Text   = "✈️  Авто-воздух"
        lblAir.Text       = "✈️  Авто-воздух: ВЫКЛ"
        lblAir.TextColor3 = Color3.fromRGB(170, 170, 230)
        wasAirborne       = false
        airCooldown       = false
        if airConn then airConn:Disconnect(); airConn = nil end
        -- на случай если клавиши остались зажаты
        holdUp(Enum.KeyCode.X)
    end
end

-- ============================================================
--  BUTTON BINDINGS
-- ============================================================
btnAntiFall.MouseButton1Click:Connect(toggleAntiFall)
btnAutoFarm.MouseButton1Click:Connect(toggleAutoFarm)
btnAutoAir.MouseButton1Click:Connect(toggleAutoAir)

-- ============================================================
--  STARTUP NOTIFICATION
-- ============================================================
local notif = Instance.new("Frame")
notif.Size             = UDim2.new(0, 240, 0, 44)
notif.Position         = UDim2.new(0.5, -120, 0, -50)
notif.BackgroundColor3 = Color3.fromRGB(55, 55, 190)
notif.BorderSizePixel  = 0
notif.Parent           = gui
addCorner(notif)

local notifTxt = Instance.new("TextLabel")
notifTxt.Size               = UDim2.new(1,0,1,0)
notifTxt.BackgroundTransparency = 1
notifTxt.Text               = "🚲  Bike Universe Farm — загружен!"
notifTxt.TextColor3         = Color3.fromRGB(255,255,255)
notifTxt.TextSize           = 13
notifTxt.Font               = Enum.Font.GothamBold
notifTxt.Parent             = notif

TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
    Position = UDim2.new(0.5, -120, 0, 10)
}):Play()

task.delay(3, function()
    TweenService:Create(notif, TweenInfo.new(0.4), {
        Position = UDim2.new(0.5, -120, 0, -60)
    }):Play()
    task.wait(0.4)
    notif:Destroy()
end)

print("[BUFarm] ✓ Скрипт загружен. GUI открыт.")
