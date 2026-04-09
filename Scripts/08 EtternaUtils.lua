--- Holographic Void: Etterna Utility Functions
-- Consolidates grade calculation, clear types, score retrieval,
-- rate management, timing stats, and judge rescoring.
-- Ported with adaptation from spawncamping-wallhack.

------------------------------------------------------------
-- ROUNDING HELPERS
------------------------------------------------------------
notShit = notShit or {}
function notShit.floor(x, y)
	y = 10 ^ (y or 0)
	return math.floor(x * y) / y
end
function notShit.ceil(x, y)
	y = 10 ^ (y or 0)
	return math.ceil(x * y) / y
end
function notShit.round(x, y)
	y = 10 ^ (y or 0)
	return math.floor(x * y + 0.5) / y
end

------------------------------------------------------------
-- RATE MANAGEMENT
------------------------------------------------------------
function getCurRateValue()
	return notShit.round(GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(), 3)
end

function getCurRate()
	local mods = GAMESTATE:GetSongOptionsString()
	if string.find(mods, "Haste") ~= nil then
		return "Haste"
	elseif string.find(mods, "xMusic") == nil then
		return "1.0x"
	else
		return (string.match(mods, "%d+%.%d+xMusic")):sub(1, -6)
	end
end

function getCurRateString()
	local r = string.format("%.2f", getCurRateValue()):gsub("%.?0+$", "") .. "x"
	if r == "1x" then r = "1.0x" end
	if r == "2x" then r = "2.0x" end
	return r
end

function getCurRateDisplayString()
	return getRateDisplayString(getCurRateString())
end

function getRateDisplayString(x)
	if x == "1x" then x = "1.0x"
	elseif x == "2x" then x = "2.0x" end
	return x .. "Music"
end

function changeMusicRate(amount)
	local curRate = getCurRateValue()
	local newRate = curRate + amount
	if newRate <= 3 and newRate >= 0.05 then
		GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(curRate + amount)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(curRate + amount)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(curRate + amount)
		MESSAGEMAN:Broadcast("CurrentRateChanged", {rate = newRate, oldRate = curRate})
	end
end

------------------------------------------------------------
-- GRADE CALCULATION & CUSTOM NAMES
------------------------------------------------------------
HV.CustomGrades = {
	Grade_Tier01 = "神",
	Grade_Tier02 = "秀上",
	Grade_Tier03 = "秀中",
	Grade_Tier04 = "秀下",
	Grade_Tier05 = "優上",
	Grade_Tier06 = "優中",
	Grade_Tier07 = "優下",
	Grade_Tier08 = "良上",
	Grade_Tier09 = "良中",
	Grade_Tier10 = "良下",
	Grade_Tier11 = "佳上",
	Grade_Tier12 = "佳中",
	Grade_Tier13 = "佳下",
	Grade_Tier14 = "普",
	Grade_Tier15 = "欠",
	Grade_Tier16 = "堕",
	Grade_Tier17 = "Grade_Tier17.",
	Grade_Failed = "堕",
	Grade_None   = "無"
}

function HV.GetGradeName(grade)
	if not grade then return "" end
	-- Safely extract the short name (e.g. "Tier01", "Failed")
	-- grade may be "Grade_Tier09" (full enum) or "Tier09" (already short)
	local s = grade:gsub("^Grade_", "")
	local key = "Grade_" .. s

	local pref = ThemePrefs.Get("HV_UseCustomGrades")
	if (pref == "true" or pref == true) and HV.CustomGrades[key] then
		return HV.CustomGrades[key]
	end
	
	-- Safe fallback for THEME:GetString
	if THEME:HasString("Grade", s) then
		return THEME:GetString("Grade", s)
	end
	
	-- Manual fallback mapping if THEME:HasString is somehow unreliable or missing
	local fallbacks = {
		Tier01 = "AAAAA", Tier02 = "AAAA:", Tier03 = "AAAA.", Tier04 = "AAAA",
		Tier05 = "AAA:", Tier06 = "AAA.", Tier07 = "AAA", Tier08 = "AA:",
		Tier09 = "AA.", Tier10 = "AA", Tier11 = "A:", Tier12 = "A.",
		Tier13 = "A", Tier14 = "B", Tier15 = "C", Tier16 = "D",
		Failed = "F", None = "None"
	}
	return fallbacks[s] or s
end

WifeTiers = {
	Grade_Tier01 = 0.999935, Grade_Tier02 = 0.9998, Grade_Tier03 = 0.9997,
	Grade_Tier04 = 0.99955,  Grade_Tier05 = 0.999,  Grade_Tier06 = 0.998,
	Grade_Tier07 = 0.997,    Grade_Tier08 = 0.99,   Grade_Tier09 = 0.965,
	Grade_Tier10 = 0.93,     Grade_Tier11 = 0.9,    Grade_Tier12 = 0.85,
	Grade_Tier13 = 0.8,      Grade_Tier14 = 0.7,    Grade_Tier15 = 0.6,
	Grade_Tier16 = 0.0,
}

WifeTierList = {
	"Grade_Tier01","Grade_Tier02","Grade_Tier03","Grade_Tier04",
	"Grade_Tier05","Grade_Tier06","Grade_Tier07","Grade_Tier08",
	"Grade_Tier09","Grade_Tier10","Grade_Tier11","Grade_Tier12",
	"Grade_Tier13","Grade_Tier14","Grade_Tier15","Grade_Tier16"
}

function isMidGrade(grade)
	return grade == "Grade_Tier02" or grade == "Grade_Tier03"
		or grade == "Grade_Tier05" or grade == "Grade_Tier06"
		or grade == "Grade_Tier08" or grade == "Grade_Tier09"
		or grade == "Grade_Tier11" or grade == "Grade_Tier12"
end

