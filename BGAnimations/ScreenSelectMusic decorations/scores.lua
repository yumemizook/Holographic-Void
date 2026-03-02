--- Holographic Void: Scores Tab
-- Shows local score history and online leaderboard for the current chart
-- Online: DLMAN:GetChartLeaderBoard(ck) / RequestChartLeaderBoardFromOnline(ck, cb)

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

-- View modes
local VIEW_LOCAL = 1
local VIEW_ONLINE = 2
local currentView = VIEW_LOCAL

-- Sort modes
local SORT_SSR = 1
local SORT_WIFE = 2
local currentSort = SORT_SSR

-- Data
local localScores = {}
local onlineScores = {}
local displayedScores = {}
local onlineLoading = false
local filterCurrentRate = true

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

local function SortScores(scoreTable)
	if not scoreTable or #scoreTable == 0 then return end
	
	table.sort(scoreTable, function(a, b)
		-- Handle different score structures (local vs online)
		local sA = a.score or a
		local sB = b.score or b
		
		if currentSort == SORT_SSR then
			local ssrA = GetSSR(sA)
			local ssrB = GetSSR(sB)
			if math.abs(ssrA - ssrB) > 0.0001 then return ssrA > ssrB end
			return sA:GetWifeScore() > sB:GetWifeScore()
		else
			-- Wife% sort
			local wA = sA:GetWifeScore()
			local wB = sB:GetWifeScore()
			if math.abs(wA - wB) > 0.000001 then return wA > wB end
			-- Fallback to SSR
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
		-- Apply rate filter if enabled (tolerate small floating point differences)
		if not filterCurrentRate or math.abs(rNum - currentRate) < 0.001 then
			local scores = scoreList:GetScores()
			if scores then
				for _, s in ipairs(scores) do
					localScores[#localScores + 1] = {score = s, rate = rateName}
				end
			end
		end
	end

	-- Sort using helper
	SortScores(localScores)
end

local function FetchOnlineScores()
	onlineScores = {}
	onlineLoading = true

	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then
		onlineLoading = false
		return
	end

	local ck = steps:GetChartKey()
	if not ck then
		onlineLoading = false
		return
	end

	if not DLMAN:IsLoggedIn() then
		onlineLoading = false
		return
	end

	-- Try cached first
	local cached = DLMAN:GetChartLeaderBoard(ck)
	if cached and #cached > 0 then
		onlineScores = cached
		onlineLoading = false
		if scoresActor then scoresActor:playcommand("RefreshScores") end
		return
	end

	-- Request from server
	DLMAN:RequestChartLeaderBoardFromOnline(
		ck,
		function(leaderboard)
			if leaderboard then
				onlineScores = leaderboard
				-- Sort using helper
				SortScores(onlineScores)
			else
				onlineScores = {}
			end
			onlineLoading = false
			if scoresActor then scoresActor:queuecommand("RefreshScores") end
		end
	)
end

-- ============================================================
-- UI
-- ============================================================

local t = Def.ActorFrame {
	Name = "ScoresOverlay",
	InitCommand = function(self)
		scoresActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.GetMusicWheel then whee = screen:GetMusicWheel() end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "SCORES" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				HV.ActiveTab = "SCORES"
				currentPage = 1
				currentView = VIEW_LOCAL
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
			if currentView == VIEW_LOCAL then
				GetLocalScores()
			else
				FetchOnlineScores()
			end
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
			local viewLabel = currentView == VIEW_LOCAL and "LOCAL" or "ONLINE"
			if song and steps then
				local diff = ToEnumShortString(steps:GetDifficulty())
				self:settextf("SCORES [%s]: %s [%s]", viewLabel, song:GetDisplayMainTitle(), diff)
			else
				self:settextf("SCORES [%s]", viewLabel)
			end
		end
	},

	-- View toggle button (Merged LOCAL/ONLINE)
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 55, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "ToggleViewBg",
			InitCommand = function(self) self:zoomto(100, 18):diffuse(accentColor):diffusealpha(0.4) end,
			RefreshScoresCommand = function(self)
				if not DLMAN:IsLoggedIn() and currentView == VIEW_LOCAL then
					self:diffuse(color("#444444"))
				else
					self:diffuse(accentColor)
				end
			end,
		},
		LoadFont("Common Normal") .. {
			Name = "ToggleViewText",
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				local viewName = currentView == VIEW_LOCAL and "LOCAL" or "ONLINE"
				self:settext("VIEW: " .. viewName)
				if currentView == VIEW_ONLINE and not DLMAN:IsLoggedIn() then
					self:diffuse(dimText)
				else
					self:diffuse(brightText)
				end
			end,
		},
	},

	-- Rate filter toggle button
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 145, -overlayH/2 + 18) end,
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
				self:settext(filterCurrentRate and "CUR. RATE" or "ALL RATES")
				self:diffusealpha(filterCurrentRate and 1 or 0.5)
			end,
		},
	},

	-- Sort toggle button
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 215, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "SortBtnBg",
			InitCommand = function(self) self:zoomto(65, 18):diffuse(accentColor):diffusealpha(0.15) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText) end,
			RefreshScoresCommand = function(self)
				self:settext(currentSort == SORT_SSR and "SORT: SSR" or "SORT: WIFE%")
				local bg = self:GetParent():GetChild("SortBtnBg")
				if bg then bg:diffusealpha(0.5) end
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
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-overlayW/2 + 25, -overlayH/2 + 65) end,
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):zoom(0.32):diffuse(dimText):settext("#") end },
		LoadFont("Common Normal") .. { Name = "HdrName", InitCommand = function(self) self:halign(0):x(30):zoom(0.32):diffuse(dimText):settext("PLAYER") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(190):zoom(0.32):diffuse(dimText):settext("WIFE%") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(280):zoom(0.32):diffuse(dimText):settext("SSR") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(345):zoom(0.32):diffuse(dimText):settext("GRADE") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(415):zoom(0.32):diffuse(dimText):settext("RATE") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(485):zoom(0.32):diffuse(dimText):settext("CLEAR") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(1):x(overlayW - 50):zoom(0.32):diffuse(dimText):settext("DATE") end },
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 12, -overlayH/2 + 82)
				:zoomto(overlayW - 24, 1):diffuse(color("0.12,0.12,0.12,1"))
		end,
	},

	-- Loading indicator
	LoadFont("Common Normal") .. {
		Name = "LoadingText",
		InitCommand = function(self)
			self:xy(0, 0):zoom(0.35):diffuse(accentColor):settext("Loading..."):visible(false)
		end,
		RefreshScoresCommand = function(self)
			self:visible(onlineLoading and currentView == VIEW_ONLINE)
		end,
	},

	-- Hint
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(1):xy(0, overlayH/2 - 8):zoom(0.20):diffuse(dimText)
				:settext("SCROLL to page · CLICK LOCAL/ONLINE to toggle · CLICK outside to close")
		end,
	},
}

