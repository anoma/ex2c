#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

// Definition of a term

struct small {
  int32_t value;
};

struct atom {
  uint32_t length;
  char *value;
};

struct tuple {
  uint32_t length;
  struct term *values;
};

struct list {
  struct term *head;
  struct term *tail;
};

struct nil {};

struct fun {
  struct term (*ptr)();
  char *id;
  uint32_t id_len;
  uint32_t arity;
  uint32_t num_free;
  struct term *env;
};

struct bitstring {
  uint32_t length;
  unsigned char *bytes;
};

enum term_type {
  SMALL = 15,
  ATOM = 7,
  TUPLE = 2,
  LIST = 1,
  NIL = 27,
  FUN = 16,
  BITSTRING = 17,
  MAP = 28
};

struct term {
  enum term_type type;
  union {
    struct small small;
    struct atom atom;
    struct tuple tuple;
    struct list list;
    struct nil nil;
    struct fun fun;
    struct bitstring bitstring;
    struct map *map;
  };
};

struct map {
  struct term key;
  struct term value;
  struct map *tail;
};

// Convenience functions for term construction

int bit_to_byte_size(int length) { return (length + 7) / 8; }

struct term make_small(int32_t value) {
  struct term t;
  t.type = SMALL;
  t.small.value = value;
  return t;
}

struct term make_atom(uint32_t len, char *value) {
  struct term t;
  t.type = ATOM;
  t.atom.length = len;
  t.atom.value = value;
  return t;
}

struct term make_tuple(uint32_t len, struct term *values) {
  struct term t;
  t.type = TUPLE;
  t.tuple.length = len;
  t.tuple.values = (struct term *) calloc(len, sizeof(struct term));
  for(int i = 0; i < len; i++) {
    t.tuple.values[i] = values[i];
  }
  return t;
}

struct term make_list(struct term head, struct term tail) {
  struct term t;
  t.type = LIST;
  t.list.head = (struct term *) malloc(sizeof(struct term));
  *t.list.head = head;
  t.list.tail = (struct term *) malloc(sizeof(struct term));
  *t.list.tail = tail;
  return t;
} 

struct term make_nil() {
  struct term t;
  t.type = NIL;
  return t;
}

struct term make_fun(struct term (*ptr)(), char *id, uint32_t id_len, uint32_t arity, uint32_t num_free, struct term *env) {
  struct term t;
  t.type = FUN;
  t.fun.ptr = ptr;
  t.fun.id = id;
  t.fun.id_len = id_len;
  t.fun.arity = arity;
  t.fun.num_free = num_free;
  t.fun.env = (struct term *) calloc(num_free, sizeof(struct term));
  for(int i = 0; i < num_free; i++) {
    t.fun.env[i] = env[i];
  }
  return t;
}

struct term make_bitstring(uint32_t length, unsigned char *bytes) {
  struct term t;
  t.type = BITSTRING;
  t.bitstring.length = length;
  int byte_size = bit_to_byte_size(length);
  t.bitstring.bytes = (unsigned char *) malloc(byte_size);
  memcpy(t.bitstring.bytes, bytes, byte_size);
  return t;
}

struct term make_map() {
  struct term t;
  t.type = MAP;
  t.map = NULL;
  return t;
}

// State of the virtual machine

struct term xs[128];
struct term stack[128];
struct term *E = stack + 128;

// Foreign Function Interface

struct term call_0(struct term (*fun)()) {
  return fun();
}

struct term call_1(struct term (*fun)(), struct term x0) {
  xs[0] = x0;
  return call_0(fun);
}

struct term call_2(struct term (*fun)(), struct term x0, struct term x1) {
  xs[1] = x1;
  return call_1(fun, x0);
}

struct term call_3(struct term (*fun)(), struct term x0, struct term x1, struct term x2) {
  xs[2] = x2;
  return call_2(fun, x0, x1);
}

struct term call_4(struct term (*fun)(), struct term x0, struct term x1, struct term x2, struct term x3) {
  xs[3] = x3;
  return call_3(fun, x0, x1, x2);
}

