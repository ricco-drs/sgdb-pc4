
-- #  BLOQUE A - PRUEBAS DE SEGURIDAD                                  #
-- #  Ejecutar en: CONN_SEGURIDAD  (usuario C##G01_SEGURIDAD)          #
SET SERVEROUTPUT ON;

-- =====================================================================
-- TC_SEG01 : Autenticar usuario (login con hash SHA256)
-- Requerimiento: SEG01
-- Objetivo: validar credenciales correctas, incorrectas e inexistentes
-- =====================================================================
DECLARE
  v_resultado VARCHAR2(30);
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_SEG01 - AUTENTICACION DE USUARIO');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  -- Caso 1: credenciales correctas (debe devolver el ROL)
  v_resultado := pkg_seguridad.autenticar_usuario('admin', 'admin123');
  DBMS_OUTPUT.PUT_LINE('Login correcto (admin/admin123): ' || v_resultado);

  -- Caso 2: contrasena incorrecta (debe devolver DENEGADO)
  v_resultado := pkg_seguridad.autenticar_usuario('admin', 'claveIncorrecta');
  DBMS_OUTPUT.PUT_LINE('Clave incorrecta: ' || v_resultado);

  -- Caso 3: usuario inexistente (debe devolver DENEGADO)
  v_resultado := pkg_seguridad.autenticar_usuario('usuario_fantasma', 'x');
  DBMS_OUTPUT.PUT_LINE('Usuario inexistente: ' || v_resultado);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: ADMINISTRADOR / DENEGADO / DENEGADO');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_SEG02 : Verificar permisos por rol
-- Requerimiento: SEG02
-- Objetivo: comprobar que cada rol solo accede a sus operaciones
-- =====================================================================
DECLARE
  v_id_analista NUMBER;
  v_id_gerente  NUMBER;
  v_id_cajero   NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_SEG02 - VERIFICACION DE PERMISOS POR ROL');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_analista FROM t_usuario WHERE username = 'ana';
  SELECT id_usuario INTO v_id_gerente  FROM t_usuario WHERE username = 'geren';
  SELECT id_usuario INTO v_id_cajero   FROM t_usuario WHERE username = 'caja';

  -- El analista SI puede aprobar prestamos
  DBMS_OUTPUT.PUT_LINE('Analista -> APROBAR_PRESTAMO: ' ||
    pkg_seguridad.tiene_permiso(v_id_analista, 'APROBAR_PRESTAMO'));

  -- El gerente NO puede aprobar prestamos (solo reportes)
  DBMS_OUTPUT.PUT_LINE('Gerente  -> APROBAR_PRESTAMO: ' ||
    pkg_seguridad.tiene_permiso(v_id_gerente, 'APROBAR_PRESTAMO'));

  -- El gerente SI puede ver reportes
  DBMS_OUTPUT.PUT_LINE('Gerente  -> VER_REPORTES: ' ||
    pkg_seguridad.tiene_permiso(v_id_gerente, 'VER_REPORTES'));

  -- El cajero SI puede registrar pagos
  DBMS_OUTPUT.PUT_LINE('Cajero   -> REGISTRAR_PAGO: ' ||
    pkg_seguridad.tiene_permiso(v_id_cajero, 'REGISTRAR_PAGO'));

  -- El cajero NO puede aprobar prestamos
  DBMS_OUTPUT.PUT_LINE('Cajero   -> APROBAR_PRESTAMO: ' ||
    pkg_seguridad.tiene_permiso(v_id_cajero, 'APROBAR_PRESTAMO'));

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: SI / NO / SI / SI / NO');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_SEG03 : Registrar auditoria
-- Requerimiento: SEG03
-- Objetivo: verificar que las acciones quedan registradas en bitacora
-- =====================================================================
DECLARE
  v_id_admin   NUMBER;
  v_total_ini  NUMBER;
  v_total_fin  NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_SEG03 - REGISTRO DE AUDITORIA');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_admin FROM t_usuario WHERE username = 'admin';

  -- Contar registros de auditoria antes
  SELECT COUNT(*) INTO v_total_ini FROM t_auditoria;
  DBMS_OUTPUT.PUT_LINE('Registros de auditoria antes: ' || v_total_ini);

  -- Registrar una accion de auditoria de prueba
  pkg_seguridad.registrar_auditoria(
    v_id_admin, 'PRUEBA_TC', 'T_AUDITORIA', NULL,
    'Registro de prueba TC_SEG03');

  -- Contar despues
  SELECT COUNT(*) INTO v_total_fin FROM t_auditoria;
  DBMS_OUTPUT.PUT_LINE('Registros de auditoria despues: ' || v_total_fin);
  DBMS_OUTPUT.PUT_LINE('La auditoria incremento en: ' || (v_total_fin - v_total_ini));

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: el contador aumenta en 1');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_SEG04 : Bloqueo de usuario tras 3 intentos fallidos
-- Requerimiento: SEG04
-- Objetivo: bloquear cuenta tras 3 fallos y permitir desbloqueo admin
-- =====================================================================
DECLARE
  v_resultado VARCHAR2(30);
  v_estado    VARCHAR2(10);
  v_intentos  NUMBER;
  v_id_user   NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_SEG04 - BLOQUEO POR INTENTOS FALLIDOS');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  -- Aseguramos que ana2 este activa antes de la prueba
  BEGIN
    SELECT id_usuario INTO v_id_user FROM t_usuario WHERE username = 'ana2';
    UPDATE t_usuario SET estado = 'ACTIVO', intentos_fallidos = 0
     WHERE id_usuario = v_id_user;
    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('NOTA: el usuario ana2 no existe. Cree ana2 con TC_ADM03 primero.');
      RETURN;
  END;

  -- Tres intentos fallidos consecutivos
  v_resultado := pkg_seguridad.autenticar_usuario('ana2', 'mala1');
  DBMS_OUTPUT.PUT_LINE('Intento 1: ' || v_resultado);
  v_resultado := pkg_seguridad.autenticar_usuario('ana2', 'mala2');
  DBMS_OUTPUT.PUT_LINE('Intento 2: ' || v_resultado);
  v_resultado := pkg_seguridad.autenticar_usuario('ana2', 'mala3');
  DBMS_OUTPUT.PUT_LINE('Intento 3: ' || v_resultado);

  -- Verificar que quedo bloqueado
  SELECT estado, intentos_fallidos INTO v_estado, v_intentos
    FROM t_usuario WHERE username = 'ana2';
  DBMS_OUTPUT.PUT_LINE('Estado tras 3 fallos: ' || v_estado || ' (intentos=' || v_intentos || ')');

  -- Intentar con clave correcta estando bloqueado (debe seguir BLOQUEADO)
  v_resultado := pkg_seguridad.autenticar_usuario('ana2', 'ana2clave');
  DBMS_OUTPUT.PUT_LINE('Login con clave correcta (bloqueado): ' || v_resultado);

  -- El administrador desbloquea
  pkg_seguridad.desbloquear_usuario(v_id_user);
  DBMS_OUTPUT.PUT_LINE('Admin desbloqueo la cuenta.');

  -- Ahora el login correcto SI funciona
  v_resultado := pkg_seguridad.autenticar_usuario('ana2', 'ana2clave');
  DBMS_OUTPUT.PUT_LINE('Login tras desbloqueo: ' || v_resultado);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: bloqueo tras 3 fallos y login OK tras desbloqueo');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_SEG05 : Encriptar y desencriptar datos sensibles (AES256)
