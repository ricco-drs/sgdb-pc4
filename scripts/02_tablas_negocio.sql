-- ---------------------------------------------------------------------
-- TABLA: T_TIPO_PRESTAMO (catalogo de productos crediticios)
-- ---------------------------------------------------------------------
CREATE TABLE t_tipo_prestamo (
  id_tipo_prestamo      NUMBER          NOT NULL,
  nombre                VARCHAR2(60)    NOT NULL,
  tasa_interes_mensual  NUMBER(7,4)     NOT NULL,
  monto_minimo          NUMBER(12,2)    NOT NULL,
  monto_maximo          NUMBER(12,2)    NOT NULL,
  plazo_minimo_meses    NUMBER(3)       NOT NULL,
  plazo_maximo_meses    NUMBER(3)       NOT NULL,
  estado                VARCHAR2(10)    DEFAULT 'ACTIVO' NOT NULL,
  fecha_registro        DATE            DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_tipo_prestamo PRIMARY KEY (id_tipo_prestamo),
  CONSTRAINT uk_tipo_prestamo_nombre UNIQUE (nombre),
  CONSTRAINT ck_tipo_tasa   CHECK (tasa_interes_mensual > 0),
  CONSTRAINT ck_tipo_montos CHECK (monto_maximo > monto_minimo),
  CONSTRAINT ck_tipo_plazos CHECK (plazo_maximo_meses >= plazo_minimo_meses),
  CONSTRAINT ck_tipo_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);

-- ---------------------------------------------------------------------
-- TABLA: T_CLIENTE (datos de los solicitantes)
-- FK a t_usuario (seguridad) -> se agrega en script 05
-- ---------------------------------------------------------------------
CREATE TABLE t_cliente (
  id_cliente           NUMBER          NOT NULL,
  dni                  VARCHAR2(8)     NOT NULL,
  nombres              VARCHAR2(100)   NOT NULL,
  apellidos            VARCHAR2(100)   NOT NULL,
  fecha_nacimiento     DATE            NOT NULL,
  telefono             VARCHAR2(15),
  email                VARCHAR2(120),
  direccion            VARCHAR2(200),
  ingreso_mensual      NUMBER(12,2)    NOT NULL,
  estado               VARCHAR2(10)    DEFAULT 'ACTIVO' NOT NULL,
  fecha_registro       DATE            DEFAULT SYSDATE NOT NULL,
  id_usuario_registro  NUMBER          NOT NULL,
  CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
  CONSTRAINT uk_cliente_dni UNIQUE (dni),
  CONSTRAINT ck_cliente_dni     CHECK (LENGTH(dni) = 8),
  CONSTRAINT ck_cliente_ingreso CHECK (ingreso_mensual > 0),
  CONSTRAINT ck_cliente_estado  CHECK (estado IN ('ACTIVO','INACTIVO'))
);

-- ---------------------------------------------------------------------
-- TABLA: T_SOLICITUD (solicitudes de prestamo con evaluacion)
-- FK a t_usuario (seguridad) -> se agrega en script 05
-- ---------------------------------------------------------------------
CREATE TABLE t_solicitud (
  id_solicitud          NUMBER          NOT NULL,
  id_cliente            NUMBER          NOT NULL,
  id_tipo_prestamo      NUMBER          NOT NULL,
  monto_solicitado      NUMBER(12,2)    NOT NULL,
  plazo_meses           NUMBER(3)       NOT NULL,
  ingreso_declarado     NUMBER(12,2)    NOT NULL,
  capacidad_pago        NUMBER(12,2),
  cuota_estimada        NUMBER(12,2),
  ratio_cuota_ingreso   NUMBER(7,4),
  calificacion          CHAR(1),
  estado                VARCHAR2(12)    DEFAULT 'PENDIENTE' NOT NULL,
  fecha_solicitud       DATE            DEFAULT SYSDATE NOT NULL,
  id_analista           NUMBER          NOT NULL,
  fecha_decision        DATE,
  id_analista_decision  NUMBER,
  CONSTRAINT pk_solicitud PRIMARY KEY (id_solicitud),
  CONSTRAINT ck_solicitud_calif  CHECK (calificacion IN ('A','B','C','D')),
  CONSTRAINT ck_solicitud_estado CHECK (estado IN ('PENDIENTE','APROBADO','RECHAZADO','EN_REVISION')),
  CONSTRAINT fk_solicitud_cliente FOREIGN KEY (id_cliente)
    REFERENCES t_cliente (id_cliente),
  CONSTRAINT fk_solicitud_tipo FOREIGN KEY (id_tipo_prestamo)
    REFERENCES t_tipo_prestamo (id_tipo_prestamo)
);

-- ---------------------------------------------------------------------
-- TABLA: T_PRESTAMO (prestamos aprobados y desembolsados)
-- FK a t_usuario (seguridad) -> se agrega en script 05
-- ---------------------------------------------------------------------
CREATE TABLE t_prestamo (
  id_prestamo           NUMBER          NOT NULL,
  id_solicitud          NUMBER          NOT NULL,
  monto_aprobado        NUMBER(12,2)    NOT NULL,
  plazo_meses           NUMBER(3)       NOT NULL,
  tasa_interes_mensual  NUMBER(7,4)     NOT NULL,
  cuota_mensual         NUMBER(12,2)    NOT NULL,
  saldo_pendiente       NUMBER(12,2)    NOT NULL,
  fecha_desembolso      DATE            DEFAULT SYSDATE NOT NULL,
  fecha_primera_cuota   DATE            NOT NULL,
  estado                VARCHAR2(10)    DEFAULT 'VIGENTE' NOT NULL,
  id_analista_aprobador NUMBER          NOT NULL,
  fecha_aprobacion      DATE            DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_prestamo PRIMARY KEY (id_prestamo),
  CONSTRAINT uk_prestamo_solicitud UNIQUE (id_solicitud),
  CONSTRAINT ck_prestamo_estado CHECK (estado IN ('VIGENTE','CANCELADO','MOROSO')),
  CONSTRAINT fk_prestamo_solicitud FOREIGN KEY (id_solicitud)
    REFERENCES t_solicitud (id_solicitud)
);

