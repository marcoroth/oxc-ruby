use oxc_ffi::{oxc_result_free, oxc_scope, OxcErrorCode};

use std::ffi::{CStr, CString};

fn scope(source: &str, options: &str) -> (OxcErrorCode, String) {
  let source = CString::new(source).unwrap();
  let options = CString::new(options).unwrap();

  let result = unsafe { oxc_scope(source.as_ptr(), options.as_ptr()) };
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
fn scope_renames_what_the_file_declared_at_the_top_level() {
  let (code, answer) = scope("let a = 1; foo(a)", r#"{"scope":"x"}"#);

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    r#"{"code":"let a_x = 1;\nfoo(a_x);\n","renamed":{"a":"a_x"},"errors":[],"panicked":false}"#
  );
}

#[test]
fn scope_refuses_a_scope_that_could_not_read_as_part_of_a_name() {
  let (code, answer) = scope("let a = 1", r#"{"scope":"a-b"}"#);

  assert_eq!(code, OxcErrorCode::Option);
  assert_eq!(
    answer,
    concat!(
      r#"Invalid scope "a-b". It has to read as part of a JavaScript name, "#,
      "so letters, digits, _ and $ only."
    )
  );
}
