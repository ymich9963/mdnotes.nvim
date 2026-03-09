---@module 'mdnotes.table'

local M = {}

---@alias MdnTableCell string

---@class MdnTableCellComplex
---@field content MdnTableCell Cell content
---@field start_col integer Cell start position
---@field end_col integer Cell end position
---@field lnum integer Line in the table

---@alias MdnTableContents table<table<MdnTableCell>> Contents of a table
---@alias MdnTableContentsComplex table<table<MdnTableCellComplex>> Complex table data which is just more information about each cell

---@class MdnTable: MdnMultiLineLocation
---@field contents MdnTableContents|MdnTableContentsComplex

---@alias MdnTableColLoc table<table<integer>> Table column locations

---Check if there is a table in the specified search range or under the cursor
---@param opts {search: MdnSearchOpts?}?
---@return MdnSearchResult
function M.check_table_valid(opts)
    opts = opts or {}

    local search_opts = opts.search or {}
    vim.validate("search_opts", search_opts, "table")

    local buffer = search_opts.buffer or vim.api.nvim_get_current_buf()
    local origin_lnum = search_opts.origin_lnum or vim.fn.line('.')
    local lower_limit_lnum = search_opts.upper_limit_lnum or 1
    local upper_limit_lnum = search_opts.lower_limit_lnum or vim.fn.line('$')

    local table_startl = 0
    local table_endl = 0

    -- A table needs at least 3 lines to be valid
    if upper_limit_lnum < 3 then
        return { valid = false }
    end

    for i = origin_lnum, lower_limit_lnum, -1 do
        local cur_line = vim.api.nvim_buf_get_lines(buffer, i - 1, i, false)[1]
        local count = select(2, cur_line:gsub("|", ""))
        if count < 2 then
            break
        end
        table_startl = i
    end

    if table_startl == 0 then
        return { valid = false }
    end

    local delimeter_row = vim.api.nvim_buf_get_lines(buffer, table_startl + 1 - 1, table_startl + 1, false)[1]

    -- If it find anything other than |, :, - in delemeter row table is not valid
    if delimeter_row:match("[^:%-|]+") then
        return { valid = false }
    end

    for i = origin_lnum, upper_limit_lnum do
        local cur_line = vim.api.nvim_buf_get_lines(buffer, i - 1, i, false)[1]
        local count = select(2, cur_line:gsub("|", ""))
        if count < 2 then
            break
        end
        table_endl = i
    end

    if table_endl == 0 then
        return { valid = false }
    end

    return {
        valid = true,
        buffer = buffer,
        startl = table_startl,
        endl = table_endl,
    }
end

---Write the table to the buffer
---Use startl == endl for inserting at current line
---@param opts MdnTable
function M.write_table(opts)
    opts = opts or {}

    local buffer = opts.buffer or vim.api.nvim_get_current_buf()
    local startl = opts.startl or vim.fn.line('.')
    local endl = opts.endl or vim.fn.line('.')
    local contents = opts.contents or {""}

    vim.validate("buffer", buffer, "number")
    vim.validate("startl", startl, "number")
    vim.validate("endl", endl, "number")
    vim.validate("contents", contents, "table")

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

    vim.api.nvim_buf_set_lines(buffer, startl - 1, endl, false, table_formatted)
end

---Create a table with r rows and c columns
---@param rows integer|string
---@param columns integer|string
---@param opts {buffer: integer?, lnum: integer?}?
function M.create(rows, columns, opts)
    if rows == nil or columns == nil then
        vim.notify("Mdn: Please specify both row and column dimensions", vim.log.levels.ERROR)
        return
    end

    opts = opts or {}
    local buffer = opts.buffer or vim.api.nvim_get_current_buf()
    local lnum = opts.lnum or vim.fn.line('.')

    if type(rows) == "string" then
        rows = vim.fn.str2nr(rows)
    end

    if type(columns) == "string" then
        columns = vim.fn.str2nr(columns)
    end

    vim.validate("rows", rows, "number")
    vim.validate("columns", columns, "number")

    local row_entry = {}
    local new_table = {}
    local header_row = {}

    for _ = 1, rows do
        row_entry = {}
        for _ = 1, columns do
            table.insert(row_entry, "    ")
        end
        table.insert(new_table, row_entry)
    end

    for _ = 1, columns do
        table.insert(header_row, "----")
    end
    table.insert(new_table, 2, header_row)

    M.write_table({ buffer = buffer, startl = lnum, endl = lnum, contents = new_table })
