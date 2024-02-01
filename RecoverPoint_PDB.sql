col name format a30
col time format a32
col scn format 999999999999999999
set linesize 100
select NAME
    , TIME
    , SCN
    , PDB_RESTORE_POINT
    , GUARANTEE_FLASHBACK_DATABASE 
from V$RESTORE_POINT;

/* -------------------------------------------------------------------------------- */
DROP RESTORE POINT PROVISIONAMENTO_XXXX FOR PLUGGABLE DATABASE FXPROV;

/* ======================================================== 
Ativa o FlashBack:
*/
ALTER DATABASE FLASHBACK ON;

/* ======================================================== 
Desativa o FlashBack:
*/
ALTER DATABASE FLASHBACK OFF;

/* -------------------------------------------------------------------------------- */
https://www.oracle.com/br/technical-resources/articles/database-performance/flashback.html

Introdução:

O Oracle Database 12c R2 agora permite que se aplique nos PluggableDatabases (PDBs) operações de flashback assim como nos 
Non-Container Database (NCDB’s)no Oracle Database 12c R1 e em todos os database desde que o Oracle Database 11g foi lançado. 
A adição dessa funcionalidade irá agora permitir que os PDB’ssejam “rolledback” em um evento de amplamente difundido de erros de 
manipulação de dados ou um deploy catastrófico de DDLs como uma “cachoeira quebrada”.


Setup do ambiente

Copy
	Copied to Clipboard

	Error: Could not Copy
```
Sistema Operacional:    Oracle Enterprise Linux 6.8 (Santiago)
Database:     Oracle Database 12c R2 (12.2.0.1.0)
Oracle Clusterware:   Oracle Clusterware12c R2 (12.2.0.1.0)
Hostname:     tstldb10,tstldb102
IP addresses:     192.168.0.61, 192.168.0.62
Cluster Name:     TSTLDB01
Container Database (CDB): PRODCDB
Pluggable Database (PDB): PRODPDB
```

Pré-requisitos

Para estesetup, o CDB$ROOT database irá precisar estar em modo ARCHIVELOG.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
[oracle@tstldb101 trace]$ . oraenv
ORACLE_SID = [oracle] ? prodcdb1
The Oracle base remains unchanged with value /u01/app/oracle
[oracle@tstldb101 trace]$sqlplus / as sysdba


SQL*Plus: Release 12.2.0.1.0 Production on Tue Mar 14 00:53:15 2017
Copyright (c) 1982, 2016, Oracle.  All rights reserved.
Connected to:
Oracle Database 12c Enterprise Edition Release 12.2.0.1.0 - 64bit Production


SQL> select log_mode from v$database;


LOG_MODE
-------------------
ARCHIVELOG
```
Crie uma tabela ‘test’ com dados no PRODPDB pluggable database

Aqui iremos criar a tabela TEST com 10 registros com o propósito de mostrar o FLASHBACK em ação.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL> select inst_id,name, open_mode from gv$containers order by 2,1;


INST_ID   NAME                OPEN_MODE
-------------   ----------------    --------------------
1     CDB$ROOT          READ WRITE
2     CDB$ROOT          READ WRITE
1     PDB$SEED          READ ONLY
2     PDB$SEED          READ ONLY
1     PRODPDB           READ WRITE
2     PRODPDB           READ WRITE


6 rows selected.


SQL> alter session set container = PRODPDB;
Sessionaltered.
```

Criando a tabela e carregando os dados

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL> create table test_user.test (id number);
Table created.


SQL> begin
2  fori in 1..10
3  loop
4  insert into test_user.test values (i);
5  end loop;
6  commit;
7  end;
8  /


PL/SQL procedure successfully completed.


SQL> select * from test_user.test;


        ID
----------
         1
         2
         3
         4
         5
         6
         7
         8
         9
        10


