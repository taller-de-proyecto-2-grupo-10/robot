-- Set module name as parameter of require
local modname = 'servo'
local M = {}
_G[modname] = M

local tmr = tmr
local pwm = pwm

-- Limited to local environment
setfenv(1,M)

local servo_pin = 7

-- Valores de contador para el PWM, obtenidos empíricamente,
-- para ser utilizados en la orientación del servo.
local position = {}
position['forward'] = 69
position['right'] = 26 
position['left'] = 120

-- Se configura el pin como PWM, y se provoca que el servo
-- mire hacia adelante.
function setup()
  pwm.setup(servo_pin, 50, position['forward'])
  pwm.start(servo_pin)
end

-- Gira hacia la posición de 0°
function look_forward()
  pwm.setduty(servo_pin, position['forward'])
end

-- Gira hacia derecha 90°
function look_right()
  pwm.setduty(servo_pin, position['right'])
end

-- Gira hacia la izquierda 90°
function look_left()
  pwm.setduty(servo_pin, position['left'])
end

return M