-- Requerimiento: SEG05
-- Objetivo: proteger datos sensibles con DBMS_CRYPTO
-- =====================================================================
DECLARE
  v_original     VARCHAR2(200) := 'DatoSensible-DNI-40123456';
  v_encriptado   RAW(2000);
  v_desencriptado VARCHAR2(200);
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_SEG05 - ENCRIPTACION DE DATOS SENSIBLES');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  DBMS_OUTPUT.PUT_LINE('Texto original    : ' || v_original);

  -- Encriptar
  v_encriptado := pkg_seguridad.encriptar_dato(v_original);
  DBMS_OUTPUT.PUT_LINE('Texto encriptado  : ' || RAWTOHEX(v_encriptado));

  -- Desencriptar
  v_desencriptado := pkg_seguridad.desencriptar_dato(v_encriptado);
  DBMS_OUTPUT.PUT_LINE('Texto recuperado  : ' || v_desencriptado);

  IF v_original = v_desencriptado THEN
    DBMS_OUTPUT.PUT_LINE('VERIFICACION: OK (el dato se recupero identico)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('VERIFICACION: ERROR');
  END IF;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: el texto recuperado coincide con el original');
  DBMS_OUTPUT.PUT_LINE('');
END;
/


-- #####################################################################
-- #  BLOQUE B - PRUEBAS DE NEGOCIO                                    #
-- #  Ejecutar en: CONN_NEGOCIO  (usuario C##G01_NEGOCIO)             #
-- #  Incluye: VALOR (VAL), ADMINISTRACION (ADM), CONSULTAS (CON)      #
-- #####################################################################

SET SERVEROUTPUT ON;

-- =====================================================================
-- TC_ADM01 : Registrar cliente con validaciones
-- Requerimiento: ADM01
-- Objetivo: registrar cliente validando DNI, edad e ingreso
-- =====================================================================
DECLARE
  v_id_ana     NUMBER;
  v_id_cliente NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_ADM01 - REGISTRO DE CLIENTE');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_ana
    FROM c##g01_seguridad.t_usuario WHERE username = 'ana';

  -- Registro valido
  pkg_administracion.registrar_cliente(
    p_dni => '48901234', p_nombres => 'Diego Martin', p_apellidos => 'Salas Vargas',
    p_fecha_nac => DATE '1994-06-20', p_telefono => '987000111',
    p_email => 'diego.salas@email.com', p_direccion => 'Av. Prueba 100, Lima',
    p_ingreso => 3800, p_id_usuario_reg => v_id_ana, p_id_cliente => v_id_cliente);
  DBMS_OUTPUT.PUT_LINE('Cliente valido registrado con ID: ' || v_id_cliente);

  -- Intento con DNI invalido (menos de 8 digitos) - debe fallar
  BEGIN
    pkg_administracion.registrar_cliente(
      p_dni => '123', p_nombres => 'Error', p_apellidos => 'Test',
      p_fecha_nac => DATE '1990-01-01', p_telefono => '999',
      p_email => 'x@x.com', p_direccion => 'x',
      p_ingreso => 1000, p_id_usuario_reg => v_id_ana, p_id_cliente => v_id_cliente);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('DNI invalido rechazado: ' || SQLERRM);
  END;

  -- Intento con menor de edad - debe fallar
  BEGIN
    pkg_administracion.registrar_cliente(
      p_dni => '99999999', p_nombres => 'Menor', p_apellidos => 'Edad',
      p_fecha_nac => DATE '2015-01-01', p_telefono => '999',
      p_email => 'x@x.com', p_direccion => 'x',
      p_ingreso => 1000, p_id_usuario_reg => v_id_ana, p_id_cliente => v_id_cliente);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Menor de edad rechazado: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: registro valido OK, invalidos rechazados');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_ADM02 : Registrar tipo de prestamo y actualizar tasa
-- Requerimiento: ADM02
-- Objetivo: mantener catalogo de tipos de prestamo con sus tasas
-- =====================================================================
DECLARE
  v_id_tipo NUMBER;
  v_nombre_unico VARCHAR2(60);
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_ADM02 - TIPOS DE PRESTAMO Y TASAS');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  -- Nombre unico basado en timestamp para evitar duplicados en reejecuciones
  v_nombre_unico := 'Prestamo Test ' || TO_CHAR(SYSTIMESTAMP, 'HH24MISSFF3');

  -- Crear un tipo de prestamo nuevo
  pkg_administracion.registrar_tipo_prestamo(
    p_nombre => v_nombre_unico, p_tasa => 0.0220,
    p_monto_min => 2000, p_monto_max => 40000,
    p_plazo_min => 6, p_plazo_max => 36, p_id_tipo => v_id_tipo);
  DBMS_OUTPUT.PUT_LINE('Tipo de prestamo creado con ID: ' || v_id_tipo);

  -- Actualizar su tasa
  pkg_administracion.actualizar_tasa(v_id_tipo, 0.0195);
  DBMS_OUTPUT.PUT_LINE('Tasa actualizada a 0.0195 para el tipo ' || v_id_tipo);

  -- Intento con tasa invalida (negativa) - debe fallar
  BEGIN
    pkg_administracion.actualizar_tasa(v_id_tipo, -0.01);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Tasa negativa rechazada: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: creacion y actualizacion OK, tasa negativa rechazada');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_ADM03 : Gestionar usuario (delega en PKG_SEGURIDAD)
-- Requerimiento: ADM03
-- Objetivo: crear usuario desde administracion respetando capas
-- =====================================================================
DECLARE
  v_id_admin NUMBER;
  v_id_nuevo NUMBER;
  v_username VARCHAR2(30);
  v_existe   NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_ADM03 - GESTION DE USUARIOS');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_admin
    FROM c##g01_seguridad.t_usuario WHERE username = 'admin';

  -- Username unico para evitar duplicados en reejecuciones
  v_username := 'user' || TO_CHAR(SYSTIMESTAMP, 'HH24MISS');

  -- Crear usuario delegando en el paquete de seguridad
  pkg_administracion.gestionar_usuario(
    p_username => v_username, p_password => 'clave123',
    p_nombre_rol => 'CAJERO', p_nombre => 'Cajero Test Nuevo',
    p_email => 'cajerotest@prestafacil.pe', p_id_admin => v_id_admin,
    p_id_usuario => v_id_nuevo);
  DBMS_OUTPUT.PUT_LINE('Usuario "' || v_username || '" creado con ID: ' || v_id_nuevo);

  -- Verificar que el usuario existe en el esquema de seguridad
  SELECT COUNT(*) INTO v_existe
    FROM c##g01_seguridad.t_usuario WHERE id_usuario = v_id_nuevo;
  DBMS_OUTPUT.PUT_LINE('Usuario confirmado en esquema SEGURIDAD: ' ||
    CASE WHEN v_existe > 0 THEN 'SI' ELSE 'NO' END);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: usuario creado en esquema de seguridad');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_ADM04 : Gestionar parametros del sistema
-- Requerimiento: ADM04
-- Objetivo: modificar parametros que alteran el comportamiento
-- =====================================================================
DECLARE
  v_id_admin  NUMBER;
  v_valor_ini VARCHAR2(50);
  v_valor_mod VARCHAR2(50);
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_ADM04 - GESTION DE PARAMETROS');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_admin
    FROM c##g01_seguridad.t_usuario WHERE username = 'admin';

  -- Ver valor inicial
  SELECT valor INTO v_valor_ini FROM t_parametro WHERE codigo = 'DIAS_MOROSIDAD';
  DBMS_OUTPUT.PUT_LINE('DIAS_MOROSIDAD (inicial): ' || v_valor_ini);

  -- Cambiar el parametro
  pkg_administracion.actualizar_parametro('DIAS_MOROSIDAD', '10', v_id_admin);
  SELECT valor INTO v_valor_mod FROM t_parametro WHERE codigo = 'DIAS_MOROSIDAD';
  DBMS_OUTPUT.PUT_LINE('DIAS_MOROSIDAD (modificado): ' || v_valor_mod);

  -- Restaurar el valor original para no alterar el sistema
  pkg_administracion.actualizar_parametro('DIAS_MOROSIDAD', v_valor_ini, v_id_admin);
  DBMS_OUTPUT.PUT_LINE('DIAS_MOROSIDAD restaurado a: ' || v_valor_ini);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: el parametro cambia y se restaura');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_ADM05 : Gestionar lista negra
-- Requerimiento: ADM05
-- Objetivo: vetar clientes y verificar que se bloquean sus solicitudes
-- =====================================================================
DECLARE
  v_id_admin NUMBER;
  v_id_ana   NUMBER;
  v_id_lista NUMBER;
  v_id_sol   NUMBER;
  v_ya       NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_ADM05 - LISTA NEGRA');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_admin FROM c##g01_seguridad.t_usuario WHERE username = 'admin';
  SELECT id_usuario INTO v_id_ana   FROM c##g01_seguridad.t_usuario WHERE username = 'ana';

  -- Verificar si el cliente 4 ya esta en lista negra
  SELECT COUNT(*) INTO v_ya FROM t_lista_negra
   WHERE id_cliente = 4 AND estado = 'ACTIVO';

  IF v_ya = 0 THEN
    pkg_administracion.agregar_lista_negra(
      p_id_cliente => 4, p_motivo => 'Prueba de lista negra TC_ADM05',
      p_id_usuario_reg => v_id_admin, p_id_lista => v_id_lista);
    DBMS_OUTPUT.PUT_LINE('Cliente 4 agregado a lista negra. ID lista: ' || v_id_lista);
  ELSE
    DBMS_OUTPUT.PUT_LINE('Cliente 4 ya estaba en lista negra.');
  END IF;

  -- Intentar registrar solicitud para el cliente vetado (debe fallar)
  BEGIN
    pkg_valor.registrar_solicitud(4, 1, 5000, 12, v_id_ana, v_id_sol);
    DBMS_OUTPUT.PUT_LINE('ERROR: no deberia permitir la solicitud');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Solicitud bloqueada por lista negra: ' || SQLERRM);
  END;

  -- Retirar de lista negra
  pkg_administracion.quitar_lista_negra(4);
  DBMS_OUTPUT.PUT_LINE('Cliente 4 retirado de lista negra.');

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: veto bloquea solicitud, luego se retira');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_VAL01 : Registrar solicitud de prestamo
-- Requerimiento: VAL01
-- Objetivo: crear solicitud validando cliente, monto, plazo y rangos
-- =====================================================================
DECLARE
  v_id_ana       NUMBER;
  v_id_solicitud NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_VAL01 - REGISTRAR SOLICITUD');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_ana
    FROM c##g01_seguridad.t_usuario WHERE username = 'ana';

  -- Solicitud valida (cliente 1, tipo 1, monto 8000, plazo 12)
  pkg_valor.registrar_solicitud(
    p_id_cliente => 1, p_id_tipo_prestamo => 1, p_monto => 8000,
    p_plazo_meses => 12, p_id_analista => v_id_ana, p_id_solicitud => v_id_solicitud);
  DBMS_OUTPUT.PUT_LINE('Solicitud valida creada con ID: ' || v_id_solicitud);

  -- Intento con monto fuera de rango (muy alto) - debe fallar
  BEGIN
    pkg_valor.registrar_solicitud(1, 1, 999999, 12, v_id_ana, v_id_solicitud);
    DBMS_OUTPUT.PUT_LINE('ERROR: no deberia permitir monto fuera de rango');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Monto fuera de rango rechazado: ' || SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: solicitud valida OK, monto invalido rechazado');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_VAL02 : Evaluar capacidad de pago y calificar
