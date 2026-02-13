local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

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
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['get_files_in_cwd()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes').get_files_in_cwd(".md")
    ]])
    eq(ret, {"file1.md", "file2.md", "file3.md", "file4.md", "file5.md", "file6.md", "file7.md"})

    ret = child.lua([[
    return require('mdnotes').get_files_in_cwd(nil, false, "directory")
    ]])
    eq(ret, {"assets"})

    ret = child.lua([[
    return require('mdnotes').get_files_in_cwd(".md", false, "file", "^.*7.*")
    ]])
    eq(ret, {"file7.md"})
end

return T
