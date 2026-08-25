#include <ruby.h>
#include <ruby/encoding.h>
#include <ruby/thread.h>
#include "include/oxc.h"

static VALUE rb_mOxc;
static VALUE rb_mBackend;
static VALUE rb_eError;
static VALUE rb_eOptionError;
static VALUE rb_eOxcEncodingError;
static VALUE rb_eTransformError;
static VALUE rb_eInternalError;
static VALUE rb_ePanicError;

typedef struct OxcResult (*oxc_function)(const char *, const char *);

struct call_arguments {
  oxc_function function;
  const char *source;
  const char *options;
  struct OxcResult result;
};

static VALUE make_utf8_string(const char *cstring) {
  return rb_enc_str_new_cstr(cstring, rb_utf8_encoding());
}

static VALUE take_utf8_string(char *cstring) {
  if (!cstring) return Qnil;

  VALUE string = make_utf8_string(cstring);
  oxc_string_free(cstring);

  return string;
}

static VALUE error_class_for(enum OxcErrorCode code) {
  switch (code) {
    case OXC_ERROR_CODE_OPTION: return rb_eOptionError;
    case OXC_ERROR_CODE_ENCODING: return rb_eOxcEncodingError;
    case OXC_ERROR_CODE_TRANSFORM: return rb_eTransformError;
    case OXC_ERROR_CODE_PANIC: return rb_ePanicError;
    default: return rb_eInternalError;
  }
}

static VALUE unwrap(struct OxcResult result) {
  if (result.error) {
    VALUE message = make_utf8_string(result.error);
    VALUE error_class = error_class_for(result.code);

    oxc_result_free(result);

    rb_raise(error_class, "%s", StringValueCStr(message));
  }

  if (!result.value) {
    oxc_result_free(result);

    rb_raise(rb_eInternalError, "oxc returned no result");
  }

  VALUE value = rb_enc_str_new(result.value, (long) result.value_len, rb_utf8_encoding());

  oxc_result_free(result);

  return value;
}

static void *without_gvl(void *data) {
  struct call_arguments *arguments = (struct call_arguments *) data;

  arguments->result = arguments->function(arguments->source, arguments->options);

  return NULL;
}

static VALUE call(oxc_function function, VALUE source, VALUE options) {
  struct call_arguments arguments;

  arguments.function = function;
  arguments.source = StringValueCStr(source);
  arguments.options = StringValueCStr(options);

  rb_thread_call_without_gvl(without_gvl, &arguments, NULL, NULL);

  return unwrap(arguments.result);
}

static VALUE rb_minify(VALUE self, VALUE source, VALUE options) {
  (void) self;

  return call(oxc_minify, source, options);
}

static VALUE rb_transform(VALUE self, VALUE source, VALUE options) {
  (void) self;

  return call(oxc_transform, source, options);
}

static VALUE rb_scope(VALUE self, VALUE source, VALUE options) {
  (void) self;

  return call(oxc_scope, source, options);
}

static VALUE rb_parse(VALUE self, VALUE source, VALUE options) {
  (void) self;

  return call(oxc_parse, source, options);
}

static VALUE rb_native_version(VALUE self) {
  (void) self;

  return take_utf8_string(oxc_version());
}

static VALUE rb_oxc_version(VALUE self) {
  (void) self;

  return take_utf8_string(oxc_oxc_version());
}

void Init_oxc(void) {
  rb_mOxc = rb_define_module("Oxc");
  rb_mBackend = rb_define_module_under(rb_mOxc, "Backend");

  rb_eError = rb_define_class_under(rb_mOxc, "Error", rb_eStandardError);
  rb_eOptionError = rb_define_class_under(rb_mOxc, "OptionError", rb_eError);
  rb_eOxcEncodingError = rb_define_class_under(rb_mOxc, "EncodingError", rb_eError);
  rb_eTransformError = rb_define_class_under(rb_mOxc, "TransformError", rb_eError);
  rb_eInternalError = rb_define_class_under(rb_mOxc, "InternalError", rb_eError);
  rb_ePanicError = rb_define_class_under(rb_mOxc, "PanicError", rb_eInternalError);

  rb_define_singleton_method(rb_mBackend, "minify", rb_minify, 2);
  rb_define_singleton_method(rb_mBackend, "transform", rb_transform, 2);
  rb_define_singleton_method(rb_mBackend, "parse", rb_parse, 2);
  rb_define_singleton_method(rb_mBackend, "scope", rb_scope, 2);
  rb_define_singleton_method(rb_mBackend, "version", rb_native_version, 0);
  rb_define_singleton_method(rb_mBackend, "oxc_version", rb_oxc_version, 0);
}
