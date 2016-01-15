require 'stomp'
require 'logging'

require 'tdl/transport/remote_broker'
require 'tdl/abstractions/processing_rules'

require 'tdl/serialization/json_rpc_serialization_provider'

module TDL

  class Client

    def initialize(hostname, port, username)
      @hostname = hostname
      @port = port
      @username = username
      @logger = Logging.logger[self]
    end

    def go_live_with(processing_rules)
      begin
        @logger.info 'Starting client.'
        remote_broker = RemoteBroker.new(@hostname, @port, @username)
        remote_broker.subscribe(ApplyProcessingRules.new(processing_rules))

        #DEBT: We should have no timeout here. We could put a special message in the queue
        remote_broker.join(3)
        @logger.info 'Stopping client.'
        remote_broker.close
      rescue Exception => e
        @logger.error "Problem communicating with the broker. #{e.message}"
        raise $! if ENV["RUBY_ENV"] == "test"
      end
    end


    #~~~~ Queue handling policies

    class ApplyProcessingRules
      def initialize(processing_rules)
        @processing_rules = processing_rules
        @logger = Logging.logger[self]
        @audit = AuditStream.new
      end

      def process_next_request_from(remote_broker, request)
        @audit.start_line
        @audit.log(request)

        begin
          processing_rule = @processing_rules.get_rule_for(request)
          user_implementation = processing_rule.user_implementation
          result = user_implementation.call(*request.params)

          should_publish = false
          if processing_rule.client_action.include? 'publish'
            should_publish = true
          end

          should_continue = false
          unless processing_rule.client_action.include? 'stop'
            should_continue = true
          end
        rescue Exception => e
          @logger.info "The user implementation has thrown exception. #{e.message}"
          result = 'empty'
          should_publish = false
          should_continue = false
          raise $! if ENV['RUBY_ENV'] == 'test'
        end


        response = Response.new(request, result)

        @audit.log(response)

        if should_publish
        else
          @logger.info "id = #{request.id}, req = #{request.method}(#{request.params.join(', ')}), resp = #{response.result} (NOT PUBLISHED)"
        end

        if should_publish
          remote_broker.respond_to(request, with(response))
        end


        # @audit.log(action)
        @audit.end_line

        unless should_continue
          remote_broker.close
        end
      end

      def with(object)
        object
      end
    end


    # ~~~~ Utils

    class AuditStream

      def initialize
        @logger = Logging.logger[self]
        start_line
      end

      def start_line
        @str = ''
      end

      def log(auditable)
        text = auditable.audit_text
        if not text.empty? and @str.length > 0
          @str << ', '
        end

        @str << text
      end

      def end_line
        @logger.info @str
      end

    end

  end
end
