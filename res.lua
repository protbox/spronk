local math_min = math.min

local res = {}

local last_mouse_x, last_mouse_y = 0, 0
local currently_rendering = nil

local function _get_raw_mouse_position(width, height)
  local mouse_x, mouse_y = love.mouse.getPosition()
  local window_width, window_height = love.graphics.getDimensions()
  local scale = math_min(window_width / width, window_height / height)
  local offset_x = (window_width - width * scale) * 0.5
  local offset_y = (window_height - height * scale) * 0.5
  return (mouse_x - offset_x) / scale, (mouse_y - offset_y) / scale
end

function res.get_mouse_position(width, height)
  local x, y = _get_raw_mouse_position(width, height)
  if x >= 0 and x <= width and y >= 0 and y <= height then
    last_mouse_x, last_mouse_y = x, y
  end
  return last_mouse_x, last_mouse_y
end

function res.get_scale(width, height)
  if currently_rendering then
    width  = width  or currently_rendering[1]
    height = height or currently_rendering[2]
  end
  local window_width, window_height = love.graphics.getDimensions()
  return math_min(window_width / width, window_height / height)
end

function res.set(width, height, centered)
  if currently_rendering then
    error("Must call res.unset before calling set.")
  end

  currently_rendering = {width, height}
  love.graphics.push()

  local window_width, window_height = love.graphics.getDimensions()
  local scale = math_min(window_width / width, window_height / height)
  local offset_x = (window_width - width * scale) * 0.5
  local offset_y = (window_height - height * scale) * 0.5
  love.graphics.translate(offset_x, offset_y)
  love.graphics.scale(scale)
  
  if centered then
    love.graphics.translate(0.5 * width, 0.5 * height)
  end

  return scale
end

local default_black = {0, 0, 0, 1}

function res.unset(letterbox_color)
  if not currently_rendering then
    error("Must call res.set before calling unset.")
  end

  local canvas_width, canvas_height = currently_rendering[1], currently_rendering[2]
  currently_rendering = nil
  love.graphics.pop()

  local window_width, window_height = love.graphics.getDimensions()
  local scale = math_min(window_width / canvas_width, window_height / canvas_height)
  local scaled_width, scaled_height = canvas_width * scale, canvas_height * scale

  local r, g, b, a = love.graphics.getColor()
  love.graphics.setColor(letterbox_color or default_black)
  
  -- draw letterbox bars
  love.graphics.rectangle("fill", 0, 0, window_width, 0.5 * (window_height - scaled_height))       -- top
  love.graphics.rectangle("fill", 0, window_height, window_width, -0.5 * (window_height - scaled_height)) -- bottom
  love.graphics.rectangle("fill", 0, 0, 0.5 * (window_width - scaled_width), window_height)          --left
  love.graphics.rectangle("fill", window_width, 0, -0.5 * (window_width - scaled_width), window_height) -- right

  -- restore original color
  love.graphics.setColor(r, g, b, a)
end

return res
