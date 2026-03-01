--- Holographic Void: Playlists Tab
-- Uses SONGMAN:GetPlaylists() with Til Death-matching chart APIs
-- Supports drill-down into individual playlists, chart deletion, song selection

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.04,0.04,0.04,0.97")

local overlayW = 680
local overlayH = 400
local rowH = 34
local chartsPerPage = 8
local playlistsPerPage = 8
local playlistsActor = nil
local whee = nil

-- State
local allplaylists = {}
local singleplaylistactive = false
local allplaylistsactive = true
local currentPlaylistPage = 1
local currentChartPage = 1

-- Active playlist data
local pl = nil
local chartlist = {}

local function RefreshPlaylistList()
	allplaylists = {}
	local ok, playlists = pcall(function() return SONGMAN:GetPlaylists() end)
	if ok and playlists then
		for name, playlist in pairs(playlists) do
			allplaylists[#allplaylists + 1] = {name = name, playlist = playlist}
		end
		table.sort(allplaylists, function(a, b) return a.name < b.name end)
	end
end

local function RefreshChartList()
	chartlist = {}
	if pl then
		pcall(function()
			chartlist = pl:GetChartlist()
		end)
	end
end

local t = Def.ActorFrame {
	Name = "PlaylistsOverlay",
	InitCommand = function(self)
		playlistsActor = self
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen.GetMusicWheel then whee = screen:GetMusicWheel() end
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "PLAYLISTS" then
			self:visible(not self:GetVisible())
			if self:GetVisible() then
				HV.ActiveTab = "PLAYLISTS"
				singleplaylistactive = false
				allplaylistsactive = true
				currentPlaylistPage = 1
				currentChartPage = 1
				RefreshPlaylistList()
				self:playcommand("RefreshUI")
			else
				HV.ActiveTab = ""
			end
		else
			self:visible(false)
			if HV.ActiveTab == "PLAYLISTS" then HV.ActiveTab = "" end
		end
	end,

	-- Background
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard) end },
	Def.Quad { InitCommand = function(self) self:valign(0):y(-overlayH/2):zoomto(overlayW, 2):diffuse(accentColor):diffusealpha(0.7) end },

	-- Title
	LoadFont("Common Normal") .. {
		Name = "Title",
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-overlayW/2 + 16, -overlayH/2 + 10):zoom(0.35):diffuse(accentColor)
		end,
		RefreshUICommand = function(self)
			if singleplaylistactive and pl then
				self:settext("PLAYLIST: " .. pl:GetName())
			else
				self:settextf("PLAYLISTS (%d)", #allplaylists)
			end
		end,
	},

	-- Back button
	LoadFont("Common Normal") .. {
		Name = "BackBtn",
		InitCommand = function(self)
			self:halign(1):valign(0):xy(overlayW/2 - 16, -overlayH/2 + 10):zoom(0.26):diffuse(accentColor)
		end,
		RefreshUICommand = function(self)
			self:visible(singleplaylistactive)
			if singleplaylistactive then self:settext("< BACK") end
		end,
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self)
			self:halign(0.5):valign(1):xy(0, overlayH/2 - 8):zoom(0.22):diffuse(dimText)
		end,
		RefreshUICommand = function(self)
			local total, perPage, curPage
			if singleplaylistactive then
				total = #chartlist
				perPage = chartsPerPage
				curPage = currentChartPage
			else
				total = #allplaylists
				perPage = playlistsPerPage
				curPage = currentPlaylistPage
			end
			local totalPages = math.max(1, math.ceil(total / perPage))
			self:settextf("Page %d / %d · CLICK to select · SCROLL to page", curPage, totalPages)
		end,
	},
}

-- Rows for playlist list and chart entries
local rowStartY = -overlayH/2 + 40

