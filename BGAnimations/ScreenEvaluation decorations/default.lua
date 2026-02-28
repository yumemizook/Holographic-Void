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

-- Vectors for rescoring/offset plot
local nrv = pss:GetNoteRowVector()
local dvt = pss:GetOffsetVector()
local ctt = pss:GetTrackVector()
local ntt = pss:GetTapNoteTypeVector()
local totalTaps = pss:GetTotalTaps()

-- Score/Judge state
local judges = {"TapNoteScore_W1","TapNoteScore_W2","TapNoteScore_W3","TapNoteScore_W4","TapNoteScore_W5","TapNoteScore_Miss"}
local hjudges = {"HoldNoteScore_Held","HoldNoteScore_LetGo","HoldNoteScore_MissedHold"}
local rate = getCurRate()
local judge = (PREFSMAN:GetPreference("SortBySSRNormPercent") and 4 or GetTimingDifficulty())
local rescoredPercentage

local function clampJudge()
	if judge < 4 then judge = 4 end
	if judge > 9 then judge = 9 end
end
clampJudge()

-- Score table
local hsTable = getScoreTable(pn, rate)
local scoreIndex = 0
if hsTable then
	scoreIndex = getHighScoreIndex(hsTable, pss:GetHighScore())
end
local curScore = pss:GetHighScore()
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
	if not tracks or not devianceTable then return end
	for i = 1, #devianceTable do
		if tracks[i] then
			if math.abs(devianceTable[i]) > tso * 90 then
				if tracks[i] < middleCol then cbl = cbl + 1
				elseif tracks[i] > middleCol then cbr = cbr + 1
				else cbm = cbm + 1 end
			end
		end
	end
end
recountCBs()

local statInfo = {
	wifeMean(devianceTable),
	wifeAbsMean(devianceTable),
	wifeSd(devianceTable),
	cbl, cbr, cbm
}

-- HV Color Palette
local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
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
		end
	end
end

local t = Def.ActorFrame {
	Name = "EvalDecorations"
}

