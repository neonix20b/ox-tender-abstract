# Использование OxTenderAbstract с Sidekiq

## Обработка блокировок API в отложенных задачах

При частых запросах к API zakupki.gov.ru сервер может заблокировать загрузку архивов на 10 минут. Библиотека теперь правильно обрабатывает такие блокировки и возвращает специальные результаты.

## Рекомендуемый Sidekiq Worker с автоматическим ожиданием

```ruby
class TenderImportWorker
  include Sidekiq::Worker
  
  # Простая настройка - библиотека сама управляет блокировками
  sidekiq_options retry: 3
  
  def perform(region, date, subsystem_type = 'PRIZ', document_type = 'epNotificationEF2020', resume_state = nil)
    # Используем новый метод с автоматическим ожиданием
    result = OxTenderAbstract.search_tenders_with_auto_wait(
      org_region: region,
      exact_date: date,
      subsystem_type: subsystem_type,
      document_type: document_type,
      resume_state: resume_state
    )
    
    if result.failure?
      # Обрабатываем только критические ошибки
      handle_failure(result, region, date, subsystem_type, document_type)
    else
      process_tenders(result.data[:tenders])
    end
  end
  
  private
  
  def handle_failure(result, region, date, subsystem_type, document_type)
    # С автоматическим ожиданием блокировки обрабатываются автоматически
    # Нужно обрабатывать только реальные ошибки
    logger.error "Tender import failed: #{result.error}"
    raise StandardError, result.error
  end
  
  def process_tenders(tenders)
    tenders.each do |tender|
      save_tender_to_database(tender)
    end
    
    logger.info "Processed #{tenders.size} tenders"
  end
end
```

## Альтернативный Worker с ручным управлением

```ruby
class TenderImportWorkerManual
  include Sidekiq::Worker
  
  # Настраиваем повторные попытки с увеличенной задержкой для блокировок
  sidekiq_options retry: 5
  
  def perform(region, date, subsystem_type = 'PRIZ', document_type = 'epNotificationEF2020', resume_state = nil)
    # Отключаем автоматическое ожидание для ручного управления
    OxTenderAbstract.configure do |config|
      config.auto_wait_on_block = false
    end
    
    result = OxTenderAbstract.search_tenders_with_auto_wait(
      org_region: region,
      exact_date: date,
      subsystem_type: subsystem_type,
      document_type: document_type,
      resume_state: resume_state
    )
    
    if result.failure?
      handle_failure(result, region, date, subsystem_type, document_type)
    else
      process_tenders(result.data[:tenders])
    end
  end
  
  private
  
  def handle_failure(result, region, date, subsystem_type, document_type)
    # Проверяем тип ошибки
    if result.metadata[:error_type] == :blocked
      # API заблокировал доступ на 10 минут
      retry_after = result.metadata[:retry_after] || 600
      
      logger.warn "Archive download blocked, retrying in #{retry_after} seconds"
      
      # Перепланируем задачу через указанное время
      TenderImportWorker.perform_in(
        retry_after.seconds + 30, # +30 секунд для гарантии
        region, date, subsystem_type, document_type
      )
    else
      # Обычная ошибка - логируем и возможно повторяем стандартно
      logger.error "Tender import failed: #{result.error}"
      raise StandardError, result.error
    end
  end
  
  def process_tenders(tenders)
    tenders.each do |tender|
      # Обработка каждого тендера
      save_tender_to_database(tender)
    end
    
    logger.info "Processed #{tenders.size} tenders"
  end
end
```

## Конфигурация автоматического ожидания

Библиотека теперь поддерживает встроенное автоматическое ожидание при блокировках:

```ruby
# config/initializers/ox_tender_abstract.rb
OxTenderAbstract.configure do |config|
  config.token = ENV['ZAKUPKI_API_TOKEN']
  
  # Настройки автоматического ожидания
  config.auto_wait_on_block = true    # Автоматически ждать при блокировке (по умолчанию true)
  config.block_wait_time = 610        # Время ожидания в секундах (10 мин + 10 сек)
  config.max_wait_time = 900          # Максимальное время ожидания (15 мин)
end
```

### Режимы работы

1. **Автоматическое ожидание** (`auto_wait_on_block = true`) - библиотека сама ждет и продолжает
2. **Ручное управление** (`auto_wait_on_block = false`) - возвращает состояние для продолжения в Sidekiq

## Настройка Sidekiq для обработки блокировок

### 1. Кастомная стратегия повторов