for i = 1, math.max(chartsPerPage, playlistsPerPage) do
	t[#t + 1] = Def.ActorFrame {
		Name = "Row_" .. i,
		InitCommand = function(self)
			self:xy(-overlayW/2 + 16, rowStartY + (i - 1) * rowH)
		end,

		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(overlayW - 32, rowH - 2):diffuse(color("0,0,0,0.2"))
			end,
		},

		-- Main text line
		LoadFont("Zpix Normal") .. {
			Name = "MainText",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(15, rowH/2):zoom(0.5):diffuse(brightText):maxwidth((overlayW - 250) / 0.5)
			end,
		},

		-- Sub text (right side)
		LoadFont("Common Normal") .. {
			Name = "SubText",
			InitCommand = function(self)
				self:halign(1):valign(0.5):x(overlayW - 120):y(rowH/2):zoom(0.4):diffuse(subText)
			end,
		},

		-- Rate display
		LoadFont("Common Normal") .. {
			Name = "RateText",
			InitCommand = function(self)
				self:halign(1):valign(0.5):x(overlayW - 60):y(rowH/2):zoom(0.4):diffuse(dimText)
			end,
		},

		-- Delete button (only for chart view)
		LoadFont("Common Normal") .. {
			Name = "DelBtn",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):x(overlayW - 60):y(rowH/2):zoom(0.4):diffuse(color("1,0.3,0.3,0.6")):settext("✕")
			end,
		},

		RefreshUICommand = function(self)
			if singleplaylistactive then
				-- Chart entries
				local idx = (currentChartPage - 1) * chartsPerPage + i
				if idx <= #chartlist then
					self:visible(true)
					local entry = chartlist[idx]
					local songTitle = entry:GetSongTitle() or "???"
					self:GetChild("MainText"):settext(songTitle)

					-- Check if song exists
					local song = SONGMAN:GetSongByChartKey(entry:GetChartkey())
					if song then
						self:GetChild("MainText"):diffuse(brightText)
					else
						self:GetChild("MainText"):diffuse(color("1,0.3,0.3,1"))
					end

					self:GetChild("RateText"):settextf("%.2fx", entry:GetRate()):visible(true)

					-- Show personal best if available
					local pb = ""
					pcall(function()
						local best = SCOREMAN:GetScoresByKey(entry:GetChartkey())
						if best then
							for _, sl in pairs(best) do
								local scores = sl:GetScores()
								if scores and #scores > 0 then
									pb = string.format("%.2f%%", scores[1]:GetWifeScore() * 100)
									break
								end
							end
						end
					end)
					self:GetChild("SubText"):settext(pb):visible(true)
					self:GetChild("DelBtn"):visible(true)
				else
					self:visible(false)
				end
			else
				-- Playlist list
				local idx = (currentPlaylistPage - 1) * playlistsPerPage + i
				if idx <= #allplaylists then
					self:visible(true)
					local plEntry = allplaylists[idx]
					self:GetChild("MainText"):settext(plEntry.name):diffuse(brightText)
					local ct = 0
					pcall(function() ct = plEntry.playlist:GetNumCharts() end)
					self:GetChild("SubText"):settextf("%d charts", ct):visible(true)
					self:GetChild("RateText"):settext(""):visible(false)
					self:GetChild("DelBtn"):visible(false)
				else
					self:visible(false)
				end
			end
		end,
	}
end

-- Input handler
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
			screen:AddInputCallback(function(event)
				if not playlistsActor or not playlistsActor:GetVisible() then return false end
				if not event or not event.DeviceInput then return false end
				
				if event.type ~= "InputEventType_FirstPress" then return true end
				local btn = event.DeviceInput.button

				-- Pagination
				local dir = 0
				if btn == "DeviceButton_mousewheel down" or btn == "DeviceButton_down" then dir = 1 end
				if btn == "DeviceButton_mousewheel up" or btn == "DeviceButton_up" then dir = -1 end
				if dir ~= 0 then
					if singleplaylistactive then
						local totalPages = math.max(1, math.ceil(#chartlist / chartsPerPage))
						currentChartPage = math.max(1, math.min(totalPages, currentChartPage + dir))
					else
						local totalPages = math.max(1, math.ceil(#allplaylists / playlistsPerPage))
						currentPlaylistPage = math.max(1, math.min(totalPages, currentPlaylistPage + dir))
					end
					playlistsActor:playcommand("RefreshUI")
					return true
				end

				if btn == "DeviceButton_left mouse button" then
					local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

					-- Close on outside click
					if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						return true
					end

					-- Back button
					if singleplaylistactive then
						local backX = SCREEN_CENTER_X + overlayW/2 - 40
						local backY = SCREEN_CENTER_Y - overlayH/2 + 18
						if mx >= backX - 30 and mx <= backX + 30 and my >= backY - 10 and my <= backY + 10 then
							singleplaylistactive = false
							allplaylistsactive = true
							currentPlaylistPage = 1
							playlistsActor:playcommand("RefreshUI")
							return true
						end
					end

					-- Row clicks
					local perPage = singleplaylistactive and chartsPerPage or playlistsPerPage
					for ri = 1, perPage do
						local rowTop = SCREEN_CENTER_Y + rowStartY + (ri - 1) * rowH
						local rowLeft = SCREEN_CENTER_X - overlayW/2 + 16
						if mx >= rowLeft and mx <= rowLeft + overlayW - 32 and my >= rowTop and my <= rowTop + rowH then
							if singleplaylistactive then
								local idx = (currentChartPage - 1) * chartsPerPage + ri
								if idx <= #chartlist then
									local entry = chartlist[idx]
									local hx = mx - rowLeft

									-- Delete button
									if hx >= overlayW - 60 then
										pcall(function()
											pl:DeleteChart(idx)
										end)
										RefreshChartList()
										playlistsActor:playcommand("RefreshUI")
										return true
									end

									-- Song select
									local ck = entry:GetChartkey()
									if ck then
										local song = SONGMAN:GetSongByChartKey(ck)
										if song and whee then
											whee:SelectSong(song)
										end
									end
									MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
								end
							else
								local idx = (currentPlaylistPage - 1) * playlistsPerPage + ri
								if idx <= #allplaylists then
									pl = allplaylists[idx].playlist
									singleplaylistactive = true
									allplaylistsactive = false
									currentChartPage = 1
									RefreshChartList()
									playlistsActor:playcommand("RefreshUI")
								end
							end
							return true
						end
					end
					
					return true -- Sink all other clicks inside the overlay
				end

				if event.button == "Back" then
					if singleplaylistactive then
						singleplaylistactive = false
						allplaylistsactive = true
						playlistsActor:playcommand("RefreshUI")
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
