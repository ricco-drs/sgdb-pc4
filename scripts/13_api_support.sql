
-- EJECUTAR EN: CONN_SEGURIDAD  (usuario c##g01_seguridad)

CREATE OR REPLACE PROCEDURE sp_login_api(
  p_username   IN  VARCHAR2,
  p_password   IN  VARCHAR2,
  p_id_usuario OUT NUMBER,
  p_rol        OUT VARCHAR2
) AS
BEGIN
  -- Reutiliza EXACTAMENTE la logica de SEG01 (hash SHA256, bloqueo, auditoria).
  p_rol := pkg_seguridad.autenticar_usuario(p_username, p_password);

  IF p_rol IN ('DENEGADO', 'BLOQUEADO') THEN
    p_id_usuario := NULL;   -- login fallido: no exponemos id
  ELSE
    SELECT id_usuario INTO p_id_usuario
      FROM t_usuario
     WHERE username = p_username;
  END IF;
END sp_login_api;
/

-- El backend (C##G01_APP) solo necesita EXECUTE sobre este procedimiento.
GRANT EXECUTE ON sp_login_api TO c##g01_app;

-- FIN DEL SCRIPT 13