# PROYECTO PRESTAFACIL - Scripts de Base de Datos (Oracle 19c)

Sistema de Gestion de Prestamos Personales. Solucion 100% a nivel de
base de datos: 3 esquemas, 15 tablas, 5 paquetes PL/SQL (25 requerimientos),
roles Oracle, vistas y datos de prueba.

## Conexiones necesarias (SQL Developer)

| Conexion       | Usuario            | Password     | Rol           |
|----------------|--------------------|--------------|---------------|
| MiOracle       | SYS (as SYSDBA)    | (tu clave)   | Administrador |
| CONN_NEGOCIO   | c##g01_negocio     | negocio123   | Esquema 1     |
| CONN_SEGURIDAD | c##g01_seguridad   | seguridad123 | Esquema 2     |
| CONN_REPORTES  | c##g01_reportes    | reportes123  | Esquema 3     |

Todas: host localhost, puerto 1521, SID orcl.

## ORDEN DE INSTALACION DESDE CERO

IMPORTANTE: hay una dependencia clave. Los paquetes de negocio
(PKG_VALOR, PKG_ADMINISTRACION) llaman a PKG_SEGURIDAD, por lo que el
GRANT EXECUTE de pkg_seguridad debe existir ANTES de compilarlos.
Por eso el orden intercala un fragmento del script 11.

Ejecutar cada script en la conexion indicada, con F5 (script completo):

| Paso | Script                     | Conexion          | Que hace                         |
|------|----------------------------|-------------------|----------------------------------|
| 1    | 00_eliminacion.sql         | MiOracle (SYS)    | Limpieza (solo si reinstala)     |
| 2    | 01_esquemas.sql            | MiOracle (SYS)    | Crea los 3 usuarios/esquemas     |
| 3    | 02_tablas_negocio.sql      | CONN_NEGOCIO      | 8 tablas de negocio              |
| 4    | 03_tablas_seguridad.sql    | CONN_SEGURIDAD    | 6 tablas de seguridad            |
| 5    | 04_tablas_reportes.sql     | CONN_REPORTES     | 1 tabla de reportes              |
| 6    | 05_fk_cruzadas.sql (A)     | CONN_SEGURIDAD    | GRANTs REFERENCES/SELECT/INSERT  |
| 7    | 05_fk_cruzadas.sql (B)     | CONN_NEGOCIO      | FK cruzadas de negocio           |
| 8    | 05_fk_cruzadas.sql (C)     | CONN_REPORTES     | FK cruzada de reportes           |
| 9    | 06_secuencias.sql (A)      | CONN_NEGOCIO      | 8 secuencias                     |
| 10   | 06_secuencias.sql (B)      | CONN_SEGURIDAD    | 6 secuencias                     |
| 11   | 06_secuencias.sql (C)      | CONN_REPORTES     | 1 secuencia                      |
| 12   | 07_indices.sql             | CONN_NEGOCIO      | 7 indices                        |
| 13   | 08_datos_prueba.sql (A)    | CONN_SEGURIDAD    | Roles, usuarios, permisos        |
| 14   | 08_datos_prueba.sql (B)    | CONN_NEGOCIO      | Tipos, parametros, clientes      |
| 15   | 09_paquetes.sql (A)        | CONN_SEGURIDAD    | PKG_SEGURIDAD (spec + body)      |
| 16   | 11_privilegios_roles (A)   | CONN_SEGURIDAD    | GRANT EXECUTE pkg_seguridad *    |
| 17   | 09_paquetes.sql (B)        | CONN_NEGOCIO      | PKG_VALOR, ADMIN, CONSULTAS      |
| 18   | 11_privilegios_roles (B)   | CONN_NEGOCIO      | GRANT SELECT tablas a reportes   |
| 19   | 09_paquetes.sql (C)        | CONN_REPORTES     | PKG_REPORTES                     |
| 20   | 10_vistas.sql (A)          | CONN_NEGOCIO      | 2 vistas operativas              |
| 21   | 10_vistas.sql (B)          | CONN_REPORTES     | 1 vista gerencial                |
| 22   | 11_privilegios_roles (C)   | MiOracle (SYS)    | Roles Oracle + usuario app       |
| 23   | 12_TC_pruebas.sql          | Segun bloque      | Casos de prueba (25 req)         |

(*) El paso 16 solo ejecuta la PARTE A del script 11 (los dos GRANT
EXECUTE de pkg_seguridad). Es necesario ANTES del paso 17 para que
PKG_VALOR y PKG_ADMINISTRACION compilen (llaman a pkg_seguridad).

## Usuarios de la aplicacion (datos de prueba)

| Username | Password  | Rol           |
|----------|-----------|---------------|
| admin    | admin123  | ADMINISTRADOR |
| ana      | ana123    | ANALISTA      |
| caja     | caja123   | CAJERO        |
| super    | super123  | SUPERVISOR    |
| geren    | geren123  | GERENTE       |

## Notas tecnicas

- Entorno: Oracle 19c multitenant, trabajando en CDB$ROOT. Por eso todos
  los usuarios y roles llevan el prefijo obligatorio C##.
- Hash de contrasenas: SHA256 via DBMS_CRYPTO.HASH.
- Encriptacion de datos sensibles: AES256 via DBMS_CRYPTO (clave de 32 bytes).
- Metodo de amortizacion: frances (cuota fija).
- Las contrasenas simples (negocio123, etc.) son para el entorno academico.
  En produccion se usarian contrasenas robustas.
