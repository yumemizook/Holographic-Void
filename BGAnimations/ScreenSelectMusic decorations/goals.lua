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
			self:settextf("GOALS (%d)", #goaltable)
		end,
	},

	-- Add Goal button
	Def.ActorFrame {
		Name = "AddGoalBtn",
		InitCommand = function(self) self:xy(overlayW/2 - 60, -overlayH/2 + 18) end,
		Def.Quad { InitCommand = function(self) self:zoomto(80, 20):diffuse(accentColor):diffusealpha(0.3) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.26):diffuse(brightText):settext("+ ADD GOAL") end },
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
				self:settext("No goals")
			end
		end,
	},

	-- Sortable column headers
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-overlayW/2 + 16, -overlayH/2 + 38) end,

		-- Priority header (clickable to sort)
		LoadFont("Common Normal") .. {
			Name = "HeaderPri",
			InitCommand = function(self) self:halign(0.5):x(20):zoom(0.32):diffuse(accentColor):settext("PRI") end,
		},
		-- Song name header (clickable to sort by name)
		LoadFont("Common Normal") .. {
			Name = "HeaderName",
			InitCommand = function(self) self:halign(0):x(45):zoom(0.32):diffuse(accentColor):settext("SONG") end,
		},
		-- Rate header
		LoadFont("Common Normal") .. {
			Name = "HeaderRate",
			InitCommand = function(self) self:halign(0.5):x(350):zoom(0.32):diffuse(accentColor):settext("RATE") end,
		},
		-- Target header
		LoadFont("Common Normal") .. {
			Name = "HeaderTarget",
			InitCommand = function(self) self:halign(0.5):x(420):zoom(0.32):diffuse(accentColor):settext("TARGET %") end,
		},
		-- Diff header
		LoadFont("Common Normal") .. {
			Name = "HeaderDiff",
			InitCommand = function(self) self:halign(0.5):x(500):zoom(0.32):diffuse(accentColor):settext("DIFF") end,
		},
		-- Date header
		LoadFont("Common Normal") .. {
			Name = "HeaderDate",
			InitCommand = function(self) self:halign(0.5):x(580):zoom(0.32):diffuse(accentColor):settext("STATUS") end,
		},
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 12, -overlayH/2 + 50)
				:zoomto(overlayW - 24, 1):diffuse(color("0.12,0.12,0.12,1"))
		end,
	},

	-- Configuration Panel (shown when adding a goal)
	Def.ActorFrame {
		Name = "ConfigPanel",
		InitCommand = function(self) self:visible(false) end,
		GoalTableRefreshCommand = function(self)
			self:visible(IsAddingGoal)
		end,

		-- Semi-transparent background for config
		Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(color("0,0,0,0.95")) end },
		
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:y(-overlayH/2 + 60):zoom(0.6):diffuse(accentColor):settext("NEW GOAL CONFIGURATION") end,
		},

		-- Settings rows
		Def.ActorFrame {
			InitCommand = function(self) self:y(-20) end,

			-- Target %
			LoadFont("Common Normal") .. { InitCommand = function(self) self:x(-140):halign(1):zoom(0.4):diffuse(subText):settext("TARGET %:") end },
			Def.Quad { 
				Name = "TargetBg",
				InitCommand = function(self) self:x(20):zoomto(120, 36):diffuse(color("0.1,0.1,0.1,1")) end,
				GoalTableRefreshCommand = function(self) self:diffuse(ActiveInput == 1 and color("0.2,0.2,0.2,1") or color("0.1,0.1,0.1,1")) end,
			},
			LoadFont("Common Normal") .. { 
				Name = "TargetVal",
				InitCommand = function(self) self:x(20):zoom(0.5):diffuse(brightText) end,
				GoalTableRefreshCommand = function(self) self:settextf("%.4f%%", NewGoalTarget) end,
			},

			-- Rate
			LoadFont("Common Normal") .. { InitCommand = function(self) self:x(-140):y(60):halign(1):zoom(0.4):diffuse(subText):settext("RATE:") end },
			LoadFont("Common Normal") .. { Name="RateL", InitCommand = function(self) self:x(-30):y(60):zoom(0.4):diffuse(accentColor):settext("<") end },
			LoadFont("Common Normal") .. { 
				Name = "RateVal",
				InitCommand = function(self) self:x(20):y(60):zoom(0.5):diffuse(brightText) end,
				GoalTableRefreshCommand = function(self) self:settextf("%.2fx", NewGoalRate) end,
			},
			LoadFont("Common Normal") .. { Name="RateR", InitCommand = function(self) self:x(70):y(60):zoom(0.4):diffuse(accentColor):settext(">") end },

			-- Priority
			LoadFont("Common Normal") .. { InitCommand = function(self) self:x(-140):y(120):halign(1):zoom(0.4):diffuse(subText):settext("PRIORITY:") end },
			LoadFont("Common Normal") .. { Name="PriL", InitCommand = function(self) self:x(-30):y(120):zoom(0.4):diffuse(accentColor):settext("<") end },
			LoadFont("Common Normal") .. { 
				Name = "PriVal",
				InitCommand = function(self) self:x(20):y(120):zoom(0.5):diffuse(brightText) end,
				GoalTableRefreshCommand = function(self) self:settextf("%d", NewGoalPriority) end,
			},
			LoadFont("Common Normal") .. { Name="PriR", InitCommand = function(self) self:x(70):y(120):zoom(0.4):diffuse(accentColor):settext(">") end },
		},

		-- Buttons
		Def.ActorFrame {
			InitCommand = function(self) self:y(overlayH/2 - 60) end,
			-- Confirm
			Def.ActorFrame {
				Name = "ConfirmBtn",
				InitCommand = function(self) self:x(100) end,
				Def.Quad { InitCommand = function(self) self:zoomto(140, 40):diffuse(color("0,0.5,0,0.6")) end },
				LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.45):diffuse(brightText):settext("CONFIRM") end },
			},
			-- Cancel
			Def.ActorFrame {
				Name = "CancelBtn",
				InitCommand = function(self) self:x(-100) end,
				Def.Quad { InitCommand = function(self) self:zoomto(140, 40):diffuse(color("0.5,0,0,0.6")) end },
				LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.45):diffuse(brightText):settext("CANCEL") end },
			},
		},
	},

	-- Hint
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(1):xy(0, overlayH/2 - 12):zoom(0.26):diffuse(dimText)
				:settext("CLICK song → find on wheel · L/R click pri/rate to adjust · CLICK header to sort · SCROLL to page")
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
				if sg and sg:IsAchieved() then
					self:diffuse(color("0,0.15,0,0.3"))
				else
					self:diffuse(color("0,0,0,0.2"))
				end
			end,
		},

		-- Priority display (L/R click to adjust)
		LoadFont("Common Normal") .. {
			Name = "Priority",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(20):y(rowH/2):zoom(0.4):diffuse(mainText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settextf("%d", sg:GetPriority()) else self:settext("") end
			end,
		},

		-- Song name (click to find on wheel)
		LoadFont("Zpix Normal") .. {
			Name = "SongName",
			InitCommand = function(self)
				self:halign(0):valign(0.5):x(45):y(rowH/2):zoom(0.5):diffuse(brightText):maxwidth(350 / 0.5)
			end,
			GoalTableRefreshCommand = function(self)
				if sg then
					if goalsong then
						self:settext(goalsong:GetDisplayMainTitle()):diffuse(brightText)
					else
						self:settext("[Missing]"):diffuse(color("1,0.3,0.3,1"))
					end
				else
					self:settext("")
				end
			end,
		},

		-- Rate (L/R click to adjust ±0.1)
		LoadFont("Common Normal") .. {
			Name = "Rate",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(420):y(rowH/2):zoom(0.4):diffuse(subText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settextf("%.2fx", sg:GetRate()) else self:settext("") end
			end,
		},

		-- Target %
		LoadFont("Common Normal") .. {
			Name = "Target",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(500):y(rowH/2):zoom(0.45):diffuse(mainText) end,
			GoalTableRefreshCommand = function(self)
				if sg then self:settextf("%.4f%%", sg:GetPercent() * 100) else self:settext("") end
			end,
		},

		-- Difficulty
		LoadFont("Common Normal") .. {
			Name = "Diff",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(580):y(rowH/2):zoom(0.4) end,
			GoalTableRefreshCommand = function(self)
				if sg and goalsteps then
					local d = ToEnumShortString(goalsteps:GetDifficulty())
					self:settext(d):diffuse(HVColor.Difficulty[d] or mainText)
				else
					self:settext("?"):diffuse(dimText)
				end
			end,
		},

		-- Status (achieved / pending)
		LoadFont("Common Normal") .. {
			Name = "Status",
			InitCommand = function(self) self:halign(0.5):valign(0.5):x(660):y(rowH/2):zoom(0.4) end,
			GoalTableRefreshCommand = function(self)
				if sg then
					if sg:IsAchieved() then
						self:settext("DONE"):diffuse(color("0.4,1,0.4,1"))
					else
						self:settext("PENDING"):diffuse(color("1,0.7,0.3,1"))
					end
				else
					self:settext("")
				end
			end,
		},

		-- Delete button (X)
		LoadFont("Common Normal") .. {
			Name = "DeleteBtn",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(overlayW - 42):y(rowH/2):zoom(0.26):diffuse(color("1,0.3,0.3,0.6")):settext("✕")
			end,
			GoalTableRefreshCommand = function(self)
				self:visible(sg ~= nil)
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
				if not goalsActor or not goalsActor:GetVisible() then return false end
				if not event or not event.DeviceInput then return false end
				
				-- ============================================================
				-- NUMERIC INPUT FOR TARGET %
				-- ============================================================
				if ActiveInput == 1 then
					if event.type == "InputEventType_Release" then return true end
					if event.button == "Start" or event.button == "Back" then
						ActiveInput = 0
						NewGoalTarget = tonumber(TargetQuery) or 93
						if NewGoalTarget > 100 then NewGoalTarget = 100 end
						goalsActor:playcommand("GoalTableRefresh")
						return true
					end

					if event.DeviceInput.button == "DeviceButton_backspace" then
						TargetQuery = TargetQuery:sub(1, -2)
					elseif event.DeviceInput.button == "DeviceButton_delete" then
						TargetQuery = ""
					elseif event.DeviceInput.button == "DeviceButton_period" or event.DeviceInput.button == "DeviceButton_kp ." then
						if not TargetQuery:find("%.") then
							TargetQuery = TargetQuery .. "."
						end
					else
						local n = event.DeviceInput.button:match("DeviceButton_(%d)")
						if n then
							if TargetQuery == "0" then TargetQuery = "" end
							TargetQuery = TargetQuery .. n
							-- Cap at 100 or 2 decimal places
							local val = tonumber(TargetQuery)
							if val and val > 100 then TargetQuery = "100" end
							local _, after = TargetQuery:find("%.")
							if after and #TargetQuery - after > 4 then
								TargetQuery = TargetQuery:sub(1, after + 4)
							end
						end
					end
					if TargetQuery == "" then TargetQuery = "0" end
					NewGoalTarget = tonumber(TargetQuery) or 0
					goalsActor:playcommand("GoalTableRefresh")
					return true
				end

				if event.type ~= "InputEventType_FirstPress" then return true end
				local btn = event.DeviceInput.button

				-- ============================================================
				-- KEYBOARD SUPPORT FOR CONFIG PANEL
				-- ============================================================
				if IsAddingGoal and ActiveInput == 0 then
					if btn == "DeviceButton_up" or btn == "DeviceButton_left" then
						NewGoalRate = math.max(0.1, NewGoalRate - 0.1)
						goalsActor:playcommand("GoalTableRefresh")
						return true
					elseif btn == "DeviceButton_down" or btn == "DeviceButton_right" then
						NewGoalRate = math.min(3.0, NewGoalRate + 0.1)
						goalsActor:playcommand("GoalTableRefresh")
						return true
					elseif btn == "DeviceButton_pgup" then
						NewGoalPriority = math.min(100, NewGoalPriority + 1)
						goalsActor:playcommand("GoalTableRefresh")
						return true
					elseif btn == "DeviceButton_pgdn" then
						NewGoalPriority = math.max(0, NewGoalPriority - 1)
						goalsActor:playcommand("GoalTableRefresh")
						return true
					elseif btn == "DeviceButton_enter" or event.button == "Start" then
						-- Trigger Confirm Logic
						local steps = GAMESTATE:GetCurrentSteps()
						local profile = GetProfile()
						if steps and profile then
							local sg = profile:AddGoal(steps:GetChartKey())
							if sg then
								sg:SetPercent(NewGoalTarget / 100)
								sg:SetRate(NewGoalRate)
								sg:SetPriority(NewGoalPriority)
								profile:SetFromAll()
							end
							RefreshGoals()
							IsAddingGoal = false
							goalsActor:playcommand("GoalTableRefresh")
						end
						return true
					elseif btn == "DeviceButton_escape" or event.button == "Back" then
						IsAddingGoal = false
						goalsActor:playcommand("GoalTableRefresh")
						return true
					end
				end

				-- Pagination
				if not IsAddingGoal then
					local dir = 0
					if btn == "DeviceButton_mousewheel down" or btn == "DeviceButton_down" then dir = 1 end
					if btn == "DeviceButton_mousewheel up" or btn == "DeviceButton_up" then dir = -1 end
					if dir ~= 0 then
						ind = math.max(0, math.min(#goaltable - numGoals, ind + dir * numGoals))
						goalsActor:playcommand("GoalTableRefresh")
						return true
					end
				end

				-- Click handling
				if btn == "DeviceButton_left mouse button" or btn == "DeviceButton_right mouse button" then
					local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
					local isRight = btn == "DeviceButton_right mouse button"

					-- Close on outside click
					if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
						if IsAddingGoal then
							IsAddingGoal = false
							ActiveInput = 0
							goalsActor:playcommand("GoalTableRefresh")
						else
							MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						end
						return true
					end

					-- Configuration Panel Clicks
					if IsAddingGoal then
						-- Target % Field
						if IsMouseOverCentered(SCREEN_CENTER_X + 20, SCREEN_CENTER_Y - 20, 120, 36) then
							ActiveInput = 1
							TargetQuery = string.format("%.4f", NewGoalTarget)
							goalsActor:playcommand("GoalTableRefresh")
							return true
						end
						ActiveInput = 0 -- Clicked away from field

						-- Rate adjust
						local rateY = SCREEN_CENTER_Y + 40
						-- Left arrow (<)
						if IsMouseOverCentered(SCREEN_CENTER_X - 30, rateY, 40, 40) then
							NewGoalRate = math.max(0.1, NewGoalRate - 0.1)
							goalsActor:playcommand("GoalTableRefresh")
							return true
						end
						-- Right arrow (>)
						if IsMouseOverCentered(SCREEN_CENTER_X + 70, rateY, 40, 40) then
							NewGoalRate = math.min(3.0, NewGoalRate + 0.1)
							goalsActor:playcommand("GoalTableRefresh")
							return true
						end

						-- Priority adjust
						local priY = SCREEN_CENTER_Y + 100
						-- Left arrow (<)
						if IsMouseOverCentered(SCREEN_CENTER_X - 30, priY, 40, 40) then
							NewGoalPriority = math.max(0, NewGoalPriority - 1)
							goalsActor:playcommand("GoalTableRefresh")
							return true
						end
						-- Right arrow (>)
						if IsMouseOverCentered(SCREEN_CENTER_X + 70, priY, 40, 40) then
							NewGoalPriority = math.min(100, NewGoalPriority + 1)
							goalsActor:playcommand("GoalTableRefresh")
							return true
						end

						-- Confirm / Cancel Buttons
						local btnY = SCREEN_CENTER_Y + overlayH/2 - 60
						-- Confirm
						if IsMouseOverCentered(SCREEN_CENTER_X + 100, btnY, 140, 40) then
							local steps = GAMESTATE:GetCurrentSteps()
							local profile = GetProfile()
							if steps and profile then
								local ck = steps:GetChartKey()
								if ck then
									local sg = profile:AddGoal(ck)
									-- Handle case where it returns boolean or nil
									if not sg or type(sg) == "boolean" then
										local gt = profile:GetGoalTable()
										for _, g in ipairs(gt) do
											if g:GetChartKey() == ck then sg = g; break end
										end
									end
									
									if sg and type(sg) ~= "boolean" then
										sg:SetPercent(NewGoalTarget / 100)
										sg:SetRate(NewGoalRate)
										sg:SetPriority(NewGoalPriority)
										profile:SetFromAll() -- Persist
									end
									RefreshGoals()
									IsAddingGoal = false
									goalsActor:playcommand("GoalTableRefresh")
								end
							end
							return true
						end
						-- Cancel
						if IsMouseOverCentered(SCREEN_CENTER_X - 100, btnY, 140, 40) then
							IsAddingGoal = false
							goalsActor:playcommand("GoalTableRefresh")
							return true
						end

						return true -- Sink all input while config is open
					end

					-- Add Goal button
					if not isRight and IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 60, SCREEN_CENTER_Y - overlayH/2 + 18, 100, 24) then
						IsAddingGoal = true
						NewGoalRate = getCurRateValue()
						NewGoalTarget = 93.00
						TargetQuery = "93.00"
						NewGoalPriority = 0
						goalsActor:playcommand("GoalTableRefresh")
						return true
					end

					-- Header clicks to sort
					local headerY = SCREEN_CENTER_Y - overlayH/2 + 38
					if my >= headerY - 15 and my <= headerY + 15 and not isRight then
						local profile = GetProfile()
						if profile then
							local hx = mx - (SCREEN_CENTER_X - overlayW/2 + 16)
							if hx >= 0 and hx <= 40 then
								pcall(function() profile:SortByPriority() end)
							elseif hx >= 45 and hx <= 340 then
								pcall(function() profile:SortByName() end)
							elseif hx >= 340 and hx <= 400 then
								pcall(function() profile:SortByRate() end)
							elseif hx >= 400 and hx <= 460 then
								pcall(function() profile:SortByDiff() end)
							elseif hx >= 460 and hx <= 640 then
								pcall(function() profile:SortByDate() end)
							end
							ind = 0
							RefreshGoals()
							goalsActor:playcommand("GoalTableRefresh")
						end
						return true
					end

					-- Row clicks
					for ri = 1, numGoals do
						local rowTop = SCREEN_CENTER_Y + rowStartY + (ri - 1) * rowH
						local rowLeft = SCREEN_CENTER_X - overlayW/2 + 16
						if my >= rowTop and my <= rowTop + rowH then
							local gIdx = ri + ind
							if gIdx <= #goaltable then
								local sg = goaltable[gIdx]
								local hx = mx - rowLeft

								-- Delete button (right end)
								if hx >= overlayW - 65 and hx <= overlayW - 15 then
									if not isRight then
										pcall(function() sg:Delete() end)
										pcall(function() GetProfile():SetFromAll() end)
										RefreshGoals()
										if whee then whee:RebuildWheelItems() end
										goalsActor:playcommand("GoalTableRefresh")
									end
									return true
								end

								-- Rate column (L +0.1, R -0.1)
								if hx >= 350 and hx <= 410 then
									if not isRight then
										pcall(function() sg:SetRate(sg:GetRate() + 0.1) end)
									else
										pcall(function() sg:SetRate(sg:GetRate() - 0.1) end)
									end
									goalsActor:playcommand("GoalTableRefresh")
									return true
								end

								-- Song name click → find on wheel
								if hx >= 30 and hx <= 350 and not isRight then
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
					if IsAddingGoal then
						IsAddingGoal = false
						ActiveInput = 0
						goalsActor:playcommand("GoalTableRefresh")
					else
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					end
					return true
				end

				-- Sink all input when overlay is visible
				return true
			end)
	end,
}

return t
