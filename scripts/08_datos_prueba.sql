
-- ---- ROLES ----
INSERT INTO t_rol (id_rol, nombre, descripcion, estado)
  VALUES (seq_rol.NEXTVAL, 'ADMINISTRADOR', 'Gestiona usuarios, parametros y seguridad', 'ACTIVO');
INSERT INTO t_rol (id_rol, nombre, descripcion, estado)
  VALUES (seq_rol.NEXTVAL, 'ANALISTA', 'Registra y evalua solicitudes de prestamo', 'ACTIVO');
INSERT INTO t_rol (id_rol, nombre, descripcion, estado)
  VALUES (seq_rol.NEXTVAL, 'CAJERO', 'Registra pagos de cuotas', 'ACTIVO');
INSERT INTO t_rol (id_rol, nombre, descripcion, estado)
  VALUES (seq_rol.NEXTVAL, 'SUPERVISOR', 'Consulta estado operativo y morosidad', 'ACTIVO');
INSERT INTO t_rol (id_rol, nombre, descripcion, estado)
  VALUES (seq_rol.NEXTVAL, 'GERENTE', 'Consulta reportes consolidados (solo lectura)', 'ACTIVO');

-- ---- OPERACIONES PROTEGIDAS ----
INSERT INTO t_operacion (id_operacion, codigo, descripcion, modulo)
  VALUES (seq_operacion.NEXTVAL, 'REGISTRAR_SOLICITUD', 'Registrar solicitud de prestamo', 'VALOR');
INSERT INTO t_operacion (id_operacion, codigo, descripcion, modulo)
  VALUES (seq_operacion.NEXTVAL, 'APROBAR_PRESTAMO', 'Aprobar o rechazar solicitud', 'VALOR');
INSERT INTO t_operacion (id_operacion, codigo, descripcion, modulo)
  VALUES (seq_operacion.NEXTVAL, 'REGISTRAR_PAGO', 'Registrar pago de cuota', 'VALOR');
INSERT INTO t_operacion (id_operacion, codigo, descripcion, modulo)
  VALUES (seq_operacion.NEXTVAL, 'GESTIONAR_USUARIOS', 'Crear y administrar usuarios', 'SEGURIDAD');
INSERT INTO t_operacion (id_operacion, codigo, descripcion, modulo)
  VALUES (seq_operacion.NEXTVAL, 'GESTIONAR_PARAMETROS', 'Configurar parametros del sistema', 'ADMIN');
INSERT INTO t_operacion (id_operacion, codigo, descripcion, modulo)
  VALUES (seq_operacion.NEXTVAL, 'CONSULTAR_OPERATIVO', 'Consultas operativas del dia a dia', 'CONSULTA');
INSERT INTO t_operacion (id_operacion, codigo, descripcion, modulo)
  VALUES (seq_operacion.NEXTVAL, 'VER_REPORTES', 'Ejecutar reportes consolidados', 'REPORTE');

-- ---- USUARIOS (contrasena hasheada SHA256 con DBMS_CRYPTO) ----
INSERT INTO t_usuario (id_usuario, username, password_hash, id_rol, nombre_completo, email, estado, intentos_fallidos, fecha_creacion)
  VALUES (seq_usuario.NEXTVAL, 'admin',
    RAWTOHEX(DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW('admin123'), DBMS_CRYPTO.HASH_SH256)),
    (SELECT id_rol FROM t_rol WHERE nombre='ADMINISTRADOR'), 'Carlos Administrador', 'admin@prestafacil.pe', 'ACTIVO', 0, SYSDATE);
INSERT INTO t_usuario (id_usuario, username, password_hash, id_rol, nombre_completo, email, estado, intentos_fallidos, fecha_creacion)
  VALUES (seq_usuario.NEXTVAL, 'ana',
    RAWTOHEX(DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW('ana123'), DBMS_CRYPTO.HASH_SH256)),
    (SELECT id_rol FROM t_rol WHERE nombre='ANALISTA'), 'Ana Analista Perez', 'ana@prestafacil.pe', 'ACTIVO', 0, SYSDATE);
INSERT INTO t_usuario (id_usuario, username, password_hash, id_rol, nombre_completo, email, estado, intentos_fallidos, fecha_creacion)
  VALUES (seq_usuario.NEXTVAL, 'caja',
    RAWTOHEX(DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW('caja123'), DBMS_CRYPTO.HASH_SH256)),
    (SELECT id_rol FROM t_rol WHERE nombre='CAJERO'), 'Pedro Cajero Ruiz', 'caja@prestafacil.pe', 'ACTIVO', 0, SYSDATE);
