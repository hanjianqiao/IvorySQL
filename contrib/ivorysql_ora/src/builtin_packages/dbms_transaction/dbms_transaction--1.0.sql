/*-------------------------------------------------------------------------
 * Copyright 2026 IvorySQL Global Development Team
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * dbms_transaction--1.0.sql
 *
 * Oracle-compatible DBMS_TRANSACTION package.
 *
 * COMMIT/ROLLBACK reuse PL/iSQL's native COMMIT/ROLLBACK statements (only
 * valid when the package procedure is invoked as a top-level CALL, exactly
 * like a bare COMMIT/ROLLBACK would be).  SAVEPOINT/ROLLBACK_SAVEPOINT call
 * into a small C bridge (dbms_transaction.c) that reaches directly into
 * PostgreSQL's DefineSavepoint()/RollbackToSavepoint(), since PL/iSQL has no
 * native savepoint statement.  READ_ONLY/READ_WRITE and the metadata readers
 * are thin wrappers around existing SQL facilities.
 *
 * The distributed-transaction recovery subprograms (ADVISE_*, COMMIT_FORCE,
 * ROLLBACK_FORCE, COMMIT_COMMENT, PURGE_LOST_DB_ENTRY, PURGE_MIXED) exist in
 * the package spec for script compatibility but always raise an error:
 * IvorySQL has no equivalent of Oracle's two-phase-commit-over-dblink
 * recovery machinery (DBA_2PC_PENDING / RECO).  Applications that need
 * distributed transaction recovery should use PostgreSQL's native
 * PREPARE TRANSACTION / COMMIT PREPARED / ROLLBACK PREPARED and
 * pg_prepared_xacts instead.
 *
 * contrib/ivorysql_ora/src/builtin_packages/dbms_transaction/dbms_transaction--1.0.sql
 *
 *-------------------------------------------------------------------------
 */

-- Register C functions for the named-savepoint operations
CREATE FUNCTION sys.ora_dbms_transaction_savepoint(name TEXT)
RETURNS VOID
AS 'MODULE_PATHNAME', 'ora_dbms_transaction_savepoint'
LANGUAGE C VOLATILE;

CREATE FUNCTION sys.ora_dbms_transaction_rollback_savepoint(name TEXT)
RETURNS VOID
AS 'MODULE_PATHNAME', 'ora_dbms_transaction_rollback_savepoint'
LANGUAGE C VOLATILE;

CREATE OR REPLACE PACKAGE dbms_transaction IS

    PROCEDURE commit(comment IN VARCHAR2 DEFAULT NULL);
    PROCEDURE rollback;
    PROCEDURE savepoint(sp IN VARCHAR2);
    PROCEDURE rollback_savepoint(sp IN VARCHAR2);

    PROCEDURE read_only;
    PROCEDURE read_write;
    FUNCTION isolation_level RETURN VARCHAR2;
    FUNCTION local_transaction_id(create_transaction IN BOOLEAN DEFAULT FALSE) RETURN VARCHAR2;

    -- Legacy no-ops: Oracle itself documents these as having no effect in
    -- current releases (discrete-transaction hint / explicit rollback
    -- segments, both obsoleted by automatic undo management).
    PROCEDURE begin_discrete_transaction;
    PROCEDURE use_rollback_segment(rollback_segment IN VARCHAR2);

    -- Distributed transaction (two-phase commit) recovery: not supported.
    PROCEDURE commit_force(xid IN VARCHAR2, scn IN NUMBER DEFAULT NULL);
    PROCEDURE rollback_force(xid IN VARCHAR2);
    PROCEDURE commit_comment(cmnt IN VARCHAR2);
    PROCEDURE purge_lost_db_entry(xid IN VARCHAR2);
    PROCEDURE purge_mixed(xid IN VARCHAR2);
    PROCEDURE advise_commit(xid IN VARCHAR2);
    PROCEDURE advise_rollback(xid IN VARCHAR2);
    PROCEDURE advise_nothing(xid IN VARCHAR2);

END dbms_transaction;

