---Mdnotes

if vim.g.loaded_mdnotes then
    return
end
vim.g.loaded_mdnotes = true

local mdnotes_group = vim.api.nvim_create_augroup('Mdnotes', { clear = true })

-- To save the current working directory
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    group = mdnotes_group,
    callback = function()
        require('mdnotes').set_cwd()
    end,
})

-- To record buffer history
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    group = mdnotes_group,
    callback = function(args)
        require('mdnotes.history').record_buf(args.buf)
    end,
})

-- Parsing fragments for :Mdn generate_toc and :Mdn inline_link open
vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
    pattern = "*.md",
    group = mdnotes_group,
    callback = function(args)
        require('mdnotes.toc').populate_buf_fragments(args.buf)
    end,
})

-- Automatic ordered list renumbering
vim.api.nvim_create_autocmd({"TextChangedI"}, {
    pattern = "*.md",
    group = mdnotes_group,
    callback = function()
        if require('mdnotes').config.auto_list_renumber == true then
            if not require("mdnotes.formatting").ordered_list_renumber(true) then
                return
            end
        end
    end
})

-- Automatic table best fit
vim.api.nvim_create_autocmd({"ModeChanged"}, {
    pattern = {"i:n", "*.md"},
    group = mdnotes_group,
    callback = function()
        if require('mdnotes').config.auto_table_best_fit == true then
            if not require("mdnotes.table").best_fit(true) then
                return
            end
        end
    end
})

-- Outliner State Message
vim.api.nvim_create_autocmd({"CursorMoved"}, {
    pattern = {"*.md"},
    group = mdnotes_group,
    callback = function()
        if require("mdnotes.outliner").outliner_state == true then
            vim.notify("-- MDN OUTLINER --", vim.log.levels.INFO)
            return
        end
    end
})

local commands = nil
local get_commands = function() return {
    index = {
        require("mdnotes").go_to_index_file,
        open_containing_folder = require("mdnotes").open_containing_folder,
    },
    journal = {
        require("mdnotes").go_to_journal_file,
        insert_entry = require("mdnotes").journal_insert_entry,
    },
    formatting = {
        strong_toggle = require("mdnotes.formatting").strong_toggle,
        emphasis_toggle = require("mdnotes.formatting").emphasis_toggle,
        strikethrough_toggle = require("mdnotes.formatting").strikethrough_toggle,
        inline_code_toggle = require("mdnotes.formatting").inline_code_toggle,
        autolink_toggle = require("mdnotes.formatting").autolink_toggle,
        task_list_toggle = require("mdnotes.formatting").task_list_toggle,
        ordered_list_renumber = require("mdnotes.formatting").ordered_list_renumber,
        unformat_lines = require("mdnotes.formatting").unformat_lines,
    },
    wikilink = {
        follow = require("mdnotes.wikilink").follow,
        show_references = require("mdnotes.wikilink").show_references,
        rename_references = require("mdnotes.wikilink").rename_references,
        undo_rename = require("mdnotes.wikilink").undo_rename,
        create = require("mdnotes.wikilink").create,
        delete = require("mdnotes.wikilink").delete,
        normalize = require("mdnotes.wikilink").normalize,
        find_orphans = require("mdnotes.wikilink").find_orphans,
    },
    table = {
        create = require("mdnotes.table").create,
        best_fit = require("mdnotes.table").best_fit,
        column_insert_left = require("mdnotes.table").column_insert_left,
        column_insert_right = require("mdnotes.table").column_insert_right,
        column_move_left = require("mdnotes.table").column_move_left,
        column_move_right = require("mdnotes.table").column_move_right,
        column_delete = require("mdnotes.table").column_delete,
        column_alignment_toggle = require("mdnotes.table").column_alignment_toggle,
        column_duplicate = require("mdnotes.table").column_duplicate,
        row_insert_above = require("mdnotes.table").row_insert_above,
        row_insert_below = require("mdnotes.table").row_insert_below,
    },
    history = {
        go_back = require("mdnotes.history").go_back,
        go_forward = require("mdnotes.history").go_forward,
        clear = require("mdnotes.history").clear,
    },
    assets = {
        insert_file = require("mdnotes.assets").insert_file,
        insert_image = require("mdnotes.assets").insert_image,
        delete_unused = require("mdnotes.assets").delete_unused,
        move_unused = require("mdnotes.assets").move_unused,
        open_containing_folder = require("mdnotes.assets").open_containing_folder,
        download_website_html  = require("mdnotes.assets").download_website_html,
    },
    outliner= {
        toggle = require("mdnotes.outliner").toggle,
        indent = require("mdnotes.outliner").indent,
        unindent = require("mdnotes.outliner").unindent,
    },
    inline_link = {
        open = require("mdnotes.inline_link").open,
        toggle = require("mdnotes.inline_link").toggle,
        rename = require("mdnotes.inline_link").rename,
        relink = require("mdnotes.inline_link").relink,
        normalize = require("mdnotes.inline_link").normalize,
        validate = require("mdnotes.inline_link").validate,
        convert_fragment_to_gfm = require("mdnotes.inline_link").convert_fragment_to_gfm,
    },
    toc = {
        generate = require("mdnotes.toc").generate
    },
    heading = {
        next = require("mdnotes.heading").goto_next,
        previous = require("mdnotes.heading").goto_previous,
    },
}
end

vim.api.nvim_create_user_command( "Mdn", function(opts)
    ---@type table<any>
    local args = vim.split(opts.args, "%s+")
    local cmd_arg = args[1]
    local subcmd_arg = ""
    local func = nil
    commands = commands or get_commands()

    local command = commands[cmd_arg]
    if #args > 1 then
        subcmd_arg = args[2]
        func = command[subcmd_arg]
    else
        func = command[1]
    end

    if func == commands["formatting"]["task_list_toggle"]
        or func == commands["formatting"]["unformat_lines"] then
        func(opts.line1, opts.line2)
    elseif func == commands["table"]["create"] then
        func(args[3], args[4])
    elseif func == commands["toc"]["generate"] then
        func(true, args[3])
    elseif func then
        func()
    else
        vim.notify("Unknown command: '" .. cmd_arg .. " " .. subcmd_arg .. "'", vim.log.levels.ERROR)
    end
end,
{
    nargs = "+",
    complete = function(arg, cmd, _)
        local args = vim.split(cmd, "%s+")
        commands = commands or get_commands()

        if #args == 2 then
            -- Command completion
            return vim.tbl_filter(function(k)
                return k:find("^" .. arg)
            end, vim.tbl_keys(commands))
        elseif #args == 3 then
            -- Subcommand completion
            local category = args[2]
            local subcmd = commands[category]

            if not subcmd then
                return
            end

            return vim.tbl_filter(function(k)
                if type(k) == "number" then return false end
                return k:find("^" .. arg)
            end, vim.tbl_keys(subcmd))
        end
    end,
    desc = "Mdnotes main command",
    range = true,
})


