# encoding: UTF-8

module Vines
  class Stream
    class Server
      class AuthDialbackResult < State
        VALID, INVALID, ERROR, TYPE = %w[valid invalid error type]
        VERIFY, ID, FROM, TO = %w[verify id from to].map {|s| s.freeze }

        def initialize(stream, success=Ready)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless node.name == VERIFY

          if node[TYPE] == ERROR
            stream.write("<db:result from='#{node[FROM]}' to='#{node[TO]}' type='#{ERROR}'><error type='cancel'><item-not-found xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/></error></db:result>")
            stream.close_connection_after_writing
          else
            stream.write("<db:result from='#{node[FROM]}' to='#{node[TO]}' type='valid'/>")
            advance
          end
        end
      end
    end
  end
end