-- Get rescore elements helper
local function getRescoreElems()
	return getRescoreElements(pss, curScore)
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
					SCREENMAN:GetTopScreen():SetPlayerStageStatsFromReplayData(
						SCREENMAN:GetTopScreen():GetStageStats():GetPlayerStageStats(), tso, pss:GetHighScore())
				end
			end)
		end,
		ResetJudgeCommand = function(self) recountCBs() end,
		SetJudgeCommand = function(self) recountCBs() end,

		-- Main BG
		Def.Quad {
			InitCommand = function(self) self:halign(0):valign(0):zoomto(frameW, frameH):diffuse(bgCard) end
		},

		-- Banner
		Def.Sprite {
			Name = "Banner",
			InitCommand = function(self) self:halign(0):valign(0):xy(pad, pad) end,
			OnCommand = function(self)
				if song then
					local bpath = song:GetBannerPath()
					if not bpath then bpath = THEME:GetPathG("Common", "fallback banner") end
					self:LoadBackground(bpath)
					self:scaletofit(0, 0, 140, 44)
				end
			end
		},

		-- Song Title
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 150, pad):zoom(0.5):diffuse(brightText)
				self:maxwidth((frameW - pad - 160) / 0.5)
			end,
			OnCommand = function(self) if song then self:settext(song:GetDisplayMainTitle()) end end
		},
		-- Artist
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 150, pad + 20):zoom(0.3):diffuse(subText)
				self:maxwidth((frameW - pad - 160) / 0.3)
			end,
			OnCommand = function(self) if song then self:settext("// " .. song:GetDisplayArtist()) end end
		},
		-- Difficulty + Rate + MSD
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):valign(0):xy(frameW - pad, pad):zoom(0.35)
			end,
			OnCommand = function(self)
				if steps then
					local diff = ToEnumShortString(steps:GetDifficulty())
					local stype = ToEnumShortString(steps:GetStepsType()):gsub("_", " ")
					local meter = steps:GetMSD(getCurRateValue(), 1)
					meter = meter == 0 and steps:GetMeter() or meter
					self:settextf("%s %s %.1f", stype, diff, meter)
					self:diffuse(HVColor.GetDifficultyColor(diff))
				end
			end
		},
		-- Rate
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):valign(0):xy(frameW - pad, pad + 18):zoom(0.28):diffuse(dimText)
			end,
			OnCommand = function(self) self:settextf("Rate: %s", rate) end
		},
		-- Timing judge display
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):valign(0):xy(frameW - pad, pad + 32):zoom(0.22):diffuse(dimText)
			end,
			OnCommand = function(self) self:settextf("Judge: %d", judge) end,
			SetJudgeCommand = function(self) self:settextf("Judge: %d", judge) end,
			ResetJudgeCommand = function(self) self:settextf("Judge: %d", judge) end
		},

		-- Separator
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 55):zoomto(frameW - pad*2, 1):diffuse(dividerColor)
			end
		},
	}

	-- ============================================================
	-- GRADE + SCORE AREA
	-- ============================================================
	board[#board + 1] = Def.ActorFrame {
		Name = "GradeScore",
		InitCommand = function(self) self:xy(pad, pad + 65) end,

		-- Life Graph BG
		Def.GraphDisplay {
			InitCommand = function(self) self:Load("GraphDisplay") end,
			BeginCommand = function(self)
				pcall(function()
					local ss = SCREENMAN:GetTopScreen():GetStageStats()
					self:Set(ss, pss)
					self:diffusealpha(0.3)
					self:y(20)
					pcall(function() self:GetChild("Line"):diffusealpha(0) end)
				end)
			end
		},

		-- Grade letter
		LoadFont("Common Large") .. {
			Name = "GradeLetter",
			InitCommand = function(self) self:halign(0):valign(0):zoom(0.8) end,
			OnCommand = function(self)
				local grade = pss:GetHighScore():GetWifeGrade()
				self:settext(THEME:GetString("Grade", ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
			end,
			SetJudgeCommand = function(self)
				if rescoredPercentage then
					local g = getWifeGradeTier(rescoredPercentage)
					self:settext(THEME:GetString("Grade", ToEnumShortString(g)))
				end
			end,
			ResetJudgeCommand = function(self) self:playcommand("On") end
		},

		-- Wife%
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(68, 0):zoom(0.6):diffuse(accentColor) end,
			OnCommand = function(self)
				local ws = pss:GetHighScore():GetWifeScore()
				if ws > 0.99 then
					self:settextf("%.4f%%", math.floor(ws * 1000000) / 10000)
				else
					self:settextf("%.2f%%", math.floor(ws * 10000) / 100)
				end
			end,
			SetJudgeCommand = function(self)
				if rescoredPercentage then
					if rescoredPercentage > 99 then
						self:settextf("%05.4f%% (J%d)", rescoredPercentage, judge)
					else
						self:settextf("%05.2f%% (J%d)", rescoredPercentage, judge)
					end
				end
			end,
			ResetJudgeCommand = function(self) self:playcommand("On") end
		},

		-- SSR
		LoadFont("Common Normal") .. {
			Name = "SSR",
			InitCommand = function(self) self:halign(0):valign(0):xy(68, 24):zoom(0.32) end,
			OnCommand = function(self)
				local ssr = curScore:GetSkillsetSSR("Overall")
				if ssr > 0 then
					self:settextf("SSR: %.2f", ssr):diffuse(HVColor.GetMSDRatingColor(ssr))
				else
					self:settext("SSR: N/A"):diffuse(dimText)
				end
			end,
			HighlightCommand = function(self)
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local ax, ay = self:GetTrueX(), self:GetTrueY()
				local w, h = self:GetZoomedWidth(), self:GetZoomedHeight()
				local isOver = mx >= ax and mx <= ax + w and my >= ay - h/2 and my <= ay + h/2
				if isOver then
					local ssr = curScore:GetSkillsetSSR("Overall")
					self:settextf("Score Specific Rating: %.2f", ssr)
				else
					self:playcommand("On")
				end
			end
		},

		-- WifeDP
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(68, 40):zoom(0.26):diffuse(subText) end,
			OnCommand = function(self)
				if steps then
					local notes = steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
					local dp = pss:GetWifeScore() * notes * 2
					self:settextf("WifeDP: %.2f", dp)
				end
			end
		},

		-- Life %
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):valign(0):xy(frameW - pad * 3, 0):zoom(0.28):diffuse(dimText) end,
			OnCommand = function(self)
				local text = string.format("Life: %.0f%%", pss:GetCurrentLife() * 100)
				if pss:GetCurrentLife() == 0 then
					local ok, alive = pcall(function() return pss:GetAliveSeconds() end)
					if ok and alive then
						text = text .. string.format("\n%.2fs Survived", alive)
					end
				end
				self:settext(text)
			end
		},
	}

	-- ============================================================
	-- CLEAR TYPE
	-- ============================================================
	board[#board + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(pad, pad + 125) end,

		-- Divider
		Def.Quad {
			InitCommand = function(self) self:halign(0):valign(0):zoomto(frameW - pad*2, 1):diffuse(dividerColor) end
		},
		-- Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(0, 5):zoom(0.24):diffuse(dimText):settext("CLEAR TYPE") end
		},
		-- Current clear type
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(0, 22):zoom(0.38) end,
			OnCommand = function(self)
				self:settext(getClearTypeText(clearType)):diffuse(getClearTypeColor(clearType))
			end
		},
		-- Record clear type
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):valign(0):xy(frameW - pad*2, 22):zoom(0.28):diffusealpha(0.4) end,
			OnCommand = function(self)
				if hsTable then
					local recCT = getHighestClearType(pn, steps, hsTable, scoreIndex)
					self:settext(getClearTypeText(recCT)):diffuse(getClearTypeColor(recCT)):diffusealpha(0.4)
				end
			end
		},
		-- Comparison arrow
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):valign(0):xy(frameW - pad*2 - 100, 22):zoom(0.3) end,
			OnCommand = function(self)
				if hsTable then
					local recCT = getHighestClearType(pn, steps, hsTable, scoreIndex)
					local curLvl = getClearTypeLevel(clearType)
					local recLvl = getClearTypeLevel(recCT)
					if curLvl < recLvl then
						self:settext("▲"):diffuse(color("#7AFFAF"))
					elseif curLvl > recLvl then
						self:settext("▼"):diffuse(color("#FF7A7A"))
					else
						self:settext("—"):diffuse(dimText)
					end
				end
			end
		},
	}

	-- ============================================================
	-- TAP JUDGMENTS
	-- ============================================================
	local judgY = pad + 170
	board[#board + 1] = Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(pad, judgY):zoomto(frameW - pad*2, 1):diffuse(dividerColor)
		end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, judgY + 4):zoom(0.24):diffuse(accentColor):settext("JUDGMENTS") end
	}

	local itemSpacing = (frameW - pad*2) / 6
	for k, v in ipairs(judges) do
		local jx = pad + (k - 0.5) * itemSpacing
		-- Label
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(jx, judgY + 22):zoom(0.24):diffuse(judgmentColors[k])
				self:settext(getJudgeStrings(v))
			end
		}
		-- Count
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(jx, judgY + 38):zoom(0.38):diffuse(brightText) end,
			OnCommand = function(self) self:settext(pss:GetTapNoteScores(v)) end,
			SetJudgeCommand = function(self) self:settext(getRescoredJudge(dvt, judge, k)) end,
			ResetJudgeCommand = function(self) self:playcommand("On") end
		}
		-- Percentage
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(jx, judgY + 52):zoom(0.2):diffuse(dimText) end,
			OnCommand = function(self)
				local pct = pss:GetPercentageOfTaps(v)
				if tostring(pct) == tostring(0/0) then pct = 0 end
				self:settextf("%.1f%%", pct * 100)
			end,
			SetJudgeCommand = function(self)
				if totalTaps > 0 then
					self:settextf("%.1f%%", getRescoredJudge(dvt, judge, k) / totalTaps * 100)
				end
			end,
			ResetJudgeCommand = function(self) self:playcommand("On") end
		}
	end

	-- ============================================================
	-- HOLDS + MINES + STATS ROW
	-- ============================================================
	local statsY = judgY + 70
	board[#board + 1] = Def.Quad {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, statsY):zoomto(frameW - pad*2, 1):diffuse(dividerColor) end
	}

	-- Hold OK / NG / Missed
	local holdLabels = {"Hold OK", "Hold NG", "Mines Hit"}
	local holdX = pad
	for i, label in ipairs(holdLabels) do
		local hx = holdX + (i - 1) * (frameW - pad*2) / 5
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(hx, statsY + 5):zoom(0.22):diffuse(subText):settext(label) end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(hx, statsY + 18):zoom(0.32):diffuse(mainText) end,
			OnCommand = function(self)
				if i == 1 then self:settext(pss:GetHoldNoteScores("HoldNoteScore_Held"))
				elseif i == 2 then self:settext(pss:GetHoldNoteScores("HoldNoteScore_LetGo"))
				elseif i == 3 then self:settext(pss:GetTapNoteScores("TapNoteScore_HitMine")) end
			end
		}
	end

	-- Mean / |Mean| / Std Dev
	local mLabels = {"Mean", "|Mean|", "Std Dev"}
	for i, label in ipairs(mLabels) do
		local mx = holdX + (i - 1 + 3) * (frameW - pad*2) / 5
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(mx, statsY + 5):zoom(0.22):diffuse(subText):settext(label) end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(mx, statsY + 18):zoom(0.28):diffuse(mainText) end,
			OnCommand = function(self)
				if i == 1 then self:settextf("%.2fms", statInfo[1])
				elseif i == 2 then self:settextf("%.2fms", statInfo[2])
				elseif i == 3 then self:settextf("%.2fms", statInfo[3]) end
			end
		}
	end

	-- ============================================================
	-- MISS COUNT + CB BREAKDOWN + MAX COMBO
	-- ============================================================
	local miscY = statsY + 40
	board[#board + 1] = Def.Quad {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, miscY):zoomto(frameW - pad*2, 1):diffuse(dividerColor) end
	}

	-- Max Combo
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, miscY + 5):zoom(0.22):diffuse(subText):settext("Max Combo") end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, miscY + 18):zoom(0.32):diffuse(mainText) end,
		OnCommand = function(self) self:settext(pss:MaxCombo()) end
	}

	-- Miss Count
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)/4, miscY + 5):zoom(0.22):diffuse(subText):settext("Miss Count") end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)/4, miscY + 18):zoom(0.32):diffuse(mainText) end,
		OnCommand = function(self) self:settext(getScoreComboBreaks(curScore)) end
	}

	-- CBs Left / Right
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)*2/4, miscY + 5):zoom(0.22):diffuse(subText):settext("CBs") end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)*2/4, miscY + 18):zoom(0.26):diffuse(mainText) end,
		OnCommand = function(self)
			local text = string.format("L:%d  R:%d", cbl, cbr)
			if showMiddle then text = text .. string.format("  M:%d", cbm) end
			self:settext(text)
		end,
		SetJudgeCommand = function(self)
			local text = string.format("L:%d  R:%d", cbl, cbr)
			if showMiddle then text = text .. string.format("  M:%d", cbm) end
			self:settext(text)
		end,
		ResetJudgeCommand = function(self) self:playcommand("On") end
	}

	-- Score vs Record comparison
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)*3/4, miscY + 5):zoom(0.22):diffuse(subText):settext("vs Record") end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)*3/4, miscY + 18):zoom(0.28) end,
		OnCommand = function(self)
			if recScore then
				local curVal = getScore(curScore, steps, false)
				local recVal = getScore(recScore, steps, false)
				local diff = curVal - recVal
				local extra = diff >= 0 and "+" or ""
				self:settextf("%s%.2f", extra, diff)
				self:diffuse(diff >= 0 and color("#7AFFAF") or color("#FF7A7A"))
			else
				self:settext("New!"):diffuse(accentColor)
			end
		end
	}

	return board
