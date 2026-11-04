-- HUD: dinero, ingresos, estado del bloqueo, botones de menú, cartel de evento y aviso de "llévalo a tu base".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Rebirths = require(Shared.Config.Rebirths)
local Events = require(Shared.Config.Events)
local Rarities = require(Shared.Config.Rarities)

local Theme = require(script.Parent.Theme)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local player = Players.LocalPlayer

local Hud = {}

Hud.Callbacks = {} :: { [string]: () -> () }

local cashLabel: TextLabel
local incomeLabel: TextLabel
local rebirthLabel: TextLabel
local lockLabel: TextLabel
local lockChip: Frame
local carryHolder: Frame
local carryLabel: TextLabel
local eventHolder: Frame
local eventTitle: TextLabel
local eventDesc: TextLabel
local eventStroke: UIStroke?

local shownCash = 0
local targetCash = 0

local function menuButton(parent: Instance, icon: string, text: string, color: Color3, order: number, key: string)
	local button = Theme.Button({
		Name = key,
		Text = "",
		Color = color,
		Size = UDim2.fromOffset(104, 88),
		LayoutOrder = order,
		Parent = parent,
		OnClick = function()
			local callback = Hud.Callbacks[key]
			if callback then
				callback()
			end
		end,
	})
	Gui.Label({
		Text = icon,
		Size = UDim2.new(1, 0, 0.62, 0),
		Font = Theme.Fonts.Title,
		StrokeThickness = 0,
		Parent = button,
	})
	Gui.Label({
		Text = text,
		Size = UDim2.new(1, 0, 0.36, 0),
		Position = UDim2.fromScale(0, 0.64),
		Font = Theme.Fonts.Title,
		StrokeThickness = 2,
		Parent = button,
	})
	return button
end

local function buildLeft(screen: ScreenGui)
	local holder = Gui.Create("Frame", {
		Name = "LeftHud",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(240, 420),
		Position = UDim2.new(0, 14, 0, 66),
		AnchorPoint = Vector2.new(0, 0),
		Parent = screen,
	})
	Theme.AutoScale(holder)
	Gui.List(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left).Parent = holder

	local cashPanel = Theme.Panel({ Name = "Cash", Size = UDim2.fromOffset(232, 104), Parent = holder, LayoutOrder = 1 })
	Gui.Label({
		Text = "💰",
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(8, 8),
		StrokeThickness = 0,
		Parent = cashPanel,
	})
	cashLabel = Gui.Label({
		Name = "Amount",
		Text = "$0",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -66, 0, 46),
		Position = UDim2.fromOffset(58, 8),
		StrokeThickness = 3,
		Parent = cashPanel,
	})
	Gui.Gradient(Color3.fromRGB(190, 255, 170), Color3.fromRGB(70, 220, 100), 90).Parent = cashLabel
	incomeLabel = Gui.Label({
		Name = "Income",
		Text = "+$0/s",
		Font = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.Income,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.62, -10, 0, 28),
		Position = UDim2.fromOffset(12, 62),
		StrokeThickness = 2,
		Parent = cashPanel,
	})
	rebirthLabel = Gui.Label({
		Name = "Rebirth",
		Text = "⭐ x1",
		Font = Theme.Fonts.Bold,
		TextColor3 = Color3.fromRGB(220, 190, 255),
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.38, -8, 0, 28),
		Position = UDim2.new(0.62, 0, 0, 62),
		StrokeThickness = 2,
		Parent = cashPanel,
	})

	lockChip = Theme.Panel({ Name = "Lock", Size = UDim2.fromOffset(232, 40), Parent = holder, LayoutOrder = 2, Color = Theme.Colors.DarkRed, Radius = 12 })
	lockLabel = Gui.Label({
		Text = "🔓 Tu taller está ABIERTO",
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 2,
		Parent = lockChip,
	})

	local grid = Gui.Create("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(232, 200), Parent = holder, LayoutOrder = 3 })
	Gui.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(108, 90),
		CellPadding = UDim2.fromOffset(12, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	menuButton(grid, "🛒", "TIENDA", Theme.Colors.Green, 1, "Shop")
	menuButton(grid, "⭐", "RENACER", Theme.Colors.Purple, 2, "Rebirth")
	menuButton(grid, "📖", "ÍNDICE", Theme.Colors.Blue, 3, "Index")
	menuButton(grid, "❓", "AYUDA", Theme.Colors.Orange, 4, "Help")

	local mute = Theme.Button({
		Name = "Mute",
		Text = "🔊",
		Color = Theme.Colors.NavyLight,
		Size = UDim2.fromOffset(52, 42),
		LayoutOrder = 4,
		Parent = holder,
	})
	mute.Activated:Connect(function()
		SoundController.SetMuted(not SoundController.Muted)
		mute.Text = if SoundController.Muted then "🔇" else "🔊"
	end)
end

local function buildCarry(screen: ScreenGui)
	carryHolder = Gui.Create("Frame", {
		Name = "CarryHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 64),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = screen,
	})
	Theme.AutoScale(carryHolder)
	local panel = Theme.Panel({ Size = UDim2.fromScale(1, 1), Color = Theme.Colors.DarkGold, Parent = carryHolder })
	carryLabel = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 3,
		Parent = panel,
	})
