module Agents
  class PortStatusAgent < Agent
    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The agent checks a port (TCP) for a specific host.
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
        'timeout_sec' => '1',
        'changes_only' => 'true'
      }
    end

    def validate_options
      unless options['ip'].present?
        errors.add(:base, "ip is a required field")
      end

      unless options['port'].present?
        errors.add(:base, "port is a required field")
      end

      unless options['timeout_sec'].present?
        errors.add(:base, "timeout_sec is a required field")
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
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