function getGradeFamilyForMidGrade(grade)
	if grade == "Grade_Tier02" or grade == "Grade_Tier03" then return "Grade_Tier04"
	elseif grade == "Grade_Tier05" or grade == "Grade_Tier06" then return "Grade_Tier07"
	elseif grade == "Grade_Tier08" or grade == "Grade_Tier09" then return "Grade_Tier10"
	elseif grade == "Grade_Tier11" or grade == "Grade_Tier12" then return "Grade_Tier14"
	else return grade end
end

function gradeFamilyToBetterGrade(grade)
	if grade == "Grade_Tier04" then return "Grade_Tier01"
	elseif grade == "Grade_Tier07" then return "Grade_Tier04"
	elseif grade == "Grade_Tier10" then return "Grade_Tier07"
	elseif grade == "Grade_Tier14" then return "Grade_Tier10"
	else
		if grade == "Grade_Tier01" then return grade
		else return string.format("Grade_Tier%02d", (tonumber(grade:sub(-2)) - 1)) end
	end
end

function getEtternaGrade(wifePct)
	if not wifePct then return "Failed" end
	local pct = wifePct / 100
	if pct >= 0.999935 then return "Tier01"
	elseif pct >= 0.9998 then return "Tier02"
	elseif pct >= 0.9997 then return "Tier03"
	elseif pct >= 0.99955 then return "Tier04"
	elseif pct >= 0.999 then return "Tier05"
	elseif pct >= 0.998 then return "Tier06"
	elseif pct >= 0.997 then return "Tier07"
	elseif pct >= 0.99 then return "Tier08"
	elseif pct >= 0.965 then return "Tier09"
	elseif pct >= 0.93 then return "Tier10"
	elseif pct >= 0.9 then return "Tier11"
	elseif pct >= 0.85 then return "Tier12"
	elseif pct >= 0.8 then return "Tier13"
	elseif pct >= 0.7 then return "Tier14"
	elseif pct >= 0.6 then return "Tier15"
	elseif pct >= 0.0 then return "Tier16"
	else return "Tier17" end
end

function getWifeGradeTier(percent)
	percent = percent / 100
	local midgrades = PREFSMAN:GetPreference("UseMidGrades")
	for _, v in pairs(WifeTierList) do
		if not midgrades and isMidGrade(v) then
			-- skip
		elseif percent > WifeTiers[v] then
			return v
		end
	end
	return "Grade_Tier16"
end

function getMaxNotes(pn)
	local steps = GAMESTATE:GetCurrentSteps()
	if steps then
		return steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
	end
	return 0
end

function getMaxScore(pn)
	return getMaxNotes(pn) * 2
end

function getGradeThreshold(pn, grade)
	local maxScore = getMaxScore(pn)
	if grade == "Grade_Failed" then return 0
	else return math.ceil(maxScore * (WifeTiers[grade] or 0)) end
end

function getNearbyGrade(pn, wifeScore, grade)
	local midgrades = PREFSMAN:GetPreference("UseMidGrades")
	if grade == "Grade_Tier01" then return grade, 0
	elseif grade == "Grade_Failed" then return "Grade_Tier16", wifeScore
	elseif grade == "Grade_None" then return "Grade_Tier16", 0
	else
		local nextGrade
		if not midgrades then
			local grd = getGradeFamilyForMidGrade(grade)
			nextGrade = gradeFamilyToBetterGrade(grd)
		else
			nextGrade = string.format("Grade_Tier%02d", (tonumber(grade:sub(-2)) - 1))
		end
		local gradeScore = getGradeThreshold(pn, grade)
		local nextGradeScore = getGradeThreshold(pn, nextGrade)
		local curGradeDiff = wifeScore - gradeScore
		local nextGradeDiff = wifeScore - nextGradeScore
		if math.abs(curGradeDiff) < math.abs(nextGradeDiff) then
			return grade, curGradeDiff
		else
			return nextGrade, nextGradeDiff
		end
	end
end

------------------------------------------------------------
-- CLEAR TYPE SYSTEM (IIDX-style)
------------------------------------------------------------
local clearTypeNames = {
	[1]="ClearType_MFC", [2]="ClearType_WF", [3]="ClearType_SDP",
	[4]="ClearType_PFC", [5]="ClearType_BF", [6]="ClearType_SDG",
	[7]="ClearType_FC",  [8]="ClearType_MF", [9]="ClearType_SDCB",
	[10]="ClearType_EXHC", [11]="ClearType_HClear", [12]="ClearType_Clear",
	[13]="ClearType_EClear", [14]="ClearType_AClear", [15]="ClearType_Failed",
	[16]="ClearType_Invalid", [17]="ClearType_Noplay", [18]="ClearType_None",
	[19]="ClearType_SoftInvalid",
}

local clearTypeReverse = {}
for k, v in pairs(clearTypeNames) do clearTypeReverse[v] = k end

------------------------------------------------------------
-- INVALIDATING MODIFIERS DETECTION
------------------------------------------------------------
function GetInvalidatingMods(pn)
	local ps = GAMESTATE:GetPlayerState(pn)
	if not ps then return {} end
	
	local mods = {}
	local modStr = ps:GetPlayerOptionsString("ModsLevel_Current"):lower()
	
	-- Remove mods (note-reduction)
	local checks = {
		["no mines"] = "NoMines", ["no holds"] = "NoHolds", ["no rolls"] = "NoRolls",
		["no hands"] = "NoHands", ["no jumps"] = "NoJumps", ["no lifts"] = "NoLifts",
		["no quads"] = "NoQuads", ["no stretch"] = "NoStretch", ["no fakes"] = "NoFakes",
		["little"] = "Little",
		-- Insert mods (note-addition)
		["wide"] = "Wide", ["big"] = "Big", ["quick"] = "Quick",
		["bmrize"] = "BMRize", ["skippy"] = "Skippy",
		-- Pattern Transform mods
		["echo"] = "Echo", ["stomp"] = "Stomp", ["jackjs"] = "JackJS",
		["anchorjs"] = "AnchorJS", ["icyworld"] = "IcyWorld",
		-- Turn mods (multi-word first to avoid partial matches)
		["soft shuffle"] = "SoftShuffle", ["super shuffle"] = "SuperShuffle",
		["hran shuffle"] = "HRanShuffle", ["shuffle"] = "Shuffle",
		["backwards"] = "Backwards",
		-- Hold Transform mods
		["planted"] = "Planted", ["floored"] = "Floored",
		["twister"] = "Twister", ["holdrolls"] = "HoldRolls",
	}
	
	for pattern, name in pairs(checks) do
		if modStr:find(pattern) then
			table.insert(mods, name)
		end
	end
	
	-- Left/Right turns: use word-boundary frontier pattern to avoid false positives
	if modStr:find("%f[%a]left%f[%A]") then table.insert(mods, "TurnLeft") end
	if modStr:find("%f[%a]right%f[%A]") then table.insert(mods, "TurnRight") end
	
	-- Additive Mines: 'mines' present but NOT as 'no mines'
	if modStr:find("mines") and not modStr:find("no mines") then
		table.insert(mods, "Mines")
	end
	
	-- Gameplay Aids
	if getAutoplay and getAutoplay() ~= 0 then table.insert(mods, "Autoplay") end
	if GAMESTATE:IsPracticeMode() then table.insert(mods, "PracticeMode") end
	
	return mods
