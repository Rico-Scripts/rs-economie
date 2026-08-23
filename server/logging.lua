RSEconomyLog = function(event, title, description, fields, level)
    local payload = {
        resource = GetCurrentResourceName(),
        event = event,
        title = title,
        description = description,
        color = Config.LogColors[level or 'info'] or Config.LogColors.info,
        fields = fields or {},
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    if GetResourceState('rs_discordlogs') == 'started' then
        local ok = pcall(function()
            exports.rs_discordlogs:Log(event, payload)
        end)
        if ok then return end
    end

    if Config.Webhook == '' then return end
    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = Config.WebhookName,
        avatar_url = Config.WebhookAvatar,
        embeds = {{
            title = title,
            description = description,
            color = payload.color,
            fields = fields,
            footer = { text = 'Rico Scripts • RS Economie' },
            timestamp = payload.timestamp
        }}
    }), { ['Content-Type'] = 'application/json' })
end
