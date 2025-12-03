local M = {}

local bold_char = require('mdnotes').bold_char
local italic_char = require('mdnotes').italic_char

M = {
    wikilink = "()%[%[(.-)%]%]()",
    file_section = "([^#]+)#?(.*)",
    hyperlink = "()(%[[^%]]+%]%([^%)]+%)())",
    text_link = "%[([^%]]+)%]%(([^%)]+)%)",
    bold = "()%" .. bold_char .. "%" .. bold_char .. "([^%" .. bold_char .. "].-)%" .. bold_char .. "%" .. bold_char .. "()",
    italic = "()%" .. italic_char .. "([^%" .. italic_char .. "].-)%" .. italic_char .."()",
    strikethrough = "()~~(.-)~~()",
    inline_code = "()`([^`]+)`()",
    unordered_list = "^([%s]-)([-+*])[%s](.+)",
    ordered_list = "^([%s]-)([%d]+)([%.%)])[%s]-(.+)",
    task = "[%s]-(%[[ xX]%])[%s].-",
    heading = "^([%#]+)[%s]+(.+)",
}

return M
