--[[
Copyright (c) 2017, Vsevolod Stakhov <vsevolod@highsecure.ru>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
]]--

local exports = {}

local function rspamd_map_add_from_ucl(opt, mtype, description)
  local ret = {
    get_key = function(t, k)
      if t.__data then
        return t.__data:get_key(k)
      end

      return nil
    end
  }
  local ret_mt = {
    __index = function(t, k)
      if t.__data then
        return t.get_key(k)
      end

      return nil
    end
  }

  if not opt then
    return nil
  end

  if type(opt) == 'string' then
    -- We have a single string, so we treat it as a map
    local map = rspamd_config:add_map{
      type = mtype,
      description = description,
      url = opt,
    }

    if map then
      ret.__data = map
      setmetatable(ret, ret_mt)
      return ret
    end
  elseif type(opt) == 'table' then
    -- it might be plain map or map of plain elements
    if opt[1] then
      if mtype == 'radix' then

        if string.find(opt[1], '^%d') then
          local map = rspamd_config:radix_from_ucl(opt)

          if map then
            ret.__data = map
            setmetatable(ret, ret_mt)
            return ret
          end
        else
          -- Plain table
          local map = rspamd_config:add_map{
            type = mtype,
            description = description,
            url = opt,
          }
          if map then
            ret.__data = map
            setmetatable(ret, ret_mt)
            return ret
          end
        end
      elseif mtype == 'regexp' then
        -- Plain table
        local map = rspamd_config:add_map{
          type = mtype,
          description = description,
          url = opt,
        }
        if map then
          ret.__data = map
          setmetatable(ret, ret_mt)
          return ret
        end
      else
        if string.find(opt[1], '^/%a') or string.find(opt[1], '^http') then
          -- Plain table
          local map = rspamd_config:add_map{
            type = mtype,
            description = description,
            url = opt,
          }
          if map then
            ret.__data = map
            setmetatable(ret, ret_mt)
            return ret
          end
        else
          local data = {}
          local nelts = 0
          for _,elt in ipairs(opt) do
            if type(elt) == 'string' then
              data[elt] = true
              nelts = nelts + 1
            end
          end

          if nelts > 0 then
            ret.__data = data
            ret.get_key = function(t, k)
              if k ~= '__data' then
                return t.__data[k]
              end

              return nil
            end
            return ret
          end
        end
      end
    else
      local map = rspamd_config:add_map{
        type = mtype,
        description = description,
        url = opt,
      }
      if map then
        ret.__data = map
        setmetatable(ret, ret_mt)
        return ret
      end
    end
  end

  return nil
end

local function rspamd_map_add(mname, optname, mtype, description)
  local opt = rspamd_config:get_module_opt(mname, optname)

  return rspamd_map_add_from_ucl(opt, mtype, description)
end

exports.rspamd_map_add = rspamd_map_add
exports.rspamd_map_add_from_ucl = rspamd_map_add_from_ucl

-- Check `what` for being lua_map name, otherwise just compares key with what
local function rspamd_maybe_check_map(key, what)
  local fun = require "fun"

  local function starts(where,st)
    return string.sub(where,1,string.len(st))==st
  end

  if type(what) == "table" then
    return fun.any(function(elt) return rspamd_maybe_check_map(key, elt) end, what)
  end
  if type(rspamd_maps) == "table" then
    local mn
    if starts(what, "map:") then
      mn = string.sub(what, 4)
    elseif starts(what, "map://") then
      mn = string.sub(what, 6)
    end

    if mn and rspamd_maps[mn] then
      return rspamd_maps[mn]:get_key(key)
    else
      return what:lower() == key
    end
  else
    return what:lower() == key
  end

end

exports.rspamd_maybe_check_map = rspamd_maybe_check_map

return exports
