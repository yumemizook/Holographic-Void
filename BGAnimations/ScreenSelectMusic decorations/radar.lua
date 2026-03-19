local pn = GAMESTATE:GetEnabledPlayers()[1]

local RADAR_X, RADAR_Y = 0, 0
local RADAR_RADIUS, LABEL_OFFSET = 30, 6
local TWEEN_STEPS, TWEEN_TIME = 30, 0.12
local STEP_TIME = TWEEN_TIME / TWEEN_STEPS
local MAX_DISPLAY, MAX_OVERFLOW, OVERFLOW_K = 1.2, 2.5, 0.7
local POINTS_SCALE = 200 / MAX_DISPLAY
local CAP = 2.5

local categories = {
	{name=THEME:GetString("Radar", "POWER"),  color=color("#E0B080"), canOverflow=true},  -- Muted Orange
	{name=THEME:GetString("Radar", "CHAOS"),  color=color("#B898CF"), canOverflow=true},  -- Muted Purple
	{name=THEME:GetString("Radar", "HELL"),   color=color("#CF9898"), canOverflow=false}, -- Muted Red
	{name=THEME:GetString("Radar", "MACH"),   color=color("#80C0CF"), canOverflow=false}, -- Muted Cyan
	{name=THEME:GetString("Radar", "FREEZE"), color=color("#CFD198"), canOverflow=false}, -- Muted Yellow
	{name=THEME:GetString("Radar", "EARTH"),  color=color("#A0CFAB"), canOverflow=true},  -- Muted Green
}

local labelAlign = {
	{h=0.5, v=1,   dx=0,  dy=-2},
	{h=0,   v=0.5, dx=2,  dy=0},
	{h=0,   v=0.5, dx=2,  dy=0},
	{h=0.5, v=0,   dx=0,  dy=2},
	{h=1,   v=0.5, dx=-2, dy=0},
	{h=1,   v=0.5, dx=-2, dy=0},
}

local tooltipOffset = {
	{h=0.5, v=0, dx=0,  dy=-1},
	{h=0,   v=0, dx=2,  dy=4},
	{h=0,   v=0, dx=2,  dy=4},
	{h=0.5, v=0, dx=0,  dy=9},
	{h=1,   v=0, dx=-2, dy=4},
	{h=1,   v=0, dx=-2, dy=4},
}

local displayedValues = {0,0,0,0,0,0}
local oldValues       = {0,0,0,0,0,0}
local targetValues    = {0,0,0,0,0,0}
local rawValues       = {0,0,0,0,0,0}
local hellBreakdown   = {mines=0, lifts=0, rolls=0, fakes=0}

local displayedColor = {1,1,1,1}
local oldColor       = {1,1,1,1}
local targetColor    = {1,1,1,1}

local currentStep, previewVisible, hoverActive = 0, false, false
local tooltipActors, hellBreakdownActors = {}, {}
local hellBaseX, hellBaseY = 0, 0

-- helpers

local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function smoothstep(t) return t*t*(3-2*t) end
local function valueToPts(v) return v * POINTS_SCALE end

local function getHexPoint(i, r, cx, cy)
	local a = math.rad(-90 + (i-1)*60)
	return cx + r*math.cos(a), cy + r*math.sin(a)
end

local function lighten(c, f)
	return color(string.format("#%02x%02x%02x",
		math.min(math.floor(c[1]*f*255), 255),
		math.min(math.floor(c[2]*f*255), 255),
		math.min(math.floor(c[3]*f*255), 255)))
end

local function shadowOf(c)
	return color(string.format("#%02x%02x%02x",
		math.floor(c[1]*0.3*255), math.floor(c[2]*0.3*255), math.floor(c[3]*0.3*255)))
end

local function saturate(d, D, k)
	local num, den = 1-math.exp(-k*d), 1-math.exp(-k*D)
	return den > 0 and num/den or 0
end

local function segCurve(v, segs)
	if v <= segs[1].v then return (v / segs[1].v) * segs[1].scale end
	local pv, ps = segs[1].v, segs[1].scale
	for i = 2, #segs do
		local s = segs[i]
		if v <= s.v or i == #segs then
			return ps + (s.scale - ps) * saturate(v - pv, s.v - pv, s.k)
		end
		pv, ps = s.v, s.scale
	end
end

-- display curves

local function toDisplayValue(raw, idx)
	if raw <= MAX_DISPLAY then return raw end
	if not categories[idx].canOverflow then return MAX_DISPLAY end
	local excess = raw - MAX_DISPLAY
	local range = MAX_OVERFLOW - MAX_DISPLAY
	return MAX_DISPLAY + range * (1 - 1/(1 + excess*OVERFLOW_K))
