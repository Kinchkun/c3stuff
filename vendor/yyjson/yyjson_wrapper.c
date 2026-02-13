#include "yyjson.h"
#include <stdint.h>

// C3 Allocator interface - matches C3's Allocator struct layout
// The C3 Allocator is a fat pointer: (data_ptr, vtable_ptr)
typedef struct {
    void *data;
    void *vtable;
} C3Allocator;

// C3 allocator functions - implemented in C3 and exported
extern void* c3_alloc_malloc(C3Allocator* alloc, size_t size);
extern void* c3_alloc_realloc(C3Allocator* alloc, void* ptr, size_t old_size, size_t new_size);
extern void c3_alloc_free(C3Allocator* alloc, void* ptr);

// yyjson allocator callbacks that forward to C3
static void* c3_yyjson_malloc(void *ctx, size_t size) {
    return c3_alloc_malloc((C3Allocator*)ctx, size);
}

static void* c3_yyjson_realloc(void *ctx, void *ptr, size_t old_size, size_t size) {
    return c3_alloc_realloc((C3Allocator*)ctx, ptr, old_size, size);
}

static void c3_yyjson_free(void *ctx, void *ptr) {
    c3_alloc_free((C3Allocator*)ctx, ptr);
}

// Create a yyjson allocator from C3 allocator
yyjson_doc* c3_yyjson_read_with_alloc(const char *dat, size_t len, yyjson_read_flag flg, C3Allocator *alloc) {
    yyjson_alc alc = {
        .malloc = c3_yyjson_malloc,
        .realloc = c3_yyjson_realloc,
        .free = c3_yyjson_free,
        .ctx = alloc
    };
    return yyjson_read_opts((char*)dat, len, flg, &alc, NULL);
}

// Wrapper functions for inline functions that C3 needs to call

yyjson_doc *c3_yyjson_read(const char *dat, size_t len, yyjson_read_flag flg) {
    return yyjson_read(dat, len, flg);
}

yyjson_val *c3_yyjson_doc_get_root(yyjson_doc *doc) {
    return yyjson_doc_get_root(doc);
}

void c3_yyjson_doc_free(yyjson_doc *doc) {
    yyjson_doc_free(doc);
}

char *c3_yyjson_val_write(const yyjson_val *val, yyjson_write_flag flg, size_t *len) {
    return yyjson_val_write(val, flg, len);
}

// Type checking wrappers
bool c3_yyjson_is_null(yyjson_val *val) { return yyjson_is_null(val); }
bool c3_yyjson_is_bool(yyjson_val *val) { return yyjson_is_bool(val); }
bool c3_yyjson_is_str(yyjson_val *val) { return yyjson_is_str(val); }
bool c3_yyjson_is_arr(yyjson_val *val) { return yyjson_is_arr(val); }
bool c3_yyjson_is_obj(yyjson_val *val) { return yyjson_is_obj(val); }
bool c3_yyjson_is_int(yyjson_val *val) { return yyjson_is_int(val); }
bool c3_yyjson_is_real(yyjson_val *val) { return yyjson_is_real(val); }
bool c3_yyjson_is_num(yyjson_val *val) { return yyjson_is_num(val); }

// Value getters
const char *c3_yyjson_get_str(yyjson_val *val) { return yyjson_get_str(val); }
int64_t c3_yyjson_get_sint(yyjson_val *val) { return yyjson_get_sint(val); }
uint64_t c3_yyjson_get_uint(yyjson_val *val) { return yyjson_get_uint(val); }
double c3_yyjson_get_real(yyjson_val *val) { return yyjson_get_real(val); }
double c3_yyjson_get_num(yyjson_val *val) { return yyjson_get_num(val); }
bool c3_yyjson_get_bool(yyjson_val *val) { return yyjson_get_bool(val); }
size_t c3_yyjson_get_len(yyjson_val *val) { return yyjson_get_len(val); }

// Array functions
size_t c3_yyjson_arr_size(yyjson_val *arr) { return yyjson_arr_size(arr); }
yyjson_val *c3_yyjson_arr_get(yyjson_val *arr, size_t idx) { return yyjson_arr_get(arr, idx); }
yyjson_arr_iter c3_yyjson_arr_iter_with(yyjson_val *arr) { return yyjson_arr_iter_with(arr); }
bool c3_yyjson_arr_iter_has_next(yyjson_arr_iter *iter) { return yyjson_arr_iter_has_next(iter); }
yyjson_val *c3_yyjson_arr_iter_next(yyjson_arr_iter *iter) { return yyjson_arr_iter_next(iter); }

// Object functions
size_t c3_yyjson_obj_size(yyjson_val *obj) { return yyjson_obj_size(obj); }
yyjson_val *c3_yyjson_obj_get(yyjson_val *obj, const char *key) { return yyjson_obj_get(obj, key); }
yyjson_obj_iter c3_yyjson_obj_iter_with(yyjson_val *obj) { return yyjson_obj_iter_with(obj); }
bool c3_yyjson_obj_iter_has_next(yyjson_obj_iter *iter) { return yyjson_obj_iter_has_next(iter); }
yyjson_val *c3_yyjson_obj_iter_next(yyjson_obj_iter *iter) { return yyjson_obj_iter_next(iter); }
yyjson_val *c3_yyjson_obj_iter_get_val(yyjson_val *key) { return yyjson_obj_iter_get_val(key); }
