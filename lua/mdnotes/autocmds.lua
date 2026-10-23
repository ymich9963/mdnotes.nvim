---@module "mdnotes.autocmds"

local mdnotes_cwd_group = vim.api.nvim_create_augroup('mdn.cwd', { clear = true })
local mdnotes_record_group = vim.api.nvim_create_augroup('mdn.record', { clear = true })
local mdnotes_pop_frag_group = vim.api.nvim_create_augroup('mdn.pop_frag', { clear = true })
local mdnotes_renumber_group = vim.api.nvim_create_augroup('mdn.renumber', { clear = true })
local mdnotes_best_fit_group = vim.api.nvim_create_augroup('mdn.best_fit', { clear = true })
local mdnotes_outliner_group = vim.api.nvim_create_augroup('mdn.outliner', { clear = true })
local mdnotes_journal_group = vim.api.nvim_create_augroup('mdn.journal', { clear = true })
local mdnotes_pop_rl_group = vim.api.nvim_create_augroup('mdn.pop_rl', { clear = true })
local mdnotes_pop_fn_group = vim.api.nvim_create_augroup('mdn.pop_fn', { clear = true })

-- To save the current working directory
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    group = mdnotes_cwd_group,
    callback = function()
        require('mdnotes').set_cwd()
    end,
    desc = "Mdnotes automatic setting of cwd autocmd"
})

-- To record buffer history
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    group = mdnotes_record_group,
    callback = function(args)
        require('mdnotes.history').record_buf(args.buf)
    end,
    desc = "Mdnotes record buffer autocmd for buffer history"
})

-- Parsing fragments for :Mdn generate_toc and :Mdn inline_link open
vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
    pattern = "*.md",
    group = mdnotes_pop_frag_group,
    callback = function(args)
        require('mdnotes').populate_buf_fragments(args.buf)
    end,
    desc = "Mdnotes populating buffer fragments table autocmd"
})

-- Automatic ordered list renumbering
vim.api.nvim_create_autocmd({"TextChangedI"}, {
    pattern = "*.md",
    group = mdnotes_renumber_group,
    callback = function()
        require("mdnotes.list").ordered_list_renumber({ silent = true })
    end,
    desc = "Mdnotes automatic ordered list renumber autocmd"
})

-- Automatic table best fit
vim.api.nvim_create_autocmd({"ModeChanged"}, {
    pattern = {"i:n", "*.md"},
    group = mdnotes_best_fit_group,
    callback = function()
        require("mdnotes.table").best_fit({ silent = true })
    end,
    desc = "Mdnotes automatic table best fit autocmd"
})

-- Outliner State Message
vim.api.nvim_create_autocmd({"CursorMoved"}, {
    pattern = "*.md",
    group = mdnotes_outliner_group,
    callback = function()
        if require("mdnotes.outliner").outliner_state == true then
            vim.notify("-- MDN OUTLINER --", vim.log.levels.INFO)
            return
        end
    end,
    desc = "Mdnotes outliner state autocmd"
})

-- Automatic journal entry
vim.api.nvim_create_autocmd({"BufEnter"}, {
    pattern = "*.md",
    group = mdnotes_journal_group,
    callback = function()
        require("mdnotes.journal").insert_entry({ silent = true, check_file = true })
    end,
    desc = "Mdnotes automatic journal entry autocmd"
})

-- Parse reference links in current buffer
vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
    pattern = "*.md",
    group = mdnotes_pop_rl_group,
    callback = function(args)
        require('mdnotes.reference_link').populate_buf_reference_link_definitions(args.buf)
    end,
    desc = "Mdnotes populating buffer reference links table autocmd"
})

-- Parse footnotes in current buffer
vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
    pattern = "*.md",
    group = mdnotes_pop_fn_group,
    callback = function(args)
        require('mdnotes.footnote').populate_buf_footnotes(args.buf)
    end,
    desc = "Mdnotes populating buffer footnotes table autocmd"
})

