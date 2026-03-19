-- Holographic Void: NPS Calculator
-- Ported from spawncamping-wallhack
-- Time-based moving average with ActorMultiVertex graph display

local pn = GAMESTATE:GetEnabledPlayers()[1]
local countNotesSeparately = GAMESTATE:CountNotesSeparately()

-- Check preferences
if not HV.ShowNPS() then
	return Def.ActorFrame {}
end

-- Window sizes from ThemePrefs instead of hardcoded
local function getWindowSize()
	return tonumber(ThemePrefs.Get("HV_NPSWindowSize")) or 1.5
end
local npsWindow = getWindowSize()
local minWindow = 0.5 

-- HV Specific Styling & Position
local graphWidth = 140
local graphHeight = 50
local graphX = 10
local graphY = SCREEN_CENTER_Y + 100
local fontZoom = 0.65
local accentColor = HVColor.Accent or color("#00CFFF")

-- Graph settings
local initialPeak = 1 -- Set lower so easy songs don't look broken
local maxVerts = 150
local graphFreq = 0.2

local noteTable = {}
local lastJudgment = "TapNoteScore_None"
local noteSum = 0
local peakNPS = 0
local curNPS = 0

-- Cached UI references
local npsTextActor = nil

local function addNote(time, size)
	if countNotesSeparately then size = 1 end
	noteTable[#noteTable + 1] = {time, size}
	noteSum = noteSum + size
end

local function removeNote()
	local exit = false
	while not exit do
		if #noteTable >= 1 then
			-- Calculate time since start (mimicking GetTimeSinceStart for gameplay)
			local currentTime = GAMESTATE:GetSongPosition():GetMusicSeconds() / getCurRateValue()
			local noteTime = noteTable[1][1]
			if noteTime + npsWindow < currentTime then
				noteSum = noteSum - noteTable[1][2]
				table.remove(noteTable, 1)
			else
				exit = true
			end
		else
			exit = true
		end
	end
end

local function getCurNPS()
	local musicSeconds = math.max(0, GAMESTATE:GetSongPosition():GetMusicSeconds() / getCurRateValue())
	return noteSum / clamp(musicSeconds, minWindow, npsWindow)
end

local function Update(self)
	removeNote()
	curNPS = getCurNPS()

	-- Track peak NPS from the start of the song
	peakNPS = math.max(peakNPS, curNPS)
	
	if npsTextActor then
		npsTextActor:settextf("NPS: %0.0f  Peak: %0.0f", curNPS, peakNPS)
	end
end

local t = Def.ActorFrame {
	Name = "NPSCalcContainer",
	OnCommand = function(self)
		self:SetUpdateFunction(Update)
	end,
	
	-- Judgment hook
	Def.Actor {
		JudgmentMessageCommand = function(self, params)
			local notes = params.Notes
			local chordsize = 0
			if params.Player == pn and params.Type == "Tap" then
				if GAMESTATE:GetCurrentGame():CountNotesSeparately() then
					chordsize = 1
				else
					for i = 1, GAMESTATE:GetCurrentStyle():ColumnsPerPlayer() do
						if notes ~= nil and notes[i] ~= nil then
							chordsize = chordsize + 1
						end
					end
				end
				local currentTime = GAMESTATE:GetSongPosition():GetMusicSeconds() / getCurRateValue()
				addNote(currentTime, chordsize)
				lastJudgment = params.TapNoteScore
			end
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_NPSWindowSize" then
				npsWindow = getWindowSize()
			end
		end
	}
}

-- Text Container
t[#t + 1] = Def.ActorFrame {
	Name = "NPSTextContainer",
	InitCommand = function(self)
		self:xy(graphX, graphY - 5):zoom(fontZoom)
	end,
	LoadFont("Common Normal") .. {
		Name = "Text",
		InitCommand = function(self)
			self:halign(0):valign(1):diffuse(accentColor)
			self:settext("NPS: 0  Peak: 0")
			npsTextActor = self
		end
	}
}

-- Graph Container
local verts = {{{0, 0, 0}, Color.White}}
local total = 1
local graphPeakNPS = initialPeak

local graphVerts = Def.ActorFrame {
	Name = "NPSGraph",
	InitCommand = function(self)
		self:xy(graphX, graphY)
	end,
	
	-- Background Quad
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(graphWidth, graphHeight)
			self:xy(0, graphHeight)
			self:diffuse(color("0.03,0.03,0.03")):diffusealpha(0.7)
			self:halign(0):valign(1)
		end
	},
	
	-- Top Line
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(graphWidth, 1)
			self:xy(0, 0)
			self:diffusealpha(0.2)
			self:halign(0)
		end
	},

	-- Base Line
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(graphWidth, 1)
			self:xy(0, graphHeight)
			self:diffusealpha(0.5)
			self:halign(0)
		end
	},

	-- AMV Graph
	Def.ActorMultiVertex {
		Name = "AMV_QuadStrip",
		InitCommand = function(self)
			self:visible(true)
			self:xy(graphWidth, graphHeight)
			self:SetDrawState {Mode = "DrawMode_LineStrip"}
		end,
		BeginCommand = function(self)
			peakNPS = 0
			graphPeakNPS = initialPeak
			self:SetDrawState {First = 1, Num = -1}
			self:SetVertices(verts)
			self:queuecommand("GraphUpdate")
		end,
		GraphUpdateCommand = function(self)
			total = total + 1
			-- ensure we keep scaling appropriately
			if peakNPS > graphPeakNPS then
				for i = 1, #verts do
					verts[i][1][2] = verts[i][1][2] * (graphPeakNPS / peakNPS)
				end
				graphPeakNPS = peakNPS
			end
			
			local currentPeak = math.max(graphPeakNPS, initialPeak)
			verts[#verts + 1] = {{total * (graphWidth / maxVerts), -curNPS / currentPeak * graphHeight, 0}, accentColor}
			
			if #verts > maxVerts + 2 then
				table.remove(verts, 1)
			end
			self:SetVertices(verts)
			self:addx(-graphWidth / maxVerts)
			self:SetDrawState {First = math.max(1, #verts - maxVerts), Num = math.min(maxVerts, #verts)}
			self:sleep(graphFreq)
			self:queuecommand("GraphUpdate")
		end
	}
}

t[#t + 1] = graphVerts

return t
