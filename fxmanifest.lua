fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'devayee'
description 'Framework-agnostic bridge library for ESX / QBCore / QBox / Standalone'
version '1.0.0'
repository 'https://github.com/devayee/d-bridge'

shared_scripts {
      '@ox_lib/init.lua',
    'shared/config.lua'
}

server_scripts {
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}
