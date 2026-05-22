local gh = require('utils').gh

vim.pack.add { gh 'MunifTanjim/nui.nvim' }
vim.pack.add { { src = gh 'nvim-java/nvim-java', version = 'v4.1.0' } }
vim.pack.add { { src = gh 'nvim-java/lua-async-await', version = 'v1.1.0' } }
vim.pack.add { { src = gh 'nvim-java/nvim-java-core', version = 'v2.0.0' } }
vim.pack.add { { src = gh 'nvim-java/nvim-java-test', version = 'v1.0.1' } }
vim.pack.add { { src = gh 'nvim-java/nvim-java-dap', version = 'v1.0.0' } }
vim.pack.add { gh 'JavaHello/spring-boot.nvim' }

require('java').setup {}