local M = {}

local uv = vim.loop or vim.uv

M.config = {}
M.patterns = {}
M.bold_char = ""
M.italic_char = ""
M.open_cmd = nil

function M.setup(user_config)
    M.config = require('mdnotes.config').setup(user_config)
    M.patterns = require('mdnotes.patterns')

    M.bold_char = M.config.bold_format:sub(1, 1)
    M.italic_char = M.config.italic_format:sub(1, 1)

    if M.config.wikilink_open_behaviour == "buffer" then
        M.open_cmd = 'edit '
    elseif M.config.wikilink_open_behaviour == "tab" then
        M.open_cmd = 'tabnew '
    end
end

function M.list_remap(inc_val)
    -- ul = unordered list, ol = ordered list
    local line = vim.api.nvim_get_current_line()
    local ul_indent, ul_marker, ul_text = line:match(M.patterns.unordered_list)
    local ol_indent, ol_marker, ol_separator, ol_text = line:match(M.patterns.ordered_list)
    local indent = ul_indent or ol_indent
    local text = ul_text or ol_text or ""

    text = text:gsub(M.patterns.task, "")

    if text and text ~= "" then
        if ul_marker then
            if ul_text:match(M.patterns.task) then
                return indent, "\n" .. ul_marker .. " " .. "[ ] "
            else
                return indent, "\n" .. ul_marker .. " "
            end
        end

        if ol_marker then
            if ol_text:match(M.patterns.task) then
                return indent, "\n" .. tostring(tonumber(ol_marker + inc_val)) .. ol_separator .. " " .. "[ ] "
            else
                return indent, "\n" .. tostring(tonumber(ol_marker + inc_val)) .. ol_separator .. " "
            end
        end
    end

    return indent, "\n"
end

function M.open()
    local line = vim.api.nvim_get_current_line()
    local current_col = vim.fn.col('.')
    local link = ""
    local path = ""
    local section = ""

    for start_pos, hyperlink, end_pos in line:gmatch(M.patterns.hyperlink) do
        if start_pos < current_col and end_pos > current_col then
            _, link = hyperlink:match(M.patterns.text_link)
            break
        end
    end

    if link == "" then
        vim.notify(("Mdn: Nothing to open."), vim.log.levels.ERROR)
        return
    end

    link = link:gsub("[<>]?", "")
    path, section = link:match(M.patterns.file_section)

    -- Check for just a section first
    -- Path in this case is a section
    if link:sub(1,1) == "#" then
        path = require('mdnotes.toc').get_section(path)
        vim.fn.cursor(vim.fn.search("# " .. path), 1)
        vim.api.nvim_input('zz')
    else
        -- Then it is assumed to have a path
        -- Append .md to guarantee a file name
        if path:sub(-3) ~= ".md" then
            path = path .. ".md"
        end
        -- Check if the current file is the one in the link
        if path == vim.fs.basename(vim.api.nvim_buf_get_name(0)) then
            section = require('mdnotes.toc').get_section(path)
            vim.fn.cursor(vim.fn.search("# " .. section), 1)
            vim.api.nvim_input('zz')
            -- Check if the file exists
        elseif uv.fs_stat(path) then
            vim.cmd(M.open_cmd .. path)
            if section ~= "" then
                section = require('mdnotes.toc').get_section(path)
                vim.fn.cursor(vim.fn.search(section), 1)
                vim.api.nvim_input('zz')
            end
            -- Last case is when it should be treated as a URI
        elseif vim.fn.has("win32") then
            vim.system({'cmd.exe', '/c', 'start', '', link})
        else
            -- There might be issues with code below, see issue
            -- https://github.com/neovim/neovim/issues/36293
            vim.ui.open(link)
        end
    end
end

function M.go_to_index_file()
    if M.config.index_file == "" then
        vim.notify(("Mdn: Please specify an index file to use this feature."), vim.log.levels.ERROR)
        return
    end

    vim.cmd(M.open_cmd .. M.config.index_file)
end

function M.go_to_journal_file()
    if M.config.journal_file == "" then
        vim.notify(("Mdn: Please specify a diary file to use this feature."), vim.log.levels.ERROR)
        return
    end

    vim.cmd(M.open_cmd .. M.config.journal_file)
end

function M.journal_insert_entry()
    local strftime = vim.fn.strftime(M.config.date_format):match("([^\n\r\t]+)")
    local journal_entry_template = {
        "## " .. strftime,
        "",
        "",
        "",
        "---",
        "",
    }

    vim.api.nvim_win_set_cursor(0, {1 ,0})
    vim.api.nvim_put(journal_entry_template, "V", false, false)
    vim.api.nvim_win_set_cursor(0, {3 ,0})
end

return M

