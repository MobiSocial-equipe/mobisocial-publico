package br.ufc.quixada.arquitetura.mobisocial.event;

import br.ufc.quixada.arquitetura.mobisocial.user.model.TariffProfile;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Evento publicado na fila {@code payments.process} após o agendamento de uma corrida (ADR 02).
 */
public record RideScheduledEvent(
        UUID eventId,
        UUID rideId,
        UUID routeId,
        UUID passengerId,
        TariffProfile tariffProfile,
        boolean sharedRide,
        int passengerCount,
        String paymentMethod,
        BigDecimal distanceKm,
        LocalDateTime createdAt) {

    /**
     * Cria uma instância de {@link RideScheduledEvent} com {@code eventId} e {@code createdAt} gerados automaticamente.
     */
    public static RideScheduledEvent of(
            UUID rideId,
            UUID routeId,
            UUID passengerId,
            TariffProfile tariffProfile,
            boolean sharedRide,
            int passengerCount,
            String paymentMethod,
            BigDecimal distanceKm) {
        return new RideScheduledEvent(
                UUID.randomUUID(),
                rideId,
                routeId,
                passengerId,
                tariffProfile,
                sharedRide,
                passengerCount,
                paymentMethod,
                distanceKm,
                LocalDateTime.now());
    }
}