struct term call_5(struct term (*fun)(), struct term x0, struct term x1, struct term x2, struct term x3, struct term x4) {
  xs[4] = x4;
  return call_4(fun, x0, x1, x2, x3);
}

struct term call_6(struct term (*fun)(), struct term x0, struct term x1, struct term x2, struct term x3, struct term x4, struct term x5) {
  xs[5] = x5;
  return call_5(fun, x0, x1, x2, x3, x4);
}

struct term call_7(struct term (*fun)(), struct term x0, struct term x1, struct term x2, struct term x3, struct term x4, struct term x5, struct term x6) {
  xs[6] = x6;
  return call_6(fun, x0, x1, x2, x3, x4, x5);
}

struct term call_8(struct term (*fun)(), struct term x0, struct term x1, struct term x2, struct term x3, struct term x4, struct term x5, struct term x6, struct term x7) {
  xs[7] = x7;
  return call_7(fun, x0, x1, x2, x3, x4, x5, x6);
}

struct term call_9(struct term (*fun)(), struct term x0, struct term x1, struct term x2, struct term x3, struct term x4, struct term x5, struct term x6, struct term x7, struct term x8) {
  xs[8] = x8;
  return call_8(fun, x0, x1, x2, x3, x4, x5, x6, x7);
}

// Virtual machine support functions

int map_size(struct term t) {
  struct map *u = t.map;
  int i;
  for(i = 0; u; i++, u = u->tail) {}
  return i;
}

void display_aux(const struct term *t) {
  switch(t->type) {
    case NIL:
      printf("[]");
      break;
    case LIST:
      printf("[");
      display_aux(t->list.head);
      t = t->list.tail;
      while(t->type == LIST) {
        printf(", ");
        display_aux(t->list.head);
        t = t->list.tail;
      }
      if(t->type != NIL) {
        printf(" | ");
        display_aux(t);
      }
      printf("]");
      break;
    case SMALL:
      printf("%i", t->small.value);
      break;
    case ATOM:
      printf(":%s", t->atom.value);
      break;
    case TUPLE:
      printf("{");
      for(int i = 0; i < t->tuple.length; i++) {
        if(i) printf(", ");
        display_aux(&t->tuple.values[i]);
      }
      printf("}");
      break;
    case FUN:
      printf("#Fun<%s>", t->fun.id);
      break;
    case BITSTRING:
      printf("<<");
      for(int i = 0; i < bit_to_byte_size(t->bitstring.length); i++) {
        if(i) printf(", ");
        printf("%u", t->bitstring.bytes[i]);
      }
      int rem = t->bitstring.length % 8;
      if(rem != 0) printf(" :: %u", rem);
      printf(">>");
      break;
  case MAP:
    printf("%%{");
    const struct map *map = t->map;
    for(int i = 0; map; i++, map = map->tail) {
      if(i) printf(", ");
      display_aux(&t->map->key);
      printf(" => ");
      display_aux(&t->map->value);
    }
    printf("}");
    break;
  }
}

void display(struct term t) {
  display_aux(&t);
  printf("\n");
}

bool is_tuple(struct term t) {
  return t.type == TUPLE;
}

bool test_arity(struct term t, int len) {
  return t.tuple.length == len;
}

bool is_nonempty_list(struct term t) {
  return t.type == LIST;
}

bool is_nil(struct term t) {
  return t.type == NIL;
}

void get_list(struct term t, struct term *hd, struct term *tl) {
  *hd = *t.list.head;
  *tl = *t.list.tail;
}

void put_list(struct term hd, struct term tl, struct term *t) {
  *t = make_list(hd, tl);
}

void get_hd(struct term t, struct term *hd) {
  *hd = *t.list.head;
}

void get_tl(struct term t, struct term *tl) { *tl = *t.list.tail; }

int tag_index(enum term_type t) {
  switch(t) {
  case NIL: return 5;
  case LIST: return 6;
  case SMALL: return 0;
  case ATOM: return 1;
  case TUPLE: return 3;
  case BITSTRING: return 7;
  case FUN: return 2;
  case MAP: return 4;
  }
}

int min(int a, int b) { return a < b ? a : b; }

