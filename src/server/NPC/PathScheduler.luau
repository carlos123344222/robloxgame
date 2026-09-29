--!strict
-- Runs PathfindingService requests with a small concurrency limit, so a crowd of NPCs re-routing at
-- the same moment doesn't stall the server.

local PathfindingService = game:GetService("PathfindingService")

export type Request = {
	Params: { [string]: any },
	Start: Vector3,
	Goal: Vector3,
	Callback: (path: Path?) -> (),
	Cancelled: boolean,
}

local MAX_ACTIVE = 3

local PathScheduler = {}

local queue: { Request } = {}
local active = 0

local pump: () -> ()

local function run(request: Request)
	active += 1
	task.spawn(function()
		local path = PathfindingService:CreatePath(request.Params)
		local ok = pcall(function()
			path:ComputeAsync(request.Start, request.Goal)
		end)
		active -= 1
		if not request.Cancelled then
			local success = ok and path.Status == Enum.PathStatus.Success
			request.Callback(if success then path else nil)
		end
		pump()
	end)
end

pump = function()
	while active < MAX_ACTIVE and #queue > 0 do
		local request = table.remove(queue, 1) :: Request
		if not request.Cancelled then
			run(request)
		end
	end
end

function PathScheduler.Request(params: { [string]: any }, start: Vector3, goal: Vector3, callback: (path: Path?) -> ()): Request
	local request: Request = {
		Params = params,
		Start = start,
		Goal = goal,
		Callback = callback,
		Cancelled = false,
	}
	table.insert(queue, request)
	pump()
	return request
end

return PathScheduler
