

function inRange()
    local data = math.random(1, 100)
    local ret = data % 3

    if ret == 1 then
        return "paper"
    elseif ret == 2 then
        return "stone"
    else
        return "scissors"
    end
end

function  compare(msg)
    local playerToAct = msg.From
    local x = msg.Tags.Direction
    local y = inRange()
    local reply = "win"

    if x == "paper" and y == "stone" then
        reply = "win"
    elseif x == "paper" and y == "paper" then
        reply = "equal"
    elseif x == "paper" and y == "scissors" then
        reply = "failed"
    elseif x == "stone" and y == "paper" then
        reply = "failed"
    elseif x == "stone" and y == "stone" then
        reply = "equal"
    elseif x == "stone" and y == "scissors" then
        reply = "win"
    elseif x == "scissors" and y == "paper" then
        reply = "win"
    elseif x == "scissors" and y == "stone" then
        reply = "failed"
    elseif x == "scissors" and y == "scissors" then
        reply = "equal"
    else
        ao.send({Target = playerToAct, Action = "Act-Failed", Reason = "Invalid direction."})
    end

    announce("Player-Act", playerToAct, reply)
end

Handlers.add("PlayerAct", Handlers.utils.hasMatchingTag("Action", "PlayerCompare"), compare)
