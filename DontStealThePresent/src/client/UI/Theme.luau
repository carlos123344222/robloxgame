-- Estilo de la interfaz: colores navideños, botones con relieve, paneles y ventanas modales animadas.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)

local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Theme = {}

Theme.Colors = {
	Red = Color3.fromRGB(230, 44, 62),
	DarkRed = Color3.fromRGB(150, 16, 34),
	Green = Color3.fromRGB(42, 184, 96),
	DarkGreen = Color3.fromRGB(18, 110, 56),
	Gold = Color3.fromRGB(255, 200, 60),
	DarkGold = Color3.fromRGB(190, 120, 10),
	Blue = Color3.fromRGB(60, 140, 255),
	DarkBlue = Color3.fromRGB(24, 70, 170),
	Purple = Color3.fromRGB(160, 92, 255),
	DarkPurple = Color3.fromRGB(80, 36, 160),
	Orange = Color3.fromRGB(255, 140, 40),
	DarkOrange = Color3.fromRGB(170, 70, 0),
	Navy = Color3.fromRGB(26, 34, 66),
	NavyLight = Color3.fromRGB(44, 58, 110),
	White = Color3.fromRGB(255, 255, 255),
	Snow = Color3.fromRGB(236, 244, 255),
	Gray = Color3.fromRGB(120, 128, 150),
	Money = Color3.fromRGB(110, 255, 120),
	Income = Color3.fromRGB(255, 226, 80),
}

Theme.Fonts = Gui.Fonts

