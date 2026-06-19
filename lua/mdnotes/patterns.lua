---@module 'mdnotes.patterns'

local M = {}

---@alias MdnPattern string Lua pattern that returns the start and end columns, as well as the text

---@class MdnPatterns
---@field wikilink MdnPattern WikiLink pattern
---@field inline_link MdnPattern Inline link pattern
---@field strong MdnPattern Strong format indicator pattern
---@field emphasis MdnPattern Emphasis format indicator pattern
---@field strikethrough MdnPattern Strikethrough format indicator pattern
---@field inline_code MdnPattern Inline code format indicator pattern
---@field autolink MdnPattern Autolink format indicator pattern
---@field text_uri string Text and URI from inline link pattern
---@field uri_title string Title from inline link URI
---@field uri_no_fragment string URI only pattern
---@field fragment string Fragment only pattern
---@field wikilink_alias string WikiLink alias
---@field unordered_list string Unordered list pattern
---@field ordered_list string Ordered list pattern
---@field task string Task item pattern
---@field heading string Heading pattern
M = {
    wikilink = "()%[%[(.-)%]%]()",
    inline_link = "()([!]?%[[^%]]+%]%([^%)]+%))()",
    strong = "()[%*_][%*_]([^%*_].-)[%*_][%*_]()",
    emphasis = "()[%*_]([^%*_].-)[%*_]()",
    strikethrough = "()~~(.-)~~()",
    inline_code = "()`([^`]+)`()",
    autolink = "()<(.-)>()",

    text_uri = "%[([^%]]+)%]%((.+)%)",
    uri_title = ".+%s\"([^\"]*)\"",
    uri_no_fragment = "^([^#]+).*",
    fragment = "#([^|]*)",
    wikilink_alias = ".+|([^|]+)",
    unordered_list = "^([%s]-)([-+*])[%s](.*)",
    ordered_list = "^([%s]-)([%d]+)([%.%)])[%s](.*)",
    task = "[%s]-(%[[ xX]%])[%s]+.-",
    heading = "^([%#]+)[%s]+(.+)",
}

return M
