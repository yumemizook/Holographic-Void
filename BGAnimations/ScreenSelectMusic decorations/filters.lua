--- Holographic Void: Filters Tab
-- Rebuilt from Til Death's implementation using UIElements for proper mouse/keyboard input.
-- Uses FILTERMAN singleton for per-skillset MSD filtering, rate bounds, filter mode, and wheel refresh.

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
local active = false

local hoverAlpha = 0.6
local textzoom = 0.40
local spacingY = 25
local numbershers = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"}

-- Active numeric input state
local ActiveSS = 0
local activebound = 0 -- 0 = lower, 1 = upper
local SSQuery = {}
SSQuery[0] = {}
SSQuery[1] = {}
for i = 1, #ms.SkillSets + 2 do
	SSQuery[0][i] = "0"
	SSQuery[1][i] = "0"
end
local numbersafterthedecimal = 0

local totalRows = #ms.SkillSets + 2

-- Numeric input handler (runs when a filter cell is being edited)
local function FilterInput(event)
	if event.type ~= "InputEventType_Release" and ActiveSS > 0 and active then
		local shouldUpdate = false
		if event.button == "Start" or event.button == "Back" then
			ActiveSS = 0
			MESSAGEMAN:Broadcast("HV_NumericInputEnded")
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			return true
		elseif event.DeviceInput.button == "DeviceButton_backspace" then
			SSQuery[activebound][ActiveSS] = SSQuery[activebound][ActiveSS]:sub(1, -2)
			shouldUpdate = true
		elseif event.DeviceInput.button == "DeviceButton_delete" then
			SSQuery[activebound][ActiveSS] = ""
			shouldUpdate = true
		else
			for i = 1, #numbershers do
				if event.DeviceInput.button == "DeviceButton_" .. numbershers[i] then
					shouldUpdate = true
					if SSQuery[activebound][ActiveSS] == "0" then
						SSQuery[activebound][ActiveSS] = ""
					end
					SSQuery[activebound][ActiveSS] = SSQuery[activebound][ActiveSS] .. numbershers[i]
					-- Clamp lengths: 2 digits for MSD skillsets, 3 for length, 5 for %
					if (ActiveSS < #ms.SkillSets + 1 and #SSQuery[activebound][ActiveSS] > 2)
						or (ActiveSS < #ms.SkillSets + 2 and #SSQuery[activebound][ActiveSS] > 3)
						or #SSQuery[activebound][ActiveSS] > 5 then
						SSQuery[activebound][ActiveSS] = numbershers[i]
					end
				end
			end
		end
		if SSQuery[activebound][ActiveSS] == "" then
			shouldUpdate = true
			SSQuery[activebound][ActiveSS] = "0"
		end
		if shouldUpdate then
			local num = 0
			if ActiveSS == #ms.SkillSets + 2 then
				local q = SSQuery[activebound][ActiveSS]
				numbersafterthedecimal = 0
				if #q > 2 then
					numbersafterthedecimal = #q - 2
					local n = tonumber(q) / (10 ^ (#q - 2))
					n = notShit.round(n, numbersafterthedecimal)
					num = n
				else
					num = tonumber(q)
				end
			else
				num = tonumber(SSQuery[activebound][ActiveSS])
			end
			FILTERMAN:SetSSFilter(num, ActiveSS, activebound)
			if whee then whee:SongSearch("") end
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
		end
	end
end

-- Layout constants
local cellW = 50
local cellH = 20
local rowStartY = 55
local labelColX = 20
local minColX = overlayW / 2 + 20
local maxColX = minColX + cellW + 16

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
		end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "FILTERS" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				HV.ActiveTab = "FILTERS"
				active = true
				self:playcommand("Set")
			else
				HV.ActiveTab = ""
				active = false
				ActiveSS = 0
				SCREENMAN:set_input_redirected(PLAYER_1, false)
			end
		else
			self:visible(false)
			if HV.ActiveTab == "FILTERS" then HV.ActiveTab = "" end
			active = false
			ActiveSS = 0
			SCREENMAN:set_input_redirected(PLAYER_1, false)
		end
	end,

	MouseRightClickMessageCommand = function(self)
		if active then
			ActiveSS = 0
			MESSAGEMAN:Broadcast("HV_NumericInputEnded")
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			SCREENMAN:set_input_redirected(PLAYER_1, false)
		end
	end,

	-- Background card
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(overlayW, overlayH):diffuse(bgCard)
		end,
	},
	-- Accent bar at top
	Def.Quad {
		InitCommand = function(self)
			self:valign(0):y(-overlayH / 2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7)
		end,
	},

	-- Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW / 2 + 20, -overlayH / 2 + 12):zoom(0.55)
				:diffuse(accentColor):settext(THEME:GetString("Filters", "Title"))
		end,
	},

	-- Instructions (Top Right)
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):valign(0):xy(overlayW / 2 - 20, -overlayH / 2 + 15):zoom(0.32):diffuse(dimText)
				:settext(THEME:GetString("Filters", "Instructions"))
		end,
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):valign(0):xy(overlayW / 2 - 20, -overlayH / 2 + 30):zoom(0.32):diffuse(dimText)
				:settext(THEME:GetString("Filters", "Hint"))
		end,
	},

	-- Column headers
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(-overlayW / 2 + labelColX, -overlayH / 2 + rowStartY - 10)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):zoom(0.35):diffuse(dimText):settext(THEME:GetString("Filters", "SkillsetColumn"))
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):x(minColX):zoom(0.35):diffuse(dimText):settext(THEME:GetString("Filters", "MinColumn"))
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):x(maxColX):zoom(0.35):diffuse(dimText):settext(THEME:GetString("Filters", "MaxColumn"))
			end,
		},
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW / 2 + 12, -overlayH / 2 + rowStartY - 4)
				:zoomto(overlayW - 24, 1):diffuse(color("0.12,0.12,0.12,1"))
		end,
	},
}

