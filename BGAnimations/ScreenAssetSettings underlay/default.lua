local top
local profile = PROFILEMAN:GetProfile(PLAYER_1)

local curType = 2 -- Default to Avatar
local assetTypes = {
	"toasty",
	"avatar",
	"judgment",
}

local maxRows = 5
local maxColumns = 5
local curPage = 1
local curIndex = 1
local selectedIndex = 0
local GUID = profile:GetGUID()
local assetTable = {}
local maxPage = 1

local sidebarW = 160
local mainW = SCREEN_WIDTH - sidebarW - 40
local mainH = SCREEN_HEIGHT - 80
local itemW = 80
local itemH = 80
local spacing = 20

local lastClickTime = 0
local lastClickIdx = 0

local function getToastyPreview(dirPath)
	local files = FILEMAN:GetDirListing(dirPath .. "/")
	for _, f in ipairs(files) do
		local ext = f:sub(-4):lower()
		if ext == ".png" or ext == ".jpg" or ext == "jpeg" then
			return dirPath .. "/" .. f
		end
	end
	return nil
end

local function loadAssetTable()
	local type = assetTypes[curType]
	local dir = assetFolders[type]
	
	assetTable = {}
	local files = FILEMAN:GetDirListing(dir)
	for _, f in ipairs(files) do
		-- For toasties, we list directories. For others, we list image files.
		if type == "toasty" then
			if f ~= "." and f ~= ".." then
				table.insert(assetTable, f)
			end
		else
			local ext = f:sub(-4):lower()
			if ext == ".png" or ext == ".jpg" or ext == "jpeg" then
				table.insert(assetTable, f)
			end
		end
	end
	
	maxPage = math.max(1, math.ceil(#assetTable / (maxRows * maxColumns)))
	-- Keep curPage within bounds but try to show selected
	local currentPath = getAssetByType(type, GUID)
	selectedIndex = 0
	for i, f in ipairs(assetTable) do
		if dir .. f == currentPath then
			selectedIndex = i
			curPage = math.ceil(i / (maxRows * maxColumns))
			break
		end
	end
	if curPage > maxPage then curPage = maxPage end
	MESSAGEMAN:Broadcast("UpdateAssetDisplay")
end

local function confirmPick(idx)
	if not idx or idx < 1 or idx > #assetTable then return end
	
	local type = assetTypes[curType]
	local name = assetTable[idx]
	local path = assetFolders[type] .. name
	
	setAssetsByType(type, GUID, path)
	selectedIndex = idx
	MESSAGEMAN:Broadcast("AssetChanged", {type = type, path = path})
	if type == "avatar" then MESSAGEMAN:Broadcast("AvatarChanged") end
	MESSAGEMAN:Broadcast("UpdateAssetDisplay")
	ms.ok("Applied " .. type .. ": " .. name)
end

local t = Def.ActorFrame {
	BeginCommand = function(self)
		top = SCREENMAN:GetTopScreen()
		loadAssetTable()
		self:queuecommand("Refresh")
	end,
	RefreshCommand = function(self)
		MESSAGEMAN:Broadcast("UpdateAssetDisplay")
	end
}

-- Background
t[#t+1] = Def.Quad {
	InitCommand = function(self)
		self:FullScreen():diffuse(HVColor.Black):diffusealpha(0.9)
	end
}

-- Sidebar
t[#t+1] = Def.ActorFrame {
	InitCommand = function(self) self:xy(sidebarW/2 + 10, SCREEN_CENTER_Y) end,
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(sidebarW, SCREEN_HEIGHT - 40):diffuse(HVColor.BG2):diffusealpha(0.5)
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:y(-150):zoom(0.8):settext("ASSETS"):diffuse(HVColor.Accent) end
	}
}

-- Sidebar Tabs
for i, type in ipairs(assetTypes) do
	t[#t+1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(sidebarW/2 + 10, SCREEN_CENTER_Y - 60 + (i-1)*50) end,
		Def.Quad {
			Name = "TabBG",
			InitCommand = function(self)
				self:zoomto(sidebarW - 20, 40):diffuse(HVColor.BG3):diffusealpha(0.2)
			end,
			UpdateAssetDisplayMessageCommand = function(self)
				self:stoptweening():linear(0.1):diffusealpha(curType == i and 0.6 or 0.2)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:zoom(0.5):settext(type:upper()) end,
			UpdateAssetDisplayMessageCommand = function(self)
				self:stoptweening():linear(0.1):diffuse(curType == i and HVColor.Accent or HVColor.Text)
			end
		}
	}
end

-- Main Area Container
local mainAreaX = sidebarW + 20
local mainAreaY = 40
t[#t+1] = Def.ActorFrame {
	Name = "MainArea",
	InitCommand = function(self) self:xy(mainAreaX + mainW/2, mainAreaY + mainH/2) end,
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(mainW, mainH):diffuse(HVColor.BG2):diffusealpha(0.3)
		end
	}
}

