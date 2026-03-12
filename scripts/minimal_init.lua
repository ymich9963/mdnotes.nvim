-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- Set up 'mini.test' only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() == 0 then
    -- Add 'mini.test' to 'runtimepath' to be able to use 'mini.test'
    -- Assumed that 'mini.test' is cloned in a known path
    local mini_path
    if vim.fn.isdirectory("deps/mini.test") == 1 then
        -- This is used for CI
        mini_path = "deps/mini.test"
    else
        -- This is used when developing
        mini_path = vim.fs.normalize(vim.fn.stdpath('data') .. '/lazy/mini.test')
    end

    vim.cmd('set rtp+=' .. mini_path)

    -- Set up 'mini.test'
    require('mini.test').setup({ execute = { stop_on_error = true, }, })
end
