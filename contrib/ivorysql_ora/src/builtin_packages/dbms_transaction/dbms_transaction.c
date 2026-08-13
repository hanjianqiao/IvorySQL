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
 * Implementation of Oracle's DBMS_TRANSACTION package (savepoint subset).
 * This module is part of ivorysql_ora extension.
 *
 * COMMIT, ROLLBACK, READ ONLY/READ WRITE and the metadata readers are plain
 * PL/iSQL wrappers (see dbms_transaction--1.0.sql) around statements the
 * language already supports natively.  Only the named-savepoint operations
 * need a C-level bridge, because PL/iSQL has no SAVEPOINT/ROLLBACK TO
 * SAVEPOINT statement of its own.
 *
 * These bridge functions call DefineSavepoint()/RollbackToSavepoint()
 * (declared in access/xact.h) directly rather than going through SPI.
 * Unlike SPI_commit()/SPI_rollback(), a savepoint operation never
 * terminates the current top-level transaction -- it only marks the
 * transaction state so a subtransaction is started/ended when control
 * returns to CommitTransactionCommand() at the end of the current
 * top-level command, exactly as happens for a plain SQL SAVEPOINT /
 * ROLLBACK TO SAVEPOINT statement.  That means none of SPI's machinery
 * (connection stack, atomic-context checks, the PG_TRY/
 * StartTransactionCommand dance SPI_commit()/SPI_rollback() need) is
 * relevant here, so there is nothing to gain from routing through SPI --
 * standard_ProcessUtility() calls these same xact.c functions directly
 * for a plain SQL SAVEPOINT statement, and this bridge does the same.
 *
 * Portions Copyright (c) 2025-2026, IvorySQL Global Development Team
 *
 * contrib/ivorysql_ora/src/builtin_packages/dbms_transaction/dbms_transaction.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "access/xact.h"
#include "fmgr.h"
#include "utils/builtins.h"

/*
 * Oracle limits a savepoint identifier to 30 bytes; we are more generous but
 * still reject absurdly long names up front rather than let them flow into
 * TopTransactionContext-allocated savepoint bookkeeping.
 */
#define DBMS_TRANSACTION_SAVEPOINT_NAME_LEN	256

PG_FUNCTION_INFO_V1(ora_dbms_transaction_savepoint);
PG_FUNCTION_INFO_V1(ora_dbms_transaction_rollback_savepoint);

static char *
get_savepoint_name(FunctionCallInfo fcinfo)
{
	char	   *name;

	if (PG_ARGISNULL(0))
		ereport(ERROR,
				(errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
				 errmsg("DBMS_TRANSACTION savepoint name must not be NULL")));

	name = text_to_cstring(PG_GETARG_TEXT_PP(0));

	if (strlen(name) >= DBMS_TRANSACTION_SAVEPOINT_NAME_LEN)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("DBMS_TRANSACTION savepoint name too long (max %d bytes)",
						DBMS_TRANSACTION_SAVEPOINT_NAME_LEN - 1)));

	return name;
}

/*
 * DBMS_TRANSACTION.SAVEPOINT(name)
 *
 * Establishes a named savepoint in the current transaction.  Requires an
 * explicit transaction block to already be open, same as a bare SQL
 * SAVEPOINT statement -- unlike COMMIT/ROLLBACK, this has nothing to do
 * with atomic vs. non-atomic CALL context.
 */
Datum
ora_dbms_transaction_savepoint(PG_FUNCTION_ARGS)
{
	char	   *name = get_savepoint_name(fcinfo);

	RequireTransactionBlock(true, "SAVEPOINT");
	DefineSavepoint(name);

	PG_RETURN_VOID();
}

/*
 * DBMS_TRANSACTION.ROLLBACK_SAVEPOINT(name)
 *
 * Rolls back to a previously established savepoint without ending the
 * transaction.
 */
Datum
ora_dbms_transaction_rollback_savepoint(PG_FUNCTION_ARGS)
{
	char	   *name = get_savepoint_name(fcinfo);

	RollbackToSavepoint(name);

	PG_RETURN_VOID();
}
