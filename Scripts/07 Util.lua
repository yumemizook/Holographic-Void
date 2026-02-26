--- Holographic Void: Utility Functions
-- Ported and adapted from Til Death for consistent engine-level interactions.

-- ms fallback for notifications
ms = ms or {}
function ms.ok(text)
	SCREENMAN:SystemMessage(text)
end

--- Open a ScreenTextEntry popup with OK and Cancel callbacks.
-- @param question   The question/prompt to display
-- @param maxLength  Maximum input character length
-- @param isPassword Boolean to mask the input
-- @param funcOK     Function(answer) to call on OK
-- @param funcCancel Function() to call on Cancel or Esc
function easyInputStringOKCancel(question, maxLength, isPassword, funcOK, funcCancel)
	SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
	local settings = {
		Question = question,
		MaxInputLength = maxLength,
		Password = isPassword,
		OnOK = function(answer)
			funcOK(answer)
		end,
		OnCancel = function()
			if funcCancel then funcCancel() end
		end,
	}
	SCREENMAN:GetTopScreen():Load(settings)
end

--- Wrapper for simple text entry with only an OK callback.
-- @param question   The question/prompt to display
-- @param maxLength  Maximum input character length
-- @param isPassword Boolean to mask the input
-- @param func       Function(answer) to call on OK
function easyInputStringWithFunction(question, maxLength, isPassword, func)
	easyInputStringOKCancel(
		question,
		maxLength,
		isPassword,
		function(answer)
			func(answer)
		end,
		nil
	)
end

Trace("Holographic Void: 07 Util.lua loaded.")
