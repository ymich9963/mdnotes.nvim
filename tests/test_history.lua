local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local helpers = require('tests/helpers')
local create_md_buffer = require('tests/helpers').create_md_buffer

-- Create (but not start) child Neovim object
local child = MiniTest.new_child_neovim()

-- Define main test set of this file
local T = new_set({
    -- Register hooks
    hooks = {
        -- This will be executed before every (even nested) case
        pre_case = function()
            -- Restart child process with custom 'init.lua' script
            child.restart({ '-u', 'scripts/minimal_init.lua' })
            -- Load tested plugin
            child.lua([[M = require('mdnotes')]])
            child.lua([[require('mdnotes').setup()]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['record_buf()'] = function()
    -- Setup test buffer
    local lines = {""}
    local buf1 = create_md_buffer(child, lines)

    local ret1 = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    return require('mdnotes.history').buf_history
    ]])

    eq(ret1, {buf1})

    local buf2 = create_md_buffer(child, lines)

    local ret2 = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    return require('mdnotes.history').buf_history
    ]])

    eq(ret2, {buf1, buf2})

    local ret3 = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    return require('mdnotes.history').buf_history
    ]])

    eq(ret3, {buf1, buf2})
end

T['go_back()/go_forward()'] = function()
    -- Setup test buffer
    local lines = {""}

    local buf1 = create_md_buffer(child, lines)
    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    return require('mdnotes.history').buf_history
    ]])

    local buf2 = create_md_buffer(child, lines)
    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    return require('mdnotes.history').buf_history
    ]])

    local buf3 = create_md_buffer(child, lines)
    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    return require('mdnotes.history').buf_history
    ]])

    -- Go back
    local ret1 = child.lua([[
    require('mdnotes.history').go_back()
    return vim.api.nvim_get_current_buf()
    ]])
    eq(ret1, buf2)

    local ret2 = child.lua([[
    return require('mdnotes.history').buf_history
    ]])
    eq(ret2, {buf1, buf2, buf3})

    local ret3 = child.lua([[
    return require('mdnotes.history').current_index
    ]])
    eq(ret3, 2)

    -- Go forward
    ret1 = child.lua([[
    require('mdnotes.history').go_forward()
    return vim.api.nvim_get_current_buf()
    ]])
    eq(ret1, buf3)

    ret2 = child.lua([[
    return require('mdnotes.history').buf_history
    ]])
    eq(ret2, {buf1, buf2, buf3})

    ret3 = child.lua([[
    return require('mdnotes.history').current_index
    ]])
    eq(ret3, 3)
end

T['overwrite'] = function()
    -- Setup test buffer
    local lines = {""}

    local buf1 = create_md_buffer(child, lines)
    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    ]])

    local buf2 = create_md_buffer(child, lines)
    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    ]])

    local buf3 = create_md_buffer(child, lines)
    local ret3 = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    return require('mdnotes.history').buf_history
    ]])
    eq(ret3, {buf1, buf2, buf3})

    -- Go back and create buffer 4
    child.lua([[require('mdnotes.history').go_back()]])
    local buf4 = create_md_buffer(child, lines)
    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    ]])

    local ret2 = child.lua([[
    return require('mdnotes.history').buf_history
    ]])
    eq(ret2, {buf1, buf2, buf4})
end

T['clear()'] = function()
    -- Setup test buffer
    local lines = {""}

    local buf1 = create_md_buffer(child, lines)
    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    ]])

    local buf2 = create_md_buffer(child, lines)
    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    ]])

    local buf3 = create_md_buffer(child, lines)
    local ret3 = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.history').record_buf(cur_buf)
    return require('mdnotes.history').buf_history
    ]])
    eq(ret3, {buf1, buf2, buf3})

    local ret = child.lua([[
    require('mdnotes.history').clear()
    return {require('mdnotes.history').buf_history, require('mdnotes.history').current_index}
    ]])
    eq(ret[1], {})
    eq(ret[2], 0)
end

return T
