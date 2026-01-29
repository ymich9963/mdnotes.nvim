# Mdnotes Rationale
In this document I explain certain design decisions for `mdnotes` and how they differ from an Obsidian-like approach.

## Using Current File's Directory
In most note-taking apps, the notes directory is designated within its options or configuration. I chose to use the current file's directory in `mdnotes` for the following reasons,

- No configuration needed so you can create wikis anywhere on any machine
- Easily create small local wikis
- WikiLinks or inline links are directly linked to the file's location, which works like a filesystem
- Functionality like global rename, backlinks, etc. are scoped to the current file's directory

Essentially the plugin treats a directory as a namespace, instead of using a vault model.
