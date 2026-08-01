# Efficient Bulk Hash Insertion with Redis 8.10’s `HIMPORT`

I’m not a Ruby developer, and my code samples might make that clear. However, there are two reasons I’m using Ruby for the examples in this article:

1. A new release of [redis-rb](https://github.com/redis/redis-rb).
2. Its support for a new Redis command: HIMPORT.


## Getting started

Establishing a Redis connection in Ruby is straightforward. All you need is the redis gem and a Redis OSS server.

> Fun fact: A ruby is a gemstone, which is why software packages in Ruby are called gems. It’s a charming way to highlight the value of every package contributed by the community.


```
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

```
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
  
```
redis.himport_prepare("scores", %w[_uid score tag])
```


## A simple benchmark

```
ruby himport_demo.rb benchmark
Benchmarking 1000000 records ...
HSET:    1000000 records in 12.029s
HIMPORT: 1000000 records in 10.589s
```
