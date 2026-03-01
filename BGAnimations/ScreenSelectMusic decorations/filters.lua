--- Holographic Void: Filters Tab
-- Uses the C++ FILTERMAN singleton for per-skillset MSD filtering,
-- rate bounds, filter mode (AND/OR), and instant wheel refresh via whee:SongSearch("")

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.04,0.04,0.04,0.97")

local overlayW = 680
local overlayH = 400
local filtersActor = nil
local whee = nil

-- Active numeric input state (0 = none, 1-10 = which filter index)
local ActiveSS = 0
local activebound = 0 -- 0 = lower, 1 = upper
local SSQuery = {{}, {}}
for i = 1, #ms.SkillSets + 2 do
	SSQuery[1][i] = "0"
	SSQuery[2][i] = "0"
end

-- Numeric input handler (runs when a filter cell is being edited)
local function FilterInput(event)
	if event.type == "InputEventType_Release" then return true end
	if ActiveSS == 0 then return false end

	if event.button == "Start" or event.button == "Back" then
		ActiveSS = 0
		MESSAGEMAN:Broadcast("HV_NumericInputEnded")
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		return true
	end

	local shouldUpdate = false
	local bnd = activebound + 1 -- SSQuery use 1-indexed bounds

	if event.DeviceInput.button == "DeviceButton_backspace" then
		SSQuery[bnd][ActiveSS] = SSQuery[bnd][ActiveSS]:sub(1, -2)
		shouldUpdate = true
	elseif event.DeviceInput.button == "DeviceButton_delete" then
		SSQuery[bnd][ActiveSS] = ""
		shouldUpdate = true
	else
		-- Number keys 0-9
		local numbershers = {"1","2","3","4","5","6","7","8","9","0"}
		for _, n in ipairs(numbershers) do
			if event.DeviceInput.button == "DeviceButton_" .. n then
				shouldUpdate = true
				if SSQuery[bnd][ActiveSS] == "0" then
					SSQuery[bnd][ActiveSS] = ""
				end
				SSQuery[bnd][ActiveSS] = SSQuery[bnd][ActiveSS] .. n
				-- Clamp length: 2 digits for MSD, 3 for length, 5 for %
				local maxLen = ActiveSS <= #ms.SkillSets and 2 or (ActiveSS == #ms.SkillSets + 1 and 3 or 5)
				if #SSQuery[bnd][ActiveSS] > maxLen then
					SSQuery[bnd][ActiveSS] = n
				end
			end
		end
	end

	if SSQuery[bnd][ActiveSS] == "" then
		shouldUpdate = true
		SSQuery[bnd][ActiveSS] = "0"
	end

	if shouldUpdate then
		local num = tonumber(SSQuery[bnd][ActiveSS]) or 0
		FILTERMAN:SetSSFilter(num, ActiveSS, activebound)
		if whee then whee:SongSearch("") end
		MESSAGEMAN:Broadcast("HV_FilterUpdated")
	end

	return true
end

-- Build the UI
local t = Def.ActorFrame {
	Name = "FiltersOverlay",
	InitCommand = function(self)
		filtersActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen then
			whee = screen:GetMusicWheel()
			screen:AddInputCallback(function(event)
				if not filtersActor or not filtersActor:GetVisible() then return false end
				if not event or not event.DeviceInput then return false end
				
				-- If numeric input is active, it handles everything
				if ActiveSS > 0 then return FilterInput(event) end

				if event.type ~= "InputEventType_FirstPress" then return true end
				local btn = event.DeviceInput.button

				-- Click handling
				if btn == "DeviceButton_left mouse button" then
					local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
					if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						return true
					end
					
					-- (The actual cell/button logic is handled in the other callback below, but we must return true here if we're over the overlay)
					return true 
				end

				if event.button == "Back" then
					ActiveSS = 0
					SCREENMAN:set_input_redirected(PLAYER_1, false)
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- Sink all other input
				return true
			end)
		end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "FILTERS" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				HV.ActiveTab = "FILTERS"
				self:playcommand("RefreshUI")
			else
				HV.ActiveTab = ""
				ActiveSS = 0
				SCREENMAN:set_input_redirected(PLAYER_1, false)
			end
		else
			self:visible(false)
			if HV.ActiveTab == "FILTERS" then HV.ActiveTab = "" end
			ActiveSS = 0
			SCREENMAN:set_input_redirected(PLAYER_1, false)
		end
	end,

	-- Background
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard) end },
	Def.Quad { InitCommand = function(self) self:valign(0):y(-overlayH/2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7) end },

	-- Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 20, -overlayH/2 + 15):zoom(0.5):diffuse(accentColor):settext("FILTERS")
		end,
	},

	-- Instructions
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 20, -overlayH/2 + 35):zoom(0.28):diffuse(dimText)
				:settext("CLICK a cell to type a number · ENTER/ESC to finish · Right-click to cancel")
		end,
	},

	-- Column headers
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-overlayW/2 + 25, -overlayH/2 + 58) end,
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0):zoom(0.32):diffuse(dimText):settext("SKILLSET") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(overlayW - 200):zoom(0.32):diffuse(dimText):settext("MIN") end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:halign(0.5):x(overlayW - 120):zoom(0.32):diffuse(dimText):settext("MAX") end },
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 12, -overlayH/2 + 62):zoomto(overlayW - 24, 1):diffuse(color("0.12,0.12,0.12,1"))
		end,
	},
}

