require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::PortStatusAgent do
  before(:each) do
    @valid_options = Agents::PortStatusAgent.new.default_options
    @checker = Agents::PortStatusAgent.new(:name => "PortStatusAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
