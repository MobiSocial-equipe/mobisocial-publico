package br.ufc.quixada.arquitetura.mobisocial.event;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Evento publicado na fila {@code notifications.dispatch} após o processamento financeiro da corrida (ADR 02).
 */
public record PaymentProcessedEvent(
        UUID eventId,
        UUID paymentId,
        UUID rideId,
        UUID passengerId,
        BigDecimal finalAmount,
        String status,
        LocalDateTime createdAt) {

    /**
     * Cria uma instância de {@link PaymentProcessedEvent} com {@code eventId} e {@code createdAt} gerados automaticamente.
     */
    public static PaymentProcessedEvent of(
            UUID paymentId,
            UUID rideId,
            UUID passengerId,
            BigDecimal finalAmount,
            String status) {
        return new PaymentProcessedEvent(
                UUID.randomUUID(),
                paymentId,
                rideId,
                passengerId,
                finalAmount,
                status,
                LocalDateTime.now());
    }
}
