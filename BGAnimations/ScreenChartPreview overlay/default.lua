--- Holographic Void: ScreenChartPreview Overlay (RE-IMPLEMENTED)
-- Full UI logic from spawncamping-wallhack with HV Aesthetics and Embedded Sync.

local pn = GAMESTATE:GetEnabledPlayers()[1]
local song = GAMESTATE:GetCurrentSong()
local steps = GAMESTATE:GetCurrentSteps()

-- Global state managed by SSM
local ssm = nil
local musicratio = 1
local snapGraph = nil
local densityGraph = nil
local previewType = 1
local musicLength = 0
local musicPaused = false
local inputCallback = nil

-- References for sync
local noteFieldRef = nil
local progressRef = nil
local cdgFrameRef = nil
local rootRef = nil

-- HV Color Palette
local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local white = color("1,1,1,1")
local bgCard = color("0.06,0.06,0.06,0.95")

-- Layout constants
local frameWidth = SCREEN_WIDTH/2 - 40
local frameHeight = 340
local densityGraphWidth = 80
local verticalSpacing = 7
local horizontalSpacing = 10

local validStepsType = {
	'StepsType_Dance_Single',
	'StepsType_Dance_Solo',
	'StepsType_Dance_Double',
}
local stepsTable = {}
local curStepIndex = 0

local function findCurStepIndex(givenSteps)
	if not givenSteps then return 0 end
	for i = 1, #stepsTable do
		if stepsTable[i]:GetChartKey() == givenSteps:GetChartKey() then
			return i
		end
	end
	return 0
end

local function meterComparator(stepA, stepB)
	return Enum.Reverse(Difficulty)[stepA:GetDifficulty()] < Enum.Reverse(Difficulty)[stepB:GetDifficulty()]
end

-- HV Helper fallbacks
local function getDifficulty(diff)
	if not diff then return "" end
	return ToEnumShortString(diff):gsub("Difficulty_", "")
end

local function getDifficultyColor(diff)
	return HVColor and HVColor.GetDifficultyColor(diff) or white
end

local function GetCustomDifficulty(stype, diff)
	return diff
end

local function getSongLengthColor(len)
	return HVColor and HVColor.GetSongLengthColor(len) or white
end

function getMSDColor(msd)
	if not msd or msd == 0 then return dimText end
	return (HVColor and HVColor.GetMSDRatingColor) and HVColor.GetMSDRatingColor(msd) or white
end

-- Helper: check if mouse is over an actor
local function isOver(self)
	if not self or not self:GetVisible() then return false end
	local mx = INPUTFILTER:GetMouseX()
	local my = INPUTFILTER:GetMouseY()
	local x = self:GetTrueX()
	local y = self:GetTrueY()
	local w = self:GetZoomedWidth()
	local h = self:GetZoomedHeight()

	-- Quads and most actors are centered (0.5) in Etterna unless specified.
	-- Since GetHAlign isn't always available, we handle common alignments manually or fallback.
	local name = self:GetName()
	local ha = 0.5
	local va = 0.5
	
	if name == "PreviewClickable" or name == "PreviewSeek" then
		ha = 0
		va = 0
	end

	return mx >= x - (w * ha) and mx <= x + (w * (1 - ha)) and
	       my >= y - (h * va) and my <= y + (h * (1 - va))
end

------------------------------------------------------------
-- AUDIO CONTROL (Embedded)
------------------------------------------------------------
local function updateMusicSync(self)
	if not ssm then return end
	local ok, pos = pcall(function() return ssm:GetSampleMusicPosition() end)
	if not ok or not pos then return end
	
	-- Sync NoteField
	if noteFieldRef and noteFieldRef.SetSeconds then
		noteFieldRef:SetSeconds(pos)
	end

	-- Sync Progress Bar
	if progressRef then
		local h = math.min(pos / (musicLength / math.max(1, frameHeight - 20)), frameHeight - 20)
		progressRef:stoptweening():zoomto(densityGraphWidth, math.max(0, h))
	end
	
	-- Sync Seek Bar
	if cdgFrameRef then
		local seek = cdgFrameRef:GetChild("PreviewSeek")
		local click = cdgFrameRef:GetChild("PreviewClickable")
		if seek and click then
			if isOver(click) then
				seek:visible(true):y(20 + (INPUTFILTER:GetMouseY() - cdgFrameRef:GetTrueY()))
			else
				seek:visible(true):y(20 + pos / (musicLength / math.max(1, frameHeight - 20)))
			end
		end
	end
end

