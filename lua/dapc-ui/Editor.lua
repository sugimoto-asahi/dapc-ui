--- UI manager for the editor part (read: anything outside the dapc-ui panel)

--- @class Editor
--- @field breakpoints table<string, table<number, boolean>>
local Editor = {
	breakpoints = {},
}

--- Setup
function Editor:setup()
	-- Subscribe to apis
	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventExecutionPoint",
		callback = function(args)
			local data = args.data
			self:set_current_point(data.path, data.row)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventSetBreakpoint",
		callback = function(args)
			local data = args.data
			self:set_breakpoint(data.path, data.row)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventUpdateBreakpoint",
		callback = function(args)
			local data = args.data
			self:update_breakpoint(data.path, data.old, data.new)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventUnsetBreakpoint",
		callback = function(args)
			local data = args.data
			self:unset_breakpoint(data.path, data.row)
		end,
	})
end

local current_line_id -- extmark id of current line
--- Reflect the current execution point.
--- This will also position the cursor at the execution point.
--- @param path string Path to file the execution is currently at
--- @param row number Row number of the current execution point
function Editor:set_current_point(path, row)
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

	-- Now that the buffer is displaying, trigger the filetype detection
	-- so that syntax highlighting can be applied to it.
	-- This seems hacky though, but when a new buffer is created
	-- it doesn't seem to have a filetype set.
	vim.cmd("filetype detect")

	-- position cursor at execution point
	vim.api.nvim_win_set_cursor(winid, { row, 0 }) -- hardcoded to first column

	-- highlight the execution point
	local execution_ns = vim.api.nvim_create_namespace("execution")
	if current_line_id ~= nil then
		vim.api.nvim_buf_del_extmark(bufnr, execution_ns, current_line_id)
	end
	current_line_id = vim.api.nvim_buf_set_extmark(bufnr, execution_ns, row - 1, 0, {
		id = row,
		line_hl_group = "DapcCurrentLine",
	})
end

--- Display a breakpoint
--- @param path string Absolute path to file where breakpoint is
--- @param row number Row number of breakpoint
function Editor:set_breakpoint(path, row)
	-- vim.print("Request to display breakpoint at: " .. path .. "#" .. row)
	local breakpoint_ns = vim.api.nvim_create_namespace("breakpoint_ns")

	-- make sure to display signs
	vim.opt.signcolumn = "auto"
	-- place the breakpoint sign
	-- set_extmark is 0-indexed for the line number
	local buf = vim.fn.bufnr(path)
	vim.api.nvim_buf_set_extmark(buf, breakpoint_ns, row - 1, 0, {
		sign_text = "●",
		sign_hl_group = "DapcBreakpointSign",
		-- we have it so the extmark id matches the (1-indexed) row number
		-- so we can refer to it easily later on
		id = row,
	})

	if not self.breakpoints[path] then
		self.breakpoints[path] = {}
	end
	self.breakpoints[path][row] = true
end

--- Update a breakpoint
--- @param path string Absolute path to file where breakpoint is
--- @param old number Old row number of breakpoint
--- @param new number New row number of breakpoint
function Editor:update_breakpoint(path, old, new)
	self:unset_breakpoint(path, old)
	self:set_breakpoint(path, new)
end

--- Unset a breakpoint
--- @param path string Absolute path to file where breakpoint is
--- @param row number Row number of breakpoint to unset
function Editor:unset_breakpoint(path, row)
	self.breakpoints[path][row] = false

	local breakpoint_ns = vim.api.nvim_create_namespace("breakpoint_ns")
	local buf = vim.fn.bufnr(path)
	vim.api.nvim_buf_del_extmark(buf, breakpoint_ns, row)
end

return Editor
