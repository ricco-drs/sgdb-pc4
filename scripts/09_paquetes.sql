
-- ---- ESPECIFICACION ----
CREATE OR REPLACE PACKAGE pkg_seguridad AS

  ex_sin_permiso EXCEPTION;
  PRAGMA EXCEPTION_INIT(ex_sin_permiso, -20001);

  -- SEG01
  FUNCTION autenticar_usuario(
    p_username IN VARCHAR2,
    p_password IN VARCHAR2
  ) RETURN VARCHAR2;

  -- SEG02
  FUNCTION tiene_permiso(
    p_id_usuario    IN NUMBER,
    p_cod_operacion IN VARCHAR2
  ) RETURN VARCHAR2;

  PROCEDURE validar_permiso(
    p_id_usuario    IN NUMBER,
    p_cod_operacion IN VARCHAR2
  );

  -- SEG03
  PROCEDURE registrar_auditoria(
    p_id_usuario  IN NUMBER,
    p_accion      IN VARCHAR2,
    p_entidad     IN VARCHAR2,
    p_id_registro IN NUMBER,
    p_detalle     IN VARCHAR2
  );

  -- SEG04
  PROCEDURE registrar_intento_login(
    p_username IN VARCHAR2,
    p_exitoso  IN CHAR
  );

  PROCEDURE desbloquear_usuario(
    p_id_usuario IN NUMBER
  );

  -- SEG05
  FUNCTION encriptar_dato(
    p_texto IN VARCHAR2
  ) RETURN RAW;

  FUNCTION desencriptar_dato(
    p_dato IN RAW
  ) RETURN VARCHAR2;

  -- ---- NUEVO: gestión de usuarios (soporte para ADM03) ----
  PROCEDURE crear_usuario(
    p_username    IN VARCHAR2,
    p_password    IN VARCHAR2,
    p_id_rol      IN NUMBER,
    p_nombre      IN VARCHAR2,
    p_email       IN VARCHAR2,
    p_id_admin    IN NUMBER,
    p_id_usuario  OUT NUMBER
  );

  PROCEDURE actualizar_usuario(
    p_id_usuario IN NUMBER,
    p_nombre     IN VARCHAR2,
    p_email      IN VARCHAR2,
    p_estado     IN VARCHAR2,
    p_id_admin   IN NUMBER
  );

END pkg_seguridad;
/

