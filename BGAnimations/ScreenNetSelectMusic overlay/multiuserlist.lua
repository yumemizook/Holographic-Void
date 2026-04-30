local usersZoom = 0.5
local usersWidth = 76
local usersWidthSmall = 52
local usersWidthZoom = usersWidth * (1 / usersZoom)
local usersWidthSmallZoom = usersWidthSmall * (1 / usersZoom)
local usersRowSize = 6
local usersRowSizeSmall = 8
local usersX = SCREEN_CENTER_X - 40
local usersY = 14
local usersXGap = 8
local usersYGap = 12
local usersHeight = 10

local top = SCREENMAN:GetTopScreen()
local qty = 0
local dimText = color("0.55,0.55,0.55,1")
local readyText = color("0.75,1,0.85,1")
local busyText = color("0.65,0.75,1,1")
local optionsText = HVColor.Accent
local evalText = color("1,1,1,1")

local r = Def.ActorFrame {
	BeginCommand = function(self)
		self:queuecommand("Set")
	end,
	InitCommand = function(self)
		self:queuecommand("Set")
	end,
	SetCommand = function(self)
		top = SCREENMAN:GetTopScreen()
	end,
	UsersUpdateMessageCommand = function(self)
		self:queuecommand("Set")
	end
}

local function userLabel(i)
	local aux = LoadFont("Common Normal") .. {
		Name = i,
		BeginCommand = function(self)
			self:halign(0)
			self:zoom(usersZoom):diffuse(dimText):queuecommand("Set")
		end,
		SetCommand = function(self)
			if SCREENMAN:GetTopScreen():GetName() ~= "ScreenNetSelectMusic" then
				self:settext("")
				return
			end
			local num = self:GetName() + 0
			qty = top:GetUserQty()
			if num <= qty then
				self:settext(top:GetUser(num))
				local state = top:GetUserState(num)
				if state == 3 then
					self:diffuse(evalText)
				elseif state == 2 then
					self:diffuse(busyText)
				elseif state == 4 then
					self:diffuse(optionsText)
				else
					if top:GetUserReady(num) then
						self:diffuse(readyText)
					else
						self:diffuse(dimText)
					end
				end
			else
				self:settext("")
			end
			if qty < 7 then
				self:x(usersX + (usersWidth + usersXGap) * ((i - 1) % usersRowSize))
				self:y(usersY)
				self:maxwidth(usersWidthZoom)
			elseif qty < 13 then
				self:x(usersX + (usersWidth + usersXGap) * ((i - 1) % usersRowSize))
				self:y(usersY + math.floor((i - 1) / usersRowSize) * (usersHeight + usersYGap))
				self:maxwidth(usersWidthZoom)
			else
				self:x(usersX + (usersWidthSmall + usersXGap / 2) * ((i - 1) % usersRowSizeSmall))
				self:y(usersY + math.floor((i - 1) / usersRowSizeSmall) * (usersHeight + usersYGap))
				self:maxwidth(usersWidthSmallZoom)
			end
		end,
		PlayerJoinedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		PlayerUnjoinedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		UsersUpdateMessageCommand = function(self)
			self:queuecommand("Set")
		end
	}
	return aux
end

for i = 1, 32 do
	r[#r + 1] = userLabel(i)
end

return r