int max(int a, int b) { return a < b ? b : a; }

int cmp_exact(struct term t, struct term u) {
  if(t.type != u.type) return tag_index(t.type) - tag_index(u.type);
  switch(t.type) {
  case NIL:
    return 0;
  case LIST: {
    int diff = cmp_exact(*t.list.head, *u.list.head);
    return diff ? diff : cmp_exact(*t.list.tail, *u.list.tail);
  } case SMALL:
    return t.small.value - u.small.value;
  case ATOM: {
    int diff = memcmp(t.atom.value, u.atom.value, min(t.atom.length, u.atom.length));
    return diff ? diff : t.atom.length - u.atom.length;
  } case TUPLE: {
      int diff = t.tuple.length - u.tuple.length;
      if(diff) return diff;
      for(int i = 0; i < t.tuple.length; i++) {
        int diff = cmp_exact(t.tuple.values[i], u.tuple.values[i]);
        if(diff) {
          return diff;
        }
      }
      return 0;
    } case BITSTRING: {
        int diff = memcmp(t.bitstring.bytes, u.bitstring.bytes, bit_to_byte_size(min(t.bitstring.length, u.bitstring.length)));
        return diff ? diff : t.bitstring.length - u.bitstring.length;
      } case FUN: {
          int diff0 = memcmp(t.fun.id, u.fun.id, min(t.fun.id_len, u.fun.id_len));
          int diff1 = diff0 ? diff0 : t.fun.id_len - u.fun.id_len;
          int diff2 = diff1 ? diff1 : t.fun.arity - u.fun.arity;
          int diff = diff2 ? diff2 : t.fun.num_free - u.fun.num_free;
          if(diff) return diff;
          for(int i = 0; i < t.fun.num_free; i++) {
            int diff = cmp_exact(t.fun.env[i], u.fun.env[i]);
            if(diff) {
              return diff;
            }
          }
          return 0;
        }
  case MAP: {
    int diff = map_size(t) - map_size(u);
    if(diff) return diff;
    struct map *v = t.map, *w = u.map;
    for(; v; v = v->tail, w = w->tail) {
      int diff = cmp_exact(v->key, w->key);
      if(diff) {
        return diff;
      }
    }
    struct map *x = t.map, *y = u.map;
    for(; x; x = x->tail, y = y->tail) {
      int diff = cmp_exact(x->value, y->value);
      if(diff) {
        return diff;
      }
    }
    return 0;
  }
  }
}

bool cmp(struct term t, struct term u) { return cmp_exact(t, u); }

bool is_eq_exact(struct term t, struct term u) { return cmp_exact(t, u) == 0; }

bool is_ne_exact(struct term t, struct term u) { return cmp_exact(t, u) != 0; }

bool is_eq(struct term t, struct term u) { return cmp(t, u) == 0; }

bool is_ge(struct term t, struct term u) { return cmp_exact(t, u) >= 0; }

bool is_lt(struct term t, struct term u) {
  return cmp_exact(t, u) < 0;
}

bool bif_3D3A3D(struct term t, struct term u, struct term *v) {
  if(cmp_exact(t, u) == 0) {
    *v = make_atom(4, "true");
  } else {
    *v = make_atom(5, "false");
  }
  return true;
}

bool bif_2D(struct term a, struct term b, struct term *c) {
  if(a.type != SMALL || b.type != SMALL) return false;
  c->type = SMALL;
  return !__builtin_sub_overflow(a.small.value, b.small.value, &c->small.value);
}

bool bif_2B(struct term a, struct term b, struct term *c) {
  if(a.type != SMALL || b.type != SMALL) return false;
  c->type = SMALL;
  return !__builtin_add_overflow(a.small.value, b.small.value, &c->small.value);
}

bool bif_2A(struct term a, struct term b, struct term *c) {
  if(a.type != SMALL || b.type != SMALL) return false;
  c->type = SMALL;
  return !__builtin_mul_overflow(a.small.value, b.small.value, &c->small.value);
}

