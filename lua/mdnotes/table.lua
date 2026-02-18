---@module 'mdnotes.table'
local M = {}

---@class MdnotesTableComplexData
---@field content string Cell content
---@field start_pos integer Cell start position
---@field end_pos integer Cell end position
---@field line integer Line in the table

---@alias MdnotesTableContents table<table<string>> Contents of a table
---@alias MdnotesTableColLoc table<table<integer>> Table column locations
---@alias MdnotesTableComplex table<table<MdnotesTableComplexData>> Complex table data which is just more information about the table

---Check if there is a table under the cursor
---@return boolean table_valid, integer|nil table_startl, integer|nil table_endl
function M.check_valid_table()
    local cur_line_num = vim.fn.line('.')
    local max_line_num = vim.fn.line('$')
    local min_line_num = 0
    local table_startl = 0
    local table_endl = 0
    local table_valid = true

    -- A table needs at least 3 lines to be valid
    if max_line_num < 3 then
        return false, nil, nil
    end

    for i = cur_line_num, min_line_num, -1 do
        local line = vim.fn.getline(i)
        local _, count = line:gsub("|", "")
        if count < 2 then
            if i == 1 then
                table_startl = 1
            else
                table_startl = i + 1
            end
            break
        end
    end

    if table_startl == 0 then
        return false, nil, nil
    end

    local delimeter_row = vim.fn.getline(table_startl + 1)

    -- If it find anything other than |, :, - in delemeter row table is not valid
    if delimeter_row:match("[^:%-|]+") then
        return false, nil, nil
    end

    for i = cur_line_num, max_line_num + 1 do
        local line = vim.fn.getline(i)
        local _, count = line:gsub("|", "")
        if count < 2 then
            if i == max_line_num then
                table_endl = max_line_num
            else
                table_endl = i - 1
            end
            break
        end
    end

    if table_endl == 0 then
        return false, nil, nil
    end

    return table_valid, table_startl, table_endl
end

---Write the table to the buffer
---@param contents MdnotesTableContents
---@param startl integer?
---@param endl integer?
function M.write_table_lines(contents, startl, endl)
    if startl == nil then startl = vim.fn.line('.') end
    if endl == nil then endl = vim.fn.line('.') end
    local table_formatted = {}

    -- Copy so that it's not passed by reference
    local table_contents = vim.deepcopy(contents, true)

    -- Append a blank entry to have a | at the end
    for _, v in ipairs(table_contents) do
        table.insert(v, "")
    end

    -- Concatinate with |
    for _, v in ipairs(table_contents) do
        table.insert(table_formatted, "|" .. table.concat(v, "|"))
    end

    if startl == endl  then
        vim.api.nvim_put(table_formatted, "l", false, false)
    else
        vim.api.nvim_buf_set_lines(0, startl - 1, endl, false, table_formatted)
    end
end

---Create a table with r rows and c columns
---@param rows integer Rows
---@param columns integer Columns
function M.create(rows, columns)
    if rows == nil or columns == nil then
        vim.notify("Mdn: Please specify both row and column dimensions", vim.log.levels.ERROR)
        return
    end

    vim.validate("rows", rows, "number")
    vim.validate("columns", columns, "number")

    local row_entry = {}
    local new_table = {}
    local header_row = {}

    for row = 1, rows do
        row_entry = {}
        for col = 1, columns do
            table.insert(row_entry, tostring(row) .. "r" .. tostring(col) .. "c")
        end
        table.insert(new_table, row_entry)
    end

    for _ = 1, columns do
        table.insert(header_row, "----")
    end
    table.insert(new_table, 2, header_row)

    M.write_table_lines(new_table)
end

---Parse the table in the specified line numbers
---@param table_startl integer
---@param table_endl integer
---@return MdnotesTableContents
function M.parse_table(table_startl, table_endl)
    local table_parsed = {}

    local table_lines = vim.api.nvim_buf_get_lines(0, table_startl - 1, table_endl, false)

    -- Trim whitespace
    for r, v in ipairs(table_lines) do
        table_lines[r] = vim.trim(v)
    end

    local table_temp = {}

    for _, v in ipairs(table_lines) do
        table_temp = {}
        for text in v:gmatch("[^|]+") do
            table.insert(table_temp, text)
        end
        table.insert(table_parsed, table_temp)
    end

    return table_parsed
end

