--- Holographic Void: Chord Density Graph
-- Adapted from Til Death / spawncamping-wallhack
-- Uses GetCDGraphVectors() + ActorMultiVertex for proper chord density visualization

local cdg

local optionalParam = Var("width")
local wodth = 300
if optionalParam ~= nil then
	wodth = optionalParam
end
local hidth = 40
local txtoff = 10

local textonleft = true
local function textmover(self)
	if not self:GetChild("npstext") then return end
	local npsActor = self:GetChild("npstext")
	if npsActor:GetVisible() == false then return end
	local overNps = false
	local mx = INPUTFILTER:GetMouseX()
	local my = INPUTFILTER:GetMouseY()
	-- simple bounding check
	local ax, ay = npsActor:GetTrueX(), npsActor:GetTrueY()
	if math.abs(mx - ax) < 40 and math.abs(my - ay) < 12 then
		overNps = true
	end
	if overNps and textonleft then
		npsActor:x(wodth - txtoff):halign(1)
		textonleft = false
	elseif overNps and not textonleft then
		npsActor:x(txtoff):halign(0)
		textonleft = true
	end
end

local function makeABar(vertices, x, y, barWidth, barHeight, prettycolor)
	vertices[#vertices + 1] = {{x, y - barHeight, 0}, prettycolor}
	vertices[#vertices + 1] = {{x - barWidth, y - barHeight, 0}, prettycolor}
	vertices[#vertices + 1] = {{x - barWidth, y, 0}, prettycolor}
	vertices[#vertices + 1] = {{x, y, 0}, prettycolor}
end

local function getColorForDensity(density, nColumns)
	-- Grayscale gradient: single notes lighter, bigger chords darker
	local interval = 1 / nColumns
	local value = 1 - density * interval
	return color(tostring(value) .. "," .. tostring(value) .. "," .. tostring(value))
end

local function updateGraphMultiVertex(parent, realgraph)
	local steps = GAMESTATE:GetCurrentSteps()
	if steps then
		local ncol = steps:GetNumColumns()
		local rate = math.max(0.05, getCurRateValue())
		local graphVectors = steps:GetCDGraphVectors(rate)
		if graphVectors == nil then
			realgraph:SetVertices({})
			realgraph:SetDrawState({Mode = "DrawMode_Quads", First = 0, Num = 0})
			return
		end

		local npsVector = graphVectors[1]
		parent.npsVector = npsVector
		local numberOfColumns = #npsVector
		local columnWidth = wodth / numberOfColumns
		-- set height scale of graph relative to the max nps
		local hodth = 0
		for i = 1, #npsVector do
			if npsVector[i] * 2 > hodth then
				hodth = npsVector[i] * 2
			end
		end

		parent:GetChild("npsline"):y(-hidth * 0.7)
		parent:GetChild("npstext"):settext(string.format("%.0f NPS", hodth / 2 * 0.7)):y(-hidth * 0.9)
		hodth = hidth / hodth
		local verts = {}
		local yOffset = 0
		local lastIndex = 1
		for density = 1, ncol do
			for column = 1, numberOfColumns do
				if graphVectors[density][column] > 0 then
					local barColor = getColorForDensity(density, ncol)
					makeABar(verts, math.min(column * columnWidth, wodth), yOffset, columnWidth, graphVectors[density][column] * 2 * hodth, barColor)
					if column > lastIndex then
						lastIndex = column
					end
				end
			end
		end

		parent.finalNPSVectorIndex = lastIndex

		realgraph:SetVertices(verts)
		realgraph:SetDrawState({Mode = "DrawMode_Quads", First = 1, Num = #verts})
	end
end

local t = Def.ActorFrame {
	Name = "ChordDensityGraph",
	InitCommand = function(self)
		cdg = self
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:diffusealpha(0)
	end,
	DelayedChartUpdateMessageCommand = function(self)
		self:playcommand("GraphUpdate")
	end,
	CurrentRateChangedMessageCommand = function(self)
		if self:IsVisible() then
			self:queuecommand("GraphUpdate")
		end
	end,
	ChartPreviewOnMessageCommand = function(self)
		self:queuecommand("GraphUpdate")
	end,
	PracticeModeReloadMessageCommand = function(self)
		self:queuecommand("GraphUpdate")
	end,
	Def.Quad {
		Name = "cdbg",
		InitCommand = function(self)
			self:zoomto(wodth, hidth + 2):valign(1):diffuse(color("1,1,1,1")):halign(0)
		end
	}
}

t[#t + 1] = Def.ActorMultiVertex {
	Name = "CDGraphDrawer",
	GraphUpdateCommand = function(self)
		if self:IsVisible() then
			self:GetParent():SetUpdateFunction(textmover)
			updateGraphMultiVertex(cdg, self)
			self:GetParent():linear(0.3)
			self:GetParent():diffusealpha(1)
		else
			self:GetParent():SetUpdateFunction(nil)
		end
	end
}

-- NPS reference line
t[#t + 1] = Def.Quad {
	Name = "npsline",
	InitCommand = function(self)
		self:zoomto(wodth, 2):diffusealpha(1):valign(1):diffuse(color(".75,0,0,0.75")):halign(0)
	end
}

-- NPS text label
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "npstext",
	InitCommand = function(self)
		self:halign(0):zoom(0.35):settext(""):diffuse(color("1,0.3,0.3"))
	end
}

return t
