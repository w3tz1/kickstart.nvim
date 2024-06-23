-- This is the same as in lspconfig.server_configurations.jdtls, but avoids
-- needing to require that when this module loads.
local java_filetypes = { 'java' }

return {
  -- Add java to treesitter.
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { 'java' })
    end,
  },

  -- Configure nvim-lspconfig to install the server automatically via mason, but
  -- defer actually starting it to our configuration of nvim-jtdls below.
  {
    'neovim/nvim-lspconfig',
    opts = {
      -- make sure mason installs the server
      servers = {
        jdtls = {},
      },
      setup = {
        jdtls = function()
          return true -- avoid duplicate servers
        end,
      },
    },
  },

  -- Set up nvim-jdtls to attach to java files.
  {
    'mfussenegger/nvim-jdtls',
    dependencies = { 'folke/which-key.nvim' },
    ft = java_filetypes,
    opts = function()
      return {
        -- How to find the root dir for a given filename. The default comes from
        -- lspconfig which provides a function specifically for java projects.
        root_dir = require('lspconfig.server_configurations.jdtls').default_config.root_dir,

        -- How to find the project name for a given root dir.
        project_name = function(root_dir)
          return root_dir and vim.fs.basename(root_dir)
        end,

        -- Where are the config and workspace dirs for a project?
        jdtls_config_dir = function(project_name)
          return vim.fn.stdpath 'cache' .. '/jdtls/' .. project_name .. '/config'
        end,
        jdtls_workspace_dir = function(project_name)
          return vim.fn.stdpath 'cache' .. '/jdtls/' .. project_name .. '/workspace'
        end,

        -- How to run jdtls. This can be overridden to a full java command-line
        -- if the Python wrapper script doesn't suffice.
        cmd = { vim.fn.exepath 'jdtls' },
        full_cmd = function(opts)
          local fname = vim.api.nvim_buf_get_name(0)
          local root_dir = opts.root_dir(fname)
          local project_name = opts.project_name(root_dir)
          local cmd = vim.deepcopy(opts.cmd)
          if project_name then
            vim.list_extend(cmd, {
              '-configuration',
              opts.jdtls_config_dir(project_name),
              '-data',
              opts.jdtls_workspace_dir(project_name),
            })
          end
          return cmd
        end,
      }
    end,
    config = function()
      -- Attach the jdtls for each java buffer. HOWEVER, this plugin loads
      -- depending on filetype, so this autocmd doesn't run for the first file.
      -- For that, we call directly below.
      vim.api.nvim_create_autocmd('FileType', {
        pattern = java_filetypes,
      })

      -- Setup keymap and dap after the lsp is fully attached.
      -- https://github.com/mfussenegger/nvim-jdtls#nvim-dap-configuration
      -- https://neovim.io/doc/user/lsp.html#LspAttach
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == 'jdtls' then
            local wk = require 'which-key'
            wk.register({
              ['<leader>cx'] = { name = '+extract' },
              ['<leader>cxv'] = { require('jdtls').extract_variable_all, 'Extract Variable' },
              ['<leader>cxc'] = { require('jdtls').extract_constant, 'Extract Constant' },
              ['gs'] = { require('jdtls').super_implementation, 'Goto Super' },
              ['gS'] = { require('jdtls.tests').goto_subjects, 'Goto Subjects' },
              ['<leader>co'] = { require('jdtls').organize_imports, 'Organize Imports' },
            }, { mode = 'n', buffer = args.buf })
            wk.register({
              ['<leader>c'] = { name = '+code' },
              ['<leader>cx'] = { name = '+extract' },
              ['<leader>cxm'] = {
                [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]],
                'Extract Method',
              },
              ['<leader>cxv'] = {
                [[<ESC><CMD>lua require('jdtls').extract_variable_all(true)<CR>]],
                'Extract Variable',
              },
              ['<leader>cxc'] = {
                [[<ESC><CMD>lua require('jdtls').extract_constant(true)<CR>]],
                'Extract Constant',
              },
            }, { mode = 'v', buffer = args.buf })
          end
        end,
      })
    end,
  },
}
