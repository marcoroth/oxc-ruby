use std::collections::BTreeMap;

use serde::Serialize;
use serde_json::value::RawValue;

use crate::diagnostic::Diagnostic;
use crate::module_record::ModuleRecord;
use crate::symbols::Symbols;

#[derive(Debug, Default, Serialize)]
pub struct MinifyPayload {
  pub code: String,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub map: Option<String>,
  pub legal_comments: Vec<String>,
  pub errors: Vec<Diagnostic>,
  pub panicked: bool,
}

#[derive(Debug, Default, Serialize)]
pub struct TransformPayload {
  pub code: String,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub map: Option<String>,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub declaration: Option<String>,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub declaration_map: Option<String>,
  pub legal_comments: Vec<String>,
  pub helpers_used: BTreeMap<String, String>,
  pub errors: Vec<Diagnostic>,
  pub panicked: bool,
}

#[derive(Debug, Serialize)]
pub struct Comment {
  #[serde(rename = "type")]
  pub kind: &'static str,
  pub value: String,
  pub start: u32,
  pub end: u32,
}

#[derive(Debug, Serialize)]
pub struct ParsePayload {
  #[serde(skip_serializing_if = "Option::is_none")]
  pub program: Option<Box<RawValue>>,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub module_record: Option<ModuleRecord>,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub symbols: Option<Symbols>,
  pub comments: Vec<Comment>,
  pub errors: Vec<Diagnostic>,
  pub panicked: bool,
}
