-- Загрузка стабильной библиотеки Kavo UI
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()

-- Настройка темы
local Window = Library.CreateLib("Project Resonance v2.9 | FTAP", "DarkTheme")

-- Вкладки
local TargetTab = Window:NewTab("Target")
local MethodTab = Window:NewTab("Method Settings")
local AntisTab = Window:NewTab("Antis")
local SettingsTab = Window:NewTab("Settings")

-- Секции
local TargetSection = TargetTab:NewSection("Target")
local ApplySection = TargetTab:NewSection("Apply")
local MethodSection = MethodTab:NewSection("Methods")
local KickSettings = MethodTab:NewSection("Kick Settings")
local AntisSection = AntisTab:NewSection("Protection Modules")
local LagSection = AntisTab:NewSection("Lag & Performance")
local SettingsSection = SettingsTab:NewSection("Script Settings")

-- Сервисы и переменные
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- Флаги состояния
local isUnloaded = false
local targetName = ""
local loopRagdoll = false
local kickHeight = 500
local isAntiBlobman = true
local isAntiNetwork = true
local isAntiVoid = true
local isAntiExplosion = true
local isAntiKick = true
local isAntiLag = true

-- Таблица соединений
local Connections = {}
local oldNamecall = nil -- Сюда сохраним оригинальную функцию игры

-- ================= ЛОГИКА КИКА =================
local function getTarget()
    if targetName ~= "" then
        local target = Players:FindFirstChild(targetName)
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            return target
        end
    end
    return nil
end

local function executeKick()
    local target = getTarget()
    if not target or not target.Character then return end
    
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    local hum = target.Character:FindFirstChildOfClass("Humanoid")
    
    if hrp and hum then
        pcall(function() hrp:SetNetworkOwner(LocalPlayer) end)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 3, 0)
        end
        hum.PlatformStand = true
        
        local bv = Instance.new("BodyVelocity")
        bv.Velocity = Vector3.new(0, kickHeight, 0)
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = hrp
        
        task.wait(0.1)
        bv:Destroy()
        
        if not loopRagdoll then
            task.wait(0.5)
            hum.PlatformStand = false
        end
    end
end

-- ================= ЛОГИКА ЗАЩИТЫ =================

-- 1. Anti Network
task.spawn(function()
    while not isUnloaded do
        task.wait(0.1)
        if isAntiNetwork and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = LocalPlayer.Character.HumanoidRootPart
            pcall(function()
                if hrp:GetNetworkOwner() ~= LocalPlayer then
                    hrp:SetNetworkOwner(LocalPlayer)
                end
            end)
        end
    end
end)

-- 2. Anti Blobman
Connections.Heartbeat1 = RunService.Heartbeat:Connect(function()
    if isUnloaded or not isAntiBlobman then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if hrp and hum then
        if hrp.Velocity.Magnitude > 250 or hrp.RotVelocity.Magnitude > 50 then
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
            for _, v in pairs(hrp:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyAngularVelocity") or v:IsA("BodyPosition") then
                    v:Destroy()
                end
            end
        end
        if hum.PlatformStand then
            hum.PlatformStand = false
        end
    end
end)

-- 3. Anti Void
Connections.Heartbeat2 = RunService.Heartbeat:Connect(function()
    if isUnloaded or not isAntiVoid then return end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        if char.HumanoidRootPart.Position.Y < -100 then
            char.HumanoidRootPart.CFrame = CFrame.new(0, 50, 0)
        end
    end
end)

-- 4. Anti Explosion
Connections.DescendantAdded = Workspace.DescendantAdded:Connect(function(obj)
    if isUnloaded or not isAntiExplosion then return end
    if obj:IsA("Explosion") or obj:IsA("Fire") or obj.Name == "Void" then
        task.wait(0.05)
        pcall(function() obj:Destroy() end)
    end
end)

-- 5. Anti Kick (Хук)
if isAntiKick then
    local mt = getrawmetatable(game)
    oldNamecall = mt.__namecall -- Сохраняем оригинал
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" and isAntiKick and not isUnloaded then
            return
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- 6. Anti Lag
task.spawn(function()
    while not isUnloaded do
        task.wait(5)
        if isAntiLag then
            for _, v in pairs(Workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") then
                    if v.Parent ~= LocalPlayer.Character then
                        v.Enabled = false
                    end
                end
            end
        end
    end
end)

-- ================= UI ЭЛЕМЕНТЫ =================

-- Target Tab
TargetSection:NewTextBox("TargetName", "Targets", function(txt) targetName = txt end)
ApplySection:NewToggle("LoopRagdoll", "Loop Apply Method Selected", function(state) loopRagdoll = state end)
ApplySection:NewButton("Apply Method Selected", "Кикнуть цель", function() executeKick() end)

-- Method Tab
MethodSection:NewDropdown("MethodDropdown", "Methods", {"Kick", "Destroy Food", "Remove Gucci"}, function(currentOption) end)
KickSettings:NewSlider("KickHeight", "Kick Height", 1000, 10, function(value) kickHeight = value end)
KickSettings:NewButton("TPVoid", "TP To Void Platform", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, -500, 0)
    end
end)

-- Antis Tab
AntisSection:NewToggle("AntiBlobman", "Anti Blobman", function(state) isAntiBlobman = state end)
AntisSection:NewToggle("AntiNetwork", "Anti Network Ownership", function(state) isAntiNetwork = state end)
AntisSection:NewToggle("AntiExplosion", "Anti Explosion", function(state) isAntiExplosion = state end)
AntisSection:NewToggle("AntiVoid", "Anti Void", function(state) isAntiVoid = state end)
AntisSection:NewToggle("AntiKick", "Anti Kick", function(state) isAntiKick = state end)

-- Lag Section
LagSection:NewToggle("AntiLag", "Anti Lag", function(state) isAntiLag = state end)

-- ================= КНОПКА UNLOAD =================
SettingsSection:NewButton("Unload Script", "Полностью выгружает скрипт", function()
    isUnloaded = true -- Останавливаем циклы
    
    -- 1. Отключаем все соединения
    for _, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    
    -- 2. Возвращаем оригинальный __namecall (чтобы игра не зависла)
    if oldNamecall then
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = oldNamecall
        setreadonly(mt, true)
    end
    
    -- 3. Ищем и удаляем GUI во всех возможных местах
    local guiNames = {"KavoUI", "Obsidian"}
    for _, name in ipairs(guiNames) do
        -- В CoreGui
        local cg = CoreGui:FindFirstChild(name)
        if cg then cg:Destroy() end
        
        -- В PlayerGui
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local pgGui = pg:FindFirstChild(name)
            if pgGui then pgGui:Destroy() end
        end
        
        -- В gethui (защищенная папка экзекутора)
        if gethui then
            local hui = gethui():FindFirstChild(name)
            if hui then hui:Destroy() end
        end
    end
    
    -- Уведомление об успешной выгрузке
    print("Скрипт успешно выгружен!")
end)

-- ================= БИНД НА TAB =================
local uiVisible = true
Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isUnloaded then return end
    if input.KeyCode == Enum.KeyCode.Tab then
        uiVisible = not uiVisible
        local kavoGui = CoreGui:FindFirstChild("KavoUI") or LocalPlayer.PlayerGui:FindFirstChild("KavoUI")
        if kavoGui then
            local mainFrame = kavoGui:FindFirstChild("MainFrame") or kavoGui:FindFirstChild("Main")
            if mainFrame then
                mainFrame.Visible = uiVisible
            end
        end
    end
end)

Library:Notify("Скрипт загружен! Нажми TAB, чтобы скрыть меню.", 5)