-- ---- CUERPO ----
CREATE OR REPLACE PACKAGE BODY pkg_seguridad AS

  c_clave_cripto CONSTANT RAW(32) := UTL_RAW.CAST_TO_RAW('PrestaFacil2024ClaveSegura32byte');

  FUNCTION calcular_hash(p_texto IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN RAWTOHEX(
      DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW(p_texto), DBMS_CRYPTO.HASH_SH256));
  END calcular_hash;

  PROCEDURE registrar_auditoria(
    p_id_usuario  IN NUMBER,
    p_accion      IN VARCHAR2,
    p_entidad     IN VARCHAR2,
    p_id_registro IN NUMBER,
    p_detalle     IN VARCHAR2
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO t_auditoria (id_auditoria, id_usuario, accion, entidad, id_registro_afectado, detalle, fecha_hora)
    VALUES (seq_auditoria.NEXTVAL, p_id_usuario, p_accion, p_entidad, p_id_registro, p_detalle, SYSTIMESTAMP);
    COMMIT;
  END registrar_auditoria;

  PROCEDURE registrar_intento_login(
    p_username IN VARCHAR2,
    p_exitoso  IN CHAR
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_id_usuario t_usuario.id_usuario%TYPE;
    v_intentos   NUMBER;
  BEGIN
    BEGIN
      SELECT id_usuario INTO v_id_usuario
        FROM t_usuario WHERE username = p_username;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN v_id_usuario := NULL;
    END;

    INSERT INTO t_intento_login (id_intento, id_usuario, username, exitoso, fecha_hora)
    VALUES (seq_intento_login.NEXTVAL, v_id_usuario, p_username, p_exitoso, SYSTIMESTAMP);

    IF p_exitoso = 'N' AND v_id_usuario IS NOT NULL THEN
      UPDATE t_usuario SET intentos_fallidos = intentos_fallidos + 1
       WHERE id_usuario = v_id_usuario
      RETURNING intentos_fallidos INTO v_intentos;
      IF v_intentos >= 3 THEN
        UPDATE t_usuario SET estado = 'BLOQUEADO' WHERE id_usuario = v_id_usuario;
      END IF;
    END IF;
    COMMIT;
  END registrar_intento_login;

  FUNCTION autenticar_usuario(
    p_username IN VARCHAR2,
    p_password IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_id_usuario    t_usuario.id_usuario%TYPE;
    v_hash_guardado t_usuario.password_hash%TYPE;
    v_hash_ingresado VARCHAR2(256);
    v_estado        t_usuario.estado%TYPE;
    v_rol           VARCHAR2(30);
  BEGIN
    BEGIN
      SELECT u.id_usuario, u.password_hash, u.estado, r.nombre
        INTO v_id_usuario, v_hash_guardado, v_estado, v_rol
        FROM t_usuario u JOIN t_rol r ON r.id_rol = u.id_rol
       WHERE u.username = p_username;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        registrar_intento_login(p_username, 'N');
        RETURN 'DENEGADO';
    END;

    IF v_estado <> 'ACTIVO' THEN
      registrar_intento_login(p_username, 'N');
      RETURN 'BLOQUEADO';
    END IF;

    v_hash_ingresado := calcular_hash(p_password);

    IF v_hash_ingresado = v_hash_guardado THEN
      registrar_intento_login(p_username, 'S');
      UPDATE t_usuario SET fecha_ultimo_acceso = SYSDATE, intentos_fallidos = 0
       WHERE id_usuario = v_id_usuario;
      COMMIT;
      registrar_auditoria(v_id_usuario, 'LOGIN', 'T_USUARIO', v_id_usuario, 'Acceso exitoso');
      RETURN v_rol;
    ELSE
      registrar_intento_login(p_username, 'N');
      RETURN 'DENEGADO';
    END IF;
  END autenticar_usuario;

  FUNCTION tiene_permiso(
    p_id_usuario    IN NUMBER,
    p_cod_operacion IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_count NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_count
      FROM t_usuario u
      JOIN t_rol_permiso rp ON rp.id_rol = u.id_rol
      JOIN t_operacion o    ON o.id_operacion = rp.id_operacion
     WHERE u.id_usuario = p_id_usuario AND o.codigo = p_cod_operacion;
    IF v_count > 0 THEN RETURN 'SI'; ELSE RETURN 'NO'; END IF;
  END tiene_permiso;

  PROCEDURE validar_permiso(
    p_id_usuario    IN NUMBER,
    p_cod_operacion IN VARCHAR2
  ) IS
  BEGIN
    IF tiene_permiso(p_id_usuario, p_cod_operacion) = 'NO' THEN
      registrar_auditoria(p_id_usuario, 'ACCESO_DENEGADO', 'T_OPERACION', NULL,
        'Intento de ejecutar ' || p_cod_operacion || ' sin permiso');
      RAISE_APPLICATION_ERROR(-20001,
        'Usuario sin permiso para la operacion: ' || p_cod_operacion);
    END IF;
  END validar_permiso;

  PROCEDURE desbloquear_usuario(
    p_id_usuario IN NUMBER
  ) IS
  BEGIN
    UPDATE t_usuario SET estado = 'ACTIVO', intentos_fallidos = 0
     WHERE id_usuario = p_id_usuario;
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'Usuario no encontrado: ' || p_id_usuario);
    END IF;
    registrar_auditoria(p_id_usuario, 'DESBLOQUEO', 'T_USUARIO', p_id_usuario, 'Usuario desbloqueado');
    COMMIT;
  END desbloquear_usuario;

  FUNCTION encriptar_dato(
    p_texto IN VARCHAR2
  ) RETURN RAW IS
    v_encriptado RAW(2000);
  BEGIN
    v_encriptado := DBMS_CRYPTO.ENCRYPT(
      src => UTL_RAW.CAST_TO_RAW(p_texto),
      typ => DBMS_CRYPTO.ENCRYPT_AES256 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_PKCS5,
      key => c_clave_cripto);
    RETURN v_encriptado;
  END encriptar_dato;

  FUNCTION desencriptar_dato(
    p_dato IN RAW
  ) RETURN VARCHAR2 IS
    v_desencriptado RAW(2000);
  BEGIN
    v_desencriptado := DBMS_CRYPTO.DECRYPT(
      src => p_dato,
      typ => DBMS_CRYPTO.ENCRYPT_AES256 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_PKCS5,
      key => c_clave_cripto);
    RETURN UTL_RAW.CAST_TO_VARCHAR2(v_desencriptado);
  END desencriptar_dato;

  -- ===================================================================
  -- Crear usuario (CORREGIDO: hash en variable, no en el INSERT)
  -- ===================================================================
  PROCEDURE crear_usuario(
    p_username    IN VARCHAR2,
    p_password    IN VARCHAR2,
    p_id_rol      IN NUMBER,
    p_nombre      IN VARCHAR2,
    p_email       IN VARCHAR2,
    p_id_admin    IN NUMBER,
    p_id_usuario  OUT NUMBER
  ) IS
    v_existe NUMBER;
    v_rol_ok NUMBER;
    v_hash   VARCHAR2(256);
  BEGIN
    validar_permiso(p_id_admin, 'GESTIONAR_USUARIOS');

    SELECT COUNT(*) INTO v_existe FROM t_usuario WHERE username = p_username;
    IF v_existe > 0 THEN
      RAISE_APPLICATION_ERROR(-20003, 'El username ya existe: ' || p_username);
    END IF;

    SELECT COUNT(*) INTO v_rol_ok FROM t_rol WHERE id_rol = p_id_rol AND estado = 'ACTIVO';
    IF v_rol_ok = 0 THEN
      RAISE_APPLICATION_ERROR(-20004, 'El rol no existe o esta inactivo.');
    END IF;

    -- Calcular el hash ANTES del INSERT (en variable)
    v_hash := calcular_hash(p_password);

    p_id_usuario := seq_usuario.NEXTVAL;
    INSERT INTO t_usuario (id_usuario, username, password_hash, id_rol, nombre_completo, email, estado, intentos_fallidos, fecha_creacion)
    VALUES (p_id_usuario, p_username, v_hash, p_id_rol, p_nombre, p_email, 'ACTIVO', 0, SYSDATE);

    registrar_auditoria(p_id_admin, 'CREAR_USUARIO', 'T_USUARIO', p_id_usuario,
      'Usuario creado: ' || p_username);
    COMMIT;
  END crear_usuario;

  PROCEDURE actualizar_usuario(
    p_id_usuario IN NUMBER,
    p_nombre     IN VARCHAR2,
    p_email      IN VARCHAR2,
    p_estado     IN VARCHAR2,
    p_id_admin   IN NUMBER
  ) IS
  BEGIN
    validar_permiso(p_id_admin, 'GESTIONAR_USUARIOS');

    IF p_estado NOT IN ('ACTIVO','BLOQUEADO','INACTIVO') THEN
      RAISE_APPLICATION_ERROR(-20005, 'Estado invalido.');
    END IF;

    UPDATE t_usuario
       SET nombre_completo = p_nombre, email = p_email, estado = p_estado
     WHERE id_usuario = p_id_usuario;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20006, 'Usuario no encontrado: ' || p_id_usuario);
    END IF;

    registrar_auditoria(p_id_admin, 'ACTUALIZAR_USUARIO', 'T_USUARIO', p_id_usuario,
      'Usuario actualizado');
    COMMIT;
  END actualizar_usuario;

END pkg_seguridad;
/


-- #####################################################################
-- PARTE B : PAQUETES DE NEGOCIO  (ejecutar en CONN_NEGOCIO)
-- #####################################################################

-- =====================================================================
-- PKG_VALOR (VAL01-VAL05) - Ciclo del prestamo, metodo frances
-- =====================================================================

-- ---- ESPECIFICACION ----
CREATE OR REPLACE PACKAGE pkg_valor AS

  -- VAL01: Registrar una nueva solicitud de préstamo
  PROCEDURE registrar_solicitud(
    p_id_cliente       IN NUMBER,
    p_id_tipo_prestamo IN NUMBER,
    p_monto            IN NUMBER,
    p_plazo_meses      IN NUMBER,
    p_id_analista      IN NUMBER,
    p_id_solicitud     OUT NUMBER
  );

  -- VAL02: Evaluar capacidad de pago y asignar calificación (A/B/C/D)
  PROCEDURE evaluar_solicitud(
    p_id_solicitud IN NUMBER,
    p_calificacion OUT CHAR
  );

  -- VAL03: Aprobar o rechazar una solicitud
  PROCEDURE decidir_solicitud(
    p_id_solicitud IN NUMBER,
    p_decision     IN VARCHAR2,   -- 'APROBAR' o 'RECHAZAR'
    p_id_analista  IN NUMBER
  );

  -- VAL04: Generar cronograma de cuotas (método francés)
  PROCEDURE generar_cronograma(
    p_id_prestamo IN NUMBER
  );

  -- VAL05: Registrar el pago de una cuota
  PROCEDURE registrar_pago(
    p_id_cuota    IN NUMBER,
    p_monto       IN NUMBER,
    p_medio_pago  IN VARCHAR2,
    p_id_cajero   IN NUMBER
  );

  -- Función auxiliar: calcular cuota mensual (método francés)
  FUNCTION calcular_cuota_francesa(
    p_monto IN NUMBER,
    p_tasa  IN NUMBER,
    p_plazo IN NUMBER
  ) RETURN NUMBER;

END pkg_valor;
/

-- ---- CUERPO ----
CREATE OR REPLACE PACKAGE BODY pkg_valor AS

  PROCEDURE auditar(p_id_usuario NUMBER, p_accion VARCHAR2, p_entidad VARCHAR2,
                    p_id_reg NUMBER, p_detalle VARCHAR2) IS
  BEGIN
    c##g01_seguridad.pkg_seguridad.registrar_auditoria(
      p_id_usuario, p_accion, p_entidad, p_id_reg, p_detalle);
  END auditar;

  -- Lee un parámetro del sistema como número (punto decimal explícito)
  FUNCTION param_num(p_codigo VARCHAR2) RETURN NUMBER IS
    v_valor t_parametro.valor%TYPE;
  BEGIN
    SELECT valor INTO v_valor FROM t_parametro WHERE codigo = p_codigo;
    -- Interpretar SIEMPRE el punto como separador decimal
    RETURN TO_NUMBER(v_valor, '9999999990.99999999',
                     'NLS_NUMERIC_CHARACTERS=''.,''');
  END param_num;

  FUNCTION calcular_cuota_francesa(
    p_monto IN NUMBER,
    p_tasa  IN NUMBER,
    p_plazo IN NUMBER
  ) RETURN NUMBER IS
    v_factor NUMBER;
    v_cuota  NUMBER;
  BEGIN
    IF p_tasa = 0 THEN
      RETURN ROUND(p_monto / p_plazo, 2);
    END IF;
    v_factor := POWER(1 + p_tasa, p_plazo);
    v_cuota  := p_monto * (p_tasa * v_factor) / (v_factor - 1);
    RETURN ROUND(v_cuota, 2);
  END calcular_cuota_francesa;

  PROCEDURE registrar_solicitud(
    p_id_cliente       IN NUMBER,
    p_id_tipo_prestamo IN NUMBER,
    p_monto            IN NUMBER,
    p_plazo_meses      IN NUMBER,
    p_id_analista      IN NUMBER,
    p_id_solicitud     OUT NUMBER
  ) IS
    v_monto_min   t_tipo_prestamo.monto_minimo%TYPE;
    v_monto_max   t_tipo_prestamo.monto_maximo%TYPE;
    v_plazo_min   t_tipo_prestamo.plazo_minimo_meses%TYPE;
    v_plazo_max   t_tipo_prestamo.plazo_maximo_meses%TYPE;
    v_ingreso     t_cliente.ingreso_mensual%TYPE;
    v_estado_cli  t_cliente.estado%TYPE;
    v_en_lista    NUMBER;
  BEGIN
    BEGIN
      SELECT ingreso_mensual, estado INTO v_ingreso, v_estado_cli
        FROM t_cliente WHERE id_cliente = p_id_cliente;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20101, 'El cliente no existe.');
    END;

    IF v_estado_cli <> 'ACTIVO' THEN
      RAISE_APPLICATION_ERROR(-20102, 'El cliente no esta activo.');
    END IF;

    SELECT COUNT(*) INTO v_en_lista
      FROM t_lista_negra
     WHERE id_cliente = p_id_cliente AND estado = 'ACTIVO';
    IF v_en_lista > 0 THEN
      RAISE_APPLICATION_ERROR(-20103, 'El cliente esta en lista negra.');
    END IF;

    BEGIN
      SELECT monto_minimo, monto_maximo, plazo_minimo_meses, plazo_maximo_meses
        INTO v_monto_min, v_monto_max, v_plazo_min, v_plazo_max
        FROM t_tipo_prestamo WHERE id_tipo_prestamo = p_id_tipo_prestamo;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20104, 'El tipo de prestamo no existe.');
    END;

    IF p_monto < v_monto_min OR p_monto > v_monto_max THEN
      RAISE_APPLICATION_ERROR(-20105, 'El monto esta fuera del rango permitido.');
    END IF;
    IF p_plazo_meses < v_plazo_min OR p_plazo_meses > v_plazo_max THEN
      RAISE_APPLICATION_ERROR(-20106, 'El plazo esta fuera del rango permitido.');
    END IF;

    p_id_solicitud := seq_solicitud.NEXTVAL;
    INSERT INTO t_solicitud (id_solicitud, id_cliente, id_tipo_prestamo, monto_solicitado,
      plazo_meses, ingreso_declarado, estado, fecha_solicitud, id_analista)
    VALUES (p_id_solicitud, p_id_cliente, p_id_tipo_prestamo, p_monto,
      p_plazo_meses, v_ingreso, 'PENDIENTE', SYSDATE, p_id_analista);

    auditar(p_id_analista, 'REGISTRAR', 'T_SOLICITUD', p_id_solicitud,
      'Solicitud registrada por monto ' || p_monto);
    COMMIT;
  END registrar_solicitud;

  PROCEDURE evaluar_solicitud(
    p_id_solicitud IN NUMBER,
    p_calificacion OUT CHAR
  ) IS
    v_monto     t_solicitud.monto_solicitado%TYPE;
    v_plazo     t_solicitud.plazo_meses%TYPE;
    v_ingreso   t_solicitud.ingreso_declarado%TYPE;
    v_tasa      t_tipo_prestamo.tasa_interes_mensual%TYPE;
    v_capacidad NUMBER;
    v_cuota     NUMBER;
    v_ratio     NUMBER;
    v_porc_cap  NUMBER;
  BEGIN
    BEGIN
      SELECT s.monto_solicitado, s.plazo_meses, s.ingreso_declarado, tp.tasa_interes_mensual
        INTO v_monto, v_plazo, v_ingreso, v_tasa
        FROM t_solicitud s
        JOIN t_tipo_prestamo tp ON tp.id_tipo_prestamo = s.id_tipo_prestamo
       WHERE s.id_solicitud = p_id_solicitud;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20107, 'La solicitud no existe.');
    END;

    v_porc_cap  := param_num('PORC_CAPACIDAD') / 100;
    v_capacidad := v_ingreso * v_porc_cap;
    v_cuota := calcular_cuota_francesa(v_monto, v_tasa, v_plazo);
    v_ratio := v_cuota / v_ingreso;

    IF v_ratio <= param_num('RATIO_A') THEN
      p_calificacion := 'A';
    ELSIF v_ratio <= param_num('RATIO_B') THEN
      p_calificacion := 'B';
    ELSIF v_ratio <= param_num('RATIO_C') THEN
      p_calificacion := 'C';
    ELSE
      p_calificacion := 'D';
    END IF;

    UPDATE t_solicitud
       SET capacidad_pago = v_capacidad,
           cuota_estimada = v_cuota,
           ratio_cuota_ingreso = v_ratio,
           calificacion = p_calificacion
     WHERE id_solicitud = p_id_solicitud;

    COMMIT;
  END evaluar_solicitud;

  PROCEDURE decidir_solicitud(
    p_id_solicitud IN NUMBER,
    p_decision     IN VARCHAR2,
    p_id_analista  IN NUMBER
  ) IS
    v_calificacion t_solicitud.calificacion%TYPE;
    v_estado       t_solicitud.estado%TYPE;
    v_monto        t_solicitud.monto_solicitado%TYPE;
    v_plazo        t_solicitud.plazo_meses%TYPE;
    v_id_tipo      t_solicitud.id_tipo_prestamo%TYPE;
    v_tasa         t_tipo_prestamo.tasa_interes_mensual%TYPE;
    v_cuota        NUMBER;
    v_id_prestamo  NUMBER;
  BEGIN
    c##g01_seguridad.pkg_seguridad.validar_permiso(p_id_analista, 'APROBAR_PRESTAMO');

    BEGIN
      SELECT calificacion, estado, monto_solicitado, plazo_meses, id_tipo_prestamo
        INTO v_calificacion, v_estado, v_monto, v_plazo, v_id_tipo
        FROM t_solicitud WHERE id_solicitud = p_id_solicitud;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20108, 'La solicitud no existe.');
    END;

    IF v_estado NOT IN ('PENDIENTE','EN_REVISION') THEN
      RAISE_APPLICATION_ERROR(-20109, 'La solicitud ya fue decidida.');
    END IF;

    IF v_calificacion IS NULL THEN
      RAISE_APPLICATION_ERROR(-20110, 'La solicitud debe evaluarse antes de decidir.');
    END IF;

    IF v_calificacion = 'D' AND UPPER(p_decision) = 'APROBAR' THEN
      RAISE_APPLICATION_ERROR(-20111, 'No se puede aprobar una solicitud con calificacion D.');
    END IF;

    IF UPPER(p_decision) = 'RECHAZAR' THEN
      UPDATE t_solicitud
         SET estado = 'RECHAZADO', fecha_decision = SYSDATE, id_analista_decision = p_id_analista
       WHERE id_solicitud = p_id_solicitud;
      auditar(p_id_analista, 'RECHAZAR', 'T_SOLICITUD', p_id_solicitud, 'Solicitud rechazada');

    ELSIF UPPER(p_decision) = 'APROBAR' THEN
      UPDATE t_solicitud
         SET estado = 'APROBADO', fecha_decision = SYSDATE, id_analista_decision = p_id_analista
       WHERE id_solicitud = p_id_solicitud;

      SELECT tasa_interes_mensual INTO v_tasa
        FROM t_tipo_prestamo WHERE id_tipo_prestamo = v_id_tipo;

      v_cuota := calcular_cuota_francesa(v_monto, v_tasa, v_plazo);
      v_id_prestamo := seq_prestamo.NEXTVAL;

      INSERT INTO t_prestamo (id_prestamo, id_solicitud, monto_aprobado, plazo_meses,
        tasa_interes_mensual, cuota_mensual, saldo_pendiente, fecha_desembolso,
        fecha_primera_cuota, estado, id_analista_aprobador, fecha_aprobacion)
      VALUES (v_id_prestamo, p_id_solicitud, v_monto, v_plazo,
        v_tasa, v_cuota, v_monto, SYSDATE,
        ADD_MONTHS(SYSDATE, 1), 'VIGENTE', p_id_analista, SYSDATE);

      auditar(p_id_analista, 'APROBAR', 'T_PRESTAMO', v_id_prestamo,
        'Prestamo aprobado por monto ' || v_monto);

      generar_cronograma(v_id_prestamo);
    ELSE
      RAISE_APPLICATION_ERROR(-20112, 'Decision invalida. Use APROBAR o RECHAZAR.');
    END IF;

    COMMIT;
  END decidir_solicitud;

  PROCEDURE generar_cronograma(
    p_id_prestamo IN NUMBER
  ) IS
    v_monto      t_prestamo.monto_aprobado%TYPE;
    v_plazo      t_prestamo.plazo_meses%TYPE;
    v_tasa       t_prestamo.tasa_interes_mensual%TYPE;
    v_cuota      t_prestamo.cuota_mensual%TYPE;
    v_fecha_ini  t_prestamo.fecha_primera_cuota%TYPE;
    v_saldo      NUMBER;
    v_interes    NUMBER;
    v_capital    NUMBER;
  BEGIN
    SELECT monto_aprobado, plazo_meses, tasa_interes_mensual, cuota_mensual, fecha_primera_cuota
      INTO v_monto, v_plazo, v_tasa, v_cuota, v_fecha_ini
      FROM t_prestamo WHERE id_prestamo = p_id_prestamo;

    v_saldo := v_monto;

    FOR i IN 1 .. v_plazo LOOP
      v_interes := ROUND(v_saldo * v_tasa, 2);
      v_capital := ROUND(v_cuota - v_interes, 2);

      IF i = v_plazo THEN
        v_capital := v_saldo;
        v_cuota   := v_capital + v_interes;
      END IF;

      v_saldo := ROUND(v_saldo - v_capital, 2);

      INSERT INTO t_cuota (id_cuota, id_prestamo, numero_cuota, fecha_vencimiento,
        monto_capital, monto_interes, monto_cuota, saldo_capital, monto_pagado, estado)
      VALUES (seq_cuota.NEXTVAL, p_id_prestamo, i, ADD_MONTHS(v_fecha_ini, i-1),
        v_capital, v_interes, v_capital + v_interes, v_saldo, 0, 'PENDIENTE');
    END LOOP;

    COMMIT;
  END generar_cronograma;

  PROCEDURE registrar_pago(
    p_id_cuota    IN NUMBER,
    p_monto       IN NUMBER,
    p_medio_pago  IN VARCHAR2,
    p_id_cajero   IN NUMBER
  ) IS
    v_monto_cuota  t_cuota.monto_cuota%TYPE;
    v_pagado       t_cuota.monto_pagado%TYPE;
    v_estado       t_cuota.estado%TYPE;
    v_id_prestamo  t_cuota.id_prestamo%TYPE;
    v_nuevo_pagado NUMBER;
    v_cuotas_pend  NUMBER;
  BEGIN
    c##g01_seguridad.pkg_seguridad.validar_permiso(p_id_cajero, 'REGISTRAR_PAGO');

    BEGIN
      SELECT monto_cuota, monto_pagado, estado, id_prestamo
        INTO v_monto_cuota, v_pagado, v_estado, v_id_prestamo
        FROM t_cuota WHERE id_cuota = p_id_cuota;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20113, 'La cuota no existe.');
    END;

    IF v_estado = 'PAGADA' THEN
      RAISE_APPLICATION_ERROR(-20114, 'La cuota ya esta pagada.');
    END IF;

    IF p_monto <= 0 THEN
      RAISE_APPLICATION_ERROR(-20115, 'El monto del pago debe ser positivo.');
    END IF;

    INSERT INTO t_pago (id_pago, id_cuota, monto_pagado, fecha_pago, medio_pago, id_cajero)
    VALUES (seq_pago.NEXTVAL, p_id_cuota, p_monto, SYSDATE, p_medio_pago, p_id_cajero);

    v_nuevo_pagado := v_pagado + p_monto;

    IF v_nuevo_pagado >= v_monto_cuota THEN
      UPDATE t_cuota
         SET monto_pagado = v_nuevo_pagado, estado = 'PAGADA', fecha_pago = SYSDATE
       WHERE id_cuota = p_id_cuota;
    ELSE
      UPDATE t_cuota
         SET monto_pagado = v_nuevo_pagado, estado = 'PARCIAL'
       WHERE id_cuota = p_id_cuota;
    END IF;

    UPDATE t_prestamo
       SET saldo_pendiente = saldo_pendiente - p_monto
     WHERE id_prestamo = v_id_prestamo;

    SELECT COUNT(*) INTO v_cuotas_pend
      FROM t_cuota
     WHERE id_prestamo = v_id_prestamo AND estado <> 'PAGADA';

    IF v_cuotas_pend = 0 THEN
      UPDATE t_prestamo SET estado = 'CANCELADO', saldo_pendiente = 0
       WHERE id_prestamo = v_id_prestamo;
    END IF;

    auditar(p_id_cajero, 'PAGAR', 'T_CUOTA', p_id_cuota,
      'Pago registrado por ' || p_monto || ' via ' || p_medio_pago);
    COMMIT;
  END registrar_pago;

