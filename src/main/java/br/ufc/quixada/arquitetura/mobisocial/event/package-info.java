/**
 * Contratos JSON dos eventos assíncronos trafegados pelo Message Broker RabbitMQ
 * ({@code broker} no {@code docs/c4/workspace.dsl}).
 *
 * <p>Classes planejadas:
 * <ul>
 *   <li>{@code RideScheduledEvent}: payload publicado na fila {@code payments.process}.</li>
 *   <li>{@code PaymentProcessedEvent}: payload publicado na fila {@code notifications.dispatch}.</li>
 * </ul>
 */
package br.ufc.quixada.arquitetura.mobisocial.event;
