--- Holographic Void: ScreenChartPreview Overlay
-- Ported from spawncamping-wallhack for high-level chart analysis.
-- Features: Vertical chord density graph, NoteField rendering, scrollable sample music.

local pn = GAMESTATE:GetEnabledPlayers()[1]
local song = GAMESTATE:GetCurrentSong()
local steps = GAMESTATE:GetCurrentSteps()
if not song or not steps then return Def.ActorFrame {} end

local musicratio = 1
local previewX = SCREEN_CENTER_X - 100
local previewY = SCREEN_CENTER_Y
local previewW = 320
local previewH = SCREEN_HEIGHT * 0.85
local densityGraphWidth = 80

-- Colors
local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local bgCard = color("0,0,0,0.8")

local function input(event)
	if event.type == "InputEventType_FirstPress" then
		if event.button == "Back" or event.button == "Start" or event.DeviceInput.button == "DeviceButton_space" then
			SCREENMAN:GetTopScreen():Cancel()
		end

		if event.DeviceInput.button == "DeviceButton_p" then
			local ok, paused = pcall(function() return SCREENMAN:GetTopScreen():IsSampleMusicPaused() end)
			if ok then
				SCREENMAN:GetTopScreen():PauseSampleMusic()
				MESSAGEMAN:Broadcast("MusicPauseToggled")
			end
		end

		-- Rate changes (EffectUp/Down)
		if event.button == "EffectUp" then
			changeMusicRate(0.05)
		elseif event.button == "EffectDown" then
			changeMusicRate(-0.05)
		end
	end
	return false
end

local function update(self)
	local tscr = SCREENMAN:GetTopScreen()
	if not tscr or not tscr.GetSampleMusicPosition then return end
	
	local pos = tscr:GetSampleMusicPosition() / musicratio
	local posBar = self:GetChild("PreviewProgress")
	if posBar then
		posBar:zoomto(densityGraphWidth, math.min(pos, previewH))
	end
	
	-- Update seek line if hovering
	local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
	local gx = SCREEN_WIDTH - densityGraphWidth - 20
	local gy = (SCREEN_HEIGHT - previewH)/2
	
	local seek = self:GetChild("PreviewSeek")
	if mx >= gx and mx <= gx + densityGraphWidth and my >= gy and my <= gy + previewH then
		seek:visible(true):y(my - SCREEN_CENTER_Y)
	else
		seek:visible(false)
	end
end

local t = Def.ActorFrame {
	OnCommand = function(self)
		self:SetUpdateFunction(update)
		local tscr = SCREENMAN:GetTopScreen()
		if tscr then tscr:AddInputCallback(input) end
		
		-- Calculate music ratio: total length / graph height
		local lastSec = song:GetLastSecond()
		musicratio = lastSec / previewH
	end,
	
	-- Dark Background for the whole screen
	Def.Quad {
		InitCommand = function(self)
			self:FullScreen():diffuse(color("0,0,0,0.7"))
		end
	},

	-- Center Area: NoteField Preview
	Def.ActorFrame {
		Name = "NoteFieldArea",
		InitCommand = function(self)
			self:xy(previewX, previewY)
		end,
		
		-- Gray BG for notes
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(250, SCREEN_HEIGHT):diffuse(color("0.05,0.05,0.05,0.9"))
			end
		},
		
		Def.NoteFieldPreview {
			Name = "NoteField",
			InitCommand = function(self)
				self:zoom(1.0):draworder(90)
				self:LoadNoteData(steps)
			end
		},
		
		LoadFont("Common Large") .. {
			Name = "PauseText",
			InitCommand = function(self)
				self:zoom(0.5):diffuse(color("1,0,0,1")):settext("PAUSED"):visible(false)
			end,
			MusicPauseToggledMessageCommand = function(self)
				local ok, paused = pcall(function() return SCREENMAN:GetTopScreen():IsSampleMusicPaused() end)
				if ok then self:visible(paused) end
			end
		}
	},

	-- Top Bar: Song Info
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, 30)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(SCREEN_WIDTH - 40, 50):diffuse(bgCard)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-SCREEN_WIDTH/2 + 30, -10):halign(0):zoom(0.5):diffuse(brightText)
			end,
			OnCommand = function(self)
				self:settext(song:GetDisplayMainTitle())
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-SCREEN_WIDTH/2 + 30, 10):halign(0):zoom(0.3):diffuse(subText)
			end,
			OnCommand = function(self)
				self:settext(song:GetDisplayArtist() .. "  |  " .. ToEnumShortString(steps:GetDifficulty()) .. " " .. steps:GetMeter())
			end
		},
		-- Rate display
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(SCREEN_WIDTH/2 - 30, 0):halign(1):zoom(0.4):diffuse(accentColor)
			end,
			OnCommand = function(self) self:playcommand("Set") end,
			CurrentRateChangedMessageCommand = function(self) self:playcommand("Set") end,
			SetCommand = function(self)
				self:settext(getCurRateDisplayString())
			end
		}
	},

	-- Right Side: Chord Density Graph (Vertical)
	Def.ActorFrame {
		Name = "DensityGraphArea",
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - densityGraphWidth/2 - 20, SCREEN_CENTER_Y)
		end,
		
		-- Graph BG
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(densityGraphWidth, previewH):diffuse(bgCard)
			end
		},
		
		-- Progress Bar (Overlay)
		Def.Quad {
			Name = "PreviewProgress",
			InitCommand = function(self)
				self:zoomto(densityGraphWidth, 0):valign(0):y(-previewH/2)
				self:diffuse(color("0,1,0,0.3"))
			end
		},
		
		-- The actual graph
		LoadActor(THEME:GetPathB("", "_chorddensitygraph")) .. {
			InitCommand = function(self)
				-- We need to rotate/adjust the graph for vertical display if possible, 
				-- but our _chorddensitygraph is horizontal.
				-- For now, let's render it horizontal and rotate the actor frame.
				self:rotationz(-90):zoomto(previewH, densityGraphWidth):y(0)
				self:queuecommand("GraphUpdate")
			end
		},
		
		-- Clickable Area for Seek
		Def.Quad {
			Name = "MouseSeeker",
			InitCommand = function(self)
				self:zoomto(densityGraphWidth, previewH):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.button == "DeviceButton_left mouse button" then
					local my = INPUTFILTER:GetMouseY()
					local relativeY = my - (SCREEN_CENTER_Y - previewH/2)
					local seekPos = relativeY * musicratio
					pcall(function()
						SCREENMAN:GetTopScreen():SetSampleMusicPosition(seekPos)
					end)
				end
			end
		},
		
		-- Seek Line
		Def.Quad {
			Name = "PreviewSeek",
			InitCommand = function(self)
				self:zoomto(densityGraphWidth, 1):diffuse(color("1,1,1,0.8")):visible(false)
			end
		}
	},

	-- Bottom Help
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_HEIGHT - 20):zoom(0.25):diffuse(dimText)
			self:settext("Space/Esc: Close  |  P: Pause  |  +/-: Change Rate  |  Click graph to seek")
		end
	}
}

return t