END pkg_valor;
/

-- =====================================================================
-- PKG_ADMINISTRACION (ADM01-ADM05) - Mantenimientos y catalogos
-- =====================================================================

-- ---- ESPECIFICACION ----
CREATE OR REPLACE PACKAGE pkg_administracion AS

  -- ADM01: Registrar/actualizar cliente
  PROCEDURE registrar_cliente(
    p_dni             IN VARCHAR2,
    p_nombres         IN VARCHAR2,
    p_apellidos       IN VARCHAR2,
    p_fecha_nac       IN DATE,
    p_telefono        IN VARCHAR2,
    p_email           IN VARCHAR2,
    p_direccion       IN VARCHAR2,
    p_ingreso         IN NUMBER,
    p_id_usuario_reg  IN NUMBER,
    p_id_cliente      OUT NUMBER
  );

  PROCEDURE actualizar_cliente(
    p_id_cliente IN NUMBER,
    p_telefono   IN VARCHAR2,
    p_email      IN VARCHAR2,
    p_direccion  IN VARCHAR2,
    p_ingreso    IN NUMBER,
    p_estado     IN VARCHAR2
  );

  -- ADM02: Gestionar tipos de prestamo y tasas
  PROCEDURE registrar_tipo_prestamo(
    p_nombre      IN VARCHAR2,
    p_tasa        IN NUMBER,
    p_monto_min   IN NUMBER,
    p_monto_max   IN NUMBER,
    p_plazo_min   IN NUMBER,
    p_plazo_max   IN NUMBER,
    p_id_tipo     OUT NUMBER
  );

  PROCEDURE actualizar_tasa(
    p_id_tipo   IN NUMBER,
    p_nueva_tasa IN NUMBER
  );

  -- ADM03: Gestionar usuarios (llama a PKG_SEGURIDAD)
  PROCEDURE gestionar_usuario(
    p_username   IN VARCHAR2,
    p_password   IN VARCHAR2,
    p_nombre_rol IN VARCHAR2,
    p_nombre     IN VARCHAR2,
    p_email      IN VARCHAR2,
    p_id_admin   IN NUMBER,
    p_id_usuario OUT NUMBER
  );

  -- ADM04: Gestionar parametros del sistema
  PROCEDURE actualizar_parametro(
    p_codigo     IN VARCHAR2,
    p_nuevo_valor IN VARCHAR2,
    p_id_admin   IN NUMBER
  );

  -- ADM05: Gestionar lista negra
  PROCEDURE agregar_lista_negra(
    p_id_cliente     IN NUMBER,
    p_motivo         IN VARCHAR2,
    p_id_usuario_reg IN NUMBER,
    p_id_lista       OUT NUMBER
  );

  PROCEDURE quitar_lista_negra(
    p_id_cliente IN NUMBER
  );

