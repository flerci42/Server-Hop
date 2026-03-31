-- ServerHop Module
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local module = {}

local visitedServers = {}
local cursor = nil
local hopping = false
local retrying = false
local currentPlaceId = nil

local function safeJSONDecode(str)
    local success, result = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    if success then
        return result
    else
        warn("JSON decode failed, retrying...")
        return nil
    end
end

local function getServers(placeId)
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    if cursor then
        url = url .. "&cursor=" .. cursor
    end

    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if not success or not response then
        warn("HTTP request failed, retrying...")
        task.wait(2)
        return nil
    end

    local data = safeJSONDecode(response)
    if not data then
        task.wait(1)
        return nil
    end

    return data
end

local function hop(placeId)
    if hopping then return end
    hopping = true
    currentPlaceId = placeId

    while true do
        task.wait(2)

        local data = getServers(placeId)
        if not data then continue end

        cursor = data.nextPageCursor
        local found = false

        for _, server in pairs(data.data) do
            if server.playing < server.maxPlayers
            and not server.accessCode then

                local id = server.id

                if not visitedServers[id] then
                    visitedServers[id] = true
                    found = true

                    print("Attempting server:", id)

                    local success, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, id, player)
                    end)

                    if not success then
                        if tostring(err):find("Unauthorized") then
                            print("Skipped VIP server:", id)
                        else
                            warn("Teleport error:", err)
                        end
                    end

                    task.wait(2)
                end
            end
        end

        if not found then
            print("No available servers in this batch, continuing...")
        end

        if not cursor then
            print("Reached end, restarting search...")
            visitedServers = {}
            cursor = nil
            task.wait(1)
        end
    end
end

TeleportService.TeleportInitFailed:Connect(function(plr, result, err, placeId, instanceId)
    if plr ~= player then return end
    if retrying then return end

    retrying = true
    warn("Teleport failed:", result, err)
    task.wait(2)

    if module and currentPlaceId then
        module:Teleport(currentPlaceId)
    end

    task.wait(3)
    retrying = false
end)

function module:Teleport(placeId)
    hop(placeId)
end

return module
