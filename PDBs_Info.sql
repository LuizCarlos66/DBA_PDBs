set linesize 150
col name format a20
col open_time format a35
select con_id, name, open_mode, open_time
--   , round(total_size/1048567,0) Tamanho_Mb
   , round(total_size/1073741824,0) Tamanho_Gb
, creation_time
from v$pdbs;

---
Check startup time of PDB database


col name for a8
col open_time for a33
select con_id,name,dbid,open_mode,open_time from v$containers;

---
Check uptime of PDB database

col name for a12
col "database uptime" for a30
select name
     , floor(sysdate-cast(open_time as date))||'Days ' || 
       floor(((sysdate-cast(open_time as date))-floor(sysdate-cast(open_time as date)))*24) || 'hours ' || 
       round(((sysdate-cast(open_time as date)-floor(sysdate-cast(open_time as date) )*24)-floor((sysdate-cast(open_time as date)-floor(sysdate-cast(open_time as date))*24)))*60) || 'minutes' "Database Uptime" 
from v$containers;

---
Check creation time and status of PDBS

col pdb_name for a12
select pdb_name
     , creation_time
     , status 
from dba_pdbs;

---
Check size of PDBS

col name for a12
select name
     , open_mode
     , restricted
     , creation_time
     , Round(total_size / 1048576,0) total_size_Mb
from v$PDBS;
