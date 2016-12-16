uart.setup(0,115200,8,0,1,1)
print("NodeMCU Aspiradora Robot")
motor_control = require('motor_control')
ultrasonic_sensor = require('ultrasonic_sensor')
relay = require('relay')
servo = require('servo')



events = {}
event_counter = 0


-- Tabla que hace un mapeo de los estados de la máquina de estados finitos con
-- el cada uno de los mensajes relacionados que se enviarán al usuario.
pretty_state = {OFF="El robot ha sido detenido.", 
                MOVING="Moviendose automáticamente.", 
                LOOKING_LEFT="Mirando hacia la izquierda.",
                LOOKING_RIGHT="Mirando hacia la derecha.",
                TURNING_LEFT="Girando hacia la izquierda.",
                TURNING_RIGHT="Girando hacia la derecha.",
                NEED_TO_AVOID="Obstáculo detectado.",
                AVOIDING="Verificando existencia de obstáculo.",
                TURNING_AROUND="Girando 180°."}


-- Definición de estado de inicio y variables iniciales.
state = "OFF"
last_sent_state = "OFF"
last_state = "OFF"
obstacle = false
ok_to_go = false

mode = "none"

files = file.list()

-- Configuración inicial para cada uno de los módulos del sistema.
ultrasonic_sensor.setup()
relay.setup()
motor_control.setup()
servo.setup()

opt_enc.setup(6)


-- Variables que almacenan los pulsos del encoder cuando se quiere girar (cálculos detallados en informe):
-- 120°
turn_pulses = ((2 * 314 * 235) / (30 * 100)) -- 21.98
-- 180°
turn_around_pulses = ((2 * 314 * 235) / (20 * 100)) -- 32.97


