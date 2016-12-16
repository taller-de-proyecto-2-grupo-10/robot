local modname = 'relay'
local M = {}
_G[modname] = M

local gpio = gpio

-- Limited to local environment
setfenv(1,M)

local relay_pin = 10

-- Configura el pin de control como salida y lo pone en ALTO
function setup()
  --setup relay pin
  gpio.mode(relay_pin, gpio.OUTPUT)
  gpio.write(relay_pin, gpio.HIGH)
end

-- Prende el relay, cierra el circuito en bornes
function switch_on()
  gpio.write(relay_pin, gpio.LOW)
end

-- Apaga el relay, abre el circuito en bornes
function switch_off()
  gpio.write(relay_pin, gpio.HIGH)
end

-- Si el relay está prendido, lo apaga, de lo contrario lo
-- enciende
function toggle()
  if gpio.read(relay_pin) == gpio.HIGH then
	gpio.write(relay_pin, gpio.LOW)
  else
	gpio.write(relay_pin, gpio.HIGH)
  end
end

-- Devuelve si el circuito en bornes del relay está cerrado
-- o no.
function is_enabled()
	return (gpio.read(relay_pin) == gpio.LOW)
end

return M
