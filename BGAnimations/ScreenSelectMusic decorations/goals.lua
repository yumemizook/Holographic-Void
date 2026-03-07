--- Holographic Void: Goals Tab
-- Uses profile:GetGoalTable() with Til Death-matching sort/edit APIs
-- per-goal priority/rate editing, delete, and click-to-find-song

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.04,0.04,0.04,0.97")

local overlayW = 680
local overlayH = 400
local rowH = 32
local numGoals = 10
local ind = 0 -- scroll offset (0-indexed like Til Death)
local goalsActor = nil
local whee = nil
local goaltable = {}
local IsAddingGoal = false
local NewGoalTarget = 93 -- default 93%
local NewGoalRate = 1.0
local NewGoalPriority = 0
local ActiveInput = 0 -- 0=none, 1=Target%
local TargetQuery = "93.00"

local function GetProfile()
	return GetPlayerOrMachineProfile(PLAYER_1) or PROFILEMAN:GetProfile(PLAYER_1)
end

local function RefreshGoals()
	goaltable = {}
	local profile = GetProfile()
	if profile then
		-- Sync profile data (ensures goals are loaded from XML/Sync)
		pcall(function() profile:SetFromAll() end)
		local ok, gt = pcall(function() return profile:GetGoalTable() end)
		if ok and gt then goaltable = gt end
	end
end

local t = Def.ActorFrame {
	Name = "GoalsOverlay",
	InitCommand = function(self)
		goalsActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.GetMusicWheel then whee = screen:GetMusicWheel() end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "GOALS" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				HV.ActiveTab = "GOALS"
				ind = 0
				RefreshGoals()
			else
				HV.ActiveTab = ""
				IsAddingGoal = false
				ActiveInput = 0
			end
		else
			self:visible(false)
			if HV.ActiveTab == "GOALS" then HV.ActiveTab = "" end
			IsAddingGoal = false
			ActiveInput = 0
		end
		self:playcommand("GoalTableRefresh")
	end,

	-- Background
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard) end },
	Def.Quad { InitCommand = function(self) self:valign(0):y(-overlayH/2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7) end },

	-- Title
	LoadFont("Common Normal") .. {
		Name = "Title",
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 20, -overlayH/2 + 15):zoom(0.5):diffuse(accentColor)
		end,
		GoalTableRefreshCommand = function(self)
			self:settextf(THEME:GetString("Goals", "Title"), #goaltable)
		end,
	},

	-- Add Goal button (Relocated to top right for cleaner look)
	Def.ActorFrame {
		Name = "AddGoalBtn",
		InitCommand = function(self) self:xy(overlayW/2 - 80, -overlayH/2 + 25) end,
		Def.Quad { 
			InitCommand = function(self) 
				self:zoomto(100, 26):diffuse(accentColor):diffusealpha(0.15)
					:blend(Blend.Add)
			end 
		},
		Def.Quad { 
			InitCommand = function(self) 
				self:zoomto(100, 2):valign(1):y(13):diffuse(accentColor):diffusealpha(0.6)
			end 
		},
		LoadFont("Common Normal") .. { 
			InitCommand = function(self) 
				self:zoom(0.3):diffuse(brightText):settext(THEME:GetString("Goals", "AddGoal")) 
			end 
		},
	},

	-- Page indicator
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:halign(0.5):valign(0):xy(0, -overlayH/2 + 10):zoom(0.24):diffuse(dimText)
		end,
		GoalTableRefreshCommand = function(self)
			if #goaltable > 0 then
				self:settextf("%d-%d of %d", ind + 1, math.min(ind + numGoals, #goaltable), #goaltable)
			else
				self:settext(THEME:GetString("Goals", "NoGoals"))
			end
		end,
	},

	-- Sortable column headers
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-overlayW/2 + 16, -overlayH/2 + 38) end,

		-- Priority header
		LoadFont("Common Normal") .. {
			Name = "HeaderPri",
			InitCommand = function(self) self:halign(0.5):x(45):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Goals", "PriorityColumn")) end,
		},
		-- Song name header
		LoadFont("Common Normal") .. {
			Name = "HeaderName",
			InitCommand = function(self) self:halign(0):x(75):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Goals", "SongColumn")) end,
		},
		-- Rate header
		LoadFont("Common Normal") .. {
			Name = "HeaderRate",
			InitCommand = function(self) self:halign(0.5):x(365):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Goals", "RateColumn")) end,
		},
		-- Target header
		LoadFont("Common Normal") .. {
			Name = "HeaderTarget",
			InitCommand = function(self) self:halign(0.5):x(425):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Goals", "TargetColumn")) end,
		},
		-- Diff header
		LoadFont("Common Normal") .. {
			Name = "HeaderDiff",
			InitCommand = function(self) self:halign(0.5):x(485):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Goals", "DiffColumn")) end,
		},
		-- PB header
		LoadFont("Common Normal") .. {
			Name = "HeaderPB",
			InitCommand = function(self) self:halign(0.5):x(545):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Goals", "PBColumn") or "PB") end,
		},
		-- Status header
		LoadFont("Common Normal") .. {
			Name = "HeaderStatus",
			InitCommand = function(self) self:halign(0.5):x(625):zoom(0.32):diffuse(accentColor):settext(THEME:GetString("Goals", "StatusColumn")) end,
		},
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 12, -overlayH/2 + 50)
				:zoomto(overlayW - 24, 1):diffuse(color("0.12,0.12,0.12,1"))
		end,
	},

	-- Hint
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(1):xy(0, overlayH/2 - 12):zoom(0.26):diffuse(dimText)
				:settext(THEME:GetString("Goals", "Hint"))
		end,
	},
}

