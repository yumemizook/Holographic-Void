--- Holographic Void: Tags Tab
-- Uses TAGMAN (tags.lua) to match other themes (Til Death, Rebirth)
-- Allows adding/removing personal tags to charts for better organization

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
local tagsActor = nil

-- Data
local allTags = {} -- List of unique tag names
local songTags = {} -- Tags for current song
local currentChartkey = ""

-- ============================================================
-- DATA FETCHING
-- ============================================================

local function RefreshData()
	local steps = GAMESTATE:GetCurrentSteps()
	currentChartkey = steps and steps:GetChartKey() or ""
	
	-- Get all unique tags from TAGMAN
	allTags = {}
	local tagData = TAGMAN:get_data().playerTags
	for tagName, charts in pairs(tagData) do
		allTags[#allTags+1] = tagName
	end
	table.sort(allTags)
	
	-- Identify which tags the current song has
	songTags = {}
	if currentChartkey ~= "" then
		for tagName, charts in pairs(tagData) do
			if charts[currentChartkey] then
				songTags[tagName] = true
			end
		end
	end
end

-- ============================================================
-- ACTIONS
-- ============================================================

local function ToggleTag(tagName)
	if currentChartkey == "" then return end
	local tagData = TAGMAN:get_data().playerTags
	
	if not tagData[tagName] then tagData[tagName] = {} end
	
	if tagData[tagName][currentChartkey] then
		tagData[tagName][currentChartkey] = nil
	else
		tagData[tagName][currentChartkey] = 1
	end
	
	TAGMAN:set_dirty()
	TAGMAN:save()
	RefreshData()
	if tagsActor then tagsActor:playcommand("RefreshTags") end
end

local function AddNewTag()
	easyInputStringOKCancel(
		THEME:GetString("Tags", "NewTagPrompt"), 32, false,
		function(name)
			if name and name ~= "" then
				local tagData = TAGMAN:get_data().playerTags
				if not tagData[name] then
					tagData[name] = {}
					TAGMAN:set_dirty()
					TAGMAN:save()
					RefreshData()
					if tagsActor then tagsActor:playcommand("RefreshTags") end
				end
			end
		end,
		nil
	)
end

local function DeleteTag(tagName)
	local tagData = TAGMAN:get_data().playerTags
	tagData[tagName] = nil
	TAGMAN:set_dirty()
	TAGMAN:save()
	RefreshData()
	if tagsActor then tagsActor:playcommand("RefreshTags") end
end

-- ============================================================
-- UI
-- ============================================================

local t = Def.ActorFrame {
	Name = "TagsOverlay",
	InitCommand = function(self)
		tagsActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "TAGS" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				HV.ActiveTab = "TAGS"
				currentPage = 1
				RefreshData()
				self:playcommand("RefreshTags")
			else
				HV.ActiveTab = ""
			end
		else
			self:visible(false)
			if HV.ActiveTab == "TAGS" then HV.ActiveTab = "" end
		end
	end,
	CurrentStepsChangedMessageCommand = function(self)
		if self:GetVisible() then
			RefreshData()
			self:playcommand("RefreshTags")
		end
	end,

	-- Background
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard) end },
	Def.Quad { InitCommand = function(self) self:valign(0):y(-overlayH/2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7) end },

	-- Title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 20, -overlayH/2 + 15):zoom(0.5):diffuse(accentColor):settext(THEME:GetString("Tags", "Title"))
		end,
	},

	-- Add Tag Button
	Def.ActorFrame {
		InitCommand = function(self) self:xy(overlayW/2 - 60, -overlayH/2 + 20) end,
		Def.Quad {
			Name = "AddBtnBg",
			InitCommand = function(self) self:zoomto(90, 20):diffuse(accentColor):diffusealpha(0.15) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(brightText):settext(THEME:GetString("Tags", "AddTag")) end,
		},
	},

	-- Page Info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:halign(1):valign(0):xy(overlayW/2 - 16, -overlayH/2 + 38):zoom(0.22):diffuse(dimText)
		end,
	},

	-- Hint
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):valign(1):xy(0, overlayH/2 - 12):zoom(0.28):diffuse(dimText)
				:settext(THEME:GetString("Tags", "Hint"))
		end,
	},
}