-- Helper: create a clickable filter input box for row i
local function CreateFilterInputBox(i)
	local label = ""
	if i <= #ms.SkillSets then
		label = ms.SkillSetsTranslated[i] or ms.SkillSets[i]
	elseif i == #ms.SkillSets + 1 then
		label = THEME:GetString("Filters", "LengthLabel")
	else
		label = THEME:GetString("Filters", "BestPercentLabel")
	end

	local rowY = -overlayH / 2 + rowStartY + (i - 1) * spacingY

	local row = Def.ActorFrame {
		Name = "FilterRow_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW / 2 + labelColX, rowY)
		end,

		-- Row label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0.5):y(spacingY / 2):zoom(0.38):diffuse(mainText):settext(label)
			end,
		},

		----------- LOWER BOUND (MIN) -----------
		-- Clickable background quad
		UIElements.QuadButton(1, 1) .. {
			Name = "LowerBg",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(minColX):y(spacingY / 2):zoomto(cellW, cellH)
			end,
			SetCommand = function(self)
				if ActiveSS == i and activebound == 0 then
					self:diffuse(color("#666666"))
				else
					self:diffuse(color("#000000"))
				end
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and active then
					ActiveSS = i
					activebound = 0
					MESSAGEMAN:Broadcast("HV_NumericInputActive")
					SCREENMAN:set_input_redirected(PLAYER_1, true)
				end
			end,
			MouseOverCommand = function(self)
				if ActiveSS ~= i or activebound ~= 0 then
					self:diffusealpha(hoverAlpha)
				end
			end,
			MouseOutCommand = function(self)
				self:diffusealpha(1)
			end,
			HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
			HV_NumericInputEndedMessageCommand = function(self) self:playcommand("Set") end,
			HV_NumericInputActiveMessageCommand = function(self) self:playcommand("Set") end,
		},

		-- Lower bound value text
		LoadFont("Common Normal") .. {
			Name = "LowerVal",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(minColX):y(spacingY / 2):zoom(0.38):maxwidth(cellW / 0.38 - 4)
			end,
			SetCommand = function(self)
				local fval = notShit.round(FILTERMAN:GetSSFilter(i, 0), numbersafterthedecimal)
				local fmtstr
				if i == #ms.SkillSets + 2 then
					if numbersafterthedecimal > 0 then
						fmtstr = "%5." .. numbersafterthedecimal .. "f"
					else
						fmtstr = "%02d."
					end
				else
					fmtstr = "%d"
				end
				self:settextf(fmtstr, fval)
				if fval <= 0 and ActiveSS ~= i then
					self:diffuse(dimText)
				else
					self:diffuse(brightText)
				end
			end,
			HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
			HV_NumericInputActiveMessageCommand = function(self) self:playcommand("Set") end,
			HV_NumericInputEndedMessageCommand = function(self) self:playcommand("Set") end,
		},

		----------- UPPER BOUND (MAX) -----------
		UIElements.QuadButton(1, 1) .. {
			Name = "UpperBg",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(maxColX):y(spacingY / 2):zoomto(cellW, cellH)
			end,
			SetCommand = function(self)
				if ActiveSS == i and activebound == 1 then
					self:diffuse(color("#666666"))
				else
					self:diffuse(color("#000000"))
				end
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and active then
					ActiveSS = i
					activebound = 1
					MESSAGEMAN:Broadcast("HV_NumericInputActive")
					SCREENMAN:set_input_redirected(PLAYER_1, true)
				end
			end,
			MouseOverCommand = function(self)
				if ActiveSS ~= i or activebound ~= 1 then
					self:diffusealpha(hoverAlpha)
				end
			end,
			MouseOutCommand = function(self)
				self:diffusealpha(1)
			end,
			HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
			HV_NumericInputEndedMessageCommand = function(self) self:playcommand("Set") end,
			HV_NumericInputActiveMessageCommand = function(self) self:playcommand("Set") end,
		},

		-- Upper bound value text
		LoadFont("Common Normal") .. {
			Name = "UpperVal",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(maxColX):y(spacingY / 2):zoom(0.38):maxwidth(cellW / 0.38 - 4)
			end,
			SetCommand = function(self)
				local fval = notShit.round(FILTERMAN:GetSSFilter(i, 1), numbersafterthedecimal)
				local fmtstr
				if i == #ms.SkillSets + 2 then
					if numbersafterthedecimal > 0 then
						fmtstr = "%5." .. numbersafterthedecimal .. "f"
					else
						fmtstr = "%02d."
					end
				else
					fmtstr = "%d"
				end
				self:settextf(fmtstr, fval)
				if fval <= 0 and ActiveSS ~= i then
					self:diffuse(dimText)
				else
					self:diffuse(brightText)
				end
			end,
			HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
			HV_NumericInputActiveMessageCommand = function(self) self:playcommand("Set") end,
			HV_NumericInputEndedMessageCommand = function(self) self:playcommand("Set") end,
		},
	}

	return row