end

local function powerDisplay(msd) return math.min(math.pow(msd, 1.4) / 100, CAP) end
local function msdscale(m) return powerDisplay(m) end

local function hellDisplay(raw)
	return segCurve(raw * POINTS_SCALE, {
		{v=1,    scale=1/POINTS_SCALE},
		{v=100,  scale=0.5,  k=0.01},
		{v=200,  scale=1.2,  k=0.015},
		{v=400,  scale=2.0,  k=0.001},
		{v=800, scale=2.5,  k=0.001},
	})
end

-- first segment guarantees any nonzero mach is visibl
local function machDisplay(raw)
	return segCurve(raw * POINTS_SCALE, {
		{v=1,   scale=0.15},
		{v=50,  scale=0.5,  k=0.12},
		{v=90,  scale=1.2,  k=0.08},
		{v=120,  scale=2.0,  k=0.03},
		{v=125, scale=2.5,  k=0.03},
	})
end

local function freezeDisplay(raw)
	return segCurve(raw * POINTS_SCALE, {
		{v=100,   scale=100/POINTS_SCALE},
		{v=1500,  scale=2.0,  k=0.0015},
		{v=10000, scale=4.0,  k=0.0001},
	})
end

-- tooltip fns
local displayFn = {
	function(raw) return math.pow(raw, 1.4) / 100 end,
	function(raw) return toDisplayValue(raw, 2) end,
	hellDisplay, machDisplay, freezeDisplay,
	function(raw) return toDisplayValue(raw, 6) end,
}

-- tooltip hover

local function showTooltips()
	if not HV.ShowMSD() then return end
	hoverActive = true
	for i = 1, 6 do
		if tooltipActors[i] then
			tooltipActors[i]:visible(i ~= 3 or rawValues[3] <= 0)
		end
	end
	local line = 0
	for _, a in ipairs(hellBreakdownActors) do
		if a.hasPct then
			a:xy(hellBaseX, hellBaseY + line*6):visible(true)
			line = line + 1
		else
			a:visible(false)
		end
	end
end

local function hideTooltips()
	hoverActive = false
	for i = 1, 6 do if tooltipActors[i] then tooltipActors[i]:visible(false) end end
	for _, a in ipairs(hellBreakdownActors) do a:visible(false) end
end

-- radar calculation

