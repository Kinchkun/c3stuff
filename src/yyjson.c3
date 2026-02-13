module yy;
import std::io;
import std::core::mem;

// Opaque types (internal)
alias YYDoc = void*;

// Val wraps the yyjson_val pointer to enable method syntax
struct Val {
  void* ptr;
}

// C3 allocator bridge functions - called from C
fn void* c3_alloc_malloc(Allocator* alloc, usz size) @extern("c3_alloc_malloc") @export {
  return (*alloc).acquire(size, NO_ZERO, 0) ?? null;
}

fn void* c3_alloc_realloc(Allocator* alloc, void* ptr, usz old_size, usz new_size) @extern("c3_alloc_realloc") @export {
  return (*alloc).resize(ptr, new_size, 0) ?? null;
}

fn void c3_alloc_free(Allocator* alloc, void* ptr) @extern("c3_alloc_free") @export {
  (*alloc).release(ptr, false);
}

// JSON value types
const char TYPE_NONE = 0;
const char TYPE_RAW  = 1;
const char TYPE_NULL = 2;
const char TYPE_BOOL = 3;
const char TYPE_NUM  = 4;
const char TYPE_STR  = 5;
const char TYPE_ARR  = 6;
const char TYPE_OBJ  = 7;

// Read flags
const uint READ_NOFLAG                = 0;
const uint READ_INSITU                = 1 << 0;
const uint READ_STOP_WHEN_DONE        = 1 << 1;
const uint READ_ALLOW_TRAILING_COMMAS = 1 << 2;
const uint READ_ALLOW_COMMENTS        = 1 << 3;
const uint READ_ALLOW_INF_AND_NAN     = 1 << 4;
const uint READ_NUMBER_AS_RAW         = 1 << 5;
const uint READ_ALLOW_INVALID_UNICODE = 1 << 6;
const uint READ_BIGNUM_AS_RAW         = 1 << 7;

// Write flags
const uint WRITE_NOFLAG           = 0;
const uint WRITE_PRETTY           = 1 << 0;
const uint WRITE_ESCAPE_UNICODE   = 1 << 1;
const uint WRITE_ESCAPE_SLASHES   = 1 << 2;
const uint WRITE_ALLOW_INF_AND_NAN = 1 << 3;
const uint WRITE_INF_AND_NAN_AS_NULL = 1 << 4;
const uint WRITE_ALLOW_INVALID_UNICODE = 1 << 5;
const uint WRITE_PRETTY_TWO_SPACES = 1 << 6;

struct ReadErr {
  uint code;
  ZString msg;
  usz pos;
}

struct ArrIter {
  usz idx;
  usz max;
  void* cur;
}

struct ObjIter {
  usz idx;
  usz max;
  void* cur;
  void* obj;
}

// Internal extern functions
extern fn YYDoc yy_read(char* dat, usz len, uint flg) @extern("c3_yyjson_read") @private;
extern fn YYDoc yy_read_with_alloc(char* dat, usz len, uint flg, Allocator* alloc) @extern("c3_yyjson_read_with_alloc") @private;
extern fn void yy_doc_free(YYDoc doc) @extern("c3_yyjson_doc_free") @private;
extern fn void* yy_doc_get_root(YYDoc doc) @extern("c3_yyjson_doc_get_root") @private;

// Type checking externs
extern fn bool yy_is_null(void* val) @extern("c3_yyjson_is_null") @private;
extern fn bool yy_is_bool(void* val) @extern("c3_yyjson_is_bool") @private;
extern fn bool yy_is_int(void* val) @extern("c3_yyjson_is_int") @private;
extern fn bool yy_is_real(void* val) @extern("c3_yyjson_is_real") @private;
extern fn bool yy_is_num(void* val) @extern("c3_yyjson_is_num") @private;
extern fn bool yy_is_str(void* val) @extern("c3_yyjson_is_str") @private;
extern fn bool yy_is_arr(void* val) @extern("c3_yyjson_is_arr") @private;
extern fn bool yy_is_obj(void* val) @extern("c3_yyjson_is_obj") @private;

