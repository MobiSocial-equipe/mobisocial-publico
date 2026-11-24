# Documentação Arquitetural (Modelo C4 — Structurizr)

[← Voltar ao README principal](../../README.md) · [Arquitetura e Estilos](../arquitetura.md) · [ADRs](../adr/README.md) · [Contribuição](../CONTRIBUTING.md)

---

O código-fonte da modelagem arquitetural encontra-se em [`workspace.dsl`](./workspace.dsl). As Decisões Arquiteturais (ADRs) estão documentadas em [`docs/adr/`](../adr/README.md) e o guia de contribuição em [`docs/CONTRIBUTING.md`](../CONTRIBUTING.md).

> **Dica:** Para visualizar e navegar pelos diagramas interativamente no Structurizr local, execute na raiz do repositório:
> ```bash
> docker run -it --rm -p 8080:8080 -v "$PWD/docs/c4:/usr/local/structurizr" structurizr/structurizr local
> ```

---

## 1. C4 Nível 1: Diagrama de Contexto

![Diagrama de Contexto - C4 Nível 1](.structurizr/1/svgs/N1-Contexto-dark.svg)

O Passageiro e o Motorista acessam o MobiSocial por **HTTPS**. Para processar cobranças e calcular rotas, o sistema chama o Gateway de Pagamentos e a API de Mapas, também por **HTTPS**.

## 2. C4 Nível 2: Diagrama de Container

![Diagrama de Container - C4 Nível 2](.structurizr/1/svgs/N2-Containers-dark.svg)

O Front-end se comunica com o Serviço de Usuários e com o Serviço de Rotas e Corridas por **HTTPS/REST** (JSON). O Serviço de Rotas e Corridas consulta o perfil tarifário do passageiro no Serviço de Usuários por **HTTP/REST** e chama a API de Mapas por **HTTPS** para calcular rotas e distâncias. O processamento de pagamento e notificação é assíncrono: o Serviço de Rotas e Corridas publica um evento na fila `payments.process` do RabbitMQ, o Serviço de Pagamentos o consome, faz a cobrança no Gateway Externo por **HTTPS** e publica em `notifications.dispatch`, que o Serviço de Notificações consome. As mensagens entre esses serviços trafegam por **AMQP**, e os serviços gravam seus dados no PostgreSQL via **JDBC**.

### Fluxos Dinâmicos

#### 1. Autenticação
![Fluxo Dinâmico - Autenticação](.structurizr/1/svgs/n4/N4-1-Autenticacao-dark.svg)

O Passageiro informa suas credenciais ao Front-end, que chama o Serviço de Usuários. O serviço consulta o PostgreSQL, valida o perfil tarifário e retorna o token JWT ao Passageiro.

#### 2. Agendamento
![Fluxo Dinâmico - Agendamento](.structurizr/1/svgs/n4/N4-2-Agendamento-dark.svg)

O Passageiro envia uma requisição autenticada ao Serviço de Rotas e Corridas. O serviço valida o JWT, consulta o perfil tarifário e a API de Mapas, verifica os assentos disponíveis, persiste a corrida no PostgreSQL e publica `RideScheduledEvent` no broker.

#### 3. Pagamento e rateio
![Fluxo Dinâmico - Pagamento e Rateio](.structurizr/1/svgs/n4/N4-3-Pagamento-dark.svg)

O Serviço de Pagamentos recebe `RideScheduledEvent`, consulta os dados necessários no PostgreSQL, calcula o rateio e aplica a tarifa social. Em seguida, solicita a cobrança ao Gateway Externo, salva o resultado no banco e publica `PaymentProcessedEvent` no broker.

#### 4. Notificação
![Fluxo Dinâmico - Notificação](.structurizr/1/svgs/n4/N4-4-Notificacao-dark.svg)

O Serviço de Notificações consome `PaymentProcessedEvent`, formata e registra a confirmação no PostgreSQL e envia o resultado ao Passageiro e ao Motorista.

## 3. C4 Nível 3: Diagramas de Componentes

### Serviço de Usuários
![Diagrama de Componentes - Serviço de Usuários](.structurizr/1/svgs/n3/N3-Usuarios-dark.svg)

