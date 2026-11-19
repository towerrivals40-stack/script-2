-- ================================================================
--  Bike Universe | Auto Farm v2.0
--  Исследовано: деньги = езда вперёд + держать Ctrl (вилли)
--  Чем дольше вилли без падения → растёт множитель → больше монет
-- ================================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UserInput     = game:GetService("UserInputService")
local VIM           = game:GetService("VirtualInputManager")

local player    = Players.LocalPlayer
local mouse     = player:GetMouse()

-- ── Утилиты нажатия клавиш ────────────────────────────────────
local function keyDown(key)
    pcall(function() VIM:SendKeyEvent(true,  key, false, game) end)
end
local function keyUp(key)
    pcall(function() VIM:SendKeyEvent(false, key, false, game) end)
end
local function tap(key, hold)
    keyDown(key); task.wait(hold or 0.08); keyUp(key)
end

-- ── Поиск VehicleSeat ─────────────────────────────────────────
local function getSeat()
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
        return hum.SeatPart
    end
    return nil
end

-- ── Угол наклона байка (pitch) ────────────────────────────────
-- LookVector.Y > 0  → нос вверх (вилли)
-- LookVector.Y < 0  → нос вниз
-- UpVector.Y < 0.3  → байк завалился набок
local function getBikePitch()
    local char = player.Character
    if not char then return 0, 1 end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return 0, 1 end
    return root.CFrame.LookVector.Y, root.CFrame.UpVector.Y
end

-- ── Деньги из leaderstats ─────────────────────────────────────
local function getMoney()
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return nil end
    -- game может называть его Cash / Money / Coins / Bucks
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("IntValue") or v:IsA("NumberValue") then
            return v.Value
        end
    end
    return nil
end

-- ── Поиск ближайшего байка для посадки ───────────────────────
local function findNearestBike()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local best, bestDist = nil, 50 -- только в радиусе 50 студов
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("VehicleSeat") then
            local dist = (obj.Position - root.Position).Magnitude
            if dist < bestDist and obj.Occupant == nil then
                best = obj; bestDist = dist
            end
        end
    end
    return best
end

-- ── Посадка на байк ───────────────────────────────────────────
local function tryMount()
    local char = player.Character
    if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local seat = findNearestBike()
    if seat then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = seat.CFrame * CFrame.new(0, 2, 0)
        end
        task.wait(0.4)
        seat:Sit(hum)
    else
        -- попробовать нажать Q (спавн байка)
        tap(Enum.KeyCode.Q, 0.1)
        task.wait(2)
        local seat2 = findNearestBike()
        if seat2 and hum then seat2:Sit(hum) end
    end
end

-- =================================================================
--  С О С Т О Я Н И Е
-- =================================================================
local state = {
    farm      = false,
    wheelie   = true,   -- вилли включено по умолчанию (главный источник денег)
    antiFall  = true,
    -- статистика
    startTime  = 0,
    startMoney = 0,
    lastMoney  = 0,
    farmCoins  = 0,
}

local wheelieHeld = false
local function setWheelieHeld(v)
    if v == wheelieHeld then return end
    wheelieHeld = v
    if v then keyDown(Enum.KeyCode.LeftControl)
    else      keyUp(Enum.KeyCode.LeftControl) end
end

-- =================================================================
--  Г У И
-- =================================================================
-- удалить старый gui если перезапустили
pcall(function()
    local old = player.PlayerGui:FindFirstChild("BUv2")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name           = "BUv2"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = player.PlayerGui

-- ── Вспомогательные функции ──────────────────────────────────
local FONT_BOLD   = Enum.Font.GothamBold
local FONT_REG    = Enum.Font.Gotham
local C3 = Color3.fromRGB

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = p; return c
end
local function stroke(p, col, t)
    local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = t or 1.5; s.Parent = p; return s
end
local function gradient(p, c0, c1, rot)
    local g = Instance.new("UIGradient")
    g.Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0,c0), ColorSequenceKeypoint.new(1,c1) })
    g.Rotation = rot or 90; g.Parent = p; return g
end