end

-- Add all filter rows
for i = 1, totalRows do
	t[#t + 1] = CreateFilterInputBox(i)
end

-- Controls section (below the rows)
local ctrlSpacing = 22
local controlsY = -overlayH / 2 + rowStartY + totalRows * spacingY + 8

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + 12, controlsY - 4)
			:zoomto(overlayW - 24, 1):diffuse(color("0.12,0.12,0.12,1"))
	end,
}

-- Max Rate (left-click +, right-click -)
t[#t + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + labelColX, controlsY + 6):zoom(textzoom)
			:diffuse(accentColor)
	end,
	SetCommand = function(self)
		self:settextf(THEME:GetString("Filters", "MaxRateFormatted"), FILTERMAN:GetMaxFilterRate())
	end,
	HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
	HV_ResetFilterMessageCommand = function(self) self:playcommand("Set") end,
	MouseOverCommand = function(self) self:diffusealpha(hoverAlpha) end,
	MouseOutCommand = function(self) self:diffusealpha(1) end,
}
t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + labelColX, controlsY + 6)
			:zoomto(140, spacingY - 2):diffusealpha(0)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" and active then
			FILTERMAN:SetMaxFilterRate(FILTERMAN:GetMaxFilterRate() + 0.1)
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			if whee then whee:SongSearch("") end
		elseif params.event == "DeviceButton_right mouse button" and active then
			FILTERMAN:SetMaxFilterRate(FILTERMAN:GetMaxFilterRate() - 0.1)
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			if whee then whee:SongSearch("") end
		end
	end,
}

