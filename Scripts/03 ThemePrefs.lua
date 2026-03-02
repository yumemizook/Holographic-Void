--- Holographic Void: Theme Preferences
-- @module 03_ThemePrefs
-- Uses the _Fallback ThemePrefs system to register and manage
-- theme-specific preferences saved to Save/ThemePrefs.ini.

-- Preference definitions: each key maps to a table with a Default value.
-- These are registered with the _Fallback ThemePrefs.Init system.
local HVPrefs = {
	-- Visual: Background animation intensity (0 = off, 1 = subtle, 2 = full)
	HV_BGAnimIntensity = {
		Default = "2",
		Choices = {"Off", "Subtle", "Full"},
		Values = {"0", "1", "2"}
	},

	-- Gameplay: Show MSD ratings on music wheel
	HV_ShowMSD = {
		Default = "true",
		Choices = {"Off", "On"},
		Values = {"false", "true"}
	},

	-- Gameplay: Show judge offset display on evaluation
	HV_ShowJudgeOffsets = {
		Default = "true",
		Choices = {"Off", "On"},
		Values = {"false", "true"}
	},

	-- Gameplay: Show player profile stats on select music
	HV_ShowProfileStats = {
		Default = "true",
		Choices = {"Off", "On"},
		Values = {"false", "true"}
	},

	-- Gameplay: MSD Color Scale (HolographicVoid or TilDeath)
	HV_MSDColorScaleV3 = {
		Default = "Holographic",
		Choices = {"Holographic", "Classic", "None", "Monochrome"},
		Values = {"Holographic", "Classic", "None", "Monochrome"}
	},

	-- Visual: Enable glow/bloom effects on active elements
	HV_EnableGlow = {
		Default = "true",
		Choices = {"Off", "On"},
		Values = {"false", "true"}
	},

	-- Gameplay: Show measure divider lines
	HV_ShowMeasureLines = {
		Default = "true",
		Choices = {"Off", "On"},
		Values = {"false", "true"}
	},

	-- Gameplay: UI/Background Dim (0.0 - 1.0)
	HV_ScreenFilter = {
		Default = "0.0",
		Choices = {"Off", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "Max"},
		Values  = {"0.0", "0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7", "0.8", "0.9", "1.0"},
	},

	-- Gameplay: Lane Cover percentage (0 = off, 1-100)
	HV_LaneCover = {
		Default = "0",
		Choices = {"Off", "10%", "25%", "40%", "50%", "60%", "75%"},
		Values  = {"0", "10", "25", "40", "50", "60", "75"},
	},

	-- Gameplay: Toggle real-time NPS display
	HV_ShowNPS = {
		Default = "true",
		Choices = {"Off", "On"},
		Values = {"false", "true"}
	},

	-- Gameplay: Toggle target tracker comparison
	HV_ShowTargetTracker = { Default = "false" },

	-- Visual: Background/Menu particles
	HV_Particles = {
		Default = "true",
		Choices = {"Off", "On"},
		Values = {"false", "true"}
	},

	-- Gameplay: Mini (Receptor Size)
	HV_Mini = { Default = 100 },

	-- Visual: Accent color hex
	HV_AccentColor = { Default = "#5ABAFF" },

	-- Auth: Saved EtternaOnline username and login token
	HV_Username = { Default = "" },
	HV_PasswordToken = { Default = "" },

	-- Custom Grades
	HV_UseCustomGrades = {
		Default = "false",
		Choices = {"Off", "On"},
		Values = {"false", "true"}
	},
	
	-- Grade Color Style
	HV_GradeColorStyle = {
		Default = "Holographic",
		Choices = {"Holographic", "Classic"},
		Values = {"Holographic", "Classic"}
	},

	-- Visual: Background Effect Style
	HV_BackgroundEffect = {
		Default = "Grid",
		Choices = {"Grid", "Hex", "Scanlines", "Flow", "Rotating 4D Cube", "None"},
		Values = {"Grid", "Hex", "Scanlines", "Flow", "4DCube", "None"}
	},

}

-- bLoadFromDisk = true on the first call to read existing prefs from file.
ThemePrefs.Init(HVPrefs, true)

-- After loading, refresh accent colors
if HVColor and HVColor.RefreshAccent then
	HVColor.RefreshAccent()
end

-- ==========================================================================
-- Convenience getters for commonly used prefs
-- ==========================================================================

--- Get the current accent color as a color table.
function HV.GetAccentColor()
	return HVColor.Accent
end

--- Check if glow effects are enabled.
function HV.IsGlowEnabled()
	return ThemePrefs.Get("HV_EnableGlow") == "true"
end

--- Get background animation intensity (0, 1, or 2).
function HV.GetBGAnimIntensity()
	local val = tonumber(ThemePrefs.Get("HV_BGAnimIntensity"))
	return val and HV.Clamp(val, 0, 2) or 1
end

--- Check if MSD ratings should be shown.
function HV.ShowMSD()
	local val = ThemePrefs.Get("HV_ShowMSD")
	return val == "true" or val == true
end

--- Check if judge offsets should be shown on evaluation.
function HV.ShowJudgeOffsets()
	local val = ThemePrefs.Get("HV_ShowJudgeOffsets")
	return val == "true" or val == true
end

--- Check if player profile stats should be shown.
function HV.ShowProfileStats()
	local val = ThemePrefs.Get("HV_ShowProfileStats")
	return val == "true" or val == true
end

--- Check if measure lines should be shown.
function HV.ShowMeasureLines()
	local val = ThemePrefs.Get("HV_ShowMeasureLines")
	return val == "true" or val == true
end

Trace("Holographic Void: 03 ThemePrefs.lua loaded.")