-- Requerimiento: VAL02
-- Objetivo: calcular capacidad y asignar calificacion A/B/C/D
-- =====================================================================
DECLARE
  v_id_ana       NUMBER;
  v_id_solicitud NUMBER;
  v_calificacion CHAR(1);
  v_capacidad    NUMBER;
  v_ratio        NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_VAL02 - EVALUAR Y CALIFICAR SOLICITUD');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_ana
    FROM c##g01_seguridad.t_usuario WHERE username = 'ana';

  -- Crear una solicitud para evaluar
  pkg_valor.registrar_solicitud(
    p_id_cliente => 1, p_id_tipo_prestamo => 1, p_monto => 9000,
    p_plazo_meses => 18, p_id_analista => v_id_ana, p_id_solicitud => v_id_solicitud);

  -- Evaluar la solicitud
  pkg_valor.evaluar_solicitud(v_id_solicitud, v_calificacion);

  -- Mostrar los resultados calculados
  SELECT capacidad_pago, ratio_cuota_ingreso
    INTO v_capacidad, v_ratio
    FROM t_solicitud WHERE id_solicitud = v_id_solicitud;

  DBMS_OUTPUT.PUT_LINE('Solicitud ' || v_id_solicitud || ' evaluada:');
  DBMS_OUTPUT.PUT_LINE('  Capacidad de pago: ' || v_capacidad);
  DBMS_OUTPUT.PUT_LINE('  Ratio cuota/ingreso: ' || ROUND(v_ratio, 4));
  DBMS_OUTPUT.PUT_LINE('  Calificacion asignada: ' || v_calificacion);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: calificacion entre A y D segun el ratio');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_VAL03 : Aprobar o rechazar solicitud
