# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class Auth < State
          NS = NAMESPACES[:sasl]

          def initialize(stream, success=AuthResult)
            super
          end

          def node(node)
            unless external?(node)
              puts "Auth:#{node.to_yaml}"
              raise StreamErrors::NotAuthorized
            end
            authzid = Base64.strict_encode64(stream.domain)
            stream.write(%Q{<auth xmlns="#{NS}" mechanism="EXTERNAL">#{authzid}</auth>})
            advance
          end

          private

          def external?(node)
            external = node.xpath("ns:mechanisms/ns:mechanism[text()='EXTERNAL']", 'ns' => NS).any?
            puts "Auth: external => #{external}"
            node.name == 'features' && namespace(node) == NAMESPACES[:stream] && external
          end
        end
      end
    end
  end
end
