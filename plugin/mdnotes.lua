if vim.g.loaded_mdnotes then
    return
end
vim.g.loaded_mdnotes = true

local mdnotes = require('mdnotes')

local mdnotes_group = vim.api.nvim_create_augroup('Mdnotes', { clear = true })

-- To record buffer history
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    group = mdnotes_group,
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

vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    group = mdnotes_group,
    callback = function(args)
        local buf_exists = false
        local buf_num = args.buf
        local index = 0
        for i,v in ipairs(mdnotes.buf_sections) do
            if v.buf_num == buf_num then
                buf_exists = true
                index = i
                break
            end
        end

        local original_sections = mdnotes.get_sections_original()
        if buf_exists then
            if mdnotes.buf_sections[index].parsed.original ~= original_sections then
                mdnotes.buf_sections[index].parsed.original = original_sections
                mdnotes.buf_sections[index].parsed.gfm = mdnotes.get_sections_gfm_from_original(original_sections)
            end
        else
            table.insert(mdnotes.buf_sections, {
                buf_num = buf_num,
                parsed = {
                    original = original_sections,
                    gfm = mdnotes.get_sections_gfm_from_original(original_sections)
                }
            })
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
    task_list_toggle = mdnotes.task_list_toggle,
    insert_journal_entry = mdnotes.insert_journal_entry,
    generate_toc = mdnotes.generate_toc,
}

vim.api.nvim_create_user_command( "Mdn", function(opts)
    local args = vim.split(opts.args, "%s+")
    local subcmd = args[1]

    local func = subcommands[subcmd]
    if func == subcommands["task_list_toggle"] then
        func(opts.line1, opts.line2)
    elseif func then
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