-- Requerimiento: VAL03
-- Objetivo: decidir la solicitud y crear el prestamo si se aprueba
-- =====================================================================
DECLARE
  v_id_ana       NUMBER;
  v_id_solicitud NUMBER;
  v_calificacion CHAR(1);
  v_estado       VARCHAR2(12);
  v_existe_prest NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_VAL03 - APROBAR / RECHAZAR SOLICITUD');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_ana
    FROM c##g01_seguridad.t_usuario WHERE username = 'ana';

  -- Crear y evaluar una solicitud
  pkg_valor.registrar_solicitud(
    p_id_cliente => 1, p_id_tipo_prestamo => 1, p_monto => 7000,
    p_plazo_meses => 12, p_id_analista => v_id_ana, p_id_solicitud => v_id_solicitud);
  pkg_valor.evaluar_solicitud(v_id_solicitud, v_calificacion);
  DBMS_OUTPUT.PUT_LINE('Solicitud ' || v_id_solicitud || ' calificacion: ' || v_calificacion);

  -- Aprobar la solicitud
  pkg_valor.decidir_solicitud(v_id_solicitud, 'APROBAR', v_id_ana);

  -- Verificar el nuevo estado
  SELECT estado INTO v_estado FROM t_solicitud WHERE id_solicitud = v_id_solicitud;
  DBMS_OUTPUT.PUT_LINE('Estado de la solicitud: ' || v_estado);

  -- Verificar que se creo el prestamo
  SELECT COUNT(*) INTO v_existe_prest FROM t_prestamo WHERE id_solicitud = v_id_solicitud;
  DBMS_OUTPUT.PUT_LINE('Prestamo generado: ' || CASE WHEN v_existe_prest > 0 THEN 'SI' ELSE 'NO' END);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: estado APROBADO y prestamo creado');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_VAL04 : Generar cronograma (metodo frances)
