--- Holographic Void: ScreenEvaluation Decorations
-- Ported from spawncamping-wallhack for modularity and high-level play analysis.
-- Features: Modular scoreBoard(pn), Horizontal Judgments, Robust Clear Types, 
--           Paginated Scoreboard, Offset Plot, Life Graph.

local t = Def.ActorFrame {
	Name = "EvalDecorations"
}

-- Colors & Styles (HV Palette)
local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.06,0.06,0.06,0.95")

-- Judgment and Grade data from localization
local judgmentTNS = {
	"TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3",
	"TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss"
}
local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
}

-- ============================================================
-- HELPER: Robust Clear Type detection
-- ============================================================
local function getCTColor(ct)
	return HVColor.GetClearTypeColor(ct)
end

-- ============================================================
-- THE SCOREBOARD (Modular function for left/right player support)
-- ============================================================
local function scoreBoard(pn)
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
	local song = GAMESTATE:GetCurrentSong()
	local steps = GAMESTATE:GetCurrentSteps()
	
	local frameX = 10
	local frameY = 10
	local frameW = SCREEN_CENTER_X - 20
	local frameH = SCREEN_HEIGHT - 20
	local pad = 12

	local t = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(frameX, frameY)
		end,

		-- Main Background
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(frameW, frameH):diffuse(bgCard)
			end
		},

		-- Banner Support
		Def.Sprite {
			Name = "Banner",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad)
			end,
			OnCommand = function(self)
				if song then
					local bpath = song:GetBannerPath()
					if not bpath then bpath = THEME:GetPathG("Common", "fallback banner") end
					self:LoadBackground(bpath)
					self:scaletofit(0, 0, 140, 44)
				end
			end
		},

		-- Song Info (Title/Artist)
		LoadFont("Zpix Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 150, pad - 2):zoom(0.4):diffuse(brightText)
				self:maxwidth((frameW - pad - 160) / 0.4)
			end,
			OnCommand = function(self)
				if song then self:settext(song:GetDisplayMainTitle()) end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 150, pad + 18):zoom(0.28):diffuse(subText)
				self:maxwidth((frameW - pad - 160) / 0.28)
			end,
			OnCommand = function(self)
				if song then self:settext(song:GetDisplayArtist()) end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad + 150, pad + 32):zoom(0.22):diffuse(dimText)
			end,
			OnCommand = function(self)
				if steps then
					local diff = ToEnumShortString(steps:GetDifficulty())
					local rate = getCurRateString()
					self:settext(diff .. " · " .. rate)
				end
			end
		},

		-- Separator
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):xy(pad, pad + 55):zoomto(frameW - pad*2, 1):diffuse(color("0.1,0.1,0.1,1"))
			end
		},

		-- Large Score Area
		Def.ActorFrame {
			Name = "MainScore",
			InitCommand = function(self) self:xy(pad, pad + 70) end,
			
			-- Grade
			LoadFont("Common Large") .. {
				Name = "GradeLetter",
				InitCommand = function(self) self:halign(0):valign(0):zoom(0.9) end,
				OnCommand = function(self)
					local wifePct = pss:GetWifeScore() * 100
					local grade = getEtternaGrade(wifePct)
					
					-- Override with Failed if applicable
					local detailedCT = getDetailedClearType(pss)
					if detailedCT == "Failed" then 
						grade = "Failed" 
					end
					
					self:settext(THEME:GetString("Grade", grade))
					self:diffuse(HVColor.GetGradeColor(grade))
				end
			},
			
			-- % Score
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):xy(80, 0):zoom(0.65):diffuse(accentColor) end,
				OnCommand = function(self)
					local wifePct = pss:GetWifeScore() * 100
					self:settext(string.format(wifePct > 99 and "%.4f%%" or "%.2f%%", wifePct))
				end
			},

			-- WifeDP & SSR
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):xy(80, 24):zoom(0.3):diffuse(subText) end,
				OnCommand = function(self)
					local dp = pss:GetWifeScore() * (steps:GetRadarValues():GetValue("RadarCategory_Notes") * 2)
					self:settext(string.format("WifeDP: %.2f", dp))
				end
			},
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):xy(80, 40):zoom(0.3) end,
				OnCommand = function(self)
					local ssr = pss:GetHighScore():GetSkillsetSSR("Overall")
					if ssr > 0 then
						self:settext(string.format("SSR: %.2f", ssr)):diffuse(HVColor.GetMSDRatingColor(ssr))
					else
						self:settext("SSR: N/A"):diffuse(dimText)
					end
				end
			},

			-- Clear Type Lamp
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):xy(0, 50):zoom(0.35) end,
				OnCommand = function(self)
					local ct = getDetailedClearType(pss)
					self:settext(THEME:GetString("ClearTypes", ct)):diffuse(getCTColor(ct))
				end
			}
		},

		-- Horizontal Judgment Grid
		Def.ActorFrame {
			Name = "Judgments",
			InitCommand = function(self) self:xy(pad, pad + 150) end,
			
			Def.Quad { -- Header BG
				InitCommand = function(self) self:halign(0):zoomto(frameW - pad*2, 22):diffuse(color("0.1,0.1,0.1,0.5")):valign(0) end
			},
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):valign(0):xy(4, 4):zoom(0.3):diffuse(accentColor):settext("JUDGMENTS") end
			}
		}
	}

	-- Add the horizontal judgment rows
	local itemSpacing = (frameW - pad*2) / 6
	for i, tns in ipairs(judgmentTNS) do
		local jx = (i - 0.5) * itemSpacing
		t[#t].Judgments[#t[#t].Judgments + 1] = Def.ActorFrame {
			InitCommand = function(self) self:x(jx) end,
			
			-- Result Name
			LoadFont("Common Normal") .. {
				InitCommand = function(self) 
					self:y(30):zoom(0.24):diffuse(judgmentColors[i])
					self:settext(THEME:GetString("TapNoteScore", ToEnumShortString(tns)))
				end
			},
			-- Count
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:y(45):zoom(0.35):diffuse(brightText) end,
				OnCommand = function(self) self:settext(pss:GetTapNoteScores(tns)) end
			},
			-- %
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:y(58):zoom(0.2):diffuse(dimText) end,
				OnCommand = function(self)
					local pct = pss:GetPercentageOfTaps(tns)
					if tostring(pct) == tostring(0/0) then pct = 0 end
					self:settext(string.format("%.1f%%", pct * 100))
				end
			}
		}
	end

	-- Hold Stats & More
	t[#t + 1] = Def.ActorFrame {
		Name = "MiscStats",
		InitCommand = function(self) self:xy(pad, pad + 230) end,
		
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):zoom(0.22):diffuse(subText) end,
			OnCommand = function(self)
				local ok = pss:GetHoldNoteScores("HoldNoteScore_Held")
				local ng = pss:GetHoldNoteScores("HoldNoteScore_LetGo")
				self:settext(string.format("Holds: %d OK / %d NG", ok, ng))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(1):x(frameW - pad*2):zoom(0.22):diffuse(subText) end,
			OnCommand = function(self)
				self:settext("Max Combo: " .. pss:MaxCombo())
			end
		}
	}

	-- Offset Metrics
	t[#t + 1] = Def.ActorFrame {
		Name = "OffsetMetrics",
		InitCommand = function(self) self:xy(pad, frameH - 40) end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):zoom(0.24):diffuse(accentColor):settext("OFFSET STATS") end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):y(15):zoom(0.26):diffuse(mainText) end,
			OnCommand = function(self)
				local offsets = pss:GetOffsetVector()
				if #offsets > 0 then
					local sum, sumAbs = 0, 0
					for _, v in ipairs(offsets) do
						sum = sum + v
						sumAbs = sumAbs + math.abs(v)
					end
					self:settextf("Mean: %+.2fms  |Mean|: %.2fms", (sum/#offsets)*1000, (sumAbs/#offsets)*1000)
				else
					self:settext("N/A")
				end
			end
		}
	}

	return t