---Get the table contents as lines using start and end lines
---@param opts {silent: boolean?}? opts.silent: Silence notifications
---@return MdnotesTableContents|nil, integer|nil, integer|nil
function M.get_table_lines(opts)
    opts = opts or {}
    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    local table_valid, startl, endl = M.check_valid_table()
    if table_valid == false or startl == nil or endl == nil then
        if silent == false then
            vim.notify("Mdn: No valid table detected", vim.log.levels.ERROR)
        end

        return nil, nil, nil
    end

    local table_lines = M.parse_table(startl, endl)
    if vim.tbl_isempty(table_lines) then
        if silent == false then
            vim.notify("Mdn: Error parsing table", vim.log.levels.ERROR)
        end

        return nil, nil, nil
    end

    return table_lines, startl, endl
end

---Get the table column locations
---@return MdnotesTableColLoc|nil
function M.get_column_locations()
    -- Fence post problem, all tables will have n+1 | characters with n being the text    
    local table_valid, startl, endl = M.check_valid_table()
    if table_valid == false or startl == nil or endl == nil then
        vim.notify("Mdn: No valid table detected", vim.log.levels.ERROR)
        return nil
    end

    local table_lines = vim.api.nvim_buf_get_lines(0, startl - 1, endl, false)
    local col_locations_table = {}
    local col_locations_line = {}

    for _, line in ipairs(table_lines) do
        col_locations_line = {}
        for i in line:gmatch("()|") do
            table.insert(col_locations_line, i)
        end
        table.insert(col_locations_table, col_locations_line)
    end

    return col_locations_table
end