-- Requerimiento: VAL04
-- Objetivo: generar cuotas con amortizacion francesa (saldo cierra en 0)
-- =====================================================================
DECLARE
  v_id_ana       NUMBER;
  v_id_solicitud NUMBER;
  v_calificacion CHAR(1);
  v_id_prestamo  NUMBER;
  v_num_cuotas   NUMBER;
  v_saldo_final  NUMBER;
  v_suma_capital NUMBER;
  v_monto        NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_VAL04 - GENERAR CRONOGRAMA (METODO FRANCES)');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_ana
    FROM c##g01_seguridad.t_usuario WHERE username = 'ana';

  -- Crear, evaluar y aprobar (aprobar genera el cronograma automaticamente)
  pkg_valor.registrar_solicitud(
    p_id_cliente => 1, p_id_tipo_prestamo => 1, p_monto => 12000,
    p_plazo_meses => 24, p_id_analista => v_id_ana, p_id_solicitud => v_id_solicitud);
  pkg_valor.evaluar_solicitud(v_id_solicitud, v_calificacion);
  pkg_valor.decidir_solicitud(v_id_solicitud, 'APROBAR', v_id_ana);

  SELECT id_prestamo, monto_aprobado INTO v_id_prestamo, v_monto
    FROM t_prestamo WHERE id_solicitud = v_id_solicitud;

  -- Verificar el cronograma generado
  SELECT COUNT(*), MIN(saldo_capital), SUM(monto_capital)
    INTO v_num_cuotas, v_saldo_final, v_suma_capital
    FROM t_cuota WHERE id_prestamo = v_id_prestamo;

  DBMS_OUTPUT.PUT_LINE('Prestamo ' || v_id_prestamo || ' (monto ' || v_monto || ')');
  DBMS_OUTPUT.PUT_LINE('Numero de cuotas generadas: ' || v_num_cuotas || ' (esperado 24)');
  DBMS_OUTPUT.PUT_LINE('Saldo capital de la ultima cuota: ' || v_saldo_final || ' (esperado 0)');
  DBMS_OUTPUT.PUT_LINE('Suma de capital de todas las cuotas: ' || v_suma_capital ||
    ' (debe igualar el monto ' || v_monto || ')');

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: 24 cuotas, saldo final 0, capital suma el monto');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_VAL05 : Registrar pago de cuota
-- Requerimiento: VAL05
-- Objetivo: registrar pago, actualizar saldo y marcar cuota pagada
-- =====================================================================
DECLARE
  v_id_ana       NUMBER;
  v_id_caja      NUMBER;
  v_id_solicitud NUMBER;
  v_calificacion CHAR(1);
  v_id_prestamo  NUMBER;
  v_id_cuota     NUMBER;
  v_monto_cuota  NUMBER;
  v_saldo_antes  NUMBER;
  v_saldo_desp   NUMBER;
  v_estado_cuota VARCHAR2(10);
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_VAL05 - REGISTRAR PAGO DE CUOTA');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  SELECT id_usuario INTO v_id_ana  FROM c##g01_seguridad.t_usuario WHERE username = 'ana';
  SELECT id_usuario INTO v_id_caja FROM c##g01_seguridad.t_usuario WHERE username = 'caja';

  -- Preparar un prestamo con cronograma
  pkg_valor.registrar_solicitud(
    p_id_cliente => 1, p_id_tipo_prestamo => 1, p_monto => 5000,
    p_plazo_meses => 6, p_id_analista => v_id_ana, p_id_solicitud => v_id_solicitud);
  pkg_valor.evaluar_solicitud(v_id_solicitud, v_calificacion);
  pkg_valor.decidir_solicitud(v_id_solicitud, 'APROBAR', v_id_ana);

  SELECT id_prestamo INTO v_id_prestamo
    FROM t_prestamo WHERE id_solicitud = v_id_solicitud;
  SELECT saldo_pendiente INTO v_saldo_antes
    FROM t_prestamo WHERE id_prestamo = v_id_prestamo;

  -- Tomar la primera cuota
  SELECT id_cuota, monto_cuota INTO v_id_cuota, v_monto_cuota
    FROM t_cuota WHERE id_prestamo = v_id_prestamo AND numero_cuota = 1;

  DBMS_OUTPUT.PUT_LINE('Saldo del prestamo antes del pago: ' || v_saldo_antes);
  DBMS_OUTPUT.PUT_LINE('Pagando cuota 1 por: ' || v_monto_cuota);

  -- Registrar el pago (cajero)
  pkg_valor.registrar_pago(v_id_cuota, v_monto_cuota, 'EFECTIVO', v_id_caja);

  -- Verificar resultados
  SELECT estado INTO v_estado_cuota FROM t_cuota WHERE id_cuota = v_id_cuota;
  SELECT saldo_pendiente INTO v_saldo_desp FROM t_prestamo WHERE id_prestamo = v_id_prestamo;

  DBMS_OUTPUT.PUT_LINE('Estado de la cuota tras el pago: ' || v_estado_cuota);
  DBMS_OUTPUT.PUT_LINE('Saldo del prestamo despues del pago: ' || v_saldo_desp);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: cuota PAGADA y saldo reducido');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_CON01 : Consultar cronograma de un prestamo
