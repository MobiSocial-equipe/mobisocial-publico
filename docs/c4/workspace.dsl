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
                rideServiceComp = component "RideService" "Orquestra as regras de negócio de rotas e corridas, coordena o pareamento e aciona persistência e publicação de eventos." "Spring Bean (@Service)" "Componente"
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
                paymentServiceComp = component "PaymentService" "Calcula o rateio (carpooling), aplica descontos de tarifa social (estudante/UBS) e coordena cobrança, persistência e publicação de evento." "Spring Bean (@Service)" "Componente"
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

        frontend -> userService "Cadastro e login (/api/users, /api/auth)" "HTTPS/REST (JSON)"
        frontend -> rideService "Rotas e corridas (/api/rides, /api/routes)" "HTTPS/REST (JSON)"

        userService -> db "Lê e grava usuários e perfis" "JDBC"

        rideService -> userService "Consulta perfil tarifário do passageiro" "HTTP/REST"
        rideService -> mapas "Consulta rotas e distâncias" "HTTPS"
        rideService -> db "Lê e grava rotas e corridas" "JDBC"
        rideService -> broker "Publica evento em payments.process" "AMQP"

        broker -> paymentService "Entrega payments.process" "AMQP"
        paymentService -> db "Lê e grava pagamentos" "JDBC"
        paymentService -> gateway "Cobra" "HTTPS"
        paymentService -> broker "Publica evento em notifications.dispatch" "AMQP"

        broker -> notificationService "Entrega notifications.dispatch" "AMQP"
        notificationService -> db "Registra envios" "JDBC"

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
    }

    views {
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
            relationship "Relationship" {
                routing Orthogonal
                fontSize 22
            }
        }
    }
}