-- Carteles flotantes y prompts de los regalos (en la cinta y en los pedestales).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Presents = require(Shared.Config.Presents)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)

local PresentDisplay = {}

local GREEN = Color3.fromRGB(110, 255, 120)
local YELLOW = Color3.fromRGB(255, 226, 80)

local function line(parent: Instance, text: string, color: Color3, height: number, order: number, font: Enum.Font?): TextLabel
	return Gui.Label({
		Name = "Line" .. order,
		Text = text,
		TextColor3 = color,
		Font = font or Gui.Fonts.Bold,
		Size = UDim2.new(1, 0, height, 0),
		LayoutOrder = order,
		Parent = parent,
		StrokeThickness = 2,
	})
end

local function rarityLine(parent: Instance, rarityId: string, height: number, order: number)
	local rarity = Rarities.Get(rarityId)
	local label = line(parent, rarity.Name, rarity.Color, height, order, Gui.Fonts.Title)
	if rarity.Rainbow then
		label.TextColor3 = Color3.new(1, 1, 1)
		Gui.RainbowGradient().Parent = label
		label:AddTag("RainbowText")
	end
	return label
end

local function mutationLine(parent: Instance, mutationId: string?, height: number, order: number)
	local mutation = Mutations.Get(mutationId)
	if not mutation then
		return
	end
	local label = line(parent, mutation.Name .. "  x" .. mutation.Mult, mutation.TextColor, height, order, Gui.Fonts.Title)
	if mutation.Rainbow then
		Gui.RainbowGradient().Parent = label
		label:AddTag("RainbowText")
	end
end

function PresentDisplay.Price(presentId: string, mutationId: string?): number
	local info = Presents.Get(presentId)
	if not info then
		return 0
	end
	return math.floor(info.Price * Mutations.Multiplier(mutationId))
end

function PresentDisplay.BaseIncome(presentId: string, mutationId: string?): number
	local info = Presents.Get(presentId)
	if not info then
		return 0
	end
	return info.Income * Mutations.Multiplier(mutationId)
end

local function holder(model: Model): Attachment
	local root = model.PrimaryPart :: BasePart
	return root:FindFirstChild("Top") :: Attachment
end

-- Cartel completo de un regalo en la cinta
function PresentDisplay.Belt(model: Model, presentId: string, mutationId: string?)
	local info = Presents.Get(presentId)
	if not info then
		return
	end
	local billboard = Gui.Billboard(holder(model), Vector2.new(10, 5.6), Vector3.new(0, 2.9, 0), 90)
	billboard.Name = "Info"
	local frame = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = billboard })
	Gui.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom).Parent = frame
	mutationLine(frame, mutationId, 0.17, 1)
	line(frame, info.Name, Color3.new(1, 1, 1), 0.21, 2)
	rarityLine(frame, info.Rarity, 0.17, 3)
	line(frame, Format.Income(PresentDisplay.BaseIncome(presentId, mutationId)), YELLOW, 0.17, 4)
	line(frame, Format.Cash(PresentDisplay.Price(presentId, mutationId)), GREEN, 0.25, 5, Gui.Fonts.Title)
end

-- Cartel de un regalo en un pedestal
function PresentDisplay.Slot(model: Model, presentId: string, mutationId: string?, incomePerSecond: number)
	local info = Presents.Get(presentId)
	if not info then
		return
	end
	local billboard = Gui.Billboard(holder(model), Vector2.new(8, 3.6), Vector3.new(0, 1.8, 0), 70)
	billboard.Name = "Info"
	local frame = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = billboard })
	Gui.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom).Parent = frame
	mutationLine(frame, mutationId, 0.24, 1)
	line(frame, info.Name, Color3.new(1, 1, 1), 0.28, 2)
	rarityLine(frame, info.Rarity, 0.22, 3)
	line(frame, Format.Income(incomePerSecond), YELLOW, 0.26, 4).Name = "Income"
end

function PresentDisplay.Prompt(parent: Instance, props: { [string]: any }): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.Style = Enum.ProximityPromptStyle.Default
	for key, value in props do
		(prompt :: any)[key] = value
	end
	prompt.Parent = parent
	return prompt
end

-- Pilar de luz para los regalos legendarios o mejores
function PresentDisplay.LightPillar(model: Model, color: Color3)
	local root = model.PrimaryPart :: BasePart
	local bottom = Instance.new("Attachment")
	bottom.Name = "PillarBottom"
	bottom.Parent = root
	local top = Instance.new("Attachment")
	top.Name = "PillarTop"
	top.Position = Vector3.new(0, 70, 0)
	top.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = "Pillar"
	beam.Attachment0 = bottom
	beam.Attachment1 = top
	beam.Color = ColorSequence.new(color)
	beam.Width0 = 2.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Segments = 1
	beam.Parent = root
end

return PresentDisplay