-- ---------------------------------------------------------------------
-- TABLA: T_CUOTA (cronograma de pagos - metodo frances)
-- ---------------------------------------------------------------------
CREATE TABLE t_cuota (
  id_cuota          NUMBER          NOT NULL,
  id_prestamo       NUMBER          NOT NULL,
  numero_cuota      NUMBER(3)       NOT NULL,
  fecha_vencimiento DATE            NOT NULL,
  monto_capital     NUMBER(12,2)    NOT NULL,
  monto_interes     NUMBER(12,2)    NOT NULL,
  monto_cuota       NUMBER(12,2)    NOT NULL,
  saldo_capital     NUMBER(12,2)    NOT NULL,
  monto_pagado      NUMBER(12,2)    DEFAULT 0 NOT NULL,
  estado            VARCHAR2(10)    DEFAULT 'PENDIENTE' NOT NULL,
  fecha_pago        DATE,
  CONSTRAINT pk_cuota PRIMARY KEY (id_cuota),
  CONSTRAINT uk_cuota_prestamo_num UNIQUE (id_prestamo, numero_cuota),
  CONSTRAINT ck_cuota_numero CHECK (numero_cuota > 0),
  CONSTRAINT ck_cuota_estado CHECK (estado IN ('PENDIENTE','PAGADA','PARCIAL','MOROSA')),
  CONSTRAINT fk_cuota_prestamo FOREIGN KEY (id_prestamo)
    REFERENCES t_prestamo (id_prestamo)
);

-- ---------------------------------------------------------------------
-- TABLA: T_PAGO (pagos registrados por los cajeros)
-- FK a t_usuario (seguridad) -> se agrega en script 05
-- ---------------------------------------------------------------------
CREATE TABLE t_pago (
  id_pago       NUMBER          NOT NULL,
  id_cuota      NUMBER          NOT NULL,
  monto_pagado  NUMBER(12,2)    NOT NULL,
  fecha_pago    DATE            DEFAULT SYSDATE NOT NULL,
  medio_pago    VARCHAR2(15)    NOT NULL,
  id_cajero     NUMBER          NOT NULL,
  observacion   VARCHAR2(200),
  CONSTRAINT pk_pago PRIMARY KEY (id_pago),
  CONSTRAINT ck_pago_monto CHECK (monto_pagado > 0),
  CONSTRAINT ck_pago_medio CHECK (medio_pago IN ('EFECTIVO','TRANSFERENCIA','TARJETA')),
  CONSTRAINT fk_pago_cuota FOREIGN KEY (id_cuota)
    REFERENCES t_cuota (id_cuota)
);

-- ---------------------------------------------------------------------
-- TABLA: T_PARAMETRO (configuracion del sistema)
-- FK a t_usuario (seguridad) -> se agrega en script 05
-- ---------------------------------------------------------------------
CREATE TABLE t_parametro (
  id_parametro            NUMBER          NOT NULL,
  codigo                  VARCHAR2(30)    NOT NULL,
  descripcion             VARCHAR2(150)   NOT NULL,
  valor                   VARCHAR2(50)    NOT NULL,
  tipo_dato               VARCHAR2(10)    NOT NULL,
  fecha_modificacion      DATE            DEFAULT SYSDATE NOT NULL,
  id_usuario_modificacion NUMBER          NOT NULL,
  CONSTRAINT pk_parametro PRIMARY KEY (id_parametro),
  CONSTRAINT uk_parametro_codigo UNIQUE (codigo),
  CONSTRAINT ck_parametro_tipo CHECK (tipo_dato IN ('NUMERO','TEXTO','FECHA'))
);

-- ---------------------------------------------------------------------
-- TABLA: T_LISTA_NEGRA (clientes vetados)
-- FK a t_usuario (seguridad) -> se agrega en script 05
-- ---------------------------------------------------------------------
CREATE TABLE t_lista_negra (
  id_lista_negra       NUMBER          NOT NULL,
  id_cliente           NUMBER          NOT NULL,
  motivo               VARCHAR2(200)   NOT NULL,
  fecha_ingreso        DATE            DEFAULT SYSDATE NOT NULL,
  estado               VARCHAR2(10)    DEFAULT 'ACTIVO' NOT NULL,
  fecha_levantamiento  DATE,
  id_usuario_registro  NUMBER          NOT NULL,
  CONSTRAINT pk_lista_negra PRIMARY KEY (id_lista_negra),
  CONSTRAINT ck_lista_negra_estado CHECK (estado IN ('ACTIVO','LEVANTADO')),
  CONSTRAINT fk_lista_negra_cliente FOREIGN KEY (id_cliente)
    REFERENCES t_cliente (id_cliente)
);
