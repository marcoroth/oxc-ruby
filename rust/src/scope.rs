use std::collections::BTreeMap;

use oxc::allocator::Allocator;
use oxc::codegen::Codegen;
use oxc::parser::Parser;
use oxc::semantic::SemanticBuilder;
use oxc::str::Ident;
use serde::Serialize;

use crate::diagnostic::Diagnostic;
use crate::options::ScopeOptions;
use crate::source_type::source_type_for;

#[derive(Debug, Default, Serialize)]
pub struct ScopePayload {
  pub code: String,
  #[serde(skip_serializing_if = "Option::is_none")]
  pub map: Option<String>,
  pub renamed: BTreeMap<String, String>,
  pub errors: Vec<Diagnostic>,
  pub panicked: bool,
}

pub fn scope_source(source: &str, options: &ScopeOptions) -> Result<ScopePayload, String> {
  let filename = options.filename.clone().unwrap_or_default();
  let source_type = source_type_for(&filename, options.lang.as_deref(), options.source_type.as_deref())?;
  let suffix = options.suffix()?;

  let allocator = Allocator::default();

  let parsed = Parser::new(&allocator, source, source_type).parse();
  let program = parsed.program;

  if parsed.panicked {
    return Ok(ScopePayload {
      errors: Diagnostic::from_diagnostics(&filename, source, parsed.diagnostics),
      panicked: true,
      ..ScopePayload::default()
    });
  }

  let mut scoping = SemanticBuilder::new().build(&program).semantic.into_scoping();
  let root = scoping.root_scope_id();

  let bindings = scoping
    .get_bindings(root)
    .iter()
    .map(|(name, symbol_id)| (name.to_string(), *symbol_id))
    .collect::<Vec<_>>();

  let mut renamed = BTreeMap::new();

  for (name, symbol_id) in bindings {
    let scoped = format!("{name}{}{suffix}", options.separator);

    scoping.rename_symbol(symbol_id, root, Ident::from_str_in(&scoped, &&allocator));
    renamed.insert(name, scoped);
  }

  let printed = Codegen::new()
    .with_options(options.to_codegen_options()?)
    .with_scoping(Some(scoping))
    .build(&program);

  Ok(ScopePayload {
    code: printed.code,
    map: printed.map.map(|map| map.to_json_string()),
    renamed,
    errors: Diagnostic::from_diagnostics(&filename, source, parsed.diagnostics),
    panicked: false,
  })
}