INSERT INTO t_usuario (id_usuario, username, password_hash, id_rol, nombre_completo, email, estado, intentos_fallidos, fecha_creacion)
  VALUES (seq_usuario.NEXTVAL, 'super',
    RAWTOHEX(DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW('super123'), DBMS_CRYPTO.HASH_SH256)),
    (SELECT id_rol FROM t_rol WHERE nombre='SUPERVISOR'), 'Sofia Supervisora Diaz', 'super@prestafacil.pe', 'ACTIVO', 0, SYSDATE);
INSERT INTO t_usuario (id_usuario, username, password_hash, id_rol, nombre_completo, email, estado, intentos_fallidos, fecha_creacion)
  VALUES (seq_usuario.NEXTVAL, 'geren',
    RAWTOHEX(DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW('geren123'), DBMS_CRYPTO.HASH_SH256)),
    (SELECT id_rol FROM t_rol WHERE nombre='GERENTE'), 'Gabriel Gerente Torres', 'geren@prestafacil.pe', 'ACTIVO', 0, SYSDATE);

-- ---- MATRIZ DE PERMISOS POR ROL ----
-- ADMINISTRADOR: gestiona usuarios y parametros
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='ADMINISTRADOR'), (SELECT id_operacion FROM t_operacion WHERE codigo='GESTIONAR_USUARIOS'));
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='ADMINISTRADOR'), (SELECT id_operacion FROM t_operacion WHERE codigo='GESTIONAR_PARAMETROS'));

-- ANALISTA: registra solicitudes, aprueba y consulta
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='ANALISTA'), (SELECT id_operacion FROM t_operacion WHERE codigo='REGISTRAR_SOLICITUD'));
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='ANALISTA'), (SELECT id_operacion FROM t_operacion WHERE codigo='APROBAR_PRESTAMO'));
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='ANALISTA'), (SELECT id_operacion FROM t_operacion WHERE codigo='CONSULTAR_OPERATIVO'));

-- CAJERO: registra pagos y consulta
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='CAJERO'), (SELECT id_operacion FROM t_operacion WHERE codigo='REGISTRAR_PAGO'));
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='CAJERO'), (SELECT id_operacion FROM t_operacion WHERE codigo='CONSULTAR_OPERATIVO'));

-- SUPERVISOR: consulta operativa y ve reportes
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='SUPERVISOR'), (SELECT id_operacion FROM t_operacion WHERE codigo='CONSULTAR_OPERATIVO'));
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='SUPERVISOR'), (SELECT id_operacion FROM t_operacion WHERE codigo='VER_REPORTES'));

-- GERENTE: SOLO reportes (minimo privilegio)
INSERT INTO t_rol_permiso (id_rol_permiso, id_rol, id_operacion)
  VALUES (seq_rol_permiso.NEXTVAL, (SELECT id_rol FROM t_rol WHERE nombre='GERENTE'), (SELECT id_operacion FROM t_operacion WHERE codigo='VER_REPORTES'));

COMMIT;


-- #####################################################################
-- PARTE B : DATOS DE NEGOCIO (ejecutar en CONN_NEGOCIO)
-- #####################################################################

-- ---- TIPOS DE PRESTAMO (con sus tasas) ----
INSERT INTO t_tipo_prestamo (id_tipo_prestamo, nombre, tasa_interes_mensual, monto_minimo, monto_maximo, plazo_minimo_meses, plazo_maximo_meses, estado, fecha_registro)
  VALUES (seq_tipo_prestamo.NEXTVAL, 'Prestamo Personal', 0.0250, 1000, 30000, 6, 36, 'ACTIVO', SYSDATE);
INSERT INTO t_tipo_prestamo (id_tipo_prestamo, nombre, tasa_interes_mensual, monto_minimo, monto_maximo, plazo_minimo_meses, plazo_maximo_meses, estado, fecha_registro)
  VALUES (seq_tipo_prestamo.NEXTVAL, 'Prestamo Emprendedor', 0.0300, 5000, 50000, 12, 48, 'ACTIVO', SYSDATE);
INSERT INTO t_tipo_prestamo (id_tipo_prestamo, nombre, tasa_interes_mensual, monto_minimo, monto_maximo, plazo_minimo_meses, plazo_maximo_meses, estado, fecha_registro)
  VALUES (seq_tipo_prestamo.NEXTVAL, 'Prestamo Express', 0.0400, 500, 5000, 3, 12, 'ACTIVO', SYSDATE);

