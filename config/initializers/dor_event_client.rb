# frozen_string_literal: true

Dor::Event::Client.configure(hostname: Settings.rabbitmq.hostname,
                             vhost: Settings.rabbitmq.vhost,
                             username: Settings.rabbitmq.username,
                             password: Settings.rabbitmq.password)
