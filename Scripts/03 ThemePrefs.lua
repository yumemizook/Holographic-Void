--- Holographic Void: Theme Preferences
-- @module 03_ThemePrefs
-- Uses the _Fallback ThemePrefs system to register and manage
-- theme-specific preferences saved to Save/ThemePrefs.ini.

-- Preference definitions: each key maps to a table with a Default value.
-- These are registered with the _Fallback ThemePrefs.Init system.
local HVPrefs = {
	-- Visual: Background animation intensity (0 = off, 1 = subtle, 2 = full)
	HV_BGAnimIntensity = {
		Default = 1,
		Choices = {"Off", "Subtle", "Full"},
		Values = {0, 1, 2}
	},

	-- Gameplay: Show MSD ratings on music wheel
	HV_ShowMSD = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true}
	},


	-- Gameplay: Show player profile stats on select music
	HV_ShowProfileStats = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true}
	},

	-- Gameplay: MSD Color Scale (HolographicVoid or TilDeath)
	HV_MSDColorScaleV3 = {
		Default = "Holographic",
		Choices = {"Holographic", "Classic", "None", "Monochrome"},
		Values = {"Holographic", "Classic", "None", "Monochrome"}
	},

	-- Visual: Enable glow/bloom effects on active elements
	HV_EnableGlow = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true}
	},

	-- Gameplay: Show measure divider lines
	HV_ShowMeasureLines = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true}
	},

	-- Gameplay: UI/Background Dim (0.0 - 1.0)
	HV_ScreenFilter = {
		Default = 0.0,
		Choices = {"Off", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "Max"},
		Values = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0},
	},

	-- Gameplay: Lane Cover percentage (0 = off, 1-100)
	HV_LaneCover = {
		Default = 0,
		Choices = {"Off", "10%", "25%", "40%", "50%", "60%", "75%"},
		Values = {0, 10, 25, 40, 50, 60, 75},
	},

	-- Gameplay: Toggle real-time NPS display
	HV_ShowNPS = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true}
	},

	-- Gameplay: NPS Window Size (seconds)
	HV_NPSWindowSize = {
		Default = 1,
		Choices = {"1s", "2s", "3s", "4s", "5s"},
		Values = {1, 2, 3, 4, 5}
	},

	-- Gameplay: Toggle Timing Offset Bar
	HV_ShowOffsetBar = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true}
	},

	-- Gameplay: EWMA Smoothing for Offset Bar
	HV_EWMAOffsetBar = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true}
	},

	-- Gameplay: Toggle Full Pacemaker Graph
	HV_ShowPacemakerGraph = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true}
	},

	-- Gameplay: Toggle Mini Text Pacemaker
	HV_ShowTextPacemaker = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true}
	},

	-- Gameplay: Mini Pacemaker Target Type
	HV_PacemakerTargetType = {
		Default = "Target",
		Choices = {"Target", "PB", "PB Replay"},
		Values = {"Target", "PB", "PBReplay"}
	},

	-- Gameplay: Mini Pacemaker Target Goal (percentage)
	HV_PacemakerTargetGoal = {
		Default = 93,
		Choices = {
			"0%", "1%", "2%", "3%", "4%", "5%", "6%", "7%", "8%", "9%", "10%",
			"11%", "12%", "13%", "14%", "15%", "16%", "17%", "18%", "19%", "20%",
			"21%", "22%", "23%", "24%", "25%", "26%", "27%", "28%", "29%", "30%",
			"31%", "32%", "33%", "34%", "35%", "36%", "37%", "38%", "39%", "40%",
			"41%", "42%", "43%", "44%", "45%", "46%", "47%", "48%", "49%", "50%",
			"51%", "52%", "53%", "54%", "55%", "56%", "57%", "58%", "59%", "60%",
			"61%", "62%", "63%", "64%", "65%", "66%", "67%", "68%", "69%", "70%",
			"71%", "72%", "73%", "74%", "75%", "76%", "77%", "78%", "79%", "80%",
			"81%", "82%", "83%", "84%", "85%", "86%", "87%", "88%", "89%", "90%",
			"91%", "92%", "93%", "94%", "95%", "96%", "97%", "98%", "99%",
			"99.50%", "99.70%", "99.80%", "99.90%", "99.95%",
			"99.96%", "99.97%", "99.98%", "99.99%",
			"99.990%", "99.991%", "99.992%", "99.993%", "99.994%",
			"99.995%", "99.996%", "99.997%", "99.998%", "99.999%", "100%"
		},
		Values = {
			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
			11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
			21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
			31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
			41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
			51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
			61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
			71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
			81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
			91, 92, 93, 94, 95, 96, 97, 98, 99,
			99.50, 99.70, 99.80, 99.90, 99.95,
			99.96, 99.97, 99.98, 99.99,
			99.990, 99.991, 99.992, 99.993, 99.994,
			99.995, 99.996, 99.997, 99.998, 99.999, 100
		}
	},

	-- Gameplay: Toggle target tracker comparison
	HV_ShowTargetTracker = { Default = false },

	-- Visual: Background/Menu particles
	HV_Particles = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true}
	},
	
	-- Gameplay: Show Mean on Notefield
	HV_ShowMean = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true}
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
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true}
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
		Choices = {"Grid", "Hex", "Scanlines", "Flow", "Rays", "None"},
		Values = {"Grid", "Hex", "Scanlines", "Flow", "Rays", "None"}
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
	return (ThemePrefs.Get("HV_EnableGlow") == "true" or ThemePrefs.Get("HV_EnableGlow") == true)
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
