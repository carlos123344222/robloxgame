-- Client main script (runs in LocalPlayer)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

print("Client loaded! Game Version: " .. Constants.GAME_VERSION)

-- Client initialization code here