------------------------------------------------------------
-- INPUT HANDLING
------------------------------------------------------------
local function input(event)
	if event.type ~= "InputEventType_FirstPress" then return false end
	local btn = event.DeviceInput.button
	if not ssm then return false end

	-- Left-click detection
	if btn == "DeviceButton_left mouse button" then
		if not rootRef or not rootRef:GetVisible() then return false end

		-- Difficulty List (MSD Buttons)
		local listRow = rootRef:GetChild("DifficultyListRow")
		if listRow then
			for i=1, 8 do
				local btnFrame = listRow:GetChild("DiffButton"..i)
				if btnFrame and btnFrame:GetVisible() then
					local quad = btnFrame:GetChild("Dot"..i)
					if quad and isOver(quad) and stepsTable[i] then
						GAMESTATE:SetCurrentSteps(stepsTable[i])
						MESSAGEMAN:Broadcast("ChartPreviewOn")
						return true
					end
				end
			end
		end

		-- Rate Buttons
		local bpmRow = rootRef:GetChild("BPMRow")
		if bpmRow then
			local d = bpmRow:GetChild("Dec")
			local i = bpmRow:GetChild("Inc")
			if d and isOver(d) then 
				MESSAGEMAN:Broadcast("PrevRate")
				return true 
			end
			if i and isOver(i) then 
				MESSAGEMAN:Broadcast("NextRate")
				return true 
			end
		end

		-- Seek on CDG
		if cdgFrameRef then
			local click = cdgFrameRef:GetChild("PreviewClickable")
			if click and isOver(click) then
				local my = INPUTFILTER:GetMouseY()
				local fy = cdgFrameRef:GetTrueY() + 20
				ssm:SetSampleMusicPosition(math.max(0, math.min((my - fy) * musicratio, musicLength)))
				return true
			end
		end

		-- Capture all other left clicks to prevent 'escaping' to main screen wheel
		return true
	end

	-- Mouse wheel: seek
	if (btn == "DeviceButton_mousewheel up" or btn == "DeviceButton_mousewheel down") then
		if cdgFrameRef and isOver(cdgFrameRef:GetChild("PreviewClickable")) then
			local ok, pos = pcall(function() return ssm:GetSampleMusicPosition() end)
			if ok and pos then
				local dir = (btn == "DeviceButton_mousewheel up") and -1.0 or 1.0
				ssm:SetSampleMusicPosition(math.max(0, math.min(musicLength, pos + dir)))
			end
			return true
		end
	end

	-- Right-click: pause
	if btn == "DeviceButton_right mouse button" then
		ssm:PauseSampleMusic()
		musicPaused = not musicPaused
		MESSAGEMAN:Broadcast("MusicPauseToggled")
		return true
	end

	return false
end

------------------------------------------------------------
-- UI COMPONENTS (HV Themed)
------------------------------------------------------------

local function topRow()
	local fw = SCREEN_WIDTH - 20
	local fh = 55
	return Def.ActorFrame {
		Name = "TopRow",
		Def.Quad { InitCommand = function(self) self:zoomto(fw, fh):diffuse(bgCard) end },
		Def.Sprite {
			Name = "Banner",
			ReloadCommand = function(self)
				local bnpath = song:GetBannerPath() or THEME:GetPathG("Common", "fallback banner")
				self:LoadBackground(bnpath):scaletoclipped(140, 40):x(-fw/2 + 5):halign(0)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SongTitle",
			ReloadCommand = function(self)
				self:settext(song:GetMainTitle()):xy(-fw/2 + 155, -14):zoom(0.5):halign(0):diffuse(brightText)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Artist",
			ReloadCommand = function(self)
				self:settext(song:GetDisplayArtist()):xy(-fw/2 + 155, 2):zoom(0.32):halign(0):diffuse(subText)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "NoteCount",
			ReloadCommand = function(self)
				local notes = steps:GetRadarValues(pn):GetValue("RadarCategory_Notes")
				self:settextf("%d Notes", notes):xy(-fw/2 + 155, 14):zoom(0.3):halign(0):diffuse(dimText)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Duration",
			ReloadCommand = function(self)
				local length = song:GetStepsSeconds()/getCurRateValue()
				self:xy(fw/2 - 220, -14):settext(SecondsToMSS(length)):zoom(0.4):halign(1):diffuse(getSongLengthColor(length))
			end
		},
		-- Large MSD Display
		Def.ActorFrame {
			Name = "ChartInfoFrame",
			InitCommand = function(self) self:xy(fw/2 - 10, 0) end,
			LoadFont("Common Normal") .. {
				Name = "FullInfo",
				ReloadCommand = function(self)
					self:xy(0, -12):zoom(0.35):halign(1):diffuse(subText)
					local stype = steps:GetStepsType()
					local diff = steps:GetDifficulty()
					self:settext(ToEnumShortString(stype):gsub("_", " ") .. " " .. getDifficulty(diff))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "LargeMSD",
				ReloadCommand = function(self)
					local msd = steps:GetMSD(getCurRateValue(), 1)
					if msd > 0 then
						self:settextf("%.2f", msd):xy(0, 10):zoom(0.8):halign(1):diffuse(getMSDColor(msd))
					else
						self:settext(steps:GetMeter()):xy(0, 10):zoom(0.8):halign(1):diffuse(dimText)
					end
				end
			}
		}
	}
