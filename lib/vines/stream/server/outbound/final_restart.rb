# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class FinalRestart < State
          def initialize(stream, success=FinalFeatures)
            super
          end

          def node(node)
            unless stream?(node)
              puts "Outbound FinalRestart"
              raise StreamErrors::NotAuthorized
            end
            advance
          end
        end
      end
    end
  end
end
