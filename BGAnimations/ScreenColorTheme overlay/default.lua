--- Holographic Void: ScreenColorTheme Overlay
-- Custom Lua UI for selecting the theme's accent color.
-- Features clickable swatches with a live preview panel that updates in real time.

local accentChoices = {
	{ name = "Ice Blue",       hex = "#5ABAFF" },
	{ name = "White",          hex = "#FFFFFF" },
	{ name = "Warm Gold",      hex = "#FFD080" },
	{ name = "Soft Red",       hex = "#FF8080" },
	{ name = "Mint",           hex = "#80FFB0" },
	{ name = "Violet",         hex = "#B080FF" },
	{ name = "Pure Gray",      hex = "#808080" },
	{ name = "Neon Pink",      hex = "#FF3399" },
	{ name = "Cyber Purple",   hex = "#7000FF" },
	{ name = "Emerald",        hex = "#00D050" },
	{ name = "Sunset Orange",  hex = "#FF7A00" },
	{ name = "Electric Indigo",hex = "#4B0082" },
	{ name = "Crimson",        hex = "#DC143C" },
	{ name = "Cyan",           hex = "#00FFFF" },
}

-- Layout constants
local cols = 7
local rows = math.ceil(#accentChoices / cols)
local swatchSize = 56
local swatchGapX = 20
local swatchGapY = 54
local totalSwatchW = cols * (swatchSize + swatchGapX) - swatchGapX
local swatchStartX = SCREEN_CENTER_X - totalSwatchW / 2 + swatchSize / 2
local swatchStartY = SCREEN_CENTER_Y - 110

local function getSwatchPos(i)
	local r = math.ceil(i / cols) - 1
	local c = (i - 1) % cols
	local rowCount = cols
	if r == rows - 1 and #accentChoices % cols ~= 0 then
		rowCount = #accentChoices % cols
	end
	local rowW = rowCount * (swatchSize + swatchGapX) - swatchGapX
	local sx = SCREEN_CENTER_X - rowW / 2 + swatchSize / 2 + c * (swatchSize + swatchGapX)
	local sy = swatchStartY + r * (swatchSize + swatchGapY)
	return sx, sy
end

-- Preview panel constants
local previewY = SCREEN_CENTER_Y + 95
local previewW = 400
local previewH = 120

-- State
local selectedIdx = 1
local hoveredIdx = nil
local previewColor = color("#5ABAFF")

-- ============================================================
-- Helpers
-- ============================================================
local function getActiveHex()
	if ThemePrefs and ThemePrefs.Get then
		local h = ThemePrefs.Get("HV_AccentColor")
		if h and h ~= "" then return h end
	end
	return "#5ABAFF"
end

local function findSelectedIdx()
	local cur = getActiveHex():upper()
	for i, c in ipairs(accentChoices) do
		if c.hex:upper() == cur then return i end
	end
	return 1
end

local function applyColor(idx)
	local choice = accentChoices[idx]
	if not choice then return end
	selectedIdx = idx
	ThemePrefs.Set("HV_AccentColor", choice.hex)
	ThemePrefs.ForceSave()
	if HVColor and HVColor.RefreshAccent then
		HVColor.RefreshAccent()
	end
	previewColor = color(choice.hex)
	MESSAGEMAN:Broadcast("ColorThemeChanged")
	MESSAGEMAN:Broadcast("ThemePrefChanged", { Name = "HV_AccentColor" })
end

-- ============================================================
-- Root ActorFrame
-- ============================================================
local t = Def.ActorFrame {
	Name = "ColorThemeRoot",
	BeginCommand = function(self)
		selectedIdx = findSelectedIdx()
		previewColor = color(getActiveHex())

		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		screen:AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local btn = (event.DeviceInput or {}).button or ""
			local gb = event.button or ""

			-- Escape / Back
			if gb == "Back" or btn == "DeviceButton_escape" then
				screen:Cancel()
				return true
			end

			-- Grid navigation
			if gb == "MenuLeft" or btn == "DeviceButton_left" then
				local ni = selectedIdx - 1
				if ni < 1 then ni = #accentChoices end
				applyColor(ni)
				return true
			end
			if gb == "MenuRight" or btn == "DeviceButton_right" then
				local ni = selectedIdx + 1
				if ni > #accentChoices then ni = 1 end
				applyColor(ni)
				return true
			end
			if gb == "MenuUp" or btn == "DeviceButton_up" then
				local ni = selectedIdx - cols
				if ni >= 1 then applyColor(ni) return true end
			end
			if gb == "MenuDown" or btn == "DeviceButton_down" then
				local ni = selectedIdx + cols
				if ni <= #accentChoices then applyColor(ni) return true end
			end

			-- Enter / Start to confirm and go back
			if gb == "Start" or btn == "DeviceButton_enter" then
				screen:Cancel()
				return true
			end

			-- Mouse click
			if btn == "DeviceButton_left mouse button" then
				local mx = INPUTFILTER:GetMouseX()
				local my = INPUTFILTER:GetMouseY()
				for i = 1, #accentChoices do
					local sx, sy = getSwatchPos(i)
					if mx >= sx - swatchSize/2 and mx <= sx + swatchSize/2
					   and my >= sy - swatchSize/2 and my <= sy + swatchSize/2 then
						applyColor(i)
						return true
					end
				end
			end
		end)
	end,
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			-- Mouse hover detection
			local mx = INPUTFILTER:GetMouseX()
			local my = INPUTFILTER:GetMouseY()
			local newHover = nil
			for i = 1, #accentChoices do
				local sx, sy = getSwatchPos(i)
				if mx >= sx - swatchSize/2 and mx <= sx + swatchSize/2
				   and my >= sy - swatchSize/2 and my <= sy + swatchSize/2 then
					newHover = i
					break
				end
			end
			if newHover ~= hoveredIdx then
				hoveredIdx = newHover
				MESSAGEMAN:Broadcast("SwatchHoverChanged")
			end
		end)
	end
}