end

local diffShorthands = {
	Beginner = "BG", Easy = "EZ", Medium = "MD", Hard = "HD", Challenge = "CH", Edit = "ED"
}

local function stepsListRow()
	local fh = 36
	local rowT = Def.ActorFrame {
		Name = "DifficultyListRow",
		ReloadCommand = function(self)
			stepsTable = song:GetStepsByStepsType(steps:GetStepsType())
			table.sort(stepsTable, meterComparator)
			curStepIndex = findCurStepIndex(steps)
			self:RunCommandsOnChildren(function(self) self:playcommand("Update") end)
		end
	}
	
	for i = 1, 8 do
		rowT[#rowT+1] = Def.ActorFrame {
			Name = "DiffButton"..i,
			InitCommand = function(self) self:x((i-1)*66 - (3.5*66)) end,
			Def.Quad {
				Name = "Dot"..i,
				InitCommand = function(self) self:zoomto(64, fh):diffuse(bgCard):diffusealpha(0.8) end,
				UpdateCommand = function(self)
					local s = stepsTable[i]
					if s then
						local isCur = (s:GetChartKey() == steps:GetChartKey())
						local diff = s:GetDifficulty()
						self:visible(true):diffuse(HVColor.GetDifficultyColor(diff))
						self:diffusealpha(isCur and 0.8 or 0.2)
					else
						self:visible(false)
					end
				end
			},
			-- Large MSD text as main label (properly colored by rating)
			LoadFont("Common Normal") .. {
				Name = "MSDLabel",
				InitCommand = function(self) self:y(-4):zoom(0.45):diffuse(brightText) end,
				UpdateCommand = function(self)
					local s = stepsTable[i]
					if s then
						local msd = s:GetMSD(getCurRateValue(), 1)
						local displayMsd = math.floor(msd * 100) / 100
						if displayMsd == 0 then displayMsd = s:GetMeter() end
						self:settext(displayMsd):visible(true)
						
						-- Color MSD text by rating
						local mColor = getMSDColor(msd)
						self:diffuse(mColor)
					else
						self:visible(false)
					end
				end
			},
			-- Shorthand Difficulty under it
			LoadFont("Common Normal") .. {
				Name = "DiffShorthand",
				InitCommand = function(self) self:y(10):zoom(0.25):diffuse(subText) end,
				UpdateCommand = function(self)
					local s = stepsTable[i]
					if s then
						local diffName = ToEnumShortString(s:GetDifficulty())
						self:settext(diffShorthands[diffName] or diffName:sub(1,2):upper()):visible(true)
					else
						self:visible(false)
					end
				end
			}
		}
	end
	return rowT
end

local function stepsBPMRow()
	local fh = 40
	return Def.ActorFrame {
		Name = "BPMRow",
		ReloadCommand = function(self) self:RunCommandsOnChildren(function(self) self:playcommand("Update") end) end,
		
		-- Rate Change Arrows (Left)
		Def.Quad {
			Name = "Dec",
			InitCommand = function(self) self:x(-95):zoomto(45, fh):diffusealpha(0) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:x(-95):settext("<"):zoom(0.5):diffuse(brightText) end,
			UpdateCommand = function(self)
				local d = self:GetParent():GetChild("Dec")
				self:diffuse(isOver(d) and accentColor or brightText)
			end
		},
		
		-- BPM & Rate Text
		LoadFont("Common Normal") .. {
			Name = "BPMText",
			UpdateCommand = function(self)
				local rate = getCurRateValue()
				local bpm = (steps and steps:GetDisplayBpms()[2] or 150) * rate
				self:settextf("%.0f BPM (%.2fx)", bpm, rate):zoom(0.4):diffuse(brightText)
			end
		},

		-- Rate Change Arrows (Right)
		Def.Quad {
			Name = "Inc",
			InitCommand = function(self) self:x(95):zoomto(45, fh):diffusealpha(0) end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:x(95):settext(">"):zoom(0.5):diffuse(brightText) end,
			UpdateCommand = function(self)
				local i = self:GetParent():GetChild("Inc")
				self:diffuse(isOver(i) and accentColor or brightText)
			end
		}
	}
