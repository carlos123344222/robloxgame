-- Avisos en pantalla: toasts apilados arriba, alerta roja cuando te roban, texto grande y confeti.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Remotes = require(Shared.Net.Remotes)

local Theme = require(script.Parent.Theme)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Notifications = {}

local screen: ScreenGui
local stack: Frame
local alertFrame: Frame
local alertText: TextLabel
local edge: Frame

local KIND_COLORS: { [string]: Color3 } = {
	Info = Theme.Colors.NavyLight,
	Success = Theme.Colors.Green,
	Warning = Theme.Colors.Orange,
	Error = Theme.Colors.Red,
	Rare = Theme.Colors.Purple,
	Event = Theme.Colors.Blue,
}

local active = 0

function Notifications.Toast(text: string, kind: string?, extra: { [string]: any }?)
	local color = KIND_COLORS[kind or "Info"] or Theme.Colors.NavyLight
	if extra and typeof(extra.Color) == "Color3" then
		color = extra.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	end
	active += 1
	while active > 5 do
		local oldest: Instance? = nil
		local oldestOrder = math.huge
		for _, child in stack:GetChildren() do
			if child:IsA("Frame") and child.LayoutOrder < oldestOrder then
				oldest = child
				oldestOrder = child.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
		active -= 1
	end
	local toast = Gui.Create("Frame", {
		Name = "Toast",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = math.floor(os.clock() * 1000),
		BackgroundTransparency = 1,
		Parent = stack,
	}, {
		Gui.Corner(12),
		Gui.Gradient(Theme.Lighter(color, 0.15), Theme.Darker(color, 0.2), 90),
	})
	local stroke = Gui.BorderStroke(Theme.Darker(color, 0.65), 3, 1)
	stroke.Parent = toast
	local label = Gui.Label({
		Text = text,
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextTransparency = 1,
		StrokeThickness = 2,
		Parent = toast,
	})
	local labelStroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
	labelStroke.Transparency = 1
	if extra and extra.Rainbow then
		Gui.RainbowGradient().Parent = label
		label:AddTag("RainbowText")
	end
	Theme.Tween(toast, 0.25, { BackgroundTransparency = 0 })
	Theme.Tween(stroke, 0.25, { Transparency = 0 })
	Theme.Tween(label, 0.25, { TextTransparency = 0 })
	Theme.Tween(labelStroke, 0.25, { Transparency = 0 })
	local life = if kind == "Event" or kind == "Rare" then 6 else 4
	task.delay(life, function()
		if not toast.Parent then
			return
		end
		Theme.Tween(toast, 0.4, { BackgroundTransparency = 1 })
		Theme.Tween(stroke, 0.4, { Transparency = 1 })
		Theme.Tween(label, 0.4, { TextTransparency = 1 })
		Theme.Tween(labelStroke, 0.4, { Transparency = 1 })
		task.wait(0.45)
		if toast.Parent then
			toast:Destroy()
			active -= 1
		end
	end)
end

-- Texto enorme en el centro (renacer, evento...)
function Notifications.Center(text: string, color: Color3?)
	local label = Gui.Label({
		Text = text,
		Font = Theme.Fonts.Title,
		TextColor3 = color or Theme.Colors.Gold,
		Size = UDim2.new(0.8, 0, 0.12, 0),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 5,
		Parent = screen,
	})
	local scale = Gui.Create("UIScale", { Scale = 0.3, Parent = label })
	Theme.Tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		Theme.Tween(label, 0.5, { TextTransparency = 1 })
		Theme.Tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.5, { Transparency = 1 })
		task.wait(0.55)
		label:Destroy()
	end)
end

