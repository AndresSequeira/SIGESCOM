-- SIGESCOM - Paso 01
-- Ejecutar conectado como ADMIN en SQL Developer.
-- Antes de este script, en Oracle Cloud cree la Autonomous AI Database:
-- Nombre: SIGESCOM
-- Password ADMIN: Basesdedatos2026.

CREATE USER ADMINBD IDENTIFIED BY "Basesdedatos2026.";
GRANT CONNECT, RESOURCE TO ADMINBD;
ALTER USER ADMINBD QUOTA UNLIMITED ON USERS;

-- Privilegios utiles para objetos REST/APEX y PL/SQL en Autonomous Database.
GRANT CREATE VIEW TO ADMINBD;
GRANT CREATE PROCEDURE TO ADMINBD;
GRANT CREATE TRIGGER TO ADMINBD;
GRANT CREATE SEQUENCE TO ADMINBD;