-- Score rows
local rowsStartY = -overlayH/2 + 82
for i = 1, pageSize do
	t[#t + 1] = Def.ActorFrame {
		Name = "ScoreRow_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW/2 + 25, rowsStartY + (i-1) * rowH)
		end,

		Def.Quad { Name = "Bg", InitCommand = function(self) self:halign(0):valign(0):zoomto(overlayW - 50, rowH - 4):diffuse(color("0,0,0,0.2")) end },
		LoadFont("Common Normal") .. { Name = "Rank", InitCommand = function(self) self:halign(0):valign(0.5):y(rowH/2):zoom(0.35):diffuse(dimText) end },
		LoadFont("Common Normal") .. { Name = "Player", InitCommand = function(self) self:halign(0):valign(0.5):x(30):y(rowH/2):zoom(0.42):diffuse(mainText):maxwidth(150 / 0.42) end },
		LoadFont("Common Normal") .. { Name = "Wife", InitCommand = function(self) self:halign(0):valign(0.5):x(190):y(rowH/2 - 5):zoom(0.40):diffuse(brightText) end },
		LoadFont("Common Normal") .. { Name = "Judgments", InitCommand = function(self) self:halign(0):valign(0.5):x(190):y(rowH/2 + 8):zoom(0.22):diffuse(subText) end },
		LoadFont("Common Normal") .. { Name = "SSR", InitCommand = function(self) self:halign(0):valign(0.5):x(280):y(rowH/2):zoom(0.40):diffuse(brightText) end },
		LoadFont("Common Normal") .. { Name = "Grade", InitCommand = function(self) self:halign(0):valign(0.5):x(345):y(rowH/2):zoom(0.38) end },
		LoadFont("Common Normal") .. { Name = "Rate", InitCommand = function(self) self:halign(0):valign(0.5):x(415):y(rowH/2):zoom(0.38):diffuse(mainText) end },
		LoadFont("Common Normal") .. { Name = "Clear", InitCommand = function(self) self:halign(0):valign(0.5):x(485):y(rowH/2):zoom(0.35) end },
		LoadFont("Common Normal") .. { Name = "Date", InitCommand = function(self) self:halign(1):valign(0.5):x(overlayW - 50):y(rowH/2):zoom(0.32):diffuse(subText) end },

		RefreshScoresCommand = function(self)
			local idx = (currentPage - 1) * pageSize + i
			local scores = displayedScores

			if idx <= #scores then
				self:visible(true)
				self:GetChild("Rank"):settext(tostring(idx))

				if currentView == VIEW_LOCAL then
					local entry = scores[idx]
					local s = entry.score

					self:GetChild("Player"):settext("You")
					
					-- Judgments
					local w1 = s:GetTapNoteScore("TapNoteScore_W1")
					local w2 = s:GetTapNoteScore("TapNoteScore_W2")
					local w3 = s:GetTapNoteScore("TapNoteScore_W3")
					local w4 = s:GetTapNoteScore("TapNoteScore_W4")
					local w5 = s:GetTapNoteScore("TapNoteScore_W5")
					local miss = s:GetTapNoteScore("TapNoteScore_Miss")
					self:GetChild("Judgments"):settextf("%d | %d | %d | %d | %d | %d", w1, w2, w3, w4, w5, miss)

					local wife = s:GetWifeScore() * 100
					if wife >= 99.7 then
						self:GetChild("Wife"):settextf("%.4f%%", wife)
					else
						self:GetChild("Wife"):settextf("%.2f%%", wife)
					end

					local ssr = 0
					if s.GetSkillsetSSR then ssr = s:GetSkillsetSSR("Overall")
					elseif s.GetSkillsetSum then ssr = s:GetSkillsetSum()
					elseif s.GetSkillSetSum then ssr = s:GetSkillSetSum() end
					
					self:GetChild("SSR"):settextf("%.2f", ssr):diffuse(HVColor.GetMSDRatingColor(ssr))

					local gradeStr = ToEnumShortString(s:GetWifeGrade())
					self:GetChild("Grade"):settext(HV.GetGradeName(gradeStr)):diffuse(HVColor.GetGradeColor(gradeStr))
					self:GetChild("Rate"):settextf("%.2fx", s:GetMusicRate())

					local ct = getDetailedClearType(s)
					self:GetChild("Clear"):settext(ct):diffuse(HVColor.GetClearTypeColor(ct))
					self:GetChild("Date"):settext(s:GetDate())
				else
					-- Online leaderboard score
					local s = scores[idx]
					pcall(function()
						local username = s:GetDisplayName() or s:GetName() or "???"
						self:GetChild("Player"):settext(username)

						-- Online judgments if available
						local w1 = s:GetTapNoteScore("TapNoteScore_W1") or 0
						local w2 = s:GetTapNoteScore("TapNoteScore_W2") or 0
						local w3 = s:GetTapNoteScore("TapNoteScore_W3") or 0
						local w4 = s:GetTapNoteScore("TapNoteScore_W4") or 0
						local w5 = s:GetTapNoteScore("TapNoteScore_W5") or 0
						local miss = s:GetTapNoteScore("TapNoteScore_Miss") or 0
						self:GetChild("Judgments"):settextf("%d | %d | %d | %d | %d | %d", w1, w2, w3, w4, w5, miss)

						local wife = s:GetWifeScore() * 100
						if wife >= 99.7 then
							self:GetChild("Wife"):settextf("%.4f%%", wife)
						else
							self:GetChild("Wife"):settextf("%.2f%%", wife)
						end

						local ssr = 0
						if s.GetSkillsetSSR then ssr = s:GetSkillsetSSR("Overall")
						elseif s.GetSkillsetSum then ssr = s:GetSkillsetSum()
						elseif s.GetSkillSetSum then ssr = s:GetSkillSetSum() end
						
						self:GetChild("SSR"):settextf("%.2f", ssr):diffuse(HVColor.GetMSDRatingColor(ssr))

						local gradeStr = ToEnumShortString(s:GetWifeGrade())
						self:GetChild("Grade"):settext(HV.GetGradeName(gradeStr)):diffuse(HVColor.GetGradeColor(gradeStr))
						self:GetChild("Rate"):settextf("%.2fx", s:GetMusicRate())

						local ct = getDetailedClearType(s)
						self:GetChild("Clear"):settext(ct):diffuse(HVColor.GetClearTypeColor(ct))
						self:GetChild("Date"):settext(s:GetDate())
					end)
				end
			else
				self:visible(false)
			end
		end,
	}