local function calculateRadarValues(steps, song)
	if not steps or not song then
		rawValues, hellBreakdown = {0,0,0,0,0,0}, {mines=0, lifts=0, rolls=0, fakes=0}
		return {0,0,0,0,0,0}
	end

	local rv = steps:GetRadarValues(pn)
	local noteCount = math.max(rv:GetValue('RadarCategory_TapsAndHolds'), 1)
	local holds  = rv:GetValue('RadarCategory_Holds')
	local rolls  = rv:GetValue('RadarCategory_Rolls')
	local mines  = rv:GetValue('RadarCategory_Mines')
	local fakes  = rv:GetValue('RadarCategory_Fakes')
	local lifts  = rv:GetValue('RadarCategory_Lifts')
	local jumps  = rv:GetValue('RadarCategory_Jumps')
	local hands  = rv:GetValue('RadarCategory_Hands')
	local length = math.max(steps:GetLengthSeconds(), 1)

	local rate       = HV.CurrentSongData.rate or 1
	local overall    = steps:GetMSD(rate, 1) or 0
	local jumpstream = steps:GetMSD(rate, 3) or 0
	local handstream = steps:GetMSD(rate, 4) or 0
	local stamina    = steps:GetMSD(rate, 5) or 0
	local jackspeed  = steps:GetMSD(rate, 6) or 0
	local chordjack  = steps:GetMSD(rate, 7) or 0
	local technical  = steps:GetMSD(rate, 8) or 0

	local truejumps, truehands, truequads = 0, 0, 0
	local gv = steps:GetCDGraphVectors(rate)
	if gv and gv[2] and gv[3] and gv[4] then
		truejumps = math.ceil(wifeMean(gv[2]) * #gv[2] / 2)
		truehands = math.ceil(wifeMean(gv[3]) * #gv[3] / 3)
		truequads = math.ceil(wifeMean(gv[4]) * #gv[4] / 4)
	end

	if overall == 0 then
		rawValues, hellBreakdown = {0,0,0,0,0,0}, {mines=0, lifts=0, rolls=0, fakes=0}
		return {0,0,0,0,0,0}
	end

	-- POWER
	local power = powerDisplay(stamina)

	-- CHAOS
	local chaos = 0
	if noteCount >= 50 and gv and gv[1] and #gv[1] > 0 then
		local maxNps, avgNps = math.max(unpack(gv[1])), wifeMean(gv[1])
		if avgNps > 0 then
			local maxssr   = math.max(unpack(steps:GetSSRs(rate, 1))) or 0
			local otherssr = math.max(unpack(steps:GetSSRs(rate, 0.93))) or 0
			local ssrRatio = otherssr > 0 and maxssr/otherssr or 1
			local spikeSSR = clamp(math.pow(ssrRatio - 0.07, 8), 0.75, 1.4)
			local techF = math.pow(technical*1.05/overall, 2)
			local jackF = chordjack > 0 and math.min(math.pow(jackspeed*1.1/chordjack, 2), 1.25) or 1
			local cjF   = chordjack > 0 and math.min(math.pow(jackspeed*1.1/chordjack, 2), 1.5) or 1
			local stamF = stamina > 0 and math.pow(overall/stamina, 0.6) or 1
			chaos = math.max(0,
				math.max(msdscale(technical), msdscale(jackspeed))
				* spikeSSR
				* math.max(techF, jackF)
				* math.min(1, stamF, cjF))
		end
	end

	-- HELL
	local hell, hellMines, hellLifts, hellRolls, hellFakes = 0, 0, 0, 0, 0
	if noteCount >= 50 then
		hellRolls = (rolls/noteCount) * 5
		hellFakes = (fakes/noteCount) * 2.5
		hellLifts = (lifts/noteCount) * 8
		hellMines = (mines/noteCount) * 1.125
		hell = math.max(0, hellRolls + hellFakes + hellLifts + hellMines)
	end
	if     lifts >= 1  then hell = math.max(hell, 0.3)
	elseif fakes >= 1  then hell = math.max(hell, 0.2)
	elseif rolls >= 10 then hell = math.max(hell, 0.2)
	elseif rolls >= 1  then hell = math.max(hell, 0.15) end

	local hellRawTotal = hellMines + hellLifts + hellRolls + hellFakes
	if hellRawTotal > 0 then
		local s = hellDisplay(hell) * POINTS_SCALE / (hellRawTotal * POINTS_SCALE)
		hellBreakdown = {
			mines=valueToPts(hellMines)*s, lifts=valueToPts(hellLifts)*s,
			rolls=valueToPts(hellRolls)*s, fakes=valueToPts(hellFakes)*s,
		}
	else
		hellBreakdown = {mines=0, lifts=0, rolls=0, fakes=0}
	end

	-- MACH
	local mach = 0
	local td = steps:GetTimingData()
	if td then
		local allStops, stops = td:GetStops(), 0
		if allStops then
			for _, s in ipairs(allStops) do
				local p = tonumber(tostring(s):match("=([%d%.%-]+)"))
				if p and math.abs(p) > 0.025 then stops = stops + 1 end
			end
		end
		local warps   = td:GetWarps()   and #td:GetWarps()                  or 0
		local speeds  = td:GetSpeeds()  and math.max(0, #td:GetSpeeds()-1)  or 0
		local scrolls = td:GetScrolls() and math.max(0, #td:GetScrolls()-1) or 0
		local gimmicks = stops + warps + speeds + scrolls
		local perMin = gimmicks / (length / 60)
		mach = math.max(0, math.log(1 + perMin) * 0.1)
	end

	-- FREEZE
	local freeze = 0
	if noteCount >= 50 and holds > 0 then
		freeze = math.max(0,
			((holds/noteCount)
			+ (hands - truehands - truequads)/noteCount * 8
			+ (jumps - truejumps - truehands - truequads)/noteCount * 8)
			* msdscale(overall))
	elseif holds >= 1 then
		freeze = 0.1
	end

	-- EARTH
	local earth = math.max(0,
		((truequads/noteCount)*2 + (truehands/noteCount)*2 + (truejumps/noteCount)*1)
		* msdscale(overall)
		* math.max(chordjack*1.1/overall, handstream*1.25/overall, jumpstream*1.1/overall)
		* math.min(1, overall/jackspeed * 1.2))

	rawValues = {stamina, chaos, hell, mach, freeze, earth}
	return {
		math.min(powerDisplay(stamina),    CAP),
		math.min(toDisplayValue(chaos, 2), CAP),
		math.min(hellDisplay(hell),        CAP),
		math.min(machDisplay(mach),        CAP),
		math.min(freezeDisplay(freeze),    CAP),
		math.min(toDisplayValue(earth, 6), CAP),
	}
end

-- actor tree

local t = Def.ActorFrame {
	Name = "ChartRadar",
	InitCommand = function(self) self:xy(0,0):visible(false) end,
	BeginCommand = function(self) self:queuecommand("Set") end,
	SetCommand = function(self)
		if previewVisible then self:visible(false); return end
		local song, steps = GAMESTATE:GetCurrentSong(), GAMESTATE:GetCurrentSteps()
		if not (song and steps) then self:visible(false); return end

		for i = 1, 6 do oldValues[i] = displayedValues[i] end
		for i = 1, 4 do oldColor[i] = displayedColor[i] end

		targetValues = calculateRadarValues(steps, song)
		
		-- Find the highest radar category from the calculated target values
		-- Apply its mapped category color to the radar fill and outline
		local maxVal = -1
		local maxIdx = 1
		for i = 1, 6 do
			local val = targetValues[i]
			if val > maxVal then
				maxVal = val
				maxIdx = i
			end
		end
		
		local nc = categories[maxIdx].color
		for i = 1, 4 do targetColor[i] = nc[i] end
		if not hoverActive then hideTooltips() end
		currentStep = 0
		self:visible(true):stoptweening():queuecommand("AnimateStep")
	end,
	AnimateStepCommand = function(self)
		currentStep = currentStep + 1
		local p = smoothstep(currentStep / TWEEN_STEPS)
		for i = 1, 6 do displayedValues[i] = oldValues[i] + (targetValues[i]-oldValues[i])*p end
		for i = 1, 4 do displayedColor[i] = oldColor[i] + (targetColor[i]-oldColor[i])*p end
		self:queuecommand("UpdateRadar")
		if hoverActive then showTooltips() end
		if currentStep < TWEEN_STEPS then self:sleep(STEP_TIME):queuecommand("AnimateStep") end
	end,
	DelayedChartUpdateMessageCommand = function(self) self:stoptweening():queuecommand("Set") end,
	TabChangedMessageCommand          = function(self) self:stoptweening():queuecommand("Set") end,
	NoteFieldVisibleMessageCommand    = function(self) previewVisible = true;  self:visible(false) end,
	ChartPreviewOnMessageCommand      = function(self) previewVisible = true;  self:visible(false) end,
	ChartPreviewOffMessageCommand     = function(self) previewVisible = false; self:stoptweening():queuecommand("Set") end,
}

-- hover zone
local HOVER_SIZE = (RADAR_RADIUS + LABEL_OFFSET + 12) * 2
t[#t+1] = UIElements.QuadButton(1, 1) .. {
	Name = "RadarHoverZone",
	InitCommand = function(self) self:xy(RADAR_X, RADAR_Y):zoomto(HOVER_SIZE, HOVER_SIZE):diffusealpha(0) end,
	MouseOverCommand = function(self) if self:IsVisible() then showTooltips() end end,
	MouseOutCommand  = function(self) hideTooltips() end,
}

-- hex background triangles + spokes
for i = 1, 6 do
	local ni = i%6 + 1
	t[#t+1] = Def.ActorMultiVertex {
		InitCommand = function(self) self:xy(RADAR_X, RADAR_Y) end,
		SetCommand = function(self)
			local x1, y1 = getHexPoint(i,  RADAR_RADIUS, 0, 0)
			local x2, y2 = getHexPoint(ni, RADAR_RADIUS, 0, 0)
			self:SetDrawState{Mode="DrawMode_Triangles"}
			self:SetVertices({
				{{0,0,0},    color("0.04,0.04,0.04,0.8")},
				{{x1,y1,0},  color("0.08,0.08,0.08,0.8")},
				{{x2,y2,0},  color("0.08,0.08,0.08,0.8")},
			})
		end,
	}
	t[#t+1] = Def.ActorMultiVertex {
		InitCommand = function(self) self:xy(RADAR_X, RADAR_Y) end,
		SetCommand = function(self)
			local x, y = getHexPoint(i, RADAR_RADIUS, 0, 0)
			self:SetDrawState{Mode="DrawMode_LineStrip"}
			self:SetVertices({{{0,0,0}, color("0.12,0.12,0.12,1")}, {{x,y,0}, color("0.12,0.12,0.12,1")}})
		end,
	}
end

-- hex border
t[#t+1] = Def.ActorMultiVertex {
	InitCommand = function(self) self:xy(RADAR_X, RADAR_Y) end,
	SetCommand = function(self)
		local verts = {}
		for i = 1, 7 do
			local x, y = getHexPoint((i-1)%6+1, RADAR_RADIUS, 0, 0)
			verts[#verts+1] = {{x,y,0}, color("0.18,0.18,0.18,1")}
		end
		self:SetDrawState{Mode="DrawMode_LineStrip"}
		self:SetVertices(verts)
	end,
}

-- radar fill
t[#t+1] = Def.ActorMultiVertex {
	Name = "RadarFill",
	InitCommand = function(self) self:xy(RADAR_X, RADAR_Y) end,
	UpdateRadarCommand = function(self)
		local c = {displayedColor[1], displayedColor[2], displayedColor[3], 0.6}
		local verts = {{{0,0,0}, c}}
		for i = 1, 7 do
			local idx = (i-1)%6+1
			local x, y = getHexPoint(idx, RADAR_RADIUS * math.max(displayedValues[idx] or 0, 0.03), 0, 0)
			verts[#verts+1] = {{x,y,0}, c}
		end
		self:SetDrawState{Mode="DrawMode_Fan"}
		self:SetVertices(verts)
	end,
}

-- radar outline
t[#t+1] = Def.ActorMultiVertex {
	Name = "RadarOutline",
	InitCommand = function(self) self:xy(RADAR_X, RADAR_Y) end,
	UpdateRadarCommand = function(self)
		local c = {
			math.min(displayedColor[1]*1.2, 1),
			math.min(displayedColor[2]*1.2, 1),
			math.min(displayedColor[3]*1.2, 1), 1,
		}
		local verts = {}
		for i = 1, 7 do
			local idx = (i-1)%6+1
			local x, y = getHexPoint(idx, RADAR_RADIUS * math.max(displayedValues[idx] or 0, 0.03), 0, 0)
			verts[#verts+1] = {{x,y,0}, c}
		end
		self:SetDrawState{Mode="DrawMode_LineStrip"}
		self:SetVertices(verts)
	end,
}

-- labels, tooltips, hell breakdown

local hellSources = {
	{key="mines", label=THEME:GetString("Radar", "Mines")}, {key="rolls", label=THEME:GetString("Radar", "Rolls")},
	{key="lifts", label=THEME:GetString("Radar", "Lifts")}, {key="fakes", label=THEME:GetString("Radar", "Fakes")},
}

for i = 1, 6 do
	local cat = categories[i]
	local shadow = shadowOf(cat.color)
	local lx, ly = getHexPoint(i, RADAR_RADIUS + LABEL_OFFSET, RADAR_X, RADAR_Y)
	local la, ta = labelAlign[i], tooltipOffset[i]

	t[#t+1] = LoadFont("Common Large") .. {
		Name = "RadarLabel"..i,
		InitCommand = function(self)
			self:xy(lx, ly):zoom(0.15):settext(cat.name):diffuse(cat.color)
				:shadowlength(0.5):shadowcolor(shadow)
				:halign(la.h):valign(la.v):addx(la.dx):addy(la.dy)
		end,
	}

	t[#t+1] = LoadFont("Common Normal") .. {
		Name = "RadarValue"..i,
		InitCommand = function(self)
			self:visible(false):zoom(0.225):shadowlength(0.5)
				:diffuse(lighten(cat.color, 0.8)):shadowcolor(shadow)
				:xy(lx + ta.dx, ly + ta.dy):halign(ta.h):valign(ta.v)
			tooltipActors[i] = self
		end,
		UpdateRadarCommand = function(self)
			self:settextf("%.2f", displayFn[i](rawValues[i]) * POINTS_SCALE)
		end,
	}

	if i == 3 then
		hellBaseX, hellBaseY = lx + 2, ly + 4
		for _, src in ipairs(hellSources) do
			t[#t+1] = LoadFont("Common Normal") .. {
				Name = "HellBreakdown"..src.key,
				InitCommand = function(self)
					hellBreakdownActors[#hellBreakdownActors+1] = self
					self.srcKey, self.srcLabel = src.key, src.label
					self:xy(hellBaseX, hellBaseY):halign(0):valign(0):zoom(0.225):visible(false)
						:diffuse(lighten(cat.color, 0.8)):shadowlength(0.5):shadowcolor(shadow)
				end,
				UpdateRadarCommand = function(self)
					local val = hellBreakdown[self.srcKey]
					if val and val > 0.01 then
						self:settextf("%.2f %s", val, self.srcLabel)
						self.hasPct = true
					else
						self:settext("")
						self.hasPct = false
					end
				end,
			}
		end
	end
end

return t