-- Skillset filter rows (8 skillsets + Length + Best%)
local rowH = 26
local rowStartY = -overlayH/2 + 72
local totalRows = #ms.SkillSets + 2

for i = 1, totalRows do
	local label = ""
	if i <= #ms.SkillSets then
		label = ms.SkillSetsTranslated[i] or ms.SkillSets[i]
	elseif i == #ms.SkillSets + 1 then
		label = "Length (s)"
	else
		label = "Best %"
	end

	t[#t + 1] = Def.ActorFrame {
		Name = "FilterRow_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW/2 + 16, rowStartY + (i-1) * rowH)
		end,

		-- Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):valign(0.5):y(rowH/2):zoom(0.28):diffuse(mainText):settext(label) end,
		},

		-- Lower bound cell
		Def.Quad {
			Name = "LowerBg",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(280):y(rowH/2):zoomto(50, rowH - 4):diffuse(color("0.06,0.06,0.06,1"))
			end,
			RefreshUICommand = function(self)
				if ActiveSS == i and activebound == 0 then
					self:diffuse(color("0.15,0.15,0.15,1"))
				else
					self:diffuse(color("0.06,0.06,0.06,1"))
				end
			end,
			HV_FilterUpdatedMessageCommand = function(self) self:playcommand("RefreshUI") end,
			HV_NumericInputEndedMessageCommand = function(self) self:playcommand("RefreshUI") end,
		},
		LoadFont("Common Normal") .. {
			Name = "LowerVal",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(280):y(rowH/2):zoom(0.30):diffuse(brightText)
			end,
			RefreshUICommand = function(self)
				local val = FILTERMAN:GetSSFilter(i, 0)
				if val <= 0 then
					self:settext("—"):diffuse(dimText)
				else
					self:settextf("%g", val):diffuse(brightText)
				end
			end,
			HV_FilterUpdatedMessageCommand = function(self) self:playcommand("RefreshUI") end,
			HV_NumericInputEndedMessageCommand = function(self) self:playcommand("RefreshUI") end,
		},

		-- Upper bound cell
		Def.Quad {
			Name = "UpperBg",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(350):y(rowH/2):zoomto(50, rowH - 4):diffuse(color("0.06,0.06,0.06,1"))
			end,
			RefreshUICommand = function(self)
				if ActiveSS == i and activebound == 1 then
					self:diffuse(color("0.15,0.15,0.15,1"))
				else
					self:diffuse(color("0.06,0.06,0.06,1"))
				end
			end,
			HV_FilterUpdatedMessageCommand = function(self) self:playcommand("RefreshUI") end,
			HV_NumericInputEndedMessageCommand = function(self) self:playcommand("RefreshUI") end,
		},
		LoadFont("Common Normal") .. {
			Name = "UpperVal",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(350):y(rowH/2):zoom(0.30):diffuse(brightText)
			end,
			RefreshUICommand = function(self)
				local val = FILTERMAN:GetSSFilter(i, 1)
				if val <= 0 then
					self:settext("—"):diffuse(dimText)
				else
					self:settextf("%g", val):diffuse(brightText)
				end
			end,
			HV_FilterUpdatedMessageCommand = function(self) self:playcommand("RefreshUI") end,
			HV_NumericInputEndedMessageCommand = function(self) self:playcommand("RefreshUI") end,
		},
	}

	-- Click handlers for the cells (as a separate ActorFrame so they get proper input)
	t[#t + 1] = Def.ActorFrame {
		BeginCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if not screen then return end
			-- We use the existing input callback, but also need click detection on cells
		end,
	}
