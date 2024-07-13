-- Code for Requester stations
local comms = require("comms")
local storage = require("storage")
local station = require("station")
local pretty = require("cc.pretty")

Requester = {
    state = "idle",
    provider = nil,
    lastLearn = nil,
    time = nil,
}

function Requester:displayInfo()
    term.clear()
    term.setCursorPos(1,1)
    print("Requester Station")
    print("State: "..Requester.state)
    print("Provider: "..(Requester.provider or "None"))
    print("Time: "..(Requester.time or "None"))
end

local function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
  end

function Requester:run()
    term.clear()
    term.setCursorPos(1,1)
    print("Requester Station")
    storage.enumerate()
    if not station.enumerate() then
        print("No station present...")
    end
    if not comms.enumerate() then
        print("No modem present...")
        return
    end

    while true do
        Requester.displayInfo()
        if Requester.state == "waiting" and station.trainInbound() then
            -- Waiting for train delivery and either the train is on its way or it's being unloaded
            Requester.state = "inbound/unloading"
            sleep(1)
        elseif Requester.time and os.clock() - Requester.time > 600 then
            -- Nothing should take more than 10 minutes, so return to idle state after 10 minutes
            Requester.state = "idle"
            Requester.time = nil
        elseif Requester.state == "waiting"  then
            -- Do nothing if we're in the waiting state
            sleep(1)
        elseif Requester.state == "inbound/unloading" and not station.trainInbound() then
            -- Was unloading. Train has since fucked off. Return to idle
            Requester.state = "idle"
        elseif Requester.state == "inbound/unloading" then
            -- Train is present and being unloaded. Just wait 1 second
            sleep(1)
        elseif Requester.state == "requested" and os.clock() - Requester.time > 5 then
            Requester.state = "idle"
        elseif Requester.state == "idle" then
            -- Check if we need any items. If we do, broadcast that need
            local itemsNeeded, fluidsNeeded = storage.stuffNeeded()
            -- pretty.pretty_print(needed)
            if tablelength(itemsNeeded) > 0 then
                -- print("Items needed")
                comms.broadcast(nil,{
                    type="request",
                    items=itemsNeeded,
                    fluids=fluidsNeeded
                })
                Requester.state = "requested"
                Requester.time = os.clock()
            else
                -- print("No items needed")
                sleep(5)
            end
        elseif Requester.state == "requested" then
            -- Wait for a response to the needed items broadcast.
            -- Respond with a list of all items we could do with having
            local id, msg = comms.receive(nil,5)
            if not id or msg["type"] ~= "requestAck" then
                goto continue_run
            end
            Requester.provider = id
            Requester.state = "negotiating"
            Requester.time = os.clock()

            local itemsWanted, fluidsWanted = storage.stuffWanted()

            comms.send(nil, id, {
                type="requestOptional",
                items=itemsWanted,
                fluids=fluidsWanted
            })
        elseif Requester.state == "negotiating" then
            -- Wait for a list of all items that will be sent
            -- Accept the terms of the delivery and begin waiting for it.
            local id, msg = comms.receive(nil,5)
            if not id or msg["type"] ~= "requestOptionalAck" or id ~= Requester.provider then
                goto continue_run
            end
            
            comms.send(nil, id, {
                type = "accept",
                station = station.getName()
            })
            Requester.state = "waiting"
            Requester.time = os.clock()
        else
            -- Unknown state.
            print("Unknown state: "..Requester.state)
            sleep(60)
        end
        ::continue_run::
    end
end


return Requester