bool bif_rem(struct term a, struct term b, struct term *c) {
  if(a.type != SMALL || b.type != SMALL || b.small.value == 0) return false;
  c->type = SMALL;
  c->small.value = a.small.value % b.small.value;
  return true;
}

bool bif_div(struct term a, struct term b, struct term *c) {
  if(a.type != SMALL || b.type != SMALL || b.small.value == 0) return false;
  c->type = SMALL;
  c->small.value = a.small.value / b.small.value;
  return true;
}

int bif_length(struct term a, struct term *b) {
  if(a.type != LIST) return false;
  b->type = SMALL;
  for(b->small.value = 0; a.type != NIL; b->small.value++) {
    if(a.type != LIST) return false;
    else a = *a.list.tail;
  }
  return true;
}

struct term erlang_get_module_info_1() {
  abort();
}

struct term erlang_get_module_info_2() {
  abort();
}

struct term erlang_2B_2() {
  struct term c;
  if(!bif_2B(xs[0], xs[1], &c)) abort();
  else return c;
}

int cmp_exact_r(const void *a, const void *b) {
  const struct term **a_term = (const struct term **) a;
  const struct term **b_term = (const struct term **) b;
  return cmp(**a_term, **b_term);
}

bool put_map_assoc(struct term map_term, struct term *dst, struct term *keys, struct term *values, size_t size) {
  // Sort the supplied keys in preparation forr map insertion
  struct term *key_ptrs[size];
  for(int i = 0; i < size; i++) key_ptrs[i] = &keys[i];
  qsort(key_ptrs, size, sizeof(struct term *), cmp_exact_r);

  struct map *map = map_term.map;
  struct map *new_map = map;
  struct map **new_map_ptr = &new_map;
  // Insert the supplied key-value pairs into the map in order
  for(int i = 0; i < size; i++) {
    int j = key_ptrs[i] - keys;
    int diff = true;
    // Duplicate the map until we get to the matching entry
    for(; map && (diff = cmp_exact(map->key, keys[j])) < 0; map = map->tail) {
      *new_map_ptr = (struct map *) malloc(sizeof(struct map));
      (*new_map_ptr)->key = map->key;
      (*new_map_ptr)->value = map->value;
      (*new_map_ptr)->tail = map->tail;
      new_map_ptr = &(*new_map_ptr)->tail;
    }
    // Construct the map entry that will contain the given key-value pair
    *new_map_ptr = (struct map *) malloc(sizeof(struct map));
    (*new_map_ptr)->key = keys[j];
    (*new_map_ptr)->value = values[j];
    (*new_map_ptr)->tail = diff ? map : map->tail;
    new_map_ptr = &(*new_map_ptr)->tail;
  }
  // Finally construct a term from the map with the new association
  dst->type = MAP;
  dst->map = new_map;
  return true;
}

struct term put_map_assoc_nofail(struct term map_term, struct term *keys, struct term *values, size_t size) {
  struct term dst;
  assert(put_map_assoc(map_term, &dst, keys, values, size));
  return dst;
}

bool put_map_exact(struct term map_term, struct term *dst, struct term *keys, struct term *values, size_t size) {
  // Sort the supplied keys in preparation forr map insertion
  struct term *key_ptrs[size];
  for(int i = 0; i < size; i++) key_ptrs[i] = &keys[i];
  qsort(key_ptrs, size, sizeof(struct term *), cmp_exact_r);

  struct map *map = map_term.map;
  struct map *new_map = map;
  struct map **new_map_ptr = &new_map;
  // Insert the supplied key-value pairs into the map in order
  for(int i = 0; i < size; i++) {
    int j = key_ptrs[i] - keys;
    int diff = true;
    // Duplicate the map until we get to the matching entry
    for(; map && (diff = cmp_exact(map->key, keys[j])) < 0; map = map->tail) {
      *new_map_ptr = (struct map *) malloc(sizeof(struct map));
      (*new_map_ptr)->key = map->key;
      (*new_map_ptr)->value = map->value;
      (*new_map_ptr)->tail = map->tail;
      new_map_ptr = &(*new_map_ptr)->tail;
    }
    // If diff != 0, then we did not arrive at equal term.
    if(diff) return false;
    // Construct the map entry that will contain the given key-value pair
    *new_map_ptr = (struct map *) malloc(sizeof(struct map));
    (*new_map_ptr)->key = keys[j];
    (*new_map_ptr)->value = values[j];
    (*new_map_ptr)->tail = map->tail;
    new_map_ptr = &(*new_map_ptr)->tail;
  }
  // Finally construct a term from the map with the new association
  dst->type = MAP;
  dst->map = new_map;
  return true;
}

