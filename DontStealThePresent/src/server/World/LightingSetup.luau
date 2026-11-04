-- Noche de Navidad: cielo estrellado, niebla azulada, brillo en las luces de neón.

local Lighting = game:GetService("Lighting")

local LightingSetup = {}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

function LightingSetup.Apply()
	Lighting.ClockTime = 20.6
	Lighting.GeographicLatitude = 41
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(92, 102, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 140, 184)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	local sky = ensure("Sky", "NightSky") :: Sky
	sky.StarCount = 6000
	sky.MoonAngularSize = 14
	sky.SunAngularSize = 10
	sky.CelestialBodiesShown = true

	local atmosphere = ensure("Atmosphere", "SnowAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(176, 196, 255)
	atmosphere.Decay = Color3.fromRGB(92, 104, 168)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.4

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 30
	bloom.Threshold = 1.4

	local color = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	color.Brightness = 0.03
	color.Contrast = 0.1
	color.Saturation = 0.12
	color.TintColor = Color3.fromRGB(242, 246, 255)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.03
	rays.Spread = 0.6
end

return LightingSetup