end

local function buildEvent(screen: ScreenGui)
	eventHolder = Gui.Create("Frame", {
		Name = "EventHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(520, 78),
		Position = UDim2.new(0.5, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		Parent = screen,
	})
	Theme.AutoScale(eventHolder)
	local panel = Theme.Panel({ Name = "EventPanel", Size = UDim2.fromScale(1, 1), Color = Theme.Colors.Blue, Parent = eventHolder })
	eventStroke = panel:FindFirstChildOfClass("UIStroke")
	eventTitle = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -20, 0.56, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		StrokeThickness = 3,
		Parent = panel,
	})
	eventDesc = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextColor3 = Color3.fromRGB(230, 240, 255),
		Size = UDim2.new(1, -20, 0.34, 0),
		Position = UDim2.new(0.5, 0, 0.6, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		StrokeThickness = 2,
		Parent = panel,
	})
end

local function refreshData()
	local data = ClientState.Data
	targetCash = data.Cash or 0
	local rebirths = data.Rebirths or 0
	rebirthLabel.Text = string.format("⭐ x%s", Format.Number(Rebirths.IncomeMultiplier(rebirths)))
end

local lastEventId = ""

local function update(dt: number)
	-- el dinero sube/baja con animación
	if math.abs(targetCash - shownCash) < 1 then
		shownCash = targetCash
	else
		shownCash += (targetCash - shownCash) * math.min(1, dt * 10)
	end
	cashLabel.Text = Format.Cash(shownCash)
	local income = (player:GetAttribute("Income") :: number?) or 0
	incomeLabel.Text = "+" .. Format.Income(income)

	-- bloqueo de tu base
	local base = ClientState.MyBase()
	if base then
		lockChip.Visible = true
		local locked, remaining = ClientState.IsMyBaseLocked()
		if locked then
			lockLabel.Text = "🔒 Bloqueado " .. Format.Clock(remaining)
			lockChip.BackgroundColor3 = Color3.new(1, 1, 1)
			local gradient = lockChip:FindFirstChildOfClass("UIGradient") :: UIGradient
			gradient.Color = ColorSequence.new(Color3.fromRGB(60, 200, 110), Color3.fromRGB(20, 120, 60))
		else
			local blink = (os.clock() % 1) < 0.5
			lockLabel.Text = if blink then "🔓 ¡Tu taller está ABIERTO!" else "🔓 Pisa el botón rojo para cerrar"
			local gradient = lockChip:FindFirstChildOfClass("UIGradient") :: UIGradient
			gradient.Color = ColorSequence.new(Color3.fromRGB(230, 70, 80), Color3.fromRGB(140, 20, 34))
		end
	else
		lockChip.Visible = false
	end

	-- llevando un regalo robado
	local carrying = player:GetAttribute("Carrying")
	if type(carrying) == "string" then
		carryHolder.Visible = true
		local endsAt = (player:GetAttribute("CarryEndsAt") :: number?) or 0
		local remaining = endsAt - ClientState.Now()
		carryLabel.Text = string.format("🏃 ¡Lleva %s a tu taller!  ⏱ %d", carrying, math.max(0, math.ceil(remaining)))
		local rarity = Rarities.Get((player:GetAttribute("CarryingRarity") :: string?) or "Common")
		carryLabel.TextColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4)
	else
		carryHolder.Visible = false
	end

	-- evento activo
	local eventId = workspace:GetAttribute("EventId")
	local event = Events.Get(if type(eventId) == "string" then eventId else nil)
	if event then
		local endsAt = (workspace:GetAttribute("EventEndsAt") :: number?) or 0
		local remaining = endsAt - ClientState.Now()
		if remaining > 0 then
			eventHolder.Visible = true
			eventTitle.Text = event.Name .. "   " .. Format.Clock(remaining)
			eventDesc.Text = event.Description
			if lastEventId ~= event.Id then
				lastEventId = event.Id
				local panel = eventHolder:FindFirstChild("EventPanel") :: Frame
				local gradient = panel:FindFirstChildOfClass("UIGradient") :: UIGradient
				gradient.Color = ColorSequence.new(event.Color, event.Color:Lerp(Color3.new(0, 0, 0), 0.45))
				if eventStroke then
					eventStroke.Color = event.Color:Lerp(Color3.new(0, 0, 0), 0.7)
				end
			end
		else
			eventHolder.Visible = false
		end
	else
		eventHolder.Visible = false
		lastEventId = ""
	end
end

function Hud.Start(screen: ScreenGui)
	buildLeft(screen)
	buildCarry(screen)
	buildEvent(screen)
	ClientState.Changed:Connect(refreshData)
	refreshData()
	shownCash = targetCash
	RunService.RenderStepped:Connect(update)
end

-- Posición del botón de dinero (para efectos que vuelan hacia él)
function Hud.CashLabel(): TextLabel
	return cashLabel
end

return Hud
