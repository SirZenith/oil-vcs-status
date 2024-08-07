local user = require "user"

user.lsp = {
    __newentry = true,
    load_extra_plugins = {
        __append = true,
        "oil.nvim"
    }
}
