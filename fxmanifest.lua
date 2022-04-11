fx_version 'cerulean'
game 'gta5'

author 'SocialPeely#4095'
version '1.0.0'
description 'Peely Garages - Advanced Parking'

shared_scripts {
    'config.lua',
    'lang.lua'
}

client_scripts {
    '@PolyZone/client.lua',
	'client.lua'
}

server_script {
	'@oxmysql/lib/MySQL.lua',
	'server.lua'
}

lua54 'yes'