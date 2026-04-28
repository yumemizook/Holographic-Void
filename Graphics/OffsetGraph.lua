--- Holographic Void: Offset Plot Graph
-- Ported from spawncamping-wallhack OffsetGraph.lua
-- Shows timing offsets as colored dots on a time axis with judgment threshold lines.
-- Supports judge rescoring via OffsetPlotModification messages.
-- Supports hand-specific highlighting via ToggleHands.
-- Supports hover tooltip showing running score/stats at cursor position.

local tst = ms.JudgeScalers
local judge = (PREFSMAN:GetPreference("SortBySSRNormPercent") and 4 or GetTimingDifficulty())
local tso = tst[judge]
local plotScale = 100
local maxOffset = math.max(180, 180 * (tso or 1))
local dvt = {}

local function clampJudge()
	if judge < 4 then judge = 4 end
	if judge > 9 then judge = 9 end
end
clampJudge()

local function updateMaxOffset()
	maxOffset = math.max(180, 180 * (tso or 1)) * plotScale / 100
end

local function setPlotScale(scale)
	plotScale = math.max(5, math.min(100, scale))
	updateMaxOffset()
	MESSAGEMAN:Broadcast("JudgeDisplayChanged")
end

local function setPlotScaleToWorstHit()
	local worst = 0
	for i = 1, #dvt do
		local offset = math.abs(dvt[i] or 0)
		if offset < 1000 and offset > worst then worst = offset end
	end
	if worst > 0 then
		setPlotScale(math.ceil(worst / math.max(180, 180 * (tso or 1)) * 100))
	end
end

local dotWidth = 2
local dotHeight = 2

local nrv = {}
local ctt = {}
local ntt = {}
local wuab = {}
local columns = 4
local finalSecond = 1
local td
local oddColumns = false
local middleColumn = 1.5
local cbl, cbr, cbm = 0, 0, 0
local showMiddle = false

local handspecific = false
local left = false
local middle = false
local setWidth = 0
local setHeight = 0
local setSong
local setSteps

local usingCustomWindows = false

local function fitX(x)
	if finalSecond == 0 then return 0 end
	return x / finalSecond * setWidth - setWidth / 2
end

local function fitY(y)
	return -1 * y / maxOffset * setHeight / 2
end

