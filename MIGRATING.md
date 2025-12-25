# Migrating
`mdnotes` strides to adhere to the CommonMark and GFM Markdown specs to ensure that your notes are as readably and pretty everywhere. If coming from other apps like Obsidian, Logseq, or Zettlr, then you may need to modify certain things so that they adhere to the spec `mdnotes` expects. For example, asset paths might have the `./` current directory specified or if coming from Windows you might notice how they use `\` instead of `/`. Logseq for example adds bullet points to every page at every paragraph, and does not care about spaces in asset links. This is also the same case for Zettlr. Obsidian follows the specification quite closely from what I've tested so only minor changes would have to be done when migrating.

Therefore I've made a list below of the small amount of changes you may need to do when migrating to `mdnotes`.

- Asset paths must have `/`.
- Links to files or sections with spaces must be enclosed in `<`/`>` like this `[example](<path/to/file name with spaces.md>)`.
- WikiLinks can only be file names. 

The first two points can be fixed by running the `:Mdn inline_link normalize` command on every reference of your asset folder in your notes. For example if your folder is called `assets` you can use `:h vimgrep` and then execute `:h cdo` on the resulting quickfix list. An example command would be,
```vim
:vimgrep /assets/ **
```
The command above would search for your assets folder in the current directory and all subdirectories. Then after inspecting the quickfix results are correct, execute the following command to normalise the assets file path,
```vim
:cdo Mdn inline_link normalize
```
See `:h Mdn-inline_link-normalize` for what the command does, but executing the above will essentially, change `.\assets\` to `./assets/`, change `.\assets\` to `assets/`, change `./assets/` to `assets/`.
