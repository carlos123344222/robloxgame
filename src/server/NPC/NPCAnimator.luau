--!strict
-- Plays Roblox's stock R15 locomotion animations on an NPC, driven by its Locomotion state.
-- (Players get the same animations from the default Animate script.) The asset ids are Roblox's own
-- default animations; swap them for custom ones in ANIMATION_IDS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

type Loco = Types.Loco

local ANIMATION_IDS: { [string]: string } = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
}

local FADE = 0.15

export type NPCAnimator = {
	Update: (self: NPCAnimator, dt: number) -> (),
	Destroy: (self: NPCAnimator) -> (),
}

type Impl = NPCAnimator & {
	Loco: Loco,
	Tracks: { [string]: AnimationTrack },
	Current: string?,
}

local NPCAnimator = {}
NPCAnimator.__index = NPCAnimator

function NPCAnimator.new(character: Model, loco: Loco): NPCAnimator
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if humanoid and animator == nil then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end

	local tracks: { [string]: AnimationTrack } = {}
	if animator then
		for name, id in ANIMATION_IDS do
			local animation = Instance.new("Animation")
			animation.Name = name
			animation.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok and track then
				track.Priority = if name == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Core
				tracks[name] = track
			else
				warn(`[NPCAnimator] could not load animation '{name}'`)
			end
		end
	end

	local self = setmetatable({ Loco = loco, Tracks = tracks, Current = nil }, NPCAnimator)
	return (self :: any) :: NPCAnimator
end

local function choose(loco: Loco): (string, number)
	local state = loco.StateName
	if state == "Air" then
		return if loco.Velocity.Y > 4 then "Jump" else "Fall", 1
	elseif state == "Roll" or state == "Stun" then
		return "Fall", 1
	elseif state == "Mantle" then
		return "Jump", 1
	elseif state == "Slide" then
		return "Idle", 1
	end

	local speed = loco.HSpeed
	if state == "Dash" or state == "WallRun" then
		return "Run", math.clamp(speed / 16, 0.8, 2.2)
	end
	if speed < 1 then
		return "Idle", 1
	elseif speed < loco.Cfg.RunSpeed * 0.6 then
		return "Walk", math.clamp(speed / 14.5, 0.5, 1.6)
	end
	return "Run", math.clamp(speed / 16, 0.7, 2.2)
end

function NPCAnimator.Update(self: Impl, _dt: number)
	local name, playbackSpeed = choose(self.Loco)
	local track: AnimationTrack? = self.Tracks[name]
	if track == nil then
		return
	end
	if self.Current ~= name then
		local previous: AnimationTrack? = if self.Current then self.Tracks[self.Current] else nil
		if previous then
			previous:Stop(FADE)
		end
		track:Play(FADE)
		self.Current = name
	end
	track:AdjustSpeed(playbackSpeed)
end

function NPCAnimator.Destroy(self: Impl)
	for _, track in self.Tracks do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(self.Tracks)
end

return NPCAnimator