local function setOffsetVerts(vt, x, y, c)
	vt[#vt + 1] = {{x - dotWidth/2, y + dotWidth/2, 0}, c}
	vt[#vt + 1] = {{x + dotWidth/2, y + dotWidth/2, 0}, c}
	vt[#vt + 1] = {{x + dotWidth/2, y - dotWidth/2, 0}, c}
	vt[#vt + 1] = {{x - dotWidth/2, y - dotWidth/2, 0}, c}
end

local function convertXToRow(x)
	local output = x / setWidth
	if output < 0 then output = 0 end
	if output > 1 then output = 1 end
	local stepsTD = GAMESTATE:GetCurrentSteps():GetTimingData()
	return stepsTD:GetBeatFromElapsedTime(output * finalSecond) * 48
end

local function HighlightUpdaterThing(self)
	if self:IsVisible() then
		self:GetChild("Background"):playcommand("Highlight")
	end
end

local baralpha = 0.4

-- HV color scheme
local frameBG = color("0.06,0.06,0.06,0.95")
local brightText = color("1,1,1,1")
local dimText = brightText
local accentColor = HVColor.Accent
local subText = brightText

local t = Def.ActorFrame{
	InitCommand = function(self)
		self:RunCommandsOnChildren(function(self)
			local params = {width = 0, height = 0, song = nil, steps = nil, nrv = {}, dvt = {}, ctt = {}, ntt = {}, columns = 4}
			self:playcommand("Update", params)
		end)
	end,
	OnCommand = function(self)
		local name = SCREENMAN:GetTopScreen():GetName()
		if name == "ScreenEvaluationNormal" or name == "ScreenNetEvaluation" then
			local ok, allowHovering = pcall(function()
				return not SCREENMAN:GetTopScreen():ScoreUsedInvalidModifier()
			end)
			if ok and allowHovering then
				self:SetUpdateFunction(HighlightUpdaterThing)
			end
		end
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if not event or not event.DeviceInput or event.type ~= "InputEventType_FirstPress" then return false end
			local bg = self:GetChild("Background")
			if not bg or not isOver(bg) then return false end

			local btn = event.DeviceInput.button
			if btn == "DeviceButton_mousewheel up" then
				setPlotScale(plotScale - 5)
				return true
			elseif btn == "DeviceButton_mousewheel down" then
				setPlotScale(plotScale + 5)
				return true
			elseif btn == "DeviceButton_left mouse button" then
				setPlotScaleToWorstHit()
				return true
			elseif btn == "DeviceButton_right mouse button" then
				setPlotScale(100)
				return true
			end
			return false
		end)
	end,
	OffsetPlotModificationMessageCommand = function(self, params)
		if params.Name == "PrevJudge" and judge > 1 then
			judge = judge - 1
			clampJudge()
			tso = tst[judge]
		elseif params.Name == "NextJudge" and judge < 9 then
			judge = judge + 1
			clampJudge()
			tso = tst[judge]
		elseif params.Name == "ToggleHands" and #ctt > 0 then
			if not handspecific then
				handspecific = true
				left = true
			elseif handspecific and left then
				if oddColumns then middle = true end
				left = false
			elseif handspecific and middle then
				middle = false
			elseif handspecific and not left then
				handspecific = false
			end
		end
		if params.Name == "ResetJudge" then
			judge = PREFSMAN:GetPreference("SortBySSRNormPercent") and 4 or GetTimingDifficulty()
			clampJudge()
			tso = tst[judge]
		end
		if params.Name ~= "ResetJudge" and params.Name ~= "PrevJudge"
			and params.Name ~= "NextJudge" and params.Name ~= "ToggleHands" then return end
		updateMaxOffset()
		MESSAGEMAN:Broadcast("JudgeDisplayChanged")
	end,
	ScoreChangedMessageCommand = function(self)
		self:queuecommand("Update")
	end,
	LoadedCustomWindowMessageCommand = function(self)
		usingCustomWindows = true
		self:queuecommand("Update")
	end,
	UnloadedCustomWindowMessageCommand = function(self)
		usingCustomWindows = false
		self:queuecommand("Update")
	end
}
local function checkParams(params)
	if type(params) ~= "table" or params.width == nil then
		params = {width = setWidth, height = setHeight, song = setSong,
			steps = setSteps, nrv = nrv, dvt = dvt, ctt = ctt, ntt = ntt, columns = columns}
	end
	oddColumns = (columns or 4) % 2 ~= 0
	middleColumn = ((columns or 4) - 1) / 2.0
	return params
end

-- Plot BG
t[#t+1] = Def.Quad{
	Name = "Background",
	InitCommand = function(self)
		self:halign(0):valign(0):diffuse(frameBG)
	end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		setWidth = params.width
		setHeight = params.height
		setSong = params.song
		setSteps = params.steps
		dvt = params.dvt or {}
		nrv = params.nrv or {}
		ctt = params.ctt or {}
		ntt = params.ntt or {}
		columns = params.columns or 4
		cbl = params.cbl or 0
		cbr = params.cbr or 0
		cbm = params.cbm or 0
		showMiddle = params.showMiddle or false
		if params.song then
			finalSecond = params.song:GetLastSecond()
		end
		if params.steps then
			td = params.steps:GetTimingData()
		end
		self:zoomto(params.width, params.height)
	end,
	HighlightCommand = function(self)
		local bar = self:GetParent():GetChild("PosBar")
		local txt = self:GetParent():GetChild("PosText")
		local bg = self:GetParent():GetChild("PosBG")
		local mx = INPUTFILTER:GetMouseX()
		local my = INPUTFILTER:GetMouseY()
		local x = self:GetTrueX()
		local y = self:GetTrueY()
		local w = self:GetZoomedWidth()
		local h = self:GetZoomedHeight()
		local ha = self.GetHAlign and self:GetHAlign() or 0
		local va = self.GetVAlign and self:GetVAlign() or 0
		
		if mx >= x - w * ha and mx <= x + w * (1 - ha) and my >= y - h * va and my <= y + h * (1 - va) then
			local xpos = INPUTFILTER:GetMouseX() - self:GetTrueX()
			bar:visible(true)
			txt:visible(true)
			bg:visible(true)
			bar:x(xpos)
			txt:x(xpos - 2)
			txt:y(100)
			bg:x(xpos)
			bg:y(100)
			bg:zoomto(txt:GetZoomedWidth() + 4, txt:GetZoomedHeight() + 4)

			local row = convertXToRow(xpos)
			local ok, replay = pcall(function() return REPLAYS:GetActiveReplay() end)
			if ok and replay and replay.GetReplaySnapshotForNoterow then
				local sok, snapshot = pcall(function() return replay:GetReplaySnapshotForNoterow(row) end)
				if sok and snapshot then
					local judgments = snapshot:GetJudgments()
					local wifescore = snapshot:GetWifePercent() * 100
					local mean = snapshot:GetMean()
					local sd = snapshot:GetStandardDeviation()
					local timebro = td:GetElapsedTimeFromNoteRow(row) / getCurRateValue()
					txt:settextf("%.2f%%\nMarv: %d\nPerf: %d\nGreat: %d\nGood: %d\nBad: %d\nMiss: %d\nSD: %.2fms\nMean: %.2fms\nTime: %.2fs",
						wifescore,
						judgments["W1"] or 0, judgments["W2"] or 0,
						judgments["W3"] or 0, judgments["W4"] or 0,
						judgments["W5"] or 0, judgments["Miss"] or 0,
						sd or 0, mean or 0, timebro or 0)
				end
			end
		else
			bar:visible(false)
			txt:visible(false)
			bg:visible(false)
		end
	end
}

-- Plot center horizontal line removed per user request

-- Judgment threshold lines (symmetric)
local fantabars = {22.5, 45, 90, 135}
local bantafars = {"TapNoteScore_W2", "TapNoteScore_W3", "TapNoteScore_W4", "TapNoteScore_W5"}
local santabarf = {"TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3", "TapNoteScore_W4"}
for i = 1, #fantabars do
	-- Upper line
	t[#t + 1] = Def.Quad {
		InitCommand = function(self) self:halign(0):valign(0) end,
		UpdateCommand = function(self, params)
			params = checkParams(params)
			self:zoomto(params.width, 1)
			
			local fit = fantabars[i] * (tso or 1)
			if usingCustomWindows and getCustomWindowConfigJudgmentWindow then
				fit = getCustomWindowConfigJudgmentWindow(santabarf[i])
			end
			
			local c = offsetToJudgeColor(fit + 1, tso)
			if usingCustomWindows and customOffsetToJudgeColor then
				c = customOffsetToJudgeColor(fit + 1, getCurrentCustomWindowConfigJudgmentWindowTable())
			end
			
			self:diffuse(c):diffusealpha(baralpha)
			self:y(fitY(fit) + params.height / 2)
		end,
		JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
	}
	-- Lower line (mirror)
	t[#t + 1] = Def.Quad {
		InitCommand = function(self) self:halign(0):valign(0) end,
		UpdateCommand = function(self, params)
			params = checkParams(params)
			self:zoomto(params.width, 1)
			
			local fit = fantabars[i] * (tso or 1)
			if usingCustomWindows and getCustomWindowConfigJudgmentWindow then
				fit = getCustomWindowConfigJudgmentWindow(santabarf[i])
			end
			
			local c = offsetToJudgeColor(fit + 1, tso)
			if usingCustomWindows and customOffsetToJudgeColor then
				c = customOffsetToJudgeColor(fit + 1, getCurrentCustomWindowConfigJudgmentWindowTable())
			end
			
			self:diffuse(c):diffusealpha(baralpha)
			self:y(fitY(-fit) + params.height / 2)
		end,
		JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
	}
end

-- Position bar for hover
t[#t+1] = Def.Quad {
	Name = "PosBar",
	InitCommand = function(self)
		self:visible(false):zoomto(2, setHeight):diffuse(color("0.5,0.5,0.5,1")):valign(0)
	end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		self:zoomto(2, params.height)
	end
}

-- Late ms text
t[#t+1] = LoadFont("Common Normal")..{
	InitCommand = function(self) self:zoom(0.35):halign(0):valign(1):diffuse(dimText) end,
	UpdateCommand = function(self)
		self:xy(5, -5):settextf("Late (+%d ms)", maxOffset)
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- Early ms text
t[#t+1] = LoadFont("Common Normal")..{
	InitCommand = function(self) self:zoom(0.35):halign(0):valign(1):diffuse(dimText) end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		self:xy(5, params.height - 5):settextf("Early (-%d ms)", maxOffset)
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- Hand highlight info text
t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:zoom(0.35):diffuse(brightText):settext("") end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		self:xy(params.width / 2, -48)
		if ntt ~= nil and #ntt > 0 then
			if handspecific then
				local leftPts, rightPts, midPts = 0, 0, 0
				local leftTaps, rightTaps, midTaps = 0, 0, 0
				local tso = tst[judge] or 1
				
				for i = 1, #dvt do
					local pts = wife3(math.abs(dvt[i]), tso)
					if ctt[i] < middleColumn then
						leftPts = leftPts + pts
						leftTaps = leftTaps + 1
					elseif ctt[i] > middleColumn then
						rightPts = rightPts + pts
						rightTaps = rightTaps + 1
					else
						midPts = midPts + pts
						midTaps = midTaps + 1
					end
				end
				
				local score = 0
				if left then
					score = leftTaps > 0 and (leftPts / (leftTaps * 2)) * 100 or 0
					self:settextf("Left hand: %.4f%%", score)
				elseif middle then
					score = midTaps > 0 and (midPts / (midTaps * 2)) * 100 or 0
					self:settextf("Middle: %.4f%%", score)
				else
					score = rightTaps > 0 and (rightPts / (rightTaps * 2)) * 100 or 0
					self:settextf("Right hand: %.4f%%", score)
				end
				self:diffuse(accentColor)
			else
				self:settext("DOWN TOGGLE HIGHLIGHTS")
				self:diffuse(subText)
			end
		else
			self:settext("")
		end
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- Early/Late distribution indicator
t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:zoom(0.35):halign(1):valign(1):diffuse(dimText) end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		self:xy(params.width - 5, -5)
		local early = 0
		local late = 0
		if params.dvt and #params.dvt > 0 then
			for _, off in ipairs(params.dvt) do
				if off < 0 then early = early + 1
				elseif off > 0 then late = late + 1 end
			end
		end
		if early + late > 0 then
			self:settextf("Early: %d (%.1f%%) | Late: %d (%.1f%%)", 
				early, early / (early + late) * 100,
				late, late / (early + late) * 100)
		else
			self:settext("")
		end
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- CB Display (Stacked above Delta Hand on Right)
t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:zoom(0.4):halign(1):valign(1):diffuse(brightText) end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		self:xy(params.width - 5, -5 - 20)
		local totalCBs = cbl + cbr + cbm
		local text = string.format("CB: %d (L:%d  R:%d", totalCBs, cbl, cbr)
		if showMiddle then text = text .. string.format("  M:%d", cbm) end
		self:settext(text .. ")")
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- Delta Hand Display (Stacked above Distribution on Right)
t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:zoom(0.4):halign(1):valign(1):diffuse(brightText) end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		self:xy(params.width - 5, -5 - 10)
		if params.dvt and #params.dvt > 0 and params.ctt and #params.ctt > 0 then
			local leftPts, rightPts = 0, 0
			local leftTaps, rightTaps = 0, 0
			local tso = tst[judge] or 1
			for i = 1, #params.dvt do
				local pts = wife3(math.abs(params.dvt[i]), tso)
				if params.ctt[i] < middleColumn then
					leftPts = leftPts + pts
					leftTaps = leftTaps + 1
				elseif params.ctt[i] > middleColumn then
					rightPts = rightPts + pts
					rightTaps = rightTaps + 1
				end
			end
			local leftScore = leftTaps > 0 and (leftPts / (leftTaps * 2)) or 0
			local rightScore = rightTaps > 0 and (rightPts / (rightTaps * 2)) or 0
			local delta = math.abs(leftScore - rightScore) * 100
			local symbol = ""
			if leftScore > rightScore then
				symbol = "> "
			elseif leftScore < rightScore then
				symbol = "< "
			end
			self:settextf("Δ Hand: %s%.4f%%", symbol, delta)
		else
			self:settext("")
		end
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- THE DOTS (ActorMultiVertex)
t[#t+1] = Def.ActorMultiVertex{
	UpdateCommand = function(self, params)
		params = checkParams(params)
		local verts = {}

		if params.song == nil or params.steps == nil or params.nrv == nil or params.dvt == nil
			or #params.nrv == 0 or #params.dvt == 0 then
			self:SetVertices(verts)
			self:SetDrawState{Mode = "DrawMode_Quads", First = 1, Num = 0}
			return
		end

		local stepsTD = params.steps:GetTimingData()
		for i = 1, #params.nrv do
			wuab[i] = stepsTD:GetElapsedTimeFromNoteRow(params.nrv[i])
		end

		for i = 1, #params.nrv do
			if params.dvt[i] ~= nil then
				local offsetMs = params.dvt[i]
				local rawOffset = offsetMs
				local c = offsetToJudgeColor(offsetMs, tso)
				if usingCustomWindows and customOffsetToJudgeColor then
					c = customOffsetToJudgeColor(offsetMs, getCurrentCustomWindowConfigJudgmentWindowTable())
				end
				c = {c[1], c[2], c[3], 1}

				local x = fitX(wuab[i]) + params.width / 2
				local y = fitY(offsetMs) + params.height / 2
				local alpha = 1

				if handspecific and params.ctt and params.ctt[i] then
					if left then
						if params.ctt[i] >= middleColumn then alpha = 0.1 end
					elseif middle then
						if params.ctt[i] ~= middleColumn then alpha = 0.1 end
					else
						if params.ctt[i] <= middleColumn then alpha = 0.1 end
					end
				end

				if math.abs(rawOffset) >= 1000 then
					-- Misses: vertical line (Etterna recorded misses as 1000ms)
					local a = alpha == 1 and 0.3 or 0.1
					c[4] = a
					verts[#verts+1] = {{x - dotWidth/4, params.height, 0}, c}
					verts[#verts+1] = {{x + dotWidth/4, params.height, 0}, c}
					verts[#verts+1] = {{x + dotWidth/4, 0, 0}, c}
					verts[#verts+1] = {{x - dotWidth/4, 0, 0}, c}
				else
					c[4] = alpha
					setOffsetVerts(verts, x, y, c)
				end
			end
		end

		self:SetVertices(verts)
		self:SetDrawState{Mode = "DrawMode_Quads", First = 1, Num = #verts}
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- Tooltip BG
t[#t+1] = Def.Quad {
	Name = "PosBG",
	InitCommand = function(self)
		self:valign(1):halign(1):zoomto(30, 30):diffuse(color(".06,.06,.06,.9")):visible(false)
	end
}

-- Tooltip text
t[#t+1] = LoadFont("Common Normal") .. {
	Name = "PosText",
	InitCommand = function(self)
		self:valign(1):halign(1):zoom(0.3):diffuse(color("0.8,0.8,0.8,1"))
	end
}

return t
