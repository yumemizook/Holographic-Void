--- Holographic Void: Global Initialization
-- @module 01_Init
-- Loaded after _Fallback's 00 init.lua. Sets up the theme namespace
-- and common helper utilities.

-- Theme namespace
HV = {}

-- Screen dimensions (cached for convenience)
HV.ScreenWidth = SCREEN_WIDTH
HV.ScreenHeight = SCREEN_HEIGHT
HV.ScreenCenterX = SCREEN_CENTER_X
HV.ScreenCenterY = SCREEN_CENTER_Y

-- Design grid: 16-column base for layout alignment
HV.GridColumns = 16
HV.GridColumnWidth = HV.ScreenWidth / HV.GridColumns
HV.GridRows = 9
HV.GridRowHeight = HV.ScreenHeight / HV.GridRows

--- Get the X position of a grid column (0-indexed, left edge of column).
-- @param col Column index (0 to HV.GridColumns-1)
-- @return number X position
function HV.ColX(col)
	return col * HV.GridColumnWidth
end

--- Get the Y position of a grid row (0-indexed, top edge of row).
-- @param row Row index (0 to HV.GridRows-1)
-- @return number Y position
function HV.RowY(row)
	return row * HV.GridRowHeight
end

--- Clamp a value between a minimum and maximum.
-- @param val Number to clamp
-- @param low Minimum value
-- @param high Maximum value
-- @return number Clamped value
function HV.Clamp(val, low, high)
	return math.max(low, math.min(high, val))
end

--- Linear interpolation between two values.
-- @param a Start value
-- @param b End value
-- @param t Interpolation factor (0-1)
-- @return number Interpolated value
function HV.Lerp(a, b, t)
	return a + (b - a) * HV.Clamp(t, 0, 1)
end

--- Create a standard Quad with the theme's style defaults.
-- Returns a Quad actor definition table.
-- @param params Table with optional keys: Width, Height, Color, Alpha, X, Y
-- @return actor definition table
function HV.Quad(params)
	params = params or {}
	local w = params.Width or 100
	local h = params.Height or 100
	local c = params.Color or HVColor.BG2
	local a = params.Alpha or 1
	local x = params.X or 0
	local y = params.Y or 0
	return Def.Quad {
		InitCommand = function(self)
			self:zoomto(w, h):xy(x, y):diffuse(c):diffusealpha(a)
		end
	}
end

--- Create a standard text actor with the theme's default font.
-- @param params Table with optional keys: Text, Font, Zoom, Color, X, Y, Halign, Valign
-- @return actor definition table
function HV.Text(params)
	params = params or {}
	local text = params.Text or ""
	local font = params.Font or "Common Normal"
	local zoom = params.Zoom or 1
	local c = params.Color or HVColor.Text
	local x = params.X or 0
	local y = params.Y or 0
	local ha = params.Halign or 0.5
	local va = params.Valign or 0.5
	return LoadFont(font) .. {
		Text = text,
		InitCommand = function(self)
			self:xy(x, y):zoom(zoom):halign(ha):valign(va):diffuse(c)
		end
	}
end

Trace("Holographic Void: 01 Init.lua loaded.")

-- ============================================================
-- RATE HELPERS (used across screens)
-- ============================================================
function getCurRateValue()
	local so = GAMESTATE:GetSongOptionsObject("ModsLevel_Current")
	if so and so:MusicRate() then return so:MusicRate() end
	so = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred")
	if so and so:MusicRate() then return so:MusicRate() end
	return 1
end

function getCurRateString()
	local rate = getCurRateValue()
	if not rate then return "1.0x" end
	return string.format("%.2fx", rate)
end
