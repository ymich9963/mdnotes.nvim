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

local function parse_table()
    local cur_line_num = vim.fn.line('.')
    local max_line_num = vim.fn.line('$')
    local min_line_num = 0
    local table_start_line_num = 0
    local table_end_line_num = 0
    local table_parsed = {}

    for i = cur_line_num, min_line_num, -1 do
        local line = vim.fn.getline(i)
        local _, count = line:gsub("|", "")
        if count < 2 then
            table_start_line_num = i
            break
        end
    end

    for i = cur_line_num, max_line_num do
        local line = vim.fn.getline(i)
        local _, count = line:gsub("|", "")
        if count < 2 then
            table_end_line_num = i - 1
            break
        end
    end

    if table_start_line_num == 0 and table_end_line_num == 0 then
        vim.notify(("Mdn: Could not detect table."), vim.log.levels.ERROR)
        return
    end

    local table_lines = vim.api.nvim_buf_get_lines(0, table_start_line_num, table_end_line_num, false)
    local table_temp = {}

    for _, v in ipairs(table_lines) do
        table_temp = {}
        for text in v:gmatch("[^|]+") do
            table.insert(table_temp, text)
        end
        table.insert(table_parsed, table_temp)
    end

    return table_parsed, table_start_line_num, table_end_line_num
end

function M.table_create(r, c)
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

function M.table_best_fit()
    local table_lines, startl, endl = parse_table()
    -- local max_char_count = 0
    local max_char_count = {}

    if not table_lines then
        vim.notify(("Mdn: Error parsing table."), vim.log.levels.ERROR)
        return
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
    for c, vv in ipairs(table_lines[2]) do
        table_lines[2][c] = vv:gsub(" ", "-")
    end

    write_table(table_lines, startl, endl)
end

return M
