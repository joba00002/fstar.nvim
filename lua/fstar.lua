local status = require("status")
local M = {}

local status_displayers = {}

local uri_to_bufnr = function(uri)
    return vim.fn.bufadd(vim.uri_to_fname(uri))
end

local get_position = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    return {
        line = pos[1]-1,
        character = pos[2],
    }
end

local setup_lsp = function (fstar_lsp_path, namespace_id)
    local my_bufnr = vim.api.nvim_get_current_buf()
    status_displayers[my_bufnr] = status.StatusDisplayer:new(namespace_id, my_bufnr)
    vim.lsp.start({
        cmd = { fstar_lsp_path },
        root_dir = vim.fn.getcwd(), -- Use PWD as project root dir.
        handlers = {
            ["fstar-lsp/clearStatus"] = vim.lsp.with(
                function(err, result, ctx, config)
                    local bufnr = uri_to_bufnr(result.uri)
                    status_displayers[bufnr]:clear()
                    return { success = true }
                end,
            {}),

            ["fstar-lsp/setStatus"] = vim.lsp.with(
                function(err, result, ctx, config)
                    local bufnr = uri_to_bufnr(result.uri)
                    status_displayers[bufnr]:set_status(result.range.start.line, result.range["end"].line, result.statusType)
                    return { success = true }
                end,
            {}),
        }
    })
end

local fstar_verify_all = function()
    for _, client in ipairs(vim.lsp.get_active_clients({bufnr = 0})) do
        client.notify("fstar-lsp/verifyAll", {
            textDocument = vim.lsp.util.make_text_document_params()
        })
    end
end

local fstar_lax_to_position = function()
    for _, client in ipairs(vim.lsp.get_active_clients({bufnr = 0})) do
        client.notify("fstar-lsp/laxToPosition", {
            textDocument = vim.lsp.util.make_text_document_params(),
            position = get_position(),
        })
    end
end

local fstar_verify_to_position = function()
    for _, client in ipairs(vim.lsp.get_active_clients({bufnr = 0})) do
        client.notify("fstar-lsp/verifyToPosition", {
            textDocument = vim.lsp.util.make_text_document_params(),
            position = get_position(),
        })
    end
end

local fstar_cancel_all = function()
    for _, client in ipairs(vim.lsp.get_active_clients({bufnr = 0})) do
        client.notify("fstar-lsp/cancelAll", {
            textDocument = vim.lsp.util.make_text_document_params()
        })
    end
end

local fstar_reload_dependencies = function()
    for _, client in ipairs(vim.lsp.get_active_clients({bufnr = 0})) do
        client.notify("fstar-lsp/reloadDependencies", {
            textDocument = vim.lsp.util.make_text_document_params()
        })
    end
end


local setup_fstar_command = function ()
    vim.api.nvim_buf_create_user_command(0, 'FStar',
        function(input)
            if input.fargs[1] == "verify_all" then
                fstar_verify_all()
            end
            if input.fargs[1] == "lax_to_position" then
                fstar_lax_to_position()
            end
            if input.fargs[1] == "verify_to_position" then
                fstar_verify_to_position()
            end
            if input.fargs[1] == "cancel_all" then
                fstar_cancel_all()
            end
            if input.fargs[1] == "reload_dependencies" then
                fstar_reload_dependencies()
            end
        end,
        {
            desc = "Communicate with F* LSP",
            nargs = 1,
            complete = function(ArgLead, CmdLine, CursorPos)
                return { "verify_all", "lax_to_position", "verify_to_position", "cancel_all", "reload_dependencies" }
            end,
        }
    )
end

M.setup = function(cfg)
    local namespace_id = vim.api.nvim_create_namespace("fstar.nvim")
    vim.api.nvim_set_hl_ns(namespace_id)

    vim.api.nvim_set_hl(namespace_id, "FullyChecked", {
        bg = cfg.colors.fully_checked,
    })
    vim.api.nvim_set_hl(namespace_id, "LaxChecked", {
        bg = cfg.colors.lax_checked,
    })
    vim.api.nvim_set_hl(namespace_id, "InProgress", {
        bg = cfg.colors.in_progress,
    })
    -- Is this highlight useful?
    vim.api.nvim_set_hl(namespace_id, "Scheduled", {
        bg = cfg.colors.scheduled,
    })

    vim.filetype.add({
        extension = {
            fst = "fstar",
            fsti = "fstar",
        }
    })

    vim.api.nvim_create_autocmd({"FileType"}, {
        pattern = {"fstar"},
        callback = function()
            setup_lsp(cfg.fstar_lsp_path, namespace_id)
            setup_fstar_command()
        end,
    })
end

return M