-- Goal rows
local rowStartY = -overlayH/2 + 58

local function makeGoalRow(i)
	local sg, ck, goalsong, goalsteps

	local row = Def.ActorFrame {
		Name = "GoalRow_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW/2 + 16, rowStartY + (i - 1) * rowH)
		end,
		GoalTableRefreshCommand = function(self)
			sg = goaltable[i + ind]
			if sg then
				ck = sg:GetChartKey()
				goalsong = SONGMAN:GetSongByChartKey(ck)
				goalsteps = SONGMAN:GetStepsByChartKey(ck)
				self:visible(true)
			else
				self:visible(false)
			end
		end,

		-- Row background
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(overlayW - 32, rowH - 2):diffuse(color("0,0,0,0.2"))
			end,
			GoalTableRefreshCommand = function(self)
				if sg then
					if sg:IsVacuous() then
						self:diffuse(color("0.15,0.15,0,0.3")) -- Yellowish for vacuous
					elseif sg:IsAchieved() then
						self:diffuse(color("0,0.15,0,0.3")) -- Greenish for achieved
					else
						self:diffuse(color("0,0,0,0.2"))
					end
				end
			end,
		},

		-- Delete button (X)
		LoadActor(THEME:GetPathG("", "delete")) .. {
			Name = "DeleteBtn",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(15):y(rowH/2):zoom(0.2)
			end,
			GoalTableRefreshCommand = function(self)
				self:visible(sg ~= nil)
				if sg then
					self:diffuse(color("1,0.3,0.3,0.6"))
				end
			end,
		},

		-- Priority display
		LoadFont("Common Normal") .. {
			Name = "Priority",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(45):y(rowH/2):zoom(0.4):diffuse(mainText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settextf("%d", sg:GetPriority()) else self:settext("") end
			end,
		},

		-- Song name
		LoadFont("Zpix Normal") .. {
			Name = "SongName",
			InitCommand = function(self)
				self:halign(0):valign(0.5):x(75):y(rowH/2):zoom(0.5):diffuse(brightText):maxwidth(280 / 0.5)
			end,
			GoalTableRefreshCommand = function(self)
				if sg then
					if goalsong then
						self:settext(goalsong:GetDisplayMainTitle()):diffuse(brightText)
					else
						self:settext(THEME:GetString("Goals", "SongMissing")):diffuse(color("1,0.3,0.3,1"))
					end
				else
					self:settext("")
				end
			end,
		},

		-- Rate
		LoadFont("Common Normal") .. {
			Name = "Rate",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(365):y(rowH/2):zoom(0.4):diffuse(subText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settextf("%.2fx", sg:GetRate()) else self:settext("") end
			end,
		},

		-- Target %
		LoadFont("Common Normal") .. {
			Name = "Target",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(425):y(rowH/2):zoom(0.4):diffuse(mainText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settextf("%.2f%%", sg:GetPercent() * 100) else self:settext("") end
			end,
		},

		-- Difficulty
		LoadFont("Common Normal") .. {
			Name = "Diff",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(485):y(rowH/2):zoom(0.4) end,
			GoalTableRefreshCommand = function(self)
				if sg and goalsteps then
					local d = ToEnumShortString(goalsteps:GetDifficulty())
					self:settext(d):diffuse(HVColor.Difficulty[d] or mainText)
				else
					self:settext("?"):diffuse(dimText)
				end
			end,
		},

		-- PB Display
		LoadFont("Common Normal") .. {
			Name = "PB",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(545):y(rowH/2):zoom(0.38) end,
			GoalTableRefreshCommand = function(self)
				if sg then
					local pb = sg:GetPBUpTo()
					if pb then
						local pbc = pb:GetWifeScore() * 100
						if pb:GetMusicRate() < sg:GetRate() then
							self:settextf("%.2f%% (%.2fx)", pbc, pb:GetMusicRate())
						else
							self:settextf("%.2f%%", pbc)
						end
						if sg:IsAchieved() then
							self:diffuse(color("0.5,1,0.5,1"))
						else
							self:diffuse(subText)
						end
					else
						self:settext("-"):diffuse(dimText)
					end
				else
					self:settext("")
				end
			end,
		},

		-- Status
		LoadFont("Common Normal") .. {
			Name = "Status",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(625):y(rowH/2):zoom(0.38) end,
			GoalTableRefreshCommand = function(self)
				if sg then
					if sg:IsVacuous() then
						self:settext(THEME:GetString("Goals", "Vacuous")):diffuse(color("0.9,0.9,0.3,1"))
					elseif sg:IsAchieved() then
						self:settext(THEME:GetString("Goals", "Achieved")):diffuse(color("0.4,1,0.4,1"))
					else
						self:settext(THEME:GetString("Goals", "Pending")):diffuse(color("1,0.7,0.3,1"))
					end
				else
					self:settext("")
				end
			end,
		},
	}

	return row
end

for i = 1, numGoals do
	t[#t + 1] = makeGoalRow(i)
end

-- Input handler
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
			screen:AddInputCallback(function(event)
				-- Always sink inputs when visible to prevent leaks to underlying MusicWheel
				if not goalsActor or not goalsActor:GetVisible() then return false end

				-- Sink mouse moves and other non-device inputs early
				if not event or not event.DeviceInput then return true end
				
				local btn = event.DeviceInput.button or ""
				local evType = event.type
				local isRight = btn == "DeviceButton_right mouse button"
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				
				-- Handle mouse moves and releases early
				if evType == "InputEventType_Release" then return true end

				-- Ensure period key is sunk even if not in numeric input mode
				-- to prevent native Sort changes (Etterna default)
				if btn == "DeviceButton_period" or btn == "DeviceButton_kp ." then
					if ActiveInput ~= 1 then
						return true -- Sink but don't handle
					end
				end

				-- Add Goal Button Click (Top Right)
				if btn == "DeviceButton_left mouse button" and evType == "InputEventType_FirstPress" then
					-- Bounding box for the stylized button in the top right
					-- Relative to center: x = overlayW/2 - 80 (260), y = -overlayH/2 + 25 (-175)
					-- With width 100, height 26
					local btnCX = SCREEN_CENTER_X + (overlayW / 2) - 80
					local btnCY = SCREEN_CENTER_Y - (overlayH / 2) + 25
					
					if mx >= btnCX - 50 and mx <= btnCX + 50 and my >= btnCY - 13 and my <= btnCY + 13 then
						local steps = GAMESTATE:GetCurrentSteps()
						local profile = GetProfile()
						if steps and profile then
							local ck = steps:GetChartKey()
							if ck then
								local sg = profile:AddGoal(ck)
								-- AddGoal might return true or a scoregoal object
								if not sg or type(sg) == "boolean" then
									local gt = profile:GetGoalTable()
									for _, g in ipairs(gt) do
										if g:GetChartKey() == ck then sg = g; break end
									end
								end
								if sg and type(sg) ~= "boolean" then
									sg:SetPercent(0.93)
									sg:SetRate(getCurRateValue() or 1.0)
									sg:SetPriority(0)
									pcall(function() profile:SetFromAll() end)
								end
								RefreshGoals()
								goalsActor:playcommand("GoalTableRefresh")
							end
						end
						return true
					end
				end

				-- Pagination
				local dir = 0
				if btn == "DeviceButton_mousewheel down" or btn == "DeviceButton_down" then dir = 1 end
				if btn == "DeviceButton_mousewheel up" or btn == "DeviceButton_up" then dir = -1 end
				if dir ~= 0 then
					ind = math.max(0, math.min(#goaltable - numGoals, ind + dir * numGoals))
					goalsActor:playcommand("GoalTableRefresh")
					return true
				end

				-- Click handling
				if btn == "DeviceButton_left mouse button" or btn == "DeviceButton_right mouse button" then
					-- Close on outside click
					if mx < SCREEN_CENTER_X - overlayW/2 or mx > SCREEN_CENTER_X + overlayW/2 or my < SCREEN_CENTER_Y - overlayH/2 or my > SCREEN_CENTER_Y + overlayH/2 then
						if evType ~= "InputEventType_FirstPress" then return true end
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						return true
					end

					-- If we are clicking inside the overlay, it's safe to run the rest of the click logic.
					for ri = 1, numGoals do
						local rowTop = SCREEN_CENTER_Y + rowStartY + (ri - 1) * rowH
						local rowLeft = SCREEN_CENTER_X - overlayW/2 + 16
						if my >= rowTop and my <= rowTop + rowH then
							local gIdx = ri + ind
							if gIdx <= #goaltable then
								local sg = goaltable[gIdx]
								local hx = mx - rowLeft

								-- Delete button (left end)
								if hx >= 0 and hx <= 30 then
									if not isRight then
										pcall(function() sg:Delete() end)
										pcall(function() GetProfile():SetFromAll() end)
										RefreshGoals()
										if whee then whee:RebuildWheelItems() end
										goalsActor:playcommand("GoalTableRefresh")
									end
									return true
								end

								-- Priority column (L +1, R -1)
								if hx >= 30 and hx <= 65 then
									if not isRight then
										pcall(function() sg:SetPriority(sg:GetPriority() + 1) end)
									else
										pcall(function() sg:SetPriority(sg:GetPriority() - 1) end)
									end
									goalsActor:playcommand("GoalTableRefresh")
									return true
								end

								-- Rate column (L +0.1, R -0.1)
								if hx >= 345 and hx <= 395 then
									if not isRight then
										pcall(function() sg:SetRate(sg:GetRate() + 0.1) end)
									else
										pcall(function() sg:SetRate(sg:GetRate() - 0.1) end)
									end
									goalsActor:playcommand("GoalTableRefresh")
									return true
								end

								-- Target % column (L +1.0%, R -1.0%, Ctrl for +0.01%/-0.01%)
								if hx >= 395 and hx <= 455 then
									local step = INPUTFILTER:IsControlPressed() and 0.0001 or 0.01
									if isRight then step = step * -1 end
									pcall(function() sg:SetPercent(sg:GetPercent() + step) end)
									goalsActor:playcommand("GoalTableRefresh")
									return true
								end

								-- Song name click → find on wheel
								if hx >= 65 and hx <= 345 and not isRight then
									local ck = sg:GetChartKey()
									if ck then
										local song = SONGMAN:GetSongByChartKey(ck)
										if song and whee then
											whee:SelectSong(song)
										end
									end
									MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
									return true
								end
							end -- end if sg
							return true
						end -- end row click
					end -- end rows loop
					
					return true -- Sink all other clicks inside the overlay
				end

				if event.button == "Back" or event.DeviceInput.button == "DeviceButton_escape" then
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- WE DO NOT SINK UNHANDLED INPUTS ANYMORE. Let standard wheel interactions pass through if not explicitly trapped above.
				return false
			end)

	end,
}

return t