---Get the table contents along with some more information (which is why it's called complex)
---@return MdnotesTableComplex|nil, integer|nil, integer|nil
function M.get_table_lines_complex()
    local table_lines, startl, endl = M.get_table_lines()

    if table_lines == nil then
        -- Errors would already be outputted
        return
    end

    local col_locations = M.get_column_locations() or {{0}}
    local table_complex = {}
    local table_complex_entry = {}

    for i, line in ipairs(table_lines) do
        table_complex_entry = {}
        for j, cell in ipairs(line) do
            table.insert(table_complex_entry, {
                content = cell,
                start_pos = col_locations[i][j],
                end_pos = col_locations[i][j + 1],
                line = i
            })
        end
        table.insert(table_complex, table_complex_entry)
    end

    return table_complex, startl, endl
end

---Get the current column based on cursor location
---@return integer|nil
function M.get_cur_column_num()
    local table_lines_complex, _, _ = M.get_table_lines_complex()

    if table_lines_complex == nil then
        -- Errors would already be outputted
        return
    end

    local cur_cursor_col_pos = vim.fn.getpos(".")[3]

    for _, line in ipairs(table_lines_complex) do
        for j, cell in ipairs(line) do
            -- Treats the left | as the start point of the column
            if cell.start_pos <= cur_cursor_col_pos and cell.end_pos > cur_cursor_col_pos then
                return j
            end
        end
    end

    return nil
end

---Insert a column to the table either left or right
---@param direction '"left"'|'"right"' Column insertion direction
local function insert_column(direction)
    local cur_col = M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    local table_lines, startl, endl = M.get_table_lines()

    if table_lines == nil or startl == nil or endl == nil then
        -- Errors would already be outputted
        return
    end

    if direction == "right" then
        cur_col = cur_col + 1
    elseif direction == "left" then
    end

    for i, v in ipairs(table_lines) do
        if i == 2 then
            table.insert(v, cur_col, "----")
        else
            table.insert(v, cur_col, "    ")
        end
    end

    M.write_table_lines(table_lines, startl, endl)
end

---Insert column to the left of the current column
function M.column_insert_left()
    insert_column("left")
end

---Insert column to the right of the current column
function M.column_insert_right()
    insert_column("right")
end

---Move a column either left or right
---@param direction '"left"'|'"right"' Column move direction
local function move_column(direction)
    local cur_col = M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    local new_col = 0
    if direction == "left" then
        new_col = cur_col - 1
    elseif direction == "right" then
        new_col = cur_col + 1
    end

    local table_lines, startl, endl = M.get_table_lines()

    if table_lines == nil or startl == nil or endl == nil then
        -- Errors would already be outputted
        return
    end

    if new_col < 1 or new_col > #table_lines[1] then
        vim.notify("Mdn: Column move exceeds table dimensions", vim.log.levels.ERROR)
        return
    end

    local temp_col_val = ""
    for _, v in ipairs(table_lines) do
        temp_col_val = v[cur_col]
        table.remove(v, cur_col)
        table.insert(v, new_col, temp_col_val)
    end

    M.write_table_lines(table_lines, startl, endl)
end

---Move current column to the left
function M.column_move_left()
    move_column("left")
end

---Move current column to the right
function M.column_move_right()
    move_column("right")
end

---Insert an empty row either above or below
---@param direction '"above"'|'"below"' Row insertion direction
local function insert_row(direction)
    local table_lines , startl, endl = M.get_table_lines()

    if table_lines == nil or startl == nil or endl == nil then
        -- Errors would already be outputted
        return
    end

    local cur_cursor_line = vim.fn.line('.')
    local cur_table_line_num = cur_cursor_line - startl

    -- In case the table is at the very top
    if cur_table_line_num == 0 then cur_table_line_num = 1 end

    local cur_table_line = table_lines[cur_table_line_num]
    local new_table_line = {}

    for _, v in ipairs(cur_table_line) do
        local text = v:gsub(".", " ")
        table.insert(new_table_line, text)
    end

    if direction == "above" then
        table.insert(table_lines, cur_table_line_num, new_table_line)
    elseif direction == "below" then
        table.insert(table_lines, cur_table_line_num + 1, new_table_line)
    end

    M.write_table_lines(table_lines, startl, endl)
end

---Insert a row above the current row
function M.row_insert_above()
    insert_row("above")
end

---Insert a row below the current row
function M.row_insert_below()
    insert_row("below")
end

---Add the appropriate amount of spaces for each column
---@param opts {silent: boolean?}? opts.silent: Silence notifications
function M.best_fit(opts)
    opts = opts or {}
    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    local table_lines, startl, endl = M.get_table_lines({ silent = silent })

    if table_lines == nil or startl == nil or endl == nil then
        -- Errors would already be outputted
        return
    end

    local max_char_count = {}
    local padding = ""
    if require('mdnotes').config.table_best_fit_padding > 0 then
        padding = (" "):rep(require('mdnotes').config.table_best_fit_padding)
    end

    -- Trim whitespace in each cell
    for r, v in ipairs(table_lines) do
        for c, vv in ipairs(v) do
            table_lines[r][c] = padding .. vim.trim(vv) .. padding
        end
    end

    local cols_count = #table_lines[1]

    -- Initialise the max char count
    for _ = 1, cols_count do
        table.insert(max_char_count, 0)
    end

    -- Get max char count for each column
    for c = 1, cols_count do
        for _, r in ipairs(table_lines) do
            if #r[c] > max_char_count[c]  then
                max_char_count[c] = #r[c]
            end
        end
    end

    -- Add spaces to fill void in smaller cells
    for r, v in ipairs(table_lines) do
        for c, vv in ipairs(v) do
            if #vv < max_char_count[c] then
                table_lines[r][c] = vv .. (" "):rep(max_char_count[c] - #vv)
            end
        end
    end

    -- Add the dashes for the delimeter row
    local new_delimiter_row = ""
    for c, v in ipairs(table_lines[2]) do
        local colon1, _, colon2 = v:match("([:]?)([-]+)([:]?)")
        new_delimiter_row = ("-"):rep(max_char_count[c])
        if colon1 == ":" then
            new_delimiter_row =  ":" .. new_delimiter_row:sub(2)
        end
        if colon2 == ":" then
            new_delimiter_row = new_delimiter_row:sub(1, -2) .. ":"
        end
        table_lines[2][c] = new_delimiter_row
    end

    M.write_table_lines(table_lines, startl, endl)
end

---Delete current column. Can also use visual block mode
function M.column_delete()
    local cur_col = M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    local table_lines, startl, endl = M.get_table_lines()

    if table_lines == nil then
        -- Errors would already be outputted
        return
    end

    for _, v in ipairs(table_lines) do
        table.remove(v, cur_col)
    end

    M.write_table_lines(table_lines, startl, endl)
end

---Toggle alignment of the current column
function M.column_alignment_toggle()
    local cur_col = M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    local table_lines, startl, endl = M.get_table_lines()

    if table_lines == nil then
        -- Errors would already be outputted
        return
    end

    local delimiter_row = table_lines[2][cur_col]
    local new_delimiter_row = ""

    -- if delimeter row is --- create :--
    if delimiter_row:match("^[-]+$") then
        new_delimiter_row = delimiter_row:gsub("-", ":", 1)
        -- if delimeter row is :-- create --:
    elseif delimiter_row:match("^:[-]+[^:]$") then
        new_delimiter_row = delimiter_row:gsub(":", "-")
        new_delimiter_row = new_delimiter_row:sub(1, -2) .. ":"
        -- if delimeter row is --: create :-:
    elseif delimiter_row:match("^[^:][-]+:$") then
        new_delimiter_row = delimiter_row:gsub("-", ":", 1)
        -- if delimeter row is :-: create ---
    elseif delimiter_row:match("^:[-]+:$") then
        new_delimiter_row = delimiter_row:gsub(":", "-")
    else
        vim.notify("Mdn: Check that the table delimeter row is in the correct format", vim.log.levels.ERROR)
        return
    end

    table_lines[2][cur_col] = new_delimiter_row

    M.write_table_lines(table_lines, startl, endl)
end

---Duplicate the current column. Inserts it to the right
function M.column_duplicate()
    local cur_col = M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    local table_lines, startl, endl = M.get_table_lines()

    if table_lines == nil then
        -- Errors would already be outputted
        return
    end

    for _, r in ipairs(table_lines) do
        for j, c in ipairs(r) do
            if j == cur_col then
                table.insert(r, cur_col, c)
                break
            end
        end
    end

    M.write_table_lines(table_lines, startl, endl)
end

---Get table as columns
---@param opts {silent: boolean?}? opts.silent: Silence notifications
---@return MdnotesTableContents|nil contents 
function M.get_table_columns(opts)
    opts = opts or {}
    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    local table_lines = M.get_table_lines({ silent = silent })

    if table_lines == nil then
        -- Errors would already be outputted
        return
    end

    local table_columns = {}
    local column = {}
    for c = 1, #table_lines[1] do
        column = {}
        for _, r in ipairs(table_lines) do
            table.insert(column, r[c])
        end
        table.insert(table_columns, column)
    end

    return table_columns
end

---Sort table based on current column
---@param comp fun(a, b): boolean
---@param write boolean? Write to buffer
function M.column_sort(comp, write)
    if write == nil then write = true end
    local cur_col = M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    local table_columns = M.get_table_columns()

    if table_columns == nil then
        -- Errors would already be outputted
        return
    end

    local cur_column = vim.deepcopy(table_columns[cur_col], true)

    -- Remove heading and separator
    table.remove(cur_column, 1)
    table.remove(cur_column, 1)

    local sorted_column = vim.deepcopy(cur_column, true)
    table.sort(sorted_column, comp)

    local index_tbl = {}
    for old_index, v in ipairs(cur_column) do
        for new_index, vv in ipairs(sorted_column) do
            if v == vv then
                -- Add two to account for the heading and separator
                table.insert(index_tbl, {old_index = old_index + 2, new_index = new_index + 2})
            end
        end
    end

    local table_lines, startl, endl = M.get_table_lines()

    if table_lines == nil then
        -- Errors would already be outputted
        return
    end

    local new_table_lines = {}
    table.insert(new_table_lines, table_lines[1])
    table.insert(new_table_lines, table_lines[2])
    for _, v in ipairs(index_tbl) do
        new_table_lines[v.new_index] = table_lines[v.old_index]
    end

    if write == true then
        M.write_table_lines(new_table_lines, startl, endl)
    end

    return new_table_lines, startl, endl
end

function M.column_sort_ascending()
    local table_lines, startl, endl = M.column_sort(function(a, b) return a < b end, false)
    if table_lines == nil then
        -- Errors would already be outputted
        return
    end

    M.write_table_lines(table_lines, startl, endl)
end

function M.column_sort_descending()
    local table_lines, startl, endl = M.column_sort(function(a, b) return a > b end, false)
    if table_lines == nil then
        -- Errors would already be outputted
        return
    end

    M.write_table_lines(table_lines, startl, endl)
end

---Get table as columns
---@param contents MdnotesTableContents
---@return MdnotesTableContents|nil contents 
function M.parse_columns_to_lines(contents)
    local table_lines = {}
    local row = {}
    for c = 1, #contents[1] do
        row = {}
        for _, r in ipairs(contents) do
            table.insert(row, r[c])
        end
        table.insert(table_lines, row)
    end

    return table_lines
end

return M