-- Requerimiento: CON01
-- Objetivo: devolver todas las cuotas de un prestamo
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_num    NUMBER; v_venc DATE; v_cap NUMBER; v_int NUMBER;
  v_cuota  NUMBER; v_saldo NUMBER; v_pagado NUMBER; v_estado VARCHAR2(10);
  v_count  NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_CON01 - CONSULTAR CRONOGRAMA (PRESTAMO 1)');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_consultas.consultar_cronograma(1);
  LOOP
    FETCH v_cursor INTO v_num, v_venc, v_cap, v_int, v_cuota, v_saldo, v_pagado, v_estado;
    EXIT WHEN v_cursor%NOTFOUND;
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE('Cuota ' || v_num || ' | Vence: ' || TO_CHAR(v_venc,'DD/MM/YY') ||
      ' | Cuota: ' || v_cuota || ' | Saldo: ' || v_saldo || ' | ' || v_estado);
  END LOOP;
  CLOSE v_cursor;
  DBMS_OUTPUT.PUT_LINE('Total de cuotas listadas: ' || v_count);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: se listan todas las cuotas del prestamo');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_CON02 : Consultar estado y saldo de un prestamo
-- Requerimiento: CON02
-- Objetivo: mostrar saldo, estado y avance de cuotas
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_idp NUMBER; v_monto NUMBER; v_cuota NUMBER; v_saldo NUMBER;
  v_estado VARCHAR2(10); v_pagadas NUMBER; v_totales NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_CON02 - CONSULTAR ESTADO DEL PRESTAMO 1');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_consultas.consultar_estado_prestamo(1);
  FETCH v_cursor INTO v_idp, v_monto, v_cuota, v_saldo, v_estado, v_pagadas, v_totales;
  DBMS_OUTPUT.PUT_LINE('Prestamo ' || v_idp);
  DBMS_OUTPUT.PUT_LINE('  Monto aprobado: ' || v_monto);
  DBMS_OUTPUT.PUT_LINE('  Cuota mensual: ' || v_cuota);
  DBMS_OUTPUT.PUT_LINE('  Saldo pendiente: ' || v_saldo);
  DBMS_OUTPUT.PUT_LINE('  Estado: ' || v_estado);
  DBMS_OUTPUT.PUT_LINE('  Cuotas pagadas: ' || v_pagadas || ' de ' || v_totales);
  CLOSE v_cursor;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: datos consolidados del prestamo');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_CON03 : Consultar historial de pagos de un cliente
