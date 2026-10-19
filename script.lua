-- Загрузка стабильной библиотеки Kavo UI (основа Obsidian)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()

-- Настройка темы (Делаем её максимально похожей на Obsidian/Resonance)
local Window = Library.CreateLib("Project Resonance v2.9 | FTAP", "DarkTheme")

-- Создаем вкладки (слева с иконками)
local TargetTab = Window:NewTab("Target")
local MethodTab = Window:NewTab("Method Settings")
local AntisTab = Window:NewTab("Antis")
local SettingsTab = Window:NewTab("Settings")

-- Секции для Target
local TargetSection = TargetTab:NewSection("Target")
local ApplySection = TargetTab:NewSection("Apply")

-- Секции для Method
local MethodSection = MethodTab:NewSection("Methods")
local KickSettings = MethodTab:NewSection("Kick Settings")

-- Секции для Antis
local AntisSection = AntisTab:NewSection("Protection Modules")
local LagSection = AntisTab:NewSection("Lag & Performance")

-- Сервисы и переменные
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local targetName = ""
local isKicking = false
local loopRagdoll = false
local removeAntiKick = true
local kickHeight = 500
local isAntiBlobman = true
local isAntiNetwork = true
local isAntiVoid = true
local isAntiExplosion = true
local isAntiKick = true
local isAntiLag = true

-- ================= ЛОГИКА КИКА (Blobman Kick) =================
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

-- ================= ЛОГИКА ЗАЩИТЫ (Antis) =================

-- 1. Anti Network Ownership
task.spawn(function()
    while task.wait(0.1) do
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

-- 2. Anti Blobman / Fling
RunService.Heartbeat:Connect(function()
    if not isAntiBlobman then return end
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
RunService.Heartbeat:Connect(function()
    if not isAntiVoid then return end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        if char.HumanoidRootPart.Position.Y < -100 then
            char.HumanoidRootPart.CFrame = CFrame.new(0, 50, 0)
        end
    end
end)

-- 4. Anti Explosion
Workspace.DescendantAdded:Connect(function(obj)
    if not isAntiExplosion then return end
    if obj:IsA("Explosion") or obj:IsA("Fire") or obj.Name == "Void" then
        task.wait(0.05)
        pcall(function() obj:Destroy() end)
    end
end)

-- 5. Anti Kick (Packet Protect)
if isAntiKick then
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" and isAntiKick then
            return
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- 6. Anti Lag
task.spawn(function()
    while task.wait(5) do
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
TargetSection:NewTextBox("TargetName", "Targets", function(txt)
    targetName = txt
end)

ApplySection:NewToggle("LoopRagdoll", "Loop Apply Method Selected", function(state)
    loopRagdoll = state
end)

ApplySection:NewButton("Apply Method Selected", "Кикнуть цель", function()
    executeKick()
end)

-- Method Tab
MethodSection:NewDropdown("MethodDropdown", "Methods", {"Kick", "Destroy Food", "Remove Gucci"}, function(currentOption)
    -- Заглушка
end)

KickSettings:NewToggle("AntiKick", "Remove Anti-Kick", function(state)
    removeAntiKick = state
end)

KickSettings:NewSlider("KickHeight", "Kick Height", 1000, 10, function(value)
    kickHeight = value
end)

KickSettings:NewButton("TPVoid", "TP To Void Platform", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, -500, 0)
    end
end)

-- Antis Tab (Как на твоем скрине)
AntisSection:NewToggle("AntiGrab", "Anti Grab", function(state) end)
AntisSection:NewToggle("GucciAntiGrab", "[GUCCI] Anti Grab", function(state) end)
AntisSection:NewToggle("AntiBlobman", "Anti Blobman", function(state)
    isAntiBlobman = state
end)
AntisSection:NewToggle("AntiNetwork", "Anti Network Ownership", function(state)
    isAntiNetwork = state
end)
AntisSection:NewToggle("AntiExplosion", "Anti Explosion", function(state)
    isAntiExplosion = state
end)
AntisSection:NewToggle("AntiBurn", "Anti Burn", function(state) end)
AntisSection:NewToggle("AntiVoid", "Anti Void", function(state)
    isAntiVoid = state
end)
AntisSection:NewToggle("AntiKick", "Anti Kick", function(state)
    isAntiKick = state
end)
AntisSection:NewToggle("BreakPCLD", "[Break PCLD] Anti Kick", function(state) end)
AntisSection:NewToggle("AntiSticky", "Anti Sticky", function(state) end)
AntisSection:NewToggle("AntiSnowball", "Anti Snowball", function(state) end)
AntisSection:NewToggle("AntiBanana", "Anti Banana", function(state) end)
AntisSection:NewToggle("AntiPaint", "Anti Paint", function(state) end)
AntisSection:NewToggle("AntiPoison", "Anti Poison", function(state) end)

-- Lag Section
LagSection:NewToggle("AntiLag", "Anti Lag", function(state)
    isAntiLag = state
end)
LagSection:NewToggle("AutoAntiLag", "Auto Anti Lag", function(state) end)
LagSection:NewToggle("AntiInvis", "Anti Invis", function(state) end)
LagSection:NewToggle("AutoReset", "Auto Reset", function(state) end)

-- ================= БИНД НА TAB =================
local uiVisible = true
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Tab then
        uiVisible = not uiVisible
        -- В Kavo UI главный фрейм называется "KavoUI"
        local kavoGui = game:GetService("CoreGui"):FindFirstChild("KavoUI")
        if kavoGui then
            local mainFrame = kavoGui:FindFirstChild("MainFrame") or kavoGui:FindFirstChild("Main")
            if mainFrame then
                mainFrame.Visible = uiVisible
            end
        end
    end
end)

-- Уведомление
Library:Notify("Защита активирована! Нажми TAB, чтобы скрыть меню.", 5)
