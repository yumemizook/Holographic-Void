--- Holographic Void: Search Overlay
-- Uses the C++ native whee:SongSearch() for instant, lag-free filtering
-- Input blocking via set_input_redirected prevents Enter from leaking

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

-- Search state
local searchActive = false
local searchString = ""
local searchActor = nil
local whee = nil
local inputCallbackRegistered = false

local overlayW = 680
local overlayH = 150

-- Update the search display text
local function UpdateDisplay()
	if not searchActor then return end
	local queryText = searchActor:GetChild("QueryText")
	local cursorText = searchActor:GetChild("Cursor")
	local hintText = searchActor:GetChild("HintText")

	if queryText then
		if searchString == "" then
			queryText:settext("Type to search..."):diffuse(dimText)
		else
			queryText:settext(searchString):diffuse(brightText)
		end
	end

	if cursorText then
		cursorText:visible(searchActive)
		if searchActive and queryText then
			local textW = queryText:GetZoomedWidth()
			-- Offset adjusted: +10px from original +2px = +12px
			cursorText:x(-overlayW / 2 + 32 + textW + 12)
		end
	end

	if hintText then
		if searchActive then
			hintText:settext("ENTER  apply  ·  ESC  clear & close  ·  BACKSPACE  delete  ·  DEL  clear all")
		else
			hintText:settext("Search applied. Click search bar or Ctrl+4 to edit.")
		end
	end

	-- Sync the header search bar text
	MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString})
end

-- Activate search mode
local function ActivateSearch()
	searchActive = true
	local screen = SCREENMAN:GetTopScreen()
	if screen and screen.GetMusicWheel then
		whee = screen:GetMusicWheel()
	end
	UpdateDisplay()
end

-- Deactivate search mode
local function DeactivateSearch(clearFilter)
	searchActive = false
	if clearFilter then
		searchString = ""
		-- Clear search via C++ API
		if whee then
			whee:SongSearch("")
		end
	end
	UpdateDisplay()
end

-- Input callback for search mode
local function SearchInputCallback(event)
	if not searchActive then return false end
	if not event or not event.DeviceInput then return true end

	local btn = event.DeviceInput.button or ""
	local evType = event.type or ""

	-- Only process FirstPress and Repeat
	if evType == "InputEventType_Release" then return true end

	-- Enter: Apply search and close overlay (keep filter)
	if event.button == "Start" or btn == "DeviceButton_enter" or btn == "DeviceButton_KP enter" then
		-- Apply final search via C++ API if not already done
		if whee then whee:SongSearch(searchString) end
		if searchActor then searchActor:queuecommand("CloseFromInput") end
		return true
	end

	-- Escape: Clear filter and close
	if event.button == "Back" or btn == "DeviceButton_escape" then
		if searchActor then searchActor:playcommand("ClearFilter") end
		if searchActor then searchActor:queuecommand("CloseFromInput") end
		return true
	end

	-- Backspace: Delete last character
	if btn == "DeviceButton_backspace" then
		if #searchString > 0 then
			searchString = searchString:sub(1, -2)
			-- Instant search via C++ API
			if whee then whee:SongSearch(searchString) end
			UpdateDisplay()
		end
		return true
	end

	-- Delete: Clear entire search
	if btn == "DeviceButton_delete" then
		searchString = ""
		if whee then whee:SongSearch("") end
		UpdateDisplay()
		return true
	end

	-- Ctrl+V: Paste
	if btn == "DeviceButton_v" and INPUTFILTER:IsControlPressed() then
		if Arch and Arch.getClipboard then
			local clip = Arch.getClipboard()
			if clip then
				searchString = searchString .. clip
				if whee then whee:SongSearch(searchString) end
				UpdateDisplay()
			end
		end
		return true
	end

	-- Use event.char (the C++ provided character) for a cleaner approach
	if event.char and event.char:match('[%%%+%-%!%@%#%$%^%&%*%(%)%=%_%.%,%:%;%\'%"%>%<%?%/%~%|%w%[%]%{%}%`%\\]') then
		-- Skip number keys when not holding Ctrl (they map to tab indices in some themes)
		-- but we want them for search
		searchString = searchString .. event.char
		-- Instant search via C++ API
		if whee then whee:SongSearch(searchString) end
		UpdateDisplay()
		return true
	end

	-- Space key
	if btn == "DeviceButton_space" then
		searchString = searchString .. " "
		if whee then whee:SongSearch(searchString) end
		UpdateDisplay()
		return true
	end

	-- Consume all other input to prevent leaking
	return true