O **Serviço de Usuários** recebe requisições do **Front-end** via **HTTPS/REST** (JSON) nos controladores `AuthController` (`/api/auth`) e `UserController` (`/api/users`). O `AuthController` delega ao `AuthService` a validação de credenciais e a emissão do token **JWT**, enquanto o `UserController` delega ao `UserService` o cadastro de passageiros e motoristas, a gestão de veículos/assentos e a consulta de perfis tarifários (`COMUM`, `ESTUDANTE`, `SOCIAL`). Além disso, o `UserController` atende requisições internas via **HTTP/REST** do **Serviço de Rotas e Corridas** (`UserServiceClient`) para verificação de perfil tarifário, e os dados de usuários e veículos são persistidos no **PostgreSQL** por meio do `UserRepository` (**JDBC**).

### Serviço de Rotas e Corridas
![Diagrama de Componentes - Serviço de Rotas e Corridas](.structurizr/1/svgs/n3/N3-RotasCorridas-dark.svg)

O **Serviço de Rotas e Corridas** recebe requisições do **Front-end** via **HTTPS/REST** (JSON) nos controladores `RouteController` (`/api/routes`) e `RideController` (`/api/rides`), delegando as regras de negócio ao `RideService`. O `RideService` utiliza o `RouteMatchingComponent` para parear passageiros e rotas compatíveis, consulta o perfil tarifário no **Serviço de Usuários** via `UserServiceClient` (**HTTP/REST**), calcula rotas e distâncias na **API de Mapas / Geolocalização** via `MapsClient` (**HTTPS**), persiste rotas e corridas no **PostgreSQL** por meio de `RouteRepository` e `RideRepository` (**JDBC**) e publica o evento `RideScheduledEvent` na fila `payments.process` do **RabbitMQ** através do `RideEventPublisher` (**AMQP**).

### Message Broker (RabbitMQ — Filas AMQP)
![Diagrama de Componentes - Message Broker](.structurizr/1/svgs/n3/N3-Broker-dark.svg)

O Message Broker organiza o fluxo assíncrono em duas filas duráveis via **AMQP**: `payments.process`, que recebe o evento `RideScheduledEvent` do **Serviço de Rotas e Corridas** e o entrega ao **Serviço de Pagamentos**, e `notifications.dispatch`, que recebe o evento `PaymentProcessedEvent` do **Serviço de Pagamentos** e o entrega ao **Serviço de Notificações**.

### Serviço de Pagamentos
![Diagrama de Componentes - Serviço de Pagamentos](.structurizr/1/svgs/n3/N3-Pagamentos-dark.svg)

O `PaymentEventListener` consome o evento `RideScheduledEvent` da fila `payments.process` (**AMQP**) e aciona o `PaymentService`, responsável pelo cálculo de rateio (*carpooling*) e aplicação de tarifa social (estudante/UBS). O `PaymentService` solicita a cobrança ao **Gateway Externo de Pagamentos** via `PaymentGatewayClient` (**HTTPS**), persiste a transação no **PostgreSQL** via `PaymentRepository` (**JDBC**) e dispara o evento `PaymentProcessedEvent` na fila `notifications.dispatch` por meio do `PaymentEventPublisher` (**AMQP**).

### Serviço de Notificações
![Diagrama de Componentes - Serviço de Notificações](.structurizr/1/svgs/n3/N3-Notificacoes-dark.svg)

O `NotificationEventListener` consome o evento `PaymentProcessedEvent` da fila `notifications.dispatch` (**AMQP**) e delega ao `NotificationService` a formatação e emissão dos avisos de corrida e pagamento aprovado. Em seguida, o `NotificationRepository` grava o histórico de envios no **PostgreSQL** via **JDBC**.

## 4. C4 Nível 4: Diagramas de Código e Classes

### 4.1. Diagramas de Código no Structurizr (`workspace.dsl`)

#### Serviço de Rotas e Corridas (Classes, Interfaces JPA, Entidades e Eventos)
![Diagrama de Código - Serviço de Rotas e Corridas](.structurizr/1/svgs/n4/N4-Codigo-Corridas-dark.svg)

Modela as classes (`RouteController`, `RideController`, `RideService`, `RouteMatchingComponent`, `UserServiceClient`, `MapsClient`, `RideEventPublisher`), interfaces JPA (`RouteRepository`, `RideRepository`), entidades (`Route` e `Ride`, no schema `rides`) e contratos de evento (`RideScheduledEvent` e `TariffProfile`) do pacote `br.ufc.quixada.arquitetura.mobisocial.ride`.