// Value getter externs
extern fn bool yy_get_bool(void* val) @extern("c3_yyjson_get_bool") @private;
extern fn ulong yy_get_uint(void* val) @extern("c3_yyjson_get_uint") @private;
extern fn long yy_get_sint(void* val) @extern("c3_yyjson_get_sint") @private;
extern fn double yy_get_real(void* val) @extern("c3_yyjson_get_real") @private;
extern fn double yy_get_num(void* val) @extern("c3_yyjson_get_num") @private;
extern fn ZString yy_get_str(void* val) @extern("c3_yyjson_get_str") @private;
extern fn usz yy_get_len(void* val) @extern("c3_yyjson_get_len") @private;

// Array externs
extern fn usz yy_arr_size(void* arr) @extern("c3_yyjson_arr_size") @private;
extern fn void* yy_arr_get(void* arr, usz idx) @extern("c3_yyjson_arr_get") @private;
extern fn ArrIter yy_arr_iter_with(void* arr) @extern("c3_yyjson_arr_iter_with") @private;
extern fn bool yy_arr_iter_has_next(ArrIter* iter) @extern("c3_yyjson_arr_iter_has_next") @private;
extern fn void* yy_arr_iter_next(ArrIter* iter) @extern("c3_yyjson_arr_iter_next") @private;

// Object externs
extern fn usz yy_obj_size(void* obj) @extern("c3_yyjson_obj_size") @private;
extern fn void* yy_obj_get(void* obj, ZString key) @extern("c3_yyjson_obj_get") @private;
extern fn ObjIter yy_obj_iter_with(void* obj) @extern("c3_yyjson_obj_iter_with") @private;
extern fn bool yy_obj_iter_has_next(ObjIter* iter) @extern("c3_yyjson_obj_iter_has_next") @private;
extern fn void* yy_obj_iter_next(ObjIter* iter) @extern("c3_yyjson_obj_iter_next") @private;
extern fn void* yy_obj_iter_get_val(void* key) @extern("c3_yyjson_obj_iter_get_val") @private;

// Write externs
extern fn ZString yy_val_write(void* val, uint flg, usz* len) @extern("c3_yyjson_val_write") @private;
extern fn void libc_free(void* ptr) @extern("free") @private;

// =============================================================================
// Val methods - Type checking
// =============================================================================

fn bool Val.is_null(self)   => yy_is_null(self.ptr);
fn bool Val.is_bool(self)   => yy_is_bool(self.ptr);
fn bool Val.is_int(self)    => yy_is_int(self.ptr);
fn bool Val.is_real(self)   => yy_is_real(self.ptr);
fn bool Val.is_num(self)    => yy_is_num(self.ptr);
fn bool Val.is_str(self)    => yy_is_str(self.ptr);
fn bool Val.is_arr(self)    => yy_is_arr(self.ptr);
fn bool Val.is_obj(self)    => yy_is_obj(self.ptr);

// =============================================================================
// Val methods - Value getters (safe, return optionals)
// =============================================================================

fn bool? Val.get_bool(self) {
  if (!yy_is_bool(self.ptr)) return NOT_A_BOOL~;
  return yy_get_bool(self.ptr);
}

fn ulong? Val.get_uint(self) {
  if (!yy_is_num(self.ptr)) return NOT_A_NUMBER~;
  return yy_get_uint(self.ptr);
}

fn long? Val.get_int(self) {
  if (!yy_is_num(self.ptr)) return NOT_A_NUMBER~;
  return yy_get_sint(self.ptr);
}

fn double? Val.get_real(self) {
  if (!yy_is_num(self.ptr)) return NOT_A_NUMBER~;
  return yy_get_real(self.ptr);
}

fn double? Val.get_num(self) {
  if (!yy_is_num(self.ptr)) return NOT_A_NUMBER~;
  return yy_get_num(self.ptr);
}

