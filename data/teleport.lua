local waypoint_loader = require("functions.waypoint_loader")
local countdown_display = require("graphics.countdown_display")
local teleport = {}

local function cleanup_before_teleport(ChestsInteractor, Movement)
    collectgarbage("collect")
    waypoint_loader.clear_cached_waypoints()
    ChestsInteractor.clearInteractedObjects()
    Movement.reset()
end

-- Variáveis locais
local current_index = 1
local last_position = nil
local stable_position_count = 0
local stable_position_threshold = 3 -- Ajuste conforme necessário
local teleport_state = "idle"
local teleport_start_time = 0
local teleport_timeout = 10 -- Tempo máximo para teleporte em segundos

-- Função para obter o próximo local de teleporte
function teleport.get_next_teleport_location()
    local valid_zones = {}
    for zone, info in pairs(waypoint_loader.zone_mappings) do
        table.insert(valid_zones, {name = zone, id = info.id})
    end
    return valid_zones[(current_index % #valid_zones) + 1].name
end

-- Função principal de teleporte
function teleport.tp_to_next(ChestsInteractor, Movement)
    local current_time = os.time()
    local current_world = world.get_current_world()
    if not current_world then
        return false
    end

    local world_name = current_world:get_name()
    local local_player = get_local_player()
    if not local_player then
        return false
    end

    local current_position = local_player:get_position()

    if teleport_state == "idle" then
        cleanup_before_teleport(ChestsInteractor, Movement)
        local valid_zones = {}
        for zone, info in pairs(waypoint_loader.zone_mappings) do
            if zone ~= current_world:get_current_zone_name() then
                table.insert(valid_zones, {name = zone, id = info.id})
            end
        end
        if #valid_zones == 0 then
            console.print("Erro: Não há zonas válidas para teleporte")
            return false
        end
        local current_tp = valid_zones[current_index]
        teleport_to_waypoint(current_tp.id)
        teleport_state = "initiated"
        teleport_start_time = current_time
        last_position = current_position
        console.print("Teleporte iniciado para " .. current_tp.name)
        countdown_display.start_countdown(teleport_timeout)
        return false
    elseif teleport_state == "initiated" then
        if current_time - teleport_start_time > teleport_timeout then
            console.print("Teleporte falhou: timeout. Tentando novamente...")
            teleport_state = "idle"  -- Reset the state to try again
            return false
        elseif world_name:find("Limbo") then
            teleport_state = "in_limbo"
            console.print("Em Limbo, aguardando...")
            return false
        elseif current_position:dist_to(last_position) > 5 then  -- Assuming a threshold of 5 units
            console.print("Movimento detectado. Teleporte cancelado. Tentando novamente...")
            teleport_state = "idle"  -- Reset the state to try again
            return false
        end
    elseif teleport_state == "in_limbo" and not world_name:find("Limbo") then
        teleport_state = "exited_limbo"
        last_position = current_position
        stable_position_count = 0
        console.print("Saiu do Limbo, verificando posição estável")
        return false
    elseif teleport_state == "exited_limbo" then
        if last_position and current_position:dist_to(last_position) < 0.5 then
            stable_position_count = stable_position_count + 1
            if stable_position_count >= stable_position_threshold then
                local valid_zones = {}
                for zone, info in pairs(waypoint_loader.zone_mappings) do
                    if zone ~= current_world:get_current_zone_name() then
                        table.insert(valid_zones, {name = zone, id = info.id})
                    end
                end
                current_index = current_index % #valid_zones + 1
                teleport_state = "idle"
                console.print("Teleporte concluído com sucesso para " .. valid_zones[current_index].name)
                return true
            end
        else
            stable_position_count = 0
        end
    end

    last_position = current_position
    return false
end

-- Função para resetar o estado do teleporte
function teleport.reset()
    teleport_state = "idle"
    last_position = nil
    stable_position_count = 0
    current_index = 1
    console.print("Estado do teleporte resetado")
end

-- Função para obter o estado atual do teleporte
function teleport.get_teleport_state()
    return teleport_state
end

return teleport