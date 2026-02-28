--- Holographic Void: ScreenHVDownloadOverlay
-- Custom global download progress overlay visible on ALL screens.
-- Shows a compact progress bar + text at the bottom of the screen.
-- Hovering the mouse over the bar expands it to show queued packs.

local barH = 4
local barY = SCREEN_BOTTOM - barH
local textY = barY - 16
local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.9,0.9,0.9,1")

-- Queue panel constants
local queueRowH = 18           -- height per queued pack row
local maxQueueDisplay = 8      -- max queued items to show
local hoverZoneH = 28          -- hitbox height at screen bottom for hover detection
local panelPadding = 8

local t = Def.ActorFrame {
	Name = "DownloadOverlay",
}

-- Background strip behind text (compact mode)
t[#t + 1] = Def.Quad {
	Name = "BG",
	InitCommand = function(self)
		self:halign(0):valign(1)
			:xy(0, SCREEN_BOTTOM)
			:zoomto(SCREEN_WIDTH, 22)
			:diffuse(color("0,0,0,0.9"))
			:visible(false)
	end
}

-- Progress bar fill
t[#t + 1] = Def.Quad {
	Name = "BarFill",
	InitCommand = function(self)
		self:halign(0):valign(0)
			:xy(0, barY)
			:zoomto(0, barH)
			:diffuse(accentColor)
			:visible(false)
	end
}

-- Download status text
t[#t + 1] = Def.BitmapText {
	Font = "Common Normal",
	Name = "StatusText",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, textY)
			:zoom(0.35)
			:diffuse(mainText)
			:shadowlength(1)
			:visible(false)
	end
}

-- Percentage text (right side)
t[#t + 1] = Def.BitmapText {
	Font = "Common Normal",
	Name = "PctText",
	InitCommand = function(self)
		self:halign(1)
			:xy(SCREEN_WIDTH - 6, textY)
			:zoom(0.3)
			:diffuse(accentColor)
			:shadowlength(1)
			:visible(false)
	end
}

-- ============================================================
-- EXPANDED QUEUE PANEL (shown on hover)
-- ============================================================
local queuePanel = Def.ActorFrame {
	Name = "QueuePanel",
	InitCommand = function(self)
		self:visible(false)
	end,

	-- Expanded background
	Def.Quad {
		Name = "QueueBG",
		InitCommand = function(self)
			self:halign(0):valign(1)
				:xy(0, SCREEN_BOTTOM - 22)
				:zoomto(SCREEN_WIDTH, 0)
				:diffuse(color("0.03,0.03,0.03,0.95"))
		end
	},

	-- "DOWNLOAD QUEUE" header
	Def.BitmapText {
		Font = "Common Normal",
		Name = "QueueHeader",
		InitCommand = function(self)
			self:halign(0):valign(1)
				:xy(12, SCREEN_BOTTOM - 26)
				:zoom(0.28)
				:diffuse(accentColor)
				:settext("DOWNLOAD QUEUE")
		end
	},

	-- Separator line
	Def.Quad {
		Name = "QueueSep",
		InitCommand = function(self)
			self:halign(0):valign(1)
				:xy(0, SCREEN_BOTTOM - 22)
				:zoomto(SCREEN_WIDTH, 1)
				:diffuse(accentColor):diffusealpha(0.2)
		end
	}
}

-- Pre-create text rows for queued pack names
for i = 1, maxQueueDisplay do
	queuePanel[#queuePanel + 1] = Def.BitmapText {
		Font = "Common Normal",
		Name = "QueueItem" .. i,
		InitCommand = function(self)
			self:halign(0):valign(1)
				:xy(16, SCREEN_BOTTOM - 28 - (i * queueRowH))
				:zoom(0.28)
				:diffuse(subText)
				:visible(false)
		end
	}

	-- Status indicator per row (downloading / queued)
	queuePanel[#queuePanel + 1] = Def.BitmapText {
		Font = "Common Normal",
		Name = "QueueStatus" .. i,
		InitCommand = function(self)
			self:halign(1):valign(1)
				:xy(SCREEN_WIDTH - 12, SCREEN_BOTTOM - 28 - (i * queueRowH))
				:zoom(0.24)
				:diffuse(dimText)
				:visible(false)
		end
	}
end

