# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class AuthDialbackResult < State
          RESULT, VALID, INVALID, TYPE = %w[db:result valid invalid type].map {|s| s.freeze }

          attr_accessor :dialback_secret

          def initialize(stream, success=Ready)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized if node.name != RESULT

            case node[TYPE]
            when VALID
              advance
              stream.notify_connected
            when INVALID
              stream.close_connection
            else
              raise StreamErrors::NotAuthorized
            end
          end
        end
      end
    end
  end
end
