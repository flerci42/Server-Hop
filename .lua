--[[local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour
local Deleted = false
local S_T = game:GetService("TeleportService")
local S_H = game:GetService("HttpService")

local File = pcall(function()
	AllIDs = S_H:JSONDecode(readfile("server-hop-temp.json"))
end)
if not File then
	table.insert(AllIDs, actualHour)
	pcall(function()
		writefile("server-hop-temp.json", S_H:JSONEncode(AllIDs))
	end)

end
local function TPReturner(placeId)
	local Site;
	if foundAnything == "" then
		Site = S_H:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=100'))
	else
		Site = S_H:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
	end
	local ID = ""
	if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
		foundAnything = Site.nextPageCursor
	end
	local num = 0;
	for i,v in pairs(Site.data) do
		local Possible = true
		ID = tostring(v.id)
		if tonumber(v.maxPlayers) > tonumber(v.playing) then
			for _,Existing in pairs(AllIDs) do
				if num ~= 0 then
					if ID == tostring(Existing) then
						Possible = false
					end
				else
					if tonumber(actualHour) ~= tonumber(Existing) then
						local delFile = pcall(function()
							delfile("server-hop-temp.json")
							AllIDs = {}
							table.insert(AllIDs, actualHour)
						end)
					end
				end
				num = num + 1
			end
			if Possible == true then
				table.insert(AllIDs, ID)
				wait()
				pcall(function()
					writefile("server-hop-temp.json", S_H:JSONEncode(AllIDs))
					wait()
					S_T:TeleportToPlaceInstance(placeId, ID, game.Players.LocalPlayer)
				end)
				wait(4)
			end
		end
	end
end
local module = {}
function module:Teleport(placeId)
	while wait() do
		pcall(function()
			TPReturner(placeId)
			if foundAnything ~= "" then
				TPReturner(placeId)
			end
		end)
	end
end
return module]]

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
