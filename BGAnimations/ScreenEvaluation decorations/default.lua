--- Holographic Void: ScreenEvaluation Decorations
-- Full-featured evaluation screen ported from spawncamping-wallhack.
-- Features: Life/Combo graphs, Avatar+Player info, Grade+Score with rescoring,
--   SSR display, ClearType comparison, Tap/Hold/Mine judgments, Timing stats (mean/sd),
--   CB L/R breakdown, Paginated Local/Online Scoreboard, Full Offset Plot.

local song = GAMESTATE:GetCurrentSong()
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local steps = GAMESTATE:GetCurrentSteps()
local pn = GAMESTATE:GetEnabledPlayers()[1]
local profile = PROFILEMAN:GetProfile(pn)

-- State variables (declared early for function visibility)
local curScore = pss:GetHighScore()
local judge = (PREFSMAN:GetPreference("SortBySSRNormPercent") and 4 or GetTimingDifficulty())
local judges = {"TapNoteScore_W1","TapNoteScore_W2","TapNoteScore_W3","TapNoteScore_W4","TapNoteScore_W5","TapNoteScore_Miss"}

-- Rescoring/offset plot state
local nrv, dvt, ctt, ntt, totalTaps
local function updateVectors()
	nrv = pss:GetNoteRowVector()
	ctt = pss:GetTrackVector()
	ntt = pss:GetTapNoteTypeVector()
	totalTaps = pss:GetTotalTaps()
	dvt = pss:GetOffsetVector()
end
updateVectors()

-- Local timing helpers (to avoid nil global issues if scripts haven't reloaded)
local function localWifeMean(dvt) return wifeMean(dvt) end
local function localWifeAbsMean(dvt) return wifeAbsMean(dvt) end
local function localWifeSd(dvt) return wifeSd(dvt) end
local function localWifeMax(dvt) return wifeMax(dvt) end

-- LA/RA Ratio calculation (ported from Til Death)
-- Calculates Ludicrous Attack and Ridiculous Attack ratios from replay offsets
local function calculateRatios(score)
	local replay = score:GetReplay()
	if not replay then return -1, -1, -1, -1 end
	pcall(function() replay:LoadAllData() end)
	local offsetTable = replay:GetOffsetVector()
	local typeTable = replay:GetTapNoteTypeVector()
	if not offsetTable or #offsetTable == 0 or not typeTable or #typeTable == 0 then
		return -1, -1, -1, -1
	end

	-- Define judgment windows based on current judge
	local marvWindow = 22.5 * (ms.JudgeScalers[judge] or 1)
	local raThreshold = marvWindow / 2
	local laThreshold = raThreshold / 2

	local ludic = 0
	local ridicLA = 0
	local ridic = 0
	local marvRA = 0

	for i, o in ipairs(offsetTable) do
		if typeTable[i] == "TapNoteType_Tap" or typeTable[i] == "TapNoteType_HoldHead" then
			local off = math.abs(o) -- Already ms
			if off <= raThreshold then
				ridic = ridic + 1
			elseif off <= marvWindow then
				marvRA = marvRA + 1
			end
			if off <= laThreshold then
				ludic = ludic + 1
			elseif off <= raThreshold then
				ridicLA = ridicLA + 1
			end
		end
	end

	local ra = marvRA > 0 and (ridic / marvRA) or -1
	local la = ridicLA > 0 and (ludic / ridicLA) or -1
	return ra, la, ridic, marvRA, ludic, ridicLA
end

local hjudges = {"HoldNoteScore_Held","HoldNoteScore_LetGo","HoldNoteScore_MissedHold"}
local rate = getCurRate()
local rescoredPercentage
local usingCustomWindows = false
local lastSnapshot = nil
local showRATally = false

-- Cache for RA/LA ratios to avoid repeated replay loading
local cachedRatios = nil
local function clearRatioCache() cachedRatios = nil end
local function getRatios()
	if not cachedRatios then
		local ra, la, ridic, marvRA, ludic, ridicLA = calculateRatios(curScore)
		cachedRatios = {ra, la, ridic, marvRA, ludic, ridicLA}
	end
	return unpack(cachedRatios)
end

-- a helper to get the radar value for a score and fall back to playerstagestats if that fails
local function gatherRadarValue(radar, score)
    local n = score:GetRadarValues():GetValue(radar)
    if n == -1 then
        return pss:GetRadarActual():GetValue(radar)
    end
    return n
end

local songTotalNotes = steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
local songMaxPoints = songTotalNotes * 2

local function getRunningWife(wife, judged)
	if judged == 0 then return 0 end
	return wife * (songTotalNotes / judged)
end

local function clampJudge()
	if judge < 4 then judge = 4 end
	if judge > 9 then judge = 9 end
end
clampJudge()

-- Score table
local hsTable = getScoreTable(pn, rate)
local scoreIndex = 0
if hsTable then
	scoreIndex = getHighScoreIndex(hsTable, curScore)
end
local recScore = getBestScore(pn, scoreIndex, rate, true)
local clearType = getClearType(pn, steps, curScore)

-- Left/Right CB tracking
local tracks = pss:GetTrackVector()
local devianceTable = pss:GetOffsetVector()
local cbl, cbr, cbm = 0, 0, 0
local tst = ms.JudgeScalers
local ncol = steps and steps:GetNumColumns() or 4
local middleCol = (ncol - 1) / 2
local showMiddle = middleCol == math.floor(middleCol)

local function recountCBs()
	local tso = tst[judge] or 1
	cbl, cbr, cbm = 0, 0, 0
	if not ctt or not dvt then return end
	for i = 1, #dvt do
		if ctt[i] then
			-- Standard Etterna CB threshold is 90ms (J4). Scales with judge.
			if math.abs(dvt[i]) > tso * 90 then 
				if ctt[i] < middleCol then cbl = cbl + 1
				elseif ctt[i] > middleCol then cbr = cbr + 1
				else cbm = cbm + 1 end
			end
		end
	end
end
recountCBs()

local function getStatInfo()
	return {
		wifeMean(dvt),
		wifeAbsMean(dvt),
		wifeSd(dvt),
		wifeMax(dvt),
		cbl, cbr, cbm
	}
end

-- HV Color Palette
local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local dimText = brightText
local subText = brightText
local mainText = brightText
local bgCard = color("0.06,0.06,0.06,0.95")
local dividerColor = color("0.2,0.2,0.2,1")

-- Judgment colors (HV palette)
local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
}

