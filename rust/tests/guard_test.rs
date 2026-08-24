use oxc_ffi::{guard, oxc_result_free, Failure, OxcErrorCode};

use std::ffi::CStr;
use std::os::raw::c_char;

fn message(error: *mut c_char) -> String {
  unsafe { CStr::from_ptr(error) }.to_str().unwrap().to_string()
}

#[test]
fn guard_catches_a_panic_and_carries_its_message() {
  let result = guard(|| -> Result<String, Failure> { panic!("boom") });

  assert_eq!(result.code, OxcErrorCode::Panic);
  assert!(result.value.is_null());
  assert_eq!(message(result.error), "boom");

  unsafe { oxc_result_free(result) };
}

#[test]
fn guard_answers_what_the_call_produced() {
  let result = guard(|| Ok::<_, Failure>("foo();".to_string()));

  assert_eq!(result.code, OxcErrorCode::None);
  assert!(result.error.is_null());
  assert_eq!(message(result.value), "\"foo();\"");

  unsafe { oxc_result_free(result) };
}

#[test]
fn guard_carries_the_code_a_failure_was_given() {
  let result = guard(|| -> Result<String, Failure> { Err(Failure::option("nope")) });

  assert_eq!(result.code, OxcErrorCode::Option);
  assert_eq!(message(result.error), "nope");

  unsafe { oxc_result_free(result) };
}
