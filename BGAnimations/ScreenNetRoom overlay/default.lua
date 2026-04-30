local t = Def.ActorFrame {}
local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local subText = color("0.65,0.65,0.65,1")
local dimText = color("0.45,0.45,0.45,1")
local bgCard = color("0.06,0.06,0.06,0.92")
local roomWidth = SCREEN_WIDTH - 40
local roomHeight = 52
local roomGap = 10
local topOffset = 56
local footerH = 32
local maxVisibleRooms = math.max(1, math.floor((SCREEN_HEIGHT - topOffset - footerH - 24) / (roomHeight + roomGap)))

local function roomText(room, key, fallback)
	if room == nil then return fallback end
	local value = room[key]
	if value == nil or value == "" then
		return fallback
	end
	return tostring(value)
end

local function roomList()
	local selectedIndex = 1
	local roomCount = 0
	local creatingRoom = false
	local scrollOffset = 0

	local function clampSelection()
		if roomCount <= 0 then
			selectedIndex = 1
			creatingRoom = true
			scrollOffset = 0
			return
		end
		if selectedIndex < 1 then selectedIndex = roomCount end
		if selectedIndex > roomCount then selectedIndex = 1 end
		if selectedIndex <= scrollOffset then
			scrollOffset = selectedIndex - 1
		end
		if selectedIndex > scrollOffset + maxVisibleRooms then
			scrollOffset = selectedIndex - maxVisibleRooms
		end
		if scrollOffset < 0 then scrollOffset = 0 end
	end

	return Def.ActorFrame {
		Name = "HVNetRoomList",
		OnCommand = function(self)
			SCREENMAN:set_input_redirected(PLAYER_1, true)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:AddInputCallback(function(event)
					if event.type ~= "InputEventType_FirstPress" and event.type ~= "InputEventType_Repeat" then
						return false
					end
					local button = event.button
					if button == "Back" then
						screen:Cancel()
						return true
					end
					if button == "MenuLeft" or button == "Left" or button == "MenuRight" or button == "Right" then
						creatingRoom = not creatingRoom
						MESSAGEMAN:Broadcast("HVNetRoomRefresh")
						return true
					end
					if button == "MenuUp" or button == "Up" then
						if creatingRoom then
							creatingRoom = false
							selectedIndex = math.max(1, roomCount)
						else
							selectedIndex = selectedIndex - 1
						end
						clampSelection()
						MESSAGEMAN:Broadcast("HVNetRoomRefresh")
						return true
					end
					if button == "MenuDown" or button == "Down" then
						if roomCount == 0 then
							creatingRoom = true
						elseif creatingRoom then
							creatingRoom = false
							selectedIndex = 1
						else
							selectedIndex = selectedIndex + 1
						end
						clampSelection()
						MESSAGEMAN:Broadcast("HVNetRoomRefresh")
						return true
					end
					if button == "Start" then
						if creatingRoom then
							screen:GetRoomWheel():MakeNewRoom()
						elseif roomCount > 0 then
							local rooms = screen:GetRoomWheel():GetRooms()
							local room = rooms[selectedIndex]
							if room then
								screen:SelectRoom(room.name)
							end
						end
						return true
					end
					return false
				end)
			end
			self:playcommand("Refresh")
		end,
		RefreshCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if not screen then return end
			local rooms = screen:GetRoomWheel():GetRooms()
			roomCount = #rooms
			clampSelection()
			for i = 1, maxVisibleRooms do
				local roomActor = self:GetChild("Room" .. i)
				local roomIndex = i + scrollOffset
				local room = rooms[roomIndex]
				if roomActor then
					roomActor:visible(room ~= nil)
					if room then
						roomActor:playcommand("SetRoom", {
							room = room,
							selected = not creatingRoom and roomIndex == selectedIndex,
							index = roomIndex
						})
					end
				end
			end
			local noRooms = self:GetChild("NoRooms")
			if noRooms then
				noRooms:visible(roomCount == 0)
			end
			local create = self:GetChild("CreateRoom")
			if create then
				create:playcommand("SetSelected", {selected = creatingRoom})
			end
		end,
		HVNetRoomRefreshMessageCommand = function(self)
			self:playcommand("Refresh")
		end,
		LoadFont("Common Normal") .. {
			Name = "NoRooms",
			InitCommand = function(self)
				self:xy(20, topOffset + 12):zoom(0.4):halign(0):diffuse(dimText)
				self:settext(THEME:GetString("NetRoom", "NoRooms"))
				self:visible(false)
			end
		},
		Def.ActorFrame {
			Name = "CreateRoom",
			InitCommand = function(self)
				self:xy(20, SCREEN_HEIGHT - footerH - 8)
			end,
			SetSelectedCommand = function(self, params)
				local selected = params and params.selected
				self:GetChild("Bg"):diffuse(selected and accentColor or color("0.1,0.1,0.1,0.95"))
				self:GetChild("Label"):diffuse(selected and color("0,0,0,1") or brightText)
			end,
			Def.Quad {
				Name = "Bg",
				InitCommand = function(self)
					self:halign(0):valign(0):zoomto(160, footerH):diffuse(color("0.1,0.1,0.1,0.95"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "Label",
				InitCommand = function(self)
					self:halign(0):valign(0):xy(10, 7):zoom(0.4):diffuse(brightText)
					self:settext(THEME:GetString("NetRoom", "CreateRoom"))
				end
			},
			UIElements.QuadButton(1, 1) .. {
				InitCommand = function(self)
					self:halign(0):valign(0):zoomto(160, footerH):diffusealpha(0)
				end,
				MouseDownCommand = function(self, params)
					if params.event == "DeviceButton_left mouse button" then
						local screen = SCREENMAN:GetTopScreen()
						if screen then
							screen:GetRoomWheel():MakeNewRoom()
						end
					end
				end
			}
		}
	}
end

local function roomEntry(i)
	return Def.ActorFrame {
		Name = "Room" .. i,
		InitCommand = function(self)
			self:xy(20, topOffset + ((i - 1) * (roomHeight + roomGap)))
		end,
		SetRoomCommand = function(self, params)
			local room = params.room
			local selected = params.selected
			self:GetChild("Bg"):diffuse(selected and color("0.12,0.12,0.12,0.98") or bgCard)
			self:GetChild("Accent"):diffuse(selected and accentColor or color("0.2,0.2,0.2,1"))
			self:GetChild("Name"):settext(roomText(room, "name", "Room"))
			self:GetChild("Desc"):settext(roomText(room, "description", THEME:GetString("NetRoom", "Explain")))
			self:GetChild("State"):settext(room and room.passworded and THEME:GetString("NetRoom", "Passworded") or "")
		end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(roomWidth, roomHeight):diffuse(bgCard)
			end
		},
		Def.Quad {
			Name = "Accent",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(2, roomHeight):diffuse(color("0.2,0.2,0.2,1"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Name",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(10, 6):zoom(0.42):diffuse(brightText):maxwidth((roomWidth - 40) / 0.42)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Desc",
			InitCommand = function(self)
				self:halign(0):valign(0):xy(10, 28):zoom(0.3):diffuse(subText):maxwidth((roomWidth - 110) / 0.3)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "State",
			InitCommand = function(self)
				self:halign(1):valign(0):xy(roomWidth - 10, 18):zoom(0.28):diffuse(accentColor)
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(roomWidth, roomHeight):diffusealpha(0)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					local screen = SCREENMAN:GetTopScreen()
					local roomName = self:GetParent():GetChild("Name"):GetText()
					if screen and roomName and roomName ~= "" then
						screen:SelectRoom(roomName)
					end
				end
			end,
			MouseOverCommand = function(self)
				MESSAGEMAN:Broadcast("HVNetRoomRefresh")
			end,
			MouseOutCommand = function(self)
				MESSAGEMAN:Broadcast("HVNetRoomRefresh")
			end
		}
	}
end

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.55"))
	end
}

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(0, 0):zoomto(SCREEN_WIDTH, 40):diffuse(color("0.03,0.03,0.03,0.98"))
	end
}

t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:halign(0):valign(0):xy(16, 10):zoom(0.6):diffuse(brightText)
		self:settext(THEME:GetString("NetRoom", "Name"))
	end
}

t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:halign(1):valign(0):xy(SCREEN_WIDTH - 16, 11):zoom(0.32):diffuse(dimText)
		self:settext(THEME:GetString("NetRoom", "Explain"))
	end
}

local list = roomList()
for i = 1, maxVisibleRooms do
	list[#list + 1] = roomEntry(i)
end
t[#t + 1] = list

t[#t + 1] = LoadActor("lobbyuserlist.lua")
t[#t + 1] = LoadActor("../_cursor")

return t
