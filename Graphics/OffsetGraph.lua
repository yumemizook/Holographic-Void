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
		-- Ignore misses (offset >= 1000ms) when scaling to worst hit
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

local trendMetricModes = {
	{id = "wife", label = "Wife%"},
	{id = "grade", label = "Grade"},
	{id = "clear", label = "Clear Type"},
	{id = "mean", label = "Mean"},
	{id = "sd", label = "Std Dev"},
	{id = "ma", label = "MA"},
	{id = "pa", label = "PA"},
}
local trendColorModes = {
	{id = "none", label = "None"},
	{id = "grade", label = "Grade"},
	{id = "clear", label = "Clear Type"},
}
local trendMetricIndex = 1
local trendColorModeIndex = 1

local selectingSlice = false
local selectStartX = nil
local selectCurrentX = nil
local selectedSliceX1 = nil
local selectedSliceX2 = nil
local selectedSliceStats = nil
local fitX

local function clampValue(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function getMouseLocalX(bg)
	if not bg then return 0 end
	return clampValue(INPUTFILTER:GetMouseX() - bg:GetTrueX(), 0, setWidth)
end

local function getJudgeWindows()
	local windows = {
		W1 = 22.5 * (tso or 1),
		W2 = 45 * (tso or 1),
		W3 = 90 * (tso or 1),
		W4 = 135 * (tso or 1),
		W5 = 180 * (tso or 1),
	}
	if usingCustomWindows and getCustomWindowConfigJudgmentWindow then
		windows.W1 = getCustomWindowConfigJudgmentWindow("TapNoteScore_W1") or windows.W1
		windows.W2 = getCustomWindowConfigJudgmentWindow("TapNoteScore_W2") or windows.W2
		windows.W3 = getCustomWindowConfigJudgmentWindow("TapNoteScore_W3") or windows.W3
		windows.W4 = getCustomWindowConfigJudgmentWindow("TapNoteScore_W4") or windows.W4
		windows.W5 = getCustomWindowConfigJudgmentWindow("TapNoteScore_W5") or windows.W5
	end
	return windows
end

local function classifyOffset(offsetMs, windows)
	local absOffset = math.abs(offsetMs or 0)
	if absOffset >= 1000 or absOffset > windows.W5 then return "Miss" end
	if absOffset <= windows.W1 then return "W1" end
	if absOffset <= windows.W2 then return "W2" end
	if absOffset <= windows.W3 then return "W3" end
	if absOffset <= windows.W4 then return "W4" end
	if absOffset <= windows.W5 then return "W5" end
	return "Miss"
end

local function getClearTypeFromCounts(judgments, wifePct)
	local w2 = judgments.W2 or 0
	local w3 = judgments.W3 or 0
	local w4 = judgments.W4 or 0
	local w5 = judgments.W5 or 0
	local miss = judgments.Miss or 0
	local cb = w4 + w5 + miss

	if cb > 0 then
		if cb == 1 then return "ClearType_MF" end
		if cb < 10 then return "ClearType_SDCB" end
		if (wifePct or 0) < 83 then return "ClearType_SoftInvalid" end
		return "ClearType_Clear"
	end

	if w3 > 0 then
		if w3 == 1 then return "ClearType_BF" end
		if w3 < 10 then return "ClearType_SDG" end
		return "ClearType_FC"
	end

	if w2 > 0 then
		if w2 == 1 then return "ClearType_WF" end
		if w2 < 10 then return "ClearType_SDP" end
		return "ClearType_PFC"
	end

	return "ClearType_MFC"
end

local function gradeToNumeric(grade)
	local s = tostring(grade or "")
	local tier = tonumber(s:match("Tier(%d+)"))
	if tier then
		tier = clampValue(tier, 1, 17)
		return ((17 - tier) / 16) * 100
	end
	if s:find("Failed") then return 0 end
	return 0
end

local function clearTypeToNumeric(clearType)
	local level = getClearTypeLevel and getClearTypeLevel(clearType) or 18
	level = clampValue(level, 1, 19)
	return ((19 - level) / 18) * 100
end

local function getCurrentTrendMetricId()
	return trendMetricModes[trendMetricIndex].id
end

local function getCurrentTrendColorModeId()
	return trendColorModes[trendColorModeIndex].id
end

local function cycleTrendMetric(step)
	step = step or 1
	trendMetricIndex = trendMetricIndex + step
	if trendMetricIndex > #trendMetricModes then trendMetricIndex = 1 end
	if trendMetricIndex < 1 then trendMetricIndex = #trendMetricModes end
	MESSAGEMAN:Broadcast("JudgeDisplayChanged")
end

local function cycleTrendColorMode(step)
	step = step or 1
	trendColorModeIndex = trendColorModeIndex + step
	if trendColorModeIndex > #trendColorModes then trendColorModeIndex = 1 end
	if trendColorModeIndex < 1 then trendColorModeIndex = #trendColorModes end
	MESSAGEMAN:Broadcast("JudgeDisplayChanged")
end

local function getMetricValue(metricId, wifePct, judgments, mean, sd)
	if metricId == "wife" then return wifePct end
	if metricId == "grade" then
		local grade = getWifeGradeTier and getWifeGradeTier(wifePct) or "Grade_Tier16"
		return gradeToNumeric(grade)
	end
	if metricId == "clear" then
		local clearType = getClearTypeFromCounts(judgments, wifePct)
		return clearTypeToNumeric(clearType)
	end
	if metricId == "mean" then return mean end
	if metricId == "sd" then return sd end
	if metricId == "ma" then return judgments.W1 or 0 end
	if metricId == "pa" then return judgments.W2 or 0 end
	return wifePct
end

local function calculateSliceStats(x1, x2, params)
	if not x1 or not x2 then return nil end
	if not params or not params.nrv or not params.dvt then return nil end
	local leftX = math.min(x1, x2)
	local rightX = math.max(x1, x2)
	if rightX - leftX < 1 then return nil end

	local windows = getJudgeWindows()
	local noteCount = 0
	local wifePoints = 0
	local judgments = {W1 = 0, W2 = 0, W3 = 0, W4 = 0, W5 = 0, Miss = 0}
	local validCount = 0
	local mean = 0
	local m2 = 0
	local firstTime = nil
	local lastTime = nil

	for i = 1, #params.nrv do
		if params.dvt[i] ~= nil and wuab[i] ~= nil then
			local x = fitX(wuab[i]) + params.width / 2
			if x >= leftX and x <= rightX then
				noteCount = noteCount + 1
				local offset = params.dvt[i]
				wifePoints = wifePoints + wife3(math.abs(offset), tso)
				local bucket = classifyOffset(offset, windows)
				judgments[bucket] = (judgments[bucket] or 0) + 1

				if math.abs(offset) < 1000 then
					validCount = validCount + 1
					local delta = offset - mean
					mean = mean + (delta / validCount)
					m2 = m2 + delta * (offset - mean)
				end

				if firstTime == nil then firstTime = wuab[i] end
				lastTime = wuab[i]
			end
		end
	end

	if noteCount == 0 then
		return {
			notes = 0,
			wife = 0,
			mean = 0,
			sd = 0,
			ma = 0,
			pa = 0,
			startTime = leftX / math.max(setWidth, 1) * finalSecond,
			endTime = rightX / math.max(setWidth, 1) * finalSecond,
		}
	end

	local sd = validCount > 1 and math.sqrt(m2 / (validCount - 1)) or 0
	local wifePct = (wifePoints / (noteCount * 2)) * 100
	return {
		notes = noteCount,
		wife = wifePct,
		mean = mean,
		sd = sd,
		ma = judgments.W1 or 0,
		pa = judgments.W2 or 0,
		startTime = firstTime or 0,
		endTime = lastTime or 0,
	}
end

local function refreshSliceStats(params)
	if selectedSliceX1 and selectedSliceX2 then
		selectedSliceStats = calculateSliceStats(selectedSliceX1, selectedSliceX2, params)
	else
		selectedSliceStats = nil
	end
end

fitX = function(x)
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
			if not event or not event.DeviceInput then return false end
			local btn = event.DeviceInput.button

			if event.type == "InputEventType_FirstPress" and btn == "DeviceButton_left mouse button" then
				local metricLabel = self:GetChild("TrendMetricLabel")
				local colorLabel = self:GetChild("TrendColorLabel")
				if metricLabel and isOver(metricLabel) then
					cycleTrendMetric(1)
					return true
				end
				if colorLabel and isOver(colorLabel) then
					cycleTrendColorMode(1)
					return true
				end
			end

			local bg = self:GetChild("Background")
			if not bg or not isOver(bg) then return false end

			if event.type == "InputEventType_FirstPress" and btn == "DeviceButton_mousewheel up" then
				setPlotScale(plotScale - 5)
				return true
			elseif event.type == "InputEventType_FirstPress" and btn == "DeviceButton_mousewheel down" then
				setPlotScale(plotScale + 5)
				return true
			elseif event.type == "InputEventType_FirstPress" and btn == "DeviceButton_left mouse button" then
				selectingSlice = true
				selectStartX = getMouseLocalX(bg)
				selectCurrentX = selectStartX
				MESSAGEMAN:Broadcast("JudgeDisplayChanged")
				return true
			elseif event.type == "InputEventType_Release" and btn == "DeviceButton_left mouse button" and selectingSlice then
				local endX = getMouseLocalX(bg)
				local dragDistance = math.abs((selectStartX or endX) - endX)
				selectingSlice = false
				selectCurrentX = nil
				if dragDistance < 3 then
					setPlotScaleToWorstHit()
				else
					selectedSliceX1 = math.min(selectStartX or endX, endX)
					selectedSliceX2 = math.max(selectStartX or endX, endX)
					refreshSliceStats({width = setWidth, nrv = nrv, dvt = dvt})
					MESSAGEMAN:Broadcast("JudgeDisplayChanged")
				end
				return true
			elseif event.type == "InputEventType_FirstPress" and btn == "DeviceButton_right mouse button" then
				if selectedSliceX1 and selectedSliceX2 then
					selectedSliceX1 = nil
					selectedSliceX2 = nil
					selectedSliceStats = nil
					MESSAGEMAN:Broadcast("JudgeDisplayChanged")
				else
					setPlotScale(100)
				end
				return true
			elseif event.type == "InputEventType_FirstPress" and btn == "DeviceButton_middle mouse button" then
				cycleTrendMetric(1)
				return true
			elseif event.type == "InputEventType_FirstPress" and btn == "DeviceButton_x1 mouse button" then
				cycleTrendColorMode(1)
				return true
			elseif event.type == "InputEventType_FirstPress" and btn == "DeviceButton_x2 mouse button" then
				cycleTrendColorMode(-1)
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
		elseif params.Name == "NextTrendMetric" then
			cycleTrendMetric(1)
			return
		elseif params.Name == "PrevTrendMetric" then
			cycleTrendMetric(-1)
			return
		elseif params.Name == "NextTrendColor" then
			cycleTrendColorMode(1)
			return
		elseif params.Name == "PrevTrendColor" then
			cycleTrendColorMode(-1)
			return
		end
		if params.Name == "ResetJudge" then
			judge = PREFSMAN:GetPreference("SortBySSRNormPercent") and 4 or GetTimingDifficulty()
			clampJudge()
			tso = tst[judge]
		end
		if params.Name ~= "ResetJudge" and params.Name ~= "PrevJudge"
			and params.Name ~= "NextJudge" and params.Name ~= "ToggleHands"
			and params.Name ~= "NextTrendMetric" and params.Name ~= "PrevTrendMetric"
			and params.Name ~= "NextTrendColor" and params.Name ~= "PrevTrendColor" then return end
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
		if params.steps and params.nrv then
			local stepsTD = params.steps:GetTimingData()
			for i = 1, #params.nrv do
				wuab[i] = stepsTD:GetElapsedTimeFromNoteRow(params.nrv[i])
			end
		end
		self:zoomto(params.width, params.height)
		refreshSliceStats(params)
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
		
		if selectingSlice then
			selectCurrentX = clampValue(INPUTFILTER:GetMouseX() - self:GetTrueX(), 0, w)
		end

		local activeX1 = selectedSliceX1
		local activeX2 = selectedSliceX2
		if selectingSlice and selectStartX and selectCurrentX then
			activeX1 = math.min(selectStartX, selectCurrentX)
			activeX2 = math.max(selectStartX, selectCurrentX)
		end

		local sliceQuad = self:GetParent():GetChild("SliceSelection")
		local sliceLeftLine = self:GetParent():GetChild("SliceLeftLine")
		local sliceRightLine = self:GetParent():GetChild("SliceRightLine")
		if sliceQuad and activeX1 and activeX2 and (activeX2 - activeX1) >= 1 then
			sliceQuad:visible(true)
			sliceQuad:x(activeX1)
			sliceQuad:zoomto(activeX2 - activeX1, setHeight)
			if sliceLeftLine then
				sliceLeftLine:visible(true):x(activeX1)
				sliceLeftLine:zoomto(1, setHeight)
			end
			if sliceRightLine then
				sliceRightLine:visible(true):x(activeX2)
				sliceRightLine:zoomto(1, setHeight)
			end
		else
			if sliceQuad then sliceQuad:visible(false) end
			if sliceLeftLine then sliceLeftLine:visible(false) end
			if sliceRightLine then sliceRightLine:visible(false) end
		end

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

-- Slice highlight
t[#t+1] = Def.Quad {
	Name = "SliceSelection",
	InitCommand = function(self)
		self:halign(0):valign(0):visible(false):diffuse(HVColor.Accent):diffusealpha(0.16)
	end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		if selectedSliceX1 and selectedSliceX2 then
			local x1 = math.min(selectedSliceX1, selectedSliceX2)
			local x2 = math.max(selectedSliceX1, selectedSliceX2)
			if x2 - x1 >= 1 then
				self:visible(true):x(x1):zoomto(x2 - x1, params.height)
			else
				self:visible(false)
			end
		else
			self:visible(false)
		end
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

t[#t+1] = Def.Quad {
	Name = "SliceLeftLine",
	InitCommand = function(self)
		self:halign(0):valign(0):visible(false):diffuse(HVColor.Accent):diffusealpha(0.7)
	end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		if selectedSliceX1 and selectedSliceX2 then
			local x1 = math.min(selectedSliceX1, selectedSliceX2)
			local x2 = math.max(selectedSliceX1, selectedSliceX2)
			if x2 - x1 >= 1 then
				self:visible(true):x(x1):zoomto(1, params.height)
			else
				self:visible(false)
			end
		else
			self:visible(false)
		end
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

t[#t+1] = Def.Quad {
	Name = "SliceRightLine",
	InitCommand = function(self)
		self:halign(0):valign(0):visible(false):diffuse(HVColor.Accent):diffusealpha(0.7)
	end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		if selectedSliceX1 and selectedSliceX2 then
			local x1 = math.min(selectedSliceX1, selectedSliceX2)
			local x2 = math.max(selectedSliceX1, selectedSliceX2)
			if x2 - x1 >= 1 then
				self:visible(true):x(x2):zoomto(1, params.height)
			else
				self:visible(false)
			end
		else
			self:visible(false)
		end
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- Progression line (metric over chart)
t[#t+1] = Def.ActorMultiVertex{
	Name = "TrendLine",
	UpdateCommand = function(self, params)
		params = checkParams(params)
		local verts = {}

		if params.song == nil or params.steps == nil or params.nrv == nil or params.dvt == nil
			or #params.nrv == 0 or #params.dvt == 0 then
			self:SetVertices(verts)
			self:SetDrawState{Mode = "DrawMode_LineStrip", First = 1, Num = 0}
			return
		end

		local windows = getJudgeWindows()
		local metricId = getCurrentTrendMetricId()
		local colorModeId = getCurrentTrendColorModeId()
		local judgments = {W1 = 0, W2 = 0, W3 = 0, W4 = 0, W5 = 0, Miss = 0}
		local wifePoints = 0
		local validCount = 0
		local runningMean = 0
		local m2 = 0
		local points = {}
		local minVal = math.huge
		local maxVal = -math.huge

		for i = 1, #params.nrv do
			if params.dvt[i] ~= nil and wuab[i] ~= nil then
				local offset = params.dvt[i]
				wifePoints = wifePoints + wife3(math.abs(offset), tso)
				local bucket = classifyOffset(offset, windows)
				judgments[bucket] = (judgments[bucket] or 0) + 1

				if math.abs(offset) < 1000 then
					validCount = validCount + 1
					local delta = offset - runningMean
					runningMean = runningMean + (delta / validCount)
					m2 = m2 + delta * (offset - runningMean)
				end

				local wifePct = (wifePoints / (i * 2)) * 100
				local sd = validCount > 1 and math.sqrt(m2 / (validCount - 1)) or 0
				local clearType = getClearTypeFromCounts(judgments, wifePct)
				local grade = getWifeGradeTier and getWifeGradeTier(wifePct) or "Grade_Tier16"
				local metricValue = getMetricValue(metricId, wifePct, judgments, runningMean, sd)

				points[#points + 1] = {
					x = fitX(wuab[i]) + params.width / 2,
					value = metricValue,
					grade = grade,
					clearType = clearType,
				}

				if metricValue < minVal then minVal = metricValue end
				if metricValue > maxVal then maxVal = metricValue end
			end
		end

		if #points < 2 then
			self:SetVertices(verts)
			self:SetDrawState{Mode = "DrawMode_LineStrip", First = 1, Num = 0}
			return
		end

		if minVal == math.huge or maxVal == -math.huge then
			self:SetVertices(verts)
			self:SetDrawState{Mode = "DrawMode_LineStrip", First = 1, Num = 0}
			return
		end

		if math.abs(maxVal - minVal) < 0.0001 then
			maxVal = minVal + 1
		end

		for i = 1, #points do
			local p = points[i]
			local normalized = (p.value - minVal) / (maxVal - minVal)
			local y = params.height - (normalized * params.height)
			local c = {accentColor[1], accentColor[2], accentColor[3], 0.92}
			if colorModeId == "grade" then
				local gc = HVColor.GetGradeColor(p.grade)
				c = {gc[1], gc[2], gc[3], 0.92}
			elseif colorModeId == "clear" then
				local cc = getClearTypeColor and getClearTypeColor(p.clearType) or accentColor
				c = {cc[1], cc[2], cc[3], 0.92}
			end
			verts[#verts + 1] = {{p.x, y, 0}, c}
		end

		self:SetVertices(verts)
		self:SetDrawState{Mode = "DrawMode_LineStrip", First = 1, Num = #verts}
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

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

			local visible = math.abs(fit) <= maxOffset
			self:visible(visible)
			if visible then
				self:diffuse(c):diffusealpha(baralpha)
				self:y(fitY(fit) + params.height / 2)
			end
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

			local visible = math.abs(fit) <= maxOffset
			self:visible(visible)
			if visible then
				self:diffuse(c):diffusealpha(baralpha)
				self:y(fitY(-fit) + params.height / 2)
			end
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

-- Trend line control labels
t[#t+1] = LoadFont("Common Normal") .. {
	Name = "TrendMetricLabel",
	InitCommand = function(self)
		self:halign(0):valign(1):xy(5, -18):zoom(0.3):diffuse(brightText)
	end,
	UpdateCommand = function(self)
		self:settextf("Trend: %s", trendMetricModes[trendMetricIndex].label)
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

t[#t+1] = LoadFont("Common Normal") .. {
	Name = "TrendColorLabel",
	InitCommand = function(self)
		self:halign(1):valign(1):zoom(0.3):diffuse(brightText)
	end,
	UpdateCommand = function(self, params)
		params = checkParams(params)
		self:xy(params.width - 5, -18)
		self:settextf("Color: %s", trendColorModes[trendColorModeIndex].label)
	end,
	JudgeDisplayChangedMessageCommand = function(self) self:queuecommand("Update") end
}

-- Slice summary
t[#t+1] = LoadFont("Common Normal") .. {
	Name = "SliceInfo",
	InitCommand = function(self)
		self:halign(0):valign(0):xy(5, 4):zoom(0.28):diffuse(brightText)
	end,
	UpdateCommand = function(self)
		if selectingSlice and selectStartX and selectCurrentX then
			local params = {width = setWidth, nrv = nrv, dvt = dvt}
			local live = calculateSliceStats(selectStartX, selectCurrentX, params)
			if live and live.notes > 0 then
				self:settextf("Slice %.2fs-%.2fs | Notes: %d | Wife: %.2f%% | Mean: %.2fms | SD: %.2fms | MA: %d | PA: %d",
					live.startTime or 0, live.endTime or 0, live.notes or 0,
					live.wife or 0, live.mean or 0, live.sd or 0,
					live.ma or 0, live.pa or 0)
			else
				self:settext("Slice selecting...")
			end
		elseif selectedSliceStats and selectedSliceStats.notes and selectedSliceStats.notes > 0 then
			self:settextf("Slice %.2fs-%.2fs | Notes: %d | Wife: %.2f%% | Mean: %.2fms | SD: %.2fms | MA: %d | PA: %d",
				selectedSliceStats.startTime or 0, selectedSliceStats.endTime or 0, selectedSliceStats.notes or 0,
				selectedSliceStats.wife or 0, selectedSliceStats.mean or 0, selectedSliceStats.sd or 0,
				selectedSliceStats.ma or 0, selectedSliceStats.pa or 0)
		elseif selectedSliceX1 and selectedSliceX2 then
			self:settext("Slice contains no notes")
		else
			self:settext("LMB drag: select slice | MMB: cycle trend | RMB: clear slice/reset scale")
		end
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