-- Scroll support
local function scroller(event)
	if event.type == "InputEventType_FirstPress" then
		if event.DeviceInput.button == "DeviceButton_mousewheel up" then
			MESSAGEMAN:Broadcast("WheelUpSlow")
		elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
			MESSAGEMAN:Broadcast("WheelDownSlow")
		elseif event.DeviceInput.button == "DeviceButton_left mouse button" then
			MESSAGEMAN:Broadcast("MouseLeftClick", {event=event})
		end
	end
end

local function isOver(actor)
	if not actor or not actor.GetVisible or not actor:GetVisible() then return false end
	if actor.IsVisible and not actor:IsVisible() then return false end
	local x = actor:GetTrueX()
	local y = actor:GetTrueY()
	local w = actor:GetZoomedWidth()
	local h = actor:GetZoomedHeight()
	local ha = actor.GetHAlign and actor:GetHAlign() or 0
	local va = actor.GetVAlign and actor:GetVAlign() or 0
	local mx = INPUTFILTER:GetMouseX()
	local my = INPUTFILTER:GetMouseY()
	return mx >= x - w * ha and mx <= x + w * (1 - ha) and my >= y - h * va and my <= y + h * (1 - va)
end

local showGraphs = false

local t = Def.ActorFrame {
	Name = "EvalDecorations",
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(scroller)
		SCREENMAN:SetSystemCursorVisible(true)
		INPUTFILTER:SetMouseVisible(true)
	end,
	ScoreChangedMessageCommand = function(self)
		pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		curScore = pss:GetHighScore()
		updateVectors()
		clearRatioCache()
		self:RunCommandsOnChildren(function(self) self:playcommand("SetJudge") end)
		self:RunCommandsOnChildren(function(self) self:playcommand("On") end)
	end
}

-- Get rescore elements helper
local function getRescoreElems()
	local o = {}
	local radarpss = pss:GetRadarPossible()
	local radarscore = curScore:GetRadarValues()
	
	o["dvt"] = pss:GetOffsetVector()
	o["totalHolds"] = radarpss:GetValue("RadarCategory_Holds")
	o["totalRolls"] = radarpss:GetValue("RadarCategory_Rolls")
	o["holdsHit"] = radarscore:GetValue("RadarCategory_Holds")
	o["rollsHit"] = radarscore:GetValue("RadarCategory_Rolls")
	o["holdsMissed"] = o["totalHolds"] - o["holdsHit"]
	o["rollsMissed"] = o["totalRolls"] - o["rollsHit"]
	o["minesHit"] = radarpss:GetValue("RadarCategory_Mines") - radarscore:GetValue("RadarCategory_Mines")
	o["totalTaps"] = pss:GetTotalTaps()
	o["misses"] = pss:GetTapNoteScores("TapNoteScore_Miss")
	o["totalNotes"] = songTotalNotes
	return o
end


-- Rescore function (ported from EtternaUtils.lua)
local function getRescoredWife3Judge(judgeType, judge, rst)
	local totalPoints = 0
	local tso = ms.JudgeScalers[judge] or 1

	local dvt = rst["dvt"]
	if not dvt or #dvt == 0 then return 0 end

	for i = 1, #dvt do
		totalPoints = totalPoints + wife3(math.abs(dvt[i]), tso)
	end
	totalPoints = totalPoints + (rst["misses"] or 0) * -5.5
	totalPoints = totalPoints + (rst["minesHit"] or 0) * -7
	totalPoints = totalPoints + (rst["holdsMissed"] or 0) * -4.5
	totalPoints = totalPoints + (rst["rollsMissed"] or 0) * -4.5

	local maxPoints = (rst["totalNotes"] or rst["totalTaps"] or 0) * 2
	if maxPoints <= 0 then return 0 end

	local res = (totalPoints / maxPoints) * 100
	return math.min(res, 100) -- Only clamp upper bound
end

