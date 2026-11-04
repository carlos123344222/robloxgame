-- Sonidos del juego. Por defecto usan sonidos que vienen incluidos con el cliente de Roblox
-- (rbxasset://), así funcionan sin subir nada. Puedes cambiarlos por "rbxassetid://<id>" de la Creator Store.

export type SoundInfo = { Id: string, Volume: number, Pitch: number }

local Sounds: { [string]: SoundInfo } = {
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.15 },
	Collect = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.6 },
	NoMoney = { Id = "rbxasset://sounds/button.wav", Volume = 0.6, Pitch = 0.6 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Pitch = 1 },
	Open = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35, Pitch = 1.3 },
	Swing = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.55, Pitch = 1.1 },
	Hit = { Id = "rbxasset://sounds/collide.wav", Volume = 0.9, Pitch = 0.9 },
	Throw = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Pitch = 1.5 },
	SnowHit = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.7, Pitch = 1.4 },
	Freeze = { Id = "rbxasset://sounds/glassbreak.wav", Volume = 0.6, Pitch = 1.4 },
	Zap = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.5, Pitch = 1.6 },
	Lock = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.9, Pitch = 0.8 },
	Unlock = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.7, Pitch = 1.3 },
	Steal = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.8, Pitch = 1.2 },
	Alarm = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Pitch = 0.55 },
	Success = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1 },
	Fail = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.5, Pitch = 1 },
	Event = { Id = "rbxasset://sounds/victory.wav", Volume = 0.5, Pitch = 0.8 },
	Rebirth = { Id = "rbxasset://sounds/victory.wav", Volume = 0.8, Pitch = 1.1 },
	Jump = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.6, Pitch = 1.4 },
	Sell = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 0.9 },
}

return Sounds
