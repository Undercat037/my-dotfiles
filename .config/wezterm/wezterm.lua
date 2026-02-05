local wezterm = require('wezterm')
local config = wezterm.config_builder()
local colors = require('colors')
config.colors = colors
return config
