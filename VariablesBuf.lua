local FoldTree = require("dapc-ui.FoldTree")
local FoldTreeNode = require("dapc-ui.FoldTreeNode")

--- Variables buffer
local sep = ": "

--- Construct the text that displays in the buffer for a given variable
--- @param name string Name of variable
--- @param value string Value to display
--- @param var_type? string Type of variable
local build_line = function(name, value, var_type)
	local type_text = var_type or ""
	local line = type_text .. " " .. name .. sep .. value
	return line
end

--- @private
--- @class RowMapValue
--- @field table string Name of variable

--- @class VariablesBuf
--- @field buf number Backing buffer
--- @field tree FoldTree Tree for current suspended state
--- @field node_map table<number, number> Map of node id to variable reference
--- @field row_map table<number, number> Map of row number to node id
--- representing that variable
--- @field request_node number Node id the data received
--- from the next DapcEventVariables is meant for
--- @field cursor table<number> Current cursor position in this buffer
--- @note see https://microsoft.github.io/debug-adapter-protocol/overview
--- "Lifetime of Objects References" for the reason why the tree should only exist
--- for the duration of the current suspended state
local VariablesBuf = {
	map = {},

	-- these variables need to be reset each time a new suspended state is reached
	row_map = {},
	node_map = {},
	tree = FoldTree:new(),
	next_id = 1,
	request_node = 0, -- always start by inserting at the root node
	--
}

--- @private
--- Request the DAP for the children of a variable
--- (e.g. elements of a vector variable)
--- @param reference number Variable reference of the variable we want to query
function VariablesBuf:get_variable(reference)
	vim.api.nvim_exec_autocmds("User", {
		pattern = "DapcGetVariable",
		data = { reference = reference },
	})

	return self.node_map[reference]
end

function VariablesBuf:setup()
	-- Persistent buffer for variables
	VariablesBuf.buf = vim.api.nvim_create_buf(false, true)

	-- Subscribe to apis
	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventVariables",
		callback = function(args)
			self:update(args.data, self.request_node)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventStartState",
		callback = function(args)
			self:reset()
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventEndState",
		callback = function(args) end,
	})

	-- Buffer local keymaps
	vim.keymap.set("n", "zo", function()
		local target_node_id = self.row_map[vim.api.nvim_win_get_cursor(0)[1]]

		-- only send the request if the target node is actually one that has children
		if self.node_map[target_node_id] then
			local reference = self.node_map[target_node_id]
			self.request_node = target_node_id
			self:get_variable(reference)
		end
	end, { buf = VariablesBuf.buf })

	return VariablesBuf.buf
end

--- @private
--- Get the row number of the next empty row
--- @note Returned values must be used
--- @return number row Next available row
function VariablesBuf:get_next_row()
	local row = self.next_row
	self.next_row = self.next_row + 1

	return row
end

--- @private
--- Get the next available node id
--- @note Returned values must be subsequently used
--- @return number index Next available id
function VariablesBuf:get_next_id()
	local id = self.next_id
	self.next_id = self.next_id + 1

	return id
end

--- Update with new data
--- Only to be used for the start of a new suspended state
--- @param data any New variables data
--- @param node_id number Node id to insert all this new data under
function VariablesBuf:update(data, node_id)
	-- save the current cursor position in the variables buffer
	local win = vim.fn.bufwinid(self.buf)
	local cursor = vim.api.nvim_win_get_cursor(win)

	-- do nothing for empty data
	if not next(data) then
		return
	end
	for index, var in ipairs(data) do
		local line
		if var.var_type then
			line = build_line(var.name, var.value, var.var_type)
		else
			line = build_line(var.name, var.value)
		end

		local id = self:get_next_id()
		local node = FoldTreeNode:new(id, line)
		-- A non-zero reference implies that this variable is not a primitive,
		-- and is instead some structure with child variables. For example,
		-- an array variable would have child variables, namely, the array's elements.
		-- Therefore, we want to take note of the node that represents this variable,
		-- since we will want to append child nodes to it later on.
		if var.reference ~= 0 then
			self.node_map[id] = var.reference
		end
		self.tree:insert(node_id, node)
	end
	-- Construct and render the variable tree
	local folds = self.tree:get()

	-- update row map
	for index, fold in ipairs(folds) do
		self.row_map[index] = fold.node_id
	end

	self.tree:render(self.buf, folds)
	vim.api.nvim_win_set_cursor(win, cursor)
	vim.api.nvim_win_call(win, function()
		-- open the fold
		if vim.fn.foldlevel(cursor[1]) > 0 then
			vim.cmd("normal! zo")
		end
	end)
end

--- @private
--- Reset state to prepare for a new suspended state
function VariablesBuf:reset()
	self.row_map = {}
	self.node_map = {}
	self.tree = FoldTree:new()
	self.next_id = 1
	self.request_node = 0
end

return VariablesBuf
