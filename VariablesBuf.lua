local FoldTree = require("dapc-ui.FoldTree")
local FoldTreeNode = require("dapc-ui.FoldTreeNode")

--- Variables buffer
local sep = ": "
local whitespace = " "

--- Build the display table for a node
--- @param name string Name of variable
--- @param value string Value to display
--- @param var_type? string Type of variable
--- @return dapc-ui.Line
local function make_line(name, value, var_type)
	local type_text = var_type or ""
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
	return result
end

--- @private
--- @class RowMapValue
--- @field table string Name of variable

--- @private
--- @class dapc-ui.VariablesBuf.NodeData
--- @field reference number Variable reference of node
--- @field is_processed boolean True if the variable reference of this node
--- has already been used in a Variables request

--- @class VariablesBuf
--- @field buf number Backing buffer
--- @field tree FoldTree Tree for current suspended state
--- @field node_map table<number, dapc-ui.VariablesBuf.NodeData> Map of node id
--- to information about the node
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
			if self.request_node ~= 0 then
				self.node_map[self.request_node].is_processed = true
			end
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
		local node_data = self.node_map[target_node_id]

		-- Only send the request if the target node is actually one that has children,
		-- and if we haven't yet processed this node before
		if node_data and not node_data.is_processed then
			self.request_node = target_node_id
			self:get_variable(node_data.reference)
		else
			-- the node has already been processed before, so there is a
			-- fold at that local, and we can just open that fold
			vim.cmd("normal! zo")
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
		return
	end
	for _, var in ipairs(data) do
		local id = self:get_next_id()
		local display = make_line(var.name, var.value, var.var_type)
		local node = FoldTreeNode:new(id, display)
		-- A non-zero reference implies that this variable is not a primitive,
		-- and is instead some structure with child variables. For example,
		-- an array variable would have child variables, namely, the array's elements.
		-- Therefore, we want to take note of the node that represents this variable,
		-- since we will want to append child nodes to it later on.
		if var.reference ~= 0 then
			--- @type dapc-ui.VariablesBuf.NodeData
			local value = {
				reference = var.reference,
				is_processed = false,
			}
			self.node_map[id] = value
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
	if cursor then
		vim.api.nvim_win_set_cursor(win, cursor)
		vim.api.nvim_win_call(win, function()
			-- open the fold
			if vim.fn.foldlevel(cursor[1]) > 0 then
				vim.cmd("normal! zo")
			end
		end)
	end
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
