//! C FFI bindings for oxc.
//!
//! # Safety
//!
//! Every function here requires that pointer arguments are valid, NUL-terminated C strings unless
//! documented as nullable. Returned pointers are owned by the caller and must be released with
//! `oxc_string_free` or `oxc_result_free`.

#![allow(clippy::missing_safety_doc)]

mod diagnostic;
mod module_record;
mod options;
mod parse;
mod result;
mod scope;
mod source_type;
mod symbols;
mod transform;

use std::any::Any;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;

use oxc::allocator::Allocator;
use oxc::codegen::Codegen;
use oxc::minifier::Minifier;
use oxc::parser::Parser;
use oxc::CompilerInterface;
use serde::de::DeserializeOwned;

use crate::diagnostic::Diagnostic;
use crate::options::{MinifyOptions, ParseOptions, ScopeOptions, TransformOptions};
use crate::parse::parse_source;
use crate::result::{MinifyPayload, TransformPayload};
use crate::scope::scope_source;
use crate::source_type::source_type_for;
use crate::transform::Compiler;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const OXC_VERSION: &str = env!("OXC_VERSION");

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OxcErrorCode {
  None = 0,
  Option,
  Encoding,
  Transform,
  Internal,
  Panic,
}

#[repr(C)]
pub struct OxcResult {
  pub value: *mut c_char,
  pub value_len: usize,
  pub error: *mut c_char,
  pub code: OxcErrorCode,
}

impl OxcResult {
  pub fn ok(value: String) -> Self {
    let len = value.len();

    Self {
      value: into_c_string(value),
      value_len: len,
      error: ptr::null_mut(),
      code: OxcErrorCode::None,
    }
  }

  pub fn err(code: OxcErrorCode, message: impl AsRef<str>) -> Self {
    Self {
      value: ptr::null_mut(),
      value_len: 0,
      error: into_c_string(message.as_ref()),
      code,
    }
  }
}

pub struct Failure {
  code: OxcErrorCode,
  message: String,
}

impl Failure {
  pub fn option(message: impl Into<String>) -> Self {
    Self {
      code: OxcErrorCode::Option,
      message: message.into(),
    }
  }

  pub fn encoding(message: impl Into<String>) -> Self {
    Self {
      code: OxcErrorCode::Encoding,
      message: message.into(),
    }
  }
}

fn into_c_string(value: impl Into<Vec<u8>>) -> *mut c_char {
  CString::new(value).unwrap_or_default().into_raw()
}

unsafe fn borrow_str<'a>(pointer: *const c_char, label: &str) -> Result<&'a str, Failure> {
  if pointer.is_null() {
    return Err(Failure::encoding(format!("{label} is null")));
  }

  CStr::from_ptr(pointer)
    .to_str()
    .map_err(|error| Failure::encoding(format!("Invalid UTF-8 in {label}: {error}")))
}

unsafe fn borrow_options<T: Default + DeserializeOwned>(pointer: *const c_char) -> Result<T, Failure> {
  if pointer.is_null() {
    return Ok(T::default());
  }

  let json = borrow_str(pointer, "options")?;

  if json.trim().is_empty() {
    return Ok(T::default());
  }

  serde_json::from_str(json).map_err(|error| Failure::option(format!("Invalid options: {error}")))
}

fn panic_message(payload: &Box<dyn Any + Send>) -> String {
  if let Some(message) = payload.downcast_ref::<&str>() {
    return (*message).to_string();
  }

  if let Some(message) = payload.downcast_ref::<String>() {
    return message.clone();
  }

  "oxc panicked".to_string()
}

fn answer<T: serde::Serialize>(outcome: Result<T, Failure>) -> OxcResult {
  match outcome {
    Ok(payload) => match serde_json::to_string(&payload) {
      Ok(json) => OxcResult::ok(json),
      Err(error) => OxcResult::err(
        OxcErrorCode::Internal,
        format!("Failed to serialize the result: {error}"),
      ),
    },
    Err(failure) => OxcResult::err(failure.code, failure.message),
  }
}

pub fn guard<T: serde::Serialize>(call: impl FnOnce() -> Result<T, Failure>) -> OxcResult {
  match panic::catch_unwind(AssertUnwindSafe(call)) {
    Ok(outcome) => answer(outcome),
    Err(payload) => OxcResult::err(OxcErrorCode::Panic, panic_message(&payload)),
  }
}