END pkg_administracion;
/

-- ---- CUERPO ----
CREATE OR REPLACE PACKAGE BODY pkg_administracion AS

  PROCEDURE auditar(p_id_usuario NUMBER, p_accion VARCHAR2, p_entidad VARCHAR2,
                    p_id_reg NUMBER, p_detalle VARCHAR2) IS
  BEGIN
    c##g01_seguridad.pkg_seguridad.registrar_auditoria(
      p_id_usuario, p_accion, p_entidad, p_id_reg, p_detalle);
  END auditar;

  -- ADM01: Registrar cliente
  PROCEDURE registrar_cliente(
    p_dni             IN VARCHAR2,
    p_nombres         IN VARCHAR2,
    p_apellidos       IN VARCHAR2,
    p_fecha_nac       IN DATE,
    p_telefono        IN VARCHAR2,
    p_email           IN VARCHAR2,
    p_direccion       IN VARCHAR2,
    p_ingreso         IN NUMBER,
    p_id_usuario_reg  IN NUMBER,
    p_id_cliente      OUT NUMBER
  ) IS
    v_existe  NUMBER;
    v_edad    NUMBER;
  BEGIN
    IF LENGTH(p_dni) <> 8 OR NOT REGEXP_LIKE(p_dni, '^[0-9]{8}$') THEN
      RAISE_APPLICATION_ERROR(-20201, 'El DNI debe tener 8 digitos numericos.');
    END IF;

    SELECT COUNT(*) INTO v_existe FROM t_cliente WHERE dni = p_dni;
    IF v_existe > 0 THEN
      RAISE_APPLICATION_ERROR(-20202, 'Ya existe un cliente con ese DNI.');
    END IF;

    v_edad := TRUNC(MONTHS_BETWEEN(SYSDATE, p_fecha_nac) / 12);
    IF v_edad < 18 THEN
      RAISE_APPLICATION_ERROR(-20203, 'El cliente debe ser mayor de edad.');
    END IF;

    IF p_ingreso <= 0 THEN
      RAISE_APPLICATION_ERROR(-20204, 'El ingreso debe ser positivo.');
    END IF;

    p_id_cliente := seq_cliente.NEXTVAL;
    INSERT INTO t_cliente (id_cliente, dni, nombres, apellidos, fecha_nacimiento,
      telefono, email, direccion, ingreso_mensual, estado, fecha_registro, id_usuario_registro)
    VALUES (p_id_cliente, p_dni, p_nombres, p_apellidos, p_fecha_nac,
      p_telefono, p_email, p_direccion, p_ingreso, 'ACTIVO', SYSDATE, p_id_usuario_reg);

    auditar(p_id_usuario_reg, 'REGISTRAR', 'T_CLIENTE', p_id_cliente,
      'Cliente registrado: ' || p_nombres || ' ' || p_apellidos);
    COMMIT;
  END registrar_cliente;

  -- ADM01 (variante): Actualizar cliente
  PROCEDURE actualizar_cliente(
    p_id_cliente IN NUMBER,
    p_telefono   IN VARCHAR2,
    p_email      IN VARCHAR2,
    p_direccion  IN VARCHAR2,
    p_ingreso    IN NUMBER,
    p_estado     IN VARCHAR2
  ) IS
  BEGIN
    IF p_ingreso <= 0 THEN
      RAISE_APPLICATION_ERROR(-20204, 'El ingreso debe ser positivo.');
    END IF;
    IF p_estado NOT IN ('ACTIVO','INACTIVO') THEN
      RAISE_APPLICATION_ERROR(-20205, 'Estado invalido.');
    END IF;

    UPDATE t_cliente
       SET telefono = p_telefono, email = p_email, direccion = p_direccion,
           ingreso_mensual = p_ingreso, estado = p_estado
     WHERE id_cliente = p_id_cliente;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20206, 'Cliente no encontrado.');
    END IF;
    COMMIT;
  END actualizar_cliente;

  -- ADM02: Registrar tipo de prestamo
  PROCEDURE registrar_tipo_prestamo(
    p_nombre      IN VARCHAR2,
    p_tasa        IN NUMBER,
    p_monto_min   IN NUMBER,
    p_monto_max   IN NUMBER,
    p_plazo_min   IN NUMBER,
    p_plazo_max   IN NUMBER,
    p_id_tipo     OUT NUMBER
  ) IS
  BEGIN
    IF p_tasa <= 0 THEN
      RAISE_APPLICATION_ERROR(-20207, 'La tasa debe ser positiva.');
    END IF;
    IF p_monto_max <= p_monto_min THEN
      RAISE_APPLICATION_ERROR(-20208, 'El monto maximo debe ser mayor al minimo.');
    END IF;
    IF p_plazo_max < p_plazo_min THEN
      RAISE_APPLICATION_ERROR(-20209, 'El plazo maximo debe ser mayor o igual al minimo.');
    END IF;

    p_id_tipo := seq_tipo_prestamo.NEXTVAL;
    INSERT INTO t_tipo_prestamo (id_tipo_prestamo, nombre, tasa_interes_mensual,
      monto_minimo, monto_maximo, plazo_minimo_meses, plazo_maximo_meses, estado, fecha_registro)
    VALUES (p_id_tipo, p_nombre, p_tasa, p_monto_min, p_monto_max, p_plazo_min, p_plazo_max, 'ACTIVO', SYSDATE);
    COMMIT;
  END registrar_tipo_prestamo;

  -- ADM02 (variante): Actualizar tasa
  PROCEDURE actualizar_tasa(
    p_id_tipo   IN NUMBER,
    p_nueva_tasa IN NUMBER
  ) IS
  BEGIN
    IF p_nueva_tasa <= 0 THEN
      RAISE_APPLICATION_ERROR(-20207, 'La tasa debe ser positiva.');
    END IF;

    UPDATE t_tipo_prestamo SET tasa_interes_mensual = p_nueva_tasa
     WHERE id_tipo_prestamo = p_id_tipo;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20210, 'Tipo de prestamo no encontrado.');
    END IF;
    COMMIT;
  END actualizar_tasa;

  -- ADM03: Gestionar usuario (delega en PKG_SEGURIDAD)
  PROCEDURE gestionar_usuario(
    p_username   IN VARCHAR2,
    p_password   IN VARCHAR2,
    p_nombre_rol IN VARCHAR2,
    p_nombre     IN VARCHAR2,
    p_email      IN VARCHAR2,
    p_id_admin   IN NUMBER,
    p_id_usuario OUT NUMBER
  ) IS
    v_id_rol NUMBER;
  BEGIN
    BEGIN
      SELECT id_rol INTO v_id_rol
        FROM c##g01_seguridad.t_rol WHERE nombre = p_nombre_rol;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20211, 'El rol no existe: ' || p_nombre_rol);
    END;

    c##g01_seguridad.pkg_seguridad.crear_usuario(
      p_username, p_password, v_id_rol, p_nombre, p_email, p_id_admin, p_id_usuario);
  END gestionar_usuario;

  -- ADM04: Actualizar parametro del sistema
  PROCEDURE actualizar_parametro(
    p_codigo     IN VARCHAR2,
    p_nuevo_valor IN VARCHAR2,
    p_id_admin   IN NUMBER
  ) IS
  BEGIN
    UPDATE t_parametro
       SET valor = p_nuevo_valor, fecha_modificacion = SYSDATE, id_usuario_modificacion = p_id_admin
     WHERE codigo = p_codigo;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20212, 'Parametro no encontrado: ' || p_codigo);
    END IF;

    auditar(p_id_admin, 'ACTUALIZAR', 'T_PARAMETRO', NULL,
      'Parametro ' || p_codigo || ' cambiado a ' || p_nuevo_valor);
    COMMIT;
  END actualizar_parametro;

  -- ADM05: Agregar a lista negra
  PROCEDURE agregar_lista_negra(
    p_id_cliente     IN NUMBER,
    p_motivo         IN VARCHAR2,
    p_id_usuario_reg IN NUMBER,
    p_id_lista       OUT NUMBER
  ) IS
    v_existe NUMBER;
    v_ya     NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_existe FROM t_cliente WHERE id_cliente = p_id_cliente;
    IF v_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20213, 'El cliente no existe.');
    END IF;

    SELECT COUNT(*) INTO v_ya FROM t_lista_negra
     WHERE id_cliente = p_id_cliente AND estado = 'ACTIVO';
    IF v_ya > 0 THEN
      RAISE_APPLICATION_ERROR(-20214, 'El cliente ya esta en lista negra.');
    END IF;

    p_id_lista := seq_lista_negra.NEXTVAL;
    INSERT INTO t_lista_negra (id_lista_negra, id_cliente, motivo, fecha_ingreso, estado, id_usuario_registro)
    VALUES (p_id_lista, p_id_cliente, p_motivo, SYSDATE, 'ACTIVO', p_id_usuario_reg);

    auditar(p_id_usuario_reg, 'LISTA_NEGRA', 'T_LISTA_NEGRA', p_id_lista,
      'Cliente ' || p_id_cliente || ' agregado a lista negra: ' || p_motivo);
    COMMIT;
  END agregar_lista_negra;

  -- ADM05 (variante): Quitar de lista negra
  PROCEDURE quitar_lista_negra(
    p_id_cliente IN NUMBER
  ) IS
  BEGIN
    UPDATE t_lista_negra
       SET estado = 'LEVANTADO', fecha_levantamiento = SYSDATE
     WHERE id_cliente = p_id_cliente AND estado = 'ACTIVO';

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20215, 'El cliente no esta en lista negra activa.');
    END IF;
    COMMIT;
  END quitar_lista_negra;

