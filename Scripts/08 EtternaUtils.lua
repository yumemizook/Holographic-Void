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
	return string.format("%.2f", getCurRateValue()):gsub("%.?0+$", "") .. "x"
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
-- GRADE CALCULATION
------------------------------------------------------------
WifeTiers = {
	Grade_Tier01 = 0.999935, Grade_Tier02 = 0.9998, Grade_Tier03 = 0.9997,
	Grade_Tier04 = 0.99955,  Grade_Tier05 = 0.999,  Grade_Tier06 = 0.998,
	Grade_Tier07 = 0.997,    Grade_Tier08 = 0.99,   Grade_Tier09 = 0.965,
	Grade_Tier10 = 0.93,     Grade_Tier11 = 0.9,    Grade_Tier12 = 0.85,
	Grade_Tier13 = 0.8,      Grade_Tier14 = 0.7,    Grade_Tier15 = 0.6,
	Grade_Tier16 = 0.5,
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
	if not wifePct or wifePct <= 0 then return "Failed" end
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
	elseif pct >= 0.5 then return "Tier16"
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

local clearTypeTextFull = {
	ClearType_MFC = "Marvelous Full Combo", ClearType_WF = "Whiteflag",
	ClearType_SDP = "Single Digit Perfects", ClearType_PFC = "Perfect Full Combo",
	ClearType_BF = "Blackflag", ClearType_SDG = "Single Digit Greats",
	ClearType_FC = "Full Combo", ClearType_MF = "Missflag",
	ClearType_SDCB = "Single Digit CBs", ClearType_EXHC = "EX-Hard Clear",
	ClearType_HClear = "Hard Clear", ClearType_Clear = "Clear",
	ClearType_EClear = "Easy Clear", ClearType_AClear = "Assist Clear",
	ClearType_Failed = "Failed", ClearType_Invalid = "Invalid",
	ClearType_Noplay = "No Play", ClearType_None = "",
}

local clearTypeTextShort = {
	ClearType_MFC = "MFC", ClearType_WF = "WF", ClearType_SDP = "SDP",
	ClearType_PFC = "PFC", ClearType_BF = "BF", ClearType_SDG = "SDG",
	ClearType_FC = "FC", ClearType_MF = "MF", ClearType_SDCB = "SDCB",
	ClearType_EXHC = "EXH", ClearType_HClear = "HC", ClearType_Clear = "Clear",
	ClearType_EClear = "EC", ClearType_AClear = "AC", ClearType_Failed = "Failed",
	ClearType_Invalid = "Invalid", ClearType_Noplay = "No Play", ClearType_None = "",
}

local function getClearLevel(pn, steps, score)
	if score == nil or steps == nil then return 17 end
	local grade = score:GetWifeGrade()
	if grade == nil then return 17
	elseif grade == "Grade_Failed" then return 15 end

	local tns = {
		W1 = score:GetTapNoteScore("TapNoteScore_W1"),
		W2 = score:GetTapNoteScore("TapNoteScore_W2"),
		W3 = score:GetTapNoteScore("TapNoteScore_W3"),
		W4 = score:GetTapNoteScore("TapNoteScore_W4"),
		W5 = score:GetTapNoteScore("TapNoteScore_W5"),
		Miss = score:GetTapNoteScore("TapNoteScore_Miss"),
	}
	local hns = {
		Held = score:GetHoldNoteScore("HoldNoteScore_Held"),
	}

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

function getClearTypeText(ct)
	return clearTypeTextFull[ct] or ""
end

function getClearTypeShortText(ct)
	return clearTypeTextShort[ct] or ""
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
function wifeMean(dvt)
	if dvt == nil or #dvt == 0 then return 0 end
	local sum = 0
	for _, v in ipairs(dvt) do sum = sum + v end
	return sum / #dvt
end

function wifeAbsMean(dvt)
	if dvt == nil or #dvt == 0 then return 0 end
	local sum = 0
	for _, v in ipairs(dvt) do sum = sum + math.abs(v) end
	return sum / #dvt
end

function wifeSd(dvt)
	if dvt == nil or #dvt < 2 then return 0 end
	local m = wifeMean(dvt)
	local sum = 0
	for _, v in ipairs(dvt) do sum = sum + (v - m) ^ 2 end
	return math.sqrt(sum / (#dvt - 1))
end

------------------------------------------------------------
-- JUDGE RESCORING
------------------------------------------------------------
function getRescoredJudge(dvt, judgeDiff, window)
	if dvt == nil or #dvt == 0 then return 0 end
	local tst = ms.JudgeScalers
	local tso = tst[judgeDiff]
	if not tso then return 0 end

	-- Window: 1=W1, 2=W2, 3=W3, 4=W4, 5=W5, 6=Miss
	local windows = {22.5, 45, 90, 135, 180}
	local count = 0
	for _, v in ipairs(dvt) do
		local absOff = math.abs(v)
		if window == 6 then
			if absOff > tso * 180 then count = count + 1 end
		elseif window == 1 then
			if absOff <= tso * windows[1] then count = count + 1 end
		else
			if absOff > tso * windows[window - 1] and absOff <= tso * windows[window] then
				count = count + 1
			end
		end
	end
	return count
end

function getRescoredWife3Judge(scoreType, judgeDiff, rst)
	if rst == nil or rst["dvt"] == nil then return 0 end
	local tst = ms.JudgeScalers
	local tso = tst[judgeDiff]
	if not tso then return 0 end

	-- Use the engine's rescoring if available
	local dvt = rst["dvt"]
	local totalPoints = 0
	local maxPoints = rst["totalTaps"] * 2

	for _, v in ipairs(dvt) do
		local absOff = math.abs(v) * tso
		-- Wife3 curve approximation
		if absOff <= 22.5 then
			totalPoints = totalPoints + 2
		elseif absOff <= 45 then
			totalPoints = totalPoints + 2 - (absOff - 22.5) / 22.5
		elseif absOff <= 90 then
			totalPoints = totalPoints + 1 - (absOff - 45) / 45
		elseif absOff <= 135 then
			totalPoints = totalPoints + 0 - (absOff - 90) / 90
		elseif absOff <= 180 then
			totalPoints = totalPoints - 4
		else
			totalPoints = totalPoints - 8
		end
	end

	-- Subtract for missed holds/mines
	if rst["holdsMissed"] then
		totalPoints = totalPoints - rst["holdsMissed"] * 6
	end
	if rst["minesHit"] then
		totalPoints = totalPoints - rst["minesHit"] * 8
	end

	if maxPoints <= 0 then return 0 end
	return (totalPoints / maxPoints) * 100
end

function getRescoreElements(pss, score)
	local o = {}
	local dvt = pss:GetOffsetVector()
	o["dvt"] = dvt
	
	-- PSS uses GetRadarActual, HighScore uses GetRadarValues
	local radarpss = pss.GetRadarActual and pss:GetRadarActual() or pss:GetRadarValues()
	local radarscore = score.GetRadarValues and score:GetRadarValues() or score:GetRadarActual()
	
	o["totalHolds"] = (radarpss:GetValue("RadarCategory_Holds") or 0)
		+ (radarpss:GetValue("RadarCategory_Rolls") or 0)
	o["holdsHit"] = (radarscore:GetValue("RadarCategory_Holds") or 0)
		+ (radarscore:GetValue("RadarCategory_Rolls") or 0)
	o["holdsMissed"] = o["totalHolds"] - o["holdsHit"]
	o["minesHit"] = (radarpss:GetValue("RadarCategory_Mines") or 0)
		- (radarscore:GetValue("RadarCategory_Mines") or 0)
	o["totalTaps"] = pss:GetTotalTaps()
	return o
end

------------------------------------------------------------
-- OFFSET TO JUDGE COLOR
------------------------------------------------------------
function offsetToJudgeColor(offset, scale)
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

------------------------------------------------------------
-- AVATAR PATH
------------------------------------------------------------
function getAvatarPath(pn)
	local profile = PROFILEMAN:GetProfile(pn)
	if profile then
		local path = profile:GetDisplayName()
		-- Try to find avatar in profile directory
		-- Fallback to default
	end
	return THEME:GetPathG("", "avatar_default")
end

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

Trace("Holographic Void: 08 EtternaUtils.lua loaded (expanded).")
