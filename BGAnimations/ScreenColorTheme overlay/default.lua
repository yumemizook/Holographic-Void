--- Holographic Void: ScreenColorTheme Overlay
-- Custom Lua UI for selecting the theme's accent color.
-- Features clickable swatches with a live preview panel that updates in real time.
-- We use color presets for now. the proper color config screen will be here at some point.

local accentChoices = {
	-- Cool Colors (Blues/Cyans/Greens)
	{ name = "Ice Blue",        hex = "#5ABAFF" },     -- Default
	{ name = "Arctic Blue",     hex = "#4A9AEF" },
	{ name = "Deep Ocean",      hex = "#2E5F8A" },
	{ name = "Cyan",            hex = "#00FFFF" },
	{ name = "Teal",            hex = "#008B8B" },
	{ name = "Mint",            hex = "#80FFB0" },
	{ name = "Emerald",         hex = "#00D050" },
	{ name = "Forest Green",    hex = "#228B22" },
	{ name = "Sky Blue",        hex = "#87CEEB" },      -- Extended cool color
	
	-- Warm Colors (Yellows/Oranges/Reds)
	{ name = "Warm Gold",       hex = "#FFD080" },
	{ name = "Golden",          hex = "#FFD700" },
	{ name = "Sunset Orange",   hex = "#FF7A00" },
	{ name = "Coral",           hex = "#FF6B6B" },
	{ name = "Soft Red",        hex = "#FF8080" },
	{ name = "Crimson",         hex = "#DC143C" },
	{ name = "Rose",            hex = "#FF007F" },
	{ name = "Amber",           hex = "#FFBF00" },      -- Extended warm color
	
	-- Purple/Violet Spectrum
	{ name = "Lavender",        hex = "#b6b6ff" },
	{ name = "Violet",          hex = "#B080FF" },
	{ name = "Electric Indigo", hex = "#4B0082" },
	{ name = "Cyber Purple",    hex = "#7000FF" },
	{ name = "Magenta",         hex = "#FF00FF" },
	{ name = "Orchid",          hex = "#DA70D6" },      -- Extended purple color
	
	-- Neutral/Grayscale
	{ name = "Pure Gray",       hex = "#808080" },
	{ name = "Silver",          hex = "#C0C0C0" },
	{ name = "Platinum",        hex = "#E5E4E2" },
	{ name = "White",           hex = "#FFFFFF" },
	{ name = "Charcoal",        hex = "#333b40" },      -- Extended neutral color
}

-- Layout constants
local cols = 7
local rows = math.ceil(#accentChoices / cols)
local swatchSize = 50
local swatchGapX = 16
local swatchGapY = 44
local totalSwatchW = cols * (swatchSize + swatchGapX) - swatchGapX
local swatchStartX = SCREEN_LEFT + 60 + swatchSize / 2
local swatchStartY = SCREEN_CENTER_Y - 110

-- Preview panel constants (right side chunks)
local previewStartX = SCREEN_RIGHT - 180
local previewStartY = SCREEN_CENTER_Y - 120
local chunkW = 280
local chunkH = 55

local function getSwatchPos(i)
	local r = math.ceil(i / cols) - 1
	local c = (i - 1) % cols
	sx = swatchStartX + c * (swatchSize + swatchGapX)
	sy = swatchStartY + r * (swatchSize + swatchGapY)
	return sx, sy
end

-- Interactivity for chunks
local gradeStyles = {"Holographic", "Classic"}
local msdScales = {"Holographic", "Classic", "None", "Monochrome"}

local function getGradeStyle()
	return ThemePrefs.Get("HV_GradeColorStyle") or "Holographic"
end

local function cycleGradeStyle()
	local current = getGradeStyle()
	local nextStyle = gradeStyles[1]
	for i, s in ipairs(gradeStyles) do
		if s == current then
			nextStyle = gradeStyles[i % #gradeStyles + 1]
			break
		end
	end
	ThemePrefs.Set("HV_GradeColorStyle", nextStyle)
	ThemePrefs.ForceSave()
	MESSAGEMAN:Broadcast("GradeStyleChanged")
end

local function getMSDScale()
	return ThemePrefs.Get("HV_MSDColorScaleV3") or "Holographic"
end

local function cycleMSDScale()
	local current = getMSDScale()
	local nextScale = msdScales[1]
	for i, s in ipairs(msdScales) do
		if s == current then
			nextScale = msdScales[i % #msdScales + 1]
			break
		end
	end
	ThemePrefs.Set("HV_MSDColorScaleV3", nextScale)
	ThemePrefs.ForceSave()
	MESSAGEMAN:Broadcast("MSDScaleChanged")
end

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
				
				-- Swatches
				for i = 1, #accentChoices do
					local sx, sy = getSwatchPos(i)
					if mx >= sx - swatchSize/2 and mx <= sx + swatchSize/2
					   and my >= sy - swatchSize/2 and my <= sy + swatchSize/2 then
						applyColor(i)
						return true
					end
				end

				-- Interactive Chunks
				local function isOverChunk(yOff)
					local cx = previewStartX
					local cy = previewStartY + yOff
					return mx >= cx - chunkW/2 and mx <= cx + chunkW/2
					   and my >= cy - chunkH/2 and my <= cy + chunkH/2
				end

				if isOverChunk(248) then -- Grade Chunk
					cycleGradeStyle()
					return true
				end
				if isOverChunk(310) then -- MSD Chunk
					cycleMSDScale()
					return true
				end
			end
		end)
	end,
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			-- Mouse hover detection
			local mx = INPUTFILTER:GetMouseX()
			local my = INPUTFILTER:GetMouseY()
			
			-- Swatches
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

			-- Chunk hovers
			local function isOverChunk(yOff)
				local cx = previewStartX
				local cy = previewStartY + yOff
				return mx >= cx - chunkW/2 and mx <= cx + chunkW/2
				   and my >= cy - chunkH/2 and my <= cy + chunkH/2
			end
			
			local overGrade = isOverChunk(248)
			local overMSD = isOverChunk(310)
			if overGrade ~= self.HoveringGrade then
				self.HoveringGrade = overGrade
				MESSAGEMAN:Broadcast("GradeHoverChanged", { Hovering = overGrade })
			end
			if overMSD ~= self.HoveringMSD then
				self.HoveringMSD = overMSD
				MESSAGEMAN:Broadcast("MSDHoverChanged", { Hovering = overMSD })
			end
		end)
	end
}

