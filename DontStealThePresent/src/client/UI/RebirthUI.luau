-- Ventana de renacer: qué ganas, qué necesitas y botón para hacerlo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gui = require(Shared.Util.Gui)
local Format = require(Shared.Util.Format)
local Rebirths = require(Shared.Config.Rebirths)
local Rarities = require(Shared.Config.Rarities)
local Presents = require(Shared.Config.Presents)
local Remotes = require(Shared.Net.Remotes)

local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Notifications)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local RebirthUI = {}

local modal: Theme.Modal
local levelLabel: TextLabel
local rows: { TextLabel } = {}
local reqCash: TextLabel
local reqRarity: TextLabel
local button: TextButton

local function hasRarity(rarityId: string): boolean
	local needed = Rarities.Get(rarityId).Index
	for _, entry in ClientState.Data.Presents or {} do
		local info = Presents.Get(entry.Id)
		if info and Rarities.Get(info.Rarity).Index >= needed then
			return true
		end
	end
	return false
end

local function refresh()
	local data = ClientState.Data
	local current = data.Rebirths or 0
	local requirement = Rebirths.Requirement(current)
	levelLabel.Text = string.format("Renacimiento actual: %d", current)
	if not requirement then
		rows[1].Text = "¡Has llegado al renacimiento máximo! 👑"
		rows[2].Text = ""
		rows[3].Text = ""
		reqCash.Text = ""
		reqRarity.Text = ""
		button.Text = "MÁXIMO"
		Theme.Recolor(button, Theme.Colors.Gray)
		return
	end
	local nextLevel = requirement.Level
	rows[1].Text = string.format("💰 Ingresos:  x%s  ➜  x%s", Format.Number(Rebirths.IncomeMultiplier(current)), Format.Number(Rebirths.IncomeMultiplier(nextLevel)))
	rows[2].Text = string.format("🎁 Huecos:  %d  ➜  %d", Rebirths.SlotCount(current), Rebirths.SlotCount(nextLevel))
	rows[3].Text = string.format("🔒 Bloqueo:  %ds  ➜  %ds", Rebirths.LockDuration(current), Rebirths.LockDuration(nextLevel))
	local cashOk = (data.Cash or 0) >= requirement.Cost
	local rarityOk = hasRarity(requirement.Rarity)
	reqCash.Text = string.format("%s  Tener %s  (tienes %s)", if cashOk then "✅" else "❌", Format.Cash(requirement.Cost), Format.Cash(data.Cash or 0))
	reqCash.TextColor3 = if cashOk then Theme.Colors.Money else Color3.fromRGB(255, 140, 140)
	reqRarity.Text = string.format("%s  Un regalo %s o mejor en tu taller", if rarityOk then "✅" else "❌", requirement.RarityName)
	reqRarity.TextColor3 = if rarityOk then Theme.Colors.Money else Color3.fromRGB(255, 140, 140)
	button.Text = "⭐ RENACER"
	Theme.Recolor(button, if cashOk and rarityOk then Theme.Colors.Purple else Theme.Colors.Gray)
end

local busy = false

local function doRebirth()
	if busy then
		return
	end
	busy = true
	local ok, success, message = pcall(function()
		return Remotes.Function("Rebirth"):InvokeServer("rebirth")
	end)
	busy = false
	if not ok then
		Notifications.Toast("Error al renacer. Inténtalo otra vez.", "Error")
	elseif not success then
		Notifications.Toast("⭐ " .. tostring(message), "Error")
		SoundController.Play("NoMoney")
	else
		modal:Close()
		Notifications.Center("⭐ ¡RENACIMIENTO! ⭐", Color3.fromRGB(220, 180, 255))
	end
	refresh()
end

function RebirthUI.Start(screen: ScreenGui)
	modal = Theme.Modal(screen, "⭐ RENACER", Theme.Colors.Purple, Vector2.new(600, 470))
	local list = Gui.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = modal.Content })
	Gui.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = list
	levelLabel = Gui.Label({ Text = "", Font = Theme.Fonts.Title, Size = UDim2.new(1, 0, 0, 34), TextColor3 = Color3.fromRGB(220, 190, 255), ZIndex = 23, LayoutOrder = 1, Parent = list })
	Gui.Label({ Text = "Al renacer consigues PARA SIEMPRE:", Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 26), ZIndex = 23, LayoutOrder = 2, StrokeThickness = 2, Parent = list })
	for i = 1, 3 do
		rows[i] = Gui.Label({ Text = "", Font = Theme.Fonts.Bold, TextColor3 = Theme.Colors.Income, Size = UDim2.new(1, 0, 0, 30), ZIndex = 23, LayoutOrder = 2 + i, Parent = list })
	end
	Gui.Label({ Text = "Necesitas:", Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 26), ZIndex = 23, LayoutOrder = 7, StrokeThickness = 2, Parent = list })
	reqCash = Gui.Label({ Text = "", Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 28), ZIndex = 23, LayoutOrder = 8, Parent = list })
	reqRarity = Gui.Label({ Text = "", Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 28), ZIndex = 23, LayoutOrder = 9, Parent = list })
	Gui.Label({
		Text = "⚠️ Perderás tu dinero y tus regalos. Los objetos de la tienda se quedan.",
		Font = Theme.Fonts.Body,
		TextColor3 = Color3.fromRGB(255, 200, 150),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 23,
		LayoutOrder = 10,
		StrokeThickness = 0,
		Parent = list,
	})
	button = Theme.Button({
		Text = "⭐ RENACER",
		Color = Theme.Colors.Purple,
		Size = UDim2.fromOffset(280, 58),
		LayoutOrder = 11,
		Parent = list,
		OnClick = doRebirth,
		Sound = "Click",
	})
	button.ZIndex = 24
	local shadow = (button.Parent :: Frame):FindFirstChild("Shadow") :: Frame
	shadow.ZIndex = 23
	modal.OnOpen = refresh
	ClientState.Changed:Connect(function()
		if modal.IsOpen then
			refresh()
		end
	end)
end

function RebirthUI.Open()
	modal:Open()
end

function RebirthUI.Toggle()
	if modal.IsOpen then
		modal:Close()
	else
		modal:Open()
	end
end

return RebirthUI
