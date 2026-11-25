package br.ufc.quixada.arquitetura.mobisocial.config;

import org.springframework.amqp.core.AmqpAdmin;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.JacksonJsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configuração das filas AMQP e serialização JSON no RabbitMQ (conformidade C4 e ADR 02).
 */
@Configuration
public class RabbitMQConfig {

    private final String paymentsProcessQueueName;
    private final String notificationsDispatchQueueName;
    private final String paymentsProcessDlqName;
    private final String notificationsDispatchDlqName;

    public RabbitMQConfig(
            @Value("${mobisocial.rabbitmq.queues.payments-process}") String paymentsProcessQueueName,
            @Value("${mobisocial.rabbitmq.queues.notifications-dispatch}") String notificationsDispatchQueueName,
            @Value("${mobisocial.rabbitmq.queues.payments-process-dlq}") String paymentsProcessDlqName,
            @Value("${mobisocial.rabbitmq.queues.notifications-dispatch-dlq}") String notificationsDispatchDlqName) {
        this.paymentsProcessQueueName = paymentsProcessQueueName;
        this.notificationsDispatchQueueName = notificationsDispatchQueueName;
        this.paymentsProcessDlqName = paymentsProcessDlqName;
        this.notificationsDispatchDlqName = notificationsDispatchDlqName;
    }

    /**
     * Fila principal durável para eventos de corridas agendadas ({@code payments.process}).
     */
    @Bean
    public Queue paymentsProcessQueue() {
        return QueueBuilder.durable(paymentsProcessQueueName)
                .deadLetterExchange("")
                .deadLetterRoutingKey(paymentsProcessDlqName)
                .build();
    }

    /**
     * Dead-letter queue durável para falhas no processamento de pagamentos.
     */
    @Bean
    public Queue paymentsProcessDlq() {
        return QueueBuilder.durable(paymentsProcessDlqName).build();
    }

    /**
     * Fila principal durável para eventos de pagamentos processados ({@code notifications.dispatch}).
     */
    @Bean
    public Queue notificationsDispatchQueue() {
        return QueueBuilder.durable(notificationsDispatchQueueName)
                .deadLetterExchange("")
                .deadLetterRoutingKey(notificationsDispatchDlqName)
                .build();
    }

    /**
     * Dead-letter queue durável para falhas no envio de notificações.
     */
    @Bean
    public Queue notificationsDispatchDlq() {
        return QueueBuilder.durable(notificationsDispatchDlqName).build();
    }

    /**
     * Conversor JSON nativo Jackson 3 para os contratos de eventos do pacote {@code event}.
     */
    @Bean
    public MessageConverter messageConverter() {
        return new JacksonJsonMessageConverter("br.ufc.quixada.arquitetura.mobisocial.event");
    }

    /**
     * Template AMQP configurado com serialização JSON.
     */
    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory, MessageConverter messageConverter) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(messageConverter);
        return rabbitTemplate;
    }

    /**
     * Garante a declaração imediata das filas no RabbitMQ durante a inicialização da aplicação.
     */
    @Bean
    public ApplicationRunner declareRabbitQueuesOnStartup(AmqpAdmin amqpAdmin) {
        return args -> amqpAdmin.initialize();
    }
}
