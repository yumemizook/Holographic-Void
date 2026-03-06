--- Holographic Void: ThemePrefs Option Rows
-- @module 04_ThemePrefsRows
-- Defines option row handlers for the in-client ThemePrefs system.
-- These rows appear in ScreenOptionsService when theme options are accessed.
-- Uses _Fallback's ThemePrefsRows.Init system.

local HVPrefRows = {
	-- Auto Login Tokens (Secret, non-visible in menu)
	HV_Username = {
		Default = "",
		Choices = {""},
		Values  = {""},
	},
	HV_PasswordToken = {
		Default = "",
		Choices = {""},
		Values  = {""},
	},


	-- Background Animation Intensity
	HV_BGAnimIntensity = {
		Default = 1,
		Choices = {"Off", "Subtle", "Full"},
		Values = {0, 1, 2},
	},


	-- Show MSD Ratings
	HV_ShowMSD = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},


	-- Show Profile Stats on Select Music
	HV_ShowProfileStats = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},


	-- MSD Color Scale
	HV_MSDColorScaleV3 = {
		Default = "Holographic",
		Choices = {"Holographic", "Classic", "None", "Monochrome"},
		Values  = {"Holographic", "Classic", "None", "Monochrome"},
	},

	-- Show Measure Lines
	HV_ShowMeasureLines = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Screen Filter
	HV_ScreenFilter = {
		Default = 0.0,
		Choices = {"Off", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "Max"},
		Values = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0},
	},

	-- Lane Cover
	HV_LaneCover = {
		Default = 0,
		Choices = {"Off", "10%", "25%", "40%", "50%", "60%", "75%"},
		Values = {0, 10, 25, 40, 50, 60, 75},
	},

	-- Glow Effects
	HV_EnableGlow = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Show NPS
	HV_ShowNPS = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- NPS Window Size
	HV_NPSWindowSize = {
		Default = 1,
		Choices = {"1s", "2s", "3s", "4s", "5s"},
		Values = {1, 2, 3, 4, 5},
	},

	-- Error Bar Mode
	HV_ErrorBarMode = {
		Default = "Standard",
		Choices = {"Off", "Standard", "EWMA Only", "Both"},
		Values  = {"Off", "Standard", "EWMAOnly", "Both"},
	},

	-- Show Full Pacemaker Graph
	HV_ShowPacemakerGraph = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Show Mini Text Pacemaker
	HV_ShowTextPacemaker = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Pacemaker Target Type
	HV_PacemakerTargetType = {
		Default = "Target",
		Choices = {"Target", "PB", "PB Replay"},
		Values  = {"Target", "PB", "PBReplay"},
	},

	-- Pacemaker Target Goal
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
		},
	},

	-- Show Particles
	HV_Particles = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Show Mean on Notefield
	HV_ShowMean = {
		Default = true,
		Choices = {"Off", "On"},
		Values = {false, true},
	},
	
	-- Accent Color
	HV_AccentColor = {
		Default = "#5ABAFF",
		Choices = {"Blue", "Pink", "Mint", "Orange", "Purple", "White"},
		Values  = {"#5ABAFF", "#FF5ABB", "#5AFFBA", "#FFBA5A", "#BA5AFF", "#D9D9D9"},
	},

	-- Use Custom Grade Names (from grade.costom.md)
	HV_UseCustomGrades = {
		Default = false,
		Choices = {"Off", "On"},
		Values = {false, true},
	},

	-- Grade Color Style
	HV_GradeColorStyle = {
		Default = "Holographic",
		Choices = {"Holographic", "Classic"},
		Values  = {"Holographic", "Classic"},
	},
	
	-- Background Effect Style
	HV_BackgroundEffect = {
		Default = "Grid",
		Choices = {"Grid", "Hex", "Scanlines", "Flow", "Rays", "None"},
		Values  = {"Grid", "Hex", "Scanlines", "Flow", "Rays", "None"},
	},

	-- Title Screen Text Mode
	HV_QuotesMode = {
		Default = "Quotes",
		Choices = {"Off", "Quotes", "Tips"},
		Values  = {"Off", "Quotes", "Tips"},
	},
} -- End of HVPrefRows

-- Register the rows with the _Fallback ThemePrefsRows system
ThemePrefsRows.Init(HVPrefRows)

-- Helper for 1% - 250% choices
local RSChoices = {}
for i = 1, 250 do
	RSChoices[i] = tostring(i) .. "%"
end

-- ReceptorSize OptionRow (Til' Death style)
function OptionRowMini()
	return {
		Name = "Mini",
		LayoutType = "ShowAllInRow",
		SelectType = "SelectOne",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		ExportOnCancel = true,
		Choices = RSChoices,
		LoadSelections = function(self, list, pn)
			local prefs = tonumber(ThemePrefs.Get("HV_Mini")) or 100
			-- Ensure index is within range [1, 250]
			local idx = math.max(1, math.min(math.floor(prefs), 250))
			list[idx] = true
		end,
		SaveSelections = function(self, list, pn)
			for i = 1, #list do
				if list[i] then
					ThemePrefs.Set("HV_Mini", i)
					ThemePrefs.Save()
					break
				end
			end
		end
	}
end

-- Also register a global function to get all HV option row lines
-- for use in metrics.ini ScreenOptionsService Lines
function HVThemeOptionsLines()
	local l = "HV_BGAnimIntensity,HV_BackgroundEffect,HV_ShowMSD,HV_ShowProfileStats,HV_MSDColorScaleV3,HV_ShowMeasureLines,HV_ShowNPS,HV_NPSWindowSize,HV_ShowPacemakerGraph,HV_ShowTextPacemaker,HV_PacemakerTargetType,HV_PacemakerTargetGoal,HV_ShowMean,HV_QuotesMode,HV_ErrorBarMode,HV_Particles,HV_EnableGlow,HV_UseCustomGrades,HV_GradeColorStyle"
	return l
end

-- Wrap ThemePrefRow to ensure it saves to disk immediately when changed
local function HVThemePrefRow(name, title)
	local row = ThemePrefRow(name, title)
	row.ExportOnChange = true
	local baseSave = row.SaveSelections
	row.SaveSelections = function(self, list, pn)
		baseSave(self, list, pn)
		ThemePrefs.Save()
	end
	return row
end

function OptionRowPacemakerType()
	return HVThemePrefRow("HV_PacemakerTargetType")
end

function OptionRowPacemakerGoal()
	return HVThemePrefRow("HV_PacemakerTargetGoal")
end

function OptionRowShowTextPacemaker()
	return HVThemePrefRow("HV_ShowTextPacemaker", "Text Pacemaker")
end

-- ScreenPlayerOptions Helpers
function OptionRowScreenFilter()
	return HVThemePrefRow("HV_ScreenFilter", "Screen Filter")
end

function OptionRowLaneCover()
	return HVThemePrefRow("HV_LaneCover", "Lane Cover")
end

function OptionRowErrorBarMode()
	return HVThemePrefRow("HV_ErrorBarMode", "Error Bar Mode")
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
