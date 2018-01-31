require 'dalli'

module Jive
    module Cache
        class Memcache
            def initialize(host, opts={})
                @client = Dalli::Client.new(host, opts)
            end

            def set(k,v)
                @client.set(k,v)
            end

            def get(k)
                @client.get(k)
            end
            
            def has_key?(k)
                 @client.has_key?(k)
            end
        end

        class Hashcache
            def initialize(*)
                @cache_hash = {}
            end

            def set(k,v)
                @cache_hash[k] = v
            end

            def get(k)
                @cache_hash[k]
            end

            def has_key?(k)
                @cache_hash.has_key? k
            end
        end
        PROVIDERS = {
            memcache: Memcache,
            hashcache: Hashcache
        }
    end
end