t[#t + 1] = queuePanel

-- ============================================================
-- MAIN UPDATE FUNCTION
-- ============================================================
t.OnCommand = function(self)
	local bg = self:GetChild("BG")
	local bar = self:GetChild("BarFill")
	local status = self:GetChild("StatusText")
	local pct = self:GetChild("PctText")
	local panel = self:GetChild("QueuePanel")
	local panelBG = panel:GetChild("QueueBG")
	local wasVisible = false
	local isExpanded = false

	self:SetUpdateFunction(function()
		local dls = DLMAN:GetDownloads()
		local queued = DLMAN:GetQueuedPacks()
		local hasDL = dls and #dls > 0
		local hasQueued = queued and #queued > 0
		local shouldShow = hasDL or hasQueued

		-- Show/hide the compact bar
		if shouldShow and not wasVisible then
			wasVisible = true
			bg:visible(true)
			bar:visible(true)
			status:visible(true)
			pct:visible(true)
		elseif not shouldShow and wasVisible then
			wasVisible = false
			bg:visible(false)
			bar:visible(false)
			status:visible(false)
			pct:visible(false)
			bar:zoomto(0, barH)
			-- Also hide expanded panel
			panel:visible(false)
			isExpanded = false
		end

		if not shouldShow then return end

		-- Update compact bar
		if hasDL then
			local dl = dls[1]
			local dlKB = dl:GetKBDownloaded()
			local totalKB = dl:GetTotalKB()
			local mb = dlKB / 1024
			local total = totalKB / 1024
			local percent = 0
			if totalKB > 0 then
				percent = dlKB / totalKB
			end

			local dlPacks = DLMAN:GetDownloadingPacks()
			local packName = "pack"
			if dlPacks and #dlPacks > 0 then
				packName = dlPacks[1]:GetName()
			end

			local queueCount = queued and #queued or 0
			if queueCount > 0 then
				status:settextf("Downloading: %s  (%.0f/%.0fMB)  +%d queued",
					packName, mb, total, queueCount)
			else
				status:settextf("Downloading: %s  (%.0f/%.0fMB)",
					packName, mb, total)
			end

			pct:settextf("%.0f%%", percent * 100)
			bar:zoomto(SCREEN_WIDTH * percent, barH)
		elseif hasQueued then
			status:settextf("Queued: %d pack(s)...", #queued)
			pct:settext("")
			bar:zoomto(0, barH)
		end

		-- ====================================================
		-- HOVER DETECTION: expand/collapse queue panel
		-- ====================================================
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		local hoverTarget = SCREEN_BOTTOM - hoverZoneH
		-- If expanded, extend hover zone to cover the full panel
		local panelH = 0
		local queueCount = queued and #queued or 0
		local displayCount = math.min(queueCount, maxQueueDisplay)

		if isExpanded then
			panelH = 28 + displayCount * queueRowH + panelPadding
			hoverTarget = SCREEN_BOTTOM - 22 - panelH - 8
		end

		local isHovering = my >= hoverTarget and my <= SCREEN_BOTTOM
			and mx >= 0 and mx <= SCREEN_WIDTH

		if isHovering and not isExpanded and (queueCount > 0 or hasDL) then
			isExpanded = true
			panel:visible(true)

			-- Size the expanded panel background
			panelH = 28 + displayCount * queueRowH + panelPadding
			panelBG:stoptweening():linear(0.15):zoomto(SCREEN_WIDTH, panelH)

		elseif not isHovering and isExpanded then
			isExpanded = false
			panelBG:stoptweening():linear(0.1):zoomto(SCREEN_WIDTH, 0)
			-- Hide after collapse animation
			panel:sleep(0.12):queuecommand("HidePanel")
		end

		-- Update queue item texts when expanded
		if isExpanded then
			-- Build the full list: downloading packs first, then queued
			local allItems = {}
			local dlPacks = DLMAN:GetDownloadingPacks()
			if dlPacks then
				for _, p in ipairs(dlPacks) do
					allItems[#allItems + 1] = { name = p:GetName(), status = "DOWNLOADING" }
				end
			end
			if queued then
				for _, p in ipairs(queued) do
					allItems[#allItems + 1] = { name = p:GetName(), status = "QUEUED" }
				end
			end

			for i = 1, maxQueueDisplay do
				local nameText = panel:GetChild("QueueItem" .. i)
				local statusText = panel:GetChild("QueueStatus" .. i)
				if i <= #allItems then
					nameText:settext(allItems[i].name)
					nameText:visible(true)
					statusText:settext(allItems[i].status)
					if allItems[i].status == "DOWNLOADING" then
						statusText:diffuse(accentColor)
					else
						statusText:diffuse(dimText)
					end
					statusText:visible(true)
				else
					nameText:visible(false)
					statusText:visible(false)
				end
			end
		else
			-- Hide all rows when collapsed
			for i = 1, maxQueueDisplay do
				local nameText = panel:GetChild("QueueItem" .. i)
				local statusText = panel:GetChild("QueueStatus" .. i)
				if nameText then nameText:visible(false) end
				if statusText then statusText:visible(false) end
			end
		end
	end)
end

-- HidePanel command used after collapse animation
t[#t + 1] = Def.Actor {
	Name = "Dummy"
}
-- Attach the hide command to the queue panel itself
queuePanel.HidePanelCommand = function(self)
	self:visible(false)
end

return t
