-- Reproduce los sonidos del juego por nombre (ver Shared/Config/Sounds).

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local GameConfig = require(Shared.Config.GameConfig)

local SoundController = {}

local templates: { [string]: Sound } = {}
local folder: Folder
local music: Sound? = nil
SoundController.Muted = false

local function template(name: string): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local info = Sounds[name]
	if not info then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = info.Id
	sound.Volume = info.Volume
	sound.PlaybackSpeed = info.Pitch
	sound.Parent = folder
	templates[name] = sound
	return sound
end

function SoundController.Play(name: string, position: Vector3?, pitchJitter: number?)
	if SoundController.Muted then
		return
	end
	local base = template(name)
	if not base then
		return
	end
	local sound = base:Clone()
	if pitchJitter then
		sound.PlaybackSpeed *= 1 + (math.random() * 2 - 1) * pitchJitter
	end
	if position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position)
		holder.Parent = workspace.CurrentCamera
		sound.RollOffMinDistance = 20
		sound.RollOffMaxDistance = 220
		sound.Parent = holder
		sound:Play()
		task.delay(6, function()
			holder:Destroy()
		end)
	else
		sound.Parent = folder
		sound:Play()
		task.delay(6, function()
			sound:Destroy()
		end)
	end
end

function SoundController.SetMuted(muted: boolean)
	SoundController.Muted = muted
	if music then
		music.Volume = if muted then 0 else GameConfig.MusicVolume
	end
end

function SoundController.Start()
	folder = Instance.new("Folder")
	folder.Name = "DSTPSounds"
	folder.Parent = SoundService
	for name in Sounds do
		template(name)
	end
	if GameConfig.MusicSoundId ~= "" then
		local track = Instance.new("Sound")
		track.Name = "Music"
		track.SoundId = GameConfig.MusicSoundId
		track.Volume = GameConfig.MusicVolume
		track.Looped = true
		track.Parent = folder
		track:Play()
		music = track
	end
end

return SoundController
