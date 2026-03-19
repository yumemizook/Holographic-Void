--- Holographic Void: Theme Preferences
-- @module 03_ThemePrefs

-- ==========================================================================
-- ThemePrefs Relocation & Migration System
-- ==========================================================================
-- We override the global ThemePrefs system to use a theme-specific folder.
-- This prevents settings from being overwritten by other themes and 
-- allows for better organization.

local HVThemePrefsPath = "Save/Holographic Void_settings/themeConfig.lua"
local NewIniPath = "Save/Holographic Void_settings/ThemePrefs.ini"
local OldIniPath = "Save/ThemePrefs.ini"

-- Internal storage for preferences (since _fallback's table is local to its script)
local PrefsTable = {}
local FallbackTheme = "_fallback"

local function GetThemeName()
	return (themeInfo and themeInfo.Name) or THEME:GetThemeDisplayName()
end

-- Resolve which section a preference belongs to
local function ResolveTable(pref)
	local name = GetThemeName()
	if PrefsTable[name] and PrefsTable[name][pref] ~= nil then
		return PrefsTable[name]
	end
	if PrefsTable[FallbackTheme] and PrefsTable[FallbackTheme][pref] ~= nil then
		return PrefsTable[FallbackTheme]
	end
	for section, _ in pairs(PrefsTable) do
		if PrefsTable[section][pref] ~= nil then
			return PrefsTable[section]
		end
	end
	return nil
end

-- Helper to load a Lua config file safely
local function load_lua_config(path)
	local file = RageFileUtil.CreateRageFile()
	local ret = nil
	if file:Open(path, 1) then -- READ
		local content = file:Read()
		local data = loadstring(content)
		if data then
			setfenv(data, {})
			local success, data_ret = pcall(data)
			if success then
				ret = data_ret
			end
		end
		file:Close()
	end
	file:destroy()
	return ret
end

-- Re-implement ThemePrefs with the new path
ThemePrefs = {
	NeedsSaved = false,
	Init = function(prefs, bLoadFromDisk)
		if bLoadFromDisk then
			ThemePrefs.Load()
		end
		local section = GetThemeName()
		PrefsTable[section] = PrefsTable[section] or {}
		for k, tbl in pairs(prefs) do
			if PrefsTable[section][k] == nil then
				PrefsTable[section][k] = tbl.Default
			end
		end
	end,
	Load = function()
		-- 1. Try new .lua path first
		if FILEMAN:DoesFileExist(HVThemePrefsPath) then
			local data = load_lua_config(HVThemePrefsPath)
			if type(data) == "table" then
				PrefsTable = data
				return true
			end
		end

		-- 2. Fall back to theme-specific .ini for migration
		if FILEMAN:DoesFileExist(NewIniPath) then
			if IniFile then
				Trace("Holographic Void: Migrating settings from " .. NewIniPath)
				PrefsTable = IniFile.ReadFile(NewIniPath)
				ThemePrefs.NeedsSaved = true
				ThemePrefs.Save()
				return true
			end
		end

		-- 3. Fall back to legacy .ini for migration
		if FILEMAN:DoesFileExist(OldIniPath) then
			if IniFile then
				Trace("Holographic Void: Migrating legacy settings from " .. OldIniPath)
				PrefsTable = IniFile.ReadFile(OldIniPath)
				ThemePrefs.NeedsSaved = true
				ThemePrefs.Save()
				return true
			end
		end

		PrefsTable = {}
		return true
	end,
	Save = function()
		if ThemePrefs.NeedsSaved then
			local file = RageFileUtil.CreateRageFile()
			if file:Open(HVThemePrefsPath, 2) then -- WRITE
				local output = "return " .. lua_table_to_string(PrefsTable)
				file:Write(output)
				file:Close()
				ThemePrefs.NeedsSaved = false
			else
				Warn("Holographic Void: Could not open '" .. HVThemePrefsPath .. "' for writing.")
			end
			file:destroy()
		end
	end,
	ForceSave = function()
		ThemePrefs.NeedsSaved = true
		ThemePrefs.Save()
	end,
	Get = function(name)
		local tbl = ResolveTable(name)
		return tbl and tbl[name] or nil
	end,
	Set = function(name, value)
		local tbl = ResolveTable(name)
		if tbl then
			ThemePrefs.NeedsSaved = true
			tbl[name] = value
		end
	end
}

-- Update global aliases
GetThemePref = ThemePrefs.Get
SetThemePref = ThemePrefs.Set


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

	-- Gameplay: Error Bar Mode (Off, Standard, EWMA Only, Both)
	HV_ErrorBarMode = {
		Default = "Standard",
		Choices = {"Off", "Standard", "EWMA Only", "Both"},
		Values = {"Off", "Standard", "EWMAOnly", "Both"}
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

	-- Visual: Show scrolling quotes/tips on Title Screen
	HV_QuotesMode = {
		Default = "Quotes",
		Choices = {"Off", "Quotes", "Tips"},
		Values = {"Off", "Quotes", "Tips"}
	},

	-- Alarm System Preferences
	HV_AlarmActive = { Default = false },
	HV_AlarmType = {
		Default = "Timer",
		Choices = {"Time", "Timer"},
		Values = {"Time", "Timer"}
	},
	HV_AlarmTime = { Default = "12:00" },
	HV_AlarmTimerDuration = { Default = 5 },
	HV_AlarmShowInGameplay = { Default = true },
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
