local spronk = {}
local spronk_mt = { __index = spronk }

function spronk.new(frame_w, frame_h, spritesheet, bbox_w, bbox_h)
	assert(spritesheet ~= nil,
		"spronk.new: frame_width, frame_height, spritesheet")

	local cols = math.floor(spritesheet:getWidth() / frame_w)
    local rows = math.floor(spritesheet:getHeight() / frame_h)
    
    local quads = {}

    for row = 1, rows do
        quads[row] = {}
        for col = 1, cols do
            local x = (col - 1) * frame_w
            local y = (row - 1) * frame_h
            quads[row][col] = love.graphics.newQuad(x, y, frame_w, frame_h, spritesheet)
        end
    end
    
    -- jit-friendly setmetatable
    local inst = {
    	sheet = spritesheet,
    	quads = quads,
    	states = {},
    	current = nil,
    	timer = 0,
	    frame_index = 1,
	    finished = false,
	    frame_w = frame_w,
	    frame_h = frame_h,

	    -- bounding box dimensions
	    bbox_w = bbox_w or frame_w,
	    bbox_h = bbox_h or frame_h,

	    -- draw defaults
	    rotation = 0,
	    scale_x = 1,
	    scale_y = 1,
	    offset_x = 0,
	    offset_y = 0
    }

    setmetatable(inst, spronk_mt)

    return inst
end

function spronk:add_state(name, cfg)
    assert(cfg.row ~= nil or cfg.frames:match("%d+:"), 
        "spronk.add_state: row required unless using row:frame syntax")

    local state = {
        row = cfg.row or 1,
        duration = cfg.duration or 0.1,
        loop = cfg.loop ~= false,
        frames = self:parse_frames(cfg.frames, cfg.row or 1),
        on_complete = cfg.on_complete,
        on_frame = cfg.on_frame
    }
    
    self.states[name] = state

    if not self.current then
        self.current = name
    end
end

function spronk:set_state(name)
    local new_state = self.states[name]

    -- state does not exist or we're already in this state
    if not new_state or self.current == name then
        return false
    end
    
    self.current = name
    self.timer = 0
    self.frame_index = 1
    self.finished = false
    return true
end

-- why doesn't lua have trim
local function _trim(str)
    return str:match("^%s*(.-)%s*$")
end

function spronk:parse_frames(frame_str, default_row)
    local frames = {}

    for segment in frame_str:gmatch("[^,]+") do
        segment = _trim(segment)
        
        local row = default_row
        local frame_part = segment
        
        -- check if this segment specifies a row
        if segment:match("(%d+):(.+)") then
            local row_str, frames_str = segment:match("(%d+):(.+)")
            row = tonumber(row_str)
            frame_part = frames_str
        end
        
        -- now parse the frame part
        if frame_part:match("(%d+)-(%d+)") then
            local start_frame, end_frame = frame_part:match("(%d+)-(%d+)")
            start_frame, end_frame = tonumber(start_frame), tonumber(end_frame)
            
            if start_frame <= end_frame then
                -- forwards, eg: 1-4
                for i = start_frame, end_frame do
                    table.insert(frames, self.quads[row][i])
                end
            else
                -- reverse, eg: 9-2
                for i = start_frame, end_frame, -1 do
                    table.insert(frames, self.quads[row][i])
                end
            end
        else
            -- single frame
            local frame_num = tonumber(frame_part)
            if frame_num then
                table.insert(frames, self.quads[row][frame_num])
            end
        end
    end
    
    return frames
end

function spronk:update(dt)
    if not self.current then return end
    
    local state = self.states[self.current]
    if not state then return end
    
    if self.finished and not state.loop then return end
    
    self.timer = self.timer + dt
    
    -- calc which frame we should be on
    local frame_duration = state.duration / #state.frames
    local target_frame = math.floor(self.timer / frame_duration) + 1
    
    -- check if we've moved to a new frame
    if target_frame ~= self.frame_index and target_frame <= #state.frames then
        self.frame_index = target_frame
        
        if state.on_frame and state.on_frame[self.frame_index] then
            state.on_frame[self.frame_index]()
        end
    end
    
    -- is the animation complete?
    if self.timer >= state.duration then
        if state.loop then
            self.timer = 0
            self.frame_index = 1
        else
            -- only trigger on_complete if we weren't already finished
            if not self.finished then
                self.finished = true
                self.frame_index = #state.frames
                
                if state.on_complete then
                    state.on_complete()
                end
            end
        end
    end
end

function spronk:draw(x, y, rotation, scale_x, scale_y, offset_x, offset_y)
    if not self.current then return end
    
    local state = self.states[self.current]
    if not state or #state.frames == 0 then return end
    
    local final_scale_x = scale_x or self.scale_x
    local final_scale_y = scale_y or scale_x or self.scale_y
    local final_offset_x = offset_x or self.offset_x
    local final_offset_y = offset_y or self.offset_y
    
    local origin_x = final_offset_x
    if final_scale_x < 0 then
        origin_x = final_offset_x + self.bbox_w
    end
    
    love.graphics.draw(
        self.sheet,
        state.frames[self.frame_index],
        x or 0,
        y or 0,
        rotation or self.rotation,
        final_scale_x,
        final_scale_y,
        origin_x,
        final_offset_y
    )
end

function spronk:set_bbox(bbox)
    if type(bbox) == "table" then
        self.offset_x = bbox.x or 0
        self.offset_y = bbox.y or 0
        self.bbox_w = bbox.w or self.frame_w
        self.bbox_h = bbox.h or self.frame_h
    else
        self.bbox_w = bbox or self.frame_w
        self.bbox_h = bbox or self.frame_h
    end
end


function spronk:flip_h(flipped)
    if flipped then
        self.scale_x = -math.abs(self.scale_x)
    else
        self.scale_x = math.abs(self.scale_x)
    end
end

function spronk:flip_v(flipped)
    if flipped then
        self.scale_y = -math.abs(self.scale_y)
    else
        self.scale_y = math.abs(self.scale_y)
    end
end

function spronk:set_rotation(rot)
    self.rotation = rot
end

function spronk:set_scale(x, y)
    self.scale_x = x
    self.scale_y = y or x
end

function spronk:set_offset(x, y)
    self.offset_x = x or 0
    self.offset_y = y or 0
end

return spronk