local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local dimText = color("0.55,0.55,0.55,1")
local bgCard = color("0.06,0.06,0.06,0.9")
local activeCard = color("0.12,0.12,0.12,0.98")
local panelW = 220
local panelH = 60
local panelX = SCREEN_WIDTH - panelW - 12
local panelY = 46

local function currentScreenIsNet()
	local top = SCREENMAN:GetTopScreen()
	return top ~= nil and top:GetName() == "ScreenNetSelectMusic"
end

local function getReadyState()
	local top = SCREENMAN:GetTopScreen()
	if not top or top:GetName() ~= "ScreenNetSelectMusic" then
		return false
	end
	local qty = top:GetUserQty()
	local loggedInUser = NSMAN:GetLoggedInUsername()
	for i = 1, qty do
		if top:GetUser(i) == loggedInUser then
			return top:GetUserReady(i)
		end
	end
	return false
end

return Def.ActorFrame {
	Name = "NetPlayPanel",
	InitCommand = function(self)
		self:xy(panelX, panelY)
		self:visible(currentScreenIsNet())
	end,
	OnCommand = function(self)
		self:queuecommand("Refresh")
	end,
	RefreshCommand = function(self)
		self:visible(currentScreenIsNet())
		local roomLabel = self:GetChild("RoomName")
		if roomLabel then
			local roomName = NSMAN:GetCurrentRoomName()
			roomLabel:settext(roomName and roomName ~= "" and roomName or "NETPLAY")
		end
		self:GetChild("ReadyButton"):playcommand("Refresh")
		self:GetChild("ForceButton"):playcommand("Refresh")
	end,
	UsersUpdateMessageCommand = function(self)
		self:playcommand("Refresh")
	end,
	ChatMessageCommand = function(self)
		self:playcommand("Refresh")
	end,
	PlayerJoinedMessageCommand = function(self)
		self:playcommand("Refresh")
	end,
	PlayerUnjoinedMessageCommand = function(self)
		self:playcommand("Refresh")
	end,
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(panelW, panelH):diffuse(bgCard)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(2, panelH):diffuse(accentColor):diffusealpha(0.5)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "RoomName",
		InitCommand = function(self)
			self:halign(0):valign(0):xy(10, 8):zoom(0.34):diffuse(brightText):maxwidth((panelW - 20) / 0.34)
		end
	},
	Def.ActorFrame {
		Name = "ReadyButton",
		InitCommand = function(self)
			self:xy(10, 30)
		end,
		RefreshCommand = function(self)
			local readied = getReadyState()
			self:GetChild("Bg"):diffuse(readied and activeCard or color("0.1,0.1,0.1,0.95"))
			self:GetChild("Label"):settext(THEME:GetString("ScreenSelectMusic", readied and "Unready" or "Ready"))
			self:GetChild("Label"):diffuse(readied and accentColor or brightText)
		end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(92, 22):diffuse(color("0.1,0.1,0.1,0.95"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(46, 11):zoom(0.28):diffuse(brightText)
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(92, 22):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and currentScreenIsNet() then
					NSMAN:SendChatMsg("/ready", 1, NSMAN:GetCurrentRoomName())
					self:GetParent():playcommand("Refresh")
				end
			end
		}
	},
	Def.ActorFrame {
		Name = "ForceButton",
		InitCommand = function(self)
			self:xy(110, 30)
		end,
		RefreshCommand = function(self)
			self:GetChild("Bg"):diffuse(color("0.1,0.1,0.1,0.95"))
			self:GetChild("Label"):settext(THEME:GetString("ScreenSelectMusic", "ForceStart"))
			self:GetChild("Label"):diffuse(dimText)
		end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(100, 22):diffuse(color("0.1,0.1,0.1,0.95"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(50, 11):zoom(0.28):diffuse(dimText)
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(100, 22):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and currentScreenIsNet() then
					NSMAN:SendChatMsg("/force", 1, NSMAN:GetCurrentRoomName())
					self:GetParent():playcommand("Refresh")
				end
			end
		}
	}
}