-- ============================================================
-- HEADER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_TOP + 50) end,

	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:zoom(0.6):diffuse(color("1,1,1,1"))
			self:settext("COLOR THEME")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(28):zoom(0.32):diffuse(color("0.45,0.45,0.45,1"))
			self:settext("Select an accent color for the Holographic Void experience")
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(44):zoomto(SCREEN_WIDTH * 0.5, 1)
				:diffuse(HVColor.Accent):diffusealpha(0.3)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.5)
		end
	}
}

-- ============================================================
-- COLOR SWATCHES
-- ============================================================
for i, choice in ipairs(accentChoices) do
	t[#t + 1] = Def.ActorFrame {
		Name = "Swatch_" .. i,
		InitCommand = function(self)
			local sx, sy = getSwatchPos(i)
			self:xy(sx, sy)
		end,

		-- Swatch background (color fill)
		Def.Quad {
			Name = "SwatchBg",
			InitCommand = function(self)
				self:zoomto(swatchSize, swatchSize):diffuse(color(choice.hex))
			end,
			SwatchHoverChangedMessageCommand = function(self)
				if hoveredIdx == i then
					self:stoptweening():decelerate(0.1):zoomto(swatchSize + 6, swatchSize + 6)
				else
					self:stoptweening():decelerate(0.1):zoomto(swatchSize, swatchSize)
				end
			end
		},

		-- Selection ring
		Def.Quad {
			Name = "Ring",
			InitCommand = function(self)
				self:zoomto(swatchSize + 8, swatchSize + 8)
					:diffuse(color("1,1,1,0")):blend("BlendMode_Add")
			end,
			ColorThemeChangedMessageCommand = function(self)
				if selectedIdx == i then
					self:stoptweening():linear(0.12)
						:diffuse(color(choice.hex)):diffusealpha(0.7)
				else
					self:stoptweening():linear(0.12):diffusealpha(0)
				end
			end,
			BeginCommand = function(self)
				if selectedIdx == i then
					self:diffuse(color(choice.hex)):diffusealpha(0.7)
				end
			end
		},

		-- Selected checkmark indicator
		LoadFont("Common Normal") .. {
			Name = "Check",
			InitCommand = function(self)
				self:y(swatchSize/2 + 2):zoom(0.5):diffuse(color("1,1,1,0"))
				self:settext("●")
			end,
			ColorThemeChangedMessageCommand = function(self)
				if selectedIdx == i then
					self:stoptweening():linear(0.1):diffuse(color(choice.hex)):diffusealpha(1)
				else
					self:stoptweening():linear(0.1):diffusealpha(0)
				end
			end,
			BeginCommand = function(self)
				if selectedIdx == i then
					self:diffuse(color(choice.hex)):diffusealpha(1)
				end
			end
		},

		-- Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:y(swatchSize/2 + 16):zoom(0.3)
					:diffuse(color("0.65,0.65,0.65,1"))
				self:settext(choice.name)
			end,
			SwatchHoverChangedMessageCommand = function(self)
				if hoveredIdx == i then
					self:stoptweening():linear(0.1):diffuse(color("1,1,1,1"))
				else
					self:stoptweening():linear(0.1):diffuse(color("0.65,0.65,0.65,1"))
				end
			end
		}
	}
