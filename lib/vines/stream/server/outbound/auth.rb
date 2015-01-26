# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class Auth < State
          NS = NAMESPACES[:tls]
          REQUIRED = 'required'.freeze

          def initialize(stream, success=TLSResult)
            super
          end

          def node(node)
            if dialback?(node) && !tls_required?(node)
              @success = AuthDialbackResult
              secret = Kit.auth_token
              dialback_key = Kit.dialback_key(secret, stream.remote_domain, stream.domain, stream.id)
              stream.write(%Q(<db:result from="#{stream.domain}" to="#{stream.remote_domain}">#{dialback_key}</db:result>))
              advance
              stream.router << stream # We need to be discoverable for the dialback connection
              stream.state.dialback_secret = secret
            elsif tls?(node)
              stream.write("<starttls xmlns='#{NS}'/>")
              advance
            else
              raise StreamErrors::NotAuthorized
            end
          end

          private

          def tls_required?(node)
            child = node.xpath('ns:starttls', 'ns' => NS).children.first
            !child.nil? && child.name == REQUIRED
          end

          def dialback?(node)
            dialback = node.xpath('ns:dialback', 'ns' => NAMESPACES[:dialback]).any?
            features?(node) && dialback
          end

          def tls?(node)
            tls = node.xpath('ns:starttls', 'ns' => NS).any?
            features?(node) && tls
          end

          def features?(node)
            node.name == 'features' && namespace(node) == NAMESPACES[:stream]
          end
        end
      end
    end
  end
end