struct term put_map_exact_nofail(struct term map_term, struct term *keys, struct term *values, size_t size) {
  struct term dst;
  assert(put_map_exact(map_term, &dst, keys, values, size));
  return dst;
}

struct term erlang_error_1() {
  printf("exception error:");
  display(xs[0]);
  abort();
}

struct term erlang_error_2() {
  printf("exception error:");
  display(xs[0]);
  abort();
}

struct term erlang_error_3() {
  printf("exception error:");
  display(xs[0]);
  abort();
}

struct term erlang_nif_error_1() {
  printf("exception error:");
  display(xs[0]);
  abort();
}

struct term erlang_2B2B_2() {
  struct term *x0 = &xs[0];
  struct term concat;
  concat.type = NIL;
  // Duplicate the list in the first argument
  struct term *concat_ptr = &concat;
  for(; x0->type == LIST; x0 = x0->list.tail, concat_ptr = concat_ptr->list.tail) {
    concat_ptr->type = LIST;
    concat_ptr->list.head = x0->list.head;
    concat_ptr->list.tail = (struct term *) malloc(sizeof(struct term));
  }
  // Ensure that the first argument is a proper list
  assert(x0->type == NIL);
  // Then set the tail of the concatenation to be the second argument
  *concat_ptr = xs[1];
  return concat;
}

bool is_atom(struct term t) { return t.type == ATOM; }

bool is_float(struct term t) { return false; }

bool is_list(struct term t) { return t.type == LIST || t.type == NIL; }

bool is_integer(struct term t) { return t.type == SMALL; }

bool is_function2(struct term t, struct term u) {
  if(u.type != SMALL) {
    printf("argument 2: not an integer");
    abort();
  } else if(u.small.value) {
    printf("argument 2: out of range");
    abort();
  } else {
    return t.type == FUN && u.type == SMALL && t.fun.arity == u.small.value;
  }
}

void badmatch(struct term t) {
  struct term exit_reason = make_tuple(2, (struct term []) { make_atom(8, "badmatch"), t });
  display(exit_reason);
  abort();
}

void case_end(struct term t) {
  struct term exit_reason = make_tuple(2, (struct term []) { make_atom(11, "case_clause"), t });
  display(exit_reason);
  abort();
}

bool bif_element(struct term t, struct term u, struct term *v) {
  if(t.type == SMALL && t.small.value > 0 && u.type == TUPLE && t.small.value <= u.tuple.length) {
    *v = u.tuple.values[t.small.value - 1];
    return true;
  } else {
    return false;
  }
}

struct term erlang_setelement_3() {
  if(xs[0].type == SMALL) {
    printf("1st argument: not an integer");
    abort();
  } else if(xs[0].small.value <= 0 || xs[0].small.value > xs[1].tuple.length) {
    printf("1st argument: out of range");
    abort();
  } else if(xs[1].type != TUPLE) {
    printf("2nd argument: not a tuple");
    abort();
  } else {
    struct term u = make_tuple(xs[0].small.value <= xs[1].tuple.length, xs[1].tuple.values);
    u.tuple.values[xs[0].small.value - 1] = xs[2];
    return u;
  }
}

bool has_map_fields(struct term t, int len, struct term *fields) {
  if(t.type != MAP) return false;
  for(int i = 0; i < len; i++) {
    bool found = false;
    for(struct map *m = t.map; m; m = m->tail) {
      if(cmp_exact(m->key, fields[i]) == 0) {
        found = true;
        break;
      }
    }
    if(!found) return false;
  }
  return true;
}