end

function IsScoreInvalid(score)
	if not score then return false end
	
	local mods = ""
	if score.GetModifiers then
		mods = score:GetModifiers():lower()
	elseif score.GetTapNoteScores then
		-- For live PlayerStageStats, check current game state
		if getAutoplay and getAutoplay() ~= 0 then return true end
		if GAMESTATE:IsPracticeMode() then return true end
		mods = GAMESTATE:GetPlayerState(PLAYER_1):GetPlayerOptionsString("ModsLevel_Current"):lower()
	else
		return false
	end

	local invalidating = {
		"no mines", "no holds", "no rolls", "no hands",
		"no jumps", "no lifts", "no quads", "no stretch",
		"no fakes", "little", "wide", "big", "quick",
		"bmrize", "skippy", "echo", "stomp", "jackjs",
		"anchorjs", "icyworld", "autoplay", "practice",
		-- Turns
		"backwards", "soft shuffle", "super shuffle", "hran shuffle", "shuffle",
		-- Hold Transforms
		"planted", "floored", "twister", "holdrolls",
	}
	for _, m in ipairs(invalidating) do
		if mods:find(m) then return true end
	end
	-- Left/Right turns (word boundary)
	if mods:find("%f[%a]left%f[%A]") then return true end
	if mods:find("%f[%a]right%f[%A]") then return true end
	-- Additive mines
	if mods:find("mines") and not mods:find("no mines") then return true end
	
	-- 2. J4 Check (Legacy/Fallback)
	-- If the score is somehow flagged by engine, we can check here
	
	return false
end

function getClearTypeText(ct)
	return THEME:GetString("ClearTypes", ct)
end

function getClearTypeShortText(ct)
	-- If there's no specific short string, fallback to full
	if THEME:HasString("ClearTypesShort", ct) then
		return THEME:GetString("ClearTypesShort", ct)
	end
	return THEME:GetString("ClearTypes", ct)
end

function getClearLevel(pn, steps, score)
	if score == nil or steps == nil then return 17 end
	
	local grade
	if score.GetWifeGrade then grade = score:GetWifeGrade()
	else grade = score:GetGrade() end

	if grade == nil then return 17 end
	-- Check invalid mods FIRST: a failed invalid score should still be Invalid
	if IsScoreInvalid(score) then return 16 end
	if grade == "Grade_Failed" then return 15 end

	local tns = {}
	if score.GetTapNoteScore then
		tns.W1 = score:GetTapNoteScore("TapNoteScore_W1")
		tns.W2 = score:GetTapNoteScore("TapNoteScore_W2")
		tns.W3 = score:GetTapNoteScore("TapNoteScore_W3")
		tns.W4 = score:GetTapNoteScore("TapNoteScore_W4")
		tns.W5 = score:GetTapNoteScore("TapNoteScore_W5")
		tns.Miss = score:GetTapNoteScore("TapNoteScore_Miss")
	else
		tns.W1 = score:GetTapNoteScores("TapNoteScore_W1")
		tns.W2 = score:GetTapNoteScores("TapNoteScore_W2")
		tns.W3 = score:GetTapNoteScores("TapNoteScore_W3")
		tns.W4 = score:GetTapNoteScores("TapNoteScore_W4")
		tns.W5 = score:GetTapNoteScores("TapNoteScore_W5")
		tns.Miss = score:GetTapNoteScores("TapNoteScore_Miss")
	end

	local hns = {}
	if score.GetHoldNoteScore then
		hns.Held = score:GetHoldNoteScore("HoldNoteScore_Held")
	else
		hns.Held = score:GetHoldNoteScores("HoldNoteScore_Held")
	end

	local maxNotes
	if GAMESTATE:CountNotesSeparately() then
		maxNotes = steps:GetRadarValues(pn):GetValue("RadarCategory_Notes") or 0
	else
		maxNotes = steps:GetRadarValues(pn):GetValue("RadarCategory_TapsAndHolds") or 0
	end
	local maxHolds = (steps:GetRadarValues(pn):GetValue("RadarCategory_Holds") or 0)
		+ (steps:GetRadarValues(pn):GetValue("RadarCategory_Rolls") or 0)

	local totalTaps = tns.W1 + tns.W2 + tns.W3 + tns.W4 + tns.W5 + tns.Miss
	if totalTaps ~= maxNotes then return 16 end -- note count mismatch

	-- Soft Invalid check (< 83% J4)
	local j4Pct = getJ4NormalizedPercentage(score)
	if j4Pct < 83 then return 19 end

	-- MFC
	if tns.W1 == maxNotes and hns.Held == maxHolds then return 1 end

	-- PFC variants
	if tns.W1 + tns.W2 == maxNotes and hns.Held == maxHolds then
		if tns.W2 == 1 then return 2      -- WF
		elseif tns.W2 < 10 then return 3  -- SDP
		else return 4 end                 -- PFC
	end

	-- FC variants
	local missCount = tns.W4 + tns.W5 + tns.Miss
	if missCount == 0 then
		if tns.W3 == 1 then return 5      -- BF
		elseif tns.W3 < 10 then return 6  -- SDG
		else return 7 end                 -- FC
	elseif missCount == 1 then return 8   -- MF
	elseif missCount < 10 then return 9   -- SDCB
	end

	return 12 -- Clear
