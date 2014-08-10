# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class TLSResult < State
          NS      = NAMESPACES[:tls]
          PROCEED = 'proceed'.freeze
          FAILURE = 'failure'.freeze

          def initialize(stream, success=AuthRestart)
            super
          end

          def node(node)
            unless namespace(node) == NS
              puts "TLSResult"
              raise StreamErrors::NotAuthorized
            end
            case node.name
            when PROCEED
              stream.encrypt
              stream.start(node)
              stream.reset
              advance
            when FAILURE
              stream.close_connection
            else
              puts "TLSResult: else"
              raise StreamErrors::NotAuthorized
            end
          end
        end
      end
    end
  end
end
