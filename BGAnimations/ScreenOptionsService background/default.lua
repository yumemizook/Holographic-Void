local t = Def.ActorFrame {}
local parallaxZoom = 1.06
local parallaxX = 20
local parallaxY = 12
local bgActor = nil

-- Background Image
t[#t + 1] = LoadActor(THEME:GetPathG("", "background.jpg")) .. {
	InitCommand = function(self)
		bgActor = self
		self:Center():zoomto(SCREEN_WIDTH * parallaxZoom, SCREEN_HEIGHT * parallaxZoom)
		self.hv_curX = SCREEN_CENTER_X
		self.hv_curY = SCREEN_CENTER_Y
		self.hv_targetX = SCREEN_CENTER_X
		self.hv_targetY = SCREEN_CENTER_Y
	end
}

t[#t + 1] = Def.ActorFrame {
	OnCommand = function(self)
		self:SetUpdateFunction(function(actor)
			if not bgActor then return end
			local parallaxOn = (HV and HV.ParallaxEnabled and HV.ParallaxEnabled())
			if parallaxOn then
				local mx = INPUTFILTER:GetMouseX() or SCREEN_CENTER_X
				local my = INPUTFILTER:GetMouseY() or SCREEN_CENTER_Y
				local nx = (mx / SCREEN_WIDTH) - 0.5
				local ny = (my / SCREEN_HEIGHT) - 0.5
				bgActor.hv_targetX = SCREEN_CENTER_X + (nx * 2 * parallaxX)
				bgActor.hv_targetY = SCREEN_CENTER_Y + (ny * 2 * parallaxY)
			else
				bgActor.hv_targetX = SCREEN_CENTER_X
				bgActor.hv_targetY = SCREEN_CENTER_Y
			end
			bgActor.hv_curX = bgActor.hv_curX + (bgActor.hv_targetX - bgActor.hv_curX) * 0.16
			bgActor.hv_curY = bgActor.hv_curY + (bgActor.hv_targetY - bgActor.hv_curY) * 0.16
			bgActor:xy(bgActor.hv_curX, bgActor.hv_curY)
		end)
	end
}

-- Grey Quad Overlay
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:diffuse(color("0.08,0.08,0.08,0.8"))
	end
}

-- Particles
t[#t + 1] = LoadActor("../_particles.lua")

return t
