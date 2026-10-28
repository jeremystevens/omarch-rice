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
}