-- Requerimiento: CON03
-- Objetivo: listar los pagos realizados por un cliente
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_idpago NUMBER; v_fecha DATE; v_monto NUMBER; v_medio VARCHAR2(15);
  v_ncuota NUMBER; v_idprest NUMBER;
  v_count NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_CON03 - HISTORIAL DE PAGOS (CLIENTE 1)');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_consultas.consultar_historial_pagos(1);
  LOOP
    FETCH v_cursor INTO v_idpago, v_fecha, v_monto, v_medio, v_ncuota, v_idprest;
    EXIT WHEN v_cursor%NOTFOUND;
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE('Pago ' || v_idpago || ' | Prestamo ' || v_idprest ||
      ' | Cuota ' || v_ncuota || ' | Monto: ' || v_monto || ' | ' || v_medio);
  END LOOP;
  CLOSE v_cursor;
  DBMS_OUTPUT.PUT_LINE('Total de pagos del cliente: ' || v_count);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: se listan los pagos del cliente');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_CON04 : Buscar clientes por criterio
-- Requerimiento: CON04
-- Objetivo: buscar clientes por nombre, apellido o DNI
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_idc NUMBER; v_dni VARCHAR2(8); v_nom VARCHAR2(100); v_ape VARCHAR2(100);
  v_tel VARCHAR2(15); v_email VARCHAR2(120); v_ing NUMBER; v_est VARCHAR2(10);
  v_count NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_CON04 - BUSCAR CLIENTES (criterio "a")');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  -- Busqueda amplia para demostrar coincidencias
  v_cursor := pkg_consultas.buscar_clientes('a');
  LOOP
    FETCH v_cursor INTO v_idc, v_dni, v_nom, v_ape, v_tel, v_email, v_ing, v_est;
    EXIT WHEN v_cursor%NOTFOUND;
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE(v_nom || ' ' || v_ape || ' | DNI: ' || v_dni);
  END LOOP;
  CLOSE v_cursor;
  DBMS_OUTPUT.PUT_LINE('Total de clientes encontrados: ' || v_count);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: lista de clientes que coinciden');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_CON05 : Consultar cuotas vencidas / morosas
-- Requerimiento: CON05
-- Objetivo: detectar cuotas con atraso superior al parametro
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_idc NUMBER; v_nom VARCHAR2(100); v_ape VARCHAR2(100); v_idp NUMBER;
  v_nc NUMBER; v_venc DATE; v_mc NUMBER; v_mp NUMBER; v_dias NUMBER; v_est VARCHAR2(10);
  v_count NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_CON05 - CUOTAS MOROSAS (todas)');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_consultas.consultar_cuotas_morosas(NULL);
  LOOP
    FETCH v_cursor INTO v_idc, v_nom, v_ape, v_idp, v_nc, v_venc, v_mc, v_mp, v_dias, v_est;
    EXIT WHEN v_cursor%NOTFOUND;
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE(v_nom || ' ' || v_ape || ' | Prestamo ' || v_idp ||
      ' | Cuota ' || v_nc || ' | Dias atraso: ' || v_dias);
  END LOOP;
  CLOSE v_cursor;

  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('(No hay cuotas morosas en este momento)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Total de cuotas morosas: ' || v_count);
  END IF;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: cuotas vencidas con sus dias de atraso');
  DBMS_OUTPUT.PUT_LINE('');
END;
/


