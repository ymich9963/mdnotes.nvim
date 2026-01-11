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

---Write the table to the buffer
---@param contents MdnotesTableContents
---@param start_line integer?
---@param end_line integer?
local function write_table(contents, start_line, end_line)
    local table_formatted = {}

    -- Append a blank entry to have a | at the end
    for _, v in ipairs(contents) do
        table.insert(v, "")
    end

    -- Concatinate with |
    for _, v in ipairs(contents) do
        table.insert(table_formatted, "|" .. table.concat(v, "|"))
    end

    if not start_line and not end_line  then
        vim.api.nvim_put(table_formatted, "V", false, false)
    else
        vim.api.nvim_buf_set_lines(0, start_line or 0, end_line or 0, false, table_formatted)
    end
end

---Check if there is a table under the cursor
local function check_valid_table()
    local cur_line_num = vim.fn.line('.')
    local max_line_num = vim.fn.line('$')
    local min_line_num = 0
    local table_start_line_num = 0
    local table_end_line_num = 0
    local table_valid = true

    for i = cur_line_num, min_line_num, -1 do
        local line = vim.fn.getline(i)
        local _, count = line:gsub("|", "")
        if count < 2 then
            table_start_line_num = i
            break
        end
    end

    local delimeter_row = vim.fn.getline(table_start_line_num + 2)

    -- If it find anything other than |, :, - in delemeter row
    -- table is not valid
    if delimeter_row:match("[^:%-|]+") then
        table_valid = false
        return table_valid
    end


    for i = cur_line_num, max_line_num do
        local line = vim.fn.getline(i)
        local _, count = line:gsub("|", "")
        if count < 2 then
            table_end_line_num = i - 1
            break
        end
    end

    return table_valid, table_start_line_num, table_end_line_num
end

---Parse the table in the specified line numbers
---@param table_start_line_num integer
---@param table_end_line_num integer
---@return MdnotesTableContents
local function parse_table(table_start_line_num, table_end_line_num)
    local table_parsed = {}

    local table_lines = vim.api.nvim_buf_get_lines(0, table_start_line_num, table_end_line_num, false)

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

---Get the table contents and start and end lines
---@param silent boolean? Output errors
---@return MdnotesTableContents|nil
---@return integer|nil
---@return integer|nil
local function get_table(silent)
    if not silent then silent = false end

    local table_valid, startl, endl = check_valid_table()
    if not table_valid or not startl or not endl then
        if silent == false then
            vim.notify(("Mdn: No valid table detected."), vim.log.levels.ERROR)
        end

        return nil, nil, nil
    end

    local table_lines = parse_table(startl, endl)
    if vim.tbl_isempty(table_lines) then
        if silent == false then
            vim.notify(("Mdn: Error parsing table."), vim.log.levels.ERROR)
        end

        return nil, nil, nil
    end

    return table_lines, startl, endl
end

---Get the table column locations
---@return MdnotesTableColLoc|nil
local function get_column_locations()
    -- Fence post problem, all tables will have n+1 | characters with n being the text    
    local table_valid, startl, endl = check_valid_table()
    if not table_valid then
        vim.notify(("Mdn: No valid table detected."), vim.log.levels.ERROR)
        return nil
    end

    local table_lines = vim.api.nvim_buf_get_lines(0, startl or 0, endl or 0, false)
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
---@return MdnotesTableComplex|nil
---@return integer|nil
---@return integer|nil
local function get_table_complex()
    local table_lines, startl, endl = get_table()

    if not table_lines then
        -- Errors would already be outputted
        return
    end

    local col_locations = get_column_locations() or {0}
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
local function get_cur_column()
    local table_lines_complex, _, _ = get_table_complex()

    if not table_lines_complex then
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
    local cur_col = get_cur_column()

    if not cur_col then
        return
    end

    local table_lines, startl, endl = get_table()

    if not table_lines or not startl or not endl then
        -- Errors would already be outputted
        return
    end

    if direction == "right" then
        cur_col = cur_col + 1
    end

    for i, v in ipairs(table_lines) do
        if i == 2 then
            table.insert(v, cur_col, "----")
        else
            table.insert(v, cur_col, "    ")
        end
    end

    write_table(table_lines, startl, endl)
