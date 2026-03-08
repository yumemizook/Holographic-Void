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
}

local clearTypeReverse = {}
for k, v in pairs(clearTypeNames) do clearTypeReverse[v] = k end

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

	if grade == nil then return 17
	elseif grade == "Grade_Failed" then return 15 end

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
	if totalTaps ~= maxNotes then return 16 end -- Invalid

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
					highest = math.min(highest, getClearLevel(pn, steps, hScore))
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
	return "MFC"
end

------------------------------------------------------------
-- SCORE RETRIEVAL & COMPARISON
------------------------------------------------------------
function GetDisplayScore()
	local pn = PLAYER_1
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then return nil end
	
	-- Get scores for the current rate
	local rate = getCurRateString()
	local scores = getScoreTable(pn, rate, steps)
	
	if scores and #scores > 0 then
		-- Return the highest wife score
		return scores[1]
	end
	return nil
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
	local steps = GAMESTATE:GetCurrentSteps()
	if hsTable ~= nil and #hsTable >= 1 then
		for k, v in ipairs(hsTable) do
			if k ~= ignore then
				local indexScore = hsTable[k]
				if indexScore ~= nil then
					local temp = getScore(indexScore, steps, percent)
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
				if indexScore ~= nil then
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
				if indexScore ~= nil then
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
function getRescoredWife3Judge(version, judgeScale, rst)
	local tso = ms.JudgeScalers
	local ts = tso[judgeScale]
	local p = 0.0
	local dvt = rst["dvt"]
	if dvt == nil then return p end

	for i = 1, #dvt do							-- wife2 does not require abs due to ^2 but this does
		p = p + wife3(math.abs(dvt[i]), ts, version)
	end
	p = p + (rst["holdsMissed"] * -4.5)
	p = p + (rst["minesHit"] * -7)
	
	local totalTaps = rst["totalTaps"] or rst["totalNotes"] or #dvt
	if totalTaps == 0 or totalTaps < #dvt then 
		totalTaps = #dvt 
	end
	if totalTaps == 0 then return 0 end
	
	local finalPoints = math.min(totalTaps * 2, p)
	return (finalPoints / (totalTaps * 2)) * 100.0
end

function getRescoreElements(pss, score)
	local o = {}
	o["dvt"] = pss:GetOffsetVector()
	
	local radarpss = pss.GetRadarActual and pss:GetRadarActual() or pss:GetRadarValues()
	local radarscore = score.GetRadarValues and score:GetRadarValues() or score:GetRadarActual()
	
	o["totalHolds"] = (radarpss:GetValue("RadarCategory_Holds") or 0)
	o["totalRolls"] = (radarpss:GetValue("RadarCategory_Rolls") or 0)
	o["holdsHit"] = (radarscore:GetValue("RadarCategory_Holds") or 0)
	o["rollsHit"] = (radarscore:GetValue("RadarCategory_Rolls") or 0)
	o["holdsMissed"] = o["totalHolds"] - o["holdsHit"]
	o["rollsMissed"] = o["totalRolls"] - o["rollsHit"]
	o["minesHit"] = (radarpss:GetValue("RadarCategory_Mines") or 0) - (radarscore:GetValue("RadarCategory_Mines") or 0)
	
	o["totalTaps"] = pss:GetTotalTaps()
	o["tapsHit"] = #o["dvt"]
	o["misses"] = o["totalTaps"] - o["tapsHit"]
	
	local steps = GAMESTATE:GetCurrentSteps()
	if steps then
		local rv = steps:GetRadarValues(PLAYER_1)
		o["totalNotes"] = rv:GetValue("RadarCategory_Notes")
	else
		o["totalNotes"] = o["totalTaps"]
	end
	
	return o
end

------------------------------------------------------------
-- OFFSET TO JUDGE COLOR
------------------------------------------------------------
function offsetToJudgeColor(offset, scale)
	if not offset then return color("#E0A0A0") end
	scale = scale or 1
	local absOff = math.abs(offset)
	if absOff <= 22.5 * scale then
		return color("#FFFFFF")  -- Marvelous
	elseif absOff <= 45 * scale then
		return color("#E0E0A0")  -- Perfect
	elseif absOff <= 90 * scale then
		return color("#A0E0A0")  -- Great
	elseif absOff <= 135 * scale then
		return color("#A0C8E0")  -- Good
	elseif absOff <= 180 * scale then
		return color("#C8A0E0")  -- Bad
	else
		return color("#E0A0A0")  -- Miss
	end
end

------------------------------------------------------------
-- JUDGMENT HELPERS
------------------------------------------------------------
function getJudgeStrings(tns)
	return THEME:GetString("TapNoteScore", ToEnumShortString(tns))
end

-- Song length color (from sc-wh)
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

Trace("Holographic Void: 08 EtternaUtils.lua loaded (expanded).")
