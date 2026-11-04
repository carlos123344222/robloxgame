-- Tienda del Elfo: compra gears permanentes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Gears = require(Shared.Config.Gears)
local Remotes = require(Shared.Net.Remotes)

local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Notifications)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local ShopUI = {}

local modal: Theme.Modal
local cards: { [string]: { Button: TextButton, Price: TextLabel } } = {}

local function refresh()
	local data = ClientState.Data
	for gearId, card in cards do
		local info = Gears.Get(gearId)
		if info then
			local owned = data.Gears and data.Gears[gearId]
			if owned or info.Price == 0 then
				card.Button.Text = "✓ TUYO"
				Theme.Recolor(card.Button, Theme.Colors.Gray)
			elseif (data.Cash or 0) >= info.Price then
				card.Button.Text = "COMPRAR"
				Theme.Recolor(card.Button, Theme.Colors.Green)
			else
				card.Button.Text = "COMPRAR"
				Theme.Recolor(card.Button, Theme.Colors.Red)
			end
			card.Price.Text = if info.Price == 0 then "GRATIS" else Format.Cash(info.Price)
		end
	end
end

local busy = false

local function buy(gearId: string)
	if busy then
		return
	end
	local data = ClientState.Data
	if data.Gears and data.Gears[gearId] then
		Notifications.Toast("Ya tienes este objeto: está en tu mochila.", "Info")
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return Remotes.Function("BuyGear"):InvokeServer(gearId)
	end)
	busy = false
	if not ok then
		Notifications.Toast("Error al comprar. Inténtalo otra vez.", "Error")
	elseif not success then
		Notifications.Toast("💸 " .. tostring(message), "Error")
		SoundController.Play("NoMoney")
	end
	refresh()
end

function ShopUI.Start(screen: ScreenGui)
	modal = Theme.Modal(screen, "🛒 TIENDA DEL ELFO", Theme.Colors.Green, Vector2.new(700, 500))
	local scroller = Gui.Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Snow,
		ZIndex = 22,
		Parent = modal.Content,
	})
	Gui.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(206, 300),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroller,
	})
	Gui.Padding(6).Parent = scroller
	for order, gearId in Gears.Order do
		local info = Gears.Get(gearId)
		if info then
			local card = Theme.Panel({ Name = gearId, Size = UDim2.fromOffset(206, 300), Color = Theme.Colors.NavyLight, Parent = scroller, LayoutOrder = order })
			card.ZIndex = 23
			local iconBg = Gui.Create("Frame", {
				BackgroundColor3 = info.Color,
				Size = UDim2.fromOffset(96, 96),
				Position = UDim2.new(0.5, 0, 0, 12),
				AnchorPoint = Vector2.new(0.5, 0),
				ZIndex = 24,
				Parent = card,
			}, { Gui.CornerScale(0.5), Gui.BorderStroke(Theme.Darker(info.Color, 0.6), 3) })
			Gui.Label({ Text = info.Icon, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), StrokeThickness = 0, ZIndex = 25, Parent = iconBg })
			Gui.Label({
				Text = info.FullName,
				Font = Theme.Fonts.Title,
				Size = UDim2.new(1, -16, 0, 30),
				Position = UDim2.new(0.5, 0, 0, 114),
				AnchorPoint = Vector2.new(0.5, 0),
				StrokeThickness = 2,
				ZIndex = 24,
				Parent = card,
			})
			Gui.Label({
				Text = info.Description,
				Font = Theme.Fonts.Body,
				TextColor3 = Color3.fromRGB(210, 220, 245),
				TextWrapped = true,
				Size = UDim2.new(1, -20, 0, 60),
				Position = UDim2.new(0.5, 0, 0, 146),
				AnchorPoint = Vector2.new(0.5, 0),
				StrokeThickness = 0,
				ZIndex = 24,
				Parent = card,
			})
			local price = Gui.Label({
				Text = Format.Cash(info.Price),
				Font = Theme.Fonts.Title,
				TextColor3 = Theme.Colors.Money,
				Size = UDim2.new(1, -16, 0, 30),
				Position = UDim2.new(0.5, 0, 0, 208),
				AnchorPoint = Vector2.new(0.5, 0),
				StrokeThickness = 2,
				ZIndex = 24,
				Parent = card,
			})
			local button = Theme.Button({
				Text = "COMPRAR",
				Color = Theme.Colors.Green,
				Size = UDim2.new(1, -28, 0, 44),
				Position = UDim2.new(0.5, 0, 1, -12),
				AnchorPoint = Vector2.new(0.5, 1),
				Parent = card,
				OnClick = function()
					buy(gearId)
				end,
			})
			button.ZIndex = 25
			local shadow = (button.Parent :: Frame):FindFirstChild("Shadow") :: Frame
			shadow.ZIndex = 24
			cards[gearId] = { Button = button, Price = price }
		end
	end
	modal.OnOpen = refresh
	ClientState.Changed:Connect(function()
		if modal.IsOpen then
			refresh()
		end
	end)
	refresh()
end

function ShopUI.Open()
	modal:Open()
end

function ShopUI.Toggle()
	if modal.IsOpen then
		modal:Close()
	else
		modal:Open()
	end
end

return ShopUI
