use oxc_ffi::{oxc_minify, oxc_result_free, OxcErrorCode};

use std::ffi::{CStr, CString};
use std::ptr;

fn minify(source: &str, options: &str) -> (OxcErrorCode, String) {
  let source = CString::new(source).unwrap();
  let options = CString::new(options).unwrap();

  let result = unsafe { oxc_minify(source.as_ptr(), options.as_ptr()) };
  let code = result.code;

  let answer = if result.value.is_null() {
    unsafe { CStr::from_ptr(result.error) }.to_str().unwrap().to_string()
  } else {
    unsafe { CStr::from_ptr(result.value) }.to_str().unwrap().to_string()
  };

  unsafe { oxc_result_free(result) };

  (code, answer)
}

#[test]
fn minify_answers_json_for_source_it_read() {
  let (code, answer) = minify("const x = 1; console.log(x)", "{}");

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    r#"{"code":"console.log(1);","legal_comments":[],"errors":[],"panicked":false}"#
  );
}

#[test]
fn minify_reads_the_options_it_was_given() {
  let (code, answer) = minify("console.log(1); foo()", r#"{"compress":{"drop_console":true}}"#);

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    r#"{"code":"foo();","legal_comments":[],"errors":[],"panicked":false}"#
  );
}

#[test]
fn minify_reports_the_length_of_what_it_answered() {
  let source = CString::new("foo()").unwrap();
  let options = CString::new("{}").unwrap();

  let result = unsafe { oxc_minify(source.as_ptr(), options.as_ptr()) };
  let value = unsafe { CStr::from_ptr(result.value) }.to_bytes().len();

  assert_eq!(result.value_len, value);

  unsafe { oxc_result_free(result) };
}

#[test]
fn minify_refuses_an_option_it_does_not_read() {
  let (code, answer) = minify("foo()", r#"{"nonsense":true}"#);

  assert_eq!(code, OxcErrorCode::Option);
  assert_eq!(
    answer,
    "Invalid options: unknown field `nonsense`, expected one of `filename`, `lang`, `source_type`, `compress`, `mangle`, `codegen`, `sourcemap` at line 1 column 11"
  );
}

#[test]
fn minify_refuses_a_null_source() {
  let options = CString::new("{}").unwrap();
  let result = unsafe { oxc_minify(ptr::null(), options.as_ptr()) };

  assert_eq!(result.code, OxcErrorCode::Encoding);
  assert_eq!(
    unsafe { CStr::from_ptr(result.error) }.to_str().unwrap(),
    "source is null"
  );

  unsafe { oxc_result_free(result) };
}

#[test]
fn minify_refuses_a_source_that_is_not_utf8() {
  let source = CString::new(vec![0xff, 0xfe]).unwrap();
  let options = CString::new("{}").unwrap();

  let result = unsafe { oxc_minify(source.as_ptr(), options.as_ptr()) };

  assert_eq!(result.code, OxcErrorCode::Encoding);
  assert_eq!(
    unsafe { CStr::from_ptr(result.error) }.to_str().unwrap(),
    "Invalid UTF-8 in source: invalid utf-8 sequence of 1 bytes from index 0"
  );

  unsafe { oxc_result_free(result) };
}

#[test]
fn minify_reads_no_options_at_all_as_the_defaults() {
  let source = CString::new("const x = 1; console.log(x)").unwrap();
  let result = unsafe { oxc_minify(source.as_ptr(), ptr::null()) };

  assert_eq!(result.code, OxcErrorCode::None);

  unsafe { oxc_result_free(result) };
}