-- ============================================================
-- HEADER
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_TOP + 30) end,

	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:zoom(0.55):diffuse(color("1,1,1,1"))
			self:settext("COLOR THEME")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(24):zoom(0.28):diffuse(color("0.45,0.45,0.45,1"))
			self:settext("Select an accent color for the Holographic Void experience")
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:y(38):zoomto(SCREEN_WIDTH * 0.4, 1)
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
				self:y(swatchSize/2 + 2):zoom(0.45):diffuse(color("1,1,1,0"))
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
				self:y(swatchSize/2 + 14):zoom(0.28)
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
-- FEATURE PREVIEW CHUNKS (Right Side)
-- ============================================================

-- Helper to create a preview chunk
local function createChunk(name, yOffset, iconChar, titleText, descText, showProgress)
	return Def.ActorFrame {
		Name = "Chunk_" .. name,
		InitCommand = function(self) self:xy(previewStartX, previewStartY + yOffset) end,
		
		-- Chunk background
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9"))
			end
		},
		
		-- Left accent bar
		Def.Quad {
			Name = "ChunkAccentBar",
			InitCommand = function(self)
				self:halign(0):x(-chunkW/2):zoomto(3, chunkH)
					:diffuse(color(getActiveHex())):diffusealpha(0.8)
			end,
			ColorThemeChangedMessageCommand = function(self)
				self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8)
			end
		},
		
		-- Icon
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-chunkW/2 + 18, 0):zoom(0.4)
					:diffuse(color(getActiveHex()))
				self:settext(iconChar)
			end,
			ColorThemeChangedMessageCommand = function(self)
				self:stoptweening():linear(0.15):diffuse(previewColor)
			end
		},
		
		-- Title
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-chunkW/2 + 38, -8):halign(0):zoom(0.32)
					:diffuse(color("1,1,1,1"))
				self:settext(titleText)
			end
		},
		
		-- Description
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-chunkW/2 + 38, 8):halign(0):zoom(0.24)
					:diffuse(color("0.65,0.65,0.65,1"))
				self:settext(descText)
			end
		},
		
		-- Optional progress bar
		showProgress and Def.ActorFrame {
			InitCommand = function(self) self:y(16) end,
			Def.Quad {
				InitCommand = function(self)
					self:halign(0):x(-chunkW/2 + 38):zoomto(80, 4)
						:diffuse(color("0.18,0.18,0.18,1"))
				end
			},
			Def.Quad {
				Name = "ProgressBar",
				InitCommand = function(self)
					self:halign(0):x(-chunkW/2 + 38):zoomto(55, 4)
						:diffuse(color(getActiveHex())):diffusealpha(0.7)
				end,
				ColorThemeChangedMessageCommand = function(self)
					self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.7)
				end
			}
		} or nil
	}
end