end

t[#t + 1] = scoreBoard(PLAYER_1)

------------------------------------------------------------
-- RIGHT PANEL: OFFSET PLOT + SCOREBOARD
------------------------------------------------------------
local rightX = SCREEN_CENTER_X + 10
local rightW = SCREEN_CENTER_X - 20
local offsetPlotHeight = 160
local scoreListY = offsetPlotHeight + 30

-- Score list state
local scoreList = hsTable
local scoresPerPage = 5
local maxPages = scoreList and math.ceil(#scoreList / scoresPerPage) or 1
local curPage = 1
local isLocal = true
local offsetScoreIndex = scoreIndex
local offsetisLocal = true

local function movePage(n)
	if maxPages <= 1 then return end
	if n > 0 then
		curPage = ((curPage + n - 1) % maxPages) + 1
	else
		curPage = ((curPage + n + maxPages - 1) % maxPages) + 1
	end
	MESSAGEMAN:Broadcast("UpdateScoreList")
end

t[#t + 1] = Def.ActorFrame {
	Name = "RightPanel",
	InitCommand = function(self) self:x(rightX) end,
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(scroller)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" then
				if event.button == "MenuLeft" then movePage(-1)
				elseif event.button == "MenuRight" then movePage(1)

				-- Judge cycling
				elseif event.button == "EffectUp" then
					MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "NextJudge"})
				elseif event.button == "EffectDown" then
					MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "PrevJudge"})
				elseif event.button == "MenuUp" then
					MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "ResetJudge"})
				elseif event.button == "MenuDown" then
					MESSAGEMAN:Broadcast("OffsetPlotModification", {Name = "ToggleHands"})
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

	-- ============================================================
	-- OFFSET PLOT
	-- ============================================================
	LoadActor(THEME:GetPathG("", "OffsetGraph")) .. {
		InitCommand = function(self)
			self:xy(10, 20)
		end,
		OnCommand = function(self)
			self:RunCommandsOnChildren(function(child)
				child:playcommand("Update", {
					width = rightW - 20,
					height = offsetPlotHeight,
					song = song,
					steps = steps,
					nrv = nrv,
					dvt = dvt,
					ctt = ctt,
					ntt = ntt,
					columns = steps and steps:GetNumColumns() or 4
				})
			end)
		end,
		ShowScoreOffsetMessageCommand = function(self)
			-- When a score in the list is clicked, update the offset plot with its data
			if scoreList and scoreList[offsetScoreIndex] then
				local selScore = scoreList[offsetScoreIndex]
				if selScore:HasReplayData() then
					local replay = selScore:GetReplay()
					if replay then
						self:RunCommandsOnChildren(function(child)
							child:playcommand("Update", {
								width = rightW - 20,
								height = offsetPlotHeight,
								song = song,
								steps = steps,
								nrv = replay:GetNoteRowVector() or {},
								dvt = replay:GetOffsetVector() or {},
								ctt = replay:GetTrackVector() or {},
								ntt = replay:GetTapNoteTypeVector() or {},
								columns = steps and steps:GetNumColumns() or 4
							})
						end)
					end
				end
			end
		end
	},

	-- Offset Plot Label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(15, 15):zoom(0.2):diffuse(dimText):halign(0):settext("OFFSET PLOT")
		end
	},

	-- ============================================================
	-- SCOREBOARD HEADER
	-- ============================================================
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(15, offsetPlotHeight + 30):zoom(0.24):diffuse(accentColor):halign(0):settext("SCOREBOARD")
		end
	},

	-- Local / Online indicator
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(rightW - 10, offsetPlotHeight + 30):zoom(0.2):diffuse(dimText):halign(1)
			self:settext("Local Scores")
		end
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:xy(rightW / 2, SCREEN_HEIGHT - 40):zoom(0.22):diffuse(dimText)
		end,
		OnCommand = function(self) self:playcommand("UpdateText") end,
		UpdateScoreListMessageCommand = function(self) self:playcommand("UpdateText") end,
		UpdateTextCommand = function(self)
			if scoreList and #scoreList > 0 then
				self:settextf("Page %d/%d  |  %d scores", curPage, maxPages, #scoreList)
			else
				self:settext("No scores")
			end
		end
	},
}

