love.graphics.setDefaultFilter("nearest", "nearest")

local res = require "res"
local spronk = require "spronk"

-- https://clembod.itch.io/warrior-free-animation-set
local spritesheet = love.graphics.newImage("player.png")

local spr
local player = {
	x = 0,
	y = 170-42,
	vx = 0,
	vy = 0,
	jump_force = -240,
	gravity = -600,
	ground = 168,
	speed = 80,
}

function love.load()
	love.graphics.setBackgroundColor(100/255, 169/255, 229/255, 1)

	spr = spronk.new(69, 44, spritesheet)
	-- optional bounding box support
	spr:set_bbox({
		x = 22, -- x offset
		y = 12, -- y offset
		w = 10, -- bbox width
		h = 31  -- bbox height
	}) 

	spr:add_state("idle", {
		row = 1,
		frames = '1-6',
		duration = 0.8
	})

	spr:add_state("run", {
		frames = '2:1-6, 3:1-2',
		duration = 0.6
	})

	spr:add_state("jump", {
		frames = '7:5-6, 8:1-2',
		duration = 0.6
	})

	spr:add_state("fall", {
		frames = '8:3-6, 9:1',
		duration = 0.6
	})

	spr:add_state("land", {
		frames = '11:4-6, 12:1-3',
		duration = 0.2,
		loop = false,
		on_complete = function()
			player.landing = false
			spr:set_state("idle")
		end
	})

	spr:add_state("attack1", {
		frames = '3:3-6, 4:1-5',
		duration = 0.4,
		loop = false,
		on_complete = function()
			player.attacking = false
			spr:set_state("idle")
		end
	})
end

--[[ WARNING WARNING WARNING WARNING ]]
-- DO NOT USE THIS AS AN ACTUAL EXAMPLE FOR A PLAYER CONTROLLER. IT IS TERRIBLE AND BUGGY.
-- YOU HAVE BEEN WARNED.

function love.update(dt)
	spr:update(dt)

	-- run
	if love.keyboard.isDown("right") then
		if player.x < 300 then
			spr:flip_h(false)
			player.x = player.x + (player.speed * dt)

			player.running = true
		end

		
	elseif love.keyboard.isDown("left") then
		if player.x > -20 then
			spr:flip_h(true)
			player.x = player.x - (player.speed * dt)

			player.running = true
		end
	else
		player.running = false
	end

	-- jump
	if love.keyboard.isDown("z") then
		if player.vy == 0 then
			spr:set_state("jump")
			player.vy = player.jump_force
		end
	end

	-- gravity
	if player.vy ~= 0 then
		player.y = player.y + player.vy * dt
		player.vy = player.vy - player.gravity * dt
	end

	if player.y > player.ground-44 then
		player.vy = 0
    	player.y = player.ground-44
    	if spr.current == "fall" then
    		player.landing = true
    		spr:set_state("land")
    	end
	end

	if love.keyboard.isDown("x") and not player.attacking then
		player.attacking = true
		spr:set_state("attack1")

	elseif not player.attacking then
		-- animations
		if player.vy < 0 then
			spr:set_state("jump")
		elseif player.vy > 0 then
			spr:set_state("fall")
		else
			if not player.landing then
				if player.running then
					spr:set_state("run")
				else
					spr:set_state("idle")
				end
			end
		end
	end
end

function love.draw()
	res.set(320, 180)
	spr:draw(player.x, player.y)
	res.unset()
end