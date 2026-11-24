workspace "MobiSocial" "Mobilidade urbana inclusiva - SOA + Event-Driven (Spring Boot)" {

    model {
        passageiro = person "Passageiro" "Usuário comum, estudante ou paciente de UBS. Solicita, agenda e acompanha corridas." "Pessoa"
        motorista = person "Motorista Parceiro" "Cadastra veículos, aceita rotas planejadas e transporta passageiros." "Pessoa"

        gateway = softwareSystem "Gateway Externo de Pagamentos" "Processa cobranças, rateios e validação de vouchers sociais." "Externo"
        mapas = softwareSystem "API de Mapas / Geolocalização" "Fornece distância, tempo estimado e traçado de rotas urbanas." "Externo"

        mobisocial = softwareSystem "MobiSocial" "Plataforma de rotas, corridas compartilhadas e pagamentos com tarifa social." {

            frontend = container "Aplicação Front-end" "Interface para cadastro, login, solicitação de corridas e acompanhamento da viagem." "Web App (SPA)" "Frontend"

            userService = container "Serviço de Usuários" "Cadastro, login (emissão de JWT), perfis tarifários (comum, estudante, social) e regras de negócio de usuários e motoristas." "Spring Boot (REST)" "Servico" {
                authController = component "AuthController" "Expõe endpoints REST (/api/auth/login) para autenticação de usuários e emissão de token JWT." "Spring Web (@RestController)" "Componente"
                userController = component "UserController" "Expõe endpoints REST (/api/users) para cadastro de usuários, gestão de veículos/assentos e consulta de perfis tarifários." "Spring Web (@RestController)" "Componente"
                authService = component "AuthService" "Valida credenciais de acesso e gera tokens JWT contendo perfil tarifário e papel do usuário." "Spring Bean (@Service)" "Componente"
                userServiceComp = component "UserService" "Orquestra regras de negócio de cadastro de passageiros/motoristas, perfis tarifários e veículos." "Spring Bean (@Service)" "Componente"
                userRepository = component "UserRepository" "Persiste e consulta usuários, perfis tarifários e veículos no PostgreSQL." "Spring Data JPA (@Repository)" "Componente"
            }

            rideService = container "Serviço de Rotas e Corridas" "Cria rotas, agenda corridas, pareia passageiros e publica eventos. Valida o JWT recebido." "Spring Boot (REST)" "Servico" {
                routeController = component "RouteController" "Expõe endpoints REST (/api/routes) para criação, consulta e gerenciamento de rotas oferecidas por motoristas." "Spring Web (@RestController)" "Componente"
                rideController = component "RideController" "Expõe endpoints REST (/api/rides) para solicitação, agendamento e acompanhamento de corridas por passageiros." "Spring Web (@RestController)" "Componente"
                rideServiceComp = component "RideService" "Orquestra as regras de negócio de rotas e corridas, coordena o pareamento e aciona persistência e publicação de eventos." "Spring Bean (@Service)" "Componente" {
                    url "{workspace}/diagrams#N4-Codigo-Corridas"
                }
                routeMatchingComponent = component "RouteMatchingComponent" "Executa a lógica de compatibilidade geográfica e de horários para parear passageiros e rotas disponíveis." "Spring Bean (@Component)" "Componente"
                userServiceClient = component "UserServiceClient" "Consulta o Serviço de Usuários via HTTP/REST para validar perfis tarifários (comum, estudante, social) e cadastros." "Spring HTTP Client (@Component)" "Componente"
                mapsClient = component "MapsClient" "Integra-se via HTTPS com a API de Mapas / Geolocalização para obter distância, tempo estimado e traçado de rotas." "Spring HTTP Client (@Component)" "Componente"
                rideEventPublisher = component "RideEventPublisher" "Publica o evento RideScheduledEvent na fila payments.process do RabbitMQ após confirmar a corrida." "Spring AMQP (RabbitTemplate)" "Componente"
                routeRepository = component "RouteRepository" "Persiste e consulta rotas planejadas e disponibilidade de vagas no PostgreSQL." "Spring Data JPA (@Repository)" "Componente"
                rideRepository = component "RideRepository" "Persiste e consulta solicitações e agendamentos de corridas no PostgreSQL." "Spring Data JPA (@Repository)" "Componente"
            }

            broker = container "Message Broker" "Filas payments.process e notifications.dispatch." "RabbitMQ (AMQP)" "Broker" {
                paymentsProcessQueue = component "payments.process" "Fila durável de eventos de corridas agendadas aguardando processamento financeiro (RideScheduledEvent)." "RabbitMQ Queue (AMQP)" "Fila"
                notificationsDispatchQueue = component "notifications.dispatch" "Fila durável de eventos de pagamentos processados aguardando envio de aviso (PaymentProcessedEvent)." "RabbitMQ Queue (AMQP)" "Fila"
            }

            paymentService = container "Serviço de Pagamentos" "Consome corridas agendadas, calcula rateio/tarifa social e processa a cobrança." "Spring Boot (Worker)" "Servico" {
                paymentEventListener = component "PaymentEventListener" "Consome eventos RideScheduledEvent da fila payments.process e aciona o processamento financeiro." "Spring AMQP (@RabbitListener)" "Componente"
                paymentServiceComp = component "PaymentService" "Calcula o rateio (carpooling), aplica descontos de tarifa social (estudante/UBS) e coordena cobrança, persistência e publicação de evento." "Spring Bean (@Service)" "Componente" {
                    url "{workspace}/diagrams#N4-Codigo-Pagamentos"
                }
                paymentGatewayClient = component "PaymentGatewayClient" "Integra-se via HTTPS com o Gateway Externo de Pagamentos para processar PIX, cartão ou voucher social." "Spring HTTP Client (@Component)" "Componente"
                paymentRepository = component "PaymentRepository" "Persiste e consulta transações financeiras, rateios e subsídios no PostgreSQL." "Spring Data JPA (@Repository)" "Componente"
                paymentEventPublisher = component "PaymentEventPublisher" "Publica o evento PaymentProcessedEvent na fila notifications.dispatch após aprovação da cobrança." "Spring AMQP (RabbitTemplate)" "Componente"
            }

            notificationService = container "Serviço de Notificações" "Consome eventos finais e emite avisos de corrida e pagamento." "Spring Boot (Worker)" "Servico" {
                notificationEventListener = component "NotificationEventListener" "Consome eventos PaymentProcessedEvent da fila notifications.dispatch e aciona a emissão de avisos." "Spring AMQP (@RabbitListener)" "Componente"
                notificationServiceComp = component "NotificationService" "Formata e emite avisos de confirmação de corrida e pagamento aprovado para passageiro e motorista." "Spring Bean (@Service)" "Componente"
                notificationRepository = component "NotificationRepository" "Registra o histórico de envios e status das notificações no PostgreSQL." "Spring Data JPA (@Repository)" "Componente"
            }

            db = container "Banco de Dados" "Usuários, veículos, rotas, corridas e pagamentos (schema por serviço)." "PostgreSQL" "Database"
        }

        # --- Nível 1: Contexto
        passageiro -> mobisocial "Cadastra-se, solicita e acompanha corridas" "HTTPS"
        motorista -> mobisocial "Cadastra veículos e aceita rotas" "HTTPS"
        mobisocial -> gateway "Processa cobranças e vouchers" "HTTPS"
        mobisocial -> mapas "Calcula rotas e distâncias" "HTTPS"

        # --- Nível 2: Containers
        passageiro -> frontend "Usa" "HTTPS"
        motorista -> frontend "Usa" "HTTPS"
        frontend -> passageiro "Disponibiliza respostas e confirmações" "HTTPS"

        frontend -> userService "Cadastro e login (/api/users, /api/auth)" "HTTPS/REST (JSON)"
        frontend -> rideService "Rotas e corridas (/api/rides, /api/routes)" "HTTPS/REST (JSON)"
        userService -> frontend "Retorna JWT" "HTTPS/REST (JSON)"

        userService -> db "Lê e grava usuários e perfis" "JDBC"
        db -> userService "Retorna usuários e perfis" "JDBC"

        rideService -> userService "Consulta perfil tarifário do passageiro" "HTTP/REST"
        rideService -> mapas "Consulta rotas e distâncias" "HTTPS"
        mapas -> rideService "Retorna trajeto estimado" "HTTPS"
        rideService -> db "Lê e grava rotas e corridas" "JDBC"
        db -> rideService "Retorna rotas e corridas" "JDBC"
        rideService -> broker "Publica evento em payments.process" "AMQP"

        broker -> paymentService "Entrega payments.process" "AMQP"
        paymentService -> db "Lê e grava pagamentos" "JDBC"
        db -> paymentService "Retorna dados de pagamento" "JDBC"
        paymentService -> gateway "Cobra" "HTTPS"
        gateway -> paymentService "Retorna status da cobrança" "HTTPS"
        paymentService -> broker "Publica evento em notifications.dispatch" "AMQP"

        broker -> notificationService "Entrega notifications.dispatch" "AMQP"
        notificationService -> db "Registra envios" "JDBC"
        db -> notificationService "Confirma registros" "JDBC"
        notificationService -> passageiro "Envia confirmação da corrida e do pagamento" "HTTPS/Push"
        notificationService -> motorista "Envia aviso da corrida agendada" "HTTPS/Push"

        # --- Nível 3: Componentes (Serviço de Usuários, Serviço de Rotas e Corridas, Message Broker, Serviço de Pagamentos e Serviço de Notificações)
        frontend -> authController "Realiza login (/api/auth)" "HTTPS/REST (JSON)"
        frontend -> userController "Cadastra usuários e veículos (/api/users)" "HTTPS/REST (JSON)"
        userServiceClient -> userController "Consulta perfil tarifário do passageiro" "HTTP/REST"

        authController -> authService "Delega autenticação e geração de JWT"
        userController -> userServiceComp "Delega cadastro e consulta de usuários/veículos"
        authService -> userRepository "Busca credenciais do usuário"
        userServiceComp -> userRepository "Persiste e consulta usuários e veículos"
        userRepository -> db "Lê e grava usuários e veículos" "JDBC"

        frontend -> routeController "Cria e consulta rotas (/api/routes)" "HTTPS/REST (JSON)"
        frontend -> rideController "Solicita e acompanha corridas (/api/rides)" "HTTPS/REST (JSON)"

        routeController -> rideServiceComp "Delega criação e gestão de rotas"
        rideController -> rideServiceComp "Delega agendamento e consulta de corridas"

        rideServiceComp -> routeMatchingComponent "Solicita pareamento entre passageiro e rotas disponíveis"
        routeMatchingComponent -> routeRepository "Consulta rotas ativas e vagas"

        rideServiceComp -> userServiceClient "Solicita verificação de perfil tarifário e status do usuário"

        rideServiceComp -> mapsClient "Solicita cálculo de distância, tempo e traçado"
        mapsClient -> mapas "Consulta rotas e distâncias" "HTTPS"

        rideServiceComp -> routeRepository "Persiste e atualiza rotas"
        rideServiceComp -> rideRepository "Persiste e atualiza corridas"
        routeRepository -> db "Lê e grava rotas" "JDBC"
        rideRepository -> db "Lê e grava corridas" "JDBC"

        rideServiceComp -> rideEventPublisher "Solicita publicação do evento de corrida agendada"
        rideEventPublisher -> paymentsProcessQueue "Publica RideScheduledEvent (payments.process)" "AMQP"

        paymentsProcessQueue -> paymentEventListener "Entrega RideScheduledEvent (payments.process)" "AMQP"
        paymentEventListener -> paymentServiceComp "Aciona cálculo de rateio/tarifa social e cobrança"
        paymentServiceComp -> paymentGatewayClient "Solicita cobrança ou validação de voucher"
        paymentGatewayClient -> gateway "Processa cobrança e vouchers" "HTTPS"
        paymentServiceComp -> paymentRepository "Persiste transação e rateio"
        paymentRepository -> db "Lê e grava pagamentos" "JDBC"
        paymentServiceComp -> paymentEventPublisher "Solicita publicação do pagamento aprovado"
        paymentEventPublisher -> notificationsDispatchQueue "Publica PaymentProcessedEvent (notifications.dispatch)" "AMQP"

        notificationsDispatchQueue -> notificationEventListener "Entrega PaymentProcessedEvent (notifications.dispatch)" "AMQP"
        notificationEventListener -> notificationServiceComp "Delega emissão do aviso de corrida e pagamento"
        notificationServiceComp -> notificationRepository "Salva registro do envio"
        notificationRepository -> db "Registra envios de notificações" "JDBC"

        # --- Nível 4 (Código): Pacotes, Classes, Interfaces JPA, Entidades e Eventos
        group "br.ufc.quixada.arquitetura.mobisocial.user.model" {
            clsTariffProfile = element "TariffProfile" "<<enumeration>>" "COMMON | STUDENT | SOCIAL" "CodigoEnum"
        }

        group "br.ufc.quixada.arquitetura.mobisocial.event" {
            clsRideScheduledEvent = element "RideScheduledEvent" "<<record / event>>" "+rideId: UUID | +passengerId: UUID | +tariffProfile: TariffProfile | +sharedRide: boolean | +paymentMethod: String | +distanceKm: BigDecimal" "CodigoEvento"
            clsPaymentProcessedEvent = element "PaymentProcessedEvent" "<<record / event>>" "+paymentId: UUID | +rideId: UUID | +passengerId: UUID | +finalAmount: BigDecimal | +status: String" "CodigoEvento"
        }

        group "br.ufc.quixada.arquitetura.mobisocial.ride" {
            clsRouteController = element "RouteController" "<<@RestController>>" "+createRoute(request): ResponseEntity<Route> | +getRoute(routeId): ResponseEntity<Route> | +listRoutes(origin, destination): List<Route>" "CodigoClasse"
            clsRideController = element "RideController" "<<@RestController>>" "+scheduleRide(request, jwt): ResponseEntity<Ride> | +getRideStatus(rideId, jwt): ResponseEntity<Ride>" "CodigoClasse"
            clsRideService = element "RideService" "<<@Service>>" "+validateJwt(jwt): boolean | +scheduleRide(passengerId, routeId, sharedRide, paymentMethod): Ride | +getRideStatus(rideId): Ride" "CodigoClasse"
            clsRouteMatchingComponent = element "RouteMatchingComponent" "<<@Component>>" "+findCompatibleRoutes(passengerId, origin, destination): List<Route> | +hasAvailableSeats(route): boolean | +allocatePassenger(route, passengerId): void" "CodigoClasse"
            clsUserServiceClient = element "UserServiceClient" "<<@Component>>" "+getTariffProfile(passengerId, jwt): TariffProfile" "CodigoClasse"
            clsMapsClient = element "MapsClient" "<<@Component>>" "+calculateRouteDistance(origin, destination): BigDecimal | +estimateTravelTime(origin, destination): int | +calculateRoute(origin, destination, stops): String" "CodigoClasse"
            clsRideEventPublisher = element "RideEventPublisher" "<<@Component>>" "+publishRideScheduled(event): void" "CodigoClasse"
            clsRouteRepository = element "RouteRepository" "<<interface>> JpaRepository" "+findById(routeId): Optional<Route> | +findAvailableRoutes(origin, destination): List<Route> | +save(route): Route" "CodigoInterface"
            clsRideRepository = element "RideRepository" "<<interface>> JpaRepository" "+findById(rideId): Optional<Ride> | +findByPassengerId(passengerId): List<Ride> | +save(ride): Ride" "CodigoInterface"
            clsRoute = element "Route" "<<@Entity>> schema=rides" "-id: UUID | -driverId: UUID | -vehicleId: UUID | -origin: String | -intermediateStops: String | -destination: String | -departureTime: LocalDateTime | -maxSeats: int | -occupiedSeats: int" "CodigoEntidade"
            clsRide = element "Ride" "<<@Entity>> schema=rides" "-id: UUID | -passengerId: UUID | -routeId: UUID | -sharedRide: boolean | -paymentMethod: String | -status: String" "CodigoEntidade"
        }

        group "br.ufc.quixada.arquitetura.mobisocial.payment" {
            clsPaymentEventListener = element "PaymentEventListener" "<<@RabbitListener>>" "+onRideScheduled(event): void" "CodigoClasse"
            clsPaymentService = element "PaymentService" "<<@Service>>" "+processPayment(event): Payment | +calculateFare(tariffProfile, sharedRide, distanceKm, passengerCount): BigDecimal" "CodigoClasse"
            clsPaymentGatewayClient = element "PaymentGatewayClient" "<<@Component>>" "+charge(amount, paymentMethod): boolean | +validateSocialVoucher(voucherCode): boolean" "CodigoClasse"
            clsPaymentRepository = element "PaymentRepository" "<<interface>> JpaRepository" "+findByRideId(rideId): Optional<Payment> | +save(payment): Payment" "CodigoInterface"
            clsPaymentEventPublisher = element "PaymentEventPublisher" "<<@Component>>" "+publishPaymentProcessed(event): void" "CodigoClasse"
            clsPayment = element "Payment" "<<@Entity>> schema=payments" "-id: UUID | -rideId: UUID | -passengerId: UUID | -finalAmount: BigDecimal | -paymentMethod: String | -status: String" "CodigoEntidade"
        }

        clsRouteController -> clsRideService "invoca"
        clsRideController -> clsRideService "invoca"
        clsRideService -> clsRouteMatchingComponent "valida rota e aloca assento"
        clsRideService -> clsUserServiceClient "consulta perfil tarifário"
        clsRideService -> clsMapsClient "calcula distância e tempo"
        clsRideService -> clsRouteRepository "consulta e salva rotas"
        clsRideService -> clsRideRepository "consulta e salva corridas"
        clsRideService -> clsRideEventPublisher "publica após commit"
        clsUserServiceClient -> clsTariffProfile "retorna"
        clsRouteMatchingComponent -> clsRoute "valida e atualiza assentos"
        clsRouteRepository -> clsRoute "persiste (@Entity)"
        clsRideRepository -> clsRide "persiste (@Entity)"
        clsRoute -> clsRide "1..* acomoda"
        clsRideEventPublisher -> clsRideScheduledEvent "instancia e publica (payments.process)"
        clsRideScheduledEvent -> clsTariffProfile "contém"

        clsPaymentEventListener -> clsRideScheduledEvent "consome (payments.process)"
        clsPaymentEventListener -> clsPaymentService "delega processamento"
        clsPaymentService -> clsPaymentGatewayClient "cobra ou valida voucher"
        clsPaymentService -> clsPaymentRepository "verifica idempotência e salva"
        clsPaymentService -> clsPaymentEventPublisher "aciona publicação"
        clsPaymentRepository -> clsPayment "persiste (@Entity)"
        clsPaymentEventPublisher -> clsPaymentProcessedEvent "instancia e publica (notifications.dispatch)"
    }

    views {
        properties {
            "structurizr.sort" "created"
        }

        systemContext mobisocial "N1-Contexto" "C4 Nível 1 - Diagrama de Contexto" {
            include *
            autolayout lr
        }

        container mobisocial "N2-Containers" "C4 Nível 2 - Diagrama de Containers" {
            include *
            autolayout lr
        }

        component userService "N3-Usuarios" "C4 Nível 3 - Componentes do Serviço de Usuários" {
            include *
            autolayout lr
        }

        component rideService "N3-RotasCorridas" "C4 Nível 3 - Componentes do Serviço de Rotas e Corridas" {
            include *
            autolayout lr
        }

        component broker "N3-Broker" "C4 Nível 3 - Filas do Message Broker (RabbitMQ)" {
            include *
            autolayout lr
        }

        component paymentService "N3-Pagamentos" "C4 Nível 3 - Componentes do Serviço de Pagamentos" {
            include *
            autolayout lr
        }

        component notificationService "N3-Notificacoes" "C4 Nível 3 - Componentes do Serviço de Notificações" {
            include *
            autolayout lr
        }

        dynamic mobisocial "N4-1-Autenticacao" "Autenticação do passageiro e emissão do JWT" {
            passageiro -> frontend "Informa email e senha"
            frontend -> userService "POST /api/auth/login"
            userService -> db "Busca credenciais e perfil tarifário"
            db -> userService "Retorna o usuário"
            userService -> frontend "Retorna JWT"
            frontend -> passageiro "Disponibiliza o token ao passageiro"
            autolayout lr
        }

        dynamic mobisocial "N4-2-Agendamento" "Agendamento compartilhado e publicação do evento" {
            passageiro -> frontend "Solicita corrida com JWT"
            frontend -> rideService "POST /api/rides e valida o JWT"
            rideService -> userService "Consulta perfil tarifário"
            userService -> db "Busca o perfil tarifário"
            rideService -> mapas "Calcula rota e distância"
            mapas -> rideService "Retorna trajeto estimado"
            rideService -> db "Verifica assentos disponíveis"
            db -> rideService "Confirma a rota ativa"
            rideService -> db "Salva a corrida agendada"
            db -> rideService "Confirma o agendamento"
            rideService -> broker "Publica RideScheduledEvent"
            autolayout lr
        }

        dynamic mobisocial "N4-3-Pagamento" "Rateio, tarifa social e cobrança" {
            broker -> paymentService "Entrega RideScheduledEvent"
            paymentService -> db "Consulta dados da corrida e passageiros"
            db -> paymentService "Retorna dados necessários"
            paymentService -> gateway "Calcula o rateio, aplica a tarifa social e solicita a cobrança"
            gateway -> paymentService "Retorna status da cobrança"
            paymentService -> db "Salva pagamento e rateios"
            db -> paymentService "Confirma o registro"
            paymentService -> broker "Publica PaymentProcessedEvent"
            autolayout lr
        }

        dynamic mobisocial "N4-4-Notificacao" "Confirmação da corrida e do pagamento" {
            broker -> notificationService "Entrega PaymentProcessedEvent"
            notificationService -> db "Formata, registra e envia a notificação"
            db -> notificationService "Confirma o registro"
            notificationService -> passageiro "Envia confirmação da corrida e do pagamento"
            notificationService -> motorista "Envia aviso da corrida agendada"
            autolayout lr
        }

        custom "N4-Codigo-Corridas" "C4 Nível 4 (Código) - Classes de Rotas e Corridas" "Diagrama de classes, interfaces JPA, entidades e eventos gerado pelo Structurizr para o Serviço de Rotas e Corridas" {
            include clsRouteController clsRideController clsRideService clsRouteMatchingComponent clsUserServiceClient clsMapsClient clsRideEventPublisher clsRouteRepository clsRideRepository clsRoute clsRide clsRideScheduledEvent clsTariffProfile
            autolayout lr
        }

        custom "N4-Codigo-Pagamentos" "C4 Nível 4 (Código) - Classes de Pagamentos" "Diagrama de classes, interface JPA, entidade e eventos gerado pelo Structurizr para o Serviço de Pagamentos" {
            include clsRideScheduledEvent clsTariffProfile clsPaymentEventListener clsPaymentService clsPaymentGatewayClient clsPaymentRepository clsPaymentEventPublisher clsPayment clsPaymentProcessedEvent
            autolayout lr
        }

        styles {
            element "Pessoa" {
                shape Person
                background #08427b
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "Externo" {
                background #8a8a8a
                color #ffffff
            }
            element "Frontend" {
                shape WebBrowser
                background #0277bd
                color #ffffff
            }
            element "Servico" {
                background #2e7d32
                color #ffffff
            }
            element "Componente" {
                background #43a047
                color #ffffff
            }
            element "Broker" {
                shape Pipe
                background #e65100
                color #ffffff
            }
            element "Fila" {
                shape Pipe
                background #fb8c00
                color #ffffff
            }
            element "Database" {
                shape Cylinder
                background #5e35b1
                color #ffffff
            }
            element "Group" {
                color #94a3b8
                border dashed
            }
            element "CodigoClasse" {
                shape RoundedBox
                background #1e293b
                color #f8fafc
                border solid
                stroke #94a3b8
                strokeWidth 2
            }
            element "CodigoInterface" {
                shape RoundedBox
                background #1e293b
                color #f8fafc
                border dashed
                stroke #cbd5e1
                strokeWidth 3
            }
            element "CodigoEntidade" {
                shape RoundedBox
                background #27223d
                color #f8fafc
                border solid
                stroke #a78bfa
                strokeWidth 2
            }
            element "CodigoEvento" {
                shape RoundedBox
                background #2d2118
                color #f8fafc
                border solid
                stroke #fbbf24
                strokeWidth 2
            }
            element "CodigoEnum" {
                shape RoundedBox
                background #27272a
                color #e4e4e7
                border dotted
                stroke #a1a1aa
                strokeWidth 2
            }
            relationship "Relationship" {
                routing Orthogonal
                fontSize 22
            }
        }
    }
}