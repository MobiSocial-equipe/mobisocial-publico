package br.ufc.quixada.arquitetura.mobisocial.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.ufc.quixada.arquitetura.mobisocial.event.PaymentProcessedEvent;
import br.ufc.quixada.arquitetura.mobisocial.event.RideScheduledEvent;
import br.ufc.quixada.arquitetura.mobisocial.user.model.TariffProfile;
import java.math.BigDecimal;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.support.converter.MessageConverter;

class RabbitMQConfigTest {

    private final RabbitMQConfig config = new RabbitMQConfig(
            "payments.process",
            "notifications.dispatch",
            "payments.process.dlq",
            "notifications.dispatch.dlq");

    @Test
    void shouldDeclareDurableQueuesWithDeadLetterConfiguration() {
        Queue paymentsQueue = config.paymentsProcessQueue();
        Queue paymentsDlq = config.paymentsProcessDlq();
        Queue notificationsQueue = config.notificationsDispatchQueue();
        Queue notificationsDlq = config.notificationsDispatchDlq();

        assertEquals("payments.process", paymentsQueue.getName());
        assertTrue(paymentsQueue.isDurable());
        assertEquals("", paymentsQueue.getArguments().get("x-dead-letter-exchange"));
        assertEquals("payments.process.dlq", paymentsQueue.getArguments().get("x-dead-letter-routing-key"));

        assertEquals("payments.process.dlq", paymentsDlq.getName());
        assertTrue(paymentsDlq.isDurable());

        assertEquals("notifications.dispatch", notificationsQueue.getName());
        assertTrue(notificationsQueue.isDurable());
        assertEquals("", notificationsQueue.getArguments().get("x-dead-letter-exchange"));
        assertEquals("notifications.dispatch.dlq", notificationsQueue.getArguments().get("x-dead-letter-routing-key"));

        assertEquals("notifications.dispatch.dlq", notificationsDlq.getName());
        assertTrue(notificationsDlq.isDurable());
    }

    @Test
    void shouldSerializeAndDeserializeEventsAsJson() {
        MessageConverter converter = config.messageConverter();

        RideScheduledEvent rideEvent = RideScheduledEvent.of(
                UUID.randomUUID(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                TariffProfile.STUDENT,
                true,
                3,
                "PIX",
                new BigDecimal("12.50"));

        Message rideMessage = converter.toMessage(rideEvent, new MessageProperties());
        Object decodedRide = converter.fromMessage(rideMessage);
        assertInstanceOf(RideScheduledEvent.class, decodedRide);
        assertEquals(rideEvent, decodedRide);

        PaymentProcessedEvent paymentEvent = PaymentProcessedEvent.of(
                UUID.randomUUID(),
                rideEvent.rideId(),
                rideEvent.passengerId(),
                new BigDecimal("8.75"),
                "APPROVED");

        Message paymentMessage = converter.toMessage(paymentEvent, new MessageProperties());
        Object decodedPayment = converter.fromMessage(paymentMessage);
        assertInstanceOf(PaymentProcessedEvent.class, decodedPayment);
        assertEquals(paymentEvent, decodedPayment);
    }
}
