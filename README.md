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

The `HIMPORT` command includes several sub-commands, the first of which is `HIMPORT PREPARE`. This sub-command allows you to declare a field set. Below is an example of a field set named "scores" with the following fields:

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

It’s important to note that the prepared field set is only valid within the context of the connection where `HIMPORT PREPARE` was executed.

This is a good opportunity to revisit the `himport_auto_prepare` option. The client library maintains an internal 
registry of all prepared imports. If a connection disconnects and then reconnects, it automatically re-registers all preparations.

Once the field set is no longer needed, it can be discarded. Discarding the field set removes it from the registry.

### Prepare once, use anywhere in your application

The demo CLI app himport_demo.rb includes an inline mode, which simulates a scenario where you prepare your field sets when starting your application.

```bash
ruby himport_demo.rb inline
```

The previously mentioned registry allows you to use `HIMPORT` as a general alternative to `HSET`. It's strongly  advised to use `himport_auto_prepare=true`.

**Note**: The client library `redis-rb` does not have built-in connection pooling. However, if you use a connection pool (as described in the [README](https://github.com/redis/redis-rb#connection-pooling-and-thread-safety)), you must ensure that each connection in the pool is prepared individually.


### Prepare, bulk import, discard

A more common use case involves performing the preparation and bulk import within a single pipeline. Redis pipelining allows you to issue multiple commands at once without waiting for a response to each individual command. A pipeline always executes against a single connection. For this scenario, you can set `himport_auto_prepare` to `false`.

The demo CLI app includes a `bulk` mode for this purpose:

```ruby
      result = redis.pipelined do |pipeline|
        pipeline.himport_prepare("scores", %w[_uid score tag])
        (1..NUM_IMPORTS).each { |i|
          uuid, score, tag = random_demo_data
          pipeline.himport_set(uuid, "scores", [uuid, score, tag])
        }
      end
```

Once the import completes, the field set is no longer needed and can be discarded.

## A simple benchmark

Last but not least, the CLI app includes a `benchmark` mode, which performs the following steps:

1. Prepares a single field set, then pipelines a number of `HSET` commands and measures the time taken to complete the import.
2. Repeats the exact same steps using `HIMPORT`, enabling a fair comparison.

The following benchmark was executed on a local host with a field set containing just three fields. It demonstrated an 11% faster import. Since `HIMPORT` primarily saves network bandwidth, we expect even greater performance improvements with larger field sets.

```bash
ruby himport_demo.rb benchmark
Benchmarking 1000000 records ...
HSET:    1000000 records in 12.029s
HIMPORT: 1000000 records in 10.589s
```
