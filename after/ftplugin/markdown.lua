local mdnotes = require("mdnotes")

if mdnotes.config.auto_list then
    vim.keymap.set("i", "<CR>", function ()
        local line = vim.api.nvim_get_current_line()
        local _, list_marker, list_text = line:match(mdnotes.format_patterns.list)
        local _, ordered_marker, separator, ordered_text = line:match(mdnotes.format_patterns.ordered_list)

        if list_marker then
            if list_text:match(mdnotes.format_patterns.task) then
                return "\n" .. list_marker .. " " .. "[ ] "
            else
                return "\n" .. list_marker .. " "
            end
        end

        if ordered_marker then
            if ordered_text:match(mdnotes.format_patterns.task) then
                return "\n" .. tostring(tonumber(ordered_marker + 1)) .. separator .. " " .. "[ ] "
            else
                return "\n" .. tostring(tonumber(ordered_marker + 1)) .. separator .. " "
            end
        end
        return "\n"
    end,
    {
        expr = true,
        desc = "Mdnotes <CR> remap for auto-lists",
        buffer = true
    })
end

