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
			local off = math.abs(o)
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
	return ra, la, ridicLA, marvRA
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
				if steps and ThemePrefs.Get("HV_ShowMSD") == "true" then
					local diff = ToEnumShortString(steps:GetDifficulty())
					local stype = ToEnumShortString(steps:GetStepsType()):gsub("_", " ")
					local meter = steps:GetMSD(getCurRateValue(), 1)
					meter = meter == 0 and steps:GetMeter() or meter
					self:settextf("%s %s %.1f", stype, diff, meter)
					self:diffuse(HVColor.GetDifficultyColor(diff))
				else
					self:settext("")
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
	-- GRADE + SCORE AREA (Including Graphs)
	-- ============================================================
	board[#board + 1] = Def.ActorFrame {
		Name = "GradeScore",
		InitCommand = function(self) self:xy(pad, pad + 65) end,
	}

	-- ============================================================
	-- GRAPHS AREA
	-- ============================================================
	board[#board + 1] = Def.ActorFrame {
		Name = "Graphs",
		InitCommand = function(self) self:xy(pad, pad + 120) end,

		-- Life Graph BG
		Def.GraphDisplay {
			InitCommand = function(self) self:Load("GraphDisplay") end,
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
			InitCommand = function(self) self:Load("ComboGraph" .. ToEnumShortString(pn)) end,
			BeginCommand = function(self)
				pcall(function()
					local ss = SCREENMAN:GetTopScreen():GetStageStats()
					self:Set(ss, pss)
				end)
			end
		},
	}

	-- ============================================================
	-- CLEAR TYPE
	-- ============================================================
	board[#board + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(pad, pad + 180) end,

		-- Divider
		Def.Quad {
			InitCommand = function(self) self:halign(0):valign(0):zoomto(frameW - pad*2, 1):diffuse(dividerColor) end
		},
		-- Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(0, 8):zoom(0.28)						:diffuse(subText)
						:settext(THEME:GetString("ScreenEvaluation", "CategoryClearType"))
				end,
		},
		-- Current clear type
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(0, 26):zoom(0.45) end,
			OnCommand = function(self)
				self:settext(getClearTypeText(clearType)):diffuse(getClearTypeColor(clearType))
			end
		},
		-- Record clear type
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):valign(0):xy(frameW - pad*2, 26):zoom(0.35):diffusealpha(0.4) end,
			OnCommand = function(self)
				if hsTable then
					local recCT = getHighestClearType(pn, steps, hsTable, scoreIndex)
					self:settext(getClearTypeText(recCT)):diffuse(getClearTypeColor(recCT)):diffusealpha(0.4)
				end
			end
		},
		-- Comparison arrow
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):valign(0):xy(frameW - pad*2 - 120, 26):zoom(0.35) end,
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
	local judgY = pad + 230
	board[#board + 1] = Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(pad, judgY):zoomto(frameW - pad*2, 1):diffuse(dividerColor)
		end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, judgY + 8):zoom(0.28)						:diffuse(subText)
						:settext(THEME:GetString("ScreenEvaluation", "CategoryJudgment"))
				end,
	}

	local itemSpacing = (frameW - pad*2) / 6
	for k, v in ipairs(judges) do
		local jx = pad + (k - 0.5) * itemSpacing
		-- Label
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(jx, judgY + 28):zoom(0.28):diffuse(judgmentColors[k])
				self:settext(getJudgeStrings(v))
			end
		}
		-- Count
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(jx, judgY + 48):zoom(0.45):diffuse(brightText) end,
			OnCommand = function(self) self:settext(pss:GetTapNoteScores(v)) end,
			SetJudgeCommand = function(self) self:settext(getRescoredJudge(dvt, judge, k)) end,
			ResetJudgeCommand = function(self) self:playcommand("On") end
		}
		-- Percentage
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(jx, judgY + 66):zoom(0.24):diffuse(dimText) end,
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
	local statsY = judgY + 90
	board[#board + 1] = Def.Quad {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, statsY):zoomto(frameW - pad*2, 1):diffuse(dividerColor) end
	}

	-- Hold OK / NG / Missed
	local holdLabels = {"Hold OK", "Hold NG", "Mines Hit"}
	local holdX = pad
	for i, label in ipairs(holdLabels) do
		local hx = holdX + (i - 1) * (frameW - pad*2) / 6
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(hx, statsY + 8):zoom(0.26):diffuse(subText):settext(label) end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(hx, statsY + 24):zoom(0.38):diffuse(mainText) end,
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
		local mx = holdX + (i - 1 + 3) * (frameW - pad*2) / 6
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(mx, statsY + 8):zoom(0.26):diffuse(subText):settext(label) end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(mx, statsY + 24):zoom(0.34):diffuse(mainText) end,
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
	local miscY = statsY + 55
	board[#board + 1] = Def.Quad {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, miscY):zoomto(frameW - pad*2, 1):diffuse(dividerColor) end
	}

	-- Max Combo
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, miscY + 8):zoom(0.26)						:diffuse(subText)
						:settext(THEME:GetString("ScreenEvaluation", "CategoryScore"))
					end,
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, miscY + 24):zoom(0.38):diffuse(mainText) end,
		OnCommand = function(self) self:settext(pss:MaxCombo()) end
	}

	-- Miss Count
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)/4, miscY + 8):zoom(0.26):diffuse(subText):settext("Miss Count") end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)/4, miscY + 24):zoom(0.38):diffuse(mainText) end,
		OnCommand = function(self) self:settext(getScoreComboBreaks(curScore)) end
	}

	-- CBs Left / Right
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)*2/4, miscY + 8):zoom(0.26):diffuse(subText):settext("CBs") end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)*2/4, miscY + 24):zoom(0.32):diffuse(mainText) end,
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
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)*3/4, miscY + 8):zoom(0.26):diffuse(subText):settext("vs Record") end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad + (frameW - pad*2)*3/4, miscY + 24):zoom(0.34) end,
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

	-- ============================================================
	-- RATIOS ROW: LA / RA / MA / PA (colored, left to right)
	-- ============================================================
	local ratioY = miscY + 40
	board[#board + 1] = Def.Quad {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, ratioY):zoomto(frameW - pad*2, 1):diffuse(dividerColor) end
	}

	local ratioLabels = {"LA", "RA", "MA", "PA"}
	local ratioColors = {color("#FF69B4"), color("#FFD700"), color("#FFFFFF"), color("#E0E0A0")}
	local ratioCount = #ratioLabels
	for ri, rlabel in ipairs(ratioLabels) do
		local rx = pad + (ri - 1) * (frameW - pad*2) / ratioCount
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(rx, ratioY + 5):zoom(0.22):diffuse(ratioColors[ri]):settext(rlabel)
			end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(rx, ratioY + 18):zoom(0.32):diffuse(mainText) end,
			OnCommand = function(self)
				if ri == 1 then
					-- LA (Ludicrous Attack)
					local ra, la, ridicLA, marvRA = calculateRatios(curScore)
					if la >= 0 then
						self:settextf("%.2f:1", la):rainbow()
					else
						self:settext("N/A"):diffuse(dimText)
					end
				elseif ri == 2 then
					-- RA (Ridiculous Attack)
					local ra, la, ridicLA, marvRA = calculateRatios(curScore)
					if ra >= 0 then
						self:settextf("%.2f:1", ra):diffuse(ratioColors[2])
					else
						self:settext("N/A"):diffuse(dimText)
					end
				elseif ri == 3 then
					-- MA (Marvelous Attack count)
					local ma = pss:GetTapNoteScores("TapNoteScore_W1")
					self:settext(ma):diffuse(ratioColors[3])
				elseif ri == 4 then
					-- PA (Perfect Attack count)
					local pa = pss:GetTapNoteScores("TapNoteScore_W2")
					self:settext(pa):diffuse(ratioColors[4])
				end
			end,
			SetJudgeCommand = function(self)
				if ri == 3 then
					self:settext(getRescoredJudge(dvt, judge, 1))
				elseif ri == 4 then
					self:settext(getRescoredJudge(dvt, judge, 2))
				end
			end,
			ResetJudgeCommand = function(self) self:playcommand("On") end
		}
	end

	-- ============================================================
	-- LARGEST OFFSET + NOTE TYPES
	-- ============================================================
	local extraY = ratioY + 40
	board[#board + 1] = Def.Quad {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, extraY):zoomto(frameW - pad*2, 1):diffuse(dividerColor) end
	}

	-- Largest Offset
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, extraY + 5):zoom(0.26):diffuse(subText):settext("Largest Offset") end
	}
	board[#board + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):xy(pad, extraY + 24):zoom(0.34):diffuse(mainText) end,
		OnCommand = function(self)
			local largest = 0
			if devianceTable and #devianceTable > 0 then
				for _, v in ipairs(devianceTable) do
					if math.abs(v) > largest then largest = math.abs(v) end
				end
			end
			self:settextf("%.2fms", largest)
		end
	}

	-- Note Types Hit/Count
	local noteTypeLabels = {"Taps", "Holds", "Rolls", "Lifts", "Mines"}
	local noteTypeRadars = {
		"RadarCategory_Notes", "RadarCategory_Holds", "RadarCategory_Rolls",
		"RadarCategory_Lifts", "RadarCategory_Mines"
	}
	local ntStartX = pad + (frameW - pad*2) / 4
	for ni, nlabel in ipairs(noteTypeLabels) do
		local nx = ntStartX + (ni - 1) * (frameW - pad*2 - ntStartX + pad) / #noteTypeLabels
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(nx, extraY + 5):zoom(0.26):diffuse(subText):settext(nlabel) end
		}
		board[#board + 1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0):xy(nx, extraY + 24):zoom(0.32):diffuse(mainText) end,
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
			self:xy(10, 40) -- Adjusted down slightly
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
	},

	-- Offset Plot Label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(20, 25):zoom(0.35):halign(0):diffuse(subText)
			self:settext(THEME:GetString("ScreenEvaluation", "CategoryOffset"))
		end,
	},
}

-- ============================================================
-- SCOREBOARD (loaded from external files)
-- ============================================================
local scoreboardFrame = Def.ActorFrame {
	Name = "ScoreboardContainer",
	InitCommand = function(self) self:xy(rightX + 10, offsetPlotHeight + 50) end,
}

if inMulti then
	scoreboardFrame[#scoreboardFrame + 1] = LoadActor("MPscoreboard")
else
	scoreboardFrame[#scoreboardFrame + 1] = LoadActor("online_leaderboard")
end

t[#t + 1] = scoreboardFrame
t[#t + 1] = LoadActor("manipfactor")

return t
