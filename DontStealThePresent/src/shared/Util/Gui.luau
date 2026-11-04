-- Ayudas para crear interfaces por código (servidor: carteles y billboards; cliente: HUD y menús).

local Gui = {}

Gui.Fonts = {
	Title = Enum.Font.LuckiestGuy,
	Bold = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
}

function Gui.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Gui.Corner(radius: number?): UICorner
	return Gui.Create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Gui.CornerScale(scale: number): UICorner
	return Gui.Create("UICorner", { CornerRadius = UDim.new(scale, 0) })
end

function Gui.Stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Gui.Create("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Gui.BorderStroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Gui.Create("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Gui.Gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Gui.Create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function Gui.RainbowGradient(): UIGradient
	return Gui.Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 255, 120)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 200, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 100, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 200)),
		}),
	})
end

-- Texto con borde negro estilo cartoon
function Gui.Label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Gui.Fonts.Bold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	local strokeThickness = base.StrokeThickness
	base.StrokeThickness = nil
	local label = Gui.Create("TextLabel", base)
	if strokeThickness ~= 0 then
		Gui.Stroke(Color3.new(0, 0, 0), strokeThickness or 2).Parent = label
	end
	return label
end

function Gui.Padding(px: number): UIPadding
	return Gui.Create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Gui.List(direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return Gui.Create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Billboard básico en studs (se hace más pequeño con la distancia)
function Gui.Billboard(parent: Instance, sizeStuds: Vector2, offset: Vector3, maxDistance: number?): BillboardGui
	return Gui.Create("BillboardGui", {
		Size = UDim2.new(sizeStuds.X, 0, sizeStuds.Y, 0),
		StudsOffsetWorldSpace = offset,
		MaxDistance = maxDistance or 80,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Parent = parent,
	})
end

return Gui
