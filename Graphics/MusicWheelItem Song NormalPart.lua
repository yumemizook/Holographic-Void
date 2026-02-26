--- Holographic Void: MusicWheelItem Song NormalPart
-- Enhanced song row: MSD for selected difficulty type, local best grade,
-- artist + subtitle display.
-- Uses SetMessageCommand with params.Song for reliable song data access.

local wheelItemW = 280

local t = Def.ActorFrame {}

-- Card background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(wheelItemW, 32):diffuse(color("0.08,0.08,0.08,1"))
	end,
	SetMessageCommand = function(self)
		self:stoptweening():linear(0.1)
	end,
	GainFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.14,0.14,0.14,1"))
	end,
	LoseFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.08,0.08,0.08,1"))
	end
}

-- Left accent bar (difficulty color) - uses GAMESTATE for current selected diff
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(-wheelItemW/2 + 2):zoomto(3, 28)
			:diffuse(color("0.3,0.3,0.3,1"))
	end,
	SetMessageCommand = function(self)
		local curSteps = GAMESTATE:GetCurrentSteps()
		if curSteps then
			local diff = ToEnumShortString(curSteps:GetDifficulty())
			local dc = (HVColor and HVColor.Difficulty and HVColor.Difficulty[diff])
			if dc then self:diffuse(dc):diffusealpha(0.7) return end
		end
		self:diffuse(color("0.3,0.3,0.3,1"))
	end,
	CurrentStepsChangedMessageCommand = function(self)
		local curSteps = GAMESTATE:GetCurrentSteps()
		if curSteps then
			local diff = ToEnumShortString(curSteps:GetDifficulty())
			local dc = (HVColor and HVColor.Difficulty and HVColor.Difficulty[diff])
			if dc then self:diffuse(dc):diffusealpha(0.7) return end
		end
		self:diffuse(color("0.3,0.3,0.3,1"))
	end
}

-- MSD rating text (right side) - shows MSD for the SAME difficulty as selected
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "MSDDisplay",
	InitCommand = function(self)
		self:halign(1):x(wheelItemW/2 - 6):y(-4)
			:zoom(0.32):diffuse(color("0.65,0.65,0.65,1"))
	end,
	SetMessageCommand = function(self, params)
		if params and params.Song then self.hv_song = params.Song end
		local song = self.hv_song
		if not song then self:settext("") return end
		local curSteps = GAMESTATE:GetCurrentSteps()
		if not curSteps then self:settext("") return end
		local targetDiff = curSteps:GetDifficulty()
		local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType()) or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))
		if allSteps then
			for _, st in ipairs(allSteps) do
				if st:GetDifficulty() == targetDiff then
					local msd = st:GetMSD(getCurRateValue(), 1)
					if msd and msd > 0 then
						self:settext(string.format("%.1f", msd))
						self:diffuse(HVColor.GetMSDRatingColor(msd))
					else
						self:settext("-")
						self:diffuse(color("0.45,0.45,0.45,1"))
					end
					return
				end
			end
		end
		self:settext("")
	end,
	CurrentStepsChangedMessageCommand = function(self) if self.hv_song then self:playcommand("Set") end end,
	CurrentRateChangedMessageCommand = function(self) if self.hv_song then self:playcommand("Set") end end
}

-- Grade badge (right side, below MSD) - shows grade for matching difficulty
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "GradeDisplay",
	InitCommand = function(self)
		self:halign(1):x(wheelItemW/2 - 6):y(7)
			:zoom(0.22):diffuse(color("0.45,0.45,0.45,1"))
	end,
	SetMessageCommand = function(self, params)
		if params and params.Song then self.hv_song = params.Song end
		local song = self.hv_song
		local curSteps = GAMESTATE:GetCurrentSteps()
		if not song or not curSteps then self:settext("") return end
		local targetDiff = curSteps:GetDifficulty()
		local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType()) or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))
		if allSteps then
			for _, st in ipairs(allSteps) do
				if st:GetDifficulty() == targetDiff then
					local profile = PROFILEMAN:GetProfile(PLAYER_1)
					if profile then
						local chartKey = st:GetChartKey()
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
									self:settext(gs)
									self:diffuse(HVColor.GetGradeColor(gs))
									return
								end
							end
						end
					end
				end
			end
		end
		self:settext("")
	end,
	CurrentStepsChangedMessageCommand = function(self) if self.hv_song then self:playcommand("Set") end end
}

-- Artist / Subtitle line - uses params.Song
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "ArtistSubtitle",
	InitCommand = function(self)
		self:halign(0):x(-wheelItemW/2 + 10):y(8)
			:zoom(0.2):diffuse(color("0.5,0.5,0.5,1"))
			:maxwidth((wheelItemW - 80) / 0.2)
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

-- Bottom border line
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:y(16):zoomto(wheelItemW, 1)
			:diffuse(color("0.12,0.12,0.12,1"))
	end
}

return t
