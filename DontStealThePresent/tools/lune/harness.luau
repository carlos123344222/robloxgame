-- Ejecuta ModuleScripts de un .rbxl construido por Rojo dentro de Lune, con los tipos de datos de
-- Roblox (Instance, Vector3, CFrame, Enum...). Lune valida cada propiedad contra la API de Roblox, así que
-- un nombre o tipo de propiedad mal escrito falla aquí igual que fallaría en el juego.
--
-- Uso: local harness = require("./harness"); local env = harness.open("build/base.rbxl")
--      local MapBuilder = env.require(env.game.ServerScriptService.Server.World.MapBuilder)

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = {}

export type Env = {
	game: any,
	require: (any) -> any,
}

function Harness.fromGame(game: any): Env
	local cache: { [any]: any } = {}
	local loading: { [any]: boolean } = {}
	local workspace = game:GetService("Workspace")

	local function requireModule(target: any): any
		if cache[target] ~= nil then
			return cache[target]
		end
		assert(typeof(target) == "Instance" and target:IsA("ModuleScript"), "require() espera un ModuleScript")
		assert(not loading[target], "require circular: " .. target:GetFullName())
		loading[target] = true
		local env = {
			script = target,
			game = game,
			workspace = workspace,
			Instance = roblox.Instance,
			Vector3 = roblox.Vector3,
			Vector2 = roblox.Vector2,
			CFrame = roblox.CFrame,
			Color3 = roblox.Color3,
			BrickColor = roblox.BrickColor,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			Rect = roblox.Rect,
			Enum = roblox.Enum,
			Font = roblox.Font,
			NumberRange = roblox.NumberRange,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			PhysicalProperties = roblox.PhysicalProperties,
			Ray = roblox.Ray,
			Region3 = roblox.Region3,
			task = task,
			require = requireModule,
			warn = function(...)
				print("[warn]", ...)
			end,
		}
		local chunk = luau.load(target.Source, {
			debugName = target:GetFullName(),
			environment = env,
		})
		local result = chunk()
		loading[target] = nil
		cache[target] = result
		return result
	end

	return {
		game = game,
		require = requireModule,
	}
end

function Harness.open(placePath: string): Env
	local game = roblox.deserializePlace(fs.readFile(placePath))
	return Harness.fromGame(game)
end

-- Busca un hijo por ruta "A.B.C"
function Harness.find(root: any, path: string): any
	local node = root
	for name in string.gmatch(path, "[^%.]+") do
		local child = node:FindFirstChild(name)
		assert(child, "No existe " .. path .. " (falta " .. name .. ")")
		node = child
	end
	return node
end

return Harness
