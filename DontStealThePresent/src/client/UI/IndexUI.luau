-- Índice de regalos: todos los regalos del juego con vista 3D; los que no has conseguido salen en sombra.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Presents = require(Shared.Config.Presents)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local PresentBuilder = require(Shared.PresentBuilder)

local Theme = require(script.Parent.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local IndexUI = {}

type Card = {
	Frame: Frame,
	Viewport: ViewportFrame,
	Name: TextLabel,
	Info: TextLabel,
	Dots: { [string]: Frame },
	Model: Model?,
	Discovered: boolean?,
	Distance: number,
	Height: number,
}

local modal: Theme.Modal
local cards: { [string]: Card } = {}
local counter: TextLabel
local built = false
local spinConnection: RBXScriptConnection? = nil

local MUTATION_KEYS = { "Normal", "Gold", "Diamond", "Frost", "Candy", "Rainbow" }

local function setSilhouette(model: Model, silhouette: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Name ~= "Hub" then
			if silhouette then
				d:SetAttribute("OriginalColor", d:GetAttribute("OriginalColor") or d.Color)
				d.Color = Color3.fromRGB(8, 10, 20)
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

local function fillViewport(card: Card, presentId: string, discovered: boolean)
	if card.Model and card.Discovered == discovered then
		return
	end
	if card.Model then
		card.Model:Destroy()
	end
	local model = PresentBuilder.Build(presentId, nil, { NoEffects = true })
	local height = PresentBuilder.GetHeight(model)
	setSilhouette(model, not discovered)
	model.Parent = card.Viewport
	card.Model = model
	card.Discovered = discovered
	local camera = card.Viewport.CurrentCamera or Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = card.Viewport
	card.Viewport.CurrentCamera = camera
	local size = math.max(height, (model.PrimaryPart :: BasePart).Size.X * 2.2)
	local distance = size * 1.9 + 2
	camera.CFrame = CFrame.lookAt(Vector3.new(0, height * 0.62, -distance), Vector3.new(0, height * 0.45, 0))
	card.Distance = distance
	card.Height = height
end

local function refresh()
	local index = ClientState.Data.Index or {}
	local found, total = 0, 0
	for _, info in Presents.List do
		total += 1
		local card = cards[info.Id]
		local entry = index[info.Id]
		local discovered = entry ~= nil and next(entry) ~= nil
		if discovered then
			found += 1
		end
		if card then
			fillViewport(card, info.Id, discovered)
			card.Name.Text = if discovered then info.Name else "???"
			local rarity = Rarities.Get(info.Rarity)
			card.Info.Text = if discovered then Format.Income(info.Income) else rarity.Name
			for key, dot in card.Dots do
				local has = entry ~= nil and entry[key] == true
				dot.BackgroundTransparency = if has then 0 else 0.75
			end
		end
	end
	counter.Text = string.format("📖 Descubiertos: %d / %d", found, total)
end

local function build()
	if built then
		return
	end
	built = true
	local scroller = modal.Content:FindFirstChild("Scroller") :: ScrollingFrame
	for order, info in Presents.List do
		local rarity = Rarities.Get(info.Rarity)
		local frame = Theme.Panel({
			Name = info.Id,
			Size = UDim2.fromOffset(150, 196),
			Color = rarity.Dark,
			Parent = scroller,
			LayoutOrder = order,
			StrokeColor = rarity.Color,
			StrokeThickness = 3,
		})
		frame.ZIndex = 23
		if rarity.Rainbow then
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				Gui.RainbowGradient().Parent = stroke
			end
		end
		local viewport = Gui.Create("ViewportFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 0, 112),
			Position = UDim2.fromOffset(6, 6),
			Ambient = Color3.fromRGB(190, 190, 210),
			LightColor = Color3.fromRGB(255, 250, 240),
			LightDirection = Vector3.new(-0.5, -1, 0.6),
			ZIndex = 24,
			Parent = frame,
		})
		local name = Gui.Label({
			Text = "???",
			Font = Theme.Fonts.Bold,
			Size = UDim2.new(1, -10, 0, 22),
			Position = UDim2.fromOffset(5, 120),
			ZIndex = 24,
			StrokeThickness = 2,
			Parent = frame,
		})
		local rarityLabel = Gui.Label({
			Text = rarity.Name,
			Font = Theme.Fonts.Title,
			TextColor3 = rarity.Color,
			Size = UDim2.new(1, -10, 0, 16),
			Position = UDim2.fromOffset(5, 142),
			ZIndex = 24,
			StrokeThickness = 2,
			Parent = frame,
		})
		if rarity.Rainbow then
			Gui.RainbowGradient().Parent = rarityLabel
			rarityLabel:AddTag("RainbowText")
		end
		local infoLabel = Gui.Label({
			Text = "",
			Font = Theme.Fonts.Bold,
			TextColor3 = Theme.Colors.Income,
			Size = UDim2.new(1, -10, 0, 16),
			Position = UDim2.fromOffset(5, 158),
			ZIndex = 24,
			StrokeThickness = 2,
			Parent = frame,
		})
		local dotsFrame = Gui.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 12),
			Position = UDim2.fromOffset(5, 178),
			ZIndex = 24,
			Parent = frame,
		})
		Gui.List(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center).Parent = dotsFrame
		local dots = {}
		for i, key in MUTATION_KEYS do
			local mutation = Mutations.Get(key)
			local color = if mutation then mutation.TextColor else Color3.fromRGB(230, 230, 240)
			local dot = Gui.Create("Frame", {
				Name = key,
				BackgroundColor3 = color,
				Size = UDim2.fromOffset(12, 12),
				LayoutOrder = i,
				ZIndex = 25,
				Parent = dotsFrame,
			}, { Gui.CornerScale(0.5), Gui.BorderStroke(Color3.new(0, 0, 0), 1) })
			if key == "Rainbow" then
				Gui.RainbowGradient().Parent = dot
			end
			dots[key] = dot
		end
		cards[info.Id] = {
			Frame = frame,
			Viewport = viewport,
			Name = name,
			Info = infoLabel,
			Dots = dots,
			Model = nil,
			Discovered = nil,
			Distance = 10,
			Height = 3,
		}
	end
