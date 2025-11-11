if vim.g.loaded_mdnotes then
    return
end
vim.g.loaded_mdnotes = true

local mdnotes = require('mdnotes')

-- To record buffer history
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    callback = function(args)
        local buf_num = args.buf
        if mdnotes.current_index == 0 or mdnotes.buf_history[mdnotes.current_index] ~= buf_num then
            -- If the user has went back and the current buffer is not the same as the stored buffer
            -- Create a copy of the list up to the current index and then add the new buffer
            if mdnotes.current_index < #mdnotes.buf_history then
                mdnotes.buf_history = vim.list_slice(mdnotes.buf_history, 1, mdnotes.current_index)
            end
            table.insert(mdnotes.buf_history, buf_num)
            mdnotes.current_index = #mdnotes.buf_history
        end
    end,
})

local subcommands = {
    home = mdnotes.go_to_index_file,
    journal = mdnotes.go_to_journal_file,
    open = mdnotes.open,
    open_wikilink = mdnotes.open_wikilink,
    hyperlink_toggle = mdnotes.hyperlink_toggle,
    show_references = mdnotes.show_references,
    outliner_toggle = mdnotes.outliner_toggle,
    insert_image = mdnotes.insert_image,
    insert_file = mdnotes.insert_file,
    go_back = mdnotes.go_back,
    go_forward = mdnotes.go_forward,
    clear_history = mdnotes.clear_history,
    cleanup_unused_assets = mdnotes.cleanup_unused_assets,
    move_unused_assets = mdnotes.move_unused_assets,
    rename_link_references = mdnotes.rename_link_references,
    rename_references_cur_buf = mdnotes.rename_references_cur_buf,
    bold_toggle = mdnotes.bold_toggle,
    italic_toggle = mdnotes.italic_toggle,
    strikethrough_toggle = mdnotes.strikethrough_toggle,
    inline_code_toggle = mdnotes.inline_code_toggle,
    insert_journal_entry = mdnotes.insert_journal_entry,
}

vim.api.nvim_create_user_command( "Mdn", function(opts)
    local args = vim.split(opts.args, "%s+")
    local subcmd = args[1]

    local func = subcommands[subcmd]
    if func then
        func()
    else
        vim.notify("Unknown subcommand: " .. (subcmd or ""), vim.log.levels.WARN)
    end
end,
{
    nargs = "+",
    complete = function(arg)
        return vim.tbl_filter(function(sub)
            return sub:match("^" .. arg)
        end, vim.tbl_keys(subcommands))
    end,
    desc = "Markdown-notes main command",
    range = true,
})

