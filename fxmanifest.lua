fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'qbx_usedcars'
author 'mundstock'
description 'Sell used vehicles anywhere'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@qbx_core/modules/lib.lua',
    'server/listings.lua',
    'server/main.lua'
}

client_scripts {
    '@qbx_core/modules/lib.lua',
    'client/main.lua',
    'client/nui.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/app.js',
    'web/style.css'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'oxmysql'
}

