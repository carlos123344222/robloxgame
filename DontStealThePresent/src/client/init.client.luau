-- Don't Steal the Present — arranque del cliente.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Controllers = script:WaitForChild("Controllers")
local UI = script:WaitForChild("UI")

local ClientState = require(script:WaitForChild("ClientState"))
local SoundController = require(Controllers.SoundController)
local WorldAnimator = require(Controllers.WorldAnimator)
local BaseController = require(Controllers.BaseController)
local GearController = require(Controllers.GearController)
local EffectsController = require(Controllers.EffectsController)

local Theme = require(UI.Theme)
local Notifications = require(UI.Notifications)
local Hud = require(UI.Hud)
local ShopUI = require(UI.ShopUI)
local RebirthUI = require(UI.RebirthUI)
local IndexUI = require(UI.IndexUI)
local IntroUI = require(UI.IntroUI)

local screen = Instance.new("ScreenGui")
screen.Name = "DontStealThePresent"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

SoundController.Start()
Notifications.Start(screen)
Hud.Start(screen)
ShopUI.Start(screen)
RebirthUI.Start(screen)
IndexUI.Start(screen)
IntroUI.Start(screen)

Hud.Callbacks.Shop = ShopUI.Toggle
Hud.Callbacks.Rebirth = RebirthUI.Toggle
Hud.Callbacks.Index = IndexUI.Toggle
Hud.Callbacks.Help = IntroUI.ToggleHelp

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		ShopUI.Open()
	elseif prompt.Name == "RebirthPrompt" then
		RebirthUI.Open()
	end
end)

-- atajos de teclado
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.G then
		ShopUI.Toggle()
	elseif input.KeyCode == Enum.KeyCode.R then
		RebirthUI.Toggle()
	elseif input.KeyCode == Enum.KeyCode.J then
		IndexUI.Toggle()
	elseif input.KeyCode == Enum.KeyCode.H then
		IntroUI.ToggleHelp()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		Theme.CloseAll()
	end
end)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

task.spawn(WorldAnimator.Start)
BaseController.Start()
GearController.Start()
EffectsController.Start()
ClientState.Start()