end

---Get the table lines in the specified line numbers
---@param buffer integer
---@param table_startl integer
---@param table_endl integer
---@return MdnTableContents
function M.get_table_lines(buffer, table_startl, table_endl)
    buffer = buffer or vim.api.nvim_get_current_buf()

    vim.validate("buffer", buffer, "number")
    vim.validate("table_startl", table_startl, "number")
    vim.validate("table_endl", table_endl, "number")

    local table_lines = {}
    local lines = vim.api.nvim_buf_get_lines(buffer, table_startl - 1, table_endl, false)

    -- Trim whitespace
    for r, v in ipairs(lines) do
        lines[r] = vim.trim(v)
    end

    local table_temp = {}

    for _, v in ipairs(lines) do
        table_temp = {}
        for text in v:gmatch("[^|]+") do
            table.insert(table_temp, text)
        end

        if vim.tbl_isempty(table_temp) then
            table.insert(table_temp, "")
        end

        table.insert(table_lines, table_temp)
    end

    return table_lines
end

---Get the table lines along with some more information (which is why it's called complex)
---@param buffer integer
---@param table_startl integer
---@param table_endl integer
---@return MdnTableContentsComplex
function M.get_table_lines_complex(buffer, table_startl, table_endl)
    buffer = buffer or vim.api.nvim_get_current_buf()

    vim.validate("buffer", buffer, "number")
    vim.validate("table_startl", table_startl, "number")
    vim.validate("table_endl", table_endl, "number")

    local table_lines = M.get_table_lines(buffer, table_startl, table_endl)

    if table_lines == nil then
        -- Errors would already be outputted
        return {}
    end

    local col_locations = M.get_column_locations() or {{0}}
    local table_complex = {}
    local table_complex_entry = {}

    for i, line in ipairs(table_lines) do
        table_complex_entry = {}
        for j, cell in ipairs(line) do
            table.insert(table_complex_entry, {
                content = cell,
                start_col = col_locations[i][j],
                end_col = col_locations[i][j + 1],
                lnum = i
            })
        end
        table.insert(table_complex, table_complex_entry)
    end

    return table_complex
end

---Parse the table
---@param opts {silent: boolean?, search: MdnSearchOpts?, complex: boolean?}?
---@return MdnTable
function M.parse(opts)
    opts = opts or {}

    local search_opts = opts.search or {}
    vim.validate("search_opts", search_opts, "table")

    local buffer = search_opts.buffer or vim.api.nvim_get_current_buf()
    local silent = opts.silent or false
    local complex = opts.complex or false

    vim.validate("silent", silent, "boolean")
    vim.validate("complex", complex, "boolean")

    local tsearch = M.check_table_valid({ search = search_opts })
    if tsearch.valid == false then
        if silent == false then
            vim.notify("Mdn: No valid table detected", vim.log.levels.ERROR)
        end

        return {}
    end

    local table_lines = {}
    if complex == false then
        table_lines = M.get_table_lines(search_opts.buffer, tsearch.startl, tsearch.endl) or {}
    elseif complex == true then
        table_lines = M.get_table_lines_complex(search_opts.buffer, tsearch.startl, tsearch.endl) or {}
    end

    if vim.tbl_isempty(table_lines) then
        if silent == false then
            vim.notify("Mdn: Error parsing table", vim.log.levels.ERROR)
        end

        return {}
    end

    return {
        contents = table_lines,
        startl = tsearch.startl,
        endl = tsearch.endl,
        buffer = buffer
    }
end

---Get the table column locations
---@param opts {search: MdnSearchOpts?}?
---@return MdnTableColLoc?
function M.get_column_locations(opts)
    opts = opts or {}
    local search_opts = opts.search or {}
    vim.validate("search_opts", search_opts, "table")

    local buffer = search_opts.buffer or vim.api.nvim_get_current_buf()

    -- Fence post problem, all tables will have n+1 '|' characters with n being the text    
    local tsearch = M.check_table_valid({ search = opts.search })
    if tsearch.valid == false then
        vim.notify("Mdn: No valid table detected", vim.log.levels.ERROR)
        return nil
    end

    local table_lines = vim.api.nvim_buf_get_lines(buffer, tsearch.startl - 1, tsearch.endl, false)
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

---Get the current column based on cursor location
---@return integer?
function M.get_cur_column_num()
    local tdata = M.parse({ complex = true })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return nil
    end

    local cur_cursor_col_pos = vim.fn.getpos(".")[3]

    for _, line in ipairs(tdata.contents) do
        for j, cell in ipairs(line) do
            -- Treats the left | as the start point of the column
            if cell.start_col <= cur_cursor_col_pos and cell.end_col > cur_cursor_col_pos then
                return j
            end
        end
    end

    return nil
end

---Insert column to the left of the current column
---@param opts {search: MdnSearchOpts?, cur_col: integer?}?
function M.column_insert_left(opts)
    opts = opts or {}
    local tdata = M.parse({ search = opts.search })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_col = opts.cur_col or M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    vim.validate("cur_col", cur_col, "number")

    for i, v in ipairs(tdata.contents) do
        if i == 2 then
            table.insert(v, cur_col, "----")
        else
            table.insert(v, cur_col, "    ")
        end
    end

    M.write_table(tdata)
end

---Insert column to the right of the current column
---@param opts {search: MdnSearchOpts?, cur_col: integer?}?
function M.column_insert_right(opts)
    opts = opts or {}
    local tdata = M.parse({ search = opts.search })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_col = opts.cur_col or M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    vim.validate("cur_col", cur_col, "number")

    for i, v in ipairs(tdata.contents) do
        if i == 2 then
            table.insert(v, cur_col + 1, "----")
        else
            table.insert(v, cur_col + 1, "    ")
        end
    end

    M.write_table(tdata)
end

---Move current column to the left
---@param opts {search: MdnSearchOpts?, cur_col: integer?}?
function M.column_move_left(opts)
    opts = opts or {}
    local tdata = M.parse({ search = opts.search })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_col = opts.cur_col or M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    vim.validate("cur_col", cur_col, "number")

    local new_col = cur_col - 1
    if new_col < 1 or new_col > #tdata.contents[1] then
        vim.notify("Mdn: Column move exceeds table dimensions", vim.log.levels.ERROR)
        return
    end

    local temp_col_val = ""
    for _, v in ipairs(tdata.contents) do
        temp_col_val = v[cur_col]
        table.remove(v, cur_col)
        table.insert(v, new_col, temp_col_val)
    end

    M.write_table(tdata)
end

---Move current column to the right
---@param opts {search: MdnSearchOpts?, cur_col: integer?}?
function M.column_move_right(opts)
    opts = opts or {}
    local tdata = M.parse({ search = opts.search })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_col = opts.cur_col or M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    vim.validate("cur_col", cur_col, "number")

    local new_col = cur_col + 1
    if new_col < 1 or new_col > #tdata.contents[1] then
        vim.notify("Mdn: Column move exceeds table dimensions", vim.log.levels.ERROR)
        return
    end

    local temp_col_val = ""
    for _, v in ipairs(tdata.contents) do
        temp_col_val = v[cur_col]
        table.remove(v, cur_col)
        table.insert(v, new_col, temp_col_val)
    end

    M.write_table(tdata)
end

---Insert an empty row above the current row
---@param opts {search: MdnSearchOpts?, lnum: integer?}?
function M.row_insert_above(opts)
    opts = opts or {}
    local search_opts = opts.search or {}
    local lnum = opts.lnum or vim.fn.line('.')
    vim.validate("search_opts", search_opts, "table")
    vim.validate("lnum", lnum, "number")

    local tdata = M.parse({ search = search_opts })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_table_lnum = lnum - tdata.startl

    -- In case the table is at the very top
    if cur_table_lnum == 0 then cur_table_lnum = 1 end

    local new_table_line = {}
    local cur_table_line = tdata.contents[cur_table_lnum]
    for _, v in ipairs(cur_table_line) do
        local text = v:gsub(".", " ")
        table.insert(new_table_line, text)
    end

    table.insert(tdata.contents, cur_table_lnum, new_table_line)

    M.write_table(tdata)
end

---Insert an empty row below the current row
---@param opts {search: MdnSearchOpts?, lnum: integer?}?
function M.row_insert_below(opts)
    opts = opts or {}
    local search_opts = opts.search or {}
    local lnum = opts.lnum or vim.fn.line('.')
    vim.validate("search_opts", search_opts, "table")
    vim.validate("lnum", lnum, "number")

    local tdata = M.parse({ search = search_opts })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_table_lnum = lnum - tdata.startl

    -- In case the table is at the very top
    if cur_table_lnum == 0 then cur_table_lnum = 1 end

    local new_table_line = {}
    local cur_table_line = tdata.contents[cur_table_lnum]
    for _, v in ipairs(cur_table_line) do
        local text = v:gsub(".", " ")
        table.insert(new_table_line, text)
    end

    table.insert(tdata.contents, cur_table_lnum + 1, new_table_line)

    M.write_table(tdata)
end

---Add the appropriate amount of spaces for each column
---@param opts {silent: boolean?, search: MdnSearchOpts?}?
function M.best_fit(opts)
    opts = opts or {}
    local silent = opts.silent or false
    local search_opts = opts.search or {}
    vim.validate("silent", silent, "boolean")

    local tdata = M.parse({ search = search_opts, silent = silent })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local max_char_count = {}
    local padding = ""
    local config_best_fit_padding = require('mdnotes').config.table_best_fit_padding
    if config_best_fit_padding > 0 then
        padding = (" "):rep(config_best_fit_padding)
    end

    -- Trim whitespace in each cell
    for r, v in ipairs(tdata.contents) do
        for c, vv in ipairs(v) do
            tdata.contents[r][c] = padding .. vim.trim(vv) .. padding
        end
    end

    local cols_count = #tdata.contents[1]

    -- Initialise the max char count
    for _ = 1, cols_count do
        table.insert(max_char_count, 0)
    end

    -- Get max char count for each column
    for c = 1, cols_count do
        for _, r in ipairs(tdata.contents) do
            if #r[c] > max_char_count[c]  then
                max_char_count[c] = #r[c]
            end
        end
    end

    -- Add spaces to fill void in smaller cells
    for r, v in ipairs(tdata.contents) do
        for c, vv in ipairs(v) do
            if #vv < max_char_count[c] then
                tdata.contents[r][c] = vv .. (" "):rep(max_char_count[c] - #vv)
            end
        end
    end

    -- Add the dashes for the delimeter row
    local new_delimiter_row = ""
    for c, v in ipairs(tdata.contents[2]) do
        local colon1, _, colon2 = v:match("([:]?)([-]+)([:]?)")
        new_delimiter_row = ("-"):rep(max_char_count[c])
        if colon1 == ":" then
            new_delimiter_row =  ":" .. new_delimiter_row:sub(2)
        end
        if colon2 == ":" then
            new_delimiter_row = new_delimiter_row:sub(1, -2) .. ":"
        end
        tdata.contents[2][c] = new_delimiter_row
    end

    M.write_table(tdata)
end

---Delete current column
---@param opts {search: MdnSearchOpts?, cur_col: integer?}?
function M.column_delete(opts)
    opts = opts or {}
    local tdata = M.parse({ search = opts.search })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_col = opts.cur_col or M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    vim.validate("cur_col", cur_col, "number")

    for _, v in ipairs(tdata.contents) do
        table.remove(v, cur_col)
    end

    M.write_table(tdata)
end

---Toggle alignment of the current column
---@param opts {search: MdnSearchOpts?, cur_col: integer?}?
function M.column_alignment_toggle(opts)
    opts = opts or {}
    local tdata = M.parse({ search = opts.search })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_col = opts.cur_col or M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    vim.validate("cur_col", cur_col, "number")

    local delimiter_row = tdata.contents[2][cur_col]
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

    tdata.contents[2][cur_col] = new_delimiter_row

    M.write_table(tdata)
end

---Duplicate the current column. Inserts it to the right
---@param opts {search: MdnSearchOpts?, cur_col: integer?}?
function M.column_duplicate(opts)
    opts = opts or {}
    local tdata = M.parse({ search = opts.search })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_col = opts.cur_col or M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    vim.validate("cur_col", cur_col, "number")

    for _, r in ipairs(tdata.contents) do
        for j, c in ipairs(r) do
            if j == cur_col then
                table.insert(r, cur_col, c)
                break
            end
        end
    end

    M.write_table(tdata)
end

---Get table as columns
---@param opts {silent: boolean?, search: MdnSearchOpts?}?
---@return MdnTableContents? contents 
function M.get_table_columns(opts)
    opts = opts or {}
    local silent = opts.silent or false
    local search_opts = opts.search or {}
    vim.validate("silent", silent, "boolean")
    vim.validate("search_opts", search_opts, "table")

    local tdata = M.parse({ search = search_opts, silent = silent })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local table_columns = {}
    local column = {}
    for c = 1, #tdata.contents[1] do
        column = {}
        for _, r in ipairs(tdata.contents) do
            table.insert(column, r[c])
        end
        table.insert(table_columns, column)
    end

    return table_columns
end

---Sort table based on current column using a comp function
---@param comp fun(a, b): boolean
---@param opts {search: MdnSearchOpts?, cur_col: integer?, write: boolean?}?
function M.column_sort(comp, opts)
    opts = opts or {}

    local write = opts.write ~= false
    local tdata = M.parse({ search = opts.search })

    if tdata.contents == nil then
        -- Errors would already be outputted
        return
    end

    local cur_col = opts.cur_col or M.get_cur_column_num()

    if cur_col == nil then
        return
    end

    vim.validate("cur_col", cur_col, "number")

    local table_columns = M.get_table_columns({ search = opts.search })

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

    local new_table_lines = {}
    table.insert(new_table_lines, tdata.contents[1])
    table.insert(new_table_lines, tdata.contents[2])
    for _, v in ipairs(index_tbl) do
        new_table_lines[v.new_index] = tdata.contents[v.old_index]
    end

    if write == true then
        tdata.contents = new_table_lines
        M.write_table(tdata)
    end

    return new_table_lines, tdata.startl, tdata.endl
end

---@param opts {search: MdnSearchOpts?, cur_col: integer?, write: boolean?}?
function M.column_sort_ascending(opts)
    M.column_sort(function(a, b) return a < b end, opts or {})
end

---@param opts {search: MdnSearchOpts?, cur_col: integer?, write: boolean?}?
function M.column_sort_descending(opts)
    M.column_sort(function(a, b) return a > b end, opts or {})
end

---Parse columns back to lines
---@param contents MdnTableContents
---@return MdnTableContents contents 
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
