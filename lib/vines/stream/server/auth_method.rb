# encoding: UTF-8

module Vines
  class Stream
    class Server
      class AuthMethod < State
        STARTTLS, RESULT, FROM, TO = %w[starttls result from to].map {|s| s.freeze }
        PROCEED  = %Q{<proceed xmlns="#{NS}"/>}.freeze
        FAILURE  = %Q{<failure xmlns="#{NS}"/>}.freeze

        def initialize(stream, success=AuthDialbackResult)
          super
        end

        def node(node)
          if dialback?(node) && !tls_required?(node)
            begin
              Vines::Stream::Server.start(stream.config, node[FROM], node[TO]) do |s|
                s ? s.write("<db:verify from='#{node[FROM]}' id='#{s.id}' to='#{node[TO]}'>#{node.text}</db:verify>")
              end
              advance
            rescue StanzaErrors::RemoteServerNotFound => e
              stream.write("<db:result from='#{node[FROM]}' to='#{node[TO]}' type='error'><error type='cancel'><item-not-found xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/></error></db:result>")
              stream.close_connection_after_writing
            end
          elsif starttls?(node)
            @success = AuthRestart
            if stream.encrypt?
              stream.write(PROCEED)
              stream.encrypt
              stream.reset
              advance
            else
              stream.write(FAILURE)
              stream.write('</stream:stream>')
              stream.close_connection_after_writing
            end
          else
            raise StreamErrors::NotAuthorized
          end
        end

        private

        def tls_required?(node)
          child = node.xpath('ns:starttls', 'ns' => NAMESPACES[:tls]).children.first
          !child.nil? && child.name == REQUIRED
        end

        def starttls?(node)
          node.name == STARTTLS && namespace(node) == NAMESPACES[:tls]
        end

        def dialback?(node)
          node.name == RESULT && namespace(node) == NAMESPACES[:legacy_dialback]
        end
      end
    end
  end
end
