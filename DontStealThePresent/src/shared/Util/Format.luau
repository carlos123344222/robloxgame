-- Formato de números y tiempos para la interfaz: 1250 -> "1.25K", 3600000 -> "3.6M"...

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(text: string): string
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

function Format.Number(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		if n == math.floor(n) or n >= 100 then
			return sign .. tostring(math.floor(n))
		end
		return sign .. trimZeros(string.format("%.1f", math.floor(n * 10 + 1e-6) / 10))
	end
	local tier = 0
	local scaled = n
	while scaled >= 1000 and tier < #SUFFIXES - 1 do
		scaled /= 1000
		tier += 1
	end
	local text
	if scaled >= 100 then
		text = tostring(math.floor(scaled + 1e-9))
	elseif scaled >= 10 then
		text = trimZeros(string.format("%.1f", math.floor(scaled * 10 + 1e-6) / 10))
	else
		text = trimZeros(string.format("%.2f", math.floor(scaled * 100 + 1e-6) / 100))
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

function Format.Cash(n: number): string
	return "$" .. Format.Number(n)
end

function Format.Income(n: number): string
	return "$" .. Format.Number(n) .. "/s"
end

-- 1234567 -> "1,234,567"
function Format.Commas(n: number): string
	local text = tostring(math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (if n < 0 then "-" else "") .. out
end

-- 75 -> "1:15", 9 -> "0:09"
function Format.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- 3700 -> "1h 1m", 75 -> "1m 15s"
function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

return Format
