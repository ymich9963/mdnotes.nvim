local M = {}

local function write_table(contents, start_line, end_line)
    local table_start_line_num = start_line or nil
    local table_end_line_num = end_line or nil
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
        vim.api.nvim_buf_set_lines(0, table_start_line_num, table_end_line_num, false, table_formatted)
    end
end

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

function M.best_fit()
    local table_valid, startl, endl = check_valid_table()
    if not table_valid then
        vim.notify(("Mdn: No valid table detected."), vim.log.levels.ERROR)
        return
    end

    local table_lines = parse_table(startl, endl)
    if vim.tbl_isempty(table_lines) then
        vim.notify(("Mdn: Error parsing table."), vim.log.levels.ERROR)
        return
    end

    local max_char_count = {}

    -- Trim whitespace in each cell
    for r, v in ipairs(table_lines) do
        for c, vv in ipairs(v) do
            table_lines[r][c] = vim.trim(vv)
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
    for c, _ in ipairs(table_lines[2]) do
        table_lines[2][c] = ("-"):rep(max_char_count[c])
    end

    write_table(table_lines, startl, endl)
end

return M
