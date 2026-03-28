local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local module = {}

local visitedServers = {}
local cursor = nil
local hopping = false

local function getServers(placeId)
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"

    if cursor then
        url = url .. "&cursor=" .. cursor
    end

    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        warn("HTTP failed, retrying...")
        task.wait(2)
        return nil
    end

    return HttpService:JSONDecode(response)
end

local function hop(placeId)
    if hopping then return end
    hopping = true

    while true do
        task.wait(2)

        local data = getServers(placeId)
        if not data then continue end

        cursor = data.nextPageCursor

        local foundServer = false

        for _, server in pairs(data.data) do
            if server.playing < server.maxPlayers then
                local id = server.id

                if not visitedServers[id] then
                    visitedServers[id] = true
                    foundServer = true

                    print("Joining server:", id)

                    local success, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, id, player)
                    end)

                    if success then
                        task.wait(5)
                        return
                    else
                        warn("Teleport failed:", err)
                    end
                end
            end
        end

        if not foundServer then
            print("No available servers here, moving on...")
        end

        if not cursor then
            print("Reached end, restarting search...")
            visitedServers = {}
            cursor = nil
            task.wait(1)
        end
    end
end

function module:Teleport(placeId)
    hop(placeId)
end

return module
