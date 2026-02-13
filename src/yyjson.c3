module yyjson;
import std::io;
import std::core::mem;

// Opaque types (internal)
alias YYDoc = void*;
alias Val = void*;

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
  Val cur;
}

struct ObjIter {
  usz idx;
  usz max;
  Val cur;
  Val obj;
}

// Internal document functions
extern fn YYDoc yy_read(char* dat, usz len, uint flg) @extern("c3_yyjson_read") @private;
extern fn YYDoc yy_read_with_alloc(char* dat, usz len, uint flg, Allocator* alloc) @extern("c3_yyjson_read_with_alloc") @private;
extern fn void yy_doc_free(YYDoc doc) @extern("c3_yyjson_doc_free") @private;
extern fn Val yy_doc_get_root(YYDoc doc) @extern("c3_yyjson_doc_get_root") @private;

// Type checking (using wrappers)
extern fn bool is_null(Val val) @extern("c3_yyjson_is_null");
extern fn bool is_bool(Val val) @extern("c3_yyjson_is_bool");
extern fn bool is_int(Val val) @extern("c3_yyjson_is_int");
extern fn bool is_real(Val val) @extern("c3_yyjson_is_real");
extern fn bool is_num(Val val) @extern("c3_yyjson_is_num");
extern fn bool is_str(Val val) @extern("c3_yyjson_is_str");
extern fn bool is_arr(Val val) @extern("c3_yyjson_is_arr");
extern fn bool is_obj(Val val) @extern("c3_yyjson_is_obj");

// Value getters (using wrappers)
extern fn bool get_bool(Val val) @extern("c3_yyjson_get_bool");
extern fn ulong get_uint(Val val) @extern("c3_yyjson_get_uint");
extern fn long get_sint(Val val) @extern("c3_yyjson_get_sint");
extern fn double get_real(Val val) @extern("c3_yyjson_get_real");
extern fn double get_num(Val val) @extern("c3_yyjson_get_num");
extern fn ZString get_str(Val val) @extern("c3_yyjson_get_str");
extern fn usz get_len(Val val) @extern("c3_yyjson_get_len");

// Array functions (using wrappers)
extern fn usz arr_size(Val arr) @extern("c3_yyjson_arr_size");
extern fn Val arr_get(Val arr, usz idx) @extern("c3_yyjson_arr_get");
extern fn ArrIter arr_iter_with(Val arr) @extern("c3_yyjson_arr_iter_with");
extern fn bool arr_iter_has_next(ArrIter* iter) @extern("c3_yyjson_arr_iter_has_next");
extern fn Val arr_iter_next(ArrIter* iter) @extern("c3_yyjson_arr_iter_next");

// Object functions (using wrappers)
extern fn usz obj_size(Val obj) @extern("c3_yyjson_obj_size");
extern fn Val obj_get(Val obj, ZString key) @extern("c3_yyjson_obj_get");
extern fn ObjIter obj_iter_with(Val obj) @extern("c3_yyjson_obj_iter_with");
extern fn bool obj_iter_has_next(ObjIter* iter) @extern("c3_yyjson_obj_iter_has_next");
extern fn Val obj_iter_next(ObjIter* iter) @extern("c3_yyjson_obj_iter_next");
extern fn Val obj_iter_get_val(Val key) @extern("c3_yyjson_obj_iter_get_val");

// Write functions
extern fn ZString val_write(Val val, uint flg, usz* len) @extern("c3_yyjson_val_write");
extern fn void libc_free(void* ptr) @extern("free");

// Pretty printable wrapper for Val
struct Pretty (Printable) {
  Val val;
}

fn Pretty Val.pretty(val) => { .val = val };

fn usz? Pretty.to_format(&self, Formatter* f) @dynamic {
  usz len;
  ZString json = val_write(self.val, WRITE_PRETTY, &len);
  if (json == null) return 0;
  defer libc_free(json);
  return f.print((String)json[:len]);
}

// Parse JSON string, returns root Val
// When using allocator (e.g. arena), memory is managed by the allocator
fn Val? parse(String json, Allocator allocator) {
  YYDoc doc = yy_read_with_alloc(json.ptr, json.len, READ_NOFLAG, &allocator);
  if (doc == null) return PARSE_ERROR~;
  return yy_doc_get_root(doc);
}

// Parse directly from a ByteWriter (efficient, no copy)
fn Val? parse_bytes(io::ByteWriter* writer, Allocator allocator) {
  char[] data = writer.array_view();
  YYDoc doc = yy_read_with_alloc(data.ptr, data.len, READ_NOFLAG, &allocator);
  if (doc == null) return PARSE_ERROR~;
  return yy_doc_get_root(doc);
}

faultdef PARSE_ERROR;
