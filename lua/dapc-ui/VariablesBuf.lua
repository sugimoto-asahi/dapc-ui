local FoldTree = require("dapc-ui.FoldTree")
local FoldTreeNode = require("dapc-ui.FoldTreeNode")

--- Variables buffer
local sep = ": "
local whitespace = " "
local update_sign = ""

--- Build the display table for a node
--- @param name string Name of variable
--- @param value string Value to display
--- @param var_type? string Type of variable
--- @param is_updated? boolean
--- @return dapc-ui.Line
local function make_line(name, value, var_type, is_updated)
	local type_text = var_type or ""
	local is_updated = is_updated or false
	local line = type_text .. whitespace .. name .. sep .. value

	-- Display format: <type><whitespace><name><sep><value>

	local current = 1
	--- @type dapc-ui.Line.Highlight
	local type_hl = {
		hl_group = "DapUIType",
		start_col = current,
		end_col = current + #type_text,
	}
	current = current + #type_text + #whitespace

	--- @type dapc-ui.Line.Highlight
	local name_hl = {
		hl_group = "DapUIName",
		start_col = current,
		end_col = current + #name,
	}
	current = current + #name

	--- @type dapc-ui.Line.Highlight
	local value_hl = {
		hl_group = "DapUIVariable",
		start_col = current,
		end_col = current + #value,
	}
	current = current + #value

	--- @type dapc-ui.Line
	local result = {
		text = line,
		highlights = { type_hl, name_hl, value_hl },
	}
	if is_updated then
		result.sign = update_sign
	end

	return result
end

--- @private
--- @class RowMapValue
--- @field table string Name of variable

--- @private
--- @class dapc-ui.VariablesBuf.NodeData
--- @field reference number Variable reference of node
--- @field value string Current value

--- @private
--- @alias dapc-ui.VariablesBuf.Context table<string, number>
--- Map of variable name to node id, in a local context.
--- This is possible because while the same variable name
--- may be shared in many places within the same stack frame
--- (e.g. the name of a variable at function scope scope may be the same as
--- the name of the member of a struct variable), within the same local context
--- variable names are unique. An example of a "local context" is the
--- aforementioned struct; structs cannot have members with the same name.

--- @class VariablesBuf
--- @field buf number Backing buffer
--- @field tree FoldTree Tree for current suspended state
--- @field node_map table<number, dapc-ui.VariablesBuf.NodeData> Map of node id
--- to information about the node
--- @field row_map table<number, number> Map of row number to node id
--- representing that variable
--- @field contexts table<number, dapc-ui.VariablesBuf.Context> node id -> (var name, node id)
--- @field request_node number Node id the data received
--- from the next DapcEventVariables is meant for
--- @field cursor table<number> Current cursor position in this buffer
--- @note see https://microsoft.github.io/debug-adapter-protocol/overview
--- "Lifetime of Objects References" for the reason why the tree should only exist
--- for the duration of the current suspended state
local VariablesBuf = {}

--- @private
--- Request the DAP for the children of a variable
--- (e.g. elements of a vector variable)
--- @param reference number Variable reference of the variable we want to query
function VariablesBuf:get_variable(reference)
	vim.api.nvim_exec_autocmds("User", {
		pattern = "DapcGetVariable",
		data = { reference = reference },
	})
end

function VariablesBuf:setup()
	self:reset()
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
		pattern = "DapEventStartFrame",
		callback = function(args)
			self:reset()
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DapEventEndFrame",
		callback = function(args)
			self:reset()
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventStartState",
		callback = function(args) end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DapcEventEndState",
		callback = function(args)
			self:reset()
		end,
	})

	-- Buffer local keymaps
	vim.keymap.set("n", "zo", function()
		local target_node_id = self.row_map[vim.api.nvim_win_get_cursor(0)[1]]
		local node_data = self.node_map[target_node_id]

		self.request_node = target_node_id
		-- Variables requests are only valid for complex variables ,
		-- and complex variables can be identified by their reference not being 0
		if node_data.reference ~= 0 then
			self:get_variable(node_data.reference)
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

--- Update a node with new data
--- Only to be used for the start of a new suspended state
--- @param data any New variables data
--- @param node_id number Node id to insert all this new data under
function VariablesBuf:update(data, node_id)
	-- save the current cursor position in the variables buffer
	local win = vim.fn.bufwinid(self.buf)
	local cursor = nil
	if win ~= -1 then -- panel is not open
		cursor = vim.api.nvim_win_get_cursor(win)
	end

	-- do nothing for empty data
	if not next(data) then
		self.request_node = 0
		return
	end
	for _, var in ipairs(data) do
		--- @type dapc-ui.Line
		local display
		local target_node
		if context[var.name] then
			-- this is not a new variable
			target_node = context[var.name]

			--- @type dapc-ui.VariablesBuf.NodeData
			local node_data = self.node_map[target_node]

			if node_data.value ~= var.value then
				display = make_line(var.name, var.value, var.var_type, true)
			else
				display = make_line(var.name, var.value, var.var_type, false)
			end
			self.tree:update_display(target_node, display)
		else
			-- this is a new variable
			target_node = self:get_next_id()
			display = make_line(var.name, var.value, var.var_type, true)

			-- update the context
			context[var.name] = target_node

			local node = FoldTreeNode:new(target_node, display)
			self.tree:insert(node_id, node)
		end

		--- @type dapc-ui.VariablesBuf.NodeData
		local value = {
			reference = var.reference,
			value = var.value,
		}
		self.node_map[target_node] = value

		-- This is a complex variable, so it needs its own context
		if var.reference ~= 0 and not self.contexts[target_node] then
			self.contexts[target_node] = {}
		end
	end
	-- Construct and render the variable tree
	local folds = self.tree:get()

	-- update row map
	for index, fold in ipairs(folds) do
		self.row_map[index] = fold.node_id
	end

	self.tree:render(self.buf, folds)
	if cursor then
		vim.api.nvim_win_set_cursor(win, cursor)
		vim.api.nvim_win_call(win, function()
			-- open the fold
			if vim.fn.foldlevel(cursor[1]) > 0 then
				vim.cmd("normal! zo")
			end
		end)
	end
	self.request_node = 0
end

--- @private
--- Reset / init state to prepare for a new suspended state
function VariablesBuf:reset()
	self.row_map = {}
	self.node_map = {}
	self.tree = FoldTree:new()
	self.next_id = 1
	self.request_node = 0 -- always start by inserting at the root node
	self.contexts = {}
	self.contexts[0] = {}
end

return VariablesBuf
