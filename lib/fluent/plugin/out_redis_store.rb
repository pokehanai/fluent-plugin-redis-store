module Fluent
  class RedisStoreOutput < BufferedOutput
    Fluent::Plugin.register_output('redis_store', self)

    # redis connection
    config_param :host,      :string,  :default => '127.0.0.1'
    config_param :port,      :integer, :default => 6379
    config_param :path,      :string,  :default => nil
    config_param :password,  :string,  :default => nil
    config_param :db,        :integer, :default => 0
    config_param :timeout,   :float,   :default => 5.0

    # redis command and parameters
    config_param :format_type,       :string,  :default => 'json'
    config_param :store_type,        :string,  :default => 'zset'
    config_param :key_prefix,        :string,  :default => ''
    config_param :key_suffix,        :string,  :default => ''
    config_param :key,               :string,  :default => nil
    config_param :key_path,          :string,  :default => nil
    config_param :score_path,        :string,  :default => nil
    config_param :value_path,        :string,  :default => ''
    config_param :key_expire,        :integer, :default => -1
    config_param :value_expire,      :integer, :default => -1
    config_param :value_length,      :integer, :default => -1
    config_param :order,             :string,  :default => 'asc'
    config_param :collision_policy,  :string,  :default => nil
    config_set_default :flush_interval, 1

    def initialize
      super
      require 'redis'
      require 'msgpack'
    end

    def configure(conf)
      super

      if @key_path == nil and @key == nil
        raise Fluent::ConfigError, "either key_path or key is required"
      end
    end

    def start
      super
      if @path
        @redis = Redis.new(:path => @path, :password => @password,
                           :timeout => @timeout, :thread_safe => true, :db => @db)
      else
        @redis = Redis.new(:host => @host, :port => @port, :password => @password,
                           :timeout => @timeout, :thread_safe => true, :db => @db)
      end
    end

    def shutdown
      @redis.quit
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      @redis.pipelined {
        chunk.open { |io|
          begin
            MessagePack::Unpacker.new(io).each { |message|
              begin
                (tag, time, record) = message
                case @store_type
                when 'zset'
                  operation_for_zset(record, time)
                when 'set'
                  operation_for_set(record)
                when 'list'
                  operation_for_list(record)
                when 'string'
                  operation_for_string(record)
                when 'publish'
                  operation_for_publish(record)
                end
              rescue NoMethodError => e
                puts e
              end
            }
          rescue EOFError
            # EOFError always occured when reached end of chunk.
          end
        }
      }
    end

    def operation_for_zset(record, time)
      key = get_key_from(record)
      value = get_value_from(record)
      score = get_score_from(record, time)
      if @collision_policy
        if @collision_policy == 'NX'
          @redis.zadd(key, score, value, :nx => true)
        elsif @collision_policy == 'XX'
          @redis.zadd(key, score, value, :xx => true)
        end
      else
        @redis.zadd(key, score, value)
      end

      set_key_expire key
      if 0 < @value_expire
        now = Time.now.to_i
        @redis.zremrangebyscore key , '-inf' , (now - @value_expire)
      end
      if 0 < @value_length
        script = generate_zremrangebyrank_script(key, @value_length, @order)
        @redis.eval script
      end
    end

    def operation_for_set(record)
      key = get_key_from(record)
      value = get_value_from(record)
      @redis.sadd key, value
      set_key_expire key
    end

    def operation_for_list(record)
      key = get_key_from(record)
      value = get_value_from(record)

      if @order == 'asc'
        @redis.rpush key, value
      else
        @redis.lpush key, value
      end
      set_key_expire key
      if 0 < @value_length
        script = generate_ltrim_script(key, @value_length, @order)
        @redis.eval script
      end
    end

    def operation_for_string(record)
      key = get_key_from(record)
      value = get_value_from(record)
      @redis.set key, value

      set_key_expire key
    end

    def operation_for_publish(record)
      key = get_key_from(record)
      value = get_value_from(record)
      @redis.publish key, value
    end

    def generate_zremrangebyrank_script(key, maxlen, order)
      script  = "local key = '" + key.to_s + "'\n"
      script += "local maxlen = " + maxlen.to_s + "\n"
      script += "local order ='" + order.to_s + "'\n"
      script += "local len = tonumber(redis.call('ZCOUNT', key, '-inf', '+inf'))\n"
      script += "if len > maxlen then\n"
      script += "    if order == 'asc' then\n"
      script += "       local l = len - maxlen\n"
      script += "       if l >= 0 then\n"
      script += "           return redis.call('ZREMRANGEBYRANK', key, 0, l)\n"
      script += "       end\n"
      script += "    else\n"
      script += "       return redis.call('ZREMRANGEBYRANK', key, maxlen, -1)\n"
      script += "    end\n"
      script += "end\n"
      return script
    end

    def generate_ltrim_script(key, maxlen, order)
      script  = "local key = '" + key.to_s + "'\n"
      script += "local maxlen = " + maxlen.to_s + "\n"
      script += "local order ='" + order.to_s + "'\n"
      script += "local len = tonumber(redis.call('LLEN', key))\n"
      script += "if len > maxlen then\n"
      script += "    if order == 'asc' then\n"
      script += "        local l = len - maxlen\n"
      script += "        return redis.call('LTRIM', key, l, -1)\n"
      script += "    else\n"
      script += "        return redis.call('LTRIM', key, 0, maxlen - 1)\n"
      script += "    end\n"
      script += "end\n"
      return script
    end

    def traverse(data, key)
      val = data
      key.split('.').each{ |k|
        if val.has_key?(k)
          val = val[k]
        else
          return nil
        end
      }
      return val
    end

    def get_key_from(record)
      if @key
        k = @key
      else
        k = traverse(record, @key_path).to_s
      end
      key = @key_prefix + k + @key_suffix

      raise Fluent::ConfigError, "key is empty" if key == ''
      key
    end

    def get_value_from(record)
      value = traverse(record, @value_path)
      case @format_type
      when 'json'
        value.to_json
      when 'msgpack'
        value.to_msgpack
      else
        value
      end
    end

    def get_score_from(record, time)
      if @score_path
        traverse(record, @score_path)
      else
        time
      end
    end

    def set_key_expire(key)
      if 0 < @key_expire
        @redis.expire key, @key_expire
      end
    end

  end
end
