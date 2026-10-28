-- NEXUS developer additions on top of LazyVim's language extras
-- (typescript, json, python, yaml, markdown, prettier, eslint, dap.core are
-- enabled in lazyvim.json). This file covers what those extras don't:
-- shell scripts, HTML and CSS. shellcheck and shfmt come from mise (on PATH),
-- so Mason does not install second copies.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = { filetypes = { "sh", "bash" } },
        html = {},
        cssls = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "bash-language-server",
        "html-lsp", "css-lsp",
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
        bash = { "shfmt" },
        -- ruff directly, so formatting doesn't depend on the LSP being attached.
        python = { "ruff_organize_imports", "ruff_format" },
      },
      formatters = {
        -- 2-space indent, indent switch cases, binary ops at line start.
        shfmt = { prepend_args = { "-i", "2", "-ci", "-bn" } },
      },
    },
  },
  {
    -- NEXUS Resume reopens nvim with this plugin's session for the folder.
    -- LazyVim saves it only when nvim quits cleanly; also save while working
    -- (when a file is opened or written) so a logout or crash keeps the list
    -- of open files. Unsaved changes are not part of a session.
    "folke/persistence.nvim",
    init = function()
      local loading = false
      local group = vim.api.nvim_create_augroup("nexus_persistence", { clear = true })
      vim.api.nvim_create_autocmd("User", { group = group, pattern = "PersistenceLoadPre", callback = function() loading = true end })
      vim.api.nvim_create_autocmd("User", { group = group, pattern = "PersistenceLoadPost", callback = function() loading = false end })
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = group,
        callback = function(ev)
          if loading or vim.bo[ev.buf].buftype ~= "" or vim.api.nvim_buf_get_name(ev.buf) == "" then return end
          vim.schedule(function()
            local ok, p = pcall(require, "persistence")
            if ok and p.active() then pcall(p.save) end
          end)
        end,
      })
    end,
  },
}
