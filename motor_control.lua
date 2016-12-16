local modname = 'motor_control'
local M = {}
_G[modname] = M

local pwm = pwm

-- Limited to local environment
setfenv(1,M)

-- Define tablas en las que se almacenará la información de los motores.
local left_motor = {}
local right_motor = {}

-- Define los ciclos de trabajo por defecto para los motores
-- En movimiento hacia adelante y hacia atrás de 500 y en giros 450.
local default_duty_cycle = 500
local default_duty_cycle_on_turning = 450


-- Define los pines GPIO de los PWM para ambos motores

left_motor['pwm1_gpio'] = 4
left_motor['pwm2_gpio'] = 3
left_motor['pwm1_duty_cycle'] = 0
left_motor['pwm2_duty_cycle'] = 0

right_motor['pwm1_gpio'] = 2
right_motor['pwm2_gpio'] = 1
right_motor['pwm1_duty_cycle'] = 0
right_motor['pwm2_duty_cycle'] = 0


-- Método que configura los parámetros anteriormente seteados y define la frecuencia de
-- las señales de PWM
function setup()
    pwm.setup(left_motor['pwm1_gpio'], 500, left_motor['pwm1_duty_cycle'])
    pwm.setup(left_motor['pwm2_gpio'], 500, left_motor['pwm2_duty_cycle'])
    pwm.start(left_motor['pwm1_gpio'])
    pwm.start(left_motor['pwm2_gpio'])
    
    
    pwm.setup(right_motor['pwm1_gpio'], 500, right_motor['pwm1_duty_cycle'])
    pwm.setup(right_motor['pwm2_gpio'], 500, right_motor['pwm2_duty_cycle'])
    pwm.start(right_motor['pwm1_gpio'])
    pwm.start(right_motor['pwm2_gpio'])
end


-- Método que recibe como parámetro un sentido: 'right' | 'left' , que permite al robor girar en esos sentidos
function rotate_normal(direction)
  if direction == 'right' then
    pwm.setduty(right_motor['pwm1_gpio'], 0)
    pwm.setduty(right_motor['pwm2_gpio'], 0)
    pwm.setduty(left_motor['pwm1_gpio'], 0)
    pwm.setduty(left_motor['pwm2_gpio'], default_duty_cycle_on_turning)
  elseif direction == 'left' then
    pwm.setduty(left_motor['pwm1_gpio'], 0)
    pwm.setduty(left_motor['pwm2_gpio'], 0)
    pwm.setduty(right_motor['pwm1_gpio'], 0)
    pwm.setduty(right_motor['pwm2_gpio'], default_duty_cycle_on_turning)
  end
end


-- Método similar al anterior. La diferencia está en que siempre gira utilizando una sola rueda.
-- Se utiliza para poder determinar cuánto se gira, utilizando el único encoder del sistema.
function rotate(direction)
  if direction == 'right' then
    pwm.setduty(right_motor['pwm1_gpio'], 0)
    pwm.setduty(right_motor['pwm2_gpio'], 0)
    pwm.setduty(left_motor['pwm1_gpio'], 0)
    pwm.setduty(left_motor['pwm2_gpio'], default_duty_cycle_on_turning)
  elseif direction == 'left' then
    pwm.setduty(right_motor['pwm1_gpio'], 0)
    pwm.setduty(right_motor['pwm2_gpio'], 0)
    pwm.setduty(left_motor['pwm2_gpio'], 0)
    pwm.setduty(left_motor['pwm1_gpio'], default_duty_cycle_on_turning)
  end
end


-- Detiene todos los motores.
function stop()
  pwm.setduty(right_motor['pwm1_gpio'], 0)
  pwm.setduty(right_motor['pwm2_gpio'], 0)
  pwm.setduty(left_motor['pwm1_gpio'], 0)
  pwm.setduty(left_motor['pwm2_gpio'], 0)
end


-- Método que permite mover hacia atrás y adelante el robot. Recibe como parámetro una dirección: 'forward' | 'backward'
function move(direction)
  if direction == 'forward' then
    pwm.setduty(right_motor['pwm1_gpio'], 0)
    pwm.setduty(right_motor['pwm2_gpio'], default_duty_cycle)
    pwm.setduty(left_motor['pwm1_gpio'], 0)
    pwm.setduty(left_motor['pwm2_gpio'], default_duty_cycle)
  elseif direction == 'backward' then
    pwm.setduty(left_motor['pwm2_gpio'], 0)
    pwm.setduty(left_motor['pwm1_gpio'], default_duty_cycle)
    pwm.setduty(right_motor['pwm2_gpio'], 0)
    pwm.setduty(right_motor['pwm1_gpio'], default_duty_cycle)
  end
end

return M
