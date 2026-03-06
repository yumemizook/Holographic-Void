--- Holographic Void: ScreenPackDownloader Decorations
-- Full interactive pack browser with:
--   - Search by name (keyboard input)
--   - Paginated pack list via PackList API
--   - Downloaded pack detection via SONGMAN:DoesSongGroupExist()
--   - Download / queue management
--   - Average difficulty, song count, play count columns
--   - Real-time download progress
-- Keyboard navigable

local t = Def.ActorFrame {
	Name = "PackDownloaderUI"
}


local accentColor = HVColor.Accent
local installedColor = color("0.35,0.65,0.35,1")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local borderColor = color("0.18,0.18,0.18,1")
local rowHilight = color("0.12,0.12,0.12,0.9")
local rowNormal = color("0.04,0.04,0.04,0.5")
local rowAlt = color("0.06,0.06,0.06,0.5")
local rowInstalled = color("0.04,0.08,0.04,0.6")

-- ============================================================
-- STATE
-- ============================================================
local packList = PackList:new()
local nameInput = ""
local selectedRow = 1
local packsPerPage = 14
local currentPacks = {}
local installedFlags = {} -- cache installed status per row
local isSearching = false

-- Bundle Selector State
local availableBundles = {"All"}
local currentBundleIndex = 1
local isBundleListOpen = false

local function updateAvailableBundles()
	local alltags = DLMAN:GetPackTags()
	local bundles = alltags["pack_bundle"]
	availableBundles = {"All"}
	if bundles then
		for _, b in ipairs(bundles) do
			table.insert(availableBundles, b:sub(1,1):upper() .. b:sub(2))
		end
	end
end
updateAvailableBundles()

-- Check if a pack is installed locally (same as Til Death)
local function isPackInstalled(pack)
	if not pack then return false end
	return SONGMAN:DoesSongGroupExist(pack:GetName())
end

-- ============================================================
-- BACKGROUND
-- ============================================================
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(color("1,1,1,0.02"))
		end
	}
end

-- ============================================================
-- HEADER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Header",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, 20) end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.6):diffuse(brightText):settext("PACK DOWNLOADER")
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(14):zoomto(SCREEN_WIDTH * 0.92, 1):diffuse(borderColor)
		end
	}
}

-- ============================================================
-- SEARCH BAR
-- ============================================================
local searchBarY = 44
local searchBarW = SCREEN_WIDTH * 0.50

t[#t + 1] = Def.ActorFrame {
	Name = "SearchBar",
	InitCommand = function(self) self:xy(SCREEN_WIDTH * 0.28, searchBarY) end,

	Def.Sprite {
		Texture = THEME:GetPathG("", "search.png"),
		InitCommand = function(self)
			self:halign(1):x(-searchBarW / 2 - 8):zoom(0.35):diffuse(mainText)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(searchBarW, 20):diffuse(color("0.08,0.08,0.08,0.9"))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):x(-searchBarW / 2 + 6):zoom(0.28):diffuse(dimText)
			self:settext("SEARCH:")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SearchText",
		InitCommand = function(self)
			self:halign(0):x(-searchBarW / 2 + 55):zoom(0.32):diffuse(mainText)
		end,
		UpdateSearchCommand = function(self)
			if nameInput == "" then
				self:settext(isSearching and "Type to search..." or "Click to search...")
				self:diffuse(dimText)
			else
				self:settext(nameInput .. (isSearching and "_" or ""))
				self:diffuse(mainText)
			end
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(10):zoomto(searchBarW, 1):diffuse(accentColor):diffusealpha(0.2)
		end
	}
}

-- ============================================================
-- BUNDLE SELECTOR
-- ============================================================
local bundleBtnW = 100
local bundleBtnX = SCREEN_WIDTH * 0.28 + searchBarW / 2 + 10 + bundleBtnW / 2
local bundleListW = 140
local bundleItemH = 20

