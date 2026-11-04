-- Números generales del juego. Todo lo que define el ritmo de una partida está aquí.

local GameConfig = {
	GameName = "Don't Steal the Present",
	GameNameEs = "¡No robes el regalo!",

	-- Economía ----------------------------------------------------------------------------------------
	StartCash = 100,
	SellRefund = 0.5, -- al vender un regalo recuperas este % de su precio
	OfflineEarningsRate = 0.2, -- % de los ingresos que generan tus regalos mientras no juegas
	OfflineEarningsMaxHours = 6,

	-- Bases -------------------------------------------------------------------------------------------
	MaxBases = 8,
	SlotsPerBase = 16,

	-- Cinta de regalos --------------------------------------------------------------------------------
	Belt = {
		Speed = 7, -- studs por segundo
		SpawnInterval = 2.3, -- segundos entre regalos
		SpawnJitter = 0.6,
		MaxItems = 30,
		StartX = -192,
		EndX = 196,
		Z = 0,
		SurfaceY = 2.6, -- altura de la superficie de la cinta
		BuyDistance = 18, -- tolerancia del servidor (el prompt aparece a 12)
		AnnounceRarity = 5, -- índice de rareza a partir del cual se anuncia al servidor (5 = Legendario)
	},

	-- Robos -------------------------------------------------------------------------------------------
	Steal = {
		HoldDuration = 1.35,
		MaxCarryTime = 75, -- segundos antes de que el regalo vuelva solo a su dueño
		CarrySpeedMult = 0.7,
		CarryJumpHeight = 5,
		StealDistance = 16,
	},

	-- Movimiento --------------------------------------------------------------------------------------
	Movement = {
		WalkSpeed = 18,
		JumpHeight = 7.5,
	},

	-- Guardado ----------------------------------------------------------------------------------------
	DataStoreName = "DontStealThePresent_v1",
	AutosaveInterval = 90,

	-- Eventos -----------------------------------------------------------------------------------------
	Events = {
		FirstDelay = 150,
		IntervalMin = 330,
		IntervalMax = 510,
	},

	-- Comandos de chat para probar (/dinero, /renacer, /evento...). Solo funcionan en Studio o para el
	-- creador del juego.
	DevCommands = true,

	-- Música de fondo: pon aquí el id de una canción navideña de la Creator Store (p. ej. "rbxassetid://123").
	-- Vacío = sin música.
	MusicSoundId = "",
	MusicVolume = 0.35,
}

return GameConfig