#### Serviço de Pagamentos (Classes, Interface JPA, Entidade e Eventos)
![Diagrama de Código - Serviço de Pagamentos](.structurizr/1/svgs/n4/N4-Codigo-Pagamentos-dark.svg)

Modela o consumidor AMQP (`PaymentEventListener`), o serviço de cálculo de rateio e tarifa social (`PaymentService`), o cliente HTTPS do gateway (`PaymentGatewayClient`), a interface JPA (`PaymentRepository`), a entidade `Payment` (no schema `payments`), o publicador (`PaymentEventPublisher`) e os eventos `RideScheduledEvent` e `PaymentProcessedEvent`.

### 4.2. Diagramas de Classes (Mermaid — Detalhamento por Serviço)

#### Serviço de Usuários

```mermaid
classDiagram
    direction LR

    class User {
        <<abstract entity>>
        -UUID id
        -String name
        -String password
        -String email
        -String status
    }

    class Passenger {
        <<entity>>
        -TariffProfile tariffProfile
    }

    class Driver {
        <<entity>>
    }

    class Role {
        <<entity>>
        -UUID id
        -String name
    }

    class UserRole {
        <<entity>>
        -UUID userId
        -UUID roleId
    }

    class TariffProfile {
        <<enumeration>>
        COMMON
        STUDENT
        SOCIAL
    }

    class Vehicle {
        <<entity>>
        -UUID id
        -UUID driverId
        -int seatCapacity
        -String status
    }

    class AuthController {
        +login(credentials) ResponseEntity~String~
    }

    class UserController {
        +registerPassenger(request) ResponseEntity~Passenger~
        +registerDriver(request) ResponseEntity~Driver~
        +registerVehicle(request) ResponseEntity~Vehicle~
        +getTariffProfile(userId) TariffProfile
        +manageVehicleCapacity(vehicleId, seatCapacity) Vehicle
    }

    class AuthService {
        +authenticate(email, password) String
        +generateJwt(user) String
        +validateJwt(jwt) boolean
    }

    class UserService {
        +registerPassenger(request) Passenger
        +registerDriver(request) Driver
        +registerVehicle(request) Vehicle
        +getTariffProfile(userId) TariffProfile
        +manageVehicleCapacity(vehicleId, seatCapacity) Vehicle
    }

    class UserRepository {
        <<interface>>
        +findByEmail(email) Optional~User~
        +findById(userId) Optional~User~
        +save(user) User
    }

    Passenger --|> User
    Driver --|> User
    User "1" --> "*" UserRole : assigned roles
    UserRole "*" --> "1" Role : references
    Passenger --> TariffProfile : has
    Driver "1" --> "*" Vehicle : owns
    AuthController --> AuthService
    AuthService --> UserRepository
    UserController --> UserService
    UserService --> UserRepository
    UserRepository ..> User : persists
```

#### Serviço de Rotas e Corridas