-- ---- PARAMETROS DEL SISTEMA (configurables) ----
INSERT INTO t_parametro (id_parametro, codigo, descripcion, valor, tipo_dato, fecha_modificacion, id_usuario_modificacion)
  VALUES (seq_parametro.NEXTVAL, 'PORC_CAPACIDAD', 'Porcentaje del ingreso destinado a capacidad de pago', '40', 'NUMERO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='admin'));
INSERT INTO t_parametro (id_parametro, codigo, descripcion, valor, tipo_dato, fecha_modificacion, id_usuario_modificacion)
  VALUES (seq_parametro.NEXTVAL, 'DIAS_MOROSIDAD', 'Dias de atraso para marcar cuota como morosa', '5', 'NUMERO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='admin'));
INSERT INTO t_parametro (id_parametro, codigo, descripcion, valor, tipo_dato, fecha_modificacion, id_usuario_modificacion)
  VALUES (seq_parametro.NEXTVAL, 'RATIO_A', 'Ratio maximo cuota/ingreso para calificacion A', '0.30', 'NUMERO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='admin'));
INSERT INTO t_parametro (id_parametro, codigo, descripcion, valor, tipo_dato, fecha_modificacion, id_usuario_modificacion)
  VALUES (seq_parametro.NEXTVAL, 'RATIO_B', 'Ratio maximo cuota/ingreso para calificacion B', '0.40', 'NUMERO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='admin'));
INSERT INTO t_parametro (id_parametro, codigo, descripcion, valor, tipo_dato, fecha_modificacion, id_usuario_modificacion)
  VALUES (seq_parametro.NEXTVAL, 'RATIO_C', 'Ratio maximo cuota/ingreso para calificacion C', '0.50', 'NUMERO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='admin'));

-- ---- CLIENTES ----
INSERT INTO t_cliente (id_cliente, dni, nombres, apellidos, fecha_nacimiento, telefono, email, direccion, ingreso_mensual, estado, fecha_registro, id_usuario_registro)
  VALUES (seq_cliente.NEXTVAL, '40123456', 'Juan Alberto', 'Ramirez Soto', DATE '1990-05-15', '987654321', 'juan.ramirez@email.com', 'Av. Los Olivos 123, Lima', 3500, 'ACTIVO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='ana'));
INSERT INTO t_cliente (id_cliente, dni, nombres, apellidos, fecha_nacimiento, telefono, email, direccion, ingreso_mensual, estado, fecha_registro, id_usuario_registro)
  VALUES (seq_cliente.NEXTVAL, '41234567', 'Maria Elena', 'Torres Vega', DATE '1985-08-22', '987654322', 'maria.torres@email.com', 'Jr. Las Flores 456, Lima', 5000, 'ACTIVO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='ana'));
INSERT INTO t_cliente (id_cliente, dni, nombres, apellidos, fecha_nacimiento, telefono, email, direccion, ingreso_mensual, estado, fecha_registro, id_usuario_registro)
  VALUES (seq_cliente.NEXTVAL, '42345678', 'Carlos Enrique', 'Mendoza Rios', DATE '1992-11-30', '987654323', 'carlos.mendoza@email.com', 'Calle Union 789, Lima', 2800, 'ACTIVO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='ana'));
INSERT INTO t_cliente (id_cliente, dni, nombres, apellidos, fecha_nacimiento, telefono, email, direccion, ingreso_mensual, estado, fecha_registro, id_usuario_registro)
  VALUES (seq_cliente.NEXTVAL, '43456789', 'Ana Lucia', 'Flores Quispe', DATE '1988-03-10', '987654324', 'ana.flores@email.com', 'Av. Grau 321, Lima', 4200, 'ACTIVO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='ana'));
INSERT INTO t_cliente (id_cliente, dni, nombres, apellidos, fecha_nacimiento, telefono, email, direccion, ingreso_mensual, estado, fecha_registro, id_usuario_registro)
  VALUES (seq_cliente.NEXTVAL, '44567890', 'Roberto Jose', 'Castro Luna', DATE '1995-07-18', '987654325', 'roberto.castro@email.com', 'Jr. Ancash 654, Lima', 6000, 'ACTIVO', SYSDATE,
    (SELECT id_usuario FROM c##g01_seguridad.t_usuario WHERE username='ana'));

COMMIT;