-- Tag rows
local rowsStartY = -overlayH/2 + 60
for i = 1, pageSize do
	t[#t + 1] = Def.ActorFrame {
		Name = "TagRow_" .. i,
		InitCommand = function(self)
			self:xy(0, rowsStartY + (i-1) * rowH)
		end,

		Def.Quad { 
			Name = "Bg", 
			InitCommand = function(self) self:zoomto(overlayW - 32, rowH - 4):diffuse(color("0,0,0,0.3")) end,
		},
		-- Toggle marker (Dot)
		Def.Quad {
			Name = "Marker",
			InitCommand = function(self) self:x(-overlayW/2 + 30):zoomto(4, 4) end,
		},
		LoadFont("Common Normal") .. { 
			Name = "TagName", 
			InitCommand = function(self) self:halign(0):x(-overlayW/2 + 60):zoom(0.45) end 
		},
		
		RefreshTagsCommand = function(self)
			local idx = (currentPage - 1) * pageSize + i
			if idx <= #allTags then
				self:visible(true)
				local name = allTags[idx]
				self:GetChild("TagName"):settext(name):diffuse(songTags[name] and brightText or subText)
				self:GetChild("Marker"):diffuse(songTags[name] and accentColor or color("0.1,0.1,0.1,1"))
				self:GetChild("Bg"):diffusealpha(songTags[name] and 0.4 or 0.2)
			else
				self:visible(false)
			end
		end,
	}
end

-- Update function on main frame
t.RefreshTagsCommand = function(self)
	local totalPages = math.max(1, math.ceil(#allTags / pageSize))
	currentPage = math.min(currentPage, totalPages)
	
	local pageInfo = self:GetChild("PageInfo")
	if pageInfo then
		pageInfo:settextf(THEME:GetString("Tags", "PageInfoFormatted"), #allTags, currentPage, totalPages)
	end
	
	for i = 1, pageSize do
		local row = self:GetChild("TagRow_" .. i)
		if row then row:playcommand("RefreshTags") end
	end
end

-- Input handler
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if not tagsActor or not tagsActor:GetVisible() then return false end
			if not event or not event.DeviceInput then return false end
			if event.type ~= "InputEventType_FirstPress" then return false end
			local btn = event.DeviceInput.button

			-- 1. Pagination
			local dir = 0
			if btn == "DeviceButton_mousewheel down" or btn == "DeviceButton_right" or btn == "DeviceButton_down" then dir = 1 end
			if btn == "DeviceButton_mousewheel up" or btn == "DeviceButton_left" or btn == "DeviceButton_up" then dir = -1 end
			if dir ~= 0 then
				local totalPages = math.max(1, math.ceil(#allTags / pageSize))
				local newPage = math.max(1, math.min(totalPages, currentPage + dir))
				if newPage ~= currentPage then
					currentPage = newPage
					tagsActor:playcommand("RefreshTags")
				end
				return true
			end

			-- 2. Mouse Clicks
			if btn == "DeviceButton_left mouse button" or btn == "DeviceButton_right mouse button" then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

				-- Close on outside click
				if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
					MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
					return true
				end

				-- New Tag button
				if btn == "DeviceButton_left mouse button" and IsMouseOverCentered(SCREEN_CENTER_X + overlayW/2 - 60, SCREEN_CENTER_Y - overlayH/2 + 20, 90, 20) then
					AddNewTag()
					return true
				end

				-- Row clicks
				for i = 1, pageSize do
					local rowY = SCREEN_CENTER_Y + rowsStartY + (i-1) * rowH
					if IsMouseOverCentered(SCREEN_CENTER_X, rowY, overlayW - 32, rowH - 4) then
						local idx = (currentPage - 1) * pageSize + i
						if idx <= #allTags then
							if btn == "DeviceButton_left mouse button" then
								ToggleTag(allTags[idx])
							else
								DeleteTag(allTags[idx])
							end
						end
						return true
					end
				end
				
				-- Sink all other clicks inside the overlay
				return true
			end

			if event.button == "Back" or event.DeviceInput.button == "DeviceButton_escape" then
				MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
				return true
			end

			-- Sink all input when overlay is visible
			return true
		end)
	end,
}

return t
