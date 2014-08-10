# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class AuthResult < State
          SUCCESS = 'success'.freeze
          FAILURE = 'failure'.freeze

          def initialize(stream, success=FinalRestart)
            super
          end

          def node(node)
            unless namespace(node) == NAMESPACES[:sasl]
              puts "Outbound AuthResult"
              raise StreamErrors::NotAuthorized
            end
            case node.name
            when SUCCESS
              stream.start(node)
              stream.reset
              advance
            when FAILURE
              stream.close_connection
            else
              puts "Outbound AuthResult: else"
              raise StreamErrors::NotAuthorized
            end
          end
        end
      end
    end
  end
end
