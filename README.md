# Efficient Bulk Hash Insertion with Redis 8.10’s `HIMPORT`

I’m not a Ruby developer, and my code samples might make that clear. However, there are two reasons I’m using Ruby for the examples in this article:

1. A new release of [redis-rb](https://github.com/redis/redis-rb).
2. Its support for a new Redis command: HIMPORT.


## Getting started

Establishing a Redis connection in Ruby is straightforward. All you need is the redis gem and a Redis OSS server.

> Fun fact: A ruby is a gemstone, which is why software packages in Ruby are called gems. It’s a charming way to highlight the value of every package contributed by the community.


```ruby
redis = Redis.new(
        host:     options[:host],
        port:     options[:port],
        username: options[:user],
        password: options[:password],
        himport_auto_prepare: true
)
```

The `himport_auto_prepare` option defaults to `true`. I included it here for reference. We’ll revisit it later. For now, just bear with me.


## Why `HIMPORT`?

Why not just use HSET? To answer that, let’s look at a Ruby example:

```ruby
redis.hset("scores:68430017", "_uid", "68430017", "score", 42, "tag", "vladvildanov")
...
redis.hset("scores:03DBA163", "_uid", "03DBA163", "score", 234, "tag", "nosqlgeek")
```

One thing stands out: We’re repeatedly sending not just the data, but also the field names. This is exactly what `HIMPORT` is going to solve.

## How does it work?

The command `HIMPORT` has several sub-commands. The first one is `HIMPORT PREPARE`. It allows you to declare a field set. Here is an example of the field set `scores` with the fields:

* **_uid**: The player id
* **score**: The score that the player achieved 
* **tag**: The player tag.
  
```ruby
    redis.himport_prepare("scores", %w[_uid score tag])

    (1..NUM_IMPORTS).each { |i|
      uuid, score, tag = random_demo_data
      redis.himport_set(uuid, "scores", [uuid, score, tag])
    }

    redis.himport_discard("scores")
```

It's important to understand that the prepared field set is only valid in the context of the connection on which `HIMPORT PREPARE` was executed.

This is a good time to revisit this `himport_auto_prepare` option. The client library keeps all prepared imports inside an internal registry. So, if a connection disconnects and then reconnects it reregisters all the preparations automatically.

As soon as the field set isn't needed anymore, it can be discarded. Discarding the field set removes it from the registry.


### Prepare once, use anywhere in your application

The demo CLI app `himport_demo.rb` has a mode `inline` which mimics a scenario where you prepare your fieldsets when starting your application. 

```ruby
ruby himport_demo.rb inline
```

The previously mentioned registry allowx you to use `HIMPORT` as a general alternative to `HSET`. It's strongly  advised to use `himport_auto_prepare=true`.

There is the following caveat: The client library `redis-rb` doesn't have built-in connection pooling. However, if you use a pool of connections as described in [the README](https://github.com/redis/redis-rb#connection-pooling-and-thread-safety), you need to take into account that each connection of the pool needs to be prepared by you. 


### Prepare, bulk import, discard

The more common use case is to perform a the preparation and bulk import on within a single pipeline. Redis pipelining allows issuing multiple commands at once without waiting for the response to each individual command. A pipeline is always executed against a single connections. You can set `himport_auto_prepare=false` for this scenario.

The demo CLI app has a mode called `bulk` for that.

```ruby
      result = redis.pipelined do |pipeline|
      pipeline.himport_prepare("scores", %w[_uid score tag])

      (1..NUM_IMPORTS).each { |i|
        uuid, score, tag = random_demo_data
        puts "#{i}: Importing score #{score} of player #{tag} with id #{uuid} ..."
        pipeline.himport_set(uuid, "scores", [uuid, score, tag])
      }

      pipeline.himport_discard("scores")
    end
```

As soon as the import completes, the field set isn't needed anymore and can be discarded.


## A simple benchmark

TODO

```
ruby himport_demo.rb benchmark
Benchmarking 1000000 records ...
HSET:    1000000 records in 12.029s
HIMPORT: 1000000 records in 10.589s
```
