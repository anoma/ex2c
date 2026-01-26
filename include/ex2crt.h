#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

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
  BITSTRING = 17
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
  };
};

// Convenience functions for term construction

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

struct term make_fun(struct term (*ptr)(), uint32_t num_free, struct term *env) {
  struct term t;
  t.type = FUN;
  t.fun.ptr = ptr;
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
  t.bitstring.bytes = bytes;
  return t;
}

// State of the virtual machine

struct term xs[128];
struct term stack[128];
struct term *E = stack + 128;

// Virtual machine support functions

int bit_to_byte_size(int length) {
  return (length + 7)/8;
}

void display_aux(struct term *t) {
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
      printf("%s", t->atom.value);
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
      printf("#Fun<%p>", t->fun.ptr);
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
  }
}

void display(struct term t) {
  display_aux(&t);
  printf("\n");
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

void get_tl(struct term t, struct term *tl) {
  *tl = *t.list.tail;
}

bool is_eq_exact(struct term t, struct term u) {
  if(t.type != u.type) return false;
  switch(t.type) {
    case NIL:
      return true;
    case LIST:
      return is_eq_exact(*t.list.head, *u.list.head) && is_eq_exact(*t.list.tail, *u.list.tail);
    case SMALL:
      return t.small.value == u.small.value;
    case ATOM:
      return t.atom.length == u.atom.length && !memcmp(t.atom.value, u.atom.value, t.atom.length);
    case TUPLE:
      if(t.tuple.length != u.tuple.length) return false;
      for(int i = 0; i < t.tuple.length; i++) {
        if(!is_eq_exact(t.tuple.values[i], u.tuple.values[i])) {
          return false;
        }
      }
      return true;
    case BITSTRING:
      return t.bitstring.length == u.bitstring.length && !memcmp(t.bitstring.bytes, u.bitstring.bytes, bit_to_byte_size(t.bitstring.length));
    case FUN:
      if(t.fun.ptr != u.fun.ptr || t.fun.num_free != u.fun.num_free) return false;
      for(int i = 0; i < t.fun.num_free; i++) {
        if(!is_eq_exact(t.fun.env[i], u.fun.env[i])) {
          return false;
        }
      }
      return true;
  }
}

bool is_eq(struct term t, struct term u) {
  return is_eq_exact(t, u);
}

bool bif_sub(struct term a, struct term b, struct term *c) {
  if(a.type != SMALL || b.type != SMALL) return false;
  c->type = SMALL;
  c->small.value = a.small.value - b.small.value;
  return !__builtin_sub_overflow(a.small.value, b.small.value, &c->small.value);
}

bool bif_add(struct term a, struct term b, struct term *c) {
  if(a.type != SMALL || b.type != SMALL) return false;
  c->type = SMALL;
  c->small.value = a.small.value + b.small.value;
  return !__builtin_add_overflow(a.small.value, b.small.value, &c->small.value);
}

bool bif_mul(struct term a, struct term b, struct term *c) {
  if(a.type != SMALL || b.type != SMALL) return false;
  c->type = SMALL;
  c->small.value = a.small.value * b.small.value;
  return !__builtin_mul_overflow(a.small.value, b.small.value, &c->small.value);
}