-- #####################################################################
-- #  BLOQUE C - PRUEBAS DE REPORTES                                   #
-- #  Ejecutar en: CONN_REPORTES  (usuario C##G01_REPORTES)           #
-- #####################################################################

SET SERVEROUTPUT ON;

-- =====================================================================
-- TC_REP01 : Cartera total de prestamos por estado
-- Requerimiento: REP01
-- Objetivo: consolidar la cartera agrupada por estado
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_estado VARCHAR2(10); v_cant NUMBER; v_monto NUMBER; v_saldo NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_REP01 - CARTERA POR ESTADO');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_reportes.cartera_por_estado;
  LOOP
    FETCH v_cursor INTO v_estado, v_cant, v_monto, v_saldo;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('Estado ' || v_estado || ' | Cantidad: ' || v_cant ||
      ' | Monto total: ' || v_monto || ' | Saldo: ' || v_saldo);
  END LOOP;
  CLOSE v_cursor;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: resumen de la cartera por estado');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_REP02 : Indice de morosidad por periodo
-- Requerimiento: REP02
-- Objetivo: calcular el porcentaje de morosidad por mes
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_periodo VARCHAR2(7); v_total NUMBER; v_morosas NUMBER; v_porc NUMBER;
  v_count NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_REP02 - INDICE DE MOROSIDAD');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_reportes.indice_morosidad;
  LOOP
    FETCH v_cursor INTO v_periodo, v_total, v_morosas, v_porc;
    EXIT WHEN v_cursor%NOTFOUND;
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE('Periodo ' || v_periodo || ' | Total: ' || v_total ||
      ' | Morosas: ' || v_morosas || ' | % Morosidad: ' || v_porc);
  END LOOP;
  CLOSE v_cursor;
  DBMS_OUTPUT.PUT_LINE('Periodos analizados: ' || v_count);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: morosidad por periodo (0% si no hay vencidas)');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_REP03 : Ranking de clientes por monto prestado
-- Requerimiento: REP03
-- Objetivo: ordenar clientes por monto usando funcion analitica RANK
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_id NUMBER; v_cliente VARCHAR2(200); v_num NUMBER; v_monto NUMBER; v_rank NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_REP03 - RANKING DE CLIENTES');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_reportes.ranking_clientes(10);
  LOOP
    FETCH v_cursor INTO v_id, v_cliente, v_num, v_monto, v_rank;
    EXIT WHEN v_cursor%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE('#' || v_rank || ' | ' || v_cliente ||
      ' | Prestamos: ' || v_num || ' | Monto total: ' || v_monto);
  END LOOP;
  CLOSE v_cursor;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: clientes rankeados por monto (RANK)');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_REP04 : Recaudacion por periodo
-- Requerimiento: REP04
-- Objetivo: totalizar lo recaudado por mes
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_periodo VARCHAR2(7); v_npagos NUMBER; v_recaudado NUMBER;
  v_count NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_REP04 - RECAUDACION MENSUAL');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_reportes.recaudacion_mensual;
  LOOP
    FETCH v_cursor INTO v_periodo, v_npagos, v_recaudado;
    EXIT WHEN v_cursor%NOTFOUND;
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE('Periodo ' || v_periodo || ' | Pagos: ' || v_npagos ||
      ' | Recaudado: ' || v_recaudado);
  END LOOP;
  CLOSE v_cursor;

  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('(No hay pagos registrados aun)');
  END IF;

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: totales recaudados por mes');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- TC_REP05 : Distribucion de prestamos por tipo y calificacion
-- Requerimiento: REP05
-- Objetivo: analizar la distribucion por categoria
-- =====================================================================
DECLARE
  v_cursor SYS_REFCURSOR;
  v_tipo VARCHAR2(60); v_calif VARCHAR2(1); v_cant NUMBER; v_monto NUMBER;
  v_count NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('==================================================');
  DBMS_OUTPUT.PUT_LINE(' TC_REP05 - DISTRIBUCION POR TIPO Y CALIFICACION');
  DBMS_OUTPUT.PUT_LINE('==================================================');

  v_cursor := pkg_reportes.distribucion_por_tipo;
  LOOP
    FETCH v_cursor INTO v_tipo, v_calif, v_cant, v_monto;
    EXIT WHEN v_cursor%NOTFOUND;
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE(v_tipo || ' | Calificacion ' || v_calif ||
      ' | Cantidad: ' || v_cant || ' | Monto: ' || v_monto);
  END LOOP;
  CLOSE v_cursor;
  DBMS_OUTPUT.PUT_LINE('Combinaciones tipo/calificacion: ' || v_count);

  DBMS_OUTPUT.PUT_LINE('RESULTADO ESPERADO: distribucion por tipo y calificacion');
  DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================================
-- FIN DE LOS CASOS DE PRUEBA
-- Total: 25 requerimientos (SEG01-05, VAL01-05, ADM01-05, CON01-05, REP01-05)
-- =====================================================================
