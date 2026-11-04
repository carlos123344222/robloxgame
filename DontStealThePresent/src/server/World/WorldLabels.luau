-- Textos de los carteles del mapa (se crean al arrancar, no se hornean).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gui = require(ReplicatedStorage.Shared.Util.Gui)

local WorldLabels = {}

local function signText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local surface = Gui.Create("SurfaceGui", {
		Name = "Label" .. face.Name,
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 36,
		LightInfluence = 0,
		Brightness = 1.6,
		Parent = part,
	})
	local label = Gui.Label({
		Text = text,
		Font = font or Gui.Fonts.Title,
		TextColor3 = color,
		Size = UDim2.fromScale(1, 1),
		StrokeThickness = 4,
		Parent = surface,
	})
	Gui.Padding(10).Parent = label
	return label
end

function WorldLabels.Apply(map: Instance)
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") then
			local text = descendant:GetAttribute("Label")
			if type(text) == "string" and not descendant:FindFirstChild("LabelFront") then
				signText(descendant, Enum.NormalId.Front, text, Color3.fromRGB(255, 240, 200))
			end
			if descendant:GetAttribute("Title") and not descendant:FindFirstChild("LabelRight") then
				for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
					local label = signText(descendant, face, "DON'T STEAL THE PRESENT", Color3.fromRGB(255, 255, 255))
					local sub = Gui.Label({
						Text = "🎁 ¡No robes el regalo! 🎁",
						Font = Gui.Fonts.Bold,
						TextColor3 = Color3.fromRGB(255, 220, 90),
						Size = UDim2.fromScale(1, 0.3),
						Position = UDim2.fromScale(0, 0.72),
						StrokeThickness = 3,
						Parent = label.Parent,
					})
					label.Size = UDim2.fromScale(1, 0.72)
					sub.ZIndex = 2
				end
			end
		end
	end
end

return WorldLabels
