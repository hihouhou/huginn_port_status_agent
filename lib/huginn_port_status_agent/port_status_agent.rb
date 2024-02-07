module Agents
  class PortStatusAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The agent checks a port (TCP) for a specific host.

      `target` is the wanted host you want to scan.

      `debug` is used for verbose mode.

      `timeout` is the delay to validate the status for a port.

      `min_port` is the starting point for the list of ports to be scanned.

      `max_port` is the end of the list of ports to be scanned.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "ip": "127.0.0.1",
            "port": "443",
            "status": "closed"
          }
    MD

    def default_options
      {
        'target' => '',
        'min_port' => '1',
        'max_port' => '1024',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'timeout_sec' => '1',
        'changes_only' => 'true'
      }
    end

    form_configurable :debug, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :target, type: :string
    form_configurable :min_port, type: :number
    form_configurable :max_port, type: :number
    form_configurable :timeout_sec, type: :string
    form_configurable :changes_only, type: :boolean

    def validate_options
      unless options['target'].present?
        errors.add(:base, "target is a required field")
      end

      unless options['min_port'].present?
        errors.add(:base, "min_port is a required field")
      end

      unless options['max_port'].present?
        errors.add(:base, "max_port is a required field")
      end

      if options['min_port'] > options['max_port']
        errors.add(:base, "min_port must be lower than max_port")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      unless options['timeout_sec'].present?
        errors.add(:base, "timeout_sec is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def scanport(port)
            s = Socket.new Socket::AF_INET, Socket::SOCK_STREAM
            begin
                    sockaddr = Socket.pack_sockaddr_in(port, interpolated['target'])
            rescue
                    puts "[!] Error: Failed to Resolve Target"
                    exit
            end
            Timeout::timeout(interpolated['timeout']) do
                    begin
                            @result = s.connect(sockaddr)
                            return port
                    rescue
                            return false
                    end
            end
    end

    def fetch()

      ports_info = {}
      to_scan = ((interpolated['min_port'])..(interpolated['max_port'])).to_a
      if interpolated['debug'] == 'true'
        log "port's list to scan"
        log to_scan
      end
      to_scan.each do |port|
        if result = scanport(port)
          ports_info[result] = "open"
        end
      end

      final_result = {'ports' => ports_info}
      if final_result != memory['last_status']
        final_result["ports"].each do |port, status|
          found = false
          if !memory['last_status'].nil? and memory['last_status'].present?
            last_status = memory['last_status']
            if interpolated['debug'] == 'true'
              log "last_status"
              log last_status
            end
            last_status["ports"].each do |portbis, statusbis|
              if port == portbis && status == statusbis
                found = true
                if interpolated['debug'] == 'true'
                  log "found is #{found}"
                end
              end
            end
          end
          if found == false
            create_event payload: { 'target' => interpolated['target'], 'port' => port, 'status' => status }
          else
            if interpolated['debug'] == 'true'
              log "found is #{found}"
            end
          end
        end
        memory['last_status'] = final_result
      else
        if interpolated['debug'] == 'true'
          log "no diff"
        end
      end

    end
  end
end
