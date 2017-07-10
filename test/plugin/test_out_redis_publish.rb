require 'helpers'

require 'redis'

$channel = nil
$message = nil

class Redis
  def initialize(options = {})
  end

  def pipelined
    yield self
  end

  def set(key, message)
    $command = :set
    $key = key
    $message = message
  end

  def rpush(key, message)
    $command = :rpush
    $key = key
    $message = message
  end

  def lpush(key, message)
    $command = :lpush
    $key = key
    $message = message
  end

  def sadd(key, message)
    $command = :sadd
    $key = key
    $message = message
  end

  def zadd(key, score, message)
    $command = :zadd
    $key = key
    $score = score
    $message = message
  end

  def expire(key, ttl)
    $expire_key = key
    $ttl = ttl
  end

  def publish(channel, message)
    $command = :publish
    $channel = channel
    $message = message
  end

  def quit
  end
end

class RedisStoreOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  def create_driver(conf)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::RedisStoreOutput).configure(conf)
  end

  def test_configure_defaults
    config = %[
      key_path a
      score_path b
    ]
    d = create_driver(config)
    assert_equal "127.0.0.1", d.instance.host
    assert_equal 6379, d.instance.port
    assert_equal nil, d.instance.path
    assert_equal nil, d.instance.password
    assert_equal 0, d.instance.db
    assert_equal 5.0, d.instance.timeout
    assert_equal 'json', d.instance.format_type
    assert_equal '', d.instance.key_prefix
    assert_equal '', d.instance.key_suffix
    assert_equal 'zset', d.instance.store_type
    assert_equal 'a', d.instance.key_path
    assert_equal nil, d.instance.key
    assert_equal 'b', d.instance.score_path
    assert_equal '', d.instance.value_path
    assert_equal -1, d.instance.key_expire
    assert_equal -1, d.instance.value_expire
    assert_equal -1, d.instance.value_length
    assert_equal 'asc', d.instance.order
    assert_equal nil, d.instance.collision_policy
  end

  def test_configure_host_port_db
    config = %[
      host 192.168.2.3
      port 9999
      password abc
      db 3
      timeout 7
      key a
      score_path b
    ]
    d = create_driver(config)
    assert_equal "192.168.2.3", d.instance.host
    assert_equal 9999, d.instance.port
    assert_equal nil, d.instance.path
    assert_equal 'abc', d.instance.password
    assert_equal 3, d.instance.db
    assert_equal 7.0, d.instance.timeout
    assert_equal nil, d.instance.key_path
    assert_equal 'a', d.instance.key
  end

  def test_configure_path
    config = %[
      path /tmp/foo.sock
      key a
      score_path b
    ]
    d = create_driver(config)
    assert_equal "/tmp/foo.sock", d.instance.path
  end

  def test_configure_exception
    assert_raise(Fluent::ConfigError) do
      create_driver(%[])
    end
  end

#  def test_write
#    d = create_driver(CONFIG1)
#
#    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
#    d.emit({ "foo" => "bar" }, time)
#    d.run
#
#    assert_equal "test", $channel
#    assert_equal(%Q[{"foo":"bar","time":#{time}}], $message)
#  end

  def get_time
    Time.parse("2011-01-02 13:14:15 UTC").to_i
  end

  # it should return whole message
  def test_omit_value_path
    config = %[
      format_type plain
      store_type string
      key_path   user
    ]
    d = create_driver(config)
    message = {
      'user' => 'george',
      'stat' => { 'attack' => 7 }
    }
    $ttl = nil
    d.emit(message, get_time)
    d.run

    assert_equal "george", $key
    assert_equal message, $message
    assert_equal nil, $ttl
  end

  def test_key_value_paths
    config = %[
      format_type plain
      store_type string
      key_path   user.name
      value_path stat.attack
      key_expire 3
    ]
    d = create_driver(config)
    message = {
      'user' => { 'name' => 'george' },
      'stat' => { 'attack' => 7 }
    }
    $ttl = nil
    d.emit(message, get_time)
    d.run

    assert_equal "george", $key
    assert_equal 7, $message
    assert_equal 3, $ttl
  end

  def test_json
    config = %[
      format_type json
      store_type string
      key_path   user
    ]
    d = create_driver(config)
    message = {
      'user' => 'george',
      'stat' => { 'attack' => 7 }
    }
    $ttl = nil
    d.emit(message, get_time)
    d.run

    assert_equal "george", $key
    assert_equal message.to_json, $message
  end

  def test_msgpack
    config = %[
      format_type msgpack
      store_type string
      key_path   user
    ]
    d = create_driver(config)
    message = {
      'user' => 'george',
      'stat' => { 'attack' => 7 }
    }
    $ttl = nil
    d.emit(message, get_time)
    d.run

    assert_equal "george", $key
    assert_equal message.to_msgpack, $message
  end

  def test_list_asc
    config = %[
      format_type plain
      store_type list
      key_path   user
    ]
    d = create_driver(config)
    message = {
      'user' => 'george',
      'stat' => { 'attack' => 7 }
    }
    d.emit(message, get_time)
    d.run

    assert_equal :rpush, $command
    assert_equal "george", $key
    assert_equal message, $message
  end

  def test_list_desc
    config = %[
      format_type plain
      store_type list
      key_path   user
      order      desc
    ]
    d = create_driver(config)
    message = {
      'user' => 'george',
      'stat' => { 'attack' => 7 }
    }
    d.emit(message, get_time)
    d.run

    assert_equal :lpush, $command
    assert_equal "george", $key
    assert_equal message, $message
  end

  def test_set
    config = %[
      format_type plain
      store_type set
      key_path   user
      order      desc
    ]
    d = create_driver(config)
    message = {
      'user' => 'george',
      'stat' => { 'attack' => 7 }
    }
    d.emit(message, get_time)
    d.run

    assert_equal :sadd, $command
    assert_equal "george", $key
    assert_equal message, $message
  end

  def test_zset
    config = %[
      format_type plain
      store_type zset
      key_path   user
      score_path result
    ]

    d = create_driver(config)
    message = {
      'user' => 'george',
      'stat' => { 'attack' => 7 },
      'result' => 81
    }
    d.emit(message, get_time)
    d.run

    assert_equal :zadd, $command
    assert_equal "george", $key
    assert_equal 81, $score
    assert_equal message, $message
  end

  def test_zset_with_no_score_path
    config = %[
      format_type plain
      store_type zset
      key_path   user
    ]

    d = create_driver(config)
    message = {
      'user' => 'george',
      'stat' => { 'attack' => 7 },
      'result' => 81
    }
    d.emit(message, get_time)
    d.run

    assert_equal :zadd, $command
    assert_equal "george", $key
    assert_equal get_time, $score
    assert_equal message, $message
  end

  def test_publish
    config = %[
      format_type plain
      store_type publish
      key_path   user
    ]

    d = create_driver(config)
    message = {
      'user' => 'george'
    }
    d.emit(message, get_time)
    d.run

    assert_equal :publish, $command
    assert_equal "george", $channel
    assert_equal message, $message
  end

  def test_empty_key
    config = %[
      format_type plain
      store_type string
      key_path   none
    ]

    d = create_driver(config)
    message = { 'user' => 'george' }
    d.emit(message, get_time)
    assert_raise(Fluent::ConfigError) do
      d.run
    end
  end
end