-- ── Главное окно ─────────────────────────────────────────────
local W, H = 300, 420
local win = Instance.new("Frame")
win.Name             = "Win"
win.Size             = UDim2.new(0, W, 0, H)
win.Position         = UDim2.new(0, 20, 0.5, -H/2)
win.BackgroundColor3 = C3(10, 10, 20)
win.BorderSizePixel  = 0
win.Parent           = gui
corner(win, 14)
stroke(win, C3(70, 90, 240))
gradient(win, C3(16,16,34), C3(8,8,16), 120)

-- ── Заголовок ────────────────────────────────────────────────
local title = Instance.new("Frame")
title.Size             = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = C3(50, 60, 200)
title.BorderSizePixel  = 0
title.ZIndex           = 3
title.Parent           = win
corner(title, 14)
gradient(title, C3(90,70,240), C3(40,40,180))

-- заголовок — текст
local titleTxt = Instance.new("TextLabel")
titleTxt.Size               = UDim2.new(1,-68,1,0)
titleTxt.Position           = UDim2.new(0,14,0,0)
titleTxt.BackgroundTransparency = 1
titleTxt.Text               = "🚲  Bike Universe Farm"
titleTxt.TextColor3         = C3(255,255,255)
titleTxt.TextSize           = 15
titleTxt.Font               = FONT_BOLD
titleTxt.TextXAlignment     = Enum.TextXAlignment.Left
titleTxt.ZIndex             = 4
titleTxt.Parent             = title

-- кнопки минимизации и закрытия
local function iconBtn(sym, xOff, bg)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,26,0,26); b.Position = UDim2.new(1,xOff,0.5,-13)
    b.BackgroundColor3 = bg; b.BorderSizePixel = 0
    b.Text = sym; b.TextColor3 = C3(255,255,255); b.TextSize = 14
    b.Font = FONT_BOLD; b.ZIndex = 5; b.Parent = title
    corner(b, 6); return b
end
local btnClose = iconBtn("✕", -10, C3(190,45,45))
local btnMin   = iconBtn("−", -40, C3(45,45,110))

-- ── Перетаскивание ───────────────────────────────────────────
do
    local drag, ds, wp = false, nil, nil
    title.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            drag=true; ds=inp.Position; wp=win.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then drag=false end
            end)
        end
    end)
    UserInput.InputChanged:Connect(function(inp)
        if drag and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - ds
            win.Position = UDim2.new(wp.X.Scale, wp.X.Offset+d.X, wp.Y.Scale, wp.Y.Offset+d.Y)
        end
    end)
end

-- ── Контент ──────────────────────────────────────────────────
local content = Instance.new("ScrollingFrame")
content.Name                 = "Content"
content.Size                 = UDim2.new(1,-12, 1,-58)
content.Position             = UDim2.new(0,6, 0,52)
content.BackgroundTransparency = 1
content.ScrollBarThickness   = 0
content.CanvasSize           = UDim2.new(0,0,0,0)
content.AutomaticCanvasSize  = Enum.AutomaticSize.Y
content.Parent               = win

local uiList = Instance.new("UIListLayout")
uiList.FillDirection         = Enum.FillDirection.Vertical
uiList.Padding               = UDim.new(0, 5)
uiList.HorizontalAlignment   = Enum.HorizontalAlignment.Center
uiList.Parent                = content

local uiPad = Instance.new("UIPadding")
uiPad.PaddingLeft    = UDim.new(0,8)
uiPad.PaddingRight   = UDim.new(0,8)
uiPad.PaddingTop     = UDim.new(0,4)
uiPad.Parent         = content

-- ── Создать строку статуса ───────────────────────────────────
local function statRow(icon, txt)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,27); row.BackgroundColor3 = C3(18,18,36)
    row.BorderSizePixel = 0; row.Parent = content
    corner(row, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-10,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = icon.."  "..txt
    lbl.TextColor3 = C3(160,160,220); lbl.TextSize = 12
    lbl.Font = FONT_REG; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    return lbl
end

local lblStatus  = statRow("⚡","Статус: не запущен")
local lblBike    = statRow("🏍️","Байк: не найден")
local lblWheels  = statRow("🎯","Вилли: ожидание")
local lblCoins   = statRow("💰","~0 монет/час")
local lblTotal   = statRow("📊","Заработано: 0")
local lblTime    = statRow("⏱️","Время фарма: 0 сек")

-- ── Разделитель ──────────────────────────────────────────────
local function divider()
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1,0,0,1); d.BackgroundColor3 = C3(40,40,80)
    d.BorderSizePixel = 0; d.Parent = content
