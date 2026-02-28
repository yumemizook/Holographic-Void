--- Holographic Void: Isolated Input Debugger
-- This actor is designed to be loaded by the main overlay but stay functional
-- even if other parts of the overlay script crash.

local inputLogs = {}
local brightText = color("1,1,1,1")
local neonCyan = color("0,1,1,1")

-- Global helper for other scripts to log to this specific debugger
HV_DEBUG_LOG = function(text)
	local t = (GetTimeSinceStart and GetTimeSinceStart()) or os.clock()
	table.insert(inputLogs, 1, string.format("[%s] %s", string.format("%.3f", t), text))
	if #inputLogs > 15 then table.remove(inputLogs) end
	MESSAGEMAN:Broadcast("UpdateInputDebugText")
end

return Def.ActorFrame {
	Name = "InputDebuggerRoot",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X - 175, SCREEN_CENTER_Y - 120)
			:draworder(9999)
			:visible(false)
	end,
	ToggleInputDebuggerMessageCommand = function(self)
		self:visible(not self:GetVisible())
	end,

	-- Semi-transparent black background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(350, 240):diffuse(color("0.02,0.02,0.02,0.9"))
		end
	},
	-- Neon Borders
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(350, 2):diffuse(neonCyan)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(2, 240):diffuse(neonCyan)
		end
	},

	LoadFont("Common Normal") .. {
		Name = "Title",
		InitCommand = function(self)
			self:halign(0):valign(0):xy(10, 10):zoom(0.4):diffuse(neonCyan):settext("HV INPUT DEBUGGER (Active)")
		end
	},
	
	LoadFont("Common Normal") .. {
		Name = "LogText",
		InitCommand = function(self)
			self:halign(0):valign(0):xy(10, 30):zoom(0.32):diffuse(brightText):settext("Waiting for system events...")
		end,
		UpdateInputDebugTextMessageCommand = function(self)
			self:settext(table.concat(inputLogs, "\n"))
		end
	}
}
