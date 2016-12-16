-- Set module name as parameter of require
local modname = 'ultrasonic_sensor'
local M = {}
_G[modname] = M

local hcsr04 = hcsr04

-- Limited to local environment
setfenv(1,M)

local trigger_pin = 0
local echo_pin = 5
local callback_function = nil

-- Configura el módulo hcsr04, con los pines definidos en las
-- variables correspondientes.
-- La función de callback es una función que llamará a la
-- función de Lua definida por el método get_distance(), 
-- pasándole la distancia medida en centímetros.
function setup()
  hcsr04.setup(trigger_pin, echo_pin, function(distance)
        if callback_function ~= nil then
            callback_function(distance / 10)
        end
  end)
end

-- Establece la función de callback definida en el argumento
-- como función a llamar cuando se realice la medición, la
-- cual es desencadenada por este método.
function get_distance(callback)
  callback_function = callback
  hcsr04.trigger()
end


return M
