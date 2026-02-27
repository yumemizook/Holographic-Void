--- Holographic Void: Theme Preferences
-- @module 03_ThemePrefs
-- Uses the _Fallback ThemePrefs system to register and manage
-- theme-specific preferences saved to Save/ThemePrefs.ini.

-- Preference definitions: each key maps to a table with a Default value.
-- These are registered with the _Fallback ThemePrefs.Init system.
local HVPrefs = {
	-- Visual: Accent color (hex string)
	HV_AccentColor = { Default = "#5ABAFF" },

	-- Visual: Global UI opacity (0.0 - 1.0)
	HV_UIOpacity = { Default = "1.0" },

	-- Visual: Enable glow/bloom effects on active elements
	HV_EnableGlow = { Default = "true" },

	-- Visual: Background animation intensity (0 = off, 1 = subtle, 2 = full)
	HV_BGAnimIntensity = { Default = "1" },

	-- Layout: Music wheel position offset X
	HV_WheelOffsetX = { Default = "0" },

	-- Layout: Music wheel position offset Y
	HV_WheelOffsetY = { Default = "0" },

	-- Layout: Evaluation graph height scale (0.5 - 2.0)
	HV_EvalGraphScale = { Default = "1.0" },

	-- Gameplay: Show MSD ratings on music wheel
	HV_ShowMSD = { Default = "true" },

	-- Gameplay: Show judge offset display on evaluation
	HV_ShowJudgeOffsets = { Default = "true" },

	-- Gameplay: Show player profile stats on select music
	HV_ShowProfileStats = { Default = "true" },

	-- Gameplay: Judge difficulty display (4-9 or Justice)
	HV_DefaultJudge = { Default = "4" },

	-- Gameplay: MSD Color Scale (HolographicVoid or TilDeath)
	HV_MSDColorScale = { Default = "HolographicVoid" },

	-- Gameplay: Show measure divider lines
	HV_ShowMeasureLines = { Default = "false" },

	-- Auth: Saved EtternaOnline username and login token
	HV_Username = { Default = "" },
	HV_PasswordToken = { Default = "" },
}

-- Register with the _Fallback ThemePrefs system.
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

--- Get the current UI opacity as a number.
function HV.GetUIOpacity()
	local val = tonumber(ThemePrefs.Get("HV_UIOpacity"))
	return val and HV.Clamp(val, 0, 1) or 1
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
	return ThemePrefs.Get("HV_ShowMSD") == "true"
end

--- Check if judge offsets should be shown on evaluation.
function HV.ShowJudgeOffsets()
	return ThemePrefs.Get("HV_ShowJudgeOffsets") == "true"
end

--- Check if player profile stats should be shown.
function HV.ShowProfileStats()
	return ThemePrefs.Get("HV_ShowProfileStats") == "true"
end

--- Get the eval graph vertical scale.
function HV.GetEvalGraphScale()
	local val = tonumber(ThemePrefs.Get("HV_EvalGraphScale"))
	return val and HV.Clamp(val, 0.5, 2.0) or 1.0
end

Trace("Holographic Void: 03 ThemePrefs.lua loaded.")
