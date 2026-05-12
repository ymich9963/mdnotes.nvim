# 📢 Supported Markdown Formatting
Here is the supported Markdown formatting for `mdnotes.nvim`. The plugin tries to adhere to the [CommonMark](https://spec.commonmark.org/) and [GitHub Flavoured Markdown (GFM)](https://github.github.com/gfm/) spec as well as providing WikiLink support. If any problems arise please don't hesitate to create an issue for it!
## Links
Opened with `:Mdn inline_link open`. Inserted with the `:Mdn assets insert_file/image` and `:Mdn inline_link toggle` commands. If no extension is given to `file` below, it is treated as `.md`.
```
    [link](https://neovim.io)
    [link](path/to/file#fragment)
    [link](path/to/file#GFM Style Fragment Wth Spaces)
    [link](path/to/file#gfm-style-fragment-wth-spaces)
    [link](<path/to/file with spaces.md#fragment>)
    [link](#Original Fragment)
    [link](#original-fragment)
    [link](path/to/file.extension)
    ![image](path/to/image.extension)
```
## WikiLinks
Opened with `:Mdn wikilink follow`. Can only be filenames, so `link` can also be `link.md`.
```
    [[link]]
    [[link#fragment]]
    [[link#fragment with spaces]]
    [[link#fragment-with-spaces]]
    [[link|alias]]
    [[link#fragment-with-spaces|alias]]
    [[link#fragment with spaces|alias]]
```
## Formatting
Toggled with `:Mdn formatting <format>_toggle`. Using `_` for the strong and emphasis formats needs to be specified in the `strong_format` and `emphasis_format` config options. The ***strong emphasis*** format can be done by first applying `emphasis` and then `strong`.
```
    **strong**
    __strong__
    *emphasis*
    _emphasis_
    ~~strikethrough~~
    `inline code`
    <autolink>
```
## Lists
All ordered and unordered CommonMark lists along with GFM task lists are supported.
```
    - Item
    + Item
    * Item
    1) Item
    2. Item
    - [x] Task lists with all ordered and unordered lists above
```
## Tables
The GFM table specification is supported.
```
|1r1c|1r2c|1r3c|
|----|----|----|
|2r1c|2r2c|2r3c|
|3r1c|3r2c|3r3c|
```

