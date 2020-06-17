require 'huginn_agent'
require 'timeout'

#HuginnAgent.load 'huginn_port_status_agent/concerns/my_agent_concern'
HuginnAgent.register 'huginn_port_status_agent/port_status_agent'
