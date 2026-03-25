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
	Beginner    = color("#98B8CF"),   -- Light gray
	Easy        = color("#A0CFAB"),   -- Muted green-gray
	Medium      = color("#CFD198"),   -- Muted gold-gray
	Hard        = color("#CF9898"),   -- Muted red-gray
	Challenge   = color("#B898CF"),   -- Muted blue-gray
	Edit        = color("#8C8C8C"),   -- Muted purple-gray
}

-- Override GameColor.Difficulty with our monochromatic versions
if GameColor and GameColor.Difficulty then
	for k, v in pairs(HVColor.Difficulty) do
		GameColor.Difficulty[k] = v
		GameColor.Difficulty["Difficulty_" .. k] = v
	end
end

--- Get a color for a difficulty short name (e.g. "Hard", "Challenge", "Edit").
function HVColor.GetDifficultyColor(diff)
	if not diff then return HVColor.Difficulty.Edit end
	local s = diff:gsub("Difficulty_", "")
	return HVColor.Difficulty[s] or HVColor.Difficulty.Edit
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

-- MSD rating color scale (smooth gradient)
local msdTable = {
	{0, color("#80C0CF")},  -- Muted Cyan
	{10, color("#A0CFAB")}, -- Green
	{15, color("#CFD198")}, -- Yellow
	{20, color("#E0B080")}, -- Muted Orange
	{25, color("#CF9898")}, -- Muted Red
	{30, color("#CF98B8")}, -- Muted Pink
	{35, color("#B898CF")}, -- Muted Purple
	{40, color("#5C4B7A")}, -- Dark Purple
}

