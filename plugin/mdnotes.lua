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
        if require('mdnotes.config').auto_list_renumber == true then
            if not require("mdnotes.formatting").ordered_list_renumber(true) then
                return
            end
        end
    end
})

-- Automatic table best fit
vim.api.nvim_create_autocmd({"ModeChanged"}, {
    pattern = {"*:n", "*.md"},
    group = mdnotes_group,
    callback = function()
        if require('mdnotes.config').auto_table_best_fit == true then
            if not require("mdnotes.tables").best_fit(true) then
                return
            end
        end
    end
})

local commands = nil
local get_commands = function() return {
        home = {
            require("mdnotes").go_to_index_file
        },
        open = {
            require("mdnotes").open
        },
        journal = {
            require("mdnotes").go_to_journal_file,
            insert_entry = require("mdnotes").journal_insert_entry,
        },
        formatting = {
            bold_toggle = require("mdnotes.formatting").bold_toggle,
            italic_toggle = require("mdnotes.formatting").italic_toggle,
            strikethrough_toggle = require("mdnotes.formatting").strikethrough_toggle,
            inline_code_toggle = require("mdnotes.formatting").inline_code_toggle,
            task_list_toggle = require("mdnotes.formatting").task_list_toggle,
            ordered_list_renumber = require("mdnotes.formatting").ordered_list_renumber,
        },
        wikilink = {
            follow = require("mdnotes.wikilinks").follow,
            show_references = require("mdnotes.wikilinks").show_references,
            rename_references = require("mdnotes.wikilinks").rename_references,
            undo_rename = require("mdnotes.wikilinks").undo_rename,
        },
        table = {
            create = require("mdnotes.tables").create,
            best_fit = require("mdnotes.tables").best_fit,
            column_insert_left = require("mdnotes.tables").column_insert_left,
            column_insert_right = require("mdnotes.tables").column_insert_right,
            column_move_left = require("mdnotes.tables").column_move_left,
            column_move_right = require("mdnotes.tables").column_move_right,
            column_delete = require("mdnotes.tables").column_delete,
            column_alignment_toggle = require("mdnotes.tables").column_alignment_toggle,
            column_duplicate = require("mdnotes.tables").column_duplicate,
            row_insert_above = require("mdnotes.tables").row_insert_above,
            row_insert_below = require("mdnotes.tables").row_insert_belo,
        },
        history = {
            go_back = require("mdnotes.history").go_back,
            go_forward = require("mdnotes.history").go_forward,
            clear = require("mdnotes.history").clear,
        },
        assets = {
            insert_image = require("mdnotes.assets").insert_image,
            insert_file = require("mdnotes.assets").insert_file,
            cleanup_unused = require("mdnotes.assets").cleanup_unused,
            move_unused = require("mdnotes.assets").move_unused,
            open_containing_folder = require("mdnotes.assets").open_containing_folder,
        },
        outliner_toggle = {
            require("mdnotes.outliner").toggle
        },
        inline_link = {
            toggle = require("mdnotes.formatting").hyperlink_toggle,
        },
        toc = {
            generate = require("mdnotes.toc").generate
        },
    }
end

vim.api.nvim_create_user_command( "Mdn", function(opts)
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

    if func == commands["formatting"]["task_list_toggle"] then
        func(opts.line1, opts.line2)
    elseif func == commands["table"]["create"] then
        func(args[3], args[4])
    elseif func then
        func()
    else
        vim.notify("Unknown command: " .. cmd_arg .. subcmd_arg, vim.log.levels.ERROR)
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
                return k:find("^" .. arg)
            end, vim.tbl_keys(subcmd))
        end
    end,
    desc = "Mdnotes main command",
    range = true,
})

