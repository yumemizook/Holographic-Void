local curSong = nil
local start = math.max(0, HV.LastPlayedSecond or 0)
local delay = 0.02
local startFromPreview = true
local previewMode = ThemePrefs.Get("HV_SongPreview") or 1
local loop = previewMode == 2
local curPath = ""
local sampleStart = 0
local musicLength = 0
local loops = 0
local musicNotPaused = 1
local sampleEvent = false

-- Use a more robust check for chart preview mode
local function isChartPreviewActive()
	return (SCREENMAN:GetTopScreen() and SCREENMAN:GetTopScreen():GetName() == "ScreenChartPreview")
		or (HV and HV.ChartPreviewActive)
end

HV.LastPlayedSecond = 0

local deltaSum = 0
local function playMusic(self, delta)
	deltaSum = deltaSum + delta * musicNotPaused

	local tscr = SCREENMAN:GetTopScreen()
	if not tscr or tscr:GetName() ~= "ScreenSelectMusic" then return end

	local curPos = GAMESTATE:GetSongPosition():GetMusicSeconds()

	-- If we are in the middle of the preview (part 1) and it's not looping,
	-- trigger the transition to part 2 when it nears the end.
	if loops == 1 and not loop and curPos >= musicLength - 0.2 and musicLength > 0 then
		goNow = true
	end

	-- dont override sample music with this if in chart preview mode
	if isChartPreviewActive() then 
		return 
	end

	-- Fallback: arm sampleEvent if PlayingSampleMusic never fired.
	-- In normal wheel navigation PlayingSampleMusic arrives within ~1-2 frames.
	-- When returning from the evaluation screen the wheel is already settled so
	-- Etterna never re-fires PlayingSampleMusic — catch that with a 0.4s timeout.
	-- Sanity: only fire if curSong and curPath are actually valid.
	if not sampleEvent and loops == 0 and curSong and curPath and curPath ~= ""
		and deltaSum > 0.4 then
		sampleEvent = true
	end

	-- Initial start or transition trigger
	if (deltaSum > delay and sampleEvent and loops == 0) or (goNow and not isChartPreviewActive()) then
		goNow = false
		if tscr:GetMusicWheel():IsSettled() and loops <= 1 then
			if curSong and curPath then
				if startFromPreview then -- When starting from preview point
					local duration = musicLength - sampleStart
					SOUND:PlayMusicPart(curPath, sampleStart, duration, 2, 2, loop, true, true)
					if ThemePrefs.Get("HV_SongPreview") == 3 then
						startFromPreview = false
					end
				else -- When starting from start or from exit point.
					local duration = musicLength - start
					-- If this is the second part of Mode 3, let it loop
					local shouldLoop = (ThemePrefs.Get("HV_SongPreview") == 3) or loop
					SOUND:PlayMusicPart(curPath, start, duration, 2, 2, shouldLoop, true, not (loops == 1))
					start = 0
					if ThemePrefs.Get("HV_SongPreview") == 2 then
						startFromPreview = true
					end
				end
				loops = loops + 1
				-- Always use a small interval to monitor position instead of sleeping
				self:SetUpdateFunctionInterval(0.025)
			end
		end
	else
		-- Ensure we keep polling frequently if we are waiting for a transition
		self:SetUpdateFunctionInterval(0.025)
	end
end

local t = Def.ActorFrame{
	InitCommand = function(self)
		if ThemePrefs.Get("HV_SongPreview") ~= 1 then
			self:SetUpdateFunction(playMusic)
			-- Initial arming if a song is already selected (e.g. returning to screen)
			self:playcommand("CurrentSongChanged")
		end
	end,
	CurrentSongChangedMessageCommand = function(self)
		musicNotPaused = 1
		goNow = false
		loops = 0
		SOUND:StopMusic()
		deltaSum = 0
		curSong = GAMESTATE:GetCurrentSong()
		if curSong ~= nil then
			curPath = curSong:GetMusicPath()
			if not curPath then
				sampleEvent = false
				return
			end
			sampleStart = curSong:GetSampleStart()
			musicLength = curSong:MusicLengthSeconds()
			startFromPreview = start == 0
			-- Do NOT arm sampleEvent here — PlayingSampleMusic does it for normal
			-- wheel navigation. For eval-return (where PlayingSampleMusic never
			-- fires), the 0.4s fallback timer in playMusic handles it instead.
			sampleEvent = false
			if ThemePrefs.Get("HV_SongPreview") ~= 1 then
				self:SetUpdateFunctionInterval(0.002)
			end
		else
			sampleEvent = false
		end
	end,
	PlayingSampleMusicMessageCommand = function(self)
		local nah = isChartPreviewActive()

		musicNotPaused = 1
		goNow = false
		sampleEvent = true
		loops = 0
		deltaSum = 0
		if not nah and ThemePrefs.Get("HV_SongPreview") ~= 1 then
			self:SetUpdateFunctionInterval(0.002)
			SOUND:StopMusic()
		end
	end,
	CurrentRateChangedMessageCommand = function(self)
		-- Removed StopMusic and restart to allow real-time rate update by the engine.
		-- Position-based monitor in playMusic handles transitions if needed.
	end,
	PreviewNoteFieldDeletedMessageCommand = function(self)
		musicNotPaused = 1
		goNow = false
		sampleEvent = true
		loops = 0
		if ThemePrefs.Get("HV_SongPreview") ~= 1 then
			self:SetUpdateFunctionInterval(0.002)
			SOUND:StopMusic()
		end
	end,
	ChartPreviewOnMessageCommand = function(self)
		self.stoppedForPreview = true
		SOUND:StopMusic()
	end,
	ChartPreviewOffMessageCommand = function(self)
		self.stoppedForPreview = false
	end
}

return t