end

function getClearType(pn, steps, score)
	return clearTypeNames[getClearLevel(pn, steps, score)]
end

function getClearTypeLevel(ct)
	return clearTypeReverse[ct] or 18
end


function getClearTypeColor(ct)
	return HVColor.GetClearTypeColor(ct) or color("1,1,1,1")
end

function getHighestClearType(pn, steps, scoreList, ignore)
	if steps == nil then return clearTypeNames[18] end
	local highest = 17
	if scoreList ~= nil then
		for i = 1, #scoreList do
			if i ~= ignore then
				local hScore = scoreList[i]
				if hScore ~= nil then
					local cl = getClearLevel(pn, steps, hScore)
					if cl ~= 16 then
						highest = math.min(highest, cl)
					end
				end
			end
		end
	end
	return clearTypeNames[highest]
end

------------------------------------------------------------
-- CLEAR TYPE (Detailed, from PSS)
------------------------------------------------------------
function getDetailedClearType(obj)
	if not obj then return "Failed" end
	local miss, w5, w4, w3, w2 = 0, 0, 0, 0, 0
	local grade = "Grade_None"
	local wifeScore = 0

	if obj.GetTapNoteScores then -- PlayerStageStats
		miss = obj:GetTapNoteScores("TapNoteScore_Miss")
		w5 = obj:GetTapNoteScores("TapNoteScore_W5")
		w4 = obj:GetTapNoteScores("TapNoteScore_W4")
		w3 = obj:GetTapNoteScores("TapNoteScore_W3")
		w2 = obj:GetTapNoteScores("TapNoteScore_W2")
		grade = obj:GetGrade()
		wifeScore = obj:GetWifeScore()
	elseif obj.GetTapNoteScore then -- HighScore
		miss = obj:GetTapNoteScore("TapNoteScore_Miss")
		w5 = obj:GetTapNoteScore("TapNoteScore_W5")
		w4 = obj:GetTapNoteScore("TapNoteScore_W4")
		w3 = obj:GetTapNoteScore("TapNoteScore_W3")
		w2 = obj:GetTapNoteScore("TapNoteScore_W2")
		grade = obj:GetGrade()
		wifeScore = obj:GetWifeScore()
	end

	-- Check invalid mods FIRST: a failed invalid score should still be Invalid
	if IsScoreInvalid(obj) then return "Invalid" end
	if grade == "Grade_Failed" or grade == "Grade_None" or wifeScore <= 0 then
		return "Failed"
	end

	local cb = miss + w5 + w4
	if cb > 0 then
		if cb == 1 then return "MF"
		elseif cb < 10 then return "SDCB"
		else return "Clear" end
	end
	if w3 > 0 then
		if w3 == 1 then return "BF"
		elseif w3 < 10 then return "SDG"
		else return "FC" end
	end
	if w2 > 0 then
		if w2 == 1 then return "WF"
		elseif w2 < 10 then return "SDP"
		else return "PFC" end
	end
	local j4Pct = getJ4NormalizedPercentage(obj)
	if j4Pct < 83 then return "Soft Invalid" end

	return "MFC"
end

------------------------------------------------------------
-- SCORE RETRIEVAL & COMPARISON
------------------------------------------------------------
function GetDisplayScore()
	local pn = PLAYER_1
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then return nil end
	
	local currentRateValue = getCurRateValue()
	local rateTable = getRateTable(pn, steps)
	if not rateTable then return nil end

	-- 1. Try current rate first
	local currentRateStr = getCurRateString()
	local currentScores = rateTable[currentRateStr]
	if currentScores and #currentScores > 0 then
		-- Use J4-normalized comparison to find the best for this rate
		local bestOfRate = nil
		local bestOfRatePct = -math.huge
		for i = 1, #currentScores do
			local s = currentScores[i]
			if not IsScoreInvalid(s) then
				local p = getJ4NormalizedPercentage(s)
				if p > bestOfRatePct then
					bestOfRatePct = p
					bestOfRate = s
				end
			end
		end
		return bestOfRate
	end

	-- 2. No scores for current rate, find the closest one
	local closestRate = nil
	local minDiff = math.huge
	local bestScore = nil
	local bestScorePct = -math.huge

	for rateStr, scores in pairs(rateTable) do
		if scores and #scores > 0 then
			local rNum = tonumber((rateStr:gsub("x", ""))) or 0
			local diff = math.abs(rNum - currentRateValue)
			
			-- Find the best score for this specific rate first
			local bestInThisRate = nil
			local bestInThisRatePct = -math.huge
			for i = 1, #scores do
				local s = scores[i]
				if not IsScoreInvalid(s) then
					local p = getJ4NormalizedPercentage(s)
					if p > bestInThisRatePct then
						bestInThisRatePct = p
						bestInThisRate = s
					end
				end
			end

			if bestInThisRate and diff < minDiff then
				minDiff = diff
				closestRate = rateStr
				bestScore = bestInThisRate
				bestScorePct = bestInThisRatePct
			elseif bestInThisRate and math.abs(diff - minDiff) < 0.0001 then
				-- If rates are equally close, pick the one with better J4 normalized percentage
				if bestInThisRatePct > bestScorePct then
					bestScore = bestInThisRate
					bestScorePct = bestInThisRatePct
				end
			end
		end
	end

	return bestScore
end

function getScoreGrade(score)
	if score ~= nil then return score:GetWifeGrade()
	else return "Grade_None" end
end

