--- Etternity: Scores Tab
-- Shows local score history for the current chart

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.04,0.04,0.04,0.97")

local overlayW = 680
local overlayH = 400
local rowH = 34
local pageSize = 8
local currentPage = 1
local scoresActor = nil
local whee = nil

-- Sort modes
local SORT_SSR = 1
local SORT_WIFE = 2
local currentSort = SORT_SSR

-- Data
local localScores = {}
local displayedScores = {}
local filterCurrentRate = true
local displayAsJ4 = PREFSMAN:GetPreference("SortBySSRNormPercent")

-- ============================================================
-- DATA HELPERS
-- ============================================================

local function GetSSR(s)
	if not s then return 0 end
	if s.GetSkillsetSSR then return s:GetSkillsetSSR("Overall") end
	if s.GetSkillsetSum then return s:GetSkillsetSum() end
	if s.GetSkillSetSum then return s:GetSkillSetSum() end
	return 0
end

local function getRescoreElementsFromScore(score)
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

local function getJ4NormalizedPercentage(score)
	if not score then return 0 end
	if type(score.GetRescoredWifeScore) == "function" then
		return score:GetRescoredWifeScore(4) * 100
	end
	if score:HasReplayData() then
		local rst = getRescoreElementsFromScore(score)
		if rst and rst.dvt then
			return getRescoredWife3Judge(3, 4, rst)
		end
	end
	return score:GetWifeScore() * 100
end

local function SortScores(scoreTable)
	if not scoreTable or #scoreTable == 0 then return end
	table.sort(scoreTable, function(a, b)
		local sA = a.score or a
		local sB = b.score or b
		if currentSort == SORT_SSR then
			local ssrA = GetSSR(sA)
			local ssrB = GetSSR(sB)
			if math.abs(ssrA - ssrB) > 0.0001 then return ssrA > ssrB end
			return sA:GetWifeScore() > sB:GetWifeScore()
		else
			local wA = displayAsJ4 and getJ4NormalizedPercentage(sA) or sA:GetWifeScore() * 100
			local wB = displayAsJ4 and getJ4NormalizedPercentage(sB) or sB:GetWifeScore() * 100
			if math.abs(wA - wB) > 0.000001 then return wA > wB end
			return GetSSR(sA) > GetSSR(sB)
		end
	end)
end

-- ============================================================
-- DATA FETCHING
-- ============================================================

