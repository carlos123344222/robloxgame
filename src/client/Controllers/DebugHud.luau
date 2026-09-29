--!strict
-- Tiny tuning readout (F3 toggles): state, speeds, flow and ability charges.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

type Loco = Types.Loco

local DebugHud = {}

function DebugHud.Start(movement: Types.LocoProvider)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WCT_DebugHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = false

	local label = Instance.new("TextLabel")
	label.Name = "Readout"
	label.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Position = UDim2.new(0, 12, 0, 12)
	label.Size = UDim2.fromOffset(250, 150)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(230, 236, 245)
	label.Text = ""
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 6)
	padding.Parent = label

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.F3 then
			gui.Enabled = not gui.Enabled
		end
	end)

	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if elapsed < 0.08 or not gui.Enabled then
			return
		end
		elapsed = 0
		local loco = movement.GetLocomotion()
		if loco == nil or loco.Destroyed then
			label.Text = "no character"
			return
		end
		label.Text = string.format(
			"state   %s\nspeed   %5.1f  (h %5.1f)\nvy      %5.1f\nflow    %3.0f%%\ndash    %d  air jumps %d\nfloor   %s\n[F3] hide",
			loco.StateName,
			loco.Velocity.Magnitude,
			loco.HSpeed,
			loco.Velocity.Y,
			loco.Flow * 100,
			loco.DashCharges,
			loco.AirJumps,
			if loco.Grounded then "yes" else "no"
		)
	end)
end

return DebugHud
