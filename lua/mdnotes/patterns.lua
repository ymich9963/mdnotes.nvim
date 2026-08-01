---@module 'mdnotes.patterns'

local M = {}

---@alias MdnPattern string Lua pattern that returns the start and end columns, as well as the text

---@class MdnPatterns
---@field wikilink MdnPattern WikiLink pattern
---@field inline_link MdnPattern Inline link pattern
---@field strong MdnPattern Strong format delimiter pattern
---@field emphasis MdnPattern Emphasis format delimiter pattern
---@field strikethrough MdnPattern Strikethrough format delimiter pattern
---@field inline_code MdnPattern Inline code format delimiter pattern
---@field autolink MdnPattern Autolink format delimiter pattern
---@field text_dest string Text and destination from inline link pattern
---@field dest_title string Title from inline link destination
---@field dest_no_fragment string destination only pattern
---@field fragment string Fragment only pattern
---@field wikilink_alias string WikiLink alias
---@field unordered_list string Unordered list pattern
---@field ordered_list string Ordered list pattern
---@field task string Task item pattern
---@field heading string Heading pattern
M = {
    wikilink = "()(%[%[.-%]%])()",
    inline_link = "()([!]?%[[^%]]+%]%([^%)]+%))()",
    strong = "()[%*_][%*_]([^%*_].-)[%*_][%*_]()",
    emphasis = "()[%*_]([^%*_].-)[%*_]()",
    strikethrough = "()~~(.-)~~()",
    inline_code = "()`([^`]+)`()",
    autolink = "()<(.-)>()",
    reference_link = "()(%[[^%]]+%]%[[^%]]-%])()",

    heading = "^([%#]+)[%s]+(.+)",
    unordered_list = "^([%s]-)([-+*])[%s](.*)",
    ordered_list = "^([%s]-)([%d]+)([%.%)])[%s](.*)",
    reference_link_definition = "^%[([^%]]+)%]:%s?(.+)",
    code_fence = "^```.-",

    text_dest = "%[([^%]]+)%]%((.+)%)",
    dest_title = ".+%s\"([^\"]*)\"",
    dest_no_fragment = "^([^#]+).*",
    fragment = "#([^|]*)",
    wikilink_contents = "%[%[(.-)%]%]",
    wikilink_alias = ".+|([^|]+)",
    task = "[%s]-(%[[ xX]%])[%s]+.-",
    text_label = "%[([^%]]+)%]%[(.-)%]",
}

return M
