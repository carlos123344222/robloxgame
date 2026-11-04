-- Compila todos los .luau de src/ para detectar errores de sintaxis.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures = 0
local count = 0

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				failures += 1
				print("ERROR " .. path .. "\n  " .. tostring(err))
			end
		end
	end
end

walk(process.args[1] or "src")
print(string.format("%d archivos compilados, %d con errores", count, failures))
if failures > 0 then
	process.exit(1)
end
