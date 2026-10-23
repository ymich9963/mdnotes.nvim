local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
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
            child.lua([[require('mdnotes').setup()]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['delete_format()'] = new_set({
    parametrize = {
        { '_re' },
        { '_ts' }
    }
})

T['delete_format()']['impl'] = function(suffix)
    local lines = {"emphasis *emphasis*"}
    local buf = create_md_buffer(child, lines)

    child.fn.cursor(1, 12)
    child.lua([[Mdn.formatting.delete_format]] .. suffix .. [[("emphasis")]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "emphasis emphasis")
    eq(child.fn.getcurpos()[3], 11)
end

T['emphasis'] = function()
    -- Setup test buffer
    local lines = {"emphasis emphasis"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[Mdn.formatting.emphasis_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "*emphasis* emphasis")
    eq(child.fn.getcurpos()[3], 2)

    child.fn.cursor(1, 12)
    child.lua([[Mdn.formatting.emphasis_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "*emphasis* *emphasis*")
    eq(child.fn.getcurpos()[3], 13)

    child.lua([[Mdn.formatting.emphasis_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "*emphasis* emphasis")
    eq(child.fn.getcurpos()[3], 12)

    child.fn.cursor(1, 2)
    child.lua([[Mdn.formatting.emphasis_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "emphasis emphasis")
    eq(child.fn.getcurpos()[3], 1)
end

T['strong'] = function()
    -- Setup test buffer
    local lines = {"strong strong"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[Mdn.formatting.strong_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "**strong** strong")
    eq(child.fn.getcurpos()[3], 3)

    child.fn.cursor(1, 12)
    child.lua([[Mdn.formatting.strong_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "**strong** **strong**")
    eq(child.fn.getcurpos()[3], 14)

    child.fn.cursor(1, 14)
    child.lua([[Mdn.formatting.strong_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "**strong** strong")
    eq(child.fn.getcurpos()[3], 12)

    child.fn.cursor(3, 3)
    child.lua([[Mdn.formatting.strong_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "strong strong")
    eq(child.fn.getcurpos()[3], 1)
end

T['strikethrough'] = function()
    -- Setup test buffer
    local lines = {"strikethrough strikethrough"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[Mdn.formatting.strikethrough_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "~strikethrough~ strikethrough")
    eq(child.fn.getcurpos()[3], 2)

    child.fn.cursor(1, 21)
    child.lua([[Mdn.formatting.strikethrough_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "~strikethrough~ ~strikethrough~")
    eq(child.fn.getcurpos()[3], 22)

    child.lua([[Mdn.formatting.strikethrough_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "~strikethrough~ strikethrough")
    eq(child.fn.getcurpos()[3], 21)

    child.fn.cursor(1, 2)
    child.lua([[Mdn.formatting.strikethrough_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "strikethrough strikethrough")
    eq(child.fn.getcurpos()[3], 1)
end

T['inline_code'] = function()
    -- Setup test buffer
    local lines = {"inline_code inline_code"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[Mdn.formatting.inline_code_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "`inline_code` inline_code")
    eq(child.fn.getcurpos()[3], 2)

    child.fn.cursor(1, 15)
    child.lua([[Mdn.formatting.inline_code_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "`inline_code` `inline_code`")
    eq(child.fn.getcurpos()[3], 16)

    child.lua([[Mdn.formatting.inline_code_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "`inline_code` inline_code")
    eq(child.fn.getcurpos()[3], 15)

    child.fn.cursor(1, 2)
    child.lua([[Mdn.formatting.inline_code_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "inline_code inline_code")
    eq(child.fn.getcurpos()[3], 1)
end

T['autolink'] = function()
    -- Setup test buffer
    local lines = {"https://autolink.com https://autolink.com"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[Mdn.formatting.autolink_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "<https://autolink.com> https://autolink.com")
    eq(child.fn.getcurpos()[3], 2)

    child.fn.cursor(1, 24)
    child.lua([[Mdn.formatting.autolink_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "<https://autolink.com> <https://autolink.com>")
    eq(child.fn.getcurpos()[3], 25)

    child.lua([[Mdn.formatting.autolink_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "<https://autolink.com> https://autolink.com")
    eq(child.fn.getcurpos()[3], 24)

    child.fn.cursor(1, 2)
    child.lua([[Mdn.formatting.autolink_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "https://autolink.com https://autolink.com")
    eq(child.fn.getcurpos()[3], 1)
end

T['fenced_code_block()'] = function()
    -- Setup test buffer
    local lines = {
        "code"
    }
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[Mdn.formatting.fenced_code_block_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "```",
        "code",
        "```",
    })
    child.fn.cursor(2, 1)
    child.lua([[Mdn.formatting.fenced_code_block_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "code",
    })
end

return T
