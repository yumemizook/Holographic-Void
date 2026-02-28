--- Holographic Void: MusicWheelItem SectionExpanded NormalPart
-- Group header row: left-aligned pack name, right-aligned song count.

local wheelItemW = 280

local t = Def.ActorFrame {}

-- Background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(wheelItemW, 34):diffuse(color("0.10,0.10,0.10,1"))
	end,
	GainFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.16,0.16,0.16,1"))
	end,
	LoseFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.10,0.10,0.10,1"))
	end
}

-- Left accent bar (accent color for groups)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(-wheelItemW/2 + 2):zoomto(4, 30):diffuse(HVColor.Accent):diffusealpha(0.5)
	end
}

-- Song count (right-aligned, smaller)
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "SongCount",
	InitCommand = function(self)
		self:halign(1):x(wheelItemW/2 - 8):y(0)
			:zoom(0.24):diffuse(color("0.45,0.45,0.45,1"))
	end,
	SetCommand = function(self)
		local group = self:GetParent():GetParent()
		if group and group.GetSectionName then
			local sectionName = group:GetSectionName()
			if sectionName and sectionName ~= "" then
				local songs = SONGMAN:GetSongsInGroup(sectionName)
				if songs then
					local total = #songs
					local cleared = 0
					for _, song in ipairs(songs) do
						local allSteps = song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType()
						if allSteps then
							local hasClear = false
							for _, st in ipairs(allSteps) do
								local chartKey = st:GetChartKey()
								if chartKey then
									local scoresByRate = SCOREMAN:GetScoresByKey(chartKey)
									if scoresByRate then
										for _, scoresAtRate in pairs(scoresByRate) do
											local scoreList = scoresAtRate:GetScores()
											if scoreList and #scoreList > 0 then
												hasClear = true
												break
											end
										end
									end
								end
								if hasClear then break end
							end
							if hasClear then cleared = cleared + 1 end
						end
					end
					self:settext(tostring(cleared) .. "/" .. tostring(total))
				else
					self:settext("")
				end
			else
				self:settext("")
			end
		else
			self:settext("")
		end
	end
}

-- Bottom border
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:y(17):zoomto(wheelItemW, 1):diffuse(color("0.18,0.18,0.18,1"))
	end
}

-- Engine text color override
t[#t + 1] = Def.Actor {
	SetMessageCommand = function(self)
		local normalPart = self:GetParent()
		if not normalPart then return end
		local mwi = normalPart:GetParent()
		if not mwi then return end

		local names = {"SectionExpanded", "SectionCollapsed"}
		for _, name in ipairs(names) do
			local textActor = mwi:GetChild(name)
			if textActor and textActor:GetVisible() then
				textActor:diffuse(HVColor.Accent)
			end
		end
	end,
	ColorThemeChangedMessageCommand = function(self) self:playcommand("Set") end
}

return t