END pkg_administracion;
/

-- =====================================================================
-- PKG_CONSULTAS (CON01-CON05) - Consultas operativas (SYS_REFCURSOR)
-- =====================================================================

-- ---- ESPECIFICACION ----
CREATE OR REPLACE PACKAGE pkg_consultas AS

  -- CON01: Consultar el cronograma completo de un prestamo
  FUNCTION consultar_cronograma(
    p_id_prestamo IN NUMBER
  ) RETURN SYS_REFCURSOR;

  -- CON02: Consultar saldo y estado de un prestamo
  FUNCTION consultar_estado_prestamo(
    p_id_prestamo IN NUMBER
  ) RETURN SYS_REFCURSOR;

  -- CON03: Consultar historial de pagos de un cliente
  FUNCTION consultar_historial_pagos(
    p_id_cliente IN NUMBER
  ) RETURN SYS_REFCURSOR;

  -- CON04: Buscar clientes por criterio (nombre, apellido o DNI)
  FUNCTION buscar_clientes(
    p_criterio IN VARCHAR2
  ) RETURN SYS_REFCURSOR;

  -- CON05: Consultar cuotas vencidas / morosas
  FUNCTION consultar_cuotas_morosas(
    p_id_cliente IN NUMBER DEFAULT NULL
  ) RETURN SYS_REFCURSOR;

