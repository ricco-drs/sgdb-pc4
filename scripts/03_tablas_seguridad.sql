-- ---------------------------------------------------------------------
-- TABLA: T_ROL (perfiles funcionales del sistema)
-- ---------------------------------------------------------------------
CREATE TABLE t_rol (
  id_rol       NUMBER          NOT NULL,
  nombre       VARCHAR2(30)    NOT NULL,
  descripcion  VARCHAR2(150),
  estado       VARCHAR2(10)    DEFAULT 'ACTIVO' NOT NULL,
  CONSTRAINT pk_rol PRIMARY KEY (id_rol),
  CONSTRAINT uk_rol_nombre UNIQUE (nombre),
  CONSTRAINT ck_rol_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);

-- ---------------------------------------------------------------------
-- TABLA: T_OPERACION (operaciones/permisos del sistema)
-- ---------------------------------------------------------------------
CREATE TABLE t_operacion (
  id_operacion  NUMBER          NOT NULL,
  codigo        VARCHAR2(40)    NOT NULL,
  descripcion   VARCHAR2(150)   NOT NULL,
  modulo        VARCHAR2(30)    NOT NULL,
  CONSTRAINT pk_operacion PRIMARY KEY (id_operacion),
  CONSTRAINT uk_operacion_codigo UNIQUE (codigo)
);

-- ---------------------------------------------------------------------
-- TABLA: T_USUARIO (usuarios del sistema con hash de contrasena)
-- ---------------------------------------------------------------------
CREATE TABLE t_usuario (
  id_usuario           NUMBER          NOT NULL,
  username             VARCHAR2(30)    NOT NULL,
  password_hash        VARCHAR2(256)   NOT NULL,
  id_rol               NUMBER          NOT NULL,
  nombre_completo      VARCHAR2(120)   NOT NULL,
  email                VARCHAR2(120),
  estado               VARCHAR2(10)    DEFAULT 'ACTIVO' NOT NULL,
  intentos_fallidos    NUMBER(2)       DEFAULT 0 NOT NULL,
  fecha_ultimo_acceso  DATE,
  fecha_creacion       DATE            DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
  CONSTRAINT uk_usuario_username UNIQUE (username),
  CONSTRAINT ck_usuario_estado CHECK (estado IN ('ACTIVO','BLOQUEADO','INACTIVO')),
  CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol)
    REFERENCES t_rol (id_rol)
);

-- ---------------------------------------------------------------------
-- TABLA: T_ROL_PERMISO (matriz de permisos rol-operacion)
-- ---------------------------------------------------------------------
CREATE TABLE t_rol_permiso (
  id_rol_permiso  NUMBER          NOT NULL,
  id_rol          NUMBER          NOT NULL,
  id_operacion    NUMBER          NOT NULL,
  CONSTRAINT pk_rol_permiso PRIMARY KEY (id_rol_permiso),
  CONSTRAINT uk_rol_operacion UNIQUE (id_rol, id_operacion),
  CONSTRAINT fk_rolperm_rol FOREIGN KEY (id_rol)
    REFERENCES t_rol (id_rol),
  CONSTRAINT fk_rolperm_operacion FOREIGN KEY (id_operacion)
    REFERENCES t_operacion (id_operacion)
);

-- ---------------------------------------------------------------------
-- TABLA: T_AUDITORIA (bitacora de acciones del sistema)
-- ---------------------------------------------------------------------
CREATE TABLE t_auditoria (
  id_auditoria          NUMBER          NOT NULL,
  id_usuario            NUMBER          NOT NULL,
  accion                VARCHAR2(30)    NOT NULL,
  entidad               VARCHAR2(40)    NOT NULL,
  id_registro_afectado  NUMBER,
  detalle               VARCHAR2(400),
  fecha_hora            TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_auditoria PRIMARY KEY (id_auditoria),
  CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuario)
    REFERENCES t_usuario (id_usuario)
);

-- ---------------------------------------------------------------------
-- TABLA: T_INTENTO_LOGIN (registro de intentos de acceso)
-- ---------------------------------------------------------------------
CREATE TABLE t_intento_login (
  id_intento   NUMBER          NOT NULL,
  id_usuario   NUMBER,
  username     VARCHAR2(30)    NOT NULL,
  exitoso      CHAR(1)         NOT NULL,
  fecha_hora   TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_intento_login PRIMARY KEY (id_intento),
  CONSTRAINT ck_intento_exitoso CHECK (exitoso IN ('S','N')),
  CONSTRAINT fk_intento_usuario FOREIGN KEY (id_usuario)
    REFERENCES t_usuario (id_usuario)
);