-- ============================================================
-- SCORE ROWS (dynamic)
-- ============================================================
local scoreRowsFrame = Def.ActorFrame {
	Name = "ScoreRows",
	InitCommand = function(self) self:xy(rightX + 10, 10 + offsetPlotHeight + 45) end,
}

for i = 1, scoresPerPage do
	scoreRowsFrame[#scoreRowsFrame + 1] = Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self) self:y((i - 1) * 30) end,
		OnCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateScoreListMessageCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateRowCommand = function(self)
			local idx = (curPage - 1) * scoresPerPage + i
			if scoreList and scoreList[idx] then
				self:visible(true)
				self:RunCommandsOnChildren(function(child) child:playcommand("SetScore", {index = idx}) end)
			else
				self:visible(false)
			end
		end,

		-- Row BG
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(rightW - 20, 26):diffuse(color("0,0,0,0.3"))
			end,
			SetScoreCommand = function(self, params)
				if params.index == scoreIndex and isLocal then
					self:diffuse(accentColor):diffusealpha(0.08)
				else
					self:diffuse(color("0,0,0,0.3"))
				end
			end,
			MouseDownCommand = function(self)
				local idx = (curPage - 1) * scoresPerPage + i
				if scoreList and scoreList[idx] and scoreList[idx]:HasReplayData() then
					offsetScoreIndex = idx
					offsetisLocal = isLocal
					MESSAGEMAN:Broadcast("ShowScoreOffset")
				end
			end,
			WheelUpSlowMessageCommand = function(self)
				if self:IsOver() then movePage(-1) end
			end,
			WheelDownSlowMessageCommand = function(self)
				if self:IsOver() then movePage(1) end
			end
		},

		-- Clear type lamp
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(4, 26)
			end,
			SetScoreCommand = function(self, params)
				local ct = getClearType(pn, steps, scoreList[params.index])
				self:diffuse(getClearTypeColor(ct))
			end
		},

		-- Grade
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(18, 6):zoom(0.26):halign(0) end,
			SetScoreCommand = function(self, params)
				local grade = scoreList[params.index]:GetWifeGrade()
				self:settext(THEME:GetString("Grade", ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
			end
		},

		-- Score %
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(55, 6):zoom(0.26):halign(0):diffuse(mainText) end,
			SetScoreCommand = function(self, params)
				local ws = scoreList[params.index]:GetWifeScore()
				if ws >= 0.99 then
					self:settextf("%.4f%%", math.floor(ws * 1000000) / 10000)
				else
					self:settextf("%.2f%%", math.floor(ws * 10000) / 100)
				end
			end
		},

		-- Judgments summary
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(55, 18):zoom(0.2):halign(0):diffuse(dimText) end,
			SetScoreCommand = function(self, params)
				local s = scoreList[params.index]
				self:settextf("%d-%d-%d-%d-%d-%d",
					s:GetTapNoteScore("TapNoteScore_W1"), s:GetTapNoteScore("TapNoteScore_W2"),
					s:GetTapNoteScore("TapNoteScore_W3"), s:GetTapNoteScore("TapNoteScore_W4"),
					s:GetTapNoteScore("TapNoteScore_W5"), s:GetTapNoteScore("TapNoteScore_Miss"))
			end
		},

		-- Date
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(rightW - 25, 6):zoom(0.2):halign(1):diffuse(dimText) end,
			SetScoreCommand = function(self, params)
				self:settext(scoreList[params.index]:GetDate())
			end
		},

		-- SSR
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(rightW - 25, 18):zoom(0.2):halign(1) end,
			SetScoreCommand = function(self, params)
				local ssr = scoreList[params.index]:GetSkillsetSSR("Overall")
				self:settextf("%.2f", ssr)
				self:diffuse(HVColor.GetMSDRatingColor(ssr))
			end
		},

		-- Replay indicator
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(rightW - 25, 12):zoom(0.15):halign(1):diffuse(color("#7AFFAF"))
				self:settext("●"):visible(false)
			end,
			SetScoreCommand = function(self, params)
				self:visible(scoreList[params.index]:HasReplayData())
			end
		},
	}
end

t[#t + 1] = scoreRowsFrame

return t