-- Min Rate (left-click +, right-click -)
t[#t + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + labelColX, controlsY + 6 + ctrlSpacing):zoom(textzoom)
			:diffuse(accentColor)
	end,
	SetCommand = function(self)
		self:settextf(THEME:GetString("Filters", "MinRateFormatted"), FILTERMAN:GetMinFilterRate())
	end,
	HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
	HV_ResetFilterMessageCommand = function(self) self:playcommand("Set") end,
	MouseOverCommand = function(self) self:diffusealpha(hoverAlpha) end,
	MouseOutCommand = function(self) self:diffusealpha(1) end,
}
t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + labelColX, controlsY + 6 + ctrlSpacing)
			:zoomto(140, ctrlSpacing - 2):diffusealpha(0)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" and active then
			FILTERMAN:SetMinFilterRate(FILTERMAN:GetMinFilterRate() + 0.1)
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			if whee then whee:SongSearch("") end
		elseif params.event == "DeviceButton_right mouse button" and active then
			FILTERMAN:SetMinFilterRate(FILTERMAN:GetMinFilterRate() - 0.1)
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			if whee then whee:SongSearch("") end
		end
	end,
}

-- Right-side controls (anchored to right half of overlay)
local rightColX = overlayW / 2 - 220

-- Mode toggle (AND / OR)
t[#t + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + rightColX, controlsY + 6):zoom(textzoom)
			:diffuse(accentColor)
	end,
	SetCommand = function(self)
		if FILTERMAN:GetFilterMode() then
			self:settext(THEME:GetString("Filters", "ModeAND"))
		else
			self:settext(THEME:GetString("Filters", "ModeOR"))
		end
	end,
	HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
	HV_FilterModeChangedMessageCommand = function(self) self:playcommand("Set") end,
	HV_ResetFilterMessageCommand = function(self) self:playcommand("Set") end,
	MouseOverCommand = function(self) self:diffusealpha(hoverAlpha) end,
	MouseOutCommand = function(self) self:diffusealpha(1) end,
}
t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + rightColX, controlsY + 6)
			:zoomto(120, spacingY - 2):diffusealpha(0)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" and active then
			FILTERMAN:ToggleFilterMode()
			MESSAGEMAN:Broadcast("HV_FilterModeChanged")
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			if whee then whee:SongSearch("") end
		end
	end,
}

-- Highest Skillsets Only toggle (greyed when AND mode)
t[#t + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + rightColX, controlsY + 6 + ctrlSpacing):zoom(textzoom)
			:maxwidth((overlayW / 2 - 40) / textzoom)
	end,
	SetCommand = function(self)
		local onoff = FILTERMAN:GetHighestSkillsetsOnly() and THEME:GetString("Filters", "On") or THEME:GetString("Filters", "Off")
		self:settextf(THEME:GetString("Filters", "HighestSSOnly"), onoff)
		if FILTERMAN:GetFilterMode() then
			self:diffuse(color("1,1,1,0.2"))
		else
			self:diffuse(accentColor)
		end
	end,
	HV_FilterModeChangedMessageCommand = function(self) self:playcommand("Set") end,
	HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
	HV_ResetFilterMessageCommand = function(self) self:playcommand("Set") end,
	MouseOverCommand = function(self)
		if not FILTERMAN:GetFilterMode() then
			self:diffusealpha(hoverAlpha)
		end
	end,
	MouseOutCommand = function(self)
		if FILTERMAN:GetFilterMode() then
			self:diffusealpha(0.2)
		else
			self:diffusealpha(1)
		end
	end,
}
t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + rightColX, controlsY + 6 + ctrlSpacing)
			:zoomto(180, ctrlSpacing - 2):diffusealpha(0)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" and active and not FILTERMAN:GetFilterMode() then
			FILTERMAN:ToggleHighestSkillsetsOnly()
			MESSAGEMAN:Broadcast("HV_FilterModeChanged")
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			if whee then whee:SongSearch("") end
		end
	end,
}

