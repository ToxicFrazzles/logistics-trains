-- Startup script to load into the code for the specific station type

settings.define("station.type", {
    description = "Type of the station",
    default = "provider/requester",
    type="string"
})
settings.set("shell.allow_disk_startup", true)
settings.save()


if settings.get("station.type") == "provider" then
    local p = require("provider")
    p.run()
elseif settings.get("station.type") == "requester" then
    local r = require("requester")
    r.run()
else
    print("Please set the station type correctly. 'set station.type <station type>'")
end
