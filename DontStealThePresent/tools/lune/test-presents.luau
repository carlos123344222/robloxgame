-- Construye todos los regalos con todas las mutaciones para comprobar que no hay errores.
local process = require("@lune/process")
local harness = require("./harness")

local placePath = process.args[1] or "build/base.rbxl"
local env = harness.open(placePath)
local shared = harness.find(env.game, "ReplicatedStorage.Shared")
local PresentBuilder = env.require(shared.PresentBuilder)
local Presents = env.require(shared.Config.Presents)
local Mutations = env.require(shared.Config.Mutations)

local mutations = { "" }
for _, id in Mutations.Order do
	table.insert(mutations, id)
end

local total, parts = 0, 0
local failures = 0
for _, info in Presents.List do
	for _, mutation in mutations do
		local ok, result = pcall(PresentBuilder.Build, info.Id, if mutation == "" then nil else mutation)
		if ok then
			total += 1
			local count = #result:GetDescendants()
			parts += count
			local height = result:GetAttribute("Height")
			assert(type(height) == "number" and height > 0.5, info.Id .. " altura inválida")
			if mutation == "" then
				print(string.format("  %-14s %-24s %3d objetos  altura %.2f", info.Rarity, info.Name, count, height))
			end
		else
			failures += 1
			print("FALLO", info.Id, mutation, result)
		end
	end
end

print(string.format("%d regalos construidos (%d instancias en total), %d fallos", total, parts, failures))
if failures > 0 then
	process.exit(1)
end