end

-- Rate filters and mode toggles (below the skillset rows)
local controlsY = rowStartY + totalRows * rowH + 6

t[#t + 1] = Def.ActorFrame {
	Name = "Controls",
	InitCommand = function(self) self:xy(-overlayW/2 + 16, controlsY) end,

	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):y(-4):zoomto(overlayW - 32, 1):diffuse(color("0.12,0.12,0.12,1"))
		end,
	},

	-- Max Rate
	LoadFont("Common Normal") .. {
		Name = "MaxRate",
		InitCommand = function(self)
			self:halign(0):valign(0.5):xy(0, 14):zoom(0.28):diffuse(accentColor)
		end,
		RefreshUICommand = function(self)
			self:settextf("Max Rate: %.1fx", FILTERMAN:GetMaxFilterRate())
		end,
		HV_FilterUpdatedMessageCommand = function(self) self:playcommand("RefreshUI") end,
	},
	-- Min Rate
	LoadFont("Common Normal") .. {
		Name = "MinRate",
		InitCommand = function(self)
			self:halign(0):valign(0.5):xy(0, 34):zoom(0.28):diffuse(accentColor)
		end,
		RefreshUICommand = function(self)
			self:settextf("Min Rate: %.1fx", FILTERMAN:GetMinFilterRate())
		end,
		HV_FilterUpdatedMessageCommand = function(self) self:playcommand("RefreshUI") end,
	},

	-- Mode toggle (AND / OR)
	LoadFont("Common Normal") .. {
		Name = "ModeToggle",
		InitCommand = function(self)
			self:halign(0):valign(0.5):xy(200, 14):zoom(0.28):diffuse(accentColor)
		end,
		RefreshUICommand = function(self)
			if FILTERMAN:GetFilterMode() then
				self:settext("Mode: AND")
			else
				self:settext("Mode: OR")
			end
		end,
		HV_FilterUpdatedMessageCommand = function(self) self:playcommand("RefreshUI") end,
	},

	-- FilterResults display
	LoadFont("Common Normal") .. {
		Name = "Results",
		InitCommand = function(self)
			self:halign(0):valign(0.5):xy(200, 34):zoom(0.26):diffuse(subText)
		end,
		FilterResultsMessageCommand = function(self, msg)
			if msg then
				self:settextf("Matches: %d / %d", msg.Matches or 0, msg.Total or 0)
			end
		end,
	},
}

-- Action buttons (Reset, Apply Rate+/-, Mode toggle)
t[#t + 1] = Def.ActorFrame {
	Name = "ActionButtons",
	InitCommand = function(self) self:xy(0, overlayH/2 - 25) end,

	-- Reset button
	Def.ActorFrame {
		InitCommand = function(self) self:x(-120) end,
		Def.Quad { InitCommand = function(self) self:zoomto(90, 24):diffuse(color("0.15,0,0,0.8")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.28):diffuse(color("1,0.4,0.4,1")):settext("RESET ALL") end },
	},

	-- Rate+ button
	Def.ActorFrame {
		InitCommand = function(self) self:x(-20) end,
		Def.Quad { InitCommand = function(self) self:zoomto(60, 24):diffuse(color("0.1,0.1,0.1,1")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.28):diffuse(mainText):settext("RATE+") end },
	},

	-- Rate- button
	Def.ActorFrame {
		InitCommand = function(self) self:x(45) end,
		Def.Quad { InitCommand = function(self) self:zoomto(60, 24):diffuse(color("0.1,0.1,0.1,1")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.28):diffuse(mainText):settext("RATE-") end },
	},

	-- Mode toggle button
	Def.ActorFrame {
		InitCommand = function(self) self:x(120) end,
		Def.Quad { InitCommand = function(self) self:zoomto(80, 24):diffuse(color("0.1,0.1,0.1,1")) end },
		LoadFont("Common Normal") .. { InitCommand = function(self) self:zoom(0.28):diffuse(mainText):settext("TOGGLE MODE") end },
	},
}

