--- Holographic Void: Etterna Utility Functions
-- Consolidates grade calculation, clear types, and score retrieval.

--- Calculate Etterna grade based on Wife percentage.
-- @param wifePct Float percentage (0-100)
-- @return Tier string (Tier01-Tier16, Failed, None)
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

--- Determine detailed clear type (MFC, PFC, etc.) from score data.
-- Works with both PlayerStageStats and HighScore objects.
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

function getCurRateString()
	local mods = GAMESTATE:GetSongOptionsString()
	if mods:find("Haste") then return "Haste" end
	local r = mods:match("(%d+%.%d+)xMusic")
	if r then return r .. "x" end
	return "1.0x"
end

Trace("Holographic Void: 08 EtternaUtils.lua loaded.")