bool is_tagged_tuple(struct term t, int len, struct term tag) {
  return t.type == TUPLE && t.tuple.length == len && tag.type == ATOM && t.tuple.length > 0 && cmp_exact(t.tuple.values[0], tag) == 0;
}

struct term erlang_2D2D_2() {
  struct term *x0 = &xs[0];
  struct term duplicate;
  duplicate.type = NIL;
  // Duplicate the list in the first argument
  struct term *duplicate_ptr = &duplicate;
  for(; x0->type == LIST; x0 = x0->list.tail, duplicate_ptr = duplicate_ptr->list.tail) {
    // Copy the current cell of x0 into duplicate
    duplicate_ptr->type = LIST;
    duplicate_ptr->list.head = x0->list.head;
    duplicate_ptr->list.tail = (struct term *) malloc(sizeof(struct term));
  }
  // Ensure that the first argument is a proper list
  assert(x0->type == NIL);
  // Then set the tail of the duplicate to nil
  *duplicate_ptr = *x0;
  // Now remove the terms occuring in the second list
  struct term *x1 = &xs[1];
  for(; x1->type == LIST; x1 = x1->list.tail) {
    // Iterate through the duplicate list looking for *x1->list.head
    for(struct term *duplicate_ptr = &duplicate; duplicate_ptr->type == LIST;) {
      // If *x1->list.head is found, then remove it
      if(cmp_exact(*duplicate_ptr->list.head, *x1->list.head) == 0) {
        struct term *tail = duplicate_ptr->list.tail;
        // Remove *x1->list.head by overwriting it with its tail
        *duplicate_ptr = *duplicate_ptr->list.tail;
        // Since the tail has been copied and was created in this function, it's now dangling
        free(tail);
        // Only remove one instance of the match
        break;
      } else {
        // Otherwise move to the next element
        duplicate_ptr = duplicate_ptr->list.tail;
      }
    }
  }
  // Ensure that the second argument is a proper list
  assert(x1->type == NIL);
  return duplicate;
}

struct term erlang_integer_to_list_1() {
  printf("integer_to_list/1 not implemented");
  abort();
}

struct term erlang_float_to_list_1() {
  printf("float_to_list/1 not implemented");
  abort();
}

struct term erlang_atom_to_list_1() {
  printf("atom_to_list/1 not implemented");
  abort();
}

// Serialization/deserialization functions

int borsh_size(const struct term *t) {
  // Tag byte
  int size = sizeof(uint8_t);
  switch(t->type) {
  case NIL: break;
  case LIST:
    size += borsh_size(t->list.head) + borsh_size(t->list.tail);
    break;
  case SMALL:
    size += sizeof(int32_t);
    break;
  case ATOM:
    size += sizeof(uint32_t) + t->atom.length;
    break;
  case TUPLE:
    size += sizeof(uint32_t);
    for(int i = 0; i < t->tuple.length; i++) {
      size += borsh_size(&t->tuple.values[i]);
    }
    break;
  case FUN:
    printf("Functions cannot be serialized");
    abort();
    break;
  case BITSTRING:
    size += sizeof(uint32_t) + sizeof(uint32_t) + bit_to_byte_size(t->bitstring.length);
    break;
  case MAP:
    size += sizeof(uint32_t);
    for(const struct map *map = t->map; map; map = map->tail) {
      size += borsh_size(&map->key) + borsh_size(&map->value);
    }
    break;
  }
  return size;
}

void borsh_serialize_uint32(const uint32_t value, unsigned char * const output, int *pos) {
  output[(*pos)++] = value & 0xFF;
  output[(*pos)++] = (value >> 8) & 0xFF;
  output[(*pos)++] = (value >> 16) & 0xFF;
  output[(*pos)++] = (value >> 24) & 0xFF;
}