CREATE OR REPLACE PACKAGE BODY dbms_transaction IS

    PROCEDURE commit(comment IN VARCHAR2 DEFAULT NULL) IS
    BEGIN
        COMMIT;
    END;

    PROCEDURE rollback IS
    BEGIN
        ROLLBACK;
    END;

    PROCEDURE savepoint(sp IN VARCHAR2) IS
    BEGIN
        PERFORM sys.ora_dbms_transaction_savepoint(sp);
    END;

    PROCEDURE rollback_savepoint(sp IN VARCHAR2) IS
    BEGIN
        PERFORM sys.ora_dbms_transaction_rollback_savepoint(sp);
    END;

    PROCEDURE read_only IS
    BEGIN
        EXECUTE 'SET TRANSACTION READ ONLY';
    END;

    PROCEDURE read_write IS
    BEGIN
        EXECUTE 'SET TRANSACTION READ WRITE';
    END;

    FUNCTION isolation_level RETURN VARCHAR2 IS
        lvl VARCHAR2(32);
    BEGIN
        SELECT upper(current_setting('transaction_isolation')) INTO lvl;
        RETURN lvl;
    END;

    FUNCTION local_transaction_id(create_transaction IN BOOLEAN DEFAULT FALSE) RETURN VARCHAR2 IS
        xid_text VARCHAR2(32);
    BEGIN
        IF create_transaction THEN
            SELECT pg_current_xact_id()::text INTO xid_text;
        ELSE
            SELECT pg_current_xact_id_if_assigned()::text INTO xid_text;
        END IF;
        RETURN xid_text;
    END;

    PROCEDURE begin_discrete_transaction IS
    BEGIN
        NULL;
    END;

    PROCEDURE use_rollback_segment(rollback_segment IN VARCHAR2) IS
    BEGIN
        NULL;
    END;

    PROCEDURE commit_force(xid IN VARCHAR2, scn IN NUMBER DEFAULT NULL) IS
    BEGIN
        RAISE EXCEPTION 'DBMS_TRANSACTION.COMMIT_FORCE is not supported by IvorySQL; use PostgreSQL''s native COMMIT PREPARED instead'
            USING ERRCODE = 'feature_not_supported';
    END;

    PROCEDURE rollback_force(xid IN VARCHAR2) IS
    BEGIN
        RAISE EXCEPTION 'DBMS_TRANSACTION.ROLLBACK_FORCE is not supported by IvorySQL; use PostgreSQL''s native ROLLBACK PREPARED instead'
            USING ERRCODE = 'feature_not_supported';
    END;

    PROCEDURE commit_comment(cmnt IN VARCHAR2) IS
    BEGIN
        RAISE EXCEPTION 'DBMS_TRANSACTION.COMMIT_COMMENT is not supported by IvorySQL'
            USING ERRCODE = 'feature_not_supported';
    END;

    PROCEDURE purge_lost_db_entry(xid IN VARCHAR2) IS
    BEGIN
        RAISE EXCEPTION 'DBMS_TRANSACTION.PURGE_LOST_DB_ENTRY is not supported by IvorySQL; see pg_prepared_xacts instead'
            USING ERRCODE = 'feature_not_supported';
    END;

    PROCEDURE purge_mixed(xid IN VARCHAR2) IS
    BEGIN
        RAISE EXCEPTION 'DBMS_TRANSACTION.PURGE_MIXED is not supported by IvorySQL; see pg_prepared_xacts instead'
            USING ERRCODE = 'feature_not_supported';
    END;

    PROCEDURE advise_commit(xid IN VARCHAR2) IS
    BEGIN
        RAISE EXCEPTION 'DBMS_TRANSACTION.ADVISE_COMMIT is not supported by IvorySQL'
            USING ERRCODE = 'feature_not_supported';
    END;

    PROCEDURE advise_rollback(xid IN VARCHAR2) IS
    BEGIN
        RAISE EXCEPTION 'DBMS_TRANSACTION.ADVISE_ROLLBACK is not supported by IvorySQL'
            USING ERRCODE = 'feature_not_supported';
    END;

    PROCEDURE advise_nothing(xid IN VARCHAR2) IS
    BEGIN
        RAISE EXCEPTION 'DBMS_TRANSACTION.ADVISE_NOTHING is not supported by IvorySQL'
            USING ERRCODE = 'feature_not_supported';
    END;

END dbms_transaction;
