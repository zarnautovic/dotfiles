-- PHP formatting + linting.
-- The LazyVim `lang.php` extra already gives us Intelephense (LSP) + treesitter.
-- This adds the missing pieces: a formatter and a static analyzer, wired into
-- LazyVim's existing conform.nvim / nvim-lint, with the tools auto-installed by Mason.
return {
  -- Format PHP with php-cs-fixer (general-purpose; picks up .php-cs-fixer.dist.php if present).
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        php = { "php_cs_fixer" },
      },
    },
  },

  -- Lint PHP with PHPStan (picks up phpstan.neon from the project root if present).
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        php = { "phpstan" },
      },
    },
  },

  -- Auto-install the PHP tools. list_extend so we don't clobber other ensure_installed entries.
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "php-cs-fixer", "phpstan" })
    end,
  },
}