------------------------------------------------------------
-- LEFT PANEL: SCORE CARD
------------------------------------------------------------
local function scoreBoard(pn)
	local frameX = 10
	local frameY = 10
	local frameW = SCREEN_CENTER_X - 20
	local frameH = SCREEN_HEIGHT - 20
	local pad = 12

	local function highlight(self) self:queuecommand("Highlight") end

	local board = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(frameX, frameY)
			self:SetUpdateFunction(highlight)
		end,
		OffsetPlotModificationMessageCommand = function(self, params)
			if params.Name == "Coin" then
				self:playcommand("ToggleCustomWindows")
				return
			end

			if usingCustomWindows then
				if params.Name == "PrevJudge" then
					self:playcommand("MoveCustomWindowIndex", {direction=-1})
				elseif params.Name == "NextJudge" then
					self:playcommand("MoveCustomWindowIndex", {direction=1})
				end
				return
			end

			local rst = getRescoreElems()
			if params.Name == "PrevJudge" and judge > 1 then
				judge = judge - 1
				clampJudge()
				rescoredPercentage = getRescoredWife3Judge(3, judge, rst)
			elseif params.Name == "NextJudge" and judge < 9 then
				judge = judge + 1
				clampJudge()
				rescoredPercentage = getRescoredWife3Judge(3, judge, rst)
			end
			if params.Name == "ResetJudge" then
				judge = PREFSMAN:GetPreference("SortBySSRNormPercent") and 4 or GetTimingDifficulty()
				clampJudge()
				self:RunCommandsOnChildren(function(self) self:playcommand("ResetJudge") end)
			elseif params.Name ~= "ToggleHands" then
				self:RunCommandsOnChildren(function(self) self:playcommand("SetJudge") end)
			end
			recountCBs()
			pcall(function()
				local tso = tst[judge]
				if tso then
					local screen = SCREENMAN:GetTopScreen()
					if screen and screen.GetStageStats then
						local stats = screen:GetStageStats()
						if stats and stats.GetPlayerStageStats then
							local ppss = stats:GetPlayerStageStats()
							if ppss and screen.SetPlayerStageStatsFromReplayData then
								screen:SetPlayerStageStatsFromReplayData(ppss, tso, pss:GetHighScore())
							end
						end
					end
				end
			end)
		end,
		ToggleCustomWindowsMessageCommand = function(self)
			if inMulti then return end
			usingCustomWindows = not usingCustomWindows

			if not usingCustomWindows then
				unloadCustomWindowConfig()
				MESSAGEMAN:Broadcast("UnloadedCustomWindow")
				self:RunCommandsOnChildren(function(self) self:playcommand("SetJudge") end)
				pcall(function()
					local tso = tst[judge]
					local screen = SCREENMAN:GetTopScreen()
					screen:RescoreReplay(pss, tso, curScore or pss:GetHighScore(), false)
				end)
			else
				loadCurrentCustomWindowConfig()
				pcall(function()
					local tso = tst[judge]
					local screen = SCREENMAN:GetTopScreen()
					local success = screen:RescoreReplay(pss, tso, curScore or pss:GetHighScore(), currentCustomWindowConfigUsesOldestNoteFirst())
					if success then
						lastSnapshot = REPLAYS:GetActiveReplay():GetLastReplaySnapshot()
					end
				end)
				if lastSnapshot then
					MESSAGEMAN:Broadcast("LoadedCustomWindow")
				end
			end
			self:RunCommandsOnChildren(function(self) self:playcommand("UpdateCustomWindowVisibility") end)
		end,
		MoveCustomWindowIndexMessageCommand = function(self, params)
			if not usingCustomWindows then return end
			moveCustomWindowConfigIndex(params.direction)
			loadCurrentCustomWindowConfig()
			pcall(function()
				local tso = tst[judge]
				local screen = SCREENMAN:GetTopScreen()
				local success = screen:RescoreReplay(pss, tso, curScore or pss:GetHighScore(), currentCustomWindowConfigUsesOldestNoteFirst())
				if success then
					lastSnapshot = REPLAYS:GetActiveReplay():GetLastReplaySnapshot()
				end
			end)
			if lastSnapshot then
				MESSAGEMAN:Broadcast("LoadedCustomWindow")
			end
		end,
		ResetJudgeMessageCommand = function(self) recountCBs() end,
		SetJudgeMessageCommand = function(self) recountCBs() end,

		-- Main BG
		Def.Quad {
			InitCommand = function(self) self:halign(0):valign(0):zoomto(frameW, frameH):diffuse(bgCard) end
		},

		Def.Sprite {
			Name = "Banner",
			InitCommand = function(self) self:halign(0.5):valign(0):xy(frameW/2, pad + 10) end,
			OnCommand = function(self)
				if song then
					local bpath = song:GetBannerPath()
					if not bpath then bpath = THEME:GetPathG("Common", "fallback banner") end
					self:LoadBackground(bpath)
					self:scaletofit(0, 0, frameW - pad*2, 60)
				end
			end
		},

		-- Song Title
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 80):zoom(0.55):diffuse(brightText)
				self:maxwidth((frameW - pad*2) / 0.5)
			end,
			OnCommand = function(self) if song then self:settext(song:GetDisplayMainTitle()) end end
		},
		-- Artist
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 104):zoom(0.5):diffuse(subText)
				self:maxwidth((frameW - pad*2) / 0.5)
			end,
			OnCommand = function(self) if song then self:settext("// " .. song:GetDisplayArtist()) end end
		},
		-- Pack Name
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 120):zoom(0.4):diffuse(subText)
				self:maxwidth((frameW - pad*2) / 0.4)
			end,
			OnCommand = function(self) if song then self:settext(song:GetGroupName()) end end
		},
		-- Compact Difficulty + MSD
		Def.ActorFrame {
			InitCommand = function(self) self:xy(frameW - pad, pad + 80) end,
			
			-- Shorthand (colored by difficulty type)
			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(1):valign(1):xy(-58, 16):zoom(0.55)
				end,
				OnCommand = function(self)
					if steps then
						local diff = ToEnumShortString(steps:GetDifficulty())
						local diffShort = {
							Beginner = "BG", Easy = "EZ", Medium = "NM", Hard = "HD", Challenge = "IN", Edit = "ED"
						}
						self:settext(diffShort[diff] or diff:sub(1,2):upper())
						self:diffuse(HVColor.GetDifficultyColor(diff))
					end
				end
			},
			-- MSD (Common Large, 2 decimal points)
			LoadFont("Common Large") .. {
				InitCommand = function(self)
					self:halign(1):valign(0):xy(0, -2):zoom(0.6)
				end,
				OnCommand = function(self)
					if steps then
						local meter = steps:GetMSD(getCurRateValue(), 1)
						meter = meter == 0 and steps:GetMeter() or meter
						self:settextf("%.2f", meter)
						self:diffuse(HVColor.GetMSDRatingColor(meter))
					end
				end
			}
		},
		-- Rate
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):valign(0):xy(frameW - pad, pad + 100):zoom(0.45):diffuse(brightText)
			end,
			OnCommand = function(self) self:settextf("Rate: %s", rate) end
		},
		-- Timing judge display
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):valign(0):xy(frameW - pad, pad + 114):zoom(0.5):diffuse(dimText)
			end,
			OnCommand = function(self) self:settextf("Judge: %d", judge) end,
			SetJudgeCommand = function(self) self:settextf("Judge: %d", judge) end,
			ResetJudgeCommand = function(self) self:settextf("Judge: %d", judge) end
		},

		-- Separator
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 135):zoomto(frameW - pad*2, 1):diffuse(dividerColor)
			end
		},
	}

	-- ============================================================
	-- GRADE + SCORE AREA
	-- ============================================================
	board[#board + 1] = Def.ActorFrame {
		Name = "GradeScore",
		InitCommand = function(self) self:xy(pad, pad + 145) end,

		-- Grade
		LoadFont("Common Large") .. {
			Name = "GradeScoreLabel",
			InitCommand = function(self) self:halign(0):valign(0):xy(0, 0):zoom(0.7):diffuse(mainText) end,
			OnCommand = function(self)
				local grade = pss:GetWifeGrade()
				self:settext(HV.GetGradeName(ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
			end
		},
		-- SSR
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(10, 45):zoom(0.8):diffuse(subText) end,
			OnCommand = function(self)
				local ssr = curScore:GetSkillsetSSR("Overall")
				self:settextf("%.2f", ssr)
				self:diffuse(HVColor.GetMSDRatingColor(ssr))
			end
		},

		-- Custom Scoring Label
		LoadFont("Common Normal") .. {
			Name = "CustomScoringLabel",
			InitCommand = function(self) self:halign(0):valign(0):xy(110, -5):zoom(0.45):diffuse(accentColor):visible(false) end,
			OnCommand = function(self)
				if usingCustomWindows then
					self:visible(true)
					self:settext(getCurrentCustomWindowConfigName())
				end
			end,
			LoadedCustomWindowMessageCommand = function(self)
				self:visible(true)
				self:settext(getCurrentCustomWindowConfigName())
			end,
			UnloadedCustomWindowMessageCommand = function(self)
				self:visible(false)
			end
		},

		-- Wife Score
		LoadFont("Common Large") .. {
			Name = "WifeScoreLabel",
			InitCommand = function(self) self:halign(0):valign(0):xy(110, 5):zoom(0.65):diffuse(mainText) end,
			OnCommand = function(self)
				local wife = pss:GetWifeScore()
				-- In Etterna, GetWifeScore() is already absolute (song-wide) percentage.
				-- If we want to show it as points/points, we could, but showing negative % is fine.
				
				if wife >= 0.99 then
					self:settextf("%.4f%%", math.floor(wife * 1000000) / 10000)
				else
					self:settextf("%.2f%%", math.floor(wife * 10000) / 100)
				end
			end,
			SetJudgeCommand = function(self)
				if usingCustomWindows then return end
				if rescoredPercentage then
					if rescoredPercentage >= 99 then
						self:settextf("%.4f%%", math.floor(rescoredPercentage * 10000) / 10000)
					else
						self:settextf("%.2f%%", math.floor(rescoredPercentage * 100) / 100)
					end
				end
			end,
			LoadedCustomWindowMessageCommand = function(self)
				if not lastSnapshot then return end
				local wife = lastSnapshot:GetWifePercent() * 100
				if wife >= 99 then
					self:settextf("%.4f%%", math.floor(wife * 10000) / 10000)
				else
					self:settextf("%.2f%%", math.floor(wife * 100) / 100)
				end
			end,
			ResetJudgeMessageCommand = function(self) self:playcommand("On") end
		},
		-- DP (WifeDP)
		Def.ActorFrame {
			Name = "WifeDPDisplay",
			InitCommand = function(self) self:xy(110, 45) end,
			
			-- Whole part
			LoadFont("Common Normal") .. {
				Name = "WholeDP",
				InitCommand = function(self) self:halign(0):valign(1):xy(0, 5):zoom(0.8):diffuse(color("#55b0ff")) end,
				OnCommand = function(self)
					local dp = curScore.GetWifePoints and curScore:GetWifePoints() or (pss:GetWifeScore() * songMaxPoints)
					local whole = math.floor(dp)
					self:settext(whole)
				end,
				SetJudgeCommand = function(self)
					if rescoredPercentage then
						local dp = (rescoredPercentage / 100) * songMaxPoints
						self:settext(math.floor(dp))
					end
				end,
				ResetJudgeMessageCommand = function(self) self:playcommand("On") end
			},
			-- Decimal part
			LoadFont("Common Normal") .. {
				Name = "DecimalDP",
				InitCommand = function(self) self:halign(0):valign(1):xy(0, 5):zoom(0.35):diffuse(color("#55b0ff")) end,
				OnCommand = function(self)
					local dp = curScore.GetWifePoints and curScore:GetWifePoints() or (pss:GetWifeScore() * songMaxPoints)
					local wife = pss:GetWifeScore()
					local precision = (wife >= 0.93) and 4 or 2
					local format = "%." .. precision .. "f"
					local decimalStr = string.format(format, dp):match("%.(.*)")
					self:settext("." .. decimalStr)
					
					-- Adjust position based on whole part width
					local wholePart = self:GetParent():GetChild("WholeDP")
					self:x(wholePart:GetWidth() * wholePart:GetZoom() + 1)
				end,
				SetJudgeCommand = function(self)
					if rescoredPercentage then
						local dp = (rescoredPercentage / 100) * songMaxPoints
						local precision = (rescoredPercentage >= 93) and 4 or 2
						local format = "%." .. precision .. "f"
						local decimalStr = string.format(format, dp):match("%.(.*)")
						self:settext("." .. decimalStr)
						
						local wholePart = self:GetParent():GetChild("WholeDP")
						self:x(wholePart:GetWidth() * wholePart:GetZoom() + 1)
					end
				end,
				ResetJudgeMessageCommand = function(self) self:playcommand("On") end
			},
		},
		-- DP slash (Total Score)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(110, 52):zoom(0.35):diffuse(subText) end,
			OnCommand = function(self)
				self:settextf("/ %.2f", songMaxPoints)
			end
		},
		-- Personal Best / Record Comparison (Pacemaker Text)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(110, 70):zoom(0.45):diffuse(subText) end,
			OnCommand = function(self)
				if recScore then
					local pbDp = recScore.GetWifePoints and recScore:GetWifePoints() or (recScore:GetWifeScore() * songMaxPoints)
					local curDp = pss:GetWifeScore() * songMaxPoints
					local diff = curDp - pbDp
					
					self:settextf("PB: %.2f (%+5.2f)", pbDp, diff)
				else
					self:settext("PB: New!"):diffuse(accentColor)
				end
			end
		},

		-- MF (Manip Factor)
		LoadActor("manipfactor") .. {
			InitCommand = function(self) self:xy(280, 10) end
		},

		-- Clear Type Display Area
		Def.ActorFrame {
			InitCommand = function(self) self:xy(280, 45) end,

			-- Current Clear Type
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):zoom(0.5) end,
				OnCommand = function(self)
					self:settext(getClearTypeText(clearType)):diffuse(getClearTypeColor(clearType))
				end
			},
			-- Best Clear Type Comparison (Below)
			Def.ActorFrame {
				InitCommand = function(self) self:xy(0, 15) end,
				
				LoadFont("Common Normal") .. {
					Name = "BestLabel",
					InitCommand = function(self) self:halign(0):valign(0):zoom(0.4) end,
					OnCommand = function(self)
						if hsTable then
							local recCT = getHighestClearType(pn, steps, hsTable, scoreIndex)
							self:settextf("Best: %s", getClearTypeText(recCT))
							self:diffuse(getClearTypeColor(recCT)):diffusealpha(0.6)
						end
					end
				},
				LoadFont("Common Normal") .. {
					Name = "BestArrow",
					InitCommand = function(self) self:halign(0):valign(0):zoom(0.4):visible(false) end,
					OnCommand = function(self)
						self:settext("")
					end
				}
			}
		},
	}


	-- ============================================================
	-- TWO-COLUMN STATS AREA
	-- ============================================================
	local statsStartY = pad + 230
	local col1X = pad
	local col2X = (frameW / 2) + 5
	local rowH = 18
	
	-- Separator
	board[#board + 1] = Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(pad, statsStartY):zoomto(frameW - pad*2, 1):diffuse(dividerColor)
		end
	}

	-- Judgment Tally Frame (Column 1)
	local tallyFrame = Def.ActorFrame {
		Name = "JudgmentTally",
		InitCommand = function(self) self:SetUpdateFunction(highlight) end,
		HighlightCommand = function(self)
			if usingCustomWindows then
				if showRATally then showRATally = false self:playcommand("RATallyChanged") end
				return
			end
			local over = isOver(self:GetChild("HoverArea"))
			if over ~= showRATally then
				showRATally = over
				self:playcommand("RATallyChanged")
			end
		end,

		Def.Quad {
			Name = "HoverArea",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(col1X, statsStartY + 20):zoomto(col2X - pad - 5, rowH * 6 + 4):diffusealpha(0)
			end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(col1X, statsStartY + 8):zoom(0.45):diffuse(subText)
							:settext(THEME:GetString("ScreenEvaluation", "CategoryJudgment"))
					end,
		}
	}
	board[#board + 1] = tallyFrame

	local raLabels = {"Ludicrous", "Ridiculous", "Marvelous", "Perfect", "Great", "Miss"}
	local raColors = {color("#FF69B4"), color("#FFD700"), color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"), color("#E0A0A0")}
	
	for k, v in ipairs(judges) do
		local jy = statsStartY + 28 + (k - 1) * rowH
		-- Label
		tallyFrame[#tallyFrame + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):xy(col1X, jy):zoom(0.45):diffuse(judgmentColors[k])
				self:settext(getJudgeStrings(v))
			end,
			RATallyChangedCommand = function(self)
				if showRATally then
					self:settext(raLabels[k]):diffuse(raColors[k])
				elseif usingCustomWindows then
					if getCustomWindowConfigJudgmentName then self:settext(getCustomWindowConfigJudgmentName(v)) end
					self:diffuse(judgmentColors[k])
				else
					self:settext(getJudgeStrings(v)):diffuse(judgmentColors[k])
				end
			end,
			LoadedCustomWindowMessageCommand = function(self)
				if getCustomWindowConfigJudgmentName then self:settext(getCustomWindowConfigJudgmentName(v)) end
			end,
			UnloadedCustomWindowMessageCommand = function(self) self:settext(getJudgeStrings(v)) end
		}
		-- Count
		tallyFrame[#tallyFrame + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(col2X - pad - 40, jy):zoom(0.55):diffuse(brightText) end,
			OnCommand = function(self) self:settext(pss:GetTapNoteScores(v)) end,
			SetJudgeCommand = function(self) 
				local count = getRescoredJudge(dvt, judge, k)
				self:settext(count)
			end,
			RATallyChangedCommand = function(self)
				if showRATally then
					local ra, la, ridic, marvRA, ludic, ridicLA = getRatios()
					if k == 1 then self:settext(ludic)
					elseif k == 2 then self:settext(ridicLA)
					elseif k == 3 then self:settext(marvRA)
					elseif k == 4 then self:settext(pss:GetTapNoteScores("TapNoteScore_W2"))
					elseif k == 5 then self:settext(pss:GetTapNoteScores("TapNoteScore_W3"))
					elseif k == 6 then self:settext(pss:GetTapNoteScores("TapNoteScore_Miss"))
					end
				else
					self:playcommand("SetJudge")
				end
			end,
			LoadedCustomWindowMessageCommand = function(self)
				if lastSnapshot then
					local jName = v:gsub("TapNoteScore_", "")
					self:settext(lastSnapshot:GetJudgments()[jName] or 0)
				end
			end,
			ResetJudgeMessageCommand = function(self) self:playcommand("On") end
		}
		-- Percentage
		tallyFrame[#tallyFrame + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(col2X - pad - 5, jy):zoom(0.35):diffuse(dimText) end,
			OnCommand = function(self)
				local pct = pss:GetPercentageOfTaps(v)
				if tostring(pct) == tostring(0/0) then pct = 0 end
				self:settextf("%.1f%%", pct * 100)
			end,
			SetJudgeCommand = function(self)
				if totalTaps > 0 then
					local count = getRescoredJudge(dvt, judge, k)
					self:settextf("%.1f%%", count / totalTaps * 100)
				end
			end,
			RATallyChangedCommand = function(self)
				if showRATally then
					local ra, la, ridic, marvRA, ludic, ridicLA = getRatios()
					local count = 0
					if k == 1 then count = ludic
					elseif k == 2 then count = ridicLA
					elseif k == 3 then count = marvRA
					elseif k == 4 then count = pss:GetTapNoteScores("TapNoteScore_W2")
					elseif k == 5 then count = pss:GetTapNoteScores("TapNoteScore_W3")
					elseif k == 6 then count = pss:GetTapNoteScores("TapNoteScore_Miss")
					end
					if totalTaps > 0 then self:settextf("%.1f%%", count / totalTaps * 100) end
				else
					self:playcommand("SetJudge")
				end
			end,
			ResetJudgeMessageCommand = function(self) self:playcommand("On") end
		}
	end

	-- Ratios (Bottom Column 1 - 2x2 Grid)
	local ratioStartY = statsStartY + 28 + (6 * rowH) + 12
	local ratioLabels = {"LA", "RA", "MA", "PA"}
	local ratioColors = {color("#FF69B4"), color("#FFD700"), color("#FFFFFF"), color("#E0E0A0")}
	for ri, rlabel in ipairs(ratioLabels) do
		local col = (ri - 1) % 2
		local row = math.floor((ri - 1) / 2)
		local rx = col1X + col * 75
		if col == 1 then rx = rx + 35 end
		local ry = ratioStartY + row * 26
		
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(col == 1 and 1 or 0):xy(col == 1 and rx + 30 or rx, ry):zoom(0.48):diffuse(ratioColors[ri]):settext(rlabel .. ":") end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(col == 1 and 1 or 0):xy(col == 1 and rx + 75 or rx + 40, ry):zoom(0.5):diffuse(mainText) end,
			OnCommand = function(self)
				if ri == 1 then
					local ra, la, ridic, marvRA, ludic, ridicLA = getRatios()
					if ridicLA == 0 then self:settext(ludic > 0 and "No Ridics" or "N/A"):diffuse(ludic > 0 and color("#FFFFFF") or dimText)
					else self:settextf("%.2f:1", la):rainbow() end
				elseif ri == 2 then
					local ra, la, ridic, marvRA, ludic, ridicLA = getRatios()
					if marvRA == 0 then self:settext(ridic > 0 and "No Marvs" or "N/A"):diffuse(ridic > 0 and ratioColors[2] or dimText)
					else self:settextf("%.2f:1", ra):diffuse(ratioColors[2]) end
				elseif ri == 3 then
					local w1 = pss:GetTapNoteScores("TapNoteScore_W1")
					local w2 = pss:GetTapNoteScores("TapNoteScore_W2")
					if w2 == 0 then self:settext(w1 > 0 and "No Perfs" or "N/A"):diffuse(w1 > 0 and color("#FFFFFF") or dimText)
					else self:settextf("%.2f:1", w1 / w2):diffuse(ratioColors[3]) end
				elseif ri == 4 then
					local w3 = pss:GetTapNoteScores("TapNoteScore_W3")
					if w3 == 0 then self:settext(pss:GetTapNoteScores("TapNoteScore_W2") > 0 and "No Greats" or "N/A"):diffuse(dimText)
					else self:settextf("%.2f:1", pss:GetTapNoteScores("TapNoteScore_W2") / w3):diffuse(ratioColors[4]) end
				end
			end,
			SetJudgeCommand = function(self)
				if ri == 3 or ri == 4 then
					local w1 = getRescoredJudge(dvt, judge, 1)
					local w2 = getRescoredJudge(dvt, judge, 2)
					local w3 = getRescoredJudge(dvt, judge, 3)
					if ri == 3 then
						if w2 == 0 then self:settext(w1 > 0 and "No Perfs" or "N/A")
						else self:settextf("%.2f:1", w1 / w2) end
					else
						if w3 == 0 then self:settext(w2 > 0 and "No Greats" or "N/A")
						else self:settextf("%.2f:1", w2 / w3) end
					end
				else
					self:playcommand("On")
				end
			end,
			ResetJudgeMessageCommand = function(self) self:playcommand("On") end
		}
	end

	-- Column 2: Holds / Mines
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(col2X, statsStartY + 8):zoom(0.45):diffuse(subText):settext("Holds & Stats") end
	}
	local holdLabels = {"Hold OK", "Hold NG", "Mines Hit"}
	for i, label in ipairs(holdLabels) do
		local hy = statsStartY + 28 + (i - 1) * rowH
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):xy(col2X, hy):zoom(0.42):diffuse(subText):settext(label .. ":") end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(frameW - pad, hy):zoom(0.45):diffuse(mainText) end,
			OnCommand = function(self)
				if i == 1 then self:settext(pss:GetHoldNoteScores("HoldNoteScore_Held"))
				elseif i == 2 then self:settext(pss:GetHoldNoteScores("HoldNoteScore_LetGo"))
				elseif i == 3 then self:settext(pss:GetTapNoteScores("TapNoteScore_HitMine")) end
			end
		}
	end

	-- Column 2: Timing Stats
	local timingStartY = statsStartY + 28 + (3 * rowH)
	local tStatLabels = {"Mean", "Std Dev", "Max Dev"}
	for i, label in ipairs(tStatLabels) do
		local ty = timingStartY + (i - 1) * rowH
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):xy(col2X, ty):zoom(0.42):diffuse(subText):settext(label .. ":") end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(frameW - pad, ty):zoom(0.45):diffuse(mainText) end,
			OnCommand = function(self)
				if i == 1 then self:settextf("%.2fms", wifeMean(dvt))
				elseif i == 2 then self:settextf("%.2fms", wifeSd(dvt))
				elseif i == 3 then self:settextf("%.2fms", wifeMax(dvt)) end
			end,
			SetJudgeCommand = function(self) self:playcommand("On") end
		}
	end

	-- Column 2: Note Types
	local ntStartY = ratioStartY
	local noteTypeLabels = {"Taps", "Holds", "Rolls", "Lifts", "Mines"}
	local noteTypeRadars = {"RadarCategory_Notes", "RadarCategory_Holds", "RadarCategory_Rolls", "RadarCategory_Lifts", "RadarCategory_Mines"}
	for ni, nlabel in ipairs(noteTypeLabels) do
		local ny = ntStartY + (ni - 1) * 16
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):xy(col2X, ny - 7):zoom(0.32):diffuse(subText):settext(nlabel .. ":") end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):xy(frameW - pad, ny -7):zoom(0.35):diffuse(mainText) end,
			OnCommand = function(self)
				if steps then
					local possible = steps:GetRadarValues(pn):GetValue(noteTypeRadars[ni])
					local actual = pss:GetRadarActual():GetValue(noteTypeRadars[ni])
					self:settextf("%d/%d", actual, possible)
				end
			end
		}
	end

	return board
