module Agents
  class PortStatusAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The agent checks a port (TCP) for a specific host.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

      <pre><code>{
        "ip": "127.0.0.1",
        "port": "443",
        "status": "closed"
      }</code></pre>
    MD

    def default_options
      {
        'ip' => '',
        'port' => '',
        'expected_receive_period_in_days' => '2',
        'timeout_sec' => '1',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :ip, type: :string
    form_configurable :port, type: :string
    form_configurable :timeout_sec, type: :string
    form_configurable :changes_only, type: :boolean

    def validate_options
      unless options['ip'].present?
        errors.add(:base, "ip is a required field")
      end

      unless options['port'].present?
        errors.add(:base, "port is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      unless options['timeout_sec'].present?
        errors.add(:base, "timeout_sec is a required field")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      memory['last_status'].to_i > 0

      return false if recent_error_logs?
      
      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def check
      port_open? interpolated['ip'], interpolated[:port].to_i, interpolated[:timeout_sec].to_i
    end

    private

    def port_open?(ip, port, seconds)
      Timeout::timeout(seconds) do
        begin
          TCPSocket.new(ip, port).close
          port_status = 'opened'
          log "port #{port} opened on #{ip}"
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          log "port #{port} closed on #{ip}"
          port_status = 'closed'
        end
        payload = { 'ip' => "#{ip}", 'port' => "#{port}", 'status' => "#{port_status}" }

        if interpolated['changes_only'] == 'true'
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
            create_event payload: payload
          end
        else
          create_event payload: payload
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
          end
        end
      end
    rescue Timeout::Error
      false
    end
  end
end