end

divider()

-- ── Создать кнопку-переключатель ─────────────────────────────
local function makeToggle(icon, label, offCol, onCol)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,40); btn.BackgroundColor3 = offCol
    btn.BorderSizePixel = 0
    btn.Text = icon.."  "..label
    btn.TextColor3 = C3(255,255,255); btn.TextSize = 13; btn.Font = FONT_BOLD
    btn.Parent = content
    corner(btn, 9)

    local isOn = false

    local function refresh()
        TweenService:Create(btn, TweenInfo.new(0.22), {
            BackgroundColor3 = isOn and onCol or offCol
        }):Play()
        btn.Text = icon.."  "..label..(isOn and "  ✓" or "")
    end

    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        refresh()
    end)

    return btn, function() return isOn end, function(v)
        isOn = v; refresh()
    end
end

local btnFarm,  isFarmOn,  setFarmOn  = makeToggle("🤖","Авто-фарм",     C3(35,100,55),  C3(45,210,105))
local btnWheel, isWheelOn, setWheelOn = makeToggle("🎯","Авто-вилли",     C3(55,45,170),  C3(100,80,255))
local btnFall,  isFallOn,  setFallOn  = makeToggle("🛡️","Анти-падение",  C3(35,80,170),  C3(30,170,220))

divider()

-- индикатор угла вилли
local pitchRow = Instance.new("Frame")
pitchRow.Size = UDim2.new(1,0,0,32); pitchRow.BackgroundColor3 = C3(18,18,36)
pitchRow.BorderSizePixel = 0; pitchRow.Parent = content
corner(pitchRow, 7)

local pitchBg = Instance.new("Frame")
pitchBg.Size = UDim2.new(1,-20,0,10); pitchBg.Position = UDim2.new(0,10,0.5,-5)
pitchBg.BackgroundColor3 = C3(30,30,55); pitchBg.BorderSizePixel = 0
pitchBg.Parent = pitchRow; corner(pitchBg, 5)

local pitchBar = Instance.new("Frame")
pitchBar.Size = UDim2.new(0,0,1,0); pitchBar.BackgroundColor3 = C3(90,230,120)
pitchBar.BorderSizePixel = 0; pitchBar.Parent = pitchBg; corner(pitchBar, 5)

local pitchTxt = Instance.new("TextLabel")
pitchTxt.Size = UDim2.new(0,60,1,0); pitchTxt.Position = UDim2.new(1,-65,0,0)
pitchTxt.BackgroundTransparency = 1; pitchTxt.Text = "0°"
pitchTxt.TextColor3 = C3(200,200,255); pitchTxt.TextSize = 11; pitchTxt.Font = FONT_BOLD
pitchTxt.TextXAlignment = Enum.TextXAlignment.Right
pitchTxt.Parent = pitchRow

-- ── Кнопка «Сесть на байк» ───────────────────────────────────
local btnMount = Instance.new("TextButton")
btnMount.Size = UDim2.new(1,0,0,36); btnMount.BackgroundColor3 = C3(160,100,20)
btnMount.BorderSizePixel = 0; btnMount.Text = "🏍️  Сесть на байк (Q)"
btnMount.TextColor3 = C3(255,255,255); btnMount.TextSize = 13; btnMount.Font = FONT_BOLD
btnMount.Parent = content; corner(btnMount, 9)

btnMount.MouseButton1Click:Connect(function()
    task.spawn(tryMount)
end)

-- ── Мини-кнопки минимизировать/закрыть ───────────────────────
local minimized = false
btnMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(win, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0,W,0,52) or UDim2.new(0,W,0,H)
    }):Play()
    btnMin.Text = minimized and "+" or "−"
