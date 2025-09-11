# SAVEPOINT Implementation Summary

This document summarizes the implementation of SAVEPOINT functionality in Red ORM to address issue #575.

## Problem Solved

Previously, nested transactions in Red created new database connections, which led to isolation issues where changes made in the outer transaction were not visible to the inner transaction. This caused problems in complex transaction scenarios.

## Solution Overview

The implementation introduces SAVEPOINT support that:

1. **Uses the same connection**: All nested transactions use savepoints on the same underlying database connection
2. **Maintains API compatibility**: Existing code continues to work without changes
3. **Adds manual control**: Developers can create and manage named savepoints directly

## Files Modified/Added

### New AST Classes
- `lib/Red/AST/Savepoint.rakumod` - AST for SAVEPOINT statements
- `lib/Red/AST/RollbackToSavepoint.rakumod` - AST for ROLLBACK TO SAVEPOINT statements  
- `lib/Red/AST/ReleaseSavepoint.rakumod` - AST for RELEASE SAVEPOINT statements

### Core Implementation
- `lib/Red/Driver/TransactionContext.rakumod` - Transaction context wrapper for savepoint management
- `lib/Red/Driver.rakumod` - Updated base driver role with savepoint methods
- `lib/Red/Driver/CommonSQL.rakumod` - SQL translation for savepoint operations
- `lib/Red/Driver/SQLite.rakumod` - SQLite-specific syntax overrides

### Tests and Documentation
- `t/90-savepoints.rakutest` - Comprehensive test suite for savepoint functionality
- `t/91-savepoints-basic.rakutest` - Basic functionality tests
- `docs/savepoints.pod6` - User documentation
- `examples/savepoint-demo.raku` - Example usage

## Architecture

### TransactionContext Pattern

The core innovation is the `TransactionContext` class that:

1. **Wraps the parent driver**: Acts as a proxy to the real database connection
2. **Tracks nesting level**: Knows whether it's the main transaction or a savepoint
3. **Manages savepoint names**: Automatically generates names like "sp2", "sp3" for nested levels
4. **Delegates methods**: All driver methods are forwarded to the parent connection
5. **Handles promises**: Maintains promises for coordination between levels

### SQL Generation

The implementation supports different SQL dialects:

```sql
-- PostgreSQL/MySQL Standard
SAVEPOINT sp1;
ROLLBACK TO SAVEPOINT sp1;
RELEASE SAVEPOINT sp1;

-- SQLite Simplified
SAVEPOINT sp1;
ROLLBACK TO sp1;
RELEASE sp1;
```

### Method Flow

1. `$driver.begin()` → Creates `TransactionContext(level=1)` and executes `BEGIN`
2. `$tx.begin()` → Creates `TransactionContext(level=2, name="sp2")` and executes `SAVEPOINT sp2`
3. `$tx.commit()` → Executes `RELEASE SAVEPOINT sp2` or `COMMIT` depending on level
4. `$tx.rollback()` → Executes `ROLLBACK TO SAVEPOINT sp2` or `ROLLBACK` depending on level

## Key Design Decisions

### 1. API Compatibility
- `begin()` still returns a different object (TransactionContext instead of new connection)
- All existing driver methods are available through delegation
- FALLBACK method ensures any missing methods are forwarded

### 2. Automatic vs Manual
- Automatic: Nested `begin()` calls use savepoints transparently
- Manual: `savepoint()`, `rollback-to-savepoint()`, `release-savepoint()` methods for direct control

### 3. Promise Coordination
- Each transaction context maintains a Promise
- Helps coordinate cleanup between different nesting levels
- Allows for future enhancements like waiting on nested operations

### 4. Database Compatibility
- Standard SQL SAVEPOINT syntax for PostgreSQL and MySQL
- SQLite-specific overrides for its simpler syntax
- Easily extensible for other databases

## Benefits

1. **Solves Isolation Issues**: Outer transaction changes are visible to inner transactions
2. **Performance**: No connection overhead for nested transactions
3. **Correctness**: Proper transaction semantics across nesting levels
4. **Flexibility**: Both automatic and manual savepoint management
5. **Compatibility**: Works with existing Red transaction code

## Future Enhancements

Potential improvements that could build on this foundation:

1. **Named Transaction Blocks**: Allow developers to name transaction levels
2. **Rollback Retry Logic**: Automatic retry of operations after savepoint rollbacks
3. **Transaction Metrics**: Tracking of savepoint usage and nesting depth
4. **Deadlock Detection**: Enhanced handling of database deadlocks with savepoints
5. **Async Coordination**: Better integration with async/await patterns

## Testing

The implementation includes comprehensive tests covering:

- Basic savepoint SQL generation
- Nested transaction scenarios
- Manual savepoint operations
- Transaction isolation behavior
- API compatibility

Run tests with: `prove6 -lv t/90-savepoints.rakutest t/91-savepoints-basic.rakutest`

## Maintenance Notes

- The TransactionContext class delegates all methods to maintain compatibility
- SQL translation is handled in the driver hierarchy (CommonSQL → specific drivers)
- New database drivers need to implement savepoint translation methods
- Tests should be updated when adding new transaction-related features