end

t[#t + 1] = scoreBoard(PLAYER_1)

------------------------------------------------------------
-- RIGHT PANEL: OFFSET PLOT + SCOREBOARD
------------------------------------------------------------
local inMulti = Var("LoadingScreen") == "ScreenNetEvaluation"
local rightX = SCREEN_CENTER_X + 10
local rightW = SCREEN_CENTER_X - 20
local offsetPlotHeight = 160

t[#t + 1] = Def.ActorFrame {
	Name = "RightPanel",
	InitCommand = function(self) self:x(rightX) end,
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(scroller)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" then
				-- Judge cycling
				if event.button == "EffectUp" then
					if usingCustomWindows then
						MESSAGEMAN:Broadcast("MoveCustomWindowIndex", {direction = 1})
					else
						MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "NextJudge"})
					end
				elseif event.button == "EffectDown" then
					if usingCustomWindows then
						MESSAGEMAN:Broadcast("MoveCustomWindowIndex", {direction = -1})
					else
						MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "PrevJudge"})
					end
				elseif event.button == "MenuUp" then
					if usingCustomWindows then
						MESSAGEMAN:Broadcast("ToggleCustomWindows")
					else
						MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "ResetJudge"})
					end
				elseif event.button == "MenuDown" or event.DeviceInput.button == "DeviceButton_down" or event.button == "Down" then
					if not usingCustomWindows then
						MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "ToggleHands"})
					end
				elseif event.button == "Coin" then
					MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "Coin"})
				end
			end
		end)
	end,

	-- BG
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(0, 10):zoomto(rightW, SCREEN_HEIGHT - 20):diffuse(bgCard)
		end
	},

	-- Toggle Offset Plot / Graphs
	Def.Quad {
		InitCommand = function(self)
			self:xy(rightW, 20):zoomto(110, 24):halign(1):diffuse(accentColor):diffusealpha(0.2)
		end,
		UpdateToggleMessageCommand = function(self)
			self:diffusealpha(showGraphs and 0.4 or 0.2)
		end,
		MouseLeftClickMessageCommand = function(self)
			if isOver(self) then
				showGraphs = not showGraphs
				MESSAGEMAN:Broadcast("ToggleGraphs")
				MESSAGEMAN:Broadcast("UpdateToggle")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(rightW - 55, 20):zoom(0.42):settext("Toggle Graphs"):diffuse(brightText)
		end
	},

	-- ============================================================
	-- GRAPHS AREA
	-- ============================================================
	Def.ActorFrame {
		Name = "Graphs",
		InitCommand = function(self) self:xy(0, 40) self:visible(showGraphs) end,
		ToggleGraphsMessageCommand = function(self) self:visible(showGraphs) end,

		-- Graph Area Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(10, -15):zoom(0.45):halign(0):diffuse(subText)
				self:settext("Combo & Life Graph")
			end,
		},

		-- Life Graph BG
		Def.GraphDisplay {
			InitCommand = function(self) 
				self:Load("GraphDisplay") 
				self:xy(0, 0):zoomto(rightW, 80):halign(0):valign(0)
			end,
			BeginCommand = function(self)
				pcall(function()
					local ss = SCREENMAN:GetTopScreen():GetStageStats()
					self:Set(ss, pss)
					self:diffusealpha(0.3)
					pcall(function() self:GetChild("Line"):diffusealpha(0) end)
				end)
			end
		},

		-- Combo Graph
		Def.ComboGraph {
			InitCommand = function(self) 
				self:Load("ComboGraph" .. ToEnumShortString(pn)) 
				self:xy(0, 80):zoomto(rightW, 80):halign(0):valign(0)
			end,
			BeginCommand = function(self)
				pcall(function()
					local ss = SCREENMAN:GetTopScreen():GetStageStats()
					self:Set(ss, pss)
				end)
			end
		},
	},

	-- ============================================================
	-- OFFSET PLOT (MOVED HERE)
	-- ============================================================
	Def.ActorFrame {
		Name = "OffsetPlotWrapper",
		InitCommand = function(self) self:xy(0, 50) self:visible(not showGraphs) end,
		ToggleGraphsMessageCommand = function(self) self:visible(not showGraphs) end,
		
		LoadActor(THEME:GetPathG("", "OffsetGraph")) .. {
			InitCommand = function(self)
				self:xy(10, 20)
			end,
			OnCommand = function(self)
				self:RunCommandsOnChildren(function(child)
					child:playcommand("Update", {
						width = rightW - 20,
						height = 100,
						song = song,
						steps = steps,
						nrv = nrv,
						dvt = dvt,
						ctt = ctt,
						ntt = ntt,
						columns = steps and steps:GetNumColumns() or 4,
						cbl = cbl,
						cbr = cbr,
						cbm = cbm,
						showMiddle = showMiddle
					})
				end)
			end,
			SetJudgeMessageCommand = function(self) self:playcommand("On") end,
		},
		-- Offset Plot Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(10, -10):zoom(0.55):halign(0):diffuse(subText)
				self:settext(THEME:GetString("ScreenEvaluation", "CategoryOffset"))
			end,
		},
	},
}

-- ============================================================
-- SCOREBOARD (loaded from external files)
-- ============================================================
local scoreboardFrame = Def.ActorFrame {
	Name = "ScoreboardContainer",
	InitCommand = function(self) self:xy(rightX + 10, offsetPlotHeight + 130) end,
}

if inMulti then
	scoreboardFrame[#scoreboardFrame + 1] = LoadActor("MPscoreboard")
else
	scoreboardFrame[#scoreboardFrame + 1] = LoadActor("online_leaderboard")
end

t[#t + 1] = scoreboardFrame
t[#t + 1] = LoadActor("../_cursor")

return t