fn minify_source(source: &str, options: &MinifyOptions) -> Result<MinifyPayload, Failure> {
  let filename = options.filename.clone().unwrap_or_default();

  let minifier_options = options.to_minifier_options().map_err(Failure::option)?;
  let mut codegen_options = options.to_codegen_options().map_err(Failure::option)?;

  let source_type =
    source_type_for(&filename, options.lang.as_deref(), options.source_type.as_deref()).map_err(Failure::option)?;

  let allocator = Allocator::default();
  let parsed = Parser::new(&allocator, source, source_type).parse();

  let mut program = parsed.program;

  let minified = Minifier::new(minifier_options).minify(&allocator, &mut program);

  if !options.sourcemap {
    codegen_options.source_map_path = None;
  }

  let printed = Codegen::new()
    .with_options(codegen_options)
    .with_scoping(minified.scoping)
    .build(&program);

  let map = printed.map.map(|map| map.to_json_string());

  let legal_comments = printed
    .legal_comments
    .iter()
    .map(|comment| comment.span.source_text(source).to_string())
    .collect();

  Ok(MinifyPayload {
    code: printed.code,
    map,
    legal_comments,
    errors: Diagnostic::from_diagnostics(&filename, source, parsed.diagnostics),
    panicked: parsed.panicked,
  })
}

fn transform_source(source: &str, options: &TransformOptions) -> Result<TransformPayload, Failure> {
  let filename = options.filename.clone().unwrap_or_default();

  let source_type =
    source_type_for(&filename, options.lang.as_deref(), options.source_type.as_deref()).map_err(Failure::option)?;

  let mut compiler = Compiler::new(options).map_err(Failure::option)?;

  compiler.compile(source, source_type, std::path::Path::new(&filename));

  let legal_comments = compiler
    .legal_comments
    .iter()
    .map(|span| span.source_text(source).to_string())
    .collect();

  let panicked = compiler.code.is_empty() && !compiler.errors.is_empty();

  Ok(TransformPayload {
    code: compiler.code,
    map: compiler.map,
    declaration: compiler.declaration,
    declaration_map: compiler.declaration_map,
    legal_comments,
    helpers_used: compiler.helpers_used,
    errors: Diagnostic::from_diagnostics(&filename, source, compiler.errors),
    panicked,
  })
}

#[no_mangle]
pub unsafe extern "C" fn oxc_scope(source: *const c_char, options_json: *const c_char) -> OxcResult {
  guard(|| {
    let source = borrow_str(source, "source")?;
    let options = borrow_options::<ScopeOptions>(options_json)?;

    scope_source(source, &options).map_err(Failure::option)
  })
}

#[no_mangle]
pub unsafe extern "C" fn oxc_parse(source: *const c_char, options_json: *const c_char) -> OxcResult {
  guard(|| {
    let source = borrow_str(source, "source")?;
    let options = borrow_options::<ParseOptions>(options_json)?;

    parse_source(source, &options).map_err(Failure::option)
  })
}

#[no_mangle]
pub unsafe extern "C" fn oxc_transform(source: *const c_char, options_json: *const c_char) -> OxcResult {
  guard(|| {
    let source = borrow_str(source, "source")?;
    let options = borrow_options::<TransformOptions>(options_json)?;

    transform_source(source, &options)
  })
}

#[no_mangle]
pub unsafe extern "C" fn oxc_minify(source: *const c_char, options_json: *const c_char) -> OxcResult {
  guard(|| {
    let source = borrow_str(source, "source")?;
    let options = borrow_options::<MinifyOptions>(options_json)?;

    minify_source(source, &options)
  })
}

#[no_mangle]
pub unsafe extern "C" fn oxc_version() -> *mut c_char {
  into_c_string(VERSION)
}

#[no_mangle]
pub unsafe extern "C" fn oxc_oxc_version() -> *mut c_char {
  into_c_string(OXC_VERSION)
}

#[no_mangle]
pub unsafe extern "C" fn oxc_string_free(value: *mut c_char) {
  if !value.is_null() {
    drop(CString::from_raw(value));
  }
}

#[no_mangle]
pub unsafe extern "C" fn oxc_result_free(result: OxcResult) {
  oxc_string_free(result.value);
  oxc_string_free(result.error);
}
