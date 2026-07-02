SET SERVEROUTPUT ON;

-- ---------------------------------------------------------------------
-- 1. ELIMINAR ROLES ORACLE (si existen)
-- ---------------------------------------------------------------------
BEGIN
  FOR r IN (SELECT role FROM dba_roles
             WHERE role IN ('C##ROL_ANALISTA','C##ROL_CAJERO',
                            'C##ROL_SUPERVISOR','C##ROL_GERENTE',
                            'C##ROL_ADMINISTRADOR')) LOOP
    EXECUTE IMMEDIATE 'DROP ROLE ' || r.role;
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- 2. ELIMINAR USUARIO DE APLICACION (frontend), si existe
-- ---------------------------------------------------------------------
BEGIN
  FOR u IN (SELECT username FROM dba_users
             WHERE username = 'C##G01_APP') LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- 3. ELIMINAR LOS 3 ESQUEMAS CON TODOS SUS OBJETOS
--    CASCADE elimina tablas, paquetes, vistas, secuencias, indices, etc.
-- ---------------------------------------------------------------------
BEGIN
  FOR u IN (SELECT username FROM dba_users
             WHERE username IN ('C##G01_NEGOCIO','C##G01_SEGURIDAD','C##G01_REPORTES')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
  END LOOP;
END;
/

BEGIN
  DBMS_OUTPUT.PUT_LINE('====================================================');
  DBMS_OUTPUT.PUT_LINE(' Eliminacion controlada completada.');
  DBMS_OUTPUT.PUT_LINE(' Esquemas, roles y usuario de aplicacion eliminados.');
  DBMS_OUTPUT.PUT_LINE(' Puede ejecutar los scripts de creacion desde 01.');
  DBMS_OUTPUT.PUT_LINE('====================================================');
END;
/
