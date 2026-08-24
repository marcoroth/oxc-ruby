use oxc_ffi::{oxc_result_free, oxc_transform, OxcErrorCode};

use std::ffi::{CStr, CString};

fn transform(source: &str, options: &str) -> (OxcErrorCode, String) {
  let source = CString::new(source).unwrap();
  let options = CString::new(options).unwrap();

  let result = unsafe { oxc_transform(source.as_ptr(), options.as_ptr()) };
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
fn transform_strips_the_types_a_typescript_file_wrote() {
  let (code, answer) = transform("const x: number = 1; foo(x)", r#"{"filename":"app.ts"}"#);

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    r#"{"code":"const x = 1;\nfoo(x);\n","legal_comments":[],"helpers_used":{},"errors":[],"panicked":false}"#
  );
}

#[test]
fn transform_leaves_javascript_it_had_no_work_for_alone() {
  let (code, answer) = transform("const x = 1; foo(x)", "{}");

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    r#"{"code":"const x = 1;\nfoo(x);\n","legal_comments":[],"helpers_used":{},"errors":[],"panicked":false}"#
  );
}

#[test]
fn transform_reports_the_helpers_its_lowering_needs() {
  let source = "class A { #p = 1; get() { return this.#p } }; foo(A)";
  let (code, answer) = transform(source, r#"{"target":"es2015","codegen":{"remove_whitespace":true}}"#);

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    concat!(
      r#"{"code":"import _classPrivateFieldInitSpec from\"@oxc-project/runtime/helpers/classPrivateFieldInitSpec\";"#,
      r#"import _classPrivateFieldGet from\"@oxc-project/runtime/helpers/classPrivateFieldGet2\";"#,
      r#"var _p=new WeakMap;class A{constructor(){_classPrivateFieldInitSpec(this,_p,1)}"#,
      r#"get(){return _classPrivateFieldGet(_p,this)}};foo(A);","legal_comments":[],"#,
      r#""helpers_used":{"classPrivateFieldGet2":"@oxc-project/runtime/helpers/classPrivateFieldGet2","#,
      r#""classPrivateFieldInitSpec":"@oxc-project/runtime/helpers/classPrivateFieldInitSpec"},"#,
      r#""errors":[],"panicked":false}"#
    )
  );
}

#[test]
fn transform_answers_what_it_could_not_read_inside_the_result() {
  let (code, answer) = transform("const x = ;", "{}");

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    concat!(
      r#"{"code":"","legal_comments":[],"helpers_used":{},"errors":[{"severity":"error","#,
      r#""message":"Unexpected token","labels":[{"start":10,"end":11}],"#,
      r#""codeframe":"\n  x Unexpected token\n   ,-[:1:11]\n 1 | const x = ;\n   :           ^\n   `----\n"}],"#,
      r#""panicked":true}"#
    )
  );
}

#[test]
fn transform_refuses_an_option_minify_reads_and_it_does_not() {
  let (code, answer) = transform("foo()", r#"{"compress":true}"#);

  assert_eq!(code, OxcErrorCode::Option);
  assert_eq!(
    answer,
    concat!(
      "Invalid options: unknown field `compress`, expected one of `filename`, `lang`, `source_type`, `cwd`, ",
      "`target`, `jsx`, `typescript`, `assumptions`, `decorator`, `helpers`, `define`, `inject`, `minify`, ",
      "`codegen`, `sourcemap` ",
      "at line 1 column 11"
    )
  );
}

#[test]
fn transform_minifies_to_the_target_it_was_asked_to_lower_for() {
  let (code, answer) = transform(
    "const f = (a) => a ** 2; foo(f)",
    r#"{"target":"es2015","minify":true}"#,
  );

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    r#"{"code":"foo(e=>Math.pow(e,2));","legal_comments":[],"helpers_used":{},"errors":[],"panicked":false}"#
  );
}

#[test]
fn transform_writes_a_declaration_file_for_the_types_it_stripped() {
  let (code, answer) = transform(
    "export const a: number = 1",
    r#"{"filename":"a.ts","source_type":"module","typescript":{"declaration":true}}"#,
  );

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    concat!(
      r#"{"code":"export const a = 1;\n","declaration":"export declare const a: number;\n","#,
      r#""legal_comments":[],"helpers_used":{},"errors":[],"panicked":false}"#
    )
  );
}
