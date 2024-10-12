local M = {}

---@class Tip.config
---@field seconds number
---@field title string
---@field url string

---@type Tip.config
M.config = {
  seconds = 2,
  title = 'Tip!',
}

---@param params Tip.config
M.setup = function(params)
  M.config = vim.tbl_deep_extend('force', {}, M.config, params or {})
  vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
      local xml2lua = require 'xml2lua'
      local handler = require 'xmlhandler.tree'
      local http_request = require 'http.request'
      local headers, stream = assert(http_request.new_from_uri('https://www.tcmb.gov.tr/kurlar/today.xml'):go())
      local body = assert(stream:get_body_as_string())
      if headers:get ':status' ~= '200' then
        error(body)
      end

      local parser = xml2lua.parser(handler)
      parser:parse(body)

      local currencies = {}

      for _, p in pairs(handler.root.Tarih_Date.Currency) do
        local code = p._attr.CurrencyCode
        local obj = {}
        obj['buy'] = p.ForexBuying
        obj['code'] = code
        currencies[code] = obj
      end

      local async = require 'plenary.async'
      local sender, receiver = async.control.channel.mpsc()

      async.run(function()
        local arr = { currencies['USD'], currencies['EUR'] }
        for i = 1, 2 do
          sender.send(arr[i])
        end
      end)

      for _ = 1, 2 do
        local value = receiver.recv()
        local buy = value.buy
        local code = value.code
        pcall(vim.notify, buy, M.config.seconds, { title = code })
      end
    end,
  })
end

return M
