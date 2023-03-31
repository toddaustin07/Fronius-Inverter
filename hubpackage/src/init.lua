--[[
  Copyright 2023 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  Fronius Inverter driver

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"                 -- just for time
local socket = require "cosock.socket"          -- just for time
local comms = require "comms"
local parser = require "parser"
local log = require "log"

-- Module variables
local thisDriver = {}
local initialized = false

-- Constants
local DEVICE_PROFILE = 'fronius.v1'

-- Custom capabilities
local cap_load = capabilities["partyvoice23922.froniusload"]
local cap_draw = capabilities["partyvoice23922.froniusdraw"]
local cap_discharge = capabilities["partyvoice23922.froniusdischarge"]
local cap_autonomy = capabilities["partyvoice23922.froniusselfgen"]
local cap_consumed = capabilities["partyvoice23922.froniusselfconsumed"]


local function update_device(device, data)

  if data then
    device:emit_event(capabilities.powerMeter.power(data.power))
    device:emit_event(cap_load.load(data.load))
    device:emit_event(cap_draw.draw(data.draw))
    device:emit_event(cap_discharge.discharge(data.discharge))
    device:emit_event(capabilities.battery.battery(data.battery))
    device:emit_event(cap_autonomy.selfgen(data.autonomy))
    device:emit_event(cap_consumed.selfconsumed(data.consumed))
    
  end

end


local function do_refresh(device)

  local method, url = comms.validate(device.preferences.request)
  if method and url then
  
    local ret, response = comms.issue_request(device, method, url, nil, nil)
    
    if ret == 'OK' then
      update_device(device, parser.parsedata(response))
    end
    
  else
    log.warn('Invalid configured request string')
  end
end


local function setup_periodic_refresh(driver, device)

  if device:get_field('refreshtimer') then
    driver:cancel_timer(device:get_field('refreshtimer'))
  end

  local refreshtimer = driver:call_on_schedule(device.preferences.refreshfreq, function()
      do_refresh(device)
    end)
    
  device:set_field('refreshtimer', refreshtimer)

end

-----------------------------------------------------------------------
--										COMMAND HANDLERS
-----------------------------------------------------------------------

local function handle_refresh(_, device, command)

  do_refresh(device)
  
end

------------------------------------------------------------------------
--                REQUIRED EDGE DRIVER HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
  log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")

  device.thread:queue_event(do_refresh, device)
  
  setup_periodic_refresh(driver, device)
  
  initialized = true
  
end


-- Called when device was just created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")

  local init_data = {
			  ['power'] = 0,
			  ['load'] = 0,
			  ['draw'] = 0,
			  ['discharge'] = 0,
			  ['battery'] = 0,
        ['autonomy'] = 0,
			  ['consumed'] = 0
			}
  
  update_device(device, init_data)
  
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  -- Nothing to do here!

end


-- Called when device was deleted via mobile app
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  driver:cancel_timer(device:get_field('refreshtimer'))
  
  initialized = false
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end

local function shutdown_handler(driver, event)

  log.info ('*** Driver being shut down ***')

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

  -- Did preferences change?
  if args.old_st_store.preferences then
  
    if args.old_st_store.preferences.request ~= device.preferences.request then 
      log.info ('Request string changed to: ', device.preferences.request)
      
      device.thread:queue_event(do_refresh, device)
      
    elseif args.old_st_store.preferences.refreshfreq ~= device.preferences.refreshfreq then 
      log.info ('Refresh fequency changed to: ', device.preferences.refreshfreq)
      
      setup_periodic_refresh(driver, device)
    end
  else
    log.warn ('Old preferences missing')
  end  
     
end


-- Create Device
local function discovery_handler(driver, _, should_continue)

  if not initialized then

    log.info("Creating device")

    local MFG_NAME = 'TAUSTIN'
    local MODEL = 'FroniusV1'
    local VEND_LABEL = 'Fronius Inverter V1'
    local ID = 'FoniusV1' .. tostring(socket.gettime())
    local PROFILE = DEVICE_PROFILE

    -- Create master creator device

    local create_device_msg = {
                                type = "LAN",
                                device_network_id = ID,
                                label = VEND_LABEL,
                                profile = PROFILE,
                                manufacturer = MFG_NAME,
                                model = MODEL,
                                vendor_provided_label = VEND_LABEL,
                              }

    assert (driver:try_create_device(create_device_msg), "failed to create device")

    log.debug("Exiting device creation")

  else
    log.info ('Fronius device already created')
  end
end


-----------------------------------------------------------------------
--        DRIVER MAINLINE: Build driver context table
-----------------------------------------------------------------------
thisDriver = Driver("thisDriver", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    driverSwitched = handler_driverchanged,
    infoChanged = handler_infochanged,
    doConfigure = device_doconfigure,
    removed = device_removed
  },
  driver_lifecycle = shutdown_handler,
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh,
    },
  }
})

log.info ('Fronius Inverter v1.0 Started')

thisDriver:run()