10 rows selected.
```

Criar um Guaranteed Restore Point (GRP)

Neste exemplo, iremos criar um guaranteedrestore point (ponto de restauração garantido). 
Apesar do restore point garantido ser um pouco de exagero dado a ociosidade do database test. 
A diferença entre um restore point garantido e um regular é que os flashback logs do restore point garantido não será 
expirados da Flash Recovery Area (FRA) de acordo com seu parâmetro db_flashback_retention_target.

É interessante notar que você não precisa ter flashback habilitado para um CDB para criar PDBsrestore points. 
Se ocorrer de criar um restore point para um PDB enquanto o CBD não está com flashback habilitado, o valor FLASHBACK_ON 
na v$database irá trocar de NO para RESTORE POINT ONLY.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL>  select flashback_on from v$database;


FLASHBACK_ON
--------------------------
NO


SQL> create restore point BEFORE_DML guarantee flashback database;
Restore point created.


SQL> select flashback_on from v$database;


FLASHBACK_ON
----------------------------------
RESTORE POINT ONLY
```

Checando as entradas no Alert log

Copy
	Copied to Clipboard

	Error: Could not Copy
```
When you issue the create restore point command, you will see that the RVWR process is started for the 
CDB and there will be an entry indicating the restore point name and the PDB name that generated the restore point.
Starting background process RVWR
2017-03-14T01:00:08.210974-04:00
RVWR started with pid=60, OS id=437
2017-03-14T01:00:12.721691-04:00
PRODPDB(3):Allocated 15937344 bytes in shared pool for flashback generation buffer
2017-03-14T01:00:25.846052-04:00
PRODPDB(3):Created guaranteed restore point BEFORE_DML
```

Vamos dropar a tabela ‘test’ do pluggable database (PDB)

Vamos causar algum dano a nossa preciosa TEST e eliminar a mesma e purgar o conteúdo da DBA_RECYCLEBIN para uma boa medida.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL> drop table test_user.test;
Table dropped.


SQL> purge dba_recyclebin;
DBA Recyclebinpurged.


Vamos fazer um duplo cheque para ver que os dados se foram consultando a tabela TEST, conforme abaixo: 


SQL> select * from test_user.test;
select * from test_user.test
                        *
ERROR at line 1:
ORA-00942: table or view does not exist
```

Flashback doPluggable Database (PDB)

Agora que temos um drop, irreparável na tabela TEST. Vamos ver se podemos reverter o dano voltando ao restore point feito anterior ao drop da tabela.

Primeiro, nós iremos precisar fechar o pluggable database em todas as instances do nosso cluster.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
[oracle@tstldb101 trace]$ . oraenv
ORACLE_SID = [oracle] ? prodcdb1
The Oracle base remains unchanged with value /u01/app/oracle


[oracle@tstldb101 trace]$sqlplus / as sysdba
SQL*Plus: Release 12.2.0.1.0 Production on Tue Mar 14 01:18:25 2017
Copyright (c) 1982, 2016, Oracle.  All rights reserved.
Connected to:
Oracle Database 12c Enterprise Edition Release 12.2.0.1.0 - 64bit Production


SQL> select inst_id,name, open_mode from gv$containers order by 2,1;


INST_ID   NAME              OPEN_MODE
------------  ------------------  --------------------
1     CDB$ROOT          READ WRITE
2     CDB$ROOT          READ WRITE
1     PDB$SEED          READ ONLY
2     PDB$SEED          READ ONLY
1     PRODPDB           READ WRITE
2     PRODPDB           READ WRITE


6 rows selected.


SQL> alter pluggable database PRODPDB close instances=ALL;
Pluggable database altered.


SQL> select inst_id,name, open_mode from gv$containers order by 2,1;


INST_ID   NAME                OPEN_MODE
-------------   ----------------    --------------------
1     CDB$ROOT          READ WRITE
2     CDB$ROOT          READ WRITE
1     PDB$SEED          READ ONLY
2     PDB$SEED          READ ONLY
1     PRODPDB           MOUNTED
2     PRODPDB           MOUNTED


6 rows selected.
```
Agora que o PDB está fechado, podemos realizar o flashback database nele.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL> flashback pluggable database PRODPDB to restore point BEFORE_DML;
Flashback complete.
```

Checando as entradas no Alert Log

Copy
	Copied to Clipboard

	Error: Could not Copy
```
2017-03-14T01:20:45.900268-04:00
flashback pluggable database PRODPDB to restore point BEFORE_DML
2017-03-14T01:20:47.003048-04:00
Flashback Restore Start
Restore Flashback Pluggable Database PRODPDB (3) until change 1484920
Flashback Restore Complete
Flashback Media Recovery Start
2017-03-14T01:20:48.736628-04:00
Serial Media Recovery started
2017-03-14T01:20:49.049432-04:00
Recovery of Online Redo Log: Thread 1 Group 2 Seq 2 Reading mem 0
  Mem# 0: +DATA/PRODCDB/ONLINELOG/group_2.262.938558255
  Mem# 1: +FRA/PRODCDB/ONLINELOG/group_2.258.938558271