-- Función que añade un nuevo evento a la tabla de eventos de la cual consume el usuario para visualizar
-- en la interfaz web.
function add_new_event(message)
    event_counter = event_counter + 1
    events[#events + 1] = string.format('{"id": %i, "message": "%s"}', event_counter, message)
end


-- Función que genera un JSON para enviar información al usuario.
-- La estructura contiene información del estado del sistema y los eventos ocurridos.
function generate_json()
    status = 'Funcionando'
    cleaning = "false"
    if relay.is_enabled() then
        cleaning = "true"
    end
    
    events_str = string.format('{"status": "%s", "mode": "%s", "cleaning": %s, "events": [', status, mode, cleaning)
    events_str = events_str .. table.concat(events, ", ") .. "]}"
    
    for k,v in pairs(events) do events[k]=nil end
    
    return events_str
end


-- Función que realiza las tareas correspondientes al estado actual en el que se encuentra
-- la máquina de estados finitos.
function do_state()
    -- Se almacenan los estados de las alarmas utilizadas en la detección de obstáculos
    -- laterales y en los giros del robot.
    running_2, mode_2 = tmr.state(2)
    running_3, mode_3 = tmr.state(3)

    -- Acciones de acuerdo al estado actual.
    if state == "OFF" then  -- Si el estado es OFF se apagan los motores.
        motor_control.stop()
        obstacle = false
        ok_to_go = false
        servo_done = false
        motor_done = false
        distance_done = false
        obstacle_done = false
    elseif state == "MOVING" then -- Si el estado es MOVING se mueve hacia adelante y se verifica la existencia de obstáculos.
        motor_control.move('forward')
        ultrasonic_sensor.get_distance(function(distance)
            obstacle = (distance < 30)
        end)
    elseif state == "NEED_TO_AVOID" then -- Si el estado es NEED_TO_AVOID se verifíca por segunda vez la existencia de un obstáculo delantero.
        if not distance_done then
            motor_control.stop()
            obstacle = false
            obstacle_done = false
            ultrasonic_sensor.get_distance(function(distance)
                distance = distance
                distance_done = true
                obstacle = (distance < 30)
                obstacle_done = true
            end)
        end
    elseif state == "AVOIDING" then -- Si el estado es AVOIDING se frenan los motores.
        motor_control.stop()
        obstacle = false
    elseif state == "LOOKING_LEFT" then -- Si el estado es LOOKING_LEFT se gira el servo para detectar obstáculos a la izquierda.
        if not running_2 then
            servo.look_left()
            tmr.alarm(2, 1500, tmr.ALARM_SINGLE, function()
                ultrasonic_sensor.get_distance(function(distance)
                    ok_to_go = distance > 30
                    servo.look_forward()
                    servo_done = true
                end)
            end)
        end
    elseif state == "LOOKING_RIGHT" then -- Si el estado es LOOKING_RIGHT se gira el servo para detectar obstáculos a la derecha.
        if not running_2 then
            servo.look_right()
            tmr.alarm(2, 1500, tmr.ALARM_SINGLE, function()
                ultrasonic_sensor.get_distance(function(distance)
                    ok_to_go = distance > 30
                    servo.look_forward()
                    servo_done = true
                end)
            end)
        end
    elseif state == "TURNING_LEFT" then -- Si el estado es TURNING_LEFT se gira hacia la izquierda teniendo en cuenta la cantidad de pulsos generados por el encoder.
        if not running_3 then
            opt_enc.reset_counter()
            motor_control.rotate('left')
            tmr.alarm(3, 10, tmr.ALARM_SEMI, function()
                local count = opt_enc.get_counter()
                if count > turn_pulses then
                    motor_control.stop()
                    motor_done = true
                else
                    tmr.start(3)
                end
            end)
        end
    elseif state == "TURNING_RIGHT" then -- Si el estado es TURNING_RIGHT se gira hacia la derecha teniendo en cuenta la cantidad de pulsos generados por el encoder.
        if not running_3 then
            opt_enc.reset_counter()
            motor_control.rotate('right')
            tmr.alarm(3, 10, tmr.ALARM_SEMI, function()
                local count = opt_enc.get_counter()
                if count > turn_pulses then
                    motor_control.stop()
                    motor_done = true
                else
                    tmr.start(3)
                end
            end)
        end
    elseif state == "TURNING_AROUND" then -- Si el estado es TURNING_AROUND se gira hacia la izquierda hasta girar 180°.
        if not running_3 then
            opt_enc.reset_counter()
            motor_control.rotate('left')
            tmr.alarm(3, 10, tmr.ALARM_SEMI, function()
                local count = opt_enc.get_counter()
                if count > turn_around_pulses then
                    motor_control.stop()
                    motor_done = true
                else
                    tmr.start(3)
                end
            end)
        end
    end
end


-- Tarea automática que genera nuevos eventos en caso de ser necesario
-- cada 100 milisegundos.
tmr.alarm(0, 100, tmr.ALARM_AUTO, function()
    if last_sent_state ~= state then
        add_new_event(pretty_state[state])
        last_sent_state = state
    end
end)



-- Tarea automática que ejecuta la lógica de cambios de estados de la máquina de estados
-- finitos. Para lograrlo, en base al estado actual, el estado anterior y los parámetros de entrada
-- determina cual es el estado siguiente.
tmr.alarm(1, 200, tmr.ALARM_AUTO, function()
    if state == "OFF" then
        if mode == "automatic" then
            last_state = state
            state = "MOVING"
        end
    elseif state == "MOVING" then
        if obstacle and last_state == "TURNING_AROUND" then
            last_state = state
            state = "OFF"
        elseif obstacle then
            last_state = state
            distance_done = false
            obstacle_done = false
            state = "NEED_TO_AVOID"
        end
    elseif state == "NEED_TO_AVOID" then
        if obstacle_done then
            obstacle_done = false
            distance_done = false
            if obstacle then
                state = "AVOIDING"
            else
                state = "MOVING"
            end
        end
    elseif state == "AVOIDING" then
        last_state = state
        if (tmr.now() % 2) == 0 then
            state = "LOOKING_RIGHT"
        else
            state = "LOOKING_LEFT"
        end
    elseif state == "LOOKING_RIGHT" then
        if servo_done then
            servo_done = false
            if ok_to_go then
                last_state = state
                state = "TURNING_RIGHT"
            elseif last_state ~= "LOOKING_LEFT" then
                last_state = state
                state = "LOOKING_LEFT"
            else
                last_state = state
                state = "TURNING_AROUND"
            end
        end
    elseif state == "LOOKING_LEFT" then
        if servo_done then
            servo_done = false
            if ok_to_go then
                last_state = state
                state = "TURNING_LEFT"
            elseif last_state ~= "LOOKING_RIGHT" then
                last_state = state
                state = "LOOKING_RIGHT"
            else
                last_state = state
                state = "TURNING_AROUND"
            end
        end
    elseif state == "TURNING_AROUND" or state == "TURNING_RIGHT" or state == "TURNING_LEFT" then
        if motor_done then
            motor_done = false
            last_state = state
            state = "MOVING"
        end
    end

    -- La función do_state() sólo es llamada cuando el sistema se encuentra funcionando en modo 'automático'
    if mode == "automatic" then
        do_state()
    else
        last_state = state
        state = "OFF"
    end
    
end)



-- Creación de servidor TCP y escucha en el puerto 80 por peticiones de los usuarios.
srv=net.createServer(net.TCP) 
srv:listen(80,function(conn) 
    conn:on("receive",function(conn,payload) 
        -- print(payload)
        local file_to_send = ""
        local file_offset = 0
        
        local _, _, method, path, http_ver = string.find(payload, "^(%u+)%s(.+)%s(HTTP/%d.%d)")


        local function send_file(conn)
            file.open(file_to_send, "r")
            file.seek("set", file_offset)
            data = file.read()
            if data == EOF then
                print("File sent: " .. file_to_send)
                conn:close()
            else
                conn:send(data)
                file_offset = file.seek()
                print(file_to_send .. ": " .. file_offset .. " bytes sent")
            end
            file.close()
        end
        
        if method ~= nil and path ~= nil and http_ver ~= nil then  
            if method == "GET" and path == "/" then
                path = "/index.html"
            end
            path = string.sub(path, 2)
            local file_size = files[path]
            if file_size ~= nil then
                local cache_header = ""
                if file_size > 20480 then
                    cache_header = "Expires: Sun, 17-Jan-2038 19:14:07 GMT\r\n"
                end
                conn:send(http_ver .. " 200 OK\r\nContent-Type: text/html\r\nContent-Length: " .. file_size .. "\r\n" .. cache_header .. "\r\n")
                file_to_send = path
                file_offset = 0
                conn:on("sent", send_file)
            else
                -- En caso de ser requerido el JSON con información del sistema, se genera y se envía con el comando send()
                if path == "events.json" then
                    json = generate_json()
                    conn:send(http_ver .. " 200 OK\r\nContent-type: application/json; charset=utf-8\r\nConnection: close\r\n\r\n" .. json)
                else
                    _, _, action = string.find(path, "^control%?action=(%a+)")
                    if action ~= nil then
                      action = string.lower(action)
                      
                      -- Para cada una de las acciones definidas se ejecutan los comandos correspondientes

                      -- Conmutación del modo automático
                      if action == "toggleautomatic" then
                        if mode == "automatic" then
                          mode = "none"
                          motor_control.stop()
                          relay.switch_off()
                        else
                          mode = "automatic"
                          relay.switch_on()
                        end
                        tmr.stop(3)
                        tmr.stop(2)
                        servo.look_forward()
                        -- Conmutación del modo manual
                      elseif action == "togglemanual" then
                        if mode == "manual" then
                          mode = "none"
                        else
                          mode = "manual"
                        end
                        relay.switch_off()
                        tmr.stop(3)
                        tmr.stop(2)
                        motor_control.stop()

                        -- Acción de mover motores hacia atras.
                      elseif mode == "manual" and action == "backward" then
                        print("Accion: Atras")
                        motor_control.move('backward')
                        -- Acción de mover motores hacia adelante.
                      elseif mode == "manual" and action == "forward" then
                        print("Accion: Adelante")
                        motor_control.move('forward')
                        -- Acción de girar a la izquierda.
                      elseif mode == "manual" and action == "left" then
                        print("Accion: Izquierda")
                        motor_control.rotate_normal('left')
                        -- Acción de girar a la derecha.
                      elseif mode == "manual" and action == "right" then
                        print("Accion: Derecha")
                        motor_control.rotate_normal('right')
                        -- Acción de detener.
                      elseif action == "stop" then
                        print("Accion: Detener")
                        motor_control.stop()
                        -- Acción de conmutar el funcionamiento del ventilador.
                      elseif action == "togglecleaner" then
                        print("Accion: Toggle aspiradora")
                        if mode == "manual" then
                          relay.toggle()
                        end
                      end
                    else
                      conn:send(http_ver .. " 404 Not Found\r\nContent-Length: 0\r\n\r\n")
                    end
                end

                conn:close()
            end
        end
    end) 
end)
