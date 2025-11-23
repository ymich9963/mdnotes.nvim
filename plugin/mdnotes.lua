if vim.g.loaded_mdnotes then
    return
end
vim.g.loaded_mdnotes = true

local mdnotes_group = vim.api.nvim_create_augroup('Mdnotes', { clear = true })

-- To record buffer history
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    group = mdnotes_group,
    callback = function(args)
        local mdnotes_history = require('mdnotes.history')
        local buf_num = args.buf
        if mdnotes_history.current_index == 0 or mdnotes_history.buf_history[mdnotes_history.current_index] ~= buf_num then
            -- If the user has went back and the current buffer is not the same as the stored buffer
            -- Create a copy of the list up to the current index and then add the new buffer
            if mdnotes_history.current_index < #mdnotes_history.buf_history then
                mdnotes_history.buf_history = vim.list_slice(mdnotes_history.buf_history, 1, mdnotes_history.current_index)
            end
            table.insert(mdnotes_history.buf_history, buf_num)
            mdnotes_history.current_index = #mdnotes_history.buf_history
        end
    end,
})

-- Parsing sections for :Mdn generate_toc and :Mdn open
vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
    pattern = "*.md",
    group = mdnotes_group,
    callback = function(args)
        local mdnotes_toc = require('mdnotes.toc')
        local buf_exists = false
        local buf_num = args.buf
        local original_sections = mdnotes_toc.get_sections_original()
        for _,v in ipairs(mdnotes_toc.buf_sections) do
            if v.buf_num == buf_num then
                buf_exists = true
                if v.parsed.original ~= original_sections then
                    v.parsed.original = original_sections
                    v.parsed.gfm = mdnotes_toc.get_sections_gfm_from_original(original_sections)
                end
                break
            end
        end

        if not buf_exists then
            table.insert(mdnotes_toc.buf_sections, {
                buf_num = buf_num,
                parsed = {
                    original = original_sections,
                    gfm = mdnotes_toc.get_sections_gfm_from_original(original_sections)
                }
            })
        end
    end,
})

local subcommands = {
    home = require("mdnotes").go_to_index_file,
    journal = require("mdnotes").go_to_journal_file,
    insert_journal_entry = require("mdnotes").insert_journal_entry,
    open = require("mdnotes").open,
    outliner_toggle = require("mdnotes.outliner").outliner_toggle,
    open_wikilink = require("mdnotes.wikilinks").open_wikilink,
    show_references = require("mdnotes.wikilinks").show_references,
    rename_references = require("mdnotes.wikilinks").rename_references,
    insert_image = require("mdnotes.assets").insert_image,
    insert_file = require("mdnotes.assets").insert_file,
    cleanup_unused_assets = require("mdnotes.assets").cleanup_unused_assets,
    move_unused_assets = require("mdnotes.assets").move_unused_assets,
    go_back = require("mdnotes.history").go_back,
    go_forward = require("mdnotes.history").go_forward,
    clear_history = require("mdnotes.history").clear_history,
    hyperlink_toggle = require("mdnotes.formatting").hyperlink_toggle,
    bold_toggle = require("mdnotes.formatting").bold_toggle,
    italic_toggle = require("mdnotes.formatting").italic_toggle,
    strikethrough_toggle = require("mdnotes.formatting").strikethrough_toggle,
    inline_code_toggle = require("mdnotes.formatting").inline_code_toggle,
    task_list_toggle = require("mdnotes.formatting").task_list_toggle,
    generate_toc = require("mdnotes.toc").generate_toc,
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

