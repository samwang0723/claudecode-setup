# Rails Production Patterns

## Multi-Database (Read Replicas)

```ruby
# config/database.yml
production:
  primary:
    <<: *default
    url: <%= ENV['DATABASE_URL'] %>
  primary_replica:
    <<: *default
    url: <%= ENV['DATABASE_REPLICA_URL'] %>
    replica: true

# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: { writing: :primary, reading: :primary_replica }
end

# Automatic read/write splitting
ActiveRecord::Base.connected_to(role: :reading) do
  User.find(id)  # Hits replica
end

# Rails 7+ automatic switching
# config/application.rb
config.active_record.database_selector = { delay: 2.seconds }
config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
```

---

## Distributed Locking (Redis)

```ruby
# app/services/concerns/with_lock.rb
module WithLock
  extend ActiveSupport::Concern

  private

  def with_lock(key, ttl: 30.seconds)
    lock_key = "lock:#{key}"
    lock_value = SecureRandom.uuid

    acquired = Redis.current.set(lock_key, lock_value, nx: true, ex: ttl.to_i)
    unless acquired
      Rails.logger.warn("Failed to acquire lock: #{lock_key}")
      return Result.failure(errors: ["operation in progress"])
    end

    begin
      yield
    ensure
      # Only release if we still own the lock
      release_script = <<~LUA
        if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
        else
          return 0
        end
      LUA
      Redis.current.eval(release_script, keys: [lock_key], argv: [lock_value])
    end
  end
end

# Usage
class ProcessPaymentService
  include WithLock

  def call
    with_lock("payment:#{@user_id}:#{@currency}", ttl: 60.seconds) do
      # Only one instance processes this payment at a time
      execute_payment
    end
  end
end
```

---

## Idempotent Operations

```ruby
# app/services/concerns/idempotent.rb
module Idempotent
  extend ActiveSupport::Concern

  private

  def idempotent(key, ttl: 24.hours)
    idempotency_key = "idempotent:#{key}"

    # Check if already processed
    cached = Redis.current.get(idempotency_key)
    if cached
      Rails.logger.info("Idempotent hit: #{idempotency_key}")
      return JSON.parse(cached, symbolize_names: true)
    end

    result = yield

    # Cache the result
    Redis.current.setex(idempotency_key, ttl.to_i, result.to_json)
    result
  end
end

# Usage in controller
class Api::V1::TransfersController < Api::BaseController
  def create
    result = CreateTransferService.new(
      current_user,
      transfer_params,
      idempotency_key: request.headers['Idempotency-Key']
    ).call

    if result.success?
      render json: result.value, status: :created
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end
end
```

---

## Safe Batch Processing

```ruby
# Process large datasets without OOM
class BatchProcessingService
  BATCH_SIZE = 1000

  def call(scope)
    processed = 0
    errors = []

    scope.find_each(batch_size: BATCH_SIZE) do |record|
      process_record(record)
      processed += 1
    rescue StandardError => e
      errors << { id: record.id, error: e.message }
      Rails.logger.error("Batch error: record=#{record.id} error=#{e.message}")
    end

    { processed: processed, errors: errors }
  end

  private

  def process_record(record)
    # Business logic
  end
end

# With progress tracking
class BatchWithProgressService
  def call(scope, job_id:)
    total = scope.count
    processed = 0

    scope.in_batches(of: 1000) do |batch|
      batch.each do |record|
        process_record(record)
        processed += 1
      end

      # Update progress
      Redis.current.hset("job:#{job_id}", {
        processed: processed,
        total: total,
        percent: (processed.to_f / total * 100).round(1)
      })
    end
  end
end
```

---

## PII Masking Helper

