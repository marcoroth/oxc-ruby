use oxc_ffi::{oxc_parse, oxc_result_free, OxcErrorCode};

use std::ffi::{CStr, CString};

fn parse(source: &str, options: &str) -> (OxcErrorCode, String) {
  let source = CString::new(source).unwrap();
  let options = CString::new(options).unwrap();

  let result = unsafe { oxc_parse(source.as_ptr(), options.as_ptr()) };
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
fn parse_splices_the_ast_into_the_payload_instead_of_escaping_it() {
  let (code, answer) = parse("a", "{}");

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    concat!(
      r#"{"program":{"type":"Program","body":[{"type":"ExpressionStatement","#,
      r#""expression":{"type":"Identifier","name":"a","start":0,"end":1},"start":0,"end":1}],"#,
      r#""sourceType":"module","hashbang":null,"start":0,"end":1},"comments":[],"errors":[],"panicked":false}"#
    )
  );
}

#[test]
fn parse_leaves_the_ast_out_when_it_was_only_asked_to_read() {
  let (code, answer) = parse("// hi\nfoo()", r#"{"ast":false}"#);

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    r#"{"comments":[{"type":"Line","value":" hi","start":0,"end":5}],"errors":[],"panicked":false}"#
  );
}

#[test]
fn parse_answers_what_it_could_not_read_inside_the_result() {
  let (code, answer) = parse("const x = ;", r#"{"ast":false}"#);

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    concat!(
      r#"{"comments":[],"errors":[{"severity":"error","message":"Unexpected token","#,
      r#""labels":[{"start":10,"end":11}],"#,
      r#""codeframe":"\n  x Unexpected token\n   ,-[:1:11]\n 1 | const x = ;\n   :           ^\n   `----\n"}],"#,
      r#""panicked":true}"#
    )
  );
}

#[test]
fn parse_refuses_an_ast_type_it_cannot_read() {
  let (code, answer) = parse("a", r#"{"ast_type":"ruby"}"#);

  assert_eq!(code, OxcErrorCode::Option);
  assert_eq!(answer, "Unknown ast_type: ruby. Expected js or ts.");
}

#[test]
fn parse_reads_the_module_record_when_it_was_asked_to() {
  let (code, answer) = parse(
    r#"import { a } from "./a""#,
    r#"{"ast":false,"source_type":"module","module_record":true}"#,
  );

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    concat!(
      r#"{"module_record":{"has_module_syntax":true,"static_imports":[{"start":0,"end":23,"#,
      r#""module_request":{"value":"./a","start":18,"end":23},"entries":[{"import_name":{"kind":"name","#,
      r#""name":"a","start":9,"end":10},"local_name":{"value":"a","start":9,"end":10},"is_type":false}]}],"#,
      r#""static_exports":[],"dynamic_imports":[],"import_metas":[]},"comments":[],"errors":[],"panicked":false}"#
    )
  );
}

#[test]
fn parse_reads_the_symbols_when_it_was_asked_to() {
  let (code, answer) = parse("let a = 1; foo(a)", r#"{"ast":false,"symbols":true}"#);

  assert_eq!(code, OxcErrorCode::None);
  assert_eq!(
    answer,
    concat!(
      r#"{"symbols":{"declared":[{"name":"a","root":true,"declaration":{"start":4,"end":5},"#,
      r#""references":[{"start":15,"end":16,"read":true,"write":false}]}],"#,
      r#""unresolved":[{"name":"foo","references":[{"start":11,"end":14,"read":true,"write":false}]}]},"#,
      r#""comments":[],"errors":[],"panicked":false}"#
    )
  );
}