function getScore(score, steps, percent)
	if percent == nil then percent = true end
	if score ~= nil and steps ~= nil then
		local pn = GAMESTATE:GetEnabledPlayers()[1]
		local notes = steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
		if percent then return score:GetWifeScore()
		else return score:GetWifeScore() * notes * 2 end
	end
	return 0
end

function getScoreComboBreaks(score)
	if score == nil then return 0 end
	return score:GetTapNoteScore("TapNoteScore_W4")
		+ score:GetTapNoteScore("TapNoteScore_W5")
		+ score:GetTapNoteScore("TapNoteScore_Miss")
end

function getScoreMaxCombo(score)
	if score == nil then return 0 end
	return score:GetMaxCombo()
end

function getHighScoreIndex(hsTable, score)
	if hsTable == nil then return 0 end
	for i, hs in ipairs(hsTable) do
		if hs:GetDate() == score:GetDate() and
			math.abs(hs:GetWifeScore() - score:GetWifeScore()) < 0.0001 then
			return i
		end
	end
	return 0
end

-- Rate table: returns {["1.0x"] = {score1, score2, ...}, ...}
function getRateTable(pn, steps)
	pn = pn or GAMESTATE:GetEnabledPlayers()[1]
	steps = steps or GAMESTATE:GetCurrentSteps()
	if not steps then return nil end
	local ck = steps:GetChartKey()
	if not ck then return nil end
	local sl = SCOREMAN:GetScoresByKey(ck)
	if sl == nil then return nil end
	local o = {}
	for k, v in pairs(sl) do
		o[k] = v:GetScores()
	end
	return o
end

function getScoreTable(pn, rate, steps)
	if not rate then rate = "1.0x" end
	local rtTable = getRateTable(pn, steps)
	if not rtTable then return nil end
	return rtTable[rate]
end

function getRate(score)
	if score == nil then return "1.0x" end
	local r = string.format("%.2f", score:GetMusicRate()):gsub("%.?0+$", "") .. "x"
	if r == "1x" then r = "1.0x" end
	if r == "2x" then r = "2.0x" end
	return r
end

function getBestScore(pn, ignore, rate, percent)
	if not rate then rate = "1.0x" end
	local highest = -math.huge
	local bestScore
	local hsTable = getScoreTable(pn, rate)
	if hsTable ~= nil and #hsTable >= 1 then
		for k, v in ipairs(hsTable) do
			if k ~= ignore then
				local indexScore = hsTable[k]
				if indexScore ~= nil and not IsScoreInvalid(indexScore) then
					local temp = getJ4NormalizedPercentage(indexScore)
					if temp >= highest then
						highest = temp
						bestScore = indexScore
					end
				end
			end
		end
	end
	return bestScore
end

function getBestMissCount(pn, ignore, rate)
	if not rate then rate = "1.0x" end
	local lowest = math.huge
	local bestScore
	local hsTable = getScoreTable(pn, rate)
	if hsTable ~= nil and #hsTable >= 1 then
		for i = 1, #hsTable do
			if i ~= ignore then
				local indexScore = hsTable[i]
				if indexScore ~= nil and not IsScoreInvalid(indexScore) then
					if indexScore:GetGrade() ~= "Grade_Failed" then
						local temp = getScoreComboBreaks(indexScore)
						if temp < lowest then
							lowest = temp
							bestScore = indexScore
						end
					end
				end
			end
		end
	end
	return bestScore
end

function getBestMaxCombo(pn, ignore, rate)
	if not rate then rate = "1.0x" end
	local highest = 0
	local bestScore
	local hsTable = getScoreTable(pn, rate)
	if hsTable ~= nil and #hsTable >= 1 then
		for i = 1, #hsTable do
			if i ~= ignore then
				local indexScore = hsTable[i]
				if indexScore ~= nil and not IsScoreInvalid(indexScore) then
					local temp = getScoreMaxCombo(indexScore)
					if temp > highest then
						highest = temp
						bestScore = indexScore
					end
				end
			end
		end
	end
	return bestScore
end

------------------------------------------------------------
-- TIMING STATISTICS
------------------------------------------------------------
function wifeMean(t)
	local c = #t
	local m = 0
	if c == 0 then
		return 0
	end
	local o = 0
	for i = 1, c do
		-- ignore EO misses and replay mines
		if t[i] ~= 1000 and t[i] ~= -1100 then
			o = o + t[i]
		else
			m = m + 1
		end
	end
	return o / (c - m)
end

function wifeAbsMean(t)
	local c = #t
	local m = 0
	if c == 0 then
		return 0
	end
	local o = 0
	for i = 1, c do
		-- ignore EO misses and replay mines
		if t[i] ~= 1000 and t[i] ~= -1100 then
			o = o + math.abs(t[i])
		else
			m = m + 1
		end
	end
	return o / (c - m)
end

