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

T['check_table_valid()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return require('mdnotes.table').check_table_valid()]])
    eq(ret.valid, true)
    eq(ret.startl, 1)
    eq(ret.endl, 4)

    lines = {
        "|1r1c|1r2c|1r3c|",
        "|2r1c|2r2c|2r3c|",
    }
    create_md_buffer(child, lines)

    ret = child.lua([[return require('mdnotes.table').check_table_valid()]])
    eq(ret.valid, false)
    eq(ret.startl, nil)
    eq(ret.endl, nil)
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

    require('mdnotes.table').write_table({
        buffer = 0,
        startl = 1,
        endl = #table_content,
        contents = table_content
    })
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
        "|    |    |    |",
        "|----|----|----|",
        "|    |    |    |",
    })
end

T['get_table_lines()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return require('mdnotes.table').get_table_lines(0,1,4)]])
    eq(ret, {
        {"1r1c","1r2c","1r3c"},
        {"----","----","----"},
        {"2r1c","2r2c","2r3c"},
        {"3r1c","3r2c","3r3c"},
    })
end

T['parse()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return require('mdnotes.table').parse()]])
    eq(ret.contents, {
        {"1r1c","1r2c","1r3c"},
        {"----","----","----"},
        {"2r1c","2r2c","2r3c"},
        {"3r1c","3r2c","3r3c"},
    })
    eq(ret.startl, 1)
    eq(ret.endl, 4)

    -- Check how duplicates are handled
    lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|2r1c|2r2c|2r3c|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    ret = child.lua([[return require('mdnotes.table').parse()]])
    eq(ret.contents, {
        {"1r1c","1r2c","1r3c"},
        {"----","----","----"},
        {"2r1c","2r2c","2r3c"},
        {"2r1c","2r2c","2r3c"},
        {"2r1c","2r2c","2r3c"},
        {"3r1c","3r2c","3r3c"},
    })
    eq(ret.startl, 1)
    eq(ret.endl, 6)
end

T['get_column_locations()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return require('mdnotes.table').get_column_locations()]])
    eq(ret, {
        {1, 6, 11, 16},
        {1, 6, 11, 16},
        {1, 6, 11, 16},
        {1, 6, 11, 16},
    })
end

T['convert_contents_to_complex()'] = function()
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
                text = "1r1c",
                start_col = 1,
                end_col = 6,
                lnum = 1,
            },
            {
                text = "1r2c",
                start_col = 6,
                end_col = 11,
                lnum = 1,
            },
            {
                text = "1r3c",
                start_col = 11,
                end_col = 16,
                lnum = 1,
            }
        },
        {
            {
                text = "----",
                start_col = 1,
                end_col = 6,
                lnum = 2,
            },
            {
                text = "----",
                start_col = 6,
                end_col = 11,
                lnum = 2,
            },
            {
                text = "----",
                start_col = 11,
                end_col = 16,
                lnum = 2,
            }
        },
        {
            {
                text = "2r1c",
                start_col = 1,
                end_col = 6,
                lnum = 3,
            },
            {
                text = "2r2c",
                start_col = 6,
                end_col = 11,
                lnum = 3,
            },
            {
                text = "2r3c",
                start_col = 11,
                end_col = 16,
                lnum = 3,
            }
        },
        {
            {
                text = "3r1c",
                start_col = 1,
                end_col = 6,
                lnum = 4,
            },
            {
                text = "3r2c",
                start_col = 6,
                end_col = 11,
                lnum = 4,
            },
            {
                text = "3r3c",
                start_col = 11,
                end_col = 16,
                lnum = 4,
            }
        }
    }

    local ret = child.lua([[
    local col_locs = require('mdnotes.table').get_column_locations()
    local tdata = require('mdnotes.table').parse()
    return require('mdnotes.table').convert_contents_to_complex(tdata.contents, col_locs)]])
    eq(ret, expected_table_complex)
end

T['get_cur_column_num()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return require('mdnotes.table').get_cur_column_num()]])
    eq(ret, 1)
end

T['column_insert()'] = function()
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

T['column_move()'] = function()
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

T['row_insert()'] = function()
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
        "|3r1c|3r2c|3r3c|",
        "|    |    |    |",
    })

    child.lua([[require('mdnotes.table').row_insert_above()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|    |    |    |",
        "|3r1c|3r2c|3r3c|",
        "|    |    |    |",
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

T['get_table_columns()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    local tdata = require('mdnotes.table').parse()
    return require('mdnotes.table').get_table_columns(tdata.contents)]])
    eq(ret, {
        {"1r1c", "----", "2r1c", "3r1c"},
        {"1r2c", "----", "2r2c", "3r2c"},
        {"1r3c", "----", "2r3c", "3r3c"},
    })
end

T['column_sort()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|4r1c|3r2c|3r3c|",
        "|2r1c|2r2c|2r3c|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    local buf = create_md_buffer(child, lines)

    -- Ascending
    child.lua([[
    local tdata = require('mdnotes.table').parse()
    tdata.contents = require('mdnotes.table').column_sort(tdata.contents, 1, function(a, b) return a < b end)
    require('mdnotes.table').write_table(tdata)
    ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
        "|4r1c|3r2c|3r3c|",
    })

    -- Descending
    child.lua([[
    local tdata = require('mdnotes.table').parse()
    tdata.contents = require('mdnotes.table').column_sort(tdata.contents, 1, function(a, b) return a > b end)
    require('mdnotes.table').write_table(tdata)
    ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|4r1c|3r2c|3r3c|",
        "|3r1c|3r2c|3r3c|",
        "|2r1c|2r2c|2r3c|",
        "|2r1c|2r2c|2r3c|",
    })
end

T['parse_columns_to_lines()'] = function()
    local lines = {
        "|1r1c|1r2c|1r3c|",
        "|----|----|----|",
        "|2r1c|2r2c|2r3c|",
        "|3r1c|3r2c|3r3c|",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    local tdata = require('mdnotes.table').parse()
    local table = require('mdnotes.table').get_table_columns(tdata.contents)
    return require('mdnotes.table').parse_columns_to_lines(table)
    ]])
    eq(ret, {
        {"1r1c","1r2c","1r3c"},
        {"----","----","----"},
        {"2r1c","2r2c","2r3c"},
        {"3r1c","3r2c","3r3c"},
    })
end

return T