end

-- ============================================================
-- SEARCH OVERLAY ACTOR
-- ============================================================

local t = Def.ActorFrame {
	Name = "SearchOverlay",
	InitCommand = function(self)
		searchActor = self
		self:xy(SCREEN_CENTER_X, 70):visible(false)
		-- Sync header on load
		MESSAGEMAN:Broadcast("SearchQueryUpdated", {query = searchString})
	end,

	CloseFromInputGeneralCommand = function(self)
		DeactivateSearch(false)
		MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
	end,
	CloseFromInputCommand = function(self)
		self:sleep(0.02):queuecommand("CloseFromInputGeneral")
	end,
	ClearFilterCommand = function(self)
		searchString = ""
		if whee then whee:SongSearch("") end
		UpdateDisplay()
	end,

	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "SEARCH" then
			local wasVisible = self:GetVisible()
			if wasVisible and searchActive then
				-- Toggle off: close search
				DeactivateSearch(true)
				self:visible(false)
				HV.ActiveTab = ""
			else
				self:visible(true)
				ActivateSearch()
				HV.ActiveTab = "SEARCH"
			end
		else
			if searchActive then DeactivateSearch(false) end
			self:visible(false)
		end
	end,

	BeginCommand = function(self)
		if not inputCallbackRegistered then
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				whee = screen:GetMusicWheel()
				screen:AddInputCallback(SearchInputCallback)
				inputCallbackRegistered = true
			end
		end
	end,

	EndCommand = function(self)
		if searchActive then DeactivateSearch(true) end
	end,

	-- Dark background card
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(overlayW, overlayH):diffuse(color("0.04,0.04,0.04,0.97"))
		end,
	},
	-- Top accent border
	Def.Quad {
		InitCommand = function(self)
			self:valign(0):y(-overlayH / 2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7)
		end,
	},
	-- Bottom accent border
	Def.Quad {
		InitCommand = function(self)
			self:valign(1):y(overlayH / 2):zoomto(overlayW, 1):diffuse(accentColor):diffusealpha(0.3)
		end,
	},

	-- SEARCH label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW / 2 + 25, -overlayH / 2 + 15):zoom(0.5):diffuse(accentColor):settext("SEARCH")
		end,
	},

	-- Input background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW / 2 + 25, -overlayH / 2 + 35)
				:zoomto(overlayW - 50, 48):diffuse(color("0.08,0.08,0.08,1"))
		end,
	},
	-- Input accent border (left)
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW / 2 + 25, -overlayH / 2 + 35)
				:zoomto(2, 48):diffuse(accentColor):diffusealpha(0.5)
		end,
	},

	-- Query text
	LoadFont("Common Normal") .. {
		Name = "QueryText",
		InitCommand = function(self)
			self:halign(0):valign(0.5):xy(-overlayW / 2 + 25 + 15, -overlayH / 2 + 65)
				:zoom(0.55):diffuse(dimText):settext("Type to search...")
				:maxwidth((overlayW - 100) / 0.55)
		end,
	},

	-- Blinking cursor
	LoadFont("Common Normal") .. {
		Name = "Cursor",
		InitCommand = function(self)
			self:halign(0):valign(0.5):xy(-overlayW / 2 + 25 + 15, -overlayH / 2 + 65)
				:zoom(0.55):diffuse(accentColor):settext("|"):visible(false)
		end,
		OnCommand = function(self) self:queuecommand("Blink") end,
		BlinkCommand = function(self)
			self:diffusealpha(1):sleep(0.5):diffusealpha(0):sleep(0.3):queuecommand("Blink")
		end,
	},

	-- Hint text
	LoadFont("Common Normal") .. {
		Name = "HintText",
		InitCommand = function(self)
			self:halign(0.5):valign(1):xy(0, overlayH / 2 - 12):zoom(0.32):diffuse(dimText)
				:settext("ENTER  apply  ·  ESC  clear & close  ·  BACKSPACE  delete  ·  DEL  clear all")
		end,
	},
}

return t
