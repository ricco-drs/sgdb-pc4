
-- #####################################################################
-- PARTE A : PERMISOS DEL PAQUETE DE SEGURIDAD (en CONN_SEGURIDAD)
-- #####################################################################

-- Permite que NEGOCIO y REPORTES usen el paquete de seguridad
-- (para auditar acciones y validar permisos)
GRANT EXECUTE ON pkg_seguridad TO c##g01_negocio;
GRANT EXECUTE ON pkg_seguridad TO c##g01_reportes;


-- #####################################################################
-- PARTE B : PERMISOS DE LECTURA HACIA REPORTES (en CONN_NEGOCIO)
-- #####################################################################

-- REPORTES lee (solo SELECT) las tablas de negocio para sus reportes.
-- Esto materializa el principio de minimo privilegio del Gerente:
-- puede LEER todo para reportes, pero NUNCA modificar datos.
GRANT SELECT ON t_cliente        TO c##g01_reportes;
GRANT SELECT ON t_solicitud      TO c##g01_reportes;
GRANT SELECT ON t_prestamo       TO c##g01_reportes;
GRANT SELECT ON t_cuota          TO c##g01_reportes;
GRANT SELECT ON t_pago           TO c##g01_reportes;
GRANT SELECT ON t_tipo_prestamo  TO c##g01_reportes;


-- #####################################################################
-- PARTE C : ROLES ORACLE Y USUARIO DE APLICACION (en MiOracle / SYS)
-- #####################################################################

-- ---------------------------------------------------------------------
-- C.1 - CREACION DE ROLES ORACLE (perfiles del sistema)
--       Por estar en CDB, los roles comunes llevan prefijo C##.
-- ---------------------------------------------------------------------
CREATE ROLE c##rol_analista;
CREATE ROLE c##rol_cajero;
CREATE ROLE c##rol_supervisor;
CREATE ROLE c##rol_gerente;
CREATE ROLE c##rol_administrador;

-- ---------------------------------------------------------------------
-- C.2 - PRIVILEGIOS POR ROL (agrupacion segun perfil = minimo privilegio)
-- ---------------------------------------------------------------------

-- ROL ANALISTA: opera solicitudes y prestamos
GRANT SELECT, INSERT, UPDATE ON c##g01_negocio.t_cliente       TO c##rol_analista;
GRANT SELECT, INSERT, UPDATE ON c##g01_negocio.t_solicitud     TO c##rol_analista;
GRANT SELECT, INSERT, UPDATE ON c##g01_negocio.t_prestamo      TO c##rol_analista;
GRANT SELECT                 ON c##g01_negocio.t_tipo_prestamo TO c##rol_analista;
GRANT SELECT                 ON c##g01_negocio.t_cuota         TO c##rol_analista;
GRANT EXECUTE ON c##g01_negocio.pkg_valor     TO c##rol_analista;
GRANT EXECUTE ON c##g01_negocio.pkg_consultas TO c##rol_analista;

-- ROL CAJERO: registra pagos y consulta
GRANT SELECT ON c##g01_negocio.t_cuota    TO c##rol_cajero;
GRANT SELECT ON c##g01_negocio.t_prestamo TO c##rol_cajero;
GRANT SELECT, INSERT ON c##g01_negocio.t_pago TO c##rol_cajero;
GRANT EXECUTE ON c##g01_negocio.pkg_valor     TO c##rol_cajero;
GRANT EXECUTE ON c##g01_negocio.pkg_consultas TO c##rol_cajero;

-- ROL SUPERVISOR: consulta operativa (solo lectura)
GRANT SELECT ON c##g01_negocio.t_prestamo TO c##rol_supervisor;
GRANT SELECT ON c##g01_negocio.t_cuota    TO c##rol_supervisor;
GRANT SELECT ON c##g01_negocio.t_cliente  TO c##rol_supervisor;
GRANT EXECUTE ON c##g01_negocio.pkg_consultas TO c##rol_supervisor;

-- ROL GERENTE: SOLO reportes (minimo privilegio real)
GRANT EXECUTE ON c##g01_reportes.pkg_reportes      TO c##rol_gerente;
GRANT SELECT  ON c##g01_reportes.v_resumen_cartera TO c##rol_gerente;

-- ROL ADMINISTRADOR: gestion de administracion y seguridad
GRANT EXECUTE ON c##g01_negocio.pkg_administracion TO c##rol_administrador;
GRANT EXECUTE ON c##g01_seguridad.pkg_seguridad    TO c##rol_administrador;
GRANT SELECT  ON c##g01_seguridad.t_usuario   TO c##rol_administrador;
GRANT SELECT  ON c##g01_seguridad.t_auditoria TO c##rol_administrador;

-- ---------------------------------------------------------------------
-- C.3 - USUARIO DE APLICACION (para el backend intermedio del frontend)
--       Un solo usuario "de servicio" que el backend usa para conectarse
--       y ejecutar los paquetes. No accede a tablas directamente: toda
--       operacion pasa por los paquetes PL/SQL (encapsulamiento total).
-- ---------------------------------------------------------------------
CREATE USER c##g01_app IDENTIFIED BY app123
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp;

GRANT CREATE SESSION TO c##g01_app;

-- El usuario de aplicacion solo puede EJECUTAR los paquetes
-- (no tiene acceso directo a las tablas: seguridad por encapsulamiento)
GRANT EXECUTE ON c##g01_seguridad.pkg_seguridad      TO c##g01_app;
GRANT EXECUTE ON c##g01_negocio.pkg_valor            TO c##g01_app;
GRANT EXECUTE ON c##g01_negocio.pkg_administracion   TO c##g01_app;
GRANT EXECUTE ON c##g01_negocio.pkg_consultas        TO c##g01_app;
GRANT EXECUTE ON c##g01_reportes.pkg_reportes        TO c##g01_app;
