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

-- Automatic ordered list renumbering
vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    pattern = "*.md",
    group = mdnotes_group,
    callback = function()
        if not require("mdnotes.formatting").ordered_list_renumber(true)
            and require('mdnotes.config').auto_list_renumber == true then
            return
        end
    end
})

-- Automatic table best fit
vim.api.nvim_create_autocmd({"ModeChanged"}, {
    pattern = {"*:n", "*.md"},
    group = mdnotes_group,
    callback = function()
        if not require("mdnotes.tables").best_fit(true)
            and require('mdnotes.config').auto_table_best_fit == true then
            return
        end
    end
})

local subcommands = nil
local get_subcommands = function() return {
    home = require("mdnotes").go_to_index_file,
    journal = require("mdnotes").go_to_journal_file,
    journal_insert_entry = require("mdnotes").journal_insert_entry,
    open = require("mdnotes").open,
    outliner_toggle = require("mdnotes.outliner").toggle,
    wikilink_follow = require("mdnotes.wikilinks").follow,
    wikilink_show_references = require("mdnotes.wikilinks").show_references,
    wikilink_rename_references = require("mdnotes.wikilinks").rename_references,
    wikilink_undo_rename = require("mdnotes.wikilinks").undo_rename,
    insert_image = require("mdnotes.assets").insert_image,
    insert_file = require("mdnotes.assets").insert_file,
    assets_cleanup_unused = require("mdnotes.assets").cleanup_unused,
    assets_move_unused = require("mdnotes.assets").move_unused,
    assets_open_containing_folder = require("mdnotes.assets").open_containing_folder,
    history_go_back = require("mdnotes.history").go_back,
    history_go_forward = require("mdnotes.history").go_forward,
    history_clear = require("mdnotes.history").clear,
    hyperlink_toggle = require("mdnotes.formatting").hyperlink_toggle,
    bold_toggle = require("mdnotes.formatting").bold_toggle,
    italic_toggle = require("mdnotes.formatting").italic_toggle,
    strikethrough_toggle = require("mdnotes.formatting").strikethrough_toggle,
    inline_code_toggle = require("mdnotes.formatting").inline_code_toggle,
    task_list_toggle = require("mdnotes.formatting").task_list_toggle,
    ordered_list_renumber = require("mdnotes.formatting").ordered_list_renumber,
    toc_generate = require("mdnotes.toc").generate,
    table_create = require("mdnotes.tables").create,
    table_best_fit = require("mdnotes.tables").best_fit,
    table_column_insert_left = require("mdnotes.tables").column_insert_left,
    table_column_insert_right = require("mdnotes.tables").column_insert_right,
    table_column_move_left = require("mdnotes.tables").column_move_left,
    table_column_move_right = require("mdnotes.tables").column_move_right,
    table_column_delete = require("mdnotes.tables").column_delete,
    table_column_alignment_toggle = require("mdnotes.tables").column_alignment_toggle,
    table_row_insert_above = require("mdnotes.tables").row_insert_above,
    table_row_insert_below = require("mdnotes.tables").row_insert_below
} end

vim.api.nvim_create_user_command( "Mdn", function(opts)
    local args = vim.split(opts.args, "%s+")
    local subcmd = args[1]
    subcommands = subcommands or get_subcommands()

    local func = subcommands[subcmd]
    if func == subcommands["task_list_toggle"] then
        func(opts.line1, opts.line2)
    elseif func == subcommands["table_create"] then
        func(args[2], args[3])
    elseif func then
        func()
    else
        vim.notify("Unknown subcommand: " .. (subcmd or ""), vim.log.levels.WARN)
    end
end,
{
    nargs = "+",
    complete = function(arg)
        subcommands = subcommands or get_subcommands()
        return vim.tbl_filter(function(sub)
            return sub:match("^" .. arg)
        end, vim.tbl_keys(subcommands))
    end,
    desc = "Mdnotes main command",
    range = true,
})