-- Click handling for cells and buttons
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if not filtersActor or not filtersActor:GetVisible() then return false end
			if not event or not event.DeviceInput then return false end
			if event.type ~= "InputEventType_FirstPress" then return false end
			if event.DeviceInput.button ~= "DeviceButton_left mouse button" and
			   event.DeviceInput.button ~= "DeviceButton_right mouse button" then return false end

			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			local isRightClick = event.DeviceInput.button == "DeviceButton_right mouse button"

			-- Right-click cancels numeric input
			if isRightClick and ActiveSS > 0 then
				ActiveSS = 0
				MESSAGEMAN:Broadcast("HV_NumericInputEnded")
				SCREENMAN:set_input_redirected(PLAYER_1, false)
				return true
			end

			if not isRightClick then
				-- Check filter cell clicks
				for fi = 1, totalRows do
					local cellY = SCREEN_CENTER_Y + rowStartY + (fi-1) * rowH + rowH/2
					-- Lower bound cell (MIN)
					if IsMouseOverCentered(SCREEN_CENTER_X + 140, cellY, 50, rowH) then
						ActiveSS = fi
						activebound = 0
						SSQuery[1][fi] = "0"
						MESSAGEMAN:Broadcast("HV_NumericInputActive")
						SCREENMAN:set_input_redirected(PLAYER_1, true)
						filtersActor:playcommand("RefreshUI")
						return true
					end
					-- Upper bound cell (MAX)
					if IsMouseOverCentered(SCREEN_CENTER_X + 210, cellY, 50, rowH) then
						ActiveSS = fi
						activebound = 1
						SSQuery[2][fi] = "0"
						MESSAGEMAN:Broadcast("HV_NumericInputActive")
						SCREENMAN:set_input_redirected(PLAYER_1, true)
						filtersActor:playcommand("RefreshUI")
						return true
					end
				end

				-- Check action buttons
				local btnY = SCREEN_CENTER_Y + overlayH/2 - 25

				-- Reset
				if IsMouseOverCentered(SCREEN_CENTER_X - 120, btnY, 90, 24) then
					FILTERMAN:ResetAllFilters()
					for idx = 1, totalRows do
						SSQuery[1][idx] = "0"
						SSQuery[2][idx] = "0"
					end
					ActiveSS = 0
					SCREENMAN:set_input_redirected(PLAYER_1, false)
					MESSAGEMAN:Broadcast("HV_FilterUpdated")
					MESSAGEMAN:Broadcast("HV_NumericInputEnded")
					if whee then whee:SongSearch("") end
					filtersActor:playcommand("RefreshUI")
					return true
				end

				-- Rate+
				if IsMouseOverCentered(SCREEN_CENTER_X - 20, btnY, 60, 24) then
					FILTERMAN:SetMaxFilterRate(FILTERMAN:GetMaxFilterRate() + 0.1)
					if whee then whee:SongSearch("") end
					MESSAGEMAN:Broadcast("HV_FilterUpdated")
					filtersActor:playcommand("RefreshUI")
					return true
				end

				-- Rate-
				if IsMouseOverCentered(SCREEN_CENTER_X + 45, btnY, 60, 24) then
					FILTERMAN:SetMinFilterRate(FILTERMAN:GetMinFilterRate() + 0.1)
					if whee then whee:SongSearch("") end
					MESSAGEMAN:Broadcast("HV_FilterUpdated")
					filtersActor:playcommand("RefreshUI")
					return true
				end

				-- Mode toggle
				if IsMouseOverCentered(SCREEN_CENTER_X + 120, btnY, 80, 24) then
					FILTERMAN:ToggleFilterMode()
					if whee then whee:SongSearch("") end
					MESSAGEMAN:Broadcast("HV_FilterUpdated")
					filtersActor:playcommand("RefreshUI")
					return true
				end
			end

			return false
		end)
	end,
}

return t
