fx_version 'cerulean'
game 'gta5'

author 'Rico Scripts'
description 'Complete ESX economy management with banking, savings, loans, policies and audit logging'
version '1.0.0'

lua54 'yes'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/logging.lua',
    'server/main.lua'
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql'
}

provide 'rs-economie'
