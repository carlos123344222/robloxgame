-- Pantalla de bienvenida con el logo animado y la ventana de ayuda "¿Cómo se juega?".

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local GameConfig = require(Shared.Config.GameConfig)

local Theme = require(script.Parent.Theme)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local IntroUI = {}

local helpModal: Theme.Modal

local STEPS = {
	{ "🎁", "COMPRA", "Los regalos salen de la Fábrica de Santa por la cinta. Acércate y pulsa E para comprarlos." },
	{ "💰", "COBRA", "Cada regalo de tu taller genera dinero. Pisa la placa verde de delante para cobrarlo." },
	{ "😈", "ROBA", "Entra en otro taller abierto, mantén E sobre un regalo y llévalo corriendo a tu taller." },
	{ "🔒", "PROTEGE", "Pisa el botón rojo de tu taller para bloquearlo. ¡Golpea a los ladrones con el bastón!" },
	{ "⭐", "RENACE", "Junta mucho dinero y un regalo raro para renacer: ganarás más y tendrás más huecos." },
}

local function stepRow(parent: Instance, index: number, step: { string })
	local row = Theme.Panel({ Name = "Step" .. index, Size = UDim2.new(1, -8, 0, 70), Color = Theme.Colors.NavyLight, Parent = parent, LayoutOrder = index, Radius = 14 })
	row.ZIndex = 23
	local badge = Gui.Create("Frame", {
		BackgroundColor3 = Theme.Colors.Gold,
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 24,
		Parent = row,
	}, { Gui.CornerScale(0.5), Gui.BorderStroke(Theme.Colors.DarkGold, 3) })
	Gui.Label({ Text = step[1], Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), StrokeThickness = 0, ZIndex = 25, Parent = badge })
	Gui.Label({
		Text = index .. ". " .. step[2],
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.new(1, -84, 0, 24),
		Position = UDim2.fromOffset(74, 6),
		ZIndex = 24,
		StrokeThickness = 2,
		Parent = row,
	})
	Gui.Label({
		Text = step[3],
		Font = Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(225, 232, 250),
		Size = UDim2.new(1, -84, 0, 34),
		Position = UDim2.fromOffset(74, 30),
		ZIndex = 24,
		StrokeThickness = 0,
		Parent = row,
	})
end

function IntroUI.OpenHelp()
	helpModal:Open()
end

function IntroUI.ToggleHelp()
	if helpModal.IsOpen then
		helpModal:Close()
	else
		helpModal:Open()
	end
end

local function showSplash(screen: ScreenGui)
	local splash = Gui.Create("Frame", {
		Name = "Splash",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		Parent = screen,
	}, { Gui.Gradient(Color3.fromRGB(20, 30, 80), Color3.fromRGB(6, 10, 30), 90) })
	-- copos de nieve
	local flakes = {}
	for i = 1, 70 do
		local size = math.random(4, 10)
		local flake = Gui.Create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = math.random() * 0.5,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromScale(math.random(), math.random()),
			ZIndex = 61,
			Parent = splash,
		}, { Gui.CornerScale(0.5) })
		flakes[i] = { Frame = flake, Speed = 0.04 + math.random() * 0.08, Drift = (math.random() - 0.5) * 0.03 }
	end
	local content = Gui.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(900, 520),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 62,
		Parent = splash,
	})
	Theme.AutoScale(content)
	local gift = Gui.Label({ Text = "🎁", Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), StrokeThickness = 0, ZIndex = 63, Parent = content })
	local title = Gui.Label({
		Text = "DON'T STEAL THE PRESENT",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, 0, 0, 100),
		Position = UDim2.fromOffset(0, 150),
		ZIndex = 63,
		StrokeThickness = 6,
		Parent = content,
	})
	Gui.Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 230, 120)),
		}),
		Parent = title,
	})
	Gui.Label({
		Text = "🎄 " .. GameConfig.GameNameEs .. " 🎄",
		Font = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 254),
		ZIndex = 63,
		StrokeThickness = 3,
		Parent = content,
	})
	Gui.Label({
		Text = "Compra regalos · Roba los de los demás · Protege tu taller",
		Font = Theme.Fonts.Body,
		TextColor3 = Color3.fromRGB(210, 222, 255),
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 304),
		ZIndex = 63,
		StrokeThickness = 0,
		Parent = content,
	})
	local play: TextButton
	local closing = false
	local connection: RBXScriptConnection
	local function close()
		if closing then
			return
		end
		closing = true
		SoundController.Play("Success")
		for _, d in splash:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				Theme.Tween(d, 0.4, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				Theme.Tween(d, 0.4, { Transparency = 1 })
			elseif d:IsA("Frame") then
				Theme.Tween(d, 0.4, { BackgroundTransparency = 1 })
			end
		end
		Theme.Tween(splash, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.55, function()
			connection:Disconnect()
			splash:Destroy()
		end)
	end
	play = Theme.Button({
		Text = "🎅 ¡A JUGAR!",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(320, 76),
		Position = UDim2.new(0.5, 0, 0, 360),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = content,
		OnClick = close,
	})
	play.ZIndex = 65
	local playShadow = (play.Parent :: Frame):FindFirstChild("Shadow") :: Frame
	playShadow.ZIndex = 64
	local help = Theme.Button({
		Text = "❓ ¿Cómo se juega?",
		Color = Theme.Colors.Blue,
		Size = UDim2.fromOffset(260, 50),
		Position = UDim2.new(0.5, 0, 0, 452),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = content,
		OnClick = function()
			close()
			task.delay(0.6, IntroUI.OpenHelp)
		end,
	})
	help.ZIndex = 65
	local helpShadow = (help.Parent :: Frame):FindFirstChild("Shadow") :: Frame
	helpShadow.ZIndex = 64

	local giftScale = Gui.Create("UIScale", { Scale = 0.2, Parent = gift })
	Theme.Tween(giftScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Elastic)
	local titleScale = Gui.Create("UIScale", { Scale = 0.4, Parent = title })
	Theme.Tween(titleScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		gift.Rotation = math.sin(t * 2.2) * 8
		title.Rotation = math.sin(t * 1.3) * 1.5
		for _, f in flakes do
			local pos = f.Frame.Position
			local y = pos.Y.Scale + f.Speed * dt
			local x = pos.X.Scale + f.Drift * dt
			if y > 1.02 then
				y = -0.02
				x = math.random()
			end
			f.Frame.Position = UDim2.fromScale(x, y)
		end
	end)
	task.delay(25, close)
end

function IntroUI.Start(screen: ScreenGui)
	helpModal = Theme.Modal(screen, "❓ ¿CÓMO SE JUEGA?", Theme.Colors.Orange, Vector2.new(640, 520))
	local list = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = helpModal.Content })
	Gui.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = list
	for i, step in STEPS do
		stepRow(list, i, step)
	end
	Gui.Label({
		Text = "Consejo: los regalos con pilar de luz son LEGENDARIOS o mejores. ¡Corre a por ellos!",
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Income,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 10,
		ZIndex = 23,
		StrokeThickness = 0,
		Parent = list,
	})
	showSplash(screen)
end

return IntroUI
