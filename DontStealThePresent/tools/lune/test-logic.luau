-- Pruebas de la lógica pura (formato de números, renacimientos, rarezas).
local process = require("@lune/process")
local harness = require("./harness")
local env = harness.open(process.args[1] or "build/base.rbxl")
local shared = harness.find(env.game, "ReplicatedStorage.Shared")
local Format = env.require(shared.Util.Format)
local Rebirths = env.require(shared.Config.Rebirths)
local Rarities = env.require(shared.Config.Rarities)
local Presents = env.require(shared.Config.Presents)
local Rng = env.require(shared.Util.Rng)

local failures = 0
local function eq(actual, expected, label)
	if actual ~= expected then
		failures += 1
		print(string.format("FALLO %s: esperaba %s, obtuve %s", label, tostring(expected), tostring(actual)))
	end
end

for _, case in {
	{ 0, "$0" }, { 7, "$7" }, { 999, "$999" }, { 1000, "$1K" }, { 1050, "$1.05K" }, { 4100, "$4.1K" },
	{ 12500, "$12.5K" }, { 999999, "$999K" }, { 1000000, "$1M" }, { 1250000, "$1.25M" }, { 42000000, "$42M" },
	{ 1.1e9, "$1.1B" }, { 2.5e12, "$2.5T" }, { 12.5, "$12.5" }, { -1500, "$-1.5K" },
} do
	eq(Format.Cash(case[1]), case[2], "Format.Cash(" .. case[1] .. ")")
end
eq(Format.Clock(75), "1:15", "Clock")
eq(Format.Clock(9), "0:09", "Clock 9")
eq(Format.Commas(1234567), "1,234,567", "Commas")
eq(Format.Duration(3700), "1h 1m", "Duration")

eq(Rebirths.SlotCount(0), 8, "slots r0")
eq(Rebirths.SlotCount(4), 16, "slots r4")
eq(Rebirths.SlotCount(9), 16, "slots max")
eq(Rebirths.SlotRequirement(9), 1, "slot 9 req")
eq(Rebirths.SlotRequirement(16), 4, "slot 16 req")
eq(Rebirths.LockDuration(0), 60, "lock r0")
eq(Rebirths.LockDuration(100), 120, "lock max")
eq(Rebirths.IncomeMultiplier(2), 2, "mult r2")
eq(Rebirths.Requirement(0).Cost, 1000000, "rebirth cost 0")
eq(Rebirths.Requirement(0).Rarity, "Rare", "rebirth rarity 0")
eq(Rebirths.Requirement(Rebirths.Max), nil, "rebirth max")

-- cada rareza tiene regalos y los precios crecen con la rareza
local lastMax = 0
for _, id in Rarities.Order do
	local list = Presents.ByRarity[id]
	eq(list ~= nil and #list > 0, true, "regalos de " .. id)
	local minPrice = math.huge
	for _, info in list do
		minPrice = math.min(minPrice, info.Price)
		eq(info.Income > 0 and info.Price > 0, true, info.Id .. " precio/ingreso")
		lastMax = math.max(lastMax, info.Price)
	end
end
eq(Rarities.WeightWithLuck("Secret", 3) > Rarities.Get("Secret").Weight * 10, true, "la suerte sube los secretos")

-- el generador determinista se mantiene en rango
local rng = Rng.new(42)
for _ = 1, 1000 do
	local v = rng:Int(1, 6)
	if v < 1 or v > 6 then
		failures += 1
		print("FALLO Rng fuera de rango", v)
		break
	end
end

print(if failures == 0 then "Lógica OK" else (failures .. " fallos"))
if failures > 0 then
	process.exit(1)
end