t[#t + 1] = Def.ActorFrame {
	Name = "BundleSelector",
	InitCommand = function(self) self:xy(bundleBtnX, searchBarY) end,

	-- Button background
	Def.Quad {
		Name = "BundleBtnBG",
		InitCommand = function(self)
			self:zoomto(bundleBtnW, 20):diffuse(color("0.12,0.12,0.12,0.9"))
		end,
		UpdateCommand = function(self)
			if isBundleListOpen then
				self:diffuse(accentColor):diffusealpha(0.4)
			else
				self:diffuse(color("0.12,0.12,0.12,0.9"))
			end
		end
	},
	LoadFont("Common Normal") .. {
		Name = "BundleLabel",
		InitCommand = function(self)
			self:zoom(0.26):diffuse(subText):settext("BUNDLE:")
			self:x(-bundleBtnW / 2 + 5):halign(0)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "CurrentBundleText",
		InitCommand = function(self)
			self:zoom(0.28):diffuse(brightText)
			self:x(-bundleBtnW / 2 + 45):halign(0)
		end,
		UpdateCommand = function(self)
			self:settext(availableBundles[currentBundleIndex]:upper())
		end
	},
	-- Dropdown arrow
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(bundleBtnW / 2 - 10):zoom(0.3):diffuse(dimText):settext("▼")
		end
	}
}

-- ============================================================
-- DOWNLOAD STATUS
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "DownloadStatusBar",
	InitCommand = function(self) self:xy(SCREEN_WIDTH * 0.8, searchBarY) end,
	OnCommand = function(self)
		local statusText = self:GetChild("DLStatus")
		self:SetUpdateFunction(function()
			local dls = DLMAN:GetDownloads()
			if dls and #dls > 0 then
				local dl = dls[1]
				local kb = dl:GetKBDownloaded()
				local total = dl:GetTotalKB()
				statusText:settextf("DL: %d/%dKB", kb, total)
				statusText:diffuse(accentColor)
			else
				local queued = DLMAN:GetQueuedPacks()
				if queued and #queued > 0 then
					statusText:settextf("%d queued", #queued)
					statusText:diffuse(subText)
				else
					statusText:settext("")
				end
			end
		end)
	end,

	LoadFont("Common Normal") .. {
		Name = "DLStatus",
		InitCommand = function(self) self:zoom(0.28):diffuse(dimText) end,
	}
}

-- ============================================================
-- COLUMN HEADERS
-- ============================================================
local listY = 62
local listX = SCREEN_WIDTH * 0.04
local listW = SCREEN_WIDTH * 0.92
local rowH = 24
local colIdxX = 4
local colNameX = 28
local colAvgX = listW * 0.58
local colSongsX = listW * 0.66
local colSizeX = listW * 0.76
local colStatusX = listW * 0.9

t[#t + 1] = Def.ActorFrame {
	Name = "ColumnHeaders",
	InitCommand = function(self) self:xy(listX, listY) end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):x(colNameX):zoom(0.24):diffuse(dimText):settext("PACK NAME")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):x(colAvgX):zoom(0.24):diffuse(dimText):settext("AVG MSD")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):x(colSongsX):zoom(0.24):diffuse(dimText):settext("SONGS")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(1):x(colSizeX):zoom(0.24):diffuse(dimText):settext("SIZE")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0.5):x(colStatusX):zoom(0.24):diffuse(dimText):settext("STATUS")
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):y(10):zoomto(listW, 1):diffuse(borderColor)
		end
	}
}

-- ============================================================
-- PACK LIST ROWS
-- ============================================================
local packListFrame = Def.ActorFrame {
	Name = "PackRows",
	InitCommand = function(self) self:xy(listX, listY + 14) end,

	PackListRequestFinishedMessageCommand = function(self)
		currentPacks = packList:GetPacks() or {}
		-- Cache installed flags
		installedFlags = {}
		for i, pack in ipairs(currentPacks) do
			installedFlags[i] = isPackInstalled(pack)
		end
		selectedRow = 1
		self:playcommand("RefreshRows")
	end,

	RefreshRowsCommand = function(self)
		for i = 1, packsPerPage do
			self:playcommand("UpdateRow" .. i)
		end
		MESSAGEMAN:Broadcast("UpdatePageInfo")
	end
}

