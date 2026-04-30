local usersZoom = 0.45
local usersWidth = 64
local usersWidthSmall = 40
local usersWidthZoom = usersWidth * (1 / usersZoom)
local usersWidthSmallZoom = usersWidthSmall * (1 / usersZoom)
local usersRowSize = 6
local usersRowSizeSmall = 10
local usersX = 24
local usersY = SCREEN_HEIGHT - 62
local usersXGap = 6
local usersYGap = 10
local usersHeight = 8

local lobbos = {}
local accentColor = HVColor.Accent
local subText = color("0.75,0.75,0.75,1")
local r = Def.ActorFrame {
	BeginCommand = function(self)
		self:queuecommand("Set")
	end,
	InitCommand = function(self)
		self:queuecommand("Set")
	end,
	SetCommand = function(self)
		lobbos = NSMAN:GetLobbyUserList() or {}
	end,
	UsersUpdateMessageCommand = function(self)
		self:queuecommand("Set")
	end,
	PlayerJoinedMessageCommand = function(self)
		self:queuecommand("Set")
	end,
	PlayerUnjoinedMessageCommand = function(self)
		self:queuecommand("Set")
	end
}

local function userLabel(i)
	return LoadFont("Common Normal") .. {
		Name = i,
		BeginCommand = function(self)
			self:halign(0)
			self:zoom(usersZoom):diffuse(subText):queuecommand("Set")
		end,
		SetCommand = function(self)
			if SCREENMAN:GetTopScreen():GetName() ~= "ScreenNetRoom" then
				return
			end
			local num = self:GetName() + 0
			if num <= #lobbos then
				self:settext(lobbos[num])
				self:diffuse(num == 1 and accentColor or subText)
			else
				self:settext("")
			end
			if #lobbos < 13 then
				self:x(usersX + (usersWidth + usersXGap) * ((i - 1) % usersRowSize))
				self:y(usersY + math.floor((i - 1) / usersRowSize) * (usersHeight + usersYGap))
				self:maxwidth(usersWidthZoom)
			else
				self:x(usersX + (usersWidthSmall + usersXGap / 2) * ((i - 1) % usersRowSizeSmall))
				self:y(usersY + math.floor((i - 1) / usersRowSizeSmall) * (usersHeight + usersYGap))
				self:maxwidth(usersWidthSmallZoom)
			end
		end,
		UsersUpdateMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		PlayerJoinedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		PlayerUnjoinedMessageCommand = function(self)
			self:queuecommand("Set")
		end
	}
end

for i = 1, 40 do
	r[#r + 1] = userLabel(i)
end

return r
