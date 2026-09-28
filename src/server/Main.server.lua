-- Server main script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

print("Game started! Version: " .. Constants.GAME_VERSION)

-- Server initialization code here