END pkg_consultas;
/

-- ---- CUERPO ----
CREATE OR REPLACE PACKAGE BODY pkg_consultas AS

  -- Lee un parametro numerico (punto decimal explicito)
  FUNCTION param_num(p_codigo VARCHAR2) RETURN NUMBER IS
    v_valor t_parametro.valor%TYPE;
  BEGIN
    SELECT valor INTO v_valor FROM t_parametro WHERE codigo = p_codigo;
    RETURN TO_NUMBER(v_valor, '9999999990.99999999',
                     'NLS_NUMERIC_CHARACTERS=''.,''');
  END param_num;

  -- CON01: Cronograma de un prestamo
  FUNCTION consultar_cronograma(
    p_id_prestamo IN NUMBER
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT numero_cuota, fecha_vencimiento, monto_capital, monto_interes,
             monto_cuota, saldo_capital, monto_pagado, estado
        FROM t_cuota
       WHERE id_prestamo = p_id_prestamo
       ORDER BY numero_cuota;
    RETURN v_cursor;
  END consultar_cronograma;

  -- CON02: Estado y saldo de un prestamo
  FUNCTION consultar_estado_prestamo(
    p_id_prestamo IN NUMBER
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT p.id_prestamo,
             p.monto_aprobado,
             p.cuota_mensual,
             p.saldo_pendiente,
             p.estado,
             (SELECT COUNT(*) FROM t_cuota c
               WHERE c.id_prestamo = p.id_prestamo AND c.estado = 'PAGADA') AS cuotas_pagadas,
             (SELECT COUNT(*) FROM t_cuota c
               WHERE c.id_prestamo = p.id_prestamo) AS cuotas_totales
        FROM t_prestamo p
       WHERE p.id_prestamo = p_id_prestamo;
    RETURN v_cursor;
  END consultar_estado_prestamo;

  -- CON03: Historial de pagos de un cliente
  FUNCTION consultar_historial_pagos(
    p_id_cliente IN NUMBER
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT pg.id_pago, pg.fecha_pago, pg.monto_pagado, pg.medio_pago,
             c.numero_cuota, pr.id_prestamo
        FROM t_pago pg
        JOIN t_cuota c    ON c.id_cuota = pg.id_cuota
        JOIN t_prestamo pr ON pr.id_prestamo = c.id_prestamo
        JOIN t_solicitud s ON s.id_solicitud = pr.id_solicitud
       WHERE s.id_cliente = p_id_cliente
       ORDER BY pg.fecha_pago DESC;
    RETURN v_cursor;
  END consultar_historial_pagos;

  -- CON04: Buscar clientes por criterio
  FUNCTION buscar_clientes(
    p_criterio IN VARCHAR2
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
    v_crit   VARCHAR2(200);
  BEGIN
    v_crit := '%' || UPPER(p_criterio) || '%';
    OPEN v_cursor FOR
      SELECT id_cliente, dni, nombres, apellidos, telefono, email,
             ingreso_mensual, estado
        FROM t_cliente
       WHERE UPPER(nombres) LIKE v_crit
          OR UPPER(apellidos) LIKE v_crit
          OR dni LIKE v_crit
       ORDER BY apellidos, nombres;
    RETURN v_cursor;
  END buscar_clientes;

  -- CON05: Cuotas vencidas / morosas
  FUNCTION consultar_cuotas_morosas(
    p_id_cliente IN NUMBER DEFAULT NULL
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
    v_dias   NUMBER;
  BEGIN
    v_dias := param_num('DIAS_MOROSIDAD');

    OPEN v_cursor FOR
      SELECT cl.id_cliente, cl.nombres, cl.apellidos,
             pr.id_prestamo, c.numero_cuota, c.fecha_vencimiento,
             c.monto_cuota, c.monto_pagado,
             TRUNC(SYSDATE - c.fecha_vencimiento) AS dias_atraso, c.estado
        FROM t_cuota c
        JOIN t_prestamo pr ON pr.id_prestamo = c.id_prestamo
        JOIN t_solicitud s ON s.id_solicitud = pr.id_solicitud
        JOIN t_cliente cl  ON cl.id_cliente = s.id_cliente
       WHERE c.estado <> 'PAGADA'
         AND TRUNC(SYSDATE - c.fecha_vencimiento) > v_dias
         AND (p_id_cliente IS NULL OR cl.id_cliente = p_id_cliente)
       ORDER BY dias_atraso DESC;
    RETURN v_cursor;
  END consultar_cuotas_morosas;

END pkg_consultas;
/

-- #####################################################################
-- PARTE C : PKG_REPORTES  (ejecutar en CONN_REPORTES)
-- #####################################################################
--
-- Lee las tablas de negocio con prefijo c##g01_negocio (solo SELECT).
-- Requiere los GRANT SELECT del script 11 sobre las tablas de negocio.
-- =====================================================================

-- ---- ESPECIFICACION ----
CREATE OR REPLACE PACKAGE pkg_reportes AS

  -- REP01: Cartera total de prestamos (agrupada por estado)
  FUNCTION cartera_por_estado RETURN SYS_REFCURSOR;

  -- REP02: Indice de morosidad por mes
  FUNCTION indice_morosidad RETURN SYS_REFCURSOR;

  -- REP03: Ranking de clientes por monto prestado
  FUNCTION ranking_clientes(
    p_top IN NUMBER DEFAULT 10
  ) RETURN SYS_REFCURSOR;

  -- REP04: Recaudacion por periodo (mes)
  FUNCTION recaudacion_mensual RETURN SYS_REFCURSOR;

  -- REP05: Distribucion de prestamos por tipo y calificacion
  FUNCTION distribucion_por_tipo RETURN SYS_REFCURSOR;

  -- Registrar la ejecucion de un reporte (bitacora)
  PROCEDURE registrar_ejecucion(
    p_codigo   IN VARCHAR2,
    p_id_user  IN NUMBER,
    p_params   IN VARCHAR2,
    p_filas    IN NUMBER
  );

END pkg_reportes;
/

-- ---- CUERPO ----
CREATE OR REPLACE PACKAGE BODY pkg_reportes AS

  -- Registrar ejecucion de reporte (bitacora)
  PROCEDURE registrar_ejecucion(
    p_codigo   IN VARCHAR2,
    p_id_user  IN NUMBER,
    p_params   IN VARCHAR2,
    p_filas    IN NUMBER
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO t_log_reporte (id_log_reporte, codigo_reporte, id_usuario_ejecutor,
      parametros, fecha_ejecucion, filas_retornadas)
    VALUES (seq_log_reporte.NEXTVAL, p_codigo, p_id_user, p_params, SYSTIMESTAMP, p_filas);
    COMMIT;
  END registrar_ejecucion;

  -- REP01: Cartera total de prestamos por estado
  FUNCTION cartera_por_estado RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT estado,
             COUNT(*)              AS cantidad_prestamos,
             SUM(monto_aprobado)   AS monto_total,
             SUM(saldo_pendiente)  AS saldo_total
        FROM c##g01_negocio.t_prestamo
       GROUP BY estado
       ORDER BY monto_total DESC;
    RETURN v_cursor;
  END cartera_por_estado;

  -- REP02: Indice de morosidad por mes
  FUNCTION indice_morosidad RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT TO_CHAR(c.fecha_vencimiento, 'YYYY-MM') AS periodo,
             COUNT(*)                                 AS total_cuotas,
             SUM(CASE WHEN c.estado <> 'PAGADA'
                       AND c.fecha_vencimiento < SYSDATE
                      THEN 1 ELSE 0 END)              AS cuotas_morosas,
             ROUND(
               SUM(CASE WHEN c.estado <> 'PAGADA'
                         AND c.fecha_vencimiento < SYSDATE
                        THEN 1 ELSE 0 END) * 100 / COUNT(*), 2
             )                                        AS porcentaje_morosidad
        FROM c##g01_negocio.t_cuota c
       GROUP BY TO_CHAR(c.fecha_vencimiento, 'YYYY-MM')
       ORDER BY periodo;
    RETURN v_cursor;
  END indice_morosidad;

  -- REP03: Ranking de clientes por monto prestado (funcion analitica)
  FUNCTION ranking_clientes(
    p_top IN NUMBER DEFAULT 10
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT * FROM (
        SELECT cl.id_cliente,
               cl.nombres || ' ' || cl.apellidos AS cliente,
               COUNT(p.id_prestamo)              AS num_prestamos,
               SUM(p.monto_aprobado)             AS monto_total,
               RANK() OVER (ORDER BY SUM(p.monto_aprobado) DESC) AS ranking
          FROM c##g01_negocio.t_cliente cl
          JOIN c##g01_negocio.t_solicitud s ON s.id_cliente = cl.id_cliente
          JOIN c##g01_negocio.t_prestamo p  ON p.id_solicitud = s.id_solicitud
         GROUP BY cl.id_cliente, cl.nombres, cl.apellidos
      )
      WHERE ranking <= p_top
      ORDER BY ranking;
    RETURN v_cursor;
  END ranking_clientes;

  -- REP04: Recaudacion mensual
  FUNCTION recaudacion_mensual RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT TO_CHAR(pg.fecha_pago, 'YYYY-MM') AS periodo,
             COUNT(*)               AS num_pagos,
             SUM(pg.monto_pagado)   AS total_recaudado
        FROM c##g01_negocio.t_pago pg
       GROUP BY TO_CHAR(pg.fecha_pago, 'YYYY-MM')
       ORDER BY periodo;
    RETURN v_cursor;
  END recaudacion_mensual;

  -- REP05: Distribucion por tipo y calificacion
  FUNCTION distribucion_por_tipo RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT tp.nombre                AS tipo_prestamo,
             s.calificacion,
             COUNT(*)                 AS cantidad,
             SUM(s.monto_solicitado)  AS monto_total
        FROM c##g01_negocio.t_solicitud s
        JOIN c##g01_negocio.t_tipo_prestamo tp ON tp.id_tipo_prestamo = s.id_tipo_prestamo
       WHERE s.calificacion IS NOT NULL
       GROUP BY tp.nombre, s.calificacion
       ORDER BY tp.nombre, s.calificacion;
    RETURN v_cursor;
  END distribucion_por_tipo;

END pkg_reportes;
/

-- =====================================================================
-- FIN DEL SCRIPT 09 - Los 5 paquetes (25 requerimientos)
-- =====================================================================
