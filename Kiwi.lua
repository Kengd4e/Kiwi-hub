-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Variables
local AimLockEnabled = false
local ESPEnabled = false
local GUIVisible = true
local GUIIsLocked = false
local FOVRadius = 100

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "GameGUI"

-- Main Frame (สีขาว มน เงา)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 450)
MainFrame.Position = UDim2.new(0, 50, 0, 50)
MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

-- Function to create modern buttons with emoji
local function createButton(name, emoji, position, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 200, 0, 45)
    btn.Position = position
    btn.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- ปิด = แดง
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 20
    btn.Text = emoji.." "..name
    btn.Parent = MainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        callback(btn)
    end)
end

-- Buttons with emoji
createButton("AimLock", "🎯", UDim2.new(0, 20, 0, 20), function(btn)
    AimLockEnabled = not AimLockEnabled
    btn.BackgroundColor3 = AimLockEnabled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
end)

createButton("ESP", "👁️", UDim2.new(0, 20, 0, 80), function(btn)
    ESPEnabled = not ESPEnabled
    btn.BackgroundColor3 = ESPEnabled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
end)

createButton("Toggle GUI", "🖱️", UDim2.new(0, 20, 0, 140), function(btn)
    GUIVisible = not GUIVisible
    ScreenGui.Enabled = GUIVisible
end)

createButton("Lock GUI", "🔒", UDim2.new(0, 20, 0, 200), function(btn)
    GUIIsLocked = not GUIIsLocked
    btn.BackgroundColor3 = GUIIsLocked and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
end)

-- Drag GUI
local dragging = false
local dragInput, mousePos, framePos

MainFrame.InputBegan:Connect(function(input)
    if GUIIsLocked then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        mousePos = input.Position
        framePos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - mousePos
        MainFrame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X,
                                       framePos.Y.Scale, framePos.Y.Offset + delta.Y)
    end
end)

-- FOV Circle อยู่กลางจอ
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = true
FOVCircle.Color = Color3.fromRGB(0, 255, 0)
FOVCircle.Thickness = 2
FOVCircle.Radius = FOVRadius
FOVCircle.Filled = false
FOVCircle.Transparency = 0.5
local viewportSize = Camera.ViewportSize
FOVCircle.Position = Vector2.new(viewportSize.X/2, viewportSize.Y/2)

-- ESP Table
local ESPTable = {}

-- Track respawned players
local function TrackPlayer(player)
    player.CharacterAdded:Connect(function(char)
        if ESPTable[player] then
            ESPTable[player]:Remove()
            ESPTable[player] = nil
        end
        if ESPEnabled then
            local esp = Drawing.new("Circle")
            -- แยกสีตามทีม
            local playerTeam = player.Team
            local localTeam = LocalPlayer.Team
            esp.Color = (playerTeam == localTeam) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
            esp.Radius = 10
            esp.Filled = true
            ESPTable[player] = esp
        end
    end)
end

-- Track existing players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        TrackPlayer(player)
    end
end

-- Track players joining later
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        TrackPlayer(player)
    end
end)

-- RenderStepped loop
RunService.RenderStepped:Connect(function()
    -- ESP
    if ESPEnabled then
        for player, esp in pairs(ESPTable) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local root = player.Character.HumanoidRootPart
                local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                esp.Position = Vector2.new(screenPos.X, screenPos.Y)
                esp.Visible = onScreen
            else
                esp.Visible = false
            end
        end
    end

    -- AimLock + AimLine
    if AimLockEnabled then
        local closestPlayer = nil
        local shortestDistance = FOVRadius
        local center = Vector2.new(viewportSize.X/2, viewportSize.Y/2) -- FOV กลางจอ
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
                local headPos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
                local distance = (Vector2.new(headPos.X, headPos.Y) - center).Magnitude
                if distance < shortestDistance then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end

        if closestPlayer then
            -- AimLine
            if not ESPTable[closestPlayer.."Line"] then
                local line = Drawing.new("Line")
                line.Color = Color3.fromRGB(0, 255, 0)
                line.Thickness = 2
                ESPTable[closestPlayer.."Line"] = line
            end
            local line = ESPTable[closestPlayer.."Line"]
            local headPos, onScreen = Camera:WorldToViewportPoint(closestPlayer.Character.Head.Position)
            line.From = center
            line.To = Vector2.new(headPos.X, headPos.Y)
            line.Visible = onScreen
        end
    end
end)