```ruby
# app/helpers/pii_helper.rb
module PiiHelper
  module_function

  def mask_email(email)
    return nil if email.blank?

    local, domain = email.split('@')
    return '***' if local.nil? || domain.nil?

    "#{local[0..1]}***@#{domain}"
  end

  def mask_phone(phone)
    return nil if phone.blank?

    "***#{phone.last(4)}"
  end

  def mask_name(name)
    return nil if name.blank?

    "#{name[0]}***"
  end

  def mask_address(address)
    return nil if address.blank?

    "***#{address.last(10)}"
  end

  # For logging — mask all known PII fields in a hash
  def sanitize_for_log(hash)
    pii_fields = %i[email phone mobile address ssn passport_number
                    date_of_birth first_name last_name full_name]

    hash.transform_keys(&:to_sym).each_with_object({}) do |(k, v), result|
      result[k] = pii_fields.include?(k) ? '[FILTERED]' : v
    end
  end
end

# Usage in logging
Rails.logger.info("User action", PiiHelper.sanitize_for_log(user.attributes))
```

---

## Feature Flags (Simple)

```ruby
# app/models/feature_flag.rb
class FeatureFlag
  CACHE_TTL = 5.minutes

  def self.enabled?(flag_name, user: nil)
    flag = cached_flag(flag_name)
    return false if flag.nil?

    case flag[:strategy]
    when 'boolean'
      flag[:enabled]
    when 'percentage'
      user && (Digest::MD5.hexdigest("#{flag_name}:#{user.id}").to_i(16) % 100) < flag[:percentage]
    when 'whitelist'
      user && flag[:user_ids]&.include?(user.id)
    else
      false
    end
  end

  def self.cached_flag(name)
    Rails.cache.fetch("feature_flag:#{name}", expires_in: CACHE_TTL) do
      # Load from DB or config
      config = YAML.load_file(Rails.root.join('config', 'feature_flags.yml'))
      config[name.to_s]&.deep_symbolize_keys
    end
  end
end

# Usage
if FeatureFlag.enabled?(:new_checkout_flow, user: current_user)
  # New flow
else
  # Legacy flow
end
```

---

## Structured Logging

```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_payload do |controller|
    {
      user_id: controller.try(:current_user)&.id,
      request_id: controller.request.request_id
    }
  end

  config.lograge.custom_options = lambda do |event|
    exceptions = %w[controller action format id]
    {
      params: event.payload[:params].except(*exceptions),
      exception: event.payload[:exception]&.first,
      exception_message: event.payload[:exception_object]&.message
    }
  end
end

# Structured log helper
module StructuredLog
  def log_event(event_name, **fields)
    # Never log PII
    safe_fields = PiiHelper.sanitize_for_log(fields)
    Rails.logger.info(
      { event: event_name, **safe_fields, timestamp: Time.current.iso8601 }.to_json
    )
  end
end
```

---

## Safe Migration Patterns

```ruby
# Zero-downtime column addition
class AddStatusToOrders < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Step 1: Add column (nullable, no default in DB)
    add_column :orders, :status, :string

    # Step 2: Add index concurrently (non-blocking)
    add_index :orders, :status, algorithm: :concurrently

    # Step 3: Backfill in a separate migration or job
    # NEVER backfill in the same migration as column addition
  end
end

# Safe column rename (3-step deploy)
# Deploy 1: Add new column, write to both
# Deploy 2: Backfill, read from new
# Deploy 3: Remove old column

# Safe index creation
class AddIndexToUsersEmail < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :users, :email, unique: true, algorithm: :concurrently
  end
end
```

---

## Rate Limiting per User

```ruby
# app/services/rate_limiter.rb
class RateLimiter
  def initialize(key:, limit:, period:)
    @key = "rate_limit:#{key}"
    @limit = limit
    @period = period
  end

  def allowed?
    current = Redis.current.get(@key).to_i
    return true if current < @limit

    false
  end

  def increment!
    count = Redis.current.incr(@key)
    Redis.current.expire(@key, @period.to_i) if count == 1
    count <= @limit
  end

  def remaining
    [@limit - Redis.current.get(@key).to_i, 0].max
  end
end

# Usage in controller
class Api::V1::TransfersController < Api::BaseController
  before_action :check_rate_limit, only: :create

  private

  def check_rate_limit
    limiter = RateLimiter.new(
      key: "transfers:#{current_user.id}",
      limit: 10,
      period: 1.minute
    )

    unless limiter.increment!
      render json: {
        error: 'Rate limit exceeded',
        retry_after: limiter.remaining
      }, status: :too_many_requests
    end
  end
end
```
