-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
Game = "0rVZYFxvfJpO__EfOz0_PUQ3GFE9kEaES0GkUDNXjvE" 
HealthyValue = 20

local colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
local function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Calculate members distance with proximity
-- @param x1, y1: Coordinates of the first point
-- @param x2, y2: Coordinates of the second point
-- @return: float indicating the distance between two points
local function calcDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

-- Finds the weakest opponent within a specified range.
-- @param playerId: The ID of the player.
-- @param range: The range within which to search for opponents.
-- @return: The ID of the weakest opponent, or nil if no opponent is found.
function findAttackableMemberInRange(playerId, range)
    local player = LatestGameState.Players[playerId]
    local targetId = nil
    local targetHealth = math.huge -- Initialize with a large value

    -- 1.find the nearest member in range, return id if it's health value less than palyer.
    local minDistance = 10000
    local minDisState = { x = 0, y = 0 }
    local minDisId = nil
    for disId, disState in pairs(LatestGameState.Players) do
        if (disId ~= playerId) then
            local dis = calcDistance(player.x, player.y, disState.x, disState.y)
            if (dis < minDistance) then
                minDistance = dis
                minDisState = disState
            end
        end
    end

    local minDisPlayer = LatestGameState.Players[minDisId]
    if minDisId ~= playerId and inRange(player.x, player.y, minDisState.x, minDisState.y, range) and minDisPlayer.health < player.health then
        return minDisId
    end

    -- 2.find the weakest member
    local minHealth = 10000
    local minHealthId = nil
    for healthId, healthState in pairs(LatestGameState.Players) do
        if healthId ~= playerId and inRange(player.x, player.y, healthState.x, healthState.y, range) then
            if healthState.health < minHealth then
                minHealthId = healthId
                minHealth = healthState.health
            end
        end
    end

    return minHealthId
end

-- Decides the next action based on player proximity and energy.
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
function decideNextAction()
    local player = LatestGameState.Players[ao.id]

    if player.energy > 5 then
        local targetId = findAttackableMemberInRange(ao.id, 3)
        if targetId then
            print(colors.red .. "Player in range. Attacking the target opponent." .. colors.reset)
            ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, TargetPlayer = targetId, AttackEnergy =
            tostring(player.energy) })
        end
    else
        print(colors.red .. "No player in range or insufficient energy. Moving randomly." .. colors.reset)
        local directionMap = { "Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft" }
        local randomIndex = math.random(#directionMap)
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex] })
    end
    InAction = true
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" then
            ao.send({ Target = ao.id, Action = "AutoPay" })
        elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
            ao.send({ Target = Game, Action = "GetGameState" })
        elseif InAction then
            print("Previous action still in progress. Skipping.")
        end
        print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    end
)

-- Handler to trigger game state updates.
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        if not InAction then
            print(colors.gray .. "Getting game state..." .. colors.reset)
            ao.send({ Target = Game, Action = "GetGameState" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
    "AutoPay",
    Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function(msg)
        print("Auto-paying confirmation fees.")
        ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Print \'LatestGameState\' for detailed view.")
    end
)

-- Handler to decide the next best action.
Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function()
        if LatestGameState.GameMode ~= "Playing" then
            InAction = false -- Reset InAction flag if not in playing mode
            return
        end
        print("Deciding next action.")
        decideNextAction()
    end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        if not InAction then
            InAction = true
            local playerEnergy = LatestGameState.Players[ao.id].energy
            if playerEnergy == nil then
                print(colors.red .. "Unable to read energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
            elseif playerEnergy == 0 then
                print(colors.red .. "Player has insufficient energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
            else
                print(colors.red .. "Returning attack." .. colors.reset)
                ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
            end
            ao.send({ Target = ao.id, Action = "Tick" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)