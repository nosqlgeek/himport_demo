require "redis"
require "thor"
require "securerandom"

# Simple CLI application for demoing purposes
class HimportDemo < Thor
  class_option :host,     type: :string,  default: "localhost", desc: "Redis host"
  class_option :port,     type: :numeric, default: 6379,        desc: "Redis port"
  class_option :user,     type: :string,                        desc: "Redis username"
  class_option :password, type: :string,                        desc: "Redis password"

  # Constants
  PLAYER_TAGS = ["vladvildanov", "elena-kolevska", "petyaslavova", "antirez", "nosqlgeek"]
  NUM_IMPORTS = 100
  NUM_BENCHMARK_IMPORTS = NUM_IMPORTS * 10


  # Helper to connect to Redis
  # - no_commands tells Thor not to expose redis as a CLI command
  # - @redis ||= lazily initializes the connection once and reuses it
  no_commands do
    def redis
      @redis ||= Redis.new(
        host:     options[:host],
        port:     options[:port],
        username: options[:user],
        password: options[:password],
        himport_auto_prepare: true,


      )
    rescue Redis::CannotConnectError
      puts "Error: cannot connect to Redis at #{options[:host]}:#{options[:port]}"
      exit 1
    rescue Redis::CommandError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  # Runs some application code into which the HIMPORT's are mixed in
  no_commands do
    def something
      sleep(0.1)
    end
  end

  # Generates a random demo record: [uuid, score, tag_idx, tag]
  no_commands do
    def random_demo_data
      uuid = SecureRandom.uuid
      score = rand(1000)
      tag_idx = rand(PLAYER_TAGS.size - 1)
      tag = PLAYER_TAGS[tag_idx]
      [uuid, score, tag]
    end
  end

  # CLI commands
  desc "info", "If the purpose of this tool isn't obvious ;-)"
  def info
    puts "A short demo of the new `HIMPORT` Redis command."
  end

  desc "test", "Test the Redis connection"
  def test
    puts(redis.ping)
  end

  desc "inline", "Prepare once, execute whenever your app needs it."
  def inline
    puts "Preparing a field set ..."
    redis.himport_prepare("scores", %w[_uid score tag])

    (1..NUM_IMPORTS).each { |i|

      puts "Pretending to do something else for the #{i}th time ..."
      something

      # Prepare demo data
      uuid, score, tag = random_demo_data

      puts "Importing score #{score} of player #{tag} with id #{uuid} ..."

      redis.himport_set(uuid, "scores", [uuid, score, tag])
    }
  end

  desc "bulk", "Prepare once, execute as a bulk of commands."
  def bulk

    result = redis.pipelined do |pipeline|
      pipeline.himport_prepare("scores", %w[_uid score tag])

      (1..NUM_IMPORTS).each { |i|
        uuid, score, tag = random_demo_data
        puts "#{i}: Importing score #{score} of player #{tag} with id #{uuid} ..."
        pipeline.himport_set(uuid, "scores", [uuid, score, tag])
      }
    end

    puts("Imported #{result.length-1} records")
  end

  desc "benchmark", "Run a short HSET vs. HIMPORT benchmark."
  def benchmark

  end
end

HimportDemo.start(ARGV)
