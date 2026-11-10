-- ============================================================================
--  CMake projects (cmake-tools.nvim). Start Neovim in the project's root
--  folder (where CMakeLists.txt is). F7 / F5 / Ctrl+F5 use it automatically.
--
--  <leader>mg  configure (cmake -S . -B build/<type>)    <leader>mb  build      (F7)
--  <leader>mt  build type: Debug / Release / …           <leader>mr  run        (Ctrl+F5)
--  <leader>ms  which target to build                     <leader>md  debug      (F5)
--  <leader>ml  which target to run / debug               <leader>mT  run tests (ctest)
--  <leader>ma  arguments / env for the launch target     <leader>mc  clean
--  <leader>mp  configure preset (CMakePresets.json)      <leader>mx  stop the running build
--
--  compile_commands.json is linked into the project root after every configure,
--  so clangd knows every flag and include path. Builds use Ninja and ccache
--  when installed (install.sh), and all 8 cores.
-- ============================================================================
local function cmd(c) return '<cmd>' .. c .. '<CR>' end

return {
  'Civitasv/cmake-tools.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  ft = { 'cmake' },
  cmd = {
    'CMakeGenerate', 'CMakeBuild', 'CMakeRun', 'CMakeDebug', 'CMakeRunTest', 'CMakeClean', 'CMakeInstall',
    'CMakeSelectBuildType', 'CMakeSelectBuildTarget', 'CMakeSelectLaunchTarget', 'CMakeSelectConfigurePreset',
    'CMakeSelectBuildPreset', 'CMakeSelectKit', 'CMakeLaunchArgs', 'CMakeTargetSettings', 'CMakeSettings',
    'CMakeStopExecutor', 'CMakeStopRunner', 'CMakeOpenExecutor', 'CMakeOpenRunner', 'CMakeShowTargetFiles',
    'CMakeQuickBuild', 'CMakeQuickRun', 'CMakeQuickDebug',
  },
  init = function()
    -- started inside a CMake project: load right after startup, so the
    -- statusline shows the build type / target from the beginning
    if vim.uv.fs_stat(vim.uv.cwd() .. '/CMakeLists.txt') then
      vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        once = true,
        callback = function() require('lazy').load({ plugins = { 'cmake-tools.nvim' } }) end,
      })
    end
  end,
  keys = {
    { '<leader>mg', cmd('CMakeGenerate'), desc = 'CMake: configure' },
    { '<leader>mt', cmd('CMakeSelectBuildType'), desc = 'CMake: build type' },
    { '<leader>ms', cmd('CMakeSelectBuildTarget'), desc = 'CMake: build target' },
    { '<leader>ml', cmd('CMakeSelectLaunchTarget'), desc = 'CMake: launch target' },
    { '<leader>ma', cmd('CMakeTargetSettings'), desc = 'CMake: launch target arguments / env' },
    { '<leader>mp', cmd('CMakeSelectConfigurePreset'), desc = 'CMake: configure preset' },
    { '<leader>mT', cmd('CMakeRunTest'), desc = 'CMake: run tests (ctest)' },
    { '<leader>mc', cmd('CMakeClean'), desc = 'CMake: clean' },
    { '<leader>mx', cmd('CMakeStopExecutor'), desc = 'CMake: stop build' },
    { '<leader>mo', cmd('CMakeOpenExecutor'), desc = 'CMake: show build output' },
  },
  opts = function()
    -- Read by CMake when it creates a *new* build folder; existing folders keep
    -- the generator / launcher they were configured with, so nothing breaks.
    if vim.fn.executable('ninja') == 1 and not vim.env.CMAKE_GENERATOR then vim.env.CMAKE_GENERATOR = 'Ninja' end
    if vim.fn.executable('ccache') == 1 then
      vim.env.CMAKE_C_COMPILER_LAUNCHER = vim.env.CMAKE_C_COMPILER_LAUNCHER or 'ccache'
      vim.env.CMAKE_CXX_COMPILER_LAUNCHER = vim.env.CMAKE_CXX_COMPILER_LAUNCHER or 'ccache'
    end
    vim.env.CMAKE_BUILD_PARALLEL_LEVEL = vim.env.CMAKE_BUILD_PARALLEL_LEVEL or tostring(vim.uv.available_parallelism())

    return {
      cmake_build_directory = 'build/${variant:buildType}',
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' },
      cmake_regenerate_on_save = true, -- saving CMakeLists.txt re-configures
      cmake_compile_commands_options = { action = vim.fn.has('win32') == 1 and 'copy' or 'soft_link', target = vim.uv.cwd },
      cmake_dap_configuration = { -- CMakeDebug -> gdb (see lua/plugins/debug.lua)
        name = 'cpp',
        type = vim.g.is_win and 'codelldb' or 'gdb',
        request = 'launch',
        stopAtBeginningOfMainSubprogram = false,
        runInTerminal = false,
      },
      -- build output in the quickfix list; it closes itself when the build succeeds
      cmake_executor = { name = 'quickfix', opts = { show = 'always', auto_close_when_success = true } },
      -- the program runs in a terminal split at the bottom
      cmake_runner = { name = 'terminal', opts = { split_size = 12 } },
      cmake_virtual_text_support = false,
    }
  end,
}
