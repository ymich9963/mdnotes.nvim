# Migrating
`mdnotes` strides to adhere to the CommonMark and GFM Markdown specs to ensure that your notes are as readably and pretty everywhere. If coming from other apps like Obsidian, Logseq, or Zettlr, then you may need to modify certain things so that they adhere to the spec `mdnotes` expects. For example, asset paths might have the `./` current directory specified or if coming from Windows you might notice how they use `\` instead of `/`. Logseq for example adds bullet points to every page at every paragraph, and does not care about spaces in asset links. This is also the same case for Zettlr. Obsidian follows the specification quite closely from what I've tested so only minor changes would have to be done when migrating.

Therefore I've made a list below of the small amount of changes you may need to do when migrating to `mdnotes`.

- Asset paths must have `/`.
- Links to files or sections with spaces must be enclosed in `<`/`>` like this `[example](<path/to/file name with spaces.md>)`.
- WikiLinks can only be file names. 

To change your asset path you can use `:h vimgrep` and then execute `:h cdo` on the resulting quickfix list. See example commands below, and remember to backup your data before executing destructive commands,

- Change `.\assets\` to `./assets/`
```
vimgrep /\.\\assets\\/ *
cdo s/\.\\assets\\/\.\/assets\//g
```

- Change `.\assets\` to `assets/`
```
vimgrep /\.\\assets\\/ *
cdo s/\.\\assets\\/assets\//g
```

- Change `./assets/` to `assets/`
```
vimgrep /\.\/assets\// *
cdo s/\.\/assets\//assets\//g
```

- Change all `\)` to `/)`
```
vimgrep /\\)/ *
cdo s/\\)/\/)/g
```