-- Asset Grid
local gridAF = Def.ActorFrame {
	InitCommand = function(self) self:xy(mainAreaX + 40, mainAreaY + 40) end,
}

for r = 0, maxRows-1 do
	for c = 0, maxColumns-1 do
		local i = r * maxColumns + c + 1
		gridAF[#gridAF+1] = Def.ActorFrame {
			Name = "Asset_" .. i,
			InitCommand = function(self)
				self:xy(c * (itemW + spacing), r * (itemH + spacing))
			end,
			UpdateAssetDisplayMessageCommand = function(self)
				local idx = ((curPage - 1) * maxRows * maxColumns) + i
				local name = assetTable[idx]
				local sprite = self:GetChild("Sprite")
				local border = self:GetChild("Border")
				local label = self:GetChild("Label")
				
				if name then
					self:visible(true)
					local type = assetTypes[curType]
					local path = assetFolders[type] .. name
					
					local loadPath = path
					if type == "toasty" then
						loadPath = getToastyPreview(path)
						label:visible(true):settext(name)
					else
						label:visible(false)
					end
					
					if loadPath and FILEMAN:DoesFileExist(loadPath) then
						sprite:visible(true)
						if type == "judgment" then
							sprite:Load(loadPath):zoomto(itemW, itemH/3)
						else
							sprite:Load(loadPath):zoomto(itemW, itemH)
						end
					else
						sprite:visible(false)
					end
					
					if selectedIndex == idx then
						border:visible(true):diffuse(HVColor.Accent)
					else
						border:visible(false)
					end
				else
					self:visible(false)
				end
			end,
			
			Def.Quad {
				Name = "Border",
				InitCommand = function(self) self:zoomto(itemW + 4, itemH + 4):visible(false) end
			},
			Def.Sprite {
				Name = "Sprite",
				InitCommand = function(self) self:zoomto(itemW, itemH) end
			},
			LoadFont("Common Normal") .. {
				Name = "Label",
				InitCommand = function(self) self:y(itemH/2 + 5):zoom(0.35):visible(false) end
			}
		}
	end
end
t[#t+1] = gridAF

-- Page Info & Footer
t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:xy(mainAreaX + mainW/2, mainAreaY + mainH - 20):zoom(0.4) end,
	UpdateAssetDisplayMessageCommand = function(self)
		self:settextf("Page %d / %d  (%d assets)", curPage, maxPage, #assetTable)
	end
}

t[#t+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self) self:xy(SCREEN_WIDTH - 80, SCREEN_HEIGHT - 30):zoom(0.4):halign(1) end,
	InitCommand = function(self) self:settext("Left Click: Select/Double (Apply)   Right Click: Back   Scroll: Page") end
}

-- Global Input Handling (Mouse & Keys)
t[#t+1] = Def.Actor {
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" then
				if event.button == "Back" or event.DeviceInput.button == "DeviceButton_right mouse button" then
					SCREENMAN:GetTopScreen():Cancel()
					return true
				end
				
				-- Mouse Wheel
				if event.DeviceInput.button == "DeviceButton_mousewheel up" then
					if curPage > 1 then curPage = curPage - 1 MESSAGEMAN:Broadcast("UpdateAssetDisplay") end
				elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
					if curPage < maxPage then curPage = curPage + 1 MESSAGEMAN:Broadcast("UpdateAssetDisplay") end
				end

				-- Left Click
				if event.DeviceInput.button == "DeviceButton_left mouse button" then
					-- Check Sidebar
					for i, _ in ipairs(assetTypes) do
						local tx = sidebarW/2 + 10
						local ty = SCREEN_CENTER_Y - 60 + (i-1)*50
						if IsMouseOverCentered(tx, ty, sidebarW - 20, 40) then
							curType = i
							loadAssetTable()
							return true
						end
					end
					
					-- Check Grid
					for r = 0, maxRows-1 do
						for c = 0, maxColumns-1 do
							local idx_in_page = r * maxColumns + c + 1
							local idx = ((curPage - 1) * maxRows * maxColumns) + idx_in_page
							if assetTable[idx] then
								local gx = mainAreaX + 40 + c * (itemW + spacing)
								local gy = mainAreaY + 40 + r * (itemH + spacing)
								if IsMouseOverCentered(gx, gy, itemW, itemH) then
									local now = GetTimeSinceStart()
									if idx == lastClickIdx and (now - lastClickTime) < 0.4 then
										confirmPick(idx)
										lastClickTime = 0 -- Reset to prevent triple click issues
									else
										selectedIndex = idx
										lastClickTime = now
										lastClickIdx = idx
										MESSAGEMAN:Broadcast("UpdateAssetDisplay")
									end
									return true
								end
							end
						end
					end
				end
			end
		end)
	end
}

return t
