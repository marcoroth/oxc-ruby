use std::sync::Arc;

use oxc::diagnostics::{LabeledSpan, NamedSource, OxcDiagnostic};
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct Diagnostic {
  pub severity: &'static str,
  pub message: String,
  pub labels: Vec<Label>,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub help: Option<String>,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub codeframe: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct Label {
  #[serde(skip_serializing_if = "Option::is_none")]
  pub message: Option<String>,
  pub start: u32,
  pub end: u32,
}

impl Diagnostic {
  pub fn from_diagnostics(
    filename: &str,
    source_text: &str,
    diagnostics: impl IntoIterator<Item = OxcDiagnostic>,
  ) -> Vec<Self> {
    let diagnostics = diagnostics.into_iter().collect::<Vec<_>>();

    if diagnostics.is_empty() {
      return Vec::new();
    }

    let source = Arc::new(NamedSource::new(filename, source_text.to_string()));

    diagnostics
      .into_iter()
      .map(|diagnostic| Self::from_diagnostic(&source, diagnostic))
      .collect()
  }

  fn from_diagnostic(source: &Arc<NamedSource<String>>, diagnostic: OxcDiagnostic) -> Self {
    let severity = match diagnostic.severity {
      oxc::diagnostics::Severity::Error => "error",
      oxc::diagnostics::Severity::Warning => "warning",
      oxc::diagnostics::Severity::Advice => "advice",
    };

    let labels = diagnostic.labels.iter().map(Label::from).collect::<Vec<_>>();
    let message = diagnostic.message.to_string();
    let help = diagnostic.help.as_ref().map(ToString::to_string);
    let codeframe = Some(diagnostic.render_with_source_code(Arc::clone(source)));

    Self {
      severity,
      message,
      labels,
      help,
      codeframe,
    }
  }
}

impl From<&LabeledSpan> for Label {
  fn from(label: &LabeledSpan) -> Self {
    Self {
      message: label.label().map(ToString::to_string),
      start: label.offset(),
      end: label.offset() + label.len(),
    }
  }
}
