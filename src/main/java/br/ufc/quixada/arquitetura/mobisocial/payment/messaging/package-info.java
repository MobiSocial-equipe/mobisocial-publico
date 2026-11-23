/**
 * Consumidores e publicadores AMQP do container <b>Serviço de Pagamentos</b> ({@code paymentService} no {@code docs/c4/workspace.dsl}).
 *
 * <p>Classes planejadas:
 * <ul>
 *   <li>{@code PaymentEventListener}: consome eventos de corridas agendadas da fila {@code payments.process}.</li>
 *   <li>{@code PaymentEventPublisher}: publica eventos de pagamento processado na fila {@code notifications.dispatch}.</li>
 * </ul>
 */
package br.ufc.quixada.arquitetura.mobisocial.payment.messaging;
