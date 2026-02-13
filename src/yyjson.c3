module yyjson;
import std::io;

// Opaque types
alias Doc = void*;
alias Val = void*;
alias MutDoc = void*;
alias MutVal = void*;

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

// Document functions (using wrapper for inline functions)
extern fn Doc read(char* dat, usz len, uint flg) @extern("c3_yyjson_read");
extern fn void doc_free(Doc doc) @extern("c3_yyjson_doc_free");
extern fn Val doc_get_root(Doc doc) @extern("c3_yyjson_doc_get_root");

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

// Helper: parse a string and return root value (caller must free doc)
fn Val? parse(String json, Doc* out_doc) {
  Doc doc = read(json.ptr, json.len, READ_NOFLAG);
  if (doc == null) return PARSE_ERROR~;
  *out_doc = doc;
  return doc_get_root(doc);
}

// Parse from InStream (e.g., HttpResponse)
// Reads entire stream into buffer, then parses
fn Val? parse_stream(InStream stream, Doc* out_doc, Allocator allocator) {
  io::ByteWriter buffer;
  buffer.init(allocator);
  buffer.read_from(stream)!;

  char[] data = buffer.array_view();
  Doc doc = read(data.ptr, data.len, READ_NOFLAG);
  if (doc == null) return PARSE_ERROR~;
  *out_doc = doc;
  return doc_get_root(doc);
}

// Parse directly from a ByteWriter (efficient, no copy)
fn Val? parse_bytes(io::ByteWriter* writer, Doc* out_doc) {
  char[] data = writer.array_view();
  Doc doc = read(data.ptr, data.len, READ_NOFLAG);
  if (doc == null) return PARSE_ERROR~;
  *out_doc = doc;
  return doc_get_root(doc);
}

faultdef PARSE_ERROR;
