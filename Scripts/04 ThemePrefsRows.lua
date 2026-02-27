--- Holographic Void: ThemePrefs Option Rows
-- @module 04_ThemePrefsRows
-- Defines option row handlers for the in-client ThemePrefs system.
-- These rows appear in ScreenOptionsService when theme options are accessed.
-- Uses _Fallback's ThemePrefsRows.Init system.

local HVPrefRows = {
	-- Accent Color
	HV_AccentColor = {
		Default = "#5ABAFF",
		Choices = {"Ice Blue", "White", "Warm Gold", "Soft Red", "Mint", "Violet", "Pure Gray"},
		Values  = {"#5ABAFF", "#FFFFFF", "#FFD080", "#FF8080", "#80FFB0", "#B080FF", "#808080"},
	},

	-- UI Opacity
	HV_UIOpacity = {
		Default = "1.0",
		Choices = {"25%", "50%", "75%", "100%"},
		Values  = {"0.25", "0.5", "0.75", "1.0"},
	},

	-- Glow Effects
	HV_EnableGlow = {
		Default = "true",
		Choices = {"Off", "On"},
		Values  = {"false", "true"},
	},

	-- Background Animation Intensity
	HV_BGAnimIntensity = {
		Default = "1",
		Choices = {"Off", "Subtle", "Full"},
		Values  = {"0", "1", "2"},
	},

	-- Music Wheel Offset X
	HV_WheelOffsetX = {
		Default = "0",
		Choices = {"-100", "-50", "0", "+50", "+100"},
		Values  = {"-100", "-50", "0", "50", "100"},
	},

	-- Music Wheel Offset Y
	HV_WheelOffsetY = {
		Default = "0",
		Choices = {"-50", "-25", "0", "+25", "+50"},
		Values  = {"-50", "-25", "0", "25", "50"},
	},

	-- Eval Graph Scale
	HV_EvalGraphScale = {
		Default = "1.0",
		Choices = {"50%", "75%", "100%", "125%", "150%", "200%"},
		Values  = {"0.5", "0.75", "1.0", "1.25", "1.5", "2.0"},
	},

	-- Show MSD Ratings
	HV_ShowMSD = {
		Default = "true",
		Choices = {"Off", "On"},
		Values  = {"false", "true"},
	},

	-- Show Judge Offsets on Evaluation
	HV_ShowJudgeOffsets = {
		Default = "true",
		Choices = {"Off", "On"},
		Values  = {"false", "true"},
	},

	-- Show Profile Stats on Select Music
	HV_ShowProfileStats = {
		Default = "true",
		Choices = {"Off", "On"},
		Values  = {"false", "true"},
	},

	-- Default Judge Difficulty
	HV_DefaultJudge = {
		Default = "4",
		Choices = {"J4", "J5", "J6", "J7", "J8", "Justice"},
		Values  = {"4", "5", "6", "7", "8", "9"},
	},

	-- MSD Color Scale
	HV_MSDColorScale = {
		Default = "HolographicVoid",
		Choices = {"Holographic Void", "Til Death"},
		Values  = {"HolographicVoid", "TilDeath"},
	},

	-- Show Measure Lines
	HV_ShowMeasureLines = {
		Default = "false",
		Choices = {"Off", "On"},
		Values  = {"false", "true"},
	},
}

-- Register the rows with the _Fallback ThemePrefsRows system
ThemePrefsRows.Init(HVPrefRows)

-- Also register a global function to get all HV option row lines
-- for use in metrics.ini ScreenOptionsService Lines
function HVThemeOptionsLines()
	return "HV_AccentColor,HV_UIOpacity,HV_EnableGlow,HV_BGAnimIntensity,"
		.. "HV_WheelOffsetX,HV_WheelOffsetY,HV_EvalGraphScale,"
		.. "HV_ShowMSD,HV_ShowJudgeOffsets,HV_ShowProfileStats,HV_DefaultJudge,"
		.. "HV_ShowMeasureLines"
end

-- Listen for pref changes and refresh accent color
local function OnThemePrefChanged(params)
	if params and params.Name == "HV_AccentColor" then
		if HVColor and HVColor.RefreshAccent then
			HVColor.RefreshAccent()
		end
	end
end

-- Hook into the broadcast system
-- This is called from _Fallback when a ThemePref is saved
if MESSAGEMAN then
	-- We can't directly subscribe here, but themes handle this
	-- via the ThemePrefChangedMessageCommand on actors
end

Trace("Holographic Void: 04 ThemePrefsRows.lua loaded.")