end

-- ============================================================
-- LIVE PREVIEW PANEL
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "PreviewPanel",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, previewY) end,

	-- Panel background
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(previewW, previewH):diffuse(color("0.06,0.06,0.06,0.95"))
		end
	},

	-- Left accent bar (live preview)
	Def.Quad {
		Name = "AccentBar",
		InitCommand = function(self)
			self:halign(0):x(-previewW/2):zoomto(3, previewH)
				:diffuse(color(getActiveHex())):diffusealpha(0.8)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8)
		end
	},

	-- "PREVIEW" label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-previewW/2 + 20, -previewH/2 + 14):halign(0):zoom(0.25)
				:diffuse(color("0.45,0.45,0.45,1"))
			self:settext("LIVE PREVIEW")
		end
	},

	-- Sample header text
	LoadFont("Common Normal") .. {
		Name = "SampleHeader",
		InitCommand = function(self)
			self:xy(0, -previewH/2 + 36):zoom(0.55):diffuse(color("1,1,1,1"))
			self:settext("HOLOGRAPHIC VOID")
		end
	},

	-- Sample accent line
	Def.Quad {
		Name = "SampleLine",
		InitCommand = function(self)
			self:y(-previewH/2 + 52):zoomto(previewW * 0.6, 2)
				:diffuse(color(getActiveHex())):diffusealpha(0.6)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.6)
		end
	},

	-- Sample body text
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(0, -previewH/2 + 70):zoom(0.3):diffuse(color("0.65,0.65,0.65,1"))
			self:settext("Song Title — Artist Name")
		end
	},

	-- Sample accent-colored element (simulated button)
	Def.Quad {
		Name = "SampleBtn",
		InitCommand = function(self)
			self:xy(-60, previewH/2 - 22):zoomto(80, 24)
				:diffuse(color(getActiveHex())):diffusealpha(0.3)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.3)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SampleBtnTxt",
		InitCommand = function(self)
			self:xy(-60, previewH/2 - 22):zoom(0.3)
				:diffuse(color(getActiveHex()))
			self:settext("START")
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor)
		end
	},

	-- Second sample button
	Def.Quad {
		InitCommand = function(self)
			self:xy(60, previewH/2 - 22):zoomto(80, 24)
				:diffuse(color("0.12,0.12,0.12,1"))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(60, previewH/2 - 22):zoom(0.3)
				:diffuse(color("0.65,0.65,0.65,1"))
			self:settext("OPTIONS")
		end
	}
}

-- ============================================================
-- CURRENT SELECTION DISPLAY
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "CurrentLabel",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, previewY + previewH/2 + 30):zoom(0.35)
			:diffuse(color("0.65,0.65,0.65,1"))
	end,
	ColorThemeChangedMessageCommand = function(self)
		local name = accentChoices[selectedIdx] and accentChoices[selectedIdx].name or "?"
		self:settext("Active: " .. name)
	end,
	BeginCommand = function(self)
		local name = accentChoices[selectedIdx] and accentChoices[selectedIdx].name or "?"
		self:settext("Active: " .. name)
	end
}

-- ============================================================
-- FOOTER
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 20):zoom(0.28)
			:diffuse(color("0.45,0.45,0.45,1"))
		self:settext("Click a swatch or use Left/Right · Enter to confirm · Escape to go back")
	end
}

-- ============================================================
-- DECORATIVE BRACKETS
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:diffusealpha(0.2) end,
	Def.ActorFrame {
		InitCommand = function(self) self:xy(SCREEN_LEFT + 20, SCREEN_TOP + 20) end,
		Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(40, 1):diffuse(color(getActiveHex())) end,
			ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end },
		Def.Quad { InitCommand = function(self) self:halign(0):valign(0):zoomto(1, 40):diffuse(color(getActiveHex())) end,
			ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end }
	},
	Def.ActorFrame {
		InitCommand = function(self) self:xy(SCREEN_RIGHT - 20, SCREEN_BOTTOM - 20) end,
		Def.Quad { InitCommand = function(self) self:halign(1):valign(1):zoomto(40, 1):diffuse(color(getActiveHex())) end,
			ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end },
		Def.Quad { InitCommand = function(self) self:halign(1):valign(1):zoomto(1, 40):diffuse(color(getActiveHex())) end,
			ColorThemeChangedMessageCommand = function(self) self:stoptweening():linear(0.15):diffuse(previewColor) end }
	}
}

-- ============================================================
-- MOUSE CURSOR
-- ============================================================
t[#t + 1] = LoadActor("../_cursor")

return t