--- Get a color for a numeric MSD value based on theme preferences.
-- @param msd Number (0-40+)
-- @return Color
function HVColor.GetMSDRatingColor(msd)
	if not msd or msd < 0 then return msdTable[1][2] end

	local scale = "Holographic"
	if ThemePrefs and ThemePrefs.Get then
		local prefValue = ThemePrefs.Get("HV_MSDColorScaleV3")
		-- Robust fallback: if preference is empty, nil, or explicitly "None" (which was causing issues), 
		-- default to our premium "Holographic" scale.
		if prefValue and prefValue ~= "" and prefValue ~= "None" then
			scale = prefValue
		end
	end

	-- Normalize case for robustness
	local s = scale:lower()
	if s == "classic" then
		-- Classic Til Death hue shift logic
		return HSV(math.max(95 - (msd / 40) * 150, -50), 0.9, 0.9)
	elseif s == "none" then
		-- Static White
		return color("#FFFFFF")
	elseif s == "monochrome" then
		-- Asymptotically darker (White -> Dark Gray)
		local v = 1.0 / (1.0 + (msd * 0.04))
		return color(v..","..v..","..v..",1")
	end

	-- Holographic Void: smooth interpolation between muted thresholds
	for i = 1, #msdTable - 1 do
		local lower = msdTable[i]
		local upper = msdTable[i+1]
		if msd >= lower[1] and msd <= upper[1] then
			local p = (msd - lower[1]) / (upper[1] - lower[1])
			return HV.LerpColor(p, lower[2], upper[2])
		end
	end

	if msd > 40 then return msdTable[#msdTable][2] end
	return msdTable[1][2]
end

-- Clear Type colors (muted variants of classic schemes)
HVColor.ClearType = {
	MFC     = color("#E0F8FF"), -- Slightly cyan white (Marvelous Full Combo)
	WF      = color("#E0E0E0"), -- Muted White (White Flag - 1xW2 FC)
	SDP     = color("#CFD198"), -- Muted Yellow (Single Digit Perfects)
	PFC     = color("#CFD198"), -- Muted Yellow (Perfect Full Combo)
	BF      = color("#B898CF"), -- Muted Purple (Black Flag - 1xW3 FC)
	SDG     = color("#A0CFAB"), -- Muted Green (Single Digit Greats)
	FC      = color("#A0CFAB"), -- Muted Green (Full Combo)
	MF      = color("#CF9898"), -- Muted Red (Miss Flag - 1xMiss)
	SDCB    = color("#80C0CF"), -- Muted Cyan (Single Digit Combo Breakers)
	Clear   = color("#5ABAFF"), -- Accent Blue
	Failed  = color("#CF9898"), -- Muted Red
	Invalid = color("#454545"), -- Dim Gray
	NoPlay  = color("#252525"), -- Darkest Gray
	None    = color("#252525"), -- Darkest Gray
}

--- Get a color for a Clear Type string.
function HVColor.GetClearTypeColor(ct)
	if not ct then return HVColor.ClearType.Clear end
	local s = ct:upper():gsub(" ", ""):gsub("CLEARTYPE_", "")
	
	if HVColor.ClearType[s] then return HVColor.ClearType[s] end
	
	-- Fallback patterns
	if s:find("MARVELOUS") then return HVColor.ClearType.MFC end
	if s:find("PERFECT")   then return HVColor.ClearType.PFC end
	if s:find("COMBO")     then return HVColor.ClearType.FC end
	if s:find("FAILED")    then return HVColor.ClearType.Failed end
	return HVColor.ClearType.Clear
end

-- Song Length colors
HVColor.SongLength = {
	Normal   = color("#D9D9D9"), -- Standard text
	Long     = color("#E0B080"), -- Muted Orange (>= 2:30)
	Marathon = color("#CF9898"), -- Muted Red (>= 5:00)
}

--- Get a color for song duration in seconds.
function HVColor.GetSongLengthColor(seconds)
	if not seconds then return HVColor.SongLength.Normal end
	if seconds >= 300 then return HVColor.SongLength.Marathon end
	if seconds >= 150 then return HVColor.SongLength.Long end
	return HVColor.SongLength.Normal
end

-- Grade colors (muted, matching the theme aesthetic)
HVColor.Grade = {
	AAAAA = color("#FFFFFF"),    -- Pure White
	AAAA  = color("#80C0CF"),    -- Muted Cyan
	AAA   = color("#CFD198"),    -- Muted Yellow
	AA    = color("#A0CFAB"),    -- Muted Green
	A     = color("#CF9898"),    -- Muted Red
	B     = color("#98B8CF"),    -- Muted Blue-Gray
	C     = color("#B898CF"),    -- Muted Purple
	D     = color("#CF98B8"),    -- Muted Pink
	F     = color("#606060"),    -- Dim Gray
	None  = color("#454545"),    -- Dim Gray
}

-- Classic Til Death grade colors
HVColor.GradeClassic = {
	AAAAA = color("#FFFFFF"),    -- White
	AAAA  = color("#66CCFF"),    -- Cyan
	AAA   = color("#EEBB00"),    -- Yellow
	AA    = color("#66cc66"),    -- Green
	A     = color("#DA5757"),    -- Red
	B     = color("#5B78BB"),    -- Blue
	C     = color("#C97BFF"),    -- Purple
	D     = color("#8C6239"),    -- Pink
	F     = color("#CDCDCD"),    -- Gray
	None  = color("#666666"),    -- Dark Gray
}

--- Get a color for a Grade string or enum.
function HVColor.GetGradeColor(grade)
	local style = ThemePrefs.Get("HV_GradeColorStyle") or "Holographic"
	local palette = style == "Classic" and HVColor.GradeClassic or HVColor.Grade

	if not grade then return palette.None end
	local s = tostring(grade):upper():gsub("GRADE_", "")
	
	-- Handle Tier specific matches first (Etterna Tiers)
	if s:find("TIER01") then return palette.AAAAA end
	if s:find("TIER02") or s:find("TIER03") or s:find("TIER04") then return palette.AAAA end
	if s:find("TIER05") or s:find("TIER06") or s:find("TIER07") then return palette.AAA end
	if s:find("TIER08") or s:find("TIER09") or s:find("TIER10") then return palette.AA end
	if s:find("TIER11") or s:find("TIER12") or s:find("TIER13") then return palette.A end
	if s:find("TIER14") then return palette.B end
	if s:find("TIER15") then return palette.C end
	if s:find("TIER16") then return palette.D end
	if s:find("TIER17") or s:find("FAILED") then return palette.F end
	
	-- Fallback text matches
	if s:find("AAAAA") then return palette.AAAAA end
	if s:find("AAAA")  then return palette.AAAA end
	if s:find("AAA")   then return palette.AAA  end
	if s:find("AA")    then return palette.AA   end
	if s:find("A")     then return palette.A    end
	if s:find("B")     then return palette.B    end
	if s:find("C")     then return palette.C    end
	if s:find("D")     then return palette.D    end
	
	return palette.None
end

--- Get a color for an online rank number.
function HVColor.GetSkillsetRankColor(rank)
	if not rank or rank <= 0 then return color("#737373") end
	
	if rank <= 10 then return color("#CFD198") end       -- Top 10 (Muted Gold)
	if rank <= 50 then return color("#A0CFAB") end       -- Top 50 (Muted Green)
	if rank <= 100 then return color("#80C0CF") end      -- Top 100 (Muted Cyan)
	if rank <= 500 then return color("#D9D9D9") end      -- Top 500 (White-Gray)
	return color("#A6A6A6")                              -- Fallback (Subtitle Text)
end

-- Global helper expected by some fallback or legacy scripts
function getMainColor(type)
	if not type or type == "" then return HVColor.Accent end
	if type == "highlight" then return HVColor.Accent end
	if type == "positive" then return color("#A0CFAB") end
	if type == "negative" then return color("#CF9898") end
	-- Fallback for any other requested type
	return HVColor.Accent
end

Trace("Holographic Void: 02 Colors.lua loaded.")
