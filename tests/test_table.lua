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
            child.lua([[M = require('mdnotes')]])
            child.lua([[require('mdnotes').setup()]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['check_valid_table()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = (child.lua_get([[{require('mdnotes.table').check_valid_table()}]]))
    eq(ret[1], true)
    eq(ret[2], 1)
    eq(ret[3], 4)

    lines = {
        "|1r1c|1r2c|1r3c|",
        "|2r1c|2r2c|2r3c|",
    }
    create_md_buffer(child, lines)

    ret = child.lua_get([[{require('mdnotes.table').check_valid_table()}]])
    eq(ret[1], false)
    eq(ret[2], nil)
    eq(ret[3], nil)
end

T['write_table()'] = function()
    local lines = {
        "",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[
    local table_content = {
        {"1r1c","1r2c","1r3c"},
        {"----","----","----"},
        {"2r1c","2r2c","2r3c"},
        {"3r1c","3r2c","3r3c"},
    }

    require('mdnotes.table').write_table(table_content, 1, #table_content)
    ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    })
end

T['create()'] = function()
    local lines = {
        "",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[require('mdnotes.table').create(3,3)]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
        ""
    })
end

T['parse_table()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua_get([[require('mdnotes.table').parse_table(1,4)]])
    eq(ret, {
        {"1r1c","1r2c","1r3c"},
        {"----","----","----"},
        {"2r1c","2r2c","2r3c"},
        {"3r1c","3r2c","3r3c"},
    })
end

T['get_table()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua_get([[{require('mdnotes.table').get_table()}]])
    eq(ret[1], {
        {"1r1c","1r2c","1r3c"},
        {"----","----","----"},
        {"2r1c","2r2c","2r3c"},
        {"3r1c","3r2c","3r3c"},
    })
    eq(ret[2], 1)
    eq(ret[3], 4)
end

T['get_column_locations()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua_get([[require('mdnotes.table').get_column_locations()]])
    eq(ret, {
        {1, 6, 11, 16},
        {1, 6, 11, 16},
        {1, 6, 11, 16},
        {1, 6, 11, 16},
    })
end

T['get_table_complex()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local expected_table_complex =
    {
        {
            {
              content = "1r1c",
              start_pos = 1,
              end_pos = 6,
              line = 1,
            },
            {
              content = "1r2c",
              start_pos = 6,
              end_pos = 11,
              line = 1,
            },
            {
              content = "1r3c",
              start_pos = 11,
              end_pos = 16,
              line = 1,
            }
        },
        {
            {
              content = "----",
              start_pos = 1,
              end_pos = 6,
              line = 2,
            },
            {
              content = "----",
              start_pos = 6,
              end_pos = 11,
              line = 2,
            },
            {
              content = "----",
              start_pos = 11,
              end_pos = 16,
              line = 2,
            }
        },
        {
            {
              content = "2r1c",
              start_pos = 1,
              end_pos = 6,
              line = 3,
            },
            {
              content = "2r2c",
              start_pos = 6,
              end_pos = 11,
              line = 3,
            },
            {
              content = "2r3c",
              start_pos = 11,
              end_pos = 16,
              line = 3,
            }
        },
        {
            {
              content = "3r1c",
              start_pos = 1,
              end_pos = 6,
              line = 4,
            },
            {
              content = "3r2c",
              start_pos = 6,
              end_pos = 11,
              line = 4,
            },
            {
              content = "3r3c",
              start_pos = 11,
              end_pos = 16,
              line = 4,
            }
        }
    }

    local ret = child.lua_get([[{require('mdnotes.table').get_table_complex()}]])
    eq(ret[1], expected_table_complex)
    eq(ret[2], 1)
    eq(ret[3], 4)
end

T['get_cur_column()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua_get([[require('mdnotes.table').get_cur_column()]])
    eq(ret, 1)
end

T['insert_column()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[require('mdnotes.table').column_insert_right()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|    |1r2c|1r3c|",
        "|----|----|----|----|",
        "|2r1c|    |2r2c|2r3c|",
        "|3r1c|    |3r2c|3r3c|",
    })

    child.lua([[require('mdnotes.table').column_insert_left()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|    |1r1c|    |1r2c|1r3c|",
        "|----|----|----|----|----|",
        "|    |2r1c|    |2r2c|2r3c|",
        "|    |3r1c|    |3r2c|3r3c|",
    })
end

T['move_column()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[require('mdnotes.table').column_move_right()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r2c|1r1c|1r3c|",
        "|----|----|----|",
        "|2r2c|2r1c|2r3c|",
        "|3r2c|3r1c|3r3c|",
    })

    child.fn.cursor(1, 10)
    child.lua([[require('mdnotes.table').column_move_left()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    })
end

T['insert_row()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    local buf = create_md_buffer(child, lines)

    child.fn.cursor(4, 1)
    child.lua([[require('mdnotes.table').row_insert_below()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|    |    |    |",
        "|3r1c|3r2c|3r3c|",
    })

    child.lua([[require('mdnotes.table').row_insert_above()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|    |    |    |",
        "|2r1c|2r2c|2r3c|",
        "|    |    |    |",
        "|3r1c|3r2c|3r3c|",
    })
end

T['best_fit()'] = function()
    local lines = {
        "|1r1c   |1r2c   |1r3c |",
        "|----|----|----|",
        "|2r1c    |2r2c  |2r3c   |",
        "|3r1c  |3r2c   |3r3c   |",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[require('mdnotes.table').best_fit()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    })

    child.lua([[require('mdnotes').config.table_best_fit_padding = 1]])
    child.lua([[require('mdnotes.table').best_fit()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "| 1r1c | 1r2c | 1r3c |",
        "|------|------|------|",
        "| 2r1c | 2r2c | 2r3c |",
        "| 3r1c | 3r2c | 3r3c |",
    })
end

T['column_delete()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[require('mdnotes.table').column_delete()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r2c|1r3c|",
        "|----|----|",
        "|2r2c|2r3c|",
        "|3r2c|3r3c|",
    })
end

T['column_alignment_toggle()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[require('mdnotes.table').column_alignment_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|:---|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    })

    child.lua([[require('mdnotes.table').column_alignment_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|---:|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    })

    child.lua([[require('mdnotes.table').column_alignment_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|:--:|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    })

    child.lua([[require('mdnotes.table').column_alignment_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    })
end

T['column_duplicate()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[require('mdnotes.table').column_duplicate()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r1c|1r2c|1r3c|",
        "|----|----|----|----|",
        "|2r1c|2r1c|2r2c|2r3c|",
        "|3r1c|3r1c|3r2c|3r3c|",
    })
end

return T
