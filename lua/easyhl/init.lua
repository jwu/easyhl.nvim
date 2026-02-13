---@class EasyHL
---@field setup function
---@field highlight_word function
---@field highlight_text function
---@field highlight_range function
---@field clear function
---@field clear_all function
---@field get_hl_text function

local M = {}

---Setup configuration
---@param opts? easyhl.Config
M.setup = require('easyhl.config').setup

---Highlight word under cursor
---@param label number 1-4
M.highlight_word = require('easyhl.highlight').highlight_word

---Highlight text with pattern
---@param label number 1-4
---@param pattern string
M.highlight_text = require('easyhl.highlight').highlight_text

---Highlight visual selection range
---@param label number 1-4
M.highlight_range = require('easyhl.highlight').highlight_range

---Clear highlight for a label
---@param label number 0-4 (0 = clear all)
M.clear = require('easyhl.highlight').clear

---Clear all highlights
M.clear_all = require('easyhl.highlight').clear_all

---Get current highlight text for a label
---@param label number 1-4
---@return string|nil
M.get_hl_text = require('easyhl.highlight').get_hl_text

return M
