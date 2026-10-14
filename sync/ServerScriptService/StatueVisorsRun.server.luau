-- Server: visors on every statue when the server starts (ServerScriptService.StatueVisors has the fits).
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Config"))
require(script.Parent:WaitForChild("StatueVisors")).ApplyAll(Config)