end

---Move a column either left or right
---@param direction '"left"'|'"right"' Column move direction
local function move_column(direction)
    local cur_col = get_cur_column()

    if not cur_col then
        return
    end

    local new_col = 0
    if direction == "left" then
        new_col = cur_col - 1
    elseif direction == "right" then
        new_col = cur_col + 1
    end


    local table_lines, startl, endl = get_table()

    if not table_lines or not startl or not endl then
        -- Errors would already be outputted
        return
    end

    if new_col < 1 or new_col > #table_lines[1] then
        vim.notify(("Mdn: Column move exceeds table dimensions."), vim.log.levels.ERROR)
        return
    end

    local temp_col_val = ""
    for _, v in ipairs(table_lines) do
        temp_col_val = v[cur_col]
        table.remove(v, cur_col)
        table.insert(v, new_col, temp_col_val)
    end

    write_table(table_lines, startl, endl)
end

---Insert a row either above or below
---@param direction '"above"'|'"below"' Row insertion direction
local function insert_row(direction)
    local table_lines , startl, endl = get_table()

    if not table_lines or not startl or not endl then
        -- Errors would already be outputted
        return
    end

    local cur_cursor_line = vim.fn.line('.')
    local cur_table_line_num = cur_cursor_line - startl
    local cur_table_line = table_lines[cur_table_line_num]
    local new_table_line = {}

    for _, v in ipairs(cur_table_line) do
        local text, _ = v:gsub(".", " ")
        table.insert(new_table_line, text)
    end

    vim.print(new_table_line)

    if direction == "above" then
        table.insert(table_lines, cur_table_line_num, new_table_line)
    elseif direction == "below" then
        table.insert(table_lines, cur_table_line_num + 1, new_table_line)
    end

    write_table(table_lines, startl, endl)
end

---Create a table with r rows and c columns
---@param r integer Rows
---@param c integer Columns
function M.create(r, c)
    if not r and not c then
        vim.notify(("Mdn: Please specify both row and column dimensions."), vim.log.levels.ERROR)
        return
    end

    local rows = r
    local columns = c
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

    write_table(new_table)
end

function M.best_fit(silent)

    local table_lines, startl, endl = get_table(silent)

    if not table_lines then
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

    write_table(table_lines, startl, endl)
end

---Insert column to the left of the current column
function M.column_insert_left()
    insert_column("left")
end

---Insert column to the right of the current column
function M.column_insert_right()
    insert_column("right")
end

---Delete current column. Can also use visual block mode
function M.column_delete()
    local cur_col = get_cur_column()

    if not cur_col then
        return
    end

    local table_lines, startl, endl = get_table()

    if not table_lines then
        -- Errors would already be outputted
        return
    end

    for _, v in ipairs(table_lines) do
        table.remove(v, cur_col)
    end

    write_table(table_lines, startl, endl)
end

---Move current column to the left
function M.column_move_left()
    move_column("left")
end

---Move current column to the right
function M.column_move_right()
    move_column("right")
end

---Insert a row above the current row
function M.row_insert_above()
    insert_row("above")
end

---Insert a row below the current row
function M.row_insert_below()
    insert_row("below")
end

---Toggle alignment of the current column
function M.column_alignment_toggle()
    local cur_col = get_cur_column()

    if not cur_col then
        return
    end

    local table_lines, startl, endl = get_table()

    if not table_lines then
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
        vim.notify(("Mdn: Check that the table delimeter row is in the correct format."), vim.log.levels.ERROR)
        return
    end

    table_lines[2][cur_col] = new_delimiter_row

    write_table(table_lines, startl, endl)
end

---Duplicate the current column. Inserts it to the right
function M.column_duplicate()
    local cur_col = get_cur_column()

    if not cur_col then
        return
    end

    local table_lines, startl, endl = get_table()

    if not table_lines then
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

    write_table(table_lines, startl, endl)
end

return M
