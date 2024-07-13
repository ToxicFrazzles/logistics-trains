# logistics-trains
A system to turn trains from the Minecraft mod Create into smart logistics trains through the use of CC: Tweaked computers

## Work In Progress
I currently have big plans to make the computers able to be managed through a web interface such as updating their Lua code and configuring the item and fluid thresholds on requester stations. For now the only functioning version is the first version detailed below.

## First version
The first version purely uses wireless rednet  to request and provide items. 
There's a handy installation script for this first version on [pastebin](https://pastebin.com/wmUAz9Hj) and you can easily download the installer to your CC: Tweaked computer with this command `pastebin get wmUAz9Hj install.lua`

To set up a station you will need:
* Train station block
* Ender modem
* Computer
* Portable fluid/storage interface 
* Cables and modems to connect the station to the computer. Provider stations also require storage and the interface to be connected to the wired network.

I will not provide support for the use of this first verison or do any bugfixes. I also currently host the Lua files on my webserver and this could go down without warning. If the first version is no longer hosted on my webserver you can find it in the [second commit to this repo](https://github.com/ToxicFrazzles/logistics-trains/tree/c7a0ba96cca2fe376c1ddd1ad5ad97cb724bff9d/server/computer/station).