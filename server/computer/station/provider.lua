-- Code for Provider stations
local comms = require("comms")
local storage = require("storage")
local station = require("station")
local pretty = require("cc.pretty")

Provider = {
    state = "idle",
    requester = nil,
    time = nil,
    sendingItems = nil,
    sendingFluids = nil,
    destination = nil,
}


local function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
  end

function Provider:displayInfo()
    term.clear()
    term.setCursorPos(1,1)
    print("Provider Station")
    print("State: "..Provider.state)
    print("Requester: "..(Provider.requester or "None"))
    print("Time: "..(Provider.time or "None"))
    print("Destination: "..(Provider.destination or "None"))
end


function Provider:run()
    storage.enumerate()
    if not station.enumerate() then
        print("No station present...")
    end
    if not comms.enumerate() then
        print("No modem present...")
        return
    end

    term.clear()
    term.setCursorPos(1,1)
    print("Provider Station")

    while true do
        Provider.displayInfo()
        if Provider.state == "noTrain" and station.trainPresent() then
            Provider.state = "idle"
        elseif Provider.state == "noTrain" then
            sleep(5)
        elseif Provider.state == "idle" then
            local id, msg = comms.receive()
            if not id or msg["type"] ~= "request" then
                goto continue_run
            end
            local itemLevels, fluidLevels = storage.getLevels()
            local itemsCanProvide = {}
            for name, quantity in pairs(msg["items"]) do
                if itemLevels[name] and itemLevels[name] > quantity then
                    itemsCanProvide[name] = quantity
                end
            end
            local fluidsCanProvide = {}
            for name, quantity in pairs(msg["fluids"]) do
                if fluidLevels[name] and fluidLevels[name] > quantity then
                    fluidsCanProvide[name] = quantity
                end
            end

            if tablelength(itemsCanProvide) == 0 and tablelength(fluidsCanProvide) == 0 then
                goto continue_run
            end
            
            Provider.requester = id
            comms.send(nil, id, {
                type = "requestAck"
            })
            Provider.state = "acked"
            Provider.time = os.clock()
        elseif Provider.state == "acked" then
            local id, msg = comms.receive(nil,5)
            if not id or msg["type"] ~= "requestOptional" then
                goto continue_run
            end

            local itemLevels, fluidLevels = storage.getLevels()
            local sendingItems = {}
            local sendingFluids = {}
            for name, quantity in pairs(msg["items"]) do
                if itemLevels[name] and itemLevels[name] > quantity then
                    sendingItems[name] = quantity
                end
            end
            for name, quantity in pairs(msg["fluids"]) do
                if fluidLevels[name] and fluidLevels[name] > quantity then
                    sendingFluids[name] = quantity
                    break
                end
            end

            comms.send(nil, id, {
                type = "requestOptionalAck",
                items = sendingItems,
                fluids = sendingFluids
            })
            Provider.state = "pendingAccept"
            Provider.time = os.clock()
            Provider.sendingItems = sendingItems
            Provider.sendingFluids = sendingFluids
        elseif Provider.state == "pendingAccept" then
            local id, msg = comms.receive(nil,5)
            if not id or (msg["type"] ~= "accept" and msg["type"] ~= "reject") then
                goto continue_run
            end
            if msg["type"] == "reject" then
                Provider.state = "idle"
                Provider.time = nil
                Provider.sendingItems = nil
                Provider.sendingFluids = nil
            else
                Provider.destination = msg["station"]
                Provider.state = "loading"
                Provider.time = os.clock()
            end
        elseif Provider.state == "loading" then
            storage.loadTrain(nil,Provider.sendingItems, Provider.sendingFluids)
            station.unloadAt(nil,Provider.destination, Provider.sendingItems, Provider.sendingFluids)
            Provider.state = "noTrain"
            sleep(5)
        else
            -- Unknown state.
            print("Unknown state: "..Provider.state)
            sleep(60)
        end
        ::continue_run::
    end
end


return Provider