end

function IndexUI.Start(screen: ScreenGui)
	modal = Theme.Modal(screen, "📖 ÍNDICE DE REGALOS", Theme.Colors.Blue, Vector2.new(860, 560))
	counter = Gui.Label({
		Text = "",
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 23,
		StrokeThickness = 2,
		Parent = modal.Content,
	})
	Gui.Label({
		Text = "Puntos: Normal · Dorado · Diamante · Escarcha · Caramelo · Arcoíris",
		Font = Theme.Fonts.Body,
		TextColor3 = Color3.fromRGB(200, 210, 240),
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 28),
		ZIndex = 23,
		StrokeThickness = 0,
		Parent = modal.Content,
	})
	local scroller = Gui.Create("ScrollingFrame", {
		Name = "Scroller",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.fromOffset(0, 50),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Snow,
		ZIndex = 22,
		Parent = modal.Content,
	})
	Gui.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 196),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroller,
	})
	Gui.Padding(6).Parent = scroller
	modal.OnOpen = function()
		build()
		refresh()
		if not spinConnection then
			spinConnection = RunService.RenderStepped:Connect(function()
				if not modal.IsOpen then
					return
				end
				local angle = os.clock() * 0.8
				local orbit = Vector3.new(math.sin(angle), 0, -math.cos(angle))
				for _, card in cards do
					local camera = card.Viewport.CurrentCamera
					if camera and card.Model then
						local eye = orbit * card.Distance + Vector3.new(0, card.Height * 0.62, 0)
						camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, card.Height * 0.45, 0))
					end
				end
			end)
		end
	end
	ClientState.Changed:Connect(function()
		if modal.IsOpen then
			refresh()
		end
	end)
end

function IndexUI.Open()
	modal:Open()
end

function IndexUI.Toggle()
	if modal.IsOpen then
		modal:Close()
	else
		modal:Open()
	end
end

return IndexUI
