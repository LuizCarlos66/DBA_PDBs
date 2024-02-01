
---
#  Fecha o PDB
---
SQL> ALTER PLUGGABLE DATABASE FXCONF CLOSE INSTANCES=ALL;

Pluggable database altered.

SQL> show pdbs

CON_ID     CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
        57 FXCONF                         MOUNTED

---
# Abre o PDB no modo de UPGRADE
---
SQL> ALTER PLUGGABLE DATABASE FXOGG OPEN UPGRADE;

Pluggable database altered.

SQL> show pdbs

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
        57 FXOGG                          MIGRATE    YES

---
# Verifica valores de Versão do DST
---
SQL> COLUMN property_name FORMAT A30
COLUMN property_value FORMAT A20

SELECT property_name, property_value
FROM   database_properties
WHERE  property_name LIKE 'DST_%'
ORDER BY property_name;

PROPERTY_NAME                  PROPERTY_VALUE
------------------------------ --------------------
DST_PRIMARY_TT_VERSION         31
DST_SECONDARY_TT_VERSION       0
DST_UPGRADE_STATE              NONE

---
# Altera o Status do DST para UPGRADE
---
SQL> DECLARE
  l_tz_version PLS_INTEGER;
BEGIN
  SELECT DBMS_DST.get_latest_timezone_version
  INTO   l_tz_version
  FROM   dual;

  DBMS_OUTPUT.put_line('l_tz_version=' || l_tz_version);
  DBMS_DST.begin_upgrade(l_tz_version);
END;
/

PL/SQL procedure successfully completed.

---
# Verifica valores de Versão do DST e Status se está como UPGRADE
---
SQL> COLUMN property_name FORMAT A30
COLUMN property_value FORMAT A20

SELECT property_name, property_value
FROM   database_properties
WHERE  property_name LIKE 'DST_%'
ORDER BY property_name;

PROPERTY_NAME                  PROPERTY_VALUE
------------------------------ --------------------
DST_PRIMARY_TT_VERSION         34
DST_SECONDARY_TT_VERSION       31
DST_UPGRADE_STATE              UPGRADE


---
# Fecha o PDB - Normal
---
SQL> ALTER PLUGGABLE DATABASE FXOGG CLOSE INSTANCES=ALL;

Pluggable database altered.

##############################################################################
# Abre o PDB somente em 1 dos NO do RAC
##############################################################################
SQL> ALTER PLUGGABLE DATABASE FXOGG OPEN;

Pluggable database altered.

SQL> show pdbs

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
        57 FXOGG                          READ WRITE NO

---
# Executa Procedimento de UPGRADE_DATABASE e END_UPGRADE
---
SQL> COLUMN property_name FORMAT A30
COLUMN property_value FORMAT A20

SELECT property_name, property_value
FROM   database_properties
WHERE  property_name LIKE 'DST_%'
ORDER BY property_name;

PROPERTY_NAME                  PROPERTY_VALUE
------------------------------ --------------------
DST_PRIMARY_TT_VERSION         34
DST_SECONDARY_TT_VERSION       31
DST_UPGRADE_STATE              UPGRADE

SQL> SET SERVEROUTPUT ON
DECLARE
SQL>   2    l_failures   PLS_INTEGER;
  3  BEGIN
  4    DBMS_DST.upgrade_database(l_failures);
  5    DBMS_OUTPUT.put_line('DBMS_DST.upgrade_database : l_failures=' || l_failures);
  6    DBMS_DST.end_upgrade(l_failures);
  7    DBMS_OUTPUT.put_line('DBMS_DST.end_upgrade : l_failures=' || l_failures);
  8  END;
  9  /
Table list: "GSMADMIN_INTERNAL"."AQ$_CHANGE_LOG_QUEUE_TABLE_L"
Number of failures: 0
Table list: "GSMADMIN_INTERNAL"."AQ$_CHANGE_LOG_QUEUE_TABLE_S"
Number of failures: 0
Table list: "DVSYS"."SIMULATION_LOG$"
Number of failures: 0
Table list: "DVSYS"."AUDIT_TRAIL$"
Number of failures: 0
Table list: "C##OGGADM"."AQ$_QT$_OGG$RFXPRD_2_L"
Number of failures: 0
Table list: "C##OGGADM"."AQ$_QT$_OGG$RFXPRD_2_S"
Number of failures: 0
Table list: "C##OGGADM"."AQ$_QT$_OGG$RSYSTEM_1_L"
Number of failures: 0
Table list: "C##OGGADM"."AQ$_QT$_OGG$RSYSTEM_1_S"
Number of failures: 0
DBMS_DST.upgrade_database : l_failures=0
An upgrade window has been successfully ended.
DBMS_DST.end_upgrade : l_failures=0

PL/SQL procedure successfully completed.

##############################################################################
# Valida Upgrade Pós-Upgrade
##############################################################################
SQL> COLUMN property_name FORMAT A30
COLUMN property_value FORMAT A20

SELECT property_name, property_value
FROM   database_properties
WHERE  property_name LIKE 'DST_%'
ORDER BY property_name;

PROPERTY_NAME                  PROPERTY_VALUE
------------------------------ --------------------
DST_PRIMARY_TT_VERSION         34
DST_SECONDARY_TT_VERSION       0
DST_UPGRADE_STATE              NONE

---
# Fecha o PDB
---
SQL> ALTER PLUGGABLE DATABASE FXOGG CLOSE INSTANCES=ALL;

Pluggable database altered.

##############################################################################
#  Abre o PDB - Normal em todas as Instancias
##############################################################################
SQL> ALTER PLUGGABLE DATABASE FXOGG OPEN INSTANCES=ALL;


Pluggable database altered.

##############################################################################
#  Check novamente a versão do DST
##############################################################################
SQL> SELECT property_name, property_value
FROM   database_properties
WHERE  property_name LIKE 'DST_%'
ORDER BY property_name;  2    3    4

PROPERTY_NAME                  PROPERTY_VALUE
------------------------------ --------------------
DST_PRIMARY_TT_VERSION         34
DST_SECONDARY_TT_VERSION       0
DST_UPGRADE_STATE              NONE


Bibliotecas:
https://oracle-base.com/articles/misc/update-database-time-zone-file
https://docs.oracle.com/en/database/oracle/oracle-database/12.2/upgrd/rerunning-upgrades-oracle-database.html#GUID-B8C68634-CB6B-415D-BB31-E8E11EBAF742
https://smarttechways.com/2021/06/26/upgrade-the-database-time-zone-in-multitenant-cdb-or-pdb-environment/
