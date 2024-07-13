local json = require("json")

Comms = {
    modemPeripheralName = nil,
    msgHandler = nil
}


function Comms:enumerate()
    local periphs = peripheral.getNames()
    for index, pName in ipairs(periphs) do
        if not peripheral.hasType(pName, "modem") then
            goto continue_enumerate
        else
            local modem = peripheral.wrap(pName)
            if modem.isWireless() then
                Comms.modemPeripheralName = pName
                print("Found wireless modem")
                return true
            end
        end
        ::continue_enumerate::
    end
    return false
end

function Comms:open()
    if Comms.modemPeripheralName == nil then
        Comms.enumerate()
    end
    if rednet.isOpen(Comms.modemPeripheralName) then
        return
    end

    rednet.open(Comms.modemPeripheralName)
    -- print("Opened rednet on modem")
end

function Comms:broadcast(msg)
    if Comms.modemPeripheralName == nil then
        Comms.enumerate()
    end
    if not rednet.isOpen(Comms.modemPeripheralName) then
        Comms.open()
    end
    rednet.broadcast(json.encode(msg), "logisticsTrains")
    -- print(">>>" .. json.encode(msg))
end

function Comms:send(recipient, msg)
    if Comms.modemPeripheralName == nil then
        Comms.enumerate()
    end
    if not rednet.isOpen(Comms.modemPeripheralName) then
        Comms.open()
    end

    rednet.send(recipient, json.encode(msg), "logisticsTrains")
    -- print(">" .. json.encode(msg))
end

function Comms:receive(timeout)
    if Comms.modemPeripheralName == nil then
        Comms.enumerate()
    end
    if not rednet.isOpen(Comms.modemPeripheralName) then
        Comms.open()
    end

    local id, msg = rednet.receive("logisticsTrains", timeout)
    if not id then
        return id,msg
    else
        -- print("<" .. msg)
        return id, json.decode(msg)
    end
end

return Comms