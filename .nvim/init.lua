local user = require "user"

user.lsp {
    server_runtime_config = {
        lua_ls = {
            load_extra_plugins = {
                __append = true,
                "oil.nvim"
            },
        },
    },
}
