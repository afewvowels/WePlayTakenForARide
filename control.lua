-- WePlay: Taken for a Ride — Train Collision Avoidance
-- Trains pick you up instead of running you over.

local ROLLING_STOCK = {
  ["locomotive"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["artillery-wagon"] = true,
}

local DODGE_DISTANCE = 3
local HORN_COOLDOWN = 180 -- ticks (3 seconds) between honks from the same train

-- Toot toot! Plays for every nearby player who has the horn turned on.
local function honk(car)
  local train = car.train
  local id = train and train.valid and train.id or car.unit_number
  storage.last_honk = storage.last_honk or {}
  local last = storage.last_honk[id]
  if last and game.tick - last < HORN_COOLDOWN then return end
  storage.last_honk[id] = game.tick

  local surface = car.surface
  for _, player in pairs(game.connected_players) do
    if player.surface == surface and settings.get_player_settings(player)["wp-tfar-horn"].value then
      player.play_sound{path = "wp-tfar-horn", position = car.position}
    end
  end
end

local function dist2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function notify(character, key)
  local player = character.player
  if not (player and player.valid) then return end
  if not settings.get_player_settings(player)["wp-tfar-message"].value then return end
  player.create_local_flying_text{
    text = {key},
    position = character.position,
  }
end

-- Find an empty seat in the train, preferring the car that hit us, then the closest one.
local function find_empty_car(hit_by, character)
  if not hit_by.get_driver() then return hit_by end
  local train = hit_by.train
  if not (train and train.valid) then return nil end
  local best, best_d
  local pos = character.position
  for _, car in pairs(train.carriages) do
    if car.valid and not car.get_driver() then
      local d = dist2(car.position, pos)
      if not best_d or d < best_d then
        best, best_d = car, d
      end
    end
  end
  return best
end

-- Bump the character sideways off the tracks, toward whichever side they're already on.
local function dodge(hit_by, character)
  local angle = hit_by.orientation * 2 * math.pi
  -- Train facing direction (orientation 0 = north, clockwise).
  local fx, fy = math.sin(angle), -math.cos(angle)
  -- Perpendicular (to the train's right).
  local px, py = -fy, fx

  local rel_x = character.position.x - hit_by.position.x
  local rel_y = character.position.y - hit_by.position.y
  local side = (rel_x * px + rel_y * py) >= 0 and 1 or -1

  local target = {
    x = character.position.x + px * side * DODGE_DISTANCE,
    y = character.position.y + py * side * DODGE_DISTANCE,
  }
  local safe = character.surface.find_non_colliding_position(character.name, target, 6, 0.5)
  if safe then
    character.teleport(safe)
  end
end

local function on_damaged(event)
  local cause = event.cause
  if not (cause and cause.valid and ROLLING_STOCK[cause.type]) then return end
  if event.damage_type.name ~= "impact" then return end

  local character = event.entity
  if not (character and character.valid) then return end

  -- Undo the hit.
  character.health = character.health + event.final_damage_amount

  if character.vehicle then return end

  if settings.global["wp-tfar-mode"].value == "pickup" then
    local car = find_empty_car(cause, character)
    if car then
      car.set_driver(character)
      honk(cause)
      notify(character, "wp-tfar.picked-up")
      return
    end
  end

  dodge(cause, character)
  honk(cause)
  notify(character, "wp-tfar.dodged")
end

script.on_event(defines.events.on_entity_damaged, on_damaged, {
  {filter = "type", type = "character"},
})