-- Add feature demonstration chunks
t[#t + 1] = createChunk("Header", 0, "H", "Title Header", "Sample header text styling", false)
t[#t + 1] = createChunk("Button", 62, "B", "Active Button", "Interactive button states", false)
t[#t + 1] = createChunk("Progress", 124, "P", "Progress Bar", "Progress indicators", true)
t[#t + 1] = createChunk("Accent", 186, "A", "Accent Elements", "Selection & highlights", false)

-- ============================================================
-- INTERACTIVE GRADE PREVIEW
-- ============================================================
t[#t+1] = Def.ActorFrame {
	Name = "Chunk_Grade",
	InitCommand = function(self) self:xy(previewStartX, previewStartY + 248) end,
	
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9"))
		end,
		GradeHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.1,0.1,0.1,0.9") or color("0.06,0.06,0.06,0.9"))
		end
	},
	
	Def.Quad {
		Name = "ChunkAccentBar",
		InitCommand = function(self)
			self:halign(0):x(-chunkW/2):zoomto(3, chunkH)
				:diffuse(color(getActiveHex())):diffusealpha(0.8)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8)
		end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW/2 + 18, 0):zoom(0.4):diffuse(color(getActiveHex()))
			self:settext("G")
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor)
		end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW/2 + 38, -14):halign(0):zoom(0.32):diffuse(color("1,1,1,1"))
		end,
		BeginCommand = function(self) self:playcommand("Set") end,
		GradeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			self:settext("Grade Colors: " .. getGradeStyle())
		end
	},

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW/2 + 38, -2):halign(0):zoom(0.18):diffuse(color("0.4,0.4,0.4,1"))
			self:settext("Click to cycle style (Holographic/Classic)")
		end,
		GradeHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffusealpha(params.Hovering and 1 or 0.4)
		end
	},
	
	-- Grade Examples
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, 14) end,
		
		(function()
			local grades = {"AAAAA", "AAAA", "AAA", "AA", "A", "B", "C", "D", "F"}
			local am = Def.ActorFrame {}
			for i, g in ipairs(grades) do
				am[#am+1] = LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x((i-1)*25):zoom(0.24):halign(0)
					end,
					BeginCommand = function(self) self:playcommand("Set") end,
					GradeStyleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self)
						self:settext(g)
						self:diffuse(HVColor.GetGradeColor(g))
					end
				}
			end
			return am
		end)()
	}
}

-- ============================================================
-- INTERACTIVE MSD SCALE PREVIEW
-- ============================================================
t[#t+1] = Def.ActorFrame {
	Name = "Chunk_MSD",
	InitCommand = function(self) self:xy(previewStartX, previewStartY + 310) end,
	
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(chunkW, chunkH):diffuse(color("0.06,0.06,0.06,0.9"))
		end,
		MSDHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffuse(params.Hovering and color("0.1,0.1,0.1,0.9") or color("0.06,0.06,0.06,0.9"))
		end
	},
	
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):x(-chunkW/2):zoomto(3, chunkH)
				:diffuse(color(getActiveHex())):diffusealpha(0.8)
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor):diffusealpha(0.8)
		end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW/2 + 18, 0):zoom(0.4):diffuse(color(getActiveHex()))
			self:settext("M")
		end,
		ColorThemeChangedMessageCommand = function(self)
			self:stoptweening():linear(0.15):diffuse(previewColor)
		end
	},
	
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW/2 + 38, -14):halign(0):zoom(0.32):diffuse(color("1,1,1,1"))
		end,
		BeginCommand = function(self) self:playcommand("Set") end,
		MSDScaleChangedMessageCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			self:settext("MSD Scale: " .. getMSDScale())
		end
	},

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-chunkW/2 + 38, -2):halign(0):zoom(0.18):diffuse(color("0.4,0.4,0.4,1"))
			self:settext("Click to cycle scale (Holographic/Classic/None/Mono)")
		end,
		MSDHoverChangedMessageCommand = function(self, params)
			self:stoptweening():linear(0.1):diffusealpha(params.Hovering and 1 or 0.4)
		end
	},

	-- MSD Scale Bar (0-40)
	Def.ActorFrame {
		InitCommand = function(self) self:xy(-chunkW/2 + 38, 12) end,
		
		(function()
			local am = Def.ActorFrame {}
			local segments = 40
			local segW = 200 / segments
			for i = 0, segments do
				am[#am+1] = Def.Quad {
					InitCommand = function(self)
						self:x(i * segW):halign(0):zoomto(segW, 6)
					end,
					BeginCommand = function(self) self:playcommand("Set") end,
					MSDScaleChangedMessageCommand = function(self) self:playcommand("Set") end,
					SetCommand = function(self)
						self:diffuse(HVColor.GetMSDRatingColor(i))
					end
				}
			end
			
			-- Labels for 0 and 40
			am[#am+1] = LoadFont("Common Normal") .. {
				InitCommand = function(self) self:y(11):zoom(0.18):halign(0):diffuse(color("0.5,0.5,0.5,1")):settext("0") end
			}
			am[#am+1] = LoadFont("Common Normal") .. {
				InitCommand = function(self) self:x(200):y(11):zoom(0.18):halign(1):diffuse(color("0.5,0.5,0.5,1")):settext("40+") end
			}
			
			return am
		end)()
	}
}

-- ============================================================
-- CURRENT SELECTION DISPLAY
-- ============================================================
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "CurrentLabel",
	InitCommand = function(self)
		self:xy(swatchStartX + totalSwatchW/2 - swatchSize/2, swatchStartY + 4 * (swatchSize + swatchGapY) + 20):zoom(0.32)
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
