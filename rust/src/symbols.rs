use oxc::ast::ast::Program;
use oxc::semantic::{ReferenceId, Semantic, SemanticBuilder};
use oxc::span::GetSpan;
use serde::Serialize;

use crate::module_record::Span;

#[derive(Debug, Serialize)]
pub struct Symbols {
  pub declared: Vec<Symbol>,
  pub unresolved: Vec<Unresolved>,
}

#[derive(Debug, Serialize)]
pub struct Symbol {
  pub name: String,
  pub root: bool,
  pub declaration: Span,
  pub references: Vec<Reference>,
}

#[derive(Debug, Serialize)]
pub struct Unresolved {
  pub name: String,
  pub references: Vec<Reference>,
}

#[derive(Debug, Serialize)]
pub struct Reference {
  pub start: u32,
  pub end: u32,
  pub read: bool,
  pub write: bool,
}

pub fn read<'a>(program: &'a Program<'a>) -> Symbols {
  let semantic = SemanticBuilder::new().with_build_nodes(true).build(program).semantic;

  Symbols {
    declared: declared(&semantic),
    unresolved: unresolved(&semantic),
  }
}

fn declared(semantic: &Semantic<'_>) -> Vec<Symbol> {
  let scoping = semantic.scoping();

  scoping
    .symbol_ids()
    .map(|symbol_id| {
      let name = scoping.symbol_name(symbol_id).to_string();
      let declaration = scoping.symbol_span(symbol_id);

      Symbol {
        root: scoping.symbol_scope_id(symbol_id) == scoping.root_scope_id(),
        name,
        declaration: Span {
          start: declaration.start,
          end: declaration.end,
        },
        references: scoping
          .get_resolved_reference_ids(symbol_id)
          .iter()
          .map(|reference_id| reference(semantic, *reference_id))
          .collect(),
      }
    })
    .collect()
}

fn unresolved(semantic: &Semantic<'_>) -> Vec<Unresolved> {
  let scoping = semantic.scoping();

  let mut unresolved = scoping
    .root_unresolved_references()
    .iter()
    .map(|(name, reference_ids)| Unresolved {
      name: name.to_string(),
      references: reference_ids
        .iter()
        .map(|reference_id| reference(semantic, *reference_id))
        .collect(),
    })
    .collect::<Vec<_>>();

  unresolved.sort_unstable_by(|left, right| left.name.cmp(&right.name));

  unresolved
}

fn reference(semantic: &Semantic<'_>, reference_id: ReferenceId) -> Reference {
  let found = semantic.scoping().get_reference(reference_id);
  let span = semantic.nodes().kind(found.node_id()).span();

  Reference {
    start: span.start,
    end: span.end,
    read: found.is_read(),
    write: found.is_write(),
  }
}