end

-- ============================================================
-- ASSEMBLY
-- ============================================================

-- Left: Scoreboard (Evaluation Card)
t[#t + 1] = scoreBoard(PLAYER_1)

-- Right Panel (Shared sc-wh logic for plot and list)
local rightX = SCREEN_CENTER_X + 10
local rightW = SCREEN_CENTER_X - 20

t[#t + 1] = Def.ActorFrame {
	Name = "RightPanel",
	InitCommand = function(self) self:x(rightX) end,

	-- BG
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(0, 10):zoomto(rightW, SCREEN_HEIGHT - 20):diffuse(bgCard)
		end
	},

	-- Offset Plot (Small)
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(10, 20):zoomto(rightW - 20, 100):diffuse(color("0,0,0,0.5"))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(20, 30):zoom(0.2):diffuse(dimText):halign(0):settext("OFFSET PLOT") end
	},
	-- Simple Plot Dots
	Def.ActorFrame {
		InitCommand = function(self) self:xy(10 + (rightW-20)/2, 70) end,
		BeginCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			local offsets = pss:GetOffsetVector()
			local plotW = rightW - 40
			local count = math.min(#offsets, 400)
			for i = 1, count do
				local off = offsets[i]
				local c = math.abs(off) < 0.0225 and color("#FFFFFF") or color("#FF8888")
				local dot = Def.Quad {
					InitCommand = function(s)
						s:xy((off/0.18)*(plotW/2), (i/count-0.5)*70):zoomto(1.5, 1.5):diffuse(c):diffusealpha(0.4)
					end
				}
				self:AddChild(dot)
			end
		end
	},

	-- Scoreboard List (Paginated)
	Def.ActorFrame {
		Name = "PaginatedScoreboard",
		InitCommand = function(self) self:xy(10, 135) end,
		BeginCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:AddInputCallback(function(event)
					if event.type == "InputEventType_FirstPress" then
						if event.button == "MenuLeft" or event.DeviceInput.button == "DeviceButton_mousewheel up" then
							MESSAGEMAN:Broadcast("PrevScorePage")
						elseif event.button == "MenuRight" or event.DeviceInput.button == "DeviceButton_mousewheel down" then
							MESSAGEMAN:Broadcast("NextScorePage")
						end
					end
				end)
			end
		end,

		-- Header
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.24):diffuse(accentColor):halign(0):settext("SCOREBOARD") end
		},
		
		-- Rows (Max 7)
		Def.ActorFrame {
			Name = "ScoreRows",
			InitCommand = function(self) self:y(20) end,
			OnCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				local curScore = pss:GetHighScore()
				local rtTable = getRateTable()
				local curRate = getCurRateString()
				if curRate == "1x" then curRate = "1.0x" end
				if curRate == "2x" then curRate = "2.0x" end
				
				local hsTable = {}
				if rtTable and rtTable[curRate] then
					hsTable = rtTable[curRate]
					table.sort(hsTable, function(a, b) return a:GetWifeScore() > b:GetWifeScore() end)
				end
				local scoreIndex = 1
				for i, hs in ipairs(hsTable) do
					if hs:GetDate() == curScore:GetDate() then
						scoreIndex = i
						break
					end
				end

				local rowsPerPage = 6
				local curPage = math.ceil(scoreIndex / rowsPerPage)
				local totalPages = math.max(1, math.ceil(#hsTable / rowsPerPage))

				local function updateRows()
					self:RemoveAllChildren()
					local start = (curPage - 1) * rowsPerPage + 1
					local finish = math.min(start + rowsPerPage - 1, #hsTable)
					
					for i = start, finish do
						local hs = hsTable[i]
						local rowY = (i - start) * 28
						local isCurrent = (i == scoreIndex)
						
						self:AddChild(Def.ActorFrame {
							InitCommand = function(s) s:y(rowY) end,
							-- Row BG
							Def.Quad {
								InitCommand = function(s) s:zoomto(rightW - 20, 24):halign(0):diffuse(color("0,0,0,0.3")) end,
								OnCommand = function(s) if isCurrent then s:diffuse(accentColor):diffusealpha(0.1) end end
							},
							-- Rank
							LoadFont("Common Normal") .. {
								InitCommand = function(s) s:xy(4, 0):zoom(0.24):halign(0):diffuse(dimText):settext(i .. ".") end
							},
							-- Grade
							LoadFont("Common Normal") .. {
								InitCommand = function(s) 
									local g = ToEnumShortString(hs:GetWifeGrade())
									s:xy(25, 0):zoom(0.28):halign(0)
									s:settext(THEME:GetString("Grade", g))
									s:diffuse(HVColor.GetGradeColor(g))
								end
							},
							-- Score %
							LoadFont("Common Normal") .. {
								InitCommand = function(s) s:xy(80, 0):zoom(0.3):halign(0):diffuse(mainText):settext(string.format("%.2f%%", hs:GetWifeScore() * 100)) end
							},
							-- Combo
							LoadFont("Common Normal") .. {
								InitCommand = function(s) s:xy(rightW - 25, 0):zoom(0.22):halign(1):diffuse(dimText):settext("x" .. hs:GetMaxCombo()) end
							}
						})
					end
					
					-- Page Info
					self:AddChild(LoadFont("Common Normal") .. {
						InitCommand = function(s) s:xy(rightW - 20, -20):zoom(0.2):halign(1):diffuse(dimText) end,
						OnCommand = function(s) s:settext(string.format("Page %d/%d", curPage, totalPages)) end
					})
				end

				self:AddChild(Def.Actor {
					NextScorePageMessageCommand = function()
						if curPage < totalPages then curPage = curPage + 1 updateRows() end
					end,
					PrevScorePageMessageCommand = function()
						if curPage > 1 then curPage = curPage - 1 updateRows() end
					end
				})

				updateRows()
			end
		}
	}
}

return t
