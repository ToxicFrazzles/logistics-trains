-- Install to computer:
-- pastebin get wmUAz9Hj install.lua
-- Install to floppy:
-- pastebin get wmUAz9Hj disk/startup.lua

-- Files currently hosted here. This will change to use your own server in future
local base_url = "https://jdengineering.uk/misc/logitrains/"

local files = {
    "startup.lua", "comms.lua", "provider.lua",
    "requester.lua", "station.lua", "storage.lua", "json.lua"
}



for index, value in ipairs(files) do
    local r = http.get(base_url .. value, nil, true)
    if r == nil then
        goto ERROR
    end

    local f = fs.open(value, "w+")
    f.write(r.readAll())
    f.close()
end

print("Installed successfully!")
sleep(3)
settings.set("shell.allow_disk_startup", false)
settings.save()
os.reboot()
::ERROR::
print("ERROR: Failed to download required file '" .. value .. "'")
sleep(30)
os.shutdown()
