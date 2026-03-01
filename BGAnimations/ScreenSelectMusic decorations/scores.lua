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

-- Data
local localScores = {}
local onlineScores = {}
local onlineLoading = false

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

	for rateName, scoreList in pairs(sl) do
		local scores = scoreList:GetScores()
		if scores then
			for _, s in ipairs(scores) do
				localScores[#localScores + 1] = {score = s, rate = rateName}
			end
		end
	end

	table.sort(localScores, function(a, b)
		return a.score:GetWifeScore() > b.score:GetWifeScore()
	end)
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

	-- View toggle buttons
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 90, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "LocalBtnBg",
			InitCommand = function(self) self:zoomto(60, 18):diffuse(accentColor):diffusealpha(0.4) end,
			RefreshScoresCommand = function(self)
				self:diffusealpha(currentView == VIEW_LOCAL and 0.5 or 0.15)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText):settext("LOCAL") end,
			RefreshScoresCommand = function(self)
				self:diffusealpha(currentView == VIEW_LOCAL and 1 or 0.5)
			end,
		},
	},
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 25, -overlayH/2 + 18) end,
		Def.Quad {
			Name = "OnlineBtnBg",
			InitCommand = function(self) self:zoomto(60, 18):diffuse(accentColor):diffusealpha(0.15) end,
			RefreshScoresCommand = function(self)
				self:diffusealpha(currentView == VIEW_ONLINE and 0.5 or 0.15)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText):settext("ONLINE") end,
			RefreshScoresCommand = function(self)
				self:diffusealpha(currentView == VIEW_ONLINE and 1 or 0.5)
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
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(300):zoom(0.32):diffuse(dimText):settext("GRADE") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(380):zoom(0.32):diffuse(dimText):settext("RATE") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):x(450):zoom(0.32):diffuse(dimText):settext("CLEAR") end },
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
		LoadFont("Common Normal") .. { Name = "Wife", InitCommand = function(self) self:halign(0):valign(0.5):x(190):y(rowH/2):zoom(0.45):diffuse(brightText) end },
		LoadFont("Common Normal") .. { Name = "Grade", InitCommand = function(self) self:halign(0):valign(0.5):x(300):y(rowH/2):zoom(0.38) end },
		LoadFont("Common Normal") .. { Name = "Rate", InitCommand = function(self) self:halign(0):valign(0.5):x(380):y(rowH/2):zoom(0.38):diffuse(mainText) end },
		LoadFont("Common Normal") .. { Name = "Clear", InitCommand = function(self) self:halign(0):valign(0.5):x(450):y(rowH/2):zoom(0.35) end },
		LoadFont("Common Normal") .. { Name = "Date", InitCommand = function(self) self:halign(1):valign(0.5):x(overlayW - 50):y(rowH/2):zoom(0.32):diffuse(subText) end },

		RefreshScoresCommand = function(self)
			local idx = (currentPage - 1) * pageSize + i
			local scores = currentView == VIEW_LOCAL and localScores or onlineScores

			if idx <= #scores then
				self:visible(true)
				self:GetChild("Rank"):settext(tostring(idx))

				if currentView == VIEW_LOCAL then
					local entry = scores[idx]
					local s = entry.score

					self:GetChild("Player"):settext("You")

					local wife = s:GetWifeScore() * 100
					if wife >= 99 then
						self:GetChild("Wife"):settextf("%.4f%%", wife)
					else
						self:GetChild("Wife"):settextf("%.2f%%", wife)
					end

					local gradeStr = ToEnumShortString(s:GetWifeGrade())
					self:GetChild("Grade"):settext(THEME:GetString("Grade", gradeStr)):diffuse(HVColor.GetGradeColor(gradeStr))
					self:GetChild("Rate"):settextf("%.2fx", s:GetMusicRate())

					local ct = getDetailedClearType(s)
					self:GetChild("Clear"):settext(ct):diffuse(HVColor.GetClearTypeColor(ct))
					self:GetChild("Date"):settext(s:GetDate())
				else
					-- Online leaderboard score
					local s = scores[idx]
					-- Online scores are HighScore objects too
					pcall(function()
						local username = s:GetDisplayName() or s:GetName() or "???"
						self:GetChild("Player"):settext(username)

						local wife = s:GetWifeScore() * 100
						if wife >= 99 then
							self:GetChild("Wife"):settextf("%.4f%%", wife)
						else
							self:GetChild("Wife"):settextf("%.2f%%", wife)
						end

						local gradeStr = ToEnumShortString(s:GetWifeGrade())
						self:GetChild("Grade"):settext(THEME:GetString("Grade", gradeStr)):diffuse(HVColor.GetGradeColor(gradeStr))
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

-- RefreshScores on main frame
t.RefreshScoresCommand = function(self)
	local scores = currentView == VIEW_LOCAL and localScores or onlineScores
	local totalPages = math.max(1, math.ceil(#scores / pageSize))
	currentPage = math.min(currentPage, totalPages)

	local pageInfo = self:GetChild("PageInfo")
	if pageInfo then
		pageInfo:settextf("Page %d / %d (%d scores)", currentPage, totalPages, #scores)
	end

	-- Update column header for player name
	local hdrFrame = nil
	for ci = 1, self:GetNumChildren() do
		-- Headers get updated via the name check in each row
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
			if event.type ~= "InputEventType_FirstPress" then return false end
			local btn = event.DeviceInput.button

			-- Pagination
			local dir = 0
			if btn == "DeviceButton_mousewheel down" or btn == "DeviceButton_right" or btn == "DeviceButton_down" then dir = 1 end
			if btn == "DeviceButton_mousewheel up" or btn == "DeviceButton_left" or btn == "DeviceButton_up" then dir = -1 end
			if dir ~= 0 then
				local scores = currentView == VIEW_LOCAL and localScores or onlineScores
				local totalPages = math.max(1, math.ceil(#scores / pageSize))
				currentPage = math.max(1, math.min(totalPages, currentPage + dir))
				scoresActor:playcommand("RefreshScores")
				return true
			end

			-- Click handling
			if btn == "DeviceButton_left mouse button" then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

				-- Close on outside click
				if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- Local button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 90, SCREEN_CENTER_Y - overlayH/2 + 18, 60, 18) then
					if currentView ~= VIEW_LOCAL then
						currentView = VIEW_LOCAL
						currentPage = 1
						GetLocalScores()
						scoresActor:playcommand("RefreshScores")
					end
					return true
				end

				-- Online button
				if IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 25, SCREEN_CENTER_Y - overlayH/2 + 18, 60, 18) then
					if currentView ~= VIEW_ONLINE then
						currentView = VIEW_ONLINE
						currentPage = 1
						FetchOnlineScores()
						scoresActor:playcommand("RefreshScores")
					end
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