void borsh_serialize_term(const struct term *t, unsigned char * const output, int *pos) {
  output[(*pos)++] = (uint8_t) t->type;
  switch(t->type) {
  case NIL: break;
  case LIST:
    borsh_serialize_term(t->list.head, output, pos);
    borsh_serialize_term(t->list.tail, output, pos);
    break;
  case SMALL:
    borsh_serialize_uint32(t->small.value, output, pos);
    break;
  case ATOM:
    borsh_serialize_uint32(t->atom.length, output, pos);
    for(int i = 0; i < t->atom.length; i++) {
      output[(*pos)++] = t->atom.value[i];
    }
    break;
  case TUPLE:
    borsh_serialize_uint32(t->tuple.length, output, pos);
    for(int i = 0; i < t->tuple.length; i++) {
      borsh_serialize_term(&t->tuple.values[i], output, pos);
    }
    break;
  case FUN:
    printf("Functions cannot be serialized");
    abort();
    break;
  case BITSTRING:
    borsh_serialize_uint32(t->bitstring.length, output, pos);
    int byte_size = bit_to_byte_size(t->bitstring.length);
    borsh_serialize_uint32(byte_size, output, pos);
    for(int i = 0; i < byte_size; i++) {
      output[(*pos)++] = t->bitstring.bytes[i];
    }
    break;
  case MAP:
    int size = map_size(*t);
    borsh_serialize_uint32(size, output, pos);
    for(struct map *map = t->map; map; map = map->tail) {
      borsh_serialize_term(&map->key, output, pos);
      borsh_serialize_term(&map->value, output, pos);
    }
    break;
  }
}

void env_commit(const uint8_t *buffer_ptr, uintptr_t buffer_size);

struct term Elixir2EGuestEnv_commit_1() {
  int capacity = borsh_size(&xs[0]);
  unsigned char *bytes = (unsigned char *) malloc(capacity);
  int pos = 0;
  borsh_serialize_term(&xs[0], bytes, &pos);
  env_commit(bytes, pos);
  return make_bitstring(pos*8, bytes);
}

uint32_t borsh_deserialize_uint32(const unsigned char * const input, int *pos) {
  int output = 0;
  output += input[(*pos)++];
  output += input[(*pos)++] << 8;
  output += input[(*pos)++] << 16;
  output += input[(*pos)++] << 24;
  return output;
}

struct term borsh_deserialize_term(const unsigned char * const input, int *pos) {
  enum term_type type = (enum term_type) input[(*pos)++];
  switch(type) {
  case NIL: return make_nil();
  case LIST:
    struct term hd = borsh_deserialize_term(input, pos);
    struct term tl = borsh_deserialize_term(input, pos);
    return make_list(hd, tl);
  case SMALL:
    return make_small(borsh_deserialize_uint32(input, pos));
  case ATOM: {
    int length = borsh_deserialize_uint32(input, pos);
    char *value = (char *) malloc(length);
    for(int i = 0; i < length; i++) {
      value[i] = input[(*pos)++];
    }
    return make_atom(length, value);
  } case TUPLE: {
      int length = borsh_deserialize_uint32(input, pos);
      struct term values[length];
      for(int i = 0; i < length; i++) {
        values[i] = borsh_deserialize_term(input, pos);
      }
      return make_tuple(length, values);
    } case FUN: {
        printf("Functions cannot be deserialized");
        abort();
        break;
      } case BITSTRING: {
          int bit_length = borsh_deserialize_uint32(input, pos);
          int byte_length = borsh_deserialize_uint32(input, pos);
          unsigned char bytes[byte_length];
          for(int i = 0; i < byte_length; i++) {
            bytes[i] = input[(*pos)++];
          }
          return make_bitstring(bit_length, bytes);
        } case MAP: {
            int length = borsh_deserialize_uint32(input, pos);
            struct term keys[length], values[length];
            for(int i = 0; i < length; i++) {
              keys[i] = borsh_deserialize_term(input, pos);
              values[i] = borsh_deserialize_term(input, pos);
            }
            return put_map_assoc_nofail(make_map(), keys, values, length);
          }
  }
}

uintptr_t env_read(uint8_t *buffer_ptr, uintptr_t buffer_size);

struct term Elixir2EGuestEnv_read_0() {
  const int LENGTH = 256;
  unsigned char buffer[LENGTH];
  env_read(buffer, LENGTH);
  int pos = 0;
  return borsh_deserialize_term(buffer, &pos);
}
