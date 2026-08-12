--
-- dbms_transaction.sql
--
-- tests for DBMS_TRANSACTION:
--   COMMIT / ROLLBACK, SAVEPOINT / ROLLBACK_SAVEPOINT,
--   READ_ONLY / READ_WRITE, ISOLATION_LEVEL, LOCAL_TRANSACTION_ID,
--   legacy no-ops, and the documented-unsupported distributed
--   transaction recovery subprograms.
--

create table dbms_tx_t (id int, val varchar2(100));

--
-- COMMIT / ROLLBACK: valid only when the package procedure is invoked as a
-- top-level CALL (non-atomic context) -- same restriction as a bare
-- COMMIT/ROLLBACK statement inside a PL/iSQL procedure.
-- AUTOCOMMIT is default ON in PG
--
insert into dbms_tx_t values (1, 'committed');
call dbms_transaction.commit();
select * from dbms_tx_t order by id;

insert into dbms_tx_t values (2, 'rolled back');
call dbms_transaction.rollback();
select * from dbms_tx_t order by id;

BEGIN
    insert into dbms_tx_t values (3, 'committed');
    dbms_transaction.commit();
    insert into dbms_tx_t values (4, 'rolled back');
    dbms_transaction.rollback();
END;
/
select * from dbms_tx_t order by id;

--
-- SAVEPOINT / ROLLBACK_SAVEPOINT: unlike COMMIT/ROLLBACK, these require an
-- explicit transaction block, same as a bare SQL SAVEPOINT statement.
--
call dbms_transaction.savepoint('sp_outside');

-- PG starts transactions explicitly while Oracle starts transactions implicityly
BEGIN;
    insert into dbms_tx_t values (5, 'before sp1');
    call dbms_transaction.savepoint('sp1');
    insert into dbms_tx_t values (6, 'after sp1, will be rolled back');
    call dbms_transaction.rollback_savepoint('sp1');
    insert into dbms_tx_t values (7, 'after rollback to sp1');
COMMIT;
select * from dbms_tx_t order by id;

-- nested savepoints: rolling back to the outer one undoes both
BEGIN;
    call dbms_transaction.savepoint('a');
    insert into dbms_tx_t values (8, 'a');
    call dbms_transaction.savepoint('b');
    insert into dbms_tx_t values (9, 'b');
    call dbms_transaction.rollback_savepoint('a');
    insert into dbms_tx_t values (10, 'after rollback to a');
COMMIT;
select * from dbms_tx_t order by id;

-- rollback to a savepoint that does not exist

BEGIN;
    call dbms_transaction.savepoint('a');
    insert into dbms_tx_t values (8, 'a');
    call dbms_transaction.savepoint('b');
    insert into dbms_tx_t values (9, 'b');
    call dbms_transaction.rollback_savepoint('a');
    insert into dbms_tx_t values (10, 'after rollback to a');
    call dbms_transaction.rollback_savepoint('b');
COMMIT;
select * from dbms_tx_t order by id;

BEGIN;
    call dbms_transaction.rollback_savepoint('does_not_exist');
ROLLBACK;

--
-- READ_ONLY / READ_WRITE
--
BEGIN;
    call dbms_transaction.read_only();
    insert into dbms_tx_t values (11, 'blocked by read only');
ROLLBACK;

-- READ_WRITE as the first statement of a transaction is a no-op that must
-- not block subsequent writes.  (Switching a transaction back from read-only
-- to read-write after another statement has already run is a PostgreSQL
-- restriction -- "transaction read-write mode must be set before any
-- query" -- so that sequence is intentionally not exercised here.)
BEGIN;
    call dbms_transaction.read_write();
    insert into dbms_tx_t values (12, 'allowed with read_write');
COMMIT;
select * from dbms_tx_t where id = 12;

--
-- ISOLATION_LEVEL / LOCAL_TRANSACTION_ID
--
select dbms_transaction.isolation_level() from dual;

BEGIN isolation level serializable;
    select dbms_transaction.isolation_level() from dual;
COMMIT;

-- REPEATABLE READ has no Oracle equivalent: Oracle recognizes only READ
-- COMMITTED and SERIALIZABLE as transaction isolation levels, so this
-- particular level/result would never be seen against a real Oracle
-- database.  IvorySQL just passes the PostgreSQL isolation level name
-- straight through.
BEGIN isolation level repeatable read;
    select dbms_transaction.isolation_level() from dual;
COMMIT;

select dbms_transaction.local_transaction_id() is null as no_xid_without_create from dual;

BEGIN;
    select dbms_transaction.local_transaction_id(true) is not null as xid_created from dual;
    select dbms_transaction.local_transaction_id() is not null as xid_now_visible from dual;
    -- calling again with create_transaction=true on an already-assigned
    -- transaction just returns the existing id, it does not assign a new one
    select dbms_transaction.local_transaction_id(true) = dbms_transaction.local_transaction_id() as xid_stable from dual;
COMMIT;

-- the transaction (and its id) ends with the commit above -- a fresh
-- transaction has no id again until something assigns one
select dbms_transaction.local_transaction_id() is null as no_xid_in_new_transaction from dual;



--
-- Legacy no-ops
--
call dbms_transaction.begin_discrete_transaction();
call dbms_transaction.use_rollback_segment('rbs1');

--
-- Distributed-transaction recovery subprograms: documented as unsupported
--
call dbms_transaction.commit_force('1.2.3');
call dbms_transaction.rollback_force('1.2.3');
call dbms_transaction.commit_comment('c');
call dbms_transaction.purge_lost_db_entry('1.2.3');
call dbms_transaction.purge_mixed('1.2.3');
call dbms_transaction.advise_commit('1.2.3');
call dbms_transaction.advise_rollback('1.2.3');
call dbms_transaction.advise_nothing('1.2.3');

drop table dbms_tx_t;
