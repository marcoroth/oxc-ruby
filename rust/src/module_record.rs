use std::collections::BTreeMap;

use oxc::syntax::module_record::{
  ExportEntry, ExportExportName, ExportImportName, ExportLocalName, ImportEntry, ImportImportName,
  ModuleRecord as OxcModuleRecord, NameSpan,
};
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct ModuleRecord {
  pub has_module_syntax: bool,
  pub static_imports: Vec<StaticImport>,
  pub static_exports: Vec<StaticExport>,
  pub dynamic_imports: Vec<DynamicImport>,
  pub import_metas: Vec<Span>,
}

#[derive(Debug, Serialize)]
pub struct Span {
  pub start: u32,
  pub end: u32,
}

#[derive(Debug, Serialize)]
pub struct ValueSpan {
  pub value: String,
  pub start: u32,
  pub end: u32,
}

#[derive(Debug, Serialize)]
pub struct Name {
  pub kind: &'static str,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub name: Option<String>,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub start: Option<u32>,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub end: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct StaticImport {
  pub start: u32,
  pub end: u32,
  pub module_request: ValueSpan,
  pub entries: Vec<StaticImportEntry>,
}

#[derive(Debug, Serialize)]
pub struct StaticImportEntry {
  pub import_name: Name,
  pub local_name: ValueSpan,
  pub is_type: bool,
}

#[derive(Debug, Serialize)]
pub struct StaticExport {
  pub start: u32,
  pub end: u32,
  pub entries: Vec<StaticExportEntry>,
}

#[derive(Debug, Serialize)]
pub struct StaticExportEntry {
  pub start: u32,
  pub end: u32,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub module_request: Option<ValueSpan>,
  pub import_name: Name,
  pub export_name: Name,
  pub local_name: Name,
  pub is_type: bool,
}

#[derive(Debug, Serialize)]
pub struct DynamicImport {
  pub start: u32,
  pub end: u32,
  pub module_request: Span,
}

impl From<&OxcModuleRecord<'_>> for ModuleRecord {
  fn from(record: &OxcModuleRecord<'_>) -> Self {
    let mut static_imports = record
      .requested_modules
      .iter()
      .flat_map(|(name, requested)| {
        requested
          .iter()
          .filter(|module| module.is_import)
          .map(|module| StaticImport {
            start: module.statement_span.start,
            end: module.statement_span.end,
            module_request: ValueSpan {
              value: name.to_string(),
              start: module.span.start,
              end: module.span.end,
            },
            entries: record
              .import_entries
              .iter()
              .filter(|entry| entry.statement_span == module.statement_span)
              .map(StaticImportEntry::from)
              .collect(),
          })
      })
      .collect::<Vec<_>>();

    static_imports.sort_unstable_by_key(|import| import.start);

    let mut grouped = BTreeMap::<(u32, u32), Vec<StaticExportEntry>>::new();

    for entry in record
      .local_export_entries
      .iter()
      .chain(record.indirect_export_entries.iter())
      .chain(record.star_export_entries.iter())
    {
      grouped
        .entry((entry.statement_span.start, entry.statement_span.end))
        .or_default()
        .push(StaticExportEntry::from(entry));
    }

    let static_exports = grouped
      .into_iter()
      .map(|((start, end), entries)| StaticExport { start, end, entries })
      .collect();

    Self {
      has_module_syntax: record.has_module_syntax,
      static_imports,
      static_exports,
      dynamic_imports: record
        .dynamic_imports
        .iter()
        .map(|import| DynamicImport {
          start: import.span.start,
          end: import.span.end,
          module_request: Span {
            start: import.module_request.start,
            end: import.module_request.end,
          },
        })
        .collect(),
      import_metas: record
        .import_metas
        .iter()
        .map(|span| Span {
          start: span.start,
          end: span.end,
        })
        .collect(),
    }
  }
}

impl From<&NameSpan<'_>> for ValueSpan {
  fn from(name: &NameSpan<'_>) -> Self {
    Self {
      value: name.name.to_string(),
      start: name.span.start,
      end: name.span.end,
    }
  }
}

impl From<&ImportEntry<'_>> for StaticImportEntry {
  fn from(entry: &ImportEntry<'_>) -> Self {
    Self {
      import_name: Name::from(&entry.import_name),
      local_name: ValueSpan::from(&entry.local_name),
      is_type: entry.is_type,
    }
  }
}

impl From<&ExportEntry<'_>> for StaticExportEntry {
  fn from(entry: &ExportEntry<'_>) -> Self {
    Self {
      start: entry.span.start,
      end: entry.span.end,
      module_request: entry.module_request.as_ref().map(ValueSpan::from),
      import_name: Name::from(&entry.import_name),
      export_name: Name::from(&entry.export_name),
      local_name: Name::from(&entry.local_name),
      is_type: entry.is_type,
    }
  }
}

impl Name {
  fn named(kind: &'static str, name: &NameSpan<'_>) -> Self {
    Self {
      kind,
      name: Some(name.name.to_string()),
      start: Some(name.span.start),
      end: Some(name.span.end),
    }
  }

  fn bare(kind: &'static str) -> Self {
    Self {
      kind,
      name: None,
      start: None,
      end: None,
    }
  }
}

impl From<&ImportImportName<'_>> for Name {
  fn from(import_name: &ImportImportName<'_>) -> Self {
    match import_name {
      ImportImportName::Name(name) => Self::named("name", name),
      ImportImportName::NamespaceObject => Self::bare("namespace_object"),
      ImportImportName::Default(span) => Self {
        kind: "default",
        name: None,
        start: Some(span.start),
        end: Some(span.end),
      },
    }
  }
}

impl From<&ExportImportName<'_>> for Name {
  fn from(import_name: &ExportImportName<'_>) -> Self {
    match import_name {
      ExportImportName::Name(name) => Self::named("name", name),
      ExportImportName::All => Self::bare("all"),
      ExportImportName::AllButDefault => Self::bare("all_but_default"),
      ExportImportName::Null => Self::bare("none"),
    }
  }
}

impl From<&ExportExportName<'_>> for Name {
  fn from(export_name: &ExportExportName<'_>) -> Self {
    match export_name {
      ExportExportName::Name(name) => Self::named("name", name),
      ExportExportName::Default(span) => Self {
        kind: "default",
        name: None,
        start: Some(span.start),
        end: Some(span.end),
      },
      ExportExportName::Null => Self::bare("none"),
    }
  }
}

impl From<&ExportLocalName<'_>> for Name {
  fn from(local_name: &ExportLocalName<'_>) -> Self {
    match local_name {
      ExportLocalName::Name(name) => Self::named("name", name),
      ExportLocalName::Default(name) => Self::named("default", name),
      ExportLocalName::Null => Self::bare("none"),
    }
  }
}