```ruby
# config/initializers/sidekiq.rb

# Кастомная стратегия повторов для API блокировок
class TenderRetryStrategy
  def call(worker, job, queue)
    # Извлекаем информацию об ошибке
    exception = job['error_message']
    
    if exception&.include?('blocked')
      # Для блокировок используем фиксированную задержку
      return 600 # 10 минут
    else
      # Стандартная экспоненциальная задержка
      return (job['retry_count'] ** 4) + 15
    end
  end
end

Sidekiq.configure_server do |config|
  config.death_handlers << lambda do |job, ex|
    # Логируем окончательно проваленные задачи
    Rails.logger.error "Sidekiq job #{job['class']} failed permanently: #{ex.message}"
  end
end
```

### 2. Настройка очередей с приоритетами

```ruby
# config/sidekiq.yml
:queues:
  - [critical, 2]
  - [tenders_import, 1] 
  - [tenders_retry, 1]
  - [default, 1]
```

### 3. Worker с интеллектуальными повторами

```ruby
class SmartTenderImportWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: 'tenders_import', retry: 3
  
  # Кастомная логика повторов
  sidekiq_retry_in do |count, exception|
    case exception.message
    when /blocked/
      # Для блокировок ждем 10 минут
      600
    when /network error/i
      # Для сетевых ошибок короткая задержка
      30 * (count + 1)
    else
      # Стандартная задержка
      60 * (count + 1)
    end
  end
  
  def perform(params)
    with_error_handling do
      import_tenders(params)
    end
  end
  
  private
  
  def with_error_handling
    yield
  rescue => e
    if e.message.include?('blocked')
      # Перемещаем в специальную очередь для повторов
      SmartTenderImportWorker.set(queue: 'tenders_retry')
                            .perform_in(610.seconds, { retry: true }.merge(params))
    else
      raise e
    end
  end
end
```

## Мониторинг и отладка

### 1. Логирование блокировок

```ruby
class TenderImportLogger
  def self.log_blocked_request(region, date, retry_after)
    Rails.logger.warn {
      "[TENDER_BLOCKED] Region: #{region}, Date: #{date}, Retry after: #{retry_after}s"
    }
    
    # Отправка в системы мониторинга
    StatsD.increment('tender_import.blocked')
    StatsD.histogram('tender_import.retry_delay', retry_after)
  end
end
```

### 2. Метрики для мониторинга

```ruby
# В worker'е
def perform(params)
  start_time = Time.current
  
  begin
    result = import_tenders(params)
    StatsD.increment('tender_import.success')
    StatsD.histogram('tender_import.duration', Time.current - start_time)
  rescue => e
    StatsD.increment('tender_import.error')
    StatsD.increment("tender_import.error.#{error_type(e)}")
    raise
  end
end

def error_type(exception)
  case exception.message
  when /blocked/ then 'blocked'
  when /network/ then 'network'
  when /parse/ then 'parse'
  else 'unknown'
  end
end
```

## Рекомендации

1. **Используйте разные очереди** для обычных и повторных задач
2. **Мониторьте частоту блокировок** - если они частые, уменьшите нагрузку
3. **Настройте алерты** на высокий процент блокировок
4. **Кэшируйте результаты** где возможно, чтобы уменьшить количество запросов
5. **Используйте rate limiting** на уровне приложения

## Пример полной настройки

```ruby
# app/workers/tender_import_worker.rb
class TenderImportWorker
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker
  
  # Ограничиваем количество одновременных запросов
  sidekiq_throttle(
    threshold: { limit: 5, period: 1.minute },
    key: ->(region, date) { "tender_import:#{region}" }
  )
  
  sidekiq_options queue: 'tenders', retry: 5
  
  def perform(region, date, options = {})
    TenderImportService.new(region, date, options).call
  end
end

# app/services/tender_import_service.rb
class TenderImportService
  def initialize(region, date, options = {})
    @region = region
    @date = date
    @options = options
  end
  
  def call
    result = OxTenderAbstract.search_tenders(
      org_region: @region,
      exact_date: @date,
      subsystem_type: @options[:subsystem_type] || 'PRIZ'
    )
    
    if result.failure?
      handle_error(result)
    else
      process_success(result)
    end
  end
  
  private
  
  def handle_error(result)
    case result.metadata[:error_type]
    when :blocked
      schedule_retry(result.metadata[:retry_after])
    when :network
      raise NetworkError, result.error
    else
      raise StandardError, result.error
    end
  end
  
  def schedule_retry(retry_after)
    TenderImportWorker.perform_in(
      (retry_after + 30).seconds,
      @region, @date, @options.merge(retry: true)
    )
  end
end
```
