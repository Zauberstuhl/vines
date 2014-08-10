# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class Start < State
          def initialize(stream, success=TLS)
            super
          end

          def node(node)
            unless stream?(node)
              puts "Start"
              raise StreamErrors::NotAuthorized
            end
            advance
          end
        end
      end
    end
  end
end
