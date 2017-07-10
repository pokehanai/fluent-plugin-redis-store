Redis Output Plugin For fluentd
===============================
[Fluentd][] output plugin to upload/publish event data to [Redis][] storage.

[Fluentd]: http://fluentd.org/
[Redis]: http://redis.io/

Background
----------

This is forked project from [fluent-plugin-redis-store][].

[fluent-plugin-redis-store]: https://github.com/pokehanai/fluent-plugin-redis-store

Features
--------

#### Supported Redis commands

Currently the plugin supports following Redis commands:

- **set** by `string` type (of the plugin)
- **lpush**/**rpush** by `list` type
- **sadd** by `set` type
- **zadd** by `zset` type
- **publish** by `publish` type

#### Supported _value_ format

- plain(as is)
- JSON
- [MessagePack](http://msgpack.org/)

#### _key_ string for Redis storage

Redis commands require _key_ and _value_.  
For _key_, the plugin supports either way;

1. Specify a fixed key.  
   You can do this simply using `key` option in td-agent configuration file.

   ```apache
   type redis_store
   key userdata
   ```

2. Lookup a key string in every event data by a lookup path.  
   If event data have structured data like

   ```javascript
   { "user": { "name": "Kei" } }
   ```

   and you want to use each name of user, you can use `key_path` option.

   ```apache
   type redis_store
   key_path user.name
   ```

   With the above data, `Kei` will be a _key_.

In addition, `key_prefix` and `key_suffix` are useful in some cases. Both are available either `key` and `key_path`

   ```apache
   type redis_store
   key_path user.name
   key_prefix ouruser.
   key_suffix .accesslog
   ```

With the previous data, _key_ will be `outuser.Kei.accesslog`.

#### _value_ data for Redis storage

To determine what _value_ in every event data to be srtored, you have two options;

1. Store extracted data in event data, by a lookup path with `value_path` option.  
   It works like `key_path`.
2. Store whole data.  
   This is default behavior. To do it, simply omit `value_path` option.

Installation
------------

```bash
fluent-gem install fluent-plugin-redis-store-gabfl

# or if you are using td-agent:
td-agent-gem install fluent-plugin-redis-store-gabfl
```

Configuration
-------------

### Redis connection

| Key        | Type   | Required?   |                  Default | Description                                       |
| :----      | :----- | :---------- | :----------------------- | :------------                                     |
| `host`      | string | Optional    | 127.0.0.1               | host name of Redis server                               |
| `port`     | int    | Optional    |                     6379 | port number of Redis server                       |
| `password` | string | Optional    |                          | password for Redis connection                     |
| `path`     | string | Optional    |                          | To connect via Unix socket, try '/tmp/redis.sock' |
| `db`       | int    | Optional    |                        0 | DB number of Redis                                |
| `timeout`  | float  | Optional    |                      5.0 | connection timeout in seconds                     |

### common options for storages

| Key           | Type   | Default                  | Description                                          |
| :----         | :----- | :----------------------- | :------------                                        |
| `key`         | string |                          | Fixed _key_ used to store(publish) in Redis          |
| `key_path`    | string |                          | path to lookup for _key_ in the event data           |
| `key_prefix`  | string |                          | prefix of _key_                                      |
| `key_suffix`  | string |                          | suffix of _key_                                      |
| `value_path`  | string | (whole event data)       | path to lookup for _value_ in the event data         |
| `store_type`  | string | zset                     | `string`/`list`/`set`/`zset`/`publish`               |
| `format_type` | string | plain                    | format type for _value_ (`plain`/`json`/`msgpack`)   |
| `key_expire`  | int    | -1                       | If set, the key will be expired in specified seconds |
| `flush_interval`  | time    | 1                       | Time interval which events will be flushed to Redis |

Note: either `key` or `key_path` is required.

### `string` storage specific options

| Key    | Type   | Default                  | Description                                 |
| :----  | :----- | :----------------------- | :------------                               |
| `type` | string |                          | Fixed _key_ used to store(publish) in Redis |
No more options than common options.

### `list` storage specific options

| Key     | Type   | Default                  | Description                         |
| :----   | :----- | :----------------------- | :------------                       |
| `order` | string | asc                      | `asc`: **rpush**, `desc`: **lpush** |

### `set` storage specific options

No more options than common options.

### `zset` storage specific options

| Key                 | Type   | Default                  | Description                                                             |
| :----               | :----- | :----------------------- | :------------                                                           |
| `score_path`        | string | (_time_ of log event)    | path to lookup for _score_ in the event data                            |
| `collision_policy`  | string | (nil)                    | Only update elements that already exist (XX) or add a new element (NX)  |
| `value_expire`      | int    |                          | value expiration in seconds                                             |

If `value_expire` is set, the plugin assumes that the _score_ in the **SortedSet** is
based on *timestamp* and it deletes expired _members_ every after new event data arrives.

### `publish` storage specific options

No more options than common options.


Copyright
---------

Copyright (c) 2013 moaikids  
Copyright (c) 2014 HANAI Tohru  

License
-------
Apache License, Version 2.0