for i = 1, packsPerPage do
	local rowY = (i - 1) * rowH

	packListFrame[#packListFrame + 1] = Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self) self:y(rowY) end,

		-- Row background
		Def.Quad {
			Name = "RowBG",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(listW, rowH - 1)
				if i % 2 == 0 then self:diffuse(rowAlt) else self:diffuse(rowNormal) end
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if i == selectedRow and pack then
					self:diffuse(rowHilight)
				elseif pack and installedFlags[i] then
					self:diffuse(rowInstalled)
				elseif i % 2 == 0 then
					self:diffuse(rowAlt)
				else
					self:diffuse(rowNormal)
				end
			end
		},

		-- Selection indicator
		Def.Quad {
			Name = "SelectBar",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(2, rowH - 1)
					:diffuse(accentColor):visible(false)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				self:visible(i == selectedRow and currentPacks[i] ~= nil)
			end
		},

		-- Row index
		LoadFont("Common Normal") .. {
			Name = "RowIdx",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(colIdxX, 3)
					:zoom(0.24):diffuse(dimText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local pageOffset = (packList:GetCurrentPage() - 1) * packsPerPage
					self:settextf("%d.", pageOffset + i)
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Pack name
		LoadFont("Common Normal") .. {
			Name = "PackName",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(colNameX, 3)
					:zoom(0.32):diffuse(mainText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					self:settext(pack:GetName())
					if installedFlags[i] then
						self:diffuse(installedColor)
					elseif i == selectedRow then
						self:diffuse(brightText)
					else
						self:diffuse(mainText)
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Average difficulty
		LoadFont("Common Normal") .. {
			Name = "AvgMSD",
			InitCommand = function(self)
				self:halign(1):valign(0):xy(colAvgX, 3)
					:zoom(0.26):diffuse(subText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local avg = pack:GetAvgDifficulty()
					if avg and avg > 0 then
						self:settextf("%.1f", avg)
					else
						self:settext("-")
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Song count
		LoadFont("Common Normal") .. {
			Name = "SongCount",
			InitCommand = function(self)
				self:halign(1):valign(0):xy(colSongsX, 3)
					:zoom(0.26):diffuse(subText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local count = pack:GetSongCount()
					if count and count > 0 then
						self:settext(tostring(count))
					else
						self:settext("-")
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Pack size
		LoadFont("Common Normal") .. {
			Name = "PackSize",
			InitCommand = function(self)
				self:halign(1):valign(0):xy(colSizeX, 3)
					:zoom(0.26):diffuse(subText)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					local bytes = pack:GetSize()
					if bytes and bytes > 0 then
						local mb = bytes / (1024 * 1024)
						if mb >= 1024 then
							self:settextf("%.1fGB", mb / 1024)
						else
							self:settextf("%.0fMB", mb)
						end
					else
						self:settext("--")
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Status text
		LoadFont("Common Normal") .. {
			Name = "StatusText",
			InitCommand = function(self)
				self:halign(0.5):valign(0):xy(colStatusX, 3):zoom(0.24)
			end,
			["UpdateRow" .. i .. "Command"] = function(self)
				local pack = currentPacks[i]
				if pack then
					if installedFlags[i] then
						self:settext("INSTALLED")
						self:diffuse(installedColor)
					elseif pack:IsQueued() then
						self:settext("QUEUED")
						self:diffuse(accentColor)
					else
						self:settext("DOWNLOAD")
						self:diffuse(subText)
					end
					self:visible(true)
				else
					self:visible(false)
				end
			end
		},

		-- Download progress bar (per row)
		Def.Quad {
			Name = "DLBar",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(0, rowH - 2)
					:zoomto(0, 1):diffuse(accentColor):diffusealpha(0.5)
			end
		}
	}
end

t[#t + 1] = packListFrame

-- ============================================================
-- STATUS INDICATOR (center of list area, shows when no rows visible)
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "LoadingText",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoom(0.4):diffuse(subText):visible(false)
	end,
	PackListRequestFinishedMessageCommand = function(self)
		local packs = packList:GetPacks()
		if packs and #packs > 0 then
			self:visible(false)
		else
			if packList:GetTotalResults() == 0 then
				self:settext("No packs found matching your search."):visible(true)
				self:diffuse(dimText)
			else
				self:visible(false)
			end
		end
	end,
	ShowLoadingCommand = function(self)
		self:settext("Fetching packs from server..."):visible(true)
		self:diffuse(accentColor):diffusealpha(0.6)
	end
}

-- Bundle List Overlay (Moved here for higher Z-order)
local bundleListFrame = Def.ActorFrame {
	Name = "BundleListOverlay",
	InitCommand = function(self) 
		self:xy(bundleBtnX - bundleBtnW / 2 + bundleListW / 2, searchBarY + 12 + (bundleItemH * #availableBundles / 2))
		self:visible(false)
	end,
	UpdateCommand = function(self)
		self:visible(isBundleListOpen)
		-- Re-center based on number of items
		self:y(searchBarY + 12 + (bundleItemH * #availableBundles / 2))
	end
}

-- List Background
bundleListFrame[#bundleListFrame + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(bundleListW, bundleItemH * #availableBundles)
		self:diffuse(color("0.05,0.05,0.05,0.95")):strokeColor(borderColor):strokeWidth(1)
	end
}

for i, bundleName in ipairs(availableBundles) do
	bundleListFrame[#bundleListFrame + 1] = Def.ActorFrame {
		Name = "BundleItem" .. i,
		InitCommand = function(self)
			self:y((i - 1 - (#availableBundles - 1) / 2) * bundleItemH)
		end,

		Def.Quad {
			Name = "ItemBG",
			InitCommand = function(self)
				self:zoomto(bundleListW - 2, bundleItemH - 2):diffusealpha(0)
			end,
			UpdateCommand = function(self)
				if i == currentBundleIndex then
					self:diffuse(accentColor):diffusealpha(0.2)
				else
					self:diffusealpha(0)
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.28):diffuse(mainText):settext(bundleName:upper())
			end,
			UpdateCommand = function(self)
				if i == currentBundleIndex then
					self:diffuse(brightText)
				else
					self:diffuse(mainText)
				end
			end
		}
	}
end

t[#t + 1] = bundleListFrame

-- ============================================================
-- FOOTER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "Footer",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 26) end,

	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self) self:zoom(0.28):diffuse(subText) end,
		UpdatePageInfoMessageCommand = function(self)
			local page = packList:GetCurrentPage()
			local total = packList:GetTotalPages()
			local results = packList:GetTotalResults()
			if total > 0 then
				self:settextf("Page %d / %d  ·  %d packs found", page, total, results)
			else
				if packList:IsAwaitingRequest() then
					self:settext("Searching...")
				else
					self:settext("No results - type to search")
				end
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(14):zoom(0.22):diffuse(dimText)
			self:settext("Type = search  ·  ↑↓/Scroll = select  ·  Enter/Click = download  ·  ←→ = pages  ·  Del = reset  ·  Esc = exit")
		end
	}
}

-- ============================================================
-- INPUT HANDLER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "InputHandler",
	BeginCommand = function(self)
		-- Initial search: show all packs
		packList:FilterAndSearch("", {}, true, packsPerPage)
		self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")

		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_Release" then return end

			local btn = event.DeviceInput.button
			local gameBtn = event.button

			-- Mouse wheel -> scroll rows up/down
			local scroll = GetMouseScrollDirection(btn)
			if scroll ~= 0 then
				if scroll < 0 then
					selectedRow = math.max(selectedRow - 1, 1)
				else
					selectedRow = math.min(selectedRow + 1, math.min(#currentPacks, packsPerPage))
				end
				self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				return
			end

			-- Mouse left click -> select/download row
			if IsMouseLeftClick(btn) then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()

				-- Check if bundle list is open and click is inside
				if isBundleListOpen then
					for i = 1, #availableBundles do
						local itemY = searchBarY + 12 + (i - 0.5) * bundleItemH
						if mx >= bundleBtnX - bundleBtnW / 2 and mx <= bundleBtnX - bundleBtnW / 2 + bundleListW
							and my >= itemY - bundleItemH / 2 and my <= itemY + bundleItemH / 2 then
							currentBundleIndex = i
							isBundleListOpen = false
							self:GetParent():GetChild("BundleSelector"):playcommand("Update")
							self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
							self:playcommand("DoSearch")
							return
						end
					end
					-- Clicked outside bundle list
					isBundleListOpen = false
					self:GetParent():GetChild("BundleSelector"):playcommand("Update")
					self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
					return
				end

				-- Check if click is on bundle selector button
				if mx >= bundleBtnX - bundleBtnW / 2 and mx <= bundleBtnX + bundleBtnW / 2
					and my >= searchBarY - 10 and my <= searchBarY + 10 then
					isBundleListOpen = not isBundleListOpen
					self:GetParent():GetChild("BundleSelector"):playcommand("Update")
					self:GetParent():GetChild("BundleListOverlay"):playcommand("Update")
					return
				end
				
				-- Check if click is on the search bar
				local sbX = SCREEN_WIDTH * 0.28
				local sbW = searchBarW
				local sbH = 20
				if mx >= sbX - sbW / 2 and mx <= sbX + sbW / 2 and my >= searchBarY - sbH / 2 and my <= searchBarY + sbH / 2 then
					isSearching = true
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					return
				else
					if isSearching then
						isSearching = false
						self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					end
				end

				-- Check if click is within the pack list area
				for i = 1, math.min(#currentPacks, packsPerPage) do
					local rowTopY = listY + 14 + (i - 1) * rowH
					if mx >= listX and mx <= listX + listW
						and my >= rowTopY and my <= rowTopY + rowH then
						if selectedRow == i then
							-- Already selected, trigger download
							local pack = currentPacks[i]
							if pack and not installedFlags[i] and not pack:IsQueued() then
								if pack:GetSize() > 2000000000 then
									pack:DownloadExternally()
								else
									pack:DownloadAndInstall(false)
								end
							end
						else
							selectedRow = i
						end
						self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
						return
					end
				end
				return
			end

			-- Text input — consume before checking navigation keys
			if isSearching then
				if btn == "DeviceButton_backspace" then
					nameInput = nameInput:sub(1, -2)
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					self:stoptweening():sleep(0.5):queuecommand("DoSearch")
					return
				end

				if btn == "DeviceButton_delete" then
					nameInput = ""
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					packList:FilterAndSearch("", {}, true, packsPerPage)
					self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
					return
				end

				local char = inputToCharacter(event)
				if char then
					nameInput = nameInput .. char
					self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
					self:stoptweening():sleep(0.5):queuecommand("DoSearch")
					return
				end
			end

			-- Arrow navigation
			if gameBtn == "MenuDown" or gameBtn == "Down" then
				selectedRow = math.min(selectedRow + 1, math.min(#currentPacks, packsPerPage))
				self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				return
			elseif gameBtn == "MenuUp" or gameBtn == "Up" then
				selectedRow = math.max(selectedRow - 1, 1)
				self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				return
			elseif btn == "DeviceButton_enter" or gameBtn == "Start" then
				-- Enter/Start = download/queue selected pack
				local pack = currentPacks[selectedRow]
				if pack and not installedFlags[selectedRow] and not pack:IsQueued() then
					if pack:GetSize() > 2000000000 then
						pack:DownloadExternally()
					else
						pack:DownloadAndInstall(false)
					end
					self:GetParent():GetChild("PackRows"):playcommand("RefreshRows")
				end
				return
			elseif gameBtn == "MenuRight" or gameBtn == "Right" or gameBtn == "EffectDown" then
				-- Right / Select+Down = next page
				if packList:NextPage() then
					self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
				end
				return
			elseif gameBtn == "MenuLeft" or gameBtn == "Left" or gameBtn == "EffectUp" then
				-- Left / Select+Up = prev page
				if packList:PrevPage() then
					self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
				end
				return
			end
		end)

		self:GetParent():GetChild("SearchBar"):playcommand("UpdateSearch")
	end,

	-- Auto-search triggered after typing debounce
	DoSearchCommand = function(self)
		local tags = {}
		if availableBundles[currentBundleIndex] ~= "All" then
			table.insert(tags, availableBundles[currentBundleIndex]:lower())
		end
		packList:FilterAndSearch(nameInput, tags, true, packsPerPage)
		self:GetParent():GetChild("LoadingText"):playcommand("ShowLoading")
	end,

	-- Periodic refresh for download progress
	OnCommand = function(self)
		self:SetUpdateFunction(function(af)
			if currentPacks and #currentPacks > 0 then
				local packRows = af:GetParent():GetChild("PackRows")
				for i = 1, math.min(#currentPacks, packsPerPage) do
					local pack = currentPacks[i]
					if pack and pack:IsQueued() then
						packRows:playcommand("UpdateRow" .. i)
					end
				end
			end
		end)
	end
}

-- Load custom mouse cursor (highest Z-order)
t[#t + 1] = LoadActor("../_cursor")

return t