end)

btnClose.MouseButton1Click:Connect(function()
    if isFarmOn() then setFarmOn(false) end
    -- отпустить клавиши
    keyUp(Enum.KeyCode.LeftControl)
    keyUp(Enum.KeyCode.W)
    gui:Destroy()
end)

-- =================================================================
--  О С Н О В Н О Й  Ц И К Л  Ф А Р М А
-- =================================================================
local PITCH_MAX   = 0.70   -- LookVector.Y выше этого → отпускаем Ctrl (байк переворачивается назад)
local PITCH_MIN   = 0.08   -- LookVector.Y ниже этого → нажимаем Ctrl (начинаем вилли)
local SIDE_LIMIT  = 0.35   -- UpVector.Y ниже этого → байк завалился набок
local farmConn

local prevMoney = nil
local moneyHistory = {}     -- последние 60 значений для расчёта /час

local function fmt(n)
    if n >= 1000000 then return string.format("%.1fM", n/1000000)
    elseif n >= 1000 then return string.format("%.1fK", n/1000)
    else return tostring(math.floor(n)) end
end

local function startFarm()
    state.startTime  = tick()
    state.startMoney = getMoney() or 0
    state.farmCoins  = 0
    prevMoney        = state.startMoney
    moneyHistory     = {}

    farmConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            local farmOn  = isFarmOn()
            local wheelOn = isWheelOn()
            local fallOn  = isFallOn()

            local char = player.Character
            if not char then
                lblStatus.Text = "⚡  Нет персонажа, жду..."
                return
            end

            local hum  = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then return end

            local seat      = getSeat()
            local pitchY    = root.CFrame.LookVector.Y
            local upY       = root.CFrame.UpVector.Y
            local pitchDeg  = math.deg(math.asin(math.clamp(pitchY, -1, 1)))

            -- ── Обновить полосу угла ──────────────────────────
            local barFrac = math.clamp((pitchY + 1) / 2, 0, 1)
            TweenService:Create(pitchBar, TweenInfo.new(0.1), {
                Size = UDim2.new(barFrac, 0, 1, 0)
            }):Play()
            pitchBar.BackgroundColor3 =
                pitchY > 0.55 and C3(230, 80, 80) or
                pitchY > 0.35 and C3(230, 180, 30) or C3(80, 220, 110)
            pitchTxt.Text = string.format("%+.0f°", pitchDeg)

            -- ── Деньги ───────────────────────────────────────
            local curMoney = getMoney()
            if curMoney and prevMoney then
                local delta = curMoney - prevMoney
                if delta > 0 then
                    state.farmCoins = state.farmCoins + delta
                    table.insert(moneyHistory, { t = tick(), v = delta })
                end
            end
            prevMoney = curMoney

            -- Держать историю 60 сек
            local now = tick()
            while #moneyHistory > 0 and (now - moneyHistory[1].t) > 60 do
                table.remove(moneyHistory, 1)
            end
            if #moneyHistory >= 2 then
                local span = moneyHistory[#moneyHistory].t - moneyHistory[1].t
                if span > 1 then
                    local sum = 0
                    for _, e in ipairs(moneyHistory) do sum = sum + e.v end
                    local cph = math.floor(sum / span * 3600)
                    lblCoins.Text = "💰  ~"..fmt(cph).." монет/час"
                end
            end

            lblTotal.Text = "📊  Заработано: "..fmt(state.farmCoins)
            lblTime.Text  = "⏱️  Фарм: "..math.floor(tick()-state.startTime).."с"

            -- ── Не запущен — ничего не делаем ────────────────
            if not farmOn then
                lblStatus.Text = "⚡  Фарм выключен"
                lblBike.Text   = "🏍️  Байк: не отслеживается"
                setWheelieHeld(false)
                keyUp(Enum.KeyCode.W)
                return
            end

            -- ── Нет байка → попытка посадки ──────────────────
            if not seat then
                lblStatus.Text = "⚡  Нет байка, пытаюсь сесть..."
                lblBike.Text   = "🏍️  Байк: не найден"
                setWheelieHeld(false)
                keyUp(Enum.KeyCode.W)
                -- раз в 3 сек
                if math.floor(tick()*10) % 30 == 0 then
                    task.spawn(tryMount)
                end
                return
            end

            lblBike.Text = "🏍️  Байк: найден ✓"

            -- ── Анти-падение ─────────────────────────────────
            if fallOn then
                if upY < SIDE_LIMIT then
                    -- завалился набок — выпрямить
                    lblStatus.Text = "⚡  Выравниваю байк..."
                    local lv = root.CFrame.LookVector
                    root.CFrame = CFrame.new(root.Position + Vector3.new(0,1.5,0))
                                * CFrame.Angles(0, math.atan2(lv.X, lv.Z), 0)
                    root.AssemblyLinearVelocity  = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    setWheelieHeld(false)
                    task.wait(0.3)
                    return
                end
            end

            -- ── Держать прямо ─────────────────────────────────
            -- Steer = 0 принудительно каждый кадр
            seat.Steer = 0
            -- Throttle = 1 принудительно (едет вперёд)
            seat.Throttle = 1

            -- ── Вилли-логика ──────────────────────────────────
            if wheelOn then
                if pitchY > PITCH_MAX then
                    -- Слишком высоко → отпустить Ctrl, чуть нажать тормоз
                    setWheelieHeld(false)
                    lblWheels.Text = "🎯  Вилли: слишком высоко! 📉"
                    -- краткий тормоз для снижения угла
                    keyDown(Enum.KeyCode.S)
                    task.wait(0.08)
                    keyUp(Enum.KeyCode.S)
                elseif pitchY < PITCH_MIN then
                    -- Слишком низко → зажать Ctrl
                    setWheelieHeld(true)
                    lblWheels.Text = "🎯  Вилли: набираю угол... ↑"
                else
                    -- Хорошая зона → держать Ctrl
                    setWheelieHeld(true)
                    if pitchY > 0.45 then
                        lblWheels.Text = string.format("🎯  Вилли: ИДЕАЛЬНО! %.0f°", pitchDeg)
                    else
                        lblWheels.Text = string.format("🎯  Вилли: держу %.0f°", pitchDeg)
                    end
                end
            else
                setWheelieHeld(false)
                lblWheels.Text = "🎯  Вилли: выключено"
            end

            -- Всегда держать W (газ)
            keyDown(Enum.KeyCode.W)

            lblStatus.Text = "⚡  Фармлю... x" .. tostring(seat.Throttle)
        end)
    end)