```mermaid
classDiagram
    direction LR

    class RouteController {
        +createRoute(request) ResponseEntity~Route~
        +getRoute(routeId) ResponseEntity~Route~
        +listRoutes(origin, destination) List~Route~
    }

    class RideController {
        +scheduleRide(request, jwt) ResponseEntity~Ride~
        +getRideStatus(rideId, jwt) ResponseEntity~Ride~
    }

    class RideService {
        +validateJwt(jwt) boolean
        +scheduleRide(passengerId, routeId, sharedRide, paymentMethod) Ride
        +getRideStatus(rideId) Ride
    }

    class RouteMatchingComponent {
        +findCompatibleRoutes(passengerId, origin, destination) List~Route~
        +hasAvailableSeats(route) boolean
        +allocatePassenger(route, passengerId) void
    }

    class UserServiceClient {
        +getTariffProfile(passengerId, jwt) TariffProfile
    }

    class MapsClient {
        +calculateRouteDistance(origin, destination) BigDecimal
        +estimateTravelTime(origin, destination) int
        +calculateRoute(origin, destination, intermediateStops) String
    }

    class RideEventPublisher {
        +publishRideScheduled(event) void
    }

    class RouteRepository {
        <<interface>>
        +findById(routeId) Optional~Route~
        +findAvailableRoutes(origin, destination) List~Route~
        +save(route) Route
    }

    class RideRepository {
        <<interface>>
        +findById(rideId) Optional~Ride~
        +findByPassengerId(passengerId) List~Ride~
        +save(ride) Ride
    }

    class Route {
        <<entity>>
        -UUID id
        -UUID driverId
        -UUID vehicleId
        -String origin
        -String intermediateStops
        -String destination
        -LocalDateTime departureTime
        -int maxSeats
        -int occupiedSeats
    }

    class Ride {
        <<entity>>
        -UUID id
        -UUID passengerId
        -UUID routeId
        -boolean sharedRide
        -String paymentMethod
        -String status
    }

    class RideScheduledEvent {
        +UUID rideId
        +UUID passengerId
        +TariffProfile tariffProfile
        +boolean sharedRide
        +String paymentMethod
        +BigDecimal distanceKm
    }

    RouteController --> RideService
    RideController --> RideService
    RideService --> RouteMatchingComponent
    RideService --> UserServiceClient
    RideService --> MapsClient
    RideService --> RouteRepository
    RideService --> RideRepository
    RideService --> RideEventPublisher
    RouteMatchingComponent ..> Route : validates and updates
    RideRepository ..> Ride : persists
    RouteRepository ..> Route : persists
    RideEventPublisher ..> RideScheduledEvent : publishes to payments.process
    Route "1" --> "*" Ride : accommodates
```

#### Serviço de Pagamentos

```mermaid
classDiagram
    direction LR

    class RideScheduledEvent {
        +UUID rideId
        +UUID passengerId
        +TariffProfile tariffProfile
        +boolean sharedRide
        +String paymentMethod
        +BigDecimal distanceKm
    }

    class TariffProfile {
        <<enumeration>>
        COMMON
        STUDENT
        SOCIAL
    }

    class PaymentEventListener {
        +onRideScheduled(event) void
    }

    class PaymentService {
        +processPayment(event) Payment
        +calculateFare(tariffProfile, sharedRide, distanceKm, passengerCount) BigDecimal
    }

    class PaymentGatewayClient {
        +charge(amount, paymentMethod) boolean
        +validateSocialVoucher(voucherCode) boolean
    }

    class PaymentRepository {
        <<interface>>
        +findByRideId(rideId) Optional~Payment~
        +save(payment) Payment
    }

    class PaymentEventPublisher {
        +publishPaymentProcessed(event) void
    }

    class Payment {
        <<entity>>
        -UUID id
        -UUID rideId
        -UUID passengerId
        -BigDecimal finalAmount
        -String paymentMethod
        -String status
    }

    class PaymentProcessedEvent {
        +UUID paymentId
        +UUID rideId
        +UUID passengerId
        +BigDecimal finalAmount
        +String status
    }

    RideScheduledEvent --> TariffProfile
    PaymentEventListener ..> RideScheduledEvent : consumes from payments.process
    PaymentEventListener --> PaymentService
    PaymentService --> PaymentGatewayClient
    PaymentService --> PaymentRepository
    PaymentService --> PaymentEventPublisher
    PaymentRepository ..> Payment : persists
    PaymentEventPublisher ..> PaymentProcessedEvent : publishes to notifications.dispatch
```

#### Serviço de Notificações

```mermaid
classDiagram
    direction LR

    class PaymentProcessedEvent {
        +UUID paymentId
        +UUID rideId
        +UUID passengerId
        +BigDecimal finalAmount
        +String status
    }

    class NotificationEventListener {
        +onPaymentProcessed(event) void
    }

    class NotificationService {
        +sendConfirmation(event) Notification
        +notifyPassenger(passengerId, rideId, message) Notification
        +notifyDriver(driverId, rideId, message) Notification
    }

    class NotificationRepository {
        <<interface>>
        +save(notification) Notification
    }

    class Notification {
        <<entity>>
        -UUID id
        -UUID passengerId
        -UUID rideId
        -String message
        -LocalDateTime sentAt
    }

    NotificationEventListener ..> PaymentProcessedEvent : consumes from notifications.dispatch
    NotificationEventListener --> NotificationService
    NotificationService --> NotificationRepository
    NotificationRepository ..> Notification : persists
```
