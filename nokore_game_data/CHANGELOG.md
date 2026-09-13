# 0.12.0

0.12.0 introduces richer utility functions for some simple data structures atop the key-value store.

This is mostly to restore functionality that was removed during the optimization of the KVStore in 0.11.0 where `dirty` had to be marked externally by callers working with nested structures.

These new utility functions are useful for a single layer of indirection, if a caller must modify a sub structure within a key, then the old manual marking method is recommended.

* Added `KVStore#table_init/1`
* Added `KVStore#dset_insert/2`
* Added `KVStore#dset_remove/2`
* Added `KVStore#dset_pop/1`
* Added `KVStore#dset_pop_at/2`
* Added `KVStore#dset_has_value/2`
* Added `KVStore#dset_get/2`
* Added `KVStore#darray_insert/3`
* Added `KVStore#darray_remove/2`
* Added `KVStore#darray_push/2`
* Added `KVStore#darray_delete/2`
* Added `KVStore#darray_pop_at/2`
* Added `KVStore#darray_pop/1`
* Added `KVStore#darray_has_value/2`
* Added `KVStore#darray_get/2`
* Added `KVStore#dmap_put/3`
* Added `KVStore#dmap_put_lazy/3`
* Added `KVStore#dmap_put_new/3`
* Added `KVStore#dmap_put_new_lazy/3`
* Added `KVStore#dmap_delete/2`
* Added `KVStore#dmap_get/2`

# 0.11.0

* Optimize `put`, `put_all`, `upsert_lazy`, `update_lazy` and `delete` to only mark dirty if the value actually changes, this does have a new problem however, callers that were modifying tables and putting them back will need to explicitly mark the kv_store as dirty.

# 0.10.0

* Updated KVStore to utilize update foundation_binary, marshalling is now done with V2 vs V1, and is NOT backwards compatible once updated, V1 stores can still be read and will continuing being readable for the future, but newly persisted stores will use the V2 format.

# 0.9.0

* Changed `KVStore#increment/2` and `KVStore#decrement/2` return values, they now return the value and self instead of just self
* Fixed `KVStore#increment/2` and `KVStore#decrement/2` not marking store as dirty

# 0.8.0

* Added `KVStore#clear_dirty/0`

# 0.7.0

* Added `KVStore#put_all/1`
