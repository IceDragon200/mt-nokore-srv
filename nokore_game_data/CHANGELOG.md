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
