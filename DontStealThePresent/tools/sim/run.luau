--!nocheck
-- Partida simulada de principio a fin con el código real del servidor y del cliente.
--
--   lune run tools/sim/run.luau <ruta a Full-API-Dump.json>
--
-- El volcado de la API se descarga de github.com/MaximumADHD/Roblox-Client-Tracker (Full-API-Dump.json).

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local taskLib = require("@lune/task")
local Emu = require("./emu")

local V3 = roblox.Vector3
local CF = roblox.CFrame

local apiPath = process.args[1] or "Full-API-Dump.json"
local projectRoot = process.args[2] or "."
Emu.Quiet = process.env.SIM_VERBOSE == nil

local failures = {}
local passed = 0
local function check(condition, message)
	if condition then
		passed += 1
		print("  \27[32m✓\27[0m " .. message)
	else
		table.insert(failures, message)
		print("  \27[31m✗ " .. message .. "\27[0m")
	end
end
local function section(title)
	print("\n\27[1m== " .. title .. "\27[0m")
end

Emu.LoadApi(apiPath)
local game = Emu.Boot(projectRoot)
local workspace = Emu.workspace
local PPS = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Servidor ---------------------------------------------------------------------------------------------------
section("Arranque del servidor")
local serverScript = game:GetService("ServerScriptService").Server
local serverRequire = Emu.MakeRequire("server")
local started = os.clock()
Emu.RunScript("server", serverScript, serverRequire)
taskLib.wait(0.2)
Emu.Run(0.5)
print(string.format("  (arranque en %.2fs)", os.clock() - started))
local map = workspace:FindFirstChild("Map")
check(map ~= nil, "el mapa se construye al arrancar")
check(map and #map.Bases:GetChildren() == 8, "hay 8 talleres")
check(ReplicatedStorage:FindFirstChild("Remotes") ~= nil, "se crean los remotes")
local items = map.Conveyor.Items
check(#items:GetChildren() > 3, "la cinta empieza con regalos (" .. #items:GetChildren() .. ")")

local Services = serverScript.Services
local DataService = serverRequire(Services.DataService)
local BaseService = serverRequire(Services.BaseService)
local StealService = serverRequire(Services.StealService)
local CharacterService = serverRequire(Services.CharacterService)
local EventService = serverRequire(Services.EventService)
local ConveyorService = serverRequire(Services.ConveyorService)

-- Jugadores --------------------------------------------------------------------------------------------------
section("Entra Alice (jugador local)")
local alice = Emu.AddPlayer("Alice", 1001)
Emu.LocalPlayer = alice
local aliceChar = Emu.SpawnCharacter(alice, V3.new(0, 5, 20))
local clientRequire = Emu.MakeRequire("client")
Emu.RunScript("client", game.StarterPlayer.StarterPlayerScripts.Client, clientRequire)
Emu.Run(1.5)
local aliceData = DataService.Get(alice)
check(aliceData ~= nil, "datos de Alice cargados")
check(aliceData and aliceData.Cash == 100, "Alice empieza con $100")
check(alice:GetAttribute("BaseId") == 1, "Alice tiene el taller 1")
local aliceBase = BaseService.GetBase(alice)
check(alice.Backpack:FindFirstChild("Bastón") ~= nil, "Alice tiene el bastón")
check(alice.PlayerGui:FindFirstChild("DontStealThePresent") ~= nil, "la interfaz del cliente existe")
check(aliceChar.HumanoidRootPart.Position.Z < -20, "Alice aparece en su taller")

local function rootOf(player)
	return player.Character.HumanoidRootPart
end
local function moveTo(player, position, lookAt)
	local root = rootOf(player)
	root.CFrame = if lookAt then CF.lookAt(position, lookAt) else CF.new(position)
end

section("Comprar en la cinta")
DataService.AddCash(alice, 1000000)
local target = nil
for _, model in items:GetChildren() do
	target = model
	break
end
check(target ~= nil, "hay un regalo para comprar")
if target then
	local now = workspace:GetServerTimeNow()
	local x = target:GetAttribute("StartX") + target:GetAttribute("Speed") * (now - target:GetAttribute("SpawnT"))
	moveTo(alice, V3.new(x, 4, 7))
	local prompt = target.Root.Mid.BuyPrompt
	local before = aliceData.Cash
	Emu.Fire(PPS, "PromptTriggered", prompt, alice)
	Emu.Run(0.5)
	check(aliceBase.Slots[1].Present ~= nil, "el regalo comprado va al hueco 1")
	check(aliceData.Cash < before, "se cobra el precio")
	check(target.Parent == nil, "el regalo desaparece de la cinta")
	check(aliceBase.Slots[1].Present and aliceBase.Slots[1].Present.Model ~= nil, "hay modelo en el pedestal")
end

section("Dinero acumulado y cobro")
Emu.Run(2.3)
local stored = aliceBase.Slots[1].Present and aliceBase.Slots[1].Present.Stored or 0
check(stored > 0, "el regalo genera dinero (" .. stored .. ")")
local cashBefore = aliceData.Cash
Emu.Fire(aliceBase.Slots[1].Pad, "Touched", rootOf(alice))
Emu.Run(0.3)
check(aliceData.Cash > cashBefore, "pisar la placa cobra el dinero")

section("Bloqueo")
Emu.Fire(aliceBase.LockButton, "Touched", rootOf(alice))
Emu.Run(0.3)
check(BaseService.IsLocked(aliceBase), "el botón bloquea la base")

section("Entra Bob e intenta robar")
local bob = Emu.AddPlayer("Bob", 1002)
Emu.SpawnCharacter(bob, V3.new(0, 5, -20))
Emu.Run(1)
local bobBase = BaseService.GetBase(bob)
check(bobBase ~= nil and bobBase.Id == 2, "Bob tiene el taller 2")
local slot1 = aliceBase.Slots[1]
local function stealPrompt(slot)
	local present = slot.Present
	return present and present.Model and present.Model.Root.Mid.StealPrompt
end
moveTo(bob, slot1.Pedestal.Position + V3.new(3, 2, 0))
Emu.Fire(PPS, "PromptTriggered", stealPrompt(slot1), bob)
Emu.Run(0.3)
check(not StealService.IsCarrying(bob), "no se puede robar en una base bloqueada")
-- dentro de una base bloqueada te expulsan
check(not BaseService.IsInside(aliceBase, rootOf(bob).Position), "Bob es expulsado de la base bloqueada")

aliceBase.LockedUntil = 0
Emu.Run(0.4)
moveTo(bob, slot1.Pedestal.Position + V3.new(3, 2, 0))
Emu.Fire(PPS, "PromptTriggered", stealPrompt(slot1), bob)
Emu.Run(0.3)
check(StealService.IsCarrying(bob), "Bob roba el regalo")
check(slot1.Present and slot1.Present.BeingStolen, "el hueco queda marcado como robándose")
check(bob:GetAttribute("Carrying") ~= nil, "Bob lleva el regalo (atributo)")
check(bob.Character.Humanoid.WalkSpeed < 18, "Bob va más lento")

section("Alice le da un bastonazo")
local bat = alice.Backpack["Bastón"]
bat.Parent = aliceChar
local bobPos = rootOf(bob).Position
moveTo(alice, bobPos + V3.new(0, 0, 4), bobPos)
Emu.Fire(bat, "Activated")
Emu.Run(0.4)
check(not StealService.IsCarrying(bob), "el golpe hace soltar el regalo")
check(slot1.Present and not slot1.Present.BeingStolen and slot1.Present.Model ~= nil, "el regalo vuelve al pedestal")

section("Bob roba y llega a su taller")
taskLib.wait(1)
moveTo(bob, slot1.Pedestal.Position + V3.new(3, 2, 0))
Emu.Fire(PPS, "PromptTriggered", stealPrompt(slot1), bob)
Emu.Run(0.3)
check(StealService.IsCarrying(bob), "segundo robo")
moveTo(bob, bobBase.CFrame.Position + V3.new(0, 3, 0))
Emu.Run(0.4)
check(not StealService.IsCarrying(bob), "entrega completada")
check(bobBase.Slots[1].Present ~= nil, "el regalo está en el taller de Bob")
check(aliceBase.Slots[1].Present == nil, "Alice lo ha perdido")
check(DataService.Get(bob).Stats.Steals == 1, "se cuenta el robo")

section("Tienda y gears")
local remotes = ReplicatedStorage.Remotes
DataService.AddCash(alice, 50000000)
local ok, msg = remotes.BuyGear:InvokeServer("Snowball")
check(ok == true, "comprar Bola de Nieve (" .. tostring(msg) .. ")")
local ok2 = remotes.BuyGear:InvokeServer("Snowball")
check(ok2 == false, "no se puede comprar dos veces")
check(alice.Backpack:FindFirstChild("Bola de Nieve") ~= nil, "la bola de nieve está en la mochila")
Emu.RaycastHook = function()
	local r = rootOf(bob)
	return { Instance = r, Position = r.Position, Normal = V3.yAxis, Material = roblox.Enum.Material.Plastic, Distance = 5 }
end
local snowball = alice.Backpack["Bola de Nieve"]
bat.Parent = alice.Backpack
snowball.Parent = aliceChar
Emu.Run(0.2)
Emu.MouseHit = CF.new(rootOf(bob).Position)
Emu.Fire(snowball, "Activated")
Emu.Run(0.5)
check(CharacterService.IsFrozen(bob), "la bola de nieve congela a Bob")
Emu.Run(1.6)
check(not CharacterService.IsFrozen(bob), "Bob se descongela")
check(remotes.BuyGear:InvokeServer("FreezeRay") == true, "comprar Rayo Congelador")
local ray = alice.Backpack:FindFirstChild("Rayo de Hielo")
snowball.Parent = alice.Backpack
ray.Parent = aliceChar
Emu.Run(0.2)
Emu.Fire(ray, "Activated")
Emu.Run(0.3)
check(CharacterService.IsFrozen(bob), "el rayo congela a Bob")
Emu.RaycastHook = nil
check(remotes.BuyGear:InvokeServer("ReindeerBoots") == true, "comprar Botas de Reno")
local boots = alice.Backpack:FindFirstChild("Botas de Reno")
ray.Parent = alice.Backpack
boots.Parent = aliceChar
Emu.Fire(boots, "Equipped")
Emu.Run(0.2)
check(aliceChar.Humanoid.WalkSpeed > 20, "las botas dan velocidad (" .. aliceChar.Humanoid.WalkSpeed .. ")")
Emu.Fire(boots, "Unequipped")
check(remotes.BuyGear:InvokeServer("JingleBell") == true, "comprar Campana")
local bell = alice.Backpack:FindFirstChild("Campana")
bell.Parent = aliceChar
Emu.Fire(bell, "Equipped")
Emu.Run(0.2)
check(aliceChar.Humanoid.JumpHeight > 15, "la campana da saltos enormes")
Emu.Fire(bell, "Unequipped")

section("Vender")
BaseService.PlacePresent(aliceBase, 3, "Drum", "Gold")
Emu.Run(0.2)
local cashBeforeSell = aliceData.Cash
Emu.Fire(PPS, "PromptTriggered", aliceBase.Slots[3].Present.Model.Root.Mid.SellPrompt, alice)
Emu.Run(0.3)
check(aliceBase.Slots[3].Present == nil and aliceData.Cash > cashBeforeSell, "vender devuelve dinero")

section("Renacer")
aliceData.Cash = 500
local okR = remotes.Rebirth:InvokeServer("rebirth")
check(okR == false, "sin dinero no se puede renacer")
DataService.AddCash(alice, 3000000)
BaseService.PlacePresent(aliceBase, 2, "GingerHouse", nil)
local okR2, msgR2 = remotes.Rebirth:InvokeServer("rebirth")
check(okR2 == true, "renacer (" .. tostring(msgR2) .. ")")
check(aliceData.Rebirths == 1 and aliceData.Cash == 100, "renacimiento 1 y dinero reiniciado")
check(aliceBase.Slots[2].Present == nil, "se quitan los regalos")
check(aliceBase.Slots[10].Unlocked and not aliceBase.Slots[11].Unlocked, "se desbloquean 2 huecos")

section("Eventos")
for _, id in { "Blizzard", "Aurora", "SantaNight", "GoldRain" } do
	check(EventService.Start(id, 2), "evento " .. id)
	Emu.Run(0.4)
end
check(EventService.GetLuck() > 1, "el evento da suerte")
ConveyorService.Spawn("InfiniteGift", "Rainbow")
ConveyorService.Spawn("SantasGift", nil)
Emu.Run(0.4)
EventService.Stop()
Emu.Run(0.3)

section("Interfaz")
local ClientScript = game.StarterPlayer.StarterPlayerScripts.Client
local UI = ClientScript.UI
for _, name in { "ShopUI", "RebirthUI", "IndexUI" } do
	local module = clientRequire(UI[name])
	module.Toggle()
	Emu.Run(0.4)
	module.Toggle()
	Emu.Run(0.2)
end
local IntroUI = clientRequire(UI.IntroUI)
IntroUI.ToggleHelp()
Emu.Run(0.3)
IntroUI.ToggleHelp()
local IndexUI = clientRequire(UI.IndexUI)
IndexUI.Toggle()
Emu.Run(0.3)
local gui = alice.PlayerGui.DontStealThePresent
local viewports = 0
for _, d in gui:GetDescendants() do
	if d.ClassName == "ViewportFrame" and #d:GetChildren() > 1 then
		viewports += 1
	end
end
check(viewports >= 28, "el índice muestra los 28 regalos en 3D (" .. viewports .. ")")
IndexUI.Toggle()

section("Comandos de prueba")
local TextChatService = game:GetService("TextChatService")
local commandsFolder = TextChatService:FindFirstChild("DevCommands")
local cashBeforeCmd = aliceData.Cash
if commandsFolder then
	local source = Emu.New("TextSource", true)
	Emu.Set(source, "UserId", 1001)
	Emu.Fire(commandsFolder.Dev_dinero, "Triggered", source, "/dinero 5m")
else
	Emu.Fire(alice, "Chatted", "/dinero 5m")
end
Emu.Run(0.3)
check(aliceData.Cash >= cashBeforeCmd + 5000000, "/dinero 5m funciona")

section("Guardado y vuelta")
local bobPresent = bobBase.Slots[1].Present and bobBase.Slots[1].Present.Id
Emu.RemovePlayer(bob)
Emu.Run(0.5)
check(Emu.Store["Player_1002"] ~= nil, "los datos de Bob se guardan al salir")
check(bobBase.Owner == nil, "el taller de Bob queda libre")
local bob2 = Emu.AddPlayer("Bob", 1002)
Emu.SpawnCharacter(bob2, V3.new(0, 5, -20))
Emu.Run(1)
local bobBase2 = BaseService.GetBase(bob2)
check(bobBase2 and bobBase2.Slots[1].Present and bobBase2.Slots[1].Present.Id == bobPresent, "al volver recupera su regalo")
check(DataService.Get(bob2).Stats.Steals == 1, "y sus estadísticas")

section("Sin DataStore (Studio sin acceso a la API)")
Emu.StoreError = "Studio access to API services is not allowed."
local carl = Emu.AddPlayer("Carl", 1003)
Emu.SpawnCharacter(carl, V3.new(0, 5, 0))
Emu.Run(1)
check(DataService.Get(carl) ~= nil, "Carl juega con datos nuevos")
Emu.StoreError = nil

section("Cierre del servidor")
for _, fn in Emu.CloseCallbacks do
	local okClose, errClose = pcall(fn)
	check(okClose, "BindToClose " .. tostring(errClose or ""))
end

-- Resumen -----------------------------------------------------------------------------------------------------
print("\n\27[1m== Resumen\27[0m")
print(string.format("  %d comprobaciones OK, %d fallidas, %d errores de ejecución", passed, #failures, #Emu.Errors))
if #Emu.Warnings > 0 then
	print("  Avisos (warn):")
	local seen = {}
	for _, w in Emu.Warnings do
		if not seen[w] then
			seen[w] = true
			print("    · " .. w)
		end
	end
end
local stubs = {}
for name, count in Emu.Stubs do
	table.insert(stubs, string.format("%s ×%d", name, count))
end
table.sort(stubs)
if #stubs > 0 then
	print("  Métodos no emulados (devuelven nil): " .. table.concat(stubs, ", "))
end
process.exit(if #failures == 0 and #Emu.Errors == 0 then 0 else 1)
