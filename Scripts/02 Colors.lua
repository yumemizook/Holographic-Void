--- Holographic Void: Monochromatic Color Palette
-- @module 02_Colors
-- Extends _Fallback's Color module with theme-specific colors.
-- All primary UI colors are shades of gray/white on OLED black.

HVColor = {
	-- Core palette (OLED blacks, whites, grays)
	Black       = color("0,0,0,1"),              -- #000000 - True OLED black
	BG1         = color("0.04,0.04,0.04,1"),     -- #0A0A0A - Deepest background
	BG2         = color("0.08,0.08,0.08,1"),     -- #141414 - Card/panel background
	BG3         = color("0.12,0.12,0.12,1"),     -- #1F1F1F - Elevated surface
	Border      = color("0.18,0.18,0.18,1"),     -- #2E2E2E - Subtle borders
	Separator   = color("0.22,0.22,0.22,1"),     -- #383838 - Dividers / separators
	TextDim     = color("0.45,0.45,0.45,1"),     -- #737373 - Disabled / dim text
	TextSub     = color("0.65,0.65,0.65,1"),     -- #A6A6A6 - Subtitle / secondary text
	Text        = color("0.85,0.85,0.85,1"),     -- #D9D9D9 - Primary body text
	TextBright  = color("1,1,1,1"),               -- #FFFFFF - Headers / emphasis
	White       = color("1,1,1,1"),               -- #FFFFFF

	-- Accent: configurable via ThemePrefs, defaults to a cool blue-white
	Accent      = color("#5ABAFF"),               -- Default accent (icy blue)
	AccentDim   = color("#2A6A9F"),               -- Dimmed accent for hover states

	-- Transparent overlays
	Overlay50   = color("0,0,0,0.5"),
	Overlay75   = color("0,0,0,0.75"),
	Overlay90   = color("0,0,0,0.9"),
}

--- Update the accent color from theme preferences.
-- Called after ThemePrefs loads to apply user's chosen accent.
function HVColor.RefreshAccent()
	if ThemePrefs and ThemePrefs.Get then
		local hex = ThemePrefs.Get("HV_AccentColor")
		if hex and hex ~= "" then
			HVColor.Accent = color(hex)
			-- Derive a dimmed version at 60% brightness
			local hsv = ColorToHSV(HVColor.Accent)
			hsv.Value = hsv.Value * 0.6
			HVColor.AccentDim = HSVToColor(hsv)
		end
	end
end

-- Difficulty colors (monochromatic-friendly with subtle hue shifts)
HVColor.Difficulty = {
	Beginner    = color("#8C8C8C"),   -- Light gray
	Easy        = color("#A0CFAB"),   -- Muted green-gray
	Medium      = color("#CFD198"),   -- Muted gold-gray
	Hard        = color("#CF9898"),   -- Muted red-gray
	Challenge   = color("#98B8CF"),   -- Muted blue-gray
	Edit        = color("#B898CF"),   -- Muted purple-gray
}

-- Override GameColor.Difficulty with our monochromatic versions
if GameColor and GameColor.Difficulty then
	for k, v in pairs(HVColor.Difficulty) do
		GameColor.Difficulty[k] = v
		GameColor.Difficulty["Difficulty_" .. k] = v
	end
end

-- Judgment colors (kept distinct but desaturated to fit the theme)
HVColor.Judgment = {
	W1   = color("#FFFFFF"),    -- Marvelous: pure white
	W2   = color("#E0E0A0"),    -- Perfect: warm off-white
	W3   = color("#A0E0A0"),    -- Great: pale green
	W4   = color("#A0C8E0"),    -- Good: pale blue
	W5   = color("#C8A0E0"),    -- Bad: pale purple
	Miss = color("#E0A0A0"),    -- Miss: pale red
}

-- Grade colors
HVColor.Grade = {
	AAAA = color("#FFFFFF"),
	AAA  = color("#E8E8E8"),
	AA   = color("#D0D0D0"),
	A    = color("#B8B8B8"),
	B    = color("#A0A0A0"),
	C    = color("#888888"),
	D    = color("#707070"),
	F    = color("#585858"),
}

Trace("Holographic Void: 02 Colors.lua loaded.")