end

local function UpdateDisplayedScores()
	displayedScores = {}
	local source = currentView == VIEW_LOCAL and localScores or onlineScores
	
	if currentView == VIEW_LOCAL then
		displayedScores = source -- localScores is already filtered in GetLocalScores
	else
		-- Online scores need manual filtering if CUR. RATE is active
		local currentRate = getCurRateValue()
		for _, s in ipairs(source) do
			local rNum = s:GetMusicRate()
			if not filterCurrentRate or math.abs(rNum - currentRate) < 0.001 then
				displayedScores[#displayedScores + 1] = s
			end
		end
	end

	-- Always sort the final displayed list if we just switched sort mode
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
		pageInfo:settextf("Page %d / %d (%d scores)", currentPage, totalPages, #scores)
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
			local isPress = event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat"

			if event.type ~= "InputEventType_FirstPress" then 
				if btn == "DeviceButton_left mouse button" or btn == "Back" or btn == "DeviceButton_escape" then
					return true
				end
				return false 
			end

			-- Click handling
			if btn == "DeviceButton_left mouse button" then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

				-- Close on outside click
				if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- Toggle View button (Local/Online)
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 55, SCREEN_CENTER_Y - overlayH/2 + 18, 100, 18) then
					if currentView == VIEW_LOCAL then
						currentView = VIEW_ONLINE
						FetchOnlineScores()
					else
						currentView = VIEW_LOCAL
						GetLocalScores()
					end
					currentPage = 1
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- Rate button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 145, SCREEN_CENTER_Y - overlayH/2 + 18, 65, 18) then
					filterCurrentRate = not filterCurrentRate
					currentPage = 1
					if currentView == VIEW_LOCAL then
						GetLocalScores()
					end
					-- No need to re-fetch online, UpdateDisplayedScores will filter cached onlineScores
					scoresActor:playcommand("RefreshScores")
					return true
				end

				-- Sort button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 215, SCREEN_CENTER_Y - overlayH/2 + 18, 65, 18) then
					currentSort = (currentSort == SORT_SSR) and SORT_WIFE or SORT_SSR
					currentPage = 1
					-- Re-sort the source tables to be safe
					SortScores(localScores)
					SortScores(onlineScores)
					-- UpdateDisplayedScores will handle the final subset and re-sort displayedScores
					scoresActor:playcommand("RefreshScores")
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
