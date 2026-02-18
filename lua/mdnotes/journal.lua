---@module 'mdnotes.journal'

local M = {}

---Resolve the journal file name from the config
---@return string path Journal file path
function M.get_journal_file()
    local config_journal_file = require('mdnotes').config.journal_file
    local ret = ""

    if type(config_journal_file) == "function" then
        ret = config_journal_file()
    elseif type(config_journal_file) == "string" then
        ret = config_journal_file
    end

    return vim.fs.normalize(ret)
end

---Go to journal file
function M.go_to()
    local journal_file = M.get_journal_file()

    if journal_file == "" then
        vim.notify("Mdn: Please specify a journal file to use this feature", vim.log.levels.ERROR)
        return
    end

    require('mdnotes').open_buf(journal_file)
end

---Insert an entry to the journal file
---@param opts {silent: boolean?, check_file: boolean}? opts.silent: Silence notifications, opts. check_file: Check if currently in journal file
function M.insert_entry(opts)
    opts = opts or {}
    local silent = opts.silent or false
    local check_file = opts.check_file or false

    vim.validate("silent", silent, "boolean")
    vim.validate("check_file", check_file, "boolean")

    local journal_file = M.get_journal_file()

    if journal_file == "" then
        if silent == false then
            vim.notify("Mdn: Please specify a journal file to use this feature", vim.log.levels.ERROR)
        end

        return
    end

    if check_file == true then
        local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
        if not bufname:find(journal_file, 1, true) then
            if silent == false then
                vim.notify("Mdn: Journal file is not currently open", vim.log.levels.ERROR)
            end

            return
        end
    end

    local strftime = vim.fn.strftime(require('mdnotes').config.date_format):match("([^\n\r\t]+)")
    local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
    local match = false

    for i = 1, #lines do
        if lines[i]:match(strftime) then
            match = true
            break
        end

        -- Limit search to x lines
        if i > 100 then
            break
        end
    end

    if match == false then
        local journal_entry_template = {
            "## " .. strftime,
            "",
            "",
            "",
            "---",
        }

        vim.fn.cursor({1 ,0})
        vim.api.nvim_put(journal_entry_template, "l", false, false)
        vim.fn.cursor({3 ,0})
    else
        if silent == false then
            vim.notify("Mdn: Journal entry already exists", vim.log.levels.WARN)
        end
    end
end

return M