-- ¡Te están robando!
function Notifications.Alert(thiefName: string, presentLabel: string)
	alertText.Text = string.format("🚨 ¡%s te está robando %s! 🚨", thiefName, presentLabel)
	alertFrame.Visible = true
	local scale = alertFrame:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.5
	Theme.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	SoundController.Play("Alarm")
	task.delay(0.35, function()
		SoundController.Play("Alarm")
	end)
	-- borde rojo parpadeante
	edge.Visible = true
	for i = 1, 6 do
		task.delay((i - 1) * 0.3, function()
			edge.BackgroundTransparency = 1
			Theme.Tween(edge, 0.15, { BackgroundTransparency = 0.75 })
			task.wait(0.15)
			Theme.Tween(edge, 0.15, { BackgroundTransparency = 1 })
		end)
	end
	task.delay(3.5, function()
		alertFrame.Visible = false
		edge.Visible = false
	end)
end

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 70, 80),
	Color3.fromRGB(70, 220, 110),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(200, 110, 255),
}

function Notifications.Confetti(big: boolean?)
	local count = if big then 110 else 55
	for _ = 1, count do
		local piece = Gui.Create("Frame", {
			BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)],
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			Position = UDim2.new(math.random(), 0, -0.05, 0),
			Rotation = math.random(0, 360),
			ZIndex = 50,
			Parent = screen,
		})
		local duration = 1.8 + math.random() * 1.6
		Theme.Tween(piece, duration, {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.08, 0),
			Rotation = piece.Rotation + math.random(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

function Notifications.Start(parent: ScreenGui)
	screen = parent
	stack = Gui.Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 300),
		Position = UDim2.new(0.5, 0, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = screen,
	})
	Theme.AutoScale(stack)
	Gui.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top).Parent = stack

	edge = Gui.Create("Frame", {
		Name = "AlertEdge",
		BackgroundColor3 = Color3.fromRGB(255, 0, 30),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 0,
		Parent = screen,
	})
	-- el centro del borde es transparente: usamos un marco interior con agujero simulado por 4 barras
	edge.BackgroundTransparency = 1
	for _, def in {
		{ UDim2.new(1, 0, 0.08, 0), UDim2.new(0, 0, 0, 0) },
		{ UDim2.new(1, 0, 0.08, 0), UDim2.new(0, 0, 0.92, 0) },
		{ UDim2.new(0.05, 0, 1, 0), UDim2.new(0, 0, 0, 0) },
		{ UDim2.new(0.05, 0, 1, 0), UDim2.new(0.95, 0, 0, 0) },
	} do
		Gui.Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 0, 30),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = def[1],
			Position = def[2],
			Parent = edge,
		}, {
			Gui.Create("UIGradient", {
				Transparency = NumberSequence.new(0, 1),
				Rotation = if def[1].X.Scale == 1 then (if def[2].Y.Scale > 0.5 then -90 else 90) else (if def[2].X.Scale > 0.5 then 180 else 0),
			}),
		})
	end

	local alertHolder = Gui.Create("Frame", {
		Name = "AlertHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(640, 70),
		Position = UDim2.new(0.5, 0, 0, 62),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 30,
		Parent = screen,
	})
	Theme.AutoScale(alertHolder)
	alertFrame = Theme.Panel({
		Name = "Alert",
		Size = UDim2.fromScale(1, 1),
		Color = Theme.Colors.Red,
		Parent = alertHolder,
	})
	alertFrame.Visible = false
	alertFrame.ZIndex = 30
	Gui.Create("UIScale", { Scale = 1, Parent = alertFrame })
	alertText = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 3,
		ZIndex = 31,
		Parent = alertFrame,
	})

	Remotes.Event("Notify").OnClientEvent:Connect(function(text, kind, extra)
		if type(text) ~= "string" then
			return
		end
		Notifications.Toast(text, kind, extra)
		if kind == "Event" then
			local color = if type(extra) == "table" and typeof(extra.Color) == "Color3" then extra.Color else nil
			Notifications.Center(string.split(text, " — ")[1], color)
		end
	end)
	Remotes.Event("Alert").OnClientEvent:Connect(function(thief, label)
		Notifications.Alert(tostring(thief), tostring(label))
	end)
end

return Notifications
