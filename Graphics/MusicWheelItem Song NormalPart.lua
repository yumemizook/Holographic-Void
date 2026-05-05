--- Etternity: MusicWheelItem Song NormalPart
-- Enhanced song row: MSD for selected difficulty type, local best grade,
-- artist + subtitle display.
-- Uses SetMessageCommand with params.Song for reliable song data access.

local wheelItemW = 280

local t = Def.ActorFrame {}

-- Card background (OLED: true black unfocused, subtle lift on focus)
t[#t + 1] = Def.Quad {
	Name = "BgQuad",
	InitCommand = function(self)
		self:zoomto(wheelItemW, 38):diffuse(color("0.03,0.03,0.03,1"))
	end,
	SetMessageCommand = function(self, params)
		-- Removed focus-based background lift to match fixed highlight
	end
}

-- Left accent bar (difficulty color, OLED glow) - uses GAMESTATE for current selected diff
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(-wheelItemW/2 + 1):zoomto(2, 30)
			:diffuse(color("0.15,0.15,0.15,1"))
	end,
	SetMessageCommand = function(self, params)
		local curSteps = GAMESTATE:GetCurrentSteps()
		if curSteps then
			local diff = ToEnumShortString(curSteps:GetDifficulty())
			local dc = (HVColor and HVColor.Difficulty and HVColor.Difficulty[diff])
			if dc then
				self:diffuse(dc):diffusealpha(0.6) -- Constant alpha for uniform look
				return
			end
		end
		self:diffuse(color("0.15,0.15,0.15,1"))
	end,
	CurrentStepsChangedMessageCommand = function(self)
		self:playcommand("Set")
	end
}

-- MSD rating text (left side) - shows MSD for closest available difficulty
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "MSDDisplay",
	InitCommand = function(self)
		self:halign(0):x(-wheelItemW/2 + 8):y(0)
			:zoom(0.52):diffuse(color("0.65,0.65,0.65,1"))
	end,
	SetMessageCommand = function(self, params)
		local song = (params and params.Song) or self.hv_lastSong
		self.hv_lastSong = song
		local curSteps = GAMESTATE:GetCurrentSteps()

		if not song or not curSteps then 
			self:settext("") 
			return 
		end

		local diffOrder = {Beginner=1, Easy=2, Medium=3, Hard=4, Challenge=5, Edit=6}
		local targetDiff = ToEnumShortString(curSteps:GetDifficulty())
		local targetIdx = diffOrder[targetDiff] or 4
		local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType())
			or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))

		local showMSD = HV.ShowMSD()

		if allSteps then
			-- Find best matching chart: exact first, then closest by difficulty index
			local bestSt = nil
			local bestDist = math.huge
			for _, st in ipairs(allSteps) do
				local d = ToEnumShortString(st:GetDifficulty())
				local idx = diffOrder[d] or 99
				local dist = math.abs(idx - targetIdx)
				if dist < bestDist then
					bestDist = dist
					bestSt = st
				end
			end

			if bestSt then
				if showMSD then
					local msd = bestSt:GetMSD(getCurRateValue(), 1)
					if msd and msd > 0 then
						self:settext(string.format("%.2f", msd))
						self:diffuse(HVColor.GetMSDRatingColor(msd))
					else
						self:settext("-")
						self:diffuse(color("0.45,0.45,0.45,1"))
					end
				else
					self:settext(tostring(bestSt:GetMeter()))
					self:diffuse(color("0.65,0.65,0.65,1"))
				end
				return
			end
		end
		self:settext("")
	end,
	CurrentStepsChangedMessageCommand = function(self)
		self:playcommand("Set", {Song = self.hv_lastSong})
	end,
	CurrentRateChangedMessageCommand = function(self)
		self:playcommand("Set", {Song = self.hv_lastSong})
	end
}

-- Grade badge (left side, below MSD) - shows grade for closest available difficulty
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "GradeDisplay",
	InitCommand = function(self)
		self:halign(0):x(-wheelItemW/2 + 8):y(11)
			:zoom(0.50):diffuse(color("0.45,0.45,0.45,1"))
	end,
	SetMessageCommand = function(self, params)
		local song = (params and params.Song) or self.hv_lastSong
		self.hv_lastSong = song
		local curSteps = GAMESTATE:GetCurrentSteps()

		if not song or not curSteps then 
			self:settext("") 
			return 
		end

		local diffOrder = {Beginner=1, Easy=2, Medium=3, Hard=4, Challenge=5, Edit=6}
		local targetDiff = ToEnumShortString(curSteps:GetDifficulty())
		local targetIdx = diffOrder[targetDiff] or 4
		local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType())
			or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))

		if allSteps then
			local bestSt = nil
			local bestDist = math.huge
			for _, st in ipairs(allSteps) do
				local d = ToEnumShortString(st:GetDifficulty())
				local idx = diffOrder[d] or 99
				local dist = math.abs(idx - targetIdx)
				if dist < bestDist then
					bestDist = dist
					bestSt = st
				end
			end

			if bestSt then
				local chartKey = bestSt:GetChartKey()
				if chartKey then
					local scoresByRate = SCOREMAN:GetScoresByKey(chartKey)
					if scoresByRate then
						local bestWife = -1
						local bestGrade = nil
						for _, scoresAtRate in pairs(scoresByRate) do
							local scoreList = scoresAtRate:GetScores()
							if scoreList then
								for _, s in ipairs(scoreList) do
									local w = s:GetWifeScore()
									if w > bestWife then
										bestWife = w
										bestGrade = s:GetWifeGrade()
									end
								end
							end
						end
						if bestGrade and bestGrade ~= "Grade_Failed" then
							local gs = ToEnumShortString(bestGrade)
							self:settext(HV.GetGradeName(bestGrade))
							self:diffuse(HVColor.GetGradeColor(gs))
							return
						end
					end
				end
			end
		end
		self:settext("")
	end,
	CurrentStepsChangedMessageCommand = function(self)
		self:playcommand("Set", {Song = self.hv_lastSong})
	end
}

-- Artist / Subtitle line - uses params.Song
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "ArtistSubtitle",
	InitCommand = function(self)
		self:halign(0.5):x(0):y(11)
			:zoom(0.30):diffuse(color("0.5,0.5,0.5,1"))
			:maxwidth((wheelItemW - 40) / 0.30)
	end,
	SetMessageCommand = function(self, params)
		local song = params and params.Song
		if song then
			local artist = song:GetDisplayArtist() or ""
			local subtitle = song:GetDisplaySubTitle() or ""
				self:settext(artist)
		else
			self:settext("")
		end
	end
}

-- Bottom separator (OLED: very subtle, barely visible hairline)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:y(19):zoomto(wheelItemW, 1)
			:diffuse(color("0.08,0.08,0.08,1"))
	end
}

-- Engine text color override
t[#t + 1] = Def.Actor {
	SetMessageCommand = function(self)
		local normalPart = self:GetParent()
		if not normalPart then return end
		local mwi = normalPart:GetParent()
		if not mwi then return end

		local names = {"SongName", "SubTitle", "Sort", "Roulette", "Random", "Custom", "Portal", "Mode"}
		for _, name in ipairs(names) do
			local textActor = mwi:GetChild(name)
			if textActor and textActor:GetVisible() then
				textActor:diffuse(HVColor.Accent)
				-- Apply maxwidth and centering in Lua to avoid metrics issues
				if textActor.maxwidth then
					textActor:maxwidth(wheelItemW * 0.8 / textActor:GetZoom())
				end
			end
		end
	end,
	ColorThemeChangedMessageCommand = function(self) self:playcommand("Set") end
}

return t