-- Highest Difficulty Only toggle (greyed when AND mode)
t[#t + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + rightColX, controlsY + 6 + ctrlSpacing * 2):zoom(textzoom)
			:maxwidth((overlayW / 2 - 40) / textzoom)
	end,
	SetCommand = function(self)
		local onoff = FILTERMAN:GetHighestDifficultyOnly() and THEME:GetString("Filters", "On") or THEME:GetString("Filters", "Off")
		self:settextf(THEME:GetString("Filters", "HighestDiffOnly"), onoff)
		if FILTERMAN:GetFilterMode() then
			self:diffuse(color("1,1,1,0.2"))
		else
			self:diffuse(accentColor)
		end
	end,
	HV_FilterModeChangedMessageCommand = function(self) self:playcommand("Set") end,
	HV_FilterUpdatedMessageCommand = function(self) self:playcommand("Set") end,
	HV_ResetFilterMessageCommand = function(self) self:playcommand("Set") end,
	MouseOverCommand = function(self)
		if not FILTERMAN:GetFilterMode() then
			self:diffusealpha(hoverAlpha)
		end
	end,
	MouseOutCommand = function(self)
		if FILTERMAN:GetFilterMode() then
			self:diffusealpha(0.2)
		else
			self:diffusealpha(1)
		end
	end,
}
t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + rightColX, controlsY + 6 + ctrlSpacing * 2)
			:zoomto(180, ctrlSpacing - 2):diffusealpha(0)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" and active and not FILTERMAN:GetFilterMode() then
			FILTERMAN:ToggleHighestDifficultyOnly()
			MESSAGEMAN:Broadcast("HV_FilterModeChanged")
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			if whee then whee:SongSearch("") end
		end
	end,
}

-- Filter match count
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "FilterResults",
	InitCommand = function(self)
		self:halign(0):valign(0):xy(-overlayW / 2 + rightColX, controlsY + 6 + ctrlSpacing * 3):zoom(textzoom)
			:diffuse(subText):settext("")
	end,
	FilterResultsMessageCommand = function(self, msg)
		if msg then
			self:settextf(THEME:GetString("Filters", "MatchesFormatted"), msg.Matches or 0, msg.Total or 0)
		end
	end,
}

-- Bottom action bar
local bottomY = overlayH / 2 - 28

-- Reset button
t[#t + 1] = UIElements.TextButton(1, 1, "Common Normal") .. {
	InitCommand = function(self)
		self:xy(overlayW / 2 - 80, bottomY)
		local txt = self:GetChild("Text")
		local bg = self:GetChild("BG")
		txt:zoom(0.38):settext(THEME:GetString("Filters", "ResetAll")):diffuse(color("1,0.4,0.4,1"))
		bg:zoomto(110, 22):diffuse(color("0.15,0,0,0.8"))
	end,
	RolloverUpdateCommand = function(self, params)
		if params.update == "in" then
			self:diffusealpha(hoverAlpha)
		else
			self:diffusealpha(1)
		end
	end,
	ClickCommand = function(self, params)
		if params.update ~= "OnMouseDown" then return end
		if params.event == "DeviceButton_left mouse button" and active then
			FILTERMAN:ResetAllFilters()
			for idx = 1, totalRows do
				SSQuery[0][idx] = "0"
				SSQuery[1][idx] = "0"
			end
			numbersafterthedecimal = 0
			activebound = 0
			ActiveSS = 0
			MESSAGEMAN:Broadcast("HV_FilterUpdated")
			MESSAGEMAN:Broadcast("HV_ResetFilter")
			MESSAGEMAN:Broadcast("HV_NumericInputEnded")
			MESSAGEMAN:Broadcast("HV_FilterModeChanged")
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			if whee then whee:SongSearch("") end
		end
	end,
}

-- Input callback handler
local function SharedInputHandler(event)
	if not filtersActor or not filtersActor:GetVisible() then return false end
	if not event or not event.DeviceInput then return false end

	local top = SCREENMAN:GetTopScreen()
	if not top or top:GetName() ~= "ScreenSelectMusic" then return false end

	-- If numeric input is active, delegate to FilterInput
	if ActiveSS > 0 then
		FilterInput(event)
		return true
	end

	if event.type ~= "InputEventType_FirstPress" then return false end
	local btn = event.DeviceInput.button

	-- Click outside the overlay to close it
	if btn == "DeviceButton_left mouse button" then
		if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
			ActiveSS = 0
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
			return true
		end
	end

	-- Escape/Back closes the overlay
	if event.button == "Back" or btn == "DeviceButton_escape" then
		ActiveSS = 0
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
		return true
	end

	return false
end

-- Register input callback
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		if HV.FiltersInputCallback then
			pcall(function() screen:RemoveInputCallback(HV.FiltersInputCallback) end)
		end
		HV.FiltersInputCallback = function(event) return SharedInputHandler(event) end
		screen:AddInputCallback(HV.FiltersInputCallback)
	end,
}

return t