function Theme.Tween(instance: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

Theme.Darker = darker
Theme.Lighter = lighter

-- Escala un bloque de interfaz según el tamaño de pantalla (móvil / PC)
function Theme.AutoScale(target: GuiObject): UIScale
	local uiScale = Gui.Create("UIScale", { Parent = target })
	local camera = workspace.CurrentCamera
	local function update()
		local viewport = camera.ViewportSize
		local s = math.min(viewport.X / 1280, viewport.Y / 760)
		uiScale.Scale = math.clamp(s, 0.55, 1.15)
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return uiScale
end


export type ButtonProps = {
	Text: string,
	Color: Color3?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	Font: Enum.Font?,
	TextColor: Color3?,
	LayoutOrder: number?,
	Name: string?,
	OnClick: (() -> ())?,
	Sound: string?,
}

-- Botón con relieve (sombra inferior), degradado, borde y animación al pasar y pulsar
function Theme.Button(props: ButtonProps): TextButton
	local color = props.Color or Theme.Colors.Green
	local holder = Gui.Create("Frame", {
		Name = props.Name or "Button",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	local shadow = Gui.Create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = darker(color, 0.55),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 5),
		Parent = holder,
	}, { Gui.Corner(14) })
	local button = Gui.Create("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, 0),
		Text = props.Text,
		Font = props.Font or Theme.Fonts.Title,
		TextScaled = true,
		TextColor3 = props.TextColor or Theme.Colors.White,
		Parent = holder,
	}, {
		Gui.Corner(14),
		Gui.Gradient(lighter(color, 0.25), color, 90),
		Gui.BorderStroke(darker(color, 0.6), 3),
		Gui.Create("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
	})
	Gui.Stroke(darker(color, 0.7), 2).Parent = button
	local scale = Gui.Create("UIScale", { Scale = 1, Parent = holder })
	button.MouseEnter:Connect(function()
		Theme.Tween(scale, 0.12, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		Theme.Tween(scale, 0.12, { Scale = 1 })
		Theme.Tween(button, 0.08, { Position = UDim2.new() })
	end)
	button.MouseButton1Down:Connect(function()
		Theme.Tween(button, 0.06, { Position = UDim2.new(0, 0, 0, 4) })
	end)
	button.MouseButton1Up:Connect(function()
		Theme.Tween(button, 0.08, { Position = UDim2.new() })
	end)
	button.Activated:Connect(function()
		SoundController.Play(props.Sound or "Click")
		if props.OnClick then
			props.OnClick()
		end
	end)
	shadow.ZIndex = button.ZIndex - 1
	return button
end

-- Cambia el color de un botón creado con Theme.Button
function Theme.Recolor(button: TextButton, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(lighter(color, 0.25), color)
	end
	for _, child in button:GetChildren() do
		if child:IsA("UIStroke") then
			child.Color = darker(color, 0.65)
		end
	end
	local holder = button.Parent
	local shadow = holder and holder:FindFirstChild("Shadow") :: Frame?
	if shadow then
		shadow.BackgroundColor3 = darker(color, 0.55)
	end
end

function Theme.Panel(props: { [string]: any }): Frame
	local color = props.Color or Theme.Colors.Navy
	local frame = Gui.Create("Frame", {
		Name = props.Name or "Panel",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		Parent = props.Parent,
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Gui.Corner(props.Radius or 16),
		Gui.Gradient(lighter(color, 0.12), darker(color, 0.15), 90),
		Gui.BorderStroke(props.StrokeColor or Color3.fromRGB(10, 14, 30), props.StrokeThickness or 3),
	})
	return frame
end

-- Ventanas modales ----------------------------------------------------------------------------------------

export type Modal = {
	Root: Frame,
	Content: Frame,
	Title: TextLabel,
	Open: (self: Modal) -> (),
	Close: (self: Modal) -> (),
	IsOpen: boolean,
	OnOpen: (() -> ())?,
}

local current: Modal? = nil

function Theme.Modal(screen: ScreenGui, title: string, color: Color3, size: Vector2): Modal
	local overlay = Gui.Create("TextButton", {
		Name = title .. "Overlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	})
	local holder = Gui.Create("Frame", {
		Name = "WindowHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = overlay,
	})
	Theme.AutoScale(holder)
	local window = Theme.Panel({
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		Color = Theme.Colors.Navy,
		Parent = holder,
		Radius = 22,
		StrokeThickness = 4,
	})
	window.ZIndex = 21
	local scale = Gui.Create("UIScale", { Scale = 1, Parent = window })
	-- cabecera con "nieve"
	local header = Gui.Create("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 62),
		ZIndex = 22,
		Parent = window,
	}, {
		Gui.Corner(22),
		Gui.Gradient(lighter(color, 0.2), color, 90),
		Gui.BorderStroke(darker(color, 0.6), 3),
	})
	Gui.Create("Frame", {
		Name = "SnowCap",
		BackgroundColor3 = Theme.Colors.Snow,
		Size = UDim2.new(1, -24, 0, 10),
		Position = UDim2.new(0, 12, 0, -4),
		ZIndex = 23,
		Parent = header,
	}, { Gui.Corner(6) })
	for i = 0, 6 do
		Gui.Create("Frame", {
			BackgroundColor3 = Theme.Colors.Snow,
			Size = UDim2.fromOffset(14 + (i % 3) * 4, 12 + (i % 2) * 6),
			Position = UDim2.new(0.08 + i * 0.14, 0, 0, 2),
			ZIndex = 23,
			Parent = header,
		}, { Gui.CornerScale(0.5) })
	end
	local titleLabel = Gui.Label({
		Text = title,
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -140, 0, 44),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 24,
		StrokeThickness = 3,
		Parent = header,
	})
	local modal: Modal
	local close = Theme.Button({
		Name = "Close",
		Text = "X",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -10, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Parent = header,
		OnClick = function()
			modal:Close()
		end,
	})
	close.ZIndex = 25
	local closeShadow = (close.Parent :: Frame):FindFirstChild("Shadow") :: Frame
	closeShadow.ZIndex = 24
	local content = Gui.Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 1, -82),
		Position = UDim2.new(0, 14, 0, 72),
		ZIndex = 22,
		Parent = window,
	})

	modal = {
		Root = overlay :: any,
		Content = content,
		Title = titleLabel,
		IsOpen = false,
		OnOpen = nil,
	} :: any

	function modal.Open(self: Modal)
		if current and current ~= self then
			current:Close()
		end
		current = self
		self.IsOpen = true
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		scale.Scale = 0.6
		Theme.Tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
		Theme.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		SoundController.Play("Open")
		if self.OnOpen then
			self.OnOpen()
		end
	end

	function modal.Close(self: Modal)
		if not self.IsOpen then
			return
		end
		self.IsOpen = false
		if current == self then
			current = nil
		end
		Theme.Tween(overlay, 0.15, { BackgroundTransparency = 1 })
		local tween = Theme.Tween(scale, 0.15, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween.Completed:Once(function()
			if not self.IsOpen then
				overlay.Visible = false
			end
		end)
	end

	overlay.Activated:Connect(function()
		-- clic fuera de la ventana
	end)
	return modal
end

function Theme.CloseAll()
	if current then
		current:Close()
	end
end

return Theme