local function GetLocalScores()
	localScores = {}
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then return end
	local ck = steps:GetChartKey()
	if not ck then return end
	local sl = SCOREMAN:GetScoresByKey(ck)
	if not sl then return end

	local currentRate = getCurRateValue()

	for rateName, scoreList in pairs(sl) do
		local rNum = tonumber((rateName:gsub("x", ""))) or 0
		if not filterCurrentRate or math.abs(rNum - currentRate) < 0.001 then
			local scores = scoreList:GetScores()
			if scores then
				for _, s in ipairs(scores) do
					localScores[#localScores + 1] = {score = s, rate = rateName}
				end
			end
		end
	end

	SortScores(localScores)
end

local function ViewScore(score)
	if not score then return end
	local ss = score.score or score
	local screen = SCREENMAN:GetTopScreen()
	if screen and screen.ShowEvalScreenForScore then
		screen:ShowEvalScreenForScore(ss)
	else
		if STATSMAN:GetCurStageStats() then
			STATSMAN:GetCurStageStats():GetPlayerStageStats():SetHighScore(ss)
			SCREENMAN:SetNewScreen("ScreenEvaluation")
		end
	end
end

-- ============================================================
-- UI
-- ============================================================

local t = Def.ActorFrame {
	Name = "ScoresOverlay",
	InitCommand = function(self)
		scoresActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false):diffusealpha(0)
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.GetMusicWheel then whee = screen:GetMusicWheel() end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "SCORES" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				self:stoptweening():diffusealpha(0):linear(0.2):diffusealpha(1)
				HV.ActiveTab = "SCORES"
				currentPage = 1
				GetLocalScores()
				self:playcommand("RefreshScores")
			else
				HV.ActiveTab = ""
			end
		else
			self:visible(false)
			if HV.ActiveTab == "SCORES" then HV.ActiveTab = "" end
		end
	end,
	TabNavigationMessageCommand = function(self, params)
		if self:GetVisible() and params and params.dir then
			local totalPages = math.max(1, math.ceil(#displayedScores / pageSize))
			currentPage = math.max(1, math.min(totalPages, currentPage + params.dir))
			self:playcommand("RefreshScores")
		end
	end,
	CurrentStepsChangedMessageCommand = function(self)
		if self:GetVisible() then
			currentPage = 1
			GetLocalScores()
			self:playcommand("RefreshScores")
		end
	end,

	-- Background
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard) end },
	Def.Quad { InitCommand = function(self) self:valign(0):y(-overlayH/2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7) end },

	-- Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 25, -overlayH/2 + 15):zoom(0.5):diffuse(accentColor)
		end,
		RefreshScoresCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			local steps = GAMESTATE:GetCurrentSteps()
			local viewLabel = THEME:GetString("Scores", "Local")
			if song and steps then
				local diff = ToEnumShortString(steps:GetDifficulty())
				self:settextf(THEME:GetString("Scores", "TitleGeneric"), viewLabel, song:GetDisplayMainTitle(), diff)
			else
				self:settextf(THEME:GetString("Scores", "TitleGenericNoChart"), viewLabel)
			end
		end
	},

	-- Rate filter toggle button
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 55, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "RateBtnBg",
			InitCommand = function(self) self:zoomto(65, 18):diffuse(accentColor):diffusealpha(0.15) end,
			RefreshScoresCommand = function(self)
				self:diffusealpha(filterCurrentRate and 0.5 or 0.15)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				self:settext(filterCurrentRate and THEME:GetString("Scores", "FilterCurrRate") or THEME:GetString("Scores", "FilterAllRates"))
				self:diffusealpha(filterCurrentRate and 1 or 0.5)
			end,
		},
	},

	-- Sort toggle button
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 125, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "SortBtnBg",
			InitCommand = function(self) self:zoomto(65, 18):diffuse(accentColor):diffusealpha(0.15) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				self:settext(currentSort == SORT_SSR and THEME:GetString("Scores", "SortSSR") or THEME:GetString("Scores", "SortWife"))
				local bg = self:GetParent():GetChild("SortBtnBg")
				if bg then bg:diffusealpha(0.5) end
			end,
		},
	},

	-- J4 Display Toggle Button
	Def.ActorFrame {
		Name = "J4ToggleFrame",
		InitCommand = function(self) self:xy(overlayW/2 - 195, -overlayH/2 + 18) end,
		RefreshScoresCommand = function(self)
			local normPref = PREFSMAN:GetPreference("SortBySSRNormPercent")
			self:visible(not normPref)
		end,
		Def.Quad {
			Name = "J4BtnBg",
			InitCommand = function(self) self:zoomto(65, 18):diffuse(accentColor):diffusealpha(0.15) end,
			RefreshScoresCommand = function(self)
				self:diffusealpha(displayAsJ4 and 0.5 or 0.15)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				self:settext(displayAsJ4 and "Display: J4" or "Display: Raw")
				self:diffusealpha(displayAsJ4 and 1 or 0.5)
			end,
		},
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:halign(1):valign(0):xy(overlayW/2 - 16, -overlayH/2 + 30):zoom(0.24):diffuse(dimText)
		end,
	},

	-- Column headers
	-- NOTE: :visible() is called on a separate line to avoid chaining after :settext(),
	-- which returns nil in some Etternity builds and causes a "bad self" crash.
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-overlayW/2 + 25, -overlayH/2 + 65) end,
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):zoom(0.32):diffuse(dimText):settext("#") end },
		LoadFont("Common Normal") .. { Name = "HdrName", InitCommand = function(self) self:halign(0):x(30):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "PlayerColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(190):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "WifeColumn")) end },
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):x(280):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "SSRColumn"))
				self:visible(HV.ShowMSD())
			end
		},
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(345):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "GradeColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(415):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "RateColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(485):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "ClearColumn")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(1):x(overlayW - 50):zoom(0.32):diffuse(dimText):settext(THEME:GetString("Scores", "DateColumn")) end },
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 12, -overlayH/2 + 82)
				:zoomto(overlayW - 24, 1):diffuse(color("0.12,0.12,0.12,1"))
		end,
	},

	-- Hint
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(1):xy(0, overlayH/2 - 8):zoom(0.20):diffuse(dimText)
				:settext(THEME:GetString("Scores", "ScoreHint"))
		end,
	},
}

