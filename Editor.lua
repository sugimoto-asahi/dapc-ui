--- UI manager for the editor part (read: anything outside the dapc-ui panel)
--- @class Editor
local Editor = {}

--- Setup
function Editor:setup()
	-- Subscribe to apis
	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventExecutionPoint",
		callback = function(args)
			local data = args.data
			self:set_current_point(data.path, data.row, data.col)
		end,
	})
end

local current_line_id -- extmark id of current line
--- Reflect the current execution point.
--- This will also position the cursor at the execution point.
--- @param path string Path to file the execution is currently at
--- @param row number Row number of the current execution point
--- @param col number Column number of the current execution point
function Editor:set_current_point(path, row, col)
	-- Create a new buffer backing the currently executing file if it doesn't yet exist
	local bufnr = vim.fn.bufnr(path, true)

	-- First, we need to bring the executing buffer into view. This means setting one
	-- of the windows to display the buffer.
	-- However, we cannot just pick any window, because the Panel is also a window,
	-- and we don't want to overwrite that.
	-- The strategy is as follows:
	--     1. If the buffer is already in one of the windows, just switch to that window
	--     2. Otherwise, display the buffer in the window the user the currently in,
	--     EXCEPT when the user is in the Panel window, in which case we choose the top left window.
	local winid = vim.fn.bufwinid(bufnr)
	if winid == -1 then
		winid = vim.api.nvim_get_current_win()
		if vim.w[winid].tag == "dapc-ui" then
			winid = vim.fn.win_getid(1) -- winnr of 1 represents the top-left window
		end
	end
	vim.api.nvim_set_current_win(winid)
	vim.api.nvim_win_set_buf(winid, bufnr)

	-- position cursor at execution point
	vim.api.nvim_win_set_cursor(winid, { row, col }) -- hardcoded to first column

	-- highlight the execution point
	local execution_ns = vim.api.nvim_create_namespace("execution")
	if current_line_id ~= nil then
		vim.api.nvim_buf_del_extmark(bufnr, execution_ns, current_line_id)
	end
	current_line_id = vim.api.nvim_buf_set_extmark(bufnr, execution_ns, row - 1, col - 1, {
		id = row,
		line_hl_group = "DapcCurrentLine",
	})
end

return Editor
