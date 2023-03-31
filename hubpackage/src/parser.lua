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
  
  Fronius Inverter return data parser module

--]]

local log = require "log"
local json = require "dkjson"

return {

  parsedata = function(response)
  
    local dataobj, pos, err = json.decode (response, 1, nil)
    if err then
      log.error ("JSON decode error:", err)
      return nil
    end
    
    local parsed_data = {
			  ['power'] = 0,
			  ['load'] = 0,
			  ['draw'] = 0,
			  ['discharge'] = 0,
			  ['battery'] = 0,
			  ['autonomy'] = 0,
			  ['consumed'] = 0
			}
    
    -- all data received as watts
    
    if type(dataobj.Body.Data.Site.P_PV) == 'number' then
      parsed_data['power'] = math.floor(dataobj.Body.Data.Site.P_PV * 1000) / 1000
    end
    
    if type(dataobj.Body.Data.Site.P_Load) == 'number' then
      parsed_data['load'] = math.floor(dataobj.Body.Data.Site.P_Load) / 1000	-- convert to kWatts
    end
    
    if type(dataobj.Body.Data.Site.P_Grid) == 'number' then
      parsed_data['draw'] = math.floor(dataobj.Body.Data.Site.P_Grid) / 1000	-- convert to kWatts
    end
    
    if type(dataobj.Body.Data.Site.P_Akku) == 'number' then
      parsed_data['discharge'] = math.floor(dataobj.Body.Data.Site.P_Akku / 1000)	-- convert to kWatts
    end
    
    if type(dataobj.Body.Data.Inverters['1'].SOC) == 'number' then
      parsed_data['battery'] = math.floor(dataobj.Body.Data.Inverters['1'].SOC + .5)
    end

    if type(dataobj.Body.Data.Site.rel_Autonomy) == 'number' then
      parsed_data['autonomy'] = dataobj.Body.Data.Site.rel_Autonomy
    end

    if type(dataobj.Body.Data.Site.rel_SelfConsumption) == 'number' then
      parsed_data['consumed'] = dataobj.Body.Data.Site.rel_SelfConsumption
    end

    return parsed_data

  end

}