end

startFarm()  -- подключаем Heartbeat сразу (логика сама проверяет флаги)

-- =================================================================
--  Н О Т И Ф И К А Ц И Я
-- =================================================================
local notif = Instance.new("Frame")
notif.Size = UDim2.new(0,250,0,42); notif.Position = UDim2.new(0.5,-125,0,-50)
notif.BackgroundColor3 = C3(55,55,200); notif.BorderSizePixel = 0; notif.Parent = gui
corner(notif, 10); gradient(notif, C3(80,60,230), C3(40,40,180))

local ntxt = Instance.new("TextLabel")
ntxt.Size = UDim2.new(1,0,1,0); ntxt.BackgroundTransparency = 1
ntxt.Text = "🚲  BikeUniverse Farm v2 — OK!"
ntxt.TextColor3 = C3(255,255,255); ntxt.TextSize = 13; ntxt.Font = FONT_BOLD
ntxt.Parent = notif

TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
    Position = UDim2.new(0.5,-125,0,8)
}):Play()
task.delay(3.5, function()
    TweenService:Create(notif, TweenInfo.new(0.4), {
        Position = UDim2.new(0.5,-125,0,-55)
    }):Play()
    task.wait(0.5); notif:Destroy()
end)

-- =================================================================
--  ОЧИСТКА при выходе
-- =================================================================
player.CharacterRemoving:Connect(function()
    setWheelieHeld(false)
    keyUp(Enum.KeyCode.W)
end)

print("[BUFarm v2] ✓ Запущен. Нажми 'Авто-фарм' чтобы начать.")