2017-03-14T01:20:49.090049-04:00
Recovery of Online Redo Log: Thread 2 Group 4 Seq 2 Reading mem 0
  Mem# 0: +DATA/PRODCDB/ONLINELOG/group_4.271.938559081
  Mem# 1: +FRA/PRODCDB/ONLINELOG/group_4.260.938559091
2017-03-14T01:20:49.409836-04:00
Incomplete Recovery applied until change 1484920 time 03/14/2017 01:08:25
Flashback Media Recovery Complete
Flashback Pluggable Database PRODPDB (3) recovered until change 1484920
Completed: flashback pluggable database PRODPDB to restore point BEFORE_DML
```
Porque o restore point foi criado

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL> alter pluggable database PRODPDB open instances=ALL;
alter pluggable database PRODPDB open instances=ALL
*
ERROR at line 1:
ORA-65107: Error encountered when processing the current task on instance:1
ORA-01113: file 14 needs media recovery
ORA-01110: data file 14:
'+DATA/PRODCDB/4AA8F71F10B96DB0E0533D00A8C0638A/DATAFILE/users.278.938559493'
```
Como o flashback foi realizado para um restore point criado enquanto o PDB estava em modo READ WRITE, 
iremos precisar abrir o PDB com a opção RESETLOGS e então fazer um novo comando OPEN para abrir o PDB em todas as instances do nosso cluster database.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL> alter pluggable database PRODPDB open resetlogs;
Pluggable database altered.


SQL> alter pluggable database PRODPDB open instances=ALL;
Pluggable database altered.
```

Checando as entradas no Alert

Copy
	Copied to Clipboard

	Error: Could not Copy
```
2017-03-14T01:20:45.900268-04:00
flashback pluggable database PRODPDB to restore point BEFORE_DML
2017-03-14T01:20:47.003048-04:00
Flashback Restore Start
Restore Flashback Pluggable Database PRODPDB (3) until change 1484920
Flashback Restore Complete
Flashback Media Recovery Start
2017-03-14T01:20:48.736628-04:00
Serial Media Recovery started
2017-03-14T01:20:49.049432-04:00
Recovery of Online Redo Log: Thread 1 Group 2 Seq 2 Reading mem 0
  Mem# 0: +DATA/PRODCDB/ONLINELOG/group_2.262.938558255
  Mem# 1: +FRA/PRODCDB/ONLINELOG/group_2.258.938558271
2017-03-14T01:20:49.090049-04:00
Recovery of Online Redo Log: Thread 2 Group 4 Seq 2 Reading mem 0
  Mem# 0: +DATA/PRODCDB/ONLINELOG/group_4.271.938559081
  Mem# 1: +FRA/PRODCDB/ONLINELOG/group_4.260.938559091