function wifeSd(t)
	local u = wifeMean(t)
	local u2 = 0
	local m = 0
	for i = 1, #t do
		-- ignore EO misses and replay mines
		if t[i] ~= 1000 and t[i] ~= -1100 then
			u2 = u2 + (t[i] - u) ^ 2
		else
			m = m + 1
		end
	end
	if (#t - 1 - m) <= 0 then return 0 end
	return math.sqrt(u2 / (#t - 1 - m))
end

function wifeRange(t)
	local x, y = 10000, 0
	for i = 1, #t do
		if math.abs(t[i]) <= 180 then		-- some replays (online ones i think?) are flagging misses as 1100 for some reason
			if math.abs(t[i]) < math.abs(x) then
				x = t[i]
			end
			if math.abs(t[i]) > math.abs(y) then
				y = t[i]
			end
		end
	end
	return x, y
end

function wifeMax(t)
	local _, y = wifeRange(t)
	return math.abs(y)
end

------------------------------------------------------------
-- JUDGE RESCORING
------------------------------------------------------------
-- For Window-based Scoring
function getRescoredJudge(offsetVector, judgeScale, judge)
	local tso = ms.JudgeScalers
	local ts = tso[judgeScale]
	local windows = {22.5, 45.0, 90.0, 135.0, 180.0, 500.0}
	local lowerBound = judge > 1 and windows[judge - 1] * ts or -1.0
	local upperBound = judge == 5 and math.max(windows[judge] * ts, 180.0) or windows[judge] * ts
	local judgeCount = 0

	if offsetVector == nil then return judgeCount end

	if judge > 5 then
		lowerBound = math.max(lowerBound, 180.0)
		for i = 1, #offsetVector do
			local x = math.abs(offsetVector[i])
			if (x > lowerBound) then
				judgeCount = judgeCount + 1
			end
		end
	else
		for i = 1, #offsetVector do
			local x = math.abs(offsetVector[i])
			if (x > lowerBound and x <= upperBound) then
				judgeCount = judgeCount + 1
			end
		end
	end
	return judgeCount
end

-- erf constants
local a1 =  0.254829592
local a2 = -0.284496736
local a3 =  1.421413741
local a4 = -1.453152027
local a5 =  1.061405429
local p  =  0.3275911

function erf(x)
	-- Save the sign of x
	local sign = 1
	if x < 0 then
		sign = -1
	end
	x = math.abs(x)

	-- A&S formula 7.1.26
	local t = 1.0/(1.0 + p*x)
	local y = 1.0 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t*math.exp(-x*x)

	return sign*y
end

function wife3(maxms, ts, version)
	ts = ts or 1.0
	local max_points = 2
	local miss_weight = -5.5
	local ridic = 5 * ts
	local max_boo_weight = 180 * ts
	local ts_pow = 0.75
	local zero = 65 * (ts^ts_pow)
	local dev = 22.7 * (ts^ts_pow)

	-- case handling
	if maxms <= ridic then			-- anything below this (judge scaled) threshold is counted as full pts
		return max_points
	elseif maxms <= zero then			-- ma/pa region, exponential
			return max_points * erf((zero - maxms) / dev)
	elseif maxms <= max_boo_weight then -- cb region, linear
		return (maxms - zero) * miss_weight / (max_boo_weight - zero)
	else							-- we can just set miss values manually
		return miss_weight			-- technically the max boo is always 180 above j4 however this is immaterial to the
	end								-- purpose of the scoring curve, which is to assign point values
end

-- holy shit this is fugly
function getRescoredWife3Judge(version, judgeScale, rst, useCurrent)
	local tso = ms.JudgeScalers
	local ts = (tso and tso[judgeScale]) or 1.0
	local totalPoints = 0.0
	local dvt = rst["dvt"]
	
	if dvt then
		for i = 1, #dvt do
			local offset = math.abs(dvt[i])
			totalPoints = totalPoints + wife3(offset, ts, version)
		end
	end
	
	-- Penalize holds, rolls, and mines.
	
	totalPoints = totalPoints + (math.max(0, rst["holdsMissed"] or 0) * -4.5)
	totalPoints = totalPoints + (math.max(0, rst["rollsMissed"] or 0) * -4.5)
	totalPoints = totalPoints + (math.max(0, rst["minesHit"] or 0) * -7)
	
	-- Use notesPassed for live percentage, totalNotes for evaluation.
	local maxNotes = 0
	if useCurrent then
		maxNotes = math.max(0, rst["notesPassed"] or 0)
	else
		maxNotes = math.max(0, rst["totalNotes"] or 0)
		-- For evaluation, we must penalize unplayed notes (from failing early) as misses.
		local unplayed = math.max(0, maxNotes - (rst["notesPassed"] or 0))
		totalPoints = totalPoints - (unplayed * 5.5) -- unhit notes are unhit
	end
	
	if maxNotes <= 0 then return 0 end
	local maxPoints = maxNotes * 2
	
	return math.min((totalPoints / maxPoints) * 100.0, 100)
end

function getRescoreElements(pss, score)
	local o = {}
	
	-- Base counts from PlayerStageStats (Live Stats)
	if pss then
		o["dvt"] = pss:GetOffsetVector()
		o["misses"] = math.max(0, (pss.GetTapNoteScores and pss:GetTapNoteScores("TapNoteScore_Miss")) or (pss.GetTapNoteScore and pss:GetTapNoteScore("TapNoteScore_Miss")) or 0)
		o["holdsMissed"] = math.max(0, (pss.GetHoldNoteScores and pss:GetHoldNoteScores("HoldNoteScore_LetGo")) or (pss.GetHoldNoteScore and pss:GetHoldNoteScore("HoldNoteScore_LetGo")) or 0)
		o["rollsMissed"] = 0
		o["minesHit"] = math.max(0, (pss.GetTapNoteScores and pss:GetTapNoteScores("TapNoteScore_HitMine")) or (pss.GetTapNoteScore and pss:GetTapNoteScore("TapNoteScore_HitMine")) or 0)
		
		-- Count hits
		local hits = 0
		for _, name in ipairs({"W1","W2","W3","W4","W5"}) do
			local count = (pss.GetTapNoteScores and pss:GetTapNoteScores("TapNoteScore_"..name)) or (pss.GetTapNoteScore and pss:GetTapNoteScore("TapNoteScore_"..name)) or 0
			if count ~= -1 then hits = hits + count end
		end
		o["tapsHit"] = hits
		o["notesPassed"] = hits + o["misses"]
		
		local steps = GAMESTATE:GetCurrentSteps()
		local radar = steps and steps:GetRadarValues(PLAYER_1)
		o["totalHolds"] = (radar and radar:GetValue("RadarCategory_Holds")) or 0
		o["totalRolls"] = (radar and radar:GetValue("RadarCategory_Rolls")) or 0
		o["totalMines"] = (radar and radar:GetValue("RadarCategory_Mines")) or 0
		o["totalNotes"] = (radar and radar:GetValue("RadarCategory_Notes")) or o["notesPassed"]
	elseif score then
		-- Use the Score-based retrieval (Moved from SelectMusic for global use)
		return getRescoreElementsFromScore(score)
	end
	
	return o
end

function getRescoreElementsFromScore(score)
	local o = {}
	if not score or not score:HasReplayData() then return nil end
	local replay = score:GetReplay()
	local ok = pcall(function() replay:LoadAllData() end)
	if not ok then return nil end
	
	local dvtTmp = replay:GetOffsetVector()
	local tvt = replay:GetTapNoteTypeVector()
	local dvt = {}
	if tvt ~= nil and #tvt > 0 then
		for i, d in ipairs(dvtTmp) do
			local ty = tvt[i]
			if ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
				dvt[#dvt+1] = d
			end
		end
	else
		dvt = dvtTmp
	end
	o["dvt"] = dvt
	
	o["misses"] = score:GetTapNoteScore("TapNoteScore_Miss")
	o["holdsMissed"] = score:GetHoldNoteScore("HoldNoteScore_LetGo")
	o["rollsMissed"] = 0
	o["minesHit"] = score:GetTapNoteScore("TapNoteScore_HitMine")
	
	local hits = 0
	for _, name in ipairs({"W1","W2","W3","W4","W5"}) do
		hits = hits + score:GetTapNoteScore("TapNoteScore_"..name)
	end
	o["tapsHit"] = hits
	o["notesPassed"] = hits + o["misses"]
	
	local steps = GAMESTATE:GetCurrentSteps()
	local radar = steps and steps:GetRadarValues(PLAYER_1)
	o["totalHolds"] = (radar and radar:GetValue("RadarCategory_Holds")) or score:GetHoldNoteScore("HoldNoteScore_Held") + o["holdsMissed"]
	o["totalRolls"] = (radar and radar:GetValue("RadarCategory_Rolls")) or 0
	o["totalMines"] = (radar and radar:GetValue("RadarCategory_Mines")) or score:GetTapNoteScore("TapNoteScore_AvoidMine") + o["minesHit"]
	o["totalNotes"] = (radar and radar:GetValue("RadarCategory_Notes")) or o["notesPassed"]
	
	return o
end

function getJ4NormalizedPercentage(score)
	if not score then return 0 end
	
	-- Detect if this is a live PlayerStageStats object (has GetTapNoteScores but not GetModifiers)
	local isLivePSS = (type(score.GetTapNoteScores) == "function" and type(score.GetModifiers) ~= "function")
	if isLivePSS then
		-- For live gameplay: use raw wife score as best approximation
		if type(score.GetWifeScore) == "function" then
			return score:GetWifeScore() * 100
		end
		return 0
	end
	
	-- 1. Engine method (Fastest, most reliable for newer Etterna)
	if type(score.GetRescoredWifeScore) == "function" then
		return score:GetRescoredWifeScore(4) * 100
	end
	
	-- 2. Manual rescore if replay exists
	if type(score.HasReplayData) == "function" and score:HasReplayData() then
		local rst = getRescoreElementsFromScore(score)
		if rst and rst.dvt then
			return getRescoredWife3Judge(3, 4, rst)
		end
	end
	
	-- 3. Fallback to raw wife score (If used on J4 or no replay available)
	if type(score.GetWifeScore) == "function" then
		return score:GetWifeScore() * 100
	end
	return 0
end

------------------------------------------------------------
-- OFFSET TO JUDGE COLOR
------------------------------------------------------------
function offsetToJudgeColor(offset, scale)
	if not offset then return HVColor.GetJudgmentColor("Miss") end
	scale = scale or 1
	local absOff = math.abs(offset)
	if absOff <= 22.5 * scale then
		return HVColor.GetJudgmentColor("W1")
	elseif absOff <= 45 * scale then
		return HVColor.GetJudgmentColor("W2")
	elseif absOff <= 90 * scale then
		return HVColor.GetJudgmentColor("W3")
	elseif absOff <= 135 * scale then
		return HVColor.GetJudgmentColor("W4")
	elseif absOff <= 180 * scale then
		return HVColor.GetJudgmentColor("W5")
	else
		return HVColor.GetJudgmentColor("Miss")
	end
end

------------------------------------------------------------
-- JUDGMENT HELPERS
------------------------------------------------------------
function getJudgeStrings(tns)
	return THEME:GetString("TapNoteScore", ToEnumShortString(tns))
end

-- Song length color (from sc-wh) -- unused for now?
function getSongLengthColor(len)
	if len > 600 then return color("#ff3333")
	elseif len > 300 then return color("#ffaa33")
	elseif len > 120 then return color("#ffff33")
	else return color("#cccccc") end
end

-- Common BPM from BPM+time list
function getCommonBPM(bpmsAndTimes, lastBeat)
	if not bpmsAndTimes or #bpmsAndTimes == 0 then return 0 end
	-- Simplified: return the BPM that takes up the most time
	local bpmDurations = {}
	for i = 1, #bpmsAndTimes do
		local bpm = bpmsAndTimes[i][2]
		local startBeat = bpmsAndTimes[i][1]
		local endBeat = lastBeat
		if i < #bpmsAndTimes then
			endBeat = bpmsAndTimes[i + 1][1]
		end
		local dur = endBeat - startBeat
		bpmDurations[bpm] = (bpmDurations[bpm] or 0) + dur
	end
	local maxDur = 0
	local commonBPM = 0
	for bpm, dur in pairs(bpmDurations) do
		if dur > maxDur then
			maxDur = dur
			commonBPM = bpm
		end
	end
	return commonBPM
end

-- NOTE: getAvatarPath() is provided by _fallback/Scripts/12 AssetsUtils.lua
-- Do NOT override it here. It uses the assetsConfig system (per-GUID).

------------------------------------------------------------
-- MISC ACTOR HELPERS
------------------------------------------------------------
function Alpha(c, a)
	return {c[1], c[2], c[3], a}
end

function Saturation(c, s)
	if type(c) ~= "table" then return c end
	local r, g, b = c[1] or 0, c[2] or 0, c[3] or 0
	local gray = r * 0.299 + g * 0.587 + b * 0.114
	return {gray + (r - gray) * s, gray + (g - gray) * s, gray + (b - gray) * s, c[4] or 1}
end

function SecondsToMSS(s)
	if not s or s < 0 then return "0:00" end
	return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

-- Initialize custom grades

------------------------------------------------------------
-- LEVELLING LOGIC
------------------------------------------------------------
HV.XPFile = "Save/Holographic Void_settings/profileXP.lua"
HV.XPData = nil

function HV.LoadXPData()
	if HV.XPData then return HV.XPData end
	if FILEMAN:DoesFileExist(HV.XPFile) then
		local file = RageFileUtil.CreateRageFile()
		if file:Open(HV.XPFile, 1) then
			local content = file:Read()
			local data = loadstring(content)
			if data then
				setfenv(data, {})
				local success, ret = pcall(data)
				if success and type(ret) == "table" then
					HV.XPData = ret
				end
			end
			file:Close()
		end
		file:destroy()
	end
	HV.XPData = HV.XPData or {}
	return HV.XPData
end

function HV.SaveXPData()
	if not HV.XPData then return end
	local file = RageFileUtil.CreateRageFile()
	if file:Open(HV.XPFile, 2) then
		local output = "return {\n"
		for guid, xp in pairs(HV.XPData) do
			output = output .. string.format("\t[%q] = %d,\n", guid, xp)
		end
		output = output .. "}"
		file:Write(output)
		file:Close()
	end
	file:destroy()
end

function HV.GetXP(profile)
	if not profile then return 0 end
	local data = HV.LoadXPData()
	local guid = profile:GetGUID()
	local xp = data[guid]
	
	if not xp then
		-- Migration: Initialize with raw note counts if no custom XP exists
		xp = profile:GetTotalTapsAndHolds() or 0
		data[guid] = xp
		HV.SaveXPData()
	end
	return tonumber(xp) or 0
end

function HV.SetXP(profile, value)
	if not profile then return end
	local data = HV.LoadXPData()
	local guid = profile:GetGUID()
	data[guid] = value
	HV.SaveXPData()
end

function HV.CalculateXPGain(pss, msd)
	if not pss or pss:GetFailed() then return 0 end
	
	local base = 0
	if type(pss.GetTotalTaps) == "function" then
		base = pss:GetTotalTaps() or 0
	end
	if base <= 0 then
		local possible = pss:GetRadarPossible()
		if possible then base = possible:GetValue("RadarCategory_TapsAndHolds") or 0 end
	end
	if base <= 0 then
		local steps = GAMESTATE:GetCurrentSteps()
		if steps then base = steps:GetRadarValues(GAMESTATE:GetEnabledPlayers()[1]):GetValue("RadarCategory_TapsAndHolds") or 0 end
	end
	if base <= 0 then base = 500 end -- completely fallback
	
	local msdFactor = math.max(1, (msd or 0) / 15)
	
	local score = 0
	if type(pss.GetWifeScore) == "function" then
		score = pss:GetWifeScore() or 0
	end
	
	-- Normalization: If score > 1.5, it's returning raw points rather than percentage.
	if score > 1.5 then
		score = score / (base * 2)
	end
	
	-- Safeguard against negative percentage
	score = math.max(0, score)
	
	local accFactor = math.pow(score / 0.93, 2)
	
	local gain = math.floor(base * msdFactor * accFactor)
	return math.max(0, gain)
end

function HV.GetLevelFromXP(xp)
	if not xp or xp < 0 then return 1 end
	-- Level = 90 * ln(XP / 5000 + 1) + 1
	-- Since custom XP scales differently, we might need to adjust the divisor (5000)
	-- but let's keep it consistent for now.
	return math.floor(90 * math.log(xp / 5000 + 1)) + 1
end

function HV.GetLevel(profile)
	if not profile then return 1 end
	return HV.GetLevelFromXP(HV.GetXP(profile))
end

function HV.GetXPForLevel(level)
	if level <= 1 then return 0 end
	-- XP = 5000 * (math.exp((level - 1) / 90) - 1)
	return 5000 * (math.exp((level - 1) / 90) - 1)
end

function HV.GetLevelProgressFromXP(xp)
	if not xp or xp < 0 then return 0, 0, 0 end
	local level = HV.GetLevelFromXP(xp)
	local xpCurrentLevel = HV.GetXPForLevel(level)
	local xpNextLevel = HV.GetXPForLevel(level + 1)
	
	local progress = (xp - xpCurrentLevel) / (xpNextLevel - xpCurrentLevel)
	local currentXPInLevel = math.floor(xp - xpCurrentLevel)
	local totalXPNeededForLevel = math.floor(xpNextLevel - xpCurrentLevel)
	
	return progress, currentXPInLevel, totalXPNeededForLevel
end

function HV.GetLevelProgress(profile)
	if not profile then return 0, 0, 0 end
	return HV.GetLevelProgressFromXP(HV.GetXP(profile))
end

function HV.GetLevelColor(level)
	if level >= 1000 then return color("#FFFFFF")    -- Rainbow/Diamond
	elseif level >= 900 then return color("#403010") -- Black/Gold
	elseif level >= 800 then return color("#404040") -- Black/Silver
	elseif level >= 700 then return color("#5C629E") -- Dark Blue
	elseif level >= 600 then return color("#5C9E62") -- Dark Green
	elseif level >= 500 then return color("#9E5C5C") -- Dark Red
	elseif level >= 400 then return color("#8B5C9E") -- Deep Purple
	elseif level >= 300 then return color("#98CFCE") -- Cyan/Aqua
	elseif level >= 250 then return color("#CF9898") -- Pink/Red
	elseif level >= 200 then return color("#CFD198") -- Orange/Gold
	elseif level >= 150 then return color("#CFA0CF") -- Purple
	elseif level >= 100 then return color("#80C0CF") -- Blue
	elseif level >= 50 then return color("#A0CFAB")  -- Green
	else return color("#A6A6A6") end                 -- Gray
end

HV.LastTotalXP = 0
HV.GameplaySessionValid = false

Trace("Holographic Void: 08 EtternaUtils.lua loaded (expanded).")