end

local function sidePanel()
	local fw = 200
	local fh = frameHeight or 340
	local skillsets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}
	local radarCategories = {
		{"Taps", "RadarCategory_Notes"}, {"Jumps", "RadarCategory_Jumps"}, {"Hands", "RadarCategory_Hands"},
		{"Holds", "RadarCategory_Holds"}, {"Rolls", "RadarCategory_Rolls"}, {"Mines", "RadarCategory_Mines"},
	}
	
	local t = Def.ActorFrame {
		Name = "SidePanel",
		ReloadCommand = function(self) self:RunCommandsOnChildren(function(s) s:playcommand("Update") end) end,
		Def.Quad { InitCommand = function(self) self:zoomto(fw, fh):diffuse(bgCard):diffusealpha(0.8) end },
	}

	-- Notes Section
	local notesSection = Def.ActorFrame {
		InitCommand = function(self) self:xy(-fw/2 + 10, -fh/2 + 15) end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.35):halign(0):diffuse(accentColor):settext("[ NOTES ]") end
		},
	}
	for i, v in ipairs(radarCategories) do
		notesSection[#notesSection+1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:y(15 + (i-1)*14):zoom(0.32):halign(0):diffuse(subText) end,
			UpdateCommand = function(self)
				local val = steps:GetRadarValues(pn):GetValue(v[2])
				self:settextf("%s: %d", v[1], val)
			end
		}
	end
	t[#t+1] = notesSection

	-- Skillsets Section
	local skillsetSection = Def.ActorFrame {
		InitCommand = function(self) self:xy(-fw/2 + 10, -fh/2 + 120) end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.35):halign(0):diffuse(accentColor):settext("[ SKILLSETS ]") end
		},
	}
	for i, ss in ipairs(skillsets) do
		skillsetSection[#skillsetSection+1] = LoadFont("Common Normal") .. {
			InitCommand = function(self) self:y(15 + (i-1)*17):zoom(0.35):halign(0):diffuse(subText) end,
			UpdateCommand = function(self)
				local val = steps:GetMSD(getCurRateValue(), i)
				if val > 0 then
					self:settextf("%s: %.2f", ss, val):diffuse(getMSDColor(val))
				else
					self:settext(ss .. ": -"):diffuse(dimText)
				end
			end
		}
	end
	t[#t+1] = skillsetSection
	return t
end

local sp = sidePanel()

------------------------------------------------------------
-- ROOT ACTORFRAME
------------------------------------------------------------
local t = Def.ActorFrame {
	Name = "ChartPreviewRoot",
	InitCommand = function(self) rootRef = self; self:SetUpdateFunction(updateMusicSync) end,
	ChartPreviewOnMessageCommand = function(self)
		ssm = SCREENMAN:GetTopScreen()
		song = GAMESTATE:GetCurrentSong()
		steps = GAMESTATE:GetCurrentSteps()
		if not song or not steps then return end
		musicLength = song:GetLastSecond()
		musicratio = musicLength / math.max(1, frameHeight - 20)
		if not inputCallback then
			inputCallback = function(event) return input(event) end
			ssm:AddInputCallback(inputCallback)
		end
		self:visible(true):playcommand("Reload")
	end,
	ChartPreviewOffMessageCommand = function(self)
		self:visible(false)
		if ssm and inputCallback then ssm:RemoveInputCallback(inputCallback); inputCallback = nil end
	end,
	ReloadCommand = function(self) self:RunCommandsOnChildren(function(self) self:playcommand("Reload") end) end,
	RateChangedMessageCommand = function(self) self:playcommand("Reload") end,
	CurrentRateChangedMessageCommand = function(self) self:playcommand("Reload") end,
	CodeMessageCommand = function(self, params) if params.Name == "NextRate" or params.Name == "PrevRate" then self:playcommand("Reload") end end,

	-- Full screen dim
	Def.Quad { InitCommand = function(self) self:FullScreen():diffuse(color("0,0,0,0.85")) end },

	-- Top row
	topRow() .. { InitCommand = function(self) self:xy(SCREEN_CENTER_X, 40) end },

	-- Difficulty Bar
	stepsListRow() .. { InitCommand = function(self) self:xy(SCREEN_CENTER_X - 60, 95) end },
	
	-- Rate Bar
	stepsBPMRow() .. { InitCommand = function(self) self:xy(SCREEN_CENTER_X + 260, 95) end },

	-- Favorite Star
	LoadActor(THEME:GetPathG("", "round_star")) .. {
		InitCommand = function(self) self:zoom(0.3):diffuse(Color.Yellow):wag() end,
		ReloadCommand = function(self) self:visible(song:IsFavorited()):xy(SCREEN_CENTER_X - SCREEN_WIDTH/2 + 20, 40) end
	},

	-- Side Panel (Left)
	sp .. { InitCommand = function(self) self:xy(SCREEN_CENTER_X - frameWidth/2 - 90, SCREEN_CENTER_Y + 50) end },

	-- NoteField Preview (Center)
	Def.ActorFrame {
		Name = "NoteFieldFrame",
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 50) end,
		Def.Quad { InitCommand = function(self) self:zoomto(frameWidth - 60, frameHeight):diffuse(bgCard) end },
		Def.NoteFieldPreview {
			Name = "NoteField",
			DrawDistanceBeforeTargetsPixels = 800, DrawDistanceAfterTargetsPixels = 0,
			InitCommand = function(self) self:zoom(0.6):xy(0, 50):draworder(100) end,
			OnCommand = function(self) noteFieldRef = self end,
			ReloadCommand = function(self) if steps then self:LoadNoteData(steps) end end
		}
	},

	-- Density Graph (Right)
	Def.ActorFrame {
		Name = "CDGFrame",
		InitCommand = function(self) self:xy(SCREEN_CENTER_X + frameWidth/2 - 10, SCREEN_CENTER_Y + 50 - frameHeight/2); cdgFrameRef = self end,
		Def.Quad { InitCommand = function(self) self:zoomto(densityGraphWidth, frameHeight):halign(0):valign(0):diffuse(bgCard) end },
		Def.Quad {
			Name = "PreviewProgress",
			InitCommand = function(self) self:xy(0, 20):zoomto(densityGraphWidth, 0):halign(0):valign(0):diffuse(accentColor):diffusealpha(0.3); progressRef = self end
		},
		-- Graph NPS Text
		LoadFont("Common Normal") .. {
			Name = "NPSText",
			InitCommand = function(self) self:xy(densityGraphWidth/2, 10):zoom(0.35):diffuse(subText) end
		},
		-- AMV Graph
		Def.ActorMultiVertex {
			Name = "ChordDensityGraph",
			ReloadCommand = function(self)
				local rate = math.max(MIN_MUSIC_RATE, getCurRateValue())
				local graphVectors = steps:GetCDGraphVectors(rate)
				if not graphVectors then self:SetVertices({}):SetDrawState({Mode="DrawMode_Quads", First=0, Num=0}) return end
				local npsVector = graphVectors[1]
				local nRows = #npsVector
				local rHeight = (frameHeight - 20) / nRows
				local mNPS = 0
				for i=1, #npsVector do if npsVector[i]*2 > mNPS then mNPS = npsVector[i]*2 end end
				self:GetParent():GetChild("NPSText"):settext(string.format("%.0f Max NPS", mNPS/2))
				local mWidth = densityGraphWidth / math.max(1, mNPS)
				local verts, nCols = {}, steps:GetNumColumns()
				for d=1, nCols do
					for r=1, nRows do
						if graphVectors[d][r] > 0 then
							local val = 0.1 + (nCols - (d-1)) * (0.6 / nCols)
							local c = color(val..","..val..","..val..",1")
							local x, y = 0, 20 + (r-1)*rHeight
							local bh, bw = graphVectors[d][r]*2*mWidth, rHeight
							verts[#verts+1] = {{x, y, 0}, c}
							verts[#verts+1] = {{x+bh, y, 0}, c}
							verts[#verts+1] = {{x+bh, y+bw, 0}, c}
							verts[#verts+1] = {{x, y+bw, 0}, c}
						end
					end
				end
				self:SetVertices(verts):SetDrawState({Mode="DrawMode_Quads", First=1, Num=#verts})
			end
		},
		-- Interactions
		Def.Quad { Name = "PreviewClickable", InitCommand = function(self) self:zoomto(densityGraphWidth, frameHeight-20):xy(0, 20):halign(0):valign(0):diffusealpha(0) end },
		Def.Quad { Name = "PreviewSeek", InitCommand = function(self) self:zoomto(densityGraphWidth, 1):halign(0):diffuse(accentColor) end }
	}
}

return t
