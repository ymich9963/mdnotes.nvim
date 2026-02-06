---
name: Bug report
about: You found a bug in mdnotes
title: "\U0001F41E "
labels: bug
assignees: ymich9963

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behaviour:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Minimal Config Test**
Does it also happen with a minimal plugin config? 

Use the following code snippet in a `minit.lua` file and start Neovim with `nvim -u minit.lua`.
```lua
vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

require("lazy.minit").repro({
    spec = {
        {
            "ymich9963/mdnotes"
            -- also put any issue related setup here
        }
    }
})
```

**Expected behaviour**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Version Info:**
 - OS: [e.g. Windows XP]
 - Neovim: [e.g. 0.1.0]

**Additional context**
Add any other context about the problem here.
