-- =============================================================================
-- Usuarios de base de datos con mínimo privilegio
-- El usuario maestro (admin_educloud) se usa solo para administrar; su
-- contraseña la genera y guarda RDS en AWS Secrets Manager.
-- Las contraseñas de abajo son marcadores: se reemplazan por las que
-- genera Secrets Manager (secretos educloud/rds/app y educloud/rds/reportes).
-- =============================================================================

-- Aplicación web (EC2): lee y escribe datos, pero no puede borrar tablas
-- ni cambiar el esquema (sin DROP, ALTER ni GRANT).
CREATE USER 'app_educloud'@'%' IDENTIFIED BY '<desde-secrets-manager>' REQUIRE SSL;
GRANT SELECT, INSERT, UPDATE ON educloud.* TO 'app_educloud'@'%';
GRANT DELETE ON educloud.progreso TO 'app_educloud'@'%';

-- Lambda de reportes: solo lectura.
CREATE USER 'reportes_educloud'@'%' IDENTIFIED BY '<desde-secrets-manager>' REQUIRE SSL;
GRANT SELECT ON educloud.* TO 'reportes_educloud'@'%';

-- '%' acepta cualquier origen a nivel MySQL, pero la red ya lo limita:
-- el Security Group SG-RDS solo deja entrar a SG-Web-Servers y SG-Lambda-Reportes.
-- REQUIRE SSL rechaza conexiones sin cifrar (TLS en tránsito).