-- Score rows
local rowsStartY = -overlayH/2 + 82
for i = 1, pageSize do
	t[#t + 1] = Def.ActorFrame {
		Name = "ScoreRow_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW/2 + 25, rowsStartY + (i-1) * rowH):diffusealpha(0)
		end,

		Def.Quad { Name = "Bg", InitCommand = function(self) self:halign(0):valign(0):zoomto(overlayW - 50, rowH - 4):diffuse(color("0,0,0,0.2")) end },
		LoadFont("Common Normal") .. { Name = "Rank",       InitCommand = function(self) self:halign(0):valign(0.5):y(rowH/2):zoom(0.35):diffuse(dimText) end },
		LoadFont("Common Normal") .. { Name = "Player",     InitCommand = function(self) self:halign(0):valign(0.5):x(30):y(rowH/2):zoom(0.42):diffuse(mainText):maxwidth(150 / 0.42) end },
		LoadFont("Common Normal") .. { Name = "Wife",       InitCommand = function(self) self:halign(0):valign(0.5):x(190):y(rowH/2 - 5):zoom(0.40):diffuse(brightText) end },
		LoadFont("Common Normal") .. { Name = "Judge",      InitCommand = function(self) self:halign(1):valign(0.5):x(185):y(rowH/2 - 5):zoom(0.30):diffuse(subText) end },
		LoadFont("Common Normal") .. { Name = "Judgments",  InitCommand = function(self) self:halign(0):valign(0.5):x(190):y(rowH/2 + 8):zoom(0.22):diffuse(subText) end },
		LoadFont("Common Normal") .. {
			Name = "SSR",
			InitCommand = function(self)
				self:halign(0):valign(0.5):x(280):y(rowH/2):zoom(0.40):diffuse(brightText)
				self:visible(HV.ShowMSD())
			end
		},
		LoadFont("Common Normal") .. { Name = "Grade",      InitCommand = function(self) self:halign(0):valign(0.5):x(345):y(rowH/2):zoom(0.38) end },
		LoadFont("Common Normal") .. { Name = "Rate",       InitCommand = function(self) self:halign(0):valign(0.5):x(415):y(rowH/2):zoom(0.38):diffuse(mainText) end },
		LoadFont("Common Normal") .. { Name = "Clear",      InitCommand = function(self) self:halign(0):valign(0.5):x(485):y(rowH/2):zoom(0.35) end },
		LoadFont("Common Normal") .. { Name = "Date",       InitCommand = function(self) self:halign(1):valign(0.5):x(overlayW - 90):y(rowH/2):zoom(0.32):diffuse(subText) end },
		LoadFont("Common Normal") .. { Name = "CC",         InitCommand = function(self) self:halign(0):valign(0.5):x(30):y(rowH/2 + 8):zoom(0.28):diffuse(color("#FF0000")):settext("Chord Cohesion ON") end },
		
		-- Replay Button
		Def.ActorFrame {
			Name = "ReplayButton",
			InitCommand = function(self) self:xy(overlayW - 60, rowH / 2):zoom(0.32) end,
			RefreshScoresCommand = function(self)
				local idx = (currentPage - 1) * pageSize + i
				local s = displayedScores[idx]
				if s then
					local ss = s.score or s
					self:visible(ss:HasReplayData())
				else
					self:visible(false)
				end
			end,
			Def.Quad { Name = "Hit", InitCommand = function(self) self:zoomto(60, 60):diffusealpha(0) end },
			LoadActor(THEME:GetPathG("", "mp_play")) .. {
				InitCommand = function(self) self:diffuse(accentColor) end,
			},
		},

		RefreshScoresCommand = function(self)
			local idx = (currentPage - 1) * pageSize + i
			local scores = displayedScores

			if idx <= #scores then
				self:visible(true)
				self:stoptweening():diffusealpha(0):sleep(i * 0.04):linear(0.15):diffusealpha(1)
				self:GetChild("Rank"):settext(tostring(idx))

				local entry = scores[idx]
				local s = entry.score
				self:GetChild("Player"):settext(THEME:GetString("Common", "You"))
				
				-- Judgments
				local w1 = s:GetTapNoteScore("TapNoteScore_W1")
				local w2 = s:GetTapNoteScore("TapNoteScore_W2")
				local w3 = s:GetTapNoteScore("TapNoteScore_W3")
				local w4 = s:GetTapNoteScore("TapNoteScore_W4")
				local w5 = s:GetTapNoteScore("TapNoteScore_W5")
				local miss = s:GetTapNoteScore("TapNoteScore_Miss")
				self:GetChild("Judgments"):settextf("%d | %d | %d | %d | %d | %d", w1, w2, w3, w4, w5, miss)

				-- Wife% display
				local wife = s:GetWifeScore() * 100
				if displayAsJ4 then
					wife = getJ4NormalizedPercentage(s)
				end
				
				if wife >= 99.7 then
					self:GetChild("Wife"):settextf("%.4f%%", wife)
				else
					self:GetChild("Wife"):settextf("%.2f%%", wife)
				end
				
				local norm = PREFSMAN:GetPreference("SortBySSRNormPercent")
				local judgeIndex = ""
				if displayAsJ4 then
					judgeIndex = "J4"
				elseif not norm and type(s.GetJudgeScale) == "function" then
					local scale = s:GetJudgeScale()
					if scale then
						scale = math.floor(scale * 100 + 0.5) / 100
						local j = 4
						for k, v in pairs(ms.JudgeScalers) do
							if math.floor(v * 100 + 0.5) / 100 == scale then
								j = k
								if j >= 4 then break end
							end
						end
						j = math.max(4, math.min(9, j))
						judgeIndex = "J" .. j
					end
				end
				self:GetChild("Judge"):settext(judgeIndex)
				if displayAsJ4 then
					self:GetChild("Judge"):diffuse(accentColor)
				else
					self:GetChild("Judge"):diffuse(subText)
				end

				local ssr = 0
				if s.GetSkillsetSSR then ssr = s:GetSkillsetSSR("Overall")
				elseif s.GetSkillsetSum then ssr = s:GetSkillsetSum()
				elseif s.GetSkillSetSum then ssr = s:GetSkillSetSum() end
				
				self:GetChild("SSR"):settextf("%.2f", ssr)
				self:GetChild("SSR"):diffuse(HVColor.GetMSDRatingColor(ssr))
				self:GetChild("SSR"):visible(HV.ShowMSD())

				local gradeStr = ToEnumShortString(s:GetWifeGrade())
				self:GetChild("Grade"):settext(HV.GetGradeName(gradeStr)):diffuse(HVColor.GetGradeColor(gradeStr))
				self:GetChild("Rate"):settextf("%.2fx", s:GetMusicRate())

				local ct = getDetailedClearType(s)
				self:GetChild("Clear"):settext(ct):diffuse(HVColor.GetClearTypeColor(ct))
				self:GetChild("Date"):settext(s:GetDate())

				local cc = self:GetChild("CC")
				if cc then
					cc:visible(s:GetChordCohesion())
				end
			else
				self:visible(false)
			end
		end,
	}