2017-03-14T01:20:49.409836-04:00
Incomplete Recovery applied until change 1484920 time 03/14/2017 01:08:25
Flashback Media Recovery Complete
Flashback Pluggable Database PRODPDB (3) recovered until change 1484920
Completed: flashback pluggable database PRODPDB to restore point BEFORE_DML
2017-03-14T01:22:22.628569-04:00
alter pluggable database PRODPDB open instances=ALL
2017-03-14T01:22:22.735406-04:00
PRODPDB(3):Autotune of undo retention is turned on.
2017-03-14T01:22:22.883561-04:00
PRODPDB(3):This instance was first to open pluggable database PRODPDB (container=3)
Pdb PRODPDB hit error 1113 during open read write (1) and will be closed.
2017-03-14T01:22:22.995375-04:00
Errors in file /u01/app/oracle/diag/rdbms/prodcdb/prodcdb1/trace/prodcdb1_ppa7_1957.trc:
ORA-01113: file 14 needs media recovery
ORA-01110: data file 14: '+DATA/PRODCDB/4AA8F71F10B96DB0E0533D00A8C0638A/DATAFILE/users.278.938559493'
PRODPDB(3):JIT: pid 1957 requesting stop
PRODPDB(3):detach called for domid 3 (domuid: 0x41e01c9f, options: 0x10, pid: 1957)
2017-03-14T01:22:23.205075-04:00
Errors in file /u01/app/oracle/diag/rdbms/prodcdb/prodcdb1/trace/prodcdb1_ppa7_1957.trc:
ORA-01113: file 14 needs media recovery
ORA-01110: data file 14: '+DATA/PRODCDB/4AA8F71F10B96DB0E0533D00A8C0638A/DATAFILE/users.278.938559493'
ORA-65107 signalled during: alter pluggable database PRODPDB open instances=ALL...
2017-03-14T01:24:35.278898-04:00
alter pluggable database PRODPDB open resetlogs
2017-03-14T01:24:35.564485-04:00
Online datafile 14
Online datafile 13
Online datafile 12
Online datafile 11
Online datafile 10
PRODPDB(3):Autotune of undo retention is turned on.
PRODPDB(3):This instance was first to open pluggable database PRODPDB (container=3)
PRODPDB(3):attach called for domid 3 (domuid: 0x41e01c9f, options: 0x0, pid: 5746)
PRODPDB(3):queued attach broadcast request 0x78e89368
2017-03-14T01:24:35.935673-04:00
* allocate domain 3, valid ? 1
 all enqueues go to domain 0
2017-03-14T01:24:36.413698-04:00
PRODPDB(3):Endian type of dictionary set to little
2017-03-14T01:24:38.178066-04:00
PRODPDB(3):[5746] Successfully onlined Undo Tablespace 2.
PRODPDB(3):Undo initialization finished serial:0 start:16869251 end:16870398 diff:1147 ms (1.1 seconds)
PRODPDB(3):Database Characterset for PRODPDB is AL32UTF8
PRODPDB(3):JIT: pid 5746 requesting stop
2017-03-14T01:24:39.346088-04:00
PRODPDB(3):detach called for domid 3 (domuid: 0x41e01c9f, options: 0x0, pid: 5746)
PRODPDB(3):queued detach broadcast request 0x78e89310
2017-03-14T01:24:39.452824-04:00
freeing rdom 3
PRODPDB(3):Autotune of undo retention is turned on.
2017-03-14T01:24:40.111054-04:00
PRODPDB(3):This instance was first to open pluggable database PRODPDB (container=3)
2017-03-14T01:24:40.355393-04:00
PRODPDB(3):attach called for domid 3 (domuid: 0x41e01c9f, options: 0x0, pid: 5746)
PRODPDB(3):queued attach broadcast request 0x78e892b8
2017-03-14T01:24:40.394141-04:00
* allocate domain 3, valid ? 1
 all enqueues go to domain 0