fn ZString? Val.str(self) {
  if (!yy_is_str(self.ptr)) return NOT_A_STRING~;
  return yy_get_str(self.ptr);
}

fn usz Val.len(self) => yy_get_len(self.ptr);

// =============================================================================
// Val methods - Object access
// =============================================================================

// Get object property by key (safe, returns fault if not found)
fn Val? Val.get(self, ZString key) {
  if (!yy_is_obj(self.ptr)) return NOT_AN_OBJECT~;
  void* result = yy_obj_get(self.ptr, key);
  if (result == null) return NO_SUCH_PROPERTY~;
  return { .ptr = result };
}

// Get object size (number of key-value pairs)
fn usz Val.obj_size(self) => yy_obj_size(self.ptr);

// Get object iterator
fn ObjIter Val.obj_iter(self) => yy_obj_iter_with(self.ptr);

// =============================================================================
// Val methods - Array access
// =============================================================================

// Get array element by index (safe, returns fault if out of bounds)
fn Val? Val.at(self, usz idx) {
  if (!yy_is_arr(self.ptr)) return NOT_AN_ARRAY~;
  if (idx >= yy_arr_size(self.ptr)) return INDEX_OUT_OF_BOUNDS~;
  return { .ptr = yy_arr_get(self.ptr, idx) };
}

// [] operator for array access - keeps foreach working
// Note: Use .at() for bounds-checked access
fn Val Val.get_at(self, usz idx) @operator([]) {
  return { .ptr = yy_arr_get(self.ptr, idx) };
}

// Get array size (also enables posts[^1] reverse indexing)
fn usz Val.arr_size(self) @operator(len) => yy_arr_size(self.ptr);

// Get array iterator
fn ArrIter Val.arr_iter(self) => yy_arr_iter_with(self.ptr);

// =============================================================================
// Iterator methods
// =============================================================================

fn bool ArrIter.has_next(&self) => yy_arr_iter_has_next(self);
fn Val ArrIter.next(&self) => { .ptr = yy_arr_iter_next(self) };

fn bool ObjIter.has_next(&self) => yy_obj_iter_has_next(self);
fn Val ObjIter.next(&self) => { .ptr = yy_obj_iter_next(self) };
fn Val Val.get_val(self) => { .ptr = yy_obj_iter_get_val(self.ptr) };

// =============================================================================
// Pretty printing
// =============================================================================

struct Pretty (Printable) {
  Val val;
}

fn Pretty Val.pretty(self) => { .val = self };

fn usz? Pretty.to_format(&self, Formatter* f) @dynamic {
  usz len;
  ZString json = yy_val_write(self.val.ptr, WRITE_PRETTY, &len);
  if (json == null) return 0;
  defer libc_free(json);
  return f.print((String)json[:len]);
}

// =============================================================================
// Parsing
// =============================================================================

// Parse JSON string, returns root Val
// When using allocator (e.g. arena), memory is managed by the allocator
fn Val? parse(String json, Allocator allocator) {
  YYDoc doc = yy_read_with_alloc(json.ptr, json.len, READ_NOFLAG, &allocator);
  if (doc == null) return PARSE_ERROR~;
  return { .ptr = yy_doc_get_root(doc) };
}

// Parse directly from a ByteWriter (efficient, no copy)
fn Val? parse_bytes(io::ByteWriter* writer, Allocator allocator) {
  char[] data = writer.array_view();
  YYDoc doc = yy_read_with_alloc(data.ptr, data.len, READ_NOFLAG, &allocator);
  if (doc == null) return PARSE_ERROR~;
  return { .ptr = yy_doc_get_root(doc) };
}

// =============================================================================
// Faults
// =============================================================================

faultdef PARSE_ERROR;
faultdef INDEX_OUT_OF_BOUNDS;
faultdef NO_SUCH_PROPERTY;
faultdef NOT_A_STRING;
faultdef NOT_A_NUMBER;
faultdef NOT_A_BOOL;
faultdef NOT_AN_ARRAY;
faultdef NOT_AN_OBJECT;