end

local function UpdateDisplayedScores()
	displayedScores = localScores
	SortScores(displayedScores)
end

-- RefreshScores on main frame
t.RefreshScoresCommand = function(self)
	UpdateDisplayedScores()
	
	local scores = displayedScores
	local totalPages = math.max(1, math.ceil(#scores / pageSize))
	currentPage = math.min(currentPage, totalPages)

	local pageInfo = self:GetChild("PageInfo")
	if pageInfo then
		pageInfo:settextf(THEME:GetString("Common", "PageInfoDetailed"), currentPage, totalPages, #scores)
	end

	for ri = 1, pageSize do
		local row = self:GetChild("ScoreRow_" .. ri)
		if row then row:playcommand("RefreshScores") end
	end
end

-- Input handler
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if not scoresActor or not scoresActor:GetVisible() then return false end
			if not event or not event.DeviceInput then return false end
			
			local btn = event.DeviceInput.button
			local isPress = event.type == "InputEventType_FirstPress"

			if isPress and btn == "DeviceButton_left mouse button" then
				-- Close on outside click
				if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- Close button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 16, SCREEN_CENTER_Y - overlayH/2 + 16, 24, 24) then
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- Rate button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 55, SCREEN_CENTER_Y - overlayH/2 + 18, 65, 18) then
					filterCurrentRate = not filterCurrentRate
					currentPage = 1
					GetLocalScores()
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- Sort button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 125, SCREEN_CENTER_Y - overlayH/2 + 18, 65, 18) then
					currentSort = (currentSort == SORT_SSR) and SORT_WIFE or SORT_SSR
					currentPage = 1
					SortScores(localScores)
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- J4 Display button
				local normPref = PREFSMAN:GetPreference("SortBySSRNormPercent")
				if not normPref and IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 195, SCREEN_CENTER_Y - overlayH/2 + 18, 65, 18) then
					displayAsJ4 = not displayAsJ4
					currentPage = 1
					SortScores(localScores)
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- Row interaction
				local replayX = SCREEN_CENTER_X + 305
				for ri = 1, pageSize do
					local ry = SCREEN_CENTER_Y + rowsStartY + (ri - 1) * rowH + rowH / 2
					
					-- 1. Check Replay Button first (higher priority)
					if IsMouseOverCentered(replayX, ry, 35, 30) then
						local idx = (currentPage - 1) * pageSize + ri
						local s = displayedScores[idx]
						if s then
							local ss = s.score or s
							if ss:HasReplayData() then
								SCREENMAN:GetTopScreen():PlayReplay(ss)
							end
						end
						return true
					end

					-- 2. Check Row Click (View Score)
					if IsMouseOverCentered(SCREEN_CENTER_X, ry, overlayW - 50, rowH) then
						local idx = (currentPage - 1) * pageSize + ri
						local s = displayedScores[idx]
						if s then
							ViewScore(s)
						end
						return true
					end
				end
			end

			-- Paging
			if isPress then
				if btn == "MenuLeft" or event.button == "Left" or event.DeviceInput.button == "DeviceButton_left" then
					MESSAGEMAN:Broadcast("TabNavigation", {dir = -1})
					return true
				elseif btn == "MenuRight" or event.button == "Right" or event.DeviceInput.button == "DeviceButton_right" then
					MESSAGEMAN:Broadcast("TabNavigation", {dir = 1})
					return true
				end
			end

			if event.button == "Back" or event.DeviceInput.button == "DeviceButton_escape" then
				MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
				return true
			end

			return true
		end)
	end,
}

return t