2017-03-14T01:24:40.867286-04:00
PRODPDB(3):Endian type of dictionary set to little
2017-03-14T01:24:42.505342-04:00
PRODPDB(3):[5746] Successfully onlined Undo Tablespace 2.
PRODPDB(3):Undo initialization finished serial:0 start:16873543 end:16874610 diff:1067 ms (1.1 seconds)
PRODPDB(3):Pluggable database PRODPDB dictionary check beginning
PRODPDB(3):Pluggable Database PRODPDB Dictionary check complete
PRODPDB(3):Database Characterset for PRODPDB is AL32UTF8
2017-03-14T01:24:44.273160-04:00
PRODPDB(3):Opatch validation is skipped for PDB PRODPDB (con_id=0)
2017-03-14T01:24:47.946543-04:00
PRODPDB(3):Opening pdb with no Resource Manager plan active
2017-03-14T01:24:50.875522-04:00
Starting control autobackup
2017-03-14T01:24:53.590768-04:00
Control autobackup written to DISK device


handle '+FRA/PRODCDB/AUTOBACKUP/2017_03_14/s_938568290.269.938568293'


Pluggable database PRODPDB closed
Completed: alter pluggable database PRODPDB open resetlogs
2017-03-14T01:25:20.369712-04:00
alter pluggable database PRODPDB open instances=ALL
2017-03-14T01:25:28.316750-04:00
Completed: alter pluggable database PRODPDB open instances=ALL
```
Agora que o PDB está online em todas as instances, podemos confirmar se a nossa tabela TEST foi recuperada.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL> alter session set container = PRODPDB;
Session altered.


SQL> select * from test_user.test;


ID
----------
1
2
3
4
5
6
7
8
9
10


10 rowsselected.
```
Successo!!!
  
A tabela TESTestá de volta ao pluggable database.Agora que fizemos a restauração para o RESTORE POINT podemos dropar o mesmo 
e observar o que o Oracle faz em background.

Copy
	Copied to Clipboard

	Error: Could not Copy
```
SQL> drop restore point BEFORE_DML;
Restore point dropped.
```

Checando as entradas no Alert

Copy
	Copied to Clipboard

	Error: Could not Copy
```
2017-03-14T01:35:02.079060-04:00
PRODPDB(3):Drop guaranteed restore point BEFORE_DML
2017-03-14T01:35:02.256528-04:00
RVWR shutting down
2017-03-14T01:35:05.265401-04:00
PRODPDB(3):Deleted Oracle managed file +FRA/PRODCDB/4AA8F71F10B96DB0E0533D00A8C0638A/FLASHBACK/log_1.268.938567291
PRODPDB(3):Deleted Oracle managed file +FRA/PRODCDB/FLASHBACK/log_2.267.938567297
PRODPDB(3):Deleted Oracle managed file +FRA/PRODCDB/FLASHBACK/log_3.266.938567299
PRODPDB(3):Deleted Oracle managed file +FRA/PRODCDB/FLASHBACK/log_4.265.938567307
PRODPDB(3):Guaranteed restore point BEFORE_DML dropped
```
Da saída acima, podemos ver que os flashback logs associados a esterestore point foram eliminados.


Passosprincipais:

- Habilitar o ARCHIVELOG modeno Container Database (CDB)
- Criarum Guaranteed restore point no Pluggable Database (PDB)
- Fecharo Pluggable Database (PDB) em todas as instances
- Flashback do Pluggable Database (PDB) para orestore point
- Abrir oPluggable Database (PDB) coma opção RESETLOGS.

Conclusão

Agora é possível fazer comandos Flashback database paraPluggable Database (PDB’s)no Oracle Database 12c R2. 
Isto diminui drasticamente o custo de se fazer um Point In Time Recovery dos PDB como você não precisa restaurar 
o CDB completamentepara um point in time anterior. O que significa que cada PDB agora é verdadeiramente separado de outro, 
ambos rodando e durante cenários de recuperação (recovery).
