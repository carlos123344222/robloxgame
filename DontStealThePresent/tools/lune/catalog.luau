-- Imprime el catálogo de regalos en Markdown (para el README).
local process = require("@lune/process")
local harness = require("./harness")
local env = harness.open(process.args[1] or "build/base.rbxl")
local shared = harness.find(env.game, "ReplicatedStorage.Shared")
local Presents = env.require(shared.Config.Presents)
local Rarities = env.require(shared.Config.Rarities)
local Format = env.require(shared.Util.Format)
local total = 0
for _, id in Rarities.Order do
	total += Rarities.List[id].Weight
end
print("| Rareza | Regalo | Precio | Genera | Prob. de la rareza |")
print("| --- | --- | ---: | ---: | ---: |")
for _, info in Presents.List do
	local rarity = Rarities.Get(info.Rarity)
	print(string.format("| %s | %s | %s | %s | %.2f%% |", rarity.Name, info.Name, Format.Cash(info.Price), Format.Income(info.Income), rarity.Weight / total * 100))
end
